#!/usr/bin/env python
"""Genera los PNG de las cartas de giro y las hojas de contacto.

Uso, desde la raiz del proyecto y sin argumentos:

    python art/ui/cards/build_cards.py

Descubre todos los `lotes/lote_*.py`, junta sus `RARITY` y `PAINTERS` y escribe:

* `art/ui/cards/<id>.png` — una carta por id, 312 x 450, RGBA. Nombre en minusculas.
* `art/render/ui/cards-hoja-<lote>.png` — una hoja de contacto por lote.
* `art/render/ui/cards-paso1-hoja-contacto.png` — las cartas de `lote_ejemplo`.

Un solo lote, para trabajar en paralelo sin pisar los PNG de los demas:

    python art/ui/cards/build_cards.py --lote lote_comunes

Con `--lote` escribe solo las cartas de ese lote y solo su hoja: no toca los PNG de
otros lotes ni la hoja del paso 1. Si el lote no existe, sale con codigo 1 y la lista
de lotes disponibles.

Es idempotente y determinista: no usa azar ni fechas, y ordena ids y lotes.
"""
import importlib.util
import sys
from pathlib import Path

import cardlib

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = HERE
SHEETS = ROOT / "art" / "render" / "ui"
LOTES = HERE / "lotes"
EXAMPLE_LOTE = "lote_ejemplo"
USAGE = "uso: python art/ui/cards/build_cards.py [--lote <nombre de lote>]"

#: Nombres que se escriben bajo cada carta en las hojas de contacto. Un lote puede
#: traer su propio `LABELS` y se mezcla aqui; esto es el registro de las de ejemplo.
DISPLAY = {"Fine": "Multa", "Strike": "Huelga", "Hurricane": "Hurac\u00e1n"}


def parse_args(argv):
    """Devuelve el lote pedido con `--lote`, o `None` si hay que hacerlos todos."""
    only = None
    rest = list(argv)
    while rest:
        arg = rest.pop(0)
        if arg == "--lote":
            if not rest:
                raise SystemExit("%s\nfalta el nombre del lote" % USAGE)
            only = rest.pop(0)
        elif arg.startswith("--lote="):
            only = arg.split("=", 1)[1]
        elif arg in ("-h", "--help"):
            print(__doc__.strip())
            raise SystemExit(0)
        else:
            raise SystemExit("%s\nargumento desconocido: %s" % (USAGE, arg))
    if only is not None and not only:
        raise SystemExit("%s\nel nombre del lote esta vacio" % USAGE)
    return only


def load_lotes():
    """Importa `lotes/lote_*.py` y devuelve [(nombre, modulo)] en orden alfabetico."""
    modules = []
    for path in sorted(LOTES.glob("lote_*.py")):
        spec = importlib.util.spec_from_file_location(path.stem, path)
        if spec is None or spec.loader is None:  # pragma: no cover
            raise RuntimeError("no se puede importar %s" % path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        modules.append((path.stem, module))
    return modules


def _order(rarities):
    """Orden de la hoja: legendarias, raras y comunes; dentro de cada grupo, por id."""
    return sorted(rarities, key=lambda cid: (cardlib.RARITY_RANK[rarities[cid]], cid))


def collect(modules):
    """Junta RARITY, PAINTERS y etiquetas de todos los lotes."""
    cards = {}
    labels = dict(DISPLAY)
    for name, module in modules:
        painters = getattr(module, "PAINTERS", None)
        rarities = getattr(module, "RARITY", None)
        if not isinstance(painters, dict) or not isinstance(rarities, dict):
            raise RuntimeError("%s no expone PAINTERS y RARITY" % name)
        labels.update(getattr(module, "LABELS", {}))
        for card_id, painter in painters.items():
            if card_id in cards:
                raise RuntimeError("la carta %r esta en dos lotes" % card_id)
            if card_id not in rarities:
                raise RuntimeError("%s no declara la rareza de %r" % (name, card_id))
            cards[card_id] = (rarities[card_id], painter)
        for card_id in rarities:
            if card_id not in painters:
                raise RuntimeError("%s declara la rareza de %r sin pintor" % (name, card_id))
    return cards, labels


def _only_lote(modules, name):
    """Deja el lote pedido; si no existe, error con la lista de los disponibles."""
    available = [module_name for module_name, _ in modules]
    if name not in available:
        raise SystemExit(
            "no existe el lote %r\nlotes disponibles: %s" % (name, ", ".join(available))
        )
    return [(module_name, module) for module_name, module in modules if module_name == name]


def main(argv=None):
    only = parse_args(sys.argv[1:] if argv is None else argv)

    modules = load_lotes()
    if not modules:
        raise SystemExit("no hay lotes en %s" % LOTES)
    if only is not None:
        modules = _only_lote(modules, only)

    cards, labels = collect(modules)
    OUT.mkdir(parents=True, exist_ok=True)
    SHEETS.mkdir(parents=True, exist_ok=True)

    paths = {}
    for card_id in sorted(cards):
        rarity, painter = cards[card_id]
        image = cardlib.render_card(card_id, rarity, painter)
        path = OUT / ("%s.png" % card_id.lower())
        image.save(path)
        paths[card_id] = path
        print("carta  %-12s %-9s %s" % (card_id, rarity, path.name))

    for name, module in modules:
        entries = [
            (card_id, module.RARITY[card_id], paths[card_id], labels.get(card_id, card_id))
            for card_id in _order(module.RARITY)
        ]
        title = "FLIP THE TABLE \u00b7 CARTAS DE GIRO \u00b7 LOTE %s" % name[5:].upper()
        sheet = SHEETS / ("cards-hoja-%s.png" % name[5:])
        cardlib.contact_sheet(entries, sheet, title)
        print("hoja   %-12s %s" % (name, sheet.name))

    if only is not None:
        print("%d cartas, 1 lote (%s)" % (len(cards), only))
        return 0

    example = dict(modules).get(EXAMPLE_LOTE)
    if example is None:
        entries = [
            (card_id, cards[card_id][0], paths[card_id], labels.get(card_id, card_id))
            for card_id in _order({cid: cards[cid][0] for cid in cards})
        ]
    else:
        entries = [
            (card_id, example.RARITY[card_id], paths[card_id], labels.get(card_id, card_id))
            for card_id in _order(example.RARITY)
        ]
    paso1 = SHEETS / "cards-paso1-hoja-contacto.png"
    cardlib.contact_sheet(
        entries, paso1, "FLIP THE TABLE \u00b7 CARTAS DE GIRO \u00b7 PASO 1"
    )
    print("hoja   %-12s %s" % ("paso 1", paso1.name))
    print("%d cartas, %d lotes" % (len(cards), len(modules)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

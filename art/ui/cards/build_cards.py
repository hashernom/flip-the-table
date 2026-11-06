#!/usr/bin/env python
"""Genera los PNG de las cartas de giro y las hojas de contacto.

Uso, desde la raiz del proyecto y sin argumentos:

    python art/ui/cards/build_cards.py

Descubre todos los `lotes/lote_*.py`, junta sus `RARITY` y `PAINTERS` y escribe:

* `art/ui/cards/<id>.png` — una carta por id, 312 x 450, RGBA. Nombre en minusculas.
* `art/render/ui/cards-hoja-<lote>.png` — una hoja de contacto por lote.
* `art/render/ui/cards-paso1-hoja-contacto.png` — las cartas de `lote_ejemplo`.

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

#: Nombres que se escriben bajo cada carta en las hojas de contacto. Un lote puede
#: traer su propio `LABELS` y se mezcla aqui; esto es el registro de las de ejemplo.
DISPLAY = {"Fine": "Multa", "Strike": "Huelga", "Hurricane": "Hurac\u00e1n"}


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


def main():
    modules = load_lotes()
    if not modules:
        raise SystemExit("no hay lotes en %s" % LOTES)

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

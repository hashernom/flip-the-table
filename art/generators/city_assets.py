"""Escribe en `ArtAssets.luau` las mallas de un barrio a partir de lo que ya subió `upload_city.ps1`.

Es la parte que se equivoca a mano: 37 ids nuevos por barrio, cada uno con su material. El guion lee
`uploaded.json` (nombre de archivo -> assetId) y `<barrio>-stats.json` (qué mallas forman cada
asset), y deja en el código un bloque entre marcas que se puede regenerar sin tocar lo demás.

Uso:
  python art/generators/city_assets.py centro
  python art/generators/city_assets.py centro --check   (no escribe, solo dice qué falta)
"""

import argparse
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
CITY = os.path.join(REPO, "art", "blender", "city")
ART_ASSETS = os.path.join(REPO, "src", "shared", "config", "ArtAssets.luau")
MANIFEST = os.path.join(REPO, "art", "manifest.json")

START = "\t-- @barrios:inicio"
END = "\t-- @barrios:fin"

# Material y color de cada pieza, por el sufijo de su malla. Sale de `art/guia-de-estilo.md` §2.2 y §6:
# una pieza de Open Cloud llega sin material, así que el color y el material se ponen aquí.
MATERIALS = {
    "curb": ((156, 154, 148), "Concrete", None),
    "flag": ((198, 190, 174), "Concrete", None),
    "flag_dark": ((124, 122, 116), "Concrete", None),
    "grate": ((43, 47, 51), "Metal", 0.2),
    "bark": ((107, 88, 68), "Wood", None),
    "leaf": ((78, 107, 60), "Grass", None),
    "soil": ((47, 42, 37), "Ground", None),
    "iron": ((35, 40, 43), "Metal", None),
    "lamp_glass": ((237, 229, 211), "SmoothPlastic", None),
    "wood": ((122, 84, 51), "Wood", None),
    "brick": ((176, 102, 74), "Brick", None),
    "brick_dark": ((142, 82, 60), "Brick", None),
    "stone": ((210, 201, 180), "Limestone", None),
    "stone_dark": ((185, 176, 156), "Limestone", None),
    "slate": ((74, 78, 84), "Slate", None),
    "window": ((46, 58, 68), "SmoothPlastic", None),
    "paint": ((222, 216, 200), "SmoothPlastic", None),
    "red": ((196, 56, 43), "Fabric", None),
    "hydrant": ((168, 53, 42), "Metal", None),
    # El cristal de la ciudad es el azul de la guía (§2.2), no el de las ventanas: `window` es hueco.
    "glass": ((127, 178, 217), "Glass", 0.25),
    "concrete": ((196, 192, 184), "Concrete", None),
    "rust": ((140, 74, 42), "CorrodedMetal", None),
    "steel": ((168, 174, 180), "Metal", 0.8),
    "gold": ((201, 162, 39), "Metal", 0.9),
    "asphalt": ((74, 78, 84), "Asphalt", None),
    "water": ((62, 127, 166), "Water", None),
    "canvas": ((224, 218, 202), "Fabric", None),
    "neon": ((245, 197, 24), "Neon", None),
}

# Orden de las piezas dentro de un asset: primero lo que se ve de lejos.
ORDER = ["stone", "stone_dark", "brick", "brick_dark", "slate", "window", "curb", "flag", "flag_dark", "grate"]


def load(name):
    with open(name, encoding="utf-8") as handle:
        return json.load(handle)


def load_uploaded():
    """Junta todos los `uploaded*.json` de la carpeta: cada barrio sube al suyo y aquí se leen juntos."""
    merged = {}
    for name in sorted(os.listdir(CITY)):
        if name.startswith("uploaded") and name.endswith(".json"):
            merged.update(load(os.path.join(CITY, name)))
    if not merged:
        raise SystemExit(f"No hay uploaded*.json en {CITY}")
    return merged


def suffix_of(mesh, asset):
    prefix = f"{asset}_"
    if not mesh.startswith(prefix):
        raise ValueError(f"{mesh} no empieza por {prefix}")
    return mesh[len(prefix) :]


def asset_order(asset):
    return asset


def render_block(barrio, stats, uploaded):
    missing = []
    lines = []
    names = sorted(stats.keys(), key=asset_order)
    for name in names:
        entry = stats[name]
        piece_lines = []
        for mesh in sorted(entry["pieces"], key=lambda item: (ORDER.index(suffix_of(item, name)) if suffix_of(item, name) in ORDER else 99, item)):
            file = f"{mesh}.fbx"
            if file not in uploaded:
                missing.append(file)
                continue
            suffix = suffix_of(mesh, name)
            if suffix not in MATERIALS:
                missing.append(f"{file} (sin material para «{suffix}»)")
                continue
            color, material, reflectance = MATERIALS[suffix]
            color_text = "{ " + ", ".join(str(value) for value in color) + " }"
            extra = f", {reflectance}" if reflectance is not None else ""
            piece_lines.append(f'\t\tpiece("{mesh}", "{uploaded[file].split("//")[-1]}", {color_text}, "{material}"{extra}),')
        if not piece_lines:
            continue
        lines.append(f'\t["{name}"] = {{')
        lines.extend(piece_lines)
        lines.append("\t},")
    return lines, missing


def manifest_entries(barrio, stats, uploaded):
    """Una entrada de manifiesto por asset, con los ids de sus mallas. Estado `Draft`: aprobar no toca."""
    entries = []
    for name in sorted(stats.keys()):
        entry = stats[name]
        ids = []
        for mesh in entry["pieces"]:
            file = f"{mesh}.fbx"
            if file in uploaded:
                ids.append(uploaded[file])
        if not ids:
            continue
        is_backdrop = "backdrop" in name
        record = {
            "id": name,
            "category": "CityBackdrop" if is_backdrop else "RepeatedProp",
            "source": f"art/blender/city/{barrio}.py",
            "triangles": entry["triangles"],
            "textures": 0,
            "status": "Draft",
            "screenshots": [],
            "generatedWith": f"Blender 5.2, art/blender/city/{barrio}.py",
            "assetId": ids[0],
        }
        if is_backdrop:
            # El fondo no necesita versión reducida (art/PIPELINE.md §2); el resto, sí.
            record["assetIds"] = ids
        else:
            record["lods"] = [entry["lod"]]
            record["assetIds"] = ids
        entries.append(record)
    return entries


def write_manifest(entries):
    with open(MANIFEST, encoding="utf-8") as handle:
        manifest = json.load(handle)
    by_id = {asset["id"]: asset for asset in manifest["assets"]}
    added, updated = 0, 0
    for entry in entries:
        if entry["id"] in by_id:
            current = by_id[entry["id"]]
            if current.get("triangles") == entry["triangles"] and current.get("assetIds") == entry["assetIds"]:
                continue
            current.update(entry)
            updated += 1
        else:
            manifest["assets"].append(entry)
            added += 1
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(manifest, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    return added, updated


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("barrio")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    stats = load(os.path.join(CITY, f"{args.barrio}-stats.json"))
    uploaded = load_uploaded()

    lines, missing = render_block(args.barrio, stats, uploaded)
    if missing:
        print("FALTAN:")
        for item in missing:
            print(f"  - {item}")
        return 1
    if not lines:
        print("Nada que escribir")
        return 1

    # Una marca por barrio: así un barrio no borra el bloque de los demás al regenerarse.
    start_tag = f"{START} {args.barrio}"
    end_tag = f"{END} {args.barrio}"
    block = "\n".join([start_tag] + lines + [end_tag])

    with open(ART_ASSETS, encoding="utf-8") as handle:
        source = handle.read()

    # Formatos anteriores sin nombre de barrio: se retiran antes de insertar.
    legacy = source.find("\t-- @barrios:inicio (generado")
    if legacy != -1:
        legacy_end = source.find(END, legacy)
        source = source[:legacy] + source[legacy_end + len(END) :]

    start = source.find(start_tag)
    if start != -1:
        end = source.find(end_tag, start)
        source = source[:start] + block + source[end + len(end_tag) :]
    else:
        anchor = "ArtAssets.street = {"
        position = source.find(anchor)
        if position == -1:
            raise SystemExit("No encuentro `ArtAssets.street = {` en ArtAssets.luau")
        close = source.find("} :: { [string]: { Piece } }", position)
        if close == -1:
            raise SystemExit("No encuentro el cierre de `ArtAssets.street`")
        # El cierre lleva sangría de un tabulador; el bloque se mete justo antes.
        source = source[:close] + block + "\n" + source[close:]

    if args.check:
        print(block)
        return 0

    with open(ART_ASSETS, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(source)

    added, updated = write_manifest(manifest_entries(args.barrio, stats, uploaded))

    total = sum(entry["triangles"] for entry in stats.values())
    print(f"escrito: {len(lines)} assets de {args.barrio}, {total} triángulos; manifiesto +{added} ~{updated}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

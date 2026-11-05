"""Comprueba una propiedad modelada antes de subirla: es la parte medible de la fase B del blueprint.

Abre cada FBX de verdad, así que no se fía de lo que diga el script que las generó. Comprueba una malla por
FBX, el presupuesto, los materiales, que cada nivel sume piezas y que el edificio quepa en su sitio. No juzga si
se ve bien: eso lo decide quien mira los renders.

Uso, con la carpeta que contiene stats.json y las FBX y la altura máxima en studs:
  blender --background --factory-startup --python art/generators/check_property.py -- <carpeta> <altura_max>

Acaba con "CHECK OK" o con "CHECK FAIL" y código de salida 1.
"""

import json
import os
import sys

import bpy

TRIANGLE_BUDGET = 3000
ALLOWED_MATERIALS = {"Brick", "Limestone", "Slate", "Glass", "Metal", "Fabric", "Wood", "SmoothPlastic", "Grass"}
LOT_HALF_WIDTH = 18.0  # medio solar
FRONT_LIMIT = -10.3  # delante empieza la franja del marcador
BACK_LIMIT = 13.0  # el fondo del solar, con algo de holgura: detrás no se ve desde la calle
MIN_BODY_HEIGHT = 7.0
EPSILON = 0.05


def load_mesh(path):
    """Importa una FBX en una escena vacía y devuelve sus mallas."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path, axis_forward="Z", axis_up="Y")
    return [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]


def bounds_of(obj):
    corners = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    return (
        min(c.x for c in corners),
        max(c.x for c in corners),
        min(c.y for c in corners),
        max(c.y for c in corners),
        min(c.z for c in corners),
        max(c.z for c in corners),
    )


def main():
    args = sys.argv[sys.argv.index("--") + 1 :]
    folder, height_limit = args[0], float(args[1])
    problems = []
    stats_path = os.path.join(folder, "stats.json")
    if not os.path.exists(stats_path):
        print(f"CHECK FAIL: no existe {stats_path}")
        sys.exit(1)
    with open(stats_path, encoding="utf-8") as handle:
        stats = json.load(handle)

    pieces = stats["piezas"]
    keys = [piece["clave"] for piece in pieces]
    if len(keys) != len(set(keys)):
        problems.append("hay claves repetidas")

    total = stats["total_triangulos"]
    if total > TRIANGLE_BUDGET:
        problems.append(f"{total} triángulos: el presupuesto es {TRIANGLE_BUDGET}")
    if stats["lod1"]["triangulos"] >= total / 2:
        problems.append(f"LOD1 de {stats['lod1']['triangulos']}: debe bajar del 50 % de {total}")

    per_level = {level: [] for level in range(6)}
    limits = {}
    for piece in pieces:
        key = piece["clave"]
        level = piece["nivel"]
        per_level.setdefault(level, []).append(key)
        if piece["material"] not in ALLOWED_MATERIALS:
            problems.append(f"{key}: material {piece['material']} no permitido")
        path = os.path.join(folder, key + ".fbx")
        if not os.path.exists(path):
            problems.append(f"{key}: falta la FBX")
            continue
        meshes = load_mesh(path)
        if len(meshes) != 1:
            problems.append(f"{key}: la FBX tiene {len(meshes)} mallas; ArtLoader solo cargaría la primera")
            continue
        limits[key] = (level, bounds_of(meshes[0]))

    if not any(name.endswith("_LOD1.fbx") for name in os.listdir(folder)):
        problems.append("falta la FBX del LOD1")
    for level in range(6):
        if not per_level[level]:
            problems.append(f"el nivel {level} no tiene piezas")

    summary = {}
    for level in range(6):
        boxes = [box for owner, box in limits.values() if owner <= level]
        if not boxes:
            continue
        low_x, high_x = min(b[0] for b in boxes), max(b[1] for b in boxes)
        low_y, high_y = min(b[2] for b in boxes), max(b[3] for b in boxes)
        low_z, high_z = min(b[4] for b in boxes), max(b[5] for b in boxes)
        summary[level] = f"ancho {high_x - low_x:.1f}, frente {low_y:.1f}, fondo {high_y:.1f}, alto {high_z:.1f}"
        if max(abs(low_x), abs(high_x)) > LOT_HALF_WIDTH + EPSILON:
            problems.append(f"nivel {level}: se sale del solar a lo ancho ({low_x:.1f} a {high_x:.1f})")
        if low_y < FRONT_LIMIT - EPSILON:
            problems.append(f"nivel {level}: invade la franja del marcador (frente en {low_y:.1f})")
        if high_y > BACK_LIMIT + EPSILON:
            problems.append(f"nivel {level}: se sale por el fondo ({high_y:.1f})")
        if low_z < -EPSILON:
            problems.append(f"nivel {level}: baja del suelo ({low_z:.1f})")
        if high_z > height_limit + EPSILON:
            problems.append(f"nivel {level}: {high_z:.1f} de alto supera {height_limit}")
        if level == 0 and high_z < MIN_BODY_HEIGHT:
            problems.append(f"nivel 0: {high_z:.1f} de alto es más bajo que una planta")

    for level, text in summary.items():
        print(f"NIVEL {level}: {text}")
    print(f"TRIANGULOS: {total}; LOD1: {stats['lod1']['triangulos']}; PIEZAS: {len(keys)}")
    if problems:
        for problem in problems:
            print("PROBLEMA:", problem)
        print("CHECK FAIL")
        sys.exit(1)
    print("CHECK OK")


if __name__ == "__main__":
    main()

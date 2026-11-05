"""Bodega La Reserva y ficha taxi: el resto de mallas propias de la porción vertical.

La bodega sigue las reglas del Cine Lux (R-P50): cuerpo fijo y un añadido por nivel, con una malla por
material porque en Roblox cada malla lleva uno solo. Solo se dibuja a escala; la aprobación es en el juego.

Uso: blender --background --factory-startup --python art/blender/slice/build_slice_props.py
"""

import json
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_cine_lux import HERE, box, count, export, flat, join, lod_of, perforate, textured, uv_unwrap  # noqa: E402

WIDTH = 32.0
DEPTH = 18.0
HEIGHT = 13.0


def by_material(parts, prefix):
    groups = {}
    for part in parts:
        groups.setdefault(part.data.materials[0].name.split(".")[0], []).append(part)
    meshes = []
    for material, members in groups.items():
        mesh = join(members, f"{prefix}_{material}")
        uv_unwrap(mesh)
        meshes.append(mesh)
    return meshes


def build_base(mats):
    """Nave baja de ladrillo con portalón de carga, ventanas altas y tejado de dos niveles."""
    front = -DEPTH / 2
    parts, cutters = [], []
    wall = box("wall", (WIDTH, DEPTH, HEIGHT), (0, 0, HEIGHT / 2), mats["brick"])
    for x in (-10.5, 10.5):
        cutters.append(box("win_cut", (5.0, 2.0, 3.6), (x, front, 8.2)))
        parts.append(box("win", (5.0, 0.1, 3.6), (x, front + 0.55, 8.2), mats["glass"]))
        parts.append(box("win_sill", (5.6, 0.5, 0.25), (x, front - 0.1, 6.3), mats["stone"]))
        parts.append(box("win_head", (5.6, 0.4, 0.4), (x, front - 0.05, 10.2), mats["stone"]))
        parts.append(box("win_bar", (0.15, 0.2, 3.6), (x, front + 0.3, 8.2), mats["dark"]))
    cutters.append(box("door_cut", (9.0, 2.0, 7.4), (0, front, 3.7)))
    perforate(wall, cutters)
    # Portalón de madera con dintel de caliza: es lo que la distingue de una tienda.
    parts.append(box("door", (9.0, 0.2, 7.4), (0, front + 0.5, 3.7), mats["wood"]))
    for x in (-2.25, 0.0, 2.25):
        parts.append(box("door_plank", (0.18, 0.3, 7.4), (x, front + 0.35, 3.7), mats["dark"]))
    parts.append(box("lintel", (10.4, 0.8, 1.0), (0, front - 0.1, 7.9), mats["stone"]))
    parts.append(box("plinth", (WIDTH + 0.2, DEPTH + 0.2, 0.8), (0, 0, 0.4), mats["stone"]))
    parts.append(box("cornice", (WIDTH + 0.7, DEPTH + 0.7, 0.6), (0, 0, HEIGHT + 0.1), mats["stone"]))
    # Barricas junto al portalón: el rótulo es el nombre pintado en el asfalto.
    for x, y in ((-7.0, front - 1.2), (-5.0, front - 1.2), (7.0, front - 1.2)):
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.9, depth=2.0, location=(x, y, 1.0))
        barrel = bpy.context.active_object
        barrel.data.materials.append(mats["wood"])
        parts.append(barrel)
    # Cubierta: lo que ve la cámara del turno.
    parts.append(box("roof", (WIDTH - 0.8, DEPTH - 0.8, 0.5), (0, 0, HEIGHT + 0.45), mats["slate"]))
    parts.append(box("ridge", (WIDTH - 6.0, 5.0, 2.2), (0, 2.0, HEIGHT + 1.8), mats["slate"]))
    for x in (-9.0, 0.0, 9.0):
        parts.append(box("vent", (1.6, 1.6, 1.2), (x, -5.0, HEIGHT + 1.2), mats["slate"]))
    wall.name = "bodega_wall"
    return [wall] + by_material(parts, "bodega_base")


def build_addons(mats):
    front = -DEPTH / 2
    levels = {
        1: [
            box("awning", (10.0, 2.0, 0.2), (0, front - 1.0, 8.9), mats["red"]),
            box("crate", (2.2, 1.6, 1.6), (9.5, front - 1.2, 0.8), mats["wood"]),
        ],
        2: [
            box("board", (12.0, 0.4, 1.6), (0, front - 0.15, 11.4), mats["cream"]),
            box("lamp_l", (0.4, 1.0, 0.4), (-7.5, front - 0.5, 11.4), mats["steel"]),
            box("lamp_r", (0.4, 1.0, 0.4), (7.5, front - 0.5, 11.4), mats["steel"]),
        ],
        3: [
            box("storey", (20.0, 12.0, 5.0), (0, 2.0, HEIGHT + 3.2), mats["brick"]),
            box("storey_top", (20.6, 12.6, 0.5), (0, 2.0, HEIGHT + 5.9), mats["stone"]),
            box("storey_win_l", (3.0, 0.12, 2.6), (-5.0, -4.06, HEIGHT + 3.2), mats["glass"]),
            box("storey_win_r", (3.0, 0.12, 2.6), (5.0, -4.06, HEIGHT + 3.2), mats["glass"]),
        ],
        4: [
            box("canopy", (14.0, 4.0, 0.5), (0, front - 2.0, 8.8), mats["steel"]),
            box("canopy_band", (14.3, 4.3, 0.15), (0, front - 2.0, 9.15), mats["gold"]),
            box("post_l", (0.3, 0.3, 8.6), (-6.6, front - 3.7, 4.3), mats["steel"]),
            box("post_r", (0.3, 0.3, 8.6), (6.6, front - 3.7, 4.3), mats["steel"]),
        ],
        5: [
            box("tower", (8.0, 8.0, 9.0), (0, 2.0, HEIGHT + 10.6), mats["stone"]),
            box("tower_band", (8.5, 8.5, 0.25), (0, 2.0, HEIGHT + 15.2), mats["gold"]),
            box("tower_cap", (5.0, 5.0, 1.2), (0, 2.0, HEIGHT + 15.9), mats["steel"]),
        ],
    }
    return {level: by_material(parts, f"bodega_addon{level}") for level, parts in levels.items()}


def build_taxi(mats):
    """Ficha taxi sobre su peana: mide 9 de alto, como el cuerpo, y el avatar va encima."""
    parts = [
        box("plinth", (6.0, 6.0, 1.0), (0, 0, 0.5), mats["dark"]),
        box("stem", (2.0, 2.0, 2.0), (0, 0, 2.0), mats["steel"]),
        box("chassis", (4.6, 8.0, 1.5), (0, 0, 3.75), mats["taxi"]),
        box("hood", (4.4, 2.0, 0.3), (0, -2.9, 4.65), mats["taxi"]),
        box("cabin", (4.0, 4.2, 1.6), (0, 0.3, 5.3), mats["glass"]),
        box("roof", (4.2, 4.4, 0.3), (0, 0.3, 6.25), mats["taxi"]),
        box("sign", (1.8, 0.8, 0.6), (0, 0.3, 6.7), mats["cream"]),
        box("bumper_f", (4.8, 0.3, 0.4), (0, -4.1, 3.4), mats["steel"]),
        box("bumper_b", (4.8, 0.3, 0.4), (0, 4.1, 3.4), mats["steel"]),
        box("mount", (3.0, 3.0, 2.0), (0, 0.3, 8.0), mats["dark"]),
    ]
    for x in (-2.4, 2.4):
        for y in (-2.6, 2.6):
            parts.append(box("wheel", (0.7, 1.7, 1.7), (x, y, 3.3), mats["dark"]))
    return by_material(parts, "taxi")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "NONE"
    bpy.context.scene.unit_settings.scale_length = 1.0
    mats = {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "stone": textured("limestone", "concrete", "D2C9B4"),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "steel": flat("steel", "A8AEB4", 0.25, 0.8),
        "gold": flat("gold", "C9A227", 0.3, 0.9),
        "red": flat("red", "C4382B", 0.7),
        "cream": flat("cream", "EDE5D3", 0.6),
        "slate": flat("slate", "4A4E54", 0.85),
        "dark": flat("dark", "2A2E33", 0.6),
        "wood": flat("wood", "6B4A2E", 0.8),
        "taxi": flat("taxi", "F5C518", 0.35),
    }
    base = build_base(mats)
    addons = build_addons(mats)
    taxi = build_taxi(mats)
    stats = {}
    for mesh in base + [m for ms in addons.values() for m in ms] + taxi:
        export(mesh, f"{mesh.name}.fbx")
    stats["bodega"] = sum(count(m) for m in base + [m for ms in addons.values() for m in ms])
    stats["taxi"] = sum(count(m) for m in taxi)
    bodega_lod = lod_of(base + [m for ms in addons.values() for m in ms], "bodega_LOD1")
    taxi_lod = lod_of(taxi, "taxi_LOD1")
    export(bodega_lod, "bodega_LOD1.fbx")
    export(taxi_lod, "taxi_LOD1.fbx")
    stats["bodega_lod"] = count(bodega_lod)
    stats["taxi_lod"] = count(taxi_lod)
    with open(os.path.join(HERE, "slice-props-stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2)
    print("PROPS_STATS", json.dumps(stats))


if __name__ == "__main__":
    main()

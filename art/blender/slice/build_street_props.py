"""Mobiliario de la manzana: árbol, farola, banco y paso de cebra.

Son piezas que se repiten mucho, así que importan más que cualquier edificio suelto: una malla por material,
el origen en el centro de la base y el frente hacia -Y, que es lo que `lookAt` deja mirando a la calle.
Medidas a la escala de art/escala.md: la planta baja mide 7 studs.

Uso: blender --background --factory-startup --python art/blender/slice/build_street_props.py
"""

import json
import math
import os
import random
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_cine_lux import HERE, box, count, export, flat, lod_of  # noqa: E402
from build_slice_props import by_material, profile  # noqa: E402


def cylinder(radius1, radius2, depth, location, mat, vertices=8, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=radius1, radius2=radius2, depth=depth, location=location, rotation=rotation
    )
    obj = bpy.context.active_object
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    obj.data.materials.append(mat)
    return obj


def blob(radius, location, mat, squash=0.8):
    """Masa de hojas: una esfera deformada para que la copa no parezca hecha de bolas."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=radius, location=location)
    obj = bpy.context.active_object
    for vertex in obj.data.vertices:
        vertex.co *= 1 + random.uniform(-0.16, 0.16)
        vertex.co.z *= squash
    obj.data.materials.append(mat)
    return obj


def build_tree(mats):
    """Árbol de alineación en su alcorque, con el tronco despejado para no tapar la calle."""
    random.seed(7)
    parts = [
        cylinder(0.55, 0.32, 8.5, (0, 0, 4.25), mats["bark"]),
        # Dos ramas que entran en la copa: desde abajo se ve que el tronco la sostiene.
        cylinder(0.3, 0.14, 3.6, (0.9, 0.2, 8.4), mats["bark"], 6, (0, math.radians(32), 0)),
        cylinder(0.3, 0.14, 3.4, (-0.8, -0.4, 8.6), mats["bark"], 6, (math.radians(16), math.radians(-28), 0)),
        blob(4.2, (0, 0, 12.6), mats["leaf"]),
        blob(3.0, (2.7, 0.8, 11.0), mats["leaf"]),
        blob(2.9, (-2.6, -1.1, 11.2), mats["leaf"]),
        blob(2.6, (0.5, -2.7, 11.0), mats["leaf"]),
        blob(2.6, (-0.6, 2.7, 11.4), mats["leaf"]),
        blob(2.5, (0.4, 0.2, 15.3), mats["leaf"]),
        box("soil", (2.7, 2.7, 0.08), (0, 0, 0.04), mats["soil"]),
    ]
    # Alcorque de piedra, a ras de acera.
    for x, y, sx, sy in ((0, -1.5, 3.3, 0.3), (0, 1.5, 3.3, 0.3), (-1.5, 0, 0.3, 2.7), (1.5, 0, 0.3, 2.7)):
        parts.append(box("curb", (sx, sy, 0.16), (x, y, 0.08), mats["stone"]))
    return by_material(parts, "tree")


def build_lamp(mats):
    """Farola de hierro de brazo curvo: la linterna cae sobre la calzada, a -Y."""
    iron, shade = mats["iron"], mats["lamp"]
    parts = [
        cylinder(0.55, 0.42, 1.0, (0, 0, 0.5), iron, 8),
        cylinder(0.34, 0.34, 0.2, (0, 0, 1.1), iron, 8),
        cylinder(0.24, 0.13, 12.6, (0, 0, 7.3), iron, 8),
        cylinder(0.2, 0.2, 0.18, (0, 0, 6.0), iron, 8),
    ]
    # Brazo: tramos cortos que dibujan la curva.
    points = [(0.0, 13.5), (-0.6, 14.05), (-1.4, 14.35), (-2.3, 14.4), (-3.0, 14.2)]
    for (y1, z1), (y2, z2) in zip(points, points[1:]):
        length = math.hypot(y2 - y1, z2 - z1)
        tilt = math.atan2(y2 - y1, z2 - z1)
        parts.append(cylinder(0.1, 0.1, length, (0, (y1 + y2) / 2, (z1 + z2) / 2), iron, 6, (-tilt, 0, 0)))
    parts.append(cylinder(0.85, 0.2, 0.55, (0, -3.0, 13.95), iron, 10))
    parts.append(cylinder(0.5, 0.62, 0.7, (0, -3.0, 13.4), shade, 10))
    return by_material(parts, "lamp")


def build_bench(mats):
    """Banco de listones con patas de hierro. Se sienta mirando a la calle."""
    wood, iron = mats["wood"], mats["iron"]
    parts = []
    for y in (-0.55, -0.2, 0.15, 0.5):
        parts.append(box("seat", (5.6, 0.28, 0.14), (0, y, 1.5), wood))
    for z in (2.15, 2.6, 3.05):
        parts.append(box("back", (5.6, 0.12, 0.3), (0, 0.78, z), wood))
    for x in (-2.3, 2.3):
        parts.append(box("leg_front", (0.16, 0.16, 1.45), (x, -0.55, 0.72), iron))
        parts.append(box("leg_back", (0.16, 0.16, 3.2), (x, 0.72, 1.6), iron))
        parts.append(box("rail", (0.16, 1.5, 0.14), (x, 0.08, 1.38), iron))
        parts.append(box("arm", (0.16, 1.4, 0.12), (x + (0.0), 0.05, 2.3), iron))
        parts.append(box("arm_post", (0.14, 0.14, 0.85), (x, -0.55, 1.9), iron))
    return by_material(parts, "bench")


def build_crosswalk(mats):
    """Cebra de lado a lado de la calzada, que mide 34. Las bandas siguen el sentido de la marcha."""
    parts = [box("band", (7.0, 1.3, 0.06), (0, -15.0 + order * 2.5, 0.03), mats["paint"]) for order in range(13)]
    return by_material(parts, "crosswalk")


def build_car(mats):
    """Sedán de tráfico, más bajo que el taxi y sin rótulo ni damero: no se confunde con una ficha."""
    parts = [
        profile(
            "body",
            [(-5.6, 0.8), (-5.6, 2.0), (-5.1, 2.4), (-2.7, 2.7), (-1.2, 4.3), (2.1, 4.3), (3.7, 2.8), (5.3, 2.6), (5.6, 2.0), (5.6, 0.8)],
            2.8,
            mats["car"],
        ),
        profile("cabin", [(-2.55, 2.78), (-1.12, 4.12), (2.02, 4.12), (3.5, 2.85)], 2.85, mats["glass"]),
        box("bumper_f", (5.7, 0.35, 0.5), (0, -5.7, 1.2), mats["dark"]),
        box("bumper_b", (5.7, 0.35, 0.5), (0, 5.7, 1.2), mats["dark"]),
        box("light_l", (1.0, 0.1, 0.35), (-1.9, -5.62, 1.95), mats["steel"]),
        box("light_r", (1.0, 0.1, 0.35), (1.9, -5.62, 1.95), mats["steel"]),
    ]
    for x in (-2.6, 2.6):
        for y in (-3.4, 3.4):
            bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.95, depth=0.8, location=(x, y, 0.95), rotation=(0, math.radians(90), 0))
            wheel = bpy.context.active_object
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
            wheel.data.materials.append(mats["dark"])
            parts.append(wheel)
            parts.append(box("hub", (0.84, 0.7, 0.7), (x, y, 0.95), mats["steel"]))
    return by_material(parts, "car")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "NONE"
    bpy.context.scene.unit_settings.scale_length = 1.0
    mats = {
        "bark": flat("bark", "4A3A2C", 0.9),
        "leaf": flat("leaf", "4B6B3A", 0.9),
        "soil": flat("soil", "2F2A25", 1.0),
        "stone": flat("limestone", "D2C9B4", 0.8),
        "iron": flat("iron", "23282B", 0.5, 0.7),
        "lamp": flat("lamp", "EDE5D3", 0.4),
        "wood": flat("wood", "7A5433", 0.8),
        "paint": flat("paint", "DED8C8", 0.8),
        "car": flat("carbody", "34465E", 0.35),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "dark": flat("dark", "2A2E33", 0.6),
        "steel": flat("steel", "A8AEB4", 0.25, 0.8),
    }
    stats = {}
    for name, builder in (
        ("tree", build_tree),
        ("lamp", build_lamp),
        ("bench", build_bench),
        ("crosswalk", build_crosswalk),
        ("car", build_car),
    ):
        meshes = builder(mats)
        stats[name] = sum(count(mesh) for mesh in meshes)
        for mesh in meshes:
            export(mesh, f"{mesh.name}.fbx")
        lod = lod_of(meshes, f"{name}_LOD1")
        export(lod, f"{name}_LOD1.fbx")
        stats[f"{name}_lod"] = count(lod)
    with open(os.path.join(HERE, "street-props-stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2)
    print("STREET_STATS", json.dumps(stats))


if __name__ == "__main__":
    main()

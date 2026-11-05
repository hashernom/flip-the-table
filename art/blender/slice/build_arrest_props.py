"""Escena de arresto: coche patrulla, accesorio de gorra de policía y cárcel.

El coche sigue las reglas de build_street_props y build_slice_props: una malla por material,
el origen en el centro de la base y el frente hacia -Y. La gorra es un accesorio: se monta sobre la cabeza
de un avatar de Roblox, que el código construye por partes, así que su origen está en la base de la gorra
(z = 0 donde apoya sobre la cabeza). Medidas en studs.

Salidas, en art/blender/slice/:
  patrol_{navy,white,glass,dark,steel,sirenred,sirenblue}.fbx y patrol_LOD1.fbx
  officer_{cap,gold}.fbx y officer_LOD1.fbx
  jail_{brick,limestone,glass,steel,dark,sign}.fbx y jail_LOD1.fbx
  arrest-props-stats.json   triángulos reales

Y en art/render/: patrol.png, officer.png y jail.png, solo para revisión técnica.

Uso: blender --background --factory-startup --python art/blender/slice/build_arrest_props.py
"""

import json
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_cine_lux import HERE, box, camera, count, export, flat, letters, lod_of, perforate, render, srgb, textured  # noqa: E402
from build_slice_props import by_material, profile  # noqa: E402

BUDGET = {"patrol": 2000, "officer": 2000, "jail": 10000}
JAIL_WIDTH = 30.0
JAIL_DEPTH = 16.0
JAIL_HEIGHT = 14.0


def emissive(name, hex_color):
    """Luz de la sirena: color plano con un poco de emisión para que se lea en el render."""
    mat = flat(name, hex_color, 0.2)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Emission Color"].default_value = (*srgb(hex_color), 1)
    bsdf.inputs["Emission Strength"].default_value = 2.0
    return mat


def cylinder(radius, depth, location, mat, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.data.materials.append(mat)
    return obj


def wheel(x, y, mats):
    """Rueda en el plano X-Z, con el eje a lo ancho, como en build_car."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.95, depth=0.8, location=(x, y, 0.95), rotation=(0, math.radians(90), 0))
    obj = bpy.context.active_object
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    obj.data.materials.append(mats["dark"])
    return obj


def build_patrol(mats):
    """Sedán azul marino con puertas y capó blancos, franja blanca y barra de sirenas: 11.4 de largo, 4.4 de alto."""
    navy, white = mats["navy"], mats["white"]
    body = [(-5.5, 0.9), (-5.5, 2.2), (-5.0, 2.6), (-2.7, 2.7), (3.3, 2.7), (5.0, 2.6), (5.5, 2.2), (5.5, 0.9)]
    cabin = [(-2.6, 2.7), (-1.2, 3.95), (1.9, 3.95), (3.3, 2.7)]
    parts = [
        profile("body", body, 2.9, navy),
        profile("cabin", cabin, 2.62, mats["glass"]),
        box("hood", (5.3, 2.7, 0.3), (0, -4.15, 2.72), white),
        box("bumper_f", (5.2, 0.2, 0.7), (0, -5.6, 1.0), mats["dark"]),
        box("bumper_b", (5.2, 0.2, 0.7), (0, 5.6, 1.0), mats["dark"]),
        box("light_l", (0.9, 0.1, 0.35), (-1.9, -5.55, 1.95), mats["steel"]),
        box("light_r", (0.9, 0.1, 0.35), (1.9, -5.55, 1.95), mats["steel"]),
        # Barra de sirenas sobre el techo: dos mitades separadas para que el código las haga parpadear.
        box("siren_base", (2.6, 1.5, 0.1), (0, -0.1, 4.0), mats["dark"]),
        box("siren_red", (1.3, 1.4, 0.35), (-0.65, -0.1, 4.225), mats["sirenred"]),
        box("siren_blue", (1.3, 1.4, 0.35), (0.65, -0.1, 4.225), mats["sirenblue"]),
    ]
    for side in (-1, 1):
        parts.append(box("door", (0.12, 3.6, 1.65), (side * 2.96, -0.5, 1.78), white))
        parts.append(box("stripe", (0.1, 11.0, 0.3), (side * 2.95, 0.0, 1.7), white))
    for x in (-2.5, 2.5):
        for y in (-3.4, 3.4):
            parts.append(wheel(x, y, mats))
            parts.append(box("hub", (0.84, 0.7, 0.7), (x, y, 0.95), mats["steel"]))
    return by_material(parts, "patrol")


def build_officer(mats):
    """Gorra de plato con su placa dorada. Origen en la base de la gorra; la visera mira a -Y."""
    cap, gold = mats["cap"], mats["gold"]
    parts = [
        cylinder(1.2, 0.55, (0, 0, 0.275), cap, 16),
        cylinder(1.22, 0.12, (0, 0, 0.06), cap, 16),
        box("visor", (2.0, 1.0, 0.06), (0, -1.05, 0.03), cap),
        box("badge", (0.7, 0.08, 0.4), (0, -1.22, 0.3), gold),
    ]
    return by_material(parts, "officer")


def build_jail(mats):
    """Cárcel y comisaría de ladrillo oscuro: ventanas con barrotes, portón central y rótulo en 3D."""
    front = -JAIL_DEPTH / 2
    window_xs = (-10.0, -5.5, 5.5, 10.0)
    parts, cutters = [], []
    wall = box("wall", (JAIL_WIDTH, JAIL_DEPTH, JAIL_HEIGHT), (0, 0, JAIL_HEIGHT / 2), mats["brick"])
    for x in window_xs:
        cutters.append(box("win_cut", (1.4, 2.0, 3.2), (x, front, 8.0)))
    cutters.append(box("gate_cut", (7.0, 2.0, 6.0), (0, front, 3.0)))
    perforate(wall, cutters)
    parts.append(wall)
    for x in window_xs:
        parts.append(box("glass", (1.2, 0.1, 3.2), (x, front + 0.5, 8.0), mats["glass"]))
        for dx in (-0.4, 0.0, 0.4):
            parts.append(box("bar", (0.12, 0.2, 3.2), (x + dx, front + 0.35, 8.0), mats["steel"]))
        parts.append(box("rail", (1.4, 0.2, 0.12), (x, front + 0.35, 8.0), mats["steel"]))
        parts.append(box("sill", (1.9, 0.6, 0.3), (x, front - 0.2, 6.35), mats["limestone"]))
        parts.append(box("head", (1.9, 0.5, 0.35), (x, front - 0.15, 9.75), mats["limestone"]))
    # Portón de garaje: hoja oscura con tres juntas, marco de caliza y dintel.
    parts.append(box("gate", (7.0, 0.3, 6.0), (0, front + 0.5, 3.0), mats["dark"]))
    for z in (1.5, 3.0, 4.5):
        parts.append(box("gate_slat", (7.0, 0.35, 0.15), (0, front + 0.45, z), mats["dark"]))
    for x in (-3.75, 3.75):
        parts.append(box("gate_frame", (0.5, 0.5, 6.0), (x, front - 0.1, 3.0), mats["limestone"]))
    parts.append(box("gate_lintel", (9.0, 0.7, 1.0), (0, front - 0.2, 6.5), mats["limestone"]))
    # Zócalo, cornisa y tejado.
    parts.append(box("plinth", (JAIL_WIDTH + 0.4, JAIL_DEPTH + 0.4, 0.9), (0, 0, 0.45), mats["limestone"]))
    parts.append(box("cornice", (JAIL_WIDTH + 0.8, JAIL_DEPTH + 0.8, 0.6), (0, 0, 13.9), mats["limestone"]))
    parts.append(box("roof", (JAIL_WIDTH - 0.6, JAIL_DEPTH - 0.6, 0.4), (0, 0, 14.4), mats["dark"]))
    # Placa de rótulo sobre el portón con el texto en 3D.
    parts.append(box("sign_plate", (9.2, 0.3, 2.4), (0, front - 0.15, 11.0), mats["limestone"]))
    parts.append(letters("CÁRCEL", 1.8, (0, front - 0.3, 11.0), mats["sign"], 0.25))
    return by_material(parts, "jail")


def stage(mats):
    """Suelo, sol y fondo para el render de revisión; igual que build_cine_lux."""
    scene = bpy.context.scene
    floor = box("floor", (40.0, 40.0, 0.2), (0, 0, -0.1), mats["floor"])
    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 4.2
    sun_data.angle = math.radians(1.0)
    sun = bpy.data.objects.new("sun", sun_data)
    bpy.context.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(90 - 34), 0, math.radians(-38))
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.68, 0.78, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.cycles.device = "CPU"
    scene.view_settings.look = "AgX - Medium High Contrast"
    return floor


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    scene.unit_settings.scale_length = 1.0
    mats = {
        "navy": flat("navy", "1B2A4A", 0.35),
        "white": flat("white", "F2F2F0", 0.4),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "dark": flat("dark", "2A2E33", 0.6),
        "steel": flat("steel", "A8AEB4", 0.25, 0.8),
        "sirenred": emissive("sirenred", "D62828"),
        "sirenblue": emissive("sirenblue", "1F5FD6"),
        "cap": flat("cap", "1B2A4A", 0.5),
        "gold": flat("gold", "C9A227", 0.3, 0.9),
        "skin": flat("skin", "E0B48A", 0.6),
        "brick": textured("brick", "brick_warm", "5E3A2E"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "sign": flat("sign", "C4382B", 0.6),
        "floor": flat("floor", "A39C8E", 0.9),
    }

    stats = {}
    models = {}
    for name, builder in (("patrol", build_patrol), ("officer", build_officer), ("jail", build_jail)):
        meshes = builder(mats)
        lod = lod_of(meshes, f"{name}_LOD1")
        per_mesh = {mesh.name: count(mesh) for mesh in meshes}
        total = sum(per_mesh.values())
        lod_total = count(lod)
        assert total <= BUDGET[name], f"{name} supera el presupuesto: {total}"
        assert lod_total < total, f"el LOD de {name} no es menor: {lod_total} >= {total}"
        for mesh in meshes:
            export(mesh, f"{mesh.name}.fbx")
        export(lod, f"{name}_LOD1.fbx")
        stats[name] = {"triangles": total, "meshes": per_mesh, "lod_triangles": lod_total}
        models[name] = meshes

    # Cabeza de referencia solo para el render de la gorra: no se exporta.
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.0, location=(0, 0, -1.0))
    head = bpy.context.active_object
    head.name = "head_ref"
    head.data.materials.append(mats["skin"])

    floor = stage(mats)
    views = (
        ("patrol", "patrol.png", camera("patrol_cam", (-9.0, -17.0, 7.0), (0, 0, 2.2), 42), 1280, 720),
        ("officer", "officer.png", camera("officer_cam", (-2.6, -7.0, 1.9), (0, 0, -0.45), 80), 1000, 1000),
        ("jail", "jail.png", camera("jail_cam", (-20.0, -40.0, 13.0), (0, -2.0, 6.0), 40), 1600, 900),
    )
    for name, filename, cam, width, height in views:
        for model, meshes in models.items():
            for mesh in meshes:
                mesh.hide_render = model != name
        head.hide_render = name != "officer"
        # El suelo tapa la cabeza de referencia: en la vista de la gorra se quita.
        floor.hide_render = name == "officer"
        scene.render.resolution_x = width
        scene.render.resolution_y = height
        render(scene, cam, filename)

    with open(os.path.join(HERE, "arrest-props-stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("ARREST_STATS", json.dumps(stats))


if __name__ == "__main__":
    main()

"""Utilidades comunes de los barrios de Metrópolis (plan 07, Tarea 1).

Un barrio se modela en su propio guion (`centro.py`, `puerto.py`, ...) y comparte aquí todo lo que
no es diseño: el lienzo, el agrupado por material, la versión de menor detalle, la exportación y el
registro de triángulos. Así los cuatro barrios se construyen igual y se comparan de verdad.

Reglas que no se tocan aquí y vienen de `art/PIPELINE.md` y `art/escala.md`:

- 1 unidad de Blender = 1 stud.
- El origen de cada pieza va en el centro de su base y a ras de suelo.
- El frente de la pieza mira a **-Y**: es el lado que se pone hacia la calle con `CFrame.lookAt`.
- Una malla, un material: en Roblox cada malla lleva uno solo, así que se agrupa por material y cada
  grupo se exporta aparte.

Uso: `blender --background --factory-startup --python art/blender/city/centro.py`
"""

import json
import math
import os
import random
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
RENDER = os.path.join(REPO, "art", "render")
SLICE = os.path.abspath(os.path.join(HERE, "..", "slice"))

sys.path.insert(0, SLICE)
from build_cine_lux import LOD_RATIO, flat, srgb  # noqa: E402,F401


def reset_scene():
    """Lienzo vacío a la escala del juego: 1 unidad es 1 stud.

    Vacía la escena **y** los materiales: `read_factory_settings` borra los datablocks, así que la
    paleta se crea después o las referencias quedan muertas.
    """
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    scene.unit_settings.scale_length = 1.0
    MATS.clear()
    for name, (color, roughness, metallic) in PALETTE.items():
        MATS[name] = flat(name, color, roughness, metallic)
    return scene


def select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.hide_viewport = False
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_modifiers(obj):
    select_only(obj)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)


def box(name, size, location, mat=None, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    if rotation is not None:
        obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if mat is not None:
        obj.data.materials.append(mat)
    return obj


def prism(name, radius1, radius2, depth, location, mat, vertices=8, rotation=None):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius1,
        radius2=radius2,
        depth=depth,
        location=location,
        rotation=rotation or (0, 0, 0),
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    obj.data.materials.append(mat)
    return obj


def sphere(name, radius, location, mat, subdivisions=1, squash=1.0, jitter=0.0, seed=0):
    """Masa redonda barata: subdivisión 1 son 80 triángulos, que es lo que aguanta un objeto repetido."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = name
    if jitter or squash != 1.0:
        rng = random.Random(seed)
        for vertex in obj.data.vertices:
            scale = 1.0 + (rng.uniform(-jitter, jitter) if jitter else 0.0)
            vertex.co *= scale
            vertex.co.z *= squash
    obj.data.materials.append(mat)
    return obj


def tube(name, a, b, radius, mat, vertices=6):
    """Cilindro entre dos puntos: brazos, barrotes y tirantes sin calcular ángulos a mano."""
    start, end = Vector(a), Vector(b)
    middle = (start + end) / 2
    length = (end - start).length
    direction = (end - start).normalized()
    rotation = direction.to_track_quat("Z", "Y").to_euler()
    return prism(name, radius, radius, length, middle, mat, vertices, rotation)


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return joined


def count(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def uv_unwrap(obj, cube_size=2.4):
    select_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=cube_size)
    bpy.ops.object.mode_set(mode="OBJECT")


def by_material(parts, prefix):
    """Una malla por material, con UV de cubo: es lo que viaja a Roblox."""
    groups = {}
    for part in parts:
        if not part.data.materials:
            raise ValueError(f"{part.name} no tiene material")
        key = part.data.materials[0].name.split(".")[0]
        groups.setdefault(key, []).append(part)
    meshes = []
    for material, members in groups.items():
        mesh = join(sorted(members, key=lambda item: item.name), f"{prefix}_{material}")
        mesh.name = f"{prefix}_{material}"
        uv_unwrap(mesh)
        meshes.append(mesh)
    return sorted(meshes, key=lambda item: item.name)


def lod_of(sources, name, ratio=LOD_RATIO):
    """Versión de menor detalle: copia, decima y une. No se dibuja; solo cuenta para el presupuesto."""
    copies = []
    for source in sources:
        copy = source.copy()
        copy.data = source.data.copy()
        copy.name = f"{source.name}_copy"
        bpy.context.collection.objects.link(copy)
        decimate = copy.modifiers.new("Decimate", "DECIMATE")
        decimate.ratio = ratio
        apply_modifiers(copy)
        copies.append(copy)
    lod = join(copies, name)
    lod.hide_render = True
    return lod


def export(obj, folder, filename):
    select_only(obj)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(folder, filename),
        use_selection=True,
        apply_scale_options="FBX_SCALE_UNITS",
        axis_forward="Z",
        axis_up="Y",
        bake_anim=False,
        add_leaf_bones=False,
    )


def save_blend(path):
    bpy.ops.wm.save_as_mainfile(filepath=path)


def render_preview(name, location, target, lens=42):
    """Imagen de revisión técnica, no de aprobación: sirve para juzgar volumen y silueta."""
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    scene.render.film_transparent = False

    data = bpy.data.cameras.new(name)
    data.lens = lens
    camera = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(camera)
    camera.location = location
    camera.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera

    scene.render.filepath = os.path.join(RENDER, name)
    bpy.ops.render.render(write_still=True)


def sun(elevation=34.0, azimuth=-38.0, energy=4.2, sky=0.85):
    """El sol de `art/luz.md`: 34° de elevación, luz de día."""
    data = bpy.data.lights.new("sun", "SUN")
    data.energy = energy
    data.angle = math.radians(1.0)
    obj = bpy.data.objects.new("sun", data)
    bpy.context.collection.objects.link(obj)
    obj.rotation_euler = (math.radians(90 - elevation), 0, math.radians(azimuth))

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.68, 0.78, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = sky
    bpy.context.scene.world = world
    return obj


def build_assets(barrio, builders, backdrops, folder, blend_name):
    """Construye, exporta y cuenta. Devuelve el resumen para el manifiesto."""
    stats = {}
    scene_objects = []

    for name, builder in builders:
        parts = builder(MATS)
        meshes = by_material(parts, name)
        total = sum(count(mesh) for mesh in meshes)
        for mesh in meshes:
            export(mesh, folder, f"{mesh.name}.fbx")
        lod = lod_of(meshes, f"{name}_LOD1")
        export(lod, folder, f"{name}_LOD1.fbx")
        entry = {
            "triangles": total,
            "lod": count(lod),
            "pieces": [mesh.name for mesh in meshes],
        }
        stats[name] = entry
        scene_objects.extend(meshes)
        print(f"BUILT {name}: {total} triángulos, {len(meshes)} mallas, LOD {entry['lod']}")

    for name, builder in backdrops:
        parts = builder(MATS)
        meshes = by_material(parts, name)
        total = sum(count(mesh) for mesh in meshes)
        for mesh in meshes:
            export(mesh, folder, f"{mesh.name}.fbx")
        stats[name] = {
            "triangles": total,
            "lod": None,
            "pieces": [mesh.name for mesh in meshes],
        }
        scene_objects.extend(meshes)
        print(f"BUILT {name}: {total} triángulos, {len(meshes)} mallas")

    with open(os.path.join(folder, f"{barrio}-stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("CITY_STATS", json.dumps(stats, ensure_ascii=False))

    save_blend(os.path.join(REPO, "art", "blender", "city", blend_name))
    return stats


# La paleta de `art/guia-de-estilo.md` §2.2 y §7. La de cada barrio la completa su guion.
PALETTE = {
    "limestone": ("D2C9B4", 0.75, 0.0),
    "brick": ("B0664A", 0.85, 0.0),
    "asphalt": ("4A4E54", 0.90, 0.0),
    "steel": ("A8AEB4", 0.25, 0.8),
    "glass": ("7FB2D9", 0.12, 0.0),
    "gold": ("C9A227", 0.30, 0.9),
    "iron": ("23282B", 0.50, 0.7),
    "cream": ("EDE5D3", 0.60, 0.0),
    "slate": ("4A4E54", 0.85, 0.0),
    "wood": ("7A5433", 0.80, 0.0),
    "soil": ("2F2A25", 1.00, 0.0),
    "leaf": ("4B6B3A", 0.90, 0.0),
    "red": ("C4382B", 0.70, 0.0),
    "granite": ("9C9A94", 0.80, 0.0),
    "water": ("3E7FA6", 0.05, 0.0),
}

MATS = {}

"""Blockout de escala de la porción vertical (adelanto de la subfase 06).

Este guion es la fuente del blockout: no se edita el .blend a mano, se regenera.
1 unidad de Blender = 1 stud (Unit System = None), como indica la documentación oficial
de Roblox para Blender.

Produce, en art/blender/blockout/:
  blockout.blend          la escena, con los assets ya colocados
  blockout.fbx            la escena entera, para la prueba de importación
  assets/<id>.fbx         un FBX por asset, con el origen en el centro de su base
  blockout-stats.json     triángulos, medidas y materiales de cada asset

Y en art/render/: cuatro vistas para juzgar la escala.

Uso: blender --background --factory-startup --python art/blender/blockout/build_blockout.py
"""

import json
import math
import os

import bpy
from mathutils import Vector

# --- Escala del proyecto, en studs ------------------------------------------------------------
# La referencia es el avatar de Roblox: 6 studs de alto, unos 1,70 m.
FLOOR = 7.0  # altura de planta
STREET_WIDTH = 28.0  # calzada: tres fichas de lado a lado
SIDEWALK = 6.0  # acera a cada lado
LOT_FRONT = 18.0  # frente de solar; tres solares = 54 studs, bajo el máximo de 60 de la subfase 05
LOT_DEPTH = 22.0
TOKEN_BASE = 8.0  # diámetro de la base de una ficha
TOKEN_HEIGHT = 12.0  # altura de la ficha sin el avatar
AVATAR_HEIGHT = 6.0
EYE_RATIO = 0.85  # ojos del avatar, proporción de un cuerpo de 6 studs
TOKEN_EYE = TOKEN_HEIGHT + AVATAR_HEIGHT * EYE_RATIO

HOUSE_FLOORS = 2
OFFICE_FLOORS = 5
TOWER_FLOORS = 12

LOT_Y = STREET_WIDTH / 2 + SIDEWALK + LOT_DEPTH / 2

BLOCKOUT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(BLOCKOUT_DIR, "..", "..", ".."))
ASSETS_DIR = os.path.join(BLOCKOUT_DIR, "assets")
RENDER_DIR = os.path.join(REPO_ROOT, "art", "render")


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    # 1 unidad = 1 stud. Sin sistema de unidades, Blender no convierte nada.
    scene.unit_settings.system = "NONE"
    scene.unit_settings.scale_length = 1.0
    scene.cursor.location = (0.0, 0.0, 0.0)
    return scene


def material(name, color, metallic=0.0, roughness=0.5, emission=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission is not None:
        # Blender 4 y 5 llaman a esta entrada "Emission Color".
        socket = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        if socket is not None:
            socket.default_value = (*emission, 1.0)
        strength = bsdf.inputs.get("Emission Strength")
        if strength is not None:
            strength.default_value = emission_strength
    return mat


def box(name, size, center, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj


def cylinder(name, radius, depth, center, mat, vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=center)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def bevel(obj, width=0.35, segments=2):
    """Redondea la silueta: un cubo perfecto se lee como marcador temporal."""
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"


def join(parts, name):
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return obj


def apply_all_modifiers(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def triangle_count(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    count = len(mesh.loop_triangles)
    evaluated.to_mesh_clear()
    return count


def make_lod(obj, ratio=0.5):
    """Copia decimada: la versión de menor detalle que exige el estándar de assets.

    Se aplican primero los modificadores del original; si no, la decimación se calcula sobre la
    malla base y reduce el asset a cuatro caras, que no es un LOD sino una ruina.
    """
    lod = obj.copy()
    lod.data = obj.data.copy()
    lod.name = f"{obj.name}_LOD1"
    bpy.context.collection.objects.link(lod)
    lod.location = obj.location
    lod.parent = None
    apply_all_modifiers(lod)
    decimate = lod.modifiers.new("Decimate", "DECIMATE")
    decimate.ratio = ratio
    apply_all_modifiers(lod)
    lod.hide_render = True
    lod.hide_set(True)
    return lod


def build_house(mats):
    base = FLOOR * HOUSE_FLOORS
    parts = [
        box("house_body", (LOT_FRONT - 4, LOT_DEPTH - 6, base), (0, 0, base / 2), mats["plaster"]),
        box("house_roof", (LOT_FRONT - 3, LOT_DEPTH - 5, 1.2), (0, 0, base + 0.6), mats["tile"]),
        box("house_door", (3, 0.5, 4), (0, -(LOT_DEPTH - 6) / 2, 2), mats["gold"]),
    ]
    obj = join(parts, "house")
    bevel(obj, 0.25, 2)
    return obj


def build_office(mats):
    base = FLOOR * OFFICE_FLOORS
    parts = [
        box("office_body", (LOT_FRONT - 3, LOT_DEPTH - 4, base), (0, 0, base / 2), mats["concrete"]),
        box("office_crown", (LOT_FRONT - 4, LOT_DEPTH - 5, 1.5), (0, 0, base + 0.75), mats["metal"]),
    ]
    # Fachada acristalada: una banda de cristal por planta del lado de la calle.
    for floor in range(OFFICE_FLOORS):
        z = FLOOR * floor + FLOOR * 0.6
        parts.append(box(f"office_glass_{floor}", (LOT_FRONT - 5, 0.6, 2.6), (0, -(LOT_DEPTH - 4) / 2, z), mats["glass"]))
    obj = join(parts, "office")
    bevel(obj, 0.2, 1)
    return obj


def build_skyscraper(mats):
    total = FLOOR * TOWER_FLOORS
    parts = []
    # Tres cuerpos que se estrechan: da silueta sin salir del presupuesto de triángulos.
    tiers = [(18.0, 22.0, total * 0.55), (14.0, 18.0, total * 0.3), (10.0, 14.0, total * 0.15)]
    z = 0.0
    for index, (width, depth, height) in enumerate(tiers):
        parts.append(box(f"tower_tier_{index}", (width, depth, height), (0, 0, z + height / 2), mats["concrete"]))
        for floor in range(int(height // FLOOR)):
            zw = z + FLOOR * floor + FLOOR * 0.65
            parts.append(box(f"tower_glass_{index}_{floor}", (width - 1.5, 0.5, 2.8), (0, -depth / 2, zw), mats["glass"]))
        z += height
    # Neón vertical: el detalle que define la paleta de Metrópolis de Noche.
    parts.append(box("tower_neon", (0.8, 0.8, total * 0.8), (8.0, -10.0, total * 0.5), mats["neon"]))
    parts.append(box("tower_spire", (1.2, 1.2, 8.0), (0, 0, total + 4.0), mats["gold"]))
    obj = join(parts, "skyscraper")
    bevel(obj, 0.15, 1)
    return obj


def build_token(mats):
    stem_height = TOKEN_HEIGHT - 4.0
    body_top = TOKEN_HEIGHT - 1.2
    parts = [
        cylinder("token_base", TOKEN_BASE / 2, 1.6, (0, 0, 0.8), mats["gold"]),
        cylinder("token_stem", TOKEN_BASE / 2 - 1.0, stem_height, (0, 0, stem_height / 2 + 1.6), mats["gold"]),
        box("token_car", (5.2, 3.0, 2.2), (0, 0, body_top - 1.0), mats["taxi"]),
        box("token_cabin", (2.6, 2.6, 1.6), (0, 0, body_top + 0.4), mats["glass"]),
        box("token_light", (1.0, 0.4, 0.4), (0, -1.6, body_top - 0.6), mats["neon"]),
    ]
    obj = join(parts, "taxi-token")
    bevel(obj, 0.15, 2)
    return obj


def build_avatar(mats):
    """Referencia de escala: el avatar de 6 studs, de pie sobre la ficha."""
    parts = [
        box("avatar_legs", (2.0, 1.1, 2.0), (0, 0, 1.0), mats["denim"]),
        box("avatar_torso", (2.2, 1.2, 2.6), (0, 0, 3.4), mats["skin"]),
        box("avatar_head", (1.6, 1.6, 1.6), (0, 0, 5.2), mats["skin"]),
    ]
    return join(parts, "avatar-ref")


def build_ground(mats):
    """El suelo de la escena no es un asset: la ciudad lo genera por código en la subfase 05."""
    street_length = 200.0
    box("scenery-ground", (400.0, 400.0, 0.4), (0, 0, -0.6), mats["asphalt"])
    parts = [box("street_asphalt", (street_length, STREET_WIDTH, 0.4), (0, 0, -0.2), mats["asphalt"])]
    for side in (-1, 1):
        y = side * (STREET_WIDTH / 2 + SIDEWALK / 2)
        parts.append(box(f"street_sidewalk_{side}", (street_length, SIDEWALK, 0.6), (0, y, 0.1), mats["sidewalk"]))
    # Línea central discontinua: referencia de velocidad al recorrer la calle.
    for index in range(-6, 7):
        parts.append(box(f"street_dash_{index}", (4.0, 0.5, 0.1), (index * 14.0, 0, 0.05), mats["gold"]))
    return join(parts, "street")


def build_neighbours(mats):
    """Manzana del otro lado: no es un asset, está para que la calle se lea como calle."""
    parts = []
    for index, (x, width, height) in enumerate([(-40.0, 34.0, 46.0), (0.0, 30.0, 30.0), (42.0, 38.0, 58.0)]):
        parts.append(box(f"neighbour_{index}", (width, 18.0, height), (x, -LOT_Y, height / 2), mats["concrete"]))
    return join(parts, "scenery-south")


def build_skyline(mats):
    """Fondo de ciudad: silueta lejana, sin detalle, para medir profundidad."""
    parts = []
    specs = [
        (-70.0, 60.0, 34.0),
        (-40.0, 70.0, 52.0),
        (10.0, 66.0, 28.0),
        (48.0, 74.0, 44.0),
        (80.0, 58.0, 30.0),
    ]
    for index, (x, y, height) in enumerate(specs):
        parts.append(box(f"backdrop_{index}", (16.0, 16.0, height), (x, y, height / 2), mats["backdrop"]))
    return join(parts, "city-backdrop")


def camera(name, location, target, lens=35.0, ortho_scale=None, collection=None):
    cam_data = bpy.data.cameras.new(name)
    cam_data.lens = lens
    cam_data.clip_end = 5000.0
    if ortho_scale is not None:
        # Vista ortográfica: compara alturas sin que la perspectiva las disimule.
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = ortho_scale
    cam = bpy.data.objects.new(name, cam_data)
    (collection or bpy.context.collection).objects.link(cam)
    cam.location = location
    direction = Vector(target) - Vector(location)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return cam


def render(scene, cam, filepath, resolution=(1600, 900)):
    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    shading.show_shadows = True
    shading.show_cavity = True
    shading.background_type = "VIEWPORT"
    shading.background_color = (0.02, 0.02, 0.03)
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.camera = cam
    scene.render.filepath = filepath
    # La escena se pasa explícita: al renderizar una que no está activa, si no, sale la otra.
    bpy.ops.render.render(write_still=True, scene=scene.name)


def build_scale_sheet(assets, plate, path):
    """Hoja de escala: los assets en fila, con cámara ortográfica.

    Es la imagen con la que se aprueban proporciones: sin perspectiva, 92 studs son 92 studs
    aunque el rascacielos esté lejos. Al lado de cada edificio va una persona de 6 studs.
    """
    sheet = bpy.data.scenes.new("hoja-de-escala")
    coll = bpy.data.collections.new("hoja")
    sheet.collection.children.link(coll)

    def place(obj, x, z=0.0):
        copy = obj.copy()
        copy.parent = None
        coll.objects.link(copy)
        copy.location = (x, 0.0, z)
        copy.hide_render = False
        copy.hide_set(False)
        return copy

    house, office, skyscraper, token, avatar = assets
    place(house, 0.0)
    place(office, 34.0)
    place(skyscraper, 78.0)
    place(token, 132.0)
    place(avatar, 132.0, TOKEN_HEIGHT)
    # Una persona a pie, para saber cuánto mide de verdad cada edificio.
    place(avatar, 150.0)

    ground = plate.copy()
    ground.parent = None
    coll.objects.link(ground)
    ground.location = (75.0, 0.0, -0.6)

    cam = camera("cam_sheet", (75.0, -500.0, 55.0), (75.0, 0.0, 55.0), ortho_scale=215.0, collection=coll)

    sun_data = bpy.data.lights.new("sheet_sun", "SUN")
    sun_data.energy = 3.0
    sun = bpy.data.objects.new("sheet_sun", sun_data)
    coll.objects.link(sun)
    sun.rotation_euler = (math.radians(55), 0.0, math.radians(35))

    render(sheet, cam, path)
    return sheet


def main():
    scene = reset_scene()
    os.makedirs(ASSETS_DIR, exist_ok=True)
    os.makedirs(RENDER_DIR, exist_ok=True)

    mats = {
        "asphalt": material("asphalt_wet", (0.03, 0.03, 0.04), 0.0, 0.32),
        "sidewalk": material("sidewalk", (0.35, 0.35, 0.36), 0.0, 0.75),
        "concrete": material("concrete", (0.42, 0.42, 0.44), 0.0, 0.62),
        "glass": material("glass", (0.10, 0.22, 0.32), 0.2, 0.08),
        "metal": material("metal_polished", (0.55, 0.55, 0.58), 1.0, 0.22),
        "gold": material("gold", (0.95, 0.70, 0.18), 1.0, 0.25),
        "neon": material("neon_cyan", (0.05, 0.9, 1.0), 0.0, 0.2, (0.05, 0.9, 1.0), 6.0),
        "plaster": material("plaster", (0.55, 0.42, 0.38), 0.0, 0.8),
        "tile": material("clay_tile", (0.45, 0.22, 0.16), 0.0, 0.7),
        "taxi": material("taxi_paint", (0.95, 0.75, 0.05), 0.1, 0.35),
        "skin": material("avatar_skin", (0.62, 0.45, 0.32), 0.0, 0.6),
        "denim": material("avatar_denim", (0.16, 0.24, 0.42), 0.0, 0.7),
        "backdrop": material("backdrop", (0.08, 0.09, 0.12), 0.0, 0.9),
    }

    street = build_ground(mats)
    build_neighbours(mats)
    backdrop = build_skyline(mats)
    house = build_house(mats)
    office = build_office(mats)
    skyscraper = build_skyscraper(mats)
    token = build_token(mats)
    avatar = build_avatar(mats)

    placements = {
        "house": (house, (-LOT_FRONT, LOT_Y, 0.0)),
        "office": (office, (0.0, LOT_Y, 0.0)),
        "skyscraper": (skyscraper, (LOT_FRONT, LOT_Y, 0.0)),
        "taxi-token": (token, (-40.0, 0.0, 0.25)),
        "street": (street, (0.0, 0.0, 0.0)),
        "city-backdrop": (backdrop, (0.0, 0.0, 0.0)),
    }
    for obj, position in placements.values():
        obj.location = position

    # El avatar va encima de la ficha: al emparentar, su posición pasa a ser relativa.
    avatar.parent = token
    avatar.location = (0.0, 0.0, TOKEN_HEIGHT)

    lods = {}
    for asset_id, (obj, _) in placements.items():
        if asset_id in ("street", "city-backdrop"):
            continue
        lods[asset_id] = make_lod(obj)

    stats = {}
    for asset_id, (obj, position) in placements.items():
        dimensions = tuple(round(value, 2) for value in obj.dimensions)
        entry = {
            "id": asset_id,
            "triangles": triangle_count(obj),
            "dimensions_studs": {"x": dimensions[0], "y": dimensions[1], "z": dimensions[2]},
            "materials": sorted({slot.material.name for slot in obj.material_slots if slot.material}),
            "position": {"x": round(position[0], 2), "y": round(position[1], 2), "z": round(position[2], 2)},
        }
        if asset_id in lods:
            entry["lod_triangles"] = triangle_count(lods[asset_id])
            entry["lod_meshes"] = [lods[asset_id].name]
        stats[asset_id] = entry

    # Cámaras. La de primera persona es la cámara real del juego: va a la altura de los ojos
    # del avatar subido a la ficha, no a la de una persona.
    first_person = camera("cam_first_person", (-45.0, -6.0, 17.1), (40.0, 8.0, 11.0), lens=22.0)
    street_view = camera("cam_escala", (-78.0, -4.0, 22.0), (-2.0, 26.0, 18.0), lens=28.0)
    pedestrian = camera("cam_pedestrian", (-62.0, 12.0, 6.0), (24.0, 16.0, 16.0), lens=26.0)
    # Casi cenital: es la vista de maqueta que el juego ofrece como vista general.
    aerial = camera("cam_aerial", (30.0, 20.0, 300.0), (0.0, 6.0, 0.0), lens=40.0)

    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 3.0
    sun = bpy.data.objects.new("sun", sun_data)
    bpy.context.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(55), 0.0, math.radians(35))

    # La hoja de escala es otra escena: así la ciudad no tapa los assets.
    sheet_path = os.path.join(RENDER_DIR, "blockout-hoja-de-escala.png")
    build_scale_sheet(
        (house, office, skyscraper, token, avatar),
        bpy.data.objects["scenery-ground"],
        sheet_path,
    )

    # Sol y ambiente: la ciudad es nocturna, pero el blockout necesita leer volúmenes.
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLOCKOUT_DIR, "blockout.blend"))

    for cam, name in (
        (street_view, "blockout-escala.png"),
        (pedestrian, "blockout-peatonal.png"),
        (first_person, "blockout-primera-persona.png"),
        (aerial, "blockout-aerea.png"),
    ):
        render(scene, cam, os.path.join(RENDER_DIR, name))

    # Un FBX por asset, con el origen en el centro de su base y sin desplazamiento.
    for asset_id, (obj, position) in placements.items():
        if asset_id in ("street", "city-backdrop"):
            continue
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        if asset_id in lods:
            lods[asset_id].select_set(True)
        bpy.context.view_layer.objects.active = obj
        saved = obj.location.copy()
        obj.location = (0.0, 0.0, 0.0)
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(ASSETS_DIR, f"{asset_id}.fbx"),
            use_selection=True,
            apply_scale_options="FBX_SCALE_UNITS",
            axis_forward="Z",
            axis_up="Y",
            bake_anim=False,
            add_leaf_bones=False,
            path_mode="COPY",
            embed_textures=True,
        )
        obj.location = saved

    bpy.ops.export_scene.fbx(
        filepath=os.path.join(BLOCKOUT_DIR, "blockout.fbx"),
        use_selection=False,
        apply_scale_options="FBX_SCALE_UNITS",
        axis_forward="Z",
        axis_up="Y",
        bake_anim=False,
        add_leaf_bones=False,
        path_mode="COPY",
        embed_textures=True,
    )

    with open(os.path.join(BLOCKOUT_DIR, "blockout-stats.json"), "w", encoding="utf-8") as handle:
        json.dump(
            {
                "scale": {
                    "unit": "stud",
                    "floor": FLOOR,
                    "street_width": STREET_WIDTH,
                    "sidewalk": SIDEWALK,
                    "lot_front": LOT_FRONT,
                    "lot_depth": LOT_DEPTH,
                    "token_base_diameter": TOKEN_BASE,
                    "token_height": TOKEN_HEIGHT,
                    "avatar_height": AVATAR_HEIGHT,
                    "first_person_eye": round(TOKEN_EYE, 2),
                    "floors": {"house": HOUSE_FLOORS, "office": OFFICE_FLOORS, "skyscraper": TOWER_FLOORS},
                },
                "assets": stats,
            },
            handle,
            indent=2,
            ensure_ascii=False,
        )

    print("SCALE_JSON_START")
    print(json.dumps(stats, ensure_ascii=False))
    print("SCALE_JSON_END")


main()

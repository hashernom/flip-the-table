"""Escalera de edificios de Centro para la porción vertical: casa, hotel y rascacielos.

Una, dos y tres casas repiten el mismo modelo; hotel y rascacielos son modelos propios. Medidas de
art/escala.md: planta de 7, casa de 15,2, hotel de 36,5 y rascacielos de 92. Paleta y materiales de
art/guia-de-estilo.md: ladrillo y caliza con toldos, sin neón. Los huecos van perforados con booleana,
como en art/blender/facade/build_facade.py.

Salidas, en art/blender/slice/:
  ladder.blend            escena de revisión (no se versiona)
  <id>_{wall,trim,glass}.fbx y <id>_LOD1.fbx, con el origen en el centro de la base
  ladder-stats.json       triángulos y medidas reales

Y en art/render/: ladder-calle.png y ladder-aerea.png. Son revisión técnica: la aprobación se hace en
el juego, con su luz y su cámara.

Uso: blender --background --factory-startup --python art/blender/slice/build_ladder.py
"""

import json
import math
import os

import bpy
from mathutils import Vector

FLOOR = 7.0
HOUSE = {"width": 10.0, "depth": 12.0, "height": 15.2}
HOTEL = {"width": 30.0, "depth": 18.0, "height": 36.5}
TOWER = {"width": 18.0, "depth": 18.0, "height": 92.0}
HOUSE_STEP = 12.0  # CityLayout: separación entre casas de un mismo solar
LOT_WIDTH = 36.0
LOT_DEPTH = 22.0
LOD_RATIO = 0.45
STREET_WIDTH = 34.0
SIDEWALK = 7.0
TOKEN_HEIGHT = 9.0
TOKEN_BASE = 6.0
AVATAR_HEIGHT = 6.0
EYE = 14.1
SUN_ELEVATION = 34.0

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
TEX = os.path.join(REPO, "art", "textures", "cc0")
RENDER = os.path.join(REPO, "art", "render")


def srgb(hex_color):
    def channel(value):
        value /= 255.0
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4

    return tuple(channel(int(hex_color[i : i + 2], 16)) for i in (0, 2, 4))


def textured(name, stem, tint=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")

    def image(suffix, non_color=False):
        node = nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(os.path.join(TEX, f"{stem}_{suffix}.jpg"), check_existing=True)
        if non_color:
            node.image.colorspace_settings.name = "Non-Color"
        return node

    color = image("color")
    if tint is None:
        links.new(color.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        # La textura solo añade variación: el albedo es el de la tabla 2.2 de la guía.
        mix = nodes.new("ShaderNodeMixRGB")
        mix.blend_type = "MULTIPLY"
        mix.inputs["Fac"].default_value = 0.7
        mix.inputs["Color1"].default_value = (*srgb(tint), 1)
        links.new(color.outputs["Color"], mix.inputs["Color2"])
        links.new(mix.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(image("roughness", True).outputs["Color"], bsdf.inputs["Roughness"])
    normal_map = nodes.new("ShaderNodeNormalMap")
    links.new(image("normal", True).outputs["Color"], normal_map.inputs["Color"])
    links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def flat(name, hex_color, roughness=0.5, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*srgb(hex_color), 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


def box(name, size, location, mat=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        obj.data.materials.append(mat)
    return obj


def select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


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


def apply_modifiers(obj):
    select_only(obj)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)


def perforate(wall, cutters):
    # Una booleana por hueco, como en la fachada: unir los cortes en una malla se comía medio muro.
    for index, cutter in enumerate(cutters):
        boolean = wall.modifiers.new(f"hole_{index}", "BOOLEAN")
        boolean.operation = "DIFFERENCE"
        boolean.object = cutter
    apply_modifiers(wall)
    for cutter in cutters:
        bpy.data.objects.remove(cutter, do_unlink=True)


def triangles(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    count = len(mesh.loop_triangles)
    evaluated.to_mesh_clear()
    return count


def uv_unwrap(obj, cube_size=2.4):
    """Proyección de cubo con tamaño fijo: densidad de texel constante y ladrillo sin estirar."""
    select_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=cube_size)
    bpy.ops.object.mode_set(mode="OBJECT")


def face_points(width, depth, u, axis_side):
    """Punto de una fachada: axis_side es -Y delante, -X y +X los lados. u va a lo largo del muro."""
    if axis_side == "front":
        return (u, -depth / 2)
    if axis_side == "left":
        return (-width / 2, u)
    return (width / 2, u)


def window_set(prefix, width, depth, z, u, side, window_w, window_h, wall_t, mats, trims, glazing, cutters):
    x, y = face_points(width, depth, u, side)
    frontal = side == "front"
    normal = (0, -1) if frontal else ((-1, 0) if side == "left" else (1, 0))

    def sized(along, through, up):
        return (along, through, up) if frontal else (through, along, up)

    def at(push, up):
        return (x + normal[0] * push, y + normal[1] * push, z + up)

    cutters.append(box(f"{prefix}_cut", sized(window_w, wall_t * 3, window_h), (x, y, z)))
    glazing.append(box(f"{prefix}_glass", sized(window_w, 0.1, window_h), at(-0.55, 0), mats["glass"]))
    trims.append(box(f"{prefix}_sill", sized(window_w + 0.5, 0.6, 0.2), at(0.1, -window_h / 2 - 0.1), mats["stone"]))
    trims.append(box(f"{prefix}_head", sized(window_w + 0.4, 0.4, 0.3), at(0.05, window_h / 2 + 0.15), mats["stone"]))
    trims.append(box(f"{prefix}_mullion", sized(0.14, 0.15, window_h), at(-0.45, 0), mats["steel"]))


def shell(name, width, depth, height, thickness, mat):
    """Muro macizo: los huecos llevan cristal hundido, así que por dentro no se ve nada."""
    return box(name, (width, depth, height), (0, 0, height / 2), mat)


def cornice(width, depth, z, mat, trims, scale=1.0):
    trims.append(box("cornice_a", (width + 0.3 * scale, depth + 0.3 * scale, 0.3 * scale), (0, 0, z), mat))
    trims.append(box("cornice_b", (width + 0.8 * scale, depth + 0.8 * scale, 0.45 * scale), (0, 0, z + 0.35 * scale), mat))


def awning(width, center_x, front_y, z, mat, trims):
    """Toldo inclinado: es lo que hace que la planta baja se lea como comercio a la altura de la ficha."""
    trims.append(box("awning_top", (width, 0.2, 0.25), (center_x, front_y - 0.1, z), mat))
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(center_x, front_y - 1.0, z - 0.5))
    canvas = bpy.context.active_object
    canvas.name = "awning"
    canvas.scale = (width, 2.2, 0.12)
    canvas.rotation_euler = (math.radians(-24), 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    canvas.data.materials.append(mat)
    trims.append(canvas)


def build_house(mats):
    width, depth, height = HOUSE["width"], HOUSE["depth"], HOUSE["height"]
    trims, glazing, cutters = [], [], []
    body_h = height - 1.4
    wall = shell("house_wall", width, depth, body_h, 0.6, mats["brick"])
    upper_z = FLOOR + 3.5
    lower_z = 3.6

    # Planta alta: dos ventanas al frente y dos por lado. Planta baja: puerta y escaparate.
    for u in (-2.4, 2.4):
        window_set("up_f", width, depth, upper_z, u, "front", 2.0, 3.0, 0.6, mats, trims, glazing, cutters)
    for side in ("left", "right"):
        for u in (-2.8, 2.8):
            window_set("up_s", width, depth, upper_z, u, side, 2.0, 3.0, 0.6, mats, trims, glazing, cutters)
            window_set("lo_s", width, depth, lower_z, u, side, 2.0, 2.8, 0.6, mats, trims, glazing, cutters)

    front = -depth / 2
    cutters.append(box("door_cut", (2.0, 2.0, 4.6), (-2.6, front, 2.3)))
    glazing.append(box("door", (2.0, 0.12, 4.5), (-2.6, front + 0.5, 2.25), mats["glass"]))
    trims.append(box("door_head", (2.5, 0.4, 0.3), (-2.6, front - 0.05, 4.75), mats["stone"]))
    cutters.append(box("shop_cut", (4.0, 2.0, 3.4), (1.9, front, 2.9)))
    glazing.append(box("shop", (4.0, 0.12, 3.4), (1.9, front + 0.5, 2.9), mats["glass"]))
    trims.append(box("shop_sill", (4.5, 0.5, 0.25), (1.9, front - 0.05, 1.1), mats["stone"]))
    perforate(wall, cutters)

    awning(width - 1.0, 0, front, 5.5, mats["awning"], trims)
    trims.append(box("string", (width + 0.2, depth + 0.2, 0.3), (0, 0, FLOOR), mats["stone"]))
    trims.append(box("plinth", (width + 0.15, depth + 0.15, 0.7), (0, 0, 0.35), mats["stone"]))
    cornice(width, depth, body_h, mats["stone"], trims)
    # Cubierta a dos aguas baja, sin subir de los 15,2: el tejado es lo que tapa el horizonte en primera persona.
    trims.append(box("roof", (width - 0.4, depth - 0.4, 1.0), (0, 0, height - 0.5), mats["slate"]))
    return wall, trims, glazing


def build_hotel(mats):
    width, depth, height = HOTEL["width"], HOTEL["depth"], HOTEL["height"]
    trims, glazing, cutters = [], [], []
    body_h = height - 1.5
    wall = shell("hotel_wall", width, depth, body_h, 0.8, mats["brick"])
    floors = 5
    front = -depth / 2

    for floor in range(1, floors):
        z = floor * FLOOR + 3.8
        for column in range(6):
            u = (column - 2.5) * 4.6
            window_set("f", width, depth, z, u, "front", 2.2, 3.4, 0.8, mats, trims, glazing, cutters)
        for side in ("left", "right"):
            for column in range(3):
                u = (column - 1) * 5.0
                window_set("s", width, depth, z, u, side, 2.2, 3.4, 0.8, mats, trims, glazing, cutters)
        trims.append(box("belt", (width + 0.2, depth + 0.2, 0.25), (0, 0, floor * FLOOR), mats["stone"]))

    # Planta baja de caliza: entrada central con marquesina y escaparates a los lados.
    trims.append(box("base_stone", (width + 0.3, depth + 0.3, 1.0), (0, 0, 0.5), mats["stone"]))
    trims.append(box("base_head", (width + 0.4, depth + 0.4, 0.9), (0, 0, FLOOR - 0.45), mats["stone"]))
    for x in (-15.0 + 0.4, 15.0 - 0.4, -5.0, 5.0, -10.0, 10.0):
        trims.append(box("pier", (1.2, 0.5, FLOOR - 1.0), (x, front - 0.1, FLOOR / 2), mats["stone"]))
    cutters.append(box("door_cut", (7.0, 2.4, 5.0), (0, front, 2.5)))
    glazing.append(box("door", (7.0, 0.14, 5.0), (0, front + 0.6, 2.5), mats["glass"]))
    for x in (-10.0, 10.0):
        for offset in (-2.5, 2.5):
            cutters.append(box("shop_cut", (3.8, 2.4, 3.8), (x + offset, front, 3.1)))
            glazing.append(box("shop", (3.8, 0.14, 3.8), (x + offset, front + 0.6, 3.1), mats["glass"]))
    perforate(wall, cutters)

    # Marquesina de acero en la entrada: el cambio de categoría respecto a las casas.
    trims.append(box("marquee", (10.0, 3.6, 0.35), (0, front - 1.7, 5.8), mats["steel"]))
    trims.append(box("marquee_band", (10.2, 3.8, 0.12), (0, front - 1.7, 6.05), mats["gold"]))
    for x in (-4.6, 4.6):
        trims.append(box("marquee_post", (0.3, 0.3, 5.8), (x, front - 3.2, 2.9), mats["steel"]))
    awning(8.5, -10.0, front, 5.9, mats["awning"], trims)
    awning(8.5, 10.0, front, 5.9, mats["awning"], trims)

    cornice(width, depth, body_h, mats["stone"], trims, 1.6)
    trims.append(box("roof", (width - 1.0, depth - 1.0, 0.8), (0, 0, height - 0.6), mats["slate"]))
    return wall, trims, glazing


def build_tower(mats):
    total = TOWER["height"]
    trims, glazing = [], []
    # Tres cuerpos que se estrechan. El de abajo es el que se ve desde la ficha, y lleva la caliza.
    tiers = [(18.0, 18.0, 56.0), (14.0, 14.0, 21.0), (10.0, 10.0, 14.0)]
    z = 0.0
    walls = []
    for index, (width, depth, height) in enumerate(tiers):
        walls.append(box(f"core_{index}", (width - 1.0, depth - 1.0, height), (0, 0, z + height / 2), mats["dark"]))
        bays = max(3, int(width // 4))
        pitch = width / bays
        # Pilastras de caliza continuas y una banda de cristal por planta: lectura vertical de torre.
        for step in range(bays + 1):
            offset = (step - bays / 2) * pitch
            for sign in (-1, 1):
                trims.append(box("pier", (0.7, 1.0, height), (offset, sign * (depth / 2 - 0.5), z + height / 2), mats["stone"]))
                trims.append(box("pier", (1.0, 0.7, height), (sign * (width / 2 - 0.5), offset, z + height / 2), mats["stone"]))
        floors = int(height // FLOOR)
        for floor in range(floors):
            base = z + floor * FLOOR
            for sign in (-1, 1):
                glazing.append(box("band", (width - 1.4, 0.15, FLOOR - 1.3), (0, sign * (depth / 2 - 0.65), base + FLOOR / 2 + 0.3), mats["glass"]))
                glazing.append(box("band", (0.15, depth - 1.4, FLOOR - 1.3), (sign * (width / 2 - 0.65), 0, base + FLOOR / 2 + 0.3), mats["glass"]))
                trims.append(box("spandrel", (width - 0.8, 0.5, 0.6), (0, sign * (depth / 2 - 0.45), base + 0.3), mats["stone"]))
                trims.append(box("spandrel", (0.5, depth - 0.8, 0.6), (sign * (width / 2 - 0.45), 0, base + 0.3), mats["stone"]))
        z += height
        trims.append(box("setback", (width + 0.6, depth + 0.6, 0.7), (0, 0, z - 0.1), mats["stone"]))

    # Coronación con un filete de oro: la guía lo limita a remates.
    trims.append(box("crown_band", (10.5, 10.5, 0.2), (0, 0, z + 0.35), mats["gold"]))
    trims.append(box("crown", (6.0, 6.0, total - z - 0.5), (0, 0, z + (total - z) / 2 + 0.25), mats["steel"]))

    # Vestíbulo: planta baja de caliza y doble altura, con marquesina.
    front = -TOWER["depth"] / 2
    trims.append(box("lobby_stone", (18.4, 18.4, 1.0), (0, 0, 0.5), mats["stone"]))
    trims.append(box("lobby_head", (18.6, 18.6, 1.2), (0, 0, FLOOR - 0.6), mats["stone"]))
    trims.append(box("lobby_marquee", (8.0, 3.0, 0.3), (0, front - 1.5, 5.6), mats["steel"]))

    wall = join(walls, "tower_wall")
    return wall, trims, glazing


def finish(asset_id, parts):
    wall, trims, glazing = parts
    wall.name = f"{asset_id}_wall"
    # El muro no siempre pasa por join: sin esto conserva el origen en su centro y queda medio enterrado.
    select_only(wall)
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    trim = join(trims, f"{asset_id}_trim")
    glass = join(glazing, f"{asset_id}_glass")
    for obj in (wall, trim, glass):
        uv_unwrap(obj)
    meshes = (wall, trim, glass)

    lod_parts = []
    for source in meshes:
        copy = source.copy()
        copy.data = source.data.copy()
        copy.name = f"{source.name}_copy"
        bpy.context.collection.objects.link(copy)
        decimate = copy.modifiers.new("Decimate", "DECIMATE")
        decimate.ratio = LOD_RATIO
        apply_modifiers(copy)
        lod_parts.append(copy)
    lod = join(lod_parts, f"{asset_id}_LOD1")
    lod.hide_render = True
    lod.hide_viewport = True

    for obj, name in [(wall, "wall"), (trim, "trim"), (glass, "glass"), (lod, None)]:
        select_only_visible(obj)
        filename = f"{asset_id}_{name}.fbx" if name else f"{asset_id}_LOD1.fbx"
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(HERE, filename),
            use_selection=True,
            apply_scale_options="FBX_SCALE_UNITS",
            axis_forward="Z",
            axis_up="Y",
            bake_anim=False,
            add_leaf_bones=False,
        )
    lod.hide_viewport = True
    return {
        "meshes": meshes,
        "triangles": sum(triangles(obj) for obj in meshes),
        "lod_triangles": triangles_of_hidden(lod),
    }


def select_only_visible(obj):
    obj.hide_viewport = False
    select_only(obj)


def triangles_of_hidden(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def instance(meshes, x, y=0.0, turn=0.0):
    for source in meshes:
        copy = source.copy()
        copy.name = f"{source.name}_at"
        copy.location = (x, y, 0)
        copy.rotation_euler = (0, 0, turn)
        # El original está oculto en la escena de revisión, y la copia lo heredaría.
        copy.hide_render = False
        copy.hide_viewport = False
        bpy.context.collection.objects.link(copy)


def camera(name, location, target, lens):
    data = bpy.data.cameras.new(name)
    data.lens = lens
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    return obj


def stage(mats, house, hotel, tower):
    """Calle de revisión: los cinco pasos en fila, de izquierda a derecha, con su solar y la ficha."""
    for source in (*house, *hotel, *tower):
        source.hide_render = True
        source.hide_viewport = True

    spacing = LOT_WIDTH + 4.0
    lot_y = STREET_WIDTH / 2 + SIDEWALK + LOT_DEPTH / 2
    start = -2.0 * spacing
    steps = []
    for level in range(5):
        steps.append(start + level * spacing)

    for count, x in zip((1, 2, 3), steps[:3]):
        for order in range(count):
            instance(house, x + (order - (count - 1) / 2) * HOUSE_STEP, lot_y)
    instance(hotel, steps[3], lot_y)
    instance(tower, steps[4], lot_y)

    length = spacing * 8
    box("road", (length, STREET_WIDTH, 0.4), (0, 0, -0.2), mats["asphalt"])
    for sign in (-1, 1):
        box("kerb", (length, 0.6, 0.6), (0, sign * (STREET_WIDTH / 2 + 0.3), 0.0), mats["stone"])
        box("walk", (length, SIDEWALK, 0.4), (0, sign * (STREET_WIDTH / 2 + SIDEWALK / 2), 0.0), mats["pavement"])
    box("lots", (length, LOT_DEPTH + 10, 0.2), (0, lot_y + 5, -0.1), mats["pavement"])

    # Ficha y avatar de referencia: solo para leer la escala, no son los modelos finales.
    bpy.ops.mesh.primitive_cylinder_add(radius=TOKEN_BASE / 2, depth=TOKEN_HEIGHT, location=(steps[2], 8, TOKEN_HEIGHT / 2))
    bpy.context.active_object.data.materials.append(flat("token_ref", "F5C518", 0.35))
    box("avatar_ref", (1.6, 1.2, AVATAR_HEIGHT), (steps[2], 8, TOKEN_HEIGHT + AVATAR_HEIGHT / 2), flat("avatar_ref", "6E747C", 0.8))

    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 4.2
    sun_data.angle = math.radians(1.0)
    sun = bpy.data.objects.new("sun", sun_data)
    bpy.context.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(90 - SUN_ELEVATION), 0, math.radians(-38))

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.68, 0.78, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    bpy.context.scene.world = world
    return steps


def render(scene, cam, name):
    scene.camera = cam
    scene.render.filepath = os.path.join(RENDER, name)
    bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    scene.unit_settings.scale_length = 1.0
    os.makedirs(HERE, exist_ok=True)

    mats = {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "stone": textured("limestone", "concrete", "D2C9B4"),
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "steel": flat("steel", "A8AEB4", 0.25, 0.8),
        "gold": flat("gold", "C9A227", 0.3, 0.9),
        "awning": flat("awning", "C4382B", 0.8),
        "slate": flat("slate", "4A4E54", 0.85),
        "dark": flat("dark", "2A2E33", 0.7),
    }

    results = {
        "slice-house": finish("slice-house", build_house(mats)),
        "slice-hotel": finish("slice-hotel", build_hotel(mats)),
        "slice-tower": finish("slice-tower", build_tower(mats)),
    }

    stage(mats, results["slice-house"]["meshes"], results["slice-hotel"]["meshes"], results["slice-tower"]["meshes"])

    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    scene.view_settings.look = "AgX - Medium High Contrast"

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "ladder.blend"))

    street = camera("calle", (-70.0, -8.0, EYE), (10.0, 34.0, 18.0), 24)
    aerial = camera("aerea", (0.0, -135.0, 62.0), (0.0, 32.0, 28.0), 30)
    render(scene, street, "ladder-calle.png")
    render(scene, aerial, "ladder-aerea.png")

    stats = {
        asset_id: {"triangles": result["triangles"], "lod_triangles": result["lod_triangles"]}
        for asset_id, result in results.items()
    }
    with open(os.path.join(HERE, "ladder-stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("LADDER_STATS")
    print(json.dumps(stats))


main()

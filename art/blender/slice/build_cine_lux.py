"""Cine Lux de Medianoche: primera propiedad de la porción vertical.

Cada propiedad es un edificio fijo (R-P50). El cuerpo no cambia: cada nivel le suma un añadido, y junto
a él se ponen los marcadores de mejora. Art déco de Centro: caliza en el cuerpo central, ladrillo en los
flancos, sin neón ni estética nocturna, como pide art/guia-de-estilo.md.

Salidas, en art/blender/slice/:
  cine-lux.blend            escena de revisión (no se versiona)
  cine-lux_base_{wall,trim,glass,roof,sign}.fbx y cine-lux_addon1..5.fbx, con el origen en el centro de la base
  cine-lux_LOD1.fbx         versión reducida del conjunto al máximo
  marker-{house,hotel,tower}.fbx y sus _LOD1
  cine-lux-stats.json       triángulos reales

Y en art/render/: cine-lux-calle.png y cine-lux-niveles.png. Son revisión técnica: la aprobación se hace
en el juego, con su luz y su cámara.

Uso: blender --background --factory-startup --python art/blender/slice/build_cine_lux.py
"""

import json
import math
import os

import bpy
from mathutils import Vector

WIDTH = 32.0
DEPTH = 18.0
HEIGHT = 24.0
FLOOR = 7.0
BAY = 13.0  # ancho del cuerpo central
LOT_WIDTH = 36.0
LOT_DEPTH = 22.0
FRONT_OFFSET = 2.0  # el edificio se retrasa en el solar: delante van los marcadores
MARKER_FRONT = -9.5
MARKER_STEP = 4.4
MARKER_ALONG = 11.5  # a un lado, para no tapar la entrada
LOD_RATIO = 0.5
STREET_WIDTH = 34.0
SIDEWALK = 7.0
SPACING = 40.0
SLOT_LENGTH = 30.0
SLOT_DEPTH = 16.0
SLOT_SIDE = 8.0
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


def textured(name, stem, tint):
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

    # La textura solo añade variación: el albedo es el de la tabla 2.2 de la guía.
    mix = nodes.new("ShaderNodeMixRGB")
    mix.blend_type = "MULTIPLY"
    mix.inputs["Fac"].default_value = 0.7
    mix.inputs["Color1"].default_value = (*srgb(tint), 1)
    links.new(image("color").outputs["Color"], mix.inputs["Color2"])
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
    obj.hide_viewport = False
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def origin_at_zero(obj):
    select_only(obj)
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    origin_at_zero(joined)
    return joined


def apply_modifiers(obj):
    select_only(obj)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)


def perforate(wall, cutters):
    for index, cutter in enumerate(cutters):
        boolean = wall.modifiers.new(f"hole_{index}", "BOOLEAN")
        boolean.operation = "DIFFERENCE"
        boolean.object = cutter
    apply_modifiers(wall)
    for cutter in cutters:
        bpy.data.objects.remove(cutter, do_unlink=True)


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


def letters(text, size, location, mat, depth=0.25):
    """Rótulo en 3D mirando a la calle (-Y), centrado en x."""
    bpy.ops.object.text_add(location=location, rotation=(math.radians(90), 0, 0))
    obj = bpy.context.active_object
    obj.data.body = text
    obj.data.size = size
    obj.data.align_x = "CENTER"
    obj.data.align_y = "CENTER"
    obj.data.extrude = depth
    obj.data.resolution_u = 2
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    return obj


def build_base(mats):
    front = -DEPTH / 2
    bay_front = front - 0.8
    flank_h = HEIGHT - 3.0
    trims, glazing, cutters = [], [], []
    roofing, signs = [], []

    # Flancos de ladrillo con cuerpo central de caliza que sobresale y sube: la silueta del cine.
    wall = box("wall", (WIDTH, DEPTH, flank_h), (0, 0, flank_h / 2), mats["brick"])
    bay = box("bay", (BAY, 1.6, HEIGHT), (0, front, HEIGHT / 2), mats["stone"])
    trims.append(bay)

    # Tres ventanales altos en el cuerpo central.
    for x in (-3.8, 0.0, 3.8):
        cutters_bay = box("win_cut", (2.6, 3.0, 8.4), (x, front, 14.4))
        boolean = bay.modifiers.new("win", "BOOLEAN")
        boolean.operation = "DIFFERENCE"
        boolean.object = cutters_bay
        apply_modifiers(bay)
        bpy.data.objects.remove(cutters_bay, do_unlink=True)
        glazing.append(box("win", (2.6, 0.12, 8.4), (x, front + 0.2, 14.4), mats["glass"]))
        for z in (11.6, 14.4, 17.2):
            trims.append(box("muntin", (2.6, 0.16, 0.14), (x, front - 0.1, z), mats["steel"]))
        trims.append(box("win_sill", (3.1, 1.0, 0.25), (x, bay_front, 10.05), mats["stone"]))

    # Ventanas de los flancos, en la planta alta y a los lados.
    for side in (-1, 1):
        for u in (-4.2, 0.0, 4.2):
            x = side * (BAY / 2 + 4.8) + u * 0.6
            cutters.append(box("cut", (1.8, 2.0, 3.6), (x, front, 13.5)))
            glazing.append(box("flank_win", (1.8, 0.1, 3.6), (x, front + 0.55, 13.5), mats["glass"]))
            trims.append(box("sill", (2.2, 0.5, 0.2), (x, front - 0.1, 11.6), mats["stone"]))
            trims.append(box("head", (2.2, 0.35, 0.28), (x, front - 0.05, 15.45), mats["stone"]))
        for y in (-5.0, 0.0, 5.0):
            for z in (4.0, 13.5):
                cutters.append(box("side_cut", (2.0, 2.0, 3.4), (side * WIDTH / 2, y, z)))
                glazing.append(box("side_win", (0.1, 2.0, 3.4), (side * (WIDTH / 2 - 0.55), y, z), mats["glass"]))
                trims.append(box("side_sill", (0.5, 2.4, 0.2), (side * (WIDTH / 2 + 0.1), y, z - 1.8), mats["stone"]))

    # Puertas del vestíbulo y carteleras a los lados: lo que se ve desde la ficha.
    for x in (-4.2, -1.4, 1.4, 4.2):
        # Más altas que un avatar, que mide 5,6 con accesorios (medido en Studio).
        glazing.append(box("door", (2.4, 0.14, 6.5), (x, bay_front + 0.5, 3.25), mats["glass"]))
        trims.append(box("door_frame", (0.2, 0.3, 6.6), (x + 1.3, bay_front + 0.3, 3.3), mats["steel"]))
    box_lobby = box("lobby_cut", (11.4, 3.0, 6.6), (0, front, 3.3))
    boolean = bay.modifiers.new("lobby", "BOOLEAN")
    boolean.operation = "DIFFERENCE"
    boolean.object = box_lobby
    apply_modifiers(bay)
    bpy.data.objects.remove(box_lobby, do_unlink=True)
    for side in (-1, 1):
        for u in (-3.2, 3.2):
            x = side * (BAY / 2 + 4.8) + u
            cutters.append(box("shop_cut", (4.0, 2.0, 4.0), (x, front, 3.4)))
            glazing.append(box("poster", (4.0, 0.12, 4.0), (x, front + 0.5, 3.4), mats["glass"]))
            trims.append(box("poster_frame", (4.4, 0.4, 0.3), (x, front - 0.05, 1.3), mats["stone"]))
    perforate(wall, cutters)

    # Marquesina sencilla y rótulo: el cine ya se reconoce sin mejoras.
    trims.append(box("marquee", (12.0, 2.6, 0.6), (0, bay_front - 1.3, 7.1), mats["stone"]))
    trims.append(box("sign_board", (9.0, 0.4, 1.3), (0, bay_front - 0.1, 8.3), mats["cream"]))
    signs.append(letters("CINE LUX", 1.0, (0, bay_front - 0.32, 8.3), mats["red"]))

    # Molduras: zócalo, junta sobre la planta baja, cornisa y escalonado déco del cuerpo central.
    trims.append(box("plinth", (WIDTH + 0.2, DEPTH + 0.2, 0.8), (0, 0, 0.4), mats["stone"]))
    trims.append(box("string", (WIDTH + 0.2, DEPTH + 0.2, 0.4), (0, 0, FLOOR + 1.2), mats["stone"]))
    trims.append(box("cornice", (WIDTH + 0.7, DEPTH + 0.7, 0.6), (0, 0, flank_h + 0.1), mats["stone"]))
    # Cubierta: en Roblox cada malla lleva un solo material, así que va aparte de la caliza. La cámara del
    # turno la ve de lleno: lucernario de la sala, climatización, conductos y depósito.
    roof_z = flank_h + 0.45
    top = roof_z + 0.25
    roofing.append(box("roof", (WIDTH - 0.8, DEPTH - 0.8, 0.5), (0, 0, roof_z), mats["slate"]))
    roofing.append(box("skylight_curb", (10.0, 6.0, 0.7), (-7.0, 2.0, top + 0.35), mats["slate"]))
    for u in (-3.0, 0.0, 3.0):
        roofing.append(box("skylight_rib", (0.3, 6.2, 1.1), (-7.0 + u, 2.0, top + 0.55), mats["slate"]))
    for x, y in ((6.0, 4.5), (11.0, 4.5), (6.0, -1.5)):
        roofing.append(box("hvac", (3.4, 2.6, 1.8), (x, y, top + 0.9), mats["slate"]))
        roofing.append(box("hvac_fan", (2.2, 1.6, 0.25), (x, y, top + 1.9), mats["slate"]))
    roofing.append(box("duct", (5.0, 0.7, 0.7), (8.5, 1.5, top + 0.35), mats["slate"]))
    roofing.append(box("hatch", (1.8, 1.8, 0.9), (12.0, -3.5, top + 0.45), mats["slate"]))
    trims.append(box("bay_step", (BAY - 3.0, 1.6, 1.0), (0, front, HEIGHT + 0.5), mats["stone"]))
    trims.append(box("bay_step2", (BAY - 7.0, 1.6, 0.8), (0, front, HEIGHT + 1.4), mats["stone"]))
    for x in (-BAY / 2 + 0.5, BAY / 2 - 0.5):
        trims.append(box("bay_pier", (1.0, 0.5, HEIGHT - 8.0), (x, bay_front - 0.1, 16.0), mats["stone"]))
    return wall, trims, glazing, roofing, signs


def build_addon(level, mats):
    front = -DEPTH / 2
    bay_front = front - 0.8
    parts = []
    if level == 1:
        # Toldos sobre las carteleras y jardineras: el primer gasto se nota a pie de calle.
        for side in (-1, 1):
            for u in (-3.2, 3.2):
                x = side * (BAY / 2 + 4.8) + u
                bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, front - 0.9, 5.6))
                canvas = bpy.context.active_object
                canvas.scale = (4.4, 2.0, 0.12)
                canvas.rotation_euler = (math.radians(-22), 0, 0)
                bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
                canvas.data.materials.append(mats["red"])
                parts.append(canvas)
                parts.append(box("planter", (3.6, 0.9, 0.7), (x, front - 0.6, 0.65), mats["stone"]))
                parts.append(box("hedge", (3.3, 0.7, 0.9), (x, front - 0.6, 1.4), mats["hedge"]))
    elif level == 2:
        # Fachada arreglada: pilastras de caliza en los flancos, friso y rótulo mayor.
        for side in (-1, 1):
            # Entre las ventanas, nunca delante, y más salientes que el friso para no compartir cara.
            for x in (BAY / 2 + 1.0, BAY / 2 + 3.54, BAY / 2 + 6.06, BAY / 2 + 8.6):
                parts.append(box("pilaster", (0.7, 0.8, 13.0), (side * x, front - 0.3, 14.0), mats["stone"]))
            parts.append(box("frieze", (9.6, 0.4, 1.2), (side * (BAY / 2 + 4.8), front - 0.1, 19.4), mats["stone"]))
        parts.append(box("sign_big", (BAY - 2.0, 0.4, 2.4), (0, bay_front - 0.15, 20.8), mats["cream"]))
        parts.append(letters("LUX", 2.0, (0, bay_front - 0.4, 20.8), mats["red"]))
    elif level == 3:
        # Una planta más, retranqueada, para que suba sin dejar de ser el mismo edificio.
        storey = box("storey", (24.0, 14.0, 5.0), (0, 2.0, HEIGHT - 3.0 + 3.0), mats["brick"])
        parts.append(storey)
        parts.append(box("storey_cornice", (24.6, 14.6, 0.5), (0, 2.0, HEIGHT + 2.7), mats["stone"]))
        for x in (-9.0, -5.4, 5.4, 9.0):
            parts.append(box("storey_win", (2.2, 0.12, 2.8), (x, -5.06, HEIGHT - 0.2), mats["glass"]))
    elif level == 4:
        # Gran marquesina de acero con filete de oro y su letrero.
        parts.append(box("grand_marquee", (15.0, 4.6, 0.9), (0, bay_front - 2.3, 7.4), mats["steel"]))
        # El oro va en el canto, como filete: la cubierta es de acero (guía, §11.6).
        parts.append(box("grand_band", (15.3, 4.9, 0.18), (0, bay_front - 2.3, 7.9), mats["gold"]))
        parts.append(box("grand_cap", (15.0, 4.6, 0.14), (0, bay_front - 2.3, 8.05), mats["steel"]))
        parts.append(box("grand_board", (11.0, 0.5, 1.2), (0, bay_front - 4.4, 8.55), mats["cream"]))
        parts.append(letters("ESTRENO", 0.8, (0, bay_front - 4.7, 8.55), mats["red"]))
        for x in (-7.0, 7.0):
            parts.append(box("post", (0.35, 0.35, 7.0), (x, bay_front - 4.2, 3.5), mats["steel"]))
    elif level == 5:
        # Coronación: torre con filete de oro y letrero vertical. Es la señal de propiedad al máximo.
        base = HEIGHT + 3.0
        parts.append(box("crown", (10.0, 8.0, 6.0), (0, 2.0, base + 3.0), mats["stone"]))
        parts.append(box("crown_band", (10.5, 8.5, 0.25), (0, 2.0, base + 6.1), mats["gold"]))
        parts.append(box("crown_cap", (6.0, 5.0, 1.2), (0, 2.0, base + 6.8), mats["steel"]))
        # Letrero en el borde del cuerpo central, para no chocar con el rótulo del nivel 2.
        blade_x = BAY / 2 + 1.6
        parts.append(box("blade_arm", (2.0, 0.3, 0.3), (blade_x - 0.8, front - 0.8, 24.0), mats["steel"]))
        parts.append(box("blade", (1.9, 0.5, 11.0), (blade_x, front - 1.0, 21.0), mats["cream"]))
        for order, char in enumerate("LUX"):
            parts.append(letters(char, 2.2, (blade_x, front - 1.28, 24.6 - order * 3.4), mats["red"]))
    addon = join(parts, f"cine-lux_addon{level}")
    uv_unwrap(addon)
    return addon


def build_marker(kind, mats):
    parts = []
    if kind == "house":
        # Casita de caliza con tejado a dos aguas. Nunca verde: sería el reparto del original.
        parts.append(box("plate", (3.8, 2.8, 0.2), (0, 0, 0.1), mats["slate"]))
        parts.append(box("body", (3.2, 2.2, 2.0), (0, 0, 1.2), mats["cream"]))
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=2.5, depth=1.2, location=(0, 0, 2.8), rotation=(0, 0, math.radians(45)))
        roof = bpy.context.active_object
        roof.scale = (1.0, 0.8, 1.0)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        roof.data.materials.append(mats["slate"])
        parts.append(roof)
    elif kind == "hotel":
        parts.append(box("plate", (4.4, 2.8, 0.2), (0, 0, 0.1), mats["slate"]))
        parts.append(box("body", (3.8, 2.2, 5.0), (0, 0, 2.7), mats["cream"]))
        parts.append(box("band", (3.9, 2.3, 0.3), (0, 0, 4.2), mats["gold"]))
        parts.append(box("top", (4.0, 2.4, 0.3), (0, 0, 5.3), mats["slate"]))
    else:
        parts.append(box("plate", (3.8, 2.8, 0.2), (0, 0, 0.1), mats["slate"]))
        parts.append(box("body", (3.0, 2.2, 5.2), (0, 0, 2.8), mats["steel"]))
        parts.append(box("mid", (2.1, 1.6, 2.2), (0, 0, 6.5), mats["steel"]))
        parts.append(box("band", (2.2, 1.7, 0.25), (0, 0, 7.7), mats["gold"]))
        parts.append(box("spire", (0.6, 0.6, 0.9), (0, 0, 8.25), mats["gold"]))
    marker = join(parts, f"marker-{kind}")
    uv_unwrap(marker, 1.0)
    return marker


def lod_of(sources, name):
    copies = []
    for source in sources:
        copy = source.copy()
        copy.data = source.data.copy()
        copy.name = f"{source.name}_copy"
        bpy.context.collection.objects.link(copy)
        decimate = copy.modifiers.new("Decimate", "DECIMATE")
        decimate.ratio = LOD_RATIO
        apply_modifiers(copy)
        copies.append(copy)
    lod = join(copies, name)
    lod.hide_render = True
    return lod


def export(obj, filename):
    select_only(obj)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(HERE, filename),
        use_selection=True,
        apply_scale_options="FBX_SCALE_UNITS",
        axis_forward="Z",
        axis_up="Y",
        bake_anim=False,
        add_leaf_bones=False,
    )


def place(sources, x, y=0.0, marker_scale=1.0):
    for source in sources:
        copy = source.copy()
        copy.location = (x, y, 0)
        copy.scale = (marker_scale, marker_scale, marker_scale)
        copy.hide_render = False
        copy.hide_viewport = False
        bpy.context.collection.objects.link(copy)


def tree(x, y, mats):
    """Solo para leer el ambiente: el árbol definitivo será un asset propio del plan 07."""
    box("trunk", (0.8, 0.8, 5.0), (x, y, 2.5), mats["bark"])
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=4.2, location=(x, y, 8.0))
    bpy.context.active_object.data.materials.append(mats["hedge"])


def lamp(x, y, mats):
    box("lamp_post", (0.35, 0.35, 11.0), (x, y, 5.5), mats["dark"])
    box("lamp_arm", (0.25, 2.4, 0.25), (x, y - 1.2, 11.0), mats["dark"])
    box("lamp_head", (0.9, 1.2, 0.35), (x, y - 2.2, 10.9), mats["cream"])


def stage(mats, base, addons, markers):
    """Tramo de calle: el mismo edificio en sus seis estados, cada uno con su casilla pintada."""
    lot_y = STREET_WIDTH / 2 + SIDEWALK + LOT_DEPTH / 2
    building_y = lot_y + FRONT_OFFSET
    length = SPACING * 10
    box("road", (length, STREET_WIDTH, 0.4), (0, 0, -0.2), mats["asphalt"])
    for sign in (-1, 1):
        box("kerb", (length, 0.5, 0.5), (0, sign * (STREET_WIDTH / 2 + 0.25), 0.0), mats["stone"])
        box("walk", (length, SIDEWALK, 0.4), (0, sign * (STREET_WIDTH / 2 + SIDEWALK / 2), 0.0), mats["pavement"])
    box("lots", (length, LOT_DEPTH + 20, 0.2), (0, lot_y + 10, -0.1), mats["pavement"])
    box("far", (length, 60, 0.2), (0, -STREET_WIDTH / 2 - SIDEWALK - 30, -0.1), mats["pavement"])

    # Línea discontinua en el eje: es lo que hace leer calzada y no tablero.
    dash = -length / 2
    while dash < length / 2:
        box("dash", (5.0, 0.4, 0.04), (dash, 0, 0.02), mats["cream"])
        dash += 11.0

    for level in range(6):
        x = (level - 2.5) * SPACING
        place(base, x, building_y)
        for order in range(1, level + 1):
            place([addons[order]], x, building_y)
        # La casilla: pintura de zona en el carril del edificio, con filete y asfalto hasta la siguiente.
        box("slot", (SLOT_LENGTH, SLOT_DEPTH, 0.04), (x, SLOT_SIDE, 0.03), mats["zone"])
        for sign in (-1, 1):
            box("slot_edge", (0.5, SLOT_DEPTH, 0.05), (x + sign * SLOT_LENGTH / 2, SLOT_SIDE, 0.035), mats["cream"])
            box("slot_edge", (SLOT_LENGTH, 0.5, 0.05), (x, SLOT_SIDE + sign * SLOT_DEPTH / 2, 0.035), mats["cream"])
        if level in (1, 2, 3):
            for order in range(level):
                place([markers["house"]], x + MARKER_ALONG + (order - (level - 1) / 2) * MARKER_STEP, lot_y + MARKER_FRONT)
        elif level == 4:
            place([markers["hotel"]], x + MARKER_ALONG, lot_y + MARKER_FRONT)
        elif level == 5:
            place([markers["tower"]], x + MARKER_ALONG, lot_y + MARKER_FRONT)
        # Ambiente en el hueco entre edificios, y árboles en la acera de enfrente.
        gap_x = x + SPACING / 2
        lamp(gap_x, STREET_WIDTH / 2 + 2.0, mats)
        tree(gap_x, -(STREET_WIDTH / 2 + SIDEWALK / 2), mats)
        lamp(x, -(STREET_WIDTH / 2 + 2.0), mats)

    # Ficha y avatar de referencia, en su casilla, solo para leer la escala.
    bpy.ops.mesh.primitive_cylinder_add(radius=3.0, depth=9.0, location=(-1.5 * SPACING, SLOT_SIDE, 4.5))
    bpy.context.active_object.data.materials.append(flat("token_ref", "F5C518", 0.35))
    box("avatar_ref", (1.6, 1.2, 6.0), (-1.5 * SPACING, SLOT_SIDE, 12.0), flat("avatar_ref", "6E747C", 0.8))

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


def camera(name, location, target, lens):
    data = bpy.data.cameras.new(name)
    data.lens = lens
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    return obj


def render(scene, cam, name):
    scene.camera = cam
    scene.render.filepath = os.path.join(RENDER, name)
    bpy.ops.render.render(write_still=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    scene.unit_settings.scale_length = 1.0

    mats = {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "stone": textured("limestone", "concrete", "D2C9B4"),
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "steel": flat("steel", "A8AEB4", 0.25, 0.8),
        "gold": flat("gold", "C9A227", 0.3, 0.9),
        "red": flat("red", "C4382B", 0.7),
        "cream": flat("cream", "EDE5D3", 0.6),
        "slate": flat("slate", "4A4E54", 0.85),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "bark": flat("bark", "5A4636", 0.9),
        "dark": flat("dark", "2A2E33", 0.6),
        "zone": flat("zone", "DC2626", 0.8),
    }

    wall, trims, glazing, roofing, signs = build_base(mats)
    wall.name = "cine-lux_base_wall"
    origin_at_zero(wall)
    trim = join(trims, "cine-lux_base_trim")
    glass = join(glazing, "cine-lux_base_glass")
    roof = join(roofing, "cine-lux_base_roof")
    sign = join(signs, "cine-lux_base_sign")
    for obj in (wall, trim, glass, roof, sign):
        uv_unwrap(obj)
    base = [wall, trim, glass, roof, sign]

    addons = {level: build_addon(level, mats) for level in range(1, 6)}
    markers = {kind: build_marker(kind, mats) for kind in ("house", "hotel", "tower")}

    whole = base + list(addons.values())
    lod = lod_of(whole, "cine-lux_LOD1")
    marker_lods = {kind: lod_of([marker], f"marker-{kind}_LOD1") for kind, marker in markers.items()}

    for obj, name in ((wall, "base_wall"), (trim, "base_trim"), (glass, "base_glass"), (roof, "base_roof"), (sign, "base_sign")):
        export(obj, f"cine-lux_{name}.fbx")
    for level, addon in addons.items():
        export(addon, f"cine-lux_addon{level}.fbx")
    export(lod, "cine-lux_LOD1.fbx")
    for kind, marker in markers.items():
        export(marker, f"marker-{kind}.fbx")
        export(marker_lods[kind], f"marker-{kind}_LOD1.fbx")

    stats = {
        "cine-lux": {
            "triangles": sum(count(obj) for obj in whole),
            "base": sum(count(obj) for obj in base),
            "lod_triangles": count(lod),
        }
    }
    for kind, marker in markers.items():
        stats[f"marker-{kind}"] = {"triangles": count(marker), "lod_triangles": count(marker_lods[kind])}

    for source in [*whole, lod, *markers.values(), *marker_lods.values()]:
        source.hide_render = True
        source.hide_viewport = True

    stage(mats, base, addons, markers)

    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "cine-lux.blend"))

    render(scene, camera("niveles", (0.0, -190.0, 78.0), (0.0, 22.0, 10.0), 30), "cine-lux-niveles.png")
    render(scene, camera("calle", (0.5 * SPACING - 52.0, SLOT_SIDE - 1.0, EYE), (0.5 * SPACING + 20.0, 28.0, 16.0), 26), "cine-lux-calle.png")

    with open(os.path.join(HERE, "cine-lux-stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("CINE_STATS")
    print(json.dumps(stats))


main()

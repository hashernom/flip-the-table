"""Callejón del Hojalatero: taller de hojalatería de la zona Cobre, modelado desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de nave con cubierta inclinada de pizarra (más alta al frente) y cinco
añadidos que se suman: toldo de chapa, pilas de planchas y mejora de fachada, altillo de taller, ampliación
y torre de celosía con remate de cobre. Sigue el método de barberia-morro.py: una malla por material y color,
LOD1 con decimado.

Salidas, en art/blender/buildings/cobre/:
  callejon-del-hojalatero.blend              escena de revisión (no se versiona)
  callejon-del-hojalatero/hojalatero_<pieza>_<material>.fbx y hojalatero_LOD1.fbx
  callejon-del-hojalatero/stats.json         triángulos por pieza y nivel, límites y materiales
Y en art/render/cobre/callejon-del-hojalatero/: callejon-del-hojalatero-niveles.png y
callejon-del-hojalatero-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/cobre/callejon-del-hojalatero.py
"""

import json
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "callejon-del-hojalatero")
RENDER_SUBDIR = "cobre/callejon-del-hojalatero"
sys.path.insert(0, SLICE)

# Helpers compartidos con los edificios ya en el juego (no se copian: se importan).
from build_cine_lux import (  # noqa: E402
    box,
    build_marker,
    camera,
    count,
    flat,
    join,
    lamp,
    letters,
    lod_of,
    perforate,
    render,
    select_only,
    textured,
    tree,
    uv_unwrap,
)

WIDTH = 32.0
DEPTH = 18.0
FRONT = -DEPTH / 2  # el frente da a -Y
SKIN = 0.6  # grosor de la chapa de acero de la fachada
WALL_H = 18.0  # volumen antes de cortar la cubierta
ROOF_THETA = math.radians(14.0)  # pendiente de la cubierta: sube hacia el frente
ROOF_Q = 14.9  # altura de la cara superior de la cubierta en y = 0
PORTAL_W = 9.0  # portalón central, como el de la Bodega
PORTAL_H = 7.4  # más alto que el avatar (6)
PORTAL_Y_CUT = -9.6  # el corte atraviesa la chapa y 1,0 de fondo
PORTAL_Y_FLOOR = -7.4  # suelo de la hornacina del portalón
SIGN_Z = 11.2
TRIANGLE_BUDGET = 3000
MAX_HEIGHT = 34.0
CINE_LUX_L5_TRIANGLES = 3042
NAVE_X = -6.4
NAVE_W = 18.8
NAVE_Y0 = 0.0
NAVE_Y1 = 8.8
NAVE_Z0 = 12.0
NAVE_Z1 = 21.5
NAVE_ROOF_Q = 21.0

FRONT_OFFSET = 2.0
STREET_WIDTH = 34.0
SIDEWALK = 7.0
LOT_DEPTH = 22.0
SPACING = 40.0
SLOT_LENGTH = 30.0
SLOT_DEPTH = 16.0
SLOT_SIDE = 8.0
MARKER_FRONT = -9.5
MARKER_STEP = 4.4
MARKER_ALONG = 11.5

# Material de Roblox, sufijo de color y RGB de cada material de Blender.
RBX = {
    "brick": ("Brick", "", "B0664A"),
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "metal": ("Metal", "", "C97B3A"),
    "metal_acero": ("Metal", "_acero", "8C939B"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "metal": flat("metal", "C97B3A", 0.3, 0.9),
        "metal_acero": flat("metal_acero", "8C939B", 0.4, 0.9),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "DC2626", 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "6E747C", 0.8),
    }


def cylinder(name, radius, depth, location, mat, verts, caps):
    """Cilindro vertical."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts,
        radius=radius,
        depth=depth,
        end_fill_type="NGON" if caps else "NOTHING",
        location=location,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def cone(name, radius, depth, location, mat):
    """Pirámide de base cuadrada, para el remate de cobre de la torre."""
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=radius, radius2=0.0, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def beam(name, a, b, thick, mat):
    """Barra cuadrada entre dos puntos (montante, larguero o diagonal de la celosía)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    obj = box(name, (thick, d.length, thick), tuple((a + b) / 2), mat)
    obj.rotation_euler = Vector((0.0, 1.0, 0.0)).rotation_difference(d.normalized()).to_euler()
    return obj


def roof_normal():
    """Normal de la cubierta principal: mira arriba y hacia atrás."""
    return Vector((0.0, math.sin(ROOF_THETA), math.cos(ROOF_THETA)))


def plane_z(y, qz=ROOF_Q):
    """Altura de la cara superior de la cubierta en un y dado. Baja hacia el fondo."""
    return qz - math.tan(ROOF_THETA) * y


def cutter(name, size, location, rotation=(0.0, 0.0, 0.0)):
    obj = box(name, size, location)
    obj.rotation_euler = rotation
    return obj


def roof_cutter(name, qz=ROOF_Q, qy=0.0):
    """Bloque enorme apoyado sobre el plano de la cubierta: quita todo lo que sobresale."""
    center = Vector((0.0, qy, qz)) + roof_normal() * 20.0
    return cutter(name, (200.0, 200.0, 40.0), tuple(center), (-ROOF_THETA, 0.0, 0.0))


def portal_cutter(name):
    """Hueco del portalón: 9 de ancho, 7,4 de alto, desde el suelo."""
    return cutter(
        name,
        (PORTAL_W, PORTAL_Y_FLOOR - PORTAL_Y_CUT, PORTAL_H + 0.5),
        (0.0, (PORTAL_Y_CUT + PORTAL_Y_FLOOR) / 2, (PORTAL_H - 0.5) / 2),
    )


def slope_slab(name, width, y_mid, z_plane, span, thick, mat):
    """Losa de cubierta apoyada sobre el plano inclinado, con su cara inferior en el plano."""
    n = Vector((0.0, math.sin(ROOF_THETA), math.cos(ROOF_THETA)))
    center = Vector((0.0, y_mid, z_plane)) + n * (thick / 2)
    length = span / math.cos(ROOF_THETA)
    obj = box(name, (width, length, thick), tuple(center), mat)
    obj.rotation_euler = (-ROOF_THETA, 0.0, 0.0)
    return obj


def fit_width(obj, max_width):
    """Reduce el rótulo de forma uniforme si no cabe en la placa."""
    width = obj.dimensions.x
    if width > max_width:
        select_only(obj)
        factor = max_width / width
        obj.scale = (factor, factor, factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def build_body(M):
    """Nivel 0: nave de ladrillo con fachada de chapa de acero, portalón, cubierta de pizarra, placa y chimenea."""
    parts = []
    body_y0 = FRONT + SKIN
    body_y1 = DEPTH / 2
    body_yc = (body_y0 + body_y1) / 2

    # Volumen de ladrillo recortado por la cubierta inclinada y el portalón.
    brick = box("body_brick", (WIDTH, body_y1 - body_y0, WALL_H), (0.0, body_yc, WALL_H / 2), M["brick"])
    perforate(brick, [roof_cutter("cut_roof_brick"), portal_cutter("cut_portal_brick")])
    parts.append(brick)

    # Fachada de chapa de acero, cortada igual que el ladrillo.
    skin = box("skin", (WIDTH, SKIN, WALL_H), (0.0, FRONT + SKIN / 2, WALL_H / 2), M["metal_acero"])
    perforate(skin, [roof_cutter("cut_roof_skin"), portal_cutter("cut_portal_skin")])
    parts.append(skin)

    # Zócalo de caliza, abierto en el portalón.
    plinth = box("plinth", (WIDTH + 0.6, DEPTH + 0.6, 0.6), (0.0, 0.0, 0.3), M["limestone"])
    perforate(plinth, [portal_cutter("cut_portal_plinth")])
    parts.append(plinth)

    # Cubierta de pizarra: losa sobre el plano inclinado, con un poco de vuelo.
    parts.append(slope_slab("roof_slate", WIDTH + 1.0, 0.0, plane_z(0.0), DEPTH + 0.8, 0.4, M["slate"]))

    # Nervios verticales de la chapa, fuera de la zona del portalón.
    for x in (-9.0, -6.6, 6.6, 9.0):
        parts.append(box("rib", (0.25, 0.25, 17.4), (x, FRONT - 0.125, 8.7), M["metal_acero"]))

    # Dos ventanas pequeñas de cristal, una a cada lado: no son hileras de pisos.
    for x in (-12.6, 12.6):
        parts.append(box("pane", (2.2, 0.1, 2.2), (x, FRONT - 0.05, 4.8), M["glass"]))

    # Persiana enrollable del portalón: lamas de chapa dentro de la hornacina y el cajón superior.
    for k in range(8):
        parts.append(box("slat", (PORTAL_W - 0.4, 0.4, 0.5), (0.0, -7.8, 0.65 + 0.85 * k), M["metal_acero"]))
    parts.append(box("shutter_head", (PORTAL_W, 1.2, 0.5), (0.0, -8.2, PORTAL_H - 0.25), M["metal_acero"]))

    # Placa de pizarra con HOJALATERO en letras de cobre, por encima del portalón.
    parts.append(box("sign_plate", (13.0, 0.3, 2.2), (0.0, FRONT - 0.15, SIGN_Z), M["slate"]))
    parts.append(fit_width(letters("HOJALATERO", 1.3, (0.0, FRONT - 0.28, SIGN_Z), M["metal"], depth=0.2), 11.5))

    # Chimenea metálica alta, en la mitad trasera.
    parts.append(cylinder("chimney", 0.7, 7.5, (8.0, 5.0, 15.75), M["metal_acero"], 12, True))
    return parts


def build_awning(M):
    """Nivel 1: toldo de chapa sobre el portalón, con canalón de cobre en el borde."""
    parts = []
    run, drop = 2.7, 0.9
    length = math.hypot(run, drop)
    angle = math.atan2(drop, run)
    # Arranca en la fachada (y -9, z 9,4) y baja hacia fuera hasta y -11,7, z 8,5.
    awning = box("awning", (10.0, length, 0.25), (0.0, FRONT - run / 2, 8.95), M["metal_acero"])
    awning.rotation_euler = (math.pi + angle, 0.0, 0.0)
    parts.append(awning)
    gutter = cylinder("gutter", 0.28, 10.0, (0.0, FRONT - run - 0.05, 8.45), M["metal"], 10, True)
    gutter.rotation_euler = (0.0, math.pi / 2, 0.0)
    parts.append(gutter)
    return parts


def sheet_stack(parts, M, x, y, count_sheets):
    """Pila de planchas de chapa tumbadas sobre el suelo, una encima de otra."""
    for k in range(count_sheets):
        parts.append(box("sheet", (3.6, 2.6, 0.14), (x, y, 0.07 + 0.14 * k), M["metal_acero"]))


def build_upgrade(M):
    """Nivel 2: mejora de fachada. Pilastra de caliza en la esquina derecha, marco de cobre en el portalón y pilas de planchas."""
    parts = []
    parts.append(box("pilaster", (1.0, 0.8, 17.5), (15.4, FRONT - 0.4, 8.75), M["limestone"]))
    for side in (-1, 1):
        parts.append(box("trim_jamb", (0.5, 0.5, PORTAL_H + 0.5), (side * 4.75, FRONT - 0.25, (PORTAL_H + 0.5) / 2), M["metal"]))
    parts.append(box("trim_lintel", (10.0, 0.5, 0.5), (0.0, FRONT - 0.25, PORTAL_H + 0.25), M["metal"]))
    # Dos pilas de planchas a la izquierda del portalón, fuera de la zona de marcadores.
    sheet_stack(parts, M, -11.4, FRONT - 2.2, 6)
    sheet_stack(parts, M, -7.4, FRONT - 2.4, 4)
    return parts


def build_nave(M):
    """Nivel 3: altillo de taller en la mitad trasera izquierda. Cambia la silueta con una cubierta propia."""
    parts = []
    yc = (NAVE_Y0 + NAVE_Y1) / 2
    nave = box("nave", (NAVE_W, NAVE_Y1 - NAVE_Y0, NAVE_Z1 - NAVE_Z0), (NAVE_X, yc, (NAVE_Z0 + NAVE_Z1) / 2), M["metal_acero"])
    perforate(nave, [roof_cutter("cut_roof_nave", qz=NAVE_ROOF_Q, qy=0.0)])
    parts.append(nave)
    parts.append(slope_slab("nave_roof", NAVE_W + 0.6, yc, plane_z(yc, NAVE_ROOF_Q), NAVE_Y1 - NAVE_Y0 + 0.6, 0.4, M["slate"]))
    parts.append(box("nave_window", (12.0, 0.2, 2.0), (NAVE_X, NAVE_Y0, 16.6), M["glass"]))
    return parts


def build_annex(M):
    """Nivel 4: ampliación visible en la esquina delantera izquierda, de ladrillo con cubierta plana de pizarra."""
    parts = []
    parts.append(box("annex", (4.0, 3.6, 7.0), (-16.0, -10.4, 3.5), M["brick"]))
    parts.append(box("annex_cap", (4.4, 3.8, 0.4), (-16.0, -10.4, 7.2), M["slate"]))
    parts.append(box("annex_window", (2.0, 0.15, 2.2), (-16.0, -12.25, 4.2), M["glass"]))
    return parts


def build_tower(M):
    """Nivel 5: torre de celosía en la mitad trasera derecha, con remate de cobre."""
    parts = []
    cx, cy = 12.5, 5.0
    half = 1.1
    z_base, z_top = 12.5, 31.0
    frames = [14.5, 20.0, 25.5, 31.0]
    corners = [(cx - half, cy - half), (cx + half, cy - half), (cx + half, cy + half), (cx - half, cy + half)]
    for x, y in corners:
        parts.append(beam("leg", (x, y, z_base), (x, y, z_top), 0.35, M["metal_acero"]))
    for z in frames:
        for i in range(4):
            a, b = corners[i], corners[(i + 1) % 4]
            parts.append(beam("bar", (a[0], a[1], z), (b[0], b[1], z), 0.25, M["metal_acero"]))
    levels = [z_base] + frames
    for z0, z1 in zip(levels[:-1], levels[1:]):
        for i in range(4):
            a, b = corners[i], corners[(i + 1) % 4]
            parts.append(beam("brace", (a[0], a[1], z0), (b[0], b[1], z1), 0.22, M["metal_acero"]))
    parts.append(cone("crown_copper", 1.5, 1.4, (cx, cy, z_top + 0.7), M["metal"]))
    return parts


def group(level, parts, store):
    """Une las piezas de un nivel en una malla por material y color. En Roblox cada malla lleva un material."""
    layer = "body" if level == 0 else f"addon{level}"
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        # Se aplican las transformaciones para que la malla unida quede en coordenadas de escena.
        for member in members:
            select_only(member)
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        rbx, suffix, rgb = RBX[key]
        name = f"hojalatero_{layer}_{rbx.lower()}{suffix}"
        mesh = join(members, name)
        uv_unwrap(mesh)
        materials = {m.name for m in mesh.data.materials if m is not None}
        if len(materials) != 1:
            raise RuntimeError(f"{name} tiene {len(materials)} materiales")
        store.append({"key": name, "level": level, "material": rbx, "rgb": rgb, "obj": mesh})


def bounds(objects):
    """Límites en studs: ancho (x), fondo (y) y alto (z) con las mallas en coordenadas de escena."""
    xs, ys, zs = [], [], []
    for obj in objects:
        for v in obj.data.vertices:
            p = obj.matrix_world @ v.co
            xs.append(p.x)
            ys.append(p.y)
            zs.append(p.z)
    return {
        "ancho": round(max(xs) - min(xs), 2),
        "fondo": round(max(ys) - min(ys), 2),
        "alto": round(max(zs) - min(zs), 2),
        "alto_maximo_sobre_suelo": round(max(zs), 2),
    }


def export(obj, filename):
    select_only(obj)
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, filename),
        use_selection=True,
        apply_scale_options="FBX_SCALE_UNITS",
        axis_forward="Z",
        axis_up="Y",
        bake_anim=False,
        add_leaf_bones=False,
    )


def place(sources, x, y=0.0):
    for source in sources:
        copy = source.copy()
        copy.location = (x, y, 0)
        copy.hide_render = False
        copy.hide_viewport = False
        bpy.context.collection.objects.link(copy)


def lights_and_world():
    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 4.2
    sun_data.angle = math.radians(1.0)
    sun = bpy.data.objects.new("sun", sun_data)
    bpy.context.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(90 - 34.0), 0, math.radians(-38))
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.68, 0.78, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    bpy.context.scene.world = world


def street_stage(M, cumulative, markers):
    """Tramo de calle con la casilla pintada de cada nivel, como en la escena del Cine Lux."""
    lot_y = STREET_WIDTH / 2 + SIDEWALK + LOT_DEPTH / 2
    building_y = lot_y + FRONT_OFFSET
    length = SPACING * 10
    box("road", (length, STREET_WIDTH, 0.4), (0, 0, -0.2), M["asphalt"])
    for sign in (-1, 1):
        box("kerb", (length, 0.5, 0.5), (0, sign * (STREET_WIDTH / 2 + 0.25), 0.0), M["limestone"])
        box("walk", (length, SIDEWALK, 0.4), (0, sign * (STREET_WIDTH / 2 + SIDEWALK / 2), 0.0), M["pavement"])
    box("lots", (length, LOT_DEPTH + 20, 0.2), (0, lot_y + 10, -0.1), M["pavement"])
    box("far", (length, 60, 0.2), (0, -STREET_WIDTH / 2 - SIDEWALK - 30, -0.1), M["pavement"])
    dash = -length / 2
    while dash < length / 2:
        box("dash", (5.0, 0.4, 0.04), (dash, 0, 0.02), M["cream"])
        dash += 11.0

    for level in range(6):
        x = (level - 2.5) * SPACING
        place(cumulative[level], x, building_y)
        box("slot", (SLOT_LENGTH, SLOT_DEPTH, 0.04), (x, SLOT_SIDE, 0.03), M["zone"])
        for sign in (-1, 1):
            box("slot_edge", (0.5, SLOT_DEPTH, 0.05), (x + sign * SLOT_LENGTH / 2, SLOT_SIDE, 0.035), M["cream"])
            box("slot_edge", (SLOT_LENGTH, 0.5, 0.05), (x, SLOT_SIDE + sign * SLOT_DEPTH / 2, 0.035), M["cream"])
        # Marcadores de nivel del juego, solo para comprobar que el edificio no los pisa.
        if level in (1, 2, 3):
            for order in range(level):
                place([markers["house"]], x + MARKER_ALONG + (order - (level - 1) / 2) * MARKER_STEP, lot_y + MARKER_FRONT)
        elif level == 4:
            place([markers["hotel"]], x + MARKER_ALONG, lot_y + MARKER_FRONT)
        elif level == 5:
            place([markers["tower"]], x + MARKER_ALONG, lot_y + MARKER_FRONT)
        gap_x = x + SPACING / 2
        lamp(gap_x, STREET_WIDTH / 2 + 2.0, M)
        tree(gap_x, -(STREET_WIDTH / 2 + SIDEWALK / 2), M)
        lamp(x, -(STREET_WIDTH / 2 + 2.0), M)

    # Ficha de referencia (caja oscura 8 × 4 × 5) y avatar de 6 de alto para la escala.
    box("ficha_ref", (8.0, 4.0, 5.0), (-2.5 * SPACING, SLOT_SIDE, 2.5), M["dark"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-2.5 * SPACING + 2.6, lot_y - 9.0, 3.0), M["avatar"])
    lights_and_world()


def hide_all():
    """Oculta la calle y sus copias para el render siguiente, sin borrar las mallas de origen."""
    for obj in bpy.data.objects:
        obj.hide_render = True
        obj.hide_viewport = True


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    scene.unit_settings.scale_length = 1.0
    os.makedirs(OUT, exist_ok=True)
    render_dir = os.path.join(REPO, "art", "render", *RENDER_SUBDIR.split("/"))
    os.makedirs(render_dir, exist_ok=True)

    M = make_materials()
    pieces = []

    # Nivel 0: cuerpo. Niveles 1 a 5: añadidos que se suman sin sustituir nada.
    group(0, build_body(M), pieces)
    builders = {1: build_awning, 2: build_upgrade, 3: build_nave, 4: build_annex, 5: build_tower}
    for level, builder in builders.items():
        group(level, builder(M), pieces)

    # Estadísticas por pieza, por nivel (propias y acumuladas) y límites.
    objects = [p["obj"] for p in pieces]
    total = sum(count(o) for o in objects)
    levels = {}
    cumulative_objects = {}
    for level in range(6):
        own = [p for p in pieces if p["level"] == level]
        cum = [p for p in pieces if p["level"] <= level]
        cumulative_objects[level] = [p["obj"] for p in cum]
        levels[str(level)] = {
            "triangulos_propios": sum(count(p["obj"]) for p in own),
            "triangulos_acumulados": sum(count(p["obj"]) for p in cum),
            "limites": bounds(cumulative_objects[level]),
        }

    # LOD1 con el conjunto entero, al 50 % como los demás edificios.
    lod = lod_of(objects, "hojalatero_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "hojalatero_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "piezas": [
            {
                "clave": p["key"],
                "nivel": p["level"],
                "material": p["material"],
                "rgb": p["rgb"],
                "triangulos": count(p["obj"]),
            }
            for p in pieces
        ],
        "niveles": levels,
        "total_triangulos": total,
        "presupuesto_triangulos": TRIANGLE_BUDGET,
        "lod1": {
            "triangulos": lod_tris,
            "porcentaje_del_total": round(100.0 * lod_tris / total, 1),
        },
        "referencia_cine_lux_nivel5": CINE_LUX_L5_TRIANGLES,
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("HOJALATERO_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] >= MAX_HEIGHT:
        raise RuntimeError(f"Altura total de {levels['5']['limites']['alto_maximo_sobre_suelo']} no baja de {MAX_HEIGHT}")

    # Escena de revisión y renders, con las mallas de origen ocultas.
    for obj in objects + [lod]:
        obj.hide_render = True
        obj.hide_viewport = True
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "callejon-del-hojalatero.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["slate"], "gold": M["metal"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -190.0, 78.0), (0.0, 22.0, 10.0), 30), f"{RENDER_SUBDIR}/callejon-del-hojalatero-niveles.png")

    # Comparación: nivel 0 frente a un bloque de Bodega (13) y otro de Cine Lux (24), a la misma distancia.
    hide_all()
    box("ground", (150, 40, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -40.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (40, 0, 12.0), M["block"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -150.0, 30.0), (0.0, 0.0, 9.0), 42), f"{RENDER_SUBDIR}/callejon-del-hojalatero-comparacion.png")
    print("HOJALATERO_DONE")


if __name__ == "__main__":
    main()

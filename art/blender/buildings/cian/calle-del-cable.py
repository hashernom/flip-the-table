"""Calle del Cable: central telefónica y taller de cables de la zona Cian, modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen está
en el centro de la base, con z = 0 a ras de suelo. Cuerpo de caliza de 17,5 y cinco añadidos que se suman:
toldo metálico con más cables, ventanales de la centralita, antena y castillete de cables, pabellón de operadores
retranqueado con cubierta a dos aguas y torre de antenas con castillete y remate de cobre (34 de alto).

El rasgo propio es el cable: cabecera de aisladores de cerámica clara sobre la cornisa, de la que baja por la
fachada un haz de cuatro cables gruesos hasta los repartidores, y castillete de cables en la cubierta.

Sigue el método de barberia-morro.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/cian/:
  calle-del-cable.blend                    escena de revisión (no se versiona)
  calle-del-cable/cable_<pieza>_<material>.fbx y cable_LOD1.fbx
  calle-del-cable/stats.json               triángulos por pieza y nivel, límites y materiales
Y en art/render/cian/calle-del-cable/: calle-del-cable-niveles.png y calle-del-cable-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/cian/calle-del-cable.py
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
OUT = os.path.join(HERE, "calle-del-cable")
RENDER_SUBDIR = "cian/calle-del-cable"
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

# --- Cuerpo (studs) -----------------------------------------------------------------------------
WIDTH = 32.0
DEPTH = 18.0
FRONT = -DEPTH / 2  # el frente da a -Y

PLINTH_H = 0.9
WALL_TOP = 16.4
CORNICE_TOP = 17.1
BODY_TOP = 17.5  # remate del antepecho y de la capilla central
ROOF_Z = 17.3  # cara superior de la cubierta: donde apoyan los añadidos
DECK_H = ROOF_Z - CORNICE_TOP

BAY_W = 12.0  # cuerpo central que sobresale: da sombra y escala al portalón
BAY_D = 0.3
BAY_FRONT = FRONT - BAY_D

CUT_DEPTH = 3.0
CUT_Y = FRONT + 1.0

DOOR_W = 4.2  # portalón: 4,2 × 7,6, muy por encima de la figura de 6
DOOR_TOP = 7.6

GW_X = 10.2  # ventanales de la sala de operadores: anchos y altos, a ambos lados del portalón
GW_W = 6.4
G_Z0, G_Z1 = 1.25, 7.05

UP_W = 4.4  # ventanales de la centralita (nivel 2): proporción vertical, distinta de la planta baja
UP_X = 10.6
UP_Z0, UP_Z1 = 10.8, 15.8

PLAQUE_W = 10.6
PLAQUE_H = 3.6
PLAQUE_Z = 10.9  # 9,1 a 12,7, sobre el portalón y el toldo, en dos líneas
SIGN_SIZE = 1.7
SIGN_LINES = (("CALLE", 11.55), ("DEL CABLE", 9.95))

# Cabecera de cables sobre la cornisa y haz que baja por la fachada.
HEAD_BAR_X = 6.45
HEAD_BAR_W = 2.4
HEAD_BAR_Z = 16.62
HEAD_Y = FRONT - 0.55
HEAD_INS_X = (-7.0, -5.9, 5.9, 7.0)
HEAD_TOP = 17.3
CABLES_X = (-7.0, -5.9, 5.9, 7.0)
CABLE_R = 0.3
CABLE_BOTTOM = 3.9
FAR_INS_X = (-14.6, 14.6)
FAR_INS_Z = 16.75
FAR_TOP = 17.04
CABINET_X = 6.45

# Nivel 1: toldo metálico y segunda hilera de cables.
AWNING_W = 7.4
AWNING_RUN = 0.55
AWNING_DROP = 0.45
AWNING_Z = 8.35
INS2_X = (-10.6, -3.5, 3.5, 10.6)
INS2_Y = FRONT - 0.58
INS2_Z = 16.38

# Nivel 3: castillete de cables y antena.
CAST_X, CAST_Y = -9.0, -5.2
CAST_TOP = 21.7
MAST_X, MAST_Y = -13.8, -4.0
MAST_TOP = 25.4

# Nivel 4: pabellón de operadores, retranqueado, con basamento de caliza y cubierta a dos aguas.
PAV_W, PAV_D, PAV_H = 24.0, 7.4, 3.8
PAV_X, PAV_Y = 0.0, 4.7
PAV_FRONT = PAV_Y - PAV_D / 2
PAV_BASE = ROOF_Z + 0.4
PAV_TOP = PAV_BASE + PAV_H

# Nivel 5: torre de antenas con castillete y remate de cobre.
TOWER_X, TOWER_Y = 10.2, -4.6
TOWER_LEG0 = 2.2
TOWER_LEG1 = 1.1
TOWER_Z0 = ROOF_Z + 2.4
TOWER_Z1 = 32.2
TOWER_MAX = 34.0

MAX_HEIGHT = 34.0
TRIANGLE_BUDGET = 3000
CINE_LUX_L5_TRIANGLES = 3042

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
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "metal_acero": ("Metal", "_acero", "8C939B"),
    "metal": ("Metal", "", "C97B3A"),
    "brick": ("Brick", "", "B0664A"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, la calle y el ambiente."""
    return {
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "metal_acero": flat("metal_acero", "8C939B", 0.4, 0.9),
        "metal": flat("metal", "C97B3A", 0.3, 0.9),
        "brick": textured("brick", "brick_warm", "B0664A"),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "22D3EE", 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "3E444B", 0.8),
    }


def cylinder(name, radius, depth, location, mat, verts, caps):
    """Cilindro vertical. Con cinco vértices basta para los aisladores de cerámica."""
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


def beam(name, a, b, thick, mat):
    """Barra cuadrada entre dos puntos: cable, montante, larguero o diagonal."""
    a, b = Vector(a), Vector(b)
    d = b - a
    obj = box(name, (thick, d.length, thick), tuple((a + b) / 2), mat)
    obj.rotation_euler = Vector((0.0, 1.0, 0.0)).rotation_difference(d.normalized()).to_euler()
    return obj


def cone(name, radius, depth, location, mat, spin=0.0):
    """Pirámide de base cuadrada, para el remate de cobre."""
    bpy.ops.mesh.primitive_cone_add(
        vertices=4, radius1=radius, radius2=0.0, depth=depth, location=location, rotation=(0.0, 0.0, spin)
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def gable(name, x0, x1, y0, y1, z_eave, z_ridge, mat):
    """Prisma de cubierta a dos aguas: dos faldones, dos hastiales y el fondo. Ocho triángulos."""
    ym = (y0 + y1) / 2
    verts = [(x0, y0, z_eave), (x1, y0, z_eave), (x1, y1, z_eave), (x0, y1, z_eave), (x0, ym, z_ridge), (x1, ym, z_ridge)]
    faces = [(0, 1, 5, 4), (3, 4, 5, 2), (0, 4, 3), (1, 2, 5), (0, 3, 2, 1)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
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


def portal_cutter(name):
    """Hueco del portalón: 4,2 de ancho y 7,6 de alto, atravesando zócalo, cuerpo central y muro."""
    return box(name, (DOOR_W, CUT_DEPTH, DOOR_TOP + 0.3), (0, CUT_Y, (DOOR_TOP - 0.3) / 2))


def build_body(M):
    """Nivel 0: central de caliza con portalón, dos ventanales de sala, cabecera de cables y cornisa."""
    parts = []

    # Muro con los huecos de verdad: portalón y los dos ventanales de la sala de operadores.
    win_cuts = [
        box("cut_gwin", (GW_W, 2.6, G_Z1 - G_Z0), (sx * GW_X, FRONT + 1.3, (G_Z0 + G_Z1) / 2))
        for sx in (-1, 1)
    ]
    wall = box("wall", (WIDTH, DEPTH, WALL_TOP), (0, 0, WALL_TOP / 2), M["limestone"])
    perforate(wall, win_cuts + [portal_cutter("cut_portal_wall")])
    parts.append(wall)

    # Cuerpo central que sobresale: recoge el portalón y la placa, y rompe la caja plana.
    bay = box("bay", (BAY_W, BAY_D, BODY_TOP), (0, FRONT - BAY_D / 2, BODY_TOP / 2), M["limestone"])
    perforate(bay, [portal_cutter("cut_portal_bay")])
    parts.append(bay)

    # Zócalo de pizarra, abierto en el portalón.
    plinth = box("plinth", (WIDTH + 0.6, DEPTH + 0.8, PLINTH_H), (0, 0, PLINTH_H / 2), M["slate"])
    perforate(plinth, [portal_cutter("cut_portal_plinth")])
    parts.append(plinth)

    # Cornisa, capilla del cuerpo central y antepecho que remata la cubierta.
    parts.append(
        box("cornice", (WIDTH + 0.8, DEPTH + 0.8, CORNICE_TOP - WALL_TOP), (0, 0, (WALL_TOP + CORNICE_TOP) / 2), M["limestone"])
    )
    parts.append(
        box("bay_cap", (BAY_W + 0.9, BAY_D + 0.55, BODY_TOP - CORNICE_TOP), (0, FRONT - (BAY_D + 0.55) / 2, (CORNICE_TOP + BODY_TOP) / 2), M["limestone"])
    )
    for sx in (-1, 1):
        parts.append(box("parapet", (10.0, 0.6, BODY_TOP - CORNICE_TOP), (sx * 11.0, FRONT - 0.1, (CORNICE_TOP + BODY_TOP) / 2), M["limestone"]))
        parts.append(box("parapet", (0.6, DEPTH + 0.8, BODY_TOP - CORNICE_TOP), (sx * (WIDTH / 2 + 0.1), 0, (CORNICE_TOP + BODY_TOP) / 2), M["limestone"]))
    parts.append(box("parapet", (WIDTH + 0.8, 0.6, BODY_TOP - CORNICE_TOP), (0, -FRONT + 0.1, (CORNICE_TOP + BODY_TOP) / 2), M["limestone"]))
    parts.append(box("roof_deck", (30.8, 17.0, DECK_H), (0, 0, CORNICE_TOP + DECK_H / 2), M["slate"]))

    # Portalón: jambas y dintel de caliza sobre el cuerpo central, y bastidor de acero dentro del hueco.
    for sx in (-1, 1):
        parts.append(box("portal_jamb", (0.9, 0.55, DOOR_TOP + 0.1), (sx * 2.55, BAY_FRONT - 0.275, (DOOR_TOP + 0.1) / 2), M["limestone"]))
    parts.append(box("portal_lintel", (6.0, 0.55, 0.9), (0, BAY_FRONT - 0.275, DOOR_TOP + 0.45), M["limestone"]))
    parts.append(box("door_glass", (DOOR_W - 0.9, 0.14, DOOR_TOP - 0.5), (0, FRONT + 0.5, (DOOR_TOP - 0.5) / 2 + 0.15), M["glass"]))
    for dx in (-1.0, 1.0):
        parts.append(box("door_bar", (0.12, 0.2, DOOR_TOP - 0.6), (dx, FRONT + 0.45, (DOOR_TOP - 0.5) / 2 + 0.15), M["metal_acero"]))
    for sx in (-1, 1):
        parts.append(box("door_jamb", (0.3, 0.5, DOOR_TOP), (sx * (DOOR_W / 2 - 0.15), FRONT + 0.55, DOOR_TOP / 2), M["metal_acero"]))
    parts.append(box("door_head", (DOOR_W, 0.5, 0.35), (0, FRONT + 0.55, DOOR_TOP - 0.175), M["metal_acero"]))
    parts.append(box("door_sill", (DOOR_W + 0.4, 0.7, 0.18), (0, FRONT + 0.35, 0.09), M["metal_acero"]))
    parts.append(box("door_transom", (DOOR_W - 0.6, 0.35, 0.18), (0, FRONT + 0.6, 5.6), M["metal_acero"]))

    # Ventanales de la sala de operadores: anchos, altos y con parteluces de acero, no ventanas de casa.
    for sx in (-1, 1):
        xc = sx * GW_X
        parts.append(box("gwin_glass", (GW_W - 0.3, 0.12, G_Z1 - G_Z0 - 0.4), (xc, FRONT + 0.5, (G_Z0 + G_Z1) / 2), M["glass"]))
        for x in (xc - GW_W / 2 - 0.3, xc + GW_W / 2 + 0.3):
            parts.append(box("gwin_jamb", (0.6, 0.5, G_Z1 - G_Z0 + 0.6), (x, FRONT - 0.25, (G_Z0 + G_Z1) / 2 + 0.2), M["limestone"]))
        parts.append(box("gwin_head", (GW_W + 1.2, 0.5, 0.6), (xc, FRONT - 0.25, G_Z1 + 0.15), M["limestone"]))
        parts.append(box("gwin_sill", (GW_W + 1.4, 0.75, 0.4), (xc, FRONT - 0.3, G_Z0 - 0.185), M["limestone"]))
        for dx in (-2.1, -0.7, 0.7, 2.1):
            parts.append(box("gwin_mullion", (0.14, 0.34, G_Z1 - G_Z0 - 0.3), (xc + dx, FRONT + 0.3, (G_Z0 + G_Z1) / 2), M["metal_acero"]))
        parts.append(box("gwin_transom", (GW_W - 0.3, 0.3, 0.13), (xc, FRONT + 0.33, G_Z0 + 2.6), M["metal_acero"]))

    # Placa de pizarra con el nombre en dos líneas de letras de caliza, encima del portalón y del toldo.
    parts.append(box("plaque", (PLAQUE_W, 0.35, PLAQUE_H), (0, BAY_FRONT - 0.175, PLAQUE_Z), M["slate"]))
    for text, z in SIGN_LINES:
        parts.append(fit_width(letters(text, SIGN_SIZE, (0, BAY_FRONT - 0.37, z), M["limestone"], depth=0.18), 9.4))

    # Cabecera de cables: barras de acero en la cornisa con aisladores de cerámica clara, y el haz de
    # cuatro cables redondos que baja por la fachada hasta los repartidores.
    for sx in (-1, 1):
        parts.append(box("head_bar", (HEAD_BAR_W, 0.32, 0.34), (sx * HEAD_BAR_X, HEAD_Y, HEAD_BAR_Z), M["metal_acero"]))
    for x in HEAD_INS_X:
        parts.append(cylinder("head_insulator", 0.3, 0.7, (x, HEAD_Y, HEAD_BAR_Z + 0.52), M["limestone"], 5, True))
    for x in CABLES_X:
        parts.append(cylinder("facade_cable", CABLE_R, HEAD_TOP - CABLE_BOTTOM, (x, FRONT - 0.35, (HEAD_TOP + CABLE_BOTTOM) / 2), M["metal_acero"], 6, True))
    # Aisladores de extremo de la cornisa y cable que cuelga de uno a otro lado.
    for x in FAR_INS_X:
        parts.append(cylinder("far_insulator", 0.26, 0.58, (x, FRONT - 0.42, FAR_INS_Z), M["limestone"], 5, True))
    for sx in (-1, 1):
        near, mid, far = sx * HEAD_BAR_X, sx * 10.7, sx * 14.6
        parts.append(beam("cornice_cable", (near, HEAD_Y, 17.25), (mid, HEAD_Y + 0.05, 16.85), 0.3, M["metal_acero"]))
        parts.append(beam("cornice_cable", (mid, HEAD_Y + 0.05, 16.85), (far, FRONT - 0.45, FAR_TOP), 0.3, M["metal_acero"]))

    # Repartidores donde remata el haz: el cableado también se ve a la altura de la calle.
    for sx in (-1, 1):
        parts.append(box("dist_cabinet", (1.5, 0.42, 3.0), (sx * CABINET_X, FRONT - 0.21, 2.4), M["slate"]))
    return parts


def build_awning(M):
    """Nivel 1: toldo metálico sobre el portalón y los ventanales, y una segunda hilera de cables."""
    parts = []
    length = math.hypot(AWNING_RUN, AWNING_DROP)
    angle = math.atan2(AWNING_DROP, AWNING_RUN)
    awning = box("awning", (AWNING_W, length, 0.15), (0, BAY_FRONT - AWNING_RUN / 2, AWNING_Z), M["metal_acero"])
    awning.rotation_euler = (angle, 0.0, 0.0)
    parts.append(awning)
    parts.append(box("awning_edge", (AWNING_W + 0.04, 0.14, 0.3), (0, BAY_FRONT - AWNING_RUN - 0.02, AWNING_Z - AWNING_DROP + 0.05), M["metal"]))
    for sx in (-1, 1):
        parts.append(beam("awning_rod", (sx * 3.1, BAY_FRONT, 9.2), (sx * 3.1, BAY_FRONT - AWNING_RUN - 0.05, AWNING_Z - 0.15), 0.1, M["metal_acero"]))
    # Toldos menores sobre los dos ventanales: el nivel 1 se ve en toda la fachada.
    run, drop = 0.55, 0.4
    length = math.hypot(run, drop)
    for sx in (-1, 1):
        canopy = box("win_awning", (GW_W + 0.6, length, 0.12), (sx * GW_X, FRONT - run / 2, 7.9), M["metal_acero"])
        canopy.rotation_euler = (math.atan2(drop, run), 0.0, 0.0)
        parts.append(canopy)
        parts.append(box("win_awning_edge", (GW_W + 0.64, 0.12, 0.26), (sx * GW_X, FRONT - run - 0.02, 7.9 - drop + 0.03), M["metal"]))
    for x in INS2_X:
        parts.append(cylinder("insulator2", 0.22, 0.52, (x, INS2_Y + 0.16, INS2_Z), M["limestone"], 5, True))
    # Segunda hilera: cable colgado entre los aisladores de arriba.
    xs = INS2_X
    for x0, x1 in zip(xs[:-1], xs[1:]):
        xm = (x0 + x1) / 2
        parts.append(beam("cable2", (x0, INS2_Y, INS2_Z + 0.26), (xm, INS2_Y, INS2_Z - 0.1), 0.16, M["metal_acero"]))
        parts.append(beam("cable2", (xm, INS2_Y, INS2_Z - 0.1), (x1, INS2_Y, INS2_Z + 0.26), 0.16, M["metal_acero"]))
    return parts


def build_centralita(M):
    """Nivel 2: los dos ventanales altos de la centralita, con recerco de caliza y parteluces de acero."""
    parts = []
    for sx in (-1, 1):
        xc = sx * UP_X
        for x in (xc - UP_W / 2 + 0.275, xc + UP_W / 2 - 0.275):
            parts.append(box("up_jamb", (0.55, 0.45, UP_Z1 - UP_Z0 + 1.0), (x, FRONT - 0.225, (UP_Z0 + UP_Z1) / 2), M["limestone"]))
        parts.append(box("up_head", (UP_W, 0.45, 0.55), (xc, FRONT - 0.225, UP_Z1 + 0.275), M["limestone"]))
        parts.append(box("up_sill", (UP_W + 0.7, 0.55, 0.35), (xc, FRONT - 0.275, UP_Z0 - 0.175), M["limestone"]))
        parts.append(box("up_glass", (UP_W - 0.8, 0.12, UP_Z1 - UP_Z0), (xc, FRONT - 0.12, (UP_Z0 + UP_Z1) / 2), M["glass"]))
        for dx in (-1.2, 0.0, 1.2):
            parts.append(box("up_mullion", (0.12, 0.2, UP_Z1 - UP_Z0 - 0.1), (xc + dx, FRONT - 0.15, (UP_Z0 + UP_Z1) / 2), M["metal_acero"]))
        parts.append(box("up_transom", (UP_W - 0.8, 0.2, 0.12), (xc, FRONT - 0.15, (UP_Z0 + UP_Z1) / 2), M["metal_acero"]))
    return parts


def build_aerial(M):
    """Nivel 3: castillete de cables en la cubierta y antena de acero con sus travesaños."""
    parts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(beam("cast_post", (CAST_X + sx * 1.9, CAST_Y + sy * 1.4, ROOF_Z), (CAST_X + sx * 1.9, CAST_Y + sy * 1.4, CAST_TOP), 0.28, M["metal_acero"]))
    for z in (ROOF_Z + 2.1, CAST_TOP - 0.1):
        parts.append(beam("cast_bar", (CAST_X - 1.9, CAST_Y - 1.4, z), (CAST_X + 1.9, CAST_Y - 1.4, z), 0.22, M["metal_acero"]))
        parts.append(beam("cast_bar", (CAST_X - 1.9, CAST_Y + 1.4, z), (CAST_X + 1.9, CAST_Y + 1.4, z), 0.22, M["metal_acero"]))
        parts.append(beam("cast_bar", (CAST_X - 1.9, CAST_Y - 1.4, z), (CAST_X - 1.9, CAST_Y + 1.4, z), 0.22, M["metal_acero"]))
        parts.append(beam("cast_bar", (CAST_X + 1.9, CAST_Y - 1.4, z), (CAST_X + 1.9, CAST_Y + 1.4, z), 0.22, M["metal_acero"]))
    parts.append(beam("cast_brace", (CAST_X - 1.9, CAST_Y - 1.4, ROOF_Z + 0.1), (CAST_X - 1.9, CAST_Y + 1.4, ROOF_Z + 2.1), 0.16, M["metal_acero"]))
    parts.append(beam("cast_brace", (CAST_X + 1.9, CAST_Y - 1.4, ROOF_Z + 2.1), (CAST_X + 1.9, CAST_Y + 1.4, ROOF_Z + 0.1), 0.16, M["metal_acero"]))

    # Aisladores del castillete y cables que bajan hasta la cabecera de la cornisa.
    tops = (CAST_X - 1.4, CAST_X, CAST_X + 1.4)
    for x in tops:
        parts.append(cylinder("cast_insulator", 0.2, 0.5, (x, CAST_Y - 1.4, CAST_TOP + 0.1), M["limestone"], 5, True))
    for x, target in zip(tops, (-14.6, -7.0, -5.9)):
        mid = ((x + target) / 2, (CAST_Y - 1.4 + HEAD_Y) / 2, 19.3)
        parts.append(beam("aerial_cable", (x, CAST_Y - 1.4, CAST_TOP + 0.35), mid, 0.14, M["metal_acero"]))
        parts.append(beam("aerial_cable", mid, (target, HEAD_Y, HEAD_TOP), 0.14, M["metal_acero"]))

    # Antena: dado de acero, mástil y tres travesaños.
    parts.append(box("mast_base", (0.9, 0.9, 0.6), (MAST_X, MAST_Y, ROOF_Z + 0.3), M["metal_acero"]))
    parts.append(box("mast", (0.24, 0.24, MAST_TOP - ROOF_Z - 0.6), (MAST_X, MAST_Y, (MAST_TOP + ROOF_Z + 0.6) / 2), M["metal_acero"]))
    for z in (21.4, 23.2, 24.9):
        parts.append(box("mast_arm", (2.6, 0.12, 0.12), (MAST_X, MAST_Y, z), M["metal_acero"]))
    return parts


def build_pavilion(M):
    """Nivel 4: pabellón de operadores retranqueado, con basamento de caliza y cubierta a dos aguas."""
    parts = []
    parts.append(box("pavilion_base", (PAV_W + 0.4, PAV_D + 0.4, PAV_BASE - ROOF_Z), (PAV_X, PAV_Y, (ROOF_Z + PAV_BASE) / 2), M["limestone"]))
    parts.append(box("pavilion", (PAV_W, PAV_D, PAV_H), (PAV_X, PAV_Y, PAV_BASE + PAV_H / 2), M["brick"]))
    parts.append(box("pavilion_eave", (PAV_W + 0.5, PAV_D + 0.5, 0.3), (PAV_X, PAV_Y, PAV_TOP + 0.15), M["limestone"]))
    parts.append(
        gable(
            "pavilion_roof",
            PAV_X - PAV_W / 2 - 0.45,
            PAV_X + PAV_W / 2 + 0.45,
            PAV_Y - PAV_D / 2 - 0.35,
            PAV_Y + PAV_D / 2 + 0.35,
            PAV_TOP + 0.3,
            PAV_TOP + 2.0,
            M["slate"],
        )
    )
    # Ventanal de centralita en el frente del pabellón, con parteluces y alféizar de caliza.
    parts.append(box("pavilion_glass", (12.6, 0.12, 2.1), (PAV_X, PAV_FRONT - 0.06, 19.7), M["glass"]))
    for k in range(4):
        parts.append(box("pavilion_mullion", (0.14, 0.2, 2.1), (PAV_X - 4.8 + k * 3.2, PAV_FRONT - 0.1, 19.7), M["metal_acero"]))
    parts.append(box("pavilion_sill", (13.2, 0.45, 0.3), (PAV_X, PAV_FRONT - 0.2, 18.45), M["limestone"]))
    return parts


def build_tower(M):
    """Nivel 5: torre ancha de celosía con castillete de cables y remate de cobre."""
    parts = []
    parts.append(box("tower_base", (4.8, 4.8, 2.4), (TOWER_X, TOWER_Y, ROOF_Z + 1.2), M["limestone"]))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(
                beam(
                    "tower_leg",
                    (TOWER_X + sx * TOWER_LEG0, TOWER_Y + sy * TOWER_LEG0, TOWER_Z0),
                    (TOWER_X + sx * TOWER_LEG1, TOWER_Y + sy * TOWER_LEG1, TOWER_Z1),
                    0.34,
                    M["metal_acero"],
                )
            )
    for z in (23.6, 27.9):
        half = TOWER_LEG0 + (TOWER_LEG1 - TOWER_LEG0) * (z - TOWER_Z0) / (TOWER_Z1 - TOWER_Z0)
        parts.append(beam("tower_bar", (TOWER_X - half, TOWER_Y - half, z), (TOWER_X + half, TOWER_Y - half, z), 0.22, M["metal_acero"]))
        parts.append(beam("tower_bar", (TOWER_X - half, TOWER_Y + half, z), (TOWER_X + half, TOWER_Y + half, z), 0.22, M["metal_acero"]))
        parts.append(beam("tower_bar", (TOWER_X - half, TOWER_Y - half, z), (TOWER_X - half, TOWER_Y + half, z), 0.22, M["metal_acero"]))
        parts.append(beam("tower_bar", (TOWER_X + half, TOWER_Y - half, z), (TOWER_X + half, TOWER_Y + half, z), 0.22, M["metal_acero"]))
    parts.append(beam("tower_brace", (TOWER_X - TOWER_LEG0, TOWER_Y - TOWER_LEG0, TOWER_Z0), (TOWER_X + 1.66, TOWER_Y - 1.66, 23.6), 0.18, M["metal_acero"]))
    parts.append(beam("tower_brace", (TOWER_X + TOWER_LEG0, TOWER_Y + TOWER_LEG0, TOWER_Z0), (TOWER_X - 1.66, TOWER_Y + 1.66, 23.6), 0.18, M["metal_acero"]))

    # Castillete de cables: tres travesaños de acero con sus aisladores de cerámica.
    for z in (29.2, 30.4, 31.6):
        parts.append(box("tower_arm", (4.8, 0.18, 0.18), (TOWER_X, TOWER_Y, z), M["metal_acero"]))
        for dx in (-1.7, 1.7):
            parts.append(cylinder("tower_insulator", 0.18, 0.5, (TOWER_X + dx, TOWER_Y, z + 0.34), M["limestone"], 5, True))

    # Remate de cobre: banda y pirámide hasta 34.
    parts.append(box("tower_band", (2.8, 2.8, 0.35), (TOWER_X, TOWER_Y, TOWER_Z1 + 0.175), M["metal"]))
    parts.append(cone("tower_cap", 1.5, TOWER_MAX - TOWER_Z1 - 0.35, (TOWER_X, TOWER_Y, (TOWER_MAX + TOWER_Z1 + 0.35) / 2), M["metal"], math.radians(45)))
    return parts


def group(level, parts, store):
    """Une las piezas de un nivel en una malla por material y color. En Roblox cada malla lleva un material."""
    layer = "body" if level == 0 else f"addon{level}"
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        # Se aplican las transformaciones para que la malla quede en coordenadas de escena.
        for member in members:
            select_only(member)
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        rbx, suffix, rgb = RBX[key]
        name = f"cable_{layer}_{rbx.lower()}{suffix}"
        # Un grupo de una sola pieza no se une: join con un solo objeto avisa «No mesh data to join».
        mesh = members[0] if len(members) == 1 else join(members, name)
        mesh.name = name
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
    if world.node_tree is None:
        world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.68, 0.78, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    bpy.context.scene.world = world


def street_stage(M, cumulative, markers):
    """Tramo de calle con la casilla pintada de cada nivel, como en la escena de la Barbería Morro."""
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

    # Ficha de referencia (caja oscura 8 × 4 × 5) y figura de 6 de alto para leer la escala.
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
    # Las FBX de una corrida anterior se borran: si una pieza desaparece, no debe quedar la vieja.
    for name in os.listdir(OUT):
        if name.startswith("cable_") and name.endswith(".fbx"):
            os.remove(os.path.join(OUT, name))
    render_dir = os.path.join(REPO, "art", "render", *RENDER_SUBDIR.split("/"))
    os.makedirs(render_dir, exist_ok=True)

    M = make_materials()
    pieces = []

    # Nivel 0: cuerpo. Niveles 1 a 5: añadidos que se suman sin sustituir nada.
    group(0, build_body(M), pieces)
    builders = {1: build_awning, 2: build_centralita, 3: build_aerial, 4: build_pavilion, 5: build_tower}
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
    lod = lod_of(objects, "cable_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "cable_LOD1.fbx")

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
    print("CABLE_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] > MAX_HEIGHT + 0.001:
        raise RuntimeError(f"Altura total de {levels['5']['limites']['alto_maximo_sobre_suelo']} supera {MAX_HEIGHT}")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "calle-del-cable.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["slate"], "gold": M["metal"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -190.0, 78.0), (0.0, 22.0, 10.0), 30), f"{RENDER_SUBDIR}/calle-del-cable-niveles.png")

    # Comparación: nivel 0 frente a un bloque de Bodega (13) y otro de Cine Lux (24), con la figura de 6 delante.
    hide_all()
    box("ground", (150, 40, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -40.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (40, 0, 12.0), M["block"])
    # Figura de 6 delante del portalón de 7,6: la escala se lee de un vistazo.
    box("avatar_ref", (1.6, 1.2, 6.0), (-36.2, -11.8, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -150.0, 30.0), (0.0, 0.0, 9.0), 42), f"{RENDER_SUBDIR}/calle-del-cable-comparacion.png")
    print("CABLE_DONE")


if __name__ == "__main__":
    main()

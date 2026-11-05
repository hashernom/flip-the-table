"""Neo Mundo: centro de convenciones del Bulevar Magenta, modelado desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de 16 —las dos alas, la masa principal— y la sala grande al fondo, que
asoma por encima; cinco añadidos que se suman: marquesina y vestíbulo, bandas de cristal y acceso, lucernarios
y sala grande, pabellón anexo de exposiciones y torre del auditorio con remate de metal.
El rasgo único es el portal abierto entre las dos alas: un vano de 10 × 13 sin puerta, de doce de fondo, con el
vestíbulo de cristal y la sala al final, y el nombre en la faja que lo corona. Se distingue de Centro Páez
(atrio de cristal y pez dorado) y de Plaza del Neón (marquesina grande de bolera) por ese hueco.
Sigue el método de barberia-morro.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/magenta/:
  neo-mundo.blend                   escena de revisión (no se versiona)
  neo-mundo/neomundo_<pieza>_<material>.fbx y neomundo_LOD1.fbx
  neo-mundo/stats.json              triángulos por pieza y nivel, límites y materiales
Y en art/render/magenta/neo-mundo/: neo-mundo-niveles.png y neo-mundo-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/magenta/neo-mundo.py
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "neo-mundo")
RENDER_SUBDIR = "magenta/neo-mundo"
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
BACK = DEPTH / 2
BODY_H = 16.0  # masa principal: las dos alas
COPE_Z = 16.5  # cara superior del remate de caliza de las alas
DECK_Z = 16.75  # cara superior de la cubierta de pizarra de las alas
WING_OUTER = 16.0
WING_INNER_FRONT = 7.0  # cara interior del ala en la fachada: el portal mide 14
WING_INNER_BACK = 6.2  # al fondo el vano se estrecha a 12,4: las alas convergen
HALL_Y0 = 3.0  # donde empieza la sala grande
HALL_TOP = 19.2  # la sala asoma por encima de las alas
HALL_CAP_TOP = 19.7
HALL_DECK_TOP = 19.9
PORTAL_TOP = 13.0  # el vano sube hasta la faja del rótulo: dos plantas y media de alto
PIER_W = 1.5  # el ala se adelanta junto al portal: dos machones que lo enmarcan
PIER_Y = FRONT - 0.9
FASCIA_Z0 = PORTAL_TOP
FASCIA_HALF = 8.1
FASCIA_FRONT = FRONT + 0.14  # la faja va 0,14 por detrás de las alas: sin caras coplanares
FASCIA_BACK = -7.8  # la faja es un dintel de 1,2 de fondo entre las dos alas
BACKER_HALF = 6.6
BACKER_Z0 = 13.35
BACKER_Z1 = 15.45
SIGN_SIZE = 2.35
APRON = (14.2, 1.4, 0.24)  # escalón de entrada, delante del vano
LOBBY_W = 9.6  # vestíbulo de cristal al fondo del patio
LOBBY_Z0 = 0.6
LOBBY_Z1 = 11.2
LOBBY_RECESS = 0.45
CLERESTORY_W = 30.0  # banda de cristal alta de la sala
CLERESTORY_Z0 = 16.8
CLERESTORY_Z1 = 19.0
REVEAL_Z = 9.0  # línea de acero que continúa la marquesina por las alas
DECK_X = 10.425  # cubierta de pizarra del ala derecha (la izquierda es su espejo)
DECK_W = 10.25
DECK_Y = -3.0
DECK_D = 11.1
RIBBON_Z0 = 13.4  # banda de cristal del nivel 2, bajo el remate
RIBBON_Z1 = 15.2
RIBBON_FRONT = (8.9, 15.4)  # tramo de la banda en la fachada de cada ala
RIBBON_Y = 8.0

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
TRIANGLE_BUDGET = 3000
CINE_LUX_L5_TRIANGLES = 3042
MAX_HEIGHT = 34.0
MAX_LEVEL0_HEIGHT = 21.0
FRONT_LIMIT = -10.0
LOT_HALF_WIDTH = 18.0

# Material de Roblox, sufijo de color y RGB de cada clave de material de Blender.
RBX = {
    "limestone": ("Limestone", "", "D2C9B4"),
    "glass": ("Glass", "", "2E4A63"),
    "slate": ("Slate", "", "4A4E54"),
    "metal_acero": ("Metal", "_acero", "A8AEB4"),
    "metal_oro": ("Metal", "_oro", "C9A227"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "slate": flat("slate", "4A4E54", 0.85),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.25, 0.8),
        "metal_oro": flat("metal_oro", "C9A227", 0.3, 0.9),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "E85D9E", 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "3A4046", 0.8),
    }


def prism_z(name, points, z0, z1, mat):
    """Prisma vertical: polígono del plano XY extruido de z0 a z1 (la planta de cada ala)."""
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    build = bmesh.new()
    low = [build.verts.new((x, y, z0)) for x, y in points]
    high = [build.verts.new((x, y, z1)) for x, y in points]
    build.faces.new(list(reversed(low)))
    build.faces.new(high)
    total = len(points)
    for index in range(total):
        nxt = (index + 1) % total
        build.faces.new((low[index], low[nxt], high[nxt], high[index]))
    bmesh.ops.recalc_face_normals(build, faces=build.faces)
    build.to_mesh(mesh)
    build.free()
    obj.data.materials.append(mat)
    return obj


def cone(name, radius, depth, location, mat, verts=4):
    """Pirámide de base regular, para el remate metálico de la torre."""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def wing_points(side):
    """Planta del ala: costado exterior recto y cara interior que converge hacia la sala."""
    return [
        (side * WING_INNER_FRONT, FRONT),
        (side * WING_OUTER, FRONT),
        (side * WING_OUTER, HALL_Y0),
        (side * WING_INNER_BACK, HALL_Y0),
    ]


def wing_base_points(side):
    """Planta del ala de abajo: se adelanta junto al portal y forma el machón que lo enmarca."""
    return [
        (side * WING_INNER_FRONT, PIER_Y),
        (side * (WING_INNER_FRONT + PIER_W), PIER_Y),
        (side * (WING_INNER_FRONT + PIER_W), FRONT),
        (side * WING_OUTER, FRONT),
        (side * WING_OUTER, HALL_Y0),
        (side * WING_INNER_BACK, HALL_Y0),
    ]


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
    """Nivel 0: dos alas de caliza con el portal abierto entre ellas, la sala grande al fondo y el rótulo."""
    parts = []

    # Las dos alas y su remate de caliza. La cara interior converge: el vano pasa de 10 a 8,4. El tramo bajo
    # se adelanta junto al portal: dos machones de 1,5 × 0,9 que lo enmarcan y le dan escala.
    for side in (-1, 1):
        parts.append(prism_z("wing_base", wing_base_points(side), 0.0, PORTAL_TOP, M["limestone"]))
        parts.append(prism_z("wing", wing_points(side), PORTAL_TOP, BODY_H, M["limestone"]))
        parts.append(prism_z("wing_coping", wing_points(side), BODY_H, COPE_Z, M["limestone"]))
        parts.append(
            box("wing_deck", (DECK_W, DECK_D, DECK_Z - COPE_Z), (side * DECK_X, DECK_Y, (COPE_Z + DECK_Z) / 2), M["slate"])
        )

    # Sala grande: un volumen de caliza que asoma por encima de las alas. Con huecos de verdad: el vestíbulo
    # y la banda de cristal de la planta alta, para que no se lea como una caja con rectángulos pegados.
    lobby_cut = box(
        "cut_lobby",
        (LOBBY_W, 0.75, LOBBY_Z1 - LOBBY_Z0),
        (0.0, HALL_Y0 - 0.30 + 0.375, (LOBBY_Z0 + LOBBY_Z1) / 2),
    )
    clerestory_cut = box(
        "cut_clerestory",
        (CLERESTORY_W, 0.75, CLERESTORY_Z1 - CLERESTORY_Z0),
        (0.0, HALL_Y0 - 0.30 + 0.375, (CLERESTORY_Z0 + CLERESTORY_Z1) / 2),
    )
    hall = box("hall", (WIDTH, BACK - HALL_Y0, HALL_TOP), (0.0, (HALL_Y0 + BACK) / 2, HALL_TOP / 2), M["limestone"])
    side_cuts = [
        box("cut_clerestory_side", (0.75, 5.0, CLERESTORY_Z1 - CLERESTORY_Z0), (side * WIDTH / 2, 6.0, (CLERESTORY_Z0 + CLERESTORY_Z1) / 2))
        for side in (-1, 1)
    ]
    perforate(hall, [lobby_cut, clerestory_cut, *side_cuts])
    parts.append(hall)

    # Cristal al fondo de cada hueco: dentro no hay interior modelado.
    glass_back = HALL_Y0 + LOBBY_RECESS - 0.06
    parts.append(box("lobby_glass", (LOBBY_W - 0.1, 0.12, LOBBY_Z1 - LOBBY_Z0 - 0.1), (0.0, glass_back, (LOBBY_Z0 + LOBBY_Z1) / 2), M["glass"]))
    parts.append(box("clerestory_glass", (CLERESTORY_W - 0.1, 0.12, CLERESTORY_Z1 - CLERESTORY_Z0 - 0.1), (0.0, glass_back, (CLERESTORY_Z0 + CLERESTORY_Z1) / 2), M["glass"]))
    for side in (-1, 1):
        parts.append(box("clerestory_glass_side", (0.12, 4.9, CLERESTORY_Z1 - CLERESTORY_Z0 - 0.1), (side * (WIDTH / 2 - 0.33), 6.0, (CLERESTORY_Z0 + CLERESTORY_Z1) / 2), M["glass"]))

    # Remate de la sala, cubierta de pizarra y equipos de climatización.
    parts.append(box("hall_cap", (WIDTH + 0.6, (BACK - HALL_Y0) + 0.6, HALL_CAP_TOP - HALL_TOP), (0.0, (HALL_Y0 + BACK) / 2, (HALL_TOP + HALL_CAP_TOP) / 2), M["limestone"]))
    parts.append(box("hall_deck", (WIDTH - 0.4, (BACK - HALL_Y0) - 0.4, HALL_DECK_TOP - HALL_CAP_TOP), (0.0, (HALL_Y0 + BACK) / 2, (HALL_CAP_TOP + HALL_DECK_TOP) / 2), M["slate"]))
    parts.append(box("hvac_a", (3.0, 2.2, 0.8), (-11.8, 6.4, HALL_DECK_TOP + 0.4), M["slate"]))
    parts.append(box("hvac_b", (2.6, 2.0, 0.7), (12.2, 6.6, HALL_DECK_TOP + 0.35), M["slate"]))

    # Faja del rótulo: un dintel de caliza que cruza el vano arriba y lo corona. El nombre va en letras de
    # acero sobre un panel de pizarra, para que se lea desde la calle.
    parts.append(box("fascia", (2 * FASCIA_HALF, FASCIA_BACK - FASCIA_FRONT, BODY_H - FASCIA_Z0), (0.0, (FASCIA_FRONT + FASCIA_BACK) / 2, (FASCIA_Z0 + BODY_H) / 2), M["limestone"]))
    parts.append(box("sign_backer", (2 * BACKER_HALF, 0.14, BACKER_Z1 - BACKER_Z0), (0.0, FASCIA_FRONT - 0.07, (BACKER_Z0 + BACKER_Z1) / 2), M["slate"]))
    name = letters("NEO MUNDO", SIGN_SIZE, (0.0, FASCIA_FRONT - 0.26, (BACKER_Z0 + BACKER_Z1) / 2), M["metal_acero"], depth=0.16)
    parts.append(fit_width(name, 2 * BACKER_HALF - 0.7))

    # Patio: suelo de caliza y escalón de entrada, para que el vano se lea como un zaguán y no como un hueco.
    parts.append(box("court_floor", (11.8, 11.8, 0.18), (0.0, -3.0, 0.09), M["limestone"]))
    parts.append(box("apron", APRON, (0.0, -9.18, APRON[2] / 2), M["limestone"]))

    # Zócalo de caliza y línea de acero a la altura de la marquesina: dos trazos que ordenan la fachada lisa.
    face_inner = WING_INNER_FRONT + PIER_W
    for side in (-1, 1):
        parts.append(box("plinth", (WING_OUTER - face_inner, 0.24, 0.55), (side * ((WING_OUTER + face_inner) / 2), FRONT - 0.12, 0.275), M["limestone"]))
        parts.append(box("reveal", (WING_OUTER - face_inner, 0.14, 0.22), (side * ((WING_OUTER + face_inner) / 2), FRONT - 0.07, REVEAL_Z), M["metal_acero"]))
    return parts


def build_marquee(M):
    """Nivel 1: marquesina que cruza el portal y vestíbulo con podio, columnas y dosel."""
    parts = []
    # Marquesina: losa de acero con faja de caliza, apoyada en los dos machones a 8,4 de alto.
    parts.append(box("marquee", (14.4, 1.60, 0.58), (0.0, -9.05, 8.71), M["metal_acero"]))
    parts.append(box("marquee_fascia", (14.5, 0.24, 0.62), (0.0, -9.78, 8.71), M["limestone"]))

    # Vestíbulo: podio de caliza, dos columnas de acero y dosel, delante del cristal de la sala.
    parts.append(box("porch_podium", (10.2, 3.25, 0.32), (0.0, 1.375, 0.16), M["limestone"]))
    parts.append(box("porch_step", (10.6, 0.55, 0.16), (0.0, -0.50, 0.08), M["limestone"]))
    for side in (-1, 1):
        parts.append(box("porch_column", (0.26, 0.26, 7.28), (side * 4.3, 0.90, 3.96), M["metal_acero"]))
    parts.append(box("porch_canopy", (10.0, 2.95, 0.24), (0.0, 1.525, 7.72), M["metal_acero"]))

    # Marco de las puertas del vestíbulo, por delante del cristal del fondo.
    for side in (-1, 1):
        parts.append(box("door_jamb", (0.22, 0.35, 7.10), (side * 2.80, 3.225, 3.55), M["metal_acero"]))
    parts.append(box("door_head", (5.82, 0.35, 0.25), (0.0, 3.225, 7.22), M["metal_acero"]))
    for side in (-1, 1):
        parts.append(box("door_leaf", (2.55, 0.06, 6.85), (side * 1.35, 3.30, 3.48), M["glass"]))
    return parts


def build_ribbon(M):
    """Nivel 2: bandas de cristal bajo el remate de las alas y jambas de acero que forran el portal."""
    parts = []
    band_w = RIBBON_FRONT[1] - RIBBON_FRONT[0]
    band_x = (RIBBON_FRONT[0] + RIBBON_FRONT[1]) / 2
    for side in (-1, 1):
        centre = side * band_x
        parts.append(box("ribbon_pane", (band_w, 0.10, RIBBON_Z1 - RIBBON_Z0), (centre, FRONT - 0.04, (RIBBON_Z0 + RIBBON_Z1) / 2), M["glass"]))
        parts.append(box("ribbon_head", (band_w + 0.5, 0.30, 0.22), (centre, FRONT - 0.13, RIBBON_Z1 + 0.08), M["metal_acero"]))
        parts.append(box("ribbon_sill", (band_w + 0.5, 0.30, 0.22), (centre, FRONT - 0.13, RIBBON_Z0 - 0.08), M["metal_acero"]))
        for offset in (-band_w / 2, 0.0, band_w / 2):
            parts.append(box("ribbon_mullion", (0.14, 0.26, RIBBON_Z1 - RIBBON_Z0), (centre + offset, FRONT - 0.10, (RIBBON_Z0 + RIBBON_Z1) / 2), M["metal_acero"]))
        parts.append(box("side_ribbon", (0.10, RIBBON_Y, RIBBON_Z1 - RIBBON_Z0), (side * (WING_OUTER - 0.04), -2.6, (RIBBON_Z0 + RIBBON_Z1) / 2), M["glass"]))
        parts.append(box("side_ribbon_head", (0.30, RIBBON_Y + 0.5, 0.22), (side * (WING_OUTER + 0.13), -2.6, RIBBON_Z1 + 0.08), M["metal_acero"]))
        parts.append(box("side_ribbon_sill", (0.30, RIBBON_Y + 0.5, 0.22), (side * (WING_OUTER + 0.13), -2.6, RIBBON_Z0 - 0.08), M["metal_acero"]))

    # Acceso: el vano se forra con dos jambas de acero y un dintel hasta la faja del rótulo.
    for side in (-1, 1):
        parts.append(box("portal_jamb", (0.45, 0.38, PORTAL_TOP), (side * 6.75, FRONT - 0.10, PORTAL_TOP / 2), M["metal_acero"]))
    parts.append(box("portal_head", (13.9, 0.40, 0.30), (0.0, FRONT - 0.10, PORTAL_TOP - 0.15), M["metal_acero"]))
    return parts


def build_hall_top(M):
    """Nivel 3: la sala grande sube por encima del remate con su banda de cristal, y cuatro lucernarios."""
    parts = []
    parts.append(box("drum_low", (15.0, 5.3, 2.0), (0.0, 6.05, HALL_DECK_TOP + 1.0), M["limestone"]))
    parts.append(box("drum_glass", (14.8, 5.1, 0.9), (0.0, 6.05, 22.35), M["glass"]))
    parts.append(box("drum_high", (15.0, 5.3, 0.7), (0.0, 6.05, 23.15), M["limestone"]))
    parts.append(box("drum_cap", (15.4, 5.7, 0.3), (0.0, 6.05, 23.65), M["limestone"]))
    for x in (-6.0, -3.0, 0.0, 3.0, 6.0):
        parts.append(box("drum_mullion", (0.12, 0.16, 0.98), (x, 3.44, 22.35), M["metal_acero"]))
    for side in (-1, 1):
        for y in (-6.3, -3.2):
            parts.append(box("skylight_curb", (3.8, 3.4, 0.5), (side * 11.0, y, DECK_Z + 0.25), M["limestone"]))
            parts.append(box("skylight_glass", (3.5, 3.1, 0.12), (side * 11.0, y, DECK_Z + 0.56), M["glass"]))
    return parts


def build_pavilion(M):
    """Nivel 4: pabellón anexo de exposiciones sobre el ala izquierda, retranqueado del frente."""
    parts = []
    centre = -10.6
    parts.append(box("pavilion_base", (9.0, 3.1, 2.2), (centre, 0.95, 17.85), M["limestone"]))
    parts.append(box("pavilion_glass", (8.8, 2.9, 1.9), (centre, 0.95, 19.90), M["glass"]))
    parts.append(box("pavilion_cap", (9.3, 3.4, 0.22), (centre, 0.95, 20.96), M["slate"]))
    for x in (-3.0, -1.0, 1.0, 3.0):
        parts.append(box("pavilion_mullion", (0.12, 0.16, 1.9), (centre + x, -0.56, 19.90), M["metal_acero"]))
    return parts


def build_tower(M):
    """Nivel 5: torre del auditorio sobre el ala derecha, con el vano del portal en grande y remate de metal."""
    parts = []
    cx, cy, deep = 10.6, 0.775, 3.55
    parts.append(box("tower_low", (6.0, deep, 2.60), (cx, cy, 18.05), M["limestone"]))
    parts.append(box("tower_glass", (5.8, deep - 0.2, 2.0), (cx, cy, 20.35), M["glass"]))
    parts.append(box("tower_high", (6.0, deep, 3.00), (cx, cy, 22.85), M["limestone"]))
    parts.append(box("tower_band", (6.3, deep + 0.3, 0.35), (cx, cy, 24.525), M["metal_oro"]))
    # Dos pilares y un vano abierto: el portal del nivel 0 repetido en lo alto de la torre.
    for side in (-1, 1):
        parts.append(box("tower_pier", (1.80, deep, 4.50), (cx + side * 2.10, cy, 26.95), M["limestone"]))
    parts.append(box("tower_lintel", (6.20, deep + 0.2, 1.20), (cx, cy, 29.80), M["limestone"]))
    parts.append(box("tower_cap", (5.90, deep - 0.25, 0.25), (cx, cy, 30.525), M["metal_oro"]))
    parts.append(box("tower_step", (4.70, deep - 0.85, 0.55), (cx, cy, 30.925), M["metal_oro"]))
    crown = cone("tower_crown", 2.4, 1.70, (cx, cy, 32.05), M["metal_oro"])
    crown.rotation_euler = (0.0, 0.0, math.radians(45.0))
    parts.append(crown)
    for x in (-1.8, 0.0, 1.8):
        parts.append(box("tower_mullion", (0.12, 0.16, 2.10), (cx + x, cy - deep / 2 + 0.04, 20.35), M["metal_acero"]))
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
        name = f"neomundo_{layer}_{rbx.lower()}{suffix}"
        # Con una sola pieza no se une nada: unir una malla consigo misma avisa «No mesh data to join».
        if len(members) == 1:
            mesh = members[0]
            mesh.name = name
        else:
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
        for vertex in obj.data.vertices:
            point = obj.matrix_world @ vertex.co
            xs.append(point.x)
            ys.append(point.y)
            zs.append(point.z)
    return {
        "ancho": round(max(xs) - min(xs), 2),
        "fondo": round(max(ys) - min(ys), 2),
        "alto": round(max(zs) - min(zs), 2),
        "alto_maximo_sobre_suelo": round(max(zs), 2),
        "frente": round(min(ys), 2),
        "fondo_maximo": round(max(ys), 2),
        "x_min": round(min(xs), 2),
        "x_max": round(max(xs), 2),
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
    box("avatar_ref", (1.6, 1.2, 6.0), (-2.5 * SPACING + 6.4, building_y + FRONT - 1.4, 3.0), M["avatar"])
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
    builders = {1: build_marquee, 2: build_ribbon, 3: build_hall_top, 4: build_pavilion, 5: build_tower}
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
    lod = lod_of(objects, "neomundo_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "neomundo_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "altura_cuerpo": BODY_H,
        "altura_portal": PORTAL_TOP,
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
    print("NEOMUNDO_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    top0 = levels["0"]["limites"]
    if top0["alto_maximo_sobre_suelo"] > MAX_LEVEL0_HEIGHT:
        raise RuntimeError(f"Nivel 0 de {top0['alto_maximo_sobre_suelo']} pasa de {MAX_LEVEL0_HEIGHT}")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] > MAX_HEIGHT:
        raise RuntimeError(f"Altura total de {levels['5']['limites']['alto_maximo_sobre_suelo']} pasa de {MAX_HEIGHT}")
    for level, data in levels.items():
        limits = data["limites"]
        if limits["frente"] < FRONT_LIMIT - 0.02:
            raise RuntimeError(f"Nivel {level}: el frente llega a {limits['frente']}, más allá de {FRONT_LIMIT}")
        if max(abs(limits["x_min"]), abs(limits["x_max"])) > LOT_HALF_WIDTH:
            raise RuntimeError(f"Nivel {level}: se sale del solar a lo ancho ({limits['x_min']} a {limits['x_max']})")
        if limits["fondo_maximo"] > 13.0:
            raise RuntimeError(f"Nivel {level}: se sale por el fondo ({limits['fondo_maximo']})")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "neo-mundo.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["metal_acero"], "gold": M["metal_oro"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -190.0, 78.0), (0.0, 22.0, 10.0), 30), f"{RENDER_SUBDIR}/neo-mundo-niveles.png")

    # Comparación: el nivel 0 al centro y, a los lados, un bloque de Bodega (13) y otro de Cine Lux (24), con
    # la figura de 6 delante de la fachada y al lado del portal, que es lo que permite revisar la puerta.
    hide_all()
    box("ground", (180, 46, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], 0.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (-34.0, 0.0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (34.0, 0.0, 12.0), M["block"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-10.0, -10.6, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -88.0, 14.0), (0.0, 0.0, 9.0), 28), f"{RENDER_SUBDIR}/neo-mundo-comparacion.png")
    print("NEOMUNDO_DONE")


if __name__ == "__main__":
    main()

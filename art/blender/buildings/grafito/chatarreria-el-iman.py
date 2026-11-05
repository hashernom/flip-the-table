"""Chatarrería El Imán: propiedad de la zona Grafito (distrito industrial), modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de ladrillo de 15 (la nave) y cinco añadidos que se suman: portal y
marquesina, mejora de fachada, clasificación de chatarra, pabellón de reciclaje y torre de la grúa con remate
de cobre. Delante de la nave, un patio cercado con grúa de imán y pilas: el imán y las pilas son el rasgo, y
tienen que leerse ya en el nivel 0.

Sigue el método de barberia-morro.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/grafito/:
  chatarreria-el-iman.blend                  escena de revisión (no se versiona)
  chatarreria-el-iman/iman_<pieza>_<material>.fbx y iman_LOD1.fbx
  chatarreria-el-iman/stats.json             triángulos por pieza y nivel, límites y materiales
Y en art/render/grafito/chatarreria-el-iman/: chatarreria-el-iman-niveles.png y -comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/grafito/chatarreria-el-iman.py
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
OUT = os.path.join(HERE, "chatarreria-el-iman")
RENDER_SUBDIR = "grafito/chatarreria-el-iman"
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
BODY_H = 15.0  # altura del cuerpo: la nave
NAVE_FRONT = -3.0  # fachada de la nave; delante queda el patio
NAVE_DEPTH = BACK - NAVE_FRONT
YARD_DEPTH = NAVE_FRONT - FRONT

PORTAL_W = 9.0  # portalón, como el de la Bodega
PORTAL_H = 7.4  # más alto que el avatar (6)
PORTAL_X = -6.0
PORTAL_Y = -4.0
PORTAL_REVEAL = 1.5  # fondo de la hornacina del portalón

WIN_W = 1.8
WIN_H = 5.2
WIN_Z = 2.2
WINDOW_X = (-13.2, 1.2)  # dos ventanas altas, una a cada lado del portalón

PLATE_W = 16.0
PLATE_Z = 10.85
LETTERS_SIZE = 1.5

GATE_X = (-13.0, -1.0)  # hueco del portón en la cerca
FENCE_TOP = 2.2
FENCE_WALL = 0.75
FENCE_T = 0.45

SAW_Y0, SAW_Y1 = -3.0, 2.0  # dientes de sierra sobre la crujía delantera
DECK_Y0, DECK_Y1 = 2.0, 9.0
SAW_RISE = 1.8
SAW_TEETH = 4

CRANE_X, CRANE_Y = 9.6, -5.8
CRANE_TOP = 3.4  # alto del cuerpo de la grúa, donde arranca el mástil
MAST_TOP = 16.2  # cabeza del mástil: la pluma sale de aquí
JIB_TIP = 4.6  # punta de la pluma, sobre la pila de coches
TOWER_X, TOWER_Y = 13.8, -6.4
TOWER_TOP = 36.0
CROWN_TOP = 38.4

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

# Material de Roblox, sufijo de color y RGB de cada clave de material de Blender.
RBX = {
    "brick": ("Brick", "", "B0664A"),
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "metal": ("Metal", "", "A8AEB4"),
    "metal_grafito": ("Metal", "_grafito", "64748B"),
    "metal_oro": ("Metal", "_oro", "C9A227"),
    "fabric_rojo": ("Fabric", "_rojo", "C4382B"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "metal": flat("metal", "A8AEB4", 0.3, 0.9),
        "metal_grafito": flat("metal_grafito", "64748B", 0.35, 0.9),
        "metal_oro": flat("metal_oro", "C9A227", 0.3, 0.9),
        "fabric_rojo": flat("fabric_rojo", "C4382B", 0.8),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "64748B", 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "6E747C", 0.8),
    }


def cylinder(name, radius, depth, location, mat, verts=10, caps=True, rotation=(0.0, 0.0, 0.0)):
    """Cilindro. Con `rotation` se tumba para hacer tubos y barriles."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts,
        radius=radius,
        depth=depth,
        end_fill_type="NGON" if caps else "NOTHING",
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def cone(name, radius, depth, location, mat, verts=4):
    """Pirámide: remate de cobre de la torre."""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def beam(name, a, b, thick, mat):
    """Barra cuadrada entre dos puntos: montante, larguero o diagonal de celosía."""
    a, b = Vector(a), Vector(b)
    d = b - a
    obj = box(name, (thick, d.length, thick), tuple((a + b) / 2), mat)
    obj.rotation_euler = Vector((0.0, 1.0, 0.0)).rotation_difference(d.normalized()).to_euler()
    return obj


def tilted(name, size, location, mat, rotation_z=0.0, rotation_y=0.0):
    """Caja con un pequeño giro: los fardos y las chapas de la chatarra no están a escuadra."""
    obj = box(name, size, location, mat)
    obj.rotation_euler = (0.0, rotation_y, rotation_z)
    return obj


def fit_width(obj, max_width):
    """Reduce el rótulo de forma uniforme si no cabe en la placa."""
    bpy.context.view_layer.update()
    width = obj.dimensions.x
    if width > max_width:
        select_only(obj)
        factor = max_width / width
        obj.scale = (factor, factor, factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def build_body(M):
    """Nivel 0: patio cercado, nave con portalón, pilas de chatarra y grúa de imán."""
    parts = []

    # Solera del patio: la chatarra y la cerca tienen que pisar algo, no flotar sobre la casilla.
    parts.append(box("patio", (WIDTH, YARD_DEPTH, 0.25), (0.0, (FRONT + NAVE_FRONT) / 2, 0.125), M["limestone"]))

    # Nave de ladrillo con huecos de verdad: el portalón y dos ventanas altas con derrame.
    portal_cut = box("cut_portal", (PORTAL_W, 5.0, PORTAL_H + 0.5), (PORTAL_X, PORTAL_Y, (PORTAL_H - 0.5) / 2))
    window_cuts = [
        box("cut_win", (WIN_W, 4.2, WIN_H), (x, -3.9, WIN_Z + WIN_H / 2)) for x in WINDOW_X
    ]
    wall = box("nave", (WIDTH, NAVE_DEPTH, BODY_H), (0.0, (NAVE_FRONT + BACK) / 2, BODY_H / 2), M["brick"])
    perforate(wall, [portal_cut] + window_cuts)
    parts.append(wall)

    # Zócalo de caliza, cortado en el portalón.
    plinth = box("plinth", (WIDTH + 0.4, NAVE_DEPTH + 0.4, 0.9), (0.0, (NAVE_FRONT + BACK) / 2 + 0.05, 0.45), M["limestone"])
    perforate(plinth, [box("cut_portal2", (PORTAL_W + 0.3, 5.0, 1.6), (PORTAL_X, PORTAL_Y, 0.75))])
    parts.append(plinth)
    parts.append(box("cornice", (WIDTH + 0.6, NAVE_DEPTH + 0.6, 0.6), (0.0, (NAVE_FRONT + BACK) / 2, 14.7), M["limestone"]))

    # Cubierta en dientes de sierra: la silueta industrial de la nave, distinta de la chimenea y la marquesina.
    tooth = WIDTH / SAW_TEETH
    theta = math.atan2(SAW_RISE, tooth)
    for k in range(SAW_TEETH):
        x0 = -WIDTH / 2 + k * tooth
        normal = Vector((-math.sin(theta), 0.0, math.cos(theta)))
        center = Vector((x0 + tooth / 2, (SAW_Y0 + SAW_Y1) / 2, BODY_H + SAW_RISE / 2)) + normal * 0.15
        slope = box("saw", (math.hypot(tooth, SAW_RISE), SAW_Y1 - SAW_Y0, 0.3), tuple(center), M["slate"])
        slope.rotation_euler = (0.0, -theta, 0.0)
        parts.append(slope)
        parts.append(
            box(
                "saw_face",
                (0.3, SAW_Y1 - SAW_Y0, SAW_RISE),
                (x0 + tooth, (SAW_Y0 + SAW_Y1) / 2, BODY_H + SAW_RISE / 2),
                M["glass"],
            )
        )
    parts.append(box("deck", (WIDTH, DECK_Y1 - DECK_Y0, 0.35), (0.0, (DECK_Y0 + DECK_Y1) / 2, BODY_H + 0.17), M["slate"]))
    for x, y in ((-7.0, 5.2), (3.0, 6.8), (11.0, 4.6)):
        parts.append(box("vent", (1.5, 1.5, 1.5), (x, y, BODY_H + 1.1), M["metal_grafito"]))

    # Ventanas: cristal oscuro al fondo del derrame. Detrás no hay interior.
    for x in WINDOW_X:
        parts.append(box("pane", (WIN_W - 0.1, 0.1, WIN_H - 0.1), (x, -1.88, WIN_Z + WIN_H / 2), M["glass"]))

    # Portalón: marco de acero y la persiana recogida dentro de la hornacina.
    parts.append(box("portal_head", (PORTAL_W + 1.0, 0.55, 0.6), (PORTAL_X, -3.0, PORTAL_H + 0.3), M["metal"]))
    for sign in (-1, 1):
        parts.append(box("portal_jamb", (0.45, 0.55, PORTAL_H), (PORTAL_X + sign * (PORTAL_W / 2 + 0.1), -3.0, PORTAL_H / 2), M["metal"]))
    for k in range(3):
        parts.append(box("shutter", (PORTAL_W - 0.4, 0.25, 0.45), (PORTAL_X, -2.1, PORTAL_H - 0.45 - 0.5 * k), M["metal"]))

    # Placa de caliza con panel de pizarra y el nombre en letras de acero.
    parts.append(box("placa", (PLATE_W, 0.5, 2.8), (PORTAL_X, -3.15, PLATE_Z), M["limestone"]))
    parts.append(box("placa_panel", (PLATE_W - 1.1, 0.25, 2.1), (PORTAL_X, -3.42, PLATE_Z), M["slate"]))
    sign = letters("CHATARRERÍA EL IMÁN", LETTERS_SIZE, (PORTAL_X, -3.56, PLATE_Z), M["metal"], depth=0.18)
    parts.append(fit_width(sign, PLATE_W - 2.4))

    # Cerca: muro bajo de caliza y barandilla de acero, con el hueco del portón delante de la nave.
    def fence_run(x0, x1, y0, y1, first_post=True):
        """Tramo de cerca: muro bajo, barrote de acero y postes repartidos."""
        length = math.hypot(x1 - x0, y1 - y0)
        horizontal = abs(y1 - y0) < 1e-6
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        size = (length, FENCE_T, FENCE_WALL) if horizontal else (FENCE_T, length, FENCE_WALL)
        parts.append(box("fence_wall", size, (cx, cy, FENCE_WALL / 2), M["limestone"]))
        rail = (length, 0.18, 0.16) if horizontal else (0.18, length, 0.16)
        parts.append(box("fence_rail", rail, (cx, cy, FENCE_TOP - 0.08), M["metal"]))
        steps = max(1, int(round(length / 4.6)))
        for k in range(0 if first_post else 1, steps + 1):
            t = k / steps
            parts.append(box("fence_post", (0.24, 0.24, FENCE_TOP), (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, FENCE_TOP / 2), M["metal"]))

    fence_run(-WIDTH / 2, GATE_X[0] - 0.65, FRONT, FRONT)
    fence_run(GATE_X[1] + 0.65, WIDTH / 2, FRONT, FRONT)
    fence_run(-WIDTH / 2, -WIDTH / 2, FRONT, NAVE_FRONT, first_post=False)
    fence_run(WIDTH / 2, WIDTH / 2, FRONT, NAVE_FRONT, first_post=False)

    # Pilas de chatarra clasificada: volúmenes geométricos, sin marcas ni anagramas.
    for k in range(5):
        parts.append(
            tilted(
                "cars",
                (3.6, 2.2, 0.8),
                (5.6 + (0.16 if k % 2 else -0.12), -5.4 + (0.1 if k % 2 else -0.12), 0.55 + 0.82 * k),
                M["metal"],
                rotation_z=0.045 * (-1) ** k,
            )
        )
    for k in range(3):
        parts.append(
            tilted(
                "bale",
                (2.6, 2.6, 1.6),
                (-14.4 + 0.1 * (-1) ** k, -5.2 + 0.08 * (-1) ** k, 0.85 + 1.62 * k),
                M["metal_grafito"],
                rotation_z=0.06 * (-1) ** k,
            )
        )

    # Grúa de imán: orugas, cuerpo, mástil, pluma de celosía y el imán con la chatarra pegada.
    for sign in (-1, 1):
        parts.append(box("track", (1.15, 4.4, 1.0), (CRANE_X + sign * 1.25, CRANE_Y, 0.5), M["metal_grafito"]))
    parts.append(box("crane_body", (2.9, 3.2, 2.4), (CRANE_X, CRANE_Y, 2.2), M["metal"]))
    parts.append(box("crane_cab", (1.7, 1.6, 1.7), (CRANE_X - 1.9, CRANE_Y + 0.3, 3.2), M["metal_grafito"]))
    parts.append(box("mast", (1.3, 1.3, MAST_TOP - CRANE_TOP), (CRANE_X, CRANE_Y, (MAST_TOP + CRANE_TOP) / 2), M["metal"]))
    # Pluma: dos cordones horizontales con celosía entre ellos, y el contrapeso al otro lado.
    jib_span = CRANE_X - JIB_TIP
    for sign in (-1, 1):
        parts.append(box("jib", (jib_span, 0.22, 0.22), ((CRANE_X + JIB_TIP) / 2, CRANE_Y, MAST_TOP + sign * 0.62), M["metal"]))
    for k in range(4):
        x0 = JIB_TIP + jib_span * k / 4
        z0 = MAST_TOP + (0.62 if k % 2 == 0 else -0.62)
        parts.append(beam("jib_brace", (x0, CRANE_Y, z0), (x0 + jib_span / 4, CRANE_Y, 2 * MAST_TOP - z0), 0.13, M["metal"]))
    parts.append(box("jib_heel", (1.0, 1.0, 1.8), (CRANE_X, CRANE_Y, MAST_TOP), M["metal_grafito"]))
    parts.append(box("jib_weight", (1.1, 1.4, 1.2), (CRANE_X + 1.9, CRANE_Y, MAST_TOP - 0.2), M["slate"]))
    parts.append(box("crane_head", (0.7, 0.8, 0.7), (JIB_TIP, CRANE_Y, MAST_TOP), M["metal_grafito"]))
    parts.append(box("cable", (0.09, 0.09, 7.9), (JIB_TIP, CRANE_Y, 11.85), M["metal"]))
    parts.append(cylinder("magnet", 1.45, 2.0, (JIB_TIP, CRANE_Y, 7.6), M["slate"], 12))
    parts.append(cylinder("magnet_collar", 0.55, 0.5, (JIB_TIP, CRANE_Y, 8.75), M["metal"], 8))
    parts.append(box("magnet_load", (3.2, 1.9, 0.6), (JIB_TIP, CRANE_Y, 6.3), M["metal"]))
    return parts


def build_gate(M):
    """Nivel 1: marquesina de acero sobre el portalón y pórtico del portón en la cerca."""
    parts = []
    parts.append(box("marquesina", (PORTAL_W + 3.0, 2.6, 0.3), (PORTAL_X, -4.4, 8.3), M["metal"]))
    for x in (PORTAL_X - 5.2, PORTAL_X + 5.2):
        parts.append(beam("marquesina_tie", (x, -3.0, 9.4), (x, -5.6, 8.45), 0.2, M["metal"]))
    # Dos pilares de portón, por encima de la cerca: el acceso se lee desde la calle sin cerrar la vista.
    for x in GATE_X:
        parts.append(box("gate_pier", (1.2, 1.2, 6.0), (x, FRONT, 3.0), M["limestone"]))
        parts.append(box("gate_cap", (1.6, 1.6, 0.35), (x, FRONT, 6.17), M["limestone"]))
    return parts


def build_facade(M):
    """Nivel 2: mejora de fachada. Pilastras, imposta, marcos de las ventanas y cerco de acero de la placa."""
    parts = []
    for sign in (-1, 1):
        parts.append(box("pilaster", (1.4, 0.7, BODY_H), (sign * 15.3, NAVE_FRONT, BODY_H / 2), M["brick"]))
    parts.append(box("imposta", (WIDTH + 0.4, 0.6, 0.55), (0.0, NAVE_FRONT, 13.9), M["limestone"]))
    for x in WINDOW_X:
        parts.append(box("win_head", (WIN_W + 0.7, 0.45, 0.3), (x, NAVE_FRONT, WIN_Z + WIN_H + 0.15), M["metal"]))
        parts.append(box("win_sill", (WIN_W + 0.7, 0.55, 0.28), (x, NAVE_FRONT - 0.05, WIN_Z - 0.14), M["limestone"]))
        parts.append(box("win_jamb", (0.25, 0.45, WIN_H), (x - WIN_W / 2 - 0.2, NAVE_FRONT, WIN_Z + WIN_H / 2), M["metal"]))
        parts.append(box("win_jamb", (0.25, 0.45, WIN_H), (x + WIN_W / 2 + 0.2, NAVE_FRONT, WIN_Z + WIN_H / 2), M["metal"]))
    for z in (PLATE_Z - 1.55, PLATE_Z + 1.55):
        parts.append(box("placa_frame", (PLATE_W + 0.5, 0.4, 0.3), (PORTAL_X, -3.05, z), M["metal_grafito"]))
    for sign in (-1, 1):
        parts.append(box("placa_frame", (0.3, 0.4, 3.4), (PORTAL_X + sign * (PLATE_W / 2 + 0.1), -3.05, PLATE_Z), M["metal_grafito"]))
    return parts


def build_sorting(M):
    """Nivel 3: clasificación. La pila de fardos sube y la chatarra se cubre con lona roja."""
    parts = []
    for k in range(4):
        parts.append(
            tilted(
                "bale2",
                (2.4 - 0.14 * k, 2.4 - 0.14 * k, 1.6),
                (-14.4 + 0.1 * (-1) ** k, -5.2 + 0.08 * (-1) ** k, 4.92 + 1.62 * k),
                M["metal"],
                rotation_z=0.07 * (-1) ** k,
            )
        )
    parts.append(tilted("tarp", (3.8, 2.5, 0.25), (5.6, -5.4, 4.22), M["fabric_rojo"], rotation_z=0.06))
    return parts


def build_annex(M):
    """Nivel 4: pabellón anexo de reciclaje, retranqueado sobre la crujía trasera de la nave."""
    parts = []
    parts.append(box("annex", (14.0, 6.5, 7.4), (-9.0, 5.75, BODY_H + 3.7), M["brick"]))
    parts.append(box("annex_band", (14.4, 6.9, 0.45), (-9.0, 5.75, BODY_H + 2.6), M["metal_grafito"]))
    parts.append(box("annex_cap", (14.6, 6.9, 0.45), (-9.0, 5.75, BODY_H + 7.6), M["slate"]))
    parts.append(box("annex_grille", (7.0, 0.25, 2.4), (-9.0, 2.45, BODY_H + 4.6), M["slate"]))
    parts.append(box("annex_door", (3.2, 0.3, 3.6), (-13.6, 2.45, BODY_H + 1.8), M["metal"]))
    return parts


def build_tower(M):
    """Nivel 5: torre de celosía de la grúa en el patio, con remate de cobre. Afina hacia arriba."""
    parts = []
    base_half, top_half = 1.6, 1.0

    def corners_at(z):
        half = base_half + (top_half - base_half) * (z / TOWER_TOP)
        return [
            (TOWER_X - half, TOWER_Y - half),
            (TOWER_X + half, TOWER_Y - half),
            (TOWER_X + half, TOWER_Y + half),
            (TOWER_X - half, TOWER_Y + half),
        ]

    parts.append(box("tower_base", (4.0, 4.0, 0.7), (TOWER_X, TOWER_Y, 0.35), M["limestone"]))
    bottom, top = corners_at(0.0), corners_at(TOWER_TOP)
    for i in range(4):
        parts.append(beam("tower_leg", (bottom[i][0], bottom[i][1], 0.0), (top[i][0], top[i][1], TOWER_TOP), 0.34, M["metal"]))
    for z in (7.0, 14.0, 21.0, 28.0, 34.5):
        ring = corners_at(z)
        for i in range(4):
            a, b = ring[i], ring[(i + 1) % 4]
            parts.append(beam("tower_ring", (a[0], a[1], z), (b[0], b[1], z), 0.2, M["metal"]))
    for z0, z1 in ((7.0, 14.0), (21.0, 28.0)):
        low, high = corners_at(z0), corners_at(z1)
        for i in (0, 2):
            parts.append(beam("tower_brace", (low[i][0], low[i][1], z0), (high[i + 1][0], high[i + 1][1], z1), 0.16, M["metal"]))
    parts.append(cone("tower_cap", 1.5, 2.2, (TOWER_X, TOWER_Y, TOWER_TOP + 1.1), M["metal_oro"]))
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
        name = f"iman_{layer}_{rbx.lower()}{suffix}"
        # Un grupo de una sola pieza no se une: join consigo mismo avisa «No mesh data to join».
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
    builders = {1: build_gate, 2: build_facade, 3: build_sorting, 4: build_annex, 5: build_tower}
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
    lod = lod_of(objects, "iman_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "iman_LOD1.fbx")

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
    print("IMAN_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if levels["0"]["limites"]["alto_maximo_sobre_suelo"] > 20.0:
        raise RuntimeError(f"Nivel 0 de {levels['0']['limites']['alto_maximo_sobre_suelo']} pasa de 20")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] > CROWN_TOP + 0.05:
        raise RuntimeError(f"Nivel 5 de {levels['5']['limites']['alto_maximo_sobre_suelo']} pasa del remate")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "chatarreria-el-iman.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["slate"], "gold": M["metal"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -182.0, 74.0), (0.0, 22.0, 19.0), 30.5), f"{RENDER_SUBDIR}/chatarreria-el-iman-niveles.png")

    # Comparación: nivel 0 frente a un bloque de Bodega (13) y otro de Cine Lux (24), con una figura de 6
    # delante de la fachada y al lado del portalón: sin ella no se puede revisar la puerta.
    hide_all()
    box("ground", (150, 40, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -40.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (40, 0, 12.0), M["block"])
    box("figura_6", (1.6, 1.2, 6.0), (-40.0 - 11.6, -10.8, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -150.0, 20.0), (0.0, 0.0, 8.0), 46), f"{RENDER_SUBDIR}/chatarreria-el-iman-comparacion.png")
    print("IMAN_DONE")


if __name__ == "__main__":
    main()

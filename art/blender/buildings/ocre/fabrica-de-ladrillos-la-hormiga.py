"""Fábrica de Ladrillos La Hormiga: propiedad de la zona Ocre (sector del ladrillo), modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de 21 (la nave del horno) y cinco añadidos que se suman: toldo de carga y
naves de secado; puertas del horno y mejora de fachada; chimenea y patio de arcilla; pabellón anexo de oficinas,
retranqueado; y torre de la chimenea con remate de cobre. El nivel 0 completo no pasa de 26 y el nivel 5 no
llega a 40.

Se reconoce sin leer el rótulo: chimenea alta de ladrillo sobre el horno, naves de secado largas con lucernarios
y cerchas, portalón de carga y patio de arcilla. La silueta (chimenea + naves escalonadas) es distinta de la del
Almacén El Ladrillo (marquesina y depósito) y de la Curtiembre Los Nogales (secaderos de listones).

Sigue el método de barberia-morro.py: una malla por material y color, LOD1 con decimado y los mismos helpers de
build_cine_lux.py.

Salidas, en art/blender/buildings/ocre/:
  fabrica-de-ladrillos-la-hormiga.blend                              escena de revisión (no se versiona)
  fabrica-de-ladrillos-la-hormiga/hormiga_<pieza>_<material>.fbx y hormiga_LOD1.fbx
  fabrica-de-ladrillos-la-hormiga/stats.json                         triángulos por pieza y nivel, límites y materiales
Y en art/render/ocre/fabrica-de-ladrillos-la-hormiga/:
  fabrica-de-ladrillos-la-hormiga-niveles.png y fabrica-de-ladrillos-la-hormiga-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/ocre/fabrica-de-ladrillos-la-hormiga.py
"""

import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "fabrica-de-ladrillos-la-hormiga")
RENDER_SUBDIR = "ocre/fabrica-de-ladrillos-la-hormiga"
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
BODY_H = 21.0  # masa principal: la nave del horno
MAX_HEIGHT = 40.0  # altura máxima con el nivel 5, decidida por el responsable
LEVEL0_MAX = 26.0  # el nivel 0 completo, cubierta incluida, no pasa de aquí

# Nave del horno (cuerpo).
HALL_X0 = -1.0
HALL_X1 = 16.0
GATE_W = 9.0  # portalón de carga, como el de la Bodega
GATE_H = 7.4  # más alto que una figura de 6
GATE_CX = 7.5
HALL_WIN_W = 9.4  # ventanal alto de la nave, uno y ancho: no es una hilera de ventanitas
HALL_WIN_H = 2.6
HALL_WIN_Z = 16.3
HALL_WIN_Y = -8.0  # fondo del hueco, por detrás del plano de fachada

# Horno: pecho de ladrillo delante de la nave y chimenea.
KILN_X0 = -5.0
KILN_X1 = -1.0
KILN_FRONT = -9.7
KILN_BACK = -5.4
KILN_H = 9.8
CHIMNEY_X = -3.0
CHIMNEY_Y = -7.55
CHIMNEY_W = 2.6
CHIMNEY_TOP0 = 25.47
ARCH_R = 1.55
ARCH_Z = 3.6

# Naves de secado: dos cuerpos en L que dejan el patio delante.
SHED_X0 = -16.0
SHED_FRONT_X1 = -8.8
SHED_X1 = -5.0
SHED_H = 12.2
SHED_CORNICE_TOP = 12.6
SHED_DECK_TOP = 12.8
SHED_BACK_Y = -6.0  # fondo del patio
PATIO_X0 = SHED_FRONT_X1
PATIO_X1 = SHED_X1
PATIO_BACK = SHED_BACK_Y
MONITORS = (  # (x0, x1, y0, y1, alto sobre la cubierta)
    (SHED_X0, SHED_FRONT_X1, -8.5, -3.5, 1.5),
    (SHED_X0, SHED_X1, -2.5, 2.5, 2.3),
    (SHED_X0, SHED_X1, 3.5, 8.5, 3.1),
)
RIDGE3_TOP = SHED_DECK_TOP + 3.1 + 0.16  # 16,06: donde apoya la nave alta del nivel 1

# Nivel 1: toldo de carga sobre el portalón y nave alta de secado.
CANOPY_W = 9.8
CANOPY_DEPTH = 0.95
CANOPY_Z = 8.42
LOFT_X0, LOFT_X1 = -15.2, -5.8
LOFT_Y0, LOFT_Y1 = 4.3, 8.4
LOFT_Z0 = RIDGE3_TOP - 0.06
LOFT_H = 3.8

# Nivel 4: pabellón de oficinas retranqueado sobre la cubierta.
OFFICE_X0, OFFICE_X1 = 8.2, 15.6
OFFICE_Y0, OFFICE_Y1 = 3.2, 8.6
OFFICE_Z0 = 21.9
OFFICE_H = 4.8

# Nivel 5: torre de la chimenea.
TOWER_TOP = 39.8

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

# Material de Roblox, sufijo de color y RGB de cada clave de material de Blender.
RBX = {
    "brick": ("Brick", "", "B0664A"),
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "metal_acero": ("Metal", "_acero", "A8AEB4"),
    "metal_oro": ("Metal", "_oro", "C9A227"),
    "metal_ocre": ("Metal", "_ocre", "A16207"),
    "wood": ("Wood", "", "6B4A2E"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.35, 0.9),
        "metal_oro": flat("metal_oro", "C9A227", 0.3, 0.9),
        "metal_ocre": flat("metal_ocre", "A16207", 0.45, 0.7),
        "wood": flat("wood", "6B4A2E", 0.75),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "A16207", 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "6E747C", 0.8),
    }


def cone(name, radius, depth, location, mat, verts=8, rotation=None):
    """Cono: remates de cobre y pilas de arcilla del patio."""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    if rotation:
        obj.rotation_euler = rotation
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


def simplify(obj, ratio=0.62):
    """Aligera el rótulo ya convertido a malla: los glifos gastan más triángulos de los que se ven a escala."""
    select_only(obj)
    modifier = obj.modifiers.new("simplify", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = ratio
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def louver_band(parts, M, name, x0, x1, y, z0, z1, slats=5, thick=0.14):
    """Bandas de lamas de acero: respiraderos de las naves, no ventanas."""
    span = (z1 - z0) / slats
    for k in range(slats):
        parts.append(box(f"{name}_slat{k}", (x1 - x0, thick, span * 0.46), ((x0 + x1) / 2, y, z0 + span * (k + 0.5)), M["metal_acero"]))
    for x in (x0 + 0.08, x1 - 0.08):
        parts.append(box(f"{name}_post", (0.16, thick + 0.06, z1 - z0), (x, y, (z0 + z1) / 2), M["metal_acero"]))


def monitor_ridge(parts, M, name, x0, x1, y0, y1, base, height):
    """Lucernario corrido de la nave de secado: hueco de verdad, cristal al fondo y tapa de pizarra."""
    width = x1 - x0
    depth = y1 - y0
    glass_h = height - 0.3
    parts.append(box(f"{name}_sill", (width, 0.16, 0.2), ((x0 + x1) / 2, y0 + 0.08, base + 0.1), M["slate"]))
    parts.append(box(f"{name}_back", (width, 0.16, height), ((x0 + x1) / 2, y1 - 0.08, base + height / 2), M["slate"]))
    for x in (x0 + 0.09, x1 - 0.09):
        parts.append(box(f"{name}_side", (0.18, depth, height), (x, (y0 + y1) / 2, base + height / 2), M["slate"]))
    parts.append(box(f"{name}_cap", (width + 0.2, depth + 0.2, 0.16), ((x0 + x1) / 2, (y0 + y1) / 2, base + height + 0.08), M["slate"]))
    parts.append(box(f"{name}_glass", (width - 0.5, 0.08, glass_h), ((x0 + x1) / 2, y0 + 0.15, base + 0.18 + glass_h / 2), M["glass"]))


def gate_truss(M):
    """Cercha de acero que se ve por el portalón abierto: la nave tiene estructura, no es una caja."""
    parts = []
    y = -7.3
    parts.append(box("truss_bottom", (8.7, 0.16, 0.18), (GATE_CX, y, 6.35), M["metal_acero"]))
    parts.append(box("truss_top", (8.7, 0.16, 0.18), (GATE_CX, y, 7.25), M["metal_acero"]))
    for x in (5.0, 7.5, 10.0):
        parts.append(box("truss_post", (0.14, 0.14, 0.9), (x, y, 6.8), M["metal_acero"]))
    for x, sign in ((6.25, 1), (8.75, -1)):
        diagonal = box("truss_diag", (1.45, 0.14, 0.14), (x, y, 6.8), M["metal_acero"])
        diagonal.rotation_euler = (0, sign * math.radians(38), 0)
        parts.append(diagonal)
    return parts


def build_body(M):
    """Nivel 0: nave del horno con portalón, horno con chimenea, naves de secado y patio de arcilla."""
    parts = []

    # --- Nave del horno: un solo ventanal alto, no hileras de ventanitas de vivienda.
    hall = box("hall", (HALL_X1 - HALL_X0, DEPTH, BODY_H), ((HALL_X0 + HALL_X1) / 2, 0.0, BODY_H / 2), M["brick"])
    perforate(
        hall,
        [
            box("cut_gate", (GATE_W, 2.2, GATE_H + 0.3), (GATE_CX, FRONT + 0.9, GATE_H / 2 - 0.15)),
            box("cut_hall_win", (HALL_WIN_W, 1.2, HALL_WIN_H), (GATE_CX, FRONT + 0.5, HALL_WIN_Z)),
        ],
    )
    parts.append(hall)

    # Zócalo de caliza, abierto en el portalón; pilastras de ladrillo en las esquinas.
    parts.append(box("plinth_l", (4.0, 0.4, 0.8), (1.0, FRONT - 0.15, 0.4), M["limestone"]))
    parts.append(box("plinth_r", (4.0, 0.4, 0.8), (14.0, FRONT - 0.15, 0.4), M["limestone"]))
    for x in (-0.55, 15.55):
        parts.append(box("corner_pilaster", (0.9, 0.55, BODY_H), (x, FRONT - 0.05, BODY_H / 2), M["brick"]))

    # Cornisa y cubierta de pizarra. La cubierta es plana: la chimenea y el pabellón harán la silueta.
    parts.append(box("hall_cornice", (HALL_X1 - HALL_X0 + 0.8, DEPTH + 0.8, 0.7), (7.5, 0, BODY_H + 0.35), M["limestone"]))
    parts.append(box("hall_roof", (HALL_X1 - HALL_X0 + 0.2, DEPTH + 0.2, 0.3), (7.5, 0, BODY_H + 0.85), M["slate"]))

    # Portalón: dintel, guías, umbral y la cercha que se ve dentro. Queda abierto: mide 9 × 7,4.
    parts.append(box("gate_lintel", (GATE_W + 0.8, 0.65, 0.55), (GATE_CX, FRONT - 0.12, GATE_H + 0.28), M["metal_acero"]))
    for x in (2.88, 12.12):
        parts.append(box("gate_guide", (0.28, 0.35, GATE_H), (x, FRONT - 0.08, GATE_H / 2), M["metal_acero"]))
    parts.append(box("gate_threshold", (8.9, 1.9, 0.16), (GATE_CX, FRONT + 1.0, 0.08), M["limestone"]))
    parts.extend(gate_truss(M))

    # Ventanal alto de la nave: hueco de verdad en el ladrillo, cristal al fondo y marco de acero.
    parts.append(box("hall_win_glass", (HALL_WIN_W - 0.3, 0.1, HALL_WIN_H - 0.2), (GATE_CX, HALL_WIN_Y, HALL_WIN_Z), M["glass"]))
    parts.append(box("hall_win_head", (HALL_WIN_W + 0.6, 0.3, 0.3), (GATE_CX, FRONT - 0.02, HALL_WIN_Z + HALL_WIN_H / 2 + 0.15), M["metal_acero"]))
    parts.append(box("hall_win_sill", (HALL_WIN_W + 0.7, 0.5, 0.3), (GATE_CX, FRONT - 0.08, HALL_WIN_Z - HALL_WIN_H / 2 - 0.15), M["limestone"]))
    for x in (GATE_CX - 2.8, GATE_CX, GATE_CX + 2.8):
        parts.append(box("hall_win_mullion", (0.18, 0.3, HALL_WIN_H), (x, FRONT - 0.06, HALL_WIN_Z), M["metal_acero"]))

    # Rótulo en placa de pizarra con el nombre en letras 3D de caliza, por encima del portalón y del toldo.
    parts.append(box("sign_plate", (15.2, 0.36, 4.2), (7.5, FRONT - 0.08, 11.5), M["slate"]))
    line1 = letters("FÁBRICA DE LADRILLOS", 1.30, (7.5, FRONT - 0.34, 12.35), M["limestone"], depth=0.2)
    line2 = letters("LA HORMIGA", 1.70, (7.5, FRONT - 0.34, 10.55), M["limestone"], depth=0.2)
    parts.append(simplify(fit_width(line1, 14.2)))
    parts.append(simplify(fit_width(line2, 9.2)))

    # --- Horno: pecho de ladrillo con boca ciega, chimenea alta y su corona de caliza.
    kiln = box("kiln", (KILN_X1 - KILN_X0, KILN_FRONT - KILN_BACK, KILN_H), ((KILN_X0 + KILN_X1) / 2, (KILN_FRONT + KILN_BACK) / 2, KILN_H / 2), M["brick"])
    perforate(kiln, [box("cut_kiln_mouth", (3.0, 0.6, 3.9), (CHIMNEY_X, KILN_FRONT + 0.25, 1.85))])
    parts.append(kiln)
    parts.append(box("kiln_coping", (4.3, 4.6, 0.35), (CHIMNEY_X, (KILN_FRONT + KILN_BACK) / 2, KILN_H + 0.175), M["limestone"]))

    parts.append(box("chimney", (CHIMNEY_W, CHIMNEY_W, CHIMNEY_TOP0), (CHIMNEY_X, CHIMNEY_Y, CHIMNEY_TOP0 / 2), M["brick"]))
    for z in (13.5, 18.5, 23.2):
        parts.append(box("chimney_band", (CHIMNEY_W + 0.12, CHIMNEY_W + 0.12, 0.14), (CHIMNEY_X, CHIMNEY_Y, z), M["metal_acero"]))
    parts.append(box("chimney_corbel", (2.9, 2.9, 0.3), (CHIMNEY_X, CHIMNEY_Y, 24.85), M["brick"]))
    parts.append(box("chimney_crown", (3.0, 3.0, 0.35), (CHIMNEY_X, CHIMNEY_Y, 25.175), M["limestone"]))
    parts.append(box("chimney_cap", (3.1, 3.1, 0.12), (CHIMNEY_X, CHIMNEY_Y, 25.41), M["limestone"]))

    # --- Naves de secado: dos cuerpos en L; el patio queda delante, entre la nave y el horno.
    shed_front = box("shed_front", (SHED_FRONT_X1 - SHED_X0, DEPTH, SHED_H), ((SHED_X0 + SHED_FRONT_X1) / 2, 0, SHED_H / 2), M["brick"])
    perforate(shed_front, [box("cut_cart_door", (3.6, 0.6, 5.7), ((SHED_X0 + SHED_FRONT_X1) / 2, FRONT + 0.25, 2.75))])
    parts.append(shed_front)
    parts.append(box("shed_back", (SHED_X1 - PATIO_X0, -SHED_BACK_Y + DEPTH / 2, SHED_H), ((PATIO_X0 + SHED_X1) / 2, (SHED_BACK_Y + DEPTH / 2) / 2, SHED_H / 2), M["brick"]))
    for x0, x1, y0, y1 in ((SHED_X0, SHED_FRONT_X1, FRONT, DEPTH / 2), (PATIO_X0, SHED_X1, SHED_BACK_Y, DEPTH / 2)):
        parts.append(box("shed_cornice", (x1 - x0, y1 - y0, 0.4), ((x0 + x1) / 2, (y0 + y1) / 2, SHED_CORNICE_TOP - 0.2), M["limestone"]))
        parts.append(box("shed_deck", (x1 - x0, y1 - y0, 0.2), ((x0 + x1) / 2, (y0 + y1) / 2, SHED_DECK_TOP - 0.1), M["slate"]))
    for x0, x1, y0, y1, height in MONITORS:
        monitor_ridge(parts, M, "monitor", x0, x1, y0, y1, SHED_DECK_TOP, height)

    # Puerta de carros de la nave de secado, de madera, dentro de un hueco de verdad.
    parts.append(box("cart_panel", (3.4, 0.14, 5.4), ((SHED_X0 + SHED_FRONT_X1) / 2, FRONT + 0.5, 2.7), M["wood"]))
    for z in (1.0, 2.7, 4.4):
        parts.append(box("cart_brace", (3.5, 0.08, 0.18), ((SHED_X0 + SHED_FRONT_X1) / 2, FRONT + 0.43, z), M["wood"]))
    parts.append(box("cart_lintel", (4.2, 0.5, 0.35), ((SHED_X0 + SHED_FRONT_X1) / 2, FRONT - 0.02, 5.75), M["limestone"]))
    louver_band(parts, M, "shed_louver", SHED_X0 + 0.3, SHED_FRONT_X1 - 0.3, FRONT - 0.04, 8.4, 9.8, 5)
    parts.append(box("shed_louver_sill", (6.8, 0.45, 0.2), ((SHED_X0 + SHED_FRONT_X1) / 2, FRONT - 0.02, 8.3), M["limestone"]))
    parts.append(box("shed_plinth_l", (1.35, 0.4, 0.6), (SHED_X0 + 0.675, FRONT - 0.12, 0.3), M["limestone"]))
    parts.append(box("shed_plinth_r", (1.35, 0.4, 0.6), (SHED_FRONT_X1 - 0.675, FRONT - 0.12, 0.3), M["limestone"]))

    # --- Patio de arcilla: suelo de caliza, muro bajo de ladrillo y cancela de acero.
    parts.append(box("patio_floor", (PATIO_X1 - PATIO_X0, PATIO_BACK - FRONT, 0.16), ((PATIO_X0 + PATIO_X1) / 2, (FRONT + PATIO_BACK) / 2, 0.08), M["limestone"]))
    for x0, x1 in ((PATIO_X0, -7.9), (-5.9, PATIO_X1)):
        parts.append(box("patio_wall", (x1 - x0, 0.3, 1.1), ((x0 + x1) / 2, FRONT + 0.15, 0.55), M["brick"]))
    for x in (-8.0, -5.8):
        parts.append(box("patio_pier", (0.25, 0.35, 1.5), (x, FRONT + 0.18, 0.75), M["brick"]))
    parts.append(box("patio_gate_top", (2.0, 0.1, 0.1), (-6.9, FRONT + 0.2, 1.15), M["metal_acero"]))
    parts.append(box("patio_gate_mid", (2.0, 0.1, 0.08), (-6.9, FRONT + 0.2, 0.6), M["metal_acero"]))
    for x in (-7.55, -7.15, -6.75, -6.35):
        parts.append(box("patio_bar", (0.07, 0.07, 1.1), (x, FRONT + 0.2, 0.55), M["metal_acero"]))
    return parts


def build_toldo(M):
    """Nivel 1: toldo de carga sobre el portalón y nave alta de secado sobre el lucernario trasero."""
    parts = []
    parts.append(box("canopy_deck", (CANOPY_W, CANOPY_DEPTH, 0.16), (GATE_CX, FRONT - CANOPY_DEPTH / 2, CANOPY_Z), M["metal_acero"]))
    parts.append(box("canopy_fascia", (CANOPY_W, 0.08, 0.32), (GATE_CX, FRONT - CANOPY_DEPTH + 0.04, CANOPY_Z - 0.12), M["metal_acero"]))
    for x in (GATE_CX - 3.4, GATE_CX + 3.4):
        bracket = box("canopy_bracket", (0.12, 1.15, 0.12), (x, FRONT - 0.42, CANOPY_Z - 0.1), M["metal_acero"])
        bracket.rotation_euler = (math.radians(-32), 0, 0)
        parts.append(bracket)
    parts.append(box("canopy_rail", (CANOPY_W - 0.6, 0.12, 0.14), (GATE_CX, FRONT - CANOPY_DEPTH + 0.1, CANOPY_Z - 0.02), M["metal_acero"]))

    # Nave alta: segundo piso de secado sobre la crujía trasera, con lamas y lucernario propios.
    parts.append(box("loft", (LOFT_X1 - LOFT_X0, LOFT_Y1 - LOFT_Y0, LOFT_H), ((LOFT_X0 + LOFT_X1) / 2, (LOFT_Y0 + LOFT_Y1) / 2, LOFT_Z0 + LOFT_H / 2), M["brick"]))
    parts.append(box("loft_cornice", (LOFT_X1 - LOFT_X0 + 0.3, LOFT_Y1 - LOFT_Y0 + 0.3, 0.3), ((LOFT_X0 + LOFT_X1) / 2, (LOFT_Y0 + LOFT_Y1) / 2, LOFT_Z0 + LOFT_H + 0.15), M["limestone"]))
    parts.append(box("loft_roof", (LOFT_X1 - LOFT_X0 + 0.1, LOFT_Y1 - LOFT_Y0 + 0.1, 0.2), ((LOFT_X0 + LOFT_X1) / 2, (LOFT_Y0 + LOFT_Y1) / 2, LOFT_Z0 + LOFT_H + 0.4), M["slate"]))
    louver_band(parts, M, "loft_louver", LOFT_X0 + 0.3, LOFT_X1 - 0.3, LOFT_Y0 - 0.04, LOFT_Z0 + 1.0, LOFT_Z0 + 2.2, 4)
    parts.append(box("loft_glass", (LOFT_X1 - LOFT_X0 - 0.9, 0.1, 0.85), ((LOFT_X0 + LOFT_X1) / 2, LOFT_Y0 - 0.04, LOFT_Z0 + 3.25), M["glass"]))
    parts.append(box("loft_glass_sill", (LOFT_X1 - LOFT_X0 - 0.6, 0.3, 0.16), ((LOFT_X0 + LOFT_X1) / 2, LOFT_Y0 - 0.06, LOFT_Z0 + 2.74), M["limestone"]))
    return parts


def build_horno(M):
    """Nivel 2: puertas del horno con arco de caliza y mejora de fachada de la nave."""
    parts = []
    # Dos puertas de fundición dentro de la boca del horno, con sus refuerzos.
    for x in (-3.72, -2.28):
        parts.append(box("furnace_door", (1.32, 0.12, 2.7), (x, -9.14, 1.35), M["metal_acero"]))
        for z in (0.6, 2.1):
            parts.append(box("furnace_rib", (1.2, 0.08, 0.16), (x, -9.06, z), M["metal_acero"]))
    # Arco de cinco dovelas de caliza sobre la boca: el remate del horno.
    for angle in (14, 52, 90, 128, 166):
        a = math.radians(angle)
        stone = box("arch_voussoir", (0.64, 0.45, 0.5), (CHIMNEY_X + ARCH_R * math.cos(a), KILN_FRONT + 0.1, ARCH_Z + ARCH_R * math.sin(a)), M["limestone"])
        stone.rotation_euler = (0, math.radians(angle - 90), 0)
        parts.append(stone)
    for x in (-4.6, -1.4):
        parts.append(box("arch_impost", (0.55, 0.45, 0.4), (x, KILN_FRONT + 0.1, 3.55), M["limestone"]))

    # Mejora de fachada: imposta de caliza sobre el rótulo y remates de las pilastras.
    parts.append(box("string_course", (17.4, 0.45, 0.35), (7.5, FRONT - 0.1, 13.95), M["limestone"]))
    for x in (-0.55, 15.55):
        parts.append(box("pilaster_cap", (1.05, 0.65, 0.35), (x, FRONT - 0.07, 20.825), M["limestone"]))
    return parts


def build_chimney_patio(M):
    """Nivel 3: la chimenea sube y el patio se llena de arcilla."""
    parts = []
    parts.append(box("chimney_stage2_base", (3.0, 3.0, 0.3), (CHIMNEY_X, CHIMNEY_Y, 25.62), M["limestone"]))
    parts.append(box("chimney_stage2", (2.3, 2.3, 5.5), (CHIMNEY_X, CHIMNEY_Y, 28.52), M["brick"]))
    for z in (27.2, 29.8):
        parts.append(box("chimney_stage2_band", (2.42, 2.42, 0.12), (CHIMNEY_X, CHIMNEY_Y, z), M["metal_acero"]))
    parts.append(box("chimney_stage2_accent", (2.45, 2.45, 0.12), (CHIMNEY_X, CHIMNEY_Y, 30.6), M["metal_ocre"]))
    parts.append(box("chimney_stage2_corbel", (2.6, 2.6, 0.3), (CHIMNEY_X, CHIMNEY_Y, 31.42), M["brick"]))
    parts.append(box("chimney_stage2_crown", (2.9, 2.9, 0.3), (CHIMNEY_X, CHIMNEY_Y, 31.72), M["limestone"]))
    parts.append(box("chimney_stage2_cap", (3.05, 3.05, 0.12), (CHIMNEY_X, CHIMNEY_Y, 31.93), M["limestone"]))

    # El patio: pilas de arcilla, artesa de caliza y remates del muro.
    for x, y, radius, depth in ((-8.0, -7.5, 0.78, 2.1), (-6.4, -7.9, 0.9, 1.75), (-6.25, -6.8, 0.62, 1.35)):
        parts.append(cone("clay_pile", radius, depth, (x, y, 0.16 + depth / 2), M["brick"], verts=7))
    parts.append(box("clay_trough", (1.5, 1.0, 0.6), (-8.05, -6.55, 0.46), M["limestone"]))
    for x0, x1 in ((PATIO_X0, -7.9), (-5.9, PATIO_X1)):
        parts.append(box("patio_coping", (x1 - x0 + 0.1, 0.4, 0.14), ((x0 + x1) / 2, FRONT + 0.15, 1.17), M["limestone"]))
    for x in (-8.0, -5.8):
        parts.append(box("patio_pier_cap", (0.35, 0.45, 0.12), (x, FRONT + 0.18, 1.56), M["limestone"]))
    return parts


def build_office(M):
    """Nivel 4: pabellón anexo de oficinas, retranqueado sobre la cubierta del horno."""
    parts = []
    width = OFFICE_X1 - OFFICE_X0
    depth = OFFICE_Y1 - OFFICE_Y0
    cx = (OFFICE_X0 + OFFICE_X1) / 2
    cy = (OFFICE_Y0 + OFFICE_Y1) / 2
    annex = box("office", (width, depth, OFFICE_H), (cx, cy, OFFICE_Z0 + OFFICE_H / 2), M["brick"])
    perforate(annex, [box("cut_office_glass", (5.9, 0.9, 1.5), (cx, OFFICE_Y0 + 0.4, OFFICE_Z0 + 2.9))])
    parts.append(annex)
    parts.append(box("office_glass", (5.7, 0.1, 1.4), (cx, OFFICE_Y0 + 0.78, OFFICE_Z0 + 2.9), M["glass"]))
    for x in (cx - 1.9, cx, cx + 1.9):
        parts.append(box("office_mullion", (0.14, 0.25, 1.5), (x, OFFICE_Y0 + 0.02, OFFICE_Z0 + 2.9), M["metal_acero"]))
    parts.append(box("office_sill", (6.3, 0.4, 0.2), (cx, OFFICE_Y0 - 0.02, OFFICE_Z0 + 2.05), M["limestone"]))
    parts.append(box("office_cornice", (width + 0.4, depth + 0.4, 0.35), (cx, cy, OFFICE_Z0 + OFFICE_H + 0.175), M["limestone"]))
    parts.append(box("office_roof", (width + 0.2, depth + 0.2, 0.22), (cx, cy, OFFICE_Z0 + OFFICE_H + 0.46), M["slate"]))
    return parts


def build_tower(M):
    """Nivel 5: torre de la chimenea hasta 39,8, con galería de acero y remate de cobre."""
    parts = []
    parts.append(box("chimney_tower_base", (3.0, 3.0, 0.25), (CHIMNEY_X, CHIMNEY_Y, 32.115), M["limestone"]))
    parts.append(box("chimney_tower_shaft", (2.9, 2.9, 5.0), (CHIMNEY_X, CHIMNEY_Y, 34.74), M["brick"]))
    parts.append(box("chimney_tower_band", (3.0, 3.0, 0.24), (CHIMNEY_X, CHIMNEY_Y, 36.2), M["limestone"]))
    parts.append(box("chimney_tower_corbel", (3.2, 3.2, 0.35), (CHIMNEY_X, CHIMNEY_Y, 37.315), M["brick"]))
    parts.append(box("chimney_tower_gallery", (3.7, 3.7, 0.2), (CHIMNEY_X, CHIMNEY_Y, 37.59), M["metal_acero"]))
    parts.append(box("chimney_tower_gallery_band", (3.76, 3.76, 0.1), (CHIMNEY_X, CHIMNEY_Y, 37.49), M["metal_oro"]))
    parts.append(cone("copper_cap", 2.35, 1.35, (CHIMNEY_X, CHIMNEY_Y, 38.365), M["metal_oro"], verts=4, rotation=(0, 0, math.radians(45))))
    parts.append(box("copper_finial", (0.16, 0.16, 0.8), (CHIMNEY_X, CHIMNEY_Y, 39.4), M["metal_oro"]))
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
        name = f"hormiga_{layer}_{rbx.lower()}{suffix}"
        # Un grupo de una sola pieza no se une: join con un único objeto avisa «No mesh data to join».
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
        "frente": round(min(ys), 2),
        "fondo_maximo": round(max(ys), 2),
        "x_minimo": round(min(xs), 2),
        "x_maximo": round(max(xs), 2),
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

    # Ficha de referencia (caja oscura 8 × 4 × 5) y figura de 6 junto al portalón del nivel 0.
    box("ficha_ref", (8.0, 4.0, 5.0), (-2.5 * SPACING, SLOT_SIDE, 2.5), M["dark"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-2.5 * SPACING + GATE_CX + 6.0, building_y - 10.9, 3.0), M["avatar"])
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
    builders = {1: build_toldo, 2: build_horno, 3: build_chimney_patio, 4: build_office, 5: build_tower}
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
    lod = lod_of(objects, "hormiga_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "hormiga_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "cuerpo": BODY_H,
        "altura_maxima": MAX_HEIGHT,
        "nivel0_maximo": LEVEL0_MAX,
        "nivel_0_tope": levels["0"]["limites"]["alto_maximo_sobre_suelo"],
        "nivel_5_tope": levels["5"]["limites"]["alto_maximo_sobre_suelo"],
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
    print("HORMIGA_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": {k: v["limites"]["alto_maximo_sobre_suelo"] for k, v in levels.items()}}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if levels["0"]["limites"]["alto_maximo_sobre_suelo"] > LEVEL0_MAX:
        raise RuntimeError(f"El nivel 0 llega a {levels['0']['limites']['alto_maximo_sobre_suelo']}: no debe pasar de {LEVEL0_MAX}")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] > MAX_HEIGHT:
        raise RuntimeError(f"El nivel 5 llega a {levels['5']['limites']['alto_maximo_sobre_suelo']}: no debe pasar de {MAX_HEIGHT}")
    for level in range(6):
        limits = levels[str(level)]["limites"]
        if limits["frente"] < -10.0:
            raise RuntimeError(f"El nivel {level} invade la franja del marcador: frente en {limits['frente']}")
        if max(abs(limits["x_minimo"]), abs(limits["x_maximo"])) > 18.0:
            raise RuntimeError(f"El nivel {level} se sale del solar a lo ancho: {limits['x_minimo']} a {limits['x_maximo']}")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "fabrica-de-ladrillos-la-hormiga.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["metal_acero"], "gold": M["metal_oro"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -190.0, 78.0), (0.0, 22.0, 10.0), 30), f"{RENDER_SUBDIR}/fabrica-de-ladrillos-la-hormiga-niveles.png")

    # Comparación: nivel 0 frente a los bloques de 13 y 24 y una figura de 6 delante de la fachada.
    hide_all()
    box("ground", (180, 60, 0.4), (0, -6, -0.2), M["pavement"])
    place(cumulative_objects[0], -40.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (40, 0, 12.0), M["block"])
    # La figura va delante de la fachada, al lado derecho del portalón y contra el ladrillo.
    box("avatar_ref", (1.6, 1.2, 6.0), (-40.0 + GATE_CX + 5.8, -9.9, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -150.0, 30.0), (0.0, 0.0, 9.0), 42), f"{RENDER_SUBDIR}/fabrica-de-ladrillos-la-hormiga-comparacion.png")
    print("HORMIGA_DONE")


if __name__ == "__main__":
    main()

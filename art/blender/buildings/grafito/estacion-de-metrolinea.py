"""Estación de Metrolínea: propiedad de la zona Grafito (Distrito Grafito), modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de taquillas de ladrillo y caliza de 17,5 de alto y cinco añadidos que se
suman: marquesina de acero y cristal sobre el andén, arcos y cristal de la entrada, torre del reloj, pabellón
de oficinas retranqueado y remate de cobre. El andén, las vías, la marquesina de entrada y el reloj ya están en
el cuerpo: el nivel 0 se lee como estación sin leer el rótulo. Sigue el método de barberia-morro.py: una malla
por material y color, LOD1 con decimado y los helpers de build_cine_lux.py.

Salidas, en art/blender/buildings/grafito/:
  estacion-de-metrolinea.blend                     escena de revisión (no se versiona)
  estacion-de-metrolinea/metro_<pieza>_<material>.fbx y metro_LOD1.fbx
  estacion-de-metrolinea/stats.json                triángulos por pieza y nivel, límites y materiales
Y en art/render/grafito/estacion-de-metrolinea/: estacion-de-metrolinea-niveles.png y -comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/grafito/estacion-de-metrolinea.py
"""

import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "estacion-de-metrolinea")
RENDER_SUBDIR = "grafito/estacion-de-metrolinea"
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

# Solar y cuerpo. El frente del cuerpo se retranquea 2 para que la marquesina de entrada vuele sin pasar de
# y = -10; delante queda un atrio de 2 de fondo.
WIDTH = 32.0
DEPTH = 18.0
FRONT = -DEPTH / 2  # línea del solar: -9
HALL_X0, HALL_X1 = -16.0, 4.0
HALL_FRONT, HALL_BACK = -7.0, 9.0
HALL_W = HALL_X1 - HALL_X0  # 20
HALL_D = HALL_BACK - HALL_FRONT  # 16
HALL_H = 17.5  # masa principal
HALL_CX = (HALL_X0 + HALL_X1) / 2  # -6
HALL_CY = (HALL_FRONT + HALL_BACK) / 2  # 1

# Portalón de 9 × 7,4: más alto que el avatar de 6. Puerta de cristal de tres hojas de 2,5 × 7.
PORTAL_W, PORTAL_H, PORTAL_CX = 9.0, 7.4, -6.0
PORTAL_RECESS = 1.0

# Ventanas altas a los lados del portalón. El añadido 2 les pone arco y más cristal.
WIN_W, WIN_Z0, WIN_Z1 = 2.6, 9.4, 14.2
WINDOW_CX = (-14.35, 2.25)

# Marquesina de entrada: vidrio inclinado de acero verde sobre el portalón, con dos postes al frente.
AWNING_CX, AWNING_W = -6.0, 14.0
AWNING_LOW_Z, AWNING_HIGH_Z = 8.2, 9.05
AWNING_FRONT, AWNING_BACK = -8.7, -7.0
AWNING_ANGLE = math.atan2(AWNING_HIGH_Z - AWNING_LOW_Z, AWNING_BACK - AWNING_FRONT)
AWNING_POST_X = 6.7

# Rótulo en placa sobre la marquesina, en el muro, y reloj de estación encima.
SIGN_W, SIGN_Z0, SIGN_Z1 = 9.8, 9.7, 12.8
SIGN_FRONT = -7.25
CLOCK_Z, CLOCK_R = 14.05, 1.0

# Andén y vías, dentro del nivel 0: son obra civil, no mejora.
PLATFORM_X0, PLATFORM_X1, PLATFORM_TOP = 4.0, 11.0, 1.0
PLATFORM_Y0, PLATFORM_Y1 = -9.0, 9.0
RAILS = (12.55, 15.35)
SLEEPERS = tuple(-8.4 + 2.4 * k for k in range(8))
TRACKBED_X0, TRACKBED_X1 = 11.0, 16.0

# Marquesina del andén (nivel 1): montera a un agua desde el muro del cuerpo hasta la fila de pilares.
CANOPY_X0, CANOPY_X1 = 3.9, 11.0
CANOPY_Y0, CANOPY_Y1 = -7.0, 9.0
CANOPY_HIGH_Z, CANOPY_LOW_Z = 11.4, 9.9
CANOPY_ANGLE = math.atan2(CANOPY_HIGH_Z - CANOPY_LOW_Z, CANOPY_X1 - CANOPY_X0)
COLUMN_X = 10.65
COLUMN_Y = (-6.6, -2.2, 2.2, 6.6)

# Torre del reloj (nivel 3) y remate de cobre (nivel 5).
TOWER_X, TOWER_Y = -11.0, 3.5
TOWER_Z0, TOWER_Z1 = 17.5, 27.7
LANTERN_Z0, LANTERN_Z1 = 27.7, 33.55
SPIRE_TOP = 38.9
ANNEX_X, ANNEX_Y, ANNEX_TOP = 0.6, -0.5, 23.65

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
BODY_LEVEL0_MAX = 22.5
MAX_HEIGHT = 40.0

# Material de Roblox, sufijo de color y RGB de cada material de Blender. El metal lleva cinco acabados
# (acero, verde oscuro, verde claro, grafito y cobre), así que todos van con sufijo de color.
RBX = {
    "brick": ("Brick", "", "B0664A"),
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "wood": ("Wood", "", "6B4A2E"),
    "metal_acero": ("Metal", "_acero", "A8AEB4"),
    "metal_verde_oscuro": ("Metal", "_verde_oscuro", "31503C"),
    "metal_verde_claro": ("Metal", "_verde_claro", "A8BD96"),
    "metal_grafito": ("Metal", "_grafito", "64748B"),
    "metal_cobre": ("Metal", "_cobre", "C97B3A"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "wood": flat("wood", "6B4A2E", 0.75),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.25, 0.9),
        "metal_verde_oscuro": flat("metal_verde_oscuro", "31503C", 0.35, 0.5),
        "metal_verde_claro": flat("metal_verde_claro", "A8BD96", 0.4, 0.4),
        "metal_grafito": flat("metal_grafito", "64748B", 0.35, 0.6),
        "metal_cobre": flat("metal_cobre", "C97B3A", 0.3, 0.9),
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


def cylinder(name, radius, depth, location, mat, verts=12, caps=True, rotation=(0.0, 0.0, 0.0)):
    """Cilindro. Para el reloj va tumbado: eje en Y, cara al frente."""
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
    if mat is not None:
        obj.data.materials.append(mat)
    return obj


def cone(name, radius, depth, location, mat, verts=4, rotation=(0.0, 0.0, 0.0)):
    """Pirámide de base cuadrada, para el remate de cobre."""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def clock(parts, x, y, z, radius, ring, face, hand, depth=0.34):
    """Reloj de estación de cara al frente (-Y): anillo, esfera clara y agujas."""
    parts.append(cylinder("metro_clock_ring", radius, depth, (x, y, z), ring, 12, True, (math.pi / 2, 0, 0)))
    face_y = y - depth / 2 - 0.05
    parts.append(cylinder("metro_clock_face", radius * 0.82, 0.1, (x, face_y, z), face, 12, True, (math.pi / 2, 0, 0)))
    hand_y = face_y - 0.06
    parts.append(box("metro_clock_hour", (0.09, 0.06, radius * 0.5), (x, hand_y, z + radius * 0.25), hand))
    parts.append(box("metro_clock_minute", (radius * 0.62, 0.06, 0.08), (x + radius * 0.31, hand_y, z), hand))


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
    """Nivel 0: taquillas de ladrillo con portalón, marquesina de entrada con reloj, andén y vías."""
    parts = []

    # Volumen de ladrillo con huecos de verdad: portalón y dos ventanas altas, perforados.
    wall = box("metro_wall", (HALL_W, HALL_D, HALL_H), (HALL_CX, HALL_CY, HALL_H / 2), M["brick"])
    cuts = [box("cut_portal", (PORTAL_W, 2.2, PORTAL_H + 0.5), (PORTAL_CX, -7.1, (PORTAL_H - 0.5) / 2))]
    for xc in WINDOW_CX:
        cuts.append(box("cut_win", (WIN_W + 0.1, 1.4, WIN_Z1 - WIN_Z0 + 0.1), (xc, -7.2, (WIN_Z0 + WIN_Z1) / 2)))
    perforate(wall, cuts)
    parts.append(wall)

    # Zócalo de caliza, abierto en el portalón, y banda verde oscura pintada sobre él.
    plinth = box("metro_plinth", (HALL_W + 0.5, HALL_D + 0.5, 0.9), (HALL_CX, HALL_CY, 0.45), M["limestone"])
    perforate(plinth, [box("cut_portal_plinth", (PORTAL_W, 2.4, 1.4), (PORTAL_CX, -7.15, 0.2))])
    parts.append(plinth)
    parts.append(box("metro_band_low", (HALL_W + 0.2, HALL_D + 0.2, 0.22), (HALL_CX, HALL_CY, 1.03), M["metal_verde_oscuro"]))
    parts.append(box("metro_band_high", (HALL_W + 0.2, HALL_D + 0.2, 0.2), (HALL_CX, HALL_CY, 16.9), M["metal_verde_claro"]))

    # Cornisa, junta y cubierta de pizarra por encima del pretil de caliza.
    parts.append(box("metro_cornice", (HALL_W + 0.8, HALL_D + 0.8, 0.6), (HALL_CX, HALL_CY, 17.8), M["limestone"]))
    parts.append(box("metro_string", (HALL_W + 0.3, HALL_D + 0.3, 0.32), (HALL_CX, HALL_CY, 15.4), M["limestone"]))
    parts.append(box("metro_roof", (HALL_W - 0.4, HALL_D - 0.4, 0.25), (HALL_CX, HALL_CY, 18.225), M["slate"]))

    # Portalón: jambas, dintel y revestimiento interior de caliza; tres hojas de cristal con marco verde.
    for sx in (-1, 1):
        parts.append(box("metro_jamb", (0.7, 0.5, 8.3), (PORTAL_CX + sx * 4.85, -7.1, 4.15), M["limestone"]))
        parts.append(box("metro_reveal_jamb", (0.25, 1.0, PORTAL_H), (PORTAL_CX + sx * 4.375, -6.5, PORTAL_H / 2), M["limestone"]))
        parts.append(box("metro_door_jamb", (0.18, 0.26, 7.05), (PORTAL_CX + sx * 4.09, -6.6, 3.675), M["metal_verde_oscuro"]))
    parts.append(box("metro_lintel", (PORTAL_W + 1.9, 0.5, 0.9), (PORTAL_CX, -7.1, 7.85), M["limestone"]))
    parts.append(box("metro_reveal_head", (PORTAL_W, 1.0, 0.22), (PORTAL_CX, -6.5, PORTAL_H - 0.11), M["limestone"]))
    parts.append(box("metro_threshold", (PORTAL_W + 0.4, 1.3, 0.18), (PORTAL_CX, -7.35, 0.09), M["limestone"]))
    for xc in (-8.75, -6.0, -3.25):
        parts.append(box("metro_door", (2.5, 0.12, 7.0), (xc, -6.6, 3.65), M["glass"]))

    # Ventanas altas del cuerpo: hueco, revestimiento, alféizar, vidrio y barra verde.
    for xc in WINDOW_CX:
        parts.append(box("metro_win_sill", (WIN_W + 0.5, 0.5, 0.28), (xc, -7.15, WIN_Z0 - 0.1), M["limestone"]))
        for sx in (-1, 1):
            parts.append(box("metro_win_reveal", (0.16, 0.5, WIN_Z1 - WIN_Z0), (xc + sx * 1.33, -6.75, (WIN_Z0 + WIN_Z1) / 2), M["limestone"]))
        parts.append(box("metro_win_head", (WIN_W + 0.36, 0.5, 0.18), (xc, -6.75, WIN_Z1 + 0.06), M["limestone"]))
        parts.append(box("metro_win_glass", (WIN_W, 0.1, WIN_Z1 - WIN_Z0), (xc, -6.62, (WIN_Z0 + WIN_Z1) / 2), M["glass"]))
        parts.append(box("metro_win_bar", (0.1, 0.16, WIN_Z1 - WIN_Z0), (xc, -6.55, (WIN_Z0 + WIN_Z1) / 2), M["metal_verde_oscuro"]))

    # Atrio de caliza delante del cuerpo.
    parts.append(box("metro_forecourt", (HALL_W, 2.0, 0.08), (HALL_CX, -8.0, 0.04), M["limestone"]))

    # Marquesina de entrada inclinada: vidrio sobre bastidor verde y dos postes al frente.
    slope = math.hypot(AWNING_BACK - AWNING_FRONT, AWNING_HIGH_Z - AWNING_LOW_Z)
    mid_y = (AWNING_FRONT + AWNING_BACK) / 2
    mid_z = (AWNING_LOW_Z + AWNING_HIGH_Z) / 2
    glass = box("metro_awning_glass", (AWNING_W, slope, 0.09), (AWNING_CX, mid_y, mid_z), M["glass"])
    glass.rotation_euler = (AWNING_ANGLE, 0.0, 0.0)
    parts.append(glass)
    parts.append(box("metro_awning_edge", (AWNING_W + 0.2, 0.3, 0.34), (AWNING_CX, -8.55, 8.27), M["metal_verde_oscuro"]))
    for sx in (-1, 1):
        side = box("metro_awning_side", (0.26, slope, 0.3), (AWNING_CX + sx * 6.87, mid_y, mid_z), M["metal_verde_oscuro"])
        side.rotation_euler = (AWNING_ANGLE, 0.0, 0.0)
        parts.append(side)
        parts.append(box("metro_awning_post", (0.34, 0.34, AWNING_LOW_Z - 0.08), (AWNING_CX + sx * AWNING_POST_X, -8.55, (AWNING_LOW_Z + 0.08) / 2), M["metal_verde_oscuro"]))
    for xc in (-9.4, -2.6):
        rib = box("metro_awning_rib", (0.16, slope, 0.14), (xc, mid_y, mid_z), M["metal_verde_oscuro"])
        rib.rotation_euler = (AWNING_ANGLE, 0.0, 0.0)
        parts.append(rib)

    # Placa del rótulo en el muro, por encima de la marquesina, con marco de caliza y letras de caliza.
    parts.append(box("metro_sign_plate", (SIGN_W, 0.4, SIGN_Z1 - SIGN_Z0), (AWNING_CX, -7.05, (SIGN_Z0 + SIGN_Z1) / 2), M["metal_verde_oscuro"]))
    parts.append(box("metro_sign_top", (SIGN_W + 0.7, 0.5, 0.26), (AWNING_CX, -7.05, SIGN_Z1 + 0.13), M["limestone"]))
    parts.append(box("metro_sign_bottom", (SIGN_W + 0.7, 0.5, 0.26), (AWNING_CX, -7.05, SIGN_Z0 - 0.13), M["limestone"]))
    for sx in (-1, 1):
        parts.append(box("metro_sign_side", (0.25, 0.5, SIGN_Z1 - SIGN_Z0), (AWNING_CX + sx * (SIGN_W / 2 + 0.125), -7.05, (SIGN_Z0 + SIGN_Z1) / 2), M["limestone"]))
    line_one = fit_width(letters("ESTACIÓN DE", 1.25, (AWNING_CX, -7.38, 12.0), M["limestone"], depth=0.16), SIGN_W - 0.4)
    line_two = fit_width(letters("METROLÍNEA", 1.25, (AWNING_CX, -7.38, 10.5), M["limestone"], depth=0.16), SIGN_W - 0.4)
    parts.extend([line_one, line_two])

    # Reloj de estación sobre el rótulo, en el muro.
    clock(parts, AWNING_CX, -7.0, CLOCK_Z, CLOCK_R, M["metal_verde_oscuro"], M["limestone"], M["metal_verde_oscuro"])

    # Andén, borde de seguridad, vías sobre lecho de pizarra, traviesas y dos farolas de andén.
    parts.append(box("metro_platform", (PLATFORM_X1 - PLATFORM_X0, PLATFORM_Y1 - PLATFORM_Y0, PLATFORM_TOP - 0.1), (7.5, 0.0, (PLATFORM_TOP - 0.1) / 2), M["limestone"]))
    parts.append(box("metro_platform_top", (PLATFORM_X1 - PLATFORM_X0, PLATFORM_Y1 - PLATFORM_Y0, 0.1), (7.5, 0.0, PLATFORM_TOP - 0.05), M["slate"]))
    parts.append(box("metro_platform_edge", (0.45, PLATFORM_Y1 - PLATFORM_Y0, 0.12), (10.775, 0.0, PLATFORM_TOP + 0.06), M["metal_grafito"]))
    parts.append(box("metro_trackbed", (TRACKBED_X1 - TRACKBED_X0, 18.0, 0.1), (13.5, 0.0, 0.05), M["slate"]))
    for x in RAILS:
        parts.append(box("metro_rail", (0.18, 18.0, 0.18), (x, 0.0, 0.31), M["metal_acero"]))
    for y in SLEEPERS:
        parts.append(box("metro_sleeper", (4.0, 0.4, 0.12), (14.0, y, 0.16), M["metal_grafito"]))
    for x, y in ((8.7, -4.8), (8.7, 4.6)):
        parts.append(box("metro_platform_lamp", (0.22, 0.22, 5.2), (x, y, PLATFORM_TOP + 2.6), M["metal_verde_oscuro"]))
        parts.append(box("metro_lamp_head", (0.62, 0.62, 0.28), (x, y, PLATFORM_TOP + 5.34), M["metal_verde_claro"]))

    # Cubierta: lucernario y dos remates de ventilación, fuera de donde suben las torres.
    parts.append(box("metro_skylight_curb", (5.2, 3.6, 0.5), (-5.6, 6.0, 18.6), M["slate"]))
    parts.append(box("metro_skylight", (4.4, 2.8, 0.12), (-5.6, 6.0, 18.91), M["glass"]))
    parts.append(box("metro_vent_left", (1.6, 1.6, 1.0), (-14.5, -1.5, 18.85), M["slate"]))
    parts.append(box("metro_vent_right", (1.6, 1.6, 1.0), (1.5, -5.5, 18.85), M["slate"]))
    return parts


def build_canopy(M):
    """Nivel 1: marquesina de acero y cristal sobre el andén, con sus pilares y bancos."""
    parts = []
    length = math.hypot(CANOPY_X1 - CANOPY_X0, CANOPY_HIGH_Z - CANOPY_LOW_Z) + 0.4
    mid_x = (CANOPY_X0 + CANOPY_X1) / 2
    mid_z = (CANOPY_HIGH_Z + CANOPY_LOW_Z) / 2
    span = CANOPY_Y1 - CANOPY_Y0

    glass = box("metro_canopy_glass", (length, span + 0.2, 0.09), (mid_x, (CANOPY_Y0 + CANOPY_Y1) / 2, mid_z + 0.02), M["glass"])
    glass.rotation_euler = (0.0, CANOPY_ANGLE, 0.0)
    parts.append(glass)
    for x in (5.3, 7.45, 9.6):
        top = mid_z + 0.12 + (mid_x - x) * math.tan(CANOPY_ANGLE)
        parts.append(box("metro_canopy_purlin", (0.14, span + 0.2, 0.1), (x, (CANOPY_Y0 + CANOPY_Y1) / 2, top), M["metal_verde_oscuro"]))
    parts.append(box("metro_canopy_wall_beam", (0.5, span + 0.2, 0.4), (CANOPY_X0 + 0.25, 1.0, CANOPY_HIGH_Z - 0.05), M["metal_verde_oscuro"]))
    parts.append(box("metro_canopy_eave", (0.3, span + 0.2, 0.5), (CANOPY_X1 - 0.05, 1.0, CANOPY_LOW_Z - 0.05), M["metal_verde_oscuro"]))
    for y in COLUMN_Y:
        rafter = box("metro_canopy_rafter", (length - 0.1, 0.22, 0.26), (mid_x, y, mid_z - 0.12), M["metal_verde_oscuro"])
        rafter.rotation_euler = (0.0, CANOPY_ANGLE, 0.0)
        parts.append(rafter)
        parts.append(box("metro_canopy_column", (0.34, 0.34, CANOPY_LOW_Z - PLATFORM_TOP), (COLUMN_X, y, (CANOPY_LOW_Z + PLATFORM_TOP) / 2), M["metal_verde_oscuro"]))
    for y in (CANOPY_Y0 + 0.15, CANOPY_Y1 - 0.15):
        parts.append(box("metro_canopy_tie", (CANOPY_X1 - CANOPY_X0, 0.3, 0.3), (mid_x, y, CANOPY_LOW_Z), M["metal_verde_oscuro"]))
    for x, y in ((8.6, -4.6), (8.6, 3.4)):
        parts.append(box("metro_bench_seat", (2.6, 0.6, 0.16), (x, y, PLATFORM_TOP + 0.55), M["wood"]))
        parts.append(box("metro_bench_back", (2.6, 0.12, 0.5), (x, y + 0.24, PLATFORM_TOP + 0.85), M["wood"]))
    return parts


def build_arches(M):
    """Nivel 2: arcos de caliza y más cristal en la entrada, sobre las ventanas del cuerpo."""
    parts = []
    for xc in WINDOW_CX:
        plate = box("metro_arch_plate", (3.2, 0.5, 1.7), (xc, -7.1, WIN_Z1 + 0.75), M["limestone"])
        cutter = cylinder("cut_arch", 1.0, 1.4, (xc, -7.1, WIN_Z1 - 0.1), None, 16, True, (math.pi / 2, 0, 0))
        perforate(plate, [cutter])
        parts.append(plate)
        parts.append(box("metro_arch_glass", (2.4, 0.08, 1.1), (xc, -7.03, WIN_Z1 + 0.45), M["glass"]))
        for sx in (-1, 1):
            parts.append(box("metro_arch_mullion", (0.1, 0.16, WIN_Z1 - WIN_Z0 - 0.3), (xc + sx * 0.65, -6.55, (WIN_Z0 + WIN_Z1) / 2), M["metal_verde_oscuro"]))
        parts.append(box("metro_arch_transom", (2.5, 0.16, 0.1), (xc, -6.55, WIN_Z1 - 0.5), M["metal_verde_oscuro"]))
    return parts


def build_tower(M):
    """Nivel 3: torre del reloj de caliza sobre el ala izquierda, con bandas verdes."""
    parts = []
    parts.append(box("metro_tower_base", (5.6, 5.6, 0.7), (TOWER_X, TOWER_Y, TOWER_Z0 + 0.35), M["limestone"]))
    parts.append(box("metro_tower_shaft", (4.8, 4.8, 5.2), (TOWER_X, TOWER_Y, 20.8), M["limestone"]))
    parts.append(box("metro_tower_band", (5.15, 5.15, 0.35), (TOWER_X, TOWER_Y, 23.575), M["metal_verde_oscuro"]))
    parts.append(box("metro_tower_stage", (4.6, 4.6, 3.2), (TOWER_X, TOWER_Y, 25.35), M["limestone"]))
    clock(parts, TOWER_X, TOWER_Y - 2.45, 25.25, 1.15, M["metal_verde_oscuro"], M["limestone"], M["metal_verde_oscuro"])
    parts.append(box("metro_tower_cornice", (5.4, 5.4, 0.45), (TOWER_X, TOWER_Y, 27.175), M["limestone"]))
    parts.append(box("metro_tower_cap", (4.7, 4.7, 0.3), (TOWER_X, TOWER_Y, 27.55), M["metal_verde_oscuro"]))
    return parts


def build_annex(M):
    """Nivel 4: pabellón de oficinas retranqueado sobre la cubierta, de ladrillo con banda de caliza."""
    parts = []
    parts.append(box("metro_annex", (6.6, 7.0, 5.6), (ANNEX_X, ANNEX_Y, 20.3), M["brick"]))
    parts.append(box("metro_annex_band", (6.9, 7.3, 0.3), (ANNEX_X, ANNEX_Y, 23.25), M["limestone"]))
    parts.append(box("metro_annex_roof", (6.4, 6.8, 0.25), (ANNEX_X, ANNEX_Y, 23.525), M["slate"]))
    parts.append(box("metro_annex_glass", (5.2, 0.12, 1.4), (ANNEX_X, ANNEX_Y - 3.56, 21.4), M["glass"]))
    parts.append(box("metro_annex_sill", (5.6, 0.3, 0.22), (ANNEX_X, ANNEX_Y - 3.6, 20.6), M["limestone"]))
    for xc in (-0.4, 1.6):
        parts.append(box("metro_annex_mullion", (0.12, 0.2, 1.5), (xc, ANNEX_Y - 3.56, 21.4), M["metal_verde_oscuro"]))
    return parts


def build_crown(M):
    """Nivel 5: remate de cobre de la torre del reloj, hasta 38,9."""
    parts = []
    parts.append(box("metro_lantern", (3.6, 3.6, LANTERN_Z1 - LANTERN_Z0), (TOWER_X, TOWER_Y, (LANTERN_Z0 + LANTERN_Z1) / 2), M["limestone"]))
    for x, y, w, d in (
        (TOWER_X, TOWER_Y - 1.83, 2.4, 0.14),
        (TOWER_X, TOWER_Y + 1.83, 2.4, 0.14),
        (TOWER_X - 1.83, TOWER_Y, 0.14, 2.4),
        (TOWER_X + 1.83, TOWER_Y, 0.14, 2.4),
    ):
        parts.append(box("metro_louvre", (w, d, 3.2), (x, y, 30.4), M["metal_verde_claro"]))
    parts.append(box("metro_lantern_cornice", (4.2, 4.2, 0.4), (TOWER_X, TOWER_Y, 33.1), M["limestone"]))
    parts.append(box("metro_lantern_band", (3.9, 3.9, 0.25), (TOWER_X, TOWER_Y, 33.425), M["metal_verde_oscuro"]))
    parts.append(cone("metro_spire", 2.55, 4.0, (TOWER_X, TOWER_Y, 35.55), M["metal_cobre"], 4, (0.0, 0.0, math.radians(45))))
    parts.append(cone("metro_finial", 0.32, 0.6, (TOWER_X, TOWER_Y, 37.85), M["metal_cobre"], 4, (0.0, 0.0, math.radians(45))))
    parts.append(cylinder("metro_finial_rod", 0.12, 1.3, (TOWER_X, TOWER_Y, 38.25), M["metal_cobre"], 8, True))
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
        name = f"metro_{layer}_{rbx.lower()}{suffix}"
        if len(members) == 1:
            mesh = members[0]
            mesh.name = name
            mesh.data.name = name
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
        "frente": round(min(ys), 2),
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

    # Ficha de referencia (caja oscura 8 × 4 × 5, sin taxi) y avatar de 6 de alto para la escala.
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

    # Nivel 0: cuerpo con andén y vías. Niveles 1 a 5: añadidos que se suman sin sustituir nada.
    group(0, build_body(M), pieces)
    builders = {1: build_canopy, 2: build_arches, 3: build_tower, 4: build_annex, 5: build_crown}
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
    lod = lod_of(objects, "metro_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "metro_LOD1.fbx")

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
    print("METRO_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if levels["0"]["limites"]["alto_maximo_sobre_suelo"] > BODY_LEVEL0_MAX:
        raise RuntimeError(f"El nivel 0 llega a {levels['0']['limites']['alto_maximo_sobre_suelo']}: más de {BODY_LEVEL0_MAX}")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] > MAX_HEIGHT:
        raise RuntimeError(f"El nivel 5 llega a {levels['5']['limites']['alto_maximo_sobre_suelo']}: más de {MAX_HEIGHT}")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "estacion-de-metrolinea.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["slate"], "gold": M["metal_cobre"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -178.0, 70.0), (0.0, 22.0, 12.0), 31), f"{RENDER_SUBDIR}/estacion-de-metrolinea-niveles.png")

    # Comparación: nivel 0 frente a un bloque de Bodega (13) y otro de Cine Lux (24), con una figura de 6
    # delante de la fachada y al lado de la puerta, para revisar que el portalón la supera.
    hide_all()
    box("ground", (2000, 2000, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -31.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (2.0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (35.0, 0, 12.0), M["block"])
    box("figura_6", (1.6, 1.2, 6.0), (-31.5, -9.0, 3.0), M["zone"])
    lights_and_world()
    render(scene, camera("comparacion", (2.0, -120.0, 26.0), (2.0, 0.0, 9.5), 40), f"{RENDER_SUBDIR}/estacion-de-metrolinea-comparacion.png")
    print("METRO_DONE")


if __name__ == "__main__":
    main()

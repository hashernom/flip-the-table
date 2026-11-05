"""Fundición Vulcano: propiedad del Distrito Grafito (zona 11), modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de 20: la nave de horno de ladrillo. Cinco añadidos que se suman: pórtico
de carga, silos de mineral, chimenea y horno, pabellón de oficinas retranqueado y torre de la chimenea con
remate de cobre, hasta 40. El nivel 0 ya se lee como fundición: chimenea de ladrillo aparte de la nave, dos
silos de chapa, portalón de 9 × 7,4, cercha de acero y rótulo en letras 3D. Nada de hileras de ventanitas: el
único hueco alto es un ventanal de nave, y el resto del cristal va en la linterna de cubierta.

Sigue el método de barberia-morro.py y build_cine_lux.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/grafito/:
  fundicion-vulcano.blend               escena de revisión (no se versiona)
  fundicion-vulcano/vulcano_<pieza>_<material>.fbx y vulcano_LOD1.fbx
  fundicion-vulcano/stats.json          triángulos por pieza y nivel, límites y materiales
Y en art/render/grafito/fundicion-vulcano/: fundicion-vulcano-niveles.png y fundicion-vulcano-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/grafito/fundicion-vulcano.py
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
OUT = os.path.join(HERE, "fundicion-vulcano")
RENDER_SUBDIR = "grafito/fundicion-vulcano"
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
FRONT = -8.6  # cara de la nave: deja 1,4 de vuelo al pórtico, que llega justo a -10
BACK = 8.6
BODY_H = 20.0  # masa principal: la nave de horno
NAVE_X0, NAVE_X1 = -15.5, 1.9
NAVE_CX = (NAVE_X0 + NAVE_X1) / 2  # -6,8
NAVE_D = BACK - FRONT  # 17,2

PORTAL_W, PORTAL_H = 9.0, 7.4  # portalón: mucho más alto que el avatar de 6
PORTAL_CX = -8.4
DOOR_W, DOOR_H = 2.6, 6.9  # puerta de personas, también por encima del avatar
DOOR_CX = -0.4

SIGN_Z = 13.0  # placa por encima de la puerta y del toldo (el toldo sube a 9,8)
SIGN_W = 13.8
WINDOW_W, WINDOW_Z0, WINDOW_Z1 = 6.0, 15.4, 18.6  # un ventanal de nave, no una hilera

CHIMNEY_CX, CHIMNEY_CY = 6.7, 5.0  # exenta en el patio: se ve la chimenea entera
CHIMNEY_BASE = 3.2
CHIMNEY_TOP = 24.35  # el nivel 0 completo no pasa de 25

SILO_R = 2.3
SILO_A = (9.9, -2.2)
SILO_B = (14.6, -2.2)
SILO_H = 12.0
SILO_CONE = 1.3
SILO_C = (10.9, 4.8)
SILO_D = (15.2, 4.8)
SILO_C_R = 2.1
SILO_C_H = 16.4
SILO_C_CONE = 1.7

CUPOLA = (5.6, -2.6)  # horno de cubilote, delante de la chimenea
CUPOLA_R = 1.7

OFFICE_X0, OFFICE_X1 = -14.0, -3.4
OFFICE_Y0, OFFICE_Y1 = -1.6, 7.4
OFFICE_Z0 = 20.25
OFFICE_TOP = 27.25  # cornisa del pabellón de oficinas

MAX_HEIGHT = 40.0
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
    "metal": ("Metal", "", "A8AEB4"),
    "metal_oro": ("Metal", "_oro", "C9A227"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "metal": flat("metal", "A8AEB4", 0.35, 0.85),
        "metal_oro": flat("metal_oro", "C9A227", 0.3, 0.9),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "64748B", 0.8),  # grafito de la zona, solo pintura de la casilla
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "6E747C", 0.8),
        "figure": flat("figure", "333A44", 0.8),
    }


def cylinder(name, radius, depth, location, mat, verts, caps):
    """Cilindro vertical. Sin tapas en los anillos: van pegados al silo y no se ven por dentro."""
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


def cone(name, radius, depth, location, mat, verts=14):
    """Cono de cubierta de silo o remate de la chimenea."""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def beam(name, a, b, thick, mat):
    """Barra cuadrada entre dos puntos: montante, larguero o diagonal de una cercha."""
    a, b = Vector(a), Vector(b)
    d = b - a
    obj = box(name, (thick, d.length, thick), tuple((a + b) / 2), mat)
    obj.rotation_euler = Vector((0.0, 1.0, 0.0)).rotation_difference(d.normalized()).to_euler()
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


def merge(members, name):
    """Une varias piezas en una malla. Con una sola pieza no se llama a join: avisaría «No mesh data to join»."""
    if len(members) == 1:
        obj = members[0]
        obj.name = name
        select_only(obj)
        bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        return obj
    return join(members, name)


def silo(parts, M, x, y, radius, height, cone_h, hoops, ladder=False):
    """Silo de mineral completo: zócalo de caliza, tambor de chapa, anillo, cono de pizarra y anillos."""
    parts.append(cylinder("silo_base", radius + 0.15, 0.45, (x, y, 0.225), M["limestone"], 14, True))
    parts.append(cylinder("silo_drum", radius, height - 0.4, (x, y, 0.4 + (height - 0.4) / 2), M["metal"], 14, True))
    parts.append(cylinder("silo_ring", radius + 0.12, 0.3, (x, y, height - 0.12), M["metal"], 12, False))
    parts.append(cone("silo_roof", radius + 0.15, cone_h, (x, y, height + cone_h / 2 - 0.05), M["slate"], 14))
    for z in hoops:
        parts.append(cylinder("silo_hoop", radius + 0.08, 0.16, (x, y, z), M["metal"], 12, False))
    if ladder:
        outer = radius + 0.08
        for dy in (-0.25, 0.25):
            parts.append(box("ladder_rail", (0.1, 0.1, height - 1.2), (x + outer + 0.06, y + dy, (height - 1.2) / 2 + 0.6), M["metal"]))
        for z in (2.6, 4.8, 7.0, 9.2):
            parts.append(box("ladder_rung", (0.1, 0.6, 0.1), (x + outer + 0.02, y, z), M["metal"]))


def build_body(M):
    """Nivel 0: nave de horno, portalón, ventanal, rótulo, chimenea de ladrillo exenta y dos silos."""
    parts = []

    # Huecos de verdad: portalón, puerta de personas y ventanal de nave.
    portal_cut = box("portal_cut", (PORTAL_W, 2.5, PORTAL_H + 0.5), (PORTAL_CX, FRONT + 0.75, (PORTAL_H - 0.5) / 2))
    door_cut = box("door_cut", (DOOR_W, 1.6, DOOR_H + 0.5), (DOOR_CX, FRONT + 0.4, (DOOR_H - 0.5) / 2))
    window_cut = box("window_cut", (WINDOW_W, 1.2, WINDOW_Z1 - WINDOW_Z0), (PORTAL_CX, FRONT + 0.2, (WINDOW_Z0 + WINDOW_Z1) / 2))
    nave = box("nave", (NAVE_X1 - NAVE_X0, NAVE_D, BODY_H), (NAVE_CX, 0.0, BODY_H / 2), M["brick"])
    perforate(nave, [portal_cut, door_cut, window_cut])
    parts.append(nave)

    # Zócalo de caliza, abierto en el portalón y en la puerta.
    plinth = box("plinth", (NAVE_X1 - NAVE_X0 + 0.4, NAVE_D + 0.4, 0.9), (NAVE_CX, 0.0, 0.45), M["limestone"])
    perforate(
        plinth,
        [
            box("plinth_portal", (PORTAL_W, 2.5, 1.6), (PORTAL_CX, FRONT + 0.75, 0.3)),
            box("plinth_door", (DOOR_W, 1.6, 1.6), (DOOR_CX, FRONT + 0.4, 0.3)),
        ],
    )
    parts.append(plinth)
    parts.append(box("cornice", (NAVE_X1 - NAVE_X0 + 0.6, NAVE_D + 0.5, 0.6), (NAVE_CX, 0.0, 19.65), M["limestone"]))

    # Cubierta de pizarra y linterna con banda de cristal corrida sobre la nave.
    parts.append(box("roof", (NAVE_X1 - NAVE_X0 - 0.4, NAVE_D - 0.4, 0.3), (NAVE_CX, 0.0, 20.1), M["slate"]))
    m_y0, m_y1, m_w = -6.0, 7.2, 3.8
    m_cx, m_cy = -0.4, (m_y0 + m_y1) / 2
    parts.append(box("monitor_curb", (m_w, m_y1 - m_y0, 0.5), (m_cx, m_cy, 20.5), M["brick"]))
    for side in (-1, 1):
        parts.append(box("monitor_glass", (0.12, m_y1 - m_y0 - 0.5, 1.15), (m_cx + side * (m_w / 2 - 0.06), m_cy, 21.33), M["glass"]))
    # Testeros de ladrillo en los dos extremos: la linterna queda cerrada y no se ve por dentro.
    for y in (m_y0 + 0.125, m_y1 - 0.125):
        parts.append(box("monitor_end", (m_w, 0.25, 1.15), (m_cx, y, 21.33), M["brick"]))
    for y in (-4.6, 5.8):
        for side in (-1, 1):
            parts.append(box("monitor_rib", (0.18, 0.34, 1.3), (m_cx + side * (m_w / 2 + 0.02), y, 21.35), M["metal"]))
    parts.append(box("monitor_cap", (m_w + 0.5, m_y1 - m_y0 + 0.5, 0.3), (m_cx, m_cy, 22.05), M["slate"]))

    # Chimenea de ladrillo exenta en el patio: el rasgo de la casa. A nivel 0 llega a 24,35.
    parts.append(box("chimney_plinth", (CHIMNEY_BASE + 0.4, CHIMNEY_BASE + 0.4, 1.4), (CHIMNEY_CX, CHIMNEY_CY, 0.7), M["brick"]))
    parts.append(box("chimney_shaft", (CHIMNEY_BASE, CHIMNEY_BASE, 11.2), (CHIMNEY_CX, CHIMNEY_CY, 7.0), M["brick"]))
    parts.append(box("chimney_ring1", (CHIMNEY_BASE + 0.35, CHIMNEY_BASE + 0.35, 0.5), (CHIMNEY_CX, CHIMNEY_CY, 12.65), M["brick"]))
    parts.append(box("chimney_mid", (CHIMNEY_BASE - 0.4, CHIMNEY_BASE - 0.4, 10.5), (CHIMNEY_CX, CHIMNEY_CY, 18.15), M["brick"]))
    parts.append(box("chimney_ring2", (CHIMNEY_BASE - 0.05, CHIMNEY_BASE - 0.05, 0.45), (CHIMNEY_CX, CHIMNEY_CY, 23.525), M["brick"]))
    parts.append(box("chimney_band", (CHIMNEY_BASE - 0.25, CHIMNEY_BASE - 0.25, 0.3), (CHIMNEY_CX, CHIMNEY_CY, 23.9), M["limestone"]))
    parts.append(box("chimney_mouth", (CHIMNEY_BASE - 0.5, CHIMNEY_BASE - 0.5, 0.3), (CHIMNEY_CX, CHIMNEY_CY, 24.2), M["slate"]))

    # Los dos silos del cuerpo: sin ellos el nivel 0 no se lee como fundición.
    silo(parts, M, SILO_A[0], SILO_A[1], SILO_R, SILO_H, SILO_CONE, (8.4,))
    silo(parts, M, SILO_B[0], SILO_B[1], SILO_R, SILO_H, SILO_CONE, (8.4,), ladder=True)

    # Portalón: bastidor de acero, persiana enrollable y cercha de acero vista sobre el dintel.
    for side in (-1, 1):
        parts.append(box("portal_jamb", (0.45, 0.6, PORTAL_H + 0.5), (PORTAL_CX + side * (PORTAL_W / 2 + 0.22), FRONT + 0.15, (PORTAL_H + 0.5) / 2), M["metal"]))
    parts.append(box("portal_lintel", (PORTAL_W + 0.9, 0.6, 0.45), (PORTAL_CX, FRONT + 0.15, PORTAL_H + 0.2), M["metal"]))
    parts.append(box("shutter", (PORTAL_W - 0.35, 0.3, PORTAL_H - 0.25), (PORTAL_CX, FRONT + 1.75, (PORTAL_H - 0.25) / 2), M["metal"]))
    for z in (1.7, 3.7, 5.7):
        parts.append(box("shutter_slat", (PORTAL_W - 0.3, 0.36, 0.16), (PORTAL_CX, FRONT + 1.75, z), M["metal"]))
    z_bot, z_top = 7.62, 8.78
    parts.append(box("truss_bottom", (PORTAL_W + 0.8, 0.55, 0.25), (PORTAL_CX, FRONT + 0.22, z_bot), M["metal"]))
    parts.append(box("truss_top", (PORTAL_W + 0.8, 0.55, 0.25), (PORTAL_CX, FRONT + 0.22, z_top), M["metal"]))
    for x in (-11.7, -9.3, -6.9, -4.5):
        parts.append(box("truss_post", (0.22, 0.45, z_top - z_bot), (x, FRONT + 0.22, (z_bot + z_top) / 2), M["metal"]))
    for x in (-11.7, -9.3, -6.9):
        parts.append(beam("truss_brace", (x, FRONT + 0.22, z_bot), (x + 2.4, FRONT + 0.22, z_top), 0.2, M["metal"]))

    # Puerta de personas: marco de caliza, hoja de acero.
    for side in (-1, 1):
        parts.append(box("door_jamb", (0.3, 0.5, DOOR_H + 0.3), (DOOR_CX + side * (DOOR_W / 2 + 0.15), FRONT + 0.2, (DOOR_H + 0.3) / 2), M["limestone"]))
    parts.append(box("door_head", (DOOR_W + 0.6, 0.5, 0.3), (DOOR_CX, FRONT + 0.2, DOOR_H + 0.15), M["limestone"]))
    parts.append(box("door_leaf", (DOOR_W - 0.3, 0.25, DOOR_H - 0.1), (DOOR_CX, FRONT + 0.65, (DOOR_H - 0.1) / 2), M["metal"]))

    # Ventanal de nave con sus montantes y alféizar: un hueco grande, no una hilera de ventanitas.
    parts.append(box("window_glass", (WINDOW_W - 0.3, 0.12, WINDOW_Z1 - WINDOW_Z0 - 0.4), (PORTAL_CX, FRONT + 0.62, (WINDOW_Z0 + WINDOW_Z1) / 2), M["glass"]))
    for x in (-10.3, -6.5):
        parts.append(box("window_mullion", (0.2, 0.3, WINDOW_Z1 - WINDOW_Z0 - 0.2), (x, FRONT + 0.4, (WINDOW_Z0 + WINDOW_Z1) / 2), M["metal"]))
    parts.append(box("window_sill", (WINDOW_W + 0.5, 0.55, 0.3), (PORTAL_CX, FRONT + 0.1, WINDOW_Z0 - 0.15), M["limestone"]))

    # Placa de caliza con campo de pizarra y «FUNDICIÓN VULCANO» en letras de acero.
    parts.append(box("sign_plate", (SIGN_W, 0.45, 2.8), (PORTAL_CX, FRONT - 0.15, SIGN_Z), M["limestone"]))
    parts.append(box("sign_field", (SIGN_W - 0.8, 0.2, 2.2), (PORTAL_CX, FRONT - 0.45, SIGN_Z), M["slate"]))
    parts.append(fit_width(letters("FUNDICIÓN VULCANO", 1.2, (PORTAL_CX, FRONT - 0.62, SIGN_Z), M["metal"], depth=0.2), SIGN_W - 1.5))

    # Pilastras de caliza en las esquinas de la fachada.
    for x in (NAVE_X0 + 0.35, NAVE_X1 - 0.35):
        parts.append(box("pilaster", (0.7, 0.5, 19.4), (x, FRONT + 0.1, 9.7), M["limestone"]))
    return parts


def build_gantry(M):
    """Nivel 1: pórtico de carga de acero sobre el portalón, con muelle de caliza y polipasto."""
    parts = []
    dock_top = 0.55
    dock_y0, dock_y1 = -9.85, -8.55
    parts.append(box("dock", (9.8, dock_y1 - dock_y0, dock_top), (PORTAL_CX, (dock_y0 + dock_y1) / 2, dock_top / 2), M["limestone"]))
    parts.append(box("dock_edge", (9.8, 0.22, 0.2), (PORTAL_CX, dock_y0 + 0.11, dock_top - 0.1), M["metal"]))

    post_x = (PORTAL_CX - PORTAL_W / 2 - 0.35, PORTAL_CX + PORTAL_W / 2 + 0.35)
    for x in post_x:
        parts.append(box("gantry_post", (0.45, 0.45, 8.95), (x, -9.55, dock_top + 8.95 / 2), M["metal"]))
    parts.append(box("gantry_beam", (post_x[1] - post_x[0] + 0.5, 0.45, 0.5), (PORTAL_CX, -9.55, 9.25), M["metal"]))
    for x in post_x:
        parts.append(beam("gantry_brace", (x, -9.55, 8.0), (x + (0.9 if x < PORTAL_CX else -0.9), -9.55, 9.1), 0.2, M["metal"]))
    parts.append(box("canopy", (PORTAL_W + 1.4, 1.45, 0.28), (PORTAL_CX, -9.15, 9.66), M["metal"]))
    parts.append(box("canopy_edge", (PORTAL_W + 1.5, 0.2, 0.34), (PORTAL_CX, -9.83, 9.63), M["metal"]))

    # Polipasto colgado de la viga: el pórtico sirve para cargar, no solo de adorno.
    parts.append(box("hoist_body", (0.95, 0.7, 0.55), (PORTAL_CX, -9.55, 8.72), M["metal"]))
    parts.append(box("hoist_cable", (0.1, 0.1, 2.5), (PORTAL_CX, -9.55, 7.2), M["metal"]))
    parts.append(box("hoist_hook", (0.45, 0.3, 0.4), (PORTAL_CX, -9.55, 5.75), M["metal"]))
    return parts


def build_silos(M):
    """Nivel 2: silos de mineral. Entra la segunda fila, más alta, detrás de la del cuerpo."""
    parts = []
    silo(parts, M, SILO_C[0], SILO_C[1], SILO_C_R, SILO_C_H, SILO_C_CONE, (11.0,))
    silo(parts, M, SILO_D[0], SILO_D[1], SILO_C_R, SILO_C_H, SILO_C_CONE, (11.0,), ladder=True)
    return parts


def build_furnace(M):
    """Nivel 3: la chimenea sube y el horno de cubilote entra con su conducto de humos."""
    parts = []
    parts.append(box("chimney_upper", (CHIMNEY_BASE - 0.7, CHIMNEY_BASE - 0.7, 5.65), (CHIMNEY_CX, CHIMNEY_CY, 27.175), M["brick"]))
    parts.append(box("chimney_upper_ring", (CHIMNEY_BASE - 0.2, CHIMNEY_BASE - 0.2, 0.4), (CHIMNEY_CX, CHIMNEY_CY, 30.2), M["brick"]))

    cx, cy = CUPOLA
    parts.append(box("cupola_base", (CUPOLA_R * 2 + 0.5, CUPOLA_R * 2 + 0.5, 0.45), (cx, cy, 0.225), M["limestone"]))
    parts.append(cylinder("cupola_drum", CUPOLA_R, 7.4, (cx, cy, 0.4 + 3.7), M["metal"], 14, True))
    parts.append(cone("cupola_cone", CUPOLA_R + 0.15, 1.3, (cx, cy, 8.45), M["metal"], 14))
    parts.append(box("cupola_door", (0.9, 0.22, 1.0), (cx, cy - CUPOLA_R - 0.05, 3.6), M["metal"]))
    for z in (4.8, 7.2):
        parts.append(cylinder("cupola_ring", CUPOLA_R + 0.08, 0.18, (cx, cy, z), M["metal"], 12, False))
    # Pasarela de carga del horno.
    parts.append(box("cupola_platform", (3.2, 1.3, 0.22), (cx, cy - CUPOLA_R - 0.6, 5.6), M["metal"]))
    parts.append(box("cupola_rail", (3.2, 0.09, 0.09), (cx, cy - CUPOLA_R - 1.15, 6.5), M["metal"]))
    for x in (cx - 1.5, cx + 1.5):
        parts.append(box("cupola_rail_post", (0.09, 0.09, 0.9), (x, cy - CUPOLA_R - 1.15, 6.05), M["metal"]))
    # Conducto de humos del horno a la chimenea.
    parts.append(box("flue", (1.5, 4.4, 1.2), (cx, 1.15, 7.3), M["metal"]))
    return parts


def build_offices(M):
    """Nivel 4: pabellón de oficinas sobre la nave, retranqueado de la fachada."""
    parts = []
    w, d = OFFICE_X1 - OFFICE_X0, OFFICE_Y1 - OFFICE_Y0
    cx, cy = (OFFICE_X0 + OFFICE_X1) / 2, (OFFICE_Y0 + OFFICE_Y1) / 2
    parts.append(box("office_plinth", (w, d, 0.7), (cx, cy, OFFICE_Z0 + 0.35), M["limestone"]))
    body = box("office_body", (w, d, OFFICE_TOP - OFFICE_Z0 - 0.7), (cx, cy, (OFFICE_Z0 + 0.7 + OFFICE_TOP) / 2), M["brick"])
    ribbon = 1.9
    band_z = 23.4
    perforate(
        body,
        [
            box("ribbon_front", (w - 0.4, 0.7, ribbon), (cx, OFFICE_Y0 + 0.35, band_z)),
            box("ribbon_left", (0.7, d - 0.4, ribbon), (OFFICE_X0 + 0.35, cy, band_z)),
            box("ribbon_right", (0.7, d - 0.4, ribbon), (OFFICE_X1 - 0.35, cy, band_z)),
        ],
    )
    parts.append(body)
    parts.append(box("office_glass_front", (w - 0.4, 0.12, ribbon), (cx, OFFICE_Y0 + 0.62, band_z), M["glass"]))
    for x in (OFFICE_X0 + 0.35, OFFICE_X1 - 0.35):
        parts.append(box("office_glass_side", (0.12, d - 0.4, ribbon), (x, cy, band_z), M["glass"]))
    for x in (OFFICE_X0 + 2.2, cx, OFFICE_X1 - 2.2):
        parts.append(box("office_mullion", (0.18, 0.34, ribbon + 0.16), (x, OFFICE_Y0 + 0.1, band_z), M["metal"]))
    for y in (OFFICE_Y0 + 4.5,):
        for x in (OFFICE_X0 + 0.1, OFFICE_X1 - 0.1):
            parts.append(box("office_mullion_side", (0.34, 0.18, ribbon + 0.16), (x, y, band_z), M["metal"]))
    parts.append(box("office_cornice", (w + 0.6, d + 0.6, 0.4), (cx, cy, OFFICE_TOP + 0.2), M["limestone"]))
    parts.append(box("office_roof", (w, d, 0.3), (cx, cy, OFFICE_TOP + 0.55), M["slate"]))
    parts.append(box("office_core", (2.4, 2.4, 1.4), (OFFICE_X0 + 2.0, OFFICE_Y1 - 1.6, OFFICE_TOP + 0.7), M["brick"]))
    return parts


def build_crown(M):
    """Nivel 5: torre de la chimenea con remate de cobre. Es lo más alto de la calle: 40."""
    parts = []
    parts.append(box("tower_shaft", (3.9, 3.9, 4.2), (CHIMNEY_CX, CHIMNEY_CY, 32.5), M["brick"]))
    parts.append(box("tower_upper", (3.5, 3.5, 2.6), (CHIMNEY_CX, CHIMNEY_CY, 35.9), M["brick"]))
    parts.append(box("tower_corbel", (3.8, 3.8, 0.45), (CHIMNEY_CX, CHIMNEY_CY, 37.35), M["brick"]))
    parts.append(box("tower_band", (3.95, 3.95, 0.3), (CHIMNEY_CX, CHIMNEY_CY, 37.7), M["limestone"]))
    parts.append(box("tower_copper", (3.75, 3.75, 0.5), (CHIMNEY_CX, CHIMNEY_CY, 38.1), M["metal_oro"]))
    parts.append(cone("tower_cap", 2.4, 1.55, (CHIMNEY_CX, CHIMNEY_CY, 39.15), M["metal_oro"], 8))
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
        name = f"vulcano_{layer}_{rbx.lower()}{suffix}"
        mesh = merge(members, name)
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

    # Ficha de referencia (caja oscura 8 × 4 × 5) y avatar de 6 de alto para la escala.
    box("ficha_ref", (8.0, 4.0, 5.0), (-2.5 * SPACING, SLOT_SIDE, 2.5), M["dark"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-2.5 * SPACING + 2.6, lot_y - 9.0, 3.0), M["figure"])
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
    builders = {1: build_gantry, 2: build_silos, 3: build_furnace, 4: build_offices, 5: build_crown}
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
    lod = lod_of(objects, "vulcano_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "vulcano_LOD1.fbx")

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
    print("VULCANO_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] > MAX_HEIGHT:
        raise RuntimeError(f"Nivel 5 de {levels['5']['limites']['alto_maximo_sobre_suelo']}: el tope es {MAX_HEIGHT}")
    if levels["0"]["limites"]["alto_maximo_sobre_suelo"] > 25.0:
        raise RuntimeError(f"Nivel 0 de {levels['0']['limites']['alto_maximo_sobre_suelo']}: no debe pasar de 25")

    # Escena de revisión y renders, con las mallas de origen ocultas.
    for obj in objects + [lod]:
        obj.hide_render = True
        obj.hide_viewport = True
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 40
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "fundicion-vulcano.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["slate"], "gold": M["metal"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -190.0, 78.0), (0.0, 22.0, 12.0), 30), f"{RENDER_SUBDIR}/fundicion-vulcano-niveles.png")

    # Comparación: nivel 0 frente a un bloque de Bodega (13) y otro de Cine Lux (24), con la figura de 6
    # delante de la fachada y al lado del portalón, que es lo que permite revisar la puerta.
    hide_all()
    box("ground", (170, 44, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -34.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (6.0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (44.0, 0, 12.0), M["block"])
    # Figura de 6 delante de la fachada y al lado del portalón, sobre el ladrillo: no tapa ninguna puerta.
    box("figure_ref", (1.6, 1.2, 6.0), (-34.0 - 13.85, -10.8, 3.0), M["figure"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -145.0, 30.0), (0.0, 0.0, 10.0), 42), f"{RENDER_SUBDIR}/fundicion-vulcano-comparacion.png")
    print("VULCANO_DONE")


if __name__ == "__main__":
    main()

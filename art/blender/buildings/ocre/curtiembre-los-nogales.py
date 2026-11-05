"""Curtiembre Los Nogales: propiedad de la zona Ocre, modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de 19 (la masa principal), con una crujía baja de 12 en el tercio derecho,
y cinco añadidos que se suman: toldo de carga, segundo secadero y respiraderos; pilas de caliza y mejora de
fachada; chimenea; pabellón anexo de oficinas, retranqueado; y torre de la chimenea con remate de cobre. El
nivel 0 completo no pasa de 24 y el nivel 5 no llega a 40. Sigue el método de barberia-morro.py: una malla por
material y color, LOD1 con decimado y los mismos helpers de build_cine_lux.py.

El negocio se reconoce sin leer el rótulo: portalón de carga, secaderos de listones en la planta alta, en la
crujía baja y sobre la cubierta, pilas de caliza y chimenea de ladrillo con zunchos. Los secaderos son
estructura de listones con pies derechos, no ventanas.

Salidas, en art/blender/buildings/ocre/:
  curtiembre-los-nogales.blend              escena de revisión (no se versiona)
  curtiembre-los-nogales/curtiembre_<pieza>_<material>.fbx y curtiembre_LOD1.fbx
  curtiembre-los-nogales/stats.json         triángulos por pieza y nivel, límites y materiales
Y en art/render/ocre/curtiembre-los-nogales/: curtiembre-los-nogales-niveles.png y
curtiembre-los-nogales-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/ocre/curtiembre-los-nogales.py
"""

import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "curtiembre-los-nogales")
RENDER_SUBDIR = "ocre/curtiembre-los-nogales"
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
    origin_at_zero,
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
BODY_H = 19.0  # masa principal: nave de ladrillo
CORNICE_TOP = 19.5
ROOF_TOP = 19.9
AISLE_H = 12.0  # crujía baja del tercio derecho
AISLE_X0 = 6.0
AISLE_X1 = 16.0

PORTAL_W = 9.0  # portalón de carga, como el de la Bodega
PORTAL_H = 7.4  # más alto que una figura de 6
PORTAL_X = -7.4
DOOR_W = 2.6  # puerta de personas, también por encima de 6
DOOR_H = 7.1
DOOR_X = 0.8

SCREEN_X0 = -11.9  # secadero de listones de la planta alta, sobre portón y puerta
SCREEN_X1 = 4.6
SCREEN_Z0 = 13.0
SCREEN_Z1 = 17.6
SCREEN_SLATS = 11

VENT_X0 = 8.2  # secadero de listones de la crujía baja
VENT_X1 = 15.2
VENT_Z0 = 4.2
VENT_Z1 = 9.0
VENT_SLATS = 8

SIGN_X = -2.9
SIGN_Z = 10.6
SIGN_W = 17.0
SIGN_H = 2.6
SIGN_MAX_LETTERS = 16.0

CHIMNEY_X = -14.2  # chimenea: pecho de ladrillo en la esquina izquierda
CHIMNEY_Y = -8.0
CHIMNEY_W = 3.2
CHIMNEY_D = 3.6
CHIMNEY_TOP = 23.2  # más corona de caliza y filete de cobre: 23,82

VAT_X0 = 8.4  # pilas de caliza, delante de la crujía baja
VAT_X1 = 15.1
VAT_D = 0.95
VAT_H = 1.3

MAX_LEVEL0_TOP = 24.0
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

# Material de Roblox, sufijo de color y RGB de cada material de Blender.
RBX = {
    "brick": ("Brick", "", "B0664A"),
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "wood": ("Wood", "", "6B4A2E"),
    "metal": ("Metal", "", "A8AEB4"),
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
        "wood": flat("wood", "6B4A2E", 0.7),
        "metal": flat("metal", "A8AEB4", 0.35, 0.9),
        "metal_oro": flat("metal_oro", "C9A227", 0.3, 0.9),
        "fabric_rojo": flat("fabric_rojo", "C4382B", 0.8),
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


def cone(name, radius, depth, location, mat, verts=4, rotation=None):
    """Cono de base poligonal: el remate de cobre de la chimenea."""
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


def simplify(obj, ratio=0.75):
    """Aligera el rótulo ya convertido a malla: los glifos gastan más triángulos de los que se ven a escala."""
    select_only(obj)
    modifier = obj.modifiers.new("simplify", "DECIMATE")
    modifier.decimate_type = "COLLAPSE"
    modifier.ratio = ratio
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def slats_across(parts, name, x0, x1, y, z0, z1, how_many, mat, thick=0.12, height=0.22):
    """Listones horizontales que corren a lo ancho: el secadero se lee por los huecos entre listones."""
    span = (z1 - z0 - height) / max(how_many - 1, 1)
    for k in range(how_many):
        parts.append(box(name, (x1 - x0, thick, height), ((x0 + x1) / 2, y, z0 + height / 2 + span * k), mat))


def drying_rack(parts, M, x0, x1, y0, y1, z0, z1, how_many=6):
    """Secadero de listones sobre la cubierta: pies derechos por delante, listones detrás y capa de pizarra."""
    w, d = x1 - x0, y1 - y0
    for x in (x0 + 0.18, (x0 + x1) / 2, x1 - 0.18):
        for y in (y0 + 0.2, y1 - 0.2):
            parts.append(box("rack_post", (0.36, 0.36, z1 - z0), (x, y, (z0 + z1) / 2), M["wood"]))
    slats_across(parts, "rack_slat", x0 + 0.3, x1 - 0.3, y0 + 0.08, z0 + 0.18, z1 - 0.06, how_many, M["wood"])
    for side in (x0 + 0.2, x1 - 0.2):
        parts.append(box("rack_end", (0.16, d - 0.5, z1 - z0 - 0.24), (side, (y0 + y1) / 2, (z0 + z1) / 2), M["wood"]))
    parts.append(box("rack_back", (w - 0.5, 0.12, z1 - z0 - 0.3), ((x0 + x1) / 2, y1 - 0.06, (z0 + z1) / 2), M["wood"]))
    parts.append(box("rack_rail", (w, 0.16, 0.18), ((x0 + x1) / 2, y0 + 0.06, z1 - 0.09), M["wood"]))
    parts.append(box("rack_cap", (w + 0.1, d + 0.1, 0.22), ((x0 + x1) / 2, (y0 + y1) / 2, z1 + 0.11), M["slate"]))


def build_body(M):
    """Nivel 0: nave de ladrillo y crujía baja, con portalón, puerta, dos secaderos, chimenea y placa."""
    parts = []
    # Muro en L (la crujía baja se recorta del volumen) con huecos de verdad: portón, puerta, secadero y
    # el hueco del secadero de la crujía.
    wall = box("body_wall", (WIDTH, DEPTH, BODY_H), (0, 0, BODY_H / 2), M["brick"])
    perforate(
        wall,
        [
            box("cut_portal", (PORTAL_W, 2.4, PORTAL_H + 0.2), (PORTAL_X, -8.8, PORTAL_H / 2 - 0.1)),
            box("cut_door", (DOOR_W, 2.6, DOOR_H + 0.2), (DOOR_X, -8.7, DOOR_H / 2 - 0.1)),
            box(
                "cut_screen",
                (SCREEN_X1 - SCREEN_X0, 1.4, SCREEN_Z1 - SCREEN_Z0),
                ((SCREEN_X0 + SCREEN_X1) / 2, -8.8, (SCREEN_Z0 + SCREEN_Z1) / 2),
            ),
            box("cut_aisle", (AISLE_X1 - AISLE_X0 + 0.8, DEPTH + 2.0, BODY_H - AISLE_H + 0.4), ((AISLE_X0 + AISLE_X1) / 2 + 0.4, 0, (BODY_H + AISLE_H) / 2 + 0.2)),
            box(
                "cut_vent",
                (VENT_X1 - VENT_X0, 1.2, VENT_Z1 - VENT_Z0),
                ((VENT_X0 + VENT_X1) / 2, -8.9, (VENT_Z0 + VENT_Z1) / 2),
            ),
        ],
    )
    parts.append(wall)

    # Zócalo de caliza, abierto en el portón y en la puerta.
    plinth = box("plinth", (WIDTH + 0.4, DEPTH + 0.4, 0.9), (0, 0, 0.45), M["limestone"])
    perforate(
        plinth,
        [
            box("cut_plinth_portal", (PORTAL_W + 0.1, DEPTH + 0.8, 1.2), (PORTAL_X, 0, 0.45)),
            box("cut_plinth_door", (DOOR_W + 0.1, DEPTH + 0.8, 1.2), (DOOR_X, 0, 0.45)),
        ],
    )
    parts.append(plinth)

    # Cornisas y cubiertas de pizarra: la de la nave y la de la crujía.
    parts.append(box("cornice", (22.6, DEPTH + 0.6, 0.5), (-5.0, 0, CORNICE_TOP - 0.25), M["limestone"]))
    parts.append(box("roof", (22.2, DEPTH + 0.2, 0.4), (-5.0, 0, 19.7), M["slate"]))
    parts.append(box("aisle_cornice", (10.6, DEPTH + 0.6, 0.4), (11.0, 0, 11.8), M["limestone"]))
    parts.append(box("aisle_roof", (10.2, DEPTH + 0.2, 0.4), (11.0, 0, 12.2), M["slate"]))
    parts.append(box("aisle_pilaster", (0.8, 0.4, 11.6), (15.6, FRONT - 0.2, 5.8), M["limestone"]))

    # Chimenea: pecho de ladrillo en la esquina, basa de caliza, zunchos de acero y corona con filete de cobre.
    parts.append(box("chimney_base", (3.5, 3.7, 1.0), (CHIMNEY_X, CHIMNEY_Y, 0.5), M["limestone"]))
    parts.append(box("chimney", (CHIMNEY_W, CHIMNEY_D, CHIMNEY_TOP), (CHIMNEY_X, CHIMNEY_Y, CHIMNEY_TOP / 2), M["brick"]))
    for z in (5.5, 11.5, 17.5):
        parts.append(box("chimney_ring", (CHIMNEY_W + 0.1, CHIMNEY_D + 0.1, 0.14), (CHIMNEY_X, CHIMNEY_Y, z), M["metal"]))
    parts.append(box("chimney_crown", (3.6, 3.7, 0.5), (CHIMNEY_X, CHIMNEY_Y, 23.45), M["limestone"]))
    parts.append(box("chimney_copper", (3.65, 3.75, 0.12), (CHIMNEY_X, CHIMNEY_Y, 23.76), M["metal_oro"]))

    # Portalón: persiana de acero en lamas dentro del hueco, con bastidor y umbral.
    for k in range(6):
        parts.append(box("shutter_slat", (PORTAL_W - 0.15, 0.45, 0.86), (PORTAL_X, -7.85, 0.55 + 1.14 * k), M["metal"]))
    parts.append(box("shutter_head", (PORTAL_W - 0.15, 0.5, 0.55), (PORTAL_X, -7.85, 7.05), M["metal"]))
    for side in (-1, 1):
        parts.append(box("portal_jamb", (0.3, 0.5, 7.6), (PORTAL_X + side * (PORTAL_W / 2 - 0.15), -8.9, 3.8), M["metal"]))
    parts.append(box("portal_lintel", (PORTAL_W + 0.3, 0.5, 0.35), (PORTAL_X, -8.9, 7.55), M["metal"]))
    parts.append(box("portal_sill", (PORTAL_W, 0.5, 0.12), (PORTAL_X, -8.9, 0.06), M["metal"]))

    # Puerta de personas: cristal alto con marco de madera.
    parts.append(box("door_glass", (DOOR_W - 0.35, 0.1, 6.6), (DOOR_X, -8.72, 3.35), M["glass"]))
    for side in (-1, 1):
        parts.append(box("door_jamb", (0.22, 0.45, 7.2), (DOOR_X + side * (DOOR_W / 2 - 0.11), -8.85, 3.6), M["wood"]))
    parts.append(box("door_head", (DOOR_W + 0.2, 0.45, 0.3), (DOOR_X, -8.85, 7.0), M["wood"]))
    parts.append(box("door_kick", (DOOR_W - 0.4, 0.25, 0.9), (DOOR_X, -8.8, 0.45), M["wood"]))

    # Secadero de la planta alta: fondo de caliza, listones de madera y pies derechos por delante.
    parts.append(box("screen_back", (SCREEN_X1 - SCREEN_X0 + 0.2, 0.22, SCREEN_Z1 - SCREEN_Z0 + 0.2), ((SCREEN_X0 + SCREEN_X1) / 2, -8.33, (SCREEN_Z0 + SCREEN_Z1) / 2), M["limestone"]))
    slats_across(parts, "screen_slat", SCREEN_X0, SCREEN_X1, -8.88, SCREEN_Z0 + 0.12, SCREEN_Z1 - 0.02, SCREEN_SLATS, M["wood"], thick=0.12, height=0.26)
    for k in range(5):
        x = SCREEN_X0 + (SCREEN_X1 - SCREEN_X0) * k / 4
        parts.append(box("screen_post", (0.34, 0.7, 5.0), (x, -8.85, (SCREEN_Z0 + SCREEN_Z1) / 2), M["wood"]))

    # Secadero de la crujía baja: mismo dibujo de listones, más bajo.
    parts.append(box("vent_back", (VENT_X1 - VENT_X0 + 0.2, 0.2, VENT_Z1 - VENT_Z0 + 0.2), ((VENT_X0 + VENT_X1) / 2, -8.33, (VENT_Z0 + VENT_Z1) / 2), M["limestone"]))
    slats_across(parts, "vent_slat", VENT_X0, VENT_X1, -8.9, VENT_Z0 + 0.1, VENT_Z1 - 0.02, VENT_SLATS, M["wood"], thick=0.12, height=0.24)
    for k in range(4):
        x = VENT_X0 + (VENT_X1 - VENT_X0) * k / 3
        parts.append(box("vent_post", (0.3, 0.6, 5.0), (x, -8.85, (VENT_Z0 + VENT_Z1) / 2), M["wood"]))

    # Placa de pizarra con CURTIEMBRE LOS NOGALES en letras de caliza, sobre la puerta y el toldo.
    parts.append(box("sign_plate", (SIGN_W, 0.3, SIGN_H), (SIGN_X, FRONT - 0.12, SIGN_Z), M["slate"]))
    parts.append(simplify(fit_width(letters("CURTIEMBRE LOS NOGALES", 1.35, (SIGN_X, FRONT - 0.34, SIGN_Z), M["limestone"], depth=0.18), SIGN_MAX_LETTERS)))

    # Secadero de listones sobre la cubierta, delante: el rasgo que se ve de lejos.
    drying_rack(parts, M, -11.5, 3.0, -8.7, -3.1, ROOF_TOP, 22.1)
    return parts


def build_awning(M):
    """Nivel 1: toldo de carga, segundo secadero sobre la cubierta y respiraderos de acero."""
    parts = []
    # Toldo de lona sobre el portón: vuela 0,9 y queda por debajo de la placa.
    run, drop = 0.92, 0.4
    length = math.hypot(run, drop)
    angle = math.atan2(-drop, -run)
    canvas = box("awning", (PORTAL_W + 0.4, length, 0.1), (PORTAL_X, FRONT - run / 2, 8.15), M["fabric_rojo"])
    canvas.rotation_euler = (angle, 0, 0)
    parts.append(canvas)
    parts.append(box("awning_valance", (PORTAL_W + 0.4, 0.06, 0.35), (PORTAL_X, -9.9, 7.73), M["fabric_rojo"]))
    parts.append(box("awning_bar", (PORTAL_W + 0.4, 0.14, 0.14), (PORTAL_X, -9.88, 7.9), M["metal"]))
    for x in (-10.9, -7.4, -3.9):
        arm = box("awning_arm", (0.12, length, 0.12), (x, FRONT - run / 2, 8.04), M["metal"])
        arm.rotation_euler = (angle, 0, 0)
        parts.append(arm)

    # Segundo secadero, más alto y retrasado: la cubierta se llena de listones.
    drying_rack(parts, M, -14.5, 2.0, -2.4, 3.4, ROOF_TOP, 23.0)
    for k in range(3):
        x = -12.2 + 5.6 * k
        parts.append(box("vent_frame", (1.15, 0.16, 0.95), (x, -2.28, 21.6), M["metal"]))
        for j in range(2):
            parts.append(box("vent_slat", (1.0, 0.22, 0.1), (x, -2.2, 21.4 + 0.3 * j), M["metal"]))
    return parts


def build_vats(M):
    """Nivel 2: pilas de caliza delante de la crujía baja y mejora de fachada con caliza."""
    parts = []
    trough = box("vats", (VAT_X1 - VAT_X0, VAT_D, VAT_H), ((VAT_X0 + VAT_X1) / 2, -9.48, VAT_H / 2), M["limestone"])
    perforate(trough, [box("cut_vat", (2.9, 0.55, 1.2), (10.15 + 3.2 * k, -9.48, 0.9)) for k in range(2)])
    parts.append(trough)
    parts.append(box("vat_step", (3.0, 0.45, 0.25), (DOOR_X, -9.25, 0.12), M["limestone"]))

    # Bandas de caliza que enmarcan los secaderos y la placa.
    parts.append(box("screen_sill", (SCREEN_X1 - SCREEN_X0 + 0.4, 0.5, 0.5), ((SCREEN_X0 + SCREEN_X1) / 2, FRONT - 0.05, 12.75), M["limestone"]))
    parts.append(box("screen_head", (SCREEN_X1 - SCREEN_X0 + 0.4, 0.5, 0.4), ((SCREEN_X0 + SCREEN_X1) / 2, FRONT - 0.05, 17.8), M["limestone"]))
    parts.append(box("vent_sill", (VENT_X1 - VENT_X0 + 0.4, 0.5, 0.4), ((VENT_X0 + VENT_X1) / 2, FRONT - 0.05, 4.0), M["limestone"]))
    parts.append(box("sign_frame_top", (SIGN_W + 0.5, 0.4, 0.3), (SIGN_X, FRONT - 0.2, 12.05), M["limestone"]))
    parts.append(box("sign_frame_bottom", (SIGN_W + 0.5, 0.4, 0.3), (SIGN_X, FRONT - 0.2, 9.15), M["limestone"]))
    for side in (-1, 1):
        parts.append(box("sign_frame_side", (0.3, 0.4, 3.2), (SIGN_X + side * (SIGN_W / 2 + 0.15), FRONT - 0.2, SIGN_Z), M["limestone"]))
    return parts


def build_chimney(M):
    """Nivel 3: la chimenea crece hasta 31,9, con zunchos de acero y corona de caliza."""
    parts = []
    parts.append(box("chimney_shaft", (2.3, 2.3, 8.1), (CHIMNEY_X, CHIMNEY_Y, 27.87), M["brick"]))
    parts.append(box("chimney_band_a", (2.6, 2.6, 0.3), (CHIMNEY_X, CHIMNEY_Y, 26.1), M["limestone"]))
    parts.append(box("chimney_band_b", (2.6, 2.6, 0.3), (CHIMNEY_X, CHIMNEY_Y, 29.3), M["limestone"]))
    parts.append(box("chimney_crown", (2.7, 2.7, 0.45), (CHIMNEY_X, CHIMNEY_Y, 31.695), M["limestone"]))
    for z in (25.2, 28.2, 30.9):
        parts.append(box("chimney_ring", (2.4, 2.4, 0.12), (CHIMNEY_X, CHIMNEY_Y, z), M["metal"]))
    return parts


def build_annex(M):
    """Nivel 4: pabellón anexo de oficinas de ladrillo sobre la crujía baja, retranqueado y con ventanal."""
    parts = []
    pavilion = box("annex", (9.2, 6.2, 5.4), (11.2, 4.9, 15.1), M["brick"])
    perforate(pavilion, [box("cut_annex", (6.4, 1.4, 1.8), (11.4, 1.6, 15.4))])
    parts.append(pavilion)
    parts.append(box("annex_glass", (6.4, 0.1, 1.8), (11.4, 2.02, 15.4), M["glass"]))
    for x in (9.0, 11.4, 13.8):
        parts.append(box("annex_mullion", (0.16, 0.3, 1.8), (x, 1.92, 15.4), M["metal"]))
    parts.append(box("annex_sill", (6.8, 0.4, 0.2), (11.4, 1.78, 14.3), M["limestone"]))
    parts.append(box("annex_cornice", (9.6, 6.6, 0.4), (11.2, 4.9, 17.6), M["limestone"]))
    parts.append(box("annex_roof", (9.6, 6.6, 0.3), (11.2, 4.9, 17.95), M["slate"]))
    return parts


def build_tower(M):
    """Nivel 5: torre de la chimenea hasta 39,7, con corona de acero y remate de cobre."""
    parts = []
    parts.append(box("tower_corbel_a", (2.55, 2.55, 0.5), (CHIMNEY_X, CHIMNEY_Y, 32.17), M["brick"]))
    parts.append(box("tower_corbel_b", (2.9, 2.9, 0.5), (CHIMNEY_X, CHIMNEY_Y, 32.67), M["brick"]))
    parts.append(box("tower_shaft", (2.9, 2.9, 4.2), (CHIMNEY_X, CHIMNEY_Y, 35.02), M["brick"]))
    parts.append(box("tower_band", (3.2, 3.2, 0.4), (CHIMNEY_X, CHIMNEY_Y, 37.32), M["limestone"]))
    parts.append(box("tower_crown_base", (2.85, 2.85, 0.25), (CHIMNEY_X, CHIMNEY_Y, 37.645), M["metal"]))
    parts.append(box("tower_crown", (2.65, 2.65, 0.85), (CHIMNEY_X, CHIMNEY_Y, 38.195), M["metal"]))
    parts.append(box("tower_crown_top", (2.9, 2.9, 0.2), (CHIMNEY_X, CHIMNEY_Y, 38.72), M["metal"]))
    parts.append(cone("tower_copper", 2.1, 0.6, (CHIMNEY_X, CHIMNEY_Y, 39.12), M["metal_oro"], rotation=(0, 0, math.radians(45))))
    parts.append(cone("tower_finial", 0.22, 0.26, (CHIMNEY_X, CHIMNEY_Y, 39.55), M["metal_oro"], verts=6))
    return parts


def group(level, parts, store):
    """Une las piezas de un nivel en una malla por material y color. En Roblox cada malla lleva un material."""
    layer = "body" if level == 0 else f"addon{level}"
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        rbx, suffix, rgb = RBX[key]
        name = f"curtiembre_{layer}_{rbx.lower()}{suffix}"
        if len(members) == 1:
            # Un solo objeto: join daría «No mesh data to join», así que solo se renombra y se centra el origen.
            mesh = members[0]
            mesh.name = name
            origin_at_zero(mesh)
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

    # Ficha de referencia (caja oscura 8 × 4 × 5) y figura de 6 junto a la puerta del nivel 0.
    box("ficha_ref", (8.0, 4.0, 5.0), (-2.5 * SPACING, SLOT_SIDE, 2.5), M["dark"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-2.5 * SPACING + DOOR_X + 3.1, building_y - 11.2, 3.0), M["avatar"])
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
    builders = {1: build_awning, 2: build_vats, 3: build_chimney, 4: build_annex, 5: build_tower}
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
    lod = lod_of(objects, "curtiembre_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "curtiembre_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "altura_cuerpo": BODY_H,
        "altura_crujia_baja": AISLE_H,
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
    print("CURTIEMBRE_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if levels["0"]["limites"]["alto_maximo_sobre_suelo"] > MAX_LEVEL0_TOP:
        raise RuntimeError(f"El nivel 0 llega a {levels['0']['limites']['alto_maximo_sobre_suelo']}: no debe pasar de {MAX_LEVEL0_TOP}")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] >= MAX_HEIGHT:
        raise RuntimeError(f"El nivel 5 llega a {levels['5']['limites']['alto_maximo_sobre_suelo']}: no debe llegar a {MAX_HEIGHT}")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "curtiembre-los-nogales.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["metal"], "gold": M["metal_oro"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -190.0, 78.0), (0.0, 22.0, 10.0), 30), f"{RENDER_SUBDIR}/curtiembre-los-nogales-niveles.png")

    # Comparación: nivel 0 junto a una figura de 6 pegada a la puerta y a los bloques de 13 y 24.
    hide_all()
    box("ground", (150, 40, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -30.0, 0.0)
    box("bloque_bajo", (WIDTH, DEPTH, 13.0), (4.0, 0, 6.5), M["block"])
    box("bloque_alto", (WIDTH, DEPTH, 24.0), (38.0, 0, 12.0), M["block"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-30.0 + DOOR_X + 3.1, -11.2, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (4.0, -125.0, 20.0), (4.0, 0.0, 9.5), 40), f"{RENDER_SUBDIR}/curtiembre-los-nogales-comparacion.png")
    print("CURTIEMBRE_DONE")


if __name__ == "__main__":
    main()

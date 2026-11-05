"""Versalles 2: conjunto residencial de ladrillo de la zona Violeta (Muelle Violeta), modelado desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base, con z = 0 a ras de suelo. La masa principal —las dos villas de ladrillo de dos
plantas— llega a 19,0; el nivel 0, con las chimeneas, se queda en 21,45. Cinco añadidos que se suman:

  1. Verja, portón y toldos: barrotes de acero sobre el muro y hoja de portón, y toldo de lona sobre cada puerta.
  2. Jardín y caminos: césped, camino de caliza, setos y cipreses dentro del solar.
  3. Casas nuevas, retranqueadas: dos casas de ladrillo al fondo, con sus cubiertas por encima de las villas.
  4. Pabellón común: la sala de los vecinos al fondo del patio, con cubierta a cuatro aguas y porche.
  5. Torre del depósito: torre de ladrillo sobre el pabellón, con depósito de acero y remate de cobre, hasta 34.

Sigue el método de barberia-morro.py y build_cine_lux.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/violeta/:
  versalles-2.blend                          escena de revisión (no se versiona)
  versalles-2/versalles2_<pieza>_<material>.fbx y versalles2_LOD1.fbx
  versalles-2/stats.json                     triángulos por pieza y nivel, límites y materiales
Y en art/render/violeta/versalles-2/: versalles-2-niveles.png y versalles-2-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/violeta/versalles-2.py
"""

import json
import math
import os
import sys

import bmesh
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "versalles-2")
RENDER_SUBDIR = "violeta/versalles-2"
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

# --- Solar ----------------------------------------------------------------------------------------
WIDTH = 32.0
DEPTH = 18.0
FRONT = -DEPTH / 2  # el frente da a -Y

# --- Muro de la calle, portón y placa ------------------------------------------------------------
WALL_Y0, WALL_Y1 = -8.85, -8.15  # muro de ladrillo, con su albardilla de caliza
WALL_H = 1.15
WALL_TOP = WALL_H + 0.28
PILLAR_XS = (10.6,)  # pilastras de la verja, a cada lado del portón
GATE_X = 4.5  # medio hueco del portalón: 9 de ancho
GATE_TOP = 7.4  # más alto que la figura de 6
PIER_X0, PIER_X1 = 4.5, 6.0
GATE_Y0, GATE_Y1 = -9.0, -8.1
PIER_TOP = 9.6
CAPITAL_TOP = 10.5
GATE_FINIAL_TOP = 11.4
LINTEL_TOP = 8.2  # dintel de caliza sobre el portalón
SIGN_Z0, SIGN_Z1 = 8.2, 10.4  # placa de pizarra con el nombre
SIGN_HALF = 5.8
SIGN_Z = 9.3
SIGN_SIZE = 1.6
SIGN_MAX_W = 9.9

# --- Villas de dos plantas: la masa principal ----------------------------------------------------
VX0, VX1 = 5.8, 15.0  # 9,2 de ancho
VY0, VY1 = -5.6, 3.0  # 8,6 de fondo
VCX = (VX0 + VX1) / 2  # 10,4
V_WALL_TOP = 15.2
V_CORNICE_TOP = 15.75
V_EAVE = 15.78
V_RIDGE = 19.0  # la altura del cuerpo
V_HIP, V_OVER = 2.4, 0.7
DOOR_W, DOOR_TOP = 2.6, 6.9  # más ancha y más alta que la puerta mínima del estándar
LOW_WINS = ((7.4, 1.7), (13.4, 1.7))
LOW_Z0, LOW_Z1 = 1.5, 5.9
UP_WINS = ((7.6, 2.2), (13.2, 2.2))
UP_Z0, UP_Z1 = 8.7, 13.1
CHIMNEY_X, CHIMNEY_Y = 13.6, 1.7
CHIMNEY_TOP = 21.2

# --- Nivel 1: verja, portón y toldos -------------------------------------------------------------
RAIL_TOP = 3.2
RAIL_PICKETS = 4
LEAF_HALF = GATE_X - 0.1
LEAF_TOP = GATE_TOP - 0.2
AWNING_W = 4.6
AWNING_WALL_Z = 7.7
AWNING_EDGE_Y = -7.35
AWNING_EDGE_Z = 6.95
DECK_W, DECK_Y1, DECK_Z = 5.6, -7.6, 0.45
POST_X, POST_Y = 1.9, -7.15

# --- Nivel 2: jardín y caminos -------------------------------------------------------------------
LAWN_Z = 0.16
PATH_HALF, PATH_Z = 1.7, 0.22
HEDGE_W, HEDGE_H = 0.55, 0.95

# --- Nivel 3: casas nuevas, retranqueadas --------------------------------------------------------
BX0, BX1 = 7.6, 15.2
BY0, BY1 = 4.4, 8.4
B_WALL_TOP = 15.4
B_CORNICE_TOP = 15.85
B_EAVE = 15.88
B_RIDGE = 21.2
B_HIP, B_OVER = 1.4, 0.6
B_CHIMNEY_X, B_CHIMNEY_Y = 13.4, 7.5
B_CHIMNEY_TOP = 22.9

# --- Nivel 4: pabellón común ---------------------------------------------------------------------
PX0, PX1 = -4.9, 4.9
PY0, PY1 = 1.9, 8.5
P_WALL_TOP = 15.0
P_CORNICE_TOP = 15.5
P_EAVE = 15.55
P_RIDGE = 21.8
P_HIP, P_OVER = 1.6, 0.5

# --- Nivel 5: torre del depósito -----------------------------------------------------------------
TOWER_HALF = 1.7
TOWER_CY = (PY0 + PY1) / 2
TOWER_BASE = 12.0  # arranca dentro del pabellón: no flota
SHAFT_TOP = 29.2
TANK_BOTTOM, TANK_TOP = 29.15, 32.6
TANK_R = 2.35
CAP_BOTTOM, CAP_TOP = 32.55, 33.7
TOWER_TIP = 33.95
MAX_HEIGHT = 34.0
BODY_LIMIT = 24.0
TRIANGLE_BUDGET = 3000
CINE_LUX_L5_TRIANGLES = 3042

# --- Escena de calle (solo render) ---------------------------------------------------------------
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
ZONE_RGB = "8B5CF6"  # violeta, solo en la casilla pintada de la escena de render

# Material de Roblox, sufijo de color y RGB de cada clave de material de Blender.
RBX = {
    "brick": ("Brick", "", "B0664A"),
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "wood": ("Wood", "", "6B4A2E"),
    "fabric_rojo": ("Fabric", "_rojo", "C4382B"),
    "metal_acero": ("Metal", "_acero", "A8AEB4"),
    "metal_oro": ("Metal", "_oro", "C9A227"),
    "metal_violeta": ("Metal", "_violeta", "8B5CF6"),
    "grass_cesped": ("Grass", "_cesped", "6E8F4E"),
    "grass_seto": ("Grass", "_seto", "4A6B3A"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "wood": flat("wood", "6B4A2E", 0.7),
        "fabric_rojo": flat("fabric_rojo", "C4382B", 0.8),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.25, 0.8),
        "metal_oro": flat("metal_oro", "C9A227", 0.3, 0.9),
        "metal_violeta": flat("metal_violeta", ZONE_RGB, 0.35, 0.6),
        "grass_cesped": flat("grass_cesped", "6E8F4E", 0.9),
        "grass_seto": flat("grass_seto", "4A6B3A", 0.9),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", ZONE_RGB, 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "6E747C", 0.8),
    }


def slab(name, x0, x1, y0, y1, z0, z1, mat=None):
    """Caja a partir de sus límites: se lee mejor que centro y tamaño."""
    x0, x1 = sorted((x0, x1))
    y0, y1 = sorted((y0, y1))
    z0, z1 = sorted((z0, z1))
    return box(name, (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), mat)


def span(a, b, pad=0.0):
    """Límites de un tramo con el vuelo hacia fuera: la villa izquierda se modela con la x en negativo."""
    return (min(a, b) - pad, max(a, b) + pad)


def pyramid(name, side, height, location, mat):
    """Pirámide de base cuadrada con las aristas paralelas a los ejes."""
    bpy.ops.mesh.primitive_cone_add(
        vertices=4,
        radius1=side / math.sqrt(2.0),
        radius2=0.0,
        depth=height,
        location=location,
        rotation=(0.0, 0.0, math.radians(45.0)),
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def cylinder(name, radius, depth, location, mat, verts=10, caps=True):
    """Cilindro vertical: depósito, aros y remate de cobre de la torre."""
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


def cone(name, radius, depth, location, mat, verts=10):
    """Cono de base circular: remate de cobre de la torre y cipreses del jardín."""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def hip_roof(name, x0, x1, y0, y1, z_eave, z_ridge, mat, hip=0.0):
    """Cubierta de pizarra a cuatro aguas, con la cumbrera en el eje x.

    `hip` recorta la cumbrera para que los cuatro faldones caigan al mismo alero; el prisma va cerrado
    por abajo para que el vuelo del alero no se vea como un agujero.
    """
    x0, x1 = sorted((x0, x1))
    y0, y1 = sorted((y0, y1))
    mid = (y0 + y1) / 2
    verts = [
        (x0, y0, z_eave),
        (x1, y0, z_eave),
        (x1, y1, z_eave),
        (x0, y1, z_eave),
        (x0 + hip, mid, z_ridge),
        (x1 - hip, mid, z_ridge),
    ]
    faces = [(0, 1, 5, 4), (2, 3, 4, 5), (1, 2, 5), (3, 0, 4), (0, 3, 2, 1)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
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


def simplify(obj, ratio):
    """Baja el detalle de una malla sin moverla. El rótulo es la pieza más cara del cuerpo y a 190 studs no se nota."""
    select_only(obj)
    modifier = obj.modifiers.new("simplify", "DECIMATE")
    modifier.ratio = ratio
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def opening(cuts, cx, z0, z1, width, face_y, depth=1.4, outside=0.4):
    """Recorte que entra desde la fachada, con el borde de fuera para no dejar caras coplanares."""
    cuts.append(box("cut", (width, depth + outside, z1 - z0), (cx, face_y + (depth - outside) / 2, (z0 + z1) / 2)))


def pane(parts, M, cx, z0, z1, width, face_y, depth=1.4):
    """Cristal opaco al fondo del nicho: tapa el hueco y no deja ver la pared de dentro."""
    parts.append(box("pane", (width - 0.1, 0.12, z1 - z0 - 0.1), (cx, face_y + depth - 0.1, (z0 + z1) / 2), M["glass"]))


def frame(parts, cx, z0, z1, width, face_y, mat, sill=True):
    """Cerco de caliza: dos jambas, dintel y alféizar. Todo solapa 0,01 con el hueco para no coplanar."""
    for sign in (-1, 1):
        parts.append(box("jamb", (0.28, 0.5, z1 - z0 + 0.28), (cx + sign * (width / 2 + 0.13), face_y + 0.06, (z0 + z1) / 2), mat))
    parts.append(box("head", (width + 0.54, 0.5, 0.3), (cx, face_y + 0.06, z1 + 0.14), mat))
    if sill:
        parts.append(box("sill", (width + 0.7, 0.62, 0.26), (cx, face_y + 0.1, z0 - 0.12), mat))


def window(parts, cuts, M, cx, z0, z1, width, face_y, mat=None, sill=True):
    """Ventana completa: hueco de verdad, cristal al fondo y cerco de caliza."""
    opening(cuts, cx, z0, z1, width, face_y)
    pane(parts, M, cx, z0, z1, width, face_y)
    frame(parts, cx, z0, z1, width, face_y, mat or M["limestone"], sill)


def door(parts, cuts, M, cx, z0, z1, width, face_y, leaf_mat=None):
    """Puerta con hoja de madera y cerco de caliza."""
    opening(cuts, cx, z0 - 0.5, z1, width, face_y)
    parts.append(box("leaf", (width - 0.18, 0.14, z1 - 0.12), (cx, face_y + 1.15, (z1 - 0.12) / 2 + 0.06), leaf_mat or M["wood"]))
    for sign in (-1, 1):
        parts.append(box("jamb", (0.3, 0.55, z1 + 0.25), (cx + sign * (width / 2 + 0.14), face_y + 0.08, (z1 + 0.25) / 2), M["limestone"]))
    parts.append(box("head", (width + 0.6, 0.55, 0.32), (cx, face_y + 0.08, z1 + 0.14), M["limestone"]))


def villa(M, side):
    """Una de las dos villas: ladrillo, ventanas pequeñas con cerco de caliza y cubierta de pizarra."""
    parts, cuts = [], []
    x0, x1 = side * VX0, side * VX1
    sx = lambda value: side * value  # noqa: E731

    wall = slab("villa_wall", x0, x1, VY0, VY1, 0.0, V_WALL_TOP, M["brick"])
    door(parts, cuts, M, sx(VCX), 0.0, DOOR_TOP, DOOR_W, VY0)
    for cx, width in LOW_WINS:
        window(parts, cuts, M, sx(cx), LOW_Z0, LOW_Z1, width, VY0)
    for cx, width in UP_WINS:
        window(parts, cuts, M, sx(cx), UP_Z0, UP_Z1, width, VY0, sill=False)
    perforate(wall, cuts)
    parts.insert(0, wall)

    # Zócalo, junta de plantas y cornisa: la villa se apoya en la caliza, no en una caja de ladrillo.
    px0, px1 = span(x0, x1, 0.12)
    plinth = slab("plinth", px0, px1, VY0 - 0.14, VY1 + 0.12, 0.0, 0.7, M["limestone"])
    perforate(plinth, [box("door_cut", (DOOR_W, 1.2, 1.4), (sx(VCX), VY0 + 0.1, 0.4))])
    parts.append(plinth)
    sx0, sx1 = span(x0, x1, 0.1)
    parts.append(slab("string", sx0, sx1, VY0 - 0.1, VY1 + 0.1, 7.0, 7.35, M["limestone"]))
    cx0, cx1 = span(x0, x1, 0.35)
    parts.append(slab("cornice", cx0, cx1, VY0 - 0.35, VY1 + 0.35, V_WALL_TOP, V_CORNICE_TOP, M["limestone"]))

    # Cubierta a cuatro aguas y chimenea de ladrillo con remate de caliza.
    rx0, rx1 = span(x0, x1, V_OVER)
    parts.append(hip_roof("roof", rx0, rx1, VY0 - V_OVER, VY1 + V_OVER, V_EAVE, V_RIDGE, M["slate"], hip=V_HIP))
    parts.append(slab("ridge_cap", rx0 + V_HIP - 0.2, rx1 - V_HIP + 0.2, (VY0 + VY1) / 2 - 0.3, (VY0 + VY1) / 2 + 0.3, V_RIDGE - 0.06, V_RIDGE + 0.18, M["slate"]))
    parts.append(slab("chimney", sx(CHIMNEY_X) - 0.45, sx(CHIMNEY_X) + 0.45, CHIMNEY_Y - 0.45, CHIMNEY_Y + 0.45, 15.8, CHIMNEY_TOP, M["brick"]))
    parts.append(slab("chimney_cap", sx(CHIMNEY_X) - 0.55, sx(CHIMNEY_X) + 0.55, CHIMNEY_Y - 0.55, CHIMNEY_Y + 0.55, CHIMNEY_TOP, CHIMNEY_TOP + 0.25, M["limestone"]))
    return parts


def gateway(M):
    """Muro de la calle, pilastras, portón y placa de pizarra con el nombre en letras de caliza."""
    parts = []
    for side in (-1, 1):
        # Muro de ladrillo con zócalo y albardilla de caliza, del portón al borde del solar.
        parts.append(slab("street_wall", side * PIER_X1, side * 16.0, WALL_Y0, WALL_Y1, 0.0, WALL_H, M["brick"]))
        parts.append(slab("street_cap", side * PIER_X1, side * 16.0, WALL_Y0 - 0.12, WALL_Y1 + 0.12, WALL_H, WALL_TOP, M["limestone"]))
        for x in PILLAR_XS:
            parts.append(slab("pillar", side * x - 0.42, side * x + 0.42, WALL_Y0 - 0.22, WALL_Y1 + 0.22, 0.0, 2.5, M["brick"]))
            parts.append(slab("pillar_cap", side * x - 0.54, side * x + 0.54, WALL_Y0 - 0.32, WALL_Y1 + 0.32, 2.5, 2.82, M["limestone"]))
        # Pilastras del portón: ladrillo, basa y capitel de caliza, y remate piramidal.
        parts.append(slab("gate_pier", side * PIER_X0, side * PIER_X1, GATE_Y0, GATE_Y1, 0.0, PIER_TOP, M["brick"]))
        gx0, gx1 = span(side * PIER_X0, side * PIER_X1, 0.16)
        parts.append(slab("gate_pier_plinth", gx0, gx1, GATE_Y0 - 0.1, GATE_Y1 + 0.1, 0.0, 0.85, M["limestone"]))
        cx0, cx1 = span(side * PIER_X0, side * PIER_X1, 0.18)
        parts.append(slab("gate_pier_capital", cx0, cx1, GATE_Y0 - 0.14, GATE_Y1 + 0.14, PIER_TOP, CAPITAL_TOP, M["limestone"]))
        parts.append(
            pyramid(
                "gate_pier_finial",
                1.6,
                GATE_FINIAL_TOP - CAPITAL_TOP,
                (side * (PIER_X0 + PIER_X1) / 2, (GATE_Y0 + GATE_Y1) / 2, (CAPITAL_TOP + GATE_FINIAL_TOP) / 2),
                M["limestone"],
            )
        )

    # Dintel sobre el portalón y placa de pizarra con el nombre, como el cartel del Cine Lux.
    parts.append(slab("lintel", -PIER_X1 + 0.02, PIER_X1 - 0.02, GATE_Y0 - 0.04, GATE_Y1 + 0.04, GATE_TOP, LINTEL_TOP, M["limestone"]))
    parts.append(slab("placa", -SIGN_HALF, SIGN_HALF, GATE_Y0 + 0.02, GATE_Y1 - 0.02, SIGN_Z0, SIGN_Z1, M["slate"]))
    parts.append(slab("placa_cap", -SIGN_HALF - 0.3, SIGN_HALF + 0.3, GATE_Y0 - 0.06, GATE_Y1 + 0.06, SIGN_Z1 - 0.06, SIGN_Z1 + 0.32, M["limestone"]))
    parts.append(
        simplify(
            fit_width(
                letters("VERSALLES 2", SIGN_SIZE, (0, GATE_Y0 - 0.02, SIGN_Z), M["limestone"], depth=0.22),
                SIGN_MAX_W,
            ),
            0.7,
        )
    )
    return parts


def build_body(M):
    """Nivel 0: dos villas de ladrillo de dos plantas, muro de caliza y portón con el nombre."""
    parts = []
    for side in (-1, 1):
        parts += villa(M, side)
    parts += gateway(M)
    return parts


def build_rail(M):
    """Nivel 1: verja de acero sobre el muro, hojas del portón y toldo de lona en cada puerta."""
    parts = []
    # Barrotes de la verja sobre la albardilla, de la pilastra del portón al borde del solar.
    for side in (-1, 1):
        x_in, x_out = side * PIER_X1, side * 16.0
        parts.append(slab("rail_top", x_in, x_out, WALL_Y0 + 0.06, WALL_Y0 + 0.22, RAIL_TOP - 0.14, RAIL_TOP, M["metal_acero"]))
        for k in range(RAIL_PICKETS):
            x = x_in + (x_out - x_in) * (k + 0.5) / RAIL_PICKETS
            parts.append(slab("picket", x - 0.07, x + 0.07, WALL_Y0 + 0.06, WALL_Y0 + 0.22, WALL_TOP - 0.1, RAIL_TOP, M["metal_acero"]))
    # Hojas del portón, de barrotes: se cierra el hueco sin tapar el jardín.
    for side in (-1, 1):
        x_in, x_out = side * 0.12, side * LEAF_HALF
        for z0, z1 in ((0.35, 0.5), (3.05, 3.2), (LEAF_TOP - 0.15, LEAF_TOP)):
            parts.append(slab("leaf_rail", x_in, x_out, GATE_Y0 + 0.36, GATE_Y0 + 0.5, z0, z1, M["metal_acero"]))
        parts.append(slab("leaf_stile", side * 0.12, side * 0.3, GATE_Y0 + 0.34, GATE_Y0 + 0.52, 0.2, LEAF_TOP, M["metal_acero"]))
        parts.append(slab("leaf_stile", side * (LEAF_HALF - 0.18), side * LEAF_HALF, GATE_Y0 + 0.34, GATE_Y0 + 0.52, 0.2, LEAF_TOP, M["metal_acero"]))
        for k in range(3):
            x = side * (0.65 + (LEAF_HALF - 0.95) * k / 2.0)
            parts.append(slab("leaf_bar", x - 0.06, x + 0.06, GATE_Y0 + 0.36, GATE_Y0 + 0.5, 0.2, LEAF_TOP - 0.1, M["metal_acero"]))
    # Porche: tarima y escalón de caliza, dos postes de madera y toldo de lona roja sobre la puerta.
    for side in (-1, 1):
        cx = side * VCX
        parts.append(slab("deck", cx - DECK_W / 2, cx + DECK_W / 2, VY0, DECK_Y1, 0.0, DECK_Z, M["limestone"]))
        parts.append(slab("step", cx - 1.7, cx + 1.7, DECK_Y1, DECK_Y1 - 0.55, 0.0, 0.24, M["limestone"]))
        for sign in (-1, 1):
            x = cx + sign * POST_X
            parts.append(slab("post", x - 0.13, x + 0.13, POST_Y - 0.13, POST_Y + 0.13, DECK_Z, AWNING_EDGE_Z, M["wood"]))
        run = POST_Y - VY0
        fall = AWNING_EDGE_Z - AWNING_WALL_Z
        canvas = box(
            "awning",
            (AWNING_W, math.hypot(run, fall), 0.16),
            (cx, (VY0 + POST_Y) / 2, (AWNING_WALL_Z + AWNING_EDGE_Z) / 2),
            M["fabric_rojo"],
        )
        canvas.rotation_euler = (math.atan2(-fall, -run), 0.0, 0.0)
        parts.append(canvas)
        parts.append(slab("valance", cx - AWNING_W / 2, cx + AWNING_W / 2, POST_Y - 0.09, POST_Y + 0.09, AWNING_EDGE_Z - 0.4, AWNING_EDGE_Z, M["fabric_rojo"]))
    return parts


def build_garden(M):
    """Nivel 2: césped, camino de caliza, setos y cipreses, todo dentro del solar y a ras de suelo."""
    parts = []
    # Césped: franjas delanteras, fondo del patio y jardín trasero de los lados.
    for side in (-1, 1):
        parts.append(slab("lawn_front", side * 6.1, side * 15.9, WALL_Y1 + 0.05, VY0 + 0.05, 0.0, LAWN_Z, M["grass_cesped"]))
        parts.append(slab("lawn_rear", side * 6.1, side * 15.9, 3.6, 8.8, 0.0, LAWN_Z, M["grass_cesped"]))
    for side in (-1, 1):
        parts.append(slab("lawn_patio", side * (PATH_HALF - 0.06), side * 5.7, WALL_Y1 + 0.05, 8.8, 0.0, LAWN_Z, M["grass_cesped"]))
    # Camino de caliza del portón al pabellón.
    parts.append(slab("path", -PATH_HALF, PATH_HALF, WALL_Y1 + 0.05, PY0 + 0.05, 0.0, PATH_Z, M["limestone"]))
    # Setos: dos a lo largo del camino, dos pegados al muro de la calle.
    for side in (-1, 1):
        parts.append(slab("hedge_path", side * (PATH_HALF + 0.12), side * (PATH_HALF + 0.12 + HEDGE_W), -7.9, PY0 - 0.6, LAWN_Z - 0.06, LAWN_Z + HEDGE_H, M["grass_seto"]))
        parts.append(slab("hedge_wall", side * 6.4, side * 15.4, WALL_Y1 + 0.25, WALL_Y1 + 0.25 + HEDGE_W, LAWN_Z - 0.06, LAWN_Z + HEDGE_H, M["grass_seto"]))
    # Cuatro cipreses en el patio, dos a cada lado del camino, y dos arbustos recortados.
    for x, y in ((-3.2, -6.4), (3.2, -6.4), (-3.2, -1.0), (3.2, -1.0)):
        parts.append(cone("cypress", 0.78, 4.6, (x, y, LAWN_Z + 2.3), M["grass_seto"], verts=6))
    for x, y in ((-4.7, -3.7), (4.7, -3.7)):
        parts.append(cone("shrub", 0.62, 1.5, (x, y, LAWN_Z + 0.75), M["grass_seto"], verts=6))
    return parts


def back_house(M, side):
    """Nivel 3: casa nueva retranqueada al fondo, con cubierta de pizarra y chimenea."""
    parts, cuts = [], []
    x0, x1 = side * BX0, side * BX1
    sx = lambda value: side * value  # noqa: E731
    wall = slab("back_wall", x0, x1, BY0, BY1, 0.0, B_WALL_TOP, M["brick"])
    perforate(wall, cuts)
    parts.insert(0, wall)
    bx0, bx1 = span(x0, x1, 0.1)
    parts.append(slab("back_plinth", bx0, bx1, BY0 - 0.12, BY1 + 0.1, 0.0, 0.6, M["limestone"]))
    kx0, kx1 = span(x0, x1, 0.3)
    parts.append(slab("back_cornice", kx0, kx1, BY0 - 0.3, BY1 + 0.3, B_WALL_TOP, B_CORNICE_TOP, M["limestone"]))
    rx0, rx1 = span(x0, x1, B_OVER)
    parts.append(hip_roof("back_roof", rx0, rx1, BY0 - B_OVER, BY1 + B_OVER, B_EAVE, B_RIDGE, M["slate"], hip=B_HIP))
    parts.append(slab("back_ridge", rx0 + B_HIP - 0.2, rx1 - B_HIP + 0.2, (BY0 + BY1) / 2 - 0.3, (BY0 + BY1) / 2 + 0.3, B_RIDGE - 0.06, B_RIDGE + 0.16, M["slate"]))
    parts.append(slab("back_chimney", sx(B_CHIMNEY_X) - 0.4, sx(B_CHIMNEY_X) + 0.4, B_CHIMNEY_Y - 0.4, B_CHIMNEY_Y + 0.4, 17.4, B_CHIMNEY_TOP, M["brick"]))
    parts.append(slab("back_chimney_cap", sx(B_CHIMNEY_X) - 0.5, sx(B_CHIMNEY_X) + 0.5, B_CHIMNEY_Y - 0.5, B_CHIMNEY_Y + 0.5, B_CHIMNEY_TOP, B_CHIMNEY_TOP + 0.22, M["limestone"]))
    return parts


def build_houses(M):
    """Nivel 3: las dos casas nuevas que el conjunto levanta al fondo del jardín."""
    parts = []
    for side in (-1, 1):
        parts += back_house(M, side)
    return parts


def build_pavilion(M):
    """Nivel 4: pabellón común de los vecinos, con cubierta a cuatro aguas y porche de caliza."""
    parts, cuts = [], []
    wall = slab("pavilion_wall", PX0, PX1, PY0, PY1, 0.0, P_WALL_TOP, M["brick"])
    door(parts, cuts, M, 0.0, 0.0, 7.2, 3.2, PY0)
    for cx in (-2.9, 2.9):
        window(parts, cuts, M, cx, 1.4, 6.2, 1.8, PY0)
        window(parts, cuts, M, cx, 9.6, 12.8, 1.6, PY0, sill=False)
    perforate(wall, cuts)
    parts.insert(0, wall)
    plinth = slab("pavilion_plinth", PX0 - 0.12, PX1 + 0.12, PY0 - 0.14, PY1 + 0.1, 0.0, 0.7, M["limestone"])
    perforate(plinth, [box("door_cut", (3.6, 1.4, 1.4), (0.0, PY0 + 0.1, 0.4))])
    parts.append(plinth)
    parts.append(slab("pavilion_band", PX0 - 0.08, PX1 + 0.08, PY0 - 0.1, PY1 + 0.08, 7.35, 7.7, M["limestone"]))
    parts.append(slab("pavilion_cornice", PX0 - 0.32, PX1 + 0.32, PY0 - 0.32, PY1 + 0.3, P_WALL_TOP, P_CORNICE_TOP, M["limestone"]))
    parts.append(hip_roof("pavilion_roof", PX0 - P_OVER, PX1 + P_OVER, PY0 - P_OVER, PY1 + P_OVER, P_EAVE, P_RIDGE, M["slate"], hip=P_HIP))
    parts.append(slab("pavilion_ridge", PX0 + P_HIP - 0.2, PX1 - P_HIP + 0.2, TOWER_CY - 0.3, TOWER_CY + 0.3, P_RIDGE - 0.06, P_RIDGE + 0.18, M["slate"]))
    # Porche del pabellón: losa de caliza sobre dos postes de madera.
    parts.append(slab("porch_canopy", -2.35, 2.35, PY0 - 1.15, PY0 + 0.2, 7.75, 8.1, M["limestone"]))
    for sign in (-1, 1):
        x = sign * 2.05
        parts.append(slab("porch_post", x - 0.14, x + 0.14, PY0 - 1.05, PY0 - 0.77, 0.0, 7.75, M["wood"]))
    return parts


def build_tower(M):
    """Nivel 5: torre del depósito sobre el pabellón, con depósito de acero y remate de cobre."""
    parts = []
    cx, cy = 0.0, TOWER_CY
    parts.append(slab("tower_shaft", cx - TOWER_HALF, cx + TOWER_HALF, cy - TOWER_HALF, cy + TOWER_HALF, TOWER_BASE, SHAFT_TOP, M["brick"]))
    parts.append(slab("tower_band", cx - TOWER_HALF - 0.14, cx + TOWER_HALF + 0.14, cy - TOWER_HALF - 0.14, cy + TOWER_HALF + 0.14, SHAFT_TOP - 0.55, SHAFT_TOP, M["limestone"]))
    parts.append(slab("tower_base_band", cx - TOWER_HALF - 0.12, cx + TOWER_HALF + 0.12, cy - TOWER_HALF - 0.12, cy + TOWER_HALF + 0.12, 16.6, 17.1, M["limestone"]))
    parts.append(cylinder("tank", TANK_R, TANK_TOP - TANK_BOTTOM, (cx, cy, (TANK_BOTTOM + TANK_TOP) / 2), M["metal_acero"], verts=10))
    parts.append(cone("cap", TANK_R + 0.35, CAP_TOP - CAP_BOTTOM, (cx, cy, (CAP_BOTTOM + CAP_TOP) / 2), M["metal_oro"], verts=10))
    parts.append(cylinder("finial_ball", 0.24, TOWER_TIP - CAP_TOP, (cx, cy, (CAP_TOP + TOWER_TIP) / 2), M["metal_violeta"], verts=6))
    return parts


def group(level, parts, store):
    """Une las piezas de un nivel en una malla por material y color. En Roblox cada malla lleva un material."""
    layer = "body" if level == 0 else f"addon{level}"
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        # Las transformaciones se aplican antes de unir para que la malla quede en coordenadas de escena.
        for member in members:
            select_only(member)
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        rbx, suffix, rgb = RBX[key]
        name = f"versalles2_{layer}_{rbx.lower()}{suffix}"
        if len(members) == 1:
            mesh = members[0]
            select_only(mesh)
            origin_at_zero(mesh)
            mesh.name = name
        else:
            mesh = join(members, name)
        uv_unwrap(mesh)
        materials = {m.name for m in mesh.data.materials if m is not None}
        if len(materials) != 1:
            raise RuntimeError(f"{name} tiene {len(materials)} materiales")
        store.append({"key": name, "level": level, "material": rbx, "rgb": rgb, "obj": mesh})


def bounds(objects):
    """Límites en studs, con las mallas en coordenadas de escena."""
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

    # Nivel 0: cuerpo. Niveles 1 a 5: añadidos que se suman sin sustituir nada.
    group(0, build_body(M), pieces)
    builders = {1: build_rail, 2: build_garden, 3: build_houses, 4: build_pavilion, 5: build_tower}
    for level, builder in builders.items():
        group(level, builder(M), pieces)

    # Estadísticas por pieza, por nivel (propias y acumuladas) y límites.
    objects = [piece["obj"] for piece in pieces]
    total = sum(count(obj) for obj in objects)
    levels = {}
    cumulative_objects = {}
    for level in range(6):
        own = [piece for piece in pieces if piece["level"] == level]
        cum = [piece for piece in pieces if piece["level"] <= level]
        cumulative_objects[level] = [piece["obj"] for piece in cum]
        levels[str(level)] = {
            "triangulos_propios": sum(count(piece["obj"]) for piece in own),
            "triangulos_acumulados": sum(count(piece["obj"]) for piece in cum),
            "limites": bounds(cumulative_objects[level]),
        }

    # LOD1 con el conjunto entero, al 50 % como los demás edificios.
    lod = lod_of(objects, "versalles2_LOD1")
    lod_tris = count(lod)

    for piece in pieces:
        export(piece["obj"], piece["key"] + ".fbx")
    export(lod, "versalles2_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "cuerpo": {"alto_masa_principal": V_RIDGE, "alto_nivel_0": levels["0"]["limites"]["alto_maximo_sobre_suelo"]},
        "piezas": [
            {
                "clave": piece["key"],
                "nivel": piece["level"],
                "material": piece["material"],
                "rgb": piece["rgb"],
                "triangulos": count(piece["obj"]),
            }
            for piece in pieces
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
    print("VERSALLES2_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if levels["0"]["limites"]["alto_maximo_sobre_suelo"] > BODY_LIMIT:
        raise RuntimeError(f"El nivel 0 llega a {levels['0']['limites']['alto_maximo_sobre_suelo']} y no debe pasar de {BODY_LIMIT}")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] > MAX_HEIGHT:
        raise RuntimeError(f"Altura total de {levels['5']['limites']['alto_maximo_sobre_suelo']} supera {MAX_HEIGHT}")
    for level in range(6):
        limits = levels[str(level)]["limites"]
        if limits["frente"] < -10.0:
            raise RuntimeError(f"nivel {level}: el frente llega a {limits['frente']} y no debe pasar de -10")
        if max(abs(limits["x_minimo"]), abs(limits["x_maximo"])) > 18.0:
            raise RuntimeError(f"nivel {level}: se sale a lo ancho ({limits['x_minimo']} a {limits['x_maximo']})")
        if limits["fondo_maximo"] > 13.0:
            raise RuntimeError(f"nivel {level}: el fondo llega a {limits['fondo_maximo']}")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "versalles-2.blend"))

    markers = {
        kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["slate"], "gold": M["metal_oro"]})
        for kind in ("house", "hotel", "tower")
    }
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -195.0, 96.0), (0.0, 26.0, 11.0), 30), f"{RENDER_SUBDIR}/versalles-2-niveles.png")

    # Comparación: nivel 0 frente a un bloque de Bodega (13) y otro de Cine Lux (24), con la figura de 6
    # delante de la fachada y al lado del portón: sin ella no se puede revisar la puerta.
    hide_all()
    box("ground", (400, 200, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -34.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (34, 0, 12.0), M["block"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-34.0 + 6.6, -10.4, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -150.0, 30.0), (0.0, 4.0, 12.0), 30), f"{RENDER_SUBDIR}/versalles-2-comparacion.png")
    print("VERSALLES2_DONE")


if __name__ == "__main__":
    main()

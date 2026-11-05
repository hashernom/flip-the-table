"""Calle del Azafrán: casa de especias de la zona Naranja (Feria Naranja), modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de 19, la masa principal: casa estrecha de ladrillo con tienda, sacos y
balanza, y el piso alto volado del secadero. A la derecha, el secadero abierto y el almacén bajo aprovechan el
ancho del solar. Cinco añadidos que se suman: toldo y escaparate, listones del secadero, chimenea de secado y
respiraderos, pabellón del almacén retranqueado y torre del secadero con remate de oro.

La silueta es la de una casa de especias: torre estrecha de ladrillo, piso volado de listones, chimenea de
secado y una nave baja de listones al lado. No es una caja con ventanas: el cuerpo tiene huecos de verdad
(perforate), marcos, cornisa y placa. Se distingue de sus vecinas (nave de hierro con reloj; restaurante de
asados con porche y chimenea) por la estrechez, el secadero volado y la cubierta plana con antepecho de caliza.

Salidas, en art/blender/buildings/naranja/:
  calle-del-azafran.blend                         escena de revisión (no se versiona)
  calle-del-azafran/azafran_<pieza>_<material>.fbx y azafran_LOD1.fbx
  calle-del-azafran/stats.json                    triángulos por pieza y nivel, límites y materiales
Y en art/render/naranja/calle-del-azafran/: calle-del-azafran-niveles.png y
calle-del-azafran-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/naranja/calle-del-azafran.py
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
OUT = os.path.join(HERE, "calle-del-azafran")
RENDER_SUBDIR = "naranja/calle-del-azafran"
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

# --- Solar y casa -------------------------------------------------------------------------------
WIDTH = 32.0
DEPTH = 18.0
FRONT = -8.8  # fachada de la casa
BACK = 8.8

HX0, HX1 = -15.8, -2.6  # casa estrecha: 13,2 de ancho
HCX = (HX0 + HX1) / 2.0
LOWER_TOP = 11.9  # planta baja: tienda
WALL_TOP = 18.2
BODY_TOP = 19.0  # cuerpo (masa principal), con el antepecho de caliza

# Escaparate y puerta: la puerta pasa de 2,4 × 6,5 de largo.
SHOP_X0, SHOP_X1 = -15.25, -7.25
SHOP_Z0, SHOP_Z1 = 0.9, 6.6
SHOP_CX = (SHOP_X0 + SHOP_X1) / 2.0
DOOR_CX = -5.2
DOOR_W = 2.8
DOOR_TOP = 7.3
CUT = 1.6  # profundidad de los cortes: deja hornacina de 1,3 para los sacos

# Secadero volado: tres vanos grandes, no una hilera de ventanitas.
BAY_W = 2.9
BAY_Z0, BAY_Z1 = 12.6, 17.4
BAY_STEP = 3.45
BAYS = [HCX - BAY_STEP, HCX, HCX + BAY_STEP]

# Rótulo: placa de madera con el nombre en letras de caliza, sobre la puerta y el toldo.
PLATE_W = 12.2
PLATE_Z = 10.15
PLATE_H = 2.1
SIGN_TEXT = "CALLE DEL AZAFRÁN"
SIGN_SIZE = 1.25

# Chimenea de secado (el nivel 0 ya la enseña; el 3 la remata).
CHIM_CX, CHIM_CY = -7.75, 3.35
CHIM_W, CHIM_D = 1.7, 1.5
CHIM_L0_TOP = 21.98

# Secadero abierto de la derecha: aprovecha el ancho del solar.
SHED_X0, SHED_X1 = -2.6, 7.2
SHED_FRONT = -6.6
SHED_TOP = 7.5

# Almacén bajo de la derecha.
STORE_X0, STORE_X1 = 7.2, 16.4
STORE_FRONT = -6.2
STORE_TOP = 6.6

# Pabellón del almacén (nivel 4), retranqueado sobre el almacén bajo.
ANNEX_X0, ANNEX_X1 = 7.6, 16.2
ANNEX_Y0, ANNEX_Y1 = 1.2, 8.6
ANNEX_Z0, ANNEX_Z1 = 6.7, 13.0

# Torre del secadero (nivel 5).
TOWER_X, TOWER_Y = -12.5, -5.5
TOWER_TOP = 33.7
MAX_HEIGHT = 34.0
LEVEL0_MAX = 24.0

# Escena de calle.
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
    "brick": ("Brick", "", "B0664A"),  # 176, 102, 74
    "limestone": ("Limestone", "", "D2C9B4"),  # 210, 201, 180
    "slate": ("Slate", "", "4A4E54"),  # 74, 78, 84
    "glass": ("Glass", "", "2E4A63"),  # 46, 74, 99
    "wood": ("Wood", "", "6B4A2E"),  # 107, 74, 46
    "fabric_rojo": ("Fabric", "_rojo", "C4382B"),  # 196, 56, 43
    "metal_acero": ("Metal", "_acero", "A8AEB4"),  # 168, 174, 180
    "metal_oro": ("Metal", "_oro", "C9A227"),  # 201, 162, 39
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
        "metal_acero": flat("metal_acero", "A8AEB4", 0.4, 0.9),
        "metal_oro": flat("metal_oro", "C9A227", 0.3, 0.9),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "F59E0B", 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "6E747C", 0.8),
    }


def from_faces(name, verts, faces, mat):
    """Malla a mano (prismas y troncos de pirámide): caras planas, normales recalculadas hacia fuera."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    return obj


def frustum(name, cx, cy, sx0, sy0, z0, sx1, sy1, z1, mat):
    """Tronco de pirámide de base rectangular, para el remate de oro de la torre."""
    verts = [
        (cx - sx0 / 2, cy - sy0 / 2, z0),
        (cx + sx0 / 2, cy - sy0 / 2, z0),
        (cx + sx0 / 2, cy + sy0 / 2, z0),
        (cx - sx0 / 2, cy + sy0 / 2, z0),
        (cx - sx1 / 2, cy - sy1 / 2, z1),
        (cx + sx1 / 2, cy - sy1 / 2, z1),
        (cx + sx1 / 2, cy + sy1 / 2, z1),
        (cx - sx1 / 2, cy + sy1 / 2, z1),
    ]
    faces = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return from_faces(name, verts, faces, mat)


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
    """Nivel 0: casa estrecha de ladrillo con tienda, sacos, balanza, piso volado del secadero, chimenea,
    placa, y a la derecha el secadero abierto y el almacén bajo: el negocio se lee sin rótulo."""
    parts = []

    # Muro bajo (tienda) y muro volado (secadero), con huecos de verdad.
    lower = box("wall_low", (HX1 - HX0, BACK - FRONT, LOWER_TOP), (HCX, (FRONT + BACK) / 2, LOWER_TOP / 2), M["brick"])
    shop_cut = box("shop_cut", (SHOP_X1 - SHOP_X0, CUT, SHOP_Z1 - SHOP_Z0), (SHOP_CX, FRONT + CUT / 2 - 0.3, (SHOP_Z0 + SHOP_Z1) / 2))
    door_cut = box("door_cut", (DOOR_W, CUT, DOOR_TOP + 0.5), (DOOR_CX, FRONT + CUT / 2 - 0.3, (DOOR_TOP - 0.5) / 2))
    perforate(lower, [shop_cut, door_cut])
    parts.append(lower)

    upper = box("wall_up", (HX1 - HX0, BACK - FRONT + 0.4, WALL_TOP - LOWER_TOP), (HCX, (FRONT - 0.4 + BACK) / 2, (LOWER_TOP + WALL_TOP) / 2), M["brick"])
    bay_cuts = [box("bay_cut", (BAY_W, 1.2, BAY_Z1 - BAY_Z0), (x, FRONT - 0.4 + 0.5, (BAY_Z0 + BAY_Z1) / 2)) for x in BAYS]
    perforate(upper, bay_cuts)
    parts.append(upper)

    # Zócalo de caliza, abierto en la puerta, y cornisa de la planta baja.
    plinth = box("plinth", (13.6, 17.8, 0.6), (HCX, (FRONT + BACK) / 2, 0.3), M["limestone"])
    perforate(plinth, [box("plinth_cut", (DOOR_W, 1.8, 0.8), (DOOR_CX, FRONT + 0.6, 0.4))])
    parts.append(plinth)
    parts.append(box("shop_band", (13.6, 0.5, 0.5), (HCX, FRONT - 0.1, 7.7), M["limestone"]))

    # Cubierta plana de la casa: antepecho de caliza (el cuerpo llega a 19) y terraza de pizarra.
    for size, location in (
        ((14.0, 0.5, 1.0), (HCX, -9.25, 18.5)),
        ((14.0, 0.5, 1.0), (HCX, 8.75, 18.5)),
        ((0.5, 17.5, 1.0), (-15.95, -0.25, 18.5)),
        ((0.5, 17.5, 1.0), (-2.45, -0.25, 18.5)),
    ):
        parts.append(box("parapet", size, location, M["limestone"]))
    parts.append(box("roof_deck", (13.2, 17.4, 0.4), (HCX, -0.2, 18.4), M["slate"]))

    # Escaparate: cristal al fondo de la hornacina, marco de madera, mostrador de caliza y los sacos.
    parts.append(box("shop_glass", (7.9, 0.1, 5.7), (SHOP_CX, -7.6, 3.75), M["glass"]))
    parts.append(box("shop_head", (8.2, 0.55, 0.32), (SHOP_CX, -8.85, 6.44), M["wood"]))
    parts.append(box("shop_sill", (8.2, 0.75, 0.3), (SHOP_CX, -8.75, 1.05), M["wood"]))
    for x in (SHOP_X0 + 0.15, SHOP_X1 - 0.15):
        parts.append(box("shop_jamb", (0.3, 0.55, 5.4), (x, -8.85, 3.75), M["wood"]))
    parts.append(box("shop_mullion", (0.22, 0.5, 5.4), (SHOP_CX, -8.85, 3.75), M["wood"]))
    parts.append(box("shop_counter", (7.6, 0.6, 0.55), (SHOP_CX, -8.0, 1.175), M["limestone"]))
    for x in (-14.3, -12.55, -10.1):
        parts.append(box("sack", (1.0, 0.55, 1.15), (x, -8.05, 2.03), M["wood"]))
        parts.append(box("sack_neck", (0.52, 0.4, 0.26), (x, -8.05, 2.72), M["wood"]))
    parts.append(box("scale_base", (0.85, 0.5, 0.12), (-9.15, -8.05, 1.51), M["metal_acero"]))
    parts.append(box("scale_column", (0.1, 0.1, 0.85), (-9.15, -8.05, 2.28), M["metal_acero"]))
    parts.append(box("scale_pan", (0.62, 0.4, 0.07), (-9.15, -8.05, 2.74), M["metal_acero"]))

    # Puerta alta de madera, con su marco, umbral y herraje.
    for x in (DOOR_CX - 0.73, DOOR_CX + 0.73):
        parts.append(box("door_leaf", (1.34, 0.16, 7.0), (x, -8.0, 3.65), M["wood"]))
    for x in (DOOR_CX - 1.29, DOOR_CX + 1.29):
        parts.append(box("door_jamb", (0.22, 0.5, 7.1), (x, -8.55, 3.55), M["wood"]))
    parts.append(box("door_head", (DOOR_W, 0.5, 0.35), (DOOR_CX, -8.55, 7.12), M["wood"]))
    parts.append(box("door_threshold", (3.2, 0.9, 0.2), (DOOR_CX, -8.35, 0.1), M["limestone"]))
    parts.append(box("door_handle", (0.12, 0.16, 0.65), (-4.35, -7.9, 3.6), M["metal_acero"]))

    # Rótulo: placa de madera con el nombre en letras de caliza, sobre la puerta y el toldo.
    parts.append(box("sign_plate", (PLATE_W, 0.42, PLATE_H), (HCX, FRONT - 0.15, PLATE_Z), M["wood"]))
    name = letters(SIGN_TEXT, SIGN_SIZE, (HCX, FRONT - 0.42, 10.0), M["limestone"], depth=0.18)
    parts.append(fit_width(name, 11.4))

    # Secadero volado: viga de madera, cristal al fondo y las hiladas de listones que cierran los vanos:
    # el piso alto se lee como secadero desde la calle, sin necesidad de rótulo.
    parts.append(box("bressummer", (13.6, 0.6, 0.55), (HCX, FRONT - 0.25, 11.8), M["wood"]))
    parts.append(box("loft_glass", (9.9, 0.1, 4.9), (HCX, -8.35, 15.0), M["glass"]))
    for x in BAYS:
        for k in range(9):
            parts.append(box("loft_lath", (BAY_W, 0.16, 0.18), (x, FRONT - 0.25, 12.78 + 0.54 * k), M["wood"]))

    # Chimenea de secado sobre la terraza.
    parts.append(box("chimney", (CHIM_W, CHIM_D, 3.2), (CHIM_CX, CHIM_CY, 20.1), M["brick"]))
    parts.append(box("chimney_cap", (CHIM_W + 0.25, CHIM_D + 0.25, 0.28), (CHIM_CX, CHIM_CY, 21.84), M["limestone"]))

    # Racks de secado en la terraza: listones a la vista, la silueta de la casa de especias.
    for cx in (-8.3, -5.1):
        for sx in (-1, 1):
            parts.append(box("rack_post", (0.16, 0.16, 2.1), (cx + sx * 1.35, -7.4, 19.65), M["wood"]))
        for z in (19.0, 19.75, 20.5):
            parts.append(box("rack_shelf", (2.95, 0.55, 0.12), (cx, -7.4, z), M["wood"]))

    # Secadero abierto de la derecha: muros de ladrillo, postes, cubierta de pizarra y listones al frente.
    parts.append(box("shed_side", (0.5, 15.4, SHED_TOP), (6.95, 1.1, SHED_TOP / 2), M["brick"]))
    parts.append(box("shed_back", (9.3, 0.5, SHED_TOP), (2.05, 8.55, SHED_TOP / 2), M["brick"]))
    for x in (-2.3, 1.0, 4.1, 6.5):
        parts.append(box("shed_post", (0.34, 0.34, SHED_TOP), (x, SHED_FRONT + 0.15, SHED_TOP / 2), M["wood"]))
    parts.append(box("shed_roof", (9.8, 15.4, 0.3), (2.3, 1.1, SHED_TOP + 0.15), M["slate"]))
    parts.append(box("shed_fascia", (10.2, 0.4, 0.35), (2.3, SHED_FRONT + 0.1, SHED_TOP + 0.02), M["limestone"]))
    for bay_x, bay_w in ((-0.65, 2.9), (2.55, 2.7), (5.3, 2.0)):
        for z in (1.85, 2.95):
            parts.append(box("shed_shelf", (bay_w, 0.55, 0.12), (bay_x, SHED_FRONT + 0.35, z), M["wood"]))
    for x in (-1.2, 0.4, 1.9):
        parts.append(box("shed_sack", (0.9, 0.6, 1.0), (x, SHED_FRONT + 1.1, 0.5), M["wood"]))
    for sx in (-1, 1):
        parts.append(box("shed_rack_post", (0.16, 0.16, 1.9), (2.3 + sx * 1.9, 6.9, SHED_TOP + 1.1), M["wood"]))
    for z in (SHED_TOP + 0.8, SHED_TOP + 1.7):
        parts.append(box("shed_rack_shelf", (4.2, 0.55, 0.12), (2.3, 6.9, z), M["wood"]))

    # Almacén bajo de la derecha: cierra el ancho del solar.
    store = box("store", (STORE_X1 - STORE_X0, BACK - STORE_FRONT, STORE_TOP), ((STORE_X0 + STORE_X1) / 2, (STORE_FRONT + BACK) / 2, STORE_TOP / 2), M["brick"])
    store_door = box("store_cut", (3.2, 1.6, 5.6), (11.6, STORE_FRONT + 0.5, 2.8))
    store_window = box("store_window_cut", (1.5, 1.2, 1.2), (14.7, STORE_FRONT + 0.5, 3.7))
    perforate(store, [store_door, store_window])
    parts.append(store)
    for x in (10.82, 12.38):
        parts.append(box("store_leaf", (1.55, 0.14, 5.4), (x, -5.35, 2.8), M["wood"]))
    for x in (10.09, 13.11):
        parts.append(box("store_jamb", (0.2, 0.4, 5.6), (x, -6.0, 2.8), M["wood"]))
    parts.append(box("store_head", (3.4, 0.4, 0.3), (11.6, -6.0, 5.45), M["wood"]))
    parts.append(box("store_glass", (1.4, 0.1, 1.1), (14.7, -5.35, 3.7), M["glass"]))
    parts.append(box("store_sill", (1.8, 0.4, 0.22), (14.7, -6.05, 3.05), M["wood"]))
    parts.append(box("store_cornice", (9.6, 0.5, 0.35), (11.8, -6.15, 6.3), M["limestone"]))
    parts.append(box("store_roof", (9.6, 15.4, 0.35), (11.8, 1.3, 6.775), M["slate"]))
    return parts


def build_awning(M):
    """Nivel 1: toldo de lona roja sobre escaparate y puerta, con faldón, brazos, recercado de caliza y cajas."""
    parts = []
    run, drop = 1.05, 0.6
    angle = math.atan2(-drop, -run)
    canvas = box("toldo", (11.2, math.hypot(run, drop), 0.14), (-9.7, FRONT - run / 2, 7.85), M["fabric_rojo"])
    canvas.rotation_euler = (angle, 0.0, 0.0)
    parts.append(canvas)
    parts.append(box("toldo_faldon", (11.2, 0.14, 0.45), (-9.7, FRONT - run, 7.32), M["fabric_rojo"]))
    for x in (-15.2, -4.2):
        parts.append(box("brazo", (0.18, 1.2, 0.18), (x, FRONT - 0.55, 7.8), M["wood"]))
    for x in (-15.55, -6.95):
        parts.append(box("pilastra", (0.5, 0.5, 6.9), (x, FRONT - 0.05, 4.05), M["limestone"]))
    parts.append(box("escaparate_dintel", (9.0, 0.45, 0.4), (-11.25, FRONT - 0.12, 6.95), M["limestone"]))
    parts.append(box("caja_grande", (1.1, 0.9, 0.9), (-14.6, -9.35, 0.45), M["wood"]))
    parts.append(box("caja_pequena", (0.9, 0.8, 0.7), (-13.3, -9.4, 0.35), M["wood"]))
    return parts


def build_galeria(M):
    """Nivel 2: el secadero gana su galería de listones — tarima, soportes y barandilla — y las ventanas del
    secadero se recercan con alféizar de caliza y postes de madera."""
    parts = []
    parts.append(box("galeria_tarima", (11.6, 0.7, 0.22), (HCX, FRONT - 0.55, 12.61), M["wood"]))
    for x in (-14.9, -11.6, -8.3, -5.0):
        parts.append(box("galeria_soporte", (0.35, 0.65, 0.5), (x, FRONT - 0.5, 12.25), M["wood"]))
    for z in (13.0, 13.35):
        parts.append(box("galeria_liston", (11.6, 0.16, 0.16), (HCX, FRONT - 0.85, z), M["wood"]))
    for x in (-15.1, -11.9, -8.7, -5.5):
        parts.append(box("galeria_post", (0.16, 0.16, 0.98), (x, FRONT - 0.85, 13.0), M["wood"]))
    for x in BAYS:
        parts.append(box("alfeizar", (BAY_W + 0.34, 0.55, 0.3), (x, FRONT - 0.45, 12.3), M["limestone"]))
        for side in (-1, 1):
            parts.append(box("poste", (0.24, 0.32, 4.9), (x + side * (BAY_W / 2 - 0.02), FRONT - 0.48, 14.95), M["wood"]))
    return parts


def build_chimney(M):
    """Nivel 3: la chimenea de secado gana caña, banda y capucha de acero, y el secadero, respiraderos."""
    parts = []
    parts.append(box("chimney_up", (1.4, 1.25, 1.5), (CHIM_CX, CHIM_CY, 22.73), M["brick"]))
    parts.append(box("chimney_band", (1.65, 1.5, 0.26), (CHIM_CX, CHIM_CY, 23.61), M["limestone"]))
    parts.append(box("chimney_cowl", (1.75, 1.6, 0.35), (CHIM_CX, CHIM_CY, 23.92), M["metal_acero"]))
    parts.append(box("chimney_hat", (1.95, 1.8, 0.14), (CHIM_CX, CHIM_CY, 24.17), M["metal_acero"]))
    for cy in (1.2, 4.4):
        parts.append(box("vent", (1.2, 1.0, 0.9), (-14.0, cy, 19.05), M["metal_acero"]))
        parts.append(box("vent_cap", (1.45, 1.25, 0.12), (-14.0, cy, 19.56), M["metal_acero"]))
    return parts


def build_annex(M):
    """Nivel 4: pabellón del almacén, retranqueado sobre el almacén bajo, con portón alto y pescante."""
    parts = []
    annex = box("annex", (ANNEX_X1 - ANNEX_X0, ANNEX_Y1 - ANNEX_Y0, ANNEX_Z1 - ANNEX_Z0), ((ANNEX_X0 + ANNEX_X1) / 2, (ANNEX_Y0 + ANNEX_Y1) / 2, (ANNEX_Z0 + ANNEX_Z1) / 2), M["brick"])
    perforate(annex, [box("annex_cut", (3.8, 1.6, 4.9), (11.9, ANNEX_Y0 + 0.5, 9.55))])
    parts.append(annex)
    for x in (10.99, 12.81):
        parts.append(box("annex_leaf", (1.8, 0.14, 4.7), (x, ANNEX_Y0 + 0.55, 9.55), M["wood"]))
    parts.append(box("annex_head", (4.0, 0.4, 0.3), (11.9, ANNEX_Y0 + 0.2, 11.95), M["wood"]))
    parts.append(box("annex_hoist", (0.45, 3.0, 0.45), (11.9, ANNEX_Y0 - 1.2, 12.5), M["wood"]))
    parts.append(box("annex_pulley", (0.5, 0.55, 0.45), (11.9, ANNEX_Y0 - 2.6, 12.12), M["metal_acero"]))
    parts.append(box("annex_coping", (ANNEX_X1 - ANNEX_X0, 0.5, 0.32), (11.9, ANNEX_Y0 + 0.25, 12.95), M["limestone"]))
    parts.append(box("annex_roof", (ANNEX_X1 - ANNEX_X0 + 0.4, ANNEX_Y1 - ANNEX_Y0 + 0.4, 0.35), (11.9, 4.9, 13.175), M["slate"]))
    return parts


def build_tower(M):
    """Nivel 5: torre del secadero, de listones y postes, con collar de caliza y remate de oro."""
    parts = []
    cx, cy = TOWER_X, TOWER_Y
    parts.append(box("tower_core", (2.8, 2.8, 12.2), (cx, cy, 24.7), M["wood"]))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box("tower_leg", (0.45, 0.45, 12.5), (cx + sx * 1.38, cy + sy * 1.38, 24.85), M["wood"]))
    for z in (20.2, 24.3, 28.4):
        for sy in (-1, 1):
            parts.append(box("tower_band_x", (3.4, 0.18, 0.2), (cx, cy + sy * 1.48, z), M["wood"]))
        for sx in (-1, 1):
            parts.append(box("tower_band_y", (0.18, 3.4, 0.2), (cx + sx * 1.48, cy, z), M["wood"]))
    parts.append(box("tower_collar", (3.5, 3.5, 0.3), (cx, cy, 30.95), M["limestone"]))
    parts.append(frustum("tower_cap", cx, cy, 3.7, 3.7, 31.1, 1.5, 1.5, 33.2, M["metal_oro"]))
    parts.append(box("tower_finial", (0.34, 0.34, 0.5), (cx, cy, 33.45), M["metal_oro"]))
    return parts


def group(level, parts, store):
    """Une las piezas de un nivel en una malla por material y color. En Roblox cada malla lleva un material."""
    if not parts:
        raise RuntimeError(f"el nivel {level} no tiene piezas que unir")
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
        name = f"azafran_{layer}_{rbx.lower()}{suffix}"
        # Un grupo con una sola pieza no se une: join() avisaría «No mesh data to join».
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
        "fondo_y": round(max(ys), 2),
        "ancho_x": [round(min(xs), 2), round(max(xs), 2)],
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

    # Ficha de referencia (caja oscura 8 × 4 × 5) y figura de 6 de alto junto a la puerta.
    box("ficha_ref", (8.0, 4.0, 5.0), (-2.5 * SPACING, SLOT_SIDE, 2.5), M["dark"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-2.5 * SPACING + DOOR_CX - 2.4, lot_y - 9.0, 3.0), M["avatar"])
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
    builders = {1: build_awning, 2: build_galeria, 3: build_chimney, 4: build_annex, 5: build_tower}
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
    lod = lod_of(objects, "azafran_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "azafran_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "cuerpo": {"ancho": HX1 - HX0, "fondo": BACK - FRONT, "alto": BODY_TOP},
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
    print("AZAFRAN_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if levels["0"]["limites"]["alto_maximo_sobre_suelo"] > LEVEL0_MAX:
        raise RuntimeError(f"El nivel 0 llega a {levels['0']['limites']['alto_maximo_sobre_suelo']} y el tope es {LEVEL0_MAX}")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] > MAX_HEIGHT:
        raise RuntimeError(f"El nivel 5 llega a {levels['5']['limites']['alto_maximo_sobre_suelo']} y el tope es {MAX_HEIGHT}")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "calle-del-azafran.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["metal_acero"], "gold": M["metal_oro"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -192.0, 80.0), (0.0, 22.0, 11.0), 30), f"{RENDER_SUBDIR}/calle-del-azafran-niveles.png")

    # Comparación: nivel 0 frente a un bloque de Bodega (13) y otro de Cine Lux (24), con la figura de 6
    # delante de la fachada y al lado de la puerta, que es lo que permite revisar la puerta.
    hide_all()
    box("ground", (190, 44, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -24.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (10, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (44, 0, 12.0), M["block"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-24.0 - 7.6, -10.6, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (-4.0, -112.0, 24.0), (2.0, 0.0, 8.5), 33), f"{RENDER_SUBDIR}/calle-del-azafran-comparacion.png")
    print("AZAFRAN_DONE")


if __name__ == "__main__":
    main()

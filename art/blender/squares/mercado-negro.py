"""Mercado Negro: puesto de callejón de una casilla especial, modelado desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18 y el vuelo del toldo llega a y = -9,5; el
frente da a -Y y el origen está en el centro de la base, con z = 0 a ras de suelo. Es una casilla, no una
propiedad: no tiene niveles ni añadidos, así que todas las piezas van en el cuerpo y la altura máxima es 14.
El puesto se reconoce por cuatro rasgos: la lona a rayas sobre el mostrador, las cajas apiladas, la persiana
metálica a medio bajar y el farol. Detrás, una casa de vecindad baja con tejado a dos aguas, tanque de agua,
chimenea y portón de carga: el callejón también se ve desde la cámara alta del juego.

Salidas, en art/blender/squares/:
  mercado-negro.blend              escena de revisión (no se versiona)
  mercado-negro/market_<material>.fbx y market_LOD1.fbx
  mercado-negro/stats.json         triángulos por pieza, total, LOD1 y medidas
Y en art/render/squares/mercado-negro/: mercado-negro-frontal.png, mercado-negro-aereo.png y
mercado-negro-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/squares/mercado-negro.py
"""

import json
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "mercado-negro")
RENDER_SUBDIR = "squares/mercado-negro"
sys.path.insert(0, SLICE)

# Helpers compartidos con los edificios ya en el juego (no se copian: se importan).
from build_cine_lux import (  # noqa: E402
    box,
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
    uv_unwrap,
)

# --- Solar --------------------------------------------------------------------------------------
WIDTH = 32.0
DEPTH = 18.0
FRONT = -DEPTH / 2.0  # -9, la fachada del puesto
MAX_HEIGHT = 14.0
AVATAR = 6.0

# --- Puesto (kiosco) ----------------------------------------------------------------------------
KX = 9.5  # medio ancho
KY0, KY1 = -6.2, 1.6  # frente y fondo
KZ = 8.8  # altura de los muros del puesto
COUNTER_X = (-6.9, -0.7)  # hueco del mostrador
COUNTER_Z = (2.6, 7.0)
SHUTTER_BOTTOM = 4.85  # la persiana tapa media ventana
DOOR_X = (2.9, 5.7)  # 2,8 de ancho
DOOR_TOP = 7.0  # 7,0 de alto: un stud por encima del avatar

# --- Rótulo -------------------------------------------------------------------------------------
PARAPET_Z = 11.4
SIGN_Z = 10.05
SIGN_TEXT = "MERCADO NEGRO"
SIGN_SIZE = 1.85
SIGN_W = 16.6

# --- Lona ---------------------------------------------------------------------------------------
AWN_X = 8.6
AWN_Z_WALL = 7.9
AWN_EDGE_Y = -9.5
AWN_EDGE_Z = 6.95
PANELS = 8

# --- Casa del fondo -----------------------------------------------------------------------------
BX = 15.6
BY0, BY1 = 1.0, 9.0
BZ = 11.4
RIDGE_Y = 5.0
RIDGE_Z = 13.2

# --- Escena de render ---------------------------------------------------------------------------
STREET_WIDTH = 34.0
SIDEWALK = 7.0
TRIANGLE_BUDGET = 3000
CINE_LUX_L5_TRIANGLES = 3042

# Material de Roblox, sufijo de color y RGB de cada material de Blender.
RBX = {
    "brick": ("Brick", "", "B0664A"),
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "metal": ("Metal", "_acero", "A8AEB4"),
    "wood": ("Wood", "", "6B4A2E"),
    "fabric_rojo": ("Fabric", "_rojo", "C4382B"),
    "fabric_crema": ("Fabric", "_crema", "EDE5D3"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": textured("slate", "concrete", "4A4E54"),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "metal": flat("metal", "A8AEB4", 0.4, 0.9),
        "wood": flat("wood", "6B4A2E", 0.7),
        "fabric_rojo": flat("fabric_rojo", "C4382B", 0.8),
        "fabric_crema": flat("fabric_crema", "EDE5D3", 0.8),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "6E747C", 0.8),
        "zone": flat("zone", "C97B3A", 0.8),
    }


# --- Helpers propios ----------------------------------------------------------------------------

def cylinder(name, radius, depth, location, mat, verts=12, caps=True):
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


def cone(name, radius, depth, location, mat, verts=4, flip=False):
    """Pirámide de base cuadrada, para el remate del farol y los caperuzones."""
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts,
        radius1=radius,
        radius2=0.0,
        depth=depth,
        location=location,
        rotation=(math.pi if flip else 0.0, 0.0, math.radians(45)),
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def slab(name, x, y0, z0, y1, z1, width, thickness, mat=None):
    """Losa plana entre dos puntos del plano YZ, centrada en x: lona, faldones y cubierta."""
    dy, dz = y1 - y0, z1 - z0
    length = math.hypot(dy, dz)
    obj = box(name, (width, length, thickness), (x, (y0 + y1) / 2.0, (z0 + z1) / 2.0), mat)
    obj.rotation_euler = (math.atan2(dz, dy), 0.0, 0.0)
    return obj


def prism(name, tri, x0, x1, mat):
    """Prisma triangular: los hastiales del tejado de la casa del fondo."""
    (y0, z0), (y1, z1), (y2, z2) = tri
    verts = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z1), (x0, y1, z1), (x1, y2, z2), (x0, y2, z2)]
    faces = [(0, 3, 5), (1, 2, 4), (0, 1, 2, 3), (3, 2, 4, 5), (5, 4, 1, 0)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def crate(name, size, loc, yaw, mat, hero=False):
    """Caja de madera con travesaños que sobresalen, para que se lea como caja y no como bloque.

    Gira sobre Z, nunca sobre Y: así ninguna esquina baja de z = 0.
    """
    w, d, h = size
    cos, sin = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))

    def place(dx, dy, dz, sx, sy, sz):
        obj = box(name, (sx, sy, sz), (loc[0] + dx * cos - dy * sin, loc[1] + dx * sin + dy * cos, loc[2] + dz), mat)
        obj.rotation_euler = (0.0, 0.0, math.radians(yaw))
        return obj

    parts = [place(0.0, 0.0, 0.0, w, d, h)]
    for k in range(2):
        dz = -h / 2.0 + h * (0.27 + 0.46 * k)
        parts.append(place(0.0, -d / 2.0 - 0.05, dz, w * 1.01, 0.13, h * 0.16))
    if hero:
        for sign in (-1, 1):
            parts.append(place(sign * w * 0.42, -d / 2.0 - 0.05, 0.0, w * 0.08, 0.13, h * 0.94))
    return parts


def fit_width(obj, max_width):
    """Reduce el rótulo de forma uniforme si no cabe en la placa."""
    width = obj.dimensions.x
    if width > max_width:
        select_only(obj)
        factor = max_width / width
        obj.scale = (factor, factor, factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


# --- Piezas -------------------------------------------------------------------------------------

def build_kiosk(M):
    """El puesto: masa de ladrillo con el hueco del mostrador y la puerta de servicio."""
    parts = []
    kiosk = box("kiosk", (KX * 2.0, KY1 - KY0, KZ), (0.0, (KY0 + KY1) / 2.0, KZ / 2.0), M["brick"])
    center_x = (COUNTER_X[0] + COUNTER_X[1]) / 2.0
    counter_cut = box(
        "counter_cut",
        (COUNTER_X[1] - COUNTER_X[0], 1.8, COUNTER_Z[1] - COUNTER_Z[0]),
        (center_x, KY0 + 0.6, (COUNTER_Z[0] + COUNTER_Z[1]) / 2.0),
    )
    door_cut = box(
        "door_cut",
        (DOOR_X[1] - DOOR_X[0], 2.6, DOOR_TOP),
        ((DOOR_X[0] + DOOR_X[1]) / 2.0, KY0 + 1.0, DOOR_TOP / 2.0),
    )
    perforate(kiosk, [counter_cut, door_cut])
    parts.append(kiosk)

    # Banda de caliza en la base de la fachada, abierta en la puerta.
    for x0, x1 in ((-KX, DOOR_X[0]), (DOOR_X[1], KX)):
        parts.append(box("base_band", (x1 - x0, 0.1, 0.5), ((x0 + x1) / 2.0, KY0 - 0.05, 0.25), M["limestone"]))
    return parts


def build_parapet(M):
    """Frontón de ladrillo sobre el puesto con el rótulo en letras de caliza mirando a la calle."""
    parts = []
    parts.append(box("parapet", (KX * 2.0, 0.85, PARAPET_Z - KZ), (0.0, KY0 + 0.425, (KZ + PARAPET_Z) / 2.0), M["brick"]))
    parts.append(box("parapet_coping", (KX * 2.0 + 0.3, 1.05, 0.28), (0.0, KY0 + 0.425, PARAPET_Z + 0.14), M["limestone"]))
    parts.append(box("sign_board", (SIGN_W, 0.4, 2.25), (0.0, KY0 - 0.18, SIGN_Z), M["wood"]))
    name = letters(SIGN_TEXT, SIGN_SIZE, (0.0, KY0 - 0.33, SIGN_Z), M["limestone"], depth=0.2)
    parts.append(fit_width(name, SIGN_W - 1.0))
    return parts


def build_shutter(M):
    """Persiana metálica a medio bajar sobre el mostrador, con su caja de enrollar y sus guías."""
    parts = []
    x0, x1 = COUNTER_X
    width = x1 - x0
    center_x = (x0 + x1) / 2.0
    parts.append(box("shutter_box", (width + 0.35, 0.7, 0.62), (center_x, KY0 + 0.25, COUNTER_Z[1] + 0.3), M["metal"]))
    slats = 7
    pitch = (COUNTER_Z[1] - 0.1 - SHUTTER_BOTTOM) / slats
    for k in range(slats):
        z = SHUTTER_BOTTOM + pitch * (k + 0.5)
        parts.append(box(f"slat{k}", (width - 0.05, 0.16, pitch * 0.78), (center_x, KY0 + 0.09, z), M["metal"]))
    for x in (x0 - 0.14, x1 + 0.14):
        parts.append(
            box(
                "shutter_guide",
                (0.16, 0.28, COUNTER_Z[1] - SHUTTER_BOTTOM + 0.2),
                (x, KY0 + 0.1, (COUNTER_Z[1] + SHUTTER_BOTTOM) / 2.0),
                M["metal"],
            )
        )
    parts.append(box("shutter_bar", (width, 0.2, 0.16), (center_x, KY0 + 0.1, SHUTTER_BOTTOM - 0.02), M["metal"]))
    return parts


def build_counter(M):
    """Mostrador de tablón, estante con cajas al fondo y testero oscuro: lo que se ve bajo la persiana."""
    parts = []
    center_x = (COUNTER_X[0] + COUNTER_X[1]) / 2.0
    parts.append(box("counter", (6.7, 0.9, 0.3), (center_x, KY0 - 0.42, COUNTER_Z[0] + 0.15), M["wood"]))
    for x in (-6.2, -1.4):
        parts.append(box("counter_bracket", (0.18, 0.62, 0.26), (x, KY0 - 0.35, COUNTER_Z[0] - 0.05), M["wood"]))
    parts.append(box("shelf", (6.2, 0.9, 0.14), (center_x, KY0 + 1.05, 3.85), M["wood"]))
    parts.append(box("shelf_box_a", (1.1, 0.8, 0.7), (-5.9, KY0 + 1.0, 4.27), M["wood"]))
    parts.append(box("shelf_box_b", (0.9, 0.7, 0.6), (-4.5, KY0 + 1.05, 4.22), M["wood"]))
    parts.append(box("counter_back", (6.3, 0.12, 4.5), (center_x, KY0 + 1.48, 4.8), M["slate"]))
    return parts


def build_door(M):
    """Puerta de 2,8 × 7,0 con marco de madera y hoja abierta hacia dentro: supera al avatar de 6."""
    parts = []
    center_x = (DOOR_X[0] + DOOR_X[1]) / 2.0
    parts.append(box("door_jamb_l", (0.22, 0.32, DOOR_TOP + 0.2), (DOOR_X[0] - 0.06, KY0 - 0.12, (DOOR_TOP + 0.2) / 2.0), M["wood"]))
    parts.append(box("door_jamb_r", (0.22, 0.32, DOOR_TOP + 0.2), (DOOR_X[1] + 0.06, KY0 - 0.12, (DOOR_TOP + 0.2) / 2.0), M["wood"]))
    parts.append(box("door_head", (DOOR_X[1] - DOOR_X[0] + 0.5, 0.32, 0.24), (center_x, KY0 - 0.12, DOOR_TOP + 0.12), M["wood"]))
    parts.append(box("door_leaf", (0.14, 2.3, DOOR_TOP - 0.2), (DOOR_X[0] + 0.22, KY0 + 1.18, (DOOR_TOP - 0.2) / 2.0), M["wood"]))
    for z in (1.6, 5.2):
        parts.append(box("door_hinge", (0.3, 0.12, 0.14), (DOOR_X[0] + 0.07, KY0 + 1.16, z), M["metal"]))
    parts.append(box("door_handle", (0.12, 0.1, 0.34), (DOOR_X[0] + 0.36, KY0 + 2.1, 3.6), M["metal"]))
    parts.append(box("door_back", (DOOR_X[1] - DOOR_X[0] + 0.1, 0.12, DOOR_TOP), (center_x, KY0 + 2.28, DOOR_TOP / 2.0), M["slate"]))
    return parts


def build_notice(M):
    """Tablón de avisos de pizarra en el machón entre el mostrador y la puerta."""
    parts = []
    parts.append(box("notice_frame", (1.7, 0.12, 1.3), (1.1, KY0 - 0.06, 4.9), M["wood"]))
    parts.append(box("notice_board", (1.5, 0.06, 1.1), (1.1, KY0 - 0.14, 4.9), M["slate"]))
    return parts


def build_awning(M):
    """Lona a rayas con faldón, postes y cabios: el toldo que hace leer mercado desde lejos."""
    parts = []
    x0, x1 = -AWN_X, AWN_X
    width = (x1 - x0) / PANELS
    for k in range(PANELS):
        xc = x0 + width * (k + 0.5)
        mat = M["fabric_rojo"] if k % 2 == 0 else M["fabric_crema"]
        parts.append(slab(f"canvas{k}", xc, KY0, AWN_Z_WALL, AWN_EDGE_Y, AWN_EDGE_Z, width + 0.02, 0.1, mat))
        parts.append(box(f"valance{k}", (width + 0.02, 0.1, 0.78), (xc, AWN_EDGE_Y - 0.02, AWN_EDGE_Z - 0.39), mat))

    parts.append(box("awn_wall_beam", (AWN_X * 2.0 + 0.4, 0.26, 0.26), (0.0, KY0 - 0.1, AWN_Z_WALL - 0.05), M["wood"]))
    parts.append(box("awn_edge_beam", (AWN_X * 2.0 + 0.4, 0.26, 0.26), (0.0, AWN_EDGE_Y, AWN_EDGE_Z - 0.03), M["wood"]))
    for x in (-6.0, -2.0, 2.0, 6.0):
        parts.append(slab(f"rafter{x}", x, KY0, AWN_Z_WALL - 0.11, AWN_EDGE_Y, AWN_EDGE_Z - 0.11, 0.18, 0.16, M["wood"]))
    for x in (-AWN_X + 0.05, AWN_X - 0.05):
        parts.append(box("awn_post", (0.34, 0.34, AWN_EDGE_Z), (x, AWN_EDGE_Y, AWN_EDGE_Z / 2.0), M["wood"]))
    return parts


def build_lantern(M):
    """Farol de hierro colgado de la viga de borde de la lona: armadura oscura y vidrios de caliza."""
    parts = []
    x, y = -7.2, AWN_EDGE_Y + 0.06
    top = AWN_EDGE_Z - 0.02
    parts.append(box("lantern_rod", (0.09, 0.09, 0.52), (x, y, top - 0.26), M["metal"]))
    parts.append(box("lantern_plate", (0.92, 0.92, 0.14), (x, y, top - 0.58), M["slate"]))
    for dx, dy in ((-0.41, -0.41), (0.41, -0.41), (0.41, 0.41), (-0.41, 0.41)):
        parts.append(box("lantern_post", (0.1, 0.1, 1.15), (x + dx, y + dy, top - 1.24), M["slate"]))
    for dx, dy, sx, sy in ((0.0, -0.36, 0.72, 0.06), (0.0, 0.36, 0.72, 0.06), (-0.36, 0.0, 0.06, 0.72), (0.36, 0.0, 0.06, 0.72)):
        parts.append(box("lantern_pane", (sx, sy, 1.0), (x + dx, y + dy, top - 1.24), M["limestone"]))
    parts.append(box("lantern_band", (0.78, 0.78, 0.07), (x, y, top - 1.24), M["slate"]))
    parts.append(box("lantern_base", (0.9, 0.9, 0.12), (x, y, top - 1.87), M["slate"]))
    parts.append(cone("lantern_finial", 0.2, 0.26, (x, y, top - 2.06), M["slate"], 4, True))
    return parts


def build_crates(M):
    """Cajas apiladas en los dos patios y sobre el mostrador: el otro rasgo del puesto."""
    parts = []
    stack = [
        ((3.2, 2.6, 2.6), (-12.4, -6.4, 1.3), 4.0, True),
        ((2.7, 2.2, 2.2), (-12.3, -6.5, 3.7), -3.0, True),
        ((2.1, 1.7, 1.6), (-12.2, -6.6, 5.6), 7.0, True),
        ((2.0, 1.7, 1.7), (-10.5, -7.9, 0.85), 18.0, True),
        ((2.4, 2.0, 2.0), (13.4, -1.0, 1.0), 4.0, False),
        ((2.0, 1.7, 1.7), (13.3, -1.1, 2.85), -8.0, False),
        ((1.6, 1.1, 1.0), (-5.6, -6.75, 3.4), 8.0, False),
        ((1.2, 0.9, 0.9), (-2.2, -6.75, 3.35), -10.0, False),
        ((1.8, 1.5, 1.4), (2.4, -0.2, 9.74), 14.0, False),
    ]
    for size, loc, yaw, hero in stack:
        parts.extend(crate("crate", size, loc, yaw, M["wood"], hero=hero))
    return parts


def build_side_stall(M):
    """Puesto auxiliar del patio derecho: mesa de tablón, dos cajas y un tonel."""
    parts = []
    parts.append(box("side_table", (2.8, 1.5, 0.22), (12.2, -6.0, 2.45), M["wood"]))
    for dx, dy in ((-1.15, -0.55), (1.15, -0.55), (1.15, 0.55), (-1.15, 0.55)):
        parts.append(box("side_leg", (0.2, 0.2, 2.34), (12.2 + dx, -6.0 + dy, 1.17), M["wood"]))
    parts.extend(crate("side_crate", (1.5, 1.1, 1.0), (12.0, -6.2, 3.06), 8.0, M["wood"]))
    parts.append(cylinder("barrel", 0.72, 1.5, (14.4, -8.0, 0.75), M["wood"], 10, True))
    parts.append(cylinder("barrel_hoop", 0.76, 0.12, (14.4, -8.0, 1.15), M["metal"], 10, False))
    return parts


def build_kiosk_roof(M):
    """Cubierta plana del puesto: pizarra, tanque de agua sobre patas, respiradero y una caja guardada."""
    parts = []
    parts.append(box("kiosk_deck", (KX * 2.0 + 0.2, (KY1 - KY0) - 0.9, 0.24), (0.0, -1.95, KZ + 0.12), M["slate"]))
    tx, ty = 5.2, -0.7
    for dx, dy in ((-0.82, -0.82), (0.82, -0.82), (0.82, 0.82), (-0.82, 0.82)):
        parts.append(box("tank_leg", (0.15, 0.15, 0.8), (tx + dx, ty + dy, KZ + 0.64), M["metal"]))
    parts.append(cylinder("tank", 1.2, 1.9, (tx, ty, KZ + 1.99), M["metal"], 12, True))
    parts.append(cone("tank_lid", 1.34, 0.34, (tx, ty, KZ + 3.11), M["metal"], 8))
    parts.append(box("tank_pipe", (0.16, 0.16, 1.1), (tx + 0.82, ty, KZ + 0.79), M["metal"]))
    parts.append(box("roof_vent", (0.24, 0.24, 1.0), (-1.8, 0.8, KZ + 0.74), M["metal"]))
    parts.append(box("roof_vent_cap", (0.5, 0.5, 0.12), (-1.8, 0.8, KZ + 1.26), M["metal"]))
    return parts


def build_house(M):
    """Casa del fondo: ladrillo, tejado a dos aguas de pizarra, hastiales, alero y bajante."""
    parts = []
    middle_y = (BY0 + BY1) / 2.0
    parts.append(box("house", (BX * 2.0, BY1 - BY0, BZ), (0.0, middle_y, BZ / 2.0), M["brick"]))
    parts.append(slab("roof_front", 0.0, BY0, BZ, RIDGE_Y, RIDGE_Z, BX * 2.0 + 0.3, 0.3, M["slate"]))
    parts.append(slab("roof_back", 0.0, BY1, BZ, RIDGE_Y, RIDGE_Z, BX * 2.0 + 0.3, 0.3, M["slate"]))
    parts.append(box("ridge", (BX * 2.0 + 0.4, 0.55, 0.34), (0.0, RIDGE_Y, RIDGE_Z + 0.1), M["slate"]))
    for x0, x1 in ((-BX, -BX + 0.6), (BX - 0.6, BX)):
        parts.append(prism("gable", [(BY0, BZ), (BY1, BZ), (RIDGE_Y, RIDGE_Z)], x0, x1, M["brick"]))
    for y in (BY0, BY1):
        parts.append(box("eave_drip", (BX * 2.0 + 0.4, 0.5, 0.32), (0.0, y, BZ - 0.06), M["limestone"]))
    # Hiladas de pizarra: el tejado se ve de lleno desde la cámara del juego y no puede ser un plano liso.
    slant = (RIDGE_Z - BZ) / (RIDGE_Y - BY0)
    for y0 in (1.75, 2.65, 3.55, 4.35):
        z0 = BZ + (y0 - BY0) * slant
        parts.append(slab(f"batten{y0}", 0.0, y0, z0 + 0.24, y0 + 0.26, z0 + 0.24 + 0.26 * slant, BX * 2.0 - 0.1, 0.14, M["slate"]))
    for y0 in (5.75, 7.05):
        z0 = BZ + (BY1 - y0) * slant
        parts.append(slab(f"batten_back{y0}", 0.0, y0, z0 + 0.24, y0 - 0.26, z0 + 0.24 + 0.26 * slant, BX * 2.0 - 0.1, 0.14, M["slate"]))

    # Ventana con persiana metálica a medio bajar en el patio izquierdo.
    wx = -14.4
    parts.append(box("win_glass", (2.0, 0.14, 2.4), (wx, BY0 - 0.04, 4.9), M["glass"]))
    parts.append(box("win_sill", (2.4, 0.5, 0.24), (wx, BY0 - 0.1, 3.58), M["limestone"]))
    parts.append(box("win_head", (2.4, 0.4, 0.22), (wx, BY0 - 0.1, 6.2), M["limestone"]))
    for k in range(3):
        parts.append(box(f"win_slat{k}", (1.9, 0.14, 0.3), (wx, BY0 - 0.15, 5.26 + k * 0.34), M["metal"]))

    # Bajante de acero en la esquina derecha.
    parts.append(cylinder("downpipe", 0.16, 10.6, (15.1, BY0 - 0.16, 5.3), M["metal"], 8, True))
    for z in (2.6, 7.4):
        parts.append(box("pipe_bracket", (0.3, 0.24, 0.14), (15.1, BY0 - 0.06, z), M["metal"]))

    # Portón de carga sobre el puesto y viga de izar con su polea.
    parts.append(box("loading_door", (4.6, 0.3, 2.0), (-1.5, BY0 - 0.14, 9.95), M["wood"]))
    parts.append(box("loading_strap", (4.4, 0.06, 0.14), (-1.5, BY0 - 0.31, 10.4), M["metal"]))
    parts.append(box("hoist_beam", (0.32, 2.6, 0.32), (-1.5, BY0 - 1.3, 11.35), M["wood"]))
    parts.append(box("hoist_block", (0.34, 0.34, 0.4), (-1.5, BY0 - 2.4, 11.05), M["metal"]))
    parts.append(box("hoist_chain", (0.07, 0.07, 0.9), (-1.5, BY0 - 2.4, 10.4), M["metal"]))
    parts.append(box("hoist_hook", (0.22, 0.22, 0.16), (-1.5, BY0 - 2.4, 9.94), M["metal"]))
    # Escotilla de acceso a la cubierta, junto a la chimenea.
    parts.append(box("roof_hatch", (1.8, 1.8, 0.55), (11.0, 2.5, 12.35), M["slate"]))
    parts.append(box("roof_hatch_lid", (2.0, 2.0, 0.12), (11.0, 2.5, 12.68), M["metal"]))

    # Chimenea de ladrillo con caperuza de acero y dos respiraderos sobre el faldón.
    parts.append(box("chimney", (1.4, 1.4, 1.6), (7.0, 4.3, 12.75), M["brick"]))
    parts.append(box("chimney_cap", (1.72, 1.72, 0.22), (7.0, 4.3, 13.66), M["metal"]))
    for x, y in ((-8.6, 2.7), (1.8, 3.6)):
        base_z = BZ + (y - BY0) * (RIDGE_Z - BZ) / (RIDGE_Y - BY0)
        parts.append(box("flue", (0.28, 0.28, 0.95), (x, y, base_z + 0.35), M["metal"]))
        parts.append(box("flue_cap", (0.5, 0.5, 0.12), (x, y, base_z + 0.86), M["metal"]))
    # Lucernario del faldón delantero: el tejado se ve desde la cámara del juego.
    parts.append(slab("skylight_curb", -4.5, 2.05, BZ + 0.5, 3.35, BZ + 1.09, 3.0, 0.3, M["slate"]))
    parts.append(slab("skylight_glass", -4.5, 2.2, BZ + 0.66, 3.2, BZ + 1.11, 2.6, 0.12, M["glass"]))
    return parts


def build_house_band(M):
    """Zócalo de caliza de la casa del fondo en los dos patios."""
    parts = []
    for x0, x1 in ((-BX, -KX), (KX, BX)):
        parts.append(box("house_band", (x1 - x0, 0.12, 0.55), ((x0 + x1) / 2.0, BY0 - 0.06, 0.275), M["limestone"]))
    return parts


def build_body(M):
    parts = []
    parts.extend(build_kiosk(M))
    parts.extend(build_parapet(M))
    parts.extend(build_shutter(M))
    parts.extend(build_counter(M))
    parts.extend(build_door(M))
    parts.extend(build_notice(M))
    parts.extend(build_awning(M))
    parts.extend(build_lantern(M))
    parts.extend(build_crates(M))
    parts.extend(build_side_stall(M))
    parts.extend(build_kiosk_roof(M))
    parts.extend(build_house(M))
    parts.extend(build_house_band(M))
    return parts


def build_lod(M):
    """LOD1 dibujado a mano: una sola malla, un solo material y la mitad de triángulos.

    `lod_of` decima y une, pero el resultado conserva varios materiales y, con tanta caja, no baja del
    50 %. Aquí se guarda solo la masa: puesto, frontón, lona, casa y sus cubiertas.
    """
    parts = []
    parts.append(box("lod_kiosk", (KX * 2.0, KY1 - KY0, KZ), (0.0, (KY0 + KY1) / 2.0, KZ / 2.0)))
    parts.append(box("lod_parapet", (KX * 2.0, 0.85, PARAPET_Z - KZ), (0.0, KY0 + 0.425, (KZ + PARAPET_Z) / 2.0)))
    parts.append(box("lod_sign", (SIGN_W, 0.4, 2.25), (0.0, KY0 - 0.18, SIGN_Z)))
    parts.append(box("lod_house", (BX * 2.0, BY1 - BY0, BZ), (0.0, (BY0 + BY1) / 2.0, BZ / 2.0)))
    parts.append(slab("lod_roof_front", 0.0, BY0, BZ, RIDGE_Y, RIDGE_Z, BX * 2.0 + 0.3, 0.3))
    parts.append(slab("lod_roof_back", 0.0, BY1, BZ, RIDGE_Y, RIDGE_Z, BX * 2.0 + 0.3, 0.3))
    parts.append(box("lod_ridge", (BX * 2.0, 0.55, 0.34), (0.0, RIDGE_Y, RIDGE_Z + 0.1)))
    parts.append(slab("lod_canvas", 0.0, KY0, AWN_Z_WALL, AWN_EDGE_Y, AWN_EDGE_Z, AWN_X * 2.0, 0.1))
    parts.append(box("lod_valance", (AWN_X * 2.0, 0.1, 0.52), (0.0, AWN_EDGE_Y, AWN_EDGE_Z - 0.26)))
    for x in (-AWN_X + 0.05, AWN_X - 0.05):
        parts.append(box("lod_post", (0.34, 0.34, AWN_EDGE_Z), (x, AWN_EDGE_Y, AWN_EDGE_Z / 2.0)))
    parts.append(box("lod_counter", (6.7, 0.9, 0.6), ((COUNTER_X[0] + COUNTER_X[1]) / 2.0, KY0 - 0.42, COUNTER_Z[0] + 0.3)))
    parts.append(box("lod_shutter", (6.3, 0.2, 2.1), ((COUNTER_X[0] + COUNTER_X[1]) / 2.0, KY0 + 0.1, 5.9)))
    parts.append(box("lod_chimney", (1.4, 1.4, 1.9), (7.0, 4.3, 12.9)))
    parts.append(box("lod_tank", (2.6, 2.6, 2.1), (5.2, -0.7, KZ + 1.9)))
    for yaw, loc, size in (
        (6.0, (-13.0, -6.3, 1.3), (3.2, 2.6, 2.6)),
        (12.0, (-12.8, -6.5, 3.6), (2.7, 2.2, 2.2)),
        (4.0, (13.4, -1.0, 1.0), (2.4, 2.0, 2.0)),
        (10.0, (-5.6, -6.75, 3.3), (1.6, 1.1, 0.9)),
    ):
        parts.append(box("lod_crate", size, loc))
        parts[-1].rotation_euler = (0.0, 0.0, math.radians(yaw))
    for part in parts:
        select_only(part)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mesh = join(parts, "market_LOD1")
    mesh.data.materials.clear()
    mesh.data.materials.append(M["brick"])
    uv_unwrap(mesh)
    return mesh


def group(parts, store):
    """Une las piezas en una malla por material y color. En Roblox cada malla lleva un material."""
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        for member in members:
            select_only(member)
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        rbx, suffix, rgb = RBX[key]
        name = f"market_{rbx.lower()}{suffix}"
        # Unir un solo objeto no hace nada y Blender avisa «No mesh data to join»: se salta.
        mesh = join(members, name) if len(members) > 1 else members[0]
        mesh.name = name
        # El recorte booleano añade un hueco de material vacío: la pieza debe quedar con material único.
        for polygon in mesh.data.polygons:
            index = polygon.material_index
            if index >= len(mesh.data.materials) or mesh.data.materials[index] is None:
                polygon.material_index = 0
        for slot in reversed([i for i, material in enumerate(mesh.data.materials) if material is None]):
            mesh.data.materials.pop(index=slot)
        uv_unwrap(mesh)
        materials = {m.name for m in mesh.data.materials if m is not None}
        if len(mesh.data.materials) != 1 or len(materials) != 1:
            raise RuntimeError(f"{name} tiene {len(mesh.data.materials)} huecos de material: {materials}")
        store.append({"key": name, "level": 0, "material": rbx, "rgb": rgb, "obj": mesh})


def bounds(objects):
    """Límites en studs con las mallas en coordenadas de escena."""
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
        copy.location = (x, y, 0.0)
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


def street_scene(M):
    """Solar, acera y calzada, solo para los renders: la calle no va en el modelo."""
    box("lot", (150, 22, 0.2), (0, 0, -0.1), M["pavement"])
    box("walk", (150, SIDEWALK, 0.3), (0, -11 - SIDEWALK / 2.0, 0.0), M["pavement"])
    box("road", (150, 40, 0.2), (0, -18 - 20.0, -0.1), M["asphalt"])
    box("kerb", (150, 0.5, 0.36), (0, -18.25, 0.0), M["limestone"])
    for k in range(-7, 8):
        box("dash", (4.2, 0.35, 0.05), (k * 9.0, -38, 0.06), M["cream"])
    lights_and_world()


def hide_all():
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

    # La casilla no tiene niveles: todas las piezas van en el cuerpo, a nivel 0.
    group(build_body(M), pieces)

    objects = [p["obj"] for p in pieces]
    total = sum(count(o) for o in objects)
    medidas = bounds(objects)

    # LOD1 dibujado a mano: una malla, un material y muy por debajo de la mitad del total.
    lod = build_lod(M)
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "market_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "prefijo": "market",
        "niveles": 1,
        "huella": {"ancho": WIDTH, "fondo": DEPTH, "vuelo_maximo_y": -10.0},
        "medidas": medidas,
        "altura_maxima_permitida": MAX_HEIGHT,
        "avatar_de_referencia": AVATAR,
        "puerta": {"ancho": round(DOOR_X[1] - DOOR_X[0], 2), "alto": DOOR_TOP},
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
        "total_triangulos": total,
        "presupuesto_triangulos": TRIANGLE_BUDGET,
        "lod1": {
            "triangulos": lod_tris,
            "porcentaje_del_total": round(100.0 * lod_tris / total, 1),
            "mallas": 1,
            "material": "Brick",
            "rgb": "B0664A",
        },
        "referencia_cine_lux_nivel5": CINE_LUX_L5_TRIANGLES,
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("MERCADO_NEGRO_STATS", json.dumps({"total": total, "lod1": lod_tris, "medidas": medidas}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2.0:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if medidas["alto_maximo_sobre_suelo"] > MAX_HEIGHT:
        raise RuntimeError(f"Altura {medidas['alto_maximo_sobre_suelo']} > {MAX_HEIGHT}")
    if medidas["frente"] < -10.0:
        raise RuntimeError(f"Hay piezas delante de y = -10: {medidas['frente']}")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "mercado-negro.blend"))

    place(objects, 0.0, 0.0)
    street_scene(M)
    render(scene, camera("frontal", (0.0, -46.0, 10.0), (0.0, -1.0, 6.6), 40), f"{RENDER_SUBDIR}/mercado-negro-frontal.png")
    render(scene, camera("aereo", (0.0, -50.0, 45.0), (0.0, 2.0, 4.5), 42), f"{RENDER_SUBDIR}/mercado-negro-aereo.png")

    # Comparación: el puesto junto a la figura de 6 y a un bloque de la Bodega (13), a la misma distancia.
    hide_all()
    box("ground", (260, 90, 0.4), (0, 0, -0.2), M["pavement"])
    place(objects, -17.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (19.0, 0.0, 6.5), M["block"])
    box("figura_6", (1.6, 1.2, AVATAR), (-6.5, -10.9, AVATAR / 2.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (2.0, -80.0, 21.0), (2.0, 0.0, 7.0), 40), f"{RENDER_SUBDIR}/mercado-negro-comparacion.png")
    print("MERCADO_NEGRO_DONE")


if __name__ == "__main__":
    main()

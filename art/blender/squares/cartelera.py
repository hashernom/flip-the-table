"""Cartelera: la casilla de la Cartelera de la Suerte, modelada desde cero.

Una pantalla gigante de ciudad sobre una torre de acero, con un cuerpo bajo de ladrillo y caliza que
alberga el acceso, las carteleras de calle y el rótulo en letras 3D. Medidas en studs (1 unidad de
Blender = 1 stud): huella 32 × 18, el frente da a -Y y el origen está en el centro de la base, con
z = 0 a ras de suelo. Es una casilla, no una propiedad: no tiene niveles ni añadidos, así que todas
las piezas van en el cuerpo y la altura máxima es 28,6.

La pantalla es una malla plana aparte, con la clave billboard_screen, para que la escena proyecte en
ella: 26 × 11, inclinada 5° y montada alta sobre la torre, de modo que la cámara alta del juego siga
viendo la cubierta por debajo. Todo lo demás la sostiene: bastidor, brazos, puntales, torre y placas
de anclaje. Nada flota y el rótulo va por encima de la puerta y del toldo, a 9,45.

Sigue la estructura de art/blender/buildings/cobre/barberia-morro.py: helpers importados de
art/blender/slice/build_cine_lux.py, una malla por material y color, LOD1 decimado, stats.json y
renders de revisión. Sin neón, sin fichas, sin ruletas: es una pantalla municipal, no un casino.

Salidas, en art/blender/squares/:
  cartelera.blend                 escena de revisión (no se versiona)
  cartelera/billboard_<material>.fbx, billboard_screen.fbx, billboard_LOD1.fbx y stats.json
Y en art/render/squares/cartelera/: cartelera-frontal.png, cartelera-aereo.png y
cartelera-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/squares/cartelera.py
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "cartelera")
RENDER_SUBDIR = "squares/cartelera"
sys.path.insert(0, SLICE)

# Helpers compartidos con los edificios ya en el juego (no se copian: se importan).
import build_cine_lux  # noqa: E402
from build_cine_lux import (  # noqa: E402
    box,
    camera,
    count,
    flat,
    join,
    lamp,
    letters,
    lod_of,
    render,
    select_only,
    textured,
    tree,
    uv_unwrap,
)

# El LOD1 tiene que quedar por debajo de la mitad, no en la mitad exacta.
build_cine_lux.LOD_RATIO = 0.42

# --------------------------------------------------------------------------------------------
# Solar. Huella 32 × 18; el toldo es el único vuelo y llega a y = -9,85.
# --------------------------------------------------------------------------------------------
WIDTH = 32.0
DEPTH = 18.0
FRONT = -DEPTH / 2.0  # -9
BACK = DEPTH / 2.0  # 9
WALL_T = 0.6

# Cuerpo: sala de la cartelera delante y almacén detrás, más bajo, para que la cámara alta lea
# dos volúmenes y no una caja.
HALL_BACK = 4.0
HALL_H = 10.6
ANNEX_Y0, ANNEX_Y1 = 4.0, 9.0
ANNEX_HALF = 15.0
ANNEX_H = 7.2

# Huecos de la fachada.
DOOR_W = 2.8
DOOR_H = 7.0
CASE_X = 8.6  # centro de cada cartelera de calle
CASE_W = 4.4
CASE_Z0 = 2.8
CASE_Z1 = 6.0
SIDE_DOOR_Y = (-6.5, -3.9)
SIDE_DOOR_H = 6.6
SIDE_WIN_Y = (-4.2, -0.9)
SIDE_WIN_Z = (5.2, 7.0)

# Rótulo: banda oscura con «CARTELERA» en letras de caliza, sobre la marquesina.
SIGN_Z0, SIGN_Z1 = 8.3, 10.6
SIGN_Z = (SIGN_Z0 + SIGN_Z1) / 2.0
SIGN_W = 24.0
LETTER_SIZE = 2.4

# Pantalla: plana, aparte, con la clave billboard_screen. Va alta, sobre la torre, para que la
# cámara alta del juego siga viendo la cubierta por debajo de ella.
TILT = math.radians(5.0)
SINT, COST = math.sin(TILT), math.cos(TILT)
SCREEN_W = 26.0
SCREEN_H = 11.0
SCREEN_C = (0.0, -8.47, 21.42)
SCREEN_DEPTH = 0.4  # canto del bastidor que la sostiene

# Torre de acero.
LEG_X = 15.2
LEG_Y_FRONT = -1.2
LEG_Y_BACK = 2.6
LEG_SIZE = 0.7
ROOF_Z = HALL_H
LEG_TOP = 28.6
TOP_RING_Z = 28.25
MID_Z = 19.6
ARM_Z = (17.6, 21.4, 25.2)
ARM_X = 12.4

# Escena de render.
STREET_WIDTH = 34.0
TRIANGLE_BUDGET = 3000
MAX_HEIGHT = 30.0
FRONT_LIMIT = -10.0
CINE_LUX_L5_TRIANGLES = 3042

# Material de Roblox, clave de la pieza y RGB de cada material de Blender.
RBX = {
    "brick": ("Brick", "billboard_brick", "B0664A"),
    "limestone": ("Limestone", "billboard_limestone", "D2C9B4"),
    "slate": ("Slate", "billboard_slate", "4A4E54"),
    "glass": ("Glass", "billboard_glass", "2E4A63"),
    "metal": ("Metal", "billboard_metal", "A8AEB4"),
    "wood": ("Wood", "billboard_wood", "6B4A2E"),
    "screen": ("SmoothPlastic", "billboard_screen", "2E3338"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "metal": flat("metal", "A8AEB4", 0.28, 0.8),
        "wood": flat("wood", "6B4A2E", 0.7),
        "screen": flat("screen", "2E3338", 0.36),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "avatar": flat("avatar", "6E747C", 0.8),
    }


# --------------------------------------------------------------------------------------------
# Piezas propias que no están en los helpers compartidos.
# --------------------------------------------------------------------------------------------
def cylinder(name, radius, depth, location, mat, verts=12):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts,
        radius=radius,
        depth=depth,
        end_fill_type="NGON",
        location=location,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def beam_yz(name, x, start, end, width, depth, mat):
    """Viga en el plano YZ, a x fijo: se usa para tirantes, puntales y la pata trasera de la torre."""
    y0, z0 = start
    y1, z1 = end
    dy, dz = y1 - y0, z1 - z0
    length = math.hypot(dy, dz)
    obj = box(name, (width, length, depth), (x, (y0 + y1) / 2, (z0 + z1) / 2), mat)
    obj.rotation_euler = (math.atan2(dz, dy), 0, 0)
    select_only(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return obj


def plane_point(du, dv, dn):
    """Punto del plano de la pantalla: du a la derecha, dv hacia arriba, dn hacia la calle."""
    return (
        SCREEN_C[0] + du,
        SCREEN_C[1] + dv * SINT - dn * COST,
        SCREEN_C[2] + dv * COST + dn * SINT,
    )


def screen_y(z):
    """Altura del plano de la pantalla en y, para que los brazos mueran justo detrás."""
    return SCREEN_C[1] + (z - SCREEN_C[2]) * math.tan(TILT)


def frame_box(name, du_size, dv_size, dn_size, du, dv, dn, mat):
    """Caja dentro del plano de la pantalla: el bastidor, el capó y el respaldo van inclinados con ella."""
    obj = box(name, (du_size, dn_size, dv_size), plane_point(du, dv, dn), mat)
    obj.rotation_euler = (-TILT, 0, 0)
    select_only(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return obj


def fit_width(obj, max_width):
    """Reduce el rótulo de forma uniforme si no cabe en la banda."""
    width = obj.dimensions.x
    if width > max_width:
        select_only(obj)
        factor = max_width / width
        obj.scale = (factor, factor, factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


# --------------------------------------------------------------------------------------------
# Cuerpo bajo. Los huecos se arman con paños de verdad: ni booleanos ni caras raras.
# --------------------------------------------------------------------------------------------
def build_hall(M):
    """Sala de ladrillo con zócalo y pilastras de caliza, puerta alta, dos carteleras de calle, marquesina
    de acero y la banda del rótulo con «CARTELERA» en letras 3D."""
    parts = []
    y_wall = FRONT + WALL_T / 2
    inner = CASE_X - CASE_W / 2  # 6,4
    outer = CASE_X + CASE_W / 2  # 10,8

    # Muro frontal por paños. El de la izquierda y el de la derecha acaban en la pilastra.
    for x0, x1 in ((-15.4, -outer), (-inner, -DOOR_W / 2), (DOOR_W / 2, inner), (outer, 15.4)):
        parts.append(box("front_wall", (x1 - x0, WALL_T, HALL_H), ((x0 + x1) / 2, y_wall, HALL_H / 2), M["brick"]))
    parts.append(box("front_door_head", (DOOR_W, WALL_T, HALL_H - DOOR_H), (0, y_wall, (DOOR_H + HALL_H) / 2), M["brick"]))
    for sign in (-1, 1):
        parts.append(box("front_case_head", (CASE_W, WALL_T, HALL_H - CASE_Z1), (sign * CASE_X, y_wall, (CASE_Z1 + HALL_H) / 2), M["brick"]))
        parts.append(box("front_case_sill", (CASE_W, WALL_T, CASE_Z0), (sign * CASE_X, y_wall, CASE_Z0 / 2), M["brick"]))

    # Costado este: hueco de la ventana de la sala de control, armado con los cuatro paños.
    win_y0, win_y1 = SIDE_WIN_Y
    win_z0, win_z1 = SIDE_WIN_Z
    east = [
        ("side_east_low", (0.6, 12.9, win_z0), (15.7, -2.45, win_z0 / 2)),
        ("side_east_high", (0.6, 12.9, HALL_H - win_z1), (15.7, -2.45, (win_z1 + HALL_H) / 2)),
        ("side_east_front", (0.6, win_y0 + 8.9, win_z1 - win_z0), (15.7, (win_y0 - 8.9) / 2, (win_z0 + win_z1) / 2)),
        ("side_east_back", (0.6, HALL_BACK - win_y1, win_z1 - win_z0), (15.7, (win_y1 + HALL_BACK) / 2, (win_z0 + win_z1) / 2)),
    ]
    for name, size, location in east:
        parts.append(box(name, size, location, M["brick"]))

    # Costado oeste: hueco de la puerta de servicio.
    door_y0, door_y1 = SIDE_DOOR_Y
    west = [
        ("side_west_front", (0.6, door_y0 + 8.9, HALL_H), (-15.7, (door_y0 - 8.9) / 2, HALL_H / 2)),
        ("side_west_back", (0.6, HALL_BACK - door_y1, HALL_H), (-15.7, (door_y1 + HALL_BACK) / 2, HALL_H / 2)),
        ("side_west_head", (0.6, door_y1 - door_y0, HALL_H - SIDE_DOOR_H), (-15.7, (door_y0 + door_y1) / 2, (SIDE_DOOR_H + HALL_H) / 2)),
    ]
    for name, size, location in west:
        parts.append(box(name, size, location, M["brick"]))

    parts.append(box("back_wall", (WIDTH, WALL_T, HALL_H), (0, 3.7, HALL_H / 2), M["brick"]))

    # Zócalo, pilastras de esquina y banda del rótulo.
    for sign in (-1, 1):
        parts.append(box("plinth", (15.4 - DOOR_W / 2, 0.3, 0.55), (sign * (DOOR_W / 2 + 15.4) / 2, FRONT - 0.1, 0.275), M["limestone"]))
        parts.append(box("pilaster", (1.1, 0.35, HALL_H), (sign * 15.45, FRONT - 0.12, HALL_H / 2), M["limestone"]))
    parts.append(box("sign_band", (SIGN_W, 0.45, SIGN_Z1 - SIGN_Z0), (0, FRONT - 0.175, SIGN_Z), M["slate"]))
    parts.append(fit_width(letters("CARTELERA", LETTER_SIZE, (0, FRONT - 0.47, SIGN_Z), M["limestone"], depth=0.14), 21.0))

    # Marquesina de acero sobre la puerta, con sus tirantes al muro.
    parts.append(box("canopy", (8.8, 1.0, 0.26), (0, FRONT - 0.35, 7.45), M["metal"]))
    for sign in (-1, 1):
        parts.append(beam_yz("canopy_rod", sign * 3.9, (-9.78, 7.58), (-9.0, 8.24), 0.12, 0.12, M["metal"]))

    # Puerta de entrada: 2,8 × 7,0, hojas de cristal oscuro y herraje de acero.
    parts.append(box("door_threshold", (3.0, 0.5, 0.14), (0, FRONT + 0.1, 0.07), M["limestone"]))
    parts.append(box("door_head", (3.16, 0.5, 0.2), (0, FRONT + 0.1, DOOR_H), M["metal"]))
    for sign in (-1, 1):
        parts.append(box("door_jamb", (0.18, 0.5, DOOR_H), (sign * 1.49, FRONT + 0.1, DOOR_H / 2), M["metal"]))
        parts.append(box("door_leaf", (1.32, 0.1, DOOR_H - 0.25), (sign * 0.69, FRONT + 0.42, (DOOR_H + 0.15) / 2), M["glass"]))
        parts.append(box("door_bar", (1.05, 0.1, 0.1), (sign * 0.69, FRONT + 0.34, 3.5), M["metal"]))
    parts.append(box("door_stile", (0.14, 0.16, DOOR_H - 0.25), (0, FRONT + 0.36, (DOOR_H + 0.15) / 2), M["wood"]))

    # Carteleras de calle: marco de caliza, cristal oscuro y su solera.
    for sign in (-1, 1):
        parts.append(box("case_back", (4.7, 0.35, 3.4), (sign * CASE_X, FRONT + 0.1, 4.4), M["limestone"]))
        parts.append(box("case_glass", (4.2, 0.08, 2.9), (sign * CASE_X, FRONT - 0.08, 4.4), M["glass"]))
        parts.append(box("case_sill", (4.9, 0.4, 0.18), (sign * CASE_X, FRONT - 0.02, 2.62), M["limestone"]))

    # Ventana de la sala de control, al este, y puerta de servicio, al oeste.
    parts.append(box("side_win_glass", (0.16, win_y1 - win_y0 - 0.1, win_z1 - win_z0 - 0.1), (15.86, (win_y0 + win_y1) / 2, (win_z0 + win_z1) / 2), M["glass"]))
    parts.append(box("side_win_head", (0.14, win_y1 - win_y0, 0.16), (15.93, (win_y0 + win_y1) / 2, win_z1 - 0.08), M["metal"]))
    parts.append(box("side_win_sill", (0.2, win_y1 - win_y0, 0.2), (15.9, (win_y0 + win_y1) / 2, win_z0 - 0.02), M["limestone"]))

    parts.append(box("side_door_leaf", (0.14, 2.5, SIDE_DOOR_H - 0.1), (-15.78, (door_y0 + door_y1) / 2, (SIDE_DOOR_H - 0.1) / 2), M["wood"]))
    for y in (door_y0 + 0.09, door_y1 - 0.09):
        parts.append(box("side_door_jamb", (0.28, 0.18, SIDE_DOOR_H), (-15.86, y, SIDE_DOOR_H / 2), M["metal"]))
    parts.append(box("side_door_head", (0.28, door_y1 - door_y0, 0.2), (-15.86, (door_y0 + door_y1) / 2, SIDE_DOOR_H - 0.1), M["metal"]))
    parts.append(box("side_door_sill", (0.2, door_y1 - door_y0, 0.14), (-15.9, (door_y0 + door_y1) / 2, 0.07), M["limestone"]))
    return parts


def build_roof(M):
    """Cubierta de la sala: losa, pretil y todo lo que ve la cámara alta del juego. Nada sobresale del
    solar y nada queda volando: cada pieza apoya en la losa."""
    parts = []
    parts.append(box("roof_deck", (31.2, 12.6, 0.3), (0, -2.55, ROOF_Z - 0.15), M["slate"]))
    for name, size, location in (
        ("parapet_front", (32.0, 0.45, 0.55), (0, -8.75, ROOF_Z + 0.275)),
        ("parapet_back", (32.0, 0.4, 0.55), (0, 3.75, ROOF_Z + 0.275)),
        ("parapet_east", (0.45, 12.6, 0.55), (15.7, -2.55, ROOF_Z + 0.275)),
        ("parapet_west", (0.45, 12.6, 0.55), (-15.7, -2.55, ROOF_Z + 0.275)),
    ):
        parts.append(box(name, size, location, M["slate"]))
    for name, size, location in (
        ("coping_front", (32.0, 0.6, 0.14), (0, -8.75, ROOF_Z + 0.62)),
        ("coping_back", (32.0, 0.55, 0.14), (0, 3.75, ROOF_Z + 0.62)),
        ("coping_east", (0.6, 13.35, 0.14), (15.7, -2.55, ROOF_Z + 0.62)),
        ("coping_west", (0.6, 13.35, 0.14), (-15.7, -2.55, ROOF_Z + 0.62)),
    ):
        parts.append(box(name, size, location, M["limestone"]))

    # Lucernario de la sala, delante de la torre.
    parts.append(box("skylight_curb", (3.8, 2.6, 0.5), (-7.0, -5.4, ROOF_Z + 0.25), M["slate"]))
    parts.append(box("skylight_glass", (3.4, 2.2, 0.1), (-7.0, -5.4, ROOF_Z + 0.55), M["glass"]))
    for x in (-7.8, -6.2):
        parts.append(box("skylight_rib", (0.12, 2.3, 0.12), (x, -5.4, ROOF_Z + 0.66), M["slate"]))

    # Climatización: tres equipos con su bancada y su rejilla, y el hueco de acceso.
    for x, y, body in ((9.0, -5.8, (3.1, 2.3, 1.7)), (-10.6, 0.6, (2.7, 2.1, 1.5)), (11.8, -3.0, (2.0, 1.6, 1.2))):
        parts.append(box("hvac_curb", (body[0] + 0.3, body[1] + 0.3, 0.22), (x, y, ROOF_Z + 0.11), M["slate"]))
        parts.append(box("hvac_body", body, (x, y, ROOF_Z + 0.22 + body[2] / 2), M["slate"]))
        parts.append(box("hvac_fan", (body[0] - 0.8, body[1] - 0.6, 0.16), (x, y, ROOF_Z + 0.3 + body[2]), M["metal"]))
    parts.append(box("hatch_curb", (1.9, 1.9, 0.4), (12.6, 0.8, ROOF_Z + 0.2), M["slate"]))
    parts.append(box("hatch_lid", (1.7, 1.7, 0.14), (12.6, 0.8, ROOF_Z + 0.47), M["metal"]))

    # Cajas de conexión y bandejas de cables que bajan de la pantalla al edificio.
    for sign in (-1, 1):
        parts.append(box("junction_box", (2.0, 1.0, 0.7), (sign * 2.6, -7.4, ROOF_Z + 0.35), M["slate"]))
        parts.append(box("cable_tray", (0.45, 8.4, 0.2), (sign * 1.0, -3.1, ROOF_Z + 0.1), M["metal"]))

    # Depósito de agua sobre el cuerpo bajo: remata la cubierta y se lee desde la calle y desde arriba.
    for dx in (-0.65, 0.65):
        for dy in (-0.65, 0.65):
            parts.append(box("hall_tank_leg", (0.2, 0.2, 0.9), (-6.0 + dx, -1.2 + dy, ROOF_Z + 0.45), M["metal"]))
    parts.append(cylinder("hall_tank", 1.3, 1.9, (-6.0, -1.2, ROOF_Z + 0.9 + 0.95), M["slate"], 12))
    parts.append(cylinder("hall_tank_cap", 1.4, 0.12, (-6.0, -1.2, ROOF_Z + 0.9 + 1.96), M["metal"], 12))

    for x, y in ((13.4, -7.2), (-13.6, 2.2)):
        parts.append(cylinder("vent_pipe", 0.26, 1.1, (x, y, ROOF_Z + 0.55), M["metal"], 8))
    return parts


def build_annex(M):
    """Almacén trasero, más bajo, con su cubierta a la vista: depósito de agua, lucernario, rejillas y
    pretil. Es el segundo volumen que la cámara alta necesita para no leer una caja sola."""
    parts = []
    for sign in (-1, 1):
        parts.append(box("annex_wall", (0.6, ANNEX_Y1 - ANNEX_Y0, ANNEX_H), (sign * 14.7, 6.5, ANNEX_H / 2), M["brick"]))
    parts.append(box("annex_back", (2 * ANNEX_HALF, 0.6, ANNEX_H), (0, 8.7, ANNEX_H / 2), M["brick"]))
    parts.append(box("annex_roof", (29.7, 4.95, 0.25), (0, 6.5, ANNEX_H - 0.125), M["slate"]))
    for sign in (-1, 1):
        parts.append(box("annex_parapet", (0.35, 4.6, 0.5), (sign * 14.65, 6.5, ANNEX_H + 0.25), M["slate"]))
        parts.append(box("annex_coping", (0.55, 4.9, 0.12), (sign * 14.65, 6.5, ANNEX_H + 0.56), M["limestone"]))
    parts.append(box("annex_parapet_back", (29.7, 0.35, 0.5), (0, 8.65, ANNEX_H + 0.25), M["slate"]))
    parts.append(box("annex_coping_back", (30.0, 0.55, 0.12), (0, 8.65, ANNEX_H + 0.56), M["limestone"]))

    # Depósito de agua sobre cuatro patas, con su tapa.
    for dx in (-0.75, 0.75):
        for dy in (-0.75, 0.75):
            parts.append(box("tank_leg", (0.22, 0.22, 0.9), (-9.0 + dx, 6.4 + dy, ANNEX_H + 0.45), M["metal"]))
    parts.append(cylinder("tank", 1.45, 2.3, (-9.0, 6.4, ANNEX_H + 0.9 + 1.15), M["slate"], 12))
    parts.append(cylinder("tank_cap", 1.55, 0.14, (-9.0, 6.4, ANNEX_H + 0.9 + 2.37), M["metal"], 12))

    parts.append(box("annex_skylight_curb", (2.8, 1.9, 0.4), (4.0, 6.4, ANNEX_H + 0.2), M["slate"]))
    parts.append(box("annex_skylight_glass", (2.4, 1.6, 0.08), (4.0, 6.4, ANNEX_H + 0.43), M["glass"]))
    parts.append(cylinder("annex_vent", 0.24, 1.0, (11.0, 7.6, ANNEX_H + 0.5), M["metal"], 8))
    return parts


def build_tower(M):
    """Torre de acero que sostiene la pantalla: dos pórticos en A, con la pata trasera inclinada, un
    dintel arriba, tres cruces delanteras con sus brazos y dos puntales que bajan a la cubierta. Los
    brazos mueren en el bastidor: la pantalla no flota."""
    parts = []
    for sx in (-1, 1):
        parts.append(box("tower_leg", (LEG_SIZE, LEG_SIZE, LEG_TOP - ROOF_Z), (sx * LEG_X, LEG_Y_FRONT, (ROOF_Z + LEG_TOP) / 2), M["metal"]))
        parts.append(beam_yz("tower_rear", sx * LEG_X, (LEG_Y_BACK, ROOF_Z), (LEG_Y_FRONT, LEG_TOP), LEG_SIZE, LEG_SIZE, M["metal"]))
        for y in (LEG_Y_FRONT, LEG_Y_BACK):
            parts.append(box("tower_base", (1.2, 1.2, 0.3), (sx * LEG_X, y, ROOF_Z + 0.15), M["metal"]))
    # Dintel superior y costillas que atan la pata trasera con la delantera.
    parts.append(box("tower_top", (2 * LEG_X + LEG_SIZE, 0.6, 0.7), (0, LEG_Y_FRONT, TOP_RING_Z), M["metal"]))
    for sx in (-1, 1):
        parts.append(box("tower_tie", (0.5, 2.0, 0.5), (sx * LEG_X, LEG_Y_FRONT + 0.95, MID_Z), M["metal"]))
    # Tres cruces delanteras: son las que reciben los brazos de la pantalla.
    for z in ARM_Z:
        parts.append(box("cross_beam", (2 * LEG_X + LEG_SIZE, 0.5, 0.55), (0, LEG_Y_FRONT, z), M["metal"]))
        tip = screen_y(z) + 0.4
        for sx in (-1, 1):
            parts.append(box("screen_arm", (0.55, tip - LEG_Y_FRONT, 0.6), (sx * ARM_X, (LEG_Y_FRONT + tip) / 2, z), M["metal"]))
    # Dos puntales delanteros que bajan del bastidor a la cubierta: la pantalla también apoya abajo y
    # desde la calle se lee de dónde cuelga.
    for sx in (-1, 1):
        parts.append(beam_yz("screen_strut", sx * 13.4, (-2.4, ROOF_Z + 0.1), (-8.35, 15.35), 0.34, 0.34, M["metal"]))
    return parts


def build_screen(M):
    """La pantalla y su bastidor. El respaldo de pizarra, el marco de acero, el capó y los brazos de la
    torre la sujetan: no hay nada en el aire."""
    parts = []
    half_w, half_h = SCREEN_W / 2, SCREEN_H / 2
    parts.append(frame_box("screen_back", 2 * half_w + 0.9, 2 * half_h + 0.9, SCREEN_DEPTH, 0, 0, -SCREEN_DEPTH / 2 - 0.04, M["slate"]))
    parts.append(frame_box("frame_top", 2 * half_w + 1.8, 1.1, 0.9, 0, half_h + 0.55, -0.5, M["metal"]))
    parts.append(frame_box("frame_bottom", 2 * half_w + 1.8, 1.1, 0.9, 0, -half_h - 0.55, -0.5, M["metal"]))
    for sx in (-1, 1):
        parts.append(frame_box("frame_side", 0.9, 2 * half_h + 2.2, 1.0, sx * (half_w + 0.45), 0, -0.5, M["metal"]))
    parts.append(frame_box("frame_hood", 2 * half_w + 2.8, 0.3, 1.5, 0, half_h + 0.85, 0.55, M["metal"]))
    return parts


def build_screen_panel(M):
    """La pantalla: una sola cara plana de 26 × 13, con la clave billboard_screen. El juego proyecta en ella."""
    mesh = bpy.data.meshes.new("billboard_screen")
    bm = bmesh.new()
    half_w, half_h = SCREEN_W / 2, SCREEN_H / 2
    corners = ((-half_w, -half_h), (half_w, -half_h), (half_w, half_h), (-half_w, half_h))
    verts = [bm.verts.new(plane_point(du, dv, 0.0)) for du, dv in corners]
    face = bm.faces.new(verts)
    bm.normal_update()
    if face.normal.dot(Vector((0.0, -COST, SINT))) < 0:
        face.normal_flip()
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("billboard_screen", mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(M["screen"])
    return obj


def build_ladder(M):
    """Escalera de servicio sobre la pata delantera derecha, de la cubierta al anillo superior. Va
    pegada a la pata: no flota."""
    parts = []
    for x in (LEG_X - 0.3, LEG_X + 0.3):
        parts.append(box("ladder_rail", (0.14, 0.16, LEG_TOP - ROOF_Z - 1.4), (x, LEG_Y_FRONT - 0.55, (ROOF_Z + LEG_TOP) / 2 - 0.3), M["metal"]))
    for index in range(9):
        z = ROOF_Z + 1.1 + index * 1.85
        parts.append(box("ladder_rung", (0.62, 0.14, 0.1), (LEG_X, LEG_Y_FRONT - 0.55, z), M["metal"]))
    for z in (ROOF_Z + 0.9, TOP_RING_Z - 1.2):
        parts.append(box("ladder_stand", (0.25, 0.55, 0.14), (LEG_X, LEG_Y_FRONT - 0.28, z), M["metal"]))
    return parts


def group(parts, store):
    """Une todas las piezas en una malla por material y color: cada FBX lleva un material y un color."""
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        rbx, name, rgb = RBX[key]
        if len(members) > 1:
            mesh = join(members, name)
        else:
            mesh = members[0]
            mesh.name = name
            select_only(mesh)
            bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
            bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        uv_unwrap(mesh)
        materials = {m.name for m in mesh.data.materials if m is not None}
        if len(materials) != 1:
            raise RuntimeError(f"{name} tiene {len(materials)} materiales")
        store.append({"key": name, "material": rbx, "rgb": rgb, "obj": mesh})


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
        "frente_y": round(min(ys), 2),
        "fondo_y": round(max(ys), 2),
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


def street(M):
    """Tramo de calle solo para el render: la casilla del suelo la pinta el juego."""
    box("road", (260, STREET_WIDTH, 0.45), (0, -32.5, -0.24), M["asphalt"])
    box("walk_near", (260, 6.0, 0.4), (0, -12.0, -0.2), M["pavement"])
    box("walk_far", (260, 7.0, 0.4), (0, -53.0, -0.22), M["pavement"])
    box("kerb", (260, 0.4, 0.5), (0, -15.1, -0.22), M["cream"])
    box("back_lot", (220, 60, 0.3), (0, 32, -0.16), M["pavement"])
    dash = -125.0
    while dash < 125.0:
        box("dash", (5.0, 0.4, 0.05), (dash, -32.5, -0.02), M["cream"])
        dash += 11.0
    for x in (-34.0, 34.0):
        lamp(x, -15.8, M)
        tree(x, -12.4, M)
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
    parts = build_hall(M) + build_roof(M) + build_annex(M) + build_tower(M) + build_screen(M) + build_ladder(M)
    parts.append(build_screen_panel(M))

    pieces = []
    group(parts, pieces)

    objects = [piece["obj"] for piece in pieces]
    total = sum(count(obj) for obj in objects)
    sizes = bounds(objects)

    # LOD1: una sola malla y un solo material, decimado por debajo de la mitad. La pantalla no se
    # decima, porque es una sola cara: se copia tal cual y se une al resto para que el LOD siga
    # teniendo pantalla y no salga el aviso de Decimate por falta de caras.
    screen_obj = next(piece["obj"] for piece in pieces if piece["key"] == "billboard_screen")
    lod = lod_of([obj for obj in objects if obj is not screen_obj], "billboard_LOD1")
    screen_copy = screen_obj.copy()
    screen_copy.data = screen_obj.data.copy()
    screen_copy.name = "billboard_screen_lod"
    bpy.context.collection.objects.link(screen_copy)
    lod = join([lod, screen_copy], "billboard_LOD1")
    lod.data.materials.clear()
    lod.data.materials.append(M["limestone"])
    uv_unwrap(lod)
    lod_tris = count(lod)

    for piece in pieces:
        export(piece["obj"], piece["key"] + ".fbx")
    export(lod, "billboard_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "vuelos": {"frente_y": sizes["frente_y"], "limite_y": FRONT_LIMIT},
        "piezas": [
            {
                "clave": piece["key"],
                "nivel": 0,
                "material": piece["material"],
                "rgb": piece["rgb"],
                "triangulos": count(piece["obj"]),
            }
            for piece in pieces
        ],
        "pantalla": {
            "clave": "billboard_screen",
            "ancho": SCREEN_W,
            "alto": SCREEN_H,
            "inclinacion_grados": round(math.degrees(TILT), 1),
            "centro": [0.0, SCREEN_C[1], SCREEN_C[2]],
            "triangulos": count(next(piece["obj"] for piece in pieces if piece["key"] == "billboard_screen")),
        },
        "total_triangulos": total,
        "presupuesto_triangulos": TRIANGLE_BUDGET,
        "altura_maxima_permitida": MAX_HEIGHT,
        "lod1": {
            "archivo": "billboard_LOD1.fbx",
            "mallas": 1,
            "material": "Limestone",
            "rgb": "D2C9B4",
            "triangulos": lod_tris,
            "porcentaje_del_total": round(100.0 * lod_tris / total, 1),
        },
        "medidas": sizes,
        "referencia_cine_lux_nivel5": CINE_LUX_L5_TRIANGLES,
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("CARTELERA_STATS", json.dumps({"total": total, "lod1": lod_tris, "medidas": sizes, "piezas": len(pieces)}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if sizes["alto_maximo_sobre_suelo"] > MAX_HEIGHT:
        raise RuntimeError(f"Altura {sizes['alto_maximo_sobre_suelo']} > {MAX_HEIGHT}")
    if sizes["frente_y"] < FRONT_LIMIT:
        raise RuntimeError(f"Vuela más de -10: {sizes['frente_y']}")
    if sizes["ancho"] > WIDTH + 0.05:
        raise RuntimeError(f"El ancho {sizes['ancho']} pasa de 32")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "cartelera.blend"))

    place(objects, 0.0, 0.0)
    street(M)
    render(scene, camera("frontal", (0.0, -92.0, 13.0), (0.0, -3.0, 13.8), 50), f"{RENDER_SUBDIR}/cartelera-frontal.png")
    render(scene, camera("aereo", (38.0, -76.0, 58.0), (0.0, 1.0, 13.5), 42), f"{RENDER_SUBDIR}/cartelera-aereo.png")

    # Comparación: la cartelera junto a una figura de 6 studs, para leer la altura real de la puerta
    # y de la pantalla.
    hide_all()
    box("ground", (260, 120, 0.4), (0, 0, -0.2), M["pavement"])
    place(objects, 0.0, 0.0)
    box("avatar_ref", (1.6, 1.2, 6.0), (12.8, -11.2, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (30.0, -78.0, 16.0), (0.0, -4.0, 13.0), 45), f"{RENDER_SUBDIR}/cartelera-comparacion.png")
    print("CARTELERA_DONE")


if __name__ == "__main__":
    main()

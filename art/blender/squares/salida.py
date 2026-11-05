"""Salida: la casilla de salida de Flip the Table, modelada desde cero.

Una cochera de salida: nave abierta de 32 × 18, con portalón alto, puertas de servicio, ventanas de
taller y un pórtico de señalización sobre la entrada con «SALIDA» en letras 3D. Sin añadidos de nivel:
una sola pieza. Frente a -Y, origen en el centro de la base y z = 0 a ras de suelo.

Sigue la estructura de art/blender/buildings/cobre/barberia-morro.py: helpers importados de
art/blender/slice/build_cine_lux.py, una malla por material y color, LOD1 decimado, stats.json y renders.

Salidas:
  art/blender/squares/salida/start_<material>.fbx, start_LOD1.fbx y stats.json
  art/blender/squares/salida.blend                 escena de revisión (no se versiona)
Y en art/render/squares/salida/: salida-frontal.png, salida-aereo.png y salida-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/squares/salida.py
"""

import json
import math
import os
import sys

import bmesh
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "salida")
RENDER_SUBDIR = "squares/salida"
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
# Medidas en studs. Huella 32 × 18; el único vuelo es el pórtico, que llega a y = -10.
# --------------------------------------------------------------------------------------------
WIDTH = 32.0
DEPTH = 18.0
FRONT = -DEPTH / 2  # -9
BACK = DEPTH / 2  # 9
WALL_T = 0.8
WALL_H = 10.2
EAVE_Z = 10.35
RIDGE_Z = 14.6
ROOF_T = 0.34
PORTAL_HALF = 4.7  # portalón de 9,4
PORTAL_H = 7.8
PIER_W = 1.2  # machón entre portalón y puerta: el pórtico apoya aquí
DOOR_HALF = 1.4  # puertas de servicio de 2,8
DOOR_H = 6.7
WIN_HALF = 1.8  # ventanas de taller de 3,6
WIN_Z0 = 2.4
WIN_Z1 = 7.2
WIN_X = 11.4
DOOR_X = 7.3
GANTRY_X = 5.3
SIGN_HALF = 5.2
GATE_Y = -8.55
SIGN_Y = -9.62
TRIANGLE_BUDGET = 3000
MAX_HEIGHT = 22.0

# Normal de cada faldón en el plano YZ, para separar piezas de la cubierta siguiendo la pendiente.
FRONT_NORMAL = (-0.4266, 0.9044)
BACK_NORMAL = (0.4266, 0.9044)

# Material de Roblox, sufijo de color y RGB de cada clave de material de Blender.
RBX = {
    "limestone": ("Limestone", "", "D2C9B4"),
    "brick": ("Brick", "", "B0664A"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "metal": ("Metal", "", "A8AEB4"),
    "wood": ("Wood", "", "6B4A2E"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "brick": textured("brick", "brick_warm", "B0664A"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "metal": flat("metal", "A8AEB4", 0.25, 0.8),
        "wood": flat("wood", "6B4A2E", 0.7),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "avatar": flat("avatar", "6E747C", 0.8),
    }


def roof_line_front(y):
    """Altura de la cara superior del faldón delantero en y (de -9 a 0)."""
    return EAVE_Z + (y - FRONT) * (RIDGE_Z - EAVE_Z) / (0.0 - FRONT)


def roof_line_back(y):
    """Altura de la cara superior del faldón trasero en y (de 0 a 9)."""
    return EAVE_Z + (BACK - y) * (RIDGE_Z - EAVE_Z) / (BACK - 0.0)


def front_point(y, offset=0.0):
    """Punto (y, z) sobre el faldón delantero, desplazado a lo largo de su normal."""
    return (y + FRONT_NORMAL[0] * offset, roof_line_front(y) + FRONT_NORMAL[1] * offset)


def back_point(y, offset=0.0):
    return (y + BACK_NORMAL[0] * offset, roof_line_back(y) + BACK_NORMAL[1] * offset)


# --------------------------------------------------------------------------------------------
# Piezas propias que no están en los helpers compartidos.
# --------------------------------------------------------------------------------------------
def slope_panel(name, x0, x1, p0, p1, thick, mat):
    """Losa inclinada: la cara superior va de p0 a p1, que son (y, z). Sirve para tejados y faldones."""
    y0, z0 = p0
    y1, z1 = p1
    dy, dz = y1 - y0, z1 - z0
    length = math.hypot(dy, dz)
    theta = math.atan2(dz, dy)
    normal_y, normal_z = -math.sin(theta), math.cos(theta)
    center_y = (y0 + y1) / 2 - normal_y * thick / 2
    center_z = (z0 + z1) / 2 - normal_z * thick / 2
    obj = box(name, (x1 - x0, length, thick), ((x0 + x1) / 2, center_y, center_z), mat)
    obj.rotation_euler = (theta, 0, 0)
    select_only(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return obj


def gable(name, x0, x1, y0, y1, z0, z_apex, mat):
    """Frontón triangular en el plano YZ, de x0 a x1: 8 triángulos y ninguna cara abierta."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    middle = (y0 + y1) / 2
    side_a = [bm.verts.new((x0, y0, z0)), bm.verts.new((x0, y1, z0)), bm.verts.new((x0, middle, z_apex))]
    side_b = [bm.verts.new((x1, y0, z0)), bm.verts.new((x1, y1, z0)), bm.verts.new((x1, middle, z_apex))]
    bm.faces.new(side_a)
    bm.faces.new(tuple(reversed(side_b)))
    for index in range(3):
        following = (index + 1) % 3
        bm.faces.new((side_a[index], side_a[following], side_b[following], side_b[index]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def cylinder(name, radius, depth, location, mat, verts=12, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts,
        radius=radius,
        depth=depth,
        end_fill_type="NGON",
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    select_only(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
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


# --------------------------------------------------------------------------------------------
# Construcción. Todo se modela una sola vez: no hay niveles que sumar.
# --------------------------------------------------------------------------------------------
def build_shell(M):
    """Nave de caliza con esquinas de ladrillo y cubierta a dos aguas. El frente se arma con los huecos
    de verdad (portalón, puertas y ventanas), así no hace falta ningún booleano y hay profundidad."""
    parts = []
    # Muros laterales y trasero.
    for sign in (-1, 1):
        parts.append(box("side_wall", (WALL_T, DEPTH, WALL_H), (sign * (WIDTH / 2 - WALL_T / 2), 0, WALL_H / 2), M["limestone"]))
    parts.append(box("back_wall", (WIDTH, WALL_T, WALL_H), (0, BACK - WALL_T / 2, WALL_H / 2), M["limestone"]))

    # Frente: el central con el dintel del portalón y, a cada lado, el machón, la puerta, el machón de
    # la ventana, el antepecho, el dintel de la ventana y la esquina.
    y_wall = FRONT + WALL_T / 2
    parts.append(box("front_head", (PORTAL_HALF * 2, WALL_T, WALL_H - PORTAL_H), (0, y_wall, (PORTAL_H + WALL_H) / 2), M["limestone"]))
    for sign in (-1, 1):
        pier_center = PORTAL_HALF + PIER_W / 2
        parts.append(box("front_pier", (PIER_W, WALL_T, WALL_H), (sign * pier_center, y_wall, WALL_H / 2), M["limestone"]))
        door_start = PORTAL_HALF + PIER_W
        parts.append(box("door_head", (DOOR_HALF * 2, WALL_T, WALL_H - DOOR_H), (sign * (door_start + DOOR_HALF), y_wall, (DOOR_H + WALL_H) / 2), M["limestone"]))
        window_start = WIN_X - WIN_HALF
        parts.append(box("win_pier", (window_start - (door_start + DOOR_HALF * 2), WALL_T, WALL_H), (sign * ((door_start + DOOR_HALF * 2 + window_start) / 2), y_wall, WALL_H / 2), M["limestone"]))
        # Machón de ladrillo que enmarca la ventana por el lado de la puerta: rompe la caliza lisa.
        parts.append(box("win_post", (0.7, 0.35, WALL_H), (sign * 9.05, FRONT - 0.02, WALL_H / 2), M["brick"]))
        parts.append(box("win_sill_wall", (WIN_HALF * 2, WALL_T, WIN_Z0), (sign * WIN_X, y_wall, WIN_Z0 / 2), M["limestone"]))
        parts.append(box("win_head_wall", (WIN_HALF * 2, WALL_T, WALL_H - WIN_Z1), (sign * WIN_X, y_wall, (WIN_Z1 + WALL_H) / 2), M["limestone"]))
        parts.append(box("corner", (16.0 - (WIN_X + WIN_HALF), WALL_T, WALL_H), (sign * ((WIN_X + WIN_HALF + 16.0) / 2), y_wall, WALL_H / 2), M["limestone"]))

    # Zócalo solo en el frente, donde se mira.
    for sign in (-1, 1):
        parts.append(box("plinth", (16.0 - PORTAL_HALF, 0.55, 0.7), (sign * ((PORTAL_HALF + 16.0) / 2), FRONT - 0.07, 0.35), M["limestone"]))

    # Esquinas de ladrillo, dintel del portalón y junta de caliza sobre él.
    for sign in (-1, 1):
        parts.append(box("pier", (1.3, 0.75, WALL_H), (sign * 15.35, FRONT + 0.15, WALL_H / 2), M["brick"]))
    parts.append(box("lintel", (PORTAL_HALF * 2 + 0.5, 0.7, 0.55), (0, FRONT + 0.1, PORTAL_H + 0.275), M["brick"]))
    parts.append(box("belt", (WIDTH, 0.4, 0.45), (0, FRONT + 0.05, 8.55), M["limestone"]))

    # Alero: tapa el canto del tejado y cierra la junta con el muro.
    parts.append(box("fascia_front", (WIDTH, 0.4, 0.7), (0, FRONT - 0.05, 10.05), M["limestone"]))
    parts.append(box("fascia_back", (WIDTH, 0.4, 0.7), (0, BACK - 0.22, 10.05), M["limestone"]))

    # Frontones de ladrillo en los dos hastiales.
    for sign in (-1, 1):
        parts.append(gable("gable", sign * 15.2, sign * 16.0, FRONT, BACK, WALL_H - 0.15, RIDGE_Z - ROOF_T, M["brick"]))
    return parts


def build_gate(M):
    """Portalón: guías de acero, tambor de la persiana recogida y umbral. La nave queda abierta."""
    parts = []
    for sign in (-1, 1):
        parts.append(box("gate_guide", (0.24, 0.42, PORTAL_H), (sign * (PORTAL_HALF + 0.05), FRONT + 0.45, PORTAL_H / 2), M["metal"]))
        parts.append(box("gate_bracket", (0.32, 0.6, 0.55), (sign * (PORTAL_HALF - 0.1), GATE_Y + 0.05, PORTAL_H - 0.4), M["metal"]))
    parts.append(cylinder("gate_drum", 0.38, PORTAL_HALF * 2 - 0.4, (0, GATE_Y, PORTAL_H - 0.38), M["metal"], 12, (0.0, math.pi / 2, 0.0)))
    parts.append(box("gate_sill", (PORTAL_HALF * 2 + 0.4, 0.6, 0.12), (0, FRONT + 0.5, 0.06), M["metal"]))

    # Puertas de servicio: hoja de madera dentro del hueco, con dos travesaños.
    for sign in (-1, 1):
        x = sign * DOOR_X
        parts.append(box("door_leaf", (DOOR_HALF * 2 - 0.2, 0.16, DOOR_H - 0.12), (x, FRONT + 0.38, (DOOR_H - 0.12) / 2), M["wood"]))
        for z in (1.35, 5.35):
            parts.append(box("door_rail", (DOOR_HALF * 2 - 0.2, 0.07, 0.22), (x, FRONT + 0.28, z), M["wood"]))
        for side in (-1, 1):
            parts.append(box("door_jamb", (0.2, 0.55, DOOR_H), (x + side * (DOOR_HALF - 0.08), FRONT + 0.2, DOOR_H / 2), M["wood"]))
        parts.append(box("door_frame_head", (DOOR_HALF * 2 + 0.2, 0.55, 0.24), (x, FRONT + 0.2, DOOR_H - 0.1), M["wood"]))

    # Ventanas de taller: un solo paño alto a cada lado, no una hilera de ventanitas.
    for sign in (-1, 1):
        x = sign * WIN_X
        parts.append(box("win_glass", (WIN_HALF * 2 - 0.2, 0.12, WIN_Z1 - WIN_Z0), (x, FRONT + 0.46, (WIN_Z0 + WIN_Z1) / 2), M["glass"]))
        for side in (-1, 1):
            parts.append(box("win_jamb", (0.2, 0.55, WIN_Z1 - WIN_Z0), (x + side * (WIN_HALF - 0.08), FRONT + 0.2, (WIN_Z0 + WIN_Z1) / 2), M["limestone"]))
        parts.append(box("win_head", (WIN_HALF * 2 + 0.2, 0.55, 0.24), (x, FRONT + 0.2, WIN_Z1 - 0.1), M["limestone"]))
        parts.append(box("win_sill", (WIN_HALF * 2 + 0.3, 0.6, 0.26), (x, FRONT + 0.18, WIN_Z0 - 0.05), M["limestone"]))
        parts.append(box("win_mullion", (0.16, 0.3, WIN_Z1 - WIN_Z0 - 0.2), (x, FRONT + 0.56, (WIN_Z0 + WIN_Z1) / 2), M["wood"]))

    # Lámparas de pared sobre las puertas: solo herraje, sin luz.
    for sign in (-1, 1):
        parts.append(box("lamp_arm", (0.18, 0.45, 0.18), (sign * DOOR_X, FRONT, 7.5), M["metal"]))
        parts.append(box("lamp_shade", (0.9, 0.6, 0.24), (sign * DOOR_X, FRONT - 0.2, 7.3), M["metal"]))
    return parts


def build_roof(M):
    """Cubierta a dos aguas con rastreles, linternón, claraboyas, chimenea y ventilaciones: es lo que ve
    la cámara alta del juego, así que lleva detalle de verdad y nada queda volando."""
    parts = []
    parts.append(slope_panel("roof_front", -WIDTH / 2, WIDTH / 2, (FRONT, EAVE_Z), (0.0, RIDGE_Z), ROOF_T, M["slate"]))
    parts.append(slope_panel("roof_back", -WIDTH / 2, WIDTH / 2, (0.0, RIDGE_Z), (BACK, EAVE_Z), ROOF_T, M["slate"]))
    parts.append(box("ridge_cap", (WIDTH, 1.4, 0.6), (0, 0, 14.5), M["metal"]))

    # Rastreles: costillas finas sobre los dos faldones.
    count_x = 12
    for index in range(count_x):
        x = -15.4 + index * (30.8 / (count_x - 1))
        for is_front in (True, False):
            if is_front:
                start, end = front_point(-8.5, 0.12), front_point(-1.7, 0.12)
            else:
                start, end = back_point(8.5, 0.12), back_point(1.7, 0.12)
            parts.append(slope_panel("batten", x - 0.09, x + 0.09, start, end, 0.3, M["slate"]))

    # Linternón sobre la cumbrera: banda de cristal con montantes y su propio tejadillo.
    parts.append(box("monitor_curb", (13.4, 3.0, 1.6), (0, 0, 14.4), M["limestone"]))
    for sign in (-1, 1):
        parts.append(box("monitor_sill", (13.2, 0.36, 0.3), (0, sign * 1.15, 15.3), M["limestone"]))
        parts.append(box("monitor_cap", (13.2, 0.36, 0.3), (0, sign * 1.15, 16.85), M["limestone"]))
        parts.append(box("monitor_glass", (12.6, 0.12, 1.45), (0, sign * 1.15, 16.03), M["glass"]))
        parts.append(box("monitor_end", (0.3, 2.9, 1.65), (sign * 6.6, 0, 16.0), M["limestone"]))
        for x in (-5.2, 0.0, 5.2):
            parts.append(box("monitor_mullion", (0.16, 0.4, 1.5), (x, sign * 1.15, 16.03), M["metal"]))
        parts.append(slope_panel("monitor_roof", -6.9, 6.9, (sign * 1.45, 16.95), (0.0, 17.92), 0.22, M["slate"]))
        parts.append(gable("monitor_gable", sign * 6.3, sign * 6.9, -1.45, 1.45, 16.8, 17.92, M["limestone"]))
    parts.append(box("monitor_ridge", (14.0, 0.8, 0.2), (0, 0, 17.95), M["metal"]))

    # Chimenea, claraboyas, escotilla y ventilaciones en el faldón delantero: es el que ve la cámara alta.
    parts.append(box("flue", (1.1, 1.1, 3.2), (12.9, -3.1, 13.7), M["metal"]))
    parts.append(box("flue_cap", (1.45, 1.45, 0.22), (12.9, -3.1, 15.41), M["metal"]))
    for sign in (-1, 1):
        x = sign * 10.5
        parts.append(slope_panel("skylight_curb", x - 1.7, x + 1.7, front_point(-7.4, 0.28), front_point(-5.2, 0.28), 0.3, M["slate"]))
        parts.append(slope_panel("skylight_glass", x - 1.5, x + 1.5, front_point(-7.25, 0.33), front_point(-5.35, 0.33), 0.07, M["glass"]))
    parts.append(slope_panel("hatch_curb", -13.2, -11.4, front_point(-4.9, 0.25), front_point(-3.3, 0.25), 0.28, M["slate"]))
    parts.append(slope_panel("hatch_lid", -13.05, -11.55, front_point(-4.75, 0.31), front_point(-3.45, 0.31), 0.08, M["metal"]))
    for sign in (-1, 1):
        parts.append(cylinder("vent_pipe", 0.32, 2.2, (sign * 4.6, -3.0, 12.4), M["metal"], 8))
        parts.append(cylinder("vent_cap", 0.44, 0.12, (sign * 4.6, -3.0, 13.56), M["metal"], 8))
    return parts


def build_interior(M):
    """Lo que se ve por el portalón: suelo, pilares, vigas, portón trasero y mostrador de salida."""
    parts = []
    parts.append(box("floor", (WIDTH - 1.8, DEPTH - 1.8, 0.16), (0, 0, 0.08), M["slate"]))
    for sign_x in (-1, 1):
        for y in (-4.0, 4.0):
            parts.append(box("column", (0.45, 0.45, 9.2), (sign_x * 8.0, y, 0.16 + 4.6), M["metal"]))
        parts.append(box("beam_long", (0.45, 15.0, 0.55), (sign_x * 8.0, 0, 9.45), M["metal"]))
    for y in (-4.0, 4.0):
        parts.append(box("beam_cross", (16.0, 0.4, 0.5), (0, y, 9.42), M["metal"]))

    # Portón trasero bajado, de madera: da fondo a la nave sin dejar un agujero negro.
    for index in range(9):
        parts.append(box("back_slat", (5.6, 0.14, 0.6), (0, BACK - 0.9, 0.46 + index * 0.62), M["wood"]))
    for sign in (-1, 1):
        parts.append(box("back_guide", (0.24, 0.2, 5.6), (sign * 2.95, BACK - 0.92, 2.85), M["metal"]))

    # Mostrador de salida, una estantería y dos cajas.
    parts.append(box("counter", (5.2, 1.1, 1.05), (-5.0, 5.6, 0.16 + 0.525), M["wood"]))
    parts.append(box("counter_top", (5.5, 1.25, 0.14), (-5.0, 5.6, 1.29), M["wood"]))
    parts.append(box("counter_back", (5.2, 0.16, 1.5), (-5.0, 6.28, 0.16 + 0.75), M["wood"]))
    parts.append(box("shelf", (4.6, 0.9, 0.16), (-9.4, 7.9, 2.4), M["wood"]))
    parts.append(box("crate", (1.3, 1.1, 1.0), (4.6, 1.6, 0.66), M["wood"]))
    parts.append(box("crate", (1.1, 1.0, 0.9), (6.2, 0.7, 0.61), M["wood"]))
    return parts


def build_gantry(M):
    """Pórtico de señalización sobre el portalón: dos postes sobre los machones, celosía de acero y la
    placa con «SALIDA» en letras 3D, legible desde la calle."""
    parts = []
    for sign in (-1, 1):
        parts.append(box("gantry_pad", (1.1, 0.7, 0.4), (sign * GANTRY_X, SIGN_Y, 0.2), M["limestone"]))
        parts.append(box("gantry_post", (0.7, 0.55, 11.6), (sign * GANTRY_X, SIGN_Y, 5.8), M["metal"]))
    parts.append(box("gantry_chord_low", (GANTRY_X * 2 + 1.0, 0.42, 0.4), (0, SIGN_Y, 11.4), M["metal"]))
    parts.append(box("gantry_chord_high", (GANTRY_X * 2 + 1.0, 0.42, 0.4), (0, SIGN_Y, 12.5), M["metal"]))
    for x in (-4.2, -2.1, 0.0, 2.1, 4.2):
        parts.append(box("gantry_strut", (0.28, 0.3, 0.7), (x, SIGN_Y, 11.95), M["metal"]))

    parts.append(box("sign_plate", (SIGN_HALF * 2, 0.45, 2.6), (0, SIGN_Y, 13.9), M["limestone"]))
    parts.append(box("sign_frame_top", (SIGN_HALF * 2 + 0.2, 0.55, 0.16), (0, SIGN_Y, 15.28), M["metal"]))
    parts.append(box("sign_frame_bottom", (SIGN_HALF * 2 + 0.2, 0.55, 0.16), (0, SIGN_Y, 12.52), M["metal"]))
    for sign in (-1, 1):
        parts.append(box("sign_frame_side", (0.16, 0.55, 2.6), (sign * (SIGN_HALF + 0.02), SIGN_Y, 13.9), M["metal"]))
    parts.append(box("sign_cap", (SIGN_HALF * 2 + 0.5, 0.7, 0.14), (0, SIGN_Y, 15.43), M["metal"]))
    name = fit_width(letters("SALIDA", 2.2, (0.0, SIGN_Y - 0.18, 13.9), M["slate"], depth=0.14), 9.6)
    parts.append(name)
    return parts


def group(parts, store):
    """Une todas las piezas en una malla por material y color: cada FBX lleva un material y un color."""
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        rbx, suffix, rgb = RBX[key]
        name = f"start_{rbx.lower()}{suffix}"
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
        "x": [round(min(xs), 2), round(max(xs), 2)],
        "y": [round(min(ys), 2), round(max(ys), 2)],
        "z": [round(min(zs), 2), round(max(zs), 2)],
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
    box("road", (240, 34, 0.4), (0, -32.5, -0.24), M["asphalt"])
    box("walk_near", (240, 6.0, 0.4), (0, -12.0, -0.2), M["pavement"])
    box("walk_far", (240, 7.0, 0.4), (0, -53.0, -0.22), M["pavement"])
    box("kerb", (240, 0.4, 0.45), (0, -15.2, -0.22), M["cream"])
    dash = -115.0
    while dash < 115.0:
        box("dash", (5.0, 0.4, 0.05), (dash, -32.5, -0.02), M["cream"])
        dash += 11.0
    for x in (-22.0, 22.0):
        lamp(x, -15.8, M)
        tree(x, -12.4, M)
    box("avatar_ref", (1.6, 1.2, 6.0), (-10.2, -11.8, 3.0), M["avatar"])
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
    parts = build_shell(M) + build_gate(M) + build_roof(M) + build_interior(M) + build_gantry(M)
    pieces = []
    group(parts, pieces)

    objects = [piece["obj"] for piece in pieces]
    total = sum(count(obj) for obj in objects)
    sizes = bounds(objects)

    # LOD1: una sola malla y un solo material, decimado por debajo de la mitad.
    lod = lod_of(objects, "start_LOD1")
    lod.data.materials.clear()
    lod.data.materials.append(M["limestone"])
    uv_unwrap(lod)
    lod_tris = count(lod)

    for piece in pieces:
        export(piece["obj"], piece["key"] + ".fbx")
    export(lod, "start_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "tipo": "casilla especial «Salida»: cochera de salida sin añadidos de nivel; todo el modelo es el cuerpo",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "vuelos": {"frente_y": sizes["frente_y"], "limite_y": -10.0},
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
        "total_triangulos": total,
        "presupuesto_triangulos": TRIANGLE_BUDGET,
        "altura_maxima_permitida": MAX_HEIGHT,
        "lod1": {
            "clave": "start_LOD1",
            "archivo": "start_LOD1.fbx",
            "mallas": 1,
            "materiales": 1,
            "material": "Limestone",
            "rgb": "D2C9B4",
            "triangulos": lod_tris,
            "porcentaje_del_total": round(100.0 * lod_tris / total, 1),
        },
        "medidas": sizes,
        "puertas": [
            {"clave": "start_metal", "uso": "portalón de la nave", "ancho": PORTAL_HALF * 2, "alto": PORTAL_H},
            {"clave": "start_wood", "uso": "puertas de servicio", "ancho": DOOR_HALF * 2, "alto": DOOR_H},
        ],
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("SALIDA_STATS", json.dumps({"total": total, "lod1": lod_tris, "medidas": sizes, "piezas": len(pieces)}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if sizes["alto_maximo_sobre_suelo"] > MAX_HEIGHT:
        raise RuntimeError(f"Altura {sizes['alto_maximo_sobre_suelo']} > {MAX_HEIGHT}")
    if sizes["frente_y"] < -10.0:
        raise RuntimeError(f"Vuela más de -10: {sizes['frente_y']}")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "salida.blend"))

    place(objects, 0.0, 0.0)
    street(M)
    render(scene, camera("frontal", (0.0, -58.0, 10.5), (0.0, -4.0, 7.5), 48), f"{RENDER_SUBDIR}/salida-frontal.png")
    render(scene, camera("aereo", (28.0, -50.0, 42.0), (0.0, -2.0, 7.0), 50), f"{RENDER_SUBDIR}/salida-aereo.png")

    # Comparación: la cochera con una figura de 6 studs metida en el portalón, para leer la altura real.
    hide_all()
    box("ground", (260, 100, 0.4), (0, 0, -0.2), M["pavement"])
    place(objects, 0.0, 0.0)
    box("avatar_ref", (1.6, 1.2, 6.0), (8.6, -10.6, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (18.0, -52.0, 12.0), (0.0, -6.0, 8.0), 40), f"{RENDER_SUBDIR}/salida-comparacion.png")
    print("SALIDA_DONE")


if __name__ == "__main__":
    main()

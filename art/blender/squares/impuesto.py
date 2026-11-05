"""Impuesto: la aduana de la casilla «Impuesto», modelada desde cero.

La casilla no es una propiedad: no lleva añadidos de nivel ni marcadores. El edificio es su negocio y se
reconoce sin leer el rótulo: una casa de aduana baja y larga, con una torre de control en el extremo derecho,
la ventanilla de cobro con mostrador de caliza y rejilla, la barrera a rayas rojas y blancas cruzada delante
de la torre y la placa «IMPUESTO» en letras 3D sobre el pretil.

Medidas en studs (1 unidad de Blender = 1 stud). Frente a -Y, origen en el centro de la base y z = 0 a ras de
suelo. Huella 29,1 x 17,15 dentro del máximo de 32 x 18; el vuelo delantero máximo queda en y = -9,95 (máximo
-10) y la altura en 15,93 (máximo 16).

Salidas, en art/blender/squares/:
  impuesto.blend            escena de revisión (no se versiona)
  impuesto/tax_<material>.fbx   una malla, un material y un color por FBX
  impuesto/tax_LOD1.fbx         una sola malla con un solo material, por debajo del 50 %
  impuesto/stats.json           triángulos por pieza, total, LOD1 y medidas
Y en art/render/squares/impuesto/: impuesto-frontal.png, impuesto-aereo.png e impuesto-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/squares/impuesto.py
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
OUT = os.path.join(HERE, "impuesto")
RENDER_SUBDIR = "squares/impuesto"
sys.path.insert(0, SLICE)

# Helpers compartidos con los edificios ya en el juego (no se copian: se importan).
from build_cine_lux import (  # noqa: E402
    apply_modifiers,
    box,
    camera,
    count,
    flat,
    join,
    letters,
    origin_at_zero,
    perforate,
    render,
    select_only,
    textured,
    uv_unwrap,
)

# --- Medidas ---------------------------------------------------------------------------------------
WIDTH = 27.0  # cuerpo, sin la torre
DEPTH = 14.0
FRONT = -DEPTH / 2  # -7,0
BACK = DEPTH / 2
BRICK_TOP = 1.25  # zócalo de ladrillo
WALL_TOP = 7.6
CORNICE_TOP = 7.95
EAVE = 7.9
RIDGE = 11.2
RIDGE_HALF = WIDTH / 2 - DEPTH / 2  # 6,5: lima a 45 grados

DOOR_X = -6.5
DOOR_W = 2.9  # hueco; el paso libre entre jambas es 2,62
DOOR_TOP = 6.8

WIN_W = 2.6
WIN_Z0 = 2.7
WIN_Z1 = 6.3
WIN_XS = (-9.6, 1.9)  # un ventanal bajo el porche y otro entre porche y torre

# Porche de entrada: dos pilares de caliza y un faldón de pizarra sobre la puerta.
PORCH_X0, PORCH_X1 = -11.6, -1.4
PORCH_CX = (PORCH_X0 + PORCH_X1) / 2
PORCH_W = PORCH_X1 - PORCH_X0
PORCH_HIGH = (-6.95, 7.05)  # borde alto, metido en el muro
PORCH_LOW = (-9.45, 6.30)  # borde bajo, sobre los pilares
PORCH_PIER_XS = (-11.3, -1.9)
PORCH_PIER_Y = -9.05
PORCH_PIER_TOP = 6.13

# Pretil y placa. El pretil tapa el arranque del tejado desde la calle; la placa va por encima del porche.
PARAPET_Z0 = 7.90
PARAPET_Z1 = 10.35
PARAPET_W = 15.0
PARAPET_Y0, PARAPET_Y1 = -7.35, -6.65
SIGN_TEXT = "IMPUESTO"
SIGN_SIZE = 1.9
SIGN_W = 10.0
SIGN_Z = 9.20
SIGN_Y = -7.50  # centro de la tabla, 0,17 por delante del pretil

# Torre de control en el extremo derecho, metida en el cuerpo y 1,4 por delante de la fachada.
TOWER_X0, TOWER_X1 = 7.0, 14.5
TOWER_Y0, TOWER_Y1 = -8.4, -1.9
TOWER_W = TOWER_X1 - TOWER_X0  # 7,5
TOWER_D = TOWER_Y1 - TOWER_Y0  # 6,5
TOWER_CX = (TOWER_X0 + TOWER_X1) / 2  # 10,75
TOWER_CY = (TOWER_Y0 + TOWER_Y1) / 2  # -5,15
TOWER_TOP = 11.6
TOWER_EAVE = 11.95
TOWER_PYR_TOP = 13.50
TOWER_PYR_W = 7.4
TOWER_PYR_D = 6.4

# Ventanilla de cobro y ventana alta de la torre.
WINDOW_Z0, WINDOW_Z1 = 3.3, 6.5
WINDOW_W = 3.4
UPPER_WIN_W = 0.95
UPPER_WIN_Z0, UPPER_WIN_Z1 = 8.0, 10.6

# Linterna de la torre: tambor de cristal, bandas de caliza y capuchón de pizarra.
LANTERN_BASE = (13.45, 13.67)
LANTERN_GLASS = (13.62, 14.57)
LANTERN_BAND = (14.55, 14.75)
LANTERN_CAP = (14.72, 15.55)
LANTERN_FINIAL = (15.53, 15.93)

# Barrera a rayas. Poste en el borde derecho, brazo hacia la izquierda, delante de la torre.
BARRIER = (14.0, -9.35)
BOOM_Z = 2.59
BOOM_TOP = 2.73
BOOM_BOTTOM = 2.45
BOOM_START_X = 13.90
BOOM_STRIPES = 8
BOOM_STRIPE_W = 1.45
BOOM_END_X = BOOM_START_X - BOOM_STRIPES * BOOM_STRIPE_W  # 2,30

CHIMNEY = (-9.5, 3.5)

HEIGHT_MAX = 16.0
FRONT_LIMIT = -10.0
LOT_WIDTH, LOT_DEPTH = 32.0, 18.0
TRIANGLE_BUDGET = 3000
LOD_RATIO = 0.42

MEASURED = {}  # medidas reales que no salen de una constante (el rótulo se ajusta al ancho)

RBX = {
    "brick": ("Brick", "", "B0664A"),
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "metal": ("Metal", "", "A8AEB4"),
    "wood": ("Wood", "", "6B4A2E"),
    "plastic_rojo": ("SmoothPlastic", "_rojo", "C4382B"),
    "plastic_blanco": ("SmoothPlastic", "_blanco", "EDE5D3"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el suelo y las referencias."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "metal": flat("metal", "A8AEB4", 0.25, 0.8),
        "wood": flat("wood", "6B4A2E", 0.7),
        "plastic_rojo": flat("plastic_rojo", "C4382B", 0.35),
        "plastic_blanco": flat("plastic_blanco", "EDE5D3", 0.35),
        # Solo escena de render.
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "cream": flat("cream", "EDE5D3", 0.6),
        "avatar": flat("avatar", "6E747C", 0.8),
    }


def mesh_object(name, verts, faces, mat):
    """Malla a mano para tejados y troncos de pirámide, con las normales hacia fuera."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    return obj


def hip_roof(name, half_w, half_d, ridge_half, z_eave, z_ridge, mat):
    """Tejado a cuatro aguas: dos faldones trapezoidales y dos limas triangulares. 8 triángulos."""
    verts = [
        (-half_w, -half_d, z_eave),
        (half_w, -half_d, z_eave),
        (half_w, half_d, z_eave),
        (-half_w, half_d, z_eave),
        (-ridge_half, 0.0, z_ridge),
        (ridge_half, 0.0, z_ridge),
    ]
    faces = [(0, 1, 5, 4), (4, 5, 2, 3), (0, 4, 3), (1, 2, 5), (3, 2, 1, 0)]
    return mesh_object(name, verts, faces, mat)


def frustum(name, w0, d0, w1, d1, z0, z1, mat, center=(0.0, 0.0)):
    """Tronco de pirámide de base y tapa rectangulares: remate de la torre y capuchón de la linterna."""
    cx, cy = center
    verts = [
        (cx - w0 / 2, cy - d0 / 2, z0),
        (cx + w0 / 2, cy - d0 / 2, z0),
        (cx + w0 / 2, cy + d0 / 2, z0),
        (cx - w0 / 2, cy + d0 / 2, z0),
        (cx - w1 / 2, cy - d1 / 2, z1),
        (cx + w1 / 2, cy - d1 / 2, z1),
        (cx + w1 / 2, cy + d1 / 2, z1),
        (cx - w1 / 2, cy + d1 / 2, z1),
    ]
    faces = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    return mesh_object(name, verts, faces, mat)


def bar(name, p0, p1, width, thick, mat):
    """Barra entre dos puntos: limas del tejado, costillas de la linterna."""
    a, b = Vector(p0), Vector(p1)
    direction = b - a
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(a + b) / 2)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (direction.length, width, thick)
    obj.rotation_euler = direction.to_track_quat("X", "Z").to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.data.materials.append(mat)
    return obj


def cylinder(name, radius, depth, location, mat, verts=12, rotation=(0.0, 0.0, 0.0)):
    """Cilindro con tapas: eje del poste, remates y tubos de chimenea."""
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
    return obj


def door_cutter():
    """Hueco de la puerta: atraviesa el zócalo y el muro, 1,4 de fondo. Baja 0,1 bajo el suelo para cortar limpio."""
    return box("door_cut", (DOOR_W, 1.4, DOOR_TOP + 0.1), (DOOR_X, -6.7, (DOOR_TOP - 0.1) / 2))


def window_cutter(x):
    """Hueco de ventanal: mella de 1,0 en el muro, de z 2,7 a 6,3."""
    return box("win_cut", (WIN_W, 1.0, WIN_Z1 - WIN_Z0), (x, -6.6, (WIN_Z0 + WIN_Z1) / 2))


def build_walls(M):
    """Zócalo de ladrillo, muro de caliza, cornisa, pretil y placa con el nombre."""
    parts = []

    plinth = box("plinth", (WIDTH + 0.4, DEPTH + 0.4, BRICK_TOP), (0.0, 0.0, BRICK_TOP / 2), M["brick"])
    perforate(plinth, [door_cutter()])
    parts.append(plinth)

    # El muro arranca 0,05 dentro del zócalo: sin caras coplanares en la junta.
    wall_height = WALL_TOP - BRICK_TOP + 0.05
    wall = box("wall", (WIDTH, DEPTH, wall_height), (0.0, 0.0, BRICK_TOP - 0.05 + wall_height / 2), M["limestone"])
    perforate(wall, [door_cutter(), window_cutter(WIN_XS[0]), window_cutter(WIN_XS[1])])
    parts.append(wall)

    parts.append(box("cornice", (WIDTH + 0.4, DEPTH + 0.4, 0.4), (0.0, 0.0, 7.75), M["limestone"]))

    # Pretil: pared sobre la cornisa que da un plano a la placa y tapa el arranque del tejado.
    parts.append(box("parapet", (PARAPET_W, 0.7, PARAPET_Z1 - PARAPET_Z0),
                     (0.0, (PARAPET_Y0 + PARAPET_Y1) / 2, (PARAPET_Z0 + PARAPET_Z1) / 2), M["limestone"]))
    parts.append(box("parapet_cap", (PARAPET_W + 0.4, 0.9, 0.24), (0.0, -7.0, 10.44), M["limestone"]))

    # Placa de caliza con marco de pizarra: el nombre se lee desde la calle por encima del porche.
    parts.append(box("sign_board", (SIGN_W, 0.34, 1.9), (0.0, SIGN_Y, SIGN_Z), M["limestone"]))
    parts.append(box("sign_frame_top", (SIGN_W + 0.2, 0.18, 0.16), (0.0, SIGN_Y - 0.21, SIGN_Z + 0.95), M["slate"]))
    parts.append(box("sign_frame_bottom", (SIGN_W + 0.2, 0.18, 0.16), (0.0, SIGN_Y - 0.21, SIGN_Z - 0.95), M["slate"]))
    for side in (-1, 1):
        parts.append(box("sign_frame_side", (0.16, 0.18, 1.9), (side * (SIGN_W / 2 + 0.02), SIGN_Y - 0.21, SIGN_Z), M["slate"]))
    name = letters(SIGN_TEXT, SIGN_SIZE, (0.0, SIGN_Y - 0.24, SIGN_Z), M["slate"], depth=0.22)
    width = name.dimensions.x
    if width > SIGN_W - 1.0:
        select_only(name)
        factor = (SIGN_W - 1.0) / width
        name.scale = (factor, factor, factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    MEASURED["rotulo"] = (round(name.dimensions.x, 2), round(name.dimensions.y, 2))
    parts.append(name)
    return parts


def build_door(M):
    """Puerta de madera con cristal, más alta que un avatar (6,8 x 2,9 de hueco)."""
    parts = []
    parts.append(box("door_leaf", (2.55, 0.14, 6.55), (DOOR_X, -6.40, 3.275), M["wood"]))
    for side in (-1, 1):
        parts.append(box("door_jamb", (0.14, 0.4, 6.9), (DOOR_X + side * 1.38, -6.75, 3.45), M["wood"]))
        parts.append(box("door_stile", (0.16, 0.16, 6.55), (DOOR_X + side * 1.05, -6.49, 3.275), M["wood"]))
    parts.append(box("door_head", (DOOR_W, 0.4, 0.2), (DOOR_X, -6.75, 6.73), M["wood"]))
    parts.append(box("door_rail", (2.34, 0.16, 0.9), (DOOR_X, -6.49, 0.45), M["wood"]))
    parts.append(box("door_glass", (1.9, 0.06, 3.25), (DOOR_X, -6.50, 4.35), M["glass"]))
    parts.append(box("door_handle", (0.09, 0.16, 0.6), (DOOR_X + 0.95, -6.46, 3.3), M["metal"]))
    parts.append(box("threshold", (3.2, 1.2, 0.2), (DOOR_X, -6.5, 0.1), M["limestone"]))
    return parts


def build_window(M, x):
    """Ventanal de caliza y madera con cristal opaco y parteluz."""
    parts = []
    parts.append(box("sill", (WIN_W + 0.6, 0.5, 0.25), (x, -6.8, 2.575), M["limestone"]))
    parts.append(box("hood", (WIN_W + 0.4, 0.45, 0.25), (x, -6.9, 6.425), M["limestone"]))
    for side in (-1, 1):
        parts.append(box("win_jamb", (0.14, 0.28, 3.6), (x + side * 1.22, -6.85, 4.5), M["wood"]))
    parts.append(box("win_head", (WIN_W, 0.28, 0.14), (x, -6.85, 6.23), M["wood"]))
    parts.append(box("win_sill_bar", (WIN_W, 0.28, 0.14), (x, -6.85, 2.77), M["wood"]))
    parts.append(box("mullion", (0.12, 0.2, 3.34), (x, -6.7, 4.5), M["wood"]))
    parts.append(box("pane", (2.3, 0.08, 3.3), (x, -6.55, 4.5), M["glass"]))
    return parts


def build_porch(M):
    """Porche de entrada: dos pilares de caliza, faldón de pizarra, canalón y cuatro costillas."""
    parts = []
    for x in PORCH_PIER_XS:
        parts.append(box("pier_base", (0.85, 0.85, 0.35), (x, PORCH_PIER_Y, 0.175), M["limestone"]))
        parts.append(box("pier", (0.55, 0.55, PORCH_PIER_TOP), (x, PORCH_PIER_Y, PORCH_PIER_TOP / 2), M["limestone"]))
        parts.append(box("pier_capital", (0.8, 0.8, 0.25), (x, PORCH_PIER_Y, PORCH_PIER_TOP + 0.125), M["limestone"]))

    # Faldón inclinado: borde alto dentro del muro, borde bajo sobre los capiteles.
    (y_high, z_high), (y_low, z_low) = PORCH_HIGH, PORCH_LOW
    run = y_high - y_low
    rise = z_high - z_low
    angle = math.atan2(rise, run)
    length = math.hypot(run, rise)
    canopy = box("porch_canopy", (PORCH_W, length + 0.06, 0.22), (PORCH_CX, (y_high + y_low) / 2, (z_high + z_low) / 2), M["slate"])
    canopy.rotation_euler = (angle, 0.0, 0.0)
    parts.append(canopy)

    parts.append(box("porch_fascia", (PORCH_W + 0.2, 0.16, 0.32), (PORCH_CX, y_low - 0.08, z_low - 0.02), M["limestone"]))
    parts.append(box("porch_gutter", (PORCH_W + 0.2, 0.28, 0.16), (PORCH_CX, y_low - 0.2, z_low - 0.18), M["metal"]))
    for index, x in enumerate((-9.4, -6.5, -3.6)):
        rib = box(f"porch_rib{index}", (0.16, length - 0.2, 0.16), (x, (y_high + y_low) / 2, (z_high + z_low) / 2 - 0.18), M["slate"])
        rib.rotation_euler = (angle, 0.0, 0.0)
        parts.append(rib)
        # Listones sobre el faldón: la cámara alta mira la cara superior del porche.
        cap = box(f"porch_top{index}", (0.14, length - 0.1, 0.1),
                  (x, (y_high + y_low) / 2 - math.sin(angle) * 0.155, (z_high + z_low) / 2 + math.cos(angle) * 0.155),
                  M["slate"])
        cap.rotation_euler = (angle, 0.0, 0.0)
        parts.append(cap)
    return parts


def build_roof(M):
    """Tejado a cuatro aguas con hiladas, limas, cumbrera, chimenea y respiraderos: se mira desde arriba."""
    parts = [hip_roof("roof", WIDTH / 2, DEPTH / 2, RIDGE_HALF, EAVE, RIDGE, M["slate"])]

    # Hiladas de los dos faldones: se acortan hacia la cumbrera porque las limas se comen las esquinas.
    angle = math.atan2(RIDGE - EAVE, DEPTH / 2)
    for side in (-1, 1):
        normal = (0.0, side * math.sin(angle), math.cos(angle))
        for index, t in enumerate((0.16, 0.34, 0.52, 0.70, 0.86)):
            length = WIDTH - DEPTH * t
            y = side * (DEPTH / 2 - DEPTH / 2 * t) + normal[1] * 0.02
            z = EAVE + (RIDGE - EAVE) * t + normal[2] * 0.02
            course = box(f"course{side}{index}", (length, 0.8, 0.12), (0.0, y, z), M["slate"])
            course.rotation_euler = (-side * angle, 0.0, 0.0)
            parts.append(course)

    # Limas y cumbrera.
    for side_x in (-1, 1):
        for side_y in (-1, 1):
            parts.append(bar("hip", (side_x * WIDTH / 2, side_y * DEPTH / 2, EAVE),
                             (side_x * RIDGE_HALF, 0.0, RIDGE), 0.28, 0.22, M["slate"]))
    parts.append(box("ridge", (2 * RIDGE_HALF + 0.5, 0.45, 0.26), (0.0, 0.0, RIDGE + 0.08), M["slate"]))

    # Dentículos bajo la cornisa: la fachada larga necesita una línea de sombra.
    for index in range(18):
        x = -12.75 + index * 1.5
        parts.append(box(f"dentil{index}", (0.24, 0.18, 0.22), (x, -7.09, 7.44), M["limestone"]))

    # Chimenea de ladrillo con capa de caliza y dos tubos: remate de la izquierda.
    cx, cy = CHIMNEY
    parts.append(box("chimney", (1.5, 1.5, 4.6), (cx, cy, 10.7), M["brick"]))
    parts.append(box("chimney_cap", (1.85, 1.85, 0.25), (cx, cy, 13.1), M["limestone"]))
    for index, (dx, dy) in enumerate(((-0.35, -0.35), (0.35, 0.35))):
        parts.append(cylinder(f"flue{index}", 0.17, 0.6, (cx + dx, cy + dy, 13.45), M["metal"], 10))

    # Respiraderos del faldón delantero: dos cajas bajas con tapa de acero.
    for index, x in enumerate((-10.5, -4.0)):
        parts.append(box(f"vent{index}", (1.1, 0.9, 0.5), (x, -4.0, 9.45), M["slate"]))
        parts.append(box(f"vent_cap{index}", (1.3, 1.1, 0.1), (x, -4.0, 9.73), M["metal"]))

    # Escotilla y tubo de ventilación en el faldón trasero: también se ve desde la cámara alta.
    parts.append(box("roof_hatch", (1.6, 1.2, 0.6), (4.5, 4.0, 9.5), M["slate"]))
    parts.append(box("roof_hatch_cap", (1.8, 1.4, 0.12), (4.5, 4.0, 9.86), M["metal"]))
    parts.append(cylinder("roof_pipe", 0.14, 0.9, (0.6, 2.4, 10.2), M["metal"], 8))
    return parts


def build_tower(M):
    """Torre de control: ladrillo, bandas de caliza, ventanilla, ventana alta y linterna."""
    parts = []
    shaft = box("tower", (TOWER_W, TOWER_D, TOWER_TOP), (TOWER_CX, TOWER_CY, TOWER_TOP / 2), M["brick"])
    window_cut = box("teller_cut", (WINDOW_W, 0.8, WINDOW_Z1 - WINDOW_Z0 + 0.2),
                     (TOWER_CX, TOWER_Y0 + 0.4, (WINDOW_Z0 + WINDOW_Z1) / 2))
    upper_cut = box("upper_cut", (UPPER_WIN_W + 0.1, 0.7, UPPER_WIN_Z1 - UPPER_WIN_Z0 + 0.2),
                    (TOWER_CX, TOWER_Y0 + 0.35, (UPPER_WIN_Z0 + UPPER_WIN_Z1) / 2))
    perforate(shaft, [window_cut, upper_cut])
    parts.append(shaft)

    # Bandas de caliza: base, dintel de la ventanilla y cornisa.
    parts.append(box("tower_base", (TOWER_W + 0.3, TOWER_D + 0.3, 0.22), (TOWER_CX, TOWER_CY, 1.30), M["limestone"]))
    parts.append(box("tower_band", (TOWER_W + 0.3, TOWER_D + 0.3, 0.25), (TOWER_CX, TOWER_CY, 7.075), M["limestone"]))
    parts.append(box("tower_cornice", (TOWER_W + 0.5, TOWER_D + 0.5, 0.4), (TOWER_CX, TOWER_CY, 11.75), M["limestone"]))

    # Ventanilla de cobro: cristal, marco de madera, rejilla, mostrador y caja de persiana.
    parts.append(box("teller_glass", (WINDOW_W - 0.1, 0.08, WINDOW_Z1 - WINDOW_Z0 - 0.2),
                     (TOWER_CX, TOWER_Y0 + 0.4, (WINDOW_Z0 + WINDOW_Z1) / 2), M["glass"]))
    for side in (-1, 1):
        parts.append(box("teller_jamb", (0.14, 0.28, WINDOW_Z1 - WINDOW_Z0),
                         (TOWER_CX + side * (WINDOW_W / 2 - 0.07), TOWER_Y0 + 0.24, (WINDOW_Z0 + WINDOW_Z1) / 2), M["wood"]))
    parts.append(box("teller_head", (WINDOW_W, 0.28, 0.14), (TOWER_CX, TOWER_Y0 + 0.24, WINDOW_Z1 - 0.07), M["wood"]))
    parts.append(box("teller_sill", (WINDOW_W, 0.28, 0.14), (TOWER_CX, TOWER_Y0 + 0.24, WINDOW_Z0 + 0.07), M["wood"]))
    for index in range(5):
        x = TOWER_CX - 1.36 + index * 0.68
        parts.append(box(f"bar{index}", (0.06, 0.06, WINDOW_Z1 - WINDOW_Z0 - 0.3), (x, TOWER_Y0 + 0.1, 4.9), M["metal"]))
    parts.append(box("bar_rail", (WINDOW_W - 0.3, 0.06, 0.06), (TOWER_CX, TOWER_Y0 + 0.1, 5.95), M["metal"]))
    parts.append(box("counter", (WINDOW_W + 0.5, 0.75, 0.28), (TOWER_CX, TOWER_Y0 - 0.125, 3.44), M["limestone"]))
    parts.append(box("shutter_box", (WINDOW_W + 0.3, 0.45, 0.45), (TOWER_CX, TOWER_Y0 + 0.1, 6.68), M["wood"]))

    # Ventana alta: cristal, marco de caliza y repisa.
    parts.append(box("upper_glass", (UPPER_WIN_W, 0.08, UPPER_WIN_Z1 - UPPER_WIN_Z0 - 0.2),
                     (TOWER_CX, TOWER_Y0 + 0.35, (UPPER_WIN_Z0 + UPPER_WIN_Z1) / 2), M["glass"]))
    for side in (-1, 1):
        parts.append(box("upper_jamb", (0.16, 0.2, UPPER_WIN_Z1 - UPPER_WIN_Z0),
                         (TOWER_CX + side * (UPPER_WIN_W / 2 + 0.06), TOWER_Y0 + 0.02, (UPPER_WIN_Z0 + UPPER_WIN_Z1) / 2), M["limestone"]))
        parts.append(box("upper_sill", (UPPER_WIN_W + 0.5, 0.35, 0.18), (TOWER_CX, TOWER_Y0 - 0.04, UPPER_WIN_Z0 - 0.09), M["limestone"]))
    parts.append(box("upper_head", (UPPER_WIN_W + 0.5, 0.35, 0.18), (TOWER_CX, TOWER_Y0 - 0.04, UPPER_WIN_Z1 + 0.09), M["limestone"]))

    # Ventana de la cara derecha: rompe el paño de ladrillo que ve la cámara alta desde ese lado.
    parts.append(box("side_glass", (0.08, 1.2, 2.2), (TOWER_X1 + 0.02, -6.0, 9.2), M["glass"]))
    for side in (-1, 1):
        parts.append(box("side_jamb", (0.18, 0.16, 2.2), (TOWER_X1 + 0.05, -6.0 + side * 0.66, 9.2), M["limestone"]))
    parts.append(box("side_sill", (0.35, 1.6, 0.2), (TOWER_X1 + 0.04, -6.0, 8.0), M["limestone"]))
    parts.append(box("side_head", (0.3, 1.6, 0.2), (TOWER_X1 + 0.03, -6.0, 10.4), M["limestone"]))

    # Bajante de acero en la esquina de la torre, con su embudo y dos abrazaderas.
    parts.append(cylinder("downpipe", 0.12, 11.4, (TOWER_X1 + 0.08, TOWER_Y0 + 0.24, 5.8), M["metal"], 8))
    parts.append(box("downpipe_hopper", (0.34, 0.34, 0.45), (TOWER_X1 + 0.08, TOWER_Y0 + 0.24, 11.45), M["metal"]))
    for z in (3.0, 7.0):
        parts.append(box("downpipe_bracket", (0.12, 0.34, 0.12), (TOWER_X1 + 0.02, TOWER_Y0 + 0.24, z), M["metal"]))

    # Tejado de la torre: tronco de pirámide y cuatro limas.
    parts.append(frustum("tower_roof", TOWER_PYR_W, TOWER_PYR_D, 2.2, 2.2, 11.90, TOWER_PYR_TOP, M["slate"],
                         center=(TOWER_CX, TOWER_CY)))
    for side_x in (-1, 1):
        for side_y in (-1, 1):
            parts.append(bar("tower_hip",
                             (TOWER_CX + side_x * TOWER_PYR_W / 2, TOWER_CY + side_y * TOWER_PYR_D / 2, TOWER_EAVE),
                             (TOWER_CX + side_x * 1.1, TOWER_CY + side_y * 1.1, TOWER_PYR_TOP),
                             0.24, 0.2, M["slate"]))

    # Linterna: basa, tambor de cristal, costillas, banda y capuchón con remate.
    base_z0, base_z1 = LANTERN_BASE
    glass_z0, glass_z1 = LANTERN_GLASS
    band_z0, band_z1 = LANTERN_BAND
    cap_z0, cap_z1 = LANTERN_CAP
    finial_z0, finial_z1 = LANTERN_FINIAL
    parts.append(box("lantern_base", (2.4, 2.4, base_z1 - base_z0), (TOWER_CX, TOWER_CY, (base_z0 + base_z1) / 2), M["limestone"]))
    parts.append(box("lantern_glass", (1.75, 1.75, glass_z1 - glass_z0), (TOWER_CX, TOWER_CY, (glass_z0 + glass_z1) / 2), M["glass"]))
    for side_x in (-1, 1):
        for side_y in (-1, 1):
            parts.append(box("lantern_rib", (0.1, 0.1, glass_z1 - glass_z0),
                             (TOWER_CX + side_x * 0.83, TOWER_CY + side_y * 0.83, (glass_z0 + glass_z1) / 2), M["metal"]))
    parts.append(box("lantern_band", (2.4, 2.4, band_z1 - band_z0), (TOWER_CX, TOWER_CY, (band_z0 + band_z1) / 2), M["limestone"]))
    parts.append(frustum("lantern_cap", 2.7, 2.7, 0.2, 0.2, cap_z0, cap_z1, M["slate"], center=(TOWER_CX, TOWER_CY)))
    parts.append(cylinder("finial", 0.07, finial_z1 - finial_z0, (TOWER_CX, TOWER_CY, (finial_z0 + finial_z1) / 2), M["metal"], 8))
    return parts


def build_barrier(M):
    """Barrera a rayas: poste de acero, contrapeso y brazo de ocho tramos rojos y blancos."""
    parts = []
    px, py = BARRIER
    parts.append(box("barrier_base", (1.2, 1.2, 0.22), (px, py, 0.11), M["metal"]))
    parts.append(box("barrier_post", (0.42, 0.42, 3.4), (px, py, 1.7), M["metal"]))
    parts.append(box("barrier_cap", (0.56, 0.56, 0.16), (px, py, 3.46), M["metal"]))
    parts.append(cylinder("barrier_pivot", 0.36, 0.5, (px, py, BOOM_Z), M["metal"], 10, (math.radians(90), 0.0, 0.0)))
    parts.append(box("barrier_arm", (1.3, 0.26, 0.26), (px + 0.65, py, BOOM_Z), M["metal"]))
    parts.append(box("barrier_weight", (0.3, 0.75, 1.15), (px + 1.25, py, BOOM_Z - 0.12), M["metal"]))
    parts.append(box("barrier_collar", (0.46, 0.46, 0.42), (px - 0.15, py, BOOM_Z), M["metal"]))

    for index in range(BOOM_STRIPES):
        x = BOOM_START_X - BOOM_STRIPE_W * (index + 0.5)
        mat = M["plastic_rojo"] if index % 2 == 0 else M["plastic_blanco"]
        parts.append(box(f"stripe{index}", (BOOM_STRIPE_W, 0.3, BOOM_TOP - BOOM_BOTTOM), (x, py, BOOM_Z), mat))
    parts.append(box("boom_tip", (0.24, 0.36, 0.36), (BOOM_END_X - 0.1, py, BOOM_Z), M["plastic_rojo"]))
    return parts


def group(parts, store):
    """Una malla por material y color: en Roblox cada malla lleva un solo material."""
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        rbx, suffix, rgb = RBX[key]
        name = f"tax_{key.replace('plastic', 'smoothplastic')}" if key.startswith("plastic") else f"tax_{key}"
        if len(members) == 1:
            mesh = members[0]
            mesh.name = name
            origin_at_zero(mesh)
        else:
            mesh = join(members, name)
        uv_unwrap(mesh)
        materials = {material.name for material in mesh.data.materials if material is not None}
        if len(materials) != 1:
            raise RuntimeError(f"{name} tiene {len(materials)} materiales: {sorted(materials)}")
        store.append({"key": name, "material": rbx, "rgb": rgb, "obj": mesh})


def bounds(objects):
    """Límites en studs a partir de los vértices de las mallas en coordenadas de escena."""
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
        "x": (round(min(xs), 2), round(max(xs), 2)),
        "y": (round(min(ys), 2), round(max(ys), 2)),
        "z": (round(min(zs), 2), round(max(zs), 2)),
        "alto_maximo_sobre_suelo": round(max(zs), 2),
    }


def lod_single(objects, name, material):
    """LOD1: una sola malla, un solo material y por debajo de la mitad de triángulos."""
    copies = []
    for source in objects:
        copy = source.copy()
        copy.data = source.data.copy()
        copy.name = f"{source.name}_lod"
        bpy.context.collection.objects.link(copy)
        copies.append(copy)
    lod = join(copies, name)
    decimate = lod.modifiers.new("Decimate", "DECIMATE")
    decimate.ratio = LOD_RATIO
    apply_modifiers(lod)
    lod.data.materials.clear()
    lod.data.materials.append(material)
    for polygon in lod.data.polygons:
        polygon.material_index = 0
    lod.hide_render = True
    return lod


def exported_triangles(path):
    """Cuenta los triángulos de una FBX ya escrita, importándola y borrando la copia.

    El exportador de FBX descarta unas pocas caras del LOD decimado: el número que se publica es el del
    archivo, no el de la malla en memoria.
    """
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, axis_forward="Z", axis_up="Y")
    imported = [obj for obj in bpy.data.objects if obj not in before and obj.type == "MESH"]
    if len(imported) != 1:
        raise RuntimeError(f"{os.path.basename(path)} tiene {len(imported)} mallas")
    triangles = count(imported[0])
    for obj in imported:
        bpy.data.objects.remove(obj, do_unlink=True)
    return triangles


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


def lights_and_world():
    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 4.2
    sun_data.angle = math.radians(1.0)
    sun = bpy.data.objects.new("sun", sun_data)
    bpy.context.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(90 - 34.0), 0.0, math.radians(-38.0))
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.68, 0.78, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    bpy.context.scene.world = world


def stage(M):
    """Solo escena de render: suelo, acera, calzada y sus líneas, para leer la escala y la altura."""
    box("ground", (320, 320, 0.4), (0.0, 0.0, -0.2), M["pavement"])
    box("walk_near", (200, 5.4, 0.3), (0.0, -13.3, 0.15), M["pavement"])
    box("road", (200, 32.0, 0.24), (0.0, -32.2, 0.06), M["asphalt"])
    for side in (-1, 1):
        box("kerb", (200, 0.45, 0.36), (0.0, -32.2 + side * 16.0, 0.06), M["cream"])
    dash = -100.0
    while dash < 100.0:
        box("dash", (5.0, 0.36, 0.02), (dash, -32.2, 0.19), M["cream"])
        dash += 11.0
    lights_and_world()


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

    parts = []
    parts += build_walls(M)
    parts += build_door(M)
    parts += build_window(M, WIN_XS[0])
    parts += build_window(M, WIN_XS[1])
    parts += build_porch(M)
    parts += build_roof(M)
    parts += build_tower(M)
    parts += build_barrier(M)
    group(parts, pieces)

    objects = [piece["obj"] for piece in pieces]
    total = sum(count(obj) for obj in objects)
    measured = bounds(objects)
    lod = lod_single(objects, "tax_LOD1", M["limestone"])
    lod_tris = count(lod)

    for piece in pieces:
        export(piece["obj"], piece["key"] + ".fbx")
    export(lod, "tax_LOD1.fbx")
    lod_fbx_tris = exported_triangles(os.path.join(OUT, "tax_LOD1.fbx"))

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "tipo": "lugar: aduana de la casilla Impuesto, sin añadidos de nivel",
        "origen": "centro de la base, z = 0 a ras de suelo, frente a -Y",
        "huella": {
            "ancho_maximo": LOT_WIDTH,
            "fondo_maximo": LOT_DEPTH,
            "vuelo_delantero_maximo_y": FRONT_LIMIT,
            "zona_libre": "ninguna",
        },
        "medidas": measured,
        "puerta": {
            "hueco_ancho": DOOR_W,
            "hueco_alto": DOOR_TOP,
            "paso_libre_entre_jambas": round(DOOR_W - 0.28, 2),
            "minimo": {"ancho": 2.4, "alto": 6.5},
        },
        "rotulo": {
            "texto": SIGN_TEXT,
            "letras_alto": MEASURED.get("rotulo", (0.0, 0.0))[1],
            "letras_ancho": MEASURED.get("rotulo", (0.0, 0.0))[0],
            "z": SIGN_Z,
            "material": "Slate",
            "rgb": "4A4E54",
        },
        "barrera": {
            "poste": {"x": BARRIER[0], "y": BARRIER[1], "alto": 3.54},
            "brazo": {"desde_x": BOOM_START_X, "hasta_x": round(BOOM_END_X, 2), "z": BOOM_Z, "tramos": BOOM_STRIPES},
        },
        "ventanilla": {
            "ancho": WINDOW_W,
            "alto": round(WINDOW_Z1 - WINDOW_Z0, 2),
            "z": [WINDOW_Z0, WINDOW_Z1],
            "mostrador": "caliza, vuela 0,5 sobre la fachada de la torre",
        },
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
        "niveles": {
            "0": {
                "triangulos_propios": total,
                "triangulos_acumulados": total,
                "limites": measured,
            }
        },
        "total_triangulos": total,
        "presupuesto_triangulos": TRIANGLE_BUDGET,
        "lod1": {
            "clave": "tax_LOD1",
            "triangulos": lod_fbx_tris,
            "triangulos_malla": lod_tris,
            "porcentaje_del_total": round(100.0 * lod_fbx_tris / total, 1),
            "mallas": 1,
            "material": "Limestone",
            "rgb": "D2C9B4",
        },
        "altura_maxima": measured["alto_maximo_sobre_suelo"],
        "altura_maxima_permitida": HEIGHT_MAX,
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("IMPUESTO_STATS", json.dumps({
        "total": total,
        "lod1_fbx": lod_fbx_tris,
        "lod1_malla": lod_tris,
        "medidas": measured,
        "piezas": [(piece["key"], count(piece["obj"])) for piece in pieces],
    }, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_fbx_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_fbx_tris} de {total}")
    if measured["alto_maximo_sobre_suelo"] > HEIGHT_MAX + 0.01:
        raise RuntimeError(f"Altura {measured['alto_maximo_sobre_suelo']} > {HEIGHT_MAX}")
    if measured["y"][0] < FRONT_LIMIT - 0.01:
        raise RuntimeError(f"Vuela más de la cuenta: y = {measured['y'][0]}")
    if measured["y"][1] > LOT_DEPTH / 2:
        raise RuntimeError(f"Se sale por el fondo: y = {measured['y'][1]}")
    if abs(measured["x"][0]) > LOT_WIDTH / 2 or measured["x"][1] > LOT_WIDTH / 2:
        raise RuntimeError(f"Se sale del solar a lo ancho: {measured['x']}")
    if measured["z"][0] < -0.01:
        raise RuntimeError(f"Baja del suelo: z = {measured['z'][0]}")

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "impuesto.blend"))

    # Solo el LOD se queda oculto: las piezas son las que se renderizan.
    lod.hide_render = True
    lod.hide_viewport = True
    stage(M)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass

    render(scene, camera("frontal", (0.0, -52.0, 14.0), (0.0, -1.5, 7.6), 45), f"{RENDER_SUBDIR}/impuesto-frontal.png")
    render(scene, camera("aereo", (30.0, -44.0, 40.0), (0.0, -2.0, 8.0), 42), f"{RENDER_SUBDIR}/impuesto-aereo.png")

    box("avatar_ref", (1.6, 1.2, 6.0), (-12.4, -9.9, 3.0), M["avatar"])
    render(scene, camera("comparacion", (4.0, -52.0, 15.5), (-2.0, -2.0, 7.5), 42), f"{RENDER_SUBDIR}/impuesto-comparacion.png")
    print("IMPUESTO_DONE")


if __name__ == "__main__":
    main()

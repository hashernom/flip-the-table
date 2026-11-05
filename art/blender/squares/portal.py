"""Portal: la casilla «Portal» del tablero, modelada desde cero.

Boca de metro monumental: arco de piedra caliza de medio punto abierto a ras de calle, con un pozo de
5,2 de fondo detras del vano. Dentro, una escalera de seis peldaños baja desde la calle hasta -1,8,
con pasamanos de acero y dados de pizarra en los costados, y el fondo lo cierra un plano oscuro: el
interior es un hueco real, no un muro pintado. Sobre el arco van la placa redonda y, en el ático, el
rótulo «PORTAL» en letras 3D. Sin neón, sin marcas y sin nada de casino.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, el frente da a -Y, el origen está en
el centro de la base y z = 0 a ras de suelo; solo el pozo de la escalera baja por debajo de la calle
(hasta -2,4 de macizo). Altura máxima: 18. Todo el vuelo queda dentro de y = -9.

Sigue la estructura de art/blender/buildings/cobre/barberia-morro.py: helpers importados de
art/blender/slice/build_cine_lux.py, una malla por material y color, LOD1 decimado, stats.json y
renders de revisión. El suelo de los renders lleva el hueco del pozo y una luz de relleno: ninguna de
las dos se exporta.

Salidas, en art/blender/squares/:
  portal.blend                    escena de revisión (no se versiona)
  portal/portal_<material>.fbx    una malla, un material y un color por FBX
  portal/portal_LOD1.fbx          una sola malla y un solo material, por debajo del 50 %
  portal/stats.json               triángulos por pieza, total, LOD1 y medidas
Y en art/render/squares/portal/: portal-frontal.png, portal-aereo.png y portal-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/squares/portal.py
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
OUT = os.path.join(HERE, "portal")
RENDER_SUBDIR = "squares/portal"
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
    perforate,
    render,
    select_only,
    textured,
    uv_unwrap,
)

# --------------------------------------------------------------------------------------------------
# Medidas. Todo en studs, frente a -Y, origen en el centro de la base y z = 0 en el suelo.
# --------------------------------------------------------------------------------------------------
WIDTH = 32.0
DEPTH = 18.0
HALF_W = WIDTH / 2.0
LOT_FRONT = -9.0
LOT_BACK = 9.0

# Cuerpo central de caliza con el arco de medio punto.
CEN_W = 20.0
CEN_FRONT = -7.0
CEN_BACK = 2.9
CEN_D = CEN_BACK - CEN_FRONT
CEN_Y = (CEN_FRONT + CEN_BACK) / 2.0
CEN_H = 13.6
OPEN_W = 10.0
OPEN_R = OPEN_W / 2.0
SPRING = 5.2
APEX = SPRING + OPEN_R
REVEAL = 0.55        # ancho del rebaje de piedra alrededor del arco

# La boca llega a ras de calle y la escalera baja por debajo: es un pozo, no un umbral elevado.
GRADE = 0.0
IN_STEPS = 6
IN_TREAD = 0.66
IN_RISE = 0.30
FLOOR_Z = -(IN_STEPS * IN_RISE)      # -1,8: fondo del pozo, por debajo de la calle
IN_START = CEN_FRONT + 0.35          # el primer peldaño entra 0,35 desde la fachada
IN_END = IN_START + IN_STEPS * IN_TREAD
TUNNEL_BACK = IN_END + 0.9           # rellano del fondo antes del plano oscuro
PIT_BOTTOM = FLOOR_Z - 0.6           # macizo bajo los peldaños

# Remate: cornisa, ático con el rótulo, cornisa superior, pretil y terraza.
CORNICE_Z0 = CEN_H
CORNICE_Z1 = 14.2
ATTIC_Z0 = CORNICE_Z1
ATTIC_Z1 = 16.4
ATTIC_W = 19.4
ATTIC_D = 9.8
TOP_CORNICE_Z1 = 16.85
PARAPET_Z1 = 17.2
PLAQUE_Z = 12.2
PLAQUE_R = 1.30
SIGN_Z = 15.3
SIGN_SIZE = 1.55

# Alas laterales y nave trasera: cierran la huella sin tapar el arco.
WING_X0 = 10.0
WING_X1 = 15.8
WING_FRONT = -6.6
WING_H = 9.2
WING_EAVE = 9.75
WING_RIDGE = 10.9
REAR_Y0 = CEN_BACK
REAR_Y1 = 8.7
REAR_H = 6.2
REAR_EAVE = 6.7
REAR_RIDGE = 8.0

# Límites y comprobaciones.
TRIANGLE_BUDGET = 3000
LOD_RATIO = 0.42
MAX_HEIGHT = 18.0
FLIGHT_LIMIT = -10.0
EPS = 0.03

# Material de Roblox, nombre de pieza y RGB. Un color por pieza y por FBX.
RBX = {
    "limestone": ("Limestone", "portal_limestone", "D2C9B4"),
    "brick": ("Brick", "portal_brick", "B0664A"),
    "slate": ("Slate", "portal_slate", "4A4E54"),
    "steel": ("Metal", "portal_steel", "A8AEB4"),
    "glass": ("Glass", "portal_glass", "2E4A63"),
    "interior": ("SmoothPlastic", "portal_interior", "2E3338"),
}


def make_materials():
    """Materiales de la guía y, solo para los renders, la calle, el asfalto y la figura."""
    return {
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "brick": textured("brick", "brick_warm", "B0664A"),
        "slate": flat("slate", "4A4E54", 0.85),
        "steel": flat("steel", "A8AEB4", 0.25, 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        # Plano del fondo del túnel: oscuro a propósito, fuera de la paleta de fachada.
        "interior": flat("interior", "2E3338", 0.75),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "avatar": flat("avatar", "6E747C", 0.8),
    }


# --------------------------------------------------------------------------------------------------
# Piezas propias que no están en los helpers compartidos.
# --------------------------------------------------------------------------------------------------
def cylinder_z(name, radius, z0, z1, location, mat, verts=12):
    """Cilindro vertical: respiraderos y remates."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts,
        radius=radius,
        depth=z1 - z0,
        end_fill_type="NGON",
        location=(location[0], location[1], (z0 + z1) / 2.0),
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def disc_y(name, radius, depth, y, z, mat, verts=24):
    """Disco con el eje en Y: la placa redonda mira a la calle."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts,
        radius=radius,
        depth=depth,
        end_fill_type="NGON",
        location=(0.0, y, z),
        rotation=(math.radians(90), 0.0, 0.0),
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def hip_roof(name, size_x, size_y, eave, ridge, mat, ridge_axis="x", location=(0.0, 0.0)):
    """Cubierta a cuatro aguas: dos faldones trapezoidales, dos triángulos y el fondo cerrado."""
    ox, oy = location
    half_x, half_y = size_x / 2.0, size_y / 2.0
    corners = [
        (ox - half_x, oy - half_y, eave),
        (ox + half_x, oy - half_y, eave),
        (ox + half_x, oy + half_y, eave),
        (ox - half_x, oy + half_y, eave),
    ]
    if ridge_axis == "x":
        run = max(0.0, size_x - size_y) / 2.0
        ridge_pts = [(ox - run, oy, ridge), (ox + run, oy, ridge)]
    else:
        run = max(0.0, size_y - size_x) / 2.0
        ridge_pts = [(ox, oy - run, ridge), (ox, oy + run, ridge)]
    faces = [(0, 1, 5, 4), (2, 3, 4, 5), (3, 0, 4), (1, 2, 5), (0, 3, 2, 1)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(corners + ridge_pts, [], faces)
    mesh.validate()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def beam_yz(name, x, start, end, width, depth, mat):
    """Barra en el plano YZ a x fijo: pasamanos inclinados de la escalera interior."""
    y0, z0 = start
    y1, z1 = end
    dy, dz = y1 - y0, z1 - z0
    length = math.hypot(dy, dz)
    obj = box(name, (width, length, depth), (x, (y0 + y1) / 2.0, (z0 + z1) / 2.0), mat)
    obj.rotation_euler = (math.atan2(-dz, dy), 0.0, 0.0)
    select_only(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return obj


def fit_width(obj, max_width):
    """Reduce el rótulo de forma uniforme si no cabe en el ancho previsto."""
    width = obj.dimensions.x
    if width > max_width:
        select_only(obj)
        factor = max_width / width
        obj.scale = (factor, factor, factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def step_top(y):
    """Altura del peldaño interior en una y dada: 0 en la calle y negativa dentro del pozo."""
    if y <= IN_START:
        return GRADE
    index = min(IN_STEPS - 1, int((y - IN_START) / IN_TREAD))
    return -(index + 1) * IN_RISE


# --------------------------------------------------------------------------------------------------
# Cuerpo: muro de caliza con el arco calado y el túnel ciego.
# --------------------------------------------------------------------------------------------------
def build_mass(M):
    """Muro central con el arco de medio punto y el túnel ciego que acaba en el plano oscuro."""
    parts = []
    wall = box("portal_mass", (CEN_W, CEN_D, CEN_H), (0.0, CEN_Y, CEN_H / 2.0), M["limestone"])
    # El corte no atraviesa el cuerpo: el fondo queda macizo y el túnel es ciego.
    cutter_front = CEN_FRONT - 0.4
    cutter_len = TUNNEL_BACK - cutter_front
    cutter_y = (cutter_front + TUNNEL_BACK) / 2.0

    bpy.ops.mesh.primitive_cylinder_add(
        vertices=32,
        radius=OPEN_R,
        depth=cutter_len,
        end_fill_type="NGON",
        location=(0.0, cutter_y, SPRING),
        rotation=(math.radians(90), 0.0, 0.0),
    )
    round_cut = bpy.context.active_object
    round_cut.name = "round_cut"
    jamb_cut = box("jamb_cut", (OPEN_W, cutter_len, SPRING + 2.7), (0.0, cutter_y, (SPRING - 2.7) / 2.0))
    # Rebaje de 0,3 delante: dibuja el marco de piedra del arco sin añadir volumen que haga sombras.
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=32,
        radius=OPEN_R + REVEAL,
        depth=0.34,
        end_fill_type="NGON",
        location=(0.0, CEN_FRONT - 0.17, SPRING),
        rotation=(math.radians(90), 0.0, 0.0),
    )
    reveal_round = bpy.context.active_object
    reveal_round.name = "reveal_round"
    reveal_jamb = box("reveal_jamb", (OPEN_W + 1.1, 0.34, SPRING + 0.8),
                      (0.0, CEN_FRONT - 0.17, (SPRING - 0.8) / 2.0))
    perforate(wall, [round_cut, jamb_cut, reveal_round, reveal_jamb])
    parts.append(wall)

    # Impostas en el arranque del arco y pilastras de las esquinas, apoyadas en la calle.
    for side in (-1, 1):
        parts.append(box("impost", (0.95, 0.42, 0.5), (side * (OPEN_R + 0.48), CEN_FRONT - 0.11, SPRING + 0.25), M["limestone"]))
        parts.append(box("pilaster", (1.15, 0.5, CEN_H - 0.35), (side * 9.42, CEN_FRONT - 0.25, (CEN_H + 0.35) / 2.0), M["limestone"]))
        parts.append(box("pilaster_base", (1.35, 0.62, 0.75), (side * 9.42, CEN_FRONT - 0.31, 0.725), M["limestone"]))
    # Zócalo de piedra bajo el muro, solo en las pilas (el centro es el pozo de la escalera).
    for side in (-1, 1):
        x0, x1 = sorted((side * (OPEN_W / 2.0 + 0.15), side * CEN_W / 2.0))
        parts.append(box("plinth", (x1 - x0, 0.28, 0.9), ((x0 + x1) / 2.0, CEN_FRONT - 0.14, 0.45), M["limestone"]))
    return parts


def build_entry(M):
    """Escalera que baja desde la calle al pozo, rellano del fondo, plano oscuro y pasamanos."""
    parts = []
    # Cada peldaño es macizo hasta el fondo del pozo: se ve el escalón, no un hueco.
    for index in range(IN_STEPS):
        top = -(index + 1) * IN_RISE
        parts.append(box("in_step", (OPEN_W + 0.2, IN_TREAD, top - PIT_BOTTOM),
                         (0.0, IN_START + (index + 0.5) * IN_TREAD, (top + PIT_BOTTOM) / 2.0), M["limestone"]))
    # Rellano del fondo, en sombra, y plano oscuro que cierra el túnel.
    parts.append(box("landing", (OPEN_W + 0.2, TUNNEL_BACK - IN_END, FLOOR_Z - PIT_BOTTOM),
                     (0.0, (IN_END + TUNNEL_BACK) / 2.0, (FLOOR_Z + PIT_BOTTOM) / 2.0), M["slate"]))
    parts.append(box("interior_plane", (OPEN_W + 0.6, 0.25, APEX + 0.6 - PIT_BOTTOM),
                     (0.0, TUNNEL_BACK - 0.12, (APEX + 0.6 + PIT_BOTTOM) / 2.0), M["interior"]))
    # Dados de pizarra en los costados del túnel: el interior no es un muro blanco.
    for side in (-1, 1):
        parts.append(box("tunnel_dado", (0.22, CEN_FRONT - TUNNEL_BACK, 3.4),
                         (side * (OPEN_W / 2.0 - 0.05), (CEN_FRONT + TUNNEL_BACK) / 2.0, FLOOR_Z + 1.7), M["slate"]))
        # Sardinel de piedra en el borde del pozo: remata el hueco del suelo.
        parts.append(box("pit_kerb", (0.32, CEN_FRONT - TUNNEL_BACK + 0.1, 0.26),
                         (side * (OPEN_W / 2.0 + 0.1), (CEN_FRONT + TUNNEL_BACK) / 2.0, 0.13), M["limestone"]))
    # Pasamanos de acero a los dos lados, anclados en los peldaños.
    rail_start = (IN_START + 0.05, 0.95)
    rail_end = (IN_END - 0.1, FLOOR_Z + 0.95)
    span = rail_end[0] - rail_start[0]
    for side in (-1, 1):
        parts.append(beam_yz("handrail", side * 3.6, rail_start, rail_end, 0.16, 0.16, M["steel"]))
        for post_y in (IN_START + 0.25, IN_START + 2.0, IN_START + 3.6):
            t = (post_y - rail_start[0]) / span
            rail_z = rail_start[1] + t * (rail_end[1] - rail_start[1])
            base_z = step_top(post_y)
            parts.append(box("rail_post", (0.14, 0.14, rail_z - base_z), (side * 3.6, post_y,
                                                                        (base_z + rail_z) / 2.0), M["steel"]))
    return parts


def build_crown(M):
    """Cornisa, ático con el rótulo, cornisa superior, pretil, terraza y remates de cubierta."""
    parts = []
    parts.append(box("cornice", (CEN_W + 0.9, CEN_D + 0.5, CORNICE_Z1 - CORNICE_Z0),
                     (0.0, CEN_Y, (CORNICE_Z0 + CORNICE_Z1) / 2.0), M["limestone"]))
    parts.append(box("attic", (ATTIC_W, ATTIC_D, ATTIC_Z1 - ATTIC_Z0),
                     (0.0, CEN_Y, (ATTIC_Z0 + ATTIC_Z1) / 2.0), M["limestone"]))
    parts.append(box("top_cornice", (ATTIC_W + 1.2, ATTIC_D + 0.4, 0.45),
                     (0.0, CEN_Y, ATTIC_Z1 + 0.225), M["limestone"]))
    # Terraza de piedra dentro del pretil: lo que ve la cámara alta.
    parts.append(box("deck", (ATTIC_W + 0.3, ATTIC_D - 0.3, 0.12), (0.0, CEN_Y, ATTIC_Z1 + 0.51), M["limestone"]))
    half_w, half_d = (ATTIC_W + 0.9) / 2.0, (ATTIC_D + 0.1) / 2.0
    for name, size, location in (
        ("parapet_front", (ATTIC_W + 0.9, 0.4, 0.4), (0.0, -half_d + 0.2, ATTIC_Z1 + 0.85)),
        ("parapet_back", (ATTIC_W + 0.9, 0.4, 0.4), (0.0, half_d - 0.2, ATTIC_Z1 + 0.85)),
        ("parapet_east", (0.4, ATTIC_D + 0.1, 0.4), (half_w - 0.2, 0.0, ATTIC_Z1 + 0.85)),
        ("parapet_west", (0.4, ATTIC_D + 0.1, 0.4), (-half_w + 0.2, 0.0, ATTIC_Z1 + 0.85)),
    ):
        parts.append(box(name, size, (location[0], location[1] + CEN_Y, location[2]), M["limestone"]))
    for name, size, location in (
        ("coping_front", (ATTIC_W + 1.2, 0.6, 0.15), (0.0, -half_d + 0.2, ATTIC_Z1 + 1.12)),
        ("coping_back", (ATTIC_W + 1.2, 0.6, 0.15), (0.0, half_d - 0.2, ATTIC_Z1 + 1.12)),
        ("coping_east", (0.6, ATTIC_D + 0.4, 0.15), (half_w - 0.2, 0.0, ATTIC_Z1 + 1.12)),
        ("coping_west", (0.6, ATTIC_D + 0.4, 0.15), (-half_w + 0.2, 0.0, ATTIC_Z1 + 1.12)),
    ):
        parts.append(box(name, size, (location[0], location[1] + CEN_Y, location[2]), M["slate"]))
    # Dos respiraderos de acero en la terraza, lejos del rótulo.
    for x in (-7.6, 7.6):
        parts.append(cylinder_z("deck_vent", 0.32, ATTIC_Z1 + 0.57, ATTIC_Z1 + 1.02, (x, 0.6), M["steel"], 10))
    return parts


def build_plaque(M):
    """Placa redonda sobre el arco: respaldo de acero, cara de pizarra en relieve y una P de caliza."""
    parts = []
    parts.append(disc_y("plaque_back", PLAQUE_R, 0.42, CEN_FRONT - 0.13, PLAQUE_Z, M["steel"], 24))
    # La cara va por delante del respaldo: así el aro de acero se lee como un cerco.
    parts.append(disc_y("plaque_face", PLAQUE_R - 0.24, 0.22, CEN_FRONT - 0.39, PLAQUE_Z, M["slate"], 24))
    letter = letters("P", 1.3, (0.0, CEN_FRONT - 0.55, PLAQUE_Z), M["limestone"], depth=0.17)
    parts.append(letter)
    return parts


def build_sign(M):
    """Rótulo «PORTAL» en letras 3D de pizarra sobre la entrada, en el ático."""
    label = letters("PORTAL", SIGN_SIZE, (0.0, CEN_Y - ATTIC_D / 2.0 - 0.03, SIGN_Z), M["slate"], depth=0.22)
    return [fit_width(label, 15.0)]


def build_wings(M):
    """Alas laterales de caliza con taquilla acristalada, cornisa y cubierta a cuatro aguas."""
    parts = []
    depth = CEN_BACK - WING_FRONT
    for side in (-1, 1):
        cx = (WING_X0 + WING_X1) / 2.0 * side
        parts.append(box("wing", (WING_X1 - WING_X0, depth, WING_H), (cx, (WING_FRONT + CEN_BACK) / 2.0, WING_H / 2.0), M["limestone"]))
        parts.append(box("wing_plinth", (WING_X1 - WING_X0, 0.26, 0.9), (cx, WING_FRONT - 0.13, 0.45), M["limestone"]))
        parts.append(box("wing_cornice", (WING_X1 - WING_X0 + 0.4, depth + 0.3, 0.55),
                         (cx, (WING_FRONT + CEN_BACK) / 2.0, WING_H + 0.275), M["limestone"]))
        # Taquilla: cristal con marco de acero y alféizar de caliza.
        win_y = WING_FRONT - 0.06
        parts.append(box("ticket_glass", (3.0, 0.12, 2.9), (cx, win_y, 4.5), M["glass"]))
        parts.append(box("ticket_head", (3.4, 0.3, 0.22), (cx, win_y - 0.06, 6.05), M["steel"]))
        parts.append(box("ticket_sill", (3.4, 0.42, 0.24), (cx, win_y - 0.08, 2.95), M["limestone"]))
        for offset in (-1.6, 1.6):
            parts.append(box("ticket_jamb", (0.18, 0.24, 3.1), (cx + offset, win_y - 0.05, 4.5), M["steel"]))
        parts.append(box("ticket_mullion", (0.14, 0.2, 2.9), (cx, win_y - 0.08, 4.5), M["steel"]))
        # Cubierta a cuatro aguas y chimenea.
        parts.append(hip_roof("wing_roof", WING_X1 - WING_X0 + 0.4, depth + 0.5, WING_EAVE, WING_RIDGE, M["slate"],
                              ridge_axis="y", location=(cx, (WING_FRONT + CEN_BACK) / 2.0)))
        ridge_len = max(0.0, (depth + 0.5) - (WING_X1 - WING_X0 + 0.4))
        parts.append(box("wing_ridge", (0.5, ridge_len + 0.3, 0.26), (cx, (WING_FRONT + CEN_BACK) / 2.0, WING_RIDGE + 0.05), M["slate"]))
        parts.append(box("wing_chimney", (0.85, 0.85, 1.7), (cx, 0.9, WING_RIDGE + 0.55), M["limestone"]))
        parts.append(box("wing_chimney_cap", (1.1, 1.1, 0.16), (cx, 0.9, WING_RIDGE + 1.48), M["slate"]))
    return parts


def build_rear(M):
    """Nave trasera de ladrillo: cierra la huella y deja ver la cubierta desde el aire."""
    parts = []
    depth = REAR_Y1 - REAR_Y0
    cy = (REAR_Y0 + REAR_Y1) / 2.0
    # La nave no pasa de ±16: el ancho útil de la huella son 32 justos.
    parts.append(box("rear", (WIDTH - 0.4, depth, REAR_H), (0.0, cy, REAR_H / 2.0), M["brick"]))
    parts.append(box("rear_plinth", (WIDTH - 0.1, 0.24, 0.85), (0.0, REAR_Y0 + 0.12, 0.425), M["limestone"]))
    parts.append(box("rear_cornice", (WIDTH - 0.1, depth + 0.3, 0.5), (0.0, cy, REAR_H + 0.25), M["limestone"]))
    parts.append(hip_roof("rear_roof", WIDTH - 0.1, depth + 0.45, REAR_EAVE, REAR_RIDGE, M["slate"],
                          ridge_axis="x", location=(0.0, cy)))
    ridge_len = max(0.0, (WIDTH - 0.1) - (depth + 0.45))
    parts.append(box("rear_ridge", (ridge_len + 0.3, 0.5, 0.26), (0.0, cy, REAR_RIDGE + 0.05), M["slate"]))
    for x in (-11.5, 11.5):
        parts.append(cylinder_z("rear_vent", 0.3, REAR_EAVE + 0.35, REAR_EAVE + 0.95, (x, cy), M["steel"], 10))
    return parts


def group(parts, store):
    """Une las piezas en una malla por material y color: en Roblox cada malla lleva un solo material."""
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
        materials = {material.name for material in mesh.data.materials if material is not None}
        if len(materials) != 1:
            raise RuntimeError(f"{name} tiene {len(materials)} materiales")
        store.append({"key": name, "material": rbx, "rgb": rgb, "obj": mesh})
    return store


def bounds(objects):
    """Límites reales en studs a partir de los vértices de las mallas, en coordenadas de escena."""
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
    }


def build_lod(objects, material, name, ratio):
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
    decimate.ratio = ratio
    apply_modifiers(lod)
    select_only(lod)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris(quad_method="BEAUTY", ngon_method="BEAUTY")
    bpy.ops.object.mode_set(mode="OBJECT")
    lod.data.materials.clear()
    lod.data.materials.append(material)
    for polygon in lod.data.polygons:
        polygon.material_index = 0
    return lod


def fbx_info(path):
    """Importa una FBX y devuelve sus mallas, materiales y triángulos reales."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, axis_forward="Z", axis_up="Y")
    fresh = [obj for obj in bpy.data.objects if obj not in before and obj.type == "MESH"]
    materials = {material.name for obj in fresh for material in obj.data.materials if material is not None}
    tris = sum(count(obj) for obj in fresh)
    for obj in fresh:
        bpy.data.objects.remove(obj, do_unlink=True)
    return len(fresh), len(materials), tris


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


def tunnel_fill():
    """Relleno solo para los renders: en el juego la boca lleva su propia luz. No se exporta."""
    data = bpy.data.lights.new("tunnel_fill", "AREA")
    data.shape = "RECTANGLE"
    data.size = 5.0
    data.size_y = 2.0
    data.energy = 900.0
    data.color = (1.0, 0.94, 0.86)
    obj = bpy.data.objects.new("tunnel_fill", data)
    bpy.context.collection.objects.link(obj)
    obj.location = (0.0, -3.4, 9.0)
    obj.rotation_euler = (math.radians(-12.0), 0.0, 0.0)


def render_ground(M):
    """Suelo de la escena de render, con el hueco del pozo: si fuera una losa taparía la escalera."""
    x0 = -(OPEN_W / 2.0 + 0.2)
    x1 = OPEN_W / 2.0 + 0.2
    y0 = CEN_FRONT - 0.2
    y1 = TUNNEL_BACK + 0.2
    box("ground_sur", (200.0, y0 + 42.0, 0.4), (0.0, (y0 - 42.0) / 2.0, -0.2), M["pavement"])
    box("ground_norte", (200.0, 42.0 - y1, 0.4), (0.0, (y1 + 42.0) / 2.0, -0.2), M["pavement"])
    box("ground_oeste", (x0 + 100.0, y1 - y0, 0.4), ((x0 - 100.0) / 2.0, (y0 + y1) / 2.0, -0.2), M["pavement"])
    box("ground_este", (100.0 - x1, y1 - y0, 0.4), ((x1 + 100.0) / 2.0, (y0 + y1) / 2.0, -0.2), M["pavement"])


def street(M):
    """Acera, calzada y farolas: solo escena de render, nunca se exporta."""
    render_ground(M)
    box("sidewalk_edge", (200.0, 0.4, 0.18), (0.0, -13.2, 0.09), M["cream"])
    box("road", (200.0, 14.0, 0.06), (0.0, -20.4, 0.03), M["asphalt"])
    dash = -95.0
    while dash < 95.0:
        box("dash", (5.0, 0.4, 0.03), (dash, -20.4, 0.065), M["cream"])
        dash += 11.0
    for x in (-26.0, 26.0):
        box("lamp_post", (0.32, 0.32, 10.5), (x, -12.4, 5.25), M["dark"])
        box("lamp_arm", (0.24, 2.2, 0.24), (x, -13.5, 10.5), M["dark"])
        box("lamp_head", (0.8, 1.1, 0.3), (x, -14.5, 10.4), M["cream"])


def six_stud_figure(M, x, y):
    """Figura de 6 studs para la comparación: piernas, torso y cabeza. Solo render."""
    return [
        box("avatar_leg_l", (0.45, 0.6, 1.7), (x - 0.3, y, 0.85), M["avatar"]),
        box("avatar_leg_r", (0.45, 0.6, 1.7), (x + 0.3, y, 0.85), M["avatar"]),
        box("avatar_body", (1.25, 0.75, 2.5), (x, y, 2.95), M["avatar"]),
        box("avatar_head", (0.85, 0.85, 1.6), (x, y, 5.2), M["avatar"]),
    ]


def hide_all():
    for obj in bpy.data.objects:
        obj.hide_render = True
        obj.hide_viewport = True


def place(sources):
    for source in sources:
        copy = source.copy()
        copy.location = (0.0, 0.0, 0.0)
        copy.hide_render = False
        copy.hide_viewport = False
        bpy.context.collection.objects.link(copy)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    scene.unit_settings.scale_length = 1.0
    os.makedirs(OUT, exist_ok=True)
    render_dir = os.path.join(REPO, "art", "render", *RENDER_SUBDIR.split("/"))
    os.makedirs(render_dir, exist_ok=True)

    M = make_materials()
    parts = []
    parts += build_mass(M)
    parts += build_entry(M)
    parts += build_crown(M)
    parts += build_plaque(M)
    parts += build_sign(M)
    parts += build_wings(M)
    parts += build_rear(M)

    pieces = []
    group(parts, pieces)

    objects = [piece["obj"] for piece in pieces]
    total = sum(count(obj) for obj in objects)
    measured = bounds(objects)

    lod = build_lod(objects, M["limestone"], "portal_LOD1", LOD_RATIO)
    lod_tris = count(lod)

    for piece in pieces:
        export(piece["obj"], piece["key"] + ".fbx")
        meshes, materials, tris = fbx_info(os.path.join(OUT, piece["key"] + ".fbx"))
        piece["mallas_fbx"] = meshes
        piece["materiales_fbx"] = materials
        piece["triangulos_fbx"] = tris
    export(lod, "portal_LOD1.fbx")
    lod_meshes, lod_materials, lod_fbx_tris = fbx_info(os.path.join(OUT, "portal_LOD1.fbx"))

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "tipo": "lugar: boca de metro monumental, sin niveles",
        "origen": "centro de la base, z = 0 a ras de suelo, frente a -Y",
        "huella": {
            "ancho": WIDTH,
            "fondo": DEPTH,
            "x": [-HALF_W, HALF_W],
            "y": [LOT_FRONT, LOT_BACK],
            "vuelo_permitido_y": FLIGHT_LIMIT,
            "vuelo_usado_y": measured["y"][0],
        },
        "medidas": {**measured, "alto_maximo_sobre_suelo": measured["z"][1]},
        "boca": {
            "ancho": OPEN_W,
            "alto_libre": round(APEX - GRADE, 2),
            "a_ras_de_calle": GRADE,
            "escalera": {
                "peldaños": IN_STEPS,
                "contrahuella": round(IN_RISE, 2),
                "huella": IN_TREAD,
                "desciende_hasta": round(FLOOR_Z, 2),
            },
            "rehundido": round(CEN_FRONT - TUNNEL_BACK, 2),
            "plano_oscuro_y": round(TUNNEL_BACK, 2),
            "nota": "la escalera baja por debajo del nivel de calle: el conjunto apoya en z = 0",
        },
        "piezas": [
            {
                "clave": piece["key"],
                "material": piece["material"],
                "rgb": piece["rgb"],
                "triangulos": count(piece["obj"]),
                "triangulos_en_fbx": piece["triangulos_fbx"],
                "mallas_en_fbx": piece["mallas_fbx"],
                "materiales_en_fbx": piece["materiales_fbx"],
            }
            for piece in pieces
        ],
        "total_triangulos": total,
        "presupuesto_triangulos": TRIANGLE_BUDGET,
        "altura_maxima_permitida": MAX_HEIGHT,
        "lod1": {
            "archivo": "portal_LOD1.fbx",
            "mallas": lod_meshes,
            "materiales": lod_materials,
            "material": "Limestone",
            "rgb": "D2C9B4",
            "triangulos": lod_fbx_tris,
            "triangulos_antes_de_exportar": lod_tris,
            "porcentaje_del_total": round(100.0 * lod_fbx_tris / total, 1),
        },
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("PORTAL_STATS", json.dumps({"total": total, "lod1": lod_fbx_tris, "medidas": measured,
                                      "piezas": len(pieces)}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_fbx_tris >= total / 2 or lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris}/{lod_fbx_tris} de {total}")
    if any(piece["mallas_fbx"] != 1 for piece in pieces) or lod_meshes != 1:
        raise RuntimeError("alguna FBX no tiene una sola malla")
    if any(piece["materiales_fbx"] != 1 for piece in pieces) or lod_materials != 1:
        raise RuntimeError("alguna FBX no tiene un solo material")
    if sum(piece["triangulos_fbx"] for piece in pieces) != total:
        raise RuntimeError("los triángulos de las FBX no suman el total")
    if measured["x"][0] < -HALF_W - EPS or measured["x"][1] > HALF_W + EPS:
        raise RuntimeError(f"Se sale a lo ancho: {measured['x']}")
    if measured["y"][0] < LOT_FRONT - EPS or measured["y"][1] > LOT_BACK + EPS:
        raise RuntimeError(f"Se sale de la huella: {measured['y']}")
    if measured["y"][0] < FLIGHT_LIMIT:
        raise RuntimeError(f"Vuela más allá de y = {FLIGHT_LIMIT}: {measured['y'][0]}")
    if measured["z"][0] < PIT_BOTTOM - EPS or measured["z"][1] > MAX_HEIGHT + EPS:
        raise RuntimeError(f"Altura fuera de rango: {measured['z']}")
    if APEX - GRADE < 6.5:
        raise RuntimeError("La boca no deja pasar a un avatar de 6")

    # Escena de revisión: las mallas de origen se ocultan y los renders montan copias.
    for obj in objects + [lod]:
        obj.hide_render = True
        obj.hide_viewport = True
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "portal.blend"))

    place(objects)
    street(M)
    lights_and_world()
    tunnel_fill()
    render(scene, camera("frontal", (0.0, -54.0, 10.6), (0.0, -2.0, 8.4), 46), f"{RENDER_SUBDIR}/portal-frontal.png")
    render(scene, camera("aereo", (34.0, -46.0, 44.0), (-1.5, 1.5, 5.5), 40), f"{RENDER_SUBDIR}/portal-aereo.png")

    # Comparación: el portal junto a una figura de 6 studs, a la escala real del juego.
    hide_all()
    render_ground(M)
    place(objects)
    for part in six_stud_figure(M, 5.6, -10.6):
        part.hide_render = False
        part.hide_viewport = False
    lights_and_world()
    tunnel_fill()
    render(scene, camera("comparacion", (-20.0, -48.0, 13.0), (0.0, -4.5, 8.0), 36), f"{RENDER_SUBDIR}/portal-comparacion.png")
    print("PORTAL_DONE")


if __name__ == "__main__":
    main()

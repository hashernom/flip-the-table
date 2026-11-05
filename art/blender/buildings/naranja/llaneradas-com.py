"""llaneradas.com: restaurante de asados de la zona Naranja (Feria Naranja), modelado desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de 15,5: casa de ladrillo con cubierta de pizarra a dos aguas, ala baja
de despensa a la derecha y el asador con su chimenea de ladrillo en el centro de la fachada. Cinco añadidos
que se suman: porche de madera con toldo, ventanal con el comedor, asador y chimenea, pabellón de comedor
retranqueado sobre el ala y torre de la chimenea con remate de oro.

La silueta es la de un asadero: cubierta a dos aguas, porche de madera y una chimenea de ladrillo que
sobresale del tejado. No es una caja con ventanas: el cuerpo tiene huecos de verdad (perforate), marcos,
cornisa y placa. Se distingue de sus vecinas (nave de hierro con reloj; casa estrecha con toldo y secadero)
por la chimenea y la cubierta a dos aguas, y por ser más baja que las dos.

Salidas, en art/blender/buildings/naranja/:
  llaneradas-com.blend                       escena de revisión (no se versiona)
  llaneradas-com/llaneradas_<pieza>_<material>.fbx y llaneradas_LOD1.fbx
  llaneradas-com/stats.json                  triángulos por pieza y nivel, límites y materiales
Y en art/render/naranja/llaneradas-com/: llaneradas-com-niveles.png y llaneradas-com-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/naranja/llaneradas-com.py
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
OUT = os.path.join(HERE, "llaneradas-com")
RENDER_SUBDIR = "naranja/llaneradas-com"
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

# Huella del solar.
WIDTH = 32.0
DEPTH = 18.0
FRONT = -6.0  # fachada del cuerpo principal
BACK = 8.0
MAIN_X0, MAIN_X1 = -16.0, 6.0  # casa principal: 22 de ancho
WING_X0, WING_X1 = 6.0, 16.0  # ala de despensa: 10 de ancho
WING_FRONT = -5.2

EAVE = 15.5  # altura del cuerpo (masa principal)
RIDGE_Y = 1.0
RIDGE_Z = 18.3  # cumbrera de la cubierta a dos aguas
WING_TOP = 8.2  # ala baja: muro
WING_ROOF = 8.5  # ala baja: cara superior de la cubierta

# Puerta: 2,8 × 7,2, muy por encima de la figura de 6.
DOOR_X = -12.8
DOOR_W = 2.8
DOOR_TOP = 7.2

# Ventanal del comedor, abierto de verdad en el ladrillo.
WIN_X0, WIN_X1 = -7.5, 1.5
WIN_CX = (WIN_X0 + WIN_X1) / 2
WIN_W = WIN_X1 - WIN_X0
WIN_Z0, WIN_Z1 = 1.0, 6.6
WIN_H = WIN_Z1 - WIN_Z0

# Asador: pecho de ladrillo y chimenea, en el centro de la fachada.
ASADOR_X0, ASADOR_X1 = 2.35, 5.95
ASADOR_CX = (ASADOR_X0 + ASADOR_X1) / 2
ASADOR_Y0, ASADOR_Y1 = -8.6, -6.0
BREAST_TOP = 8.6
CHIMNEY_L0 = 20.2  # tope del nivel 0 completo: la calle mantiene su altura
CROWN_H = 0.5
CROWN_SHAFT = 2.7
CROWN_BAND = 0.3
CROWN_PLATE = 0.18
CHIMNEY_L3 = CHIMNEY_L0 + CROWN_H + CROWN_SHAFT + CROWN_BAND + CROWN_PLATE  # 23,88
TOWER_LOW_H = 4.55
TOWER_BAND_H = 0.24
TOWER_HIGH_H = 2.96
TOWER_MID = CHIMNEY_L3 + TOWER_LOW_H  # 28,43
TOWER_END = TOWER_MID + TOWER_BAND_H + TOWER_HIGH_H  # 31,63
TOWER_BAND_TOP = TOWER_END + TOWER_BAND_H  # 31,87
COLLAR_TOP = TOWER_BAND_TOP + 0.2  # 32,07
CAP_TOP = COLLAR_TOP + 1.38  # 33,45
FINIAL_TOP = CAP_TOP + 0.35  # 33,80
MAX_HEIGHT = 34.0

# Porche y toldo.
PORCH_X0, PORCH_X1 = -16.0, 2.4
PORCH_FRONT = -9.9  # nada delante de y = -10
POST_Y = -9.45
POST_TOP = 7.05
DECK_TOP = 0.3

# Placa y rótulo.
PLACA_X = -4.8
PLACA_Z = 10.3
PLACA_W = 11.6

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
LEVEL0_MAX = 20.5

# Material de Roblox, sufijo de color y RGB de cada clave de material de Blender.
RBX = {
    "brick": ("Brick", "", "B0664A"),  # 176, 102, 74
    "limestone": ("Limestone", "", "D2C9B4"),  # 210, 201, 180
    "slate": ("Slate", "", "4A4E54"),  # 74, 78, 84
    "glass": ("Glass", "", "2E4A63"),  # 46, 74, 99
    "wood": ("Wood", "", "6B4A2E"),  # 107, 74, 46
    "metal_acero": ("Metal", "_acero", "A8AEB4"),  # 168, 174, 180
    "metal_oro": ("Metal", "_oro", "C9A227"),  # 201, 162, 39
    "fabric_rojo": ("Fabric", "_rojo", "C4382B"),  # 196, 56, 43
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "wood": flat("wood", "6B4A2E", 0.7),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.4, 0.9),
        "metal_oro": flat("metal_oro", "C9A227", 0.3, 0.9),
        "fabric_rojo": flat("fabric_rojo", "C4382B", 0.8),
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


def prism(name, x0, x1, profile, mat):
    """Perfil en Y-Z extruido a lo largo de X: el volumen de la cubierta a dos aguas."""
    n = len(profile)
    verts = [(x0, y, z) for y, z in profile] + [(x1, y, z) for y, z in profile]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, j + n, i + n))
    return from_faces(name, verts, faces, mat)


def frustum(name, cx, cy, sx0, sy0, z0, sx1, sy1, z1, mat):
    """Tronco de pirámide de base rectangular, para el remate de la torre."""
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


def slab(name, x0, x1, y0, z0, y1, z1, thick, mat, lift=0.03):
    """Losa inclinada con su cara inferior sobre la recta (y0, z0)-(y1, z1) del plano de cubierta."""
    dy, dz = y1 - y0, z1 - z0
    length = math.hypot(dy, dz)
    if length == 0:
        raise ValueError(f"{name}: losa sin longitud")
    angle = math.atan2(dz, dy)
    if dy >= 0:
        ny, nz = -dz / length, dy / length
    else:
        ny, nz = dz / length, -dy / length
    cx = (x0 + x1) / 2.0
    cy = (y0 + y1) / 2.0 + ny * (thick / 2.0 + lift)
    cz = (z0 + z1) / 2.0 + nz * (thick / 2.0 + lift)
    obj = box(name, (x1 - x0, length, thick), (cx, cy, cz), mat)
    obj.rotation_euler = (angle, 0.0, 0.0)
    return obj


def cylinder(name, radius, depth, location, mat, verts, caps, rotation=(0.0, 0.0, 0.0)):
    """Cilindro, vertical por defecto. Para el asador se tumba (rotación X o Y de 90°)."""
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


def roof_z(y):
    """Altura del faldón delantero de la cubierta en un y dado (ladrillo bajo la pizarra)."""
    return 15.4 + (RIDGE_Z - 15.4) / (RIDGE_Y - FRONT) * (y - FRONT)


def roof_z_back(y):
    """Altura del faldón trasero, que baja hacia el fondo."""
    return 15.4 + (RIDGE_Z - 15.4) / (BACK - RIDGE_Y) * (BACK - y)


def chair(parts, M, x, y, z):
    """Silla de comedor en tres cajas: asiento, respaldo y pie. Se ve por el ventanal."""
    parts.append(box("silla_pie", (0.6, 0.6, 1.5), (x, y, z + 0.75), M["wood"]))
    parts.append(box("silla_asiento", (0.8, 0.8, 0.18), (x, y, z + 1.6), M["wood"]))
    parts.append(box("silla_respaldo", (0.8, 0.14, 1.3), (x, y + 0.33, z + 2.3), M["wood"]))


def table(parts, M, x, y, z):
    """Mesa de comedor: tablero y pie central."""
    parts.append(box("mesa_pie", (0.4, 0.4, 2.5), (x, y, z + 1.25), M["wood"]))
    parts.append(box("mesa_tablero", (1.8, 1.0, 0.2), (x, y, z + 2.6), M["wood"]))


def build_body(M):
    """Nivel 0: la casa de ladrillo, la cubierta, la puerta, el ventanal, la placa y el asador con su chimenea."""
    parts = []

    # Cuerpo principal: huecos de verdad para la puerta y el ventanal.
    body = box("body", (MAIN_X1 - MAIN_X0, BACK - FRONT, EAVE), ((MAIN_X0 + MAIN_X1) / 2, (FRONT + BACK) / 2, EAVE / 2), M["brick"])
    door_cut = box("door_cut", (DOOR_W, 1.9, DOOR_TOP + 0.2), (DOOR_X, FRONT + 0.75, (DOOR_TOP + 0.2) / 2))
    win_cut = box("win_cut", (WIN_W, 1.9, WIN_H), (WIN_CX, FRONT + 0.75, (WIN_Z0 + WIN_Z1) / 2))
    perforate(body, [door_cut, win_cut])
    parts.append(body)

    # Ala baja de despensa y cocina, retranqueada de la fachada.
    wing = box("wing", (WING_X1 - WING_X0, BACK - WING_FRONT, WING_TOP), ((WING_X0 + WING_X1) / 2, (WING_FRONT + BACK) / 2, WING_TOP / 2), M["brick"])
    service_cut = box("service_cut", (2.4, 1.4, 6.6), (12.6, WING_FRONT + 0.5, 3.3))
    pantry_cut = box("pantry_cut", (2.0, 1.4, 2.4), (9.3, WING_FRONT + 0.5, 4.2))
    perforate(wing, [service_cut, pantry_cut])
    parts.append(wing)

    # Volumen de la cubierta a dos aguas y sus faldones de pizarra.
    parts.append(prism("gable", MAIN_X0, MAIN_X1, [(FRONT, 15.4), (RIDGE_Y, RIDGE_Z), (BACK, 15.4)], M["brick"]))
    parts.append(slab("roof_front", MAIN_X0 - 0.55, MAIN_X1 + 0.02, -6.55, roof_z(-6.55), 1.03, roof_z(1.03), 0.3, M["slate"]))
    parts.append(slab("roof_back", MAIN_X0 - 0.55, MAIN_X1 + 0.02, 8.55, roof_z_back(8.55), 0.97, roof_z_back(0.97), 0.3, M["slate"]))
    parts.append(box("roof_ridge", (MAIN_X1 - MAIN_X0 + 0.57, 0.95, 0.22), ((MAIN_X0 - 0.55 + MAIN_X1 + 0.02) / 2, RIDGE_Y, roof_z(RIDGE_Y) + 0.27), M["slate"]))
    parts.append(box("wing_roof", (WING_X1 - WING_X0 + 0.3, BACK - WING_FRONT + 0.3, 0.3), ((WING_X0 + WING_X1) / 2, (WING_FRONT + BACK) / 2, WING_ROOF - 0.15), M["slate"]))

    # Zócalo, cornisa de caliza y las cornisas del ala.
    plinth = box("plinth", (MAIN_X1 - MAIN_X0 + 0.4, BACK - FRONT, 0.5), ((MAIN_X0 + MAIN_X1) / 2, (FRONT + BACK) / 2, 0.25), M["limestone"])
    perforate(plinth, [box("plinth_cut", (DOOR_W, 1.9, 0.6), (DOOR_X, FRONT + 0.75, 0.3))])
    parts.append(plinth)
    parts.append(box("cornice", (MAIN_X1 - MAIN_X0 + 0.7, BACK - FRONT + 0.7, 0.5), ((MAIN_X0 + MAIN_X1) / 2, (FRONT + BACK) / 2, 15.15), M["limestone"]))
    parts.append(box("wing_plinth", (WING_X1 - WING_X0 + 0.3, BACK - WING_FRONT, 0.4), ((WING_X0 + WING_X1) / 2, (WING_FRONT + BACK) / 2, 0.2), M["limestone"]))
    parts.append(box("wing_coping", (WING_X1 - WING_X0 + 0.35, BACK - WING_FRONT + 0.35, 0.3), ((WING_X0 + WING_X1) / 2, (WING_FRONT + BACK) / 2, WING_TOP - 0.15), M["limestone"]))

    # Puerta: hojas de madera en el hueco, marco, umbral y herraje de acero.
    parts.append(box("door_leaf_l", (DOOR_W / 2 - 0.06, 0.14, DOOR_TOP - 0.35), (DOOR_X - DOOR_W / 4 + 0.03, FRONT + 0.55, (DOOR_TOP - 0.35) / 2), M["wood"]))
    parts.append(box("door_leaf_r", (DOOR_W / 2 - 0.06, 0.14, DOOR_TOP - 0.35), (DOOR_X + DOOR_W / 4 - 0.03, FRONT + 0.55, (DOOR_TOP - 0.35) / 2), M["wood"]))
    for z in (2.2, 4.6):
        parts.append(box("door_batten", (DOOR_W - 0.3, 0.08, 0.34), (DOOR_X, FRONT + 0.46, z), M["wood"]))
    parts.append(box("door_jamb_l", (0.2, 0.45, DOOR_TOP), (DOOR_X - DOOR_W / 2 + 0.1, FRONT + 0.2, DOOR_TOP / 2), M["wood"]))
    parts.append(box("door_jamb_r", (0.2, 0.45, DOOR_TOP), (DOOR_X + DOOR_W / 2 - 0.1, FRONT + 0.2, DOOR_TOP / 2), M["wood"]))
    parts.append(box("door_head", (DOOR_W, 0.45, 0.3), (DOOR_X, FRONT + 0.2, DOOR_TOP - 0.15), M["wood"]))
    parts.append(box("threshold", (DOOR_W, 0.7, 0.16), (DOOR_X, FRONT + 0.15, 0.08), M["limestone"]))
    parts.append(box("handle", (0.12, 0.16, 0.8), (DOOR_X - 0.35, FRONT + 0.38, 3.6), M["metal_acero"]))

    # Puerta de servicio y ventanilla de la despensa, en el ala.
    parts.append(box("service_door", (2.3, 0.12, 6.4), (12.6, WING_FRONT + 0.25, 3.2), M["wood"]))
    parts.append(box("service_head", (2.5, 0.4, 0.3), (12.6, WING_FRONT + 0.1, 6.55), M["wood"]))
    parts.append(box("pantry_glass", (2.0, 0.12, 2.4), (9.3, WING_FRONT + 0.55, 4.2), M["glass"]))

    # Ventanal: fondo de cristal, suelo de madera, marco y dos parteluces; el comedor con sillas
    # y el recercado de caliza llegan en el nivel 2.
    parts.append(box("win_glass", (WIN_W + 0.1, 0.12, WIN_H + 0.1), (WIN_CX, FRONT + 1.55, (WIN_Z0 + WIN_Z1) / 2), M["glass"]))
    parts.append(box("win_floor", (WIN_W, 1.75, 0.12), (WIN_CX, FRONT + 0.85, WIN_Z0 + 0.06), M["wood"]))
    parts.append(box("win_head", (WIN_W + 0.64, 0.3, 0.3), (WIN_CX, FRONT - 0.05, WIN_Z1 + 0.15), M["wood"]))
    for side in (-1, 1):
        parts.append(box("win_jamb", (0.32, 0.3, WIN_H + 0.6), (WIN_CX + side * (WIN_W / 2 + 0.16), FRONT - 0.05, (WIN_Z0 + WIN_Z1) / 2), M["wood"]))
    for x in (WIN_X0 + WIN_W / 3, WIN_X0 + 2 * WIN_W / 3):
        parts.append(box("win_mullion", (0.22, 0.26, WIN_H), (x, FRONT + 0.02, (WIN_Z0 + WIN_Z1) / 2), M["wood"]))

    # Placa de caliza y rótulo con el nombre en letras 3D, por encima de la puerta y del toldo.
    parts.append(box("placa", (PLACA_W, 0.36, 2.3), (PLACA_X, FRONT - 0.18, PLACA_Z), M["limestone"]))
    name = letters("llaneradas", 1.8, (0.0, FRONT - 0.44, PLACA_Z + 0.05), M["wood"], depth=0.18)
    tail = letters(".com", 1.0, (0.0, FRONT - 0.44, PLACA_Z - 0.34), M["metal_acero"], depth=0.18)
    total = name.dimensions.x + 0.26 + tail.dimensions.x
    if total > PLACA_W - 0.7:
        factor = (PLACA_W - 0.7) / total
        for obj in (name, tail):
            select_only(obj)
            obj.scale = (factor, factor, factor)
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        total = name.dimensions.x + 0.26 * factor + tail.dimensions.x
    name.location.x = PLACA_X - total / 2 + name.dimensions.x / 2
    tail.location.x = name.location.x + name.dimensions.x / 2 + 0.26 + tail.dimensions.x / 2
    parts.append(name)
    parts.append(tail)

    # Pecho del asador: ladrillo con boca de arco, del suelo a la chimenea. El hueco entra de verdad
    # en el ladrillo (0,15 por delante de la cara) y deja 1,5 de fondo de ladrillo detrás.
    breast = box("asador_breast", (ASADOR_X1 - ASADOR_X0, ASADOR_Y1 - ASADOR_Y0 + 0.1, BREAST_TOP), (ASADOR_CX, (ASADOR_Y0 + ASADOR_Y1) / 2 - 0.05, BREAST_TOP / 2), M["brick"])
    mouth = box("mouth_cut", (2.5, 1.65, 2.3), (ASADOR_CX, -8.025, 1.15))
    arch = cylinder("arch_cut", 1.25, 1.65, (ASADOR_CX, -8.025, 2.3), None, 16, True, rotation=(math.pi / 2, 0.0, 0.0))
    perforate(breast, [mouth, arch])
    parts.append(breast)

    # Chimenea de ladrillo: tres cañas y su remate de caliza. Es el rasgo de la propiedad.
    parts.append(box("chimney_low", (3.3, 2.4, 4.6), (ASADOR_CX, -7.3, BREAST_TOP + 2.3), M["brick"]))
    parts.append(box("chimney_mid", (3.0, 2.2, 3.2), (ASADOR_CX, -7.3, 14.8), M["brick"]))
    parts.append(box("chimney_high", (2.7, 2.0, 3.5), (ASADOR_CX, -7.3, 18.15), M["brick"]))
    parts.append(box("chimney_cap", (3.1, 2.3, 0.3), (ASADOR_CX, -7.3, CHIMNEY_L0 - 0.15), M["limestone"]))

    # El asador: umbral de caliza, brasero, parrilla, varilla y campana.
    parts.append(box("hearth_stone", (3.8, 0.95, 0.22), (ASADOR_CX, -9.12, 0.11), M["limestone"]))
    parts.append(box("fire_tray", (2.4, 1.3, 0.24), (ASADOR_CX, -8.0, 0.12), M["metal_acero"]))
    for offset in (-1.0, -0.5, 0.0, 0.5, 1.0):
        parts.append(box("grill_bar", (0.13, 1.4, 0.13), (ASADOR_CX + offset, -7.95, 1.05), M["metal_acero"]))
    for y in (-8.15, -7.55):
        parts.append(box("grill_rail", (2.7, 0.13, 0.13), (ASADOR_CX, y, 1.05), M["metal_acero"]))
    parts.append(cylinder("spit", 0.1, 3.6, (ASADOR_CX, -7.9, 2.25), M["metal_acero"], 8, True, rotation=(0.0, math.pi / 2, 0.0)))
    parts.append(box("spit_handle", (0.14, 0.16, 0.6), (ASADOR_X0 - 0.02, -7.9, 2.05), M["metal_acero"]))
    parts.append(box("arch_band", (3.3, 0.24, 0.3), (ASADOR_CX, ASADOR_Y0 - 0.1, 3.7), M["limestone"]))
    return parts


def build_porch(M):
    """Nivel 1: porche de madera con postes, vigas y cabrios, y toldo de lona sobre el ventanal."""
    parts = []
    width = PORCH_X1 - PORCH_X0
    parts.append(box("deck", (width, -PORCH_FRONT + FRONT, DECK_TOP), ((PORCH_X0 + PORCH_X1) / 2, (PORCH_FRONT + FRONT) / 2, DECK_TOP / 2), M["wood"]))
    for x in (-15.5, -10.4, -4.9, 2.0):
        parts.append(box("post", (0.42, 0.42, POST_TOP - DECK_TOP), (x, POST_Y, (POST_TOP + DECK_TOP) / 2), M["wood"]))
        parts.append(box("post_base", (0.62, 0.62, 0.22), (x, POST_Y, DECK_TOP + 0.11), M["wood"]))
    parts.append(box("beam_front", (width + 0.5, 0.42, 0.44), ((PORCH_X0 + PORCH_X1) / 2, POST_Y, POST_TOP), M["wood"]))
    parts.append(box("beam_wall", (width, 0.36, 0.4), ((PORCH_X0 + PORCH_X1) / 2, FRONT - 0.18, POST_TOP + 0.4), M["wood"]))
    for x in (-15.5, -13.0, -10.4, -7.8, -4.9, -2.4, 0.1, 2.0):
        parts.append(slab("rafter", x - 0.11, x + 0.11, -9.45, POST_TOP + 0.05, -6.3, POST_TOP + 0.5, 0.26, M["wood"]))
    # Toldo de lona roja sobre los cabrios, delante del ventanal, con su faldón.
    parts.append(slab("toldo", -8.9, 0.6, -9.30, POST_TOP + 0.30, -6.05, POST_TOP + 0.72, 0.12, M["fabric_rojo"], lift=0.05))
    parts.append(box("toldo_faldon", (9.5, 0.12, 0.5), (-4.15, -9.30, POST_TOP + 0.05), M["fabric_rojo"]))
    parts.append(box("bench_seat", (2.4, 0.72, 0.16), (-14.2, -6.9, DECK_TOP + 1.35), M["wood"]))
    parts.append(box("bench_leg_l", (0.16, 0.6, 1.35), (-15.25, -6.9, DECK_TOP + 0.67), M["wood"]))
    parts.append(box("bench_leg_r", (0.16, 0.6, 1.35), (-13.15, -6.9, DECK_TOP + 0.67), M["wood"]))
    return parts


def build_dining(M):
    """Nivel 2: se arregla el ventanal y se ve el comedor con sus sillas de madera detrás del cristal."""
    parts = []
    # Recercado de caliza y parteluces de madera: la fachada se arregla, no se tapa.
    parts.append(box("win_band_l", (0.45, 0.45, WIN_H + 0.8), (WIN_X0 - 0.22, FRONT - 0.12, (WIN_Z0 + WIN_Z1) / 2), M["limestone"]))
    parts.append(box("win_band_r", (0.45, 0.45, WIN_H + 0.8), (WIN_X1 + 0.22, FRONT - 0.12, (WIN_Z0 + WIN_Z1) / 2), M["limestone"]))
    parts.append(box("win_band_top", (WIN_W + 0.9, 0.45, 0.45), (WIN_CX, FRONT - 0.12, WIN_Z1 + 0.45), M["limestone"]))
    parts.append(box("win_band_sill", (WIN_W + 1.0, 0.5, 0.4), (WIN_CX, FRONT - 0.15, WIN_Z0 - 0.15), M["limestone"]))
    parts.append(box("transom", (WIN_W - 0.1, 0.22, 0.22), (WIN_CX, FRONT + 0.16, 5.32), M["wood"]))
    # Junquillo de caliza sobre la planta baja, a lo largo de la fachada.
    parts.append(box("string_course", (18.4, 0.34, 0.34), (-6.9, FRONT - 0.1, 8.15), M["limestone"]))
    # El comedor: dos mesas y cuatro sillas de madera dentro del ventanal, sobre el suelo del hueco.
    z = WIN_Z0 + 0.12
    for tx, chair_xs in ((-5.6, (-6.9, -4.3)), (-1.6, (-2.9, -0.3))):
        table(parts, M, tx, FRONT + 0.9, z)
        for cx in chair_xs:
            chair(parts, M, cx, FRONT + 0.9, z)
    return parts


def build_asador_upgrade(M):
    """Nivel 3: el asador crece. Corbel de ladrillo, caña alta, remate y campana de acero, y la leña."""
    parts = []
    parts.append(box("crown_corbel", (3.5, 2.5, CROWN_H), (ASADOR_CX, -7.3, CHIMNEY_L0 + CROWN_H / 2), M["brick"]))
    parts.append(box("crown_shaft", (2.5, 1.8, CROWN_SHAFT), (ASADOR_CX, -7.3, CHIMNEY_L0 + CROWN_H + CROWN_SHAFT / 2), M["brick"]))
    parts.append(box("crown_band", (2.9, 2.1, CROWN_BAND), (ASADOR_CX, -7.3, CHIMNEY_L0 + CROWN_H + CROWN_SHAFT + CROWN_BAND / 2), M["limestone"]))
    parts.append(box("crown_plate", (2.6, 1.9, CROWN_PLATE), (ASADOR_CX, -7.3, CHIMNEY_L3 - CROWN_PLATE / 2), M["metal_acero"]))
    # Campana de acero sobre la boca del asador.
    parts.append(box("hood", (3.0, 1.1, 0.75), (ASADOR_CX, ASADOR_Y0 - 0.55, 4.5), M["metal_acero"]))
    parts.append(box("hood_lip", (2.6, 0.9, 0.16), (ASADOR_CX, ASADOR_Y0 - 0.6, 4.06), M["metal_acero"]))
    # Leña apilada bajo el porche, junto a la puerta.
    parts.append(box("log_rack", (2.2, 0.95, 0.12), (-15.0, -8.2, DECK_TOP + 0.06), M["wood"]))
    for x, y, z in ((-15.4, -8.2, 0.68), (-14.6, -8.2, 0.68), (-15.0, -8.2, 1.18), (-15.0, -7.5, 0.68)):
        parts.append(cylinder("log", 0.26, 2.0, (x, y, z), M["wood"], 6, True, rotation=(0.0, math.pi / 2, 0.0)))
    return parts


def build_annex(M):
    """Nivel 4: el ala gana una planta de comedor retranqueada, con terraza y antepecho de caliza."""
    parts = []
    annex = box("annex", (10.1, 10.25, 6.7), (10.95, 2.825, 8.5 + 3.35), M["brick"])
    cuts = [box("annex_cut", (2.4, 1.2, 3.4), (x, -1.75, 12.3)) for x in (7.9, 10.9, 13.9)]
    perforate(annex, cuts)
    parts.append(annex)
    for x in (7.9, 10.9, 13.9):
        parts.append(box("annex_glass", (2.4, 0.12, 3.4), (x, -1.24, 12.3), M["glass"]))
    parts.append(box("annex_sill", (10.1, 0.34, 0.34), (10.95, -2.36, 10.42), M["wood"]))
    parts.append(box("annex_head", (10.1, 0.34, 0.34), (10.95, -2.36, 14.18), M["wood"]))
    for x in (6.62, 9.4, 12.4, 15.18):
        parts.append(box("annex_post", (0.3, 0.34, 3.9), (x, -2.36, 12.3), M["wood"]))
    # Terraza delante del pabellón: antepecho de caliza sobre la cubierta del ala.
    parts.append(box("parapet", (10.0, 0.36, 1.5), (10.95, -5.12, WING_ROOF + 0.75), M["limestone"]))
    parts.append(box("parapet_cap", (10.3, 0.5, 0.22), (10.95, -5.12, WING_ROOF + 1.61), M["limestone"]))
    parts.append(box("annex_coping", (10.4, 10.5, 0.3), (10.95, 2.85, 15.35), M["limestone"]))
    parts.append(slab("annex_roof", 5.9, 16.1, -2.45, 15.5, 8.1, 14.65, 0.28, M["slate"]))
    return parts


def build_tower(M):
    """Nivel 5: torre de la chimenea, con fajas de caliza y remate de oro. Es la señal de nivel máximo."""
    parts = []
    parts.append(box("tower_low", (2.5, 1.85, TOWER_LOW_H), (ASADOR_CX, -7.3, CHIMNEY_L3 + TOWER_LOW_H / 2), M["brick"]))
    parts.append(box("tower_band_low", (2.75, 2.05, TOWER_BAND_H), (ASADOR_CX, -7.3, TOWER_MID + TOWER_BAND_H / 2), M["limestone"]))
    parts.append(box("tower_high", (2.25, 1.65, TOWER_HIGH_H), (ASADOR_CX, -7.3, TOWER_MID + TOWER_BAND_H + TOWER_HIGH_H / 2), M["brick"]))
    parts.append(box("tower_band_high", (2.5, 1.9, TOWER_BAND_H), (ASADOR_CX, -7.3, TOWER_END + TOWER_BAND_H / 2), M["limestone"]))
    parts.append(box("tower_collar", (2.65, 2.0, 0.2), (ASADOR_CX, -7.3, TOWER_BAND_TOP + 0.1), M["metal_acero"]))
    parts.append(frustum("tower_cap", ASADOR_CX, -7.3, 2.8, 2.15, COLLAR_TOP, 0.55, 0.45, CAP_TOP, M["metal_oro"]))
    parts.append(box("tower_finial", (0.4, 0.36, FINIAL_TOP - CAP_TOP), (ASADOR_CX, -7.3, (FINIAL_TOP + CAP_TOP) / 2), M["metal_oro"]))
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
        name = f"llaneradas_{layer}_{rbx.lower()}{suffix}"
        # Un material con una sola pieza no se une: join con un solo objeto avisa «No mesh data to join».
        if len(members) == 1:
            mesh = members[0]
            mesh.name = name
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

    # Ficha de referencia (caja oscura 8 × 4 × 5) y figura de 6 de alto para leer la escala.
    box("ficha_ref", (8.0, 4.0, 5.0), (-2.5 * SPACING, SLOT_SIDE, 2.5), M["dark"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-2.5 * SPACING + DOOR_X + 2.9, lot_y - 7.2, 3.0), M["avatar"])
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
    builders = {1: build_porch, 2: build_dining, 3: build_asador_upgrade, 4: build_annex, 5: build_tower}
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
    lod = lod_of(objects, "llaneradas_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "llaneradas_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "cuerpo": {"ancho": MAIN_X1 - MAIN_X0, "fondo": BACK - FRONT, "alto": EAVE},
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
    print("LLANERADAS_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "llaneradas-com.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["metal_acero"], "gold": M["metal_oro"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -190.0, 72.0), (0.0, 22.0, 11.0), 30), f"{RENDER_SUBDIR}/llaneradas-com-niveles.png")

    # Comparación: nivel 0 frente a un bloque de Bodega (13) y otro de Cine Lux (24), con la figura de 6
    # delante de la fachada y al lado de la puerta, que es lo que permite revisar la puerta.
    hide_all()
    box("ground", (300, 400, 0.4), (0, 40, -0.2), M["pavement"])
    place(cumulative_objects[0], -31.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (5.0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (41.0, 0, 12.0), M["block"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-31.0 + DOOR_X + 2.9, -7.6, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -140.0, 28.0), (0.0, 0.0, 9.0), 40), f"{RENDER_SUBDIR}/llaneradas-com-comparacion.png")
    print("LLANERADAS_DONE")


if __name__ == "__main__":
    main()

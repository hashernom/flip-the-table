"""Versalles 1: conjunto residencial de la zona Violeta, modelado desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 x 18, la del solar; el frente da a -Y y el origen
esta en el centro de la base, con z = 0 a ras de suelo. Dos casas pareadas de dos pisos, blancas, con cubierta
de pizarra, porche y jardin delantero, y un portalon de verja con el rotulo. El cuerpo (masa principal) llega a
16,0; el nivel 0 completo, con cubiertas y chimeneas, se queda en 20,6. Cinco anadidos que se suman: verja y
porton, jardin y caminos, casas nuevas retranqueadas, pabellon comun y torre del deposito con remate de cobre.

La ficha pide un conjunto identico al de Versalles 2 (misma tipologia, fachada de ladrillo) y distinguible por
color y remate: aqui la fachada es de caliza blanca y el remate es la torre del deposito. La puerta de la casa
mide 2,6 x 6,6 y el portalon 9,0 x 7,4; ambos superan la figura de 6. El rotulo va en placa de pizarra sobre el
portalon, por encima de la puerta y del toldo, con letras de caliza.

Sigue el metodo de barberia-morro.py y build_cine_lux.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/violeta/:
  versalles-1.blend                         escena de revision (no se versiona)
  versalles-1/versalles1_<pieza>_<material>.fbx y versalles1_LOD1.fbx
  versalles-1/stats.json                    triangulos por pieza y nivel, limites y materiales
Y en art/render/violeta/versalles-1/: versalles-1-niveles.png y versalles-1-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/violeta/versalles-1.py
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
OUT = os.path.join(HERE, "versalles-1")
RENDER_SUBDIR = "violeta/versalles-1"
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

# --- Solar -----------------------------------------------------------------------------------------
WIDTH = 32.0
DEPTH = 18.0
LOT_FRONT = -DEPTH / 2  # -9,0
PORTAL_Y = -8.9  # linea de la verja y del portalon

# --- Casas pareadas: masa principal de 16,0, cubierta a cuatro aguas por encima --------------------
HOUSE_H = 16.0
HOUSE_RIDGE = 19.2
HOUSE_X = 11.0  # centro de cada casa; de -16 a -6 y de 6 a 16
HOUSE_Y0, HOUSE_Y1 = -1.0, 6.0
HOUSE_W, HOUSE_D = 10.0, 7.0
DOOR_W, DOOR_H = 2.6, 6.6
WIN_W, WIN_H = 1.7, 3.5
UPPER_W, UPPER_H = 1.6, 3.4
GROUND_WIN_Z0 = 1.5
GROUND_WIN_Z1 = 5.0
UPPER_WIN_Z0 = 11.9
UPPER_WIN_Z1 = 15.3
ROOF_OVER = 0.55
ROOF_HIP = 2.4

# --- Porton y rotulo ------------------------------------------------------------------------------
PORTAL_HALF = 4.5  # hueco libre de 9,0
PORTAL_TOP = 7.4
PIER_X = 5.1
CANOPY_Z0, CANOPY_Z1 = 8.4, 8.65
SCREEN_Z0, SCREEN_Z1 = 8.65, 11.65
PLACA_Z0, PLACA_Z1 = 9.25, 11.45
PLACA_Z = (PLACA_Z0 + PLACA_Z1) / 2
SIGN_TEXT = "VERSALLES 1"
SIGN_SIZE = 1.7
SIGN_MAX_W = 9.2

# --- Verja y porton (nivel 1) ---------------------------------------------------------------------
RAIL_Z0, RAIL_Z1 = 1.0, 2.44
GATE_TOP = 7.05

# --- Jardin (nivel 2) -----------------------------------------------------------------------------
BED_X = 11.0
BED_Y = -8.0
CROSS_PATH_Y = -2.6

# --- Casas nuevas retranqueadas (nivel 3) ---------------------------------------------------------
COTTAGE_X = 3.6
COTTAGE_W, COTTAGE_D = 4.4, 5.8
COTTAGE_H = 10.4
COTTAGE_RIDGE = 12.8
COTTAGE_Y0, COTTAGE_Y1 = 2.8, 8.6
COTTAGE_DOOR_W, COTTAGE_DOOR_H = 1.7, 6.2
COTTAGE_WIN_Z0, COTTAGE_WIN_Z1 = 6.95, 8.85

# --- Pabellon comun (nivel 4) ---------------------------------------------------------------------
PAV_X, PAV_Y = -4.3, -6.0
PAV_W, PAV_D = 4.8, 5.2
PAV_FLOOR_TOP = 0.45
PAV_POST_TOP = 4.7
PAV_RIDGE = 6.3

# --- Torre del deposito (nivel 5) -----------------------------------------------------------------
TOWER_X, TOWER_Y = 10.5, 7.8
TOWER_W, TOWER_D = 2.6, 2.4
TOWER_SHAFT_TOP = 26.5
TANK_W, TANK_D = 3.2, 2.8
TANK_TOP = 29.9
CROWN_TOP = 32.7
TOWER_TOP = 33.55

TRIANGLE_BUDGET = 3000
BODY_LIMIT = 21.0  # el nivel 0 completo, con cubierta y chimeneas, no pasa de aqui
MAX_HEIGHT = 34.0
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
ZONE_RGB = "8B5CF6"  # violeta, solo en la casilla pintada de la escena de render

# Material de Roblox, sufijo de color y RGB de cada material de Blender.
RBX = {
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
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "wood": flat("wood", "6B4A2E", 0.7),
        "fabric_rojo": flat("fabric_rojo", "C4382B", 0.8),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.4, 0.9),
        "metal_oro": flat("metal_oro", "C9A227", 0.3, 0.9),
        "metal_violeta": flat("metal_violeta", "8B5CF6", 0.35, 0.7),
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
    """Caja a partir de sus limites: se lee mejor que centro y tamano."""
    return box(name, (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), mat)


def cylinder(name, radius, depth, location, mat, verts=8, caps=True):
    """Cilindro vertical: remates metalicos de la torre."""
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


def cone(name, radius, depth, location, mat, verts=8):
    """Cono vertical: topiaria del jardin."""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def hip_roof(name, x0, x1, y0, y1, z_eave, z_ridge, mat, hip=0.0):
    """Cubierta de pizarra a cuatro aguas, con la cumbrera en el eje X."""
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


def pyramid(name, x0, x1, y0, y1, z0, z1, mat):
    """Piramide de base rectangular: remates del pabellon y de la torre."""
    verts = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), ((x0 + x1) / 2, (y0 + y1) / 2, z1)]
    faces = [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (0, 3, 2, 1)]
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
    """Reduce el rotulo de forma uniforme si no cabe en la placa."""
    width = obj.dimensions.x
    if width > max_width:
        select_only(obj)
        factor = max_width / width
        obj.scale = (factor, factor, factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def window_unit(parts, cuts, M, x, z0, z1, width, frame_mat, glass_mat):
    """Hueco de verdad en la fachada -Y, cristal retranqueado y alfeizar de caliza."""
    height = z1 - z0
    zc = (z0 + z1) / 2
    cuts.append(box("win_cut", (width, 1.2, height + 0.1), (x, -0.5, zc)))
    parts.append(box("pane", (width - 0.2, 0.1, height - 0.3), (x, -0.2, zc), glass_mat))
    parts.append(box("sill", (width + 0.25, 0.5, 0.2), (x, -1.02, z0 - 0.1), frame_mat))
    parts.append(box("head", (width + 0.25, 0.5, 0.2), (x, -1.02, z1 + 0.1), frame_mat))


def build_house(M, side):
    """Una de las dos casas pareadas: pared de caliza con vanos de verdad, porche, placa de caliza y pizarra."""
    parts, cuts = [], []
    cx = side * HOUSE_X
    door_x = side * HOUSE_X
    wall = box("house_wall", (HOUSE_W, HOUSE_D, HOUSE_H), (cx, (HOUSE_Y0 + HOUSE_Y1) / 2, HOUSE_H / 2), M["limestone"])

    cuts.append(box("door_cut", (DOOR_W, 1.2, DOOR_H + 0.6), (door_x, -0.5, (DOOR_H + 0.2) / 2)))
    for offset in (-3.2, 3.2):
        window_unit(parts, cuts, M, door_x + offset, GROUND_WIN_Z0, GROUND_WIN_Z1, WIN_W, M["limestone"], M["glass"])
    for offset in (-3.3, 0.0, 3.3):
        window_unit(parts, cuts, M, door_x + offset, UPPER_WIN_Z0, UPPER_WIN_Z1, UPPER_W, M["limestone"], M["glass"])
    perforate(wall, cuts)
    parts.insert(0, wall)

    # Puerta de 2,6 x 6,6, mas alta que la figura de 6, con recercado de caliza y hoja de madera.
    parts.append(box("door_leaf", (DOOR_W - 0.3, 0.16, DOOR_H - 0.2), (door_x, -0.25, 0.45 + (DOOR_H - 0.2) / 2), M["wood"]))
    for sign in (-1, 1):
        parts.append(box("door_jamb", (0.28, 0.4, DOOR_H + 0.2), (door_x + sign * (DOOR_W / 2 + 0.14), -1.0, (DOOR_H + 0.2) / 2), M["limestone"]))
    parts.append(box("door_head", (DOOR_W + 0.6, 0.4, 0.3), (door_x, -1.0, DOOR_H + 0.15), M["limestone"]))

    # Porche: tarima de caliza, dos postes de madera y tejadillo de pizarra.
    parts.append(box("porch_deck", (5.6, 2.4, 0.45), (door_x, -2.2, 0.225), M["limestone"]))
    for sign in (-1, 1):
        parts.append(box("porch_post", (0.3, 0.3, 7.55), (door_x + sign * 2.2, -3.1, 4.225), M["wood"]))
    parts.append(box("porch_roof", (5.9, 2.7, 0.25), (door_x, -2.2, 8.125), M["slate"]))

    # Junta de plantas, cornisa, chimenea y cubierta a cuatro aguas.
    parts.append(box("string", (HOUSE_W + 0.4, HOUSE_D + 0.4, 0.3), (cx, 2.5, 8.45), M["limestone"]))
    parts.append(box("cornice", (HOUSE_W + 0.7, HOUSE_D + 0.7, 0.4), (cx, 2.5, 16.0), M["limestone"]))
    parts.append(box("chimney", (0.9, 0.9, 3.0), (side * 8.0, 4.5, 18.9), M["limestone"]))
    parts.append(box("chimney_cap", (1.1, 1.1, 0.2), (side * 8.0, 4.5, 20.5), M["slate"]))
    parts.append(box("ridge_cap", (HOUSE_W - 5.0, 0.4, 0.2), (cx, 2.5, 19.3), M["slate"]))
    parts.append(hip_roof("roof", cx - HOUSE_W / 2 - ROOF_OVER, cx + HOUSE_W / 2 + ROOF_OVER, HOUSE_Y0 - ROOF_OVER, HOUSE_Y1 + ROOF_OVER, HOUSE_H, HOUSE_RIDGE, M["slate"], hip=ROOF_HIP))
    return parts


def build_portal(M):
    """Portalon de la verja: 9,0 x 7,4, toldo de pizarra y placa con el nombre por encima."""
    parts = []
    for side in (-1, 1):
        parts.append(box("pier", (1.2, 1.0, PORTAL_TOP + 1.0), (side * PIER_X, PORTAL_Y, (PORTAL_TOP + 1.0) / 2), M["limestone"]))
    parts.append(box("lintel", (11.4, 0.9, 1.0), (0.0, PORTAL_Y, PORTAL_TOP + 0.5), M["limestone"]))
    parts.append(box("portal_floor", (9.4, 1.0, 0.22), (0.0, PORTAL_Y, 0.11), M["limestone"]))
    parts.append(box("canopy", (12.0, 1.6, CANOPY_Z1 - CANOPY_Z0), (0.0, -9.1, (CANOPY_Z0 + CANOPY_Z1) / 2), M["slate"]))
    parts.append(box("screen", (11.4, 0.7, SCREEN_Z1 - SCREEN_Z0), (0.0, PORTAL_Y, (SCREEN_Z0 + SCREEN_Z1) / 2), M["limestone"]))
    parts.append(box("screen_cap", (11.6, 0.8, 0.25), (0.0, PORTAL_Y, SCREEN_Z1 + 0.125), M["limestone"]))
    parts.append(box("sign_plate", (10.0, 0.2, PLACA_Z1 - PLACA_Z0), (0.0, -9.25, PLACA_Z), M["slate"]))
    name = fit_width(letters(SIGN_TEXT, SIGN_SIZE, (0.0, -9.45, PLACA_Z), M["limestone"], depth=0.18), SIGN_MAX_W)
    parts.append(name)
    return parts


def build_verja(M):
    """Nivel 1: verja de acero sobre el muro bajo y porton de dos hojas, sin tapar el nombre."""
    parts = []
    for side in (-1, 1):
        parts.append(box("end_pier", (0.9, 0.9, 2.5), (side * 15.55, PORTAL_Y, 1.25), M["limestone"]))
        parts.append(box("end_cap", (1.1, 1.1, 0.25), (side * 15.55, PORTAL_Y, 2.625), M["limestone"]))
    for side in (-1, 1):
        x0, x1 = side * 5.7, side * 15.1
        xc = (x0 + x1) / 2
        length = abs(x1 - x0)
        parts.append(box("rail_top", (length, 0.14, 0.14), (xc, PORTAL_Y, RAIL_Z1 - 0.07), M["metal_acero"]))
        parts.append(box("rail_bottom", (length, 0.12, 0.12), (xc, PORTAL_Y, RAIL_Z0 + 0.06), M["metal_acero"]))
        for k in range(4):
            x = x0 + (x1 - x0) * (k + 1) / 5.0
            parts.append(box("bar", (0.1, 0.1, RAIL_Z1 - RAIL_Z0 - 0.19), (x, PORTAL_Y, (RAIL_Z0 + RAIL_Z1) / 2), M["metal_acero"]))
    for side in (-1, 1):
        xc = side * 2.25
        parts.append(box("gate_top", (4.3, 0.14, 0.14), (xc, PORTAL_Y, GATE_TOP - 0.07), M["metal_acero"]))
        parts.append(box("gate_bottom", (4.3, 0.14, 0.14), (xc, PORTAL_Y, 0.47), M["metal_acero"]))
        for sign in (-1, 1):
            parts.append(box("gate_stile", (0.14, 0.14, GATE_TOP - 0.45), (xc + sign * 2.08, PORTAL_Y, (GATE_TOP + 0.4) / 2), M["metal_acero"]))
        for k in range(4):
            x = xc - 4.3 / 2.0 + 4.3 * (k + 1) / 5.0
            parts.append(box("gate_bar", (0.1, 0.1, GATE_TOP - 0.6), (x, PORTAL_Y, (GATE_TOP + 0.4) / 2), M["metal_acero"]))
    return parts


def build_garden(M):
    """Nivel 2: caminos de caliza, setos, arriates y topiaria que hacen leer el jardin desde arriba."""
    parts = []
    for side in (-1, 1):
        parts.append(box("cross_path", (6.9, 1.6, 0.22), (side * 4.75, CROSS_PATH_Y, 0.11), M["limestone"]))
        parts.append(box("hedge", (0.5, 4.0, 0.8), (side * 2.0, -6.0, 0.55), M["grass_seto"]))
        parts.append(box("bed_curb", (5.0, 1.0, 0.25), (side * BED_X, BED_Y, 0.125), M["limestone"]))
        parts.append(box("bed_hedge", (4.6, 0.7, 0.9), (side * BED_X, BED_Y, 0.7), M["grass_seto"]))
        parts.append(cone("topiary", 0.55, 2.6, (side * 7.6, -7.6, 0.15 + 1.3), M["grass_seto"]))
    return parts


def build_cottages(M):
    """Nivel 3: dos casas nuevas retranqueadas al fondo del jardin central, con porton y ventana alta."""
    parts = []
    for side in (-1, 1):
        cx = side * COTTAGE_X
        wall = box("cottage_wall", (COTTAGE_W, COTTAGE_D, COTTAGE_H), (cx, (COTTAGE_Y0 + COTTAGE_Y1) / 2, COTTAGE_H / 2), M["limestone"])
        cuts = [
            box("door_cut", (COTTAGE_DOOR_W, 1.1, COTTAGE_DOOR_H + 0.3), (cx, 3.25, (COTTAGE_DOOR_H - 0.1) / 2)),
            box("win_cut", (1.2, 1.1, COTTAGE_WIN_Z1 - COTTAGE_WIN_Z0 + 0.1), (cx, 3.25, (COTTAGE_WIN_Z0 + COTTAGE_WIN_Z1) / 2)),
        ]
        perforate(wall, cuts)
        parts.append(wall)
        parts.append(box("door_leaf", (COTTAGE_DOOR_W - 0.25, 0.14, COTTAGE_DOOR_H - 0.5), (cx, 2.95, 0.15 + (COTTAGE_DOOR_H - 0.5) / 2), M["wood"]))
        for sign in (-1, 1):
            parts.append(box("door_jamb", (0.2, 0.3, COTTAGE_DOOR_H - 0.1), (cx + sign * 0.95, 2.9, (COTTAGE_DOOR_H - 0.1) / 2), M["limestone"]))
        parts.append(box("door_head", (2.1, 0.3, 0.25), (cx, 2.9, COTTAGE_DOOR_H - 0.05), M["limestone"]))
        parts.append(box("pane", (1.0, 0.1, COTTAGE_WIN_Z1 - COTTAGE_WIN_Z0 - 0.2), (cx, 3.05, (COTTAGE_WIN_Z0 + COTTAGE_WIN_Z1) / 2), M["glass"]))
        parts.append(box("sill", (1.4, 0.4, 0.18), (cx, 2.75, COTTAGE_WIN_Z0 - 0.09), M["limestone"]))
        parts.append(box("head", (1.4, 0.4, 0.18), (cx, 2.75, COTTAGE_WIN_Z1 + 0.09), M["limestone"]))
        parts.append(box("cottage_chimney", (0.55, 0.55, 1.6), (cx, 7.6, 11.2), M["limestone"]))
        parts.append(box("cottage_chimney_cap", (0.7, 0.7, 0.15), (cx, 7.6, 12.075), M["slate"]))
        parts.append(box("cottage_cornice", (COTTAGE_W + 0.3, COTTAGE_D + 0.3, 0.3), (cx, (COTTAGE_Y0 + COTTAGE_Y1) / 2, COTTAGE_H), M["limestone"]))
        parts.append(box("cottage_step", (2.0, 0.5, 0.2), (cx, 2.5, 0.25), M["limestone"]))
        parts.append(box("cottage_ridge", (COTTAGE_W - 1.8, 0.3, 0.18), (cx, (COTTAGE_Y0 + COTTAGE_Y1) / 2, COTTAGE_RIDGE), M["slate"]))
        parts.append(hip_roof("cottage_roof", cx - COTTAGE_W / 2 - 0.15, cx + COTTAGE_W / 2 + 0.15, COTTAGE_Y0 - 0.15, COTTAGE_Y1 + 0.15, COTTAGE_H, COTTAGE_RIDGE, M["slate"], hip=0.9))
    return parts


def build_pavilion(M):
    """Nivel 4: pabellon comun de madera y lona roja a la izquierda del jardin delantero."""
    parts = []
    parts.append(box("pavilion_floor", (3.8, 4.4, PAV_FLOOR_TOP), (PAV_X, PAV_Y, PAV_FLOOR_TOP / 2), M["limestone"]))
    for x in (PAV_X - 1.5, PAV_X + 1.5):
        for y in (PAV_Y - 1.8, PAV_Y + 1.8):
            parts.append(box("pavilion_post", (0.25, 0.25, PAV_POST_TOP - PAV_FLOOR_TOP), (x, y, (PAV_FLOOR_TOP + PAV_POST_TOP) / 2), M["wood"]))
    parts.append(box("pavilion_bench", (2.4, 0.6, 0.45), (PAV_X, PAV_Y, PAV_FLOOR_TOP + 0.225), M["wood"]))
    parts.append(box("pavilion_finial", (0.25, 0.25, 0.5), (PAV_X, PAV_Y, PAV_RIDGE + 0.25), M["wood"]))
    parts.append(box("pavilion_valance", (PAV_W - 0.2, 0.12, 0.35), (PAV_X, PAV_Y - PAV_D / 2 + 0.05, PAV_POST_TOP), M["fabric_rojo"]))
    parts.append(pyramid("pavilion_roof", PAV_X - PAV_W / 2, PAV_X + PAV_W / 2, PAV_Y - PAV_D / 2, PAV_Y + PAV_D / 2, PAV_POST_TOP, PAV_RIDGE, M["fabric_rojo"]))
    return parts


def build_tower(M):
    """Nivel 5: torre del deposito con deposito de madera, flejes de acero y remate de cobre."""
    parts = []
    parts.append(box("tower_shaft", (TOWER_W, TOWER_D, TOWER_SHAFT_TOP), (TOWER_X, TOWER_Y, TOWER_SHAFT_TOP / 2), M["limestone"]))
    for z in (20.0, 23.5):
        parts.append(box("tower_band", (TOWER_W + 0.3, TOWER_D + 0.3, 0.25), (TOWER_X, TOWER_Y, z), M["limestone"]))
    parts.append(box("tower_rim", (TANK_W + 0.2, TANK_D + 0.2, 0.25), (TOWER_X, TOWER_Y - 0.1, TOWER_SHAFT_TOP - 0.1), M["limestone"]))
    parts.append(box("tower_tank", (TANK_W, TANK_D, TANK_TOP - TOWER_SHAFT_TOP), (TOWER_X, TOWER_Y - 0.1, (TOWER_SHAFT_TOP + TANK_TOP) / 2), M["wood"]))
    for z in (26.9, 28.0, 29.1):
        parts.append(box("tower_hoop", (TANK_W + 0.2, TANK_D + 0.2, 0.14), (TOWER_X, TOWER_Y - 0.1, z), M["metal_acero"]))
    parts.append(box("tower_top", (TANK_W + 0.2, TANK_D + 0.2, 0.2), (TOWER_X, TOWER_Y - 0.1, TANK_TOP + 0.1), M["limestone"]))
    parts.append(pyramid("tower_crown", TOWER_X - 1.8, TOWER_X + 1.8, TOWER_Y - 1.6, TOWER_Y + 1.4, TANK_TOP + 0.2, CROWN_TOP, M["metal_oro"]))
    parts.append(cylinder("tower_finial", 0.16, 0.6, (TOWER_X, TOWER_Y - 0.1, (CROWN_TOP + TOWER_TOP - 0.25) / 2), M["metal_oro"]))
    parts.append(cylinder("tower_tip", 0.24, 0.25, (TOWER_X, TOWER_Y - 0.1, TOWER_TOP - 0.125), M["metal_violeta"]))
    return parts


def build_body(M):
    """Nivel 0: jardin, casas pareadas, portalon con rotulo y muro bajo de la verja."""
    parts = []
    parts.append(box("lawn", (WIDTH, 17.6, 0.15), (0.0, 0.1, 0.075), M["grass_cesped"]))
    parts.append(box("path", (2.6, 17.5, 0.22), (0.0, 0.15, 0.11), M["limestone"]))
    for side in (-1, 1):
        parts.extend(build_house(M, side))
    parts.extend(build_portal(M))
    for x0, x1 in ((-16.0, -5.7), (5.7, 16.0)):
        length = x1 - x0
        xc = (x0 + x1) / 2
        parts.append(box("front_wall", (length, 0.5, 0.9), (xc, PORTAL_Y, 0.45), M["limestone"]))
        parts.append(box("front_coping", (length, 0.6, 0.15), (xc, PORTAL_Y, 0.975), M["limestone"]))
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
        name = f"versalles1_{layer}_{rbx.lower()}{suffix}"
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
    """Limites en studs: ancho (x), fondo (y) y alto (z), con las mallas en coordenadas de escena."""
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

    # Ficha de referencia (caja oscura 8 x 4 x 5) y avatar de 6 de alto para la escala.
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

    # Nivel 0: cuerpo. Niveles 1 a 5: anadidos que se suman sin sustituir nada.
    group(0, build_body(M), pieces)
    builders = {1: build_verja, 2: build_garden, 3: build_cottages, 4: build_pavilion, 5: build_tower}
    for level, builder in builders.items():
        group(level, builder(M), pieces)

    # Estadisticas por pieza, por nivel (propias y acumuladas) y limites.
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

    # LOD1 con el conjunto entero, al 50 % como los demas edificios.
    lod = lod_of(objects, "versalles1_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "versalles1_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "cuerpo": {"alto_masa_principal": HOUSE_H, "alto_nivel_0": levels["0"]["limites"]["alto_maximo_sobre_suelo"], "limite_nivel_0": BODY_LIMIT},
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
    print("VERSALLES_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

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

    # Escena de revision y renders, con las mallas de origen ocultas.
    for obj in objects + [lod]:
        obj.hide_render = True
        obj.hide_viewport = True
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "versalles-1.blend"))

    markers = {
        kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["metal_acero"], "gold": M["metal_oro"]})
        for kind in ("house", "hotel", "tower")
    }
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    # Vista de calle como en las referencias: el portalon deja ver el jardin central y las casas nuevas,
    # y el rotulo se lee de frente; el remate de la torre queda por encima de las cubiertas.
    render(scene, camera("niveles", (0.0, -190.0, 78.0), (0.0, 22.0, 10.0), 30), f"{RENDER_SUBDIR}/versalles-1-niveles.png")

    # Comparacion: nivel 0 junto a una figura de 6 delante del portalon, y bloques de Bodega (13) y Cine Lux (24).
    hide_all()
    box("ground", (150, 40, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -40.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (40, 0, 12.0), M["block"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-40.0 + 2.6, -9.0, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -150.0, 30.0), (0.0, 0.0, 9.0), 42), f"{RENDER_SUBDIR}/versalles-1-comparacion.png")
    print("VERSALLES_DONE")


if __name__ == "__main__":
    main()

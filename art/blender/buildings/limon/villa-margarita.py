"""Villa Margarita: casona de campo azul de la zona Limón, modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base, con z = 0 a ras de suelo. La masa principal —la casona azul de dos plantas— llega
a 20,0; el nivel 0, con la cubierta de pizarra y la buhardilla, se queda en 24,8. Cinco añadidos que se suman:
verja y porche, jardín y setos, ventanas coloniales y balcón, ala lateral retranqueada y torre del mirador con
remate de cobre.

Sigue el método de barberia-morro.py y build_cine_lux.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/limon/:
  villa-margarita.blend                        escena de revisión (no se versiona)
  villa-margarita/villa_<pieza>_<material>.fbx y villa_LOD1.fbx
  villa-margarita/stats.json                   triángulos por pieza y nivel, límites y materiales
Y en art/render/limon/villa-margarita/: villa-margarita-niveles.png y villa-margarita-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/limon/villa-margarita.py
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
OUT = os.path.join(HERE, "villa-margarita")
RENDER_SUBDIR = "limon/villa-margarita"
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
LOT_FRONT = -DEPTH / 2  # el frente del solar da a -Y

# --- Casona: masa principal de 20,0 de alto, con la cubierta por encima ----------------------------
BODY_HALF = 12.0
BODY_Y0, BODY_Y1 = -4.8, 7.2  # 12 de fondo: deja jardín delante y algo de patio detrás
BODY_H = 20.0
BODY_YC = (BODY_Y0 + BODY_Y1) / 2
WALL_NICHE = 1.5  # fondo del hueco de cada vano: se ve el recercado, no una calcomanía

DOOR_W = 3.4
DOOR_H = 6.9  # 0,9 más alta que la figura de 6
GROUND_WIN_XS = (-7.6, 7.6)
GROUND_WIN_W = 3.2
GROUND_WIN_Z0, GROUND_WIN_Z1 = 1.5, 5.9
UPPER_WIN_XS = (-7.6, 0.0, 7.6)
UPPER_WIN_W = 3.6
UPPER_Z0, UPPER_Z1 = 12.5, 17.9
SIDE_WINDOWS = ((-1, 0.6), (-1, 4.4), (1, -2.4))  # (costado, y): dos al oeste, una al este
SIDE_WIN_Z0, SIDE_WIN_Z1 = 12.6, 16.6

STRING_Z0, STRING_Z1 = 8.4, 8.8
PLACA_Z = 10.6  # placa y letras por encima de la puerta y del toldo
CORNICE_Z0, CORNICE_Z1 = 19.45, 20.05
EAVE_Z = 20.05
RIDGE_Z = 24.6  # cubierta con pendiente de casa de campo, siempre por debajo de 25
ROOF_OVER = 0.9  # vuelo de la cubierta de pizarra
RIDGE_HIP = 3.6
DORMER_X, DORMER_HALF = 0.0, 1.85  # buhardilla sobre la puerta
DORMER_Y0, DORMER_Y1 = -4.3, -2.7
DORMER_Z0, DORMER_Z1 = 20.5, 22.9

# --- Nivel 1: verja y porche ----------------------------------------------------------------------
FENCE_Y = -9.2
FENCE_Z = 1.15
FENCE_HALF = 15.5
GATE_HALF = 2.6
GATE_PIER_HALF = 3.05
DECK_X = 6.0
DECK_Y1 = -7.75
DECK_Z = 0.5
STEP_Y1 = -8.35
STEP_Z = 0.3
AWNING_W = 12.6
AWNING_WALL_Z = 8.95
AWNING_EDGE_Y = -7.8
AWNING_EDGE_Z = 8.05
POST_X = 5.55
POST_Y = -7.5
PATH_HALF = 2.0
PATH_Y0 = -9.1

# --- Nivel 3: ventanas coloniales y balcón --------------------------------------------------------
BALCONY_Z0, BALCONY_Z1 = 12.15, 12.45
BALCONY_HALF = 3.1
BALCONY_DEPTH = 1.25
RAIL_Z = 13.4

# --- Nivel 4: ala lateral retranqueada ------------------------------------------------------------
WING_X0, WING_X1 = 12.0, 17.5
WING_Y0, WING_Y1 = 0.4, 7.2
WING_H = 14.2

# --- Nivel 5: torre del mirador -------------------------------------------------------------------
TOWER_X0, TOWER_X1 = -9.5, -3.5
TOWER_Y0, TOWER_Y1 = -2.9, 3.1
TOWER_Z0, TOWER_Z1 = 16.5, 30.4
TOWER_BAND_Z1 = 30.95
TOWER_CAP_Z1 = 32.85
TOWER_FINIAL_Z1 = 33.65

TRIANGLE_BUDGET = 3000
BODY_LIMIT = 25.0  # el nivel 0 completo, con la cubierta, no pasa de aquí
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
ZONE_RGB = "FACC15"  # limón, solo en la casilla pintada de la escena de render

# Material de Roblox, sufijo de color y RGB de cada clave de material de Blender.
RBX = {
    "smoothplastic_azul": ("SmoothPlastic", "_azul", "35638C"),
    "smoothplastic_blanco": ("SmoothPlastic", "_blanco", "E4DFD3"),
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "wood": ("Wood", "", "6B4A2E"),
    "fabric_rojo": ("Fabric", "_rojo", "C4382B"),
    "metal": ("Metal", "", "C97B3A"),
    "grass_cesped": ("Grass", "_cesped", "6E8F4E"),
    "grass_seto": ("Grass", "_seto", "4A6B3A"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "smoothplastic_azul": flat("smoothplastic_azul", "35638C", 0.55),
        "smoothplastic_blanco": flat("smoothplastic_blanco", "E4DFD3", 0.6),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "wood": flat("wood", "6B4A2E", 0.7),
        "fabric_rojo": flat("fabric_rojo", "C4382B", 0.8),
        "metal": flat("metal", "C97B3A", 0.3, 0.9),
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
    return box(name, (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), mat)


def cylinder(name, radius, depth, location, mat, verts=8):
    """Cilindro vertical: remate de cobre del mirador."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def pyramid(name, side, height, location, mat):
    """Pirámide de base cuadrada (remate de cobre) con las aristas paralelas a los ejes."""
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


def cone(name, radius, depth, location, mat, verts=8):
    """Cono de base circular: ciprés y arbusto recortado del jardín."""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def pitched_roof(name, x0, x1, y0, y1, z_eave, z_ridge, mat, along="x", hip=0.0):
    """Cubierta de pizarra a dos o cuatro aguas, con la cumbrera en un eje.

    `along` es el eje de la cumbrera: "x" deja los faldones al frente y al fondo; "y" los deja a los lados.
    `hip` recorta la cumbrera para que los extremos también caigan a cuatro aguas.
    """
    if along == "x":
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
    else:
        mid = (x0 + x1) / 2
        verts = [
            (x0, y0, z_eave),
            (x1, y0, z_eave),
            (x1, y1, z_eave),
            (x0, y1, z_eave),
            (mid, y0 + hip, z_ridge),
            (mid, y1 - hip, z_ridge),
        ]
        faces = [(0, 1, 4), (1, 2, 5, 4), (2, 3, 5), (3, 0, 4, 5), (0, 3, 2, 1)]
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


def window_unit(parts, cuts, M, face_axis, face, out, u, width, z0, z1, frame_mat=None, sill=True):
    """Ventana con hueco de verdad, cristal retranqueado y recercado claro.

    face_axis "y": la cara mira a ±Y (fachada); "x": mira a ±X (costado). `out` es el signo hacia fuera y
    `face` la coordenada del plano de fachada.
    """
    frame_mat = frame_mat or M["smoothplastic_blanco"]
    height = z1 - z0
    zc = (z0 + z1) / 2
    span = 1.0 + WALL_NICHE
    center = face + out * (1.0 - WALL_NICHE) / 2
    frame = face + out * 0.06
    if face_axis == "y":
        cuts.append(box("win_cut", (width, span, height + 0.1), (u, center, zc)))
        parts.append(box("pane", (width - 0.26, 0.1, height - 0.26), (u, face - out * 0.72, zc), M["glass"]))
        for sign in (-1, 1):
            parts.append(box("jamb", (0.34, 0.44, height + 0.34), (u + sign * (width / 2 + 0.17), frame, zc), frame_mat))
        parts.append(box("head", (width + 0.68, 0.44, 0.34), (u, frame, z1 + 0.17), frame_mat))
        if sill:
            parts.append(box("sill", (width + 0.9, 0.72, 0.24), (u, face - out * 0.02, z0 - 0.12), M["limestone"]))
    else:
        cuts.append(box("win_cut", (span, width, height + 0.1), (center, u, zc)))
        parts.append(box("pane", (0.1, width - 0.26, height - 0.26), (face - out * 0.72, u, zc), M["glass"]))
        for sign in (-1, 1):
            parts.append(box("jamb", (0.44, 0.34, height + 0.34), (frame, u + sign * (width / 2 + 0.17), zc), frame_mat))
        parts.append(box("head", (0.44, width + 0.68, 0.34), (frame, u, z1 + 0.17), frame_mat))
        if sill:
            parts.append(box("sill", (0.72, width + 0.9, 0.24), (face - out * 0.02, u, z0 - 0.12), M["limestone"]))


def muntins(parts, M, x, width, z0, z1):
    """Cruceta blanca de ventana colonial, por delante del cristal."""
    height = z1 - z0
    zc = (z0 + z1) / 2
    bar_y = BODY_Y0 + 0.62
    parts.append(box("muntin_v", (0.14, 0.12, height - 0.3), (x, bar_y, zc), M["smoothplastic_blanco"]))
    for offset in (0.34, 0.67):
        parts.append(box("muntin_h", (width - 0.3, 0.12, 0.14), (x, bar_y, z0 + height * offset), M["smoothplastic_blanco"]))


def build_body(M):
    """Nivel 0: casona azul de dos plantas, vanos de verdad, recercado blanco, placa y cubierta a cuatro aguas."""
    parts, cuts = [], []
    wall = slab("villa_wall", -BODY_HALF, BODY_HALF, BODY_Y0, BODY_Y1, 0.0, BODY_H, M["smoothplastic_azul"])

    # Puerta alta con recercado blanco y umbral de caliza.
    cuts.append(box("door_cut", (DOOR_W, 1.0 + WALL_NICHE, DOOR_H + 0.5), (0.0, BODY_Y0 + 0.25, (DOOR_H - 0.5) / 2)))
    leaf_y = BODY_Y0 + 0.8
    parts.append(box("door_leaf", (DOOR_W - 0.4, 0.16, DOOR_H - 0.2), (0.0, leaf_y, (DOOR_H - 0.2) / 2 + 0.1), M["wood"]))
    parts.append(box("door_stile", (0.12, 0.2, DOOR_H - 0.3), (0.0, leaf_y - 0.06, (DOOR_H - 0.2) / 2 + 0.1), M["wood"]))
    for sign in (-1, 1):
        parts.append(box("door_jamb", (0.34, 0.44, DOOR_H + 0.2), (sign * (DOOR_W / 2 + 0.17), BODY_Y0 - 0.06, (DOOR_H + 0.2) / 2), M["smoothplastic_blanco"]))
    parts.append(box("door_head", (DOOR_W + 0.68, 0.44, 0.34), (0.0, BODY_Y0 - 0.06, DOOR_H + 0.17), M["smoothplastic_blanco"]))
    parts.append(box("threshold", (DOOR_W + 0.6, 1.1, 0.3), (0.0, BODY_Y0 - 0.12, 0.15), M["limestone"]))

    for x in GROUND_WIN_XS:
        window_unit(parts, cuts, M, "y", BODY_Y0, -1, x, GROUND_WIN_W, GROUND_WIN_Z0, GROUND_WIN_Z1)
        for sign in (-1, 1):
            parts.append(box("shutter", (0.5, 0.16, 4.2), (x + sign * (GROUND_WIN_W / 2 + 0.72), BODY_Y0 - 0.02, 3.7), M["smoothplastic_blanco"]))
    for x in UPPER_WIN_XS:
        window_unit(parts, cuts, M, "y", BODY_Y0, -1, x, UPPER_WIN_W, UPPER_Z0, UPPER_Z1)
    for side, y in SIDE_WINDOWS:
        window_unit(parts, cuts, M, "x", side * BODY_HALF, side, y, 2.6, SIDE_WIN_Z0, SIDE_WIN_Z1)

    perforate(wall, cuts)
    parts.insert(0, wall)

    # Zócalo de caliza, junta de plantas y cornisa: la casa se apoya en la caliza, no en una caja azul.
    plinth = slab("plinth", -BODY_HALF - 0.15, BODY_HALF + 0.15, BODY_Y0 - 0.15, BODY_Y1 + 0.12, 0.0, 0.7, M["limestone"])
    perforate(plinth, [box("door_cut2", (DOOR_W, 1.2, 1.4), (0.0, BODY_Y0 + 0.1, 0.4))])
    parts.append(plinth)
    parts.append(slab("string", -BODY_HALF - 0.12, BODY_HALF + 0.12, BODY_Y0 - 0.15, BODY_Y0 + 0.15, STRING_Z0, STRING_Z1, M["limestone"]))
    parts.append(slab("cornice", -BODY_HALF - 0.45, BODY_HALF + 0.45, BODY_Y0 - 0.45, BODY_Y1 + 0.45, CORNICE_Z0, CORNICE_Z1, M["limestone"]))

    # Placa de pizarra con el nombre en letras de caliza, por encima de la puerta y del toldo.
    parts.append(slab("placa", -6.5, 6.5, BODY_Y0 - 0.2, BODY_Y0 + 0.2, PLACA_Z - 1.0, PLACA_Z + 1.0, M["slate"]))
    parts.append(fit_width(letters("VILLA MARGARITA", 1.05, (0.0, BODY_Y0 - 0.25, PLACA_Z), M["limestone"], depth=0.18), 11.6))

    # Buhardilla central sobre la puerta: la cubierta se lee como casa de campo, no como losa.
    dormer = slab("dormer", DORMER_X - DORMER_HALF, DORMER_X + DORMER_HALF, DORMER_Y0, DORMER_Y1, DORMER_Z0, DORMER_Z1, M["smoothplastic_azul"])
    dormer_cuts = [box("dormer_cut", (2.0, 0.9, 1.5), (DORMER_X, DORMER_Y0 + 0.45, 21.9))]
    parts.append(box("dormer_pane", (1.85, 0.1, 1.35), (DORMER_X, DORMER_Y0 + 0.62, 21.9), M["glass"]))
    for sign in (-1, 1):
        parts.append(box("dormer_jamb", (0.3, 0.3, 1.75), (DORMER_X + sign * 1.15, DORMER_Y0 - 0.04, 21.9), M["smoothplastic_blanco"]))
    parts.append(box("dormer_head", (2.3, 0.3, 0.3), (DORMER_X, DORMER_Y0 - 0.04, 22.8), M["smoothplastic_blanco"]))
    parts.append(box("dormer_sill", (2.4, 0.5, 0.22), (DORMER_X, DORMER_Y0 - 0.06, 21.05), M["limestone"]))
    perforate(dormer, dormer_cuts)
    parts.append(dormer)
    parts.append(pitched_roof("dormer_cap", DORMER_X - DORMER_HALF - 0.2, DORMER_X + DORMER_HALF + 0.2, DORMER_Y0 - 0.2, DORMER_Y1 + 0.2, DORMER_Z1, DORMER_Z1 + 0.6, M["slate"], hip=0.5))

    # Cubierta de pizarra a cuatro aguas, con su cumbrera.
    parts.append(pitched_roof("roof", -BODY_HALF - ROOF_OVER, BODY_HALF + ROOF_OVER, BODY_Y0 - ROOF_OVER, BODY_Y1 + ROOF_OVER, EAVE_Z, RIDGE_Z, M["slate"], hip=RIDGE_HIP))
    parts.append(box("ridge_cap", ((BODY_HALF - RIDGE_HIP) * 2 + 0.3, 0.6, 0.24), (0.0, BODY_YC, RIDGE_Z + 0.05), M["slate"]))
    return parts


def build_gate(M):
    """Nivel 1: verja baja de caliza con puerta de madera y porche de lona roja sobre la puerta."""
    parts = []
    # Verja: muro bajo, pilastras y cancela.
    parts.append(slab("fence_w", -FENCE_HALF + 0.55, -GATE_PIER_HALF, FENCE_Y - 0.15, FENCE_Y + 0.15, 0.0, FENCE_Z, M["limestone"]))
    parts.append(slab("fence_e", GATE_PIER_HALF, FENCE_HALF - 0.55, FENCE_Y - 0.15, FENCE_Y + 0.15, 0.0, FENCE_Z, M["limestone"]))
    parts.append(slab("coping_w", -FENCE_HALF + 0.45, -GATE_PIER_HALF - 0.1, FENCE_Y - 0.22, FENCE_Y + 0.22, FENCE_Z, FENCE_Z + 0.12, M["limestone"]))
    parts.append(slab("coping_e", GATE_PIER_HALF + 0.1, FENCE_HALF - 0.45, FENCE_Y - 0.22, FENCE_Y + 0.22, FENCE_Z, FENCE_Z + 0.12, M["limestone"]))
    for x in (-FENCE_HALF, FENCE_HALF):
        parts.append(slab("pier", x - 0.55, x + 0.55, FENCE_Y - 0.25, FENCE_Y + 0.25, 0.0, FENCE_Z + 0.85, M["limestone"]))
        parts.append(slab("pier_cap", x - 0.68, x + 0.68, FENCE_Y - 0.35, FENCE_Y + 0.35, FENCE_Z + 0.85, FENCE_Z + 1.05, M["limestone"]))
    for x in (-GATE_PIER_HALF, GATE_PIER_HALF):
        parts.append(slab("gate_pier", x - 0.45, x + 0.45, FENCE_Y - 0.22, FENCE_Y + 0.22, 0.0, FENCE_Z + 0.7, M["limestone"]))
        parts.append(slab("gate_pier_cap", x - 0.55, x + 0.55, FENCE_Y - 0.3, FENCE_Y + 0.3, FENCE_Z + 0.7, FENCE_Z + 0.9, M["limestone"]))
    for sign in (-1, 1):
        parts.append(slab("gate_leaf", sign * 0.08, sign * (GATE_HALF - 0.08), FENCE_Y - 0.07, FENCE_Y + 0.07, 0.08, 1.55, M["wood"]))
        for z in (0.35, 0.8, 1.25):
            parts.append(slab("gate_slat", sign * 0.14, sign * (GATE_HALF - 0.14), FENCE_Y - 0.11, FENCE_Y + 0.11, z, z + 0.16, M["wood"]))

    # Porche: tarima de caliza, dos postes de madera y toldo de lona roja.
    parts.append(slab("deck", -DECK_X, DECK_X, BODY_Y0, DECK_Y1, 0.0, DECK_Z, M["limestone"]))
    parts.append(slab("step", -2.4, 2.4, DECK_Y1, STEP_Y1, 0.0, STEP_Z, M["limestone"]))
    for sign in (-1, 1):
        parts.append(slab("post", sign * POST_X - 0.17, sign * POST_X + 0.17, POST_Y - 0.17, POST_Y + 0.17, DECK_Z, AWNING_EDGE_Z, M["wood"]))
    run = AWNING_EDGE_Y - BODY_Y0
    fall = AWNING_EDGE_Z - AWNING_WALL_Z
    slope = math.hypot(run, fall)
    angle = math.atan2(-fall, -run)
    canvas = box("awning", (AWNING_W, slope, 0.16), (0.0, (BODY_Y0 + AWNING_EDGE_Y) / 2, (AWNING_WALL_Z + AWNING_EDGE_Z) / 2), M["fabric_rojo"])
    canvas.rotation_euler = (angle, 0.0, 0.0)
    parts.append(canvas)
    parts.append(slab("valance", -AWNING_W / 2, AWNING_W / 2, AWNING_EDGE_Y - 0.07, AWNING_EDGE_Y + 0.07, AWNING_EDGE_Z - 0.42, AWNING_EDGE_Z, M["fabric_rojo"]))
    return parts


def build_garden(M):
    """Nivel 2: césped, setos, dos arbustos recortados y dos cipreses que enmarcan la fachada."""
    parts = []
    grass_top = 0.18
    parts.append(slab("lawn_w", -FENCE_HALF + 0.7, -DECK_X - 0.15, FENCE_Y + 0.15, BODY_Y0 - 0.15, 0.0, grass_top, M["grass_cesped"]))
    parts.append(slab("lawn_e", DECK_X + 0.15, FENCE_HALF - 0.7, FENCE_Y + 0.15, BODY_Y0 - 0.15, 0.0, grass_top, M["grass_cesped"]))
    parts.append(slab("bed_w", -DECK_X - 0.15, -2.45, FENCE_Y + 0.15, DECK_Y1 + 0.1, 0.0, grass_top, M["grass_cesped"]))
    parts.append(slab("bed_e", 2.45, DECK_X + 0.15, FENCE_Y + 0.15, DECK_Y1 + 0.1, 0.0, grass_top, M["grass_cesped"]))
    # Jardín de los costados: la casona va dentro de un jardín, no sobre una explanada.
    parts.append(slab("side_w", -FENCE_HALF + 0.7, -BODY_HALF - 0.2, BODY_Y0 + 0.1, BODY_Y1 + 1.2, 0.0, grass_top, M["grass_cesped"]))
    parts.append(slab("side_e", BODY_HALF + 0.2, FENCE_HALF - 0.7, BODY_Y0 + 0.1, BODY_Y1 + 1.2, 0.0, grass_top, M["grass_cesped"]))
    for x0, x1 in ((-FENCE_HALF + 0.8, -DECK_X - 0.4), (DECK_X + 0.4, FENCE_HALF - 0.8)):
        parts.append(slab("hedge", x0, x1, FENCE_Y + 0.3, FENCE_Y + 0.85, grass_top, grass_top + 0.75, M["grass_seto"]))
    for sign in (-1, 1):
        parts.append(slab("path_hedge", sign * 2.5, sign * 3.0, FENCE_Y + 0.35, DECK_Y1 + 0.15, grass_top, grass_top + 0.8, M["grass_seto"]))
        parts.append(cone("shrub", 0.8, 1.9, (sign * 4.3, FENCE_Y + 0.95, grass_top + 0.95), M["grass_seto"]))
        parts.append(slab("cypress_trunk", sign * 14.2 - 0.14, sign * 14.2 + 0.14, FENCE_Y + 2.6, FENCE_Y + 2.88, grass_top, grass_top + 0.9, M["wood"]))
        parts.append(cone("cypress", 0.8, 4.2, (sign * 14.2, FENCE_Y + 2.74, grass_top + 2.9), M["grass_seto"], verts=6))
    return parts


def build_colonial(M):
    """Nivel 3: crucetas blancas, contraventanas y balcón de madera sobre la puerta."""
    parts = []
    for x in UPPER_WIN_XS:
        muntins(parts, M, x, UPPER_WIN_W, UPPER_Z0, UPPER_Z1)
        for sign in (-1, 1):
            parts.append(box("shutter", (0.5, 0.16, 4.6), (x + sign * (UPPER_WIN_W / 2 + 0.72), BODY_Y0 - 0.02, 15.2), M["smoothplastic_blanco"]))
    # Balcón: losa de caliza, barandilla de madera y siete balaustres.
    parts.append(slab("balcony", -BALCONY_HALF, BALCONY_HALF, BODY_Y0 - BALCONY_DEPTH, BODY_Y0 + 0.2, BALCONY_Z0, BALCONY_Z1, M["limestone"]))
    parts.append(box("rail_top", (BALCONY_HALF * 2, 0.16, 0.16), (0.0, BODY_Y0 - BALCONY_DEPTH + 0.08, RAIL_Z), M["wood"]))
    parts.append(box("rail_bottom", (BALCONY_HALF * 2, 0.14, 0.14), (0.0, BODY_Y0 - BALCONY_DEPTH + 0.08, BALCONY_Z1 + 0.12), M["wood"]))
    for k in range(7):
        x = -BALCONY_HALF + 0.25 + k * (BALCONY_HALF * 2 - 0.5) / 6
        parts.append(box("baluster", (0.13, 0.13, 0.85), (x, BODY_Y0 - BALCONY_DEPTH + 0.08, BALCONY_Z1 + 0.55), M["wood"]))
    parts.append(box("rail_end_w", (0.18, 0.18, 1.0), (-BALCONY_HALF + 0.09, BODY_Y0 - BALCONY_DEPTH + 0.09, BALCONY_Z1 + 0.55), M["wood"]))
    parts.append(box("rail_end_e", (0.18, 0.18, 1.0), (BALCONY_HALF - 0.09, BODY_Y0 - BALCONY_DEPTH + 0.09, BALCONY_Z1 + 0.55), M["wood"]))
    return parts


def build_wing(M):
    """Nivel 4: ala lateral retranqueada, más baja, de azul con cubierta de pizarra a cuatro aguas."""
    parts, cuts = [], []
    wall = slab("wing", WING_X0, WING_X1, WING_Y0, WING_Y1, 0.0, WING_H, M["smoothplastic_azul"])
    window_unit(parts, cuts, M, "y", WING_Y0, -1, (WING_X0 + WING_X1) / 2, 2.4, 5.6, 9.2)
    perforate(wall, cuts)
    parts.insert(0, wall)
    parts.append(slab("wing_plinth", WING_X0 - 0.1, WING_X1 + 0.1, WING_Y0 - 0.1, WING_Y1 + 0.1, 0.0, 0.7, M["limestone"]))
    parts.append(slab("wing_cornice", WING_X0 - 0.3, WING_X1 + 0.3, WING_Y0 - 0.3, WING_Y1 + 0.3, WING_H, WING_H + 0.45, M["limestone"]))
    parts.append(pitched_roof("wing_roof", WING_X0 - 0.2, WING_X1 + 0.2, WING_Y0 - 0.25, WING_Y1 + 0.25, WING_H + 0.45, WING_H + 2.0, M["slate"], along="y", hip=1.4))
    return parts


def build_mirador(M):
    """Nivel 5: torre del mirador sobre el ala oeste, con ventanas y remate de cobre."""
    parts, cuts = [], []
    cx = (TOWER_X0 + TOWER_X1) / 2
    cy = (TOWER_Y0 + TOWER_Y1) / 2
    tower = slab("tower", TOWER_X0, TOWER_X1, TOWER_Y0, TOWER_Y1, TOWER_Z0, TOWER_Z1, M["smoothplastic_azul"])
    window_unit(parts, cuts, M, "y", TOWER_Y0, -1, cx, 3.0, 25.6, 28.8)
    window_unit(parts, cuts, M, "x", TOWER_X0, -1, cy, 3.0, 25.8, 28.6)
    window_unit(parts, cuts, M, "x", TOWER_X1, 1, cy, 3.0, 25.8, 28.6)
    perforate(tower, cuts)
    parts.insert(0, tower)
    parts.append(slab("tower_band", TOWER_X0 - 0.4, TOWER_X1 + 0.4, TOWER_Y0 - 0.4, TOWER_Y1 + 0.4, TOWER_Z1, TOWER_BAND_Z1, M["limestone"]))
    parts.append(pyramid("tower_cap", TOWER_X1 - TOWER_X0 + 0.8, TOWER_CAP_Z1 - TOWER_BAND_Z1, (cx, cy, (TOWER_BAND_Z1 + TOWER_CAP_Z1) / 2), M["metal"]))
    parts.append(cylinder("tower_finial", 0.14, TOWER_FINIAL_Z1 - TOWER_CAP_Z1, (cx, cy, (TOWER_CAP_Z1 + TOWER_FINIAL_Z1) / 2), M["metal"], verts=8))
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
        name = f"villa_{layer}_{rbx.lower()}{suffix}"
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
    """Límites en studs: ancho, fondo y alto, con las mallas en coordenadas de escena."""
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
    builders = {1: build_gate, 2: build_garden, 3: build_colonial, 4: build_wing, 5: build_mirador}
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
    lod = lod_of(objects, "villa_LOD1")
    lod_tris = count(lod)

    for piece in pieces:
        export(piece["obj"], piece["key"] + ".fbx")
    export(lod, "villa_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "cuerpo": {"alto_masa_principal": BODY_H, "alto_nivel_0": levels["0"]["limites"]["alto_maximo_sobre_suelo"]},
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
    print("VILLA_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "villa-margarita.blend"))

    markers = {
        kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["slate"], "gold": M["metal"]})
        for kind in ("house", "hotel", "tower")
    }
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -200.0, 100.0), (0.0, 26.0, 9.0), 31), f"{RENDER_SUBDIR}/villa-margarita-niveles.png")

    # Comparación: nivel 0 frente a un bloque de Bodega (13) y otro de Cine Lux (24), con la figura de 6
    # delante de la fachada, al lado de la puerta y a la vista: sin ella no se puede revisar la puerta.
    hide_all()
    box("ground", (150, 40, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -34.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (34, 0, 12.0), M["block"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-34.0 + 3.0, -7.0, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (-2.0, -122.0, 19.0), (2.0, 0.0, 10.0), 41), f"{RENDER_SUBDIR}/villa-margarita-comparacion.png")
    print("VILLA_DONE")


if __name__ == "__main__":
    main()

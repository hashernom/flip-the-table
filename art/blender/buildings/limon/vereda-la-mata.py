"""Vereda La Mata: condominio abierto de campo, propiedad de la zona Limón, modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el
origen está en el centro de la base, con z = 0 a ras de suelo. Es una sola propiedad compuesta: una
portada de ladrillo y caliza con portalón de 9 × 7,4 y el rótulo, dos casas campestres bajas de ladrillo
con tejado de pizarra y porche, y los jardines con caminos de caliza dentro del solar. La masa principal
—la casa grande— llega a 17,5 en la cumbrera; el nivel 0 se queda en 19,6 con la chimenea.
Cinco añadidos que se suman: verja y entrada, jardines y caminos, pérgola común, casa nueva retranqueada
y torre del depósito con remate de cobre.

Sigue el método de barberia-morro.py y build_cine_lux.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/limon/:
  vereda-la-mata.blend                       escena de revisión (no se versiona)
  vereda-la-mata/vereda_<pieza>_<material>.fbx y vereda_LOD1.fbx
  vereda-la-mata/stats.json                  triángulos por pieza y nivel, límites y materiales
Y en art/render/limon/vereda-la-mata/: vereda-la-mata-niveles.png y vereda-la-mata-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/limon/vereda-la-mata.py
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
OUT = os.path.join(HERE, "vereda-la-mata")
RENDER_SUBDIR = "limon/vereda-la-mata"
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
FRONT = -DEPTH / 2  # el frente da a -Y
GRASS_Z = 0.14
PATH_Z = 0.30

# --- Cerca, portada y rótulo -----------------------------------------------------------------------
WALL_X = 15.9
WALL_Y0, WALL_Y1 = -8.9, -8.3
WALL_Z = 2.3
PIER_XS = (-15.5, -10.5, 10.5, 15.5)
PORTAL_H = 7.4  # portalón de 9 × 7,4: más alto que un avatar de 6
PORTAL_X0, PORTAL_X1 = -4.5, 4.5
PILLAR_Y0, PILLAR_Y1 = -9.0, -7.6
LINTEL_Z0, LINTEL_Z1 = 7.4, 8.2
PLACA_Z0, PLACA_Z1 = 8.3, 10.0
PORTAL_ROOF_EAVE, PORTAL_ROOF_RIDGE = 10.0, 11.5

# --- Casa principal: la masa más alta del cuerpo ---------------------------------------------------
A_X0, A_X1 = -15.6, -5.4
A_Y0, A_Y1 = -5.4, 3.4
A_H = 12.6
A_RIDGE = 17.5
A_ROOF = (-15.95, -5.05, -6.0, 4.0)
A_DOOR_X = -10.5
A_WIN_XS = (-14.2, -6.8)

# --- Casa segunda: hastial a la calle, más baja y retranqueada -------------------------------------
B_X0, B_X1 = 4.8, 15.4
B_Y0, B_Y1 = -2.6, 5.0
B_H = 8.6
B_RIDGE = 12.6
B_ROOF = (4.4, 15.8, -3.2, 5.6)
B_DOOR_X = 10.1
B_WIN_XS = (6.4, 13.8)

# --- Casa nueva del nivel 4, al fondo del patio ----------------------------------------------------
C_X0, C_X1 = -4.2, 4.0
C_Y0, C_Y1 = 4.3, 8.6
C_H = 7.2
C_RIDGE = 10.0
C_ROOF = (-4.5, 4.3, 4.0, 8.9)
C_DOOR_X = -0.2
C_WIN_XS = (-3.1, 2.9)

# --- Pérgola común ---------------------------------------------------------------------------------
P_X0, P_X1 = -3.55, 3.55
P_Y0, P_Y1 = -4.55, -1.1
P_H = 5.9

# Parterres del nivel 0: el jardín tiene que leerse desde el primer nivel.
BEDS_L0 = ((5.4, 9.6, -7.5, -5.7), (-14.6, -7.2, -7.6, -6.6))

# --- Torre del depósito ----------------------------------------------------------------------------
T_X0, T_X1 = 10.0, 13.6
T_Y0, T_Y1 = 5.8, 8.6

TRIANGLE_BUDGET = 3000
BODY_LIMIT = 22.5  # lo que puede llegar el nivel 0 con lo que se pone en la cubierta
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
ZONE_RGB = "FACC15"  # limón, solo como acento y en la casilla pintada

# Material de Roblox, sufijo de color y RGB de cada clave de material de Blender.
RBX = {
    "brick": ("Brick", "", "B0664A"),
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "wood": ("Wood", "", "5A3A24"),
    "grass": ("Grass", "", "4B6B3A"),
    "fabric_rojo": ("Fabric", "_rojo", "C4382B"),
    "metal_acero": ("Metal", "_acero", "A8AEB4"),
    "metal_oro": ("Metal", "_oro", "C9A227"),
    "metal_limon": ("Metal", "_limon", ZONE_RGB),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "wood": flat("wood", "5A3A24", 0.7),
        "grass": flat("grass", "4B6B3A", 0.95),
        "fabric_rojo": flat("fabric_rojo", "C4382B", 0.8),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.28, 0.85),
        "metal_oro": flat("metal_oro", "C9A227", 0.3, 0.9),
        "metal_limon": flat("metal_limon", ZONE_RGB, 0.35, 0.55),
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
        "figure": flat("figure", "3A4048", 0.7),
    }


def slab(name, x0, x1, y0, y1, z0, z1, mat=None):
    """Caja a partir de sus límites: se lee mejor que centro y tamaño en un solar con muchas piezas."""
    return box(name, (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), mat)


def cylinder(name, radius, depth, location, mat, verts, caps):
    """Cilindro vertical: tambor del depósito y collarines."""
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


def cone(name, radius, depth, location, mat, verts):
    """Cono de base circular: remate de cobre del depósito."""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def pitched_roof(name, x0, x1, y0, y1, z_eave, z_ridge, mat, along="x", hip=0.0):
    """Tejado de pizarra a dos aguas (hip=0) o a cuatro aguas (hip>0), con la cumbrera en un eje.

    `along` es el eje de la cumbrera: "x" deja los hastiales a los lados y el faldón mirando a la calle;
    "y" deja el hastial mirando a la calle, como la casa segunda.
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


def window_unit(parts, cuts, M, x, width, z0, z1, face_y):
    """Hueco de verdad (booleano), cristal retranqueado, marco de madera y alféizar de caliza."""
    cuts.append(box("win_cut", (width, 2.5, z1 - z0 + 0.2), (x, face_y + 0.25, (z0 + z1) / 2)))
    parts.append(box("pane", (width - 0.24, 0.1, z1 - z0 - 0.2), (x, face_y + 0.6, (z0 + z1) / 2), M["glass"]))
    frame_y = face_y + 0.2
    parts.append(box("jamb", (0.22, 0.4, z1 - z0), (x - width / 2 + 0.11, frame_y, (z0 + z1) / 2), M["wood"]))
    parts.append(box("jamb", (0.22, 0.4, z1 - z0), (x + width / 2 - 0.11, frame_y, (z0 + z1) / 2), M["wood"]))
    parts.append(box("head", (width, 0.4, 0.24), (x, frame_y, z1 - 0.12), M["wood"]))
    parts.append(box("sill", (width + 0.5, 0.55, 0.22), (x, face_y - 0.05, z0 - 0.11), M["limestone"]))


def door_unit(parts, cuts, M, x, width, height, face_y):
    """Puerta de cristal con jambas y dintel de madera. Más alta que un avatar de 6."""
    cuts.append(box("door_cut", (width, 2.5, height + 0.5), (x, face_y + 0.25, (height - 0.5) / 2)))
    parts.append(box("door_glass", (width - 0.36, 0.1, height - 0.3), (x, face_y + 0.6, (height - 0.3) / 2 + 0.05), M["glass"]))
    parts.append(box("door_jamb", (0.18, 0.4, height), (x - width / 2 + 0.09, face_y + 0.2, height / 2), M["wood"]))
    parts.append(box("door_jamb", (0.18, 0.4, height), (x + width / 2 - 0.09, face_y + 0.2, height / 2), M["wood"]))
    parts.append(box("door_head", (width, 0.4, 0.26), (x, face_y + 0.2, height - 0.13), M["wood"]))


def porch(parts, M):
    """Porche de madera sobre suelo de caliza: el elemento de casa de campo del nivel 0."""
    parts.append(slab("porch_floor", -15.0, -6.0, -6.4, -5.4, 0.10, 0.50, M["limestone"]))
    for x in (-14.7, -10.5, -6.3):
        parts.append(slab("porch_post", x - 0.2, x + 0.2, -6.2, -5.8, 0.50, 8.2, M["wood"]))
    parts.append(slab("porch_beam", -15.0, -6.0, -6.28, -5.72, 7.85, 8.2, M["wood"]))
    parts.append(slab("porch_canopy", -15.2, -5.8, -6.55, -5.35, 8.2, 8.5, M["slate"]))


def build_body(M):
    """Nivel 0: portada con portalón y rótulo, cerca baja, las dos casas campestres y los jardines.

    Se lee como condominio sin rótulo: el conjunto de tejados de pizarra a distintas alturas, los
    porches de madera y las zonas verdes con caminos de caliza.
    """
    parts = []

    # --- Jardines: la hierba del solar y los caminos de caliza que reparten las casas.
    parts.append(slab("grass", -WALL_X, WALL_X, -8.9, 8.9, 0.0, GRASS_Z, M["grass"]))
    for index, (x0, x1, y0, y1) in enumerate(
        (
            (-1.9, 1.9, -8.95, 4.25),  # camino central, de la portada a la casa nueva
            (-6.0, -1.9, -6.4, -5.4),  # ramal al porche de la casa principal
            (1.9, 10.1, -3.4, -2.6),  # ramal a la puerta de la casa segunda
        )
    ):
        parts.append(slab(f"path{index}", x0, x1, y0, y1, 0.10, PATH_Z, M["limestone"]))

    # El jardín ya existe en el nivel 0: dos parterres con bordillo y un seto bajo a cada lado del
    # camino. Sin esto el solar se lee como un patio de cemento.
    for x0, x1, y0, y1 in BEDS_L0:
        parts.append(slab("bed_curb", x0, x1, y0, y0 + 0.25, 0.14, 0.44, M["limestone"]))
        parts.append(slab("bed_curb", x0, x1, y1 - 0.25, y1, 0.14, 0.44, M["limestone"]))
        parts.append(slab("bed_curb", x0, x0 + 0.25, y0 + 0.25, y1 - 0.25, 0.14, 0.44, M["limestone"]))
        parts.append(slab("bed_curb", x1 - 0.25, x1, y0 + 0.25, y1 - 0.25, 0.14, 0.44, M["limestone"]))
    for x0, x1 in ((-3.1, -2.5), (2.5, 3.1)):
        parts.append(slab("hedge_low", x0, x1, -8.0, -6.2, 0.10, 0.65, M["grass"]))

    # --- Cerca baja de caliza con pilastras de ladrillo, abierta en el portalón.
    parts.append(slab("wall_w", -WALL_X, PORTAL_X0 - 1.2, WALL_Y0, WALL_Y1, 0.0, WALL_Z, M["limestone"]))
    parts.append(slab("wall_e", PORTAL_X1 + 1.2, WALL_X, WALL_Y0, WALL_Y1, 0.0, WALL_Z, M["limestone"]))
    for x0, x1 in ((-WALL_X, PORTAL_X0 - 1.2), (PORTAL_X1 + 1.2, WALL_X)):
        parts.append(slab("coping", x0, x1, WALL_Y0 - 0.06, WALL_Y1 + 0.06, WALL_Z, WALL_Z + 0.25, M["limestone"]))
    for x in PIER_XS:
        parts.append(slab("pier", x - 0.4, x + 0.4, WALL_Y0 - 0.1, WALL_Y1 + 0.1, 0.0, WALL_Z + 0.65, M["brick"]))
        parts.append(slab("pier_cap", x - 0.5, x + 0.5, WALL_Y0 - 0.15, WALL_Y1 + 0.15, WALL_Z + 0.65, WALL_Z + 0.9, M["limestone"]))

    # --- Portada: dos pilares de ladrillo, dintel y placa de caliza, y tejadillo de pizarra.
    for x0, x1 in ((-5.7, PORTAL_X0), (PORTAL_X1, 5.7)):
        parts.append(slab("portal_pillar", x0, x1, PILLAR_Y0, PILLAR_Y1, 0.0, PORTAL_H, M["brick"]))
        parts.append(slab("portal_plinth", x0 - 0.08, x1 + 0.08, PILLAR_Y0 - 0.06, PILLAR_Y1 + 0.06, 0.0, 0.9, M["limestone"]))
    parts.append(slab("lintel", -6.1, 6.1, PILLAR_Y0 - 0.05, PILLAR_Y1 + 0.05, LINTEL_Z0, LINTEL_Z1, M["limestone"]))
    parts.append(slab("placa", -5.2, 5.2, -9.18, -8.88, PLACA_Z0, PLACA_Z1, M["limestone"]))
    parts.append(fit_width(letters("VEREDA LA MATA", 1.2, (0.0, -9.25, 9.15), M["wood"], depth=0.16), 9.8))
    parts.append(pitched_roof("portal_roof", -6.5, 6.5, -9.45, -7.15, PORTAL_ROOF_EAVE, PORTAL_ROOF_RIDGE, M["slate"]))

    # --- Casa principal: ladrillo, zócalo y alféizares de caliza, porche de madera y tejado a dos aguas.
    cuts = []
    wall = slab("casa_a_wall", A_X0, A_X1, A_Y0, A_Y1, 0.0, A_H, M["brick"])
    door_unit(parts, cuts, M, A_DOOR_X, 2.4, 6.6, A_Y0)
    for x in A_WIN_XS:
        window_unit(parts, cuts, M, x, 1.5, 1.5, 3.9, A_Y0)
    perforate(wall, cuts)
    parts.append(wall)
    plinth = slab("casa_a_plinth", A_X0 - 0.12, A_X1 + 0.12, A_Y0 - 0.12, A_Y1 + 0.12, 0.0, 0.75, M["limestone"])
    perforate(plinth, [box("door_cut", (2.4, 2.5, 7.1), (A_DOOR_X, A_Y0 + 0.25, 3.05))])
    parts.append(plinth)
    parts.append(pitched_roof("casa_a_roof", *A_ROOF, A_H, A_RIDGE, M["slate"]))
    parts.append(slab("chimney", -13.9, -13.1, 2.4, 3.2, 0.0, 19.3, M["brick"]))
    parts.append(slab("chimney_cap", -14.0, -13.0, 2.3, 3.3, 19.3, 19.6, M["limestone"]))
    porch(parts, M)

    # --- Casa segunda: hastial de pizarra a la calle, más baja y retranqueada respecto a la principal.
    cuts = []
    wall = slab("casa_b_wall", B_X0, B_X1, B_Y0, B_Y1, 0.0, B_H, M["brick"])
    door_unit(parts, cuts, M, B_DOOR_X, 2.4, 6.6, B_Y0)
    for x in B_WIN_XS:
        window_unit(parts, cuts, M, x, 1.5, 1.3, 3.5, B_Y0)
    perforate(wall, cuts)
    parts.append(wall)
    plinth = slab("casa_b_plinth", B_X0 - 0.12, B_X1 + 0.12, B_Y0 - 0.12, B_Y1 + 0.12, 0.0, 0.6, M["limestone"])
    perforate(plinth, [box("door_cut", (2.4, 2.5, 7.1), (B_DOOR_X, B_Y0 + 0.25, 3.05))])
    parts.append(plinth)
    parts.append(pitched_roof("casa_b_roof", *B_ROOF, B_H, B_RIDGE, M["slate"], along="y"))
    return parts


def build_gate(M):
    """Nivel 1: verja y entrada. Cancela de dos hojas con barrotes en el portalón, barandilla sobre la
    cerca y toldo de lona roja bajo el rótulo, para que la entrada se lea desde la calle."""
    parts = []
    for z0 in (1.1, 3.1, 5.35):
        parts.append(slab("gate_rail", -4.56, 4.56, -8.55, -8.35, z0, z0 + 0.25, M["metal_acero"]))
    for x in (-4.45, -0.11, 0.11, 4.45):
        parts.append(slab("gate_stile", x - 0.11, x + 0.11, -8.58, -8.32, 0.02, 5.6, M["metal_acero"]))
    for step in range(9):
        x = -4.36 + step * 1.09
        if abs(x) < 0.3:
            continue
        parts.append(slab("gate_bar", x - 0.09, x + 0.09, -8.55, -8.35, 0.02, 5.6, M["metal_acero"]))
    for x0, x1 in ((-15.8, PORTAL_X0 - 1.2), (PORTAL_X1 + 1.2, 15.8)):
        for z0 in (2.6, 3.18, 3.76):
            parts.append(slab("railing", x0, x1, -8.62, -8.52, z0, z0 + 0.12, M["metal_acero"]))
    for x in (-13.4, -7.9, 7.9, 13.4):
        parts.append(slab("railing_post", x - 0.08, x + 0.08, -8.62, -8.52, 2.5, 3.9, M["metal_acero"]))

    canvas = box("awning", (9.6, 0.9, 0.12), (0.0, -9.4, 7.07), M["fabric_rojo"])
    canvas.rotation_euler = (math.atan2(-0.55, -0.7), 0.0, 0.0)
    parts.append(canvas)
    parts.append(slab("valance", -4.8, 4.8, -9.83, -9.73, 6.5, 6.8, M["fabric_rojo"]))
    return parts


def build_gardens(M):
    """Nivel 2: jardines, setos y caminos. Setos altos que ordenan el solar, parterres con bordillo de
    caliza y el borde de los caminos, para que el verde se lea como jardín y no como una alfombra."""
    parts = []
    for x0, x1, y0, y1, z1 in (
        (-15.5, -6.5, -8.2, -7.7, 1.15),  # seto contra la cerca, lado oeste
        (6.5, 15.5, -8.2, -7.7, 1.15),  # seto contra la cerca, lado este
        (-3.15, -2.45, -5.9, -2.0, 0.95),  # seto que sigue al camino central
        (2.45, 3.15, -5.9, -2.0, 0.95),
        (-15.2, -6.6, 4.2, 5.0, 1.15),  # seto del jardín trasero
        (6.2, 9.6, 5.8, 6.6, 1.05),  # seto delante de la torre
    ):
        parts.append(slab("hedge", x0, x1, y0, y1, 0.10, z1, M["grass"]))

    for x0, x1, y0, y1 in (
        (11.0, 15.3, -7.4, -4.4),  # parterre del jardín delantero este
        (-14.8, -6.6, 5.2, 8.4),  # parterre del jardín trasero
    ):
        parts.append(slab("curb", x0, x1, y0, y0 + 0.3, 0.14, 0.46, M["limestone"]))
        parts.append(slab("curb", x0, x1, y1 - 0.3, y1, 0.14, 0.46, M["limestone"]))
        parts.append(slab("curb", x0, x0 + 0.3, y0 + 0.3, y1 - 0.3, 0.14, 0.46, M["limestone"]))
        parts.append(slab("curb", x1 - 0.3, x1, y0 + 0.3, y1 - 0.3, 0.14, 0.46, M["limestone"]))

    for x0 in (-2.05, 1.9):
        parts.append(slab("path_curb", x0, x0 + 0.15, -8.6, 4.2, 0.10, 0.36, M["limestone"]))
    return parts


def build_pergola(M):
    """Nivel 3: pérgola común de madera sobre el camino, con postes, vigas y listones. Cambia la silueta
    del patio entre las dos casas sin tapar los tejados."""
    parts = []
    for x in (-3.55, 3.10):
        for y in (-4.55, -1.10):
            parts.append(slab("pergola_post", x, x + 0.45, y, y + 0.45, 0.14, P_H, M["wood"]))
    for y in (-4.55, -1.10):
        parts.append(slab("pergola_beam", -3.95, 3.95, y, y + 0.45, P_H, P_H + 0.4, M["wood"]))
    for x in (-3.55, 3.10):
        parts.append(slab("pergola_beam", x, x + 0.45, P_Y0, P_Y1, P_H, P_H + 0.4, M["wood"]))
    for step in range(6):
        y = -4.30 + step * 0.68
        parts.append(slab("pergola_slat", -3.95, 3.95, y, y + 0.24, P_H + 0.4, P_H + 0.66, M["wood"]))
    return parts


def build_new_house(M):
    """Nivel 4: casa nueva retranqueada al fondo del patio, más baja, con tejado a cuatro aguas.
    Añade un tejado más al conjunto, que es lo que identifica al condominio."""
    parts = []
    cuts = []
    wall = slab("casa_c_wall", C_X0, C_X1, C_Y0, C_Y1, 0.0, C_H, M["brick"])
    door_unit(parts, cuts, M, C_DOOR_X, 2.2, 6.4, C_Y0)
    for x in C_WIN_XS:
        window_unit(parts, cuts, M, x, 1.3, 1.2, 3.2, C_Y0)
    perforate(wall, cuts)
    parts.append(wall)
    plinth = slab("casa_c_plinth", C_X0 - 0.1, C_X1 + 0.1, C_Y0 - 0.1, C_Y1 + 0.1, 0.0, 0.55, M["limestone"])
    perforate(plinth, [box("door_cut", (2.2, 2.5, 6.9), (C_DOOR_X, C_Y0 + 0.25, 2.95))])
    parts.append(plinth)
    parts.append(pitched_roof("casa_c_roof", *C_ROOF, C_H, C_RIDGE, M["slate"], hip=1.2))
    return parts


def build_tower(M):
    """Nivel 5: torre del depósito con remate de cobre. Fuste de ladrillo con verdugadas y cornisa de
    caliza, tambor de acero con cinta de limón y cono de cobre. Remata el conjunto sin tapar los tejados."""
    center = ((T_X0 + T_X1) / 2, (T_Y0 + T_Y1) / 2)
    parts = []
    parts.append(slab("tower_plinth", T_X0 - 0.4, T_X1 + 0.4, T_Y0 - 0.3, T_Y1 + 0.3, 0.0, 1.2, M["limestone"]))
    parts.append(slab("tower_shaft", T_X0, T_X1, T_Y0, T_Y1, 1.2, 23.0, M["brick"]))
    for z0 in (8.2, 15.2):
        parts.append(slab("tower_string", T_X0 - 0.14, T_X1 + 0.14, T_Y0 - 0.14, T_Y1 + 0.14, z0, z0 + 0.45, M["limestone"]))
    parts.append(slab("tower_cornice", T_X0 - 0.3, T_X1 + 0.3, T_Y0 - 0.3, T_Y1 + 0.3, 23.0, 23.6, M["limestone"]))
    parts.append(cylinder("tower_tank", 2.05, 5.8, (*center, 26.5), M["metal_acero"], 12, True))
    parts.append(cylinder("tower_band", 2.12, 0.55, (*center, 26.5), M["metal_limon"], 12, True))
    parts.append(cone("tower_cap", 2.25, 2.2, (*center, 30.5), M["metal_oro"], 12))
    parts.append(cylinder("tower_finial", 0.16, 0.8, (*center, 32.0), M["metal_oro"], 6, True))
    return parts


def merge(members, name):
    """Aplica transformaciones y une; con una sola pieza no llama a join (evita «No mesh data to join»)."""
    for member in members:
        select_only(member)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(members) == 1:
        obj = members[0]
        obj.name = name
    else:
        obj = join(members, name)
    origin_at_zero(obj)
    return obj


def group(level, parts, store):
    """Une las piezas de un nivel en una malla por material y color. En Roblox cada malla lleva un material."""
    layer = "body" if level == 0 else f"addon{level}"
    by_material = {}
    for part in parts:
        if not part.data.materials or part.data.materials[0] is None:
            raise RuntimeError(f"{part.name} no tiene material")
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        rbx, suffix, rgb = RBX[key]
        name = f"vereda_{layer}_{rbx.lower()}{suffix}"
        mesh = merge(members, name)
        uv_unwrap(mesh)
        materials = {m.name for m in mesh.data.materials if m is not None}
        if len(materials) != 1:
            raise RuntimeError(f"{name} tiene {len(materials)} materiales")
        store.append({"key": name, "level": level, "material": rbx, "rgb": rgb, "obj": mesh})


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
    sun.rotation_euler = (math.radians(90 - 34.0), 0, math.radians(38))
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

    # Ficha de referencia (caja oscura 8 × 4 × 5) y avatar de 6 de alto para la escala.
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
    builders = {1: build_gate, 2: build_gardens, 3: build_pergola, 4: build_new_house, 5: build_tower}
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
    lod = lod_of(objects, "vereda_LOD1")
    lod_tris = count(lod)

    for piece in pieces:
        export(piece["obj"], piece["key"] + ".fbx")
    export(lod, "vereda_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "cuerpo": {"alto_masa_principal": A_RIDGE, "alto_nivel_0": levels["0"]["limites"]["alto_maximo_sobre_suelo"]},
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
    print("VEREDA_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    body_top = levels["0"]["limites"]["alto_maximo_sobre_suelo"]
    if body_top > BODY_LIMIT:
        raise RuntimeError(f"El nivel 0 llega a {body_top} y no debe pasar de {BODY_LIMIT}")
    max_top = levels["5"]["limites"]["alto_maximo_sobre_suelo"]
    if max_top > MAX_HEIGHT:
        raise RuntimeError(f"Altura total de {max_top} supera {MAX_HEIGHT}")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "vereda-la-mata.blend"))

    markers = {
        kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["metal_acero"], "gold": M["metal_oro"]})
        for kind in ("house", "hotel", "tower")
    }
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -195.0, 125.0), (0.0, 20.0, 4.0), 30), f"{RENDER_SUBDIR}/vereda-la-mata-niveles.png")

    # Comparación: nivel 0 frente a un bloque de Bodega (13) y otro de Cine Lux (24), con una figura de
    # 6 delante de la fachada, al lado del portalón y a la vista.
    hide_all()
    box("ground", (150, 40, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -36.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (36, 0, 12.0), M["block"])
    box("figure_6", (1.6, 1.2, 6.0), (-36.0 + 2.6, -9.6, 3.0), M["figure"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -150.0, 36.0), (0.0, 0.0, 9.0), 47), f"{RENDER_SUBDIR}/vereda-la-mata-comparacion.png")
    print("VEREDA_DONE")


if __name__ == "__main__":
    main()

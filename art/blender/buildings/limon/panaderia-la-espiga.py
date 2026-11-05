"""Panadería La Espiga: panadería de barrio de la zona Limón (Paseo Limón), modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base, con z = 0 a ras de suelo. Cuerpo de ladrillo y caliza de 16 con escaparate de
mostrador y panes, puerta alta, ventana de café y puerta de obrador; en la cubierta van la chimenea del horno
y el silo de harina, que son el rasgo de la casa. El nivel 0 se queda en 20,5 y ya se lee como panadería sin
el rótulo. Cinco añadidos que se suman: toldo de lona, ventana de café con terraza, horno de leña con cúpula,
pabellón del obrador retranqueado y torre del silo con remate de cobre (33,9).

Sigue el método de barberia-morro.py y build_cine_lux.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/limon/:
  panaderia-la-espiga.blend                 escena de revisión (no se versiona)
  panaderia-la-espiga/espiga_<pieza>_<material>.fbx y espiga_LOD1.fbx
  panaderia-la-espiga/stats.json            triángulos por pieza y nivel, límites y materiales
Y en art/render/limon/panaderia-la-espiga/: panaderia-la-espiga-niveles.png y -comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/limon/panaderia-la-espiga.py
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
OUT = os.path.join(HERE, "panaderia-la-espiga")
RENDER_SUBDIR = "limon/panaderia-la-espiga"
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

# --- Cuerpo: muro, zócalo, cornisa y cubierta -------------------------------------------------------
BODY_TOP = 16.0  # alto de la masa principal, el del encargo
BAND_TOP = 15.4  # remate del ladrillo: de ahí para arriba va la caliza de la cornisa
PLINTH_TOP = 0.95
DECK_Z0, DECK_Z1 = 15.25, 15.75
ROOF = DECK_Z1  # lo que se apoya en la cubierta arranca aquí
STRING_Z0, STRING_Z1 = 8.55, 9.0
ATTIC_Z0, ATTIC_Z1 = 13.55, 13.9

# --- Huecos de la fachada ---------------------------------------------------------------------------
ESC_X0, ESC_X1 = -14.4, -4.2  # escaparate con mostrador
ESC_Z0, ESC_Z1 = 1.2, 6.0
DOOR_X0, DOOR_X1 = -1.5, 1.5
DOOR_TOP = 7.2  # 3,0 × 7,2: más alta que la figura de 6
CAF_X0, CAF_X1 = 4.6, 10.4  # ventana de café
CAF_Z0, CAF_Z1 = 1.3, 5.7
OBR_X0, OBR_X1 = 12.2, 14.4  # puerta del obrador
OBR_TOP = 4.8
PLACA_X = 6.8
PLACA_Z0, PLACA_Z1 = 9.0, 11.6  # encima de la puerta y del toldo
AWNING_INNER_Z = 8.45
AWNING_OUTER_Z = 7.6
AWNING_OUTER_Y = -9.85

# --- Chimenea del horno y silo de harina: el rasgo del nivel 0 --------------------------------------
CHIM_X0, CHIM_X1 = 11.2, 13.8
CHIM_Y0, CHIM_Y1 = -8.7, -6.5
SILO_X, SILO_Y = -11.6, -4.2

# --- Horno de leña (nivel 3) ------------------------------------------------------------------------
OVEN_X, OVEN_Y = -0.6, -4.3
OVEN_R = 2.9

# --- Pabellón del obrador (nivel 4) -----------------------------------------------------------------
PAV_X0, PAV_X1 = -15.4, -0.8
PAV_Y0, PAV_Y1 = 1.0, 8.7
PAV_Z0, PAV_Z1 = 15.5, 23.0
PAV_RIDGE = 24.5

# --- Torre del silo (nivel 5) -----------------------------------------------------------------------
TOW_X, TOW_Y = 8.6, 4.6
TOW_BASE_Z0, TOW_BASE_Z1 = 15.4, 20.6
TOW_TOP = 33.9

TRIANGLE_BUDGET = 3000
BODY_LIMIT = 21.0  # el nivel 0 completo no pasa de aquí
MAX_HEIGHT = 34.0
CINE_LUX_L5_TRIANGLES = 3042

FRONT_OFFSET = 2.0
STREET_WIDTH = 34.0
SIDEWALK = 7.0
LOT_DEPTH = 22.0
SPACING = 36.0
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
    }


def slab(name, x0, x1, y0, y1, z0, z1, mat=None):
    """Caja a partir de sus límites: se lee mejor que centro y tamaño en una fachada con muchas piezas."""
    return box(name, (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), mat)


def cut_box(name, x0, x1, z0, z1, y0=None, y1=None):
    """Caja de corte: entra medio stud por delante de la fachada y 2,6 hacia dentro."""
    y0 = FRONT - 0.5 if y0 is None else y0
    y1 = FRONT + 2.6 if y1 is None else y1
    return slab(name, x0, x1, y0, y1, z0, z1)


def cylinder(name, radius, depth, location, mat, verts=12, caps=True):
    """Cilindro vertical: tambor del silo, bandas y collarines."""
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


def cone(name, radius1, radius2, depth, location, mat, verts=12):
    """Cono o tronco de cono vertical: tolva, cúpula del horno y remate de cobre."""
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts,
        radius1=radius1,
        radius2=radius2,
        depth=depth,
        location=location,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def pitched_roof(name, x0, x1, y0, y1, z_eave, z_ridge, mat, hip=0.0):
    """Tejado de pizarra cerrado (con cara inferior): a dos aguas con hip=0 y a cuatro aguas con hip>0."""
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


def fit_width(obj, max_width):
    """Reduce el rótulo de forma uniforme si no cabe en la placa."""
    width = obj.dimensions.x
    if width > max_width:
        select_only(obj)
        factor = max_width / width
        obj.scale = (factor, factor, factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def loaf(parts, M, x, y, z, width=0.5, turn=0.0):
    """Pieza de pan sobre el mostrador o el estante: geometría del escaparate, no prop suelto."""
    obj = box("loaf", (width, 0.34, 0.28), (x, y, z + 0.14), M["brick"])
    if turn:
        obj.rotation_euler = (0, 0, turn)
    parts.append(obj)


def wheat_ear(parts, M, x, z0, scale=1.0):
    """Espiga de hierro: tallo, granos en dos filas, arista y hoja. Es la enseña de la casa."""
    s = scale
    y = FRONT - 0.06
    parts.append(box("ear_stem", (0.14 * s, 0.12, 3.0 * s), (x, y, z0 + 1.5 * s), M["metal_acero"]))
    for row in range(3):
        z = z0 + (1.65 + 0.5 * row) * s
        lean = 0.4 + 0.07 * row
        for side in (-1, 1):
            grain = box("ear_grain", (0.62 * s, 0.1, 0.18 * s), (x + side * 0.34 * s, y, z), M["metal_acero"])
            grain.rotation_euler = (0, side * lean, 0)
            parts.append(grain)
    parts.append(box("ear_tip", (0.14 * s, 0.1, 0.5 * s), (x, y, z0 + 3.25 * s), M["metal_acero"]))
    leaf = box("ear_leaf", (0.5 * s, 0.1, 0.14 * s), (x + 0.32 * s, y, z0 + 0.7 * s), M["metal_acero"])
    leaf.rotation_euler = (0, -0.5, 0)
    parts.append(leaf)


def shop_window(M):
    """Escaparate: hueco de verdad con alféizar, mostrador que vuela y estantes con panes."""
    parts = []
    xc = (ESC_X0 + ESC_X1) / 2
    w = ESC_X1 - ESC_X0
    h = ESC_Z1 - ESC_Z0
    zc = (ESC_Z0 + ESC_Z1) / 2

    # Fondo de cristal: cierra el hueco por dentro (no hay interior modelado).
    parts.append(box("esc_glass", (w + 0.5, 0.12, h + 0.4), (xc, FRONT + 0.75, zc), M["glass"]))
    # Alféizar de caliza y mostrador de madera que vuela hacia la calle.
    parts.append(box("esc_sill", (w + 0.8, 1.1, 0.35), (xc, FRONT + 0.05, ESC_Z0 + 0.17), M["limestone"]))
    parts.append(box("counter", (w - 0.1, 0.95, 0.94), (xc, FRONT + 0.0, 1.55 + 0.47), M["wood"]))
    parts.append(box("counter_top", (w + 0.2, 1.05, 0.18), (xc, FRONT - 0.05, ESC_Z0 + 1.38), M["wood"]))
    # Marco de madera dentro del hueco, con parteluz.
    for x in (ESC_X0 + 0.2, ESC_X1 - 0.2):
        parts.append(box("esc_jamb", (0.4, 0.5, h), (x, FRONT + 0.15, zc), M["wood"]))
    parts.append(box("esc_head", (w, 0.5, 0.4), (xc, FRONT + 0.15, ESC_Z1 - 0.2), M["wood"]))
    parts.append(box("esc_mullion", (0.3, 0.28, 3.2), (xc, FRONT + 0.06, 4.2), M["wood"]))
    # Estantes y panes: el escaparate de una panadería.
    for z in (3.4, 4.6):
        parts.append(box("shelf", (w - 1.2, 0.55, 0.16), (xc, FRONT + 0.25, z), M["wood"]))
    for x, z, turn in (
        (-13.5, 2.67, 0.1),
        (-12.3, 2.67, -0.1),
        (-11.1, 2.67, 0.05),
        (-7.4, 2.67, -0.08),
        (-6.2, 2.67, 0.12),
        (-5.0, 2.67, 0.0),
        (-13.2, 3.48, 0.0),
        (-11.5, 3.48, 0.12),
        (-7.8, 3.48, -0.12),
        (-12.6, 4.68, -0.1),
        (-10.6, 4.68, 0.0),
        (-7.0, 4.68, 0.1),
    ):
        loaf(parts, M, x, FRONT + 0.25, z, 0.52, turn)
    return parts


def shop_door(M):
    """Puerta de la panadería: dos hojas de cristal con montante y umbral, de 7,2 de alto."""
    parts = []
    w = DOOR_X1 - DOOR_X0
    for side in (-1, 1):
        xc = side * 0.68
        parts.append(box("door_leaf", (1.22, 0.12, 6.3), (xc, FRONT + 0.55, 0.62 + 6.3 / 2), M["glass"]))
    parts.append(box("door_stile", (0.16, 0.26, 6.3), (0, FRONT + 0.55, 3.75), M["wood"]))
    parts.append(box("door_kick", (2.9, 0.16, 0.62), (0, FRONT + 0.52, 0.31), M["wood"]))
    for x in (DOOR_X0 + 0.11, DOOR_X1 - 0.11):
        parts.append(box("door_jamb", (0.22, 0.42, DOOR_TOP), (x, FRONT + 0.2, DOOR_TOP / 2), M["wood"]))
    parts.append(box("door_head", (w, 0.42, 0.3), (0, FRONT + 0.2, DOOR_TOP - 0.15), M["wood"]))
    parts.append(box("door_step", (w + 0.7, 0.8, 0.16), (0, FRONT - 0.2, 0.08), M["limestone"]))
    return parts


def cafe_window(M):
    """Ventana del café: hueco de verdad, marco de madera y alféizar de caliza."""
    parts = []
    xc = (CAF_X0 + CAF_X1) / 2
    w = CAF_X1 - CAF_X0
    h = CAF_Z1 - CAF_Z0
    zc = (CAF_Z0 + CAF_Z1) / 2
    parts.append(box("caf_glass", (w + 0.4, 0.12, h + 0.3), (xc, FRONT + 0.8, zc), M["glass"]))
    parts.append(box("caf_sill", (w + 0.8, 0.95, 0.32), (xc, FRONT + 0.08, CAF_Z0 - 0.16), M["limestone"]))
    for x in (CAF_X0 + 0.18, CAF_X1 - 0.18):
        parts.append(box("caf_jamb", (0.36, 0.45, h), (x, FRONT + 0.2, zc), M["wood"]))
    parts.append(box("caf_head", (w, 0.45, 0.35), (xc, FRONT + 0.2, CAF_Z1 - 0.17), M["wood"]))
    parts.append(box("caf_board", (w - 0.9, 0.42, 0.14), (xc, FRONT + 0.3, CAF_Z0 + 0.35), M["wood"]))
    return parts


def bakehouse_door(M):
    """Puerta lateral del obrador: tablón de madera con cinchos de acero y dintel de caliza."""
    parts = []
    xc = (OBR_X0 + OBR_X1) / 2
    w = OBR_X1 - OBR_X0
    parts.append(box("obr_door", (w - 0.2, 0.16, OBR_TOP - 0.15), (xc, FRONT + 0.5, (OBR_TOP - 0.15) / 2), M["wood"]))
    for z in (1.1, 3.9):
        parts.append(box("obr_band", (w - 0.1, 0.1, 0.2), (xc, FRONT + 0.38, z), M["metal_acero"]))
    parts.append(box("obr_lintel", (w + 0.5, 0.45, 0.35), (xc, FRONT + 0.02, OBR_TOP + 0.17), M["limestone"]))
    parts.append(box("obr_step", (w + 0.5, 0.65, 0.14), (xc, FRONT - 0.15, 0.07), M["limestone"]))
    return parts


def cornice_ring(M):
    """Cornisa de caliza perimetral en aro: deja la cubierta de pizarra a la vista desde arriba."""
    return [
        slab("cornice_front", -WIDTH / 2 - 0.35, WIDTH / 2 + 0.35, FRONT - 0.35, FRONT + 0.25, BAND_TOP, BODY_TOP, M["limestone"]),
        slab("cornice_back", -WIDTH / 2 - 0.35, WIDTH / 2 + 0.35, -FRONT - 0.25, -FRONT + 0.35, BAND_TOP, BODY_TOP, M["limestone"]),
        slab("cornice_left", -WIDTH / 2 - 0.35, -WIDTH / 2 + 0.25, FRONT + 0.25, -FRONT - 0.25, BAND_TOP, BODY_TOP, M["limestone"]),
        slab("cornice_right", WIDTH / 2 - 0.25, WIDTH / 2 + 0.35, FRONT + 0.25, -FRONT - 0.25, BAND_TOP, BODY_TOP, M["limestone"]),
    ]


def flour_silo(M):
    """Silo de harina: patas de acero, tolva, tambor con cinchos y tejadillo cónico."""
    parts = []
    x, y = SILO_X, SILO_Y
    parts.append(slab("silo_plinth", x - 2.3, x + 2.3, y - 2.3, y + 2.3, 15.4, 16.15, M["limestone"]))
    for dx in (-1.25, 1.25):
        for dy in (-1.25, 1.25):
            parts.append(box("silo_leg", (0.24, 0.24, 1.1), (x + dx, y + dy, 16.05), M["metal_acero"]))
    parts.append(cone("silo_hopper", 0.5, 1.85, 1.0, (x, y, 17.0), M["metal_acero"], 10))
    parts.append(cylinder("silo_body", 1.85, 2.6, (x, y, 18.8), M["metal_acero"], 10, True))
    parts.append(cylinder("silo_band", 1.93, 0.16, (x, y, 18.0), M["metal_acero"], 10, True))
    parts.append(cone("silo_top", 1.85, 0.5, 0.55, (x, y, 20.38), M["metal_acero"], 10))
    return parts


def oven_chimney(M):
    """Chimenea del horno: fuste de ladrillo, cinta y capitel de caliza y sombrerete de acero."""
    parts = []
    xc = (CHIM_X0 + CHIM_X1) / 2
    yc = (CHIM_Y0 + CHIM_Y1) / 2
    parts.append(slab("chim_shaft", CHIM_X0, CHIM_X1, CHIM_Y0, CHIM_Y1, 15.4, 19.4, M["brick"]))
    parts.append(slab("chim_band", CHIM_X0 - 0.15, CHIM_X1 + 0.15, CHIM_Y0 - 0.15, CHIM_Y1 + 0.15, 18.4, 18.75, M["limestone"]))
    parts.append(slab("chim_corbel", CHIM_X0 - 0.3, CHIM_X1 + 0.3, CHIM_Y0 - 0.3, CHIM_Y1 + 0.3, 19.4, 19.8, M["limestone"]))
    parts.append(slab("chim_cap", CHIM_X0 - 0.4, CHIM_X1 + 0.4, CHIM_Y0 - 0.4, CHIM_Y1 + 0.4, 19.8, 20.02, M["metal_acero"]))
    parts.append(cylinder("chim_flue", 0.42, 0.5, (xc, yc, 20.27), M["metal_acero"], 8, True))
    return parts


def roof_fittings(M):
    """Lo que remata la azotea del cuerpo: la cubierta de pizarra y la escotilla de bajada."""
    parts = [box("deck", (WIDTH - 0.4, DEPTH - 0.4, DECK_Z1 - DECK_Z0), (0, 0, (DECK_Z0 + DECK_Z1) / 2), M["slate"])]
    parts.append(box("hatch", (1.9, 1.9, 0.7), (3.2, 6.0, ROOF + 0.3), M["wood"]))
    return parts


def build_body(M):
    """Nivel 0: panadería completa. Fachada con cuatro huecos de verdad, placa, espiga, chimenea y silo.

    Se lee sin rótulo: escaparate con panes, puerta alta, ventana de café, puerta del obrador, la espiga
    de hierro sobre el escaparate y, en la cubierta, la chimenea del horno y el silo de harina.
    """
    parts = []
    cuts = [
        cut_box("esc_cut", ESC_X0, ESC_X1, ESC_Z0, ESC_Z1),
        cut_box("caf_cut", CAF_X0, CAF_X1, CAF_Z0, CAF_Z1),
        cut_box("door_cut", DOOR_X0, DOOR_X1, -0.5, DOOR_TOP),
        cut_box("obr_cut", OBR_X0, OBR_X1, -0.5, OBR_TOP),
    ]
    wall = box("espiga_wall", (WIDTH, DEPTH, BODY_TOP - 0.6), (0, 0, (BODY_TOP - 0.6) / 2), M["brick"])
    perforate(wall, cuts)
    parts.append(wall)

    # Zócalo de caliza, abierto en la puerta y en la del obrador.
    plinth = box("plinth", (WIDTH + 0.3, DEPTH + 0.3, PLINTH_TOP), (0, 0, PLINTH_TOP / 2), M["limestone"])
    perforate(
        plinth,
        [
            cut_box("door_cut2", DOOR_X0, DOOR_X1, -0.5, DOOR_TOP),
            cut_box("obr_cut2", OBR_X0, OBR_X1, -0.5, OBR_TOP),
        ],
    )
    parts.append(plinth)

    parts.extend(cornice_ring(M))

    # Junta de caliza sobre el escaparate: el toldo cuelga de ella y la placa se apoya encima.
    parts.append(slab("string", -WIDTH / 2 - 0.25, WIDTH / 2 + 0.25, FRONT - 0.3, FRONT + 0.35, STRING_Z0, STRING_Z1, M["limestone"]))
    parts.append(slab("attic_band", -WIDTH / 2 - 0.2, WIDTH / 2 + 0.2, FRONT - 0.18, FRONT + 0.3, ATTIC_Z0, ATTIC_Z1, M["limestone"]))

    # Placa de caliza con el nombre en letras de madera, encima de la puerta y del toldo.
    parts.append(slab("placa", -PLACA_X, PLACA_X, FRONT - 0.35, FRONT, PLACA_Z0, PLACA_Z1, M["limestone"]))
    name = letters(
        "PANADERÍA LA ESPIGA",
        1.15,
        (0, FRONT - 0.36, (PLACA_Z0 + PLACA_Z1) / 2 + 0.05),
        M["wood"],
        depth=0.13,
    )
    parts.append(fit_width(name, 12.6))

    # Pilastras de ladrillo en las esquinas, con capitel de caliza.
    for side in (-1, 1):
        x = side * (WIDTH / 2 - 0.4)
        parts.append(slab("pilaster", x - 0.4, x + 0.4, FRONT - 0.42, FRONT + 0.1, PLINTH_TOP, BODY_TOP - 0.42, M["brick"]))
        parts.append(slab("pilaster_cap", x - 0.5, x + 0.5, FRONT - 0.48, FRONT + 0.15, BODY_TOP - 0.42, BODY_TOP, M["limestone"]))

    parts.extend(shop_window(M))
    parts.extend(shop_door(M))
    parts.extend(cafe_window(M))
    parts.extend(bakehouse_door(M))
    # La espiga de hierro, la enseña, sobre el escaparate y por encima del toldo.
    wheat_ear(parts, M, -10.9, 9.25)
    parts.extend(roof_fittings(M))
    parts.extend(flour_silo(M))
    parts.extend(oven_chimney(M))
    return parts


def build_awning(M):
    """Nivel 1: toldo de lona roja sobre el escaparate, con faldón y brazos de acero."""
    parts = []
    x0, x1 = ESC_X0 - 0.6, ESC_X1 + 0.6
    z_in, z_out = AWNING_INNER_Z, AWNING_OUTER_Z
    y_in, y_out = FRONT, AWNING_OUTER_Y
    length = math.hypot(y_out - y_in, z_out - z_in)
    angle = math.atan2(z_out - z_in, y_out - y_in)
    canvas = box("awning", (x1 - x0, length, 0.14), ((x0 + x1) / 2, (y_in + y_out) / 2, (z_in + z_out) / 2), M["fabric_rojo"])
    canvas.rotation_euler = (angle, 0, 0)
    parts.append(canvas)
    parts.append(slab("awning_valance", x0, x1, y_out - 0.09, y_out + 0.02, z_out - 0.5, z_out - 0.02, M["fabric_rojo"]))
    for x in (x0 + 0.8, x1 - 0.8):
        arm = box("awning_arm", (0.1, length, 0.09), (x, (y_in + y_out) / 2, (z_in + z_out) / 2 - 0.12), M["metal_acero"])
        arm.rotation_euler = (angle, 0, 0)
        parts.append(arm)
    return parts


def build_cafe(M):
    """Nivel 2: el café. Toldilla de lona sobre la ventana, tarima de madera y barandilla de acero: la
    terraza del café sin tapar la ventana del cuerpo."""
    parts = []
    x0, x1 = CAF_X0 - 0.5, CAF_X1 + 0.5
    z_in, z_out = 6.35, 5.7
    y_in, y_out = FRONT, -9.78
    length = math.hypot(y_out - y_in, z_out - z_in)
    angle = math.atan2(z_out - z_in, y_out - y_in)
    canvas = box("cafe_awning", (x1 - x0, length, 0.13), ((x0 + x1) / 2, (y_in + y_out) / 2, (z_in + z_out) / 2), M["fabric_rojo"])
    canvas.rotation_euler = (angle, 0, 0)
    parts.append(canvas)
    parts.append(slab("cafe_valance", x0, x1, y_out - 0.09, y_out + 0.01, z_out - 0.42, z_out - 0.02, M["fabric_rojo"]))

    # Tarima de la terraza, con barandilla de acero en el borde de la calle.
    parts.append(slab("terrace_deck", x0, x1, FRONT - 0.92, FRONT, 0.0, 0.3, M["wood"]))
    for step in range(5):
        x = x0 + 0.18 + step * (x1 - x0 - 0.36) / 4
        parts.append(box("rail_post", (0.14, 0.14, 3.3), (x, -9.76, 0.3 + 1.65), M["metal_acero"]))
    for z in (1.6, 3.35):
        parts.append(slab("rail", x0 + 0.1, x1 - 0.1, -9.83, -9.69, z, z + 0.13, M["metal_acero"]))
    return parts


def build_oven(M):
    """Nivel 3: el horno de leña del obrador. Tambor de ladrillo con cúpula, boca de cobre y cañón de
    chimenea propio: cambia la silueta por el rasgo de la casa."""
    parts = []
    cx, cy = OVEN_X, OVEN_Y
    parts.append(cylinder("oven_drum", OVEN_R, 2.0, (cx, cy, 15.5 + 1.0), M["brick"], 14, True))
    parts.append(cylinder("oven_band", OVEN_R + 0.12, 0.35, (cx, cy, 17.5 + 0.175), M["limestone"], 14, True))
    parts.append(cone("oven_dome", OVEN_R, 1.15, 1.85, (cx, cy, 18.775), M["brick"], 14))
    parts.append(slab("oven_flue", cx - 0.5, cx + 0.5, cy + 0.4, cy + 1.4, 19.3, 22.3, M["brick"]))
    parts.append(slab("oven_flue_cap", cx - 0.68, cx + 0.68, cy + 0.22, cy + 1.58, 22.3, 22.52, M["metal_acero"]))
    parts.append(slab("oven_mouth", cx - 0.75, cx + 0.75, cy - OVEN_R - 0.1, cy - OVEN_R + 0.12, 15.85, 17.35, M["metal_oro"]))
    parts.append(slab("oven_lintel", cx - 0.95, cx + 0.95, cy - OVEN_R - 0.16, cy - OVEN_R + 0.16, 17.35, 17.62, M["limestone"]))
    return parts


def build_annex(M):
    """Nivel 4: pabellón del obrador retranqueado en la mitad trasera de la azotea, con ventanales y
    portón de carga: la ampliación que se ve desde arriba y desde la calle."""
    parts = []
    x0, x1 = PAV_X0, PAV_X1
    y0, y1 = PAV_Y0, PAV_Y1
    z0, z1 = PAV_Z0, PAV_Z1
    cuts = []
    win_z0, win_z1 = 19.6, 22.2
    for x in (-12.4, -7.4):
        cuts.append(cut_box("annex_cut", x - 0.95, x + 0.95, win_z0, win_z1, y0 - 0.4, y0 + 2.3))
        parts.append(box("annex_glass", (1.9, 0.12, 2.5), (x, y0 + 0.6, (win_z0 + win_z1) / 2), M["glass"]))
        parts.append(slab("annex_sill", x - 1.15, x + 1.15, y0 - 0.14, y0 + 0.5, win_z0 - 0.26, win_z0, M["limestone"]))
        for side in (-1, 1):
            parts.append(slab("annex_jamb", x + side * 1.02 - side * 0.14, x + side * 1.02, y0 - 0.12, y0 + 0.5, win_z0, win_z1, M["wood"]))
    # Portón de carga del obrador, cerrado, con dintel de caliza.
    cuts.append(cut_box("annex_door_cut", -3.9, -1.3, z0 - 0.4, 20.9, y0 - 0.4, y0 + 2.3))
    parts.append(box("annex_door", (2.5, 0.2, 5.6), (-2.6, y0 + 0.55, 18.1), M["wood"]))
    for z in (17.2, 18.6, 19.9):
        parts.append(box("annex_door_band", (2.6, 0.1, 0.22), (-2.6, y0 + 0.42, z), M["metal_acero"]))
    parts.append(slab("annex_lintel", -4.2, -1.0, y0 - 0.14, y0 + 0.55, 20.9, 21.25, M["limestone"]))

    wall = box("annex_wall", (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), M["brick"])
    perforate(wall, cuts)
    parts.append(wall)
    parts.append(slab("annex_band", x0 - 0.2, x1 + 0.2, y0 - 0.2, y1 + 0.2, z1 - 0.35, z1, M["limestone"]))
    parts.append(pitched_roof("annex_roof", x0 - 0.35, x1 + 0.35, y0 - 0.35, y1 + 0.3, z1, PAV_RIDGE, M["slate"], hip=1.5))
    return parts


def build_silo_tower(M):
    """Nivel 5: torre del silo con remate de cobre. Basa de ladrillo con cintas, tambor de acero con
    cinchos, cinta de limón y cono de cobre: el remate que se ve desde toda la calle."""
    parts = []
    x, y = TOW_X, TOW_Y
    parts.append(slab("tower_base", x - 2.2, x + 2.2, y - 2.2, y + 2.2, TOW_BASE_Z0, TOW_BASE_Z1, M["brick"]))
    for z in (17.3, 19.5):
        parts.append(slab("tower_base_band", x - 2.35, x + 2.35, y - 2.35, y + 2.35, z, z + 0.35, M["limestone"]))
    parts.append(cylinder("tower_drum", 2.05, 9.5, (x, y, 25.3), M["metal_acero"], 12, True))
    parts.append(cylinder("tower_limon", 2.14, 0.35, (x, y, 20.85), M["metal_limon"], 12, True))
    for z in (23.5, 26.7):
        parts.append(cylinder("tower_band", 2.12, 0.22, (x, y, z), M["metal_acero"], 12, True))
    parts.append(cylinder("tower_collar", 2.2, 0.4, (x, y, 30.25), M["limestone"], 12, True))
    parts.append(cone("tower_cap", 2.5, 0.0, 2.9, (x, y, 31.9), M["metal_oro"], 12))
    parts.append(cylinder("tower_finial", 0.13, 0.5, (x, y, 33.6), M["metal_oro"], 6, True))
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
        name = f"espiga_{layer}_{rbx.lower()}{suffix}"
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

    # Ficha de referencia (caja oscura 8 × 4 × 5) y figura de 6 delante del nivel 0, para la escala.
    box("ficha_ref", (8.0, 4.0, 5.0), (-2.5 * SPACING, SLOT_SIDE, 2.5), M["dark"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-2.5 * SPACING + 3.1, building_y + FRONT - 1.3, 3.0), M["avatar"])
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
    builders = {1: build_awning, 2: build_cafe, 3: build_oven, 4: build_annex, 5: build_silo_tower}
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
    lod = lod_of(objects, "espiga_LOD1")
    lod_tris = count(lod)

    for piece in pieces:
        export(piece["obj"], piece["key"] + ".fbx")
    export(lod, "espiga_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "cuerpo": {"alto_masa_principal": BODY_TOP, "alto_nivel_0": levels["0"]["limites"]["alto_maximo_sobre_suelo"]},
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
    print("ESPIGA_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

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
    for level, data in levels.items():
        limits = data["limites"]
        if abs(limits["x_minimo"]) > 18.0 or abs(limits["x_maximo"]) > 18.0:
            raise RuntimeError(f"nivel {level}: se sale a lo ancho ({limits['x_minimo']} a {limits['x_maximo']})")
        if limits["frente"] < -10.0:
            raise RuntimeError(f"nivel {level}: invade la franja de delante ({limits['frente']})")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "panaderia-la-espiga.blend"))

    markers = {
        kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["metal_acero"], "gold": M["metal_oro"]})
        for kind in ("house", "hotel", "tower")
    }
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -178.0, 66.0), (0.0, 18.0, 9.0), 30), f"{RENDER_SUBDIR}/panaderia-la-espiga-niveles.png")

    # Comparación: el nivel 0 en el centro con la figura de 6 delante de la puerta, y a los lados los
    # bloques de la Bodega (13) y del Cine Lux (24), todos sobre la misma línea y a la misma distancia.
    hide_all()
    box("ground", (320, 320, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], 0.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (-34.0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (34.0, 0, 12.0), M["block"])
    # Figura de 6 de alto, delante de la fachada y al lado de la puerta: es la que valida la puerta.
    box("avatar_ref", (1.6, 1.2, 6.0), (3.1, FRONT - 1.4, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -112.0, 13.0), (0.0, 0.0, 9.5), 36), f"{RENDER_SUBDIR}/panaderia-la-espiga-comparacion.png")
    print("ESPIGA_DONE")


if __name__ == "__main__":
    main()

"""Plaza del Neón: bolera de barrio del Bulevar Magenta, modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de 19,5 —la masa principal— con portalón, escaparates de juegos, una
marquesina con faldón de lona y el nombre en letras 3D pintadas sobre placa; cinco añadidos que se suman:
gran marquesina, escaparate de juegos con paneles pintados, terraza y rótulo de cubierta, pabellón anexo de
juegos y torre del rótulo rematada con el bolo.
El nombre es una marca: no hay gas neón ni luces de casino; la bolera se lee por la marquesina, las letras
pintadas y las ventanas de juegos. Se distingue de Centro Páez (atrio de cristal y pez dorado) y de Neo Mundo
(dos alas con portal abierto) por la marquesina y la torre del bolo.
Sigue el método de barberia-morro.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/magenta/:
  plaza-del-neon/plazaneon_<pieza>_<material>.fbx y plazaneon_LOD1.fbx
  plaza-del-neon/stats.json            triángulos por pieza y nivel, límites y materiales
Y en art/render/magenta/plaza-del-neon/: plaza-del-neon-niveles.png y plaza-del-neon-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/magenta/plaza-del-neon.py
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "plaza-del-neon")
RENDER_SUBDIR = "magenta/plaza-del-neon"
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

WIDTH = 32.0
DEPTH = 18.0
FRONT = -DEPTH / 2  # el frente da a -Y
BODY_H = 19.5  # masa principal
ROOF_DECK = 19.9  # cara superior de la cubierta
PARAPET_TOP = 20.15
MAX_HEIGHT = 34.0
MAX_LEVEL0_HEIGHT = 24.5
FRONT_LIMIT = -10.0
LOT_HALF_WIDTH = 18.0
BACK_LIMIT = 13.0

PORTAL_W = 9.0  # portalón: 9 × 7,4, como el de la Bodega
PORTAL_H = 7.4
PORTAL_RECESS = 1.6
WIN_X = 10.6  # escaparates de juegos a ambos lados del portalón
WIN_W = 8.0
WIN_Z0 = 0.95
WIN_Z1 = 7.3
WIN_DEPTH = 0.9
RIBBON_W = 27.2  # banda de la sala de juegos: ancha y corrida, no ventanitas de vivienda
RIBBON_Z0 = 14.55
RIBBON_Z1 = 17.55
LINTEL_Z0 = 7.5  # banda de caliza sobre el escaparate
LINTEL_Z1 = 7.82

CANOPY_W = 15.6  # marquesina del nivel 0: la bolera se lee ya sin añadidos
CANOPY_Z0 = 8.4
CANOPY_Z1 = 8.85
VALANCE_W = 12.4  # faldón de lona roja colgando de la marquesina
VALANCE_Z0 = 7.2
MARQUEE_W = 16.8  # gran marquesina del nivel 1
MARQUEE_Z1 = 10.2

PLATE_W = 15.6  # placa del rótulo, por encima de la puerta y de la marquesina
PLATE_Z0 = 10.4
PLATE_Z1 = 13.7
PLATE_DEPTH = 0.6
SIGN_Z = 12.05
SIGN_SIZE = 1.45

TERRACE = (-9.8, -5.55)  # terraza de cubierta, delante a la izquierda
TERRACE_W = 11.4
TERRACE_D = 5.9
ROOF_SIGN = (-7.6, -1.7)  # marco de rótulo en la cubierta
ROOF_SIGN_W = 12.4
ROOF_SIGN_Z0 = 21.4
ROOF_SIGN_Z1 = 24.4
ROOF_SIGN_SIZE = 1.35

ANNEX = (8.1, 4.1)  # pabellón anexo de juegos, retranqueado
ANNEX_W = 11.0
ANNEX_D = 7.0
ANNEX_H = 3.3

TOWER = (-7.2, 4.6)  # torre del rótulo, detrás del marco de cubierta
TOWER_W = 5.4
TOWER_Z1 = 27.2
PIN_Z0 = 27.65  # el bolo remata la torre
PIN_H = 5.7

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

# Material de Roblox, sufijo de color y RGB de cada clave de material de Blender.
RBX = {
    "limestone": ("Limestone", "", "D2C9B4"),
    "glass": ("Glass", "", "2E4A63"),
    "slate": ("Slate", "", "4A4E54"),
    "steel": ("Metal", "_acero", "A8AEB4"),
    "gold": ("Metal", "_oro", "C9A227"),
    "magenta": ("Metal", "_magenta", "E85D9E"),
    "fabric_rojo": ("Fabric", "_rojo", "C4382B"),
    "wood": ("Wood", "", "6B4A2E"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "slate": flat("slate", "4A4E54", 0.85),
        "steel": flat("steel", "A8AEB4", 0.25, 0.8),
        "gold": flat("gold", "C9A227", 0.3, 0.9),
        "magenta": flat("magenta", "E85D9E", 0.4, 0.6),
        "fabric_rojo": flat("fabric_rojo", "C4382B", 0.8),
        "wood": flat("wood", "6B4A2E", 0.7),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "E85D9E", 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "3A4046", 0.8),
    }


def cylinder(name, radius, depth, location, mat, verts, caps):
    """Cilindro vertical."""
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


def lathe(name, profile, location, mat, segments=9):
    """Sólido de revolución: perfil (radio, z) girado alrededor del eje Z. Es el bolo de la torre."""
    cx, cy, cz = location
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    build = bmesh.new()
    rings = []
    for radius, z in profile:
        ring = []
        for index in range(segments):
            angle = 2.0 * math.pi * index / segments
            ring.append(build.verts.new((cx + radius * math.cos(angle), cy + radius * math.sin(angle), cz + z)))
        rings.append(ring)
    for low, high in zip(rings, rings[1:]):
        for index in range(segments):
            nxt = (index + 1) % segments
            build.faces.new((low[index], low[nxt], high[nxt], high[index]))
    build.faces.new(list(reversed(rings[0])))
    build.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(build, faces=build.faces)
    build.to_mesh(mesh)
    build.free()
    obj.data.materials.append(mat)
    return obj


def slat(name, size, location, mat, angle_x):
    """Caja inclinada: toldos. Se aplica la rotación para que la malla quede en coordenadas de escena."""
    obj = box(name, size, location, mat)
    obj.rotation_euler = (angle_x, 0.0, 0.0)
    select_only(obj)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


def sign_letters(text, size, location, mat, max_width, depth=0.2):
    """Letras 3D del rótulo, reducidas si no caben en la placa."""
    obj = letters(text, size, location, mat, depth=depth)
    width = obj.dimensions.x
    if width > max_width:
        select_only(obj)
        factor = max_width / width
        obj.scale = (factor, factor, factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def build_body(M):
    """Nivel 0: bolera de barrio. Portalón, escaparates, marquesina con lona, placa con el nombre y cubierta."""
    parts = []

    # Muro con huecos de verdad: portalón, dos escaparates y la banda corrida de la sala de juegos.
    cutters = [
        box("cut_portal", (PORTAL_W, PORTAL_RECESS, PORTAL_H), (0.0, FRONT + PORTAL_RECESS / 2, PORTAL_H / 2)),
        box("cut_ribbon", (RIBBON_W, 0.55, RIBBON_Z1 - RIBBON_Z0), (0.0, FRONT + 0.275, (RIBBON_Z0 + RIBBON_Z1) / 2)),
    ]
    for side in (-1, 1):
        cutters.append(
            box("cut_win", (WIN_W, WIN_DEPTH, WIN_Z1 - WIN_Z0), (side * WIN_X, FRONT + WIN_DEPTH / 2, (WIN_Z0 + WIN_Z1) / 2))
        )
    wall = box("plazaneon_wall", (WIDTH, DEPTH, BODY_H), (0.0, 0.0, BODY_H / 2), M["limestone"])
    perforate(wall, cutters)
    parts.append(wall)

    # Zócalo y banda de caliza sobre el escaparate, partidos por el portalón.
    for side in (-1, 1):
        parts.append(box("plinth", (11.55, 0.5, 0.85), (side * 10.275, FRONT - 0.05, 0.425), M["limestone"]))
        parts.append(
            box("lintel", (11.7, 0.5, LINTEL_Z1 - LINTEL_Z0), (side * 10.35, FRONT - 0.1, (LINTEL_Z0 + LINTEL_Z1) / 2), M["limestone"])
        )

    # Pilastras de caliza: enmarcan el portalón en la planta baja y las esquinas del edificio.
    for x in (-4.85, 4.85):
        parts.append(box("pilaster", (0.7, 0.55, LINTEL_Z1), (x, FRONT - 0.25, LINTEL_Z1 / 2), M["limestone"]))
    for x in (-15.65, 15.65):
        parts.append(box("corner", (0.7, 0.55, BODY_H), (x, FRONT - 0.25, BODY_H / 2), M["limestone"]))

    # Escaparates de juegos: cristal oscuro, carpintería de acero y travesaño, como un escaparate de calle.
    for side in (-1, 1):
        x = side * WIN_X
        parts.append(box("win_glass", (WIN_W - 0.3, 0.12, WIN_Z1 - WIN_Z0 - 0.3), (x, FRONT + WIN_DEPTH - 0.15, (WIN_Z0 + WIN_Z1) / 2), M["glass"]))
        parts.append(box("win_sill", (WIN_W + 0.7, 0.6, 0.35), (x, FRONT - 0.1, WIN_Z0), M["steel"]))
        parts.append(box("win_head", (WIN_W + 0.7, 0.6, 0.35), (x, FRONT - 0.1, WIN_Z1), M["steel"]))
        for inner in (-1, 1):
            parts.append(box("win_jamb", (0.35, 0.6, WIN_Z1 - WIN_Z0), (x + inner * WIN_W / 2, FRONT - 0.1, (WIN_Z0 + WIN_Z1) / 2), M["steel"]))
            parts.append(box("win_mullion", (0.14, 0.3, WIN_Z1 - WIN_Z0 - 0.6), (x + inner * 1.6, FRONT + WIN_DEPTH - 0.2, (WIN_Z0 + WIN_Z1) / 2), M["steel"]))
        parts.append(box("win_transom", (WIN_W - 0.4, 0.3, 0.16), (x, FRONT + WIN_DEPTH - 0.2, 5.4), M["steel"]))

    # Banda corrida de la sala de juegos, arriba: seis paños anchos, no una hilera de ventanitas.
    parts.append(box("ribbon_glass", (RIBBON_W - 0.3, 0.12, RIBBON_Z1 - RIBBON_Z0 - 0.3), (0.0, FRONT + 0.4, (RIBBON_Z0 + RIBBON_Z1) / 2), M["glass"]))
    parts.append(box("ribbon_sill", (RIBBON_W + 0.6, 0.55, 0.3), (0.0, FRONT - 0.05, RIBBON_Z0), M["steel"]))
    parts.append(box("ribbon_head", (RIBBON_W + 0.6, 0.55, 0.3), (0.0, FRONT - 0.05, RIBBON_Z1), M["steel"]))
    for x in (-9.1, -4.55, 0.0, 4.55, 9.1):
        parts.append(box("ribbon_mullion", (0.22, 0.4, RIBBON_Z1 - RIBBON_Z0), (x, FRONT + 0.1, (RIBBON_Z0 + RIBBON_Z1) / 2), M["steel"]))

    # Portalón: vestíbulo de cristal al fondo del hueco, con la carpintería de madera de la casa.
    parts.append(box("door_glass", (PORTAL_W - 0.4, 0.12, PORTAL_H - 0.3), (0.0, FRONT + PORTAL_RECESS - 0.1, (PORTAL_H - 0.3) / 2 + 0.15), M["glass"]))
    for x in (-4.35, 0.0, 4.35):
        parts.append(box("door_jamb", (0.22, 0.34, PORTAL_H), (x, FRONT + PORTAL_RECESS - 0.25, PORTAL_H / 2), M["wood"]))
    parts.append(box("door_head", (PORTAL_W, 0.34, 0.24), (0.0, FRONT + PORTAL_RECESS - 0.25, PORTAL_H - 0.12), M["wood"]))
    parts.append(box("door_rail", (PORTAL_W - 0.4, 0.3, 0.18), (0.0, FRONT + PORTAL_RECESS - 0.25, 6.95), M["wood"]))
    for side in (-1, 1):
        parts.append(box("door_kick", (4.1, 0.3, 0.55), (side * 2.2, FRONT + PORTAL_RECESS - 0.25, 0.43), M["wood"]))
    parts.append(box("threshold", (8.9, 0.8, 0.2), (0.0, FRONT - 0.4, 0.1), M["limestone"]))

    # Marquesina del cuerpo: la bolera ya se reconoce a nivel 0. Vuela hasta y = -9,98 y su cara de arriba
    # es de pizarra, para que se lea como un plano que vuela y no como una línea.
    parts.append(box("canopy", (CANOPY_W, 1.05, CANOPY_Z1 - CANOPY_Z0), (0.0, FRONT - 0.42, (CANOPY_Z0 + CANOPY_Z1) / 2), M["slate"]))
    parts.append(box("canopy_drip", (CANOPY_W, 0.3, 0.55), (0.0, FRONT - 0.83, CANOPY_Z1 - 0.27), M["steel"]))
    for x in (-7.0, 7.0):
        parts.append(box("canopy_bracket", (0.28, 1.0, 0.55), (x, FRONT - 0.45, CANOPY_Z0 - 0.27), M["steel"]))
    parts.append(box("valance", (VALANCE_W, 0.16, CANOPY_Z0 - VALANCE_Z0), (0.0, FRONT - 0.9, (VALANCE_Z0 + CANOPY_Z0) / 2), M["fabric_rojo"]))
    parts.append(box("valance_hem", (VALANCE_W + 0.1, 0.2, 0.14), (0.0, FRONT - 0.87, VALANCE_Z0 + 0.07), M["fabric_rojo"]))

    # Placa del rótulo, por encima de la puerta y de la marquesina: tablero de pizarra con las letras de caliza,
    # como el cartel pintado de una bolera de barrio.
    parts.append(box("sign_plate", (PLATE_W, PLATE_DEPTH, PLATE_Z1 - PLATE_Z0), (0.0, FRONT - 0.3, (PLATE_Z0 + PLATE_Z1) / 2), M["slate"]))
    parts.append(box("sign_coping", (PLATE_W + 0.2, 0.75, 0.18), (0.0, FRONT - 0.28, PLATE_Z1 + 0.09), M["steel"]))
    parts.append(
        sign_letters("PLAZA DEL NEÓN", SIGN_SIZE, (0.0, FRONT - 0.62, SIGN_Z), M["limestone"], PLATE_W - 1.6, depth=0.22)
    )

    # Cornisa y cubierta: caseta de escalera, climatización y conductos, para que se lea desde arriba.
    parts.append(box("cornice_front", (WIDTH + 0.7, 0.7, PARAPET_TOP - BODY_H), (0.0, FRONT - 0.2, (BODY_H + PARAPET_TOP) / 2), M["limestone"]))
    parts.append(box("cornice_back", (WIDTH + 0.7, 0.7, PARAPET_TOP - BODY_H), (0.0, -FRONT + 0.2, (BODY_H + PARAPET_TOP) / 2), M["limestone"]))
    for side in (-1, 1):
        parts.append(box("cornice_side", (0.7, DEPTH + 0.1, PARAPET_TOP - BODY_H), (side * 15.85, 0.0, (BODY_H + PARAPET_TOP) / 2), M["limestone"]))
    parts.append(box("roof_deck", (31.7, 17.7, ROOF_DECK - BODY_H), (0.0, 0.0, (BODY_H + ROOF_DECK) / 2), M["slate"]))
    parts.append(box("stair_house", (4.0, 3.2, 2.2), (11.0, -5.5, ROOF_DECK + 1.1), M["limestone"]))
    parts.append(box("stair_door", (0.9, 0.16, 1.7), (11.0, -7.16, ROOF_DECK + 0.85), M["slate"]))
    parts.append(box("hvac", (3.0, 2.2, 1.4), (6.0, -1.5, ROOF_DECK + 0.7), M["slate"]))
    parts.append(box("hvac_cap", (2.4, 1.6, 0.2), (6.0, -1.5, ROOF_DECK + 1.5), M["steel"]))
    parts.append(box("duct", (2.6, 0.6, 0.6), (8.6, -2.9, ROOF_DECK + 0.35), M["steel"]))
    parts.append(box("hatch", (1.6, 1.6, 0.7), (-1.8, 3.0, ROOF_DECK + 0.35), M["slate"]))
    return parts


def build_marquee(M):
    """Nivel 1: gran marquesina sobre la entrada y toldos de lona sobre los escaparates de juegos."""
    parts = []
    # La lona roja es lo que hace de marquesina grande: sube por encima del vuelo y se ve desde lejos.
    parts.append(box("marquee_board", (MARQUEE_W, 0.95, MARQUEE_Z1 - CANOPY_Z1), (0.0, FRONT - 0.51, (CANOPY_Z1 + MARQUEE_Z1) / 2), M["fabric_rojo"]))
    parts.append(box("marquee_trim", (MARQUEE_W + 0.15, 0.16, 0.14), (0.0, FRONT - 0.9, MARQUEE_Z1 + 0.07), M["magenta"]))
    # Toldos de lona sobre los escaparates: rematan el escaparate de juegos del nivel 1.
    for side in (-1, 1):
        x = side * WIN_X
        parts.append(slat("awning", (WIN_W, 0.95, 0.12), (x, FRONT - 0.45, 7.6), M["fabric_rojo"], math.radians(16.0)))
        parts.append(box("awning_bar", (WIN_W, 0.12, 0.16), (x, FRONT - 0.88, 7.47), M["steel"]))
    return parts


def build_shopfront(M):
    """Nivel 2: escaparate de juegos con carpintería fina y paneles pintados con el acento de la zona."""
    parts = []
    for side in (-1, 1):
        x = side * WIN_X
        # Carpintería fina del escaparate, en el plano del cristal.
        for inner in (-1, 1):
            parts.append(box("pane_mullion", (0.12, 0.26, WIN_Z1 - WIN_Z0 - 0.6), (x + inner * 3.3, FRONT + WIN_DEPTH - 0.18, (WIN_Z0 + WIN_Z1) / 2), M["steel"]))
        for z in (2.4, 4.9):
            parts.append(box("pane_rail", (WIN_W - 0.4, 0.26, 0.12), (x, FRONT + WIN_DEPTH - 0.18, z), M["steel"]))
        # Filete de acento sobre la banda de caliza del escaparate.
        parts.append(box("lintel_line", (11.4, 0.12, 0.1), (side * 10.5, FRONT - 0.38, LINTEL_Z0 + 0.12), M["magenta"]))
        # Paneles pintados junto a la placa del rótulo: tablero oscuro enmarcado en caliza, con el acento
        # de la zona en el filete de abajo y no en el paño.
        parts.append(box("panel_back", (4.8, 0.26, 2.7), (side * 11.1, FRONT - 0.05, 11.5), M["limestone"]))
        parts.append(box("painted_panel", (4.4, 0.3, 2.3), (side * 11.1, FRONT - 0.12, 11.5), M["slate"]))
        parts.append(box("panel_edge", (4.4, 0.12, 0.1), (side * 11.1, FRONT - 0.29, 10.4), M["magenta"]))
    # Friso pintado bajo la banda de la sala de juegos.
    parts.append(box("painted_frieze", (RIBBON_W + 0.8, 0.35, 0.45), (0.0, FRONT - 0.1, 14.2), M["limestone"]))
    parts.append(box("frieze_line", (RIBBON_W + 0.9, 0.12, 0.1), (0.0, FRONT - 0.29, 14.03), M["magenta"]))
    return parts


def build_terrace(M):
    """Nivel 3: terraza en la cubierta y marco de rótulo con el nombre, que cambia la silueta."""
    parts = []
    cx, cy = TERRACE
    parts.append(box("terrace_deck", (TERRACE_W, TERRACE_D, 0.26), (cx, cy, ROOF_DECK + 0.13), M["slate"]))
    parts.append(box("terrace_parapet", (TERRACE_W + 0.5, 0.35, 0.85), (cx, cy - TERRACE_D / 2, ROOF_DECK + 0.26 + 0.425), M["limestone"]))
    for side in (-1, 1):
        parts.append(box("terrace_parapet", (0.35, TERRACE_D, 0.85), (cx + side * (TERRACE_W / 2 + 0.07), cy, ROOF_DECK + 0.26 + 0.425), M["limestone"]))
    # Barandilla de acero sobre el antepecho, como pide el kit de la zona.
    parts.append(box("terrace_rail", (TERRACE_W + 0.5, 0.14, 0.12), (cx, cy - TERRACE_D / 2, ROOF_DECK + 1.17), M["steel"]))
    for side in (-1, 1):
        parts.append(box("terrace_rail", (0.14, TERRACE_D, 0.12), (cx + side * (TERRACE_W / 2 + 0.07), cy, ROOF_DECK + 1.17), M["steel"]))

    # Marco de rótulo de la cubierta: dos pies de caliza y el panel con las letras, mirando a la calle.
    sx, sy = ROOF_SIGN
    for side in (-1, 1):
        parts.append(box("roof_sign_post", (0.6, 0.6, ROOF_SIGN_Z0 - ROOF_DECK), (sx + side * (ROOF_SIGN_W / 2 - 0.3), sy, (ROOF_DECK + ROOF_SIGN_Z0) / 2), M["limestone"]))
    parts.append(box("roof_sign_panel", (ROOF_SIGN_W, 0.55, ROOF_SIGN_Z1 - ROOF_SIGN_Z0), (sx, sy, (ROOF_SIGN_Z0 + ROOF_SIGN_Z1) / 2), M["slate"]))
    for z in (ROOF_SIGN_Z0 + 0.08, ROOF_SIGN_Z1 - 0.08):
        parts.append(box("roof_sign_bar", (ROOF_SIGN_W + 0.2, 0.62, 0.16), (sx, sy, z), M["steel"]))
    parts.append(box("roof_sign_line", (ROOF_SIGN_W - 0.6, 0.12, 0.1), (sx, sy - 0.36, ROOF_SIGN_Z0 + 0.55), M["magenta"]))
    parts.append(
        sign_letters("PLAZA DEL NEÓN", ROOF_SIGN_SIZE, (sx, sy - 0.32, (ROOF_SIGN_Z0 + ROOF_SIGN_Z1) / 2), M["limestone"], ROOF_SIGN_W - 1.2, depth=0.2)
    )
    return parts


def build_annex(M):
    """Nivel 4: pabellón anexo de juegos, retranqueado en la cubierta, con banda de cristal."""
    parts = []
    cx, cy = ANNEX
    annex = box("annex", (ANNEX_W, ANNEX_D, ANNEX_H), (cx, cy, ROOF_DECK + ANNEX_H / 2), M["limestone"])
    glass_cut = box("annex_cut", (ANNEX_W - 2.6, 0.45, 1.35), (cx, cy - ANNEX_D / 2 + 0.225, ROOF_DECK + 2.2))
    perforate(annex, [glass_cut])
    parts.append(annex)
    parts.append(box("annex_glass", (ANNEX_W - 2.8, 0.12, 1.2), (cx, cy - ANNEX_D / 2 + 0.4, ROOF_DECK + 2.2), M["glass"]))
    parts.append(box("annex_head", (ANNEX_W - 2.4, 0.5, 0.22), (cx, cy - ANNEX_D / 2 - 0.06, ROOF_DECK + 2.94), M["steel"]))
    parts.append(box("annex_sill", (ANNEX_W - 2.4, 0.5, 0.22), (cx, cy - ANNEX_D / 2 - 0.06, ROOF_DECK + 1.46), M["steel"]))
    parts.append(box("annex_roof", (ANNEX_W + 0.6, ANNEX_D + 0.6, 0.3), (cx, cy, ROOF_DECK + ANNEX_H + 0.15), M["slate"]))
    parts.append(box("annex_trim", (ANNEX_W + 0.7, 0.2, 0.12), (cx, cy - ANNEX_D / 2 - 0.2, ROOF_DECK + ANNEX_H + 0.28), M["gold"]))
    return parts


def build_crown(M):
    """Nivel 5: torre del rótulo detrás del marco de cubierta, rematada con el bolo de la bolera."""
    parts = []
    parts.append(box("tower", (TOWER_W, TOWER_W, TOWER_Z1 - ROOF_DECK), (TOWER[0], TOWER[1], (ROOF_DECK + TOWER_Z1) / 2), M["limestone"]))
    for z in (ROOF_DECK + 1.1, TOWER_Z1 - 1.4):
        parts.append(box("tower_band", (TOWER_W + 0.2, TOWER_W + 0.2, 0.18), (TOWER[0], TOWER[1], z), M["steel"]))
    parts.append(box("tower_cap", (TOWER_W + 0.5, TOWER_W + 0.5, 0.45), (TOWER[0], TOWER[1], TOWER_Z1 + 0.225), M["gold"]))
    parts.append(cylinder("pin_collar", 0.95, 0.3, (TOWER[0], TOWER[1], PIN_Z0 - 0.15), M["gold"], 9, True))
    profile = [
        (0.55, 0.0),
        (0.95, 0.30),
        (1.25, 1.05),
        (1.35, 1.80),
        (1.20, 2.55),
        (0.85, 3.15),
        (0.55, 3.45),
        (0.44, 3.80),
        (0.44, 4.20),
        (0.52, 4.45),
        (0.80, 4.70),
        (0.92, 4.95),
        (0.85, 5.20),
        (0.60, 5.45),
        (0.32, 5.60),
        (0.26, 5.70),
    ]
    parts.append(lathe("giant_pin", profile, (TOWER[0], TOWER[1], PIN_Z0), M["limestone"], segments=9))
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
        name = f"plazaneon_{layer}_{rbx.lower()}{suffix}"
        if len(members) == 1:
            # Un solo objeto no se puede unir: se le pone el origen en la base y se renombra.
            origin_at_zero(members[0])
            members[0].name = name
            uv_unwrap(members[0])
            mesh = members[0]
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

    # Ficha de referencia (caja oscura 8 × 4 × 5, sin taxi) y avatar de 6 de alto para la escala.
    box("ficha_ref", (8.0, 4.0, 5.0), (-2.5 * SPACING, SLOT_SIDE, 2.5), M["dark"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-2.5 * SPACING + 6.3, building_y + FRONT - 2.0, 3.0), M["avatar"])
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
    # Los FBX de una corrida anterior no se quedan: la carpeta acaba con las piezas del stats.json actual.
    for stale in sorted(os.listdir(OUT)):
        if stale.endswith(".fbx"):
            os.remove(os.path.join(OUT, stale))
    render_dir = os.path.join(REPO, "art", "render", *RENDER_SUBDIR.split("/"))
    os.makedirs(render_dir, exist_ok=True)

    M = make_materials()
    pieces = []

    # Nivel 0: cuerpo. Niveles 1 a 5: añadidos que se suman sin sustituir nada.
    group(0, build_body(M), pieces)
    builders = {1: build_marquee, 2: build_shopfront, 3: build_terrace, 4: build_annex, 5: build_crown}
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
    lod = lod_of(objects, "plazaneon_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "plazaneon_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "altura_cuerpo": BODY_H,
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
    print("PLAZANEON_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    top0 = levels["0"]["limites"]
    if top0["alto_maximo_sobre_suelo"] > MAX_LEVEL0_HEIGHT:
        raise RuntimeError(f"Nivel 0 de {top0['alto_maximo_sobre_suelo']} pasa de {MAX_LEVEL0_HEIGHT}")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] > MAX_HEIGHT:
        raise RuntimeError(f"Altura total de {levels['5']['limites']['alto_maximo_sobre_suelo']} pasa de {MAX_HEIGHT}")
    for level, data in levels.items():
        limits = data["limites"]
        if limits["frente"] < FRONT_LIMIT:
            raise RuntimeError(f"Nivel {level}: el frente llega a {limits['frente']}, más allá de {FRONT_LIMIT}")
        if max(abs(limits["x_minimo"]), abs(limits["x_maximo"])) > LOT_HALF_WIDTH:
            raise RuntimeError(f"Nivel {level}: se sale del solar a lo ancho ({limits['x_minimo']} a {limits['x_maximo']})")
        if limits["fondo_maximo"] > BACK_LIMIT:
            raise RuntimeError(f"Nivel {level}: se sale por el fondo ({limits['fondo_maximo']})")

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

    markers = {
        kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["steel"], "gold": M["gold"]})
        for kind in ("house", "hotel", "tower")
    }
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -190.0, 78.0), (0.0, 22.0, 10.0), 30), f"{RENDER_SUBDIR}/plaza-del-neon-niveles.png")

    # Comparación: nivel 0 frente a un bloque de Bodega (13) y otro de Cine Lux (24), con la figura de 6
    # delante de la fachada y al lado de la puerta, que es lo que permite revisar la puerta.
    hide_all()
    box("ground", (170, 46, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -33.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (0.0, 0.0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (34.0, 0.0, 12.0), M["block"])
    # Figura de 6 de alto (1,6 × 1,2 × 6) en la acera, delante de la fachada y al lado de la puerta: oscura,
    # con la pared clara detrás, y separada del muro para que se lea como un volumen aparte.
    box("avatar_ref", (1.6, 1.2, 6.0), (-27.65, -13.0, 3.0), M["dark"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -125.0, 21.0), (0.0, 0.0, 11.0), 38), f"{RENDER_SUBDIR}/plaza-del-neon-comparacion.png")
    print("PLAZANEON_DONE")


if __name__ == "__main__":
    main()

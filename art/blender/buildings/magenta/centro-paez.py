"""Centro Páez: gran almacén del Bulevar Magenta, modelado desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de 18,5 —la masa principal— con atrio de cristal entre dos machones de
caliza, pez de oro sobre la galería del atrio, escaparates y rótulo. Cinco añadidos que se suman: marquesina y
toldos, bandas de ventanales y vitrinas, terraza de la galería, pabellón anexo y torre del rótulo.
Se distingue de Neo Mundo (dos alas con portal abierto) y de Plaza del Neón (marquesina de bolera) por el atrio
de cristal que sube sobre la cubierta, el pez dorado y el rótulo de coronación.
Sigue el método de barberia-morro.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/magenta/:
  centro-paez.blend                  escena de revisión (no se versiona)
  centro-paez/paez_<pieza>_<material>.fbx y paez_LOD1.fbx
  centro-paez/stats.json             triángulos por pieza y nivel, límites y materiales
Y en art/render/magenta/centro-paez/: centro-paez-niveles.png y centro-paez-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/magenta/centro-paez.py
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
OUT = os.path.join(HERE, "centro-paez")
RENDER_SUBDIR = "magenta/centro-paez"
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

WIDTH = 32.0
DEPTH = 18.0
FRONT = -DEPTH / 2  # el frente da a -Y
BODY_H = 18.5  # masa principal
ROOF_Z = 18.8  # cara superior de la cubierta
CORNICE_TOP = 19.15
RECESS = 2.6  # fondo del atrio: es lo que deja ver el pez
PORTAL_DEPTH = 1.8  # el portalón es más somero que el atrio, para que la puerta no quede en un agujero
PORTAL_W = 9.0  # portalón, como el de la Bodega
PORTAL_H = 7.4
SHOP_W = 5.6  # escaparate grande, no ventanita de vivienda
SHOP_Z0 = 0.75
SHOP_Z1 = 6.1
SHOP_DEPTH = 0.7
SHOP_X = (-12.05, 12.05)  # escaparates a los lados, fuera de los machones
ATRIUM_W = 15.0  # atrio de cristal entre los dos machones
ATRIUM_Z0 = 7.3  # arranca sobre el portalón: es un atrio de tres plantas
SCREEN_Z1 = 21.25  # el cristal del atrio sigue sobre la cubierta
MAST_X = 8.2  # machones de caliza que enmarcan el atrio
MAST_W = 1.4
MAST_D = 2.1
MAST_TOP = 22.1
CROWN_Z = 22.7  # viga de coronación de cobre con el nombre de cubierta
CROWN_H = 1.2
PLATE_Z0 = 9.1  # placa del rótulo, encima de la puerta y del toldo
PLATE_Z1 = 12.35
PLATE_HALF = 7.5
BRIDGE_Z = 12.6  # puente de la galería: el pez se apoya en él, no flota
SIGN_SIZE = 1.7
BELT_Z = 9.675
FISH = (0.4, -7.9, 15.2)  # centro del pez: dentro del atrio, delante del cristal
FISH_SCALE = (4.6, 0.85, 2.1)
TOWER = (5.5, 4.6)  # torre del rótulo, en la mitad trasera derecha
TOWER_HALF = 3.1
ANNEX = (-8.0, 4.5)  # pabellón anexo de la galería, retranqueado
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
MAX_HEIGHT = 34.0
MAX_LEVEL0_HEIGHT = 23.5
FRONT_LIMIT = -10.0
LOT_HALF_WIDTH = 18.0

# Material de Roblox, sufijo de color y RGB de cada clave de material de Blender.
RBX = {
    "limestone": ("Limestone", "", "D2C9B4"),
    "glass": ("Glass", "", "2E4A63"),
    "metal_acero": ("Metal", "_acero", "A8AEB4"),
    "metal_oro": ("Metal", "_oro", "C9A227"),
    "metal_cobre": ("Metal", "_cobre", "C97B3A"),
    "metal_magenta": ("Metal", "_magenta", "E85D9E"),
    "fabric_rojo": ("Fabric", "_rojo", "C4382B"),
    "slate": ("Slate", "", "4A4E54"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "glass": flat("glass", "2E4A63", 0.3, 0.1),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.25, 0.8),
        "metal_oro": flat("metal_oro", "C9A227", 0.3, 0.9),
        "metal_cobre": flat("metal_cobre", "C97B3A", 0.35, 0.85),
        "metal_magenta": flat("metal_magenta", "E85D9E", 0.4, 0.6),
        "fabric_rojo": flat("fabric_rojo", "C4382B", 0.8),
        "slate": flat("slate", "4A4E54", 0.85),
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


def cone(name, radius, depth, location, mat, verts=4):
    """Pirámide de base regular, para el remate de cobre."""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def prism(name, points, y, thickness, mat):
    """Prisma de un polígono del plano XZ, extruido en Y: cola y aletas del pez."""
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    build = bmesh.new()
    front = [build.verts.new((x, y + thickness / 2, z)) for x, z in points]
    back = [build.verts.new((x, y - thickness / 2, z)) for x, z in points]
    build.faces.new(front)
    build.faces.new(list(reversed(back)))
    for index in range(len(points)):
        nxt = (index + 1) % len(points)
        build.faces.new((front[index], front[nxt], back[nxt], back[index]))
    bmesh.ops.recalc_face_normals(build, faces=build.faces)
    build.to_mesh(mesh)
    build.free()
    obj.data.materials.append(mat)
    return obj


def fish(parts, M):
    """Pez dorado del atrio: cuerpo facetado, cola de abanico, dorsal y pectoral. Es el emblema del centro."""
    cx, cy, cz = FISH
    mat = M["metal_oro"]
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(cx - 1.2, cy, cz))
    body = bpy.context.active_object
    body.name = "fish_body"
    body.data.materials.append(mat)
    body.scale = FISH_SCALE
    body.rotation_euler = (0.0, math.radians(6.0), 0.0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    parts.append(body)

    # Cola: abanico con muesca, con el vértice en el cuerpo y el borde ancho detrás.
    parts.append(
        prism(
            "fish_tail",
            [(cx + 2.6, cz + 0.1), (cx + 5.6, cz + 2.1), (cx + 4.7, cz), (cx + 5.6, cz - 2.1)],
            cy,
            0.32,
            mat,
        )
    )
    # Aleta dorsal, por encima del lomo.
    parts.append(prism("fish_dorsal", [(cx - 2.6, cz + 1.4), (cx - 0.9, cz + 3.2), (cx + 2.0, cz + 1.5)], cy, 0.3, mat))
    # Pectoral, en el costado que mira a la calle.
    parts.append(prism("fish_pectoral", [(cx - 1.1, cz + 0.2), (cx + 0.6, cz - 1.5), (cx + 1.5, cz + 0.2)], cy - 0.7, 0.22, mat))
    # Ojos de pizarra, uno por cara: es lo que remata la lectura de pez de cerca.
    for side in (-1, 1):
        eye = cylinder("fish_eye", 0.38, 0.16, (cx - 2.9, cy + side * 0.66, cz + 0.55), M["slate"], 8, True)
        eye.rotation_euler = (math.pi / 2, 0.0, 0.0)
        parts.append(eye)
    return parts


def build_body(M):
    """Nivel 0: gran almacén de caliza con atrio de cristal, pez de oro, escaparates, rótulo y cubierta."""
    parts = []

    # Muro con huecos de verdad: portalón, atrio de cristal y dos escaparates grandes.
    cutters = [
        box("cut_portal", (PORTAL_W, PORTAL_DEPTH, PORTAL_H), (0.0, FRONT + PORTAL_DEPTH / 2, PORTAL_H / 2)),
        box("cut_atrium", (ATRIUM_W, RECESS, BODY_H - ATRIUM_Z0), (0.0, FRONT + RECESS / 2, (ATRIUM_Z0 + BODY_H) / 2)),
    ]
    for x in SHOP_X:
        cutters.append(box("cut_shop", (SHOP_W, SHOP_DEPTH, SHOP_Z1 - SHOP_Z0), (x, FRONT + SHOP_DEPTH / 2, (SHOP_Z0 + SHOP_Z1) / 2)))
    wall = box("paez_wall", (WIDTH, DEPTH, BODY_H), (0.0, 0.0, BODY_H / 2), M["limestone"])
    perforate(wall, cutters)
    parts.append(wall)

    # Zócalo, pilastras de esquina, banda de caliza y machones que enmarcan el atrio de abajo arriba.
    for side in (-1, 1):
        parts.append(box("plinth", (11.85, DEPTH + 0.7, 0.6), (side * 10.425, 0.0, 0.3), M["limestone"]))
        parts.append(box("pilaster", (0.9, 0.6, BODY_H - 0.6), (side * 15.65, FRONT - 0.3, (BODY_H + 0.6) / 2), M["limestone"]))
        parts.append(box("belt", (7.2, 0.5, 0.35), (side * 12.5, FRONT - 0.25, BELT_Z), M["limestone"]))
        parts.append(box("machon", (MAST_W, MAST_D, MAST_TOP), (side * MAST_X, -8.65, MAST_TOP / 2), M["limestone"]))
        parts.append(box("cornice_front", (7.45, 0.7, CORNICE_TOP - BODY_H), (side * 12.45, FRONT, (BODY_H + CORNICE_TOP) / 2), M["limestone"]))
        parts.append(box("cornice_side", (0.7, 2 * (DEPTH / 2 - 0.35), CORNICE_TOP - BODY_H), (side * (WIDTH / 2 - 0.35 + 0.35), 0.0, (BODY_H + CORNICE_TOP) / 2), M["limestone"]))
    parts.append(box("cornice_back", (WIDTH + 0.7, 0.7, CORNICE_TOP - BODY_H), (0.0, DEPTH / 2 - 0.35 + 0.35, (BODY_H + CORNICE_TOP) / 2), M["limestone"]))

    # Escaparates: cristal al fondo del hueco y carpintería metálica fina.
    for x in SHOP_X:
        parts.append(box("shop_glass", (SHOP_W - 0.2, 0.14, SHOP_Z1 - SHOP_Z0 - 0.24), (x, FRONT + SHOP_DEPTH - 0.12, (SHOP_Z0 + SHOP_Z1) / 2), M["glass"]))
        parts.append(box("shop_head", (SHOP_W, 0.5, 0.26), (x, FRONT + 0.2, SHOP_Z1 - 0.13), M["metal_acero"]))
        parts.append(box("shop_sill", (SHOP_W, 0.5, 0.3), (x, FRONT + 0.2, SHOP_Z0 + 0.15), M["metal_acero"]))
        for dx in (-1.85, 1.85):
            parts.append(box("shop_mullion", (0.16, 0.42, SHOP_Z1 - SHOP_Z0), (x + dx, FRONT + 0.22, (SHOP_Z0 + SHOP_Z1) / 2), M["metal_acero"]))

    # Portalón: hueco de 9 × 7,4 con el vestíbulo de cristal al fondo. Es más alto que un avatar de 6.
    parts.append(box("door_glass", (4.3, 0.14, 6.9), (-2.2, FRONT + PORTAL_DEPTH - 0.1, 3.55), M["glass"]))
    parts.append(box("door_glass2", (4.3, 0.14, 6.9), (2.2, FRONT + PORTAL_DEPTH - 0.1, 3.55), M["glass"]))
    parts.append(box("door_transom", (8.7, 0.14, 1.5), (0.0, FRONT + PORTAL_DEPTH - 0.1, 6.65), M["glass"]))
    for x in (-4.4, 0.0, 4.4):
        parts.append(box("door_jamb", (0.22, 0.34, PORTAL_H), (x, FRONT + PORTAL_DEPTH - 0.17, PORTAL_H / 2), M["metal_acero"]))
    for z in (3.0, 5.8, PORTAL_H - 0.15):
        parts.append(box("door_rail", (PORTAL_W, 0.34, 0.24), (0.0, FRONT + PORTAL_DEPTH - 0.17, z), M["metal_acero"]))

    # Placa del rótulo: caliza entre los machones, encima de la puerta y del toldo, con letras de cobre.
    parts.append(box("sign_plate", (2 * PLATE_HALF, 0.55, PLATE_Z1 - PLATE_Z0), (0.0, FRONT - 0.275, (PLATE_Z0 + PLATE_Z1) / 2), M["limestone"]))
    parts.append(box("sign_trim", (2 * PLATE_HALF - 0.2, 0.16, 0.2), (0.0, FRONT - 0.6, PLATE_Z0 + 0.1), M["metal_cobre"]))
    name = letters("CENTRO PÁEZ", SIGN_SIZE, (0.0, FRONT - 0.6, (PLATE_Z0 + PLATE_Z1) / 2), M["metal_cobre"], depth=0.2)
    width = name.dimensions.x
    if width > 2 * PLATE_HALF - 1.2:
        select_only(name)
        factor = (2 * PLATE_HALF - 1.2) / width
        name.scale = (factor, factor, factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    parts.append(name)

    # Atrio: pantalla de cristal que sube del portalón a la linterna, con montantes de acero.
    panes_x = ((-7.22, -2.64), (-2.36, 2.36), (2.64, 7.22))
    rows_z = ((ATRIUM_Z0 + 0.15, 13.55), (13.9, SCREEN_Z1 - 0.15))
    for z0, z1 in rows_z:
        for x0, x1 in panes_x:
            parts.append(box("atrium_pane", (x1 - x0, 0.14, z1 - z0), ((x0 + x1) / 2, FRONT + RECESS - 0.07, (z0 + z1) / 2), M["glass"]))
    for x in (-7.36, -2.5, 2.5, 7.36):
        parts.append(box("atrium_post", (0.28, 0.26, SCREEN_Z1 - ATRIUM_Z0 - 0.15), (x, FRONT + RECESS - 0.1, (ATRIUM_Z0 + 0.15 + SCREEN_Z1) / 2), M["metal_acero"]))
    for z in (ATRIUM_Z0 + 0.15, 13.72, SCREEN_Z1 - 0.15):
        parts.append(box("atrium_rail", (ATRIUM_W, 0.26, 0.3), (0.0, FRONT + RECESS - 0.1, z), M["metal_acero"]))

    # Puente de la galería: banda de caliza que cruza el atrio; en él se apoya el pez.
    parts.append(box("gallery_bridge", (ATRIUM_W, 1.9, 0.5), (0.0, -7.95, BRIDGE_Z), M["limestone"]))
    # Pez dorado sobre su pedestal de caliza, dentro del atrio.
    parts.append(box("fish_pedestal", (2.9, 1.7, 0.8), (0.0, FISH[1], 13.15), M["limestone"]))
    fish(parts, M)

    # Linterna del atrio: el cristal sigue sobre la cubierta y remata en cornisa y cubierta planas.
    for side in (-1, 1):
        parts.append(box("lantern_side", (0.14, 6.07, SCREEN_Z1 - BODY_H), (side * 7.4, FRONT + RECESS + 3.03, (BODY_H + SCREEN_Z1) / 2), M["glass"]))
    parts.append(box("lantern_back", (ATRIUM_W - 0.2, 0.14, SCREEN_Z1 - BODY_H), (0.0, FRONT + RECESS + 6.0, (BODY_H + SCREEN_Z1) / 2), M["glass"]))
    parts.append(box("lantern_rail", (ATRIUM_W + 0.3, 0.24, 0.22), (0.0, FRONT + RECESS - 0.02, SCREEN_Z1 - 0.11), M["metal_acero"]))
    parts.append(box("lantern_copper", (ATRIUM_W + 0.7, 6.6, 0.35), (0.0, FRONT + RECESS + 3.1, SCREEN_Z1 + 0.175), M["metal_cobre"]))
    parts.append(box("lantern_roof", (ATRIUM_W + 0.2, 6.2, 0.18), (0.0, FRONT + RECESS + 3.1, SCREEN_Z1 + 0.44), M["glass"]))

    # Coronación: viga de cobre sobre los machones con el nombre del centro en letras de caliza.
    parts.append(box("crown_beam", (2 * MAST_X + MAST_W - 0.2, 0.5, CROWN_H), (0.0, -9.4, CROWN_Z), M["metal_cobre"]))
    roof_name = letters("CENTRO PÁEZ", 1.2, (0.0, -9.75, CROWN_Z), M["limestone"], depth=0.18)
    width = roof_name.dimensions.x
    if width > 2 * MAST_X - 1.4:
        select_only(roof_name)
        factor = (2 * MAST_X - 1.4) / width
        roof_name.scale = (factor, factor, factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    parts.append(roof_name)

    # Cubierta de pizarra alrededor de la linterna.
    inner_side = WIDTH / 2 - 0.35
    inner_back = DEPTH / 2 - 0.35
    deck_front = FRONT - 0.35 + 0.7
    lantern_front = FRONT + RECESS - 0.24
    lantern_back = FRONT + RECESS + 6.07
    parts.append(box("deck_front", (2 * inner_side, lantern_front - deck_front, 0.3), (0.0, (deck_front + lantern_front) / 2, ROOF_Z - 0.15), M["slate"]))
    parts.append(box("deck_back", (2 * inner_side, inner_back - lantern_back, 0.3), (0.0, (lantern_back + inner_back) / 2, ROOF_Z - 0.15), M["slate"]))
    for side in (-1, 1):
        parts.append(box("deck_side", (inner_side - 7.5, lantern_back - lantern_front, 0.3), (side * (7.5 + (inner_side - 7.5) / 2), (lantern_front + lantern_back) / 2, ROOF_Z - 0.15), M["slate"]))
    parts.append(box("roof_hatch", (2.2, 2.0, 0.9), (-13.0, 6.6, ROOF_Z + 0.42), M["metal_acero"]))
    parts.append(box("roof_duct", (3.4, 0.8, 0.8), (10.0, 7.2, ROOF_Z + 0.38), M["metal_acero"]))
    return parts


def build_marquee(M):
    """Nivel 1: marquesina sobre el portalón y toldos de lona roja sobre los escaparates."""
    parts = []
    parts.append(box("marquee", (10.6, 0.9, 0.3), (0.0, FRONT - 0.45, 8.9), M["metal_acero"]))
    parts.append(box("marquee_valance", (10.6, 0.14, 1.0), (0.0, FRONT - 0.83, 8.25), M["fabric_rojo"]))
    parts.append(box("marquee_trim", (10.6, 0.1, 0.16), (0.0, FRONT - 0.84, 7.83), M["metal_magenta"]))
    for x in (-4.9, 4.9):
        parts.append(box("marquee_arm", (0.16, 0.9, 0.16), (x, FRONT - 0.45, 8.6), M["metal_acero"]))
    angle = math.radians(17.0)
    for x in SHOP_X:
        awning = box("awning", (SHOP_W + 0.4, 0.95, 0.12), (x, FRONT - 0.45, 6.35), M["fabric_rojo"])
        awning.rotation_euler = (angle, 0.0, 0.0)
        parts.append(awning)
        parts.append(box("awning_rail", (SHOP_W + 0.5, 0.2, 0.16), (x, FRONT - 0.1, 6.55), M["metal_acero"]))
    return parts


def build_bands(M):
    """Nivel 2: bandas de ventanales en las plantas altas y vitrinas junto al portalón."""
    parts = []
    for side in (-1, 1):
        center = side * 12.3
        parts.append(box("band_glass", (5.8, 0.14, 2.6), (center, FRONT - 0.06, 14.75), M["glass"]))
        parts.append(box("band_head", (6.2, 0.45, 0.26), (center, FRONT - 0.28, 16.18), M["metal_acero"]))
        parts.append(box("band_sill", (6.2, 0.45, 0.26), (center, FRONT - 0.28, 13.32), M["metal_acero"]))
        for dx in (-2.8, 0.0, 2.8):
            parts.append(box("band_mullion", (0.16, 0.4, 2.6), (center + dx, FRONT - 0.24, 14.75), M["metal_acero"]))
    # Vitrinas de la galería, a los lados de la puerta.
    for side in (-1, 1):
        x = side * 6.0
        parts.append(box("vitrina_base", (2.4, 0.9, 1.0), (x, FRONT - 0.45, 0.5), M["limestone"]))
        parts.append(box("vitrina_glass", (2.2, 0.78, 2.9), (x, FRONT - 0.45, 2.45), M["glass"]))
        parts.append(box("vitrina_cap", (2.4, 0.9, 0.24), (x, FRONT - 0.45, 4.02), M["metal_acero"]))
    return parts


def build_terrace(M):
    """Nivel 3: terraza de la galería en la cubierta, con barandilla de acero sobre los flancos."""
    parts = []
    for side in (-1, 1):
        parts.append(box("terrace_coping", (6.6, 0.55, 0.3), (side * 12.3, FRONT + 0.4, ROOF_Z + 0.15), M["limestone"]))
        for x in (-3.0, -1.0, 1.0, 3.0):
            parts.append(box("terrace_post", (0.12, 0.12, 0.95), (side * 12.3 + x, FRONT + 0.62, ROOF_Z + 0.78), M["metal_acero"]))
        parts.append(box("terrace_rail", (6.6, 0.12, 0.12), (side * 12.3, FRONT + 0.62, ROOF_Z + 1.21), M["metal_acero"]))
    return parts


def build_annex(M):
    """Nivel 4: pabellón anexo de la galería, retranqueado en la cubierta, con banda de cristal."""
    parts = []
    parts.append(box("annex", (11.0, 6.0, 2.8), (ANNEX[0], ANNEX[1], ROOF_Z + 1.4), M["limestone"]))
    parts.append(box("annex_glass", (8.4, 0.12, 1.5), (ANNEX[0], ANNEX[1] - 3.02, ROOF_Z + 1.45), M["glass"]))
    parts.append(box("annex_head", (8.8, 0.45, 0.24), (ANNEX[0], ANNEX[1] - 2.95, ROOF_Z + 2.27), M["metal_acero"]))
    parts.append(box("annex_sill", (8.8, 0.45, 0.24), (ANNEX[0], ANNEX[1] - 2.95, ROOF_Z + 0.63), M["metal_acero"]))
    parts.append(box("annex_roof", (11.6, 6.6, 0.28), (ANNEX[0], ANNEX[1], ROOF_Z + 2.94), M["metal_cobre"]))
    return parts


def build_crown(M):
    """Nivel 5: torre del rótulo con las letras en vertical y remate de cobre."""
    parts = []
    parts.append(box("tower_base", (2 * TOWER_HALF + 0.7, 2 * TOWER_HALF + 0.7, 0.4), (TOWER[0], TOWER[1], ROOF_Z + 0.2), M["metal_cobre"]))
    parts.append(box("tower", (2 * TOWER_HALF, 2 * TOWER_HALF, 11.9), (TOWER[0], TOWER[1], ROOF_Z + 5.95), M["limestone"]))
    parts.append(box("tower_mid", (2 * TOWER_HALF + 0.5, 2 * TOWER_HALF + 0.5, 0.3), (TOWER[0], TOWER[1], ROOF_Z + 7.2), M["metal_cobre"]))
    parts.append(box("tower_band", (2 * TOWER_HALF + 0.6, 2 * TOWER_HALF + 0.6, 0.55), (TOWER[0], TOWER[1], ROOF_Z + 12.18), M["metal_cobre"]))
    crown = cone("tower_crown", 4.5, 2.0, (TOWER[0], TOWER[1], ROOF_Z + 13.45), M["metal_cobre"])
    crown.rotation_euler = (0.0, 0.0, math.radians(45.0))
    parts.append(crown)
    parts.append(cylinder("tower_needle", 0.16, 0.66, (TOWER[0], TOWER[1], ROOF_Z + 14.78), M["metal_cobre"], 8, True))
    # Rótulo vertical sobre la cara que da a la calle: letras de caliza sobre panel de cobre.
    parts.append(box("tower_blade", (2.6, 0.35, 6.6), (TOWER[0], TOWER[1] - TOWER_HALF - 0.14, ROOF_Z + 7.9), M["metal_cobre"]))
    for index, character in enumerate("PÁEZ"):
        parts.append(letters(character, 1.75, (TOWER[0], TOWER[1] - TOWER_HALF - 0.36, ROOF_Z + 10.05 - index * 1.55), M["limestone"], depth=0.16))
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
        name = f"paez_{layer}_{rbx.lower()}{suffix}"
        if len(members) == 1:
            # Un solo objeto: unir consigo mismo avisa «No mesh data to join». Ya está en el origen.
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
        "fondo_maximo": round(max(ys), 2),
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

    # Ficha de referencia (caja oscura 8 × 4 × 5) y avatar de 6 de alto para la escala.
    box("ficha_ref", (8.0, 4.0, 5.0), (-2.5 * SPACING, SLOT_SIDE, 2.5), M["dark"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-2.5 * SPACING + 3.6, building_y + FRONT - 1.4, 3.0), M["avatar"])
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
    # Las FBX de una corrida anterior no deben quedarse: se subirían por error.
    for name in os.listdir(OUT):
        if name.startswith("paez_") and name.endswith(".fbx"):
            os.remove(os.path.join(OUT, name))
    render_dir = os.path.join(REPO, "art", "render", *RENDER_SUBDIR.split("/"))
    os.makedirs(render_dir, exist_ok=True)

    M = make_materials()
    pieces = []

    # Nivel 0: cuerpo. Niveles 1 a 5: añadidos que se suman sin sustituir nada.
    group(0, build_body(M), pieces)
    builders = {1: build_marquee, 2: build_bands, 3: build_terrace, 4: build_annex, 5: build_crown}
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
    lod = lod_of(objects, "paez_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "paez_LOD1.fbx")

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
    print("PAEZ_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

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
        if max(abs(limits["ancho"] / 2), abs(limits["fondo_maximo"])) > LOT_HALF_WIDTH:
            raise RuntimeError(f"Nivel {level}: se sale del solar")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "centro-paez.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["metal_acero"], "gold": M["metal_oro"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -190.0, 78.0), (0.0, 22.0, 10.0), 30), f"{RENDER_SUBDIR}/centro-paez-niveles.png")

    # Comparación: nivel 0 frente a un bloque de Bodega (13) y otro de Cine Lux (24), con la figura de 6
    # delante de la fachada y al lado de la puerta, que es lo que permite revisar la puerta.
    hide_all()
    box("ground", (360, 400, 0.4), (2.0, 100.0, -0.2), M["pavement"])
    place(cumulative_objects[0], -34.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (2.0, 0.0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (38.0, 0.0, 12.0), M["block"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-27.6, -10.2, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (2.0, -100.0, 6.5), (2.0, 0.0, 11.0), 30), f"{RENDER_SUBDIR}/centro-paez-comparacion.png")
    print("PAEZ_DONE")


if __name__ == "__main__":
    main()

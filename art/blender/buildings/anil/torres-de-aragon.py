"""Torres de Aragón: propiedad de la zona Añil (Mirador Añil), modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de 23 (la torre alta; la baja queda en 16,4) y cinco añadidos que se suman:
acceso y plaza, jardín y pérgola común, balcones y bandas blancas, pabellón de servicios y torre del depósito.
El par de torres azules con bandas y recercados blancos, unidas por la plaza-jardín, es el rasgo del edificio.
Sigue el método de barberia-morro.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/anil/:
  torres-de-aragon.blend                              escena de revisión (no se versiona)
  torres-de-aragon/aragon_<pieza>_<material>.fbx y aragon_LOD1.fbx
  torres-de-aragon/stats.json                         triángulos por pieza y nivel, límites y materiales
Y en art/render/anil/torres-de-aragon/: torres-de-aragon-niveles.png y torres-de-aragon-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/anil/torres-de-aragon.py
"""

import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "torres-de-aragon")
RENDER_SUBDIR = "anil/torres-de-aragon"
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
TOWER_W = 12.0
TOWER_D = 14.0
TOWER_CY = -2.0
TOWER_BACK = TOWER_CY + TOWER_D / 2  # 5,0
A_X = -10.0  # torre alta
B_X = 10.0  # torre baja
SLOT_W = 8.0  # plaza-jardín entre las dos torres
WALL_A = 22.6  # muro de la torre alta; la cornisa lo lleva a 23,0
WALL_B = 16.0  # muro de la torre baja; la cornisa la lleva a 16,4
BODY_H = 23.0
DOOR_W = 3.2
DOOR_H = 7.4  # más alta que el avatar (6)
SIGN_Z = 10.6
PLAZA_PAVE = 9.0  # fondo de la plaza pavimentada, de y -9 a 0
GARDEN_D = 5.0  # de y 0 a 5
TRIANGLE_BUDGET = 3000
MAX_HEIGHT = 44.0
LEVEL0_MAX = 28.0
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

# Material de Roblox, sufijo de color y RGB de cada material de Blender.
RBX = {
    "limestone": ("Limestone", "", "D2C9B4"),
    "plastic_azul": ("SmoothPlastic", "_azul", "1F5FA8"),
    "glass": ("Glass", "", "2E4A63"),
    "slate": ("Slate", "", "4A4E54"),
    "metal_acero": ("Metal", "_acero", "A8AEB4"),
    "metal_cobre": ("Metal", "_cobre", "C97B3A"),
    "wood": ("Wood", "", "6B4A2E"),
    "grass": ("Grass", "", "4B6B3A"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "plastic_azul": flat("plastic_azul", "1F5FA8", 0.35),
        "glass": flat("glass", "2E4A63", 0.35, 0.25),
        "slate": flat("slate", "4A4E54", 0.85),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.4, 0.9),
        "metal_cobre": flat("metal_cobre", "C97B3A", 0.3, 0.9),
        "wood": flat("wood", "6B4A2E", 0.7),
        "grass": flat("grass", "4B6B3A", 0.9),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "4F46E5", 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "6E747C", 0.8),
    }


def cylinder(name, radius, depth, location, mat, verts, caps):
    """Cilindro vertical. Sin tapas para los anillos del depósito."""
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
    """Cono de remate."""
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=location
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def build_body(M):
    """Nivel 0: dos torres azules con bandas y recercados blancos, plaza, jardín, rótulo y cubiertas."""
    parts = []

    # Torre alta: portal alto, ventana de planta baja, dos bandas de ventanales y el hueco del rótulo.
    cuts_a = [
        box("door_cut", (DOOR_W, 1.6, DOOR_H + 0.6), (A_X, FRONT + 0.6, (DOOR_H - 0.6) / 2)),
        box("win_cut", (3.0, 1.5, 4.0), (A_X - 3.6, FRONT + 0.55, 3.6)),
        box("strip_cut", (7.6, 1.5, 2.4), (A_X, FRONT + 0.55, 14.9)),
        box("strip_cut", (7.6, 1.5, 2.4), (A_X, FRONT + 0.55, 19.7)),
    ]
    wall_a = box("tower_a", (TOWER_W, TOWER_D, WALL_A), (A_X, TOWER_CY, WALL_A / 2), M["plastic_azul"])
    perforate(wall_a, cuts_a)
    parts.append(wall_a)

    # Torre baja: acceso retranqueado a la plaza y dos bandas de ventanales.
    cuts_b = [
        box("recess_cut", (4.2, 1.4, 7.0), (B_X, FRONT + 0.5, 3.45)),
        box("strip_cut", (7.6, 1.5, 2.4), (B_X, FRONT + 0.55, 10.2)),
        box("strip_cut", (7.6, 1.5, 2.2), (B_X, FRONT + 0.55, 14.2)),
    ]
    wall_b = box("tower_b", (TOWER_W, TOWER_D, WALL_B), (B_X, TOWER_CY, WALL_B / 2), M["plastic_azul"])
    perforate(wall_b, cuts_b)
    parts.append(wall_b)

    # Zócalos de caliza, abiertos en los dos accesos.
    plinth_a = box("plinth_a", (TOWER_W + 0.5, TOWER_D + 0.5, 0.5), (A_X, TOWER_CY, 0.25), M["limestone"])
    perforate(plinth_a, [box("door_cut_p", (DOOR_W + 0.2, 2.0, 0.7), (A_X, FRONT + 0.4, 0.35))])
    parts.append(plinth_a)
    plinth_b = box("plinth_b", (TOWER_W + 0.5, TOWER_D + 0.5, 0.5), (B_X, TOWER_CY, 0.25), M["limestone"])
    perforate(plinth_b, [box("recess_cut_p", (4.4, 2.0, 0.7), (B_X, FRONT + 0.4, 0.35))])
    parts.append(plinth_b)

    # Bandas blancas: la fachada se lee por ellas, no por ventanitas.
    for z in (7.8, 12.6, 17.4):
        parts.append(box("band_a", (TOWER_W + 0.3, TOWER_D + 0.3, 0.4), (A_X, TOWER_CY, z), M["limestone"]))
    for z in (7.8, 12.6):
        parts.append(box("band_b", (TOWER_W + 0.3, TOWER_D + 0.3, 0.4), (B_X, TOWER_CY, z), M["limestone"]))

    # Recercados blancos en las esquinas, cornisa-parapeto y cubierta plana de pizarra.
    # La pilastra va 0,03 por dentro del zócalo y arranca dentro de él: si comparte plano con otra
    # pieza, Cycles deja un hueco negro en la esquina (caras coplanares).
    for x, wall_h in ((A_X, WALL_A), (B_X, WALL_B)):
        for sx in (-1, 1):
            for sy in (-1, 1):
                parts.append(
                    box(
                        "pilaster",
                        (0.9, 0.9, wall_h - 0.4),
                        (x + sx * 5.77, TOWER_CY + sy * 6.77, 0.4 + (wall_h - 0.4) / 2),
                        M["limestone"],
                    )
                )
        zc = wall_h + 0.2
        parts.append(box("parapet", (TOWER_W + 0.3, 0.4, 0.4), (x, FRONT + 0.2, zc), M["limestone"]))
        parts.append(box("parapet", (TOWER_W + 0.3, 0.4, 0.4), (x, TOWER_BACK - 0.2, zc), M["limestone"]))
        parts.append(box("parapet", (0.4, TOWER_D - 0.4, 0.4), (x - TOWER_W / 2 + 0.2, TOWER_CY, zc), M["limestone"]))
        parts.append(box("parapet", (0.4, TOWER_D - 0.4, 0.4), (x + TOWER_W / 2 - 0.2, TOWER_CY, zc), M["limestone"]))
        parts.append(box("roof_deck", (TOWER_W - 0.6, TOWER_D - 0.6, 0.25), (x, TOWER_CY, wall_h + 0.125), M["slate"]))

    # Jardineras de cubierta: la ficha las pide y así la cubierta no es una losa lisa.
    for x, wall_h in ((A_X, WALL_A), (B_X, WALL_B)):
        base = wall_h + 0.25
        parts.append(box("roof_planter", (1.2, 2.6, 0.8), (x + 2.4, 1.4, base + 0.4), M["limestone"]))
        parts.append(box("roof_hedge", (0.9, 2.2, 0.5), (x + 2.4, 1.4, base + 1.05), M["grass"]))

    # Portal alto con vidrio, ventana de planta baja a la izquierda y sus marcos de caliza.
    parts.append(box("door_glass", (2.9, 0.12, 7.2), (A_X, -8.70, 3.7), M["glass"]))
    for sx in (-1, 1):
        parts.append(box("door_jamb", (0.22, 0.5, 7.4), (A_X + sx * 1.49, -8.75, 3.7), M["limestone"]))
    parts.append(box("door_head", (3.2, 0.5, 0.3), (A_X, -8.75, 7.25), M["limestone"]))
    parts.append(box("door_sill", (3.2, 0.8, 0.12), (A_X, -8.70, 0.06), M["limestone"]))
    for wx in (A_X - 3.6,):
        parts.append(box("win_glass", (2.5, 0.12, 3.9), (wx, -8.70, 3.6), M["glass"]))
        parts.append(box("win_sill", (3.0, 0.5, 0.28), (wx, -8.72, 1.55), M["limestone"]))
        parts.append(box("win_head", (3.0, 0.4, 0.25), (wx, -8.75, 5.72), M["limestone"]))

    # Ventanales en banda de la torre alta, con parteluces blancos que rompen el paño de vidrio.
    for z in (14.9, 19.7):
        parts.append(box("strip_glass", (7.2, 0.12, 2.1), (A_X, -8.70, z), M["glass"]))
        parts.append(box("strip_sill", (8.0, 0.5, 0.26), (A_X, -8.72, z - 1.28), M["limestone"]))
        for sx in (-1, 1):
            parts.append(box("mullion", (0.16, 0.18, 2.4), (A_X + sx * 1.25, -8.80, z), M["limestone"]))

    # Acceso retranqueado de la torre baja.
    parts.append(box("b_door_glass", (3.4, 0.12, 6.6), (B_X, -8.30, 3.30), M["glass"]))
    for sx in (-1, 1):
        parts.append(box("b_door_jamb", (0.24, 0.5, 6.8), (B_X + sx * 1.75, -8.40, 3.40), M["limestone"]))
    parts.append(box("b_door_head", (3.8, 0.5, 0.3), (B_X, -8.40, 6.90), M["limestone"]))
    for z, h in ((10.2, 2.1), (14.2, 1.9)):
        parts.append(box("b_strip_glass", (7.2, 0.12, h), (B_X, -8.70, z), M["glass"]))
        parts.append(box("b_strip_sill", (8.0, 0.5, 0.26), (B_X, -8.72, z - h / 2 - 0.08), M["limestone"]))
        for sx in (-1, 1):
            parts.append(box("mullion", (0.16, 0.18, h + 0.2), (B_X + sx * 1.25, -8.80, z), M["limestone"]))

    # Rótulo en placa de pizarra, con el nombre en letras de caliza por encima del portal y del toldo.
    parts.append(box("sign_plate", (10.4, 0.35, 3.5), (A_X, -9.05, SIGN_Z), M["slate"]))
    parts.append(letters("TORRES DE", 1.7, (A_X, -9.30, SIGN_Z + 0.90), M["limestone"], depth=0.2))
    parts.append(letters("ARAGÓN", 1.7, (A_X, -9.30, SIGN_Z - 0.75), M["limestone"], depth=0.2))

    # Plaza pavimentada, jardín y muro de fondo con verja: el par queda unido por el jardín.
    parts.append(box("plaza_pave", (SLOT_W, PLAZA_PAVE, 0.12), (0, -PLAZA_PAVE / 2, 0.06), M["limestone"]))
    parts.append(box("plaza_grass", (SLOT_W, GARDEN_D, 0.12), (0, GARDEN_D / 2, 0.06), M["grass"]))
    for y in (-7.2, -4.5, -1.8):
        parts.append(box("pave_strip", (SLOT_W, 0.5, 0.06), (0, y, 0.15), M["slate"]))
    parts.append(box("garden_curb", (SLOT_W, 0.3, 0.25), (0, 0.0, 0.125), M["limestone"]))
    rear_wall = box("rear_wall", (SLOT_W, 0.5, 2.4), (0, TOWER_BACK + 0.25, 1.2), M["limestone"])
    perforate(rear_wall, [box("gate_cut", (2.2, 1.0, 1.9), (0, TOWER_BACK + 0.25, 0.95))])
    parts.append(rear_wall)

    # Fuente de la plaza común: es lo que hace leer el hueco entre las torres como plaza y no como callejón.
    parts.append(cylinder("fountain_basin", 1.9, 0.7, (0, -2.6, 0.35), M["limestone"], 12, True))
    parts.append(cylinder("fountain_water", 1.65, 0.1, (0, -2.6, 0.74), M["glass"], 12, True))
    parts.append(cylinder("fountain_jet", 0.14, 0.9, (0, -2.6, 1.15), M["metal_cobre"], 8, True))

    # Dos jardineras a la entrada de la plaza, también de caliza y hierba.
    for sx in (-1, 1):
        parts.append(box("plaza_planter", (1.4, 1.4, 0.9), (sx * 3.1, -8.1, 0.45), M["limestone"]))
        parts.append(box("plaza_hedge", (1.1, 1.1, 0.6), (sx * 3.1, -8.1, 1.2), M["grass"]))
    return parts


def build_access(M):
    """Nivel 1: acceso y plaza. Pórtico de caliza sobre el portal, fuente, bancos y faroles."""
    parts = []
    for sx in (-1, 1):
        parts.append(box("portico_pier", (0.9, 1.0, 8.8), (A_X + sx * 2.25, -9.5, 4.4), M["limestone"]))
        parts.append(box("portico_plinth", (1.1, 1.0, 0.6), (A_X + sx * 2.25, -9.5, 0.3), M["limestone"]))
    parts.append(box("portico_lintel", (5.4, 1.0, 0.7), (A_X, -9.5, 8.45), M["limestone"]))

    # Dos bancos de madera, apoyados en el suelo de la plaza, y dos faroles de acero con farol de cristal.
    for sx in (-1, 1):
        parts.append(box("bench_seat", (0.85, 3.0, 0.18), (sx * 2.9, -4.8, 0.21), M["wood"]))
        parts.append(box("bench_back", (0.16, 3.0, 0.65), (sx * 3.25, -4.8, 0.625), M["wood"]))
        parts.append(box("lamp_post", (0.18, 0.18, 4.6), (sx * 3.3, -6.9, 2.3), M["metal_acero"]))
        parts.append(box("lamp_head", (0.5, 0.5, 0.45), (sx * 3.3, -6.9, 4.75), M["glass"]))
    return parts


def build_garden(M):
    """Nivel 2: jardín y pérgola común entre las torres, con dos árboles y parterres."""
    parts = []
    for sx in (-1, 1):
        for y in (1.6, 4.0):
            parts.append(box("pergola_post", (0.35, 0.35, 5.6), (sx * 3.2, y, 2.8), M["wood"]))
        parts.append(box("pergola_beam", (0.35, 3.4, 0.5), (sx * 3.2, 2.8, 5.85), M["wood"]))
    for y in (1.4, 2.1, 2.8, 3.5, 4.2):
        parts.append(box("pergola_slat", (7.4, 0.4, 0.16), (0, y, 6.18), M["wood"]))

    # Parterres con los dos árboles del jardín.
    for sx in (-1, 1):
        parts.append(box("garden_bed", (2.8, 1.2, 0.35), (sx * 2.6, 0.75, 0.175), M["grass"]))
        parts.append(box("tree_trunk", (0.4, 0.4, 2.4), (sx * 2.4, 0.9, 1.2), M["wood"]))
        parts.append(cone("tree_crown", 1.3, 3.0, (sx * 2.4, 0.9, 3.9), M["grass"], 8))
    return parts


def build_facade(M):
    """Nivel 3: balcones y bandas blancas. Recercados en los ventanales y balcones con barandilla."""
    parts = []
    strips = ((A_X, 14.9, 2.4), (A_X, 19.7, 2.4), (B_X, 10.2, 2.4), (B_X, 14.2, 2.2))
    for x, z, h in strips:
        z0 = z - h / 2
        parts.append(box("balcony_slab", (8.2, 1.0, 0.25), (x, -9.5, z0 - 0.12), M["limestone"]))
        parts.append(box("balcony_rail", (8.2, 0.12, 0.85), (x, -9.94, z0 + 0.43), M["metal_acero"]))
        for sx in (-1, 1):
            parts.append(box("strip_jamb", (0.4, 0.3, h + 0.3), (x + sx * 3.95, -9.12, z), M["limestone"]))
    return parts


def build_pavilion(M):
    """Nivel 4: pabellón de servicios retranqueado, cerrando el jardín por el fondo."""
    parts = []
    pavilion = box("pavilion", (9.5, 3.3, 9.0), (0, 7.15, 4.5), M["plastic_azul"])
    perforate(
        pavilion,
        [
            box("pav_door_cut", (1.6, 1.2, 2.8), (0, 5.9, 1.4)),
            box("pav_win_cut", (1.8, 1.2, 1.8), (-2.9, 5.9, 5.4)),
            box("pav_win_cut", (1.8, 1.2, 1.8), (2.9, 5.9, 5.4)),
        ],
    )
    parts.append(pavilion)
    parts.append(box("pav_cornice", (9.9, 3.7, 0.4), (0, 7.15, 9.0), M["limestone"]))
    parts.append(box("pav_roof", (9.6, 3.4, 0.2), (0, 7.15, 9.3), M["slate"]))
    parts.append(box("pav_door_glass", (1.3, 0.12, 2.6), (0, 5.75, 1.30), M["glass"]))
    for sx in (-1, 1):
        parts.append(box("pav_win_glass", (1.5, 0.12, 1.5), (sx * 2.9, 5.75, 5.4), M["glass"]))
    return parts


def build_watertower(M):
    """Nivel 5: torre del depósito sobre la torre alta, con remate de cobre."""
    parts = []
    cx, cy = A_X, TOWER_CY
    legs = ((-12.0, -3.8), (-8.0, -3.8), (-8.0, -0.2), (-12.0, -0.2))
    for x, y in legs:
        parts.append(box("deposit_leg", (0.4, 0.4, 5.4), (x, y, 25.5), M["metal_acero"]))
    for z in (26.2,):
        parts.append(box("deposit_ring", (4.0, 0.25, 0.25), (cx, -3.8, z), M["metal_acero"]))
        parts.append(box("deposit_ring", (4.0, 0.25, 0.25), (cx, -0.2, z), M["metal_acero"]))
        parts.append(box("deposit_ring", (0.25, 3.6, 0.25), (-12.0, cy, z), M["metal_acero"]))
        parts.append(box("deposit_ring", (0.25, 3.6, 0.25), (-8.0, cy, z), M["metal_acero"]))
    parts.append(cylinder("deposit_tank", 2.7, 5.4, (cx, cy, 30.9), M["plastic_azul"], 12, True))
    parts.append(cylinder("deposit_band", 2.78, 0.3, (cx, cy, 29.4), M["limestone"], 12, True))
    parts.append(cylinder("deposit_band", 2.78, 0.3, (cx, cy, 32.4), M["limestone"], 12, True))
    parts.append(cone("deposit_roof", 2.95, 2.6, (cx, cy, 34.9), M["metal_cobre"], 12))
    parts.append(cylinder("deposit_finial", 0.16, 1.6, (cx, cy, 36.8), M["metal_cobre"], 8, True))
    return parts


def merge(members, name):
    """Une un grupo en una sola malla, con las transformaciones aplicadas y el origen en el centro de la base."""
    for member in members:
        select_only(member)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(members) > 1:
        return join(members, name)
    mesh = members[0]
    mesh.name = name
    origin_at_zero(mesh)
    return mesh


def group(level, parts, store):
    """Une las piezas de un nivel en una malla por material y color. En Roblox cada malla lleva un material."""
    layer = "body" if level == 0 else f"addon{level}"
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in sorted(by_material.items()):
        rbx, suffix, rgb = RBX[key]
        name = f"aragon_{layer}_{rbx.lower()}{suffix}"
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

    # Figura de 6 delante de la fachada y junto al portal, para leer la puerta desde la calle.
    box("avatar_ref", (1.6, 1.2, 6.0), (-2.5 * SPACING - 7.2, lot_y - 9.0, 3.0), M["avatar"])
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
    builders = {1: build_access, 2: build_garden, 3: build_facade, 4: build_pavilion, 5: build_watertower}
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
    lod = lod_of(objects, "aragon_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "aragon_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "cuerpo_alto": BODY_H,
        "altura_maxima_permitida": MAX_HEIGHT,
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
    print("TORRES_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if levels["0"]["limites"]["alto_maximo_sobre_suelo"] > LEVEL0_MAX:
        raise RuntimeError(f"El nivel 0 llega a {levels['0']['limites']['alto_maximo_sobre_suelo']}, más de {LEVEL0_MAX}")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] > MAX_HEIGHT:
        raise RuntimeError(f"El nivel 5 llega a {levels['5']['limites']['alto_maximo_sobre_suelo']}, más de {MAX_HEIGHT}")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "torres-de-aragon.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["limestone"], "steel": M["metal_acero"], "gold": M["metal_cobre"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -190.0, 78.0), (0.0, 22.0, 10.0), 30), f"{RENDER_SUBDIR}/torres-de-aragon-niveles.png")

    # Comparación: nivel 0 en el centro, con la figura de 6 delante de la fachada y junto al portal,
    # entre el bloque de la Bodega (13) y el del Cine Lux (24). Así se juzga la puerta de un vistazo.
    hide_all()
    box("ground", (180, 40, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], 0.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (-34.0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (34.0, 0, 12.0), M["block"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-7.2, -10.2, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -120.0, 22.0), (0.0, 0.0, 10.0), 36), f"{RENDER_SUBDIR}/torres-de-aragon-comparacion.png")
    print("TORRES_DONE")


if __name__ == "__main__":
    main()

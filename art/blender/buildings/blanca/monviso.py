"""Monviso: propiedad de la zona Blanca (Cumbre Blanca), modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de 24 (las seis torres) y cinco añadidos que se suman: acceso y plaza,
jardines y caminos, pabellón común, terrazas y balcones y torre del depósito con remate de cobre.
El edificio es el conjunto: seis torres iguales de fachadas grises, blancas y amarillas en dos filas paralelas
de tres, sobre una plaza común que abre a la calle. La retícula 3 + 3 es el rasgo y se lee de arriba abajo.
Sigue el método de barberia-morro.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/blanca/:
  monviso.blend                      escena de revisión (no se versiona)
  monviso/monviso_<pieza>_<material>.fbx y monviso_LOD1.fbx
  monviso/stats.json                 triángulos por pieza y nivel, límites y materiales
Y en art/render/blanca/monviso/: monviso-niveles.png y monviso-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/blanca/monviso.py
"""

import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "monviso")
RENDER_SUBDIR = "blanca/monviso"
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
TOWER_W = 8.0  # las seis torres son iguales: la retícula 3 + 3 se lee en planta
TOWER_H = 24.0  # cuerpo: masa principal, las seis torres
TOWER_X = (-11.2, 0.0, 11.2)
APRON = (-9.0, -7.4)  # franja de acceso por delante de las torres
ROW_FRONT = (-7.4, -1.6)  # fila delantera
PLAZA = (-1.6, 2.8)  # plaza común entre las dos filas
ROW_BACK = (2.8, 8.6)  # fila trasera
BAND_Z = (9.8, 16.6)  # bandas blancas del espinazo de fachada
CROWN_Z = 22.7  # banda amarilla de coronación
CORNICE_Z = 23.88  # cornisa de caliza sobre la coronación
DECK_Z = 24.26  # cubierta de pizarra
PENTHOUSE_H = 2.2  # caseta de cubierta: rompe la línea plana de las torres
STRIP_W = 1.3  # franja vertical de vidrio de la fachada
STRIP_X = 2.95
SPINE_W = 4.4  # espinazo central: las bandas no cortan las franjas de vidrio
POCKET = 1.25  # fondo de los huecos: se ve el canto de la pared, no una calcomanía
GLASS_INSET = 0.5  # el vidrio va cerca de la cara: la luz le da y no lee como un agujero negro
DOOR_W = 3.6
DOOR_H = 7.4  # portalón claramente más alto que la figura de 6
PORTAL_DEPTH = 1.8
DOOR_INSET = 0.55  # el vidrio del portalón va cerca de la cara, dentro del hueco
SIGN_Z = 10.2  # centro de la placa, por encima del portalón y del toldo
SIGN_W = 7.6
SIGN_H = 3.2
CANOPY_Z = 8.0  # toldo del añadido 1, entre el dintel y la placa
PLAZA_D = PLAZA[1] - PLAZA[0]
PLAZA_CY = (PLAZA[0] + PLAZA[1]) / 2
APRON_D = APRON[1] - APRON[0]
APRON_CY = (APRON[0] + APRON[1]) / 2
TRIANGLE_BUDGET = 3000
LEVEL0_MAX = 29.0  # el nivel 0 completo no pasa de 29: la calle mantiene su altura
MAX_HEIGHT = 46.0  # el nivel 5 llega justo al máximo
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
# El gris, el blanco y el amarillo son acabados pintados (SmoothPlastic), no materiales nuevos.
RBX = {
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "plastic_gris": ("SmoothPlastic", "_gris", "A0A8B0"),
    "plastic_blanco": ("SmoothPlastic", "_blanco", "F7F5F0"),
    "plastic_amarillo": ("SmoothPlastic", "_amarillo", "C9A227"),
    "metal_acero": ("Metal", "_acero", "A8AEB4"),
    "metal_hueso": ("Metal", "_hueso", "EDE5D3"),
    "metal_cobre": ("Metal", "_cobre", "C97B3A"),
    "metal_oro": ("Metal", "_oro", "C9A227"),
    "wood": ("Wood", "", "6B4A2E"),
    "grass": ("Grass", "", "4B6B3A"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.35, 0.25),
        "plastic_gris": flat("plastic_gris", "A0A8B0", 0.45),
        "plastic_blanco": flat("plastic_blanco", "F7F5F0", 0.45),
        "plastic_amarillo": flat("plastic_amarillo", "C9A227", 0.45),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.4, 0.9),
        "metal_hueso": flat("metal_hueso", "EDE5D3", 0.35, 0.6),
        "metal_cobre": flat("metal_cobre", "C97B3A", 0.3, 0.9),
        "metal_oro": flat("metal_oro", "C9A227", 0.3, 0.9),
        "wood": flat("wood", "6B4A2E", 0.7),
        "grass": flat("grass", "4B6B3A", 0.9),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "DED4BB", 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "4C525A", 0.8),
    }


def cylinder(name, radius, depth, location, mat, verts, caps):
    """Cilindro vertical. Sin tapas cuando el anillo queda oculto dentro de otra pieza."""
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
    """Cono de remate, con la punta hacia arriba."""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
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


def windows(M, cx, y0, y1, z0, z1, parts):
    """Huecos de verdad en el fuste: franjas verticales continuas en la fachada, los costados y el patio."""
    cuts = []
    mid = (z0 + z1) / 2
    height = z1 - z0
    # Fachada: dos franjas verticales; el vidrio queda dentro del hueco, cerca de la cara.
    for sx in (-1, 1):
        cuts.append(box("strip_cut", (STRIP_W, POCKET + 0.1, height), (cx + sx * STRIP_X, y0 - 0.05 + (POCKET + 0.1) / 2, mid)))
        parts.append(
            box(
                "strip_glass",
                (STRIP_W + 0.3, 0.12, height + 0.3),
                (cx + sx * STRIP_X, y0 + GLASS_INSET, mid),
                M["glass"],
            )
        )
    # Costados: una franja en cada uno.
    for sx in (-1, 1):
        parts.append(
            box(
                "side_glass",
                (0.12, 1.7, 16.3),
                (cx + sx * (TOWER_W / 2 - GLASS_INSET), (y0 + y1) / 2, 11.4),
                M["glass"],
            )
        )
        cuts.append(
            box(
                "side_cut",
                (POCKET + 0.1, 1.4, 16.0),
                (cx + sx * (TOWER_W / 2 + 0.05 - (POCKET + 0.1) / 2), (y0 + y1) / 2, 11.4),
            )
        )
    # Patio: el hueco que mira a la plaza común.
    cuts.append(box("back_cut", (1.4, POCKET + 0.1, 16.0), (cx, y1 + 0.05 - (POCKET + 0.1) / 2, 11.4)))
    parts.append(box("back_glass", (1.7, 0.12, 16.3), (cx, y1 - GLASS_INSET, 11.4), M["glass"]))
    return cuts


def tower(M, cx, row, index, access=False, penthouse=True):
    """Una torre: fuste perforado, zócalo, bandas del espinazo, coronación, cubierta, caseta y vidrio."""
    y0, y1 = row
    cy = (y0 + y1) / 2
    depth = y1 - y0
    parts = []

    z0, z1 = (12.0, 20.4) if access else (2.6, 20.4)
    cuts = windows(M, cx, y0, y1, z0, z1, parts)
    if access:
        cuts.append(
            box(
                "door_cut",
                (DOOR_W, PORTAL_DEPTH + 0.4, DOOR_H + 0.2),
                (cx, y0 - 0.2 + (PORTAL_DEPTH + 0.4) / 2, DOOR_H / 2 - 0.1),
            )
        )
    shaft = box("tower", (TOWER_W, depth, TOWER_H), (cx, cy, TOWER_H / 2), M["plastic_gris"])
    perforate(shaft, cuts)
    parts.append(shaft)

    # Zócalo de caliza; abierto en el portalón de la torre de acceso.
    plinth = box("plinth", (TOWER_W + 0.3, depth + 0.3, 0.8), (cx, cy, 0.4), M["limestone"])
    if access:
        perforate(
            plinth,
            [box("door_cut_p", (DOOR_W + 0.2, PORTAL_DEPTH + 0.7, 1.2), (cx, y0 - 0.1 + (PORTAL_DEPTH + 0.7) / 2, 0.45))],
        )
    parts.append(plinth)

    # Bandas blancas sobre el espinazo central, entre las dos franjas de vidrio, y banda amarilla de coronación.
    for z in BAND_Z:
        parts.append(box("band", (SPINE_W, depth + 0.24, 0.8), (cx, cy, z), M["plastic_blanco"]))
    parts.append(box("crown", (TOWER_W + 0.3, depth + 0.3, 1.28), (cx, cy, CROWN_Z + 0.64), M["plastic_amarillo"]))

    # Cornisa de caliza, cubierta de pizarra y caseta: la torre no remata en una caja lisa.
    parts.append(box("cornice", (TOWER_W + 0.5, depth + 0.5, 0.34), (cx, cy, CORNICE_Z), M["limestone"]))
    parts.append(box("deck", (TOWER_W - 0.4, depth - 0.4, 0.2), (cx, cy, DECK_Z), M["slate"]))
    if penthouse:
        side = -1.7 if index % 2 == 0 else 1.7
        parts.append(
            box(
                "penthouse",
                (2.6, 2.4, PENTHOUSE_H),
                (cx + side, cy + 0.7, DECK_Z + PENTHOUSE_H / 2 - 0.05),
                M["limestone"],
            )
        )
    return parts


def portal(M):
    """Portalón de la torre de acceso y placa con el nombre: lo que se ve desde la calle."""
    parts = []
    y0 = ROW_FRONT[0]
    parts.append(box("portal_jamb", (0.36, 0.6, DOOR_H + 0.4), (-(DOOR_W / 2 + 0.18), y0 - 0.1, (DOOR_H + 0.4) / 2), M["limestone"]))
    parts.append(box("portal_jamb", (0.36, 0.6, DOOR_H + 0.4), (DOOR_W / 2 + 0.18, y0 - 0.1, (DOOR_H + 0.4) / 2), M["limestone"]))
    parts.append(box("portal_head", (DOOR_W + 1.1, 0.6, 0.42), (0, y0 - 0.1, DOOR_H + 0.2), M["limestone"]))
    parts.append(box("portal_step", (DOOR_W + 0.9, 1.0, 0.2), (0, y0 - 0.45, 0.1), M["limestone"]))
    parts.append(
        box("door_glass", (DOOR_W - 0.1, 0.12, DOOR_H - 0.1), (0, y0 + DOOR_INSET, (DOOR_H - 0.1) / 2), M["glass"])
    )

    # Placa de pizarra con filete de hueso y letras de caliza, como el cartel del Cine Lux.
    parts.append(box("sign_back", (SIGN_W + 0.3, 0.12, SIGN_H + 0.3), (0, y0 - 0.06, SIGN_Z), M["metal_hueso"]))
    parts.append(box("sign_plate", (SIGN_W, 0.34, SIGN_H), (0, y0 - 0.19, SIGN_Z), M["slate"]))
    name = letters("MONVISO", 1.8, (0, y0 - 0.33, SIGN_Z), M["limestone"], depth=0.18)
    parts.append(fit_width(name, SIGN_W - 0.5))
    return parts


def build_body(M):
    """Nivel 0: seis torres en dos filas de tres, plaza común, andén de acceso y portalón con la placa."""
    parts = []
    parts += tower(M, TOWER_X[0], ROW_FRONT, 0, penthouse=False)
    parts += tower(M, TOWER_X[1], ROW_FRONT, 1, access=True)
    parts += tower(M, TOWER_X[2], ROW_FRONT, 2)
    for index, cx in enumerate(TOWER_X):
        parts += tower(M, cx, ROW_BACK, index, penthouse=index != 1)

    # Andén de caliza por delante de las torres y suelo de la plaza común.
    parts.append(box("apron", (WIDTH, APRON_D, 0.12), (0, APRON_CY, 0.06), M["limestone"]))
    parts.append(box("plaza", (WIDTH, PLAZA_D, 0.14), (0, PLAZA_CY, 0.07), M["limestone"]))
    for x in (-8.0, 8.0):
        parts.append(box("plaza_joint", (0.5, PLAZA_D - 0.2, 0.06), (x, PLAZA_CY, 0.14), M["slate"]))
    parts += portal(M)
    return parts


def build_access(M):
    """Nivel 1: acceso y plaza. Toldo sobre el portalón, bancos, faroles y jardineras en la plaza."""
    parts = []
    y0 = ROW_FRONT[0]
    parts.append(box("canopy", (6.0, 0.85, 0.22), (0, y0 - 0.425, CANOPY_Z), M["limestone"]))
    parts.append(box("canopy_glass", (5.6, 0.7, 0.08), (0, y0 - 0.4, CANOPY_Z - 0.14), M["glass"]))
    parts.append(box("canopy_edge", (6.1, 0.12, 0.3), (0, y0 - 0.79, CANOPY_Z), M["metal_hueso"]))
    for sx in (-1, 1):
        parts.append(box("bracket", (0.16, 0.8, 0.5), (sx * 2.5, y0 - 0.45, CANOPY_Z - 0.42), M["metal_acero"]))

    # Bancos de madera, faroles de acero y jardineras en la plaza común.
    for sx in (-1, 1):
        parts.append(box("bench_seat", (2.4, 0.9, 0.2), (sx * 6.0, PLAZA_CY, 0.42), M["wood"]))
        parts.append(box("bench_back", (2.4, 0.16, 0.7), (sx * 6.0, PLAZA_CY - 0.35, 0.87), M["wood"]))
        parts.append(box("lamp_post", (0.18, 0.18, 4.2), (sx * 3.1, PLAZA_CY - 1.5, 2.1), M["metal_acero"]))
        parts.append(box("lamp_head", (0.5, 0.5, 0.45), (sx * 3.1, PLAZA_CY - 1.5, 4.35), M["glass"]))
        parts.append(box("planter", (0.9, 0.9, 0.7), (sx * 4.6, PLAZA_CY + 1.0, 0.35), M["limestone"]))
        parts.append(box("planter_hedge", (0.75, 0.75, 0.5), (sx * 4.6, PLAZA_CY + 1.0, 0.55), M["grass"]))
    return parts


def build_garden(M):
    """Nivel 2: jardines y caminos. Parterres en el andén y en la plaza, árboles y losas de pizarra."""
    parts = []
    # Jardín de acceso, a los dos lados del portalón: es el añadido que se ve desde la calle.
    for cx in (-8.0, 8.0):
        parts.append(box("apron_bed", (7.6, 1.3, 0.26), (cx, APRON_CY, 0.25), M["grass"]))
    parts.append(box("apron_path", (2.6, 0.6, 0.08), (0, APRON[0] + 0.3, 0.16), M["slate"]))
    for x in (-10.6, -5.4, 5.4, 10.6):
        parts.append(box("tree_trunk", (0.4, 0.4, 2.1), (x, APRON_CY, 1.32), M["wood"]))
        parts.append(cone("tree_crown", 1.3, 3.2, (x, APRON_CY + 0.2, 3.9), M["grass"], 8))

    # Jardines de la plaza común, entre las dos filas de torres.
    for cx in (-11.0, 11.0):
        parts.append(box("garden_bed", (6.4, 3.6, 0.3), (cx, PLAZA_CY, 0.28), M["grass"]))
        for sy in (-1, 1):
            parts.append(box("garden_curb", (6.6, 0.4, 0.34), (cx, PLAZA_CY + sy * 1.9, 0.3), M["limestone"]))
        parts.append(box("tree_trunk", (0.4, 0.4, 2.1), (cx, PLAZA_CY, 1.35), M["wood"]))
        parts.append(cone("tree_crown", 1.7, 3.6, (cx, PLAZA_CY, 4.2), M["grass"], 8))
    for x in (-7.4, 7.4):
        parts.append(box("path", (0.9, PLAZA_D - 0.3, 0.07), (x, PLAZA_CY, 0.15), M["slate"]))
    return parts


def build_pavilion(M):
    """Nivel 3: pabellón común sobre la cubierta de la torre delantera izquierda, con terraza."""
    parts = []
    cx, cy = TOWER_X[0], (ROW_FRONT[0] + ROW_FRONT[1]) / 2
    parts.append(box("pavilion_base", (6.3, 4.5, 0.3), (cx, cy, 24.45), M["limestone"]))
    walls = box("pavilion", (6.0, 4.2, 5.6), (cx, cy, 27.4), M["plastic_blanco"])
    perforate(
        walls,
        [
            box("pavilion_cut", (4.6, 1.1, 2.9), (cx, cy - 2.1 + 0.45, 27.5)),
            box("pavilion_cut", (1.1, 3.0, 2.9), (cx - 3.0 + 0.45, cy, 27.5)),
        ],
    )
    parts.append(walls)
    parts.append(box("pavilion_glass", (4.8, 0.12, 3.0), (cx, cy - 1.2, 27.5), M["glass"]))
    parts.append(box("pavilion_glass", (0.12, 3.2, 3.0), (cx - 2.1, cy, 27.5), M["glass"]))
    parts.append(box("pavilion_roof", (6.6, 4.8, 0.28), (cx, cy, 30.34), M["slate"]))
    parts.append(box("terrace_rail", (6.6, 0.12, 0.9), (cx, cy - 2.6, 25.05), M["metal_acero"]))
    parts.append(box("terrace_rail", (0.12, 4.8, 0.9), (cx - 3.3, cy, 25.05), M["metal_acero"]))
    return parts


def build_terraces(M):
    """Nivel 4: terrazas y balcones. Losas de caliza con antepecho de pizarra y barandilla de acero."""
    parts = []
    for index, cx in enumerate(TOWER_X):
        zs = (13.4, 18.6) if index == 1 else (12.4, 18.4)
        for z in zs:
            parts.append(box("balcony_slab", (4.4, 1.3, 0.3), (cx, ROW_FRONT[0] - 0.65, z), M["limestone"]))
            parts.append(box("balcony_rail", (4.4, 0.2, 0.85), (cx, ROW_FRONT[0] - 1.19, z + 0.57), M["slate"]))
        # Terraza interior, sobre la plaza, en la fila trasera.
        parts.append(box("terrace_slab", (4.4, 1.3, 0.3), (cx, ROW_BACK[0] - 0.65, 12.6), M["limestone"]))
        parts.append(box("terrace_rail", (4.4, 0.2, 0.85), (cx, ROW_BACK[0] - 1.19, 13.17), M["slate"]))
    return parts


def build_depot(M):
    """Nivel 5: torre del depósito sobre la torre central trasera, con remate de cobre."""
    parts = []
    cx, cy = 0.0, (ROW_BACK[0] + ROW_BACK[1]) / 2
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box("depot_leg", (0.35, 0.35, 9.9), (cx + sx * 1.7, cy + sy * 1.7, 29.25), M["metal_acero"]))
    for z in (28.6,):
        for sy in (-1, 1):
            parts.append(box("depot_ring", (4.0, 0.3, 0.3), (cx, cy + sy * 1.7, z), M["metal_acero"]))
        for sx in (-1, 1):
            parts.append(box("depot_ring", (0.3, 3.7, 0.3), (cx + sx * 1.7, cy, z), M["metal_acero"]))
    parts.append(cylinder("depot_tank", 3.0, 6.0, (cx, cy, 37.0), M["metal_acero"], 12, True))
    parts.append(cone("depot_cap", 3.15, 4.2, (cx, cy, 42.1), M["metal_cobre"], 12))
    parts.append(cylinder("depot_finial", 0.16, 1.8, (cx, cy, 45.1), M["metal_oro"], 8, True))
    return parts


def merge(members, name):
    """Une un grupo en una sola malla, con las transformaciones aplicadas y el origen en la base."""
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
        name = f"monviso_{layer}_{rbx.lower()}{suffix}"
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
    sun_data.energy = 3.9
    sun_data.angle = math.radians(1.0)
    sun = bpy.data.objects.new("sun", sun_data)
    bpy.context.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(90 - 34.0), 0, math.radians(-38))
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.68, 0.78, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.72
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

    # Figura de 6 junto al portalón, para leer la puerta desde la calle.
    box("avatar_ref", (1.6, 1.2, 6.0), (-2.5 * SPACING - 4.6, lot_y - 8.6, 3.0), M["avatar"])
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
    builders = {1: build_access, 2: build_garden, 3: build_pavilion, 4: build_terraces, 5: build_depot}
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
    lod = lod_of(objects, "monviso_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "monviso_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "cuerpo_alto": TOWER_H,
        "altura_maxima_permitida": MAX_HEIGHT,
        "nivel_0_maximo": LEVEL0_MAX,
        "torres": {"filas": 2, "por_fila": 3, "ancho": TOWER_W, "alto": TOWER_H},
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
    print("MONVISO_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "monviso.blend"))

    markers = {
        kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["metal_acero"], "gold": M["metal_oro"]})
        for kind in ("house", "hotel", "tower")
    }
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -192.0, 92.0), (0.0, 20.0, 9.0), 28), f"{RENDER_SUBDIR}/monviso-niveles.png")

    # Comparación: nivel 0 en el centro, la figura de 6 delante de la fachada junto al portalón,
    # entre el bloque de la Bodega (13) y el del Cine Lux (24). Así se juzga la puerta de un vistazo.
    hide_all()
    box("ground", (190, 44, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], 0.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (-33.0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (33.0, 0, 12.0), M["block"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-3.75, -9.3, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -108.0, 28.0), (0.0, -2.0, 9.0), 34), f"{RENDER_SUBDIR}/monviso-comparacion.png")
    print("MONVISO_DONE")


if __name__ == "__main__":
    main()


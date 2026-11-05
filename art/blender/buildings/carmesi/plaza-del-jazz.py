"""Plaza del Jazz: sala de jazz y baile de la zona Carmesí, modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de 18 con cornisa de caliza y cubierta de pizarra, y cinco añadidos que se
suman: marquesina de lona, escaparate de madera, cartel de la trompeta en la cubierta, pabellón de camerinos
retranqueado y torre del cartel con remate de cobre. La marquesina y la trompeta son el rasgo: nada de neón ni
casino. Sigue el método de barberia-morro.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/carmesi/:
  plaza-del-jazz.blend                       escena de revisión (no se versiona)
  plaza-del-jazz/jazz_<capa>_<material>.fbx y jazz_LOD1.fbx
  plaza-del-jazz/stats.json                  triángulos por pieza y nivel, límites y materiales
Y en art/render/carmesi/plaza-del-jazz/: plaza-del-jazz-niveles.png y plaza-del-jazz-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/carmesi/plaza-del-jazz.py
"""

import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "plaza-del-jazz")
RENDER_SUBDIR = "carmesi/plaza-del-jazz"
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
BODY_H = 18.0
PLINTH_H = 0.55

# Frente acristalado: hueco de verdad en el ladrillo, con el cristal al fondo del retranqueo.
SHOP_HALF = 13.0  # media anchura del frente acristalado
SHOP_TOP = 7.85
SHOP_DEPTH = 1.5  # del plano de fachada al fondo del retranqueo
SHOP_BACK = FRONT + SHOP_DEPTH  # -7,5: el ladrillo empieza aquí
GLASS_Y = SHOP_BACK - 0.06  # el cristal queda a paño con el fondo del retranqueo

DOOR_W = 3.8  # puerta doble, muy por encima del avatar de 6
DOOR_TOP = 7.5
DOOR_Y = -7.9

# Ventanas en arco de la planta de oficinas: tres grandes, no una hilera de ventanitas.
WIN_X = (-7.2, 0.0, 7.2)
WIN_W = 3.2
WIN_Z0 = 12.95
WIN_Z1 = 15.4  # arranque del arco
WIN_R = 1.6  # radio del arco: hasta 17,0

SIDE_WIN_Y = -3.5

# Cornisa y cubierta.
CORNICE_Z0 = 17.55
CORNICE_Z1 = 18.35
ROOF_Z = 18.45

# Marquesina del nivel 0 sobre la puerta.
MARQ_W = 9.6
MARQ_Z0 = 8.0
MARQ_Z1 = 9.05
MARQ_Y_FRONT = -9.82

# Placa con el nombre, por encima de la puerta y de la marquesina.
PLATE_Z = 10.5
PLATE_W = 17.5
PLATE_H = 2.2
LETTER_SIZE = 1.9

# Balcón de la planta alta, delante de los arcos.
BALC_W = 16.0

# Trompeta de chapa: enseña del club. Una pequeña en la cubierta desde el nivel 0 y la grande en el 3.
TRUMPET_L3 = (-1.0, -6.0)
TRUMPET_L3_Z = 24.3
TRUMPET_L3_SCALE = 1.25
TRUMPET_L0 = (12.3, -7.2)
TRUMPET_L0_Z = 20.8
TRUMPET_L0_SCALE = 0.8
TRUMPET_EMBLEM_SCALE = 0.3

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
MAX_HEIGHT = 34.0
MAX_LEVEL0 = 23.0
CINE_LUX_L5_TRIANGLES = 3042
AVATAR = (1.6, 1.2, 6.0)

# Material de Roblox, sufijo de color y RGB de cada clave de material de Blender.
RBX = {
    "brick": ("Brick", "", "B0664A"),
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "wood": ("Wood", "", "6B4A2E"),
    "metal": ("Metal", "", "C97B3A"),
    "metal_acero": ("Metal", "_acero", "A8AEB4"),
    "fabric_rojo": ("Fabric", "_rojo", "C4382B"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "wood": flat("wood", "6B4A2E", 0.7),
        "metal": flat("metal", "C97B3A", 0.3, 0.9),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.4, 0.9),
        "fabric_rojo": flat("fabric_rojo", "C4382B", 0.8),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "DC2626", 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "D5D0C6", 0.8),
    }


def cylinder(name, radius, depth, location, mat, verts=10, caps=True, rotation=(0.0, 0.0, 0.0)):
    """Cilindro (o disco) con su material. Se usa para el arco, las trompetas y el remate."""
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


def cone(name, radius1, radius2, depth, location, mat, verts=12, rotation=(0.0, 0.0, 0.0)):
    """Tronco de cono: pabellón de la trompeta y remate de cobre de la torre."""
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts,
        radius1=radius1,
        radius2=radius2,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    if mat is not None:
        obj.data.materials.append(mat)
    return obj


def rotated(obj, degrees_xyz):
    obj.rotation_euler = tuple(math.radians(value) for value in degrees_xyz)
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


def trumpet(name, location, scale, tilt, mat):
    """Trompeta de chapa plana: tubo, pabellón, pistones y bomba. Mira a la calle, en el plano XZ."""
    design = []
    design.append(cylinder(f"{name}_tube", 0.26, 4.2, (0.0, 0.0, 0.0), mat, 8, True, (0.0, math.pi / 2, 0.0)))
    design.append(
        cone(f"{name}_bell", 0.26, 1.35, 1.6, (2.9, 0.0, 0.0), mat, 10, (0.0, math.pi / 2, 0.0))
    )
    design.append(cylinder(f"{name}_mouth", 0.13, 0.5, (-2.35, 0.0, 0.0), mat, 8, True, (0.0, math.pi / 2, 0.0)))
    for index, x in enumerate((0.4, 0.9, 1.4)):
        design.append(box(f"{name}_valve{index}", (0.16, 0.5, 0.8), (x, 0.0, 0.45), mat))
    design.append(box(f"{name}_slide_a", (0.16, 0.5, 0.9), (1.7, 0.0, -0.45), mat))
    design.append(box(f"{name}_slide_b", (0.16, 0.5, 0.9), (2.5, 0.0, -0.45), mat))
    design.append(box(f"{name}_slide_c", (0.95, 0.5, 0.16), (2.1, 0.0, -0.9), mat))
    # Los giros de cada pieza se aplican antes de unir: si no, la unión hereda el giro del tubo.
    for part in design:
        select_only(part)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    piece = join(design, name)
    piece.scale = (scale, scale * 0.3, scale)
    piece.rotation_euler = (0.0, math.radians(-tilt), 0.0)
    piece.location = location
    select_only(piece)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return piece


def build_body(M):
    """Nivel 0: sala de ladrillo con frente acristalado, puerta alta, marquesina, placa, balcón y trompeta."""
    parts = []

    # Muro de ladrillo con huecos de verdad: el frente acristalado, tres arcos y una ventana por costado.
    wall = box("jazz_wall", (WIDTH, DEPTH, BODY_H), (0, 0, BODY_H / 2), M["brick"])
    cuts = [
        box(
            "cut_shop",
            (SHOP_HALF * 2, SHOP_DEPTH, SHOP_TOP - PLINTH_H),
            (0, FRONT + SHOP_DEPTH / 2, (PLINTH_H + SHOP_TOP) / 2),
        )
    ]
    for x in WIN_X:
        cuts.append(box("cut_win", (WIN_W, SHOP_DEPTH, WIN_Z1 - WIN_Z0), (x, FRONT + SHOP_DEPTH / 2, (WIN_Z0 + WIN_Z1) / 2)))
        cuts.append(
            cylinder("cut_arch", WIN_R, SHOP_DEPTH, (x, FRONT + SHOP_DEPTH / 2, WIN_Z1), None, 12, True, (math.pi / 2, 0, 0))
        )
    for side in (-1, 1):
        xc = side * (WIDTH / 2 - SHOP_DEPTH / 2)
        cuts.append(box("cut_side", (SHOP_DEPTH, WIN_W, WIN_Z1 - WIN_Z0), (xc, SIDE_WIN_Y, (WIN_Z0 + WIN_Z1) / 2)))
        cuts.append(
            cylinder("cut_side_arch", WIN_R, SHOP_DEPTH, (xc, SIDE_WIN_Y, WIN_Z1), None, 12, True, (0, math.pi / 2, 0))
        )
    perforate(wall, cuts)
    parts.append(wall)

    # Zócalo de caliza corrido, con el escalón de entrada delante de la puerta.
    parts.append(box("plinth", (WIDTH + 1.0, DEPTH + 1.0, PLINTH_H), (0, 0, PLINTH_H / 2), M["limestone"]))
    parts.append(box("entry_step", (DOOR_W + 0.8, 0.4, 0.2), (0, FRONT - 0.68, 0.1), M["limestone"]))

    # Cornisa de caliza en dos bandas y filete de cobre: el remate que comparte con el Cine Lux.
    parts.append(box("cornice_a", (WIDTH + 0.6, DEPTH + 0.6, 0.5), (0, 0, CORNICE_Z0 + 0.25), M["limestone"]))
    parts.append(box("cornice_b", (WIDTH + 1.2, DEPTH + 1.2, 0.3), (0, 0, CORNICE_Z0 + 0.65), M["limestone"]))
    parts.append(box("cornice_copper", (WIDTH + 1.4, DEPTH + 1.4, 0.12), (0, 0, CORNICE_Z1 + 0.06), M["metal"]))
    parts.append(box("roof", (WIDTH - 0.6, DEPTH - 0.6, 0.22), (0, 0, ROOF_Z - 0.11), M["slate"]))

    # Pilastras de caliza en las esquinas del frente.
    for side in (-1, 1):
        parts.append(box("pilaster", (1.0, 0.55, 17.0), (side * 15.5, FRONT - 0.2, 8.85), M["limestone"]))

    # Frente acristalado: dos paños grandes a los lados de la puerta, con jambas de caliza.
    for x0, x1 in ((-SHOP_HALF + 0.05, -2.05), (2.05, SHOP_HALF - 0.05)):
        parts.append(
            box("shop_glass", (x1 - x0, 0.12, SHOP_TOP - PLINTH_H), ((x0 + x1) / 2, GLASS_Y, (PLINTH_H + SHOP_TOP) / 2), M["glass"])
        )
    for side in (-1, 1):
        parts.append(
            box("door_jamb", (0.35, 0.5, SHOP_TOP - PLINTH_H), (side * 1.925, -7.75, (PLINTH_H + SHOP_TOP) / 2), M["limestone"])
        )
    # Dintel de caliza sobre todo el frente y jambas exteriores: enmarcan el escaparate.
    parts.append(box("shop_lintel", (SHOP_HALF * 2 + 0.7, 0.5, 0.5), (0, FRONT + 0.25, SHOP_TOP + 0.25), M["limestone"]))
    for side in (-1, 1):
        parts.append(box("shop_jamb", (0.5, 0.5, SHOP_TOP + 0.5 - PLINTH_H), (side * (SHOP_HALF + 0.1), FRONT + 0.25, (PLINTH_H + SHOP_TOP + 0.5) / 2), M["limestone"]))

    # Puerta doble de madera, con cristaleras y montante central. Mide 6,95: más que el avatar.
    for side in (-1, 1):
        parts.append(
            box("door_leaf", (1.7, 0.12, DOOR_TOP - PLINTH_H), (side * 0.9, DOOR_Y, (PLINTH_H + DOOR_TOP) / 2), M["wood"])
        )
        parts.append(
            box("door_lite", (1.06, 0.06, 4.3), (side * 0.9, DOOR_Y - 0.09, 5.05), M["glass"])
        )
    parts.append(box("door_mullion", (0.16, 0.2, DOOR_TOP - PLINTH_H), (0, DOOR_Y - 0.02, (PLINTH_H + DOOR_TOP) / 2), M["wood"]))
    parts.append(box("door_transom", (DOOR_W + 0.2, 0.24, 0.35), (0, DOOR_Y, (DOOR_TOP + SHOP_TOP) / 2), M["wood"]))

    # Ventanas en arco: cristal al fondo del retranqueo, parteluz y travesaño de acero, y antepecho de caliza.
    for x in WIN_X:
        zc = (WIN_Z0 + WIN_Z1) / 2
        parts.append(box("win_glass", (WIN_W - 0.1, 0.12, WIN_Z1 - WIN_Z0), (x, GLASS_Y, zc), M["glass"]))
        parts.append(cylinder("win_glass_arch", WIN_R - 0.05, 0.12, (x, GLASS_Y, WIN_Z1), M["glass"], 12, True, (math.pi / 2, 0, 0)))
        parts.append(box("win_mullion", (0.09, 0.16, WIN_Z1 - WIN_Z0), (x, GLASS_Y - 0.12, zc), M["metal_acero"]))
        parts.append(box("win_transom", (WIN_W - 0.1, 0.16, 0.09), (x, GLASS_Y - 0.12, WIN_Z1 - 0.05), M["metal_acero"]))

    # Ventanas de los costados: un arco por lado, con antepecho.
    for side in (-1, 1):
        xc = side * (WIDTH / 2 - SHOP_DEPTH)
        zc = (WIN_Z0 + WIN_Z1) / 2
        parts.append(box("side_glass", (0.12, WIN_W - 0.1, WIN_Z1 - WIN_Z0), (xc + side * 0.06, SIDE_WIN_Y, zc), M["glass"]))
        parts.append(
            cylinder("side_glass_arch", WIN_R - 0.05, 0.12, (xc + side * 0.06, SIDE_WIN_Y, WIN_Z1), M["glass"], 12, True, (0, math.pi / 2, 0))
        )
        parts.append(box("side_sill", (0.55, WIN_W + 0.6, 0.25), (side * (WIDTH / 2 - 0.1), SIDE_WIN_Y, WIN_Z0 - 0.12), M["limestone"]))

    # Balcón de la planta alta: losa de caliza con barandilla de cobre, delante de los arcos.
    parts.append(box("balc_slab", (BALC_W, 0.86, 0.3), (0, FRONT - 0.43, 12.35), M["limestone"]))
    parts.append(box("balc_rail", (BALC_W + 0.2, 0.16, 0.12), (0, FRONT - 0.74, 13.36), M["metal"]))
    for index in range(12):
        x = -BALC_W / 2 + 0.7 + index * (BALC_W - 1.4) / 11
        parts.append(box("baluster", (0.07, 0.07, 0.8), (x, FRONT - 0.74, 12.9), M["metal"]))
    for side in (-1, 1):
        parts.append(box("balc_post", (0.16, 0.16, 0.86), (side * (BALC_W / 2 + 0.06), FRONT - 0.74, 12.93), M["metal"]))

    # Placa de caliza con PLAZA DEL JAZZ en letras de cobre, por encima de la puerta y la marquesina.
    parts.append(box("plate", (PLATE_W, 0.4, PLATE_H), (0, FRONT - 0.2, PLATE_Z), M["limestone"]))
    parts.append(fit_width(letters("PLAZA DEL JAZZ", LETTER_SIZE, (0, FRONT - 0.42, PLATE_Z), M["metal"], depth=0.22), PLATE_W - 1.4))

    # Marquesina de la entrada: losa de acero, faldón de madera y la trompeta de cobre en el faldón.
    parts.append(box("marq_deck", (MARQ_W, 0.88, 0.22), (0, -9.37, MARQ_Z1 + 0.11), M["metal_acero"]))
    parts.append(box("marq_fascia", (MARQ_W, 0.16, MARQ_Z1 - MARQ_Z0), (0, -9.71, (MARQ_Z0 + MARQ_Z1) / 2), M["wood"]))
    for side in (-1, 1):
        parts.append(box("marq_corbel", (0.26, 0.7, 0.34), (side * 3.9, -9.35, MARQ_Z0 - 0.17), M["metal_acero"]))
    parts.append(trumpet("jazz_emblem", (0, -9.76, (MARQ_Z0 + MARQ_Z1) / 2), TRUMPET_EMBLEM_SCALE, 0.0, M["metal"]))

    # Trompeta de la cubierta: la enseña del club ya en el nivel 0, en el ángulo derecho.
    parts.append(box("vane_base", (0.8, 0.8, 0.28), (TRUMPET_L0[0], TRUMPET_L0[1], ROOF_Z + 0.14), M["metal_acero"]))
    parts.append(box("vane_post", (0.26, 0.26, 2.07), (TRUMPET_L0[0], TRUMPET_L0[1], ROOF_Z + 0.28 + 1.035), M["metal_acero"]))
    parts.append(trumpet("jazz_vane", (TRUMPET_L0[0], TRUMPET_L0[1], TRUMPET_L0_Z), TRUMPET_L0_SCALE, 14.0, M["metal"]))

    # Caja de escalera en la cubierta: no deja la azotea vacía y remata la silueta por detrás.
    parts.append(box("stair_house", (3.0, 3.2, 3.0), (1.5, 6.0, ROOF_Z + 1.5), M["brick"]))
    parts.append(box("stair_cap", (3.4, 3.6, 0.26), (1.5, 6.0, ROOF_Z + 3.13), M["limestone"]))
    parts.append(box("stair_door", (1.0, 0.14, 2.0), (1.5, 4.33, ROOF_Z + 1.0), M["wood"]))
    return parts


def build_marquee(M):
    """Nivel 1: marquesina de lona roja sobre los escaparates, con canal y tirantes de acero."""
    parts = []
    run, drop = 0.85, 0.42
    length = math.hypot(run, drop)
    angle = math.degrees(math.atan2(drop, run))
    for side in (-1, 1):
        xc = side * 9.2
        awning = box("awning", (8.6, length, 0.12), (xc, -9.45, 7.79), M["fabric_rojo"])
        rotated(awning, (angle, 0.0, 0.0))
        parts.append(awning)
        parts.append(box("valance", (8.6, 0.12, 0.3), (xc, -9.82, 7.4), M["fabric_rojo"]))
        parts.append(box("rail", (8.7, 0.16, 0.1), (xc, -9.82, 7.59), M["metal"]))
        for u in (-3.4, 3.4):
            rod = box("rod", (0.08, 1.79, 0.08), (xc + u, -9.45, 8.42), M["metal_acero"])
            rotated(rod, (60.0, 0.0, 0.0))
            parts.append(rod)
    return parts


def build_shopfront(M):
    """Nivel 2: escaparate de madera y puertas mejoradas. Montes de madera, zócalo, travesaño y herrajes."""
    parts = []
    for side in (-1, 1):
        xc = side * 7.475
        parts.append(box("shop_base", (10.85, 0.2, 0.95), (xc, -7.66, PLINTH_H + 0.475), M["wood"]))
        parts.append(box("shop_transom", (10.85, 0.28, 0.3), (xc, -7.66, 5.85), M["wood"]))
        parts.append(box("shop_post", (0.4, 0.3, SHOP_TOP - PLINTH_H), (side * 7.5, -7.66, (PLINTH_H + SHOP_TOP) / 2), M["wood"]))
        parts.append(box("door_trim", (0.4, 0.3, DOOR_TOP + 0.3 - PLINTH_H), (side * 2.22, -7.9, (PLINTH_H + DOOR_TOP + 0.3) / 2), M["wood"]))
        parts.append(box("kick_plate", (1.5, 0.1, 0.7), (side * 0.9, DOOR_Y - 0.11, PLINTH_H + 0.45), M["metal"]))
        parts.append(box("handle", (0.1, 0.1, 1.3), (side * 0.3, DOOR_Y - 0.11, 3.45), M["metal"]))
    return parts


def build_trumpet_sign(M):
    """Nivel 3: cartel de la trompeta en la cubierta, sobre un mástil de acero con su riostra."""
    parts = []
    x, y = TRUMPET_L3
    parts.append(box("mast_base", (1.0, 1.0, 0.3), (x, y, ROOF_Z + 0.15), M["metal_acero"]))
    parts.append(box("mast", (0.34, 0.34, TRUMPET_L3_Z - 0.3 - ROOF_Z), (x, y, (ROOF_Z + 0.3 + TRUMPET_L3_Z - 0.3) / 2), M["metal_acero"]))
    brace = box("mast_brace", (0.16, 0.16, 3.05), (x + 0.8, y, ROOF_Z + 1.3), M["metal_acero"])
    rotated(brace, (0.0, -31.6, 0.0))
    parts.append(brace)
    parts.append(trumpet("jazz_trumpet", (x, y, TRUMPET_L3_Z), TRUMPET_L3_SCALE, 14.0, M["metal"]))
    return parts


def build_annex(M):
    """Nivel 4: pabellón de camerinos retranqueado en la cubierta, con claraboyas y cubierta de cobre."""
    parts = []
    parts.append(box("annex", (12.0, 6.5, 5.6), (-9.2, 4.4, ROOF_Z + 2.8), M["brick"]))
    parts.append(box("annex_cornice", (12.5, 7.0, 0.3), (-9.2, 4.4, ROOF_Z + 5.75), M["limestone"]))
    parts.append(box("annex_roof", (12.7, 7.2, 0.22), (-9.2, 4.4, ROOF_Z + 6.01), M["metal"]))
    for x in (-12.2, -6.2):
        parts.append(cylinder("annex_light", 0.55, 0.3, (x, 1.05, ROOF_Z + 2.9), M["glass"], 10, True, (math.pi / 2, 0, 0)))
        parts.append(cylinder("annex_ring", 0.72, 0.12, (x, 0.94, ROOF_Z + 2.9), M["metal"], 10, True, (math.pi / 2, 0, 0)))
    return parts


def build_crown(M):
    """Nivel 5: torre del cartel con remate de cobre; el pabellón de la trompeta en grande."""
    parts = []
    x, y = 7.2, 3.6
    parts.append(box("tower", (4.8, 4.8, 9.15), (x, y, ROOF_Z + 4.575), M["brick"]))
    parts.append(box("tower_band_copper", (5.3, 5.3, 0.16), (x, y, 21.8), M["metal"]))
    parts.append(box("tower_band", (5.2, 5.2, 0.28), (x, y, 25.4), M["limestone"]))
    parts.append(box("tower_cornice", (5.6, 5.6, 0.4), (x, y, 27.8), M["metal"]))
    parts.append(box("tower_drum", (3.2, 3.2, 0.5), (x, y, 28.25), M["limestone"]))
    parts.append(cylinder("horn_stem", 0.45, 2.1, (x, y, 29.55), M["metal"], 12, True))
    parts.append(cone("bell", 0.85, 2.55, 3.2, (x, y, 32.1), M["metal"], 14))
    parts.append(cylinder("bell_rim", 2.62, 0.12, (x, y, 33.76), M["metal"], 14, True))
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
        name = f"jazz_{layer}_{rbx.lower()}{suffix}"
        # Un grupo de una sola pieza no se une: join con un solo objeto avisa «No mesh data to join».
        if len(members) == 1:
            mesh = members[0]
            mesh.name = name
            mesh.data.name = name
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
    box("avatar_ref", AVATAR, (-2.5 * SPACING + 2.6, lot_y - 9.0, AVATAR[2] / 2), M["avatar"])
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
    builders = {1: build_marquee, 2: build_shopfront, 3: build_trumpet_sign, 4: build_annex, 5: build_crown}
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
    lod = lod_of(objects, "jazz_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "jazz_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
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
    print("JAZZ_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if levels["0"]["limites"]["alto_maximo_sobre_suelo"] > MAX_LEVEL0:
        raise RuntimeError(f"Nivel 0 de {levels['0']['limites']['alto_maximo_sobre_suelo']}: pasa de {MAX_LEVEL0}")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] > MAX_HEIGHT:
        raise RuntimeError(f"Nivel 5 de {levels['5']['limites']['alto_maximo_sobre_suelo']}: pasa de {MAX_HEIGHT}")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "plaza-del-jazz.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["slate"], "gold": M["metal"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -205.0, 82.0), (0.0, 24.0, 11.0), 30), f"{RENDER_SUBDIR}/plaza-del-jazz-niveles.png")

    # Comparación: el nivel 0 con una figura de 6 delante de la puerta, y los bloques de Bodega (13) y Cine Lux (24).
    hide_all()
    box("ground", (200, 40, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -34.0, 0.0)
    avatar = box("avatar_ref", AVATAR, (-34.0 + 3.8, -12.0, AVATAR[2] / 2), M["avatar"])
    rotated(avatar, (0.0, 0.0, 22.0))
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (34, 0, 12.0), M["block"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -140.0, 22.0), (0.0, 0.0, 10.0), 45), f"{RENDER_SUBDIR}/plaza-del-jazz-comparacion.png")
    print("JAZZ_DONE")


if __name__ == "__main__":
    main()

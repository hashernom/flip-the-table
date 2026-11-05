"""Pasaje Burbuja: fonda con fuente de soda y taller de embotellado, zona Cian, modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 x 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de 15,5 de caliza clara con huecos de verdad (puerta y ventanales redondos
perforados), cubierta plana con depósito, tuberías de cobre y anuncio redondo, y cinco añadidos que se suman:
toldo y mostrador, vitrina de botellas y redondos mayores, terraza con barandilla, pabellón de huéspedes
retranqueado y torre del anuncio con burbuja de cristal y remate de cobre. Sigue el método de barberia-morro.py:
una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/cian/:
  pasaje-burbuja.blend                    escena de revisión (no se versiona)
  pasaje-burbuja/burbuja_<pieza>_<mat>.fbx y burbuja_LOD1.fbx
  pasaje-burbuja/stats.json               triángulos por pieza y nivel, límites y materiales
Y en art/render/cian/pasaje-burbuja/: pasaje-burbuja-niveles.png y pasaje-burbuja-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/cian/pasaje-burbuja.py
"""

import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "pasaje-burbuja")
RENDER_SUBDIR = "cian/pasaje-burbuja"
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
FRONT_LIMIT = -9.95  # nada delante de -10

BODY_H = 15.5  # altura del cuerpo decidida por el responsable
BRICK_TOP = 7.2  # planta baja de ladrillo; de ahí arriba, caliza clara
PLINTH_H = 0.85
DOOR_W = 7.6  # bay acristalado central: 7,6 de ancho y 7,0 de alto, muy por encima del mínimo
DOOR_TOP = 7.0
DOOR_RECESS = 1.2  # fondo del hueco de la puerta
PORTHOLE_R = 2.3  # ventanales redondos de la fuente de soda
PORTHOLE_X = 8.9
PORTHOLE_Z = 4.4
ROSE_R = 2.3  # el redondo grande de la sala de embotellado, sobre el rótulo
ROSE_Z = 12.9
STRING_Z = 7.52
PLACA_Z = 9.3
PLACA_W = 16.5
PLACA_H = 2.3
PARAPET_Z = 15.95
PARAPET_H = 1.05

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
CINE_LUX_L5_TRIANGLES = 3042

# Material de Roblox, sufijo de color y RGB de cada material de Blender (tabla del blueprint).
RBX = {
    "brick": ("Brick", "", "B0664A"),
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "metal": ("Metal", "", "C97B3A"),
    "metal_acero": ("Metal", "_acero", "8C939B"),
    "fabric_crema": ("Fabric", "_crema", "EDE5D3"),
    "wood": ("Wood", "", "5A3A24"),
    "grass": ("Grass", "", "4B6B3A"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "metal": flat("metal", "C97B3A", 0.3, 0.9),
        "metal_acero": flat("metal_acero", "8C939B", 0.4, 0.9),
        "fabric_crema": flat("fabric_crema", "EDE5D3", 0.85),
        "wood": flat("wood", "5A3A24", 0.7),
        "grass": flat("grass", "4B6B3A", 0.9),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "DC2626", 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "6E747C", 0.8),
    }


def cylinder(name, radius, depth, location, mat, verts=12, caps=True, rotation=(0.0, 0.0, 0.0)):
    """Cilindro. Se usa para tuberías, depósito, discos del anuncio y huecos redondos."""
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
    if mat:
        obj.data.materials.append(mat)
    return obj


def disc(name, radius, depth, location, mat, verts=12):
    """Disco mirando a la calle (-Y): el anuncio redondo de la cubierta y los cristales redondos."""
    return cylinder(name, radius, depth, location, mat, verts, True, (math.pi / 2, 0.0, 0.0))


def ring(name, radius, depth, location, mat, verts=16):
    """Anillo sin tapas: el aro de acero de la burbuja y el cerco de los ventanales mayores."""
    return cylinder(name, radius, depth, location, mat, verts, False, (math.pi / 2, 0.0, 0.0))


def cone(name, radius, depth, location, mat, verts=12):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def sphere(name, radius, location, mat, segments=12, rings=7):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=radius, location=location)
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


def round_cutter(name, radius, x, z, y=None, verts=16):
    """Cilindro tumbado hacia la calle: el hueco redondo que se perfora en la caliza."""
    return cylinder(name, radius, 3.0, (x, FRONT + 0.2 if y is None else y, z), None, verts, True, (math.pi / 2, 0.0, 0.0))


def build_body(M):
    """Nivel 0: fonda de caliza con fuente de soda. Huecos de verdad, mostrador, depósito y anuncio redondo."""
    parts = []

    # Planta baja de ladrillo con el bay acristalado y los dos ventanales redondos de la fuente, perforados.
    base = box("burbuja_base", (WIDTH, DEPTH, BRICK_TOP), (0, 0, BRICK_TOP / 2), M["brick"])
    perforate(
        base,
        [
            box("cut_door", (DOOR_W, 2.4, DOOR_TOP + 0.1), (0, FRONT + 0.2, (DOOR_TOP - 0.1) / 2)),
            round_cutter("cut_w", PORTHOLE_R, -PORTHOLE_X, PORTHOLE_Z),
            round_cutter("cut_e", PORTHOLE_R, PORTHOLE_X, PORTHOLE_Z),
        ],
    )
    parts.append(base)

    # Cuerpo alto de caliza clara con el redondo grande de la sala de embotellado.
    wall = box("burbuja_wall", (WIDTH, DEPTH, BODY_H - BRICK_TOP), (0, 0, (BODY_H + BRICK_TOP) / 2), M["limestone"])
    perforate(wall, [round_cutter("cut_rose", ROSE_R, 0.0, ROSE_Z)])
    parts.append(wall)

    # Zócalo de pizarra partido por el bay.
    parts.append(box("plinth_l", (11.9, 0.46, PLINTH_H), (-10.05, FRONT - 0.18, PLINTH_H / 2), M["slate"]))
    parts.append(box("plinth_r", (11.9, 0.46, PLINTH_H), (10.05, FRONT - 0.18, PLINTH_H / 2), M["slate"]))
    # Junta de planta baja y cornisa con pretil: la línea horizontal que ordena la fachada.
    parts.append(box("string", (WIDTH + 0.5, 0.5, 0.65), (0, FRONT - 0.2, STRING_Z), M["limestone"]))
    for name, size, loc in (
        ("parapet_f", (WIDTH + 0.6, 0.55, PARAPET_H), (0, FRONT - 0.14, PARAPET_Z)),
        ("parapet_b", (WIDTH + 0.6, 0.55, PARAPET_H), (0, -FRONT + 0.14, PARAPET_Z)),
        ("parapet_l", (0.55, DEPTH + 0.1, PARAPET_H), (-WIDTH / 2 - 0.02, 0, PARAPET_Z)),
        ("parapet_r", (0.55, DEPTH + 0.1, PARAPET_H), (WIDTH / 2 + 0.02, 0, PARAPET_Z)),
    ):
        parts.append(box(name, size, loc, M["limestone"]))
    # Azotea transitable de ladrillo: la cubierta plana del taller, por encima del muro para no coplanar.
    parts.append(box("deck", (WIDTH - 1.0, DEPTH - 1.0, 0.3), (0, 0, BODY_H + 0.05), M["brick"]))

    # Bay acristalado: portal de cobre, hojas de cristal y montantes de acero al fondo del hueco.
    glass_y = FRONT + DOOR_RECESS + 0.06
    parts.append(box("door_glass", (DOOR_W - 0.5, 0.12, 6.5), (0, glass_y, 3.35), M["glass"]))
    for x in (-2.5, 0.0, 2.5):
        parts.append(box("door_mullion", (0.16, 0.34, 6.5), (x, glass_y + 0.11, 3.25), M["metal_acero"]))
    parts.append(box("door_head", (DOOR_W - 0.3, 0.34, 0.24), (0, glass_y + 0.11, 6.72), M["metal_acero"]))
    parts.append(box("door_sill", (DOOR_W - 0.4, 0.32, 0.3), (0, glass_y + 0.1, 0.2), M["metal"]))
    parts.append(box("door_transom", (DOOR_W - 0.5, 0.3, 0.14), (0, glass_y + 0.1, 5.45), M["metal_acero"]))
    for side in (-1, 1):
        parts.append(box("portal_jamb", (0.42, 0.42, BRICK_TOP), (side * (DOOR_W / 2 + 0.21), FRONT - 0.12, BRICK_TOP / 2), M["metal_acero"]))

    # Ventanales redondos: cristal oscuro al fondo del hueco y cruz de acero en la cara de la caliza.
    for x in (-PORTHOLE_X, PORTHOLE_X):
        parts.append(disc("pane", PORTHOLE_R - 0.12, 0.14, (x, FRONT + 1.05, PORTHOLE_Z), M["glass"], 12))
        parts.append(box("muntin_h", (2 * PORTHOLE_R - 0.1, 0.16, 0.16), (x, FRONT - 0.04, PORTHOLE_Z), M["metal_acero"]))
        parts.append(box("muntin_v", (0.16, 0.16, 2 * PORTHOLE_R - 0.1), (x, FRONT - 0.04, PORTHOLE_Z), M["metal_acero"]))
    parts.append(disc("rose_pane", ROSE_R - 0.12, 0.14, (0, FRONT + 0.95, ROSE_Z), M["glass"], 12))
    parts.append(box("rose_bar_h", (2 * ROSE_R - 0.1, 0.18, 0.18), (0, FRONT - 0.05, ROSE_Z), M["metal_acero"]))
    parts.append(box("rose_bar_v", (0.18, 0.18, 2 * ROSE_R - 0.1), (0, FRONT - 0.05, ROSE_Z), M["metal_acero"]))

    # Placa de pizarra con el nombre en letras de caliza, por encima del portal y del toldo.
    parts.append(box("placa", (PLACA_W, 0.4, PLACA_H), (0, FRONT - 0.15, PLACA_Z), M["slate"]))
    parts.append(fit_width(letters("PASAJE BURBUJA", 1.9, (0, FRONT - 0.4, PLACA_Z), M["limestone"], depth=0.18), PLACA_W - 1.6))

    # Tuberías de cobre del taller de embotellado, a los lados de la fachada.
    for x in (-12.0, 12.0):
        parts.append(cylinder("pipe", 0.2, 15.1, (x, FRONT - 0.18, 7.65), M["metal"], 8, True))

    # Mostrador de soda: la fuente de soda se ve desde la calle, bajo el ventanal del oeste.
    parts.append(box("bar_base", (5.2, 0.9, 1.05), (-PORTHOLE_X, FRONT - 0.45, 0.525), M["limestone"]))
    parts.append(box("bar_top", (5.45, 0.9, 0.16), (-PORTHOLE_X, FRONT - 0.45, 1.13), M["metal"]))
    parts.append(box("fountain_column", (0.5, 0.5, 0.75), (-PORTHOLE_X - 1.4, FRONT - 0.45, 1.58), M["metal"]))
    parts.append(box("fountain_head", (1.5, 0.42, 0.28), (-PORTHOLE_X - 1.4, FRONT - 0.45, 2.05), M["metal"]))

    # Depósito de agua del taller, sobre dos caballetes de acero en la mitad trasera.
    for dx in (-1.6, 1.6):
        parts.append(box("tank_leg", (0.3, 3.4, 1.2), (-9.0 + dx, 4.6, BODY_H + 0.6), M["metal_acero"]))
    parts.append(box("tank_deck", (4.3, 4.3, 0.2), (-9.0, 4.6, BODY_H + 1.3), M["metal_acero"]))
    parts.append(cylinder("tank", 2.1, 2.6, (-9.0, 4.6, BODY_H + 2.85), M["slate"], 10, True))
    parts.append(cone("tank_cap", 2.2, 0.8, (-9.0, 4.6, BODY_H + 4.55), M["metal"], 10))

    # Anuncio redondo sobre la cubierta: la burbuja del negocio ya en el nivel 0.
    parts.append(cylinder("sign_post", 0.2, 1.5, (9.3, -5.6, BODY_H + 0.75), M["metal_acero"], 8, True))
    parts.append(disc("sign_back", 2.0, 0.36, (9.3, -5.45, BODY_H + 3.4), M["metal"], 12))
    parts.append(disc("sign_glass", 1.78, 0.16, (9.3, -5.67, BODY_H + 3.4), M["glass"], 12))
    return parts


def build_awning(M):
    """Nivel 1: toldo de lona claro sobre el mostrador y la puerta, y mostrador exterior a la calle."""
    parts = []
    run, drop = 0.85, 0.55
    slope = math.hypot(run, drop)
    angle = math.atan2(-drop, -run)
    canvas = box("awning", (18.0, slope, 0.14), (0, FRONT - run / 2, 7.33), M["fabric_crema"])
    canvas.rotation_euler = (angle, 0.0, 0.0)
    parts.append(canvas)
    # Faldón de cobre y rayas de pizarra sobre la lona: el canto que se lee desde lejos.
    parts.append(box("valance", (18.0, 0.12, 0.4), (0, FRONT - run + 0.02, 6.85), M["metal"]))
    for x in (-6.75, -2.25, 2.25, 6.75):
        stripe = box("awning_stripe", (2.2, slope, 0.16), (x, FRONT - run / 2, 7.34), M["slate"])
        stripe.rotation_euler = (angle, 0.0, 0.0)
        parts.append(stripe)
    for x in (-9.0, 9.0):
        parts.append(box("awning_bar", (0.18, 1.0, 0.18), (x, FRONT - run / 2, 7.3), M["metal"]))
    parts.append(cylinder("awning_rail", 0.1, 18.0, (0, FRONT - run + 0.06, 7.14), M["metal"], 8, True, (0.0, math.pi / 2, 0.0)))

    # Mostrador exterior: barra de caliza con tablero de cobre, a la calle bajo el ventanal del este.
    parts.append(box("street_bar", (5.4, 0.9, 1.3), (9.4, FRONT - 0.45, 0.65), M["limestone"]))
    parts.append(box("street_top", (5.65, 0.9, 0.18), (9.4, FRONT - 0.45, 1.39), M["metal"]))
    return parts


def build_upgrade(M):
    """Nivel 2: vitrina de botellas junto a la puerta y ventanales redondos mayores en las dos fachadas."""
    parts = []
    # Cerco de cristal y acero que agranda cada ventanal redondo del cuerpo.
    for x in (-PORTHOLE_X, PORTHOLE_X):
        parts.append(ring("lens", 2.82, 0.56, (x, FRONT - 0.28, PORTHOLE_Z), M["glass"], 16))
        parts.append(ring("lens_rim", 2.94, 0.36, (x, FRONT - 0.62, PORTHOLE_Z), M["metal"], 16))

    # Vitrina de botellas: caja acristalada con estantes y botellas en la caliza, junto a la puerta.
    vx = 5.6
    parts.append(box("vitrine_back", (2.4, 0.16, 4.0), (vx, FRONT - 0.05, 3.4), M["slate"]))
    parts.append(box("vitrine_glass", (2.5, 0.1, 4.1), (vx, FRONT - 0.62, 3.4), M["glass"]))
    for z in (1.42, 5.38):
        parts.append(box("vitrine_lip", (2.6, 0.62, 0.16), (vx, FRONT - 0.31, z), M["metal_acero"]))
    for z in (2.5, 3.6):
        parts.append(box("shelf", (2.3, 0.5, 0.1), (vx, FRONT - 0.34, z), M["metal_acero"]))
    for x0, z0 in ((vx - 0.62, 2.9), (vx + 0.45, 3.95)):
        parts.append(box("bottle", (0.24, 0.24, 0.9), (x0, FRONT - 0.34, z0), M["glass"]))
    return parts


def build_terrace(M):
    """Nivel 3: terraza de degustación con barandilla sobre la cubierta delantera oeste."""
    parts = []
    x0, x1 = -14.6, -4.4
    y0, y1 = -8.25, -4.3
    xc, yc = (x0 + x1) / 2, (y0 + y1) / 2
    deck_z = BODY_H + 0.25
    parts.append(box("terrace_deck", (x1 - x0, y1 - y0, 0.2), (xc, yc, deck_z - 0.1), M["wood"]))
    rail_z = deck_z + 1.05
    # Barandilla: dos largueros por lado y tres postes, sin barrotes que gasten triángulos.
    parts.append(box("rail_front_a", (x1 - x0, 0.14, 0.14), (xc, y0 + 0.07, rail_z), M["metal"]))
    parts.append(box("rail_front_b", (x1 - x0, 0.12, 0.12), (xc, y0 + 0.07, rail_z - 0.42), M["metal"]))
    parts.append(box("rail_left_a", (0.14, y1 - y0, 0.14), (x0 + 0.07, yc, rail_z), M["metal"]))
    parts.append(box("rail_left_b", (0.12, y1 - y0, 0.12), (x0 + 0.07, yc, rail_z - 0.42), M["metal"]))
    for x in (x0 + 0.07, xc, x1 - 0.07):
        parts.append(box("post", (0.18, 0.18, 1.15), (x, y0 + 0.07, deck_z + 0.58), M["metal"]))
    # Dos mesas de madera y una sombrilla de lona: el uso de la terraza se lee desde arriba.
    for tx, ty in ((x0 + 2.6, yc - 0.3), (x1 - 2.4, yc + 0.5)):
        parts.append(box("table_top", (1.5, 1.5, 0.14), (tx, ty, deck_z + 0.98), M["metal"]))
        parts.append(box("table_leg", (0.32, 0.32, 0.9), (tx, ty, deck_z + 0.47), M["wood"]))
    parts.append(cylinder("parasol_pole", 0.11, 2.1, (x1 - 2.2, y0 + 1.4, deck_z + 1.05), M["metal"], 8, True))
    parts.append(cone("parasol", 1.7, 0.65, (x1 - 2.2, y0 + 1.4, deck_z + 2.15), M["fabric_crema"], 12))
    # Jardinera con hierba contra el pretil.
    parts.append(box("planter", (4.4, 0.7, 0.55), (xc, y1 - 0.5, deck_z + 0.3), M["limestone"]))
    parts.append(box("planter_grass", (4.2, 0.6, 0.3), (xc, y1 - 0.5, deck_z + 0.7), M["grass"]))
    return parts


def build_pavilion(M):
    """Nivel 4: pabellón de huéspedes retranqueado en la mitad trasera, con cubierta a dos aguas."""
    parts = []
    px0, px1 = -1.0, 15.0
    py0, py1 = 1.5, 8.6
    px, py = (px0 + px1) / 2, (py0 + py1) / 2
    top = 22.0
    win_x = px + 2.6
    pavilion = box("pavilion", (px1 - px0, py1 - py0, top - BODY_H), (px, py, (BODY_H + top) / 2), M["limestone"])
    perforate(pavilion, [round_cutter("cut_pav", 1.7, win_x, 19.2, y=py0 + 0.1)])
    parts.append(pavilion)
    parts.append(disc("pav_pane", 1.58, 0.14, (win_x, py0 + 1.5, 19.2), M["glass"], 12))
    parts.append(box("pav_bar_h", (3.3, 0.16, 0.16), (win_x, py0 - 0.02, 19.2), M["metal_acero"]))
    parts.append(box("pav_bar_v", (0.16, 0.16, 3.3), (win_x, py0 - 0.02, 19.2), M["metal_acero"]))

    # Cubierta a dos aguas de pizarra y canalón de cobre en el alero de la calle.
    ridge_z, ridge_y = 23.15, py
    for sign in (-1, 1):
        eave_y = py0 if sign < 0 else py1
        dy = ridge_y - eave_y
        dz = ridge_z - top
        theta = math.atan2(dz, dy) * sign
        length = math.hypot(dy, dz) + 0.4
        slab = box("pav_roof", (px1 - px0 + 0.6, length, 0.26), (px, (eave_y + ridge_y) / 2, (top + ridge_z) / 2), M["slate"])
        slab.rotation_euler = (-theta, 0.0, 0.0)
        parts.append(slab)
    parts.append(box("pav_ridge", (px1 - px0 + 0.7, 0.3, 0.24), (px, ridge_y, ridge_z + 0.16), M["metal"]))
    parts.append(cylinder("pav_gutter", 0.17, px1 - px0, (px, py0 - 0.16, top + 0.06), M["metal"], 8, True, (0.0, math.pi / 2, 0.0)))
    return parts


def build_crown(M):
    """Nivel 5: torre del anuncio con la burbuja de cristal y remate de cobre. Sube a 33,4."""
    parts = []
    cx, cy = 0.0, -2.0
    shaft_top = 23.8
    parts.append(box("tower", (4.8, 4.8, shaft_top - BODY_H), (cx, cy, (BODY_H + shaft_top) / 2), M["limestone"]))
    parts.append(box("tower_band", (5.4, 5.4, 0.5), (cx, cy, shaft_top + 0.25), M["metal"]))

    # Burbuja: esfera de cristal más ancha que la torre, con dos aros de acero. Es la seña a esa altura.
    bubble_z = 27.3
    parts.append(sphere("bubble", 3.0, (cx, cy, bubble_z), M["glass"], 12, 7))
    parts.append(cylinder("bubble_belt", 3.11, 0.22, (cx, cy, bubble_z), M["metal_acero"], 16, False))
    parts.append(cylinder("bubble_meridian", 3.11, 0.22, (cx, cy, bubble_z), M["metal_acero"], 16, False, (math.pi / 2, 0.0, 0.0)))
    parts.append(cylinder("bubble_collar", 0.6, 0.55, (cx, cy, bubble_z + 3.1), M["metal"], 12, True))
    parts.append(cone("finial", 0.85, 2.3, (cx, cy, bubble_z + 4.45), M["metal"], 12))
    parts.append(sphere("finial_ball", 0.3, (cx, cy, bubble_z + 5.75), M["metal"], 6, 4))
    return parts


def group(level, parts, store):
    """Une las piezas de un nivel en una malla por material y color. En Roblox cada malla lleva un material."""
    layer = "body" if level == 0 else f"addon{level}"
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        rbx, suffix, rgb = RBX[key]
        name = f"burbuja_{layer}_{rbx.lower()}{suffix}"
        if len(members) == 1:
            # Un solo objeto: no hay nada que unir y join() avisa «No mesh data to join».
            mesh = members[0]
            mesh.name = name
            select_only(mesh)
            bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
            bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
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
    # Borra las FBX de una corrida anterior: si una pieza deja de existir, no debe quedar huérfana.
    for stale in os.listdir(OUT):
        if stale.endswith(".fbx"):
            os.remove(os.path.join(OUT, stale))

    M = make_materials()
    pieces = []

    # Nivel 0: cuerpo. Niveles 1 a 5: añadidos que se suman sin sustituir nada.
    group(0, build_body(M), pieces)
    builders = {1: build_awning, 2: build_upgrade, 3: build_terrace, 4: build_pavilion, 5: build_crown}
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
    lod = lod_of(objects, "burbuja_LOD1")
    lod_tris = count(lod)
    if lod_tris >= total / 2:  # el decimado a veces no basta con mallas de texto
        select_only(lod)
        decimate = lod.modifiers.new("Decimate2", "DECIMATE")
        decimate.ratio = 0.8
        bpy.ops.object.modifier_apply(modifier=decimate.name)
        lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "burbuja_LOD1.fbx")

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
    print("BURBUJA_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))
    for p in pieces:
        print("PIEZA", p["key"], p["level"], count(p["obj"]))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    top = levels["5"]["limites"]["alto_maximo_sobre_suelo"]
    if top > MAX_HEIGHT:
        raise RuntimeError(f"Altura total de {top} supera {MAX_HEIGHT}")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "pasaje-burbuja.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["slate"], "gold": M["metal"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -190.0, 78.0), (0.0, 22.0, 10.0), 30), f"{RENDER_SUBDIR}/pasaje-burbuja-niveles.png")

    # Comparación: nivel 0 frente al avatar de 6 y a un bloque de Bodega (13) y otro de Cine Lux (24).
    hide_all()
    box("ground", (170, 40, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -40.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (40, 0, 12.0), M["block"])
    box("avatar_ref", (2.0, 1.3, 4.8), (-21.5, -11.0, 2.4), M["dark"])
    box("avatar_head", (1.5, 1.3, 1.2), (-21.5, -11.0, 5.4), M["dark"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -150.0, 30.0), (0.0, 0.0, 9.0), 42), f"{RENDER_SUBDIR}/pasaje-burbuja-comparacion.png")
    print("BURBUJA_DONE")


if __name__ == "__main__":
    main()

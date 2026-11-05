"""Almacén El Ladrillo: propiedad de la zona Ocre (sector del ladrillo), modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de 16 y cinco añadidos que se suman: marquesina de carga, andén y
portones, depósito de cubierta, pabellón de oficinas y torre del depósito con remate de cobre.

Se reconoce por el patio de carga excavado en el frente, con portalón alto, pilas de ladrillo y marquesina:
es lo que la distingue de sus vecinas (Curtiembre Los Nogales y Fábrica de Ladrillos La Hormiga, que van por
chimeneas y secaderos). Sigue el método de barberia-morro.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/ocre/:
  almacen-el-ladrillo.blend                     escena de revisión (no se versiona)
  almacen-el-ladrillo/almacen_<pieza>_<material>.fbx y almacen_LOD1.fbx
  almacen-el-ladrillo/stats.json                triángulos por pieza y nivel, límites y materiales
Y en art/render/ocre/almacen-el-ladrillo/: almacen-el-ladrillo-niveles.png y almacen-el-ladrillo-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/ocre/almacen-el-ladrillo.py
"""

import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "almacen-el-ladrillo")
RENDER_SUBDIR = "ocre/almacen-el-ladrillo"
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
BODY_H = 16.0  # masa principal: lo que el responsable fija para esta propiedad
BAY_W = 12.0  # patio de carga excavado en el frente
BAY_Y = -6.0  # su fondo
BAY_TOP = 10.5
GATE_W = 9.0  # portalón principal, como el de la Bodega
GATE_H = 7.4  # más alto que el avatar (6)
GATE_DEEP = 1.4  # hornacina del portón, con las pilas dentro
SIDE_GATE_W = 5.2
SIDE_GATE_H = 5.8
DOOR_W = 2.4  # puerta de oficina
DOOR_H = 6.5
DOOR_X = -13.6
WINDOW_X = -9.0
WINDOW_W = 4.2
WINDOW_Z0 = 3.4
WINDOW_Z1 = 5.3
SIDE_GATE_X = 12.0
SIGN_Z = 13.35
PLATE_W = 20.6
PLATE_H = 2.8
LETTER_SIZE = 1.8
CANOPY_W = 12.8
TRIANGLE_BUDGET = 3000
MAX_HEIGHT = 40.0  # altura máxima con el nivel 5, decidida por el responsable
LEVEL0_MAX = 21.0  # el nivel 0 completo, cubierta incluida, no pasa de aquí
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

# Material de Roblox, sufijo de color y RGB de cada clave de material de Blender.
RBX = {
    "brick": ("Brick", "", "B0664A"),
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "metal_acero": ("Metal", "_acero", "A8AEB4"),
    "metal_oro": ("Metal", "_oro", "C9A227"),
    "metal_ocre": ("Metal", "_ocre", "A16207"),
    "wood": ("Wood", "", "6B4A2E"),
    "fabric_rojo": ("Fabric", "_rojo", "C4382B"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.4, 0.85),
        "metal_oro": flat("metal_oro", "C9A227", 0.3, 0.9),
        "metal_ocre": flat("metal_ocre", "A16207", 0.45, 0.7),
        "wood": flat("wood", "6B4A2E", 0.75),
        "fabric_rojo": flat("fabric_rojo", "C4382B", 0.8),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "A16207", 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "6E747C", 0.8),
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


def cone(name, radius, depth, location, mat, verts=12):
    """Cono de remate (el cobre de la torre)."""
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


def brick_pile(parts, M, x, y, z0, width, depth, courses, course_h, mat):
    """Pila de ladrillo: cada curso es una caja, para que se lean las juntas."""
    for k in range(courses):
        parts.append(box("brick_pile", (width, depth, course_h), (x, y, z0 + course_h * (k + 0.5)), mat))


def build_body(M):
    """Nivel 0: nave de ladrillo con patio de carga, portón alto, oficina, rótulo y cubierta de pizarra."""
    parts = []

    # Masa de ladrillo: patio de carga excavado en el frente, portalón, portón de servicio y oficina.
    nave = box("nave", (WIDTH, DEPTH, BODY_H), (0, 0, BODY_H / 2), M["brick"])
    perforate(
        nave,
        [
            # El patio entra 3 de fondo y 10,5 de alto: deja el portalón en la sombra de la marquesina.
            box("cut_bay", (BAY_W, 3.5, BAY_TOP + 0.5), (0, -7.75, (BAY_TOP - 0.5) / 2)),
            # Hornacina del portalón, con sitio para las pilas.
            box("cut_gate", (GATE_W, GATE_DEEP + 0.1, GATE_H + 0.3), (0, BAY_Y + GATE_DEEP / 2 - 0.05, (GATE_H - 0.3) / 2)),
            box("cut_door", (DOOR_W, 1.3, DOOR_H + 0.3), (DOOR_X, FRONT + 0.55, (DOOR_H - 0.3) / 2)),
            box("cut_window", (WINDOW_W, 1.2, WINDOW_Z1 - WINDOW_Z0), (WINDOW_X, FRONT + 0.6, (WINDOW_Z0 + WINDOW_Z1) / 2)),
            box("cut_side_gate", (SIDE_GATE_W, 1.3, SIDE_GATE_H + 0.3), (SIDE_GATE_X, FRONT + 0.55, (SIDE_GATE_H - 0.3) / 2)),
        ],
    )
    parts.append(nave)

    # Pilastras de ladrillo: las del patio (el rasgo se enmarca) y las de las esquinas, como el kit de la zona.
    for side in (-1, 1):
        parts.append(box("bay_pilaster", (0.7, 0.6, BAY_TOP), (side * 6.4, -9.25, BAY_TOP / 2), M["brick"]))
        parts.append(box("bay_impost", (1.0, 0.8, 0.45), (side * 6.4, -9.3, BAY_TOP - 0.22), M["limestone"]))
        parts.append(box("corner_pilaster", (0.9, 0.5, BODY_H), (side * 15.5, -9.2, BODY_H / 2), M["brick"]))

    # Cornisa de caliza y cubierta de pizarra.
    parts.append(box("cornice", (WIDTH + 0.8, DEPTH + 0.8, 0.7), (0, 0, BODY_H + 0.35), M["limestone"]))
    parts.append(box("roof", (WIDTH - 0.5, DEPTH - 0.5, 0.45), (0, 0, BODY_H + 0.925), M["slate"]))

    # Linterna de la nave central: sube el centro del edificio y le da la banda de luz de las naves.
    parts.append(box("monitor", (18.0, 6.5, 2.9), (0, -1.75, 18.6), M["brick"]))
    parts.append(box("monitor_cap", (18.6, 7.1, 0.4), (0, -1.75, 20.25), M["slate"]))
    parts.append(box("monitor_glass", (12.0, 0.1, 1.2), (0, -5.02, 18.9), M["glass"]))

    # Zócalo de caliza, partido en los huecos.
    plinth = [
        (1.4, -15.5),
        (5.7, -9.55),
        (2.7, 8.05),
        (1.6, 15.4),
    ]
    for width, xc in plinth:
        parts.append(box("plinth_front", (width, 0.45, 0.45), (xc, -8.95, 0.225), M["limestone"]))
    for side in (-1, 1):
        parts.append(box("plinth_side", (0.4, 18.0, 0.45), (side * 16.1, 0.0, 0.225), M["limestone"]))
    parts.append(box("plinth_back", (32.6, 0.4, 0.45), (0, 9.1, 0.225), M["limestone"]))

    # Portalón: dintel de acero y guías. El portón queda abierto para que se vean las pilas.
    parts.append(box("gate_head", (9.6, 0.55, 0.85), (0, BAY_Y - 0.05, GATE_H + 0.32), M["metal_acero"]))
    for side in (-1, 1):
        parts.append(box("gate_guide", (0.28, 0.36, GATE_H), (side * 4.62, BAY_Y - 0.06, GATE_H / 2), M["metal_acero"]))

    # Pilas de ladrillo en la boca del patio de carga: se ven por el portón y les da la luz del cielo.
    for x in (-2.3, 2.3):
        brick_pile(parts, M, x, -8.4, 0.0, 2.6, 0.9, 3, 1.1, M["brick"])

    # Oficina: puerta de madera con recercado de caliza, ventanal de oficina con parteluces y toldillo de lona.
    parts.append(box("door_leaf", (2.3, 0.12, 6.3), (DOOR_X, -8.42, 3.15), M["wood"]))
    for side in (-1, 1):
        parts.append(box("door_jamb", (0.28, 0.5, 6.7), (DOOR_X + side * 1.34, -8.9, 3.35), M["limestone"]))
    parts.append(box("door_head", (3.0, 0.5, 0.35), (DOOR_X, -8.9, 6.72), M["limestone"]))

    parts.append(box("window_glass", (WINDOW_W - 0.2, 0.1, WINDOW_Z1 - WINDOW_Z0 - 0.2), (WINDOW_X, -8.55, 4.35), M["glass"]))
    for side in (-1, 1):
        parts.append(box("window_mullion", (0.12, 0.3, WINDOW_Z1 - WINDOW_Z0), (WINDOW_X + side * 0.7, -8.55, 4.35), M["wood"]))
    parts.append(box("window_sill", (WINDOW_W + 0.5, 0.55, 0.3), (WINDOW_X, -8.95, 3.2), M["limestone"]))
    parts.append(box("window_head", (WINDOW_W + 0.5, 0.55, 0.32), (WINDOW_X, -8.95, 5.42), M["limestone"]))

    run, drop = 0.95, 0.45
    angle = math.atan2(drop, run)
    awning = box("office_awning", (3.6, math.hypot(run, drop), 0.08), (DOOR_X, FRONT - run / 2 + 0.02, 7.12), M["fabric_rojo"])
    awning.rotation_euler = (angle, 0, 0)
    parts.append(awning)
    parts.append(box("office_valance", (3.6, 0.07, 0.34), (DOOR_X, FRONT - run - 0.01, 6.72), M["fabric_rojo"]))

    # Portón de servicio: persiana de acero cerrada, con recercado de caliza.
    for k in range(5):
        parts.append(box("side_slat", (5.0, 0.12, 1.12), (SIDE_GATE_X, -8.5, 0.56 + 1.14 * k), M["metal_acero"]))
    for side in (-1, 1):
        parts.append(box("side_jamb", (0.3, 0.45, SIDE_GATE_H + 0.2), (SIDE_GATE_X + side * (SIDE_GATE_W / 2 + 0.15), -8.9, (SIDE_GATE_H + 0.2) / 2), M["limestone"]))
    parts.append(box("side_head", (SIDE_GATE_W + 0.6, 0.45, 0.35), (SIDE_GATE_X, -8.9, SIDE_GATE_H + 0.17), M["limestone"]))

    # Rótulo: placa de pizarra con el nombre en letras de caliza, por encima del portón y de la marquesina.
    parts.append(box("sign_plate", (PLATE_W, 0.35, PLATE_H), (0, -9.15, SIGN_Z), M["slate"]))
    name = letters("ALMACÉN EL LADRILLO", LETTER_SIZE, (0, -9.36, SIGN_Z), M["limestone"], depth=0.22)
    parts.append(fit_width(name, PLATE_W - 1.2))
    return parts


def build_canopy(M):
    """Nivel 1: marquesina de carga sobre el patio, con faldón de lona roja y carril del polipasto."""
    parts = []
    y_back, z_back = -5.8, 10.4
    y_front, z_front = -9.8, 8.95
    run = y_back - y_front
    drop = z_back - z_front
    angle = math.atan2(drop, run)
    deck = box(
        "canopy_deck",
        (CANOPY_W, math.hypot(run, drop), 0.26),
        (0, (y_back + y_front) / 2, (z_back + z_front) / 2),
        M["metal_acero"],
    )
    deck.rotation_euler = (angle, 0, 0)
    parts.append(deck)
    parts.append(box("canopy_beam", (CANOPY_W, 0.34, 0.58), (0, y_front + 0.17, z_front - 0.22), M["metal_acero"]))
    parts.append(box("canopy_valance", (CANOPY_W, 0.07, 0.95), (0, y_front - 0.04, z_front - 0.5), M["fabric_rojo"]))
    parts.append(box("hoist_rail", (0.28, 3.4, 0.28), (0, -7.9, 9.45), M["metal_acero"]))
    parts.append(box("hoist_block", (0.36, 0.36, 0.55), (0, -6.7, 9.05), M["metal_acero"]))
    return parts


def build_dock(M):
    """Nivel 2: andén de carga y portones. Persiana, recercado de caliza, pilas, bolardos e imposta."""
    parts = []
    parts.append(box("dock", (10.6, 1.9, 0.8), (0, -6.95, 0.4), M["limestone"]))
    parts.append(box("dock_edge", (10.6, 0.18, 0.24), (0, -7.86, 0.72), M["metal_acero"]))
    # El portón baja hasta media altura: la persiana de acero, con sus lamas.
    for k in range(6):
        parts.append(box("gate_slat", (8.9, 0.12, 0.42), (0, BAY_Y - 0.02, 4.75 + 0.45 * k), M["metal_acero"]))
    for x in (-4.0, 4.0):
        brick_pile(parts, M, x, -7.0, 0.8, 2.2, 1.0, 3, 0.52, M["brick"])
    for side in (-1, 1):
        parts.append(box("portal_jamb", (0.6, 0.6, GATE_H), (side * 4.85, BAY_Y - 0.2, GATE_H / 2), M["limestone"]))
        parts.append(box("bollard", (0.32, 0.32, 1.2), (side * 5.5, -8.45, 0.6), M["metal_acero"]))
        parts.append(box("string_course", (10.4, 0.45, 0.4), (side * 11.1, -9.15, 9.85), M["limestone"]))
    return parts


def build_tank(M):
    """Nivel 3: depósito de cubierta. Tanque horizontal de acero sobre dos apoyos de caliza, a la izquierda."""
    parts = []
    for x in (-13.6, -10.4):
        parts.append(box("tank_saddle", (1.3, 3.2, 2.0), (x, -3.0, 18.15), M["limestone"]))
    tank = cylinder("roof_tank", 1.6, 5.2, (-12.0, -3.0, 20.1), M["metal_acero"], 12, True)
    tank.rotation_euler = (0, math.radians(90), 0)
    parts.append(tank)
    for x in (-13.7, -12.0, -10.3):
        band = cylinder("tank_band", 1.68, 0.16, (x, -3.0, 20.1), M["metal_acero"], 12, False)
        band.rotation_euler = (0, math.radians(90), 0)
        parts.append(band)
    parts.append(box("tank_hatch", (0.9, 0.9, 0.18), (-12.0, -3.0, 21.79), M["metal_acero"]))
    return parts


def build_office(M):
    """Nivel 4: pabellón anexo de oficinas, retranqueado sobre la cubierta, con dos bandas de cristal."""
    parts = []
    parts.append(box("annex", (8.6, 6.2, 6.2), (10.6, 4.8, 20.25), M["brick"]))
    parts.append(box("annex_band", (9.0, 6.6, 0.28), (10.6, 4.8, 20.4), M["limestone"]))
    for z in (18.55, 21.55):
        parts.append(box("annex_glass", (6.6, 0.12, 1.0), (10.6, 1.66, z), M["glass"]))
    parts.append(box("annex_cornice", (9.0, 6.6, 0.4), (10.6, 4.8, 23.55), M["limestone"]))
    parts.append(box("annex_roof", (8.4, 6.0, 0.32), (10.6, 4.8, 23.9), M["slate"]))
    return parts


def build_tower(M):
    """Nivel 5: torre del depósito. Fuste de ladrillo, tanque de acero y remate de cobre."""
    parts = []
    parts.append(box("tower_base", (6.4, 6.4, 0.55), (0, 5.4, 17.42), M["limestone"]))
    parts.append(box("tower_shaft", (5.4, 5.4, 10.6), (0, 5.4, 23.0), M["brick"]))
    parts.append(box("tower_band", (5.8, 5.8, 0.35), (0, 5.4, 23.4), M["limestone"]))
    parts.append(box("tower_gallery", (6.6, 6.6, 0.24), (0, 5.4, 28.42), M["metal_acero"]))
    parts.append(cylinder("tower_tank", 2.9, 4.4, (0, 5.4, 30.7), M["metal_acero"], 12, True))
    for z in (29.6, 31.9):
        parts.append(cylinder("tower_ring", 2.98, 0.18, (0, 5.4, z), M["metal_ocre"], 12, False))
    parts.append(cone("tower_cap", 3.15, 2.2, (0, 5.4, 34.0), M["metal_oro"]))
    parts.append(box("tower_finial", (0.18, 0.18, 1.2), (0, 5.4, 35.55), M["metal_oro"]))
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
        name = f"almacen_{layer}_{rbx.lower()}{suffix}"
        # Un grupo de una sola pieza no se une: join con un único objeto avisa «No mesh data to join».
        mesh = members[0] if len(members) == 1 else join(members, name)
        mesh.name = name
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
        "frente": round(min(ys), 2),
        "fondo_maximo": round(max(ys), 2),
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
    box("avatar_ref", (1.6, 1.2, 6.0), (-2.5 * SPACING + 15.4, lot_y - 9.0, 3.0), M["avatar"])
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
    builders = {1: build_canopy, 2: build_dock, 3: build_tank, 4: build_office, 5: build_tower}
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
    lod = lod_of(objects, "almacen_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "almacen_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "cuerpo": BODY_H,
        "altura_maxima": MAX_HEIGHT,
        "nivel0_maximo": LEVEL0_MAX,
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
    print("ALMACEN_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": {k: v["limites"]["alto_maximo_sobre_suelo"] for k, v in levels.items()}}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] > MAX_HEIGHT:
        raise RuntimeError(f"El nivel 5 pasa de {MAX_HEIGHT}: {levels['5']['limites']['alto_maximo_sobre_suelo']}")
    if levels["0"]["limites"]["alto_maximo_sobre_suelo"] > LEVEL0_MAX:
        raise RuntimeError(f"El nivel 0 pasa de {LEVEL0_MAX}: {levels['0']['limites']['alto_maximo_sobre_suelo']}")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "almacen-el-ladrillo.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["slate"], "gold": M["metal_oro"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -190.0, 78.0), (0.0, 22.0, 10.0), 30), f"{RENDER_SUBDIR}/almacen-el-ladrillo-niveles.png")

    # Comparación: nivel 0 frente a la Bodega (13) y el Cine Lux (24), con la figura de 6 junto al portón.
    hide_all()
    box("ground", (180, 60, 0.4), (0, -6, -0.2), M["pavement"])
    place(cumulative_objects[0], -40.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (40, 0, 12.0), M["block"])
    # La figura va delante de la fachada, junto al portón y contra el ladrillo, para poder medir la puerta.
    box("avatar_ref", (1.6, 1.2, 6.0), (-40.0 + 7.7, -10.4, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -150.0, 30.0), (0.0, 0.0, 9.0), 42), f"{RENDER_SUBDIR}/almacen-el-ladrillo-comparacion.png")
    print("ALMACEN_DONE")


if __name__ == "__main__":
    main()

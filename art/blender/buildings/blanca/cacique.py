"""Cacique: centro comercial de Blanca (Cumbre Blanca), modelado desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de 30.5 y cinco añadidos que se suman: marquesina de acceso, vidrio de
los extremos, terraza-bar con pérgola, pabellón anexo de tiendas y torre del rótulo con remate de oro. Sigue
el método de barberia-morro.py: una malla por material y color, LOD1 con decimado.

El rasgo propio son dos cosas: los extremos curvados en planta, como el casco de un crucero, y la terraza
abierta de la última planta. Por eso el cuerpo no es una caja: la planta se genera con esquinas delanteras
muy redondeadas, y la cubierta se recorta delante para dejar la terraza a la vista desde la calle, con los
extremos del edificio más altos a los lados, como las alas del puente.

Salidas, en art/blender/buildings/blanca/:
  cacique.blend                 escena de revisión (no se versiona)
  cacique/<clave>.fbx y cacique_LOD1.fbx
  cacique/stats.json            triángulos por pieza y nivel, límites y materiales
Y en art/render/blanca/cacique/: cacique-niveles.png y cacique-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/blanca/cacique.py
"""

import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "cacique")
RENDER_SUBDIR = "blanca/cacique"
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
HALF_W = WIDTH / 2
HALF_D = DEPTH / 2
R_FRONT = 6.5  # radio de las esquinas delanteras: la curva de los extremos
R_BACK = 4.5
ARC_SEG = 4  # segmentos por esquina: curva barata y legible

Z_GROUND = 8.8  # planta baja; encima vuela la cornisa
Z_FASCIA = 12.8  # banda del rótulo
Z_RIB1 = (12.75, 18.45)  # primera banda de vidrio azul
Z_MID = (18.4, 19.8)
Z_RIB2 = (19.75, 24.3)  # segunda banda de vidrio azul
Z_TOP = 30.5  # masa principal
Z_TERRACE = 24.2  # cara inferior de la losa de cubierta

PORTAL_W = 9.0  # portalón: más alto que una figura de 6
PORTAL_H = 7.4
PORTAL_BACK = -5.8  # fondo del zaguán
ARCADE_Z = (0.45, 5.7)  # arquería de tiendas: más baja que el portalón, para que la entrada mande
ARCADE_BACK = -8.2  # fondo del hueco de la arquería: el vidrio queda 0,7 por dentro
SIGN_Z = 10.8

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
MAX_HEIGHT = 46.0
BODY_LIMIT = 35.5  # el nivel 0 con su cubierta no pasa de aquí

# Material de Roblox, sufijo de color y RGB de cada clave de material de Blender.
RBX = {
    "limestone": ("Limestone", "", "D2C9B4"),
    "glass": ("Glass", "", "2E4A63"),
    "slate": ("Slate", "", "4A4E54"),
    "metal_acero": ("Metal", "_acero", "A8AEB4"),
    "metal_oro": ("Metal", "_oro", "C9A227"),
    "wood": ("Wood", "", "6B4A2E"),
    "fabric_rojo": ("Fabric", "_rojo", "C4382B"),
    "grass": ("Grass", "", "4B6B3A"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "slate": flat("slate", "4A4E54", 0.85),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.35, 0.9),
        "metal_oro": flat("metal_oro", "C9A227", 0.3, 0.9),
        "wood": flat("wood", "6B4A2E", 0.7),
        "fabric_rojo": flat("fabric_rojo", "C4382B", 0.8),
        "grass": flat("grass", "4B6B3A", 0.9),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "EDE5D3", 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "8F8A80", 0.8),
        "avatar": flat("avatar", "59616B", 0.8),
    }


def plan(inset=0.0):
    """Contorno del volumen en planta, cerrado y en sentido antihorario.

    Las esquinas delanteras van muy redondeadas y las traseras algo menos: de ahí sale el extremo curvado,
    que es el rasgo de la propiedad. `inset` desplaza el contorno hacia dentro (negativo, hacia fuera) y
    sirve para apilar losas, forrar los extremos con vidrio o construir barandillas.
    """
    w = HALF_W - inset
    d = HALF_D - inset
    rf = R_FRONT - inset
    rb = R_BACK - inset
    points = [(-(w - rf), -d), (w - rf, -d)]
    cx, cy = w - rf, -d + rf
    for k in range(1, ARC_SEG + 1):
        angle = math.radians(-90.0 + 90.0 * k / ARC_SEG)
        points.append((cx + rf * math.cos(angle), cy + rf * math.sin(angle)))
    points.append((w, d - rb))
    cx, cy = w - rb, d - rb
    for k in range(1, ARC_SEG + 1):
        angle = math.radians(90.0 * k / ARC_SEG)
        points.append((cx + rb * math.cos(angle), cy + rb * math.sin(angle)))
    points.append((-(w - rb), d))
    cx, cy = -(w - rb), d - rb
    for k in range(1, ARC_SEG + 1):
        angle = math.radians(90.0 + 90.0 * k / ARC_SEG)
        points.append((cx + rb * math.cos(angle), cy + rb * math.sin(angle)))
    points.append((-w, -d + rf))
    cx, cy = -(w - rf), -d + rf
    for k in range(1, ARC_SEG):
        angle = math.radians(180.0 + 90.0 * k / ARC_SEG)
        points.append((cx + rf * math.cos(angle), cy + rf * math.sin(angle)))
    return points


def cycle(start, total):
    """Índices consecutivos del contorno, dando la vuelta."""
    return [(start + k) % len(plan(0.0)) for k in range(total)]


def prism(name, points, z0, z1, mat):
    """Losa cerrada: el contorno de `plan` extruido de z0 a z1. Sustituye a la caja en el cuerpo curvo."""
    n = len(points)
    verts = [(x, y, z0) for x, y in points] + [(x, y, z1) for x, y in points]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if mat:
        obj.data.materials.append(mat)
    select_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def shell(name, indices, z0, z1, mat, out=-0.3, inn=0.2):
    """Costra curva entre dos contornos desplazados: el forro de vidrio de un extremo."""
    outer = [plan(out)[i] for i in indices]
    inner = [plan(inn)[i] for i in indices]
    return prism(name, outer + list(reversed(inner)), z0, z1, mat)


def cylinder(name, radius, depth, location, mat, verts=8, caps=True):
    """Cilindro vertical: taburetes de la terraza."""
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


def cone(name, radius, depth, location, mat, verts=8):
    """Cono de base poligonal: el remate de oro de la torre."""
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


def vertical_sign(text, size, x, y, z_top, step, mat, depth):
    """Rótulo de palo: una letra debajo de otra, mirando a la calle."""
    return [letters(char, size, (x, y, z_top - order * step), mat, depth) for order, char in enumerate(text)]


def build_body(M):
    """Nivel 0: el centro comercial. Arquería de tiendas, caliza, dos bandas de vidrio azul y terraza
    abierta recortada en la última planta, con barandilla, suelo de madera y jardineras."""
    parts = []

    # Planta baja con huecos de verdad: arquería continua de vidrio y portalón de 9 × 7,4.
    ground = prism("ground", plan(0.0), 0.0, Z_GROUND, M["limestone"])
    perforate(
        ground,
        [
            box("arcade_cut", (22.4, 2.0, ARCADE_Z[1] - ARCADE_Z[0]), (0.0, -9.2, (ARCADE_Z[0] + ARCADE_Z[1]) / 2)),
            box("portal_cut", (PORTAL_W, 4.4, PORTAL_H + 0.3), (0.0, -8.0, (PORTAL_H - 0.3) / 2)),
        ],
    )
    parts.append(ground)

    # Vidrio de la arquería, al fondo del hueco, con montantes de acero y zócalo de caliza.
    for side in (-1, 1):
        parts.append(box("arcade_glass", (6.5, 0.12, 5.0), (side * 7.85, ARCADE_BACK - 0.1, 3.1), M["glass"]))
        for x in (side * 5.6, side * 8.6):
            parts.append(box("mullion", (0.16, 0.24, 5.0), (x, ARCADE_BACK - 0.22, 3.1), M["metal_acero"]))

    # Zaguán del portalón: vidrio al fondo, tres montantes y el marco de acero en la embocadura.
    parts.append(box("portal_glass", (PORTAL_W - 0.5, 0.14, PORTAL_H - 0.5), (0.0, PORTAL_BACK - 0.5, (PORTAL_H - 0.5) / 2), M["glass"]))
    for x in (-2.9, 0.0, 2.9):
        parts.append(box("portal_mullion", (0.16, 0.2, PORTAL_H - 0.5), (x, PORTAL_BACK - 0.58, (PORTAL_H - 0.5) / 2), M["metal_acero"]))
    for x in (-PORTAL_W / 2 + 0.1, PORTAL_W / 2 - 0.1):
        parts.append(box("portal_jamb", (0.26, 0.5, PORTAL_H), (x, FRONT - 0.15, PORTAL_H / 2), M["metal_acero"]))
    parts.append(box("portal_head", (PORTAL_W + 0.2, 0.5, 0.3), (0.0, FRONT - 0.15, PORTAL_H - 0.05), M["metal_acero"]))

    # Portal de caliza en voladizo: enmarca la entrada y la separa de los escaparates.
    for x in (-PORTAL_W / 2 - 0.25, PORTAL_W / 2 + 0.25):
        parts.append(box("portal_pier", (0.5, 0.45, PORTAL_H + 0.1), (x, FRONT - 0.15, (PORTAL_H + 0.1) / 2), M["limestone"]))
    parts.append(box("portal_lintel", (PORTAL_W + 1.5, 0.45, 0.45), (0.0, FRONT - 0.15, PORTAL_H + 0.4), M["limestone"]))

    # Cornisa de caliza: la banda del rótulo vuela 0,18 sobre la planta baja.
    parts.append(prism("fascia", plan(-0.18), Z_GROUND, Z_FASCIA, M["limestone"]))

    # Dos bandas de vidrio azul reflectivo, metidas 0,55 bajo la caliza: sombra de verdad, no una pegatina.
    parts.append(prism("rib1", plan(0.55), Z_RIB1[0], Z_RIB1[1], M["glass"]))
    parts.append(prism("mid", plan(0.0), Z_MID[0], Z_MID[1], M["limestone"]))
    parts.append(prism("rib2", plan(0.55), Z_RIB2[0], Z_RIB2[1], M["glass"]))

    # Última planta: masa hasta 30.5 y, encima, la terraza-bar abierta con su antepecho de caliza.
    parts.append(prism("top", plan(0.0), Z_TERRACE, Z_TOP, M["limestone"]))

    # Terraza: entablado de madera, antepecho perimetral, vegetación y vidrio de la última planta.
    parts.append(box("deck", (24.0, 13.0, 0.25), (0.0, -1.5, Z_TOP + 0.125), M["wood"]))
    parts.append(shell("parapet", cycle(0, len(plan(0.0))), Z_TOP - 0.02, Z_TOP + 0.8, M["limestone"], out=0.0, inn=0.5))
    for x in (-7.0, 0.0, 7.0):
        parts.append(box("planter", (1.5, 1.1, 0.7), (x, -6.6, Z_TOP + 0.6), M["limestone"]))
        parts.append(box("planter_grass", (1.25, 0.85, 0.55), (x, -6.6, Z_TOP + 1.25), M["grass"]))

    # Rótulo: placa de pizarra sobre la cornisa y CACIQUE en letras de caliza, por encima del portalón.
    parts.append(box("sign_plate", (14.5, 0.5, 2.9), (0.0, FRONT - 0.33, SIGN_Z), M["slate"]))
    parts.append(fit_width(letters("CACIQUE", 2.3, (0.0, FRONT - 0.6, SIGN_Z), M["limestone"], depth=0.2), 13.2))
    return parts


def build_marquesina(M):
    """Nivel 1: marquesina de acero colgada de la fachada, sobre el portalón y bajo la cornisa."""
    parts = []
    parts.append(box("marquee", (11.4, 1.0, 0.22), (0.0, FRONT - 0.46, 8.32), M["metal_acero"]))
    parts.append(box("marquee_edge", (11.8, 0.14, 0.44), (0.0, FRONT - 0.89, 8.19), M["metal_acero"]))
    parts.append(box("marquee_soffit", (11.0, 0.9, 0.12), (0.0, FRONT - 0.44, 8.18), M["limestone"]))
    for side in (-1, 1):
        tie = box("tie", (0.12, 1.5, 0.12), (side * 4.6, FRONT - 0.42, 9.2), M["metal_acero"])
        tie.rotation_euler = (math.radians(-52), 0, 0)
        parts.append(tie)
    return parts


def build_bow(M):
    """Nivel 2: los dos extremos se forran de vidrio azul de la cornisa a la terraza. El casco del
    crucero se lee de lejos sin leer el rótulo."""
    parts = []
    for indices in (cycle(1, 6), cycle(16, 5)):
        parts.append(shell("bow_glass", indices, 8.85, 24.18, M["glass"], out=-0.3, inn=0.2))
        for z in (12.8, 18.4, 19.8):
            parts.append(shell("bow_band", indices, z - 0.09, z + 0.09, M["metal_acero"], out=-0.38, inn=0.12))
    return parts


def build_terrace_bar(M):
    """Nivel 3: terraza-bar sobre la cubierta. La pérgola cambia la silueta por encima de la cornisa."""
    deck = Z_TOP + 0.25
    parts = []
    for x in (-8.4, 8.4):
        for y in (-8.3, -4.4):
            parts.append(box("pergola_post", (0.24, 0.24, 34.3 - deck), (x, y, (deck + 34.3) / 2), M["metal_acero"]))
    for y in (-8.3, -4.4):
        parts.append(box("pergola_beam", (17.8, 0.3, 0.34), (0.0, y, 34.47), M["metal_acero"]))
    for x in (-6.3, -3.15, 0.0, 3.15, 6.3):
        parts.append(box("pergola_rib", (0.22, 4.1, 0.14), (x, -6.35, 34.71), M["metal_acero"]))
    parts.append(box("pergola_canvas", (7.2, 3.9, 0.08), (-3.3, -6.35, 34.82), M["fabric_rojo"]))

    # Barra de madera, taburetes y jardineras: lo que hace que la terraza sea un bar.
    parts.append(box("bar", (6.4, 1.2, 1.15), (3.2, -5.2, deck + 0.575), M["wood"]))
    parts.append(box("bar_back", (6.4, 0.4, 0.35), (3.2, -4.5, deck + 1.3), M["wood"]))
    for x in (0.8, 2.4, 4.0, 5.6):
        parts.append(cylinder("stool", 0.34, 0.95, (x, -6.25, deck + 0.475), M["wood"], 8, True))
    for side in (-1, 1):
        parts.append(box("bar_planter", (1.2, 1.2, 0.7), (side * 10.4, -7.4, deck + 0.35), M["limestone"]))
        parts.append(box("bar_hedge", (1.0, 1.0, 0.45), (side * 10.4, -7.4, deck + 0.925), M["grass"]))

    # El nombre, en letras menores, colgado de la viga de la pérgola.
    parts.append(box("terrace_sign", (4.6, 0.22, 0.9), (0.0, -8.45, 33.85), M["slate"]))
    parts.append(fit_width(letters("CACIQUE", 0.6, (0.0, -8.56, 33.85), M["limestone"], depth=0.1), 4.2))
    return parts


def build_pavilion(M):
    """Nivel 4: pabellón anexo de tiendas, retranqueado sobre la cubierta del fondo."""
    parts = []
    parts.append(box("pavilion", (16.0, 6.0, 4.6), (0.0, 5.4, 32.8), M["limestone"]))
    parts.append(box("pavilion_glass", (15.4, 0.14, 2.0), (0.0, 2.38, 33.5), M["glass"]))
    parts.append(box("pavilion_cornice", (16.6, 6.6, 0.28), (0.0, 5.4, 35.24), M["metal_acero"]))
    return parts


def build_tower(M):
    """Nivel 5: torre del rótulo en el rincón del fondo de la cubierta, con el nombre en vertical y remate
    de oro."""
    cx, cy = 11.0, 5.0
    parts = []
    parts.append(box("tower", (5.2, 5.2, 12.7), (cx, cy, 36.85), M["limestone"]))
    for z in (31.0, 42.6):
        parts.append(box("tower_band", (5.7, 5.7, 0.24), (cx, cy, z), M["metal_acero"]))
    parts.append(box("tower_blade", (3.0, 0.28, 9.6), (cx, cy - 2.74, 37.3), M["slate"]))
    for letter in vertical_sign("CACIQUE", 1.15, cx, cy - 2.9, 41.3, 1.36, M["limestone"], 0.16):
        parts.append(letter)
    parts.append(box("tower_collar", (5.6, 5.6, 0.3), (cx, cy, 43.35), M["metal_oro"]))
    parts.append(cone("spire", 2.5, 2.5, (cx, cy, 44.75), M["metal_oro"], 8))
    return parts


def group(level, parts, store):
    """Une las piezas de un nivel en una malla por material y color. En Roblox cada malla lleva un material."""
    layer = "body" if level == 0 else f"addon{level}"
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        rbx, suffix, rgb = RBX[key]
        name = f"cacique_{layer}_{rbx.lower()}{suffix}"
        if len(members) == 1:
            # Unir una sola malla avisa «No mesh data to join»: se aplica la transformada y ya está.
            mesh = members[0]
            select_only(mesh)
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            mesh.name = name
            origin_at_zero(mesh)
        else:
            for member in members:
                select_only(member)
                bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            mesh = join(members, name)
        uv_unwrap(mesh)
        materials = {m.name for m in mesh.data.materials if m is not None}
        if len(materials) != 1:
            raise RuntimeError(f"{name} tiene {len(materials)} materiales")
        store.append({"key": name, "level": level, "material": rbx, "rgb": rgb, "obj": mesh})


def origin_at_zero(obj):
    select_only(obj)
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")


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
            box("slot_edge", (0.5, SLOT_DEPTH, 0.05), (x + sign * SLOT_LENGTH / 2, SLOT_SIDE, 0.035), M["dark"])
            box("slot_edge", (SLOT_LENGTH, 0.5, 0.05), (x, SLOT_SIDE + sign * SLOT_DEPTH / 2, 0.035), M["dark"])
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

    # Ficha de referencia (caja oscura 8 × 4 × 5, sin taxi) y figura de 6 para la escala.
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
    builders = {1: build_marquesina, 2: build_bow, 3: build_terrace_bar, 4: build_pavilion, 5: build_tower}
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

    # LOD1 con el conjunto entero, al 50 % como los demás edificios, y en una sola malla con un material.
    lod = lod_of(objects, "cacique_LOD1")
    lod_tris = count(lod)
    lod.data.materials.clear()
    lod.data.materials.append(M["limestone"])
    for polygon in lod.data.polygons:
        polygon.material_index = 0

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "cacique_LOD1.fbx")

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
    print("CACIQUE_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if levels["0"]["limites"]["alto_maximo_sobre_suelo"] > BODY_LIMIT:
        raise RuntimeError(f"El nivel 0 llega a {levels['0']['limites']['alto_maximo_sobre_suelo']}, más de {BODY_LIMIT}")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] > MAX_HEIGHT + 0.001:
        raise RuntimeError(f"El nivel 5 pasa de {MAX_HEIGHT}")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "cacique.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["slate"], "gold": M["metal_oro"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -192.0, 84.0), (0.0, 24.0, 20.0), 33), f"{RENDER_SUBDIR}/cacique-niveles.png")

    # Comparación: nivel 0 con la figura de 6 delante de la puerta, y los bloques de 13 y 24.
    hide_all()
    box("ground", (220, 90, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], 0.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (-36, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (36, 0, 12.0), M["block"])
    box("avatar_ref", (1.6, 1.2, 6.0), (6.4, -11.0, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -120.0, 36.0), (0.0, 0.0, 13.0), 36), f"{RENDER_SUBDIR}/cacique-comparacion.png")
    print("CACIQUE_DONE")


if __name__ == "__main__":
    main()

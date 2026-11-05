"""Tajamar: propiedad de Blanca (Cumbre Blanca), modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de 27 (la torre alta; las demás bajan hasta 15) y cinco añadidos que se
suman: acceso y plaza, jardines y caminos, torres nuevas retranqueadas, pabellón común y torre del depósito con
remate de cobre. El bosque de torres de ladrillo de alturas variadas alrededor de una plaza común es el rasgo
del edificio: la densidad de torres, no una torre única. Sigue el método de barberia-morro.py: una malla por
material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/blanca/:
  tajamar.blend                 escena de revisión (no se versiona)
  tajamar/tajamar_<pieza>_<material>.fbx y tajamar_LOD1.fbx
  tajamar/stats.json            triángulos por pieza y nivel, límites y materiales
Y en art/render/blanca/tajamar/: tajamar-niveles.png y tajamar-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/blanca/tajamar.py
"""

import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "tajamar")
RENDER_SUBDIR = "blanca/tajamar"
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
BODY_H = 27.0  # masa principal: la torre del fondo
GATE_H = 12.6  # bloque de acceso, dos plantas de caliza
GATE_FRONT = -2.6  # la plaza queda por delante de la fachada del bloque
GATE_HALF = 5.4
PORTAL_W = 8.4
PORTAL_H = 7.4  # portalón: más alto que cualquier figura de 6
SIGN_Z = 10.6
SIGN_W = 9.6
SIGN_MAX_W = 8.8
SIGN_TEXT = "TAJAMAR"
SIGN_SIZE = 1.7
BAND_H = 2.3  # alto del ventanal en banda
BAND_INSET = 0.85  # retranqueo lateral de la banda respecto al canto de la torre
BAND_CUT = 0.75  # fondo del hueco: hay ladrillo detrás, no calado
BAND_BASE = 4.4  # primera banda, por encima de la planta baja
BAND_TOP = 1.4  # aire bajo la cornisa
COURT_Y0 = -8.98  # plazoleta interior, por detrás de la línea de fachada
COURT_Y1 = -2.4
LEVEL0_MAX = 32.0  # el nivel 0 completo no pasa de aquí
MAX_HEIGHT = 46.0
TRIANGLE_BUDGET = 3000
CINE_LUX_L5_TRIANGLES = 3042
ZONE_RGB = "E7E5E4"  # blanco hueso, solo en la casilla pintada de la escena de render

# Torres del cuerpo: x0, x1, y0, y1, alto, bandas de ventanal, alfeizar.
# Cuatro torres delanteras con la plaza en medio, dos en la fila media y la alta al fondo.
TOWERS = [
    (-15.9, -10.3, -9.0, -3.0, 18.5, 3, True),
    (-8.8, -5.4, -9.0, -3.0, 15.0, 2, True),
    (5.4, 8.8, -9.0, -3.0, 16.5, 2, True),
    (10.3, 15.9, -9.0, -3.0, 20.0, 3, True),
    (-13.6, -6.2, -1.4, 3.6, 24.0, 4, True),
    (6.2, 13.6, -1.4, 3.6, 21.0, 3, True),
    (-4.6, 4.6, 1.4, 8.9, BODY_H, 5, True),
]

# Añadido 3: dos torres nuevas, retranqueadas en el fondo, que suben la silueta.
NEW_TOWERS = [
    (-15.4, -9.6, 4.0, 8.9, 30.5, 5, False),
    (9.6, 15.4, 4.0, 8.9, 28.0, 4, False),
]

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
AVATAR = (1.6, 1.2, 6.0)  # la figura de 6 contra la que se mide la puerta

# Material de Roblox, sufijo de color y RGB de cada material de Blender.
RBX = {
    "brick": ("Brick", "", "B0664A"),
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "metal_acero": ("Metal", "_acero", "A8AEB4"),
    "metal_oro": ("Metal", "_oro", "C9A227"),
    "wood": ("Wood", "", "6B4A2E"),
    "grass": ("Grass", "", "4B6B3A"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.4, 0.9),
        "metal_oro": flat("metal_oro", "C9A227", 0.3, 0.9),
        "wood": flat("wood", "6B4A2E", 0.7),
        "grass": flat("grass", "4B6B3A", 0.9),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", ZONE_RGB, 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "5E646C", 0.8),
    }


def slab(name, x0, x1, y0, y1, z0, z1, mat=None):
    """Caja a partir de sus límites: se lee mejor que centro y tamaño. Ordena los extremos."""
    x0, x1 = min(x0, x1), max(x0, x1)
    y0, y1 = min(y0, y1), max(y0, y1)
    z0, z1 = min(z0, z1), max(z0, z1)
    return box(name, (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), mat)


def cylinder(name, radius, depth, location, mat, verts=12, caps=True):
    """Cilindro vertical: cisterna del cuerpo y depósito del añadido 5."""
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
    """Cono vertical: remate de cobre de la torre del depósito."""
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=location
    )
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


def band_centres(h, bands):
    """Centros de las bandas de ventanal, repartidos entre la planta baja y la cornisa."""
    usable = h - BAND_BASE - BAND_TOP
    step = usable / bands
    return [round(BAND_BASE + step * (k + 0.5), 2) for k in range(bands)]


def tower(parts, M, x0, x1, y0, y1, h, bands, sills=True):
    """Torre de ladrillo: cuerpo con huecos de verdad, bandas de vidrio, zócalo, cornisa y cubierta plana."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    w, d = x1 - x0, y1 - y0
    centres = band_centres(h, bands)

    body = box("tower", (w, d, h), (cx, cy, h / 2), M["brick"])
    cuts = [box("band_cut", (w - 2 * BAND_INSET, BAND_CUT, BAND_H), (cx, y0 + BAND_CUT / 2 - 0.15, z)) for z in centres]
    perforate(body, cuts)
    parts.append(body)

    pane_w = w - 2 * BAND_INSET - 0.3
    for z in centres:
        parts.append(box("pane", (pane_w, 0.12, BAND_H - 0.16), (cx, y0 + 0.38, z), M["glass"]))
        if sills:
            # Alfeizar de caliza: sube 0,03 dentro del hueco para no compartir cara con el fondo del corte.
            parts.append(box("sill", (pane_w + 0.5, 0.42, 0.24), (cx, y0 + 0.12, z - BAND_H / 2 - 0.09), M["limestone"]))

    parts.append(box("plinth", (w + 0.3, d + 0.3, 1.1), (cx, cy, 0.55), M["limestone"]))
    parts.append(box("crown", (w + 0.3, d + 0.3, 0.55), (cx, cy, h - 0.325), M["limestone"]))
    parts.append(box("deck", (w - 0.7, d - 0.7, 0.32), (cx, cy, h - 0.04), M["slate"]))


def build_body(M):
    """Nivel 0: bosque de torres, bloque de acceso con portalón y placa, y plazoleta interior."""
    parts = []
    for x0, x1, y0, y1, h, bands, sills in TOWERS:
        tower(parts, M, x0, x1, y0, y1, h, bands, sills)

    # Bloque de acceso: dos plantas de caliza entre las torres delanteras, con el nombre encima.
    gate = slab("gate", -GATE_HALF, GATE_HALF, GATE_FRONT, GATE_FRONT + 4.4, 0.0, GATE_H, M["limestone"])
    perforate(
        gate,
        [box("portal_cut", (PORTAL_W, 1.5, PORTAL_H + 0.5), (0, GATE_FRONT + 0.6, (PORTAL_H - 0.5) / 2))],
    )
    parts.append(gate)

    # Portalón: umbral, vidrio retrancado y cerco de acero.
    parts.append(slab("threshold", -4.4, 4.4, GATE_FRONT - 0.25, GATE_FRONT + 1.35, 0.17, 0.49, M["limestone"]))
    parts.append(slab("portal_glass", -4.0, 4.0, GATE_FRONT + 0.88, GATE_FRONT + 1.02, 0.4, 7.1, M["glass"]))
    for sx in (-1, 1):
        parts.append(
            slab(
                "portal_jamb",
                sx * (PORTAL_W / 2) - 0.16,
                sx * (PORTAL_W / 2) + 0.16,
                GATE_FRONT - 0.325,
                GATE_FRONT + 0.225,
                0.0,
                PORTAL_H,
                M["metal_acero"],
            )
        )
    parts.append(
        slab("portal_head", -4.35, 4.35, GATE_FRONT - 0.325, GATE_FRONT + 0.225, PORTAL_H, PORTAL_H + 0.4, M["metal_acero"])
    )
    parts.append(slab("portal_mullion", -0.1, 0.1, GATE_FRONT + 0.8, GATE_FRONT + 1.2, 0.4, 6.8, M["metal_acero"]))

    # Placa de pizarra con TAJAMAR en letras de caliza, por encima del portalón y del toldo.
    parts.append(slab("sign_plate", -SIGN_W / 2, SIGN_W / 2, GATE_FRONT - 0.37, GATE_FRONT + 0.03, SIGN_Z - 1.2, SIGN_Z + 1.2, M["slate"]))
    parts.append(
        fit_width(
            letters(SIGN_TEXT, SIGN_SIZE, (0, GATE_FRONT - 0.44, SIGN_Z), M["limestone"], depth=0.18),
            SIGN_MAX_W,
        )
    )

    # Cornisa y cubierta del bloque de acceso.
    parts.append(slab("gate_coping", -GATE_HALF - 0.15, GATE_HALF + 0.15, GATE_FRONT - 0.15, GATE_FRONT + 4.55, 12.35, 12.8, M["limestone"]))
    parts.append(slab("gate_deck", -GATE_HALF + 0.3, GATE_HALF - 0.3, GATE_FRONT + 0.35, GATE_FRONT + 4.05, 12.75, 12.95, M["slate"]))

    # Plazoleta interior: pavimento de caliza.
    parts.append(slab("court_pave", -GATE_HALF - 0.1, GATE_HALF + 0.1, COURT_Y0, COURT_Y1, 0.0, 0.22, M["limestone"]))

    # Casetas de escalera, ventilaciones y cisterna: la cubierta del nivel 0 no es una losa lisa.
    parts.append(box("stair_head", (2.4, 2.0, 1.9), (-13.6, -5.0, 19.35), M["brick"]))
    parts.append(cylinder("cistern", 1.0, 1.8, (13.0, -5.2, 20.8), M["metal_acero"], 10, True))
    parts.append(box("stair_head", (2.4, 2.0, 1.9), (-11.0, 1.0, 24.85), M["brick"]))
    parts.append(box("roof_vent", (1.2, 1.2, 0.9), (10.4, 1.0, 21.35), M["brick"]))
    parts.append(box("roof_vent", (1.4, 1.4, 1.0), (3.2, 8.0, 27.4), M["brick"]))
    return parts


def build_access(M):
    """Nivel 1: acceso y plaza. Marquesina sobre el portalón, jardineras y umbral."""
    parts = []

    # Marquesina de caliza con canto de acero, sobre el portalón y por debajo del rótulo.
    parts.append(slab("canopy", -5.0, 5.0, -5.2, GATE_FRONT + 0.1, 8.35, 8.67, M["limestone"]))
    parts.append(box("canopy_edge", (10.2, 0.22, 0.52), (0, -5.25, 8.41), M["metal_acero"]))
    for sx in (-1, 1):
        parts.append(box("canopy_post", (0.32, 0.32, 8.25), (sx * 4.5, -4.9, 4.29), M["metal_acero"]))

    # Jardineras de caliza con seto, a los lados de la plaza.
    for sx in (-1, 1):
        parts.append(box("planter", (1.0, 2.2, 0.8), (sx * 4.8, -7.6, 0.57), M["limestone"]))
        parts.append(box("planter_hedge", (0.8, 2.0, 0.5), (sx * 4.8, -7.6, 1.2), M["grass"]))

    # Peldaño del umbral, más bajo que el pavimento de la plaza.
    parts.append(slab("door_step", -4.6, 4.6, GATE_FRONT - 0.9, GATE_FRONT + 0.2, 0.17, 0.42, M["limestone"]))
    return parts


def build_gardens(M):
    """Nivel 2: jardines y caminos. Parterres de hierba, setos y caminos de pizarra en la plaza."""
    parts = []
    for sx in (-1, 1):
        parts.append(slab("bed", sx * 2.9, sx * 5.1, -6.6, -3.2, 0.17, 0.42, M["grass"]))
        parts.append(slab("bed_hedge", sx * 2.9, sx * 3.4, -6.6, -3.2, 0.42, 1.0, M["grass"]))
        parts.append(slab("path_edge", sx * 2.4, sx * 2.9, -8.9, -3.2, 0.22, 0.28, M["slate"]))
    parts.append(slab("path_cross", -5.2, 5.2, -3.45, -3.0, 0.22, 0.28, M["slate"]))
    return parts


def build_new_towers(M):
    """Nivel 3: dos torres nuevas, retranqueadas en el fondo. Cambian la silueta del conjunto."""
    parts = []
    for x0, x1, y0, y1, h, bands, sills in NEW_TOWERS:
        tower(parts, M, x0, x1, y0, y1, h, bands, sills)
    return parts


def build_pavilion(M):
    """Nivel 4: pabellón común retranqueado en la cubierta del bloque, con terraza, barandilla y pérgola."""
    parts = []

    # Barandilla de acero en el borde de la terraza, sobre la cornisa del bloque de acceso.
    parts.append(box("terrace_rail", (10.2, 0.14, 0.14), (0, -2.2, 13.92), M["metal_acero"]))
    parts.append(box("terrace_rail", (10.2, 0.14, 0.14), (0, -2.2, 13.42), M["metal_acero"]))
    for sx in (-1, 1):
        parts.append(box("terrace_post", (0.14, 0.14, 1.1), (sx * 5.0, -2.2, 13.4), M["metal_acero"]))

    # Pabellón: pilares de caliza, caja de vidrio retrancada y pérgola de madera que vuela sobre la terraza.
    for sx in (-1, 1):
        for y in (-1.3, 1.3):
            parts.append(box("pavilion_pier", (0.5, 0.5, 2.6), (sx * 3.5, y, 14.15), M["limestone"]))
    parts.append(slab("pavilion_glass", -3.4, 3.4, -1.25, 1.25, 12.9, 15.35, M["glass"]))
    for k in range(5):
        parts.append(box("pavilion_slat", (8.2, 0.36, 0.2), (0, -1.7 + k * 0.75, 15.72), M["wood"]))
    for y in (-1.6, 1.4):
        parts.append(box("pavilion_beam", (8.4, 0.3, 0.26), (0, y, 15.52), M["wood"]))
    return parts


def build_water_tower(M):
    """Nivel 5: torre del depósito sobre la torre alta, con remate de cobre. Es el remate del conjunto."""
    parts = []
    cx, cy = 0.0, 4.9

    # Patas y arriostramientos de acero, apoyados en la cubierta del cuerpo.
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box("deposit_leg", (0.42, 0.42, 6.5), (cx + sx * 2.0, cy + sy * 2.0, 30.15), M["metal_acero"]))
    for z in (29.6, 32.2):
        for sy in (-1, 1):
            parts.append(box("deposit_ring", (4.4, 0.3, 0.3), (cx, cy + sy * 2.0, z), M["metal_acero"]))
        for sx in (-1, 1):
            parts.append(box("deposit_ring", (0.3, 4.4, 0.3), (cx + sx * 2.0, cy, z), M["metal_acero"]))

    # Depósito de acero y remate de cobre.
    parts.append(cylinder("deposit_tank", 3.6, 7.0, (cx, cy, 36.9), M["metal_acero"], 12, True))
    parts.append(cylinder("deposit_band", 3.7, 0.3, (cx, cy, 36.2), M["metal_acero"], 12, True))
    parts.append(cone("deposit_crown", 4.1, 4.8, (cx, cy, 42.8), M["metal_oro"], 12))
    parts.append(cylinder("deposit_finial", 0.22, 0.8, (cx, cy, 45.6), M["metal_oro"], 8, True))
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
        name = f"tajamar_{layer}_{rbx.lower()}{suffix}"
        if len(members) == 1:
            mesh = members[0]
            select_only(mesh)
            origin_at_zero(mesh)
            mesh.name = name
        else:
            mesh = join(members, name)
        uv_unwrap(mesh)
        materials = {m.name for m in mesh.data.materials if m is not None}
        if len(materials) != 1:
            raise RuntimeError(f"{name} tiene {len(materials)} materiales")
        store.append({"key": name, "level": level, "material": rbx, "rgb": rgb, "obj": mesh})


def bounds(objects):
    """Límites en studs: ancho (x), fondo (y) y alto (z), con las mallas en coordenadas de escena."""
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

    # Ficha de referencia (caja oscura 8 × 4 × 5) y figura de 6 delante de la plazoleta, para leer la puerta.
    box("ficha_ref", (8.0, 4.0, 5.0), (-2.5 * SPACING, SLOT_SIDE, 2.5), M["dark"])
    box("avatar_ref", AVATAR, (-2.5 * SPACING + 3.4, lot_y - 6.4, 3.2), M["avatar"])
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
    builders = {1: build_access, 2: build_gardens, 3: build_new_towers, 4: build_pavilion, 5: build_water_tower}
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
    lod = lod_of(objects, "tajamar_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "tajamar_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "cuerpo": {
            "alto_masa_principal": BODY_H,
            "alto_nivel_0": levels["0"]["limites"]["alto_maximo_sobre_suelo"],
            "limite_nivel_0": LEVEL0_MAX,
            "altura_maxima_permitida": MAX_HEIGHT,
        },
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
    print("TAJAMAR_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if levels["0"]["limites"]["alto_maximo_sobre_suelo"] > LEVEL0_MAX:
        raise RuntimeError(f"El nivel 0 llega a {levels['0']['limites']['alto_maximo_sobre_suelo']} y no debe pasar de {LEVEL0_MAX}")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] > MAX_HEIGHT:
        raise RuntimeError(f"Altura total de {levels['5']['limites']['alto_maximo_sobre_suelo']} supera {MAX_HEIGHT}")
    for level in range(6):
        limits = levels[str(level)]["limites"]
        if limits["frente"] < -10.0:
            raise RuntimeError(f"nivel {level}: el frente llega a {limits['frente']} y no debe pasar de -10")
        if max(abs(limits["x_minimo"]), abs(limits["x_maximo"])) > 18.0:
            raise RuntimeError(f"nivel {level}: se sale a lo ancho ({limits['x_minimo']} a {limits['x_maximo']})")
        if limits["fondo_maximo"] > 13.0:
            raise RuntimeError(f"nivel {level}: el fondo llega a {limits['fondo_maximo']}")

    # Escena de revisión y renders, con las mallas de origen ocultas.
    for obj in objects + [lod]:
        obj.hide_render = True
        obj.hide_viewport = True
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "tajamar.blend"))

    markers = {
        kind: build_marker(
            kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["metal_acero"], "gold": M["metal_oro"]}
        )
        for kind in ("house", "hotel", "tower")
    }
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -190.0, 78.0), (0.0, 24.0, 14.0), 30), f"{RENDER_SUBDIR}/tajamar-niveles.png")

    # Comparación: nivel 0 frente a los bloques de Bodega (13) y Cine Lux (24), con la figura de 6 delante de
    # la fachada y junto al portalón, que es lo que permite juzgar la puerta.
    hide_all()
    box("ground", (220, 60, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -38.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (-4.0, 0.0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (30.0, 0.0, 12.0), M["block"])
    box("avatar_ref", AVATAR, (-34.0, -7.6, 3.22), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -105.0, 24.0), (-4.0, 0.0, 11.0), 36), f"{RENDER_SUBDIR}/tajamar-comparacion.png")
    print("TAJAMAR_DONE")


if __name__ == "__main__":
    main()

"""Barbería Morro: propiedad de la zona Cobre (la más barata del tablero), modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base. Cuerpo de 14 (entre la Bodega, 13, y el Cine Lux, 24) y cinco añadidos que se suman.
Sigue el método de build_cine_lux.py y build_slice_props.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/cobre/:
  barberia-morro.blend                 escena de revisión (no se versiona)
  barberia-morro/morro_<pieza>_<material>.fbx y morro_LOD1.fbx
  barberia-morro/stats.json            triángulos por pieza y nivel, límites y materiales
Y en art/render/cobre/barberia-morro/: barberia-morro-niveles.png y barberia-morro-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/cobre/barberia-morro.py
"""

import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "barberia-morro")
RENDER_SUBDIR = "cobre/barberia-morro"
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
DOOR_W = 2.4
DOOR_TOP = 7.2  # claramente más alta que el avatar (6): 1,2 de margen
WIN_Z0 = 1.2
WIN_Z1 = 5.8
WINDOWS = [(-12.6, -3.4), (3.4, 12.6)]  # escaparates a ambos lados de la puerta
POLE_X = -2.3  # poste de barbero en el hueco entre escaparate y puerta
AWNING_SLOPE = 1.08  # longitud del faldón del toldo (0,9 de vuelo y 0,6 de caída)
AWNING_ANGLE = math.atan2(-0.6, -0.9)
PLACA_Z = 8.7

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
    "brick": ("Brick", "", "B0664A"),
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "metal": ("Metal", "", "C97B3A"),
    "wood": ("Wood", "", "5A3A24"),
    "fabric_rojo": ("Fabric", "_rojo", "C4382B"),
    "fabric_blanco": ("Fabric", "_blanco", "EDE5D3"),
    "plastic_rojo": ("SmoothPlastic", "_rojo", "C4382B"),
    "plastic_blanco": ("SmoothPlastic", "_blanco", "F4F4F4"),
    "plastic_azul": ("SmoothPlastic", "_azul", "1F5FA8"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "metal": flat("metal", "C97B3A", 0.3, 0.9),
        "wood": flat("wood", "5A3A24", 0.7),
        "fabric_rojo": flat("fabric_rojo", "C4382B", 0.8),
        "fabric_blanco": flat("fabric_blanco", "EDE5D3", 0.8),
        "plastic_rojo": flat("plastic_rojo", "C4382B", 0.35),
        "plastic_blanco": flat("plastic_blanco", "F4F4F4", 0.35),
        "plastic_azul": flat("plastic_azul", "1F5FA8", 0.35),
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


def cylinder(name, radius, depth, location, mat, verts, caps):
    """Cilindro vertical. Sin tapas en las bandas del poste (van unidas y se ven abiertas)."""
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


def barber_pole(M, parts, x, y, z0, z1, radius, bands, verts):
    """Poste de barbero: bandas en rojo, blanco y azul que se repiten de abajo arriba."""
    colours = ["plastic_rojo", "plastic_blanco", "plastic_azul"]
    step = (z1 - z0) / bands
    for k in range(bands):
        zc = z0 + step * (k + 0.5)
        parts.append(cylinder(f"band{k}", radius, step, (x, y, zc), M[colours[k % 3]], verts, False))


def fit_width(obj, max_width):
    """Reduce el rótulo de forma uniforme si no cabe en la placa."""
    width = obj.dimensions.x
    if width > max_width:
        select_only(obj)
        factor = max_width / width
        obj.scale = (factor, factor, factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def build_body(M):
    """Nivel 0: fachada de ladrillo, escaparates grandes, puerta alta, poste, placa y cornisa de caliza."""
    parts = []
    cuts = [
        box("win_cut", (x1 - x0, 2.5, WIN_Z1 - WIN_Z0), ((x0 + x1) / 2, FRONT + 0.25, (WIN_Z0 + WIN_Z1) / 2))
        for x0, x1 in WINDOWS
    ]
    door_cut = box("door_cut", (DOOR_W, 2.5, DOOR_TOP + 0.5), (0, FRONT + 0.25, (DOOR_TOP - 0.5) / 2))
    wall = box("morro_wall", (WIDTH, DEPTH, 13.2), (0, 0, 6.6), M["brick"])
    perforate(wall, cuts + [door_cut])
    parts.append(wall)

    # Zócalo de caliza, abierto en la puerta.
    plinth = box("plinth", (WIDTH + 0.2, DEPTH, 0.8), (0, 0, 0.4), M["limestone"])
    perforate(plinth, [box("door_cut2", (DOOR_W, 2.5, DOOR_TOP + 0.5), (0, FRONT + 0.25, (DOOR_TOP - 0.5) / 2))])
    parts.append(plinth)
    parts.append(box("cornice", (WIDTH + 0.6, DEPTH, 0.8), (0, 0, 13.6), M["limestone"]))

    for x0, x1 in WINDOWS:
        xc = (x0 + x1) / 2
        # Dos paños de cristal con marco de madera y parteluz.
        for pane_x0, pane_x1 in ((x0 + 0.35, xc - 0.15), (xc + 0.15, x1 - 0.35)):
            parts.append(box("pane", (pane_x1 - pane_x0, 0.1, 3.9), ((pane_x0 + pane_x1) / 2, FRONT + 0.55, 3.5), M["glass"]))
        parts.append(box("frame_top", (x1 - x0, 0.4, 0.35), (xc, FRONT + 0.2, WIN_Z1 - 0.175), M["wood"]))
        parts.append(box("frame_bottom", (x1 - x0, 0.4, 0.35), (xc, FRONT + 0.2, WIN_Z0 + 0.175), M["wood"]))
        parts.append(box("frame_left", (0.35, 0.4, WIN_Z1 - WIN_Z0), (x0 + 0.175, FRONT + 0.2, 3.5), M["wood"]))
        parts.append(box("frame_right", (0.35, 0.4, WIN_Z1 - WIN_Z0), (x1 - 0.175, FRONT + 0.2, 3.5), M["wood"]))
        parts.append(box("mullion", (0.3, 0.4, WIN_Z1 - WIN_Z0), (xc, FRONT + 0.2, 3.5), M["wood"]))
        parts.append(box("sill", (x1 - x0 + 0.8, 0.9, 0.4), (xc, FRONT + 0.45, 1.0), M["limestone"]))

    # Puerta: cristal alto con marco de madera. Mide más que el avatar de 6.
    parts.append(box("door_glass", (DOOR_W - 0.4, 0.1, DOOR_TOP - 0.3), (0, FRONT + 0.55, (DOOR_TOP - 0.3) / 2 + 0.1), M["glass"]))
    parts.append(box("door_jamb_l", (0.2, 0.4, DOOR_TOP), (-DOOR_W / 2 + 0.1, FRONT + 0.2, DOOR_TOP / 2), M["wood"]))
    parts.append(box("door_jamb_r", (0.2, 0.4, DOOR_TOP), (DOOR_W / 2 - 0.1, FRONT + 0.2, DOOR_TOP / 2), M["wood"]))
    parts.append(box("door_head", (DOOR_W, 0.4, 0.3), (0, FRONT + 0.2, DOOR_TOP - 0.15), M["wood"]))

    # Placa de madera con el nombre en letras de cobre, a la altura de la cornisa del escaparate.
    parts.append(box("placa", (16.0, 0.4, 2.2), (0, FRONT + 0.2, PLACA_Z), M["wood"]))
    name = fit_width(letters("BARBERÍA MORRO", 1.0, (0, FRONT - 0.05, PLACA_Z), M["metal"], depth=0.2), 14.0)
    parts.append(name)

    # Poste de barbero junto a la puerta, con sus escuadras de cobre y tapas.
    poste_y = FRONT - 0.45
    barber_pole(M, parts, POLE_X, poste_y, 1.2, 7.2, 0.45, 10, 8)
    parts.append(cylinder("pole_cap_low", 0.55, 0.25, (POLE_X, poste_y, 1.075), M["metal"], 8, True))
    parts.append(cylinder("pole_cap_top", 0.55, 0.25, (POLE_X, poste_y, 7.325), M["metal"], 8, True))
    parts.append(box("pole_arm_low", (0.3, 0.45, 0.3), (POLE_X, FRONT - 0.225, 1.6), M["metal"]))
    parts.append(box("pole_arm_top", (0.3, 0.45, 0.3), (POLE_X, FRONT - 0.225, 6.8), M["metal"]))
    return parts


def build_awning(M):
    """Nivel 1: toldo a rayas sobre los escaparates. Vuela 0,9, sin pasar de la zona de marcadores."""
    parts = []
    for x0, x1 in WINDOWS:
        ax0, ax1 = x0 - 0.2, x1 + 0.2
        n = 5
        w = (ax1 - ax0) / n
        for k in range(n):
            mat = M["fabric_rojo"] if k % 2 == 0 else M["fabric_blanco"]
            xc = ax0 + w * (k + 0.5)
            stripe = box(f"stripe{k}", (w, AWNING_SLOPE, 0.12), (xc, FRONT - 0.45, 6.6), mat)
            stripe.rotation_euler = (AWNING_ANGLE, 0, 0)
            parts.append(stripe)
    return parts


def build_upgrade(M):
    """Nivel 2: mejora de fachada. Pilastras de caliza en las esquinas, remate y marco de cobre a la placa."""
    parts = []
    for side in (-1, 1):
        parts.append(box("pilaster", (0.8, 0.5, 12.4), (side * 15.5, FRONT - 0.05, 7.0), M["limestone"]))
    parts.append(box("coping", (WIDTH + 0.6, DEPTH, 0.3), (0, 0, 14.15), M["metal"]))
    parts.append(box("placa_frame_top", (16.6, 0.3, 0.3), (0, FRONT - 0.15, PLACA_Z + 1.25), M["metal"]))
    parts.append(box("placa_frame_bottom", (16.6, 0.3, 0.3), (0, FRONT - 0.15, PLACA_Z - 1.25), M["metal"]))
    for side in (-1, 1):
        parts.append(box("placa_frame_side", (0.3, 0.3, 2.2), (side * 8.15, FRONT - 0.15, PLACA_Z), M["metal"]))
    return parts


def build_salon(M):
    """Nivel 3: planta de salón retranqueada en el frente. Un único ventanal ancho, no ventanitas de vivienda."""
    parts = []
    parts.append(box("salon", (22.0, 10.0, 5.5), (0, -4.0, 17.05), M["brick"]))
    parts.append(box("salon_glass", (16.0, 0.2, 3.6), (0, FRONT, 17.0), M["glass"]))
    parts.append(box("salon_cornice", (22.4, 10.0, 0.3), (0, -4.0, 19.95), M["limestone"]))
    parts.append(box("salon_roof", (22.2, 9.8, 0.3), (0, -4.0, 20.25), M["slate"]))
    return parts


def build_wing(M):
    """Nivel 4: ampliación en la mitad trasera, más baja que el salón, con chimenea de cobre."""
    parts = []
    parts.append(box("wing", (WIDTH, 8.0, 4.2), (0, 5.0, 16.4), M["brick"]))
    parts.append(box("wing_roof", (WIDTH + 0.2, 8.2, 0.3), (0, 5.0, 18.65), M["slate"]))
    parts.append(box("wing_flue", (0.9, 0.9, 2.0), (12.0, 6.0, 19.8), M["metal"]))
    return parts


def build_crown(M):
    """Nivel 5: torre de caliza sobre el salón y poste gigante de barbero. Remata por encima del Cine Lux."""
    cx, cy = -7.0, -4.0
    parts = []
    parts.append(box("tower", (5.0, 5.0, 5.0), (cx, cy, 22.9), M["limestone"]))
    parts.append(box("tower_band", (5.4, 5.4, 0.4), (cx, cy, 25.6), M["metal"]))
    parts.append(box("tower_cap", (4.6, 4.6, 0.3), (cx, cy, 26.0), M["slate"]))
    barber_pole(M, parts, cx, cy, 26.15, 32.15, 1.2, 12, 10)
    parts.append(cylinder("giant_pole_cap", 1.35, 0.4, (cx, cy, 32.35), M["metal"], 10, True))
    return parts


def group(level, parts, store):
    """Une las piezas de un nivel en una malla por material y color. En Roblox cada malla lleva un material."""
    layer = "body" if level == 0 else f"addon{level}"
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        rbx, suffix, rgb = RBX[key]
        name = f"morro_{layer}_{rbx.lower()}{suffix}"
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

    # Ficha de referencia (caja oscura 8 × 4 × 5, sin taxi) y avatar de 6 de alto para la escala.
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
    builders = {1: build_awning, 2: build_upgrade, 3: build_salon, 4: build_wing, 5: build_crown}
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
    lod = lod_of(objects, "morro_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "morro_LOD1.fbx")

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
    print("BARBERIA_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "barberia-morro.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["slate"], "gold": M["metal"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -190.0, 78.0), (0.0, 22.0, 10.0), 30), f"{RENDER_SUBDIR}/barberia-morro-niveles.png")

    # Comparación: nivel 0 frente a un bloque de Bodega (13) y otro de Cine Lux (24), a la misma distancia.
    hide_all()
    box("ground", (150, 40, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -40.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (40, 0, 12.0), M["block"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -150.0, 30.0), (0.0, 0.0, 9.0), 42), f"{RENDER_SUBDIR}/barberia-morro-comparacion.png")
    print("BARBERIA_DONE")


if __name__ == "__main__":
    main()

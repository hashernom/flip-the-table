"""D.T: torre corporativa de la zona Añil (Mirador Añil), modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el
origen está en el centro de la base. Cuerpo de 28,5 (podio de caliza con el lobby y fuste de muro cortina
de cristal y acero) y cinco añadidos que se suman: marquesina y lobby, aletas, corona de acero, podio
anexo y aguja con remate de oro. Sigue el método de barberia-morro.py: una malla por material y color,
LOD1 con decimado.

Salidas, en art/blender/buildings/anil/:
  d-t.blend                  escena de revisión (no se versiona)
  d-t/dt_<pieza>_<material>.fbx y dt_LOD1.fbx
  d-t/stats.json             triángulos por pieza y nivel, límites y materiales
Y en art/render/anil/d-t/: d-t-niveles.png y d-t-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/anil/d-t.py
"""

import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "d-t")
RENDER_SUBDIR = "anil/d-t"
sys.path.insert(0, SLICE)

import build_cine_lux  # noqa: E402
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

# --- Solar y cuerpo ---------------------------------------------------------------------------
WIDTH = 32.0
DEPTH = 18.0
FRONT = -DEPTH / 2  # el frente da a -Y: -9

PLINTH_H = 0.8
PODIUM_W = 30.0
PODIUM_D = 16.0
PODIUM_H = 9.4
PODIUM_FRONT = -PODIUM_D / 2  # -8

PORTAL_W = 9.0  # portalón del lobby: más alto que la figura de 6
PORTAL_H = 7.4
PORTAL_RECESS = 1.4

BAY_W = 6.0  # dos paños de lobby a los lados del portalón
BAY_H = 6.4
BAY_X = 9.5
BAY_Z0 = PLINTH_H
BAY_RECESS = 0.8

SHAFT_W = 12.0  # fuste esbelto: 12 × 10 sobre un podio de 30 × 16
SHAFT_D = 10.0
SHAFT_FRONT = -SHAFT_D / 2  # -5
SHAFT_Z0 = PODIUM_H
SHAFT_Z1 = 28.5  # masa principal: la altura que manda el encargo

GLASS_Z0 = 10.4  # el muro cortina: huecos de verdad con montantes finos de acero
GLASS_Z1 = 27.4
GLASS_RECESS = 0.5
MULLION = 0.3
CORNER_FRAME = 0.5
FRONT_SLOTS = 4
SIDE_SLOTS = 3

TOP_CORNICE_H = 0.7
TOP_CORNICE_Z0 = SHAFT_Z1 - TOP_CORNICE_H  # 27,8

LANTERN_W = 9.4  # farol de la corona, nivel 0
LANTERN_D = 7.4
LANTERN_Z1 = 32.65
LEVEL0_TOP = 33.35

CROWN_FIN_Z1 = 38.3  # corona de acero, nivel 3
CROWN_TOP = 38.75

TOTAL_HEIGHT = 44.0
LEVEL0_MAX = 33.5

SIGN_Z = 11.8  # placa del monograma sobre el podio, encima de la puerta y de la marquesina
SIGN_PLATE_W = 7.0
SIGN_PLATE_H = 2.8

TRIANGLE_BUDGET = 3000
CINE_LUX_L5_TRIANGLES = 3042
LOD_RATIO = 0.44  # por debajo del 50 % que exige el comprobador

# Escena de revisión (solo render).
FRONT_OFFSET = 2.0
STREET_WIDTH = 34.0
SIDEWALK = 7.0
LOT_DEPTH = 22.0
SPACING = 40.0
TILE_LENGTH = 30.0
TILE_DEPTH = 16.0
TILE_SIDE = 8.0
MARKER_FRONT = -9.5
MARKER_STEP = 4.4
MARKER_ALONG = 11.5

# Material de Roblox, sufijo de color y RGB de cada material de Blender.
RBX = {
    "limestone": ("Limestone", "", "D2C9B4"),
    "glass": ("Glass", "", "2E4A63"),
    "metal": ("Metal", "", "A8AEB4"),
    "metal_oro": ("Metal", "_oro", "C9A227"),
    "metal_anil": ("Metal", "_anil", "4F46E5"),
    "slate": ("Slate", "", "4A4E54"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "metal": flat("metal", "A8AEB4", 0.35, 0.8),
        "metal_oro": flat("metal_oro", "C9A227", 0.3, 0.9),
        "metal_anil": flat("metal_anil", "4F46E5", 0.4, 0.7),
        "slate": flat("slate", "4A4E54", 0.85),
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


def wall_cut(name, size_x, size_z, center_x, y_face, depth, z_center, inward=1.0):
    """Hueco en una fachada paralela a X: arranca 0,1 por fuera y muerde `depth` hacia dentro."""
    center_y = y_face + inward * (depth / 2 - 0.05)
    return box(name, (size_x, depth + 0.1, size_z), (center_x, center_y, z_center))


def wall_cut_x(name, size_y, size_z, center_y, x_face, depth, z_center, inward=1.0):
    """Hueco en una fachada paralela a Y."""
    center_x = x_face + inward * (depth / 2 - 0.05)
    return box(name, (depth + 0.1, size_y, size_z), (center_x, center_y, z_center))


def slot_ranges(span, slots):
    """Reparte `slots` huecos iguales entre dos esquinas de acero, con montantes finos."""
    width = (span - 2 * CORNER_FRAME - (slots - 1) * MULLION) / slots
    ranges = []
    cursor = -span / 2 + CORNER_FRAME
    for _ in range(slots):
        ranges.append((cursor, cursor + width))
        cursor += width + MULLION
    return ranges


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
    """Nivel 0: podio de caliza con el portalón y los dos paños del lobby, fuste de muro cortina con
    montantes de acero, farol de la corona y el monograma D.T sobre placa de caliza."""
    parts = []

    # --- Podio: plinto y cuerpo calados por el portalón y los dos paños del lobby.
    plinth = box("plinth", (WIDTH, DEPTH, PLINTH_H), (0, 0, PLINTH_H / 2), M["limestone"])
    perforate(plinth, [wall_cut("cut_portal_plinth", PORTAL_W, PORTAL_H + 0.25, 0, FRONT, 2.5, PORTAL_H / 2 - 0.1)])
    parts.append(plinth)

    podium = box("podium", (PODIUM_W, PODIUM_D, PODIUM_H - PLINTH_H), (0, 0, (PODIUM_H + PLINTH_H) / 2), M["limestone"])
    cuts = [wall_cut("cut_portal", PORTAL_W, PORTAL_H + 0.25, 0, PODIUM_FRONT, PORTAL_RECESS, PORTAL_H / 2 - 0.1)]
    for side in (-1, 1):
        cuts.append(wall_cut("cut_bay", BAY_W, BAY_H, side * BAY_X, PODIUM_FRONT, BAY_RECESS, BAY_Z0 + BAY_H / 2))
    perforate(podium, cuts)
    parts.append(podium)

    # Cornisa del podio: la terraza desde la que arranca el fuste.
    parts.append(box("podium_cornice", (PODIUM_W + 1.0, PODIUM_D + 1.0, 0.6), (0, 0, PODIUM_H + 0.3), M["limestone"]))

    # --- Portalón: muro de cristal al fondo del porche, montantes y marco de acero.
    porch_back = PODIUM_FRONT + PORTAL_RECESS  # -6,6
    parts.append(box("portal_glass", (PORTAL_W - 0.1, 0.14, PORTAL_H - 0.1), (0, porch_back - 0.08, (PORTAL_H - 0.1) / 2), M["glass"]))
    for x in (-1.6, 1.6):
        parts.append(box("portal_mullion", (0.22, 0.3, PORTAL_H - 0.2), (x, porch_back - 0.15, (PORTAL_H - 0.2) / 2), M["metal"]))
    for side in (-1, 1):
        parts.append(box("portal_jamb", (0.5, 0.6, PORTAL_H + 0.5), (side * (PORTAL_W / 2 + 0.25), PODIUM_FRONT - 0.2, (PORTAL_H + 0.5) / 2), M["metal"]))
    parts.append(box("portal_lintel", (PORTAL_W + 1.5, 0.6, 0.55), (0, PODIUM_FRONT - 0.2, PORTAL_H + 0.25), M["metal"]))

    # --- Paños del lobby: cristal de suelo a dintel, con montante y dintel de acero.
    bay_back = PODIUM_FRONT + BAY_RECESS  # -7,2
    for side in (-1, 1):
        x = side * BAY_X
        parts.append(box("bay_glass", (BAY_W - 0.1, 0.12, BAY_H - 0.1), (x, bay_back - 0.08, BAY_Z0 + BAY_H / 2), M["glass"]))
        parts.append(box("bay_mullion", (0.22, 0.3, BAY_H - 0.2), (x, bay_back - 0.15, BAY_Z0 + BAY_H / 2), M["metal"]))
        parts.append(box("bay_head", (BAY_W + 0.2, 0.4, 0.35), (x, PODIUM_FRONT - 0.05, BAY_Z0 + BAY_H + 0.1), M["metal"]))

    # --- Placa del monograma, encima del portalón y de la marquesina, sobre el fuste.
    parts.append(box("sign_plate", (SIGN_PLATE_W, 0.35, SIGN_PLATE_H), (0, SHAFT_FRONT - 0.175, SIGN_Z), M["limestone"]))
    parts.append(box("sign_frame_top", (SIGN_PLATE_W + 0.6, 0.42, 0.22), (0, SHAFT_FRONT - 0.21, SIGN_Z + SIGN_PLATE_H / 2), M["metal"]))
    parts.append(box("sign_frame_bottom", (SIGN_PLATE_W + 0.6, 0.42, 0.22), (0, SHAFT_FRONT - 0.21, SIGN_Z - SIGN_PLATE_H / 2), M["metal"]))
    for side in (-1, 1):
        parts.append(box("sign_frame_side", (0.22, 0.42, SIGN_PLATE_H + 0.6), (side * (SIGN_PLATE_W / 2 + 0.19), SHAFT_FRONT - 0.21, SIGN_Z), M["metal"]))
    monogram = letters("D.T", 2.4, (0, SHAFT_FRONT - 0.5, SIGN_Z), M["metal"], depth=0.3)
    parts.append(fit_width(monogram, SIGN_PLATE_W - 1.2))

    # --- Fuste: muro cortina. El acero es el bastidor calado y el cristal va dentro de cada hueco.
    shell = box("shaft", (SHAFT_W, SHAFT_D, SHAFT_Z1 - SHAFT_Z0), (0, 0, (SHAFT_Z0 + SHAFT_Z1) / 2), M["metal"])
    glass_h = GLASS_Z1 - GLASS_Z0
    glass_c = (GLASS_Z0 + GLASS_Z1) / 2
    cuts = []
    for x0, x1 in slot_ranges(SHAFT_W, FRONT_SLOTS):
        for face, inward in ((SHAFT_FRONT, 1.0), (-SHAFT_FRONT, -1.0)):
            cuts.append(wall_cut("cut_glass", x1 - x0, glass_h, (x0 + x1) / 2, face, GLASS_RECESS, glass_c, inward))
    for y0, y1 in slot_ranges(SHAFT_D, SIDE_SLOTS):
        for face, inward in ((-SHAFT_W / 2, 1.0), (SHAFT_W / 2, -1.0)):
            cuts.append(wall_cut_x("cut_glass_side", y1 - y0, glass_h, (y0 + y1) / 2, face, GLASS_RECESS, glass_c, inward))
    perforate(shell, cuts)
    parts.append(shell)

    pane_y = SHAFT_FRONT + GLASS_RECESS - 0.08  # -4,58
    pane_x = SHAFT_W / 2 - GLASS_RECESS + 0.08  # 5,58
    for y in (pane_y, -pane_y):
        parts.append(box("pane", (SHAFT_W - 1.1, 0.14, glass_h - 0.1), (0, y, glass_c), M["glass"]))
    for x in (pane_x, -pane_x):
        parts.append(box("pane_side", (0.14, SHAFT_D - 1.1, glass_h - 0.1), (x, 0, glass_c), M["glass"]))
    # Zócalo de acero del fuste: la línea donde la torre arranca del podio.
    parts.append(box("shaft_band", (SHAFT_W + 0.6, SHAFT_D + 0.6, 0.4), (0, 0, 10.2), M["metal"]))

    # --- Remate del cuerpo: cornisa de caliza y farol de la corona.
    parts.append(box("top_cornice", (SHAFT_W + 1.4, SHAFT_D + 1.4, TOP_CORNICE_H), (0, 0, TOP_CORNICE_Z0 + TOP_CORNICE_H / 2), M["limestone"]))
    parts.append(box("lantern", (LANTERN_W, LANTERN_D, LANTERN_Z1 - SHAFT_Z1), (0, 0, (SHAFT_Z1 + LANTERN_Z1) / 2), M["glass"]))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box("lantern_post", (0.6, 0.6, LANTERN_Z1 - SHAFT_Z1), (sx * LANTERN_W / 2, sy * LANTERN_D / 2, (SHAFT_Z1 + LANTERN_Z1) / 2), M["metal"]))
    parts.append(box("lantern_cap_steel", (LANTERN_W + 1.2, LANTERN_D + 1.2, 0.35), (0, 0, LANTERN_Z1 + 0.175), M["metal"]))
    parts.append(box("lantern_cap_stone", (LANTERN_W + 1.8, LANTERN_D + 1.8, 0.35), (0, 0, LANTERN_Z1 + 0.525), M["limestone"]))

    # --- Cubierta: casetas de instalaciones sobre la terraza del podio y la del fuste.
    parts.append(box("plant_a", (3.2, 2.4, 1.4), (9.6, 6.2, PODIUM_H + 0.6 + 0.7), M["metal"]))
    parts.append(box("plant_b", (2.2, 1.8, 1.1), (4.2, 6.9, PODIUM_H + 0.6 + 0.55), M["metal"]))
    parts.append(box("plant_c", (1.8, 1.4, 1.0), (3.9, 3.6, SHAFT_Z1 + 0.5), M["metal"]))
    return parts


def build_marquee(M):
    """Nivel 1: marquesina y lobby. Pórtico de acero sobre el portalón, con filete de añil y las hojas
    del lobby dentro del porche."""
    parts = []
    parts.append(box("canopy", (14.0, 2.0, 0.4), (0, PODIUM_FRONT - 0.8, 7.65), M["metal"]))
    parts.append(box("canopy_fascia", (14.0, 0.18, 0.95), (0, PODIUM_FRONT - 1.82, 7.35), M["metal"]))
    parts.append(box("canopy_accent", (14.1, 0.1, 0.26), (0, PODIUM_FRONT - 1.9, 7.42), M["metal_anil"]))
    for side in (-1, 1):
        parts.append(box("canopy_post", (0.45, 0.45, 7.45), (side * 6.4, PODIUM_FRONT - 1.4, 3.725), M["metal"]))
    for side in (-1, 1):
        parts.append(box("door_glass", (2.1, 0.14, 6.7), (side * 2.35, PODIUM_FRONT + 1.0, 3.45), M["glass"]))
    for x in (0.0, -3.55, 3.55):
        parts.append(box("door_jamb", (0.24, 0.3, 7.0), (x, PODIUM_FRONT + 1.0, 3.5), M["metal"]))
    parts.append(box("door_head", (7.4, 0.3, 0.3), (0, PODIUM_FRONT + 1.0, 7.0), M["metal"]))
    return parts


def build_fins(M):
    """Nivel 2: aletas verticales de acero delante del muro cortina, del podio a la cornisa."""
    parts = []
    z0, z1 = PODIUM_H + 0.6, TOP_CORNICE_Z0  # 10,0 a 27,8
    zc = (z0 + z1) / 2
    front_x = [-SHAFT_W / 2 + CORNER_FRAME / 2]
    front_x += [(x0 + x1) / 2 for x0, x1 in slot_ranges(SHAFT_W, FRONT_SLOTS)[:-1]]
    front_x.append(SHAFT_W / 2 - CORNER_FRAME / 2)
    front_x = sorted(set(round(x, 3) for x in front_x))
    for x in front_x:
        for sy in (-1, 1):
            parts.append(box("fin", (0.45, 1.05, z1 - z0), (x, sy * (SHAFT_D / 2 + 0.4), zc), M["metal"]))
    for y in (-SHAFT_D / 2 + 0.4, 0.0, SHAFT_D / 2 - 0.4):
        for sx in (-1, 1):
            parts.append(box("fin_side", (1.05, 0.45, z1 - z0), (sx * (SHAFT_W / 2 + 0.4), y, zc), M["metal"]))
    parts.append(box("frieze", (SHAFT_W + 0.9, SHAFT_D + 0.9, 0.5), (0, 0, 27.5), M["metal"]))
    return parts


def build_crown(M):
    """Nivel 3: corona de acero calada sobre la cornisa, con el monograma D.T entre las aletas."""
    parts = []
    z0, z1 = SHAFT_Z1, CROWN_FIN_Z1  # 28,5 a 38,3
    zc = (z0 + z1) / 2
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box("crown_fin", (0.6, 1.0, z1 - z0), (sx * 6.0, sy * 5.0, zc), M["metal"]))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box("crown_fin_mid", (0.6, 1.0, z1 - z0), (sx * 3.0, sy * 5.0, zc), M["metal"]))
    for sx in (-1, 1):
        parts.append(box("crown_fin_side", (0.6, 1.0, z1 - z0), (sx * 6.0, 0.0, zc), M["metal"]))
    parts.append(box("crown_ring", (13.0, 11.0, 0.3), (0, 0, 33.3), M["metal"]))
    parts.append(box("crown_cap", (13.2, 11.2, 0.45), (0, 0, CROWN_TOP - 0.225), M["metal"]))
    # El monograma de la corona: placa de caliza y letras de acero, como el cartel del Cine Lux.
    parts.append(box("crown_plate", (6.0, 0.32, 2.4), (0, -5.66, 31.0), M["limestone"]))
    crest = letters("D.T", 2.0, (0, -5.9, 31.0), M["metal"], depth=0.3)
    parts.append(fit_width(crest, 4.9))
    return parts


def build_annex(M):
    """Nivel 4: podio anexo retranqueado sobre la terraza del podio, con cubierta de pizarra y sus paños
    de cristal. Es la ampliación que se ve desde arriba y desde el lado izquierdo."""
    parts = []
    parts.append(box("annex", (8.1, 7.8, 5.3), (-10.95, 4.3, PODIUM_H + 0.6 + 2.65), M["limestone"]))
    parts.append(box("annex_roof", (8.5, 8.2, 0.4), (-10.95, 4.3, PODIUM_H + 0.6 + 5.5), M["slate"]))
    parts.append(box("annex_glass", (7.7, 0.14, 1.6), (-10.95, 0.44, PODIUM_H + 0.6 + 2.6), M["glass"]))
    parts.append(box("annex_glass_side", (0.14, 7.0, 1.6), (-14.98, 4.3, PODIUM_H + 0.6 + 2.6), M["glass"]))
    for x in (-13.4, -8.6):
        parts.append(box("annex_fin", (0.3, 0.55, 4.2), (x, 0.55, PODIUM_H + 0.6 + 2.65), M["metal"]))
    return parts


def build_spire(M):
    """Nivel 5: aguja de la corona con remate de oro. Lleva el edificio a 44."""
    parts = []
    parts.append(box("spire_a", (0.9, 0.9, 1.6), (0, 0, CROWN_TOP + 0.8), M["metal"]))
    parts.append(box("spire_b", (0.65, 0.65, 1.4), (0, 0, CROWN_TOP + 2.3), M["metal"]))
    parts.append(box("spire_c", (0.45, 0.45, 1.0), (0, 0, CROWN_TOP + 3.5), M["metal"]))
    parts.append(box("spire_collar", (0.95, 0.95, 0.22), (0, 0, CROWN_TOP + 4.0), M["metal_oro"]))
    bpy.ops.mesh.primitive_cone_add(
        vertices=4,
        radius1=0.5,
        radius2=0.0,
        depth=1.25,
        location=(0, 0, CROWN_TOP + 4.625),
        rotation=(0, 0, math.radians(45)),
    )
    finial = bpy.context.active_object
    finial.name = "spire_finial"
    finial.data.materials.append(M["metal_oro"])
    parts.append(finial)
    return parts


def group(level, parts, store):
    """Une las piezas de un nivel en una malla por material y color. En Roblox cada malla lleva un material."""
    layer = "body" if level == 0 else f"addon{level}"
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        rbx, suffix, rgb = RBX[key]
        name = f"dt_{layer}_{rbx.lower()}{suffix}"
        if len(members) == 1:
            # Un solo objeto: no hay nada que unir y Blender avisaría de ello.
            mesh = members[0]
            mesh.name = name
            origin_at_zero(mesh)
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
        box("tile", (TILE_LENGTH, TILE_DEPTH, 0.04), (x, TILE_SIDE, 0.03), M["zone"])
        for sign in (-1, 1):
            box("tile_edge", (0.5, TILE_DEPTH, 0.05), (x + sign * TILE_LENGTH / 2, TILE_SIDE, 0.035), M["cream"])
            box("tile_edge", (TILE_LENGTH, 0.5, 0.05), (x, TILE_SIDE + sign * TILE_DEPTH / 2, 0.035), M["cream"])
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
    box("ficha_ref", (8.0, 4.0, 5.0), (-2.5 * SPACING, TILE_SIDE, 2.5), M["dark"])
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
    builders = {1: build_marquee, 2: build_fins, 3: build_crown, 4: build_annex, 5: build_spire}
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

    # LOD1 con el conjunto entero; el ratio se baja un poco para quedar siempre por debajo del 50 %.
    build_cine_lux.LOD_RATIO = LOD_RATIO
    lod = lod_of(objects, "dt_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "dt_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "cuerpo": SHAFT_Z1,
        "altura_maxima_nivel_5": TOTAL_HEIGHT,
        "nivel_0_maximo_permitido": LEVEL0_MAX,
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
    print("DT_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if levels["0"]["limites"]["alto_maximo_sobre_suelo"] > LEVEL0_MAX + 0.01:
        raise RuntimeError(f"El nivel 0 llega a {levels['0']['limites']['alto_maximo_sobre_suelo']}, más de {LEVEL0_MAX}")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] > TOTAL_HEIGHT + 0.01:
        raise RuntimeError(f"El nivel 5 llega a {levels['5']['limites']['alto_maximo_sobre_suelo']}, más de {TOTAL_HEIGHT}")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "d-t.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["metal"], "gold": M["metal_oro"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -180.0, 74.0), (0.0, 26.0, 12.0), 30), f"{RENDER_SUBDIR}/d-t-niveles.png")

    # Comparación: nivel 0 frente a los bloques de Bodega (13) y Cine Lux (24), con una figura de 6
    # delante de la fachada y al lado del portalón: es lo que mide la puerta.
    hide_all()
    box("ground", (170, 46, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], 0.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (-36.0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (36.0, 0, 12.0), M["block"])
    box("avatar_ref", (1.6, 1.2, 6.0), (5.6, -9.2, 3.0), M["dark"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -120.0, 20.0), (0.0, 0.0, 14.0), 40), f"{RENDER_SUBDIR}/d-t-comparacion.png")
    print("DT_DONE")


if __name__ == "__main__":
    main()

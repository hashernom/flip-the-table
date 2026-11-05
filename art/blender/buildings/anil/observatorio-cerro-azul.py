"""Observatorio Cerro Azul: propiedad de la zona Añil (Zona Alta), modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). El frente da a -Y y el origen está en el centro de la base,
con z = 0 a ras de suelo. Cuerpo de 25 (masa principal: base de caliza, tambor y cúpula) y cinco añadidos que
se suman hasta 39, por debajo de los 44 de tope. La cúpula es el rasgo: va en el cuerpo para que el nivel 0 ya
se lea como observatorio, y el nivel 3 le saca el telescopio por la ranura.

Sigue el método de build_cine_lux.py y la plantilla de barberia-morro.py: una malla por material y color, LOD1
con decimado.

Salidas, en art/blender/buildings/anil/:
  observatorio-cerro-azul.blend            escena de revisión (no se versiona)
  observatorio-cerro-azul/observatorio_<pieza>_<material>.fbx y observatorio_LOD1.fbx
  observatorio-cerro-azul/stats.json       triángulos por pieza y nivel, límites y materiales
Y en art/render/anil/observatorio-cerro-azul/: observatorio-cerro-azul-niveles.png y -comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/anil/observatorio-cerro-azul.py
"""

import json
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "observatorio-cerro-azul")
RENDER_SUBDIR = "anil/observatorio-cerro-azul"
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

# --- Solar y huella ---------------------------------------------------------------------------------------
LOT_W = 32.0  # huella máxima del solar
LOT_D = 18.0
BASE_W = 23.2  # base de caliza: 23,2 × 15,6
BASE_Y0 = -8.2  # fachada
BASE_Y1 = 7.4  # fondo
BASE_D = BASE_Y1 - BASE_Y0
BASE_YC = (BASE_Y0 + BASE_Y1) / 2
BASE_H = 13.6  # hasta la cornisa
CORNICE_Z = BASE_H
CORNICE_H = 0.65
CORNICE_TOP = CORNICE_Z + CORNICE_H  # 14,25

# --- Entrada ----------------------------------------------------------------------------------------------
PORTAL_W = 9.2  # portalón: 9,2 × 7,8, más alto que el avatar de 6
PORTAL_H = 7.8
PORTAL_BACK = -5.1  # fondo de la hornacina
DOOR_W = 3.4
DOOR_H = 6.9
WIN_W = 2.6  # ventanales del museo, uno a cada lado: no son hileras de pisos
WIN_H = 5.6
WIN_X = 8.6
WIN_Z = 5.2
CANOPY_Z = 8.1  # marquesina del nivel 1
CANOPY_FRONT = -9.9  # vuelo máximo: nada delante de y = -10
SIGN_Z = 10.95
SIGN_W = 18.0
SIGN_H = 4.3
LETTERS = 1.8
LINE_1_Z = 11.75
LINE_2_Z = 10.15

# --- Tambor, cúpula y terraza -----------------------------------------------------------------------------
DRUM_R = 7.05
DRUM_CY = -0.4
DRUM_Z0 = 14.2
DRUM_Z1 = 15.6
RIBBON_Z0 = 15.4
RIBBON_Z1 = 17.7
CROWN_R = 7.2
CROWN_Z0 = 17.5
CROWN_Z1 = 18.5
DOME_R = 7.0
DOME_RISE = 6.8
DOME_Z = 18.2  # arranque de la cúpula (queda hundido en el aro de caliza)
DOME_TOP = DOME_Z + DOME_RISE  # 25,0: altura del cuerpo
DOME_SEG = 16
DOME_RINGS = 5
SLOT_W = 1.9
SLOT_BACK = 0.6
SLOT_Z0 = 18.1
SLOT_Z1 = 24.5
TERRACE_Z = 14.2
TERRACE_W = 23.6
TERRACE_D = 16.0

# --- Telescope (nivel 3) ----------------------------------------------------------------------------------
TILT = math.radians(45.0)
TUBE_R = 0.78
TUBE_L = 10.2
TUBE_Z0 = 19.8
TUBE_Y0 = -1.5

# --- Anexo de museo (nivel 4) -----------------------------------------------------------------------------
ANNEX_X0 = BASE_W / 2  # 11,6
ANNEX_X1 = 16.6
ANNEX_Y0 = -1.0
ANNEX_Y1 = 7.4
ANNEX_H = 7.6

# --- Torre de la cúpula (nivel 5) -------------------------------------------------------------------------
TOWER_COLLAR_R = 3.6
TOWER_COLLAR_Z0 = 23.8
TOWER_COLLAR_Z1 = 25.5
TOWER_R = 2.8
TOWER_Z1 = 31.5
LANTERN_Z1 = 34.3
LANTERN_RING_Z1 = 34.75
TURRET_R = 2.9
TURRET_RISE = 2.4
FINIAL_Z = LANTERN_RING_Z1 + TURRET_RISE  # 37,15

TRIANGLE_BUDGET = 3000
MAX_HEIGHT = 44.0
CINE_LUX_L5_TRIANGLES = 3042

# --- Escena de calle (solo render) ------------------------------------------------------------------------
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
    "limestone": ("Limestone", "", "D2C9B4"),
    "glass": ("Glass", "", "2E4A63"),
    "metal_acero": ("Metal", "_acero", "A8AEB4"),
    "metal_oro": ("Metal", "_oro", "C9A227"),
    "slate": ("Slate", "", "4A4E54"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.5, 0.85),
        "metal_oro": flat("metal_oro", "C9A227", 0.3, 0.9),
        "slate": flat("slate", "4A4E54", 0.85),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "1F3F8F", 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "2B3239", 0.7),
    }


def cylinder(name, radius, depth, location, mat, verts, caps):
    """Cilindro vertical. Sin tapas cuando va embutido entre dos aros."""
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
    """Cono de remate (aguja del nivel 5)."""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def dome_shell(name, radius, rise, segments, rings, location, mat):
    """Cúpula maciza: media bóveda cerrada por abajo, para poder abrirle la ranura con un boolean."""
    verts, faces = [], []
    for i in range(rings):
        angle = (i / rings) * math.pi / 2
        r = radius * math.cos(angle)
        z = rise * math.sin(angle)
        for s in range(segments):
            a = 2 * math.pi * (s + 0.5) / segments
            verts.append((r * math.cos(a), r * math.sin(a), z))
    apex = len(verts)
    verts.append((0.0, 0.0, rise))
    centre = len(verts)
    verts.append((0.0, 0.0, 0.0))
    for i in range(rings - 1):
        for s in range(segments):
            s2 = (s + 1) % segments
            faces.append(
                (i * segments + s, i * segments + s2, (i + 1) * segments + s2, (i + 1) * segments + s)
            )
    top = (rings - 1) * segments
    for s in range(segments):
        faces.append((top + s, top + (s + 1) % segments, apex))
    for s in range(segments):
        faces.append(((s + 1) % segments, s, centre))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.data.materials.append(mat)
    return obj


def beam(name, a, b, thick, mat):
    """Barra cuadrada entre dos puntos (tirante o montante inclinado)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    obj = box(name, (thick, d.length, thick), tuple((a + b) / 2), mat)
    obj.rotation_euler = Vector((0.0, 1.0, 0.0)).rotation_difference(d.normalized()).to_euler()
    return obj


def portal_cutter(name):
    """Hueco del portalón: 9,2 de ancho y 7,8 de alto, desde el suelo, con 2,8 de hornacina."""
    front = BASE_Y0 - 0.8
    return box(name, (PORTAL_W, PORTAL_BACK - front, PORTAL_H), (0.0, (front + PORTAL_BACK) / 2, PORTAL_H / 2))


def window_cutter(name, x):
    return box(name, (WIN_W, 1.3, WIN_H), (x, -7.65, WIN_Z))


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
    """Nivel 0: base de caliza con portalón y ventanales, placa con letras, tambor acristalado y cúpula con ranura."""
    parts = []

    # Base de caliza con los huecos abiertos de verdad: portalón y dos ventanales del museo.
    base = box("base", (BASE_W, BASE_D, BASE_H), (0.0, BASE_YC, BASE_H / 2), M["limestone"])
    perforate(base, [portal_cutter("cut_portal"), window_cutter("cut_win_l", -WIN_X), window_cutter("cut_win_r", WIN_X)])
    parts.append(base)

    # Zócalo (vuela 0,4) y cornisa de caliza.
    plinth = box("plinth", (BASE_W + 0.8, BASE_D + 0.8, 0.9), (0.0, BASE_YC, 0.45), M["limestone"])
    perforate(plinth, [portal_cutter("cut_portal_plinth")])
    parts.append(plinth)
    parts.append(box("cornice", (BASE_W + 1.2, BASE_D + 1.2, CORNICE_H), (0.0, BASE_YC, CORNICE_Z + CORNICE_H / 2), M["limestone"]))

    # Pilastras de esquina y jambas del portalón: marcan la entrada sin inventar ventanitas.
    for side in (-1, 1):
        parts.append(box("pilaster", (1.0, 0.7, BASE_H - 0.2), (side * 11.15, -7.95, (BASE_H - 0.2) / 2), M["limestone"]))
        parts.append(box("portal_jamb", (0.9, 0.7, PORTAL_H + 0.6), (side * 5.05, -7.95, (PORTAL_H + 0.6) / 2), M["limestone"]))
        parts.append(box("sill", (3.2, 1.3, 0.35), (side * WIN_X, -7.7, WIN_Z - WIN_H / 2 - 0.18), M["limestone"]))

    # Tambor: aro de caliza, franja de cristal y aro de coronación. La cúpula arranca dentro del aro alto.
    parts.append(cylinder("drum_base", DRUM_R, DRUM_Z1 - DRUM_Z0, (0.0, DRUM_CY, (DRUM_Z0 + DRUM_Z1) / 2), M["limestone"], DOME_SEG, True))
    parts.append(cylinder("drum_crown", CROWN_R, CROWN_Z1 - CROWN_Z0, (0.0, DRUM_CY, (CROWN_Z0 + CROWN_Z1) / 2), M["limestone"], DOME_SEG, True))

    # Placa de pizarra con el nombre en letras de caliza, por encima de la puerta y de la marquesina.
    parts.append(box("sign_plate", (SIGN_W, 0.35, SIGN_H), (0.0, -8.35, SIGN_Z), M["slate"]))
    parts.append(fit_width(letters("OBSERVATORIO", LETTERS, (0.0, -8.63, LINE_1_Z), M["limestone"], depth=0.16), SIGN_W - 2.0))
    parts.append(fit_width(letters("CERRO AZUL", LETTERS, (0.0, -8.63, LINE_2_Z), M["limestone"], depth=0.16), SIGN_W - 3.4))

    # Cristal: muro de la entrada con su puerta, ventanales y franja del tambor.
    parts.append(box("portal_glass", (PORTAL_W - 0.3, 0.12, PORTAL_H - 0.1), (0.0, PORTAL_BACK - 0.1, (PORTAL_H - 0.1) / 2), M["glass"]))
    parts.append(box("door", (DOOR_W, 0.08, DOOR_H), (0.0, PORTAL_BACK - 0.2, DOOR_H / 2), M["glass"]))
    for side in (-1, 1):
        parts.append(box("pane", (WIN_W, 0.1, WIN_H), (side * WIN_X, -7.15, WIN_Z), M["glass"]))
    parts.append(cylinder("drum_glass", DRUM_R - 0.1, RIBBON_Z1 - RIBBON_Z0, (0.0, DRUM_CY, (RIBBON_Z0 + RIBBON_Z1) / 2), M["glass"], DOME_SEG, False))

    # Acero: cúpula con la ranura abierta hacia la calle, montantes del tambor y marco de la puerta.
    dome = dome_shell("dome", DOME_R, DOME_RISE, DOME_SEG, DOME_RINGS, (0.0, DRUM_CY, DOME_Z), M["metal_acero"])
    slot_front = DRUM_CY - DOME_R - 1.6
    slot = box(
        "cut_slot",
        (SLOT_W, SLOT_BACK - slot_front, SLOT_Z1 - SLOT_Z0),
        (0.0, (slot_front + SLOT_BACK) / 2, (SLOT_Z0 + SLOT_Z1) / 2),
    )
    perforate(dome, [slot])
    parts.append(dome)
    for k in range(6):
        a = 2 * math.pi * (k + 0.5) / 6
        x = math.sin(a) * (DRUM_R - 0.02)
        y = DRUM_CY + math.cos(a) * (DRUM_R - 0.02)
        parts.append(box("mullion", (0.26, 0.26, RIBBON_Z1 - RIBBON_Z0), (x, y, (RIBBON_Z0 + RIBBON_Z1) / 2), M["metal_acero"]))
    for side in (-1, 1):
        parts.append(box("door_jamb", (0.18, 0.26, DOOR_H + 0.12), (side * (DOOR_W / 2 + 0.09), PORTAL_BACK - 0.16, (DOOR_H + 0.12) / 2), M["metal_acero"]))
    parts.append(box("door_head", (DOOR_W + 0.36, 0.26, 0.22), (0.0, PORTAL_BACK - 0.16, DOOR_H + 0.11), M["metal_acero"]))
    return parts


def build_marquesina(M):
    """Nivel 1: marquesina de acero sobre el portalón, con filete de oro en el canto y dos cartelas."""
    parts = []
    depth = BASE_Y0 - CANOPY_FRONT  # 1,7
    parts.append(box("canopy", (14.0, depth, 0.4), (0.0, (BASE_Y0 + CANOPY_FRONT) / 2, CANOPY_Z), M["metal_acero"]))
    parts.append(box("canopy_fascia", (14.0, 0.16, 0.55), (0.0, CANOPY_FRONT + 0.08, CANOPY_Z - 0.1), M["metal_acero"]))
    parts.append(box("canopy_gold", (14.06, 0.2, 0.1), (0.0, CANOPY_FRONT + 0.08, CANOPY_Z + 0.15), M["metal_oro"]))
    for side in (-1, 1):
        parts.append(box("corbel", (0.32, 1.0, 0.38), (side * 6.3, BASE_Y0 - 0.5, CANOPY_Z - 0.36), M["metal_acero"]))
    return parts


def build_terraza(M):
    """Nivel 2: terraza de observación con antepecho de caliza y pasamanos de acero alrededor del tambor."""
    parts = []
    parts.append(box("terrace", (TERRACE_W, TERRACE_D, 0.5), (0.0, BASE_YC, TERRACE_Z + 0.25), M["limestone"]))
    wall_z = TERRACE_Z + 0.5 + 0.725
    top_z = TERRACE_Z + 1.9 + 0.09
    for y in (TERRACE_D / 2 - 0.14, -(TERRACE_D / 2 - 0.14)):
        parts.append(box("parapet", (TERRACE_W - 0.28, 0.28, 1.45), (0.0, BASE_YC + y, wall_z), M["limestone"]))
        parts.append(box("rail_top", (TERRACE_W - 0.2, 0.38, 0.18), (0.0, BASE_YC + y, top_z), M["metal_acero"]))
    for x in (-(TERRACE_W / 2 - 0.14), TERRACE_W / 2 - 0.14):
        parts.append(box("parapet", (0.28, TERRACE_D - 0.28, 1.45), (x, BASE_YC, wall_z), M["limestone"]))
        parts.append(box("rail_top", (0.38, TERRACE_D - 0.2, 0.18), (x, BASE_YC, top_z), M["metal_acero"]))
    return parts


def build_telescopio(M):
    """Nivel 3: la cúpula abre la ranura y saca el telescopio, con el pie sobre el tambor."""
    parts = []
    base = Vector((0.0, TUBE_Y0, TUBE_Z0))
    direction = Vector((0.0, -math.sin(TILT), math.cos(TILT)))
    middle = base + direction * (TUBE_L / 2 - 0.9)
    parts.append(box("mount", (1.7, 2.2, 1.3), (0.0, TUBE_Y0, 19.15), M["metal_acero"]))
    tube = cylinder("tube", TUBE_R, TUBE_L, tuple(middle), M["metal_acero"], 12, True)
    tube.rotation_euler = (TILT, 0.0, 0.0)
    parts.append(tube)
    tip = base + direction * TUBE_L
    ring = cylinder("lens_ring", TUBE_R + 0.09, 0.26, tuple(tip - direction * 0.2), M["metal_oro"], 12, True)
    ring.rotation_euler = (TILT, 0.0, 0.0)
    parts.append(ring)
    return parts


def build_anexo(M):
    """Nivel 4: pabellón de museo retranqueado en el costado, con ventanal y cubierta de pizarra."""
    parts = []
    annex = box("annex", (ANNEX_X1 - ANNEX_X0, ANNEX_Y1 - ANNEX_Y0, ANNEX_H), ((ANNEX_X0 + ANNEX_X1) / 2, (ANNEX_Y0 + ANNEX_Y1) / 2, ANNEX_H / 2), M["limestone"])
    perforate(annex, [box("cut_annex_win", (3.4, 1.2, 2.6), ((ANNEX_X0 + ANNEX_X1) / 2, ANNEX_Y0, 4.2))])
    parts.append(annex)
    parts.append(box("annex_roof", (ANNEX_X1 - ANNEX_X0 + 0.5, ANNEX_Y1 - ANNEX_Y0 + 0.5, 0.3), ((ANNEX_X0 + ANNEX_X1) / 2, (ANNEX_Y0 + ANNEX_Y1) / 2, ANNEX_H + 0.15), M["slate"]))
    parts.append(box("annex_glass", (3.4, 0.12, 2.6), ((ANNEX_X0 + ANNEX_X1) / 2, ANNEX_Y0 - 0.15, 4.2), M["glass"]))
    return parts


def build_torre(M):
    """Nivel 5: torre de la cúpula, linterna de acero y remate de oro."""
    parts = []
    parts.append(cylinder("collar", TOWER_COLLAR_R, TOWER_COLLAR_Z1 - TOWER_COLLAR_Z0, (0.0, DRUM_CY, (TOWER_COLLAR_Z0 + TOWER_COLLAR_Z1) / 2), M["metal_acero"], DOME_SEG, False))
    parts.append(cylinder("tower", TOWER_R, TOWER_Z1 - TOWER_COLLAR_Z1, (0.0, DRUM_CY, (TOWER_COLLAR_Z1 + TOWER_Z1) / 2), M["limestone"], 12, True))
    parts.append(cylinder("tower_cornice", TOWER_R + 0.35, 0.45, (0.0, DRUM_CY, TOWER_Z1 + 0.22), M["limestone"], 12, True))
    for k in range(8):
        a = 2 * math.pi * k / 8
        parts.append(box("column", (0.3, 0.3, LANTERN_Z1 - TOWER_Z1 - 0.4), (math.sin(a) * (TOWER_R - 0.4), DRUM_CY + math.cos(a) * (TOWER_R - 0.4), (TOWER_Z1 + 0.4 + LANTERN_Z1) / 2), M["metal_acero"]))
    parts.append(cylinder("lantern_ring", TURRET_R + 0.25, LANTERN_RING_Z1 - LANTERN_Z1, (0.0, DRUM_CY, (LANTERN_Z1 + LANTERN_RING_Z1) / 2), M["metal_acero"], 12, False))
    parts.append(dome_shell("turret", TURRET_R, TURRET_RISE, 12, 4, (0.0, DRUM_CY, LANTERN_RING_Z1), M["metal_acero"]))
    parts.append(cone("finial", 0.45, 1.8, (0.0, DRUM_CY, FINIAL_Z + 0.9), M["metal_oro"], 8))
    parts.append(cylinder("finial_band", 0.62, 0.2, (0.0, DRUM_CY, FINIAL_Z - 0.06), M["metal_oro"], 8, True))
    return parts


def group(level, parts, store):
    """Une las piezas de un nivel en una malla por material y color. En Roblox cada malla lleva un material."""
    layer = "body" if level == 0 else f"addon{level}"
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        rbx, suffix, rgb = RBX[key]
        name = f"observatorio_{layer}_{rbx.lower()}{suffix}"
        if len(members) == 1:
            # Un solo objeto: no se llama a join, que avisaría «No mesh data to join».
            mesh = members[0]
            origin_at_zero(mesh)
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
    builders = {1: build_marquesina, 2: build_terraza, 3: build_telescopio, 4: build_anexo, 5: build_torre}
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
    lod = lod_of(objects, "observatorio_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "observatorio_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": LOT_W, "fondo": LOT_D},
        "cuerpo": {"altura": DOME_TOP, "base": BASE_H},
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
    print("OBSERVATORIO_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] > MAX_HEIGHT:
        raise RuntimeError(f"Nivel 5 a {levels['5']['limites']['alto_maximo_sobre_suelo']} > {MAX_HEIGHT}")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "observatorio-cerro-azul.blend"))

    markers = {kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["metal_acero"], "gold": M["metal_oro"]}) for kind in ("house", "hotel", "tower")}
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -190.0, 76.0), (0.0, 20.0, 14.0), 30), f"{RENDER_SUBDIR}/observatorio-cerro-azul-niveles.png")

    # Comparación: nivel 0 frente a los bloques de Bodega (13) y Cine Lux (24), con una figura de 6 en la puerta.
    hide_all()
    box("ground", (200, 120, 0.4), (0, -20, -0.2), M["pavement"])
    place(cumulative_objects[0], 0.0, 0.0)
    box("bloque_bodega", (32.0, 18.0, 13.0), (-33.0, 20.0, 6.5), M["block"])
    box("bloque_cine_lux", (32.0, 18.0, 24.0), (33.0, 20.0, 12.0), M["block"])
    box("avatar_ref", (1.6, 1.2, 6.0), (6.4, -9.4, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -118.0, 14.5), (0.0, 2.0, 12.0), 45), f"{RENDER_SUBDIR}/observatorio-cerro-azul-comparacion.png")
    print("OBSERVATORIO_DONE")


if __name__ == "__main__":
    main()

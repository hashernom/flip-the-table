"""Muelle de los Pescadores: lonja de pescado de la Dársena Esmeralda (Puerto), modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base, con z = 0 a ras de suelo. El cuerpo es una nave baja de ladrillo con tejado de
pizarra (cumbrera a 15, la altura del cuerpo) abierta a la calle por un portalón de 9 × 7,4 y dos puestos, con
el silo de hielo en el costado oeste: el tejado inclinado y el silo son el rasgo de la propiedad. Los cinco
añadidos se suman: toldos y puestos, cámara frigorífica y tambor del silo, respiraderos de cubierta, pabellón
anexo retranqueado y torre del silo con remate de cobre.

Sigue el método de barberia-morro.py y build_cine_lux.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/esmeralda/:
  muelle-de-los-pescadores.blend                     escena de revisión (no se versiona)
  muelle-de-los-pescadores/muelle_<pieza>.fbx y muelle_LOD1.fbx
  muelle-de-los-pescadores/stats.json                triángulos por pieza y nivel, límites y materiales
Y en art/render/esmeralda/muelle-de-los-pescadores/: muelle-de-los-pescadores-niveles.png y -comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/esmeralda/muelle-de-los-pescadores.py
"""

import json
import math
import os
import sys

import bmesh
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "muelle-de-los-pescadores")
RENDER_SUBDIR = "esmeralda/muelle-de-los-pescadores"
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

# --- Solar y nave ------------------------------------------------------------------------------------
WIDTH = 32.0
DEPTH = 18.0
FRONT = -DEPTH / 2  # el frente da a -Y

N_X0, N_X1 = -6.8, 15.4  # nave de la lonja
N_Y0, N_Y1 = FRONT, 8.6
WALL = 0.55  # grosor del muro: el hueco enseña su reveíso
WALL_TOP = 10.2
CORNICE_TOP = 10.55
RIDGE_Y = (N_Y0 + N_Y1) / 2  # -0.2
RIDGE_Z = 14.85
ROOF_T = 0.3
ROOF_X0, ROOF_X1 = N_X0 - 0.45, N_X1 + 0.45  # el alero vuela en los hastiales

# Frente abierto: portalón de 9 × 7,4 y dos puestos de 4 × 6,4, con cuatro pilastras de ladrillo.
PORTAL_X0, PORTAL_X1 = -0.2, 8.8
PORTAL_H = 7.4
BAY_L = (-5.5, -1.5)
BAY_R = (10.1, 14.1)
BAY_H = 6.4
BAYS = (BAY_L, BAY_R)

# Rótulo: placa de pizarra con el nombre en letras de caliza, por encima del portal y de los toldos.
PLACA_X0, PLACA_X1 = -5.2, 13.8
PLACA_Z0, PLACA_Z1 = 8.7, 10.15
PLACA_CX = (PLACA_X0 + PLACA_X1) / 2
SIGN = "MUELLE DE LOS PESCADORES"

# Silo de hielo al costado oeste: cuerpo de 14 y tambor del nivel 2 por encima.
SILO_X, SILO_Y = -11.6, -5.4
SILO_R = 3.0
SILO_TOP = 14.0
SILO_COLLAR = 14.45  # corona de pizarra sobre el fuste; el tambor del nivel 2 arranca de ahí

# Muelle de carga del costado oeste.
DOCK_X0, DOCK_X1 = -15.8, -7.4
DOCK_Y0, DOCK_Y1 = FRONT, -1.6
DOCK_TOP = 0.7

BODY_H = 15.0  # cumbrera del cuerpo
MAX_HEIGHT = 34.0
TRIANGLE_BUDGET = 3000
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
    "wood": ("Wood", "", "6B4A2E"),
    "fabric_rojo": ("Fabric", "_rojo", "C4382B"),
    "metal_acero": ("Metal", "_acero", "A8AEB4"),
    "metal_oro": ("Metal", "_oro", "C9A227"),
    "metal_esmeralda": ("Metal", "_esmeralda", "10B981"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "wood": flat("wood", "6B4A2E", 0.75),
        "fabric_rojo": flat("fabric_rojo", "C4382B", 0.8),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.3, 0.85),
        "metal_oro": flat("metal_oro", "C9A227", 0.32, 0.9),
        "metal_esmeralda": flat("metal_esmeralda", "10B981", 0.4, 0.5),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "10B981", 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "4A5058", 0.8),
    }


# --- Geometría ---------------------------------------------------------------------------------------


def slab(name, x0, x1, y0, y1, z0, z1, mat=None):
    """Caja a partir de sus límites: se lee mejor que centro y tamaño en un edificio de muchas piezas."""
    return box(name, (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), mat)


def cylinder(name, radius, depth, location, mat, verts, caps, rotation=(0.0, 0.0, 0.0)):
    """Cilindro (silo, aros, remates). Con tapas cierra el volumen; sin ellas queda la banda abierta."""
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
    obj.data.materials.append(mat)
    return obj


def cone(name, radius, depth, location, mat, verts):
    """Cono (remate de cobre de la torre)."""
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts,
        radius1=radius,
        radius2=0.0,
        depth=depth,
        location=location,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def gable(name, x0, x1, y0, y1, z_base, z_apex, apex_y, mat):
    """Prisma triangular de ladrillo: cierra el hastial entre el muro y el tejado, sin dejar huecos."""
    verts = [
        (x0, y0, z_base),
        (x0, y1, z_base),
        (x0, apex_y, z_apex),
        (x1, y0, z_base),
        (x1, y1, z_base),
        (x1, apex_y, z_apex),
    ]
    faces = [(0, 1, 2), (3, 5, 4), (0, 2, 5, 3), (1, 4, 5, 2), (0, 3, 4, 1)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def roof_slope(name, x0, x1, y_a, z_a, y_b, z_b, thickness, mat):
    """Faldón inclinado de pizarra: caja girada cuya cara superior pasa por los dos puntos del alero y la cumbrera."""
    length = math.hypot(y_b - y_a, z_b - z_a)
    angle = math.atan2(z_b - z_a, y_b - y_a)
    normal_y, normal_z = -math.sin(angle), math.cos(angle)
    obj = box(
        name,
        (x1 - x0, length, thickness),
        ((x0 + x1) / 2, (y_a + y_b) / 2 - normal_y * thickness / 2, (z_a + z_b) / 2 - normal_z * thickness / 2),
        mat,
    )
    obj.rotation_euler = (angle, 0, 0)
    return obj


def slanted(name, width, length, centre, angle, mat):
    """Caja girada alrededor de X (toldos, canales y puntales). `angle` mira el eje +Y hacia (cos, sin)."""
    obj = box(name, (width, length, 0.12), centre, mat)
    obj.rotation_euler = (angle, 0, 0)
    return obj


def front_openings():
    """Los tres cortadores del frente: portalón de 9 × 7,4 y dos puestos de 4 × 6,4. Empiezan bajo el suelo."""
    made = []
    for name, (x0, x1), height in (
        ("cut_portal", (PORTAL_X0, PORTAL_X1), PORTAL_H),
        ("cut_bay_l", BAY_L, BAY_H),
        ("cut_bay_r", BAY_R, BAY_H),
    ):
        made.append(
            box(
                name,
                (x1 - x0, 1.9, height + 0.4),
                ((x0 + x1) / 2, FRONT + 0.55, (height - 0.4) / 2),
            )
        )
    return made


def fit_width(obj, max_width):
    """Reduce el rótulo de forma uniforme si no cabe en la placa."""
    width = obj.dimensions.x
    if width > max_width:
        select_only(obj)
        factor = max_width / width
        obj.scale = (factor, factor, factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


# --- Nivel 0: la lonja ------------------------------------------------------------------------------


def build_body(M):
    """Nivel 0: nave de ladrillo con tejado de pizarra, frente abierto con puestos, silo de hielo y muelle.

    Ya se lee como lonja sin rótulo: portalón alto con el interior a la vista, dos puestos con mostrador,
    redes colgadas y el silo de hielo con su compuerta y su canaleta sobre el muelle de carga.
    """
    parts = []

    # --- Cerramiento: muro frontal con tres huecos de verdad, laterales, fondo y hastiales.
    wall = slab("nave_front", N_X0, N_X1, FRONT, FRONT + WALL, 0.0, WALL_TOP, M["brick"])
    perforate(wall, front_openings())
    parts.append(wall)
    parts.append(slab("nave_back", N_X0, N_X1, N_Y1 - WALL, N_Y1, 0.0, WALL_TOP, M["brick"]))
    parts.append(slab("nave_west", N_X0, N_X0 + WALL, FRONT, N_Y1, 0.0, WALL_TOP, M["brick"]))
    parts.append(slab("nave_east", N_X1 - WALL, N_X1, FRONT, N_Y1, 0.0, WALL_TOP, M["brick"]))
    parts.append(gable("gable_west", N_X0, N_X0 + 0.45, FRONT, N_Y1, 10.3, 14.6, RIDGE_Y, M["brick"]))
    parts.append(gable("gable_east", N_X1 - 0.45, N_X1, FRONT, N_Y1, 10.3, 14.6, RIDGE_Y, M["brick"]))
    parts.append(slab("pilaster_w", N_X0, N_X0 + 1.0, FRONT - 0.18, FRONT, 0.0, WALL_TOP, M["brick"]))
    parts.append(slab("pilaster_e", N_X1 - 1.0, N_X1, FRONT - 0.18, FRONT, 0.0, WALL_TOP, M["brick"]))

    # --- Zócalo y cornisa de caliza; el zócalo se abre en los tres huecos.
    plinth = slab("plinth", N_X0 - 0.15, N_X1 + 0.15, FRONT - 0.15, FRONT + 0.35, 0.0, 0.65, M["limestone"])
    perforate(plinth, front_openings())
    parts.append(plinth)
    parts.append(slab("plinth_w", N_X0 - 0.15, N_X0 + 0.35, FRONT, N_Y1 + 0.15, 0.0, 0.65, M["limestone"]))
    parts.append(slab("plinth_e", N_X1 - 0.35, N_X1 + 0.15, FRONT, N_Y1 + 0.15, 0.0, 0.65, M["limestone"]))
    parts.append(slab("cornice", N_X0 - 0.25, N_X1 + 0.25, FRONT - 0.2, N_Y1 + 0.2, WALL_TOP, CORNICE_TOP, M["limestone"]))

    # --- Tejado de pizarra a dos aguas, con la cumbrera paralela a la calle, y caballete.
    parts.append(roof_slope("roof_front", ROOF_X0, ROOF_X1, FRONT, CORNICE_TOP, RIDGE_Y, RIDGE_Z, ROOF_T, M["slate"]))
    parts.append(roof_slope("roof_back", ROOF_X0, ROOF_X1, RIDGE_Y, RIDGE_Z, N_Y1, CORNICE_TOP, ROOF_T, M["slate"]))
    parts.append(slab("ridge_cap", ROOF_X0, ROOF_X1, RIDGE_Y - 0.35, RIDGE_Y + 0.35, RIDGE_Z, BODY_H, M["slate"]))

    # --- Rótulo: placa de pizarra sobre el portal y el nombre en letras de caliza.
    parts.append(slab("sign_plate", PLACA_X0, PLACA_X1, FRONT - 0.33, FRONT - 0.03, PLACA_Z0, PLACA_Z1, M["slate"]))
    name = letters(SIGN, 1.32, (PLACA_CX, FRONT - 0.36, (PLACA_Z0 + PLACA_Z1) / 2), M["limestone"], depth=0.18)
    parts.append(fit_width(name, 17.8))

    # --- Marcos de caliza: jambas y dintel del portalón, y dinteles de los dos puestos.
    for x0, x1 in ((PORTAL_X0 - 0.45, PORTAL_X0), (PORTAL_X1, PORTAL_X1 + 0.45)):
        parts.append(slab("portal_jamb", x0, x1, FRONT - 0.18, FRONT - 0.02, 0.0, PORTAL_H, M["limestone"]))
    parts.append(slab("portal_lintel", PORTAL_X0 - 0.45, PORTAL_X1 + 0.45, FRONT - 0.18, FRONT - 0.02, PORTAL_H, PORTAL_H + 0.5, M["limestone"]))
    for x0, x1 in BAYS:
        parts.append(slab("bay_lintel", x0 - 0.35, x1 + 0.35, FRONT - 0.16, FRONT - 0.02, BAY_H, BAY_H + 0.45, M["limestone"]))

    # --- Vestíbulo del portalón: la lonja por dentro, con mesa de subasta y redes colgadas.
    parts.append(slab("hall_back", PORTAL_X0 - 0.4, PORTAL_X1 + 0.4, -6.3, -5.9, 0.0, PORTAL_H, M["limestone"]))
    parts.append(slab("hall_w", PORTAL_X0 - 0.4, PORTAL_X0, -8.6, -6.3, 0.0, PORTAL_H, M["limestone"]))
    parts.append(slab("hall_e", PORTAL_X1, PORTAL_X1 + 0.4, -8.6, -6.3, 0.0, PORTAL_H, M["limestone"]))
    parts.append(slab("hall_floor", PORTAL_X0 - 0.4, PORTAL_X1 + 0.4, -8.6, -5.9, 0.0, 0.14, M["limestone"]))
    parts.append(slab("hall_ceiling", PORTAL_X0 - 0.4, PORTAL_X1 + 0.4, -8.6, -5.9, 6.95, PORTAL_H, M["wood"]))
    parts.append(slab("auction_table", PORTAL_X0 + 2.6, PORTAL_X0 + 6.4, -7.8, -6.7, 0.14, 1.14, M["wood"]))

    # Redes colgadas del techo del vestíbulo: barras finas de acero, el oficio a la vista.
    for x0, x1 in ((PORTAL_X0 + 1.2, PORTAL_X0 + 4.2), (PORTAL_X0 + 5.0, PORTAL_X0 + 8.0)):
        for x in (x0, x1):
            parts.append(slab("net_v", x - 0.04, x + 0.04, -7.68, -7.60, 4.6, 6.95, M["metal_acero"]))
        for z in (4.6, 5.4):
            parts.append(slab("net_h", x0, x1, -7.68, -7.60, z - 0.04, z + 0.04, M["metal_acero"]))
        mesh = math.hypot(x1 - x0, 2.35)
        diagonal = box("net_diag", (mesh, 0.08, 0.07), ((x0 + x1) / 2, -7.64, 5.775), M["metal_acero"])
        diagonal.rotation_euler = (0, -math.atan2(2.35, x1 - x0), 0)
        parts.append(diagonal)

    # --- Puestos abiertos: fondo de caliza, techo de madera, mostrador al borde del hueco y estante.
    for x0, x1 in BAYS:
        parts.append(slab("stall_back", x0 - 0.5, x1 + 0.5, -6.75, -6.45, 0.0, BAY_H, M["limestone"]))
        parts.append(slab("stall_ceiling", x0 - 0.5, x1 + 0.5, -8.6, -6.45, 6.15, BAY_H, M["wood"]))
        parts.append(slab("stall_counter", x0 - 0.15, x1 + 0.15, -8.35, -7.45, 0.0, 1.05, M["wood"]))

    # --- Canalón y bajante de acero en el alero del frente.
    parts.append(slab("gutter", ROOF_X0, ROOF_X1, FRONT - 0.5, FRONT - 0.2, 10.2, 10.45, M["metal_acero"]))
    parts.append(slab("downpipe", N_X1 - 0.9, N_X1 - 0.68, FRONT - 0.30, FRONT - 0.08, 0.0, 10.2, M["metal_acero"]))

    # --- Silo de hielo al costado oeste: basa, fuste, aros, compuerta y canaleta al muelle.
    parts.append(cylinder("silo_base", SILO_R + 0.35, 0.7, (SILO_X, SILO_Y, 0.35), M["limestone"], 12, True))
    parts.append(cylinder("silo_shaft", SILO_R, SILO_TOP - 0.7, (SILO_X, SILO_Y, (SILO_TOP + 0.7) / 2), M["limestone"], 12, True))
    for z in (4.4, 9.4):
        parts.append(cylinder("silo_hoop", SILO_R + 0.3, 0.24, (SILO_X, SILO_Y, z), M["metal_acero"], 8, True))
    parts.append(cylinder("silo_collar", SILO_R + 0.18, 0.85, (SILO_X, SILO_Y, SILO_TOP - 0.15), M["slate"], 12, True))
    parts.append(box("silo_hatch", (1.7, 0.36, 1.9), (SILO_X, SILO_Y - SILO_R + 0.14, 3.5), M["metal_acero"]))
    chute = box("silo_chute", (1.1, 1.9, 0.42), (SILO_X, SILO_Y - SILO_R - 0.62, 1.9), M["metal_acero"])
    chute.rotation_euler = (math.radians(49.0), 0, 0)
    parts.append(chute)

    # --- Muelle de carga: plataforma de caliza con escalón y cajas de madera.
    parts.append(slab("dock", DOCK_X0, DOCK_X1, DOCK_Y0, DOCK_Y1, 0.0, DOCK_TOP, M["limestone"]))
    parts.append(slab("dock_step", DOCK_X0 + 1.0, DOCK_X1 - 1.0, FRONT - 0.4, FRONT, 0.0, 0.36, M["limestone"]))
    for k, (x, y, z) in enumerate(((-9.2, -3.2, 1.05), (-8.4, -3.2, 1.05))):
        parts.append(box(f"dock_crate{k}", (0.72, 0.72, 0.56), (x, y, z), M["wood"]))
    return parts


# --- Niveles 1 a 5 ----------------------------------------------------------------------------------


def build_awnings(M):
    """Nivel 1: toldos de lona sobre los dos puestos, con puntales de acero, cajas y bandejas."""
    parts = []
    for x0, x1 in BAYS:
        cx = (x0 + x1) / 2
        width = x1 - x0 + 0.7
        canvas = slanted("awning", width, 1.53, (cx, FRONT - 0.34, 7.8), math.radians(51.6), M["fabric_rojo"])
        parts.append(canvas)
        parts.append(slab("valance", x0 - 0.35, x1 + 0.35, FRONT - 0.87, FRONT - 0.77, 6.82, 7.24, M["fabric_rojo"]))
        for side in (-1, 1):
            arm = box("awning_arm", (0.09, 1.12, 0.09), (cx + side * (width / 2 - 0.12), FRONT - 0.36, 7.55), M["metal_acero"])
            arm.rotation_euler = (math.radians(51.6), 0, 0)
            parts.append(arm)
        # Puestos: dos cajas de madera y una bandeja de acero sobre el mostrador.
        for side in (-1, 1):
            parts.append(box("stall_crate", (0.7, 0.7, 0.54), (cx + side * 1.15, -7.9, 1.32), M["wood"]))
        parts.append(slab("stall_tray", cx - 0.75, cx + 0.75, -8.25, -7.55, 1.05, 1.13, M["metal_acero"]))
    return parts


def build_cold_store(M):
    """Nivel 2: cámara frigorífica al fondo del costado oeste y tambor del silo por encima del cuerpo."""
    parts = []
    parts.append(slab("chamber", -15.2, -8.4, 2.4, 8.6, 0.0, 6.2, M["limestone"]))
    parts.append(slab("chamber_roof", -15.35, -8.25, 2.25, 8.75, 6.2, 6.55, M["slate"]))
    parts.append(slab("chamber_door", -12.8, -10.2, 2.18, 2.42, 0.0, 3.2, M["metal_acero"]))
    parts.append(slab("chamber_vent", -10.2, -9.2, 2.28, 2.46, 4.3, 5.5, M["metal_acero"]))
    parts.append(box("chamber_unit", (1.7, 1.4, 1.2), (-13.8, 4.2, 7.15), M["metal_acero"]))
    # Cinta de hielo de la cámara al silo.
    parts.append(slab("ice_belt", -12.8, -10.4, -2.6, 2.5, 5.5, 6.5, M["metal_acero"]))
    # Tambor superior del silo, con sus aros, sobre la corona del cuerpo.
    parts.append(cylinder("silo_drum", 2.65, 21.0 - 14.2, (SILO_X, SILO_Y, (14.2 + 21.0) / 2), M["limestone"], 12, True))
    for z in (16.6, 19.6):
        parts.append(cylinder("silo_drum_hoop", 2.95, 0.22, (SILO_X, SILO_Y, z), M["metal_acero"], 8, True))
    return parts


def build_vents(M):
    """Nivel 3: respiraderos de cubierta. Un monitor corrido sobre la cumbrera y cuatro chimeneas de acero."""
    parts = []
    parts.append(slab("monitor", -1.0, 11.6, RIDGE_Y - 0.8, RIDGE_Y + 0.8, 14.3, 16.1, M["slate"]))
    parts.append(slab("monitor_cap", -1.25, 11.85, RIDGE_Y - 1.05, RIDGE_Y + 1.05, 16.1, 16.3, M["slate"]))
    parts.append(slab("monitor_louver_s", -0.8, 11.4, RIDGE_Y - 0.86, RIDGE_Y - 0.78, 14.55, 15.85, M["metal_acero"]))
    parts.append(slab("monitor_louver_n", -0.8, 11.4, RIDGE_Y + 0.78, RIDGE_Y + 0.86, 14.55, 15.85, M["metal_acero"]))
    for x in (-3.6, 1.2, 6.0, 10.8):
        parts.append(cylinder("cowl", 0.42, 2.2, (x, -4.6, 13.2), M["metal_acero"], 8, True))
    parts.append(slab("vent_box_w", -6.0, -3.4, -7.6, -6.2, 11.2, 12.6, M["metal_acero"]))
    parts.append(slab("vent_box_e", 10.6, 13.6, -7.4, -6.0, 11.3, 12.7, M["metal_acero"]))
    return parts


def build_pavilion(M):
    """Nivel 4: pabellón anexo de cámara, retranqueado detrás de la nave, con muelle y equipo en cubierta."""
    parts = []
    parts.append(slab("pavilion", 1.0, 12.6, 8.9, 12.7, 0.0, 7.6, M["limestone"]))
    parts.append(slab("pavilion_roof", 0.85, 12.75, 8.75, 12.85, 7.6, 7.95, M["slate"]))
    parts.append(slab("pavilion_door", 4.6, 8.2, 8.72, 8.92, 0.0, 4.6, M["metal_acero"]))
    for z in (1.2, 2.6, 4.0):
        parts.append(slab("pavilion_rib", 4.6, 8.2, 8.70, 8.74, z, z + 0.14, M["metal_acero"]))
    parts.append(slab("pavilion_window", 9.2, 11.6, 8.84, 8.94, 5.4, 6.6, M["glass"]))
    parts.append(box("pavilion_unit", (1.6, 1.3, 1.15), (2.9, 10.4, 8.5), M["metal_acero"]))
    parts.append(cylinder("pavilion_stack", 0.36, 1.4, (11.6, 11.4, 8.6), M["metal_acero"], 8, True))
    return parts


def build_tower(M):
    """Nivel 5: torre del silo con galería y remate de cobre. El nivel 5 remata la propiedad a 34."""
    parts = []
    parts.append(cylinder("tower_gallery", 2.95, 0.42, (SILO_X, SILO_Y, 21.2), M["metal_acero"], 12, True))
    parts.append(cylinder("tower_shaft", 1.85, 8.2, (SILO_X, SILO_Y, 21.4 + 4.1), M["limestone"], 12, True))
    for z in (23.4, 26.0, 28.2):
        parts.append(cylinder("tower_band", 1.92, 0.18, (SILO_X, SILO_Y, z), M["metal_acero"], 8, True))
    parts.append(cylinder("tower_ring", 2.5, 0.16, (SILO_X, SILO_Y, 29.32), M["metal_esmeralda"], 12, True))
    parts.append(cone("tower_cap", 2.45, 3.7, (SILO_X, SILO_Y, 29.4 + 1.85), M["metal_oro"], 12))
    parts.append(cylinder("tower_mast", 0.15, 0.9, (SILO_X, SILO_Y, 33.5), M["metal_acero"], 8, True))
    return parts


# --- Montaje, estadísticas y exportación --------------------------------------------------------------


def merge(members, name):
    """Aplica transformaciones y une; con una sola pieza no llama a join (evita «No mesh data to join»)."""
    for member in members:
        select_only(member)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(members) == 1:
        obj = members[0]
        obj.name = name
    else:
        obj = join(members, name)
    origin_at_zero(obj)
    return obj


def group(level, parts, store):
    """Une las piezas de un nivel en una malla por material y color. En Roblox cada malla lleva un material."""
    layer = "body" if level == 0 else f"addon{level}"
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        rbx, suffix, rgb = RBX[key]
        name = f"muelle_{layer}_{rbx.lower()}{suffix}"
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
        "frente": round(min(ys), 2),
        "fondo_maximo": round(max(ys), 2),
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
    builders = {1: build_awnings, 2: build_cold_store, 3: build_vents, 4: build_pavilion, 5: build_tower}
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
    lod = lod_of(objects, "muelle_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "muelle_LOD1.fbx")

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
    print("MUELLE_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    body_top = levels["0"]["limites"]["alto_maximo_sobre_suelo"]
    if abs(body_top - BODY_H) > 0.05:
        raise RuntimeError(f"El cuerpo mide {body_top} y debería medir {BODY_H}")
    if levels["0"]["limites"]["alto_maximo_sobre_suelo"] > 20.0:
        raise RuntimeError(f"El nivel 0 pasa de 20: {levels['0']['limites']['alto_maximo_sobre_suelo']}")
    max_top = levels["5"]["limites"]["alto_maximo_sobre_suelo"]
    if max_top > MAX_HEIGHT:
        raise RuntimeError(f"Altura total de {max_top} supera {MAX_HEIGHT}")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "muelle-de-los-pescadores.blend"))

    markers = {
        kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["metal_acero"], "gold": M["metal_oro"]})
        for kind in ("house", "hotel", "tower")
    }
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -200.0, 96.0), (0.0, 26.0, 12.0), 30), f"{RENDER_SUBDIR}/muelle-de-los-pescadores-niveles.png")

    # Comparación: nivel 0 con un avatar de 6 delante de la puerta, y los bloques de Bodega (13) y Cine Lux (24).
    hide_all()
    box("ground", (300, 240, 0.4), (0, 40, -0.22), M["pavement"])
    place(cumulative_objects[0], -33.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (33, 0, 12.0), M["block"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-33.0 + 9.4, FRONT - 1.6, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (-1.0, -122.0, 20.0), (-1.0, 2.0, 9.0), 36), f"{RENDER_SUBDIR}/muelle-de-los-pescadores-comparacion.png")
    print("MUELLE_DONE")


if __name__ == "__main__":
    main()

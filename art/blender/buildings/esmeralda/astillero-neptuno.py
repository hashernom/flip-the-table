"""Astillero Neptuno: astillero y taller de reparación de barcos de la Dársena Esmeralda (Puerto).

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base, con z = 0 a ras de suelo. El cuerpo es una nave abierta de ladrillo de 19, con
portalón de 9 × 7,4, cercha de acero a la vista sobre el frente, rótulo en placa y, al costado oeste, la grada
seca con su cabria: la grúa pórtico y la grada son el rasgo de la propiedad. Los cinco añadidos se suman:
marquesina y portón, grada y casco, grúa pórtico grande, pabellón anexo retranqueado y torre de la grúa con
remate de cobre.

Sigue el método de barberia-morro.py y build_cine_lux.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/esmeralda/:
  astillero-neptuno.blend                        escena de revisión (no se versiona)
  astillero-neptuno/astillero_<pieza>.fbx y astillero_LOD1.fbx
  astillero-neptuno/stats.json                   triángulos por pieza y nivel, límites y materiales
Y en art/render/esmeralda/astillero-neptuno/: astillero-neptuno-niveles.png y -comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/esmeralda/astillero-neptuno.py
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "astillero-neptuno")
RENDER_SUBDIR = "esmeralda/astillero-neptuno"
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
FRONT = -9.0  # el frente da a -Y

N_X0, N_X1 = -2.0, 14.2  # nave de taller
N_Y0, N_Y1 = FRONT, 9.0
WALL = 0.6  # grosor del muro: el portalón enseña su reveíso
BRICK_TOP = 16.2  # coronación del ladrillo
CORNICE_TOP = 16.8  # cornisa de caliza
GLASS_Z0, GLASS_Z1 = 16.8, 18.2  # linterna alta de la nave: banda fina, no un piso acristalado
ROOF_Z0, ROOF_Z1 = 18.2, 19.0  # losa de pizarra: el cuerpo mide 19,0
BODY_H = 19.0

PORTAL_X0, PORTAL_X1 = 1.6, 10.6  # portalón de 9 × 7,4, más alto que la figura de 6
PORTAL_H = 7.4
LINTEL_TOP = 8.2

# Rótulo: placa de caliza con el nombre en letras de acero, por encima del portalón y de la marquesina.
PLACA_X0, PLACA_X1 = -1.3, 13.5
PLACA_Z0, PLACA_Z1 = 8.6, 10.9
SIGN = "ASTILLERO NEPTUNO"

# Grada seca al costado oeste: lecho inclinado, vías, durmientes y cabria.
G_X0, G_X1 = -14.6, -5.6
G_Y0, G_Y1 = -9.4, 4.8
G_Z0, G_Z1 = 0.6, 3.0
SLOPE = math.atan2(G_Z1 - G_Z0, G_Y1 - G_Y0)
RAMP_RUN = math.hypot(G_Y1 - G_Y0, G_Z1 - G_Z0)
HULL_X = (G_X0 + G_X1) / 2

# Cabria de la grada (nivel 0): pórtico sobre el lecho, con su polipasto.
LIFT_XS = (-13.3, -6.9)
LIFT_Y = -6.0
LIFT_TOP = 12.2

# Cobertizo de chapa sobre el callejón oeste: rompe la caja de la nave y cubre las pilas de chapa.
LEAN_X0, LEAN_X1 = -5.5, N_X0
LEAN_Y0, LEAN_Y1 = -8.8, 1.4
LEAN_Z0, LEAN_Z1 = 7.8, 9.6  # z en el borde y en el muro de la nave

# Grúa pórtico grande (nivel 3): patas junto a los bordes del solar, viga de celosía a 26,4.
CRANE_X = 15.4
CRANE_Y = -2.2
LEG_TOP = 26.4
BRIDGE_LOW = 23.9
BRIDGE_TOP = 26.4
BRIDGE_HALF = 15.85

# Torre de la grúa (nivel 5), con remate de cobre a 34,0.
TOWER_X = 10.8
TOWER_TOP = 32.4
MAX_HEIGHT = 34.0

# Pabellón anexo de taller (nivel 4), retranqueado al fondo del patio.
A_X0, A_X1 = -14.4, -6.6
A_Y0, A_Y1 = 5.2, 8.9
A_TOP = 8.4

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
        "metal_acero": flat("metal_acero", "A8AEB4", 0.35, 0.85),
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
    """Cilindro (noray, poleas). Con tapas cierra el volumen; sin ellas queda la banda abierta."""
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
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def beam(name, a, b, thick, mat, depth=None):
    """Barra entre dos puntos: montantes, diagonales de celosía y puntales."""
    a, b = Vector(a), Vector(b)
    d = b - a
    obj = box(name, (thick, d.length, depth or thick), tuple((a + b) / 2), mat)
    obj.rotation_euler = Vector((0.0, 1.0, 0.0)).rotation_difference(d.normalized()).to_euler()
    return obj


def prism(name, x0, x1, profile, mat):
    """Prisma horizontal a partir de un perfil (y, z) cerrado: el lecho de la grada."""
    n = len(profile)
    verts = [(x0, y, z) for y, z in profile] + [(x1, y, z) for y, z in profile]
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, j + n, i + n))
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


def tilted(name, x0, x1, y_a, z_a, y_b, z_b, thickness, mat):
    """Losa inclinada cuya cara superior pasa por (y_a, z_a) y (y_b, z_b): marquesina."""
    angle = math.atan2(z_b - z_a, y_b - y_a)
    length = math.hypot(y_b - y_a, z_b - z_a)
    normal_y, normal_z = -math.sin(angle), math.cos(angle)
    obj = box(
        name,
        (x1 - x0, length, thickness),
        ((x0 + x1) / 2, (y_a + y_b) / 2 - normal_y * thickness / 2, (z_a + z_b) / 2 - normal_z * thickness / 2),
        mat,
    )
    obj.rotation_euler = (angle, 0, 0)
    return obj


def ramp_top(y):
    """Altura del lecho de la grada en un y dado."""
    return G_Z0 + (y - G_Y0) * math.tan(SLOPE)


def on_ramp(name, xc, width, s, length, thickness, mat, lift=0.0):
    """Pieza apoyada sobre la grada: `s` a lo largo de la pendiente, `lift` sobre el lecho."""
    normal_y, normal_z = -math.sin(SLOPE), math.cos(SLOPE)
    y = G_Y0 + s * math.cos(SLOPE) + normal_y * (lift + thickness / 2)
    z = G_Z0 + s * math.sin(SLOPE) + normal_z * (lift + thickness / 2)
    obj = box(name, (width, length, thickness), (xc, y, z), mat)
    obj.rotation_euler = (SLOPE, 0, 0)
    return obj


def slip_point(s, t, h):
    """Punto en coordenadas de la grada: `s` pendiente arriba, `t` a lo ancho, `h` sobre el lecho."""
    return (
        HULL_X + t,
        G_Y0 + s * math.cos(SLOPE),
        G_Z0 + s * math.sin(SLOPE) + h,
    )


def portal_cutters():
    """Hueco del portalón: 9 de ancho, 7,4 de alto, desde el suelo."""
    return [
        box(
            "cut_portal",
            (PORTAL_X1 - PORTAL_X0, 2.0, PORTAL_H + 0.5),
            ((PORTAL_X0 + PORTAL_X1) / 2, FRONT + 0.5, (PORTAL_H - 0.5) / 2),
        )
    ]


def fit_width(obj, max_width):
    """Reduce el rótulo de forma uniforme si no cabe en la placa."""
    width = obj.dimensions.x
    if width > max_width:
        select_only(obj)
        factor = max_width / width
        obj.scale = (factor, factor, factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


# --- Nivel 0: la nave y la grada ---------------------------------------------------------------------


def build_body(M):
    """Nivel 0: nave abierta de ladrillo con cercha de acero, portalón, rótulo y la grada con su cabria.

    Ya se lee como astillero sin rótulo: el portalón enseña el taller por dentro (costillas de barco y
    cerchas), la grada se lleva al patio y la cabria la monta. Nada de hileras de ventanitas.
    """
    parts = []

    # --- Cerramiento de la nave: frente con el portalón de verdad, laterales, fondo y pilastras.
    front = slab("nave_front", N_X0, N_X1, FRONT, FRONT + WALL, 0.0, BRICK_TOP, M["brick"])
    perforate(front, portal_cutters())
    parts.append(front)
    parts.append(slab("nave_back", N_X0, N_X1, N_Y1 - WALL, N_Y1, 0.0, BRICK_TOP, M["brick"]))
    parts.append(slab("nave_west", N_X0, N_X0 + WALL, FRONT, N_Y1, 0.0, BRICK_TOP, M["brick"]))
    parts.append(slab("nave_east", N_X1 - WALL, N_X1, FRONT, N_Y1, 0.0, BRICK_TOP, M["brick"]))
    for x0 in (N_X0, N_X1 - 1.1):
        parts.append(slab("pilaster", x0, x0 + 1.1, FRONT - 0.3, FRONT, 0.0, BRICK_TOP + 0.4, M["brick"]))

    # --- Zócalo de caliza, abierto en el portalón, y cornisa.
    plinth = slab("plinth", N_X0 - 0.15, N_X1 + 0.15, FRONT - 0.15, FRONT + 0.45, 0.0, 0.7, M["limestone"])
    perforate(plinth, portal_cutters())
    parts.append(plinth)
    parts.append(slab("plinth_side", N_X0 - 0.15, N_X0 + 0.45, FRONT, N_Y1, 0.0, 0.7, M["limestone"]))
    parts.append(slab("plinth_east", N_X1 - 0.45, N_X1 + 0.15, FRONT, N_Y1, 0.0, 0.7, M["limestone"]))
    parts.append(slab("cornice", N_X0 - 0.3, N_X1 + 0.3, FRONT - 0.3, N_Y1 + 0.3, BRICK_TOP, CORNICE_TOP, M["limestone"]))

    # --- Linterna alta: banda fina de cristal con montantes de acero. Es luz de nave, no un piso.
    parts.append(slab("clerestory", N_X0 + 0.4, N_X1 - 0.4, FRONT + 0.02, FRONT + 0.5, GLASS_Z0, GLASS_Z1, M["glass"]))
    for x in (N_X0 + 0.4, 2.2, 6.1, 10.0, N_X1 - 0.4):
        parts.append(slab("mullion", x - 0.13, x + 0.13, FRONT - 0.16, FRONT + 0.1, GLASS_Z0, GLASS_Z1, M["metal_acero"]))

    # --- Cubierta de pizarra con su casa de ventilación y dos chimeneas: desde arriba no es una caja lisa.
    parts.append(slab("roof", N_X0 - 0.55, N_X1 + 0.55, FRONT - 0.55, N_Y1 + 0.55, ROOF_Z0, ROOF_Z1, M["slate"]))
    parts.append(slab("roof_monitor", 2.4, 9.0, -3.0, -0.6, ROOF_Z1, 20.0, M["slate"]))
    parts.append(slab("monitor_cap", 2.1, 9.3, -3.3, -0.3, 20.0, 20.2, M["slate"]))
    for x in (11.6, 13.1):
        parts.append(slab("roof_stack", x - 0.42, x + 0.42, 4.2, 5.0, ROOF_Z1, 20.1, M["metal_acero"]))

    # --- Portalón: dintel y jambas de acero, umbral de caliza y el portón que llega con el nivel 1.
    parts.append(slab("portal_head", PORTAL_X0 - 0.35, PORTAL_X1 + 0.35, FRONT - 0.45, FRONT + 0.1, PORTAL_H, LINTEL_TOP, M["metal_acero"]))
    for x in (PORTAL_X0 - 0.25, PORTAL_X1 - 0.25):
        parts.append(slab("portal_jamb", x, x + 0.5, FRONT - 0.4, FRONT + 0.1, 0.0, PORTAL_H, M["metal_acero"]))
    parts.append(slab("threshold", PORTAL_X0, PORTAL_X1, FRONT - 0.5, FRONT + 1.6, 0.0, 0.2, M["limestone"]))

    # --- Taller por dentro del portalón: fondo de madera, suelo de caliza, techo y tres cerchas.
    parts.append(slab("bay_back", 1.2, 11.0, -4.3, -3.9, 0.0, 7.3, M["wood"]))
    parts.append(slab("bay_west", 1.2, 1.6, FRONT, -4.3, 0.0, 7.3, M["brick"]))
    parts.append(slab("bay_east", 10.6, 11.0, FRONT, -4.3, 0.0, 7.3, M["brick"]))
    parts.append(slab("bay_floor", 1.2, 11.0, FRONT, -4.3, 0.0, 0.16, M["limestone"]))
    parts.append(slab("bay_ceiling", 1.2, 11.0, FRONT, -4.3, 7.0, 7.3, M["wood"]))
    for y in (-7.9, -6.3, -4.7):
        parts.append(slab("bay_truss", 1.6, 10.6, y - 0.17, y + 0.17, 6.5, 7.0, M["metal_acero"]))

    # --- Costillas de barco dentro del taller: dos cuadernas en U de acero sobre el suelo.
    for y in (-7.3, -5.3):
        parts.append(slab("rib_side_w", 3.7, 4.05, y - 0.17, y + 0.17, 0.45, 3.4, M["metal_acero"]))
        parts.append(slab("rib_side_e", 8.15, 8.5, y - 0.17, y + 0.17, 0.45, 3.4, M["metal_acero"]))
        parts.append(slab("rib_bottom", 3.7, 8.5, y - 0.17, y + 0.17, 0.16, 0.5, M["metal_acero"]))

    # --- Grada seca: lecho de caliza, dos vías de acero y tres durmientes de madera.
    parts.append(prism("grada", G_X0, G_X1, [(G_Y0, 0.0), (G_Y1, 0.0), (G_Y1, G_Z1), (G_Y0, G_Z0)], M["limestone"]))
    parts.append(slab("grada_head", G_X0 - 0.2, G_X1 + 0.2, G_Y1, G_Y1 + 0.5, 0.0, G_Z1 + 0.15, M["limestone"]))
    for x in (-12.6, -7.6):
        parts.append(on_ramp("grada_rail", x, 0.42, RAMP_RUN / 2, RAMP_RUN - 0.4, 0.22, M["metal_acero"]))
    for s in (1.6, 6.2, 10.8):
        parts.append(on_ramp("durmiente", (G_X0 + G_X1) / 2, G_X1 - G_X0 - 0.5, s, 0.5, 0.2, M["wood"]))

    # --- Cabria de la grada: dos patas sobre el lecho, viga, carro y gancho. Es la grúa del nivel 0.
    lift_base = ramp_top(LIFT_Y)
    for x in LIFT_XS:
        parts.append(slab("lift_leg", x - 0.28, x + 0.28, LIFT_Y - 0.28, LIFT_Y + 0.28, lift_base, LIFT_TOP, M["metal_acero"]))
    parts.append(slab("lift_beam", LIFT_XS[0] - 0.6, LIFT_XS[1] + 0.6, LIFT_Y - 0.3, LIFT_Y + 0.3, LIFT_TOP - 0.7, LIFT_TOP, M["metal_acero"]))
    parts.append(slab("lift_band", LIFT_XS[0] - 0.2, LIFT_XS[1] + 0.2, LIFT_Y - 0.36, LIFT_Y - 0.28, LIFT_TOP - 0.55, LIFT_TOP - 0.15, M["metal_esmeralda"]))
    parts.append(slab("lift_carriage", -11.0, -9.0, LIFT_Y - 0.55, LIFT_Y + 0.55, LIFT_TOP - 1.6, LIFT_TOP - 0.7, M["metal_acero"]))
    parts.append(slab("lift_cable", -10.06, -9.94, LIFT_Y - 0.06, LIFT_Y + 0.06, 7.8, LIFT_TOP - 1.6, M["metal_acero"]))
    parts.append(slab("lift_hook", -10.5, -9.5, LIFT_Y - 0.35, LIFT_Y + 0.35, 7.0, 7.8, M["metal_acero"]))

    # --- Patio: pilas de chapa, noray y bajante. La chapa es lo que se trabaja en un astillero.
    for k in range(3):
        parts.append(slab("plate_stack", -5.45, -2.35, -0.9, 1.5, 0.02 + 0.16 * k, 0.18 + 0.16 * k, M["metal_acero"]))
    parts.append(cylinder("bollard", 0.34, 1.1, (-15.2, 1.2, 0.55), M["metal_acero"], 8, True))
    parts.append(slab("downpipe", N_X1 - 0.75, N_X1 - 0.5, FRONT - 0.34, FRONT - 0.14, 0.4, BRICK_TOP + 0.3, M["metal_acero"]))

    # --- Rótulo: placa de caliza con el nombre en letras de acero, sobre el portalón y el toldo.
    parts.append(slab("placa", PLACA_X0, PLACA_X1, FRONT - 0.53, FRONT - 0.03, PLACA_Z0, PLACA_Z1, M["limestone"]))
    name = letters(SIGN, 1.45, ((PLACA_X0 + PLACA_X1) / 2, FRONT - 0.55, (PLACA_Z0 + PLACA_Z1) / 2), M["metal_acero"], depth=0.22)
    parts.append(fit_width(name, 13.8))
    return parts


# --- Niveles 1 a 5 ----------------------------------------------------------------------------------


def build_marquee(M):
    """Nivel 1: marquesina de acero sobre el portalón y el portón de hojas correderas abiertas."""
    parts = []
    parts.append(tilted("marquee", PORTAL_X0 - 0.6, PORTAL_X1 + 0.6, FRONT, 8.65, FRONT - 0.9, 8.24, 0.16, M["metal_acero"]))
    parts.append(slab("marquee_edge", PORTAL_X0 - 0.6, PORTAL_X1 + 0.6, FRONT - 0.98, FRONT - 0.86, 7.92, 8.32, M["metal_acero"]))
    for x in (PORTAL_X0 + 0.4, PORTAL_X1 - 0.4):
        parts.append(beam("marquee_tie", (x, FRONT - 0.9, 8.32), (x, FRONT - 0.1, 9.05), 0.12, M["metal_acero"]))
    # Portón: dos hojas de acero arrimadas a las jambas, con su travesaño y su riostra.
    for x0 in (PORTAL_X0 + 0.05, PORTAL_X1 - 2.65):
        parts.append(slab("gate_leaf", x0, x0 + 2.6, FRONT - 0.02, FRONT + 0.16, 0.2, 7.1, M["metal_acero"]))
        parts.append(slab("gate_rail", x0, x0 + 2.6, FRONT - 0.08, FRONT + 0.02, 4.6, 4.9, M["metal_acero"]))
        parts.append(beam("gate_brace", (x0 + 0.15, FRONT - 0.1, 0.5), (x0 + 2.45, FRONT - 0.1, 6.8), 0.16, M["metal_acero"]))
    return parts


def build_hull(M):
    """Nivel 2: la grada con el casco en reparación, sus picaderos y sus puntales."""
    parts = []
    stations = (1.2, 4.2, 7.4, 10.2, 12.4)
    section = ((-2.3, 3.35), (-1.75, 1.5), (-0.55, 0.55), (0.55, 0.55), (1.75, 1.5), (2.3, 3.35))
    bow = ((-1.35, 3.35), (-1.05, 1.7), (-0.3, 0.7), (0.3, 0.7), (1.05, 1.7), (1.35, 3.35))
    rings = []
    for index, s in enumerate(stations):
        points = bow if index == len(stations) - 1 else section
        rings.append([slip_point(s, t, h) for t, h in points])
    verts = [point for ring in rings for point in ring]
    faces = []
    n = len(section)
    for index in range(len(rings) - 1):
        a0, b0 = index * n, (index + 1) * n
        for k in range(n - 1):
            faces.append((a0 + k, a0 + k + 1, b0 + k + 1, b0 + k))
        faces.append((a0, b0, b0 + n - 1, a0 + n - 1))  # cubierta
    faces.append(tuple(range(n))[::-1])  # espejo
    faces.append(tuple(range(len(verts) - n, len(verts))))  # proa
    mesh = bpy.data.meshes.new("hull")
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    hull = bpy.data.objects.new("hull", mesh)
    bpy.context.collection.objects.link(hull)
    hull.data.materials.append(M["metal_acero"])
    parts.append(hull)

    # Picaderos de madera bajo la quilla y puntales a las amuras.
    for s in (2.0, 6.6, 11.2):
        parts.append(on_ramp("keel_block", HULL_X, 1.5, s, 1.3, 0.55, M["wood"]))
    for s in (5.6, 9.6):
        for side in (-1, 1):
            parts.append(beam("shore", slip_point(s, side * 3.2, 0.12), slip_point(s, side * 1.9, 2.1), 0.24, M["wood"]))
    return parts


def build_gantry(M):
    """Nivel 3: la grúa pórtico grande, con sus vías, sus patas de celosía, la viga y el polipasto."""
    parts = []
    # Vías en el suelo, a lo largo de la calle y pegadas a los bordes del solar.
    for x in (-CRANE_X, CRANE_X):
        parts.append(slab("crane_rail", x - 0.4, x + 0.4, FRONT, N_Y1, 0.0, 0.28, M["metal_acero"]))
    # Patas de celosía: dos montantes, tres travesaños y dos diagonales por pata.
    for x in (-CRANE_X, CRANE_X):
        for y in (CRANE_Y - 0.55, CRANE_Y + 0.55):
            parts.append(slab("leg", x - 0.26, x + 0.26, y - 0.26, y + 0.26, 0.0, LEG_TOP, M["metal_acero"]))
        for z in (6.4, 13.4, 20.4):
            parts.append(slab("leg_tie", x - 0.24, x + 0.24, CRANE_Y - 0.6, CRANE_Y + 0.6, z, z + 0.34, M["metal_acero"]))
        parts.append(beam("leg_brace", (x, CRANE_Y - 0.55, 0.6), (x, CRANE_Y + 0.55, 13.2), 0.22, M["metal_acero"]))
        parts.append(beam("leg_brace", (x, CRANE_Y + 0.55, 13.6), (x, CRANE_Y - 0.55, 26.0), 0.22, M["metal_acero"]))
    # Viga de celosía entre las dos patas.
    parts.append(slab("bridge_low", -BRIDGE_HALF, BRIDGE_HALF, CRANE_Y - 0.35, CRANE_Y + 0.35, BRIDGE_LOW, BRIDGE_LOW + 0.45, M["metal_acero"]))
    parts.append(slab("bridge_high", -BRIDGE_HALF, BRIDGE_HALF, CRANE_Y - 0.35, CRANE_Y + 0.35, BRIDGE_TOP - 0.45, BRIDGE_TOP, M["metal_acero"]))
    for x in (-12.0, -6.0, 0.0, 6.0, 12.0):
        parts.append(slab("bridge_post", x - 0.19, x + 0.19, CRANE_Y - 0.3, CRANE_Y + 0.3, BRIDGE_LOW + 0.45, BRIDGE_TOP - 0.45, M["metal_acero"]))
    for i in range(4):
        a = -12.0 + 6.0 * i
        b = a + 6.0
        if i % 2:
            parts.append(beam("bridge_brace", (a, CRANE_Y, BRIDGE_TOP - 0.45), (b, CRANE_Y, BRIDGE_LOW + 0.45), 0.24, M["metal_acero"]))
        else:
            parts.append(beam("bridge_brace", (a, CRANE_Y, BRIDGE_LOW + 0.45), (b, CRANE_Y, BRIDGE_TOP - 0.45), 0.24, M["metal_acero"]))
    # Carro, cable y gancho sobre la grada; caseta de máquinas sobre la viga.
    parts.append(slab("trolley", -10.6, -8.4, CRANE_Y - 0.8, CRANE_Y + 0.8, BRIDGE_LOW - 1.1, BRIDGE_LOW, M["metal_acero"]))
    parts.append(slab("trolley_band", -10.7, -8.3, CRANE_Y - 0.87, CRANE_Y + 0.87, BRIDGE_LOW - 1.0, BRIDGE_LOW - 0.78, M["metal_esmeralda"]))
    parts.append(slab("hoist_cable", -9.56, -9.44, CRANE_Y - 0.06, CRANE_Y + 0.06, 14.2, BRIDGE_LOW - 1.1, M["metal_acero"]))
    parts.append(slab("hook_block", -10.1, -8.9, CRANE_Y - 0.42, CRANE_Y + 0.42, 13.0, 14.2, M["metal_acero"]))
    parts.append(slab("machine_house", 2.2, 5.8, CRANE_Y - 1.4, CRANE_Y + 1.4, BRIDGE_TOP, 28.6, M["metal_acero"]))
    parts.append(slab("house_roof", 2.0, 6.0, CRANE_Y - 1.6, CRANE_Y + 1.6, 28.6, 28.9, M["metal_acero"]))
    parts.append(slab("house_window", 2.4, 5.6, CRANE_Y - 1.46, CRANE_Y - 1.38, 27.4, 28.0, M["glass"]))
    return parts


def build_pavilion(M):
    """Nivel 4: pabellón anexo de taller, retranqueado al fondo del patio, con portón y equipo."""
    parts = []
    parts.append(slab("pavilion", A_X0, A_X1, A_Y0, A_Y1, 0.0, A_TOP, M["limestone"]))
    parts.append(slab("pavilion_roof", A_X0 - 0.25, A_X1 + 0.25, A_Y0 - 0.25, A_Y1 + 0.25, A_TOP, A_TOP + 0.4, M["slate"]))
    parts.append(slab("pavilion_door", -12.6, -8.8, A_Y0 - 0.06, A_Y0 + 0.14, 0.0, 4.8, M["metal_acero"]))
    for z in (1.4, 2.8, 4.2):
        parts.append(slab("door_rib", -12.6, -8.8, A_Y0 - 0.14, A_Y0 - 0.04, z, z + 0.16, M["metal_acero"]))
    parts.append(slab("pavilion_win", -8.0, -7.0, A_Y0 - 0.06, A_Y0 + 0.08, 5.4, 7.0, M["glass"]))
    parts.append(slab("pavilion_unit", -8.9, -7.3, 7.2, 8.5, A_TOP + 0.4, A_TOP + 1.5, M["metal_acero"]))
    parts.append(slab("pavilion_stack", -14.6, -13.9, 7.4, 8.1, A_TOP + 0.4, A_TOP + 2.0, M["metal_acero"]))
    return parts


def build_tower(M):
    """Nivel 5: torre de celosía sobre la viga de la grúa, con anillo y remate de cobre a 34."""
    parts = []
    for dx in (-0.55, 0.55):
        for dy in (-0.55, 0.55):
            parts.append(slab("tower_corner", TOWER_X + dx - 0.15, TOWER_X + dx + 0.15, CRANE_Y + dy - 0.15, CRANE_Y + dy + 0.15, BRIDGE_TOP, TOWER_TOP, M["metal_acero"]))
    for z in (28.4, 30.6):
        parts.append(slab("tower_tie_x", TOWER_X - 0.7, TOWER_X + 0.7, CRANE_Y - 0.24, CRANE_Y + 0.24, z, z + 0.24, M["metal_acero"]))
        parts.append(slab("tower_tie_y", TOWER_X - 0.24, TOWER_X + 0.24, CRANE_Y - 0.7, CRANE_Y + 0.7, z, z + 0.24, M["metal_acero"]))
    parts.append(slab("tower_ring", TOWER_X - 0.8, TOWER_X + 0.8, CRANE_Y - 0.8, CRANE_Y + 0.8, TOWER_TOP - 0.65, TOWER_TOP - 0.4, M["metal_esmeralda"]))
    parts.append(cone("copper_cap", 1.35, 1.6, (TOWER_X, CRANE_Y, TOWER_TOP + 0.8), M["metal_oro"], 8))
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
        name = f"astillero_{layer}_{rbx.lower()}{suffix}"
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
        "ancho_izquierda": round(min(xs), 2),
        "ancho_derecha": round(max(xs), 2),
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
    builders = {1: build_marquee, 2: build_hull, 3: build_gantry, 4: build_pavilion, 5: build_tower}
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
    lod = lod_of(objects, "astillero_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "astillero_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "cuerpo": BODY_H,
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
    print("ASTILLERO_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    body_top = levels["0"]["limites"]["alto_maximo_sobre_suelo"]
    if body_top > 24.0:
        raise RuntimeError(f"El nivel 0 completo pasa de 24: {body_top}")
    if body_top < BODY_H - 0.01:
        raise RuntimeError(f"El nivel 0 no llega a la altura del cuerpo ({body_top} < {BODY_H})")
    if levels["0"]["limites"]["frente"] < -10.0:
        raise RuntimeError(f"El nivel 0 vuela más de -10: {levels['0']['limites']['frente']}")
    for level in range(6):
        lim = levels[str(level)]["limites"]
        if lim["frente"] < -10.0:
            raise RuntimeError(f"nivel {level}: vuela hasta {lim['frente']}")
        if max(abs(lim["ancho_izquierda"]), abs(lim["ancho_derecha"])) > 18.0:
            raise RuntimeError(f"nivel {level}: se va a {lim['ancho_izquierda']} / {lim['ancho_derecha']} de ancho")
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "astillero-neptuno.blend"))

    markers = {
        kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["metal_acero"], "gold": M["metal_oro"]})
        for kind in ("house", "hotel", "tower")
    }
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -205.0, 92.0), (0.0, 26.0, 14.0), 32), f"{RENDER_SUBDIR}/astillero-neptuno-niveles.png")

    # Comparación: nivel 0 con una figura de 6 delante de la puerta, y los bloques de Bodega (13) y Cine Lux (24).
    hide_all()
    box("ground", (200, 46, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -33.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (33, 0, 12.0), M["block"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-33.0 + 0.5, FRONT - 1.4, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (-4.0, -118.0, 25.0), (-2.0, 0.0, 9.5), 38), f"{RENDER_SUBDIR}/astillero-neptuno-comparacion.png")
    print("ASTILLERO_DONE")


if __name__ == "__main__":
    main()

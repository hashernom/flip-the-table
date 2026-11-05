"""Caldas: escuela con tres facultades y cancha, propiedad de la zona Cian, modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base, con z = 0 a ras de suelo. Es una sola propiedad compuesta: tres volúmenes de
ladrillo de alturas distintas (11,5 / 14,5 / 9,5) alrededor de un patio, con la cancha de pasto al costado.
El central lleva la portada de caliza, el rótulo y la torre de reloj. Cinco añadidos que se suman: porche y
rótulo de la facultad, ventanales de laboratorio y pasarela, biblioteca y torre de reloj, pabellón de una
facultad nueva retranqueado y torre del auditorio con remate de cobre.

Sigue el método de barberia-morro.py y build_cine_lux.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/cian/:
  caldas.blend                 escena de revisión (no se versiona)
  caldas/caldas_<pieza>_<material>.fbx y caldas_LOD1.fbx
  caldas/stats.json            triángulos por pieza y nivel, límites y materiales
Y en art/render/cian/caldas/: caldas-niveles.png y caldas-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/cian/caldas.py
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
OUT = os.path.join(HERE, "caldas")
RENDER_SUBDIR = "cian/caldas"
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

# --- Solar y volúmenes ------------------------------------------------------------------------------
WIDTH = 32.0
DEPTH = 18.0
FRONT = -DEPTH / 2  # el frente da a -Y

# Facultad del oeste (aulas): la más baja de las tres y retranqueada 0,5 respecto al acceso.
W_X0, W_X1 = -16.0, -7.6
W_Y0, W_Y1 = -8.5, 5.4
W_H = 11.5

# Facultad central (acceso, rótulo y torre de reloj): el volumen más alto del cuerpo.
C_X0, C_X1 = -7.6, 5.8
C_Y0, C_Y1 = -9.0, 2.8
C_H = 14.5

# Facultad del este (laboratorios): retranqueada, con la cancha delante.
E_X0, E_X1 = 5.8, 16.0
E_Y0, E_Y1 = 1.2, 9.0
E_H = 9.5

# Cancha de pasto: al costado, entre la calle y la facultad del este.
PITCH_X0, PITCH_X1 = 5.8, 16.0
PITCH_Y0, PITCH_Y1 = -9.0, 1.2
PITCH_Z = 0.18

PORTAL_W = 9.0
PORTAL_H = 7.4
PLACA_Z = 11.45
PORCH_Z = 8.55
SIGN_Z = PLACA_Z

TRIANGLE_BUDGET = 3000
MAX_HEIGHT = 34.0
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
    "metal_cobre": ("Metal", "_cobre", "C97B3A"),
    "grass": ("Grass", "", "4B6B3A"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.28, 0.85),
        "metal_cobre": flat("metal_cobre", "C97B3A", 0.5, 0.45),
        "grass": flat("grass", "4B6B3A", 0.95),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "22D3EE", 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "6E747C", 0.8),
    }


def slab(name, x0, x1, y0, y1, z0, z1, mat=None):
    """Caja a partir de sus límites: se lee mejor que centro y tamaño en un edificio de muchas piezas."""
    return box(name, (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), mat)


def cylinder(name, radius, depth, location, mat, verts, caps, rotation=(0.0, 0.0, 0.0)):
    """Cilindro (esferas del reloj, remates y tambores de torre)."""
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


def pyramid(name, radius, depth, location, mat, verts=4, rotation=(0.0, 0.0, math.radians(45.0))):
    """Pirámide de base cuadrada: capitel de pizarra o remate de cobre."""
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts,
        radius1=radius,
        radius2=0.0,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def gable(name, x0, x1, y0, y1, z_eave, z_ridge, mat):
    """Tejado a dos aguas con la cumbrera a lo largo de X: el pabellón no es una caja plana."""
    mid = (y0 + y1) / 2
    verts = [
        (x0, y0, z_eave),
        (x0, y1, z_eave),
        (x0, mid, z_ridge),
        (x1, y0, z_eave),
        (x1, y1, z_eave),
        (x1, mid, z_ridge),
    ]
    faces = [(0, 1, 2), (3, 4, 5), (0, 2, 5, 3), (1, 4, 5, 2), (0, 3, 4, 1)]
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


def window_unit(parts, cuts, M, x, width, z0, z1, face_y, out=-1.0, depth=2.6, sill=True):
    """Hueco de verdad (booleano), cristal oscuro, jambas y dintel de acero y alféizar de caliza.

    `out` es la dirección hacia fuera del muro en Y: -1 en la fachada que da a la calle, +1 en la que da
    al patio. El cortador entra desde fuera y deja el cristal retranqueado 0,55.
    """
    cuts.append(box("cut", (width, depth, z1 - z0 + 0.1), (x, face_y - out * 0.25, (z0 + z1) / 2)))
    parts.append(box("pane", (width - 0.24, 0.1, z1 - z0 - 0.18), (x, face_y - out * 0.55, (z0 + z1) / 2), M["glass"]))
    frame_y = face_y - out * 0.2
    for side in (-1, 1):
        parts.append(box("jamb", (0.18, 0.4, z1 - z0), (x + side * (width / 2 - 0.09), frame_y, (z0 + z1) / 2), M["metal_acero"]))
    parts.append(box("head", (width, 0.4, 0.32), (x, frame_y, z1 - 0.11), M["metal_acero"]))
    if sill:
        parts.append(box("sill", (width + 0.5, 0.6, 0.24), (x, face_y + out * 0.3, z0 - 0.12), M["limestone"]))


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
    """Nivel 0: las tres facultades de ladrillo, el patio, la portada y la cancha con cerca y gradas.

    El cuerpo ya se lee como escuela sin rótulo: portada de caliza, ventanales altos de aula, patio
    pavimentado y cancha de pasto con dos porterías y gradas.
    """
    parts = []

    # --- Facultad del oeste: tres ventanales altos de aula, caliza en zócalo, junta y cornisa.
    cuts = []
    wall = slab("w_wall", W_X0, W_X1, W_Y0, W_Y1, 0.0, W_H - 0.8, M["brick"])
    for x in (-14.4, -11.8, -9.2):
        window_unit(parts, cuts, M, x, 1.5, 2.1, 7.5, W_Y0)
    perforate(wall, cuts)
    parts.append(wall)
    parts.append(slab("w_plinth", W_X0 - 0.15, W_X1, W_Y0 - 0.15, W_Y1 + 0.15, 0.0, 0.7, M["limestone"]))
    parts.append(slab("w_string", W_X0 - 0.15, W_X1, W_Y0 - 0.15, W_Y1 + 0.15, 7.85, 8.15, M["limestone"]))
    parts.append(slab("w_cornice", W_X0 - 0.2, W_X1 + 0.2, W_Y0 - 0.2, W_Y1 + 0.2, W_H - 0.8, W_H - 0.3, M["limestone"]))
    parts.append(slab("w_roof", W_X0 + 0.15, W_X1 - 0.15, W_Y0 + 0.15, W_Y1 - 0.15, W_H - 0.3, W_H, M["slate"]))

    # --- Facultad central: portada de caliza, portón de cristal, placa CALDAS y dos huecos al patio.
    cuts = []
    wall = slab("c_wall", C_X0, C_X1, C_Y0, C_Y1, 0.0, C_H - 0.8, M["brick"])
    cuts.append(box("portal_cut", (PORTAL_W, 2.8, PORTAL_H + 0.1), (0.0 - 0.9, FRONT + 0.4, (PORTAL_H + 0.1) / 2)))
    for x in (-4.6, 1.8):
        window_unit(parts, cuts, M, x, 1.7, 4.9, 9.3, C_Y1, out=1.0, sill=False)
    perforate(wall, cuts)
    parts.append(wall)

    plinth = slab("c_plinth", C_X0, C_X1, C_Y0 - 0.15, C_Y1 + 0.15, 0.0, 0.7, M["limestone"])
    perforate(plinth, [box("portal_cut2", (PORTAL_W, 2.8, PORTAL_H + 0.1), (-0.9, FRONT + 0.4, (PORTAL_H + 0.1) / 2))])
    parts.append(plinth)
    parts.append(slab("c_cornice", C_X0 - 0.2, C_X1 + 0.2, C_Y0 - 0.2, C_Y1 + 0.2, C_H - 0.8, C_H - 0.3, M["limestone"]))
    parts.append(slab("c_roof", C_X0 + 0.15, C_X1 - 0.15, C_Y0 + 0.15, C_Y1 - 0.15, C_H - 0.3, C_H, M["slate"]))

    # Portada de caliza: jambas y dintel por delante del ladrillo, como el resto de la zona.
    parts.append(slab("portal_jamb_w", -6.0, -5.4, FRONT - 0.5, FRONT, 0.0, 7.4, M["limestone"]))
    parts.append(slab("portal_jamb_e", 3.6, 4.2, FRONT - 0.5, FRONT, 0.0, 7.4, M["limestone"]))
    parts.append(slab("portal_lintel", -6.3, 4.5, FRONT - 0.5, FRONT, 7.4, 8.2, M["limestone"]))

    # Portón: cristal oscuro con tres montantes de acero. Más alto que un avatar de 6.
    parts.append(slab("portal_glass", -5.25, 3.45, FRONT + 0.8, FRONT + 0.92, 0.0, 7.35, M["glass"]))
    for x in (-3.0, -0.9, 1.2):
        parts.append(slab("portal_mullion", x - 0.08, x + 0.08, FRONT + 0.7, FRONT + 0.95, 0.0, 7.35, M["metal_acero"]))
    # Reveíso de caliza dentro del hueco: cierra la cámara oscura que queda detrás del dintel.
    parts.append(slab("portal_soffit", -5.4, 3.6, FRONT, FRONT + 1.0, 7.35, 7.5, M["limestone"]))
    parts.append(slab("portal_reveal_w", -5.4, -5.25, FRONT, FRONT + 1.0, 0.0, 7.35, M["limestone"]))
    parts.append(slab("portal_reveal_e", 3.45, 3.6, FRONT, FRONT + 1.0, 0.0, 7.35, M["limestone"]))

    # Quicios de caliza en las esquinas del volumen central: separan los tres volúmenes de un vistazo.
    parts.append(slab("c_quoin_w", -7.95, -7.25, FRONT - 0.25, FRONT + 0.5, 0.0, C_H - 0.8, M["limestone"]))
    parts.append(slab("c_quoin_e", 5.45, 6.15, FRONT - 0.25, FRONT + 0.5, 0.0, C_H - 0.8, M["limestone"]))

    # Placa de pizarra con CALDAS en letras de caliza, por encima de la portada y del porche.
    parts.append(slab("sign_plate", -4.9, 3.1, FRONT - 0.15, FRONT + 0.15, 10.5, 12.4, M["slate"]))
    parts.append(fit_width(letters("CALDAS", 1.55, (-0.9, FRONT - 0.22, SIGN_Z), M["limestone"], depth=0.18), 7.2))

    # --- Facultad del este: tres ventanales de aula que miran a la cancha.
    cuts = []
    wall = slab("e_wall", E_X0, E_X1, E_Y0, E_Y1, 0.0, E_H - 0.8, M["brick"])
    for x in (6.9, 8.6, 10.3):
        window_unit(parts, cuts, M, x, 1.4, 1.6, 5.8, E_Y0, depth=2.0)
    perforate(wall, cuts)
    parts.append(wall)
    parts.append(slab("e_plinth", E_X0, E_X1 + 0.15, E_Y0 - 0.15, E_Y1 + 0.15, 0.0, 0.7, M["limestone"]))
    parts.append(slab("e_cornice", E_X0 - 0.2, E_X1 + 0.2, E_Y0 - 0.2, E_Y1 + 0.2, E_H - 0.8, E_H - 0.3, M["limestone"]))
    parts.append(slab("e_roof", E_X0 + 0.3, E_X1 - 0.3, E_Y0 + 0.3, E_Y1 - 0.3, E_H - 0.3, E_H, M["slate"]))

    # --- Patio: pavimento de caliza y tapia baja con portalón de pilares al fondo.
    parts.append(slab("patio_floor", -15.9, 5.7, 2.7, 9.0, 0.0, 0.12, M["limestone"]))
    for x0, x1 in ((-16.0, -1.5), (1.5, 5.8)):
        parts.append(slab("back_wall", x0, x1, 8.7, 9.0, 0.0, 1.5, M["limestone"]))
    for x in (-1.5, 1.5):
        parts.append(slab("back_pier", x - 0.25, x + 0.25, 8.65, 9.05, 0.0, 1.9, M["limestone"]))

    # --- Cancha: hierba, cerca metálica, dos porterías y gradas bajas.
    parts.append(slab("pitch", PITCH_X0, PITCH_X1, PITCH_Y0, PITCH_Y1, 0.0, PITCH_Z, M["grass"]))
    parts.append(slab("pitch_curb_s", PITCH_X0, PITCH_X1, PITCH_Y0, PITCH_Y0 + 0.28, 0.0, 0.24, M["limestone"]))
    parts.append(slab("pitch_curb_e", PITCH_X1 - 0.28, PITCH_X1, PITCH_Y0 + 0.28, PITCH_Y1, 0.0, 0.24, M["limestone"]))
    for x in (6.2, 9.4, 12.6, 15.8):
        parts.append(slab("fence_post", x - 0.08, x + 0.08, -8.98, -8.82, 0.0, 2.2, M["metal_acero"]))
    for z in (0.8, 1.45, 2.1):
        parts.append(slab("fence_rail", 6.1, 15.9, -8.96, -8.84, z, z + 0.12, M["metal_acero"]))
    for x in (6.7, 15.3):
        for y in (-6.0, -2.8):
            parts.append(slab("goal_post", x - 0.08, x + 0.08, y - 0.08, y + 0.08, 0.0, 2.0, M["metal_acero"]))
        parts.append(slab("goal_bar", x - 0.08, x + 0.08, -6.08, -2.72, 1.94, 2.06, M["metal_acero"]))
    for k, (y0, y1, z1) in enumerate(((-0.6, 0.0, 0.5), (0.0, 0.6, 1.0), (0.6, 1.2, 1.5))):
        parts.append(slab(f"bleacher{k}", 6.2, 9.8, y0, y1, 0.0, z1, M["limestone"]))
    return parts


def build_porch(M):
    """Nivel 1: porche de caliza sobre la portada, con dos columnas, y placa AULAS de la facultad."""
    parts = []
    parts.append(slab("porch_canopy", -6.8, 5.0, FRONT - 0.7, FRONT, PORCH_Z - 0.35, PORCH_Z + 0.35, M["limestone"]))
    for x in (-6.4, 4.6):
        parts.append(slab("porch_shaft", x - 0.2, x + 0.2, FRONT - 0.45, FRONT - 0.05, 0.0, PORCH_Z - 0.65, M["limestone"]))
        parts.append(slab("porch_capital", x - 0.31, x + 0.31, FRONT - 0.55, FRONT + 0.05, PORCH_Z - 0.65, PORCH_Z - 0.35, M["limestone"]))
    parts.append(slab("porch_plate", -2.5, 0.7, FRONT - 0.78, FRONT - 0.66, PORCH_Z - 0.23, PORCH_Z + 0.27, M["slate"]))
    parts.append(fit_width(letters("AULAS", 0.66, (-0.9, FRONT - 0.84, PORCH_Z + 0.02), M["limestone"], depth=0.1), 2.6))
    return parts


def build_labs(M):
    """Nivel 2: ventanales de laboratorio sobre la facultad del este y pasarela cubierta en el patio."""
    parts = []
    # Ventanal corrido de laboratorio, por encima de los huecos de aula y a la vista desde la calle.
    parts.append(slab("lab_glass", 6.3, 13.6, E_Y0 - 0.06, E_Y0 + 0.06, 6.05, 8.4, M["glass"]))
    for x in (7.4, 8.5, 9.6, 10.7, 11.8, 12.9):
        parts.append(slab("lab_mullion", x - 0.06, x + 0.06, E_Y0 - 0.11, E_Y0 + 0.11, 6.05, 8.4, M["metal_acero"]))
    parts.append(slab("lab_head", 6.2, 13.7, E_Y0 - 0.12, E_Y0 + 0.12, 8.4, 8.55, M["metal_acero"]))
    parts.append(slab("lab_sill", 6.2, 13.7, E_Y0 - 0.16, E_Y0 + 0.16, 5.9, 6.05, M["metal_acero"]))

    # Pasarela cubierta: corre por el patio, del oeste al este, apoyada en la facultad central.
    parts.append(slab("walk_roof", -7.4, 5.6, C_Y1, C_Y1 + 1.9, 4.0, 4.25, M["slate"]))
    parts.append(slab("walk_beam", -7.4, 5.6, C_Y1 + 1.7, C_Y1 + 1.9, 3.75, 4.0, M["metal_acero"]))
    for x in (-7.2, -3.0, 1.2, 5.4):
        parts.append(slab("walk_post", x - 0.1, x + 0.1, C_Y1 + 1.7, C_Y1 + 1.9, 0.0, 3.75, M["metal_acero"]))
    return parts


def build_library_tower(M):
    """Nivel 3: biblioteca acristalada sobre la facultad central y torre de reloj detrás, el remate."""
    parts = []
    # Biblioteca: cuerpo de ladrillo retranqueado, con ventanal corrido de lectura y cornisa de caliza.
    parts.append(slab("library", -6.4, 2.4, -8.6, -3.2, C_H, 18.1, M["brick"]))
    parts.append(slab("library_glass", -5.8, 1.8, -8.66, -8.54, 15.0, 17.4, M["glass"]))
    for x in (-4.2, -2.2, -0.2, 1.4):
        parts.append(slab("library_mullion", x - 0.07, x + 0.07, -8.71, -8.49, 15.0, 17.4, M["metal_acero"]))
    parts.append(slab("library_head", -6.0, 2.0, -8.7, -8.5, 17.4, 17.75, M["limestone"]))
    parts.append(slab("library_sill", -6.0, 2.0, -8.75, -8.45, 14.8, 15.0, M["limestone"]))
    parts.append(slab("library_cornice", -6.6, 2.6, -8.8, -3.0, 18.1, 18.45, M["limestone"]))
    parts.append(slab("library_roof", -6.1, 2.1, -8.3, -3.5, 18.45, 18.65, M["slate"]))

    # Torre de reloj: basa de caliza, fuste de ladrillo, campanario y capitel de pizarra, detrás de la
    # biblioteca para que ésta se lea entera desde la calle.
    parts.append(slab("clock_base", -3.1, 1.3, -3.0, 1.4, C_H, 15.1, M["limestone"]))
    parts.append(slab("clock_shaft", -3.0, 1.2, -2.9, 1.3, 15.1, 22.4, M["brick"]))
    parts.append(slab("clock_band", -3.15, 1.35, -3.05, 1.45, 22.4, 22.8, M["limestone"]))
    parts.append(slab("clock_belfry", -2.9, 1.1, -2.8, 1.2, 22.8, 25.0, M["limestone"]))
    parts.append(slab("clock_glass", -2.2, 0.4, -2.86, -2.74, 23.5, 24.9, M["glass"]))
    for x in (-1.7, -0.1):
        parts.append(slab("clock_mullion", x - 0.06, x + 0.06, -2.9, -2.72, 23.5, 24.9, M["metal_acero"]))
    parts.append(slab("clock_cornice", -3.25, 1.45, -3.15, 1.55, 25.0, 25.4, M["limestone"]))
    parts.append(pyramid("clock_cap", 3.25, 1.6, (-0.9, -0.8, 26.2), M["slate"]))
    parts.append(cylinder("clock_finial", 0.35, 0.8, (-0.9, -0.8, 27.4), M["metal_cobre"], 8, True))
    parts.append(cylinder("clock_face", 1.1, 0.16, (-0.9, -2.98, 20.6), M["limestone"], 12, True, (math.pi / 2, 0.0, 0.0)))
    parts.append(slab("clock_hand_min", -0.96, -0.84, -3.12, -3.06, 20.6, 21.5, M["slate"]))
    parts.append(slab("clock_hand_hour", -0.9, -0.35, -3.12, -3.06, 20.55, 20.67, M["slate"]))
    return parts


def build_pavilion(M):
    """Nivel 4: pabellón de una facultad nueva, retranqueado junto a la cancha, con tejado a dos aguas."""
    parts = []
    cuts = []
    box_x0, box_x1 = 10.8, 16.0
    box_y0, box_y1 = -1.8, 1.2
    body = slab("pavilion", box_x0, box_x1, box_y0, box_y1, 0.0, 5.4, M["brick"])
    for x in (11.6, 13.2):
        window_unit(parts, cuts, M, x, 1.2, 1.4, 4.5, box_y0, depth=1.6)
    cuts.append(box("door_cut", (1.1, 1.6, 3.7), (14.9, box_y0 + 0.25, 1.85)))
    perforate(body, cuts)
    parts.append(body)

    plinth = slab("pavilion_plinth", box_x0 - 0.1, box_x1 + 0.1, box_y0 - 0.1, box_y1 + 0.1, 0.0, 0.6, M["limestone"])
    perforate(plinth, [box("door_cut2", (1.1, 1.6, 3.7), (14.9, box_y0 + 0.25, 1.85))])
    parts.append(plinth)
    parts.append(slab("pavilion_cornice", box_x0 - 0.12, box_x1 + 0.12, box_y0 - 0.12, box_y1 + 0.12, 5.2, 5.4, M["limestone"]))
    parts.append(gable("pavilion_roof", box_x0 - 0.2, box_x1 + 0.25, box_y0 - 0.3, box_y1 + 0.25, 5.4, 6.8, M["slate"]))

    # Puerta de cristal con jambas y dintel de acero.
    parts.append(slab("pavilion_door_glass", 14.42, 15.38, box_y0 + 0.45, box_y0 + 0.55, 0.0, 3.55, M["glass"]))
    for x in (14.35, 15.45):
        parts.append(slab("pavilion_door_jamb", x - 0.07, x + 0.07, box_y0 + 0.2, box_y0 + 0.5, 0.0, 3.6, M["metal_acero"]))
    parts.append(slab("pavilion_door_head", 14.3, 15.5, box_y0 + 0.2, box_y0 + 0.5, 3.5, 3.68, M["metal_acero"]))
    return parts


def build_auditorium(M):
    """Nivel 5: torre del auditorio sobre la facultad del este, con campanario y remate de cobre."""
    parts = []
    parts.append(slab("aud_base", 8.4, 13.6, 2.4, 7.6, E_H, 11.1, M["limestone"]))
    parts.append(slab("aud_shaft", 8.6, 13.4, 2.6, 7.4, 11.1, 23.2, M["brick"]))
    parts.append(slab("aud_band", 8.45, 13.55, 2.45, 7.55, 23.2, 23.6, M["limestone"]))
    parts.append(slab("aud_floor", 8.3, 13.7, 2.3, 7.7, 23.6, 24.0, M["limestone"]))
    for x0, x1 in ((8.4, 9.1), (12.9, 13.6)):
        for y0, y1 in ((2.4, 3.1), (6.9, 7.6)):
            parts.append(slab("aud_post", x0, x1, y0, y1, 24.0, 27.0, M["limestone"]))
    parts.append(slab("aud_glass", 9.0, 13.0, 3.0, 7.0, 24.0, 27.0, M["glass"]))
    parts.append(slab("aud_lintel_s", 8.4, 13.6, 2.4, 3.1, 27.0, 27.5, M["limestone"]))
    parts.append(slab("aud_lintel_n", 8.4, 13.6, 6.9, 7.6, 27.0, 27.5, M["limestone"]))
    parts.append(slab("aud_lintel_w", 8.4, 9.1, 3.1, 6.9, 27.0, 27.5, M["limestone"]))
    parts.append(slab("aud_lintel_e", 12.9, 13.6, 3.1, 6.9, 27.0, 27.5, M["limestone"]))
    parts.append(slab("aud_cornice", 8.2, 13.8, 2.2, 7.8, 27.5, 27.85, M["metal_cobre"]))
    parts.append(pyramid("aud_crown", 4.1, 5.0, (11.0, 5.0, 30.35), M["metal_cobre"]))
    parts.append(cylinder("aud_finial", 0.4, 0.8, (11.0, 5.0, 33.25), M["metal_cobre"], 8, True))
    return parts


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
        name = f"caldas_{layer}_{rbx.lower()}{suffix}"
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
    sun.rotation_euler = (math.radians(90 - 34.0), 0, math.radians(38))
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
    builders = {1: build_porch, 2: build_labs, 3: build_library_tower, 4: build_pavilion, 5: build_auditorium}
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
    lod = lod_of(objects, "caldas_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "caldas_LOD1.fbx")

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
    print("CALDAS_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    body_top = levels["0"]["limites"]["alto_maximo_sobre_suelo"]
    if abs(body_top - C_H) > 0.01:
        raise RuntimeError(f"El cuerpo mide {body_top} y debería medir {C_H}")
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "caldas.blend"))

    markers = {
        kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["metal_acero"], "gold": M["metal_cobre"]})
        for kind in ("house", "hotel", "tower")
    }
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -185.0, 112.0), (0.0, 20.0, 9.0), 30), f"{RENDER_SUBDIR}/caldas-niveles.png")

    # Comparación: nivel 0 frente a un bloque de Bodega (13) y otro de Cine Lux (24), con un avatar de 6.
    hide_all()
    box("ground", (150, 40, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -40.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (40, 0, 12.0), M["block"])
    box("avatar_ref", (1.4, 1.0, 6.0), (-40.4, -9.9, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -150.0, 30.0), (0.0, 0.0, 9.0), 42), f"{RENDER_SUBDIR}/caldas-comparacion.png")
    print("CALDAS_DONE")


if __name__ == "__main__":
    main()

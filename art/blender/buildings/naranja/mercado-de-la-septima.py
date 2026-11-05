"""Mercado de la Séptima: mercado de abastos de la zona Naranja (Feria Naranja), modelado desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18 menos el retranqueo de fachada, que deja
sitio al vuelo de los toldos; el frente da a -Y y el origen está en el centro de la base. Cuerpo de nave de
hierro y cristal sobre base de ladrillo, con reloj sobre el portalón y cumbrera a 17; cinco añadidos que se
suman: toldos y puestos, ventanales con mejora de fachada, linterna, pabellón de cámaras y torre del reloj
con remate de cobre. Sigue el método de barberia-morro.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/naranja/:
  mercado-de-la-septima.blend                 escena de revisión (no se versiona)
  mercado-de-la-septima/mercado_<pieza>_<material>.fbx y mercado_LOD1.fbx
  mercado-de-la-septima/stats.json            triángulos por pieza y nivel, límites y materiales
Y en art/render/naranja/mercado-de-la-septima/: mercado-de-la-septima-niveles.png y
mercado-de-la-septima-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/naranja/mercado-de-la-septima.py
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
OUT = os.path.join(HERE, "mercado-de-la-septima")
RENDER_SUBDIR = "naranja/mercado-de-la-septima"
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

# --- Solar y cuerpo -----------------------------------------------------------------------------
WIDTH = 32.0
DEPTH = 17.8  # de -8,8 a 9,0: la fachada se retranquea 1,2 para que el toldo no pase de -10
FRONT = -8.8
BACK = 9.0
MID_Y = (FRONT + BACK) / 2.0
NAVE_W = 20.0  # nave central de hierro y cristal
AISLE_W = 6.0  # naves laterales bajas, con los puestos abiertos a la calle
AISLE_IN = NAVE_W / 2.0
AISLE_OUT = WIDTH / 2.0
EAVE_Z = 12.0  # arranque de la cubierta de la nave
RIDGE_Z = 17.0  # altura del cuerpo: cumbrera
ROOF_PITCH = (RIDGE_Z - EAVE_Z) / (NAVE_W / 2.0)
ROOF_ANGLE = math.atan(ROOF_PITCH)
AISLE_TOP_IN = 7.9
AISLE_TOP_OUT = 7.0
AISLE_BOX_H = 8.6

# --- Entrada ------------------------------------------------------------------------------------
PORTAL_W = 9.0  # portalón de mercado, no puerta de tienda
PORTAL_APEX = 7.4  # más alto que el avatar de 6
PORTAL_SPRING = 6.6  # arranque del arco rebajado
RECESS = 1.8  # hornacina del portalón
CUT_Y = FRONT + RECESS / 2.0 - 0.3
CUT_D = RECESS + 0.6
WINDOW_W = 2.8
WINDOW_X = 7.1
WINDOW_Z0 = 2.1
WINDOW_Z1 = 6.5
BAY_W = 4.6
BAY_H = 4.4

# --- Rótulo y reloj -----------------------------------------------------------------------------
SIGN_Z = 9.7
SIGN_W = 17.0
SIGN_H = 2.3
SIGN_TEXT = "MERCADO DE LA SÉPTIMA"
SIGN_SIZE = 1.12
CLOCK_Z = 14.6
CLOCK_R = 1.42

# --- Añadidos -----------------------------------------------------------------------------------
AWNING_RUN = 1.1
LANTERN_X, LANTERN_Y = 0.0, -1.5
TOWER_X, TOWER_Y = 0.0, 3.4
TOWER_TOP = 34.0  # altura máxima del conjunto con el nivel 5
MAX_LEVEL0 = 22.0  # el nivel 0 completo no puede crecer por encima de la calle

# --- Escena de calle ----------------------------------------------------------------------------
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
AVATAR_HEIGHT = 6.0
CINE_LUX_L5_TRIANGLES = 3042

# Material de Roblox, sufijo de color y RGB de cada material de Blender.
RBX = {
    "brick": ("Brick", "", "B0664A"),
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "wood": ("Wood", "", "6B4A2E"),
    "fabric_rojo": ("Fabric", "_rojo", "C4382B"),
    "metal_acero": ("Metal", "_acero", "A8AEB4"),
    "metal_oro": ("Metal", "_oro", "C9A227"),
    "metal_naranja": ("Metal", "_naranja", "F59E0B"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "wood": flat("wood", "6B4A2E", 0.7),
        "fabric_rojo": flat("fabric_rojo", "C4382B", 0.8),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.4, 0.9),
        "metal_oro": flat("metal_oro", "C9A227", 0.3, 0.9),
        "metal_naranja": flat("metal_naranja", "F59E0B", 0.4, 0.85),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "F59E0B", 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "6E747C", 0.8),
    }


def cylinder(name, radius, depth, location, mat, verts=12, caps=True, axis="Z"):
    """Cilindro con el eje vertical o mirando a la calle (-Y), para las esferas de los relojes."""
    rotation = (math.pi / 2, 0.0, 0.0) if axis == "Y" else (0.0, 0.0, 0.0)
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


def cone(name, radius, depth, location, mat, verts=4):
    """Pirámide de base cuadrada, para el remate de cobre de la torre y de la linterna."""
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts,
        radius1=radius,
        radius2=0.0,
        depth=depth,
        location=location,
        rotation=(0.0, 0.0, math.radians(45)),
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def beam(name, a, b, thick, mat):
    """Barra cuadrada entre dos puntos (cercha, montante o aguja del reloj)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    obj = box(name, (thick, d.length, thick), tuple((a + b) / 2.0), mat)
    obj.rotation_euler = Vector((0.0, 1.0, 0.0)).rotation_difference(d.normalized()).to_euler()
    return obj


def slope_slab(name, a, b, y_mid, y_span, thickness, embed, mat):
    """Losa de cubierta entre dos puntos (x, z) del plano, con la cara inferior apoyada en él."""
    dx, dz = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dz)
    ux, uz = dx / length, dz / length
    nx, nz = -uz, ux
    if nz < 0:
        nx, nz = -nx, -nz
    angle = math.atan2(-uz, ux)
    centre = (a[0] + dx / 2.0 + nx * (thickness / 2.0 - embed), y_mid, a[1] + dz / 2.0 + nz * (thickness / 2.0 - embed))
    obj = box(name, (length, y_span, thickness), centre, mat)
    obj.rotation_euler = (0.0, angle, 0.0)
    return obj


def slope_cutter(name, x_mid, z_mid, side, angle):
    """Bloque enorme apoyado en un faldón: quita todo lo que sobresale del plano."""
    normal = Vector((side * math.sin(angle), 0.0, math.cos(angle)))
    centre = Vector((x_mid, 0.0, z_mid)) + normal * 20.0
    obj = box(name, (220.0, 220.0, 40.0), tuple(centre))
    obj.rotation_euler = (0.0, side * angle, 0.0)
    return obj


def arch_cutter(name, width, spring, apex, y, depth):
    """Recorte de arco rebajado: media lente por encima del arranque, recortada al ancho del portalón."""
    rise = apex - spring
    radius = (width**2 / 4.0 + rise**2) / (2.0 * rise)
    centre_z = apex - radius
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=24,
        radius=radius,
        depth=depth,
        end_fill_type="NGON",
        location=(0.0, y, centre_z),
        rotation=(math.pi / 2, 0.0, 0.0),
    )
    lens = bpy.context.active_object
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, y, spring + (rise + 0.4) / 2.0))
    cap = bpy.context.active_object
    cap.scale = (width, depth + 0.4, rise + 0.4)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.select_all(action="DESELECT")
    lens.select_set(True)
    bpy.context.view_layer.objects.active = lens
    boolean = lens.modifiers.new("clip", "BOOLEAN")
    boolean.operation = "INTERSECT"
    boolean.object = cap
    bpy.ops.object.modifier_apply(modifier=boolean.name)
    bpy.data.objects.remove(cap, do_unlink=True)
    lens.name = name
    return lens


def awning(name, x, width, z_top, run, drop, mat):
    """Toldo de lona: panel inclinado desde la fachada y faldón vertical en el borde."""
    angle = math.atan2(drop, run)
    length = math.hypot(run, drop)
    panel = box(name, (width, length, 0.12), (x, FRONT - run / 2.0, z_top - drop / 2.0), mat)
    panel.rotation_euler = (angle, 0.0, 0.0)
    tip = z_top - drop
    valance = box(name + "_valance", (width, 0.1, 0.4), (x, FRONT - run, tip - 0.2), mat)
    return [panel, valance]


def clock_face(parts, M, centre, radius):
    """Reloj de esfera de caliza con las agujas en pizarra: se lee a la distancia del juego."""
    x, y, z = centre
    parts.append(cylinder("clock_dial", radius, 0.5, (x, y, z), M["limestone"], 12, True, "Y"))
    face = y - 0.29
    parts.append(beam("clock_minute", (x, face, z), (x + radius * 0.55, face, z + radius * 0.82), 0.1, M["slate"]))
    parts.append(beam("clock_hour", (x, face, z), (x - radius * 0.52, face, z + radius * 0.34), 0.12, M["slate"]))


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
    """Nivel 0: nave de ladrillo con cubierta de hierro y cristal, portalón en arco, reloj y rótulo."""
    parts = []

    # Zócalo de caliza, abierto en el portalón y en los puestos.
    plinth = box("plinth", (WIDTH + 0.4, DEPTH + 0.4, 0.7), (0.0, MID_Y, 0.35), M["limestone"])
    plinth_cuts = [box("plinth_cut", (PORTAL_W, CUT_D, 7.0), (0.0, CUT_Y, 3.3))]
    for side in (-1, 1):
        plinth_cuts.append(box("plinth_bay", (BAY_W, CUT_D, 5.0), (side * (AISLE_IN + AISLE_OUT) / 2.0, CUT_Y, 2.3)))
    perforate(plinth, plinth_cuts)
    parts.append(plinth)

    # Nave central: masa de ladrillo con huecos de verdad (portalón y dos ventanales).
    cuts = [
        box("portal_cut", (PORTAL_W, CUT_D, PORTAL_SPRING), (0.0, CUT_Y, PORTAL_SPRING / 2.0)),
        arch_cutter("portal_arch", PORTAL_W, PORTAL_SPRING, PORTAL_APEX, CUT_Y, CUT_D),
    ]
    for side in (-1, 1):
        cuts.append(
            box("win_cut", (WINDOW_W, CUT_D, WINDOW_Z1 - WINDOW_Z0), (side * WINDOW_X, CUT_Y, (WINDOW_Z0 + WINDOW_Z1) / 2.0))
        )
    nave = box("nave", (NAVE_W, DEPTH, EAVE_Z), (0.0, MID_Y, EAVE_Z / 2.0), M["brick"])
    perforate(nave, cuts)
    parts.append(nave)

    # Naves laterales: ladrillo bajo, cubierta de pizarra inclinada hacia fuera y puesto abierto a la calle.
    aisle_angle = math.atan2(AISLE_TOP_IN - AISLE_TOP_OUT, AISLE_OUT - AISLE_IN)
    for side in (-1, 1):
        x_mid = side * (AISLE_IN + AISLE_OUT) / 2.0
        aisle = box("aisle", (AISLE_W, DEPTH, AISLE_BOX_H), (x_mid, MID_Y, AISLE_BOX_H / 2.0), M["brick"])
        perforate(
            aisle,
            [
                box("bay_cut", (BAY_W, CUT_D, BAY_H), (x_mid, CUT_Y, BAY_H / 2.0)),
                slope_cutter("aisle_cut", x_mid, (AISLE_TOP_IN + AISLE_TOP_OUT) / 2.0, side, aisle_angle),
            ],
        )
        parts.append(aisle)
        parts.append(
            slope_slab(
                "aisle_roof",
                (side * AISLE_IN, AISLE_TOP_IN),
                (side * AISLE_OUT, AISLE_TOP_OUT),
                MID_Y,
                DEPTH + 0.2,
                0.32,
                0.02,
                M["slate"],
            )
        )
        # Puestos: mostrador de tablón y cajas, dentro de la hornacina abierta a la calle.
        parts.append(box("stall_counter", (BAY_W - 0.4, 1.1, 1.15), (x_mid, FRONT + 1.15, 0.575), M["wood"]))
        parts.append(box("stall_crate", (1.0, 0.8, 0.8), (x_mid - 1.1, FRONT + 1.15, 1.55), M["wood"]))
        parts.append(box("stall_crate2", (0.9, 0.7, 0.7), (x_mid + 0.8, FRONT + 1.1, 1.5), M["wood"]))
        parts.append(box("aisle_quoin", (0.7, 0.45, AISLE_TOP_OUT - 0.5), (side * (AISLE_OUT - 0.3), FRONT - 0.15, (AISLE_TOP_OUT - 0.5) / 2.0), M["limestone"]))
        parts.append(box("bay_lintel", (BAY_W + 0.6, 0.4, 0.4), (x_mid, FRONT - 0.1, BAY_H + 0.2), M["limestone"]))

    # Cornisa de caliza y cubierta de hierro y cristal con sus cerchas y junquillos.
    parts.append(box("cornice", (NAVE_W + 0.9, DEPTH + 0.3, 0.6), (0.0, MID_Y, EAVE_Z - 0.55), M["limestone"]))
    for side in (-1, 1):
        parts.append(slope_slab("nave_glass", (0.0, RIDGE_Z), (side * AISLE_IN, EAVE_Z), MID_Y, DEPTH - 0.1, 0.16, 0.0, M["glass"]))
        for order, y in enumerate((-6.6, -2.2, 2.2, 6.6)):
            parts.append(
                slope_slab(f"roof_rib{order}", (0.0, RIDGE_Z), (side * AISLE_IN, EAVE_Z), y, 0.26, 0.26, -0.2, M["metal_acero"])
            )
        parts.append(box("eave_bar", (0.3, DEPTH + 0.2, 0.28), (side * AISLE_IN, MID_Y, EAVE_Z + 0.02), M["metal_acero"]))
    parts.append(box("ridge_bar", (0.45, DEPTH + 0.1, 0.4), (0.0, MID_Y, RIDGE_Z + 0.1), M["metal_acero"]))

    # Hastiales: el de la calle es de cristal con cercha de acero; el del fondo cierra la nave.
    gable = box("gable_glass", (NAVE_W, 0.35, RIDGE_Z - EAVE_Z), (0.0, FRONT, (EAVE_Z + RIDGE_Z) / 2.0), M["glass"])
    perforate(gable, [slope_cutter("gable_cut_r", 0.0, RIDGE_Z, 1.0, ROOF_ANGLE), slope_cutter("gable_cut_l", 0.0, RIDGE_Z, -1.0, ROOF_ANGLE)])
    parts.append(gable)
    back = box("gable_back", (NAVE_W, 0.35, RIDGE_Z - EAVE_Z), (0.0, BACK, (EAVE_Z + RIDGE_Z) / 2.0), M["brick"])
    perforate(back, [slope_cutter("back_cut_r", 0.0, RIDGE_Z, 1.0, ROOF_ANGLE), slope_cutter("back_cut_l", 0.0, RIDGE_Z, -1.0, ROOF_ANGLE)])
    parts.append(back)
    parts.append(beam("truss_tie", (-9.3, FRONT - 0.35, EAVE_Z + 0.5), (9.3, FRONT - 0.35, EAVE_Z + 0.5), 0.5, M["metal_acero"]))
    parts.append(beam("truss_king", (0.0, FRONT - 0.35, EAVE_Z + 0.5), (0.0, FRONT - 0.35, RIDGE_Z - 0.2), 0.45, M["metal_acero"]))
    for side in (-1, 1):
        parts.append(
            beam("truss_strut", (side * 5.6, FRONT - 0.35, EAVE_Z + 0.5), (0.0, FRONT - 0.35, CLOCK_Z - 0.55), 0.32, M["metal_acero"])
        )

    # Reloj sobre la entrada, montado en el nudo de la cercha.
    clock_face(parts, M, (0.0, FRONT - 0.3, CLOCK_Z), CLOCK_R)

    # Rótulo: placa de pizarra con letras de caliza, por encima del portalón y del toldo.
    parts.append(box("sign_plate", (SIGN_W, 0.6, SIGN_H), (0.0, FRONT - 0.28, SIGN_Z), M["slate"]))
    parts.append(fit_width(letters(SIGN_TEXT, SIGN_SIZE, (0.0, FRONT - 0.68, SIGN_Z), M["limestone"], depth=0.2), SIGN_W - 1.6))

    # Portalón: jambas y dovelas de caliza, dos hojas de madera y montante de cristal.
    for side in (-1, 1):
        parts.append(
            box("portal_jamb", (0.55, 0.5, PORTAL_SPRING + 0.1), (side * (PORTAL_W / 2.0 + 0.12), FRONT - 0.15, (PORTAL_SPRING + 0.1) / 2.0), M["limestone"])
        )
    rise = PORTAL_APEX - PORTAL_SPRING
    radius = (PORTAL_W**2 / 4.0 + rise**2) / (2.0 * rise)
    centre_z = PORTAL_APEX - radius
    half_angle = math.asin((PORTAL_W / 2.0) / radius)
    for order in range(7):
        angle = -half_angle + (2.0 * half_angle) * order / 6.0
        x = (radius + 0.3) * math.sin(angle)
        z = centre_z + (radius + 0.3) * math.cos(angle)
        voussoir = box(f"voussoir{order}", (1.35, 0.45, 0.55), (x, FRONT - 0.15, z), M["limestone"])
        voussoir.rotation_euler = (0.0, angle, 0.0)
        parts.append(voussoir)
    parts.append(box("door_leaf_l", (PORTAL_W / 2.0 - 0.3, 0.22, PORTAL_SPRING - 0.1), (-PORTAL_W / 4.0, FRONT + RECESS - 0.2, (PORTAL_SPRING - 0.1) / 2.0), M["wood"]))
    parts.append(box("door_leaf_r", (PORTAL_W / 2.0 - 0.3, 0.22, PORTAL_SPRING - 0.1), (PORTAL_W / 4.0, FRONT + RECESS - 0.2, (PORTAL_SPRING - 0.1) / 2.0), M["wood"]))
    for z in (2.6, 4.9):
        parts.append(box("door_rail", (PORTAL_W - 0.7, 0.12, 0.28), (0.0, FRONT + RECESS - 0.34, z), M["wood"]))
    parts.append(box("fanlight", (PORTAL_W - 0.5, 0.16, 0.75), (0.0, FRONT + RECESS - 0.25, PORTAL_SPRING + 0.38), M["glass"]))

    # Ventanales de la nave a los lados del portalón y pilastras de ladrillo en las esquinas.
    for side in (-1, 1):
        x = side * WINDOW_X
        parts.append(box("win_glass", (WINDOW_W - 0.3, 0.14, WINDOW_Z1 - WINDOW_Z0 - 0.3), (x, FRONT + 0.6, (WINDOW_Z0 + WINDOW_Z1) / 2.0), M["glass"]))
        parts.append(box("win_sill", (WINDOW_W + 0.5, 0.5, 0.3), (x, FRONT - 0.05, WINDOW_Z0 - 0.15), M["limestone"]))
        parts.append(box("win_head", (WINDOW_W + 0.5, 0.5, 0.3), (x, FRONT - 0.05, WINDOW_Z1 + 0.15), M["limestone"]))
        parts.append(box("win_mullion", (0.22, 0.35, WINDOW_Z1 - WINDOW_Z0), (x, FRONT - 0.12, (WINDOW_Z0 + WINDOW_Z1) / 2.0), M["metal_acero"]))
        parts.append(box("nave_pilaster", (0.8, 0.45, EAVE_Z - 1.4), (side * (NAVE_W / 2.0 - 0.45), FRONT - 0.2, (EAVE_Z - 1.4) / 2.0), M["brick"]))
        parts.append(box("pilaster_cap", (1.0, 0.6, 0.35), (side * (NAVE_W / 2.0 - 0.45), FRONT - 0.2, EAVE_Z - 1.25), M["limestone"]))
    return parts


def build_awning(M):
    """Nivel 1: toldos de lona sobre el portalón y los puestos, y mesas de tablón con cajas."""
    parts = []
    parts.extend(awning("awning_portal", 0.0, 13.0, 8.4, AWNING_RUN, 0.75, M["fabric_rojo"]))
    for side in (-1, 1):
        x = side * (AISLE_IN + AISLE_OUT) / 2.0
        parts.extend(awning("awning_stall", x, 5.4, 4.9, AWNING_RUN, 0.65, M["fabric_rojo"]))
        parts.append(box("stall_table", (2.4, 1.0, 0.16), (x, FRONT - 0.62, 1.12), M["wood"]))
        parts.append(box("stall_leg_l", (0.16, 0.9, 1.04), (x - 1.0, FRONT - 0.62, 0.52), M["wood"]))
        parts.append(box("stall_leg_r", (0.16, 0.9, 1.04), (x + 1.0, FRONT - 0.62, 0.52), M["wood"]))
        parts.append(box("stall_basket", (0.9, 0.8, 0.5), (x + 0.55, FRONT - 0.62, 1.45), M["wood"]))
    return parts


def build_windows(M):
    """Nivel 2: ventanales de la nave y mejora de fachada de las naves laterales."""
    parts = []
    for side in (-1, 1):
        x = side * (AISLE_IN + AISLE_OUT) / 2.0
        # Galería acristalada sobre los puestos, con banco y dintel de caliza.
        parts.append(box("aisle_glass", (BAY_W + 0.4, 0.16, 1.25), (x, FRONT - 0.06, 5.72), M["glass"]))
        parts.append(box("aisle_sill", (BAY_W + 0.9, 0.45, 0.32), (x, FRONT - 0.12, 4.98), M["limestone"]))
        parts.append(box("aisle_head", (BAY_W + 0.9, 0.45, 0.32), (x, FRONT - 0.12, 6.46), M["limestone"]))
        for order in (-1, 1):
            parts.append(box("aisle_mullion", (0.2, 0.3, 1.25), (x + order * 1.5, FRONT - 0.14, 5.72), M["metal_acero"]))
        # Coping de caliza en el borde de la cubierta de pizarra.
        parts.append(box("aisle_coping", (0.6, DEPTH + 0.2, 0.45), (side * (AISLE_OUT - 0.25), MID_Y, AISLE_TOP_OUT + 0.18), M["limestone"]))
        # Clarestorio: banda de cristal sobre las naves laterales, con banco de caliza y montantes.
        parts.append(box("clerestory", (0.2, 13.4, 2.55), (side * (AISLE_IN + 0.05), MID_Y, 9.95), M["glass"]))
        parts.append(box("clerestory_sill", (0.45, 13.8, 0.35), (side * (AISLE_IN + 0.1), MID_Y, 8.5), M["limestone"]))
        parts.append(box("clerestory_head", (0.45, 13.8, 0.35), (side * (AISLE_IN + 0.1), MID_Y, 11.4), M["limestone"]))
        for order, y in enumerate((-4.0, 0.0, 4.0)):
            parts.append(box(f"clerestory_bar{order}", (0.26, 0.28, 2.55), (side * (AISLE_IN + 0.14), y, 9.95), M["metal_acero"]))
    return parts


def build_lantern(M):
    """Nivel 3: linterna acristalada en la cumbrera, con reloj y remate de cobre."""
    parts = []
    base_z = 15.6
    parts.append(box("lantern_base", (5.4, 5.4, 2.0), (LANTERN_X, LANTERN_Y, base_z + 1.0), M["limestone"]))
    parts.append(box("lantern_band", (5.6, 5.6, 0.26), (LANTERN_X, LANTERN_Y, base_z + 2.05), M["metal_naranja"]))
    parts.append(box("lantern_glass", (4.3, 4.3, 2.3), (LANTERN_X, LANTERN_Y, base_z + 3.35), M["glass"]))
    for dx, dy in ((-2.3, -2.3), (2.3, -2.3), (2.3, 2.3), (-2.3, 2.3)):
        parts.append(box("lantern_post", (0.4, 0.4, 2.5), (LANTERN_X + dx, LANTERN_Y + dy, base_z + 3.35), M["metal_acero"]))
    parts.append(box("lantern_cornice", (5.2, 5.2, 0.35), (LANTERN_X, LANTERN_Y, base_z + 4.65), M["limestone"]))
    parts.append(cone("lantern_cupola", 3.6, 1.5, (LANTERN_X, LANTERN_Y, base_z + 5.6), M["metal_oro"]))
    parts.append(cylinder("lantern_finial", 0.22, 0.7, (LANTERN_X, LANTERN_Y, base_z + 6.7), M["metal_oro"], 8, True))
    clock_face(parts, M, (LANTERN_X, LANTERN_Y - 2.35, base_z + 3.4), 1.05)
    return parts


def build_annex(M):
    """Nivel 4: pabellón de cámaras retranqueado en el fondo de la nave lateral derecha, con muelle de carga.

    El cuerpo va 0,05 por fuera del muro de la nave lateral y 0,05 por dentro del fondo: así no comparte
    ningún plano con ella y no aparece el rayado negro de las caras coincidentes.
    """
    parts = []
    x0, x1 = AISLE_IN + 0.02, AISLE_OUT + 0.12
    y0, y1 = 3.6, BACK - 0.05
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    parts.append(box("annex_body", (x1 - x0, y1 - y0, 12.2), (cx, cy, 6.1), M["brick"]))
    parts.append(box("annex_roof", (x1 - x0 + 0.5, y1 - y0 + 0.45, 0.35), (cx, cy - 0.05, 12.35), M["slate"]))
    parts.append(box("annex_band", (x1 - x0 + 0.4, y1 - y0 + 0.3, 0.3), (cx, cy, 9.6), M["limestone"]))
    parts.append(box("annex_door", (0.22, 3.4, 4.6), (x1 + 0.13, cy + 0.6, 2.3), M["wood"]))
    parts.append(box("annex_canopy", (1.9, 4.6, 0.28), (x1 + 0.9, cy + 0.6, 5.2), M["metal_acero"]))
    for side in (-1, 1):
        parts.append(box("canopy_post", (0.22, 0.22, 4.8), (x1 + 1.7, cy + 0.6 + side * 1.9, 2.4), M["metal_acero"]))
    parts.append(box("dock_platform", (1.7, 4.4, 1.0), (x1 + 0.7, cy + 0.6, 0.5), M["wood"]))
    return parts


def build_tower(M):
    """Nivel 5: torre del reloj sobre la cumbrera, con remate de cobre. Remata el conjunto.

    El fuste de ladrillo se para dentro del cuerpo del reloj: si sube hasta el campanario, que es más
    estrecho, lo tapa y el remate se lee como un bloque de ladrillo macizo.
    """
    parts = []
    shaft = 6.0
    parts.append(box("tower_shaft", (shaft, shaft, 13.4), (TOWER_X, TOWER_Y, 11.0 + 6.7), M["brick"]))
    parts.append(box("tower_string", (shaft + 0.5, shaft + 0.5, 0.45), (TOWER_X, TOWER_Y, 20.2), M["limestone"]))
    parts.append(box("tower_clock_stage", (shaft + 0.9, shaft + 0.9, 3.6), (TOWER_X, TOWER_Y, 26.0), M["limestone"]))
    clock_face(parts, M, (TOWER_X, TOWER_Y - (shaft + 0.9) / 2.0 - 0.12, 26.0), 1.6)
    parts.append(box("tower_band", (shaft + 1.2, shaft + 1.2, 0.3), (TOWER_X, TOWER_Y, 27.95), M["metal_oro"]))
    parts.append(box("tower_belfry", (shaft - 0.6, shaft - 0.6, 2.4), (TOWER_X, TOWER_Y, 29.3), M["glass"]))
    for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        parts.append(box("tower_post", (0.5, 0.5, 2.6), (TOWER_X + dx * (shaft - 0.6) / 2.0, TOWER_Y + dy * (shaft - 0.6) / 2.0, 29.3), M["limestone"]))
    parts.append(box("tower_cornice", (shaft + 0.6, shaft + 0.6, 0.4), (TOWER_X, TOWER_Y, 30.7), M["limestone"]))
    parts.append(cone("tower_cap", 4.2, 2.2, (TOWER_X, TOWER_Y, 32.0), M["metal_oro"]))
    parts.append(cylinder("tower_needle", 0.2, 0.7, (TOWER_X, TOWER_Y, 33.45), M["metal_oro"], 8, True))
    return parts


def group(level, parts, store):
    """Une las piezas de un nivel en una malla por material y color. En Roblox cada malla lleva un material."""
    layer = "body" if level == 0 else f"addon{level}"
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        for member in members:
            select_only(member)
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        rbx, suffix, rgb = RBX[key]
        name = f"mercado_{layer}_{rbx.lower()}{suffix}"
        # Unir un solo objeto no hace nada y Blender avisa «No mesh data to join»: se salta.
        mesh = join(members, name) if len(members) > 1 else members[0]
        mesh.name = name
        # El recorte booleano añade un hueco de material vacío: la pieza debe quedar con material único.
        for polygon in mesh.data.polygons:
            index = polygon.material_index
            if index >= len(mesh.data.materials) or mesh.data.materials[index] is None:
                polygon.material_index = 0
        for slot in reversed([i for i, material in enumerate(mesh.data.materials) if material is None]):
            mesh.data.materials.pop(index=slot)
        uv_unwrap(mesh)
        materials = {m.name for m in mesh.data.materials if m is not None}
        if len(materials) != 1 or len(mesh.data.materials) != 1:
            raise RuntimeError(f"{name} tiene {len(mesh.data.materials)} huecos de material: {materials}")
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

    # Ficha de referencia (caja oscura 8 × 4 × 5) y avatar de 6 de alto para la escala.
    box("ficha_ref", (8.0, 4.0, 5.0), (-2.5 * SPACING, SLOT_SIDE, 2.5), M["dark"])
    box("avatar_ref", (1.6, 1.2, AVATAR_HEIGHT), (-2.5 * SPACING + 2.6, lot_y - 9.0, AVATAR_HEIGHT / 2.0), M["avatar"])
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
    builders = {1: build_awning, 2: build_windows, 3: build_lantern, 4: build_annex, 5: build_tower}
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
    lod = lod_of(objects, "mercado_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "mercado_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "altura_cuerpo": RIDGE_Z,
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
    print("MERCADO_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if levels["0"]["limites"]["alto_maximo_sobre_suelo"] > MAX_LEVEL0:
        raise RuntimeError(f"El nivel 0 llega a {levels['0']['limites']['alto_maximo_sobre_suelo']} y la calle admite {MAX_LEVEL0}")
    if levels["5"]["limites"]["alto_maximo_sobre_suelo"] > TOWER_TOP:
        raise RuntimeError(f"La torre pasa de {TOWER_TOP}: {levels['5']['limites']['alto_maximo_sobre_suelo']}")
    if min(levels[str(level)]["limites"]["frente"] for level in range(6)) < -10.0:
        raise RuntimeError("Hay piezas delante de y = -10")

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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "mercado-de-la-septima.blend"))

    markers = {
        kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["metal_acero"], "gold": M["metal_oro"]})
        for kind in ("house", "hotel", "tower")
    }
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -176.0, 72.0), (0.0, 18.0, 10.0), 34), f"{RENDER_SUBDIR}/mercado-de-la-septima-niveles.png")

    # Comparación: nivel 0 frente a un bloque de Bodega (13) y otro de Cine Lux (24), con la figura de 6
    # delante de la fachada y al lado del portalón, para poder juzgar la puerta.
    hide_all()
    box("ground", (150, 44, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], -40.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (0, 0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (40, 0, 12.0), M["block"])
    box("figura_6", (1.6, 1.2, AVATAR_HEIGHT), (-40.0 + 5.4, -11.0, AVATAR_HEIGHT / 2.0), M["dark"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -132.0, 27.0), (0.0, 0.0, 9.0), 38), f"{RENDER_SUBDIR}/mercado-de-la-septima-comparacion.png")
    print("MERCADO_DONE")


if __name__ == "__main__":
    main()

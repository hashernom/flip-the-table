"""Plaza del Duelo: casilla especial «Duelo», modelada desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18; el frente da a -Y y el origen está en el
centro de la base, con z = 0 a ras de suelo. Alto máximo 16. Sin añadidos de nivel: la plaza es una sola
pieza, así que todas las mallas salen con nivel 0.

Concepto: recinto de caliza, ladrillo y pizarra. Una puerta monumental de 30 de ancho y 16 de alto —arco
rebajado de 20 de luz, dovelas de caliza, ático con el rótulo «DUELO»— cubre dos podios enfrentados de
2,2 de alto, con una franja central de 9,2 × 13,5 libre para dos avatares de 6 studs frente a frente. Al
fondo, un pabellón de ladrillo con dos puertas de 2,4 × 6,65, una por duelista: de cada puerta se sube a
su podio por unas gradas traseras. El suelo lleva un disco de caliza con anillo de pizarra en el centro.

Salidas, en art/blender/squares/:
  duelo.blend                          escena de revisión (no se versiona)
  duelo/duel_<material>.fbx             una malla, un material y un color por FBX
  duelo/duel_LOD1.fbx                   una sola malla y un solo material
  duelo/stats.json                      triángulos por pieza, total, LOD1 y medidas
Y en art/render/squares/duelo/: duelo-frontal.png, duelo-aereo.png y duelo-comparacion.png.

Nota de modelado: las dovelas y las hiladas de pizarra se solapan a propósito, así que su cara delantera
va escalonada 3 cm para que no queden dos caras coplanares: dos caras coincidentes se sombrean negras en
Cycles. La enjuta del arco es un solo prisma, no una fila de cajas, por el mismo motivo.

El LOD1 se modela aparte, con las masas simplificadas: decimar cajas sueltas al 42 % las rompe (les quita
caras y deja huecos). Modelado aparte queda en una malla limpia, un material y muy por debajo de la mitad.

Uso: blender --background --factory-startup --python art/blender/squares/duelo.py
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))  # art/blender/squares
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "duelo")
RENDER_SUBDIR = "squares/duelo"
sys.path.insert(0, SLICE)

# Helpers compartidos con los edificios ya en el juego (no se copian: se importan).
from build_cine_lux import (  # noqa: E402
    box,
    camera,
    count,
    flat,
    join,
    letters,
    render,
    select_only,
    textured,
    uv_unwrap,
)

# ---------------------------------------------------------------- medidas ---
WIDTH, DEPTH = 32.0, 18.0
FRONT, BACK = -DEPTH / 2, DEPTH / 2
PAVE = 0.30  # plataforma de la plaza: el resto de piezas apoya en ella

# Puerta monumental (arco rebajado con ático).
PORTAL_W, PORTAL_D = 30.0, 5.5
OPEN_HALF = 10.0  # luz del arco: 20
SPRING, APEX = 6.4, 10.2  # arranque y clave del intradós
RING = 2.0  # grosor radial de las dovelas
ATTIC_BOTTOM, ATTIC_TOP = 12.10, 14.40
CORNICE_TOP = 14.72
ROOF_EAVE, ROOF_RIDGE = 14.72, 15.78
SIGN_FACE = -3.10  # cara delantera de la placa del rótulo

# Podios enfrentados.
PODIUM_X, PODIUM_W, PODIUM_D = 7.4, 4.8, 7.4
PODIUM_CY = -1.5
PODIUM_TOP = PAVE + 2.45

# Pabellón del fondo, con las dos puertas.
PAVILION_HALF = 9.0
PAVILION_FRONT, PAVILION_BACK = 4.5, 9.0
PAVILION_TOP = 8.80
DOOR_W, DOOR_H = 2.4, 6.65
DOOR_X = 3.45

# Franja que debe quedar libre entre los podios (dos avatares de 6 frente a frente).
FREE = {"x": (-4.6, 4.6), "y": (-8.6, 4.3), "z": (0.55, 6.5)}

TRIANGLE_BUDGET = 3000

# Material de Roblox, sufijo de color y RGB de cada clave de material de Blender.
RBX = {
    "brick": ("Brick", "", "B0664A"),
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "wood": ("Wood", "", "6B4A2E"),
    "glass": ("Glass", "", "2E4A63"),
    "metal": ("Metal", "", "A8AEB4"),
    "fabric_rojo": ("Fabric", "_rojo", "C4382B"),
    "fabric_blanco": ("Fabric", "_blanco", "EDE5D3"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, asfalto, acera y figuras."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "wood": flat("wood", "6B4A2E", 0.7),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "metal": flat("metal", "A8AEB4", 0.25, 0.8),
        "fabric_rojo": flat("fabric_rojo", "C4382B", 0.8),
        "fabric_blanco": flat("fabric_blanco", "EDE5D3", 0.8),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "avatar": flat("avatar", "6E747C", 0.8),
        "avatar_b": flat("avatar_b", "8A7460", 0.8),
    }


def cylinder(name, radius, depth, location, mat, verts=24):
    """Cilindro vertical con tapas: el disco del centro de la plaza."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def mesh_object(name, vertices, faces, mat):
    """Malla suelta a partir de vértices y caras, con las normales recalculadas hacia fuera."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.validate()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def prism(name, points, y_front, y_back, mat):
    """Prisma vertical desde un polígono en XZ: la enjuta del arco sale de una pieza."""
    count = len(points)
    vertices = [(x, y_front, z) for x, z in points] + [(x, y_back, z) for x, z in points]
    faces = [list(range(count)), list(range(count, 2 * count))]
    for index in range(count):
        nxt = (index + 1) % count
        faces.append([index, nxt, count + nxt, count + index])
    return mesh_object(name, vertices, faces, mat)


def pyramid(name, width, depth, base_z, apex_z, location, mat):
    """Pirámide de base rectangular: tejado a cuatro aguas del pabellón."""
    half_x, half_y = width / 2.0, depth / 2.0
    vertices = [
        (-half_x, -half_y, base_z),
        (half_x, -half_y, base_z),
        (half_x, half_y, base_z),
        (-half_x, half_y, base_z),
        (0.0, 0.0, apex_z),
    ]
    faces = [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (3, 2, 1, 0)]
    obj = mesh_object(name, vertices, faces, mat)
    obj.location = location
    return obj


# ------------------------------------------------------------------ arco ----
def arch_geometry(half_span, spring, apex):
    """Radio, centro y ángulo de arranque de un arco rebajado que pasa por (0, apex) y (±span, spring)."""
    rise = apex - spring
    radius = (half_span ** 2 + rise ** 2) / (2.0 * rise)
    z_centre = apex - radius
    phi_spring = math.atan2(spring - z_centre, half_span)
    return radius, z_centre, phi_spring


def arch_ring(parts, mat, segments=19, ring=RING, depth=PORTAL_D, y=0.0, tag="voussoir"):
    """Dovelas: cajas giradas siguiendo el intradós. Se solapan y se escalonan para no dar caras coplanares."""
    radius, z_centre, phi_spring = arch_geometry(OPEN_HALF, SPRING, APEX)
    step = (math.pi - 2.0 * phi_spring) / segments
    for index in range(segments):
        phi = phi_spring + (index + 0.5) * step
        mid = radius + ring / 2.0
        length = 2.0 * (radius + ring) * math.sin(step / 2.0) * 1.02
        thick = depth - (0.035 if index % 2 else 0.0)
        obj = box(
            f"{tag}{index}",
            (length, thick, ring),
            (mid * math.cos(phi), y, z_centre + mid * math.sin(phi)),
            mat,
        )
        obj.rotation_euler = (0, math.pi / 2.0 - phi, 0)
        parts.append(obj)


def spandrel_wall(parts, mat, top, segments=19, depth=PORTAL_D, y=0.0, tag="spandrel"):
    """Enjuta maciza entre la trasdós y el ático: un solo prisma, del arranque al arranque."""
    radius, z_centre, phi_spring = arch_geometry(OPEN_HALF, SPRING, APEX)
    outer = radius + RING
    phi_cross = math.asin((SPRING - z_centre) / outer)  # donde la trasdós corta el arranque
    points = [(-PORTAL_W / 2.0, SPRING)]
    for index in range(segments + 1):
        phi = (math.pi - phi_cross) - (math.pi - 2.0 * phi_cross) * index / segments
        points.append((outer * math.cos(phi), z_centre + outer * math.sin(phi)))
    points.extend([(PORTAL_W / 2.0, SPRING), (PORTAL_W / 2.0, top), (-PORTAL_W / 2.0, top)])
    parts.append(prism(f"{tag}_wall", points, y - depth / 2.0, y + depth / 2.0, mat))


# ------------------------------------------------------------------ piezas --
def build_paving(M):
    """Plataforma, bordillo, bandas del carril y disco central con anillo: el suelo de la plaza."""
    parts = [box("paving", (WIDTH, DEPTH, PAVE), (0, 0, PAVE / 2.0), M["limestone"])]
    for side in (-1, 1):
        parts.append(box("kerb_x", (0.55, DEPTH, 0.08), (side * (WIDTH / 2.0 - 0.275), 0, PAVE + 0.04), M["slate"]))
        parts.append(box("kerb_y", (WIDTH - 1.1, 0.55, 0.08), (0, side * (DEPTH / 2.0 - 0.275), PAVE + 0.04), M["slate"]))
        parts.append(box("lane_band", (0.45, 12.8, 0.06), (side * 4.7, -2.1, PAVE + 0.03), M["slate"]))
    parts.append(cylinder("duel_ring", 4.42, 0.06, (0, PODIUM_CY, PAVE + 0.03), M["slate"]))
    parts.append(cylinder("duel_disc", 4.0, 0.14, (0, PODIUM_CY, PAVE + 0.07), M["limestone"]))
    return parts


def build_portal(M):
    """Puerta monumental: dos estribos, arco de dovelas, ático con el rótulo y tejado de pizarra."""
    parts = []
    for side in (-1, 1):
        cx = side * 12.5
        parts.append(box("pier_plinth", (5.4, 6.1, 0.55), (cx, 0, PAVE + 0.275), M["limestone"]))
        parts.append(box("pier_shaft", (4.6, 5.5, 4.85), (cx, 0, 3.275), M["brick"]))
        for z in (2.0, 3.4, 4.8):
            parts.append(box("pier_band", (4.8, 5.62, 0.2), (cx, 0, z), M["limestone"]))
        parts.append(box("pier_impost", (5.3, 6.0, 0.70), (cx, 0, 6.05), M["limestone"]))

    arch_ring(parts, M["limestone"], segments=19, depth=PORTAL_D + 0.12)
    spandrel_wall(parts, M["brick"], ATTIC_BOTTOM + 0.05, segments=22)

    parts.append(box("attic", (PORTAL_W, 5.6, ATTIC_TOP - ATTIC_BOTTOM), (0, 0, (ATTIC_TOP + ATTIC_BOTTOM) / 2), M["limestone"]))
    parts.append(box("cornice", (PORTAL_W + 0.8, 6.2, CORNICE_TOP - ATTIC_TOP), (0, 0, (CORNICE_TOP + ATTIC_TOP) / 2), M["limestone"]))

    # Tejado a dos aguas con cinco hiladas de pizarra por faldón, escalonadas como las tejas.
    rise = ROOF_RIDGE - ROOF_EAVE
    run = 3.3
    slope = math.sqrt(rise ** 2 + run ** 2)
    angle = math.atan2(rise, run)
    for sign in (-1, 1):
        for course in range(5):
            along = (course + 0.5) * slope / 5.0
            lift = (4 - course) * 0.030
            slab = box(
                "roof_course",
                (PORTAL_W + 0.4, slope / 5.0 * 1.06, 0.18),
                (
                    0,
                    sign * along * math.cos(angle) - sign * lift * math.sin(angle),
                    ROOF_RIDGE - along * math.sin(angle) + lift * math.cos(angle),
                ),
                M["slate"],
            )
            slab.rotation_euler = (-sign * angle, 0, 0)
            parts.append(slab)
    parts.append(box("roof_ridge", (PORTAL_W + 0.6, 0.5, 0.22), (0, 0, ROOF_RIDGE + 0.11), M["slate"]))

    # Rótulo: placa de pizarra y letras de caliza en 3D, mirando a la calle.
    word = letters("DUELO", 2.6, (0, SIGN_FACE - 0.06, 13.25), M["limestone"], depth=0.2)
    corners = [word.matrix_world @ Vector(c) for c in word.bound_box]
    word_w = max(p.x for p in corners) - min(p.x for p in corners)
    word_h = max(p.z for p in corners) - min(p.z for p in corners)
    scale = min(1.0, 10.6 / word_w, 1.45 / word_h)
    if scale < 1.0:
        select_only(word)
        word.scale = (scale, scale, scale)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        word_w *= scale
        word_h *= scale
    parts.append(word)
    parts.append(box("sign_plate", (word_w + 2.4, 0.30, word_h + 0.62), (0, SIGN_FACE + 0.15, 13.25), M["slate"]))
    return parts


def build_podiums(M):
    """Dos podios enfrentados: pedestal con basa y cornisa, escalinata trasera, placa y pendón."""
    parts = []
    for side in (-1, 1):
        cx = side * PODIUM_X
        parts.append(box("podium_plinth", (4.8, 7.8, 0.45), (cx, PODIUM_CY, PAVE + 0.225), M["limestone"]))
        parts.append(box("podium_body", (4.2, 7.0, 1.55), (cx, PODIUM_CY, 0.75 + 0.775), M["brick"]))
        parts.append(box("podium_cap", (5.0, 7.8, 0.45), (cx, PODIUM_CY, 2.30 + 0.225), M["limestone"]))
        parts.append(box("podium_plaque", (1.6, 0.12, 0.9), (cx, PODIUM_CY - 3.5 + 0.14, 1.45), M["slate"]))
        # Gradas traseras: suben del suelo a la cara del podio, detrás de cada duelista.
        back = PODIUM_CY + PODIUM_D / 2.0
        for step in range(4):
            depth = 1.9 - 0.48 * step
            height = (PODIUM_TOP - PAVE) * (step + 1) / 4.0
            parts.append(box("podium_step", (4.8 - 0.04 * step, depth, height), (cx, back + depth / 2.0, PAVE + height / 2.0), M["limestone"]))
        # Pendón: un mástil sobre el podio, brazo volado y tela roja con vivo claro al pie.
        pole_x = cx + side * 1.5
        parts.append(box("banner_pole", (0.12, 0.12, 4.2), (pole_x, 0.6, PODIUM_TOP + 2.1), M["metal"]))
        parts.append(box("banner_arm", (1.85, 0.12, 0.12), (cx + side * 0.6, 0.6, PODIUM_TOP + 4.12), M["metal"]))
        parts.append(box("banner_cloth", (1.50, 0.07, 2.40), (cx + side * 0.62, 0.66, PODIUM_TOP + 2.85), M["fabric_rojo"]))
        parts.append(box("banner_hem", (1.50, 0.05, 0.30), (cx + side * 0.62, 0.72, PODIUM_TOP + 1.85), M["fabric_blanco"]))
    return parts


def build_pavilion(M):
    """Pabellón del fondo con las dos puertas de los duelistas y tejado de pizarra."""
    parts = []
    depth = PAVILION_BACK - PAVILION_FRONT
    parts.append(box("pavilion_mass", (2 * PAVILION_HALF, depth - 1.3, PAVILION_TOP - PAVE), (0, PAVILION_BACK - (depth - 1.3) / 2.0, (PAVILION_TOP + PAVE) / 2), M["brick"]))
    # Paramento delantero, partido por las dos puertas. Bajo el dintel, para no duplicar su cara.
    for x0, x1 in ((-PAVILION_HALF, -4.9), (-2.0, 2.0), (4.9, PAVILION_HALF)):
        width = x1 - x0
        parts.append(box("pavilion_front", (width, 1.3, 7.10 - PAVE), ((x0 + x1) / 2.0, PAVILION_FRONT + 0.65, (7.10 + PAVE) / 2), M["brick"]))
    parts.append(box("pavilion_lintel", (9.8, 1.3, PAVILION_TOP - 7.10), (0, PAVILION_FRONT + 0.65, (PAVILION_TOP + 7.10) / 2), M["brick"]))

    for side in (-1, 1):
        cx = side * DOOR_X
        parts.append(box("door_threshold", (2.9, 0.5, 0.15), (cx, PAVILION_FRONT + 0.15, PAVE + 0.075), M["limestone"]))
        for edge in (cx - 1.325, cx + 1.325):
            parts.append(box("door_reveal", (0.25, 1.0, DOOR_H), (edge, PAVILION_FRONT + 0.5, 0.45 + DOOR_H / 2.0), M["limestone"]))
        parts.append(box("door_soffit", (2.4, 1.0, 0.25), (cx, PAVILION_FRONT + 0.5, 6.975), M["limestone"]))
        parts.append(box("door_leaf", (DOOR_W, 0.16, DOOR_H), (cx, PAVILION_FRONT + 1.0, 0.45 + DOOR_H / 2.0), M["wood"]))
        parts.append(box("door_glass", (1.5, 0.06, 2.5), (cx, PAVILION_FRONT + 0.89, 5.0), M["glass"]))
        # Guardapolvo de caliza sobre cada puerta, con sus dos ménsulas.
        parts.append(box("door_hood", (3.6, 1.0, 0.22), (cx, PAVILION_FRONT + 0.05, 7.31), M["limestone"]))
        for corbel_x in (cx - 1.45, cx + 1.45):
            parts.append(box("door_corbel", (0.3, 0.6, 0.45), (corbel_x, PAVILION_FRONT + 0.2, 6.95), M["limestone"]))

    # Esquinales de caliza, 10 cm por delante del paramento para no coincidir con él.
    for side in (-1, 1):
        for z in (1.0, 2.7, 4.4, 6.1):
            parts.append(box("quoin", (0.7, 1.52, 0.6), (side * (PAVILION_HALF - 0.1), PAVILION_FRONT + 0.71, z), M["limestone"]))
    parts.append(box("pavilion_cornice", (2 * PAVILION_HALF + 0.8, 4.6, 0.3), (0, PAVILION_BACK - 2.3, PAVILION_TOP + 0.15), M["limestone"]))

    # Tejado a cuatro aguas: pirámide de pizarra sobre el alero.
    parts.append(pyramid("pavilion_roof", 2 * PAVILION_HALF + 1.2, 4.9, 0.0, 2.2, (0, PAVILION_BACK - 2.45, PAVILION_TOP + 0.3), M["slate"]))

    parts.append(box("chimney", (1.0, 1.0, 2.2), (-6.0, 7.6, 9.6), M["brick"]))
    parts.append(box("chimney_cap", (1.2, 1.2, 0.2), (-6.0, 7.6, 10.8), M["limestone"]))
    parts.append(box("finial", (0.22, 0.22, 0.7), (0, PAVILION_BACK - 2.45, PAVILION_TOP + 2.45), M["metal"]))
    return parts


def build_parapets(M):
    """Pretil de caliza con capuchón: cierra el recinto sin tapar los podios."""
    parts = []
    for side in (-1, 1):
        parts.append(box("parapet_side", (0.5, DEPTH, 1.25), (side * 15.65, 0, PAVE + 0.625), M["limestone"]))
        parts.append(box("parapet_cap", (0.7, DEPTH, 0.16), (side * 15.65, 0, PAVE + 1.33), M["limestone"]))
    for side in (-1, 1):
        parts.append(box("parapet_back", (6.4, 0.5, 1.25), (side * 12.2, 8.7, PAVE + 0.625), M["limestone"]))
        parts.append(box("parapet_back_cap", (6.6, 0.7, 0.16), (side * 12.2, 8.65, PAVE + 1.33), M["limestone"]))
    return parts


# ------------------------------------------------------------------ LOD1 ----
def build_lod1(M):
    """LOD1: masas simplificadas, una sola malla y un solo material (caliza)."""
    parts = [box("lod_paving", (WIDTH, DEPTH, PAVE), (0, 0, PAVE / 2.0), M["limestone"])]
    for side in (-1, 1):
        parts.append(box("lod_pier", (5.0, PORTAL_D, SPRING - PAVE), (side * 12.5, 0, (SPRING + PAVE) / 2.0), M["limestone"]))
        parts.append(box("lod_podium", (PODIUM_W + 0.2, PODIUM_D + 0.2, PODIUM_TOP - PAVE), (side * PODIUM_X, PODIUM_CY, (PODIUM_TOP + PAVE) / 2.0), M["limestone"]))
        parts.append(box("lod_parapet", (0.6, DEPTH, 1.4), (side * 15.65, 0, PAVE + 0.7), M["limestone"]))
    arch_ring(parts, M["limestone"], segments=7, depth=PORTAL_D + 0.12, tag="lod_voussoir")
    spandrel_wall(parts, M["limestone"], ATTIC_BOTTOM + 0.05, segments=7, tag="lod_spandrel")
    parts.append(box("lod_attic", (PORTAL_W, 5.6, ATTIC_TOP - ATTIC_BOTTOM), (0, 0, (ATTIC_TOP + ATTIC_BOTTOM) / 2.0), M["limestone"]))
    parts.append(box("lod_cornice", (PORTAL_W + 0.8, 6.2, CORNICE_TOP - ATTIC_TOP), (0, 0, (CORNICE_TOP + ATTIC_TOP) / 2.0), M["limestone"]))
    parts.append(box("lod_roof", (PORTAL_W + 0.6, 6.6, 1.0), (0, 0, 15.3), M["limestone"]))
    parts.append(box("lod_sign", (12.0, 0.3, 2.0), (0, SIGN_FACE + 0.15, 13.25), M["limestone"]))
    parts.append(box("lod_pavilion", (2 * PAVILION_HALF, PAVILION_BACK - PAVILION_FRONT, PAVILION_TOP - PAVE), (0, (PAVILION_FRONT + PAVILION_BACK) / 2.0, (PAVILION_TOP + PAVE) / 2.0), M["limestone"]))
    parts.append(pyramid("lod_pavilion_roof", 2 * PAVILION_HALF + 1.2, 4.9, 0.0, 2.2, (0, PAVILION_BACK - 2.45, PAVILION_TOP + 0.3), M["limestone"]))
    return parts


# --------------------------------------------------------------- montaje ----
def group(parts, store):
    """Une las piezas en una malla por material: cada FBX lleva una malla, un material y un color."""
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in sorted(by_material.items()):
        rbx, suffix, rgb = RBX[key]
        name = f"duel_{rbx.lower()}{suffix}"
        mesh = join(members, name)
        uv_unwrap(mesh)
        materials = {m.name for m in mesh.data.materials if m is not None}
        if len(materials) != 1:
            raise RuntimeError(f"{name} tiene {len(materials)} materiales")
        store.append({"key": name, "material": rbx, "rgb": rgb, "obj": mesh})


def bounds(objects):
    """Límites reales en studs, con las mallas en coordenadas de escena."""
    xs, ys, zs = [], [], []
    for obj in objects:
        for vertex in obj.data.vertices:
            point = obj.matrix_world @ vertex.co
            xs.append(point.x)
            ys.append(point.y)
            zs.append(point.z)
    return {
        "ancho": round(max(xs) - min(xs), 2),
        "fondo": round(max(ys) - min(ys), 2),
        "alto": round(max(zs) - min(zs), 2),
        "x": [round(min(xs), 2), round(max(xs), 2)],
        "y": [round(min(ys), 2), round(max(ys), 2)],
        "z": [round(min(zs), 2), round(max(zs), 2)],
    }


def free_zone_intrusions(objects):
    """Piezas que meten geometría en la franja libre entre los podios (vértices y centros de cara)."""
    def inside(point):
        return all(FREE[key][0] < point[i] < FREE[key][1] for i, key in enumerate(("x", "y", "z")))

    names = []
    for obj in objects:
        matrix = obj.matrix_world
        hit = any(inside(matrix @ vertex.co) for vertex in obj.data.vertices)
        if not hit:
            hit = any(inside(matrix @ polygon.center) for polygon in obj.data.polygons)
        if hit:
            names.append(obj.name)
    return sorted(set(names))


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


def export_lod1(M):
    """LOD1: una malla y un material. Se une lo simplificado y se comprueba que quede un solo material."""
    lod = join(build_lod1(M), "duel_LOD1")
    materials = {m.name for m in lod.data.materials if m is not None}
    if len(materials) != 1:
        raise RuntimeError(f"duel_LOD1 tiene {len(materials)} materiales")
    uv_unwrap(lod)
    return lod


# --------------------------------------------------------------- escena -----
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


def tree(x, y, M):
    box("trunk", (0.8, 0.8, 5.0), (x, y, 2.5), M["bark"])
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=4.2, location=(x, y, 8.0))
    bpy.context.active_object.data.materials.append(M["hedge"])


def lamp(x, y, M):
    box("lamp_post", (0.35, 0.35, 11.0), (x, y, 5.5), M["dark"])
    box("lamp_arm", (0.25, 2.4, 0.25), (x, y - 1.2, 11.0), M["dark"])
    box("lamp_head", (0.9, 1.2, 0.35), (x, y - 2.2, 10.9), M["cream"])


def figure(x, y, angle, mat):
    """Figura de 6 studs para leer la escala. Solo render: no se exporta."""
    cos, sin = math.cos(angle), math.sin(angle)

    def place(size, offset):
        ox, oy, oz = offset
        location = (x + ox * cos - oy * sin, y + ox * sin + oy * cos, PAVE + oz + size[2] / 2.0)
        obj = box("figure", size, location, mat)
        obj.rotation_euler = (0, 0, angle)
        return obj

    return [
        place((1.15, 0.90, 2.40), (0, 0, 0.0)),
        place((1.55, 1.00, 2.20), (0, 0, 2.40)),
        place((0.35, 0.75, 1.90), (0.95, 0, 2.55)),
        place((0.35, 0.75, 1.90), (-0.95, 0, 2.55)),
        place((0.95, 0.95, 1.05), (0, 0, 4.60)),
        place((1.10, 1.10, 0.35), (0, 0, 5.65)),
        place((0.85, 0.40, 0.10), (0, -0.55, 5.73)),
    ]


def street_stage(M):
    """Calle y solar de la escena de revisión: solo render, nunca se exporta."""
    box("road", (190, 34, 0.4), (0, -33, -0.2), M["asphalt"])
    box("kerb_near", (190, 0.5, 0.5), (0, -16.25, 0.0), M["limestone"])
    box("kerb_far", (190, 0.5, 0.5), (0, -49.75, 0.0), M["limestone"])
    box("walk_near", (190, 7, 0.4), (0, -13, 0.0), M["pavement"])
    box("walk_far", (190, 7, 0.4), (0, -53.5, 0.0), M["pavement"])
    box("lot", (WIDTH + 4, DEPTH + 4, 0.12), (0, 0, 0.06), M["pavement"])
    box("far", (190, 60, 0.2), (0, -86, -0.1), M["pavement"])
    dash = -95.0
    while dash < 95.0:
        box("dash", (5.0, 0.4, 0.04), (dash, -33, 0.02), M["cream"])
        dash += 11.0
    for x in (-26.0, 26.0):
        lamp(x, -14.0, M)
    for x in (-34.0, -18.0, 18.0, 34.0):
        tree(x, -53.5, M)
    lights_and_world()


# ------------------------------------------------------------ comprobación --
def verify_exports(expected):
    """Abre cada FBX de verdad y comprueba una malla, un material y los triángulos. Devuelve las medidas."""
    problems = []
    measured = {}
    for name, triangles in expected:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=os.path.join(OUT, name + ".fbx"), axis_forward="Z", axis_up="Y")
        meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
        if len(meshes) != 1:
            problems.append(f"{name}: {len(meshes)} mallas")
            continue
        mesh = meshes[0]
        materials = [slot.material for slot in mesh.material_slots if slot.material is not None]
        if len(materials) != 1:
            problems.append(f"{name}: {len(materials)} materiales")
        real = count(mesh)
        if real != triangles:
            problems.append(f"{name}: {real} triángulos, las cuentas dicen {triangles}")
        corners = [mesh.matrix_world @ Vector(c) for c in mesh.bound_box]
        measured[name] = {
            "triangulos": real,
            "materiales": len(materials),
            "x": [round(min(c.x for c in corners), 2), round(max(c.x for c in corners), 2)],
            "y": [round(min(c.y for c in corners), 2), round(max(c.y for c in corners), 2)],
            "z": [round(min(c.z for c in corners), 2), round(max(c.z for c in corners), 2)],
        }
    return problems, measured


def scene_checks(objects):
    """Límites del brief: huella, vuelos, suelo, altura y franja libre."""
    problems = []
    limits = bounds(objects)
    if limits["x"][0] < -16.0 - 0.05 or limits["x"][1] > 16.0 + 0.05:
        problems.append(f"ancho {limits['x']}: la huella llega a 32")
    if limits["y"][0] < -10.0 - 0.05:
        problems.append(f"vuelo delantero {limits['y'][0]}: el tope es -10")
    if limits["y"][1] > BACK + 0.05:
        problems.append(f"fondo {limits['y'][1]}: se sale del solar")
    if limits["z"][0] < -0.001:
        problems.append(f"baja del suelo: z {limits['z'][0]}")
    if limits["z"][1] > 16.0 + 0.001:
        problems.append(f"alto {limits['z'][1]}: el tope es 16")
    intruders = free_zone_intrusions(objects)
    if intruders:
        problems.append(f"entran en la franja libre: {', '.join(intruders)}")
    return problems, limits, intruders


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    scene.unit_settings.scale_length = 1.0
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(os.path.join(REPO, "art", "render", *RENDER_SUBDIR.split("/")), exist_ok=True)

    M = make_materials()
    raw = build_paving(M) + build_portal(M) + build_podiums(M) + build_pavilion(M) + build_parapets(M)
    problems, limits, intruders = scene_checks(raw)

    pieces = []
    group(raw, pieces)
    objects = [piece["obj"] for piece in pieces]
    total = sum(count(obj) for obj in objects)
    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")

    lod = export_lod1(M)
    lod_triangles = count(lod)

    for piece in pieces:
        export(piece["obj"], piece["key"] + ".fbx")
    export(lod, "duel_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "tipo": "casilla especial «Duelo»: sin añadidos de nivel, todo el modelo es el cuerpo",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "piezas": [
            {
                "clave": piece["key"],
                "nivel": 0,
                "material": piece["material"],
                "rgb": piece["rgb"],
                "triangulos": count(piece["obj"]),
            }
            for piece in pieces
        ],
        "total_triangulos": total,
        "presupuesto_triangulos": TRIANGLE_BUDGET,
        "lod1": {
            "clave": "duel_LOD1",
            "material": "Limestone",
            "rgb": "D2C9B4",
            "triangulos": lod_triangles,
            "porcentaje_del_total": round(100.0 * lod_triangles / total, 1),
            "mallas": 1,
            "materiales": 1,
        },
        "medidas": limits,
        "franja_libre": {
            "x": list(FREE["x"]),
            "y": list(FREE["y"]),
            "z": list(FREE["z"]),
            "piezas_dentro": intruders,
        },
        "puertas": [{"ancho": DOOR_W, "alto": DOOR_H, "clave": "duel_wood"}],
        "arco": {"luz": 2 * OPEN_HALF, "arranque": SPRING, "clave": APEX},
        "comprobaciones": problems,
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("DUELO_STATS", json.dumps({"total": total, "lod1": lod_triangles, "piezas": len(pieces)}, ensure_ascii=False))

    if lod_triangles >= total / 2.0:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_triangles} de {total}")

    # Escena de revisión y renders, con el LOD oculto y la plaza en su sitio.
    lod.hide_render = True
    lod.hide_viewport = True
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except Exception as error:  # el look puede no existir en otra versión de Blender
        print(f"DUELO_AVISO: sin el look AgX de la guía ({error}); se usa el de fábrica")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "duelo.blend"))

    def show(objs, visible):
        for obj in objs:
            obj.hide_render = not visible
            obj.hide_viewport = not visible

    show(objects, True)
    street_stage(M)
    figure(12.4, -7.4, 0.0, M["avatar"])
    duelists = figure(-2.3, PODIUM_CY, math.radians(90), M["avatar"]) + figure(2.3, PODIUM_CY, math.radians(-90), M["avatar_b"])
    show(duelists, False)

    render(scene, camera("frontal", (0.0, -54.0, 11.0), (0.0, -1.5, 7.0), 44), f"{RENDER_SUBDIR}/duelo-frontal.png")
    render(scene, camera("aereo", (0.0, -12.0, 66.0), (0.0, 1.5, 2.5), 48), f"{RENDER_SUBDIR}/duelo-aereo.png")
    show(duelists, True)
    render(scene, camera("comparacion", (34.0, -40.0, 24.0), (0.0, -1.5, 5.6), 45), f"{RENDER_SUBDIR}/duelo-comparacion.png")

    # Comprobación final: se abren las FBX exportadas y se miden de verdad.
    expected = [(piece["key"], count(piece["obj"])) for piece in pieces] + [("duel_LOD1", lod_triangles)]
    export_problems, measured = verify_exports(expected)
    stats["fbx_medidas"] = measured
    stats["comprobaciones"] = problems + export_problems
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    for problem in stats["comprobaciones"]:
        print("DUELO_PROBLEMA:", problem)
    print("DUELO_LIMITES", json.dumps(limits, ensure_ascii=False))
    if stats["comprobaciones"]:
        raise RuntimeError(f"{len(stats['comprobaciones'])} problemas de comprobación")
    print("DUELO_CHECK OK")


if __name__ == "__main__":
    main()

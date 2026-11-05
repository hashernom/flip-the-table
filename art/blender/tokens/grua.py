"""Ficha grua: token de vehiculo de remolque de Flip the Table.

Grua de plataforma amarilla y gris, caricaturesca y de juguete: cabina corta con capo, parabrisas
inclinado y ventanilla con marco oscuro; brazo de grua con polea, cable y gancho sobre la delantera de
la plataforma; plataforma trasera con barandilla de acero, compuerta trasera, tres ejes (6 ruedas) y arcos
de rueda recortados de verdad en la chapa. La placa del asiento va al final de la plataforma, sin que el
brazo ni el gancho la invadan. Sin marcas, logotipos ni matriculas reales.

Salidas, en art/blender/tokens/grua/:
  tow_body_<material>.fbx        carroceria, una malla por material (origen en el centro de la base)
  tow_plate.fbx                  placa de la plataforma, separada: se tine con el color del jugador
  tow_wheel_{fl,fr,rl,rr,ml,mr}.fbx  neumatico, con el origen en su eje de giro (eje X)
  tow_hub_{fl,fr,rl,rr,ml,mr}.fbx    tapacubos, en malla aparte, mismo origen y eje que su rueda
  tow_LOD1.fbx                   una sola malla y un solo material (amarillo)
  stats.json                     triangulos por pieza, total y LOD1, medidas, ejes y seat
Y en art/render/tokens/grua/: 3/4 frontal, 3/4 trasera y perfil con avatar de 6 studs sobre la placa.

Convenciones (como art/blender/slice/build_cine_lux.py): 1 unidad de Blender = 1 stud, el morro mira
a -Y, Z hacia arriba, origen en el centro de la base a ras de suelo, exportacion FBX Z Forward / Y Up.

Uso (segundo plano, sin abrir Blender):
  "D:\\blender\\blender.exe" --background --factory-startup --python art/blender/tokens/grua.py
"""

import glob
import json
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "grua")
RENDER = os.path.join(REPO, "art", "render", "tokens", "grua")

TOTAL_BUDGET = 3000
PART_BUDGET = 120  # rueda con su tapacubos
MAX_ANCHO, MAX_LARGO, MAX_ALTO = 6.5, 14.0, 7.0
REF_TAXI = {"triangulos": 2580, "ancho_x": 6.4, "largo_y": 12.4, "alto_z": 5.1, "seat_z": 4.6}

# Ruedas: origen en el eje de giro, en studs, relativo a la base. l = -X, r = +X (de frente).
AXLE_X = 2.45
FRONT_Y, MID_Y, REAR_Y = -4.50, 2.05, 5.15
WHEEL_AXLES = {
    "fl": (-AXLE_X, FRONT_Y, 1.0),
    "fr": (AXLE_X, FRONT_Y, 1.0),
    "rl": (-AXLE_X, REAR_Y, 1.0),
    "rr": (AXLE_X, REAR_Y, 1.0),
    "ml": (-AXLE_X, MID_Y, 1.0),
    "mr": (AXLE_X, MID_Y, 1.0),
}
WHEEL_RADIUS = 1.0
WHEEL_DEPTH = 0.7
HUB_RADIUS = 0.42
HUB_DEPTH = 0.8
ARCH_RADIUS = 1.15  # arco recortado en la chapa alrededor del neumatico

# Cabina: corta. Morro -Y, capo corto, parabrisas inclinado y techo plano.
CAB_Y0, CAB_Y1 = -6.70, -2.56
CAB_HALF = 2.78
CAB_BOTTOM = 1.00
ROOF_Z = 4.92
WINDSHIELD_P0 = (-5.72, 3.08)
WINDSHIELD_P1 = (-4.90, 4.70)
WINDOW_Y = (-5.40, -3.60)
WINDOW_Z = (3.30, 4.62)

# Plataforma: suelo bajo y barandilla de acero, con los dos arcos traseros recortados en el lateral.
DECK_Y0, DECK_Y1 = -2.50, 6.90
DECK_HALF = 2.50
DECK_BOTTOM, DECK_TOP = 2.13, 2.55
SIDE_X0, SIDE_X1 = 2.50, 2.78
SIDE_TOP, SIDE_BOTTOM = 2.72, 1.05
RAIL_X0, RAIL_X1 = 2.44, 2.84
RAIL_TOP = 2.80

# Brazo: pivote sobre el pedestal, punta por encima de la plataforma delantera, gancho colgando.
BOOM_PIVOT = (-0.95, 3.75)
BOOM_TIP = (0.75, 6.72)
BOOM_HALF = 0.36
HOOK_X = 0.80

# Placa del asiento: 4,5 x 4,5 al final de la plataforma; nada encima de ella.
PLATE_SIZE = (4.5, 4.5, 0.12)
PLATE_CENTER = (0.0, 4.55, DECK_TOP + 0.06)
SEAT_Z = DECK_TOP + PLATE_SIZE[2]


def srgb(hex_color):
    def channel(value):
        value /= 255.0
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4

    return tuple(channel(int(hex_color[i : i + 2], 16)) for i in (0, 2, 4))


def flat(name, hex_color, roughness=0.5, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*srgb(hex_color), 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


def select_only(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.hide_viewport = False
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def apply_modifiers(obj):
    select_only(obj)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)


def box(name, size, location, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    # La posicion se hornea en la malla: el origen de cada pieza queda en el centro de la base.
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj


def panel(name, size, location, angle_x, mat):
    """Caja girada alrededor de X: sirve para las barras del parabrisas, en su plano inclinado."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    obj.rotation_euler = (angle_x, 0.0, 0.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(mat)
    return obj


def bevel(obj, width, segments=2):
    """Bisel en los bordes de angulo vivo (mas de 35 grados): redondea las formas grandes."""
    select_only(obj)
    modifier = obj.modifiers.new("Bevel", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(35)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def close_normals(obj):
    select_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def prism(name, points, x0, x1, mat):
    """Prisma recto entre los planos x = x0 y x = x1, con el perfil (y, z) indicado."""
    verts = [(x0, y, z) for y, z in points] + [(x1, y, z) for y, z in points]
    n = len(points)
    faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    return close_normals(obj)


def profile(name, points, half_width, mat):
    """Prisma con el perfil lateral `points` (y, z), de lado a lado del vehiculo."""
    return prism(name, points, -half_width, half_width, mat)


def ribbon(name, path, half_width, x0, x1, mat):
    """Barra curva: recorre `path` (y, z) y la extruye en x con el grosor dado."""
    left, right = [], []
    for index, (y, z) in enumerate(path):
        if index == 0:
            ty, tz = path[1][0] - y, path[1][1] - z
        elif index == len(path) - 1:
            ty, tz = y - path[-2][0], z - path[-2][1]
        else:
            ty, tz = path[index + 1][0] - path[index - 1][0], path[index + 1][1] - path[index - 1][1]
        length = math.hypot(ty, tz) or 1.0
        ny, nz = -tz / length, ty / length
        left.append((y + ny * half_width, z + nz * half_width))
        right.append((y - ny * half_width, z - nz * half_width))
    return prism(name, left + right[::-1], x0, x1, mat)


def tube(name, p0, p1, radius, verts, mat):
    """Cilindro entre dos puntos del plano YZ (eje del cilindro local Z, girado alrededor de X)."""
    a = Vector((0.0, p0[0], p0[1]))
    b = Vector((0.0, p1[0], p1[1]))
    delta = b - a
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts,
        radius=radius,
        depth=delta.length,
        location=(a + b) / 2,
        rotation=(math.atan2(-delta.y, delta.z), 0.0, 0.0),
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
    obj.data.materials.append(mat)
    return obj


def cyl_x(name, center, radius, depth, verts, mat):
    """Cilindro con el eje en X (ruedas, ejes, polea, tambor): el origen queda en su centro."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts, radius=radius, depth=depth, location=center, rotation=(0, math.radians(90), 0)
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
    obj.data.materials.append(mat)
    return obj


def cyl_z(name, center, radius, depth, verts, mat):
    """Cilindro vertical (baliza): el origen queda en el centro de la base."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=center)
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    obj.data.materials.append(mat)
    return obj


def wheel_part(name, radius, depth, verts, mat, location):
    """Cilindro con el eje en X y la malla centrada: el origen es el eje de giro y la traslacion va en el objeto."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts, radius=radius, depth=depth, location=(0.0, 0.0, 0.0), rotation=(0, math.radians(90), 0)
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    obj.location = location
    obj.data.materials.append(mat)
    return obj


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    select_only(joined)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return joined


def group_by_material(parts, prefix):
    groups = {}
    for part in parts:
        groups.setdefault(part.data.materials[0].name, []).append(part)
    return {material: join(members, f"{prefix}_{material}") for material, members in groups.items()}


def arch_curve(axle_y, steps=8):
    """Puntos interiores del arco (de 0 a 180 grados) que recorta el guardabarros."""
    return [
        (axle_y + ARCH_RADIUS * math.cos(math.pi * i / steps), SIDE_BOTTOM + ARCH_RADIUS * math.sin(math.pi * i / steps))
        for i in range(1, steps)
    ]


def cab_outline():
    """Perfil lateral de la cabina, con el arco de la rueda delantera recortado en el borde inferior."""
    points = [
        (CAB_Y0, CAB_BOTTOM),
        (CAB_Y0, 2.55),
        (CAB_Y0 + 0.15, 2.85),
        (CAB_Y0 + 0.65, 3.02),
        WINDSHIELD_P0,
        WINDSHIELD_P1,
        (WINDSHIELD_P1[0] + 0.14, ROOF_Z),
        (CAB_Y1, ROOF_Z),
        (CAB_Y1, CAB_BOTTOM),
        (FRONT_Y + ARCH_RADIUS, CAB_BOTTOM),
    ]
    points += [
        (FRONT_Y + ARCH_RADIUS * math.cos(math.pi * i / 8), CAB_BOTTOM + ARCH_RADIUS * math.sin(math.pi * i / 8))
        for i in range(1, 8)
    ]
    points.append((FRONT_Y - ARCH_RADIUS, CAB_BOTTOM))
    return points


def deck_side_outline():
    """Lateral de la plataforma: barandilla arriba y los dos arcos de las ruedas recortados abajo."""
    points = [(DECK_Y0, SIDE_TOP), (DECK_Y1, SIDE_TOP), (DECK_Y1, SIDE_BOTTOM)]
    for axle_y in (REAR_Y, MID_Y):
        points.append((axle_y + ARCH_RADIUS, SIDE_BOTTOM))
        points += arch_curve(axle_y)
        points.append((axle_y - ARCH_RADIUS, SIDE_BOTTOM))
    points.append((DECK_Y0, SIDE_BOTTOM))
    return points


def windshield_parts(parts, mats):
    """Parabrisas: marco oscuro en relieve (cabecera, cubre, montantes) y cristal hundido."""
    p0, p1 = WINDSHIELD_P0, WINDSHIELD_P1
    dy, dz = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dy, dz)
    uy, uz = dy / length, dz / length
    ny, nz = -uz, uy  # normal hacia fuera (delante y arriba)
    angle = math.atan2(-uy, uz)
    mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)

    def place(t, offset, x, size, mat, name):
        y = p0[0] + uy * t + ny * offset
        z = p0[1] + uz * t + nz * offset
        parts.append(panel(name, size, (x, y, z), angle, mat))

    place(0.13, 0.03, 0.0, (5.40, 0.16, 0.26), mats["dark"], "windshield_cowl")
    place(length - 0.16, 0.03, 0.0, (5.40, 0.16, 0.32), mats["dark"], "windshield_header")
    for side in (-1, 1):
        place(length / 2, 0.03, side * 2.42, (0.32, 0.14, length - 0.10), mats["dark"], "windshield_pillar")
    place(length / 2, 0.02, 0.0, (4.50, 0.03, length - 0.56), mats["glass"], "windshield_glass")
    for side in (-1, 1):
        place(length * 0.30, 0.06, side * 0.78, (0.06, 0.03, 0.62), mats["dark"], "wiper")


def side_window(parts, mats, side):
    """Ventanilla con marco oscuro en relieve, montantes y cristal hundido, en el costado de la cabina."""
    x_frame = side * (CAB_HALF + 0.03)
    x_glass = side * (CAB_HALF + 0.02)
    y0, y1 = WINDOW_Y
    z0, z1 = WINDOW_Z
    w, h = y1 - y0, z1 - z0
    yc, zc = (y0 + y1) / 2, (z0 + z1) / 2
    parts.append(box("window_top", (0.06, w + 0.10, 0.14), (x_frame, yc, z1 - 0.06), mats["dark"]))
    parts.append(box("window_bottom", (0.06, w + 0.10, 0.14), (x_frame, yc, z0 + 0.06), mats["dark"]))
    parts.append(box("window_front", (0.06, 0.16, h + 0.10), (x_frame, y0 + 0.06, zc), mats["dark"]))
    parts.append(box("window_rear", (0.06, 0.20, h + 0.10), (x_frame, y1 - 0.08, zc), mats["dark"]))
    parts.append(box("window_glass", (0.04, w - 0.30, h - 0.28), (x_glass, yc, zc), mats["glass"]))


def rear_window(parts, mats):
    """Luna trasera de la cabina, con marco en relieve: se ve desde el 3/4 trasero."""
    z0, z1 = 3.45, 4.55
    half = 1.65
    parts.append(box("rear_glass_top", (2 * half + 0.16, 0.06, 0.12), (0, -2.53, z1 - 0.03), mats["dark"]))
    parts.append(box("rear_glass_bottom", (2 * half + 0.16, 0.06, 0.12), (0, -2.53, z0 + 0.03), mats["dark"]))
    for side in (-1, 1):
        parts.append(box("rear_glass_side", (0.14, 0.06, z1 - z0), (side * (half + 0.01), -2.53, (z0 + z1) / 2), mats["dark"]))
    parts.append(box("rear_glass", (2 * half - 0.28, 0.04, z1 - z0 - 0.28), (0, -2.56, (z0 + z1) / 2), mats["glass"]))


def build_boom(parts, crane, mats):
    """Pedestal, tambor, brazo, cilindro hidraulico, polea, cable y gancho."""
    parts.append(box("boom_base", (2.0, 1.3, 0.18), (0.0, -1.55, DECK_TOP + 0.09), mats["yellow"]))
    parts.append(bevel(box("boom_pedestal", (1.4, 1.0, 1.2), (0.0, -1.55, 3.33), mats["steel"]), 0.06, 1))
    crane.append(cyl_x("boom_drum", (0.0, -1.55, 3.42), 0.34, 1.7, 8, mats["dark"]))
    crane.append(cyl_x("boom_pivot", (0.0, -0.95, 3.75), 0.22, 1.30, 8, mats["steel"]))

    (py, pz), (ty, tz) = BOOM_PIVOT, BOOM_TIP
    dy, dz = ty - py, tz - pz
    length = math.hypot(dy, dz)
    uy, uz = dy / length, dz / length
    ny, nz = -uz, uy
    coarse = [
        (py + ny * 0.30, pz + nz * 0.30),
        (ty + ny * 0.20, tz + nz * 0.20),
        (ty - ny * 0.20, tz - nz * 0.20),
        (py - ny * 0.30, pz - nz * 0.30),
    ]
    crane.append(profile("boom_arm", coarse, BOOM_HALF, mats["steel"]))
    crane.append(panel("boom_sheave", (0.64, 0.50, 0.36), (0.0, HOOK_X, 6.70), 0.0, mats["steel"]))
    crane.append(cyl_x("boom_pulley", (0.0, HOOK_X, 6.47), 0.21, 0.36, 8, mats["dark"]))
    crane.append(box("boom_cable", (0.06, 0.06, 1.50), (0.0, HOOK_X, 5.55), mats["dark"]))
    crane.append(box("boom_block", (0.26, 0.24, 0.34), (0.0, HOOK_X, 4.64), mats["steel"]))

    hook_path = [
        (HOOK_X, 4.47),
        (HOOK_X, 4.16),
        (HOOK_X + 0.03, 3.97),
        (HOOK_X + 0.15, 3.84),
        (HOOK_X + 0.31, 3.78),
        (HOOK_X + 0.47, 3.86),
        (HOOK_X + 0.55, 4.02),
        (HOOK_X + 0.51, 4.17),
        (HOOK_X + 0.38, 4.22),
        (HOOK_X + 0.27, 4.16),
    ]
    crane.append(ribbon("boom_hook", hook_path, 0.08, -0.10, 0.10, mats["dark"]))

    crane.append(tube("boom_ram", (-1.85, 3.05), (-0.78, 4.12), 0.10, 6, mats["steel"]))
    crane.append(tube("boom_rod", (-0.85, 4.02), (-0.32, 4.74), 0.06, 6, mats["steel"]))

    parts.extend(crane)


def build_body(mats):
    parts = []
    crane = []

    # Cabina: un solo volumen con el arco delantero recortado. El bisel redondea el juguete.
    parts.append(bevel(profile("cab", cab_outline(), CAB_HALF, mats["yellow"]), 0.09, 2))

    # Plataforma: suelo, dos laterales con arcos recortados, barandilla de acero y compuerta trasera.
    parts.append(bevel(box("deck_floor", (DECK_HALF * 2, DECK_Y1 - DECK_Y0, DECK_TOP - DECK_BOTTOM),
                           (0.0, (DECK_Y0 + DECK_Y1) / 2, (DECK_BOTTOM + DECK_TOP) / 2), mats["yellow"]), 0.05, 1))
    for side in (-1, 1):
        x0, x1 = (SIDE_X0, SIDE_X1) if side > 0 else (-SIDE_X1, -SIDE_X0)
        parts.append(bevel(prism("deck_side", deck_side_outline(), x0, x1, mats["yellow"]), 0.04, 1))
    for side in (-1, 1):
        parts.append(box("deck_rail", (RAIL_X1 - RAIL_X0, DECK_Y1 - DECK_Y0, RAIL_TOP - SIDE_TOP),
                         (side * (RAIL_X0 + RAIL_X1) / 2, (DECK_Y0 + DECK_Y1) / 2, (SIDE_TOP + RAIL_TOP) / 2),
                         mats["steel"]))
    parts.append(bevel(box("tailgate", (5.0, 0.20, 1.0), (0.0, 6.80, 2.05), mats["yellow"]), 0.05, 1))

    # Chasis y ejes: se ven entre ruedas, bajo la plataforma y en los arcos.
    parts.append(bevel(box("chassis", (4.2, 13.35, 1.05), (0.0, 0.125, 1.575), mats["dark"]), 0.04, 1))
    for axle_y in (FRONT_Y, MID_Y, REAR_Y):
        parts.append(cyl_x("axle", (0.0, axle_y, 1.0), 0.14, 2 * AXLE_X, 8, mats["dark"]))

    # Cabina: parabrisas, ventanillas, luna trasera, espejos, puerta y techo.
    windshield_parts(parts, mats)
    for side in (-1, 1):
        side_window(parts, mats, side)
        parts.append(box("door_seam", (0.03, 0.05, 2.15), (side * (CAB_HALF + 0.02), -3.60, 2.23), mats["dark"]))
        parts.append(box("handle", (0.05, 0.30, 0.08), (side * (CAB_HALF + 0.05), -4.10, 3.20), mats["steel"]))
        parts.append(box("mirror_arm", (0.40, 0.06, 0.06), (side * 2.97, -5.42, 4.12), mats["steel"]))
        parts.append(box("mirror_head", (0.14, 0.42, 0.55), (side * 3.14, -5.35, 3.95), mats["dark"]))
        parts.append(box("mirror_glass", (0.11, 0.02, 0.44), (side * 3.14, -5.13, 3.95), mats["glass"]))
        parts.append(box("roof_gutter", (0.10, 2.10, 0.08), (side * 2.78, -3.65, 4.92), mats["dark"]))
        parts.append(cyl_x("fuel_cap", (side * 2.80, -2.95, 2.35), 0.16, 0.05, 6, mats["steel"]))
    rear_window(parts, mats)

    # Techo: baliza naranja y tres luces de gálibo.
    parts.append(cyl_z("beacon_base", (0.0, -3.50, 4.98), 0.22, 0.12, 8, mats["steel"]))
    parts.append(cyl_z("beacon_lens", (0.0, -3.50, 5.18), 0.18, 0.28, 8, mats["orange"]))
    for x in (-1.2, 0.0, 1.2):
        parts.append(box("roof_marker", (0.22, 0.14, 0.10), (x, -4.68, 4.97), mats["orange"]))

    # Morro: parachoques, ganchos, calandra con barras, faros e intermitentes.
    parts.append(bevel(box("bumper_front", (5.44, 0.34, 0.55), (0.0, -6.83, 1.225), mats["steel"]), 0.05, 1))
    for side in (-1, 1):
        parts.append(box("tow_hook", (0.30, 0.12, 0.20), (side * 1.90, -6.93, 0.88), mats["dark"]))
    parts.append(box("grille", (3.20, 0.06, 0.95), (0.0, -6.73, 2.05), mats["dark"]))
    for z in (1.80, 2.05, 2.30):
        parts.append(box("grille_bar", (3.00, 0.05, 0.06), (0.0, -6.77, z), mats["steel"]))
    for side in (-1, 1):
        parts.append(box("headlight_bezel", (0.66, 0.10, 0.52), (side * 2.15, -6.72, 2.05), mats["dark"]))
        parts.append(box("headlight", (0.55, 0.12, 0.42), (side * 2.15, -6.74, 2.05), mats["cream"]))
        parts.append(box("indicator", (0.30, 0.10, 0.16), (side * 2.55, -6.74, 1.65), mats["orange"]))

    # Trasera: bisagras, pestillo, pilotos, parachoques, faldones y reflectores.
    for side in (-1, 1):
        parts.append(box("tail_hinge", (0.30, 0.08, 0.18), (side * 1.70, 6.94, 2.35), mats["dark"]))
        parts.append(box("taillight", (0.40, 0.06, 0.40), (side * 2.20, 6.93, 1.80), mats["red"]))
        parts.append(box("rear_reflector", (0.22, 0.05, 0.10), (side * 2.55, 6.93, 1.55), mats["orange"]))
        parts.append(box("mud_flap", (0.55, 0.22, 0.64), (side * 2.45, 6.42, 0.73), mats["dark"]))
        parts.append(box("bumper_bracket", (0.14, 0.16, 0.16), (side * 1.80, 6.86, 1.20), mats["dark"]))
    parts.append(box("tail_latch", (0.50, 0.08, 0.12), (0.0, 6.92, 2.20), mats["steel"]))
    parts.append(bevel(box("bumper_rear", (5.40, 0.12, 0.30), (0.0, 6.94, 1.20), mats["steel"]), 0.04, 1))

    # Laterales: luces de gálibo, bolsillos, caja de herramientas y deposito de combustible.
    for side in (-1, 1):
        for y in (-1.70, 0.35, 6.80):
            parts.append(box("deck_marker", (0.04, 0.20, 0.12), (side * (SIDE_X1 + 0.02), y, 2.50), mats["orange"]))
        for y in (-1.90, 6.60):
            parts.append(box("stake_pocket", (0.08, 0.16, 1.0), (side * 2.80, y, 2.20), mats["steel"]))
    parts.append(bevel(box("tool_box", (0.10, 1.0, 0.55), (2.83, -1.40, 1.80), mats["steel"]), 0.03, 1))

    # Grua sobre la plataforma delantera: nunca llega a la placa.
    build_boom(parts, crane, mats)
    return parts, crane


def build_plate(mats):
    return bevel(box("tow_plate", PLATE_SIZE, PLATE_CENTER, mats["plate"]), 0.02, 1)


def bounds(entries):
    lo = [1e9, 1e9, 1e9]
    hi = [-1e9, -1e9, -1e9]
    for obj, offset in entries:
        for vertex in obj.data.vertices:
            point = Vector(vertex.co) + Vector(offset)
            for i in range(3):
                lo[i] = min(lo[i], point[i])
                hi[i] = max(hi[i], point[i])
    return lo, hi


def count(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


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


def build_lod(mats):
    """LOD1: una sola malla y un solo material, con la silueta del camion (cabina, plataforma, brazo y ruedas)."""
    parts = []
    parts.append(profile("lod_cab", [
        (CAB_Y0, CAB_BOTTOM), (CAB_Y0, 2.55), (CAB_Y0 + 0.2, 3.0), (WINDSHIELD_P0[0], WINDSHIELD_P0[1]),
        WINDSHIELD_P1, (CAB_Y1, ROOF_Z), (CAB_Y1, CAB_BOTTOM),
    ], CAB_HALF, mats["yellow"]))
    parts.append(box("lod_deck", (DECK_HALF * 2, DECK_Y1 - DECK_Y0, DECK_TOP - DECK_BOTTOM),
                     (0.0, (DECK_Y0 + DECK_Y1) / 2, (DECK_BOTTOM + DECK_TOP) / 2), mats["yellow"]))
    for side in (-1, 1):
        parts.append(box("lod_side", (0.28, DECK_Y1 - DECK_Y0, 1.67), (side * 2.64, (DECK_Y0 + DECK_Y1) / 2, 1.885), mats["yellow"]))
    parts.append(box("lod_pedestal", (1.4, 1.0, 1.2), (0.0, -1.55, 3.33), mats["yellow"]))
    (py, pz), (ty, tz) = BOOM_PIVOT, BOOM_TIP
    dy, dz = ty - py, tz - pz
    length = math.hypot(dy, dz)
    ny, nz = -dz / length, dy / length
    lod_boom = [
        (py + ny * 0.26, pz + nz * 0.26),
        (ty + ny * 0.17, tz + nz * 0.17),
        (ty - ny * 0.17, tz - nz * 0.17),
        (py - ny * 0.26, pz - nz * 0.26),
    ]
    parts.append(profile("lod_boom", lod_boom, BOOM_HALF, mats["yellow"]))
    parts.append(box("lod_cable", (0.08, 0.08, 2.2), (0.0, HOOK_X, 5.70), mats["yellow"]))
    parts.append(box("lod_hook", (0.2, 0.2, 0.6), (0.0, HOOK_X, 4.3), mats["yellow"]))
    for key, axle in WHEEL_AXLES.items():
        parts.append(wheel_part(f"lod_wheel_{key}", WHEEL_RADIUS, WHEEL_DEPTH, 8, mats["yellow"], axle))
    lod = join(parts, "tow_LOD1")
    select_only(lod)
    bpy.ops.object.material_slot_remove_unused()
    assert len(lod.data.materials) == 1, "el LOD1 tiene mas de un material"
    return lod


def camera(name, location, target, lens=None, ortho_scale=None):
    data = bpy.data.cameras.new(name)
    if ortho_scale is None:
        data.lens = lens
    else:
        data.type = "ORTHO"
        data.ortho_scale = ortho_scale
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    return obj


def render(scene, cam, name):
    scene.camera = cam
    scene.render.filepath = os.path.join(RENDER, name)
    bpy.ops.render.render(write_still=True)


def build_avatar(mat):
    """Silueta de referencia de 6 studs de alto (no es un asset del juego)."""
    parts = [
        box("av_leg_l", (0.8, 0.9, 2.5), (-0.5, 0, 1.25), mat),
        box("av_leg_r", (0.8, 0.9, 2.5), (0.5, 0, 1.25), mat),
        box("av_torso", (2.0, 1.0, 1.9), (0, 0, 3.45), mat),
        box("av_arm_l", (0.6, 0.6, 1.9), (-1.3, 0, 3.5), mat),
        box("av_arm_r", (0.6, 0.6, 1.9), (1.3, 0, 3.5), mat),
    ]
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.8, location=(0, 0, 5.2), segments=16, ring_count=8)
    head = bpy.context.active_object
    head.name = "av_head"
    head.data.materials.append(mat)
    parts.append(head)
    return parts


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    scene.unit_settings.scale_length = 1.0
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(RENDER, exist_ok=True)
    for old in glob.glob(os.path.join(OUT, "*.fbx")) + glob.glob(os.path.join(OUT, "stats.json")):
        os.remove(old)

    mats = {
        "yellow": flat("yellow", "F5C518", 0.35),
        "steel": flat("steel", "A8AEB4", 0.25, 0.8),
        "dark": flat("dark", "2A2E33", 0.6),
        "glass": flat("glass", "7FB2D9", 0.12),
        "cream": flat("cream", "EDE5D3", 0.6),
        "red": flat("red", "C4382B", 0.7),
        "orange": flat("orange", "E07A3C", 0.55),
        "plate": flat("plate", "EDEAE3", 0.5),
        "ground": flat("ground", "8E9196", 0.9),
    }

    body_parts, crane_parts = build_body(mats)
    # El brazo y el gancho tienen que medirse antes de agrupar: al unir por material los objetos se funden.
    crane_max_y = max((Vector(v.co) + obj.location).y for obj in crane_parts for v in obj.data.vertices)
    body = group_by_material(body_parts, "tow_body")
    plate = build_plate(mats)
    wheels = {
        key: wheel_part(f"tow_wheel_{key}", WHEEL_RADIUS, WHEEL_DEPTH, 12, mats["dark"], WHEEL_AXLES[key])
        for key in WHEEL_AXLES
    }
    hubs = {
        key: wheel_part(f"tow_hub_{key}", HUB_RADIUS, HUB_DEPTH, 8, mats["steel"], WHEEL_AXLES[key])
        for key in WHEEL_AXLES
    }

    # Comprobaciones antes de exportar.
    entries = [(obj, (0.0, 0.0, 0.0)) for obj in body.values()] + [(plate, (0.0, 0.0, 0.0))]
    entries += [(wheels[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    entries += [(hubs[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    lo, hi = bounds(entries)
    plate_lo, plate_hi = bounds([(plate, (0.0, 0.0, 0.0))])
    seat = (round((plate_lo[0] + plate_hi[0]) / 2, 4), round((plate_lo[1] + plate_hi[1]) / 2, 4), round(plate_hi[2], 4))
    width, length, height = hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]

    assert plate_hi[0] - plate_lo[0] >= 4.5 - 1e-6 and plate_hi[1] - plate_lo[1] >= 4.5 - 1e-6, "placa menor de 4,5 x 4,5"
    assert plate_lo[2] >= DECK_TOP - 1e-6, "la placa no apoya en la plataforma"
    assert abs(seat[2] - plate_hi[2]) < 1e-6, "el seat no coincide con la cara superior de la placa"
    assert width <= MAX_ANCHO + 1e-6, f"ancho {width:.2f} por encima de {MAX_ANCHO}"
    assert length <= MAX_LARGO + 1e-6, f"largo {length:.2f} por encima de {MAX_LARGO}"
    assert height <= MAX_ALTO + 1e-6, f"alto {height:.2f} por encima de {MAX_ALTO}"
    assert abs(lo[2]) < 1e-6, f"min_z {lo[2]:.4f} distinto de 0"
    for key in WHEEL_AXLES:
        wlo, _ = bounds([(wheels[key], WHEEL_AXLES[key])])
        assert abs(wlo[2]) < 1e-6, f"la rueda {key} no toca el suelo"
        assert count(wheels[key]) + count(hubs[key]) <= PART_BUDGET, f"rueda {key} por encima de {PART_BUDGET}"
    for obj in [*body.values(), plate, *wheels.values(), *hubs.values()]:
        assert len(obj.data.materials) == 1, f"{obj.name} tiene varios materiales"

    # Nada por encima de la placa dentro de su huella: el avatar tiene que quedar libre.
    for obj in body.values():
        for vertex in obj.data.vertices:
            point = Vector(vertex.co) + obj.location
            inside = plate_lo[0] - 1e-6 <= point.x <= plate_hi[0] + 1e-6 and plate_lo[1] - 1e-6 <= point.y <= plate_hi[1] + 1e-6
            assert not inside or point.z <= plate_hi[2] + 1e-6, f"{obj.name} invade la placa por encima del seat"
    assert crane_max_y < plate_lo[1] - 0.5, f"el brazo o el gancho invaden la placa (y {crane_max_y:.2f})"

    lod = build_lod(mats)

    # Las ruedas y los tapacubos se exportan con su origen en el eje y ya colocados en su sitio del
    # camion. Asi Roblox los deja en el eje al cargarlos y siguen girando alrededor de su propio centro.
    for key in WHEEL_AXLES:
        wheels[key].location = WHEEL_AXLES[key]
        hubs[key].location = WHEEL_AXLES[key]

    files = {}
    for obj in body.values():
        export(obj, f"{obj.name}.fbx")
        files[obj.name] = count(obj)
    export(plate, "tow_plate.fbx")
    files["tow_plate"] = count(plate)
    for key in WHEEL_AXLES:
        export(wheels[key], f"tow_wheel_{key}.fbx")
        export(hubs[key], f"tow_hub_{key}.fbx")
        files[f"tow_wheel_{key}"] = count(wheels[key])
        files[f"tow_hub_{key}"] = count(hubs[key])
    export(lod, "tow_LOD1.fbx")
    total = sum(files.values())
    lod_triangles = count(lod)
    assert total <= TOTAL_BUDGET, f"{total} triangulos, por encima de {TOTAL_BUDGET}"
    assert lod_triangles <= total / 2, f"LOD1 con {lod_triangles}, mas de la mitad de {total}"

    boom_length = math.hypot(BOOM_TIP[0] - BOOM_PIVOT[0], BOOM_TIP[1] - BOOM_PIVOT[1])
    stats = {
        "modelo": "grua",
        "unidades": "studs (1 unidad de Blender = 1 stud)",
        "origen": "centro de la base, a ras de suelo (x = 0, y = 0, z = 0)",
        "frente": "-Y (morro)",
        "arriba": "+Z",
        "triangulos": {
            "piezas": files,
            "total": total,
            "lod1": lod_triangles,
            "lod1_mitad_del_total": round(total / 2, 1),
            "presupuesto_total": TOTAL_BUDGET,
            "presupuesto_por_rueda_con_tapacubos": PART_BUDGET,
        },
        "medidas": {
            "ancho_x": round(width, 3),
            "largo_y": round(length, 3),
            "alto_z": round(height, 3),
            "min_z": round(lo[2], 3),
            "techo_cabina_z": ROOF_Z,
            "plataforma": {
                "inicio_y": DECK_Y0,
                "fin_y": DECK_Y1,
                "largo_y": round(DECK_Y1 - DECK_Y0, 3),
                "ancho_x": round(2 * SIDE_X1, 3),
                "z_superior": DECK_TOP,
                "barandilla_z": RAIL_TOP,
            },
            "brazo": {
                "pivote": list(BOOM_PIVOT),
                "punta": list(BOOM_TIP),
                "largo": round(boom_length, 3),
                "altura_max_z": round(hi[2], 3),
                "gancho_y_max": round(crane_max_y, 3),
                "despeje_placa_y": round(plate_lo[1] - crane_max_y, 3),
            },
            "placa": {
                "tamano_x": round(plate_hi[0] - plate_lo[0], 3),
                "tamano_y": round(plate_hi[1] - plate_lo[1], 3),
                "z_inferior": round(plate_lo[2], 4),
                "z_superior": round(plate_hi[2], 4),
                "centro_xy": [PLATE_CENTER[0], PLATE_CENTER[1]],
            },
            "referencia_taxi": REF_TAXI,
        },
        "seat": list(seat),
        "ruedas": {
            key: {
                "archivo": f"tow_wheel_{key}.fbx",
                "tapacubos": f"tow_hub_{key}.fbx",
                "eje": list(WHEEL_AXLES[key]),
                "giro": "X",
                "radio": WHEEL_RADIUS,
                "ancho": WHEEL_DEPTH,
            }
            for key in WHEEL_AXLES
        },
        "materiales": {
            **{obj.name: obj.data.materials[0].name for obj in body.values()},
            "tow_plate": "plate",
            **{f"tow_wheel_{key}": "dark" for key in WHEEL_AXLES},
            **{f"tow_hub_{key}": "steel" for key in WHEEL_AXLES},
            "tow_LOD1": "yellow",
        },
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("GRUA_STATS", json.dumps(stats))

    # Render: los mismos encuadres que el taxi.
    lod.hide_render = True

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.1))
    ground = bpy.context.active_object
    ground.name = "ground"
    ground.scale = (90.0, 90.0, 0.2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ground.data.materials.append(mats["ground"])

    avatar = build_avatar(flat("avatar_ref", "5E636A", 0.8))
    for obj in avatar:
        obj.location.y += seat[1]
        obj.location.z += seat[2]
        obj.hide_render = True

    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 4.2
    sun_data.angle = math.radians(1.0)
    sun = bpy.data.objects.new("sun", sun_data)
    bpy.context.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(90 - 34), 0, math.radians(-38))

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.5, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world

    scene.render.engine = "CYCLES"
    scene.cycles.samples = 64
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    scene.view_settings.look = "AgX - Medium High Contrast"

    render(scene, camera("frontal", (-12.0, -21.0, 12.0), (0.0, 0.0, 2.6), lens=50), "grua-3-4-frontal.png")
    render(scene, camera("trasera", (12.0, 21.0, 12.0), (0.0, 0.0, 2.6), lens=50), "grua-3-4-trasera.png")
    for obj in avatar:
        obj.hide_render = False
    render(scene, camera("perfil", (60.0, 4.0, 3.0), (0.0, 4.0, 3.0), ortho_scale=26.0), "grua-perfil-avatar.png")
    print("GRUA_RENDERS_OK")


if __name__ == "__main__":
    main()

"""Grua-remolque: pieza de escena de Flip the Table.

Grua de plataforma que se lleva una ficha en bancarrota. Es la version grande de la ficha grua:
cabina de camion con capo corto, plataforma de asfalto con barandillas, pluma hidraulica detras de la
cabina con gancho colgando sobre la plataforma, seis ruedas y tapacubos de acero. Un vehiculo de 12,4
studs de largo (el taxi) cabe sobre la plataforma.

Salidas, en art/blender/scene-props/grua-remolque/:
  towtruck_<material>.fbx       carroceria, una malla por material (origen en el centro de la base)
  towtruck_wheel_<pos>.fbx      neumatico, con el origen en su eje de giro (eje X)
  towtruck_hub_<pos>.fbx        tapacubos de acero, malla aparte, mismo origen y eje que su rueda
  towtruck_LOD1.fbx             una sola malla y un solo material, <= 50 % de los triangulos
  stats.json                    triangulos por pieza, total y LOD1, medidas, ejes y gancho
Y en art/render/scene-props/grua-remolque/: 3/4 frontal, 3/4 trasero y perfil con avatar de 6 studs.

Convenciones (como art/blender/tokens/taxi.py): 1 unidad de Blender = 1 stud, el morro mira a -Y,
Z hacia arriba, origen en el centro de la base a ras de suelo, exportacion FBX con Z Forward / Y Up.
La ficha grua mide 6,42 x 14,0 x 6,88: esta pieza es mayor en los tres ejes y no pasa de 8 x 20 x 8.

Uso (segundo plano, sin abrir Blender):
  "D:\\blender\\blender.exe" --background --factory-startup --python art/blender/scene-props/grua-remolque.py
"""

import glob
import json
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "grua-remolque")
RENDER = os.path.join(REPO, "art", "render", "scene-props", "grua-remolque")

LOD_RATIO = 0.45
TOTAL_BUDGET = 3000
MAX_SIZE = (8.0, 20.0, 8.0)  # ancho x, largo y, alto z
DECK_MIN_LENGTH = 12.4  # el vehiculo que se lleva encima
# Ficha grua actual, medida (art/blender/tokens/grua/stats.json): hay que superarla en los tres ejes.
GRUA_TOKEN = {"ancho_x": 6.42, "largo_y": 14.0, "alto_z": 6.88}

# Cabina: capo corto, parabrisas inclinado y techo plano. El morro es el -Y.
CAB_HALF = 3.15
CAB_POINTS = [
    (-9.4, 1.3),
    (-9.4, 4.05),
    (-8.6, 4.25),
    (-7.4, 4.3),
    (-6.05, 5.95),
    (-3.2, 6.0),
    (-3.2, 1.3),
]
WINDSHIELD_P0 = (-7.4, 4.3)
WINDSHIELD_P1 = (-6.05, 5.95)
ROOF_Z = 6.0
WINDSHIELD_HALF = 2.6
FRAME_HALF = 2.85
SIDE_WINDOWS = [(-6.05, -4.85), (-4.62, -3.38)]
WINDOW_Z = (4.55, 5.68)
DOOR_SEAM_Y = -4.74

# Plataforma: 12,6 de largo, 6,4 de ancho; el borde superior a 2,72.
DECK_Y0, DECK_Y1 = -3.0, 9.6
DECK_TOP = 2.72
DECK_THICK = 0.26
DECK_HALF = 3.2
RAIL_TOP = 3.02
RAIL_HALF = 0.14

# Ruedas: origen en el eje de giro, en studs, relativo a la base. l = -X, r = +X (de frente).
WHEEL_AXLES = {
    "fl": (-2.7, -7.3, 1.18),
    "fr": (2.7, -7.3, 1.18),
    "ml": (-2.7, 4.4, 1.18),
    "mr": (2.7, 4.4, 1.18),
    "rl": (-2.7, 7.2, 1.18),
    "rr": (2.7, 7.2, 1.18),
}
WHEEL_RADIUS = 1.18
WHEEL_DEPTH = 1.0
HUB_RADIUS = 0.56
HUB_DEPTH = 1.12
WHEEL_SEGMENTS = 12
HUB_SEGMENTS = 8
ARCH_RADIUS = 1.52  # arco oscuro alrededor del neumatico delantero

# Pluma: mastil detras de la cabina, viga inclinada sobre la plataforma y gancho.
MAST_Y = -1.85
MAST_TOP = 7.15
BOOM_P0 = (-1.6, 6.95)
BOOM_P1 = (5.0, 5.75)
BOOM_H0 = 0.46
BOOM_H1 = 0.26
BOOM_HALF = 0.33
HOOK_X = 0.0
HOOK_Y = 5.0
HOOK_BLOCK_TOP = 4.6
HOOK_TOP = 4.26
HOOK_R_OUT = 0.54
HOOK_R_IN = 0.23
HOOK_CENTER_Z = -0.5


def srgb(hex_color):
    def channel(value):
        value /= 255.0
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4

    return tuple(channel(int(hex_color[i : i + 2], 16)) for i in (0, 2, 4))


def flat(name, hex_color, roughness=0.5, metallic=0.0, specular=0.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*srgb(hex_color), 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    for socket in ("Specular IOR Level", "Specular"):
        if socket in bsdf.inputs:
            bsdf.inputs[socket].default_value = specular
            break
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


def profile(name, points, half_width, mat):
    """Prisma con el perfil lateral `points` (y, z), de lado a lado del vehiculo."""
    verts = [(-half_width, y, z) for y, z in points] + [(half_width, y, z) for y, z in points]
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


def beam(name, p0, p1, h0, h1, half, mat):
    """Viga de perfil (y, z) entre dos puntos, con semialtura h0 en p0 y h1 en p1."""
    dy, dz = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dy, dz)
    ny, nz = -dz / length, dy / length
    points = [
        (p0[0] + ny * h0, p0[1] + nz * h0),
        (p1[0] + ny * h1, p1[1] + nz * h1),
        (p1[0] - ny * h1, p1[1] - nz * h1),
        (p0[0] - ny * h0, p0[1] - nz * h0),
    ]
    return profile(name, points, half, mat)


def strut(name, p0, p1, radius, segments, mat):
    """Cilindro entre dos puntos 3D: puntales, escapes, tambores."""
    a, b = Vector(p0), Vector(p1)
    direction = b - a
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=segments, radius=radius, depth=direction.length, location=(a + b) / 2
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
    obj.data.materials.append(mat)
    return obj


def slope_slab(name, p0, p1, t0, t1, ext, half, mat):
    """Lamina sobre la inclinacion p0-p1, desplazada t0..t1 hacia fuera. ext > 0 alarga, < 0 recorta."""
    dy, dz = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dy, dz)
    uy, uz = dy / length, dz / length
    ny, nz = -uz, uy  # normal hacia fuera
    a = (p0[0] - uy * ext, p0[1] - uz * ext)
    b = (p1[0] + uy * ext, p1[1] + uz * ext)
    points = [
        (a[0] + ny * t0, a[1] + nz * t0),
        (b[0] + ny * t0, b[1] + nz * t0),
        (b[0] + ny * t1, b[1] + nz * t1),
        (a[0] + ny * t1, a[1] + nz * t1),
    ]
    return profile(name, points, half, mat)


def wiper(name, x, p0, p1, length, mat):
    """Limpiaparabrisas sencillo: pieza oscura alineada con el parabrisas, sobre el cristal."""
    dy, dz = p1[0] - p0[0], p1[1] - p0[1]
    norm = math.hypot(dy, dz)
    uy, uz = dy / norm, dz / norm
    ny, nz = -uz, uy
    mid = ((p0[0] + p1[0]) / 2 + ny * 0.16, (p0[1] + p1[1]) / 2 + nz * 0.16)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, mid[0], mid[1]))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (0.07, 0.05, length)
    obj.rotation_euler = (math.atan2(-dy, dz), 0, 0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(mat)
    return obj


def arch_arc(name, axle_y, x_center, mat, segments=6):
    """Arco oscuro sobre el neumatico delantero: media corona en el lateral de la cabina."""
    angles = [math.pi * i / segments for i in range(segments + 1)]
    outer = [(axle_y + ARCH_RADIUS * math.cos(t), WHEEL_RADIUS + ARCH_RADIUS * math.sin(t)) for t in angles]
    inner = [
        (axle_y + WHEEL_RADIUS * math.cos(t), WHEEL_RADIUS + WHEEL_RADIUS * math.sin(t))
        for t in reversed(angles)
    ]
    obj = profile(name, outer + inner, 0.07, mat)
    obj.location = (x_center, 0.0, 0.0)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    return obj


def hook_profile(name, mat):
    """Gancho en J: vástago corto y cazo de 311 grados, en el plano (y, z)."""
    center = (0.0, HOOK_CENTER_Z)
    outer_angles = [math.radians(a) for a in (76, 24, -28, -80, -132, -184, -235)]
    inner_angles = [math.radians(a) for a in (125, 182, 238, 295, 352, 408, 465)]
    outer = [(center[0] + HOOK_R_OUT * math.cos(t), center[1] + HOOK_R_OUT * math.sin(t)) for t in outer_angles]
    inner = [(center[0] + HOOK_R_IN * math.cos(t), center[1] + HOOK_R_IN * math.sin(t)) for t in inner_angles]
    points = [(-0.12, 0.08), (0.12, 0.08)] + outer + inner
    obj = profile(name, points, 0.14, mat)
    obj.location = (HOOK_X, HOOK_Y, HOOK_TOP)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    return obj


def wheel_part(name, radius, depth, verts, mat):
    """Cilindro con el eje en X y el origen en su centro: el origen es el eje de giro."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts, radius=radius, depth=depth, location=(0, 0, 0), rotation=(0, math.radians(90), 0)
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
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


def build_chassis(mats):
    """Bastidor, plataforma de asfalto con barandillas amarillas y detalles de carga."""
    yellow, steel, dark = mats["amarillo"], mats["acero"], mats["asfalto"]
    parts = []
    deck_len = DECK_Y1 - DECK_Y0
    deck_y = (DECK_Y0 + DECK_Y1) / 2

    parts.append(box("chassis", (3.9, 17.4, 0.55), (0, 0.2, 1.5), dark))
    for side in (-1, 1):
        parts.append(box("deck_beam", (0.32, deck_len, 0.5), (side * 3.02, deck_y, 2.21), yellow))
        parts.append(box("deck_rail", (0.28, deck_len, 0.3), (side * 3.06, deck_y, 2.87), yellow))
    parts.append(box("deck_plate", (2 * DECK_HALF, deck_len, DECK_THICK), (0, deck_y, DECK_TOP - DECK_THICK / 2), dark))
    parts.append(box("deck_rail_b", (2 * DECK_HALF, 0.28, 0.3), (0, DECK_Y1 - 0.14, 2.87), yellow))
    parts.append(box("deck_frame_f", (5.8, 0.3, 0.46), (0, DECK_Y0 + 0.15, 2.23), dark))
    # Tiras de amarre de acero sobre la plataforma, a lo largo.
    for side in (-1, 1):
        parts.append(box("tie_down", (0.1, deck_len - 0.8, 0.05), (side * 2.25, deck_y, DECK_TOP + 0.025), steel))
    return parts


def build_cab(mats):
    """Cabina amarilla, cristales, espejos, parachoques y grupo optico."""
    yellow, steel, dark, glass = mats["amarillo"], mats["acero"], mats["asfalto"], mats["cristal"]
    parts = [bevel(profile("cab", CAB_POINTS, CAB_HALF, yellow), 0.16)]

    # Parabrisas: marco oscuro con relieve y cristal menor entre montantes amarillos.
    parts.append(slope_slab("windshield_frame", WINDSHIELD_P0, WINDSHIELD_P1, 0.0, 0.09, -0.05, FRAME_HALF, dark))
    parts.append(slope_slab("windshield", WINDSHIELD_P0, WINDSHIELD_P1, 0.09, 0.13, -0.18, WINDSHIELD_HALF, glass))
    for x in (-0.85, 0.85):
        parts.append(wiper("wiper", x, WINDSHIELD_P0, WINDSHIELD_P1, 1.0, dark))

    # Luna trasera de la cabina.
    parts.append(box("rear_frame", (4.9, 0.07, 1.6), (0, -3.16, 4.85), dark))
    parts.append(box("rear_glass", (4.5, 0.05, 1.3), (0, -3.12, 4.85), glass))

    # Ventanillas laterales con marco oscuro y montante B.
    z0, z1 = WINDOW_Z
    for side in (-1, 1):
        for y0, y1 in SIDE_WINDOWS:
            w, h, yc, zc = y1 - y0, z1 - z0, (y0 + y1) / 2, (z0 + z1) / 2
            parts.append(box("window_frame", (0.05, w + 0.15, h + 0.16), (side * 3.155, yc, zc), dark))
            parts.append(box("window", (0.04, w, h), (side * 3.19, yc, zc), glass))
        parts.append(box("door_seam", (0.05, 0.09, 2.5), (side * 3.16, DOOR_SEAM_Y, 3.15), dark))
        parts.append(box("handle", (0.1, 0.42, 0.13), (side * 3.18, -5.3, 4.1), steel))
        parts.append(box("step", (0.5, 1.5, 0.12), (side * 3.2, -5.6, 1.55), steel))
        # Arco oscuro alrededor del neumatico delantero, sobre la chapa.
        parts.append(arch_arc("arch_ring", WHEEL_AXLES["fl"][1], side * (CAB_HALF + 0.02), dark))
        # Espejo: brazo horizontal, caja grande de acero y cara oscura.
        parts.append(box("mirror_arm", (0.5, 0.1, 0.1), (side * 3.35, -6.5, 4.95), steel))
        parts.append(box("mirror_head", (0.12, 0.5, 0.9), (side * 3.62, -6.5, 4.55), steel))
        parts.append(box("mirror_glass", (0.05, 0.4, 0.75), (side * 3.69, -6.5, 4.55), dark))

    # Morro: parachoques, parrilla con listones, faros y ganchos de remolque.
    parts.append(bevel(box("bumper", (6.7, 0.5, 0.62), (0, -9.55, 1.45), steel), 0.08))
    parts.append(box("grille", (2.9, 0.12, 1.05), (0, -9.44, 2.35), dark))
    for z in (1.98, 2.3, 2.62):
        parts.append(box("grille_bar", (2.66, 0.06, 0.09), (0, -9.51, z), steel))
    for side in (-1, 1):
        parts.append(box("headlight", (1.05, 0.14, 0.5), (side * 2.45, -9.45, 2.35), steel))
        parts.append(box("tow_hook", (0.3, 0.16, 0.28), (side * 2.35, -9.83, 1.45), steel))

    # Techo: barra de balizas con cuatro luces y luces de gálibo.
    parts.append(box("beacon_bar", (2.8, 0.46, 0.22), (0, -4.3, 6.12), yellow))
    for x in (-1.15, 1.15):
        parts.append(box("beacon_base", (0.34, 0.4, 0.1), (x, -4.3, 5.98), steel))
    for x in (-1.05, -0.35, 0.35, 1.05):
        parts.append(box("beacon_lamp", (0.36, 0.32, 0.08), (x, -4.3, 6.27), dark))
    for x in (-0.6, 0.0, 0.6):
        parts.append(box("marker", (0.2, 0.2, 0.1), (x, -5.82, 6.04), yellow))

    # Escape vertical detras de la cabina.
    parts.append(strut("exhaust", (2.55, -3.08, 1.9), (2.55, -3.08, 6.3), 0.12, 8, steel))
    return parts


def build_crane(mats):
    """Cabecero, mastil, pluma hidraulica, tambor, cable y gancho."""
    yellow, steel, dark = mats["amarillo"], mats["acero"], mats["asfalto"]
    parts = []
    # Cabecero que protege la cabina de la carga.
    parts.append(box("headboard", (6.0, 0.2, 1.16), (0, -2.75, 3.3), yellow))
    # Mastil portico: dos costados de acero, travesanos y base oscura, para que se vea el pivote.
    for side in (-1, 1):
        parts.append(box("mast_leg", (0.36, 0.86, MAST_TOP - 2.9), (side * 0.66, MAST_Y, (MAST_TOP + 2.9) / 2), steel))
    parts.append(box("mast_cross_top", (1.9, 0.5, 0.3), (0, MAST_Y, MAST_TOP - 0.15), steel))
    parts.append(box("mast_cross_low", (1.9, 1.0, 0.28), (0, MAST_Y, 4.35), steel))
    parts.append(box("mast_foot", (2.1, 1.35, 0.36), (0, MAST_Y, 2.92), dark))
    # Tambor del cabrestante y su soporte.
    parts.append(box("winch_base", (1.5, 0.7, 0.42), (0, -0.55, 2.93), dark))
    parts.append(strut("winch_drum", (-0.65, -0.55, 3.36), (0.65, -0.55, 3.36), 0.3, 8, steel))
    # Pluma: viga amarilla con talon de acero y empujador hidraulico.
    parts.append(beam("boom", BOOM_P0, BOOM_P1, BOOM_H0, BOOM_H1, BOOM_HALF, yellow))
    parts.append(box("boom_heel", (1.0, 1.1, 0.95), (0, -1.5, 6.9), steel))
    parts.append(strut("ram", (0.0, -1.5, 4.25), (0.0, 1.55, 6.1), 0.16, 8, steel))
    parts.append(strut("ram_rod", (0.0, 0.55, 5.32), (0.0, 1.75, 6.16), 0.09, 8, steel))
    # Punta de pluma, cable, cáncamo y gancho.
    parts.append(bevel(box("boom_tip", (0.55, 0.75, 0.6), (0, BOOM_P1[0], BOOM_P1[1] - 0.1), steel), 0.06))
    parts.append(box("cable", (0.06, 0.06, HOOK_BLOCK_TOP - 5.35), (HOOK_X, HOOK_Y, (HOOK_BLOCK_TOP + 5.35) / 2), dark))
    parts.append(box("hook_block", (0.3, 0.36, 0.34), (HOOK_X, HOOK_Y, HOOK_BLOCK_TOP - 0.17), steel))
    parts.append(hook_profile("hook", steel))
    # Central hidraulica sobre la plataforma, a un lado.
    parts.append(box("power_pack", (1.3, 0.95, 0.62), (2.15, -1.55, 3.03), steel))
    return parts


def build_rear(mats):
    """Bajos traseros: paragolpes, luces, matricula y faldones."""
    yellow, steel, dark = mats["amarillo"], mats["acero"], mats["asfalto"]
    parts = [
        box("rear_bumper", (5.4, 0.16, 0.35), (0, 9.72, 1.55), dark),
        box("rear_light", (0.45, 0.12, 0.22), (-2.4, 9.66, 2.52), steel),
        box("rear_light_r", (0.45, 0.12, 0.22), (2.4, 9.66, 2.52), steel),
        box("rear_plate", (1.2, 0.08, 0.42), (0, 9.67, 2.5), steel),
    ]
    for side in (-1, 1):
        parts.append(box("rear_bracket", (0.16, 0.16, 0.95), (side * 2.0, 9.66, 2.05), dark))
        parts.append(box("mudflap", (0.85, 0.08, 0.6), (side * 2.7, 8.6, 1.75), dark))
        parts.append(box("deck_end", (0.16, 0.16, 0.5), (side * 3.05, DECK_Y1 - 0.08, 2.6), yellow))
    return parts


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


def lod_part(source, location, material):
    copy = source.copy()
    copy.data = source.data.copy()
    copy.name = f"{source.name}_lod"
    bpy.context.collection.objects.link(copy)
    copy.location = location
    copy.data.materials.clear()
    copy.data.materials.append(material)
    return copy


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
    """Silueta de referencia de 6 studs de alto, de pie sobre el suelo (no es un asset del juego)."""
    parts = [
        box("av_leg_l", (0.8, 0.9, 2.5), (-0.5, 0, 1.25), mat),
        box("av_leg_r", (0.8, 0.9, 2.5), (0.5, 0, 1.25), mat),
        box("av_torso", (2.0, 1.0, 1.9), (0, 0, 3.45), mat),
        box("av_arm_l", (0.6, 0.6, 1.9), (-1.3, 0, 3.5), mat),
        box("av_arm_r", (0.6, 0.6, 1.9), (1.3, 0, 3.5), mat),
    ]
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.8, location=(0, 0, 5.0))
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
        "amarillo": flat("amarillo", "F5C518", 0.35),
        "acero": flat("acero", "A8AEB4", 0.25, 0.8),
        "asfalto": flat("asfalto", "2A2E33", 0.9, 0.0, 0.0),
        "cristal": flat("cristal", "2E4A63", 0.12),
        "suelo": flat("suelo", "8E9196", 0.9),
    }

    parts = build_chassis(mats) + build_cab(mats) + build_crane(mats) + build_rear(mats)
    body = group_by_material(parts, "towtruck")
    wheels = {key: wheel_part(f"towtruck_wheel_{key}", WHEEL_RADIUS, WHEEL_DEPTH, WHEEL_SEGMENTS, mats["asfalto"]) for key in WHEEL_AXLES}
    hubs = {key: wheel_part(f"towtruck_hub_{key}", HUB_RADIUS, HUB_DEPTH, HUB_SEGMENTS, mats["acero"]) for key in WHEEL_AXLES}

    # Comprobaciones antes de exportar.
    entries = [(obj, (0.0, 0.0, 0.0)) for obj in body.values()]
    entries += [(wheels[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    entries += [(hubs[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    lo, hi = bounds(entries)
    size = (hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2])
    deck_len = DECK_Y1 - DECK_Y0
    assert abs(lo[2]) < 1e-6, f"min_z = {lo[2]:.3f}, debe ser 0"
    assert size[0] <= MAX_SIZE[0], f"ancho {size[0]:.2f} por encima de {MAX_SIZE[0]}"
    assert size[1] <= MAX_SIZE[1], f"largo {size[1]:.2f} por encima de {MAX_SIZE[1]}"
    assert size[2] <= MAX_SIZE[2], f"alto {size[2]:.2f} por encima de {MAX_SIZE[2]}"
    assert size[0] > GRUA_TOKEN["ancho_x"], "no es mas ancha que la ficha grua"
    assert size[1] > GRUA_TOKEN["largo_y"], "no es mas larga que la ficha grua"
    assert size[2] > GRUA_TOKEN["alto_z"], "no es mas alta que la ficha grua"
    assert deck_len >= DECK_MIN_LENGTH, f"plataforma de {deck_len}, no cabe un vehiculo de {DECK_MIN_LENGTH}"
    for key in WHEEL_AXLES:
        assert count(wheels[key]) + count(hubs[key]) <= 160, f"rueda {key} con demasiados triangulos"
    for obj in [*body.values(), *wheels.values(), *hubs.values()]:
        assert len(obj.data.materials) == 1, f"{obj.name} tiene varios materiales"
        assert obj.location.length < 1e-6, f"{obj.name} no tiene el origen en el centro de la base"

    # LOD1: una sola malla, un solo material (amarillo) y menos de la mitad de los triangulos.
    lod_parts = [lod_part(obj, (0.0, 0.0, 0.0), mats["amarillo"]) for obj in body.values()]
    lod_parts += [lod_part(wheels[key], WHEEL_AXLES[key], mats["amarillo"]) for key in WHEEL_AXLES]
    lod_parts += [lod_part(hubs[key], WHEEL_AXLES[key], mats["amarillo"]) for key in WHEEL_AXLES]
    lod = join(lod_parts, "towtruck_LOD1")
    decimate = lod.modifiers.new("Decimate", "DECIMATE")
    decimate.ratio = LOD_RATIO
    apply_modifiers(lod)
    select_only(lod)
    bpy.ops.object.material_slot_remove_unused()
    assert len(lod.data.materials) == 1, "el LOD1 tiene mas de un material"

    # Las ruedas y los tapacubos se exportan con su origen en el eje y ya colocados en su sitio del
    # camion. Asi Roblox los deja en el eje al cargarlos (el FBX lleva la traslacion del objeto) y
    # siguen girando alrededor de su propio centro.
    for key in WHEEL_AXLES:
        wheels[key].location = WHEEL_AXLES[key]
        hubs[key].location = WHEEL_AXLES[key]

    files = {}
    for obj in body.values():
        export(obj, f"{obj.name}.fbx")
        files[obj.name] = count(obj)
    for key in WHEEL_AXLES:
        export(wheels[key], f"towtruck_wheel_{key}.fbx")
        export(hubs[key], f"towtruck_hub_{key}.fbx")
        files[f"towtruck_wheel_{key}"] = count(wheels[key])
        files[f"towtruck_hub_{key}"] = count(hubs[key])
    export(lod, "towtruck_LOD1.fbx")
    total = sum(files.values())
    lod_triangles = count(lod)
    assert total <= TOTAL_BUDGET, f"{total} triangulos, por encima de {TOTAL_BUDGET}"
    assert lod_triangles <= total / 2, f"LOD1 con {lod_triangles}, mas de la mitad de {total}"

    stats = {
        "modelo": "grua-remolque",
        "unidades": "studs (1 unidad de Blender = 1 stud)",
        "origen": "centro de la base, a ras de suelo (x = 0, y = 0, z = 0)",
        "frente": "-Y (morro)",
        "arriba": "+Z",
        "triangulos": {
            "piezas": files,
            "total": total,
            "lod1": lod_triangles,
            "lod1_mitad_del_total": round(total / 2, 1),
            "lod1_porcentaje": round(100 * lod_triangles / total, 1),
            "presupuesto_total": TOTAL_BUDGET,
        },
        "medidas": {
            "ancho_x": round(size[0], 3),
            "largo_y": round(size[1], 3),
            "alto_z": round(size[2], 3),
            "min_z": round(lo[2], 4),
            "max_z": round(hi[2], 3),
            "maximos_permitidos": list(MAX_SIZE),
            "ficha_grua": GRUA_TOKEN,
            "mayor_que_ficha_grua": True,
        },
        "plataforma": {
            "inicio_y": DECK_Y0,
            "fin_y": DECK_Y1,
            "largo_y": deck_len,
            "ancho_x": 2 * DECK_HALF,
            "z_superior": DECK_TOP,
            "barandilla_z": RAIL_TOP,
            "vehiculo_maximo_y": DECK_MIN_LENGTH,
        },
        "pluma": {
            "pivote": list(BOOM_P0),
            "punta": list(BOOM_P1),
            "altura_max_z": round(hi[2], 3),
            "cable_y": HOOK_Y,
        },
        "gancho": {
            "y": HOOK_Y,
            "x": HOOK_X,
            "z_superior": HOOK_TOP,
            "z_inferior": round(HOOK_TOP + HOOK_CENTER_Z - HOOK_R_OUT, 3),
            "despeje_plataforma": round(HOOK_TOP + HOOK_CENTER_Z - HOOK_R_OUT - DECK_TOP, 3),
        },
        "ruedas": {
            key: {
                "archivo": f"towtruck_wheel_{key}.fbx",
                "tapacubos": f"towtruck_hub_{key}.fbx",
                "eje": list(WHEEL_AXLES[key]),
                "giro": "X",
                "radio": WHEEL_RADIUS,
                "ancho": WHEEL_DEPTH,
            }
            for key in WHEEL_AXLES
        },
        "materiales": {
            **{obj.name: obj.data.materials[0].name for obj in body.values()},
            **{f"towtruck_wheel_{key}": "asfalto" for key in WHEEL_AXLES},
            **{f"towtruck_hub_{key}": "acero" for key in WHEEL_AXLES},
            "towtruck_LOD1": "amarillo",
        },
        "paleta": {"amarillo": "F5C518", "acero": "A8AEB4", "asfalto": "2A2E33", "cristal": "2E4A63"},
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("GRUA_STATS", json.dumps(stats))

    # Escena de render: suelo, sol, avatar de referencia y las tres camaras.
    lod.hide_render = True
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.1))
    ground = bpy.context.active_object
    ground.name = "ground"
    ground.scale = (120.0, 120.0, 0.2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ground.data.materials.append(mats["suelo"])

    avatar = build_avatar(flat("avatar_ref", "5E636A", 0.8))
    for obj in avatar:
        obj.location.y += 11.9
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

    render(scene, camera("frontal", (-18.0, -27.0, 14.5), (0.0, 0.3, 3.3), lens=50), "grua-remolque-3-4-frontal.png")
    render(scene, camera("trasera", (18.0, 27.0, 14.5), (0.0, 0.3, 3.3), lens=50), "grua-remolque-3-4-trasero.png")
    for obj in avatar:
        obj.hide_render = False
    render(scene, camera("perfil", (60.0, 1.5, 3.6), (0.0, 1.5, 3.6), ortho_scale=30.0), "grua-remolque-perfil-avatar.png")
    print("GRUA_RENDERS_OK")


if __name__ == "__main__":
    main()

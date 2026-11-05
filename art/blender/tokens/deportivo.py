"""Ficha deportivo: token de vehiculo de Flip the Table.

Coupe deportivo rojo, bajo y ancho, de morro largo y aleron: la silueta se lee como una cuna. La
carroceria es una sola piel hecha por estaciones, con el arco de rueda rebajado de verdad en la chapa y
aletas que nacen de ella; cabina estrecha con parabrisas y luna trasera tumbados, montantes rojos y
cristales con marco oscuro en relieve; faldones, branquias laterales, aleron de dos soportes sobre la
cubierta trasera plana y escape doble. Sin marcas, logotipos ni matriculas reales.

Salidas, en art/blender/tokens/deportivo/:
  sport_body_<material>.fbx    carroceria, una malla por material (origen en el centro de la base)
  sport_plate.fbx              placa de la cubierta trasera, separada: se tine con el color del jugador
  sport_wheel_{fl,fr,rl,rr}.fbx neumatico, con el origen en su eje de giro (eje X)
  sport_hub_{fl,fr,rl,rr}.fbx   tapacubos de acero, en malla aparte, mismo origen y eje que su rueda
  sport_LOD1.fbx               una sola malla y un solo material (color de carroceria)
  stats.json                   triangulos por pieza, total y LOD1, medidas, ejes y seat
Y en art/render/tokens/deportivo/: 3/4 frontal, 3/4 trasera y perfil con avatar de 6 studs al lado.

Convenciones (como taxi.py): 1 unidad de Blender = 1 stud, el morro mira a -Y, Z hacia arriba, origen
en el centro de la base a ras de suelo, exportacion FBX con Z Forward / Y Up.

Uso (segundo plano, sin abrir Blender):
  "D:\\blender\\blender.exe" --background --factory-startup --python art/blender/tokens/deportivo.py
"""

import glob
import json
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "deportivo")
RENDER = os.path.join(REPO, "art", "render", "tokens", "deportivo")

LOD_RATIO = 0.5
TOTAL_BUDGET = 3000
PART_BUDGET = 120  # rueda con su tapacubos
LIMITES = {"ancho_x": 6.5, "largo_y": 12.0, "alto_z": 4.2}
REFERENCIA_TAXI = {"triangles": 2580, "size_x": 6.4, "size_y": 12.4, "size_z": 5.1}

# --- Ruedas: origen en el eje de giro. l = -X, r = +X (de frente).
WHEEL_RADIUS = 0.88
WHEEL_DEPTH = 0.82
HUB_RADIUS = 0.56
HUB_DEPTH = 0.80
HUB_CAP_RADIUS = 0.22
HUB_CAP_DEPTH = 0.86
AXLE_Z = WHEEL_RADIUS
ARCH_RADIUS = 1.02  # radio del rebaje real de la chapa sobre el neumatico
ARCH_INNER_X = 2.30
FRONT_AXLE_Y = -3.55
REAR_AXLE_Y = 3.50
WHEEL_AXLES = {
    "fl": (-2.42, FRONT_AXLE_Y, AXLE_Z),
    "fr": (2.42, FRONT_AXLE_Y, AXLE_Z),
    "rl": (-2.42, REAR_AXLE_Y, AXLE_Z),
    "rr": (2.42, REAR_AXLE_Y, AXLE_Z),
}

# --- Carroceria: estaciones a lo largo de Y. Cada una define la seccion (x, z) del lateral derecho.
# (y, zb, w1, z1, w2, z2, zt): suelo, bajofondo, punto mas ancho y su altura, y cota del techo plano.
# El borde superior de la chapa se calcula como w2 - CHAMFER: una arista corta, no una repisa.
CHAMFER = 0.26
BODY_STATIONS = [
    (-5.96, 0.50, 1.55, 0.64, 2.05, 0.85, 0.98),
    (-5.60, 0.44, 1.90, 0.56, 2.42, 1.10, 1.26),
    (-5.10, 0.42, 2.14, 0.54, 2.70, 1.35, 1.56),
    (-4.45, 0.42, 2.28, 0.54, 2.88, 1.60, 1.92),
    (-3.55, 0.42, 2.32, 0.56, 2.98, 1.65, 2.28),
    (-2.70, 0.42, 2.32, 0.56, 2.90, 1.70, 2.38),
    (-1.30, 0.42, 2.32, 0.56, 2.92, 1.78, 2.44),
    (0.00, 0.42, 2.32, 0.56, 2.96, 1.86, 2.48),
    (0.65, 0.42, 2.34, 0.56, 3.00, 1.92, 2.50),
    (2.10, 0.42, 2.36, 0.56, 3.12, 2.02, 2.50),
    (3.50, 0.42, 2.36, 0.56, 3.20, 2.06, 2.50),
    (4.60, 0.42, 2.34, 0.56, 3.12, 2.02, 2.50),
    (5.45, 0.42, 2.32, 0.56, 2.98, 1.94, 2.50),
    (5.88, 0.50, 2.22, 0.64, 2.86, 1.88, 2.36),
]
ARCH_STEPS = (-0.98, -0.72, -0.40, 0.40, 0.72, 0.98)

# --- Cabina: prisma estrecho con parabrisas y luna trasera tumbados.
CABIN_HALF = 1.90
CABIN_POINTS = [(-2.70, 2.30), (-1.45, 3.52), (-0.30, 3.52), (0.65, 2.42)]
ROOF_Z = 3.52
WINDSHIELD = ((-2.70, 2.30), (-1.45, 3.52))
BACKLIGHT = ((-0.30, 3.52), (0.65, 2.42))
FRAME_HALF = 1.68
GLASS_HALF = 1.50
SIDE_WINDOW = [(-2.02, 2.72), (-1.22, 3.30), (-0.18, 3.32), (0.38, 2.76)]

# --- Placa sobre la cubierta trasera plana: 4,0 x 4,0, nada encima.
DECK_Z = 2.50
PLATE_SIZE = (4.0, 4.0, 0.10)
PLATE_CENTER = (0.0, 2.80, DECK_Z + 0.05)
SEAT = (0.0, 2.80, DECK_Z + 0.10)
PLATE_HALF_Y = PLATE_SIZE[1] / 2

# --- Aleron: entero por detras de la placa, sobre dos soportes.
WING_Y0 = 4.95
WING_Y1 = 5.86
WING_Z = 3.30
WING_HALF = 1.86
TAIL_Y = 5.88


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


def box(name, size, location, mat, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    obj.rotation_euler = rotation
    # La posicion se hornea en la malla: el origen de cada pieza queda en el centro de la base.
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(mat)
    return obj


def bevel(obj, width, segments=2):
    """Bisel en los bordes de angulo vivo: redondea las formas grandes."""
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


def mesh_object(name, verts, faces, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    return close_normals(obj)


def prism(name, points, x0, x1, mat):
    """Prisma con el perfil (y, z) `points` tendido entre los planos x0 y x1."""
    n = len(points)
    verts = [(x0, y, z) for y, z in points] + [(x1, y, z) for y, z in points]
    faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return mesh_object(name, verts, faces, mat)


def profile(name, points, half_width, mat, x_center=0.0):
    return prism(name, points, x_center - half_width, x_center + half_width, mat)


def loft(name, sections, mat):
    """Piel entre estaciones. `sections` = [(y, [(x, z), ...])] con el mismo numero de puntos."""
    n = len(sections[0][1])
    verts = [(x, y, z) for y, points in sections for x, z in points]
    faces = []
    for k in range(len(sections) - 1):
        for i in range(n):
            j = (i + 1) % n
            faces.append((k * n + i, k * n + j, (k + 1) * n + j, (k + 1) * n + i))
    faces.append(tuple(range(n)))
    faces.append(tuple(range(len(verts) - n, len(verts))))
    return mesh_object(name, verts, faces, mat)


# --- Seccion de la carroceria -------------------------------------------------


def station_params(y):
    """Interpola los parametros de la tabla de estaciones."""
    table = BODY_STATIONS
    if y <= table[0][0]:
        return table[0][1:]
    for first, second in zip(table, table[1:]):
        if first[0] <= y <= second[0]:
            t = (y - first[0]) / (second[0] - first[0])
            return tuple(a + (b - a) * t for a, b in zip(first[1:], second[1:]))
    return table[-1][1:]


def right_half(y):
    """Lateral derecho de la seccion: del suelo al centro del techo, con el arco de rueda ya rebajado."""
    zb, w1, z1, w2, z2, zt = station_params(y)
    z1 = max(z1, zb + 0.12)
    for axle in (FRONT_AXLE_Y, REAR_AXLE_Y):
        dy = y - axle
        # Arco real: el borde inferior de la chapa sube por encima del neumatico.
        if abs(dy) < ARCH_RADIUS:
            f = math.sqrt(max(0.0, 1.0 - (dy / ARCH_RADIUS) ** 2))
            z1 = max(z1, zb + 0.14 + (AXLE_Z + ARCH_RADIUS - zb - 0.14) * f)
            w1 = min(w1, ARCH_INNER_X)
    # Sobre la rueda el borde ancho es el labio de la aleta y la banda de chapa sube casi vertical.
    z4 = min(max(z2, z1 + 0.30), zt - 0.05)
    z4 = max(z4, z1 + 0.04)
    wt = w2 - CHAMFER
    return [
        (0.0, zb),
        (w1, zb),
        (w1, z1),
        (w2 - 0.06, z1 + 0.02),
        (w2, z4),
        (wt, zt),
        (0.0, zt),
    ]


def section(y):
    half = right_half(y)
    return half + [(-x, z) for x, z in reversed(half[1:-1])]


def surface_x(y, z):
    """Ancho de la chapa en (y, z): sirve para pegar detalles laterales sin que floten."""
    pts = right_half(y)
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        low, high = min(z0, z1), max(z0, z1)
        if low - 1e-6 <= z <= high + 1e-6:
            if abs(z1 - z0) < 1e-9:
                return max(x0, x1)
            t = (z - z0) / (z1 - z0)
            return x0 + (x1 - x0) * t
    return pts[1][0]


def top_z(y):
    """Altura del centro del capo / cubierta en esa estacion."""
    return station_params(y)[5]


def top_slope(y):
    step = 0.05
    return math.atan2(top_z(y + step) - top_z(y - step), 2 * step)


def station_ys():
    values = [station[0] for station in BODY_STATIONS]
    for axle in (FRONT_AXLE_Y, REAR_AXLE_Y):
        values += [axle + step for step in ARCH_STEPS]
    return sorted(values)


def build_hull(mat):
    return bevel(loft("hull", [(y, section(y)) for y in station_ys()], mat), 0.09, 1)


def arch_liner(name, axle_y, side, mat, segments=4):
    """Pase de rueda oscuro: banda curva justo por encima del neumatico, dentro del arco de chapa."""
    angles = [math.pi * (0.12 + 0.76 * i / segments) for i in range(segments + 1)]
    outer = [(axle_y + 1.02 * math.cos(t), AXLE_Z + 1.02 * math.sin(t)) for t in angles]
    inner = [(axle_y + 0.95 * math.cos(t), AXLE_Z + 0.95 * math.sin(t)) for t in reversed(angles)]
    x0 = side * 1.84
    x1 = side * 2.94
    return prism(name, outer + inner, min(x0, x1), max(x0, x1), mat)


# --- Utilidades de detalle ----------------------------------------------------


def slope_slab(name, p0, p1, t0, t1, ext, half, mat, x_center=0.0):
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
    return profile(name, points, half, mat, x_center)


def quad_slab(name, points, x0, x1, mat, pad_y=0.0, pad_z=0.0):
    """Prisma de cuatro lados, opcionalmente dilatado en (y, z) para que haga de marco."""
    ys = [p[0] for p in points]
    zs = [p[1] for p in points]
    cy, cz = (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2
    sy = (max(ys) - min(ys) + 2 * pad_y) / (max(ys) - min(ys))
    sz = (max(zs) - min(zs) + 2 * pad_z) / (max(zs) - min(zs))
    grown = [(cy + (y - cy) * sy, cz + (z - cz) * sz) for y, z in points]
    return prism(name, grown, x0, x1, mat)


def cylinder(name, radius, depth, location, mat, vertices=10, axis="Y"):
    """Cilindro con el eje pedido, centrado en `location`."""
    rotation = (math.pi / 2, 0, 0) if axis == "Y" else (0, math.pi / 2, 0)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=depth, location=(0, 0, 0), rotation=rotation
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    obj.location = location
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    obj.data.materials.append(mat)
    return obj


def disc(name, radius, depth, verts, mat):
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


# --- Carroceria ---------------------------------------------------------------


def build_body(mats):
    rojo, dark, glass, steel, cream, orange = (
        mats["rojo"],
        mats["asfalto"],
        mats["cristal"],
        mats["acero"],
        mats["caliza"],
        mats["naranja"],
    )
    parts = []
    parts.append(build_hull(rojo))
    for side in (-1, 1):
        for axle_y in (FRONT_AXLE_Y, REAR_AXLE_Y):
            parts.append(arch_liner("arch_liner", axle_y, side, dark))

    # Cabina: prisma estrecho; los montantes son el borde rojo que queda fuera del marco oscuro.
    parts.append(bevel(profile("cabin", CABIN_POINTS, CABIN_HALF, rojo), 0.10))

    # Parabrisas y luna trasera: marco oscuro hundido y cristal menor y mas alto entre montantes.
    parts.append(slope_slab("windshield_frame", WINDSHIELD[0], WINDSHIELD[1], -0.04, 0.08, -0.04, FRAME_HALF, dark))
    parts.append(slope_slab("windshield", WINDSHIELD[0], WINDSHIELD[1], 0.08, 0.125, -0.18, GLASS_HALF, glass))
    parts.append(slope_slab("backlight_frame", BACKLIGHT[0], BACKLIGHT[1], -0.04, 0.08, -0.04, FRAME_HALF, dark))
    parts.append(slope_slab("backlight", BACKLIGHT[0], BACKLIGHT[1], 0.08, 0.125, -0.16, GLASS_HALF, glass))

    # Ventanillas laterales con marco oscuro y montante rojo visible por delante y por detras.
    for side in (-1, 1):
        center = side * CABIN_HALF
        parts.append(quad_slab("side_frame", SIDE_WINDOW, center, center + side * 0.05, dark, 0.10, 0.07))
        parts.append(quad_slab("side_glass", SIDE_WINDOW, center + side * 0.05, center + side * 0.085, glass))
    parts.append(slope_slab("wiper", WINDSHIELD[0], WINDSHIELD[1], 0.11, 0.155, -0.32, 0.055, dark, x_center=0.22))

    # Morro: splitter, boca, faros, intermitentes y branquias del capo pegadas a su pendiente.
    parts.append(bevel(box("splitter", (4.50, 0.22, 0.10), (0, -5.88, 0.44), dark), 0.03))
    parts.append(box("front_mouth", (2.40, 0.14, 0.24), (0, -5.95, 0.70), dark))
    for side in (-1, 1):
        parts.append(box("headlight", (0.90, 0.10, 0.15), (side * 1.28, -5.95, 0.92), cream))
        parts.append(box("indicator", (0.20, 0.08, 0.10), (side * 1.84, -5.93, 0.84), orange))
        for y in (-3.45, -3.15):
            parts.append(
                box("hood_vent", (0.66, 0.28, 0.10), (side * 0.62, y, top_z(y) + 0.01), dark, (top_slope(y), 0, 0))
            )
    parts.append(box("cowl_vent", (3.20, 0.16, 0.08), (0, -2.52, top_z(-2.52) + 0.01), dark))

    # Laterales: faldon, branquias y manilla pegadas a la chapa con surface_x.
    for side in (-1, 1):
        parts.append(box("side_skirt", (0.16, 4.30, 0.18), (side * 2.36, 0.15, 0.45), dark))
        for z in (1.10, 1.32, 1.54):
            x = surface_x(1.70, z)
            parts.append(box("gill", (0.30, 0.86, 0.09), (side * (x - 0.13), 1.70, z), dark))
        handle_x = surface_x(-0.90, 1.74)
        parts.append(box("handle", (0.16, 0.34, 0.10), (side * (handle_x - 0.03), -0.90, 1.74), steel))
        # Espejo: caja oscura encajada en el montante, sobresale lo justo para verse.
        parts.append(box("mirror", (0.42, 0.30, 0.20), (side * 2.02, -2.30, 2.50), dark))
        # Branquias de la cubierta, fuera de la huella de la placa.
        for y in (1.80, 2.40, 3.00):
            parts.append(box("deck_louver", (0.20, 0.56, 0.06), (side * 2.22, y, DECK_Z - 0.02), dark))

    # Trasera: panel oscuro, pilotos, valance, escape doble y difusor.
    parts.append(box("tail_panel", (4.40, 0.14, 0.70), (0, 5.85, 1.92), dark))
    for side in (-1, 1):
        parts.append(box("taillight", (1.34, 0.10, 0.26), (side * 1.20, 5.90, 1.90), orange))
    parts.append(box("reverse_light", (0.60, 0.10, 0.15), (0, 5.90, 1.88), cream))
    parts.append(box("rear_valance", (3.10, 0.16, 0.48), (0, 5.84, 0.76), dark))
    for side in (-1, 1):
        parts.append(cylinder("exhaust", 0.16, 0.30, (side * 0.60, 5.79, 0.78), steel, vertices=8))
    for x in (-1.35, 0.0, 1.35):
        parts.append(box("diffuser_fin", (0.09, 0.42, 0.24), (x, 5.72, 0.50), dark))

    # Aleron: dos soportes oscuros, plano inclinado y placas de extremo.
    for side in (-1, 1):
        parts.append(box("wing_strut", (0.16, 0.30, 0.86), (side * 0.98, 5.42, 2.88), dark))
        parts.append(box("wing_endplate", (0.06, 0.88, 0.46), (side * WING_HALF, 5.40, 3.28), dark))
    parts.append(
        box(
            "wing_plane",
            (WING_HALF * 2, WING_Y1 - WING_Y0, 0.12),
            (0.0, (WING_Y0 + WING_Y1) / 2, WING_Z),
            dark,
            rotation=(math.radians(-7), 0, 0),
        )
    )
    return parts


def build_plate(mats):
    return bevel(box("sport_plate", PLATE_SIZE, PLATE_CENTER, mats["plate"]), 0.03)


def build_hub(key, mat):
    """Tapacubos: disco de acero con un centro abombado, una sola malla y un solo material."""
    parts = [disc(f"sport_hub_{key}", HUB_RADIUS, HUB_DEPTH, 10, mat)]
    parts.append(disc(f"sport_hub_{key}_cap", HUB_CAP_RADIUS, HUB_CAP_DEPTH, 6, mat))
    return join(parts, f"sport_hub_{key}")


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


def lod_copy(source, location, material):
    copy = source.copy()
    copy.data = source.data.copy()
    copy.name = f"{source.name}_lod"
    bpy.context.collection.objects.link(copy)
    copy.location = location
    copy.data.materials.clear()
    copy.data.materials.append(material)
    decimate = copy.modifiers.new("Decimate", "DECIMATE")
    decimate.ratio = LOD_RATIO
    apply_modifiers(copy)
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
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.8, location=(0, 0, 5.2))
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
        "rojo": flat("rojo", "C4382B", 0.35),
        "asfalto": flat("asfalto", "23272C", 0.85),
        "cristal": flat("cristal", "7FB2D9", 0.12, 0.0),
        "acero": flat("acero", "A8AEB4", 0.25, 0.8),
        "caliza": flat("caliza", "EDE5D3", 0.6),
        "naranja": flat("naranja", "E07A3C", 0.55),
        "plate": flat("plate", "EDEAE3", 0.5),
        "ground": flat("ground", "8E9196", 0.9),
    }

    body = group_by_material(build_body(mats), "sport_body")
    plate = build_plate(mats)
    wheels = {key: disc(f"sport_wheel_{key}", WHEEL_RADIUS, WHEEL_DEPTH, 16, mats["asfalto"]) for key in WHEEL_AXLES}
    hubs = {key: build_hub(key, mats["acero"]) for key in WHEEL_AXLES}

    # Comprobaciones antes de exportar.
    entries = [(obj, (0.0, 0.0, 0.0)) for obj in body.values()] + [(plate, (0.0, 0.0, 0.0))]
    entries += [(wheels[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    entries += [(hubs[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    lo, hi = bounds(entries)
    plate_lo, plate_hi = bounds([(plate, (0.0, 0.0, 0.0))])
    seat = (round((plate_lo[0] + plate_hi[0]) / 2, 4), round((plate_lo[1] + plate_hi[1]) / 2, 4), round(plate_hi[2], 4))
    width, length, height = hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]
    deck = TAIL_Y - BACKLIGHT[1][0]
    assert plate_hi[0] - plate_lo[0] >= 4.0 - 1e-6 and plate_hi[1] - plate_lo[1] >= 4.0 - 1e-6, "placa menor de 4 x 4"
    assert abs(plate_lo[2] - DECK_Z) < 1e-6, "la placa no apoya en la cubierta"
    assert abs(seat[2] - plate_hi[2]) < 1e-6, "el seat no coincide con la cara superior de la placa"
    assert WING_Y0 > plate_hi[1], "el aleron invade la vertical de la placa"
    assert abs(lo[2]) < 1e-6, f"la ficha no apoya en el suelo: min_z = {lo[2]}"
    assert width <= LIMITES["ancho_x"], f"ancho {width:.2f} por encima de {LIMITES['ancho_x']}"
    assert length <= LIMITES["largo_y"], f"largo {length:.2f} por encima de {LIMITES['largo_y']}"
    assert height <= LIMITES["alto_z"], f"alto {height:.2f} por encima de {LIMITES['alto_z']}"
    assert AXLE_Z + ARCH_RADIUS > AXLE_Z + WHEEL_RADIUS, "el arco no cubre el neumatico"
    for key in WHEEL_AXLES:
        assert count(wheels[key]) + count(hubs[key]) <= PART_BUDGET, f"rueda {key} por encima de {PART_BUDGET}"
    for obj in [*body.values(), plate, *wheels.values(), *hubs.values()]:
        assert len(obj.data.materials) == 1, f"{obj.name} tiene varios materiales"
    # Nada por encima de la placa dentro de su huella: el avatar tiene que caber de pie.
    for obj in body.values():
        for vertex in obj.data.vertices:
            point = Vector(vertex.co)
            if abs(point[0]) <= PLATE_SIZE[0] / 2 and abs(point[1] - PLATE_CENTER[1]) <= PLATE_HALF_Y:
                assert point[2] <= plate_hi[2] + 1e-6, f"{obj.name} invade la vertical de la placa"

    # LOD1: una sola malla con un solo material (carroceria), reducida al 50 %.
    red = body["rojo"]
    lod_parts = [lod_copy(red, (0.0, 0.0, 0.0), mats["rojo"])]
    lod_parts += [lod_copy(wheels[key], WHEEL_AXLES[key], mats["rojo"]) for key in WHEEL_AXLES]
    lod = join(lod_parts, "sport_LOD1")
    select_only(lod)
    bpy.ops.object.material_slot_remove_unused()
    assert len(lod.data.materials) == 1, "el LOD1 tiene mas de un material"

    # Las ruedas y los tapacubos se exportan con su origen en el eje y ya colocados en su sitio del
    # coche. Asi Roblox los deja en el eje al cargarlos y siguen girando alrededor de su propio centro.
    for key in WHEEL_AXLES:
        wheels[key].location = WHEEL_AXLES[key]
        hubs[key].location = WHEEL_AXLES[key]

    files = {}
    for obj in body.values():
        export(obj, f"{obj.name}.fbx")
        files[obj.name] = count(obj)
    export(plate, "sport_plate.fbx")
    files["sport_plate"] = count(plate)
    for key in WHEEL_AXLES:
        export(wheels[key], f"sport_wheel_{key}.fbx")
        export(hubs[key], f"sport_hub_{key}.fbx")
        files[f"sport_wheel_{key}"] = count(wheels[key])
        files[f"sport_hub_{key}"] = count(hubs[key])
    export(lod, "sport_LOD1.fbx")
    total = sum(files.values())
    lod_triangles = count(lod)
    assert total <= TOTAL_BUDGET, f"{total} triangulos, por encima de {TOTAL_BUDGET}"
    assert lod_triangles <= total / 2, f"LOD1 con {lod_triangles}, mas de la mitad de {total}"

    stats = {
        "modelo": "deportivo",
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
            "maletero": {
                "inicio_y": BACKLIGHT[1][0],
                "largo": round(deck, 3),
                "porcentaje_del_largo": round(100 * deck / length, 1),
                "z_superior": DECK_Z,
            },
            "placa": {
                "tamano_x": round(plate_hi[0] - plate_lo[0], 3),
                "tamano_y": round(plate_hi[1] - plate_lo[1], 3),
                "z_inferior": round(plate_lo[2], 4),
                "z_superior": round(plate_hi[2], 4),
                "centro_xy": [PLATE_CENTER[0], PLATE_CENTER[1]],
            },
            "aleron": {
                "y_inicio": WING_Y0,
                "y_fin": WING_Y1,
                "z": WING_Z,
                "ancho_x": round(2 * WING_HALF, 3),
            },
            "referencia_taxi": REFERENCIA_TAXI,
        },
        "seat": list(seat),
        "ruedas": {
            key: {
                "archivo": f"sport_wheel_{key}.fbx",
                "tapacubos": f"sport_hub_{key}.fbx",
                "eje": list(WHEEL_AXLES[key]),
                "giro": "X",
                "radio": WHEEL_RADIUS,
                "ancho": WHEEL_DEPTH,
            }
            for key in WHEEL_AXLES
        },
        "materiales": {
            **{obj.name: obj.data.materials[0].name for obj in body.values()},
            "sport_plate": "plate",
            **{f"sport_wheel_{key}": "asfalto" for key in WHEEL_AXLES},
            **{f"sport_hub_{key}": "acero" for key in WHEEL_AXLES},
            "sport_LOD1": "rojo",
        },
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("DEPORTIVO_STATS", json.dumps(stats))

    # Ruedas y tapacubos a su eje, para el render (los FBX ya se exportaron con el origen en el eje).
    for key in WHEEL_AXLES:
        wheels[key].location = WHEEL_AXLES[key]
        hubs[key].location = WHEEL_AXLES[key]
    lod.hide_render = True

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.1))
    ground = bpy.context.active_object
    ground.name = "ground"
    ground.scale = (90.0, 90.0, 0.2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ground.data.materials.append(mats["ground"])

    avatar = build_avatar(flat("avatar_ref", "5E636A", 0.8))
    for obj in avatar:
        obj.location.y += 10.0
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

    render(scene, camera("frontal", (-12.0, -21.0, 12.0), (0.0, 0.0, 2.0), lens=50), "deportivo-3-4-frontal.png")
    render(scene, camera("trasera", (12.0, 21.0, 12.0), (0.0, 0.0, 2.0), lens=50), "deportivo-3-4-trasera.png")
    for obj in avatar:
        obj.hide_render = False
    render(scene, camera("perfil", (60.0, 4.0, 3.0), (0.0, 4.0, 3.0), ortho_scale=26.0), "deportivo-perfil-avatar.png")
    print("DEPORTIVO_RENDERS_OK")


if __name__ == "__main__":
    main()

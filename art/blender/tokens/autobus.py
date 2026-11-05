"""Ficha autobus: token de vehiculo urbano de Flip the Table.

Autobus urbano de una sola planta, azul y crema: frontal plano con parabrisas partido y cartel de
destino sin texto, muchas ventanillas con marco oscuro hundido y montantes, dos puertas plegables por
lado, banda crema de cintura, techo crema con la placa del asiento centrada y cuatro ruedas dentro de
arcos reales abiertos en la chapa. Espejos de brazo largo en las esquinas delanteras: son los que
hacen que la silueta se reconozca aunque se vea en negro. Sin marcas, logotipos, texto legible ni
matriculas reales.

Salidas, en art/blender/tokens/autobus/:
  bus_body_<material>.fbx      carroceria, una malla por material (origen en el centro de la base)
  bus_plate.fbx                placa del techo, separada: se tine con el color del jugador
  bus_wheel_{fl,fr,rl,rr}.fbx  neumatico, con el origen en su eje de giro (eje X)
  bus_hub_{fl,fr,rl,rr}.fbx    tapacubos de acero, en malla aparte, mismo origen y eje que su rueda
  bus_LOD1.fbx                 una sola malla y un solo material (color de carroceria)
  stats.json                   triangulos por pieza, total y LOD1, medidas, ejes y seat
Y en art/render/tokens/autobus/: 3/4 frontal, 3/4 trasero y perfil con avatar de 6 studs al lado.

Convenciones (como art/blender/tokens/taxi.py): 1 unidad de Blender = 1 stud, el morro mira a -Y, Z
hacia arriba, origen en el centro de la base a ras de suelo, exportacion FBX con Z Forward / Y Up.

Uso (segundo plano, sin abrir Blender):
  "D:\\blender\\blender.exe" --background --factory-startup --python art/blender/tokens/autobus.py
"""

import glob
import json
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "autobus")
RENDER = os.path.join(REPO, "art", "render", "tokens", "autobus")

LOD_RATIO = 0.5
TOTAL_BUDGET = 3000
PART_BUDGET = 120  # rueda con su tapacubos
LIMITS = {"ancho_x": 6.5, "largo_y": 16.0, "alto_z": 7.5}

# Caja del vehiculo. Morro en -Y, trasera en +Y. Mas alto que ancho, como un autobus urbano.
NOSE = -7.70
TAIL = 7.70
BODY_HALF = 2.95
PANEL_INNER = 2.45
PANEL_BOTTOM = 0.85  # faldon bajo: el autobus es de piso bajo, no va sobre zancos
BODY_BOTTOM = 3.00
ROOF_Z = 6.30
BELT_Z = 2.84  # centro de la banda crema que tapa la junta de la chapa
BELT_HEIGHT = 0.28
BELT_SEGMENTS = [(-7.78, -7.04), (-5.06, 0.46), (2.44, 7.72)]  # la banda se corta en las puertas

# Planos de la chapa lateral: marco, cristal y moldura.
FRAME_OUT = 3.00
FRAME_IN = 2.85
GLASS_X = 2.94
BEAD_X = 2.95
BELT_X = 2.97

# Ventanillas y puertas laterales (vanos, sin marco). De delante a atras.
# Las puertas bajan por debajo de la banda de cintura: eso las distingue de las ventanillas.
WINDOW_Z = (3.14, 5.40)
DOOR_Z = (2.50, 5.48)
SIDE_WINDOWS = [(-4.65, -2.55), (-2.05, 0.05), (2.85, 4.95), (5.35, 7.35)]
SIDE_DOORS = [(-6.95, -5.15), (0.55, 2.35)]

# Frontal plano.
WINDSHIELD = (-2.68, 2.68, 3.10, 5.30)  # x0, x1, z0, z1
SIGN = (-1.95, 1.95, 5.52, 6.06)  # x0, x1, z0, z1
HEADLIGHT_X = 1.98
MIRROR_X = 3.19
# Trasera: ventana, rejilla del motor, pilotos, parachoques.
REAR_WINDOW = (-2.42, 2.42, 3.55, 5.36)
GRILLE_Z = (1.95, 2.75)
TAILLIGHT_X = 2.43

# Ruedas: origen en el eje de giro, en studs, relativo a la base. l = -X, r = +X (de frente).
WHEEL_AXLES = {
    "fl": (-2.42, -4.40, 1.00),
    "fr": (2.42, -4.40, 1.00),
    "rl": (-2.42, 5.20, 1.00),
    "rr": (2.42, 5.20, 1.00),
}
WHEEL_RADIUS = 1.0
WHEEL_DEPTH = 0.90
HUB_RADIUS = 0.42
HUB_DEPTH = 0.98
ARCH_RADIUS = 1.30  # arco abierto en la chapa, con el centro en el eje de la rueda
WHEEL_Z = 1.0

# Techo y placa del asiento (centrada, 4,6 x 5,8: cabe con holgura sobre el techo).
ROOF_TOP = 6.52
PLATE_SIZE = (4.60, 5.80, 0.12)
PLATE_CENTER = (0.0, 0.0, ROOF_TOP + 0.06)
SEAT_Z = ROOF_TOP + 0.12


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


def close_normals(obj):
    select_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def apply_modifiers(obj):
    select_only(obj)
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)


def box(name, size, location, mat, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    # La posicion se hornea en la malla: el origen de cada pieza queda en el centro de la base.
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


def triangulate(points):
    """Triangulacion por orejas de un poligono simple (y, z). Sin esto, el hueco del arco se rellena."""
    n = len(points)
    idx = list(range(n))
    area = 0.0
    for i in range(n):
        y0, z0 = points[i]
        y1, z1 = points[(i + 1) % n]
        area += y0 * z1 - y1 * z0
    if area < 0:
        idx.reverse()
    tris = []
    guard = 0
    while len(idx) > 3 and guard < 4096:
        guard += 1
        cut = False
        for k in range(len(idx)):
            i0, i1, i2 = idx[k - 1], idx[k], idx[(k + 1) % len(idx)]
            a, b, c = points[i0], points[i1], points[i2]
            cross = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
            if cross <= 1e-9:
                continue
            inside = False
            for j in idx:
                if j in (i0, i1, i2):
                    continue
                py, pz = points[j]
                d1 = (b[0] - a[0]) * (pz - a[1]) - (b[1] - a[1]) * (py - a[0])
                d2 = (c[0] - b[0]) * (pz - b[1]) - (c[1] - b[1]) * (py - b[0])
                d3 = (a[0] - c[0]) * (pz - c[1]) - (a[1] - c[1]) * (py - c[0])
                if d1 > 1e-9 and d2 > 1e-9 and d3 > 1e-9:
                    inside = True
                    break
            if inside:
                continue
            tris.append((i0, i1, i2))
            idx.pop(k)
            cut = True
            break
        if not cut:
            break
    if len(idx) == 3:
        tris.append(tuple(idx))
    assert len(tris) == n - 2, f"triangulacion incompleta: {len(tris)} de {n - 2}"
    return tris


def prism(name, points, x0, x1, mat):
    """Prisma con el perfil lateral `points` (y, z), de x0 a x1, con las tapas trianguladas a mano."""
    n = len(points)
    verts = [(x0, y, z) for y, z in points] + [(x1, y, z) for y, z in points]
    faces = []
    for a, b, c in triangulate(points):
        faces.append((a, b, c))
        faces.append((n + c, n + b, n + a))
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    return close_normals(obj)


def ring_object(name, verts, mat):
    """Marco rectangular con hueco: 4 vertices exteriores y 4 interiores en cada extremo."""
    faces = []
    for k in range(4):
        a, b = k, (k + 1) % 4
        faces.append((8 + a, 12 + a, 12 + b, 8 + b))  # anillo delantero
        faces.append((a, 4 + a, 4 + b, b))  # anillo trasero
        faces.append((a, 8 + a, 8 + b, b))  # pared exterior
        faces.append((4 + a, 4 + b, 12 + b, 12 + a))  # pared interior
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    return close_normals(obj)


def side_ring(name, x_in, x_out, y0, y1, z0, z1, border, mat):
    """Marco en el plano Y-Z, extruido en X. El cristal queda hundido dentro del hueco."""
    yo0, yo1, zo0, zo1 = y0 - border, y1 + border, z0 - border, z1 + border
    outer = [(yo0, zo0), (yo1, zo0), (yo1, zo1), (yo0, zo1)]
    inner = [(y0, z0), (y1, z0), (y1, z1), (y0, z1)]
    verts = [(x_in, y, z) for y, z in outer + inner] + [(x_out, y, z) for y, z in outer + inner]
    return ring_object(name, verts, mat)


def end_ring(name, y_in, y_out, x0, x1, z0, z1, border, mat):
    """Marco en el plano X-Z, extruido en Y (parabrisas y ventana trasera)."""
    xo0, xo1, zo0, zo1 = x0 - border, x1 + border, z0 - border, z1 + border
    outer = [(xo0, zo0), (xo1, zo0), (xo1, zo1), (xo0, zo1)]
    inner = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
    verts = [(x, y_in, z) for x, z in outer + inner] + [(x, y_out, z) for x, z in outer + inner]
    return ring_object(name, verts, mat)


def arch_angles(radius, z_bottom, center_z):
    """Angulos del arco que sube por encima del eje y vuelve al borde inferior de la chapa."""
    dy = math.sqrt(radius**2 - (z_bottom - center_z) ** 2)
    a0 = math.atan2(z_bottom - center_z, -dy)
    a1 = math.atan2(z_bottom - center_z, dy)
    if a0 < a1:
        a0 += 2 * math.pi
    assert a0 > a1, "el arco no cruza el borde inferior"
    return dy, a0, a1


def arch_outline(nose, tail, z_bottom, z_top, axles, radius, center_z, segments):
    """Perfil del faldon lateral: borde inferior con un arco abierto sobre cada eje."""
    dy, a0, a1 = arch_angles(radius, z_bottom, center_z)
    pts = [(nose, z_bottom)]
    for ay in sorted(axles):
        pts.append((ay - dy, z_bottom))
        for i in range(1, segments):
            angle = a0 + (a1 - a0) * i / segments
            pts.append((ay + radius * math.cos(angle), center_z + radius * math.sin(angle)))
        pts.append((ay + dy, z_bottom))
    pts.append((tail, z_bottom))
    pts.append((tail, z_top))
    pts.append((nose, z_top))
    return pts


def arch_lining(name, axle_y, x0, x1, mat, segments=11):
    """Forro del paso de rueda: tapa el espesor de chapa del arco y deja el neumatico a la vista."""
    r_in, r_out = ARCH_RADIUS - 0.10, ARCH_RADIUS + 0.04
    _, a0, a1 = arch_angles(ARCH_RADIUS, PANEL_BOTTOM, WHEEL_Z)
    angles = [a0 + (a1 - a0) * i / segments for i in range(segments + 1)]
    outer = [(axle_y + r_out * math.cos(t), WHEEL_Z + r_out * math.sin(t)) for t in angles]
    inner = [(axle_y + r_in * math.cos(t), WHEEL_Z + r_in * math.sin(t)) for t in reversed(angles)]
    return prism(name, outer + inner, x0, x1, mat)


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


def add_side_window(parts, mats, side, y0, y1):
    z0, z1 = WINDOW_Z
    yc, zc = (y0 + y1) / 2, (z0 + z1) / 2
    parts.append(
        side_ring("win_frame", side * FRAME_IN, side * FRAME_OUT, y0, y1, z0, z1, 0.08, mats["dark"])
    )
    parts.append(box("window", (0.06, y1 - y0 - 0.02, z1 - z0 - 0.02), (side * GLASS_X, yc, zc), mats["glass"]))
    parts.append(box("win_mullion", (0.08, 0.12, z1 - z0), (side * BEAD_X, yc, zc), mats["dark"]))


def add_side_door(parts, mats, side, y0, y1):
    z0, z1 = DOOR_Z
    yc, zc = (y0 + y1) / 2, (z0 + z1) / 2
    parts.append(
        side_ring("door_frame", side * FRAME_IN, side * FRAME_OUT, y0, y1, z0, z1, 0.09, mats["dark"])
    )
    parts.append(box("door_glass", (0.06, y1 - y0 - 0.02, z1 - z0 - 0.02), (side * GLASS_X, yc, zc), mats["glass"]))
    # Puerta plegable: dos hojas con la goma central y una manilla de acero.
    parts.append(box("door_split", (0.08, 0.12, z1 - z0), (side * BEAD_X, yc, zc), mats["dark"]))
    parts.append(box("door_handle", (0.09, 0.12, 0.30), (side * 2.97, yc + 0.18, 3.92), mats["steel"]))


def build_body(mats):
    parts = []
    # Casco: frontal plano hasta el techo, trasera con chaflan. Una sola planta, nada de dos pisos.
    shell_points = [
        (NOSE, BODY_BOTTOM),
        (NOSE, ROOF_Z),
        (TAIL - 0.30, ROOF_Z),
        (TAIL, 5.95),
        (TAIL, BODY_BOTTOM),
    ]
    parts.append(bevel(prism("shell", shell_points, -BODY_HALF, BODY_HALF, mats["bus"]), 0.20, 2))

    # Faldon lateral con arcos reales sobre las ruedas y sombra oscura del paso de rueda detras.
    axles = sorted({axle[1] for axle in WHEEL_AXLES.values()})
    outline = arch_outline(NOSE, TAIL, PANEL_BOTTOM, BODY_BOTTOM, axles, ARCH_RADIUS, WHEEL_Z, 11)
    for side in (-1, 1):
        parts.append(prism("sill", outline, side * PANEL_INNER, side * BODY_HALF, mats["bus"]))
        for axle_y in axles:
            parts.append(
                arch_lining("arch_lining", axle_y, side * PANEL_INNER, side * (BODY_HALF + 0.025), mats["bus"])
            )
    parts.append(box("sill_shadow", (3.80, 15.0, 2.20), (0, 0, 1.90), mats["dark"]))
    parts.append(box("apron_f", (5.94, 0.34, 2.15), (0, NOSE + 0.13, 1.925), mats["bus"]))
    parts.append(box("apron_r", (5.94, 0.34, 2.15), (0, TAIL - 0.13, 1.925), mats["bus"]))
    # Filete oscuro de bajos: asienta la ficha en el suelo y rompe la pared azul.
    for side in (-1, 1):
        for y0, y1 in [(-7.70, -5.72), (-3.08, 3.89), (6.51, 7.70)]:
            parts.append(box("skirt", (0.06, y1 - y0, 0.17), (side * 2.96, (y0 + y1) / 2, 0.945), mats["dark"]))
        # Juntas de chapa en el faldon, entre ruedas y puertas.
        for y in (-3.35, 2.60, 6.58):
            parts.append(box("panel_seam", (0.05, 0.05, 1.60), (side * 2.955, y, 1.80), mats["dark"]))

    # Banda crema de cintura: se corta en las puertas y remata la librea de dos tonos.
    for y0, y1 in BELT_SEGMENTS:
        for side in (-1, 1):
            parts.append(box("belt", (0.08, y1 - y0, BELT_HEIGHT), (side * BELT_X, (y0 + y1) / 2, BELT_Z), mats["cream"]))
    parts.append(box("belt_nose", (5.98, 0.14, BELT_HEIGHT), (0, NOSE - 0.01, BELT_Z), mats["cream"]))
    parts.append(box("belt_tail", (5.98, 0.14, BELT_HEIGHT), (0, TAIL + 0.01, BELT_Z), mats["cream"]))

    # Techo crema con respiraderos y una escotilla. La placa va aparte.
    parts.append(bevel(box("roof_cap", (5.98, 15.20, 0.32), (0, 0, 6.36), mats["cream"]), 0.05, 1))
    for y in (-5.30, 5.30):
        parts.append(box("roof_vent", (1.10, 0.90, 0.08), (0, y, 6.56), mats["dark"]))
    parts.append(bevel(box("roof_hatch", (1.70, 1.20, 0.18), (0, -4.05, 6.61), mats["cream"]), 0.04, 1))

    # Ventanillas y puertas plegables en los dos lados.
    for side in (-1, 1):
        for y0, y1 in SIDE_WINDOWS:
            add_side_window(parts, mats, side, y0, y1)
        for y0, y1 in SIDE_DOORS:
            add_side_door(parts, mats, side, y0, y1)

    # Frontal: parabrisas partido, cartel de destino sin texto, faros y parachoques.
    x0, x1, z0, z1 = WINDSHIELD
    parts.append(end_ring("windshield_frame", -7.76, -7.58, x0, x1, z0, z1, 0.09, mats["dark"]))
    parts.append(box("windshield", (x1 - x0 - 0.02, 0.06, z1 - z0 - 0.02), (0, -7.68, (z0 + z1) / 2), mats["glass"]))
    parts.append(box("windshield_split", (0.18, 0.08, z1 - z0), (0, -7.72, (z0 + z1) / 2), mats["dark"]))
    for x in (-1.42, 1.42):
        parts.append(box("wiper", (0.07, 0.04, 0.90), (x, -7.73, 3.80), mats["dark"], (0, math.radians(14), 0)))

    sx0, sx1, sz0, sz1 = SIGN
    parts.append(box("sign_bezel", (sx1 - sx0 + 0.16, 0.24, sz1 - sz0 + 0.16), (0, -7.72, (sz0 + sz1) / 2), mats["dark"]))
    parts.append(box("sign_face", (sx1 - sx0, 0.05, sz1 - sz0), (0, -7.845, (sz0 + sz1) / 2), mats["cream"]))
    # Junta horizontal del panel de acceso, entre el parabrisas y los faros.
    parts.append(box("front_seam", (4.40, 0.06, 0.06), (0, -7.72, 2.32), mats["dark"]))

    for side in (-1, 1):
        parts.append(box("headlight_housing", (1.00, 0.10, 0.50), (side * HEADLIGHT_X, -7.77, 1.95), mats["dark"]))
        parts.append(box("headlight", (0.78, 0.05, 0.34), (side * HEADLIGHT_X, -7.805, 1.95), mats["cream"]))
    parts.append(bevel(box("bumper_f", (5.94, 0.26, 0.60), (0, -7.80, 1.12), mats["steel"]), 0.07))

    # Trasera: ventana, rejilla del motor, pilotos y parachoques. Ninguna cara lisa.
    rx0, rx1, rz0, rz1 = REAR_WINDOW
    parts.append(end_ring("rear_frame", 7.58, 7.76, rx0, rx1, rz0, rz1, 0.09, mats["dark"]))
    parts.append(box("rear_glass", (rx1 - rx0 - 0.02, 0.06, rz1 - rz0 - 0.02), (0, 7.68, (rz0 + rz1) / 2), mats["glass"]))
    parts.append(box("rear_split", (0.18, 0.08, rz1 - rz0), (0, 7.72, (rz0 + rz1) / 2), mats["dark"]))
    parts.append(box("grille_back", (4.15, 0.06, GRILLE_Z[1] - GRILLE_Z[0]), (0, 7.75, sum(GRILLE_Z) / 2), mats["dark"]))
    for i in range(3):
        parts.append(box("grille_slat", (4.15, 0.06, 0.11), (0, 7.80, GRILLE_Z[0] + 0.14 + i * 0.26), mats["dark"]))
    for side in (-1, 1):
        parts.append(box("taillight_housing", (0.62, 0.08, 0.56), (side * TAILLIGHT_X, 7.77, 1.95), mats["dark"]))
        parts.append(box("taillight", (0.46, 0.05, 0.40), (side * TAILLIGHT_X, 7.80, 1.95), mats["red"]))
    parts.append(bevel(box("bumper_r", (5.94, 0.26, 0.60), (0, 7.80, 1.12), mats["steel"]), 0.07))

    # Espejos de brazo largo en las esquinas delanteras, por delante del parabrisas: la silueta de
    # autobus se reconoce por ellos aunque la ficha se vea en negro.
    for side in (-1, 1):
        parts.append(box("mirror_arm", (0.34, 0.12, 0.08), (side * 3.02, -7.74, 5.64), mats["dark"]))
        parts.append(box("mirror_head", (0.10, 0.20, 0.66), (side * MIRROR_X, -7.86, 5.34), mats["dark"]))
    return parts


def build_plate(mats):
    return bevel(box("bus_plate", PLATE_SIZE, PLATE_CENTER, mats["plate"]), 0.03)


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
        "bus": flat("bus", "3E7FA6", 0.35),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "glass": flat("glass", "7FB2D9", 0.12, 0.0),
        "steel": flat("steel", "A8AEB4", 0.25, 0.8),
        "red": flat("red", "C4382B", 0.7),
        "plate": flat("plate", "EDEAE3", 0.5),
        "ground": flat("ground", "8E9196", 0.9),
    }

    body = group_by_material(build_body(mats), "bus_body")
    plate = build_plate(mats)
    wheels = {key: wheel_part(f"bus_wheel_{key}", WHEEL_RADIUS, WHEEL_DEPTH, 16, mats["dark"]) for key in WHEEL_AXLES}
    hubs = {key: wheel_part(f"bus_hub_{key}", HUB_RADIUS, HUB_DEPTH, 8, mats["steel"]) for key in WHEEL_AXLES}

    # Comprobaciones antes de exportar.
    entries = [(obj, (0.0, 0.0, 0.0)) for obj in body.values()] + [(plate, (0.0, 0.0, 0.0))]
    entries += [(wheels[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    entries += [(hubs[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    lo, hi = bounds(entries)
    plate_lo, plate_hi = bounds([(plate, (0.0, 0.0, 0.0))])
    seat = (round((plate_lo[0] + plate_hi[0]) / 2, 4), round((plate_lo[1] + plate_hi[1]) / 2, 4), round(plate_hi[2], 4))
    width, length, height = hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]

    assert width <= LIMITS["ancho_x"], f"ancho {width:.2f} por encima de {LIMITS['ancho_x']}"
    assert length <= LIMITS["largo_y"], f"largo {length:.2f} por encima de {LIMITS['largo_y']}"
    assert height <= LIMITS["alto_z"], f"alto {height:.2f} por encima de {LIMITS['alto_z']}"
    assert abs(lo[2]) < 1e-6, f"min_z {lo[2]:.3f}, las ruedas no tocan el suelo"
    assert plate_hi[0] - plate_lo[0] >= 4.5 - 1e-6 and plate_hi[1] - plate_lo[1] >= 5.0 - 1e-6, "placa menor de 4,5 x 5"
    assert plate_lo[2] >= ROOF_Z - 1e-6, "la placa no apoya en el techo"
    assert abs(plate_lo[0] + plate_hi[0]) < 1e-6 and abs(plate_lo[1] + plate_hi[1]) < 1e-6, "la placa no esta centrada"
    assert abs(seat[2] - plate_hi[2]) < 1e-6, "el seat no coincide con la cara superior de la placa"
    # Nada por encima de la placa, ni dentro de su huella: el avatar tiene que apoyarse limpio.
    for obj in body.values():
        for vertex in obj.data.vertices:
            if abs(vertex.co[0]) < plate_hi[0] + 1e-6 and abs(vertex.co[1]) < plate_hi[1] + 1e-6:
                assert vertex.co[2] <= plate_lo[2] + 1e-6, f"{obj.name} invade la placa del asiento"
    for obj in [*body.values(), plate, *wheels.values(), *hubs.values()]:
        assert len(obj.data.materials) == 1, f"{obj.name} tiene varios materiales"
    for key in WHEEL_AXLES:
        assert count(wheels[key]) + count(hubs[key]) <= PART_BUDGET, f"rueda {key} por encima de {PART_BUDGET}"

    # LOD1: una sola malla con un solo material (carroceria), reducida al 50 %.
    lod_parts = [lod_copy(body["bus"], (0.0, 0.0, 0.0), mats["bus"])]
    lod_parts.append(lod_copy(body["cream"], (0.0, 0.0, 0.0), mats["bus"]))
    lod_parts += [lod_copy(wheels[key], WHEEL_AXLES[key], mats["bus"]) for key in WHEEL_AXLES]
    lod = join(lod_parts, "bus_LOD1")
    decimate = lod.modifiers.new("Decimate", "DECIMATE")
    decimate.ratio = LOD_RATIO
    apply_modifiers(lod)
    select_only(lod)
    bpy.ops.object.material_slot_remove_unused()
    assert len(lod.data.materials) == 1, "el LOD1 tiene mas de un material"

    # Las ruedas y los tapacubos se exportan con su origen en el eje y ya colocados en su sitio del
    # coche. Asi Roblox los deja en el eje al cargarlos (el FBX lleva la traslacion del objeto) y
    # siguen girando alrededor de su propio centro. Sin esto, las cuatro caen en (0,0,0).
    for key in WHEEL_AXLES:
        wheels[key].location = WHEEL_AXLES[key]
        hubs[key].location = WHEEL_AXLES[key]

    files = {}
    for obj in body.values():
        export(obj, f"{obj.name}.fbx")
        files[obj.name] = count(obj)
    export(plate, "bus_plate.fbx")
    files["bus_plate"] = count(plate)
    for key in WHEEL_AXLES:
        export(wheels[key], f"bus_wheel_{key}.fbx")
        export(hubs[key], f"bus_hub_{key}.fbx")
        files[f"bus_wheel_{key}"] = count(wheels[key])
        files[f"bus_hub_{key}"] = count(hubs[key])
    export(lod, "bus_LOD1.fbx")
    total = sum(files.values())
    lod_triangles = count(lod)
    assert total <= TOTAL_BUDGET, f"{total} triangulos, por encima de {TOTAL_BUDGET}"
    assert lod_triangles <= total / 2, f"LOD1 con {lod_triangles}, mas de la mitad de {total}"

    ventanas = 2 * len(SIDE_WINDOWS) + 2  # laterales + parabrisas + trasera
    stats = {
        "modelo": "autobus",
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
            "plantas": 1,
            "ventanillas": ventanas,
            "puertas_plegables": 2 * len(SIDE_DOORS),
            "maletero": {
                "inicio_y": 3.60,
                "largo": round(TAIL - 3.60, 3),
                "porcentaje_del_largo": round(100 * (TAIL - 3.60) / length, 1),
                "z_superior": 3.06,
                "nota": "en el autobus es el compartimento del motor, no un maletero de equipaje",
            },
            "placa": {
                "tamano_x": round(plate_hi[0] - plate_lo[0], 3),
                "tamano_y": round(plate_hi[1] - plate_lo[1], 3),
                "z_inferior": round(plate_lo[2], 4),
                "z_superior": round(plate_hi[2], 4),
                "centro_xy": [PLATE_CENTER[0], PLATE_CENTER[1]],
            },
            "limites": LIMITS,
        },
        "seat": list(seat),
        "ruedas": {
            key: {
                "archivo": f"bus_wheel_{key}.fbx",
                "tapacubos": f"bus_hub_{key}.fbx",
                "eje": list(WHEEL_AXLES[key]),
                "giro": "X",
                "radio": WHEEL_RADIUS,
                "ancho": WHEEL_DEPTH,
            }
            for key in WHEEL_AXLES
        },
        "materiales": {
            **{obj.name: obj.data.materials[0].name for obj in body.values()},
            "bus_plate": "plate",
            **{f"bus_wheel_{key}": "dark" for key in WHEEL_AXLES},
            **{f"bus_hub_{key}": "steel" for key in WHEEL_AXLES},
            "bus_LOD1": "bus",
        },
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("AUTOBUS_STATS", json.dumps(stats))

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
        obj.location.y += 10.5
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

    render(scene, camera("frontal", (-17.0, -28.0, 11.5), (0.0, 0.0, 3.1), lens=50), "autobus-3-4-frontal.png")
    render(scene, camera("trasera", (17.0, 28.0, 11.5), (0.0, 0.0, 3.1), lens=50), "autobus-3-4-trasera.png")
    for obj in avatar:
        obj.hide_render = False
    render(scene, camera("perfil", (60.0, 4.0, 3.4), (0.0, 4.0, 3.4), ortho_scale=26.0), "autobus-perfil-avatar.png")
    print("AUTOBUS_RENDERS_OK")


if __name__ == "__main__":
    main()

"""Ficha food-truck: furgon alto de comida de Flip the Table.

Furgon de reparto reconvertido en puesto callejero: caja alta y cuadrada, cabina corta con parabrisas
inclinado y morro de dos volumenes, ventanilla de servicio grande en el lateral izquierdo con marco
oscuro, montantes y toldo a rayas, mostrador de acero con bandeja, guardabarros con arco real,
trasera con persiana enrollable y travesanos, y chimenea pequena en el techo delante de la placa.
Sin marcas, logotipos, texto legible ni matriculas.

Salidas, en art/blender/tokens/food-truck/:
  food_body_<material>.fbx     carroceria, una malla por material
  food_plate.fbx               placa del techo, separada: se tine con el color del jugador
  food_wheel_{fl,fr,rl,rr}.fbx neumatico, con el origen en su eje de giro (eje X)
  food_hub_{fl,fr,rl,rr}.fbx   tapacubos de acero, mismo origen y eje que su rueda
  food_LOD1.fbx                una sola malla y un solo material (color de carroceria)
  stats.json                   triangulos por pieza, total y LOD1, medidas, ejes y seat
Y en art/render/tokens/food-truck/: 3/4 frontal, 3/4 trasero y perfil con avatar de 6 studs al lado.

Convenciones (como art/blender/tokens/taxi.py): 1 unidad de Blender = 1 stud, el morro mira a -Y,
Z hacia arriba, origen en el centro de la base a ras de suelo, exportacion FBX con Z Forward / Y Up.

Uso (segundo plano, sin abrir Blender):
  "D:\\blender\\blender.exe" --background --factory-startup --python art/blender/tokens/food-truck.py
"""

import glob
import json
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "food-truck")
RENDER = os.path.join(REPO, "art", "render", "tokens", "food-truck")

LOD_RATIO = 0.5
TOTAL_BUDGET = 3000
PART_BUDGET = 120  # rueda con su tapacubos
MAX_WIDTH, MAX_LENGTH, MAX_HEIGHT = 6.5, 13.0, 7.0

# Ruedas: origen en el eje de giro, en studs, relativo a la base. l = -X, r = +X (de frente).
WHEEL_AXLES = {
    "fl": (-2.42, -4.0, 1.0),
    "fr": (2.42, -4.0, 1.0),
    "rl": (-2.42, 4.0, 1.0),
    "rr": (2.42, 4.0, 1.0),
}
WHEEL_RADIUS = 1.0
WHEEL_DEPTH = 0.8
HUB_RADIUS = 0.5
HUB_DEPTH = 0.9

# Carroceria. La caja es mas ancha que la cabina: escalon visible en el lateral.
BODY_BOTTOM = 0.95
BOX_HALF = 2.75
CAB_HALF = 2.60
BOX_ROOF = 5.85
CAB_ROOF = 4.45
NOSE_Y = -6.20
TAIL_Y = 6.20

# Cabina: morro de dos volumenes, parabrisas inclinado entre el capo y el techo.
CAB_POINTS = [
    (NOSE_Y, BODY_BOTTOM),
    (NOSE_Y, 2.18),
    (-5.98, 2.52),
    (-5.48, 2.68),
    (-4.25, 4.25),
    (-4.08, CAB_ROOF),
    (-2.50, CAB_ROOF),
    (-2.50, BODY_BOTTOM),
]
BOX_POINTS = [(-2.70, BODY_BOTTOM), (-2.70, BOX_ROOF), (TAIL_Y, BOX_ROOF), (TAIL_Y, BODY_BOTTOM)]

# Parabrisas: marco oscuro, cristal y montante central.
WINDSHIELD_P0 = (-5.48, 2.68)
WINDSHIELD_P1 = (-4.25, 4.25)
WIND_FRAME_HALF = 2.38
WIND_GLASS_HALF = 2.10

# Ventanilla de servicio en el lateral -X (en Roblox aparece a +X, el eje X sale reflejado).
SERVICE_Y = (-1.75, 2.35)
SERVICE_Z = (2.90, 4.65)
SERVICE_BORDER = 0.16
SERVICE_DEPTH = 0.08

# Toldo: nueve fajas alternas, de la chapa al borde, por encima de la ventanilla.
AWNING_Y = (-2.10, 2.70)
AWNING_STRIPES = 9
AWNING_INNER = (-2.71, 4.94)
AWNING_OUTER = (-3.40, 4.58)
AWNING_THICKNESS = 0.08

# Mostrador de acero bajo la ventanilla, con borde y dos soportes.
COUNTER_Z = 2.59
COUNTER_OUT = -3.36

# Techo: placa del avatar en la mitad trasera; chimenea delante, fuera de la placa.
PLATE_SIZE = (4.6, 5.1, 0.10)
PLATE_CENTER = (0.0, 2.85, BOX_ROOF + 0.04)
CHIMNEY_XY = (-1.60, -2.00)
CHIMNEY_TOP = 6.66


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
    # La posicion se hornea en la malla: el origen de cada pieza queda en el origen de la ficha.
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


def slab_xz(name, p0, p1, y0, y1, thickness, mat):
    """Losa inclinada en el plano XZ entre p0 y p1, de y0 a y1 y con `thickness` normal a la pendiente."""
    dx, dz = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dx, dz)
    ux, uz = dx / length, dz / length
    nx, nz = -uz, ux
    h = thickness / 2
    corners = [(p0, -h), (p1, -h), (p1, h), (p0, h)]
    verts = []
    for y in (y0, y1):
        for (px, pz), offset in corners:
            verts.append((px + nx * offset, y, pz + nz * offset))
    faces = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    return close_normals(obj)


def frame_side(name, sign, face, y0, y1, z0, z1, border, depth, mat):
    """Marco de cuatro travesanos en un plano lateral x = sign*face; el relieve entra hacia dentro."""
    cx = sign * (face - depth / 2)
    yc, zc = (y0 + y1) / 2, (z0 + z1) / 2
    inner_z = z1 - z0 - 2 * border
    return [
        box(f"{name}_bottom", (depth, y1 - y0, border), (cx, yc, z0 + border / 2), mat),
        box(f"{name}_top", (depth, y1 - y0, border), (cx, yc, z1 - border / 2), mat),
        box(f"{name}_front", (depth, border, inner_z), (cx, y0 + border / 2, zc), mat),
        box(f"{name}_back", (depth, border, inner_z), (cx, y1 - border / 2, zc), mat),
    ]


def frame_rear(name, face, x0, x1, z0, z1, border, depth, mat):
    """Marco de cuatro travesanos en el plano trasero y = face; entra 3 cm en la chapa para no coincidir."""
    cy = face - 0.03 + depth / 2
    xc, zc = (x0 + x1) / 2, (z0 + z1) / 2
    inner_z = z1 - z0 - 2 * border
    return [
        box(f"{name}_bottom", (x1 - x0, depth, border), (xc, cy, z0 + border / 2), mat),
        box(f"{name}_top", (x1 - x0, depth, border), (xc, cy, z1 - border / 2), mat),
        box(f"{name}_left", (border, depth, inner_z), (x0 + border / 2, cy, zc), mat),
        box(f"{name}_right", (border, depth, inner_z), (x1 - border / 2, cy, zc), mat),
    ]


def glass_pane(name, sign, face, depth, y0, y1, z0, z1, mat):
    """Cristal retranqueado detras del marco: nunca una lamina a ras de la chapa."""
    return box(
        name,
        (0.04, y1 - y0, z1 - z0),
        (sign * (face - depth + 0.035), (y0 + y1) / 2, (z0 + z1) / 2),
        mat,
    )


def arch_arc(name, axle_y, x_center, inner, outer, half, mat, segments=8):
    """Arco oscuro sobre el neumatico: media corona entre los radios inner y outer."""
    angles = [math.pi * i / segments for i in range(segments + 1)]
    outer_pts = [(axle_y + outer * math.cos(t), 1.0 + outer * math.sin(t)) for t in angles]
    inner_pts = [(axle_y + inner * math.cos(t), 1.0 + inner * math.sin(t)) for t in reversed(angles)]
    obj = profile(name, outer_pts + inner_pts, half, mat)
    obj.location = (x_center, 0.0, 0.0)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    return obj


def fender_flare(name, axle_y, body_half, out, mat):
    """Guardabarros integrado: abultamiento de la chapa que nace y muere dentro del lateral."""
    stations = [(axle_y - 1.50, 0.0), (axle_y - 0.80, 1.0), (axle_y + 0.80, 1.0), (axle_y + 1.50, 0.0)]
    x0 = body_half - 0.10
    objs = []
    for side in (-1, 1):
        verts, faces = [], []
        for y, a in stations:
            section = [
                (x0, 2.16),
                (body_half + 0.02 + out * a, 2.16),
                (body_half - 0.02 + out * 0.72 * a, 2.54 + 0.08 * a),
                (x0, 2.62),
            ]
            for x, z in section:
                verts.append((side * x, y, z))
        n = 4
        for k in range(len(stations) - 1):
            for i in range(n):
                faces.append((k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i))
        faces.append(tuple(range(n)))
        faces.append(tuple(range((len(stations) - 1) * n, len(stations) * n)))
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(verts, [], faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        mesh.materials.append(mat)
        objs.append(close_normals(obj))
    return objs


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


def build_body(mats):
    """Devuelve (piezas, piezas del toldo). El toldo se mide aparte para comprobar que no invade la placa."""
    parts = []
    awning = []
    parts.append(bevel(profile("box_body", BOX_POINTS, BOX_HALF, mats["food"]), 0.18))
    parts.append(bevel(profile("cab_body", CAB_POINTS, CAB_HALF, mats["food"]), 0.16))
    # Cornisa de caliza: banda que remata el borde del techo; la chapa sigue a la vista por arriba.
    parts.append(box("cornice", (2 * BOX_HALF + 0.12, TAIL_Y + 0.06 - (-2.84), 0.28),
                     (0.0, (TAIL_Y + 0.06 - 2.84) / 2, BOX_ROOF - 0.16), mats["cream"]))
    # Guardabarros con arco real: abultamiento de chapa y arco oscuro alrededor del neumatico.
    for axle_y, body_half, out in ((-4.0, CAB_HALF, 0.24), (4.0, BOX_HALF, 0.12)):
        parts += fender_flare("fender", axle_y, body_half, out, mats["food"])
        for side in (-1, 1):
            # El arco queda 4 cm por dentro de la cara del neumatico: si coincide, no se ve.
            parts.append(
                arch_arc("arch_ring", axle_y, side * (body_half - 0.01), 1.00, 1.26, 0.04, mats["dark"])
            )
    # Chasis oscuro: cierra el hueco bajo la chapa y evita que la ficha parezca flotar.
    parts.append(box("chassis", (4.3, 11.6, 0.37), (0.0, 0.0, 0.785), mats["dark"]))
    # Parabrisas: marco oscuro con relieve, cristal menor y montante central.
    parts.append(
        slope_slab_profile("windshield_frame", WINDSHIELD_P0, WINDSHIELD_P1, 0.0, 0.12, -0.06,
                            WIND_FRAME_HALF, mats["dark"])
    )
    parts.append(
        slope_slab_profile("windshield_glass", WINDSHIELD_P0, WINDSHIELD_P1, 0.12, 0.16, -0.24,
                            WIND_GLASS_HALF, mats["glass"])
    )
    parts.append(
        slope_slab_profile("windshield_post", WINDSHIELD_P0, WINDSHIELD_P1, 0.16, 0.21, -0.24,
                            0.10, mats["dark"])
    )
    # Limpiaparabrisas y espejos: dos piezas oscuras que recortan la silueta del morro.
    for x in (-0.55, 0.55):
        parts.append(wiper("wiper", x, WINDSHIELD_P0, WINDSHIELD_P1, mats["dark"]))
    for side in (-1, 1):
        parts.append(box("mirror_arm", (0.24, 0.08, 0.08), (side * 2.70, -4.50, 3.62), mats["steel"]))
        parts.append(box("mirror", (0.10, 0.26, 0.46), (side * 2.84, -4.52, 3.62), mats["dark"]))
    # Morro: parrilla de travesanos, faros y parachoques.
    for z in (1.26, 1.46, 1.66):
        parts.append(box("grille", (2.4, 0.10, 0.12), (0.0, NOSE_Y - 0.04, z), mats["dark"]))
    for side in (-1, 1):
        parts.append(bevel(box("headlight", (0.64, 0.12, 0.42), (side * 1.86, NOSE_Y - 0.05, 1.72),
                               mats["cream"]), 0.05))
    parts.append(bevel(box("bumper_f", (5.3, 0.24, 0.50), (0.0, NOSE_Y - 0.10, 0.80), mats["steel"]), 0.08))
    # Cabina: ventanillas con marco, montante, junta de puerta y manilla en los dos lados.
    for side in (-1, 1):
        parts += frame_side("cab_win", side, CAB_HALF + 0.05, -4.15, -2.85, 2.95, 4.02,
                            0.13, 0.07, mats["dark"])
        parts.append(glass_pane("cab_glass", side, CAB_HALF + 0.05, 0.07, -4.05, -2.95, 3.03, 3.94,
                                mats["glass"]))
        parts.append(box("cab_mullion", (0.07, 0.10, 1.07), (side * 2.63, -3.50, 3.485), mats["dark"]))
        parts.append(box("door_seam", (0.06, 0.07, 3.0), (side * 2.62, -2.92, 2.55), mats["dark"]))
        parts.append(box("door_handle", (0.10, 0.34, 0.10), (side * 2.66, -3.35, 2.72), mats["steel"]))
    # Ventanilla de servicio (-X): marco, dos montantes, cristal retranqueado y mostrador.
    face = BOX_HALF + 0.06
    parts += frame_side("service_frame", -1, face, SERVICE_Y[0], SERVICE_Y[1], SERVICE_Z[0], SERVICE_Z[1],
                        SERVICE_BORDER, SERVICE_DEPTH, mats["dark"])
    parts.append(glass_pane("service_glass", -1, face, SERVICE_DEPTH,
                            SERVICE_Y[0] + 0.06, SERVICE_Y[1] - 0.06,
                            SERVICE_Z[0] + 0.06, SERVICE_Z[1] - 0.06, mats["glass"]))
    for y in (-0.62, 1.02):
        parts.append(box("service_mullion", (0.09, 0.10, SERVICE_Z[1] - SERVICE_Z[0]),
                         (-(face - 0.045), y, (SERVICE_Z[0] + SERVICE_Z[1]) / 2), mats["dark"]))
    # Mostrador de acero pegado al alfeizar de la ventanilla, con borde y dos soportes.
    parts.append(box("counter", (0.64, 4.30, 0.13), (-3.04, 0.30, COUNTER_Z + 0.065), mats["steel"]))
    parts.append(box("counter_lip", (0.06, 4.30, 0.22), (COUNTER_OUT + 0.03, 0.30, COUNTER_Z + 0.20),
                     mats["steel"]))
    for y in (-1.50, 2.10):
        parts.append(box("counter_bracket", (0.52, 0.09, 0.20), (-2.96, y, COUNTER_Z - 0.14),
                         mats["steel"]))
    # Toldo a rayas: nueve fajas de la chapa al borde, con dos puntales oscuros.
    y0, y1 = AWNING_Y
    step = (y1 - y0) / AWNING_STRIPES
    for i in range(AWNING_STRIPES):
        material = mats["cream"] if i % 2 == 0 else mats["red"]
        awning.append(
            slab_xz("awning_stripe", AWNING_INNER, AWNING_OUTER, y0 + i * step, y0 + (i + 1) * step,
                    AWNING_THICKNESS, material)
        )
    for y in (y0 + 0.10, y1 - 0.10):
        parts.append(slab_xz("awning_strut", (-2.70, 4.32), (AWNING_OUTER[0] + 0.10, 4.54),
                             y - 0.04, y + 0.04, 0.05, mats["dark"]))
    # Costado +X: puerta de servicio con ventanilla, cerco oscuro y manilla, y rejilla de equipo.
    parts.append(box("door_backing", (0.03, 2.10, 2.30), (BOX_HALF + 0.005, 1.90, 2.35), mats["dark"]))
    parts.append(box("door_panel", (0.06, 2.00, 2.20), (BOX_HALF + 0.04, 1.90, 2.35), mats["cream"]))
    parts += frame_side("door_win_frame", 1, BOX_HALF + 0.10, 1.15, 2.05, 2.55, 3.35, 0.10, 0.09,
                        mats["dark"])
    parts.append(box("door_win_glass", (0.02, 0.78, 0.68), (BOX_HALF + 0.082, 1.60, 2.95),
                     mats["glass"]))
    parts.append(box("door_panel_handle", (0.10, 0.34, 0.10), (BOX_HALF + 0.10, 2.40, 2.48),
                     mats["steel"]))
    for z in (2.95, 3.18, 3.41):
        parts.append(box("side_vent", (0.06, 1.1, 0.10), (BOX_HALF + 0.025, 5.05, z), mats["dark"]))
    parts.append(box("belt_line", (0.06, 8.6, 0.08), (BOX_HALF + 0.025, 1.80, 2.74), mats["dark"]))
    # Trasera: persiana enrollable con travesanos, pilotos rojos, asa y parachoques.
    parts += frame_rear("shutter_frame", TAIL_Y, -2.32, 2.32, 1.55, 4.90, 0.16, 0.14, mats["dark"])
    parts.append(box("shutter_panel", (4.36, 0.06, 3.19), (0.0, TAIL_Y + 0.02, 3.225), mats["cream"]))
    for i in range(6):
        parts.append(box("shutter_slat", (4.20, 0.05, 0.09), (0.0, TAIL_Y + 0.075, 1.85 + i * 0.50),
                         mats["dark"]))
    for side in (-1, 1):
        parts.append(box("taillight", (0.72, 0.10, 0.38), (side * 1.95, TAIL_Y + 0.04, 1.22),
                         mats["red"]))
    parts.append(box("shutter_handle", (0.60, 0.08, 0.12), (0.0, TAIL_Y + 0.09, 1.72), mats["steel"]))
    parts.append(bevel(box("bumper_b", (5.3, 0.24, 0.50), (0.0, TAIL_Y + 0.09, 0.80), mats["steel"]), 0.08))
    # Techo: respiradero sobre la cabina y chimenea pequena delante de la placa.
    parts.append(box("cab_vent", (1.10, 0.90, 0.16), (0.0, -3.35, 4.51), mats["cream"]))
    parts.append(box("chimney_collar", (0.62, 0.62, 0.14), (CHIMNEY_XY[0], CHIMNEY_XY[1], 5.89),
                     mats["dark"]))
    parts.append(box("chimney_stack", (0.44, 0.44, 0.58), (CHIMNEY_XY[0], CHIMNEY_XY[1], 6.24),
                     mats["steel"]))
    parts.append(box("chimney_cap", (0.66, 0.66, 0.14), (CHIMNEY_XY[0], CHIMNEY_XY[1], 6.59),
                     mats["steel"]))
    return parts, awning


def slope_slab_profile(name, p0, p1, t0, t1, ext, half, mat):
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


def wiper(name, x, p0, p1, mat):
    """Limpiaparabrisas sencillo: pieza oscura alineada con el parabrisas, sobre el cristal."""
    dy, dz = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dy, dz)
    uy, uz = dy / length, dz / length
    ny, nz = -uz, uy
    mid = ((p0[0] + p1[0]) / 2 + ny * 0.18, (p0[1] + p1[1]) / 2 + nz * 0.18)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, mid[0], mid[1]))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (0.08, 0.05, 0.9)
    obj.rotation_euler = (math.atan2(-dy, dz), 0, 0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(mat)
    return obj


def build_plate(mats):
    return bevel(box("food_plate", PLATE_SIZE, PLATE_CENTER, mats["plate"]), 0.025)


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
        "food": flat("food", "E07A3C", 0.45),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "23272C", 0.6),
        "glass": flat("glass", "7FB2D9", 0.12, 0.0),
        "steel": flat("steel", "A8AEB4", 0.25, 0.8),
        "red": flat("red", "C4382B", 0.7),
        "plate": flat("plate", "EDEAE3", 0.5),
        "ground": flat("ground", "8E9196", 0.9),
    }

    parts, awning_parts = build_body(mats)
    # El toldo se mide antes de agrupar; despues sus fajas se funden con el resto por material.
    awning_lo, awning_hi = bounds([(obj, (0.0, 0.0, 0.0)) for obj in awning_parts])
    body = group_by_material(parts + awning_parts, "food_body")
    plate = build_plate(mats)
    # 20 vertices: el poligono tiene un vertice justo abajo, asi el neumatico toca el suelo en z = 0.
    wheels = {key: wheel_part(f"food_wheel_{key}", WHEEL_RADIUS, WHEEL_DEPTH, 20, mats["dark"])
              for key in WHEEL_AXLES}
    hubs = {key: wheel_part(f"food_hub_{key}", HUB_RADIUS, HUB_DEPTH, 8, mats["steel"])
            for key in WHEEL_AXLES}

    # Comprobaciones antes de exportar.
    entries = [(obj, (0.0, 0.0, 0.0)) for obj in body.values()] + [(plate, (0.0, 0.0, 0.0))]
    entries += [(wheels[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    entries += [(hubs[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    lo, hi = bounds(entries)
    plate_lo, plate_hi = bounds([(plate, (0.0, 0.0, 0.0))])
    seat = (round((plate_lo[0] + plate_hi[0]) / 2, 4), round((plate_lo[1] + plate_hi[1]) / 2, 4),
            round(plate_hi[2], 4))
    wheel_lo, _ = bounds([(wheels["fl"], WHEEL_AXLES["fl"])])
    width, length, height = hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]
    assert plate_hi[0] - plate_lo[0] >= 4.5 - 1e-6 and plate_hi[1] - plate_lo[1] >= 5.0 - 1e-6, \
        "placa menor de 4,5 x 5"
    assert BOX_ROOF - 0.05 <= plate_lo[2] < BOX_ROOF, "la placa no apoya en el techo"
    assert plate_hi[2] > BOX_ROOF + 0.05, "la placa no sobresale del techo"
    assert abs(seat[2] - plate_hi[2]) < 1e-6, "el seat no coincide con la cara superior de la placa"
    assert awning_hi[2] < plate_lo[2], "el toldo sube por encima de la placa"
    assert awning_lo[0] < -plate_hi[0], "el toldo se mete sobre la placa"
    assert CHIMNEY_TOP <= MAX_HEIGHT, "la chimenea pasa del alto maximo"
    assert abs(wheel_lo[2]) < 1e-6, "las ruedas no tocan el suelo"
    assert abs(lo[2]) < 1e-6, "min_z distinto de 0"
    assert width <= MAX_WIDTH, f"ancho {width:.2f} por encima de {MAX_WIDTH}"
    assert length <= MAX_LENGTH, f"largo {length:.2f} por encima de {MAX_LENGTH}"
    assert height <= MAX_HEIGHT, f"alto {height:.2f} por encima de {MAX_HEIGHT}"
    for key in WHEEL_AXLES:
        assert count(wheels[key]) + count(hubs[key]) <= PART_BUDGET, f"rueda {key} por encima de {PART_BUDGET}"
    for obj in [*body.values(), plate, *wheels.values(), *hubs.values()]:
        assert len(obj.data.materials) == 1, f"{obj.name} tiene varios materiales"

    # LOD1: una sola malla con un solo material (carroceria), reducida al 50 %.
    orange = body["food"]
    lod_parts = [lod_copy(orange, (0.0, 0.0, 0.0), mats["food"])]
    lod_parts += [lod_copy(wheels[key], WHEEL_AXLES[key], mats["food"]) for key in WHEEL_AXLES]
    lod = join(lod_parts, "food_LOD1")
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
    export(plate, "food_plate.fbx")
    files["food_plate"] = count(plate)
    for key in WHEEL_AXLES:
        export(wheels[key], f"food_wheel_{key}.fbx")
        export(hubs[key], f"food_hub_{key}.fbx")
        files[f"food_wheel_{key}"] = count(wheels[key])
        files[f"food_hub_{key}"] = count(hubs[key])
    export(lod, "food_LOD1.fbx")
    total = sum(files.values())
    lod_triangles = count(lod)
    assert total <= TOTAL_BUDGET, f"{total} triangulos, por encima de {TOTAL_BUDGET}"
    assert lod_triangles <= total / 2, f"LOD1 con {lod_triangles}, mas de la mitad de {total}"

    stats = {
        "modelo": "food-truck",
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
            "maximos_permitidos": {"ancho_x": MAX_WIDTH, "largo_y": MAX_LENGTH, "alto_z": MAX_HEIGHT},
            "techo_cabina_z": CAB_ROOF,
            "techo_caja_z": BOX_ROOF,
            "ventanilla_servicio": {
                "lado_blender": "-X (en Roblox aparece a +X: el eje X sale reflejado)",
                "y_inicio": SERVICE_Y[0],
                "y_fin": SERVICE_Y[1],
                "z_inicio": SERVICE_Z[0],
                "z_fin": SERVICE_Z[1],
                "montantes": 2,
            },
            "toldo": {
                "salida_x": round(abs(awning_lo[0]), 3),
                "z_apoyo": AWNING_INNER[1],
                "z_borde": round(awning_lo[2], 3),
                "largo_y": round(AWNING_Y[1] - AWNING_Y[0], 3),
                "rayas": AWNING_STRIPES,
            },
            "mostrador": {
                "z": COUNTER_Z,
                "salida_x": round(abs(COUNTER_OUT), 3),
                "largo_y": 4.30,
            },
            "chimenea": {
                "base_xy": list(CHIMNEY_XY),
                "alto_z": CHIMNEY_TOP,
            },
            "placa": {
                "tamano_x": round(plate_hi[0] - plate_lo[0], 3),
                "tamano_y": round(plate_hi[1] - plate_lo[1], 3),
                "z_inferior": round(plate_lo[2], 4),
                "z_superior": round(plate_hi[2], 4),
                "centro_xy": [PLATE_CENTER[0], PLATE_CENTER[1]],
            },
            "avatar": {
                "seat_z": round(seat[2], 4),
                "libre_sobre_placa": True,
                "toldo_z_max": round(awning_hi[2], 3),
            },
        },
        "seat": list(seat),
        "ruedas": {
            key: {
                "archivo": f"food_wheel_{key}.fbx",
                "tapacubos": f"food_hub_{key}.fbx",
                "eje": list(WHEEL_AXLES[key]),
                "giro": "X",
                "radio": WHEEL_RADIUS,
                "ancho": WHEEL_DEPTH,
            }
            for key in WHEEL_AXLES
        },
        "materiales": {
            **{obj.name: obj.data.materials[0].name for obj in body.values()},
            "food_plate": "plate",
            **{f"food_wheel_{key}": "dark" for key in WHEEL_AXLES},
            **{f"food_hub_{key}": "steel" for key in WHEEL_AXLES},
            "food_LOD1": "food",
        },
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("FOODTRUCK_STATS", json.dumps(stats))

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

    render(scene, camera("frontal", (-12.0, -21.0, 12.0), (0.0, 0.0, 2.9), lens=50),
           "food-truck-3-4-frontal.png")
    render(scene, camera("trasera", (12.0, 21.0, 12.0), (0.0, 0.0, 2.9), lens=50),
           "food-truck-3-4-trasera.png")
    for obj in avatar:
        obj.hide_render = False
    render(scene, camera("perfil", (60.0, 4.0, 3.0), (0.0, 4.0, 3.0), ortho_scale=26.0),
           "food-truck-perfil-avatar.png")
    print("FOODTRUCK_RENDERS_OK")


if __name__ == "__main__":
    main()

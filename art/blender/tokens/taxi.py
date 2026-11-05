"""Ficha taxi: token de vehiculo de Flip the Table y referencia para los otros siete.

Sedan clasico de tres volumenes, caricaturesco y de juguete de lujo: capo, cabina mas estrecha que la
carroceria con montantes inclinados, maletero bajo y visible, arcos de rueda integrados en el lateral,
banda ajedrezada, parabrisas y luna trasera con marco oscuro, tapacubos de acero y cartelito TAXI generico.
Sin marcas, logotipos ni matriculas reales.

Salidas, en art/blender/tokens/taxi/:
  taxi_body_<material>.fbx     carroceria, una malla por material (origen en el centro de la base)
  taxi_plate.fbx               placa del techo, separada: se tine con el color del jugador
  taxi_wheel_{fl,fr,rl,rr}.fbx neumatico, con el origen en su eje de giro (eje X)
  taxi_hub_{fl,fr,rl,rr}.fbx   tapacubos de acero, en malla aparte, mismo origen y eje que su rueda
  taxi_LOD1.fbx                una sola malla y un solo material (color de carroceria)
  stats.json                   triangulos por pieza, total y LOD1, medidas, ejes y seat
Y en art/render/tokens/taxi/: 3/4 frontal, 3/4 trasero y perfil con avatar de 6 studs al lado.

Convenciones (como art/blender/slice/build_cine_lux.py): 1 unidad de Blender = 1 stud, el morro mira a -Y,
Z hacia arriba, origen en el centro de la base a ras de suelo, exportacion FBX con Z Forward / Y Up.

Uso (segundo plano, sin abrir Blender):
  "D:\\blender\\blender.exe" --background --factory-startup --python art/blender/tokens/taxi.py
"""

import glob
import json
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "taxi")
RENDER = os.path.join(REPO, "art", "render", "tokens", "taxi")

LOD_RATIO = 0.5
TOTAL_BUDGET = 3000
PART_BUDGET = 120  # rueda con su tapacubos
PREVIOUS = {"triangles": 476, "size_x": 6.24, "size_y": 11.6, "size_z": 5.65}  # taxi actual, medido

# Ruedas: origen en el eje de giro, en studs, relativo a la base. l = -X, r = +X (de frente).
WHEEL_AXLES = {
    "fl": (-2.65, -3.4, 1.0),
    "fr": (2.65, -3.4, 1.0),
    "rl": (-2.65, 3.4, 1.0),
    "rr": (2.65, 3.4, 1.0),
}
WHEEL_RADIUS = 1.0
WHEEL_DEPTH = 0.8
HUB_RADIUS = 0.5
HUB_DEPTH = 0.9
ARCH_RADIUS = 1.3  # arco oscuro alrededor del neumatico, en el lateral

# Carroceria (perfil lateral y, z): capo, maletero bajo. El morro es el -Y.
BODY_HALF = 2.95
REAR_Y = 6.0
BODY_POINTS = [
    (-5.8, 0.9), (-5.8, 2.0), (-5.5, 2.6), (-5.0, 2.75), (-3.5, 2.8),
    (4.1, 2.8), (4.1, 3.1), (REAR_Y, 3.1), (REAR_Y, 0.9),
]

# Cabina: mas estrecha que la carroceria. Parabrisas y luna trasera inclinados entre cabina y maletero.
CABIN_HALF = 2.55
ROOF_Z = 4.5
WINDSHIELD_P0 = (-3.5, 2.8)
WINDSHIELD_P1 = (-1.9, 4.5)
BACKLIGHT_P0 = (3.3, 4.5)
BACKLIGHT_P1 = (4.1, 3.1)
ROOF_REAR_Y = BACKLIGHT_P0[0]
TRUNK_Z = 3.1
CABIN_POINTS = [WINDSHIELD_P0, WINDSHIELD_P1, BACKLIGHT_P0, BACKLIGHT_P1, (4.1, 2.8)]
GLASS_HALF = 2.05  # cristal del parabrisas y de la luna trasera, dentro de los montantes amarillos
FRAME_HALF = 2.25  # marco oscuro, con relieve, detras del cristal

# Arcos de rueda: abultamiento continuo de la chapa, trapecio en seccion (x, z) a lo largo de y.
BULGE_RANGES = [(-4.6, -2.2), (2.2, 4.6)]


def bulge_section(a):
    """Seccion trapecial (x, z) del abultamiento: a = 0 queda dentro de la chapa, a = 1 es el arco completo."""
    return [(2.8, 2.55), (2.9 + 0.3 * a, 2.55), (2.9 + 0.2 * a, 2.7 + 0.25 * a), (2.8, 2.7 + 0.25 * a)]

# Techo de la cabina: zona plana bajo la placa (4,5 x 4,5, cabe con el redondeo de los bordes).
PLATE_SIZE = (4.5, 4.5, 0.1)
PLATE_CENTER = (0.0, 0.8, ROOF_Z + 0.05)
SEAT = (0.0, 0.8, ROOF_Z + 0.1)
SIGN_SIZE = (2.0, 0.4, 0.6)
SIGN_CENTER = (0.0, -1.7, ROOF_Z + 0.3)
WIPER_X = (-0.6, 0.6)
WIPER_LENGTH = 0.9

# Banda ajedrezada: dos hileras de cuadros, de -4,8 a 4,8, por encima de las ruedas.
CHECK_Z = 2.05
CHECK_ROW = 0.25
CHECK_STEP = 0.6
CHECK_COUNT = 16
SIDE_WINDOWS = [(-1.6, 1.4), (1.7, 3.0)]  # tramos de ventanilla (y0, y1), z 3.1 a 4.1
WINDOW_Z = (3.1, 4.1)
DOOR_SEAMS = (-2.0, 1.55)
HANDLES = (-0.6, 2.2)


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


def arch_bulge(name, y0, y1, mat):
    """Abultamiento de la chapa sobre la rueda: loft de secciones trapeciales que nacen y mueren dentro de la chapa."""
    stations = [(y0, 0.0), (y0 + 0.7, 1.0), (y1 - 0.7, 1.0), (y1, 0.0)]
    objs = []
    for side in (-1, 1):
        verts, faces = [], []
        for y, a in stations:
            for x, z in bulge_section(a):
                verts.append((side * x, y, z))
        n = len(bulge_section(0.0))
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


def wiper(name, x, p0, p1, mat):
    """Limpiaparabrisas sencillo: pieza oscura alineada con el parabrisas, sobre el cristal."""
    dy, dz = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dy, dz)
    uy, uz = dy / length, dz / length
    ny, nz = -uz, uy
    mid = ((p0[0] + p1[0]) / 2 + ny * 0.14, (p0[1] + p1[1]) / 2 + nz * 0.14)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, mid[0], mid[1]))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (0.08, 0.05, WIPER_LENGTH)
    obj.rotation_euler = (math.atan2(-dy, dz), 0, 0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(mat)
    return obj


def ring(name, center, radius, depth, segments, mat):
    """Anillo oscuro alrededor de la rueda, con el eje en X: arco de rueda en el lateral."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=segments, radius=radius, depth=depth, location=center, rotation=(0, math.radians(90), 0)
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
    obj.data.materials.append(mat)
    return obj


def arch_arc(name, axle_y, x_center, mat, segments=8):
    """Arco oscuro sobre el neumatico: media corona (radio ARCH_RADIUS a 1,0) desde el eje hacia arriba."""
    angles = [math.pi * i / segments for i in range(segments + 1)]
    outer = [(axle_y + ARCH_RADIUS * math.cos(t), 1.0 + ARCH_RADIUS * math.sin(t)) for t in angles]
    inner = [(axle_y + 1.0 * math.cos(t), 1.0 + 1.0 * math.sin(t)) for t in reversed(angles)]
    obj = profile(name, outer + inner, 0.07, mat)
    obj.location = (x_center, 0.0, 0.0)
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


def build_body(mats):
    parts = []
    parts.append(bevel(profile("body", BODY_POINTS, BODY_HALF, mats["taxi"]), 0.2))
    parts.append(bevel(profile("cabin", CABIN_POINTS, CABIN_HALF, mats["taxi"]), 0.15))
    # Arcos de rueda: abultamiento de la misma chapa y anillo oscuro alrededor del neumatico.
    for y0, y1 in BULGE_RANGES:
        parts += arch_bulge("arch_bulge", y0, y1, mats["taxi"])
    for side in (-1, 1):
        for axle_y in (-3.4, 3.4):
            parts.append(arch_arc("arch_ring", axle_y, side * 2.98, mats["dark"]))
    # Parabrisas y luna trasera: marco oscuro con relieve y cristal menor entre montantes amarillos.
    parts.append(slope_slab("windshield_frame", WINDSHIELD_P0, WINDSHIELD_P1, 0.0, 0.1, -0.05, FRAME_HALF, mats["dark"]))
    parts.append(slope_slab("windshield", WINDSHIELD_P0, WINDSHIELD_P1, 0.1, 0.14, -0.2, GLASS_HALF, mats["glass"]))
    parts.append(slope_slab("rear_frame", BACKLIGHT_P0, BACKLIGHT_P1, 0.0, 0.1, -0.05, FRAME_HALF, mats["dark"]))
    parts.append(slope_slab("rear_glass", BACKLIGHT_P0, BACKLIGHT_P1, 0.1, 0.14, -0.2, GLASS_HALF, mats["glass"]))
    for x in WIPER_X:
        parts.append(wiper("wiper", x, WINDSHIELD_P0, WINDSHIELD_P1, mats["dark"]))
    # Ventanillas con marco oscuro, en los dos lados de la cabina.
    z0, z1 = WINDOW_Z
    for side in (-1, 1):
        for y0, y1 in SIDE_WINDOWS:
            w, h, yc, zc = y1 - y0, z1 - z0, (y0 + y1) / 2, (z0 + z1) / 2
            parts.append(box("window_frame", (0.05, w + 0.16, h + 0.16), (side * 2.555, yc, zc), mats["dark"]))
            parts.append(box("window", (0.04, w, h), (side * 2.6, yc, zc), mats["glass"]))
    # Banda ajedrezada continua: dos hileras, cuadros alternos oscuros y crema.
    for side in (-1, 1):
        for row in (0, 1):
            z = CHECK_Z + row * CHECK_ROW + CHECK_ROW / 2
            for i in range(CHECK_COUNT):
                y = -4.8 + i * CHECK_STEP + CHECK_STEP / 2
                material = mats["dark"] if (i + row) % 2 == 0 else mats["cream"]
                parts.append(box("check", (0.05, CHECK_STEP, CHECK_ROW), (side * 2.975, y, z), material))
    # Juntas de puerta y manillas, por debajo de la banda.
    for side in (-1, 1):
        for y in DOOR_SEAMS:
            parts.append(box("door_seam", (0.06, 0.08, 1.1), (side * 2.99, y, 1.5), mats["dark"]))
        for y in HANDLES:
            parts.append(box("handle", (0.12, 0.35, 0.12), (side * 2.99, y, 1.6), mats["steel"]))
    # Morro: faros, parachoques de acero y cartelito TAXI generico delante de la placa.
    for side in (-1, 1):
        parts.append(box("headlight", (0.9, 0.15, 0.45), (side * 1.9, -5.82, 1.7), mats["cream"]))
    parts.append(bevel(box("bumper_f", (5.6, 0.4, 0.5), (0, -6.0, 1.15), mats["steel"]), 0.1))
    # Trasera: pilotos rojos, placa en blanco sin texto, parachoques.
    for side in (-1, 1):
        parts.append(box("taillight", (0.9, 0.12, 0.5), (side * 2.0, 6.02, 2.45), mats["red"]))
    parts.append(box("rear_plate", (1.8, 0.1, 0.45), (0, 6.04, 1.55), mats["cream"]))
    parts.append(bevel(box("bumper_b", (5.6, 0.4, 0.5), (0, 6.0, 1.15), mats["steel"]), 0.1))
    parts.append(bevel(box("roof_sign", SIGN_SIZE, SIGN_CENTER, mats["cream"]), 0.06))
    return parts


def build_plate(mats):
    return bevel(box("taxi_plate", PLATE_SIZE, PLATE_CENTER, mats["plate"]), 0.03)


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
        "taxi": flat("taxi", "F5C518", 0.35),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "glass": flat("glass", "7FB2D9", 0.12, 0.0),
        "steel": flat("steel", "A8AEB4", 0.25, 0.8),
        "red": flat("red", "C4382B", 0.7),
        "plate": flat("plate", "EDEAE3", 0.5),
        "ground": flat("ground", "8E9196", 0.9),
    }

    body = group_by_material(build_body(mats), "taxi_body")
    plate = build_plate(mats)
    wheels = {key: wheel_part(f"taxi_wheel_{key}", WHEEL_RADIUS, WHEEL_DEPTH, 16, mats["dark"]) for key in WHEEL_AXLES}
    hubs = {key: wheel_part(f"taxi_hub_{key}", HUB_RADIUS, HUB_DEPTH, 8, mats["steel"]) for key in WHEEL_AXLES}

    # Comprobaciones antes de exportar.
    entries = [(obj, (0.0, 0.0, 0.0)) for obj in body.values()] + [(plate, (0.0, 0.0, 0.0))]
    entries += [(wheels[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    entries += [(hubs[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    lo, hi = bounds(entries)
    plate_lo, plate_hi = bounds([(plate, (0.0, 0.0, 0.0))])
    seat = (round((plate_lo[0] + plate_hi[0]) / 2, 4), round((plate_lo[1] + plate_hi[1]) / 2, 4), round(plate_hi[2], 4))
    length = hi[1] - lo[1]
    trunk = REAR_Y - ROOF_REAR_Y
    assert plate_hi[0] - plate_lo[0] >= 4.5 - 1e-6 and plate_hi[1] - plate_lo[1] >= 4.5 - 1e-6, "placa menor de 4,5 x 4,5"
    assert plate_lo[2] >= ROOF_Z - 1e-6, "la placa no apoya en el techo"
    assert plate_lo[1] > SIGN_CENTER[1] + SIGN_SIZE[1] / 2, "el cartelito invade la placa"
    assert abs(seat[2] - plate_hi[2]) < 1e-6, "el seat no coincide con la cara superior de la placa"
    assert hi[0] - lo[0] <= PREVIOUS["size_x"] * 1.10, "ancho por encima del 10 %"
    assert length <= PREVIOUS["size_y"] * 1.10, "largo por encima del 10 %"
    assert hi[2] - lo[2] <= PREVIOUS["size_z"] * 1.10, "alto por encima del 10 %"
    assert trunk >= 0.2 * length, f"maletero {trunk:.2f} por debajo del 20 % del largo"
    assert TRUNK_Z < ROOF_Z - 1.0, "el maletero no es visiblemente mas bajo que la cabina"
    for key in WHEEL_AXLES:
        assert count(wheels[key]) + count(hubs[key]) <= PART_BUDGET, f"rueda {key} por encima de {PART_BUDGET}"
    for obj in [*body.values(), plate, *wheels.values(), *hubs.values()]:
        assert len(obj.data.materials) == 1, f"{obj.name} tiene varios materiales"

    # LOD1: una sola malla con un solo material (carroceria), reducida al 50 %.
    yellow = body["taxi"]
    lod_parts = [lod_copy(yellow, (0.0, 0.0, 0.0), mats["taxi"])]
    lod_parts += [lod_copy(wheels[key], WHEEL_AXLES[key], mats["taxi"]) for key in WHEEL_AXLES]
    lod = join(lod_parts, "taxi_LOD1")
    select_only(lod)
    bpy.ops.object.material_slot_remove_unused()
    assert len(lod.data.materials) == 1, "el LOD1 tiene mas de un material"

    files = {}
    for obj in body.values():
        export(obj, f"{obj.name}.fbx")
        files[obj.name] = count(obj)
    export(plate, "taxi_plate.fbx")
    files["taxi_plate"] = count(plate)
    for key in WHEEL_AXLES:
        export(wheels[key], f"taxi_wheel_{key}.fbx")
        export(hubs[key], f"taxi_hub_{key}.fbx")
        files[f"taxi_wheel_{key}"] = count(wheels[key])
        files[f"taxi_hub_{key}"] = count(hubs[key])
    export(lod, "taxi_LOD1.fbx")
    total = sum(files.values())
    lod_triangles = count(lod)
    assert total <= TOTAL_BUDGET, f"{total} triangulos, por encima de {TOTAL_BUDGET}"
    assert lod_triangles <= total / 2, f"LOD1 con {lod_triangles}, mas de la mitad de {total}"

    stats = {
        "modelo": "taxi",
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
            "ancho_x": round(hi[0] - lo[0], 3),
            "largo_y": round(length, 3),
            "alto_z": round(hi[2] - lo[2], 3),
            "min_z": round(lo[2], 3),
            "techo_cabina_z": ROOF_Z,
            "maletero": {
                "inicio_y": ROOF_REAR_Y,
                "largo": round(trunk, 3),
                "porcentaje_del_largo": round(100 * trunk / length, 1),
                "z_superior": TRUNK_Z,
            },
            "placa": {
                "tamano_x": round(plate_hi[0] - plate_lo[0], 3),
                "tamano_y": round(plate_hi[1] - plate_lo[1], 3),
                "z_inferior": round(plate_lo[2], 4),
                "z_superior": round(plate_hi[2], 4),
                "centro_xy": [PLATE_CENTER[0], PLATE_CENTER[1]],
            },
            "previo_taxi_actual": PREVIOUS,
        },
        "seat": list(seat),
        "ruedas": {
            key: {
                "archivo": f"taxi_wheel_{key}.fbx",
                "tapacubos": f"taxi_hub_{key}.fbx",
                "eje": list(WHEEL_AXLES[key]),
                "giro": "X",
                "radio": WHEEL_RADIUS,
                "ancho": WHEEL_DEPTH,
            }
            for key in WHEEL_AXLES
        },
        "materiales": {
            **{obj.name: obj.data.materials[0].name for obj in body.values()},
            "taxi_plate": "plate",
            **{f"taxi_wheel_{key}": "dark" for key in WHEEL_AXLES},
            **{f"taxi_hub_{key}": "steel" for key in WHEEL_AXLES},
            "taxi_LOD1": "taxi",
        },
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("TAXI_STATS", json.dumps(stats))

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

    render(scene, camera("frontal", (-12.0, -21.0, 12.0), (0.0, 0.0, 2.6), lens=50), "taxi-3-4-frontal.png")
    render(scene, camera("trasera", (12.0, 21.0, 12.0), (0.0, 0.0, 2.6), lens=50), "taxi-3-4-trasera.png")
    for obj in avatar:
        obj.hide_render = False
    render(scene, camera("perfil", (60.0, 4.0, 3.0), (0.0, 4.0, 3.0), ortho_scale=26.0), "taxi-perfil-avatar.png")
    print("TAXI_RENDERS_OK")


if __name__ == "__main__":
    main()

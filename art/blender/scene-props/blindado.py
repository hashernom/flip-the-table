"""Pieza de escena blindado: el furgon blindado de Flip the Table.

Furgon de juguete gris acero, pesado y caricaturesco: cabina baja con parabrisas partido en dos
paneles pequenos, caja de carga mas alta con costados planos y remachados, portillos pequenos,
guardabarros oscuros sobre ruedas grandes, parachoques de goma, porton trasero de dos hojas y
techo con costillas y escotilla. Sin marcas, logotipos, matriculas ni texto.

Salidas, en art/blender/scene-props/blindado/:
  armored_<material>.fbx          una malla por material (origen en el centro de la base)
  armored_wheel_{fl,fr,rl,rr}.fbx neumatico, con el origen en su eje de giro (eje X)
  armored_hub_{fl,fr,rl,rr}.fbx   tapacubos, malla aparte, mismo origen y eje que su rueda
  armored_LOD1.fbx                una sola malla y un solo material, como maximo la mitad de triangulos
  stats.json                      triangulos por pieza, total y LOD1, medidas, giros y materiales
Y en art/render/scene-props/blindado/: 3/4 frontal, 3/4 trasero y perfil con avatar de 6 studs.

Convenciones (las de art/blender/tokens/taxi.py): 1 unidad de Blender = 1 stud, el morro mira a -Y,
Z hacia arriba, origen en el centro de la base a ras de suelo, exportacion FBX con Z Forward / Y Up.
Materiales de art/guia-de-estilo.md: acero A8AEB4, asfalto 2A2E33, cristal 2E4A63, caliza D2C9B4.
Medidas maximas: 7 de ancho, 14 de largo y 8 de alto. Presupuesto: 3 000 triangulos.

Uso (segundo plano, sin abrir Blender):
  "D:\\blender\\blender.exe" --background --factory-startup --python art/blender/scene-props/blindado.py
"""

import glob
import json
import math
import os

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "blindado")
RENDER = os.path.join(REPO, "art", "render", "scene-props", "blindado")

TOTAL_BUDGET = 3000
PART_BUDGET = 200  # rueda con su tapacubos
LOD_RATIO = 0.5
MAX_X, MAX_Y, MAX_Z = 7.0, 14.0, 8.0

# Ruedas: origen en el eje de giro, en studs, relativo a la base. l = -X, r = +X (de frente).
WHEEL_AXLES = {
    "fl": (-2.56, -3.90, 1.20),
    "fr": (2.56, -3.90, 1.20),
    "rl": (-2.56, 4.00, 1.20),
    "rr": (2.56, 4.00, 1.20),
}
WHEEL_RADIUS = 1.20
WHEEL_CENTER_Z = 1.20
WHEEL_DEPTH = 1.12
WHEEL_SIDES = 18
HUB_RADIUS = 0.66
HUB_DEPTH = 1.26
HUB_SIDES = 12
ARCH_INNER = 0.95  # aro oscuro de la caja de rueda, metido bajo el neumatico
ARCH_OUTER = 1.45
ARCH_HALF = 0.055
ARCH_X = 3.035
ARCH_START = -0.12  # el aro baja un poco por debajo del eje y muere en el borde inferior
ARCH_SWEEP = math.pi + 0.24

# Carroceria: un solo perfil lateral (y, z). Morro corto a -Y, cabina baja y caja de carga alta.
HALF_W = 3.00
BODY_POINTS = [
    (-6.60, 1.05),
    (-6.60, 2.92),
    (-6.40, 3.28),
    (-4.70, 3.56),
    (-4.00, 5.10),
    (-2.60, 5.24),
    (-2.45, 6.28),
    (6.20, 6.28),
    (6.60, 5.92),
    (6.60, 1.05),
]
BODY_BEVEL = 0.16

# Parabrisas partido en dos paneles pequenos, con marco oscuro y montante central.
WINDSHIELD_P0 = (-4.70, 3.56)
WINDSHIELD_P1 = (-4.00, 5.10)
FRAME_HALF = 2.50
GLASS_HALF = 0.92
GLASS_CENTER = 1.04
POST_HALF = 0.11
WIPER_X = (-0.55, 0.55)
WIPER_LENGTH = 0.70

# Ventanillas pequenas: cabina, portillos de la caja y lunas traseras.
CAB_WINDOW = (-3.85, -2.85, 3.95, 4.85)  # y0, y1, z0, z1
PORTHOLE_YS = (-0.75, 1.55)
PORTHOLE_Z = 5.20
PORTHOLE_SIZE = 0.54
REAR_WINDOW_X = (-1.35, 1.35)
REAR_WINDOW_Z = 5.05
REAR_WINDOW_SIZE = 0.56

# Remaches de acero: dos hileras por costado de la caja y el perimetro de la trasera.
RIVET_SIZE = (0.10, 0.14, 0.14)
RIVET_ROWS_Z = (1.50, 5.95)
RIVET_YS = tuple(-2.10 + 0.80 * i for i in range(11))
REAR_RIVET_XS = (-2.45, 2.45)
REAR_RIVET_ZS = (1.60, 5.55)

# Detalles laterales: junta de puerta, manilla, estribo trasero y liston de roce.
DOOR_SEAM_Y = -2.68
HANDLE_Y = -3.05
STEP_Y = 5.85
STEP_SIZE = (0.26, 0.90, 0.14)
RUB_RAIL_Y = (-2.30, 6.30)
RUB_RAIL_Z = 2.10

# Morro y trasera: parachoques, rejilla, faros y pilotos.
BUMPER_FRONT = (0.0, -6.77, 1.52)
BUMPER_REAR = (0.0, 6.77, 1.47)
BUMPER_SIZE = (6.10, 0.34, 0.60)
GRILLE_Z = (2.10, 2.40, 2.70)
HEADLIGHT_X = (-2.10, 2.10)
REAR_LAMP_X = (-2.45, 2.45)

# Techo de la caja: costillas, escotilla y balizas sobre la cabina.
ROOF_RIBS_Y = (-1.40, 0.40, 5.30)
HATCH_CENTER = (0.0, 2.40, 6.33)
HATCH_FRAME = (1.70, 1.30, 0.10)
HATCH_LID = (1.30, 0.95, 0.10)
MARKER_X = (-2.35, 2.35)

ROOF_Z = 6.28
CAB_ROOF_Z = 5.24

MATERIALS = {
    "steel": ("A8AEB4", 0.50, 0.20),
    "asphalt": ("2A2E33", 0.72, 0.05),
    "glass": ("2E4A63", 0.12, 0.25),
    "limestone": ("D2C9B4", 0.35, 0.0),
}
LOD_MATERIAL = "steel"


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


def profile(name, points, half_width, mat, center_x=0.0):
    """Prisma con el perfil lateral `points` (y, z), de lado a lado del vehiculo."""
    verts = [(center_x - half_width, y, z) for y, z in points] + [
        (center_x + half_width, y, z) for y, z in points
    ]
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


def slope_slab(name, p0, p1, t0, t1, ext, half, mat, center_x=0.0):
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
    return profile(name, points, half, mat, center_x=center_x)


def wiper(name, x, p0, p1, mat):
    """Limpiaparabrisas sencillo: pieza oscura alineada con el parabrisas, sobre el cristal."""
    dy, dz = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dy, dz)
    uy, uz = dy / length, dz / length
    ny, nz = -uz, uy
    mid = ((p0[0] + p1[0]) / 2 + ny * 0.16, (p0[1] + p1[1]) / 2 + nz * 0.16)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, mid[0], mid[1]))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (0.07, 0.05, WIPER_LENGTH)
    obj.rotation_euler = (math.atan2(-dy, dz), 0, 0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(mat)
    return obj


def arch_ring(name, axle_y, x_center, mat, segments=10):
    """Aro oscuro sobre el neumatico: corona de paso de rueda que muere a ras del borde inferior."""
    angles = [ARCH_START + ARCH_SWEEP * i / segments for i in range(segments + 1)]
    outer = [
        (axle_y + ARCH_OUTER * math.cos(t), WHEEL_CENTER_Z + ARCH_OUTER * math.sin(t)) for t in angles
    ]
    inner = [
        (axle_y + ARCH_INNER * math.cos(t), WHEEL_CENTER_Z + ARCH_INNER * math.sin(t))
        for t in reversed(angles)
    ]
    return profile(name, outer + inner, ARCH_HALF, mat, center_x=x_center)


def wheel_part(name, radius, depth, verts, mat):
    """Cilindro con el eje en X y el origen en su centro: el origen es el eje de giro.

    Se gira medio paso sobre su eje para que un vertice quede abajo y la rueda toque el suelo.
    """
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts, radius=radius, depth=depth, location=(0, 0, 0), rotation=(0, math.radians(90), 0)
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    obj.data.transform(Matrix.Rotation(math.pi / verts, 4, "X"))
    obj.data.materials.append(mat)
    return obj


def rivet(name, x, y, z, mat):
    return box(name, RIVET_SIZE, (x, y, z), mat)


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
    parts.append(bevel(profile("hull", BODY_POINTS, HALF_W, mats["steel"]), BODY_BEVEL))
    # Aros oscuros de los cuatro pasos de rueda, planos sobre el costado.
    for axle in WHEEL_AXLES.values():
        for side in (-1, 1):
            parts.append(arch_ring("arch", axle[1], side * ARCH_X, mats["asphalt"]))
    # Parabrisas: marco oscuro, montante central y dos paneles de cristal pequenos.
    parts.append(
        slope_slab("windshield_frame", WINDSHIELD_P0, WINDSHIELD_P1, 0.0, 0.06, 0.0, FRAME_HALF, mats["asphalt"])
    )
    for sign in (-1, 1):
        parts.append(
            slope_slab(
                "windshield_glass",
                WINDSHIELD_P0,
                WINDSHIELD_P1,
                0.06,
                0.10,
                -0.08,
                GLASS_HALF,
                mats["glass"],
                center_x=sign * GLASS_CENTER,
            )
        )
    parts.append(
        slope_slab("windshield_post", WINDSHIELD_P0, WINDSHIELD_P1, 0.06, 0.12, 0.0, POST_HALF, mats["asphalt"])
    )
    for x in WIPER_X:
        parts.append(wiper("wiper", x, WINDSHIELD_P0, WINDSHIELD_P1, mats["asphalt"]))
    # Ventanillas de cabina y portillos pequenos de la caja, con marco oscuro y cristal menor.
    y0, y1, z0, z1 = CAB_WINDOW
    wy, wz, yc, zc = y1 - y0, z1 - z0, (y0 + y1) / 2, (z0 + z1) / 2
    for side in (-1, 1):
        parts.append(box("cab_frame", (0.06, wy + 0.18, wz + 0.18), (side * 3.005, yc, zc), mats["asphalt"]))
        parts.append(box("cab_glass", (0.05, wy, wz), (side * 3.035, yc, zc), mats["glass"]))
        for y in PORTHOLE_YS:
            frame = PORTHOLE_SIZE + 0.22
            parts.append(box("porthole_frame", (0.06, frame, frame), (side * 3.005, y, PORTHOLE_Z), mats["asphalt"]))
            parts.append(box("porthole_glass", (0.05, PORTHOLE_SIZE, PORTHOLE_SIZE), (side * 3.04, y, PORTHOLE_Z), mats["glass"]))
        # Junta de puerta, manilla y estribo de la puerta trasera.
        parts.append(box("door_seam", (0.05, 0.08, 3.00), (side * 3.005, DOOR_SEAM_Y, 3.60), mats["asphalt"]))
        parts.append(box("handle", (0.10, 0.28, 0.12), (side * 3.05, HANDLE_Y, 3.60), mats["asphalt"]))
        parts.append(box("side_step", STEP_SIZE, (side * 3.06, STEP_Y, 0.97), mats["asphalt"]))
        # Liston de roce, entre los dos volumenes y por encima de las ruedas.
        rail_y0, rail_y1 = RUB_RAIL_Y
        parts.append(
            box("rub_rail", (0.05, rail_y1 - rail_y0, 0.16), (side * 3.005, (rail_y0 + rail_y1) / 2, RUB_RAIL_Z), mats["asphalt"])
        )
        # Juntas verticales de la chapa de la caja.
        for y in (0.55, 3.75):
            parts.append(box("panel_seam", (0.05, 0.08, 3.60), (side * 3.005, y, 4.05), mats["asphalt"]))
        # Remaches: dos hileras a lo largo de la caja.
        for z in RIVET_ROWS_Z:
            for y in RIVET_YS:
                parts.append(rivet("rivet", side * 3.045, y, z, mats["asphalt"]))
    # Trasera: porton de dos hojas, travesano, bisagras, lunas, pilotos y remaches.
    parts.append(box("rear_seam", (0.10, 0.06, 4.40), (0.0, 6.63, 3.40), mats["asphalt"]))
    parts.append(box("rear_beam", (5.10, 0.06, 0.16), (0.0, 6.63, 3.00), mats["asphalt"]))
    for side in (-1, 1):
        parts.append(box("door_edge", (0.05, 0.06, 4.40), (side * 2.62, 6.63, 3.40), mats["asphalt"]))
        for z in (3.80, 5.30):
            parts.append(box("hinge", (0.34, 0.10, 0.36), (side * 2.55, 6.64, z), mats["asphalt"]))
        parts.append(box("rear_lamp", (0.50, 0.08, 0.58), (side * 2.45, 6.63, 2.20), mats["limestone"]))
    for x in REAR_WINDOW_X:
        frame = REAR_WINDOW_SIZE + 0.18
        parts.append(box("rear_frame", (frame, 0.06, frame), (x, 6.63, REAR_WINDOW_Z), mats["asphalt"]))
        parts.append(box("rear_glass", (REAR_WINDOW_SIZE, 0.05, REAR_WINDOW_SIZE), (x, 6.66, REAR_WINDOW_Z), mats["glass"]))
    for x in REAR_RIVET_XS:
        for z in REAR_RIVET_ZS:
            parts.append(rivet("rear_rivet", x, 6.645, z, mats["asphalt"]))
    # Morro: rejilla, faros y parachoques de goma.
    for z in GRILLE_Z:
        parts.append(box("grille", (3.00, 0.08, 0.13), (0.0, -6.63, z), mats["asphalt"]))
    for x in HEADLIGHT_X:
        parts.append(box("headlight", (0.70, 0.10, 0.46), (x, -6.62, 2.46), mats["limestone"]))
    parts.append(bevel(box("bumper_f", BUMPER_SIZE, BUMPER_FRONT, mats["asphalt"]), 0.08, 1))
    parts.append(bevel(box("bumper_b", BUMPER_SIZE, BUMPER_REAR, mats["asphalt"]), 0.08, 1))
    # Techo de la caja: costillas, escotilla y balizas sobre la cabina.
    for y in ROOF_RIBS_Y:
        parts.append(box("roof_rib", (5.40, 0.16, 0.10), (0.0, y, 6.32), mats["asphalt"]))
    parts.append(box("hatch_frame", HATCH_FRAME, HATCH_CENTER, mats["asphalt"]))
    parts.append(box("hatch_lid", HATCH_LID, (HATCH_CENTER[0], HATCH_CENTER[1], 6.38), mats["steel"]))
    for x in MARKER_X:
        parts.append(box("marker", (0.22, 0.26, 0.12), (x, -3.30, CAB_ROOF_Z + 0.06), mats["limestone"]))
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
    path = os.path.join(OUT, filename)
    assert os.path.getsize(path) > 0, f"{filename} vacio"


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

    mats = {name: flat(name, *values) for name, values in MATERIALS.items()}
    mats["ground"] = flat("ground", "8E9196", 0.9)
    mats["avatar"] = flat("avatar_ref", "5E636A", 0.8)

    body = group_by_material(build_body(mats), "armored")
    wheels = {
        key: wheel_part(f"armored_wheel_{key}", WHEEL_RADIUS, WHEEL_DEPTH, WHEEL_SIDES, mats["asphalt"])
        for key in WHEEL_AXLES
    }
    hubs = {
        key: wheel_part(f"armored_hub_{key}", HUB_RADIUS, HUB_DEPTH, HUB_SIDES, mats["steel"])
        for key in WHEEL_AXLES
    }

    # Comprobaciones antes de exportar.
    entries = [(obj, (0.0, 0.0, 0.0)) for obj in body.values()]
    entries += [(wheels[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    entries += [(hubs[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    lo, hi = bounds(entries)
    width, length, height = hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]
    assert abs(lo[2]) < 1e-3, f"min_z {lo[2]:.4f}, la base no esta a ras de suelo"
    assert width <= MAX_X + 1e-6, f"ancho {width:.2f} por encima de {MAX_X}"
    assert length <= MAX_Y + 1e-6, f"largo {length:.2f} por encima de {MAX_Y}"
    assert height <= MAX_Z + 1e-6, f"alto {height:.2f} por encima de {MAX_Z}"
    assert lo[1] < -6.9 and hi[1] > 6.9, "el morro no mira a -Y"
    assert width <= HALF_W * 2 + 0.7, "los espejos se salen del ancho previsto"
    for key in WHEEL_AXLES:
        assert count(wheels[key]) + count(hubs[key]) <= PART_BUDGET, f"rueda {key} por encima de {PART_BUDGET}"
    for obj in [*body.values(), *wheels.values(), *hubs.values()]:
        assert len(obj.data.materials) == 1, f"{obj.name} tiene varios materiales"
    assert set(body) == {"steel", "asphalt", "glass", "limestone"}, f"materiales de carroceria: {sorted(body)}"

    # LOD1: una sola malla con un solo material (acero), reducida a la mitad.
    lod_parts = [lod_copy(body[LOD_MATERIAL], (0.0, 0.0, 0.0), mats[LOD_MATERIAL])]
    lod_parts += [lod_copy(wheels[key], WHEEL_AXLES[key], mats[LOD_MATERIAL]) for key in WHEEL_AXLES]
    lod = join(lod_parts, "armored_LOD1")
    select_only(lod)
    bpy.ops.object.material_slot_remove_unused()
    assert len(lod.data.materials) == 1, "el LOD1 tiene mas de un material"

    # Las ruedas y los tapacubos se exportan con su origen en el eje y ya colocados en su sitio del
    # coche: el FBX lleva la traslacion del objeto y siguen girando alrededor de su propio centro.
    for key in WHEEL_AXLES:
        wheels[key].location = WHEEL_AXLES[key]
        hubs[key].location = WHEEL_AXLES[key]

    files = {}
    for name, obj in body.items():
        export(obj, f"{obj.name}.fbx")
        files[obj.name] = count(obj)
    for key in WHEEL_AXLES:
        export(wheels[key], f"armored_wheel_{key}.fbx")
        export(hubs[key], f"armored_hub_{key}.fbx")
        files[f"armored_wheel_{key}"] = count(wheels[key])
        files[f"armored_hub_{key}"] = count(hubs[key])
    export(lod, "armored_LOD1.fbx")
    total = sum(files.values())
    lod_triangles = count(lod)
    assert total <= TOTAL_BUDGET, f"{total} triangulos, por encima de {TOTAL_BUDGET}"
    assert lod_triangles <= total / 2, f"LOD1 con {lod_triangles}, mas de la mitad de {total}"

    stats = {
        "modelo": "blindado",
        "unidades": "studs (1 unidad de Blender = 1 stud)",
        "origen": "centro de la base, a ras de suelo (x = 0, y = 0, z = 0)",
        "frente": "-Y (morro)",
        "arriba": "+Z",
        "triangulos": {
            "piezas": files,
            "total": total,
            "lod1": lod_triangles,
            "lod1_porcentaje_del_total": round(100 * lod_triangles / total, 1),
            "lod1_mitad_del_total": round(total / 2, 1),
            "presupuesto_total": TOTAL_BUDGET,
            "presupuesto_por_rueda_con_tapacubos": PART_BUDGET,
        },
        "medidas": {
            "ancho_x": round(width, 3),
            "largo_y": round(length, 3),
            "alto_z": round(height, 3),
            "min_z": round(lo[2], 4),
            "max_z": round(hi[2], 3),
            "techo_caja_z": ROOF_Z,
            "techo_cabina_z": CAB_ROOF_Z,
            "batalla": round(WHEEL_AXLES["rl"][1] - WHEEL_AXLES["fl"][1], 3),
            "maximos": {"ancho_x": MAX_X, "largo_y": MAX_Y, "alto_z": MAX_Z},
        },
        "ruedas": {
            key: {
                "archivo": f"armored_wheel_{key}.fbx",
                "tapacubos": f"armored_hub_{key}.fbx",
                "eje": list(WHEEL_AXLES[key]),
                "giro": "X",
                "radio": WHEEL_RADIUS,
                "ancho": WHEEL_DEPTH,
            }
            for key in WHEEL_AXLES
        },
        "materiales": {obj.name: obj.data.materials[0].name for obj in body.values()},
        "materiales_ruedas": {f"armored_wheel_{key}": "asphalt" for key in WHEEL_AXLES},
        "materiales_tapacubos": {f"armored_hub_{key}": "steel" for key in WHEEL_AXLES},
        "materiales_lod1": [LOD_MATERIAL],
        "colores": {name: values[0] for name, values in MATERIALS.items()},
        "nota_roblox": "Cada FBX llega como una malla con un material. Ruedas y tapacubos llevan la traslacion del eje en el FBX, pero el pivote al importar queda en el centro de la caja: para girarlas, PivotOffset o un Attachment en stats.ruedas.<pos>.eje.",
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("BLINDADO_STATS", json.dumps(stats))

    # Escena de revision: suelo, sol y fondo, como taxi.py.
    lod.hide_render = True
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.1))
    ground = bpy.context.active_object
    ground.name = "ground"
    ground.scale = (90.0, 90.0, 0.2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ground.data.materials.append(mats["ground"])

    avatar = build_avatar(mats["avatar"])
    for obj in avatar:
        obj.location.y += 9.6
        obj.hide_render = True

    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 3.4
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
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    scene.view_settings.look = "AgX - Medium High Contrast"

    render(scene, camera("frontal", (-13.2, -21.5, 12.8), (0.0, -0.2, 3.0), lens=50), "blindado-3-4-frontal.png")
    render(scene, camera("trasera", (13.2, 21.5, 12.8), (0.0, 0.2, 3.0), lens=50), "blindado-3-4-trasero.png")
    for obj in avatar:
        obj.hide_render = False
    render(
        scene,
        camera("perfil", (60.0, 3.2, 3.1), (0.0, 3.2, 3.1), ortho_scale=26.5),
        "blindado-perfil-avatar.png",
    )
    print("BLINDADO_RENDERS_OK")


if __name__ == "__main__":
    main()

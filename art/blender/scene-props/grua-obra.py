"""Grua torre de obra: prop de escena de Flip the Table.

Grua torre de celosia amarilla para un solar en obras: base atornillada, mastil de cuatro montantes con
arriostrado en X, corona de giro, pluma triangular con carro, cable y gancho, contrapluma con tres bloques
de contrapeso, cabina acristalada en el lateral y punta con tirantes. Sin ruedas, sin marcas ni rotulos.

Salidas, en art/blender/scene-props/grua-obra/:
  crane_amarillo.fbx   estructura amarilla, una malla y un material
  crane_acero.fbx      acero pulido (tirantes, cable, carro, anclajes), una malla y un material
  crane_asfalto.fbx    asfalto oscuro (cristales, contrapesos, gancho), una malla y un material
  crane_LOD1.fbx       una sola malla, un solo material y menos de la mitad de los triangulos
  stats.json           triangulos, medidas, materiales, ejes y limites
Y en art/render/scene-props/grua-obra/: 3/4 frontal, 3/4 trasero y perfil con avatar de 6 studs.

Convenciones (como art/blender/tokens/taxi.py): 1 unidad de Blender = 1 stud, la pluma mira a -Y,
Z hacia arriba, origen en el centro de la base a ras de suelo, exportacion FBX Z Forward / Y Up.

Uso (segundo plano, sin abrir Blender):
  "D:\\blender\\blender.exe" --background --factory-startup --python art/blender/scene-props/grua-obra.py
"""

import glob
import json
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "grua-obra")
RENDER = os.path.join(REPO, "art", "render", "scene-props", "grua-obra")

LOD_RATIO = 0.45
TOTAL_BUDGET = 3000
MAX_X, MAX_Y, MAX_Z = 12.0, 30.0, 45.0

# Base atornillada: zapata amarilla centrada en el origen, con placas de acero en las esquinas.
BASE_X, BASE_Y, BASE_Z = 6.8, 6.8, 0.9
GUSSET_Z = 3.4  # altura a la que mueren los cartabones de la base

# Mastil de celosia: cuatro montantes en las esquinas, cuadros horizontales y X en las cuatro caras.
MAST_HALF = 1.9
POST = 0.45
FRAME = 0.30
BRACE = 0.28
MAST_Z0 = BASE_Z
MAST_Z1 = 29.6
MODULES = 5
MODULE = (MAST_Z1 - MAST_Z0) / MODULES
LEVELS = MODULES + 1

# Corona de giro.
RING_Z, RING_R, RING_H = 29.8, 2.35, 0.4
SLEW_Z0, SLEW_Z1 = 30.0, 31.5
SLEW_SIZE = 5.0

# Pluma triangular: dos cordones inferiores y uno superior, con V de celosia y travesanos.
JIB_Y0, JIB_Y1 = -2.5, -19.8
JIB_X = 1.2
JIB_Z0, JIB_Z1 = 31.5, 33.7
JIB_PANELS = 7

# Contrapluma: misma seccion, mas corta, con los bloques de contrapeso colgados del extremo.
CJ_Y0, CJ_Y1 = 2.5, 9.4
CJ_X = 1.1
CJ_Z0, CJ_Z1 = 31.5, 33.2
CJ_PANELS = 3

# Cabina: cuelga de una plataforma en el lateral -X, a la altura de la corona de giro.
CAB_X0, CAB_X1 = -5.4, -2.4
CAB_Y0, CAB_Y1 = -2.8, 0.4
CAB_Z0, CAB_Z1 = 30.9, 33.7
PLAT_X0, PLAT_X1 = -5.5, -2.3
PLAT_Y0, PLAT_Y1 = -3.1, 0.7
PLAT_Z0, PLAT_Z1 = 30.6, 30.9

# Contrapeso: tres bloques oscuros apilados en el extremo de la contrapluma.
CW_Y = 8.4
CW_SIZE = (3.2, 2.0, 0.72)
CW_LEVELS = (31.0, 30.28, 29.56)

# Punta: piramide de cuatro patas y tirantes hasta pluma y contrapluma.
APEX_Z = 36.6
APEX_HALF = 1.3
TIE_Z = 36.95
TIE_POINTS = ((0.0, -7.0, JIB_Z1 + 0.1), (0.0, -14.5, JIB_Z1 + 0.1), (0.0, 8.8, CJ_Z1 + 0.1))

# Carro, cable y gancho.
HOOK_Y = -13.2
TROLLEY_Z = 31.22
CABLE_Z0, CABLE_Z1 = 30.95, 13.45
BLOCK_Z = 13.1

# Avatar de referencia de 6 studs (solo render, no se exporta).
AVATAR_Y = -8.5


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


def bar(name, p0, p1, thickness, mat, depth=None):
    """Barra de seccion rectangular entre dos puntos: montantes, cuadros, celosia y tirantes."""
    p0, p1 = Vector(p0), Vector(p1)
    direction = p1 - p0
    length = direction.length
    if length < 1e-6:
        raise ValueError(f"{name}: barra de longitud cero")
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=tuple((p0 + p1) / 2))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (thickness, depth if depth is not None else thickness, length)
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(mat)
    return obj


def bevel(obj, width, segments=1):
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
    """Prisma con el perfil lateral `points` (y, z), de lado a lado."""
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


def cylinder(name, radius, depth, location, mat, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
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


def build_base(mats):
    """Zapata amarilla con placas de anclaje de acero y cartabones en las cuatro caras."""
    parts = [bevel(box("base_slab", (BASE_X, BASE_Y, BASE_Z), (0.0, 0.0, BASE_Z / 2), mats["amarillo"]), 0.10)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box("base_plate", (1.25, 1.25, 0.30), (sx * 2.65, sy * 2.65, BASE_Z + 0.15), mats["acero"]))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(
                bar(
                    "base_gusset",
                    (sx * (BASE_X / 2 - 0.35), sy * (BASE_Y / 2 - 0.35), 0.95),
                    (sx * MAST_HALF, sy * MAST_HALF, GUSSET_Z),
                    0.26,
                    mats["amarillo"],
                )
            )
    return parts


def build_mast(mats):
    """Cuatro montantes continuos, seis cuadros horizontales y X en cada cara y modulo."""
    parts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(
                bar(
                    "mast_post",
                    (sx * MAST_HALF, sy * MAST_HALF, MAST_Z0),
                    (sx * MAST_HALF, sy * MAST_HALF, MAST_Z1),
                    POST,
                    mats["amarillo"],
                )
            )
    for level in range(LEVELS):
        z = MAST_Z0 + level * MODULE
        for sy in (-1, 1):
            parts.append(
                bar("mast_frame_x", (-MAST_HALF, sy * MAST_HALF, z), (MAST_HALF, sy * MAST_HALF, z), FRAME, mats["amarillo"])
            )
        for sx in (-1, 1):
            parts.append(
                bar("mast_frame_y", (sx * MAST_HALF, -MAST_HALF, z), (sx * MAST_HALF, MAST_HALF, z), FRAME, mats["amarillo"])
            )
    for module in range(MODULES):
        z0 = MAST_Z0 + module * MODULE
        z1 = z0 + MODULE
        for sy in (-1, 1):
            parts.append(
                bar("mast_brace", (-MAST_HALF, sy * MAST_HALF, z0), (MAST_HALF, sy * MAST_HALF, z1), BRACE, mats["amarillo"])
            )
            parts.append(
                bar("mast_brace", (MAST_HALF, sy * MAST_HALF, z0), (-MAST_HALF, sy * MAST_HALF, z1), BRACE, mats["amarillo"])
            )
        for sx in (-1, 1):
            parts.append(
                bar("mast_brace", (sx * MAST_HALF, -MAST_HALF, z0), (sx * MAST_HALF, MAST_HALF, z1), BRACE, mats["amarillo"])
            )
            parts.append(
                bar("mast_brace", (sx * MAST_HALF, MAST_HALF, z0), (sx * MAST_HALF, -MAST_HALF, z1), BRACE, mats["amarillo"])
            )
    return parts


def build_slew(mats):
    """Corona de giro: anillo de acero y plataforma amarilla sobre el mastil."""
    parts = [cylinder("slew_ring", RING_R, RING_H, (0.0, 0.0, RING_Z), mats["acero"], vertices=12)]
    parts.append(
        bevel(box("slew_body", (SLEW_SIZE, SLEW_SIZE, SLEW_Z1 - SLEW_Z0), (0.0, 0.0, (SLEW_Z0 + SLEW_Z1) / 2), mats["amarillo"]), 0.12)
    )
    return parts


def build_jib(mats):
    """Pluma triangular: dos cordones inferiores, uno superior, V de celosia y travesanos."""
    parts = [
        bar("jib_chord_l", (-JIB_X, JIB_Y0, JIB_Z0), (-JIB_X, JIB_Y1, JIB_Z0), 0.34, mats["amarillo"]),
        bar("jib_chord_r", (JIB_X, JIB_Y0, JIB_Z0), (JIB_X, JIB_Y1, JIB_Z0), 0.34, mats["amarillo"]),
        bar("jib_chord_top", (0.0, JIB_Y0, JIB_Z1), (0.0, JIB_Y1, JIB_Z1), 0.34, mats["amarillo"]),
    ]
    panel = (JIB_Y1 - JIB_Y0) / JIB_PANELS
    for index in range(JIB_PANELS):
        ya = JIB_Y0 + index * panel
        yb = ya + panel
        parts.append(bar("jib_brace_l", (-JIB_X, ya, JIB_Z0), (0.0, yb, JIB_Z1), 0.22, mats["amarillo"]))
        parts.append(bar("jib_brace_r", (0.0, yb, JIB_Z1), (JIB_X, ya, JIB_Z0), 0.22, mats["amarillo"]))
        parts.append(bar("jib_cross", (-JIB_X, yb, JIB_Z0), (JIB_X, yb, JIB_Z0), 0.22, mats["amarillo"]))
    for sx in (-1, 1):
        parts.append(bar("jib_tip", (sx * JIB_X, JIB_Y1, JIB_Z0), (0.0, JIB_Y1, JIB_Z1), 0.24, mats["amarillo"]))
    return parts


def build_counter_jib(mats):
    """Contrapluma: celosia corta con el mismo perfil triangular que la pluma."""
    parts = [
        bar("cj_chord_l", (-CJ_X, CJ_Y0, CJ_Z0), (-CJ_X, CJ_Y1, CJ_Z0), 0.34, mats["amarillo"]),
        bar("cj_chord_r", (CJ_X, CJ_Y0, CJ_Z0), (CJ_X, CJ_Y1, CJ_Z0), 0.34, mats["amarillo"]),
        bar("cj_chord_top", (0.0, CJ_Y0, CJ_Z1), (0.0, CJ_Y1, CJ_Z1), 0.34, mats["amarillo"]),
    ]
    panel = (CJ_Y1 - CJ_Y0) / CJ_PANELS
    for index in range(CJ_PANELS):
        ya = CJ_Y0 + index * panel
        yb = ya + panel
        parts.append(bar("cj_brace_l", (-CJ_X, ya, CJ_Z0), (0.0, yb, CJ_Z1), 0.22, mats["amarillo"]))
        parts.append(bar("cj_brace_r", (0.0, yb, CJ_Z1), (CJ_X, ya, CJ_Z0), 0.22, mats["amarillo"]))
        parts.append(bar("cj_cross", (-CJ_X, yb, CJ_Z0), (CJ_X, yb, CJ_Z0), 0.22, mats["amarillo"]))
    for sx in (-1, 1):
        parts.append(bar("cj_tip", (sx * CJ_X, CJ_Y1, CJ_Z0), (0.0, CJ_Y1, CJ_Z1), 0.24, mats["amarillo"]))
    return parts


def build_cab(mats):
    """Cabina: plataforma volada, cuerpo amarillo, techo y dos cristales oscuros."""
    parts = [
        box(
            "cab_platform",
            (PLAT_X1 - PLAT_X0, PLAT_Y1 - PLAT_Y0, PLAT_Z1 - PLAT_Z0),
            ((PLAT_X0 + PLAT_X1) / 2, (PLAT_Y0 + PLAT_Y1) / 2, (PLAT_Z0 + PLAT_Z1) / 2),
            mats["amarillo"],
        )
    ]
    for sy in (-1, 1):
        parts.append(
            bar(
                "cab_strut",
                (-2.3, sy * 1.2, 30.4),
                (-5.2, sy * 1.2, PLAT_Z0 + 0.04),
                0.20,
                mats["acero"],
            )
        )
    parts.append(
        bevel(
            box(
                "cab_body",
                (CAB_X1 - CAB_X0, CAB_Y1 - CAB_Y0, CAB_Z1 - CAB_Z0),
                ((CAB_X0 + CAB_X1) / 2, (CAB_Y0 + CAB_Y1) / 2, (CAB_Z0 + CAB_Z1) / 2),
                mats["amarillo"],
            ),
            0.12,
        )
    )
    parts.append(
        box(
            "cab_roof",
            (CAB_X1 - CAB_X0 + 0.2, CAB_Y1 - CAB_Y0 + 0.2, 0.22),
            ((CAB_X0 + CAB_X1) / 2, (CAB_Y0 + CAB_Y1) / 2, CAB_Z1 + 0.11),
            mats["amarillo"],
        )
    )
    parts.append(box("cab_glass_front", (2.3, 0.10, 1.55), ((CAB_X0 + CAB_X1) / 2, CAB_Y0 - 0.03, 33.55), mats["asfalto"]))
    parts.append(box("cab_glass_side", (0.10, 2.3, 1.35), (CAB_X0 - 0.03, (CAB_Y0 + CAB_Y1) / 2, 33.5), mats["asfalto"]))
    return parts


def build_counterweight(mats):
    """Tres bloques oscuros colgados de dos tirantes de acero en el extremo de la contrapluma."""
    parts = []
    for sx in (-1, 1):
        parts.append(bar("cw_rod", (sx * 0.9, CW_Y, CJ_Z0 - 0.05), (sx * 0.9, CW_Y, CW_LEVELS[-1] - 0.1), 0.14, mats["acero"]))
    for z in CW_LEVELS:
        parts.append(bevel(box("cw_block", CW_SIZE, (0.0, CW_Y, z), mats["asfalto"]), 0.06))
    return parts


def build_apex(mats):
    """Punta: cuatro patas, dos travesanos y tirantes de acero hasta la pluma y la contrapluma."""
    parts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(
                bar(
                    "apex_leg",
                    (sx * APEX_HALF, sy * APEX_HALF, SLEW_Z1),
                    (0.0, 0.0, APEX_Z),
                    0.26,
                    mats["amarillo"],
                )
            )
    for sy in (-1, 1):
        y = sy * 0.78
        parts.append(bar("apex_cross", (-0.78, y, 33.6), (0.78, y, 33.6), 0.20, mats["amarillo"]))
    parts.append(box("apex_cap", (0.6, 0.6, 0.5), (0.0, 0.0, APEX_Z + 0.25), mats["amarillo"]))
    for point in TIE_POINTS:
        parts.append(bar("tie", (0.0, 0.0, TIE_Z), point, 0.13, mats["acero"]))
    return parts


def build_hook(mats):
    """Carro bajo la pluma, cable de acero y gancho oscuro: fondo de gancho por encima de z = 10."""
    parts = [
        box("trolley", (2.6, 1.0, 0.55), (0.0, HOOK_Y, TROLLEY_Z), mats["acero"]),
        bar("hoist_cable", (0.0, HOOK_Y, CABLE_Z0), (0.0, HOOK_Y, CABLE_Z1), 0.10, mats["acero"]),
        box("hook_block", (0.55, 0.75, 0.75), (0.0, HOOK_Y, BLOCK_Z), mats["acero"]),
        box("hook_shank", (0.24, 0.24, 0.85), (0.0, HOOK_Y, 12.32), mats["asfalto"]),
        box("hook_bend", (0.24, 0.62, 0.24), (0.0, HOOK_Y + 0.25, 11.95), mats["asfalto"]),
        box("hook_tip", (0.24, 0.24, 0.50), (0.0, HOOK_Y + 0.45, 12.16), mats["asfalto"]),
    ]
    return parts


def build_parts(mats):
    return (
        build_base(mats)
        + build_mast(mats)
        + build_slew(mats)
        + build_jib(mats)
        + build_counter_jib(mats)
        + build_cab(mats)
        + build_counterweight(mats)
        + build_apex(mats)
        + build_hook(mats)
    )


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


def world_bounds(objects):
    """Bbox en mundo: tiene en cuenta la matriz de cada objeto (el avatar si la usa)."""
    bpy.context.view_layer.update()
    lo = [1e9, 1e9, 1e9]
    hi = [-1e9, -1e9, -1e9]
    for obj in objects:
        matrix = obj.matrix_world
        for vertex in obj.data.vertices:
            point = matrix @ Vector(vertex.co)
            for i in range(3):
                lo[i] = min(lo[i], point[i])
                hi[i] = max(hi[i], point[i])
    return lo, hi


def count(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def lod_copy(source, material):
    copy = source.copy()
    copy.data = source.data.copy()
    copy.name = f"{source.name}_lod"
    bpy.context.collection.objects.link(copy)
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


def camera(name, location, target, lens=50.0):
    data = bpy.data.cameras.new(name)
    data.lens = lens
    data.sensor_fit = "AUTO"
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    return obj


def frame_camera(name, direction, target, bbox, margin=1.12, lens=50.0, resolution=(1200, 1200)):
    """Coloca una camara en perspectiva a la distancia justa para que el bbox entre con margen."""
    d = Vector(direction).normalized()
    f = -d
    right = f.cross(Vector((0.0, 0.0, 1.0)))
    if right.length < 1e-6:
        right = Vector((1.0, 0.0, 0.0))
    right.normalize()
    up = right.cross(f)
    tan_h = 18.0 / lens
    tan_v = tan_h * (resolution[1] / resolution[0])
    lo, hi = bbox
    distance = 5.0
    for x in (lo[0], hi[0]):
        for y in (lo[1], hi[1]):
            for z in (lo[2], hi[2]):
                v = Vector((x, y, z)) - Vector(target)
                depth = v.dot(f)
                distance = max(
                    distance,
                    abs(v.dot(right)) * margin / tan_h - depth,
                    abs(v.dot(up)) * margin / tan_v - depth,
                )
    return camera(name, tuple(Vector(target) + d * distance), target, lens=lens)


def frame_ortho(name, direction, target, bbox, margin=1.10, resolution=(1200, 1200)):
    d = Vector(direction).normalized()
    f = -d
    right = f.cross(Vector((0.0, 0.0, 1.0)))
    if right.length < 1e-6:
        right = Vector((1.0, 0.0, 0.0))
    right.normalize()
    up = right.cross(f)
    lo, hi = bbox
    half_w = max(abs((Vector((x, y, z)) - Vector(target)).dot(right)) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2]))
    half_h = max(abs((Vector((x, y, z)) - Vector(target)).dot(up)) for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2]))
    scale = 2.0 * max(half_w * resolution[0] / resolution[1], half_h) * margin
    data = bpy.data.cameras.new(name)
    data.type = "ORTHO"
    data.ortho_scale = scale
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = tuple(Vector(target) + d * 200.0)
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
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
        "amarillo": flat("amarillo", "F5C518", 0.35),
        "acero": flat("acero", "A8AEB4", 0.25, 0.8),
        "asfalto": flat("asfalto", "2A2E33", 0.6),
    }

    groups = group_by_material(build_parts(mats), "crane")

    # Comprobaciones antes de exportar.
    entries = [(obj, (0.0, 0.0, 0.0)) for obj in groups.values()]
    lo, hi = bounds(entries)
    size_x, size_y, size_z = hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]
    assert abs(lo[2]) < 1e-6, f"la base no arranca en z = 0 (min_z = {lo[2]})"
    for obj in groups.values():
        assert len(obj.data.materials) == 1, f"{obj.name} tiene varios materiales"
        assert len(obj.data.polygons) > 0, f"{obj.name} esta vacio"
    assert size_x <= MAX_X + 1e-6, f"ancho {size_x:.2f} por encima de {MAX_X}"
    assert size_y <= MAX_Y + 1e-6, f"largo {size_y:.2f} por encima de {MAX_Y}"
    assert size_z <= MAX_Z + 1e-6, f"alto {size_z:.2f} por encima de {MAX_Z}"
    assert lo[1] < -10 and hi[1] > 5, "la pluma no mira a -Y"

    # LOD1: una sola malla con un solo material (amarillo), reducida por debajo de la mitad.
    lod_parts = [lod_copy(obj, mats["amarillo"]) for obj in groups.values()]
    lod = join(lod_parts, "crane_LOD1")
    select_only(lod)
    bpy.ops.object.material_slot_remove_unused()
    assert len(lod.data.materials) == 1, "el LOD1 tiene mas de un material"

    files = {}
    for obj in groups.values():
        files[obj.name] = count(obj)
    total = sum(files.values())
    lod_triangles = count(lod)
    assert total <= TOTAL_BUDGET, f"{total} triangulos, por encima de {TOTAL_BUDGET}"
    assert lod_triangles <= total / 2, f"LOD1 con {lod_triangles}, mas de la mitad de {total}"

    for obj in groups.values():
        export(obj, f"{obj.name}.fbx")
    export(lod, "crane_LOD1.fbx")

    lod_lo, lod_hi = bounds([(lod, (0.0, 0.0, 0.0))])
    stats = {
        "modelo": "grua-obra",
        "unidades": "studs (1 unidad de Blender = 1 stud)",
        "origen": "centro de la base, a ras de suelo (x = 0, y = 0, z = 0)",
        "frente": "-Y (pluma y gancho)",
        "arriba": "+Z",
        "limites": {"max_x": MAX_X, "max_y": MAX_Y, "max_z": MAX_Z},
        "triangulos": {
            "piezas": files,
            "total": total,
            "lod1": lod_triangles,
            "lod1_mitad_del_total": round(total / 2, 1),
            "lod1_ratio": LOD_RATIO,
            "presupuesto_total": TOTAL_BUDGET,
        },
        "medidas": {
            "ancho_x": round(size_x, 3),
            "largo_y": round(size_y, 3),
            "alto_z": round(size_z, 3),
            "min_z": round(lo[2], 5),
            "max_z": round(hi[2], 3),
            "base": {"tamano_x": BASE_X, "tamano_y": BASE_Y, "alto": BASE_Z, "centro": [0.0, 0.0]},
            "mastil": {"seccion": round(2 * MAST_HALF + POST, 3), "de_z": MAST_Z0, "a_z": MAST_Z1, "modulos": MODULES},
            "pluma": {"de_y": JIB_Y0, "a_y": JIB_Y1, "de_z": JIB_Z0, "a_z": JIB_Z1, "paneles": JIB_PANELS},
            "contrapluma": {"de_y": CJ_Y0, "a_y": CJ_Y1, "de_z": CJ_Z0, "a_z": CJ_Z1, "bloques": len(CW_LEVELS)},
            "cabina": {"x": [CAB_X0, CAB_X1], "y": [CAB_Y0, CAB_Y1], "z": [CAB_Z0, CAB_Z1]},
            "punta": {"z": APEX_Z},
            "gancho": {"y": HOOK_Y, "bloque_z": BLOCK_Z, "fondo_z": 11.83},
            "lod1_bbox": {"x": round(lod_hi[0] - lod_lo[0], 3), "y": round(lod_hi[1] - lod_lo[1], 3), "z": round(lod_hi[2] - lod_lo[2], 3)},
        },
        "materiales": {
            "crane_amarillo": {"nombre": "amarillo", "hex": "F5C518", "rugosidad": 0.35, "metalico": 0.0},
            "crane_acero": {"nombre": "acero", "hex": "A8AEB4", "rugosidad": 0.25, "metalico": 0.8},
            "crane_asfalto": {"nombre": "asfalto", "hex": "2A2E33", "rugosidad": 0.6, "metalico": 0.0},
            "crane_LOD1": {"nombre": "amarillo", "hex": "F5C518"},
        },
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("GRUA_STATS", json.dumps(stats))

    lod.hide_render = True

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.1))
    ground = bpy.context.active_object
    ground.name = "ground"
    ground.scale = (140.0, 140.0, 0.2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ground.data.materials.append(flat("ground", "8E9196", 0.9))

    avatar = build_avatar(flat("avatar_ref", "5E636A", 0.8))
    for obj in avatar:
        obj.location.y += AVATAR_Y
        obj.hide_render = True
    avatar_lo, avatar_hi = world_bounds(avatar)

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
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 1200
    scene.view_settings.look = "AgX - Medium High Contrast"

    target = ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2)
    front = frame_camera("frontal", (-0.55, -0.78, 0.25), target, (lo, hi))
    render(scene, front, "grua-obra-3-4-frontal.png")
    back = frame_camera("trasera", (0.55, 0.78, 0.25), target, (lo, hi))
    render(scene, back, "grua-obra-3-4-trasero.png")
    for obj in avatar:
        obj.hide_render = False
    profile_bbox_lo = [min(lo[0], avatar_lo[0]), min(lo[1], avatar_lo[1]), min(lo[2], avatar_lo[2])]
    profile_bbox_hi = [max(hi[0], avatar_hi[0]), max(hi[1], avatar_hi[1]), max(hi[2], avatar_hi[2])]
    profile_target = (0.0, (profile_bbox_lo[1] + profile_bbox_hi[1]) / 2, (profile_bbox_lo[2] + profile_bbox_hi[2]) / 2)
    profile_cam = frame_ortho("perfil", (1.0, 0.0, 0.0), profile_target, (profile_bbox_lo, profile_bbox_hi))
    render(scene, profile_cam, "grua-obra-perfil-avatar.png")
    print("GRUA_RENDERS_OK")


if __name__ == "__main__":
    main()

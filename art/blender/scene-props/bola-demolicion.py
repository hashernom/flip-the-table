"""Pieza de escena «bola-demolicion»: grua corta de orugas con pluma de celosia, cadena y bola.

Concepto: una grua de demolicion compacta y de juguete. Orugas anchas con ruedas de apoyo, cubierta de
acero, cabina naranja con ventanas, contrapeso oscuro, pluma de celosia con tirantes, gancho, cadena
colgando de la pluma y bola de hierro fundido al final. Sin marcas, logotipos, texto legible ni nada
del juego original.

Salidas, en art/blender/scene-props/bola-demolicion/:
  wrecking_<material>.fbx   grua, una malla por material (origen en el centro de la base)
  wrecking_ball.fbx         bola de hierro, malla aparte (origen en el gancho, el punto de giro)
  wrecking_chain.fbx        cadena, malla aparte (origen en el gancho, el punto de giro)
  wrecking_LOD1.fbx         una sola malla y un solo material, <= mitad del total
  stats.json                triangulos, medidas y puntos de giro
Y en art/render/scene-props/bola-demolicion/: 3/4 frontal, 3/4 trasero y perfil con avatar de 6 studs.

Convenciones (como art/blender/tokens/taxi.py): 1 unidad de Blender = 1 stud, el frente mira a -Y, Z
hacia arriba, origen en el centro de la base a ras de suelo, exportacion FBX con Z Forward / Y Up.

Uso (segundo plano, sin abrir Blender):
  "D:\\blender\\blender.exe" --background --factory-startup --python art/blender/scene-props/bola-demolicion.py
"""

import glob
import json
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "bola-demolicion")
RENDER = os.path.join(REPO, "art", "render", "scene-props", "bola-demolicion")

TOTAL_BUDGET = 2000
LOD_RATIO = 0.34
MAX_X, MAX_Y, MAX_Z = 10.0, 16.0, 30.0

# Orugas: capsula en el perfil lateral, de lado a lado del vehiculo.
TRACK_X = 3.6          # centro de cada oruga
TRACK_HALF = 0.95      # media anchura de la oruga
TRACK_STRAIGHT = 3.6   # media recta del perfil
TRACK_RADIUS = 1.05    # radio de los extremos (alto total 2,1)
IDLER_Y = (-2.4, 2.4)
IDLER_RADIUS = 0.5

# Base y superestructura.
DECK_SIZE = (5.6, 7.2, 1.5)
DECK_Z = 1.85
TURNTABLE_RADIUS = 1.85
TURNTABLE_Z = 2.95
CAB_SIZE = (4.0, 5.2, 3.4)
CAB_CENTER = (0.0, 1.0, 5.0)
COUNTERWEIGHT_SIZE = (5.0, 1.4, 2.6)
COUNTERWEIGHT_CENTER = (0.0, 4.15, 4.7)

# Pluma: celosia de cuatro cordones entre el pie y la punta. La punta sobresale por delante para que
# la cadena y la bola cuelguen despejadas de la maquina.
BOOM_FOOT = (0.0, -2.1, 3.2)
BOOM_TIP = (0.0, -8.0, 22.8)
BOOM_HALF_W = 0.75
BOOM_HALF_D = 0.40
BOOM_PANELS = 7

# Bola y cadena. Todo cuelga del gancho, que es el punto de giro de las dos mallas.
HOOK = (0.0, -8.0, 21.8)
BALL_RADIUS = 2.4
BALL_CENTER = (0.0, -8.0, 9.6)
CHAIN_LINKS = 7
CHAIN_STEP = 1.2
LINK_HALF_H = 0.855

AVATAR_Y = 8.2
AVATAR_COLOR = "5E636A"


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


def bake(obj):
    select_only(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


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
    """Prisma con el perfil lateral `points` (y, z), de lado a lado de la pieza."""
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


def capsule_points(half_straight, radius, steps=4):
    """Perfil de capsula (y, z) tumbado: recta arriba y abajo y dos extremos redondos."""
    points = []
    for i in range(steps + 1):
        angle = -math.pi / 2 + math.pi * i / steps
        points.append((half_straight + radius * math.cos(angle), radius + radius * math.sin(angle)))
    for i in range(steps + 1):
        angle = math.pi / 2 + math.pi * i / steps
        points.append((-half_straight + radius * math.cos(angle), radius + radius * math.sin(angle)))
    return points


def beam(name, p0, p1, width, depth, mat):
    """Caja de seccion width x depth tendida entre dos puntos."""
    p0, p1 = Vector(p0), Vector(p1)
    direction = p1 - p0
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(p0 + p1) / 2.0)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (width, depth, direction.length)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(mat)
    return obj


def cylinder(name, radius, depth, location, segments, mat, axis="Z"):
    rotation = {
        "Z": (0.0, 0.0, 0.0),
        "X": (0.0, math.radians(90), 0.0),
        "Y": (math.radians(90), 0.0, 0.0),
    }[axis]
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=segments, radius=radius, depth=depth, location=location, rotation=rotation
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
    obj.data.materials.append(mat)
    return obj


def ring(name, centre, major, minor, mat, rotation=(0.0, 0.0, 0.0), scale=(1.0, 1.0, 1.0)):
    """Anillo de 6 x 3 segmentos: 36 triangulos, suficiente para un eslabon o un ojo forjado."""
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major,
        minor_radius=minor,
        major_segments=6,
        minor_segments=3,
        location=(0.0, 0.0, 0.0),
        rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    obj.scale = scale
    obj.location = centre
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj


def join(objects, name, pivot=(0.0, 0.0, 0.0)):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    bpy.context.scene.cursor.location = pivot
    select_only(joined)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return joined


def group_by_material(parts, prefix, pivot=(0.0, 0.0, 0.0)):
    groups = {}
    for part in parts:
        groups.setdefault(part.data.materials[0].name, []).append(part)
    return {material: join(members, f"{prefix}_{material}", pivot) for material, members in groups.items()}


def bounds(objects):
    lo = [1e9, 1e9, 1e9]
    hi = [-1e9, -1e9, -1e9]
    for obj in objects:
        matrix = obj.matrix_world
        for vertex in obj.data.vertices:
            point = matrix @ vertex.co
            for i in range(3):
                lo[i] = min(lo[i], point[i])
                hi[i] = max(hi[i], point[i])
    return lo, hi


def count(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def build_tracks(mats):
    parts = []
    for side in (-1, 1):
        track = profile("track", capsule_points(TRACK_STRAIGHT, TRACK_RADIUS), TRACK_HALF, mats["dark"])
        track.location = (side * TRACK_X, 0.0, 0.0)
        parts.append(bake(track))
        for y in IDLER_Y:
            parts.append(
                cylinder(
                    "idler",
                    IDLER_RADIUS,
                    0.14,
                    (side * (TRACK_X + TRACK_HALF + 0.04), y, 0.95),
                    6,
                    mats["steel"],
                    "X",
                )
            )
    return parts


def build_chassis(mats):
    parts = [bevel(box("deck", DECK_SIZE, (0.0, 0.0, DECK_Z), mats["steel"]), 0.12)]
    parts.append(cylinder("turntable", TURNTABLE_RADIUS, 0.7, (0.0, 0.0, TURNTABLE_Z), 12, mats["dark"]))
    parts.append(bevel(box("cab", CAB_SIZE, CAB_CENTER, mats["orange"]), 0.3))
    parts.append(box("window_front", (3.0, 0.10, 1.5), (0.0, -1.62, 5.45), mats["glass"]))
    for side in (-1, 1):
        parts.append(box("window_side", (0.10, 2.6, 1.25), (side * 2.02, 0.9, 5.4), mats["glass"]))
    parts.append(bevel(box("counterweight", COUNTERWEIGHT_SIZE, COUNTERWEIGHT_CENTER, mats["dark"]), 0.18))
    parts.append(cylinder("bracket", 0.34, 1.6, (0.0, -1.9, 2.9), 8, mats["steel"], "Z"))
    return parts


def build_boom(mats):
    foot, tip = Vector(BOOM_FOOT), Vector(BOOM_TIP)
    axis = (tip - foot).normalized()
    across = Vector((0.0, -axis.z, axis.y))  # perpendicular en el plano YZ, hacia delante
    parts = []

    # Cuatro cordones: dos a cada lado, uno delante y otro detras.
    for sx in (-1, 1):
        for sd in (-1, 1):
            offset = Vector((sx * BOOM_HALF_W, 0.0, 0.0)) + across * (sd * BOOM_HALF_D)
            parts.append(beam("chord", foot + offset, tip + offset, 0.30, 0.30, mats["steel"]))

    stations = [foot.lerp(tip, i / BOOM_PANELS) for i in range(BOOM_PANELS + 1)]

    # Celosia: diagonales alternas en los dos costados, del cordon de delante al de detras.
    for i in range(BOOM_PANELS):
        sign = 1 if i % 2 == 0 else -1
        for sx in (-1, 1):
            p0 = stations[i] + Vector((sx * BOOM_HALF_W, 0.0, 0.0)) + across * (sign * BOOM_HALF_D)
            p1 = stations[i + 1] + Vector((sx * BOOM_HALF_W, 0.0, 0.0)) - across * (sign * BOOM_HALF_D)
            parts.append(beam("brace", p0, p1, 0.14, 0.14, mats["steel"]))

    # Cabecera, polea, gancho y pestanas.
    parts.append(box("boom_head", (1.6, 0.95, 0.9), (0.0, tip.y, tip.z), mats["steel"]))
    for side in (-1, 1):
        parts.append(box("cheek", (0.12, 0.8, 1.0), (side * 0.52, tip.y, tip.z + 0.35), mats["dark"]))
    parts.append(cylinder("sheave", 0.40, 0.86, (0.0, tip.y, tip.z + 0.35), 10, mats["steel"], "X"))
    parts.append(box("hook_block", (0.60, 0.50, 0.60), (0.0, tip.y, tip.z - 0.65), mats["steel"]))
    parts.append(
        ring("shackle", (0.0, tip.y, tip.z - 1.00), 0.22, 0.07, mats["steel"], (math.radians(90), 0.0, 0.0))
    )

    # Tirantes: caballete sobre la cabina y dos cables hasta la punta de la pluma.
    top = Vector((0.0, 0.9, 9.3))
    for side in (-1, 1):
        parts.append(
            beam("gantry", (side * 0.42, 2.6, 6.6), top + Vector((side * 0.42, 0.0, 0.0)), 0.18, 0.18, mats["steel"])
        )
    for side in (-1, 1):
        parts.append(beam("pendant", top + Vector((side * 0.42, 0.0, 0.0)), (side * 0.3, tip.y, tip.z + 0.5), 0.09, 0.09, mats["dark"]))
    return parts


def build_ball(mats):
    parts = []
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=BALL_RADIUS, location=BALL_CENTER)
    sphere = bpy.context.active_object
    sphere.name = "ball"
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    sphere.data.materials.append(mats["iron"])
    parts.append(sphere)
    top = BALL_CENTER[2] + BALL_RADIUS
    parts.append(cylinder("ball_neck", 0.42, 0.7, (BALL_CENTER[0], BALL_CENTER[1], top + 0.15), 8, mats["iron"], "Z"))
    parts.append(
        ring(
            "ball_eye",
            (BALL_CENTER[0], BALL_CENTER[1], top + 0.75),
            0.34,
            0.09,
            mats["iron"],
            (math.radians(90), 0.0, 0.0),
        )
    )
    return parts


def build_chain(mats):
    parts = []
    for i in range(CHAIN_LINKS):
        z = HOOK[2] - 0.82 - i * CHAIN_STEP
        parts.append(
            ring(
                "link",
                (HOOK[0], HOOK[1], z),
                0.5,
                0.09,
                mats["steel"],
                (math.radians(90), 0.0, math.radians(90) if i % 2 else 0.0),
                (0.52, 1.0, 1.45),
            )
        )
    return parts


def lod_copy(source, material, ratio=LOD_RATIO):
    copy = source.copy()
    copy.data = source.data.copy()
    copy.name = f"{source.name}_lod"
    bpy.context.collection.objects.link(copy)
    select_only(copy)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    copy.data.materials.clear()
    copy.data.materials.append(material)
    decimate = copy.modifiers.new("Decimate", "DECIMATE")
    decimate.ratio = ratio
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
        "steel": flat("steel", "A8AEB4", 0.28, 0.8),
        "dark": flat("dark", "23272C", 0.65, 0.15),
        "orange": flat("orange", "E07A3C", 0.5, 0.1),
        "glass": flat("glass", "7FB2D9", 0.12, 0.0),
        "iron": flat("iron", "525860", 0.44, 0.55),
        "ground": flat("ground", "8E9196", 0.9),
    }

    tracks = build_tracks(mats)
    crane_parts = tracks + build_chassis(mats) + build_boom(mats)
    ball_parts = build_ball(mats)
    chain_parts = build_chain(mats)

    # La base tiene que quedar centrada en el origen: el centro de su caja es (0, 0), a ras de suelo.
    base_lo, base_hi = bounds(tracks)
    base_center = [(base_lo[i] + base_hi[i]) / 2.0 for i in range(2)]

    crane = group_by_material(crane_parts, "wrecking", (0.0, 0.0, 0.0))
    ball = join(ball_parts, "wrecking_ball", HOOK)
    chain = join(chain_parts, "wrecking_chain", HOOK)

    pieces = [*crane.values(), ball, chain]
    lo, hi = bounds(pieces)
    width, length, height = hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]
    pivot = Vector(HOOK)
    ball_lo, ball_hi = bounds([ball])
    chain_lo, chain_hi = bounds([chain])

    # Comprobaciones antes de exportar.
    assert abs(base_center[0]) < 1e-6 and abs(base_center[1]) < 1e-6, f"base descentrada: {base_center}"
    assert abs(lo[2]) < 1e-6, f"min_z = {lo[2]:.4f}, la pieza no apoya en el suelo"
    assert width <= MAX_X + 1e-6, f"ancho {width:.2f} por encima de {MAX_X}"
    assert length <= MAX_Y + 1e-6, f"largo {length:.2f} por encima de {MAX_Y}"
    assert height <= MAX_Z + 1e-6, f"alto {height:.2f} por encima de {MAX_Z}"
    for obj in pieces:
        assert len(obj.data.materials) == 1, f"{obj.name} tiene varios materiales"
        select_only(obj)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.delete_loose()
        bpy.ops.object.mode_set(mode="OBJECT")
    for piece, label in ((ball, "bola"), (chain, "cadena")):
        origin = Vector(piece.matrix_world.translation)
        assert (origin - pivot).length < 1e-6, f"el origen de la {label} no esta en el gancho"
    assert ball_hi[2] < pivot.z - 1.0, "la bola no cuelga por debajo del gancho"
    assert chain_hi[2] <= pivot.z + 0.4 and chain_lo[2] <= ball_hi[2] + 1.0, "la cadena no llega del gancho a la bola"
    assert chain_lo[2] > ball_lo[2], "la cadena atraviesa la bola"
    assert max(hi[0], -lo[0]) < MAX_X / 2.0, "la bola se sale de la anchura"

    # LOD1: una sola malla con un solo material, reducida. La cadena se sustituye por una barra.
    lod_parts = [lod_copy(obj, mats["steel"]) for obj in [*crane.values(), ball]]
    lod_parts.append(beam("lod_chain", (HOOK[0], HOOK[1], HOOK[2]), (HOOK[0], HOOK[1], ball_hi[2]), 0.2, 0.2, mats["steel"]))
    lod = join(lod_parts, "wrecking_LOD1", (0.0, 0.0, 0.0))
    select_only(lod)
    bpy.ops.object.material_slot_remove_unused()
    assert len(lod.data.materials) == 1, "el LOD1 tiene mas de un material"

    files = {}
    for obj in crane.values():
        export(obj, f"{obj.name}.fbx")
        files[obj.name] = count(obj)
    export(ball, "wrecking_ball.fbx")
    files["wrecking_ball"] = count(ball)
    export(chain, "wrecking_chain.fbx")
    files["wrecking_chain"] = count(chain)
    export(lod, "wrecking_LOD1.fbx")

    total = sum(files.values())
    lod_triangles = count(lod)
    assert total <= TOTAL_BUDGET, f"{total} triangulos, por encima de {TOTAL_BUDGET}"
    assert lod_triangles <= total / 2, f"LOD1 con {lod_triangles}, mas de la mitad de {total}"

    def roblox(point):
        return [round(point[0], 4), round(point[2], 4), round(point[1], 4)]

    stats = {
        "modelo": "bola-demolicion",
        "unidades": "studs (1 unidad de Blender = 1 stud)",
        "origen": "centro de la base, a ras de suelo (x = 0, y = 0, z = 0)",
        "frente": "-Y (pluma y bola)",
        "arriba": "+Z",
        "triangulos": {
            "piezas": files,
            "total": total,
            "lod1": lod_triangles,
            "lod1_porcentaje_del_total": round(100 * lod_triangles / total, 1),
            "lod1_mitad_del_total": round(total / 2, 1),
            "presupuesto_total": TOTAL_BUDGET,
        },
        "medidas": {
            "ancho_x": round(width, 3),
            "largo_y": round(length, 3),
            "alto_z": round(height, 3),
            "min_z": round(lo[2], 4),
            "maximos": {"ancho_x": MAX_X, "largo_y": MAX_Y, "alto_z": MAX_Z},
        },
        "puntos_de_giro": {
            "gancho": {
                "posicion_blender": [round(c, 4) for c in HOOK],
                "posicion_roblox": roblox(HOOK),
                "giro": "X (balanceo en el plano YZ de Blender / ZY de Roblox)",
            },
            "bola": {
                "archivo": "wrecking_ball.fbx",
                "origen_blender": [round(c, 4) for c in HOOK],
                "centro_caja_blender": [round((ball_lo[i] + ball_hi[i]) / 2.0, 4) for i in range(3)],
                "offset_caja_desde_gancho": [
                    round((ball_lo[i] + ball_hi[i]) / 2.0 - HOOK[i], 4) for i in range(3)
                ],
                "radio": BALL_RADIUS,
            },
            "cadena": {
                "archivo": "wrecking_chain.fbx",
                "origen_blender": [round(c, 4) for c in HOOK],
                "centro_caja_blender": [round((chain_lo[i] + chain_hi[i]) / 2.0, 4) for i in range(3)],
                "offset_caja_desde_gancho": [
                    round((chain_lo[i] + chain_hi[i]) / 2.0 - HOOK[i], 4) for i in range(3)
                ],
                "eslabones": CHAIN_LINKS,
                "paso": CHAIN_STEP,
                "de_z": round(chain_lo[2], 3),
                "a_z": round(chain_hi[2], 3),
            },
        },
        "pluma": {
            "pie_blender": [round(c, 4) for c in BOOM_FOOT],
            "punta_blender": [round(c, 4) for c in BOOM_TIP],
            "paneles": BOOM_PANELS,
        },
        "materiales": {obj.name: obj.data.materials[0].name for obj in [*crane.values(), ball, chain]},
        "materiales_lod1": ["steel"],
        "nota_roblox": (
            "Como el taxi: Roblox carga cada FBX con el pivote en el centro de su caja. La bola y la "
            "cadena llegan a su sitio, pero su pivote queda en el centro de la caja, no en el gancho: "
            "para el balanceo hay que poner PivotOffset (o un Attachment) en el gancho con el offset "
            "de stats.puntos_de_giro."
        ),
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("BOLA_DEMOLICION_STATS", json.dumps(stats))

    # Escena de render: la pieza se queda donde esta; el LOD no se renderiza.
    lod.hide_render = True

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.1))
    ground = bpy.context.active_object
    ground.name = "ground"
    ground.scale = (90.0, 90.0, 0.2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ground.data.materials.append(mats["ground"])

    avatar = build_avatar(flat("avatar_ref", AVATAR_COLOR, 0.8))
    for obj in avatar:
        obj.location.y += AVATAR_Y
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
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 1400
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass

    target = (0.0, -3.5, 11.6)
    render(scene, camera("frontal", (-38.0, -31.0, 18.0), target, lens=48), "bola-demolicion-3-4-frontal.png")
    render(scene, camera("trasera", (38.0, 26.0, 19.0), (0.0, -2.5, 11.2), lens=48), "bola-demolicion-3-4-trasero.png")
    for obj in avatar:
        obj.hide_render = False
    render(
        scene,
        camera("perfil", (60.0, 0.0, 11.8), (0.0, -0.5, 11.8), ortho_scale=32.0),
        "bola-demolicion-perfil-avatar.png",
    )
    print("BOLA_DEMOLICION_RENDERS_OK")


if __name__ == "__main__":
    main()

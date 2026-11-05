"""Pieza de escena casco-obra: el casco de obra amarillo de Flip the Table.

Casco de juguete, caricaturesco: campana ovalada con hombro marcado, visera curva que abraza el
frente y forro oscuro en la base que lo separa de la cabeza. Se apoya sobre la cabeza de un avatar,
asi que el origen va en el centro de la base, donde apoya, con el mismo convenio que la gorra de
policia (art/blender/slice/build_arrest_props.py). Frente en -Y, arriba +Z. Sin marcas, logotipos,
texto legible ni nada de Monopoly.

Salidas, en art/blender/scene-props/casco-obra/:
  helmet_yellow.fbx   campana y visera, una malla y un material (origen en el centro de la base)
  helmet_dark.fbx     forro de la base, una malla y un material, mismo origen
  helmet_LOD1.fbx     una sola malla y un material, como maximo la mitad de triangulos
  stats.json          triangulos por pieza, total y LOD1, medidas y puntos de giro
Y en art/render/scene-props/casco-obra/: 3/4 frontal, 3/4 trasero y perfil con avatar de 6 studs.

Convenciones (las de taxi.py): 1 unidad de Blender = 1 stud, frente en -Y, Z hacia arriba, origen
en el centro de la base a ras de suelo, exportacion FBX con Z Forward / Y Up.
Medidas maximas: radio 1,25 en la base, alto 0,70 y la visera sobresale 1,00 como maximo hacia -Y.

Uso (segundo plano, sin abrir Blender):
  "D:\\blender\\blender.exe" --background --factory-startup --python art/blender/scene-props/casco-obra.py
"""

import glob
import json
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "casco-obra")
RENDER = os.path.join(REPO, "art", "render", "scene-props", "casco-obra")

TRI_MAX = 300
RADIO_MAX = 1.25
ALTO_MAX = 0.70
VISERA_MAX = 1.00
LOD_RATIO = 0.45

# Forro oscuro de la base: el aro donde apoya el casco sobre la cabeza (rx, ry) y su altura.
BAND = (1.10, 1.23)
BAND_Z = (0.0, 0.10)
BAND_SEGMENTS = 12

# Campana: anillos elipticos (rx, ry, z) de abajo arriba y la coronilla (y, z). Es mas larga que
# ancha, como un casco de verdad, y el ultimo anillo se estira en Y para dejar una cresta suave.
DOME_SEGMENTS = 14
DOME_RINGS = (
    (1.08, 1.21, 0.10),
    (1.12, 1.25, 0.22),
    (1.06, 1.18, 0.34),
    (0.96, 1.07, 0.45),
    (0.80, 0.89, 0.55),
    (0.52, 0.64, 0.632),
)
DOME_TOP = (0.0, 0.695)

# Visera: arco que abraza el frente (-Y) y muere en los costados. Las elipses interior y exterior
# son (rx, ry); la exterior es la que da la punta hacia -Y.
BRIM_STATIONS = 9
BRIM_ARC = 78.0
BRIM_INNER = (1.00, 1.115)
BRIM_OUTER = (1.14, 1.90)
BRIM_Z = 0.245
BRIM_DROP = 0.095  # cuanto baja el borde delantero respecto del interior
BRIM_THICK_IN = 0.10
BRIM_THICK_OUT = 0.06

YELLOW = "F5C518"
DARK = "2A2E33"


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


def finish(obj, name):
    """Nombre y origen en el centro de la base: la geometria ya esta en coordenadas del modelo."""
    obj.name = name
    obj.data.name = name
    select_only(obj)
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return obj


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    return finish(bpy.context.active_object, name)


def ellipse(rx, ry, z, segments):
    step = 2.0 * math.pi / segments
    return [(rx * math.cos(i * step), ry * math.sin(i * step), z) for i in range(segments)]


def dome(name, mat):
    """Campana: anillos elipticos cosidos y cerrada con un abanico en la coronilla y otro en la base."""
    verts, faces = [], []
    for rx, ry, z in DOME_RINGS:
        verts.extend(ellipse(rx, ry, z, DOME_SEGMENTS))
    apex = len(verts)
    verts.append((0.0, DOME_TOP[0], DOME_TOP[1]))
    last = (len(DOME_RINGS) - 1) * DOME_SEGMENTS
    for k in range(len(DOME_RINGS) - 1):
        for i in range(DOME_SEGMENTS):
            a = k * DOME_SEGMENTS + i
            b = k * DOME_SEGMENTS + (i + 1) % DOME_SEGMENTS
            faces.append((a, b, b + DOME_SEGMENTS, a + DOME_SEGMENTS))
    for i in range(DOME_SEGMENTS):
        faces.append((last + i, last + (i + 1) % DOME_SEGMENTS, apex))
    base = len(verts)
    verts.append((0.0, 0.0, DOME_RINGS[0][2]))
    for i in range(DOME_SEGMENTS):
        faces.append((base, (i + 1) % DOME_SEGMENTS, i))
    return mesh_object(name, verts, faces, mat)


def brim(name, mat):
    """Visera: seccion barrida por un arco del frente, mas fina y mas baja cuanto mas hacia la punta."""
    stations = []
    for k in range(BRIM_STATIONS):
        angle = math.radians(-BRIM_ARC + 2.0 * BRIM_ARC * k / (BRIM_STATIONS - 1))
        sin, cos = math.sin(angle), math.cos(angle)
        far = cos * cos  # 1 en el frente, 0 en los costados
        ix, iy = BRIM_INNER[0] * sin, -BRIM_INNER[1] * cos
        ox, oy = BRIM_OUTER[0] * sin, -BRIM_OUTER[1] * cos
        outer_z = BRIM_Z - BRIM_DROP * far
        outer_thick = BRIM_THICK_IN + (BRIM_THICK_OUT - BRIM_THICK_IN) * far
        stations.append(
            [
                (ix, iy, BRIM_Z),
                (ox, oy, outer_z),
                (ox, oy, outer_z - outer_thick),
                (ix, iy, BRIM_Z - BRIM_THICK_IN),
            ]
        )
    verts = [point for station in stations for point in station]
    faces = []
    for k in range(len(stations) - 1):
        a, b = 4 * k, 4 * (k + 1)
        faces += [
            (a + 0, a + 1, b + 1, b + 0),
            (a + 1, a + 2, b + 2, b + 1),
            (a + 2, a + 3, b + 3, b + 2),
            (a + 3, a + 0, b + 0, b + 3),
        ]
    faces.append((0, 3, 2, 1))
    last = 4 * (len(stations) - 1)
    faces.append((last + 0, last + 1, last + 2, last + 3))
    return mesh_object(name, verts, faces, mat)


def band(name, mat):
    """Forro de la base: cilindro eliptico cerrado, con su tapa superior como reborde visible."""
    verts = ellipse(BAND[0], BAND[1], BAND_Z[0], BAND_SEGMENTS)
    verts += ellipse(BAND[0], BAND[1], BAND_Z[1], BAND_SEGMENTS)
    bottom = len(verts)
    verts.append((0.0, 0.0, BAND_Z[0]))
    top = len(verts)
    verts.append((0.0, 0.0, BAND_Z[1]))
    faces = []
    for i in range(BAND_SEGMENTS):
        j = (i + 1) % BAND_SEGMENTS
        faces.append((i, j, BAND_SEGMENTS + j, BAND_SEGMENTS + i))
        faces.append((bottom, j, i))
        faces.append((top, BAND_SEGMENTS + i, BAND_SEGMENTS + j))
    return mesh_object(name, verts, faces, mat)


def count(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


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


def center(lo, hi):
    return [round((lo[i] + hi[i]) / 2.0, 4) for i in range(3)]


def lod_copy(source, material):
    copy = source.copy()
    copy.data = source.data.copy()
    copy.name = f"{source.name}_lod"
    bpy.context.collection.objects.link(copy)
    decimate = copy.modifiers.new("Decimate", "DECIMATE")
    decimate.ratio = LOD_RATIO
    apply_modifiers(copy)
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


def cuboid(name, size, location, mat):
    """Caja para la figura de referencia del render; no se exporta."""
    half = [value / 2.0 for value in size]
    verts = [
        (location[0] + i * half[0], location[1] + j * half[1], location[2] + k * half[2])
        for i in (-1, 1)
        for j in (-1, 1)
        for k in (-1, 1)
    ]
    faces = [
        (0, 1, 3, 2),
        (4, 6, 7, 5),
        (0, 4, 5, 1),
        (2, 3, 7, 6),
        (0, 2, 6, 4),
        (1, 5, 7, 3),
    ]
    return mesh_object(name, verts, faces, mat)


def build_avatar(mat):
    """Silueta de 6 studs de alto, de pie sobre el suelo (no es un asset del juego)."""
    parts = [
        cuboid("av_leg_l", (0.8, 0.9, 2.5), (-0.5, 0, 1.25), mat),
        cuboid("av_leg_r", (0.8, 0.9, 2.5), (0.5, 0, 1.25), mat),
        cuboid("av_torso", (2.0, 1.0, 1.9), (0, 0, 3.45), mat),
        cuboid("av_arm_l", (0.6, 0.6, 1.9), (-1.3, 0, 3.5), mat),
        cuboid("av_arm_r", (0.6, 0.6, 1.9), (1.3, 0, 3.5), mat),
    ]
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.8, location=(0, 0, 5.2))
    head = bpy.context.active_object
    head.name = "av_head"
    head.data.materials.append(mat)
    parts.append(head)
    return parts


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


def render(scene, cam, name, width, height):
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.camera = cam
    scene.render.filepath = os.path.join(RENDER, name)
    bpy.ops.render.render(write_still=True)


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
        "yellow": flat("yellow", YELLOW, 0.7),
        "dark": flat("dark", DARK, 0.6),
        "ground": flat("ground", "8E9196", 0.9),
        "avatar": flat("avatar_ref", "5E636A", 0.8),
    }

    # Piezas: una malla por material, las dos con el origen en el centro de la base.
    dome_obj = dome("dome", mats["yellow"])
    brim_obj = brim("brim", mats["yellow"])
    dome_lo, dome_hi = bounds([(dome_obj, (0.0, 0.0, 0.0))])
    brim_lo, brim_hi = bounds([(brim_obj, (0.0, 0.0, 0.0))])
    helmet_yellow = join([dome_obj, brim_obj], "helmet_yellow")
    helmet_dark = finish(band("band", mats["dark"]), "helmet_dark")
    pieces = [helmet_yellow, helmet_dark]

    for obj in pieces:
        assert len(obj.data.materials) == 1, f"{obj.name} tiene varios materiales"
        assert obj.location.length < 1e-9, f"{obj.name} no tiene el origen en la base"

    # Medidas reales antes de exportar.
    lo, hi = bounds([(obj, (0.0, 0.0, 0.0)) for obj in pieces])
    band_lo, band_hi = bounds([(helmet_dark, (0.0, 0.0, 0.0))])
    assert abs(lo[2]) < 1e-9, f"min_z = {lo[2]}, el casco no apoya a ras de suelo"
    assert abs(center(band_lo, band_hi)[0]) < 1e-9 and abs(center(band_lo, band_hi)[1]) < 1e-9, (
        "la base no esta centrada en el origen"
    )
    assert band_hi[0] <= RADIO_MAX + 1e-9 and band_hi[1] <= RADIO_MAX + 1e-9, "la base pasa de radio 1,25"
    assert hi[2] <= ALTO_MAX + 1e-9, f"alto {hi[2]:.3f} por encima de {ALTO_MAX}"
    assert abs(lo[1] + BRIM_OUTER[1]) < 1e-6, "la visera no acaba donde dice la constante"
    assert -lo[1] - band_hi[1] <= VISERA_MAX + 1e-9, "la visera sobresale mas de 1,00"

    lod = join([lod_copy(obj, mats["yellow"]) for obj in pieces], "helmet_LOD1")
    select_only(lod)
    bpy.ops.object.material_slot_remove_unused()
    assert len(lod.data.materials) == 1, "el LOD1 tiene mas de un material"

    files = {}
    for obj in pieces + [lod]:
        export(obj, f"{obj.name}.fbx")
        files[obj.name] = count(obj)
    total = files["helmet_yellow"] + files["helmet_dark"]
    lod_triangles = files["helmet_LOD1"]
    assert total <= TRI_MAX, f"{total} triangulos, por encima de {TRI_MAX}"
    assert lod_triangles <= total / 2, f"LOD1 con {lod_triangles}, mas de la mitad de {total}"

    stats = {
        "modelo": "casco-obra",
        "unidades": "studs (1 unidad de Blender = 1 stud)",
        "origen": "centro de la base, donde apoya sobre la cabeza (x = 0, y = 0, z = 0)",
        "frente": "-Y (visera)",
        "arriba": "+Z",
        "triangulos": {
            "piezas": files,
            "total": total,
            "lod1": lod_triangles,
            "lod1_mitad_del_total": round(total / 2, 1),
            "presupuesto_total": TRI_MAX,
        },
        "medidas": {
            "ancho_x": round(hi[0] - lo[0], 3),
            "largo_y": round(hi[1] - lo[1], 3),
            "alto_z": round(hi[2] - lo[2], 3),
            "min_z": round(lo[2], 4),
            "max_z": round(hi[2], 3),
            "campana": {
                "radio_x": round(dome_hi[0], 3),
                "radio_y": round(dome_hi[1], 3),
                "altura_z": round(dome_hi[2], 3),
                "coronilla": {"y": DOME_TOP[0], "z": DOME_TOP[1]},
            },
            "base": {
                "radio_x": BAND[0],
                "radio_y": BAND[1],
                "altura_z": round(BAND_Z[1] - BAND_Z[0], 3),
                "centro": center(band_lo, band_hi)[:2],
            },
            "visera": {
                "punta_y": round(lo[1], 3),
                "sobresale": round(-lo[1] - band_hi[1], 3),
                "ancho_x": round(brim_hi[0] - brim_lo[0], 3),
                "z_inferior": round(brim_lo[2], 3),
                "z_superior": round(brim_hi[2], 3),
                "abre_grados": BRIM_ARC,
            },
            "maximos": {"radio": RADIO_MAX, "alto": ALTO_MAX, "visera": VISERA_MAX},
        },
        "puntos_de_giro": {
            "origen": [0.0, 0.0, 0.0],
            "apoyo_cabeza": [0.0, 0.0, 0.0],
            "eje_vertical": "Z",
            "centros_de_caja_blender": {obj.name: center(*bounds([(obj, (0.0, 0.0, 0.0))])) for obj in pieces + [lod]},
        },
        "materiales": {
            helmet_yellow.name: "yellow",
            helmet_dark.name: "dark",
            lod.name: "yellow",
        },
        "colores": {"yellow": YELLOW, "dark": DARK},
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("CASCO_STATS", json.dumps(stats))

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
        obj.location.y += 2.6
        obj.hide_render = True

    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 3.0
    sun_data.angle = math.radians(1.0)
    sun = bpy.data.objects.new("sun", sun_data)
    bpy.context.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(90 - 42), 0, math.radians(30))

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.5, 0.5, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world

    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.view_settings.look = "AgX - Medium High Contrast"

    render(scene, camera("frontal", (-4.6, -5.53, 4.35), (0.0, -0.25, 0.32), lens=62), "casco-obra-3-4-frontal.png", 1400, 900)
    render(scene, camera("trasera", (4.6, 5.53, 4.35), (0.0, 0.30, 0.32), lens=62), "casco-obra-3-4-trasero.png", 1400, 900)
    for obj in avatar:
        obj.hide_render = False
    render(
        scene,
        camera("perfil", (60.0, 0.75, 3.15), (0.0, 0.75, 3.15), ortho_scale=8.6),
        "casco-obra-perfil-avatar.png",
        1200,
        900,
    )
    print("CASCO_RENDERS_OK")


if __name__ == "__main__":
    main()

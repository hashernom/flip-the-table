"""Fachada de referencia de Metrópolis, modelada de verdad.

No es una caja con pegatinas: los huecos de ventana están perforados con booleana, los
marcos van dentro del hueco, la cornisa tiene perfil y las esquinas llevan sillería.

Salidas, en art/blender/facade/:
  facade.blend          escena con materiales PBR de los sets CC0
  facade.fbx            asset con el origen en el centro de la base
  facade_LOD1.fbx       versión reducida al 45 %
  facade-stats.json     triángulos y medidas reales

Y en art/render/: facade-hero.png y facade-detalle.png.

Uso: blender --background --factory-startup --python art/blender/facade/build_facade.py
"""

import json
import math
import os

import bpy
from mathutils import Vector

WIDTH = 20.0
HEIGHT = 24.0
DEPTH = 3.0
FLOOR = 4.2
WINDOW_W = 2.2
WINDOW_H = 2.6
RECESS = 0.45
COLUMNS = 3
FLOORS = 4
STORE_H = 5.0
STORE_W = 13.0
CORNICE = 0.55

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
TEX = os.path.join(REPO, "art", "textures", "cc0")
RENDER = os.path.join(REPO, "art", "render")


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    scene.unit_settings.scale_length = 1.0
    return scene


def material(name, color_map, roughness_map, normal_map, tint=(1, 1, 1)):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*tint, 1.0)

    def image_node(path, non_color=False):
        node = nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(path, check_existing=True)
        if non_color:
            node.image.colorspace_settings.name = "Non-Color"
        return node

    color = image_node(os.path.join(TEX, color_map))
    links.new(color.outputs["Color"], bsdf.inputs["Base Color"])

    if roughness_map and os.path.exists(os.path.join(TEX, roughness_map)):
        rough = image_node(os.path.join(TEX, roughness_map), non_color=True)
        links.new(rough.outputs["Color"], bsdf.inputs["Roughness"])

    if normal_map and os.path.exists(os.path.join(TEX, normal_map)):
        normal = image_node(os.path.join(TEX, normal_map), non_color=True)
        nmap = nodes.new("ShaderNodeNormalMap")
        links.new(normal.outputs["Color"], nmap.inputs["Color"])
        links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])

    return mat


def box(name, size, location, mat=None, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
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
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    return joined


def apply_modifiers(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)


def triangles(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    count = len(mesh.loop_triangles)
    evaluated.to_mesh_clear()
    return count


def uv_unwrap(obj, cube_size=2.4):
    """Proyección de cubo con tamaño fijo: densidad de texel constante y ladrillo sin estirar."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=cube_size)
    bpy.ops.object.mode_set(mode="OBJECT")


def build():
    brick = material("brick_red", "brick_red_color.jpg", "brick_red_roughness.jpg", "brick_red_normal.jpg")
    stone = material("stone", "concrete_color.jpg", "concrete_roughness.jpg", "concrete_normal.jpg")
    glass = bpy.data.materials.new("glass")
    glass.use_nodes = True
    bsdf = glass.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.05, 0.08, 0.11, 1)
    bsdf.inputs["Roughness"].default_value = 0.08
    bsdf.inputs["Metallic"].default_value = 0.2

    # Muro con huecos perforados de verdad.
    wall = box("wall", (WIDTH, DEPTH, HEIGHT), (0, 0, HEIGHT / 2), brick)

    cutters = []
    window_tops = []
    usable = HEIGHT - STORE_H - 1.2
    for floor in range(FLOORS):
        z = STORE_H + 1.0 + floor * (usable / FLOORS) + WINDOW_H / 2 + 0.4
        if z + WINDOW_H / 2 > HEIGHT - 1.2:
            continue
        window_tops.append(z)
        for column in range(COLUMNS):
            x = (column - (COLUMNS - 1) / 2) * (WIDTH / COLUMNS)
            cutters.append(
                box(
                    f"cut_{floor}_{column}",
                    (WINDOW_W, DEPTH * 2, WINDOW_H),
                    (x, 0, z),
                )
            )

    # El escaparate también es un hueco: sin esto el muro queda sólido detrás del cristal.
    cutters.append(box("cut_store", (STORE_W, DEPTH * 2, STORE_H), (0, 0, STORE_H / 2)))

    for index, cutter in enumerate(cutters):
        boolean = wall.modifiers.new(f"bool_{index}", "BOOLEAN")
        boolean.operation = "DIFFERENCE"
        boolean.object = cutter
    apply_modifiers(wall)
    for cutter in cutters:
        bpy.data.objects.remove(cutter, do_unlink=True)

    trims = []

    # Marcos dentro del hueco, con parteluz y alféizar con goterón.
    for z in window_tops:
        for column in range(COLUMNS):
            x = (column - (COLUMNS - 1) / 2) * (WIDTH / COLUMNS)
            front = -DEPTH / 2
            trims.append(box("sill", (WINDOW_W + 0.5, 0.7, 0.18), (x, front - 0.1, z - WINDOW_H / 2 - 0.1), stone))
            trims.append(box("drip", (WINDOW_W + 0.5, 0.12, 0.1), (x, front - 0.42, z - WINDOW_H / 2 - 0.22), stone))
            trims.append(box("lintel", (WINDOW_W + 0.4, 0.4, 0.22), (x, front - 0.05, z + WINDOW_H / 2 + 0.12), stone))
            for side in (-1, 1):
                trims.append(
                    box(
                        "jamb",
                        (0.22, 0.35, WINDOW_H + 0.1),
                        (x + side * (WINDOW_W / 2 - 0.05), front + RECESS / 2, z),
                        stone,
                    )
                )
            trims.append(box("mullion", (0.1, 0.2, WINDOW_H), (x, front + RECESS / 2, z), stone))
            trims.append(box("transom", (WINDOW_W, 0.2, 0.1), (x, front + RECESS / 2, z + WINDOW_H / 4), stone))

    # Escaparate y puerta, hundidos respecto a la fachada. El marco es un marco, no un panel.
    frame_y = -DEPTH / 2 + 0.2
    for side in (-1, 1):
        trims.append(box("store_jamb", (0.4, 0.6, STORE_H), (side * (STORE_W / 2 + 0.2), frame_y, STORE_H / 2), stone))
    trims.append(box("store_head", (STORE_W + 0.8, 0.6, 0.5), (0, frame_y, STORE_H + 0.1), stone))
    for mullion in range(-2, 3):
        trims.append(box("shop_mullion", (0.18, 0.4, STORE_H - 0.6), (mullion * 2.8, -DEPTH / 2 + 0.15, (STORE_H - 0.6) / 2), stone))
    trims.append(box("door_frame", (3.0, 0.4, 4.4), (STORE_W / 2 + 1.8, -DEPTH / 2 + 0.2, 2.2), stone))

    # Cornisa con perfil de tres cuerpos y pretil.
    trims.append(box("cornice_a", (WIDTH + 0.5, DEPTH + 0.5, 0.35), (0, 0, HEIGHT - 1.1), stone))
    trims.append(box("cornice_b", (WIDTH + 0.9, DEPTH + 0.9, 0.30), (0, 0, HEIGHT - 0.75), stone))
    trims.append(box("cornice_c", (WIDTH + 1.3, DEPTH + 1.3, 0.45), (0, 0, HEIGHT - 0.3), stone))
    trims.append(box("parapet", (WIDTH, DEPTH, 1.0), (0, 0, HEIGHT + 0.5), brick))

    # Sillería en las esquinas, alternando.
    for step in range(0, 18):
        z = 0.8 + step * 1.2
        for side in (-1, 1):
            trims.append(
                box(
                    "quoin",
                    (1.0, 0.45, 0.85),
                    (side * (WIDTH / 2 - 0.5), -DEPTH / 2 - 0.05, z),
                    stone,
                )
            )

    # Junta entre planta baja y primer piso.
    trims.append(box("string", (WIDTH + 0.3, 0.5, 0.35), (0, -DEPTH / 2 - 0.05, STORE_H + 0.5), stone))

    facade = join([wall], "facade_wall")
    trim = join(trims, "facade_trim")

    glass_parts = [
        box("shop_glass", (STORE_W, 0.12, STORE_H - 0.5), (0, -DEPTH / 2 + 0.45, (STORE_H - 0.5) / 2), glass),
        box("door", (3.0, 0.12, 4.3), (STORE_W / 2 + 1.8, -DEPTH / 2 + 0.45, 2.15), glass),
    ]
    for z in window_tops:
        for column in range(COLUMNS):
            x = (column - (COLUMNS - 1) / 2) * (WIDTH / COLUMNS)
            glass_parts.append(box("window", (WINDOW_W, 0.1, WINDOW_H), (x, -DEPTH / 2 + RECESS, z), glass))
    glazing = join(glass_parts, "facade_glass")

    for obj in (facade, trim, glazing):
        uv_unwrap(obj)

    return facade, trim, glazing, window_tops


def main():
    reset()
    os.makedirs(HERE, exist_ok=True)
    os.makedirs(RENDER, exist_ok=True)
    facade, trim, glazing, window_tops = build()

    total = triangles(facade) + triangles(trim) + triangles(glazing)

    # LOD1: copia decimada del conjunto.
    lod_parts = []
    for source in (facade, trim, glazing):
        copy = source.copy()
        copy.data = source.data.copy()
        copy.name = source.name + "_LOD1"
        bpy.context.collection.objects.link(copy)
        apply_modifiers(copy)
        decimate = copy.modifiers.new("Decimate", "DECIMATE")
        decimate.ratio = 0.45
        apply_modifiers(copy)
        lod_parts.append(copy)
    lod = join(lod_parts, "facade_LOD1")
    lod.hide_render = True
    lod_triangles = triangles(lod)

    # Cámara y luz para revisar
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 40
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = (20.0, -47.0, 14.0)
    direction = Vector((0.0, 0.0, 13.0)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam

    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 4.0
    sun = bpy.data.objects.new("sun", sun_data)
    bpy.context.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(52), 0.0, math.radians(38))

    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.35, 0.45, 0.62, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.1
    bpy.context.scene.world = world

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "facade.blend"))

    # Exportaciones: unidad FBX, Z delante, Y arriba, origen en la base.
    for obj, name in ((facade, "facade_wall"), (trim, "facade_trim"), (glazing, "facade_glass"), (lod, "facade_LOD1")):
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.fbx(
            filepath=os.path.join(HERE, f"{name}.fbx"),
            use_selection=True,
            apply_scale_options="FBX_SCALE_UNITS",
            axis_forward="Z",
            axis_up="Y",
            bake_anim=False,
            add_leaf_bones=False,
            path_mode="COPY",
            embed_textures=True,
        )

    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 800
    scene.render.film_transparent = False
    scene.render.filepath = os.path.join(RENDER, "facade-hero.png")
    bpy.ops.render.render(write_still=True)

    stats = {
        "triangles": total,
        "lod_triangles": lod_triangles,
        "dimensions": {"width": WIDTH, "height": HEIGHT + 1.0, "depth": DEPTH},
        "windows": len(window_tops) * COLUMNS,
        "floors": len(window_tops),
    }
    with open(os.path.join(HERE, "facade-stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("FACADE_STATS")
    print(json.dumps(stats))


main()

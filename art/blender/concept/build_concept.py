"""Imágenes conceptuales de Metrópolis para la Tarea 1 de la subfase 06.

Estudios de masa, luz y paleta —no arte final— de los tres barrios, con la escala de
`art/escala.md` (1 unidad de Blender = 1 stud) y la luz de `art/luz.md`.

    blender --background --factory-startup --python art/blender/concept/build_concept.py

Cada escena se mira desde la altura del ojo de la ficha: 14,1 studs.
"""

import math
import os

import bpy
from mathutils import Vector

OUT = os.environ.get("FTT_OUT", os.path.join(os.path.dirname(__file__), "out"))
RES_X, RES_Y = 1600, 900

ASFALTO = "#4A4E54"
ASFALTO_OSCURO = "#3A3E44"
ACERA = "#B9B2A0"
CALIZA = "#D2C9B4"
LADRILLO = "#B0664A"
LADRILLO_OSCURO = "#8E5138"
CRISTAL = "#7FB2D9"
ORO = "#C9A227"
ACERO = "#A8AEB4"
AGUA = "#3E7FA6"
VENTANA = "#26313D"
BLANCO = "#EDE5D3"
ROJO = "#C4382B"
AMARILLO = "#F5C518"
VERDE = "#7A8B3F"
LEJOS = "#8FA6B8"


def srgb(value):
    value = value.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(value[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def material(name, rgb, rough=0.8, metal=0.0, alpha=1.0, noise=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree
    bsdf = nodes.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*srgb(rgb), 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if noise > 0:
        coord = nodes.nodes.new("ShaderNodeTexCoord")
        tex = nodes.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = 0.35
        tex.inputs["Detail"].default_value = 6.0
        ramp = nodes.nodes.new("ShaderNodeValToRGB")
        base = srgb(rgb)
        ramp.color_ramp.elements[0].color = (base[0] * 0.82, base[1] * 0.82, base[2] * 0.82, 1)
        ramp.color_ramp.elements[1].color = (min(base[0] * 1.18, 1), min(base[1] * 1.18, 1), min(base[2] * 1.18, 1), 1)
        nodes.links.new(coord.outputs["Object"], tex.inputs["Vector"])
        nodes.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
        nodes.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = rough
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        mat.blend_method = "BLEND"
    return mat


def block(name, x, y, z0, sx, sy, sz, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z0 + sz / 2.0))
    obj = bpy.context.object
    obj.name = name
    obj.scale = (sx, sy, sz)
    obj.data.materials.append(mat)
    return obj


def cylinder(name, x, y, z0, radius, height, mat, verts=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=height,
                                        location=(x, y, z0 + height / 2.0))
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    for engine in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    if hasattr(scene, "eevee") and hasattr(scene.eevee, "taa_render_samples"):
        scene.eevee.taa_render_samples = 64
    scene.render.resolution_x = RES_X
    scene.render.resolution_y = RES_Y
    scene.render.film_transparent = False
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Medium High Contrast"
        scene.view_settings.exposure = -0.15
    except TypeError:
        pass

    world = bpy.data.worlds.new("Metropolis")
    world.use_nodes = True
    nodes = world.node_tree
    background = nodes.nodes["Background"]
    sky = nodes.nodes.new("ShaderNodeTexSky")
    for kind in ("MULTIPLE_SCATTERING", "SINGLE_SCATTERING", "NISHITA"):
        try:
            sky.sky_type = kind
            break
        except TypeError:
            continue
    for attr, value in (("sun_elevation", math.radians(34)), ("sun_rotation", math.radians(140)),
                        ("sun_intensity", 0.30), ("sun_size", math.radians(1.2)),
                        ("altitude", 30), ("air_density", 0.35), ("dust_density", 0.25)):
        if hasattr(sky, attr):
            setattr(sky, attr, value)
    nodes.links.new(sky.outputs[0], background.inputs[0])
    background.inputs[1].default_value = 0.30
    scene.world = world

    bpy.ops.object.light_add(type="SUN", location=(0, 0, 250))
    sun = bpy.context.object
    sun.data.energy = 3.2
    sun.data.angle = math.radians(1.1)
    sun.rotation_euler = (math.radians(56), 0.0, math.radians(140))
    return scene


def camera(loc, target, lens=35):
    bpy.ops.object.camera_add(location=loc)
    cam = bpy.context.object
    cam.data.lens = lens
    cam.data.clip_start = 0.5
    cam.data.clip_end = 4000
    look_at(cam, target)
    bpy.context.scene.camera = cam
    return cam


def render(name):
    path = os.path.join(OUT, name)
    os.makedirs(OUT, exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("RENDER", path)


# --- piezas ----------------------------------------------------------------

def window_bands(prefix, mat_win, front_y, facing, x0, x1, floors, floor_h=7.0):
    span = (x1 - x0) * 0.68
    cx = (x0 + x1) / 2.0
    for i in range(floors):
        z = 2.4 + i * floor_h
        block(f"{prefix}_w{i}", cx, front_y + facing * 0.02, z, span, 0.16, floor_h * 0.40, mat_win)


def rooftoop(prefix, cx, cy, top, mat_metal, mat_tank):
    block(f"{prefix}_tank", cx - 4, cy, top, 5, 5, 6, mat_tank)
    block(f"{prefix}_ac", cx + 6, cy + 2, top, 7, 5, 2.2, mat_metal)
    cylinder(f"{prefix}_ant", cx + 1, cy - 4, top, 0.18, 9, mat_metal, verts=8)


def building(prefix, x0, x1, front_y, depth, floors, mat_wall, mat_win, mat_trim,
             facing=-1, awning=None, step=None, roof=None):
    width = x1 - x0
    height = floors * 7.0
    cy = front_y - facing * depth / 2.0
    block(f"{prefix}_body", (x0 + x1) / 2.0, cy, 0, width, depth, height, mat_wall)
    block(f"{prefix}_corn", (x0 + x1) / 2.0, cy, height, width + 1.4, depth + 1.4, 1.4, mat_trim)
    window_bands(prefix, mat_win, front_y, facing, x0 + 1.4, x1 - 1.4, floors)
    block(f"{prefix}_shop", (x0 + x1) / 2.0, front_y + facing * 0.10, 0.5, width - 3, 0.4, 5.0, mat_win)
    piers = max(2, int(width / 7.0))
    for p in range(piers + 1):
        px = x0 + p * width / piers
        block(f"{prefix}_pier{p}", px, front_y + facing * 0.28, 0, 1.1, 0.9, 5.6, mat_trim)
    if awning:
        block(f"{prefix}_awn", (x0 + x1) / 2.0, front_y + facing * 1.3, 5.8, width - 5, 2.6, 0.7, awning)
    if step:
        inset = 3.0
        block(f"{prefix}_step", (x0 + x1) / 2.0, cy, height + 1.4, width - inset * 2, depth - inset * 2, step * 7.0, mat_wall)
        block(f"{prefix}_stepc", (x0 + x1) / 2.0, cy, height + 1.4 + step * 7.0, width - inset * 2 + 1.2, depth - inset * 2 + 1.2, 1.2, mat_trim)
        if roof:
            rooftoop(f"{prefix}_r", (x0 + x1) / 2.0, cy, height + 1.4 + step * 7.0 + 1.2, mat_trim, roof)
    elif roof:
        rooftoop(f"{prefix}_r", (x0 + x1) / 2.0, cy, height + 1.4, mat_trim, roof)


def skyline(prefix, y_center, depth, items, mat):
    for i, (x, w, h) in enumerate(items):
        block(f"{prefix}{i}", x, y_center, 0, w, depth, h, mat)


def lamppost(prefix, x, y, m):
    cylinder(f"{prefix}_p", x, y, 0, 0.3, 12.5, m, verts=10)
    block(f"{prefix}_a", x, y - 1.4, 12.1, 0.4, 3.0, 0.4, m)
    block(f"{prefix}_h", x, y - 2.7, 11.4, 1.4, 1.4, 0.8, m)


def crosswalk(prefix, x_center, m):
    for i in range(8):
        block(f"{prefix}{i}", x_center, -14.0 + i * 4.0, 0.03, 4.4, 2.4, 0.1, m)


# --- Centro ----------------------------------------------------------------

def build_centro():
    reset_scene()
    asphalt = material("asphalt", ASFALTO, 0.92, noise=1.0)
    asphalt_d = material("asphalt_d", ASFALTO_OSCURO, 0.9, noise=1.0)
    walk = material("walk", ACERA, 0.85, noise=1.0)
    lime = material("lime", CALIZA, 0.75)
    brick = material("brick", LADRILLO, 0.85, noise=0.5)
    brick_d = material("brick_d", LADRILLO_OSCURO, 0.85, noise=0.5)
    win = material("win", VENTANA, 0.12, 0.25)
    steel = material("steel", ACERO, 0.35, 0.85)
    paint = material("paint", BLANCO, 0.6)
    red = material("red", ROJO, 0.7)
    yellow = material("yellow", AMARILLO, 0.5)
    far = material("far", LEJOS, 0.9)
    tank = material("tank", "#8C7A66", 0.9)

    block("road", 0, 0, -1.0, 4000, 34, 1.0, asphalt_d)
    block("side_l", 0, -20.5, 0, 4000, 7, 1.1, walk)
    block("side_r", 0, 20.5, 0, 4000, 7, 1.1, walk)
    block("curb_l", 0, -17.1, 0, 4000, 0.4, 1.2, lime)
    block("curb_r", 0, 17.1, 0, 4000, 0.4, 1.2, lime)
    block("lane", 0, 0, -0.02, 4000, 0.4, 0.05, paint)
    crosswalk("cw", -18, paint)

    left = [(-70, -52, 6, brick, red, 0), (-50, -32, 9, lime, None, 2),
            (-30, -12, 5, brick_d, yellow, 0), (-10, 10, 12, lime, None, 3),
            (12, 30, 7, brick, red, 0), (32, 54, 10, lime, None, 2)]
    right = [(-72, -54, 8, lime, yellow, 0), (-52, -34, 5, brick, None, 0),
             (-32, -14, 11, brick_d, None, 2), (-12, 8, 6, lime, red, 0),
             (10, 32, 9, brick, None, 3), (34, 56, 7, lime, yellow, 0)]
    for i, (x0, x1, fl, wall, awn, st) in enumerate(left):
        building(f"L{i}", x0, x1, -24, 24, fl, wall, win, lime, facing=1, awning=awn, step=st, roof=tank)
    for i, (x0, x1, fl, wall, awn, st) in enumerate(right):
        building(f"R{i}", x0, x1, 24, 24, fl, wall, win, lime, facing=-1, awning=awn, step=st, roof=tank)

    for x in (-58, -34, -10, 14, 38):
        lamppost("pl", x, -18.4, steel)
        lamppost("pr", x + 12, 18.4, steel)

    skyline("far_l", -95, 30, [(120, 26, 74), (150, 20, 96), (176, 30, 62),
                               (210, 22, 110), (240, 34, 80), (278, 24, 68)], far)
    skyline("far_r", 95, 30, [(118, 28, 88), (150, 22, 64), (180, 30, 102),
                              (214, 26, 72), (246, 32, 94), (282, 22, 60)], far)

    # ficha: taxi amarillo de 9 studs
    cylinder("token", -104, -12, 0, 3.0, 8.0, yellow)
    block("token_cab", -104, -12, 5.6, 5.2, 3.4, 3.0, yellow)
    block("token_win", -104, -10.6, 6.4, 4.2, 0.9, 1.4, win)

    camera((-190, 0, 14.1), (120, 0, 19), lens=58)
    render("centro.png")


# --- Puerto ----------------------------------------------------------------

def build_puerto():
    reset_scene()
    concrete = material("concrete", "#B4AC9C", 0.9, noise=1.0)
    water = material("water", AGUA, 0.05)
    brick = material("brick", LADRILLO, 0.85, noise=0.5)
    rust = material("rust", "#8E5138", 0.8, noise=0.5)
    steel = material("steel", ACERO, 0.35, 0.85)
    win = material("win", VENTANA, 0.12, 0.25)
    lime = material("lime", CALIZA, 0.75)
    red = material("red", ROJO, 0.7)
    blue = material("blue", "#2C5C8A", 0.7)
    verde = material("verde", VERDE, 0.75)
    yellow = material("yellow", AMARILLO, 0.5)
    far = material("far", LEJOS, 0.9)
    hull = material("hull", "#2C3E4C", 0.7)

    block("quay", 0, 0, 0, 4000, 64, 2.4, concrete)
    block("water", 0, 92, -1.4, 4000, 700, 2.0, water)
    block("edge", 0, 31.0, 0, 4000, 2.2, 3.2, lime)
    block("rail", 0, 31.6, 3.2, 4000, 0.5, 0.5, steel)

    # naves al fondo del muelle
    for i, (x0, x1, h, m) in enumerate([(-110, -70, 18, brick), (-64, -26, 24, concrete),
                                        (-20, 16, 15, rust), (22, 70, 21, brick)]):
        block(f"ware{i}", (x0 + x1) / 2.0, -22, 0, x1 - x0, 38, h, m)
        block(f"ware{i}_c", (x0 + x1) / 2.0, -22, h, (x1 - x0) + 1.4, 39, 1.4, lime)
        for d in range(3):
            block(f"ware{i}_d{d}", x0 + 10 + d * (x1 - x0 - 20) / 2.4, -2.6, 1.2, 8, 0.6, 11, win)

    # contenedores apilados
    colors = [red, blue, verde, yellow]
    for row, y in enumerate((12, 19, 26)):
        for i in range(6):
            x = -70 + i * 12 + row * 4
            block(f"c{row}{i}", x, y, 2.4, 11.0, 5.6, 4.6, colors[(i + row) % 4])
            if (i + row) % 3 == 0:
                block(f"c{row}{i}b", x, y, 7.0, 11.0, 5.6, 4.6, colors[(i + row + 1) % 4])

    # grúa de pórtico por delante
    for leg_y in (0, 28):
        cylinder(f"leg{leg_y}", 24, leg_y, 2.4, 1.1, 46, steel, verts=10)
    block("beam", 24, 14, 48, 2.6, 34, 2.6, steel)
    block("mast", 24, 14, 51, 1.8, 1.8, 8, steel)
    block("hook", 24, 24, 34, 1.0, 1.0, 15, steel)

    # barco






    for x in (-52, -28, -4, 20, 44, 68):
        cylinder(f"boll{x}", x, 28.6, 2.4, 0.9, 2.6, steel, verts=10)

    camera((-178, -16, 14.1), (150, 26, 15), lens=52)
    render("puerto.png")


# --- Zona Alta -------------------------------------------------------------

def build_alta():
    reset_scene()
    plaza = material("plaza", CALIZA, 0.7, noise=1.0)
    glass = material("glass", CRISTAL, 0.05, 0.15)
    win = material("win", "#9CC4DE", 0.06, 0.1)
    gold = material("gold", ORO, 0.25, 0.9)
    steel = material("steel", ACERO, 0.3, 0.85)
    lime = material("lime", CALIZA, 0.75)
    water = material("water", AGUA, 0.05)
    far = material("far", LEJOS, 0.9)

    block("plaza", 0, 0, 0, 4000, 900, 1.0, plaza)
    block("pool", 10, 44, 1.0, 34, 20, 0.5, water)
    block("pool_rim", 10, 44, 1.0, 36, 22, 0.8, lime)

    towers = [(-74, 20, 22), (-44, 24, 30), (-14, 20, 40),
              (18, 22, 34), (50, 18, 26), (80, 22, 20)]
    for i, (x, w, floors) in enumerate(towers):
        h = floors * 7.0
        d = w * 1.15
        block(f"t{i}", x, -46, 1.0, w, d, h, glass)
        block(f"t{i}_gold", x, -46, 1.0 + h, w + 1.8, d + 1.8, 1.8, gold)
        for f in range(2, floors - 1, 2):
            block(f"t{i}_w{f}", x, -46 + d / 2 + 0.1, 1.0 + f * 7.0, w * 0.84, 0.2, 3.4, win)

    block("low_l", -168, 60, 1.0, 34, 24, 16, lime)
    block("low_l_g", -168, 60, 17.0, 35.2, 25.2, 1.6, gold)
    block("low_r", 176, 54, 1.0, 30, 22, 13, lime)
    block("low_r_g", 176, 54, 14.0, 31.2, 23.2, 1.4, gold)

    

    skyline("far", -150, 40, [(60, 40, 150), (120, 30, 120), (176, 46, 190),
                              (240, 34, 130), (300, 40, 170)], far)

    camera((-150, 200, 14.1), (0, -46, 96), lens=50)
    render("zona-alta.png")


if __name__ == "__main__":
    build_centro()
    build_puerto()
    build_alta()

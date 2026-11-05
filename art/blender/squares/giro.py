"""Giro: kiosco de avisos para la casilla de giro, modelado desde cero.

La carta de giro de `art/guia-de-estilo.md` es un papel caliza con «AVISO» arriba y el texto en un recuadro:
este lugar es ese aviso hecho edificio. Quiosco redondo de ladrillo, friso de caliza con «GIRO» en letras
3D curvadas, tablones de aviso con «AVISO» en las paredes y cubierta de pizarra con costillas de cobre.
Sin añadidos de nivel: es una casilla, no una propiedad.

Medidas en studs (1 unidad de Blender = 1 stud). Frente a -Y, origen en el centro de la base y z = 0 a ras
de suelo. Huella 17,4 x 17,4 dentro del máximo de 32 x 18; nada vuela más allá de y = -7,7. Altura 13,9.

Salidas, en art/blender/squares/:
  giro.blend                 escena de revisión (no se versiona)
  giro/spin_<material>.fbx   una malla, un material y un color por FBX
  giro/spin_LOD1.fbx         una sola malla con un solo material, por debajo del 50 %
  giro/stats.json            triángulos por pieza, total, LOD1 y medidas
Y en art/render/squares/giro/: giro-frontal.png, giro-aereo.png y giro-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/squares/giro.py
"""

import json
import math
import os
import sys

import bpy
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "giro")
RENDER_SUBDIR = "squares/giro"
sys.path.insert(0, SLICE)

# Helpers compartidos con los edificios ya en el juego (no se copian: se importan).
from build_cine_lux import (  # noqa: E402
    apply_modifiers,
    box,
    camera,
    count,
    flat,
    join,
    letters,
    origin_at_zero,
    render,
    select_only,
    textured,
    uv_unwrap,
)

# --- Medidas ---------------------------------------------------------------------------------------
SEG = 32  # lados del tambor, la plataforma y la cubierta
SEG_LANTERN = 12
P0 = 0.90  # rasante de la plataforma: el edificio arranca aquí
R_DRUM = 6.60
R_PLINTH = 6.85
Z_PLINTH = 1.55
R_FRIEZE = 6.70
Z_FRIEZE0 = 8.10
Z_DRUM_TOP = 9.45
R_CORNICE = 7.35
Z_CORNICE = 10.05
ROOF_Z1 = 12.80
R_APEX = 1.20
HEIGHT_MAX = 14.0

PLATFORM = ((8.70, 0.00, 0.30), (8.15, 0.30, 0.60), (7.60, 0.60, 0.90))
PORCH_W = 5.60
PORCH_D = 1.60
PORCH_FRONT = -7.20
PORCH_TOP = 7.80
DOOR_W = 3.20  # hueco del pórtico; el paso libre entre jambas es 2,9
DOOR_CLEAR_W = 2.90
DOOR_CLEAR_H = 6.60
DOOR_TOP = 7.70  # dintel del pórtico
BOARD_ANGLES = (62.0, 118.0, 242.0, 298.0)
BOARD_Z = 4.35
SIGN_TEXT = "GIRO"
SIGN_SIZE = 1.64  # 1,15 de altura de caja y 3,81 de ancho, curvado sobre el friso

FRONT_LIMIT = -10.0
LOT_WIDTH = 32.0
LOT_DEPTH = 18.0
TRIANGLE_BUDGET = 3000
LOD_RATIO = 0.5

RBX = {
    "brick": ("Brick", "", "B0664A"),
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "wood": ("Wood", "", "6B4A2E"),
    "metal": ("Metal", "", "C97B3A"),
    "glass": ("Glass", "", "2E4A63"),
}


def make_materials():
    """Los seis materiales del juego y, solo para la escena de render, el suelo y las referencias."""
    return {
        "brick": textured("brick", "brick_warm", "B0664A"),
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "wood": flat("wood", "6B4A2E", 0.7),
        "metal": flat("metal", "C97B3A", 0.3, 0.9),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        # Solo escena de render.
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "avatar": flat("avatar", "6E747C", 0.8),
    }


def cylinder(name, radius, depth, location, mat, verts=SEG, caps=False):
    """Cilindro vertical. Sin tapas donde la pieza queda oculta por otra."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts,
        radius=radius,
        depth=depth,
        end_fill_type="NGON" if caps else "NOTHING",
        location=location,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def ring(name, r1, r2, z0, z1, mat, verts=SEG):
    """Tronco de cono sin tapas: el friso, la cornisa y las fajas de la cubierta."""
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts,
        radius1=r1,
        radius2=r2,
        depth=z1 - z0,
        end_fill_type="NOTHING",
        location=(0.0, 0.0, (z0 + z1) / 2),
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def radial(obj, angle_deg, radius, z=0.0):
    """Coloca una pieza construida en el plano tangente del tambor, con el frente hacia -Y."""
    angle = math.radians(angle_deg)
    matrix = Matrix.Translation((radius * math.sin(angle), -radius * math.cos(angle), z)) @ Matrix.Rotation(angle, 4, "Z")
    obj.matrix_world = matrix @ obj.matrix_world
    return obj


def bent_letters(text, size, radius, z, mat, depth, target_width):
    """Letras 3D curvadas sobre el tambor: el rótulo de un quiosco redondo no es un plano."""
    obj = letters(text, size, (0.0, 0.0, 0.0), mat, depth=depth)
    select_only(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    xs = [vertex.co.x for vertex in obj.data.vertices]
    factor = target_width / (max(xs) - min(xs))
    for vertex in obj.data.vertices:
        x, y, z_local = vertex.co
        vertex.co.x = x * factor
        vertex.co.y = y * factor
        vertex.co.z = z_local * factor
    for vertex in obj.data.vertices:
        x, y, z_local = vertex.co
        theta = x / radius
        r = radius - y
        vertex.co.x = r * math.sin(theta)
        vertex.co.y = -r * math.cos(theta)
        vertex.co.z = z_local
    obj.location = (0.0, 0.0, z)
    return obj


def build_platform(M):
    """Nivel 0: tres escalones redondos de caliza. El quiosco se sube desde cualquier lado."""
    parts = []
    for index, (radius, z0, z1) in enumerate(PLATFORM):
        parts.append(cylinder(f"tier{index}", radius, z1 - z0, (0.0, 0.0, (z0 + z1) / 2), M["limestone"], SEG, True))
    return parts


def build_drum(M):
    """Tambor de ladrillo con zócalo, friso de caliza y cornisa: la masa redonda del quiosco."""
    parts = [cylinder("drum", R_DRUM, Z_DRUM_TOP - P0, (0.0, 0.0, (P0 + Z_DRUM_TOP) / 2), M["brick"], SEG, False)]
    parts.append(cylinder("plinth", R_PLINTH, Z_PLINTH - P0, (0.0, 0.0, (P0 + Z_PLINTH) / 2), M["limestone"], SEG, False))
    parts.append(cylinder("frieze", R_FRIEZE, Z_DRUM_TOP - Z_FRIEZE0, (0.0, 0.0, (Z_FRIEZE0 + Z_DRUM_TOP) / 2), M["limestone"], SEG, False))
    parts.append(ring("cornice", R_FRIEZE, R_CORNICE, Z_DRUM_TOP, Z_CORNICE, M["limestone"], SEG))
    return parts


def build_porch(M):
    """Pórtico plano en el frente: da un plano a la puerta en un muro curvo y cobija el umbral."""
    parts = []
    pier = (PORCH_W - DOOR_W) / 2  # 1,2
    for side in (-1, 1):
        parts.append(
            box(
                "porch_pier",
                (pier, PORCH_D, PORCH_TOP - P0),
                (side * (DOOR_W + pier) / 2, PORCH_FRONT + PORCH_D / 2, (P0 + PORCH_TOP) / 2),
                M["limestone"],
            )
        )
        # Pilastras: despegan el pórtico del tambor y dan sombra a la fachada plana.
        parts.append(
            box(
                "porch_pilaster",
                (0.45, 0.18, PORCH_TOP - P0),
                (side * (PORCH_W / 2 - 0.225), PORCH_FRONT - 0.06, (P0 + PORCH_TOP) / 2),
                M["limestone"],
            )
        )
    parts.append(
        box(
            "porch_lintel",
            (DOOR_W + 0.04, PORCH_D, PORCH_TOP - 7.68),
            (0.0, PORCH_FRONT + PORCH_D / 2, (7.68 + PORCH_TOP) / 2),
            M["limestone"],
        )
    )
    parts.append(box("porch_cap", (PORCH_W + 0.5, PORCH_D + 0.2, 0.10), (0.0, PORCH_FRONT + PORCH_D / 2, 7.76), M["limestone"]))
    return parts


def build_door(M):
    """Puerta de madera con cristal opaco, más alta que un avatar, y su manilla de cobre."""
    parts = []
    jamb = (DOOR_W - DOOR_CLEAR_W) / 2  # 0,15
    frame_y = PORCH_FRONT + 0.15
    for side in (-1, 1):
        parts.append(
            box(
                "door_jamb",
                (jamb + 0.10, 0.28, DOOR_CLEAR_H),
                (side * (DOOR_CLEAR_W / 2 + (jamb + 0.10) / 2), frame_y, P0 + DOOR_CLEAR_H / 2),
                M["wood"],
            )
        )
    parts.append(box("door_head", (DOOR_W + 0.2, 0.28, 0.20), (0.0, frame_y, DOOR_TOP - 0.10), M["wood"]))

    # Hoja: cajas que se solapan 0,02 para no compartir caras coplanares.
    leaf_y = frame_y + 0.20
    leaf_w = DOOR_CLEAR_W - 0.04
    parts.append(box("leaf_bottom", (leaf_w, 0.14, 2.52), (0.0, leaf_y, P0 + 1.26), M["wood"]))
    parts.append(box("leaf_mid", (leaf_w, 0.14, 0.20), (0.0, leaf_y, P0 + 2.60), M["wood"]))
    for side in (-1, 1):
        parts.append(box("leaf_stile", (0.20, 0.14, DOOR_CLEAR_H + 0.02), (side * (leaf_w / 2 - 0.11), leaf_y, P0 + (DOOR_CLEAR_H + 0.02) / 2), M["wood"]))
    parts.append(box("leaf_top", (leaf_w, 0.14, 0.52), (0.0, leaf_y, P0 + DOOR_CLEAR_H - 0.26), M["wood"]))
    parts.append(box("leaf_glass", (leaf_w - 0.44, 0.07, 3.44), (0.0, leaf_y, P0 + 4.38), M["glass"]))
    parts.append(box("glass_bar", (leaf_w - 0.48, 0.06, 0.07), (0.0, leaf_y - 0.04, P0 + 4.38), M["metal"]))
    parts.append(box("leaf_rail", (leaf_w - 0.30, 0.05, 0.08), (0.0, leaf_y - 0.07, P0 + 1.60), M["wood"]))
    parts.append(box("door_handle", (0.09, 0.12, 0.70), (1.00, leaf_y - 0.10, P0 + 3.60), M["metal"]))
    return parts


def build_boards(M):
    """Tablones de aviso en el tambor: papel caliza, «AVISO» en letras 3D y renglones de cita."""
    parts = []
    for angle in BOARD_ANGLES:
        group = []
        group.append(box("board_case", (2.60, 0.50, 3.90), (0.0, 0.0, BOARD_Z), M["wood"]))
        group.append(box("board_paper", (2.16, 0.12, 3.34), (0.0, -0.32, BOARD_Z), M["limestone"]))
        group.append(box("board_rule", (1.90, 0.04, 0.06), (0.0, -0.41, BOARD_Z + 0.83), M["slate"]))
        for index, (width, dz) in enumerate(((1.70, 0.42), (1.42, 0.17), (1.58, -0.08))):
            group.append(box(f"board_line{index}", (width, 0.04, 0.055), (0.0, -0.41, BOARD_Z + dz), M["slate"]))
        group.append(letters("AVISO", 0.42, (0.0, -0.42, BOARD_Z + 1.20), M["slate"], depth=0.10))
        for piece in group:
            radial(piece, angle, R_DRUM)
            parts.append(piece)
    return parts


def build_sign(M):
    """Rótulo: «GIRO» en letras 3D de pizarra curvadas sobre el friso caliza."""
    return [bent_letters(SIGN_TEXT, SIGN_SIZE, R_FRIEZE + 0.06, 8.82, M["slate"], 0.12, 3.81)]


def roof_radius(z):
    return R_CORNICE - (z - Z_CORNICE) * (R_CORNICE - R_APEX) / (ROOF_Z1 - Z_CORNICE)


def roof_height(radius):
    return Z_CORNICE + (R_CORNICE - radius) * (ROOF_Z1 - Z_CORNICE) / (R_CORNICE - R_APEX)


def build_roof(M):
    """Nivel 0: cubierta de pizarra en cuatro fajas escalonadas, con costillas de cobre y linterna."""
    parts = []
    step = (ROOF_Z1 - Z_CORNICE) / 4.0
    for index in range(4):
        z0 = Z_CORNICE + step * index
        z1 = z0 + step
        bottom = z0 if index == 0 else z0 - 0.07
        parts.append(ring(f"roof{index}", roof_radius(bottom) + 0.10, roof_radius(z1), bottom, z1, M["slate"], SEG))

    # Canalón de cobre en el alero: da canto a la cubierta, que si no queda en filo de papel.
    eave = roof_radius(Z_CORNICE) + 0.10
    parts.append(ring("eave", eave + 0.06, eave - 0.16, Z_CORNICE - 0.13, Z_CORNICE + 0.09, M["metal"], SEG))

    # Costillas de cobre: la cubierta se mira desde arriba en cada turno.
    r0, r1 = eave - 0.19, 1.40
    z0, z1 = roof_height(r0), roof_height(r1)
    slope = math.atan2(z1 - z0, r0 - r1)
    mid_radius, mid_z = (r0 + r1) / 2, (z0 + z1) / 2 + 0.03
    length = math.hypot(r0 - r1, z1 - z0)
    for index in range(12):
        angle = 2 * math.pi * index / 12
        rib = box("rib", (0.15, length, 0.14), (0.0, 0.0, 0.0), M["metal"])
        rib.rotation_euler = (slope, 0.0, angle)
        rib.location = (mid_radius * math.sin(angle), -mid_radius * math.cos(angle), mid_z)
        parts.append(rib)

    # Linterna: cuerpo de cristal opaco, montantes de cobre, capuchón y remate.
    parts.append(cylinder("lantern_base", 1.45, 0.25, (0.0, 0.0, 12.825), M["limestone"], SEG_LANTERN, True))
    parts.append(cylinder("lantern_glass", 1.20, 0.55, (0.0, 0.0, 13.225), M["glass"], SEG_LANTERN, False))
    for index in range(6):
        angle = 2 * math.pi * index / 6
        parts.append(box("lantern_bar", (0.09, 0.09, 0.55), (1.20 * math.sin(angle), -1.20 * math.cos(angle), 13.225), M["metal"]))
    parts.append(ring("lantern_cap", 1.55, 0.12, 13.50, 13.78, M["slate"], SEG_LANTERN))
    parts.append(ring("lantern_finial", 0.14, 0.04, 13.78, 13.90, M["metal"], 8))
    return parts


def group(parts, store):
    """Una malla por material y color: en Roblox cada malla lleva un solo material."""
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        rbx, suffix, rgb = RBX[key]
        name = f"spin_{rbx.lower()}{suffix}"
        if len(members) == 1:
            mesh = members[0]
            mesh.name = name
            origin_at_zero(mesh)
        else:
            mesh = join(members, name)
        uv_unwrap(mesh)
        materials = {material.name for material in mesh.data.materials if material is not None}
        if len(materials) != 1:
            raise RuntimeError(f"{name} tiene {len(materials)} materiales: {sorted(materials)}")
        store.append({"key": name, "material": rbx, "rgb": rgb, "obj": mesh})


def bounds(objects):
    xs, ys, zs = [], [], []
    for obj in objects:
        for vertex in obj.data.vertices:
            point = obj.matrix_world @ vertex.co
            xs.append(point.x)
            ys.append(point.y)
            zs.append(point.z)
    return {
        "ancho": round(max(xs) - min(xs), 2),
        "fondo": round(max(ys) - min(ys), 2),
        "alto": round(max(zs) - min(zs), 2),
        "alto_maximo_sobre_suelo": round(max(zs), 2),
        "frente_y_minima": round(min(ys), 2),
        "fondo_y_maxima": round(max(ys), 2),
    }


def lod_single(sources, name, mat):
    """LOD1: decimado al 50 %, una sola malla y un solo material, como el resto de los assets."""
    copies = []
    for source in sources:
        copy = source.copy()
        copy.data = source.data.copy()
        copy.name = f"{source.name}_lod"
        bpy.context.collection.objects.link(copy)
        decimate = copy.modifiers.new("Decimate", "DECIMATE")
        decimate.ratio = LOD_RATIO
        apply_modifiers(copy)
        copies.append(copy)
    lod = join(copies, name)
    lod.data.materials.clear()
    lod.data.materials.append(mat)
    for polygon in lod.data.polygons:
        polygon.material_index = 0
    lod.hide_render = True
    return lod


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


def lights_and_world():
    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 4.2
    sun_data.angle = math.radians(1.0)
    sun = bpy.data.objects.new("sun", sun_data)
    bpy.context.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(90 - 34.0), 0, math.radians(-38))
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.68, 0.78, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    bpy.context.scene.world = world


def stage(M):
    """Solo escena de render: un suelo llano, para leer la escala y la altura sin adornos."""
    box("ground", (320, 320, 0.4), (0.0, 0.0, -0.2), M["pavement"])
    lights_and_world()


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    scene.unit_settings.scale_length = 1.0
    os.makedirs(OUT, exist_ok=True)
    render_dir = os.path.join(REPO, "art", "render", *RENDER_SUBDIR.split("/"))
    os.makedirs(render_dir, exist_ok=True)

    M = make_materials()
    pieces = []

    parts = build_platform(M) + build_drum(M) + build_porch(M) + build_door(M) + build_boards(M) + build_sign(M) + build_roof(M)
    group(parts, pieces)

    objects = [piece["obj"] for piece in pieces]
    total = sum(count(obj) for obj in objects)
    limits = bounds(objects)
    lod = lod_single(objects, "spin_LOD1", M["limestone"])
    lod_tris = count(lod)

    for piece in pieces:
        export(piece["obj"], piece["key"] + ".fbx")
    export(lod, "spin_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": round(2 * PLATFORM[0][0], 2), "fondo": round(2 * PLATFORM[0][0], 2), "maximo": {"ancho": LOT_WIDTH, "fondo": LOT_DEPTH}},
        "limites": limits,
        "puerta": {"paso_libre_ancho": DOOR_CLEAR_W, "paso_libre_alto": DOOR_CLEAR_H, "hueco_portico": DOOR_W, "minimo": {"ancho": 2.4, "alto": 6.5}},
        "rotulo": {"texto": SIGN_TEXT, "letras_alto": 1.15, "letras_ancho": 3.81, "z": 8.82, "material": "Slate", "rgb": "4A4E54"},
        "piezas": [
            {"clave": piece["key"], "nivel": 0, "material": piece["material"], "rgb": piece["rgb"], "triangulos": count(piece["obj"])}
            for piece in pieces
        ],
        "niveles": {"0": {"triangulos_propios": total, "triangulos_acumulados": total, "limites": limits}},
        "total_triangulos": total,
        "presupuesto_triangulos": TRIANGLE_BUDGET,
        "lod1": {"clave": "spin_LOD1", "triangulos": lod_tris, "porcentaje_del_total": round(100.0 * lod_tris / total, 1), "mallas": 1, "material": "Limestone", "rgb": "D2C9B4"},
        "altura_maxima": limits["alto_maximo_sobre_suelo"],
        "altura_maxima_permitida": HEIGHT_MAX,
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("GIRO_STATS", json.dumps({"total": total, "lod1": lod_tris, "limites": limits, "piezas": [(p["key"], count(p["obj"])) for p in pieces]}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    if limits["alto_maximo_sobre_suelo"] > HEIGHT_MAX:
        raise RuntimeError(f"Altura {limits['alto_maximo_sobre_suelo']} > {HEIGHT_MAX}")
    if limits["frente_y_minima"] < FRONT_LIMIT:
        raise RuntimeError(f"Vuela más de la cuenta: y = {limits['frente_y_minima']}")
    if abs(limits["frente_y_minima"]) > LOT_DEPTH / 2 or limits["fondo_y_maxima"] > LOT_DEPTH / 2:
        raise RuntimeError(f"Se sale del fondo del solar: {limits['frente_y_minima']} a {limits['fondo_y_maxima']}")
    if limits["ancho"] > LOT_WIDTH:
        raise RuntimeError(f"Se sale del solar a lo ancho: {limits['ancho']}")

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "giro.blend"))

    stage(M)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass

    render(scene, camera("frontal", (0.0, -44.0, 10.0), (0.0, 0.0, 6.3), 45), f"{RENDER_SUBDIR}/giro-frontal.png")
    render(scene, camera("aereo", (18.0, -42.0, 42.0), (0.0, 2.0, 5.5), 48), f"{RENDER_SUBDIR}/giro-aereo.png")

    box("avatar_ref", (1.6, 1.2, 6.0), (9.8, -6.0, 3.0), M["avatar"])
    render(scene, camera("comparacion", (2.0, -48.0, 16.0), (2.0, 0.0, 6.3), 55), f"{RENDER_SUBDIR}/giro-comparacion.png")
    print("GIRO_DONE")


if __name__ == "__main__":
    main()


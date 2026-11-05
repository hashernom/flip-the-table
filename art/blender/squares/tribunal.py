"""Tribunal: el palacio de justicia de la casilla «Tribunal», modelado desde cero.

La casilla no trae un edificio propio: en su solar ya vive la cárcel del juego (30 × 16 × 14, puerta de
7 × 6 en y = -8). Este script modela SOLO el palacio que la envuelve: basamento y columnas de caliza
adosadas a su fachada, entablamento y frontón por encima de z = 14 hasta 26, y dos alas cortas de 3
studs a los lados. La cárcel no se toca ni se exporta; se importa únicamente en la escena de render para
enseñar el conjunto.

La caja de la cárcel (x -15..15, y -8..8, z 0..14) y el paso de la puerta (7 de ancho × 6 de alto en la
franja central delante de y = -8) quedan libres: el script lo comprueba vértice a vértice antes de
exportar.

Salidas, en art/blender/squares/tribunal/:
  tribunal_limestone.fbx y tribunal_slate.fbx    una malla, un material y un color por FBX
  tribunal_LOD1.fbx                              una sola malla, un solo material, por debajo del 50 %
  stats.json                                     triángulos por pieza, total, LOD1 y medidas
Y en art/render/squares/tribunal/: tribunal-frontal.png, tribunal-aereo.png y tribunal-comparacion.png.

Uso: blender --background --factory-startup --python art/blender/squares/tribunal.py
"""

import json
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "tribunal")
RENDER_DIR = os.path.join(REPO, "art", "render", "squares", "tribunal")
RENDER_SUBDIR = "squares/tribunal"
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
    render,
    select_only,
    textured,
    uv_unwrap,
)

# --------------------------------------------------------------------------------------------------
# Medidas. Todo en studs y con el frente hacia -Y, el origen en el centro de la base y z = 0 en el suelo.
# --------------------------------------------------------------------------------------------------
WIDTH = 32.0
DEPTH = 18.0
HALF_W = WIDTH / 2
JAIL_W, JAIL_D, JAIL_H = 30.0, 16.0, 14.0
JAIL_HALF_W, JAIL_HALF_D = JAIL_W / 2, JAIL_D / 2
DOOR_W, DOOR_H = 7.0, 6.0
DOOR_HALF = DOOR_W / 2

# Basamento: 0,88 de alto y 1,4 de fondo, en la franja delantera de 3 studs. Se interrumpe delante de la
# puerta: los dos tramos arrancan en x = ±4,1 y dejan 8,2 libres (la franja de paso son 7).
PODIUM_TOP = 0.88
PODIUM_FRONT = -9.55
PODIUM_BACK = -8.15
PODIUM_INNER = 4.10

# Orden: dos parejas de columnas de caliza en la fachada, separadas 4,5. Las de dentro flanquean la
# puerta y el rótulo «CÁRCEL» de la cárcel, que queda entero entre ellas.
COLUMN_XS = (-10.0, -5.5, 5.5, 10.0)
COLUMN_Y = -9.0
COLUMN_R = 0.78
COLUMN_ABACUS_TOP = 13.55

# Entablamento por encima de la cárcel: arquitrabe, friso con el rótulo y cornisa.
ARCHITRAVE_TOP = 14.55
FRIEZE_TOP = 16.70
CORNICE_TOP = 17.53
ATTIC_TOP = 16.74
SIGN_Z = 15.60
SIGN_SIZE = 2.1

# Tejado a dos aguas con el frontón como hastial delantero. El alero arranca sobre la cornisa (17,5) y la
# cumbrera queda en 25,1; el acroterión llega como máximo a 25,95.
ROOF_EAVE = 17.45
ROOF_RIDGE = 25.10
ROOF_FRONT = -8.25
ROOF_BACK = 8.95
PEDIMENT_FRONT = -9.60
PEDIMENT_BACK = -8.30
SLOPE = math.atan2(ROOF_RIDGE - ROOF_EAVE, HALF_W)

# Presupuesto y comprobaciones.
TRIANGLE_BUDGET = 3000
LOD_RATIO = 0.40
EPS = 0.02

RBX = {
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
}

SIGN = {"ancho": 0.0, "alto": 0.0}

# Ladrillo y materiales de la cárcel: solo para la escena de render, nunca se exportan.
JAIL_STEMS = {
    "jail_brick": "brick",
    "jail_limestone": "limestone",
    "jail_glass": "glass",
    "jail_steel": "steel",
    "jail_dark": "dark",
    "jail_sign": "sign",
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, los de la cárcel y la calle."""
    return {
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        # Solo escena de render.
        "brick": textured("brick", "brick_warm", "5E3A2E"),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "steel": flat("steel", "A8AEB4", 0.25, 0.8),
        "dark": flat("dark", "2A2E33", 0.6),
        "sign": flat("sign", "C4382B", 0.6),
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "pavement_light": flat("pavement_light", "B5AD9E", 0.85),
        "cream": flat("cream", "EDE5D3", 0.6),
        "avatar": flat("avatar", "6E747C", 0.8),
    }


def cylinder(name, radius, z0, z1, x, y, mat, verts=10):
    """Cilindro vertical de diez caras: fuste, basa o capitel de una columna."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts,
        radius=radius,
        depth=z1 - z0,
        location=(x, y, (z0 + z1) / 2),
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def prism(name, half_width, z_base, z_apex, y_front, y_back, mat):
    """Prisma triangular: hastial del frontón y tejado a dos aguas. 8 triángulos."""
    verts = [
        (-half_width, y_front, z_base),
        (half_width, y_front, z_base),
        (0.0, y_front, z_apex),
        (-half_width, y_back, z_base),
        (half_width, y_back, z_base),
        (0.0, y_back, z_apex),
    ]
    faces = [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def build_podium(M):
    """Basamento de caliza: dos tramos delanteros (la puerta queda libre), costados y fondo."""
    parts = []
    run = HALF_W - PODIUM_INNER
    for side in (-1, 1):
        parts.append(box("podium_front", (run, abs(PODIUM_FRONT - PODIUM_BACK), PODIUM_TOP),
                         (side * (HALF_W + PODIUM_INNER) / 2, (PODIUM_FRONT + PODIUM_BACK) / 2, PODIUM_TOP / 2),
                         M["limestone"]))
        parts.append(box("podium_side", (HALF_W - 15.12, 16.6, PODIUM_TOP),
                         (side * (HALF_W + 15.12) / 2, 0.0, PODIUM_TOP / 2), M["limestone"]))
    parts.append(box("podium_back", (31.12, 0.7, PODIUM_TOP), (0.0, 8.60, PODIUM_TOP / 2), M["limestone"]))
    return parts


def build_columns(M):
    """Cuatro columnas de caliza adosadas a la fachada de la cárcel, con basa, fuste y abaco."""
    parts = []
    for x in COLUMN_XS:
        parts.append(box("col_plinth", (1.85, 1.75, 0.42), (x, COLUMN_Y, 1.04), M["limestone"]))
        parts.append(cylinder("col_base", 0.94, 1.23, 1.55, x, COLUMN_Y, M["limestone"], 12))
        parts.append(cylinder("col_shaft", COLUMN_R, 1.51, 12.45, x, COLUMN_Y, M["limestone"], 12))
        parts.append(cylinder("col_capital", 0.94, 12.43, 12.92, x, COLUMN_Y, M["limestone"], 12))
        parts.append(box("col_abacus", (1.9, 1.6, 0.66), (x, COLUMN_Y, 13.22), M["limestone"]))
    return parts


def build_wings(M):
    """Alas cortas de 3 studs a los lados: pilonos de caliza que sostienen el entablamento."""
    parts = []
    for side in (-1, 1):
        cx = side * 14.45
        parts.append(box("wing_body", (3.1, 1.4, 12.67), (cx, -8.85, 7.215), M["limestone"]))
        parts.append(box("wing_base", (3.2, 1.55, 0.82), (side * 14.40, -8.90, 1.29), M["limestone"]))
        parts.append(box("wing_cornice", (3.2, 1.7, 0.90), (side * 14.40, -8.95, 13.10), M["limestone"]))
        for px in (13.45, 14.45, 15.45):
            parts.append(box("wing_rib", (0.40, 0.18, 10.40), (side * px, -9.63, 6.85), M["limestone"]))
    return parts


def build_entablature(M):
    """Arquitrabe, friso, dentículos y cornisa; por encima de z = 14 y hasta 17,5."""
    parts = []
    parts.append(box("architrave", (WIDTH, 1.55, 1.0), (0.0, -9.075, 14.05), M["limestone"]))
    parts.append(box("bed_mould", (WIDTH, 1.68, 0.22), (0.0, -9.14, 14.50), M["limestone"]))
    parts.append(box("frieze", (31.9, 1.4, 2.15), (0.0, -9.00, 15.625), M["limestone"]))
    parts.append(box("cornice_fascia", (31.9, 18.6, 0.30), (0.0, -0.45, 16.85), M["limestone"]))
    parts.append(box("cornice_slab", (32.0, 18.9, 0.53), (0.0, -0.45, 17.265), M["limestone"]))
    steps = 22
    for index in range(steps):
        x = -14.3 + index * (28.6 / (steps - 1))
        parts.append(box("dentil", (0.62, 0.24, 0.34), (x, -9.83, 16.53), M["limestone"]))
    return parts


def build_attic(M):
    """Ático de caliza sobre el tejado de la cárcel: el palacio se apoya en ella, no flota."""
    return [box("attic", (29.8, 15.8, 2.19), (0.0, 0.0, 15.645), M["limestone"])]


def build_pediment(M):
    """Frontón triangular con su cornisa rampante, acróteras y el sello central del tímpano."""
    parts = [prism("pediment", HALF_W, 17.50, ROOF_RIDGE, PEDIMENT_FRONT, PEDIMENT_BACK, M["limestone"])]
    for side in (-1, 1):
        raking = box("raking_cornice", (17.30, 0.62, 0.56),
                     (side * 8.0, -9.62, 21.35), M["limestone"])
        raking.rotation_euler = (0.0, side * SLOPE, 0.0)
        parts.append(raking)
        parts.append(box("acroterion", (0.85, 0.85, 0.85),
                         (side * 15.35, -9.45, 17.95), M["limestone"]))
    parts.append(box("apex_block", (1.05, 0.75, 0.45), (0.0, -9.35, 25.33), M["limestone"]))
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.55, depth=0.42,
                                    location=(0.0, -9.35, 25.76), rotation=(0.0, 0.0, math.radians(45)))
    finial = bpy.context.active_object
    finial.name = "apex_finial"
    finial.data.materials.append(M["limestone"])
    parts.append(finial)
    # Sello del tímpano: disco de caliza con el centro de pizarra. Sin letras ni marcas.
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=1.60, depth=0.40,
                                        location=(0.0, -9.55, 20.40), rotation=(math.radians(90), 0.0, 0.0))
    disc = bpy.context.active_object
    disc.name = "tympanum_disc"
    disc.data.materials.append(M["limestone"])
    parts.append(disc)
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.95, depth=0.12,
                                        location=(0.0, -9.72, 20.40), rotation=(math.radians(90), 0.0, 0.0))
    center = bpy.context.active_object
    center.name = "tympanum_center"
    center.data.materials.append(M["slate"])
    parts.append(center)
    return parts


def build_roof(M):
    """Tejado de pizarra: dos aguas con cumbrera, hiladas marcadas y dos chimeneas calizas."""
    parts = [prism("roof", HALF_W, ROOF_EAVE, ROOF_RIDGE, ROOF_FRONT, ROOF_BACK, M["slate"])]
    parts.append(box("ridge", (0.90, ROOF_BACK - ROOF_FRONT - 0.1, 0.35),
                     (0.0, (ROOF_FRONT + ROOF_BACK) / 2, ROOF_RIDGE), M["slate"]))
    for z in (18.60, 19.50, 20.40, 21.30, 22.20, 23.10, 24.00):
        x = HALF_W * (ROOF_RIDGE - z) / (ROOF_RIDGE - ROOF_EAVE)
        for side in (-1, 1):
            course = box("course", (0.18, 17.0, 0.09), (side * x, 0.35, z), M["slate"])
            course.rotation_euler = (0.0, side * SLOPE, 0.0)
            parts.append(course)
    for x in (-5.0, 5.0):
        parts.append(box("chimney", (1.5, 1.5, 3.5), (x, 6.0, 23.0), M["limestone"]))
        parts.append(box("chimney_cap", (1.8, 1.8, 0.25), (x, 6.0, 24.85), M["slate"]))
    return parts


def build_sign(M):
    """Rótulo «TRIBUNAL» en letras 3D de pizarra, sobre la entrada y por debajo del frontón."""
    label = letters("TRIBUNAL", SIGN_SIZE, (0.0, -9.75, SIGN_Z), M["slate"], 0.2)
    width = label.dimensions.x
    if width > 14.0:
        select_only(label)
        factor = 14.0 / width
        label.scale = (factor, factor, factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    points = [label.matrix_world @ vertex.co for vertex in label.data.vertices]
    SIGN["ancho"] = round(max(p.x for p in points) - min(p.x for p in points), 2)
    SIGN["alto"] = round(max(p.z for p in points) - min(p.z for p in points), 2)
    return [label]


def group(parts, store):
    """Une las piezas en una malla por material y color: en Roblox cada malla lleva un solo material."""
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        rbx, suffix, rgb = RBX[key]
        name = f"tribunal_{key}"
        mesh = join(members, name)
        uv_unwrap(mesh)
        materials = {material.name for material in mesh.data.materials if material is not None}
        if len(materials) != 1:
            raise RuntimeError(f"{name} tiene {len(materials)} materiales")
        store.append({"key": name, "material": rbx, "rgb": rgb, "obj": mesh})
    return store


def bounds(objects):
    """Límites reales en studs a partir de los vértices de las mallas."""
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
        "x": (round(min(xs), 2), round(max(xs), 2)),
        "y": (round(min(ys), 2), round(max(ys), 2)),
        "z": (round(min(zs), 2), round(max(zs), 2)),
    }


def jail_clearance(objects):
    """Comprueba que ningún vértice del palacio entra en la caja de la cárcel ni en el paso de la puerta."""
    inside = 0
    corridor = 0
    for obj in objects:
        for vertex in obj.data.vertices:
            point = obj.matrix_world @ vertex.co
            if (-JAIL_HALF_W - EPS <= point.x <= JAIL_HALF_W + EPS
                    and -JAIL_HALF_D - EPS <= point.y <= JAIL_HALF_D + EPS
                    and -EPS <= point.z <= JAIL_H + EPS):
                inside += 1
            if abs(point.x) <= DOOR_HALF + EPS and point.y < -JAIL_HALF_D and 0.0 <= point.z <= DOOR_H + EPS:
                corridor += 1
    return inside, corridor


def build_lod(objects, material, name, ratio):
    """LOD1: una sola malla, un solo material y por debajo de la mitad de triángulos."""
    copies = []
    for source in objects:
        copy = source.copy()
        copy.data = source.data.copy()
        copy.name = f"{source.name}_lod"
        bpy.context.collection.objects.link(copy)
        copies.append(copy)
    lod = join(copies, name)
    decimate = lod.modifiers.new("Decimate", "DECIMATE")
    decimate.ratio = ratio
    apply_modifiers(lod)
    # Triangulado antes de contar: así stats.json y la FBX dan el mismo número de triángulos.
    select_only(lod)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris(quad_method="BEAUTY", ngon_method="BEAUTY")
    bpy.ops.object.mode_set(mode="OBJECT")
    lod.data.materials.clear()
    lod.data.materials.append(material)
    for polygon in lod.data.polygons:
        polygon.material_index = 0
    return lod


def fbx_triangles(path):
    """Cuenta los triángulos del FBX ya exportado: es la cifra real que verá el juego."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, axis_forward="Z", axis_up="Y")
    fresh = [obj for obj in bpy.data.objects if obj not in before and obj.type == "MESH"]
    tris = sum(count(obj) for obj in fresh)
    for obj in fresh:
        bpy.data.objects.remove(obj, do_unlink=True)
    return tris


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


def import_jail(M):
    """Cárcel del juego, solo para los renders: se importa tal cual y no se exporta."""
    before = set(bpy.data.objects)
    for stem in JAIL_STEMS:
        path = os.path.join(SLICE, stem + ".fbx")
        if not os.path.exists(path):
            raise RuntimeError(f"falta la cárcel de referencia: {path}")
        bpy.ops.import_scene.fbx(filepath=path, axis_forward="Z", axis_up="Y")
    imported = []
    for obj in bpy.data.objects:
        if obj in before or obj.type != "MESH":
            continue
        stem = obj.name.split(".")[0]
        key = JAIL_STEMS.get(stem)
        if key is None:
            continue
        obj.data.materials.clear()
        obj.data.materials.append(M[key])
        imported.append(obj)
    if len(imported) != len(JAIL_STEMS):
        raise RuntimeError(f"la cárcel se importó con {len(imported)} mallas")
    return imported


def stage(M):
    """Suelo, acera y calzada; solo escena de render, nunca se exporta."""
    box("ground", (150.0, 90.0, 0.4), (0.0, -6.0, -0.2), M["pavement"])
    box("sidewalk", (70.0, 6.6, 0.08), (0.0, -13.2, 0.04), M["pavement_light"])
    box("kerb", (70.0, 0.35, 0.14), (0.0, -16.55, 0.07), M["cream"])
    box("street", (70.0, 14.0, 0.06), (0.0, -23.7, 0.03), M["asphalt"])


def lights_and_world():
    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 4.2
    sun_data.angle = math.radians(1.0)
    sun = bpy.data.objects.new("sun", sun_data)
    bpy.context.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(90 - 34.0), 0.0, math.radians(-38.0))
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.68, 0.78, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    bpy.context.scene.world = world


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    scene.unit_settings.scale_length = 1.0
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(RENDER_DIR, exist_ok=True)

    M = make_materials()
    pieces = []
    parts = []
    parts += build_podium(M)
    parts += build_columns(M)
    parts += build_wings(M)
    parts += build_entablature(M)
    parts += build_attic(M)
    parts += build_pediment(M)
    parts += build_roof(M)
    parts += build_sign(M)
    group(parts, pieces)

    objects = [piece["obj"] for piece in pieces]
    total = sum(count(obj) for obj in objects)
    measured = bounds(objects)
    inside, corridor = jail_clearance(objects)

    lod = build_lod(objects, M["limestone"], "tribunal_LOD1", LOD_RATIO)
    lod_tris = count(lod)
    lod_materials = {material.name for material in lod.data.materials if material is not None}

    for piece in pieces:
        export(piece["obj"], piece["key"] + ".fbx")
        piece["triangulos_fbx"] = fbx_triangles(os.path.join(OUT, piece["key"] + ".fbx"))
    export(lod, "tribunal_LOD1.fbx")
    lod_fbx_tris = fbx_triangles(os.path.join(OUT, "tribunal_LOD1.fbx"))

    limits = {
        "ancho": measured["ancho"],
        "fondo": measured["fondo"],
        "alto": measured["alto"],
        "alto_maximo_sobre_suelo": measured["z"][1],
        "frente_y_minima": measured["y"][0],
        "fondo_y_maxima": measured["y"][1],
    }
    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "tipo": "lugar: palacio de justicia sobre la cárcel del solar, sin añadidos de nivel",
        "origen": "centro de la base, z = 0 a ras de suelo, frente a -Y",
        "huella": {
            "ancho": WIDTH,
            "fondo": DEPTH,
            "maximo": {"ancho": WIDTH, "fondo": DEPTH},
        },
        "vuelos": {"frente_y": measured["y"][0], "limite_y": -10.0},
        "limites": limits,
        "medidas": {
            **measured,
            "frente_y": measured["y"][0],
            "fondo_y": measured["y"][1],
            "alto_maximo_sobre_suelo": measured["z"][1],
        },
        "carcel": {
            "caja_libre": {"x": [-JAIL_HALF_W, JAIL_HALF_W], "y": [-JAIL_HALF_D, JAIL_HALF_D], "z": [0.0, JAIL_H]},
            "puerta": {"ancho": DOOR_W, "alto": DOOR_H, "cara_y": -JAIL_HALF_D},
            "vertices_dentro_de_la_caja": inside,
            "vertices_en_el_paso_de_la_puerta": corridor,
            "franja_de_paso_libre": "x -3,5..3,5 delante de y = -8, de z = 0 a z = 6",
        },
        "piezas": [
            {
                "clave": piece["key"],
                "nivel": 0,
                "material": piece["material"],
                "rgb": piece["rgb"],
                "triangulos": count(piece["obj"]),
                "triangulos_en_fbx": piece["triangulos_fbx"],
                "medidas": bounds([piece["obj"]]),
            }
            for piece in pieces
        ],
        "niveles": {
            "0": {
                "triangulos_propios": total,
                "triangulos_acumulados": total,
                "limites": limits,
            }
        },
        "total_triangulos": total,
        "presupuesto_triangulos": TRIANGLE_BUDGET,
        "altura_maxima": measured["z"][1],
        "altura_maxima_permitida": 26.0,
        "lod1": {
            "clave": "tribunal_LOD1",
            "archivo": "tribunal_LOD1.fbx",
            "triangulos": lod_fbx_tris,
            "triangulos_antes_de_exportar": lod_tris,
            "porcentaje_del_total": round(100.0 * lod_fbx_tris / total, 1),
            "mallas": 1,
            "materiales": len(lod_materials),
            "material": "Limestone",
            "rgb": "D2C9B4",
        },
        "rotulo": {
            "texto": "TRIBUNAL",
            "ancho": SIGN["ancho"],
            "alto": SIGN["alto"],
            "z": SIGN_Z,
            "material": "Slate",
            "rgb": "4A4E54",
        },
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("TRIBUNAL_STATS", json.dumps({"total": total, "lod1": lod_tris, "medidas": measured}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2 or lod_fbx_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris}/{lod_fbx_tris} de {total}")
    if sum(piece["triangulos_fbx"] for piece in pieces) != total:
        raise RuntimeError("los triángulos de las FBX no suman el total")
    if inside or corridor:
        raise RuntimeError(f"El palacio invade la cárcel: caja {inside}, paso {corridor}")
    if measured["x"][0] < -HALF_W - EPS or measured["x"][1] > HALF_W + EPS:
        raise RuntimeError(f"Se sale a lo ancho: {measured['x']}")
    if measured["y"][0] < -10.0 - EPS or measured["y"][1] > 9.0 + EPS:
        raise RuntimeError(f"Se sale de fondo o de vuelo: {measured['y']}")
    if measured["z"][1] > 26.0 + EPS:
        raise RuntimeError(f"Supera 26 de alto: {measured['z'][1]}")

    # Escena de revisión: el palacio, la cárcel de verdad y la calle, con luz de las 9,4.
    for obj in objects:
        obj.hide_render = False
        obj.hide_viewport = False
    lod.hide_render = True
    lod.hide_viewport = True
    import_jail(M)
    stage(M)
    lights_and_world()

    # Figura de 6 studs delante de la puerta: piernas, torso y cabeza. Prueba que el paso queda libre
    # y da la escala. Es utilería del render, no se exporta.
    figure = [
        box("avatar_leg_l", (0.5, 0.7, 1.8), (1.55, -8.95, 0.9), M["avatar"]),
        box("avatar_leg_r", (0.5, 0.7, 1.8), (2.25, -8.95, 0.9), M["avatar"]),
        box("avatar_body", (1.3, 0.8, 2.4), (1.9, -8.95, 3.0), M["avatar"]),
        box("avatar_head", (0.9, 0.9, 1.8), (1.9, -8.95, 5.1), M["avatar"]),
    ]
    for part in figure:
        part.hide_render = True

    scene.render.engine = "CYCLES"
    scene.cycles.samples = 40
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    scene.view_settings.look = "AgX - Medium High Contrast"

    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "tribunal.blend"))

    render(scene, camera("frontal", (-8.0, -58.0, 12.5), (0.0, -1.0, 12.0), 33), f"{RENDER_SUBDIR}/tribunal-frontal.png")
    render(scene, camera("aereo", (-33.0, -49.0, 47.0), (0.0, 0.0, 11.0), 35), f"{RENDER_SUBDIR}/tribunal-aereo.png")

    for part in figure:
        part.hide_render = False
    render(scene, camera("comparacion", (-22.0, -48.0, 17.0), (0.0, -2.0, 12.0), 33), f"{RENDER_SUBDIR}/tribunal-comparacion.png")
    print("TRIBUNAL_DONE")


if __name__ == "__main__":
    main()

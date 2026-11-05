"""Ficha moto: token de vehiculo de Flip the Table.

Moto caricaturesca y de juguete: neumaticos gordos, deposito grande y musculoso, manillar alto y ancho,
guardabarros con arcos reales y escape cromado por los dos costados. Sin sidecar, sin marcas, sin
logotipos ni matriculas: la trasera lleva un panel oscuro, una banda crema y un piloto, nada legible.

Salidas, en art/blender/tokens/moto/:
  moto_body_<material>.fbx     carroceria, una malla por material (origen en el centro de la base)
  moto_plate.fbx               plataforma del asiento sobre la rueda trasera: se tine con el color del jugador
  moto_wheel_{f,r}.fbx         neumatico, con el origen en su eje de giro (eje X)
  moto_hub_{f,r}.fbx           tapacubos de acero, en malla aparte, mismo origen y eje que su rueda
  moto_LOD1.fbx                una sola malla y un solo material (color de carroceria)
  stats.json                   triangulos por pieza, total y LOD1, medidas, ejes, seat
Y en art/render/tokens/moto/: 3/4 frontal, 3/4 trasera y perfil con avatar de 6 studs al lado.

Convenciones (como taxi.py): 1 unidad de Blender = 1 stud, el morro mira a -Y, Z hacia arriba, origen en
el centro de la base a ras de suelo, exportacion FBX con Z Forward / Y Up. Paleta de art/guia-de-estilo.md:
carroceria en Agua (#3E7FA6, tabla 2.2), caliza EDE5D3, asfalto 2A2E33, cristal 7FB2D9, acero A8AEB4,
rojo senal C4382B y placa EDEAE3.

Uso (segundo plano, sin abrir Blender):
  "D:\\blender\\blender.exe" --background --factory-startup --python art/blender/tokens/moto.py
"""

import glob
import json
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "moto")
RENDER = os.path.join(REPO, "art", "render", "tokens", "moto")

LOD_RATIO = 0.5
TOTAL_BUDGET = 3000
PART_BUDGET = 120  # rueda con su tapacubos
LIMITS = {"ancho_x": 5.0, "largo_y": 11.0, "alto_z": 5.5}  # medidas maximas del encargo

# Ruedas: origen en el eje de giro, en studs, relativo a la base. f = delante (-Y), r = detras (+Y).
WHEEL_AXLES = {
    "f": (0.0, -3.55, 1.45),
    "r": (0.0, 3.30, 1.70),
}
WHEEL_RADIUS = {"f": 1.45, "r": 1.70}
WHEEL_WIDTH = {"f": 1.15, "r": 1.40}
HUB_RADIUS = {"f": 0.52, "r": 0.60}
HUB_WIDTH = {"f": 1.21, "r": 1.46}
WHEEL_SEGMENTS = 20
HUB_SEGMENTS = 10

# Guardabarros: arcos de verdad alrededor del neumatico, no cajas encima de la rueda.
FRONT_FENDER = {"r_in": 1.485, "r_out": 1.60, "half": 0.76, "a0": 40.0, "a1": 170.0, "segments": 10}
FRONT_TIP = {"r_in": 1.595, "r_out": 1.625, "half": 0.19, "a0": 50.0, "a1": 160.0, "segments": 6}
REAR_FENDER = {"r_in": 1.74, "r_out": 1.86, "half": 1.10, "a0": -25.0, "a1": 195.0, "segments": 10}

# Deposito: estaciones (y, medio ancho, z inferior, z superior). El morro es el -Y.
TANK_STATIONS = [
    (-2.15, 0.42, 2.94, 3.28),
    (-1.80, 0.70, 2.74, 3.60),
    (-1.25, 0.94, 2.56, 3.88),
    (-0.55, 1.04, 2.48, 4.02),
    (0.15, 0.98, 2.52, 3.96),
    (0.75, 0.74, 2.66, 3.76),
    (1.05, 0.48, 2.80, 3.56),
]
# Motor: masa oscura bajo el deposito, entre las dos ruedas.
ENGINE_STATIONS = [
    (-1.30, 0.40, 1.30, 2.42),
    (-1.00, 0.68, 1.02, 2.54),
    (-0.20, 0.76, 0.95, 2.56),
    (0.70, 0.72, 1.00, 2.48),
    (1.15, 0.46, 1.22, 2.30),
]
# Cola: plataforma ancha sobre la rueda trasera que sostiene la placa del asiento. El lomo es plano y
# llega de lado a lado, para que la placa apoye entera; la panza se estrecha y muere sobre el guardabarros.
DECK_STATIONS = [
    (0.95, 0.70, 2.95, 3.28),
    (1.10, 1.50, 3.00, 3.58),
    (1.18, 2.15, 3.06, 3.82),
    (2.10, 2.15, 3.36, 3.82),
    (3.30, 2.15, 3.44, 3.82),
    (4.60, 2.14, 3.30, 3.82),
    (5.45, 2.13, 3.02, 3.82),
    (5.62, 1.85, 2.70, 3.78),
]
DECK_TOP = 3.82

# Placa del asiento: 4,02 x 4,02, encajada en el lomo de la cola (deja labio azul todo alrededor) y con
# la cara superior a 3,86. Es la superficie donde se sube el avatar: nada por encima de ella.
PLATE_SIZE = (4.02, 4.02, 0.12)
PLATE_CENTER = (0.0, 3.32, 3.80)
SEAT_Z = PLATE_CENTER[2] + PLATE_SIZE[2] / 2

# Manillar alto: corona, torretas, barra con las puntas subidas, punos y espejos.
FORK_X = 0.78
CROWN = (0.0, -2.38, 4.06)
BAR = {"y": -2.60, "z": 4.80, "half": 0.80, "radius": 0.135, "end_z": 5.00, "end": 2.25}
GRIP = {"inner": 1.84, "outer": 2.25, "radius": 0.18}
MIRROR = {"x": 1.87, "y": -2.76, "z": 5.22, "radius": 0.21}
HEADLIGHT = {"y": -2.72, "z": 3.48, "radius": 0.50}

# Escape: cabezal que baja del motor y silencioso largo por cada costado, cromados.
EXHAUST = {"x": 1.18, "z": 1.22, "radius": 0.23, "y0": 2.25, "y1": 4.75}

MATERIAL_COLORS = {
    "moto": ("3E7FA6", 0.35, 0.0),
    "cream": ("EDE5D3", 0.6, 0.0),
    "dark": ("2A2E33", 0.6, 0.0),
    "glass": ("7FB2D9", 0.12, 0.0),
    "steel": ("A8AEB4", 0.25, 0.8),
    "red": ("C4382B", 0.7, 0.0),
    "plate": ("EDEAE3", 0.5, 0.0),
    "ground": ("8E9196", 0.9, 0.0),
}


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
    select_only(obj)
    modifier = obj.modifiers.new("Bevel", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(35)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def loft(name, stations, mat):
    """Piel entre estaciones: cada estacion es una lista cerrada de vertices con el mismo numero de puntos."""
    n = len(stations[0])
    verts = [point for station in stations for point in station]
    faces = []
    for k in range(len(stations) - 1):
        for i in range(n):
            a = k * n + i
            b = k * n + (i + 1) % n
            faces.append((a, b, b + n, a + n))
    faces.append(tuple(range(n - 1, -1, -1)))
    faces.append(tuple(range((len(stations) - 1) * n, len(stations) * n)))
    return mesh_object(name, verts, faces, mat)


def section(y, half_width, z_bottom, z_top):
    """Seccion octogonal en X: lomo plano arriba, costados verticales y base plana."""
    w, b, t = half_width, z_bottom, z_top
    h = t - b
    return [
        (-0.62 * w, y, b),
        (-w, y, b + 0.26 * h),
        (-w, y, t - 0.30 * h),
        (-0.62 * w, y, t),
        (0.62 * w, y, t),
        (w, y, t - 0.30 * h),
        (w, y, b + 0.26 * h),
        (0.62 * w, y, b),
    ]


def haunch_section(y, half_width, z_bottom, z_top):
    """Seccion de anca: lomo plano de lado a lado y costados que se meten hacia la rueda."""
    w, b, t = half_width, z_bottom, z_top
    h = t - b
    return [
        (-w, y, t),
        (w, y, t),
        (w, y, t - 0.06),
        (0.88 * w, y, t - 0.42 * h),
        (0.58 * w, y, b),
        (-0.58 * w, y, b),
        (-0.88 * w, y, t - 0.42 * h),
        (-w, y, t - 0.06),
    ]


def arc_stations(axle, r_in, r_out, half, a0, a1, segments):
    """Estaciones de un guardabarros: seccion rectangular radial barrida a lo largo del arco de la rueda."""
    stations = []
    for i in range(segments + 1):
        angle = math.radians(a0 + (a1 - a0) * i / segments)
        cy, cz = math.cos(angle), math.sin(angle)
        stations.append(
            [
                (-half, axle[0] + r_in * cy, axle[1] + r_in * cz),
                (half, axle[0] + r_in * cy, axle[1] + r_in * cz),
                (half, axle[0] + r_out * cy, axle[1] + r_out * cz),
                (-half, axle[0] + r_out * cy, axle[1] + r_out * cz),
            ]
        )
    return stations


def fender(name, axle, spec, mat):
    """Arco real sobre el neumatico, con sus dos bocas cerradas."""
    return loft(name, arc_stations(axle, spec["r_in"], spec["r_out"], spec["half"], spec["a0"], spec["a1"], spec["segments"]), mat)


def cyl(name, center, radius, depth, verts, mat, axis="X"):
    rotations = {"X": (0, math.radians(90), 0), "Y": (math.radians(90), 0, 0), "Z": (0, 0, 0)}
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts, radius=radius, depth=depth, location=center, rotation=rotations[axis]
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(mat)
    return obj


def rod(name, p0, p1, radius, verts, mat):
    """Cilindro entre dos puntos, con la posicion y el giro horneados en la malla."""
    start, end = Vector(p0), Vector(p1)
    delta = end - start
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=delta.length, location=(start + end) / 2)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = delta.to_track_quat("Z", "Y")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(mat)
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


def build_fenders(mats):
    return [
        fender("fender_f", (WHEEL_AXLES["f"][1], WHEEL_AXLES["f"][2]), FRONT_FENDER, mats["moto"]),
        fender("fender_f_tip", (WHEEL_AXLES["f"][1], WHEEL_AXLES["f"][2]), FRONT_TIP, mats["cream"]),
        fender("fender_r", (WHEEL_AXLES["r"][1], WHEEL_AXLES["r"][2]), REAR_FENDER, mats["moto"]),
    ]


def build_front(mats):
    """Horquilla, corona, faro, manillar alto y espejos: la parte que hace legible la moto de frente."""
    axle_y, axle_z = WHEEL_AXLES["f"][1], WHEEL_AXLES["f"][2]
    head_y, head_z = CROWN[1] + 0.06, CROWN[2]
    parts = [
        bevel(box("neck", (0.90, 0.70, 0.90), (0.0, -2.20, 3.62), mats["dark"]), 0.08),
        bevel(box("crown", (1.85, 0.45, 0.24), CROWN, mats["dark"]), 0.04, segments=1),
        rod("axle_f", (-0.90, axle_y, axle_z), (0.90, axle_y, axle_z), 0.08, 8, mats["steel"]),
        # Barra central, puntas subidas y travesano entre torretas: el manillar alto de la caricatura.
        rod("handlebar", (-BAR["half"], BAR["y"], BAR["z"]), (BAR["half"], BAR["y"], BAR["z"]), BAR["radius"], 8, mats["steel"]),
        rod("brace", (-0.42, -2.46, 4.46), (0.42, -2.46, 4.46), 0.06, 6, mats["steel"]),
    ]
    for side in (-1, 1):
        x = side * FORK_X
        parts.append(rod("fork", (x, head_y, head_z), (x, axle_y, axle_z), 0.115, 8, mats["steel"]))
        parts.append(rod("slider", (x, -2.54, 3.60), (x, -3.36, 1.86), 0.155, 8, mats["dark"]))
        parts.append(rod("riser", (side * 0.44, -2.44, 4.10), (side * 0.44, -2.58, 4.74), 0.11, 8, mats["steel"]))
        parts.append(rod("bar_bend", (side * BAR["half"], BAR["y"], BAR["z"]), (side * BAR["end"], -2.62, BAR["end_z"]), BAR["radius"], 8, mats["steel"]))
        parts.append(rod("grip", (side * GRIP["inner"], -2.62, BAR["end_z"]), (side * GRIP["outer"], -2.62, BAR["end_z"]), GRIP["radius"], 8, mats["dark"]))
        parts.append(rod("mirror_stalk", (side * 1.58, -2.62, 4.94), (side * MIRROR["x"], MIRROR["y"], MIRROR["z"] - 0.03), 0.05, 6, mats["steel"]))
        parts.append(cyl("mirror", (side * MIRROR["x"], MIRROR["y"], MIRROR["z"]), MIRROR["radius"], 0.07, 10, mats["steel"], axis="Y"))
    # Faro: carcasa de acero, aro oscuro y lente de cristal grande, mirando al morro.
    parts.append(cyl("headlight", (0.0, HEADLIGHT["y"], HEADLIGHT["z"]), HEADLIGHT["radius"], 0.40, 12, mats["steel"], axis="Y"))
    parts.append(cyl("headlight_ring", (0.0, HEADLIGHT["y"] - 0.18, HEADLIGHT["z"]), HEADLIGHT["radius"] + 0.05, 0.10, 12, mats["dark"], axis="Y"))
    parts.append(cyl("lens", (0.0, HEADLIGHT["y"] - 0.25, HEADLIGHT["z"]), HEADLIGHT["radius"] - 0.08, 0.09, 12, mats["glass"], axis="Y"))
    return parts


def build_engine(mats):
    parts = [loft("engine", [section(y, hw, zb, zt) for y, hw, zb, zt in ENGINE_STATIONS], mats["dark"])]
    # Aletas de refrigeracion y tapas laterales del motor.
    for z in (1.52, 1.80, 2.08):
        parts.append(box("engine_fin", (1.60, 0.50, 0.05), (0.0, 0.30, z), mats["steel"]))
    for side in (-1, 1):
        parts.append(cyl("engine_cover", (side * 0.78, -0.45, 1.58), 0.38, 0.10, 10, mats["steel"]))
        parts.append(cyl("engine_cap", (side * 0.84, -0.45, 1.58), 0.15, 0.06, 8, mats["dark"]))
    # Basculante: barra transversal y dos brazos hasta el eje trasero.
    parts.append(bevel(box("swing_pivot", (1.95, 0.30, 0.34), (0.0, 1.02, 1.60), mats["dark"]), 0.05))
    for side in (-1, 1):
        parts.append(rod("swingarm", (side * 0.88, 1.05, 1.62), (side * 0.88, WHEEL_AXLES["r"][1], WHEEL_AXLES["r"][2]), 0.10, 8, mats["dark"]))
    parts.append(rod("axle_r", (-1.00, WHEEL_AXLES["r"][1], WHEEL_AXLES["r"][2]), (1.00, WHEEL_AXLES["r"][1], WHEEL_AXLES["r"][2]), 0.08, 8, mats["steel"]))
    # Estriberas y espina que une la direccion con la cola por debajo del deposito.
    parts.append(rod("footpeg", (-1.22, 0.60, 1.45), (1.22, 0.60, 1.45), 0.09, 8, mats["steel"]))
    parts.append(bevel(box("spine", (0.56, 5.00, 0.50), (0.0, -0.50, 2.95), mats["dark"]), 0.06))
    return parts


def build_tank(mats):
    parts = [loft("tank", [section(y, hw, zb, zt) for y, hw, zb, zt in TANK_STATIONS], mats["moto"])]
    # Franja crema en el lomo, siguiendo la curva del deposito.
    stripe = [
        [(-0.17, y, zt - 0.03), (0.17, y, zt - 0.03), (0.17, y, zt + 0.02), (-0.17, y, zt + 0.02)]
        for y, _hw, _zb, zt in TANK_STATIONS
    ]
    parts.append(loft("tank_stripe", stripe, mats["cream"]))
    parts.append(cyl("tank_cap", (0.0, -1.10, 4.01), 0.20, 0.08, 10, mats["steel"], axis="Z"))
    # Paneles de rodilla crema a los costados, siguiendo la chapa del deposito (sin flotar).
    for side in (-1, 1):
        stations = []
        for y, hw, _zb, _zt in TANK_STATIONS[1:6]:
            inner, outer = side * (hw - 0.03), side * (hw + 0.018)
            stations.append([(inner, y, 3.00), (outer, y, 3.00), (outer, y, 3.34), (inner, y, 3.34)])
        parts.append(loft("knee_panel", stations, mats["cream"]))
    return parts


def build_tail(mats):
    parts = [loft("deck", [haunch_section(y, hw, zb, zt) for y, hw, zb, zt in DECK_STATIONS], mats["moto"])]
    # Trasera con relieve: panel oscuro hundido con el piloto, banda crema y faldon.
    parts.append(box("tail_panel", (2.60, 0.10, 0.42), (0.0, 5.64, 3.40), mats["dark"]))
    parts.append(box("taillight", (1.50, 0.07, 0.16), (0.0, 5.70, 3.40), mats["red"]))
    parts.append(box("tail_band", (2.40, 0.07, 0.10), (0.0, 5.67, 3.02), mats["cream"]))
    parts.append(bevel(box("mudflap", (1.40, 0.09, 0.62), (0.0, 5.60, 2.42), mats["dark"]), 0.03, segments=1))
    for side in (-1, 1):
        parts.append(box("deck_bolt", (0.09, 0.09, 0.09), (side * 1.25, 5.67, 3.22), mats["steel"]))
    # Escape doble: cabezal que baja del motor y silencioso cromado por cada costado.
    for side in (-1, 1):
        parts.append(cyl("muffler", (side * EXHAUST["x"], (EXHAUST["y0"] + EXHAUST["y1"]) / 2, EXHAUST["z"]), EXHAUST["radius"], EXHAUST["y1"] - EXHAUST["y0"], 10, mats["steel"], axis="Y"))
        parts.append(cyl("muffler_tip", (side * EXHAUST["x"], EXHAUST["y1"], EXHAUST["z"]), EXHAUST["radius"] - 0.07, 0.06, 10, mats["dark"], axis="Y"))
        parts.append(rod("header", (side * 0.62, -1.10, 2.20), (side * EXHAUST["x"], EXHAUST["y0"] - 0.10, EXHAUST["z"] + 0.04), 0.11, 8, mats["steel"]))
        parts.append(rod("exhaust_pipe", (side * EXHAUST["x"], EXHAUST["y0"] - 0.10, EXHAUST["z"] + 0.04), (side * EXHAUST["x"], EXHAUST["y1"], EXHAUST["z"]), 0.11, 8, mats["steel"]))
    return parts


def build_body(mats):
    parts = []
    parts += build_fenders(mats)
    parts += build_front(mats)
    parts += build_engine(mats)
    parts += build_tank(mats)
    parts += build_tail(mats)
    return parts


def build_plate(mats):
    return bevel(box("moto_plate", PLATE_SIZE, PLATE_CENTER, mats["plate"]), 0.03)


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

    mats = {name: flat(name, *spec) for name, spec in MATERIAL_COLORS.items()}

    body = group_by_material(build_body(mats), "moto_body")
    plate = build_plate(mats)
    wheels = {key: wheel_part(f"moto_wheel_{key}", WHEEL_RADIUS[key], WHEEL_WIDTH[key], WHEEL_SEGMENTS, mats["dark"]) for key in WHEEL_AXLES}
    hubs = {key: wheel_part(f"moto_hub_{key}", HUB_RADIUS[key], HUB_WIDTH[key], HUB_SEGMENTS, mats["steel"]) for key in WHEEL_AXLES}

    # Comprobaciones antes de exportar.
    entries = [(obj, (0.0, 0.0, 0.0)) for obj in body.values()] + [(plate, (0.0, 0.0, 0.0))]
    entries += [(wheels[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    entries += [(hubs[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    lo, hi = bounds(entries)
    plate_lo, plate_hi = bounds([(plate, (0.0, 0.0, 0.0))])
    seat = (round((plate_lo[0] + plate_hi[0]) / 2, 4), round((plate_lo[1] + plate_hi[1]) / 2, 4), round(plate_hi[2], 4))
    width, length, height = hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]
    assert width <= LIMITS["ancho_x"] + 1e-6, f"ancho {width:.2f} por encima de {LIMITS['ancho_x']}"
    assert length <= LIMITS["largo_y"] + 1e-6, f"largo {length:.2f} por encima de {LIMITS['largo_y']}"
    assert height <= LIMITS["alto_z"] + 1e-6, f"alto {height:.2f} por encima de {LIMITS['alto_z']}"
    assert abs(lo[2]) < 1e-6, f"min_z {lo[2]:.4f}, la moto no apoya en el suelo"
    assert plate_hi[0] - plate_lo[0] >= 4.0 - 1e-6 and plate_hi[1] - plate_lo[1] >= 4.0 - 1e-6, "placa menor de 4 x 4"
    assert abs(seat[2] - SEAT_Z) < 1e-6, "el seat no coincide con la cara superior de la placa"
    for key, (x, y, z) in WHEEL_AXLES.items():
        assert abs(z - WHEEL_RADIUS[key]) < 1e-6, f"la rueda {key} no toca el suelo"
        assert abs(x) < 1e-6, f"la rueda {key} no esta centrada"
    # Nada por encima de la placa dentro de su huella.
    for obj in body.values():
        for vertex in obj.data.vertices:
            if plate_lo[0] - 0.02 <= vertex.co.x <= plate_hi[0] + 0.02 and plate_lo[1] - 0.02 <= vertex.co.y <= plate_hi[1] + 0.02:
                assert vertex.co.z <= plate_hi[2] + 1e-6, f"{obj.name} invade la placa por encima de {plate_hi[2]:.2f}"
    for key in WHEEL_AXLES:
        assert count(wheels[key]) + count(hubs[key]) <= PART_BUDGET, f"rueda {key} por encima de {PART_BUDGET}"
    for obj in [*body.values(), plate, *wheels.values(), *hubs.values()]:
        assert len(obj.data.materials) == 1, f"{obj.name} tiene varios materiales"

    # LOD1: una sola malla con un solo material (carroceria), reducida al 50 %.
    blue = body["moto"]
    lod_parts = [lod_copy(blue, (0.0, 0.0, 0.0), mats["moto"])]
    lod_parts += [lod_copy(wheels[key], WHEEL_AXLES[key], mats["moto"]) for key in WHEEL_AXLES]
    lod = join(lod_parts, "moto_LOD1")
    select_only(lod)
    bpy.ops.object.material_slot_remove_unused()
    assert len(lod.data.materials) == 1, "el LOD1 tiene mas de un material"

    # Las ruedas y los tapacubos se exportan con su origen en el eje y ya colocados en su sitio de la
    # moto. Asi Roblox los deja en el eje al cargarlos (el FBX lleva la traslacion del objeto) y siguen
    # girando alrededor de su propio centro. Sin esto, las dos caen en (0,0,0).
    for key in WHEEL_AXLES:
        wheels[key].location = WHEEL_AXLES[key]
        hubs[key].location = WHEEL_AXLES[key]

    files = {}
    for obj in body.values():
        export(obj, f"{obj.name}.fbx")
        files[obj.name] = count(obj)
    export(plate, "moto_plate.fbx")
    files["moto_plate"] = count(plate)
    for key in WHEEL_AXLES:
        export(wheels[key], f"moto_wheel_{key}.fbx")
        export(hubs[key], f"moto_hub_{key}.fbx")
        files[f"moto_wheel_{key}"] = count(wheels[key])
        files[f"moto_hub_{key}"] = count(hubs[key])
    export(lod, "moto_LOD1.fbx")
    total = sum(files.values())
    lod_triangles = count(lod)
    assert total <= TOTAL_BUDGET, f"{total} triangulos, por encima de {TOTAL_BUDGET}"
    assert lod_triangles <= total / 2, f"LOD1 con {lod_triangles}, mas de la mitad de {total}"

    stats = {
        "modelo": "moto",
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
            "limites": LIMITS,
            "plataforma_z": DECK_TOP,
            "deposito": {
                "inicio_y": TANK_STATIONS[0][0],
                "fin_y": TANK_STATIONS[-1][0],
                "z_superior": max(station[3] for station in TANK_STATIONS),
                "ancho_max": round(2 * max(station[1] for station in TANK_STATIONS), 3),
            },
            "manillar": {
                "y": BAR["y"],
                "z": BAR["end_z"],
                "ancho": round(width, 3),  # el manillar es la pieza mas ancha de la moto
            },
            "placa": {
                "tamano_x": round(plate_hi[0] - plate_lo[0], 3),
                "tamano_y": round(plate_hi[1] - plate_lo[1], 3),
                "z_inferior": round(plate_lo[2], 4),
                "z_superior": round(plate_hi[2], 4),
                "centro_xy": [PLATE_CENTER[0], PLATE_CENTER[1]],
            },
        },
        "seat": list(seat),
        "ruedas": {
            key: {
                "archivo": f"moto_wheel_{key}.fbx",
                "tapacubos": f"moto_hub_{key}.fbx",
                "eje": list(WHEEL_AXLES[key]),
                "giro": "X",
                "radio": WHEEL_RADIUS[key],
                "ancho": WHEEL_WIDTH[key],
            }
            for key in WHEEL_AXLES
        },
        "materiales": {
            **{obj.name: obj.data.materials[0].name for obj in body.values()},
            "moto_plate": "plate",
            **{f"moto_wheel_{key}": "dark" for key in WHEEL_AXLES},
            **{f"moto_hub_{key}": "steel" for key in WHEEL_AXLES},
            "moto_LOD1": "moto",
        },
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("MOTO_STATS", json.dumps(stats))

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

    render(scene, camera("frontal", (-12.0, -21.0, 12.0), (0.0, 0.0, 2.6), lens=50), "moto-3-4-frontal.png")
    render(scene, camera("trasera", (12.0, 21.0, 12.0), (0.0, 0.0, 2.6), lens=50), "moto-3-4-trasera.png")
    for obj in avatar:
        obj.hide_render = False
    render(scene, camera("perfil", (60.0, 4.0, 3.0), (0.0, 4.0, 3.0), ortho_scale=26.0), "moto-perfil-avatar.png")
    print("MOTO_RENDERS_OK")


if __name__ == "__main__":
    main()

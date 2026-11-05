"""Ficha limusina: vehiculo de representacion de Flip the Table.

Limusina negra formal, muy larga y baja, de tres volumenes: capo corto, cabina acristalada larga con
cinco ventanillas por lado y cuatro puertas, maletero plano y trasera vertical con pilotos verticales.
Cromados finos (parachoques, parrilla, cintura, faldon, manillas, marcos de faros y pilotos), cristales
tintados con marco oscuro en relieve y montantes, y guardabarros con arco real alrededor del neumatico.
Sin marcas, logotipos, texto ni matriculas.

Salidas, en art/blender/tokens/limusina/:
  limo_body_<material>.fbx     carroceria, una malla por material (origen en el centro de la base)
  limo_plate.fbx               placa del techo, separada: se tine con el color del jugador
  limo_wheel_{fl,fr,rl,rr}.fbx neumatico, con el origen en su eje de giro (eje X)
  limo_hub_{fl,fr,rl,rr}.fbx   tapacubos, en malla aparte, mismo origen y eje que su rueda
  limo_LOD1.fbx                una sola malla y un solo material (color de carroceria)
  stats.json                   triangulos por pieza, total y LOD1, medidas, ejes de rueda y seat
Y en art/render/tokens/limusina/: 3/4 frontal, 3/4 trasera y perfil con avatar de 6 studs al lado.

Convenciones (las mismas que taxi.py): 1 unidad de Blender = 1 stud, el morro mira a -Y, Z hacia
arriba, origen en el centro de la base a ras de suelo, exportacion FBX con Z Forward / Y Up.

Uso (segundo plano, sin abrir Blender):
  "D:\\blender\\blender.exe" --background --factory-startup --python art/blender/tokens/limusina.py
"""

import glob
import json
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "limusina")
RENDER = os.path.join(REPO, "art", "render", "tokens", "limusina")

LOD_RATIO = 0.5
TOTAL_BUDGET = 3000
PART_BUDGET = 120  # rueda con su tapacubos
# Taxi validado en Studio el 2026-11-05: familia de referencia, no un limite.
PREVIOUS = {"triangles": 2580, "size_x": 6.4, "size_y": 12.4, "size_z": 5.1}
MAX_SIZE = (6.5, 16.0, 5.0)  # ancho, largo, alto: limite duro del encargo

# Ruedas: origen en el eje de giro, en studs, relativo a la base. l = -X, r = +X (de frente).
WHEEL_AXLES = {
    "fl": (-2.66, -5.40, 1.0),
    "fr": (2.66, -5.40, 1.0),
    "rl": (-2.66, 5.40, 1.0),
    "rr": (2.66, 5.40, 1.0),
}
AXLE_Z = 1.0
WHEEL_RADIUS = 1.0
WHEEL_DEPTH = 0.82
HUB_RADIUS = 0.54
HUB_DEPTH = 0.86
CAP_RADIUS = 0.20
CAP_DEPTH = 0.90
ARCH_R = 1.13  # radio interior del arco del guardabarros, por fuera del neumatico
ARCH_TRIM_R = 1.145  # moldura cromada del paso de rueda
FENDER_OUT = 0.15

# Carroceria: 15,4 de largo; los parachoques llegan a +-8,00 (16,00 en total).
BODY_HALF = 3.00
FRONT_Y = -7.70
REAR_Y = 7.70
SILL_Z = 0.80
BELT_Z = 2.86
ROOF_Z = 4.30
BODY_POINTS = [
    (FRONT_Y, SILL_Z), (FRONT_Y, 2.32), (-7.30, 2.56), (-6.30, 2.60), (-5.10, 2.64),
    (-4.80, BELT_Z), (REAR_Y, BELT_Z), (REAR_Y, SILL_Z),
]

# Cabina: acristalada larga, mas estrecha que la carroceria (hombro de 0,28 por lado).
CABIN_HALF = 2.72
CABIN_POINTS = [(-4.80, 2.80), (-3.45, ROOF_Z), (4.40, ROOF_Z), (5.20, 2.80)]
WINDSHIELD_P0 = (-4.71, 2.90)
WINDSHIELD_P1 = (-3.52, 4.22)
BACKLIGHT_P0 = (4.44, 4.20)
BACKLIGHT_P1 = (5.15, 2.90)
GLASS_HALF = 2.36
FRAME_HALF = 2.55

# Ventanillas laterales: cinco por lado y cuatro puertas. La banda va de WIN_Y0 a WIN_Y1.
WIN_Y0, WIN_Y1 = -3.40, 4.20
WIN_Z0, WIN_Z1 = 2.98, 4.08
PANE_COUNT = 5
MULLION = 0.16
PANE = ((WIN_Y1 - WIN_Y0) - (PANE_COUNT - 1) * MULLION) / PANE_COUNT
HANDLE_Z = 2.60
DOOR_SEAM_Z = (1.06, 2.80)

# Techo: zona plana bajo la placa (4,6 x 5,6, cabe de sobra en el techo de 7,9 de largo).
PLATE_SIZE = (4.6, 5.6, 0.12)
PLATE_CENTER = (0.0, 0.35, ROOF_Z + 0.06)
SEAT_Z = ROOF_Z + 0.12


def panes():
    out, y = [], WIN_Y0
    for _ in range(PANE_COUNT):
        out.append((y, y + PANE))
        y += PANE + MULLION
    return out


MULLION_Y = [WIN_Y0 + PANE + MULLION / 2 + i * (PANE + MULLION) for i in range(PANE_COUNT - 1)]
HANDLE_Y = [(y0 + y1) / 2 for y0, y1 in panes()][:4]


def srgb(hex_color):
    def channel(value):
        value /= 255.0
        return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4

    return tuple(channel(int(hex_color[i : i + 2], 16)) for i in (0, 2, 4))


def flat(name, hex_color, roughness=0.5, metallic=0.0, specular=0.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*srgb(hex_color), 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = specular
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
    """Bisel en los bordes de angulo vivo (mas de 35 grados): redondea las formas grandes."""
    select_only(obj)
    modifier = obj.modifiers.new("Bevel", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(35)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def profile(name, points, half_width, mat):
    """Prisma con el perfil lateral `points` (y, z), de lado a lado del vehiculo."""
    verts = [(-half_width, y, z) for y, z in points] + [(half_width, y, z) for y, z in points]
    n = len(points)
    faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return mesh_object(name, verts, faces, mat)


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


def bar_on_slope(name, p0, p1, t, x, length, width, thickness, mat, frac=0.5):
    """Barra pegada a una superficie inclinada (montante, limpiaparabrisas): sigue su pendiente."""
    dy, dz = p1[0] - p0[0], p1[1] - p0[1]
    span = math.hypot(dy, dz)
    uy, uz = dy / span, dz / span
    ny, nz = -uz, uy
    cy = p0[0] + dy * frac + ny * t
    cz = p0[1] + dz * frac + nz * t
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, cy, cz))
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (width, thickness, length)
    obj.rotation_euler = (math.atan2(-dy, dz), 0, 0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(mat)
    return obj


def arch_trim(name, axle_y, side, mat, segments=9):
    """Moldura cromada del paso de rueda: aro plano pegado a la chapa, por fuera del neumatico.

    Es una superficie abierta: el orden de las caras fija la normal hacia fuera del coche, asi que
    no se recalcula (close_normals la dejaria mirando hacia dentro).
    """
    a0, a1 = math.radians(178.0), math.radians(2.0)
    x = side * (BODY_HALF + 0.05)
    verts, faces = [], []
    for i in range(segments + 1):
        a = a0 + (a1 - a0) * i / segments
        verts.append((x, axle_y + 1.005 * math.cos(a), AXLE_Z + 1.005 * math.sin(a)))
    for i in range(segments + 1):
        a = a0 + (a1 - a0) * i / segments
        verts.append((x, axle_y + ARCH_TRIM_R * math.cos(a), AXLE_Z + ARCH_TRIM_R * math.sin(a)))
    n = segments + 1
    for i in range(segments):
        quad = (i, i + 1, n + i + 1, n + i)
        faces.append(quad if side < 0 else tuple(reversed(quad)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    return obj


def fender(name, axle_y, side, mat, segments=7):
    """Guardabarros integrado: labio que nace y muere dentro de la chapa y corona el arco real."""
    a0, a1 = math.radians(176.0), math.radians(4.0)
    base = BODY_HALF - 0.03
    verts, faces = [], []
    rows = segments + 1
    for i in range(rows):
        t = i / segments
        a = a0 + (a1 - a0) * t
        s = math.sin(math.pi * t) ** 0.6
        y = axle_y + ARCH_R * math.cos(a)
        z = AXLE_Z + ARCH_R * math.sin(a)
        out = FENDER_OUT * s + 0.005
        section = [
            (side * base, y, z),
            (side * (base + out), y, z + 0.015 * s),
            (side * (base + out * 0.88), y, z + 0.05 + 0.19 * s),
            (side * base, y, z + 0.07 + 0.25 * s),
        ]
        verts += section
    for k in range(segments):
        for j in range(4):
            a = k * 4 + j
            b = k * 4 + (j + 1) % 4
            c = (k + 1) * 4 + (j + 1) % 4
            d = (k + 1) * 4 + j
            faces.append((a, b, c, d))
    faces.append((0, 1, 2, 3))
    faces.append(tuple((rows - 1) * 4 + j for j in (3, 2, 1, 0)))
    return mesh_object(name, verts, faces, mat)


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


def build_shell(mats):
    parts = []
    parts.append(bevel(profile("body", BODY_POINTS, BODY_HALF, mats["negro"]), 0.18))
    parts.append(bevel(profile("greenhouse", CABIN_POINTS, CABIN_HALF, mats["negro"]), 0.12))
    # Montantes de la cabina: separan las cinco ventanillas y marcan las puertas.
    for side in (-1, 1):
        for y in MULLION_Y:
            parts.append(
                box("mullion", (0.13, MULLION, WIN_Z1 - WIN_Z0 + 0.08),
                    (side * (CABIN_HALF + 0.045), y, (WIN_Z0 + WIN_Z1) / 2), mats["negro"])
            )
    # Guardabarros con arco real, en las cuatro ruedas.
    for key in WHEEL_AXLES:
        side = -1 if key.endswith("l") else 1
        parts.append(fender("fender", WHEEL_AXLES[key][1], side, mats["negro"]))
    # Bajo de la carroceria: cierra el hueco entre las ruedas y da sombra bajo el faldon.
    parts.append(box("underbody", (4.8, 14.2, 0.26), (0, 0, 0.65), mats["dark"]))
    return parts


def build_windows(mats):
    parts = []
    # Ventanillas: marco oscuro en relieve (0,07) y cristal 0,03 por delante, dentro del marco.
    for side in (-1, 1):
        for y0, y1 in panes():
            w, yc = y1 - y0, (y0 + y1) / 2
            h, zc = WIN_Z1 - WIN_Z0, (WIN_Z0 + WIN_Z1) / 2
            parts.append(
                box("window_frame", (0.07, w + 0.14, h + 0.14),
                    (side * (CABIN_HALF + 0.035), yc, zc), mats["dark"])
            )
            parts.append(
                box("window_glass", (0.03, w, h), (side * (CABIN_HALF + 0.085), yc, zc), mats["glass"])
            )
        # Junta de puerta: linea oscura de la cintura al faldon, alineada con cada montante.
        for y in MULLION_Y:
            z0, z1 = DOOR_SEAM_Z
            parts.append(
                box("door_seam", (0.03, 0.06, z1 - z0), (side * (BODY_HALF + 0.005), y, (z0 + z1) / 2),
                    mats["dark"])
            )
        # Manillas cromadas, una por puerta.
        for y in HANDLE_Y:
            parts.append(
                box("handle", (0.06, 0.30, 0.09), (side * (BODY_HALF + 0.012), y, HANDLE_Z), mats["steel"])
            )
    # Parabrisas: marco oscuro y cristal recortado, con montantes de carroceria a los lados.
    parts.append(slope_slab("windshield_frame", WINDSHIELD_P0, WINDSHIELD_P1, 0.0, 0.09, -0.10,
                            FRAME_HALF, mats["dark"]))
    parts.append(slope_slab("windshield", WINDSHIELD_P0, WINDSHIELD_P1, 0.09, 0.14, -0.28,
                            GLASS_HALF, mats["glass"]))
    # Luna trasera partida por un montante central.
    parts.append(slope_slab("rear_frame", BACKLIGHT_P0, BACKLIGHT_P1, 0.0, 0.09, -0.06,
                            FRAME_HALF, mats["dark"]))
    parts.append(slope_slab("rear_glass", BACKLIGHT_P0, BACKLIGHT_P1, 0.09, 0.14, -0.20,
                            GLASS_HALF, mats["glass"]))
    parts.append(bar_on_slope("rear_mullion", (4.46, 4.20), (5.08, 2.96), 0.13, 0.0, 1.32, 0.16, 0.05,
                              mats["negro"]))
    # Limpiaparabrisas, sobre el cristal y en la mitad inferior.
    for x in (-0.82, 0.82):
        parts.append(bar_on_slope("wiper", WINDSHIELD_P0, WINDSHIELD_P1, 0.17, x, 0.72, 0.09, 0.045,
                                  mats["dark"], frac=0.30))
    # Rejillas de ventilacion tras el paso de rueda delantero: detalle de chapa en los dos lados.
    for side in (-1, 1):
        for z in (1.72, 1.84, 1.96):
            parts.append(
                box("fender_vent", (0.04, 0.46, 0.05), (side * (BODY_HALF + 0.008), -3.92, z), mats["steel"])
            )
    return parts


def build_front(mats):
    parts = []
    # Parrilla: marco cromado con panel oscuro rehundido y tres lamas.
    parts.append(box("grille_surround", (3.50, 0.06, 1.04), (0, FRONT_Y - 0.02, 1.76), mats["steel"]))
    parts.append(box("grille_panel", (3.20, 0.10, 0.90), (0, FRONT_Y - 0.045, 1.76), mats["dark"]))
    for z in (1.42, 1.76, 2.10):
        parts.append(box("grille_slat", (2.98, 0.05, 0.08), (0, FRONT_Y - 0.098, z), mats["steel"]))
    # Faros: aro cromado y lente caliza, a los lados de la parrilla.
    for side in (-1, 1):
        parts.append(
            box("headlight_ring", (1.02, 0.08, 0.44), (side * 2.30, FRONT_Y - 0.02, 1.76), mats["steel"])
        )
        parts.append(
            box("headlight_lens", (0.86, 0.10, 0.30), (side * 2.30, FRONT_Y - 0.055, 1.76), mats["cream"])
        )
    # Parachoques cromado, filo del capo y moldura del cobijo.
    parts.append(bevel(box("bumper_f", (6.00, 0.34, 0.44), (0, -7.83, 1.10), mats["steel"]), 0.09))
    parts.append(box("hood_edge", (4.60, 0.06, 0.055), (0, -7.34, 2.56), mats["steel"]))
    parts.append(box("cowl_trim", (5.30, 0.06, 0.07), (0, -4.86, 2.74), mats["steel"]))
    return parts


def build_rear(mats):
    parts = []
    # Pilotos verticales: aro cromado y lente roja.
    for side in (-1, 1):
        parts.append(
            box("taillight_ring", (0.62, 0.08, 1.18), (side * 2.30, REAR_Y + 0.02, 1.80), mats["steel"])
        )
        parts.append(
            box("taillight_lens", (0.46, 0.10, 1.02), (side * 2.30, REAR_Y + 0.055, 1.80), mats["red"])
        )
    # Panel oscuro entre los pilotos: la trasera no queda lisa.
    parts.append(box("rear_panel", (5.10, 0.03, 1.18), (0, REAR_Y + 0.012, 1.80), mats["dark"]))
    parts.append(box("trunk_trim", (5.50, 0.06, 0.10), (0, REAR_Y + 0.015, 2.55), mats["steel"]))
    parts.append(box("rear_lower_trim", (5.60, 0.06, 0.07), (0, REAR_Y + 0.015, 1.42), mats["steel"]))
    parts.append(bevel(box("bumper_b", (6.00, 0.34, 0.44), (0, 7.83, 1.10), mats["steel"]), 0.09))
    # Cola de escape doble, por debajo del parachoques y asomando por detras.
    for side in (-1, 1):
        parts.append(box("exhaust", (0.55, 0.16, 0.13), (side * 1.80, 7.92, 0.78), mats["steel"]))
    # Tapa del maletero: contorno cromado (junta delantera y filo trasero) y tercera luz de freno.
    parts.append(box("trunk_seam", (5.00, 0.05, 0.03), (0, 5.32, BELT_Z + 0.012), mats["steel"]))
    parts.append(box("trunk_lip", (5.60, 0.08, 0.05), (0, 7.44, BELT_Z + 0.02), mats["steel"]))
    parts.append(box("brake_light", (1.50, 0.07, 0.08), (0, 5.16, BELT_Z + 0.03), mats["red"]))
    return parts


def build_trim(mats):
    parts = []
    # Cromados laterales: cintura, faldon y goteron del techo. Acentuan el largo.
    for side in (-1, 1):
        parts.append(
            box("belt_trim", (0.06, 9.80, 0.08), (side * (CABIN_HALF + 0.03), 0.29, 2.90), mats["steel"])
        )
        parts.append(
            box("rocker_trim", (0.06, 8.40, 0.10), (side * (BODY_HALF + 0.005), 0.40, 1.06), mats["steel"])
        )
        parts.append(
            box("drip_rail", (0.05, 7.90, 0.04), (side * 2.66, 0.45, ROOF_Z - 0.02), mats["steel"])
        )
    return parts


def build_body(mats):
    parts = []
    parts += build_shell(mats)
    parts += build_windows(mats)
    parts += build_front(mats)
    parts += build_rear(mats)
    parts += build_trim(mats)
    # Arcos del paso de rueda: moldura cromada pegada a la chapa, dentro del guardabarros.
    for key in WHEEL_AXLES:
        side = -1 if key.endswith("l") else 1
        parts.append(arch_trim("arch_trim", WHEEL_AXLES[key][1], side, mats["steel"]))
    return parts


def build_plate(mats):
    return bevel(box("limo_plate", PLATE_SIZE, PLATE_CENTER, mats["plate"]), 0.02, 1)


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
        # Negro laca: el Asfalto de la guia (#23272C) un punto mas oscuro, no negro puro.
        # Especular bajo para que el reflejo del sol no borre la silueta en los planos horizontales.
        "negro": flat("negro", "191D22", 0.40, 0.10, 0.12),
        # Acero pulido de la guia.
        "steel": flat("steel", "A8AEB4", 0.30, 0.55),
        # Goma y juntas: negro mate, sin negro puro.
        "dark": flat("dark", "101317", 0.65),
        # Cristal tintado: Cristal azul de la guia oscurecido para que la luna se lea tintada.
        "glass": flat("glass", "3A4A57", 0.10),
        "cream": flat("cream", "EDE5D3", 0.4),
        "red": flat("red", "C4382B", 0.5),
        "plate": flat("plate", "EDEAE3", 0.55),
        "ground": flat("ground", "8E9196", 0.9),
    }

    body = group_by_material(build_body(mats), "limo_body")
    plate = build_plate(mats)
    wheels, hubs = {}, {}
    for key in WHEEL_AXLES:
        wheels[key] = wheel_part(f"limo_wheel_{key}", WHEEL_RADIUS, WHEEL_DEPTH, 16, mats["dark"])
        disc = wheel_part("hub_disc", HUB_RADIUS, HUB_DEPTH, 10, mats["steel"])
        cap = wheel_part("hub_cap", CAP_RADIUS, CAP_DEPTH, 6, mats["steel"])
        hubs[key] = join([disc, cap], f"limo_hub_{key}")

    # Comprobaciones antes de exportar.
    entries = [(obj, (0.0, 0.0, 0.0)) for obj in body.values()] + [(plate, (0.0, 0.0, 0.0))]
    entries += [(wheels[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    entries += [(hubs[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    lo, hi = bounds(entries)
    plate_lo, plate_hi = bounds([(plate, (0.0, 0.0, 0.0))])
    seat = (round((plate_lo[0] + plate_hi[0]) / 2, 4), round((plate_lo[1] + plate_hi[1]) / 2, 4),
            round(plate_hi[2], 4))
    width, length, height = hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]
    trunk = REAR_Y - 5.20

    assert plate_hi[0] - plate_lo[0] >= 4.5 - 1e-6, "placa menor de 4,5 de ancho"
    assert plate_hi[1] - plate_lo[1] >= 5.0 - 1e-6, "placa menor de 5 de largo"
    assert plate_lo[2] >= ROOF_Z - 1e-6, "la placa no apoya en el techo"
    assert abs(seat[2] - SEAT_Z) < 1e-6, "el seat no coincide con la cara superior de la placa"
    assert abs(seat[0]) < 1e-6, "la placa no esta centrada en X"
    # Nada por encima de la placa.
    assert abs(hi[2] - plate_hi[2]) < 1e-6, f"hay geometria {hi[2]:.3f} por encima de la placa"
    assert width <= MAX_SIZE[0] + 1e-6, f"ancho {width:.3f} por encima de {MAX_SIZE[0]}"
    assert length <= MAX_SIZE[1] + 1e-6, f"largo {length:.3f} por encima de {MAX_SIZE[1]}"
    assert height <= MAX_SIZE[2] + 1e-6, f"alto {height:.3f} por encima de {MAX_SIZE[2]}"
    assert abs(lo[2]) < 1e-6, f"min_z {lo[2]:.3f}, las ruedas no tocan el suelo"
    for key in WHEEL_AXLES:
        total_part = count(wheels[key]) + count(hubs[key])
        assert total_part <= PART_BUDGET, f"rueda {key} con {total_part}, por encima de {PART_BUDGET}"
        axle = WHEEL_AXLES[key]
        assert abs(axle[2] - WHEEL_RADIUS) < 1e-6, f"el eje {key} no deja la rueda en el suelo"
        # El arco real pasa por fuera del neumatico y por dentro de la chapa.
        assert abs(axle[0]) + WHEEL_DEPTH / 2 > BODY_HALF, f"la rueda {key} no asoma de la chapa"
    for obj in [*body.values(), plate, *wheels.values(), *hubs.values()]:
        assert len(obj.data.materials) == 1, f"{obj.name} tiene varios materiales"

    # LOD1: una sola malla con un solo material (carroceria), reducida al 50 %.
    paint = body["negro"]
    lod_parts = [lod_copy(paint, (0.0, 0.0, 0.0), mats["negro"])]
    lod_parts += [lod_copy(wheels[key], WHEEL_AXLES[key], mats["negro"]) for key in WHEEL_AXLES]
    lod = join(lod_parts, "limo_LOD1")
    select_only(lod)
    bpy.ops.object.material_slot_remove_unused()
    assert len(lod.data.materials) == 1, "el LOD1 tiene mas de un material"

    # Las ruedas y los tapacubos se exportan con su origen en el eje y ya colocados en su sitio del
    # coche. Asi Roblox los deja en el eje al cargarlos (el FBX lleva la traslacion del objeto) y
    # siguen girando alrededor de su propio centro. Sin esto, las cuatro caen en (0,0,0).
    for key in WHEEL_AXLES:
        wheels[key].location = WHEEL_AXLES[key]
        hubs[key].location = WHEEL_AXLES[key]

    files = {}
    for obj in body.values():
        export(obj, f"{obj.name}.fbx")
        files[obj.name] = count(obj)
    export(plate, "limo_plate.fbx")
    files["limo_plate"] = count(plate)
    for key in WHEEL_AXLES:
        export(wheels[key], f"limo_wheel_{key}.fbx")
        export(hubs[key], f"limo_hub_{key}.fbx")
        files[f"limo_wheel_{key}"] = count(wheels[key])
        files[f"limo_hub_{key}"] = count(hubs[key])
    export(lod, "limo_LOD1.fbx")
    total = sum(files.values())
    lod_triangles = count(lod)
    assert total <= TOTAL_BUDGET, f"{total} triangulos, por encima de {TOTAL_BUDGET}"
    assert lod_triangles <= total / 2, f"LOD1 con {lod_triangles}, mas de la mitad de {total}"

    stats = {
        "modelo": "limusina",
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
            "maximos_del_encargo": {"ancho_x": MAX_SIZE[0], "largo_y": MAX_SIZE[1], "alto_z": MAX_SIZE[2]},
            "techo_cabina_z": ROOF_Z,
            "maletero": {
                "inicio_y": 5.20,
                "largo": round(trunk, 3),
                "porcentaje_del_largo": round(100 * trunk / length, 1),
                "z_superior": BELT_Z,
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
                "archivo": f"limo_wheel_{key}.fbx",
                "tapacubos": f"limo_hub_{key}.fbx",
                "eje": list(WHEEL_AXLES[key]),
                "giro": "X",
                "radio": WHEEL_RADIUS,
                "ancho": WHEEL_DEPTH,
            }
            for key in WHEEL_AXLES
        },
        "puertas": {"por_lado": 4, "ventanillas_por_lado": PANE_COUNT, "banda_ventanillas_y": [WIN_Y0, WIN_Y1]},
        "materiales": {
            **{obj.name: obj.data.materials[0].name for obj in body.values()},
            "limo_plate": "plate",
            **{f"limo_wheel_{key}": "dark" for key in WHEEL_AXLES},
            **{f"limo_hub_{key}": "steel" for key in WHEEL_AXLES},
            "limo_LOD1": "negro",
        },
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("LIMUSINA_STATS", json.dumps(stats))
    print("LIMUSINA_COUNTS", {name: count(obj) for name, obj in body.items()})

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
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass

    render(scene, camera("frontal", (-15.0, -26.5, 12.5), (0.0, 0.0, 2.5), lens=50),
           "limusina-3-4-frontal.png")
    render(scene, camera("trasera", (15.0, 26.5, 12.5), (0.0, 0.0, 2.5), lens=50),
           "limusina-3-4-trasera.png")
    for obj in avatar:
        obj.hide_render = False
    render(scene, camera("perfil", (60.0, 3.0, 3.0), (0.0, 3.0, 3.0), ortho_scale=29.0),
           "limusina-perfil-avatar.png")
    print("LIMUSINA_RENDERS_OK")


if __name__ == "__main__":
    main()

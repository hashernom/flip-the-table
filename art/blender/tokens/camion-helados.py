"""Ficha camion-helados: furgoneta de helados pastel de Flip the Table.

Furgoneta de reparto con morro corto, parabrisas inclinado, techo corrido y carroceria de caja. Sobre
la cabina lleva un cono de barquillo gigante con dos bolas y guinda, que es lo que hace reconocible la
ficha en silueta. En el costado izquierdo (el -X de Blender, que en Roblox sale a +X) va la ventanilla
de servicio con mostrador y toldo a rayas; en el otro costado, un emblema de helado en relieve. La
trasera lleva dos puertas con ventanas, bisagras, manillas, pilotos, parachoques y placa en blanco.
Sin marcas, logotipos, texto legible ni matriculas reales.

Salidas, en art/blender/tokens/camion-helados/:
  icecream_body_<material>.fbx  carroceria, una malla por material (origen en el centro de la base)
  icecream_plate.fbx            placa del techo, separada: se tine con el color del jugador
  icecream_wheel_{fl,fr,rl,rr}.fbx neumatico, con el origen en su eje de giro (eje X)
  icecream_hub_{fl,fr,rl,rr}.fbx   tapacubos, en malla aparte, mismo origen y eje que su rueda
  icecream_LOD1.fbx             una sola malla y un solo material (color de carroceria)
  stats.json                    triangulos por pieza, total y LOD1, medidas, ejes y seat
Y en art/render/tokens/camion-helados/: 3/4 frontal, 3/4 trasera y perfil con avatar de 6 studs.

Convenciones (como art/blender/tokens/taxi.py): 1 unidad de Blender = 1 stud, el morro mira a -Y,
Z hacia arriba, origen en el centro de la base a ras de suelo, exportacion FBX con Z Forward / Y Up.
Los colores son la paleta de art/guia-de-estilo.md llevada a pastel: cada tono queda documentado en
PALETTE con el color de la guia del que sale.

Uso (segundo plano, sin abrir Blender):
  "D:\\blender\\blender.exe" --background --factory-startup --python art/blender/tokens/camion-helados.py
"""

import glob
import json
import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "camion-helados")
RENDER = os.path.join(REPO, "art", "render", "tokens", "camion-helados")

LOD_RATIO = 0.40
TOTAL_BUDGET = 3000
PART_BUDGET = 120  # rueda con su tapacubos
MAX_SIZE = (6.5, 13.0, 8.0)  # ancho, largo, alto con el cono

# Carroceria: caja con morro corto y parabrisas inclinado. El morro es el -Y.
BODY_HALF = 2.80
FENDER_OUT = 3.05
FLOOR_Z = 0.55
ROOF_Z = 4.12
NOSE_Y = -6.02
REAR_Y = 6.08
BODY_POINTS = [
    (NOSE_Y, FLOOR_Z),
    (NOSE_Y, 2.02),
    (-5.94, 2.30),
    (-5.55, 2.45),
    (-4.90, 2.50),
    (-3.85, 4.05),
    (5.70, ROOF_Z),
    (REAR_Y, 3.80),
    (REAR_Y, FLOOR_Z),
]
WINDSHIELD_P0 = (-4.90, 2.50)
WINDSHIELD_P1 = (-3.85, 4.05)
# El cristal y su marco paran 0,20 antes del pliegue del techo: si llegan al vértice, el bisel los
# deja asomar y aparece una cuña oscura en la esquina de la cabina.
WINDSHIELD_END = (-3.966, 3.877)

# Ruedas: origen en el eje de giro, en studs, relativo a la base. l = -X, r = +X (de frente).
WHEEL_R = 1.02
WHEEL_Z = 1.02
WHEEL_DEPTH = 0.85
WHEEL_X = 2.55
FRONT_AXLE = -3.95
REAR_AXLE = 3.85
WHEEL_AXLES = {
    "fl": (-WHEEL_X, FRONT_AXLE, WHEEL_Z),
    "fr": (WHEEL_X, FRONT_AXLE, WHEEL_Z),
    "rl": (-WHEEL_X, REAR_AXLE, WHEEL_Z),
    "rr": (WHEEL_X, REAR_AXLE, WHEEL_Z),
}
HUB_RADIUS = 0.58
HUB_DEPTH = 0.92
ARCH_IN = 1.10  # radio interior del guardabarros: deja 0,08 de sombra sobre el neumatico
ARCH_OUT = 1.28  # labio fino: el arco abraza la rueda en vez de hacerle un halo
ARCH_T0 = -0.12 * math.pi  # el arco baja hasta el borde inferior de la chapa
ARCH_T1 = 1.12 * math.pi

# Techo: filete crema en el borde, placa del asiento detras del cono y cono sobre la cabina.
ROOF_TRIM_Z = ROOF_Z + 0.05
PLATE_SIZE = (4.5, 4.5, 0.10)
PLATE_CENTER = (0.0, 3.10, ROOF_Z + 0.05)
SEAT = (0.0, 3.10, ROOF_Z + 0.10)
CONE_Y = -2.20
CONE_Z0, CONE_Z1 = 4.05, 6.60
CONE_R0, CONE_R1 = 0.09, 1.02

# Ventanilla de servicio (costado -X) con mostrador y toldo a rayas.
SERV_Y0, SERV_Y1 = -1.55, 3.05
SERV_Z0, SERV_Z1 = 2.30, 3.45
AWN_Y0, AWN_Y1 = -1.90, 3.35
AWN_IN = (-2.80, 3.92)
AWN_OUT = (-3.24, 3.54)

# Paleta: tonos pastel derivados de art/guia-de-estilo.md (seccion 2.2) y de sus colores de zona.
PALETTE = {
    "mint": ("9FD5B6", 0.55, 0.0),  # Darsena Esmeralda #10B981 rebajado con caliza
    "cream": ("EDE5D3", 0.60, 0.0),  # Caliza #EDE5D3, el mismo crema del taxi
    "pink": ("EAA7BB", 0.55, 0.0),  # Bulevar Magenta #E85D9E rebajado con caliza
    "tan": ("BD8439", 0.70, 0.0),  # Ladrillo #B0664A con Oro #C9A227: barquillo
    "glass": ("7FB2D9", 0.12, 0.0),  # Cristal azul de la guia, tal cual
    "dark": ("23272C", 0.60, 0.0),  # Asfalto de la guia
    "steel": ("A8AEB4", 0.25, 0.8),  # Acero pulido de la guia, tal cual
    "red": ("C4382B", 0.70, 0.0),  # Rojo senal de la guia
    "plate": ("EDEAE3", 0.50, 0.0),  # Placa del asiento, casi blanca
    "ground": ("8E9196", 0.90, 0.0),
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


def box(name, size, location, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    # La posicion se hornea en la malla: el origen de cada pieza queda en el centro de la base.
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj


def rot_box(name, size, location, rotation, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
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


def mesh_object(name, verts, faces, mat):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    return close_normals(obj)


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


def bar_yz(name, x, a, b, thick, width, mat):
    """Barra recta entre dos puntos (y, z) de un costado: montantes, limpiaparabrisas, soportes."""
    dy, dz = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dy, dz)
    angle = math.atan2(dz, dy)
    return rot_box(
        name,
        (thick, length, width),
        (x, (a[0] + b[0]) / 2, (a[1] + b[1]) / 2),
        (angle, 0.0, 0.0),
        mat,
    )


def bar_xz(name, y, a, b, width_y, thick, mat):
    """Barra recta entre dos puntos (x, z) de un plano vertical: soportes del toldo y del mostrador."""
    dx, dz = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dz)
    angle = math.atan2(-dz, dx)
    return rot_box(
        name,
        (length, width_y, thick),
        ((a[0] + b[0]) / 2, y, (a[1] + b[1]) / 2),
        (0.0, angle, 0.0),
        mat,
    )


def fender(name, axle_y, side, mat, segments=7):
    """Guardabarros integrado: arco de seccion rectangular que nace y muere dentro de la chapa."""
    verts, faces = [], []
    n = segments + 1
    x0, x1 = side * (BODY_HALF - 0.10), side * FENDER_OUT
    for i in range(n):
        t = ARCH_T0 + (ARCH_T1 - ARCH_T0) * i / segments
        cy, cz = math.cos(t), math.sin(t)
        for x, r in ((x0, ARCH_IN), (x1, ARCH_IN), (x1, ARCH_OUT), (x0, ARCH_OUT)):
            verts.append((x, axle_y + r * cy, WHEEL_Z + r * cz))
    for i in range(segments):
        a, b = i * 4, (i + 1) * 4
        for k in range(4):
            faces.append((a + k, a + (k + 1) % 4, b + (k + 1) % 4, b + k))
    faces.append((0, 3, 2, 1))
    a = (n - 1) * 4
    faces.append((a, a + 1, a + 2, a + 3))
    return mesh_object(name, verts, faces, mat)


def wheel_well(name, axle_y, side, mat, segments=7):
    """Paso de rueda oscuro detras del neumatico: dentro del arco se ve hueco, no chapa."""
    r = ARCH_IN - 0.02
    points = [
        (axle_y + r * math.cos(math.pi * i / segments), WHEEL_Z + r * math.sin(math.pi * i / segments))
        for i in range(segments + 1)
    ]
    obj = profile(name, points, 0.03, mat)
    obj.location = (side * (BODY_HALF + 0.02), 0.0, 0.0)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    return obj


def waffle_cone(name, center_y, z0, z1, r0, r1, mat, segments=12):
    """Cono de barquillo con costillas: anillos alternos un poco mas anchos, como el barquillo."""
    rings = (0.0, 0.5, 1.0)
    verts, faces = [], []
    for t in rings:
        z = z0 + (z1 - z0) * t
        r = r0 + (r1 - r0) * t
        for i in range(segments):
            angle = 2 * math.pi * i / segments
            rib = 1.0 + (0.035 if i % 2 else 0.0)
            verts.append((r * rib * math.cos(angle), center_y + r * rib * math.sin(angle), z))
    for k in range(len(rings) - 1):
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((k * segments + i, k * segments + j, (k + 1) * segments + j, (k + 1) * segments + i))
    faces.append(tuple(range(segments - 1, -1, -1)))
    base = (len(rings) - 1) * segments
    faces.append(tuple(base + i for i in range(segments)))
    return mesh_object(name, verts, faces, mat)


def disc_x(name, center, radius, depth, segments, mat):
    """Disco con el eje en X, centrado en `center`: emblemas de los costados."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=segments, radius=radius, depth=depth, location=center, rotation=(0, math.radians(90), 0)
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
    obj.data.materials.append(mat)
    return obj


def disc_y(name, center, radius, depth, segments, mat):
    """Disco con el eje en Y: faros y pilotos de las caras frontal y trasera."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=segments, radius=radius, depth=depth, location=center, rotation=(math.radians(90), 0, 0)
    )
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
    obj.data.materials.append(mat)
    return obj


def disc_z(name, center, radius, depth, segments, mat):
    """Disco con el eje en Z: base del cono y collar de helado."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments, radius=radius, depth=depth, location=center)
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
    obj.data.materials.append(mat)
    return obj


def ico(name, center, radius, mat, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius, location=center)
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
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
    if len(objects) == 1:
        joined = objects[0]
        joined.name = name
    else:
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


def build_cono(mats):
    """Cono gigante sobre la cabina: base atornillada al techo, barquillo, collar, bolas y guinda."""
    parts = [
        disc_z("cone_base", (0.0, CONE_Y, ROOF_Z + 0.07), 0.78, 0.14, 12, mats["cream"]),
        waffle_cone("waffle_cone", CONE_Y, CONE_Z0, CONE_Z1, CONE_R0, CONE_R1, mats["tan"]),
        disc_z("melt_collar", (0.0, CONE_Y, CONE_Z1 - 0.04), 1.10, 0.15, 12, mats["cream"]),
        ico("scoop_pink", (0.0, CONE_Y, 6.72), 0.98, mats["pink"], 2),
        ico("scoop_cream", (0.10, CONE_Y + 0.18, 7.14), 0.80, mats["cream"], 2),
        ico("cherry", (0.0, CONE_Y - 0.65, 7.45), 0.30, mats["red"], 1),
    ]
    return parts


def build_body(mats):
    parts = [bevel(profile("body", BODY_POINTS, BODY_HALF, mats["mint"]), 0.16)]
    # Filete crema en el borde del techo: enmarca la placa blanca, que es lo que se tine.
    parts.append(box("roof_trim_l", (0.14, 9.20, 0.06), (-2.52, 0.90, ROOF_TRIM_Z), mats["cream"]))
    parts.append(box("roof_trim_r", (0.14, 9.20, 0.06), (2.52, 0.90, ROOF_TRIM_Z), mats["cream"]))
    parts.append(box("roof_trim_f", (5.18, 0.14, 0.06), (0.0, -3.66, ROOF_TRIM_Z), mats["cream"]))
    parts.append(box("roof_trim_b", (5.18, 0.14, 0.06), (0.0, 5.48, ROOF_TRIM_Z), mats["cream"]))
    # Guardabarros con arco real y paso de rueda oscuro.
    for side in (-1, 1):
        for axle_y in (FRONT_AXLE, REAR_AXLE):
            parts.append(fender("fender", axle_y, side, mats["cream"]))
            parts.append(wheel_well("wheel_well", axle_y, side, mats["dark"]))
    # Parabrisas: marco oscuro con relieve, cristal por delante y montante central.
    parts.append(slope_slab("windshield_frame", WINDSHIELD_P0, WINDSHIELD_END, 0.0, 0.07, -0.05, 2.44, mats["dark"]))
    parts.append(slope_slab("windshield", WINDSHIELD_P0, WINDSHIELD_END, 0.07, 0.10, -0.18, 2.30, mats["glass"]))
    parts.append(slope_slab("windshield_mullion", WINDSHIELD_P0, WINDSHIELD_END, 0.10, 0.145, -0.06, 0.09, mats["cream"]))
    for x in (-0.62, 0.62):
        parts.append(bar_yz("wiper", x, (-4.55, 2.72), (-3.95, 3.66), 0.07, 0.05, mats["dark"]))
    # Ventanillas de la cabina, con marco oscuro, cristal y parteluz.
    for side in (-1, 1):
        y0, y1, z0, z1 = -3.55, -2.46, 2.60, 3.70
        w, h, yc, zc = y1 - y0, z1 - z0, (y0 + y1) / 2, (z0 + z1) / 2
        parts.append(box("cab_frame", (0.06, w + 0.16, h + 0.16), (side * 2.815, yc, zc), mats["dark"]))
        parts.append(box("cab_glass", (0.04, w, h), (side * 2.85, yc, zc), mats["glass"]))
        parts.append(box("cab_divider", (0.05, 0.09, h), (side * 2.875, y0 + 0.72, zc), mats["dark"]))
        # Junta de puerta y manilla, al pie de la ventanilla.
        parts.append(box("door_seam", (0.05, 0.06, 3.00), (side * 2.815, -2.38, 2.20), mats["dark"]))
        parts.append(box("handle", (0.10, 0.34, 0.12), (side * 2.87, -2.72, 2.62), mats["steel"]))
        # Espejo: brazo hasta fuera y cabeza oscura; no queda pegado a la chapa.
        parts.append(box("mirror_arm", (0.34, 0.08, 0.08), (side * 2.95, -3.95, 3.55), mats["steel"]))
        parts.append(box("mirror_head", (0.06, 0.20, 0.55), (side * 3.16, -3.95, 3.55), mats["dark"]))
    # Ventanilla de servicio (costado -X): marco, cristal, montante y mostrador con soportes.
    serv_w, serv_h = SERV_Y1 - SERV_Y0, SERV_Z1 - SERV_Z0
    serv_y, serv_z = (SERV_Y0 + SERV_Y1) / 2, (SERV_Z0 + SERV_Z1) / 2
    parts.append(box("serv_frame", (0.06, serv_w + 0.20, serv_h + 0.20), (-2.815, serv_y, serv_z), mats["dark"]))
    parts.append(box("serv_glass", (0.04, serv_w, serv_h), (-2.85, serv_y, serv_z), mats["glass"]))
    parts.append(box("serv_mullion", (0.05, 0.12, serv_h), (-2.875, serv_y, serv_z), mats["cream"]))
    parts.append(box("counter", (0.45, serv_w + 0.34, 0.12), (-3.015, serv_y, SERV_Z0 - 0.08), mats["cream"]))
    for y in (SERV_Y0 + 0.16, SERV_Y1 - 0.16):
        parts.append(bar_xz("counter_bracket", y, (-3.20, 2.18), (-2.84, 1.88), 0.07, 0.07, mats["steel"]))
    # Toldo a rayas sobre la ventanilla, con dos soportes que lo amarran a la chapa.
    stripes = 7
    step = (AWN_Y1 - AWN_Y0) / stripes
    dx, dz = AWN_OUT[0] - AWN_IN[0], AWN_OUT[1] - AWN_IN[1]
    angle = math.atan2(-dz, dx)
    for i in range(stripes):
        y = AWN_Y0 + step * (i + 0.5)
        mat = mats["pink"] if i % 2 == 0 else mats["cream"]
        parts.append(
            rot_box(
                "awning",
                (math.hypot(dx, dz) + 0.04, step + 0.02, 0.08),
                ((AWN_IN[0] + AWN_OUT[0]) / 2, y, (AWN_IN[1] + AWN_OUT[1]) / 2),
                (0.0, angle, 0.0),
                mat,
            )
        )
    for y in (AWN_Y0 + 0.10, AWN_Y1 - 0.10):
        parts.append(bar_xz("awning_bracket", y, (-2.84, 3.14), (-3.18, 3.48), 0.07, 0.07, mats["steel"]))
    # Emblema de helado en el costado +X, en relieve sobre un disco crema.
    parts.append(disc_x("side_badge", (2.82, 0.95, 2.62), 0.95, 0.07, 12, mats["cream"]))
    bpy.ops.mesh.primitive_cone_add(
        vertices=6, radius1=0.02, radius2=0.30, depth=0.72, location=(2.90, 0.95, 2.34), rotation=(0, 0, 0)
    )
    badge_cone = bpy.context.active_object
    badge_cone.name = "badge_cone"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    badge_cone.data.materials.append(mats["tan"])
    parts.append(badge_cone)
    parts.append(ico("badge_scoop", (2.90, 0.95, 2.86), 0.34, mats["pink"], 1))
    # Morro: parrilla, faros con aro oscuro, intermitentes y paragolpes con placa en blanco.
    for i in range(4):
        parts.append(box("grille", (2.10, 0.05, 0.10), (0.0, -6.05, 1.30 + i * 0.16), mats["dark"]))
    for side in (-1, 1):
        parts.append(disc_y("headlight_rim", (side * 1.85, -6.03, 1.64), 0.42, 0.10, 10, mats["dark"]))
        parts.append(disc_y("headlight", (side * 1.85, -6.07, 1.64), 0.33, 0.12, 10, mats["cream"]))
        parts.append(box("indicator", (0.26, 0.05, 0.14), (side * 2.34, -6.03, 1.26), mats["pink"]))
    parts.append(box("bumper_f", (5.70, 0.42, 0.55), (0.0, -6.23, 0.95), mats["steel"]))
    parts.append(box("plate_f", (1.30, 0.03, 0.32), (0.0, -6.45, 0.95), mats["cream"]))
    # Trasera: puertas, ventanas, bisagras, manillas, pilotos y paragolpes. Ninguna cara lisa.
    for side in (-1, 1):
        parts.append(box("rear_frame", (1.58, 0.06, 0.92), (side * 0.95, 6.10, 3.10), mats["dark"]))
        parts.append(box("rear_glass", (1.40, 0.05, 0.74), (side * 0.95, 6.135, 3.10), mats["glass"]))
        parts.append(box("rear_seam", (0.05, 0.05, 2.95), (side * 2.05, 6.10, 2.12), mats["dark"]))
        parts.append(box("rear_handle", (0.10, 0.07, 0.50), (side * 0.32, 6.12, 2.30), mats["steel"]))
        for z in (2.86, 1.42):
            parts.append(box("hinge", (0.16, 0.06, 0.12), (side * 1.96, 6.10, z), mats["dark"]))
        parts.append(box("taillight", (0.40, 0.08, 0.80), (side * 2.30, 6.10, 1.35), mats["red"]))
    parts.append(box("rear_seam_center", (0.05, 0.05, 2.95), (0.0, 6.10, 2.12), mats["dark"]))
    parts.append(box("plate_b", (1.30, 0.06, 0.34), (0.0, 6.10, 1.30), mats["cream"]))
    parts.append(box("bumper_b", (5.70, 0.42, 0.55), (0.0, 6.29, 0.95), mats["steel"]))
    for side in (-1, 1):
        parts.append(box("overrider_b", (0.18, 0.12, 0.72), (side * 1.60, 6.44, 1.02), mats["steel"]))
    parts.append(box("rear_step", (2.10, 0.30, 0.14), (0.0, 6.24, 0.56), mats["steel"]))
    # Boca de llenado en el costado +X: detalle asimetrico, como el escape de la moto.
    parts.append(disc_x("fuel_cap", (2.82, 5.52, 1.90), 0.22, 0.06, 10, mats["steel"]))
    # Estribo crema entre las dos ruedas: remata el borde inferior de la chapa.
    for side in (-1, 1):
        parts.append(box("running_board", (0.14, 4.90, 0.22), (side * 2.86, -0.05, 0.68), mats["cream"]))
    # Parachoques delantero: dos defensas verticales.
    for side in (-1, 1):
        parts.append(box("overrider", (0.18, 0.14, 0.72), (side * 1.60, -6.38, 1.02), mats["steel"]))
    return parts


def build_plate(mats):
    return box("icecream_plate", PLATE_SIZE, PLATE_CENTER, mats["plate"])


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

    mats = {name: flat(name, *values) for name, values in PALETTE.items()}

    body = group_by_material(build_body(mats) + build_cono(mats), "icecream_body")
    plate = build_plate(mats)
    wheels = {key: wheel_part(f"icecream_wheel_{key}", WHEEL_R, WHEEL_DEPTH, 16, mats["dark"]) for key in WHEEL_AXLES}
    hubs = {key: wheel_part(f"icecream_hub_{key}", HUB_RADIUS, HUB_DEPTH, 12, mats["steel"]) for key in WHEEL_AXLES}

    entries = [(obj, (0.0, 0.0, 0.0)) for obj in body.values()] + [(plate, (0.0, 0.0, 0.0))]
    entries += [(wheels[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    entries += [(hubs[key], WHEEL_AXLES[key]) for key in WHEEL_AXLES]
    lo, hi = bounds(entries)
    plate_lo, plate_hi = bounds([(plate, (0.0, 0.0, 0.0))])
    seat = (round((plate_lo[0] + plate_hi[0]) / 2, 4), round((plate_lo[1] + plate_hi[1]) / 2, 4), round(plate_hi[2], 4))
    width, length, height = hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]

    # La placa: 4,5 x 4,5, plana, sobre la capota y sin nada encima.
    assert plate_hi[0] - plate_lo[0] >= 4.5 - 1e-6 and plate_hi[1] - plate_lo[1] >= 4.5 - 1e-6, "placa menor de 4,5 x 4,5"
    assert abs(seat[2] - plate_hi[2]) < 1e-6, "el seat no coincide con la cara superior de la placa"
    for obj, offset in entries:
        if obj is plate:
            continue
        for vertex in obj.data.vertices:
            point = Vector(vertex.co) + Vector(offset)
            if plate_lo[0] - 0.01 < point[0] < plate_hi[0] + 0.01 and plate_lo[1] - 0.01 < point[1] < plate_hi[1] + 0.01:
                assert point[2] <= plate_lo[2] + 0.01, f"{obj.name} invade la placa"
    # Medidas y suelo.
    assert width <= MAX_SIZE[0], f"ancho {width:.2f} por encima de {MAX_SIZE[0]}"
    assert length <= MAX_SIZE[1], f"largo {length:.2f} por encima de {MAX_SIZE[1]}"
    assert height <= MAX_SIZE[2], f"alto {height:.2f} por encima de {MAX_SIZE[2]}"
    assert abs(lo[2]) < 1e-6, f"min_z {lo[2]:.4f}, la ficha no apoya en el suelo"
    assert abs(WHEEL_Z - WHEEL_R) < 1e-6, "las ruedas no tocan el suelo"
    for key in WHEEL_AXLES:
        assert count(wheels[key]) + count(hubs[key]) <= PART_BUDGET, f"rueda {key} por encima de {PART_BUDGET}"
    for obj in [*body.values(), plate, *wheels.values(), *hubs.values()]:
        assert len(obj.data.materials) == 1, f"{obj.name} tiene varios materiales"

    # LOD1: una sola malla con un solo material, reducida.
    lod_parts = [lod_copy(body[name], (0.0, 0.0, 0.0), mats["mint"]) for name in ("mint", "cream", "tan")]
    lod_parts += [lod_copy(wheels[key], WHEEL_AXLES[key], mats["mint"]) for key in WHEEL_AXLES]
    lod = join(lod_parts, "icecream_LOD1")
    select_only(lod)
    bpy.ops.object.material_slot_remove_unused()
    assert len(lod.data.materials) == 1, "el LOD1 tiene mas de un material"

    # Las ruedas y los tapacubos se exportan con su origen en el eje y ya colocados en su sitio de la
    # ficha. Asi Roblox los deja en el eje al cargarlos (el FBX lleva la traslacion del objeto) y
    # siguen girando alrededor de su propio centro. Sin esto, las cuatro caen en (0,0,0).
    for key in WHEEL_AXLES:
        wheels[key].location = WHEEL_AXLES[key]
        hubs[key].location = WHEEL_AXLES[key]

    files = {}
    for obj in body.values():
        export(obj, f"{obj.name}.fbx")
        files[obj.name] = count(obj)
    export(plate, "icecream_plate.fbx")
    files["icecream_plate"] = count(plate)
    for key in WHEEL_AXLES:
        export(wheels[key], f"icecream_wheel_{key}.fbx")
        export(hubs[key], f"icecream_hub_{key}.fbx")
        files[f"icecream_wheel_{key}"] = count(wheels[key])
        files[f"icecream_hub_{key}"] = count(hubs[key])
    export(lod, "icecream_LOD1.fbx")
    total = sum(files.values())
    lod_triangles = count(lod)
    assert total <= TOTAL_BUDGET, f"{total} triangulos, por encima de {TOTAL_BUDGET}"
    assert lod_triangles <= total / 2, f"LOD1 con {lod_triangles}, mas de la mitad de {total}"

    stats = {
        "modelo": "camion-helados",
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
            "techo_cabina_z": ROOF_Z,
            "cono": {
                "centro_y": CONE_Y,
                "z_inferior": CONE_Z0,
                "z_superior": round(hi[2], 3),
                "radio_boca": CONE_R1,
            },
            "ventanilla": {
                "costado": "-X (en Roblox +X)",
                "inicio_y": SERV_Y0,
                "fin_y": SERV_Y1,
                "z_inferior": SERV_Z0,
                "z_superior": SERV_Z1,
            },
            "placa": {
                "tamano_x": round(plate_hi[0] - plate_lo[0], 3),
                "tamano_y": round(plate_hi[1] - plate_lo[1], 3),
                "z_inferior": round(plate_lo[2], 4),
                "z_superior": round(plate_hi[2], 4),
                "centro_xy": [PLATE_CENTER[0], PLATE_CENTER[1]],
            },
            "maximo_permitido": {
                "ancho_x": MAX_SIZE[0],
                "largo_y": MAX_SIZE[1],
                "alto_z": MAX_SIZE[2],
            },
        },
        "seat": list(seat),
        "ruedas": {
            key: {
                "archivo": f"icecream_wheel_{key}.fbx",
                "tapacubos": f"icecream_hub_{key}.fbx",
                "eje": list(WHEEL_AXLES[key]),
                "giro": "X",
                "radio": WHEEL_R,
                "ancho": WHEEL_DEPTH,
            }
            for key in WHEEL_AXLES
        },
        "materiales": {
            **{obj.name: obj.data.materials[0].name for obj in body.values()},
            "icecream_plate": "plate",
            **{f"icecream_wheel_{key}": "dark" for key in WHEEL_AXLES},
            **{f"icecream_hub_{key}": "steel" for key in WHEEL_AXLES},
            "icecream_LOD1": "mint",
        },
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("ICE_CREAM_STATS", json.dumps(stats))

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

    # Mismos encuadres que el taxi, subidos para que entre el cono de 8 de alto.
    render(scene, camera("frontal", (-14.0, -24.5, 13.5), (0.0, 0.0, 3.2), lens=50), "camion-helados-3-4-frontal.png")
    render(scene, camera("trasera", (14.0, 24.5, 13.5), (0.0, 0.0, 3.2), lens=50), "camion-helados-3-4-trasera.png")
    for obj in avatar:
        obj.hide_render = False
    render(scene, camera("perfil", (60.0, 4.0, 3.0), (0.0, 4.0, 3.0), ortho_scale=26.0), "camion-helados-perfil-avatar.png")
    print("ICE_CREAM_RENDERS_OK")


if __name__ == "__main__":
    main()

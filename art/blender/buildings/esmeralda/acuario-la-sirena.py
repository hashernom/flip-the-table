"""Acuario La Sirena: acuario de la Dársena Esmeralda (Puerto), modelado desde cero.

Medidas en studs (1 unidad de Blender = 1 stud). Huella 32 × 18, la del solar; el frente da a -Y y el origen
está en el centro de la base, con z = 0 a ras de suelo. El cuerpo es un basamento de caliza de 10,7 con un
portal de 6,4 × 7,4, el vestíbulo con el muro del tanque al fondo y, sobre la entrada, la bóveda de cañón de
cristal de 17,0: la bóveda y la figura de la sirena son el rasgo de la propiedad y se ven desde la calle sin
leer el rótulo. Los cinco añadidos se suman: marquesina de entrada, paneles azules de los tanques, el tanque
con su bóveda de cristal sobre la cubierta, el pabellón anexo de tienda retranqueado y la torre del acuario
con su linterna de cristal y remate de cobre a 34,0.

Sigue el método de barberia-morro.py y build_cine_lux.py: una malla por material y color, LOD1 con decimado.

Salidas, en art/blender/buildings/esmeralda/:
  acuario-la-sirena.blend                        escena de revisión (no se versiona)
  acuario-la-sirena/acuario_<pieza>.fbx y acuario_LOD1.fbx
  acuario-la-sirena/stats.json                   triángulos por pieza y nivel, límites y materiales
Y en art/render/esmeralda/acuario-la-sirena/: acuario-la-sirena-niveles.png y -comparacion.png.

Uso: blender --background --factory-startup --python art/blender/buildings/esmeralda/acuario-la-sirena.py
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SLICE = os.path.join(REPO, "art", "blender", "slice")
OUT = os.path.join(HERE, "acuario-la-sirena")
RENDER_SUBDIR = "esmeralda/acuario-la-sirena"
sys.path.insert(0, SLICE)

# Helpers compartidos con los edificios ya en el juego (no se copian: se importan).
from build_cine_lux import (  # noqa: E402
    box,
    build_marker,
    camera,
    count,
    flat,
    join,
    lamp,
    letters,
    lod_of,
    origin_at_zero,
    perforate,
    render,
    select_only,
    textured,
    tree,
    uv_unwrap,
)

# --- Solar y cuerpo -----------------------------------------------------------------------------------
WIDTH = 32.0
DEPTH = 18.0
FRONT = -9.0  # el frente da a -Y
BODY_TOP = 10.7  # coronación de la piedra: la bóveda arranca aquí
CORNICE_TOP = 11.2
BODY_H = 17.0  # altura del cuerpo: la cresta de la bóveda

# Portal de 6,4 × 7,4: claramente más alto que la figura de 6. El vestíbulo entra 3,2 en el bloque.
PORTAL_W = 6.4
PORTAL_H = 7.4  # altura libre: 7,4 por encima del umbral
PORTAL_TOP = 7.65  # el hueco llega aquí; el dintel de acero ocupa los 0,25 de arriba
PORTAL_Y0 = FRONT - 0.6  # el cortador empieza fuera del muro para cortar limpio
PORTAL_Y1 = FRONT + 2.8

# Nicho de la sirena: hueco de 0,8 de fondo con el fondo de cristal oscuro.
NICHE_X0, NICHE_X1 = 5.0, 8.6
NICHE_Z0, NICHE_Z1 = 0.8, 7.6
NICHE_Y1 = FRONT + 0.8
STATUE_X = 6.8

# Rótulo: placa de cristal oscuro sobre la entrada, con las letras de caliza por encima del portal y la marquesina.
SIGN_X0, SIGN_X1 = -8.8, 8.8
SIGN_Z0, SIGN_Z1 = 8.6, 10.45
SIGN = "ACUARIO LA SIRENA"

# Bóveda de cañón sobre la sala central, de la fachada al fondo delantero.
VAULT_A = 9.2  # semiancho
VAULT_Y0 = FRONT - 0.06
VAULT_Y1 = 2.0
VAULT_RISE = 6.15  # el cristal llega a 16,85
RIB_RISE = 6.3  # los nervios de acero llegan a 17,0: el cuerpo mide 17,0

TRIANGLE_BUDGET = 3000
MAX_HEIGHT = 34.0
CINE_LUX_L5_TRIANGLES = 3042

FRONT_OFFSET = 2.0
STREET_WIDTH = 34.0
SIDEWALK = 7.0
LOT_DEPTH = 22.0
SPACING = 40.0
SLOT_LENGTH = 30.0
SLOT_DEPTH = 16.0
SLOT_SIDE = 8.0
MARKER_FRONT = -9.5
MARKER_STEP = 4.4
MARKER_ALONG = 11.5

# Material de Roblox, sufijo de color y RGB de cada clave de material de Blender.
RBX = {
    "limestone": ("Limestone", "", "D2C9B4"),
    "slate": ("Slate", "", "4A4E54"),
    "glass": ("Glass", "", "2E4A63"),
    "wood": ("Wood", "", "6B4A2E"),
    "metal_acero": ("Metal", "_acero", "A8AEB4"),
    "metal_oro": ("Metal", "_oro", "C9A227"),
    "metal_esmeralda": ("Metal", "_esmeralda", "10B981"),
}


def make_materials():
    """Materiales de la lista del juego y, solo para la escena de render, el asfalto y la calle."""
    return {
        "limestone": textured("limestone", "concrete", "D2C9B4"),
        "slate": flat("slate", "4A4E54", 0.85),
        "glass": flat("glass", "2E4A63", 0.12, 0.25),
        "wood": flat("wood", "6B4A2E", 0.75),
        "metal_acero": flat("metal_acero", "A8AEB4", 0.35, 0.85),
        "metal_oro": flat("metal_oro", "C9A227", 0.32, 0.9),
        "metal_esmeralda": flat("metal_esmeralda", "10B981", 0.4, 0.5),
        # Solo escena de render.
        "asphalt": textured("asphalt", "asphalt", "4A4E54"),
        "pavement": textured("pavement", "concrete", "A39C8E"),
        "zone": flat("zone", "10B981", 0.8),
        "cream": flat("cream", "EDE5D3", 0.6),
        "dark": flat("dark", "2A2E33", 0.6),
        "bark": flat("bark", "5A4636", 0.9),
        "hedge": flat("hedge", "4B6B3A", 0.9),
        "block": flat("block", "B8B2A6", 0.8),
        "avatar": flat("avatar", "4A5058", 0.8),
    }


# --- Geometría ---------------------------------------------------------------------------------------


def slab(name, x0, x1, y0, y1, z0, z1, mat=None):
    """Caja a partir de sus límites: se lee mejor que centro y tamaño en un edificio de muchas piezas."""
    return box(name, (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), mat)


def cylinder(name, radius, depth, location, mat, verts, caps, rotation=(0.0, 0.0, 0.0)):
    """Cilindro (tanque, aros, linterna). Con tapas cierra el volumen; sin ellas queda la banda abierta."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts,
        radius=radius,
        depth=depth,
        end_fill_type="NGON" if caps else "NOTHING",
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def cone(name, radius1, radius2, depth, location, mat, verts):
    """Cono o tronco de cono (remate de cobre, faldón de la torre)."""
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts,
        radius1=radius1,
        radius2=radius2,
        depth=depth,
        location=location,
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def beam(name, a, b, thick, mat):
    """Barra entre dos puntos: tirantes de la marquesina y puntales."""
    a, b = Vector(a), Vector(b)
    d = b - a
    obj = box(name, (thick, d.length, thick), tuple((a + b) / 2), mat)
    obj.rotation_euler = Vector((0.0, 1.0, 0.0)).rotation_difference(d.normalized()).to_euler()
    return obj


def tilted(name, x0, x1, y_a, z_a, y_b, z_b, thickness, mat):
    """Losa inclinada cuya cara superior pasa por (y_a, z_a) y (y_b, z_b): la marquesina."""
    angle = math.atan2(z_b - z_a, y_b - y_a)
    length = math.hypot(y_b - y_a, z_b - z_a)
    normal_y, normal_z = -math.sin(angle), math.cos(angle)
    obj = box(
        name,
        (x1 - x0, length, thickness),
        ((x0 + x1) / 2, (y_a + y_b) / 2 - normal_y * thickness / 2, (z_a + z_b) / 2 - normal_z * thickness / 2),
        mat,
    )
    obj.rotation_euler = (angle, 0, 0)
    return obj


def arch(name, a, b, spring, y0, y1, thickness, segments, mat):
    """Bóveda de cañón: perfil de arco elíptico (a, b) barrido en Y, con sus dos tapas cerradas.

    El perfil es un anillo: arco exterior y arco interior desplazado `thickness` hacia dentro. Al cerrar las
    dos tapas, la malla es un sólido, así que no quedan caras vistas por detrás ni huecos negros. Con un número
    par de segmentos el arco pasa por la cresta exacta.
    """
    outer, inner = [], []
    for i in range(segments + 1):
        theta = -math.pi / 2 + math.pi * i / segments
        outer.append((a * math.sin(theta), spring + b * math.cos(theta)))
        inner.append(((a - thickness) * math.sin(theta), spring + (b - thickness) * math.cos(theta)))
    profile = outer + inner[::-1]
    return swept(name, profile, y0, y1, mat)


def lunette(name, a, b, spring, y0, y1, segments, mat):
    """Frontón de cristal que cierra el arco de la bóveda: media luna maciza, para que no quede un hueco."""
    profile = [
        (a * math.sin(-math.pi / 2 + math.pi * i / segments), spring + b * math.cos(-math.pi / 2 + math.pi * i / segments))
        for i in range(segments + 1)
    ]
    profile.append((0.0, spring))
    return swept(name, profile, y0, y1, mat)


def swept(name, profile, y0, y1, mat):
    """Barre un perfil cerrado (x, z) entre y0 e y1 y cierra las dos tapas: un sólido, no una superficie."""
    n = len(profile)
    verts = [(x, y0, z) for x, z in profile] + [(x, y1, z) for x, z in profile]
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, j + n, i + n))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def dome(name, radius, z0, height, segments, rings, mat):
    """Bóveda semiesférica facetada, cerrada por la base: el remate de cristal del tanque."""
    verts = [(0.0, 0.0, z0 + height)]
    for ring in range(1, rings + 1):
        phi = (math.pi / 2) * ring / rings
        rr = radius * math.sin(phi)
        zz = z0 + height * math.cos(phi)
        for i in range(segments):
            angle = 2 * math.pi * i / segments
            verts.append((rr * math.cos(angle), rr * math.sin(angle), zz))
    faces = []
    for i in range(segments):
        faces.append((0, 1 + i, 1 + (i + 1) % segments))
    for ring in range(rings - 1):
        base0 = 1 + ring * segments
        base1 = base0 + segments
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((base0 + i, base1 + i, base1 + j, base0 + j))
    faces.append(tuple(1 + (rings - 1) * segments + i for i in range(segments))[::-1])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.validate()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def portal_cutter(name):
    """Hueco del portalón y del vestíbulo en una sola caja: 6,4 de ancho, 2,8 de fondo, hasta el suelo."""
    return box(
        name,
        (PORTAL_W, PORTAL_Y1 - PORTAL_Y0, PORTAL_TOP + 0.2),
        (0.0, (PORTAL_Y0 + PORTAL_Y1) / 2, (PORTAL_TOP - 0.2) / 2),
    )


def niche_cutter(name):
    """Hueco del nicho de la sirena: 3,6 × 0,8 × 6,8."""
    return box(
        name,
        (NICHE_X1 - NICHE_X0, NICHE_Y1 - (FRONT - 0.6), NICHE_Z1 - NICHE_Z0),
        ((NICHE_X0 + NICHE_X1) / 2, (NICHE_Y1 + FRONT - 0.6) / 2, (NICHE_Z0 + NICHE_Z1) / 2),
    )


def fit_width(obj, max_width):
    """Reduce el rótulo de forma uniforme si no cabe en la placa."""
    width = obj.dimensions.x
    if width > max_width:
        select_only(obj)
        factor = max_width / width
        obj.scale = (factor, factor, factor)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def siren(M, parts):
    """La sirena de la entrada: cola de pez ancha en la cadera, torso, cabeza, pelo y brazos.

    Va de pie sobre su pedestal, delante del nicho de cristal oscuro, así que se recorta en silueta clara.
    """
    cx, cy = STATUE_X, -9.42
    # Pedestal de caliza con su moldura.
    parts.append(slab("siren_base", 5.2, 8.4, FRONT - 0.7, FRONT, 0.0, 1.05, M["limestone"]))
    parts.append(slab("siren_base_cap", 5.1, 8.5, FRONT - 0.8, FRONT, 1.05, 1.2, M["limestone"]))
    # Cola: estrecha en el pedestal y ancha en la cadera, con la aleta abierta sobre la basa.
    tail = cone("siren_tail", 0.32, 0.76, 3.1, (cx, cy, 2.75), M["limestone"], 10)
    tail.scale = (1.0, 0.55, 1.0)
    parts.append(tail)
    for side in (-1, 1):
        fluke = box("siren_fluke", (1.25, 0.3, 0.34), (cx + side * 0.62, cy, 1.36), M["limestone"])
        fluke.rotation_euler = (0.0, side * math.radians(16), 0.0)
        parts.append(fluke)
    # Cadera, torso y hombros.
    parts.append(slab("siren_hip", cx - 0.66, cx + 0.66, cy - 0.37, cy + 0.37, 4.25, 4.9, M["limestone"]))
    parts.append(slab("siren_torso", cx - 0.45, cx + 0.45, cy - 0.29, cy + 0.29, 4.9, 6.3, M["limestone"]))
    parts.append(slab("siren_shoulders", cx - 0.65, cx + 0.65, cy - 0.31, cy + 0.31, 6.3, 6.75, M["limestone"]))
    # Cabeza y pelo.
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.42, location=(cx, cy, 7.15))
    head = bpy.context.active_object
    head.name = "siren_head"
    head.scale = (1.0, 0.8, 1.0)
    head.data.materials.append(M["limestone"])
    parts.append(head)
    parts.append(slab("siren_hair", cx - 0.44, cx + 0.44, cy + 0.1, cy + 0.34, 6.5, 7.55, M["limestone"]))
    for side in (-1, 1):
        parts.append(slab("siren_lock", cx + side * 0.42, cx + side * 0.62, cy + 0.06, cy + 0.36, 5.85, 6.9, M["limestone"]))
    # Brazos: el derecho en alto, el izquierdo tendido hacia la calle.
    raised = box("siren_arm_up", (0.2, 0.2, 1.65), (cx + 0.72, cy, 7.1), M["limestone"])
    raised.rotation_euler = (0.0, math.radians(-22), 0.0)
    parts.append(raised)
    down = box("siren_arm_down", (0.2, 0.2, 1.35), (cx - 0.7, cy, 5.75), M["limestone"])
    down.rotation_euler = (0.0, math.radians(14), 0.0)
    parts.append(down)
    parts.append(slab("siren_hand", cx + 1.0, cx + 1.26, cy - 0.12, cy + 0.12, 7.78, 7.98, M["limestone"]))


def build_body(M):
    """Nivel 0: basamento de caliza con el portal, el vestíbulo del tanque, el nicho de la sirena y la bóveda.

    Ya se lee como acuario sin rótulo: la bóveda de cristal se ve desde la calle, la sirena está a escala de
    edificio y por el portal se ve el muro del tanque. Nada de hileras de ventanitas de viviendas.
    """
    parts = []

    # --- Cuerpo: un bloque de caliza con el portal y el nicho perforados de verdad.
    body = slab("body", -WIDTH / 2, WIDTH / 2, FRONT, DEPTH / 2, 0.0, BODY_TOP, M["limestone"])
    perforate(body, [portal_cutter("cut_portal"), niche_cutter("cut_niche")])
    parts.append(body)

    # --- Zócalo, umbral y cornisa. Todo lo aplicado entra 0,05 en el muro: caras coplanares dan sombras sucias.
    for x0, x1 in ((-16.2, -PORTAL_W / 2), (PORTAL_W / 2, NICHE_X0), (NICHE_X1, 16.2)):
        parts.append(slab("plinth", x0, x1, FRONT - 0.25, FRONT + 0.05, 0.0, 0.75, M["limestone"]))
    parts.append(slab("threshold", -3.6, 3.6, FRONT - 0.6, FRONT + 0.05, 0.0, 0.18, M["limestone"]))
    parts.append(slab("cornice_f", -16.3, 16.3, FRONT - 0.3, FRONT + 0.05, BODY_TOP, CORNICE_TOP, M["limestone"]))
    parts.append(slab("cornice_b", -16.3, 16.3, DEPTH / 2, DEPTH / 2 + 0.3, BODY_TOP, CORNICE_TOP, M["limestone"]))
    for side in (-1, 1):
        parts.append(slab("cornice_s", side * 16.0, side * 16.3, FRONT - 0.3, DEPTH / 2 + 0.3, BODY_TOP, CORNICE_TOP, M["limestone"]))

    # --- Pilastras: las esquinas y las dos que apean la bóveda.
    for x0, x1 in ((-16.0, -15.0), (-9.7, -8.7), (8.7, 9.7), (15.0, 16.0)):
        parts.append(slab("pilaster", x0, x1, FRONT - 0.3, FRONT + 0.05, 0.0, BODY_TOP, M["limestone"]))

    # --- Portal: marco de acero y vestíbulo con el muro del tanque al fondo.
    for x in (-PORTAL_W / 2, PORTAL_W / 2 - 0.3):
        parts.append(slab("portal_jamb", x, x + 0.3, FRONT - 0.16, FRONT + 0.06, 0.0, PORTAL_TOP, M["metal_acero"]))
    parts.append(slab("portal_head", -PORTAL_W / 2 + 0.3, PORTAL_W / 2 - 0.3, FRONT - 0.16, FRONT + 0.06, PORTAL_H, PORTAL_TOP, M["metal_acero"]))
    parts.append(slab("lobby_floor", -PORTAL_W / 2, PORTAL_W / 2, FRONT + 0.05, PORTAL_Y1, 0.0, 0.2, M["wood"]))
    parts.append(slab("tank_glass", -3.1, 3.1, PORTAL_Y1 - 0.13, PORTAL_Y1 - 0.03, 0.2, 7.15, M["glass"]))
    parts.append(slab("tank_sill", -3.15, 3.15, PORTAL_Y1 - 0.24, PORTAL_Y1 - 0.1, 0.2, 0.62, M["metal_acero"]))
    parts.append(slab("tank_head", -3.15, 3.15, PORTAL_Y1 - 0.24, PORTAL_Y1 - 0.1, 7.0, 7.15, M["metal_acero"]))
    parts.append(slab("tank_mullion", -0.08, 0.08, PORTAL_Y1 - 0.2, PORTAL_Y1 - 0.1, 0.62, 7.0, M["metal_acero"]))

    # --- Nicho de la sirena: fondo de cristal oscuro y marco de acero.
    parts.append(slab("niche_glass", NICHE_X0 + 0.04, NICHE_X1 - 0.04, NICHE_Y1 - 0.12, NICHE_Y1 - 0.02, NICHE_Z0, NICHE_Z1, M["glass"]))
    parts.append(slab("niche_jamb_l", NICHE_X0, NICHE_X0 + 0.25, FRONT - 0.2, FRONT + 0.05, NICHE_Z0, NICHE_Z1, M["metal_acero"]))
    parts.append(slab("niche_jamb_r", NICHE_X1 - 0.25, NICHE_X1, FRONT - 0.2, FRONT + 0.05, NICHE_Z0, NICHE_Z1, M["metal_acero"]))
    parts.append(slab("niche_head", NICHE_X0 + 0.25, NICHE_X1 - 0.25, FRONT - 0.2, FRONT + 0.05, NICHE_Z1 - 0.3, NICHE_Z1, M["metal_acero"]))
    parts.append(slab("niche_sill", NICHE_X0 + 0.25, NICHE_X1 - 0.25, FRONT - 0.2, FRONT + 0.05, NICHE_Z0, NICHE_Z0 + 0.3, M["metal_acero"]))

    # --- La sirena, delante del nicho.
    siren(M, parts)

    # --- Rótulo: repisa, placa de cristal y el nombre en letras de caliza.
    parts.append(slab("sign_sill", -9.0, 9.0, FRONT - 0.42, FRONT + 0.05, SIGN_Z0 - 0.15, SIGN_Z0, M["limestone"]))
    parts.append(slab("sign_plate", SIGN_X0, SIGN_X1, FRONT - 0.35, FRONT + 0.05, SIGN_Z0, SIGN_Z1, M["glass"]))
    name = letters(SIGN, 1.55, (0.0, FRONT - 0.4, (SIGN_Z0 + SIGN_Z1) / 2), M["limestone"], depth=0.2)
    parts.append(fit_width(name, 16.4))

    # --- Bóveda de cristal y sus nervios de acero. Es lo que hace la silueta del acuario.
    parts.append(arch("vault_glass", VAULT_A, VAULT_RISE, BODY_TOP, VAULT_Y0, VAULT_Y1, 0.22, 10, M["glass"]))
    parts.append(lunette("vault_fronton", VAULT_A, VAULT_RISE, BODY_TOP, VAULT_Y0 - 0.02, VAULT_Y0 + 0.04, 10, M["glass"]))
    parts.append(lunette("vault_backon", VAULT_A, VAULT_RISE, BODY_TOP, VAULT_Y1 - 0.04, VAULT_Y1 + 0.02, 10, M["glass"]))
    for y0, y1 in ((VAULT_Y0 - 0.12, VAULT_Y0 + 0.12), (-3.7, -3.44), (VAULT_Y1 - 0.2, VAULT_Y1 + 0.04)):
        parts.append(arch("vault_rib", VAULT_A + 0.03, RIB_RISE, BODY_TOP, y0, y1, 0.3, 10, M["metal_acero"]))
    for x in (-4.4, 0.0, 4.4):
        top = BODY_TOP + VAULT_RISE * math.sqrt(max(0.0, 1.0 - (x / VAULT_A) ** 2)) - 0.12
        parts.append(slab("lunette_mullion", x - 0.07, x + 0.07, FRONT - 0.12, VAULT_Y0 + 0.03, CORNICE_TOP, top, M["metal_acero"]))

    # --- Cubierta: caseta de escalera y equipo, para que el plano de turno no vea una losa vacía.
    parts.append(slab("stair_head", -14.2, -11.2, 5.6, 8.6, BODY_TOP, 13.4, M["limestone"]))
    parts.append(slab("stair_cap", -14.4, -11.0, 5.4, 8.8, 13.4, 13.7, M["slate"]))
    for x in (-7.6, -5.4):
        parts.append(cylinder("roof_tank", 1.0, 2.2, (x, 7.4, BODY_TOP + 1.1), M["metal_acero"], 10, True))
    parts.append(slab("roof_duct", 5.6, 8.0, 6.2, 7.2, BODY_TOP, BODY_TOP + 1.0, M["metal_acero"]))
    parts.append(slab("roof_flue", 4.6, 5.4, 5.8, 6.6, BODY_TOP, BODY_TOP + 2.4, M["metal_acero"]))
    return parts


# --- Niveles 1 a 5 ----------------------------------------------------------------------------------


def build_marquee(M):
    """Nivel 1: marquesina de acero sobre el portal, con filete esmeralda y tirantes a la fachada."""
    parts = []
    parts.append(tilted("marquee", -4.8, 4.8, FRONT, 8.35, FRONT - 0.88, 7.95, 0.22, M["metal_acero"]))
    parts.append(slab("marquee_face", -4.8, 4.8, FRONT - 0.97, FRONT - 0.83, 7.55, 8.0, M["metal_acero"]))
    parts.append(slab("marquee_band", -4.6, 4.6, FRONT - 0.99, FRONT - 0.93, 7.62, 7.74, M["metal_esmeralda"]))
    for x in (-4.1, 4.1):
        parts.append(beam("marquee_tie", (x, FRONT - 0.88, 8.0), (x, FRONT - 0.06, 8.55), 0.1, M["metal_acero"]))
    return parts


def build_panels(M):
    """Nivel 2: paneles azules de los tanques en las dos alas, con bastidor de acero y lunas de cristal."""
    parts = []
    for x0, x1 in ((-14.9, -10.2), (10.2, 14.9)):
        z0, z1 = 1.0, 7.4
        for xa in (x0, x1 - 0.25):
            parts.append(slab("panel_jamb", xa, xa + 0.25, FRONT - 0.3, FRONT + 0.05, z0, z1, M["metal_acero"]))
        parts.append(slab("panel_head", x0 + 0.25, x1 - 0.25, FRONT - 0.3, FRONT + 0.05, z1 - 0.3, z1, M["metal_acero"]))
        parts.append(slab("panel_sill", x0 + 0.25, x1 - 0.25, FRONT - 0.36, FRONT + 0.05, z0, z0 + 0.35, M["metal_acero"]))
        parts.append(slab("panel_glass", x0 + 0.25, x1 - 0.25, FRONT - 0.14, FRONT - 0.02, z0 + 0.35, z1 - 0.3, M["glass"]))
        span = x1 - 0.25 - (x0 + 0.25)
        for k in (1, 2):
            xc = x0 + 0.25 + span * k / 3
            parts.append(slab("panel_mullion", xc - 0.08, xc + 0.08, FRONT - 0.2, FRONT - 0.04, z0 + 0.35, z1 - 0.3, M["metal_acero"]))
    return parts


def build_tank(M):
    """Nivel 3: el tanque de los peces sobre la cubierta trasera, con su basa y su bóveda de cristal."""
    parts = []
    cx, cy = 0.0, 5.4
    parts.append(cylinder("tank_base", 3.3, 1.7, (cx, cy, BODY_TOP + 0.85), M["limestone"], 12, True))
    parts.append(cylinder("tank_drum", 2.9, 9.2, (cx, cy, 17.0), M["glass"], 16, True))
    for z in (14.4, 17.0, 19.6):
        parts.append(cylinder("tank_hoop", 3.02, 0.26, (cx, cy, z), M["metal_acero"], 12, True))
    parts.append(cylinder("tank_collar", 3.04, 0.3, (cx, cy, 21.55), M["metal_acero"], 16, True))
    parts.append(dome("tank_dome", 2.95, 21.7, 2.3, 8, 3, M["glass"]))
    return parts


def build_pavilion(M):
    """Nivel 4: pabellón anexo de tienda, retranqueado sobre el ala oeste, con su escaparate."""
    parts = []
    x0, x1 = -15.6, -9.7
    y0, y1 = -4.4, 4.6
    z0, z1 = BODY_TOP - 0.05, 16.0
    parts.append(slab("pavilion", x0, x1, y0, y1, z0, z1, M["limestone"]))
    parts.append(slab("pavilion_roof", x0 - 0.35, x1 + 0.35, y0 - 0.35, y1 + 0.35, z1, z1 + 0.4, M["slate"]))
    parts.append(slab("shop_glass", x0 + 0.7, x1 - 0.7, y0 - 0.1, y0 + 0.04, 11.6, 14.9, M["glass"]))
    for xa in (x0 + 0.7, x1 - 0.95):
        parts.append(slab("shop_jamb", xa, xa + 0.25, y0 - 0.2, y0 + 0.02, 11.4, 15.1, M["metal_acero"]))
    parts.append(slab("shop_head", x0 + 0.95, x1 - 0.95, y0 - 0.2, y0 + 0.02, 14.9, 15.1, M["metal_acero"]))
    parts.append(slab("shop_sill", x0 + 0.95, x1 - 0.95, y0 - 0.25, y0 + 0.02, 11.4, 11.6, M["metal_acero"]))
    parts.append(slab("shop_mullion", (x0 + x1) / 2 - 0.08, (x0 + x1) / 2 + 0.08, y0 - 0.18, y0 + 0.02, 11.6, 14.9, M["metal_acero"]))
    return parts


def build_tower(M):
    """Nivel 5: torre del acuario, escalonada, con linterna de cristal y remate de cobre a 34,0."""
    parts = []
    cx, cy = 12.5, 4.2
    parts.append(slab("tower", cx - 2.6, cx + 2.6, cy - 2.6, cy + 2.6, BODY_TOP - 0.05, 17.5, M["limestone"]))
    parts.append(slab("tower_step", cx - 2.9, cx + 2.9, cy - 2.9, cy + 2.9, 17.5, 17.9, M["limestone"]))
    parts.append(slab("tower_upper", cx - 2.2, cx + 2.2, cy - 2.2, cy + 2.2, 17.9, 26.0, M["limestone"]))
    parts.append(slab("tower_cornice", cx - 2.6, cx + 2.6, cy - 2.6, cy + 2.6, 26.0, 26.6, M["limestone"]))
    parts.append(slab("tower_band", cx - 2.3, cx + 2.3, cy - 2.3, cy + 2.3, 25.3, 25.52, M["metal_esmeralda"]))
    parts.append(cylinder("lantern", 2.2, 4.6, (cx, cy, 28.9), M["glass"], 12, True))
    for z in (28.0, 29.8):
        parts.append(cylinder("lantern_hoop", 2.32, 0.22, (cx, cy, z), M["metal_acero"], 12, True))
    parts.append(cone("cap_skirt", 2.45, 1.55, 1.2, (cx, cy, 31.8), M["metal_oro"], 8))
    parts.append(cone("cap_spire", 1.55, 0.0, 1.6, (cx, cy, 33.2), M["metal_oro"], 8))
    return parts


# --- Montaje, estadísticas y exportación --------------------------------------------------------------


def merge(members, name):
    """Aplica transformaciones y une; con una sola pieza no llama a join (evita «No mesh data to join»)."""
    for member in members:
        select_only(member)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(members) == 1:
        obj = members[0]
        obj.name = name
    else:
        obj = join(members, name)
    origin_at_zero(obj)
    return obj


def group(level, parts, store):
    """Une las piezas de un nivel en una malla por material y color. En Roblox cada malla lleva un material."""
    layer = "body" if level == 0 else f"addon{level}"
    by_material = {}
    for part in parts:
        by_material.setdefault(part.data.materials[0].name, []).append(part)
    for key, members in by_material.items():
        rbx, suffix, rgb = RBX[key]
        name = f"acuario_{layer}_{rbx.lower()}{suffix}"
        # Los booleanos dejan una ranura de material vacía: la malla se deja con un solo material y todas las
        # caras en él, o en Roblox y en el render salen caras negras.
        for member in members:
            mat = member.data.materials[0] if member.data.materials else None
            if mat is None:
                raise RuntimeError(f"{name}: {member.name} se ha quedado sin material")
            member.data.materials.clear()
            member.data.materials.append(mat)
            for polygon in member.data.polygons:
                polygon.material_index = 0
        mesh = merge(members, name)
        uv_unwrap(mesh)
        materials = {m.name for m in mesh.data.materials if m is not None}
        if len(materials) != 1 or len(mesh.data.materials) != 1:
            raise RuntimeError(f"{name} tiene {len(mesh.data.materials)} materiales")
        store.append({"key": name, "level": level, "material": rbx, "rgb": rgb, "obj": mesh})


def bounds(objects):
    """Límites en studs: ancho (x), fondo (y) y alto (z) con las mallas en coordenadas de escena."""
    xs, ys, zs = [], [], []
    for obj in objects:
        for v in obj.data.vertices:
            p = obj.matrix_world @ v.co
            xs.append(p.x)
            ys.append(p.y)
            zs.append(p.z)
    return {
        "ancho": round(max(xs) - min(xs), 2),
        "fondo": round(max(ys) - min(ys), 2),
        "alto": round(max(zs) - min(zs), 2),
        "alto_maximo_sobre_suelo": round(max(zs), 2),
        "frente": round(min(ys), 2),
        "fondo_maximo": round(max(ys), 2),
        "ancho_izquierda": round(min(xs), 2),
        "ancho_derecha": round(max(xs), 2),
    }


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


def place(sources, x, y=0.0):
    for source in sources:
        copy = source.copy()
        copy.location = (x, y, 0)
        copy.hide_render = False
        copy.hide_viewport = False
        bpy.context.collection.objects.link(copy)


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


def street_stage(M, cumulative, markers):
    """Tramo de calle con la casilla pintada de cada nivel, como en la escena del Cine Lux."""
    lot_y = STREET_WIDTH / 2 + SIDEWALK + LOT_DEPTH / 2
    building_y = lot_y + FRONT_OFFSET
    length = SPACING * 10
    box("road", (length, STREET_WIDTH, 0.4), (0, 0, -0.2), M["asphalt"])
    for sign in (-1, 1):
        box("kerb", (length, 0.5, 0.5), (0, sign * (STREET_WIDTH / 2 + 0.25), 0.0), M["limestone"])
        box("walk", (length, SIDEWALK, 0.4), (0, sign * (STREET_WIDTH / 2 + SIDEWALK / 2), 0.0), M["pavement"])
    box("lots", (length, LOT_DEPTH + 20, 0.2), (0, lot_y + 10, -0.1), M["pavement"])
    box("far", (length, 60, 0.2), (0, -STREET_WIDTH / 2 - SIDEWALK - 30, -0.1), M["pavement"])
    dash = -length / 2
    while dash < length / 2:
        box("dash", (5.0, 0.4, 0.04), (dash, 0, 0.02), M["cream"])
        dash += 11.0

    for level in range(6):
        x = (level - 2.5) * SPACING
        place(cumulative[level], x, building_y)
        box("slot", (SLOT_LENGTH, SLOT_DEPTH, 0.04), (x, SLOT_SIDE, 0.03), M["zone"])
        for sign in (-1, 1):
            box("slot_edge", (0.5, SLOT_DEPTH, 0.05), (x + sign * SLOT_LENGTH / 2, SLOT_SIDE, 0.035), M["cream"])
            box("slot_edge", (SLOT_LENGTH, 0.5, 0.05), (x, SLOT_SIDE + sign * SLOT_DEPTH / 2, 0.035), M["cream"])
        # Marcadores de nivel del juego, solo para comprobar que el edificio no los pisa.
        if level in (1, 2, 3):
            for order in range(level):
                place([markers["house"]], x + MARKER_ALONG + (order - (level - 1) / 2) * MARKER_STEP, lot_y + MARKER_FRONT)
        elif level == 4:
            place([markers["hotel"]], x + MARKER_ALONG, lot_y + MARKER_FRONT)
        elif level == 5:
            place([markers["tower"]], x + MARKER_ALONG, lot_y + MARKER_FRONT)
        gap_x = x + SPACING / 2
        lamp(gap_x, STREET_WIDTH / 2 + 2.0, M)
        tree(gap_x, -(STREET_WIDTH / 2 + SIDEWALK / 2), M)
        lamp(x, -(STREET_WIDTH / 2 + 2.0), M)

    # Ficha de referencia (caja oscura 8 × 4 × 5) y avatar de 6 de alto para la escala.
    box("ficha_ref", (8.0, 4.0, 5.0), (-2.5 * SPACING, SLOT_SIDE, 2.5), M["dark"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-2.5 * SPACING + 2.6, lot_y - 9.0, 3.0), M["avatar"])
    lights_and_world()


def hide_all():
    """Oculta la calle y sus copias para el render siguiente, sin borrar las mallas de origen."""
    for obj in bpy.data.objects:
        obj.hide_render = True
        obj.hide_viewport = True


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

    # Nivel 0: cuerpo. Niveles 1 a 5: añadidos que se suman sin sustituir nada.
    group(0, build_body(M), pieces)
    builders = {1: build_marquee, 2: build_panels, 3: build_tank, 4: build_pavilion, 5: build_tower}
    for level, builder in builders.items():
        group(level, builder(M), pieces)

    # Estadísticas por pieza, por nivel (propias y acumuladas) y límites.
    objects = [p["obj"] for p in pieces]
    total = sum(count(o) for o in objects)
    levels = {}
    cumulative_objects = {}
    for level in range(6):
        own = [p for p in pieces if p["level"] == level]
        cum = [p for p in pieces if p["level"] <= level]
        cumulative_objects[level] = [p["obj"] for p in cum]
        levels[str(level)] = {
            "triangulos_propios": sum(count(p["obj"]) for p in own),
            "triangulos_acumulados": sum(count(p["obj"]) for p in cum),
            "limites": bounds(cumulative_objects[level]),
        }

    # LOD1 con el conjunto entero, al 50 % como los demás edificios.
    lod = lod_of(objects, "acuario_LOD1")
    lod_tris = count(lod)

    for p in pieces:
        export(p["obj"], p["key"] + ".fbx")
    export(lod, "acuario_LOD1.fbx")

    stats = {
        "unidad": "studs (1 unidad de Blender = 1 stud)",
        "huella": {"ancho": WIDTH, "fondo": DEPTH},
        "cuerpo": BODY_H,
        "piezas": [
            {
                "clave": p["key"],
                "nivel": p["level"],
                "material": p["material"],
                "rgb": p["rgb"],
                "triangulos": count(p["obj"]),
            }
            for p in pieces
        ],
        "niveles": levels,
        "total_triangulos": total,
        "presupuesto_triangulos": TRIANGLE_BUDGET,
        "lod1": {
            "triangulos": lod_tris,
            "porcentaje_del_total": round(100.0 * lod_tris / total, 1),
        },
        "referencia_cine_lux_nivel5": CINE_LUX_L5_TRIANGLES,
    }
    with open(os.path.join(OUT, "stats.json"), "w", encoding="utf-8") as handle:
        json.dump(stats, handle, indent=2, ensure_ascii=False)
    print("ACUARIO_STATS", json.dumps({"total": total, "lod1": lod_tris, "niveles": levels}, ensure_ascii=False))

    if total > TRIANGLE_BUDGET:
        raise RuntimeError(f"Presupuesto superado: {total} > {TRIANGLE_BUDGET}")
    if lod_tris >= total / 2:
        raise RuntimeError(f"LOD1 no baja del 50 %: {lod_tris} de {total}")
    body_top = levels["0"]["limites"]["alto_maximo_sobre_suelo"]
    if abs(body_top - BODY_H) > 0.05:
        raise RuntimeError(f"El cuerpo mide {body_top} y debería medir {BODY_H}")
    if body_top > 22.0:
        raise RuntimeError(f"El nivel 0 completo pasa de 22: {body_top}")
    for level in range(6):
        lim = levels[str(level)]["limites"]
        if lim["frente"] < -10.0:
            raise RuntimeError(f"nivel {level}: vuela hasta {lim['frente']}")
        if max(abs(lim["ancho_izquierda"]), abs(lim["ancho_derecha"])) > 18.0:
            raise RuntimeError(f"nivel {level}: se va a {lim['ancho_izquierda']} / {lim['ancho_derecha']} de ancho")
    max_top = levels["5"]["limites"]["alto_maximo_sobre_suelo"]
    if max_top > MAX_HEIGHT:
        raise RuntimeError(f"Altura total de {max_top} supera {MAX_HEIGHT}")
    if abs(max_top - MAX_HEIGHT) > 0.05:
        raise RuntimeError(f"El nivel 5 remata en {max_top} y debería rematar en {MAX_HEIGHT}")

    # Escena de revisión y renders, con las mallas de origen ocultas.
    for obj in objects + [lod]:
        obj.hide_render = True
        obj.hide_viewport = True
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 1600
    scene.render.resolution_y = 900
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "acuario-la-sirena.blend"))

    markers = {
        kind: build_marker(kind, {"slate": M["slate"], "cream": M["cream"], "steel": M["metal_acero"], "gold": M["metal_oro"]})
        for kind in ("house", "hotel", "tower")
    }
    for marker in markers.values():
        marker.hide_render = True
        marker.hide_viewport = True
    street_stage(M, cumulative_objects, markers)
    render(scene, camera("niveles", (0.0, -202.0, 100.0), (0.0, 25.0, 14.0), 31), f"{RENDER_SUBDIR}/acuario-la-sirena-niveles.png")

    # Comparación: nivel 0 con una figura de 6 delante de la fachada, junto a la puerta, y los bloques de
    # Bodega (13) y Cine Lux (24), a la misma distancia.
    hide_all()
    box("ground", (240, 60, 0.4), (0, 0, -0.2), M["pavement"])
    place(cumulative_objects[0], 0.0, 0.0)
    box("bloque_bodega", (WIDTH, DEPTH, 13.0), (-33.5, 0.0, 6.5), M["block"])
    box("bloque_cine_lux", (WIDTH, DEPTH, 24.0), (33.5, 0.0, 12.0), M["block"])
    box("avatar_ref", (1.6, 1.2, 6.0), (-3.9, FRONT - 1.4, 3.0), M["avatar"])
    lights_and_world()
    render(scene, camera("comparacion", (0.0, -116.0, 16.0), (0.0, 0.0, 9.0), 36), f"{RENDER_SUBDIR}/acuario-la-sirena-comparacion.png")
    print("ACUARIO_DONE")


if __name__ == "__main__":
    main()

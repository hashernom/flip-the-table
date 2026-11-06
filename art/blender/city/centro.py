"""Centro: el barrio de referencia de la familia (plan 07, Tarea 1).

Ladrillo y caliza, toldos, calles estrechas y sombra dura (`art/guia-de-estilo.md` §7). Es el barrio
que más se mira, así que su calle es la plantilla de las otras tres: acera de losa con bordillo de
granito y rejillas de hierro, árbol de alineación en alcorque de fundición, farola de forja, banco de
listones, quiosco de prensa y boca de riego. Detrás de las fachadas, un fondo de manzanas de 8 a 12
plantas con escapes de incendios y depósitos de agua: la silueta de Manhattan, que es la identidad
que se pide.

Salidas, en `art/blender/city/`:
  centro-walk_{...}.fbx      acera y bordillo, 40 × 7
  centro-tree_{...}.fbx      árbol y alcorque
  centro-lamp_{...}.fbx      farola de forja
  centro-bench_{...}.fbx     banco
  centro-kiosk_{...}.fbx     quiosco de prensa
  centro-hydrant_{...}.fbx   boca de riego
  centro-backdrop-{a,b}_{...}.fbx  fondo de manzanas, 80 de ancho
  centro.blend               escena de revisión
  centro-stats.json          triángulos reales

Y en `art/render/`: centro-*.png. Son revisión técnica; la aprobación se hace en el juego.

Uso: blender --background --factory-startup --python art/blender/city/centro.py
"""

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from city_kit import (  # noqa: E402
    HERE,
    MATS,
    box,
    build_assets,
    flat,
    prism,
    render_preview,
    sphere,
    sun,
    tube,
)

REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = HERE

# La acera de `CityLayout`: 7 de ancho y una pieza por casilla, así que 40 de largo.
WALK_LENGTH = 40.0
WALK_WIDTH = 7.0
CURB_WIDTH = 0.9


def extra(name, color, roughness=0.8, metallic=0.0):
    material = flat(name, color, roughness, metallic)
    MATS[name] = material
    return material


def palette():
    extra("flag", "C6BEAE", 0.85)
    extra("flag_dark", "7C7A74", 0.9)
    extra("curb", "9C9A94", 0.8)
    extra("grate", "2B2F33", 0.55, 0.6)
    extra("bark", "6B5844", 0.9)
    extra("leaf", "4E6B3C", 0.9)
    extra("iron", "23282B", 0.5, 0.7)
    extra("lamp_glass", "EDE5D3", 0.35)
    extra("wood", "7A5433", 0.8)
    extra("red", "C4382B", 0.7)
    extra("brick", "B0664A", 0.85)
    extra("brick_dark", "8E523C", 0.9)
    extra("stone", "D2C9B4", 0.8)
    extra("stone_dark", "B9B09C", 0.85)
    extra("slate", "4A4E54", 0.85)
    extra("window", "2E3A44", 0.35, 0.1)
    extra("paint", "DED8C8", 0.85)
    extra("hydrant", "A8352A", 0.65)


# --- Acera ---------------------------------------------------------------------------------------


def build_walk(_mats):
    """Losa de caliza con bordillo de granito y dos rejillas de hierro por casilla.

    Es una chapa de 10 centésimas que se apoya en la acera que ya levanta `CityBuilder`: no repite
    el canto, solo la cara que se ve. El bordillo sí baja hasta el suelo, porque es el que separa la
    calzada de la acera.
    """
    parts = [
        # Junta oscura: se ve por las ranuras entre losas.
        box("joint", (WALK_LENGTH, WALK_WIDTH, 0.03), (0, 0, 0.015), MATS["flag_dark"]),
    ]
    # Diez losas de 4 studs, con ranura de 0,1 entre ellas.
    for order in range(10):
        x = -WALK_LENGTH / 2 + 2.0 + order * 4.0
        parts.append(box("flag", (3.9, 5.4, 0.07), (x, 0.15, 0.055), MATS["flag"]))
    # Faja junto a la fachada, más estrecha y de otro tono: la acera nunca es una losa sola.
    parts.append(box("faja", (WALK_LENGTH, 0.55, 0.09), (0, 3.15, 0.045), MATS["curb"]))
    # Bordillo: del suelo a 12 centésimas sobre la losa.
    parts.append(box("curb", (WALK_LENGTH, CURB_WIDTH, 0.52), (0, -WALK_WIDTH / 2 + CURB_WIDTH / 2, -0.14), MATS["curb"]))
    # Rejillas de ventilación del metro, un guiño de la ciudad: dos por casilla, una a cada lado.
    for x in (-10.0, 10.0):
        parts.append(box("grate_frame", (5.2, 2.6, 0.06), (x, -1.55, 0.12), MATS["grate"]))
        for bar in range(7):
            parts.append(box("grate_bar", (4.9, 0.16, 0.03), (x, -2.62 + bar * 0.36, 0.15), MATS["flag_dark"]))
    return parts


# --- Árbol ---------------------------------------------------------------------------------------


def build_tree(_mats):
    """Plátano de alineación en alcorque de fundición, con el tronco despejado para no tapar la calle."""
    parts = [
        # Alcorque: marco de hierro y tierra dentro.
        box("pit_soil", (2.6, 2.6, 0.08), (0, 0, 0.04), MATS["soil"]),
        box("pit_bar", (3.4, 0.36, 0.14), (0, -1.5, 0.07), MATS["grate"]),
        box("pit_bar", (3.4, 0.36, 0.14), (0, 1.5, 0.07), MATS["grate"]),
        box("pit_bar", (0.36, 2.7, 0.14), (-1.5, 0, 0.07), MATS["grate"]),
        box("pit_bar", (0.36, 2.7, 0.14), (1.5, 0, 0.07), MATS["grate"]),
        prism("trunk", 0.36, 0.26, 8.6, (0, 0, 4.3), MATS["bark"], 8),
    ]
    for bar in range(4):
        parts.append(box("pit_slat", (2.9, 0.16, 0.06), (0, -1.05 + bar * 0.7, 0.12), MATS["grate"]))
    # Copa alta y ancha: la sombra dura del barrio la pone el sol a 34°.
    parts.append(tube("branch_a", (0, 0, 7.4), (1.1, 0.3, 10.4), 0.16, MATS["bark"], 6))
    parts.append(tube("branch_b", (0, 0, 7.9), (-1.0, -0.5, 10.8), 0.15, MATS["bark"], 6))
    parts.append(tube("branch_c", (0, 0, 8.4), (0.2, 1.0, 11.2), 0.13, MATS["bark"], 6))
    crowns = (
        (0.0, 0.0, 13.4, 4.0, 0.78),
        (2.7, 0.9, 12.2, 2.9, 0.8),
        (-2.6, -1.0, 12.4, 2.8, 0.82),
        (0.6, -2.6, 12.0, 2.6, 0.8),
        (-0.8, 2.5, 12.2, 2.5, 0.8),
        (0.3, 0.2, 15.6, 2.4, 0.7),
    )
    for order, (x, y, z, radius, squash) in enumerate(crowns):
        parts.append(
            sphere(f"crown_{order}", radius, (x, y, z), MATS["leaf"], 1, squash, 0.18, seed=order + 11)
        )
    return parts


# --- Farola --------------------------------------------------------------------------------------


def build_lamp(_mats):
    """Farola de forja: poste ochavado, brazo curvo y linterna de cuatro caras."""
    parts = [
        prism("base", 0.62, 0.5, 0.9, (0, 0, 0.45), MATS["iron"], 8),
        prism("collar", 0.42, 0.42, 0.22, (0, 0, 1.05), MATS["iron"], 8),
        prism("post", 0.24, 0.15, 11.6, (0, 0, 7.1), MATS["iron"], 8),
        prism("ring", 0.2, 0.2, 0.18, (0, 0, 5.6), MATS["iron"], 8),
        prism("ring", 0.2, 0.2, 0.18, (0, 0, 9.4), MATS["iron"], 8),
    ]
    # Brazo: tramos cortos que dibujan la curva hacia la calle (-Y).
    points = [(0.0, 12.7), (-0.5, 13.30), (-1.3, 13.62), (-2.2, 13.66), (-2.9, 13.46)]
    for (y1, z1), (y2, z2) in zip(points, points[1:]):
        parts.append(tube("arm", (0, y1, z1), (0, y2, z2), 0.11, MATS["iron"], 6))
    parts.append(tube("brace", (0, -0.35, 12.2), (0, -1.9, 13.5), 0.08, MATS["iron"], 5))
    # Linterna: el vaso de cristal y su corona de hierro.
    parts.append(prism("lantern_glass", 0.42, 0.62, 0.85, (0, -2.9, 12.95), MATS["lamp_glass"], 8))
    parts.append(prism("lantern_cap", 0.72, 0.2, 0.5, (0, -2.9, 13.6), MATS["iron"], 8))
    parts.append(prism("lantern_finial", 0.12, 0.05, 0.35, (0, -2.9, 14.0), MATS["iron"], 6))
    parts.append(prism("lantern_base", 0.55, 0.42, 0.18, (0, -2.9, 12.42), MATS["iron"], 8))
    return parts


# --- Banco ---------------------------------------------------------------------------------------


def build_bench(_mats):
    """Banco de listones con costados de fundición, mirando a la calle."""
    parts = []
    for order, y in enumerate((-0.62, -0.24, 0.14, 0.52)):
        parts.append(box(f"seat_{order}", (5.4, 0.3, 0.14), (0, y, 1.48), MATS["wood"]))
    for order, z in enumerate((2.05, 2.5, 2.95)):
        parts.append(box(f"back_{order}", (5.4, 0.12, 0.28), (0, 0.82, z), MATS["wood"]))
    for side in (-1, 1):
        x = side * 2.25
        parts.append(box("leg", (0.18, 0.18, 1.45), (x, -0.6, 0.72), MATS["iron"]))
        parts.append(box("leg", (0.18, 0.18, 3.1), (x, 0.8, 1.55), MATS["iron"]))
        parts.append(box("rail", (0.16, 1.55, 0.14), (x, 0.08, 1.36), MATS["iron"]))
        parts.append(box("armrest", (0.16, 1.5, 0.12), (x, 0.02, 2.28), MATS["iron"]))
        parts.append(box("armpost", (0.14, 0.14, 0.85), (x, -0.6, 1.86), MATS["iron"]))
        parts.append(box("footplate", (0.5, 0.5, 0.12), (x, -0.6, 0.06), MATS["iron"]))
    return parts


# --- Quiosco -------------------------------------------------------------------------------------


def build_kiosk(_mats):
    """Quiosco de prensa: zócalo de ladrillo, cuerpo de madera, toldo y rótulo."""
    parts = [
        box("plinth", (4.6, 3.4, 0.45), (0, 0, 0.225), MATS["brick_dark"]),
        box("body", (4.2, 3.0, 2.9), (0, 0, 1.9), MATS["wood"]),
        box("counter", (4.3, 0.5, 0.18), (0, -1.7, 1.55), MATS["stone"]),
    ]
    # Escaparate abierto al frente, con sus revistas.
    parts.append(box("window", (3.5, 0.12, 1.5), (0, -1.56, 2.6), MATS["window"]))
    for order in range(5):
        parts.append(box(f"mag_{order}", (0.55, 0.12, 0.7), (-1.3 + order * 0.66, -1.66, 2.5), MATS["paint"]))
    # Cornisa, toldo de lona y rótulo en lo alto.
    parts.append(box("cornice", (4.8, 3.6, 0.3), (0, 0, 3.5), MATS["stone"]))
    parts.append(box("awning", (4.9, 1.5, 0.12), (0, -2.3, 3.6), MATS["red"]))
    parts.append(box("awning_lip", (4.9, 0.18, 0.4), (0, -3.02, 3.44), MATS["red"]))
    parts.append(box("roof", (4.5, 3.3, 0.2), (0, 0, 3.75), MATS["slate"]))
    parts.append(box("sign_panel", (3.2, 0.14, 0.8), (0, -1.62, 3.95), MATS["stone"]))
    parts.append(box("sign_board", (3.0, 0.1, 0.6), (0, -1.7, 3.95), MATS["paint"]))
    # Tubo de estufa y dos cajas al lado: el quiosco nunca está solo.
    parts.append(prism("stove", 0.18, 0.18, 1.4, (1.6, 1.0, 4.5), MATS["iron"], 8))
    parts.append(box("crate", (1.3, 1.1, 0.9), (-2.4, -1.4, 0.45), MATS["wood"]))
    parts.append(box("crate", (1.1, 1.0, 0.8), (-2.5, -1.5, 1.3), MATS["wood"]))
    return parts


# --- Boca de riego -------------------------------------------------------------------------------


def build_hydrant(_mats):
    """Boca de riego de hierro fundido: la pieza que dice «estás en una ciudad de verdad»."""
    parts = [
        prism("base", 0.45, 0.38, 0.16, (0, 0, 0.08), MATS["hydrant"], 8),
        prism("body", 0.3, 0.26, 1.55, (0, 0, 0.94), MATS["hydrant"], 8),
        prism("collar", 0.34, 0.34, 0.12, (0, 0, 1.72), MATS["hydrant"], 8),
        sphere("dome", 0.28, (0, 0, 1.86), MATS["hydrant"], 1, 0.7),
        prism("cap", 0.16, 0.1, 0.22, (0, 0, 2.02), MATS["hydrant"], 6),
        prism("nozzle", 0.16, 0.16, 0.36, (0.34, 0, 1.2), MATS["hydrant"], 8, (0, math.radians(90), 0)),
        prism("nozzle", 0.16, 0.16, 0.36, (-0.34, 0, 1.2), MATS["hydrant"], 8, (0, math.radians(90), 0)),
        prism("flange", 0.2, 0.2, 0.1, (0.52, 0, 1.2), MATS["hydrant"], 8, (0, math.radians(90), 0)),
        prism("flange", 0.2, 0.2, 0.1, (-0.52, 0, 1.2), MATS["hydrant"], 8, (0, math.radians(90), 0)),
    ]
    return parts


# --- Fondo ---------------------------------------------------------------------------------------


def block(parts, name, size, location, material):
    parts.append(box(name, size, location, material))


def windows(parts, front_y, x0, x1, z0, z1, rows, cols, material, size=(2.4, 1.9)):
    """Ventana rehundida: una caja oscura metida en la fachada. Da la retícula sin gastar malla."""
    width = (x1 - x0) / cols
    height = (z1 - z0) / rows
    for row in range(rows):
        for col in range(cols):
            x = x0 + width * (col + 0.5)
            z = z0 + height * (row + 0.72)
            parts.append(box("window", (min(size[0], width * 0.55), 0.5, min(size[1], height * 0.5)), (x, front_y + 0.2, z), material))


def fire_escape(parts, side_x, front_y, z_base, levels=3):
    """Escalera de incendios: la silueta que hace inconfundible una manzana de Centro."""
    for level in range(levels):
        z = z_base + level * 3.4
        parts.append(box("landing", (4.6, 1.6, 0.12), (side_x, front_y - 0.9, z), MATS["iron"]))
        for bar in range(5):
            parts.append(box("railing", (0.08, 0.08, 1.1), (side_x - 2.0 + bar, front_y - 1.62, z + 0.55), MATS["iron"]))
        parts.append(box("rail_top", (4.6, 0.1, 0.1), (side_x, front_y - 1.62, z + 1.1), MATS["iron"]))
        if level < levels - 1:
            parts.append(box("stair", (0.9, 2.2, 0.12), (side_x + 1.6, front_y - 0.9, z + 1.7), MATS["iron"], (math.radians(38), 0, 0)))


def water_tower(parts, x, y, z, radius=2.6, height=5.2):
    """Depósito de agua de madera sobre patas de hierro: el remate clásico de la azotea."""
    for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        parts.append(box("tower_leg", (0.22, 0.22, 3.4), (x + dx * radius * 0.62, y + dy * radius * 0.62, z + 1.7), MATS["iron"]))
    parts.append(prism("tower_body", radius, radius * 0.92, height, (x, y, z + 3.4 + height / 2), MATS["wood"], 10))
    for band in range(3):
        parts.append(prism("tower_band", radius * 1.02, radius * 1.02, 0.18, (x, y, z + 3.6 + band * 1.6), MATS["iron"], 10))
    parts.append(prism("tower_roof", radius * 1.05, 0.2, 1.6, (x, y, z + 3.4 + height + 0.8), MATS["slate"], 10))


def build_backdrop_a(_mats):
    """Manzana de ladrillo y caliza con escape de incendios y depósito de agua."""
    parts = []
    # Cuerpo de ladrillo a la izquierda, con cornisa y retícula de ventanas.
    block(parts, "slab", (30.0, 16.0, 58.0), (-25.0, 0.0, 29.0), MATS["brick"])
    block(parts, "cornice", (31.2, 17.0, 1.4), (-25.0, 0.0, 58.6), MATS["stone_dark"])
    block(parts, "string", (30.4, 16.4, 0.6), (-25.0, 0.0, 34.0), MATS["stone_dark"])
    block(parts, "base", (30.6, 16.6, 5.0), (-25.0, 0.0, 2.5), MATS["stone_dark"])
    windows(parts, -8.0, -40.0, -10.0, 6.0, 56.0, 9, 6, MATS["window"])
    fire_escape(parts, -17.0, -8.0, 12.0, 4)
    water_tower(parts, -30.0, 2.0, 59.3)

    # Torre de caliza al centro, más alta y retranqueada: la vertical que remata la manzana.
    block(parts, "tower", (22.0, 15.0, 74.0), (6.0, 1.0, 37.0), MATS["stone"])
    block(parts, "tower_top", (16.0, 12.0, 12.0), (6.0, 1.0, 80.0), MATS["stone_dark"])
    block(parts, "cap", (23.2, 16.0, 1.2), (6.0, 1.0, 74.6), MATS["stone_dark"])
    block(parts, "cap_top", (17.0, 13.0, 0.9), (6.0, 1.0, 86.4), MATS["stone_dark"])
    windows(parts, -6.5, -4.0, 16.0, 5.0, 73.0, 11, 4, MATS["window"], (1.9, 2.1))
    windows(parts, -5.0, -1.0, 13.0, 75.0, 85.0, 3, 3, MATS["window"], (1.6, 1.8))

    # Bloque bajo a la derecha: rompe la línea de cornisa.
    block(parts, "low", (26.0, 15.0, 40.0), (32.0, 1.0, 20.0), MATS["brick_dark"])
    block(parts, "low_cornice", (27.2, 16.0, 1.2), (32.0, 1.0, 40.6), MATS["stone_dark"])
    windows(parts, -6.5, 20.0, 44.0, 4.0, 39.0, 7, 6, MATS["window"], (2.2, 1.8))
    block(parts, "bulkhead", (6.0, 5.0, 3.0), (36.0, 2.0, 42.6), MATS["slate"])
    return parts


def build_backdrop_b(_mats):
    """Variante: dos torres gemelas de caliza y un bloque de ladrillo con chimeneas."""
    parts = []
    for order, x in enumerate((-24.0, -2.0)):
        height = 66.0 if order == 0 else 78.0
        block(parts, "twin", (18.0, 14.0, height), (x, 0.0, height / 2), MATS["stone"])
        block(parts, "twin_base", (19.0, 15.0, 6.0), (x, 0.0, 3.0), MATS["stone_dark"])
        block(parts, "twin_cap", (19.0, 15.0, 1.3), (x, 0.0, height + 0.4), MATS["stone_dark"])
        block(parts, "twin_crown", (12.0, 10.0, 5.0), (x, 0.0, height + 3.5), MATS["brick"])
        windows(parts, -7.0, x - 7.0, x + 7.0, 8.0, height - 3.0, 14 if order else 12, 4, MATS["window"], (1.8, 2.0))

    block(parts, "warehouse", (34.0, 16.0, 30.0), (28.0, 1.0, 15.0), MATS["brick"])
    block(parts, "warehouse_cornice", (35.2, 17.0, 1.4), (28.0, 1.0, 30.6), MATS["stone_dark"])
    windows(parts, -7.0, 13.0, 43.0, 4.0, 29.0, 5, 7, MATS["window"], (2.6, 2.4))
    for order, x in enumerate((16.0, 30.0, 41.0)):
        block(parts, "chimney", (2.4, 2.4, 12.0), (x, 4.0, 36.0), MATS["brick_dark"])
        block(parts, "chimney_cap", (3.0, 3.0, 0.8), (x, 4.0, 42.4), MATS["slate"])
    water_tower(parts, 34.0, 5.0, 31.2, 2.2, 4.0)
    return parts


BUILDERS = (
    ("centro-walk", build_walk),
    ("centro-tree", build_tree),
    ("centro-lamp", build_lamp),
    ("centro-bench", build_bench),
    ("centro-kiosk", build_kiosk),
    ("centro-hydrant", build_hydrant),
)

BACKDROPS = (
    ("centro-backdrop-a", build_backdrop_a),
    ("centro-backdrop-b", build_backdrop_b),
)


def preview():
    """Dos vistas de revisión: la calle a escala de avatar y la manzana con su fondo detrás."""
    # La escena del guion solo sirve para exportar; para mirar, se vacía y se monta una calle.
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()

    # Acera: dos módulos seguidos son una manzana de 80 studs.
    for x in (-20.0, 20.0):
        for part in build_walk(MATS):
            part.location.x += x

    # Fachada de referencia y, detrás, la manzana del fondo.
    box("facade_ref", (32.0, 18.0, 24.0), (0, 12.5, 12.0), MATS["brick"])
    box("facade_plinth", (32.4, 18.4, 1.2), (0, 12.5, 0.6), MATS["stone_dark"])
    for part in build_backdrop_a(MATS):
        part.location.y += 31.5
        part.location.x += 0.0

    def put(builder, x, y):
        for part in builder(MATS):
            part.location.x += x
            part.location.y += y

    put(build_lamp, -12.0, -2.5)
    put(build_tree, 2.0, -1.0)
    put(build_bench, 13.0, 2.1)
    put(build_kiosk, -26.0, 0.0)
    put(build_hydrant, 24.0, -2.5)

    # Avatar de 6 studs y ficha de 9: la escala de `art/escala.md`, en la misma imagen.
    box("avatar_ref", (1.6, 1.2, 6.0), (8.0, -2.0, 3.0), MATS["stone"])
    prism("token_ref", 3.0, 3.0, 9.0, (-8.0, -1.6, 4.5), MATS["red"], 16)

    sun()
    render_preview("centro-calle.png", (-6.0, -44.0, 11.0), (2.0, 8.0, 9.0), 30)
    render_preview("centro-manzana.png", (0.0, -128.0, 34.0), (0.0, 16.0, 26.0), 38)


def main():
    from city_kit import reset_scene

    reset_scene()
    palette()
    stats = build_assets("centro", BUILDERS, BACKDROPS, OUT, "centro.blend")
    total = sum(entry["triangles"] for entry in stats.values())
    print(f"CENTRO_TOTAL {total}")
    preview()


if __name__ == "__main__":
    main()

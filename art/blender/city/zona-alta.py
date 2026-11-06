"""Zona Alta: cristal azul, acero pulido y oro solo en los remates (guía §7).

Es el barrio de la altura y el reflejo: la acera es losa de granito claro con bordillo de acero, el
mobiliario es acero inoxidable y cristal, y detrás de la calle se levantan torres de cristal sobre un
podio de caliza de tres plantas. El oro no cubre nada: es el filete de coronación de cada torre y el
aro del bolardo, nada más. El techo de 92 studs manda, así que las torres se cuentan enteras —podio
incluido— y ninguna pasa de 90.

Salidas, en `art/blender/city/`:
  zona-alta-walk_{...}.fbx      acera de losa y bordillo de acero, 40 × 7
  zona-alta-planter_{...}.fbx   jardinera de acero con seto
  zona-alta-bench_{...}.fbx     banco de listones sobre marco de acero
  zona-alta-lamp_{...}.fbx      farola esbelta de acero y cristal
  zona-alta-bollard_{...}.fbx   bolardo con filete de oro
  zona-alta-backdrop-{a,b}_{...}.fbx  fondo de manzanas, 80 × 20
  zona-alta.blend               escena de revisión
  zona-alta-stats.json          triángulos reales

Y en `art/render/`: zona-alta-calle.png y zona-alta-manzana.png. Son revisión técnica; la aprobación
se hace en el juego.

Uso: blender --background --factory-startup --python art/blender/city/zona-alta.py
"""

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

# La acera de `CityLayout`: 7 de ancho, una pieza por casilla, así que 40 de largo. La chapa se apoya
# en la acera que levanta `CityBuilder`, que está a 0,4 sobre el asfalto (`Barrios.SIDEWALK_TOP`).
WALK_LENGTH = 40.0
WALK_WIDTH = 7.0
CURB_WIDTH = 0.8
SIDEWALK_TOP = 0.4

BLOCK_WIDTH = 80.0
BLOCK_DEPTH = 20.0
PODIUM = 21.0
FLOOR = 7.0
CURTAIN_BAY = 5.2


def extra(name, color, roughness=0.8, metallic=0.0):
    material = flat(name, color, roughness, metallic)
    MATS[name] = material
    return material


def palette():
    """Los valores de `art/generators/city_assets.py`, para que la lámina y el juego enseñen lo mismo."""
    extra("curb", "9C9A94", 0.8)
    extra("flag", "C6BEAE", 0.75)
    extra("flag_dark", "7C7A74", 0.85)
    extra("grate", "2B2F33", 0.55, 0.6)
    extra("bark", "6B5844", 0.9)
    extra("leaf", "4E6B3C", 0.9)
    extra("soil", "2F2A25", 1.0)
    extra("iron", "23282B", 0.5, 0.7)
    extra("lamp_glass", "EDE5D3", 0.35)
    extra("wood", "7A5433", 0.8)
    extra("brick", "B0664A", 0.85)
    extra("brick_dark", "8E523C", 0.9)
    extra("stone", "D2C9B4", 0.75)
    extra("stone_dark", "B9B09C", 0.8)
    extra("slate", "4A4E54", 0.85)
    extra("window", "2E3A44", 0.3)
    extra("paint", "DED8C8", 0.85)
    extra("red", "C4382B", 0.7)
    extra("hydrant", "A8352A", 0.65)
    # El cristal de Zona Alta es azul de verdad (guía §2.2), no un panel casi negro.
    extra("glass", "7FB2D9", 0.12)
    extra("concrete", "C4C0B8", 0.8)
    extra("rust", "8C4A2A", 0.7, 0.2)
    extra("steel", "A8AEB4", 0.25, 0.8)
    extra("gold", "C9A227", 0.3, 0.9)
    extra("asphalt", "4A4E54", 0.9)
    extra("water", "3E7FA6", 0.05)
    extra("canvas", "E0DACA", 0.85)
    extra("neon", "F5C518", 0.3)


# --- Acera ---------------------------------------------------------------------------------------


def build_walk(_mats):
    """Losa grande de granito claro, junta fina y bordillo de acero pulido con su tapa.

    La chapa es fina porque la acera la levanta `CityBuilder`; el bordillo sí baja 0,4 studs, que es
    el canto que separa la acera de la calzada. En el campo van dos tapas de acero registrables: el
    detalle propio del barrio, en vez de la jardinera encastrada.
    """
    parts = [
        # Lecho de junta: se ve por las ranuras, nunca por debajo de la losa.
        box("joint", (WALK_LENGTH, WALK_WIDTH, 0.03), (0, 0, 0.015), MATS["flag_dark"]),
    ]
    # Ocho losas de 5 studs por tres hileras: granito en formato grande y junta de 3 centésimas.
    for col in range(8):
        x = -WALK_LENGTH / 2 + 2.5 + col * 5.0
        for row, y in enumerate((-1.80, 0.0, 1.80)):
            parts.append(box(f"flag_{col}_{row}", (4.94, 1.78, 0.06), (x, y, 0.03), MATS["flag"]))
    for y in (-0.90, 0.90):
        parts.append(box("joint_line", (WALK_LENGTH, 0.03, 0.02), (0, y, 0.04), MATS["flag_dark"]))
    # Faja junto a la fachada y su filete de acero: el borde del barrio también es metal.
    parts.append(box("faja", (WALK_LENGTH, 0.70, 0.07), (0, 3.15, 0.035), MATS["flag_dark"]))
    parts.append(box("edge_steel", (WALK_LENGTH, 0.10, 0.08), (0, 2.75, 0.04), MATS["steel"]))
    # Bordillo de acero: del suelo a 14 centésimas, con tapa que vuela 4 centésimas sobre la losa.
    parts.append(box("curb", (WALK_LENGTH, 0.78, 0.52), (0, -3.11, -0.16), MATS["steel"]))
    parts.append(box("curb_cap", (WALK_LENGTH, 0.86, 0.05), (0, -3.10, 0.115), MATS["steel"]))
    parts.append(box("curb_shadow", (WALK_LENGTH, 0.05, 0.30), (0, -2.705, -0.09), MATS["grate"]))
    # Dos tapas de acero registrables, con sus listones: el detalle propio de la acera.
    for x in (-14.0, 6.0):
        parts.append(box("cover_bed", (3.0, 1.9, 0.05), (x, 0.0, 0.045), MATS["grate"]))
        for order, y in enumerate((-0.60, -0.30, 0.0, 0.30, 0.60)):
            parts.append(box(f"cover_slat_{order}", (2.9, 0.22, 0.04), (x, y, 0.07), MATS["steel"]))
    return parts


# --- Jardinera -----------------------------------------------------------------------------------


def build_planter(_mats):
    """Jardinera de acero inoxidable con seto bajo recortado: 3 de largo y 1,9 de alto.

    El cuerpo va escalonado y con costillas: el acero pulido sin aristas se lee como una caja.
    """
    parts = [
        box("plinth", (3.20, 1.60, 0.10), (0, 0, 0.05), MATS["steel"]),
        box("body_low", (3.06, 1.46, 0.34), (0, 0, 0.27), MATS["steel"]),
        # Ranura oscura a media altura: es la sombra que hace leer el pulido.
        box("reveal", (3.10, 1.50, 0.05), (0, 0, 0.455), MATS["grate"]),
        box("body_high", (3.00, 1.40, 0.40), (0, 0, 0.68), MATS["steel"]),
        box("rim", (3.16, 1.54, 0.10), (0, 0, 0.90), MATS["steel"]),
        box("soil", (2.88, 1.28, 0.05), (0, 0, 0.925), MATS["soil"]),
        box("hedge", (2.78, 1.14, 0.55), (0, 0, 1.23), MATS["leaf"]),
        box("hedge_top", (2.52, 0.96, 0.30), (0, 0, 1.66), MATS["leaf"]),
    ]
    for order in range(6):
        parts.append(box("rib", (0.09, 0.05, 0.80), (-1.25 + order * 0.50, -0.715, 0.48), MATS["steel"]))
    # Dos matas redondas en las puntas: el seto no acaba en esquina viva.
    parts.append(sphere("clump_a", 0.42, (-1.18, 0.0, 1.62), MATS["leaf"], 1, 0.75, 0.10, seed=3))
    parts.append(sphere("clump_b", 0.38, (1.16, 0.0, 1.64), MATS["leaf"], 1, 0.75, 0.10, seed=5))
    return parts


# --- Banco ---------------------------------------------------------------------------------------


def build_bench(_mats):
    """Banco de diseño: bastidores de acero y listones de madera, 5,4 de largo, mirando a la calle."""
    parts = []
    for side in (-1, 1):
        x = side * 2.35
        parts.append(box("foot", (0.90, 0.90, 0.12), (x, 0, 0.06), MATS["steel"]))
        parts.append(box("side_plate", (0.16, 0.90, 1.25), (x, 0, 0.75), MATS["steel"]))
        parts.append(box("back_post", (0.14, 0.52, 1.15), (x, 0.84, 1.92), MATS["steel"]))
    parts.append(box("rail_front", (4.70, 0.16, 0.12), (0, -0.72, 1.33), MATS["steel"]))
    parts.append(box("rail_back", (4.70, 0.16, 0.12), (0, 0.72, 1.33), MATS["steel"]))
    for order, y in enumerate((-0.60, -0.28, 0.04, 0.36, 0.68)):
        parts.append(box(f"seat_{order}", (5.10, 0.28, 0.10), (0, y, 1.42), MATS["wood"]))
    for order, (y, z) in enumerate(((0.94, 2.05), (0.99, 2.45), (1.04, 2.85))):
        parts.append(box(f"back_{order}", (5.10, 0.12, 0.24), (0, y, z), MATS["wood"]))
    return parts


# --- Farola --------------------------------------------------------------------------------------


def build_lamp(_mats):
    """Farola esbelta: poste de acero de 0,44 a 0,34 de diámetro, brazo corto y vaso de cristal."""
    parts = [
        box("base", (0.80, 0.80, 0.10), (0, 0, 0.05), MATS["steel"]),
        prism("plinth", 0.46, 0.38, 0.52, (0, 0, 0.36), MATS["steel"], 8),
        prism("collar", 0.32, 0.26, 0.22, (0, 0, 0.72), MATS["steel"], 8),
        prism("post", 0.22, 0.17, 11.10, (0, 0, 6.38), MATS["steel"], 8),
        prism("capital", 0.20, 0.20, 0.16, (0, 0, 12.01), MATS["steel"], 8),
    ]
    # Brazo hacia -Y: es el lado que se gira a la calle.
    parts.append(tube("arm", (0, 0, 11.62), (0, -1.45, 12.34), 0.11, MATS["steel"], 6))
    parts.append(tube("arm_tip", (0, -1.45, 12.34), (0, -2.30, 12.40), 0.10, MATS["steel"], 6))
    parts.append(tube("brace", (0, -0.32, 11.42), (0, -1.42, 12.18), 0.07, MATS["steel"], 5))
    # Vaso de cristal con armadura de acero de cuatro montantes y su corona.
    parts.append(box("lantern_glass", (0.62, 0.76, 1.32), (0, -2.30, 11.80), MATS["lamp_glass"]))
    for dx, dy in ((-0.29, -0.35), (0.29, -0.35), (-0.29, 0.35), (0.29, 0.35)):
        parts.append(box("lantern_post", (0.06, 0.07, 1.32), (dx, -2.30 + dy, 11.80), MATS["steel"]))
    parts.append(box("lantern_band", (0.66, 0.80, 0.06), (0, -2.30, 12.20), MATS["steel"]))
    parts.append(box("lantern_cap", (0.84, 1.00, 0.16), (0, -2.30, 12.54), MATS["steel"]))
    parts.append(box("lantern_base", (0.72, 0.88, 0.14), (0, -2.30, 11.08), MATS["steel"]))
    parts.append(prism("finial", 0.11, 0.02, 0.32, (0, -2.30, 12.78), MATS["steel"], 6))
    return parts


# --- Bolardo -------------------------------------------------------------------------------------


def build_bollard(_mats):
    """Bolardo bajo de acero pulido con un solo filete de oro: 0,9 de alto."""
    parts = [
        prism("base", 0.32, 0.30, 0.06, (0, 0, 0.03), MATS["steel"], 12),
        prism("body", 0.22, 0.18, 0.62, (0, 0, 0.37), MATS["steel"], 12),
        prism("gold_band", 0.235, 0.235, 0.05, (0, 0, 0.705), MATS["gold"], 12),
        prism("cap", 0.19, 0.14, 0.10, (0, 0, 0.78), MATS["steel"], 12),
        sphere("dome", 0.13, (0, 0, 0.845), MATS["steel"], 1, 0.45),
    ]
    return parts


# --- Fondo ---------------------------------------------------------------------------------------


def block(parts, name, size, location, material, rotation=None):
    parts.append(box(name, size, location, material, rotation))


def front_grid(parts, name, x0, x1, face_y, z0, z1, bays, floors):
    """Muro cortina: montantes verticales cada 4–6 studs y travesaño por planta."""
    width = x1 - x0
    height = z1 - z0
    for index in range(bays + 1):
        x = x0 + width * index / bays
        parts.append(box(f"{name}_mullion", (0.24, 0.40, height), (x, face_y, (z0 + z1) / 2), MATS["steel"]))
    for index in range(floors + 1):
        z = z0 + height * index / floors
        parts.append(box(f"{name}_band", (width, 0.44, 0.40), ((x0 + x1) / 2, face_y, z), MATS["steel"]))


def side_grid(parts, name, y0, y1, face_x, z0, z1, bays, floors):
    """La misma retícula en una cara lateral, en el plano X = face_x."""
    depth = y1 - y0
    height = z1 - z0
    for index in range(bays + 1):
        y = y0 + depth * index / bays
        parts.append(box(f"{name}_mullion", (0.40, 0.24, height), (face_x, y, (z0 + z1) / 2), MATS["steel"]))
    for index in range(floors + 1):
        z = z0 + height * index / floors
        parts.append(box(f"{name}_band", (0.44, depth, 0.40), (face_x, (y0 + y1) / 2, z), MATS["steel"]))


def gold_crown(parts, name, center, size, top):
    """Remate de oro de un stud: cuatro filetes en el borde y cubierta de acero dentro."""
    width, depth = size
    x, y = center
    z = top - 0.5
    block(parts, f"{name}_crown_front", (width + 0.6, 0.5, 1.0), (x, y - depth / 2 - 0.05, z), MATS["gold"])
    block(parts, f"{name}_crown_back", (width + 0.6, 0.5, 1.0), (x, y + depth / 2 + 0.05, z), MATS["gold"])
    block(parts, f"{name}_crown_left", (0.5, depth + 0.6, 1.0), (x - width / 2 - 0.05, y, z), MATS["gold"])
    block(parts, f"{name}_crown_right", (0.5, depth + 0.6, 1.0), (x + width / 2 + 0.05, y, z), MATS["gold"])
    block(parts, f"{name}_deck", (width - 0.2, depth - 0.2, 0.4), (x, y, top - 0.2), MATS["steel"])


def glass_tier(parts, name, size, center, sides):
    """Cuerpo de cristal con aristas de acero y muro cortina en las caras que se ven."""
    width, depth, height = size
    x, y, z = center
    z0, z1 = z - height / 2, z + height / 2
    block(parts, f"{name}_glass", size, center, MATS["glass"])
    floors = max(2, round(height / FLOOR))
    front_grid(parts, name, x - width / 2, x + width / 2, y - depth / 2, z0, z1,
               max(3, round(width / CURTAIN_BAY)), floors)
    if "left" in sides:
        side_grid(parts, name, y - depth / 2, y + depth / 2, x - width / 2, z0, z1,
                  max(2, round(depth / CURTAIN_BAY)), floors)
    if "right" in sides:
        side_grid(parts, name, y - depth / 2, y + depth / 2, x + width / 2, z0, z1,
                  max(2, round(depth / CURTAIN_BAY)), floors)
    # Aristas: cuatro pilastras de acero que dibujan el volumen contra el cielo.
    for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        block(parts, f"{name}_pilaster", (0.46, 0.46, height),
              (x + dx * (width / 2 - 0.04), y + dy * (depth / 2 - 0.04), z), MATS["steel"])


def glass_tower(parts, name, center, base, tiers):
    """Torre de cristal con retranqueos y remate de oro. `tiers` es [(ancho, fondo, alto, lados)]."""
    x, y = center
    z = base
    for index, (width, depth, height, sides) in enumerate(tiers):
        glass_tier(parts, f"{name}_{index}", (width, depth, height), (x, y, z + height / 2), sides)
        z += height
    width, depth, _, _ = tiers[-1]
    gold_crown(parts, name, (x, y), (width, depth), z)


def limestone_block(parts, name, x0, x1, height, depth=BLOCK_DEPTH):
    """Podio de caliza: zócalo, cuerpo, junta y cornisa. La altura se mide desde el suelo."""
    width = x1 - x0
    cx = (x0 + x1) / 2
    block(parts, f"{name}_plinth", (width + 0.8, depth + 0.8, 1.2), (cx, 0, 0.6), MATS["stone_dark"])
    block(parts, f"{name}_body", (width, depth, height - 2.4), (cx, 0, height / 2), MATS["stone"])
    block(parts, f"{name}_string", (width + 0.6, depth + 0.6, 0.6), (cx, 0, height - 2.0), MATS["stone_dark"])
    block(parts, f"{name}_cornice", (width + 1.6, depth + 1.2, 1.2), (cx, 0, height - 0.6), MATS["stone_dark"])


def glass_podium(parts, name, x0, x1, height, depth=BLOCK_DEPTH, pier_count=9):
    """Podio de caliza y muro cortina: el machón y la banda de piedra pesan tanto como el cristal.

    Tres plantas: zócalo de piedra, dos bandas corridas y cornisa. Entre ellas, el mismo cristal azul
    de las torres con montantes cada 5 studs. Así el podio es de caliza sin dejar de ser Zona Alta.
    """
    width = x1 - x0
    cx = (x0 + x1) / 2
    face = -depth / 2
    glass_top = height - 1.2
    block(parts, f"{name}_plinth", (width + 0.8, depth + 0.8, 1.6), (cx, 0, 0.8), MATS["stone_dark"])
    block(parts, f"{name}_glass", (width - 0.4, depth - 0.4, glass_top - 1.6), (cx, 0, (1.6 + glass_top) / 2), MATS["glass"])
    bays = max(4, round(width / CURTAIN_BAY))
    for index in range(bays + 1):
        x = x0 + width * index / bays
        block(parts, f"{name}_mullion", (0.24, 0.40, glass_top - 1.6), (x, face, (1.6 + glass_top) / 2), MATS["steel"])
    for index in range(pier_count):
        x = x0 + width * index / (pier_count - 1)
        block(parts, f"{name}_pier", (2.4, 1.1, glass_top - 1.6), (x, face - 0.15, (1.6 + glass_top) / 2), MATS["stone"])
    for z in (7.0, 14.0):
        block(parts, f"{name}_spandrel", (width + 0.4, 0.80, 1.8), (cx, face - 0.05, z), MATS["stone"])
    block(parts, f"{name}_string", (width + 0.6, depth + 0.6, 0.6), (cx, 0, glass_top), MATS["stone_dark"])
    block(parts, f"{name}_cornice", (width + 1.6, depth + 1.2, 1.2), (cx, 0, height - 0.6), MATS["stone_dark"])


def window_row(parts, name, x0, x1, z, width, height, bays, sill=True, face=-BLOCK_DEPTH / 2):
    """Ventanas caladas en la caliza, una por vano: el podio también es de cristal azul."""
    step = (x1 - x0) / bays
    for index in range(bays):
        x = x0 + step * (index + 0.5)
        block(parts, f"{name}_glass", (min(width, step - 3.0), 0.50, height), (x, face + 0.20, z), MATS["glass"])
        if sill:
            block(parts, f"{name}_sill", (min(width, step - 3.0) + 0.5, 0.55, 0.30), (x, face + 0.15, z - height / 2 - 0.18), MATS["stone_dark"])


def build_backdrop_a(_mats):
    """Manzana A: podio continuo de caliza, tres torres que bajan de izquierda a derecha y una plaza
    elevada en el hueco entre las dos primeras."""
    parts = []
    glass_podium(parts, "podium", -BLOCK_WIDTH / 2, BLOCK_WIDTH / 2, PODIUM)
    # Cornisa de entrada: una línea de acero a 8 studs que da la escala del podio.
    block(parts, "canopy", (72.0, 1.6, 0.40), (0, -10.6, 7.9), MATS["steel"])

    # Plaza elevada: barandilla de cristal, seto y pabellón en el hueco.
    block(parts, "terrace_glass", (72.0, 0.25, 1.1), (0, -9.5, 21.55), MATS["glass"])
    block(parts, "terrace_rail", (72.0, 0.36, 0.10), (0, -9.5, 22.15), MATS["steel"])
    block(parts, "terrace_hedge", (9.0, 1.10, 1.0), (-5.0, -8.90, 21.5), MATS["leaf"])
    block(parts, "pavilion_glass", (8.0, 5.0, 5.6), (-5.0, 0.0, 23.8), MATS["glass"])
    for dx in (-2.4, 0.0, 2.4):
        block(parts, "pavilion_mullion", (0.18, 0.30, 5.6), (-5.0 + dx, -2.55, 23.8), MATS["steel"])
    block(parts, "pavilion_band", (8.0, 0.34, 0.22), (-5.0, -2.55, 24.4), MATS["steel"])
    block(parts, "pavilion_roof", (8.8, 5.8, 0.5), (-5.0, 0.0, 26.85), MATS["steel"])

    # Tres torres: 90, 70 y 56 studs contando el podio. La más alta no pasa del techo de 92.
    glass_tower(parts, "tower_a", (-23.0, 0.0), PODIUM, [
        (26.0, 16.0, 56.0, ("left", "right")),
        (22.0, 12.0, 13.0, ("left", "right")),
    ])
    glass_tower(parts, "tower_b", (12.0, 0.0), PODIUM, [
        (24.0, 16.0, 35.0, ("left",)),
        (18.0, 12.0, 14.0, ("left",)),
    ])
    glass_tower(parts, "tower_c", (32.0, 0.0), PODIUM, [
        (16.0, 14.0, 28.0, ("right",)),
        (12.0, 10.0, 7.0, ()),
    ])
    return parts


def build_backdrop_b(_mats):
    """Manzana B: podio escalonado con dos alas bajas y terraza ajardinada, torre central escalonada
    y una pasarela de cristal que la cose con la torre izquierda."""
    parts = []
    limestone_block(parts, "wing_l", -BLOCK_WIDTH / 2, -16.0, 14.0)
    limestone_block(parts, "wing_r", 16.0, BLOCK_WIDTH / 2, 14.0)
    glass_podium(parts, "core", -16.0, 16.0, PODIUM, pier_count=4)
    block(parts, "canopy", (28.0, 1.6, 0.40), (0, -10.6, 7.9), MATS["steel"])
    for x0, x1 in ((-38.0, -18.0), (18.0, 38.0)):
        for z in (7.6, 11.2):
            window_row(parts, "wing_window", x0, x1, z, 4.4, 1.9, 2, sill=False)

    # Terrazas de las alas: peto de caliza, seto y barandilla.
    for x0, x1 in ((-38.0, -18.0), (18.0, 38.0)):
        cx = (x0 + x1) / 2
        block(parts, "terrace_parapet", (x1 - x0, 0.45, 0.90), (cx, -9.75, 14.45), MATS["stone_dark"])
        block(parts, "terrace_rail", (x1 - x0, 0.10, 0.10), (cx, -9.55, 14.95), MATS["steel"])
        block(parts, "terrace_hedge", (x1 - x0 - 3.0, 0.95, 0.85), (cx, -8.85, 14.95), MATS["leaf"])

    # Torres: la central manda, las laterales nacen en la terraza de las alas.
    glass_tower(parts, "tower_core", (0.0, 0.0), PODIUM, [
        (28.0, 18.0, 42.0, ("left", "right")),
        (22.0, 14.0, 14.0, ("left", "right")),
        (16.0, 10.0, 7.0, ()),
    ])
    glass_tower(parts, "tower_l", (-27.0, 0.0), 14.0, [
        (16.0, 14.0, 42.0, ("left", "right")),
        (12.0, 10.0, 7.0, ("right",)),
    ])
    glass_tower(parts, "tower_r", (27.0, 0.0), 14.0, [
        (14.0, 14.0, 56.0, ("left",)),
    ])
    # Pasarela de cristal entre la torre izquierda y la central.
    block(parts, "bridge_glass", (6.4, 6.0, 7.0), (-16.5, 0.0, 45.5), MATS["glass"])
    block(parts, "bridge_floor", (7.2, 6.8, 0.6), (-16.5, 0.0, 42.3), MATS["steel"])
    block(parts, "bridge_roof", (7.2, 6.8, 0.6), (-16.5, 0.0, 48.7), MATS["steel"])
    for x in (-18.2, -14.8):
        block(parts, "bridge_mullion", (0.22, 6.2, 5.8), (x, 0.0, 45.5), MATS["steel"])
    return parts


BUILDERS = (
    ("zona-alta-walk", build_walk),
    ("zona-alta-planter", build_planter),
    ("zona-alta-bench", build_bench),
    ("zona-alta-lamp", build_lamp),
    ("zona-alta-bollard", build_bollard),
)

BACKDROPS = (
    ("zona-alta-backdrop-a", build_backdrop_a),
    ("zona-alta-backdrop-b", build_backdrop_b),
)


# --- Revisión ------------------------------------------------------------------------------------


def street(backdrop, refs=True):
    """Monta la calle a escala de juego: calzada a 0, acera a 0,4 y el fondo apoyado en su borde."""
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()

    box("street", (360.0, 300.0, 0.4), (0.0, -60.0, -0.2), MATS["asphalt"])

    for x in (-20.0, 20.0):
        for part in build_walk(MATS):
            part.location.x += x
            part.location.y -= 13.5
            part.location.z += SIDEWALK_TOP

    def put(builder, x, y):
        for part in builder(MATS):
            part.location.x += x
            part.location.y += y
            part.location.z += SIDEWALK_TOP

    put(build_lamp, -9.0, -15.2)
    put(build_lamp, 13.0, -15.2)
    put(build_planter, -4.0, -15.2)
    put(build_planter, 7.5, -11.4)
    put(build_bench, 1.5, -11.6)
    for x in (-13.0, 3.0, 10.0):
        put(build_bollard, x, -16.4)

    # Referencias de escala sobre la acera y en los extremos: avatar (1,6 × 1,2 × 6) y ficha (6 ⌀ × 9).
    if refs:
        box("avatar_ref", (1.6, 1.2, 6.0), (-15.0, -20.0, 3.0), MATS["paint"])
        prism("token_ref", 3.0, 3.0, 9.0, (17.0, -19.5, 4.5), MATS["red"], 16)

    for part in backdrop(MATS):
        part.location.y += 0.0


def tone(view_transform, exposure=0.0):
    settings = bpy.context.scene.view_settings
    try:
        settings.view_transform = view_transform
        settings.look = "None"
    except TypeError:
        pass
    settings.exposure = exposure


def preview():
    """Dos vistas de revisión: la calle a escala de avatar y la manzana con su fondo detrás."""
    tone("Standard")
    street(build_backdrop_a)
    sun(energy=3.2, sky=0.55)
    render_preview("zona-alta-calle.png", (-6.0, -54.0, 11.0), (2.0, -11.0, 10.0), 30)

    # La manzana se mira sin las referencias de escala: estorban a la silueta.
    street(build_backdrop_a, refs=False)
    sun(energy=3.2, sky=0.55)
    render_preview("zona-alta-manzana.png", (55.0, -195.0, 60.0), (0.0, -2.0, 45.0), 40)


def main():
    from city_kit import reset_scene

    reset_scene()
    palette()
    stats = build_assets("zona-alta", BUILDERS, BACKDROPS, OUT, "zona-alta.blend")
    total = sum(entry["triangles"] for entry in stats.values())
    print(f"ZONA_ALTA_TOTAL {total}")
    preview()


if __name__ == "__main__":
    main()

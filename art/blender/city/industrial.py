"""Industrial: el barrio del trabajo de Metrópolis (plan 07, Tarea 3).

Ladrillo oscuro, acero y óxido (`art/guia-de-estilo.md` §7). Nada de caliza ni de cristal: el
hormigón, la chapa y el óxido hacen la identidad. La acera repite la plantilla de Centro —40 × 7, con
el bordillo en -Y y la faja junto a la fachada— pero es de hormigón y lleva tapa de arqueta y rejilla
de desagüe. El mobiliario es de obra: valla, palé con sacos y bidón, contenedor y farola de sodio. El
fondo son naves de ladrillo oscuro con lucernarios, chimeneas de 40 a 60, dos silos y una pasarela de
tubos; el detalle se gasta en la fachada que da a la ruta y lo de detrás queda en masa.

Salidas, en `art/blender/city/`:
  industrial-walk_{...}.fbx       acera y bordillo, 40 × 7
  industrial-barrier_{...}.fbx    valla de obra, 4 × 2,2
  industrial-pallet_{...}.fbx     palé con sacos y bidón, 1,6 de alto
  industrial-container_{...}.fbx  contenedor, 6 × 2,6 × 2,6
  industrial-lamp_{...}.fbx       farola de sodio, 12 de alto
  industrial-backdrop-{a,b}_{...}.fbx  naves, chimeneas y silos, 80 × 20
  industrial.blend                escena de revisión
  industrial-stats.json           triángulos reales

Y en `art/render/`: industrial-*.png. Son revisión técnica; la aprobación se hace en el juego.

Uso: blender --background --factory-startup --python art/blender/city/industrial.py
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

OUT = HERE

# La acera de `CityLayout`: 7 de ancho y una pieza por casilla, así que 40 de largo.
WALK_LENGTH = 40.0
WALK_WIDTH = 7.0
CURB_WIDTH = 0.88
# La chapa de la acera sobresale 7 centésimas del suelo: es el alto al que se apoyan los props.
WALK_TOP = 0.075


def extra(name, color, roughness=0.8, metallic=0.0):
    material = flat(name, color, roughness, metallic)
    MATS[name] = material
    return material


def palette():
    """La paleta del barrio, con los valores de `art/generators/city_assets.py`.

    Open Cloud no trae material, así que el color y el material se ponen después por el sufijo de la
    malla: si el albedo del guion no es el mismo, la lámina engaña. Por eso se copian aquí tal cual.
    """
    extra("concrete", "C4C0B8", 0.9)
    extra("curb", "9C9A94", 0.85)
    extra("flag_dark", "7C7A74", 0.9)
    extra("grate", "2B2F33", 0.55, 0.45)
    extra("rust", "8C4A2A", 0.85, 0.15)
    extra("brick_dark", "8E523C", 0.9)
    extra("window", "2E3A44", 0.4, 0.1)
    extra("paint", "DED8C8", 0.85)
    extra("canvas", "E0DACA", 0.95)
    extra("lamp_glass", "EDE5D3", 0.35)
    # `iron`, `steel`, `brick`, `slate` y `wood` ya vienen de `city_kit.PALETTE` con el valor bueno.


# --- Piezas de calle -----------------------------------------------------------------------------


def build_walk(_mats):
    """Acera de hormigón: losas con junta, bordillo en -Y, faja junto a la fachada, arqueta y rejilla.

    Como la de Centro, es una chapa que se apoya en la acera que levanta `CityBuilder`: el bordillo
    baja por debajo del suelo para que se lea el canto desde la calzada. Se distingue de la de Centro
    a la primera mirada: el hormigón es más oscuro y está sucio, las juntas van marcadas y el bordillo
    es la única pieza clara. El detalle propio del barrio son las dos piezas de fundición.
    """
    parts = [
        # Junta oscura: se ve por las ranuras entre losas, y aquí va más ancha que en Centro.
        box("joint", (WALK_LENGTH, WALK_WIDTH, 0.035), (0.0, 0.0, 0.0175), MATS["flag_dark"]),
    ]
    # Diez losas de 4 studs de hormigón apagado; dos reparadas más oscuras, como cualquier acera vieja.
    for order in range(10):
        x = -WALK_LENGTH / 2 + 2.0 + order * 4.0
        material = MATS["flag_dark"] if order in (2, 7) else MATS["curb"]
        parts.append(box("slab", (3.86, 5.1, 0.06), (x, 0.05, 0.045), material))
    # Junta longitudinal: parte la acera en dos paños, como el hormigón vertido en obra.
    parts.append(box("seam", (WALK_LENGTH, 0.12, 0.02), (0.0, 0.05, 0.075), MATS["flag_dark"]))
    # Faja junto a la fachada: más estrecha, más alta y oscura, como el canal de suciedad del muro.
    parts.append(box("faja", (WALK_LENGTH, 0.8, 0.08), (0.0, 3.1, 0.04), MATS["flag_dark"]))
    # Bordillo: la única pieza clara de la acera, del suelo a 10 centésimas.
    parts.append(
        box("curb", (WALK_LENGTH, CURB_WIDTH, 0.5), (0.0, -WALK_WIDTH / 2 + CURB_WIDTH / 2, -0.15), MATS["concrete"])
    )
    # Manchas: hormigón viejo junto a la arqueta y óxido en el desagüe. Nada de una acera limpia.
    for x, y, sx, sy in ((-14.2, 1.2, 2.2, 1.1), (-7.6, -1.6, 1.5, 0.9), (3.4, 2.2, 2.6, 1.0), (17.2, -1.9, 1.8, 1.2)):
        parts.append(box("stain", (sx, sy, 0.012), (x, y, 0.082), MATS["flag_dark"]))
    for x, y, sx, sy in ((-11.8, -1.9, 1.7, 0.7), (12.6, 0.6, 1.2, 0.6)):
        parts.append(box("rust_stain", (sx, sy, 0.01), (x, y, 0.084), MATS["rust"]))

    # Tapa de arqueta: aro galvanizado, tapa de fundición y sus ranuras radiales.
    parts.append(prism("manhole_rim", 1.48, 1.48, 0.05, (11.0, 0.3, 0.085), MATS["steel"], 16))
    parts.append(prism("manhole_lid", 1.3, 1.3, 0.05, (11.0, 0.3, 0.105), MATS["grate"], 16))
    for order in range(4):
        angle = math.radians(45.0 * order)
        parts.append(
            box("manhole_slot", (2.0, 0.14, 0.02), (11.0, 0.3, 0.125), MATS["iron"], (0.0, 0.0, angle))
        )
    parts.append(prism("manhole_hub", 0.3, 0.3, 0.03, (11.0, 0.3, 0.14), MATS["steel"], 8))

    # Rejilla de desagüe junto al bordillo: marco de fundición y barrotes galvanizados.
    parts.append(box("drain_frame", (2.8, 1.4, 0.05), (6.5, -1.75, 0.075), MATS["grate"]))
    parts.append(box("drain_pit", (2.4, 1.0, 0.03), (6.5, -1.75, 0.085), MATS["iron"]))
    for order in range(5):
        parts.append(box("drain_bar", (2.5, 0.12, 0.035), (6.5, -2.15 + order * 0.2, 0.1), MATS["steel"]))

    # Registro pequeño de servicios: el detalle que hace que la acera no sea una losa sola.
    parts.append(box("service_lid", (0.9, 0.9, 0.03), (-6.0, 1.9, 0.085), MATS["steel"]))
    parts.append(box("service_ring", (1.05, 1.05, 0.02), (-6.0, 1.9, 0.075), MATS["grate"]))
    return parts


def build_barrier(_mats):
    """Valla de obra de 4 × 2,2: bastidor de acero, malla de alambre y pies de hormigón.

    Mira a -Y, como todo: el paño de malla queda de cara a la calle, los pies detrás y el faldón de
    señalización delante, que es lo que la hace legible a la distancia de la cámara.
    """
    parts = []
    for side in (-1, 1):
        x = side * 1.62
        parts.append(box("foot", (0.72, 0.95, 0.28), (x, 0.0, 0.14), MATS["concrete"]))
        parts.append(box("socket", (0.26, 0.26, 0.12), (x, 0.0, 0.31), MATS["steel"]))
        parts.append(tube("post", (x, 0.0, 0.3), (x, 0.0, 2.2), 0.075, MATS["steel"], 8))
        # Puntal en diagonal: sin él la valla parece un dibujo y no una pieza de obra.
        parts.append(tube("brace", (x, 0.0, 0.42), (x, 1.1, 0.02), 0.05, MATS["steel"], 5))
    parts.append(tube("rail_top", (-1.62, 0.0, 2.18), (1.62, 0.0, 2.18), 0.06, MATS["steel"], 6))
    parts.append(tube("rail_bottom", (-1.62, 0.0, 0.38), (1.62, 0.0, 0.38), 0.05, MATS["steel"], 6))
    # Malla: alambre vertical y horizontal, no una chapa. Con cuatro caras basta a escala de calle.
    for order in range(9):
        x = -1.5 + order * 0.375
        parts.append(tube("wire_v", (x, 0.0, 0.38), (x, 0.0, 2.18), 0.022, MATS["iron"], 4))
    for order in range(6):
        z = 0.5 + order * 0.32
        parts.append(tube("wire_h", (-1.56, 0.0, z), (1.56, 0.0, z), 0.022, MATS["iron"], 4))
    # Faldón: chapa clara con franjas rojas, lo único de la pieza que no es acero.
    parts.append(box("kick", (3.5, 0.05, 0.42), (0.0, -0.07, 0.62), MATS["paint"]))
    for order in range(4):
        parts.append(box("stripe", (0.34, 0.06, 0.4), (-1.25 + order * 0.84, -0.1, 0.62), MATS["red"]))
    return parts


def build_pallet(_mats):
    """Palé con sacos y un bidón: 1,6 de alto, la carga que nunca falta en una acera de obra.

    El palé es de tablones y el bidón de chapa con sus fajas; los sacos van en dos capas de lona,
    con la panza hacia fuera, que es lo que se ve de una carga real.
    """
    parts = []
    # Palé: tres tablones abajo, tres largueros y cinco tablas arriba.
    for y in (-0.45, 0.0, 0.45):
        parts.append(box("board", (1.5, 0.16, 0.035), (0.0, y, 0.018), MATS["wood"]))
        parts.append(box("bearer", (1.5, 0.14, 0.085), (0.0, y, 0.078), MATS["wood"]))
    for order in range(5):
        y = -0.5 + order * 0.25
        parts.append(box("deck", (1.5, 0.17, 0.04), (0.0, y, 0.14), MATS["wood"]))
    # Cuatro sacos: dos abajo y dos arriba, con el nudo hacia dentro y la panza hacia la calle.
    sacks = (
        (-0.37, -0.02, 0.55, 0.44, 0.78),
        (0.37, 0.02, 0.55, 0.43, 0.76),
        (-0.19, 0.0, 1.2, 0.4, 0.74),
        (0.23, 0.03, 1.22, 0.38, 0.72),
    )
    for order, (x, y, z, radius, squash) in enumerate(sacks):
        parts.append(sphere(f"sack_{order}", radius, (x, y, z), MATS["canvas"], 1, squash, 0.12, seed=order + 3))
    # Bidón de chapa al lado, con sus dos fajas y el tapón: el óxido que firma el barrio.
    parts.append(prism("drum", 0.31, 0.31, 1.15, (1.08, 0.18, 0.575), MATS["rust"], 12))
    for z in (0.36, 0.86):
        parts.append(prism("drum_band", 0.325, 0.325, 0.07, (1.08, 0.18, z), MATS["steel"], 12))
    parts.append(prism("drum_rim", 0.33, 0.33, 0.05, (1.08, 0.18, 1.16), MATS["steel"], 12))
    parts.append(box("drum_cap", (0.16, 0.16, 0.05), (1.0, 0.18, 1.2), MATS["iron"]))
    return parts


def build_container(_mats):
    """Contenedor de 6 × 2,6 × 2,6: chapa corrugada, esquineras de acero y puertas de óxido.

    La corrugación se modela de verdad en la cara que da a la calle (-Y); el resto es masa. Las
    puertas van en el costado -X porque en un contenedor siempre están en el lado corto, y así se
    ven desde el extremo de la calle por el que se mira la lámina.
    """
    parts = [
        box("body", (5.7, 2.28, 2.2), (0.0, 0.0, 1.35), MATS["steel"]),
        box("floor", (6.0, 2.4, 0.12), (0.0, 0.0, 0.2), MATS["steel"]),
    ]
    # Esquineras y largueros: el esqueleto de acero que hace que se lea como contenedor.
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box("corner", (0.22, 0.22, 2.42), (sx * 2.85, sy * 1.14, 1.36), MATS["steel"]))
            parts.append(box("casting", (0.3, 0.3, 0.22), (sx * 2.85, sy * 1.14, 2.46), MATS["steel"]))
            parts.append(box("casting", (0.3, 0.3, 0.22), (sx * 2.85, sy * 1.14, 0.26), MATS["steel"]))
    for sy in (-1, 1):
        parts.append(box("rail_top", (5.8, 0.16, 0.18), (0.0, sy * 1.2, 2.48), MATS["steel"]))
        parts.append(box("rail_bottom", (5.8, 0.16, 0.18), (0.0, sy * 1.2, 0.24), MATS["rust"]))
    # Corrugado: costillas verticales. Veintiuna delante, diez detrás y cinco en el costado ciego;
    # la cara de la calle es la única que se mira de cerca, así que es la que lleva el paso fino.
    for order in range(21):
        x = -2.6 + order * 0.26
        parts.append(box("rib", (0.12, 0.15, 2.06), (x, -1.2, 1.36), MATS["steel"]))
    for order in range(10):
        x = -2.45 + order * 0.55
        parts.append(box("rib_back", (0.1, 0.13, 2.06), (x, 1.2, 1.36), MATS["steel"]))
    for order in range(5):
        y = -0.94 + order * 0.47
        parts.append(box("rib_side", (0.13, 0.09, 2.06), (2.9, y, 1.36), MATS["steel"]))
    # Puertas: dos hojas de chapa comidas por el óxido, cuatro cierres verticales y las manillas.
    for sy in (-1, 1):
        parts.append(box("door", (0.1, 1.12, 2.2), (-2.93, sy * 0.57, 1.34), MATS["rust"]))
    for order, y in enumerate((-0.98, -0.34, 0.34, 0.98)):
        parts.append(tube("lock_rod", (-3.0, y, 0.34), (-3.0, y, 2.32), 0.045, MATS["steel"], 6))
        parts.append(box("hinge", (0.16, 0.12, 0.14), (-2.96, y, 0.5 + order * 0.06), MATS["steel"]))
    for sy in (-1, 1):
        parts.append(box("handle", (0.1, 0.26, 0.08), (-3.02, sy * 0.2, 1.1), MATS["steel"]))
    # Placado pintado y las bolsas de las horquillas: nada de letras, que el barrio no es una marca.
    parts.append(box("placard", (1.1, 0.05, 0.6), (-0.8, -1.28, 1.6), MATS["paint"]))
    for x in (-1.5, 1.5):
        parts.append(box("fork_pocket", (1.2, 0.4, 0.22), (x, 0.0, 0.12), MATS["grate"]))
    return parts


def build_lamp(_mats):
    """Farola de sodio: basa de hormigón, poste recto, brazo recto y pantalla rectangular.

    Doce studs hasta la coronación. La pantalla va horizontal y el vidrio mira abajo, que es como se
    ve una farola de sodio desde la calle; el resto es acero galvanizado, sin una sola curva de forja.
    """
    parts = [
        prism("base", 0.54, 0.44, 0.5, (0.0, 0.0, 0.25), MATS["concrete"], 8),
        prism("collar", 0.4, 0.36, 0.14, (0.0, 0.0, 0.57), MATS["rust"], 8),
        prism("post", 0.19, 0.12, 11.1, (0.0, 0.0, 6.19), MATS["steel"], 8),
        # Registro de acceso y su tapa, a la altura de la mano.
        box("hatch", (0.26, 0.04, 0.52), (0.0, -0.17, 1.35), MATS["iron"]),
    ]
    parts.append(tube("arm", (0.0, 0.0, 11.74), (0.0, -2.1, 11.74), 0.085, MATS["steel"], 6))
    parts.append(tube("gusset", (0.0, -0.06, 11.14), (0.0, -1.45, 11.69), 0.055, MATS["steel"], 5))
    # Pantalla: caja rectangular con el vidrio debajo y el casquete arriba.
    parts.append(box("head", (0.95, 1.7, 0.24), (0.0, -2.7, 11.63), MATS["steel"]))
    parts.append(box("lens", (0.74, 1.32, 0.06), (0.0, -2.7, 11.48), MATS["lamp_glass"]))
    parts.append(box("cap", (1.04, 1.8, 0.06), (0.0, -2.7, 11.78), MATS["steel"]))
    parts.append(box("photocell", (0.18, 0.22, 0.12), (0.0, -2.0, 11.87), MATS["iron"]))
    return parts


# --- Gramática de fachada ------------------------------------------------------------------------


def band_windows(parts, x0, x1, y, z, height, cols):
    """Ventanal corrido de nave: cristal rehundido, alféizar de hormigón y carpintería de acero."""
    width = x1 - x0
    center = (x0 + x1) / 2.0
    parts.append(box("sill", (width + 0.6, 0.5, 0.24), (center, y + 0.02, z - 0.12), MATS["concrete"]))
    parts.append(box("glass", (width, 0.5, height), (center, y + 0.1, z + height / 2.0), MATS["window"]))
    parts.append(box("lintel", (width + 0.5, 0.4, 0.16), (center, y + 0.03, z + height + 0.08), MATS["iron"]))
    # Travesaño: la línea que convierte una banda de cristal en una carpintería de taller.
    parts.append(box("transom", (width, 0.3, 0.12), (center, y - 0.02, z + height * 0.56), MATS["steel"]))
    step = width / cols
    for order in range(1, cols):
        x = x0 + step * order
        parts.append(box("mullion", (0.16, 0.3, height), (x, y - 0.02, z + height / 2.0), MATS["steel"]))


def tall_window(parts, x, y, z, width, height):
    """Ventana alta y estrecha de taller: cristal, alféizar de hormigón y carpintería de acero."""
    parts.append(box("tall_glass", (width, 0.5, height), (x, y + 0.1, z + height / 2.0), MATS["window"]))
    parts.append(box("tall_sill", (width + 0.5, 0.55, 0.2), (x, y + 0.02, z - 0.1), MATS["concrete"]))
    parts.append(box("tall_mullion", (0.16, 0.3, height), (x, y - 0.02, z + height / 2.0), MATS["steel"]))
    parts.append(box("tall_transom", (width, 0.3, 0.12), (x, y - 0.02, z + height * 0.58), MATS["steel"]))


def gate(parts, x, y, width, height, detail=True):
    """Portón de taller: hoja corrugada de guillotina, cerco de acero y, si toca, remaches."""
    parts.append(box("gate_recess", (width + 0.4, 0.5, height + 0.3), (x, y + 0.12, (height + 0.3) / 2.0), MATS["grate"]))
    parts.append(box("gate_leaf", (width, 0.18, height), (x, y - 0.06, height / 2.0), MATS["steel"]))
    for order in range(1, 4):
        z = height * order / 4.0
        parts.append(box("gate_rib", (width - 0.1, 0.22, 0.12), (x, y - 0.16, z), MATS["rust"]))
    parts.append(box("gate_lintel", (width + 0.8, 0.55, 0.4), (x, y + 0.02, height + 0.35), MATS["steel"]))
    for side in (-1, 1):
        parts.append(
            box(
                "gate_jamb",
                (0.3, 0.55, height + 0.7),
                (x + side * (width / 2.0 + 0.25), y + 0.02, (height + 0.7) / 2.0),
                MATS["steel"],
            )
        )
    if detail:
        for order in range(6):
            rx = x - width / 2.0 + 0.5 + order * (width - 1.0) / 5.0
            parts.append(box("rivet", (0.16, 0.12, 0.16), (rx, y - 0.2, height + 0.35), MATS["steel"]))
        for side in (-1, 1):
            parts.append(
                box("bumper", (0.5, 0.45, 0.5), (x + side * (width / 2.0 - 0.4), y - 0.2, 0.85), MATS["grate"])
            )


def personnel_door(parts, x, y, width, height):
    """Puerta de personal con su cerco: lo que llena una fachada entre dos portones."""
    parts.append(box("door_recess", (width + 0.3, 0.3, height + 0.2), (x, y + 0.08, (height + 0.2) / 2.0), MATS["grate"]))
    parts.append(box("door", (width, 0.14, height), (x, y - 0.05, height / 2.0), MATS["steel"]))
    parts.append(box("door_frame", (width + 0.5, 0.28, 0.22), (x, y - 0.02, height + 0.14), MATS["concrete"]))
    parts.append(box("door_handle", (0.1, 0.12, 0.1), (x + width * 0.32, y - 0.15, 1.15), MATS["iron"]))


def chimney(parts, x, y, z0, radius, height, material, band_material):
    """Chimenea troncocónica con fajas y coronación. La base queda dentro de la nave."""
    parts.append(prism("chimney", radius, radius * 0.62, height, (x, y, z0 + height / 2.0), material, 12))
    for order in range(3):
        fraction = 0.22 + order * 0.24
        band_radius = radius - radius * 0.38 * fraction + 0.12
        parts.append(
            prism("chimney_band", band_radius, band_radius, 0.55, (x, y, z0 + height * fraction), band_material, 12)
        )
    top_radius = radius * 0.62
    parts.append(
        prism("chimney_cap", top_radius + 0.35, top_radius + 0.35, 1.0, (x, y, z0 + height + 0.45), MATS["slate"], 12)
    )


def silo(parts, x, y, z0, radius, height, top, legs=0.0):
    """Silo cilíndrico con cono de carga: sobre basa de hormigón o sobre patas de acero."""
    base = z0 + legs
    if legs:
        for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            parts.append(
                box(
                    "silo_leg",
                    (0.42, 0.42, legs),
                    (x + dx * radius * 0.6, y + dy * radius * 0.6, z0 + legs / 2.0),
                    MATS["steel"],
                )
            )
        parts.append(prism("silo_hopper", 0.6, radius * 0.96, 3.4, (x, y, base - 1.7), MATS["steel"], 12))
        parts.append(box("silo_brace", (radius * 1.2, 0.3, 0.3), (x, y - radius * 0.6, z0 + legs * 0.55), MATS["iron"]))
    parts.append(prism("silo", radius, radius, height, (x, y, base + height / 2.0), MATS["steel"], 12))
    parts.append(prism("silo_cone", radius, 0.55, top, (x, y, base + height + top / 2.0), MATS["steel"], 12))
    parts.append(prism("silo_band", radius + 0.1, radius + 0.1, 0.4, (x, y, base + height * 0.2), MATS["rust"], 12))
    parts.append(prism("silo_band", radius + 0.1, radius + 0.1, 0.4, (x, y, base + height * 0.6), MATS["rust"], 12))


# --- Fondos --------------------------------------------------------------------------------------


def build_backdrop_a(_mats):
    """Nave con lucernarios, taller de cinco plantas, patio de silos, anexo y dos chimeneas.

    De izquierda a derecha: chimenea de 52, nave de tres dientes de sierra, pasarela de tubos sobre
    el patio, taller de 35 con sus ventanales corridos, patio de silos y anexo con chimenea de 44.
    Las fachadas que dan a la ruta (-Y) llevan el detalle; el fondo de cada volumen es masa.
    """
    parts = []
    front = -10.0

    # --- Nave: 22 de ancho, 16 de alero y tres dientes de sierra.
    parts.extend(
        [
            box("nave", (22.0, 20.0, 16.0), (-29.0, 0.0, 8.0), MATS["brick_dark"]),
            box("nave_plinth", (22.4, 20.4, 1.2), (-29.0, 0.0, 0.6), MATS["concrete"]),
            box("nave_band", (22.4, 0.5, 0.35), (-29.0, front + 0.1, 5.2), MATS["brick"]),
            box("nave_parapet", (22.6, 0.7, 0.9), (-29.0, front + 0.2, 16.4), MATS["concrete"]),
        ]
    )
    for side in (-1, 1):
        parts.append(box("nave_pilaster", (0.8, 0.6, 16.0), (-29.0 + side * 10.6, front + 0.2, 8.0), MATS["brick"]))
    for z in (6.4, 11.2):
        band_windows(parts, -37.6, -20.4, front, z, 2.0, 5)
    gate(parts, -30.0, front, 7.0, 6.2, detail=False)
    # Dientes de sierra: panel inclinado, lucernario de cara a la calle y su marco.
    for y0 in (-9.9, -3.3, 3.3):
        parts.append(
            box(
                "saw_roof",
                (22.0, 7.2, 0.28),
                (-29.0, y0 + 3.2, 17.65),
                MATS["slate"],
                (math.radians(27.5), 0.0, 0.0),
            )
        )
        parts.append(box("saw_glass", (22.0, 0.3, 3.3), (-29.0, y0 + 6.3, 17.65), MATS["window"]))
        parts.append(box("saw_frame", (22.0, 0.42, 0.18), (-29.0, y0 + 6.3, 19.35), MATS["steel"]))

    # --- Pasarela de tubos: del taller a la nave, sobre el patio, a la altura del tercer piso.
    parts.extend(
        [
            box("bridge_floor", (9.2, 2.2, 0.22), (-14.0, 0.0, 21.0), MATS["grate"]),
            box("bridge_kick", (9.2, 0.12, 0.25), (-14.0, -1.06, 21.25), MATS["steel"]),
        ]
    )
    for side in (-1, 1):
        parts.append(box("bridge_rail", (9.2, 0.1, 0.1), (-14.0, side * 1.05, 22.35), MATS["steel"]))
        for order in range(3):
            parts.append(
                box("bridge_post", (0.09, 0.09, 1.3), (-18.0 + order * 4.0, side * 1.05, 21.75), MATS["steel"])
            )
    for order, z in enumerate((21.5, 22.0, 22.5)):
        parts.append(
            tube("bridge_pipe", (-19.0, 1.6, z), (-9.0, 1.6, z), 0.3, MATS["rust"] if order == 1 else MATS["steel"], 8)
        )
    for x in (-18.0, -14.0, -10.0):
        parts.append(box("bridge_bracket", (0.45, 0.8, 0.3), (x, 1.3, 21.9), MATS["iron"]))
    # Bajante del taller: el tubo que recoge lo que llevan los tres anteriores.
    parts.append(tube("drop_pipe", (-9.6, -9.0, 21.5), (-9.6, -9.0, 1.4), 0.22, MATS["rust"], 6))

    # --- Taller: 20 de ancho, 5 plantas, ventanal corrido por planta y portón.
    parts.extend(
        [
            box("shop", (20.0, 20.0, 35.0), (0.0, 0.0, 17.5), MATS["brick_dark"]),
            box("shop_plinth", (20.4, 20.4, 1.3), (0.0, 0.0, 0.65), MATS["concrete"]),
            box("shop_cornice", (20.8, 0.9, 0.8), (0.0, front + 0.15, 35.3), MATS["concrete"]),
            box("shop_roof", (19.4, 19.4, 0.35), (0.0, 0.0, 35.15), MATS["slate"]),
        ]
    )
    for z in (7.0, 14.0, 21.0, 28.0):
        parts.append(box("shop_band", (20.5, 0.5, 0.3), (0.0, front + 0.1, z), MATS["brick"]))
    for z in (8.4, 15.4, 22.4, 29.4):
        band_windows(parts, -8.0, 8.0, front, z, 2.2, 5)
    gate(parts, -4.5, front, 6.5, 6.2, detail=False)
    personnel_door(parts, 3.0, front, 1.6, 2.8)
    for x in (6.6, 8.4):
        parts.append(box("shop_vent", (0.9, 1.1, 0.8), (x, front + 0.2, 4.6), MATS["grate"]))
    parts.append(box("roof_hatch", (2.2, 2.2, 0.45), (3.0, 4.0, 35.55), MATS["rust"]))
    parts.append(box("roof_stack", (0.9, 0.9, 2.2), (-5.5, 3.0, 36.2), MATS["steel"]))
    for x in (-9.7, 9.7):
        parts.append(tube("downpipe", (x, front + 0.25, 1.2), (x, front + 0.25, 34.6), 0.16, MATS["rust"], 6))

    # --- Patio de silos: murete a la calle, plinth y dos cilindros de 35.
    parts.extend(
        [
            box("yard_wall", (20.0, 0.6, 1.2), (20.0, front + 0.3, 0.6), MATS["brick_dark"]),
            box("yard_coping", (20.2, 0.8, 0.16), (20.0, front + 0.3, 1.28), MATS["concrete"]),
            box("yard_pier", (0.9, 1.0, 2.0), (10.6, front + 0.35, 1.0), MATS["brick"]),
            box("yard_pier", (0.9, 1.0, 2.0), (29.4, front + 0.35, 1.0), MATS["brick"]),
            box("silo_plinth", (16.0, 7.0, 1.4), (20.0, 2.0, 0.7), MATS["concrete"]),
        ]
    )
    for x in (14.5, 20.0, 25.5):
        parts.append(box("yard_bar", (0.09, 0.09, 1.9), (x, front + 0.3, 0.95), MATS["iron"]))
    for x in (15.5, 24.5):
        silo(parts, x, 2.0, 1.4, 3.4, 27.0, 5.4)
    parts.append(box("compressor", (1.8, 1.2, 1.6), (20.0, 7.4, 0.8), MATS["steel"]))
    parts.append(tube("silo_pipe", (15.5, 2.0, 34.7), (15.5, 2.0, 36.2), 0.3, MATS["rust"], 6))

    # --- Anexo: 10 de ancho y 22 de alto, con la segunda chimenea saliendo del tejado.
    parts.extend(
        [
            box("annex", (10.0, 20.0, 22.0), (35.0, 0.0, 11.0), MATS["brick_dark"]),
            box("annex_plinth", (10.4, 20.4, 1.2), (35.0, 0.0, 0.6), MATS["concrete"]),
            box("annex_cornice", (10.7, 20.7, 0.5), (35.0, 0.0, 21.95), MATS["concrete"]),
            box("annex_roof", (10.3, 20.3, 0.4), (35.0, 0.0, 22.15), MATS["slate"]),
        ]
    )
    for z in (8.4, 15.4):
        band_windows(parts, 31.6, 38.4, front, z, 2.0, 3)
    personnel_door(parts, 35.0, front, 1.6, 2.8)
    for x in (32.0, 38.0):
        parts.append(box("annex_vent", (0.8, 0.8, 1.8), (x, 4.0, 23.0), MATS["steel"]))

    # Chimeneas: la de la nave remata la silueta por la izquierda; la del anexo, por la derecha.
    # Ladrillo oscuro con las fajas en el ladrillo claro del barrio: el remate, no el cuerpo.
    chimney(parts, -28.0, 4.5, 0.0, 2.6, 52.0, MATS["brick_dark"], MATS["brick"])
    chimney(parts, 34.0, 2.5, 0.0, 2.0, 44.0, MATS["brick_dark"], MATS["brick"])
    return parts


def build_backdrop_b(_mats):
    """Variante de fundición: silos sobre patas, nave con monitor, torre de seis plantas y chimenea
    de acero.

    La masa cambia respecto a A: la izquierda es un patio de silos, el centro una nave baja con
    lucernario corrido y la derecha una torre alta con ventanas verticales y su casa de calderas.
    """
    parts = []
    front = -10.0

    # --- Patio de silos a la izquierda: murete, dos cilindros sobre patas y su compresor.
    parts.extend(
        [
            box("yard_wall", (14.0, 0.6, 1.2), (-33.0, front + 0.3, 0.6), MATS["concrete"]),
            box("yard_coping", (14.2, 0.8, 0.16), (-33.0, front + 0.3, 1.28), MATS["brick_dark"]),
        ]
    )
    for x in (-38.5, -35.0, -31.0, -27.5):
        parts.append(box("yard_bar", (0.09, 0.09, 1.9), (x, front + 0.3, 0.95), MATS["iron"]))
    for x in (-36.0, -29.5):
        silo(parts, x, 1.0, 0.0, 3.2, 21.0, 5.0, legs=8.0)
    parts.append(box("compressor", (1.8, 1.4, 1.6), (-32.8, 7.2, 0.8), MATS["steel"]))

    # --- Nave: 34 de ancho, 18 de alero, tres portones y monitor con dos fajas de cristal.
    parts.extend(
        [
            box("shed", (34.0, 20.0, 18.0), (-9.0, 0.0, 9.0), MATS["brick_dark"]),
            box("shed_plinth", (34.4, 20.4, 1.2), (-9.0, 0.0, 0.6), MATS["concrete"]),
            box("shed_eave", (34.4, 0.5, 0.5), (-9.0, front + 0.1, 17.9), MATS["concrete"]),
            box("shed_roof", (33.4, 19.6, 0.35), (-9.0, 0.0, 18.2), MATS["slate"]),
            box("monitor", (26.0, 9.0, 4.4), (-9.0, 0.0, 20.3), MATS["brick_dark"]),
            box("monitor_cap", (26.6, 9.6, 0.35), (-9.0, 0.0, 22.6), MATS["slate"]),
        ]
    )
    for z in (10.8, 13.8):
        band_windows(parts, -24.5, 6.5, front, z, 2.2, 7)
    for x in (-19.0, -9.0, 1.0):
        gate(parts, x, front, 6.4, 6.4, detail=False)
    for y in (-4.56, 4.56):
        parts.append(box("monitor_glass", (26.0, 0.3, 2.2), (-9.0, y, 20.5), MATS["window"]))
        parts.append(box("monitor_sill", (26.3, 0.5, 0.2), (-9.0, y, 19.3), MATS["concrete"]))
    parts.append(box("roof_vent", (1.0, 1.0, 2.0), (-20.0, 5.0, 19.2), MATS["steel"]))

    # --- Pasarela de tubos en el patio entre la nave y la torre, con sus apoyos y su barandilla.
    parts.append(box("rack_walk", (8.6, 1.8, 0.18), (12.0, -1.6, 16.2), MATS["grate"]))
    for side in (-1, 1):
        parts.append(box("rack_rail", (8.6, 0.1, 0.1), (12.0, -1.6 + side * 0.85, 17.4), MATS["steel"]))
        for order in range(3):
            parts.append(
                box("rack_post", (0.09, 0.09, 1.2), (9.0 + order * 3.0, -1.6 + side * 0.85, 16.9), MATS["steel"])
            )
    for order, z in enumerate((16.9, 17.4, 17.9, 18.4)):
        parts.append(
            tube("rack_pipe", (7.6, 1.5, z), (16.4, 1.5, z), 0.26, MATS["rust"] if order % 2 else MATS["steel"], 8)
        )
    for x in (9.2, 12.0, 14.8):
        parts.append(box("rack_column", (0.45, 0.45, 16.2), (x, 1.2, 8.1), MATS["steel"]))
        parts.append(box("rack_arm", (0.35, 3.0, 0.25), (x, 1.0, 16.5), MATS["steel"]))

    # --- Torre: 16 de ancho, 6 plantas de ventanas altas, bandas de hormigón y rótulo pintado.
    parts.extend(
        [
            box("tower", (16.0, 20.0, 42.0), (24.0, 0.0, 21.0), MATS["brick_dark"]),
            box("tower_plinth", (16.4, 20.4, 1.4), (24.0, 0.0, 0.7), MATS["concrete"]),
            box("tower_cornice", (16.8, 0.9, 0.9), (24.0, front + 0.15, 42.3), MATS["concrete"]),
            box("tower_roof", (15.4, 19.4, 0.35), (24.0, 0.0, 42.1), MATS["slate"]),
        ]
    )
    for z in (7.0, 14.0, 21.0, 28.0, 35.0):
        parts.append(box("tower_band", (16.5, 0.5, 0.28), (24.0, front + 0.1, z), MATS["brick"]))
    for x in (19.0, 24.0, 29.0):
        for row in range(4):
            tall_window(parts, x, front, 8.2 + row * 7.0, 2.4, 2.6)
    # Placa de chapa oxidada y remachada en la coronación: el remate que firma la torre.
    parts.append(box("tower_plate", (12.0, 0.22, 1.3), (24.0, front - 0.08, 38.4), MATS["rust"]))
    for order in range(5):
        parts.append(box("rivet", (0.16, 0.14, 0.16), (19.2 + order * 2.4, front - 0.24, 38.4), MATS["steel"]))
    for x in (15.7, 32.3):
        parts.append(tube("downpipe", (x, front + 0.25, 1.4), (x, front + 0.25, 41.4), 0.16, MATS["rust"], 6))

    # --- Casa de calderas: 8 de ancho, con la chimenea de acero saliendo del tejado.
    parts.extend(
        [
            box("boiler", (8.0, 20.0, 14.0), (36.0, 0.0, 7.0), MATS["brick_dark"]),
            box("boiler_plinth", (8.4, 20.4, 1.0), (36.0, 0.0, 0.5), MATS["concrete"]),
            box("boiler_cornice", (8.5, 20.5, 0.35), (36.0, 0.0, 13.95), MATS["concrete"]),
            box("boiler_roof", (8.2, 20.2, 0.4), (36.0, 0.0, 14.15), MATS["slate"]),
        ]
    )
    gate(parts, 36.0, front, 4.6, 5.0, detail=False)
    band_windows(parts, 33.0, 39.0, front, 8.6, 1.8, 3)
    parts.append(prism("stack", 1.25, 0.9, 30.0, (36.0, 4.0, 15.0), MATS["rust"], 10))
    parts.append(prism("stack_cap", 1.35, 1.35, 0.6, (36.0, 4.0, 30.3), MATS["steel"], 10))

    # Chimenea de ladrillo sobre la nave: la única vertical de ladrillo que queda en esta variante.
    chimney(parts, -12.0, 5.0, 0.0, 2.8, 56.0, MATS["brick_dark"], MATS["brick_dark"])
    return parts


BUILDERS = (
    ("industrial-walk", build_walk),
    ("industrial-barrier", build_barrier),
    ("industrial-pallet", build_pallet),
    ("industrial-container", build_container),
    ("industrial-lamp", build_lamp),
)

BACKDROPS = (
    ("industrial-backdrop-a", build_backdrop_a),
    ("industrial-backdrop-b", build_backdrop_b),
)


# --- Revisión ------------------------------------------------------------------------------------


def build_facade_ref():
    """Fachada de referencia de la lámina de calle: 56 de ancho y 18 de alto, con lucernario.

    Es una nave-taller de dos plantas, no un bloque de oficinas: zócalo, dos portones de guillotina
    con su refuerzo oxidado, ventanas altas y estrechas, rejillas de ventilación, escalera de
    mantenimiento, canalón y bajantes de chapa, y un lucernario corrido por encima de la cornisa.
    Es la misma gramática que los fondos, a escala de viandante. No se exporta: solo sirve para
    juzgar los props y los materiales contra una pared de verdad.
    """
    front = 3.6
    parts = [
        box("facade", (64.0, 12.0, 18.0), (0.0, front + 6.0, 9.0), MATS["brick_dark"]),
        box("facade_plinth", (64.6, 12.4, 1.2), (0.0, front + 6.0, 0.6), MATS["concrete"]),
        box("facade_cornice", (64.6, 0.9, 0.6), (0.0, front + 0.1, 18.2), MATS["concrete"]),
        box("facade_roof", (63.0, 11.0, 0.3), (0.0, front + 6.0, 18.0), MATS["slate"]),
        # Canalón de chapa oxidada en el alero: el óxido empieza aquí y sigue por las bajantes.
        box("gutter", (64.8, 0.8, 0.35), (0.0, front - 0.05, 18.6), MATS["rust"]),
        # Dos carreras de ladrillo que sobresalen: rompen el paño y dan la sombra de una fábrica.
        box("string_course", (64.2, 0.35, 0.22), (0.0, front + 0.05, 7.7), MATS["brick"]),
        box("string_course", (64.2, 0.35, 0.22), (0.0, front + 0.05, 12.4), MATS["brick"]),
    ]
    # Lucernario: el monitor corrido por encima de la cornisa, con su faja de cristal de cara a la
    # calle. Es lo que impide que la fachada se lea como una oficina de los setenta.
    parts.extend(
        [
            box("monitor", (46.0, 7.5, 3.2), (0.0, 7.6, 19.7), MATS["brick_dark"]),
            box("monitor_glass", (46.0, 0.3, 2.1), (0.0, 3.8, 19.85), MATS["window"]),
            box("monitor_sill", (46.3, 0.5, 0.2), (0.0, 3.75, 18.7), MATS["concrete"]),
            box("monitor_lintel", (46.3, 0.4, 0.18), (0.0, 3.75, 21.0), MATS["steel"]),
            box("monitor_cap", (46.8, 8.0, 0.35), (0.0, 7.6, 21.45), MATS["slate"]),
        ]
    )
    for order in range(5):
        x = -18.4 + order * 9.2
        parts.append(box("monitor_mullion", (0.14, 0.34, 2.1), (x, 3.75, 19.85), MATS["steel"]))
    # Ventanas altas y estrechas, dos plantas y ocho ejes: nada de bandas corridas.
    for z, height in ((8.4, 3.0), (13.4, 2.5)):
        for column in range(8):
            x = -24.5 + column * 7.0
            tall_window(parts, x, front, z, 2.2, height)
    # Portones de guillotina, grandes y con remaches; la puerta de personal, entre los dos.
    gate(parts, -12.0, front, 8.5, 7.4, detail=True)
    gate(parts, 6.0, front, 8.5, 7.4, detail=True)
    personnel_door(parts, -2.0, front, 1.6, 2.9)
    # Rejillas de ventilación: dos a pie de calle y dos en la planta alta.
    for x, z in ((-21.0, 3.4), (14.5, 3.4), (-21.0, 16.2), (14.5, 16.2)):
        parts.append(box("vent", (2.0, 0.22, 1.1), (x, front - 0.12, z), MATS["grate"]))
        parts.append(box("vent_lip", (2.2, 0.3, 0.12), (x, front - 0.14, z + 0.6), MATS["steel"]))
    # Escalera de mantenimiento: dos largueros y sus peldaños, de acero sin pintar.
    for side in (-1, 1):
        parts.append(box("ladder_rail", (0.1, 0.1, 17.2), (0.4 + side * 0.34, front - 0.22, 8.9), MATS["steel"]))
    for order in range(9):
        parts.append(box("ladder_rung", (0.78, 0.07, 0.07), (0.4, front - 0.22, 1.6 + order * 1.8), MATS["steel"]))
    # Bajantes de chapa oxidada con sus abrazaderas.
    for x in (-27.2, 13.2, 27.2):
        parts.append(tube("downpipe", (x, front - 0.22, 1.0), (x, front - 0.22, 18.4), 0.15, MATS["rust"], 6))
        for z in (5.5, 10.5, 15.5):
            parts.append(box("pipe_clip", (0.3, 0.24, 0.12), (x, front - 0.13, z), MATS["iron"]))
    # Refuerzos oxidados sobre los dos portones, con su fila de remaches.
    for gate_x in (-12.0, 6.0):
        parts.append(box("rust_beam", (9.6, 0.3, 0.5), (gate_x, front - 0.16, 8.1), MATS["rust"]))
        for order in range(7):
            parts.append(box("rivet", (0.16, 0.12, 0.16), (gate_x - 4.2 + order * 1.4, front - 0.34, 8.1), MATS["steel"]))
    # Marquesina oxidada sobre la puerta de personal, con sus apoyos de acero.
    parts.append(box("canopy", (3.2, 1.5, 0.12), (-2.0, front - 0.6, 3.5), MATS["rust"], (math.radians(-6), 0.0, 0.0)))
    for side in (-1, 1):
        parts.append(box("canopy_brace", (0.1, 1.2, 0.1), (-2.0 + side * 1.3, front - 0.55, 3.16), MATS["steel"]))
    return parts


def preview():
    """Dos láminas de revisión: la calle a escala de avatar y la manzana con su fondo detrás."""
    # La escena del guion solo sirve para exportar; para mirar, se vacía y se monta una calle.
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()

    # La calzada que en el juego levanta `CityBuilder`, y el color del material, no el del cielo.
    box("street_ground", (4000.0, 4000.0, 0.04), (0.0, 0.0, -0.02), MATS["asphalt"])

    # Dos módulos de acera seguidos: una manzana de 80 studs, la misma medida que el fondo.
    for x in (-20.0, 20.0):
        for part in build_walk(MATS):
            part.location.x += x

    # Fachada de referencia justo detrás de la faja, como una manzana de verdad.
    facade_parts = build_facade_ref()

    def put(builder, x, y):
        """Coloca un prop sobre la chapa de la acera, no en el suelo de la calzada."""
        for part in builder(MATS):
            part.location.x += x
            part.location.y += y
            part.location.z += WALK_TOP

    put(build_lamp, -17.0, -2.2)
    put(build_barrier, -5.5, 0.5)
    put(build_container, 6.0, 0.5)
    put(build_pallet, 10.5, -0.6)

    # Referencias de escala de `art/escala.md`, las dos al mismo lado: avatar de 6 studs y ficha de
    # 9 × 6. Van en la acera, a la derecha, para no tapar la línea de mobiliario.
    box("avatar_ref", (1.6, 1.2, 6.0), (15.5, 0.0, 3.0 + WALK_TOP), MATS["concrete"])
    prism("token_ref", 3.0, 3.0, 9.0, (21.0, 0.0, 4.5 + WALK_TOP), MATS["red"], 20)

    sun(energy=3.0, sky=0.55)
    bpy.context.scene.view_settings.view_transform = "Standard"
    bpy.context.scene.view_settings.look = "None"

    render_preview("industrial-calle.png", (-4.0, -44.0, 11.5), (4.0, 8.0, 10.0), 30)

    # Para la manzana sobran las referencias y la fachada de referencia: el fondo hace de manzana.
    for part in facade_parts:
        bpy.data.objects.remove(part, do_unlink=True)
    for name in ("avatar_ref", "token_ref"):
        bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)

    for part in build_backdrop_a(MATS):
        part.location.y += 13.6
    for part in build_backdrop_b(MATS):
        part.location.y += 34.0

    render_preview("industrial-manzana.png", (-24.0, -118.0, 38.0), (0.0, 11.0, 21.0), 34)


def main():
    from city_kit import reset_scene

    reset_scene()
    palette()
    stats = build_assets("industrial", BUILDERS, BACKDROPS, OUT, "industrial.blend")
    total = sum(entry["triangles"] for entry in stats.values())
    print(f"INDUSTRIAL_TOTAL {total}")
    preview()


if __name__ == "__main__":
    main()

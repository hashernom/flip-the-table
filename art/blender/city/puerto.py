"""Puerto: adoquín, hierro oxidado, naves bajas, grúas y agua (plan 07, Tarea 1).

El Puerto no compite en altura: mira al horizonte. Las siluetas se quedan entre 8 y 30 studs, la
única vertical es una grúa de 48 y el cielo abierto pesa más que los edificios (`art/guia-de-estilo.md`
§7). El acento frío lo ponen el agua y los portones; el resto sigue en ladrillo, caliza y acero, con
chapa ondulada y óxido en todo lo que es hierro.

Su calle es la del muelle: acera de adoquín menudo con bordillo de granito gastado y una argolla de
amarre, bolardo de fundición con su cadena, pila de cajas sobre palé, farola de muelle y banco de
tablón sobre caballetes oxidados. Detrás, dos fondos de 80 × 20 con naves a dos aguas, contenedores
apagados, agua y grúa.

Salidas, en `art/blender/city/`:
  puerto-walk_{...}.fbx          acera de adoquín y bordillo, 40 × 7
  puerto-bollard_{...}.fbx       bolardo de hierro fundido
  puerto-crates_{...}.fbx        pila de cajas y palé
  puerto-lamp_{...}.fbx          farola de muelle
  puerto-bench_{...}.fbx         banco de tablón
  puerto-backdrop-{a,b}_{...}.fbx  fondo de muelle y naves, 80 de ancho
  puerto.blend                   escena de revisión
  puerto-stats.json              triángulos reales

Y en `art/render/`: puerto-*.png. Son revisión técnica; la aprobación se hace en el juego.

Uso: blender --background --factory-startup --python art/blender/city/puerto.py
"""

import math
import os
import random
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
FAJA = 0.6  # faja de caliza junto a la fachada
JOINT = 0.1  # junta entre adoquines
# Cuatro hiladas de adoquín entre el bordillo y la faja: piedra menuda, no losa.
BAND = (WALK_WIDTH - CURB_WIDTH - FAJA - 3 * JOINT) / 4.0
FIELD_Y0 = -WALK_WIDTH / 2 + CURB_WIDTH
FIELD_Y1 = WALK_WIDTH / 2 - FAJA


def extra(name, color, roughness=0.8, metallic=0.0):
    """Material del barrio con el nombre exacto.

    `reset_scene` ya deja creada la paleta común, así que si el nombre está repetido se retira el
    anterior: si no, Blender lo renombraría a `iron.001` y el FBX viajaría con el sufijo.
    """
    previous = bpy.data.materials.get(name)
    if previous is not None:
        bpy.data.materials.remove(previous)
    material = flat(name, color, roughness, metallic)
    MATS[name] = material
    return material


def palette():
    # Adoquín de granito y su junta: el contraste es lo que hace que se lea la hilada.
    extra("flag", "9C978E", 0.9)
    extra("flag_dark", "56534E", 0.95)
    extra("curb", "7A7772", 0.85)
    extra("stone_dark", "B9B09C", 0.85)
    extra("stone", "D2C9B4", 0.8)
    extra("concrete", "A3A099", 0.9)
    extra("brick", "B0664A", 0.85)
    extra("brick_dark", "8A5039", 0.9)
    extra("slate", "4A4E54", 0.85)
    # Hierro: el del barrio no es negro de forja, es fundición y óxido.
    extra("iron", "262B2E", 0.55, 0.65)
    extra("rust", "8A4B33", 0.9)
    extra("steel", "A8AEB4", 0.3, 0.7)
    extra("lamp_glass", "EDE5D3", 0.35)
    extra("wood", "7E5A38", 0.85)
    extra("canvas", "B8A98C", 0.9)
    extra("paint", "D8D2C2", 0.85)
    extra("window", "2E3A44", 0.4, 0.1)
    extra("glass", "7FB2D9", 0.15)
    extra("asphalt", "4A4E54", 0.9)
    extra("water", "3E7FA6", 0.08)
    # Solo para las referencias de escala de la lámina.
    extra("red", "C4382B", 0.7)


# --- Piezas menudas ------------------------------------------------------------------------------


def gable(name, length, width, rise, base_z, center, material):
    """Cubierta a dos aguas: prisma triangular de 8 triángulos con el caballete sobre X.

    El cono de tres caras de Blender nace con el vértice hacia +Y y el eje en Z; con un giro de 90°
    en X y otro en Z queda el vértice arriba y el caballete a lo largo de X, que es lo que mira a la
    calle. El prisma no se puede escalar desde `city_kit`, así que la escala se aplica aquí.
    """
    bpy.ops.mesh.primitive_cone_add(vertices=3, radius1=1.0, radius2=1.0, depth=1.0)
    roof = bpy.context.active_object
    roof.name = name
    roof.rotation_euler = (math.radians(90), 0.0, math.radians(90))
    # El triángulo mide 1,732 de base y 1,5 de alto por unidad de radio.
    roof.scale = (width / 1.7320508, rise / 1.5, length)
    roof.location = (center[0], center[1], base_z + rise / 3.0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    roof.data.materials.append(material)
    return roof


def torus(name, major, minor, location, mat, rotation=None):
    """Argolla de amarre: el toro más barato que sigue leyéndose como un anillo."""
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major,
        minor_radius=minor,
        major_segments=8,
        minor_segments=4,
        location=location,
        rotation=rotation or (0.0, 0.0, 0.0),
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def place(parts, x, y, angle=0.0):
    """Coloca un grupo construido en el origen: gira cada pieza alrededor de (x, y) sin deformarla.

    Los ayudantes de `city_kit` aplican la rotación a la malla, así que el giro de grupo se suma a
    la orientación de cada pieza y su centro se lleva a su sitio.
    """
    cos, sin = math.cos(angle), math.sin(angle)
    for part in parts:
        px, py = part.location.x, part.location.y
        part.location.x = x + px * cos - py * sin
        part.location.y = y + px * sin + py * cos
        part.rotation_euler.z += angle
    return parts


# --- Acera ---------------------------------------------------------------------------------------


def build_walk(_mats):
    """Adoquín de granito sobre lecho oscuro, con bordillo gastado y faja de caliza.

    Es la pieza que más se repite, así que el adoquín se cuenta: cuatro hiladas de veintiséis
    piedras irregulares de 1,2 a 1,9 studs, con la hilada impar desfasada media piedra. La junta la
    dibuja el lecho que asoma entre ellas, y unas cuantas piezas van más hundidas o más oscuras
    porque un adoquín viejo nunca está a un solo nivel ni de un solo tono.
    """
    parts = [
        # Lecho: es la junta que se ve entre adoquín y adoquín.
        box("bed", (WALK_LENGTH, WALK_WIDTH, 0.05), (0, 0, 0.025), MATS["flag_dark"]),
    ]
    rng = random.Random(11)
    for row in range(4):
        y = FIELD_Y0 + BAND / 2.0 + row * (BAND + JOINT) + rng.uniform(-0.03, 0.03)
        count = rng.randint(25, 27)
        lengths = [rng.uniform(0.75, 1.3) for _ in range(count)]
        if row % 2:
            # Hilada alterna: media piedra en cada punta, como se coloca de verdad.
            lengths[0] *= 0.3
            lengths[-1] *= 0.3
        usable = WALK_LENGTH - JOINT * (count + 1)
        total = sum(lengths)
        x = -WALK_LENGTH / 2.0 + JOINT
        for index, raw in enumerate(lengths):
            length = raw * usable / total + rng.uniform(-0.04, 0.04)
            # Desgaste: casi todas a la misma cota, unas pocas hundidas y algo giradas.
            top = 0.112 + rng.uniform(-0.022, 0.004)
            yaw = rng.uniform(-0.035, 0.035)
            roll = rng.random()
            if roll < 0.18:
                material = MATS["flag_dark"]
            elif roll < 0.28:
                material = MATS["curb"]  # alguna pieza de otro granito
            else:
                material = MATS["flag"]
            parts.append(
                box(
                    f"sett_{row}_{index}",
                    (length, BAND, top - 0.05),
                    (x + length / 2.0 + rng.uniform(-0.02, 0.02), y + rng.uniform(-0.03, 0.03), 0.05 + (top - 0.05) / 2.0),
                    material,
                    (0, 0, yaw),
                )
            )
            x += length + JOINT

    # Bordillo: del suelo a 16 centésimas, en tongadas de granito con su junta.
    for index in range(5):
        x = -WALK_LENGTH / 2.0 + 4.0 + index * 8.0
        height = 0.56 + rng.uniform(-0.014, 0.014)
        parts.append(
            box(
                "curb",
                (7.92, CURB_WIDTH, height),
                (x, -WALK_WIDTH / 2.0 + CURB_WIDTH / 2.0, -0.4 + height / 2.0),
                MATS["curb"],
            )
        )

    # Faja junto a la fachada: losa de caliza, no adoquín. La acera nunca es una sola textura.
    for index in range(5):
        x = -WALK_LENGTH / 2.0 + 4.0 + index * 8.0
        parts.append(box("faja", (7.9, FAJA, 0.12), (x, WALK_WIDTH / 2.0 - FAJA / 2.0, 0.06), MATS["stone_dark"]))

    # Argolla de amarre: el detalle que dice que esta acera da al agua.
    parts.append(box("ring_plate", (0.9, 0.7, 0.09), (-9.4, -2.05, 0.1), MATS["iron"]))
    parts.append(box("ring_eye", (0.34, 0.16, 0.42), (-9.4, -2.25, 0.3), MATS["iron"]))
    parts.append(torus("ring", 0.26, 0.06, (-9.4, -2.32, 0.52), MATS["rust"], (math.radians(90), 0, 0)))
    return parts


# --- Bolardo -------------------------------------------------------------------------------------


def build_bollard(_mats):
    """Bolardo de hierro fundido en forma de seta, con su argolla para la cadena.

    Fuste de 0,48 de diámetro y 1,1 de alto: si adelgaza, deja de leerse como bolardo y pasa por
    seta de jardín.
    """
    parts = [
        prism("base", 0.36, 0.32, 0.16, (0, 0, 0.08), MATS["iron"], 8),
        prism("shaft", 0.24, 0.21, 0.7, (0, 0, 0.51), MATS["iron"], 8),
        prism("collar", 0.28, 0.26, 0.08, (0, 0, 0.9), MATS["iron"], 8),
        # El sombrero es lo que lo hace seta: más ancho que el fuste y aplastado.
        sphere("cap", 0.4, (0, 0, 0.94), MATS["iron"], 1, 0.46),
        prism("finial", 0.1, 0.07, 0.1, (0, 0, 1.1), MATS["iron"], 6),
    ]
    # Argolla de cadena en el cuello, oxidada como todo el hierro del barrio.
    parts.append(torus("eye", 0.13, 0.04, (0, -0.26, 0.72), MATS["rust"], (math.radians(90), 0, 0)))
    return parts


# --- Cajas ---------------------------------------------------------------------------------------


def crate(parts, x, y, z, size=1.1, angle=0.0):
    """Caja de madera: cuerpo, dos fajas que sobresalen y cuatro esquineros."""
    width = depth = size
    parts.append(box("crate", (width, depth, size), (x, y, z + size / 2.0), MATS["wood"], (0, 0, angle)))
    for level in (0.28, 0.72):
        parts.append(
            box(
                "crate_band",
                (width + 0.07, depth + 0.07, size * 0.1),
                (x, y, z + size * level),
                MATS["wood"],
                (0, 0, angle),
            )
        )
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(
                box(
                    "crate_post",
                    (0.1, 0.1, size),
                    (x + sx * (width / 2.0 - 0.03), y + sy * (depth / 2.0 - 0.03), z + size / 2.0),
                    MATS["wood"],
                    (0, 0, angle),
                )
            )


def build_crates(_mats):
    """Pila de cajas de madera sobre palé, con lona encima: 2,5 de alto y a la sombra de la nave."""
    parts = []
    # Palé: tres travesaños y cuatro tablas.
    for y in (-0.6, 0.0, 0.6):
        parts.append(box("pallet_runner", (2.6, 0.16, 0.14), (0, y, 0.07), MATS["wood"]))
    for index in range(4):
        parts.append(box("pallet_deck", (2.6, 0.24, 0.05), (0, -0.555 + index * 0.37, 0.165), MATS["wood"]))

    crate(parts, -0.62, 0.0, 0.19)
    crate(parts, 0.62, 0.02, 0.19, angle=math.radians(6))
    crate(parts, 0.02, 0.0, 1.29, angle=math.radians(-4))
    # Una suelta en el suelo, girada: la pila nunca está ordenada del todo.
    crate(parts, 1.98, 0.62, 0.0, angle=math.radians(19))
    # Lona sobre la caja de arriba.
    parts.append(box("tarp", (1.24, 1.16, 0.13), (0.02, 0.0, 2.45), MATS["canvas"], (0, 0, math.radians(3))))
    return parts


# --- Farola --------------------------------------------------------------------------------------


def build_lamp(_mats):
    """Farola de muelle: poste recto, brazo corto hacia la calle y pantalla cónica."""
    parts = [
        prism("base", 0.5, 0.42, 0.55, (0, 0, 0.275), MATS["iron"], 8),
        prism("collar", 0.34, 0.3, 0.18, (0, 0, 0.64), MATS["iron"], 8),
        prism("post", 0.17, 0.13, 9.02, (0, 0, 5.35), MATS["iron"], 8),
        prism("ring", 0.21, 0.21, 0.12, (0, 0, 3.4), MATS["rust"], 8),
        prism("ring", 0.21, 0.21, 0.12, (0, 0, 7.2), MATS["rust"], 8),
    ]
    # Brazo: tramos cortos que dibujan la curva hacia la calle (-Y).
    points = [(0.0, 9.8), (-0.5, 10.14), (-1.2, 10.36), (-1.85, 10.42)]
    for (y1, z1), (y2, z2) in zip(points, points[1:]):
        parts.append(tube("arm", (0, y1, z1), (0, y2, z2), 0.1, MATS["iron"], 6))
    parts.append(tube("brace", (0, -0.2, 9.1), (0, -1.5, 10.22), 0.075, MATS["iron"], 5))
    # Pantalla cónica con su canto, la bombilla y el remate.
    parts.append(prism("shade", 1.05, 0.16, 0.6, (0, -1.85, 10.72), MATS["iron"], 8))
    parts.append(prism("shade_rim", 1.09, 1.05, 0.08, (0, -1.85, 10.46), MATS["rust"], 8))
    parts.append(prism("bulb", 0.48, 0.3, 0.3, (0, -1.85, 10.3), MATS["lamp_glass"], 8))
    parts.append(prism("cap", 0.2, 0.12, 0.12, (0, -1.85, 11.04), MATS["iron"], 8))
    return parts


# --- Banco ---------------------------------------------------------------------------------------


def build_bench(_mats):
    """Banco de tablón sobre dos caballetes de hierro oxidado, mirando a la calle."""
    parts = []
    for y in (-0.34, 0.34):
        parts.append(box("seat", (5.4, 0.6, 0.16), (0, y, 1.34), MATS["wood"]))
    for side in (-1, 1):
        x = side * 2.05
        # Caballete: patas abiertas, travesaño alto y tensor.
        for dx in (-0.33, 0.33):
            angle = math.radians(10 if dx < 0 else -10)
            parts.append(box("leg", (0.16, 0.16, 1.26), (x + dx, 0, 0.63), MATS["rust"], (0, angle, 0)))
        parts.append(box("rail", (0.16, 1.15, 0.14), (x, 0, 1.24), MATS["rust"]))
        parts.append(box("stretcher", (0.12, 0.9, 0.1), (x, 0, 0.5), MATS["rust"]))
        for dx in (-0.42, 0.42):
            parts.append(box("foot", (0.42, 0.28, 0.08), (x + dx, 0, 0.04), MATS["rust"]))
    # Abrazaderas sobre el tablón: el banco se atornilla, no se apoya.
    for x in (-1.55, 1.55):
        parts.append(box("clamp", (0.16, 1.5, 0.06), (x, 0, 1.44), MATS["rust"]))
    return parts


# --- Fondo ---------------------------------------------------------------------------------------


def container(parts, x, y, z, material, length=8.0, depth=4.2, height=3.8):
    """Contenedor apagado: caja, dos fajas y la puerta oscura del costado corto."""
    parts.append(box("container", (length, depth, height), (x, y, z + height / 2.0), material))
    for level in (0.16, 0.84):
        parts.append(
            box("container_band", (length + 0.14, depth + 0.14, 0.28), (x, y, z + height * level), material)
        )
    parts.append(
        box("container_door", (0.18, depth - 0.7, height - 0.8), (x - length / 2.0, y, z + height / 2.0), MATS["iron"])
    )
    # Las esquinas van oxidadas: el contenedor lleva años en el muelle.
    for sy in (-1, 1):
        parts.append(
            box("container_rust", (length + 0.18, 0.16, 0.5), (x, y + sy * (depth / 2.0), z + 0.6), MATS["rust"])
        )


def warehouse(
    parts,
    x0,
    x1,
    y0,
    y1,
    eave,
    rise,
    body,
    roof,
    base_z=1.2,
    doors=(),
    lucernarios=2,
    high_windows=3,
    plinth=True,
    ribs=5,
    canopy=False,
):
    """Nave portuaria: cuerpo macizo, zócalo, cornisa, cubierta de chapa y portones.

    Las aberturas son las de un muelle: portón, ventana alta con marco y lucernario. El hierro va
    en óxido de verdad —canalón, bisagras, refuerzos y bajante—, no en una mancha.
    """
    width = x1 - x0
    depth = y1 - y0
    cx = (x0 + x1) / 2.0
    cy = (y0 + y1) / 2.0
    roof_width = depth + 1.4
    roof_z = base_z + eave + 0.3

    parts.append(box("nave", (width, depth, eave), (cx, cy, base_z + eave / 2.0), body))
    if plinth:
        parts.append(box("nave_plinth", (width + 0.5, depth + 0.5, 1.5), (cx, cy, base_z + 0.75), MATS["brick_dark"]))
    parts.append(box("nave_cornice", (width + 0.9, depth + 0.9, 0.55), (cx, cy, base_z + eave), MATS["stone_dark"]))
    parts.append(gable("nave_roof", width + 0.9, roof_width, rise, roof_z, (cx, cy), roof))

    # Chapa ondulada: los nervios del faldón que da a la calle.
    slope = math.atan2(rise, roof_width / 2.0)
    for index in range(ribs):
        t = (index + 0.5) / ribs
        parts.append(
            box(
                "nervio",
                (width + 0.9, 0.2, 0.11),
                (cx, cy - roof_width / 2.0 * (1.0 - t), roof_z + rise * t + 0.07),
                roof,
                (slope, 0, 0),
            )
        )
    # Canalón de chapa oxidado en el alero, con su bajante hasta el suelo.
    parts.append(
        box(
            "canalon",
            (width + 1.0, 0.4, 0.3),
            (cx, cy - roof_width / 2.0, roof_z - 0.06),
            MATS["rust"],
        )
    )
    for side in (-1, 1):
        parts.append(
            tube(
                "bajante",
                (cx + side * (width / 2.0 - 0.5), y0 - 0.2, roof_z - 0.1),
                (cx + side * (width / 2.0 - 0.5), y0 - 0.2, base_z + 0.2),
                0.13,
                MATS["rust"],
                5,
            )
        )
    # Lucernarios tumbados sobre el faldón.
    for index in range(lucernarios):
        x = x0 + width * (index + 0.5) / lucernarios
        parts.append(
            box(
                "lucernario",
                (width / lucernarios * 0.45, 1.3, 0.16),
                (x, cy - depth / 4.6, roof_z + rise * 0.5 + 0.14),
                MATS["glass"],
                (slope, 0, 0),
            )
        )
    # Ventanas altas: cristal rehundido con su marco de acero.
    for index in range(high_windows):
        x = x0 + width * (index + 0.5) / high_windows
        parts.append(box("marco", (1.9, 0.4, 1.7), (x, y0 - 0.1, base_z + eave - 2.3), MATS["steel"]))
        parts.append(box("ventana", (1.5, 0.6, 1.3), (x, y0 - 0.15, base_z + eave - 2.3), MATS["window"]))
    # Portones: hueco oscuro, dintel de acero, bisagras y refuerzos oxidadas.
    for x in doors:
        door_h = eave * 0.55
        parts.append(box("porton", (6.0, 0.6, door_h), (x, y0 - 0.1, base_z + door_h / 2.0 + 0.4), MATS["window"]))
        parts.append(box("dintel", (6.8, 0.9, 0.5), (x, y0 - 0.1, base_z + door_h + 0.5), MATS["steel"]))
        # Jambas: sin marco, el portón es un rectángulo pintado en la pared.
        for side in (-1, 1):
            parts.append(
                box(
                    "jamba",
                    (0.35, 0.75, door_h + 0.4),
                    (x + side * 3.05, y0 - 0.12, base_z + (door_h + 0.4) / 2.0 + 0.2),
                    MATS["steel"],
                )
            )
        for side in (-1, 1):
            for level in (0.3, 0.72):
                parts.append(
                    box(
                        "bisagra",
                        (0.55, 0.3, 0.32),
                        (x + side * 2.65, y0 - 0.24, base_z + door_h * level),
                        MATS["rust"],
                    )
                )
        # Refuerzo vertical de la hoja, también oxidado.
        parts.append(box("refuerzo", (0.3, 0.22, door_h), (x, y0 - 0.2, base_z + door_h / 2.0 + 0.4), MATS["rust"]))
    if canopy:
        # Toldilla colgada del muro: en un muelle el andén no admite pilares.
        parts.append(
            box(
                "toldilla",
                (width * 0.55, 2.8, 0.28),
                (cx, y0 - 1.3, base_z + eave * 0.62),
                MATS["steel"],
                (math.radians(10), 0, 0),
            )
        )
        for side in (-1, 1):
            parts.append(
                tube(
                    "tirante",
                    (cx + side * width * 0.26, y0 - 0.1, base_z + eave * 0.62 + 1.4),
                    (cx + side * width * 0.26, y0 - 2.5, base_z + eave * 0.62 - 0.1),
                    0.1,
                    MATS["rust"],
                    5,
                )
            )


def crane(parts, x, y, angle=0.0, deck=1.2, top=48.0):
    """Grúa de muelle: la única vertical del barrio y, por eso, la que fija la silueta.

    Se construye en el origen con la pluma hacia -Y y luego se gira el grupo entero con `place`,
    así la misma pieza sirve para las dos variantes de fondo.
    """
    local = []
    post_bottom = deck + 1.8
    mast_top = top - 4.0
    local.append(box("crane_plinth", (8.0, 6.0, 1.8), (0, 0, deck + 0.9), MATS["concrete"]))
    # Cuatro montantes y seis cintas: lee como celosía sin gastar malla en diagonales.
    for sx in (-1, 1):
        for sy in (-1, 1):
            local.append(
                box(
                    "crane_post",
                    (0.55, 0.55, mast_top - post_bottom),
                    (sx * 1.15, sy * 1.15, (post_bottom + mast_top) / 2.0),
                    MATS["steel"],
                )
            )
    for index in range(6):
        z = post_bottom + (mast_top - post_bottom) * (index + 0.5) / 6.0
        local.append(box("crane_band", (3.0, 3.0, 0.24), (0, 0, z), MATS["steel"]))
    local.append(box("crane_platform", (4.4, 4.4, 0.5), (0, 0, mast_top + 0.25), MATS["steel"]))
    local.append(box("crane_cab", (3.0, 2.6, 2.6), (0, -2.3, mast_top + 1.9), MATS["rust"]))
    local.append(box("crane_glass", (2.4, 0.12, 1.5), (0, -3.62, mast_top + 2.1), MATS["window"]))
    local.append(prism("crane_apex", 0.85, 0.3, 3.5, (0, 0, top - 1.75), MATS["steel"], 4))

    # Pluma y contrapeso. Las dos puntas se quedan dentro de la huella 80 × 20.
    tip_y, tip_z = -22.0, mast_top - 1.2
    local.append(tube("jib_spine", (0, 0, mast_top + 1.6), (0, tip_y, tip_z + 0.6), 0.7, MATS["steel"], 4))
    for sx in (-0.62, 0.62):
        local.append(tube("jib_rail", (sx, 0, mast_top + 2.3), (sx, tip_y, tip_z + 1.2), 0.16, MATS["steel"], 4))
    for index in range(4):
        t = (index + 0.7) / 4.6
        z_spine = (mast_top + 1.6) + (tip_z + 0.6 - mast_top - 1.6) * t
        z_rail = (mast_top + 2.3) + (tip_z + 1.2 - mast_top - 2.3) * t
        for sx in (-0.62, 0.62):
            local.append(tube("jib_tie", (sx, tip_y * t, z_rail), (sx, tip_y * t, z_spine), 0.09, MATS["steel"], 4))
    local.append(tube("counter_jib", (0, 0, mast_top + 1.6), (0, 10.0, mast_top + 1.0), 0.55, MATS["steel"], 4))
    local.append(box("counterweight", (3.4, 2.6, 3.2), (0, 9.2, mast_top - 1.4), MATS["rust"]))
    local.append(box("counter_link", (0.6, 2.4, 0.8), (0, 8.6, mast_top + 0.4), MATS["steel"]))
    local.append(tube("cable_a", (0, 0, top - 0.5), (0, tip_y, tip_z + 1.2), 0.11, MATS["iron"], 4))
    local.append(tube("cable_b", (0, 0, top - 0.5), (0, 10.0, mast_top + 1.4), 0.11, MATS["iron"], 4))

    # Carro y gancho: la prueba de que la grúa trabaja.
    local.append(box("trolley", (1.6, 1.8, 0.9), (0, -13.0, mast_top - 0.7), MATS["rust"]))
    local.append(tube("hoist", (0, -13.0, mast_top - 1.2), (0, -13.0, mast_top - 9.0), 0.09, MATS["iron"], 4))
    local.append(box("hook_block", (1.0, 1.0, 1.2), (0, -13.0, mast_top - 9.6), MATS["rust"]))
    local.append(prism("hook", 0.36, 0.1, 0.8, (0, -13.0, mast_top - 10.6), MATS["iron"], 4))
    place(local, x, y, angle)
    parts.extend(local)


def harbour(parts, half_width):
    """Dársena: el agua es el suelo del fondo y el muelle, una plataforma de hormigón sobre ella.

    La lámina ocupa los 80 × 20 de la huella a ras de suelo, así que al repetir el fondo el agua
    sigue de una pieza hasta el horizonte. La plataforma se retranquea del borde para que el agua
    rodee la manzana por los costados, y el morro lleva su canto de hormigón y sus defensas de
    madera: el muelle se come los golpes en la madera, no en el hormigón.
    """
    parts.append(box("water", (80.0, 20.0, 0.4), (0.0, 0.0, -0.2), MATS["water"]))
    parts.append(box("quay", (half_width * 2.0, 6.0, 1.0), (0.0, -5.5, 0.4), MATS["concrete"]))
    parts.append(box("quay_edge", (half_width * 2.0 + 0.6, 0.8, 0.4), (0.0, -8.5, 0.95), MATS["concrete"]))
    for side in (-1, 1):
        parts.append(box("quay_edge", (0.8, 6.0, 0.4), (side * half_width, -5.5, 0.95), MATS["concrete"]))
    # Defensas: el morro y los dos costados de la plataforma.
    for index in range(9):
        x = -half_width + 2.5 + index * (half_width * 2.0 - 5.0) / 8.0
        parts.append(box("defensa", (0.55, 0.8, 2.0), (x, -8.7, 0.1), MATS["wood"]))
    for side in (-1, 1):
        for index in range(3):
            y = -7.6 + index * 2.1
            parts.append(box("defensa", (0.8, 0.55, 2.0), (side * (half_width + 0.15), y, 0.1), MATS["wood"]))
    parts.append(box("defensa_larga", (half_width * 2.0 - 1.0, 0.5, 0.5), (0.0, -9.05, 0.35), MATS["wood"]))


def build_backdrop_a(_mats):
    """Muelle: dos naves de chapa a dos aguas, patio de contenedores y grúa sobre la dársena."""
    parts = []
    harbour(parts, 26.0)

    warehouse(
        parts, -24.0, -11.0, -8.0, -2.8, 17.0, 5.6, MATS["brick"], MATS["rust"],
        base_z=0.9, doors=(-20.5, -14.5), lucernarios=2, high_windows=4,
    )
    warehouse(
        parts, 11.0, 24.0, -8.0, -2.8, 11.0, 4.0, MATS["brick_dark"], MATS["steel"],
        base_z=0.9, doors=(17.5,), lucernarios=2, high_windows=3,
    )

    # Patio de contenedores entre las dos naves, con la grúa en su embarcadero.
    for z, material in ((0.9, MATS["steel"]), (4.7, MATS["paint"])):
        container(parts, -6.5, -6.9, z, material)
        container(parts, 6.5, -6.9, z, MATS["brick_dark"] if z < 1.0 else MATS["slate"])
    parts.append(box("crane_pier", (10.0, 6.0, 1.0), (0.0, -1.5, 0.4), MATS["concrete"]))
    crane(parts, 0.0, -1.5, math.radians(-96), 0.9, 48.0)
    return parts


def build_backdrop_b(_mats):
    """Variante: nave de dientes de sierra, almacén de tránsito y la grúa en el espigón."""
    parts = []
    harbour(parts, 26.0)

    # Nave larga y baja de dientes de sierra: la silueta que no se parece a la del fondo A.
    parts.append(box("sierra_body", (16.0, 5.2, 9.0), (-19.0, -5.4, 0.9 + 4.5), MATS["brick"]))
    parts.append(box("sierra_plinth", (16.5, 5.7, 1.2), (-19.0, -5.4, 1.5), MATS["brick_dark"]))
    parts.append(box("sierra_cornice", (16.9, 5.6, 0.45), (-19.0, -5.4, 9.4), MATS["stone_dark"]))
    teeth, step = 5, 16.0 / 5.0
    for index in range(teeth):
        x = -27.0 + step * (index + 0.5)
        # El diente sube de -X a +X y la cara vertical, acristalada, queda en el lado bajo.
        parts.append(box("diente", (step * 1.4, 5.2, 0.3), (x, -5.4, 10.7), MATS["rust"], (0, math.radians(-34), 0)))
        parts.append(box("diente_luz", (0.16, 4.4, 2.0), (x - step * 0.62, -5.4, 10.1), MATS["window"]))
    for x in (-25.0, -19.0, -13.0):
        parts.append(box("porton", (4.2, 0.5, 4.6), (x, -8.0, 0.9 + 2.3 + 0.3), MATS["window"]))
        parts.append(box("dintel", (4.8, 0.7, 0.4), (x, -8.0, 6.1), MATS["rust"]))
    parts.append(box("canalon", (16.9, 0.4, 0.3), (-19.0, -8.1, 9.6), MATS["rust"]))
    for x in (-26.4, -11.6):
        parts.append(tube("bajante", (x, -8.2, 9.5), (x, -8.2, 1.1), 0.13, MATS["rust"], 5))

    warehouse(
        parts, 0.0, 16.0, -8.0, -2.8, 20.0, 5.6, MATS["brick_dark"], MATS["rust"],
        base_z=0.9, doors=(8.0,), lucernarios=2, high_windows=4, canopy=True,
    )

    for z, material in ((0.9, MATS["steel"]), (4.7, MATS["brick_dark"]), (8.5, MATS["paint"])):
        container(parts, 22.0, -6.2, z, material)

    # Espigón al agua y grúa encima, con la pluma barriendo el patio.
    parts.append(box("pier", (9.0, 6.0, 1.0), (-31.0, -1.5, 0.4), MATS["concrete"]))
    crane(parts, -31.0, -1.1, math.radians(90), 0.9, 48.0)
    return parts


BUILDERS = (
    ("puerto-walk", build_walk),
    ("puerto-bollard", build_bollard),
    ("puerto-crates", build_crates),
    ("puerto-lamp", build_lamp),
    ("puerto-bench", build_bench),
)

BACKDROPS = (
    ("puerto-backdrop-a", build_backdrop_a),
    ("puerto-backdrop-b", build_backdrop_b),
)


def preview():
    """Dos vistas de revisión: la calle a escala de avatar y la manzana con su fondo detrás."""
    # La escena del guion solo sirve para exportar; para mirar, se vacía y se monta una calle.
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()

    # Calzada: la acera no flota y el bordillo se lee contra el asfalto. Llega hasta el bordillo y
    # sigue bajo la cámara, para que el suelo no acabe en un canto recto en mitad de la lámina.
    box("road", (400.0, 400.0, 0.4), (0.0, -203.5, -0.2), MATS["asphalt"])
    # Solar: el suelo detrás de la acera, para que la fachada no se recorte contra el vacío.
    box("lot", (400.0, 18.0, 0.24), (0.0, 12.5, -0.12), MATS["asphalt"])

    # Acera: dos módulos seguidos son una manzana de 80 studs.
    for x in (-20.0, 20.0):
        for part in build_walk(MATS):
            part.location.x += x

    # Fachada de referencia: nave de muelle con portones, cornisa y canalón, no una pared lisa.
    nave = []
    warehouse(
        nave,
        -16.0,
        16.0,
        3.5,
        21.5,
        13.0,
        5.0,
        MATS["brick"],
        MATS["rust"],
        base_z=0.0,
        doors=(-8.0, 8.0),
        lucernarios=2,
        high_windows=4,
        canopy=True,
    )

    # Y detrás, el fondo del muelle.
    for part in build_backdrop_a(MATS):
        part.location.y += 31.5

    def put(builder, x, y, angle=0.0):
        for part in builder(MATS):
            part.location.x += x
            part.location.y += y
            part.rotation_euler.z += angle

    def chain(x1, x2, y, z=0.75, sag=0.2, links=6):
        """Cadena entre dos bolardos: tramos cortos que dibujan la comba desde su argolla."""
        for index in range(links):
            t0, t1 = index / links, (index + 1) / links
            a = (x1 + (x2 - x1) * t0, y, z - sag * math.sin(math.pi * t0))
            b = (x1 + (x2 - x1) * t1, y, z - sag * math.sin(math.pi * t1))
            tube("chain", a, b, 0.045, MATS["rust"], 4)

    put(build_lamp, -26.0, -1.8)
    for x in (-17.0, -12.0, -7.0):
        put(build_bollard, x, -2.35)
    chain(-17.0, -12.0, -2.61)
    chain(-12.0, -7.0, -2.61)
    for x in (24.0, 29.0):
        put(build_bollard, x, -2.35)
    chain(24.0, 29.0, -2.61)
    put(build_crates, -2.0, 1.35, math.radians(-8))
    put(build_bench, 7.0, 2.0)

    # Escala de `art/escala.md`, apartada del centro: avatar de 6 y ficha de 9.
    box("avatar_ref", (1.6, 1.2, 6.0), (15.0, -1.4, 3.0), MATS["stone"])
    prism("token_ref", 3.0, 3.0, 9.0, (20.5, -1.2, 4.5), MATS["red"], 16)

    sun()
    # El mismo encuadre que la lámina de Centro: 44 de retroceso, 11 de altura y 30 mm.
    render_preview("puerto-calle.png", (-6.0, -44.0, 11.0), (2.0, 8.0, 9.0), 30)

    # Las referencias de escala son de la lámina de calle: en la de manzana estorban.
    for name in ("avatar_ref", "token_ref"):
        obj = bpy.data.objects.get(name)
        if obj is not None:
            bpy.data.objects.remove(obj, do_unlink=True)
    render_preview("puerto-manzana.png", (0.0, -120.0, 40.0), (0.0, 16.0, 18.0), 45)


def main():
    from city_kit import reset_scene

    reset_scene()
    palette()
    stats = build_assets("puerto", BUILDERS, BACKDROPS, OUT, "puerto.blend")
    total = sum(entry["triangles"] for entry in stats.values())
    print(f"PUERTO_TOTAL {total}")
    preview()


if __name__ == "__main__":
    main()

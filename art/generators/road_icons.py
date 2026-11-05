"""Genera los iconos de las casillas especiales, pintados con el mismo desgaste que la pintura de calzada.

Los iconos no son ilustraciones: son pictogramas de señalética, una sola tinta, sin texto. Se dibujan con
geometría propia (polígonos, arcos y trazos) y se les aplica el desgaste de `road_paint.py` —borde
irregular, pintura perdida a parches, grietas y opacidad variable— para que parezcan pintados con la misma
brocha que el marco de la casilla.

El juego tiñe el blanco con el color de la zona, igual que hace con `pintura_N.png`.

Salidas: art/textures/casillas/iconos/<id>.png (512 × 512, RGBA, blanco sobre transparente) y
preview.png, la lámina de revisión, solo para mirar.
Uso: python art/generators/road_icons.py
"""

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, "..", "textures", "casillas", "iconos"))

SIZE = 512  # lienzo cuadrado del icono
SS = 4  # supermuestreo: se dibuja a 2048 y se reduce, para que el trazo salga limpio
CANVAS = SIZE * SS
MARGIN = 40  # margen transparente mínimo de cada icono

# Desgaste, con la misma idea que road_paint.py.
EDGE_SIGMA = 2.6  # difuminado que convierte la silueta en un campo de nivel
WOBBLE = 0.34  # cuánto se mueve el borde: borde irregular, no un contorno limpio
SOFT = 0.25  # ancho del escalón del umbral, en unidades del campo
WORN = 0.09  # parte de la pintura que se pierde a parches
RIM = 0.22  # cuánto de esa pérdida se arrima al borde, como la pintura que se descascarilla
CRACKS = 11  # grietas que se llevan la pintura
STRENGTH = (0.72, 0.28)  # opacidad de la pintura: base y variación

# Colores de zona (§2.3 de la guía), solo para la lámina de revisión.
ZONE_COLOURS = [
    (201, 123, 58),
    (34, 211, 238),
    (232, 93, 158),
    (245, 158, 11),
    (220, 38, 38),
    (250, 204, 21),
    (16, 185, 129),
    (139, 92, 246),
]


# --------------------------------------------------------------------------- dibujo


class Art:
    """Lienzo de tinta plana al 255 sobre transparente, con la geometría a escala del icono."""

    def __init__(self):
        self.img = Image.new("L", (CANVAS, CANVAS), 0)
        self.draw = ImageDraw.Draw(self.img)

    # -- primitivas de bloque
    def rect(self, x0, y0, x1, y1, erase=False):
        self.draw.rectangle(
            [x0 * SS, y0 * SS, x1 * SS - 1, y1 * SS - 1], fill=0 if erase else 255
        )

    def poly(self, points, erase=False):
        self.draw.polygon([(x * SS, y * SS) for x, y in points], fill=0 if erase else 255)

    def disc(self, cx, cy, r):
        self.draw.ellipse(
            [(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=255
        )

    def half_disc(self, cx, cy, r):
        """Semicírculo que cuelga hacia abajo: el festón de una lona."""
        self.draw.pieslice(
            [(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], 0, 180, fill=255
        )

    # -- trazos
    def stroke(self, points, width, closed=False, erase=False):
        """Trazo grueso: se une con esquinas redondeadas y lleva remate en las puntas."""
        path = [(x * SS, y * SS) for x, y in points]
        if closed:
            path = path + [path[0]]
        self.draw.line(
            path, fill=0 if erase else 255, width=int(round(width * SS)), joint="curve"
        )
        if not closed and not erase:
            r = width * SS / 2
            for x, y in (path[0], path[-1]):
                self.draw.ellipse([x - r, y - r, x + r, y + r], fill=255)

    def ring_outline(self, x0, y0, x1, y1, width):
        """Contorno de un rectángulo con grosor parejo por los cuatro lados."""
        self.rect(x0, y0, x1, y0 + width)
        self.rect(x0, y1 - width, x1, y1)
        self.rect(x0, y0 + width, x0 + width, y1 - width)
        self.rect(x1 - width, y0 + width, x1, y1 - width)

    def arch(self, cx, cy, r_out, r_in, a0=math.pi, a1=2.0 * math.pi, steps=96):
        """Arco de medio punto: media corona entre dos radios."""
        outer = [
            (cx + r_out * math.cos(a), cy + r_out * math.sin(a))
            for a in np.linspace(a0, a1, steps)
        ]
        inner = [
            (cx + r_in * math.cos(a), cy + r_in * math.sin(a))
            for a in np.linspace(a1, a0, steps)
        ]
        self.poly(outer + inner)

    def tape(self, cx, cy, wide, high, angle, erase=False):
        """Rectángulo girado: una tira de cinta adhesiva."""
        c, s = math.cos(angle), math.sin(angle)
        points = []
        for dx, dy in ((-wide / 2, -high / 2), (wide / 2, -high / 2),
                       (wide / 2, high / 2), (-wide / 2, high / 2)):
            points.append((cx + dx * c - dy * s, cy + dx * s + dy * c))
        self.poly(points, erase=erase)

    def image(self):
        return self.img


def centred(mask):
    """Centra la silueta en el lienzo para que los ocho iconos queden a la misma altura."""
    ys, xs = np.nonzero(mask > 0.5)
    if len(xs) == 0:
        return mask
    dx = int(round(SIZE / 2 - (xs.min() + xs.max() + 1) / 2))
    dy = int(round(SIZE / 2 - (ys.min() + ys.max() + 1) / 2))
    moved = np.zeros_like(mask)
    src_x = slice(max(0, -dx), SIZE - max(0, dx))
    src_y = slice(max(0, -dy), SIZE - max(0, dy))
    dst_x = slice(max(0, dx), SIZE - max(0, -dx))
    dst_y = slice(max(0, dy), SIZE - max(0, -dy))
    moved[dst_y, dst_x] = mask[src_y, src_x]
    return moved


# --------------------------------------------------------------------------- iconos


def icon_salida():
    """Cochera en 3/4, dibujada a línea: nave con frontón y el portalón en fuga en el costado."""
    a = Art()
    # La testa va de frente y el costado se va al fondo a la derecha: el portalón queda en fuga.
    run = (0.88, -0.26)  # eje de fuga, por unidad de fondo
    deep = 235.0
    x0, x1 = 96.0, 228.0  # testa de la nave
    floor, eave = 452.0, 272.0
    apex_x, apex_y = 162.0, 206.0
    dx, dy = run[0] * deep, run[1] * deep
    far_x, far_eave = x1 + dx, eave + dy

    def wall(t, up=0.0):
        """Punto del costado: t va de 0 en la testa a 1 en el fondo, up sube desde el suelo."""
        return (x1 + dx * t, floor + dy * t - up)

    # Nave a línea: testa con frontón, costado en fuga y cubierta a dos aguas.
    a.stroke([(x0, floor), (x0, eave), (apex_x, apex_y), (x1, eave), (x1, floor)], 22)
    a.stroke([(x0, floor), (x1, floor), (x1 + dx, floor + dy)], 22)
    a.stroke([(x1, eave), (far_x, far_eave), (far_x, far_eave + floor - eave)], 22)
    a.stroke([(x0, eave), (x0 + dx, far_eave)], 20)  # alero
    a.stroke([(apex_x, apex_y), (apex_x + dx, apex_y + dy)], 20)  # cumbrera
    a.stroke([(x0 + dx, far_eave), (apex_x + dx, apex_y + dy), (far_x, far_eave)], 20)  # hastial
    # Portalón: el vano calado en el costado y la hoja recogida a media altura.
    a.stroke([wall(0.17, 0), wall(0.17, 160), wall(0.86, 160), wall(0.86, 0)], 16)
    a.poly([wall(0.20, 102), wall(0.83, 102), wall(0.83, 160), wall(0.20, 160)])
    for up in (118, 134):
        a.stroke([wall(0.22, up), wall(0.81, up)], 8, erase=True)
    # Pórtico de señalización sobre el faldón: dos postes y la viga que los rebasa, en la misma fuga.
    a.rect(188, 128, 204, 219)
    a.rect(271, 103, 287, 194)
    a.poly([(171.0, 137.0), (311.0, 96.0), (305.0, 74.0), (165.0, 115.0)])
    return a


def icon_giro():
    """Aviso pegado: hoja con la esquina de arriba doblada y tres tiras de cinta."""
    a = Art()
    body = [(292, 88), (120, 88), (120, 420), (392, 420), (392, 188)]
    a.stroke(body, 26, closed=False)  # el pliegue no lleva borde: ahí se ve el revés
    a.poly([(292, 88), (392, 188), (292, 188)])
    a.tape(158, 98, 44, 88, 0.10)  # cinta sobre el borde de arriba
    a.tape(242, 98, 44, 88, -0.08)
    a.tape(170, 410, 44, 82, 0.08)  # cinta sobre el borde de abajo
    a.img = a.img.rotate(-6.0, resample=Image.BICUBIC, center=(CANVAS / 2, CANVAS / 2))
    return a


def icon_mercado_negro():
    """Puesto de callejón: lona con festón, mostrador y una pila de cajas."""
    a = Art()
    # Lona: banda con cinco festones colgando.
    a.rect(68, 104, 444, 156)
    for i in range(5):
        a.half_disc(68 + 37.6 * (2 * i + 1), 156, 37.6)
    # Postes del puesto.
    a.rect(84, 156, 112, 452)
    a.rect(400, 156, 428, 452)
    # Mostrador.
    a.rect(76, 358, 436, 390)
    # Pila de cajas: dos abajo y una encima, con la junta de las tablas.
    for x0, y0 in ((122, 286), (214, 286), (168, 210)):
        a.rect(x0, y0, x0 + 80, y0 + 72)
        a.rect(x0 + 10, y0 + 38, x0 + 70, y0 + 51, erase=True)
    return a


def icon_duelo():
    """Dos podios enfrentados bajo un arco, con el hueco libre en medio."""
    a = Art()
    a.arch(256, 314, 194, 152)
    a.rect(62, 314, 104, 448)  # pierna izquierda
    a.rect(408, 314, 450, 448)  # pierna derecha
    for side in (-1, 1):
        cx = 256 + side * 85
        outer, inner = cx + side * 52, cx - side * 52
        # Plato inclinado hacia el centro, cuello y base.
        a.poly([(outer, 296), (inner, 318), (inner, 360), (outer, 338)])
        a.rect(cx - 36, 360, cx + 36, 416)
        a.rect(cx - 52, 416, cx + 52, 450)
    return a


def icon_portal():
    """Boca de metro: arco de piedra con clave y escalera de perfil que baja."""
    a = Art()
    a.arch(256, 250, 176, 138)
    a.rect(80, 250, 118, 448)
    a.rect(394, 250, 432, 448)
    a.poly([(228, 54), (284, 54), (296, 132), (216, 132)])  # clave
    # Escalera: meseta arriba a la izquierda y cuatro peldaños que bajan a la derecha.
    stair = [(150, 190), (206, 190)]
    for i in range(4):
        stair += [(206 + 42 * i, 190 + 52 * (i + 1)), (248 + 42 * i, 190 + 52 * (i + 1))]
    stair += [(374, 448), (150, 448)]
    a.poly(stair)
    return a


def icon_cartelera():
    """Pantalla grande sobre una estructura de acero: dos celosías con sus pies."""
    a = Art()
    a.ring_outline(88, 76, 424, 298, 34)
    for side in (-1, 1):
        cx = 256 + side * 84
        x0, x1 = cx - 46, cx + 46
        a.rect(x0, 298, x0 + 22, 448)
        a.rect(x1 - 22, 298, x1, 448)
        a.stroke([(x0 + 11, 306), (x1 - 11, 348), (x0 + 11, 390), (x1 - 11, 432)], 15)
        a.rect(x0 - 10, 436, x1 + 10, 452)
    return a


def icon_tribunal():
    """Frontón con columnas y escalinata."""
    a = Art()
    a.stroke([(86, 190), (256, 80), (426, 190)], 27, closed=True)
    a.rect(78, 190, 434, 226)
    left, right, count, wide = 104, 408, 4, 40
    gap = (right - left - count * wide) / (count + 1)
    for i in range(count):
        x = left + gap + i * (wide + gap)
        a.rect(x, 226, x + wide, 396)
        a.rect(x - 6, 226, x + wide + 6, 240)
        a.rect(x - 6, 382, x + wide + 6, 396)
    a.rect(100, 396, 412, 414)
    a.rect(84, 414, 428, 432)
    a.rect(68, 432, 444, 450)
    return a


def icon_impuesto():
    """Caseta de aduana con barrera a rayas."""
    a = Art()
    # Caseta: tejado que vuela, cuerpo y ventanilla partida por un parteluz.
    a.rect(84, 200, 272, 234)
    a.rect(96, 234, 260, 448)
    a.rect(118, 264, 238, 344, erase=True)
    a.rect(172, 264, 186, 344)
    a.rect(88, 430, 268, 450)
    # Poste de la barrera, con su mecanismo arriba y su pie.
    a.rect(384, 240, 426, 448)
    a.rect(370, 204, 442, 250)
    a.rect(376, 428, 434, 450)
    # Barrera: barra con rayas diagonales recortadas.
    a.rect(250, 302, 396, 358)
    x = 268
    while x < 384:
        a.poly([(x, 302), (x + 16, 302), (x + 72, 358), (x + 56, 358)], erase=True)
        x += 30
    return a


ICONS = [
    ("salida", icon_salida, 1101),
    ("giro", icon_giro, 1102),
    ("mercado-negro", icon_mercado_negro, 1103),
    ("duelo", icon_duelo, 1104),
    ("portal", icon_portal, 1105),
    ("cartelera", icon_cartelera, 1106),
    ("tribunal", icon_tribunal, 1107),
    ("impuesto", icon_impuesto, 1108),
]


# --------------------------------------------------------------------------- desgaste


def noise(rng, scale):
    """Ruido suave: píxeles al azar ampliados y difuminados, entre 0 y 1."""
    small = rng.random((max(2, int(SIZE / scale)), max(2, int(SIZE / scale))))
    image = Image.fromarray((small * 255).astype("uint8")).resize((SIZE, SIZE), Image.BICUBIC)
    image = image.filter(ImageFilter.GaussianBlur(scale / 4))
    data = np.asarray(image, dtype=float)
    return (data - data.min()) / max(1.0, data.max() - data.min())


def fractal(rng, scales):
    total = sum(1.0 / (order + 1) * noise(rng, scale) for order, scale in enumerate(scales))
    return (total - total.min()) / max(1e-6, total.max() - total.min())


def cracks(rng, mask, count):
    """Grietas: líneas quebradas que nacen dentro del icono y se llevan la pintura."""
    image = Image.new("L", (SIZE, SIZE), 0)
    draw = ImageDraw.Draw(image)
    ys, xs = np.nonzero(mask > 0.5)
    if len(xs) == 0:
        return np.zeros((SIZE, SIZE))
    for _ in range(count):
        pick = int(rng.integers(len(xs)))
        x, y = float(xs[pick]), float(ys[pick])
        angle = rng.uniform(0, 2 * math.pi)
        points = [(x, y)]
        for _ in range(int(rng.integers(4, 10))):
            angle += rng.uniform(-0.7, 0.7)
            x += math.cos(angle) * rng.uniform(9, 26)
            y += math.sin(angle) * rng.uniform(9, 26)
            points.append((x, y))
        draw.line(points, fill=255, width=int(rng.integers(1, 3)))
    return np.asarray(image.filter(ImageFilter.GaussianBlur(0.7)), dtype=float) / 255


def painted(art, seed):
    """Convierte la silueta en pintura gastada y devuelve el alfa."""
    rng = np.random.default_rng(seed)
    mask = np.asarray(art.image().resize((SIZE, SIZE), Image.LANCZOS), dtype=float) / 255
    mask = centred(mask)
    shape = Image.fromarray((mask * 255).astype("uint8")).filter(
        ImageFilter.GaussianBlur(EDGE_SIGMA)
    )
    level = np.asarray(shape, dtype=float) / 255

    # 1. Borde irregular: el nivel de la silueta se empuja con ruido, como pintado a rodillo.
    wobble = (fractal(rng, [9, 23]) - 0.5) * 2.0 * WOBBLE
    core = np.clip((level + wobble - 0.5) / SOFT + 0.5, 0, 1)

    # 2. Pintura perdida a parches: se quita la parte más baja del campo, no un tanto por ciento al azar.
    #    El borde pesa más, porque la pintura se descascarilla primero en el filo y el centro aguanta.
    patches = fractal(rng, [26, 11])
    grain = fractal(rng, [7, 3.5])
    rim = 1.0 - np.asarray(
        Image.fromarray((core * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(7)),
        dtype=float,
    ) / 255.0
    field = patches * 0.58 + grain * 0.24 + rim * RIM
    inside = core > 0.5
    cut = float(np.quantile(field[inside], WORN)) if inside.any() else 1.0
    keep = (field > cut).astype(float)

    # 3. Grietas y opacidad variable: la pintura que queda no es plana, pero el trazo fresco llega a
    #    cubrir del todo, para que el icono se lea igual de sólido que el marco de la casilla.
    crack = cracks(rng, core, CRACKS)
    strength = np.clip(STRENGTH[0] + STRENGTH[1] * fractal(rng, [64, 12]) * 1.15, 0.0, 1.0)
    alpha = core * keep * (crack < 0.34) * strength

    alpha = Image.fromarray((np.clip(alpha, 0, 1) * 255).astype("uint8")).filter(
        ImageFilter.GaussianBlur(0.6)
    )
    return np.asarray(alpha, dtype=float) / 255


def to_rgba(alpha):
    """Blanco puro sobre transparente: el juego lo tiñe con el color de la zona."""
    rgb = np.full((SIZE, SIZE, 3), 255, dtype=np.uint8)
    return Image.fromarray(
        np.dstack([rgb, (np.clip(alpha, 0, 1) * 255).astype(np.uint8)]), "RGBA"
    )


# --------------------------------------------------------------------------- lámina y revisión


def review(icons):
    """Lámina de revisión: los ocho en fila sobre asfalto, cada uno con el color de una zona."""
    cell, pad, gap = 320, 26, 12
    width = pad * 2 + cell * len(icons) + gap * (len(icons) - 1)
    sheet = Image.new("RGB", (width, pad * 2 + cell), (74, 78, 84))
    for order, (_, icon) in enumerate(icons):
        tile = icon.resize((cell, cell), Image.LANCZOS)
        tint = Image.new("RGB", (cell, cell), ZONE_COLOURS[order % len(ZONE_COLOURS)])
        sheet.paste(tint, (pad + order * (cell + gap), pad), tile.getchannel("A"))
    return sheet


def inspect(path, name):
    """Comprueba el PNG escrito y devuelve la ficha para el informe."""
    with Image.open(path) as image:
        image.load()
        if image.mode != "RGBA":
            raise SystemExit(f"{name}: se esperaba RGBA y es {image.mode}")
        size = image.size
        data = np.asarray(image)
    alpha = data[..., 3]
    if alpha.max() == 0:
        raise SystemExit(f"{name}: el alfa está vacío")
    if (data[..., :3] != 255).any():
        raise SystemExit(f"{name}: la tinta no es blanca pura")
    ys, xs = np.nonzero(alpha)
    margin = int(min(xs.min(), ys.min(), SIZE - 1 - xs.max(), SIZE - 1 - ys.max()))
    if margin < MARGIN:
        raise SystemExit(f"{name}: el icono toca el borde, margen {margin} < {MARGIN}")
    coverage = 100.0 * float((alpha > 8).mean())
    return {
        "name": name,
        "size": size,
        "margin": margin,
        "coverage": coverage,
        "box": (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())),
        "ink": 100.0 * float(alpha.sum()) / (255.0 * SIZE * SIZE),
    }


def main():
    os.makedirs(OUT, exist_ok=True)
    icons = []
    for name, builder, seed in ICONS:
        icon = to_rgba(painted(builder(), seed))
        path = os.path.join(OUT, f"{name}.png")
        icon.save(path)
        icons.append((name, icon))

    sheet = review(icons)
    sheet.save(os.path.join(OUT, "preview.png"))

    print(f"{'icono':<14}{'tamaño':>10}{'margen':>8}{'alfa':>8}{'tinta':>8}   caja")
    for name, _ in icons:
        row = inspect(os.path.join(OUT, f"{name}.png"), name)
        print(
            f"{row['name']:<14}{row['size'][0]}x{row['size'][1]:<5}{row['margin']:>8}"
            f"{row['coverage']:>7.1f}%{row['ink']:>7.1f}%   {row['box']}"
        )
    print(f"lámina: {os.path.join(OUT, 'preview.png')} {sheet.size[0]}x{sheet.size[1]}")


if __name__ == "__main__":
    main()

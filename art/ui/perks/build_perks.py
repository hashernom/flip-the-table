#!/usr/bin/env python
"""Los 12 iconos de perk de Flip the Table, dibujados con geometría (art/ui/cards/ilustraciones.md §4).

Uso: python art/ui/perks/build_perks.py

Escribe, junto a este archivo, un PNG de 256 x 256 por perk, en blanco puro y con alfa, más
`art/render/ui/perks-hoja.png` (hoja de contacto) y `manifest-perks.json` (las 12 entradas del
manifiesto de assets).

Como en `art/ui/icons/build_icons.py`: se dibuja a 4x y se reduce una sola vez con LANCZOS. La
diferencia es que aquí todo se dibuja sobre una máscara de alfa (modo L) y el color se pone al
final: así el 100 % de los píxeles visibles es exactamente blanco y lo único que varía es el alfa,
que es lo que necesita `ImageColor3` para teñirlos.

Un solo grosor de trazo por icono (16 px a tamaño final = 64 px a 4x): cada perk es o silueta
llena, o contorno de ese grosor, pero no las dos cosas.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

SIZE = 256
SS = 4
STROKE = 16

WHITE = (255, 255, 255, 255)
ASPHALT = (35, 39, 44, 255)
LIMESTONE = (237, 229, 211, 255)

OUT = Path(__file__).parent
SHEET = OUT.parent.parent / "render" / "ui" / "perks-hoja.png"

FONT_BOLD = Path(r"C:\Windows\Fonts\segoeuib.ttf")


# ---------------------------------------------------------------------------------------------
# Piezas de dibujo. Todo se dibuja sobre una máscara: 255 = opaco, 0 = transparente.
# ---------------------------------------------------------------------------------------------


def new_canvas():
    image = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    return image, ImageDraw.Draw(image)


def at(points):
    return [(x * SS, y * SS) for x, y in points]


def box(x0, y0, x1, y1):
    return [x0 * SS, y0 * SS, x1 * SS, y1 * SS]


def spline(points, samples=14):
    """Catmull-Rom cerrado: una curva que pasa por todos los puntos, para formas orgánicas."""
    count = len(points)
    result = []
    for index in range(count):
        p0 = points[(index - 1) % count]
        p1 = points[index]
        p2 = points[(index + 1) % count]
        p3 = points[(index + 2) % count]
        for step in range(samples):
            t = step / samples
            t2, t3 = t * t, t * t * t
            x = 0.5 * (
                2 * p1[0]
                + (-p0[0] + p2[0]) * t
                + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3
            )
            y = 0.5 * (
                2 * p1[1]
                + (-p0[1] + p2[1]) * t
                + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3
            )
            result.append((x, y))
    return result


def curve(points, steps=18):
    """Tramo abierto de Catmull-Rom entre los puntos dados, del primero al último."""
    result = []
    for index in range(len(points) - 1):
        p0 = points[index - 1] if index > 0 else points[0]
        p1 = points[index]
        p2 = points[index + 1]
        p3 = points[index + 2] if index + 2 < len(points) else points[-1]
        for step in range(steps):
            t = step / steps
            t2, t3 = t * t, t * t * t
            result.append(
                (
                    0.5
                    * (
                        2 * p1[0]
                        + (-p0[0] + p2[0]) * t
                        + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                        + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3
                    ),
                    0.5
                    * (
                        2 * p1[1]
                        + (-p0[1] + p2[1]) * t
                        + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                        + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3
                    ),
                )
            )
    result.append(points[-1])
    return result


def fill_shape(draw, points, smooth=True):
    draw.polygon(at(spline(points) if smooth else points), fill=255)


def erase_shape(draw, points, smooth=True):
    draw.polygon(at(spline(points) if smooth else points), fill=0)


def disc(draw, cx, cy, radius, value=255):
    draw.ellipse(box(cx - radius, cy - radius, cx + radius, cy + radius), fill=value)


def ring(draw, cx, cy, outer, inner, value=255):
    disc(draw, cx, cy, outer, value)
    disc(draw, cx, cy, inner, 255 - value)


def stroke(draw, points, width=STROKE, closed=False, value=255):
    """Polilínea de grosor constante con extremos y vértices redondeados."""
    scaled = at(list(points) + ([points[0]] if closed else []))
    thickness = int(round(width * SS))
    draw.line(scaled, fill=value, width=thickness, joint="curve")
    if not closed:
        for x, y in (scaled[0], scaled[-1]):
            draw.ellipse([x - thickness / 2, y - thickness / 2, x + thickness / 2, y + thickness / 2], fill=value)


def rrect(draw, x0, y0, x1, y1, radius, value=255):
    draw.rounded_rectangle(box(x0, y0, x1, y1), radius=radius * SS, fill=value)


def star(draw, cx, cy, radius, waist, points=4, phase=-math.pi / 2):
    """Estrella de puntas afiladas: `waist` es el radio de los valles."""
    vertices = []
    for index in range(points * 2):
        angle = phase + index * math.pi / points
        reach = radius if index % 2 == 0 else waist
        vertices.append((cx + math.cos(angle) * reach, cy + math.sin(angle) * reach))
    draw.polygon(at(vertices), fill=255)


def arrow(draw, tail, tip, width, head):
    """Flecha rellena: asta de `width` y punta triangular de `head` de ancho."""
    tx, ty = tip
    hx, hy = tail
    length = math.hypot(tx - hx, ty - hy)
    ux, uy = (tx - hx) / length, (ty - hy) / length
    nx, ny = -uy, ux
    neck = (tx - ux * head * 0.9, ty - uy * head * 0.9)
    stroke(draw, [(hx, hy), neck], width=width)
    draw.polygon(
        at(
            [
                (tx, ty),
                (neck[0] + nx * head / 2, neck[1] + ny * head / 2),
                (neck[0] - nx * head / 2, neck[1] - ny * head / 2),
            ]
        ),
        fill=255,
    )


def radial_head(draw, cx, cy, radius, angle, size, sweep=1):
    """Punta de flecha tangente a un anillo: base radial y punta en el sentido de giro."""
    base = math.radians(angle)
    tip = math.radians(angle + sweep * 20)
    draw.polygon(
        at(
            [
                (cx + math.cos(base) * (radius + size / 2), cy + math.sin(base) * (radius + size / 2)),
                (cx + math.cos(tip) * (radius + size * 0.12), cy + math.sin(tip) * (radius + size * 0.12)),
                (cx + math.cos(base) * (radius - size / 2), cy + math.sin(base) * (radius - size / 2)),
            ]
        ),
        fill=255,
    )


def shifted(layer, dx, dy):
    moved = Image.new("L", layer.size, 0)
    moved.paste(layer, (int(round(dx * SS)), int(round(dy * SS))))
    return moved


def rotated(layer, angle, center=None):
    if center is None:
        center = (SIZE * SS / 2, SIZE * SS / 2)
    return layer.rotate(angle, resample=Image.BICUBIC, center=center)


def centered(layer):
    """Centra la capa por su caja de contenido, sin reescalarla."""
    bounds = layer.getbbox()
    if not bounds:
        return layer
    content = layer.crop(bounds)
    canvas = Image.new("L", layer.size, 0)
    canvas.paste(content, ((layer.width - content.width) // 2, (layer.height - content.height) // 2))
    return canvas


# ---------------------------------------------------------------------------------------------
# Los doce dibujos. Coordenadas en píxeles finales (256 x 256) sobre un lienzo transparente.
# ---------------------------------------------------------------------------------------------


def perk_banker():
    """Bolsa de dinero atada con un nudo, y una moneda al lado. Silueta llena."""
    image, draw = new_canvas()
    body = [
        (88, 92), (64, 110), (46, 146), (36, 184), (44, 212), (74, 226),
        (110, 228), (146, 226), (176, 212), (184, 184), (174, 146), (156, 110), (132, 92),
    ]
    fill_shape(draw, body)
    # La tela recogida sobre el nudo: un copete corto, no dos orejas.
    fill_shape(draw, [(92, 96), (100, 48), (120, 48), (128, 96)])
    # El nudo: banda más ancha que el cuello y más estrecha que la panza.
    rrect(draw, 68, 62, 152, 102, 17)
    # La moneda, al lado y con aire.
    disc(draw, 200, 80, 26, 255)
    return image


def perk_landlord():
    """Llave grande de perfil, con anilla y dientes claros. Silueta llena."""
    image, draw = new_canvas()
    angle = math.radians(-38)

    def turn(px, py):
        dx, dy = px - 128, py - 128
        return (128 + dx * math.cos(angle) - dy * math.sin(angle), 128 + dx * math.sin(angle) + dy * math.cos(angle))

    # Anilla, asta y dientes en coordenadas verticales; se giran al dibujar.
    bx, by = turn(128, 74)
    ring(draw, bx, by, 58, 30)
    stroke(draw, [turn(128, 108), turn(128, 200)], width=46)
    for corners in ((146, 134, 206, 162), (146, 172, 184, 200)):
        draw.polygon(at([turn(corners[0], corners[1]), turn(corners[0], corners[3]),
                         turn(corners[2], corners[3]), turn(corners[2], corners[1])]), fill=255)
    return centered(image)


def tapered(draw, path, start, end):
    """Trazo que se afila de `start` a `end` de ancho, siguiendo la curva `path`."""
    left, right = [], []
    for index, (x, y) in enumerate(path):
        px, py = path[max(index - 1, 0)]
        nx, ny = path[min(index + 1, len(path) - 1)]
        length = math.hypot(nx - px, ny - py) or 1
        ox, oy = -(ny - py) / length, (nx - px) / length
        half = (start + (end - start) * index / (len(path) - 1)) / 2
        left.append((x + ox * half, y + oy * half))
        right.append((x - ox * half, y - oy * half))
    head = (path[0][0], path[0][1])
    draw.polygon(at(left + list(reversed(right)) + [head]), fill=255)


def perk_builder():
    """Martillo de orejas de perfil, cabeza a la izquierda y mango hacia abajo. Silueta llena."""
    image, draw = new_canvas()
    stroke(draw, [(100, 100), (150, 204)], width=38)
    head = [(29, 58), (88, 50), (152, 46), (152, 122), (88, 122), (29, 128)]
    fill_shape(draw, head, smooth=False)
    # La uña: cuerno grueso que sale del extremo de la cabeza y enrosca su punta hacia el mango.
    tapered(
        draw,
        curve([(148, 66), (186, 50), (210, 72), (210, 102), (194, 128), (174, 134)], steps=10),
        start=48,
        end=9,
    )
    return image


def perk_smuggler():
    """Maletín con asa y una línea interior que marca el doble fondo. Contorno de 16 px."""
    image, draw = new_canvas()
    draw.rounded_rectangle(box(30, 88, 226, 226), radius=18 * SS, outline=255, width=STROKE * SS)
    # Asa: media anilla apoyada en el borde superior.
    draw.arc(box(94, 40, 162, 112), 180, 360, fill=255, width=STROKE * SS)
    # La línea del doble fondo.
    stroke(draw, [(48, 178), (208, 178)])
    return image


def perk_quick_fingers():
    """Dado dentro de una flecha circular que lo rodea. Silueta llena."""
    image, draw = new_canvas()
    cx, cy, outer, inner = 128, 128, 100, 66
    # El anillo, abierto en el cuadrante superior derecho, con su punta hacia la boca.
    draw.arc(box(cx - outer, cy - outer, cx + outer, cy + outer), 344, 300, fill=255, width=(outer - inner) * SS)
    radial_head(draw, cx, cy, (outer + inner) / 2, 300, 58)
    # El dado, con su hueco alrededor para que no se pegue al anillo.
    rrect(draw, cx - 46, cy - 46, cx + 46, cy + 46, 13)
    for dot in ((-24, -24), (24, 24), (0, 0)):
        disc(draw, cx + dot[0], cy + dot[1], 11, 0)
    return image


def perk_lawyer():
    """Balanza de dos platos con su pie. Silueta llena."""
    image, draw = new_canvas()
    rrect(draw, 80, 210, 176, 228, 8)
    rrect(draw, 118, 56, 138, 214, 0)
    rrect(draw, 42, 44, 214, 60, 6)
    star(draw, 128, 42, 14, 5)
    for cx in (68, 188):
        rrect(draw, cx - 7, 56, cx + 7, 102, 0)
        draw.pieslice(box(cx - 40, 46, cx + 40, 158), 0, 180, fill=255)
        rrect(draw, cx - 40, 98, cx + 40, 110, 3)
    return image


def perk_negotiator():
    """Dos eslabones de cadena enlazados en diagonal. Silueta llena."""
    image, _ = new_canvas()
    band = 28
    half_len, half_wid = 66, 34
    first, second = (88, 172), (168, 92)

    def link(center, grow):
        layer = Image.new("L", image.size, 0)
        draw = ImageDraw.Draw(layer)
        draw.rounded_rectangle(
            box(128 - half_wid - grow, 128 - half_len - grow, 128 + half_wid + grow, 128 + half_len + grow),
            radius=(half_wid + grow) * SS,
            outline=255,
            width=(band + 2 * grow) * SS,
        )
        return shifted(rotated(layer, -45), center[0] - 128, center[1] - 128)

    first_band, first_halo = link(first, 0), link(first, 13)
    second_band, second_halo = link(second, 0), link(second, 13)
    # Dos semiplanos separados por el eje de la cadena: en uno pasa por encima un eslabón y en el
    # otro el otro, que es lo que los hace parecer enlazados y no superpuestos.
    dx, dy = second[0] - first[0], second[1] - first[1]
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length
    mx, my = (first[0] + second[0]) / 2, (first[1] + second[1]) / 2
    far = 420
    axis = Image.new("L", image.size, 0)
    ImageDraw.Draw(axis).polygon(
        at(
            [
                (mx - ux * far, my - uy * far),
                (mx + ux * far, my + uy * far),
                (mx + ux * far - uy * far, my + uy * far + ux * far),
                (mx - ux * far - uy * far, my - uy * far + ux * far),
            ]
        ),
        fill=255,
    )
    cut_first = ImageChops.multiply(first_band, ImageChops.multiply(second_halo, ImageChops.invert(axis)))
    cut_second = ImageChops.multiply(second_band, ImageChops.multiply(first_halo, axis))
    return centered(
        ImageChops.lighter(
            ImageChops.subtract(first_band, cut_first), ImageChops.subtract(second_band, cut_second)
        )
    )


def perk_lucky():
    """Estrella de cuatro puntas con dos chispas. Silueta llena."""
    image, draw = new_canvas()
    star(draw, 116, 136, 90, 24)
    star(draw, 200, 56, 26, 8)
    star(draw, 52, 204, 20, 6)
    return image


def perk_hunter():
    """Mira de puntos con una flecha dentro. Silueta llena."""
    image, draw = new_canvas()
    cx, cy = 128, 128
    ring(draw, cx, cy, 80, 56)
    for angle in (0, 90, 180, 270):
        rad = math.radians(angle)
        stroke(
            draw,
            [
                (cx + math.cos(rad) * 70, cy + math.sin(rad) * 70),
                (cx + math.cos(rad) * 94, cy + math.sin(rad) * 94),
            ],
            width=24,
        )
    arrow(draw, (94, 162), (164, 92), width=24, head=52)
    return image


def perk_armored():
    """Escudo con una segunda placa interior, separada por el bisel. Silueta llena."""
    image, draw = new_canvas()

    def shield(x0, y0, x1, y1):
        width, height = x1 - x0, y1 - y0
        return [
            (x0 + width * 0.02, y0),
            (x0 + width * 0.98, y0),
            (x0 + width * 0.99, y0 + height * 0.42),
            (x0 + width * 0.86, y0 + height * 0.72),
            (x0 + width * 0.50, y0 + height),
            (x0 + width * 0.14, y0 + height * 0.72),
            (x0 + width * 0.01, y0 + height * 0.42),
        ]

    fill_shape(draw, shield(28, 28, 228, 228), smooth=False)
    erase_shape(draw, shield(50, 54, 206, 200), smooth=False)
    fill_shape(draw, shield(74, 76, 182, 178), smooth=False)
    return image


def perk_collector():
    """Carpeta con tres cartas asomando por el borde. Silueta llena."""
    image, _ = new_canvas()

    def card(center, top, tilt, grow=0):
        layer = Image.new("L", image.size, 0)
        draw = ImageDraw.Draw(layer)
        draw.rounded_rectangle(
            box(center - 41 - grow, top - grow, center + 41 + grow, top + 120 + grow),
            radius=(6 + grow) * SS,
            fill=255,
        )
        return rotated(layer, tilt, center=(center * SS, (top + 60) * SS))

    # Tres cartas escalonadas que asoman por la boca; la de en medio queda delante.
    cards = Image.new("L", image.size, 0)
    for center, top, tilt in ((74, 62, -6), (128, 44, 0), (182, 58, 6)):
        cards = ImageChops.subtract(cards, card(center, top, tilt, grow=7))
        cards = ImageChops.lighter(cards, card(center, top, tilt))
    # La carpeta con su pestaña; las cartas se cortan 16 px por encima del borde.
    folder = Image.new("L", image.size, 0)
    folder_draw = ImageDraw.Draw(folder)
    folder_draw.rounded_rectangle(box(28, 148, 228, 228), radius=12 * SS, fill=255)
    folder_draw.rounded_rectangle(box(28, 118, 108, 152), radius=8 * SS, fill=255)
    cards = ImageChops.subtract(cards, shifted(folder, 0, -16))
    return ImageChops.lighter(cards, folder)


def perk_restless_soul():
    """Fantasma con la cola ondulada, silueta llena (mismo lenguaje que icons/ghost.png)."""
    image, draw = new_canvas()
    left, right, top = 34, 222, 32
    draw.pieslice(box(left, top, right, top + 168), 180, 360, fill=255)
    draw.rectangle(box(left, top + 84, right, 196), fill=255)
    wave = []
    steps = 140
    for step in range(steps + 1):
        x = left + (right - left) * step / steps
        y = 196 + 30 * math.cos(2 * math.pi * (x - left) / ((right - left) / 3))
        wave.append((x, y))
    draw.polygon(at(wave + [(right, 188), (left, 188)]), fill=255)
    # Ojos calados.
    draw.ellipse(box(84, 84, 110, 120), fill=0)
    draw.ellipse(box(146, 84, 172, 120), fill=0)
    return image


PERKS = [
    ("Banker", "banker", "Banquero", perk_banker),
    ("Landlord", "landlord", "Casero", perk_landlord),
    ("Builder", "builder", "Constructor", perk_builder),
    ("Smuggler", "smuggler", "Contrabandista", perk_smuggler),
    ("QuickFingers", "quick-fingers", "Dedos Rápidos", perk_quick_fingers),
    ("Lawyer", "lawyer", "Abogado", perk_lawyer),
    ("Negotiator", "negotiator", "Negociador", perk_negotiator),
    ("Lucky", "lucky", "Afortunado", perk_lucky),
    ("Hunter", "hunter", "Cazador", perk_hunter),
    ("Armored", "armored", "Blindado", perk_armored),
    ("Collector", "collector", "Coleccionista", perk_collector),
    ("RestlessSoul", "restless-soul", "Alma en Pena", perk_restless_soul),
]


# ---------------------------------------------------------------------------------------------
# Salida: PNG, hoja de contacto y manifiesto.
# ---------------------------------------------------------------------------------------------


def save_icon(mask, name):
    """Reduce una sola vez a 256 y pone el blanco: el alfa es lo único que varía."""
    reduced = mask.resize((SIZE, SIZE), Image.LANCZOS)
    icon = Image.new("RGBA", (SIZE, SIZE), WHITE)
    icon.putalpha(reduced)
    icon.save(OUT / f"{name}.png")
    return icon


def tinted(icon, color):
    """Como lo tiñe el juego con ImageColor3: mismo alfa, color plano."""
    flat = Image.new("RGBA", icon.size, color)
    flat.putalpha(icon.getchannel("A"))
    return flat


def font(size):
    try:
        return ImageFont.truetype(str(FONT_BOLD), size)
    except OSError:
        return ImageFont.load_default(size)


def contact_sheet(icons):
    sheet = Image.new("RGBA", (1600, 900), ASPHALT)
    draw = ImageDraw.Draw(sheet)
    draw.text((72, 44), "FLIP THE TABLE · PERKS", font=font(34), fill=LIMESTONE)
    draw.text(
        (72, 88),
        "blanco #FFFFFF sobre transparente · 256 × 256 · un solo trazo de 16 px por icono",
        font=font(19),
        fill=(150, 152, 152, 255),
    )

    pitch = 1600 / 6
    for index, (_, _, label, icon) in enumerate(icons):
        cell = pitch * (index % 6) + pitch / 2
        top = 136 + (index // 6) * 200
        sheet.alpha_composite(icon.resize((128, 128), Image.LANCZOS), (int(cell - 64), top))
        draw.text((int(cell), top + 142), label, font=font(24), fill=LIMESTONE, anchor="ma")

    # La prueba de verdad: los doce a 20 px, pegados y sin separación, teñidos como en el juego.
    strip_top, strip_bottom = 528, 648
    draw.rectangle([0, strip_top, 1600, strip_bottom], fill=LIMESTONE)
    draw.text((72, strip_top + 52), "A 20 PX, COMO LOS TIÑE EL JUEGO", font=font(20), fill=ASPHALT)
    start = (1600 - 12 * 20) // 2
    for index, (_, _, _, icon) in enumerate(icons):
        small = tinted(icon.resize((20, 20), Image.LANCZOS), ASPHALT)
        sheet.alpha_composite(small, (start + index * 20, strip_top + 50))

    draw.text(
        (72, 700),
        "Cada perk es silueta llena o contorno de 16 px: nunca las dos cosas en el mismo icono.",
        font=font(19),
        fill=(150, 152, 152, 255),
    )
    draw.text(
        (72, 732),
        "Dibujados a 4× desde una máscara de alfa y reducidos una sola vez con LANCZOS: el RGB es 255 en todo píxel.",
        font=font(19),
        fill=(150, 152, 152, 255),
    )
    draw.text((72, 852), "FLIP THE TABLE · ART/UI/PERKS/BUILD_PERKS.PY", font=font(17), fill=(120, 122, 124, 255))
    sheet.convert("RGB").save(SHEET)


def manifest():
    entries = [
        {
            "id": f"ui-perk-{slug}",
            "category": "UiImage",
            "source": "art/ui/perks/build_perks.py",
            "triangles": 0,
            "lods": [],
            "textures": 0,
            "status": "Draft",
            "screenshots": [],
            "generatedWith": "Pillow y Python, art/ui/perks/build_perks.py",
        }
        for _, slug, _, _ in PERKS
    ]
    (OUT / "manifest-perks.json").write_text(json.dumps(entries, indent=2) + "\n", encoding="utf-8")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    SHEET.parent.mkdir(parents=True, exist_ok=True)
    icons = [(perk_id, slug, label, save_icon(painter(), slug)) for perk_id, slug, label, painter in PERKS]
    contact_sheet(icons)
    manifest()
    print(f"{len(icons)} iconos en {OUT}")
    print(f"hoja de contacto en {SHEET}")


if __name__ == "__main__":
    main()

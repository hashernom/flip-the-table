#!/usr/bin/env python
"""Iconos propios de la interfaz de Flip the Table, dibujados con geometría (art/guia-de-estilo.md §9).

Uso: python art/ui/icons/build_icons.py
Escribe un PNG con alfa por icono junto a este archivo. Los iconos `mono` van en blanco para teñirlos
con `ImageColor3`; los demás llevan su color. Se dibuja a 4x y se reduce, para que el borde quede limpio.
"""
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 256
SS = 4
ASPHALT = (20, 23, 26, 255)
LIMESTONE = (237, 229, 211, 255)
TAXI = (245, 197, 24, 255)
SIGNAL = (196, 56, 43, 255)
GOLD = (201, 162, 39, 255)
WORKS = (224, 122, 60, 255)
GLASS = (127, 178, 217, 255)
WHITE = (255, 255, 255, 255)
SKIN = (242, 200, 148, 255)
HAIR = (91, 58, 34, 255)

OUT = Path(__file__).parent


def canvas(width=SIZE, height=SIZE):
    image = Image.new("RGBA", (width * SS, height * SS), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image)


def pts(values):
    return [(x * SS, y * SS) for x, y in values]


def box(x0, y0, x1, y1):
    return [x0 * SS, y0 * SS, x1 * SS, y1 * SS]


def stroke_poly(draw, points, fill, outline, width):
    draw.polygon(pts(points), fill=fill)
    closed = pts(points + [points[0], points[1]])
    draw.line(closed, fill=outline, width=width * SS, joint="curve")


def save(image, name):
    image.resize((image.width // SS, image.height // SS), Image.LANCZOS).save(OUT / f"{name}.png")


def crown():
    image, draw = canvas()
    points = [(30, 212), (14, 76), (82, 132), (128, 30), (174, 132), (242, 76), (226, 212)]
    stroke_poly(draw, points, GOLD, ASPHALT, 16)
    draw.ellipse(box(106, 138, 150, 182), fill=SIGNAL, outline=ASPHALT, width=8 * SS)
    for x, y in ((14, 76), (128, 30), (242, 76)):
        draw.ellipse(box(x - 14, y - 14, x + 14, y + 14), fill=GOLD, outline=ASPHALT, width=7 * SS)
    save(image, "crown")


def ghost():
    image, draw = canvas()
    wave = [(44, 110), (44, 232), (72, 208), (100, 232), (128, 208), (156, 232), (184, 208), (212, 232), (212, 110)]
    draw.pieslice(box(44, 26, 212, 194), 180, 360, fill=LIMESTONE)
    draw.polygon(pts(wave), fill=LIMESTONE)
    draw.arc(box(44, 26, 212, 194), 180, 360, fill=ASPHALT, width=12 * SS)
    draw.line(pts(wave), fill=ASPHALT, width=12 * SS, joint="curve")
    draw.ellipse(box(88, 92, 112, 124), fill=ASPHALT)
    draw.ellipse(box(144, 92, 168, 124), fill=ASPHALT)
    draw.ellipse(box(114, 138, 142, 174), fill=ASPHALT)
    save(image, "ghost")


def face():
    image, draw = canvas()
    draw.rounded_rectangle(box(44, 52, 212, 216), radius=44 * SS, fill=SKIN, outline=ASPHALT, width=10 * SS)
    draw.ellipse(box(90, 112, 114, 136), fill=ASPHALT)
    draw.ellipse(box(142, 112, 166, 136), fill=ASPHALT)
    draw.arc(box(88, 124, 168, 188), 25, 155, fill=ASPHALT, width=11 * SS)
    draw.pieslice(box(44, 34, 212, 150), 180, 360, fill=HAIR)
    save(image, "face")


def flame():
    image, draw = canvas()
    points = [(128, 14), (150, 66), (206, 118), (214, 168), (190, 216), (128, 242), (66, 216), (42, 168), (52, 124), (88, 86), (98, 128), (120, 118), (112, 62)]
    draw.line(pts(points + points[:2]), fill=WHITE, width=20 * SS, joint="curve")
    save(image, "flame")


def cards():
    image, draw = canvas()
    back = Image.new("RGBA", image.size, (0, 0, 0, 0))
    back_draw = ImageDraw.Draw(back)
    back_draw.rounded_rectangle(box(44, 58, 148, 214), radius=16 * SS, outline=WHITE, width=16 * SS)
    image.alpha_composite(back.rotate(11, resample=Image.BICUBIC, center=(96 * SS, 136 * SS)))
    front = Image.new("RGBA", image.size, (0, 0, 0, 0))
    front_draw = ImageDraw.Draw(front)
    front_draw.rounded_rectangle(box(108, 42, 212, 198), radius=16 * SS, outline=WHITE, width=16 * SS)
    image.alpha_composite(front.rotate(-9, resample=Image.BICUBIC, center=(160 * SS, 120 * SS)))
    _ = draw
    save(image, "cards")


def map_icon():
    image, draw = canvas()
    draw.rounded_rectangle(box(30, 30, 226, 226), radius=26 * SS, outline=WHITE, width=20 * SS)
    draw.rounded_rectangle(box(92, 92, 164, 164), radius=12 * SS, outline=WHITE, width=16 * SS)
    save(image, "map")


def smile():
    image, draw = canvas()
    draw.ellipse(box(26, 26, 230, 230), outline=WHITE, width=20 * SS)
    draw.rounded_rectangle(box(84, 84, 106, 124), radius=10 * SS, fill=WHITE)
    draw.rounded_rectangle(box(150, 84, 172, 124), radius=10 * SS, fill=WHITE)
    draw.arc(box(74, 92, 182, 190), 25, 155, fill=WHITE, width=18 * SS)
    save(image, "smile")


def cone():
    image, draw = canvas()
    stroke_poly(draw, [(128, 16), (190, 196), (66, 196)], WORKS, ASPHALT, 12)
    draw.polygon(pts([(103, 88), (153, 88), (168, 138), (88, 138)]), fill=LIMESTONE)
    draw.rounded_rectangle(box(22, 192, 234, 236), radius=14 * SS, fill=WORKS, outline=ASPHALT, width=12 * SS)
    save(image, "cone")


def taxi_side():
    width, height = 372, 204
    image, draw = canvas(width, height)
    body = [(16, 150), (16, 104), (30, 86), (90, 84), (132, 30), (150, 22), (246, 22), (264, 32), (298, 84), (336, 88), (358, 108), (358, 150)]
    stroke_poly(draw, body, TAXI, ASPHALT, 12)
    stroke_poly(draw, [(148, 38), (188, 38), (188, 84), (112, 84)], GLASS, ASPHALT, 7)
    stroke_poly(draw, [(206, 38), (248, 38), (276, 84), (206, 84)], GLASS, ASPHALT, 7)
    draw.rounded_rectangle(box(160, 2, 228, 24), radius=5 * SS, fill=SIGNAL, outline=ASPHALT, width=6 * SS)
    for index in range(16):
        x = 28 + index * 20
        draw.rectangle(box(x, 106 + (index % 2) * 10, x + 10, 116 + (index % 2) * 10), fill=ASPHALT)
    for center in (92, 282):
        draw.ellipse(box(center - 38, 120, center + 38, 196), fill=ASPHALT, outline=ASPHALT)
        draw.ellipse(box(center - 18, 140, center + 18, 176), fill=LIMESTONE)
    save(image, "taxi-side")


def plate_arrow():
    """Chapa de la placa del turno: esmalte claro troquelado en flecha, con doble filete y labio."""
    width, height = 960, 312
    image, draw = canvas(width, height)

    def shape(layer, inset, fill, dy=0):
        top, bottom = 12 + inset + dy, height - 24 - inset + dy
        middle = (top + bottom) / 2
        body_right = width - 170
        layer.rounded_rectangle(box(12 + inset, top, body_right, bottom), radius=max(6, 44 - inset) * SS, fill=fill)
        tip = [(body_right - 40, top), (body_right, top), (width - 16 - inset * 1.5, middle), (body_right, bottom), (body_right - 40, bottom)]
        layer.polygon(pts(tip), fill=fill)
        joint = pts([(body_right, top), (width - 16 - inset * 1.5, middle), (body_right, bottom)])
        layer.line(joint, fill=fill, width=int(10 * SS), joint="curve")

    shape(draw, 0, (20, 23, 26, 115), dy=12)
    shape(draw, 0, ASPHALT)
    shape(draw, 12, LIMESTONE)
    shape(draw, 24, ASPHALT)
    shape(draw, 28, LIMESTONE)
    save(image, "plate-arrow")


if __name__ == "__main__":
    for build in (plate_arrow, crown, ghost, face, flame, cards, map_icon, smile, cone, taxi_side):
        build()
    print("iconos escritos en", OUT)

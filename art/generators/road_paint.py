"""Genera la pintura desgastada de las casillas: un marco sobre el asfalto, en blanco con transparencia.

El juego la tiñe con el color de la zona, así que basta una textura para todos los colores. Salen varias
variantes con el mismo marco y distinto desgaste, para que dos casillas no parezcan copiadas.

Medidas en studs: 33 de ancho de calle por 28 a lo largo de ella. En Roblox, el ancho de la imagen va de lado a
lado de la calle. El lado grueso del marco es el que da al edificio: el borde izquierdo de la imagen.

Salidas: art/textures/casillas/pintura_N.png y preview.png, solo para revisión.
Uso: python art/generators/road_paint.py
"""

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, "..", "textures", "casillas"))
ACROSS, ALONG = 33.0, 28.0
PX = 34  # píxeles por stud
W, H = int(ACROSS * PX), int(ALONG * PX)
FRAME = 1.1  # grosor del marco
FRAME_BUILDING = 1.7  # grosor del lado que da al edificio
INTERIOR = 0.025  # opacidad del tinte interior
WORN = 0.27  # parte de la pintura del marco que se pierde
VARIANTS = 3
BAND = 6  # isla del lado del edificio, donde irán las mejoras
BAND_OPACITY = 0.62


def noise(rng, scale):
    """Ruido suave: píxeles al azar ampliados y difuminados, entre 0 y 1."""
    small = rng.random((max(2, int(H / scale)), max(2, int(W / scale))))
    image = Image.fromarray((small * 255).astype("uint8")).resize((W, H), Image.BICUBIC)
    image = image.filter(ImageFilter.GaussianBlur(scale / 4))
    data = np.asarray(image, dtype=float)
    return (data - data.min()) / max(1.0, data.max() - data.min())


def fractal(rng, scales):
    total = sum(1.0 / (order + 1) * noise(rng, scale) for order, scale in enumerate(scales))
    return (total - total.min()) / (total.max() - total.min())


def cracks(rng, count):
    """Grietas del asfalto: líneas quebradas por donde se pierde la pintura."""
    image = Image.new("L", (W, H), 0)
    draw = ImageDraw.Draw(image)
    for _ in range(count):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        angle = rng.uniform(0, 2 * np.pi)
        points = [(x, y)]
        for _ in range(int(rng.integers(5, 14))):
            angle += rng.uniform(-0.7, 0.7)
            x += np.cos(angle) * rng.uniform(15, 45)
            y += np.sin(angle) * rng.uniform(15, 45)
            points.append((x, y))
        draw.line(points, fill=255, width=int(rng.integers(1, 4)))
    return np.asarray(image.filter(ImageFilter.GaussianBlur(0.7)), dtype=float) / 255


def frame_alpha(rng, band=False):
    ys, xs = np.mgrid[0:H, 0:W]
    fine = fractal(rng, [14, 34])
    wobble = (fine - 0.5) * 0.5 * PX  # borde irregular, como pintado a rodillo
    edge_top = ys - wobble
    edge_left = xs - wobble
    edge_right = (W - 1 - xs) - wobble
    edge_bottom = (H - 1 - ys) - wobble
    frame = (
        (edge_top < FRAME * PX)
        | (edge_left < FRAME_BUILDING * PX)
        | (edge_right < FRAME * PX)
        | (edge_bottom < FRAME * PX)
    )
    # Un margen transparente: el marco no llega al filo exacto de la imagen.
    margin = 0.12 * PX
    inside = (ys > margin) & (xs > margin) & (ys < H - margin) & (xs < W - margin)

    patches = fractal(rng, [90, 40, 14])
    grain = fractal(rng, [5, 2.5])
    threshold = np.quantile(patches * 0.8 + grain * 0.2, WORN)
    keep = (patches * 0.8 + grain * 0.2) > threshold
    crack = cracks(rng, 16) > 0.35

    paint = frame & keep & ~crack & inside
    # La pintura que queda no es plana: unas zonas están más gastadas que otras.
    strength = 0.72 + 0.28 * fractal(rng, [60, 10])
    tint = INTERIOR * (0.5 + fractal(rng, [80, 25])) * ~crack * inside
    alpha = np.where(paint, strength, tint)
    if band:
        # Semisólida y con el mismo desgaste, pero menos roto que el contorno.
        worn = fractal(rng, [50, 12]) > 0.22
        island = (edge_left < BAND * PX) & inside & worn & ~crack
        alpha = np.where(island, np.maximum(alpha, BAND_OPACITY * strength), alpha)
    image = Image.fromarray((np.clip(alpha, 0, 1) * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(0.8))
    return image


def main():
    os.makedirs(OUT, exist_ok=True)
    tiles = []
    for variant in range(1, VARIANTS + 1):
        alpha = frame_alpha(np.random.default_rng(1000 + variant))
        white = Image.new("L", (W, H), 255)
        Image.merge("LA", (white, alpha)).save(os.path.join(OUT, f"pintura_{variant}.png"))
        tiles.append(alpha)
        banded = frame_alpha(np.random.default_rng(2000 + variant), band=True)
        Image.merge("LA", (white, banded)).save(os.path.join(OUT, f"pintura_isla_{variant}.png"))

    # Revisión: tres casillas teñidas sobre un asfalto liso.
    colours = [(201, 123, 58), (220, 38, 38), (100, 116, 139)]
    sheet = Image.new("RGB", (W + 40, (H + 20) * VARIANTS + 20), (74, 78, 84))
    for order, (alpha, colour) in enumerate(zip(tiles, colours)):
        sheet.paste(Image.new("RGB", (W, H), colour), (20, 20 + order * (H + 20)), alpha)
    sheet.save(os.path.join(OUT, "preview.png"))


if __name__ == "__main__":
    main()

"""Genera la skybox y los sets de texturas PBR de Metrópolis.

Todo es procedural y determinista: el mismo comando da los mismos archivos. No usa
texturas de terceros, así que no hay licencia que revisar.

El ruido es de valor con octavas (fBm) y periódico en los dos ejes: así las texturas
teselan sin costura y las caras de la skybox casan entre sí.

Salidas:
  art/skybox/{up,down,left,right,front,back}.png   1024x1024, listas para subir
  art/textures/<set>_{albedo,roughness,normal}.png
  art/render/hoja-texturas.png                     hoja de contactos para revisar

Uso: python art/generators/pbr_assets.py
"""

import json
import math
import os

import numpy as np
from PIL import Image

ART = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKY_DIR = os.path.join(ART, "skybox")
TEX_DIR = os.path.join(ART, "textures")
RENDER_DIR = os.path.join(ART, "render")
SIZE = 1024


def save(image, path):
    Image.fromarray(np.clip(image, 0, 255).astype(np.uint8)).save(path)


def value_noise(width, height, cells, seed):
    """Una octava de ruido de valor, periódica en ambos ejes."""
    rng = np.random.default_rng(seed)
    grid = rng.random((cells, cells))

    xs = np.arange(width) * cells / width
    ys = np.arange(height) * cells / height
    x0 = np.floor(xs).astype(int) % cells
    y0 = np.floor(ys).astype(int) % cells
    x1 = (x0 + 1) % cells
    y1 = (y0 + 1) % cells

    tx = xs - np.floor(xs)
    ty = ys - np.floor(ys)
    tx = tx * tx * (3 - 2 * tx)
    ty = ty * ty * (3 - 2 * ty)

    c00 = grid[np.ix_(y0, x0)]
    c10 = grid[np.ix_(y0, x1)]
    c01 = grid[np.ix_(y1, x0)]
    c11 = grid[np.ix_(y1, x1)]

    top = c00 + (c10 - c00) * tx[None, :]
    bottom = c01 + (c11 - c01) * tx[None, :]
    return top + (bottom - top) * ty[:, None]


def fbm(width, height, cells=4, octaves=5, seed=0, gain=0.5, turbulence=False):
    total = np.zeros((height, width))
    amplitude = 1.0
    norm = 0.0
    for octave in range(octaves):
        layer = value_noise(width, height, cells * (2**octave), seed + octave * 17)
        if turbulence:
            # Turbulencia: da bordes de nube en vez de manchas redondas.
            layer = 1.0 - np.abs(2.0 * layer - 1.0)
        total += amplitude * layer
        norm += amplitude
        amplitude *= gain
    return total / norm


def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def box_blur(array, radius=1):
    out = array.copy()
    for _ in range(radius):
        out = (np.roll(out, 1, 0) + out + np.roll(out, -1, 0)) / 3.0
        out = (np.roll(out, 1, 1) + out + np.roll(out, -1, 1)) / 3.0
    return out


def normal_from_height(height, strength=1.0):
    dx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(height)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    # Formato OpenGL: el canal G no se invierte. Roblox lo exige así.
    return np.stack(
        [(nx / length * 0.5 + 0.5), (ny / length * 0.5 + 0.5), (nz / length * 0.5 + 0.5)],
        axis=-1,
    ) * 255.0


ZENITH = np.array([56.0, 102.0, 160.0])
HORIZON = np.array([218.0, 230.0, 240.0])
CLOUD = np.array([252.0, 251.0, 248.0])


def sky_panorama(seed):
    """Las cuatro caras de una sola tirada: generadas por separado, se ven las costuras."""
    width = SIZE * 4
    t = np.linspace(0.0, 1.0, SIZE)[:, None]
    gradient = ZENITH[None, None, :] + (HORIZON - ZENITH)[None, None, :] * (t[..., None] ** 0.85)
    image = np.repeat(gradient, width, axis=1)

    cloud = fbm(width, SIZE, cells=12, octaves=5, seed=seed)
    mask = smoothstep(0.50, 0.82, cloud)
    envelope = smoothstep(0.04, 0.22, t) * (1.0 - smoothstep(0.46, 0.76, t))
    alpha = (mask * envelope * 0.95)[..., None]

    return image * (1 - alpha) + CLOUD[None, None, :] * alpha


def sky_up(seed):
    """Cara superior: casi plana, con nubes que se apagan antes del borde para casar."""
    image = np.ones((SIZE, SIZE, 3)) * ZENITH[None, None, :]
    cloud = fbm(SIZE, SIZE, cells=2, octaves=4, seed=seed)
    mask = smoothstep(0.52, 0.84, cloud)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float64)
    radius = np.sqrt(((xx - SIZE / 2) / (SIZE / 2)) ** 2 + ((yy - SIZE / 2) / (SIZE / 2)) ** 2)
    alpha = (mask * (1.0 - smoothstep(0.42, 0.92, radius)) * 0.6)[..., None]
    return image * (1 - alpha) + CLOUD[None, None, :] * alpha


def sky_down():
    return np.ones((SIZE, SIZE, 3)) * (HORIZON * 0.94)[None, None, :]


def limestone():
    coarse = fbm(SIZE, SIZE, cells=6, octaves=5, seed=11)
    fine = fbm(SIZE, SIZE, cells=24, octaves=3, seed=12)
    base = np.array([214.0, 210.0, 198.0])
    variation = (coarse - 0.5) * 20.0 + (fine - 0.5) * 9.0
    albedo = base[None, None, :] + variation[..., None]
    roughness = np.clip(0.60 + (coarse - 0.5) * 0.12 + (fine - 0.5) * 0.05, 0.34, 0.9)
    height = box_blur(coarse * 0.65 + fine * 0.35, 1)
    return albedo, roughness, normal_from_height(height, 2.4)


def brick():
    mortar = 7
    brick_w, brick_h = 128, 46
    cols = SIZE // brick_w
    rows = SIZE // brick_h + 1
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    row = yy // brick_h
    offset = (row % 2) * (brick_w // 2)
    local_x = (xx + offset) % brick_w
    local_y = yy % brick_h
    is_mortar = (local_x < mortar) | (local_y < mortar)

    rng = np.random.default_rng(7)
    jitter = rng.uniform(-10.0, 10.0, size=(rows + 2, cols + 2))
    column = ((xx + offset) // brick_w) % cols
    tint = jitter[(row % rows) + 1, column + 1]

    brick_color = np.array([146.0, 98.0, 84.0])
    mortar_color = np.array([186.0, 179.0, 168.0])
    albedo = np.where(
        is_mortar[..., None], mortar_color[None, None, :], brick_color[None, None, :] + tint[..., None]
    )

    grain = fbm(SIZE, SIZE, cells=32, octaves=3, seed=21)
    albedo = albedo + (grain[..., None] - 0.5) * 14.0

    roughness = np.where(is_mortar, 0.9, 0.74) + (grain - 0.5) * 0.05
    height = box_blur(np.where(is_mortar, 0.0, 1.0), 2)
    return albedo, np.clip(roughness, 0.3, 0.95), normal_from_height(height, 5.0)


def asphalt():
    patches = fbm(SIZE, SIZE, cells=8, octaves=4, seed=31)
    grain = fbm(SIZE, SIZE, cells=64, octaves=2, seed=32)
    base = np.array([74.0, 74.0, 80.0])
    variation = (patches - 0.5) * 12.0 + (grain - 0.5) * 24.0
    albedo = base[None, None, :] + variation[..., None]
    roughness = np.clip(0.82 + (patches - 0.5) * 0.08, 0.55, 0.95)
    height = box_blur(grain * 0.75 + patches * 0.25, 1)
    return albedo, roughness, normal_from_height(height, 1.4)


def grey_map(values):
    return np.stack([values * 255.0] * 3, axis=-1)


def contact_sheet(images, path):
    thumbs = []
    for image in images:
        pil = Image.fromarray(np.clip(image, 0, 255).astype(np.uint8))
        thumbs.append(pil.resize((384, 384), Image.LANCZOS))
    sheet = Image.new("RGB", (384 * len(thumbs), 384))
    for index, thumb in enumerate(thumbs):
        sheet.paste(thumb, (index * 384, 0))
    sheet.save(path)


def main():
    os.makedirs(SKY_DIR, exist_ok=True)
    os.makedirs(TEX_DIR, exist_ok=True)
    os.makedirs(RENDER_DIR, exist_ok=True)

    summary = {"skybox": {}, "textures": {}}

    panorama = sky_panorama(101)
    faces = {
        "front": panorama[:, 0:SIZE],
        "back": panorama[:, SIZE : SIZE * 2],
        "left": panorama[:, SIZE * 2 : SIZE * 3],
        "right": panorama[:, SIZE * 3 : SIZE * 4],
    }
    for name, image in faces.items():
        path = os.path.join(SKY_DIR, f"{name}.png")
        save(image, path)
        summary["skybox"][name] = path

    for name, image in (("up", sky_up(109)), ("down", sky_down())):
        path = os.path.join(SKY_DIR, f"{name}.png")
        save(image, path)
        summary["skybox"][name] = path

    for name, builder in (("limestone", limestone), ("brick", brick), ("asphalt", asphalt)):
        albedo, roughness, normal = builder()
        save(albedo, os.path.join(TEX_DIR, f"{name}_albedo.png"))
        save(grey_map(roughness), os.path.join(TEX_DIR, f"{name}_roughness.png"))
        save(normal, os.path.join(TEX_DIR, f"{name}_normal.png"))
        summary["textures"][name] = {
            "albedo": os.path.join(TEX_DIR, f"{name}_albedo.png"),
            "roughness": os.path.join(TEX_DIR, f"{name}_roughness.png"),
            "normal": os.path.join(TEX_DIR, f"{name}_normal.png"),
            "roughness_media": round(float(roughness.mean()), 3),
        }

    a_limestone, _, _ = limestone()
    a_brick, _, _ = brick()
    a_asphalt, _, _ = asphalt()
    contact_sheet(
        [faces["front"], a_limestone, a_brick, a_asphalt],
        os.path.join(RENDER_DIR, "hoja-texturas.png"),
    )

    print(json.dumps(summary, indent=2, ensure_ascii=False))


main()

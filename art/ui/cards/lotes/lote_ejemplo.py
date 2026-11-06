#!/usr/bin/env python
"""Tres cartas de ejemplo de Flip the Table: una por rareza.

`Fine` (Comun), `Strike` (Rara) y `Hurricane` (Legendaria) demuestran el sistema de
`cardlib.py`: cada pintor dibuja solo la ilustracion dentro de su `box`, con formas
planas, un unico grosor de trazo y cuatro colores de la paleta como maximo.

Regla de lenguaje: la ciudad se dibuja como una maqueta de lujo. Las ilustraciones son
cosas y senales (vallas, papeles, edificios, fenomenos), nunca personas: ni figuras,
ni manos, ni cabezas.

Todas las medidas son fracciones del ancho (`w`) y del alto (`h`) de la ventana, en
pixeles de 4x. El sujeto se apoya en el borde inferior o en el lateral, y la esquina
superior derecha queda libre para el sello de rareza.
"""
import math

try:
    from cardlib import (
        ACERO,
        ASFALTO,
        ASFALTO_PROFUNDO,
        CALIZA,
        CALIZA_APAGADA,
        CRISTAL_AZUL,
        NARANJA_OBRA,
        ROJO_SENAL,
        SS,
    )
except ImportError:  # permitir `python lotes/lote_ejemplo.py`
    import sys
    from pathlib import Path

    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from cardlib import (
        ACERO,
        ASFALTO,
        ASFALTO_PROFUNDO,
        CALIZA,
        CALIZA_APAGADA,
        CRISTAL_AZUL,
        NARANJA_OBRA,
        ROJO_SENAL,
        SS,
    )

RARITY = {"Fine": "Common", "Strike": "Rare", "Hurricane": "Legendary"}


# --------------------------------------------------------------------------- utiles


def _frame(box):
    """`box` de 1x -> `(x0, y0, w, h)` en pixeles de 4x."""
    x0, y0, x1, y1 = box
    return x0 * SS, y0 * SS, (x1 - x0) * SS, (y1 - y0) * SS


def _p(point):
    return (round(point[0]), round(point[1]))


def _rotate(points, cx, cy, degrees):
    """Gira puntos alrededor de (cx, cy); con la y hacia abajo, el angulo positivo gira
    en sentido horario y el negativo en sentido antihorario, como se lee en pantalla."""
    angle = math.radians(degrees)
    cos, sin = math.cos(angle), math.sin(angle)
    return [
        (cx + (x - cx) * cos - (y - cy) * sin, cy + (x - cx) * sin + (y - cy) * cos)
        for x, y in points
    ]


def _rect_points(cx, cy, half_w, half_h, degrees=0.0):
    corners = [
        (cx - half_w, cy - half_h),
        (cx + half_w, cy - half_h),
        (cx + half_w, cy + half_h),
        (cx - half_w, cy + half_h),
    ]
    return _rotate(corners, cx, cy, degrees) if degrees else corners


def _clip_line(points, limit, horizontal=True, keep_less=True):
    """Recorta un poligono contra una recta (Sutherland-Hodgman)."""
    out = []
    for index, point in enumerate(points):
        previous = points[index - 1]
        value = point[1] if horizontal else point[0]
        before = previous[1] if horizontal else previous[0]
        inside = value <= limit if keep_less else value >= limit
        inside_before = before <= limit if keep_less else before >= limit
        if inside:
            if not inside_before:
                t = (limit - before) / (value - before)
                out.append(
                    (
                        previous[0] + (point[0] - previous[0]) * t,
                        previous[1] + (point[1] - previous[1]) * t,
                    )
                )
            out.append(point)
        elif inside_before:
            t = (limit - before) / (value - before)
            out.append(
                (
                    previous[0] + (point[0] - previous[0]) * t,
                    previous[1] + (point[1] - previous[1]) * t,
                )
            )
    return out


def _clip_bottom(points, limit):
    return _clip_line(points, limit, horizontal=True, keep_less=True)


def _clip_box(points, left, top, right, bottom):
    """Recorta un poligono convexo contra un rectangulo."""
    for limit, horizontal, keep_less in (
        (left, False, False),
        (right, False, True),
        (top, True, False),
        (bottom, True, True),
    ):
        points = _clip_line(points, limit, horizontal, keep_less)
        if not points:
            break
    return points


def _polygon(draw, points, fill, outline=None, width=0):
    """Poligono plano, con filete centrado en su borde si se pide."""
    points = [(round(x), round(y)) for x, y in points]
    if len(points) < 3:
        return
    draw.polygon(points, fill=fill)
    if outline is not None and width:
        draw.line(points + [points[0]], fill=outline, width=max(1, round(width)),
                  joint="curve")


def _disc(draw, centre, radius, fill):
    cx, cy = centre
    draw.ellipse(
        [round(cx - radius), round(cy - radius), round(cx + radius), round(cy + radius)],
        fill=fill,
    )


def _bar(draw, start, end, width, fill):
    """Barra gruesa con las dos puntas redondas."""
    radius = width / 2.0
    draw.line([_p(start), _p(end)], fill=fill, width=max(1, round(width)))
    _disc(draw, start, radius, fill)
    _disc(draw, end, radius, fill)


def _fill_rect(draw, x, y, width, height, fill):
    draw.rectangle(
        [round(x), round(y), round(x + width) - 1, round(y + height) - 1], fill=fill
    )


def _quad(start, control, end, steps=40):
    points = []
    for index in range(steps + 1):
        t = index / steps
        u = 1.0 - t
        points.append(
            (
                u * u * start[0] + 2 * u * t * control[0] + t * t * end[0],
                u * u * start[1] + 2 * u * t * control[1] + t * t * end[1],
            )
        )
    return points


def _placed(cx, cy, degrees, lx, ly):
    """Punto del sistema girado de un rectangulo: centro + desplazamiento local."""
    angle = math.radians(degrees)
    cos, sin = math.cos(angle), math.sin(angle)
    return (cx + lx * cos - ly * sin, cy + lx * sin + ly * cos)


def _rect_local(cx, cy, degrees, lx, ly, width, height):
    """Rectangulo de `width` x `height` centrado en el punto local (lx, ly)."""
    half_w, half_h = width / 2.0, height / 2.0
    corners = [
        (-half_w, -half_h),
        (half_w, -half_h),
        (half_w, half_h),
        (-half_w, half_h),
    ]
    return [_placed(cx, cy, degrees, lx + x, ly + y) for x, y in corners]


def _smoothstep(value):
    value = min(1.0, max(0.0, value))
    return value * value * (3.0 - 2.0 * value)


# --------------------------------------------------------------------------- Multa


def paint_fine(draw, box):
    """Parquimetro a la izquierda y papel de multa atravesado a la derecha.

    Cuatro colores: acero en el fondo, asfalto en poste, base, anillo y bordes, caliza
    en cabeza, papel y aspa, y rojo senal en la franja y el sello.
    """
    x0, y0, w, h = _frame(box)
    draw.rectangle(
        [round(x0), round(y0), round(x0 + w) - 1, round(y0 + h) - 1], fill=ACERO
    )

    # --- parquimetro: poste, base y cabeza redonda.
    head_cx, head_cy = x0 + 0.200 * w, y0 + 0.280 * h
    head_r = 0.180 * w
    ring = 0.030 * w
    post_w = 0.070 * w
    _fill_rect(draw, head_cx - post_w / 2, head_cy, post_w, (y0 + h) - head_cy, ASFALTO)
    base_w, base_h = 0.160 * w, 0.050 * h
    _fill_rect(draw, head_cx - base_w / 2, y0 + h - base_h, base_w, base_h, ASFALTO)
    _disc(draw, (head_cx, head_cy), head_r, ASFALTO)
    _disc(draw, (head_cx, head_cy), head_r - ring, CALIZA)

    # --- esfera, aguja y ranura.
    _disc(draw, (head_cx, head_cy), 0.130 * w, CALIZA_APAGADA)
    needle = math.radians(-40.0)
    _bar(
        draw,
        (head_cx, head_cy),
        (head_cx + math.cos(needle) * 0.100 * w, head_cy + math.sin(needle) * 0.100 * w),
        0.050 * w,
        NARANJA_OBRA,
    )
    slot_w, slot_h = 0.020 * w, 0.060 * h
    _fill_rect(
        draw,
        head_cx + head_r - ring - slot_w - 0.004 * w,
        head_cy - slot_h / 2,
        slot_w,
        slot_h,
        ASFALTO,
    )

    # --- papel de multa, de frente y torcido.
    paper_cx, paper_cy = x0 + 0.520 * w, y0 + 0.550 * h
    paper_w, paper_h = 0.660 * w, 0.260 * h
    paper_angle = -12.0
    border = 0.025 * w
    _polygon(
        draw,
        _rect_points(paper_cx, paper_cy, paper_w / 2, paper_h / 2, paper_angle),
        CALIZA,
        ASFALTO,
        border,
    )
    # Franja roja pegada al borde superior, dentro del filete.
    stripe_h = 0.030 * h
    _polygon(
        draw,
        _rect_local(
            paper_cx,
            paper_cy,
            paper_angle,
            0.0,
            -paper_h / 2 + border / 2 + stripe_h / 2,
            paper_w - border,
            stripe_h,
        ),
        ROJO_SENAL,
    )

    # --- sello cuadrado en el extremo derecho, girado al contrario que el papel.
    stamp_half = 0.060 * w
    stamp_cx, stamp_cy = _placed(paper_cx, paper_cy, paper_angle, 0.255 * w, 0.004 * h)
    stamp = _rect_points(stamp_cx, stamp_cy, stamp_half, stamp_half, 12.0)
    _polygon(draw, stamp, ROJO_SENAL)
    draw.line([_p(stamp[0]), _p(stamp[2])], fill=CALIZA, width=round(0.020 * w))
    draw.line([_p(stamp[1]), _p(stamp[3])], fill=CALIZA, width=round(0.020 * w))


# -------------------------------------------------------------------- Valla de obra


def _stripes(draw, left, top, right, bottom, w, colour):
    """Franjas a 45 grados dentro del tablero, recortadas a su rectangulo."""
    thickness = 0.075 * w
    spacing = 0.110 * w
    diagonal = math.hypot(right - left, bottom - top) * 1.6
    centre_x, centre_y = (left + right) / 2.0, (top + bottom) / 2.0
    axis = math.sqrt(0.5)
    step = int(math.ceil(max(right - left, bottom - top) / spacing)) + 3
    for index in range(-step, step + 1):
        offset = index * spacing
        stripe_cx = centre_x + offset * axis
        stripe_cy = centre_y - offset * axis
        stripe = _rect_points(stripe_cx, stripe_cy, diagonal / 2, thickness / 2, 45.0)
        _polygon(draw, _clip_box(stripe, left, top, right, bottom), colour)


def _cone(draw, centre_x, base_y, width, height, colour, band):
    """Cono de obra: triangulo con banda clara, como el icono `cone`."""
    half_base = width / 2.0
    half_top = width * 0.075
    top_y = base_y - height

    def half_width_at(y):
        t = (base_y - y) / height
        return half_base + (half_top - half_base) * t

    _polygon(
        draw,
        [
            (centre_x - half_base, base_y),
            (centre_x + half_base, base_y),
            (centre_x + half_top, top_y),
            (centre_x - half_top, top_y),
        ],
        colour,
    )
    band_top = top_y + height * 0.30
    band_bottom = top_y + height * 0.52
    upper, lower = half_width_at(band_top), half_width_at(band_bottom)
    _polygon(
        draw,
        [
            (centre_x - upper, band_top),
            (centre_x + upper, band_top),
            (centre_x + lower, band_bottom),
            (centre_x - lower, band_bottom),
        ],
        band,
    )


def paint_strike(draw, box):
    """Valla de obra de frente: el trabajo parado, sin una sola persona."""
    x0, y0, w, h = _frame(box)
    draw.rectangle(
        [round(x0), round(y0), round(x0 + w) - 1, round(y0 + h) - 1], fill=CRISTAL_AZUL
    )

    board_left, board_right = x0 + 0.130 * w, x0 + 0.870 * w
    board_top, board_bottom = y0 + 0.340 * h, y0 + 0.580 * h
    border = 0.030 * w
    ground = y0 + 0.920 * h

    # --- patas en A: dos barras cruzadas bajo el tablero y un travesano.
    for leg_x in (0.220, 0.780):
        cx = x0 + leg_x * w
        _bar(draw, (cx - 0.055 * w, ground), (cx + 0.042 * w, board_bottom - 0.010 * h),
             0.050 * w, ASFALTO)
        _bar(draw, (cx + 0.055 * w, ground), (cx - 0.042 * w, board_bottom - 0.010 * h),
             0.050 * w, ASFALTO)
    _bar(
        draw,
        (x0 + 0.220 * w, y0 + 0.800 * h),
        (x0 + 0.780 * w, y0 + 0.800 * h),
        0.040 * w,
        ASFALTO,
    )

    # --- tablero: caliza, franjas de naranja recortadas y filete de asfalto encima.
    _fill_rect(
        draw, board_left, board_top, board_right - board_left,
        board_bottom - board_top, CALIZA,
    )
    _stripes(draw, board_left + border / 2, board_top + border / 2,
             board_right - border / 2, board_bottom - border / 2, w, NARANJA_OBRA)
    draw.rectangle(
        [round(board_left), round(board_top), round(board_right), round(board_bottom)],
        outline=ASFALTO,
        width=round(border),
    )

    # --- suelo: banda de asfalto a sangre que tapa los pies de las patas.
    _fill_rect(draw, x0, ground, w, (y0 + h) - ground, ASFALTO)

    # --- detalle: un cono de obra sobre el suelo, a la derecha.
    _cone(
        draw,
        x0 + 0.840 * w,
        ground,
        0.100 * w,
        0.120 * h,
        NARANJA_OBRA,
        CALIZA,
    )


# --------------------------------------------------------------------------- Huracan

#: Bloques de ciudad: centro x, ancho, alto y giro, todos apoyados en el borde inferior.
_BLOCKS = (
    (0.108, 0.210, 0.250, -6.0),
    (0.347, 0.190, 0.190, 5.0),
    (0.604, 0.230, 0.300, -3.0),
    (0.875, 0.210, 0.230, 7.0),
)


def paint_hurricane(draw, box):
    """Huracan: espiral de viento, ojo, ciudad de acero y rachas que entran por la izquierda."""
    x0, y0, w, h = _frame(box)
    draw.rectangle(
        [round(x0), round(y0), round(x0 + w) - 1, round(y0 + h) - 1],
        fill=ASFALTO_PROFUNDO,
    )

    cx, cy = x0 + 0.500 * w, y0 + 0.460 * h
    trazo = 0.060 * w

    # --- rachas cortas a la altura del ojo, entrando por la izquierda.
    for y_t, largo, comba in (
        (0.385, 0.115, -0.010),
        (0.460, 0.145, 0.008),
        (0.535, 0.100, -0.007),
    ):
        y_trazo = y0 + y_t * h
        path = _quad(
            (x0, y_trazo),
            (x0 + largo * w * 0.5, y_trazo + comba * h),
            (x0 + largo * w, y_trazo),
        )
        draw.line(
            [_p(point) for point in path],
            fill=CALIZA,
            width=round(0.040 * w),
            joint="curve",
        )
        _disc(draw, path[-1], 0.020 * w, CALIZA)

    # --- espiral de dos vueltas y media. El radio crece de 0,08 a 0,40 W y en el
    #     ultimo tramo se abre hasta el borde derecho: el brazo sale del cuadro por
    #     debajo del sello, sin bola y sin volver hacia abajo.
    turns, r_in, r_out = 2.5, 0.080 * w, 0.400 * w
    r_end = (x0 + w - 1 - trazo / 2.0 - 1.0) - cx
    ellipse = h / w
    steps = 720
    points = []
    for index in range(steps + 1):
        t = index / steps
        theta = 2.0 * math.pi * turns * (1.0 - t)
        radius = r_in + (r_out - r_in) * t
        if t > 0.840:
            radius += (r_end - r_out) * _smoothstep((t - 0.840) / 0.160)
        points.append(
            (
                cx + radius * math.cos(theta),
                cy + radius * ellipse * math.sin(theta),
            )
        )

    draw.line(
        [(round(x), round(y)) for x, y in points],
        fill=CALIZA,
        width=round(trazo),
        joint="curve",
    )

    # --- ojo: disco de caliza con el punto de asfalto profundo.
    _disc(draw, (cx, cy), r_in, CALIZA)
    _disc(draw, (cx, cy), 0.030 * w, ASFALTO_PROFUNDO)

    # --- ciudad: cuatro bloques sueltos de acero, apoyados en el borde inferior.
    contour = 0.020 * w
    base = y0 + h - 1 - contour / 2.0
    for cx_t, bw, bh, angle in _BLOCKS:
        block_cx = x0 + cx_t * w
        block_cy = base - bh * h / 2.0
        corners = _rect_points(block_cx, block_cy, bw * w / 2.0, bh * h / 2.0, angle)
        corners = _clip_bottom(corners, base)
        if len(corners) < 3:
            continue
        _polygon(draw, corners, ACERO, ASFALTO, contour)
        # Dos ventanas de asfalto profundo por bloque, a la misma altura.
        for lx_t in (-0.20, 0.20):
            window = _rect_local(
                block_cx,
                block_cy,
                angle,
                lx_t * bw * w,
                -0.06 * bh * h,
                0.030 * w,
                0.055 * h,
            )
            window = [point for point in window if point[1] <= base]
            if len(window) >= 3:
                _polygon(draw, window, ASFALTO_PROFUNDO)


PAINTERS = {"Fine": paint_fine, "Strike": paint_strike, "Hurricane": paint_hurricane}

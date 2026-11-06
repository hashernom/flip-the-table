#!/usr/bin/env python
"""Las cuatro cartas legendarias de Flip the Table.

`WorldFlip`, `Revolution`, `Earthquake` y `CrownStrike` son las cuatro cartas que
mandan en el mazo: se dibujan con el mismo lenguaje que las tres aprobadas (formas
planas, un solo grosor de trazo, cuatro colores de la paleta como maximo) y con la
misma exigencia: tienen que leerse a 95 x 95 px.

Regla de lenguaje: cosas y senales, nunca personas. Nada de figuras, cabezas ni manos.

Todo se mide en fracciones del ancho (`w`) y del alto (`h`) de la ventana, en pixeles
de 4x. El trazo es unico para las cuatro: 40 px de 4x, que son 10 px a tamano final.
La esquina superior derecha de la ventana (0,72-1,00 del ancho x 0-0,28 del alto) se
deja libre para el sello de rareza.
"""
import math

try:
    from cardlib import (
        ACERO,
        ASFALTO,
        ASFALTO_PROFUNDO,
        CALIZA,
        NARANJA_OBRA,
        ORO,
        ROJO_SENAL,
        SS,
    )
except ImportError:  # permitir `python lotes/lote_legendarias.py`
    import sys
    from pathlib import Path

    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from cardlib import (
        ACERO,
        ASFALTO,
        ASFALTO_PROFUNDO,
        CALIZA,
        NARANJA_OBRA,
        ORO,
        ROJO_SENAL,
        SS,
    )

#: Las cuatro cartas son legendarias: el lote entero comparte rareza.
RARITY = {
    "WorldFlip": "Legendary",
    "Revolution": "Legendary",
    "Earthquake": "Legendary",
    "CrownStrike": "Legendary",
}

#: Nombres en espanol para la hoja de contacto.
LABELS = {
    "WorldFlip": "Mundo al Rev\u00e9s",
    "Revolution": "Revoluci\u00f3n",
    "Earthquake": "Terremoto",
    "CrownStrike": "Golpe a la Corona",
}

#: Grosor unico del lote, en pixeles de 4x: 10 px a tamano final.
STROKE = 40


# --------------------------------------------------------------------------- utiles


def _frame(box):
    """`box` de 1x -> `(x0, y0, w, h)` en pixeles de 4x."""
    x0, y0, x1, y1 = box
    return x0 * SS, y0 * SS, (x1 - x0) * SS, (y1 - y0) * SS


def _p(point):
    return (round(point[0]), round(point[1]))


def _rotate(points, cx, cy, degrees):
    """Gira puntos alrededor de (cx, cy); con la y hacia abajo, el angulo positivo gira
    en sentido horario, como se lee en pantalla."""
    angle = math.radians(degrees)
    cos, sin = math.cos(angle), math.sin(angle)
    return [
        (cx + (x - cx) * cos - (y - cy) * sin, cy + (x - cx) * sin + (y - cy) * cos)
        for x, y in points
    ]


def _polygon(draw, points, fill, outline=ASFALTO, width=STROKE):
    """Poligono plano con filete centrado en su borde."""
    pts = [_p(point) for point in points]
    if len(pts) < 3:
        return
    draw.polygon(pts, fill=fill)
    if outline is not None and width:
        draw.line(
            pts + [pts[0], pts[1]],
            fill=outline,
            width=max(1, round(width)),
            joint="curve",
        )


def _stroke(draw, points, fill, width=STROKE):
    """Linea gruesa abierta, con las juntas redondeadas."""
    draw.line(
        [_p(point) for point in points],
        fill=fill,
        width=max(1, round(width)),
        joint="curve",
    )


def _fill(draw, x, y, width, height, fill):
    draw.rectangle(
        [round(x), round(y), round(x + width) - 1, round(y + height) - 1], fill=fill
    )


def _polar(cx, cy, radius, degrees):
    angle = math.radians(degrees)
    return (cx + radius * math.cos(angle), cy + radius * math.sin(angle))


# --------------------------------------------------------------- Mundo al Reves

#: La franja que separa los dos mundos, en fracciones del alto: el eje del dibujo.
HORIZON = 0.500
HORIZON_HALF = 0.030

#: La ciudad de arriba, en fracciones de `w` y `h`: `(izq, der, alto, ventanas)`. Los de
#: abajo son su reflejo exacto sobre la franja: el bloque alto de la izquierda reaparece
#: abajo a la derecha, boca abajo, colgando de la misma linea.
_WORLD_BLOCKS = (
    (0.040, 0.255, 0.330, 2),
    (0.320, 0.455, 0.160, 1),
    (0.515, 0.700, 0.255, 2),
    (0.775, 0.955, 0.110, 1),
)


def _block(draw, x0, y0, w, h, left, right, alto, windows, up, fill):
    """Un bloque de ciudad, derecho o colgando, con sus ventanas cuadradas."""
    base = y0 + (HORIZON + (-HORIZON_HALF if up else HORIZON_HALF)) * h
    sign = -1.0 if up else 1.0
    roof = base + sign * alto * h
    l, r = x0 + left * w, x0 + right * w

    _polygon(draw, [(l, base), (r, base), (r, roof), (l, roof)], fill)

    # Ventanas: cuadradas y pegadas al techo. Al espejarse el bloque de abajo las lleva
    # al pie de la ventana, que es donde tiene el techo un edificio boca abajo.
    body_px = alto * h
    win_w = 0.046 * w
    win_h = min(0.062 * h, 0.30 * body_px)
    gap = 0.028 * w
    total = windows * win_w + (windows - 1) * gap
    win_x = (l + r) / 2.0 - total / 2.0
    rows = 2 if alto >= 0.24 else 1
    step = 0.30 * body_px
    for row in range(rows):
        offset = 0.18 * body_px + row * step
        win_y = roof + offset if up else roof - offset - win_h
        for index in range(windows):
            _fill(
                draw,
                win_x + index * (win_w + gap),
                win_y,
                win_w,
                win_h,
                ASFALTO_PROFUNDO,
            )


def paint_world_flip(draw, box):
    """Mundo al Reves: la ciudad partida por una linea de horizonte.

    Arriba, cuatro bloques de caliza derechos; abajo, los mismos bloques en acero,
    espejados y boca abajo, colgando de la misma franja. La franja es la unica linea
    limpia del dibujo: el eje sobre el que el mundo se da la vuelta.
    """
    x0, y0, w, h = _frame(box)
    draw.rectangle(
        [round(x0), round(y0), round(x0 + w) - 1, round(y0 + h) - 1],
        fill=ASFALTO_PROFUNDO,
    )

    _fill(draw, x0, y0 + (HORIZON - HORIZON_HALF) * h, w, 2.0 * HORIZON_HALF * h, CALIZA)

    for left, right, alto, windows in _WORLD_BLOCKS:
        _block(draw, x0, y0, w, h, left, right, alto, windows, True, CALIZA)
    for left, right, alto, windows in reversed(_WORLD_BLOCKS):
        _block(draw, x0, y0, w, h, 1.0 - right, 1.0 - left, alto, windows, False, ACERO)


# ------------------------------------------------------------------------ Revolucion

#: El bucle: dos flechas de naranja obra que se persiguen, cada una con su cabeza de
#: caliza y un corte entre la punta de una y la cola de la siguiente. Angulos en grados.
_REV_TAIL = 14.0
_REV_BODY = 96.0
_REV_HEAD_LEN = 42.0
_REV_TAIL_SKEW = 12.0


def _arrow_body(cx, cy, r_out, thickness, start):
    """Galon de naranja: el cuerpo de la flecha, cortado en diagonal por la cola."""
    r_in = r_out - thickness
    tail, head = start, start + _REV_BODY
    steps = 72
    points = [
        _polar(cx, cy, r_out, tail + (head - tail) * i / steps) for i in range(steps + 1)
    ]
    points += [
        _polar(cx, cy, r_in, head + (tail - _REV_TAIL_SKEW - head) * i / steps)
        for i in range(steps + 1)
    ]
    return points


def _arrow_head(cx, cy, r_out, thickness, head):
    """Galon de caliza: la punta de la flecha, mas ancha que el cuerpo."""
    r_in = r_out - thickness
    barb = 0.35 * thickness
    mid = r_out - thickness / 2.0
    return [
        _polar(cx, cy, r_out, head),
        _polar(cx, cy, r_out + barb, head),
        _polar(cx, cy, mid, head + _REV_HEAD_LEN),
        _polar(cx, cy, r_in - barb, head),
        _polar(cx, cy, r_in, head),
    ]


def paint_revolution(draw, box):
    """Revolucion: los galones en bucle cerrado.

    Dos flechas gruesas se persiguen por un anillo con un corte entre la punta y la cola
    de cada una: el cuerpo va en naranja obra y la cabeza en caliza, para que la vuelta
    se lea de un golpe.
    """
    x0, y0, w, h = _frame(box)
    draw.rectangle(
        [round(x0), round(y0), round(x0 + w) - 1, round(y0 + h) - 1],
        fill=ASFALTO_PROFUNDO,
    )

    cx, cy = x0 + 0.500 * w, y0 + 0.512 * h
    r_out = 0.372 * w
    thickness = 0.148 * w

    for half in (0.0, 180.0):
        start = _REV_TAIL + half
        _polygon(draw, _arrow_body(cx, cy, r_out, thickness, start), NARANJA_OBRA)
        _polygon(
            draw,
            _arrow_head(cx, cy, r_out, thickness, start + _REV_BODY),
            CALIZA,
        )


# ------------------------------------------------------------------------- Terremoto

#: Eje de la grieta, de arriba abajo, en fracciones del ancho y del alto de la ventana.
#: Cae en diagonal, con dientes largos: asi las dos mitades no son dos rectangulos.
_QUAKE_CRACK = (
    (0.600, 0.150),
    (0.542, 0.250),
    (0.568, 0.340),
    (0.488, 0.445),
    (0.514, 0.535),
    (0.444, 0.640),
    (0.468, 0.735),
    (0.396, 0.850),
)
#: Bordes del bloque y desplazamiento vertical de cada mitad.
_QUAKE_LEFT, _QUAKE_RIGHT = 0.090, 0.910
_QUAKE_TOP, _QUAKE_BOTTOM = 0.150, 0.850
_QUAKE_SHIFT = 0.045
#: Media anchura de la grieta: separa los dos bordes que dibuja el asfalto.
_QUAKE_GAP = 0.024

#: Cascotes de acero: (centro x, centro y, radio, lados, giro) en fracciones de w/h.
_QUAKE_RUBBLE = (
    (0.150, 0.882, 0.068, 3, 12.0),
    (0.308, 0.908, 0.050, 4, -24.0),
    (0.648, 0.896, 0.056, 3, 40.0),
    (0.828, 0.884, 0.046, 4, -14.0),
    (0.372, 0.780, 0.040, 3, 26.0),
)


def _chip(centre, radius, sides, degrees):
    points = [
        (centre[0] + radius * math.cos(math.radians(360.0 * i / sides + 20.0)),
         centre[1] + radius * math.sin(math.radians(360.0 * i / sides + 20.0)))
        for i in range(sides)
    ]
    return _rotate(points, centre[0], centre[1], degrees)


def paint_earthquake(draw, box):
    """Terremoto: dos mitades del mismo bloque, desplazadas en vertical.

    El bloque de caliza se parte por una grieta en diagonal de asfalto: la mitad
    izquierda sube, la derecha baja y entre las dos queda la costura abierta, con las
    hileras de ventanas descuadradas. Al pie, los cascotes de acero del golpe.
    """
    x0, y0, w, h = _frame(box)
    draw.rectangle(
        [round(x0), round(y0), round(x0 + w) - 1, round(y0 + h) - 1],
        fill=ASFALTO_PROFUNDO,
    )

    def fx(value):
        return x0 + value * w

    def fy(value):
        return y0 + value * h

    # 1. La costura de asfalto, bajo las dos mitades: solo asoma por la grieta.
    _stroke(
        draw,
        [(fx(px), fy(py)) for px, py in _QUAKE_CRACK],
        ASFALTO,
        width=2.0 * _QUAKE_GAP * w + STROKE,
    )

    # 2. Las dos mitades, cada una con su borde pegado a un lado de la grieta.
    left_edge = [(fx(px - _QUAKE_GAP), fy(py)) for px, py in _QUAKE_CRACK]
    right_edge = [(fx(px + _QUAKE_GAP), fy(py)) for px, py in _QUAKE_CRACK]
    shift = _QUAKE_SHIFT * h

    left_piece = (
        [(fx(_QUAKE_LEFT), fy(_QUAKE_TOP))]
        + left_edge
        + [(fx(_QUAKE_LEFT), fy(_QUAKE_BOTTOM))]
    )
    right_piece = (
        right_edge
        + [(fx(_QUAKE_RIGHT), fy(_QUAKE_BOTTOM))]
        + [(fx(_QUAKE_RIGHT), fy(_QUAKE_TOP))]
    )
    _polygon(draw, [(x, y - shift) for x, y in left_piece], CALIZA)
    _polygon(draw, [(x, y + shift) for x, y in right_piece], CALIZA)

    # 3. Ventanas: el bloque es un bloque de ciudad, y al desplazarse las dos mitades
    #    las hileras dejan de coincidir, que es lo que cuenta el dibujo.
    window_w, window_h = 0.050 * w, 0.062 * h
    for origin_y in (0.255, 0.560):
        for left_x in (0.190, 0.315):
            _fill(draw, fx(left_x), fy(origin_y) - shift, window_w, window_h,
                  ASFALTO_PROFUNDO)
        for right_x in (0.660, 0.785):
            _fill(draw, fx(right_x), fy(origin_y) + shift, window_w, window_h,
                  ASFALTO_PROFUNDO)

    # 4. Cascotes de acero: los del suelo y los que saltan de la grieta.
    for cx_t, cy_t, radius, sides, degrees in _QUAKE_RUBBLE:
        _polygon(draw, _chip((fx(cx_t), fy(cy_t)), radius * w, sides, degrees), ACERO)


# ------------------------------------------------------------------ Golpe a la Corona

#: Contorno de la corona en coordenadas locales: 1 de ancho, la banda abajo y tres
#: puntas. La derecha esta rota: no acaba en aguja, se abre en dos dientes cortos.
_CROWN_OUTLINE = (
    (-0.500, 0.450),
    (0.500, 0.450),
    (0.500, 0.200),
    (0.460, 0.200),
    (0.452, -0.060),
    (0.418, -0.150),
    (0.392, -0.050),
    (0.352, -0.130),
    (0.240, 0.200),
    (0.120, 0.200),
    (0.000, -0.560),
    (-0.120, 0.200),
    (-0.240, 0.200),
    (-0.420, -0.360),
    (-0.460, 0.200),
    (-0.500, 0.200),
)
#: Giro de la corona, volcada hacia la derecha, y su centro en la ventana.
_CROWN_ANGLE = 30.0
_CROWN_CENTRE = (0.527, 0.540)
_CROWN_WIDTH = 0.620
#: Proporcion de la corona: mas ancha que alta, como una corona de verdad.
_CROWN_RATIO = 0.860
#: Linea de la banda, en coordenadas locales de la corona.
_CROWN_BAND = (-0.360, 0.320, 0.360, 0.320)

#: Estallido de impacto: centro, radio exterior, radio interior y numero de puntas.
_BURST_CENTRE = (0.352, 0.420)
_BURST_OUTER = 0.300
_BURST_INNER = 0.186
_BURST_SPIKES = 10
_BURST_PHASE = 6.0


def _burst(cx, cy, outer, inner, spikes, phase):
    """Estrella de puntas alternas: el golpe, detras de la corona."""
    points = []
    for index in range(spikes * 2):
        radius = outer if index % 2 == 0 else inner
        angle = math.radians(phase + 180.0 * index / spikes)
        points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    return points


def paint_crown_strike(draw, box):
    """Golpe a la Corona: la corona de oro, volcada, sobre el estallido del impacto.

    El estallido de rojo senal queda detras y a la izquierda; la corona cae hacia la
    derecha con una punta astillada, para que el golpe se lea en la direccion en la que
    se ha ido.
    """
    x0, y0, w, h = _frame(box)
    draw.rectangle(
        [round(x0), round(y0), round(x0 + w) - 1, round(y0 + h) - 1],
        fill=ASFALTO_PROFUNDO,
    )

    # 1. Estallido: estrella plana de rojo senal, sin filete; el rojo ya corta solo.
    _polygon(
        draw,
        _burst(
            x0 + _BURST_CENTRE[0] * w,
            y0 + _BURST_CENTRE[1] * h,
            _BURST_OUTER * w,
            _BURST_INNER * w,
            _BURST_SPIKES,
            _BURST_PHASE,
        ),
        ROJO_SENAL,
        outline=None,
    )

    # 2. Corona: se dibuja plana en su sistema y se gira y coloca de una vez.
    width = _CROWN_WIDTH * w
    height = width * _CROWN_RATIO
    cx, cy = x0 + _CROWN_CENTRE[0] * w, y0 + _CROWN_CENTRE[1] * h

    def place(px, py):
        return (cx + px * width, cy + py * height)

    crown = _rotate([place(px, py) for px, py in _CROWN_OUTLINE], cx, cy, _CROWN_ANGLE)
    _polygon(draw, crown, ORO)

    # 3. La banda: un trazo de asfalto que separa la base de las puntas.
    band = _rotate(
        [place(_CROWN_BAND[0], _CROWN_BAND[1]), place(_CROWN_BAND[2], _CROWN_BAND[3])],
        cx,
        cy,
        _CROWN_ANGLE,
    )
    _stroke(draw, band, ASFALTO)


PAINTERS = {
    "WorldFlip": paint_world_flip,
    "Revolution": paint_revolution,
    "Earthquake": paint_earthquake,
    "CrownStrike": paint_crown_strike,
}

#!/usr/bin/env python
"""Las cuatro cartas legendarias de Flip the Table.

`WorldFlip`, `Revolution`, `Earthquake` y `CrownStrike` son las cuatro cartas que
mandan en el mazo: se dibujan con el mismo lenguaje que las tres aprobadas (formas
planas, un solo grosor de trazo, cuatro colores de la paleta como maximo) y con la
misma exigencia: tienen que leerse a 95 x 95 px.

Regla de lenguaje: cosas y senales, nunca personas. Nada de figuras, cabezas ni manos.

Todo se mide en fracciones del ancho (`w`) y del alto (`h`) de la ventana, en pixeles
de 4x. El trazo es unico para las cuatro: 24 px de 4x, que son 6 px a tamano final, el
mismo `TRAZO` de `cardlib.py` que llevan las tres aprobadas. La esquina superior derecha
de la ventana (0,72-1,00 del ancho x 0-0,28 del alto) se deja libre para el sello de
rareza.
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

#: Grosor unico del lote, en pixeles de 4x: 6 px a tamano final (el `TRAZO` de cardlib).
STROKE = 24


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


def _polygon(draw, points, fill, outline=ASFALTO, width=STROKE, inner=None, inner_fill=None):
    """Poligono plano con filete centrado en su borde.

    `inner` es una lista de puntos que se rellena de `inner_fill` encima del relleno y
    debajo del filete: sirve para dar color a una parte de la forma sin abrirle un
    filete interior, que dejaria costura.
    """
    pts = [_p(point) for point in points]
    if len(pts) < 3:
        return
    draw.polygon(pts, fill=fill)
    if inner is not None and inner_fill is not None:
        inside = [_p(point) for point in inner]
        if len(inside) >= 3:
            draw.polygon(inside, fill=inner_fill)
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

#: El bucle: dos flechas de naranja obra que se persiguen. Cada flecha es un solo
#: poligono -cuerpo y punta juntos- con un solo filete por fuera; la punta va en caliza
#: rellena dentro del mismo poligono, sin filete interior. Angulos en grados.
_REV_CENTRE = (0.500, 0.500)
_REV_RADIUS = 0.400
_REV_THICK = 0.146
_REV_TAIL = 2.0
_REV_BODY = 106.0
_REV_HEAD = 46.0
_REV_BARB = 0.460
_REV_SKEW = 12.0
_REV_STEPS = 96


def _arrow(cx, cy, r_out, thickness, start):
    """Una flecha entera: el galon del cuerpo y la punta, en un solo poligono.

    El cuerpo recorre el anillo desde `start` a `start + _REV_BODY`. La punta sigue en
    el mismo borde -no hay corte ni segundo poligono-, sobresale `_REV_BARB` del grosor
    por cada lado para que se lean las barbas y acaba en aguja `_REV_HEAD` grados mas
    alla. La cola interior se adelanta `_REV_SKEW` grados, que corta el galon en
    diagonal.
    """
    r_in = r_out - thickness
    head = start + _REV_BODY
    mid = r_out - thickness / 2.0
    outer = r_out + _REV_BARB * thickness
    inner = r_in - _REV_BARB * thickness
    points = [
        _polar(cx, cy, r_out, start + _REV_BODY * i / _REV_STEPS)
        for i in range(_REV_STEPS + 1)
    ]
    points.append(_polar(cx, cy, outer, head))
    points.append(_polar(cx, cy, mid, head + _REV_HEAD))
    points.append(_polar(cx, cy, inner, head))
    points += [
        _polar(cx, cy, r_in, head + (start - _REV_SKEW - head) * i / _REV_STEPS)
        for i in range(_REV_STEPS + 1)
    ]
    return points


def _arrow_tip(cx, cy, r_out, thickness, start):
    """La punta de caliza: el triangulo de la cabeza, relleno dentro del poligono.

    No lleva filete propio: el del poligono la envuelve entera. Su base cae dentro del
    cuerpo, asi que del triangulo solo asoma la cara.
    """
    head = start + _REV_BODY
    mid = r_out - thickness / 2.0
    return [
        _polar(cx, cy, r_out + _REV_BARB * thickness, head),
        _polar(cx, cy, mid, head + _REV_HEAD),
        _polar(cx, cy, r_out - thickness - _REV_BARB * thickness, head),
    ]


def paint_revolution(draw, box):
    """Revolucion: los galones en bucle cerrado.

    Dos flechas gruesas se persiguen por un anillo con un corte entre la punta y la cola
    de cada una: el cuerpo va en naranja obra y la punta en caliza, rellena dentro del
    mismo poligono. Un solo filete por flecha, el de su contorno.
    """
    x0, y0, w, h = _frame(box)
    draw.rectangle(
        [round(x0), round(y0), round(x0 + w) - 1, round(y0 + h) - 1],
        fill=ASFALTO_PROFUNDO,
    )

    cx, cy = x0 + _REV_CENTRE[0] * w, y0 + _REV_CENTRE[1] * h
    r_out = _REV_RADIUS * w
    thickness = _REV_THICK * w

    for half in (0.0, 180.0):
        start = _REV_TAIL + half
        _polygon(
            draw,
            _arrow(cx, cy, r_out, thickness, start),
            NARANJA_OBRA,
            inner=_arrow_tip(cx, cy, r_out, thickness, start),
            inner_fill=CALIZA,
        )


# ------------------------------------------------------------------------- Terremoto

#: Eje de la grieta, de arriba abajo, en fracciones del ancho y del alto de la ventana.
#: Cae en diagonal, con dientes largos: asi las dos mitades no son dos rectangulos.
_QUAKE_CRACK = (
    (0.600, 0.245),
    (0.520, 0.350),
    (0.570, 0.430),
    (0.470, 0.545),
    (0.520, 0.620),
    (0.420, 0.740),
    (0.450, 0.850),
)
#: Bordes del bloque y desplazamiento vertical de cada mitad: la derecha cae el doble de
#: lo que sube la izquierda, y de ahi sale el escalon. Con el desplazamiento, el borde de
#: arriba de la mitad derecha cae en 0,325 del alto: la banda de 0,72-1,00 x 0-0,28, que
#: es la del sello, queda limpia.
_QUAKE_LEFT, _QUAKE_RIGHT = 0.090, 0.910
_QUAKE_TOP, _QUAKE_BOTTOM = 0.245, 0.850
_QUAKE_SHIFT = 0.080
#: Media anchura de la grieta: separa los dos bordes que dibuja el asfalto.
_QUAKE_GAP = 0.024

#: Hileras de ventanas, en fracciones del alto del bloque desde su borde de arriba.
_QUAKE_ROWS = (0.150, 0.500)
#: Columnas de ventanas de la mitad izquierda y de la derecha, en fracciones del ancho.
_QUAKE_COLUMNS = ((0.190, 0.315), (0.660, 0.785))

#: Cascotes de acero: (centro x, centro y, radio, lados, giro) en fracciones de w/h.
_QUAKE_RUBBLE = (
    (0.150, 0.895, 0.066, 3, 12.0),
    (0.300, 0.920, 0.048, 4, -24.0),
    (0.640, 0.912, 0.054, 3, 40.0),
    (0.828, 0.896, 0.044, 4, -14.0),
    (0.372, 0.790, 0.038, 3, 26.0),
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
    block_h = _QUAKE_BOTTOM - _QUAKE_TOP
    for row in _QUAKE_ROWS:
        origin_y = _QUAKE_TOP + row * block_h
        for left_x in _QUAKE_COLUMNS[0]:
            _fill(draw, fx(left_x), fy(origin_y) - shift, window_w, window_h,
                  ASFALTO_PROFUNDO)
        for right_x in _QUAKE_COLUMNS[1]:
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
_CROWN_CENTRE = (0.545, 0.545)
_CROWN_WIDTH = 0.680
#: Proporcion de la corona: mas ancha que alta, como una corona de verdad.
_CROWN_RATIO = 0.860
#: Linea de la banda, en coordenadas locales de la corona.
_CROWN_BAND = (-0.360, 0.320, 0.360, 0.320)

#: Estallido de impacto: centro, radio exterior, radio interior y numero de puntas. Va
#: encima del brazo izquierdo de la corona y por detras de el, sin meterse entre sus
#: puntas: a 95 px las dos formas comparten tono y, si se solapan, la corona se pierde.
_BURST_CENTRE = (0.315, 0.345)
_BURST_OUTER = 0.265
_BURST_INNER = 0.165
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

    El estallido de rojo senal queda detras del brazo izquierdo de la corona; la corona
    cae hacia la derecha con una punta astillada, para que el golpe se lea en la
    direccion en la que se ha ido.
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

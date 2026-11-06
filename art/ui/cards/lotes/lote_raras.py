#!/usr/bin/env python
"""Las cinco cartas raras de giro de Flip the Table.

`Inflation`, `BounceRent`, `DeedThief`, `Backstab` y `Demolition` completan las raras
del guion de arte (`ilustraciones.md`, seccion 3). Se dibujan con el mismo lenguaje que
las tres cartas aprobadas: formas planas, un solo grosor de trazo (40 px de 4x, que son
10 px a tamano final), cuatro colores de la paleta como maximo -fondo incluido- y la
exigencia de leerse a 95 x 95 px.

Regla de lenguaje: cosas y senales, nunca personas. Ni figuras, ni cabezas, ni manos.

Todo se mide en fracciones del ancho (`w`) y del alto (`h`) de la ventana, en pixeles
de 4x. La esquina superior derecha de la ventana (0,72-1,00 del ancho x 0-0,28 del
alto) se deja libre para el sello de rareza, y nada se dibuja fuera del `box`: la
ventana no recorta.
"""
import math

try:
    from cardlib import (
        ACERO,
        ASFALTO,
        ASFALTO_PROFUNDO,
        AZUL_MARINO,
        CALIZA,
        NARANJA_OBRA,
        ROJO_SENAL,
        SS,
    )
except ImportError:  # permitir `python lotes/lote_raras.py`
    import sys
    from pathlib import Path

    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from cardlib import (
        ACERO,
        ASFALTO,
        ASFALTO_PROFUNDO,
        AZUL_MARINO,
        CALIZA,
        NARANJA_OBRA,
        ROJO_SENAL,
        SS,
    )

#: Las cinco cartas son raras: el lote entero comparte rareza.
RARITY = {
    "Inflation": "Rare",
    "BounceRent": "Rare",
    "DeedThief": "Rare",
    "Backstab": "Rare",
    "Demolition": "Rare",
}

#: Nombres en espanol para la hoja de contacto.
LABELS = {
    "Inflation": "Inflaci\u00f3n",
    "BounceRent": "Renta Rebotada",
    "DeedThief": "Ladr\u00f3n de Escrituras",
    "Backstab": "Pu\u00f1alada",
    "Demolition": "Demolici\u00f3n",
}

#: Grosor unico del lote, en pixeles de 4x: 10 px a tamano final.
STROKE = 24
#: Media punta: lo que un filete se come fuera de la forma que rodea.
HALF = STROKE // 2


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


def _stroke(draw, points, fill, width=STROKE, caps=True):
    """Linea gruesa abierta, con las juntas redondeadas y, si se pide, las puntas."""
    pts = [_p(point) for point in points]
    if len(pts) < 2:
        return
    draw.line(pts, fill=fill, width=max(1, round(width)), joint="curve")
    if caps and width:
        radius = width / 2.0
        for x, y in (pts[0], pts[-1]):
            draw.ellipse(
                [round(x - radius), round(y - radius),
                 round(x + radius), round(y + radius)],
                fill=fill,
            )


def _fill(draw, x, y, width, height, fill):
    draw.rectangle(
        [round(x), round(y), round(x + width) - 1, round(y + height) - 1], fill=fill
    )


def _field(draw, x0, y0, w, h, colour):
    """Fondo plano de la ventana: cubre el box entero, ni un pixel mas."""
    _fill(draw, x0, y0, w, h, colour)


def _disc(draw, centre, radius, fill, outline=None, width=STROKE):
    box = [
        round(centre[0] - radius), round(centre[1] - radius),
        round(centre[0] + radius), round(centre[1] + radius),
    ]
    if outline is None:
        draw.ellipse(box, fill=fill)
    else:
        draw.ellipse(box, fill=fill, outline=outline, width=max(1, round(width)))


def _arc(cx, cy, rx, ry, start, end, steps=48):
    """Muestrea un arco de elipse; los angulos, en grados, con la y hacia abajo."""
    return [
        (cx + rx * math.cos(math.radians(start + (end - start) * i / steps)),
         cy + ry * math.sin(math.radians(start + (end - start) * i / steps)))
        for i in range(steps + 1)
    ]


def _quad(start, control, end, steps=56):
    """Muestrea una curva de Bezier cuadratica."""
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


def _clip_half(points, origin, normal):
    """Recorta un poligono convexo al semiplano `(p - origen) . normal <= 0`."""
    out = []
    count = len(points)
    for index in range(count):
        current = points[index]
        previous = points[index - 1]
        dc = ((current[0] - origin[0]) * normal[0]
              + (current[1] - origin[1]) * normal[1])
        dp = ((previous[0] - origin[0]) * normal[0]
              + (previous[1] - origin[1]) * normal[1])
        if dc <= 0.0:
            if dp > 0.0:
                t = dp / (dp - dc)
                out.append(
                    (previous[0] + (current[0] - previous[0]) * t,
                     previous[1] + (current[1] - previous[1]) * t)
                )
            out.append(current)
        elif dp <= 0.0:
            t = dp / (dp - dc)
            out.append(
                (previous[0] + (current[0] - previous[0]) * t,
                 previous[1] + (current[1] - previous[1]) * t)
            )
    return out


def _point_at(points, lengths, distance):
    """Punto de la polilinea a `distance` de su principio, medida sobre la curva."""
    if distance <= 0.0:
        return points[0]
    if distance >= lengths[-1]:
        return points[-1]
    for index in range(1, len(lengths)):
        if lengths[index] >= distance:
            span = lengths[index] - lengths[index - 1]
            t = 0.0 if span <= 0.0 else (distance - lengths[index - 1]) / span
            ax, ay = points[index - 1]
            bx, by = points[index]
            return (ax + (bx - ax) * t, ay + (by - ay) * t)
    return points[-1]


def _dotted(draw, points, fill, dash, gap, width=STROKE):
    """Trazo discontinuo sobre una polilinea, con las puntas redondas."""
    lengths = [0.0]
    for index in range(1, len(points)):
        ax, ay = points[index - 1]
        bx, by = points[index]
        lengths.append(lengths[-1] + math.hypot(bx - ax, by - ay))
    total = lengths[-1]
    if total <= 0.0:
        return
    start = 0.0
    while start < total:
        end = min(start + dash, total)
        _stroke(
            draw,
            [_point_at(points, lengths, start), _point_at(points, lengths, end)],
            fill,
            width=width,
        )
        start = end + gap


def _crossing(a, b, x):
    """Punto donde el segmento a-b corta la vertical `x`."""
    span = b[0] - a[0]
    if abs(span) < 1e-6:
        return (x, a[1])
    t = (x - a[0]) / span
    return (x, a[1] + (b[1] - a[1]) * t)


def _towards(a, b, distance):
    """Punto a `distance` de `a` en direccion a `b`."""
    span = math.hypot(b[0] - a[0], b[1] - a[1])
    if span <= 0.0:
        return a
    t = min(1.0, distance / span)
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


# ------------------------------------------------------------------------- Inflacion

#: Media anchura de cada moneda, de abajo arriba: la pila se estrecha al crecer.
_INFLATION_RADII = (0.250, 0.238, 0.226, 0.214, 0.202)
#: Canto de una moneda y comba de su cara, en fracciones del alto de la ventana.
_INFLATION_THICK = 0.105
_INFLATION_BULGE = 0.045


def paint_inflation(draw, box):
    """Inflacion: la pila de cinco monedas y la flecha que sube al lado.

    Asfalto profundo en el campo, caliza en la pila y naranja de obra en la flecha: el
    asfalto del contorno. La pila se dibuja como un solo cuerpo de caliza con un arco
    de asfalto por moneda; la flecha es una sola pieza, apoyada en el mismo suelo.
    """
    x0, y0, w, h = _frame(box)
    _field(draw, x0, y0, w, h, ASFALTO_PROFUNDO)

    ground = y0 + h - 1 - HALF
    thick = _INFLATION_THICK * h
    bulge = _INFLATION_BULGE * h
    cx = x0 + 0.330 * w

    def rim(index):
        """Altura de la linea de la cara de la moneda `index`, de abajo arriba."""
        return ground - bulge - index * thick

    def radius(index):
        return _INFLATION_RADII[index] * w

    # 1. La pila: un solo contorno, con la cara de arriba en arco y el canto abajo.
    pile = (
        _arc(cx, rim(5), radius(4), bulge, 180.0, 360.0)
        + [(cx + radius(0), rim(0))]
        + _arc(cx, rim(0), radius(0), bulge, 0.0, 180.0)[1:]
    )
    _polygon(draw, pile, CALIZA)

    # 2. Una costura por moneda: el canto de la de arriba, en arco, sobre la caliza.
    for index in range(1, 5):
        _stroke(
            draw,
            _arc(cx, rim(index), radius(index), bulge, 180.0, 0.0),
            ASFALTO,
            caps=False,
        )

    # 3. La flecha: asta y cabeza en una pieza, con el contorno de asfalto.
    arrow_cx = x0 + 0.815 * w
    shaft = 0.042 * w
    head = 0.135 * w
    apex = y0 + 0.245 * h
    shoulder = y0 + 0.500 * h
    _polygon(
        draw,
        [
            (arrow_cx - shaft, ground),
            (arrow_cx - shaft, shoulder),
            (arrow_cx - head, shoulder),
            (arrow_cx, apex),
            (arrow_cx + head, shoulder),
            (arrow_cx + shaft, shoulder),
            (arrow_cx + shaft, ground),
        ],
        NARANJA_OBRA,
    )


# -------------------------------------------------------------------- Renta Rebotada


def paint_bounce_rent(draw, box):
    """Renta Rebotada: la moneda que bota contra la pared de la derecha.

    Acero en el campo, asfalto en la pared y en el contorno, caliza en la moneda y en el
    arco punteado de la trayectoria. La moneda toca la pared en el punto del rebote y el
    arco entra por abajo a la izquierda y sale por arriba: la pared devuelve el tiro.
    """
    x0, y0, w, h = _frame(box)
    _field(draw, x0, y0, w, h, ACERO)

    right = x0 + w - 1
    bottom = y0 + h - 1

    # 1. La pared: masa de asfalto pegada al canto derecho, con su remate de caliza.
    wall = x0 + 0.755 * w
    wall_top = y0 + 0.215 * h
    _fill(draw, wall, wall_top, right - wall + 1, bottom - wall_top + 1, ASFALTO)
    _fill(draw, wall, wall_top, right - wall + 1, 0.050 * h, CALIZA)

    # 2. La trayectoria: entra por abajo a la izquierda y sale por arriba, en puntos.
    coin = (x0 + 0.640 * w, y0 + 0.520 * h)
    radius = 0.152 * w
    incoming = _quad(
        (x0 + 0.020 * w, y0 + 0.950 * h),
        (x0 + 0.430 * w, y0 + 0.830 * h),
        (coin[0] + 0.030 * w, coin[1] + 0.120 * h),
    )
    outgoing = _quad(
        (coin[0] - 0.010 * w, coin[1] - 0.120 * h),
        (x0 + 0.330 * w, y0 + 0.280 * h),
        (x0 + 0.105 * w, y0 + 0.215 * h),
    )
    dash, gap = 0.075 * w, 0.055 * w
    _dotted(draw, incoming, CALIZA, dash, gap)
    _dotted(draw, outgoing, CALIZA, dash, gap)

    # 3. La moneda, delante de la pared: disco de caliza con su filete y su aro.
    _disc(draw, coin, radius, CALIZA, ASFALTO, STROKE)
    draw.ellipse(
        [
            round(coin[0] - radius * 0.58), round(coin[1] - radius * 0.58),
            round(coin[0] + radius * 0.58), round(coin[1] + radius * 0.58),
        ],
        outline=ASFALTO,
        width=STROKE,
    )


# ---------------------------------------------------------------- Ladron de Escrituras


def paint_deed_thief(draw, box):
    """Ladron de Escrituras: la escritura saliendo del cuadro, tirada por un garfio.

    Acero en el campo, caliza en el papel, asfalto en el garfio y en la letra, y rojo
    senal en las tres lineas de movimiento. La hoja sale por el canto derecho sin
    filete en ese lado: el papel sigue fuera del cuadro. El garfio entra por la derecha
    por debajo del sello y engancha la hoja, sin puna ni forma de mano.
    """
    x0, y0, w, h = _frame(box)
    _field(draw, x0, y0, w, h, ACERO)

    right = x0 + w - 1

    # 1. La hoja: rectangulo girado que sale por la derecha. Se recorta a mano contra el
    #    canto para que el relleno llegue al marco y el filete no se escape del box.
    cx, cy = x0 + 0.620 * w, y0 + 0.575 * h
    half_w, half_h = 0.460 * w, 0.170 * h
    angle = -8.0
    corners = _rotate(
        [(cx - half_w, cy - half_h), (cx + half_w, cy - half_h),
         (cx + half_w, cy + half_h), (cx - half_w, cy + half_h)],
        cx, cy, angle,
    )
    top_left, top_right, bottom_right, bottom_left = corners
    top_cut = _crossing(top_left, top_right, right)
    bottom_cut = _crossing(bottom_left, bottom_right, right)
    sheet = [top_cut, top_left, bottom_left, bottom_cut]
    draw.polygon([_p(point) for point in sheet], fill=CALIZA)

    # 2. Filete: solo por los tres lados visibles; el canto de la derecha queda abierto.
    inset = HALF + 4
    _stroke(
        draw,
        [
            _towards(top_cut, top_left, inset),
            top_left,
            bottom_left,
            _towards(bottom_cut, bottom_left, inset),
        ],
        ASFALTO,
        caps=False,
    )

    # 3. La letra de la escritura: dos renglones paralelos al canto de arriba.
    for k in (0.030, 0.115):
        start = _towards(top_left, bottom_left, 0.055 * h + k * h)
        _stroke(
            draw,
            [_towards(start, top_right, 0.070 * w),
             _towards(start, top_right, 0.300 * w)],
            ASFALTO,
            width=STROKE,
            caps=False,
        )

    # 4. El sello de la escritura, en rojo senal, en el cuadrante de abajo a la izquierda:
    #    el de abajo a la derecha lo ocupa la esquina del sello de rareza.
    _disc(draw, (x0 + 0.255 * w, y0 + 0.735 * h), 0.080 * w, ROJO_SENAL)

    # 5. Las tres lineas de movimiento, detras y por encima de la hoja.
    for index, (fx, fy, length) in enumerate(
        ((0.070, 0.395, 0.115), (0.045, 0.320, 0.145), (0.100, 0.245, 0.100))
    ):
        start = (x0 + fx * w, y0 + fy * h)
        end = (start[0] + length * w, start[1] - length * w * 0.140)
        _stroke(draw, [start, end], ROJO_SENAL, width=STROKE)

    # 6. El garfio: un anzuelo limpio en «J» que entra por la derecha y engancha la hoja.
    #    Sin puna ni muneca: una puna triangular se leia como un pulgar.
    _stroke(
        draw,
        [(right - 6, y0 + 0.300 * h), (x0 + 0.820 * w, y0 + 0.300 * h)]
        + _quad(
            (x0 + 0.820 * w, y0 + 0.300 * h),
            (x0 + 0.735 * w, y0 + 0.430 * h),
            (x0 + 0.792 * w, y0 + 0.520 * h),
            44,
        )[1:],
        ASFALTO,
        width=0.050 * w,
    )


# ------------------------------------------------------------------------- Punalada

#: Media hoja del pacto y su giro, en fracciones del ancho y del alto.
_BACKSTAB_HALF_W = 0.340
_BACKSTAB_HALF_H = 0.235
_BACKSTAB_ANGLE = -5.0
#: El tajo: casi vertical, para que la silueta no se parezca a la escritura robada, y el
#: medio hueco entre las dos mitades.
_BACKSTAB_CUT = 88.0
_BACKSTAB_SHIFT = 0.045
#: Ancho del tajo de rojo senal.
_BACKSTAB_BLADE = 0.100


def paint_backstab(draw, box):
    """Punalada: el pacto roto, las dos mitades desplazadas y el tajo entre ellas.

    Asfalto en el campo, caliza en las dos mitades del papel y rojo senal en el tajo,
    que asoma por la costura y por las dos esquinas. Las mitades se dibujan encima del
    tajo: el rojo solo se ve donde falta papel.
    """
    x0, y0, w, h = _frame(box)
    _field(draw, x0, y0, w, h, ASFALTO)

    cx, cy = x0 + 0.520 * w, y0 + 0.545 * h
    half_w = _BACKSTAB_HALF_W * w
    half_h = _BACKSTAB_HALF_H * h
    sheet = _rotate(
        [(cx - half_w, cy - half_h), (cx + half_w, cy - half_h),
         (cx + half_w, cy + half_h), (cx - half_w, cy + half_h)],
        cx, cy, _BACKSTAB_ANGLE,
    )

    # 1. El tajo, debajo: una banda de rojo senal a lo largo de la linea del corte.
    cut = math.radians(_BACKSTAB_CUT)
    axis = (math.cos(cut), math.sin(cut))
    normal = (-axis[1], axis[0])
    length = 0.900 * w
    blade = 0.5 * _BACKSTAB_BLADE * w
    band = [
        (cx - axis[0] * length / 2, cy - axis[1] * length / 2),
        (cx - axis[0] * length / 2 + normal[0] * blade,
         cy - axis[1] * length / 2 + normal[1] * blade),
        (cx + axis[0] * length / 2 + normal[0] * blade,
         cy + axis[1] * length / 2 + normal[1] * blade),
        (cx + axis[0] * length / 2, cy + axis[1] * length / 2),
    ]
    _polygon(draw, band, ROJO_SENAL, outline=None)

    # 2. Las dos mitades, separadas a los lados del tajo.
    shift = _BACKSTAB_SHIFT * w
    for direction in (-1.0, 1.0):
        half = _clip_half(sheet, (cx, cy), (normal[0] * direction,
                                            normal[1] * direction))
        if len(half) < 3:
            continue
        moved = [(px + normal[0] * shift * direction,
                  py + normal[1] * shift * direction) for px, py in half]
        _polygon(draw, moved, CALIZA)

    # 3. Dos renglones del pacto, uno en cada mitad, lejos del corte.
    for fx, fy, length in ((0.180, 0.415, 0.150), (0.640, 0.720, 0.150)):
        start = (x0 + fx * w, y0 + fy * h)
        end = (start[0] + length * w, start[1] + length * w * 0.090)
        _stroke(draw, [start, end], ASFALTO, width=STROKE, caps=False)


# ----------------------------------------------------------------------- Demolicion


def paint_demolition(draw, box):
    """Demolicion: el bloque de caliza con el boquete y la bola entrando por la derecha.

    Acero en el campo, caliza en el bloque y asfalto en las ventanas, el boquete, la
    bola, el cable y el contorno. El bloque apoya en el canto inferior; el boquete es
    un mordisco en su lado derecho y la bola entra por el, con el cable saliendo por el
    canto derecho por debajo del sello.
    """
    x0, y0, w, h = _frame(box)
    _field(draw, x0, y0, w, h, ACERO)

    right = x0 + w - 1
    bottom = y0 + h - 1

    left = x0 + 0.030 * w
    face = x0 + 0.700 * w
    top = y0 + 0.120 * h

    # 1. El boquete: mordisco de tres quiebros en el lado derecho del bloque.
    bite = [
        (face, y0 + 0.400 * h),
        (x0 + 0.545 * w, y0 + 0.470 * h),
        (x0 + 0.600 * w, y0 + 0.570 * h),
        (x0 + 0.520 * w, y0 + 0.655 * h),
        (face, y0 + 0.745 * h),
    ]
    body = [(left, top), (face, top)] + bite + [(face, bottom), (left, bottom)]
    draw.polygon([_p(point) for point in body], fill=CALIZA)
    _stroke(
        draw,
        [(left, bottom), (left, top), (face, top)] + bite + [(face, bottom)],
        ASFALTO,
        caps=False,
    )

    # 2. Cuatro ventanas de asfalto en la fachada, lejos del boquete.
    for fx in (0.105, 0.290):
        for fy in (0.200, 0.405):
            _fill(draw, x0 + fx * w, y0 + fy * h, 0.125 * w, 0.130 * h, ASFALTO)

    # 3. El cable: sale de la bola y se pierde por el canto derecho.
    ball = (x0 + 0.795 * w, y0 + 0.620 * h)
    _stroke(
        draw,
        [(ball[0], ball[1]), (right - 24, y0 + 0.300 * h)],
        ASFALTO,
        width=STROKE,
    )

    # 4. La bola, delante del boquete.
    _disc(draw, ball, 0.150 * w, ASFALTO)


PAINTERS = {
    "Inflation": paint_inflation,
    "BounceRent": paint_bounce_rent,
    "DeedThief": paint_deed_thief,
    "Backstab": paint_backstab,
    "Demolition": paint_demolition,
}

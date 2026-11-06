#!/usr/bin/env python
"""Las ocho cartas comunes de giro de Flip the Table.

`Shield`, `ExtraDie`, `Reverse`, `ForcedTip`, `Discount`, `Shove`, `Bribe` y `Spy`
completan las comunes del guion de arte (`ilustraciones.md`, seccion 3). Se dibujan
con el mismo lenguaje que las tres cartas aprobadas: formas planas, un solo grosor de
trazo, cuatro colores de la paleta como maximo y la exigencia de leerse a 95 x 95 px.

Regla de lenguaje: cosas y senales, nunca personas. Ni figuras, ni cabezas, ni manos.

Todo se mide en fracciones del ancho (`w`) y del alto (`h`) de la ventana, en pixeles
de 4x. El trazo es unico para el lote: 40 px de 4x, que son 10 px a tamano final. La
esquina superior derecha de la ventana (0,72-1,00 del ancho x 0-0,28 del alto) se deja
libre para el sello de rareza, y nada se dibuja fuera del `box`: la ventana no recorta.
"""
import math

try:
    from cardlib import (
        ACERO,
        ASFALTO,
        AZUL_MARINO,
        CALIZA,
        CRISTAL_AZUL,
        NARANJA_OBRA,
        ORO,
        ROJO_SENAL,
        SS,
    )
except ImportError:  # permitir `python lotes/lote_comunes.py`
    import sys
    from pathlib import Path

    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from cardlib import (
        ACERO,
        ASFALTO,
        AZUL_MARINO,
        CALIZA,
        CRISTAL_AZUL,
        NARANJA_OBRA,
        ORO,
        ROJO_SENAL,
        SS,
    )

#: Las ocho cartas son comunes: el lote entero comparte rareza.
RARITY = {
    "Shield": "Common",
    "ExtraDie": "Common",
    "Reverse": "Common",
    "ForcedTip": "Common",
    "Discount": "Common",
    "Shove": "Common",
    "Bribe": "Common",
    "Spy": "Common",
}

#: Nombres en espanol para la hoja de contacto.
LABELS = {
    "Shield": "Escudo",
    "ExtraDie": "Dado Extra",
    "Reverse": "Marcha Atr\u00e1s",
    "ForcedTip": "Propina Forzada",
    "Discount": "Descuento",
    "Shove": "Empuj\u00f3n",
    "Bribe": "Soborno",
    "Spy": "Esp\u00eda",
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
    en sentido horario."""
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
    if caps:
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


def _disc(draw, centre, radius, fill):
    draw.ellipse(
        [
            round(centre[0] - radius), round(centre[1] - radius),
            round(centre[0] + radius), round(centre[1] + radius),
        ],
        fill=fill,
    )


def _token(draw, centre, radius, fill, width=STROKE):
    """Disco con filete centrado en su borde: el aro queda mitad dentro, mitad fuera.

    Es el mismo reparto que el filete de un poligono, y deja el relleno al completo.
    """
    _disc(draw, centre, radius + width / 2.0, ASFALTO)
    _disc(draw, centre, radius - width / 2.0, fill)


def _quad(start, control, end, steps=48):
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


def _polar(cx, cy, radius, degrees):
    angle = math.radians(degrees)
    return (cx + radius * math.cos(angle), cy + radius * math.sin(angle))


def _rounded_rect(x0, y0, x1, y1, radius, steps=10):
    """Contorno de un rectangulo de esquinas redondeadas, en sentido horario."""
    radius = min(radius, (x1 - x0) / 2.0, (y1 - y0) / 2.0)
    corners = (
        (x1 - radius, y0 + radius, -90.0),
        (x1 - radius, y1 - radius, 0.0),
        (x0 + radius, y1 - radius, 90.0),
        (x0 + radius, y0 + radius, 180.0),
    )
    points = []
    for cx, cy, start in corners:
        for index in range(steps + 1):
            points.append(_polar(cx, cy, radius, start + 90.0 * index / steps))
    return points


def _ellipse(cx, cy, rx, ry, degrees=0.0, steps=64):
    """Contorno de una elipse girada, muestreado para poder filetearla."""
    points = [_polar(cx, cy, 1.0, 360.0 * index / steps) for index in range(steps)]
    points = [(cx + (x - cx) * rx, cy + (y - cy) * ry) for x, y in points]
    return _rotate(points, cx, cy, degrees) if degrees else points


def _clip_convex(subject, clipper):
    """Recorta `subject` contra el poligono convexo `clipper` (Sutherland-Hodgman)."""
    points = [tuple(point) for point in subject]
    count = len(clipper)
    area = 0.0
    for index in range(count):
        ax, ay = clipper[index]
        bx, by = clipper[(index + 1) % count]
        area += ax * by - bx * ay
    sign = 1.0 if area > 0 else -1.0
    for index in range(count):
        if not points:
            return []
        ax, ay = clipper[index]
        bx, by = clipper[(index + 1) % count]
        edge_x, edge_y = bx - ax, by - ay

        def side(point):
            return sign * (edge_x * (point[1] - ay) - edge_y * (point[0] - ax))

        output = []
        for position, point in enumerate(points):
            previous = points[position - 1]
            current_side = side(point)
            previous_side = side(previous)
            if current_side >= 0.0:
                if previous_side < 0.0:
                    t = previous_side / (previous_side - current_side)
                    output.append(
                        (
                            previous[0] + (point[0] - previous[0]) * t,
                            previous[1] + (point[1] - previous[1]) * t,
                        )
                    )
                output.append(point)
            elif previous_side >= 0.0:
                t = previous_side / (previous_side - current_side)
                output.append(
                    (
                        previous[0] + (point[0] - previous[0]) * t,
                        previous[1] + (point[1] - previous[1]) * t,
                    )
                )
        points = output
    return points


# --------------------------------------------------------------------------- Escudo

#: Escudo de cometa de frente: techo plano con las esquinas redondeadas, costados
#: rectos y punta curva abajo. Todo en fracciones de `w` y `h`.
_SHIELD_TOP = 0.294
_SHIELD_TIP = 0.960
_SHIELD_HALF = 0.358
_SHIELD_STRAIGHT = 0.620
_SHIELD_CORNER = 0.060
_SHIELD_BAND = 0.062


def _shield_side(cx, top, tip, half, corner):
    """Lado derecho del escudo, del centro del techo a la punta."""
    straight = top + _SHIELD_STRAIGHT * (tip - top)
    points = [(cx, top), (cx + half - corner, top)]
    for index in range(9):  # esquina superior redondeada
        points.append(_polar(cx + half - corner, top + corner, corner,
                             -90.0 + 90.0 * index / 8.0))
    points.append((cx + half, straight))
    points += _quad(
        (cx + half, straight),
        (cx + half * 0.560, straight + 0.760 * (tip - straight)),
        (cx, tip),
        56,
    )[1:]
    return points


def paint_shield(draw, box):
    """Escudo de cometa de frente, con la banda central vertical.

    Marino en el campo, caliza en el escudo y asfalto en el filete y en la banda: la
    banda es el mismo trazo del contorno, no un color nuevo.
    """
    x0, y0, w, h = _frame(box)
    _field(draw, x0, y0, w, h, AZUL_MARINO)

    cx = x0 + 0.500 * w
    top = y0 + _SHIELD_TOP * h
    tip = y0 + _SHIELD_TIP * h
    half = _SHIELD_HALF * w
    side = _shield_side(cx, top, tip, half, _SHIELD_CORNER * w)
    outline = side + [(2.0 * cx - x, y) for x, y in reversed(side)][1:-1]
    _polygon(draw, outline, CALIZA)

    # Banda central: baja del techo hasta donde el escudo se estrecha por debajo de ella.
    band = _SHIELD_BAND * w
    inside = [y for x, y in side if (x - cx) >= band * 1.55 and y > top + 1.0]
    if inside:
        _fill(draw, cx - band, top, 2.0 * band, max(inside) - top, ASFALTO)


# --------------------------------------------------------------------------- Dado Extra


def _iso_face(centre, axis_u, axis_v):
    """Las cuatro esquinas de una cara isometrica: centro +/- media arista."""
    cx, cy = centre
    ux, uy = axis_u
    vx, vy = axis_v
    return [
        (cx - 0.5 * ux - 0.5 * vx, cy - 0.5 * uy - 0.5 * vy),
        (cx + 0.5 * ux - 0.5 * vx, cy + 0.5 * uy - 0.5 * vy),
        (cx + 0.5 * ux + 0.5 * vx, cy + 0.5 * uy + 0.5 * vy),
        (cx - 0.5 * ux + 0.5 * vx, cy - 0.5 * uy + 0.5 * vy),
    ]


#: Puntos de cada cara, en una rejilla de -1..1 dentro de la cara.
_PIPS = {
    2: ((-1.0, -1.0), (1.0, 1.0)),
    3: ((-1.0, -1.0), (0.0, 0.0), (1.0, 1.0)),
    4: ((-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)),
}
#: Separacion de los puntos respecto al centro de su cara.
_PIP_SPREAD = 0.300


def _iso_die(draw, centre, a, b, side, values=None, pip_radius=0.0):
    """Dado isometrico de tres caras vistas: la de arriba y las dos de delante."""
    cx, cy = centre
    mid = (cx, cy + b)
    faces = (
        ((cx, cy), (a, -b), (a, b), values[0] if values else None),
        ((cx - a / 2.0, cy + b / 2.0 + side / 2.0), (a, b), (0.0, side),
         values[1] if values else None),
        ((cx + a / 2.0, cy + b / 2.0 + side / 2.0), (a, -b), (0.0, side),
         values[2] if values else None),
    )
    _polygon(
        draw,
        [
            (cx, cy - b),
            (cx + a, cy),
            (cx + a, cy + side),
            (cx, cy + b + side),
            (cx - a, cy + side),
            (cx - a, cy),
        ],
        CALIZA,
    )
    for end in ((cx - a, cy), (cx + a, cy), (cx, cy + b + side)):
        _stroke(draw, [mid, end], ASFALTO)

    if not values or not pip_radius:
        return
    for centre_face, axis_u, axis_v, value in faces:
        if not value:
            continue
        for px, py in _PIPS[value]:
            point = (
                centre_face[0]
                + px * _PIP_SPREAD * axis_u[0] + py * _PIP_SPREAD * axis_v[0],
                centre_face[1]
                + px * _PIP_SPREAD * axis_u[1] + py * _PIP_SPREAD * axis_v[1],
            )
            _disc(draw, point, pip_radius, ASFALTO)


def paint_extra_die(draw, box):
    """Dado Extra: un dado de tres caras y, detras y arriba, otro mas pequeno.

    El pequeno va sin puntos, para que no compita: se lee por la silueta del cubo y
    asoma por detras del hombro izquierdo del grande.
    """
    x0, y0, w, h = _frame(box)
    _field(draw, x0, y0, w, h, ACERO)

    a = 0.322 * w
    b = 0.560 * a
    side = 1.060 * a
    small = 0.400 * a
    _iso_die(
        draw,
        (x0 + 0.207 * w, y0 + 0.268 * h),
        small,
        0.560 * small,
        1.060 * small,
    )
    _iso_die(
        draw,
        (x0 + 0.545 * w, y0 + 0.400 * h),
        a,
        b,
        side,
        values=(2, 3, 4),
        pip_radius=0.030 * w,
    )


# --------------------------------------------------------------------- Marcha Atras


def paint_reverse(draw, box):
    """Marcha Atras: la senal de cambio de sentido, de frente.

    Campo de asfalto, placa de caliza con las esquinas redondeadas, un filete naranja
    de obra por dentro y la flecha en U del mismo asfalto del contorno.
    """
    x0, y0, w, h = _frame(box)
    _field(draw, x0, y0, w, h, ASFALTO)

    left, right = x0 + 0.070 * w, x0 + 0.858 * w
    top, bottom = y0 + 0.298 * h, y0 + 0.952 * h
    _polygon(draw, _rounded_rect(left, top, right, bottom, 0.078 * w), CALIZA)

    inset = 0.050 * w
    _polygon(
        draw,
        _rounded_rect(left + inset, top + inset, right - inset, bottom - inset,
                      0.078 * w - inset),
        CALIZA,
        outline=NARANJA_OBRA,
    )

    # Flecha en U: sube por la izquierda, gira 180 grados y baja por la derecha.
    cx = 0.5 * (left + right)
    turn_y = y0 + 0.556 * h
    radius = 0.114 * w
    stem = 0.094 * w
    path = [(cx - radius, y0 + 0.812 * h)]
    path += [_polar(cx, turn_y, radius, 180.0 + 180.0 * index / 44.0)
             for index in range(45)]
    path.append((cx + radius, y0 + 0.664 * h))
    _stroke(draw, path, ASFALTO, width=stem)

    head_y = y0 + 0.662 * h
    head_half = 0.128 * w
    _polygon(
        draw,
        [
            (cx + radius - head_half, head_y),
            (cx + radius + head_half, head_y),
            (cx + radius, y0 + 0.836 * h),
        ],
        ASFALTO,
        outline=None,
    )


# ------------------------------------------------------------------ Propina Forzada


def paint_forced_tip(draw, box):
    """Propina Forzada: tarro de cristal con tres monedas y una que cae de canto.

    El tarro es un trapecio de caliza con el borde de la boca marcado y una franja de
    cristal azul en el costado derecho. Las monedas van en oro con el filete de
    asfalto; la que cae se ve de canto y se mete por la boca del tarro.
    """
    x0, y0, w, h = _frame(box)
    _field(draw, x0, y0, w, h, ACERO)

    cx = x0 + 0.545 * w
    lip = 0.345 * w
    mouth = y0 + 0.386 * h
    foot = 0.300 * w
    bottom = y0 + 0.940 * h

    # --- moneda que cae: se dibuja antes que el tarro, que le tapa la punta de abajo.
    _polygon(
        draw,
        _ellipse(x0 + 0.186 * w, y0 + 0.276 * h, 0.032 * w, 0.090 * w, 10.0),
        ORO,
    )

    # --- tarro: boca ancha y cuerpo que se estrecha hacia el fondo.
    _polygon(
        draw,
        [
            (cx - lip, mouth),
            (cx + lip, mouth),
            (cx + foot, bottom),
            (cx - foot, bottom),
        ],
        CALIZA,
    )

    # --- cristal: la franja azul del costado derecho, dentro del cuerpo.
    _polygon(
        draw,
        [
            (cx + 0.212 * w, y0 + 0.505 * h),
            (cx + 0.310 * w, y0 + 0.505 * h),
            (cx + 0.278 * w, y0 + 0.905 * h),
            (cx + 0.212 * w, y0 + 0.905 * h),
        ],
        CRISTAL_AZUL,
        outline=None,
    )

    # --- las tres monedas: dos apoyadas en el fondo y una encima, sin tocarse.
    for fx, fy in ((-0.140, 0.828), (0.140, 0.828), (0.004, 0.730)):
        _token(draw, (cx + fx * w, y0 + fy * h), 0.062 * w, ORO)

    # --- boca del tarro: un trazo de asfalto dentro del cristal.
    _stroke(
        draw,
        [(cx - lip + 0.030 * w, mouth + 0.076 * h),
         (cx + lip - 0.030 * w, mouth + 0.076 * h)],
        ASFALTO,
    )


# ------------------------------------------------------------------------ Descuento

#: Etiqueta: largo, alto y corte de la esquina, en fracciones de `w`.
_TAG_LENGTH = 0.820
_TAG_HEIGHT = 0.420
_TAG_CUT = 0.210
_TAG_ANGLE = -12.0


def paint_discount(draw, box):
    """Descuento: etiqueta de precio con la esquina cortada y la banda roja encima.

    La etiqueta va girada doce grados; la banda roja la cruza de lado a lado y se
    recorta contra su contorno, que se repasa despues para que el borde quede limpio.
    """
    x0, y0, w, h = _frame(box)
    _field(draw, x0, y0, w, h, CRISTAL_AZUL)

    cx, cy = x0 + 0.492 * w, y0 + 0.606 * h
    length, height, cut = _TAG_LENGTH * w, _TAG_HEIGHT * w, _TAG_CUT * w
    local = [
        (-length / 2.0, -height / 2.0 + cut),
        (-length / 2.0 + cut, -height / 2.0),
        (length / 2.0, -height / 2.0),
        (length / 2.0, height / 2.0),
        (-length / 2.0, height / 2.0),
    ]
    tag = _rotate([(cx + px, cy + py) for px, py in local], cx, cy, _TAG_ANGLE)
    _polygon(draw, tag, CALIZA)

    # Banda diagonal: se recorta contra la etiqueta y luego se repasa solo el filete.
    band = _rotate(
        [
            (cx - 0.5 * length, cy - 0.031 * w),
            (cx + 0.5 * length, cy - 0.031 * w),
            (cx + 0.5 * length, cy + 0.031 * w),
            (cx - 0.5 * length, cy + 0.031 * w),
        ],
        cx,
        cy,
        _TAG_ANGLE - 74.0,
    )
    _polygon(draw, _clip_convex(band, tag), ROJO_SENAL, outline=None)
    _stroke(draw, tag + [tag[0], tag[1]], ASFALTO)

    # Agujero de la esquina cortada: se ve el fondo azul, con su filete.
    hole = _rotate(
        [(cx - length / 2.0 + cut * 1.16, cy - height / 2.0 + cut * 1.16)],
        cx, cy, _TAG_ANGLE,
    )
    _token(draw, hole[0], 0.058 * w, CRISTAL_AZUL)


# -------------------------------------------------------------------------- Empujon


def paint_shove(draw, box):
    """Empujon: la ficha vuela a la derecha, empujada por dos galones.

    Naranja de obra en el campo, caliza en la ficha, los galones y los trazos de
    impulso, y asfalto en el aro y en los filetes. El orden de lectura es el del
    empujon: los trazos quedan detras, los galones en medio y la ficha delante.
    """
    x0, y0, w, h = _frame(box)
    _field(draw, x0, y0, w, h, NARANJA_OBRA)

    # Tres trazos de impulso, lo mas atras.
    for fy, length in ((0.452, 0.062), (0.612, 0.082), (0.772, 0.062)):
        _stroke(
            draw,
            [(x0 + 0.018 * w, y0 + fy * h),
             (x0 + (0.018 + length) * w, y0 + fy * h)],
            CALIZA,
        )

    # Dos galones empujando hacia la derecha.
    cy = y0 + 0.612 * h
    for apex in (0.224, 0.344):
        _stroke(
            draw,
            [(x0 + (apex - 0.086) * w, cy - 0.168 * w),
             (x0 + apex * w, cy),
             (x0 + (apex - 0.086) * w, cy + 0.168 * w)],
            CALIZA,
        )

    # La ficha, delante de los galones.
    radius = 0.240 * w
    cx = x0 + 0.660 * w
    _token(draw, (cx, cy), radius, CALIZA)
    # Aro de la ficha: la marca que la distingue de un simple disco.
    draw.ellipse(
        [
            round(cx - radius + 0.050 * w), round(cy - radius + 0.050 * w),
            round(cx + radius - 0.050 * w), round(cy + radius - 0.050 * w),
        ],
        outline=ASFALTO,
        width=STROKE,
    )


# -------------------------------------------------------------------------- Soborno


def paint_bribe(draw, box):
    """Soborno: sobre abierto, solapa caida, una moneda asomando y un sello.

    Asfalto en el campo y en los filetes, caliza en el sobre y oro en la moneda y en
    el sello de cera que cierra la punta de la solapa.
    """
    x0, y0, w, h = _frame(box)
    _field(draw, x0, y0, w, h, ASFALTO)

    left, right = x0 + 0.096 * w, x0 + 0.904 * w
    top, bottom = y0 + 0.396 * h, y0 + 0.918 * h
    _polygon(draw, [(left, top), (right, top), (right, bottom), (left, bottom)], CALIZA)

    # Moneda asomando por la boca del sobre, medio tapada por la solapa.
    _token(draw, (x0 + 0.424 * w, y0 + 0.424 * h), 0.122 * w, ORO)

    # Solapa caida por delante, del borde de arriba a la punta.
    _polygon(draw, [(left, top), (right, top), (x0 + 0.500 * w, y0 + 0.744 * h)], CALIZA)

    # Sello de cera en la punta de la solapa.
    _token(draw, (x0 + 0.500 * w, y0 + 0.606 * h), 0.080 * w, ORO)


# ----------------------------------------------------------------------------- Espia


def paint_spy(draw, box):
    """Espia: un ojo dentro de una lupa, con el mango abajo a la derecha.

    Marino en el campo, caliza en la lente y en el mango, asfalto en el aro, el ojo y
    el reflejo de dos trazos sobre el aro.
    """
    x0, y0, w, h = _frame(box)
    _field(draw, x0, y0, w, h, AZUL_MARINO)

    cx, cy = x0 + 0.436 * w, y0 + 0.458 * h
    radius = 0.302 * w
    rim = 0.060 * w
    _disc(draw, (cx, cy), radius, CALIZA)
    draw.ellipse(
        [round(cx - radius), round(cy - radius),
         round(cx + radius), round(cy + radius)],
        outline=ASFALTO,
        width=round(rim),
    )

    # Ojo: almendra, iris y un punto de luz.
    eye_w, eye_h = 0.204 * w, 0.112 * w
    upper = _quad((cx - eye_w, cy), (cx, cy - eye_h * 1.66), (cx + eye_w, cy), 40)
    lower = _quad((cx + eye_w, cy), (cx, cy + eye_h * 1.66), (cx - eye_w, cy), 40)
    _polygon(draw, upper + lower[1:-1], CALIZA)
    _disc(draw, (cx, cy), 0.090 * w, ASFALTO)
    _disc(draw, (cx - 0.030 * w, cy - 0.034 * w), 0.030 * w, CALIZA)

    # Mango: barra caliza con el filete de asfalto, hacia abajo a la derecha.
    grip = 0.086 * w
    start = _polar(cx, cy, radius - rim * 0.30, 45.0)
    end = _polar(cx, cy, radius + 0.292 * w, 45.0)
    _stroke(draw, [start, end], ASFALTO, width=grip + 2.0 * STROKE)
    _stroke(draw, [start, end], CALIZA, width=grip)

    # Reflejo de dos trazos sobre el aro, arriba a la izquierda.
    for start_angle, span in ((198.0, 13.0), (219.0, 10.0)):
        arc = [
            _polar(cx, cy, radius - rim * 0.5, start_angle + span * index / 10.0)
            for index in range(11)
        ]
        _stroke(draw, arc, CALIZA, width=STROKE)


PAINTERS = {
    "Shield": paint_shield,
    "ExtraDie": paint_extra_die,
    "Reverse": paint_reverse,
    "ForcedTip": paint_forced_tip,
    "Discount": paint_discount,
    "Shove": paint_shove,
    "Bribe": paint_bribe,
    "Spy": paint_spy,
}

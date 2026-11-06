#!/usr/bin/env python
"""Sistema visual de las cartas de giro de Flip the Table (312 x 450).

Este modulo no conoce cartas concretas: solo el marco, la ventana de ilustracion, la
banda de nombre, el pie, el sello de rareza y la hoja de contacto. Cada lote de cartas
vive en `lotes/lote_*.py` y expone `RARITY` y `PAINTERS`; `build_cards.py` los junta.

El papel es el mismo en las tres rarezas: caliza `#EDE5D3`. La rareza se lee por el
grosor y la forma del filete, la geometria de la esquina, el pie y el sello, nunca por
un campo de color grande (guia de estilo, seccion 5.2).

Contrato de un pintor
---------------------
`painter(draw, box)` recibe:

* `draw`: un `ImageDraw` sobre el lienzo de 4x (1248 x 1800).
* `box`: `(x0, y0, x1, y1)` en pixeles del lienzo de 312 x 450 (1x), NO del lienzo de
  4x. Para dibujar, multiplica por `SS` (o usa `_frame(box)`): asi el mismo pintor vale
  para cualquier ventana.

El pintor rellena el fondo del box con un color plano de la paleta y dibuja solo la
ilustracion, sin salirse del box: la ventana no recorta. La esquina superior derecha
del box queda tapada por el sello de rareza (34 x 34 px mas 8 de margen), asi que no
conviene poner ahi nada que haya que leer.

Todo se dibuja a 4x y se reduce una sola vez con `Image.LANCZOS` a 312 x 450, igual que
`art/ui/icons/build_icons.py`.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# --------------------------------------------------------------------------- medidas

SIZE = (312, 450)
SS = 4
WIDTH, HEIGHT = SIZE
CANVAS = (WIDTH * SS, HEIGHT * SS)

#: Grosor unico por carta, en pixeles de 4x (6 px a tamano final: 5-7 px es el rango).
TRAZO = 24

#: Anillo de papel visible entre el borde y la ventana.
MARCO = 6
#: Ventana de la ilustracion, filetes incluidos, igual en las tres rarezas. El bisel de
#: 30 px de la Legendaria recorta el filete de oro en las dos esquinas de arriba, que es
#: justo la senal de forma que la distingue.
WINDOW = (6, 6, 306, 290)
#: Regla de 4 px de asfalto entre la ventana y la banda de nombre.
RULE = (6, 290, 306, 294)
#: Banda de nombre: caliza, vacia, a sangre dentro del marco. La escribe el juego.
BAND = (6, 294, 306, 416)
#: Pie: 28 px al fondo con la marca de rareza y un filete de 2 px arriba.
FOOT = (6, 416, 306, 444)
#: Sello de rareza en la esquina superior derecha de la ventana.
SEAL = 34
SEAL_MARGIN = 8
#: Bisel de las esquinas superiores de la Legendaria.
BEVEL = 30

# --------------------------------------------------------------------------- paleta

ASFALTO = (35, 39, 44, 255)  # #23272C
ASFALTO_PROFUNDO = (20, 23, 26, 255)  # #14171A
CALIZA = (237, 229, 211, 255)  # #EDE5D3
CALIZA_APAGADA = (207, 197, 174, 255)  # #CFC5AE
ROJO_SENAL = (196, 56, 43, 255)  # #C4382B
NARANJA_OBRA = (224, 122, 60, 255)  # #E07A3C
AZUL_MARINO = (27, 58, 107, 255)  # #1B3A6B
ACERO = (168, 174, 180, 255)  # #A8AEB4
ORO = (201, 162, 39, 255)  # #C9A227
CRISTAL_AZUL = (127, 178, 217, 255)  # #7FB2D9
#: Solo dentro de la ilustracion, y solo si el sujeto es un taxi o una senal: una pieza
#: pequena como mucho. Nunca en el marco ni en el pie.
AMARILLO_TAXI = (245, 197, 24, 255)  # #F5C518

PALETA = {
    "asfalto": ASFALTO,
    "asfalto-profundo": ASFALTO_PROFUNDO,
    "caliza": CALIZA,
    "caliza-apagada": CALIZA_APAGADA,
    "rojo-senal": ROJO_SENAL,
    "naranja-obra": NARANJA_OBRA,
    "azul-marino": AZUL_MARINO,
    "acero": ACERO,
    "oro": ORO,
    "cristal-azul": CRISTAL_AZUL,
    "amarillo-taxi": AMARILLO_TAXI,
}

#: Colores prohibidos en todo el sistema.
PROHIBIDOS = {"verde-fieltro": (31, 91, 69, 255)}

# --------------------------------------------------------------------------- rarezas

RARITIES = ("Common", "Rare", "Legendary")
RARITY_ES = {"Common": "Com\u00fan", "Rare": "Rara", "Legendary": "Legendaria"}
RARITY_RANK = {"Legendary": 0, "Rare": 1, "Common": 2}

#: El papel. Las tres rarezas comparten cuerpo caliza.
_CAMPO = {"Common": CALIZA, "Rare": CALIZA, "Legendary": CALIZA}

#: Filetes alrededor de la ventana, de fuera hacia dentro: (color, grosor en px de 1x).
_FILLETS = {
    "Common": ((ASFALTO, 8),),
    "Rare": ((ASFALTO, 7), (CALIZA, 6), (AZUL_MARINO, 7)),
    "Legendary": ((ORO, 10), (ASFALTO, 4), (CALIZA, 3)),
}

#: Esquina inferior: la Comun es la unica redondeada.
_CORNER = {"Common": 14, "Rare": 16, "Legendary": 16}


def window_box(rarity):
    """`(x0, y0, x1, y1)` de la ventana, filetes incluidos, en px de 1x.

    Es la misma en las tres rarezas: la ilustracion mide igual en las 20 cartas.
    """
    _check(rarity)
    return WINDOW


def illustration_box(rarity):
    """`(x0, y0, x1, y1)` que recibe el pintor, en px de 1x."""
    x0, y0, x1, y1 = window_box(rarity)
    inset = sum(width for _, width in _FILLETS[rarity])
    return (x0 + inset, y0 + inset, x1 - inset, y1 - inset)


def frame_color(rarity):
    """Color del papel de una rareza (el mismo en las tres)."""
    _check(rarity)
    return _CAMPO[rarity]


def _check(rarity):
    if rarity not in RARITIES:
        raise ValueError(
            "rareza desconocida %r: usa %s" % (rarity, ", ".join(RARITIES))
        )


# --------------------------------------------------------------------------- dibujo


def pixels(box):
    """Convierte un `(x0, y0, x1, y1)` de 1x al rectangulo inclusivo de 4x de PIL."""
    x0, y0, x1, y1 = box
    return [x0 * SS, y0 * SS, x1 * SS - 1, y1 * SS - 1]


def _points(values):
    return [(round(x * SS), round(y * SS)) for x, y in values]


def _rect(draw, box, **kwargs):
    draw.rectangle(pixels(box), **kwargs)


def render_card(card_id, rarity, painter):
    """Dibuja una carta completa y la devuelve como `PIL.Image` RGBA de 312 x 450."""
    _check(rarity)
    image = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # 1. Papel: el mismo campo caliza en las tres rarezas. Al final la silueta lo
    #    recorta, pero el relleno completo evita que el LANCZOS arrastre negro.
    draw.rectangle([0, 0, CANVAS[0] - 1, CANVAS[1] - 1], fill=_CAMPO[rarity])

    # 2. Ventana: filetes concentricos, de fuera hacia dentro; el ultimo deja el fondo.
    #    La Legendaria no lleva nada encima del marco: el bisel de la silueta recorta el
    #    filete de oro en las dos esquinas de arriba y esa es toda su senal.
    box = window_box(rarity)
    for color, width in _FILLETS[rarity]:
        _rect(draw, box, fill=color)
        box = (box[0] + width, box[1] + width, box[2] - width, box[3] - width)
    art = illustration_box(rarity)
    _rect(draw, art, fill=CALIZA)

    # 3. Ilustracion.
    try:
        painter(draw, art)
    except Exception as exc:  # pragma: no cover - solo para diagnosticar un lote
        raise RuntimeError("el pintor de la carta %r fallo: %s" % (card_id, exc)) from exc

    # 4. Sello de rareza, encima de la ilustracion.
    _seal(draw, rarity)

    # 5. Regla de asfalto entre la ventana y la banda.
    _rect(draw, RULE, fill=ASFALTO)

    # 6. Banda de nombre: caliza limpia, sin texto ni marcas.
    _rect(draw, BAND, fill=CALIZA)

    # 7. Pie con la marca de rareza.
    _foot(draw, rarity)

    # 8. Silueta: lo que queda fuera es transparente.
    image.putalpha(_silhouette(rarity))

    # 9. Reduccion unica a tamano final.
    out = image.resize(SIZE, Image.LANCZOS)

    # 10. La banda se reestampa a 1x. Medido: el LANCZOS deja un anillo de mezcla de
    #     ~3 px en cada borde y la pureza de la banda caia al 93,5 %; reestampada queda
    #     al 100 %. La banda es una superficie plana, no lleva detalle que perder.
    ImageDraw.Draw(out).rectangle(
        [BAND[0], BAND[1], BAND[2] - 1, BAND[3] - 1], fill=CALIZA
    )
    return out


def _seal(draw, rarity):
    art = illustration_box(rarity)
    x0 = art[2] - SEAL_MARGIN - SEAL
    y0 = art[1] + SEAL_MARGIN
    box = (x0, y0, x0 + SEAL, y0 + SEAL)
    inner = (x0 + 5, y0 + 5, x0 + SEAL - 5, y0 + SEAL - 5)

    if rarity == "Common":
        _rect(draw, box, fill=ASFALTO)
        _rect(draw, inner, outline=CALIZA, width=3 * SS)
    elif rarity == "Rare":
        _rect(draw, box, outline=AZUL_MARINO, width=2 * SS)
        _rect(draw, (x0 + 7, y0 + 7, x0 + SEAL - 7, y0 + SEAL - 7),
              outline=AZUL_MARINO, width=2 * SS)
    else:
        _rect(draw, box, fill=ROJO_SENAL)
        _rect(draw, inner, outline=CALIZA, width=3 * SS)
        cx, cy = (x0 + SEAL // 2) * SS, (y0 + SEAL // 2) * SS
        d = 10 * SS
        draw.polygon([(cx, cy - d), (cx + d, cy), (cx, cy + d), (cx - d, cy)], fill=ORO)


def _foot(draw, rarity):
    """Pie: franja de asfalto a sangre, filete de la rareza arriba y marcas dentro."""
    x0, y0, x1, y1 = FOOT
    _rect(draw, FOOT, fill=ASFALTO)
    filet = {"Common": ASFALTO, "Rare": AZUL_MARINO, "Legendary": ORO}[rarity]
    _rect(draw, (x0, y0, x1, y0 + 3), fill=filet)

    if rarity == "Common":
        for index in range(3):
            left = 108 + index * 36
            _rect(draw, (left, 429, left + 24, 433), fill=CALIZA)
    elif rarity == "Rare":
        _rect(draw, (24, 426, 288, 430), fill=CALIZA)
        _rect(draw, (24, 434, 288, 438), fill=CALIZA)
    else:
        _rect(draw, (24, 425, 288, 431), fill=ORO)
        _rect(draw, (24, 435, 288, 439), fill=CALIZA)


def _silhouette(rarity):
    """Mascara L del contorno de la carta, a 4x."""
    mask = Image.new("L", CANVAS, 0)
    draw = ImageDraw.Draw(mask)
    if rarity == "Common":
        draw.rounded_rectangle(
            [0, 0, CANVAS[0] - 1, CANVAS[1] - 1],
            radius=_CORNER["Common"] * SS,
            fill=255,
        )
    elif rarity == "Rare":
        draw.polygon(_points(_outline(0, _CORNER["Rare"])), fill=255)
    else:
        points = [
            (BEVEL, 0),
            (WIDTH - BEVEL, 0),
            (WIDTH, BEVEL),
            (WIDTH, HEIGHT - _CORNER["Legendary"]),
            (WIDTH - _CORNER["Legendary"], HEIGHT),
            (_CORNER["Legendary"], HEIGHT),
            (0, HEIGHT - _CORNER["Legendary"]),
            (0, BEVEL),
        ]
        draw.polygon(_points(points), fill=255)
    return mask


def _outline(top, corner):
    """Poligono de la carta (en px de 1x) con las esquinas cortadas en diagonal."""
    left, right, bottom = 0, WIDTH, HEIGHT
    c = corner
    return [
        (left + c, top),
        (right - c, top),
        (right, top + c),
        (right, bottom - c),
        (right - c, bottom),
        (left + c, bottom),
        (left, bottom - c),
        (left, top + c),
    ]


# ------------------------------------------------------------------- hoja de contacto

SHEET_W = 1600
SHEET_H = 1180
HAND = (104, 150)
CORNER_CROP = 120
CORNER_SCALE = 2
#: Tira de silueta al pie de la hoja: cada ilustracion a dos tonos y a 95 x 95 exactos.
SILHOUETTE = 95
SILHOUETTE_GAP = 16
SILHOUETTE_TITLE = "PRUEBA DE SILUETA \u00b7 95\u00d795"
#: Distancia al color de fondo por debajo de la cual un pixel cuenta como fondo.
SILHOUETTE_TOLERANCE = 40
RARITY_RULE = (
    "Com\u00fan: filete simple \u00b7 Rara: doble filete y esquinas achaflanadas \u00b7 "
    "Legendaria: triple filete de oro y esquinas biseladas"
)
CORNER_LABEL = {
    "Common": "redondeada r=14",
    "Rare": "chafl\u00e1n de 16 px",
    "Legendary": "bisel de 30 px",
}


def _font(size, bold=False):
    """Fuente del sistema; si no hay ninguna TTF, la de Pillow, sin fallar.

    A tamano real el nombre va en Segoe UI Semibold (`segoeuib.ttf`): Oswald y Builder
    Sans, las voces de la guia, no estan instaladas en este Windows.
    """
    if bold:
        candidates = ["C:/Windows/Fonts/segoeuib.ttf", "C:/Windows/Fonts/arialbd.ttf"]
    else:
        candidates = ["C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf"]
    for path in candidates:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                pass
    return ImageFont.load_default()


def contact_sheet(entries, path, title, labels=None, footer=None):
    """Escribe una hoja de contacto con las cartas a tamano real y a tamano de mano.

    `entries` es una lista de `(card_id, rarity, ruta_png)` o de
    `(card_id, rarity, ruta_png, etiqueta)`. `labels` traduce los ids sin etiqueta.
    """
    items = _entries(entries, labels)
    if not items:
        raise ValueError("no hay cartas para la hoja de contacto")

    per_row = 4
    rows = [items[i:i + per_row] for i in range(0, len(items), per_row)]
    last = 82 + (len(rows) - 1) * 566
    corner_label_y = last + 512
    corner_y = corner_label_y + 18
    panel_top = corner_y + CORNER_CROP * CORNER_SCALE + 28
    panel_h = 236
    #: Tira de silueta, al pie y encima de la linea de cierre.
    strip_title_y = panel_top + panel_h + 26
    strip_y = strip_title_y + 22
    strip_caption_y = strip_y + SILHOUETTE + 4
    caption_y = strip_caption_y + 20 + 26
    height = max(SHEET_H, caption_y + 38)

    sheet = Image.new("RGBA", (SHEET_W, height), ASFALTO)
    draw = ImageDraw.Draw(sheet)
    draw.text((60, 26), title, font=_font(28, bold=True), fill=CALIZA)

    for index, row in enumerate(rows):
        y = 82 + index * 566
        for column, item in enumerate(row):
            x = 60 + column * 348
            card = Image.open(item["png"]).convert("RGBA")
            sheet.alpha_composite(card, (x, y))
            _name_on_band(draw, x, y, card.size, item["label"], 26)
            draw.text((x, y + 458), item["label"], font=_font(22, bold=True), fill=CALIZA)
            subtitle = "%s \u00b7 REAL \u00b7 312\u00d7450" % RARITY_ES[item["rarity"]]
            draw.text((x, y + 484), subtitle, font=_font(16), fill=CALIZA_APAGADA)

    # Tira de esquinas a 2x: la forma del borde, no solo el color.
    draw.text(
        (60, corner_label_y),
        "ESQUINA SUPERIOR IZQUIERDA \u00b7 2\u00d7",
        font=_font(15, bold=True), fill=CALIZA_APAGADA,
    )
    for column, item in enumerate(items[:3]):
        x = 60 + column * (CORNER_CROP * CORNER_SCALE + 36)
        card = Image.open(item["png"]).convert("RGBA")
        crop = card.crop((0, 0, CORNER_CROP, CORNER_CROP))
        sheet.alpha_composite(
            crop.resize(
                (CORNER_CROP * CORNER_SCALE, CORNER_CROP * CORNER_SCALE), Image.LANCZOS
            ),
            (x, corner_y),
        )
        caption = "%s \u00b7 %s" % (
            RARITY_ES[item["rarity"]], CORNER_LABEL[item["rarity"]]
        )
        draw.text((x, corner_y + CORNER_CROP * CORNER_SCALE + 6),
                  caption, font=_font(13), fill=CALIZA_APAGADA)

    # Panel de caliza: la mesa donde se mira la mano.
    draw.rectangle([0, panel_top, SHEET_W - 1, panel_top + panel_h - 1], fill=CALIZA)
    draw.text((60, panel_top + 8), "MANO \u00b7 104\u00d7150",
              font=_font(15, bold=True), fill=ASFALTO)

    hand_top = panel_top + 28
    _hand_group(sheet, draw, items, 60, hand_top, gap=10)
    draw.text((60, hand_top + 158), "Separadas 10 px", font=_font(13), fill=ASFALTO)
    glued_x = 60 + len(items) * HAND[0] + (len(items) - 1) * 10 + 48
    _hand_group(sheet, draw, items, glued_x, hand_top, gap=0)
    draw.text((glued_x, hand_top + 158), "Pegadas \u00b7 sin separaci\u00f3n",
              font=_font(13), fill=ASFALTO)

    # Tira de silueta: la prueba de que el sujeto se lee sin color ni detalle.
    draw.text((60, strip_title_y), SILHOUETTE_TITLE,
              font=_font(15, bold=True), fill=CALIZA_APAGADA)
    for index, item in enumerate(items):
        x = 60 + index * (SILHOUETTE + SILHOUETTE_GAP)
        sheet.alpha_composite(_silhouette_thumb(item["png"], item["rarity"]),
                              (x, strip_y))
        draw.text((x, strip_caption_y), item["label"],
                  font=_font(13), fill=CALIZA_APAGADA)

    draw.text((60, caption_y), footer or RARITY_RULE, font=_font(17), fill=CALIZA_APAGADA)
    draw.text(
        (SHEET_W - 60 - _text_width(draw, "FLIP THE TABLE", _font(13)), caption_y + 2),
        "FLIP THE TABLE", font=_font(13), fill=CALIZA_APAGADA,
    )

    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)
    return path


def _name_on_band(draw, x, y, size, label, font_size):
    """Escribe el nombre sobre la banda de caliza, como lo hara el juego."""
    width, height = size
    band_top = y + round(height * BAND[1] / HEIGHT)
    band_bottom = y + round(height * BAND[3] / HEIGHT)
    band_width = round(width * (BAND[2] - BAND[0]) / WIDTH)
    margin = round(width * 6 / WIDTH)
    font = _font(font_size, bold=True)
    lines = _wrap(draw, label, font, band_width - 2 * margin)
    line_h = font_size + round(font_size * 0.30)
    top = (band_top + band_bottom - line_h * len(lines)) // 2
    for index, line in enumerate(lines):
        line_width = _text_width(draw, line, font)
        draw.text(
            (x + (width - line_width) // 2, top + index * line_h),
            line, font=font, fill=ASFALTO,
        )


def _wrap(draw, text, font, limit):
    words = text.split()
    lines, current = [], ""
    for word in words:
        candidate = (current + " " + word).strip()
        if current and _text_width(draw, candidate, font) > limit:
            lines.append(current)
            current = word
        else:
            current = candidate
    if current:
        lines.append(current)
    return lines or [text]


def _entries(entries, labels):
    out = []
    for entry in entries:
        if len(entry) == 4:
            card_id, rarity, png, label = entry
        elif len(entry) == 3:
            card_id, rarity, png = entry
            label = (labels or {}).get(card_id, card_id)
        else:
            raise ValueError("entrada de hoja de contacto invalida: %r" % (entry,))
        _check(rarity)
        out.append({"id": card_id, "rarity": rarity, "png": Path(png), "label": label})
    return out


def _paste(sheet, item, x, y, size=None):
    image = Image.open(item["png"]).convert("RGBA")
    if size is not None:
        image = image.resize(size, Image.LANCZOS)
    sheet.alpha_composite(image, (x, y))


def _hand_group(sheet, draw, items, x, y, gap):
    for index, item in enumerate(items):
        _paste(sheet, item, x + index * (HAND[0] + gap), y, HAND)
        _name_on_band(
            draw, x + index * (HAND[0] + gap), y, HAND, item["label"], 15
        )


def _silhouette_thumb(png, rarity):
    """Ilustracion a dos tonos y 95 x 95 exactos, para la tira de silueta.

    Se recorta la ventana que pinta el pintor, se reduce a 95 x 95 y cada pixel se
    lleva a uno de los dos tonos segun su distancia al color de fondo, que es el mas
    frecuente del recorte. El sujeto va en asfalto sobre caliza, o al reves si la
    ilustracion ya es clara sobre oscuro, que es lo que se lee mejor.
    """
    card = Image.open(png).convert("RGB")
    crop = card.crop(illustration_box(rarity)).resize(
        (SILHOUETTE, SILHOUETTE), Image.LANCZOS
    )
    pixels = list(crop.getdata())
    background = max(
        crop.getcolors(SILHOUETTE * SILHOUETTE), key=lambda entry: entry[0]
    )[1]
    light = (
        0.299 * background[0] + 0.587 * background[1] + 0.114 * background[2]
    ) >= 128
    subject, field = (ASFALTO, CALIZA) if light else (CALIZA, ASFALTO)
    limit = SILHOUETTE_TOLERANCE * SILHOUETTE_TOLERANCE
    tones = []
    for red, green, blue in pixels:
        distance = (
            (red - background[0]) ** 2
            + (green - background[1]) ** 2
            + (blue - background[2]) ** 2
        )
        tones.append(subject if distance > limit else field)
    thumb = Image.new("RGBA", (SILHOUETTE, SILHOUETTE))
    thumb.putdata(tones)
    return thumb


def _text_width(draw, text, font):
    box = draw.textbbox((0, 0), text, font=font)
    return box[2] - box[0]

# Fuentes de las láminas

Los PNG de `art/identidad/` se generan desde estos HTML. No son la entrega: son la forma de
regenerarla cuando cambie un color, un texto o una tipografía.

## Cómo se regeneran

Las láminas están maquetadas a **2000 × 1300 px** (1600 × 900 los conceptos de barrio usan la misma
retícula) y se capturan en un navegador Chromium a **1800 × 1170 px** de salida.

1. Descarga las tipografías a `fonts/` dentro de esta carpeta. Son todas de Google Fonts y ninguna se
   sube al juego: en Roblox se usan por `Enum.Font`.

   | Archivo | Origen |
   | --- | --- |
   | `LuckiestGuy-Regular.ttf` | `ofl/luckiestguy` |
   | `Oswald.ttf` (variable) | `ofl/oswald` |
   | `SourceSans3.ttf` (variable) | `ofl/sourcesans3` |
   | `Bangers-Regular.ttf` | `ofl/bangers` |
   | `Michroma-Regular.ttf` | `ofl/michroma` |
   | `Merriweather.ttf` (variable) | `ofl/merriweather` |
   | `Nunito.ttf` (variable) | `ofl/nunito` |
   | `PatrickHand-Regular.ttf` | `ofl/patrickhand` |

   Los rutas son las de `github.com/google/fonts`, en la rama `main`.

2. Sirve la carpeta por HTTP —las fuentes no cargan desde `file://` por CORS— y abre el HTML.

   ```powershell
   python -m http.server 8000 --bind 127.0.0.1
   ```

3. Captura a 1800 × 1170 y guarda el PNG en `art/identidad/` con el nombre que ya tiene.

## Qué genera cada archivo

| HTML | Lámina |
| --- | --- |
| `a.html` | `direccion-a.png` — identidad y tipografía de la dirección A |
| `b.html` | `direccion-b.png` — dirección B, Maqueta |
| `c.html` | `direccion-c.png` — dirección C, Cómic |
| `escrituras.html` | `direccion-a-tarjetas.png` — A1 contra A2 y el dorso (registro de la decisión) |
| `giro.html` | `direccion-a-giro.png` — carta de giro y sellos por calidad |
| `componentes.html` | `direccion-a-componentes.png` — las tres piezas aprobadas |
| `concepto-centro.html` | `concepto-centro.png` |
| `concepto-puerto.html` | `concepto-puerto.png` |
| `concepto-alta.html` | `concepto-alta.png` |

`direccion-a-tarjetas.png` está **desactualizada a propósito**: es el acta de la comparación A1/A2 y
conserva la tabla de cuatro estados anterior a la escalera de cinco pasos. La referencia de
producción es `direccion-a-componentes.png`.

## Nota

El generador 3D de estudios de masa vive aparte, en `art/blender/concept/build_concept.py`. Sus
renders no se usaron como imágenes conceptuales: no alcanzaban el nivel para aprobar una ciudad.

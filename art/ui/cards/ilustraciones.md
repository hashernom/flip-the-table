# Ilustraciones de las cartas de giro y de los perks

Guion de arte de la Tarea 3 del plan 09. Lo aprobó el responsable el 2026-11-06 con tres cartas
de ejemplo: `Multa` (común), `Huelga` (rara) y `Huracán` (legendaria).

Este documento dice **qué se dibuja** en cada una de las 20 cartas y en los 12 perks. El **cómo**
—marco, banda de nombre, pie, paleta y medidas— está en `cardlib.py` y no se cambia sin pasar por el
responsable.

## 1. Tres reglas que no se negocian

1. **Cosas y señales, nunca personas.** La ciudad del juego no tiene gente: «sin personas en la
   ciudad, los NPC no forman parte del lenguaje visual» (PRODUCT.md). Nada de figuras, cabezas,
   multitudes ni manos dentro de una carta.
2. **La ilustración se juzga a 95 × 95 px.** Si en la tira de silueta no se reconoce el sujeto, la
   ilustración no vale, por bonita que sea a tamaño real.
3. **Cuatro colores como máximo**, de la paleta de `cardlib.py`, más el contorno de asfalto. Un
   sujeto por carta. Sin tramas, sin cuadrículas decorativas, sin degradados, sin sombras difusas.

La zona superior derecha de la ventana (0,72–1,00 del ancho × 0–0,28 del alto) queda libre: ahí va el
sello de la rareza.

## 2. Lo que ya está hecho y no se toca

| Carta | Rareza | Sujeto |
| --- | --- | --- |
| `Hurricane` | Legendaria | Espiral de viento con el ojo en el centro sobre cuatro bloques de ciudad |
| `Strike` | Rara | Valla de obra de frente, con franjas diagonales, y un cono |
| `Fine` | Común | Parquímetro con el papel de multa cruzado y sello rojo |

## 3. Las 17 cartas que faltan

Cada fila dice el **sujeto** (lo que tiene que leerse a 95 px) y el **reparto de color**. El color
fondo es el de la ventana; los demás son del sujeto.

### Legendarias (4)

| Id | Nombre | Sujeto | Colores |
| --- | --- | --- | --- |
| `WorldFlip` | Mundo al Revés | La ciudad con la mitad de arriba del derecho y la mitad de abajo invertida, separadas por una línea de horizonte | asfalto profundo, caliza, acero |
| `Revolution` | Revolución | Tres galones en bucle cerrado: dos flechas que se persiguen en círculo, con una fecha de rotura | asfalto profundo, naranja obra, caliza |
| `Earthquake` | Terremoto | Dos mitades de un bloque de caliza desplazadas en vertical con una grieta en zigzag entre ellas | asfalto profundo, caliza, acero |
| `CrownStrike` | Golpe a la Corona | Corona de oro volcada, con un astillado en una punta y un estallido de impacto detrás | asfalto profundo, oro, rojo señal |

### Raras (5)

| Id | Nombre | Sujeto | Colores |
| --- | --- | --- | --- |
| `Inflation` | Inflación | Pila de monedas que crece hacia arriba, con una flecha gruesa ascendente al lado | asfalto profundo, caliza, naranja obra |
| `BounceRent` | Renta Rebotada | Moneda rebotando en una pared, con el arco de la trayectoria punteado | acero, caliza, asfalto |
| `DeedThief` | Ladrón de Escrituras | Una escritura saliendo del cuadro, tirada por un garfio, con líneas de movimiento | marino, caliza, rojo señal |
| `Backstab` | Puñalada | Un pacto roto: papel partido en dos mitades por un tajo diagonal | asfalto, caliza, rojo señal |
| `Demolition` | Demolición | Bloque de edificio con un boquete y la bola de demolición entrando con su cable | acero, caliza, asfalto |

### Comunes (8)

| Id | Nombre | Sujeto | Colores |
| --- | --- | --- | --- |
| `Shield` | Escudo | Escudo de cometa de frente, con una banda central | marino, caliza, asfalto |
| `ExtraDie` | Dado Extra | Dado en isométrico de tres caras, y un segundo dado pequeño detrás | acero, caliza, asfalto |
| `Reverse` | Marcha Atrás | Señal de cambio de sentido: flecha en U dentro de un cuadrado redondeado | asfalto, caliza, naranja obra |
| `ForcedTip` | Propina Forzada | Tarro de cristal con tres monedas dentro y una cayendo | acero, cristal azul, caliza, oro |
| `Discount` | Descuento | Etiqueta de precio con la esquina cortada y una banda diagonal roja | cristal azul, caliza, rojo señal |
| `Shove` | Empujón | Un disco-ficha siendo empujado por dos galones, con tres trazos de impulso | naranja obra, caliza, asfalto |
| `Bribe` | Soborno | Sobre abierto del que asoma una moneda, con sello | asfalto, caliza, oro |
| `Spy` | Espía | Ojo dentro de una lupa, con el mango abajo a la derecha | marino, caliza, asfalto |

## 4. Los 12 perks

Van en `art/ui/perks/`, uno por perk, **256 × 256 px**, con alfa y **monocromos en blanco**
(`#FFFFFF`), igual que los iconos de `art/ui/icons/`: el juego los tiñe con `ImageColor3`. Un solo
grosor de trazo por icono (16 px a tamaño final, dibujado a 4×), se leen a 20 px y no llevan texto.

| Id | Nombre | Sujeto |
| --- | --- | --- |
| `Banker` | Banquero | Bolsa de dinero atada, con una moneda al lado |
| `Landlord` | Casero | Llave grande, con anilla y dientes |
| `Builder` | Constructor | Martillo de orejas, de perfil |
| `Smuggler` | Contrabandista | Maletín con doble fondo marcado por una línea interior |
| `QuickFingers` | Dedos Rápidos | Dado dentro de una flecha circular que lo rodea |
| `Lawyer` | Abogado | Balanza de dos platos |
| `Negotiator` | Negociador | Dos eslabones de cadena enlazados |
| `Lucky` | Afortunado | Estrella de cuatro puntas con dos chispas |
| `Hunter` | Cazador | Mira de puntos con una flecha dentro |
| `Armored` | Blindado | Escudo con una segunda placa interior |
| `Collector` | Coleccionista | Carpeta con tres cartas asomando |
| `RestlessSoul` | Alma en Pena | Fantasma con la cola ondulada (mismo lenguaje que `art/ui/icons/ghost.png`) |

## 5. Cómo se entrega un lote

- Un módulo nuevo en `art/ui/cards/lotes/lote_<nombre>.py` con `RARITY`, `PAINTERS` y `LABELS`
  (nombre en español para la hoja de contacto). No se edita `cardlib.py` ni `build_cards.py` ni los
  módulos de otros lotes.
- Un fragmento `art/ui/cards/lotes/lote_<nombre>.manifest.json` con las entradas del manifiesto de
  sus cartas, con esta forma:

  ```json
  [
    {
      "id": "ui-card-hurricane",
      "category": "UiImage",
      "source": "art/ui/cards/build_cards.py",
      "triangles": 0,
      "lods": [],
      "textures": 0,
      "status": "Draft",
      "screenshots": [],
      "generatedWith": "Python y Pillow, art/ui/cards/build_cards.py"
    }
  ]
  ```

  El id es `ui-card-` seguido del id de la carta en kebab-case (`WorldFlip` → `ui-card-world-flip`).
  **Nadie escribe en `art/manifest.json` a mano**: los fragmentos los funde un solo paso al final.
- `python art/ui/cards/build_cards.py --lote lote_<nombre>`, que deja sus PNG y su hoja de contacto.
- El estado es `Draft` hasta que el responsable apruebe. La aprobación no la da ningún agente.

## 6. Lo que se comprueba antes de dar un lote por bueno

1. El script sale con código 0 y los PNG miden 312×450 RGBA, con las esquinas transparentes.
2. La banda de nombre (6, 294)-(306, 416) es caliza pura al 100 %.
3. Cada ilustración ocupa al menos el 70 % del ancho de su ventana.
4. Pasa la tira de silueta a 95×95 con su nombre.
5. Dos ejecuciones seguidas dan los mismos bytes.

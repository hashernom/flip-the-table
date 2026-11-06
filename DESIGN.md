---
name: Flip the Table
description: "Interfaz de partida de PC con la señalética de una avenida: chapa esmaltada, taxímetro, escritura de calle y calzada del plazo."
colors:
  asphalt: "#23272C"
  asphalt-deep: "#14171A"
  asphalt-hot: "#3A4047"
  limestone: "#EDE5D3"
  limestone-dim: "#CFC5AE"
  taxi-yellow: "#F5C518"
  taxi-lip: "#B8920F"
  signal-red: "#C4382B"
  works-orange: "#E07A3C"
  steel: "#A8AEB4"
  navy: "#1B3A6B"
typography:
  shout:
    fontFamily: "Luckiest Guy"
    fontSize: "38px"
    fontWeight: 400
    lineHeight: 1
    letterSpacing: "normal"
  road:
    fontFamily: "Oswald"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.2
    letterSpacing: "normal"
  road-bold:
    fontFamily: "Oswald"
    fontSize: "15px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "normal"
  text:
    fontFamily: "Source Sans Pro"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "normal"
  text-bold:
    fontFamily: "Source Sans Pro"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "normal"
rounded:
  plate: "16px"
  card: "14px"
  button: "18px"
  pill: "27px"
  small: "6px"
spacing:
  xs: "4px"
  s: "8px"
  m: "12px"
components:
  button-primary:
    backgroundColor: "{colors.taxi-yellow}"
    textColor: "{colors.asphalt}"
    typography: "{typography.shout}"
    rounded: "{rounded.button}"
  button-secondary:
    backgroundColor: "{colors.asphalt}"
    textColor: "{colors.limestone}"
    typography: "{typography.road}"
    rounded: "{rounded.pill}"
  button-secondary-hover:
    backgroundColor: "{colors.asphalt-hot}"
    textColor: "{colors.limestone}"
    typography: "{typography.road}"
    rounded: "{rounded.pill}"
  plate:
    backgroundColor: "{colors.asphalt}"
    textColor: "{colors.limestone}"
    typography: "{typography.road-bold}"
    rounded: "{rounded.plate}"
  money-meter:
    backgroundColor: "{colors.asphalt-deep}"
    textColor: "{colors.limestone}"
    typography: "{typography.text-bold}"
    rounded: "{rounded.small}"
  stamp-loss:
    backgroundColor: "{colors.signal-red}"
    textColor: "{colors.limestone}"
    typography: "{typography.road}"
  deed:
    backgroundColor: "{colors.limestone}"
    textColor: "{colors.asphalt}"
    typography: "{typography.road-bold}"
    rounded: "{rounded.card}"
  road-timer:
    backgroundColor: "{colors.asphalt}"
    textColor: "{colors.limestone}"
    typography: "{typography.road-bold}"
---

# Design System: Flip the Table

## Overview

**Creative North Star: "La señal de la avenida"**

La interfaz no inventa un lenguaje: toma el de una avenida de Manhattan (placas esmaltadas, franjas de calzada, toldos, la librea del taxi) y lo ordena para una partida de 2 a 8 amigos que deciden en segundos. Cada elemento se lee como una señal de calle: la placa de un jugador es una chapa con su tornillo, el dinero es un taxímetro, el plazo es una calzada que el vehículo recorre hasta el cono, y una escritura es un papel de calle con el nombre de la zona a sangre.

La densidad es alta pero ordenada. Los jugadores van en una sola columna a la izquierda, todos con el mismo ancho; la derecha es el sitio de decidir; el centro queda libre para la ciudad. La jerarquía la hacen tres cosas, en este orden: el único amarillo, el tamaño de la cifra y la forma de la marca. El color nunca carga la información solo.

Rechazos confirmados por la guía (§9): verde fieltro y estética de casino (fichas, naipes, dados, neón), degradados, sombras difusas, logotipo, personaje o tablero de Monopoly, tipografías que no vienen integradas en Roblox, y emoji o glifos de fuente como iconos.

**Estado de implementación.** La biblioteca está construida en `Theme`, `Components`, `HudRules`, `Ui` y `UiIcons`. La captura aprobada (`art/render/ui/hud-tarea1-studio.jpg`) es el destino visual. En esta rama, `Hud.luau` todavía no importa `Components`: sus paneles usan el `Theme` heredado (ver Components, «Estado»).

**Key Characteristics:**
- Chapa esmaltada: esquinas troqueladas, aro de asfalto, borde de caliza de 3 px y labio sólido.
- Un solo amarillo, el del botón de acción.
- Cifras en ventanas de taxímetro, de ancho fijo.
- Marcas por forma: sello, pieza torcida, icono, texto. Nunca solo color.
- El plazo es una calzada.
- Una columna de jugadores a la izquierda; la derecha, para decidir.

## Colors

Una paleta de bases (asfalto y caliza), un amarillo de acción y dos avisos (rojo señal y naranja obra), con un marino de sello. Los colores de zona y de jugador son datos de partida, no tokens del sistema.

### Primary
- **Amarillo taxi** (#F5C518): el único acento. Lo pinta el botón principal, con su labio en **Labio taxi** (#B8920F), la misma chapa en sombra. En los componentes, nada más es amarillo.

### Secondary
- **Rojo señal** (#C4382B): pérdida. Sellos de traidor y de legendaria, relleno de la franja de casas de una escritura, y el signo de multiplicador (×2). Como texto pequeño no sirve: sobre caliza da 4,2:1.
- **Naranja obra** (#E07A3C): aviso que no castiga. Los últimos cinco segundos del plazo, la barra de furia y la antena de bot.

### Tertiary
- **Azul marino** (#1B3A6B): sello de rareza media, con doble filete y sin relleno.

### Neutral
- **Asfalto** (#23272C): cuerpo de la chapa, pestañas, pie de la escritura y calzada.
- **Asfalto profundo** (#14171A): fondo del taxímetro, labio de la chapa, velo de los modales.
- **Asfalto de apoyo** (#3A4047): paso de color al pasar el cursor o al pulsar un botón secundario. No está en la guía §2.1; se conserva porque el build lo usa en dos sitios y lo necesita la legibilidad del hover.
- **Caliza** (#EDE5D3): texto sobre asfalto, bordes de la chapa, papel de la escritura y cuerpo del naipe.
- **Caliza apagada** (#CFC5AE): texto secundario, rótulos de sección y aro de la placa fantasma.
- **Acero** (#A8AEB4): estado desactivado de los botones secundarios y el disco fantasma.

### Named Rules
**The One Yellow Rule.** El amarillo no decora: señala. Un solo amarillo por pantalla, sobre algo que el jugador puede o debe hacer. Hoy solo el botón principal lo pinta.

## Typography

**Display Font:** Luckiest Guy (`Enum.Font.LuckiestGuy`), solo para verbos de acción.
**Body Font:** Source Sans Pro (familia integrada de Roblox; la guía la nombra `Enum.Font.SourceSans`).
**Label/Mono Font:** Oswald (familia integrada de Roblox), regular y negrita, para nombres, etiquetas, sellos y cifras de la chapa.

**Character:** Tres voces de calle. El grito solo para verbos; la vía, para nombres y etiquetas; el texto, para cuerpos. No se añade ninguna fuente.

### Hierarchy
- **Shout** (Luckiest Guy, 38 px, interlineado 1): el texto del botón principal (COMPRAR, PAGAR). Es el único uso construido. La guía fija 28–72 px y nunca menos de 28.
- **Road** (Oswald regular, 12–14 px): sellos y teclas (12 px), texto de los botones secundarios (14 px), pestaña de zona y pie de escritura (12 px), rótulos de la escritura (12 px).
- **Road bold** (Oswald negrita, 14–33 px): nombre del jugador en la chapa (14, 15 o 17 px según el tramo; +4 px en la flecha del turno), segundos del plazo (22 px), precio de la escritura (30 px), título de la escritura (33 px).
- **Text** (Source Sans regular, 14–16 px): reglas y filas de renta (15 px; 14 px en la caja de reglas), con interlineado de 1,5 en cuerpos.
- **Text bold** (Source Sans negrita, 19–25 px): cifras del taxímetro según el tramo (19, 22 o 25 px; +2 px en la flecha). El hotel y el rascacielos de la tabla de rentas van en negrita (15 px).
- **Suelo de legibilidad:** ninguna etiqueta baja de 12 px. La interfaz crece con la pantalla (ver Layout) y no encoge la letra.
- **Interletrado:** la guía pide +0,10 em en Oswald con mayúsculas. Roblox no ofrece interletrado en `TextLabel` y el build no lo aplica (ver «No canonizado» en el informe).

### Named Rules
**The Meter Window Rule.** Cada cifra de dinero va en su propia ventana de ancho fijo: un dígito ocupa la mitad del tamaño de letra y el punto, 0,28 de ese tamaño. Así el importe no baila al rodar. El dinero se escribe con punto de miles y signo de resta (−), como `1.240` y `−50`.

**The Shout Rule.** Luckiest Guy solo en verbos, en mayúsculas, nunca en párrafo y nunca por debajo de 28 px.

## Layout

- **Tamaño de diseño: 1440 × 900.** Toda la interfaz escala con un `UIScale` igual a min(ancho/1440, alto/900), limitado entre 1 y 1,6. Crece con la pantalla y nunca encoge la letra.
- **Columna de jugadores, a la izquierda.** Empieza en x = 44 px, y = 70 px. La altura de cada placa depende del número de jugadores: de 1 a 3, 92 px (flecha del turno 122, paso entre placas 104); de 4 a 5, 80 px (flecha 104, paso 92); de 6 a 8, 62 px (flecha 84, paso 70). El ancho es común a toda la columna: el del contenido más largo, acotado entre 176 y 240 px. El contrato de dirección decía 252 px; el build manda.
- **Flecha del turno.** La placa del jugador activo es una flecha de chapa que sobresale 46 px hacia la ciudad y se mece ±1° en 3,2 s. Las demás placas no se mueven.
- **Letrero de ronda.** Centrado arriba, a 14 px del borde, con dos cuerdas (componente construido, sin conectar).
- **Lado derecho, para decidir.** En la captura aprobada: minimapa arriba, escritura debajo, COMPRAR y NO COMPRAR al pie de la columna. El centro queda para la ciudad.
- **Calzada del plazo.** Ocupa el pie a todo el ancho, 36 px de alto, con un cordón de caliza de 4 px. Deja libre 100 px para la mano de cartas (`Ui.handClearance`).
- **Paneles y modales.** Ancho del 90 % de la pantalla con tope de 460 px. Las listas hacen scroll a partir del 60 % de la altura de la pantalla.
- **Medida táctil: 44 px** (`Theme.MIN_TOUCH`). El móvil queda aplazado; el valor se conserva.
- **Ritmo.** Espacio base de 8 px para relleno de paneles y separación de listas; 4 px dentro de las cifras; 12 px de sangrado en la escritura.

### Named Rules
**The Column Rule.** Los jugadores van en una sola columna a la izquierda, todos con el mismo ancho. La derecha es el sitio de decidir y el centro queda para la ciudad.

## Elevation & Depth

Sin sombras de caída, sin desenfoque y sin degradados. La profundidad se da por capas de tono (caliza sobre asfalto, asfalto sobre asfalto profundo) y por el grosor de la chapa: un labio sólido de asfalto profundo bajo cada placa, un aro de asfalto y el borde de caliza. Ese labio es el grosor de la placa esmaltada; no se difumina y no cambia de un estado a otro.

### Shadow Vocabulary
Ninguno es `box-shadow`. Son marcos desplazados, todos dibujados con geometría propia:
- **Labio de chapa** (marco de asfalto profundo, desplazado −2 px en x y +3 px en y, 4 px más grande, 45 % de transparencia, radio 18 px): cada placa de la columna. Es el grosor de la chapa.
- **Aro de chapa** (marco de asfalto, desplazado −2 px en x e y, 4 px más grande, radio 18 px): separa el labio del borde de caliza.
- **Labio de escritura** (asfalto profundo al 50 %, desplazado 7 px en y): el grosor del papel de la escritura.
- **Labio de botón** (banda de labio taxi de 8 px bajo la cara, con borde de asfalto de 3 px): el botón principal. Al pulsarlo se hunde la cara 7 px; el labio no cambia.

### Named Rules
**The Lip Is Thickness Rule.** El labio es el grosor de la placa, no una sombra: sólido, sin difuminar, sin degradado y fijo entre estados. Lo que se mueve al pulsar es la cara, nunca la sombra.

## Shapes

Esquinas troqueladas, no vivas: la chapa de jugador y los letreros redondean con radio alto; las superficies pequeñas, con radio bajo. Radios del sistema (`Ui.radius`): chapa 16 px, píldora 27 px, escritura 14 px, botón principal 18 px, taxímetro y caja de reglas 6 px. Hay radios sueltos en piezas pequeñas (sello 3 px, tecla 5 px, pestaña de zona 9 px, marcador de furia 2 px) y discos al 50 %.

Bordes: la chapa lleva un borde de caliza de 3 px; el sello común, un filete de asfalto de 1 px; el sello raro, un filete doble de marino de 2 px; la escritura y el botón principal, un borde de asfalto de 3 px.

Silueta: rectángulos con esquinas redondeadas, discos para los avatares, flecha para el turno, cordón y calzada para el plazo.

### Named Rules
**The Stamp Tilt Rule.** Lo que la calle tiene torcido se tuerce: los sellos (0°, −4° en raro, −6° en legendario y pérdida) y el balanceo de la flecha del turno. Las placas de jugador no se giran; el build las devuelve a 0° al dejar de ser turno.

## Components

Cada componente tiene su carácter, y el código ya lo construye en `src/client/ui/Components.luau`. Las medidas son las del build.

### Botón principal (`Components.PrimaryButton`)
Carácter: la placa de taxi que se hunde al pulsarla. Es el único elemento amarillo.
- **Forma:** cara de 18 px de radio; labio taxi-lip de 8 px bajo la cara; borde de asfalto de 3 px; franja de cuadros de asfalto en la parte inferior, la librea del taxi.
- **Color:** cara amarilla; texto en asfalto, Luckiest Guy 38 px centrado.
- **Estados:** al pasar el cursor, la cara baja 2 px; al pulsar, 7 px. Desactivado: cara al 45 % de transparencia y labio al 60 %.

### Botón secundario (`Components.SecondaryButton`)
Carácter: una píldora de contorno, nunca amarilla.
- **Forma:** píldora de 27 px de radio, fondo de asfalto, filete de caliza de 2 px.
- **Contenido:** texto en Oswald 14 px en mayúsculas; icono opcional de 18 px; tecla opcional (caja de caliza, texto en asfalto, Oswald 12 px, 20 px de alto, radio 5 px).
- **Estados:** al pasar el cursor, fondo de asfalto de apoyo. Desactivado: filete y texto en acero.

### Chapa (`Components.Panel`)
Carácter: la chapa esmaltada de la que sale casi todo.
- **Forma:** labio, aro y cuerpo a 16 px de radio (el aro y el labio, 18 px); borde de caliza de 3 px.
- **Color:** cuerpo de asfalto. La placa fantasma (jugador que se fue) lleva el cuerpo al 30 % y el aro en caliza apagada.

### Placa del jugador (`Components.PlayerChip`)
Carácter: una placa de la columna. Nombre, cifra y marcas, de un vistazo.
- **Contenido:** disco de avatar a la izquierda; nombre en Oswald negrita en mayúsculas; taxímetro debajo; fila de marcas a la derecha del taxímetro.
- **Marcas:** traidor (sello rojo), furia (cinco piezas torcidas que se llenan de naranja), bot (texto), se fue (texto en caliza apagada), pierde turno (texto), cartas (icono y cifra).
- **Tornillo:** punto de caliza apagada de 6 px en la esquina superior derecha, solo en las placas que no son flecha.
- **Turno:** la placa se convierte en flecha de caliza (imagen de 9 cortes que estira solo el tramo central), con el texto en asfalto.

### Disco de avatar (`Components.Disc`)
Carácter: una señal redonda. El color del asiento va en el aro.
- **Forma:** disco de 54, 68 o 78 px según el tramo; anillo exterior de asfalto de 8 px; aro de 5 px en el color del asiento (dato del jugador, no token).
- **Estados:** la corona dorada sobre el disco cuando el dato `crown` la pide; antena de asfalto con bola naranja para un bot; icono de fantasma sobre acero para un jugador que se fue.

### Taxímetro (`Components.MoneyLabel`)
Carácter: la cifra de dinero, en ventanas fijas.
- **Forma:** caja de asfalto profundo de 6 px de radio, cuatro píxeles de relleno a cada lado. Ver The Meter Window Rule.
- **Animación:** rueda de la cifra anterior a la nueva en 0,6 s con curva cúbica de salida. Al ganar o perder, sale una etiqueta que sube y se desvanece en 1,8 s, girada ±3°: rojo señal con texto caliza si resta, caliza con texto asfalto si suma.

### Sello (`Components.Stamp`)
Carácter: un sello de goma. La forma dice la rareza, no el color.
- **Pérdida y legendaria:** relleno rojo señal, texto caliza, sin borde; giro de −6°.
- **Rara:** filete marino de 2 px, texto marino, giro de −4°. (La guía pide doble filete; el build traza uno.)
- **Común:** filete fino de asfalto de 1 px, texto asfalto, sin giro.
- **Texto:** mayúsculas en Oswald 12 px.

### Escritura de propiedad (`Components.Deed`)
Carácter: un papel de calle en cartón: bloque de zona a sangre, precio en barra y la tabla de rentas. Ancho fijo de 262 px.
- **Bloque de zona:** color de la zona a sangre, 100 px de alto. El nombre va en Oswald negrita 33 px, con la tinta (caliza o asfalto) que da mejor contraste WCAG sobre el color de la zona (`HudRules.inkFor`).
- **Pestaña de zona:** pestaña de asfalto, radio 9 px, con el nombre de la zona en Oswald 12 px sobre el bloque. Está en la lámina aprobada y se conserva. Es la pestaña de la escritura, no un patrón de cabecera para otras pantallas.
- **Barra de precio:** asfalto de 40 px, con «PRECIO» en Oswald 12 px y la cifra en Oswald negrita 30 px.
- **Tabla de rentas:** filas de 23 px. Las filas de casas (segunda a cuarta) llevan un filete rojo señal de 3 px a la izquierda que las agrupa. Las filas de hotel y rascacielos van en negrita.
- **Reglas:** caja de radio 6 px con filete de asfalto de 1 px. Dos reglas que multiplican la renta, con «×2» en rojo señal en negrita.
- **Pie:** franja de asfalto de 22 px con el tipo de carta y el código.
- **Forma:** labio de 7 px en asfalto profundo al 50 % y borde de asfalto de 3 px. Ver The Lip Is Thickness Rule.

### Naipe de la mano (`Components.Card`)
Carácter: una carta de mano de papel de caliza, con título y sello. Provisional.
- **Forma:** 104 × 150 px, radio 11 px, borde de asfalto de 3 px. Título en Oswald 13 px, sello a 40 px.

### Calzada del plazo (`Components.Timer`)
Carácter: el plazo es la calzada. El vehículo recorre el pie de la pantalla y se come los trazos hasta el cono.
- **Forma:** franja de asfalto de 36 px sobre el pie, cordón de caliza de 4 px en el borde superior.
- **Contenido:** trazos naranja de 28 × 7 px con 16 px de hueco, redondeados. Los trazos ya gastados se hunden a asfalto profundo, sin velo. El vehículo (icono de taxi de 66 × 36 px) avanza según el tiempo restante; el cono (38 × 44 px) está al final del recorrido.
- **Cifra:** segundos en Oswald negrita 22 px, arriba a la derecha.
- **Aviso:** en los últimos 5 segundos, los trazos que quedan y la cifra pasan a naranja obra.

### Ventana: tablón de obra (`Board`)
Carácter: cada ventana es un tablón de obra con carteles pegados. Elegido por el responsable el 2026-11-05 entre tres maquetas, sin las barras rayadas.
- **Tablón:** chapa de asfalto de radio 6 con borde de caliza, entre dos postes de acero que asoman 16 px por arriba y por abajo. Ocupa hasta 1200 × 820 (Pactos, 900 × 620; Ajustes, 760 × 640) y sube 16 px al abrirse, con un velo de asfalto profundo.
- **Cartel:** papel de caliza de radio 3, canto inferior de 4 px un poco más oscuro y dos tiras de cinta. Solo el cartel de título va torcido (−0,4°): una lista con scroll no recorta bien girada.
- **Cabecera:** título en Oswald negrita de 44 px, Cerrar con su tecla Esc, una frase que explica la ventana y «Cómo funciona», que despliega dos o tres pasos numerados. Es igual en todas las ventanas.
- **Elegido:** se distingue por forma y tono. La pestaña elegida va rellena y las demás solo con contorno. Una escritura elegida se despega 10 px, engorda el borde y lleva sello rojo. La ficha propia va invertida, con sello «TUYA»; la ajena, en papel apagado, con el disco del asiento de su dueño.
- **Tarjeta de decisión:** papel pequeño con una franja de asfalto que dice el tipo, título en Oswald negrita y detalle. Entra repartida, se levanta 4 px al pasar el ratón y se hunde al pulsarla; un pase es una píldora de contorno.

### Named Rules
**The Marks By Shape Rule.** Las marcas se distinguen por forma: sello con filete, pieza torcida, icono, texto. El color repite la información, nunca la lleva solo.

**The Road Clock Rule.** El plazo es la calzada: el vehículo recorre el pie y el tiempo se lee en el recorrido y en la cifra, no en una barra gris.

### Estado de implementación
- `Components.luau`, `HudRules.luau`, `Theme.luau` (los tokens y `Theme.screenGui`, `Theme.modal`), `Ui.luau` y `UiIcons.luau` están construidos, y `tests/client/HudRules.spec.luau` cubre las reglas puras.
- `Hud.luau` no importa `Components`. Sus paneles, botones y temporizador usan `Theme.panel`, `Theme.button` y `Theme.font.road`, con radios de 8 px y el amarillo en el temporizador. La pantalla de la captura aprobada no sale de este código.
- `Theme.panel`, `Theme.button`, `Theme.row`, `Theme.header`, `Theme.modal` y `Theme.scrollList` son del menú anterior. Sirven a los menús y a la lista de la vista general; no se usan en pantallas nuevas de la partida.
- `Theme.space` está definido y no lo usa nada; el espacio real es 4, 8 y 12 px, en constantes sueltas.

## Do's and Don'ts

### Do:
- **Do** usar el amarillo una sola vez por pantalla, en el botón principal (#F5C518, texto asfalto, Luckiest Guy 38 px).
- **Do** distinguir zona, rareza y estado por forma además del color: símbolo, borde del sello, marca de texto, icono.
- **Do** escribir el dinero en un taxímetro de ventanas fijas, con punto de miles y signo de resta (−).
- **Do** dejar la columna de jugadores con un solo ancho común y una altura por tramo (92, 80 o 62 px).
- **Do** construir pantallas nuevas con `Components` (`PrimaryButton`, `SecondaryButton`, `Panel`, `PlayerChip`, `Deed`, `Timer`), no con `Theme.button` ni `Theme.panel`.
- **Do** tomar la tinta de un texto sobre color de zona por contraste WCAG (`HudRules.inkFor`).

### Don't:
- **Don't** usar un segundo amarillo, ni pintar en amarillo texto informativo.
- **Don't** usar verde fieltro, neón, degradados, sombras difusas ni brillos de casino.
- **Don't** usar rojo señal para texto pequeño: sobre caliza da 4,2:1 y solo pasa como texto grande.
- **Don't** escribir Luckiest Guy en párrafos, en minúsculas o por debajo de 28 px.
- **Don't** usar emoji ni glifos de fuente como iconos: los iconos son geometría propia de `art/ui/icons/`.
- **Don't** llevar la paleta de la ciudad (caliza de material #D2C9B4, ladrillo, cristal) a la interfaz: son dos paletas distintas.
- **Don't** añadir colores fuera de la paleta de la guía; el asfalto de apoyo es la única excepción y queda anotada.

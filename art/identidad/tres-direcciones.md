# Tres direcciones visuales de Metrópolis

> **Decidido el 2026-11-02: dirección A, Señalética.** La guía derivada está en
> [`../guia-de-estilo.md`](../guia-de-estilo.md) y la capa de componentes de mesa en
> [`direccion-a-tarjetas.png`](direccion-a-tarjetas.png). B y C quedan como alternativas descartadas:
> se conservan aquí como registro de la decisión, no como material vivo.

Subfase 06, Tarea 1, Paso 1. Tres mundos visuales completos para que el responsable elija uno.
Ninguna está aprobada y ninguna toca lo ya decidido: la escala (`art/escala.md`), la luz
(`art/luz.md`), la ciudad de día sin neón, la ausencia de NPCs y el tono apto para todo público
siguen intactos.

Las tres comparten los mismos hechos y se separan en una sola pregunta: **¿quién cuenta la ciudad?**
En A la cuenta la calle, con su señalética. En B la cuenta el museo, con su cartela. En C la cuenta
un dibujante, con su viñeta. Cada respuesta arrastra una paleta, dos o tres voces tipográficas, un
tratamiento de logotipo y un riesgo distinto.

Cada dirección viene con su lámina (`direccion-a.png`, `direccion-b.png`, `direccion-c.png`): la
paleta con hex y valores de Roblox, las muestras de tipografía con su `Enum.Font`, el logotipo a
tamaño real y a tamaño icono, y una franja con la misma identidad aplicada a una casilla, al HUD y a
un botón. Las láminas están construidas en el lenguaje de su propia dirección: eso también es parte
de la propuesta.

Todas las fuentes que aparecen aquí son `Enum.Font` de Roblox, comprobadas en la referencia del
motor con su valor de enum entre paréntesis. Ninguna dirección pide subir un archivo ni licenciar
nada.

---

## A — Señalética

**1. Nombre e idea.** *Señalética.* La ciudad te habla con su propia señalética: esmalte, pintura de
tráfico y toldos. Nada que parezca un tablero.

La identidad no se inventa un lenguaje: adopta el que ya está en la calle construida. Las placas
esmaltadas de las esquinas, las franjas de la calzada, los toldos de las tiendas y la librea del
taxi son el sistema gráfico. Es el único de los tres que no necesita material nuevo para existir:
el asfalto, la caliza y la franja amarilla ya están en `art/render/`.

**2. Paleta.**

| Color | Hex | RGB · Roblox | Papel |
| --- | --- | --- | --- |
| Asfalto | `#23272C` | `Color3.fromRGB(35,39,44)` | Base. Fondo de HUD, menús y fichas de estado. |
| Caliza | `#EDE5D3` | `Color3.fromRGB(237,229,211)` | Base. Placas esmaltadas, superficies claras, texto sobre asfalto. |
| Amarillo taxi | `#F5C518` | `Color3.fromRGB(245,197,24)` | Acento. Tu turno, tu ficha y la casilla activa. Uno por pantalla. |
| Rojo señal | `#C4382B` | `Color3.fromRGB(196,56,43)` | Acento. Pérdida: bancarrota, arresto, la renta que duele. |
| Naranja obra | `#E07A3C` | `Color3.fromRGB(224,122,60)` | Aviso. Reloj, última ronda, aviso que no castiga. |
| Verde fieltro | `#1F5B45` | `Color3.fromRGB(31,91,69)` | **Prohibido.** Mesa de casino. Nunca, en ninguna superficie. |

Ley: un solo amarillo por pantalla, porque el amarillo es *el turno*. El rojo aparece únicamente
cuando alguien pierde algo.

**3. Tipografía.** Tres voces, las tres integradas en Roblox: no hay que subir ni licenciar nada.

| Voz | Fuente | `Enum.Font` | Uso |
| --- | --- | --- | --- |
| Grito | Luckiest Guy | `Enum.Font.LuckiestGuy` (32) | Botones y verbos: TIRAR, COMPRAR, PAGAR, ROBAR. Nunca en párrafo ni por debajo de 28 px. |
| Titular de vía | Oswald | `Enum.Font.Oswald` (36) | Nombres de casilla y de barrio, cifras, etiquetas de HUD. Mayúsculas con tracking +0,10 em. |
| Texto | Source Sans | `Enum.Font.SourceSans` (3) | Cuerpos, descripciones, tooltips. 16 px, cifras tabulares, interlineado 1,5. |

**Por qué estas y no otras.** Oswald es la voz institucional de la calle —placas, matrículas,
horarios— y Luckiest Guy es la voz del comercio que grita su oferta. Son dos registros que conviven
en cualquier avenida real, y esa convivencia *es* el sistema: uno ordena, el otro celebra.

**4. Logotipo.** El nombre en Luckiest Guy dentro de una placa esmaltada, con borde caliza y dos
tornillos en las esquinas. A tamaño icono queda la placa amarilla con la inicial: un cuadrado de
color con una letra, que es lo que sobrevive a 32 px. El nombre es provisional y la placa lo
aguanta: dos líneas de hasta 12 caracteres, o una sola línea en Oswald con tracking si el nombre
definitivo es más largo. **Evitar:** apilar el nombre en tres líneas, curvarlo, o meterle dados y
fichas — ahí empieza el juego de mesa que este encargo prohíbe.

**5. Cómo se distingue.** Es la única de las tres que sale de lo que el jugador ya va a ver a 14,1
studs de altura, no de un sistema gráfico traído de fuera.

**6. Riesgo.** Puede leerse como señalética municipal o como app de transporte: correcta, pero sin
alma de juego. El riesgo se paga con el grito de Luckiest Guy y con el humor de los rótulos; si el
equipo no construye señalética de verdad en el mundo, A se queda en una paleta y pierde su ventaja.

---

## B — Maqueta

**1. Nombre e idea.** *Maqueta.* La ciudad se presenta como la pieza de un museo: yeso, latón y
plano. La identidad es la cartela, no el cartel.

Toma al pie de la letra la frase del estado del arte —«la ciudad se lee como una maqueta de lujo»—
y le da su aparato: la cartela de latón que la nombra, el yeso que la sostiene, el plano que la
explica. Es la dirección que no compite con la ciudad: la enmarca.

**2. Paleta.**

| Color | Hex | RGB · Roblox | Papel |
| --- | --- | --- | --- |
| Yeso | `#E7E4DA` | `Color3.fromRGB(231,228,218)` | Base. Fondo de documento y de menús claros. |
| Grafito | `#33383D` | `Color3.fromRGB(51,56,61)` | Base. Paneles, HUD, texto. |
| Latón | `#B08A3E` | `Color3.fromRGB(176,138,62)` | Acento. Dinero, propiedad y Zona Alta; solo en filetes, cifras y nombres propios. |
| Azul plano | `#24476B` | `Color3.fromRGB(36,71,107)` | Acento. El recorrido y el tablero: lo único que dibuja. |
| Carmesí | `#A33A2F` | `Color3.fromRGB(163,58,47)` | Aviso. Bancarrota y cárcel; el único rojo del sistema. |
| Verde fieltro | `#1F5B45` | `Color3.fromRGB(31,91,69)` | **Prohibido.** Mesa de casino. Nunca, en ninguna superficie. |

Ley: el latón nunca cubre un área. En cuanto el dorado ocupa una superficie deja de ser metal y se
vuelve bisutería; por eso vive en filetes de un píxel y en cifras tabulares.

**3. Tipografía.** Dos voces, las dos integradas en Roblox.

| Voz | Fuente | `Enum.Font` | Uso |
| --- | --- | --- | --- |
| Cartela | Michroma | `Enum.Font.Michroma` (34) | Nombres de barrio, títulos de escena y la cartela misma. Mayúsculas con tracking +0,18 em. |
| Rótulo y cifra | Merriweather | `Enum.Font.Merriweather` (33) | Nombres de propiedad y dinero en cifras tabulares; cursiva solo para el estado de un solar. |
| Texto | Merriweather Light | `Enum.Font.Merriweather` (33) | Descripciones y menús. 14,5 px, interlineado 1,6. |

**Por qué estas y no otras.** Michroma da la geometría de una lente de arquitecto, y Merriweather
aporta la letra de catálogo que se lee sentado. En una identidad que renuncia al grito, el serif es
lo que hace el trabajo de cercanía.

**4. Logotipo.** El nombre en Michroma, pequeño y muy espaciado, sobre una regla de latón, con
«Metrópolis · Mapa 01» en versalitas debajo. A tamaño icono queda la planta de una manzana: un
cuadrado de latón con calles recortadas, que se lee como plano incluso a 32 px. El nombre
provisional entra mientras quepa en dos líneas de 14 caracteres. **Evitar:** degradado o brillo en
el latón, un título grande —la cartela es pequeña por definición— y cualquier dado, ficha o tablero
dibujado.

**5. Cómo se distingue.** Es la única que renuncia al grito: no le habla al jugador, le presenta la
ciudad.

**6. Riesgo.** Puede quedar adulta y silenciosa para un juego de traiciones, y el latón sin PBR real
se ve amarillo barato. El conjunto corre el riesgo de leerse como un visor arquitectónico y no como
un juego de amigos; si se elige, hay que compensarlo con energía en el movimiento y en las escenas,
no en el color.

---

## C — Cómic

**1. Nombre e idea.** *Cómic.* La ciudad se dibuja: tinta, trama y bocadillo. Cada regla es una
viñeta y cada traición pide su onomatopeya.

Es la única que se toma en serio la frase de la ficha sobre que los arrestos parecen de dibujos
animados. Lleva el tono juguetón al sistema gráfico entero: contorno de tinta, trama de impresión,
dos tintas por pieza y el bocadillo como contenedor de todo lo que el juego dice.

**2. Paleta.**

| Color | Hex | RGB · Roblox | Papel |
| --- | --- | --- | --- |
| Papel | `#F2E8D5` | `Color3.fromRGB(242,232,213)` | Base. Fondo de viñeta y de paneles de menú. |
| Tinta | `#191512` | `Color3.fromRGB(25,21,18)` | Base. Contorno de todo, texto y sombra de trama. |
| Rojo tinta | `#D0402F` | `Color3.fromRGB(208,64,47)` | Aviso. Peligro y bancarrota: la palabra que grita. |
| Azul tinta | `#2A5F8F` | `Color3.fromRGB(42,95,143)` | Acento. Información, pactos y el agua del Puerto. |
| Amarillo trama | `#F0B429` | `Color3.fromRGB(240,180,41)` | Acento. Dinero y premio; siempre en medio tono, nunca en relleno plano. |
| Verde fieltro | `#1F5B45` | `Color3.fromRGB(31,91,69)` | **Prohibido.** Mesa de casino. Nunca, en ninguna superficie. |

Ley: dos tintas por pieza, nunca tres. El papel es el tercer color y no se cuenta.

**3. Tipografía.** Tres voces, las tres integradas en Roblox.

| Voz | Fuente | `Enum.Font` | Uso |
| --- | --- | --- | --- |
| Grito | Bangers | `Enum.Font.Bangers` (22) | Títulos de escena y resultados, siempre con desplazamiento de tinta de 4 px. Nunca en párrafo. |
| Rotulado a mano | Patrick Hand | `Enum.Font.PatrickHand` (37) | Solo dentro del mundo: rótulos de solar, notas del tutorial, el cartel que cuelga el dueño. Nunca en el HUD. |
| Texto | Nunito | `Enum.Font.Nunito` (35) | Todo lo que hay que leer en movimiento. 15 px, interlineado 1,5. |

**Por qué estas y no otras.** Bangers es la letra del rótulo de cómic, Patrick Hand es la del que
escribe sobre la pared y Nunito es la que se lee corriendo. La jerarquía no la marca el tamaño sino
quién escribe: el dibujante grita, el dueño anota, el juego explica.

**4. Logotipo.** El nombre en Bangers, con contorno de tinta y una segunda pasada de rojo
desplazada 4 px —el registro mal calzado de la imprenta— dentro de un bocadillo. A tamaño icono
queda la inicial en un bocadillo cuadrado. El nombre provisional entra bien, pero los nombres muy
largos piden dos líneas y bajan el tamaño del grito. **Evitar:** más de dos tintas por pieza,
sombras difusas, degradados y cualquier efecto que el cómic no haría.

**5. Cómo se distingue.** Es la única que admite el humor en el trazo: puede dibujar un arresto de
dibujos animados sin pedir permiso al resto del sistema.

**6. Riesgo.** Sobre un 3D realista como el de `art/render/`, el contorno corre el riesgo de verse
pegado como una calcomanía. La tinta gruesa come área útil en pantalla pequeña, y el conjunto puede
derivar hacia el juguete barato —justo lo contrario de la maqueta de lujo que el producto promete—.
Es la dirección con el techo más alto y el suelo más bajo.

---

## Recomendación

**Elegiría A, Señalética**, y lo razono sobre cuatro hechos y no sobre gusto:

1. **Ya está medio construida.** La calle del banco de pruebas tiene asfalto, caliza, franjas y
   toldos; A solo les pone sistema. B necesita latón de verdad y C necesita que alguien dibuje el
   mundo entero. Con A, la identidad y la ciudad avanzan juntas desde el primer día.
2. **Aguanta la cámara real.** A 14,1 studs de altura y bajo sol duro, el amarillo sobre asfalto es
   el contraste más alto de las tres paletas, y no depende de líneas finas ni de tramas que se
   pierden con la distancia y la bruma.
3. **No añade deuda de licencia.** Las tres direcciones usan solo fuentes `Enum.Font`, así que
   ninguna arriesga una subida ni un permiso; pero A es además la única que no necesita material
   que todavía no existe en el repo.
4. **Deja sitio al lujo.** El binomio caliza/asfalto permite que la Zona Alta sea de cristal y oro
   sin que la identidad cambie de carácter. B se queda corta en la calle; C se pelea con el PBR.

El riesgo de A —parecer una app de transporte— se controla con dos reglas de la propia dirección:
el amarillo nunca decora, solo señala el turno; y el grito de Luckiest Guy aparece siempre que algo
le pasa a un jugador.

**Si el responsable prioriza otra cosa, el orden cambia con claridad:**

- Si lo que hay que proteger es la percepción de **calidad y lujo**, y se acepta un juego que no le
  grite al jugador: **B**.
- Si lo que hay que proteger es la **personalidad y la diferencia** frente al resto de Roblox, y hay
  equipo para dibujar el mundo: **C**.

No recomiendo mezclar. Las tres funcionan porque son coherentes; un híbrido de la calma de B con el
grito de C produce el aspecto genérico que este encargo existe para evitar.

## Qué no decide esta entrega

- No escribe `DESIGN.md` ni `art/guia-de-estilo.md`: eso viene después de la elección.
- No reabre escala ni luz, y no propone ciudad nocturna de neón.
- No elige nombre definitivo: las tres propuestas están dibujadas con «Flip the Table» porque es el
  nombre de trabajo, y las tres explican cómo se comportan con otro.
- No fija materiales PBR, presupuesto de triángulos ni LOD: son de la guía posterior.

## Siguiente paso, cuando haya elección

1. Fijar la dirección elegida y escribir `art/guia-de-estilo.md` con los criterios de aceptación de
   `docs/02-mvp/plan-06-base-de-arte.md`: paleta, tipografía, biblioteca de materiales, aspecto
   distinto de Centro, Puerto y Zona Alta, escala de fichas, y qué evitar.
2. Escribir `DESIGN.md` desde la dirección aprobada, no antes.
3. Aplicar la paleta a la calle del banco de pruebas y mirarla con la luz real de `art/luz.md` antes
   de darla por buena.

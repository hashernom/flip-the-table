# Guía de estilo de Metrópolis

Dirección **A · Señalética**, elegida por el responsable el 2026-11-02.
Rige para todo el arte del MVP: ciudad, interfaz, tarjetas, escenas y efectos.

No reabre `art/escala.md` ni `art/luz.md`: los usa como límites. Cuando una regla de esta guía
choque con ellos, mandan ellos.

**Estado:** guía escrita y **tres imágenes conceptuales aprobadas por el responsable el 2026-11-02**.
Los ocho criterios de aceptación de la Tarea 1 quedan cubiertos. Lo único que impide implementar es
que la ficha y el motor todavía no conocen la escalera de cinco pasos.

## 1. La idea

**La ciudad te habla con su propia señalética.** La identidad no inventa un lenguaje gráfico: adopta
el que ya existe en una avenida de Manhattan —placas esmaltadas, franjas de calzada, toldos, librea
del taxi— y lo ordena. Es una identidad de *señal*, no de tablero: si algo parece impreso sobre un
cartón cuadrado, está mal.

De ahí salen las dos reglas que resuelven casi todas las dudas:

1. **El amarillo no decora: señala.** Un solo amarillo por pantalla, siempre sobre algo que el
   jugador puede o debe hacer.
2. **Lo que la ciudad tiene, la interfaz lo hereda.** Una casilla se lee como un rótulo de calle; una
   tarjeta, como una escritura municipal; un aviso de evento, como un papel pegado en la pared.

Láminas: [`identidad/direccion-a.png`](identidad/direccion-a.png) (identidad y tipografía),
[`identidad/direccion-a-tarjetas.png`](identidad/direccion-a-tarjetas.png) (escrituras y dorso) y
[`identidad/direccion-a-giro.png`](identidad/direccion-a-giro.png) (carta de giro y sellos).

## 2. Paleta

Hay **dos paletas** y no se mezclan: la de la interfaz, que el jugador mira de cerca, y la de la
ciudad, que es albedo de material bajo el sol de `art/luz.md`. Un mismo nombre —«caliza»— tiene dos
valores distintos y eso es intencionado.

### 2.1 Identidad · interfaz

| Color | Hex | Roblox | Papel | Uso |
| --- | --- | --- | --- | --- |
| Asfalto | `#23272C` | `Color3.fromRGB(35,39,44)` | Base | Fondo de HUD, menús, fichas de estado. |
| Caliza | `#EDE5D3` | `Color3.fromRGB(237,229,211)` | Base | Placas, superficies claras, texto sobre asfalto. |
| Amarillo taxi | `#F5C518` | `Color3.fromRGB(245,197,24)` | Acento | Turno, ficha propia, casilla activa, precio. |
| Rojo señal | `#C4382B` | `Color3.fromRGB(196,56,43)` | Acento | Pérdida: bancarrota, arresto, renta cobrada. |
| Naranja obra | `#E07A3C` | `Color3.fromRGB(224,122,60)` | Aviso | Reloj, última ronda, aviso que no castiga. |
| **Verde fieltro** | `#1F5B45` | `Color3.fromRGB(31,91,69)` | **Prohibido** | Nunca. Es la mesa de casino. |

Contraste medido: Caliza sobre Asfalto, **12,0:1**; Asfalto sobre Amarillo, **9,2:1**; Asfalto sobre
Naranja, **5,0:1**. El Rojo señal no sirve para texto pequeño: sobre asfalto da **2,8:1**, y con
Caliza encima, **4,2:1**, que solo pasa como texto grande (24 px, o 19 px en negrita). Por eso el
rojo va como relleno de franja, sello o punto, y la palabra que importa se escribe en Caliza o en
Asfalto.

### 2.2 Ciudad · materiales bajo el sol

Estos son los valores con los que se pinta la ciudad en Roblox. Están por debajo de los albedos que
`art/luz.md` marca como quemados: la caliza no pasa de 208.

| Material | Hex | Roblox | Nota |
| --- | --- | --- | --- |
| Piedra caliza | `#D2C9B4` | `Color3.fromRGB(210,201,180)` | Con `Limestone`; la variedad viene de la textura, no del color. |
| Ladrillo | `#B0664A` | `Color3.fromRGB(176,102,74)` | Con `Brick`; nunca saturado a rojo puro. |
| Cristal azul | `#7FB2D9` | `Color3.fromRGB(127,178,217)` | `Glass`, transparencia 0,35; refleja el cielo, no lo imita. |
| Oro | `#C9A227` | `Color3.fromRGB(201,162,39)` | Solo en Zona Alta y en detalles; nunca en superficies grandes. |
| Asfalto seco | `#4A4E54` | `Color3.fromRGB(74,78,84)` | Albedo alto para que las sombras no se coman la calle. |
| Acero pulido | `#A8AEB4` | `Color3.fromRGB(168,174,180)` | `Metal`, rugosidad 0,25. |
| Agua | `#3E7FA6` | `Color3.fromRGB(62,127,166)` | Puerto; opaca salvo en el canal. |

### 2.3 Zonas

Una zona se identifica por **color + símbolo + nombre**, nunca solo por color: la ficha exige que la
partida se lea sin depender del color. El símbolo va en la franja de la tarjeta y también pintado en
la casilla del suelo.

| # | Zona | Hex | Símbolo | Barrio |
| --- | --- | --- | --- | --- |
| 1 | Ladrillo | `#C4382B` | Cuadrado | Centro |
| 2 | Teja | `#C86A3C` | Triángulo | Centro |
| 3 | Trigo | `#E0A93B` | Círculo | Centro |
| 4 | Oliva | `#7A8B3F` | Rombo | Centro |
| 5 | Musgo | `#3F7A52` | Cruz | Centro |
| 6 | Granito | `#6E747C` | Hexágono | Centro |
| 7 | Cielo | `#3E8FC4` | Semicírculo | Puerto |
| 8 | Marino | `#2C5C8A` | Media luna | Puerto |
| 9 | Malva | `#8E6BA8` | Estrella de cuatro | Zona Alta |
| 10 | Grafito | `#2A2E33` | Anillo | Zona Alta |

Los símbolos se dibujan como geometría propia (SVG o `ImageLabel`), en un solo grosor de trazo. No
se usan glifos de fuente ni emoji.

## 3. Tipografía

Tres voces, las tres integradas en Roblox: no se sube ni se licencia ningún archivo.

| Voz | Fuente | `Enum.Font` | Tamaño | Uso |
| --- | --- | --- | --- | --- |
| Grito | Luckiest Guy | `Enum.Font.LuckiestGuy` (32) | 28–72 px | Verbos y botones: TIRAR, COMPRAR, PAGAR, ROBAR. Momentos de jugador. |
| Titular de vía | Oswald | `Enum.Font.Oswald` (36) | 12–40 px | Nombres de casilla y barrio, cifras, etiquetas de HUD. Caps con tracking +0,10 em. |
| Texto | Source Sans | `Enum.Font.SourceSans` (3) | 14–18 px | Cuerpos, descripciones, tooltips. Cifras tabulares, interlineado 1,5. |

Reglas duras:

- Luckiest Guy **nunca** en párrafo, nunca por debajo de 28 px, nunca en mayúsculas y minúsculas
  mezcladas: la fuente solo tiene una caja y no admite corrección.
- El dinero se escribe siempre con cifras tabulares y separador de miles: `1.240`, no `1,240`.
- Ninguna etiqueta baja de 12 px. En móvil se agranda la interfaz con `UIScale`, no se encoge la
  letra.

## 4. Logotipo y título

El nombre va en **Luckiest Guy** dentro de una **placa esmaltada**: rectángulo de caliza, borde
asfalto, dos tornillos en las esquinas superiores y el subtítulo en Oswald espaciado
(«METRÓPOLIS · MAPA 01»).

- **A tamaño completo**, la placa mide 500 × 130 px y el nombre va en dos líneas.
- **A tamaño icono**, la placa desaparece y queda el cuadrado amarillo con la inicial. Por debajo de
  48 px no se intenta leer el nombre completo.
- **Nombre provisional:** la placa aguanta dos líneas de hasta 12 caracteres. Si el nombre definitivo
  es más largo, se pasa a una línea en Oswald con tracking y se retira Luckiest Guy del logotipo,
  nunca se encoge la placa.

El título de una escena (por ejemplo «BANCARROTA») va en Luckiest Guy sobre asfalto, con la barra
amarilla de calzada debajo. No se le pone sombra, ni degradado, ni contorno.

## 5. Componentes

### 5.1 Tarjetas

Son el único sitio donde el juego se permite ser un objeto de mesa: la escritura de propiedad se lee
como una placa de calle en cartón y la carta de giro como un aviso pegado en la pared. Estructura de
juego de mesa —color por zona, precio y renta en tabla, escalera de cinco pasos, dorso único— sin copiar marca,
personaje ni reparto gráfico ajenos.

- Formato **380 × 570 px**, relación 2:3, escalado con `UIScale`.
- **Escritura (A2, aprobada el 2026-11-02):** bloque de zona **a sangre de 150 px** con el nombre en
  Oswald 31 dentro y el símbolo arriba a la derecha; **barra de precio** en asfalto con la cifra en
  Oswald 33; tabla de rentas en Source Sans 13,5 con cifras tabulares y la fila del rascacielos
  cerrada con una regla de 2 px; **recuadro de reglas de renta** con los dos multiplicadores ×2 —zona completa del dueño y casilla en Zona Caliente—;
  línea de Zona Caliente; pie en asfalto con el código. El color de zona ocupa un tercio de la carta:
  eso es lo que la hace leerse como carta de mesa y no como placa.
- **Giro:** papel caliza con borde asfalto, «AVISO» arriba a la izquierda, sello de calidad arriba a
  la derecha, nombre en Luckiest Guy 56 y una **banda de ilustración a sangre** de 272 px entre dos
  reglas de 2 px. La regla va en un recuadro, debajo, como el cuerpo de un aviso; después una fila de
  metadatos («Afecta · …», «Escena · … s»).
- **Dorso:** asfalto con doble marco de caliza, esquinas marcadas, placa del logotipo al centro y un
  filete rojo. **Sin amarillo**: el amarillo señalaba, no decoraba, y en el dorso no señala nada.
  Idéntico en las 20 cartas: nadie deduce la carta por el dorso.

**La escalera de construcción, en cinco pasos.** El responsable cambió la escalera el 2026-11-02: ya
no son tres niveles —casa, edificio y rascacielos— sino **solar → 1 casa → 2 casas → 3 casas → hotel
→ rascacielos**. La tarjeta enseña la escalera completa, porque es lo que se consulta a mitad de
partida:

| Estado | Renta |
| --- | --- |
| Solar sin construir | 34 |
| 1 casa | 120 |
| 2 casas | 260 |
| 3 casas | 420 |
| Hotel | 780 |
| Rascacielos | 1.100 |

Las tres filas de casas llevan un **filete rojo a la izquierda** que las agrupa: se lee que son un
tramo de tres, no tres escalones sueltos, y deja el hotel como el cambio de categoría que es. Los
importes de la tabla son de muestra para la lámina; la economía real vive en
`src/shared/config/Economy.luau`.

**La tarjeta dice lo que se cobra, no lo que cuesta.** El coste de construir es una decisión de
compra y vive en el **HUD**, junto al dinero y las acciones del turno; la escritura solo responde
«si caigo aquí, ¿cuánto pago?». Debajo de la tabla van las dos reglas que modifican esa cifra, porque
también son renta: zona completa del dueño ×2 y casilla en Zona Caliente ×2.

**Pendiente de alinear.** `docs/00-ficha/ficha-propuesta.md` todavía dice «Tres niveles: casa,
edificio y rascacielos», y el motor sigue con `maxBuildingLevel = 3` y multiplicadores `{3, 6, 10}`.
La guía dibuja la escalera nueva porque es la decisión del responsable, pero la ficha y el motor
tienen que alinearse antes de que la tarjeta se implemente en la interfaz. La ficha no la toca arte:
se avisa aquí.
La variante **A1** —franja de zona de 20 px y precio sobre el papel, sin bloque a sangre— quedó
descartada el 2026-11-02 por el responsable. La comparación entre las dos se conserva en
[`identidad/direccion-a-tarjetas.png`](identidad/direccion-a-tarjetas.png) como registro de la
decisión; no se usa como referencia de producción. Ojo: esa lámina es anterior a la escalera de cinco
pasos y solo sirve como acta.

Las tres piezas aprobadas están juntas en
[`identidad/direccion-a-componentes.png`](identidad/direccion-a-componentes.png).

### 5.2 Sellos de calidad

**La calidad no cambia el color de la carta: cambia el sello.** El papel, la tipografía y el color
son los mismos en las 20 cartas de giro; lo que distingue una legendaria es el peso de la tinta. El
sello va siempre arriba a la derecha y mide 11,5 px de alto: no crece, engorda.

| Calidad | Cartas | Sello | Se construye con |
| --- | --- | --- | --- |
| Legendaria | 5 | Bloque rojo señal, texto caliza, filete interior claro | Relleno + filete + giro −7° |
| Rara | 7 | Doble filete azul marino, sin relleno | Borde doble + giro −4° |
| Común | 8 | Contorno fino en asfalto, recto | Borde simple, 0° |

Ninguna carta usa un cuarto color para su rareza, y ninguna escribe la rareza solo con palabras: la
forma del borde ya la dice.

Detalle en [`identidad/direccion-a-giro.png`](identidad/direccion-a-giro.png).

### 5.3 HUD y botones

- **HUD:** franja de asfalto al 92 % de opacidad, punto amarillo del jugador, nombre en Oswald 15
  versalitas y dinero en Source Sans 24 tabular alineado a la derecha.
- **Botón de acción:** placa amarilla, texto asfalto en Luckiest Guy 34, borde asfalto de 2 px y
  filete interior de 2 px. Un solo botón amarillo visible a la vez.
- **Botón secundario:** contorno de caliza sobre asfalto, texto Oswald 14 espaciado. Nunca amarillo.
- **Aviso:** naranja obra en una etiqueta de esquina; si el aviso es una pérdida, rojo señal.

### 5.4 Casilla de calle

La casilla se marca en el suelo con una **barra pintada** de 7 studs de ancho y 34 de largo, en
amarillo cuando está activa y en el color de la zona cuando no. El nombre va en una placa caliza
adosada a la acera, en Oswald mayúsculas. El símbolo de zona se pinta al inicio de la barra, para
quien no distingue el color. La barra no tapa el paso de cebra ni la señalización de tráfico.

## 6. Biblioteca de materiales

Siete materiales, todos con `MaterialService.Use2022Materials = true` y `SurfaceAppearance` cuando
aporten rugosidad. El color base de la tabla 2.2 es el albedo; las texturas solo añaden variación.

| Material | Roblox | Rugosidad | Metal | Uso típico |
| --- | --- | --- | --- | --- |
| Asfalto seco | `Asphalt` | 0,90 | 0 | Calzada, aceras exteriores. Sin reflejo especular. |
| Caliza | `Limestone` | 0,75 | 0 | Fachadas de Centro, cornisas, placas. |
| Ladrillo | `Brick` | 0,85 | 0 | Fachadas de las recetas de ladrillo y balcones. |
| Cristal | `Glass` | 0,12 | 0 | Zona Alta, escaparates, marquesinas. Transparencia 0,35. |
| Acero pulido | `Metal` | 0,25 | 0,8 | Barandillas, marquesinas, grúas del Puerto. |
| Oro | `Metal` | 0,30 | 0,9 | Remates de Zona Alta, pomos, cornisas doradas. |
| Agua | `Water` | 0,05 | 0 | Canal del Puerto y fuente de la plaza. |

Ningún material usa blanco puro ni negro puro: bajo el sol de las 9,4 se queman y se pierden la
forma y la sombra.

## 7. Barrios

Los tres tienen que distinguirse de un vistazo de silueta, no solo de color.

- **Centro.** Ladrillo y caliza, toldos, 4 a 12 plantas, calles estrechas y sombra dura. La paleta
  cálida manda. Es el barrio del arranque y el que más veces se mira.
- **Puerto.** Adoquín, hierro oxidado, naves bajas y grúas; el cielo abierto pesa más que los
  edificios. El agua y el azul marino ponen el acento frío. Aquí el horizonte se ve.
- **Zona Alta.** Cristal azul, acero pulido y oro; torres de 20 a 30 plantas, plaza elevada y
  reflejos. Es el único barrio donde el oro cubre superficies, y solo en remates.

La transición entre barrios se hace con una calle, no con un cambio de paleta a mitad de manzana.

**Imágenes conceptuales.** Cada barrio tiene su lámina de corte a escala real, no una ilustración: se
aprueban proporción, paleta y soleamiento, que es lo que la guía tiene que fijar.

- [`identidad/concepto-centro.png`](identidad/concepto-centro.png) — 8 y 12 plantas, calzada de 34,
  caliza y ladrillo alternos.
- [`identidad/concepto-puerto.png`](identidad/concepto-puerto.png) — naves de 24, muelle de 60, grúa
  de 48 como único vertical.
- [`identidad/concepto-alta.png`](identidad/concepto-alta.png) — torres de 20 a 30 plantas sobre podio
  de caliza, oro solo en la coronación.

Cada lámina lleva su cota, su escala (px por stud) y una franja de soleamiento con la sombra que
proyecta el sol a 34°.

## 8. Escala

Se respeta `art/escala.md` sin cambios: avatar 6 studs, planta 7, calzada 34, acera 7, solar 18 × 22,
ficha de 9 de alto (6 de diámetro) y ojo de cámara a 14,1. El rascacielos de 92 es el techo del
juego.

La identidad compite con esa escala: una placa de calle de 2 studs de alto es legible a 14,1 desde
la calzada, y por eso las placas de casilla no llevan más de 3 palabras.

## 9. Qué evitar

- El **logotipo, el personaje o el tablero** del juego original; cualquier imitación de su reparto
  gráfico.
- **Símbolos de casino**: verde de fieltro, fichas, ruletas, naipes, dados como adorno, brillos de
  neón y carteles nocturnos.
- **Ciudad nocturna de neón.** La luz es de día y está en `art/luz.md`.
- **Degradados**, sombras difusas y dorado con brillo: el latón y el oro se leen como metal, no como
  bisutería.
- **Tipografías subidas** sin comprobar licencia. Las tres voces son `Enum.Font` y con eso se cierra
  el tema.
- **Emoji o glifos de fuente como iconos.** Los símbolos de zona se dibujan.
- **Texto en mayúsculas largas**: Luckiest Guy no tiene minúsculas y Oswald en caps solo funciona en
  etiquetas cortas.

## 10. Lo que falta para cerrar la Tarea 1

- [x] **Tres imágenes conceptuales de la ciudad** entregadas y **aprobadas por el responsable el
      2026-11-02**: `identidad/concepto-centro.png`, `identidad/concepto-puerto.png` y
      `identidad/concepto-alta.png`.
- [ ] Revisar la paleta de materiales contra una captura real con la luz de `art/luz.md` antes de
      darla por buena.
- [ ] Actualizar `art/ESTADO.md` cuando la Tarea 1 esté cerrada.

Nota sobre las imágenes: son **cortes a escala real**, no pinturas. Los estudios de masa en 3D
(`art/blender/concept/build_concept.py`) existen y se pueden renderizar, pero no alcanzan el nivel
para aprobar una ciudad: sirven para comprobar volumen, no para enseñar el barrio.

## 11. Recomendaciones

Lo que sigue no es parte del encargo: son seis cosas que, con la guía cerrada, van a doler si no se
deciden antes de la Tarea 2.

**1. Congelar la escalera en un solo sitio.** Hoy la escalera vive en tres lugares que no coinciden:
la ficha, `Economy.buildingRentMultiplier` y la tarjeta. En cuanto la ficha diga cinco pasos, el motor
debería leerlos de **una sola tabla** —niveles, multiplicador de renta y coste— para que la interfaz,
la tarjeta y el cobro no puedan divergir otra vez. Es el error más caro que puede salir de aquí.

**2. Probar los albedos con la luz real antes de modelar nada.** Los valores de la sección 2.2 son
teóricos y están calculados para no quemarse, pero `art/luz.md` ya documenta que la caliza a 214 se
quema a pleno sol. Antes de la primera fachada PBR, pintar un cubo de 7 studs con cada material y
mirarlo desde 14,1 con `ClockTime` 9,4. Media hora que ahorra rehacer siete materiales.

**3. El turno no puede depender solo del amarillo.** La guía prohíbe el color como único portador de
información en las zonas, pero el turno sigue apoyado en «un amarillo por pantalla». Un jugador
daltónico no lo verá. Añadir una segunda señal —la ficha del jugador activo con un aro, o el nombre
en la barra— cuesta poco ahora y es imposible de colar después.

**4. Construir primero la casilla, no la fachada.** La marca de suelo de la sección 5.4 aparece en
**cada turno** y se ve a 14,1 studs desde la calzada; la fachada se ve de refilón. Si la casilla no
funciona, no hay juego; si la fachada no funciona, hay una calle fea. El orden de la Tarea 3 debería
ser casilla → ficha → fachada → escena de arresto.

**5. Usar los conceptos como referencia de cámara.** Las tres láminas están a escala y con el sol a
34°. Cuando llegue la porción vertical, capturar desde la misma altura y el mismo azimut y poner la
captura al lado de su lámina. Es la forma barata de saber si la ciudad se parece a lo aprobado sin
discutir de memoria.

**6. Que el oro siga siendo un filete.** Es la regla que más fácil se rompe cuando alguien pide «más
lujo». Si el oro crece, la Zona Alta se vuelve un casino y se cae el límite de la ficha. Cuando
apriete la tentación, subir el **cristal** y el **acero**, no el oro.
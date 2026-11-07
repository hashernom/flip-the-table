# Balance de rentas: Monopoly contra nosotros

**Fecha:** 2026-11-06. **Origen:** el responsable detectó que las casillas con casas y hoteles «no dan ese vibe Monopoly de que dañan la billetera y cambian el rumbo». El documento mide la diferencia y la opción A ya está aplicada; el resto queda pendiente de decisión.

**Fuente de los números oficiales:** [Monopoly/Properties reference](https://en.wikibooks.org/wiki/Monopoly/Properties_reference), edición estadounidense clásica, y las reglas de la escalera son las del [reglamento de Hasbro](https://www.hasbro.com/common/instruct/0009.pdf). **Nuestros números:** `config/Economy` y `config/Boards` tal como están hoy (2026-11-06). **Comportamiento en la mesa:** 280 partidas de bots, 7 recuentos de jugadores × 40 semillas, modo Rondas, medidas con una sonda temporal sobre `tests/sim` que no se queda en el repositorio.

## 1. Cómo cobra Monopoly

Cada calle tiene su propia escalera impresa. No hay fórmula: los números de la carta son la regla. El grupo de color duplica **solo la renta del solar sin mejoras**; las rentas con casas ya son absolutas. La casa cuesta lo mismo en toda la zona (50, 100, 150 o 200 según el grupo), y el hotel es el sexto escalón, después de las cuatro casas.

| Calle | Precio | Casa | Solar | Con grupo | 1 casa | 2 casas | 3 casas | 4 casas | Hotel | Hotel ÷ solar |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Mediterranean Avenue | 60 | 50 | 2 | 4 | 10 | 30 | 90 | 160 | 250 | 125× |
| Baltic Avenue | 60 | 50 | 4 | 8 | 20 | 60 | 180 | 320 | 450 | 113× |
| Oriental Avenue | 100 | 50 | 6 | 12 | 30 | 90 | 270 | 400 | 550 | 92× |
| Vermont Avenue | 100 | 50 | 6 | 12 | 30 | 90 | 270 | 400 | 550 | 92× |
| Connecticut Avenue | 120 | 50 | 8 | 16 | 40 | 100 | 300 | 450 | 600 | 75× |
| St. Charles Place | 140 | 100 | 10 | 20 | 50 | 150 | 450 | 625 | 750 | 75× |
| States Avenue | 140 | 100 | 10 | 20 | 50 | 150 | 450 | 625 | 750 | 75× |
| Virginia Avenue | 160 | 100 | 12 | 24 | 60 | 180 | 500 | 700 | 900 | 75× |
| St. James Place | 180 | 100 | 14 | 28 | 70 | 200 | 550 | 750 | 950 | 68× |
| Tennessee Avenue | 180 | 100 | 14 | 28 | 70 | 200 | 550 | 750 | 950 | 68× |
| New York Avenue | 200 | 100 | 16 | 32 | 80 | 220 | 600 | 800 | 1000 | 63× |
| Kentucky Avenue | 220 | 150 | 18 | 36 | 90 | 250 | 700 | 875 | 1050 | 58× |
| Indiana Avenue | 220 | 150 | 18 | 36 | 90 | 250 | 700 | 875 | 1050 | 58× |
| Illinois Avenue | 240 | 150 | 20 | 40 | 100 | 300 | 750 | 925 | 1100 | 55× |
| Atlantic Avenue | 260 | 150 | 22 | 44 | 110 | 330 | 800 | 975 | 1150 | 52× |
| Ventnor Avenue | 260 | 150 | 22 | 44 | 110 | 330 | 800 | 975 | 1150 | 52× |
| Marvin Gardens | 280 | 150 | 24 | 48 | 120 | 360 | 850 | 1025 | 1200 | 50× |
| Pacific Avenue | 300 | 200 | 26 | 52 | 130 | 390 | 900 | 1100 | 1275 | 49× |
| North Carolina Avenue | 300 | 200 | 26 | 52 | 130 | 390 | 900 | 1100 | 1275 | 49× |
| Pennsylvania Avenue | 320 | 200 | 28 | 56 | 150 | 450 | 1000 | 1200 | 1400 | 50× |
| Park Place | 350 | 200 | 35 | 70 | 175 | 500 | 1100 | 1300 | 1500 | 43× |
| Boardwalk | 400 | 200 | 50 | 100 | 200 | 600 | 1400 | 1700 | 2000 | 40× |

Lo que hay que retener de esta tabla, porque es lo que produce la sensación que echamos de menos:

- **La escalera acelera.** Del solar al hotel, la renta se multiplica entre 40 y 125 veces según la calle; contando desde la renta con grupo, entre 20 y 62. Los saltos grandes son las dos primeras casas (×2,5 a ×3 cada una).
- **El hotel es un golpe de otro orden.** Boardwalk cobra 2000 con una cartera inicial de 1500: una sola visita arruina a quien esté entero. Park Place cobra 1500. Hasta el hotel de la calle más barata (250) se lleva una sexta parte de la cartera.
- **Lo caro rinde mejor.** La casa cuesta cuatro veces más en el grupo azul que en el marrón (200 contra 50), pero el hotel cobra ocho veces más (2000 contra 250). Por peso invertido, llegar arriba sale mejor, y por eso quien se queda con lo caro se despega.

## 2. Cómo cobrábamos antes del arreglo

> Los números de esta sección son los de partida, los que produjeron el diagnóstico. La tabla vigente está en la sección 5.

Nuestra renta no es una escalera impresa: es una fórmula. `renta = precio × 10 % × multiplicador del nivel`, y con la zona completa se aplica **además ×2 a todos los niveles**. La escalera era ×2, ×3, ×5, ×8 y ×12; cada paso cuesta el 50 % del precio y hay cinco pasos (tres casas, hotel y rascacielos).

| Zona | Precio | Solar | Con grupo | 1 casa | 2 casas | 3 casas | Hotel | Rascacielos | Coste de un paso | Inversión total |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Cobre | 60 | 6 | 12 | 24 | 36 | 60 | 96 | 144 | 30 | 210 |
| Cian | 110 | 11 | 22 | 44 | 66 | 110 | 176 | 264 | 55 | 385 |
| Magenta | 160 | 16 | 32 | 64 | 96 | 160 | 256 | 384 | 80 | 560 |
| Naranja | 210 | 21 | 42 | 84 | 126 | 210 | 336 | 504 | 105 | 735 |
| Carmesí | 250 | 25 | 50 | 100 | 150 | 250 | 400 | 600 | 125 | 875 |
| Limón | 300 | 30 | 60 | 120 | 180 | 300 | 480 | 720 | 150 | 1050 |
| Esmeralda | 350 | 35 | 70 | 140 | 210 | 350 | 560 | 840 | 175 | 1225 |
| Violeta | 400 | 40 | 80 | 160 | 240 | 400 | 640 | 960 | 200 | 1400 |

Los tableros M y L cambian los precios de cada zona, pero no la forma: la escalera es la misma proporción en todas partes.

## 3. El diagnóstico

**Primero, la escalera es plana.** Nuestros pasos multiplican por 2, 1,5, 1,67, 1,6 y 1,5. Los de Monopoly multiplican por 2–2,5, 2,5–3, 2,3–3 y luego 1,4–2,6. La diferencia no está en un número: está en que Monopoly pega tres saltos seguidos y nosotros subimos en línea recta.

| Tramo | Oficial 60 | Oficial 200 | Oficial 400 | Nuestro 60 | Nuestro 200 | Nuestro 400 |
| --- | --- | --- | --- | --- | --- | --- |
| Grupo → 1 casa | 2,50× | 2,50× | 2,00× | 2,00× | 2,00× | 2,00× |
| 1 → 2 casas | 3,00× | 2,75× | 3,00× | 1,50× | 1,50× | 1,50× |
| 2 → 3 casas | 3,00× | 2,73× | 2,33× | 1,67× | 1,67× | 1,67× |
| 3 casas → hotel | 2,59× | 1,67× | 1,43× | 1,60× | 1,60× | 1,60× |
| Hotel → rascacielos | — | — | — | 1,50× | 1,50× | 1,50× |

En el original, el tramo de tres casas a hotel pasa por las cuatro casas: son dos saltos, no uno, y por eso su multiplicador total se compara con nuestro único paso.

**Segundo, el techo es un tercio del original.** La renta con hotel es, en todas las zonas, entre el 27 % y el 37 % de la que cobraría Monopoly a ese mismo precio. Con las tres casas, entre el 29 % y el 44 %. La primera casa es la única que aguanta la comparación, y en lo barato incluso cobra de más.

| Precio | Hotel oficial | Hotel nuestro | Nuestro ÷ oficial | 3 casas oficial | 3 casas nuestras | Nuestro ÷ oficial |
| --- | --- | --- | --- | --- | --- | --- |
| 60 | 350 | 96 | 27 % | 135 | 60 | 44 % |
| 100 | 550 | 160 | 29 % | 270 | 100 | 37 % |
| 140 | 750 | 224 | 30 % | 450 | 140 | 31 % |
| 200 | 1000 | 320 | 32 % | 600 | 200 | 33 % |
| 260 | 1150 | 416 | 36 % | 800 | 260 | 33 % |
| 320 | 1400 | 512 | 37 % | 1000 | 320 | 32 % |
| 400 | 2000 | 640 | 32 % | 1400 | 400 | 29 % |

**Tercero, el daño no amenaza una cartera llena.** Es la forma más directa de decir lo que se siente en la mesa: cuántas visitas hacen falta para dejar a alguien a cero si llega con el efectivo inicial.

| Nivel | Oficial 60 | Oficial 200 | Oficial 400 | Nuestro 60 | Nuestro 200 | Nuestro 400 |
| --- | --- | --- | --- | --- | --- | --- |
| Con grupo | 0,4 % | 2,1 % | 6,7 % | 0,8 % | 2,7 % | 5,3 % |
| 1 casa | 1,0 % | 5,3 % | 13,3 % | 1,6 % | 5,3 % | 10,7 % |
| 2 casas | 3,0 % | 14,7 % | 40,0 % | 2,4 % | 8,0 % | 16,0 % |
| 3 casas | 9,0 % | 40,0 % | 93,3 % | 4,0 % | 13,3 % | 26,7 % |
| Hotel | 23,3 % | 66,7 % | 133,3 % | 6,4 % | 21,3 % | 42,7 % |
| Rascacielos | — | — | — | 9,6 % | 32,0 % | 64,0 % |

El hotel de Boardwalk se lleva una cartera y un tercio: una visita y estás fuera. El nuestro más caro se lleva el 43 %: te deja herido, no arruinado. Con el rascacielos llega al 64 %, pero para eso hacen falta cinco pasos, no tres.

**Cuarto, la inversión es la misma y el retorno la mitad.** En la zona más cara, llegar arriba cuesta 1400 en los dos juegos (precio más cinco pasos de 200). Monopoly cobra 2000 por visita; nosotros 960. Con el mismo dinero, la mitad de renta: por eso construir no se siente como una jugada que cambia la partida, sino como una mejora modesta.

## 4. Lo que pasa de verdad en la mesa

La fórmula explica la teoría, pero no cuánto aparece en una partida. Se midieron 280 partidas de bots (40 por cada número de jugadores, modo Rondas, configuración por defecto), con 4499 rentas cobradas.

| Nivel | Rentas | Media | p50 | p90 | Máximo | Se lleva ≥25 % de la caja | ≥50 % | Arruina |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sin mejoras | 4463 | 31 | 25 | 60 | 256 | 14,2 % | 5,1 % | 0 % |
| 1 casa | 6 | 165 | 160 | 256 | 256 | 100 % | 66,7 % | 0 % |
| 2 casas | 4 | 138 | 120 | 168 | 168 | 50 % | 0 % | 0 % |
| 3 casas | 4 | 350 | 220 | 560 | 560 | 100 % | 75 % | 0 % |
| Hotel | 1 | 352 | 352 | 352 | 352 | 100 % | 100 % | 0 % |
| Rascacielos | 21 | 288 | 288 | 472 | 576 | 95,2 % | 85,7 % | 9,5 % |

- **El 99,2 % de las rentas se cobran sin ninguna mejora.** Solo 22 de 4499 (0,5 %) son de hotel o rascacielos.
- **Solo el 20,4 % de las partidas llega a construir algo**, y de media hay 0,35 propiedades mejoradas por partida al terminar. Con 2 jugadores construye el 47,5 %; con 8, el 5 %.
- **La renta media es de 31**, un 2 % de la cartera inicial. El p90 son 60.
- **Cuatro rentas arruinaron a alguien en 280 partidas** (0,09 %). Ninguna de las que se cobran sin mejoras lo consiguió.
- Aun así, **el 5,1 % de las rentas sin mejoras ya se lleva media caja**: el juego no está exento de golpes, pero los golpes no vienen de los edificios.

Dos avisos sobre esta medición. El bot no negocia bien: al terminar una partida de 2 jugadores solo 12 de las 22 propiedades tienen dueño, así que completa menos zonas de las que completaría un grupo humano. Y la causa principal de que no haya hoteles no son los números, sino que **hacer la zona completa es difícil**: al final de una partida hay 0,33 zonas completas de media. Aun con números perfectos, si las zonas no se completan, los hoteles no aparecen. Las dos cosas hay que mirarlas juntas.

## 5. Qué tan grande es el arreglo

### Opción A: cambiar la escalera (aplicada el 2026-11-06)

Una línea de `Economy.buildingRentMultiplier`, de `{ 2, 3, 5, 8, 12 }` a `{ 2, 5, 12, 24, 32 }`, y un paso de redondeo nuevo, `Economy.rentRounding = 5`: toda renta se redondea hacia arriba al múltiplo de 5, para que ninguna cifra de la carta termine en un número raro. El resto de la regla no se toca: mismo precio, mismo coste por paso, mismo ×2 de zona, mismo tope ×4 de los efectos.

| Zona | Precio | Con grupo | 1 casa | 2 casas | 3 casas | Hotel | Rascacielos | Hotel ÷ cartera |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Cobre | 60 | 15 | 25 | 60 | 145 | 290 | 385 | 19,3 % |
| Cian | 110 | 25 | 45 | 110 | 265 | 530 | 705 | 35,3 % |
| Magenta | 160 | 35 | 65 | 160 | 385 | 770 | 1025 | 51,3 % |
| Naranja | 210 | 45 | 85 | 210 | 505 | 1010 | 1345 | 67,3 % |
| Carmesí | 250 | 50 | 100 | 250 | 600 | 1200 | 1600 | 80,0 % |
| Limón | 300 | 60 | 120 | 300 | 720 | 1440 | 1920 | 96,0 % |
| Esmeralda | 350 | 70 | 140 | 350 | 840 | 1680 | 2240 | 112,0 % |
| Violeta | 400 | 80 | 160 | 400 | 960 | 1920 | 2560 | 128,0 % |

La renta sin mejoras y sin zona queda en 10, 15, 20, 25, 25, 30, 35 y 40. El ×2 de la zona se aplica antes del redondeo, así que en las cuatro zonas baratas la cifra con grupo no es el doble exacto de la cifra sin mejoras (10 → 15, no 20); de 250 en adelante coinciden. Es la única consecuencia visible del redondeo, y se corrige redondeando al múltiplo más cercano en vez de hacia arriba.

Con esta escalera el hotel queda entre el 83 % y el 110 % del oficial en todos los precios, y las tres casas entre el 69 % y el 107 %. Ya no es una copia exacta —Monopoly tiene una escalera por calle y nosotros una sola para las doce— pero el golpe vuelve a ser el mismo.

Medido con la misma sonda y la misma muestra: las rentas de hotel suben de 352 a 821 de media, las bancarrotas por renta pasan de 4 a 11 (0,25 %), y el número de rentas cobradas y la duración de las partidas no cambian (4488 contra 4499). Los hoteles siguen siendo raros (el 0,5 % de las rentas), pero cuando salen, deciden.

**Tamaño real, ya hecho:** dos valores en `config/Economy` (`buildingRentMultiplier` y `rentRounding`), el redondeo en `Property.roundRent` (usado por `rentFor` y `rentTable`), las pruebas que llevaban el número viejo escrito a mano, actualizadas a la regla nueva, el importe de la escena de renta pasado a `HudRules.formatMoney` para que «1.920» no salga como «1920», y las tablas de `contenido-tablero` y `arquitectura`. `lune run tools/check` en verde, y tras los arreglos de la revisión se repitieron las cuatro suites y la simulación completa (1 504 pruebas en total). Riesgo bajo: se revierte con las mismas dos líneas.

### Opción B: una escalera por zona (fiel)

Doce zonas × seis rentas, como las cartas de verdad. Es lo único que reproduce lo que una fórmula no puede: que el hotel divida la renta del solar por 125 en la zona barata y por 40 en la cara. Tocaría un archivo de configuración nuevo, cambiar la firma de `Property.rentTable` (hoy recibe un precio; tendría que recibir la casilla o la zona), sus dos usos en el cliente (`ActionMenuRules`, `PropertyManagerRules`) y sus pruebas, además de las mismas tablas de documentación. **Medio día o un día**, con más superficie de error en los 72 números.

### Opción C: cambiar la regla

Hoy el ×2 de la zona completa se aplica también a las casas, algo que Monopoly no hace: allí el grupo solo dobla el solar. Quitarlo bajaría todas las rentas mejoradas a la mitad (el hotel de Violeta pasaría a 0,8 veces el precio) y obligaría a compensar con la escalera. Es la opción más «correcta» y la más cara: toca ficha, arquitectura y pruebas de reglas, y cambia una regla que hoy está documentada como deliberada. No la recomiendo como primer paso.

### Lo que hay que vigilar en cualquiera de las tres

- **El tope ×4.** Con la opción A, un hotel de Violeta en Zona Caliente y última ronda cobra 7680, cinco carteras iniciales. Habría que decidir si el tope baja a ×2; un ×3 no aporta nada, porque todos los efectos son dobles.
- **El efectivo inicial.** Todo esto está calculado con 1500. La configuración de partida permite de 500 a 100 000; con 500, un hotel de 1920 es una ejecución, y con 5000 no asusta. La escalera no puede ser la misma para todos los ajustes.
- **La dificultad de completar zonas.** Es la palanca que más limita que los hoteles existan. Si el objetivo es que los hoteles aparezcan, la opción A sola no lo consigue: hace falta que completar una zona sea más fácil (tratos, subastas, o reglas de construcción más laxas).

## 6. Estado

La opción A está aplicada desde el 2026-11-06: escalera `{ 2, 5, 12, 24, 32 }`, redondeo al múltiplo de 5 hacia arriba y todo lo que muestra cifras revisado (escritura, cartel de la calle, mini-escritura del tablero, escena de renta y gestor de propiedades). Queda pendiente de decisión del responsable:

- **El tope ×4**: se dejó como estaba. Si al jugarlo parece de broma, el paso útil es bajarlo a ×2 (un tope de ×3 se comporta igual que ×2, porque todos los efectos son dobles).
- **La opción B** (una escalera por zona), solo si tras jugar con personas la curva sigue sabiendo plana en las zonas baratas.
- **La opción C** (quitar el ×2 de la zona a las casas), solo si se quiere que la regla se parezca más al original.
- **El redondeo hacia arriba** deja dos consecuencias visibles. Una: en las zonas de 60 a 210, el ×2 de la zona no es el doble exacto de la cifra sin mejoras (10 → 15). Dos: el +15 % del perk Casero se lo come el redondeo en esas zonas al nivel 0 sin zona completa (6 × 1,15 = 6,9 → 10, igual que sin el perk) y, con zona, solo en Cobre (15 → 15); desde Cian con zona ya se nota (25 → 30). Si alguna de las dos molesta, se cambia a «múltiplo más cercano» y el Casero recupera parte del efecto.

## Cómo se midió

- Números oficiales: tabla de [Wikibooks](https://en.wikibooks.org/wiki/Monopoly/Properties_reference), edición estadounidense clásica.
- Nuestros números: `Property.rentTable` y `Property.rentFor` con `config/Economy` y `config/Boards`; el porcentaje sobre cartera usa el efectivo inicial por defecto (1500). Las tablas de la sección 5 ya llevan el redondeo aplicado.
- Partidas: 280 partidas de bots, 7 recuentos de jugadores (2 a 8) × 40 semillas, modo Rondas y configuración por defecto, con el mismo bucle que `tests/sim`. Se anotó cada `RentPaid` con el nivel del edificio, el precio, la caja del pagador antes de cobrar y si acabó en bancarrota. La sonda es temporal y no se versiona; el experimento de la propuesta A se hizo cambiando solo `Economy.buildingRentMultiplier` y repitiendo la misma muestra.
- Pruebas: `lune run tests/run rules`, `client`, `config` y `net`, y `lune run tools/check` al final.

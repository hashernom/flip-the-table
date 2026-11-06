# Trazado de barrios (Tarea 1 del plan 07)

**Rama:** `plan-07-barrios`, abierta desde `main` el 2026-11-05. **Estado:** los cuatro barrios
modelados, subidos e integrados, y **aprobados por el responsable el 2026-11-06** por sus láminas.
Queda la captura en el juego: es lo único que falta para pasar los assets de `Draft` a `InGame` y
`Approved`, y no es un trámite —`tools/manifest` rechaza un `Approved` sin capturas en el juego.

## Qué se ha producido

Cada barrio tiene acera, mobiliario y fondo propios, y se distinguen **por la silueta** antes que por
el color, que es lo que pide la guía en §7.

| Barrio | Acera | Mobiliario propio | Fondo | Triángulos | Mallas |
| --- | --- | --- | --- | ---: | ---: |
| Centro | losa de caliza, bordillo de granito, rejillas de metro | plátano en alcorque de fundición, farola de forja, banco, quiosco de prensa, boca de riego | 2 manzanas de 8-12 plantas con depósitos de agua y escapes de incendios | 6 308 | 37 |
| Puerto | adoquín de tres tonos, cantil de hormigón | bolardo con cadena, cajas sobre palé, farola de muelle, banco de tablón | 2 manzanas bajas con grúa de 48, contenedores y agua | 6 020 | 40 |
| Zona Alta | losa de granito, bordillo de acero | jardinera con seto, banco de diseño, farola esbelta, bolardo con filete de oro | 2 manzanas con podio de caliza y torres de 56, 70 y 90 con remate dorado | 6 616 | 26 |
| Industrial | hormigón con arqueta y rejilla | contenedor, valla de obra, palé con sacos, farola de sodio | 2 manzanas con chimeneas de 44-56 y dos silos | 7 924 | 44 |

**29 assets** en el manifiesto, todos en `Draft`; **147 mallas** en `ArtAssets.street`. Ninguno pasa su
presupuesto: el mobiliario más caro mide 1 480 triángulos (el adoquín del Puerto) y el fondo más alto,
2 900 (Industrial B), con 2 000 y 3 000 de tope.

## Código

- **`config/Barrios.luau`** — la identidad de cada barrio: acera, reglas de mobiliario (qué pieza, a
  qué distancia del eje, cada cuántas casillas), variantes de fondo y paso de cebra. Todo lo ajustable
  vive aquí; el módulo es puro y se prueba con Lune.
- **`CityLayout.dressingFor(sizeId, barrioId)`** sustituye a la versión por zona, y se suman
  `backdropsFor` y `barriosFor`. `dressedZones` desaparece de `ArtAssets`.
- **`StreetDressing.build`** recorre los barrios del tamaño y copia sus piezas; un barrio sin mallas se
  queda sin amueblar sin romper la ciudad.
- **`CityBuilder.build`** coloca el fondo de cada barrio del tamaño, y `refreshBackdrops` lo recoloca
  cuando termina la carga de mallas, que llega después que la ciudad.
- Contrato registrado como **R-P53** en [la arquitectura](../../01-arquitectura/arquitectura.md).

## Tubería

En [art/blender/city/README.md](../../../art/blender/city/README.md). Resumen:

1. `blender --background --factory-startup --python art/blender/city/<barrio>.py` genera los FBX, el
   `.blend` de revisión, las estadísticas y dos láminas en `art/render/`.
2. `art/generators/upload_city.ps1 -Prefix <barrio> -OutFile .../uploaded-<barrio>.json` sube las
   mallas por Open Cloud; es reanudable y un JSON por barrio permite subir varios a la vez.
3. `art/generators/city_assets.py <barrio>` escribe el bloque del barrio en `ArtAssets.luau` (una marca
   por barrio, para no pisar a los demás) y añade sus entradas al manifiesto en `Draft`.
4. `art/blender/city/capture.luau` monta la ciudad en Studio con el código real y devuelve el encuadre
   para la captura.

## Lo verificado

- **`lune run tools/check` en verde** sobre el árbol final: formato, lint, tipos (estándar y Roblox),
  mapas de Rojo, pruebas, motor puro, reloj y manifiesto.
- **1 332 pruebas** en 61 archivos, entre ellas 14 nuevas de `Barrios` que comprueban que cada barrio
  del tamaño amuebla todas sus casillas, que no se construye un barrio que no entra en ese tamaño y que
  el fondo va detrás de los solares.
- **147 mallas con id y 0 ids sin registrar** en el manifiesto.
- **Presupuestos** de `RepeatedProp` y `CityBackdrop` respetados, con LOD en todo el mobiliario.
- **Escala**: `centro-hydrant` cargado en Studio midió **1,14 × 2,13 × 0,90 studs**, que es lo que mide
  el modelo en Blender. Confirma la conversión de unidades y que el frente queda a -Z, el lado que
  `CFrame.lookAt` gira hacia la calle.

## Aprobación del responsable

**2026-11-06.** El responsable aprobó los cuatro barrios por sus láminas y dio por cerrado el lote de
arte. La aprobación cubre el diseño —acera, mobiliario, fondo y cómo se distinguen entre sí—, no la
colocación en el juego, que nadie ha visto todavía funcionando.

Por eso los 29 assets siguen en **`Draft`** y no se han promovido:

- `Approved` exige capturas **en el juego** (`art/PIPELINE.md` §8), y una lámina de Blender no lo es.
  `tools/manifest` rechaza la entrada sin ellas, así que marcarlo ahora rompería `lune run tools/check`
  y dejaría la rama sin poder fusionarse.
- `InGame` significa «importado y colocado»: es verdad que el código los coloca, pero afirmarlo sin
  haberlos visto cargar en Roblox sería dar por bueno algo no comprobado.

La promoción es un cambio de dos campos por asset (`status` y `approvedBy`, más `screenshots`) y se hace
en el mismo commit que las capturas.

## Lo que falta

1. **Capturas en Studio** de los cuatro barrios y de sus fronteras, y la de partida real con 2 jugadores.
2. **La prueba de fuego**: vista general con los cuatro barrios, en gris y en color.
3. **Cámara por casilla** con las 34 propiedades a nivel 5: ninguna vista puede quedar tapada.
4. **Rendimiento**. Es el riesgo abierto: la ciudad de 56 casillas suma del orden de **1 300 piezas**
   entre acera (4-7 por casilla), arbolado, mobiliario y fondo. Cabe en Roblox, pero hay que medirlo en
   el móvil de referencia en la Tarea 7, y si aprieta, el primer recorte es fundir cada pieza de
   mobiliario en una sola malla con `SurfaceAppearance` en vez de una malla por material.

## Cómo se cierra cuando haya Studio

1. Abrir el lugar con el código de esta rama sincronizado (Rojo).
2. Ejecutar `art/blender/city/capture.luau` en modo edición con el `PEDIDO` del barrio que toque: carga
   sus mallas, levanta la ciudad del tamaño, la amuebla y devuelve `posicion` y `objetivo` para la
   cámara.
3. Capturar con `screen_capture`, guardar en `art/render/ingame/` y anotar el nombre del archivo en
   `screenshots` de cada asset del manifiesto.
4. Promover a `InGame` los que se vean colocados y a `Approved` los revisados, con `approvedBy`, y
   volver a pasar `lune run tools/check`.

# Edificios de Metrópolis

Estándar de producción de las **34 propiedades** y sus **cinco añadidos** de nivel. Cada propiedad es un edificio real, propio y fijo; las mejoras no lo sustituyen.

**Estado:** borrador (2026-11-04). Pendiente de aprobación del responsable. El piloto es Cobre.

**Para modelar, sigue [blueprint.md](blueprint.md); para encargar muchas a la vez, [prompt-orquestador.md](prompt-orquestador.md).** Ahí están todas las medidas y el flujo; este documento solo da el índice y los criterios de diseño.

## Qué manda

De mayor a menor autoridad; si hay conflicto, gana el de arriba:

1. [`docs/00-ficha/ficha-propuesta.md`](../../docs/00-ficha/ficha-propuesta.md) — reglas del juego.
2. [`art/vision-visual.md`](../vision-visual.md) — cómo se ve la ciudad.
3. [`art/guia-de-estilo.md`](../guia-de-estilo.md) — identidad, paleta, materiales, barrios y escala.
4. [`blueprint.md`](blueprint.md) — medidas y flujo. Las fichas de zona dan solo el concepto de cada edificio.
5. [`art/PIPELINE.md`](../PIPELINE.md) — requisitos técnicos y de subida.
6. [`art/manifest.json`](../manifest.json) — registro y estado de cada asset.

## Índice de zonas

| # | Zona | Barrio | Props | Ficha | Estado |
| --- | --- | --- | --- | --- | --- |
| 1 | Callejón del Cobre | Centro | 2 | [01-cobre.md](zonas/01-cobre.md) | Borrador |
| 2 | Pasaje Cian | Centro | 3 | [02-cian.md](zonas/02-cian.md) | Borrador |
| 3 | Bulevar Magenta | Centro | 3 | [03-magenta.md](zonas/03-magenta.md) | Borrador |
| 4 | Feria Naranja | Centro | 3 | [04-naranja.md](zonas/04-naranja.md) | Borrador |
| 5 | Distrito Carmesí | Centro | 3 | [05-carmesi.md](zonas/05-carmesi.md) | Borrador |
| 6 | Paseo Limón | Centro | 3 | [06-limon.md](zonas/06-limon.md) | Borrador |
| 7 | Dársena Esmeralda | Puerto | 3 | [07-esmeralda.md](zonas/07-esmeralda.md) | Borrador |
| 8 | Muelle Violeta | Puerto | 2 | [08-violeta.md](zonas/08-violeta.md) | Borrador |
| 9 | Mirador Añil | Zona Alta | 3 | [09-anil.md](zonas/09-anil.md) | Borrador |
| 10 | Cumbre Blanca | Zona Alta | 3 | [10-blanca.md](zonas/10-blanca.md) | Borrador |
| 11 | Distrito Grafito | Industrial | 3 | [11-grafito.md](zonas/11-grafito.md) | Borrador |
| 12 | Sector Ocre | Industrial | 3 | [12-ocre.md](zonas/12-ocre.md) | Borrador |

Cobre y Violeta tienen **dos** propiedades; el resto, tres. Una ficha de zona nunca inventa una tercera.

## Reglas comunes

### La propiedad manda

- El edificio **es su concepto**: barbería, taller, mercado, cine o conjunto residencial de campo. No es un bloque genérico de viviendas con un local abajo.
- Un condominio abierto de campo (Vereda La Mata) o una casona (Villa Margarita) son conceptos válidos; lo que se evita es el bloque genérico con local abajo.
- Una propiedad puede ser un conjunto de volúmenes (una escuela con tres facultades y una cancha), pero sigue siendo un solo asset y una sola propiedad.
- Todas las plantas pertenecen al concepto (salón, academia, taller, almacén, oficina). Nada de «viviendas encima» como relleno.
- La zona da paleta, materiales y banda de altura; la propiedad da el tipo de edificio, la fachada y la silueta.
- Los cinco añadidos son **detalles del mismo concepto** (escaparate, toldo, chimenea, nave, rótulo), no pisos residenciales genéricos.
- Si el concepto no se reconoce en el nivel 0, el edificio está mal.

**Las fichas describen, no miden.** Las medidas viven en `blueprint.md`. Si una ficha trae una medida, no se usa.

### Solar y huella

Ver [blueprint.md](blueprint.md), sección 2.


### Alturas

Ver [blueprint.md](blueprint.md), sección 2. La altura de cada zona la decide el responsable.


### Materiales

Ver [blueprint.md](blueprint.md), sección 4. Cobre no es un material: es `Metal` teñido con el color de la zona.


### Presupuesto

Ver [blueprint.md](blueprint.md), sección 4.


### Rótulo

Placa con el nombre en letras 3D, por encima de la puerta y del toldo, como «CINE LUX». El texto forma parte del modelo.


### Cartel de venta y placa de dueño

No se modelan. La etiqueta de dueño y nivel la crea `BuildingView`.


### Añadidos y marcadores

- Cada propiedad exporta el cuerpo y 5 añadidos, con una FBX por material y color (claves en `blueprint.md`).
- Los marcadores no se modelan por propiedad: los coloca `CityLayout.levelMarkers`.


### Cámara

- Al nivel 5, desde el plano `turn` de cada casilla de la zona y de las dos vecinas, el raycast de la cámara al punto de mira no puede tocar ningún edificio.
- Si una torre de Zona Alta falla, baja o se retranquea; no se sube el techo de 92.

### Símbolos

- Un símbolo por zona, de un solo trazo, pintado en la casilla y en la tarjeta; nunca en el edificio.
- Cobre moneda, Cian onda, Magenta rombo, Naranja rayo, Carmesí llama, Limón círculo, Esmeralda media luna, Violeta estrella, Añil constelación, Blanca copo, Grafito hexágono, Ocre ladrillo.

### Ids

- Minúsculas, ASCII y guiones para el id del manifiesto; claves cortas con guion bajo para las piezas.
- La clave de `ArtAssets.properties` es el nombre exacto de `Strings`.


## Plantilla de ficha de zona

1. **Cabecera:** zona, barrio, color, símbolo y propiedades. Sin precios ni casillas.
2. **Carácter:** 3–4 líneas de qué se ve al caminar por ella.
3. **Alturas:** relación con la banda del barrio; sin medidas.
4. **Materiales:** los de la biblioteca, sin proporciones.
5. **Kit compartido:** piezas que pueden repetirse entre las propiedades.
6. **Propiedades:** una ficha por cada una (2 o 3).
7. **Referencias:** recorte del concepto de barrio y referencias reales.
8. **Estado:** `Borrador → Revisada → Aprobada`.

## Plantilla de ficha de propiedad

1. Nombre, uso y tipo de edificio.
2. Concepto: cómo se lee el negocio en el nivel 0 (2–3 líneas).
3. Masa: volumen, plantas y cubierta; sin medidas.
4. Materiales: los de la biblioteca; uno principal por malla.
5. Fachada: huecos, cornisa, toldo, entrada y escaparate.
6. Rótulo: texto (completo o forma corta), sitio, tipografía y colores; sin medidas.
7. Silueta: el elemento único.
8. Placa de dueño y cartel de venta: sitio; sin medidas.
9. Los 5 añadidos: qué detalle del negocio añade cada uno y qué marcador lleva; sin studs.
10. Cámara: nota de oclusión; sin alturas.
11. Notas técnicas: piezas reutilizables; sin presupuesto numérico.

## Flujo

1. La ficha de zona se escribe en `Borrador`.
2. El responsable la revisa en papel y la marca `Revisada` o `Aprobada`.
3. Solo se modela lo aprobado. Cada propiedad pasa el [checklist](aceptacion.md).
4. Cobre es el piloto; las demás fichas se escriben y aprueban por zona antes de modelar.
5. La Puerta B sigue siendo requisito del plan 07; el piloto puede ampliar la porción vertical, no sustituirla.

## Glosario

- **Cuerpo:** el edificio del nivel 0, sin añadidos.
- **Añadido:** pieza que se suma en un nivel; nunca sustituye al cuerpo.
- **Marcador:** pieza pequeña que indica el nivel; la genera el código, no el modelo.
- **Kit de zona:** piezas que se comparten entre propiedades de la misma zona.
- **LOD1:** versión reducida de la propiedad, obligatoria.

## Documentos hermanos

- [niveles.md](niveles.md) — contrato de los cinco añadidos.
- [aceptacion.md](aceptacion.md) — checklist comprobable.
- [Guía de estilo](../guia-de-estilo.md) · [Visión visual](../vision-visual.md) · [Tubería](../PIPELINE.md) · [Contenido del tablero](../../docs/02-mvp/contenido-tablero.md)

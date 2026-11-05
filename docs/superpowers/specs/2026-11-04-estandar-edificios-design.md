# Estándar de edificación de Metrópolis — diseño

**Fecha:** 2026-11-04
**Rama:** `plan-06-porcion-pc`
**Estado:** propuesto; pendiente de revisión del responsable
**Ámbito:** las 34 propiedades, sus 5 añadidos de nivel y las 12 zonas. No incluye modelar ni programar.

## 1. Problema

El estándar técnico de arte está escrito (`art/PIPELINE.md`), pero el diseño no: de las 34 propiedades solo existen nombre y color. La guía de estilo, además, está desactualizada en lo que más consultaría un modelador (10 zonas de otro diseño, 3 barrios, solar de 18 × 22). Sin un catálogo por propiedad, 34 edificios modelados por agentes distintos no mantienen un estándar común.

## 2. Objetivo y no objetivos

**Objetivo.** Que cualquier agente pueda modelar una propiedad y sus cinco añadidos sin tomar decisiones de diseño, y que el responsable pueda aprobarla con una lista comprobable.

**No objetivos.** Modelar, programar el rótulo o la placa, aprobar la Puerta B, ni medir rendimiento. Este documento produce el estándar; la producción va después.

## 3. Decisiones acordadas

1. **Híbrido con detalle:** ficha por zona + ficha por propiedad con identidad, masa, materiales, rótulo, silueta y los 5 añadidos.
2. **Los cinco añadidos son propios de cada propiedad**, con piezas geométricas reutilizables dentro de la zona.
3. **Estructura B:** guía corregida + 12 fichas de zona + contrato de niveles + checklist.
4. **Rótulo:** placa de caliza modelada + `SurfaceGui` con el texto desde `Strings`, mediante `SignAnchor`. Las fichas nuevas no hornean letras; el Cine Lux existente se conserva como referencia hasta que se reexporte.
5. **Placa de dueño y cartel de venta:** los crea el código en un `PlaqueAnchor`; el modelo no los modela.
6. **La propiedad manda:** el edificio es su concepto —negocio o conjunto residencial de campo—, no un bloque genérico de viviendas con un local abajo; todas las plantas y los añadidos pertenecen al concepto. Una propiedad puede ser un conjunto de volúmenes (una escuela con tres facultades y una cancha), pero es un solo asset.
7. **Las fichas describen, no miden:** las medidas, alturas y presupuestos viven en `art/escala.md`, `art/PIPELINE.md` y `niveles.md`; la ficha de zona no repite números de diseño.

## 4. Fuentes de verdad

De mayor a menor autoridad; si hay conflicto, gana el de arriba, y los presupuestos técnicos no se negocian:

1. `docs/00-ficha/ficha-propuesta.md` — reglas del juego.
2. `art/vision-visual.md` — cómo se ve la ciudad.
3. `art/guia-de-estilo.md` — identidad, paleta, materiales, barrios y escala.
4. `art/edificios/zonas/*.md` — diseño de cada zona y propiedad.
5. `art/PIPELINE.md` — requisitos técnicos y de subida.
6. `art/manifest.json` — registro y estado de cada asset.

## 5. Archivos

```
art/edificios/
  README.md          índice, reglas comunes, plantillas y glosario
  niveles.md         contrato de los 5 añadidos y de los marcadores
  aceptacion.md      checklist comprobable (técnico + visual)
  zonas/
    01-cobre.md
    02-cian.md
    ...
    12-ocre.md
```

Además se corrige `art/guia-de-estilo.md` en su sitio (véase §9) y se actualizan `art/ESTADO.md` y `art/PIPELINE.md` con enlaces.

## 6. Reglas comunes

### 6.1 Solar y huella

- Solar de **36 × 22** (el de `CityLayout`). El 18 × 22 de la guía es viejo y se corrige. Sigue pendiente medirlo con edificios reales (`ESTADO.md`, punto 6).
- Huella máxima **32 × 18**; mínima **18 × 12**.
- Fachada a 2 studs del borde del solar; 4 studs de separación lateral; nada invade acera ni calzada.
- Origen del asset en el centro de la base, a ras de suelo.

### 6.2 Alturas

- Planta de 7 studs. Altura = 7 × plantas + cubierta, nunca más de **92**.
- La planta baja mide 7 studs. Puertas de 6,0–6,5; portalones de 6,5–7,0. El avatar mide 6: una puerta de 3 no es modelable.
- Bandas por barrio:

| Barrio | Plantas | Altura final (studs) |
| --- | --- | --- |
| Centro | 4–12 | 28–88 |
| Puerto | 2–4 | 14–32 |
| Zona Alta | 8–13 | 56–92 |
| Industrial | 2–6 | 14–46 (chimeneas y silos hasta 60) |

La guía decía Zona Alta de 20–30 plantas; a 7 studs por planta serían 140–210 y el techo es 92. Se corrige a 8–13. La banda es la altura final al nivel 5, cubierta incluida; la ficha fija el cuerpo y los añadidos dentro de ella.

La ficha distingue masa y altura total: la masa es el cuerpo; la total incluye chimeneas, rótulos y remates. El cuerpo se calcula como la altura de masa menos la suma de sus añadidos.

- Nivel 0 es el cuerpo. Incrementos de los añadidos:

| Nivel | Qué añade | Studs |
| --- | --- | --- |
| 1 | Entrada, cornisa o toldo | 0–2 |
| 2 | Huecos, balcón o mejora de fachada | 0–2 |
| 3 | Cubierta o planta técnica | 0–2 |
| 4 | Bloque de hotel | 3–6 |
| 5 | Coronación o torre | 6–12 |

- Total nunca superior a **+20** sobre el cuerpo; el nivel 5 nunca pasa de 92; el cuerpo no se sustituye en ningún nivel.

### 6.3 Materiales

- Los 7 de la guía más Pizarra (cubiertas), Lona (toldos) y Hierba (jardineras), que ya usan los modelos. No se inventan materiales nuevos. Por propiedad: principal 60–80 %, secundario 15–30 %, acento ≤ 10 %.
- Cada malla lleva un material principal; la propiedad combina solo materiales de la biblioteca.
- Cobre es `Metal` teñido con el color de zona; el cristal va oscuro (46, 74, 99).
- Oro solo en Zona Alta y solo en remates; cristal con transparencia 0,35; nada de blanco ni negro puros.
- Texturas opcionales, CC0 y documentadas. Hasta validar `SurfaceAppearance`, el color de la paleta es la fuente.

### 6.4 Presupuesto y requisitos técnicos

- Propiedad completa al nivel 5: **≤ 10 000 triángulos**. Reparto: cuerpo (incluida la placa del rótulo) ≤ 6 000; añadidos ≤ 4 000 en total y ≤ 1 000 cada uno. La ficha puede apretar; si lo hace, manda la ficha.
- Una `_LOD1` por propiedad, ≤ 50 % de triángulos (como `cine-lux`: 3 042 → 1 354) y estanca, sin aristas de borde. El manifiesto tiene una entrada por propiedad y sus piezas van en `assetIds`.
- Malla estanca, cuads, sin n-gons, con volumen, tangentes si hay normal map.
- 1 unidad de Blender = 1 stud; exportación según `PIPELINE.md`.

### 6.5 Rótulo de fachada

- Cada propiedad lleva su nombre en la fachada que da a la calle, sobre la entrada o a dos tercios de altura.
- Placa de caliza de **6–10 studs de ancho y 1,5–2,5 de alto**, ≤ 500 tris, borde del color de la zona. Va por encima de la puerta y del toldo; la ficha fija la altura, habitualmente 7,0–8,0.
- El texto no se modela: `SurfaceGui` creado por el cliente desde `Strings`, en Oswald mayúsculas, 2 líneas como máximo, asfalto sobre caliza. Si el nombre completo no cabe, la ficha fija una forma corta aprobada; el nombre completo sigue en la tarjeta y el HUD.
- El modelo aporta un `SignAnchor` (Attachment) en el centro de la placa, mirando a la calle.
- `llaneradas.com` es el único caso especial: «llaneradas» grande y «.com» pequeño.
- Ningún otro texto en fachada; prohibidos los rótulos genéricos («HOTEL», «BANK»).

### 6.6 Cartel de venta y placa de dueño

- Un solo `PlaqueAnchor` a la derecha de la entrada, a 2,5–3 studs de altura.
- La placa (4 × 2) la crea el código, no el modelo.
- Sin dueño: caliza con «EN VENTA» en asfalto; el precio no va en la placa.
- Con dueño: fondo del color de asiento (los 8 de `main.client.luau`), número de asiento en caliza y borde oscuro.

### 6.7 Añadidos y marcadores

- Cada propiedad exporta cuerpo + 5 piezas (`<id>-addon1` … `<id>-addon5`), independientes, con origen en el centro de la base.
- Semántica de los niveles según §6.2. Cada paso cambia silueta o contraste, no solo 2 studs.
- Cada añadido es un detalle del negocio, no una planta residencial genérica.
- **Los marcadores no se modelan:** los genera `CityLayout.levelMarkers`. El modelador que los añade duplica el trabajo.
- Piezas compartibles dentro de la zona, pero cada propiedad describe su secuencia.
- Materiales de la biblioteca; uno principal por malla.

### 6.8 Cámara

- Prueba al nivel 5: desde el plano `turn` de cada casilla de la zona y de las dos vecinas, un raycast de la cámara al punto de mira no puede tocar ningún edificio.
- Si una torre de Zona Alta falla, baja o se retranquea; no se sube el techo de 92.
- Captura desde cada casilla y vista general: todo visible y nada flotando.

### 6.9 Símbolos de zona

- Un símbolo por zona, dibujado como geometría de un solo trazo, pintado en la casilla y en la tarjeta; nunca en el edificio.
- Propuesta: Cobre moneda, Cian onda, Magenta rombo, Naranja rayo, Carmesí llama, Limón círculo, Esmeralda media luna, Violeta estrella, Añil constelación, Blanca copo, Grafito hexágono, Ocre ladrillo.
- Su implementación en código es una tarea aparte.

### 6.10 Ids y manifiesto

- Id en minúsculas, ASCII y guiones; sin espacios ni acentos.
- Mallas dentro de la propiedad: `<id>-body`, `<id>-addon1` … `<id>-addon5`; la versión reducida de la propiedad es `<id>_LOD1`.
- El id del FBX, el del manifiesto y el que use `src/` son el mismo texto.
- La clave visible sigue siendo el nombre de `Strings`; el id no se muestra al jugador.

## 7. Plantillas

### 7.1 Ficha de zona

Cabecera (zona, barrio, color, símbolo y propiedades), carácter, relación con la banda de altura, materiales, kit compartido, las 2 o 3 propiedades y referencias. Estado: `Borrador → Revisada → Aprobada`.

### 7.2 Ficha de propiedad

1. Nombre, uso y tipo de edificio.
2. Concepto: cómo se lee el negocio en el nivel 0 (2–3 líneas).
3. Masa: volumen, plantas y cubierta; sin medidas.
4. Materiales: los de la biblioteca; uno principal por malla.
5. Fachada: huecos, cornisa, toldo, entrada y escaparate.
6. Rótulo: texto (nombre completo o forma corta), sitio, tipografía y colores; sin medidas.
7. Silueta: el elemento único.
8. Placa de dueño y cartel de venta: sitio; sin medidas.
9. Los 5 añadidos: qué detalle del negocio añade cada uno y qué marcador lleva; sin studs.
10. Cámara: nota de oclusión; sin alturas.
11. Notas técnicas: piezas reutilizables y LOD; sin presupuesto numérico.

### 7.3 Ejemplo: Barbería Morro

- **Zona:** Cobre (Centro).
- **Uso:** barbería con academia de barberos.
- **Concepto:** edificio de barbería con escaparate alto, poste vertical, toldo a rayas y marco de rótulo en cubierta; las plantas altas son academia y salón, no viviendas.
- **Masa:** cuatro plantas, la baja a la altura de la calle; cubierta plana con marco de rótulo y tanque; cornisa de caliza.
- **Materiales:** caliza y ladrillo, con cristal, acero, lona y cobre.
- **Fachada:** escaparate alto y puerta a la altura del avatar; poste entre escaparate y puerta; ventanales de academia; cornisa.
- **Rótulo:** placa sobre la puerta y el toldo, «BARBERÍA MORRO»; `SignAnchor`.
- **Silueta:** poste de barbero y marco de rótulo en cubierta.
- **Placa:** a la derecha de la puerta; `PlaqueAnchor`.
- **Añadidos:** 1) toldo a rayas y banda de azulejo; 2) vitrina y escaparate alto; 3) mirador de la academia; 4) pabellón de hotel; 5) torre de rótulo.
- **Cámara:** probar con el plano `turn`.
- **Técnico:** presupuesto del estándar; LOD1 estanca; materiales de la biblioteca.

## 8. Checklist de aceptación

**Técnico**

- [ ] Una entrada en el manifiesto por propiedad, categoría `Building`, con las piezas en `assetIds`.
- [ ] Presupuesto cumplido y `_LOD1` que reduce triángulos.
- [ ] Malla estanca, cuads, sin n-gons, con volumen.
- [ ] Origen en el centro de la base; 1 unidad = 1 stud.
- [ ] Materiales de la biblioteca; uno principal por malla; oro solo en Zona Alta y en remate.
- [ ] `SignAnchor` y `PlaqueAnchor` presentes y orientados; placa ≤ 500 tris.
- [ ] Huella dentro del solar; sin invadir acera; altura ≤ ficha y ≤ 92.
- [ ] Cuerpo + 5 añadidos, sin sustituir el cuerpo.

**Visual**

- [ ] Se reconoce desde el plano `turn`.
- [ ] Rótulo legible; zona por color y símbolo.
- [ ] Silueta distinta de las dos vecinas; nada genérico.
- [ ] Nivel 5 reconocible como el mismo edificio.
- [ ] Raycast de cámara limpio en la zona y las vecinas.
- [ ] Sin marca ajena, casino, neón ni verde de fieltro.
- [ ] Capturas en el juego, no en Blender.

**Aprobación**

- [ ] Tres capturas en el juego (calle, turno y vista general).
- [ ] `InGame` → `Approved` con `approvedBy`.

## 9. Correcciones a la guía de estilo

1. §2.3: sustituir las 10 zonas antiguas por las 12 reales (Cobre…Ocre) con color de `Strings`, símbolo y barrio.
2. §7: cuatro barrios, con Industrial; Zona Alta 8–13 plantas; Centro 4–12; Puerto 2–4.
3. §8: solar 36 × 22 (provisional), no 18 × 22.
4. §5.1: retirar el aviso «Pendiente de alinear» de la escalera; `ESTADO.md` la da por alineada.
5. §5.1: aclarar que los marcadores los genera el código y que los añadidos son piezas del modelo.
6. §10: actualizar la lista de pendientes con los documentos nuevos.
7. Añadir enlace a `art/edificios/README.md` como fuente del diseño de edificios.
8. §6: añadir Pizarra, Lona y Hierba como materiales secundarios, ya usados por los modelos.

## 10. Pendientes y riesgos

- **Solar 36 × 22 provisional:** medir con edificios reales antes de producir en masa.
- **Albedos sin validar con la luz real:** probar los 7 materiales antes de las fachadas (`ESTADO.md`, punto 1).
- **`SurfaceAppearance` sin probar en una malla del juego:** hasta entonces, `MaterialVariant`.
- **Studio bajo Vinegar inestable:** sin capturas fiables no se puede aprobar en el juego (`ESTADO.md`, punto 7).
- **Puerta B sin aprobar:** modelar por delante del plan 07 arriesga rehacer; el piloto de Cobre puede ampliar la porción vertical, no sustituir la puerta.
- **Rendimiento aplazado:** 34 edificios × 10 000 tris es un riesgo de memoria en el tablero de 56; medir antes de la producción completa.
- **Rótulo, placa y símbolos necesitan código** (`BuildingView`, `CityBuilder`, `CityLayout`): es una tarea aparte de la modelación.

## 11. Criterios de aceptación del estándar

- [ ] La guía no contradice a `Strings`, `CityLayout` ni `ESTADO.md`.
- [ ] Las 12 fichas de zona existen y siguen la plantilla.
- [ ] Las 34 fichas de propiedad describen sus 5 añadidos.
- [ ] `niveles.md` y `aceptacion.md` existen y no duplican reglas contradictorias.
- [ ] El índice enlaza todo y marca el estado de cada ficha.
- [ ] El piloto de Cobre se aprueba en papel antes de modelar.

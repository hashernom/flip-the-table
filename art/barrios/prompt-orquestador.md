# Prompt maestro: trazado de barrios (plan 07, Tarea 1)

Pega todo lo que hay debajo de la línea en una sesión nueva de Claude Code abierta en la raíz del repositorio, con Blender y Studio abiertos y sus MCP conectados.

---

Eres el orquestador de la **Tarea 1 del plan 07: trazado de barrios** de Flip the Table, un juego de mesa multijugador para Roblox. Tu trabajo es que los 4 barrios de Metrópolis (Centro, Puerto, Zona Alta e Industrial) tengan su calle, su acera, su mobiliario y su fondo propios, y que se distingan de un vistazo **por la silueta, no solo por el color**.

**Tú no modelas.** Cada lote lo modela un subagente nuevo (`superpowers:subagent-driven-development`, que es el modo del plan 07). Tú le das el encargo, compruebas el resultado con capturas reales y decides. Los subagentes van de uno en uno porque solo hay un Blender y un Studio. Nunca aceptes un informe sin abrir sus capturas.

## 1. Lee esto antes de empezar

1. `CLAUDE.md` y `docs/instrucciones-de-sesion.md`.
2. `docs/02-mvp/plan-07-ciudad-y-fichas.md`, la Tarea 1 y las restricciones globales, y `docs/02-mvp/resultados/plan-07-cierre.md`.
3. `art/vision-visual.md`. Es una calle de asfalto continua con las casillas pintadas en el carril, y no hay baldosas ni tablero.
4. `art/guia-de-estilo.md`, **sección 7, Barrios**, que es la norma de esta tarea, y las láminas `art/identidad/concepto-centro.png`, `concepto-puerto.png` y `concepto-alta.png` (míralas con Read).
5. `art/PIPELINE.md` (escala: 1 unidad de Blender = 1 stud y el avatar mide 6) y `art/escala.md`.
6. Código: `src/shared/config/CityLayout.luau` (rutas, `ISLANDS`, `dressingFor`), `src/client/world/CityBuilder.luau` (suelo, puentes, calle y casillas), `src/client/world/StreetDressing.luau` y `ArtAssets.street` / `ArtAssets.dressedZones` en `src/shared/config/ArtAssets.luau`.
7. La plantilla de mobiliario: `art/blender/slice/build_street_props.py`.
8. Las capturas de partida en `art/render/ingame/` (`ciudad-turno.jpg`, `ruta-s.jpg`, `ruta-m.jpg`, `ruta-l.jpg`). Ese es el nivel de partida.

Después di en una frase qué vas a hacer y empieza.

## 2. Situación de partida

- **Ya existe:** la ruta de los tres tamaños, las islas (Centro y Puerto en el continente, y Zona Alta e Industrial aparte), los puentes, las 34 propiedades con su edificio real y un mobiliario genérico (árbol, farola, banco, paso de cebra y coche). `ArtAssets.dressedZones = { "carmesi" }`: el mobiliario solo se pone en carmesí.
- **No existe:** `art/blender/city/`, ninguna pieza propia de barrio y el fondo de ciudad de bajo detalle (`city-backdrop` sigue siendo el blockout gris del plan 06, en `Draft`).
- **Qué barrio entra en cada tamaño** (ficha): con 40 casillas, Centro y Puerto; con 48, también Zona Alta; con 56, los cuatro.

| Barrio | Zonas | Identidad (guía, sección 7) |
| --- | --- | --- |
| Centro | Cobre, Cian, Magenta, Naranja, Carmesí y Limón | Ladrillo y caliza, toldos, calles estrechas, sombra dura y paleta cálida. Es el barrio que más se mira. |
| Puerto | Esmeralda y Violeta | Adoquín, hierro oxidado, naves bajas, grúas y agua. El horizonte se ve. |
| Zona Alta | Añil y Blanca | Cristal azul, acero y oro solo en remates, con plaza elevada y techo de 92 studs. |
| Industrial | Grafito y Ocre | Ladrillo oscuro, acero y óxido, chimeneas y silos de hasta 60 studs. El detalle se concentra en la fachada que da a la ruta. |

## 3. Qué hay que producir

Por barrio, en `art/blender/city/<barrio>.py` (script reproducible, como el resto del arte) y su `.blend`:

1. **Calle y acera propias:** bordillo, pavimento y alcorques. Que el asfalto y las casillas pintadas sigan como están (`road-paint` está en `InGame`): se cambia lo que rodea al carril, no el carril.
2. **Mobiliario propio,** de 3 a 5 piezas por barrio. Por ejemplo: en Centro, toldos, quioscos y farolas de forja; en Puerto, bolardos, cajas, redes y una grúa de muelle; en Zona Alta, jardineras de acero, bancos de diseño y farolas de cristal; en Industrial, contenedores, palés, vallas y farolas de sodio. Cada pieza cumple el presupuesto de `RepeatedProp` de `tools/manifest.luau` (2000 triángulos, con LOD).
3. **Fondo de bajo detalle** detrás de la ruta (`CityBackdrop`: 3000 triángulos, sin LOD obligatorio): siluetas de su barrio, sin acceso y sin colisión.
4. **La calle como frontera:** la transición entre barrios se hace con una calle, nunca a mitad de manzana.

Ni interiores ni calles que nadie pise. Nada de la Toolbox ni de assets de marca.

## 4. Código

- Generaliza `dressedZones` / `dressingFor` para que el mobiliario se elija **por barrio** (`slot.barrioId`), no por zona suelta. Los valores van en `config` y no dentro de la lógica.
- `CityBuilder.build(sizeId, parent)` coloca el fondo de cada barrio que entre en ese tamaño.
- Pruebas primero, con Lune: que cada barrio del tamaño tenga su mobiliario y su fondo, que un barrio que no entra en ese tamaño no se construya, y que `CityLayout` siga pasando.
- Si cambia un contrato compartido, se cambia primero en `docs/01-arquitectura/arquitectura.md`.

## 5. Orden de trabajo

1. **Centro primero, completo** (calle, mobiliario y fondo), subido, integrado y capturado en Studio. **Para y pide la aprobación del responsable** con capturas antes de seguir: es la pieza de referencia de la familia.
2. Después, Puerto, Zona Alta e Industrial, uno detrás de otro y con la misma comprobación.
3. Captura la ruta completa en S, M y L, y una vista de cada frontera entre barrios.
4. La prueba de fuego es una captura de la vista general en la que se vean los 4 barrios: hay que distinguirlos de un vistazo, en gris (sin color) y con color.

## 6. Cómo comprobar cada lote

- Escala contra un avatar de 6 studs, en la captura.
- Subida con `art/generators/upload_model.ps1` o el MCP de Studio, y registro en `art/manifest.json` con `status: "Draft"`. Nunca `Approved` ni `InGame`: eso lo decide el responsable.
- `lune run tools/manifest` y `lune run tests/run CityLayout`, y al final `lune run tools/check` en verde.
- Ningún edificio ni pieza nueva tapa la cámara del turno en ninguna casilla, con todo al nivel 5.
- Un commit por lote. El de cierre: `feat: añadir barrios de Metrópolis`.

## 7. Al terminar

- Actualiza la fila de la Tarea 1 en `docs/02-mvp/resultados/plan-07-cierre.md` con lo verificado y lo pendiente, sin inventar resultados. Las casillas del plan las marca solo el responsable.
- Informa de qué quedó hecho, qué se comprobó y qué falta.

## 8. Cuándo parar y preguntar

- Antes de cualquier push, merge o publicación en Roblox.
- Tras el primer barrio, para pedir la aprobación.
- Si la guía de estilo choca con la visión visual o con la ficha.
- Si un lote falla 3 veces por el mismo motivo.
- Si algo pide gastar dinero o usar un servicio de pago.

# Subfase 07: Ciudad y fichas. Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Producir Metrópolis completa, las 8 fichas y los personajes de escena, al nivel de la porción vertical.

**Architecture:** `CityBuilder` deja de crear piezas grises y carga los modelos aprobados según `CityLayout`. El detalle se concentra en lo visible desde la ruta.

**Tech Stack:** Blender con su MCP, generación con IA, Roblox Studio con su MCP.

**Spec:** "Identidad" y "Qué incluye el MVP" en la [ficha](../00-ficha/ficha-propuesta.md); referencia visual aprobada en la Puerta B.

**Requisito previo:** la Puerta B está aprobada.

## Ejecución recomendada

**Modo:** subagentes, con `superpowers:subagent-driven-development`.

**Por qué:** es mucha producción por lotes separados, con capturas que llenarían rápido el contexto de una sola sesión. Cada lote cabe en un subagente nuevo, y la guía de estilo y el manifiesto mantienen la coherencia entre ellos.

**Instrucciones para la sesión:**

- Sigue también las [instrucciones generales](../instrucciones-de-sesion.md).
- Requiere la Puerta B aprobada, y Blender y Studio abiertos con sus MCP.
- Los subagentes van de uno en uno, porque solo hay un Blender y un Studio.
- Entrega a cada subagente la guía de estilo, `PIPELINE.md` y las capturas de la porción vertical.
- Produce primero una pieza de cada familia y pide su aprobación antes de hacer el resto.
- El revisor comprueba el manifiesto y las capturas, pero no sustituye la aprobación del responsable.
- Termina con la Tarea 7 cumplida en el móvil de referencia.

## Global Constraints

- Cada asset cumple el estándar de la ficha y se aprueba en el juego por una persona.
- No hay interiores ni calles que nadie pise.
- Cada propiedad es un edificio real y propio. Sus cinco niveles añaden marcadores y pequeños cambios de fachada y altura, sin sustituirlo.
- Cada grupo de color es una zona de edificios, y varias zonas forman un barrio.
- 30 FPS o más en el móvil de referencia con 8 jugadores.

## Review Focus

1. Dos zonas se confunden a simple vista: la revisión en la maqueta lo detecta. Criterio en Tarea 2.
2. Un avatar extremo atraviesa su ficha: prueba con escalas mínima y máxima. Prueba en Tarea 5.
3. Un edificio de nivel alto tapa la cámara de la casilla vecina. Prueba en Tarea 2.
4. La ciudad de 56 casillas supera el presupuesto de memoria en móvil. Prueba en Tarea 7.
5. Un asset gris queda en el juego por descuido. Prueba en Tarea 7.

---

### Task 1: Trazado de barrios

**Módulos:** `config/CityLayout`, `client/world/CityBuilder`.

**Archivos:**
- Crear: `art/blender/city/centro.blend`, `art/blender/city/puerto.blend`, `art/blender/city/zona-alta.blend`, `art/blender/city/industrial.blend`
- Modificar: `src/shared/config/CityLayout.luau`, `src/client/world/CityBuilder.luau`

**Interfaces:**
- Consume: `CityLayout.routeFor`.
- Produce: `CityBuilder.build(sizeId, parent)`, ahora con los modelos finales.

**Criterios de aceptación:**
- [ ] Calles, aceras, señales, farolas y fondo cumplen la guía de estilo.
- [ ] Los 4 barrios se distinguen de un vistazo.
- [ ] El fondo es de bajo detalle y no se accede a él.
- [ ] Las pruebas de `CityLayout` siguen pasando.

- [ ] **Paso 1:** Modelar y registrar cada asset en el manifiesto.
- [ ] **Paso 2:** Conectar `CityBuilder` y capturar la ruta completa de los 3 tamaños.
- [ ] **Paso 3:** Ejecutar `lune run tests/run CityLayout` y `lune run tools/manifest`. Esperado: PASS.
- [ ] **Paso 4:** Obtener la aprobación del responsable con capturas y video.
- [ ] **Paso 5:** Hacer commit: `feat: añadir barrios de Metrópolis`.

### Task 2: Propiedades por zona

**Módulos:** `client/world/BuildingView`, `art/blender/buildings`.

**Archivos:**
- Crear: `art/blender/buildings/zona-01.blend` a `zona-12.blend`
- Modificar: `src/client/world/BuildingView.luau`, `art/manifest.json`

**Interfaces:**
- Produce: `BuildingView.setLevel(index, level)` para las 34 propiedades.

**Criterios de aceptación:**
- [ ] Las 34 propiedades tienen edificio propio, y 12 zonas con estilo propio. Los añadidos de nivel se pueden compartir dentro de una zona si cada edificio sigue siendo reconocible.
- [ ] El color de cada zona se reconoce desde la calle y desde la maqueta.
- [ ] El dueño se identifica en cada propiedad, sin depender solo del color.
- [ ] Ningún edificio tapa la cámara de ninguna casilla; se comprueba por casilla con el nivel máximo.

- [ ] **Paso 1:** Producir una zona y conseguir su aprobación antes de continuar con las demás.
- [ ] **Paso 2:** Producir las 11 restantes y registrarlas.
- [ ] **Paso 3:** Con un script de Studio, poner todo al nivel 5 y capturar desde cada casilla. Esperado: ninguna vista bloqueada.
- [ ] **Paso 4:** Ejecutar `lune run tools/manifest`. Esperado: sin problemas.
- [ ] **Paso 5:** Hacer commit: `feat: añadir propiedades de las 12 zonas`.

### Task 3: Casillas especiales

**Módulos:** `art/blender/squares`.

**Archivos:**
- Crear: `art/blender/squares/*.blend`
- Modificar: `src/client/world/CityBuilder.luau`, `art/manifest.json`

**Criterios de aceptación:**
- [ ] Salida, Giro, Mercado Negro, Duelo, Portal, Cartelera, Tribunal e Impuesto tienen un lugar propio y reconocible.
- [ ] La Cartelera es una pantalla gigante de ciudad, sin estética de casino.
- [ ] El Tribunal incluye el lugar de la comisaría para el arresto.
- [ ] La Zona Caliente brilla sobre la zona activa y se distingue sin depender solo del color.

- [ ] **Paso 1:** Modelar y registrar los assets.
- [ ] **Paso 2:** Capturar cada casilla desde primera persona y desde la maqueta.
- [ ] **Paso 3:** Obtener la aprobación del responsable.
- [ ] **Paso 4:** Hacer commit: `feat: añadir casillas especiales`.

### Task 4: Maqueta de la vista general

**Módulos:** `client/ui/Overview`, `client/world/ModelCity`.

**Archivos:**
- Crear: `src/client/world/ModelCity.luau`, `art/blender/model-city.blend`
- Modificar: `src/client/ui/Overview.luau`

**Interfaces:**
- Produce: `ModelCity.show(view: PlayerView)`, `ModelCity.hide()`.

**Criterios de aceptación:**
- [ ] La ciudad aparece como una maqueta de lujo, con base y materiales propios.
- [ ] Muestra dueños, dinero, posiciones y efectos activos.
- [ ] Se abre y se cierra en menos de 1 s.
- [ ] Respeta los tres tamaños de ciudad.

- [ ] **Paso 1:** Implementar y conectar con `CameraRules`.
- [ ] **Paso 2:** Probar en los 3 tamaños; capturar en PC y móvil.
- [ ] **Paso 3:** Obtener la aprobación del responsable.
- [ ] **Paso 4:** Hacer commit: `feat: añadir maqueta de vista general`.

### Task 5: Ocho fichas

**Módulos:** `client/world/TokenRider`, `art/blender/tokens`.

**Archivos:**
- Crear: `art/blender/tokens/{taxi,limusina,moto,deportivo,food-truck,camion-helados,grua,autobus}.blend`, `src/shared/config/Tokens.luau`
- Modificar: `src/client/world/TokenRider.luau`, `art/manifest.json`

**Interfaces:**
- Produce: `Tokens.all = { { id: string, asset: string, seatOffset: Vector3Like } }`.

**Criterios de aceptación:**
- [ ] Las 8 fichas son vehículos gigantes con un punto claro donde va el avatar.
- [ ] Cada una tiene animación de reposo, marcha y celebración.
- [ ] Antes de programar, se confirma en la documentación oficial cómo fijar el tipo de avatar y sus límites de escala.
- [ ] Funciona con avatares de escala mínima y máxima, y con varios tipos de cuerpo permitidos.
- [ ] Cada jugador elige su ficha antes de empezar; no se repiten.

- [ ] **Paso 1:** Producir el taxi final a partir de la porción vertical y usarlo de referencia.
- [ ] **Paso 2:** Producir las otras 7 y registrarlas.
- [ ] **Paso 3:** Probar cada ficha con avatares de escala mínima y máxima; capturar.
- [ ] **Paso 4:** Obtener la aprobación del responsable.
- [ ] **Paso 5:** Hacer commit: `feat: añadir ocho fichas`.

### Task 6: Personajes y vehículos de escena

**Módulos:** `art/blender/characters`, `client/scenes/Actors`.

**Archivos:**
- Crear: `art/blender/characters/*.blend`, `src/client/scenes/Actors.luau`
- Modificar: `art/manifest.json`

**Interfaces:**
- Produce: `Actors.spawn(kind: "Police" | "PatrolCar" | "Crowd" | "Worker" | "Crane" | "TowTruck" | "ArmoredTruck" | "WreckingBall", at: CFrame): Model`, `Actors.despawn(model: Model)`.

**Criterios de aceptación:**
- [ ] Hay policías, patrullas, multitud, obreros y grúas, según la ficha, más los vehículos que piden las escenas.
- [ ] El estilo es caricaturesco y apto para todo público.
- [ ] Reutilizan objetos: una escena no crea más de los que puede liberar.
- [ ] Cada personaje tiene las animaciones que necesita su escena.

- [ ] **Paso 1:** Modelar, animar y registrar.
- [ ] **Paso 2:** Crear y destruir cada tipo 100 veces en Studio. Esperado: sin aumento sostenido de memoria.
- [ ] **Paso 3:** Obtener la aprobación del responsable.
- [ ] **Paso 4:** Hacer commit: `feat: añadir personajes de escena`.

### Task 7: Rendimiento y limpieza

**Módulos:** `client/world`, `tools/manifest`.

**Archivos:**
- Modificar: `tools/manifest.luau`
- Crear: `docs/02-mvp/resultados/rendimiento-ciudad.md`

**Criterios de aceptación:**
- [ ] 30 FPS o más en el móvil de referencia, con 8 jugadores en la ciudad de 56 casillas.
- [ ] La memoria queda dentro del presupuesto fijado en la Puerta B.
- [ ] `tools/manifest` falla si `src/` contiene `Part` gris marcado como temporal o un asset sin manifiesto.
- [ ] Se ve aceptable con el nivel gráfico mínimo.

- [ ] **Paso 1:** Añadir la comprobación de elementos temporales y probarla con un archivo de ejemplo.
- [ ] **Paso 2:** Medir el peor caso en el móvil de referencia, con ayuda del responsable.
- [ ] **Paso 3:** Optimizar hasta cumplir y registrar los resultados.
- [ ] **Paso 4:** Ejecutar `lune run tools/check`. Esperado: código 0.
- [ ] **Paso 5:** Hacer commit: `perf: ajustar la ciudad al presupuesto móvil`.

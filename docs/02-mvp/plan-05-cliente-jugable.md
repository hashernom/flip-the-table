# Subfase 05: Cliente jugable. Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (recommended) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un prototipo gris, jugable de principio a fin en primera persona, para comprobar con amigos si las reglas divierten.

**Architecture:** El cliente es una vista: recibe lotes, los ordena y reproduce escenas provisionales con las duraciones reales de `Scenes`. El arte gris es temporal y solo se usa en lugares privados.

**Tech Stack:** Luau, Rojo, MCP de Roblox Studio, Lune para la lógica pura.

**Spec:** "Identidad" y "Turnos compartidos" en la [ficha](../00-ficha/ficha-propuesta.md).

## Ejecución recomendada

**Modo:** en la sesión, con `superpowers:executing-plans`.

**Por qué:** cámara, ficha, escenas e interfaz se ajustan juntas, probando una y otra vez en un solo Studio. Mantener el contexto rinde más que empezar de cero en cada tarea, y este arte gris es provisional, así que un error aquí cuesta poco.

**Instrucciones para la sesión:**

- Sigue también las [instrucciones generales](../instrucciones-de-sesion.md).
- Requiere el plan 04 terminado y Studio abierto con su MCP.
- No inviertas en arte: todo es gris y queda marcado como temporal.
- La prueba de PC y móvil se hace durante toda la subfase, no al final.
- Pide un revisor nuevo para la rama antes de la Tarea 6.
- La Tarea 6 depende de personas: pide permiso para publicar en privado y pide al responsable que reúna los grupos. Espera los resultados reales.
- La Puerta A (Tarea 6) queda aplazada hasta la alpha por decisión del responsable (2026-11-04). Ya no bloquea el plan 06; ver `docs/02-mvp/resultados/puerta-a.md`.

## Global Constraints

- Primera persona como modo principal, con vista general mediante un botón.
- Sin movimiento libre: el jugador solo puede mirar alrededor.
- Todo el grupo ve la misma escena a la vez; el siguiente turno no empieza hasta que termina.
- La vista general no interrumpe una escena: se abre antes o después.
- PC y móvil desde esta subfase.
- El arte gris nunca se publica como versión pública.

## Review Focus

1. Un cliente se queda atrás varios lotes: se pone al día sin reproducir escenas antiguas. Prueba en Tarea 1.
2. Un jugador intenta caminar o saltar: no se mueve. Prueba en Tarea 3.
3. Un avatar muy grande o muy pequeño mantiene una cámara utilizable. Prueba en Tarea 3.
4. En móvil, ningún botón importante queda fuera de la zona segura. Prueba en Tarea 5.
5. Se abre la vista general justo al empezar una escena: se cierra y vuelve a estar disponible al terminar. Prueba en Tarea 3.

---

### Task 1: Cola de eventos y estado

**Módulos:** `client/state/EventQueue`, `client/state/StateStore`.

**Archivos:**
- Crear: `src/client/state/EventQueue.luau`, `src/client/state/StateStore.luau`, `tests/client/EventQueue.spec.luau`

**Interfaces:**
- Consume: lote `{ seq, startsAt, events, view }`.
- Produce: `EventQueue.new(): EventQueue`, `EventQueue.push(q, batch): "Queued" | "Gap" | "Duplicate"`, `EventQueue.nextDue(q, now): Batch?`, `EventQueue.resync(q, view, seq)`.

**Criterios de aceptación:**
- [x] Los lotes se reproducen en orden de `seq`.
- [x] Un duplicado se ignora; un hueco pide `ResyncRequest`.
- [x] Un lote cuya escena ya terminó aplica su estado sin reproducirse.

- [x] **Paso 1: Escribir las pruebas**

```luau
it("detecta un hueco", function()
    local q = EventQueue.new()
    expect(EventQueue.push(q, { seq = 1 })).toBe("Queued")
    expect(EventQueue.push(q, { seq = 3 })).toBe("Gap")
end)
it("ignora un duplicado", function()
    local q = EventQueue.new(); EventQueue.push(q, { seq = 1 })
    expect(EventQueue.push(q, { seq = 1 })).toBe("Duplicate")
end)
```

- [x] **Paso 2:** Ejecutar `lune run tests/run EventQueue`. Esperado: FAIL.
- [x] **Paso 3:** Implementar ambos módulos.
- [x] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [x] **Paso 5:** Hacer commit: `feat: ordenar eventos en el cliente`.

### Task 2: Ciudad gris a escala

**Módulos:** `client/world/CityBuilder`, `config/CityLayout`.

**Archivos:**
- Crear: `src/shared/config/CityLayout.luau`, `src/client/world/CityBuilder.luau`, `tests/config/CityLayout.spec.luau`

**Interfaces:**
- Produce: `CityLayout.routeFor(sizeId): { { position: Vector3Like, facing: number } }`, una posición por casilla.
- Produce: `CityBuilder.build(sizeId: SizeId, parent: Instance): CityHandles`.

**Criterios de aceptación:**
- [x] Cada tamaño tiene su ruta cerrada, con 40, 48 o 56 posiciones.
- [x] Centro y Puerto usan las mismas posiciones lógicas en los tres tamaños, y Zona Alta e Industrial se conectan por puentes.
- [x] La distancia máxima entre casillas consecutivas es de 60 studs.
- [x] Cada casilla es reconocible por tipo, color y etiqueta.

- [x] **Paso 1:** Escribir pruebas de ruta: número de posiciones por tamaño, distancia máxima y ruta cerrada.
- [x] **Paso 2:** Ejecutar `lune run tests/run CityLayout`. Esperado: FAIL.
- [x] **Paso 3:** Implementar los datos y `CityBuilder`.
- [x] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [x] **Paso 5:** Con el MCP de Studio, construir los 3 tamaños y capturar pantalla con `screen_capture`. Esperado: ruta visible y sin solapes.
- [x] **Paso 6:** Hacer commit: `feat: construir ciudad gris por tamaño`.

### Task 3: Cámaras y control del jugador

**Módulos:** `client/camera/CameraDirector`, `client/camera/CameraRules`, `client/world/TokenRider`.

**Archivos:**
- Crear: `src/client/camera/CameraRules.luau`, `src/client/camera/CameraDirector.luau`, `src/client/world/TokenRider.luau`, `tests/client/CameraRules.spec.luau`

**Interfaces:**
- Produce: `CameraRules.modeFor(ctx: { isActive: boolean, sceneRunning: boolean, overviewRequested: boolean }): "FirstPerson" | "FollowActive" | "Scene" | "Overview"`.
- Produce: `TokenRider.mount(player: Player, token: Model)`, `TokenRider.ride(token: Model, path: { number }, durationSec: number)`.

**Criterios de aceptación:**
- [x] Se cumple la tabla "Qué ve cada jugador" de la ficha. **(Por código y pruebas de `CameraRules`; con dos clientes reales no se observó.)**
- [x] Una escena tiene prioridad sobre la vista general.
- [x] Un recorrido dura como máximo 4 s, sea cual sea la distancia.
- [x] Caminar y saltar están desactivados; se puede mirar alrededor con ratón o dedo.
- [x] La cámara funciona con avatares de altura mínima y máxima.
- [x] Los demás jugadores se ven sobre sus fichas.

- [x] **Paso 1: Escribir las pruebas**

```luau
it("la escena manda sobre la vista general", function()
    expect(CameraRules.modeFor({ isActive = false, sceneRunning = true, overviewRequested = true })).toBe("Scene")
end)
it("el activo va en primera persona", function()
    expect(CameraRules.modeFor({ isActive = true, sceneRunning = false, overviewRequested = false })).toBe("FirstPerson")
end)
it("los demás siguen a la ficha activa", function()
    expect(CameraRules.modeFor({ isActive = false, sceneRunning = false, overviewRequested = false })).toBe("FollowActive")
end)
```

- [x] **Paso 2:** Ejecutar `lune run tests/run CameraRules`. Esperado: FAIL.
- [x] **Paso 3:** Implementar `CameraRules`, `CameraDirector` y `TokenRider`, con fichas grises.
- [x] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [x] **Paso 5:** Probar en Studio con `start_stop_play` y `user_keyboard_input`: pulsar WASD y espacio. Esperado: el avatar no se mueve.
- [x] **Paso 6:** Probar con avatar de escala mínima y máxima; capturar pantalla. Esperado: la cámara no atraviesa el suelo ni la ficha.
- [x] **Paso 7:** Hacer commit: `feat: añadir cámaras y subir el avatar a la ficha`.

### Task 4: Escenas provisionales

**Módulos:** `client/scenes/SceneDirector`, `client/scenes/PlaceholderScene`.

**Archivos:**
- Crear: `src/client/scenes/SceneDirector.luau`, `src/client/scenes/PlaceholderScene.luau`

**Interfaces:**
- Consume: `EventQueue.nextDue`, `Scenes.durationFor`.
- Produce: `SceneDirector.play(batch: Batch)`, `SceneDirector.register(eventOrCardId: string, scene: Scene)`.
- Produce: `Scene = { run: (ctx: SceneContext, event: Event) -> () }`.

**Criterios de aceptación:**
- [x] Todo evento sin escena final muestra su nombre durante su duración real.
- [x] Dos clientes muestran la misma escena con una diferencia menor de 250 ms. **(Medido en la misma máquina: máximo 56 ms en 10 escenas. Falta con red real.)**
- [x] Un error dentro de una escena no detiene la cola.

- [x] **Paso 1:** En Test Server con 2 clientes, registrar en consola la hora de inicio de cada escena. Esperado: diferencia menor de 250 ms.
- [x] **Paso 2:** Forzar un error en una escena de prueba. Esperado: se registra y la siguiente escena se reproduce.
- [x] **Paso 3:** Hacer commit: `feat: reproducir escenas provisionales`.

### Task 5: Interfaz gris

**Módulos:** `client/ui/Hud`, `client/ui/Menus`.

**Archivos:**
- Crear: `src/client/ui/Hud.luau`, `src/client/ui/ActionMenu.luau`, `src/client/ui/TradeMenu.luau`, `src/client/ui/PactMenu.luau`, `src/client/ui/VoteMenu.luau`, `src/client/ui/PerkMenu.luau`, `src/client/ui/Overview.luau`, `src/client/ui/LobbyMenu.luau`, `src/client/ui/ActionMenuRules.luau`, `tests/client/ActionMenuRules.spec.luau`

**Interfaces:**
- Consume: `Engine.legalActions` por medio de `view.legalActions`.
- Produce: `ActionMenuRules.buttonsFor(legal: { Action }): { { id: string, action: Action } }`.

**Criterios de aceptación:**
- [ ] Se puede jugar toda la partida solo con menús: comprar, pujar, construir, cartas, perks, tratos, pactos, votos, duelos, mercado y turno de espectro.
- [x] Un botón solo aparece si su acción es legal.
- [x] El temporizador de cada decisión está siempre visible.
- [x] En móvil, todo queda dentro de la zona segura y con objetivos táctiles de 44 píxeles o más. **(Medido a 586 × 365 con `CoreUISafeInsets`, no con el emulador.)**
- [x] La vista general muestra dueños, dinero, posiciones y efectos activos.
- [x] Los emotes se lanzan con un botón y todos los ven. **(Comprobado que el remoto llega a los dos clientes; el botón en sí no se pulsó.)**

- [x] **Paso 1:** Escribir pruebas de `ActionMenuRules`: sin compra legal no hay botón de compra; con `Bid` hay control de puja.
- [x] **Paso 2:** Ejecutar `lune run tests/run ActionMenuRules`. Esperado: FAIL.
- [x] **Paso 3:** Implementar los menús.
- [x] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Probar en Studio con el emulador de un móvil de pantalla pequeña; capturar pantalla. Esperado: sin solapes.
      El MCP de Studio no puede activar el emulador: la prueba se hizo reduciendo la ventana a 586 × 365
      y midiendo los controles. Queda pendiente con el emulador de verdad.
- [x] **Paso 6:** Hacer commit: `feat: añadir interfaz gris completa`.

### Task 6: Puerta A, prueba con amigos (aplazada hasta la alpha)

**Módulos:** todos los anteriores; `tools/criteria-report`.

**Archivos:**
- Crear: `docs/02-mvp/resultados/puerta-a.md`

**Interfaces:**
- Consume: `Telemetry`, `tools/criteria-report`.

**Criterios de aceptación:**
- [ ] El responsable elige el móvil de referencia.
- [ ] 5 partidas completas de 4 a 8 jugadores con amigos, en PC y móvil.
- [ ] Turno medio de 20 s o menos.
- [ ] Al menos una vez, el grupo pidió la revancha sin que nadie lo sugiriera.
- [ ] Decisión escrita del responsable: seguir, ajustar reglas o replantear.

- [ ] **Paso 1:** Pedir permiso al responsable para publicar el prototipo en un lugar privado.
- [ ] **Paso 2:** Pedirle que reúna los grupos; esta tarea no pueden hacerla los agentes.
- [ ] **Paso 3:** Tras cada partida, hacer 3 preguntas: qué fue lo más divertido, cuándo se aburrieron y si jugarían otra.
- [ ] **Paso 4:** Ejecutar `lune run tools/criteria-report` y escribir los resultados y la decisión en `puerta-a.md`.
- [ ] **Paso 5:** Ajustar `config` según los resultados y repetir hasta que el responsable apruebe.
- [ ] **Paso 6:** Hacer commit: `docs: registrar resultado de la Puerta A`.

---

## Cómo quedó

Ejecutada en la sesión el 2026-11-04, en el modo que recomienda el plan, con un Studio de edición y
un servidor HTTP local para llevar el código al DataModel. Las casillas de arriba reflejan lo que se
comprobó de verdad.

**Lo que se añadió al plan, y por qué** (todo con su ruling en la arquitectura):

- **`src/client/main.client.luau`.** Ninguna tarea nombraba el ensamblado del cliente y sin él ningún
  módulo llegaba a ejecutarse. Es el único punto de cableado.
- **`config/Strings` y `config/CityLayout`.** La arquitectura ya listaba `Strings`; los nombres,
  colores y etiquetas de las casillas solo estaban en `docs/02-mvp/contenido-tablero.md`, y la ruta
  de cada tamaño necesitaba datos puros que probar con Lune.
- **`client/ui/Theme`.** Colores, medidas táctiles y zona segura en un solo sitio: los siete menús
  comparten botones, paneles y modales.
- **`client/camera/CameraRules`** se separó de `CameraDirector` para poder probar la tabla «Qué ve
  cada jugador» sin abrir Studio. `CameraRules` decide también el tope de 4 s del recorrido y la
  altura de la cámara sobre el asiento.
- **Un remoto de emotes.** La ficha pide que todos vean los emotes y el protocolo no tenía por dónde:
  `EmoteRequest` con `Protocol.EMOTES` y `Protocol.validateEmote`, reenviado por el servidor a todo el
  grupo (R-P33).
- **`Scenes.maxRideSec`.** El tope de 4 s de un recorrido es un número ajustable y vive en `config`.

**Lo que se comprobó, y cómo:**

- **Cola y estado:** 22 pruebas de Lune. **Geometría de la ciudad:** 16. **Textos y colores:** 14.
  **Cámaras:** 16. **Escenas:** 17. **Menús:** 15. Total de la rama: 1000 pruebas en verde.
- **Los tres tamaños de ciudad** se construyeron en Studio y se capturaron: anillo cerrado de 40, 48
  y 56 casillas con su color y su rótulo, y las pasarelas en la junta entre islas.
- **Sin movimiento libre:** con Play y `user_keyboard_input` (W, A, espacio, D) la raíz del avatar se
  quedó en el mismo punto (0, 6.135, 0) antes y después.
- **Avatares extremos:** con `Model:ScaleTo(0.6)` y `2.2`, la cámara quedó por encima del asiento
  (6,26 y 12,48 frente a 3,30) y del suelo en los dos casos.
- **Recorrido acotado:** pedir 30 s con siete casillas tardó 4,00 s y dejó la ficha en la casilla 8,
  con el avatar encima.
- **Escenas:** con el reloj real de Roblox, una escena que revienta se registra, ocupa su hueco
  (4,03 s de dos escenas de 2 s) y la siguiente se reproduce.
- **Menús:** la barra solo enseña lo legal (comprar, no comprar, construir 8, terminar turno; en
  subasta, pujar con el control entre 10 y 340), el temporizador se ve («19 s», «11 s») y la vista
  general enseña dueños, dinero, posiciones y efectos activos.
- **Ventana pequeña:** a 586 × 365 la barra, los botones y el panel de acciones caben dentro de la
  zona segura de Roblox, y ningún botón baja de 44 píxeles de alto. Se corrigieron dos fallos que
  solo aparecían ahí: la barra de estado se colocaba debajo de la botonera del motor y el panel de la
  vista general se salía de la pantalla.

**Pendiente y por qué:**

- **Dos clientes a menos de 250 ms.** El mecanismo que se describía aquí no funcionaba: el servidor
  mandaba `time()` y el cliente comparaba con `GetServerTimeNow()`, así que cada escena duraba 0,2 s.
  Se corrigió después (R-P38 a R-P41) y se midió en un Test Server local con dos clientes. Falta
  medirlo con red real, en un lugar publicado.
- **Una partida completa de principio a fin** con personas: las pruebas en Test Server usaron clientes
  automáticos y saltaron a la última ronda. Los menús tampoco lo permiten todavía (B4, B5, B6 y B8 de
  la auditoría), a la espera de rehacer la interfaz.
- **El emulador de móvil.** El MCP de Studio no puede activarlo, así que la prueba de pantalla
  pequeña se hizo reduciendo la ventana de Studio a 586 × 365 y midiendo los controles.
- **La Puerta A** es la Tarea 6 entera: publicar en privado, reunir los grupos y decidir. No puede
  hacerla un agente. Aplazada hasta la alpha (2026-11-04), ya no bloquea el plan 06.
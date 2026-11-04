# Subfase 04: Red y partidas. Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ejecutar el motor en un servidor autoritativo y permitir que un grupo entre, juegue, se desconecte y pida la revancha.

**Architecture:** Dos lugares de Roblox: Lobby y Partida. El servidor recibe intenciones, las pasa a `Engine` y difunde lotes numerados. Lo que se puede, se escribe como lógica pura y se prueba con Lune; lo demás, en Studio y en un servidor publicado de prueba.

**Tech Stack:** Luau, Rojo, Lune, RemoteEvent, TeleportService, MemoryStoreService, AnalyticsService.

**Spec:** "Multijugador" y "Desconexiones" en la [ficha](../00-ficha/ficha-propuesta.md); contratos en [arquitectura](../01-arquitectura/arquitectura.md).

## Ejecución recomendada

**Modo:** subagentes, con `superpowers:subagent-driven-development`.

**Por qué:** aquí se decide qué puede hacer un cliente malicioso y qué información ve cada jugador. Un fallo publicado permitiría hacer trampas o ver manos ajenas, por lo que cada tarea merece una revisión independiente.

**Instrucciones para la sesión:**

- Sigue también las [instrucciones generales](../instrucciones-de-sesion.md).
- Requiere el plan 03 terminado y Studio abierto con su MCP. El uso de Studio va de uno en uno.
- Pide al revisor que busque específicamente cómo un cliente podría engañar al servidor o ver información oculta.
- Consulta la documentación oficial antes de las tareas 5 y 7.
- La Tarea 5 requiere publicar en un lugar privado: detente y pide permiso, y pide al responsable una segunda cuenta.
- Termina cuando 3 personas o cuentas pueden crear party, jugar, desconectarse, volver y pedir revancha.

## Global Constraints

- El cliente solo envía intenciones; dinero, dados y cartas se deciden en el servidor.
- La mano de cada jugador solo se envía a su dueño.
- Un cliente lento nunca detiene la partida.
- Un bot toma el turno de quien se va; el temporizador evita esperas.
- Party privada con código, partidas públicas de 2 a 8 y revancha con un botón.
- Antes de publicar, los agentes se detienen y preguntan.

## Review Focus

1. Un cliente envía una acción malformada o muy frecuente: se rechaza y no rompe el servidor. Prueba en Tarea 1.
2. Un jugador vuelve tras desconectarse y recupera su asiento y su mano. Prueba en Tarea 4.
3. Se usa un código caducado o mal escrito: mensaje claro y sin teletransporte. Prueba en Tarea 5.
4. Solo queda una persona real en la revancha: no empieza una partida sin rivales. Prueba en Tarea 6.
5. Un lote de eventos llega con hueco: el cliente puede pedir el estado completo. Prueba en Tarea 3.

---

### Task 1: Protocolo y validación

**Módulos:** `net/Protocol`, `server/match/RemoteGateway`.

**Archivos:**
- Crear: `src/shared/net/Protocol.luau`, `src/server/match/RemoteGateway.luau`, `tests/net/Protocol.spec.luau`

**Interfaces:**
- Produce: `Protocol.REMOTES = { Action = "ActionRequest", Batch = "EventBatch", Resync = "ResyncRequest" }`.
- Produce: `Protocol.validate(action: any): (boolean, string?)`, que comprueba el tipo y los campos de cada acción de la arquitectura.
- Produce: `RemoteGateway.start(onAction: (player: Player, action: Action) -> ())`.

**Criterios de aceptación:**
- [x] Cualquier valor no válido se rechaza sin lanzar error: `nil`, número, tipo desconocido, campos con tipo incorrecto, importes negativos o no enteros.
- [x] Máximo 10 acciones por segundo por jugador; el resto se descarta.
- [x] Nunca se confía en un `playerId` enviado por el cliente: se usa el `Player` del remoto.

- [x] **Paso 0:** Añadir a `tools/check` un segundo pase de `luau-lsp analyze` para `src/server` y `src/client`, con definiciones de Roblox y `sourcemap.json`. `src/shared`, `tests` y `tools` siguen en `--platform=standard`: ese pase es lo que impide usar globales de Roblox en el motor.
- [x] **Paso 1: Escribir las pruebas**

```luau
for _, bad in { {}, 1, "Roll", { type = "Nope" }, { type = "Bid", amount = -5 }, { type = "Bid", amount = 1.5 } } do
    it("rechaza entrada no válida", function()
        expect((Protocol.validate(bad))).toBe(false)
    end)
end
it("acepta una puja válida", function()
    expect((Protocol.validate({ type = "Bid", amount = 100 }))).toBe(true)
end)
```

- [x] **Paso 2:** Ejecutar `lune run tests/run Protocol`. Esperado: FAIL.
- [x] **Paso 3:** Implementar `Protocol` y `RemoteGateway`.
- [x] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [x] **Paso 5:** Hacer commit: `feat: validar acciones del cliente`.

### Task 2: Vista por jugador

**Módulos:** `rules/View`.

**Archivos:**
- Crear: `src/shared/rules/View.luau`, `tests/rules/View.spec.luau`

**Interfaces:**
- Produce: `View.forPlayer(state, playerId): PlayerView` y `View.filterEvents(state, playerId, events): { Event }`.

**Criterios de aceptación:**
- [x] Un jugador ve su mano y solo el número de cartas de los demás.
- [x] `CardDrawn` oculta el id de la carta a los demás, salvo si es legendaria y se juega.
- [x] Las elecciones secretas del Duelo no se revelan hasta `DuelResolved`.
- [x] Espía revela la mano del objetivo solo a quien jugó la carta.
- [x] `rng` nunca se incluye en la vista.

- [x] **Paso 1:** Escribir pruebas para cada criterio.
- [x] **Paso 2:** Ejecutar `lune run tests/run View`. Esperado: FAIL.
- [x] **Paso 3:** Implementar `View`.
- [x] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [x] **Paso 5:** Hacer commit: `feat: filtrar información por jugador`.

### Task 3: Servicio de partida y reloj de escenas

**Módulos:** `server/match/MatchService`, `server/match/SceneClock`, `config/Scenes`.

**Archivos:**
- Crear: `src/shared/config/Scenes.luau`, `src/server/match/SceneClock.luau`, `src/server/match/MatchService.luau`, `tests/server/SceneClock.spec.luau`

**Interfaces:**
- Produce: `Scenes.durationFor(event: Event, seenCount: number): number`.
- Produce: `SceneClock.new(): SceneClock`, `SceneClock.schedule(clock, events, now): number`, que devuelve cuándo termina la última escena.
- Produce: lote `{ seq: number, startsAt: number, events: { Event }, view: PlayerView }`.
- Produce: `MatchService.start(players: { Player }, seed: number, endMode: EndMode)`.

**Criterios de aceptación:**
- [x] `Scenes` da duración a cada evento de la arquitectura.
- [x] Comunes de 2 a 4 s; legendarias, hasta 10 s; repetidas en la misma partida, más cortas.
- [x] El temporizador de decisión no empieza hasta que termina la escena.
- [x] El servidor avanza con su reloj, sin esperar a ningún cliente.
- [x] `seq` crece de 1 en 1; `ResyncRequest` devuelve la vista actual.

- [x] **Paso 1: Escribir las pruebas**

```luau
it("encadena escenas", function()
    local clock = SceneClock.new()
    local endsAt = SceneClock.schedule(clock, { { type = "DiceRolled" }, { type = "TokenMoved", path = {} } }, 100)
    expect(endsAt > 100).toBeTruthy()
end)
it("acorta una escena ya vista", function()
    expect(Scenes.durationFor({ type = "BuildingChanged" }, 3) < Scenes.durationFor({ type = "BuildingChanged" }, 0)).toBeTruthy()
end)
it("ninguna legendaria supera 10 s", function()
    for _, id in { "Hurricane", "WorldFlip", "Revolution", "Earthquake", "CrownStrike" } do
        expect(Scenes.durationFor({ type = "CardPlayed", cardId = id }, 0) <= 10).toBeTruthy()
    end
end)
```

- [x] **Paso 2:** Ejecutar `lune run tests/run SceneClock`. Esperado: FAIL.
- [x] **Paso 3:** Implementar `Scenes`, `SceneClock` y `MatchService`.
- [x] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [x] **Paso 5:** En Studio, iniciar un Test Server con 2 clientes y jugar 3 turnos con un script de cliente temporal. Esperado: ambos reciben los lotes con `seq` 1, 2, 3 en orden.
- [x] **Paso 6:** Hacer commit: `feat: ejecutar la partida en el servidor`.

### Task 4: Presencia y bots

**Módulos:** `server/match/PresenceService`.

**Archivos:**
- Crear: `src/server/match/PresenceRules.luau`, `src/server/match/PresenceService.luau`, `tests/server/PresenceRules.spec.luau`

**Interfaces:**
- Produce: `PresenceRules.onLeave(seats, userId)`, `PresenceRules.onReturn(seats, userId): boolean`, `PresenceRules.isBotControlled(seats, playerId): boolean`.

**Criterios de aceptación:**
- [x] Quien se va pasa a control de bot de inmediato; su turno no se pierde.
- [x] Al volver, recupera asiento, mano y control.
- [x] Dos tiempos agotados seguidos activan el bot; cualquier acción lo desactiva.
- [x] Si no queda ningún humano, la partida termina y se registra como abandonada.

- [x] **Paso 1:** Escribir pruebas para cada criterio con `PresenceRules`.
- [x] **Paso 2:** Ejecutar `lune run tests/run PresenceRules`. Esperado: FAIL.
- [x] **Paso 3:** Implementar ambos módulos.
- [x] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [x] **Paso 5:** En Test Server con 3 clientes, cerrar uno a mitad de turno. Esperado: el bot juega y la partida sigue. **(Hecho con 2 clientes: el bot jugó 0,5 s después de la desconexión. Volver al asiento no se pudo probar: Studio da otro id al cliente nuevo.)**
- [x] **Paso 6:** Hacer commit: `feat: tomar el control con bots`.

### Task 5: Party privada y partidas públicas

**Módulos:** `server/lobby/PartyService`, `server/lobby/PublicQueue`.

**Archivos:**
- Crear: `src/server/lobby/PartyCode.luau`, `src/server/lobby/PartyService.luau`, `src/server/lobby/PublicQueue.luau`, `tests/server/PartyCode.spec.luau`
- Modificar: `default.project.json`; crear `lobby.project.json` para el segundo lugar

**Interfaces:**
- Produce: `PartyCode.generate(rng): string` (6 caracteres sin `0`, `O`, `1` ni `I`), `PartyCode.normalize(text: string): string?`.
- Produce: `PartyService.create(host: Player): string`, `PartyService.join(player: Player, code: string): (boolean, string?)`, `PartyService.start(host: Player, endMode: EndMode)`.
- Produce: `PublicQueue.enqueue(player: Player)`.

**Criterios de aceptación:**
- [ ] Antes de programar, se confirma el uso actual de `TeleportService` y `MemoryStoreService` en la documentación oficial.
- [ ] Un código válido reúne de 2 a 8 personas; solo el anfitrión inicia y elige el modo.
- [ ] Las partidas públicas siempre usan el modo Rondas.
- [ ] Un código caducado, lleno o mal escrito muestra un mensaje claro, sin teletransportar.
- [ ] Mayúsculas, minúsculas y espacios no importan.
- [ ] Al salir el anfitrión, el siguiente toma su lugar.
- [ ] Las partidas públicas agrupan de 2 a 8 y empiezan con 4 o más tras una espera máxima de 60 s.
- [ ] Un fallo de teletransporte se reintenta y, si persiste, devuelve al lobby con aviso.

Las casillas de criterios quedan sin marcar: el Paso 5 sigue pendiente por decisión del responsable y
ningún `MemoryStore` ni teletransporte real se ha ejecutado todavía; marcarlas afirmaría algo no
comprobado. El detalle y lo que debe demostrar la comprobación publicada están en
`.superpowers/sdd/plan-04-red-y-partidas/task-5-report.md`.

- [x] **Paso 1:** Escribir pruebas de `PartyCode`: longitud, alfabeto, `" ab3k9z "` se normaliza a `"AB3K9Z"`, y texto con símbolos devuelve `nil`.
- [x] **Paso 2:** Ejecutar `lune run tests/run PartyCode`. Esperado: FAIL.
- [x] **Paso 3:** Implementar los módulos.
- [x] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Pedir permiso al responsable para publicar en un lugar privado de prueba, necesario porque los servidores reservados no funcionan igual en Studio. Comprobar con 2 cuentas: crear código, unirse e iniciar.
- [x] **Paso 6:** Hacer commit: `feat: añadir party privada y cola pública`.

### Task 6: Revancha

**Módulos:** `server/match/RematchService`.

**Archivos:**
- Crear: `src/server/match/RematchRules.luau`, `src/server/match/RematchService.luau`, `tests/server/RematchRules.spec.luau`

**Interfaces:**
- Produce: `RematchRules.resolve(votes: { [number]: boolean }, present: { number }): "Start" | "Wait" | "NotEnough"`.

**Criterios de aceptación:**
- [ ] Al terminar, un botón inicia la revancha en el mismo servidor, sin teletransportar.
      **Mitad hecha:** el servidor de la revancha está terminado y probado (`RematchService` abre la
      votación al acabar, arranca la partida en el mismo servidor con otra semilla y devuelve al lobby
      a quien no acepta). El botón existe desde la corrección R-P42 (`client/ui/RematchMenu`), en arte
      gris, y se comprobó en un Test Server local con dos clientes. Queda sin marcar hasta probarlo en
      un lugar publicado, donde quien no acepta sí viaja al lobby.
- [x] Empieza cuando todos votan o a los 20 s, con quienes aceptaron.
- [x] Con menos de 2 personas, vuelve al lobby con aviso.
- [x] Quien no acepta vuelve al lobby.
- [x] La revancha usa otra semilla y conserva el grupo.

- [x] **Paso 1:** Escribir pruebas de `RematchRules` con 8, 2 y 1 aceptación.
- [x] **Paso 2:** Ejecutar `lune run tests/run RematchRules`. Esperado: FAIL.
- [x] **Paso 3:** Implementar ambos módulos.
- [x] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [x] **Paso 5:** Hacer commit: `feat: añadir revancha`.

### Task 7: Telemetría

**Módulos:** `server/match/Telemetry`, `server/match/MatchSummary`.

**Archivos:**
- Crear: `src/server/match/MatchSummary.luau`, `src/server/match/Telemetry.luau`, `tests/server/MatchSummary.spec.luau`, `tools/criteria-report.luau`

**Interfaces:**
- Produce: `MatchSummary.fromState(state, startedAt, endedAt, rematch: boolean, abandoned: boolean): Summary`.
- Produce: `Summary = { id, sizeId, endMode, players, durationSec, avgTurnSec, leaderAtHalfWon, finished, rematch, cardsPlayed, sceneSec }`.

**Criterios de aceptación:**
- [x] Antes de programar, se confirma el uso actual de `AnalyticsService` en la documentación oficial.
- [x] Cada partida genera un resumen, también si se abandona.
- [x] Con los resúmenes exportados, `tools/criteria-report` calcula, solo con partidas en modo Rondas, los 4 criterios medibles: partidas terminadas, segunda partida, duración y líder a mitad de partida.
- [x] No se guarda ningún dato personal: el id de partida es aleatorio y no se registran nombres.

- [x] **Paso 1:** Escribir pruebas de `MatchSummary` y del cálculo del informe con resúmenes de ejemplo.
- [x] **Paso 2:** Ejecutar `lune run tests/run MatchSummary`. Esperado: FAIL.
- [x] **Paso 3:** Implementar los módulos.
- [x] **Paso 4:** Ejecutar `lune run tools/check`. Esperado: código 0.
      Ejecutado al cerrar la rama en `2afbf90`: código 0, con las diez comprobaciones en verde
      (formato, lint, tipos estándar, mapa de Rojo, tipos de Roblox de la partida, mapa del lobby,
      tipos de Roblox del lobby, pruebas, motor puro y manifiesto).
- [x] **Paso 5:** Hacer commit: `feat: medir criterios de salida`.

---

## Cómo quedó

Ejecutada en modo subagentes el 2026-11-03: siete tareas, cada una implementada por un subagente
nuevo y revisada por otro, con hasta cinco rondas de corrección por tarea y una revisión final de
toda la rama. Las casillas de arriba reflejan lo que se comprobó.

**Lo que se añadió al plan, y por qué** (todo con su ruling en la arquitectura):

- **Dos proyectos de Rojo.** El plan solo hablaba de `default.project.json`; hay un segundo lugar,
  así que existe `lobby.project.json`. El trabajo de servidor destapó además que la convención de
  `require` relativo no cruza servicios en Roblox: `src/shared` se monta también en cada servicio
  con la clave `shared` en minúsculas, y la profundidad del DataModel tiene que igualar la del disco.
- **Un punto de cableado por lugar.** `src/server/main.server.luau` y `src/server/lobby/main.server.luau`
  conectan los remotos una sola vez; sin ellos nada recibía acciones ni empezaba partidas.
- **`MatchState`, `LobbyRules`, `PresenceRules` y `RematchRules`.** Cuatro módulos puros más, para
  que la numeración de lotes, los plazos, los asientos y los votos se puedan probar con Lune.
- **Adaptadores de almacén y teletransporte.** `MemoryStoreService` y `TeleportService` no existen en
  Studio, así que cada uno tiene su versión en memoria y la real.
- **Un remoto para votar la revancha y cinco para el lobby**, en `Protocol.REMOTES` con sus validadores.

**Pendiente y por qué:**

- **Paso 5 de las tareas 3, 4 y 5.** El plan pide un Test Server con dos clientes, cerrar uno a mitad
  de turno y publicar en un lugar privado con dos cuentas. Lo primero se hizo en parte: un Test Server
  real difundió 12 a 16 lotes, tres turnos y cero rechazos, y en una prueba de tres jugadores dos
  clientes recibieron los lotes 1, 2 y 3 en orden. Lo segundo no se hizo: los dos lugares siguen sin
  publicar y `config/Places` vale `0`, que es exactamente el caso que el lobby trata con un aviso. El
  responsable decidió el 2026-11-03 dejar la publicación pendiente.
- **El botón de la revancha** es interfaz de las subfases 05 y 08. El servidor está terminado.
- **`tests/sim-report.luau` mantiene el sesgo de contar «sin líder» como derrota** en su propio
  informe de simulación; es un camino separado del de `MatchSummary`, que ya no lo tiene.


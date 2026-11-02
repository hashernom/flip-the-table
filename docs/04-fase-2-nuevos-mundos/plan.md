# Fase 2: Nuevos mundos. Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Plan vivo:** antes de ejecutarlo, se revisa con los resultados de la Fase 1.

**Goal:** Añadir dos mapas con reglas propias y partys de 9 a 12.

**Architecture:** Un `MapDefinition` declara tablero, reglas, mazo y escenas. `MapRules` llama a los ganchos de cada mapa en momentos fijos del motor. Metrópolis es el primer mapa migrado a este sistema.

**Tech Stack:** Luau, Lune, Blender, Roblox Studio.

**Spec:** [ficha de la fase](ficha.md), [ficha general](../00-ficha/ficha-propuesta.md) y [arquitectura](../01-arquitectura/arquitectura.md).

## Ejecución recomendada

**Modo:** subagentes, con `superpowers:subagent-driven-development`.

**Por qué:** la Tarea 1 modifica el corazón de un motor ya publicado y cada mapa es casi un proyecto propio. Un contexto nuevo por tarea evita saturar la sesión, y un revisor independiente protege a Metrópolis de regresiones.

**Instrucciones para la sesión:**

- Sigue también las [instrucciones generales](../instrucciones-de-sesion.md).
- Requiere la Fase 1 validada. Antes de empezar, actualiza este plan con sus resultados y acuérdalo con el responsable.
- La Tarea 1 va primero y no cambia ningún comportamiento: los resultados deben coincidir con `tests/golden/`.
- Valida cada mapa en gris con amigos antes de producir arte final.
- Blender y Studio se usan de uno en uno.
- Construye Reino Embrujado solo si el responsable lo decide con los datos.
- Termina con `resultados.md` y la decisión del responsable sobre la Fase 3.

## Global Constraints

- Cada mapa tiene su tema, sus reglas y sus propias escenas.
- Todo el grupo ve la misma escena a la vez.
- Comunes de 2 a 4 s; legendarias, hasta 10 s.
- Cada asset cumple el estándar y se aprueba por una persona.
- Ninguna regla de mapa pide arriesgar nada de valor en un juego de azar.
- Partys de 9 a 12: una ciudad con más barrios y turnos más cortos.

## Review Focus

1. La marea cubre la casilla donde está una ficha: la ficha se mueve a la siguiente libre. Prueba en Tarea 3.
2. La gravedad se invierte durante un recorrido o sobre la Salida: nadie cobra dos veces. Prueba en Tarea 4.
3. Un jugador vota mapa y se va: la votación termina igual. Prueba en Tarea 5.
4. Un cliente no ha terminado de cargar el mapa al empezar: no bloquea a los demás. Prueba en Tarea 5.
5. Una carta interactúa con una regla de mapa, por ejemplo Mundo al Revés sobre una casilla inundada. Prueba en Tarea 3.

---

### Task 1: Marco de mapas

**Módulos:** `config/maps/Metropolis`, `rules/MapRules`, `client/world/MapLoader`.

**Archivos:**
- Crear: `src/shared/config/maps/Metropolis.luau`, `src/shared/rules/MapRules.luau`, `src/client/world/MapLoader.luau`, `tests/rules/MapRules.spec.luau`
- Modificar: `State.luau`, `Turn.luau`, `Movement.luau`, `Property.luau`, `Boards.luau`, `CityBuilder.luau`

**Interfaces:**
- Produce: `MapDefinition = { id: string, boards: { [SizeId]: Board }, hooks: MapHooks?, extraCards: { string }, scenes: { [string]: string }, music: string }`.
- Produce: `MapHooks = { onRoundStart: ((state) -> { Event })?, canLandOn: ((state, index: number) -> boolean)?, moveDirection: ((state) -> number)?, rentMultiplier: ((state, index: number) -> number)? }`.
- Modifica: `State.create(opts: { ..., mapId: string? })`, con `Metropolis` por defecto.

**Criterios de aceptación:**
- [ ] Sin cambios de comportamiento: todas las pruebas y simulaciones de Metrópolis siguen pasando.
- [ ] Una misma semilla da el mismo resultado antes y después de la migración.
- [ ] Un mapa sin ganchos funciona sin ramas especiales.
- [ ] El mapa elegido se carga; los demás no.

- [ ] **Paso 1:** Antes de migrar, guardar en `tests/golden/` los resultados de 100 partidas con semilla fija.
- [ ] **Paso 2:** Escribir la prueba: los resultados tras la migración coinciden con `tests/golden/`.
- [ ] **Paso 3:** Implementar el marco y migrar Metrópolis.
- [ ] **Paso 4:** Ejecutar `lune run tools/check`. Esperado: código 0.
- [ ] **Paso 5:** Hacer commit: `refactor: separar los mapas del motor`.

### Task 2: Partys de 9 a 12

**Módulos:** `config/Boards`, `config/Scenes`, `rules/State`, `server/lobby/PartyService`.

**Archivos:**
- Modificar: `Boards.luau`, `Economy.luau`, `Scenes.luau`, `State.luau`, `PartyService.luau`, `PublicQueue.luau`
- Crear: `tests/rules/LargeParty.spec.luau`

**Interfaces:**
- Modifica: `SizeId = "S" | "M" | "L" | "XL"`. `Boards.forPlayerCount(9..12)` devuelve `"XL"`.

**Criterios de aceptación:**
- [ ] Antes de programar, se confirma el límite de jugadores por servidor en la documentación vigente.
- [ ] XL: 56 casillas, 10 rondas (valor inicial) y temporizador de decisión de 15 s.
- [ ] Las escenas comunes usan su duración mínima en XL.
- [ ] 1000 partidas simuladas de 12 jugadores cumplen los invariantes.
- [ ] Un jugador recibe más acciones fuera de turno, como emotes y reacciones, y lo confirma una prueba con amigos.
- [ ] El peor caso, con 12 jugadores y una legendaria, se mantiene en 30 FPS o más en el móvil de referencia.

- [ ] **Paso 1:** Escribir pruebas: XL tiene 56 casillas, y 13 jugadores se rechazan.
- [ ] **Paso 2:** Ejecutar `lune run tests/run LargeParty`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar los datos y los límites.
- [ ] **Paso 4:** Ejecutar `lune run tools/check`. Esperado: código 0.
- [ ] **Paso 5:** Hacer commit: `feat: permitir partys de 9 a 12`.

### Task 3: Isla Pirata

**Módulos:** `config/maps/PirateIsland`, `rules/maps/Tide`, `client/scenes/maps/pirate/*`, `art/blender/maps/pirate`.

**Archivos:**
- Crear: los módulos anteriores y `tests/rules/maps/Tide.spec.luau`

**Interfaces:**
- Produce: `Tide.onRoundStart(state): { Event }`, `Tide.canLandOn(state, index): boolean`.
- Evento: `TideChanged { level, flooded: { number } }`.

**Criterios de aceptación:**
- [ ] Antes de la producción final, una versión gris se prueba con amigos y una porción vertical se aprueba.
- [ ] La marea sube y baja por rondas y deja sin servicio las casillas de la costa: no se compran ni cobran.
- [ ] Una ficha sobre una casilla inundada pasa a la siguiente libre.
- [ ] Una regla del mapa no atasca la partida al combinarse con cualquier carta.
- [ ] El kraken que arrastra un barco a la bahía tiene su escena estrella de 10 s o menos.
- [ ] Ciudad, edificios, casillas, personajes, música y mazo propio siguen el estándar.

- [ ] **Paso 1: Escribir las pruebas**

```luau
it("una casilla inundada no cobra", function()
    local s = Fixtures.game({ players = 4, mapId = "PirateIsland" })
    local idx = Fixtures.coastalProperty(s); Fixtures.give(s, s.players[1].id, idx)
    Fixtures.setTide(s, idx)
    expect(Property.rentFor(s, idx)).toBe(0)
end)
it("Mundo al Revés no deja fichas en casillas inundadas", function()
    -- Tras jugar la carta con marea alta, ninguna ficha queda en una casilla inundada.
end)
```

- [ ] **Paso 2:** Ejecutar `lune run tests/run Tide`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar las reglas y simular 1000 partidas por tamaño.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Probar la versión gris con amigos; ajustar.
- [ ] **Paso 6:** Producir la porción vertical y obtener la aprobación.
- [ ] **Paso 7:** Producir el mapa completo, sus escenas y su audio.
- [ ] **Paso 8:** Ejecutar `lune run tools/check`. Esperado: código 0.
- [ ] **Paso 9:** Hacer commit: `feat: añadir Isla Pirata`.

### Task 4: Estación Espacial

**Módulos:** `config/maps/SpaceStation`, `rules/maps/GravityFlip`, `client/scenes/maps/space/*`, `art/blender/maps/space`.

**Archivos:**
- Crear: los módulos anteriores y `tests/rules/maps/GravityFlip.spec.luau`

**Interfaces:**
- Produce: `GravityFlip.onRoundStart(state): { Event }`, `GravityFlip.moveDirection(state): number`.
- Evento: `GravityFlipped { direction: number }`.

**Criterios de aceptación:**
- [ ] Antes de la producción final, una versión gris se prueba con amigos y una porción vertical se aprueba.
- [ ] Un fallo de gravedad invierte el sentido de la ruta durante unas rondas fijas.
- [ ] Pasar la Salida en sentido inverso paga igual, una sola vez por vuelta.
- [ ] El sentido no cambia en mitad de un recorrido.
- [ ] La lluvia de meteoritos tiene su escena estrella de 10 s o menos.
- [ ] Ciudad, edificios, casillas, personajes, música y mazo propio siguen el estándar.

- [ ] **Paso 1:** Escribir pruebas de sentido, Salida y cambio solo al empezar la ronda.
- [ ] **Paso 2:** Ejecutar `lune run tests/run GravityFlip`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar y simular 1000 partidas por tamaño.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Probar con amigos, producir la porción vertical y obtener la aprobación.
- [ ] **Paso 6:** Producir el mapa completo, sus escenas y su audio.
- [ ] **Paso 7:** Ejecutar `lune run tools/check`. Esperado: código 0.
- [ ] **Paso 8:** Hacer commit: `feat: añadir Estación Espacial`.

### Task 5: Elección de mapa

**Módulos:** `server/lobby/MapVote`, `client/ui/MapVoteMenu`.

**Archivos:**
- Crear: `src/server/lobby/MapVoteRules.luau`, `src/server/lobby/MapVote.luau`, `src/client/ui/MapVoteMenu.luau`, `tests/server/MapVoteRules.spec.luau`

**Interfaces:**
- Produce: `MapVoteRules.resolve(votes: { [number]: string }, maps: { string }, rngSeed: number): string`.

**Criterios de aceptación:**
- [ ] El anfitrión elige o activa una votación de 15 s.
- [ ] Un empate se resuelve de forma determinista con la semilla.
- [ ] Sin votos, queda el mapa anterior.
- [ ] Quien se va no bloquea la votación.
- [ ] La partida empieza cuando todos cargan, con un máximo de 30 s; un cliente atrasado entra bajo control del bot hasta que esté listo.

- [ ] **Paso 1:** Escribir pruebas de `MapVoteRules`.
- [ ] **Paso 2:** Ejecutar `lune run tests/run MapVoteRules`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar los módulos.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir elección de mapa`.

### Task 6: Validación de la fase

**Módulos:** `tools/criteria-report`.

**Archivos:**
- Crear: `docs/04-fase-2-nuevos-mundos/resultados.md`

**Criterios de aceptación:**
- [ ] Cada criterio de la [ficha](ficha.md) está medido.
- [ ] Se decide si se construye Reino Embrujado.
- [ ] El responsable decide por escrito si se abre la Fase 3.

- [ ] **Paso 1:** Publicar solo con la aprobación del responsable.
- [ ] **Paso 2:** Medir durante 4 semanas y escribir `resultados.md`.
- [ ] **Paso 3:** Hacer commit: `docs: registrar resultados de la Fase 2`.

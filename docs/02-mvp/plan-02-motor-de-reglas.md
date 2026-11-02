# Subfase 02: Motor de reglas. Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Una partida base completa, de principio a fin, ejecutable sin Roblox.

**Architecture:** `Engine.apply` valida una acción, modifica el estado y devuelve eventos. Cada módulo cubre una regla y no conoce la red ni las escenas.

**Tech Stack:** Luau, Lune.

**Spec:** sección "Juego base" de la [ficha](../00-ficha/ficha-propuesta.md); contratos y valores en [arquitectura](../01-arquitectura/arquitectura.md).

## Ejecución recomendada

**Modo:** subagentes, con `superpowers:subagent-driven-development`.

**Por qué:** las 10 tareas comparten estado y contratos, y todo el juego se apoya en este motor. Una regla mal implementada se arrastraría a cada tarea siguiente, así que compensa revisar cada una antes de avanzar.

**Instrucciones para la sesión:**

- Sigue también las [instrucciones generales](../instrucciones-de-sesion.md).
- Requiere el plan 01 terminado. No necesita Studio ni Blender: todo se ejecuta con Lune.
- Pasa a cada subagente su tarea, la sección de contratos de la arquitectura y las firmas de las tareas anteriores.
- Una tarea no termina hasta que el revisor confirma sus criterios y `lune run tests/run` pasa completo.
- En la Tarea 10, si la simulación descubre un error, se corrige en el motor; no se relajan sus invariantes.
- Termina cuando 1000 partidas por número de jugadores cumplen los invariantes.

## Global Constraints

- El motor es determinista: mismo estado y mismas acciones, mismos eventos.
- Una acción ilegal devuelve `ok = false` y no cambia nada.
- Bancarrota no elimina: el jugador pasa a espectro.
- Gana el mayor patrimonio: efectivo más propiedades y edificios.
- Subasta de 15 s; decisión de 20 s; si se agota el tiempo, el juego decide.
- Renta doble en las dos últimas rondas.

## Review Focus

1. Un jugador no puede actuar fuera de su turno ni de su fase. Prueba en Tarea 9.
2. No puede quedar dinero negativo después de resolver una deuda. Prueba en Tarea 7.
3. Una partida nunca se atasca, aunque nadie haga nada. Prueba en Tarea 10.
4. Una deuda que supera todo el patrimonio no genera dinero de la nada. Prueba en Tarea 7.
5. Un empate de patrimonio tiene un ganador claro y estable. Prueba en Tarea 8.

---

### Task 1: Crear partida

**Módulos:** `rules/State`, `rules/Board`.

**Archivos:**
- Crear: `src/shared/rules/State.luau`, `src/shared/rules/Board.luau`, `tests/rules/State.spec.luau`, `tests/fixtures.luau`

**Interfaces:**
- Produce: `State.create(opts: { playerIds: { PlayerId }, seed: number }): GameState`
- Produce: `Board.square(state, index): Square`, `Board.zoneOf(state, index): { number }?`, `Board.ownsZone(state, playerId, zoneId): boolean`
- Produce: `Fixtures.game(opts: { players: number, seed: number? }): GameState`, `Fixtures.dice(state, a: number, b: number)`, `Fixtures.placeOn(state, playerId, index)`, `Fixtures.give(state, playerId, index)`, `Fixtures.squareOf(state, kind: SquareKind): number`, `Fixtures.hand(state, playerId, cardId: string)`, `Fixtures.turnOf(state, playerId)`.

**Criterios de aceptación:**
- [ ] Rechaza menos de 2 o más de 8 jugadores.
- [ ] Todos empiezan en la casilla 1 con 1500.
- [ ] El orden de turnos se decide con la semilla.
- [ ] `maxRounds` es 20, 15 o 12 según el tamaño.

- [ ] **Paso 1: Escribir las pruebas**

```luau
it("asigna tablero y rondas según jugadores", function()
    local s = Fixtures.game({ players = 8 })
    expect(s.sizeId).toBe("L"); expect(#s.board.squares).toBe(48); expect(s.maxRounds).toBe(12)
end)
it("rechaza 9 jugadores", function()
    expect(function() Fixtures.game({ players = 9 }) end).toThrow()
end)
it("empieza con 1500 en la casilla 1", function()
    local p = Fixtures.game({ players = 4 }).players[1]
    expect(p.cash).toBe(1500); expect(p.position).toBe(1)
end)
```

- [ ] **Paso 2:** Ejecutar `lune run tests/run State`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar `State`, `Board` y `Fixtures`.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: crear partida`.

### Task 2: Tirar dados y moverse

**Módulos:** `rules/Movement`, `rules/Engine`, `rules/Turn`.

**Archivos:**
- Crear: `src/shared/rules/Movement.luau`, `src/shared/rules/Turn.luau`, `src/shared/rules/Engine.luau`, `tests/rules/Movement.spec.luau`

**Interfaces:**
- Produce: `Engine.apply(state, playerId, action): ApplyResult`
- Produce: `Movement.advance(state, playerId, steps: number): { Event }`, con `steps` negativo para retroceder.
- Eventos: `DiceRolled { playerId, a, b }`, `TokenMoved { playerId, from, to, path }`, `PassedStart { playerId, amount }`.

**Criterios de aceptación:**
- [ ] Moverse da la vuelta al tablero.
- [ ] Pasar o caer en la Salida paga 200; retroceder sobre ella no paga.
- [ ] `TokenMoved` incluye la ruta para que el cliente la recorra.

- [ ] **Paso 1: Escribir las pruebas**

```luau
it("avanza lo que marcan los dados", function()
    local s = Fixtures.game({ players = 4 }); local id = s.players[s.turnIndex].id
    Fixtures.dice(s, 3, 4)
    expect(Engine.apply(s, id, { type = "Roll" }).ok).toBe(true)
    expect(s.players[s.turnIndex].position).toBe(8)
end)
it("paga 200 al pasar por la Salida", function()
    local s = Fixtures.game({ players = 4 }); local id = s.players[s.turnIndex].id
    Fixtures.placeOn(s, id, 31); Fixtures.dice(s, 1, 2)
    Engine.apply(s, id, { type = "Roll" })
    expect(s.players[s.turnIndex].cash).toBe(1700)
end)
```

- [ ] **Paso 2:** Ejecutar `lune run tests/run Movement`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar el movimiento y la fase `AwaitRoll`.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: tirar dados y mover fichas`.

### Task 3: Comprar y pagar renta

**Módulos:** `rules/Property`.

**Archivos:**
- Crear: `src/shared/rules/Property.luau`, `tests/rules/Property.spec.luau`

**Interfaces:**
- Produce: `Property.buy(state, playerId, index, price: number?): { Event }`, `Property.rentFor(state, index): number`, `Property.payRent(state, payerId, index): { Event }`, `Property.rentMultiplier(state, index): number`.
- Fases: caer en una propiedad libre con dinero lleva a `AwaitBuy`; `Buy` compra y `DeclineBuy` abre subasta.

**Criterios de aceptación:**
- [ ] Renta base del 10 % del precio; × 2 con el grupo completo.
- [ ] No se puede comprar sin dinero suficiente.
- [ ] Caer en lo propio no cobra.
- [ ] El multiplicador total nunca supera × 4.

- [ ] **Paso 1: Escribir las pruebas**

```luau
it("cobra el 10 % del precio", function()
    local s = Fixtures.game({ players = 2 }); local a, b = s.players[1].id, s.players[2].id
    local idx = Fixtures.squareOf(s, "Property"); Fixtures.give(s, a, idx)
    local rent = s.board.squares[idx].price * 0.1
    Property.payRent(s, b, idx)
    expect(s.players[1].cash).toBe(1500 + rent); expect(s.players[2].cash).toBe(1500 - rent)
end)
it("duplica la renta con el grupo completo", function()
    -- Dar las 3 casillas de la zona a A; rentFor devuelve 20 % del precio.
end)
it("no permite comprar sin dinero", function()
    -- Efectivo 10 en AwaitBuy: Engine.apply Buy devuelve ok = false y el estado no cambia.
end)
```

- [ ] **Paso 2:** Ejecutar `lune run tests/run Property`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar `Property` y conectar `Buy` y `DeclineBuy` en `Engine`.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: comprar propiedades y pagar renta`.

### Task 4: Subastas

**Módulos:** `rules/Auction`.

**Archivos:**
- Crear: `src/shared/rules/Auction.luau`, `tests/rules/Auction.spec.luau`

**Interfaces:**
- Produce: `Auction.start(state, index): { Event }`, `Auction.bid(state, playerId, amount): ApplyResult`, `Auction.close(state): { Event }`.
- Eventos: `AuctionStarted { index }`, `AuctionWon { index, playerId, amount }`, `AuctionNoSale { index }`.

**Criterios de aceptación:**
- [ ] Cada puja debe superar a la anterior y no exceder el efectivo.
- [ ] Puede pujar cualquier jugador activo, incluido quien rechazó.
- [ ] Sin pujas, la propiedad sigue libre.
- [ ] Al agotarse el tiempo gana la puja más alta.

- [ ] **Paso 1:** Escribir pruebas para: puja válida, puja baja rechazada, puja mayor que el efectivo rechazada, cierre con ganador y cierre sin pujas.
- [ ] **Paso 2:** Ejecutar `lune run tests/run Auction`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar la fase `Auction` y `Bid`.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir subastas`.

### Task 5: Edificios

**Módulos:** `rules/Building`.

**Archivos:**
- Crear: `src/shared/rules/Building.luau`, `tests/rules/Building.spec.luau`

**Interfaces:**
- Produce: `Building.build(state, playerId, index): ApplyResult`, `Building.lower(state, index): { Event }`, `Building.costOf(state, playerId, index): number`.
- Evento: `BuildingChanged { index, from, to }`.

**Criterios de aceptación:**
- [ ] Solo se construye con la zona completa.
- [ ] Niveles de 0 a 3: solar, casa, edificio y rascacielos.
- [ ] La renta usa × 3, × 6 y × 10 según el nivel.
- [ ] Bajar de nivel 0 no hace nada.

- [ ] **Paso 1:** Escribir pruebas para: construir sin zona falla, construir con zona sube y cobra el 50 % del precio, nivel 4 falla, y renta en cada nivel.
- [ ] **Paso 2:** Ejecutar `lune run tests/run Building`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar `Building` y `Build` en `Engine`.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir niveles de edificio`.

### Task 6: Intercambios

**Módulos:** `rules/Trade`.

**Archivos:**
- Crear: `src/shared/rules/Trade.luau`, `tests/rules/Trade.spec.luau`

**Interfaces:**
- Produce: `Trade.propose(state, fromId, offer: TradeOffer): ApplyResult`, `Trade.respond(state, playerId, tradeId, accept: boolean): ApplyResult`.
- Produce: `TradeOffer = { toId: PlayerId, giveCash: number, wantCash: number, giveSquares: { number }, wantSquares: { number } }`.

**Criterios de aceptación:**
- [ ] Solo se ofrece lo que se posee.
- [ ] Al aceptar se valida otra vez, por si algo cambió.
- [ ] Una propiedad con edificios no se intercambia hasta demolerlos.
- [ ] Una oferta caduca al terminar el turno en que se hizo.

- [ ] **Paso 1:** Escribir pruebas para: oferta válida aceptada, rechazada, propiedad ajena, dinero insuficiente al aceptar y caducidad.
- [ ] **Paso 2:** Ejecutar `lune run tests/run Trade`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar `Trade`.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir intercambios`.

### Task 7: Bancarrota y espectros

**Módulos:** `rules/Bankruptcy`, `rules/Score`.

**Archivos:**
- Crear: `src/shared/rules/Bankruptcy.luau`, `src/shared/rules/Score.luau`, `tests/rules/Bankruptcy.spec.luau`

**Interfaces:**
- Produce: `Bankruptcy.charge(state, payerId, amount, creditorId: PlayerId?): { Event }`, `Score.netWorth(state, playerId): number`, `Score.ranking(state): { PlayerId }`.
- Evento: `BankruptcyDeclared { playerId, creditorId? }`.

**Criterios de aceptación:**
- [ ] Si falta dinero, se venden automáticamente edificios y propiedades al banco a la mitad de su valor, de menor a mayor.
- [ ] Si aun así no alcanza, el jugador queda con 0 y pasa a `Ghost`; el acreedor cobra solo lo disponible.
- [ ] Sus propiedades restantes vuelven al banco.
- [ ] Los espectros no aparecen como dueños ni pagan renta.

- [ ] **Paso 1: Escribir las pruebas**

```luau
it("no crea dinero al arruinarse", function()
    local s = Fixtures.game({ players = 2 }); local a, b = s.players[1], s.players[2]
    a.cash = 100
    Bankruptcy.charge(s, a.id, 5000, b.id)
    expect(a.status).toBe("Ghost"); expect(a.cash).toBe(0)
    expect(b.cash).toBe(1600)
end)
it("vende antes de arruinarse", function()
    -- A con 50 y una propiedad de 200 debe 100: vende, paga y sigue Active con 50.
end)
```

- [ ] **Paso 2:** Ejecutar `lune run tests/run Bankruptcy`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar `Bankruptcy` y `Score`; hacer que `Property.payRent` cobre con `Bankruptcy.charge`.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir bancarrota sin eliminación`.

### Task 8: Rondas y final

**Módulos:** `rules/Turn`, `rules/Score`.

**Archivos:**
- Modificar: `src/shared/rules/Turn.luau`, `src/shared/rules/Score.luau`
- Crear: `tests/rules/Turn.spec.luau`

**Interfaces:**
- Produce: `Turn.next(state): { Event }`, `Turn.isFinalRound(state): boolean`.
- Eventos: `RoundStarted { round }`, `FinalRoundsStarted { round }`, `CrownMoved { from, to }`, `GameEnded { ranking, winnerId }`.

**Criterios de aceptación:**
- [ ] La partida termina tras la última ronda de su tamaño.
- [ ] En las dos últimas rondas la renta se duplica.
- [ ] Con un solo jugador activo, la partida continúa: los espectros aún pueden resucitar.
- [ ] Los empates se resuelven por efectivo y, si persisten, por orden de turno.
- [ ] La Corona pasa al primero de la clasificación al empezar cada ronda.

- [ ] **Paso 1: Escribir las pruebas**

```luau
it("duplica la renta en las dos últimas rondas", function()
    local s = Fixtures.game({ players = 8 }); s.round = 11
    expect(Turn.isFinalRound(s)).toBe(true)
    s.round = 10; expect(Turn.isFinalRound(s)).toBe(false)
end)
it("desempata por efectivo", function()
    -- A y B con igual patrimonio; A con más efectivo queda primero.
end)
```

- [ ] **Paso 2:** Ejecutar `lune run tests/run Turn`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar rondas, Corona y final.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir rondas y final de partida`.

### Task 9: Fases, permisos y tiempo agotado

**Módulos:** `rules/Engine`, `rules/Bot`.

**Archivos:**
- Modificar: `src/shared/rules/Engine.luau`
- Crear: `src/shared/rules/Bot.luau`, `tests/rules/Engine.spec.luau`

**Interfaces:**
- Produce: `Engine.legalActions(state, playerId): { Action }`, `Engine.timeout(state): { Event }`, `Bot.choose(state, playerId): Action`.

**Criterios de aceptación:**
- [ ] Toda acción ilegal se rechaza sin cambiar el estado.
- [ ] `legalActions` nunca incluye una acción que `apply` rechazaría.
- [ ] Al agotarse el tiempo: `AwaitRoll` tira, `AwaitBuy` rechaza, `Auction` cierra y `AwaitEnd` termina el turno.
- [ ] `Bot.choose` siempre devuelve una acción legal.

- [ ] **Paso 1: Escribir las pruebas**

```luau
it("rechaza actuar fuera de turno sin cambiar nada", function()
    local s = Fixtures.game({ players = 4 }); local other = s.players[s.turnIndex % 4 + 1].id
    local before = table.clone(s)
    expect(Engine.apply(s, other, { type = "Roll" }).ok).toBe(false)
    expect(s.turnIndex).toBe(before.turnIndex); expect(s.phase).toBe(before.phase)
end)
it("toda acción legal se puede aplicar", function()
    -- En 200 estados de una simulación, aplicar cada acción legal sobre una copia devuelve ok.
end)
```

- [ ] **Paso 2:** Ejecutar `lune run tests/run Engine`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar la validación central, el tiempo agotado y `Bot` con una heurística simple: compra si le quedan más de 200 y construye si puede.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir permisos, tiempo agotado y bot`.

### Task 10: Simulación de partidas

**Módulos:** `tests/sim`.

**Archivos:**
- Crear: `tests/sim.luau`, `tests/sim.spec.luau`

**Interfaces:**
- Produce: `Sim.play(opts: { players: number, seed: number, idle: boolean? }): SimResult`, con `{ finished: boolean, turns: number, leaderAtHalf: PlayerId, winner: PlayerId, events: { [string]: number } }`.

**Criterios de aceptación:**
- [ ] 1000 partidas por cada número de jugadores, de 2 a 8, terminan.
- [ ] En ningún momento hay efectivo negativo tras resolver una acción.
- [ ] Cada propiedad tiene un dueño como máximo y su dueño nunca es un espectro.
- [ ] Con `idle = true`, solo con tiempo agotado, la partida también termina.
- [ ] La misma semilla produce el mismo resultado.

- [ ] **Paso 1:** Escribir las pruebas con esos invariantes.
- [ ] **Paso 2:** Ejecutar `lune run tests/run sim`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar `Sim.play`; corregir en el motor lo que descubra.
- [ ] **Paso 4:** Ejecutar `lune run tools/check`. Esperado: código 0.
- [ ] **Paso 5:** Hacer commit: `test: simular partidas completas`.

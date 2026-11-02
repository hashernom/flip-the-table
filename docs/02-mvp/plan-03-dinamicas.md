# Subfase 03: Dinámicas únicas. Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Añadir al motor las cartas, los perks, las casillas nuevas, los pactos y la remontada.

**Architecture:** Cada sistema es un módulo puro que se conecta a `Engine`. Las cartas y los perks son datos en `config`, con su efecto en una tabla de funciones por id.

**Tech Stack:** Luau, Lune.

**Spec:** sección "Dinámicas únicas" de la [ficha](../00-ficha/ficha-propuesta.md); valores en [arquitectura](../01-arquitectura/arquitectura.md).

## Ejecución recomendada

**Modo:** subagentes, con `superpowers:subagent-driven-development`.

**Por qué:** cartas, perks, reacciones y pactos se combinan de muchas formas, y ahí aparecen los errores difíciles de ver. Un revisor nuevo en cada tarea comprueba esas combinaciones sin dar por buenas las suposiciones de quien las programó.

**Instrucciones para la sesión:**

- Sigue también las [instrucciones generales](../instrucciones-de-sesion.md).
- Requiere el plan 02 terminado. Solo usa Lune.
- Copia los efectos de la tabla de la ficha; si uno no se puede cumplir, detente y pregunta en vez de reinterpretarlo.
- Nada de este plan puede pedir una apuesta: el revisor lo comprueba en Duelo, Cartelera y Mercado Negro.
- Un valor nuevo va a `config` y a la tabla de la arquitectura.
- Termina cuando `lune run tests/sim-report` muestra todas las cartas y los perks usados, y entrega ese informe al responsable.

## Global Constraints

- Un giro sorprende y sacude la partida, pero nunca elimina a nadie ni la termina por sí solo.
- Mano máxima: 3 cartas. Legendaria: como máximo una cada 3 rondas.
- Huracán: una vez por partida, nunca en las últimas 2 rondas, con compensación de la mitad del valor.
- Ninguna mecánica pide arriesgar dinero en un juego de azar.
- Perks visibles para todos, elegidos en 3 momentos.
- Pactos, votos y duelos funcionan solo con menús.

## Review Focus

1. Una carta dirigida a un espectro o a quien se fue no deja la partida esperando. Prueba en Tarea 4.
2. Dos reacciones posibles no crean una cadena infinita. Prueba en Tarea 5.
3. Un Tribunal con un solo votante resuelve sin atascarse. Prueba en Tarea 7.
4. Un jugador sin dinero para un peaje o una multa recibe el trato de bancarrota. Prueba en Tarea 7.
5. Un pacto cuyo socio se arruina termina y devuelve la garantía. Prueba en Tarea 8.

---

### Task 1: Datos y robo de cartas

**Módulos:** `config/Cards`, `rules/Deck`.

**Archivos:**
- Crear: `src/shared/config/Cards.luau`, `src/shared/rules/Deck.luau`, `tests/rules/Deck.spec.luau`

**Interfaces:**
- Produce: `Cards.all: { CardDef }`, con `CardDef = { id: string, name: string, rarity: Rarity, target: "None" | "Player" | "Zone" | "Property" | "Pact", reaction: boolean, leaderOnly: boolean? }`.
- Produce: `Deck.draw(state, playerId, minRarity: Rarity?): { Event }`.
- Ids: `Hurricane`, `WorldFlip`, `Revolution`, `Earthquake`, `CrownStrike`, `Inflation`, `Blackout`, `BounceRent`, `DeedThief`, `Backstab`, `Demolition`, `Shield`, `ExtraDie`, `Reverse`, `ForcedTip`, `Discount`, `Shove`, `Fine`, `Bribe`, `Spy`.

**Criterios de aceptación:**
- [ ] Hay 20 cartas: 5 legendarias, 6 raras y 9 comunes.
- [ ] Los pesos siguen la tabla por posición de la arquitectura.
- [ ] No se roba una legendaria si hubo otra hace menos de 3 rondas.
- [ ] Con la mano llena, la carta se descarta (`CardDiscarded`).

- [ ] **Paso 1: Escribir las pruebas**

```luau
it("tiene 5, 6 y 9 cartas por rareza", function() --[[ contar Cards.all ]] end)
it("respeta el límite de legendarias", function()
    local s = Fixtures.game({ players = 4 }); s.lastLegendaryRound = s.round
    for _ = 1, 500 do
        s.players[1].hand = {}
        Deck.draw(s, s.players[1].id)
        expect(Cards.byId[s.players[1].hand[1]].rarity ~= "Legendary").toBeTruthy()
    end
end)
it("favorece a quien va peor", function()
    -- En 5000 robos, la mitad inferior obtiene más legendarias que el líder.
end)
```

- [ ] **Paso 2:** Ejecutar `lune run tests/run Deck`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar los datos y `Deck`.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir mazo con rarezas`.

### Task 2: Cartas comunes

**Módulos:** `rules/Cards`.

**Archivos:**
- Crear: `src/shared/rules/Cards.luau`, `tests/rules/CardsCommon.spec.luau`

**Interfaces:**
- Produce: `Cards.play(state, playerId, cardId, args: { targetId: PlayerId?, zoneId: string?, index: number?, pactId: string? }): ApplyResult`.
- Eventos: `CardPlayed { playerId, cardId, targetId? }`, más los eventos que cause.

**Criterios de aceptación:**
- [ ] Una prueba por carta, con el efecto de la ficha: Dado Extra, Marcha Atrás, Propina Forzada (50 por rival), Descuento (la mitad), Empujón (3 casillas), Multa (100 al banco), Soborno y Espía.
- [ ] Empujón no resuelve la casilla de destino, para no alargar el turno.
- [ ] Jugar una carta la quita de la mano.
- [ ] No se puede jugar una carta que no se tiene.

- [ ] **Paso 1:** Escribir una prueba por carta con estado inicial y final exactos.
- [ ] **Paso 2:** Ejecutar `lune run tests/run CardsCommon`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar los efectos y `PlayCard` en `Engine`.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir cartas comunes`.

### Task 3: Cartas raras

**Módulos:** `rules/Cards`, `rules/Property`.

**Archivos:**
- Modificar: `src/shared/rules/Cards.luau`, `src/shared/rules/Property.luau`
- Crear: `tests/rules/CardsRare.spec.luau`

**Interfaces:**
- Produce: `Modifier = { kind: "Inflation" | "Blackout" | "Haunt" | "Discount", zoneId: string?, index: number?, playerId: PlayerId?, untilRound: number }`.

**Criterios de aceptación:**
- [ ] Inflación: renta × 2 durante 2 rondas.
- [ ] Apagón: una zona no cobra durante 2 rondas.
- [ ] Ladrón de Escrituras: solo sin edificios y si no completa un grupo.
- [ ] Puñalada: rompe un pacto propio sin coste, se queda la garantía y deja marca de Traidor.
- [ ] Demolición: baja un nivel un edificio rival.
- [ ] Renta Rebotada se implementa en la Tarea 5.

- [ ] **Paso 1:** Escribir una prueba por carta y una por cada restricción.
- [ ] **Paso 2:** Ejecutar `lune run tests/run CardsRare`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar los efectos y los modificadores en `Property.rentMultiplier`.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir cartas raras`.

### Task 4: Cartas legendarias

**Módulos:** `rules/Cards`.

**Archivos:**
- Modificar: `src/shared/rules/Cards.luau`
- Crear: `tests/rules/CardsLegendary.spec.luau`

**Interfaces:**
- Consume: `Bankruptcy.charge`, `Building.lower`, `Score.ranking`.

**Criterios de aceptación:**
- [ ] Huracán: todas las propiedades vuelven al banco y sus dueños cobran la mitad del valor de propiedad y edificios. Una vez por partida y nunca en las últimas 2 rondas.
- [ ] Mundo al Revés: cada ficha activa cae en una casilla al azar; ninguna resuelve casilla.
- [ ] Revolución: los 2 más ricos y los 2 más pobres intercambian efectivo; con 2 o 3 jugadores activos, se intercambian el primero y el último.
- [ ] Terremoto: todos los edificios de una zona bajan un nivel.
- [ ] Golpe a la Corona: el líder pierde 25 % de su efectivo, repartido entre los demás activos; el resto de la división queda con el líder.
- [ ] Ninguna legendaria deja efectivo negativo ni causa el final de la partida.
- [ ] Una carta no puede apuntar a un espectro ni a quien se fue.

- [ ] **Paso 1: Escribir las pruebas**

```luau
it("Huracán devuelve todo y compensa la mitad", function()
    local s = Fixtures.game({ players = 4 }); local a = s.players[1]
    local idx = Fixtures.squareOf(s, "Property"); Fixtures.give(s, a.id, idx)
    local price = s.board.squares[idx].price; local cash = a.cash
    Fixtures.hand(s, a.id, "Hurricane"); Fixtures.turnOf(s, a.id)
    Engine.apply(s, a.id, { type = "PlayCard", cardId = "Hurricane" })
    expect(s.properties[idx].ownerId).toBe(nil)
    expect(a.cash).toBe(cash + price / 2)
end)
it("Huracán no se puede jugar en las últimas 2 rondas", function()
    -- s.round = s.maxRounds - 1: PlayCard devuelve ok = false.
end)
it("Huracán solo una vez por partida", function()
    -- Segundo uso: ok = false.
end)
```

- [ ] **Paso 2:** Ejecutar `lune run tests/run CardsLegendary`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar las 5 cartas.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir cartas legendarias`.

### Task 5: Reacciones

**Módulos:** `rules/Reaction`.

**Archivos:**
- Crear: `src/shared/rules/Reaction.luau`, `tests/rules/Reaction.spec.luau`

**Interfaces:**
- Produce: `Reaction.open(state, trigger: ReactionTrigger, then: PendingAction): { Event }`, `Reaction.respond(state, playerId, action): ApplyResult`.
- Evento: `CardBlocked { cardId, byPlayerId }`.

**Criterios de aceptación:**
- [ ] Una carta dirigida abre una ventana de 5 s solo si el objetivo tiene Escudo.
- [ ] Una renta abre ventana solo si el pagador tiene Renta Rebotada.
- [ ] Sin carta de reacción no hay espera.
- [ ] Una reacción no abre otra ventana.
- [ ] Al agotarse los 5 s, la acción original continúa.

- [ ] **Paso 1:** Escribir pruebas para: Escudo bloquea, tiempo agotado continúa, sin Escudo no hay fase `Reaction`, Renta Rebotada desvía a un tercero y no hay cadena.
- [ ] **Paso 2:** Ejecutar `lune run tests/run Reaction`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar la fase `Reaction`.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir ventanas de reacción`.

### Task 6: Perks

**Módulos:** `config/Perks`, `rules/Perks`.

**Archivos:**
- Crear: `src/shared/config/Perks.luau`, `src/shared/rules/Perks.luau`, `tests/rules/Perks.spec.luau`

**Interfaces:**
- Produce: `Perks.offer(state, playerId): { string }`, `Perks.draft(state, playerId, perkId): ApplyResult`, `Perks.has(player, perkId): boolean`.
- Ids: `Banker`, `Landlord`, `Builder`, `Smuggler`, `QuickFingers`, `Lawyer`, `Negotiator`, `Lucky`, `Hunter`, `Armored`, `Collector`, `RestlessSoul`.

**Criterios de aceptación:**
- [ ] Se ofrecen 3 perks distintos, sin repetir los que el jugador tiene.
- [ ] La selección ocurre al empezar y en las rondas de la tabla de la arquitectura.
- [ ] Sin elección al agotarse el tiempo, se asigna el primero ofrecido.
- [ ] Una prueba por cada perk con el efecto de la ficha.

- [ ] **Paso 1:** Escribir una prueba por perk y otras para el momento de la selección en los tres tamaños.
- [ ] **Paso 2:** Ejecutar `lune run tests/run Perks`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar la fase `PerkDraft` y los efectos en los módulos afectados.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir perks`.

### Task 7: Casillas nuevas

**Módulos:** `config/Squares`, `rules/Squares`.

**Archivos:**
- Crear: `src/shared/config/Squares.luau`, `src/shared/rules/Squares.luau`, `tests/rules/Squares.spec.luau`

**Interfaces:**
- Produce: `Squares.resolve(state, playerId, index): { Event }`.
- Eventos: `CardDrawn`, `MarketBought`, `DuelResolved { winnerId, loserId, round }`, `PortalUsed { from, to, toll }`, `BillboardResult { playerId, result, amount }`, `PlayerArrested { playerId }`, `TribunalVerdict { playerId, verdict, targetId?, votes }`.

**Criterios de aceptación:**
- [ ] Giro roba una carta.
- [ ] Mercado Negro ofrece 3 cartas visibles, con precios de 100 a 300 según rareza; se puede pasar.
- [ ] Duelo: el activo elige rival; ambos eligen en secreto; el empate repite hasta 3 veces y luego nadie gana. Quien gana cobra 150 del banco y quien pierde retrocede 2 casillas sin resolver destino. No hay apuesta.
- [ ] Portal: paga 50 y salta al siguiente Portal; sin dinero, no salta.
- [ ] Cartelera: resultado según la tabla de la arquitectura; `Lucky` mejora los premios. No pide ninguna decisión ni apuesta.
- [ ] Tribunal: arresto, 10 s de voto entre multa de 150, perder 1 turno o pagar 100 a quien elijan.
- [ ] El acusado no vota. Sin votos, multa. En empate decide el orden fijo de la lista, y el perk Abogado elige por el jugador. Soborno cancela el castigo.
- [ ] Una multa o peaje sin dinero suficiente pasa por `Bankruptcy.charge`.

- [ ] **Paso 1: Escribir las pruebas**

```luau
it("la Cartelera nunca pide decisión", function()
    local s = Fixtures.game({ players = 4 }); local id = s.players[s.turnIndex].id
    Fixtures.placeOn(s, id, Fixtures.squareOf(s, "Billboard") - 2); Fixtures.dice(s, 1, 1)
    Engine.apply(s, id, { type = "Roll" })
    expect(s.phase).toBe("AwaitEnd")
end)
it("el Duelo no cobra nada al perdedor", function()
    -- Efectivo del perdedor sin cambios; retrocede 2; ganador +150.
end)
it("el Tribunal con un solo votante resuelve", function()
    -- 2 jugadores: el único votante decide; sin voto, multa de 150.
end)
```

- [ ] **Paso 2:** Ejecutar `lune run tests/run Squares`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar las 6 casillas y el Impuesto de 100.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir casillas nuevas`.

### Task 8: Zona Caliente y pactos

**Módulos:** `rules/HotZone`, `rules/Pact`.

**Archivos:**
- Crear: `src/shared/rules/HotZone.luau`, `src/shared/rules/Pact.luau`, `tests/rules/Pact.spec.luau`, `tests/rules/HotZone.spec.luau`

**Interfaces:**
- Produce: `HotZone.move(state): { Event }`, `Pact.propose(state, fromId, toId, rounds: number): ApplyResult`, `Pact.respond(state, playerId, pactId, accept: boolean): ApplyResult`, `Pact.breakPact(state, playerId, pactId): ApplyResult`, `Pact.exemptsRent(state, payerId, ownerId): boolean`.
- Produce: `Pact = { id: string, a: PlayerId, b: PlayerId, depositA: number, depositB: number, untilRound: number }`.

**Criterios de aceptación:**
- [ ] La Zona Caliente cambia al empezar las rondas 1, 4, 7 y así sucesivamente; nunca repite la anterior.
- [ ] Sus rentas se duplican, respetando el máximo de × 4.
- [ ] Un pacto exime de renta a ambos socios durante sus rondas y dura de 1 a 5.
- [ ] Al terminar, cada uno recupera su garantía.
- [ ] Al romperlo, el traidor pierde su garantía, que pasa al socio, y lleva la marca 3 rondas.
- [ ] Si un socio se arruina, el pacto termina y el otro recupera la suya.
- [ ] Se exige efectivo para la garantía al aceptar.

- [ ] **Paso 1:** Escribir pruebas para cada criterio.
- [ ] **Paso 2:** Ejecutar `lune run tests/run Pact` y `lune run tests/run HotZone`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar ambos módulos.
- [ ] **Paso 4:** Ejecutar los comandos. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir Zona Caliente y pactos`.

### Task 9: Remontada

**Módulos:** `rules/Comeback`.

**Archivos:**
- Crear: `src/shared/rules/Comeback.luau`, `tests/rules/Comeback.spec.luau`

**Interfaces:**
- Produce: `Comeback.onRentPaid(state, payerId): { Event }`, `Comeback.ghostAct(state, playerId, action: { kind: "Sabotage" } | { kind: "Haunt", index: number }): ApplyResult`.
- Eventos: `FuryFilled { playerId }`, `GhostActed`, `GhostResurrected { playerId, cash }`.

**Criterios de aceptación:**
- [ ] Furia sube 1 por renta pagada si no se es líder; con 5, roba una carta rara o mejor y vuelve a 0.
- [ ] Cada ronda, un espectro tiene un turno propio y corto: roba una carta de sabotaje o embruja una propiedad para que no cobre durante 1 ronda.
- [ ] Las cartas de sabotaje son las comunes `Fine` y `Shove`, más la rara `Demolition`, y solo un espectro las recibe por esta vía.
- [ ] Con 3 sabotajes jugados, resucita con 500 en la casilla 1.
- [ ] Alma en Pena: el espectro empieza con 2 cartas de sabotaje.
- [ ] El turno de un espectro también tiene tiempo agotado.

- [ ] **Paso 1:** Escribir pruebas para cada criterio.
- [ ] **Paso 2:** Ejecutar `lune run tests/run Comeback`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar Furia y la fase `GhostTurn`.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir Furia y espectros`.

### Task 10: Premios y simulación completa

**Módulos:** `rules/Awards`, `tests/sim`.

**Archivos:**
- Crear: `src/shared/rules/Awards.luau`, `tests/rules/Awards.spec.luau`
- Modificar: `tests/sim.luau`, `tests/sim.spec.luau`, `src/shared/rules/Bot.luau`

**Interfaces:**
- Produce: `Awards.compute(state): { { id: string, playerId: PlayerId } }`, con `MostTreacherous` (Mayor Traidor), `BestComeback` (Mejor Remontada) y `VictimOfTheNight` (Víctima de la Noche).
- Modifica: `SimResult` añade `cardsPlayed` y `leaderAtHalfWon`.

**Criterios de aceptación:**
- [ ] Los 3 premios se calculan con `state.stats`; sin datos para uno, no se entrega.
- [ ] El bot usa cartas, perks, pactos y casillas.
- [ ] 1000 partidas por número de jugadores terminan, con los invariantes de la subfase 02.
- [ ] Cada carta y cada perk se usa al menos una vez en la simulación.
- [ ] El comando `lune run tests/sim-report` imprime, por tamaño, la tasa de victoria del líder a mitad de partida, los turnos medios y el uso de cada carta.

- [ ] **Paso 1:** Escribir las pruebas de premios y los nuevos invariantes.
- [ ] **Paso 2:** Ejecutar `lune run tests/run Awards` y `lune run tests/run sim`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar `Awards`, ampliar `Bot` y crear el informe.
- [ ] **Paso 4:** Ejecutar `lune run tools/check`. Esperado: código 0.
- [ ] **Paso 5:** Hacer commit: `feat: añadir premios y simular todas las dinámicas`.

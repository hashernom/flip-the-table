# Fase 1: Más partidas. Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Plan vivo:** las cantidades son provisionales. Antes de ejecutarlo, se revisa con los resultados de la Puerta C.

**Goal:** Añadir equipos, contenido, reglas de la casa y una tienda solo de apariencia.

**Architecture:** El motor recibe un `GameMode` y unas `HouseRules` al crear la partida. Los cosméticos viven fuera de `rules`, así no pueden afectar a la partida.

**Tech Stack:** Luau, Lune, compras de Roblox, DataStore, Blender.

**Spec:** [ficha de la fase](ficha.md), [ficha general](../00-ficha/ficha-propuesta.md) y [arquitectura](../01-arquitectura/arquitectura.md).

## Ejecución recomendada

**Modo:** subagentes, con `superpowers:subagent-driven-development`.

**Por qué:** esta fase toca dinero real y el modo de equipos altera reglas básicas del motor. Un cobro mal gestionado o una regresión en la partida publicada costaría caro, y cada tarea se puede revisar por separado.

**Instrucciones para la sesión:**

- Sigue también las [instrucciones generales](../instrucciones-de-sesion.md).
- Requiere la Puerta C aprobada. Antes de empezar, actualiza este plan con sus resultados y acuérdalo con el responsable.
- Trabaja sobre lo publicado sin romperlo: toda partida individual debe seguir pasando sus pruebas y simulaciones.
- Pide al revisor de la Tarea 4 que busque dobles entregas, pérdidas de compras y cualquier ventaja de pago.
- Usa solo el entorno de pruebas para las compras. Los precios reales los aprueba el responsable.
- Termina con `resultados.md` y la decisión del responsable sobre la Fase 2.

## Global Constraints

- Solo se vende apariencia; las cartas y los perks nunca se compran con dinero real.
- Nada de pago es aleatorio.
- Ninguna mecánica pide arriesgar nada de valor en un juego de azar.
- Cada asset cumple el estándar y se aprueba por una persona.
- Antes de hacer push o publicar, los agentes se detienen y preguntan.

## Review Focus

1. Un compañero de equipo se desconecta: el bot usa el dinero compartido sin arruinar al equipo por descuido. Prueba en Tarea 1.
2. Un equipo se arruina con un miembro aún en juego: los dos pasan a espectro a la vez. Prueba en Tarea 1.
3. Un fallo tras cobrar no entrega el cosmético, o lo entrega dos veces: la compra se reanuda sin duplicar. Prueba en Tarea 4.
4. Las reglas de la casa producen una partida imposible: se rechazan antes de empezar. Prueba en Tarea 3.
5. Un jugador intenta usar un cosmético que no tiene: el servidor no lo aplica. Prueba en Tarea 4.

---

### Task 1: Modo de equipos

**Módulos:** `rules/Teams`, `rules/State`, `rules/Score`, `rules/Bankruptcy`.

**Archivos:**
- Crear: `src/shared/rules/Teams.luau`, `tests/rules/Teams.spec.luau`
- Modificar: `State.luau`, `Score.luau`, `Bankruptcy.luau`, `Property.luau`

**Interfaces:**
- Produce: `State.create(opts: { playerIds, seed, mode: GameMode?, teams: { { PlayerId } }? })`.
- Produce: `GameMode = "FreeForAll" | "Teams"`, `Teams.cashOf(state, playerId): number`, `Teams.charge(state, playerId, amount): { Event }`, `Teams.ranking(state): { TeamId }`.

**Criterios de aceptación:**
- [ ] Admite 2 contra 2 y 4 contra 4; rechaza equipos desiguales.
- [ ] Los compañeros comparten dinero y no se pagan renta.
- [ ] Una zona se completa con propiedades de cualquier miembro.
- [ ] Gana el equipo con más patrimonio.
- [ ] Un equipo arruinado pasa a espectro completo.
- [ ] El bot no gasta el dinero compartido por debajo de 300.

- [ ] **Paso 1: Escribir las pruebas**

```luau
it("comparte el dinero", function()
    local s = Fixtures.game({ players = 4, mode = "Teams" })
    local a, b = s.teams[1][1], s.teams[1][2]
    expect(Teams.cashOf(s, a)).toBe(Teams.cashOf(s, b))
end)
it("no cobra renta entre compañeros", function()
    -- A posee la casilla; B cae en ella; dinero del equipo sin cambios.
end)
it("rechaza equipos desiguales", function()
    expect(function() Fixtures.game({ players = 5, mode = "Teams" }) end).toThrow()
end)
```

- [ ] **Paso 2:** Ejecutar `lune run tests/run Teams`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar y ampliar `tests/sim` con 1000 partidas por equipos.
- [ ] **Paso 4:** Ejecutar `lune run tools/check`. Esperado: código 0.
- [ ] **Paso 5:** Hacer commit: `feat: añadir modo de equipos`.

### Task 2: Cartas de equipo y contenido nuevo

**Módulos:** `config/Cards`, `config/Perks`, `config/Squares`, `rules/Cards`, `client/scenes/*`.

**Archivos:**
- Modificar: esos módulos
- Crear: `docs/03-fase-1-mas-partidas/contenido.md`, una escena por contenido nuevo

**Interfaces:**
- Modifica: `CardDef` añade `mode: GameMode?`.

**Criterios de aceptación:**
- [ ] `contenido.md` define, antes de programar, cada carta, perk y casilla, y el responsable la aprueba.
- [ ] 10 cartas nuevas, 3 de equipo, 4 perks y 2 casillas; las cantidades pueden cambiar con los datos.
- [ ] Toda carta nueva tiene prueba de efecto, escena y texto.
- [ ] Las cartas de equipo no aparecen en partidas individuales.
- [ ] Ningún contenido nuevo incluye apuestas.

- [ ] **Paso 1:** Escribir `contenido.md` a partir de lo que pidieron los jugadores y obtener la aprobación.
- [ ] **Paso 2:** Escribir las pruebas de efecto.
- [ ] **Paso 3:** Ejecutar `lune run tests/run Cards`. Esperado: FAIL.
- [ ] **Paso 4:** Implementar los efectos, las escenas y los textos.
- [ ] **Paso 5:** Ejecutar `lune run tools/check`. Esperado: código 0.
- [ ] **Paso 6:** Hacer commit: `feat: añadir contenido nuevo`.

### Task 3: Reglas de la casa

**Módulos:** `rules/HouseRules`, `client/ui/HouseRulesMenu`.

**Archivos:**
- Crear: `src/shared/rules/HouseRules.luau`, `src/client/ui/HouseRulesMenu.luau`, `tests/rules/HouseRules.spec.luau`

**Interfaces:**
- Produce: `HouseRules = { rounds: number?, disabledCards: { string }, chaos: "Low" | "Normal" | "High" }`.
- Produce: `HouseRules.validate(rules): (boolean, string?)`, `HouseRules.apply(state, rules)`.

**Criterios de aceptación:**
- [ ] El anfitrión elige rondas, cartas activas y nivel de caos antes de empezar.
- [ ] Hay 3 ajustes preparados: Rápida, Clásica y Caos.
- [ ] Se rechaza un mazo sin cartas comunes suficientes o unas rondas fuera de 6 a 30.
- [ ] Las partidas con reglas de la casa se separan en la telemetría.

- [ ] **Paso 1:** Escribir pruebas de validación y efecto.
- [ ] **Paso 2:** Ejecutar `lune run tests/run HouseRules`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar el módulo y el menú.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir reglas de la casa`.

### Task 4: Inventario y tienda

**Módulos:** `config/Catalog`, `server/store/PurchaseService`, `server/store/Inventory`, `client/ui/Store`.

**Archivos:**
- Crear: `src/shared/config/Catalog.luau`, `src/server/store/PurchaseLedger.luau`, `src/server/store/PurchaseService.luau`, `src/server/store/Inventory.luau`, `src/client/ui/Store.luau`, `tests/server/PurchaseLedger.spec.luau`, `tests/rules/NoPayToWin.spec.luau`

**Interfaces:**
- Produce: `PurchaseLedger.process(ledger, receiptId: string, itemId: string): "Granted" | "AlreadyGranted"`.
- Produce: `Inventory.owns(userId, itemId): boolean`, `Inventory.equip(player, slot, itemId): (boolean, string?)`.

**Criterios de aceptación:**
- [ ] Antes de programar, se confirman en la documentación oficial las compras, recibos, límites de edad y persistencia de datos.
- [ ] Una compra repetida o reanudada no se entrega dos veces.
- [ ] El servidor comprueba la propiedad antes de aplicar un cosmético.
- [ ] Una prueba comprueba que `src/shared/rules` no importa `Catalog`.
- [ ] El catálogo no tiene objetos aleatorios.
- [ ] El responsable aprueba los precios antes de publicar.

- [ ] **Paso 1:** Escribir pruebas de `PurchaseLedger` y `NoPayToWin`.
- [ ] **Paso 2:** Ejecutar `lune run tests/run PurchaseLedger` y `lune run tests/run NoPayToWin`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar los módulos.
- [ ] **Paso 4:** Ejecutar los comandos. Esperado: PASS.
- [ ] **Paso 5:** Probar una compra en el entorno de pruebas de Studio; cortar la conexión tras comprar y comprobar la entrega.
- [ ] **Paso 6:** Hacer commit: `feat: añadir tienda de cosméticos`.

### Task 5: Primer catálogo

**Módulos:** `art/cosmetics`, `client/world/CosmeticApplier`.

**Archivos:**
- Crear: `art/blender/cosmetics/*`, `src/client/world/CosmeticApplier.luau`
- Modificar: `src/shared/config/Catalog.luau`, `art/manifest.json`

**Interfaces:**
- Produce: `CosmeticApplier.apply(playerId, equipped: { [string]: string })`.

**Criterios de aceptación:**
- [ ] 8 fichas especiales; al menos 2 estelas, 2 escenas de victoria, 2 animaciones, 4 emotes y 1 estilo de edificio.
- [ ] Los cosméticos se ven a la vez para todo el grupo.
- [ ] Un estilo de edificio no impide reconocer la zona ni al dueño.
- [ ] Cumplen el estándar y el presupuesto de rendimiento.

- [ ] **Paso 1:** Producir y registrar los assets.
- [ ] **Paso 2:** Ejecutar `lune run tools/manifest`. Esperado: sin problemas.
- [ ] **Paso 3:** Obtener la aprobación del responsable.
- [ ] **Paso 4:** Hacer commit: `feat: añadir primer catálogo`.

### Task 6: Validación de la fase

**Módulos:** `tools/criteria-report`, `server/match/Telemetry`.

**Archivos:**
- Crear: `docs/03-fase-1-mas-partidas/resultados.md`

**Criterios de aceptación:**
- [ ] Cada criterio de la [ficha](ficha.md) está medido.
- [ ] El responsable decide por escrito si se abre la Fase 2.
- [ ] Se revisa el plan de la Fase 2 con estos resultados.

- [ ] **Paso 1:** Probar con amigos el modo de equipos y las reglas de la casa.
- [ ] **Paso 2:** Publicar solo con la aprobación del responsable.
- [ ] **Paso 3:** Medir durante 4 semanas y escribir `resultados.md`.
- [ ] **Paso 4:** Hacer commit: `docs: registrar resultados de la Fase 1`.

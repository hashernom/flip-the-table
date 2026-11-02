# Fase 4: Comunidad. Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Plan vivo:** antes de ejecutarlo, se revisa con los resultados de la Fase 3.

**Goal:** Añadir temporadas, eventos, torneos entre grupos y clips para compartir.

**Architecture:** Un calendario de datos activa temporadas y eventos. Los torneos reutilizan partidas privadas y resúmenes. Los mejores momentos se eligen a partir de los eventos del motor y se reviven con el mismo sistema de escenas.

**Tech Stack:** Luau, Lune, MemoryStoreService, DataStoreService, APIs de captura de Roblox.

**Spec:** [ficha de la fase](ficha.md), [ficha general](../00-ficha/ficha-propuesta.md) y [arquitectura](../01-arquitectura/arquitectura.md).

## Ejecución recomendada

**Modo:** subagentes, con `superpowers:subagent-driven-development`.

**Por qué:** calendario, eventos, torneos y clips apenas dependen entre sí, así que cada uno cabe en un subagente con instrucciones claras. Una revisión independiente ayuda sobre todo a la recuperación de torneos y a la privacidad de los clips.

**Instrucciones para la sesión:**

- Sigue también las [instrucciones generales](../instrucciones-de-sesion.md).
- Requiere la Fase 3 validada. Antes de empezar, actualiza este plan con sus resultados y acuérdalo con el responsable.
- Consulta las normas vigentes antes de los torneos y los clips; pueden haber cambiado.
- Pide al revisor que busque información oculta o datos personales en cualquier clip.
- Sin premios con valor real: una propuesta así se detiene y se consulta.
- Esta fase es continua: termina con `operacion.md` y `resultados.md`, y el responsable decide cada temporada.

## Global Constraints

- Sin premios con valor real.
- Ningún evento pide arriesgar nada de valor en un juego de azar.
- Compartir siempre es una decisión del jugador.
- Los clips respetan la información oculta.
- Cada asset cumple el estándar y se aprueba por una persona.
- Antes de hacer push o publicar, los agentes se detienen y preguntan.

## Review Focus

1. Un evento termina durante una partida: la partida acaba con sus reglas iniciales. Prueba en Tarea 1.
2. Un grupo no se presenta a una ronda: pierde sin bloquear el torneo. Prueba en Tarea 3.
3. El servidor del torneo cae entre rondas: los resultados se recuperan. Prueba en Tarea 3.
4. Un número impar de grupos: alguien pasa de ronda sin jugar, sin error. Prueba en Tarea 3.
5. Un clip revela la mano de otro jugador: la selección lo filtra. Prueba en Tarea 4.

---

### Task 1: Calendario en vivo

**Módulos:** `config/LiveCalendar`, `shared/live/Schedule`.

**Archivos:**
- Crear: `src/shared/config/LiveCalendar.luau`, `src/shared/live/Schedule.luau`, `tests/live/Schedule.spec.luau`

**Interfaces:**
- Produce: `Schedule.activeAt(calendar, unixTime: number): { season: string?, events: { string } }`.
- Modifica: `State.create(opts: { ..., eventId: string? })`, fijado al empezar la partida.

**Criterios de aceptación:**
- [ ] Antes de programar, se elige cómo actualizar el calendario sin publicar código y se confirma en la documentación vigente.
- [ ] Temporadas y eventos cambian por fecha.
- [ ] Una partida conserva las reglas con que empezó.
- [ ] Una fecha mal configurada o solapada falla en la comprobación.
- [ ] Sin datos del calendario, el juego funciona con sus reglas normales.

- [ ] **Paso 1:** Escribir pruebas de fechas, solapes y ausencia de datos.
- [ ] **Paso 2:** Ejecutar `lune run tests/run Schedule`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar los módulos.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir calendario en vivo`.

### Task 2: Primer evento

**Módulos:** `rules/EventRules`, `config/events/*`, `client/scenes/events/*`.

**Archivos:**
- Crear: `src/shared/rules/EventRules.luau`, `src/shared/config/events/FirstEvent.luau`, `src/client/scenes/events/`, `tests/rules/EventRules.spec.luau`, `docs/06-fase-4-comunidad/primer-evento.md`

**Interfaces:**
- Produce: `EventRules.hooksFor(eventId: string): MapHooks?`, con los mismos ganchos de `MapRules`.

**Criterios de aceptación:**
- [ ] `primer-evento.md` describe el evento, y el responsable lo aprueba antes de producirlo.
- [ ] El evento se activa solo por calendario.
- [ ] Tiene escena propia y se simula en 1000 partidas por tamaño.
- [ ] Un evento se puede repetir sin cambios de código.
- [ ] Las recompensas son cosméticas.

- [ ] **Paso 1:** Escribir `primer-evento.md` y obtener la aprobación.
- [ ] **Paso 2:** Escribir las pruebas de reglas.
- [ ] **Paso 3:** Ejecutar `lune run tests/run EventRules`. Esperado: FAIL.
- [ ] **Paso 4:** Implementar y producir las escenas.
- [ ] **Paso 5:** Ejecutar `lune run tools/check`. Esperado: código 0.
- [ ] **Paso 6:** Hacer commit: `feat: añadir primer evento`.

### Task 3: Torneos entre grupos

**Módulos:** `server/tournament/Bracket`, `server/tournament/TournamentService`, `client/ui/TournamentMenu`.

**Archivos:**
- Crear: `src/server/tournament/Bracket.luau`, `src/server/tournament/TournamentService.luau`, `src/client/ui/TournamentMenu.luau`, `tests/server/Bracket.spec.luau`

**Interfaces:**
- Produce: `Bracket.create(groupIds: { string }, seed: number): BracketState`, `Bracket.report(state, matchId, points: { [string]: number }): BracketState`, `Bracket.forfeit(state, groupId): BracketState`, `Bracket.nextMatches(state): { Match }`.

**Criterios de aceptación:**
- [ ] De 4 a 16 grupos; con número impar, uno pasa de ronda.
- [ ] Cada ronda suma puntos en varias partidas, para reducir el peso del azar.
- [ ] Un grupo ausente pierde tras 5 minutos.
- [ ] El estado se guarda después de cada resultado y se recupera tras una caída.
- [ ] Sin premios con valor real.
- [ ] Un torneo de 8 grupos termina sin intervención manual.

- [ ] **Paso 1: Escribir las pruebas**

```luau
it("gestiona un número impar de grupos", function()
    local b = Bracket.create({ "a", "b", "c", "d", "e" }, 1)
    expect(#Bracket.nextMatches(b) > 0).toBeTruthy()
end)
it("termina al jugar todas las rondas", function()
    -- Simular 8 grupos con resultados fijos hasta que no queden partidas.
end)
it("un grupo ausente no bloquea el torneo", function()
    -- Bracket.forfeit permite continuar y mantiene las partidas ya jugadas.
end)
```

- [ ] **Paso 2:** Ejecutar `lune run tests/run Bracket`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar los módulos.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Probar un torneo de 4 grupos con amigos, con ayuda del responsable.
- [ ] **Paso 6:** Hacer commit: `feat: añadir torneos entre grupos`.

### Task 4: Clips para compartir

**Módulos:** `rules/Highlights`, `client/ui/Highlights`.

**Archivos:**
- Crear: `src/shared/rules/Highlights.luau`, `src/client/ui/Highlights.luau`, `tests/rules/Highlights.spec.luau`

**Interfaces:**
- Produce: `Highlights.select(events: { Event }, max: number): { Highlight }`, `Highlight = { kind: string, round: number, events: { Event }, score: number }`.

**Criterios de aceptación:**
- [ ] Antes de programar, se confirman en la documentación oficial las APIs de captura, sus límites y sus requisitos de permiso.
- [ ] Al final, se seleccionan hasta 3 momentos: legendarias, traiciones, arrestos o remontadas.
- [ ] Se reviven con el mismo sistema de escenas, sin vídeo pregrabado.
- [ ] Los momentos se filtran con `View`, sin revelar información oculta.
- [ ] Solo se comparte por decisión del jugador.
- [ ] Revivirlos es opcional y no retrasa la revancha.

- [ ] **Paso 1:** Escribir pruebas: una legendaria puntúa más que una renta, no se devuelven más de `max`, y no se incluye la mano de otro jugador.
- [ ] **Paso 2:** Ejecutar `lune run tests/run Highlights`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar los módulos.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir mejores momentos`.

### Task 5: Operación de temporadas

**Módulos:** `tools/season-report`, `docs/06-fase-4-comunidad/operacion`.

**Archivos:**
- Crear: `tools/season-report.luau`, `tests/tools/season-report.spec.luau`, `docs/06-fase-4-comunidad/operacion.md`, `docs/06-fase-4-comunidad/resultados.md`

**Interfaces:**
- Produce: `SeasonReport.compute(summaries, window): Report`.

**Criterios de aceptación:**
- [ ] `operacion.md` explica cómo preparar una temporada, un evento y un torneo.
- [ ] El informe calcula los criterios de la [ficha](ficha.md).
- [ ] Cada temporada revisa las normas vigentes de Roblox.
- [ ] El responsable aprueba el plan de cada temporada.

- [ ] **Paso 1:** Escribir pruebas del informe con datos de ejemplo.
- [ ] **Paso 2:** Ejecutar `lune run tests/run season-report`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar el informe y escribir `operacion.md`.
- [ ] **Paso 4:** Ejecutar `lune run tools/check`. Esperado: código 0.
- [ ] **Paso 5:** Publicar solo con la aprobación del responsable, medir y escribir `resultados.md`.
- [ ] **Paso 6:** Hacer commit: `feat: añadir operación de temporadas`.

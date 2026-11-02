# Fase 3: Progresión. Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Plan vivo:** antes de ejecutarlo, se revisa con los resultados de la Fase 2.

**Goal:** Añadir niveles, misiones, colecciones y un pase de temporada solo cosmético.

**Architecture:** La progresión lee los eventos del motor al terminar la partida y nunca los modifica. La lógica es pura y se prueba con Lune; `ProfileStore` se encarga de guardar.

**Tech Stack:** Luau, Lune, DataStoreService, compras de Roblox.

**Spec:** [ficha de la fase](ficha.md), [ficha general](../00-ficha/ficha-propuesta.md) y [arquitectura](../01-arquitectura/arquitectura.md).

## Ejecución recomendada

**Modo:** subagentes, con `superpowers:subagent-driven-development`.

**Por qué:** un error de guardado puede borrar el progreso de jugadores reales, y a veces no se puede deshacer. Una revisión independiente de cada tarea compensa su coste, sobre todo en perfiles, recompensas y compras del pase.

**Instrucciones para la sesión:**

- Sigue también las [instrucciones generales](../instrucciones-de-sesion.md).
- Requiere la Fase 2 validada. Antes de empezar, actualiza este plan con sus resultados y acuérdalo con el responsable.
- Prueba siempre con un almacén de datos separado; nunca con los datos reales.
- Antes de migrar perfiles en producción, detente y pide permiso con un plan para revertir.
- El revisor comprueba que `src/shared/rules` siga sin importar `progression`.
- Termina con `resultados.md`, tras una temporada completa, y la decisión del responsable sobre la Fase 4.

## Global Constraints

- El nivel nunca da ventaja: `src/shared/rules` no importa nada de `progression`.
- Las recompensas son cosméticas.
- Nada de pago es aleatorio.
- Antes de cambiar datos de jugadores en producción, los agentes se detienen y preguntan.

## Review Focus

1. Dos servidores escriben el mismo perfil: no se pierde progreso. Prueba en Tarea 1.
2. Un jugador se va antes del final: recibe lo que le corresponde o nada, sin duplicar. Prueba en Tarea 2.
3. Una misión diaria cruza la medianoche durante una partida: se cuenta una sola vez. Prueba en Tarea 2.
4. Un jugador compra el pase a mitad de temporada: recibe las recompensas de su nivel. Prueba en Tarea 4.
5. Un perfil antiguo con otro formato se migra sin perder datos. Prueba en Tarea 1.

---

### Task 1: Perfil persistente

**Módulos:** `server/profile/ProfileStore`, `server/profile/ProfileSchema`.

**Archivos:**
- Crear: `src/server/profile/ProfileSchema.luau`, `src/server/profile/ProfileStore.luau`, `tests/server/ProfileSchema.spec.luau`
- Modificar: `src/server/lobby/PlayerProfile.luau`, `src/server/store/Inventory.luau`

**Interfaces:**
- Produce: `Profile = { version: number, xp: number, completedMatches: number, missions: {}, collections: {}, season: {}, inventory: {} }`.
- Produce: `ProfileSchema.migrate(raw: any): Profile`, `ProfileSchema.merge(saved: Profile, delta: ProfileDelta): Profile`.
- Produce: `ProfileStore.load(player): Profile`, `ProfileStore.apply(player, delta: ProfileDelta)`, `ProfileStore.release(player)`.

**Criterios de aceptación:**
- [ ] Antes de programar, se confirman en la documentación oficial los límites de DataStore y se elige si usar una biblioteca probada de sesiones.
- [ ] Una sesión bloquea el perfil para evitar sobrescribir progreso desde otro servidor.
- [ ] Guarda con reintentos, al salir y al cerrar el servidor.
- [ ] Perfiles antiguos se migran sin pérdida.
- [ ] Si no se puede cargar, el jugador puede jugar, pero se le avisa y no se sobrescriben sus datos.
- [ ] El perfil no guarda más datos personales que los necesarios.

- [ ] **Paso 1:** Escribir pruebas de migración, combinación y datos no válidos.
- [ ] **Paso 2:** Ejecutar `lune run tests/run ProfileSchema`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar los módulos.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** En un lugar de prueba, cerrar el servidor durante un guardado y comprobar los datos al volver.
- [ ] **Paso 6:** Hacer commit: `feat: añadir perfil persistente`.

### Task 2: Niveles y misiones

**Módulos:** `shared/progression/Levels`, `shared/progression/Missions`, `client/ui/Progress`, `client/scenes/game/PostMatchRewards`.

**Archivos:**
- Crear: `src/shared/progression/Levels.luau`, `src/shared/progression/Missions.luau`, `src/shared/config/MissionList.luau`, `src/client/ui/Progress.luau`, `src/client/scenes/game/PostMatchRewards.luau`, `tests/progression/Missions.spec.luau`, `tests/rules/NoProgressionInRules.spec.luau`

**Interfaces:**
- Produce: `Levels.levelFor(xp: number): number`, `Levels.xpFromMatch(summary: Summary, stayedUntilEnd: boolean): number`.
- Produce: `Missions.advance(progress, events: { Event }, playerId, partySize: number, today: string): ProgressDelta`.

**Criterios de aceptación:**
- [ ] Terminar una partida da más experiencia que abandonarla; abandonar no da nada.
- [ ] Las misiones se calculan con los eventos de la partida.
- [ ] Hay misiones individuales y de grupo; estas últimas exigen jugar con al menos 2 amigos.
- [ ] Ninguna misión premia perjudicar a compañeros de equipo o abandonar.
- [ ] La fecha de cada misión se fija al empezar la partida.
- [ ] Una prueba comprueba que `src/shared/rules` no importa `progression`.
- [ ] Las recompensas aparecen tras el podio y no retrasan la revancha.

- [ ] **Paso 1:** Escribir las pruebas de cada criterio.
- [ ] **Paso 2:** Ejecutar `lune run tests/run Missions`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar los módulos y las pantallas.
- [ ] **Paso 4:** Ejecutar `lune run tools/check`. Esperado: código 0.
- [ ] **Paso 5:** Hacer commit: `feat: añadir niveles y misiones`.

### Task 3: Colecciones

**Módulos:** `shared/progression/Collections`, `config/CollectionList`, `art/cosmetics`.

**Archivos:**
- Crear: `src/shared/progression/Collections.luau`, `src/shared/config/CollectionList.luau`, `tests/progression/Collections.spec.luau`
- Modificar: `art/manifest.json`, `src/shared/config/Catalog.luau`

**Interfaces:**
- Produce: `Collections.progress(inventory, collectionId): { owned: number, total: number }`, `Collections.rewardFor(inventory, collectionId): string?`.

**Criterios de aceptación:**
- [ ] Una colección por mapa, con recompensa cosmética final.
- [ ] Se puede completar jugando; comprar nunca es la única vía.
- [ ] Las recompensas no son aleatorias de pago.
- [ ] Los assets cumplen el estándar y están aprobados.

- [ ] **Paso 1:** Escribir las pruebas de progreso y recompensa.
- [ ] **Paso 2:** Ejecutar `lune run tests/run Collections`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar y producir los assets.
- [ ] **Paso 4:** Ejecutar `lune run tools/check`. Esperado: código 0.
- [ ] **Paso 5:** Hacer commit: `feat: añadir colecciones`.

### Task 4: Pase de temporada

**Módulos:** `shared/progression/SeasonPass`, `config/SeasonData`, `client/ui/SeasonPassMenu`.

**Archivos:**
- Crear: `src/shared/progression/SeasonPass.luau`, `src/shared/config/SeasonData.luau`, `src/client/ui/SeasonPassMenu.luau`, `tests/progression/SeasonPass.spec.luau`

**Interfaces:**
- Produce: `SeasonPass.tierFor(points: number): number`, `SeasonPass.claimable(state, premium: boolean): { string }`, `SeasonPass.claim(state, rewardId): (boolean, string?)`.

**Criterios de aceptación:**
- [ ] Antes de programar, se confirman las normas vigentes sobre compras y menores.
- [ ] Hay camino gratuito y camino de pago, ambos solo con cosméticos.
- [ ] Las misiones de grupo son la fuente principal de puntos.
- [ ] Al comprar a mitad de temporada, se reciben las recompensas de pago ya alcanzadas.
- [ ] Una recompensa no se reclama dos veces.
- [ ] La temporada termina con aviso y sin cuentas regresivas agresivas.
- [ ] El responsable aprueba los precios y el contenido.

- [ ] **Paso 1:** Escribir las pruebas de cada criterio.
- [ ] **Paso 2:** Ejecutar `lune run tests/run SeasonPass`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar y producir los cosméticos.
- [ ] **Paso 4:** Ejecutar `lune run tools/check`. Esperado: código 0.
- [ ] **Paso 5:** Hacer commit: `feat: añadir pase de temporada`.

### Task 5: Validación de la fase

**Módulos:** `tools/criteria-report`.

**Archivos:**
- Crear: `docs/05-fase-3-progresion/resultados.md`

**Criterios de aceptación:**
- [ ] Cada criterio de la [ficha](ficha.md) está medido.
- [ ] Se comprueba que la tasa de segunda partida no baja.
- [ ] El responsable decide por escrito si se abre la Fase 4.

- [ ] **Paso 1:** Publicar solo con la aprobación del responsable.
- [ ] **Paso 2:** Medir durante una temporada completa y escribir `resultados.md`.
- [ ] **Paso 3:** Hacer commit: `docs: registrar resultados de la Fase 3`.

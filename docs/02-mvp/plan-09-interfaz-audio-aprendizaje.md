# Subfase 09: Interfaz, audio y aprendizaje. Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (recommended) or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Antes de la Tarea 1, cargar también la skill `impeccable`.

**Goal:** Sustituir la interfaz gris por la final, añadir toda la música y el sonido, y enseñar a jugar durante la primera partida.

**Architecture:** Una biblioteca de componentes con tokens de diseño. Los textos viven en `config/Strings`, con el español como base. El audio se dispara desde las escenas por medio de `AudioDirector`.

**Tech Stack:** Luau, UI de Roblox, MCP de Studio, generación con IA para ilustraciones y audio.

**Spec:** "Identidad", "Estándar de calidad" y "Qué incluye el MVP" en la [ficha](../00-ficha/ficha-propuesta.md).

## Ejecución recomendada

**Modo:** en la sesión, con `superpowers:executing-plans`.

**Por qué:** interfaz, ilustraciones, sonido y guía deben sentirse como una sola voz. Una sesión continua conserva ese criterio y hace fáciles los ajustes con el responsable, y las pruebas puras protegen la poca lógica que hay.

**Instrucciones para la sesión:**

- Sigue también las [instrucciones generales](../instrucciones-de-sesion.md).
- Requiere los planes 05 y 07 terminados, con Studio abierto. Carga la skill `impeccable` antes de la Tarea 1.
- Puede avanzar a la par que el plan 08 solo en ramas separadas, sin tocar los mismos archivos ni usar Studio a la vez.
- Prueba siempre con la pantalla más pequeña admitida y el texto más largo.
- Confirma las condiciones de uso comercial antes de generar audio o ilustraciones.
- Pide un revisor nuevo para toda la rama antes de cerrar.
- Termina cuando se puede jugar toda la partida en móvil con la interfaz final, y el responsable la aprueba.

## Global Constraints

- PC y móvil, con interfaz propia para pantalla táctil.
- El estándar de calidad aplica a interfaz, iconos, ilustraciones de cartas, partículas, sonido y música.
- Primera partida guiada con explicaciones cortas, sin tutorial aparte.
- La interfaz nunca tapa una escena importante.
- Todo lo social se puede hacer desde menús, sin chat ni voz.

## Review Focus

1. Pantalla pequeña y texto largo: ningún texto se corta. Prueba en Tarea 2.
2. Un dato depende solo del color: también tiene icono o forma. Prueba en Tarea 1.
3. Quien ya jugó entra con un amigo nuevo: solo este último ve la guía. Prueba en Tarea 5.
4. El volumen acumulado de varias escenas no satura. Prueba en Tarea 6.
5. Un jugador en móvil rechaza por error una decisión: las acciones irreversibles se distinguen. Prueba en Tarea 2.

---

### Task 1: Sistema visual

**Módulos:** `client/ui/Theme`, `client/ui/Components`, `config/Strings`.

**Archivos:**
- Crear: `src/client/ui/Theme.luau`, `src/client/ui/Components.luau`, `src/shared/config/Strings.luau`, `tests/config/Strings.spec.luau`

**Interfaces:**
- Produce: `Theme.color`, `Theme.font`, `Theme.space`, `Theme.scaleFor(viewport)`.
- Produce: `Components.Button`, `Panel`, `Card`, `Timer`, `PlayerChip`, `MoneyLabel`.
- Produce: `Strings.get(key: string, args: { [string]: any }?): string`.

**Criterios de aceptación:**
- [ ] Sigue la paleta de la guía de estilo.
- [ ] Texto mínimo legible en móvil; objetivos táctiles de 44 píxeles o más.
- [ ] Los dueños y estados se identifican también por icono o forma, no solo por color.
- [ ] Todo texto visible pasa por `Strings`.
- [ ] El responsable aprueba una pantalla de ejemplo.

- [ ] **Paso 1:** Escribir una prueba: `Strings.get` con una clave desconocida lanza un error; toda carta y perk de `config` tiene nombre y descripción.
- [ ] **Paso 2:** Ejecutar `lune run tests/run Strings`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar tema, componentes y textos.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Obtener la aprobación del responsable con capturas en PC y móvil.
- [ ] **Paso 6:** Hacer commit: `feat: añadir sistema visual`.

### Task 2: Interfaz de partida

**Módulos:** `client/ui/*`.

**Archivos:**
- Modificar: `Hud.luau`, `ActionMenu.luau`, `TradeMenu.luau`, `PactMenu.luau`, `VoteMenu.luau`, `PerkMenu.luau`, `Overview.luau`

**Criterios de aceptación:**
- [ ] Sigue funcionando toda la partida solo con menús.
- [ ] La interfaz se oculta o se reduce durante las escenas.
- [ ] Romper un pacto y otras acciones irreversibles requieren una segunda confirmación.
- [ ] En teclado y ratón tiene atajos para lo más común.
- [ ] Los textos más largos no se cortan en la pantalla más pequeña admitida.

- [ ] **Paso 1:** Sustituir cada menú y ejecutar `lune run tests/run ActionMenuRules`. Esperado: PASS.
- [ ] **Paso 2:** Capturar cada menú con su texto más largo, en móvil y en PC.
- [ ] **Paso 3:** Obtener la aprobación del responsable.
- [ ] **Paso 4:** Hacer commit: `feat: completar interfaz de partida`.

### Task 3: Cartas, perks e iconos

**Módulos:** `art/ui`, `client/ui/Card`.

**Archivos:**
- Crear: `art/ui/cards/` (20 ilustraciones), `art/ui/perks/` (12 iconos), `art/ui/icons/`
- Modificar: `art/manifest.json`

**Criterios de aceptación:**
- [ ] 20 ilustraciones de carta y 12 iconos de perk registrados y aprobados.
- [ ] La rareza se reconoce por marco y borde, con dorado en las legendarias.
- [ ] Se distinguen entre sí en el tamaño de móvil.
- [ ] No se parecen a las cartas del juego original.

- [ ] **Paso 1:** Producir 3 cartas de ejemplo y obtener su aprobación.
- [ ] **Paso 2:** Producir el resto y registrarlo.
- [ ] **Paso 3:** Ejecutar `lune run tools/manifest`. Esperado: sin problemas.
- [ ] **Paso 4:** Hacer commit: `feat: añadir ilustraciones de cartas y perks`.

### Task 4: Lobby

**Módulos:** `client/ui/LobbyMenu`, `client/world/LobbyScene`.

**Archivos:**
- Modificar: `src/client/ui/LobbyMenu.luau`
- Crear: `src/client/world/LobbyScene.luau`

**Criterios de aceptación:**
- [ ] Desde el lobby se crea un código, se entra con uno o se juega en público.
- [ ] Se ve quién está en la party y se elige ficha antes de empezar.
- [ ] Cada error de `PartyService` muestra un mensaje claro.
- [ ] El ambiente del lobby muestra la identidad de la ciudad.

- [ ] **Paso 1:** Implementar y probar los 3 caminos con el MCP de Studio.
- [ ] **Paso 2:** Obtener la aprobación del responsable.
- [ ] **Paso 3:** Hacer commit: `feat: completar lobby`.

### Task 5: Primera partida guiada

**Módulos:** `client/ui/GuidedMatch`, `server/lobby/PlayerProfile`.

**Archivos:**
- Crear: `src/client/ui/GuidedMatchRules.luau`, `src/client/ui/GuidedMatch.luau`, `src/server/lobby/PlayerProfile.luau`, `tests/client/GuidedMatchRules.spec.luau`

**Interfaces:**
- Produce: `GuidedMatchRules.tipFor(event: Event, seenTips: { [string]: boolean }): string?`.
- Produce: `PlayerProfile.get(player): { completedMatches: number }`.

**Criterios de aceptación:**
- [ ] Solo quien no ha terminado una partida ve las explicaciones.
- [ ] Cada concepto se explica una vez, en el momento en que aparece, en una frase.
- [ ] Nunca se detiene la partida ni se obliga a cerrar nada.
- [ ] Se explican: comprar, renta, cartas, perks, vista general, pactos, Tribunal y espectro.
- [ ] Un jugador nuevo termina su primera partida sin ayuda externa en la prueba de la subfase 10.

- [ ] **Paso 1:** Escribir pruebas: un consejo aparece una sola vez y `Rent` da el consejo de renta.
- [ ] **Paso 2:** Ejecutar `lune run tests/run GuidedMatchRules`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar los módulos.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Hacer commit: `feat: añadir primera partida guiada`.

### Task 6: Música y sonido

**Módulos:** `client/audio/AudioDirector`, `art/audio`.

**Archivos:**
- Crear: `src/client/audio/AudioDirector.luau`, `src/client/audio/AudioRules.luau`, `art/audio/`, `tests/client/AudioRules.spec.luau`
- Modificar: escenas y `art/manifest.json`

**Interfaces:**
- Produce: `AudioDirector.play(id: string, opts: { volume: number? }?)`, `AudioDirector.setMusicState("Normal" | "FinalRounds" | "Podium")`.
- Produce: `AudioRules.gainFor(activeCount: number): number`.

**Criterios de aceptación:**
- [ ] Antes de usar audio generado, se confirman sus condiciones de uso comercial y los requisitos de subida de Roblox.
- [ ] Música de lobby, partida, Última Ronda y podio.
- [ ] Cada escena tiene su sonido; la ciudad, su ambiente.
- [ ] Varias escenas seguidas no saturan el volumen.
- [ ] El jugador puede ajustar música y efectos por separado.
- [ ] Cada pieza se registra en el manifiesto y se aprueba.

- [ ] **Paso 1:** Escribir pruebas de `AudioRules`: la ganancia baja al subir `activeCount` y nunca supera 1.
- [ ] **Paso 2:** Ejecutar `lune run tests/run AudioRules`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar y conectar el audio.
- [ ] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Obtener la aprobación del responsable con una partida grabada.
- [ ] **Paso 6:** Hacer commit: `feat: añadir música y sonido`.

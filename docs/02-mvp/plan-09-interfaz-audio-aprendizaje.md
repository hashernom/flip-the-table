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
- Cumple el [inventario de la interfaz](plan-09-inventario-interfaz.md): el plan no cierra con nada en gris.
- Requiere los planes 05 y 07 terminados, con Studio abierto. El responsable autorizó adelantarlo sin el plan 07 terminado (2026-11-05). Carga la skill `impeccable` antes de la Tarea 1.
- Puede avanzar a la par que el plan 08 solo en ramas separadas, sin tocar los mismos archivos ni usar Studio a la vez.
- Prueba siempre con la pantalla más pequeña admitida y el texto más largo.
- Confirma las condiciones de uso comercial antes de generar audio o ilustraciones.
- Pide un revisor nuevo para toda la rama antes de cerrar.
- Termina cuando se puede jugar toda la partida en móvil con la interfaz final, y el responsable la aprueba.
- Al terminar (planes 06 a 09) existe la alpha, provisional y pendiente de confirmar por el responsable. Sobre ella se pasa la Puerta A, aplazada desde la subfase 05 (`docs/02-mvp/resultados/puerta-a.md`).

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
- Crear: `src/client/ui/Components.luau`, `src/client/ui/HudRules.luau`, `src/shared/config/UiIcons.luau`, `art/ui/icons/`, `tests/client/HudRules.spec.luau`
- Modificar: `src/client/ui/Theme.luau`, `src/shared/config/Strings.luau`, `src/shared/config/Ui.luau`, `tests/config/Strings.spec.luau`

**Interfaces:**
- Produce: `Theme.color`, `Theme.font`, `Theme.space`, `Theme.scaleFor(viewport)`.
- Produce: `Components.Button`, `Panel`, `Card`, `Timer`, `PlayerChip`, `MoneyLabel`.
- Produce: `Strings.get(key: string, args: { [string]: any }?): string`.

**Criterios de aceptación:**
- [x] Aplica a títulos, fuentes, colores y componentes la identidad de la guía de estilo, siguiendo la skill `impeccable`.
- [ ] Texto mínimo legible en móvil; objetivos táctiles de 44 píxeles o más. **Móvil aplazado** por decisión del responsable (2026-11-04); en PC, los botones miden 44 o más.
- [x] Los dueños y estados se identifican también por icono o forma, no solo por color.
- [ ] Todo texto visible pasa por `Strings`. Listo para los componentes nuevos; los menús pasan en la Tarea 2.
- [x] El responsable aprueba una pantalla de ejemplo (2026-11-05, en Studio, turno con compra y 8 jugadores).

- [x] **Paso 1:** Escribir una prueba: `Strings.get` con una clave desconocida lanza un error; toda carta y perk de `config` tiene nombre y descripción.
- [x] **Paso 2:** Ejecutar `lune run tests/run Strings`. Esperado: FAIL.
- [x] **Paso 3:** Implementar tema, componentes y textos.
- [x] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [x] **Paso 5:** Obtener la aprobación del responsable con capturas en PC. El móvil queda aplazado.
- [x] **Paso 6:** Hacer commit: `feat: añadir sistema visual`.

**Pendiente al cerrar la tarea:** la aprobación se dio sobre una copia montada a mano en Studio. `Components.luau` y sus animaciones se ejecutan por primera vez en la Tarea 2, y los iconos siguen en estado `Draft`.

### Task 2: Interfaz de partida

**Módulos:** `client/ui/*`.

**Archivos:**
- Modificar: `Hud.luau`, `ActionMenu.luau`, `TradeMenu.luau`, `PactMenu.luau`, `Overview.luau`. `VoteMenu` y `PerkMenu` ya no existen: esas decisiones van en la barra de `ActionMenu`

**Criterios de aceptación:**
- [ ] Sigue funcionando toda la partida solo con menús. Código hecho; sin probar en Studio.
- [ ] La interfaz se oculta o se reduce durante las escenas. Código hecho: el HUD se aparta y Tratos, Pactos y la vista general se cierran; sin probar en Studio.
- [ ] Romper un pacto y otras acciones irreversibles requieren una segunda confirmación. Código y prueba (`ActionMenuRules.needsConfirm`); sin probar en Studio.
- [ ] En teclado y ratón tiene atajos para lo más común. Espacio, N, M, T, P, K y Esc, listados en Ajustes; sin probar en Studio.
- [ ] Los textos más largos no se cortan en la pantalla más pequeña admitida.

- [x] **Paso 1:** Sustituir cada menú y ejecutar `lune run tests/run ActionMenuRules`. Esperado: PASS. Todos los menús van sobre el tablón de obra (`client/ui/Board`), elegido por el responsable el 2026-11-05.
- [ ] **Paso 2:** Capturar cada menú con su texto más largo, en móvil y en PC.
- [ ] **Paso 3:** Obtener la aprobación del responsable.
- [ ] **Paso 4:** Hacer commit: `feat: completar interfaz de partida`.

### Task 3: Cartas, perks e iconos

**Módulos:** `art/ui`, `client/ui/Card`.

**Archivos:**
- Crear: `art/ui/cards/` (20 ilustraciones), `art/ui/perks/` (12 iconos), `art/ui/icons/`
- Modificar: `art/manifest.json`

**Criterios de aceptación:**
- [ ] 20 ilustraciones de carta y 12 iconos de perk registrados y aprobados. **Registrados** el
  2026-11-06 en `art/manifest.json` como `UiImage` en `Draft`; la aprobación del responsable sigue
  pendiente.
- [x] La rareza se reconoce por marco y borde, con dorado en las legendarias. Mismo papel caliza en
  las tres: filete simple de asfalto (común), doble filete con esquinas achaflanadas (rara) y triple
  filete de oro con esquinas biseladas (legendaria). El responsable aprobó el sistema el 2026-11-06 y
  pidió quitar la repisa que llevaba la legendaria encima del marco.
- [ ] Se distinguen entre sí en el tamaño de móvil. Comprobado a tamaño de mano de PC (104×150) con
  la tira de silueta a 95×95; el móvil sigue aplazado.
- [ ] No se parecen a las cartas del juego original. Sin marcas, sin símbolos de casino y sin
  personas, revisado por un revisor nuevo; falta la aprobación del responsable.

- [x] **Paso 1:** Producir 3 cartas de ejemplo y obtener su aprobación. `Multa` (común), `Huelga`
  (rara) y `Huracán` (legendaria), con su hoja de contacto en `art/render/ui/`; aprobadas el
  2026-11-06 con el cambio de la repisa.
- [x] **Paso 2:** Producir el resto y registrarlo. Cuatro lotes: 8 comunes, 5 raras, 4 legendarias y
  12 perks, cada uno con su generador y su fragmento de manifiesto.
- [x] **Paso 3:** Ejecutar `lune run tools/manifest`. Esperado: sin problemas. No existe ese comando:
  la comprobación del manifiesto es `lune run tools/check` (paso «Manifiesto»), que pasa sin
  problemas con las 32 entradas nuevas.
- [x] **Paso 4:** Hacer commit: `feat: añadir ilustraciones de cartas y perks`.

### Task 4: Lobby

**Módulos:** `client/ui/LobbyMenu`, `client/world/LobbyScene`.

**Archivos:**
- Modificar: `src/client/ui/LobbyMenu.luau`
- Crear: `src/client/world/LobbyScene.luau`

**Criterios de aceptación:**
- [ ] Desde el lobby se crea un código, se entra con uno o se juega en público.
- [ ] Se ve quién está en la party y se elige ficha antes de empezar.
- [ ] En partidas privadas, el anfitrión elige Rondas o Sin Fin, y el lobby explica en una frase cómo termina cada uno.
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
- [x] Se explican: comprar, renta, cartas, perks, vista general, pactos, Tribunal y espectro. Cubierto por prueba; sin probar en Studio.
- [ ] Un jugador nuevo termina su primera partida sin ayuda externa en la prueba de la subfase 10.

- [x] **Paso 1:** Escribir pruebas: un consejo aparece una sola vez y `Rent` da el consejo de renta.
- [x] **Paso 2:** Ejecutar `lune run tests/run GuidedMatchRules`. Esperado: FAIL.
- [x] **Paso 3:** Implementar los módulos.
- [x] **Paso 4:** Ejecutar el comando. Esperado: PASS.
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
- [ ] El jugador puede ajustar música y efectos por separado. Ajustes con dos barras; sin probar en Studio.
- [ ] Cada pieza se registra en el manifiesto y se aprueba.

- [x] **Paso 1:** Escribir pruebas de `AudioRules`: la ganancia baja al subir `activeCount` y nunca supera 1.
- [x] **Paso 2:** Ejecutar `lune run tests/run AudioRules`. Esperado: FAIL.
- [ ] **Paso 3:** Implementar y conectar el audio. Sistema hecho y conectado (`AudioDirector`, `config/Audio`, Ajustes); faltan las piezas, con sus ids vacíos hasta confirmar condiciones y aprobarlas.
- [x] **Paso 4:** Ejecutar el comando. Esperado: PASS.
- [ ] **Paso 5:** Obtener la aprobación del responsable con una partida grabada.
- [ ] **Paso 6:** Hacer commit: `feat: añadir música y sonido`.

## Estado al 2026-11-05 (rama `plan-09-tarea-2`, sin commit)

Hecho en código, con pruebas puras donde hay lógica, y sin probar todavía en Studio:

- **Estándar de ventana:** «tablón de obra», elegido por el responsable sobre tres maquetas (`.impeccable/mocks/ventanas/`). Tratos (proponer y recibido, con dinero libre), Pactos, Elegir ficha (ficha en 3D), Revancha, Lobby y Ajustes van sobre él. Las decisiones del panel (perks, Tribunal, Duelo, Mercado, reacción, espectro) son tarjetas pequeñas repartidas.
- **Mano:** carta en grande al pasar el ratón y animación al robar.
- **HUD:** «Un bot juega por ti» con RETOMAR (remoto `Reclaim`); botón y tecla de Ajustes.
- **Plazo de decisión:** 100 s, por decisión del responsable.
- **Tarea 5:** `GuidedMatchRules`, `GuidedMatch` y `PlayerProfile`.
- **Tarea 6:** `AudioRules`, `AudioDirector`, `config/Audio` y Ajustes.

Pendiente:

- **Aprobaciones y capturas** de las Tareas 2, 4 y 6 en Studio; el móvil sigue aplazado.
- **Tarea 3:** las ilustraciones de cartas y perks no se han producido.
- **Tarea 6:** la música y el ambiente no existen. Antes de generarlos hay que confirmar sus condiciones de uso comercial. Los efectos pequeños sí existen (2026-11-05): 14 efectos sintetizados desde cero por `art/audio/build_sfx.py` (clic, roce, abrir, cerrar, confirmar, rechazo, dinero, carta, tic, dados, obra, derribo, pacto roto, campanilla), sin muestras de terceros, en `art/audio/sfx/` y en el manifiesto como `Draft`. Sus ids siguen vacíos en `config/Audio` hasta subirlos a Roblox y aprobarlos. Ya están conectados: todos los botones suenan (`AudioDirector.bindUi`), las ventanas al abrir y cerrar, los rechazos, y cada evento de la mesa; los efectos varían un poco de tono en cada reproducción.
- **Cambios del 2026-11-05 pedidos por el responsable, sin probar en Studio:** fuente Builder Sans gruesa en lugar de Oswald, con un mínimo de 14 px; placa de dueño con canto, halo de 3 studs y luz (el halo se comprobó en Studio con una placa de prueba); destello del contorno al mejorar un edificio; las tarjetas de decisión ya no son `CanvasGroup` girados (se veían borrosas); la bandeja de opciones es plegable y sin scroll; las cartas se juegan desde la mano con un clic y «Confirmar» dentro de la carta, y el panel de la derecha ya no las repite; arreglado el paso del ratón entre cartas vecinas.
- **Lobby:** el servidor no envía la lista de la party, así que no se ve quién está. La elección de ficha sigue al empezar la partida, no en el lobby. `lobby.project.json` no monta los scripts del cliente: el lugar del lobby no enseña su menú. `LobbyScene` no existe.
- **`PlayerProfile`:** fuera de Studio escribe en un DataStore. Es el primer dato persistente de jugadores; aprobarlo antes de publicar.
- **Maqueta anidada en la vista general:** sin causa encontrada. `ModelCity` quita de la copia cualquier maqueta anidada y lo avisa en la consola con la ruta de origen.

## Estado al 2026-11-06 (rama `plan-09-tarea-3`)

**Tarea 3 hecha en arte y en código; falta subir las imágenes y que el responsable las apruebe.**

- **Las 20 ilustraciones y los 12 iconos existen** y son reproducibles: `python art/ui/cards/build_cards.py`
  (y `--lote <nombre>` para construir un lote suelto) y `python art/ui/perks/build_perks.py`. Los dos
  generan a 4× y reducen una sola vez, sin azar ni fechas: dos ejecuciones dan los mismos bytes.
- **Sistema visual aprobado el 2026-11-06** con tres cartas de ejemplo. El papel caliza es el mismo en
  las tres rarezas y lo que cambia es el borde: filete simple de 8 px (común), doble filete asfalto +
  caliza + marino con esquinas achaflanadas (rara) y triple filete de oro con esquinas biseladas
  (legendaria). El responsable pidió quitar la repisa que llevaba la legendaria encima del marco.
- **Lenguaje de las ilustraciones:** cosas y señales, nunca personas (la ciudad del juego no tiene
  gente). Fijado en `art/ui/cards/ilustraciones.md`, con el sujeto y los colores de las 20 cartas y de
  los 12 perks.
- **Registro:** las 32 entradas están en `art/manifest.json` como `UiImage` en `Draft`.
- **Config nuevo:** `src/shared/config/CardArt.luau`, con el `manifestId` de cada imagen, la banda de
  nombre y el aspecto de la carta; los `assetId` están vacíos hasta subirlos. Lo cubren nueve pruebas
  puras en `tests/config/CardArt.spec.luau`.
- **Integración:** `Components.Card` (la mano) y `Board.CardFace` (la vista grande) usan la imagen
  cuando hay `assetId` y se quedan como estaban cuando no; `Board.DecisionCard` enseña el icono del
  perk en la franja del tipo. Las tarjetas de decisión siguen sin ser `CanvasGroup` girados.

Pendiente:

- **Subir las 32 imágenes a Roblox.** Es publicar en la cuenta del responsable: hace falta su permiso.
  Después, rellenar los `assetId` en `CardArt.luau` y las capturas en el manifiesto, y probarlo en
  Studio con el MCP (mano, vista grande y elección de perk con el texto más largo).
- **Aprobación de las 32 imágenes.** Están en `Draft`; solo el responsable las pasa a `Approved`.
- **Móvil aplazado**, como el resto del plan.
- **Discrepancia de conteos en la guía de estilo:** su tabla de sellos dice 5 legendarias, 7 raras y 8
  comunes; `config/Cards.luau` tiene 5, 6 y 9. Manda la config, que es la fuente de verdad.

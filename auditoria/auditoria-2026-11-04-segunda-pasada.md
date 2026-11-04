# Auditoría de Flip the Table: segunda pasada

Commit auditado: `472e78c` (`main`). Fecha: 2026-11-04. Sustituye a la [primera pasada](auditoria-2026-11-04.md). Las correcciones ya están en `main`; las rutas con línea de las tablas de hallazgos se refieren a `472e78c` y pueden haberse movido.

**Veredicto: el motor de reglas es sólido y el reloj, las escenas y la revancha ya funcionan en Studio, pero el cliente todavía no se puede jugar de principio a fin.** Faltan los menús y el HUD. `tools/check` no los detecta, porque sus pruebas usan acciones inventadas en vez de estados reales del motor.

Cómo se comprobó cada hallazgo:
- **Ejecutado:** con una sonda sobre el código real. Se reproduce con `lune run auditoria/sondas/hallazgos`.
- **Búsqueda:** con `grep` en el repositorio.
- **Lectura:** leyendo el código, sin ejecutarlo.

## Cómo retomar

**Actualización (2026-11-04):** menús y HUD ya están cerrados, y el plan 06 está en curso. **Para retomar, empieza por el apartado «Estado» del [plan 06](../docs/02-mvp/plan-06-base-de-arte.md).** Las tablas de abajo quedan como registro de lo que se pidió, con los pendientes en «Estado de las correcciones».

**Al empezar la sesión:**
1. Lee `docs/instrucciones-de-sesion.md` y las decisiones R-P38 a R-P47 de `docs/01-arquitectura/arquitectura.md`.
2. Trabaja en una rama nueva desde `main`. Antes de hacer push o merge, pregunta.
3. **Pregunta al responsable el alcance visual.** Dijo que la interfaz gris se rehará por completo «porque debe tener otro diseño», y también que arreglará lo que falta antes del plan 06. Sin aclarar: si esta sesión hace solo la función con el arte gris, o ya el diseño nuevo. La interfaz final pertenece al plan 09, y para diseñarla su `CLAUDE.md` global y las instrucciones de sesión piden cargar la skill `impeccable`; para cambios solo funcionales, en el gris, no le hizo falta.
4. `lune run tools/check` tarda unos 8 minutos, sobre todo por `tests/sim.spec`. Mientras trabajas, filtra: `lune run tests/run ActionMenuRules`.

### Lo que falta en la próxima sesión

| # | Qué falta | Dónde | Cómo se propuso resolverlo |
| --- | --- | --- | --- |
| B4 | `PerkMenu` lee `pending.perkOffers`, que no existe: el motor usa `pending.draft.offer`. El modal «Sin perks» tapa la barra a todos y debajo hay tres «Elegir perk» | `ui/PerkMenu.luau`, `ActionMenuRules.labelFor` | Etiqueta `Nombre: descripción` desde `config/Perks`. Quitar el modal |
| B5 | El control va de 10 a alta + 10, arranca en 10 y vuelve a 10 con cada vista | `ActionMenuRules.bidControl`, `ui/ActionMenu.luau` | Mínimo = la puja que enumera el motor; máximo = tu efectivo. Conservar lo elegido entre vistas, acotado al rango nuevo. Añadir un salto mayor (+50), porque hay 15 s fijos |
| B6 | Botones iguales: Duelo (rival y jugada), Mercado (`labelFor` lee `index`, la acción lleva `cardId`), Tribunal, cartas por objetivo, Repetir dado y Renta Rebotada. `idFor` también repite ids | `ActionMenuRules.labelFor` e `idFor` | Etiquetas con la vista: «Retar a Ana», «Piedra», «Comprar Huelga por 200», «Multa a Ana», «Terremoto en Pasaje Cian», «Comprar Plaza Halcyon por 110», «Mover con 3 y 5». El id concatena todos los campos de la acción |
| B8 | No se ve la mano, los perks, la Corona, la Furia, la marca de Traidor, la puja alta, los precios ni el resultado del Espía (`pending.spy`). Nada avisa de una oferta recibida | `ui/Hud.luau`, `ui/Overview.luau` | Reglas puras nuevas (línea de asiento, mano, puja alta) y contador en «Tratos (1)» y «Pactos (1)» |
| B8 | Los tratos no admiten casillas: siempre manda listas vacías | `ui/TradeMenu.luau` | Elegir casillas propias y del rival sin edificios. Enseñar la parte de proponer solo en tu turno, en `AwaitRoll` o `AwaitEnd`. Filtrar rivales no activos, también en `PactMenu` |
| B8 | Una acción rechazada no avisa | `MatchService.applyAction` y `Match.submit`, `main.client` | Devolver el motivo y mandarlo por `LobbyNotice` con otro `kind`. **Ojo:** hoy todo aviso va a `rematchMenu.setNotice`, así que hay que separar por `kind`. Los clics durante una escena no deben avisar |
| I13 | Paneles de 420 y 460 px sin alto máximo; el scroll de los modales nunca actúa porque crece con el contenido | `ui/ActionMenu.luau`, `ui/Theme.luau` (`modal`) | Ancho en fracción con `UISizeConstraint`, y lista con scroll con alto máximo. `RematchMenu` ya usa ese ancho |
| M13 | `VoteMenu` se reabre tras votar, también al acusado y a los espectros | `ui/VoteMenu.luau` | Quitar el modal: con etiquetas claras, el voto cabe en la barra de acciones |
| M14 | Ids en inglés («Fine»), `userId` en vez de nombres y «casa» por casilla | `Hud`, `Overview`, menús | Nombres desde `config/Cards`, `config/Perks` y `config/Strings`. Los `playerId` son el `userId` en texto: resolver el nombre en `main.client` y guardar el último conocido, porque un bot puede ocupar el asiento de quien se fue |
| M12 | Los premios viajan en `GameEnded.awards` (junto a `ranking` y `winnerId`), pero nada los enseña | `RematchMenu` o una pantalla nueva | Podio con ganador y premios. `MostTreacherous`, `BestComeback`, `VictimOfTheNight` necesitan nombre en español |
| Extra | La barra enseña «Ronda 21/20» y mantiene Tratos y Pactos al acabar. Una respuesta de resync aplica los menús aunque haya una escena en curso (`resync.OnClientEvent` en `main.client`) | `ui/Hud.luau`, `main.client.luau` | Acotar la ronda, sin botones sociales en `GameOver`, y aplicar la vista de resync al acabar la escena |

**Avisos para esa sesión:**
- **Proponer quitar `PerkMenu` y `VoteMenu`:** el plan 05 los nombra, así que confírmalo con el responsable. Si se quitan, retira también `hideMenus` de ellos en `main.client`.
- **Texto puro y con pruebas:** pon los textos en un módulo puro, por ejemplo `ui/ViewText.luau`. El tablero sale de `Boards.get(view.sizeId)` (guárdalo en caché), y el nombre, de `Strings.squareLabel` con el ordinal dentro de la zona.
- **Sin duplicar fórmulas:** `Property.priceFor` y `Building.costOf` solo leen `state.board`, `state.players` y `state.pending`, así que aceptan `{ board, players = view.players, pending = view.pending }`.
- **Pruebas a cambiar con razón:** `tests/client/ActionMenuRules.spec.luau` fija el fallo B5 («bounds.min es el paso»). Cámbiala explicándolo; no es debilitarla.
- **Prueba de contrato (la más importante):** cada menú debe probarse con vistas salidas de `Engine` y `View`, como ya hace `ActionMenuRules.offerText`. Es lo que habría detectado B2, B4 y B6. La auditoría comprobó las etiquetas con `lune run auditoria/sondas/hallazgos` (apartados C3 a C6).
- **Los menús se ocultan durante la escena:** `hideMenus` en `main.client` y R-P39. El servidor descarta esos clics.

### Lo que va con el plan 06

| # | Qué falta | Nota |
| --- | --- | --- |
| I5 | Dueños y edificios no se ven en la ciudad: `CityBuilder.setOwner` no se llama y `BuildingView` no existe | `BuildingView` es entregable de la Tarea 3 del plan 06. Debe comparar vistas, no solo escuchar eventos: las ventas por bancarrota y Huracán no emiten `BuildingChanged` (M11) |
| I4 | Todas las fichas tienen el mismo color y ocupan el mismo punto | `main.client`: `ensureToken(seated.id, seated.position)` pasa la casilla donde debería ir el asiento. Falta además separar fichas en una misma casilla |
| Prueba | `tests/tools/manifest.spec.luau:139` («nunca aprobado») fallará al aprobar un asset en la Puerta B | Cambiarla lo decide el responsable: las normas prohíben debilitar una prueba por cuenta propia |
| Datos | Falta elegir el móvil de referencia antes de la Puerta B | Decisión del responsable |

El requisito del plan 06 dice «el plan 05 terminado, salvo la Puerta A». Con los menús cerrados en la próxima sesión, se cumple salvo lo publicado (ver abajo), que conviene anotar allí.

### Decisiones pendientes del responsable

La lista completa está en «Decisiones del responsable». No bloquean los menús ni el arte; conviene tomarlas antes de la alpha. Propuestas del auditor, **ninguna decidida**:

| Tema | Hallazgo | Propuesta |
| --- | --- | --- |
| Subasta | I2 | Mantener los 15 s fijos ya aplicados, como dice la ficha |
| Cartas de espectro | I12 | Permitir jugar Multa, Empujón y Demolición en su turno, como alternativa a robar o embrujar |
| Revolución | Decisión 3 | Ordenar por efectivo, que es lo que intercambia |
| Abogado | I11 | Que un empate favorezca también al acusado |
| Embrujo | I10 | Que dure hasta el siguiente turno del espectro, sin depender del asiento |
| Sin Fin | I14 | Aumentar la presión con las rondas; hoy puede durar horas |
| Empujón | M2 | Elegir dirección, y que no pague la Salida |
| Furia con la mano llena | M3 | Dejar elegir qué carta descartar |
| Casilla de zona con edificios | M4 | Prohibir tratarla o robarla mientras la zona tenga edificios |
| Dedos Rápidos | M7 | Aceptarlo como ventaja del perk, y etiquetar «Mover con 3 y 5» |

### Pruebas que faltan

- **Con personas:** una partida completa, cuando los menús lo permitan.
- **Sin probar:** 3 o más clientes, móvil, red real y volver al mismo asiento.
- **Requieren publicar, con permiso del responsable:** teletransporte, MemoryStore, lobby y vuelta al asiento.
- **Lobby:** `lobby.project.json` no monta el cliente, y `LobbyMenu` solo ofrece Rondas, así que Sin Fin no se puede elegir. Es parte del plan 09; hasta entonces se entra directamente al lugar de partida.

### Cómo probar en Studio con dos clientes

1. Abre `build/game.rbxl` (o crea uno con `rojo build -o build/game.rbxl`) y conecta Rojo con `rojo serve`. Comprueba que el código de Studio coincide con el disco antes de medir.
2. Menú **Test > Start Test Session > Server and Clients**. Solo abre la ventana del servidor; cada **Test > Add Clients** añade un cliente. Con 2, la partida arranca sola a los 3 s.
3. Cada ventana es un Studio distinto para el MCP: `list_roblox_studios` y, en cada id, `get_studio_state` dice si es cliente o servidor (el orden de la lista cambia).
4. **Trampas ya pagadas:**
   - `execute_luau` carga su propia copia de los módulos: su `MatchService` no es el de la partida. Para tocarla, añade antes de empezar un `Script` temporal en `ServerScriptService` que escuche un atributo de `Workspace`, y bórralo al terminar.
   - `loadstring` no está disponible.
   - `open_application` abre otra ventana de Studio vacía.
   - La votación de revancha dura 20 s desde que acaba la escena final.
   - Para llegar al final, pon `state.round = state.maxRounds` con ese script.
   - `Kick()` en un cliente simula una desconexión; un cliente nuevo recibe otro id, así que no sirve para probar la vuelta al asiento.

### Lo que no viaja con el repositorio

Si cambias de equipo, esto no está en git:
- `.superpowers/` (informes de las subfases 03 a 05; el plan 04 cita `.superpowers/sdd/plan-04-red-y-partidas/task-5-report.md`).
- `telemetry/`, `build/` y los `sourcemap*.json`, que se regeneran o son salida de ejecución.
- `art/**/*.blend` y el `.rbxl` del banco de pruebas de arte. `art/ESTADO.md` explica cómo reconstruirlo con `art/lookdev/`.
- Las herramientas: instálalas con `rokit install` y añade el plugin de Rojo en Studio.

## Estado de las correcciones

**Hecho, en `main`:** B1, B2, B3, B7, I1, I2, I3, I7, I8, I9, I15, M5, M6, M9, M10, M18, la parte de datos de M12, el paquete de I6 y los documentos y el `.gitignore` señalados abajo (R-P38 a R-P47 en la arquitectura), más el aplazamiento de la Puerta A.

**Cómo se comprobó:** B1, B3, B7, I1, I7 y M18, en Studio. I8 y el paquete de I6 solo tienen comprobación de tipos, porque necesitan un lugar publicado. El resto, con pruebas de Lune.

**Cerrado en la rama `plan-06-base-de-arte`, sin integrar en `main`:** B4, B5, B6, B8, I13, M12, M13, M14, M17, el «Extra», I4 e I5, y `PerkMenu` y `VoteMenu` retirados con el visto bueno del responsable. Las pruebas de Lune los cubren. En Studio (2026-11-04), una partida de 2 clientes, jugada por un script que manda acciones legales por el remoto real, llegó al final: perks, nombres, HUD, colores y sitio de las fichas, dueños, edificios hasta el nivel 5, aviso de rechazo, ronda 20/20, podio y botones de revancha. **Sin comprobar:** clics reales, control de puja, diálogo de tratos, aspecto de los paneles, móvil y votación de revancha, porque bajo Vinegar las ventanas de cliente salían como cuadros negros.

**Hallazgo nuevo, corregido (R-P49):** un `RemoteEvent` convierte a texto las claves de `view.properties` (`string:2`), comprobado en Studio. Lune no podía detectarlo; lo arregla `client/state/ViewWire`.

**Sigue abierto:** lo demás de «Cómo retomar». La salida de `sondas/hallazgos` ya muestra el comportamiento corregido en S1 a S3, aunque sus títulos describen el fallo original.

## Pruebas en Studio (2026-11-04, Test Server local)

Con el código de esa fecha, sin publicar nada. Los clientes los jugó un script automático y la partida saltó a la última ronda para llegar al final; ninguna persona jugó una partida entera.

| Prueba | Resultado |
| --- | --- |
| Base de tiempo | Confirma B1: `time()` valía 9,3 y `GetServerTimeNow()`, 1 793 803 602 |
| Duración de escenas | Correcta: `PerkDrafted` 2 s; `DiceRolled` y `TokenMoved` juntos, 4 s |
| 2 clientes: lotes | Mismo `seq` y en orden |
| 2 clientes: sincronía | Máximo 56 ms en 10 escenas (objetivo: 250 ms). Misma máquina, sin latencia real |
| Emotes | Llegan a los dos clientes con 12 ms de diferencia; se mandó por el remoto, no con el botón |
| Plazo con pactos en bucle | No se mueve (24,03 antes y después) |
| Acción durante una escena | Descartada, sin efecto |
| Cerrar un cliente a mitad de partida | El bot juega a los 0,5 s y la partida sigue con Duelo, Mercado y Portal |
| Entrar tarde | Sin asiento y con aviso. El aviso no se veía; corregido y comprobado |
| Avatares ajenos (M18) | **Fallo confirmado:** a 467 studs de su asiento. Corregido (R-P47): 2,8 studs |
| Final y revancha | El botón real vota, y con dos votos empieza otra partida en el mismo servidor; los dos clientes reciben los lotes desde el 0 |
| Revancha sin votos | Vence a los 20 s y avisa |

**Sin probar:** volver al mismo asiento (Studio da otro id al cliente nuevo), 3 o más clientes, móvil, red real, teletransporte, MemoryStore y lugar publicado.

**Visto de paso, sin investigar:** Studio avisa de `rbxassetid://203785492`, que no está en `src`.

## Bloqueantes

| # | Plan | Fallo | Efecto | Comprobación |
| --- | --- | --- | --- | --- |
| B1 | 05 | **Dos relojes distintos.** El servidor manda `startsAt = time()`, en segundos desde que arrancó (`MatchService.luau:211`). El cliente lo compara con `GetServerTimeNow()`, en segundos de época (`main.client.luau:371`). | Cada lote parece llevar unos 1 800 millones de segundos de retraso y cada escena dura 0,2 s. Huracán dura 0,2 s en vez de 10. El criterio de 250 ms entre clientes tampoco se cumple: cada cliente arranca al recibir el lote, sin esperar a `startsAt`. | Ejecutado con los dos valores; el reloj real, por lectura |
| B2 | 05 | **Un trato cuelga al que lo recibe.** `TradeMenu.luau:131` lee `trade.offer`, pero el motor guarda los campos sueltos (`Trade.luau:224`). | `formatOffer` lanza un error dentro de `applyView`. El bucle de `main.client.luau:369` no tiene `pcall`, así que ese cliente deja de procesar lotes para siempre. | Error ejecutado; la parada del bucle, por lectura |
| B3 | 04, 05 | **La revancha se congela y no tiene botón.** `EventQueue.resync(q, view, 0)` no reinicia `lastSeq`, y `src/client` nunca envía el voto. | Tras una partida de N lotes, los N primeros de la revancha se descartan como `Duplicate`. Además, `SceneDirector.seen` no se reinicia. | Ejecutado; el botón, por búsqueda |
| B4 | 05 | **La primera decisión de la partida está rota.** `PerkMenu.luau:26` lee `pending.perkOffers`, pero el motor usa `pending.draft.offer`. | Todos ven un modal que tapa la barra con «Sin perks que elegir». Al cerrarlo, quien elige ve tres botones iguales, «Elegir perk», sin nombre ni descripción. | Ejecutado |
| B5 | 05 | **No se puede pujar con normalidad.** El control va de 10 a alta + 10, arranca en 10 y cada vista nueva lo devuelve a 10 (`ActionMenuRules.luau:127`, `ActionMenu.luau:131`). | Con una puja de 200, «Pujar 10» se rechaza sin aviso. La única puja válida es la máxima, 210, a 20 pulsaciones de `+`. | Ejecutado |
| B6 | 05 | **Botones idénticos.** Pasa en Duelo, jugada y rival; Mercado, porque `labelFor` lee `index` y la acción lleva `cardId`; Tribunal; Multa por rival; 8 a 12 «Jugar carta: Earthquake»; Repetir dado y Renta Rebotada. | Se juega a ciegas. | Ejecutado |
| B7 | 04 | **Cualquier acción sin eventos reinicia el reloj** (`MatchState.step` y `SceneClock.schedule`). | Quien está en turno puede proponer un pacto cada 19 s y no tirar nunca: bloquea la mesa indefinidamente. Tampoco hay tope de ofertas, así que a 10 por segundo cada lote crece sin límite. | Ejecutado |
| B8 | 05 | **El cliente no enseña lo que necesitas.** No se ve la mano, los perks, la Corona, la Furia, la marca de Traidor, la puja alta, los precios del Mercado ni el resultado del Espía. Un trato no se puede hacer con casillas (`TradeMenu.luau:118`), y nada avisa de una oferta recibida ni de una acción rechazada. | Las cartas de reacción son invisibles, Espía no hace nada visible y la ficha promete Corona, Traidor y perks «a la vista». | Búsqueda en `src/client` |

## Importantes

| # | Plan | Fallo | Comprobación |
| --- | --- | --- | --- |
| I1 | 04 | **El servidor acepta acciones durante una escena y las escenas se solapan.** Un lote nuevo empieza en `now`, sin esperar al anterior (Huracán hasta t=110; un lote en t=101 acaba en t=103). Una acción sin eventos adelanta `sceneEndsAt`, y con ella el turno del bot. La ficha dice que el siguiente turno no empieza hasta que termina la escena. Los menús también aparecen antes de la escena (`main.client.luau:375`). | Ejecutado |
| I2 | 03 | **Cada puja reinicia los 15 s de la subasta.** La ficha pide subastas rápidas de 15 s, y una guerra de pujas se alarga sin tope de tiempo. Decide si quieres este comportamiento. | Ejecutado |
| I3 | 04 | **`MarketBought` revela a toda la mesa la carta comprada** (1 066 veces en la sonda hostil). `CardDrawn` y `CardDiscarded` sí la ocultan. | Ejecutado |
| I4 | 05 | **Todas las fichas son del mismo color y ocupan el mismo punto.** `ensureToken(seated.id, seated.position)` usa la casilla como asiento para elegir el color (`main.client.luau:168`), y todos empiezan en la 1. Tampoco hay separación entre fichas en la misma casilla. | Lectura |
| I5 | 05 | **La ciudad no cambia.** `setOwner` nunca se llama, nadie lee `level` y `BuildingView` no existe, aunque la arquitectura lo asigna a la subfase 05. | Búsqueda |
| I6 | 04 | **El lobby no se puede usar.** `lobby.project.json` no monta el cliente. Además, `main.client.luau:274-278` manda valores sueltos y `validateLobby` exige una tabla con `type`, y nadie escucha `LobbyNotice`, así que el código de party nunca se vería. La interfaz solo ofrece Rondas, de modo que Sin Fin es inalcanzable. La subfase 09 lo cubre en parte; para la alpha, los jugadores tendrían que entrar directamente al lugar de partida. | Ejecutado (paquetes); lectura |
| I7 | 04 | **Llegadas al lugar de partida** (`main.server.luau:107-120`). Quien llega más de 3 s después se queda sin asiento, sin aviso y con el menú de lobby abierto para siempre. Si solo llega uno de un grupo, espera indefinidamente. | Lectura |
| I8 | 04 | **Teletransporte agotado:** solo un `warn` (`Teleport.luau:45`), sin aviso ni vuelta al lobby. Para entonces la party ya se borró, así que el jugador se queda sin party. | Lectura |
| I9 | 03 | **Un Coleccionista espectro acumula efectivo:** +100 por sabotaje con la mano llena (`Deck.luau:140`). Rompe la regla de que un espectro está fuera del dinero; apareció 166 veces en la sonda hostil. | Ejecutado |
| I10 | 03 | **El Embrujo depende del asiento.** Caduca al acabar la ronda en curso (`Comeback.luau:227`), y en el último asiento de la ronda no protege nada. El plan dice «durante 1 ronda». | Ejecutado |
| I11 | 03 | **Abogado no ayuda al acusado.** Solo favorece a quien vota, y el acusado no vota. La ficha dice «los empates te favorecen». | Ejecutado |
| I12 | 05 | **Espectros:** acumulan cartas que no pueden jugar hasta resucitar. Tras la remontada, ya no les sirven para nada. | Lectura |
| I13 | 05 | **Móvil:** los paneles tienen ancho fijo de 420 y 460 px, sin alto máximo. La barra crece hacia arriba y `Roll` o `EndTurn` van primero, así que con muchos botones se salen de la pantalla. El scroll de los modales tampoco se activa, porque crece con su contenido. Contradice R-P37. | Lectura |
| I14 | 03 | **Sin Fin:** solo con tiempo agotado no siempre termina: con 8 jugadores, 3 de 3 partidas seguían en la ronda 12 000 aproximadamente. Con bots siempre termina, pero en una media de 150 rondas (máximo 310), es decir, horas de juego. | Ejecutado |
| I15 | 06 | **`lune run tools/manifest`, paso 3 de la Tarea 3, no comprueba nada:** el módulo no tiene punto de entrada y sale con 0. La regla «un id que no esté en el manifiesto no se referencia desde `src/`» no se aplica, y su prueba compara el manifiesto consigo mismo. `manifest.spec.luau:139` fallará en cuanto apruebes un asset en la Puerta B. | Ejecutado; lectura |

## Menores

| # | Fallo |
| --- | --- |
| M1 | La escena repetida se reduce a la mitad hasta 0,5 s durante toda la partida, así que el recorrido de la ficha cae a 0,5 s desde su tercera vez. La media medida es de unos 3 s de escena por turno. Es de bajo riesgo hoy, pero afecta directamente a las escenas de la subfase 08 y al objetivo de 2 a 4 s. |
| M2 | Empujón solo mueve hacia delante, y el rival puede cobrar la Salida: en la sonda pasó de 1500 a 1700. |
| M3 | La Furia se pierde con la mano llena: la carta rara se descarta. |
| M4 | Se puede regalar una casilla sin edificios de una zona con edificios: el resto conserva su nivel sin tener la zona completa. Ladrón de Escrituras también lo permite, por lectura. |
| M5 | Casero redondea mal por coma flotante: 93 combinaciones dan 1 de menos, por ejemplo 114 en vez de 115. |
| M6 | `RentPaid` anuncia el importe completo aunque el pagador quiebre: anuncia 200 y el dueño recibe 5. |
| M7 | Dedos Rápidos deja ver los dados antes de jugar Marcha Atrás o Dado Extra, y obliga a pulsar dos veces «Tirar dados». |
| M8 | Los bots no responden tratos: la oferta caduca sola. |
| M9 | Dos vencimientos seguidos activan el bot, y el reloj normal de subasta, Duelo o Tribunal cuenta contra quien está en turno. Un solo despiste real puede bastar. |
| M10 | El temporizador no se fija en la vista inicial ni en el resync. |
| M11 | Las ventas por bancarrota y Huracán no emiten eventos de edificio, así que `BuildingView` tendrá que comparar vistas. |
| M12 | `Awards.compute` no se usa en `src`: el podio y los premios no existen todavía. |
| M13 | `VoteMenu` se reabre tras votar, también al acusado y a los espectros. |
| M14 | Los textos enseñan ids en inglés («Fine»), `userId` en vez de nombres y «casa» por casilla. |
| M15 | `status = "Left"` nunca se asigna: es código muerto. |
| M16 | Hay números repetidos fuera de config: `BANK_SALE_DIVISOR` (dos sitios), `MAX_ROUNDS` de `PactMenu` y `EMOTES` de `Hud`. |
| M17 | Sin confirmar: `Overview` no fija el tamaño de su panel, y podría verse de 100 × 100. Hay que mirarlo en Studio. |
| M18 | Sin confirmar: el avatar va soldado a una ficha local anclada, y puede que los demás jugadores no lo vean encima de ella. Hay que mirarlo con dos clientes. |

## Documentación y repositorio

**Corregido:** las afirmaciones falsas de `puerta-a.md` y del plan 05, `docs/README.md`, «Metrópolis de Noche», Apagón pasa a Huelga (id `Strike`), «sabotajes jugados» en el plan 03, y `.claude/worktrees/` ignorado.

**Sigue abierto:**
- **Contradicción:** `ficha-propuesta.md:257` dice que las reglas se prueban primero con arte provisional, y la Puerta A ya está aplazada hasta la alpha. Corregirlo lo decide el responsable, porque la ficha es su documento.
- **Casillas del plan 06:** están todas sin marcar, aunque la guía, el manifiesto y la tubería ya existen. Revísalas al empezar ese plan.
- **Git LFS:** ningún archivo está en LFS y hay binarios normales en el historial; un worktree nuevo aparece con 52 archivos modificados sin que nadie los toque. Convertirlo reescribe el historial y exige force-push, así que hay que decidirlo antes.
- **Limpiable en el equipo original, si se confirma:** los worktrees de `.claude/worktrees/` y las ramas locales `docs-puerta-a-tras-alpha`, `plan-05-cliente-jugable`, `art-tuberia`, `plan-06-base-de-arte` y `worktree-agent-*`. Ninguna tiene trabajo sin integrar en `main`.
- **`dsh-plugins/`:** un complemento local («session-task-clock») que no es parte del juego. Se incluyó porque el responsable pidió subir todo; el repositorio es público.

## Hallazgos de la primera pasada

| Primera pasada | Resultado |
| --- | --- |
| 1 a 4 (puja y botones) | Confirmados: B5 y B6 |
| 5 (revancha) | Confirmado y más grave: B3 |
| 6 (ciudad) | Confirmado: I5 |
| 7 (teletransporte) | Confirmado: I8 |
| 8 (espectros) | Confirmado: I12 |
| 9 (Sin Fin) | Reproducido con cifras equivalentes: I14 |
| 10 (fallo del almacén) | **Corregido:** `PartyStore.remove` no lanza errores. El riesgo real es el de I8 |
| 11 (limitadores) | **Descartado:** la memoria está acotada por jugador y el plan no pide castigo |
| 12, 15, 16 | Confirmados: M10, M15 y M16 |
| 13 (Revolución) | Confirmado: pasa a decisión 3 |
| 14, 17, 18, 19, 20 | Confirmados: ver el apartado anterior |

También se descartó una sospecha nueva: `TeleportOptions.ReservedServerId` sí existe en la documentación oficial, aunque sin descripción. Falta probarlo en un lugar publicado.

## Lo que está bien

- **`lune run tools/check`:** pasa entero en 7 min 56 s.
- **Motor bajo ataque:** 90 s, 185 partidas, 195 790 acciones legales y 611 715 hostiles. Sin errores, sin partidas atascadas, sin cambios de estado al rechazar y sin fugas de manos, dados del Duelo, votos, Espía o `rng` en las vistas. La única infracción de invariantes es I9.
- **Plan 01:** una prueba que falla, un error de carga y un filtro sin coincidencias dan código de salida 1.
- **Contenido:** por lectura, coinciden las 34 propiedades, los colores, los precios, la composición de los tres tableros y las 20 cartas y 12 perks de la ficha.
- **Seguridad:** la identidad sale siempre del `Player`, los paquetes pasan una lista blanca y los votos de revancha exigen asiento.
- **Normas:** no hay apuestas, pagos, `rbxassetid` en `src` ni marca de Monopoly en el código.
- **Tubería:** los datos de `PIPELINE.md` que se contrastaron coinciden con la documentación oficial: 20 000 triángulos, geometría estanca, cuads y una pista de animación. Las páginas consultadas no cubren tangentes, normales ni `EnvironmentSpecularScale`.

## Decisiones del responsable

1. **Subasta:** hoy el cierre es fijo, a los 15 s, como dice la ficha. ¿Se mantiene, o cada puja debe reiniciar el tiempo? (I2)
2. **Espectros:** ¿pueden jugar sus cartas de sabotaje? (I12)
3. **Revolución:** ¿ordena por patrimonio o por efectivo? Hoy ordena por patrimonio e intercambia efectivo.
4. **Abogado:** ¿debe favorecer al acusado? (I11)
5. **Embrujo:** ¿debe cubrir una ronda completa desde que se lanza? (I10)
6. **Sin Fin:** ¿aceptas partidas de horas o aumentas la presión? (I14)
7. **Equilibrio:** el líder a mitad gana el 62,7 % en S con bots, por encima del objetivo de 50 %, aunque 19 % y 29 % en L y M. Son bots, pero conviene vigilar S.
8. **Escudo:** ¿frena Ladrón de Escrituras, Demolición y Propina Forzada?
9. **Ventana de reacción:** delata a toda la mesa quién lleva Escudo o Renta Rebotada, lo que choca con la regla de que el juego sea impredecible.
10. **Mercado Negro:** ofrece siempre una legendaria por 300, al margen de la probabilidad creciente. ¿Se mantiene?
11. **Una sola resurrección:** está en el código y no en la ficha.
12. **Cola pública:** arranca en cuanto hay 4, así que rara vez habrá partidas de 5 a 8. ¿Se mantiene?
13. **Alpha y Puerta A:** confirmar la definición provisional de alpha y elegir el móvil de referencia. El aplazamiento ya está integrado.
14. **Revisión para el plan 10:** el parecido del tablero (40 casillas, cuatro esquinas), la Cartelera como azar simulado y nombres como «Mercado Negro», de cara a la consulta legal y la clasificación de edad.

## Otros hallazgos abiertos

No bloquean nada; se pueden atender cuando toque:

- **M1:** las escenas repetidas se reducen hasta 0,5 s durante toda la partida. En Studio se vio `PropertyBought` en 0,5 s desde la cuarta ronda. Hay que revisarlo antes de la subfase 08.
- **M8:** los bots no responden tratos.
- **M15:** `status = "Left"` nunca se asigna.
- **M16:** `BANK_SALE_DIVISOR` fuera de config (su comentario lo declara regla fija), y `MAX_ROUNDS` de `PactMenu` y `EMOTES` de `Hud` repetidos.
- **M17:** `Overview` no fija el tamaño de su panel; míralo en Studio al tocar el HUD.
- **`rbxassetid://203785492`:** Studio avisa de este asset, que no está en `src`.

## Sin cubrir

- **Con personas y publicado:** ver «Pruebas que faltan». Tampoco se comprobó si quedó un Model `AlbedoCheck` en el lugar de arte (`art/ESTADO.md`, «Lo que falta», punto 1).
- **Revisado solo a través de sus pruebas:** `MatchSummary`, `criteria-report`, `CityLayout`, `CameraRules` y `PartyCode`.
- **No revisado:** el contenido de `art/guia-de-estilo.md` y de las imágenes de concepto, los planes 07 a 10 y las fases 1 a 4.
- **Conservación del dinero evento a evento:** no se hizo, porque varios movimientos no emiten evento (M11). La sonda comprobó que el efectivo sea entero y no negativo.

## Commits de esta auditoría

- `1ea29be`: reloj, plazo y escenas sin solapes.
- `3379470`: cuelgue por tratos y revancha.
- `77ef448`: reglas, llegadas, teletransporte y herramientas.
- `ab93bbf`: avatares ajenos y aviso a quien entra tarde.
- `684d1ca`: integración en `main`.
- `536ef75`: aplazamiento de la Puerta A.

Las sondas están en `auditoria/sondas/` (`hallazgos`, `fuzz` y `medidas`) y se ejecutan con `lune run auditoria/sondas/<nombre>` desde la raíz del repositorio.

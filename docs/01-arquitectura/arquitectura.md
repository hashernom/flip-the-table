# Arquitectura común

**Todas las reglas viven en un motor puro y determinista, sin Roblox; el servidor lo ejecuta y los clientes convierten sus eventos en escenas.** Así, las reglas se prueban en segundos fuera de Studio y todo el grupo ve lo mismo.

Este documento fija los nombres que usan todos los planes. Si un plan necesita cambiar un contrato, primero se cambia aquí.

## Flujo

```text
Jugador -> Client/Net -> Server/RemoteGateway -> Server/MatchService -> Rules/Engine.apply
                                                                            |
                                                              eventos y nuevo estado
                                                                            |
Todos los clientes <- Server/MatchService (lote numerado) <- View.forPlayer + SceneClock
        |
Client/EventQueue -> Client/SceneDirector -> escena, cámara, HUD y audio
```

## Stack

| Pieza | Decisión | Motivo |
| --- | --- | --- |
| Lenguaje | Luau con `--!strict` | Lenguaje nativo de Roblox, con tipos |
| Sincronización | [Rojo 7](https://rojo.space/docs/v7/) | El código vive en archivos y en git |
| Herramientas | Rokit (`rokit.toml`) con versiones fijadas | Mismo entorno para todos los agentes |
| Pruebas de lógica | [Lune](https://lune-org.github.io/docs/) y arnés propio en `tests/` | Se ejecutan sin abrir Studio |
| Pruebas en Roblox | MCP de Roblox Studio y Test Server | Cámara, escenas y red |
| Calidad | Selene, StyLua y `luau-lsp analyze` | Errores y estilo uniformes |
| Arte 3D | Blender, con MCP de Blender, exportado a FBX | Decisión de la ficha |
| Módulos | `require` por cadena relativa (`./X`, `../x/Y`), sin módulos `init` en `src/shared/rules` | Funciona igual en [Roblox](https://devforum.roblox.com/t/introducing-require-by-string/3405078) y en Lune |

Las versiones exactas se fijan en `rokit.toml` al ejecutar la subfase 01.

## Estructura del repositorio

```text
default.project.json   rokit.toml   selene.toml   stylua.toml
src/
  shared/
    rules/    Motor puro: sin Instance, game, workspace ni task
    config/   Datos: Economy, Boards, Cards, Perks, Squares, Scenes, Strings
    net/      Protocol: nombres de remotos y validadores
  server/
    match/    Partida en curso
    lobby/    Party, cola pública y teletransporte
  client/
    state/    EventQueue y StateStore
    camera/   Primera persona, turno compartido y vista general
    world/    Ciudad, fichas y edificios
    scenes/   SceneDirector y una carpeta por escena
    ui/       HUD y menús
    audio/    Música y efectos
tests/        Pruebas Lune (*.spec.luau), arnés y simulaciones
art/          Fuentes .blend, texturas, manifest.json y guía de estilo
tools/        Scripts Lune de verificación (`check`, `manifest`)
```

## Módulos

### Motor: `src/shared/rules`

| Módulo | Responsabilidad | Subfase |
| --- | --- | --- |
| `Types` | Todos los tipos compartidos | 01 |
| `Rng` | Azar determinista y serializable | 01 |
| `State` | Crear una partida | 02 |
| `Board` | Consultas de casillas, zonas y grupos | 02 |
| `Movement` | Mover fichas y pagar la Salida | 02 |
| `Property` | Compra, renta y multiplicadores | 02 |
| `Auction` | Subastas | 02 |
| `Building` | Niveles de edificio | 02 |
| `Trade` | Intercambios | 02 |
| `Bankruptcy` | Arruinarse y pasar a espectro | 02 |
| `Score` | Patrimonio, clasificación y Corona | 02 |
| `Turn` | Máquina de fases, rondas y final | 02 |
| `Engine` | Fachada pública: `apply`, `timeout`, `legalActions` | 02 |
| `Bot` | Elegir una acción legal | 02 |
| `Deck` | Robo con rareza y límites | 03 |
| `Cards` | Efecto de las 20 cartas | 03 |
| `Reaction` | Ventanas de reacción | 03 |
| `Perks` | Selección y efecto de los 12 perks | 03 |
| `Squares` | Giro, Mercado, Duelo, Portal, Cartelera y Tribunal | 03 |
| `HotZone` | Zona Caliente | 03 |
| `Pact` | Pactos y traiciones | 03 |
| `Comeback` | Furia y Espectros | 03 |
| `Awards` | Premios del final | 03 |
| `View` | Vista filtrada por jugador | 04 |

`Board.zoneOrder` da las zonas en orden de ruta. Al elegir una zona con `Rng`, se usa esa lista: un diccionario no tiene orden estable y rompería el determinismo. `tools/pure-rules` también prohíbe `math.random`, `os.time` y `os.clock` en el motor.

### Datos: `src/shared/config`

`Economy`, `Boards`, `Cards`, `Perks`, `Squares` y `Scenes`. Todo número ajustable vive aquí, nunca en la lógica.

### Servidor

| Módulo | Responsabilidad | Subfase |
| --- | --- | --- |
| `server/match/RemoteGateway` | Recibe y valida acciones; limita su frecuencia | 04 |
| `server/match/MatchService` | Ejecuta el motor y difunde lotes de eventos | 04 |
| `server/match/SceneClock` | Calcula cuándo termina cada escena, sin esperar a los clientes | 04 |
| `server/match/PresenceService` | Desconexiones, regreso y control por bot | 04 |
| `server/match/RematchService` | Revancha con el mismo grupo | 04 |
| `server/match/Telemetry` | Resumen de cada partida para los criterios de salida | 04 |
| `server/lobby/PartyService` | Códigos de party y servidor reservado | 04 |
| `server/lobby/PublicQueue` | Partidas públicas | 04 |

### Cliente

| Módulo | Responsabilidad | Subfase |
| --- | --- | --- |
| `client/state/EventQueue` | Ordena lotes y detecta huecos | 05 |
| `client/state/StateStore` | Última vista conocida | 05 |
| `client/camera/CameraDirector` | Elige el modo de cámara | 05 |
| `client/world/CityBuilder` | Coloca casillas y barrios según el tamaño | 05 |
| `client/world/TokenRider` | Sube el avatar a la ficha y recorre la ruta | 05 |
| `client/world/BuildingView` | Muestra el nivel de cada edificio | 05 |
| `client/ui/Hud` y menús | Interacción táctil y de PC | 05 y 09 |
| `client/scenes/SceneDirector` | Reproduce escenas en orden | 05 y 08 |
| `client/audio/AudioDirector` | Música y efectos | 09 |

## Contratos del motor

```luau
export type PlayerId = string
export type SizeId = "S" | "M" | "L"
export type PlayerStatus = "Active" | "Ghost" | "Left"
export type Rarity = "Common" | "Rare" | "Legendary"
export type EndMode = "Rounds" | "Endless"

export type Phase =
    "PerkDraft" | "AwaitRoll" | "AwaitBuy" | "Auction" | "Reaction"
    | "Tribunal" | "Duel" | "Market" | "AwaitEnd" | "GhostTurn" | "GameOver"

export type Player = {
    id: PlayerId, isBot: boolean, status: PlayerStatus,
    cash: number, position: number,
    hand: { string }, perks: { string },
    fury: number, sabotages: number, skipTurns: number,
    traitorUntilRound: number?, damageReducedRound: number?,
}

export type GameState = {
    rng: RngState,
    sizeId: SizeId, board: Board,
    players: { Player }, turnIndex: number,
    endMode: EndMode, round: number, maxRounds: number?,
    phase: Phase, pending: any?,
    properties: { [number]: PropertyState },
    pacts: { Pact }, modifiers: { Modifier },
    hotZoneId: string?, lastLegendaryRound: number?,
    stats: MatchStats,
}

export type Action = { type: string, [string]: any }
export type Event = { type: string, [string]: any }
export type ApplyResult = { ok: true, events: { Event } } | { ok: false, error: string }
```

Funciones públicas:

```luau
State.create(opts: { playerIds: { PlayerId }, seed: number, endMode: EndMode? }): GameState
Engine.apply(state: GameState, playerId: PlayerId, action: Action): ApplyResult
Engine.timeout(state: GameState): { Event }
Engine.legalActions(state: GameState, playerId: PlayerId): { Action }
Bot.choose(state: GameState, playerId: PlayerId): Action?
-- `nil` cuando no hay ninguna acción legal (p. ej. una subasta ajena sin dinero) o cuando el bot
-- decide no pujar en una subasta; quien dirige la partida cierra entonces con Engine.timeout.
View.forPlayer(state: GameState, playerId: PlayerId): PlayerView
```

`Engine.apply` valida antes de modificar nada. Si la acción es ilegal, devuelve `ok = false` y el estado queda intacto.

### Acciones

`DraftPerk`, `Roll`, `RerollDie`, `Buy`, `DeclineBuy`, `Bid`, `PlayCard`, `React`, `PassReaction`, `Build`, `ProposeTrade`, `RespondTrade`, `ProposePact`, `RespondPact`, `BreakPact`, `TribunalVote`, `DuelChoice`, `MarketBuy`, `MarketSkip`, `GhostAct`, `EndTurn`.

### Eventos

`RoundStarted`, `FinalRoundsStarted`, `PerkDrafted`, `DiceRolled`, `TokenMoved`, `PassedStart`, `PropertyBought`, `RentPaid`, `AuctionStarted`, `AuctionWon`, `AuctionNoSale`, `BuildingChanged`, `TradeCompleted`, `PlayerArrested`, `TribunalVerdict`, `BankruptcyDeclared`, `GhostActed`, `GhostResurrected`, `CardDrawn`, `CardDiscarded`, `CardPlayed`, `CardBlocked`, `HotZoneMoved`, `BillboardResult`, `DuelResolved`, `PortalUsed`, `MarketBought`, `PactFormed`, `PactEnded`, `PactBroken`, `CrownMoved`, `FuryFilled`, `GameEnded`.

Cada carta legendaria y rara se expresa como `CardPlayed` más los eventos concretos que causa. `Scenes` asigna escena y duración por evento y por carta.

### Decisiones que cambian los contratos

Ajustes acordados al cerrar la subfase 02. Prevalecen sobre lo que digan los planes y las notas de trabajo.

- **R5:** el tope ×4 acota solo los efectos dinámicos; la zona completa y los edificios quedan fuera.
- **R6:** `Bot.choose` devuelve `Action?`; `nil` cuando no hay ninguna acción legal.
- **R12:** en Sin Fin no hay rondas finales; desde la ronda 30 la Salida no paga y la renta se duplica, con el tope ×4.
- **R27:** gana siempre el primer jugador `Active` de la clasificación; la regla del último activo manda sobre el límite de rondas.
- **R32:** con `idle` solo se cubre el modo Rondas; en Sin Fin nadie compra y, sin sumideros de dinero hasta la fase 03, la partida no puede terminar.

## Datos iniciales

Valores de partida. Se ajustan en pruebas, siempre en `src/shared/config`.

| Valor | Inicial |
| --- | --- |
| Efectivo inicial | 1500 |
| Cobro por pasar la Salida | 200 |
| Precio de propiedad por zona | De 60 a 400, creciente a lo largo de la ruta |
| Niveles de edificio | De 0 a 5: solar, una, dos y tres casas, hotel y rascacielos |
| Renta base | 10 % del precio |
| Renta con grupo completo | Base × 2 |
| Multiplicador de renta por nivel | × 2, × 3, × 5, × 8 y × 12 |
| Coste por nivel de edificio | 50 % del precio |
| Multiplicador máximo de renta | × 4 sobre el producto de los efectos dinámicos (rondas finales, presión, Inflación, Zona Caliente, Huelga y Embrujo); la zona completa y los edificios se aplican aparte |
| Temporizador de decisión | 20 s |
| Subasta | 15 s |
| Voto del Tribunal | 10 s |
| Ventana de reacción | 5 s |
| Impuesto | 100 |
| Peaje de Portal | 50 |
| Castigos del Tribunal | Multa de 150, perder 1 turno o pagar 100 a quien elijan |
| Garantía de pacto | 100 (50 con Negociador) |
| Marca de Traidor | 3 rondas |
| Furia | Se llena con 5 rentas pagadas sin ser líder |
| Resurrección de espectro | 3 sabotajes; vuelve con 500 |
| Mano máxima | 3 cartas (4 con Contrabandista) |

### Composición del tablero

Coincide con los 40, 48 y 56 de la ficha. Las zonas tienen 2 o 3 propiedades: 2 en Cobre y Violeta, 3 en el resto. El multiplicador del nivel de edificio se aplica sobre la renta con grupo completo; los efectos dinámicos van aparte.

| Tamaño | Jugadores | Barrios | Zonas | Salida | Propiedades | Giro | Mercado | Duelo | Portal | Cartelera | Tribunal | Impuesto | Total |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S | 2 a 4 | Centro y Puerto | 8 | 1 | 22 | 6 | 2 | 2 | 3 | 2 | 1 | 1 | 40 |
| M | 5 a 6 | + Zona Alta (2 zonas) | 10 | 1 | 28 | 7 | 2 | 2 | 3 | 3 | 1 | 1 | 48 |
| L | 7 a 8 | + Industrial (2 zonas) | 12 | 1 | 34 | 8 | 2 | 2 | 3 | 4 | 1 | 1 | 56 |

### Momentos de la partida

| Tamaño | Rondas | 2.º perk, ronda | 3.er perk, ronda | Renta doble, rondas |
| --- | --- | --- | --- | --- |
| S | 20 | 7 | 14 | 19 y 20 |
| M | 15 | 6 | 11 | 14 y 15 |
| L | 12 | 5 | 9 | 11 y 12 |

Fórmula: `floor(N / 3) + 1` y `floor(2 * N / 3) + 1`. En Sin Fin, el 2.º y el 3.er perk llegan en las rondas 6 y 12; desde la ronda 30, la Salida deja de pagar y la renta se duplica, respetando el máximo de × 4, para que la partida siempre avance hacia un final. La Zona Caliente se mueve al empezar las rondas 1, 4, 7 y así sucesivamente.

### Robo de cartas por posición

| Posición en la clasificación | Común | Rara | Legendaria |
| --- | --- | --- | --- |
| Líder | 75 | 23 | 2 |
| Mitad superior | 70 | 25 | 5 |
| Mitad inferior | 55 | 30 | 15 |

El peso de legendaria se multiplica según las rondas pasadas desde la última robada, o desde el inicio si aún no hay ninguna. La rara no cambia y la común completa hasta 100.

| Rondas sin legendaria | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 o más |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Multiplicador | × 0,1 | × 0,25 | × 0,5 | × 1 | × 1,5 | × 2 | × 2,5 | × 3 |

### Cartelera de la Suerte

| Resultado | Normal | Con Afortunado |
| --- | --- | --- |
| Premio grande | +200 | +300 |
| Premio pequeño | +100 | +150 |
| Multa | -100 | -100 |
| Carta | Robo normal | Robo normal |
| Nada | Sin efecto | Sin efecto |

Peso igual para los 5 resultados. Nunca se pide apostar ni arriesgar nada.

## Restricciones de todo el proyecto

Se aplican a todas las fases y tareas.

- **Impredecible:** ninguna estrategia debe basarse en saber de antemano qué evento va a llegar.
- **Identidad propia:** no se usa el nombre, logo, personajes ni diseño de tablero de Monopoly.
- **Sin azar con apuesta:** ninguna mecánica pide arriesgar dinero, Robux u objetos en un juego de azar, ni tiene estética de casino. [La norma de Roblox](https://create.roblox.com/docs/production/promotion/experience-guidelines) prohíbe el juego de azar jugable, incluso simulado.
- **Sin pagar para ganar:** las cartas y los perks nunca se compran con dinero real. Solo se vende apariencia, y nada de pago es aleatorio.
- **Clasificación objetivo:** Minimal o Mild, las que la guía de Roblox hace accesibles a los grupos de menor edad.
- **Pactos sin chat:** todo lo social debe poder hacerse desde menús, sin chat ni voz.
- **Sin movimiento libre:** el jugador nunca camina por la ciudad.
- **Escena compartida:** los eventos se ven a la vez y en el mismo orden. Un cliente lento nunca detiene la partida.
- **Duración de escenas:** comunes de 2 a 4 s; legendarias, hasta 10 s.
- **Autoridad del servidor:** el cliente solo envía intenciones; dinero, dados y cartas se deciden en el servidor.
- **Información oculta:** la mano de cada jugador solo se envía a su dueño.
- **Assets:** cada uno cumple el estándar de la ficha y se aprueba por una persona. El límite por malla de Roblox es de [20 000 triángulos](https://create.roblox.com/docs/art/modeling/specifications); los presupuestos del juego son menores (subfase 06).

## Fuentes consultadas

Consultadas el 2026-11-01.

- [Guía de experiencias de Roblox](https://create.roblox.com/docs/production/promotion/experience-guidelines): azar, etiquetas de madurez y objetos aleatorios de pago.
- [Especificaciones de mallas de Roblox](https://create.roblox.com/docs/art/modeling/specifications): límite de triángulos.
- [Require por cadena en Roblox](https://devforum.roblox.com/t/introducing-require-by-string/3405078): rutas relativas.
- [Documentación de Rojo 7](https://rojo.space/docs/v7/) y [de Lune](https://lune-org.github.io/docs/).

**Sin verificar todavía:** el comportamiento exacto de `TeleportService`, `MemoryStoreService`, `AnalyticsService`, las compras en la experiencia y las capturas de pantalla. Cada tarea que los usa empieza consultando su documentación oficial.

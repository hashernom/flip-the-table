# Incidencia: el cliente no reconoce como propias las propiedades compradas

**Fecha:** 2026-11-07. **Estado:** causa identificada y corregida en la rama `fix-propiedades-cable`; pendiente de confirmar en una partida publicada. **Rama de diagnóstico:** `diag-propiedades` (`96dfdfb`), sobre `main` (`c29eaef`).

Este documento es autocontenido: resumen, evidencias, qué se descartó y cómo, hipótesis abiertas y la instrumentación ya preparada.

## 1. Resumen

En una partida de **5 jugadores humanos** (tablero M), varios jugadores compran propiedades, se les cobra el precio y el servidor las trata como suyas (**les pagan renta cuando otros caen** y **no les ofrece comprarlas al caer**), pero **el cliente no las pinta como propias**:

- el gestor de propiedades responde «Todavía no tienes propiedades» o enseña menos de las compradas,
- no aparece la placa/halo del dueño en la casilla,
- tampoco salen en el panel de trato.

O sea: **el estado del servidor es correcto y la vista que consume el cliente es la que falla**. Todas las superficies afectadas leen `view.properties[].ownerId`; las que no lo hacen (barra, turnos, escenas, fichas) funcionan.

## 2. Síntomas observados

Partida publicada, 5 humanos (4 reales + el responsable), sin bots, **sin subastas**. Confirmado que corre el código nuevo (`main` con el merge del plan 08 y la escalera de rentas): una escritura de Cobre muestra 10 · 15 · 25 · 60 · 145 · 290 · 385.

- **Jugador A:** compra propiedades y se le descuenta el dinero; al abrir el gestor (G) recibe el aviso `manage.none` («Todavía no tienes propiedades», `main.client.luau:757`). No hay halo en sus casillas. Cuando otros caen en ellas, **le pagan la renta**. Al caer él en una casilla suya, **no le ofrece comprarla** (la acción la calcula el servidor).
- **Jugador B:** compró unas 5 propiedades y el panel del gestor solo mostraba 2.
- **Trato:** las propiedades «fantasma» tampoco aparecen en el panel de trato.
- **F9:** ninguna línea de error ni `warn`. El juego avanza con normalidad: turnos, escenas, fichas, dinero en la barra.

## 3. Qué está confirmado

- El **servidor** tiene el dueño: cobra renta y no ofrece la compra.
- El fallo **no es de una pantalla**: gestor, libro de escrituras, trato y halo leen la misma tabla y fallan juntos.
- Las pantallas que no dependen de `properties` funcionan (barra con dinero y turno, escenas, fichas).

## 4. Camino de datos (con referencias a `main`)

**Servidor**

1. `MatchService.broadcast` (`src/server/match/MatchService.luau:117`): un lote por jugador, mismo `seq`.
2. `MatchState.batch` (`src/server/match/MatchState.luau:209`): `view = View.forPlayer(state, playerId)`.
3. `View.forPlayer` (`src/shared/rules/View.luau:116`) → `viewProperties` (`:67`), que copia `ownerId`, `level`, `mortgaged`, `price`, `rent`…
4. `remote:FireClient(player, batch)`.

`playerId` es `tostring(player.UserId)` (`MatchService.luau:100`), y las propiedades se indexan por **índice de casilla** con huecos (`State.newProperties`).

**Cliente**

5. `eventBatch.OnClientEvent` (`src/client/main.client.luau:1105`) → `ViewWire.normalize(batch.view)` (`:1109`): convierte a número las claves de `properties` que Roblox entrega como texto.
6. `EventQueue.push` (`src/client/state/EventQueue.luau:49`) → `playBatch` → `StateStore.apply` (`src/client/state/StateStore.luau:36`) guarda la vista.
7. `applyView` (`src/client/main.client.luau:996`) reparte a cada pieza:
   - `manager.setData(view, byIndex)` (`:1019`) y `book.setData(view)` (`:1020`), **dentro del paso `ActionMenu`**;
   - `tradeMenu.setView(view, names)` (`:1069`);
   - al final del lote, `syncTokens(view)` (`:1262`) → `BuildingView.sync` (`src/client/world/BuildingView.luau:494`) → `CityBuilder.setOwner` (`src/client/world/CityBuilder.luau:895`), que crea la placa y el halo.

**Consumidores que fallan**

- `PropertyManagerRules.owned` (`src/client/ui/PropertyManagerRules.luau:33`): `property.ownerId == playerId`.
- `SocialRules.tradeableSquares` (`src/client/ui/SocialRules.luau:120`): `ownerId == ownerId and property.level == 0`.
- `WorldRules.propertyChanges` (`src/client/world/WorldRules.luau:24`) + `seatOf` (`:88`): el halo se pinta solo si el `ownerId` del cambio casa con un asiento.

## 5. Qué se descartó y con qué evidencia

1. **La vista del servidor.** 12 partidas completas de 5 jugadores con bots, comparando `View.forPlayer(state, id).properties[i].ownerId` contra `state.properties[i].ownerId` cada 40 acciones: **0 divergencias**. El script está en el apéndice A.
2. **Compra y subasta.** `Property.buy` cobra y asigna `ownerId` en la misma operación; `Auction.close` (`src/shared/rules/Auction.luau:101`) también. En esta partida no hubo subastas.
3. ~~**El transporte (conversión de claves).**~~ **Descarte erróneo: era la causa (ver §11).** La simulación pasaba *todas* las claves a texto, que es el caso del diccionario puro y sí funciona; nunca reprodujo la forma real de la tabla.
4. **Mutaciones del cliente.** Ningún código de `src/client` escribe `ownerId`.
5. **El merge como origen directo.** `View.luau`, `MatchState.luau`, `src/client/state/*` y `BuildingView`/`CityBuilder` **no cambiaron** entre `27fb1a9` (main anterior) y `c29eaef`.
6. **El gestor como único culpable.** El panel de trato usa otra función (`SocialRules.tradeableSquares`) y falla igual.

## 6. Hipótesis abiertas

- **H1 (principal):** al cliente le llega `view.properties` sin `ownerId` o con menos entradas de las que hay en el servidor. Sería un problema de serialización/transporte o de la normalización, y explicaría los cuatro síntomas a la vez.
- **H2:** `view.playerId` no coincide con los `ownerId` que llegan (tipo distinto: número contra texto, o formato distinto). Explicaría gestor y trato, y el halo si además `seatOf` no encuentra el asiento.
- **H3:** `property.level` llega nulo o distinto de 0. Solo explicaría el panel de trato (filtra por `level == 0`), no el resto.
- **H4 (ya confirmada como bug aparte, no causa de esto):** cuando el asiento propio pasa a control de bot, `applyView` sale antes de `manager.setData`/`book.setData` y el gestor y el libro dejan de refrescarse. Ver §8.

## 7. Instrumentación lista

Rama **`diag-propiedades`** (`96dfdfb`), que es `main` + 32 líneas de `print` en `applyView` (se quitan al terminar). Vuelca por F9, y solo cuando cambia el número de propiedades propias:

```
[DIAG] tablero=M yo=123456(string) mias=0 total=28 asientos=123,456,789,101,112 duenos=2(string)=456(string) 15(string)=789(string)
```

Campos: tablero, `playerId` del cliente y su tipo, cuántas cuentan como propias, cuántas entradas trae `properties`, ids de los asientos, y cada propiedad con dueño como `clave(tipo)=dueño(tipo)`.

**Cómo usarla:** publicar el lugar de partida desde esa rama, jugar, comprar 2 o 3, y leer las líneas `[DIAG]` en F9 → Client.

## 8. Bug adyacente confirmado (no es la causa, pero hay que arreglarlo)

En `src/client/main.client.luau:1040-1052`, el paso `ActionMenu` de `applyView` hace `return` cuando el asiento propio tiene `isBot == true` **antes** de `manager.setData` y `book.setData`. Resultado: si al jugador se le da el control al bot (dos tiempos agotados seguidos, `Economy.bot.timeoutsToControl`), el gestor y el libro se quedan congelados con la última vista aunque el bot siga comprando por él; de ahí un «compré 5 y muestra 2». **No explica el halo ni el trato** (esos van por otro paso), así que no es la causa de esta incidencia, pero es un fallo real: `manager.setData` y `book.setData` deberían ejecutarse antes del chequeo de bot, y solo los botones deberían ocultarse.

## 9. Entorno y estado del repo

- Repo: `D:\monopoly`. Luau/Roblox con Rojo; pruebas con Lune 0.11.1.
- `main` = `c29eaef` (merge del plan 08 + escalera de rentas), subido a `origin/main`.
- Rama actual del repo: `diag-propiedades` (`96dfdfb`), árbol limpio.
- No hay Studio conectado por MCP: no se puede inspeccionar el DataModel en vivo. La partida se juega en el lugar publicado con 5 personas.
- Comprobaciones que pasan en ambas ramas: `lune run tests/run rules|client|config|net` (680/427/131/33), `stylua --check`, `selene`, `luau-lsp` estándar y Roblox, `lune run tools/check`.

## 10. Siguiente paso

1. Publicar `diag-propiedades` y recoger las líneas `[DIAG]` de una partida real.
2. Según lo que digan (árbol de decisión):
   - `total` menor que las propiedades del tablero → se pierden entradas en el transporte: mirar `ViewWire.normalize` y el tamaño/forma del payload.
   - `duenos` trae los ids correctos pero `mias=0` → comparación de ids: revisar tipos y formato entre `view.playerId` y `properties[].ownerId`.
   - `mias` correcto y aun así sin halo → tirar por `seatOf`/`propertyChanges` y el color del asiento.
3. Arreglar H4 en la misma pasada o en un commit aparte, con una prueba si se puede (la lógica vive en `main.client.luau`, que no es testeable en Lune; valorar extraer el troceo de la vista a una regla pura).

## Apéndice A — comparación vista/estado (reproducible)

Script temporal en `tests/` (no versionado). Juega con bots semillas completas de 5 jugadores y compara cada 40 acciones:

```lua
local Bot = require("../src/shared/rules/Bot")
local Engine = require("../src/shared/rules/Engine")
local State = require("../src/shared/rules/State")
local View = require("../src/shared/rules/View")

local ids = { "P1", "P2", "P3", "P4", "P5" }
for seed = 1, 12 do
	local state = State.create({ playerIds = ids, seed = seed, endMode = "Rounds" })
	local actions = 0
	while state.phase ~= "GameOver" and actions < 200000 do
		-- … bucle de acciones con Bot.choose / Engine.timeout, igual que tests/sim.luau …
		actions += 1
		if actions % 40 == 0 then
			for _, player in state.players do
				local view = View.forPlayer(state, player.id)
				for index, property in state.properties do
					assert(
						view.properties[index] ~= nil
							and view.properties[index].ownerId == property.ownerId,
						`diverge {player.id} casilla {index}`
					)
				end
			end
		end
	end
end
```

Resultado esperado tal como se ejecutó: **ninguna divergencia** en 12 semillas.

## 11. Causa y arreglo

**Causa.** `View.viewProperties` devuelve `properties` indexada por casilla con huecos. En el tablero M las claves son `2,3,5,6,7,9,10,11,14,15,16,20,21,22,26,27,28,32,33,34,38,39,41,42,43,45,46,47`. Luau guarda esa tabla **mezclada**: un tramo de array con `nil` dentro (de la 2 a la 34, y la 1 vacía) y el resto en el hash. En Lune, `rawlen(view.properties)` da 16, y `next` recorre en orden de la 2 a la 34 y luego desordenado de la 38 a la 47. La documentación de los `RemoteEvent` pide no pasar tablas con `nil` en sus índices: Roblox no la transmite entera, y al cliente le llegan menos entradas. Las compras que caen en las que se pierden no se ven en ninguna superficie. Eso explica los cuatro síntomas a la vez, y que el servidor siga cobrando bien.

**Arreglo** (rama `fix-propiedades-cable`):

- `ViewWire` pasa de `src/client/state` a `src/shared/net` y gana `ViewWire.encode`, que copia la vista con las claves de `properties` en texto (un diccionario puro, sin tramo de array).
- `MatchState.batch` y `MatchState.resync` envían `ViewWire.encode(View.forPlayer(...))`. En el cliente, `ViewWire.normalize` ya devolvía las claves a número.
- `tests/net/ViewWire.spec.luau`: para los tableros de 2 a 8 jugadores, con todas las propiedades con dueño, comprueba que solo hay claves de texto, que `rawlen` da 0 y que la ida y vuelta conserva el dueño y el nivel de cada casilla. También comprueba que `resync` envía la vista codificada; sin el arreglo, esa prueba falla (`rawlen` 16).
- **H4** corregida: en `applyView`, `manager.setData` y `book.setData` se ejecutan antes del chequeo de `isBot`.

**Pendiente:** publicar y comprobar en una partida real. La línea `[DIAG]` de esta rama debería dar `total=28` y `mias` igual a las compradas. Las 32 líneas de `print` de diagnóstico se quitan antes de fusionar con `main`.

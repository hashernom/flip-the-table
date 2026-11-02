--!strict
-- Remontada: Furia al pagar rentas y turno corto del espectro (R-P43). Un espectro roba una
-- carta de sabotaje o embruja una propiedad para que no cobre durante una ronda; con
-- Economy.ghost.sabotagesToRevive sabotajes acumulados, el turno se emplea en resucitar en la
-- Salida con Economy.ghost.reviveCash.
--
-- Dependencias: Deck, Economy, Rng, Score y Types. No require Property ni Turn para no cerrar
-- ciclos: Property llama a Comeback.onRentPaid, Turn llama a Comeback.beginGhostTurn y Engine es
-- quien cierra el turno del espectro con su propia salida (GameOver y PerkDraft).
local Deck = require("./Deck")
local Economy = require("../config/Economy")
local Rng = require("./Rng")
local Score = require("./Score")
local Types = require("./Types")

type GameState = Types.GameState
type Player = Types.Player
type PlayerId = Types.PlayerId
type Event = Types.Event
type ApplyResult = Types.ApplyResult

-- Forma que entiende Comeback para la acción GhostAct. Engine la construye a partir de su
-- Action: { kind = "Sabotage" } o { kind = "Haunt", index }.
export type GhostAction = {
	kind: string,
	index: number?,
}

-- Las tres cartas de sabotaje de la ficha: las comunes Fine y Shove y la rara Demolition. Por esta
-- vía solo se entregan en el turno del espectro o con Alma en Pena; un robo normal puede dar las
-- mismas cartas porque están en el catálogo.
local SABOTAGE_CARDS: { string } = { "Fine", "Shove", "Demolition" }

-- La Salida es la casilla 1 (Movement acredita el bono al pisar ese índice).
local START_INDEX = 1

-- Perk Alma en Pena (R-P6). El id del catálogo se consulta sin require Perks.
local RESTLESS_SOUL_PERK = "RestlessSoul"

local Comeback = {}

local function findPlayer(state: GameState, playerId: PlayerId): Player?
	for _, player in state.players do
		if player.id == playerId then
			return player
		end
	end
	return nil
end

local function playerOf(state: GameState, playerId: PlayerId): Player
	local player = findPlayer(state, playerId)
	if not player then
		error(`Comeback: no existe el jugador {playerId}`, 3)
	end
	return player
end

local function append(events: { Event }, more: { Event })
	for _, event in more do
		table.insert(events, event)
	end
end

-- Líder de la mesa: el primer Active de la clasificación. Es el criterio de la Furia, no el de la
-- Corona (que solo se mueve al empezar ronda).
local function leaderOf(state: GameState): Player?
	for _, id in Score.ranking(state) do
		local player = findPlayer(state, id)
		if player and player.status == "Active" then
			return player
		end
	end
	return nil
end

-- Entrega una carta de sabotaje al azar entre Fine, Shove y Demolition. No toca player.sabotages:
-- el contador mide acciones de sabotaje y las 2 cartas de Alma en Pena no son acciones.
function Comeback.giveSabotage(state: GameState, playerId: PlayerId): { Event }
	return Deck.add(state, playerId, Rng.pick(state.rng, SABOTAGE_CARDS))
end

-- Furia: cada renta pagada por quien no lidera suma 1. Al llegar a Economy.furyThreshold roba una
-- carta rara o mejor (minRarity = "Rare"), vuelve a 0 y emite FuryFilled. Lo llama
-- Property.chargeRent después del cobro, así que la clasificación ya refleja el pago.
function Comeback.onRentPaid(state: GameState, payerId: PlayerId): { Event }
	local payer = playerOf(state, payerId)
	-- R-P20/R-P21: un espectro o quien se fue ya no está en el circuito de dinero. Si la renta lo
	-- arruinó, no cobra Furia ni roba cartas: la partida puede haber terminado y no se emiten
	-- eventos después de GameEnded.
	if payer.status ~= "Active" then
		return {}
	end
	-- "Furia nunca cambia cuando el pagador es el líder": ni sube ni se dispara.
	local leader = leaderOf(state)
	if leader and leader.id == payerId then
		return {}
	end
	payer.fury += 1
	if payer.fury < Economy.furyThreshold then
		return {}
	end
	payer.fury = 0
	local events: { Event } = { { type = "FuryFilled", playerId = payerId } }
	append(events, Deck.draw(state, payerId, "Rare"))
	return events
end

-- Motivo por el que un embrujo no vale, o nil. Solo propiedades con dueño distinto del espectro:
-- un embrujo sobre algo propio o sin dueño no tendría a quién quitarle la renta.
local function hauntReason(state: GameState, playerId: PlayerId, index: any): string?
	if type(index) ~= "number" or index % 1 ~= 0 then
		return "El embrujo necesita el índice de una propiedad"
	end
	local property = state.properties[index]
	if not property then
		return "La casilla indicada no es una propiedad"
	end
	if not property.ownerId then
		return "La propiedad no tiene dueño"
	end
	if property.ownerId == playerId then
		return "No puedes embrujar tu propia propiedad"
	end
	return nil
end

-- Motivo por el que una acción de espectro no vale, o nil. No modifica el estado. Es la única
-- regla, compartida por Comeback.ghostAct y por la comprobación previa de Engine.
function Comeback.ghostActReason(state: GameState, playerId: PlayerId, action: GhostAction): string?
	-- Una partida terminada no reabre nada: ni siquiera una resurrección (R11).
	if state.phase == "GameOver" then
		return "La partida ha terminado"
	end
	if state.phase ~= "GhostTurn" then
		return `No se puede GhostAct en la fase {state.phase}`
	end
	local player = findPlayer(state, playerId)
	if not player then
		return `El jugador {playerId} no está en la partida`
	end
	if player.status == "Left" then
		return "El jugador ha abandonado la partida"
	end
	if player.status ~= "Ghost" then
		return "Solo un espectro puede actuar en el turno de espectro"
	end
	local current = state.players[state.turnIndex]
	if not current or current.id ~= playerId then
		return "No es tu turno"
	end
	if type(action.kind) ~= "string" then
		return "GhostAct necesita el tipo de acción"
	end
	if action.kind == "Sabotage" then
		return nil
	end
	if action.kind ~= "Haunt" then
		return `Acción de espectro desconocida: {action.kind}`
	end
	return hauntReason(state, playerId, action.index)
end

-- Resurrección: vuelve Active con el capital de la ficha, en la Salida y sin sabotajes guardados.
-- comebackRounds queda con las rondas que estuvo como espectro, para el premio de la Tarea 10.
local function revive(state: GameState, player: Player): { Event }
	player.status = "Active"
	player.cash = Economy.ghost.reviveCash
	player.position = START_INDEX
	player.sabotages = 0
	local stats = state.stats[player.id]
	stats.comebackRounds = stats.ghostRounds or 1
	return { { type = "GhostResurrected", playerId = player.id, cash = Economy.ghost.reviveCash } }
end

-- Aplica la única acción del turno del espectro. No cierra el turno: Engine lo hace después
-- para que la acción y el reloj compartan la misma salida (GameOver y PerkDraft incluidos).
function Comeback.ghostAct(state: GameState, playerId: PlayerId, action: GhostAction): ApplyResult
	local reason = Comeback.ghostActReason(state, playerId, action)
	if reason then
		return { ok = false, error = reason }
	end
	local player = playerOf(state, playerId)
	-- Con los sabotajes acumulados, el turno se emplea en resucitar en vez de actuar.
	if player.sabotages >= Economy.ghost.sabotagesToRevive then
		return { ok = true, events = revive(state, player) }
	end
	if action.kind == "Sabotage" then
		local stats = state.stats[playerId]
		stats.sabotages = (stats.sabotages or 0) + 1
		player.sabotages += 1
		local events: { Event } = { { type = "GhostActed", playerId = playerId, kind = "Sabotage" } }
		-- R-P6: la carta se entrega con Deck.add; si la mano está llena se descarta y el
		-- sabotaje cuenta igual (el contador mide acciones, no cartas en la mano).
		append(events, Comeback.giveSabotage(state, playerId))
		return { ok = true, events = events }
	end
	local index = action.index :: number
	table.insert(state.modifiers, {
		kind = "Haunt",
		index = index,
		playerId = playerId,
		-- untilRound es la última ronda activa: el embrujo cubre esta ronda y caduca al entrar
		-- en la siguiente. Property.rentMultiplier ya filtra por untilRound >= state.round.
		untilRound = state.round,
	})
	return {
		ok = true,
		events = { { type = "GhostActed", playerId = playerId, kind = "Haunt", index = index } },
	}
end

-- Empieza el turno de un espectro: cuenta la ronda para los premios. La llama Turn.next cuando
-- la fase del turno es GhostTurn, también si el reloj acaba cerrando el turno sin acción.
function Comeback.beginGhostTurn(state: GameState, playerId: PlayerId)
	local stats = state.stats[playerId]
	stats.ghostRounds = (stats.ghostRounds or 0) + 1
end

-- ¿El jugador lleva Alma en Pena? El id del catálogo se consulta sin require Perks.
local function hasRestlessSoul(player: Player): boolean
	return table.find(player.perks, RESTLESS_SOUL_PERK) ~= nil
end

-- Cartas de sabotaje de Alma en Pena (R-P6), en el orden en que se entregan y con sus eventos.
-- Las llama Bankruptcy justo cuando el jugador pasa a Ghost.
function Comeback.grantRestlessSoul(state: GameState, playerId: PlayerId): { Event }
	local events: { Event } = {}
	if not hasRestlessSoul(playerOf(state, playerId)) then
		return events
	end
	for _ = 1, Economy.perks.restlessSoulCards do
		append(events, Comeback.giveSabotage(state, playerId))
	end
	return events
end

return Comeback

--!strict
-- Vista por jugador. Es la única frontera entre el estado autoritativo del servidor y lo que viaja
-- al cliente: las manos ajenas, los ids de las cartas robadas, las jugadas secretas del Duelo, las
-- papeletas del Tribunal, la mano que revela el Espía y el generador de azar nunca salen de aquí.
-- Todo es lógica pura: no usa game, Instance, task ni ningún reloj, no muta el estado y devuelve
-- copias para que la vista sea una instantánea (R-P4).
local Board = require("./Board")
local Building = require("./Building")
local Engine = require("./Engine")
local Property = require("./Property")
local Types = require("./Types")

type GameState = Types.GameState
type PlayerId = Types.PlayerId
type PlayerView = Types.PlayerView
type ViewPlayer = Types.ViewPlayer
type Event = Types.Event

local View = {}

-- Copia profunda de los datos del motor. Nada de lo que se envía puede compartir tabla con el
-- estado, o una escena o un cliente podrían alterar la partida en curso.
local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result: { [any]: any } = {}
	for key, item in value do
		result[key] = copy(item)
	end
	return result
end

-- Copia un jugador. La mano es lo único privado: se incluye solo en la vista de su dueño; los
-- demás reciben el número de cartas.
local function viewPlayer(player: Types.Player, viewerId: PlayerId): ViewPlayer
	local result: ViewPlayer = {
		id = player.id,
		isBot = player.isBot,
		status = player.status,
		cash = player.cash,
		position = player.position,
		perks = table.clone(player.perks),
		fury = player.fury,
		sabotages = player.sabotages,
		skipTurns = player.skipTurns,
		traitorUntilRound = player.traitorUntilRound,
		damageReducedRound = player.damageReducedRound,
		handCount = #player.hand,
	}
	if player.id == viewerId then
		result.hand = table.clone(player.hand)
	end
	return result
end

local function viewPlayers(state: GameState, viewerId: PlayerId): { ViewPlayer }
	local players: { ViewPlayer } = {}
	for _, player in state.players do
		table.insert(players, viewPlayer(player, viewerId))
	end
	return players
end

-- Las propiedades son públicas: copia cada una para no compartir la tabla del estado, con las cifras
-- que la ciudad pinta en su casilla. La renta sale de las mismas reglas que la cobran.
local function viewProperties(state: GameState): { [number]: Types.ViewProperty }
	local properties: { [number]: Types.ViewProperty } = {}
	for index, property in state.properties do
		properties[index] = {
			ownerId = property.ownerId,
			level = property.level,
			mortgaged = property.mortgaged,
			price = Board.square(state, index).price or 0,
			rent = Property.rentFor(state, index),
			mortgageValue = Building.mortgageValue(state, index),
			unmortgageCost = Building.unmortgageCost(state, index),
		}
	end
	return properties
end

-- Copia `pending` y quita lo que solo puede ver su dueño. Los secretos son los del contrato: la
-- jugada del Duelo, la papeleta del Tribunal y la mano del Espía. Cualquier campo nuevo que guarde
-- una decisión privada debe limpiarse aquí.
local function viewPending(state: GameState, viewerId: PlayerId): any?
	local pending = state.pending
	if not pending then
		return nil
	end
	local view = copy(pending)
	-- El Espía entrega la mano robada solo en la vista de quien jugó la carta.
	if view.spy ~= nil and view.spy.viewerId ~= viewerId then
		view.spy = nil
	end
	-- Duelo: cada participante ve su jugada y nadie más. Al resolverse, `pending.duel` desaparece
	-- y el evento DuelResolved anuncia el resultado a todos.
	local duel = view.duel
	if duel ~= nil and duel.picks ~= nil then
		local ownPick = duel.picks[viewerId]
		duel.picks = if ownPick ~= nil then { [viewerId] = ownPick } else {}
	end
	-- Tribunal: cada votante ve su papeleta y nadie más. Al resolverse, `pending.tribunal`
	-- desaparece y TribunalVerdict publica todas las papeletas.
	local tribunal = view.tribunal
	if tribunal ~= nil and tribunal.votes ~= nil then
		local ownVote = tribunal.votes[viewerId]
		tribunal.votes = if ownVote ~= nil then { [viewerId] = ownVote } else {}
	end
	-- El azar no viaja nunca, tampoco si una fase lo copiara dentro de pending.
	view.rng = nil
	return view
end

-- Vista completa de un jugador: datos públicos de la mesa, su mano y sus acciones legales.
function View.forPlayer(state: GameState, playerId: PlayerId): PlayerView
	local viewer: Types.Player? = nil
	for _, player in state.players do
		if player.id == playerId then
			viewer = player
			break
		end
	end
	if not viewer then
		error(`View.forPlayer: no existe el jugador {playerId}`, 2)
	end
	return {
		playerId = playerId,
		sizeId = state.sizeId,
		endMode = state.endMode,
		round = state.round,
		-- Sin Fin no tiene tope de rondas y el contrato fija maxRounds como número: 0 es «sin
		-- tope». No cambiar el tipo por nil.
		maxRounds = state.maxRounds or 0,
		phase = state.phase,
		turnIndex = state.turnIndex,
		players = viewPlayers(state, playerId),
		properties = viewProperties(state),
		pacts = copy(state.pacts),
		modifiers = copy(state.modifiers),
		hotZoneId = state.hotZoneId,
		stats = copy(state.stats),
		pending = viewPending(state, playerId),
		legalActions = Engine.legalActions(state, playerId),
	}
end

-- Eventos que llevan el id de una carta robada. Se oculta a todos menos a su dueño; CardPlayed no
-- está aquí porque una carta jugada es pública (así se anuncian las legendarias).
local DRAWN_CARD_EVENTS: { [string]: boolean } = {
	CardDrawn = true,
	CardDiscarded = true,
}

-- Filtra un lote de eventos para un jugador. Es total: devuelve una lista nueva, no muta la
-- entrada ni sus eventos y deja pasar sin tocar los tipos que no conoce (un evento futuro no debe
-- desaparecer porque View todavía no lo entienda).
function View.filterEvents(_state: GameState, playerId: PlayerId, events: { Event }): { Event }
	local filtered: { Event } = {}
	for _, event in events do
		local viewEvent = copy(event)
		if DRAWN_CARD_EVENTS[viewEvent.type] == true and viewEvent.playerId ~= playerId then
			viewEvent.cardId = nil
		end
		-- Comprar en el Mercado mete la carta en la mano: es tan secreta como una robada. El precio
		-- también se oculta porque la oferta es pública y lleva una carta por rareza a un precio
		-- distinto, así que delataría cuál fue.
		if viewEvent.type == "MarketBought" and viewEvent.playerId ~= playerId then
			viewEvent.cardId = nil
			viewEvent.price = nil
		end
		table.insert(filtered, viewEvent)
	end
	return filtered
end

return View

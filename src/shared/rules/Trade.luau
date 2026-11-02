--!strict
-- Intercambios entre jugadores. Una oferta vive en pending.trades hasta que el destinatario
-- responde o hasta que termina el turno en que se hizo (caducidad, R20).
local Types = require("./Types")

type GameState = Types.GameState
type PlayerId = Types.PlayerId
type Player = Types.Player
type PropertyState = Types.PropertyState
type Phase = Types.Phase
type Event = Types.Event
type ApplyResult = Types.ApplyResult

-- Lo que se ofrece y lo que se pide, tal como llega en la acción ProposeTrade.
export type TradeOffer = {
	toId: PlayerId,
	giveCash: number,
	wantCash: number,
	giveSquares: { number },
	wantSquares: { number },
}

-- La oferta guardada: lo anterior más identidad y turno de origen (para la caducidad).
export type TradeRecord = {
	id: string,
	fromId: PlayerId,
	toId: PlayerId,
	giveCash: number,
	wantCash: number,
	giveSquares: { number },
	wantSquares: { number },
	round: number,
	turnIndex: number,
}

-- Fases en las que se puede proponer. Responder admite además AwaitBuy; nada se mueve durante
-- una subasta (R18) y con la partida terminada no se responde nada (GameOver queda fuera).
local PROPOSE_PHASES: { Phase } = { "AwaitRoll", "AwaitEnd" }
local RESPOND_PHASES: { Phase } = { "AwaitRoll", "AwaitBuy", "AwaitEnd" }

local Trade = {}

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
		error(`Trade: no existe el jugador {playerId}`, 3)
	end
	return player
end

-- pending es una tabla persistente que State.create siempre crea; sin ella no hay estado válido.
local function pendingOf(state: GameState): any
	local pending = state.pending
	if not pending then
		error("Trade: el estado no tiene pending", 3)
	end
	return pending
end

local function propertyAt(state: GameState, index: number): PropertyState
	local property = state.properties[index]
	if not property then
		error(`Trade: la casilla {index} no es una propiedad`, 3)
	end
	return property
end

-- Importe admisible: entero y no negativo.
local function isAmount(value: any): boolean
	return type(value) == "number" and value % 1 == 0 and value >= 0
end

local function findTradeIndex(trades: any, tradeId: string): number?
	for index, trade in trades do
		if trade.id == tradeId then
			return index
		end
	end
	return nil
end

-- Motivo por el que una lista de casillas no se puede intercambiar, o nil. `ownerId` es quien
-- debe poseerlas y `foreign` el motivo cuando alguna no es suya.
local function squaresReason(state: GameState, squares: any, ownerId: PlayerId, foreign: string): string?
	if type(squares) ~= "table" then
		return "La lista de casillas no es válida"
	end
	local seen: { [number]: boolean } = {}
	for _, index in squares do
		if type(index) ~= "number" or index % 1 ~= 0 then
			return "La lista de casillas no es válida"
		end
		if seen[index] then
			return "La oferta repite una casilla"
		end
		seen[index] = true
		local property = state.properties[index]
		if not property then
			return `La casilla {index} no es una propiedad`
		end
		if property.ownerId ~= ownerId then
			return foreign
		end
		if property.level > 0 then
			return "No se pueden intercambiar propiedades con edificios"
		end
	end
	return nil
end

-- Revalidación completa de una oferta guardada que se va a aceptar: el estado ha podido cambiar
-- desde que se propuso. El destinatario ya lo comprobó respondReason (existe y está activo).
local function acceptReason(state: GameState, trade: TradeRecord): string?
	local from = findPlayer(state, trade.fromId)
	if not from then
		return `El jugador {trade.fromId} no está en la partida`
	end
	if from.status ~= "Active" then
		return "El otro jugador ya no puede intercambiar"
	end
	local to = playerOf(state, trade.toId)
	if from.cash < trade.giveCash then
		return "El otro jugador ya no tiene efectivo suficiente"
	end
	if to.cash < trade.wantCash then
		return "No tienes efectivo suficiente"
	end
	local reason = squaresReason(
		state,
		trade.giveSquares,
		trade.fromId,
		"El otro jugador ya no posee una de las casillas"
	)
	if reason then
		return reason
	end
	return squaresReason(state, trade.wantSquares, trade.toId, "Ya no posees una de las casillas")
end

-- Motivo por el que una propuesta no es válida, o nil. Lo comparten propose (que rechaza sin
-- mutar) y Engine (que valida antes de llamar al handler): una sola fuente de verdad.
function Trade.proposeReason(state: GameState, fromId: PlayerId, offer: any): string?
	if type(offer) ~= "table" then
		return "La oferta no es válida"
	end
	local player = findPlayer(state, fromId)
	if not player then
		return `El jugador {fromId} no está en la partida`
	end
	if player.status == "Left" then
		return "El jugador ha abandonado la partida"
	end
	if player.status ~= "Active" then
		return "Solo los jugadores activos pueden intercambiar"
	end
	if not table.find(PROPOSE_PHASES, state.phase) then
		return `No se puede proponer un intercambio en la fase {state.phase}`
	end
	if state.players[state.turnIndex].id ~= fromId then
		return "No es tu turno"
	end
	local toId = offer.toId
	if type(toId) ~= "string" then
		return "La oferta no es válida"
	end
	if toId == fromId then
		return "No puedes proponerte un intercambio a ti mismo"
	end
	local to = findPlayer(state, toId)
	if not to then
		return `El jugador {toId} no está en la partida`
	end
	if to.status == "Left" then
		return "El otro jugador ha abandonado la partida"
	end
	if to.status ~= "Active" then
		return "Solo se puede intercambiar con un jugador activo"
	end
	if not isAmount(offer.giveCash) or not isAmount(offer.wantCash) then
		return "Los importes del intercambio no son válidos"
	end
	if offer.giveCash > player.cash then
		return "No tienes efectivo suficiente"
	end
	local reason =
		squaresReason(state, offer.giveSquares, fromId, "No puedes ofrecer una casilla que no es tuya")
	if reason then
		return reason
	end
	reason = squaresReason(
		state,
		offer.wantSquares,
		toId,
		"No puedes pedir una casilla que el otro jugador no tiene"
	)
	if reason then
		return reason
	end
	if offer.giveCash + offer.wantCash == 0 and #offer.giveSquares == 0 and #offer.wantSquares == 0 then
		return "El intercambio no ofrece ni pide nada"
	end
	return nil
end

-- Registra la oferta con un id determinista (T1, T2…) y el turno en que se hizo. Proponer no
-- mueve dinero ni casillas: el intercambio solo ocurre al aceptar.
function Trade.propose(state: GameState, fromId: PlayerId, offer: TradeOffer): ApplyResult
	local reason = Trade.proposeReason(state, fromId, offer)
	if reason then
		return { ok = false, error = reason }
	end
	local pending = pendingOf(state)
	local seq = (pending.tradeSeq or 0) + 1
	pending.tradeSeq = seq
	local record: TradeRecord = {
		id = `T{seq}`,
		fromId = fromId,
		toId = offer.toId,
		giveCash = offer.giveCash,
		wantCash = offer.wantCash,
		giveSquares = table.clone(offer.giveSquares),
		wantSquares = table.clone(offer.wantSquares),
		round = state.round,
		turnIndex = state.turnIndex,
	}
	table.insert(pending.trades, record)
	return { ok = true, events = {} }
end

-- Motivo por el que una respuesta no es válida, o nil. Con accept = true revalida la oferta
-- entera contra el estado actual antes de mover nada.
function Trade.respondReason(state: GameState, playerId: PlayerId, tradeId: any, accept: any): string?
	if not table.find(RESPOND_PHASES, state.phase) then
		return `No se puede responder un intercambio en la fase {state.phase}`
	end
	local player = findPlayer(state, playerId)
	if not player then
		return `El jugador {playerId} no está en la partida`
	end
	if player.status == "Left" then
		return "El jugador ha abandonado la partida"
	end
	if player.status ~= "Active" then
		return "Solo los jugadores activos pueden intercambiar"
	end
	if type(tradeId) ~= "string" then
		return "La oferta no es válida"
	end
	if type(accept) ~= "boolean" then
		return "La respuesta no es válida"
	end
	local pending = pendingOf(state)
	local index = findTradeIndex(pending.trades, tradeId)
	if not index then
		return "La oferta ya no existe"
	end
	local trade = pending.trades[index]
	if trade.toId ~= playerId then
		return "Solo el destinatario puede responder"
	end
	if not accept then
		return nil
	end
	return acceptReason(state, trade)
end

-- Responde a una oferta. Rechazarla solo la elimina; aceptarla canjea el efectivo y las casillas
-- y emite TradeCompleted. Todo lo rechazable se comprueba antes de mutar.
function Trade.respond(state: GameState, playerId: PlayerId, tradeId: string, accept: boolean): ApplyResult
	local reason = Trade.respondReason(state, playerId, tradeId, accept)
	if reason then
		return { ok = false, error = reason }
	end
	local pending = pendingOf(state)
	local index = findTradeIndex(pending.trades, tradeId)
	if not index then
		-- Inalcanzable tras respondReason: la oferta estaba y nada la ha quitado.
		error(`Trade.respond: la oferta {tradeId} desapareció durante la validación`, 2)
	end
	local trade = pending.trades[index]
	local events: { Event } = {}
	if accept then
		local from = playerOf(state, trade.fromId)
		local to = playerOf(state, trade.toId)
		from.cash = from.cash - trade.giveCash + trade.wantCash
		to.cash = to.cash - trade.wantCash + trade.giveCash
		for _, square in trade.giveSquares do
			propertyAt(state, square).ownerId = to.id
		end
		for _, square in trade.wantSquares do
			propertyAt(state, square).ownerId = from.id
		end
		events = { { type = "TradeCompleted", fromId = from.id, toId = to.id, tradeId = trade.id } }
	end
	table.remove(pending.trades, index)
	return { ok = true, events = events }
end

return Trade

--!strict
-- Subasta de una casilla libre. El cierre es explícito: no existe la acción de «pasar» y el
-- tiempo agotado la cerrará en la Tarea 9 a través de Auction.close.
local Board = require("./Board")
local Types = require("./Types")

type GameState = Types.GameState
type PlayerId = Types.PlayerId
type Player = Types.Player
type Event = Types.Event
type ApplyResult = Types.ApplyResult

local Auction = {}

local function findPlayer(state: GameState, playerId: PlayerId): Player?
	for _, player in state.players do
		if player.id == playerId then
			return player
		end
	end
	return nil
end

-- pending es una tabla persistente que State.create siempre crea; sin ella no hay estado válido.
local function pendingOf(state: GameState): any
	local pending = state.pending
	if not pending then
		error("Auction: el estado no tiene pending", 3)
	end
	return pending
end

-- Abre la subasta de una casilla libre. Es un error de programación llamarla sobre una casilla
-- que no es una propiedad o que ya tiene dueño: Engine solo la usa desde AwaitBuy.
function Auction.start(state: GameState, index: number): { Event }
	local pending = pendingOf(state)
	local square = Board.square(state, index)
	if square.kind ~= "Property" then
		error(`Auction.start: la casilla {index} no es una propiedad`, 2)
	end
	local property = state.properties[index]
	if property and property.ownerId then
		error(`Auction.start: la casilla {index} ya tiene dueño`, 2)
	end
	pending.index = index
	pending.auction = { index = index, high = 0, highBidder = nil }
	state.phase = "Auction"
	return { { type = "AuctionStarted", index = index } }
end

-- Motivo por el que una puja no es legal, o nil. Lo comparten bid (que rechaza sin mutar) y
-- Engine (que valida antes de llamar al handler): una sola fuente de verdad.
function Auction.bidReason(state: GameState, playerId: PlayerId, amount: any): string?
	if state.phase ~= "Auction" then
		return `No se puede pujar en la fase {state.phase}`
	end
	local auction = pendingOf(state).auction
	if not auction then
		return "No hay ninguna subasta abierta"
	end
	local player = findPlayer(state, playerId)
	if not player then
		return `El jugador {playerId} no está en la partida`
	end
	if player.status == "Left" then
		return "El jugador ha abandonado la partida"
	end
	if player.status ~= "Active" then
		return "Solo los jugadores activos pueden pujar"
	end
	-- Subir la propia puja no cambia quién gana y oculta a los demás hasta dónde llega el precio.
	if auction.highBidder == playerId then
		return "Ya vas ganando la subasta"
	end
	if type(amount) ~= "number" or amount % 1 ~= 0 then
		return "La puja debe ser un número entero"
	end
	if amount <= auction.high then
		return "La puja debe superar la actual"
	end
	if amount > player.cash then
		return "No tienes efectivo suficiente"
	end
	return nil
end

-- Registra la puja sin cobrar: el dinero se mueve al cerrar. Valida antes de mutar.
function Auction.bid(state: GameState, playerId: PlayerId, amount: number): ApplyResult
	local reason = Auction.bidReason(state, playerId, amount)
	if reason then
		return { ok = false, error = reason }
	end
	local auction = pendingOf(state).auction
	auction.high = amount
	auction.highBidder = playerId
	return { ok = true, events = {} }
end

-- Cierra la subasta: cobra al ganador (el dinero va al banco) y le entrega la casilla, o deja
-- la casilla libre si no hubo pujas. En ambos casos vuelve a AwaitEnd con el mismo turno.
function Auction.close(state: GameState): { Event }
	if state.phase ~= "Auction" then
		error(`Auction.close: no hay ninguna subasta abierta en la fase {state.phase}`, 2)
	end
	local pending = pendingOf(state)
	local auction = pending.auction
	if not auction then
		error("Auction.close: la fase Auction no tiene pending.auction", 2)
	end
	local index = auction.index
	local events: { Event }
	if auction.highBidder then
		local winner = findPlayer(state, auction.highBidder)
		if not winner then
			error(`Auction.close: no existe el jugador {auction.highBidder}`, 2)
		end
		local property = state.properties[index]
		if not property then
			error(`Auction.close: la casilla {index} no tiene estado de propiedad`, 2)
		end
		winner.cash -= auction.high
		property.ownerId = winner.id
		events = { { type = "AuctionWon", index = index, playerId = winner.id, amount = auction.high } }
	else
		events = { { type = "AuctionNoSale", index = index } }
	end
	pending.auction = nil
	pending.index = nil
	state.phase = "AwaitEnd"
	return events
end

return Auction

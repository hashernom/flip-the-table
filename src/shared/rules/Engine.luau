--!strict
-- Punto de entrada del motor: valida la acción, la aplica y devuelve los eventos.
local Board = require("./Board")
local Movement = require("./Movement")
local Property = require("./Property")
local Rng = require("./Rng")
local Turn = require("./Turn")
local Types = require("./Types")

type GameState = Types.GameState
type PlayerId = Types.PlayerId
type Action = Types.Action
type Event = Types.Event
type Phase = Types.Phase

type Handler = (GameState, PlayerId, Action) -> { Event }

-- Una acción y su contrato: fases válidas, quién puede usarla y qué la ejecuta.
type ActionRule = {
	phases: { Phase },
	turnOnly: boolean,
	-- Comprobación extra antes de mutar (efectivo, pending...). nil = sin motivo de rechazo.
	check: ((GameState, PlayerId, Action) -> string?)?,
	handler: Handler,
}

local Engine = {}

local function playerOf(state: GameState, playerId: PlayerId): Types.Player?
	for _, player in state.players do
		if player.id == playerId then
			return player
		end
	end
	return nil
end

local function append(events: { Event }, more: { Event })
	for _, event in more do
		table.insert(events, event)
	end
end

-- Resuelve la casilla pisada. Una propiedad libre abre la compra; la ajena cobra renta; la
-- propia y las demás casillas cierran el turno (los efectos de las especiales llegan en la 03).
local function resolveLanding(state: GameState, playerId: PlayerId): (Phase, { Event })
	local player = playerOf(state, playerId)
	if not player then
		error(`Engine.resolveLanding: no existe el jugador {playerId}`, 2)
	end
	local square = Board.square(state, player.position)
	if square.kind ~= "Property" then
		return "AwaitEnd", {}
	end
	local property = state.properties[square.index]
	if not property or not property.ownerId then
		local pending = state.pending
		if not pending then
			error("Engine.resolveLanding: el estado no tiene pending", 2)
		end
		pending.index = square.index
		return "AwaitBuy", {}
	end
	if property.ownerId == playerId then
		return "AwaitEnd", {}
	end
	return "AwaitEnd", Property.payRent(state, playerId, square.index)
end

-- Roll: dos dados, movimiento de la ficha y resolución de la casilla.
local function roll(state: GameState, playerId: PlayerId, _action: Action): { Event }
	local a = Rng.int(state.rng, 1, 6)
	local b = Rng.int(state.rng, 1, 6)
	local pending = state.pending
	if not pending then
		error("Engine.roll: el estado no tiene pending", 2)
	end
	pending.rolled = { a = a, b = b }

	local events: { Event } = { { type = "DiceRolled", playerId = playerId, a = a, b = b } }
	append(events, Movement.advance(state, playerId, a + b))
	-- Anotación explícita: Luau ensancha la unión de literales al inferir la local.
	local phase: Phase, landingEvents: { Event } = resolveLanding(state, playerId)
	append(events, landingEvents)
	state.phase = phase
	return events
end

-- EndTurn: pasa el turno y deja al siguiente jugador listo para tirar. La Tarea 8 añade
-- aquí la última ronda y el final de la partida.
local function endTurn(state: GameState, _playerId: PlayerId, _action: Action): { Event }
	local events = Turn.next(state)
	state.phase = "AwaitRoll"
	return events
end

-- Motivo por el que Buy no puede aplicarse, o nil. Property.canBuy es la única regla.
local function buyCheck(state: GameState, playerId: PlayerId, _action: Action): string?
	local pending = state.pending
	if not pending or not pending.index then
		return "No hay ninguna propiedad a la venta"
	end
	if not Property.canBuy(state, playerId, pending.index) then
		return "No puedes comprar esta propiedad"
	end
	return nil
end

-- Buy: cobra la propiedad pendiente. Todo lo rechazable se comprueba antes de mutar.
local function buy(state: GameState, playerId: PlayerId, _action: Action): { Event }
	local pending = state.pending
	if not pending or not pending.index then
		error("Engine.buy: la fase AwaitBuy no tiene pending.index", 2)
	end
	local events = Property.buy(state, playerId, pending.index)
	pending.index = nil
	state.phase = "AwaitEnd"
	return events
end

-- DeclineBuy solo necesita que haya una casilla pendiente que subastar.
local function declineBuyCheck(state: GameState, _playerId: PlayerId, _action: Action): string?
	local pending = state.pending
	if not pending or not pending.index then
		return "No hay ninguna propiedad que subastar"
	end
	return nil
end

-- DeclineBuy: abre la subasta conservando la casilla. La Tarea 4 crea Auction y reescribirá
-- este punto para llamar a Auction.start (que además emite AuctionStarted).
local function declineBuy(state: GameState, _playerId: PlayerId, _action: Action): { Event }
	local pending = state.pending
	if not pending or not pending.index then
		error("Engine.declineBuy: la fase AwaitBuy no tiene pending.index", 2)
	end
	pending.auction = { index = pending.index, high = 0, highBidder = nil }
	state.phase = "Auction"
	return {}
end

-- Única fuente de verdad de fases y permisos: la Tarea 9 derivará legalActions de aquí.
-- Las tareas siguientes añaden sus acciones a esta misma tabla.
local rules: { [string]: ActionRule } = {
	Roll = { phases = { "AwaitRoll" }, turnOnly = true, handler = roll },
	Buy = { phases = { "AwaitBuy" }, turnOnly = true, check = buyCheck, handler = buy },
	DeclineBuy = { phases = { "AwaitBuy" }, turnOnly = true, check = declineBuyCheck, handler = declineBuy },
	EndTurn = { phases = { "AwaitEnd" }, turnOnly = true, handler = endTurn },
}

-- Motivo del rechazo, o nil si la acción es legal. No modifica el estado.
local function validate(state: GameState, playerId: PlayerId, action: Action): string?
	local rule = rules[action.type]
	if not rule then
		return `Acción desconocida: {action.type}`
	end
	if state.phase == "GameOver" then
		return "La partida ha terminado"
	end
	local player = playerOf(state, playerId)
	if not player then
		return `El jugador {playerId} no está en la partida`
	end
	if player.status == "Left" then
		return "El jugador ha abandonado la partida"
	end
	if not table.find(rule.phases, state.phase) then
		return `No se puede {action.type} en la fase {state.phase}`
	end
	if rule.turnOnly and playerId ~= state.players[state.turnIndex].id then
		return "No es tu turno"
	end
	if rule.check then
		local reason = rule.check(state, playerId, action)
		if reason then
			return reason
		end
	end
	return nil
end

function Engine.apply(state: GameState, playerId: PlayerId, action: Action): Types.ApplyResult
	local reason = validate(state, playerId, action)
	if reason then
		return { ok = false, error = reason }
	end
	local rule = rules[action.type]
	if not rule then
		-- Inalcanzable tras validate; se mantiene por si las dos tablas se separan.
		return { ok = false, error = `Acción desconocida: {action.type}` }
	end
	return { ok = true, events = rule.handler(state, playerId, action) }
end

return Engine

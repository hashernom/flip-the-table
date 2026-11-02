--!strict
-- Punto de entrada del motor: valida la acción, la aplica y devuelve los eventos.
local Movement = require("./Movement")
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

-- Seam de la Tarea 3: resolver la casilla pisada (comprar o cobrar renta) devolverá sus
-- eventos y la fase siguiente. Hoy ninguna casilla cambia la fase.
local function resolveLanding(_state: GameState, _playerId: PlayerId): (Phase, { Event })
	return "AwaitEnd", {}
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

-- Única fuente de verdad de fases y permisos: la Tarea 9 derivará legalActions de aquí.
-- Las tareas siguientes añaden sus acciones a esta misma tabla.
local rules: { [string]: ActionRule } = {
	Roll = { phases = { "AwaitRoll" }, turnOnly = true, handler = roll },
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

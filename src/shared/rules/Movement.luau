--!strict
-- Mueve la ficha por el tablero y paga la Salida. No resuelve la casilla pisada:
-- esa parte llega con las compras y la renta.
local Economy = require("../config/Economy")
local Types = require("./Types")

type GameState = Types.GameState
type PlayerId = Types.PlayerId

local Movement = {}

local function playerOf(state: GameState, playerId: PlayerId): Types.Player
	for _, player in state.players do
		if player.id == playerId then
			return player
		end
	end
	error(`Movement: no existe el jugador {playerId}`, 3)
end

-- Índice dentro de 1..size. Acepta cualquier entero y da la vuelta en ambos sentidos.
local function wrap(index: number, size: number): number
	return (index - 1) % size + 1
end

-- Casillas pisadas, de la primera a la última.
local function pathOf(from: number, steps: number, size: number): { number }
	local direction = if steps < 0 then -1 else 1
	local path: { number } = {}
	for step = 1, math.abs(steps) do
		table.insert(path, wrap(from + step * direction, size))
	end
	return path
end

function Movement.advance(state: GameState, playerId: PlayerId, steps: number): { Types.Event }
	if steps ~= steps or steps == math.huge or steps == -math.huge or steps ~= math.floor(steps) then
		error(`Movement.advance: los pasos deben ser un entero, no {steps}`, 2)
	end
	local player = playerOf(state, playerId)
	if steps == 0 then
		return {}
	end

	local from = player.position
	local path = pathOf(from, steps, #state.board.squares)
	local to = path[#path]
	local events: { Types.Event } = {
		{ type = "TokenMoved", playerId = playerId, from = from, to = to, path = path },
	}

	-- La ruta incluye la Salida solo cuando se pisa. Retroceder nunca cobra.
	if steps > 0 and table.find(path, 1) then
		player.cash += Economy.startBonus
		table.insert(events, { type = "PassedStart", playerId = playerId, amount = Economy.startBonus })
	end

	player.position = to
	return events
end

return Movement

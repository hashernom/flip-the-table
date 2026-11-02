--!strict
-- Avance del turno. Las rondas, la Corona y el final de la partida llegan en la Tarea 8.
local Types = require("./Types")

type GameState = Types.GameState

local Turn = {}

-- Siguiente jugador que sigue en la partida. Si no queda ninguno, devuelve al actual.
local function nextIndex(state: GameState): number
	local count = #state.players
	local index = state.turnIndex
	for _ = 1, count do
		index = index % count + 1
		if state.players[index].status ~= "Left" then
			return index
		end
	end
	return state.turnIndex
end

function Turn.next(state: GameState): { Types.Event }
	local index = nextIndex(state)
	-- Dar la vuelta al orden abre ronda; con un solo jugador presente también cuenta.
	if index <= state.turnIndex then
		state.round += 1
	end
	state.turnIndex = index
	-- Aquí añadirá la Tarea 8 los eventos de ronda y de final de partida.
	return {}
end

return Turn

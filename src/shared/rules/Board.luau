--!strict
-- Consultas de solo lectura sobre el tablero de una partida en curso.
local Types = require("./Types")

type GameState = Types.GameState
type PlayerId = Types.PlayerId
type Square = Types.Square

local Board = {}

function Board.square(state: GameState, index: number): Square
	local square = state.board.squares[index]
	if not square then
		error(`Board.square: no existe la casilla {index}`, 2)
	end
	return square
end

-- Zona a la que pertenece una casilla, o nil si no es una propiedad. Devuelve una copia: una
-- carta de zona de la fase 03 no puede mutar el tablero a través de la lista.
function Board.zoneOf(state: GameState, index: number): { number }?
	local zoneId = Board.square(state, index).zoneId
	if not zoneId then
		return nil
	end
	local indices = state.board.zones[zoneId]
	if not indices then
		return nil
	end
	return table.clone(indices)
end

function Board.ownsZone(state: GameState, playerId: PlayerId, zoneId: string): boolean
	local indices = state.board.zones[zoneId]
	if not indices or #indices == 0 then
		return false
	end
	for _, index in indices do
		local property = state.properties[index]
		if not property or property.ownerId ~= playerId then
			return false
		end
	end
	return true
end

return Board

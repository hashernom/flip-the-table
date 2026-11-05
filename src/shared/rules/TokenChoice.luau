--!strict
-- Reparto de fichas entre los asientos. Es presentación, no una regla del motor: el servidor solo
-- garantiza que no se repita y que nadie cambie de ficha cuando la partida ya echó a andar.
local Tokens = require("../config/Tokens")

export type Assignments = { [string]: string }

local TokenChoice = {}

-- Reparto inicial: una ficha distinta por asiento, en el orden del catálogo. Nunca se repite mientras
-- haya ocho asientos o menos.
function TokenChoice.defaults(playerIds: { string }): Assignments
	local assignments: Assignments = {}
	for order, playerId in playerIds do
		assignments[playerId] = Tokens.forSeat(order)
	end
	return assignments
end

-- Quién tiene una ficha, o nil si está libre.
function TokenChoice.ownerOf(assignments: Assignments, tokenId: string): string?
	for playerId, chosen in assignments do
		if chosen == tokenId then
			return playerId
		end
	end
	return nil
end

-- Cambia la ficha de un jugador. Falla si la ficha no existe. Si ya es de otro, se intercambian: en
-- una mesa llena (8 asientos) no quedaría ninguna libre y nadie podría elegir. El intercambio mantiene
-- la unicidad: cada jugador sigue teniendo exactamente una ficha.
function TokenChoice.choose(assignments: Assignments, playerId: string, tokenId: string): (boolean, string?)
	if Tokens.get(tokenId) == nil then
		return false, "Esa ficha no existe."
	end
	local owner = TokenChoice.ownerOf(assignments, tokenId)
	if owner == playerId then
		return true, nil
	end
	if owner ~= nil then
		local mine = assignments[playerId]
		if mine == nil then
			return false, "Esa ficha ya es de otro jugador."
		end
		assignments[owner] = mine
	end
	assignments[playerId] = tokenId
	return true, nil
end

-- La elección se cierra en cuanto alguien sale de la Salida: antes de empezar, todos en la casilla 1.
function TokenChoice.locked(positions: { number }): boolean
	for _, position in positions do
		if position ~= 1 then
			return true
		end
	end
	return false
end

return TokenChoice

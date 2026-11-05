--!strict
-- Elección de ficha sin repetir. Cada jugador elige una de las ocho fichas de `Tokens` y ninguna se
-- usa dos veces. Es una regla pura: no toca Roblox, así que se prueba con Lune.
--
-- `choices` guarda la elección de cada jugador humano: `{ [playerId] = tokenId }`. Quien no ha
-- elegido, incluidos los bots, recibe al repartir una ficha libre.
local Tokens = require("../config/Tokens")

export type Choices = { [string]: string }

local TokenRules = {}

-- Elige la ficha `tokenId` para `playerId`. Rechaza un id que no existe y una ficha que ya tiene otro
-- jugador; elegir la que ya tienes es válido y cambiar libera la anterior. Solo muta `choices` si
-- acepta: ante un rechazo, la tabla queda igual.
function TokenRules.choose(choices: Choices, playerId: string, tokenId: string): (boolean, string?)
	if Tokens.byId(tokenId) == nil then
		return false, "Esa ficha no existe"
	end
	for otherId, otherToken in choices do
		if otherId ~= playerId and otherToken == tokenId then
			return false, "Esa ficha ya la eligió otro jugador"
		end
	end
	choices[playerId] = tokenId
	return true, nil
end

-- Reparte una ficha a cada jugador de `playerIds`, en ese orden. Primero da a cada uno su elección
-- válida; si dos jugadores eligieron la misma, gana el primero de la lista. Después da a los demás,
-- bots incluidos, las fichas libres en el orden de `Tokens.all`. Es determinista y tolera un
-- `choices` corrupto: un valor que no es una ficha se trata como si no hubiera elección.
function TokenRules.assign(playerIds: { string }, choices: Choices): { [string]: string }
	local assigned: { [string]: string } = {}
	local taken: { [string]: boolean } = {}
	local source: any = if type(choices) == "table" then choices else {}

	for _, playerId in playerIds do
		local wanted = if type(playerId) == "string" then source[playerId] else nil
		if
			type(wanted) == "string"
			and assigned[playerId] == nil
			and Tokens.byId(wanted) ~= nil
			and not taken[wanted]
		then
			assigned[playerId] = wanted
			taken[wanted] = true
		end
	end

	local nextFree = 1
	for _, playerId in playerIds do
		if type(playerId) == "string" and assigned[playerId] == nil then
			while nextFree <= #Tokens.all and taken[Tokens.all[nextFree].id] do
				nextFree += 1
			end
			local free = Tokens.all[nextFree]
			if free ~= nil then
				assigned[playerId] = free.id
				taken[free.id] = true
			end
		end
	end

	return assigned
end

return TokenRules

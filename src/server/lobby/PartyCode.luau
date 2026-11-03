--!strict
-- Códigos de party: seis caracteres del alfabeto sin 0, O, 1 ni I. Es lógica pura y determinista:
-- el generador entra por parámetro (`Rng`) y no se usa math.random, así que Lune la prueba igual
-- que Roblox (contracts.md, «Códigos de party»).
local Lobby = require("../../shared/config/Lobby")
local Rng = require("../../shared/rules/Rng")

-- Sin 0, O, 1 ni I: un código se lee por voz o por chat y esas letras se confunden entre sí.
local ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"

local PartyCode = {}

-- Código nuevo. Consume el generador que recibe, así que dos llamadas con el mismo estado dan
-- códigos distintos y la misma semilla reproduce la misma secuencia.
function PartyCode.generate(rng: Rng.RngState): string
	local characters: { string } = {}
	for index = 1, Lobby.codeLength do
		local position = Rng.int(rng, 1, #ALPHABET)
		characters[index] = string.sub(ALPHABET, position, position)
	end
	return table.concat(characters)
end

-- Código normalizado o nil si no lo es. Mayúsculas, minúsculas y espacios no importan: se quitan
-- todos los espacios y se pasa a mayúsculas. Cualquier otro símbolo, una longitud distinta o un
-- texto vacío devuelven nil, que el servicio traduce a un mensaje claro.
function PartyCode.normalize(text: string): string?
	if type(text) ~= "string" then
		return nil
	end
	local cleaned = string.upper((string.gsub(text, "%s", "")))
	if #cleaned ~= Lobby.codeLength then
		return nil
	end
	for index = 1, #cleaned do
		local character = string.sub(cleaned, index, index)
		if string.find(ALPHABET, character, 1, true) == nil then
			return nil
		end
	end
	return cleaned
end

return PartyCode

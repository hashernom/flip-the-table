--!strict
-- Catálogo de las ocho fichas: qué malla es cada una y dónde se sube el avatar.
--
-- `forSeat` da el reparto inicial, determinista: el asiento 1 lleva el taxi, el 2 la limusina y así
-- hasta el 8. Luego cada jugador puede cambiarla con `TokenMenu`; `TokenChoice` mantiene que no se
-- repitan y el cliente usa `forSeat` solo mientras no le llega el reparto del servidor.
local ArtAssets = require("./ArtAssets")

export type Token = {
	id: string,
	label: string,
	art: ArtAssets.TokenArt,
}

local ORDER: { string } = {
	"taxi",
	"limusina",
	"moto",
	"deportivo",
	"food-truck",
	"camion-helados",
	"grua",
	"autobus",
}

local LABELS: { [string]: string } = {
	taxi = "Taxi",
	limusina = "Limusina",
	moto = "Moto",
	deportivo = "Deportivo",
	["food-truck"] = "Food truck",
	["camion-helados"] = "Camión de helados",
	grua = "Grúa",
	autobus = "Autobús",
}

local Tokens = {}

Tokens.ORDER = ORDER

-- La ficha por su id, o nil si el id no está en el catálogo.
function Tokens.get(id: string): Token?
	local art = ArtAssets.tokens[id]
	local label = LABELS[id]
	if art == nil or label == nil then
		return nil
	end
	return { id = id, label = label, art = art }
end

function Tokens.all(): { Token }
	local list: { Token } = {}
	for _, id in ORDER do
		local token = Tokens.get(id)
		if token ~= nil then
			table.insert(list, token)
		end
	end
	return list
end

-- Ficha de un asiento (1..8). Se repite el ciclo si hubiera más asientos que fichas.
function Tokens.forSeat(seat: number): string
	local index = (math.max(1, math.floor(seat)) - 1) % #ORDER + 1
	return ORDER[index]
end

return Tokens

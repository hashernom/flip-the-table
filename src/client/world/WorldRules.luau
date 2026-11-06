--!strict
-- Reglas puras de lo que se ve en la ciudad: qué propiedades cambiaron entre dos vistas y en qué sitio
-- va cada ficha. `BuildingView` y `main.client` las aplican; aquí no se toca ninguna pieza, para poder
-- probarlas con Lune.
local CityLayout = require("../../shared/config/CityLayout")

export type PropertyChange = { index: number, ownerId: string?, level: number, mortgaged: boolean? }

local PAINT_DESATURATE = 0.3
local PAINT_DIM = 0.75

local WorldRules = {}

-- Lo que cambió de una vista a otra, en orden de casilla. Se compara el estado y no se escuchan eventos:
-- las ventas por bancarrota y por Huracán no emiten `BuildingChanged` (M11), y una vista de resync no
-- trae eventos. Una casilla que desaparece de la vista vuelve a estar libre.
function WorldRules.propertyChanges(
	previous: { [number]: any }?,
	current: { [number]: any }
): { PropertyChange }
	local before: { [number]: any } = previous or {}
	local changes: { PropertyChange } = {}
	for index, property in current do
		local old = before[index]
		local oldOwner = if old ~= nil then old.ownerId else nil
		local oldLevel = if old ~= nil then old.level else 0
		local oldMortgaged = old ~= nil and old.mortgaged == true
		local mortgaged = property.mortgaged == true
		if property.ownerId ~= oldOwner or property.level ~= oldLevel or mortgaged ~= oldMortgaged then
			table.insert(changes, {
				index = index,
				ownerId = property.ownerId,
				level = property.level,
				mortgaged = if mortgaged then true else nil,
			})
		end
	end
	for index, old in before do
		if current[index] == nil and (old.ownerId ~= nil or old.level ~= 0) then
			table.insert(changes, { index = index, level = 0 })
		end
	end
	table.sort(changes, function(a, b)
		return a.index < b.index
	end)
	return changes
end

-- Color de una casilla pintada en el asfalto, a partir del de su zona: se apaga y se acerca al gris, porque
-- con la luz real un color puro se ve como neón y no como pintura vial. El de la interfaz no cambia.
function WorldRules.paintColor(r: number, g: number, b: number): (number, number, number)
	local gray = (r + g + b) / 3
	local function paint(channel: number): number
		return (channel + (gray - channel) * PAINT_DESATURATE) * PAINT_DIM
	end
	return paint(r), paint(g), paint(b)
end

-- Color de la pintura de una casilla enmarcada. Se aclara si queda demasiado cerca del asfalto: Grafito y Añil
-- se perderían en la calle. El color de la zona no cambia en el resto del juego.
local ROAD_PAINT_MIN_LUMA = 0.5

function WorldRules.roadPaintColor(r: number, g: number, b: number): (number, number, number)
	local luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
	if luma >= ROAD_PAINT_MIN_LUMA then
		return r, g, b
	end
	local lift = (ROAD_PAINT_MIN_LUMA - luma) / (1 - luma)
	return r + (1 - r) * lift, g + (1 - g) * lift, b + (1 - b) * lift
end

-- Etiqueta de una propiedad en la vista general, o nil si no tiene dueño.
function WorldRules.ownerTag(ownerName: string?, level: number): string?
	if ownerName == nil then
		return nil
	end
	return if level > 0 then `{ownerName} · Nivel {level}` else ownerName
end

-- Asiento de un jugador: su orden en la vista, que no cambia durante la partida.
function WorldRules.seatOf(players: { any }, id: string): number?
	for seat, seated in players do
		if seated.id == id then
			return seat
		end
	end
	return nil
end

-- Sitio de cada ficha dentro de su casilla. El orden es el del asiento, así que todos los clientes
-- colocan las fichas igual sin hablar entre ellos.
function WorldRules.tokenOffsets(players: { any }): { [string]: CityLayout.TokenOffset }
	local occupants: { [number]: { string } } = {}
	for _, seated in players do
		local list = occupants[seated.position]
		if list == nil then
			list = {}
			occupants[seated.position] = list
		end
		table.insert(list, seated.id)
	end
	local offsets: { [string]: CityLayout.TokenOffset } = {}
	for _, list in occupants do
		for order, id in list do
			offsets[id] = CityLayout.tokenOffset(order, #list)
		end
	end
	return offsets
end

return WorldRules

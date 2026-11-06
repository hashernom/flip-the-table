--!strict
-- Reglas puras de lo que se ve en la ciudad: qué propiedades cambiaron entre dos vistas y en qué sitio
-- va cada ficha. `BuildingView` y `main.client` las aplican; aquí no se toca ninguna pieza, para poder
-- probarlas con Lune.
local CityLayout = require("../../shared/config/CityLayout")

export type PropertyChange = { index: number, ownerId: string?, level: number, mortgaged: boolean? }

-- Tono de una cifra pintada en la casilla. El color sale de `Ui.squarePrices.tones`; la etiqueta de
-- encima dice qué es cada cifra, así que el color repite la información y nunca la lleva solo.
export type PriceTone = "Buy" | "Rent0" | "Rent1" | "Rent2" | "Hot" | "Alert"
export type PriceCell = { caption: string, amount: number, tone: PriceTone }

local PAINT_DESATURATE = 0.3
local PAINT_DIM = 0.75
-- Nivel desde el que la renta se pinta en rojo: hotel y rascacielos.
local RENT_HOT_LEVEL = 3

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

-- Tono de la renta según el nivel: amarilla sin mejoras, naranja con casas y roja con hotel o más. Cuanto
-- más cálida, más duele caer ahí.
local function rentTone(level: number): PriceTone
	if level >= RENT_HOT_LEVEL then
		return "Rent2"
	elseif level >= 1 then
		return "Rent1"
	end
	return "Rent0"
end

-- La cifra que importa ahora en una casilla de propiedad, una sola: libre, lo que cuesta; con dueño, lo
-- que cobra (en la Zona Caliente, con su etiqueta propia); hipotecada, lo que cuesta deshipotecarla. Las
-- cifras vienen calculadas en la vista. `nil` si la vista no trae cifras.
function WorldRules.priceCell(property: any, hot: boolean?): PriceCell?
	if type(property) ~= "table" or type(property.price) ~= "number" then
		return nil
	end
	if property.ownerId == nil then
		return { caption = "city.price.buy", amount = property.price, tone = "Buy" }
	end
	if property.mortgaged == true then
		return { caption = "city.price.unmortgage", amount = property.unmortgageCost or 0, tone = "Alert" }
	end
	if hot == true then
		return { caption = "city.price.rentHot", amount = property.rent or 0, tone = "Hot" }
	end
	return { caption = "city.price.rent", amount = property.rent or 0, tone = rentTone(property.level or 0) }
end

-- Avance de un recorrido de ficha, de 0 a 1, en el instante `elapsed` de `seconds`. Acelera al arrancar y
-- frena al llegar, pero va a velocidad constante en medio: la ficha no se para en cada casilla.
function WorldRules.rideProgress(elapsed: number, seconds: number, rampShare: number): number
	if seconds <= 0 then
		return 1
	end
	local t = math.clamp(elapsed / seconds, 0, 1)
	local ramp = math.clamp(rampShare, 0, 0.5)
	if ramp <= 0 then
		return t
	end
	-- Perfil de velocidad trapezoidal: sube en `ramp`, se mantiene y baja en el último `ramp`.
	local peak = 1 / (1 - ramp)
	if t < ramp then
		return peak * t * t / (2 * ramp)
	elseif t > 1 - ramp then
		local left = 1 - t
		return 1 - peak * left * left / (2 * ramp)
	end
	return peak * (t - ramp / 2)
end

-- Tramo de una ruta en el que cae `distance`: `cumulative[k]` es la distancia acumulada al final del tramo
-- k. Devuelve el tramo (1-based) y cuánto de él lleva recorrido, de 0 a 1.
function WorldRules.segmentAt(cumulative: { number }, distance: number): (number, number)
	local count = #cumulative
	if count == 0 then
		return 0, 1
	end
	local before = 0
	for index = 1, count do
		local finish = cumulative[index]
		if distance <= finish or index == count then
			local span = finish - before
			if span <= 0 then
				return index, 1
			end
			return index, math.clamp((distance - before) / span, 0, 1)
		end
		before = finish
	end
	return count, 1
end

return WorldRules

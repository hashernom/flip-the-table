--!strict
-- Reglas puras de la maqueta de la vista general: a qué escala se copia la ciudad, dónde se apoya el
-- plinto, qué tarjetas tocan al abrir y dónde va el marcador de cada asiento. No toca `Instance` ni la
-- cámara, así que se prueba con Lune contra vistas salidas de `View`; `ModelCity` solo las pinta.
--
-- La maqueta es de lujo, pero también de exposición: la miniatura ocupa el mismo ancho en los tres
-- tableros, con su plinto centrado en la plaza interior del anillo. Así la vista general se compone
-- igual en una partida de 4 jugadores que en una de 8, y la cámara no depende del tamaño de la ciudad.
local CityLayout = require("../../shared/config/CityLayout")
local Strings = require("../../shared/config/Strings")
local ViewText = require("../ui/ViewText")
local WorldRules = require("./WorldRules")

export type SizeId = CityLayout.SizeId
export type Vector3Like = CityLayout.Vector3Like

-- Nombre que va grabado en las placas del plinto.
local CITY_NAME = "Metrópolis"
-- Ancho del suelo de la miniatura ya escalado, en studs del mundo. Es el mismo en los tres tableros.
local MODEL_SPAN = 240
-- Margen de madera alrededor de la miniatura y altura total del plinto, en studs del mundo.
local PLINTH_MARGIN = 22
local PLINTH_HEIGHT = 14
-- El suelo de `CityBuilder` es una losa de `span + 120` studs, dos de grosor, con su cara superior en
-- `-0,4`: de la calle (y = 0) al fondo de la losa hay 2,4 studs. La maqueta se apoya en ese fondo.
local GROUND_MARGIN = 120
local GROUND_DEPTH = 2.4
local GROUND_TOP = -0.4

export type Plinth = {
	sizeId: SizeId,
	-- Factor por el que se escala la copia de la ciudad.
	scale: number,
	-- Centro del plinto, apoyado en la plaza interior del anillo.
	center: Vector3Like,
	width: number,
	depth: number,
	height: number,
	baseY: number,
	-- Cara superior del plinto, donde se apoya la miniatura.
	deckY: number,
	-- Plano de calle de la miniatura: donde quedan las casillas al escalar.
	surfaceY: number,
	modelSpan: number,
}

export type Card = {
	index: number,
	ownerId: string,
	-- Asiento del dueño en la vista; nil si ya no está sentado.
	seat: number?,
	name: string,
	cash: number,
	level: number,
	-- Línea corta de la tarjeta: dinero y nivel.
	detail: string,
	-- Color de asiento del dueño en `#RRGGBB`, para la franja de la tarjeta.
	color: string,
}

export type CardChanges = {
	added: { Card },
	changed: { Card },
	removed: { number },
}

export type Marker = {
	id: string,
	seat: number,
	-- Casilla en la que está, y su sitio dentro de ella en studs de ciudad.
	square: number,
	side: number,
	along: number,
	color: string,
}

export type Plaque = {
	title: string,
	effect: string?,
}

-- Mismos colores que la franja de cada asiento de `main.client`. La maqueta prefiere el color real de
-- la ficha cuando ya existe; esta lista es el respaldo para un asiento que aún no tiene ficha.
local SEAT_COLORS = {
	"#E65A5A",
	"#5AA0E6",
	"#6EC878",
	"#E6BE50",
	"#B478E6",
	"#5AC8C8",
	"#E68C3C",
	"#C8C8D2",
}

local ModelCityRules = {}

ModelCityRules.CITY_NAME = CITY_NAME
ModelCityRules.MODEL_SPAN_STUDS = MODEL_SPAN
ModelCityRules.PLINTH_MARGIN_STUDS = PLINTH_MARGIN
ModelCityRules.PLINTH_HEIGHT_STUDS = PLINTH_HEIGHT
ModelCityRules.GROUND_DEPTH_STUDS = GROUND_DEPTH
ModelCityRules.GROUND_TOP_STUDS = GROUND_TOP
ModelCityRules.SEAT_COLORS = SEAT_COLORS

-- Ancho del suelo de la ciudad en studs de ciudad, incluida la losa que le pone `CityBuilder`.
function ModelCityRules.groundSpan(sizeId: SizeId): number
	return CityLayout.spanFor(sizeId) + GROUND_MARGIN
end

-- Factor de escala de la miniatura: siempre deja el mismo ancho de exposición.
function ModelCityRules.scaleFor(sizeId: SizeId): number
	return MODEL_SPAN / ModelCityRules.groundSpan(sizeId)
end

-- Plinto de un tamaño de ciudad. Va centrado en la ciudad y apoyado en el suelo de la plaza interior,
-- así que no se cruza con la calle ni con los solares.
function ModelCityRules.plinthFor(sizeId: SizeId): Plinth
	local center = CityLayout.centerFor(sizeId)
	local scale = ModelCityRules.scaleFor(sizeId)
	local deckY = GROUND_TOP + PLINTH_HEIGHT
	return {
		sizeId = sizeId,
		scale = scale,
		center = { x = center.x, y = GROUND_TOP, z = center.z },
		width = MODEL_SPAN + 2 * PLINTH_MARGIN,
		depth = MODEL_SPAN + 2 * PLINTH_MARGIN,
		height = PLINTH_HEIGHT,
		baseY = GROUND_TOP,
		deckY = deckY,
		surfaceY = deckY + GROUND_DEPTH * scale,
		modelSpan = MODEL_SPAN,
	}
end

-- Punto de la ciudad (studs de ciudad) a coordenadas del mundo en la maqueta. La miniatura se coloca
-- centrada en el plinto y con el fondo de su losa sobre la cara superior, que es justo lo que deshace
-- esta cuenta al revés.
function ModelCityRules.modelPoint(plinth: Plinth, x: number, y: number, z: number): Vector3Like
	local center = CityLayout.centerFor(plinth.sizeId)
	return {
		x = plinth.center.x + (x - center.x) * plinth.scale,
		y = plinth.deckY + (y + GROUND_DEPTH) * plinth.scale,
		z = plinth.center.z + (z - center.z) * plinth.scale,
	}
end

function ModelCityRules.seatColor(seat: number): string
	return SEAT_COLORS[(seat - 1) % #SEAT_COLORS + 1]
end

-- Color estable para un dueño que ya no está sentado (o que aún no tiene ficha): sale de su id, así que
-- dos dueños ausentes no comparten el mismo color por defecto.
function ModelCityRules.colorForOwner(ownerId: string): string
	local hash = 0
	for index = 1, #ownerId do
		hash = (hash * 31 + string.byte(ownerId, index)) % #SEAT_COLORS
	end
	return SEAT_COLORS[hash + 1]
end

local function seatOf(players: { any }, id: string): number?
	for seat, seated in players do
		if seated.id == id then
			return seat
		end
	end
	return nil
end

-- Tarjetas de las propiedades con dueño, por número de casilla. Una propiedad libre no tiene tarjeta:
-- la vista no trae ningún dato suyo que merezca una etiqueta sobre la maqueta.
function ModelCityRules.cards(view: any, names: ViewText.Names?): { [number]: Card }
	local cards: { [number]: Card } = {}
	if view == nil or view.properties == nil or view.players == nil then
		return cards
	end
	for index, property in view.properties do
		local ownerId = property.ownerId
		if ownerId == nil then
			continue
		end
		local seat = seatOf(view.players, ownerId)
		local seated = if seat ~= nil then view.players[seat] else nil
		local cash = if seated ~= nil then seated.cash else 0
		local level = property.level or 0
		cards[index] = {
			index = index,
			ownerId = ownerId,
			seat = seat,
			name = ViewText.playerName(view, names, ownerId),
			cash = cash,
			level = level,
			detail = `{cash} · {Strings.buildingLevel(level)}`,
			color = if seat ~= nil
				then ModelCityRules.seatColor(seat)
				else ModelCityRules.colorForOwner(ownerId),
		}
	end
	return cards
end

-- Qué tarjetas hay que crear, actualizar y retirar entre dos vistas. Se compara el contenido, no la
-- tabla: el dinero de un dueño cambia sin que cambie el dueño de la propiedad.
function ModelCityRules.cardDiff(previous: { [number]: Card }?, current: { [number]: Card }): CardChanges
	local before: { [number]: Card } = previous or {}
	local added: { Card } = {}
	local changed: { Card } = {}
	local removed: { number } = {}
	for index, card in current do
		local old = before[index]
		if old == nil then
			table.insert(added, card)
		elseif
			old.ownerId ~= card.ownerId
			or old.name ~= card.name
			or old.cash ~= card.cash
			or old.level ~= card.level
		then
			table.insert(changed, card)
		end
	end
	for index in before do
		if current[index] == nil then
			table.insert(removed, index)
		end
	end
	table.sort(added, function(a: Card, b: Card)
		return a.index < b.index
	end)
	table.sort(changed, function(a: Card, b: Card)
		return a.index < b.index
	end)
	table.sort(removed)
	return { added = added, changed = changed, removed = removed }
end

-- Un marcador por jugador sentado, en su casilla y con el sitio que le toca dentro de ella. El reparto
-- sale de `WorldRules.tokenOffsets`, el mismo de las fichas de la calle, para que la maqueta no invente
-- posiciones propias.
function ModelCityRules.markers(view: any): { Marker }
	local markers: { Marker } = {}
	if view == nil or view.players == nil then
		return markers
	end
	local offsets = WorldRules.tokenOffsets(view.players)
	for seat, seated in view.players do
		local offset = offsets[seated.id]
		table.insert(markers, {
			id = seated.id,
			seat = seat,
			square = seated.position,
			side = if offset ~= nil then offset.side else CityLayout.SLOT_SIDE_STUDS,
			along = if offset ~= nil then offset.along else 0,
			color = ModelCityRules.seatColor(seat),
		})
	end
	return markers
end

-- Efectos activos de un vistazo, sin llenar la placa: la Zona Caliente por su nombre y cuántos efectos
-- de mesa hay. El detalle completo ya está en el panel de la vista general.
function ModelCityRules.effectLine(view: any): string?
	if view == nil then
		return nil
	end
	local parts: { string } = {}
	local zoneId = view.hotZoneId
	if type(zoneId) == "string" then
		local ok: boolean, zone: any = pcall(Strings.zone, zoneId)
		if ok then
			table.insert(parts, `Zona Caliente: {zone.name}`)
		end
	end
	local modifiers = view.modifiers or {}
	if #modifiers > 0 then
		table.insert(parts, if #modifiers == 1 then "1 efecto activo" else `{#modifiers} efectos activos`)
	end
	if #parts == 0 then
		return nil
	end
	return table.concat(parts, " · ")
end

-- Lo que dice la placa del plinto: el nombre de la ciudad y, si los hay, sus efectos activos.
function ModelCityRules.plaque(view: any): Plaque
	return { title = CITY_NAME, effect = ModelCityRules.effectLine(view) }
end

return ModelCityRules

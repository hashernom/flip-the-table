--!strict
-- Reglas puras del minimapa: de una vista salen las celdas del anillo y el detalle de una casilla. Es lo
-- que deja ver todo el tablero aunque la cámara siga a una sola ficha (R-P51). `MiniMap` solo las pinta.
local CityLayout = require("../../shared/config/CityLayout")
local Economy = require("../../shared/config/Economy")
local Property = require("../../shared/rules/Property")
local Strings = require("../../shared/config/Strings")
local Ui = require("../../shared/config/Ui")
local ViewText = require("./ViewText")

export type Cell = {
	index: number,
	-- Sitio en el anillo, de 0 a 1.
	u: number,
	v: number,
	color: string,
	isProperty: boolean,
	-- Tipo de casilla: las especiales pintan su símbolo (el mismo de la calle) sobre el gris.
	kind: string,
	ownerSeat: number?,
	level: number,
	-- Asientos de las fichas que hay en la casilla.
	tokens: { number },
	isTurn: boolean,
}

local MiniMapRules = {}

function MiniMapRules.cells(view: any): { Cell }
	local span = CityLayout.spanFor(view.sizeId)
	local seats: { [string]: number } = {}
	for seat, seated in view.players do
		seats[seated.id] = seat
	end
	local turn = view.players[view.turnIndex]
	local turnPosition = if turn ~= nil then turn.position else nil

	local cells: { Cell } = {}
	for _, slot in CityLayout.routeFor(view.sizeId) do
		local property = view.properties[slot.index]
		local tokens: { number } = {}
		for seat, seated in view.players do
			if seated.position == slot.index then
				table.insert(tokens, seat)
			end
		end
		table.insert(cells, {
			index = slot.index,
			u = slot.position.x / span,
			v = slot.position.z / span,
			color = if slot.kind == "Property"
				then Strings.colorFor({
					index = slot.index,
					kind = slot.kind,
					zoneId = slot.zoneId,
					barrioId = slot.barrioId,
				} :: any)
				else Ui.miniMap.specialColor,
			isProperty = slot.kind == "Property",
			kind = slot.kind :: string,
			ownerSeat = if property ~= nil and property.ownerId ~= nil then seats[property.ownerId] else nil,
			level = if property ~= nil then property.level else 0,
			tokens = tokens,
			isTurn = slot.index == turnPosition,
		})
	end
	return cells
end

-- Lo que se lee al pulsar una casilla. La renta es la que cobraría el motor, no una copia de la fórmula:
-- `rentFor` lee de la vista los mismos campos que del estado.
function MiniMapRules.detailLines(view: any, names: ViewText.Names?, index: number): { string }
	local board = ViewText.board(view.sizeId)
	local square = board.squares[index]
	if square == nil then
		return {}
	end
	local lines = { ViewText.squareName(view, index) }
	local property = view.properties[index]
	if square.kind ~= "Property" or property == nil then
		return lines
	end
	local owner = property.ownerId
	if owner == nil then
		table.insert(lines, "Sin dueño")
		table.insert(lines, `Precio: {square.price}`)
		return lines
	end
	table.insert(lines, `Dueño: {ViewText.playerName(view, names, owner)}`)
	table.insert(lines, Strings.buildingLevel(math.clamp(property.level, 0, Economy.maxBuildingLevel)))
	local state = setmetatable({ board = board }, { __index = view })
	table.insert(lines, `Renta: {Property.rentFor(state :: any, index)}`)
	return lines
end

return MiniMapRules

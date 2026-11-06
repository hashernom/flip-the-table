--!strict
-- Reglas puras de «Gestionar propiedades» (R-P53): qué propiedades recorre el menú, cómo se pasa de una
-- a otra con las flechas y qué enseña cada una. Las acciones legales llegan del servidor ya agrupadas por
-- casilla (`ActionMenuRules.splitManageActions`): un botón solo se activa si su acción es legal.
local Building = require("../../shared/rules/Building")
local Economy = require("../../shared/config/Economy")
local Property = require("../../shared/rules/Property")
local Strings = require("../../shared/config/Strings")
local ViewText = require("./ViewText")

export type Button = { kind: string, label: string, action: any? }
export type Info = {
	index: number,
	name: string,
	zoneName: string,
	zoneColor: string,
	level: number,
	levelText: string,
	rent: number,
	mortgaged: boolean,
	buttons: { Button },
}

local PropertyManagerRules = {}

-- Orden fijo de los botones: construir y vender, hipotecar y levantar.
PropertyManagerRules.KINDS = { "Build", "SellBuilding", "Mortgage", "Unmortgage" }

-- Casillas del jugador, en orden de ruta.
function PropertyManagerRules.owned(view: any, playerId: string): { number }
	local list: { number } = {}
	for index, property in view.properties or {} do
		if property.ownerId == playerId then
			table.insert(list, index)
		end
	end
	table.sort(list)
	return list
end

-- La siguiente (`delta` = 1) o la anterior (-1), dando la vuelta. Sin propiedades, nil. Si la actual ya
-- no está en la lista (la vendió el banco, cambió de dueño), empieza por la primera.
function PropertyManagerRules.step(list: { number }, current: number?, delta: number): number?
	if #list == 0 then
		return nil
	end
	local at = if current ~= nil then table.find(list, current) else nil
	if at == nil then
		return list[1]
	end
	return list[(at - 1 + delta) % #list + 1]
end

local function stateLike(view: any): any
	return { board = ViewText.board(view.sizeId), players = view.players, properties = view.properties }
end

local function costFor(view: any, kind: string, index: number): number
	local state = stateLike(view)
	if kind == "Build" then
		return Building.costOf(state, view.playerId, index)
	elseif kind == "SellBuilding" then
		return Building.sellRefund(state, index)
	elseif kind == "Mortgage" then
		return Building.mortgageValue(state, index)
	end
	return Building.unmortgageCost(state, index)
end

-- Lo que enseña el menú de una casilla, con sus cuatro botones. `actions` son las legales de esa casilla.
function PropertyManagerRules.info(view: any, index: number, actions: { any }?): Info
	local state = stateLike(view)
	local square = state.board.squares[index]
	local property = view.properties[index] or { level = 0 }
	local level = math.clamp(property.level or 0, 0, Economy.maxBuildingLevel)
	local mortgaged = property.mortgaged == true
	local price = square.price or 0
	local rents = Property.rentTable(price)
	local zone = if square.zoneId ~= nil then Strings.zone(square.zoneId) else nil
	local legal: { [string]: any } = {}
	local list: { any } = actions or {}
	for _, action in list do
		legal[action.type] = action
	end
	local buttons: { Button } = {}
	for _, kind in PropertyManagerRules.KINDS do
		table.insert(buttons, {
			kind = kind,
			label = Strings.get(`manage.{kind}`, { amount = costFor(view, kind, index) }),
			action = legal[kind],
		})
	end
	return {
		index = index,
		name = ViewText.squareName(view, index),
		zoneName = if zone ~= nil then zone.name else "",
		zoneColor = if zone ~= nil then zone.color else "#888888",
		level = level,
		levelText = Strings.buildingLevel(level),
		rent = if mortgaged then 0 else rents[level + 1] or 0,
		mortgaged = mortgaged,
		buttons = buttons,
	}
end

return PropertyManagerRules

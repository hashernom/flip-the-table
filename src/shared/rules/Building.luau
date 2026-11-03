--!strict
-- Niveles de edificio: coste, construcción y descenso. La renta de cada nivel la calcula
-- Property.rentFor; aquí no se duplica ningún multiplicador.
local Board = require("./Board")
local Economy = require("../config/Economy")
local Perks = require("./Perks")
local Types = require("./Types")

type GameState = Types.GameState
type PlayerId = Types.PlayerId
type Player = Types.Player
type PropertyState = Types.PropertyState
type Event = Types.Event
type ApplyResult = Types.ApplyResult

local Building = {}

local function findPlayer(state: GameState, playerId: PlayerId): Player?
	for _, player in state.players do
		if player.id == playerId then
			return player
		end
	end
	return nil
end

local function playerOf(state: GameState, playerId: PlayerId): Player
	local player = findPlayer(state, playerId)
	if not player then
		error(`Building: no existe el jugador {playerId}`, 3)
	end
	return player
end

local function propertyAt(state: GameState, index: number): PropertyState
	local property = state.properties[index]
	if not property then
		error(`Building: la casilla {index} no es una propiedad`, 3)
	end
	return property
end

-- Coste de subir un nivel sin perks: 50 % del precio de la casilla, redondeado hacia abajo.
local function baseCostAt(state: GameState, index: number): number
	local square = Board.square(state, index)
	local price = square.price
	if not price then
		error(`Building: la casilla {index} no es una propiedad`, 3)
	end
	return math.floor(price * Economy.buildingCostRate)
end

-- Coste de subir un nivel para un jugador. Constructor descuenta un 20 %; la comprobación de si
-- se puede construir vive en buildReason.
local function costAt(state: GameState, playerId: PlayerId, index: number): number
	local cost = baseCostAt(state, index)
	local player = findPlayer(state, playerId)
	if player and Perks.has(player, "Builder") then
		return math.floor(cost * (1 - Economy.perks.builderCostRate))
	end
	return cost
end

-- Coste de subir un nivel. Es público para que la interfaz y el bot lo muestren sin repetir
-- la fórmula; la comprobación de si se puede construir vive en buildReason.
function Building.costOf(state: GameState, playerId: PlayerId, index: number): number
	return costAt(state, playerId, index)
end

-- Motivo por el que no se puede subir un nivel, o nil. Lo comparten build (que rechaza sin
-- mutar) y Engine (que valida antes de llamar al handler): una sola fuente de verdad.
function Building.buildReason(state: GameState, playerId: PlayerId, index: any): string?
	if type(index) ~= "number" or index % 1 ~= 0 then
		return "La casilla indicada no es válida"
	end
	local player = findPlayer(state, playerId)
	if not player then
		return `El jugador {playerId} no está en la partida`
	end
	if player.status ~= "Active" then
		return "Solo los jugadores activos pueden construir"
	end
	local square = state.board.squares[index]
	if not square or square.kind ~= "Property" then
		return "La casilla no es una propiedad"
	end
	local property = propertyAt(state, index)
	if property.ownerId ~= playerId then
		return "No eres el dueño de esta propiedad"
	end
	local zoneId = square.zoneId
	if not zoneId or not Board.ownsZone(state, playerId, zoneId) then
		return "Necesitas la zona completa para construir"
	end
	if property.level >= Economy.maxBuildingLevel then
		return "La propiedad ya está al nivel máximo"
	end
	if player.cash < costAt(state, playerId, index) then
		return "No tienes efectivo suficiente"
	end
	return nil
end

-- Sube un nivel y cobra el coste al banco. Valida antes de mutar: si algo falla no toca nada
-- y nunca deja el efectivo por debajo de cero.
function Building.build(state: GameState, playerId: PlayerId, index: number): ApplyResult
	local reason = Building.buildReason(state, playerId, index)
	if reason then
		return { ok = false, error = reason }
	end
	local player = playerOf(state, playerId)
	local property = propertyAt(state, index)
	local from = property.level
	-- Constructor: el coste que se cobra lleva su descuento (costAt). Se cuenta el uso real, no
	-- las consultas de precio.
	if Perks.has(player, "Builder") then
		Perks.recordUse(state, playerId, "Builder")
	end
	player.cash -= costAt(state, playerId, index)
	property.level = from + 1
	return {
		ok = true,
		events = { { type = "BuildingChanged", index = index, from = from, to = property.level } },
	}
end

-- Baja un nivel sin devolver dinero. En el nivel 0 no hace nada. La usarán las cartas de la
-- fase 03 (Terremoto, Demolición) sobre propiedades propias o ajenas.
function Building.lower(state: GameState, index: number): { Event }
	local property = propertyAt(state, index)
	if property.level <= 0 then
		return {}
	end
	local from = property.level
	property.level = from - 1
	return { { type = "BuildingChanged", index = index, from = from, to = property.level } }
end

return Building

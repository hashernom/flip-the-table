--!strict
-- Reglas de propiedad: renta, compra y cobro. La subasta llega en la Tarea 4.
local Bankruptcy = require("./Bankruptcy")
local Board = require("./Board")
local Economy = require("../config/Economy")
local Types = require("./Types")

type GameState = Types.GameState
type PlayerId = Types.PlayerId
type Player = Types.Player
type Event = Types.Event

-- El contrato fija ×2 para cada efecto dinámico. Economy no expone una clave para estos
-- factores y esta tarea no puede tocarlo; si algún día se ajustan, su sitio es Economy.
local EFFECT_DOUBLE = 2

local Property = {}

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
		error(`Property: no existe el jugador {playerId}`, 3)
	end
	return player
end

local function propertyAt(state: GameState, index: number): Types.PropertyState
	local property = state.properties[index]
	if not property then
		error(`Property: la casilla {index} no es una propiedad`, 3)
	end
	return property
end

-- Multiplicador de los efectos dinámicos, acotado al máximo de Economy. No incluye la
-- zona completa ni los edificios: eso es estructura, no efecto.
function Property.rentMultiplier(state: GameState, index: number): number
	local square = Board.square(state, index)
	local multiplier = 1
	-- Rondas finales: solo con tope de rondas (en Sin Fin maxRounds es nil).
	-- SEAM Tarea 8: sustituir esta condición por Turn.isFinalRound(state).
	if state.maxRounds ~= nil and state.round >= state.maxRounds - Economy.finalRoundsCount + 1 then
		multiplier *= EFFECT_DOUBLE
	end
	-- SEAM Tarea 8: aquí entrará la presión de Sin Fin (×2 desde pressureFromRound).
	-- state.hotZoneId lo mantiene la Tarea 03; no hay modificador de Zona Caliente.
	if state.hotZoneId ~= nil and square.zoneId == state.hotZoneId then
		multiplier *= EFFECT_DOUBLE
	end
	-- No se filtra por untilRound: la caducidad de los modificadores es de la Tarea 03.
	for _, modifier in state.modifiers do
		if modifier.kind == "Inflation" then
			multiplier *= EFFECT_DOUBLE
		elseif modifier.kind == "Blackout" then
			if modifier.zoneId ~= nil and modifier.zoneId == square.zoneId then
				multiplier = 0
			end
		elseif modifier.kind == "Haunt" then
			if modifier.index ~= nil and modifier.index == index then
				multiplier = 0
			end
		end
	end
	return math.min(multiplier, Economy.maxRentMultiplier)
end

-- Renta completa de una casilla para su dueño, redondeada hacia abajo.
function Property.rentFor(state: GameState, index: number): number
	local square = Board.square(state, index)
	local price = square.price
	if not price then
		error(`Property.rentFor: la casilla {index} no es una propiedad`, 2)
	end
	local property = propertyAt(state, index)
	local zoneMultiplier = 1
	if property.ownerId and square.zoneId and Board.ownsZone(state, property.ownerId, square.zoneId) then
		zoneMultiplier = Economy.completeZoneRentMultiplier
	end
	local buildingMultiplier = 1
	if property.level > 0 then
		buildingMultiplier = Economy.buildingRentMultiplier[property.level]
	end
	return math.floor(
		price
			* Economy.baseRentRate
			* zoneMultiplier
			* buildingMultiplier
			* Property.rentMultiplier(state, index)
	)
end

-- Predicado único de compra. Lo usa Engine y la Tarea 9 lo reutilizará en legalActions:
-- así el motor, la interfaz y el bot no duplican la regla.
function Property.canBuy(state: GameState, playerId: PlayerId, index: number, price: number?): boolean
	local player = findPlayer(state, playerId)
	if not player or player.status ~= "Active" then
		return false
	end
	local square = state.board.squares[index]
	if not square or square.kind ~= "Property" then
		return false
	end
	local property = state.properties[index]
	if not property or property.ownerId then
		return false
	end
	local cost = price or square.price
	if not cost then
		return false
	end
	return player.cash >= cost
end

-- Compra directa: asume que canBuy ya dio el visto bueno.
function Property.buy(state: GameState, playerId: PlayerId, index: number, price: number?): { Event }
	local square = Board.square(state, index)
	local cost = price or square.price
	if not cost then
		error(`Property.buy: la casilla {index} no es una propiedad`, 2)
	end
	local property = propertyAt(state, index)
	if property.ownerId then
		error(`Property.buy: la casilla {index} ya tiene dueño`, 2)
	end
	local player = playerOf(state, playerId)
	player.cash -= cost
	property.ownerId = playerId
	return { { type = "PropertyBought", playerId = playerId, index = index, price = cost } }
end

-- Cobra la renta de una casilla pisada. R9: un espectro no paga ni cobra renta. La deuda se
-- resuelve con Bankruptcy.charge: si el pagador no puede cubrirla, vende bienes o queda Ghost.
function Property.payRent(state: GameState, payerId: PlayerId, index: number): { Event }
	local ownerId = propertyAt(state, index).ownerId
	if not ownerId or ownerId == payerId then
		return {}
	end
	local owner = playerOf(state, ownerId)
	local payer = playerOf(state, payerId)
	if owner.status == "Ghost" or payer.status == "Ghost" then
		return {}
	end
	local amount = Property.rentFor(state, index)
	-- R16: una renta de 0 no emite RentPaid.
	if amount == 0 then
		return {}
	end
	local events: { Event } = Bankruptcy.charge(state, payerId, amount, ownerId)
	table.insert(events, 1, {
		type = "RentPaid",
		index = index,
		from = payerId,
		to = ownerId,
		amount = amount,
	})
	return events
end

return Property

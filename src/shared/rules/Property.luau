--!strict
-- Reglas de propiedad: renta, compra y cobro.
local Bankruptcy = require("./Bankruptcy")
local Board = require("./Board")
local Comeback = require("./Comeback")
local Economy = require("../config/Economy")
local Pact = require("./Pact")
local Perks = require("./Perks")
local Reaction = require("./Reaction")
local Turn = require("./Turn")
local Types = require("./Types")

type GameState = Types.GameState
type PlayerId = Types.PlayerId
type Player = Types.Player
type Event = Types.Event

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
	-- Rondas finales (solo Rounds) y presión de Sin Fin: efectos del calendario de la partida.
	if Turn.isFinalRound(state) then
		multiplier *= Economy.finalRoundsRentMultiplier
	end
	if Turn.isPressureRound(state) then
		multiplier *= Economy.pressureRentMultiplier
	end
	-- state.hotZoneId lo mantiene HotZone (Tarea 8); no hay modificador de Zona Caliente.
	if state.hotZoneId ~= nil and square.zoneId == state.hotZoneId then
		multiplier *= Economy.hotZoneRentMultiplier
	end
	-- Un modificador creado en la ronda R con duración D sigue activo en R … R+D−1: untilRound es
	-- su última ronda activa y desde R+D se ignora.
	for _, modifier in state.modifiers do
		if modifier.untilRound >= state.round then
			if modifier.kind == "Inflation" then
				multiplier *= Economy.inflationRentMultiplier
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
	end
	-- Casero: las rentas del dueño suben un 15 %. Es un efecto dinámico, así que entra en el tope
	-- de Economy.maxRentMultiplier (R5).
	local property = state.properties[index]
	local ownerId = if property then property.ownerId else nil
	if ownerId then
		local owner = findPlayer(state, ownerId)
		if owner and Perks.has(owner, "Landlord") then
			multiplier *= 1 + Economy.perks.landlordRentRate
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

-- Descuento pendiente del jugador. Es un conjunto por jugador (pending.discounts): dos jugadores
-- pueden tener el suyo sin gastar a la vez y ninguno cancela el del otro.
local function hasDiscount(state: GameState, playerId: PlayerId): boolean
	local pending = state.pending
	local discounts = pending and pending.discounts
	return discounts ~= nil and discounts[playerId] == true
end

-- Gasta la marca de Descuento del jugador. Idempotente: sin marca no hace nada.
local function consumeDiscount(state: GameState, playerId: PlayerId)
	local pending = state.pending
	local discounts = pending and pending.discounts
	if discounts then
		discounts[playerId] = nil
	end
end

-- Precio de compra de una casilla para un jugador. La carta Descuento deja su marca en
-- pending.discounts y la consume la compra directa (nunca una subasta): aquí vive la única
-- fórmula, compartida por canBuy, buy y la interfaz.
function Property.priceFor(state: GameState, playerId: PlayerId, index: number): number
	local price = Board.square(state, index).price
	if not price then
		error(`Property.priceFor: la casilla {index} no es una propiedad`, 2)
	end
	if hasDiscount(state, playerId) then
		return math.floor(price * Economy.cards.discountMultiplier)
	end
	return price
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
	local cost = price or Property.priceFor(state, playerId, index)
	return player.cash >= cost
end

-- Compra directa: asume que canBuy ya dio el visto bueno. Sin precio explícito usa el mismo
-- Property.priceFor que canBuy y consume el Descuento del comprador en la misma operación, así
-- el invariante se cumple llame quien llame. Con precio explícito manda el llamador.
function Property.buy(state: GameState, playerId: PlayerId, index: number, price: number?): { Event }
	local appliesDiscount = price == nil and hasDiscount(state, playerId)
	local cost = price or Property.priceFor(state, playerId, index)
	local property = propertyAt(state, index)
	if property.ownerId then
		error(`Property.buy: la casilla {index} ya tiene dueño`, 2)
	end
	local player = playerOf(state, playerId)
	player.cash -= cost
	property.ownerId = playerId
	if appliesDiscount then
		consumeDiscount(state, playerId)
	end
	return { { type = "PropertyBought", playerId = playerId, index = index, price = cost } }
end

-- Cobra una renta ya calculada: transfiere el importe del pagador al dueño y emite RentPaid.
-- Es la parte de payRent que va después de calcular la renta, sin abrir ninguna ventana de
-- reacción: la usan payRent (sin carta) y la resolución de Renta Rebotada (con un tercero), que
-- nunca puede encadenar otra ventana. Una renta de 0 no emite RentPaid (R16). R-P45: la renta
-- desviada a un tercero también respeta el pacto, así que un socio del dueño no la paga.
function Property.chargeRent(
	state: GameState,
	payerId: PlayerId,
	ownerId: PlayerId,
	index: number,
	amount: number
): { Event }
	if Pact.exemptsRent(state, payerId, ownerId) then
		return {}
	end
	if amount == 0 then
		return {}
	end
	-- R-P50: el liderazgo de la Furia se lee antes de mover el dinero, así la misma renta cuenta
	-- igual sin depender de si el cobro cambia la clasificación.
	local leaderBefore = Comeback.leaderId(state)
	local events: { Event } = Bankruptcy.charge(state, payerId, amount, ownerId)
	-- Contadores de los premios del final (Tarea 10). Se suman por renta cobrada, no por importe:
	-- son recuentos de lo que pasó en la partida. El cobro ya pasó por Bankruptcy.charge, así que
	-- un pagador arruinado también queda contado (pagó lo que pudo).
	local payerStats = state.stats[payerId]
	if payerStats then
		payerStats.rentsPaid = (payerStats.rentsPaid or 0) + 1
	end
	local ownerStats = state.stats[ownerId]
	if ownerStats then
		ownerStats.rentsCollected = (ownerStats.rentsCollected or 0) + 1
	end
	table.insert(events, 1, {
		type = "RentPaid",
		index = index,
		from = payerId,
		to = ownerId,
		amount = amount,
	})
	-- Tarea 9: una renta pagada por quien no lidera suma Furia. Es el único camino de renta: el
	-- directo y el rebotado.
	for _, event in Comeback.onRentPaid(state, payerId, leaderBefore) do
		table.insert(events, event)
	end
	return events
end

-- Cobra la renta de una casilla pisada. R9: un espectro no paga ni cobra renta. La deuda se
-- resuelve con Bankruptcy.charge: si el pagador no puede cubrirla, vende bienes o queda Ghost.
-- Tarea 5: si el pagador lleva Renta Rebotada se abre la ventana y el cobro queda en suspenso
-- hasta que la ventana decida; sin la carta se cobra en el acto.
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
	-- Un pacto vivo exime de renta a los dos socios (Tarea 8): no hay cobro ni ventana de
	-- reacción, porque no hay renta que rebotar.
	if Pact.exemptsRent(state, payerId, ownerId) then
		return {}
	end
	local amount = Property.rentFor(state, index)
	-- R16: una renta de 0 no emite RentPaid.
	if amount == 0 then
		return {}
	end
	Reaction.open(
		state,
		{ kind = "Rent", index = index, payerId = payerId, ownerId = ownerId, amount = amount },
		{ kind = "Rent", index = index, payerId = payerId, ownerId = ownerId, amount = amount }
	)
	if state.phase == "Reaction" then
		return {}
	end
	return Property.chargeRent(state, payerId, ownerId, index, amount)
end

return Property

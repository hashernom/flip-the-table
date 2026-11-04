--!strict
local Harness = require("../harness")
local Board = require("../../src/shared/rules/Board")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Property = require("../../src/shared/rules/Property")
local Types = require("../../src/shared/rules/Types")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function inTurn(state: Types.GameState): Types.Player
	return state.players[state.turnIndex]
end

-- Exige un rechazo y devuelve el mensaje para poder comprobarlo.
local function rejected(result: Types.ApplyResult): string
	if result.ok then
		error("se esperaba un rechazo y la acción se aplicó", 3)
	end
	expect(result.error ~= "").toBe(true)
	return result.error
end

local function priceOf(state: Types.GameState, index: number): number
	local price = state.board.squares[index].price
	if not price then
		error(`la casilla {index} no tiene precio`, 2)
	end
	return price
end

-- Primera propiedad del tablero con el precio indicado. La escalera de la arquitectura solo usa
-- los extremos de la tabla (60 y 400), que existen en cualquier tamaño.
local function propertyOfPrice(state: Types.GameState, price: number): number
	for _, square in state.board.squares do
		if square.kind == "Property" and square.price == price then
			return square.index
		end
	end
	error(`no hay ninguna propiedad de precio {price}`, 2)
end

local function zoneOf(state: Types.GameState, index: number): { number }
	local zone = Board.zoneOf(state, index)
	if not zone then
		error(`la casilla {index} no tiene zona`, 2)
	end
	return zone
end

local function zoneIdOf(state: Types.GameState, index: number): string
	local zoneId = state.board.squares[index].zoneId
	if not zoneId then
		error(`la casilla {index} no tiene zona`, 2)
	end
	return zoneId
end

-- El contrato fija pending como tabla persistente que State.create siempre crea.
local function pendingOf(state: Types.GameState): any
	local pending = state.pending
	if not pending then
		error("el estado no tiene pending", 2)
	end
	return pending
end

-- Deja al jugador en `from`, fuerza los dados y aplica Roll.
local function rollFrom(
	state: Types.GameState,
	playerId: Types.PlayerId,
	from: number,
	first: number,
	second: number
): { Types.Event }
	Fixtures.turnOf(state, playerId)
	Fixtures.placeOn(state, playerId, from)
	Fixtures.dice(state, first, second)
	local result = Engine.apply(state, playerId, { type = "Roll" })
	if not result.ok then
		error(result.error, 2)
	end
	return result.events
end

-- Deja la partida en AwaitBuy sobre `index`, con el turno del jugador indicado.
local function awaitingBuy(state: Types.GameState, playerId: Types.PlayerId, index: number)
	Fixtures.turnOf(state, playerId)
	state.phase = "AwaitBuy"
	pendingOf(state).index = index
end

local function addModifier(state: Types.GameState, modifier: Types.Modifier)
	table.insert(state.modifiers, modifier)
end

describe("Property.rentFor", function()
	it("cobra la renta base del 10 % del precio", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a.id, idx)
		expect(Property.rentFor(s, idx)).toBe(math.floor(priceOf(s, idx) * Economy.baseRentRate))
	end)

	it("duplica la renta con el grupo completo", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local idx = Fixtures.squareOf(s, "Property")
		local zone = zoneOf(s, idx)
		local base = math.floor(priceOf(s, idx) * Economy.baseRentRate)
		-- La zona tiene 2 o 3 propiedades: se entregan todas menos la última.
		for position = 1, #zone - 1 do
			Fixtures.give(s, a.id, zone[position])
		end
		expect(Property.rentFor(s, idx)).toBe(base)
		Fixtures.give(s, a.id, zone[#zone])
		expect(Property.rentFor(s, idx)).toBe(base * Economy.completeZoneRentMultiplier)
	end)

	it("no da zona completa si el grupo está repartido", function()
		local s = Fixtures.game({ players = 3 })
		local a, b = s.players[1], s.players[2]
		local idx = Fixtures.squareOf(s, "Property")
		local zone = zoneOf(s, idx)
		for position = 1, #zone - 1 do
			Fixtures.give(s, a.id, zone[position])
		end
		Fixtures.give(s, b.id, zone[#zone])
		expect(Property.rentFor(s, idx)).toBe(math.floor(priceOf(s, idx) * Economy.baseRentRate))
	end)

	it("aplica el multiplicador de edificios", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local idx = Fixtures.squareOf(s, "Property")
		local base = math.floor(priceOf(s, idx) * Economy.baseRentRate)
		Fixtures.give(s, a.id, idx)
		for level = 1, Economy.maxBuildingLevel do
			s.properties[idx].level = level
			expect(Property.rentFor(s, idx)).toBe(base * Economy.buildingRentMultiplier[level])
		end
	end)

	it("señala una casilla que no es una propiedad", function()
		local s = Fixtures.game({ players = 2 })
		expect(function()
			Property.rentFor(s, Fixtures.squareOf(s, "Start"))
		end).toThrow()
	end)
end)

-- Escalera literal de docs/02-mvp/contenido-tablero.md: renta con el precio 60 y 400 en cada
-- nivel, con la zona completa (columna «Renta en 60/400») y sin ella (la mitad, porque la zona
-- aporta el × 2 de la arquitectura).
type LadderStep = { level: number, zone: { [number]: number }, bare: { [number]: number } }

local LADDER: { LadderStep } = {
	{ level = 0, zone = { [60] = 12, [400] = 80 }, bare = { [60] = 6, [400] = 40 } },
	{ level = 1, zone = { [60] = 24, [400] = 160 }, bare = { [60] = 12, [400] = 80 } },
	{ level = 2, zone = { [60] = 36, [400] = 240 }, bare = { [60] = 18, [400] = 120 } },
	{ level = 3, zone = { [60] = 60, [400] = 400 }, bare = { [60] = 30, [400] = 200 } },
	{ level = 4, zone = { [60] = 96, [400] = 640 }, bare = { [60] = 48, [400] = 320 } },
	{ level = 5, zone = { [60] = 144, [400] = 960 }, bare = { [60] = 72, [400] = 480 } },
}

describe("Property.rentFor: escalera de la arquitectura", function()
	for _, step in LADDER do
		it(`nivel {step.level}`, function()
			local s = Fixtures.game({ players = 2 })
			local owner = s.players[1]
			for _, price in { 60, 400 } do
				local idx = propertyOfPrice(s, price)
				s.properties[idx].level = step.level
				-- Sin zona completa, la renta es la mitad de la columna de la arquitectura.
				expect(Property.rentFor(s, idx)).toBe(step.bare[price])
				-- Con las 2 o 3 propiedades de la zona, se aplica el × 2.
				for _, member in zoneOf(s, idx) do
					Fixtures.give(s, owner.id, member)
				end
				expect(Property.rentFor(s, idx)).toBe(step.zone[price])
			end
		end)
	end
end)

describe("Property.rentMultiplier", function()
	it("empieza en 1", function()
		local s = Fixtures.game({ players = 2 })
		expect(Property.rentMultiplier(s, Fixtures.squareOf(s, "Property"))).toBe(1)
	end)

	it("duplica en las rondas finales", function()
		local s = Fixtures.game({ players = 8 })
		local idx = Fixtures.squareOf(s, "Property")
		s.round = (s.maxRounds :: number) - Economy.finalRoundsCount
		expect(Property.rentMultiplier(s, idx)).toBe(1)
		s.round += 1
		expect(Property.rentMultiplier(s, idx)).toBe(2)
	end)

	it("no duplica en Sin Fin, sin tope de rondas", function()
		local s = Fixtures.game({ players = 8, endMode = "Endless" })
		local idx = Fixtures.squareOf(s, "Property")
		expect(s.maxRounds).toBe(nil)
		-- Muy por encima del tope de Rounds (12) y aún antes de la presión de Sin Fin.
		s.round = Economy.pressureFromRound - 1
		expect(Property.rentMultiplier(s, idx)).toBe(1)
	end)

	it("suma cada Inflación", function()
		local s = Fixtures.game({ players = 2 })
		local idx = Fixtures.squareOf(s, "Property")
		addModifier(s, { kind = "Inflation", untilRound = 99 })
		expect(Property.rentMultiplier(s, idx)).toBe(2)
		addModifier(s, { kind = "Inflation", untilRound = 99 })
		expect(Property.rentMultiplier(s, idx)).toBe(4)
	end)

	it("ignora los modificadores caducados", function()
		local s = Fixtures.game({ players = 2 })
		local idx = Fixtures.squareOf(s, "Property")
		s.round = 3
		addModifier(s, { kind = "Inflation", untilRound = 2 })
		expect(Property.rentMultiplier(s, idx)).toBe(1)
		addModifier(s, { kind = "Inflation", untilRound = 3 })
		expect(Property.rentMultiplier(s, idx)).toBe(2)
	end)

	it("duplica en la zona caliente", function()
		local s = Fixtures.game({ players = 2 })
		local idx = Fixtures.squareOf(s, "Property")
		s.hotZoneId = zoneIdOf(s, idx)
		expect(Property.rentMultiplier(s, idx)).toBe(2)
		s.hotZoneId = s.board.zoneOrder[2]
		expect(Property.rentMultiplier(s, idx)).toBe(1)
	end)

	it("anula la renta con un Huelga en su zona", function()
		local s = Fixtures.game({ players = 2 })
		local idx = Fixtures.squareOf(s, "Property")
		addModifier(s, { kind = "Strike", zoneId = s.board.zoneOrder[2], untilRound = 99 })
		expect(Property.rentMultiplier(s, idx)).toBe(1)
		addModifier(s, { kind = "Strike", zoneId = zoneIdOf(s, idx), untilRound = 99 })
		expect(Property.rentMultiplier(s, idx)).toBe(0)
	end)

	it("anula la renta con una Aparición en su casilla", function()
		local s = Fixtures.game({ players = 2 })
		local idx = Fixtures.squareOf(s, "Property")
		addModifier(s, { kind = "Haunt", index = idx + 1, untilRound = 99 })
		expect(Property.rentMultiplier(s, idx)).toBe(1)
		addModifier(s, { kind = "Haunt", index = idx, untilRound = 99 })
		expect(Property.rentMultiplier(s, idx)).toBe(0)
	end)

	it("nunca supera el máximo de × 4", function()
		local s = Fixtures.game({ players = 8 })
		local idx = Fixtures.squareOf(s, "Property")
		s.round = s.maxRounds :: number
		addModifier(s, { kind = "Inflation", untilRound = 99 })
		addModifier(s, { kind = "Inflation", untilRound = 99 })
		s.hotZoneId = zoneIdOf(s, idx)
		expect(Property.rentMultiplier(s, idx)).toBe(Economy.maxRentMultiplier)
		expect(Property.rentFor(s, idx)).toBe(
			math.floor(priceOf(s, idx) * Economy.baseRentRate * Economy.maxRentMultiplier)
		)
	end)

	it("el Casero suma su 15 % por encima del tope (R-P54)", function()
		local s = Fixtures.game({ players = 8 })
		local owner = s.players[1]
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, owner.id, idx)
		-- Rondas finales ×2 y Zona Caliente ×2 ya llenan el tope de ×4.
		s.round = s.maxRounds :: number
		s.hotZoneId = zoneIdOf(s, idx)
		expect(Property.rentMultiplier(s, idx)).toBe(Economy.maxRentMultiplier)

		-- El perk se aplica después del tope: no se pierde cuando los efectos ya llegaron a ×4.
		table.insert(owner.perks, "Landlord")
		local boosted = Economy.maxRentMultiplier * (1 + Economy.perks.landlordRentRate)
		expect(Property.rentMultiplier(s, idx)).toBe(boosted)
		expect(Property.rentFor(s, idx)).toBe(math.floor(priceOf(s, idx) * Economy.baseRentRate * boosted))
	end)
end)

describe("Property.payRent", function()
	it("cobra el 10 % del precio", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1].id, s.players[2].id
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a, idx)
		local rent = (s.board.squares[idx].price :: number) * 0.1
		Property.payRent(s, b, idx)
		expect(s.players[1].cash).toBe(1500 + rent)
		expect(s.players[2].cash).toBe(1500 - rent)
	end)

	it("emite RentPaid con el importe cobrado", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		local idx = Fixtures.squareOf(s, "Property")
		local amount = math.floor(priceOf(s, idx) * Economy.baseRentRate)
		Fixtures.give(s, a.id, idx)
		expect(Property.payRent(s, b.id, idx)).toEqual({
			{ type = "RentPaid", index = idx, from = b.id, to = a.id, amount = amount },
		})
	end)

	it("no mueve dinero si un efecto anula la renta", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a.id, idx)
		addModifier(s, { kind = "Haunt", index = idx, untilRound = 99 })
		expect(Property.rentFor(s, idx)).toBe(0)
		-- R16: una renta de 0 no emite RentPaid.
		expect(Property.payRent(s, b.id, idx)).toEqual({})
		expect(a.cash).toBe(Economy.startingCash)
		expect(b.cash).toBe(Economy.startingCash)
	end)

	it("no cobra si la casilla está libre", function()
		local s = Fixtures.game({ players = 2 })
		local payer = s.players[2]
		local idx = Fixtures.squareOf(s, "Property")
		expect(Property.payRent(s, payer.id, idx)).toEqual({})
		expect(s.players[1].cash).toBe(Economy.startingCash)
		expect(payer.cash).toBe(Economy.startingCash)
	end)

	it("no cobra al dueño de la propiedad", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a.id, idx)
		expect(Property.payRent(s, a.id, idx)).toEqual({})
		expect(a.cash).toBe(Economy.startingCash)
	end)

	it("no cobra si el dueño es un fantasma", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a.id, idx)
		a.status = "Ghost"
		expect(Property.payRent(s, b.id, idx)).toEqual({})
		expect(a.cash).toBe(Economy.startingCash)
		expect(b.cash).toBe(Economy.startingCash)
	end)

	it("no cobra a un fantasma", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a.id, idx)
		b.status = "Ghost"
		expect(Property.payRent(s, b.id, idx)).toEqual({})
		expect(a.cash).toBe(Economy.startingCash)
		expect(b.cash).toBe(Economy.startingCash)
	end)
end)

describe("Property.payRent: contadores de premios", function()
	it("suma rentsPaid y rentsCollected por una renta cobrada", function()
		local s = Fixtures.game({ players = 2 })
		local owner, payer = s.players[1], s.players[2]
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, owner.id, idx)

		Property.payRent(s, payer.id, idx)

		expect(s.stats[payer.id].rentsPaid).toBe(1)
		expect(s.stats[owner.id].rentsCollected).toBe(1)
	end)

	it("no suma nada si un pacto exime de la renta", function()
		local s = Fixtures.game({ players = 2 })
		local owner, payer = s.players[1], s.players[2]
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, owner.id, idx)
		table.insert(s.pacts, {
			id = "P1",
			a = owner.id,
			b = payer.id,
			depositA = 0,
			depositB = 0,
			untilRound = s.round,
		})

		expect(Property.payRent(s, payer.id, idx)).toEqual({})
		expect(s.stats[payer.id].rentsPaid).toBe(nil)
		expect(s.stats[owner.id].rentsCollected).toBe(nil)
	end)

	it("no suma nada si un efecto anula la renta", function()
		local s = Fixtures.game({ players = 2 })
		local owner, payer = s.players[1], s.players[2]
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, owner.id, idx)
		addModifier(s, { kind = "Haunt", index = idx, untilRound = 99 })

		expect(Property.payRent(s, payer.id, idx)).toEqual({})
		expect(s.stats[payer.id].rentsPaid).toBe(nil)
		expect(s.stats[owner.id].rentsCollected).toBe(nil)
	end)

	it("suma la renta aunque el pago arruine al pagador", function()
		local s = Fixtures.game({ players = 2 })
		local owner, payer = s.players[1], s.players[2]
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, owner.id, idx)
		payer.cash = 0

		Property.payRent(s, payer.id, idx)

		-- El pago se cobró (con lo que había) y la bancarrota no corrompe los contadores.
		expect(payer.status).toBe("Ghost")
		expect(s.stats[payer.id].rentsPaid).toBe(1)
		expect(s.stats[owner.id].rentsCollected).toBe(1)
	end)
end)

describe("Property.canBuy", function()
	it("acepta una propiedad libre y asequible", function()
		local s = Fixtures.game({ players = 2 })
		expect(Property.canBuy(s, s.players[1].id, Fixtures.squareOf(s, "Property"))).toBe(true)
	end)

	it("rechaza sin efectivo suficiente", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local idx = Fixtures.squareOf(s, "Property")
		a.cash = priceOf(s, idx) - 1
		expect(Property.canBuy(s, a.id, idx)).toBe(false)
	end)

	it("rechaza una propiedad con dueño", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, b.id, idx)
		expect(Property.canBuy(s, a.id, idx)).toBe(false)
	end)

	it("rechaza una casilla que no es propiedad", function()
		local s = Fixtures.game({ players = 2 })
		expect(Property.canBuy(s, s.players[1].id, Fixtures.squareOf(s, "Start"))).toBe(false)
	end)

	it("rechaza a un jugador fantasma", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		a.status = "Ghost"
		expect(Property.canBuy(s, a.id, Fixtures.squareOf(s, "Property"))).toBe(false)
	end)

	it("rechaza a un jugador que no está en la partida", function()
		local s = Fixtures.game({ players = 2 })
		expect(Property.canBuy(s, "P9", Fixtures.squareOf(s, "Property"))).toBe(false)
	end)

	it("admite un precio distinto del de la casilla", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local idx = Fixtures.squareOf(s, "Property")
		local price = priceOf(s, idx)
		a.cash = price - 1
		expect(Property.canBuy(s, a.id, idx, price - 1)).toBe(true)
		expect(Property.canBuy(s, a.id, idx)).toBe(false)
		expect(Property.canBuy(s, a.id, idx, price + 1)).toBe(false)
	end)
end)

describe("Property.buy", function()
	it("cobra el precio y entrega la propiedad", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local idx = Fixtures.squareOf(s, "Property")
		local price = priceOf(s, idx)
		local events = Property.buy(s, a.id, idx)
		expect(a.cash).toBe(Economy.startingCash - price)
		expect(s.properties[idx].ownerId).toBe(a.id)
		expect(events).toEqual({
			{ type = "PropertyBought", playerId = a.id, index = idx, price = price },
		})
	end)

	it("admite un precio pactado", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local idx = Fixtures.squareOf(s, "Property")
		local events = Property.buy(s, a.id, idx, 100)
		expect(a.cash).toBe(Economy.startingCash - 100)
		expect(events[1].price).toBe(100)
	end)

	it("no permite comprar dos veces la misma casilla", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a.id, idx)
		expect(function()
			Property.buy(s, a.id, idx)
		end).toThrow()
	end)
end)

describe("Buy", function()
	it("compra desde AwaitBuy y cierra la fase", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		awaitingBuy(s, a.id, idx)
		local result = Engine.apply(s, a.id, { type = "Buy" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(a.cash).toBe(Economy.startingCash - priceOf(s, idx))
		expect(s.properties[idx].ownerId).toBe(a.id)
		expect(s.phase).toBe("AwaitEnd")
		expect(pendingOf(s).index).toBe(nil)
		expect(result.events).toEqual({
			{ type = "PropertyBought", playerId = a.id, index = idx, price = priceOf(s, idx) },
		})
	end)

	it("no permite comprar sin dinero", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		awaitingBuy(s, a.id, idx)
		a.cash = 10
		local result = Engine.apply(s, a.id, { type = "Buy" })
		expect(rejected(result)).toBe("No puedes comprar esta propiedad")
		expect(a.cash).toBe(10)
		expect(s.properties[idx].ownerId).toBe(nil)
		expect(s.phase).toBe("AwaitBuy")
		expect(pendingOf(s).index).toBe(idx)
	end)

	it("rechaza una propiedad que ya tiene dueño", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, b.id, idx)
		awaitingBuy(s, a.id, idx)
		expect(rejected(Engine.apply(s, a.id, { type = "Buy" }))).toBe("No puedes comprar esta propiedad")
		expect(a.cash).toBe(Economy.startingCash)
		expect(s.properties[idx].ownerId).toBe(b.id)
		expect(s.phase).toBe("AwaitBuy")
	end)

	it("rechaza a un jugador fantasma", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		awaitingBuy(s, a.id, idx)
		a.status = "Ghost"
		expect(rejected(Engine.apply(s, a.id, { type = "Buy" }))).toBe("No puedes comprar esta propiedad")
		expect(a.cash).toBe(Economy.startingCash)
		expect(s.properties[idx].ownerId).toBe(nil)
		expect(s.phase).toBe("AwaitBuy")
	end)

	it("rechaza comprar fuera de AwaitBuy", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		pendingOf(s).index = idx
		expect(rejected(Engine.apply(s, a.id, { type = "Buy" }))).toBe("No se puede Buy en la fase AwaitRoll")
		expect(a.cash).toBe(Economy.startingCash)
		expect(s.properties[idx].ownerId).toBe(nil)
	end)

	it("rechaza comprar fuera de turno", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local other = s.players[s.turnIndex % #s.players + 1].id
		local idx = Fixtures.squareOf(s, "Property")
		awaitingBuy(s, a.id, idx)
		expect(rejected(Engine.apply(s, other, { type = "Buy" }))).toBe("No es tu turno")
		expect(s.properties[idx].ownerId).toBe(nil)
		expect(s.phase).toBe("AwaitBuy")
	end)

	it("rechaza comprar sin propiedad pendiente", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		s.phase = "AwaitBuy"
		expect(rejected(Engine.apply(s, a.id, { type = "Buy" }))).toBe("No hay ninguna propiedad a la venta")
		expect(a.cash).toBe(Economy.startingCash)
		expect(s.phase).toBe("AwaitBuy")
	end)
end)

describe("DeclineBuy", function()
	it("abre la subasta y conserva la casilla", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		awaitingBuy(s, a.id, idx)
		local result = Engine.apply(s, a.id, { type = "DeclineBuy" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(result.events).toEqual({ { type = "AuctionStarted", index = idx } })
		expect(s.phase).toBe("Auction")
		expect(pendingOf(s).index).toBe(idx)
		expect(pendingOf(s).auction).toEqual({ index = idx, high = 0 })
		expect(pendingOf(s).auction.highBidder).toBe(nil)
		expect(s.properties[idx].ownerId).toBe(nil)
		expect(a.cash).toBe(Economy.startingCash)
	end)

	it("rechaza declinar fuera de AwaitBuy", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		s.phase = "AwaitEnd"
		expect(rejected(Engine.apply(s, a.id, { type = "DeclineBuy" }))).toBe(
			"No se puede DeclineBuy en la fase AwaitEnd"
		)
		expect(s.phase).toBe("AwaitEnd")
	end)

	it("rechaza declinar fuera de turno", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local other = s.players[s.turnIndex % #s.players + 1].id
		local idx = Fixtures.squareOf(s, "Property")
		awaitingBuy(s, a.id, idx)
		expect(rejected(Engine.apply(s, other, { type = "DeclineBuy" }))).toBe("No es tu turno")
		expect(s.phase).toBe("AwaitBuy")
		expect(pendingOf(s).index).toBe(idx)
		expect(pendingOf(s).auction).toBe(nil)
	end)

	it("rechaza declinar sin propiedad pendiente", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		s.phase = "AwaitBuy"
		expect(rejected(Engine.apply(s, a.id, { type = "DeclineBuy" }))).toBe(
			"No hay ninguna propiedad que subastar"
		)
		expect(s.phase).toBe("AwaitBuy")
	end)
end)

describe("resolución de la casilla", function()
	it("cae en una propiedad libre y abre AwaitBuy", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		-- Desde la Salida, 1+1 avanza dos casillas: la segunda propiedad de la primera zona.
		local idx = Fixtures.squareOf(s, "Property") + 1
		local events = rollFrom(s, a.id, 1, 1, 1)
		expect(a.position).toBe(idx)
		expect(s.phase).toBe("AwaitBuy")
		expect(pendingOf(s).index).toBe(idx)
		expect(s.properties[idx].ownerId).toBe(nil)
		expect(a.cash).toBe(Economy.startingCash)
		expect(#events).toBe(2)
		expect(events[1].type).toBe("DiceRolled")
		expect(events[2].type).toBe("TokenMoved")
	end)

	it("abre AwaitBuy aunque el jugador no pueda pagarla", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property") + 1
		a.cash = 0
		rollFrom(s, a.id, 1, 1, 1)
		expect(s.phase).toBe("AwaitBuy")
		expect(pendingOf(s).index).toBe(idx)
		expect(a.cash).toBe(0)
		expect(rejected(Engine.apply(s, a.id, { type = "Buy" }))).toBe("No puedes comprar esta propiedad")
		expect(Engine.apply(s, a.id, { type = "DeclineBuy" }).ok).toBe(true)
		expect(s.phase).toBe("Auction")
	end)

	it("cae en una propiedad ajena, paga la renta y cierra la fase", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		local idx = Fixtures.squareOf(s, "Property") + 1
		local rent = math.floor(priceOf(s, idx) * Economy.baseRentRate)
		Fixtures.give(s, a.id, idx)
		local events = rollFrom(s, b.id, 1, 1, 1)
		expect(s.phase).toBe("AwaitEnd")
		expect(a.cash).toBe(Economy.startingCash + rent)
		expect(b.cash).toBe(Economy.startingCash - rent)
		expect(#events).toBe(3)
		expect(events[3]).toEqual({ type = "RentPaid", index = idx, from = b.id, to = a.id, amount = rent })
		expect(pendingOf(s).index).toBe(nil)
	end)

	it("cae en lo propio y no cobra", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local idx = Fixtures.squareOf(s, "Property") + 1
		Fixtures.give(s, a.id, idx)
		local events = rollFrom(s, a.id, 1, 1, 1)
		expect(s.phase).toBe("AwaitEnd")
		expect(a.cash).toBe(Economy.startingCash)
		expect(#events).toBe(2)
		expect(pendingOf(s).index).toBe(nil)
	end)

	it("cae en una casilla especial y cierra la fase sin cobrar", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local spin = Fixtures.squareOf(s, "Spin")
		local events = rollFrom(s, a.id, spin - 2, 1, 1)
		expect(a.position).toBe(spin)
		expect(s.phase).toBe("AwaitEnd")
		expect(a.cash).toBe(Economy.startingCash)
		-- La casilla Giro roba una carta (Tarea 7): el robo es el tercer evento y no cuesta nada.
		expect(#events).toBe(3)
		expect(events[3].type).toBe("CardDrawn")
		expect(#a.hand).toBe(1)
	end)
end)

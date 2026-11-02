--!strict
local Harness = require("../harness")
local Board = require("../../src/shared/rules/Board")
local Building = require("../../src/shared/rules/Building")
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

local function zoneOf(state: Types.GameState, index: number): { number }
	local zone = Board.zoneOf(state, index)
	if not zone then
		error(`la casilla {index} no tiene zona`, 2)
	end
	return zone
end

local function levelOf(state: Types.GameState, index: number): number
	local property = state.properties[index]
	if not property then
		error(`la casilla {index} no tiene estado de propiedad`, 2)
	end
	return property.level
end

-- El coste del contrato: 50 % del precio de la casilla, redondeado hacia abajo.
local function expectedCost(state: Types.GameState, index: number): number
	return math.floor(priceOf(state, index) * Economy.buildingCostRate)
end

-- Construir exige la zona completa; el arnés no cobra las propiedades que entrega.
local function giveZone(state: Types.GameState, playerId: Types.PlayerId, index: number)
	for _, member in zoneOf(state, index) do
		Fixtures.give(state, playerId, member)
	end
end

describe("Building.costOf", function()
	it("cobra el 50 % del precio de la casilla", function()
		local s = Fixtures.game({ players = 2 })
		local idx = Fixtures.squareOf(s, "Property")
		expect(Building.costOf(s, s.players[1].id, idx)).toBe(priceOf(s, idx) * Economy.buildingCostRate)
	end)

	it("hoy devuelve el coste base, sin perks", function()
		local s = Fixtures.game({ players = 2 })
		local idx = Fixtures.squareOf(s, "Property")
		expect(Building.costOf(s, s.players[1].id, idx)).toBe(Building.costOf(s, s.players[2].id, idx))
	end)

	it("señala una casilla que no es una propiedad", function()
		local s = Fixtures.game({ players = 2 })
		expect(function()
			Building.costOf(s, s.players[1].id, Fixtures.squareOf(s, "Start"))
		end).toThrow()
	end)
end)

describe("Building.build", function()
	it("no construye sin la zona completa", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local idx = Fixtures.squareOf(s, "Property")
		local zone = zoneOf(s, idx)
		Fixtures.give(s, a.id, zone[1])
		Fixtures.give(s, a.id, zone[2])
		expect(rejected(Building.build(s, a.id, idx))).toBe("Necesitas la zona completa para construir")
		expect(levelOf(s, idx)).toBe(0)
		expect(a.cash).toBe(Economy.startingCash)
	end)

	it("no construye sin ser el dueño", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		local idx = Fixtures.squareOf(s, "Property")
		giveZone(s, b.id, idx)
		expect(rejected(Building.build(s, a.id, idx))).toBe("No eres el dueño de esta propiedad")
		expect(levelOf(s, idx)).toBe(0)
		expect(a.cash).toBe(Economy.startingCash)
		expect(b.cash).toBe(Economy.startingCash)
	end)

	it("sube un nivel y cobra el 50 %", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local idx = Fixtures.squareOf(s, "Property")
		giveZone(s, a.id, idx)
		local cost = expectedCost(s, idx)
		local result = Building.build(s, a.id, idx)
		if not result.ok then
			error(result.error, 2)
		end
		expect(result.events).toEqual({ { type = "BuildingChanged", index = idx, from = 0, to = 1 } })
		expect(levelOf(s, idx)).toBe(1)
		expect(a.cash).toBe(Economy.startingCash - cost)
	end)

	it("no pasa del nivel máximo", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local idx = Fixtures.squareOf(s, "Property")
		giveZone(s, a.id, idx)
		for _ = 1, Economy.maxBuildingLevel do
			local result = Building.build(s, a.id, idx)
			if not result.ok then
				error(result.error, 2)
			end
		end
		expect(levelOf(s, idx)).toBe(Economy.maxBuildingLevel)
		local cash = a.cash
		expect(rejected(Building.build(s, a.id, idx))).toBe("La propiedad ya está al nivel máximo")
		expect(levelOf(s, idx)).toBe(Economy.maxBuildingLevel)
		expect(a.cash).toBe(cash)
	end)

	it("no construye sin efectivo suficiente", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local idx = Fixtures.squareOf(s, "Property")
		giveZone(s, a.id, idx)
		a.cash = expectedCost(s, idx) - 1
		expect(rejected(Building.build(s, a.id, idx))).toBe("No tienes efectivo suficiente")
		expect(levelOf(s, idx)).toBe(0)
		expect(a.cash).toBe(expectedCost(s, idx) - 1)
	end)

	it("no construye fuera de una propiedad", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		expect(rejected(Building.build(s, a.id, Fixtures.squareOf(s, "Start")))).toBe(
			"La casilla no es una propiedad"
		)
		expect(a.cash).toBe(Economy.startingCash)
	end)

	it("no deja construir a un fantasma", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local idx = Fixtures.squareOf(s, "Property")
		giveZone(s, a.id, idx)
		a.status = "Ghost"
		expect(rejected(Building.build(s, a.id, idx))).toBe("Solo los jugadores activos pueden construir")
		expect(levelOf(s, idx)).toBe(0)
		expect(a.cash).toBe(Economy.startingCash)
	end)
end)

describe("Building.lower", function()
	it("no hace nada en el nivel 0", function()
		local s = Fixtures.game({ players = 2 })
		local idx = Fixtures.squareOf(s, "Property")
		expect(Building.lower(s, idx)).toEqual({})
		expect(levelOf(s, idx)).toBe(0)
	end)

	it("baja un nivel y no devuelve dinero", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local idx = Fixtures.squareOf(s, "Property")
		giveZone(s, a.id, idx)
		s.properties[idx].level = 2
		local cash = a.cash
		expect(Building.lower(s, idx)).toEqual({ { type = "BuildingChanged", index = idx, from = 2, to = 1 } })
		expect(levelOf(s, idx)).toBe(1)
		expect(a.cash).toBe(cash)
	end)

	it("señala una casilla que no es una propiedad", function()
		local s = Fixtures.game({ players = 2 })
		expect(function()
			Building.lower(s, Fixtures.squareOf(s, "Start"))
		end).toThrow()
	end)
end)

describe("renta por nivel de edificio", function()
	it("aplica × 3, × 6 y × 10 con la zona completa", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local idx = Fixtures.squareOf(s, "Property")
		giveZone(s, a.id, idx)
		local base = priceOf(s, idx) * Economy.baseRentRate * Economy.completeZoneRentMultiplier
		expect(Property.rentFor(s, idx)).toBe(math.floor(base))
		for level = 1, Economy.maxBuildingLevel do
			local result = Building.build(s, a.id, idx)
			if not result.ok then
				error(result.error, 2)
			end
			expect(levelOf(s, idx)).toBe(level)
			expect(Property.rentFor(s, idx)).toBe(math.floor(base * Economy.buildingRentMultiplier[level]))
		end
	end)
end)

describe("Build", function()
	it("sube el nivel desde AwaitRoll, cobra y emite BuildingChanged", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		giveZone(s, a.id, idx)
		local cost = expectedCost(s, idx)
		local result = Engine.apply(s, a.id, { type = "Build", index = idx })
		if not result.ok then
			error(result.error, 2)
		end
		expect(result.events).toEqual({ { type = "BuildingChanged", index = idx, from = 0, to = 1 } })
		expect(levelOf(s, idx)).toBe(1)
		expect(a.cash).toBe(Economy.startingCash - cost)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("también construye desde AwaitEnd sin cambiar la fase", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		giveZone(s, a.id, idx)
		s.phase = "AwaitEnd"
		local result = Engine.apply(s, a.id, { type = "Build", index = idx })
		if not result.ok then
			error(result.error, 2)
		end
		expect(levelOf(s, idx)).toBe(1)
		expect(s.phase).toBe("AwaitEnd")
	end)

	it("rechaza construir fuera de sus fases", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		giveZone(s, a.id, idx)
		s.phase = "AwaitBuy"
		expect(rejected(Engine.apply(s, a.id, { type = "Build", index = idx }))).toBe(
			"No se puede Build en la fase AwaitBuy"
		)
		expect(levelOf(s, idx)).toBe(0)
		expect(a.cash).toBe(Economy.startingCash)
		expect(s.phase).toBe("AwaitBuy")
	end)

	it("rechaza a un jugador que no es el dueño", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local other = s.players[s.turnIndex % #s.players + 1]
		local idx = Fixtures.squareOf(s, "Property")
		giveZone(s, other.id, idx)
		expect(rejected(Engine.apply(s, a.id, { type = "Build", index = idx }))).toBe(
			"No eres el dueño de esta propiedad"
		)
		expect(levelOf(s, idx)).toBe(0)
		expect(a.cash).toBe(Economy.startingCash)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("rechaza construir fuera de turno", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local other = s.players[s.turnIndex % #s.players + 1]
		local idx = Fixtures.squareOf(s, "Property")
		giveZone(s, a.id, idx)
		expect(rejected(Engine.apply(s, other.id, { type = "Build", index = idx }))).toBe("No es tu turno")
		expect(levelOf(s, idx)).toBe(0)
		expect(a.cash).toBe(Economy.startingCash)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("rechaza una casilla que no es una propiedad", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		expect(rejected(Engine.apply(s, a.id, { type = "Build", index = Fixtures.squareOf(s, "Start") }))).toBe(
			"La casilla no es una propiedad"
		)
		expect(a.cash).toBe(Economy.startingCash)
	end)
end)

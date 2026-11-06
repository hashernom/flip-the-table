--!strict
-- Hipotecas y venta de edificios (R-P53): se hacen en el turno propio, desde «Gestionar propiedades».
local Harness = require("../harness")
local Bankruptcy = require("../../src/shared/rules/Bankruptcy")
local Board = require("../../src/shared/rules/Board")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Property = require("../../src/shared/rules/Property")
local Score = require("../../src/shared/rules/Score")
local Types = require("../../src/shared/rules/Types")
local View = require("../../src/shared/rules/View")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function inTurn(state: Types.GameState): Types.Player
	return state.players[state.turnIndex]
end

local function ok(result: Types.ApplyResult): { Types.Event }
	if not result.ok then
		error(result.error, 2)
	end
	return result.events
end

local function rejected(result: Types.ApplyResult): string
	if result.ok then
		error("se esperaba un rechazo y la acción se aplicó", 2)
	end
	return result.error
end

local function priceOf(state: Types.GameState, index: number): number
	return state.board.squares[index].price :: number
end

local function giveZone(state: Types.GameState, playerId: Types.PlayerId, index: number)
	for _, member in Board.zoneOf(state, index) :: { number } do
		Fixtures.give(state, playerId, member)
	end
end

local function otherInZone(state: Types.GameState, index: number): number
	for _, member in Board.zoneOf(state, index) :: { number } do
		if member ~= index then
			return member
		end
	end
	error("zona de una sola casilla")
end

local function hasLegal(
	state: Types.GameState,
	playerId: Types.PlayerId,
	actionType: string,
	index: number
): boolean
	for _, action in Engine.legalActions(state, playerId) do
		if action.type == actionType and action.index == index then
			return true
		end
	end
	return false
end

describe("Mortgage", function()
	it("da el 50 % del precio, marca la propiedad y emite PropertyMortgaged", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a.id, idx)
		local amount = math.floor(priceOf(s, idx) * Economy.mortgage.rate)
		local events = ok(Engine.apply(s, a.id, { type = "Mortgage", index = idx }))
		expect(events).toEqual({
			{ type = "PropertyMortgaged", playerId = a.id, index = idx, amount = amount },
		})
		expect(s.properties[idx].mortgaged).toBe(true)
		expect(a.cash).toBe(Economy.startingCash + amount)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("una hipotecada no cobra renta", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a.id, idx)
		ok(Engine.apply(s, a.id, { type = "Mortgage", index = idx }))
		expect(Property.rentFor(s, idx)).toBe(0)
	end)

	it("no se hipoteca con edificios en la zona, ni dos veces, ni la de otro", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		giveZone(s, a.id, idx)
		s.properties[otherInZone(s, idx)].level = 1
		expect(rejected(Engine.apply(s, a.id, { type = "Mortgage", index = idx }))).toBe(
			"Vende antes los edificios de la zona"
		)
		s.properties[otherInZone(s, idx)].level = 0
		ok(Engine.apply(s, a.id, { type = "Mortgage", index = idx }))
		expect(rejected(Engine.apply(s, a.id, { type = "Mortgage", index = idx }))).toBe(
			"La propiedad ya está hipotecada"
		)
		local b = s.players[if s.turnIndex == 1 then 2 else 1]
		local mine = otherInZone(s, idx)
		s.properties[mine].ownerId = b.id
		expect(rejected(Engine.apply(s, a.id, { type = "Mortgage", index = mine }))).toBe(
			"No eres el dueño de esta propiedad"
		)
	end)

	it("solo en el turno propio y en sus fases", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a.id, idx)
		s.phase = "AwaitBuy"
		rejected(Engine.apply(s, a.id, { type = "Mortgage", index = idx }))
		s.phase = "AwaitEnd"
		ok(Engine.apply(s, a.id, { type = "Mortgage", index = idx }))
	end)

	it("aparece entre las acciones legales cuando se puede", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		expect(hasLegal(s, a.id, "Mortgage", idx)).toBe(false)
		Fixtures.give(s, a.id, idx)
		expect(hasLegal(s, a.id, "Mortgage", idx)).toBe(true)
	end)

	it("con una hipotecada en la zona no se construye, pero la zona sigue completa", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		giveZone(s, a.id, idx)
		ok(Engine.apply(s, a.id, { type = "Mortgage", index = otherInZone(s, idx) }))
		expect(rejected(Engine.apply(s, a.id, { type = "Build", index = idx }))).toBe(
			"No se construye con una propiedad hipotecada en la zona"
		)
		expect(Board.ownsZone(s, a.id, s.board.squares[idx].zoneId :: string)).toBe(true)
	end)
end)

describe("Unmortgage", function()
	it("cuesta el 55 % del precio y quita la hipoteca", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a.id, idx)
		ok(Engine.apply(s, a.id, { type = "Mortgage", index = idx }))
		local before = a.cash
		local cost = math.floor(priceOf(s, idx) * Economy.mortgage.repayRate)
		local events = ok(Engine.apply(s, a.id, { type = "Unmortgage", index = idx }))
		expect(events).toEqual({
			{ type = "PropertyUnmortgaged", playerId = a.id, index = idx, amount = cost },
		})
		expect(s.properties[idx].mortgaged).toBe(nil)
		expect(a.cash).toBe(before - cost)
	end)

	it("no se recupera sin efectivo ni una que no está hipotecada", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a.id, idx)
		expect(rejected(Engine.apply(s, a.id, { type = "Unmortgage", index = idx }))).toBe(
			"La propiedad no está hipotecada"
		)
		ok(Engine.apply(s, a.id, { type = "Mortgage", index = idx }))
		a.cash = 0
		expect(rejected(Engine.apply(s, a.id, { type = "Unmortgage", index = idx }))).toBe(
			"No tienes efectivo suficiente"
		)
	end)
end)

describe("SellBuilding", function()
	it("baja un nivel y devuelve la mitad de su coste", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		giveZone(s, a.id, idx)
		s.properties[idx].level = 2
		local refund = math.floor(math.floor(priceOf(s, idx) * Economy.buildingCostRate) / 2)
		local events = ok(Engine.apply(s, a.id, { type = "SellBuilding", index = idx }))
		expect(events).toEqual({
			{ type = "BuildingChanged", index = idx, from = 2, to = 1, refund = refund },
		})
		expect(s.properties[idx].level).toBe(1)
		expect(a.cash).toBe(Economy.startingCash + refund)
	end)

	it("no vende sin edificios", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a.id, idx)
		expect(rejected(Engine.apply(s, a.id, { type = "SellBuilding", index = idx }))).toBe(
			"La propiedad no tiene edificios"
		)
	end)
end)

describe("Hipotecas en el resto de reglas", function()
	it("en el patrimonio una hipotecada vale el precio menos lo que dio", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a.id, idx)
		local before = Score.netWorth(s, a.id)
		ok(Engine.apply(s, a.id, { type = "Mortgage", index = idx }))
		-- Cobró el 50 % y la propiedad vale ahora un 50 % menos: el patrimonio no cambia.
		expect(Score.netWorth(s, a.id)).toBe(before)
	end)

	it("la liquidación no saca nada de una hipotecada y la devuelve al banco limpia", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a.id, idx)
		ok(Engine.apply(s, a.id, { type = "Mortgage", index = idx }))
		a.cash = 0
		Bankruptcy.charge(s, a.id, 10, nil)
		expect(a.status).toBe("Ghost")
		expect(s.properties[idx].ownerId).toBe(nil)
		expect(s.properties[idx].mortgaged).toBe(nil)
	end)

	it("la vista enseña la hipoteca", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a.id, idx)
		ok(Engine.apply(s, a.id, { type = "Mortgage", index = idx }))
		local view = View.forPlayer(s, a.id)
		expect(view.properties[idx].mortgaged).toBe(true)
	end)
end)

describe("Bot y las hipotecas", function()
	it("el bot recupera una hipoteca al cerrar el turno si le sobra dinero, y nunca hipoteca solo", function()
		local Bot = require("../../src/shared/rules/Bot")
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a.id, idx)
		s.phase = "AwaitEnd"
		-- Sin rival activo no hay pacto que proponer: el bot pasa a sus decisiones de cierre.
		s.players[if s.turnIndex == 1 then 2 else 1].status = "Ghost"
		local first = Bot.choose(s, a.id)
		expect(first ~= nil and first.type ~= "Mortgage").toBe(true)
		s.properties[idx].mortgaged = true
		local choice = Bot.choose(s, a.id)
		expect(choice ~= nil and choice.type).toBe("Unmortgage")
	end)
end)

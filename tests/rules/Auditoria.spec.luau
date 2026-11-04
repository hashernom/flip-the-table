--!strict
-- Regresiones de la segunda auditoría (auditoria/auditoria-2026-11-04-segunda-pasada.md). Cada prueba
-- reproduce un fallo con el motor real y lleva el número del hallazgo.
local Bankruptcy = require("../../src/shared/rules/Bankruptcy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Harness = require("../harness")
local MatchState = require("../../src/server/match/MatchState")
local Property = require("../../src/shared/rules/Property")
local Types = require("../../src/shared/rules/Types")
local View = require("../../src/shared/rules/View")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function apply(state: Types.GameState, playerId: string, action: Types.Action): { Types.Event }
	local result = Engine.apply(state, playerId, action)
	if not result.ok then
		error(result.error, 2)
	end
	return result.events
end

local function eventOf(events: { Types.Event }, kind: string): Types.Event?
	for _, event in events do
		if event.type == kind then
			return event
		end
	end
	return nil
end

describe("I3: la compra del Mercado no revela la carta", function()
	local function bought(): (Types.GameState, string, string, { Types.Event })
		local state = Fixtures.game({ players = 3, seed = 31 })
		local buyer, other = state.players[1].id, state.players[2].id
		Fixtures.placeOn(state, buyer, Fixtures.squareOf(state, "Market") - 2)
		Fixtures.dice(state, 1, 1)
		apply(state, buyer, { type = "Roll" })
		local pending = state.pending :: any
		return state,
			buyer,
			other,
			apply(state, buyer, { type = "MarketBuy", cardId = pending.market.cards[1].cardId })
	end

	it("los demás no ven la carta ni el precio, que delataría su rareza", function()
		local state, _, other, events = bought()
		local event = eventOf(View.filterEvents(state, other, events), "MarketBought") :: any
		expect(event.cardId).toBe(nil)
		expect(event.price).toBe(nil)
	end)

	it("el comprador sigue viendo lo que compró", function()
		local state, buyer, _, events = bought()
		local event = eventOf(View.filterEvents(state, buyer, events), "MarketBought") :: any
		expect(type(event.cardId)).toBe("string")
		expect(event.price).toBe(100)
	end)
end)

describe("I9: un espectro no cobra Coleccionista", function()
	it("sabotear con la mano llena no le da efectivo", function()
		local state = Fixtures.game({ players = 3, seed = 41 })
		local ghost = state.players[1]
		ghost.perks = { "Collector" }
		ghost.hand = { "Spy", "Fine", "Shove" }
		ghost.cash = 0
		Bankruptcy.charge(state, ghost.id, 1)
		state.stats[ghost.id].comebackRounds = 1
		state.turnIndex = 1
		state.phase = "GhostTurn"
		apply(state, ghost.id, { type = "GhostAct", kind = "Sabotage" })
		expect(ghost.status).toBe("Ghost")
		expect(ghost.cash).toBe(0)
	end)
end)

describe("M5: la renta con Casero no pierde una unidad por coma flotante", function()
	it("100 × nivel 3 (× 5) × Zona Caliente (× 2) × 1,15 son 115", function()
		local state = Fixtures.game({ players = 5, seed = 45 })
		local owner = state.players[1]
		owner.perks = { "Landlord" }
		local index = state.board.zones.cian[1]
		Fixtures.give(state, owner.id, index)
		state.properties[index].level = 3
		state.hotZoneId = "cian"
		expect(state.board.squares[index].price).toBe(100)
		expect(Property.rentFor(state, index)).toBe(115)
	end)
end)

describe("M6: RentPaid anuncia lo que se cobra de verdad", function()
	it("si el pagador se arruina, anuncia lo que recibió el dueño", function()
		local state = Fixtures.game({ players = 3, seed = 46 })
		local payer, owner = state.players[1], state.players[2]
		local index = state.board.zones.violeta[1]
		Fixtures.give(state, owner.id, index)
		payer.cash = 5
		local before = owner.cash
		local event = eventOf(Property.chargeRent(state, payer.id, owner.id, index, 200), "RentPaid") :: any
		expect(owner.cash - before).toBe(5)
		expect(event.amount).toBe(5)
	end)

	it("con dinero de sobra anuncia la renta entera", function()
		local state = Fixtures.game({ players = 3, seed = 46 })
		local payer, owner = state.players[1], state.players[2]
		local index = state.board.zones.violeta[1]
		Fixtures.give(state, owner.id, index)
		local event = eventOf(Property.chargeRent(state, payer.id, owner.id, index, 200), "RentPaid") :: any
		expect(event.amount).toBe(200)
	end)
end)

describe("M9: el reloj de una fase de grupo no cuenta contra quien está en turno", function()
	for _, phase: Types.Phase in { "Auction", "Tribunal", "Duel" } :: { Types.Phase } do
		it(`{phase} no atribuye el vencimiento`, function()
			local state = Fixtures.game({ players = 3, seed = 47 })
			state.phase = phase
			expect(MatchState.decidingPlayer(state)).toBe(nil)
		end)
	end
end)

describe("M12: el final de la partida anuncia los premios", function()
	it("al quedar un solo activo", function()
		local state = Fixtures.game({ players = 2, seed = 48 })
		local loser = state.players[1]
		loser.cash = 0
		state.stats[loser.id].rentsPaid = 4
		local event = eventOf(Bankruptcy.charge(state, loser.id, 1), "GameEnded") :: any
		expect(event.awards).toEqual({ { id = "VictimOfTheNight", playerId = loser.id } })
	end)

	it("al acabar la última ronda", function()
		local state = Fixtures.game({ players = 2, seed = 49 })
		local traitor = state.players[2]
		state.stats[traitor.id].pactsBroken = 1
		state.round = state.maxRounds :: number
		state.turnIndex = 2
		state.phase = "AwaitEnd"
		local event = eventOf(apply(state, traitor.id, { type = "EndTurn" }), "GameEnded") :: any
		expect(event.awards).toEqual({ { id = "MostTreacherous", playerId = traitor.id } })
	end)
end)

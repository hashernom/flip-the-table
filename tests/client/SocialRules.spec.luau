--!strict
-- Reglas de los menús sociales (tratos y pactos) con vistas reales del motor: quién puede proponer,
-- a quién, con qué casillas, y cuántas ofertas esperan respuesta. B8 de la auditoría.
local Harness = require("../harness")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Protocol = require("../../src/shared/net/Protocol")
local SocialRules = require("../../src/client/ui/SocialRules")
local Types = require("../../src/shared/rules/Types")
local Ui = require("../../src/shared/config/Ui")
local View = require("../../src/shared/rules/View")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function inTurn(state: Types.GameState): Types.Player
	return state.players[state.turnIndex]
end

local function others(state: Types.GameState, playerId: Types.PlayerId): { Types.Player }
	local list: { Types.Player } = {}
	for _, player in state.players do
		if player.id ~= playerId then
			table.insert(list, player)
		end
	end
	return list
end

local function setup(): (Types.GameState, Types.Player, Types.Player)
	local state = Fixtures.game({ players = 3, seed = 31 })
	local me = inTurn(state)
	return state, me, others(state, me.id)[1]
end

describe("SocialRules: botones sociales", function()
	it("en tu turno hay Tratos y Pactos, sin contador si no hay ofertas", function()
		local state, me = setup()
		local buttons = SocialRules.buttonsFor(View.forPlayer(state, me.id))
		expect(#buttons).toBe(2)
		expect(buttons[1].label).toBe("Tratos")
		expect(buttons[2].label).toBe("Pactos")
		expect(buttons[1].action).toEqual({ type = "__OpenTrade" })
		expect(buttons[2].action).toEqual({ type = "__OpenPact" })
	end)

	it("una oferta recibida sale en el contador del botón", function()
		local state, me, rival = setup()
		local result = Engine.apply(state, me.id, {
			type = "ProposeTrade",
			offer = { toId = rival.id, giveCash = 50, wantCash = 0, giveSquares = {}, wantSquares = {} },
		})
		expect(result.ok).toBe(true)
		Engine.apply(state, me.id, { type = "ProposePact", toId = rival.id, rounds = 2 })
		local buttons = SocialRules.buttonsFor(View.forPlayer(state, rival.id))
		expect(buttons[1].label).toBe("Tratos (1)")
		expect(buttons[2].label).toBe("Pactos (1)")
		-- Quien propone no tiene nada que responder.
		local mine = SocialRules.buttonsFor(View.forPlayer(state, me.id))
		expect(mine[1].label).toBe("Tratos")
	end)

	it("en una subasta, un duelo o al acabar no hay botones sociales", function()
		local state, me = setup()
		for _, phase in { "Auction", "Duel", "Tribunal", "Market", "Reaction", "GameOver" } do
			state.phase = phase :: Types.Phase
			expect(#SocialRules.buttonsFor(View.forPlayer(state, me.id))).toBe(0)
		end
	end)

	it("un espectro no ve los botones sociales", function()
		local state, me = setup()
		me.status = "Ghost"
		expect(#SocialRules.buttonsFor(View.forPlayer(state, me.id))).toBe(0)
	end)
end)

describe("SocialRules: quién puede proponer y a quién", function()
	it("solo propone quien está en turno y en AwaitRoll o AwaitEnd", function()
		local state, me, rival = setup()
		expect(SocialRules.canPropose(View.forPlayer(state, me.id))).toBe(true)
		expect(SocialRules.canPropose(View.forPlayer(state, rival.id))).toBe(false)
		state.phase = "AwaitBuy"
		expect(SocialRules.canPropose(View.forPlayer(state, me.id))).toBe(false)
		state.phase = "AwaitEnd"
		expect(SocialRules.canPropose(View.forPlayer(state, me.id))).toBe(true)
	end)

	it("los rivales son solo los activos y no uno mismo", function()
		local state, me = setup()
		local rivals = others(state, me.id)
		rivals[1].status = "Ghost"
		local list = SocialRules.rivals(View.forPlayer(state, me.id))
		expect(#list).toBe(1)
		expect(list[1]).toBe(rivals[2].id)
	end)

	it("las casillas a elegir son las del dueño sin edificios, en orden", function()
		local state, me, rival = setup()
		local zone = state.board.zones[state.board.zoneOrder[2]]
		Fixtures.give(state, rival.id, zone[2])
		Fixtures.give(state, rival.id, zone[1])
		Fixtures.give(state, me.id, state.board.zones[state.board.zoneOrder[1]][1])
		state.properties[zone[2]].level = 2
		local view = View.forPlayer(state, me.id)
		expect(SocialRules.tradeableSquares(view, rival.id)).toEqual({ zone[1] })
		expect(#SocialRules.tradeableSquares(view, me.id)).toBe(1)
	end)
end)

describe("SocialRules: la propuesta que arma el menú la acepta el motor", function()
	it("dinero y casillas por casillas, y el protocolo la valida", function()
		local state, me, rival = setup()
		local zone = state.board.zones[state.board.zoneOrder[2]]
		local mine = state.board.zones[state.board.zoneOrder[1]][1]
		Fixtures.give(state, me.id, mine)
		Fixtures.give(state, rival.id, zone[1])
		local view = View.forPlayer(state, me.id)
		local action = SocialRules.proposal(view, {
			targetId = rival.id,
			giveCash = 100,
			wantCash = 0,
			giveSquares = { mine },
			wantSquares = { zone[1] },
		})
		expect(action ~= nil).toBe(true)
		expect((Protocol.validate(action)) :: boolean).toBe(true)
		expect(Engine.apply(state, me.id, action :: any).ok).toBe(true)
		local seen = (View.forPlayer(state, rival.id).pending :: any).trades[1]
		expect(seen.wantSquares).toEqual({ zone[1] })
	end)

	it("sin rival elegido o sin nada que ofrecer ni pedir no hay propuesta", function()
		local state, me, rival = setup()
		local view = View.forPlayer(state, me.id)
		expect(
			SocialRules.proposal(
				view,
				{ targetId = nil, giveCash = 0, wantCash = 50, giveSquares = {}, wantSquares = {} }
			)
		).toBe(nil)
		expect(
			SocialRules.proposal(
				view,
				{ targetId = rival.id, giveCash = 0, wantCash = 0, giveSquares = {}, wantSquares = {} }
			)
		).toBe(nil)
	end)

	it("una selección vieja se depura: lo que ya no es tuyo o tiene edificios no viaja", function()
		local state, me, rival = setup()
		local zone = state.board.zones[state.board.zoneOrder[2]]
		Fixtures.give(state, rival.id, zone[1])
		Fixtures.give(state, rival.id, zone[2])
		state.properties[zone[2]].level = 1
		local view = View.forPlayer(state, me.id)
		local action = SocialRules.proposal(view, {
			targetId = rival.id,
			giveCash = 50,
			wantCash = 0,
			giveSquares = { 999 },
			wantSquares = { zone[1], zone[2] },
		})
		expect(action ~= nil).toBe(true)
		expect((action :: any).offer.wantSquares).toEqual({ zone[1] })
		expect((action :: any).offer.giveSquares).toEqual({})
	end)

	it("el dinero pedido nunca supera el efectivo del rival", function()
		local state, me, rival = setup()
		local view = View.forPlayer(state, me.id)
		local action = SocialRules.proposal(view, {
			targetId = rival.id,
			giveCash = 0,
			wantCash = rival.cash + 500,
			giveSquares = {},
			wantSquares = {},
		})
		expect((action :: any).offer.wantCash).toBe(rival.cash)
	end)

	it("los importes salen de la configuración", function()
		local steps = Ui.tradeCashSteps
		expect(steps[1]).toBe(0)
		expect(SocialRules.nextStep(steps, 0, 1)).toBe(steps[2])
		expect(SocialRules.nextStep(steps, steps[#steps], 1)).toBe(steps[#steps])
		expect(SocialRules.nextStep(steps, 0, -1)).toBe(0)
		-- Un importe que no está en la lista se acota al paso más cercano en la dirección pedida.
		expect(SocialRules.nextStep(steps, 75, 1)).toBe(100)
		expect(SocialRules.nextStep(steps, 75, -1)).toBe(50)
	end)
end)

describe("SocialRules: pactos", function()
	it("solo se ofrecen las duraciones que acepta el motor", function()
		for _, rounds in SocialRules.pactRounds() do
			expect(rounds >= Economy.pact.minRounds and rounds <= Economy.pact.maxRounds).toBe(true)
			local state = Fixtures.game({ players = 3, seed = 31 })
			local me = inTurn(state)
			local result = Engine.apply(
				state,
				me.id,
				{ type = "ProposePact", toId = others(state, me.id)[1].id, rounds = rounds }
			)
			expect(result.ok).toBe(true)
		end
	end)

	it("los pactos propios se listan con el otro socio", function()
		local state, me, rival = setup()
		state.pacts = { { id = "X1", a = rival.id, b = me.id, depositA = 0, depositB = 0, untilRound = 4 } }
		local list = SocialRules.ownPacts(View.forPlayer(state, me.id))
		expect(#list).toBe(1)
		expect(list[1].partnerId).toBe(rival.id)
		expect(list[1].id).toBe("X1")
	end)
end)

describe("SocialRules.parseCash", function()
	it("lee cifras con o sin punto de miles", function()
		expect(SocialRules.parseCash("150")).toBe(150)
		expect(SocialRules.parseCash("1.240")).toBe(1240)
		expect(SocialRules.parseCash(" 75 ")).toBe(75)
	end)

	it("sin cifras es cero, y lo que no es cifra se ignora", function()
		expect(SocialRules.parseCash("")).toBe(0)
		expect(SocialRules.parseCash("abc")).toBe(0)
		expect(SocialRules.parseCash("-50")).toBe(50)
	end)

	it("acota al máximo que se le pase", function()
		expect(SocialRules.parseCash("99999", 980)).toBe(980)
	end)
end)

--!strict
-- Configuración de la partida privada (config/MatchSettings): se valida siempre y el motor la respeta.
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Harness = require("../harness")
local MatchSettings = require("../../src/shared/config/MatchSettings")
local State = require("../../src/shared/rules/State")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function create(settings: any, endMode: any?)
	return State.create({ playerIds = { "P1", "P2", "P3" }, seed = 7, endMode = endMode, settings = settings })
end

describe("MatchSettings.normalize", function()
	it("sin configuración, la de por defecto", function()
		expect(MatchSettings.normalize(nil)).toEqual(MatchSettings.defaults())
		expect(MatchSettings.isDefault(MatchSettings.normalize({}))).toBe(true)
	end)

	it("acepta solo valores de la lista y del tipo correcto", function()
		local settings = MatchSettings.normalize({
			startingCash = 2500,
			startBonus = 999,
			length = "Long",
			auctions = false,
			perks = "no",
			hotZone = false,
			extra = true,
		})
		expect(settings.startingCash).toBe(2500)
		expect(settings.startBonus).toBe(Economy.startBonus)
		expect(settings.length).toBe("Long")
		expect(settings.auctions).toBe(false)
		expect(settings.perks).toBe(true)
		expect(settings.hotZone).toBe(false)
		expect((settings :: any).extra).toBe(nil)
	end)

	it("cada opción por defecto está entre sus valores posibles", function()
		for _, option in MatchSettings.OPTIONS do
			local value = (MatchSettings.DEFAULTS :: any)[option.id]
			if option.kind == "toggle" then
				expect(type(value)).toBe("boolean")
			else
				local found = false
				for _, choice in MatchSettings.choicesOf(option) do
					found = found or choice.value == value
				end
				expect(found).toBe(true)
			end
		end
	end)
end)

describe("State.create con configuración", function()
	it("el dinero inicial y la duración salen de la configuración", function()
		local s = create({ startingCash = 2000, length = "Short" })
		for _, player in s.players do
			expect(player.cash).toBe(2000)
		end
		expect(s.maxRounds).toBe(
			MatchSettings.maxRounds(Economy.rounds.S, MatchSettings.normalize({ length = "Short" }))
		)
		expect((s.maxRounds :: number) < Economy.rounds.S).toBe(true)
	end)

	it("sin perks empieza tirando; sin Zona Caliente no hay zona", function()
		local s = create({ perks = false, hotZone = false })
		expect(s.phase).toBe("AwaitRoll")
		expect(s.hotZoneId).toBe(nil)
		local normal = create(nil)
		expect(normal.phase).toBe("PerkDraft")
		expect(normal.hotZoneId ~= nil).toBe(true)
	end)
end)

describe("Engine con configuración", function()
	it("sin subastas, rechazar la compra deja la propiedad libre y cierra la casilla", function()
		local s = Fixtures.game({ players = 3 })
		s.settings = MatchSettings.normalize({ auctions = false })
		local player = s.players[s.turnIndex]
		Fixtures.placeOn(s, player.id, 1)
		Fixtures.dice(s, 1, 1)
		expect(Engine.apply(s, player.id, { type = "Roll" }).ok).toBe(true)
		expect(s.phase).toBe("AwaitBuy")
		local index = (s.pending :: any).index
		local result = Engine.apply(s, player.id, { type = "DeclineBuy" })
		expect(result.ok).toBe(true)
		expect(s.phase).toBe("AwaitEnd")
		expect(s.properties[index].ownerId).toBe(nil)
		expect(#(result :: any).events).toBe(0)
	end)

	it("el paso por la Salida cobra lo configurado", function()
		local s = Fixtures.game({ players = 3 })
		s.settings = MatchSettings.normalize({ startBonus = 300 })
		local player = s.players[s.turnIndex]
		local squares = #s.board.squares
		Fixtures.placeOn(s, player.id, squares)
		Fixtures.dice(s, 1, 2)
		local before = player.cash
		local result = Engine.apply(s, player.id, { type = "Roll" })
		expect(result.ok).toBe(true)
		local bonus = 0
		for _, event in (result :: any).events do
			if event.type == "PassedStart" then
				bonus = event.amount
			end
		end
		expect(bonus).toBe(300)
		expect(player.cash >= before).toBe(true)
	end)
end)

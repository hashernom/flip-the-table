--!strict
local Harness = require("../harness")
local State = require("../../src/shared/rules/State")
local View = require("../../src/shared/rules/View")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

describe("State.create: fichas", function()
	it("cada jugador tiene una ficha distinta y se respeta su elección", function()
		local state = State.create({
			playerIds = { "a", "b", "c" },
			seed = 7,
			tokens = { b = "moto" },
		})
		local seen: { [string]: boolean } = {}
		for _, player in state.players do
			expect(seen[player.tokenId]).toBe(nil)
			seen[player.tokenId] = true
			if player.id == "b" then
				expect(player.tokenId).toBe("moto")
			end
		end
	end)

	it("elegir ficha no cambia la partida de esa semilla", function()
		local without = State.create({ playerIds = { "a", "b" }, seed = 7 })
		local with = State.create({ playerIds = { "a", "b" }, seed = 7, tokens = { a = "grua" } })
		expect(with.rng.seed).toBe(without.rng.seed)
		expect(with.players[1].id).toBe(without.players[1].id)
	end)

	it("la vista enseña a todos la ficha de cada jugador", function()
		local state = State.create({ playerIds = { "a", "b" }, seed = 7, tokens = { a = "grua" } })
		local view = View.forPlayer(state, "b")
		for _, player in view.players do
			if player.id == "a" then
				expect(player.tokenId).toBe("grua")
			end
		end
	end)
end)

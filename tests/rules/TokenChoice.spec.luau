--!strict
local Harness = require("../harness")
local TokenChoice = require("../../src/shared/rules/TokenChoice")
local Tokens = require("../../src/shared/config/Tokens")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local PLAYERS = { "1", "2", "3", "4", "5", "6", "7", "8" }

describe("TokenChoice", function()
	it("reparte una ficha distinta por asiento", function()
		local assignments = TokenChoice.defaults(PLAYERS)
		local seen: { [string]: boolean } = {}
		for _, playerId in PLAYERS do
			local tokenId = assignments[playerId]
			expect(tokenId ~= nil).toBe(true)
			expect(seen[tokenId]).toBe(nil)
			seen[tokenId] = true
		end
		expect(#Tokens.ORDER).toBe(8)
	end)

	it("cambia a una ficha libre", function()
		local assignments = TokenChoice.defaults({ "1", "2", "3" })
		local wanted = Tokens.forSeat(8)
		local ok, err = TokenChoice.choose(assignments, "1", wanted)
		expect(ok).toBe(true)
		expect(err).toBe(nil)
		expect(assignments["1"]).toBe(wanted)
	end)

	it("en una mesa llena, elegir una ocupada intercambia las dos", function()
		local assignments = TokenChoice.defaults(PLAYERS)
		local mine = assignments["1"]
		local wanted = assignments["2"]
		local ok, err = TokenChoice.choose(assignments, "1", wanted)
		expect(ok).toBe(true)
		expect(err).toBe(nil)
		expect(assignments["1"]).toBe(wanted)
		expect(assignments["2"]).toBe(mine)

		-- Sigue habiendo exactamente una ficha por jugador, sin repetir.
		local seen: { [string]: boolean } = {}
		for _, playerId in PLAYERS do
			local tokenId = assignments[playerId]
			expect(tokenId ~= nil).toBe(true)
			expect(seen[tokenId]).toBe(nil)
			seen[tokenId] = true
		end
	end)

	it("rechaza una ficha que no existe y una ocupada sin ficha propia", function()
		local assignments = TokenChoice.defaults(PLAYERS)
		local ok, err = TokenChoice.choose(assignments, "1", "monopatín")
		expect(ok).toBe(false)
		expect(err).toBe("Esa ficha no existe.")

		local lonely = { ["2"] = "taxi" }
		local denied, deniedErr = TokenChoice.choose(lonely, "1", "taxi")
		expect(denied).toBe(false)
		expect(deniedErr).toBe("Esa ficha ya es de otro jugador.")
	end)

	it("se cierra en cuanto alguien sale de la Salida", function()
		expect(TokenChoice.locked({ 1, 1, 1 })).toBe(false)
		expect(TokenChoice.locked({ 1, 2, 1 })).toBe(true)
	end)
end)

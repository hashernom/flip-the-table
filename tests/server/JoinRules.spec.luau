--!strict
-- I7: el lugar de partida espera a su grupo sin dejar a nadie fuera ni a nadie esperando para siempre.
local Harness = require("../harness")
local JoinRules = require("../../src/server/match/JoinRules")
local Scenes = require("../../src/shared/config/Scenes")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

describe("JoinRules.decide con un grupo anunciado", function()
	it("arranca en cuanto están todos", function()
		expect(JoinRules.decide({ present = 4, expected = 4, sinceFirst = 0.5, sinceMinimum = 0.5 })).toBe(
			"Start"
		)
	end)

	it("sigue esperando a los que tardan más que la espera corta", function()
		expect(JoinRules.decide({
			present = 3,
			expected = 4,
			sinceFirst = Scenes.joinSec + 5,
			sinceMinimum = Scenes.joinSec + 5,
		})).toBe("Wait")
	end)

	it("al agotar la espera arranca con los que hay si son suficientes", function()
		expect(JoinRules.decide({
			present = 3,
			expected = 4,
			sinceFirst = Scenes.joinTimeoutSec,
			sinceMinimum = 1,
		})).toBe("Start")
	end)

	it("al agotar la espera con uno solo, se cancela", function()
		expect(JoinRules.decide({
			present = 1,
			expected = 4,
			sinceFirst = Scenes.joinTimeoutSec,
			sinceMinimum = nil,
		})).toBe("Abort")
	end)

	it("uno solo antes de agotar la espera sigue esperando", function()
		expect(JoinRules.decide({ present = 1, expected = 2, sinceFirst = 1, sinceMinimum = nil })).toBe(
			"Wait"
		)
	end)
end)

describe("JoinRules.decide en modo solo", function()
	it("un humano con bots ya es la mesa entera", function()
		expect(JoinRules.decide({ present = 1, expected = 4, sinceFirst = 0.1, bots = 3 })).toBe("Start")
	end)

	it("sin bots, uno solo sigue esperando al grupo", function()
		expect(JoinRules.decide({ present = 1, expected = 2, sinceFirst = 0.1, bots = 0 })).toBe("Wait")
	end)

	it("si falta parte del grupo, espera; al agotar la espera arranca con lo que hay", function()
		expect(JoinRules.decide({
			present = 1,
			expected = 5,
			sinceFirst = 0,
			sinceMinimum = 0,
			bots = 3,
		})).toBe("Wait")
		expect(JoinRules.decide({
			present = 1,
			expected = 5,
			sinceFirst = Scenes.joinTimeoutSec,
			sinceMinimum = 1,
			bots = 3,
		})).toBe("Start")
	end)
end)

describe("JoinRules.decide sin datos de entrada (Studio)", function()
	it("espera sin límite al segundo jugador", function()
		expect(JoinRules.decide({ present = 1, expected = nil, sinceFirst = 9999, sinceMinimum = nil })).toBe(
			"Wait"
		)
	end)

	it("da la espera corta desde que hay dos", function()
		expect(JoinRules.decide({ present = 2, expected = nil, sinceFirst = 100, sinceMinimum = 1 })).toBe(
			"Wait"
		)
		expect(JoinRules.decide({
			present = 2,
			expected = nil,
			sinceFirst = 100,
			sinceMinimum = Scenes.joinSec,
		})).toBe("Start")
	end)
end)

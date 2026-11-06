--!strict
-- Pruebas de las reglas puras de las escenas de cartas raras (plan 08, Tarea 4).
local CardSceneRules = require("../../src/client/scenes/cards/CardSceneRules")
local CardStaging = require("../../src/shared/config/CardStaging")
local Harness = require("../harness")
local Scenes = require("../../src/shared/config/Scenes")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function near(a: number, b: number, tolerance: number?): boolean
	return math.abs(a - b) <= (tolerance or 1e-6)
end

describe("CardStaging", function()
	it("las fracciones de cada rara suman 1 y cada paso tiene la suya", function()
		for _, name in { "demolition", "strike", "inflation", "backstab", "bounceRent" } do
			local staging = (CardStaging :: any)[name]
			local total = 0
			for _, step in staging.steps do
				expect(type(staging.fractions[step])).toBe("number")
				total += staging.fractions[step]
			end
			expect(near(total, 1, 1e-9)).toBe(true)
		end
	end)

	it("las raras duran de 2 a 4 s", function()
		for _, cardId in { "Demolition", "Strike", "Inflation", "Backstab", "BounceRent" } do
			local d = Scenes.durationFor({ type = "CardPlayed", cardId = cardId }, 0)
			expect(d >= 2 and d <= 4).toBe(true)
		end
	end)
end)

describe("CardSceneRules.swing", function()
	it("la bola está quieta antes de tomar impulso", function()
		expect(CardSceneRules.swing(0, 0, CardStaging.demolition)).toBe(0)
	end)

	it("toma impulso hacia atrás y golpea hacia el edificio", function()
		local staging = CardStaging.demolition
		expect(near(CardSceneRules.swing(1, 0, staging), -staging.windupRadians)).toBe(true)
		expect(near(CardSceneRules.swing(1, 1, staging), staging.strikeRadians)).toBe(true)
	end)

	it("el golpe pasa por la vertical a mitad de camino", function()
		local staging = CardStaging.demolition
		local middle = CardSceneRules.swing(1, 0.5, staging)
		expect(middle > -staging.windupRadians and middle < staging.strikeRadians).toBe(true)
	end)
end)

describe("CardSceneRules.rope", function()
	it("sale de un extremo, llega al otro y cuelga en medio", function()
		local a = { x = 0, y = 7, z = 0 }
		local b = { x = 20, y = 7, z = 0 }
		expect(CardSceneRules.rope(a, b, 0, 5)).toEqual(a)
		expect(CardSceneRules.rope(a, b, 1, 5)).toEqual(b)
		local middle = CardSceneRules.rope(a, b, 0.5, 5)
		expect(near(middle.x, 10) and near(middle.y, 2)).toBe(true)
	end)

	it("tensa no cuelga", function()
		local a = { x = 0, y = 7, z = 0 }
		local b = { x = 20, y = 7, z = 0 }
		expect(near(CardSceneRules.rope(a, b, 0.5, 0).y, 7)).toBe(true)
	end)
end)

describe("CardSceneRules.bounce", function()
	local from = { x = 0, y = 0, z = 0 }
	local via = { x = 10, y = 0, z = 0 }
	local to = { x = 30, y = 0, z = 0 }

	it("primero va de la propiedad al que debía pagar", function()
		local at = CardSceneRules.bounce(from, via, to, 0.5, 0, CardStaging.bounceRent)
		expect(near(at.x, 5)).toBe(true)
		expect(at.y > 0).toBe(true)
	end)

	it("y después rebota hasta el tercero", function()
		local done = CardSceneRules.bounce(from, via, to, 1, 1, CardStaging.bounceRent)
		expect(done).toEqual(to)
		local halfway = CardSceneRules.bounce(from, via, to, 1, 0.5, CardStaging.bounceRent)
		expect(near(halfway.x, 20)).toBe(true)
	end)
end)

describe("CardSceneRules.burst", function()
	it("sale del sitio, salta y vuelve al suelo", function()
		local staging = CardStaging.inflation
		local start = CardSceneRules.burst(0.25, 0, staging)
		expect(start.x == 0 and start.y == 0 and start.z == 0).toBe(true)
		local peak = CardSceneRules.burst(0.25, 0.5, staging)
		expect(near(peak.y, staging.billJump)).toBe(true)
		local landed = CardSceneRules.burst(0.25, 1, staging)
		expect(near(landed.y, 0)).toBe(true)
		local radius = math.sqrt(landed.x ^ 2 + landed.z ^ 2)
		expect(near(radius, staging.billSpread)).toBe(true)
	end)
end)

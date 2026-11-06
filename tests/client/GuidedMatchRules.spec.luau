--!strict
-- Primera partida guiada: qué consejo toca para cada cosa que pasa en la mesa. Son reglas puras: el
-- cliente les pasa los eventos de cada lote y la fase en que le toca decidir, y ellas dicen si hay un
-- consejo nuevo. Cada concepto se explica una sola vez.
local Harness = require("../harness")
local GuidedMatchRules = require("../../src/client/ui/GuidedMatchRules")
local Strings = require("../../src/shared/config/Strings")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

describe("GuidedMatchRules.tipFor", function()
	it("una renta da el consejo de renta", function()
		expect(GuidedMatchRules.tipFor({ type = "RentPaid" }, {})).toBe("rent")
	end)

	it("un consejo ya visto no vuelve a salir", function()
		local seen: { [string]: boolean } = {}
		local tip = GuidedMatchRules.tipFor({ type = "RentPaid" }, seen)
		expect(tip).toBe("rent")
		seen[tip :: string] = true
		expect(GuidedMatchRules.tipFor({ type = "RentPaid" }, seen)).toBe(nil)
	end)

	it("lo que no enseña nada no da consejo", function()
		expect(GuidedMatchRules.tipFor({ type = "TokenMoved" }, {})).toBe(nil)
		expect(GuidedMatchRules.tipFor({ type = "Unknown" }, {})).toBe(nil)
	end)

	it("cubre los ocho conceptos de la ficha y cada uno tiene su frase", function()
		local required = { "buy", "rent", "cards", "perks", "overview", "pacts", "tribunal", "ghost" }
		local covered: { [string]: boolean } = {}
		for _, tip in GuidedMatchRules.allTips() do
			covered[tip] = true
			-- Una frase corta: el consejo no detiene la partida ni obliga a leer un párrafo.
			local text = Strings.get(`guide.{tip}`)
			expect(#text > 0 and #text <= GuidedMatchRules.MAX_LENGTH).toBe(true)
		end
		for _, tip in required do
			expect(covered[tip] == true).toBe(true)
		end
	end)

	it("una decisión que llega también enseña: comprar y elegir perk", function()
		expect(GuidedMatchRules.tipFor(GuidedMatchRules.decisionEvent("AwaitBuy"), {})).toBe("buy")
		expect(GuidedMatchRules.tipFor(GuidedMatchRules.decisionEvent("PerkDraft"), {})).toBe("perks")
		expect(GuidedMatchRules.tipFor(GuidedMatchRules.decisionEvent("Tribunal"), {})).toBe("tribunal")
	end)
end)

describe("GuidedMatchRules.shouldGuide", function()
	it("solo guía a quien no ha terminado ninguna partida", function()
		expect(GuidedMatchRules.shouldGuide(0)).toBe(true)
		expect(GuidedMatchRules.shouldGuide(1)).toBe(false)
		expect(GuidedMatchRules.shouldGuide(12)).toBe(false)
	end)

	it("sin perfil cargado no guía: mejor callar que repetirle la guía a un veterano", function()
		expect(GuidedMatchRules.shouldGuide(nil)).toBe(false)
	end)
end)

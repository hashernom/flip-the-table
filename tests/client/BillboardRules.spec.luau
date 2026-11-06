--!strict
-- Pruebas del horario de la Cartelera: el marco se para siempre en la salida que decidió el motor, a su hora,
-- y frena de verdad (cada paso tarda más que el anterior).
local Harness = require("../harness")
local BillboardRules = require("../../src/client/ui/BillboardRules")
local Ui = require("../../src/shared/config/Ui")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

describe("BillboardRules.schedule", function()
	it("acaba en la salida ganadora, justo al final", function()
		for landed = 1, 5 do
			local ticks = BillboardRules.schedule(landed, 5, 1.4)
			local last = ticks[#ticks]
			expect(last.index).toBe(landed)
			expect(math.abs(last.at - 1.4) < 1e-9).toBe(true)
		end
	end)

	it("da sus vueltas por todas las salidas antes de pararse", function()
		local ticks = BillboardRules.schedule(3, 5, 1.4)
		expect(#ticks).toBe(Ui.billboard.laps * 5 + 3)
		for order, tick in ticks do
			expect(tick.index).toBe((order - 1) % 5 + 1)
		end
	end)

	it("frena: cada hueco entre pasos es mayor que el anterior", function()
		local ticks = BillboardRules.schedule(2, 5, 1.4)
		local previousGap = 0
		local previousAt = 0
		for _, tick in ticks do
			local gap = tick.at - previousAt
			expect(gap > previousGap).toBe(true)
			previousGap = gap
			previousAt = tick.at
		end
	end)
end)

describe("BillboardRules.toneFor", function()
	it("cada salida tiene su tono", function()
		expect(BillboardRules.toneFor("BigPrize")).toBe("Prize")
		expect(BillboardRules.toneFor("SmallPrize")).toBe("Prize")
		expect(BillboardRules.toneFor("Fine")).toBe("Fine")
		expect(BillboardRules.toneFor("Card")).toBe("Card")
		expect(BillboardRules.toneFor("Nothing")).toBe("Nothing")
	end)
end)

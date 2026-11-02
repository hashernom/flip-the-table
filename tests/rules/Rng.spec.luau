--!strict
local Harness = require("../harness")
local Rng = require("../../src/shared/rules/Rng")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

describe("Rng", function()
	it("repite la secuencia con la misma semilla", function()
		local a, b = Rng.new(42), Rng.new(42)
		for _ = 1, 100 do
			expect(Rng.int(a, 1, 6)).toBe(Rng.int(b, 1, 6))
		end
	end)

	it("cambia la secuencia con otra semilla", function()
		local a, b = Rng.new(1), Rng.new(2)
		local differs = false
		for _ = 1, 20 do
			if Rng.int(a, 1, 1000) ~= Rng.int(b, 1, 1000) then
				differs = true
			end
		end
		expect(differs).toBe(true)
	end)

	it("respeta el rango", function()
		local r = Rng.new(1)
		for _ = 1, 1000 do
			local v = Rng.int(r, 1, 6)
			expect(v >= 1 and v <= 6 and v == math.floor(v)).toBeTruthy()
		end
	end)

	it("alcanza todos los valores del rango", function()
		local r = Rng.new(7)
		local seen = {}
		for _ = 1, 500 do
			seen[Rng.int(r, 1, 6)] = true
		end
		expect(seen).toEqual({ true, true, true, true, true, true })
	end)

	it("avanza sin perder precisión con semillas grandes", function()
		local r = Rng.new(2 ^ 31 - 1)
		Rng.int(r, 1, 6)
		expect(r.seed).toBe(1043980748)
	end)

	it("usa primero los valores forzados", function()
		local r = Rng.new(1)
		Rng.force(r, { 3, 4 })
		expect(Rng.int(r, 1, 6)).toBe(3)
		expect(Rng.int(r, 1, 6)).toBe(4)
		expect(r.forced).toBe(nil)
	end)

	it("rechaza un rango invertido", function()
		expect(function()
			Rng.int(Rng.new(1), 6, 1)
		end).toThrow()
	end)

	it("mantiene la secuencia de referencia de la semilla 42", function()
		local r = Rng.new(42)
		local values = {}
		for i = 1, 10 do
			values[i] = Rng.int(r, 1, 1000)
		end
		expect(values).toEqual({ 583, 520, 466, 778, 423, 34, 418, 809, 613, 715 })
	end)

	it("rechaza límites que no son enteros finitos", function()
		for _, bounds in { { 0 / 0, 6 }, { 1, 0 / 0 }, { 1, math.huge }, { 1.5, 3.5 } } do
			expect(function()
				Rng.int(Rng.new(1), bounds[1], bounds[2])
			end).toThrow()
		end
	end)

	it("rechaza un valor forzado fuera de rango", function()
		local r = Rng.new(1)
		Rng.force(r, { 99 })
		expect(function()
			Rng.int(r, 1, 6)
		end).toThrow()
	end)

	it("rechaza un valor forzado que no es entero", function()
		local r = Rng.new(1)
		Rng.force(r, { 2.5 })
		expect(function()
			Rng.int(r, 1, 6)
		end).toThrow()
	end)

	it("trata una lista forzada vacía como azar normal", function()
		local r = Rng.new(42)
		Rng.force(r, {})
		expect(r.forced).toBe(nil)
		expect(Rng.int(r, 1, 1000)).toBe(583)
	end)

	it("rechaza una semilla no finita", function()
		expect(function()
			Rng.new(math.huge)
		end).toThrow()
	end)

	it("elige un elemento de la lista", function()
		local r = Rng.new(1)
		Rng.force(r, { 2 })
		expect(Rng.pick(r, { "a", "b", "c" })).toBe("b")
	end)

	it("rechaza elegir de una lista vacía", function()
		expect(function()
			Rng.pick(Rng.new(1), {})
		end).toThrow()
	end)

	it("baraja sin perder elementos ni tocar el original", function()
		local list = { 1, 2, 3, 4, 5 }
		local shuffled = Rng.shuffle(Rng.new(3), list)
		expect(list).toEqual({ 1, 2, 3, 4, 5 })
		table.sort(shuffled)
		expect(shuffled).toEqual({ 1, 2, 3, 4, 5 })
	end)
end)

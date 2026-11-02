--!strict
local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

describe("expect", function()
	it("compara tablas en profundidad", function()
		expect({ a = { 1, 2 } }).toEqual({ a = { 1, 2 } })
	end)

	it("detecta tablas distintas", function()
		expect(function()
			expect({ a = { 1, 2 } }).toEqual({ a = { 1, 3 } })
		end).toThrow()
	end)

	it("detecta tablas con claves de más", function()
		expect(function()
			expect({ a = 1, b = 2 }).toEqual({ a = 1 })
		end).toThrow()
	end)

	it("detecta valores primitivos distintos", function()
		expect(function()
			expect(1).toBe(2)
		end).toThrow()
	end)

	it("detecta errores lanzados", function()
		expect(function()
			error("x")
		end).toThrow()
	end)

	it("falla si la función no lanza nada", function()
		expect(function()
			expect(function() end).toThrow()
		end).toThrow()
	end)

	it("comprueba valores verdaderos", function()
		expect(true).toBeTruthy()
		expect(function()
			expect(false).toBeTruthy()
		end).toThrow()
	end)
end)

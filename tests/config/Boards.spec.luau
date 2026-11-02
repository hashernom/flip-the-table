--!strict
local Harness = require("../harness")
local Boards = require("../../src/shared/config/Boards")
local Economy = require("../../src/shared/config/Economy")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local EXPECTED: { [string]: { [string]: number } } = {
	S = {
		total = 32,
		zones = 6,
		Start = 1,
		Property = 18,
		Spin = 4,
		Market = 2,
		Duel = 2,
		Portal = 2,
		Billboard = 1,
		Tribunal = 1,
		Tax = 1,
	},
	M = {
		total = 40,
		zones = 8,
		Start = 1,
		Property = 24,
		Spin = 5,
		Market = 2,
		Duel = 2,
		Portal = 2,
		Billboard = 2,
		Tribunal = 1,
		Tax = 1,
	},
	L = {
		total = 48,
		zones = 10,
		Start = 1,
		Property = 30,
		Spin = 6,
		Market = 2,
		Duel = 3,
		Portal = 3,
		Billboard = 1,
		Tribunal = 1,
		Tax = 1,
	},
}

describe("Boards", function()
	it("elige el tamaño según los jugadores", function()
		expect(Boards.forPlayerCount(2)).toBe("S")
		expect(Boards.forPlayerCount(4)).toBe("S")
		expect(Boards.forPlayerCount(5)).toBe("M")
		expect(Boards.forPlayerCount(6)).toBe("M")
		expect(Boards.forPlayerCount(7)).toBe("L")
		expect(Boards.forPlayerCount(8)).toBe("L")
	end)

	it("rechaza un número de jugadores fuera de rango", function()
		expect(function()
			Boards.forPlayerCount(1)
		end).toThrow()
		expect(function()
			Boards.forPlayerCount(9)
		end).toThrow()
	end)

	for sizeId, expected in EXPECTED do
		describe(sizeId, function()
			local board = Boards.get(sizeId :: any)

			it("cumple la composición", function()
				local counts: { [string]: number } = {}
				for _, square in board.squares do
					counts[square.kind] = (counts[square.kind] or 0) + 1
				end
				expect(#board.squares).toBe(expected.total)
				for kind, count in expected do
					if kind ~= "total" and kind ~= "zones" then
						expect(counts[kind]).toBe(count)
					end
				end
			end)

			it("empieza en la Salida y numera las casillas", function()
				expect(board.squares[1].kind).toBe("Start")
				for index, square in board.squares do
					expect(square.index).toBe(index)
				end
			end)

			it("tiene zonas de 3 propiedades", function()
				local zoneCount = 0
				for _, indices in board.zones do
					zoneCount += 1
					expect(#indices).toBe(3)
					for _, index in indices do
						expect(board.squares[index].kind).toBe("Property")
					end
				end
				expect(zoneCount).toBe(expected.zones)
			end)

			it("ordena las zonas siguiendo la ruta", function()
				expect(#board.zoneOrder).toBe(expected.zones)
				local previous = 0
				for _, zoneId in board.zoneOrder do
					local first = board.zones[zoneId][1]
					expect(first > previous).toBeTruthy()
					previous = first
				end
			end)

			it("sube los precios de 60 a 400 a lo largo de la ruta", function()
				local previous = 0
				local last = 0
				for _, square in board.squares do
					if square.kind == "Property" then
						local price = square.price :: number
						expect(price >= previous).toBeTruthy()
						if previous == 0 then
							expect(price).toBe(60)
						end
						previous = price
						last = price
					else
						expect(square.price).toBe(nil)
					end
				end
				expect(last).toBe(400)
			end)
		end)
	end

	it("añade barrios sin renombrar las zonas de Centro", function()
		local function zoneIds(sizeId: any): { [string]: boolean }
			local ids = {}
			for zoneId in Boards.get(sizeId).zones do
				ids[zoneId] = true
			end
			return ids
		end
		local small, medium, large = zoneIds("S"), zoneIds("M"), zoneIds("L")
		for zoneId in small do
			expect(medium[zoneId]).toBe(true)
			expect(large[zoneId]).toBe(true)
		end
		for zoneId in medium do
			expect(large[zoneId]).toBe(true)
		end
	end)

	it("usa los barrios de cada tamaño", function()
		local function barrios(sizeId: any): { [string]: boolean }
			local found = {}
			for _, square in Boards.get(sizeId).squares do
				found[square.barrioId] = true
			end
			return found
		end
		expect(barrios("S")).toEqual({ Centro = true })
		expect(barrios("M")).toEqual({ Centro = true, Puerto = true })
		expect(barrios("L")).toEqual({ Centro = true, Puerto = true, ZonaAlta = true })
	end)

	it("devuelve un tablero independiente en cada llamada", function()
		local first = Boards.get("S")
		first.squares[1].kind = "Tax"
		expect(Boards.get("S").squares[1].kind).toBe("Start")
	end)
end)

describe("Economy", function()
	it("fija los valores iniciales de la arquitectura", function()
		expect(Economy.startingCash).toBe(1500)
		expect(Economy.startBonus).toBe(200)
		expect(Economy.rounds).toEqual({ S = 20, M = 15, L = 12 })
		expect(Economy.maxRentMultiplier).toBe(4)
		expect(Economy.buildingRentMultiplier).toEqual({ 3, 6, 10 })
	end)
end)

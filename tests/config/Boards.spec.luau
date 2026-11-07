--!strict
local Harness = require("../harness")
local Boards = require("../../src/shared/config/Boards")
local Economy = require("../../src/shared/config/Economy")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

type SizeId = "S" | "M" | "L"

local SIZES: { SizeId } = { "S", "M", "L" }

-- Composición de la arquitectura: 40, 48 y 56 casillas (docs/02-mvp/contenido-tablero.md).
local EXPECTED: { [SizeId]: { [string]: number } } = {
	S = {
		total = 40,
		zones = 8,
		Start = 1,
		Property = 22,
		Spin = 6,
		Market = 2,
		Duel = 2,
		Portal = 3,
		Billboard = 2,
		Tribunal = 1,
		Tax = 1,
	},
	M = {
		total = 48,
		zones = 10,
		Start = 1,
		Property = 28,
		Spin = 7,
		Market = 2,
		Duel = 2,
		Portal = 3,
		Billboard = 3,
		Tribunal = 1,
		Tax = 1,
	},
	L = {
		total = 56,
		zones = 12,
		Start = 1,
		Property = 34,
		Spin = 8,
		Market = 2,
		Duel = 2,
		Portal = 3,
		Billboard = 4,
		Tribunal = 1,
		Tax = 1,
	},
}

-- Zonas en orden de ruta, con sus propiedades, barrio y precio en cada tablero. El precio de una
-- misma zona cambia según el tamaño: la tabla de la arquitectura manda.
type ZoneSpec = {
	id: string,
	properties: number,
	barrio: string,
	prices: { [SizeId]: number },
}

local ZONES: { ZoneSpec } = {
	{ id = "cobre", properties = 2, barrio = "Centro", prices = { S = 60, M = 60, L = 60 } },
	{ id = "cian", properties = 3, barrio = "Centro", prices = { S = 110, M = 100, L = 90 } },
	{ id = "magenta", properties = 3, barrio = "Centro", prices = { S = 160, M = 140, L = 120 } },
	{ id = "naranja", properties = 3, barrio = "Centro", prices = { S = 210, M = 170, L = 150 } },
	{ id = "carmesi", properties = 3, barrio = "Centro", prices = { S = 250, M = 210, L = 180 } },
	{ id = "limon", properties = 3, barrio = "Centro", prices = { S = 300, M = 250, L = 220 } },
	{ id = "esmeralda", properties = 3, barrio = "Puerto", prices = { S = 350, M = 290, L = 250 } },
	{ id = "violeta", properties = 2, barrio = "Puerto", prices = { S = 400, M = 320, L = 280 } },
	{ id = "anil", properties = 3, barrio = "ZonaAlta", prices = { M = 360, L = 310 } },
	{ id = "blanca", properties = 3, barrio = "ZonaAlta", prices = { M = 400, L = 340 } },
	{ id = "grafito", properties = 3, barrio = "Industrial", prices = { L = 370 } },
	{ id = "ocre", properties = 3, barrio = "Industrial", prices = { L = 400 } },
}

local CORNERS: { string } = { "Start", "Tribunal", "Tax", "Portal" }

local function zoneSpec(zoneId: string): ZoneSpec
	for _, spec in ZONES do
		if spec.id == zoneId then
			return spec
		end
	end
	error(`la zona {zoneId} no está en la tabla de la arquitectura`, 2)
end

local function expectedZones(sizeId: SizeId): { string }
	local ids: { string } = {}
	for index = 1, EXPECTED[sizeId].zones do
		ids[index] = ZONES[index].id
	end
	return ids
end

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

	for sizeIndex = 1, #SIZES do
		local sizeId: SizeId = SIZES[sizeIndex]
		describe(sizeId, function()
			local board = Boards.get(sizeId)
			local expected = EXPECTED[sizeId]

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

			it("tiene las esquinas en los cuartos del tablero", function()
				local quarter = expected.total / 4
				for corner = 1, #CORNERS do
					local index = (corner - 1) * quarter + 1
					expect(board.squares[index].kind).toBe(CORNERS[corner])
				end
			end)

			it("ordena las 12 zonas de la arquitectura", function()
				expect(#board.zoneOrder).toBe(expected.zones)
				expect(board.zoneOrder).toEqual(expectedZones(sizeId))
			end)

			it("agrupa 2 o 3 propiedades contiguas por zona", function()
				local pending = 0
				for _, zoneId in board.zoneOrder do
					local indices = board.zones[zoneId]
					local spec = zoneSpec(zoneId)
					expect(#indices).toBe(spec.properties)
					for position, index in indices do
						expect(index > pending).toBe(true)
						expect(board.squares[index].kind).toBe("Property")
						expect(board.squares[index].zoneId).toBe(zoneId)
						expect(board.squares[index].barrioId).toBe(spec.barrio)
						if position > 1 then
							expect(index).toBe(indices[position - 1] + 1)
						end
						pending = index
					end
				end
			end)

			it("cobra el precio de la arquitectura en cada zona", function()
				for _, zoneId in board.zoneOrder do
					local spec = zoneSpec(zoneId)
					local price = spec.prices[sizeId]
					for _, index in board.zones[zoneId] do
						expect(board.squares[index].price).toBe(price)
					end
				end
			end)

			it("crece de 60 a 400 a lo largo de la ruta", function()
				local previous = 0
				local last = 0
				for _, square in board.squares do
					if square.kind == "Property" then
						local price = square.price :: number
						expect(price >= previous).toBeTruthy()
						previous = price
						last = price
					else
						expect(square.price).toBe(nil)
					end
				end
				expect(board.squares[board.zones[board.zoneOrder[1]][1]].price).toBe(60)
				expect(last).toBe(400)
			end)

			it("usa los barrios que añade cada tamaño", function()
				local found: { [string]: boolean } = {}
				for _, square in board.squares do
					found[square.barrioId] = true
				end
				local expectedBarrios: { [string]: boolean } = { Centro = true, Puerto = true }
				if sizeId ~= "S" then
					expectedBarrios.ZonaAlta = true
				end
				if sizeId == "L" then
					expectedBarrios.Industrial = true
				end
				expect(found).toEqual(expectedBarrios)
			end)
		end)
	end

	it("encadena S, M y L sin renombrar zonas", function()
		local function zonesOf(sizeId: SizeId): { string }
			return Boards.get(sizeId).zoneOrder
		end
		local small, medium, large = zonesOf("S"), zonesOf("M"), zonesOf("L")
		expect(#small).toBe(8)
		expect(#medium).toBe(10)
		expect(#large).toBe(12)
		for index = 1, #small do
			expect(medium[index]).toBe(small[index])
		end
		for index = 1, #medium do
			expect(large[index]).toBe(medium[index])
		end
		-- Las mismas zonas conservan sus propiedades y su barrio en los tres tableros.
		for _, zoneId in small do
			local spec = zoneSpec(zoneId)
			for sizeIndex = 1, #SIZES do
				local sizeId: SizeId = SIZES[sizeIndex]
				expect(#Boards.get(sizeId).zones[zoneId]).toBe(spec.properties)
			end
		end
	end)

	it("devuelve un tablero independiente en cada llamada", function()
		local first = Boards.get("S")
		first.squares[1].kind = "Tax"
		first.zones[first.zoneOrder[1]][1] = 0
		expect(Boards.get("S").squares[1].kind).toBe("Start")
		expect(Boards.get("S").zones[first.zoneOrder[1]][1]).toBe(2)
	end)
end)

describe("Economy", function()
	it("fija los valores iniciales de la arquitectura", function()
		expect(Economy.startingCash).toBe(1500)
		expect(Economy.startBonus).toBe(200)
		expect(Economy.rounds).toEqual({ S = 20, M = 15, L = 12 })
		expect(Economy.maxRentMultiplier).toBe(4)
		expect(Economy.completeZoneRentMultiplier).toBe(2)
		expect(Economy.maxBuildingLevel).toBe(5)
		expect(Economy.buildingRentMultiplier).toEqual({ 2, 5, 12, 24, 32 })
		expect(Economy.rentRounding).toBe(5)
		expect(Economy.buildingCostRate).toBe(0.5)
	end)
end)

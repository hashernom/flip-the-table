--!strict
-- Piezas de mejora sobre la isla de la casilla (art/edificios/niveles.md): casas, hotel y rascacielos.
local CityLayout = require("../../src/shared/config/CityLayout")
local Harness = require("../harness")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function kinds(level: number): { string }
	local list: { string } = {}
	for _, marker in CityLayout.islandMarkers(level) do
		table.insert(list, marker.kind)
	end
	return list
end

describe("CityLayout.islandMarkers", function()
	it("de 1 a 3 casas, hotel en el 4 y rascacielos en el 5", function()
		expect(kinds(0)).toEqual({})
		expect(kinds(1)).toEqual({ "House" })
		expect(kinds(2)).toEqual({ "House", "House" })
		expect(kinds(3)).toEqual({ "House", "House", "House" })
		expect(kinds(4)).toEqual({ "Hotel" })
		expect(kinds(5)).toEqual({ "Tower" })
	end)

	it("las casas caben en la casilla y van centradas", function()
		local markers = CityLayout.islandMarkers(3)
		local sum = 0
		for _, marker in markers do
			sum += marker.along
			expect(math.abs(marker.along) < CityLayout.PAINT_ALONG_STUDS / 2 - 2).toBe(true)
		end
		expect(math.abs(sum) < 1e-9).toBe(true)
	end)
end)

describe("CityLayout.islandCenter", function()
	it("la isla queda del lado del edificio, dentro del marco", function()
		for _, sizeId in { "S", "M", "L" } do
			for _, slot in CityLayout.routeFor(sizeId :: any) do
				if slot.kind == "Property" then
					local center, toward = CityLayout.islandCenter(slot)
					local lot = CityLayout.lotCenter(slot)
					-- El edificio está hacia `toward`: el solar queda más allá de la isla en esa dirección.
					local dx, dz = lot.x - slot.position.x, lot.z - slot.position.z
					expect(dx * toward.x + dz * toward.z > 0).toBe(true)
					local ox, oz = center.x - slot.position.x, center.z - slot.position.z
					local reach = math.sqrt(ox * ox + oz * oz)
					expect(reach < CityLayout.PAINT_ACROSS_STUDS / 2).toBe(true)
				end
			end
		end
	end)
end)

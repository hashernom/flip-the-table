--!strict
-- Pruebas de la ciudad procedural del interior del anillo y del borde exterior. Comprueban lo que se ve
-- desde la vista aérea: que el interior está lleno de manzanas variadas, que el centro es un parque con
-- plaza y fuente, que nada pisa la calle ni los solares, y que todos los clientes construyen lo mismo.
local Harness = require("../harness")
local CityInterior = require("../../src/shared/config/CityInterior")
local CityLayout = require("../../src/shared/config/CityLayout")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

-- Como en Barrios.spec: el analizador no estrecha la tabla literal al tipo del tamaño.
local SIZES: { any } = { "S", "M", "L" }

-- Hasta dónde llegan los solares del interior, desde el eje de la calle.
local LOT_REACH = CityLayout.STREET_WIDTH_STUDS / 2 + CityLayout.SIDEWALK_STUDS + CityLayout.LOT_DEPTH_STUDS

-- Media anchura de una pieza en x y en z, con su giro. Un disco es redondo; un giro recto cambia los ejes;
-- cualquier otro giro se mide por la diagonal.
local function extents(item: CityInterior.Item): (number, number)
	if item.shape == "Disk" then
		return item.sx / 2, item.sx / 2
	end
	local quarter = item.yaw / (math.pi / 2)
	local rounded = math.floor(quarter + 0.5)
	if math.abs(quarter - rounded) < 1e-6 then
		if rounded % 2 == 0 then
			return item.sx / 2, item.sz / 2
		end
		return item.sz / 2, item.sx / 2
	end
	local radius = math.sqrt(item.sx * item.sx + item.sz * item.sz) / 2
	return radius, radius
end

describe("CityInterior.cellsFor", function()
	it("reparte el interior en manzanas y el centro es la plaza", function()
		for _, sizeId in SIZES do
			local cells = CityInterior.cellsFor(sizeId)
			expect(#cells >= 9).toBe(true)
			local center = CityLayout.centerFor(sizeId)
			local plazas = 0
			for _, cell in cells do
				if cell.kind == "Plaza" then
					plazas += 1
					expect(cell.x0 < center.x and center.x < cell.x1).toBe(true)
					expect(cell.z0 < center.z and center.z < cell.z1).toBe(true)
				end
			end
			expect(plazas).toBe(1)
		end
	end)

	it("hay variedad: torres, casas, parques y canchas en cada tamaño", function()
		for _, sizeId in SIZES do
			local kinds: { [string]: boolean } = {}
			for _, cell in CityInterior.cellsFor(sizeId) do
				kinds[cell.kind] = true
			end
			for _, kind in { "Towers", "Houses", "Park", "Court" } do
				if not kinds[kind] then
					error(`la ciudad {sizeId} no tiene manzana {kind}`, 2)
				end
			end
		end
	end)

	it("ninguna manzana pisa los solares del interior", function()
		for _, sizeId in SIZES do
			local span = CityLayout.spanFor(sizeId)
			for _, cell in CityInterior.cellsFor(sizeId) do
				expect(cell.x0 >= LOT_REACH and cell.z0 >= LOT_REACH).toBe(true)
				expect(cell.x1 <= span - LOT_REACH and cell.z1 <= span - LOT_REACH).toBe(true)
			end
		end
	end)
end)

describe("CityInterior.itemsFor", function()
	it("todas las piezas caen dentro del interior, sin tocar la calle ni los solares", function()
		for _, sizeId in SIZES do
			local span = CityLayout.spanFor(sizeId)
			for _, item in CityInterior.itemsFor(sizeId) do
				local hx, hz = extents(item)
				expect(item.x - hx >= LOT_REACH - 0.01).toBe(true)
				expect(item.x + hx <= span - LOT_REACH + 0.01).toBe(true)
				expect(item.z - hz >= LOT_REACH - 0.01).toBe(true)
				expect(item.z + hz <= span - LOT_REACH + 0.01).toBe(true)
			end
		end
	end)

	it("cada pieza tiene forma, tamaño positivo y un color en hexadecimal", function()
		for _, item in CityInterior.itemsFor("M") do
			expect(CityInterior.SHAPES[item.shape]).toBe(true)
			expect(item.sx > 0 and item.sy > 0 and item.sz > 0).toBe(true)
			expect(string.match(item.color, "^#%x%x%x%x%x%x$") ~= nil).toBe(true)
			expect(CityInterior.MATERIALS[item.material]).toBe(true)
		end
	end)

	it("la plaza central tiene fuente con agua", function()
		for _, sizeId in SIZES do
			local found = false
			for _, item in CityInterior.itemsFor(sizeId) do
				if item.name == "FountainWater" then
					found = true
				end
			end
			expect(found).toBe(true)
		end
	end)

	it("todos los clientes construyen la misma ciudad", function()
		expect(CityInterior.itemsFor("L")).toEqual(CityInterior.itemsFor("L"))
	end)

	it("interior y exterior juntos caben en el presupuesto de piezas", function()
		for _, sizeId in SIZES do
			local total = #CityInterior.itemsFor(sizeId) + #CityInterior.exteriorFor(sizeId)
			expect(total <= CityInterior.MAX_PARTS).toBe(true)
		end
	end)
end)

describe("CityInterior.exteriorFor", function()
	-- Borde de la acera de fuera, desde el eje de la calle.
	local SIDEWALK_EDGE = CityLayout.STREET_WIDTH_STUDS / 2 + CityLayout.SIDEWALK_STUDS

	it("llena el borde exterior sin pisar la calle ni la acera", function()
		for _, sizeId in SIZES do
			local span = CityLayout.spanFor(sizeId)
			local items = CityInterior.exteriorFor(sizeId)
			expect(#items > 0).toBe(true)
			for _, item in items do
				local outside = item.x < -SIDEWALK_EDGE
					or item.x > span + SIDEWALK_EDGE
					or item.z < -SIDEWALK_EDGE
					or item.z > span + SIDEWALK_EDGE
				expect(outside).toBe(true)
			end
		end
	end)

	it("no pone nada delante de una casilla especial ni de la cárcel: ahí está su lugar", function()
		for _, sizeId in SIZES do
			local items = CityInterior.exteriorFor(sizeId)
			for _, slot in CityLayout.routeFor(sizeId) do
				if CityLayout.lotSideOf(slot) > 0 or slot.kind == "Tribunal" then
					local lot = CityLayout.outsideLotCenter(slot)
					for _, item in items do
						local dx, dz = item.x - lot.x, item.z - lot.z
						local near = math.abs(dx) < CityLayout.LOT_WIDTH_STUDS / 2
							and math.abs(dz) < CityLayout.LOT_WIDTH_STUDS / 2
						if near then
							error(`{item.name} pisa el lugar de la casilla {slot.index} en {sizeId}`, 2)
						end
					end
				end
			end
		end
	end)

	it("da vida a la franja verde delante de las propiedades, sin llenarla entera", function()
		for _, sizeId in SIZES do
			local spots = CityInterior.vergeFor(sizeId)
			local eligible = 0
			for _, slot in CityLayout.routeFor(sizeId) do
				if CityInterior.vergeOpen(slot) then
					eligible += 1
				end
			end
			local kinds: { [string]: boolean } = {}
			local filled = 0
			for _, spot in spots do
				if spot.kind ~= "Empty" then
					filled += 1
					kinds[spot.kind] = true
				end
			end
			expect(filled > 0 and filled < eligible).toBe(true)
			local variety = 0
			for _ in kinds do
				variety += 1
			end
			expect(variety >= 3).toBe(true)
		end
	end)
end)

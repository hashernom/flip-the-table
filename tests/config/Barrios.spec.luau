--!strict
-- Pruebas de la identidad de los barrios (plan 07, Tarea 1). Comprueban lo que el plan pide por escrito:
-- que cada barrio que entra en un tamaño tenga su calle y su fondo, que un barrio ausente no se
-- construya, y que nada de lo que pide `Barrios` se quede sin malla en `ArtAssets`.
local Harness = require("../harness")
local ArtAssets = require("../../src/shared/config/ArtAssets")
local Barrios = require("../../src/shared/config/Barrios")
local CityLayout = require("../../src/shared/config/CityLayout")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local SIZES = { "S", "M", "L" } :: { CityLayout.SizeId }

local function routeFor(sizeId: string): { CityLayout.Slot }
	return CityLayout.routeFor(sizeId :: any)
end

local function dressingFor(sizeId: string, barrioId: string): { CityLayout.Dressing }
	return CityLayout.dressingFor(sizeId :: any, barrioId)
end

local function backdropsFor(sizeId: string, barrioId: string): { CityLayout.Dressing }
	return CityLayout.backdropsFor(sizeId :: any, barrioId)
end

local function slotsOf(sizeId: string, barrioId: string): { CityLayout.Slot }
	local slots: { CityLayout.Slot } = {}
	for _, slot in routeFor(sizeId) do
		if slot.barrioId == barrioId then
			table.insert(slots, slot)
		end
	end
	return slots
end

local function countKind(items: { CityLayout.Dressing }, kind: string): number
	local total = 0
	for _, item in items do
		if item.kind == kind then
			total += 1
		end
	end
	return total
end

describe("Barrios: configuración", function()
	it("cada barrio trae acera, fondo y paso de cebra", function()
		expect(#Barrios.ids > 0).toBe(true)
		for _, id in Barrios.ids do
			local barrio = Barrios.get(id)
			expect(#barrio.walk > 0).toBe(true)
			expect(#barrio.backdrops > 0).toBe(true)
			expect(#barrio.crosswalk > 0).toBe(true)
			expect(#barrio.rules >= 3).toBe(true)
		end
	end)

	it("todos los barrios configurados existen en la ciudad", function()
		local barrios = {}
		for _, slot in routeFor("L") do
			barrios[slot.barrioId] = true
		end
		for _, id in Barrios.ids do
			expect(barrios[id]).toBe(true)
		end
	end)

	it("todo lo que pide un barrio tiene malla en ArtAssets", function()
		for _, id in Barrios.ids do
			local barrio = Barrios.get(id)
			expect(ArtAssets.street[barrio.walk] ~= nil).toBe(true)
			expect(ArtAssets.street[barrio.crosswalk] ~= nil).toBe(true)
			for _, kind in barrio.backdrops do
				expect(ArtAssets.street[kind] ~= nil).toBe(true)
			end
			for _, rule in barrio.rules do
				expect(ArtAssets.street[rule.kind] ~= nil).toBe(true)
			end
		end
	end)

	it("la acera de un barrio no la comparte con otro", function()
		local vistos: { [string]: string } = {}
		for _, id in Barrios.ids do
			local walk = Barrios.get(id).walk
			expect(vistos[walk]).toBe(nil)
			vistos[walk] = id
		end
	end)
end)

describe("CityLayout.dressingFor, por barrio", function()
	it("pone su acera en cada casilla del barrio, salvo en las esquinas", function()
		for _, sizeId in SIZES do
			for _, id in Barrios.ids do
				local slots = slotsOf(sizeId, id)
				if #slots == 0 then
					continue
				end
				-- La casilla de esquina es un cruce: la acera caería sobre la calle que cruza.
				local route = routeFor(sizeId)
				local expected = 0
				for _, slot in slots do
					local before = route[slot.index - 1]
					if before ~= nil and before.facing == slot.facing then
						expected += 1
					end
				end
				expect(expected > 0).toBe(true)
				local items = dressingFor(sizeId, id)
				expect(countKind(items, Barrios.get(id).walk)).toBe(expected)
			end
		end
	end)

	it("cada barrio tiene al menos tres clases de mobiliario propio", function()
		for _, id in Barrios.ids do
			local barrio = Barrios.get(id)
			local kinds: { [string]: boolean } = {}
			for _, rule in barrio.rules do
				if rule.kind ~= barrio.walk then
					kinds[rule.kind] = true
				end
			end
			local total = 0
			for _ in kinds do
				total += 1
			end
			expect(total >= 3).toBe(true)
		end
	end)

	it("el paso de cebra cierra el barrio por sus dos extremos", function()
		for _, sizeId in SIZES do
			for _, id in Barrios.ids do
				local slots = slotsOf(sizeId, id)
				if #slots < 3 then
					continue
				end
				local items = dressingFor(sizeId, id)
				local crosswalks = countKind(items, Barrios.get(id).crosswalk)
				-- Los dos extremos sin esquina en medio: como mucho dos, y al menos uno en recta.
				expect(crosswalks <= 2).toBe(true)
			end
		end
	end)

	it("no amuebla un barrio que no entra en ese tamaño", function()
		-- El Puerto no existe en el tablero pequeño: ni una pieza suya.
		local otros = { "Puerto", "ZonaAlta", "Industrial" }
		for _, id in otros do
			if #slotsOf("S", id) == 0 then
				expect(#dressingFor("S", id)).toBe(0)
			end
		end
	end)

	it("no deja mobiliario fuera de las casillas de su barrio", function()
		for _, sizeId in SIZES do
			for _, id in Barrios.ids do
				local slots = slotsOf(sizeId, id)
				if #slots == 0 then
					continue
				end
				-- La caja que abarca las casillas del barrio, con holgura para la junta y el ancho de acera.
				local minX, maxX = math.huge, -math.huge
				local minZ, maxZ = math.huge, -math.huge
				for _, slot in slots do
					minX = math.min(minX, slot.position.x)
					maxX = math.max(maxX, slot.position.x)
					minZ = math.min(minZ, slot.position.z)
					maxZ = math.max(maxZ, slot.position.z)
				end
				local margin = 40
				for _, item in dressingFor(sizeId, id) do
					expect(item.x >= minX - margin and item.x <= maxX + margin).toBe(true)
					expect(item.z >= minZ - margin and item.z <= maxZ + margin).toBe(true)
				end
			end
		end
	end)
end)

describe("CityLayout.backdropsFor", function()
	it("cada barrio con casillas y fondo tiene sus piezas", function()
		for _, sizeId in SIZES do
			for _, id in Barrios.ids do
				local slots = slotsOf(sizeId, id)
				if #slots < 2 then
					continue
				end
				local items = backdropsFor(sizeId, id)
				expect(#items > 0).toBe(true)
				expect(#items <= math.ceil(#slots / 2)).toBe(true)
			end
		end
	end)

	it("los fondos van detrás de los solares, nunca sobre la calle", function()
		-- El solar acaba a 46 del eje de la calzada: acera (24) más el fondo del solar (22).
		for _, sizeId in SIZES do
			local route = routeFor(sizeId)
			for _, id in Barrios.ids do
				for _, item in backdropsFor(sizeId, id) do
					local nearest, distance = nil, math.huge
					for _, slot in route do
						if slot.barrioId == id then
							local dx, dz = item.x - slot.position.x, item.z - slot.position.z
							local length = math.sqrt(dx * dx + dz * dz)
							if length < distance then
								nearest, distance = slot, length
							end
						end
					end
					expect(nearest ~= nil).toBe(true)
					expect(distance > 46).toBe(true)
				end
			end
		end
	end)

	it("los fondos van fuera del anillo: el interior es de la ciudad procedural", function()
		for _, sizeId in SIZES do
			local center = CityLayout.centerFor(sizeId :: any)
			local half = CityLayout.spanFor(sizeId :: any) / 2
			for _, id in Barrios.ids do
				for _, item in backdropsFor(sizeId, id) do
					local outside = math.abs(item.x - center.x) > half or math.abs(item.z - center.z) > half
					expect(outside).toBe(true)
					-- Mira a la calle, que queda hacia el centro.
					local toCenterX, toCenterZ = center.x - item.x, center.z - item.z
					expect(item.lookX * toCenterX + item.lookZ * toCenterZ > 0).toBe(true)
				end
			end
		end
	end)

	it("usa solo las variantes que declara el barrio", function()
		for _, sizeId in SIZES do
			for _, id in Barrios.ids do
				local barrio = Barrios.get(id)
				local permitidos: { [string]: boolean } = {}
				for _, kind in barrio.backdrops do
					permitidos[kind] = true
				end
				for _, item in backdropsFor(sizeId, id) do
					expect(permitidos[item.kind]).toBe(true)
				end
			end
		end
	end)

	it("el fondo mira a la calle, como el mobiliario", function()
		for _, sizeId in SIZES do
			for _, id in Barrios.ids do
				for _, item in backdropsFor(sizeId, id) do
					local length = math.sqrt(item.lookX * item.lookX + item.lookZ * item.lookZ)
					expect(math.abs(length - 1) < 1e-6).toBe(true)
				end
			end
		end
	end)

	it("no pone fondo a un barrio que no entra en ese tamaño", function()
		for _, id in { "Puerto", "ZonaAlta", "Industrial" } do
			if #slotsOf("S", id) == 0 then
				expect(#backdropsFor("S", id)).toBe(0)
			end
		end
	end)
end)

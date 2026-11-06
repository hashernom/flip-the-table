--!strict
local Harness = require("../harness")
local ArtAssets = require("../../src/shared/config/ArtAssets")
local Barrios = require("../../src/shared/config/Barrios")
local CityLayout = require("../../src/shared/config/CityLayout")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

describe("ArtAssets", function()
	it("una propiedad sin modelo se queda en gris", function()
		-- Las 34 propiedades del tablero ya tienen modelo (zonas 01 a 12), así que el caso «sin
		-- modelo» se comprueba con un nombre que no está registrado: `piecesFor` debe devolver nil.
		expect(ArtAssets.piecesFor("Propiedad Sin Modelo", 3)).toBe(nil)
	end)

	it("cada nivel suma su añadido y nunca quita el cuerpo", function()
		local base = ArtAssets.piecesFor("Cine Lux", 0) :: { ArtAssets.Piece }
		local top = ArtAssets.piecesFor("Cine Lux", 5) :: { ArtAssets.Piece }
		expect(#top >= #base + 5).toBe(true)
		expect(top[1].key).toBe(base[1].key)
	end)

	it("todo el mobiliario se carga y cada barrio coloca piezas que existen", function()
		local loaded: { [string]: boolean } = {}
		for _, piece in ArtAssets.all() do
			loaded[piece.key] = true
		end
		local sizes = { "S", "M", "L" } :: { CityLayout.SizeId }
		for _, sizeId in sizes do
			for _, barrioId in CityLayout.barriosFor(sizeId :: any) do
				-- Un barrio sin sus mallas todavía no amuebla nada; cuando las tenga, esto lo comprueba.
				if not Barrios.has(barrioId) then
					continue
				end
				local items = CityLayout.dressingFor(sizeId :: any, barrioId)
				expect(#items > 0).toBe(true)
				for _, item in items do
					local pieces = ArtAssets.street[item.kind]
					expect(pieces ~= nil).toBe(true)
					for _, piece in pieces do
						expect(loaded[piece.key]).toBe(true)
					end
				end
			end
		end
	end)

	it("el mobiliario va en la acera y la cebra en la calzada", function()
		local barrio = Barrios.get("Centro")
		local route = CityLayout.routeFor("S")
		-- Distancia al eje de la calle de la casilla más cercana: la calle es un anillo, así que no vale
		-- medir contra los cuatro ejes del cuadrado cuando la casilla está en una esquina.
		local function fromAxis(item: CityLayout.Dressing): number
			local nearest, best = nil, math.huge
			for _, slot in route do
				local dx, dz = item.x - slot.position.x, item.z - slot.position.z
				local square = dx * dx + dz * dz
				if square < best then
					nearest, best = slot, square
				end
			end
			local slot = nearest :: CityLayout.Slot
			local outX, outZ = math.cos(slot.facing), -math.sin(slot.facing)
			return math.abs((item.x - slot.position.x) * outX + (item.z - slot.position.z) * outZ)
		end

		local first, last = math.huge, -math.huge
		for index, slot in route do
			if slot.barrioId == "Centro" then
				first, last = math.min(first, index), math.max(last, index)
			end
		end
		-- La cebra cierra el barrio por cada extremo que dé a una recta: en una esquina ya hay cruce.
		local expected = 0
		if route[first - 1] ~= nil and route[first - 1].facing == route[first].facing then
			expected += 1
		end
		if route[last + 1] ~= nil and route[last + 1].facing == route[last].facing then
			expected += 1
		end

		local crosswalks = 0
		for _, item in CityLayout.dressingFor("S", "Centro") do
			local distance = fromAxis(item)
			if item.kind == barrio.crosswalk then
				crosswalks += 1
				expect(distance < 1e-6).toBe(true)
			else
				expect(distance >= CityLayout.STREET_WIDTH_STUDS / 2).toBe(true)
				expect(distance <= CityLayout.STREET_WIDTH_STUDS / 2 + CityLayout.SIDEWALK_STUDS).toBe(true)
			end
		end
		expect(crosswalks).toBe(expected)
	end)

	it("el tráfico da la vuelta sin saltos, en su carril y mirando hacia donde va", function()
		local span = CityLayout.spanFor("S")
		local length = CityLayout.trafficLength("S")
		local lane = CityLayout.TRAFFIC_LANE_STUDS
		local lastX, lastZ = CityLayout.trafficPose("S", 0)
		local step = 1
		for distance = step, length, step do
			local x, z, forwardX, forwardZ = CityLayout.trafficPose("S", distance)
			expect(math.abs(math.sqrt(forwardX ^ 2 + forwardZ ^ 2) - 1) < 1e-6).toBe(true)
			expect(math.sqrt((x - lastX) ^ 2 + (z - lastZ) ^ 2) <= step + 1e-6).toBe(true)
			expect((x - lastX) * forwardX + (z - lastZ) * forwardZ > 0).toBe(true)
			-- Siempre dentro del anillo y nunca más cerca del borde que el carril.
			expect(x >= lane - 1e-6 and x <= span - lane + 1e-6).toBe(true)
			expect(z >= lane - 1e-6 and z <= span - lane + 1e-6).toBe(true)
			lastX, lastZ = x, z
		end
		local endX, endZ = CityLayout.trafficPose("S", length)
		local startX, startZ = CityLayout.trafficPose("S", 0)
		expect(math.abs(endX - startX) < 1e-6 and math.abs(endZ - startZ) < 1e-6).toBe(true)
	end)

	it("no carga dos veces la misma malla", function()
		local seen: { [string]: boolean } = {}
		for _, piece in ArtAssets.all() do
			expect(seen[piece.key]).toBe(nil)
			seen[piece.key] = true
		end
	end)

	it("el orden de carga tiene exactamente las mismas mallas que all(), sin repetir", function()
		local expected: { [string]: boolean } = {}
		for _, piece in ArtAssets.all() do
			expected[piece.key] = true
		end
		local order = ArtAssets.loadOrder()
		expect(#order).toBe(#ArtAssets.all())
		local seen: { [string]: boolean } = {}
		for _, piece in order do
			expect(seen[piece.key]).toBe(nil)
			seen[piece.key] = true
		end
		for key, _ in expected do
			expect(seen[key]).toBe(true)
		end
	end)

	it("mojón, taxi y los base de cada propiedad van antes que cualquier añadido", function()
		local early: { [string]: boolean } = {}
		for _, property in ArtAssets.properties do
			for _, piece in property.base do
				early[piece.key] = true
			end
		end
		for _, piece in ArtAssets.taxi do
			early[piece.key] = true
		end
		early[ArtAssets.mojon.stone.key] = true
		early[ArtAssets.mojon.ring.key] = true

		local addon: { [string]: boolean } = {}
		for _, property in ArtAssets.properties do
			for _, list in property.addons do
				for _, piece in list do
					addon[piece.key] = true
				end
			end
		end

		local lastEarly = 0
		local firstAddon = math.huge
		for index, piece in ArtAssets.loadOrder() do
			if early[piece.key] then
				lastEarly = index
			end
			if addon[piece.key] and index < firstAddon then
				firstAddon = index
			end
		end
		expect(lastEarly > 0).toBe(true)
		expect(lastEarly < firstAddon).toBe(true)
	end)
end)

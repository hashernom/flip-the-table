--!strict
local Harness = require("../harness")
local ArtAssets = require("../../src/shared/config/ArtAssets")
local CityLayout = require("../../src/shared/config/CityLayout")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

describe("ArtAssets", function()
	it("una propiedad sin modelo se queda en gris", function()
		expect(ArtAssets.piecesFor("Pasaje Burbuja", 3)).toBe(nil)
	end)

	it("cada nivel suma su añadido y nunca quita el cuerpo", function()
		local base = ArtAssets.piecesFor("Cine Lux", 0) :: { ArtAssets.Piece }
		local top = ArtAssets.piecesFor("Cine Lux", 5) :: { ArtAssets.Piece }
		expect(#top >= #base + 5).toBe(true)
		expect(top[1].key).toBe(base[1].key)
	end)

	it("todo el mobiliario se carga y cada zona ambientada coloca piezas que existen", function()
		local loaded: { [string]: boolean } = {}
		for _, piece in ArtAssets.all() do
			loaded[piece.key] = true
		end
		for _, zone in ArtAssets.dressedZones do
			local items = CityLayout.dressingFor("S", zone)
			expect(#items > 0).toBe(true)
			for _, item in items do
				for _, piece in ArtAssets.street[item.kind] do
					expect(loaded[piece.key]).toBe(true)
				end
			end
		end
	end)

	it("el mobiliario va en la acera y la cebra en la calzada", function()
		local span = CityLayout.spanFor("S")
		local crosswalks = 0
		for _, item in CityLayout.dressingFor("S", "carmesi") do
			local fromAxis =
				math.min(math.abs(item.x), math.abs(item.z), math.abs(item.x - span), math.abs(item.z - span))
			if item.kind == "Crosswalk" then
				crosswalks += 1
				expect(fromAxis).toBe(0)
			else
				expect(fromAxis >= CityLayout.STREET_WIDTH_STUDS / 2).toBe(true)
				expect(fromAxis <= CityLayout.STREET_WIDTH_STUDS / 2 + CityLayout.SIDEWALK_STUDS).toBe(true)
			end
		end
		expect(crosswalks > 0).toBe(true)
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
end)

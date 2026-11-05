--!strict
local Harness = require("../harness")
local ArtAssets = require("../../src/shared/config/ArtAssets")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

describe("ArtAssets", function()
	it("una propiedad sin modelo se queda en gris", function()
		expect(ArtAssets.piecesFor("Calle del Estaño", 3)).toBe(nil)
	end)

	it("cada nivel suma su añadido y nunca quita el cuerpo", function()
		local base = ArtAssets.piecesFor("Cine Lux de Medianoche", 0) :: { ArtAssets.Piece }
		local top = ArtAssets.piecesFor("Cine Lux de Medianoche", 5) :: { ArtAssets.Piece }
		expect(#top >= #base + 5).toBe(true)
		expect(top[1].key).toBe(base[1].key)
	end)

	it("no carga dos veces la misma malla", function()
		local seen: { [string]: boolean } = {}
		for _, piece in ArtAssets.all() do
			expect(seen[piece.key]).toBe(nil)
			seen[piece.key] = true
		end
	end)
end)

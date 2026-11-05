--!strict
-- Modelos reales de la ciudad (R-P50): qué mallas forman cada propiedad y cada marcador, y con qué
-- material va cada una. En Roblox cada malla lleva un solo material y las de Open Cloud llegan sin él.
-- Una propiedad que no está aquí se ve con el bloque gris de `BuildingView`.
export type Piece = {
	key: string,
	assetId: string,
	color: { number },
	material: string,
	reflectance: number?,
}

local BRICK = { 176, 102, 74 }
local STONE = { 210, 201, 180 }
local SLATE = { 74, 78, 84 }
local RED = { 196, 56, 43 }
-- Oscuro y opaco: tras estos cristales no hay interior, y con transparencia se veía el ladrillo.
local GLASS = { 46, 74, 99 }

local function piece(
	key: string,
	id: string,
	color: { number },
	material: string,
	reflectance: number?
): Piece
	return {
		key = key,
		assetId = `rbxassetid://{id}`,
		color = color,
		material = material,
		reflectance = reflectance,
	}
end

local ArtAssets = {}

ArtAssets.FOLDER = "ArtAssets"
ArtAssets.READY_ATTRIBUTE = "Ready"

-- Lo que el edificio se retrasa en el solar: delante van los marcadores.
ArtAssets.FRONT_OFFSET = 2

-- Por el nombre que da `Strings.squareLabel`. Los añadidos, en orden de nivel.
ArtAssets.properties = {
	["Cine Lux de Medianoche"] = {
		base = {
			piece("cine-wall", "71336473679427", BRICK, "Brick"),
			piece("cine-trim", "77475477580156", STONE, "Limestone"),
			piece("cine-glass", "121921872087774", GLASS, "Glass", 0.25),
			piece("cine-roof", "114543760508825", SLATE, "Slate"),
			piece("cine-sign", "76583737990361", RED, "SmoothPlastic"),
		},
		addons = {
			{
				piece("cine-addon1-hedge", "122262308128677", { 75, 107, 58 }, "Grass"),
				piece("cine-addon1-limestone", "108306691423975", STONE, "Limestone"),
				piece("cine-addon1-red", "113491450572214", RED, "Fabric"),
			},
			{
				piece("cine-addon2-cream", "86646242275127", { 237, 229, 211 }, "SmoothPlastic"),
				piece("cine-addon2-limestone", "118332360564004", STONE, "Limestone"),
				piece("cine-addon2-red", "110049613209192", RED, "Fabric"),
			},
			{
				piece("cine-addon3-brick", "123554905698866", BRICK, "Brick"),
				piece("cine-addon3-glass", "84747055926971", GLASS, "Glass", 0.25),
				piece("cine-addon3-limestone", "96942026871016", STONE, "Limestone"),
			},
			{
				piece("cine-addon4-cream", "71012732247378", { 237, 229, 211 }, "SmoothPlastic"),
				piece("cine-addon4-gold", "123115517950109", { 201, 162, 39 }, "Metal"),
				piece("cine-addon4-red", "115619028441877", RED, "Fabric"),
				piece("cine-addon4-steel", "98250470333975", { 168, 174, 180 }, "Metal"),
			},
			{
				piece("cine-addon5-cream", "135807504654840", { 237, 229, 211 }, "SmoothPlastic"),
				piece("cine-addon5-gold", "122258833131116", { 201, 162, 39 }, "Metal"),
				piece("cine-addon5-limestone", "97550408016054", STONE, "Limestone"),
				piece("cine-addon5-red", "100335150180826", RED, "Fabric"),
				piece("cine-addon5-steel", "88574969270990", { 168, 174, 180 }, "Metal"),
			},
		},
	},
} :: { [string]: { base: { Piece }, addons: { { Piece } } } }

ArtAssets.markers = {
	House = piece("marker-house", "109373087404235", STONE, "Limestone"),
	Hotel = piece("marker-hotel", "135810274975392", { 168, 174, 180 }, "Metal"),
	Tower = piece("marker-tower", "94509577031463", { 201, 162, 39 }, "Metal"),
} :: { [string]: Piece }

-- Mallas de una propiedad en un nivel, o nil si aún no tiene modelo real.
function ArtAssets.piecesFor(name: string, level: number): { Piece }?
	local property = ArtAssets.properties[name]
	if property == nil then
		return nil
	end
	local pieces = table.clone(property.base)
	for order = 1, math.min(level, #property.addons) do
		table.move(property.addons[order], 1, #property.addons[order], #pieces + 1, pieces)
	end
	return pieces
end

-- Todas las mallas: lo que el servidor tiene que cargar.
function ArtAssets.all(): { Piece }
	local pieces: { Piece } = {}
	for _, property in ArtAssets.properties do
		table.move(property.base, 1, #property.base, #pieces + 1, pieces)
		for _, addon in property.addons do
			table.move(addon, 1, #addon, #pieces + 1, pieces)
		end
	end
	for _, marker in ArtAssets.markers do
		table.insert(pieces, marker)
	end
	return pieces
end

return ArtAssets

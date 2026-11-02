--!strict
-- Composición de los tres tableros de Metrópolis de Noche.
local Economy = require("./Economy")
local Types = require("../rules/Types")

type Board = Types.Board
type SizeId = Types.SizeId
type Square = Types.Square
type SquareKind = Types.SquareKind

type ZoneBlock = { zoneId: string, barrioId: string, specials: { SquareKind } }

local PROPERTIES_PER_ZONE = 3

local CENTRO: { ZoneBlock } = {
	{ zoneId = "centro-1", barrioId = "Centro", specials = { "Spin", "Tax" } },
	{ zoneId = "centro-2", barrioId = "Centro", specials = { "Portal", "Duel" } },
	{ zoneId = "centro-3", barrioId = "Centro", specials = { "Spin", "Market" } },
	{ zoneId = "centro-4", barrioId = "Centro", specials = { "Tribunal", "Spin", "Billboard" } },
	{ zoneId = "centro-5", barrioId = "Centro", specials = { "Portal", "Duel" } },
	{ zoneId = "centro-6", barrioId = "Centro", specials = { "Spin", "Market" } },
}

local EXTRA_BLOCKS: { [SizeId]: { ZoneBlock } } = {
	S = {},
	M = {
		{ zoneId = "puerto-1", barrioId = "Puerto", specials = { "Billboard" } },
		{ zoneId = "puerto-2", barrioId = "Puerto", specials = { "Spin" } },
	},
	L = {
		{ zoneId = "puerto-1", barrioId = "Puerto", specials = { "Spin" } },
		{ zoneId = "puerto-2", barrioId = "Puerto", specials = { "Duel" } },
		{ zoneId = "alta-1", barrioId = "ZonaAlta", specials = { "Spin" } },
		{ zoneId = "alta-2", barrioId = "ZonaAlta", specials = { "Portal" } },
	},
}

local function priceForZone(position: number, zoneCount: number): number
	local range = Economy.maxPropertyPrice - Economy.minPropertyPrice
	local exact = Economy.minPropertyPrice + range * (position - 1) / (zoneCount - 1)
	return math.floor(exact / Economy.priceStep + 0.5) * Economy.priceStep
end

local Boards = {}

function Boards.forPlayerCount(playerCount: number): SizeId
	if playerCount < 2 or playerCount > 8 then
		error(`Boards.forPlayerCount: se admiten de 2 a 8 jugadores, no {playerCount}`, 2)
	end
	if playerCount <= 4 then
		return "S"
	elseif playerCount <= 6 then
		return "M"
	end
	return "L"
end

function Boards.get(sizeId: SizeId): Board
	local blocks: { ZoneBlock } = table.clone(CENTRO)
	table.move(EXTRA_BLOCKS[sizeId], 1, #EXTRA_BLOCKS[sizeId], #blocks + 1, blocks)

	local squares: { Square } = { { index = 1, kind = "Start", barrioId = "Centro" } }
	local zones: { [string]: { number } } = {}
	local zoneOrder: { string } = {}

	for position, block in blocks do
		local price = priceForZone(position, #blocks)
		local indices = {}
		for _ = 1, PROPERTIES_PER_ZONE do
			local index = #squares + 1
			squares[index] = {
				index = index,
				kind = "Property",
				zoneId = block.zoneId,
				barrioId = block.barrioId,
				price = price,
			}
			table.insert(indices, index)
		end
		zones[block.zoneId] = indices
		table.insert(zoneOrder, block.zoneId)
		for _, kind: SquareKind in block.specials do
			local index = #squares + 1
			squares[index] = { index = index, kind = kind, barrioId = block.barrioId }
		end
	end

	return { sizeId = sizeId, squares = squares, zones = zones, zoneOrder = zoneOrder }
end

return Boards

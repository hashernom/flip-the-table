--!strict
-- Geometría de la ciudad por tamaño. Es puro: devuelve posiciones como tablas `{ x, y, z }` y
-- ángulos en radianes, sin Instance ni Vector3, para poder probarlo con Lune y para que el cliente
-- lo convierta a `Vector3` al construir. La fuente de verdad de la composición es `Boards`: aquí
-- solo se decide dónde cae cada casilla.
--
-- La ruta es el anillo de un cuadrado de 11, 13 o 15 casillas de lado, que da exactamente 40, 48 y
-- 56 casillas. Empieza en la esquina de la Salida, que está en el mismo sitio en los tres tamaños, y
-- avanza siempre en el mismo sentido. La ciudad crece hacia fuera: Centro, Puerto, Zona Alta e
-- Industrial, en ese orden a lo largo de la ruta, así que Centro y Puerto ocupan la cabeza del
-- anillo en los tres tamaños.
local Boards = require("./Boards")
local Types = require("../rules/Types")

export type SizeId = Types.SizeId
export type Vector3Like = { x: number, y: number, z: number }

export type Slot = {
	index: number,
	position: Vector3Like,
	-- Ángulo en radianes con el convenio de Roblox: el avance es (sin(facing), 0, cos(facing)).
	facing: number,
	barrioId: string,
	kind: Types.SquareKind,
	-- Solo en las casillas de propiedad: zona y número de la propiedad dentro de su zona.
	zoneId: string?,
	ordinal: number?,
}

-- Un puente es la arista de la ruta que cruza de una isla a otra.
export type Bridge = {
	fromIndex: number,
	toIndex: number,
	-- Isla de destino: "ZonaAlta" o "Industrial".
	barrioId: string,
	start: Vector3Like,
	facing: number,
	lengthStuds: number,
}

export type TokenOffset = { side: number, along: number }

export type BuildingBlock = { along: number, width: number, depth: number, height: number }

-- Presupuesto de separación entre casillas consecutivas, en studs. La ficha pide una ciudad a
-- escala real; 40 studs por casilla deja la ciudad entre 400 y 560 studs de lado y holgura de sobra
-- bajo el máximo de 60 que fija el plan.
local SQUARE_SPACING = 40
local MAX_STEP_STUDS = 60

-- Casillas por lado del cuadrado de cada tablero (docs/02-mvp/contenido-tablero.md, «Tableros»).
local SIDES: { [SizeId]: number } = { S = 11, M = 13, L = 15 }

-- Agrupación en islas: Centro y Puerto comparten el continente; el resto son islas que se cruzan
-- por puentes.
local ISLANDS: { [string]: string } = {
	Centro = "Mainland",
	Puerto = "Mainland",
	ZonaAlta = "ZonaAlta",
	Industrial = "Industrial",
}

local CityLayout = {}

CityLayout.SQUARE_SPACING_STUDS = SQUARE_SPACING
CityLayout.MAX_STEP_STUDS = MAX_STEP_STUDS

-- Isla de un barrio. La ciudad se agrupa en el continente (Centro y Puerto) y las islas exteriores.
function CityLayout.islandOf(barrioId: string): string
	local island = ISLANDS[barrioId]
	if island == nil then
		error(`CityLayout: el barrio {barrioId} no tiene isla asignada`, 2)
	end
	return island
end

-- Casillas por lado del cuadrado de un tablero.
function CityLayout.sideFor(sizeId: SizeId): number
	local side = SIDES[sizeId]
	if side == nil then
		error(`CityLayout: no hay ciudad para el tamaño {tostring(sizeId)}`, 2)
	end
	return side
end

-- Recorrido del anillo: desde la esquina de la Salida avanza primero por +X, después por +Z, luego
-- por -X y por último por -Z, con `side - 1` pasos por lado. Devuelve una posición por casilla, con
-- la Salida en el origen.
local function ringPositions(side: number): { Vector3Like }
	local step = SQUARE_SPACING
	local positions: { Vector3Like } = {}
	local x, z = 0, 0
	local directions = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }
	for _, direction in directions do
		for _ = 1, side - 1 do
			table.insert(positions, { x = x, y = 0, z = z })
			x += direction[1] * step
			z += direction[2] * step
		end
	end
	return positions
end

-- Ora cada propiedad con su número dentro de la zona, que es el que elige su nombre en `Strings`.
local function ordinalsFor(board: Types.Board): { [number]: number }
	local ordinals: { [number]: number } = {}
	for _, indices in board.zones do
		for ordinal, index in indices do
			ordinals[index] = ordinal
		end
	end
	return ordinals
end

-- Una posición por casilla de la ruta, en orden de ruta. `index` es la casilla del tablero, así que
-- la misma casilla lógica cae en el mismo sitio del anillo en cualquier tamaño.
function CityLayout.routeFor(sizeId: SizeId): { Slot }
	local side = CityLayout.sideFor(sizeId)
	local board = Boards.get(sizeId)
	local positions = ringPositions(side)
	local ordinals = ordinalsFor(board)
	if #positions ~= #board.squares then
		error(
			`CityLayout: el anillo de {side}x{side} da {#positions} casillas y el tablero {sizeId} tiene {#board.squares}`,
			2
		)
	end

	local count = #positions
	local route: { Slot } = {}
	for index = 1, count do
		local position = positions[index]
		local nextPosition = positions[if index == count then 1 else index + 1]
		local square = board.squares[index]
		table.insert(route, {
			index = index,
			position = position,
			facing = math.atan2(nextPosition.x - position.x, nextPosition.z - position.z),
			barrioId = square.barrioId,
			kind = square.kind,
			zoneId = square.zoneId,
			ordinal = ordinals[index],
		})
	end
	return route
end

-- Puentes de la ruta: una arista por cada cruce de isla, en el sentido de la marcha. Con ellos,
-- cada isla exterior se entra y se sale, y el continente queda rodeado por agua.
function CityLayout.bridgesFor(sizeId: SizeId): { Bridge }
	local route = CityLayout.routeFor(sizeId)
	local bridges: { Bridge } = {}
	for index, slot in route do
		local nextIndex = if index == #route then 1 else index + 1
		local nextSlot = route[nextIndex]
		local island = CityLayout.islandOf(slot.barrioId)
		local nextIsland = CityLayout.islandOf(nextSlot.barrioId)
		if island ~= nextIsland then
			table.insert(bridges, {
				fromIndex = index,
				toIndex = nextIndex,
				barrioId = nextIsland,
				start = slot.position,
				facing = slot.facing,
				lengthStuds = SQUARE_SPACING,
			})
		end
	end
	return bridges
end

-- Centro del anillo: lo usan la cámara de vista general y la maqueta. Es la mitad de la caja que
-- abarca la ruta, incluido el ancho de una casilla.
function CityLayout.centerFor(sizeId: SizeId): Vector3Like
	local side = CityLayout.sideFor(sizeId)
	local span = (side - 1) * SQUARE_SPACING
	return { x = span / 2, y = 0, z = span / 2 }
end

-- Lado de la ciudad en studs, de una esquina a la opuesta.
function CityLayout.spanFor(sizeId: SizeId): number
	return (CityLayout.sideFor(sizeId) - 1) * SQUARE_SPACING
end

-- Reparto de las fichas que comparten casilla: cuatro carriles de lado a lado (`art/escala.md`) y las
-- filas que hagan falta. Caben las ocho de una partida llena dentro de la baldosa.
local TOKEN_LANES = 4
local TOKEN_LANE_STUDS = 9
local TOKEN_ROW_STUDS = 16

CityLayout.TOKEN_LANE_STUDS = TOKEN_LANE_STUDS
CityLayout.TOKEN_ROW_STUDS = TOKEN_ROW_STUDS

-- Desplazamiento de la ficha número `order` de las `count` que hay en una casilla, medido desde su
-- centro: `side` hacia la derecha de la marcha y `along` hacia delante.
function CityLayout.tokenOffset(order: number, count: number): TokenOffset
	if count <= 1 then
		return { side = 0, along = 0 }
	end
	local lanes = math.min(count, TOKEN_LANES)
	local rows = math.ceil(count / TOKEN_LANES)
	local lane = (order - 1) % TOKEN_LANES
	local row = (order - 1) // TOKEN_LANES
	return {
		side = (lane - (lanes - 1) / 2) * TOKEN_LANE_STUDS,
		along = ((rows - 1) / 2 - row) * TOKEN_ROW_STUDS,
	}
end

-- El solar de cada casilla, junto a la baldosa y por fuera del anillo. Su fondo es el de `art/escala.md`
-- y su ancho, el de la baldosa, para que dos solares vecinos no se toquen.
local TILE_HALF = (SQUARE_SPACING - 4) / 2
local LOT_GAP_STUDS = 2
local LOT_WIDTH = SQUARE_SPACING - 4
local LOT_DEPTH = 22

CityLayout.LOT_WIDTH_STUDS = LOT_WIDTH
CityLayout.LOT_DEPTH_STUDS = LOT_DEPTH

-- Centro del solar de una casilla. La ruta gira siempre a la derecha, así que su exterior queda a la
-- izquierda de la marcha.
function CityLayout.lotCenter(slot: Slot): Vector3Like
	local distance = TILE_HALF + LOT_GAP_STUDS + LOT_DEPTH / 2
	return {
		x = slot.position.x + math.cos(slot.facing) * distance,
		y = 0,
		z = slot.position.z - math.sin(slot.facing) * distance,
	}
end

-- La escalera de cinco pasos, en piezas: una, dos y tres casas, hotel y rascacielos. Las alturas son
-- las de `art/escala.md`. `along` es la posición de la pieza a lo largo de la calle.
local HOUSE: BuildingBlock = { along = 0, width = 10, depth = 12, height = 15.2 }
local HOUSE_STEP = 12

local function houses(count: number): { BuildingBlock }
	local blocks: { BuildingBlock } = {}
	for order = 1, count do
		table.insert(blocks, {
			along = (order - (count + 1) / 2) * HOUSE_STEP,
			width = HOUSE.width,
			depth = HOUSE.depth,
			height = HOUSE.height,
		})
	end
	return blocks
end

local BUILDING_STEPS: { { BuildingBlock } } = {
	houses(1),
	houses(2),
	houses(3),
	{ { along = 0, width = 30, depth = 18, height = 36.5 } },
	{ { along = 0, width = 18, depth = 18, height = 92 } },
}

-- Piezas de un nivel de edificio. El nivel 0, o uno que no exista, no tiene ninguna.
function CityLayout.buildingBlocks(level: number): { BuildingBlock }
	return BUILDING_STEPS[level] or {}
end

return CityLayout

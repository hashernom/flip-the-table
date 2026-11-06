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

export type BuildingBlock = {
	along: number,
	front: number,
	y: number,
	width: number,
	depth: number,
	height: number,
}

-- Un objeto de la calle: dónde va su base y hacia dónde mira.
export type Dressing = {
	kind: string,
	x: number,
	y: number,
	z: number,
	lookX: number,
	lookZ: number,
}

export type LevelMarker = {
	along: number,
	front: number,
	width: number,
	depth: number,
	height: number,
	kind: string,
}

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

-- La calle: asfalto continuo y, encima, cada casilla pintada en el carril junto a su edificio
-- (art/vision-visual.md). No ocupa toda la calzada ni llega a la siguiente: se tiene que ver el asfalto.
local STREET_WIDTH = 34
local SIDEWALK = 7
local SLOT_LENGTH = 30
local SLOT_DEPTH = 16
-- Sitio del centro de la casilla desde el eje de la calle, hacia los edificios (3 studs). Negativo: el valor
-- de siempre, medido hacia el exterior; `LOT_SIDE` lo lleva al lado donde estén los edificios.
local SLOT_SIDE = -3

-- Lado de la calle donde van las propiedades (2026-11-05, espejo pedido por el responsable): 1 fuera del
-- anillo, -1 dentro. Las casillas especiales y la cárcel se quedan fuera, con la ciudad de fondo: en las
-- esquinas interiores no caben un edificio especial y la primera propiedad del lado siguiente, y el de la
-- esquina caería sobre la calle. `lotSideOf` da el lado de cada casilla.
CityLayout.LOT_SIDE = -1

CityLayout.STREET_WIDTH_STUDS = STREET_WIDTH
CityLayout.SIDEWALK_STUDS = SIDEWALK
CityLayout.SLOT_LENGTH_STUDS = SLOT_LENGTH
CityLayout.SLOT_DEPTH_STUDS = SLOT_DEPTH
CityLayout.SLOT_SIDE_STUDS = SLOT_SIDE
-- Marco pintado de una casilla: ocupa todo el ancho del asfalto. A lo largo de la calle es algo más estrecho, y aun
-- así caben las ocho fichas. Una esquina ocupa el cuadrado entero del cruce.
CityLayout.PAINT_ACROSS_STUDS = STREET_WIDTH - 1
CityLayout.PAINT_ALONG_STUDS = 28

-- Reparto de las fichas que comparten casilla: cuatro a lo largo y dos filas, con la base de
-- `art/escala.md`. Caben las ocho de una partida llena dentro de la pintura.
local TOKEN_BASE = 6
local TOKEN_LANES = 4
local TOKEN_LANE_STUDS = 7
local TOKEN_ROW_STUDS = 7.5

CityLayout.TOKEN_BASE_STUDS = TOKEN_BASE
CityLayout.TOKEN_LANE_STUDS = TOKEN_LANE_STUDS
CityLayout.TOKEN_ROW_STUDS = TOKEN_ROW_STUDS

-- Sitio de la ficha número `order` de las `count` que hay en una casilla, medido desde el eje de la
-- calle: `side` hacia la derecha de la marcha y `along` hacia delante.
function CityLayout.tokenOffset(order: number, count: number): TokenOffset
	if count <= 1 then
		return { side = SLOT_SIDE, along = 0 }
	end
	local lanes = math.min(count, TOKEN_LANES)
	local rows = math.ceil(count / TOKEN_LANES)
	local lane = (order - 1) % TOKEN_LANES
	local row = (order - 1) // TOKEN_LANES
	return {
		side = SLOT_SIDE + ((rows - 1) / 2 - row) * TOKEN_ROW_STUDS,
		along = (lane - (lanes - 1) / 2) * TOKEN_LANE_STUDS,
	}
end

-- Punto a `distance` studs del eje de la calle, hacia el exterior del anillo. La ruta gira siempre a la
-- derecha, así que su exterior queda a la izquierda de la marcha.
local function outward(slot: Slot, distance: number): Vector3Like
	return {
		x = slot.position.x + math.cos(slot.facing) * distance,
		y = 0,
		z = slot.position.z - math.sin(slot.facing) * distance,
	}
end

-- Centro de la casilla pintada.
-- Lado de su edificio: el de las propiedades (`LOT_SIDE`) o fuera, si es una casilla especial.
function CityLayout.lotSideOf(slot: Slot): number
	return if slot.kind == "Property" then CityLayout.LOT_SIDE else 1
end

function CityLayout.slotCenter(slot: Slot): Vector3Like
	return outward(slot, -SLOT_SIDE * CityLayout.lotSideOf(slot))
end

-- El solar de cada casilla, tras la acera. Su fondo es el de `art/escala.md` y su ancho, provisional, el
-- que deja 4 studs hasta el del vecino.
local LOT_WIDTH = SQUARE_SPACING - 4
local LOT_DEPTH = 22

CityLayout.LOT_WIDTH_STUDS = LOT_WIDTH
CityLayout.LOT_DEPTH_STUDS = LOT_DEPTH

-- Centro del solar de una casilla.
function CityLayout.lotCenter(slot: Slot): Vector3Like
	return outward(slot, CityLayout.lotSideOf(slot) * (STREET_WIDTH / 2 + SIDEWALK + LOT_DEPTH / 2))
end

-- Centro de un solar fuera del anillo, sea cual sea `LOT_SIDE`. Lo usa la cárcel: la escena de la
-- detención está montada con ella fuera, frente a su casilla.
function CityLayout.outsideLotCenter(slot: Slot): Vector3Like
	return outward(slot, STREET_WIDTH / 2 + SIDEWALK + LOT_DEPTH / 2)
end

-- Ciudad de fondo, fuera del anillo (2026-11-05): con las propiedades dentro, el exterior se amuebla con
-- farolas y árboles en la acera, parques y edificios bajos donde antes estaban los solares, y dos filas de
-- manzanas más altas detrás. Los edificios son bloques: se ven de lejos y nunca tapan la partida. Es decorado
-- fijo: sale siempre igual y no depende de la partida.
export type Backdrop = {
	kind: string,
	x: number,
	z: number,
	lookX: number,
	lookZ: number,
	w: number?,
	d: number?,
	h: number?,
	tone: number?,
}

CityLayout.BACKDROP = {
	lampAlong = -13,
	lampOut = 18,
	treeOut = 19.5,
	firstOut = 35,
	firstWidth = 30,
	firstDepth = 18,
	firstHeights = { 9, 12, 15, 11, 14 },
	parkEvery = 3,
	parkTreeAlong = 10,
	parkTreeOut = 39,
	benchOut = 27.5,
	grassWidth = 34,
	grassDepth = 20,
	secondOut = 62,
	secondWidth = 34,
	secondDepth = 20,
	secondHeights = { 22, 30, 26, 38, 24, 34 },
	thirdOut = 96,
	thirdWidth = 38,
	thirdDepth = 26,
	thirdHeights = { 44, 58, 50, 70, 46, 64 },
	cornerOut = 80,
	cornerSize = 40,
	cornerHeight = 72,
	tones = 6,
}

-- Altura «al azar» pero fija de la manzana `index` en una fila.
local function pick(list: { number }, index: number, salt: number): number
	return list[(index * 7 + salt * 3) % #list + 1]
end

function CityLayout.backdropFor(sizeId: SizeId): { Backdrop }
	local config = CityLayout.BACKDROP
	local route = CityLayout.routeFor(sizeId)
	local items: { Backdrop } = {}
	local count = #route
	local function add(slot: Slot, kind: string, along: number, out: number, extra: { [string]: any }?)
		local fx, fz = math.sin(slot.facing), math.cos(slot.facing)
		local ox, oz = math.cos(slot.facing), -math.sin(slot.facing)
		local item: Backdrop = {
			kind = kind,
			x = slot.position.x + fx * along + ox * out,
			z = slot.position.z + fz * along + oz * out,
			-- Todo mira a la calle.
			lookX = -ox,
			lookZ = -oz,
		}
		local fields: { [string]: any } = extra or {}
		for key, value in fields do
			(item :: any)[key] = value
		end
		table.insert(items, item)
	end
	for index, slot in route do
		local before = route[if index == 1 then count else index - 1]
		local after = route[if index == count then 1 else index + 1]
		local corner = before.facing ~= slot.facing
		if corner then
			-- La esquina exterior: una torre en la diagonal, fuera de las dos calles.
			local ax, az = math.cos(slot.facing), -math.sin(slot.facing)
			local bx, bz = math.cos(before.facing), -math.sin(before.facing)
			table.insert(items, {
				kind = "Block",
				x = slot.position.x + (ax + bx) * config.cornerOut,
				z = slot.position.z + (az + bz) * config.cornerOut,
				lookX = -(ax + bx) / 2,
				lookZ = -(az + bz) / 2,
				w = config.cornerSize,
				d = config.cornerSize,
				h = config.cornerHeight,
				tone = index % config.tones + 1,
			})
			continue
		end
		add(slot, "Lamp", config.lampAlong, config.lampOut)
		if after.facing == slot.facing then
			add(slot, "Tree", SQUARE_SPACING / 2, config.treeOut)
		end
		-- Donde antes iba el solar de una propiedad: parque o edificio bajo. Las especiales conservan el suyo.
		if slot.kind == "Property" and CityLayout.lotSideOf(slot) ~= 1 then
			if index % config.parkEvery == 0 then
				add(slot, "Grass", 0, config.firstOut, { w = config.grassWidth, d = config.grassDepth })
				add(slot, "Tree", -config.parkTreeAlong, config.parkTreeOut)
				add(slot, "Tree", config.parkTreeAlong, config.parkTreeOut)
				add(slot, "Bench", 0, config.benchOut)
			else
				add(slot, "Block", 0, config.firstOut, {
					w = config.firstWidth,
					d = config.firstDepth,
					h = pick(config.firstHeights, index, 1),
					tone = index % config.tones + 1,
				})
			end
		end
		add(slot, "Block", 0, config.secondOut, {
			w = config.secondWidth,
			d = config.secondDepth,
			h = pick(config.secondHeights, index, 2),
			tone = (index + 2) % config.tones + 1,
		})
		add(slot, "Block", 0, config.thirdOut, {
			w = config.thirdWidth,
			d = config.thirdDepth,
			h = pick(config.thirdHeights, index, 3),
			tone = (index + 4) % config.tones + 1,
		})
	end
	return items
end

-- Mobiliario de una manzana: va en las aceras y, en la junta entre dos casillas, sin pisar su pintura.
-- Los árboles van en las juntas, a ambos lados: así no tapan fachadas ni nombres desde el interior del
-- anillo, que es desde donde mira la cámara. La cebra cierra los dos extremos.
local SIDEWALK_TOP = 0.4
local JOINT_ALONG = SQUARE_SPACING / 2
local LAMP_ALONG, LAMP_OUT = -13, 18
local BENCH_ALONG, BENCH_OUT = 9, 22.6
local TREE_OUT = 19.5
local INNER_TREE_OUT = -20.5

-- Todo lo que amuebla las casillas de `zoneId`, de la primera a la última, con las de en medio incluidas.
function CityLayout.dressingFor(sizeId: SizeId, zoneId: string): { Dressing }
	local route = CityLayout.routeFor(sizeId)
	local first, last = math.huge, -math.huge
	for _, slot in route do
		if slot.zoneId == zoneId then
			first, last = math.min(first, slot.index), math.max(last, slot.index)
		end
	end
	local items: { Dressing } = {}
	if first > last then
		return items
	end

	local function place(kind: string, slot: Slot, along: number, side: number, y: number)
		-- `side` se mide hacia los edificios; aquí pasa a «hacia fuera del anillo».
		local out = side * CityLayout.LOT_SIDE
		local outX, outZ = math.cos(slot.facing), -math.sin(slot.facing)
		-- Mira a la calle desde cualquiera de las dos aceras.
		local towardStreet = if out > 0 then -1 else 1
		table.insert(items, {
			kind = kind,
			x = slot.position.x + math.sin(slot.facing) * along + outX * out,
			y = y,
			z = slot.position.z + math.cos(slot.facing) * along + outZ * out,
			lookX = outX * towardStreet,
			lookZ = outZ * towardStreet,
		})
	end

	for index = first, last do
		local slot = route[index]
		local before, after = route[index - 1], route[index + 1]
		-- Una junta solo existe si la casilla vecina sigue en la misma recta: en la esquina no hay acera.
		local straightBefore = before ~= nil and before.facing == slot.facing
		local straightAfter = after ~= nil and after.facing == slot.facing
		place("Lamp", slot, LAMP_ALONG, LAMP_OUT, SIDEWALK_TOP)
		place("Bench", slot, BENCH_ALONG, BENCH_OUT, SIDEWALK_TOP)
		if straightAfter then
			if index < last then
				place("Tree", slot, JOINT_ALONG, TREE_OUT, SIDEWALK_TOP)
				place("Tree", slot, JOINT_ALONG, INNER_TREE_OUT, SIDEWALK_TOP)
			else
				place("Crosswalk", slot, JOINT_ALONG, 0, 0)
			end
		end
		if index == first and straightBefore then
			place("Crosswalk", slot, -JOINT_ALONG, 0, 0)
		end
	end
	return items
end

-- Tráfico: un rectángulo de esquinas redondeadas por el carril libre, entre los nombres pintados y la acera
-- interior, en el mismo sentido que la ruta.
local TRAFFIC_LANE = 12
local TRAFFIC_TURN = 6

CityLayout.TRAFFIC_LANE_STUDS = TRAFFIC_LANE

-- Largo de una vuelta completa de tráfico.
function CityLayout.trafficLength(sizeId: SizeId): number
	local straight = CityLayout.spanFor(sizeId) - 2 * (TRAFFIC_LANE + TRAFFIC_TURN)
	return 4 * (straight + math.pi * TRAFFIC_TURN / 2)
end

-- Dónde está un coche tras recorrer `distance` y hacia dónde va. Calcula el primer lado y lo gira alrededor
-- del centro de la ciudad, porque los cuatro lados son iguales.
function CityLayout.trafficPose(sizeId: SizeId, distance: number): (number, number, number, number)
	local span = CityLayout.spanFor(sizeId)
	local straight = span - 2 * (TRAFFIC_LANE + TRAFFIC_TURN)
	local stretch = straight + math.pi * TRAFFIC_TURN / 2
	local along = distance % (4 * stretch)
	local side = math.floor(along / stretch)
	local t = along - side * stretch
	local start = TRAFFIC_LANE + TRAFFIC_TURN

	local x, z, forwardX, forwardZ
	if t <= straight then
		x, z, forwardX, forwardZ = start + t, TRAFFIC_LANE, 1, 0
	else
		local angle = (t - straight) / TRAFFIC_TURN
		x = start + straight + TRAFFIC_TURN * math.sin(angle)
		z = start - TRAFFIC_TURN * math.cos(angle)
		forwardX, forwardZ = math.cos(angle), math.sin(angle)
	end

	local center = span / 2
	local dx, dz = x - center, z - center
	for _ = 1, side do
		dx, dz = -dz, dx
		forwardX, forwardZ = -forwardZ, forwardX
	end
	return center + dx, center + dz, forwardX, forwardZ
end

-- Cada propiedad es un edificio fijo que existe desde el inicio (R-P50). Las medidas son de la ciudad
-- gris: el plan 07 las cambia por el modelo de cada propiedad. `along` va a lo largo de la calle, `front`
-- hacia el fondo del solar (negativo, hacia la calle) e `y` es la altura de la base de la pieza.
local BASE_BUILDING: BuildingBlock = { along = 0, front = 2, y = 0, width = 32, depth = 18, height = 24 }

-- Lo que añade cada nivel, acumulado: entrada, fachada, planta extra, marquesina y coronación.
local LEVEL_ADDONS: { BuildingBlock } = {
	{ along = 0, front = -7.5, y = 6, width = 26, depth = 1, height = 0.6 },
	{ along = 0, front = -7.5, y = 18, width = 30, depth = 1, height = 3 },
	{ along = 0, front = 2, y = 24, width = 24, depth = 14, height = 5 },
	{ along = 0, front = -8.5, y = 7, width = 14, depth = 3, height = 0.8 },
	{ along = 0, front = 2, y = 29, width = 10, depth = 8, height = 6 },
}

-- Una, dos y tres casitas; después, un solo marcador por nivel. Van en la franja delantera del solar.
local MARKER_FRONT = -9.5
-- A un lado del solar: en el centro taparían la entrada del edificio.
local MARKER_ALONG = 11.5
-- Solo la propiedad al máximo lleva marcador: un mojón. El resto de niveles se lee en el propio edificio.
local MARKER_LEVEL = 5
local MOJON = { width = 1.6, depth = 1.6, height = 3.2, kind = "Mojon" }

-- Piezas del edificio en un nivel: la base y los añadidos hasta ese nivel. Un nivel que no exista no
-- añade nada, pero el edificio sigue ahí.
function CityLayout.buildingBlocks(level: number): { BuildingBlock }
	local blocks = { BASE_BUILDING }
	for order = 1, math.min(level, #LEVEL_ADDONS) do
		table.insert(blocks, LEVEL_ADDONS[order])
	end
	return blocks
end

-- Marcadores de mejora de un nivel. Dicen la renta de un vistazo, sin mirar el edificio.
function CityLayout.levelMarkers(level: number): { LevelMarker }
	if level ~= MARKER_LEVEL then
		return {}
	end
	return {
		{
			along = MARKER_ALONG,
			front = MARKER_FRONT,
			width = MOJON.width,
			depth = MOJON.depth,
			height = MOJON.height,
			kind = MOJON.kind,
		},
	}
end

return CityLayout

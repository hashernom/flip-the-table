--!strict
-- Composición de los tres tableros de Metrópolis de Noche. La fuente de verdad es
-- docs/02-mvp/contenido-tablero.md: 12 zonas, 34 propiedades, 2 o 3 propiedades por zona y un
-- precio distinto por tamaño.
local Types = require("../rules/Types")

type Board = Types.Board
type SizeId = Types.SizeId
type Square = Types.Square
type SquareKind = Types.SquareKind

-- Una zona de la arquitectura. `prices` solo tiene la entrada de los tableros en los que la zona
-- existe: S termina en Violeta, M añade Añil y Blanca, y L añade Grafito y Ocre.
type ZoneDef = {
	zoneId: string,
	barrioId: string,
	properties: number,
	prices: { [SizeId]: number },
}

-- Un tramo del tablero. El tablero se divide en cuatro tramos iguales que abren con su esquina y
-- después reparten sus zonas y sus casillas especiales.
type SegmentDef = {
	corner: SquareKind,
	zones: { string },
	specials: { SquareKind },
}

-- Zonas en orden de ruta con las propiedades, el barrio y el precio de cada tablero (S/M/L).
local ZONES: { ZoneDef } = {
	{ zoneId = "cobre", barrioId = "Centro", properties = 2, prices = { S = 60, M = 60, L = 60 } },
	{ zoneId = "cian", barrioId = "Centro", properties = 3, prices = { S = 110, M = 100, L = 90 } },
	{ zoneId = "magenta", barrioId = "Centro", properties = 3, prices = { S = 160, M = 140, L = 120 } },
	{ zoneId = "naranja", barrioId = "Centro", properties = 3, prices = { S = 210, M = 170, L = 150 } },
	{ zoneId = "carmesi", barrioId = "Centro", properties = 3, prices = { S = 250, M = 210, L = 180 } },
	{ zoneId = "limon", barrioId = "Centro", properties = 3, prices = { S = 300, M = 250, L = 220 } },
	{ zoneId = "esmeralda", barrioId = "Puerto", properties = 3, prices = { S = 350, M = 290, L = 250 } },
	{ zoneId = "violeta", barrioId = "Puerto", properties = 2, prices = { S = 400, M = 320, L = 280 } },
	{ zoneId = "anil", barrioId = "ZonaAlta", properties = 3, prices = { M = 360, L = 310 } },
	{ zoneId = "blanca", barrioId = "ZonaAlta", properties = 3, prices = { M = 400, L = 340 } },
	{ zoneId = "grafito", barrioId = "Industrial", properties = 3, prices = { L = 370 } },
	{ zoneId = "ocre", barrioId = "Industrial", properties = 3, prices = { L = 400 } },
}

-- Regla de colocación: las esquinas caen en los cuartos del tablero, en 1, N/4+1, N/2+1 y
-- 3N/4+1, y son Salida, Tribunal, Aduana (Impuesto) y Portal central. Por eso cada tablero se
-- construye como cuatro tramos de N/4 casillas: el tramo abre con su esquina y después alterna
-- bloques de zona (con sus 2 o 3 propiedades seguidas) y las especiales que le tocan. Dentro de
-- un tramo, sus especiales se reparten lo más parejas posible después de cada bloque de zona.
-- Los totales de la arquitectura cuadran por construcción: 40/48/56 casillas, 8/10/12 zonas y
-- 22/28/34 propiedades.
local SEGMENTS: { [SizeId]: { SegmentDef } } = {
	S = {
		{
			corner = "Start",
			zones = { "cobre", "cian" },
			specials = { "Spin", "Market", "Duel", "Spin" },
		},
		{
			corner = "Tribunal",
			zones = { "magenta", "naranja" },
			specials = { "Spin", "Billboard", "Portal" },
		},
		{ corner = "Tax", zones = { "carmesi", "limon" }, specials = { "Spin", "Duel", "Billboard" } },
		{
			corner = "Portal",
			zones = { "esmeralda", "violeta" },
			specials = { "Spin", "Spin", "Portal", "Market" },
		},
	},
	M = {
		{
			corner = "Start",
			zones = { "cobre", "cian", "magenta" },
			specials = { "Spin", "Market", "Billboard" },
		},
		{
			corner = "Tribunal",
			zones = { "naranja", "carmesi" },
			specials = { "Spin", "Duel", "Billboard", "Portal", "Spin" },
		},
		{
			corner = "Tax",
			zones = { "limon", "esmeralda" },
			specials = { "Spin", "Duel", "Billboard", "Portal", "Spin" },
		},
		{
			corner = "Portal",
			zones = { "violeta", "anil", "blanca" },
			specials = { "Spin", "Spin", "Market" },
		},
	},
	L = {
		{
			corner = "Start",
			zones = { "cobre", "cian", "magenta" },
			specials = { "Spin", "Market", "Billboard", "Duel", "Spin" },
		},
		{
			corner = "Tribunal",
			zones = { "naranja", "carmesi", "limon" },
			specials = { "Spin", "Billboard", "Portal", "Spin" },
		},
		{
			corner = "Tax",
			zones = { "esmeralda", "violeta", "anil" },
			specials = { "Spin", "Spin", "Duel", "Portal", "Billboard" },
		},
		{
			corner = "Portal",
			zones = { "blanca", "grafito", "ocre" },
			specials = { "Spin", "Spin", "Billboard", "Market" },
		},
	},
}

-- Orden de las esquinas en los cuartos del tablero.
local CORNERS: { SquareKind } = { "Start", "Tribunal", "Tax", "Portal" }

local function zoneDef(zoneId: string): ZoneDef
	for _, def in ZONES do
		if def.zoneId == zoneId then
			return def
		end
	end
	error(`Boards: la zona {zoneId} no existe en la arquitectura`, 3)
end

-- Reparte `total` especiales entre `gaps` huecos (uno después de cada zona). Los primeros huecos
-- reciben una más para que el reparto sea lo más parejo posible.
local function specialsInGap(total: number, gaps: number, gap: number): number
	if gaps <= 0 then
		return 0
	end
	local base = math.floor(total / gaps)
	local extra = total % gaps
	return base + if gap <= extra then 1 else 0
end

-- Casillas totales del tablero según su composición, sin constantes fuera de esta tabla.
local function sizeOf(sizeId: SizeId): number
	local total = 0
	for _, segment in SEGMENTS[sizeId] do
		total += 1 + #segment.specials
		for _, zoneId in segment.zones do
			total += zoneDef(zoneId).properties
		end
	end
	return total
end

local function buildBoard(sizeId: SizeId): Board
	local total = sizeOf(sizeId)
	if total % 4 ~= 0 then
		error(`Boards: el tablero {sizeId} no se divide en cuatro tramos iguales ({total} casillas)`, 3)
	end
	local quarter = total / 4

	local squares: { Square } = {}
	local zones: { [string]: { number } } = {}
	local zoneOrder: { string } = {}

	for position, segment in SEGMENTS[sizeId] do
		local first = #squares + 1
		-- La esquina pertenece al barrio de la primera zona del tramo; la Salida queda en Centro.
		local cornerBarrio = if #segment.zones > 0 then zoneDef(segment.zones[1]).barrioId else "Centro"
		squares[first] = { index = first, kind = segment.corner, barrioId = cornerBarrio }

		local specialPosition = 0
		for gap, zoneId in segment.zones do
			local def = zoneDef(zoneId)
			local price = def.prices[sizeId]
			if not price then
				error(`Boards: la zona {zoneId} no existe en el tablero {sizeId}`, 3)
			end
			local indices: { number } = {}
			for _ = 1, def.properties do
				local index = #squares + 1
				squares[index] = {
					index = index,
					kind = "Property",
					zoneId = def.zoneId,
					barrioId = def.barrioId,
					price = price,
				}
				table.insert(indices, index)
			end
			zones[def.zoneId] = indices
			table.insert(zoneOrder, def.zoneId)

			-- Después del bloque de zona van sus especiales; si el tramo tiene más especiales que
			-- zonas, los primeros huecos reciben una más y la última queda antes de la esquina
			-- siguiente.
			for _ = 1, specialsInGap(#segment.specials, #segment.zones, gap) do
				specialPosition += 1
				local index = #squares + 1
				squares[index] =
					{ index = index, kind = segment.specials[specialPosition], barrioId = def.barrioId }
			end
		end

		local length = #squares - first + 1
		if length ~= quarter then
			error(
				`Boards: el tramo {position} del tablero {sizeId} ocupa {length} casillas y deberían ser {quarter}`,
				3
			)
		end
	end

	-- Comprobación de la regla de colocación: cada esquina en su cuarto y con su tipo.
	for corner, kind in CORNERS do
		local index = (corner - 1) * quarter + 1
		if squares[index].kind ~= kind then
			error(`Boards: el tablero {sizeId} debería tener {kind} en la casilla {index}`, 3)
		end
	end

	return { sizeId = sizeId, squares = squares, zones = zones, zoneOrder = zoneOrder }
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
	return buildBoard(sizeId)
end

return Boards

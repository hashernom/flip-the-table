--!strict
-- Ciudad procedural del interior del anillo y del borde exterior (2026-11-06, pedido del responsable). Desde
-- la vista aérea la ciudad tiene que leerse poblada: manzanas de torres, casas con jardín, parques, canchas
-- y una obra, separadas por calles, con un parque central que guarda una plaza con fuente. Fuera, detrás de
-- los fondos de barrio, arboledas y parquecitos. Nada de suelo gris.
--
-- Es puro y determinista: devuelve piezas como tablas (forma, centro, tamaño, giro, color y material) y
-- `CityBuilder` las convierte en `Part`. Así todos los clientes levantan la misma ciudad y se prueba con Lune.
local CityLayout = require("./CityLayout")

export type Shape = "Block" | "Disk" | "Ball" | "Wedge"
export type Item = {
	name: string,
	shape: Shape,
	-- Centro de la pieza.
	x: number,
	y: number,
	z: number,
	-- Tamaño: ancho (x), alto (y) y fondo (z). Un disco usa `sx` como diámetro y `sy` como grosor.
	sx: number,
	sy: number,
	sz: number,
	-- Giro sobre el eje vertical, en radianes.
	yaw: number,
	color: string,
	material: string,
	transparency: number?,
	-- Piezas finas que no hace falta que den sombra (líneas, ventanas, caminos).
	flat: boolean?,
}
export type CellKind = "Plaza" | "Towers" | "Midrise" | "Houses" | "Park" | "Court" | "Site"
export type Cell = { i: number, j: number, kind: CellKind, x0: number, z0: number, x1: number, z1: number }

local CityInterior = {}

CityInterior.SHAPES = { Block = true, Disk = true, Ball = true, Wedge = true } :: { [string]: boolean }
CityInterior.MATERIALS = {
	SmoothPlastic = true,
	Concrete = true,
	Grass = true,
	Glass = true,
	Brick = true,
	Wood = true,
	Slate = true,
	Ground = true,
	Metal = true,
	Water = true,
	Asphalt = true,
	Pavement = true,
	Fabric = true,
} :: { [string]: boolean }

-- Tope de piezas del interior más el exterior, para no hundir la maqueta ni el rendimiento.
CityInterior.MAX_PARTS = 2600

-- Manzanas por lado según el tamaño: siempre impar, para que haya una central.
local GRID: { [CityLayout.SizeId]: number } = { S = 3, M = 5, L = 5 }
-- Calle entre manzanas y franja de paseo que separa las manzanas de la trasera de los solares.
local ROAD = 12
local BUFFER = 6
-- Acera que rodea una manzana.
local CURB = 2.5
-- Suelo: alturas de las losas. La calle principal está a 0; las manzanas quedan un poco por encima.
local SLAB_TOP = 0.15
local SLAB_HEIGHT = 0.5

local PALETTE = {
	grass = "#5E8A4A",
	grassDark = "#4E7A3D",
	pavement = "#B9B2A3",
	asphalt = "#3A3E44",
	line = "#E8E2D2",
	dirt = "#8B6E4E",
	water = "#3F7FA6",
	stone = "#D2C9B4",
	trunk = "#5A4632",
	leaves = { "#4F7A3A", "#5C8A42", "#6B9446", "#467034" },
	walls = { "#B0664A", "#D2C9B4", "#8C8F94", "#C9A57A", "#9B5B44", "#E1D8C3", "#6E7F8E" },
	glass = { "#2E4A63", "#3B5F7A", "#4A6E86" },
	roofs = { "#5A5E64", "#4A4E54", "#6B6F75" },
	houseRoofs = { "#9B4A35", "#6B4A3A", "#5A5E64", "#B0593E" },
	court = { "#C0623A", "#3E7CB1", "#4E8A55" },
	fence = "#8C9196",
	bench = "#7A5A3C",
	lamp = "#2E3237",
	lampGlow = "#FFF1C2",
	crane = "#F5C518",
	concrete = "#A7A39A",
	cone = "#E07A3C",
}

-- Mazo de tipos de manzana: se reparte en orden barajado, así cada ciudad tiene de todo.
local DECK: { CellKind } = {
	"Towers",
	"Houses",
	"Park",
	"Court",
	"Midrise",
	"Towers",
	"Houses",
	"Site",
	"Midrise",
	"Towers",
	"Park",
	"Houses",
}

-- Generador congruencial: pseudoazar determinista, igual en todos los clientes.
type Rng = { seed: number }

local function nextRandom(rng: Rng): number
	rng.seed = (rng.seed * 1103515245 + 12345) % 2147483648
	return rng.seed / 2147483648
end

local function between(rng: Rng, low: number, high: number): number
	return low + (high - low) * nextRandom(rng)
end

local function pick<T>(rng: Rng, list: { T }): T
	return list[math.floor(nextRandom(rng) * #list) + 1]
end

local SEEDS: { [CityLayout.SizeId]: number } = { S = 1907, M = 2311, L = 3571 }

-- Primer y último stud del interior libre, en los dos ejes (la ciudad es un cuadrado).
function CityInterior.bounds(sizeId: CityLayout.SizeId): (number, number)
	local reach = CityLayout.STREET_WIDTH_STUDS / 2 + CityLayout.SIDEWALK_STUDS + CityLayout.LOT_DEPTH_STUDS
	local low = reach + BUFFER
	return low, CityLayout.spanFor(sizeId) - low
end

function CityInterior.cellsFor(sizeId: CityLayout.SizeId): { Cell }
	local count = GRID[sizeId]
	local low, high = CityInterior.bounds(sizeId)
	local size = (high - low - (count - 1) * ROAD) / count
	local rng: Rng = { seed = SEEDS[sizeId] }
	local deck = table.clone(DECK)
	for index = #deck, 2, -1 do
		local swap = math.floor(nextRandom(rng) * index) + 1
		deck[index], deck[swap] = deck[swap], deck[index]
	end
	local middle = (count + 1) / 2
	local cells: { Cell } = {}
	local dealt = 0
	for i = 1, count do
		for j = 1, count do
			local x0 = low + (i - 1) * (size + ROAD)
			local z0 = low + (j - 1) * (size + ROAD)
			local kind: CellKind
			if i == middle and j == middle then
				kind = "Plaza"
			else
				dealt += 1
				kind = deck[(dealt - 1) % #deck + 1]
			end
			table.insert(
				cells,
				{ i = i, j = j, kind = kind, x0 = x0, z0 = z0, x1 = x0 + size, z1 = z0 + size }
			)
		end
	end
	return cells
end

-- Constructores de piezas ------------------------------------------------------------------------------

local function block(
	items: { Item },
	name: string,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	color: string,
	material: string,
	extra: { yaw: number?, transparency: number?, flat: boolean?, shape: Shape? }?
)
	table.insert(items, {
		name = name,
		shape = if extra ~= nil and extra.shape ~= nil then extra.shape else "Block",
		x = x,
		y = y,
		z = z,
		sx = sx,
		sy = sy,
		sz = sz,
		yaw = if extra ~= nil and extra.yaw ~= nil then extra.yaw else 0,
		color = color,
		material = material,
		transparency = if extra ~= nil then extra.transparency else nil,
		flat = if extra ~= nil then extra.flat else nil,
	})
end

-- Losa del suelo de una zona, con su cara de arriba a `SLAB_TOP`.
local function slab(
	items: { Item },
	name: string,
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	color: string,
	material: string,
	lift: number?
)
	local top = SLAB_TOP + (lift or 0)
	block(
		items,
		name,
		(x0 + x1) / 2,
		top - SLAB_HEIGHT / 2,
		(z0 + z1) / 2,
		x1 - x0,
		SLAB_HEIGHT,
		z1 - z0,
		color,
		material,
		{ flat = true }
	)
end

-- Árbol de pocos polígonos, como los de la calle: tronco y dos copas cruzadas.
local function tree(items: { Item }, rng: Rng, x: number, z: number, scale: number?)
	local s = scale or between(rng, 0.85, 1.25)
	local leaves = pick(rng, PALETTE.leaves)
	local trunkHeight = 5 * s
	block(
		items,
		"TreeTrunk",
		x,
		SLAB_TOP + trunkHeight / 2,
		z,
		1.1 * s,
		trunkHeight,
		1.1 * s,
		PALETTE.trunk,
		"Wood"
	)
	local crown = 6.5 * s
	block(
		items,
		"TreeCrown",
		x,
		SLAB_TOP + trunkHeight + crown * 0.35,
		z,
		crown,
		crown * 0.8,
		crown,
		leaves,
		"Grass"
	)
	block(
		items,
		"TreeCrown",
		x,
		SLAB_TOP + trunkHeight + crown * 0.75,
		z,
		crown * 0.75,
		crown * 0.6,
		crown * 0.75,
		leaves,
		"Grass",
		{ yaw = math.pi / 4 }
	)
end

local function bench(items: { Item }, x: number, z: number, yaw: number)
	block(items, "Bench", x, SLAB_TOP + 0.9, z, 4, 0.4, 1.4, PALETTE.bench, "Wood", { yaw = yaw })
	block(
		items,
		"BenchLegs",
		x,
		SLAB_TOP + 0.35,
		z,
		3.4,
		0.7,
		1,
		PALETTE.lamp,
		"Metal",
		{ yaw = yaw, flat = true }
	)
end

local function lamp(items: { Item }, x: number, z: number)
	block(items, "LampPost", x, SLAB_TOP + 3.5, z, 0.4, 7, 0.4, PALETTE.lamp, "Metal", { flat = true })
	block(
		items,
		"LampGlow",
		x,
		SLAB_TOP + 7.2,
		z,
		1.2,
		1.2,
		1.2,
		PALETTE.lampGlow,
		"SmoothPlastic",
		{ shape = "Ball", flat = true }
	)
end

-- Edificio con franjas de ventanas, cornisa y algo en la azotea.
local function building(items: { Item }, rng: Rng, cx: number, cz: number, w: number, d: number, h: number)
	local wall = pick(rng, PALETTE.walls)
	local glassy = nextRandom(rng) < 0.3
	local body = if glassy then pick(rng, PALETTE.glass) else wall
	block(items, "Building", cx, SLAB_TOP + h / 2, cz, w, h, d, body, if glassy then "Glass" else "Concrete")
	-- Franjas de ventanas cada planta: ligeramente más anchas que la fachada.
	local window = if glassy then "#9FC3D9" else pick(rng, PALETTE.glass)
	local floor = 6
	local y = SLAB_TOP + floor * 0.75
	while y < SLAB_TOP + h - floor * 0.5 do
		block(items, "Windows", cx, y, cz, w + 0.3, 1.6, d + 0.3, window, "Glass", { flat = true })
		y += floor
	end
	-- Cornisa y azotea.
	local roof = pick(rng, PALETTE.roofs)
	block(items, "Cornice", cx, SLAB_TOP + h + 0.4, cz, w + 0.8, 0.8, d + 0.8, roof, "Slate")
	local extra = nextRandom(rng)
	if extra < 0.4 then
		-- Depósito de agua sobre patas, típico de la ciudad.
		local tankX, tankZ = cx + w * 0.2, cz - d * 0.2
		block(
			items,
			"TankLegs",
			tankX,
			SLAB_TOP + h + 2,
			tankZ,
			2.4,
			3.2,
			2.4,
			PALETTE.lamp,
			"Metal",
			{ flat = true }
		)
		block(
			items,
			"WaterTank",
			tankX,
			SLAB_TOP + h + 4.8,
			tankZ,
			4,
			3.6,
			4,
			"#7A5A3C",
			"Wood",
			{ shape = "Disk" }
		)
	elseif extra < 0.8 then
		block(
			items,
			"RoofUnit",
			cx - w * 0.15,
			SLAB_TOP + h + 1.6,
			cz + d * 0.15,
			w * 0.3,
			2,
			d * 0.25,
			"#9A9EA4",
			"Metal"
		)
	end
end

-- Casa con tejado a dos aguas.
local function house(items: { Item }, rng: Rng, cx: number, cz: number, w: number, d: number, yaw: number)
	local wallColor = pick(rng, PALETTE.walls)
	local roofColor = pick(rng, PALETTE.houseRoofs)
	local h = between(rng, 6, 8)
	block(items, "House", cx, SLAB_TOP + h / 2, cz, w, h, d, wallColor, "Brick", { yaw = yaw })
	-- Dos cuñas forman el tejado: cada una cubre media casa a lo ancho.
	local rise = 3.5
	local cos, sin = math.cos(yaw), math.sin(yaw)
	for _, side in { -1, 1 } do
		-- Desplazamiento a lo ancho (eje x local) de cada mitad.
		local ox = side * w / 4
		local wx, wz = cx + cos * ox, cz - sin * ox
		-- La cuña sube a lo largo de su eje Z: la pendiente va a lo ancho de la casa y la cumbrera, en X.
		block(
			items,
			"HouseRoof",
			wx,
			SLAB_TOP + h + rise / 2,
			wz,
			d + 0.8,
			rise,
			w / 2 + 0.6,
			roofColor,
			"Slate",
			{
				shape = "Wedge",
				yaw = yaw + (if side > 0 then -math.pi / 2 else math.pi / 2),
			}
		)
	end
	-- Puerta.
	block(
		items,
		"Door",
		cx - sin * (d / 2 + 0.05),
		SLAB_TOP + 2,
		cz - cos * (d / 2 + 0.05),
		2,
		4,
		0.2,
		"#5A3E2B",
		"Wood",
		{ yaw = yaw, flat = true }
	)
end

-- Manzanas ---------------------------------------------------------------------------------------------

local function sidewalkRim(items: { Item }, cell: Cell)
	slab(items, "Sidewalk", cell.x0, cell.z0, cell.x1, cell.z1, PALETTE.pavement, "Pavement")
end

local function inner(cell: Cell): (number, number, number, number)
	return cell.x0 + CURB, cell.z0 + CURB, cell.x1 - CURB, cell.z1 - CURB
end

local function buildTowers(items: { Item }, rng: Rng, cell: Cell)
	sidewalkRim(items, cell)
	local x0, z0, x1 = inner(cell)
	local half = (x1 - x0) / 2
	for a = 0, 1 do
		for b = 0, 1 do
			local px0, pz0 = x0 + a * half, z0 + b * half
			local footprint = half - 5
			local cx, cz = px0 + half / 2, pz0 + half / 2
			building(
				items,
				rng,
				cx,
				cz,
				footprint * between(rng, 0.75, 1),
				footprint * between(rng, 0.75, 1),
				between(rng, 32, 78)
			)
		end
	end
end

local function buildMidrise(items: { Item }, rng: Rng, cell: Cell)
	sidewalkRim(items, cell)
	local x0, z0, x1, z1 = inner(cell)
	local width = x1 - x0
	local count = 3
	local step = width / count
	for k = 0, count - 1 do
		local cx = x0 + step * (k + 0.5)
		building(items, rng, cx, z0 + (z1 - z0) * 0.3, step - 3, (z1 - z0) * 0.45, between(rng, 14, 28))
	end
	-- Patio trasero con árboles.
	slab(items, "Courtyard", x0, z0 + (z1 - z0) * 0.6, x1, z1, PALETTE.grass, "Grass", 0.02)
	for k = 0, count - 1 do
		tree(items, rng, x0 + step * (k + 0.5), z0 + (z1 - z0) * 0.8)
	end
end

local function buildHouses(items: { Item }, rng: Rng, cell: Cell)
	sidewalkRim(items, cell)
	local x0, z0, x1, z1 = inner(cell)
	slab(items, "Gardens", x0, z0, x1, z1, PALETTE.grass, "Grass", 0.02)
	local cols, rows = 3, 2
	local stepX, stepZ = (x1 - x0) / cols, (z1 - z0) / rows
	for a = 0, cols - 1 do
		for b = 0, rows - 1 do
			local cx, cz = x0 + stepX * (a + 0.5), z0 + stepZ * (b + 0.5)
			-- Las de la fila de delante miran a un lado y las de detrás al otro: dan a la calle.
			local yaw = if b == 0 then 0 else math.pi
			local w, d = math.min(stepX - 6, 13), math.min(stepZ - 10, 10)
			house(items, rng, cx, cz + (if b == 0 then -2 else 2), w, d, yaw)
			tree(items, rng, cx + stepX * 0.32, cz + (if b == 0 then 4 else -4), 0.8)
		end
	end
end

local function buildPark(items: { Item }, rng: Rng, cell: Cell)
	sidewalkRim(items, cell)
	local x0, z0, x1, z1 = inner(cell)
	slab(items, "Park", x0, z0, x1, z1, PALETTE.grass, "Grass", 0.02)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	-- Caminos en cruz.
	block(
		items,
		"Path",
		cx,
		SLAB_TOP + 0.05,
		cz,
		x1 - x0,
		0.12,
		3,
		PALETTE.pavement,
		"Pavement",
		{ flat = true }
	)
	block(
		items,
		"Path",
		cx,
		SLAB_TOP + 0.05,
		cz,
		3,
		0.12,
		z1 - z0,
		PALETTE.pavement,
		"Pavement",
		{ flat = true }
	)
	-- Estanque en un cuarto.
	block(
		items,
		"Pond",
		x0 + (x1 - x0) * 0.27,
		SLAB_TOP + 0.08,
		z0 + (z1 - z0) * 0.27,
		(x1 - x0) * 0.32,
		0.15,
		1,
		PALETTE.water,
		"Water",
		{ shape = "Disk", flat = true }
	)
	-- Árboles alrededor y bancos junto al cruce.
	local quarterX, quarterZ = (x1 - x0) / 4, (z1 - z0) / 4
	for _, spot in { { 3, 1 }, { 3, 3 }, { 1, 3 }, { 3.6, 0.4 }, { 0.4, 3.6 }, { 2.4, 3.6 }, { 3.6, 2.4 } } do
		tree(items, rng, x0 + quarterX * spot[1], z0 + quarterZ * spot[2])
	end
	bench(items, cx + 5, cz + 3.5, 0)
	bench(items, cx - 5, cz - 3.5, math.pi)
	lamp(items, cx + 3, cz + 3)
end

local function courtLines(items: { Item }, cx: number, cz: number, w: number, d: number)
	local t = 0.4
	local y = SLAB_TOP + 0.14
	block(items, "Line", cx, y, cz - d / 2, w, 0.05, t, PALETTE.line, "SmoothPlastic", { flat = true })
	block(items, "Line", cx, y, cz + d / 2, w, 0.05, t, PALETTE.line, "SmoothPlastic", { flat = true })
	block(items, "Line", cx - w / 2, y, cz, t, 0.05, d, PALETTE.line, "SmoothPlastic", { flat = true })
	block(items, "Line", cx + w / 2, y, cz, t, 0.05, d, PALETTE.line, "SmoothPlastic", { flat = true })
	block(items, "Line", cx, y, cz, w, 0.05, t, PALETTE.line, "SmoothPlastic", { flat = true })
	block(
		items,
		"CenterCircle",
		cx,
		y,
		cz,
		w * 0.25,
		0.04,
		1,
		PALETTE.line,
		"SmoothPlastic",
		{ shape = "Disk", flat = true }
	)
end

local function buildCourt(items: { Item }, rng: Rng, cell: Cell)
	sidewalkRim(items, cell)
	local x0, z0, x1, z1 = inner(cell)
	slab(items, "CourtGround", x0, z0, x1, z1, PALETTE.grassDark, "Grass", 0.02)
	local width = x1 - x0
	local half = (z1 - z0) / 2
	for k = 0, 1 do
		local cz = z0 + half * (k + 0.5)
		local cw, cd = width - 8, half - 8
		local color = PALETTE.court[k + 1 + (if nextRandom(rng) < 0.5 then 1 else 0)]
		block(
			items,
			"Court",
			(x0 + x1) / 2,
			SLAB_TOP + 0.08,
			cz,
			cw,
			0.12,
			cd,
			color,
			"SmoothPlastic",
			{ flat = true }
		)
		courtLines(items, (x0 + x1) / 2, cz, cw - 2, cd - 2)
		-- Canastas en los fondos.
		for _, side in { -1, 1 } do
			local hx = (x0 + x1) / 2 + side * (cw / 2 - 1.5)
			block(
				items,
				"HoopPost",
				hx,
				SLAB_TOP + 3,
				cz,
				0.4,
				6,
				0.4,
				PALETTE.lamp,
				"Metal",
				{ flat = true }
			)
			block(
				items,
				"HoopBoard",
				hx - side * 0.4,
				SLAB_TOP + 6.2,
				cz,
				0.2,
				2.2,
				3.4,
				"#F2F2F2",
				"SmoothPlastic",
				{ flat = true }
			)
		end
		-- Valla metálica alrededor.
		local fy = SLAB_TOP + 2.5
		for _, edge in { -1, 1 } do
			block(
				items,
				"Fence",
				(x0 + x1) / 2,
				fy,
				cz + edge * (cd / 2 + 2),
				cw + 4,
				5,
				0.2,
				PALETTE.fence,
				"Metal",
				{ transparency = 0.55, flat = true }
			)
			block(
				items,
				"Fence",
				(x0 + x1) / 2 + edge * (cw / 2 + 2),
				fy,
				cz,
				0.2,
				5,
				cd + 4,
				PALETTE.fence,
				"Metal",
				{ transparency = 0.55, flat = true }
			)
		end
	end
end

local function buildSite(items: { Item }, rng: Rng, cell: Cell)
	sidewalkRim(items, cell)
	local x0, z0, x1, z1 = inner(cell)
	slab(items, "Dirt", x0, z0, x1, z1, PALETTE.dirt, "Ground", 0.02)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local w, d = (x1 - x0) * 0.45, (z1 - z0) * 0.45
	-- Estructura a medio levantar: pilares y dos forjados.
	local floors = 3
	for floor = 1, floors do
		block(items, "SiteFloor", cx, SLAB_TOP + floor * 6, cz, w, 0.8, d, PALETTE.concrete, "Concrete")
	end
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		block(
			items,
			"SiteColumn",
			cx + corner[1] * (w / 2 - 0.8),
			SLAB_TOP + floors * 3,
			cz + corner[2] * (d / 2 - 0.8),
			1.2,
			floors * 6,
			1.2,
			PALETTE.concrete,
			"Concrete"
		)
	end
	-- Grúa torre: mástil, pluma y contrapeso.
	local mastX, mastZ = x1 - 6, z0 + 6
	local mastHeight = 52
	block(
		items,
		"CraneMast",
		mastX,
		SLAB_TOP + mastHeight / 2,
		mastZ,
		2,
		mastHeight,
		2,
		PALETTE.crane,
		"Metal"
	)
	local jib = (x1 - x0) * 0.7
	block(
		items,
		"CraneJib",
		mastX - jib / 2 + 6,
		SLAB_TOP + mastHeight + 1,
		mastZ,
		jib,
		1.4,
		1.4,
		PALETTE.crane,
		"Metal"
	)
	block(
		items,
		"CraneWeight",
		mastX + 7,
		SLAB_TOP + mastHeight,
		mastZ,
		4,
		2.4,
		3,
		PALETTE.concrete,
		"Concrete"
	)
	-- Materiales apilados y conos.
	for k = 0, 2 do
		block(items, "Pallet", x0 + 6 + k * 5, SLAB_TOP + 1, z1 - 6, 4, 2, 4, "#B08A5A", "Wood")
	end
	for k = 0, 3 do
		block(
			items,
			"Cone",
			x0 + 4 + k * 4,
			SLAB_TOP + 0.7,
			z0 + 3,
			0.9,
			1.4,
			0.9,
			PALETTE.cone,
			"SmoothPlastic",
			{ flat = true }
		)
	end
	tree(items, rng, x0 + 5, cz)
end

-- Parque central con la plaza y la fuente: el corazón de la ciudad.
local function buildPlaza(items: { Item }, rng: Rng, cell: Cell)
	sidewalkRim(items, cell)
	local x0, z0, x1, z1 = inner(cell)
	slab(items, "CentralPark", x0, z0, x1, z1, PALETTE.grass, "Grass", 0.02)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local size = math.min(x1 - x0, z1 - z0)
	local plaza = size * 0.55
	-- Caminos que llegan a la plaza desde las cuatro calles.
	block(
		items,
		"PlazaPath",
		cx,
		SLAB_TOP + 0.06,
		cz,
		x1 - x0,
		0.12,
		4,
		PALETTE.pavement,
		"Pavement",
		{ flat = true }
	)
	block(
		items,
		"PlazaPath",
		cx,
		SLAB_TOP + 0.06,
		cz,
		4,
		0.12,
		z1 - z0,
		PALETTE.pavement,
		"Pavement",
		{ flat = true }
	)
	-- Plaza redonda de piedra y un anillo más oscuro.
	block(
		items,
		"Plaza",
		cx,
		SLAB_TOP + 0.1,
		cz,
		plaza,
		0.2,
		1,
		PALETTE.stone,
		"Pavement",
		{ shape = "Disk", flat = true }
	)
	block(
		items,
		"PlazaRing",
		cx,
		SLAB_TOP + 0.12,
		cz,
		plaza * 0.62,
		0.2,
		1,
		"#BDB3A0",
		"Pavement",
		{ shape = "Disk", flat = true }
	)
	-- Fuente: pila, agua, columna y taza.
	local basin = plaza * 0.36
	block(
		items,
		"FountainBasin",
		cx,
		SLAB_TOP + 0.9,
		cz,
		basin,
		1.6,
		1,
		PALETTE.stone,
		"Concrete",
		{ shape = "Disk" }
	)
	block(
		items,
		"FountainWater",
		cx,
		SLAB_TOP + 1.25,
		cz,
		basin - 1.6,
		1.6,
		1,
		PALETTE.water,
		"Water",
		{ shape = "Disk", flat = true }
	)
	block(
		items,
		"FountainColumn",
		cx,
		SLAB_TOP + 3.5,
		cz,
		2.4,
		5,
		1,
		PALETTE.stone,
		"Concrete",
		{ shape = "Disk" }
	)
	block(
		items,
		"FountainBowl",
		cx,
		SLAB_TOP + 6,
		cz,
		basin * 0.4,
		0.8,
		1,
		PALETTE.stone,
		"Concrete",
		{ shape = "Disk" }
	)
	-- Bancos y farolas alrededor de la plaza.
	local ring = plaza / 2 - 3
	for k = 0, 7 do
		local angle = k * math.pi / 4 + math.pi / 8
		local bx, bz = cx + math.sin(angle) * ring, cz + math.cos(angle) * ring
		bench(items, bx, bz, angle)
		if k % 2 == 0 then
			lamp(
				items,
				cx + math.sin(angle + math.pi / 8) * (ring + 2),
				cz + math.cos(angle + math.pi / 8) * (ring + 2)
			)
		end
	end
	-- Arboleda alrededor de la plaza.
	local grove = plaza / 2 + (size / 2 - plaza / 2) * 0.55
	for k = 0, 11 do
		local angle = k * math.pi / 6 + math.pi / 12
		tree(items, rng, cx + math.sin(angle) * grove, cz + math.cos(angle) * grove, 1.15)
	end
end

local BUILDERS: { [CellKind]: (items: { Item }, rng: Rng, cell: Cell) -> () } = {
	Plaza = buildPlaza,
	Towers = buildTowers,
	Midrise = buildMidrise,
	Houses = buildHouses,
	Park = buildPark,
	Court = buildCourt,
	Site = buildSite,
}

-- Calles y paseo: el asfalto entre manzanas y la franja verde junto a la trasera de los solares.
local function buildStreets(items: { Item }, rng: Rng, sizeId: CityLayout.SizeId, cells: { Cell })
	local low, high = CityInterior.bounds(sizeId)
	local count = GRID[sizeId]
	-- Paseo verde con árboles entre los solares y las manzanas.
	slab(
		items,
		"Greenway",
		low - BUFFER,
		low - BUFFER,
		high + BUFFER,
		high + BUFFER,
		PALETTE.grassDark,
		"Grass",
		-0.05
	)
	local first = cells[1]
	local size = first.x1 - first.x0
	for k = 1, count - 1 do
		local at = low + k * size + (k - 1) * ROAD + ROAD / 2
		block(
			items,
			"Road",
			at,
			SLAB_TOP - 0.1,
			(low + high) / 2,
			ROAD,
			0.3,
			high - low,
			PALETTE.asphalt,
			"Asphalt",
			{ flat = true }
		)
		block(
			items,
			"Road",
			(low + high) / 2,
			SLAB_TOP - 0.1,
			at,
			high - low,
			0.3,
			ROAD,
			PALETTE.asphalt,
			"Asphalt",
			{ flat = true }
		)
		-- Línea discontinua en el centro.
		local dash = low + 4
		while dash < high - 4 do
			block(
				items,
				"RoadDash",
				at,
				SLAB_TOP + 0.06,
				dash + 2,
				0.4,
				0.05,
				4,
				PALETTE.line,
				"SmoothPlastic",
				{ flat = true }
			)
			block(
				items,
				"RoadDash",
				dash + 2,
				SLAB_TOP + 0.06,
				at,
				4,
				0.05,
				0.4,
				PALETTE.line,
				"SmoothPlastic",
				{ flat = true }
			)
			dash += 10
		end
	end
	-- Árboles en el paseo, cada pocos metros por los cuatro lados.
	local spot = low + 6
	while spot < high - 6 do
		for _, pair in
			{
				{ spot, low - BUFFER / 2 },
				{ spot, high + BUFFER / 2 },
				{ low - BUFFER / 2, spot },
				{ high + BUFFER / 2, spot },
			}
		do
			tree(items, rng, pair[1], pair[2], 0.7)
		end
		spot += 22
	end
end

-- Piezas del interior del anillo, en un orden fijo.
function CityInterior.itemsFor(sizeId: CityLayout.SizeId): { Item }
	local items: { Item } = {}
	local cells = CityInterior.cellsFor(sizeId)
	local rng: Rng = { seed = SEEDS[sizeId] * 7 + 3 }
	buildStreets(items, rng, sizeId, cells)
	for _, cell in cells do
		BUILDERS[cell.kind](items, rng, cell)
	end
	return items
end

-- Borde exterior: los fondos de barrio van a 72 studs de la calle. Más allá, arboledas que cierran la
-- ciudad, y un parquecito en cada esquina, donde no hay fondo.
local EXTERIOR_TREES_FROM = 128
local EXTERIOR_ROWS = 2
local EXTERIOR_ROW_GAP = 14
local EXTERIOR_STEP = 26
local CORNER_PARK = 40

function CityInterior.exteriorFor(sizeId: CityLayout.SizeId): { Item }
	local items: { Item } = {}
	local span = CityLayout.spanFor(sizeId)
	local rng: Rng = { seed = SEEDS[sizeId] * 13 + 5 }
	for row = 0, EXTERIOR_ROWS - 1 do
		local out = EXTERIOR_TREES_FROM + row * EXTERIOR_ROW_GAP
		local along = -out + (row * EXTERIOR_STEP / 2)
		while along <= span + out do
			local jitter = between(rng, -3, 3)
			tree(items, rng, along, -out + jitter)
			tree(items, rng, along, span + out + jitter)
			tree(items, rng, -out + jitter, along)
			tree(items, rng, span + out + jitter, along)
			along += EXTERIOR_STEP
		end
	end
	-- Parquecitos en las cuatro esquinas, entre la calle y las arboledas.
	local reach = CityLayout.STREET_WIDTH_STUDS / 2 + CityLayout.SIDEWALK_STUDS + CityLayout.LOT_DEPTH_STUDS
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local cx = if corner[1] < 0 then -reach - CORNER_PARK / 2 - 4 else span + reach + CORNER_PARK / 2 + 4
		local cz = if corner[2] < 0 then -reach - CORNER_PARK / 2 - 4 else span + reach + CORNER_PARK / 2 + 4
		block(
			items,
			"CornerPath",
			cx,
			SLAB_TOP + 0.05,
			cz,
			CORNER_PARK,
			0.12,
			3,
			PALETTE.pavement,
			"Pavement",
			{ flat = true }
		)
		block(
			items,
			"CornerPond",
			cx - 8,
			SLAB_TOP + 0.08,
			cz + 8,
			12,
			0.15,
			1,
			PALETTE.water,
			"Water",
			{ shape = "Disk", flat = true }
		)
		for k = 0, 4 do
			tree(items, rng, cx - CORNER_PARK / 2 + 6 + k * 7, cz - 9)
		end
		bench(items, cx + 6, cz + 3, 0)
		lamp(items, cx, cz + 4)
	end
	return items
end

return CityInterior

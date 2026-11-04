--!strict
-- Pruebas de la ruta de la ciudad por tamaño. La ruta es pura (sin Instance ni Vector3): devuelve
-- posiciones como tablas `{ x, y, z }` para poder comprobarla con Lune. Cubren los criterios de la
-- Tarea 2: una ruta cerrada por tamaño, la distancia máxima entre casillas consecutivas, la
-- colocación estable de Centro y Puerto y los puentes de Zona Alta e Industrial.
local Harness = require("../harness")
local Boards = require("../../src/shared/config/Boards")
local CityLayout = require("../../src/shared/config/CityLayout")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local SIZES: { CityLayout.SizeId } = { "S", "M", "L" }

local function distance(a: CityLayout.Vector3Like, b: CityLayout.Vector3Like): number
	local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Cuántas casillas tiene el tablero según `Boards`, que es la fuente de verdad de la composición.
local function boardSquares(sizeId: CityLayout.SizeId): number
	return #Boards.get(sizeId).squares
end

local function barrios(route: { CityLayout.Slot }): { string }
	local out: { string } = {}
	for _, slot in route do
		table.insert(out, slot.barrioId)
	end
	return out
end

describe("CityLayout.routeFor", function()
	it("cada tamaño tiene una posición por casilla del tablero", function()
		for _, sizeId in SIZES do
			expect(#CityLayout.routeFor(sizeId)).toBe(boardSquares(sizeId))
		end
	end)

	it("los tableros son de 40, 48 y 56 casillas", function()
		expect(#CityLayout.routeFor("S")).toBe(40)
		expect(#CityLayout.routeFor("M")).toBe(48)
		expect(#CityLayout.routeFor("L")).toBe(56)
	end)

	it("la ruta está cerrada: la última casilla vuelve a la primera", function()
		for _, sizeId in SIZES do
			local route = CityLayout.routeFor(sizeId)
			local step = distance(route[#route].position, route[1].position)
			expect(step <= CityLayout.MAX_STEP_STUDS).toBe(true)
			expect(distance(route[1].position, route[2].position) > 0).toBe(true)
		end
	end)

	it("ninguna distancia entre casillas consecutivas pasa de 60 studs", function()
		for _, sizeId in SIZES do
			local route = CityLayout.routeFor(sizeId)
			local longest = 0
			for index, slot in route do
				local nextSlot = route[if index == #route then 1 else index + 1]
				local step = distance(slot.position, nextSlot.position)
				if step > longest then
					longest = step
				end
			end
			expect(longest <= CityLayout.MAX_STEP_STUDS).toBe(true)
			expect(longest <= 60).toBe(true)
		end
	end)

	it("todas las casillas están a la altura del suelo", function()
		for _, sizeId in SIZES do
			for _, slot in CityLayout.routeFor(sizeId) do
				expect(slot.position.y).toBe(0)
			end
		end
	end)

	it("cada casilla mira hacia la siguiente", function()
		for _, sizeId in SIZES do
			local route = CityLayout.routeFor(sizeId)
			for index, slot in route do
				local nextSlot = route[if index == #route then 1 else index + 1]
				local dx = nextSlot.position.x - slot.position.x
				local dz = nextSlot.position.z - slot.position.z
				expect(math.abs(slot.facing - math.atan2(dx, dz)) < 1e-6).toBe(true)
			end
		end
	end)

	it("la Salida abre la ruta en la misma esquina en los tres tamaños", function()
		local first = CityLayout.routeFor("S")[1].position
		for _, sizeId in SIZES do
			local slot = CityLayout.routeFor(sizeId)[1]
			expect(slot.position.x).toBe(first.x)
			expect(slot.position.z).toBe(first.z)
			expect(slot.index).toBe(1)
		end
	end)

	it("cada casilla lleva el número, el barrio y el tipo de su casilla del tablero", function()
		for _, sizeId in SIZES do
			local board = Boards.get(sizeId)
			for index, slot in CityLayout.routeFor(sizeId) do
				expect(slot.index).toBe(index)
				expect(slot.barrioId).toBe(board.squares[index].barrioId)
				expect(slot.kind).toBe(board.squares[index].kind)
			end
		end
	end)
end)

describe("CityLayout: colocación de los barrios", function()
	-- El orden de los barrios a lo largo de la ruta. La ciudad crece hacia fuera: Centro, Puerto,
	-- Zona Alta e Industrial. Es la regla que hace que Centro y Puerto ocupen la cabeza de la ruta
	-- en los tres tamaños, aunque la ruta tenga más casillas.
	local ORDER = { Centro = 1, Puerto = 2, ZonaAlta = 3, Industrial = 4 }

	local function isNonDecreasing(values: { string }): boolean
		local highest = 0
		for _, value in values do
			local rank = ORDER[value]
			if rank == nil or rank < highest then
				return false
			end
			highest = rank
		end
		return true
	end

	it("los barrios nunca retroceden a lo largo de la ruta", function()
		for _, sizeId in SIZES do
			expect(isNonDecreasing(barrios(CityLayout.routeFor(sizeId)))).toBe(true)
		end
	end)

	it("Centro y Puerto abren la ruta en los tres tamaños", function()
		for _, sizeId in SIZES do
			local route = CityLayout.routeFor(sizeId)
			expect(route[1].barrioId).toBe("Centro")
			-- Ninguna casilla de un barrio posterior aparece antes de la última de las dos
			-- primeras: Centro y Puerto son siempre la cabeza de la ciudad.
			local limite = 0
			for index, slot in route do
				if slot.barrioId == "Centro" or slot.barrioId == "Puerto" then
					limite = index
				end
			end
			for index = 1, limite do
				local barrio = route[index].barrioId
				expect(barrio == "Centro" or barrio == "Puerto").toBe(true)
			end
		end
	end)

	it("la Zona Alta solo existe a partir del tablero mediano", function()
		local small = barrios(CityLayout.routeFor("S"))
		expect(table.find(small, "ZonaAlta")).toBe(nil)
		expect(table.find(small, "Industrial")).toBe(nil)
		expect(table.find(barrios(CityLayout.routeFor("M")), "ZonaAlta") ~= nil).toBe(true)
		expect(table.find(barrios(CityLayout.routeFor("M")), "Industrial")).toBe(nil)
		expect(table.find(barrios(CityLayout.routeFor("L")), "Industrial") ~= nil).toBe(true)
	end)
end)

describe("CityLayout.bridgesFor", function()
	-- Islas: el continente reúne Centro y Puerto; Zona Alta e Industrial son islas aparte. Un
	-- puente es exactamente la arista de la ruta que cruza de una isla a otra.
	it("el tablero pequeño no necesita puentes", function()
		expect(#CityLayout.bridgesFor("S")).toBe(0)
	end)

	it("cada puente une dos islas distintas", function()
		for _, sizeId in SIZES do
			local route = CityLayout.routeFor(sizeId)
			for _, bridge in CityLayout.bridgesFor(sizeId) do
				local from = route[bridge.fromIndex]
				local to = route[bridge.toIndex]
				expect(from ~= nil).toBe(true)
				expect(to ~= nil).toBe(true)
				expect(CityLayout.islandOf(from.barrioId) ~= CityLayout.islandOf(to.barrioId)).toBe(true)
				expect(bridge.barrioId).toBe(CityLayout.islandOf(to.barrioId))
			end
		end
	end)

	it("cada isla exterior entra y sale por un puente", function()
		for _, sizeId in SIZES do
			local route = CityLayout.routeFor(sizeId)
			-- Un puente toca dos islas: la de salida y la de llegada.
			local toques: { [string]: number } = {}
			for _, bridge in CityLayout.bridgesFor(sizeId) do
				local salida = CityLayout.islandOf(route[bridge.fromIndex].barrioId)
				local llegada = CityLayout.islandOf(route[bridge.toIndex].barrioId)
				for _, island in { salida, llegada } do
					if island ~= "Mainland" then
						toques[island] = (toques[island] or 0) + 1
					end
				end
			end
			local exteriores: { [string]: boolean } = {}
			for _, slot in route do
				local island = CityLayout.islandOf(slot.barrioId)
				if island ~= "Mainland" then
					exteriores[island] = true
				end
			end
			for island in exteriores do
				expect((toques[island] or 0) >= 2).toBe(true)
			end
		end
	end)

	it("el puente arranca en su casilla y apunta a la siguiente", function()
		for _, sizeId in SIZES do
			local route = CityLayout.routeFor(sizeId)
			for _, bridge in CityLayout.bridgesFor(sizeId) do
				local from = route[bridge.fromIndex]
				local to = route[bridge.toIndex]
				expect(bridge.start.x).toBe(from.position.x)
				expect(bridge.start.z).toBe(from.position.z)
				expect(bridge.lengthStuds <= CityLayout.MAX_STEP_STUDS).toBe(true)
				local dx = to.position.x - from.position.x
				local dz = to.position.z - from.position.z
				expect(math.abs(bridge.facing - math.atan2(dx, dz)) < 1e-6).toBe(true)
			end
		end
	end)

	it("no hay puentes donde la ruta no cambia de isla", function()
		for _, sizeId in SIZES do
			local route = CityLayout.routeFor(sizeId)
			local puentes: { [string]: boolean } = {}
			for _, bridge in CityLayout.bridgesFor(sizeId) do
				puentes[`{bridge.fromIndex}>{bridge.toIndex}`] = true
			end
			for index = 1, #route do
				local nextIndex = if index == #route then 1 else index + 1
				local changes = CityLayout.islandOf(route[index].barrioId)
					~= CityLayout.islandOf(route[nextIndex].barrioId)
				expect(puentes[`{index}>{nextIndex}`] == true).toBe(changes)
			end
		end
	end)
end)
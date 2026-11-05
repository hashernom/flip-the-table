--!strict
-- Pruebas de las reglas de la detención. Son puras: reparto del tiempo, posiciones de las patrullas y de los
-- policías, la vuelta al mapa desde la esquina Tribunal hasta la cárcel, y el giro suave de los rumbos.
-- Se prueban en S, M y L.
local Harness = require("../harness")
local ArrestRules = require("../../src/client/scenes/ArrestRules")
local CityLayout = require("../../src/shared/config/CityLayout")
local Scenes = require("../../src/shared/config/Scenes")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local SIZES = { "S", "M", "L" }
local EPS = 1e-6
local HALF_STREET = CityLayout.STREET_WIDTH_STUDS / 2
local MIN_GAP_STUDS = 6

-- Esquina Tribunal de un tamaño, con su marco y la casilla.
local function tribunalOf(size: string)
	local slot = ArrestRules.tribunalSlot(CityLayout.routeFor(size :: any))
	expect(slot ~= nil).toBe(true)
	local found = slot :: CityLayout.Slot
	return found, ArrestRules.frameOf(found)
end

local function distanceXZ(a: { x: number, z: number }, b: { x: number, z: number }): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

local function distanceLocal(a: ArrestRules.Local, b: ArrestRules.Local): number
	return math.sqrt((a.along - b.along) ^ 2 + (a.side - b.side) ^ 2)
end

describe("ArrestRules.FRACTIONS", function()
	it("las fracciones suman 1 y son positivas", function()
		local total = 0
		for _, name in ArrestRules.STEPS do
			local fraction = ArrestRules.FRACTIONS[name]
			expect(fraction > 0).toBe(true)
			total += fraction
		end
		expect(math.abs(total - 1) < EPS).toBe(true)
	end)

	it("las ventanas van en orden, sin huecos, y la última acaba en la duración", function()
		for _, duration in { 15, 7.5, 0.2 } do
			local windows = ArrestRules.windows(duration)
			local previous = 0
			for _, name in ArrestRules.STEPS do
				local window = windows[name]
				expect(math.abs(window.from - previous) < EPS).toBe(true)
				expect(window.to > window.from).toBe(true)
				previous = window.to
			end
			expect(math.abs(previous - duration) < EPS).toBe(true)
		end
	end)

	it("una duración rota no da ventanas con tiempo negativo", function()
		local windows = ArrestRules.windows(-4)
		expect(windows.detach.from).toBe(0)
		expect(windows.gate.to).toBe(0)
	end)

	it("el avance de un paso va de 0 a 1 y se queda en los extremos", function()
		local window = { from = 2, to = 4 }
		expect(ArrestRules.progress(window, 1)).toBe(0)
		expect(ArrestRules.progress(window, 3)).toBe(0.5)
		expect(ArrestRules.progress(window, 9)).toBe(1)
		expect(ArrestRules.progress({ from = 2, to = 2 }, 2)).toBe(1)
	end)
end)

describe("ArrestRules: geometría de la esquina Tribunal", function()
	for _, size in SIZES do
		it(
			`en el tablero {size} hay casilla Tribunal y el marco la sitúa donde la pinta la ciudad`,
			function()
				local slot, frame = tribunalOf(size)
				local detained = ArrestRules.toWorld(frame, ArrestRules.DETAINED)
				local center = CityLayout.slotCenter(slot)
				expect(math.abs(detained.x - center.x) < EPS).toBe(true)
				expect(math.abs(detained.z - center.z) < EPS).toBe(true)
			end
		)

		it(
			`en el tablero {size} la cárcel queda al otro lado de la acera, en el solar de la casilla`,
			function()
				local slot, frame = tribunalOf(size)
				local gate = ArrestRules.toWorld(frame, ArrestRules.gate())
				local lot = CityLayout.lotCenter(slot)
				-- La entrada cae en el borde del solar que da a la calle: a media profundidad del solar.
				expect(distanceXZ(gate, lot) <= CityLayout.LOT_DEPTH_STUDS / 2 + EPS).toBe(true)
				expect(ArrestRules.gate().side < 0).toBe(true)
			end
		)
	end

	it(
		"la fachada de la cárcel queda en side -29, con el solar, la acera y el fondo del edificio",
		function()
			expect(ArrestRules.gate().along).toBe(0)
			expect(ArrestRules.gate().side).toBe(-29)
		end
	)

	it("la puerta está en la fachada y el coche entero queda tras ella", function()
		expect(ArrestRules.JAIL_INSIDE_SIDE).toBe(ArrestRules.gate().side - 7)
	end)
end)

describe("ArrestRules: patrullas y policías", function()
	it(
		"la patrulla A aparca delante (along +) y la B detrás (along -), las dos a cada lado del detenido",
		function()
			expect(ArrestRules.CARS.A.spot.along > ArrestRules.DETAINED.along).toBe(true)
			expect(ArrestRules.CARS.B.spot.along < ArrestRules.DETAINED.along).toBe(true)
			for _, key in { "A", "B" } do
				local spot = ArrestRules.CARS[key].spot
				expect(math.abs(spot.side - ArrestRules.DETAINED.side) <= HALF_STREET).toBe(true)
				-- Llegan desde lejos, por la calzada, y no desde dentro de la casilla.
				expect(ArrestRules.CARS[key].arrival.side > spot.side).toBe(true)
			end
		end
	)

	it("los policías salen de la patrulla A y acaban junto al detenido, a su lado", function()
		for _, officer in ArrestRules.OFFICERS do
			expect(officer.flank.along).toBe(3)
			expect(math.abs(officer.start.side - ArrestRules.CARS.A.spot.side) <= 4).toBe(true)
			expect(math.abs(officer.flank.side - ArrestRules.DETAINED.side) <= 4).toBe(true)
		end
	end)
end)

describe("ArrestRules: vuelta al mapa", function()
	for _, size in SIZES do
		local function routesOf()
			local route = CityLayout.routeFor(size :: any)
			local slot = ArrestRules.tribunalSlot(route) :: CityLayout.Slot
			return ArrestRules.routes(route, slot), route
		end

		it(`en el tablero {size} A pasa por todas las casillas y acaba dentro de la cárcel`, function()
			local routes, route = routesOf()
			local carA = routes.A
			expect(#carA).toBe(#route + 1)
			expect(carA[1].along).toBe(ArrestRules.CARS.A.spot.along)
			expect(carA[1].side).toBe(ArrestRules.CARS.A.spot.side)
			expect(carA[#carA].along).toBe(0)
			expect(carA[#carA].side).toBe(ArrestRules.JAIL_INSIDE_SIDE)
		end)

		it(`en el tablero {size} A entra recta por el portón, por la calle de llegada`, function()
			local routes = routesOf()
			local length = ArrestRules.routeLength(routes.A)
			local point = ArrestRules.pointOn(routes.A, length - ArrestRules.GATE_STUDS.A)
			expect(math.abs(point.along) < 1e-3).toBe(true)
			expect(math.abs(point.side - 70) < 1e-3).toBe(true)
		end)

		it(`en el tablero {size} B no entra en la cárcel y se aparta junto a la casilla`, function()
			local routes = routesOf()
			local last = routes.B[#routes.B]
			expect(last.along).toBe(-10)
			expect(last.side).toBe(6)
			for _, point in routes.B do
				expect(point.side >= -8 - EPS or math.abs(point.along) > HALF_STREET).toBe(true)
			end
		end)

		it(`en el tablero {size} las dos patrullas nunca se pisan durante la marcha`, function()
			local routes = routesOf()
			local windows = ArrestRules.windows(15)
			local lengthA = ArrestRules.routeLength(routes.A)
			local lengthB = ArrestRules.routeLength(routes.B)
			local minGap = math.huge
			local t = windows.depart.from
			while t <= 15 do
				local a = ArrestRules.pointOn(
					routes.A,
					ArrestRules.travelDistance(windows, t, lengthA, ArrestRules.GATE_STUDS.A)
				)
				local b = ArrestRules.pointOn(
					routes.B,
					ArrestRules.travelDistance(windows, t, lengthB, ArrestRules.GATE_STUDS.B)
				)
				minGap = math.min(minGap, distanceLocal(a, b))
				t += 0.02
			end
			expect(minGap > MIN_GAP_STUDS).toBe(true)
		end)

		it(`en el tablero {size} el recorrido avanza siempre y termina en su sitio`, function()
			local routes = routesOf()
			local windows = ArrestRules.windows(15)
			local length = ArrestRules.routeLength(routes.A)
			local previous = -1
			local t = windows.depart.from
			while t <= 15 do
				local distance = ArrestRules.travelDistance(windows, t, length, ArrestRules.GATE_STUDS.A)
				expect(distance >= previous).toBe(true)
				previous = distance
				t += 0.05
			end
			expect(
				math.abs(ArrestRules.travelDistance(windows, 15, length, ArrestRules.GATE_STUDS.A) - length)
					< EPS
			).toBe(true)
		end)
	end

	it("la vuelta dura como mucho 4 segundos, y la escena llega a los 15", function()
		local duration = Scenes.durationFor({ type = "PlayerArrested" } :: any, 0)
		expect(duration).toBe(15)
		local windows = ArrestRules.windows(duration)
		expect(windows.lap.to - windows.lap.from <= 4).toBe(true)
	end)

	it("los policías, la llegada y la subida duran más que antes de la vuelta", function()
		local windows = ArrestRules.windows(15)
		expect(windows.sirens.to - windows.sirens.from >= 3).toBe(true)
		expect(windows.board.to - windows.board.from >= 4).toBe(true)
	end)

	it("la llegada: entra lanzada, clava los frenos y acaba cruzada en su sitio", function()
		local start, startHeading, startPitch = ArrestRules.arrivalPose("A", 0)
		expect(start.side).toBe(ArrestRules.CARS.A.arrival.side)
		expect(startHeading.side).toBe(-1)
		expect(startPitch).toBe(0)
		local midway = ArrestRules.arrivalPose("A", 0.375)
		-- A la mitad del tiempo ya ha hecho mucho más de la mitad del camino: frena al final.
		local total = ArrestRules.CARS.A.arrival.side - ArrestRules.CARS.A.spot.side
		expect(ArrestRules.CARS.A.arrival.side - midway.side > total * 0.75).toBe(true)
		local spot, heading, pitch, skidding = ArrestRules.arrivalPose("A", 1)
		expect(spot.side).toBe(ArrestRules.CARS.A.spot.side)
		expect(math.abs(heading.along - ArrestRules.CARS.A.parked.along) < 1e-3).toBe(true)
		expect(math.abs(pitch) < 1e-6).toBe(true)
		expect(skidding).toBe(false)
	end)

	it("la patrulla B llega después que la A", function()
		local b = ArrestRules.arrivalPose("B", 0.2)
		expect(b.side).toBe(ArrestRules.CARS.B.arrival.side)
		local a = ArrestRules.arrivalPose("A", 0.2)
		expect(a.side < ArrestRules.CARS.A.arrival.side).toBe(true)
	end)

	it("pointOn da el inicio, un punto a mitad de tramo y se queda en el final", function()
		local route = { { along = 0, side = 0 }, { along = 10, side = 0 }, { along = 10, side = 10 } }
		local start = ArrestRules.pointOn(route, 0)
		expect(start.along).toBe(0)
		local middle, heading = ArrestRules.pointOn(route, 4)
		expect(middle.along).toBe(4)
		expect(middle.side).toBe(0)
		expect(heading.along).toBe(1)
		local _, _, done = ArrestRules.pointOn(route, 999)
		expect(done).toBe(true)
		local corner, cornerHeading = ArrestRules.pointOn(route, 14)
		expect(corner.along).toBe(10)
		expect(corner.side).toBe(4)
		expect(cornerHeading.side).toBe(1)
	end)

	it("un recorrido vacío o de un punto no se mueve ni rompe", function()
		local point, _, done = ArrestRules.pointOn({}, 5)
		expect(point.along).toBe(0)
		expect(done).toBe(true)
		local single, _, singleDone = ArrestRules.pointOn({ { along = 3, side = 4 } }, 5)
		expect(single.side).toBe(4)
		expect(singleDone).toBe(true)
	end)
end)

describe("ArrestRules.turnToward: giro suave de los rumbos", function()
	it("con un giro suficiente llega al objetivo", function()
		local turned = ArrestRules.turnToward({ along = 1, side = 0 }, { along = 0, side = 1 }, 10)
		expect(math.abs(turned.along) < EPS).toBe(true)
		expect(math.abs(turned.side - 1) < EPS).toBe(true)
	end)

	it("no gira más de maxRadians por el camino corto", function()
		local maxRadians = 0.1
		local turned = ArrestRules.turnToward({ along = 1, side = 0 }, { along = 0, side = 1 }, maxRadians)
		local angle = math.acos(math.clamp(turned.along, -1, 1))
		expect(math.abs(angle - maxRadians) < EPS).toBe(true)
		expect(turned.side > 0).toBe(true)
	end)

	it("toma el camino corto cuando el objetivo está al otro lado", function()
		-- De (1,0) a (0,-1) el camino corto es -90 grados, no +270.
		local turned = ArrestRules.turnToward({ along = 1, side = 0 }, { along = 0, side = -1 }, 0.1)
		expect(turned.side < 0).toBe(true)
	end)

	it("devuelve siempre un vector unitario", function()
		local turned = ArrestRules.turnToward({ along = 0.6, side = 0.8 }, { along = -1, side = 0 }, 0.37)
		expect(math.abs(math.sqrt(turned.along ^ 2 + turned.side ^ 2) - 1) < EPS).toBe(true)
	end)

	it("tolera vectores nulos: si el actual o el objetivo son casi nulos, devuelve el objetivo", function()
		local target = { along = 0, side = 1 }
		local fromZero = ArrestRules.turnToward({ along = 0, side = 0 }, target, 1)
		expect(fromZero.along).toBe(0)
		expect(fromZero.side).toBe(1)
		local toZero = ArrestRules.turnToward({ along = 1, side = 0 }, { along = 0, side = 0 }, 1)
		expect(toZero.along).toBe(0)
		expect(toZero.side).toBe(0)
	end)
end)

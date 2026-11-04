--!strict
-- Pruebas de las reglas de cámara. Son puras: reciben el contexto y deciden el plano, sin tocar la
-- cámara ni el avatar. Cubren la tabla «Qué ve cada jugador» de la ficha: todo el grupo ve el mismo plano
-- (R-P51), con la prioridad de la escena, el tope del recorrido y la cámara por el interior del anillo.
local Harness = require("../harness")
local CameraRules = require("../../src/client/camera/CameraRules")
local CameraShots = require("../../src/shared/config/CameraShots")
local CityLayout = require("../../src/shared/config/CityLayout")
local Economy = require("../../src/shared/config/Economy")
local Scenes = require("../../src/shared/config/Scenes")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

-- Ayuda: el contexto de cámara con los tres indicadores. Cualquiera que no se pase queda en falso.
local function ctx(overrides: { [string]: boolean }?)
	local context = { riding = false, sceneRunning = false, overviewRequested = false }
	local source: { [string]: boolean } = overrides or {}
	for key, value in source do
		context[key] = value
	end
	return context
end

describe("CameraRules.modeFor", function()
	it("la escena manda sobre la vista general", function()
		expect(CameraRules.modeFor(ctx({ sceneRunning = true, overviewRequested = true }))).toBe("Scene")
	end)

	it("el recorrido de una ficha es una escena con su propio plano", function()
		expect(CameraRules.modeFor(ctx({ sceneRunning = true, riding = true }))).toBe("Ride")
		expect(CameraRules.modeFor(ctx({ sceneRunning = true, riding = true, overviewRequested = true }))).toBe(
			"Ride"
		)
	end)

	it("un recorrido suelto, sin escena en marcha, no fija el plano cerrado", function()
		expect(CameraRules.modeFor(ctx({ riding = true }))).toBe("Turn")
	end)

	it("la vista general manda fuera de una escena", function()
		expect(CameraRules.modeFor(ctx({ overviewRequested = true }))).toBe("Overview")
	end)

	it("todo el grupo ve el mismo plano del turno: no hay primera persona", function()
		expect(CameraRules.modeFor(ctx({}))).toBe("Turn")
		expect(CameraRules.modeFor({} :: any)).toBe("Turn")
	end)
end)

describe("CameraRules.pose", function()
	local function distance(a: any, b: any): number
		return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
	end
	local function flat(a: any, b: any): number
		return math.max(math.abs(a.x - b.x), math.abs(a.z - b.z))
	end

	for _, size in { "S", "M", "L" } do
		it(`en el tablero {size} la cámara siempre va por el interior y mira las fachadas`, function()
			local center = CityLayout.centerFor(size :: any)
			for _, slot in CityLayout.routeFor(size :: any) do
				local eye = CameraRules.pose(CameraShots.turn, slot.position, slot.facing)
				-- Las esquinas se doblan: se mide solo a lo largo del lado donde va la casilla.
				local edge = flat(slot.position, center)
				local towards = (eye.x - slot.position.x) * (center.x - slot.position.x)
					+ (eye.z - slot.position.z) * (center.z - slot.position.z)
				expect(edge > 0).toBe(true)
				expect(towards > 0).toBe(true)
			end
		end)
	end

	it("el plano del turno ve por encima del edificio más alto", function()
		local slot = CityLayout.routeFor("S")[5]
		local eye = CameraRules.pose(CameraShots.turn, slot.position, slot.facing)
		local tallest = 0
		for _, block in CityLayout.buildingBlocks(Economy.maxBuildingLevel) do
			tallest = math.max(tallest, block.y + block.height)
		end
		expect(eye.y > tallest).toBe(true)
	end)

	it("el plano del recorrido está más cerca de la ficha que el del turno", function()
		local slot = CityLayout.routeFor("S")[5]
		local ride = CameraRules.pose(CameraShots.ride, slot.position, slot.facing)
		local turn = CameraRules.pose(CameraShots.turn, slot.position, slot.facing)
		expect(distance(ride, slot.position) < distance(turn, slot.position)).toBe(true)
	end)

	it("mira hacia delante, a las casillas que vienen", function()
		local slot = CityLayout.routeFor("S")[5]
		local _, focus = CameraRules.pose(CameraShots.turn, slot.position, slot.facing)
		local forward = (focus.x - slot.position.x) * math.sin(slot.facing)
			+ (focus.z - slot.position.z) * math.cos(slot.facing)
		expect(forward > 0).toBe(true)
	end)
end)

describe("CameraRules: recorrido", function()
	it("un recorrido nunca pasa de cuatro segundos", function()
		expect(CameraRules.rideSeconds(30)).toBe(4)
		expect(CameraRules.rideSeconds(3)).toBe(3)
	end)

	it("el tope vive en config y es el de la ficha", function()
		expect(Scenes.maxRideSec).toBe(4)
		expect(CameraRules.rideSeconds(99)).toBe(Scenes.maxRideSec)
	end)

	it("un recorrido absurdo o negativo se queda en el mínimo utilizable", function()
		expect(CameraRules.rideSeconds(0)).toBe(CameraRules.MIN_RIDE_SEC)
		expect(CameraRules.rideSeconds(-5)).toBe(CameraRules.MIN_RIDE_SEC)
	end)

	it("la duración pedida manda cuando cabe en el tope", function()
		expect(CameraRules.rideSeconds(1.5)).toBe(1.5)
	end)
end)

describe("CameraRules: altura del avatar", function()
	it("cuanto más alto el avatar, más alta la cámara", function()
		-- Con un avatar mínimo o máximo la cámara queda por encima del asiento; nunca dentro de la
		-- ficha ni por debajo del suelo.
		expect(CameraRules.seatOffset(10) > CameraRules.seatOffset(3)).toBe(true)
		expect(CameraRules.seatOffset(3) > CameraRules.seatOffset(0.5)).toBe(true)
	end)

	it("con un avatar muy bajo la cámara no se mete en la ficha", function()
		expect(CameraRules.seatOffset(0.5) >= CameraRules.MIN_SEAT_OFFSET).toBe(true)
	end)

	it("una altura imposible no da un desplazamiento negativo", function()
		expect(CameraRules.seatOffset(-3)).toBe(CameraRules.MIN_SEAT_OFFSET)
	end)
end)

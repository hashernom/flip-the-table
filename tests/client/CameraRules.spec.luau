--!strict
-- Pruebas de las reglas de cámara. Son puras: reciben el contexto y deciden el modo, sin tocar la
-- cámara ni el avatar. Cubren la tabla «Qué ve cada jugador» de la ficha y los dos criterios de la
-- tarea que se pueden comprobar sin Studio: la prioridad de la escena y el tope del recorrido.
local Harness = require("../harness")
local CameraRules = require("../../src/client/camera/CameraRules")
local Scenes = require("../../src/shared/config/Scenes")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

-- Ayuda: el contexto de cámara con los tres indicadores. Cualquiera que no se pase queda en falso.
local function ctx(overrides: { [string]: boolean }?)
	local context = { isActive = false, sceneRunning = false, overviewRequested = false }
	local source: { [string]: boolean } = overrides or {}
	for key, value in source do
		context[key] = value
	end
	return context
end

describe("CameraRules.modeFor", function()
	it("la escena manda sobre la vista general", function()
		expect(CameraRules.modeFor({ isActive = false, sceneRunning = true, overviewRequested = true })).toBe(
			"Scene"
		)
	end)

	it("el activo va en primera persona", function()
		expect(CameraRules.modeFor({ isActive = true, sceneRunning = false, overviewRequested = false })).toBe(
			"FirstPerson"
		)
	end)

	it("los demás siguen a la ficha activa", function()
		expect(CameraRules.modeFor({ isActive = false, sceneRunning = false, overviewRequested = false })).toBe(
			"FollowActive"
		)
	end)

	it("la escena manda también sobre la primera persona", function()
		expect(CameraRules.modeFor(ctx({ isActive = true, sceneRunning = true }))).toBe("Scene")
	end)

	it("la vista general manda fuera de una escena, también para el activo", function()
		expect(CameraRules.modeFor(ctx({ overviewRequested = true }))).toBe("Overview")
		expect(CameraRules.modeFor(ctx({ isActive = true, overviewRequested = true }))).toBe("Overview")
	end)

	it("un contexto vacío no rompe: se sigue a la ficha activa", function()
		expect(CameraRules.modeFor({} :: any)).toBe("FollowActive")
	end)

	it("los valores ausentes cuentan como falsos", function()
		expect(CameraRules.modeFor({ sceneRunning = nil, isActive = true } :: any)).toBe("FirstPerson")
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

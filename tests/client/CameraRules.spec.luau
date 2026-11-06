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
		it(
			`en el tablero {size} la cámara va por el lado contrario a los edificios y mira las fachadas`,
			function()
				local center = CityLayout.centerFor(size :: any)
				for _, slot in CityLayout.routeFor(size :: any) do
					local eye = CameraRules.pose(CameraShots.turn, slot.position, slot.facing)
					-- Las esquinas se doblan: se mide solo a lo largo del lado donde va la casilla.
					local edge = flat(slot.position, center)
					local towards = (eye.x - slot.position.x) * (center.x - slot.position.x)
						+ (eye.z - slot.position.z) * (center.z - slot.position.z)
					expect(edge > 0).toBe(true)
					-- Con los solares dentro (`LOT_SIDE` = -1) la cámara va por fuera del anillo.
					expect(towards * CityLayout.LOT_SIDE > 0).toBe(true)
				end
			end
		)
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

describe("CameraRules: suavizado", function()
	it("no depende de los fotogramas: dos pasos cortos equivalen a uno largo", function()
		local one = CameraRules.followAlpha(CameraShots.followRate, 1 / 30)
		local half = CameraRules.followAlpha(CameraShots.followRate, 1 / 60)
		local two = 1 - (1 - half) * (1 - half)
		expect(math.abs(one - two) < 1e-9).toBe(true)
	end)

	it("un fotograma largo acerca más que uno corto, sin pasarse", function()
		local short = CameraRules.followAlpha(CameraShots.followRate, 1 / 120)
		local long = CameraRules.followAlpha(CameraShots.followRate, 1 / 15)
		expect(long > short).toBe(true)
		expect(CameraRules.followAlpha(CameraShots.followRate, 1000) <= 1).toBe(true)
	end)

	it("un tiempo roto no mueve la cámara", function()
		expect(CameraRules.followAlpha(CameraShots.followRate, 0)).toBe(0)
		expect(CameraRules.followAlpha(CameraShots.followRate, -1)).toBe(0)
		expect(CameraRules.followAlpha(CameraShots.followRate, 0 / 0)).toBe(0)
	end)
end)

describe("CameraRules: vista general", function()
	-- Fracciones de pantalla de un punto: 0,5 es el centro. FOV vertical 70 y la pantalla más estrecha de PC.
	local function project(eye: any, focus: any, point: any): (number, number)
		local function sub(a: any, b: any)
			return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
		end
		local function dot(a: any, b: any)
			return a.x * b.x + a.y * b.y + a.z * b.z
		end
		local function norm(a: any)
			local l = math.sqrt(dot(a, a))
			return { x = a.x / l, y = a.y / l, z = a.z / l }
		end
		local function cross(a: any, b: any)
			return { x = a.y * b.z - a.z * b.y, y = a.z * b.x - a.x * b.z, z = a.x * b.y - a.y * b.x }
		end
		local forward = norm(sub(focus, eye))
		local right = norm(cross(forward, { x = 0, y = 1, z = 0 }))
		local up = cross(right, forward)
		local d = sub(point, eye)
		local depth = dot(d, forward)
		local half = math.tan(math.rad(35))
		return dot(d, right) / (depth * half * 4 / 3), dot(d, up) / (depth * half)
	end

	it("toda la ciudad cabe en pantalla, en cualquier tamaño y en los cuatro giros rectos", function()
		-- Más cerca a petición del responsable (2026-11-06): de frente cabe entera; girada en diagonal
		-- pueden quedar fuera las puntas de las esquinas, y basta con arrastrar para verlas.
		for _, sizeId in { "S", "M", "L" } do
			local span = CityLayout.spanFor(sizeId :: any)
			local center = CityLayout.centerFor(sizeId :: any)
			for _, yaw in { 0, math.pi / 2, math.pi, 3 * math.pi / 2 } do
				local eye, focus = CameraRules.overviewPose(center, span, yaw)
				for _, corner in { { 0, 0 }, { span, 0 }, { 0, span }, { span, span } } do
					local x, y = project(eye, focus, { x = corner[1], y = 0, z = corner[2] })
					expect(math.abs(x) < 1 and math.abs(y) < 1).toBe(true)
				end
			end
		end
	end)

	it("arrastrar gira la vista y no arrastrar no la mueve", function()
		expect(CameraRules.overviewYaw(1, 0)).toBe(1)
		expect(CameraRules.overviewYaw(1, 100) ~= 1).toBe(true)
		expect(CameraRules.overviewYaw(1, 0 / 0)).toBe(1)
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

describe("CameraRules: gestionar propiedades", function()
	it("gestionar manda sobre la vista general y el turno, pero nunca sobre una escena", function()
		expect(CameraRules.modeFor({ managing = true })).toBe("Manage")
		expect(CameraRules.modeFor({ managing = true, overviewRequested = true })).toBe("Manage")
		expect(CameraRules.modeFor({ managing = true, sceneRunning = true })).toBe("Scene")
	end)

	it("el primer plano mira la fachada desde la calle, por encima del solar", function()
		-- Solar en el origen mirando a +Z (la calle queda hacia +Z).
		local eye, focus = CameraRules.managePose({ x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 1 })
		expect(eye.z > 0).toBe(true)
		expect(eye.y > focus.y).toBe(true)
		expect(math.abs(eye.x) < 1e-6).toBe(true)
		expect(focus.z).toBe(0)
	end)
end)

describe("CameraRules.isBackward", function()
	it("avanzar a la casilla siguiente no es retroceder", function()
		expect(CameraRules.isBackward(4, { 5, 6, 7 })).toBe(false)
	end)

	it("dar la vuelta por la Salida no es retroceder", function()
		expect(CameraRules.isBackward(40, { 1, 2 })).toBe(false)
	end)

	it("el perdedor de un Duelo retrocede", function()
		expect(CameraRules.isBackward(7, { 6, 5, 4 })).toBe(true)
	end)

	it("retroceder desde la Salida da la vuelta hacia atrás", function()
		expect(CameraRules.isBackward(1, { 40, 39 })).toBe(true)
	end)

	it("sin ruta no hay retroceso", function()
		expect(CameraRules.isBackward(3, {})).toBe(false)
	end)
end)

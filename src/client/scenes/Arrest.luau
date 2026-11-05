--!strict
-- Escena de la detención (PlayerArrested). El detenido se baja de su ficha, que queda oculta; llegan dos patrullas
-- lanzadas, frenan cruzadas y bajan dos policías que lo sujetan y lo llevan a la patrulla A. Las patrullas dan la
-- vuelta entera al mapa con una cámara de seguimiento y A entra en la cárcel. Entonces reaparecen la ficha y el
-- detenido en su sitio, se borra todo y sigue la partida: la escena entera es bloqueante.
--
-- El tiempo y las posiciones son de `ArrestRules`, que es puro. Aquí solo se crean las mallas y se mueven. Si la
-- ficha del detenido recibe otro movimiento, o llega un resync, una ciudad nueva o el fin de partida, `cancelFor`
-- o `cancelAll` la cortan y `finish` devuelve la ficha y el avatar al instante.
--
-- No hay sonido: las sirenas son solo el parpadeo y la luz de sus mallas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArrestRules = require("./ArrestRules")
local ArtAssets = require("../../shared/config/ArtAssets")
local CameraShots = require("../../shared/config/CameraShots")
local CityLayout = require("../../shared/config/CityLayout")
local Robloxian = require("../world/Robloxian")
local TokenRider = require("../world/TokenRider")
local Types = require("../../shared/rules/Types")
local CameraDirector = require("../camera/CameraDirector")
local CityBuilder = require("../world/CityBuilder")
local SceneDirector = require("./SceneDirector")

type Scene = SceneDirector.Scene
type Context = SceneDirector.Context
type Local = ArrestRules.Local
type Frame = ArrestRules.Frame
type Vec = ArrestRules.Vec
type Windows = { [string]: ArrestRules.Window }

export type Options = {
	director: CameraDirector.Director,
	-- La ciudad de este cliente y la ficha de cada jugador. `nil` mientras no existen.
	city: () -> CityBuilder.CityHandles?,
	token: (id: string) -> Model?,
	-- Color del asiento del detenido: viste al relleno cuando no hay avatar.
	colorOf: (id: string) -> Color3,
	log: (message: string) -> (),
}

export type Car = {
	key: string,
	parts: { BasePart },
	offsets: { CFrame },
	reds: { BasePart },
	blues: { BasePart },
	redLights: { PointLight },
	blueLights: { PointLight },
	smoke: Smoke?,
	route: { Local },
	length: number,
	gateStuds: number,
	arrived: boolean,
	position: Local,
	heading: Local,
}

export type Sequence = {
	playerId: string,
	frame: Frame,
	token: Model,
	props: Folder,
	director: CameraDirector.Director,
	routes: { [string]: { Local } },
	-- Jugador real del detenido, si lo hay. Se le devuelve su avatar al acabar aunque no se usara.
	player: Player?,
	-- true si el avatar del jugador está de pie sobre el ancla; false si el detenido es un relleno.
	standing: boolean,
	anchor: BasePart?,
	bot: Robloxian.Robloxian?,
	cars: { Car },
	officers: { Robloxian.Robloxian },
	focused: boolean,
	gateShot: boolean,
	carsSpawned: boolean,
	officersSpawned: boolean,
	walking: boolean,
	boarded: boolean,
	cancelled: boolean,
	finished: boolean,
	clock: number,
}

export type Arrest = {
	scene: Scene,
	-- Corta la escena de ese jugador, si la hay, y devuelve su ficha al instante.
	cancelFor: (id: string) -> (),
	-- Corta todas las escenas en marcha: resync, ciudad nueva o fin de partida.
	cancelAll: () -> (),
	-- ¿Ese jugador está detenido ahora mismo? `syncTokens` no debe tocar su ficha mientras tanto.
	holds: (id: string) -> boolean,
}

-- Uniforme de los policías: pantalón azul marino y camisa algo más clara.
local UNIFORM = Color3.fromRGB(27, 42, 74)
local SHIRT = Color3.fromRGB(58, 86, 140)
local SIREN_RED = Color3.fromRGB(255, 50, 50)
local SIREN_BLUE = Color3.fromRGB(50, 110, 255)
-- Luz de las sirenas, que da drama aun de día. No es arte: se ajusta a ojo.
local SIREN_RANGE = 22
local SIREN_BRIGHTNESS = 1.6
local EAST: Local = { along = 1, side = 0 }

local Arrest = {}

local function artFolder(): Instance?
	return ReplicatedStorage:FindFirstChild(ArtAssets.FOLDER)
end

-- ¿Están todas las mallas del grupo cargadas? Sin ellas la escena no monta nada y solo espera su tiempo.
local function hasAll(art: Instance, group: { ArtAssets.Piece }): boolean
	for _, piece in group do
		local source = art:FindFirstChild(piece.key)
		if source == nil or not source:IsA("BasePart") then
			return false
		end
	end
	return true
end

local function playerOf(id: string): Player?
	local userId = tonumber(id)
	if userId == nil then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

-- Ancla o punto del suelo de un punto local, mirando a `heading`. Sin dirección útil, mira al mundo.
local function groundCF(seq: Sequence, point: Local, heading: Local): CFrame
	local world: Vec = ArrestRules.toWorld(seq.frame, point)
	local dir: Vec = ArrestRules.directionOf(seq.frame, heading)
	local at = Vector3.new(world.x, 0, world.z)
	if dir.x * dir.x + dir.z * dir.z < 1e-8 then
		return CFrame.new(at)
	end
	return CFrame.lookAt(at, at + Vector3.new(dir.x, 0, dir.z))
end

-- Coloca una patrulla entera con su rumbo: cada pieza conserva su posición relativa al origen de la base. `pitch`
-- baja el morro al frenar.
local function placeCar(seq: Sequence, car: Car, point: Local, pitch: number?)
	car.position = point
	local origin = groundCF(seq, point, car.heading) * CFrame.Angles(-(pitch or 0), 0, 0)
	for index, part in car.parts do
		part.CFrame = origin * car.offsets[index]
	end
end

-- Mueve el detenido: el avatar sigue al ancla, y el relleno de un bot se posa directamente.
local function placeDetained(seq: Sequence, point: Local, heading: Local, swing: number?)
	local ground = groundCF(seq, point, heading)
	local anchor = seq.anchor
	if anchor ~= nil then
		anchor.CFrame = ground
	end
	local bot = seq.bot
	if bot ~= nil then
		bot.pose(ground * CFrame.new(0, Robloxian.TORSO_HEIGHT, 0), swing or 0)
	end
end

-- Parpadeo alterno de las sirenas: rojo y azul se turnan, en sus mallas y en su luz.
local function flash(seq: Sequence)
	local redOn = math.floor(seq.clock * ArrestRules.FLASH_HZ) % 2 == 0
	for _, car in seq.cars do
		if not car.arrived then
			for _, part in car.reds do
				part.Transparency = if redOn then 0 else 1
			end
			for _, part in car.blues do
				part.Transparency = if redOn then 1 else 0
			end
			for _, light in car.redLights do
				light.Enabled = redOn
			end
			for _, light in car.blueLights do
				light.Enabled = not redOn
			end
		end
	end
end

local function sirenLight(part: BasePart, color: Color3): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = SIREN_RANGE
	light.Brightness = SIREN_BRIGHTNESS
	light.Parent = part
	return light
end

local function makeCar(seq: Sequence, art: Instance, key: string): Car
	local route = seq.routes[key]
	local car: Car = {
		key = key,
		parts = {},
		offsets = {},
		reds = {},
		blues = {},
		redLights = {},
		blueLights = {},
		smoke = nil,
		route = route,
		length = ArrestRules.routeLength(route),
		gateStuds = ArrestRules.GATE_STUDS[key],
		arrived = false,
		position = ArrestRules.CARS[key].arrival,
		heading = { along = 0, side = -1 },
	}
	for _, piece in ArtAssets.patrol do
		local source = art:FindFirstChild(piece.key)
		if source ~= nil and source:IsA("BasePart") then
			local mesh = source:Clone()
			mesh.Anchored = true
			mesh.CanCollide = false
			mesh.CanTouch = false
			mesh.CanQuery = false
			mesh.Parent = seq.props
			table.insert(car.parts, mesh)
			table.insert(car.offsets, source.CFrame)
			if piece.key == "patrol_sirenred" then
				table.insert(car.reds, mesh)
				table.insert(car.redLights, sirenLight(mesh, SIREN_RED))
			elseif piece.key == "patrol_sirenblue" then
				table.insert(car.blues, mesh)
				table.insert(car.blueLights, sirenLight(mesh, SIREN_BLUE))
			end
		end
	end
	-- Humo de los neumáticos en el derrape.
	if #car.parts > 0 then
		local smoke = Instance.new("Smoke")
		smoke.Color = Color3.fromRGB(215, 215, 215)
		smoke.Opacity = 0.35
		smoke.Size = 6
		smoke.RiseVelocity = 2
		smoke.Enabled = false
		smoke.Parent = car.parts[1]
		car.smoke = smoke
	end
	return car
end

local function carNamed(seq: Sequence, key: string): Car?
	for _, car in seq.cars do
		if car.key == key then
			return car
		end
	end
	return nil
end

local function spawnOfficers(seq: Sequence, art: Instance)
	local caps: { BasePart } = {}
	for _, piece in ArtAssets.officerCap do
		local source = art:FindFirstChild(piece.key)
		if source ~= nil and source:IsA("BasePart") then
			table.insert(caps, source)
		end
	end
	for _ in ArrestRules.OFFICERS do
		table.insert(
			seq.officers,
			Robloxian.create(seq.props, { body = UNIFORM, shirt = SHIRT, cap = caps, police = true })
		)
	end
end

-- Los policías van hasta el detenido, lo sujetan con los brazos por delante y lo llevan a la puerta.
local function updateOfficers(seq: Sequence, progress: number, clock: number)
	for index, officer in seq.officers do
		local route = ArrestRules.OFFICERS[index]
		local here: Local, heading: Local, swing: number, reach: number
		if progress < ArrestRules.BOARD_ARRIVED then
			local eased = ArrestRules.ease(progress / ArrestRules.BOARD_ARRIVED)
			here = ArrestRules.lerp(route.start, route.flank, eased)
			heading =
				{ along = route.flank.along - route.start.along, side = route.flank.side - route.start.side }
			swing = math.sin(clock * 9) * 0.6
			reach = 0
		elseif progress < ArrestRules.BOARD_HELD then
			here = route.flank
			heading = { along = -1, side = 0 }
			swing = 0
			reach = 1
		else
			local eased = ArrestRules.ease((progress - ArrestRules.BOARD_HELD) / (1 - ArrestRules.BOARD_HELD))
			here = ArrestRules.lerp(route.flank, route.door, eased)
			heading =
				{ along = route.door.along - route.flank.along, side = route.door.side - route.flank.side }
			swing = math.sin(clock * 7) * 0.3
			reach = 0.7
		end
		officer.pose(groundCF(seq, here, heading) * CFrame.new(0, Robloxian.TORSO_HEIGHT, 0), swing, reach)
	end
end

-- Pone el detenido en su casilla, de pie. Con avatar, lo ancla y lo suelda; con relleno, lo posa.
local function setup(seq: Sequence, colorOf: Color3)
	TokenRider.hide(seq.token)
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CFrame = groundCF(seq, ArrestRules.DETAINED, EAST)
	anchor.Parent = seq.props

	local player = seq.player
	if player ~= nil and player.Character ~= nil then
		TokenRider.dismount(seq.token)
		if TokenRider.standOn(player, anchor) then
			seq.standing = true
			seq.anchor = anchor
			return
		end
	end
	anchor:Destroy()
	seq.bot = Robloxian.create(seq.props, { body = colorOf })
	placeDetained(seq, ArrestRules.DETAINED, EAST)
end

-- Dentro de la patrulla: policías y detenido desaparecen. El avatar se oculta solo para este cliente.
local function board(seq: Sequence)
	seq.boarded = true
	for _, officer in seq.officers do
		officer.destroy()
	end
	seq.officers = {}
	if seq.bot ~= nil then
		seq.bot.destroy()
		seq.bot = nil
	end
	if seq.standing and seq.player ~= nil then
		TokenRider.setAvatarHidden(seq.player, true)
	end
end

local function updateBoarding(seq: Sequence, t: number, windows: Windows)
	local progress = ArrestRules.progress(windows.board, t)
	updateOfficers(seq, progress, t)
	if progress < ArrestRules.BOARD_HELD then
		placeDetained(seq, ArrestRules.DETAINED, EAST)
	else
		if not seq.walking then
			seq.walking = true
			if seq.standing and seq.player ~= nil then
				TokenRider.setAvatarMotion(seq.player, "walk")
			end
		end
		local eased = ArrestRules.ease((progress - ArrestRules.BOARD_HELD) / (1 - ArrestRules.BOARD_HELD))
		local here = ArrestRules.lerp(ArrestRules.DETAINED, ArrestRules.DOOR, eased)
		local heading = {
			along = ArrestRules.DOOR.along - ArrestRules.DETAINED.along,
			side = ArrestRules.DOOR.side - ArrestRules.DETAINED.side,
		}
		placeDetained(seq, here, heading, math.sin(t * 7) * 0.3)
	end
	if progress >= 1 then
		board(seq)
	end
end

local function updateCar(seq: Sequence, car: Car, t: number, dt: number, windows: Windows)
	if car.arrived then
		return
	end
	if t < windows.depart.from then
		local point, heading, pitch, skidding =
			ArrestRules.arrivalPose(car.key, ArrestRules.progress(windows.sirens, t))
		car.heading = heading
		placeCar(seq, car, point, pitch)
		if car.smoke ~= nil then
			car.smoke.Enabled = skidding
		end
		return
	end
	if car.smoke ~= nil then
		car.smoke.Enabled = false
	end
	local distance = ArrestRules.travelDistance(windows, t, car.length, car.gateStuds)
	local point, heading, done = ArrestRules.pointOn(car.route, distance)
	car.heading = ArrestRules.turnToward(car.heading, heading, ArrestRules.TURN_RADIANS_PER_SEC * dt)
	placeCar(seq, car, point)
	if done then
		car.arrived = true
		if car.key == "A" then
			-- La patrulla con el detenido ha entrado por el portón: desaparece dentro de la cárcel.
			for _, part in car.parts do
				part:Destroy()
			end
			car.parts = {}
			car.reds = {}
			car.blues = {}
			car.redLights = {}
			car.blueLights = {}
			car.smoke = nil
		end
	end
end

-- Cámara: el plano de la esquina desde el principio, para ver la llegada; el seguimiento de A durante la vuelta; y
-- un corte de vuelta a la esquina para ver cómo entra en la cárcel.
local function updateCamera(seq: Sequence, t: number, windows: Windows)
	local world = ArrestRules.toWorld(seq.frame, ArrestRules.DETAINED)
	local corner = Vector3.new(world.x, 0, world.z)
	if not seq.focused then
		seq.focused = true
		seq.director.setSceneFocus(corner, CameraShots.arrest, seq.frame.facing)
	end
	if t >= windows.gate.from then
		if not seq.gateShot then
			seq.gateShot = true
			seq.director.setSceneFocus(corner, CameraShots.arrest, seq.frame.facing, true)
		end
	elseif t >= windows.lap.from then
		local carA = carNamed(seq, "A")
		if carA ~= nil then
			local at = ArrestRules.toWorld(seq.frame, carA.position)
			local dir = ArrestRules.directionOf(seq.frame, carA.heading)
			seq.director.setSceneFocus(
				Vector3.new(at.x, 0, at.z),
				CameraShots.arrestChase,
				math.atan2(dir.x, dir.z),
				true
			)
		end
	end
end

-- Un paso de la escena, en el instante `t`. `dt` son los segundos reales desde el paso anterior.
local function update(seq: Sequence, t: number, dt: number, windows: Windows, art: Instance)
	seq.clock = t

	if not seq.carsSpawned and t >= windows.sirens.from then
		seq.carsSpawned = true
		for _, key in { "A", "B" } do
			table.insert(seq.cars, makeCar(seq, art, key))
		end
	end
	for _, car in seq.cars do
		updateCar(seq, car, t, dt, windows)
	end

	if not seq.officersSpawned and t >= windows.board.from then
		seq.officersSpawned = true
		spawnOfficers(seq, art)
	end
	if seq.officersSpawned and not seq.boarded then
		updateBoarding(seq, t, windows)
	end
	if seq.boarded then
		local carA = carNamed(seq, "A")
		if carA ~= nil and not carA.arrived then
			placeDetained(seq, carA.position, carA.heading)
		end
	end

	updateCamera(seq, t, windows)
	flash(seq)
end

-- Fin de la escena: vuelve la ficha, el avatar y la cámara, y se borran las patrullas y los policías.
-- Puede llamarse varias veces y nunca lanza: cada paso va protegido.
local function finish(seq: Sequence, active: { [string]: Sequence })
	if seq.finished then
		return
	end
	seq.finished = true
	if active[seq.playerId] == seq then
		active[seq.playerId] = nil
	end
	if seq.focused then
		seq.focused = false
		pcall(function()
			seq.director.setSceneFocus(nil)
		end)
	end
	pcall(function()
		TokenRider.show(seq.token)
	end)
	local player = seq.player
	if player ~= nil then
		pcall(function()
			TokenRider.setAvatarHidden(player, false)
		end)
		pcall(function()
			TokenRider.mount(player, seq.token)
		end)
	end
	if seq.bot ~= nil then
		seq.bot.destroy()
		seq.bot = nil
	end
	for _, officer in seq.officers do
		officer.destroy()
	end
	seq.officers = {}
	for _, car in seq.cars do
		car.arrived = true
	end
	pcall(function()
		seq.props:Destroy()
	end)
end

function Arrest.new(options: Options): Arrest
	local active: { [string]: Sequence } = {}

	local function cancelFor(id: string)
		local seq = active[id]
		if seq ~= nil then
			seq.cancelled = true
			finish(seq, active)
		end
	end

	local function cancelAll()
		for _, seq in table.clone(active) do
			seq.cancelled = true
			finish(seq, active)
		end
	end

	local function run(ctx: Context, event: Types.Event)
		local id = (event :: any).playerId
		if type(id) ~= "string" then
			ctx.wait(ctx.duration)
			return
		end
		-- Una sola detención a la vez: dos juegos de patrullas en la misma esquina se pisarían.
		cancelAll()

		local handles = options.city()
		local token = options.token(id)
		local art = artFolder()
		local route = if handles ~= nil then CityLayout.routeFor(handles.sizeId) else nil
		local slot = if route ~= nil then ArrestRules.tribunalSlot(route) else nil
		-- Sin mallas de patrulla, o sin ciudad o casilla Tribunal, la escena solo espera su duración.
		if
			handles == nil
			or token == nil
			or route == nil
			or slot == nil
			or art == nil
			or not hasAll(art, ArtAssets.patrol)
		then
			ctx.wait(ctx.duration)
			return
		end

		local props = Instance.new("Folder")
		props.Name = "Arrest"
		props.Parent = handles.model
		local seq: Sequence = {
			playerId = id,
			frame = ArrestRules.frameOf(slot),
			token = token,
			props = props,
			director = options.director,
			routes = ArrestRules.routes(route, slot),
			player = playerOf(id),
			standing = false,
			anchor = nil,
			bot = nil,
			cars = {},
			officers = {},
			focused = false,
			gateShot = false,
			carsSpawned = false,
			officersSpawned = false,
			walking = false,
			boarded = false,
			cancelled = false,
			finished = false,
			clock = 0,
		}
		active[id] = seq

		local windows = ArrestRules.windows(ctx.duration)
		local ok, err = pcall(function()
			setup(seq, options.colorOf(id))
			local duration = ctx.duration
			local t = 0
			update(seq, 0, 0, windows, art)
			-- Tiempo real, a cada fotograma: la cámara sigue a un coche muy rápido y a 30 Hz daría tirones.
			while t < duration and not seq.cancelled do
				local dt = task.wait()
				if seq.cancelled then
					break
				end
				t += dt
				ctx.spent(dt)
				update(seq, math.min(t, duration), dt, windows, art)
			end
		end)
		if not ok then
			options.log(`Arrest: la escena de {id} falló: {tostring(err)}`)
		end
		finish(seq, active)
	end

	local function holds(id: string): boolean
		local seq = active[id]
		return seq ~= nil and not seq.finished
	end

	return {
		scene = { run = run },
		cancelFor = cancelFor,
		cancelAll = cancelAll,
		holds = holds,
	}
end

return Arrest

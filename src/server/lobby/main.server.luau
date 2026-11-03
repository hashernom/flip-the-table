--!strict
-- Único punto de cableado del lobby: crea los remotos, valida y limita lo que llega y lo reenvía a
-- PartyService y PublicQueue. Nada de lógica de party vive aquí. Es un Script y no un
-- ModuleScript porque debe ejecutarse una sola vez al arrancar el servidor. El lobby es otro lugar
-- de Roblox (R-P11): este archivo no requiere nada de src/server/match.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Places = require("../../shared/config/Places")
local Protocol = require("../../shared/net/Protocol")
local PartyService = require("./PartyService")
local PartyStore = require("./PartyStore")
local PublicQueue = require("./PublicQueue")
local Teleport = require("./Teleport")

local FOLDER_NAME = "FlipTheTableRemotes"

-- Mismo patrón que RemoteGateway: la carpeta y los RemoteEvent se crean si no existen, para que el
-- cliente del plan 05 los encuentre desde el primer arranque. Se repite aquí porque el lobby no
-- puede requerir módulos del lugar de partida.
local function remotesFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		if existing:IsA("Folder") then
			return existing :: Folder
		end
		error(`Lobby: {FOLDER_NAME} existe en ReplicatedStorage y no es una carpeta`, 2)
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

local function remote(name: string): RemoteEvent
	local parent = remotesFolder()
	local existing = parent:FindFirstChild(name)
	if existing then
		if existing:IsA("RemoteEvent") then
			return existing :: RemoteEvent
		end
		error(`Lobby: {FOLDER_NAME}.{name} existe y no es un RemoteEvent`, 2)
	end
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = parent
	return event
end

local notice = remote(Protocol.REMOTES.Notice)

-- Aviso al cliente: el plan 05/09 pinta el mensaje; aquí solo viaja el texto en español y un
-- motivo para agruparlo («Info», «Error» o «PartyCode»). Un jugador que ya se está yendo no puede
-- tumbar el aviso a los demás: FireClient va protegido.
local function notify(player: Player, message: string, kind: string?)
	pcall(function()
		notice:FireClient(player, { kind = kind or "Info", message = message })
	end)
end

-- Semilla de las partidas: entero dentro del estado de 31 bits de Rng. Nunca math.random.
local SEED_RANGE = 2 ^ 31 - 1
local random = Random.new()
local function nextSeed(): number
	return random:NextInteger(1, SEED_RANGE)
end

local function nowSeconds(): number
	-- Reloj sincronizado entre servidores: la caducidad de una party se compara en el servidor
	-- donde vive el anfitrión y en el que intenta entrar. `os.time` depende del reloj local.
	return Workspace:GetServerTimeNow()
end

local function nowClock(): number
	return os.clock()
end

-- En Studio no hay MemoryStore ni teletransporte utilizables: se usan los adaptadores locales y el
-- arranque contesta con un aviso claro en vez de fingir que el grupo viajó (R-P12).
local store = if RunService:IsStudio() then PartyStore.memory() else PartyStore.default()
local teleport = if RunService:IsStudio()
	then Teleport.unavailable("En Studio no se teletransporta: publica el juego y prueba con dos cuentas.")
	else Teleport.live(Places.matchId)

PartyService.configure({
	store = store,
	teleport = teleport,
	notify = notify,
	seed = nextSeed,
	now = nowSeconds,
	serverId = game.JobId,
})

PublicQueue.configure({
	teleport = teleport,
	notify = notify,
	seed = nextSeed,
	now = nowClock,
})

-- La puerta del lobby comparte el limitador de la partida: sus peticiones escriben en MemoryStore
-- y teletransportan, así que se frenan por jugador y segundo antes de validar.
local limiter = Protocol.newLimiter()

local function accept(player: Player, packet: any): { [string]: any }?
	if not limiter.allow(tostring(player.UserId), Workspace:GetServerTimeNow()) then
		return nil
	end
	local ok, valid = pcall(function(): boolean
		return (Protocol.validateLobby(packet))
	end)
	if not ok or valid ~= true then
		return nil
	end
	return packet
end

-- Un fallo inesperado de un servicio se avisa y no se propaga al manejador del remoto, igual que
-- hace RemoteGateway con las acciones de la partida.
local function forward(label: string, handler: () -> ())
	-- `pcall` tipa un solo valor de retorno cuando la función no devuelve nada; el molde de
	-- `tests/harness` evita esa inferencia para poder leer el motivo.
	local ok: boolean, err: any = (pcall :: any)(handler)
	if not ok then
		warn(`Lobby: {label} falló: {err}`)
	end
end

remote(Protocol.REMOTES.PartyCreate).OnServerEvent:Connect(function(player: Player, packet: any)
	if accept(player, packet) == nil then
		return
	end
	forward("crear party", function()
		PartyService.create(player)
	end)
end)

remote(Protocol.REMOTES.PartyJoin).OnServerEvent:Connect(function(player: Player, packet: any)
	local accepted = accept(player, packet)
	if accepted == nil then
		return
	end
	forward("entrar en party", function()
		PartyService.join(player, accepted.code)
	end)
end)

remote(Protocol.REMOTES.PartyStart).OnServerEvent:Connect(function(player: Player, packet: any)
	local accepted = accept(player, packet)
	if accepted == nil then
		return
	end
	forward("empezar party", function()
		PartyService.start(player, accepted.endMode)
	end)
end)

remote(Protocol.REMOTES.QueueJoin).OnServerEvent:Connect(function(player: Player, packet: any)
	if accept(player, packet) == nil then
		return
	end
	forward("entrar en la cola", function()
		PublicQueue.enqueue(player)
	end)
end)

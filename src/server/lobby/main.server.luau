--!strict
-- Único punto de cableado del lobby: crea los remotos, valida y limita lo que llega y lo reenvía a
-- PartyService y PublicQueue. Nada de lógica de party vive aquí. Es un Script y no un
-- ModuleScript porque debe ejecutarse una sola vez al arrancar el servidor. El lobby es otro lugar
-- de Roblox (R-P11): este archivo no requiere nada de src/server/match; la fábrica de remotos es
-- `src/server/Remotes`, compartida por los dos lugares.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Lobby = require("../../shared/config/Lobby")
local Places = require("../../shared/config/Places")
local Protocol = require("../../shared/net/Protocol")
local PartyService = require("./PartyService")
local PartyStore = require("./PartyStore")
local PublicQueue = require("./PublicQueue")
local Remotes = require("../Remotes")
local TableService = require("./TableService")
local Teleport = require("./Teleport")
local LobbyWorld = require("./LobbyWorld")

local notice = Remotes.remote(Protocol.REMOTES.Notice)

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
	else Teleport.live(Places.matchId, function(player: Player)
		notify(
			player,
			"No pudimos llevarte a la partida. Sigues en el lobby: crea o únete a otra party.",
			"Error"
		)
	end)

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

-- Lobby provisional: el parque con sus mesas. Sentarse junto a otros en una mesa es otra forma de entrar en
-- partida, además de la party y la cola.
task.spawn(function()
	local world = LobbyWorld.build()
	TableService.start(world, {
		teleport = teleport,
		notify = notify,
		seed = nextSeed,
		now = nowClock,
	})
end)

-- Las peticiones del lobby cuestan mucho más que una acción de la partida: crear un código son
-- varias lecturas y una escritura en MemoryStore, y empezar una party son varios teletransportes.
-- Se frenan con su propio ritmo (Lobby.requestsPerSecond), no con el de las acciones.
local limiter = Protocol.newLimiter(Lobby.requestsPerSecond)

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

Remotes.remote(Protocol.REMOTES.PartyCreate).OnServerEvent:Connect(function(player: Player, packet: any)
	if accept(player, packet) == nil then
		return
	end
	forward("crear party", function()
		PartyService.create(player)
	end)
end)

Remotes.remote(Protocol.REMOTES.PartyJoin).OnServerEvent:Connect(function(player: Player, packet: any)
	local accepted = accept(player, packet)
	if accepted == nil then
		return
	end
	forward("entrar en party", function()
		PartyService.join(player, accepted.code)
	end)
end)

Remotes.remote(Protocol.REMOTES.PartyStart).OnServerEvent:Connect(function(player: Player, packet: any)
	local accepted = accept(player, packet)
	if accepted == nil then
		return
	end
	forward("empezar party", function()
		PartyService.start(player, accepted.endMode, accepted.settings)
	end)
end)

Remotes.remote(Protocol.REMOTES.QueueJoin).OnServerEvent:Connect(function(player: Player, packet: any)
	if accept(player, packet) == nil then
		return
	end
	forward("entrar en la cola", function()
		PublicQueue.enqueue(player)
	end)
end)

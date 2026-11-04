--!strict
-- Único punto de cableado del lugar de partida: conecta la puerta de acciones con el servicio de
-- partida, arranca la presencia y empieza la partida con el grupo que llega por teletransporte
-- (R-P24, R-P30). Ninguna regla de juego vive aquí.
--
-- Un servidor reservado recibe a su grupo por teletransporte, así que al llegar el primer jugador
-- se leen sus datos de entrada (semilla, modo y código de party para el registro), se espera un
-- momento corto a que llegue el resto y se llama a MatchService.start. Sin datos de entrada —probar
-- directamente en Studio— arranca una partida en Rondas en cuanto hay 2 jugadores.
local Players = game:GetService("Players")

local Lobby = require("../shared/config/Lobby")
local Protocol = require("../shared/net/Protocol")
local Rng = require("../shared/rules/Rng")
local Scenes = require("../shared/config/Scenes")
local Types = require("../shared/rules/Types")
local MatchService = require("./match/MatchService")
local PresenceService = require("./match/PresenceService")
local RematchService = require("./match/RematchService")
local RemoteGateway = require("./match/RemoteGateway")
local Telemetry = require("./match/Telemetry")

type EndMode = Types.EndMode

-- Campos que el lobby deja en TeleportData (R-P30). `size` no lo pide el plan: es una ayuda para
-- arrancar en cuanto han llegado todos en vez de esperar de más. `code` solo existe en una party.
type JoinData = {
	seed: number,
	endMode: EndMode,
	code: string?,
	size: number?,
}

-- Rango del estado de Rng (31 bits): la semilla del motor no puede salir de ahí.
local SEED_RANGE = 2 ^ 31 - 1
local seedRng = Rng.new(math.floor(os.clock() * 1000))

-- Semilla de respaldo cuando no hay datos de entrada (probar directamente en Studio): sale del
-- reloj del servidor y la consume Rng, nunca math.random.
local function fallbackSeed(): number
	return Rng.int(seedRng, 1, SEED_RANGE)
end

-- Datos de entrada utilizables, o nil. Un dato roto se trata como si no hubiera: mejor una partida
-- en Rondas con semilla del reloj que un servidor que no arranca nunca.
local function readJoinData(player: Player): JoinData?
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or type(joinData) ~= "table" then
		return nil
	end
	local teleportData: any = joinData.TeleportData
	if type(teleportData) ~= "table" then
		return nil
	end
	local seed = teleportData.seed
	if type(seed) ~= "number" or seed ~= seed or seed == math.huge or seed == -math.huge then
		return nil
	end
	local endMode = teleportData.endMode
	if endMode ~= "Rounds" and endMode ~= "Endless" then
		return nil
	end
	local code = teleportData.code
	local size = teleportData.size
	if
		type(size) ~= "number"
		or size ~= size
		or size == math.huge
		or size == -math.huge
		or size % 1 ~= 0
		or size < Lobby.minPlayers
		or size > Lobby.maxPlayers
	then
		size = nil
	end
	return {
		seed = math.floor(seed),
		endMode = endMode :: EndMode,
		code = if type(code) == "string" then code else nil,
		size = size :: number?,
	}
end

local started = false
local starting = false
local deadline: number? = nil
local joinData: JoinData? = nil

-- Intenta arrancar la partida con los jugadores presentes. Espera a que llegue el grupo hasta
-- Scenes.joinSec, o antes si ya están los que anuncia `size`. Con menos de 2 no arranca: el grupo
-- de una partida es de 2 a 8 (State.create lo vuelve a validar).
local function tryStart()
	if started or starting then
		return
	end
	local current = MatchService.current()
	if current ~= nil and not current.finished then
		started = true
		return
	end
	local players = Players:GetPlayers()
	if #players < Lobby.minPlayers then
		return
	end
	local now = os.clock()
	if deadline == nil then
		deadline = now + Scenes.joinSec
	end
	local data = joinData
	local expected = if data ~= nil then data.size else nil
	local complete = expected ~= nil and #players >= expected
	if not complete and now < (deadline :: number) then
		return
	end

	local group: { Player } = {}
	for index = 1, math.min(#players, Lobby.maxPlayers) do
		group[index] = players[index]
	end
	if #group < Lobby.minPlayers then
		return
	end

	local seed = if data ~= nil then data.seed else fallbackSeed()
	local endMode: EndMode = if data ~= nil then data.endMode else "Rounds"
	-- `starting` cubre el hueco entre el aviso de PlayerAdded y el bucle de espera: MatchService
	-- no debe arrancar dos veces la misma partida.
	starting = true
	local ok, err = pcall(MatchService.start, group, seed, endMode)
	starting = false
	if not ok then
		warn(`Lugar de partida: no se pudo empezar la partida: {err}`)
		return
	end
	started = true
	local label = if data ~= nil and data.code ~= nil then `party {data.code}` else "cola pública o Studio"
	print(`Lugar de partida: {#group} jugadores, semilla {seed}, modo {endMode}, {label}`)
end

-- La puerta valida, limita y filtra; el servicio aplica la acción al motor. Se conecta una sola vez
-- por servidor: la revancha reutiliza esta conexión y solo cambia la partida vigente.
RemoteGateway.start(function(player, action)
	MatchService.submit(player, action)
end)

-- Emotes: no son una acción del motor y no pasan por la puerta de acciones. Se validan contra la lista
-- del protocolo, se limitan como cualquier paquete del cliente y se reenvían a todos, que es lo único
-- que hacen: enseñarlos.
local emoteRemote = RemoteGateway.remote(Protocol.REMOTES.Emote)
local emoteLimiter = Protocol.newLimiter()
emoteRemote.OnServerEvent:Connect(function(player: Player, emote: any)
	if not emoteLimiter.allow(tostring(player.UserId), game:GetService("Workspace"):GetServerTimeNow()) then
		return
	end
	if not Protocol.validateEmote(emote) then
		return
	end
	emoteRemote:FireAllClients(tostring(player.UserId), emote)
end)

-- La presencia registra PlayerAdded/PlayerRemoving y se engancha al arranque de cada partida;
-- debe estar enganchada antes de que la partida empiece para tener los asientos listos.
PresenceService.start()

-- La telemetría se engancha al arranque y al abandono antes de que exista la primera partida: cada
-- partida, también la abandonada, deja su resumen para los criterios de salida (Tarea 7).
Telemetry.start()

-- La revancha escucha su remoto de votos y vigila la partida para abrir la ventana cuando termina.
-- Va antes de que la partida arranque: si se conectara después, se perdería el primer final.
RematchService.start()

-- Los datos de entrada llegan con el primer jugador. Se guardan una sola vez: todos los del grupo
-- traen los mismos y mezclarlos no aporta nada.
Players.PlayerAdded:Connect(function(player: Player)
	if joinData == nil then
		joinData = readJoinData(player)
	end
	tryStart()
end)

-- Sin un PlayerAdded más (el grupo ya está dentro o llegó incompleto), el plazo de espera debe
-- vencer igual. El latido es el mismo que usa la partida para mirar su reloj.
task.spawn(function()
	while not started do
		task.wait(Scenes.heartbeatSec)
		tryStart()
	end
end)

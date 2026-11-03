--!strict
-- Cola pública: agrupa de 2 a 8 jugadores del mismo servidor del lobby y los lleva a una partida
-- en Rondas cuando hay 4 o, como muy tarde, a los 60 s con los que haya (R-P13). Las decisiones
-- viven en LobbyRules; el teletransporte entra por el adaptador inyectable (R-P12). La cola es de
-- este servidor: reunir jugadores de otros servidores necesitaría mensajería entre servidores, que
-- no forma parte de esta tarea.
local Players = game:GetService("Players")

local Lobby = require("../../shared/config/Lobby")
local Places = require("../../shared/config/Places")
local LobbyRules = require("./LobbyRules")
local Teleport = require("./Teleport")

export type Notify = (player: Player, message: string, kind: string?) -> ()

export type Adapters = {
	teleport: Teleport.Teleport,
	notify: Notify,
	seed: () -> number,
	-- Reloj monótono de este servidor (os.clock): la espera de la cola es local y no se compara
	-- entre servidores.
	now: () -> number,
}

local PublicQueue = {}

local adapters: Adapters? = nil
-- Orden de llegada a la cola, en userIds. La espera empieza con el primero.
local queue: { number } = {}
local queuedAt: number? = nil
-- Hilo que revisa la cola cuando toca; solo hay uno.
local tick: thread? = nil
-- Reserva en curso: evita dos teletransportes si dos jugadores entran a la vez.
local starting = false

local function current(): Adapters
	local config = adapters
	if config == nil then
		error("PublicQueue: falta configure antes de usarlo", 2)
	end
	return config :: Adapters
end

local function notify(player: Player, message: string, kind: string?)
	current().notify(player, message, kind)
end

local function notifyAll(players: { Player }, message: string, kind: string?)
	for _, player in players do
		notify(player, message, kind)
	end
end

-- Vacía la cola y detiene la revisión periódica. Se llama al arrancar la partida, al caducar el
-- intento y cuando no queda nadie.
local function clear()
	local thread = tick
	tick = nil
	queue = {}
	queuedAt = nil
	if thread ~= nil then
		pcall(task.cancel, thread)
	end
end

local function playersInQueue(): { Player }
	local players: { Player } = {}
	for _, userId in queue do
		local player = Players:GetPlayerByUserId(userId)
		if player ~= nil and player.Parent ~= nil then
			table.insert(players, player)
		end
	end
	return players
end

local schedule: () -> ()

-- Intenta arrancar la partida con toda la cola. Devuelve false si no se pudo (queda gente en la
-- cola y toca volver a revisar) y true si el grupo ya viaja o la cola se vació con aviso.
local function startMatch(): boolean
	local config = current()
	if starting or #queue == 0 then
		return false
	end
	local players = playersInQueue()
	if #players < Lobby.minPlayers then
		return false
	end
	if Places.matchId == Places.unpublished then
		local message = "El lugar de partida aún no está publicado."
		notifyAll(players, message, "Error")
		clear()
		return false
	end

	starting = true
	local data = LobbyRules.queueData(config.seed(), #players)
	local ok, failure = LobbyRules.retry(function(): (boolean, string?)
		return config.teleport.reserve(players, data)
	end, Lobby.teleportAttempts, task.wait)
	starting = false
	if not ok then
		local message = "No se pudo crear la partida pública. Vuelve a entrar en la cola."
		warn(`PublicQueue: al reservar el servidor público: {failure}`)
		notifyAll(players, message, "Error")
		clear()
		return false
	end
	clear()
	notifyAll(players, "La partida pública empieza. Os llevamos al servidor reservado.", "Info")
	return true
end

local function checkStart()
	local config = current()
	if starting or #queue == 0 then
		return
	end
	local since = queuedAt or config.now()
	if not LobbyRules.shouldStartQueue(#queue, config.now() - since) then
		schedule()
		return
	end
	if not startMatch() then
		-- La cola sigue viva (alguien se fue en el último momento): se vuelve a revisar.
		schedule()
	end
end

-- Revisión periódica mientras haya cola. Como mucho hay un hilo; al vaciarse o arrancar, clear lo
-- cancela.
schedule = function()
	if tick ~= nil or starting or #queue == 0 then
		return
	end
	tick = task.delay(Lobby.queueTickSec, function()
		tick = nil
		checkStart()
	end)
end

-- Entra en la cola. Si es el cuarto, la partida empieza en el acto; si no, se avisa de cuántos
-- hay y de cuánto se espera como máximo.
function PublicQueue.enqueue(player: Player): (boolean, string?)
	local config = current()
	local userId = player.UserId
	if starting then
		local message = "La cola está arrancando. Inténtalo en un momento."
		notify(player, message, "Info")
		return false, message
	end
	if table.find(queue, userId) ~= nil then
		notify(player, "Ya estás en la cola pública.", "Info")
		return true, nil
	end
	if #queue >= Lobby.maxPlayers then
		local message = `La cola está llena: caben {Lobby.maxPlayers} jugadores.`
		notify(player, message, "Error")
		return false, message
	end
	table.insert(queue, userId)
	if #queue == 1 then
		queuedAt = config.now()
	end
	notify(
		player,
		`Estás en la cola pública ({#queue}). La partida empieza con {Lobby.queueStartAt} jugadores o a los {Lobby.queueWaitSec} s.`,
		"Info"
	)
	checkStart()
	return true, nil
end

-- Sale de la cola quien cierre el juego. La espera no se reinicia: el grupo lleva esperando desde
-- que llegó el primero.
function PublicQueue.playerLeft(player: Player)
	if adapters == nil then
		return
	end
	local index = table.find(queue, player.UserId)
	if index == nil then
		return
	end
	table.remove(queue, index)
	if #queue == 0 then
		queuedAt = nil
	end
end

-- Arranca el servicio una sola vez por servidor y conecta las salidas.
function PublicQueue.configure(config: Adapters)
	if adapters ~= nil then
		return
	end
	adapters = config
	Players.PlayerRemoving:Connect(PublicQueue.playerLeft)
end

return PublicQueue

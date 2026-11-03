--!strict
-- Servicio de revancha: cuando la partida termina, abre una ventana de Scenes.rematchSec para que
-- el grupo decida si juega otra en el mismo servidor, sin teletransportar a nadie al empezar. Los
-- votos llegan por su propio remoto, con la identidad del Player y nunca de un id del paquete, y
-- pasan por el mismo limitador que las acciones. Las decisiones viven en RematchRules, que es puro;
-- aquí solo se aplican, se teletransporta a quien no sigue y se avisa en español. Una partida
-- abandonada no tiene revancha (R-P14, R-P21, R-P31).
local TeleportService = game:GetService("TeleportService")

local Lobby = require("../../shared/config/Lobby")
local MatchService = require("./MatchService")
local Places = require("../../shared/config/Places")
local Protocol = require("../../shared/net/Protocol")
local RematchRules = require("./RematchRules")
local RemoteGateway = require("./RemoteGateway")
local Scenes = require("../../shared/config/Scenes")

type Decision = RematchRules.Decision
type Match = MatchService.Match

-- Mensajes al jugador. El motivo de volver va delante y el servicio añade el destino.
local LEAVING = "La revancha empieza sin ti."
local NOT_ENOUGH = "Hacen falta al menos dos jugadores para la revancha."
local ABANDONED = "La partida se interrumpió y no hay revancha."
local START_FAILED = "No se pudo empezar la revancha."
local TO_LOBBY = "Vuelves al lobby."
-- Sin lugar publicado no se intenta el teletransporte (R-P31): el aviso lo dice y nadie se mueve.
local LOBBY_UNPUBLISHED = "El lobby todavía no está publicado, así que nadie vuelve al lobby."

local RematchService = {}

-- Suscriptores: el remoto se conecta una sola vez por servidor.
local started = false
-- Partida terminada cuya ventana de votos está abierta, o nil fuera de la ventana. Es la única
-- puerta por la que entra un voto: si no hay ventana, o el que vota no está sentado en ella, se
-- descarta en silencio.
local windowMatch: Match? = nil
-- Votos de la ventana abierta, por userId. Se estrena en cada ventana; ninguno viene del paquete.
local votes: { [number]: boolean } = {}

-- Rango del estado de Rng (31 bits): la semilla del motor no puede salir de ahí.
local SEED_RANGE = 2 ^ 31 - 1

-- Semilla de la revancha: el reloj del servidor en milisegundos, nunca la semilla anterior y nunca
-- math.random. Si dos revanchas cayeran en el mismo milisegundo, se desplaza una unidad para que la
-- partida nueva no repita la anterior.
local function nextSeed(previous: number): number
	local seed = (DateTime.now().UnixTimestampMillis % SEED_RANGE) + 1
	if seed == previous then
		seed = if seed == SEED_RANGE then 1 else seed + 1
	end
	return seed
end

-- Aviso al cliente por el canal de avisos compartido. El plan 05 pinta el texto; aquí solo viaja
-- el mensaje en español y su motivo. Un jugador que ya se está yendo no puede tumbar el aviso a los
-- demás: FireClient va protegido.
local function notify(player: Player, message: string, kind: string?)
	local ok: boolean, err: any = (pcall :: any)(function()
		RemoteGateway.remote(Protocol.REMOTES.Notice):FireClient(player, {
			kind = kind or "Info",
			message = message,
		})
	end)
	if not ok then
		warn(`RematchService: no se pudo avisar a {player.Name}: {err}`)
	end
end

-- Jugadores de la partida terminada que siguen conectados, por userId y en el orden de asientos
-- del motor. La identidad sale del Player (contracts.md, «Identidad»): aquí no se convierte ningún
-- PlayerId de texto. Un asiento cuyo dueño se fue conserva un Player viejo y no cuenta.
local function presentOf(match: Match): ({ number }, { [number]: Player })
	local present: { number } = {}
	local players: { [number]: Player } = {}
	for _, statePlayer in match.state.players do
		local player: Player? = match.players[statePlayer.id]
		if player ~= nil and player.Parent ~= nil then
			local userId = player.UserId
			table.insert(present, userId)
			players[userId] = player
		end
	end
	return present, players
end

-- Los Player de una lista de userId, en el mismo orden.
local function playersOf(present: { number }, players: { [number]: Player }): { Player }
	local list: { Player } = {}
	for _, userId in present do
		local player: Player? = players[userId]
		if player ~= nil then
			table.insert(list, player)
		end
	end
	return list
end

-- Devuelve al lobby a un jugador. Con Places.lobbyId == 0 el lugar todavía no existe (R-P31): no
-- se intenta el teletransporte y se contesta el motivo. El detalle técnico va a `warn`, no al
-- jugador.
local function teleportToLobby(player: Player): (boolean, string?)
	if Places.lobbyId == Places.unpublished then
		return false, "El lobby todavía no está publicado."
	end
	local ok: boolean, err: any = (pcall :: any)(function()
		TeleportService:TeleportAsync(Places.lobbyId, { player })
	end)
	if ok then
		return true, nil
	end
	warn(`RematchService: no se pudo devolver a {player.Name} al lobby: {err}`)
	return false, "No se pudo volver al lobby."
end

-- Avisa y devuelve al lobby. Sin lugar publicado se avisa y no se mueve a nadie: a 0 no se
-- teletransporta nunca (R-P31).
local function returnToLobby(players: { Player }, reason: string)
	if #players == 0 then
		return
	end
	if Places.lobbyId == Places.unpublished then
		for _, player in players do
			notify(player, `{reason} {LOBBY_UNPUBLISHED}`, "Info")
		end
		return
	end
	for _, player in players do
		notify(player, `{reason} {TO_LOBBY}`, "Info")
		local ok, failure = teleportToLobby(player)
		if not ok then
			notify(player, failure or "No se pudo volver al lobby.", "Error")
		end
	end
end

-- Cierra la ventana: quien no votó cuenta como que no acepta. Así el límite de tiempo usa la misma
-- regla que el resto y el mínimo de aceptaciones no se repite fuera de RematchRules.
local function cappedVotes(votesIn: { [number]: boolean }, present: { number }): { [number]: boolean }
	local capped = table.clone(votesIn)
	for _, userId in present do
		if capped[userId] == nil then
			capped[userId] = false
		end
	end
	return capped
end

-- Aplica la decisión de la regla. Con "Start" arranca la revancha en este mismo servidor (R-P21:
-- la partida terminada se puede sustituir) con quienes aceptaron, la semilla nueva y el mismo modo,
-- y manda al lobby a quien no aceptó. Si no llegan las aceptaciones —o la revancha no arranca—,
-- todos vuelven al lobby: nadie se queda en un servidor muerto.
local function applyDecision(match: Match, decision: Decision)
	local present, players = presentOf(match)
	local acceptedSet: { [number]: boolean } = {}
	local accepted: { Player } = {}
	for _, userId in RematchRules.accepted(votes, present) do
		acceptedSet[userId] = true
		local player: Player? = players[userId]
		if player ~= nil then
			table.insert(accepted, player)
		end
	end
	local leaving: { Player } = {}
	for _, userId in present do
		if acceptedSet[userId] == nil then
			local player: Player? = players[userId]
			if player ~= nil then
				table.insert(leaving, player)
			end
		end
	end

	if decision == "Start" and #accepted >= Lobby.minPlayers then
		local seed = nextSeed(match.seed)
		local ok: boolean, err: any = (pcall :: any)(MatchService.start, accepted, seed, match.state.endMode)
		if ok then
			print(
				`RematchService: revancha con {#accepted} jugadores, semilla {seed}, `
					.. `modo {match.state.endMode}`
			)
			returnToLobby(leaving, LEAVING)
			return
		end
		warn(`RematchService: no se pudo empezar la revancha: {err}`)
		returnToLobby(playersOf(present, players), START_FAILED)
		return
	end

	returnToLobby(playersOf(present, players), NOT_ENOUGH)
end

-- Abre la ventana de votos de una partida terminada y la resuelve cuando todos los presentes han
-- votado o al vencer Scenes.rematchSec. La ventana cuenta desde que acaba la escena final (que es
-- cuando el cliente puede enseñar el botón), con la holgura del latido si el servicio se retrasa.
local function runWindow(match: Match)
	votes = {}
	windowMatch = match
	local deadline = math.max(match.matchState.sceneEndsAt, time()) + Scenes.rematchSec
	while windowMatch == match do
		local present = presentOf(match)
		local decision: Decision = RematchRules.resolve(votes, present)
		if decision == "Wait" and time() >= deadline then
			decision = RematchRules.resolve(cappedVotes(votes, present), present)
		end
		if decision ~= "Wait" then
			windowMatch = nil
			applyDecision(match, decision)
			return
		end
		task.wait(Scenes.heartbeatSec)
	end
end

-- Mira la partida vigente hasta que termina. MatchService no avisa del final —puede llegar por una
-- jugada de bot, por el reloj o por un abandono—, así que se sondea con el mismo latido que usa la
-- partida. Una partida abandonada no abre ventana: quien siga conectado vuelve al lobby.
local function watch()
	local handled: Match? = nil
	while true do
		task.wait(Scenes.heartbeatSec)
		local match = MatchService.current()
		if match ~= nil and match ~= handled and match.finished then
			handled = match
			local ok: boolean, err: any = (pcall :: any)(function()
				if match.abandoned then
					local present, players = presentOf(match)
					returnToLobby(playersOf(present, players), ABANDONED)
				else
					runWindow(match)
				end
			end)
			if not ok then
				warn(`RematchService: la ventana de revancha falló: {err}`)
				windowMatch = nil
			end
		end
	end
end

-- Arranca el servicio una sola vez por servidor: crea los remotos, conecta los votos y lanza el
-- vigilante. Debe llamarse antes de que empiece la primera partida para no perderse un final.
function RematchService.start()
	if started then
		return
	end
	started = true
	-- El aviso se crea también en este lugar, con el mismo nombre que usa el lobby: el cliente lo
	-- busca desde el primer arranque y la revancha lo necesita para explicar por qué vuelve la gente.
	RemoteGateway.remote(Protocol.REMOTES.Notice)
	local limiter = Protocol.newLimiter()
	RemoteGateway.remote(Protocol.REMOTES.Rematch).OnServerEvent:Connect(function(player: Player, packet: any)
		-- El limitador va antes de validar, igual que en RemoteGateway: un cliente que inunda con
		-- paquetes malformados tampoco puede obligar a recorrer nada.
		if not limiter.allow(tostring(player.UserId), time()) then
			return
		end
		local ok: boolean, valid: any = (pcall :: any)(function(): boolean
			return (Protocol.validateRematch(packet))
		end)
		if not ok or valid ~= true then
			return
		end
		local match = windowMatch
		if match == nil then
			return
		end
		-- La identidad sale del Player del remoto y de ningún campo del paquete (R-P9).
		for _, seated in match.players do
			if seated == player and seated.Parent ~= nil then
				votes[player.UserId] = packet == true
				return
			end
		end
	end)
	task.spawn(watch)
end

return RematchService

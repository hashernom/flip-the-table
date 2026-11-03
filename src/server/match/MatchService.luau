--!strict
-- Servicio de partida: ejecuta el motor en el servidor, numera los lotes, programa las escenas,
-- mantiene el reloj de decisión y difunde lo que cada jugador puede ver. No espera a ningún
-- cliente: el latido del servidor cierra los tiempos agotados con su propio reloj (R-P20, R-P21,
-- R-P22). El arranque del servidor conecta la puerta con este servicio:
--
--     RemoteGateway.start(function(player, action)
--         MatchService.submit(player, action)
--     end)
--     MatchService.start(players, seed, "Rounds")
--
-- Una partida por servidor: start se niega si hay otra sin terminar y current() deja consultarla.
-- Una partida terminada sí se puede sustituir, que es como la revancha arranca otra.
local Engine = require("../../shared/rules/Engine")
local MatchState = require("./MatchState")
local Protocol = require("../../shared/net/Protocol")
local RemoteGateway = require("./RemoteGateway")
local Scenes = require("../../shared/config/Scenes")
local State = require("../../shared/rules/State")
local Types = require("../../shared/rules/Types")

type Action = Types.Action
type EndMode = Types.EndMode
type Event = Types.Event
type GameState = Types.GameState
type Phase = Types.Phase
type PlayerId = Types.PlayerId

export type Match = {
	state: GameState,
	seed: number,
	-- Player de Roblox de cada asiento, por PlayerId del motor. La identidad sale del Player,
	-- nunca de un id del paquete (contratos, «Identidad»).
	players: { [PlayerId]: Player },
	matchState: MatchState.MatchState,
	-- La partida ya no admite pasos (GameOver o abandono).
	finished: boolean,
	abandoned: boolean,
	abandonReason: string?,
	-- Acciones que pasaron el protocolo pero el motor rechazó (R-P22): se cuentan y se descartan.
	rejectedActions: number,
	-- Último seq difundido, para no repetir un lote en la puerta.
	lastSeq: number,
	heartbeat: thread?,
	abandonCallback: ((reason: string) -> ())?,
	submit: (self: Match, player: Player, action: Action) -> (),
	setBotControlled: (self: Match, playerId: PlayerId, controlled: boolean) -> boolean,
	abandon: (self: Match, reason: string) -> (),
	onAbandon: (self: Match, callback: (reason: string) -> ()) -> (),
}

local MatchService = {}

-- Tabla de métodos del objeto de partida. El tipo `Match` y esta tabla conviven en espacios de
-- nombres distintos de Luau: el tipo describe la forma y la tabla guarda las funciones.
local Match = {}

local current: Match? = nil

-- El PlayerId del motor es el userId en texto. La conversión vive en el borde: aquí y en
-- RemoteGateway, nunca en el motor ni en el cliente.
local function playerIdOf(player: Player): PlayerId
	return tostring(player.UserId)
end

-- Difunde un paso ya registrado: un lote por jugador, con el mismo seq y sus eventos filtrados.
-- No hace nada si el paso ya se difundió, para que el final no se anuncie dos veces.
local function broadcast(match: Match, step: MatchState.Step)
	if match.lastSeq == step.seq then
		return
	end
	match.lastSeq = step.seq
	local remote = RemoteGateway.remote(Protocol.REMOTES.Batch)
	for _, statePlayer in match.state.players do
		local player = match.players[statePlayer.id]
		if player then
			remote:FireClient(player, MatchState.batch(match.state, step, statePlayer.id))
		end
	end
end

-- Registra un paso aceptado del motor: numera, programa escenas, fija el plazo de decisión,
-- actualiza las observaciones y difunde. Si el motor cerró la partida, marca el final después de
-- difundir el último lote.
local function record(
	match: Match,
	events: { Event },
	phaseBefore: Phase,
	actionType: string?,
	fromClock: boolean,
	now: number
)
	-- Un partido cerrado no vuelve a difundir: ni el latido ni una acción tardía deben anunciar el
	-- final dos veces (el defecto de la subfase 02). MatchState.step repite la guarda por si acaso.
	if match.finished then
		return
	end
	local endedTurn = MatchState.endsTurn(actionType, phaseBefore, fromClock)
	local step = MatchState.step(match.matchState, match.state, events, now, endedTurn)
	if not step then
		return
	end
	broadcast(match, step)
	if match.state.phase == "GameOver" then
		match.finished = true
	end
end

-- Tiempo agotado: el reloj del servidor resuelve la fase. Un partido ya cerrado o en GameOver no
-- vuelve a disparar (el defecto de la subfase 02). Si el tic no emitió eventos ni movió fase,
-- ronda o turno, el reloj no puede avanzar: se abandona con un motivo claro en vez de rearmar el
-- mismo plazo y quemar `seq` con lotes vacíos.
local function fireTimeout(match: Match, now: number)
	if match.finished or match.state.phase == "GameOver" or MatchState.over(match.matchState) then
		match.finished = true
		return
	end
	local phaseBefore: Phase = match.state.phase
	local before = MatchState.snapshot(match.state)
	local events = Engine.timeout(match.state)
	if not MatchState.timeoutAdvanced(match.state, before, events) then
		local reason = `el reloj no pudo avanzar la fase {before.phase}`
		warn(`MatchService: {reason}`)
		match:abandon(reason)
		return
	end
	record(match, events, phaseBefore, nil, true, now)
end

-- Latido de la partida. Es el del servidor y no el de ningún cliente: cuando vence el plazo llama
-- a Engine.timeout y difunde el lote. Se detiene solo al terminar o abandonar la partida, así que
-- tres partidas seguidas no acumulan latidos. Un tic que falle no mata el hilo: se avisa una sola
-- vez por partida y se sigue esperando, para que un fallo puntual no deje el servidor sin reloj ni
-- sin poder alojar otra partida.
local function heartbeat(match: Match)
	local warned = false
	while not match.finished do
		local ok, err = pcall(function()
			local now = time()
			local deadline = match.matchState.decisionDeadline
			if now >= deadline then
				fireTimeout(match, now)
			else
				task.wait(math.min(Scenes.heartbeatSec, deadline - now))
			end
		end)
		if not ok then
			if not warned then
				warned = true
				warn(`MatchService: el latido falló; la partida sigue: {err}`)
			end
			task.wait(Scenes.heartbeatSec)
		end
	end
end

-- Vista inicial de cada jugador por el canal de lotes (R-P25): es un lote con `seq = 0`, «todavía
-- no hay lotes», no un lote nuevo. Va por EventBatch para que el cliente tenga un solo orden de
-- entrega; Resync queda para la petición y su respuesta.
local function sendInitial(match: Match, now: number)
	local remote = RemoteGateway.remote(Protocol.REMOTES.Batch)
	for _, statePlayer in match.state.players do
		local player = match.players[statePlayer.id]
		if player then
			local batch = MatchState.resync(match.matchState, match.state, statePlayer.id, now)
			remote:FireClient(player, batch)
		end
	end
end

-- El canal de resincronización se conecta una sola vez por servidor y busca la partida vigente;
-- así cambiar de partida no deja conexiones viejas escuchando. El limitador de la partida se
-- consulta antes de construir la vista: un cliente que reintenta no puede frenar el latido.
local resyncConnected = false
local function ensureResync()
	if resyncConnected then
		return
	end
	resyncConnected = true
	RemoteGateway.remote(Protocol.REMOTES.Resync).OnServerEvent:Connect(function(player: Player)
		local match = current
		if not match then
			return
		end
		local playerId = playerIdOf(player)
		if not MatchState.acceptsResync(match.matchState, match.state, playerId, time()) then
			return
		end
		local batch = MatchState.resync(match.matchState, match.state, playerId, time())
		RemoteGateway.remote(Protocol.REMOTES.Resync):FireClient(player, batch)
	end)
end

-- Acción de un jugador. Se aplica al motor; si la rechaza, se cuenta y no se difunde nada (R-P22).
-- El cliente que se haya quedado desfasado pide resincronización.
Match.submit = function(self: Match, player: Player, action: Action)
	if self.finished or MatchState.over(self.matchState) then
		return
	end
	local phaseBefore: Phase = self.state.phase
	local result = Engine.apply(self.state, playerIdOf(player), action)
	if not result.ok then
		self.rejectedActions += 1
		return
	end
	record(self, result.events, phaseBefore, action.type, false, time())
end

-- Control por bot (R-P6): el servicio de presencia decide y este es el único camino que escribe
-- state.players[i].isBot. Devuelve false si el jugador no está en la partida.
Match.setBotControlled = function(self: Match, playerId: PlayerId, controlled: boolean): boolean
	return MatchState.setBotControlled(self.matchState, self.state, playerId, controlled)
end

-- Abandono (R-P8): para el latido, fija endedAt y avisa al callback registrado. Es el único
-- camino que usará el servicio de presencia cuando no quede ningún humano.
Match.abandon = function(self: Match, reason: string)
	if self.abandoned then
		return
	end
	self.abandoned = true
	self.abandonReason = reason
	self.finished = true
	MatchState.abandon(self.matchState, time())
	local callback = self.abandonCallback
	if callback then
		local ok: boolean, err: any = pcall(callback, reason)
		if not ok then
			warn(`MatchService: el aviso de abandono falló: {err}`)
		end
	end
end

Match.onAbandon = function(self: Match, callback: (reason: string) -> ())
	self.abandonCallback = callback
end

local function newMatch(state: GameState, players: { [PlayerId]: Player }, seed: number, now: number): Match
	local match: Match = {
		state = state,
		seed = seed,
		players = players,
		matchState = MatchState.begin(now, state.phase),
		finished = false,
		abandoned = false,
		abandonReason = nil,
		rejectedActions = 0,
		lastSeq = 0,
		heartbeat = nil,
		abandonCallback = nil,
		submit = Match.submit,
		setBotControlled = Match.setBotControlled,
		abandon = Match.abandon,
		onAbandon = Match.onAbandon,
	}
	return match
end

-- Empieza una partida con los jugadores dados. Falla con un mensaje claro si ya hay otra en
-- curso; una terminada se puede sustituir (R-P21).
function MatchService.start(players: { Player }, seed: number, endMode: EndMode): Match
	if current and not current.finished then
		error("MatchService.start: ya hay una partida en curso; termínala o abandónala antes", 2)
	end
	local now = time()
	local playerIds: { PlayerId } = {}
	local byId: { [PlayerId]: Player } = {}
	for _, player in players do
		local playerId = playerIdOf(player)
		table.insert(playerIds, playerId)
		byId[playerId] = player
	end
	-- State.create valida de 2 a 8 jugadores, ids repetidos y el modo de partida.
	local state = State.create({ playerIds = playerIds, seed = seed, endMode = endMode })
	local match = newMatch(state, byId, seed, now)
	-- `current` se publica al final: si el arranque falla (remotos, vista inicial o latido), el
	-- servidor no queda con una partida actual a medias que bloquee la siguiente.
	ensureResync()
	sendInitial(match, now)
	match.heartbeat = task.spawn(function()
		heartbeat(match)
	end)
	current = match
	return match
end

-- La partida vigente del servidor, o nil si todavía no hay ninguna. Sigue devolviendo la última
-- cuando ya terminó, para que la revancha consulte su estado.
function MatchService.current(): Match?
	return current
end

-- Acción ya validada por RemoteGateway, que es quien conoce al Player. Si no hay partida, se
-- descarta en silencio.
function MatchService.submit(player: Player, action: Action)
	local match = current
	if not match then
		return
	end
	match:submit(player, action)
end

return MatchService

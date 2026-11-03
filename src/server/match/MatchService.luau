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
local Bot = require("../../shared/rules/Bot")
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
	-- nunca de un id del paquete (contratos, «Identidad»). Un asiento desconectado conserva su
	-- Player viejo como referencia hasta que vuelve: `present` lo descarta al enviar.
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
	-- Hilo del turno de bot programado para después de la escena (R-P27) y el `seq` del paso para
	-- el que se armó. Solo hay uno por partida; un paso nuevo lo rearma y se cancela al terminar,
	-- al abandonar o cuando ya no hay bot que jugar.
	botThread: thread?,
	botSeq: number?,
	-- Suscriptores avisados después de que el motor actúe (R-P28). Son listas para que la
	-- presencia y, en la Tarea 7, la telemetría se enganchen a la vez.
	timeoutCallbacks: { (playerId: PlayerId) -> () },
	actionCallbacks: { (playerId: PlayerId) -> () },
	abandonCallback: ((reason: string) -> ())?,
	submit: (self: Match, player: Player, action: Action) -> (),
	setBotControlled: (self: Match, playerId: PlayerId, controlled: boolean) -> boolean,
	abandon: (self: Match, reason: string) -> (),
	onAbandon: (self: Match, callback: (reason: string) -> ()) -> (),
	onTimeout: (self: Match, callback: (playerId: PlayerId) -> ()) -> (),
	onAction: (self: Match, callback: (playerId: PlayerId) -> ()) -> (),
	-- Vuelve a enganchar una conexión nueva al asiento de un jugador que regresó y le manda la
	-- vista actual, con la mano incluida. La presencia decide quién vuelve; este es el único
	-- camino que reemplaza el Player de un asiento.
	reattach: (self: Match, player: Player) -> boolean,
}

-- Suscriptor del arranque de una partida. PresenceService se engancha para tener los asientos
-- listos antes de la primera salida; la Tarea 5 y la 6 arrancan partidas sin saber quién escucha.
export type StartCallback = (match: Match) -> ()

local MatchService = {}

-- Tabla de métodos del objeto de partida. El tipo `Match` y esta tabla conviven en espacios de
-- nombres distintos de Luau: el tipo describe la forma y la tabla guarda las funciones.
local Match = {}

local current: Match? = nil

-- Suscriptores del arranque de partidas. Se guardan aquí y no en cada partida porque el aviso
-- ocurre antes de que el servidor pueda consultar `current` (R-P28).
local startCallbacks: { StartCallback } = {}

-- El PlayerId del motor es el userId en texto. La conversión vive en el borde: aquí y en
-- RemoteGateway, nunca en el motor ni en el cliente.
local function playerIdOf(player: Player): PlayerId
	return tostring(player.UserId)
end

-- ¿La conexión sigue en el juego? Un jugador que se fue conserva su Player como referencia en
-- `players` hasta que vuelve, pero su instancia ya no cuelga de Players: no se le envía nada.
local function present(player: Player?): boolean
	return player ~= nil and player.Parent ~= nil
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
		if present(player) then
			remote:FireClient(player, MatchState.batch(match.state, step, statePlayer.id))
		end
	end
end

-- Avisa a los suscriptores de un paso ya aplicado. Un suscriptor roto no puede tumbar el latido
-- ni la partida: se avisa y se sigue con los demás (R-P28).
local function notify(callbacks: { (playerId: PlayerId) -> () }, playerId: PlayerId)
	for _, callback in callbacks do
		local ok: boolean, err: any = pcall(callback, playerId)
		if not ok then
			warn(`MatchService: un suscriptor falló: {err}`)
		end
	end
end

-- Cancela el turno de bot programado, si lo hay. `pcall` protege el abandono: cancelar un hilo
-- que ya terminó no puede impedir que la partida se cierre.
local function stopBots(match: Match)
	local thread = match.botThread
	match.botThread = nil
	match.botSeq = nil
	if thread then
		pcall(task.cancel, thread)
	end
end

-- Programa el turno de bot que corresponda; se asigna más abajo, cuando ya existen el motor y
-- el reloj que necesita. `record` lo llama al terminar cualquier paso.
local kickBots: (match: Match) -> ()

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
	kickBots(match)
end

-- Tiempo agotado: el reloj del servidor resuelve la fase. Un partido ya cerrado o en GameOver no
-- vuelve a disparar (el defecto de la subfase 02). Si el tic no emitió eventos ni movió fase,
-- ronda o turno, el reloj no puede avanzar: se abandona con un motivo claro en vez de rearmar el
-- mismo plazo y quemar `seq` con lotes vacíos. `notifyTimeout` distingue el vencimiento de una
-- persona (cuenta para su racha) del cierre que hace el bot cuando no encuentra jugada.
local function fireTimeout(match: Match, now: number, notifyTimeout: boolean)
	if match.finished or match.state.phase == "GameOver" or MatchState.over(match.matchState) then
		match.finished = true
		stopBots(match)
		return
	end
	local decider = MatchState.decidingPlayer(match.state)
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
	if notifyTimeout and decider then
		notify(match.timeoutCallbacks, decider)
	end
end

-- Acción aplicada por la clave del motor. Es el mismo camino para una persona y para un bot:
-- valida con Engine.apply, registra el paso y difunde. `fromClient` distingue lo que llegó por la
-- puerta: solo lo rechazado de un cliente se cuenta (R-P22); una jugada de bot rechazada se
-- descarta sin contarla y el turno del bot busca otra salida. No avisa a `onAction`: el aviso es
-- de las acciones de personas, y el bot no debe desactivarse a sí mismo (R-P6).
local function applyAction(match: Match, playerId: PlayerId, action: Action, fromClient: boolean): boolean
	if match.finished or MatchState.over(match.matchState) then
		return false
	end
	local phaseBefore: Phase = match.state.phase
	local result = Engine.apply(match.state, playerId, action)
	if not result.ok then
		if fromClient then
			match.rejectedActions += 1
		end
		return false
	end
	record(match, result.events, phaseBefore, action.type, false, time())
	return true
end

-- Primer asiento con bot que tiene una decisión pendiente. Engine.legalActions es la misma fuente
-- que valida apply: si el bot no tiene ninguna acción legal, no es su decisión.
local function pendingBot(match: Match): PlayerId?
	for _, player in match.state.players do
		if player.isBot and #Engine.legalActions(match.state, player.id) > 0 then
			return player.id
		end
	end
	return nil
end

-- ¿Queda alguna persona que pueda actuar? Si todas las decisiones pendientes son de bots, el
-- bot sin jugada puede cerrar la fase con el reloj; si hay una persona decidiendo, no: en una
-- subasta un bot sin puja no puede robarle la decisión a quien todavía está mirando.
local function pendingHuman(match: Match): boolean
	for _, player in match.state.players do
		if not player.isBot and #Engine.legalActions(match.state, player.id) > 0 then
			return true
		end
	end
	return false
end

-- Turno de bot (R-P27): se juega al terminar la escena, no al vencer el plazo de decisión. Prueba
-- a cada asiento con bot, porque la fase puede tener varios decidiendo a la vez (duelo, tribunal).
-- Si ninguno aplica —porque no le compensa pujar o porque el motor rechazó la jugada— y ya no
-- queda persona que pueda actuar, el reloj cierra la fase: un bot que se rindió no puede dejar la
-- mesa esperando el plazo entero. Si una persona sigue decidiendo, no se le roba la decisión.
local function playBot(match: Match)
	if match.finished then
		return
	end
	local rejected = false
	for _, player in match.state.players do
		if player.isBot then
			local action = Bot.choose(match.state, player.id)
			if action then
				if applyAction(match, player.id, action, false) then
					return
				end
				rejected = true
			end
		end
	end
	if pendingHuman(match) then
		return
	end
	if rejected or pendingBot(match) then
		fireTimeout(match, time(), false)
	end
end

-- Programa el turno del bot para cuando acabe la escena del paso en curso (R-P27). Un solo hilo
-- por partida y ligado al `seq` del paso: mientras la partida siga en el mismo paso se conserva y,
-- en cuanto hay un paso nuevo, se rearma para la escena nueva (si la escena se alargó, el hilo
-- viejo no puede disparar a mitad de ella). Sin bot pendiente no hay hilo.
kickBots = function(match: Match)
	if match.finished then
		stopBots(match)
		return
	end
	if not pendingBot(match) then
		stopBots(match)
		return
	end
	if match.botThread and match.botSeq == match.matchState.seq then
		return
	end
	stopBots(match)
	local now = time()
	local delay = math.max(match.matchState.sceneEndsAt + Scenes.botDelaySec - now, 0)
	match.botSeq = match.matchState.seq
	match.botThread = task.delay(delay, function()
		match.botThread = nil
		match.botSeq = nil
		playBot(match)
	end)
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
				fireTimeout(match, now, true)
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
		if present(player) then
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

-- Acción de una persona. Se aplica por el mismo camino que la de un bot; si el motor la rechaza,
-- se cuenta y no se difunde nada (R-P22). El cliente que se haya quedado desfasado pide
-- resincronización. Tras aplicarla se avisa a la presencia, que reinicia su racha y le devuelve el
-- control (R-P28): una acción humana es la única que desactiva un bot.
Match.submit = function(self: Match, player: Player, action: Action)
	local playerId = playerIdOf(player)
	if applyAction(self, playerId, action, true) then
		notify(self.actionCallbacks, playerId)
	end
end

-- Control por bot (R-P6): el servicio de presencia decide y este es el único camino que escribe
-- state.players[i].isBot. Devuelve false si el jugador no está en la partida. Cada cambio vuelve
-- a programar el turno del bot: al activarlo hay que jugarlo y al desactivarlo puede que ya no
-- quede ninguno pendiente.
Match.setBotControlled = function(self: Match, playerId: PlayerId, controlled: boolean): boolean
	local applied = MatchState.setBotControlled(self.matchState, self.state, playerId, controlled)
	if applied then
		kickBots(self)
	end
	return applied
end

-- Abandono (R-P8): para el latido y el turno del bot, fija endedAt y avisa al callback
-- registrado. Es el único camino que usará el servicio de presencia cuando no quede ningún
-- humano.
Match.abandon = function(self: Match, reason: string)
	if self.abandoned then
		return
	end
	self.abandoned = true
	self.abandonReason = reason
	self.finished = true
	stopBots(self)
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

-- Ganchos de la partida (R-P28). Se avisa después de que el motor haya actuado y nunca se lee el
-- interior desde fuera: la presencia mantiene sus asientos con estos avisos y la telemetría de la
-- Tarea 7 se enganchará a los mismos. Un suscriptor que falle no tumba el latido (`notify`).
Match.onTimeout = function(self: Match, callback: (playerId: PlayerId) -> ())
	table.insert(self.timeoutCallbacks, callback)
end

Match.onAction = function(self: Match, callback: (playerId: PlayerId) -> ())
	table.insert(self.actionCallbacks, callback)
end

-- Una conexión nueva ocupa el asiento de un jugador que vuelve. El asiento y su mano nunca se
-- perdieron (viven en el motor): aquí se reemplaza el Player viejo por el nuevo, para que los
-- lotes le lleguen, y se le manda la vista actual con el `seq` vigente. Devuelve false si el
-- jugador no está sentado en esta partida.
Match.reattach = function(self: Match, player: Player): boolean
	local playerId = playerIdOf(player)
	local seated = false
	for _, statePlayer in self.state.players do
		if statePlayer.id == playerId then
			seated = true
			break
		end
	end
	if not seated then
		return false
	end
	self.players[playerId] = player
	local batch = MatchState.resync(self.matchState, self.state, playerId, time())
	RemoteGateway.remote(Protocol.REMOTES.Batch):FireClient(player, batch)
	return true
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
		botThread = nil,
		botSeq = nil,
		timeoutCallbacks = {},
		actionCallbacks = {},
		abandonCallback = nil,
		submit = Match.submit,
		setBotControlled = Match.setBotControlled,
		abandon = Match.abandon,
		onAbandon = Match.onAbandon,
		onTimeout = Match.onTimeout,
		onAction = Match.onAction,
		reattach = Match.reattach,
	}
	return match
end

-- Avisa del arranque de una partida a los suscriptores ya conectados. Un suscriptor roto no
-- impide jugar: se avisa y la partida sigue.
local function notifyStart(match: Match)
	for _, callback in startCallbacks do
		local ok: boolean, err: any = pcall(callback, match)
		if not ok then
			warn(`MatchService: un suscriptor del arranque falló: {err}`)
		end
	end
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
	notifyStart(match)
	return match
end

-- La partida vigente del servidor, o nil si todavía no hay ninguna. Sigue devolviendo la última
-- cuando ya terminó, para que la revancha consulte su estado.
function MatchService.current(): Match?
	return current
end

-- Se suscribe al arranque de partidas. Si ya hay una en curso avisa de inmediato, para que
-- conectar la presencia después del primer arranque no la deje sin asientos.
function MatchService.onStart(callback: StartCallback)
	table.insert(startCallbacks, callback)
	if current then
		local ok: boolean, err: any = pcall(callback, current)
		if not ok then
			warn(`MatchService: el suscriptor del arranque falló: {err}`)
		end
	end
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

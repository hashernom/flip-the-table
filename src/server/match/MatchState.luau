--!strict
-- Estado puro de una partida en el servidor: número de lote, escenas vistas, vencimiento de la
-- decisión y observaciones para la telemetría. MatchService lo envuelve, le pasa `now` y difunde
-- lo que produce; así la numeración, los plazos, las observaciones y el filtrado por jugador se
-- prueban con Lune sin tocar Roblox (R-P5, R-P7, R-P20).
local Perks = require("../../shared/rules/Perks")
local Protocol = require("../../shared/net/Protocol")
local Scenes = require("../../shared/config/Scenes")
local Score = require("../../shared/rules/Score")
local Types = require("../../shared/rules/Types")
local View = require("../../shared/rules/View")
local ViewWire = require("../../shared/net/ViewWire")
local SceneClock = require("./SceneClock")

type Event = Types.Event
type GameState = Types.GameState
type Phase = Types.Phase
type PlayerId = Types.PlayerId
type PlayerView = Types.PlayerView

-- Observaciones de la partida (R-P7). La telemetría del plan 07 las usa para el resumen; aquí solo
-- se mantienen. `leaders[round]` es el líder al empezar esa ronda, el mismo criterio que
-- tests/sim.luau usa para el líder a mitad de partida.
export type Observations = {
	startedAt: number,
	endedAt: number?,
	turns: number,
	sceneSec: number,
	leaders: { [number]: PlayerId },
}

-- Lote que recibe un jugador. El contrato es fijo: mismo `seq` para todos, eventos ya filtrados y
-- la vista de ese jugador. No comparte tablas con el estado.
export type Batch = {
	seq: number,
	startsAt: number,
	-- Cuándo vence la decisión vigente (R-P40): el temporizador del cliente es este, no uno propio.
	decisionDeadline: number,
	events: { Event },
	view: PlayerView,
}

-- Resultado puro de un paso del motor: el lote sin filtrar y los dos instantes que decide el
-- servidor. `sceneEndsAt` es cuándo termina la última escena; `decisionDeadline`, cuándo vence la
-- decisión (sceneEndsAt + Scenes.decisionSeconds de la fase nueva).
export type Step = {
	seq: number,
	startsAt: number,
	events: { Event },
	sceneEndsAt: number,
	decisionDeadline: number,
}

-- Foto mínima del avance de la partida antes de tirar del reloj. Si después del tiempo agotado no
-- cambió nada y el motor no emitió eventos, el reloj no puede sacar la partida de donde está.
export type Snapshot = {
	phase: Phase,
	round: number,
	turnIndex: number,
}

export type MatchState = {
	-- Último lote emitido. Empieza en 0 y crece de uno en uno con cada paso aceptado. El primer
	-- lote lleva seq 1; el resync antes de cualquier paso devuelve 0, que significa «sin lotes».
	seq: number,
	clock: SceneClock.SceneClock,
	sceneEndsAt: number,
	decisionDeadline: number,
	-- Qué decisión cubre ese plazo (R-P40). Nil hasta que el primer paso fije una.
	decisionKey: string?,
	observations: Observations,
	-- Control por bot que pidió el servicio de presencia (R-P6). Se registra aquí y el estado del
	-- motor se toca en un solo sitio: MatchState.setBotControlled.
	bots: { [PlayerId]: boolean },
	-- Limitador de las peticiones de resincronización de esta partida. Sin él, un cliente que
	-- reintenta construiría una vista completa por paquete y frenaría el latido de todos.
	resyncLimiter: Protocol.Limiter,
}

local MatchState = {}

-- Identifica la decisión que la partida está esperando (R-P40). Solo una decisión nueva da el plazo
-- completo: proponer un trato, pujar o votar dejan esto igual y por tanto no reinician el reloj.
function MatchState.decisionKey(state: GameState): string
	local pending = state.pending
	local duel = if pending then pending.duel else nil
	local draft = if pending then pending.draft else nil
	return table.concat({
		state.phase,
		tostring(state.round),
		tostring(state.turnIndex),
		if duel then `{tostring(duel.rivalId)}:{tostring(duel.round)}` else "",
		if draft then tostring(draft.index) else "",
	}, "|")
end

-- Estado inicial de la partida. La fase inicial también tiene plazo de decisión (el borrador de
-- perks empieza en PerkDraft y no debe quedarse esperando para siempre).
function MatchState.begin(startedAt: number, phase: Phase, decisionKey: string?): MatchState
	return {
		seq = 0,
		clock = SceneClock.new(),
		sceneEndsAt = startedAt,
		decisionDeadline = startedAt + Scenes.decisionSeconds(phase),
		decisionKey = decisionKey,
		observations = {
			startedAt = startedAt,
			endedAt = if phase == "GameOver" then startedAt else nil,
			turns = 0,
			sceneSec = 0,
			leaders = {},
		},
		bots = {},
		resyncLimiter = Protocol.newLimiter(),
	}
end

-- ¿La partida ya terminó o se abandonó? Un paso nuevo después de esto no debe emitir otro lote.
function MatchState.over(match: MatchState): boolean
	return match.observations.endedAt ~= nil
end

-- ¿Este paso cierra un turno? El motor no emite un evento EndTurn (no está en la lista de
-- «Eventos» de la arquitectura), así que se decide por la causa, con la misma regla que
-- tests/sim.luau: EndTurn y GhostAct cierran turno por definición, y el reloj lo cierra en
-- AwaitEnd y GhostTurn. `actionType` es nil cuando el paso lo produjo el reloj del servidor.
function MatchState.endsTurn(actionType: string?, phaseBefore: Phase, fromClock: boolean): boolean
	if actionType ~= nil then
		return actionType == "EndTurn" or actionType == "GhostAct"
	end
	return fromClock and (phaseBefore == "AwaitEnd" or phaseBefore == "GhostTurn")
end

-- Foto mínima del avance de la partida, tomada antes de tirar del reloj.
function MatchState.snapshot(state: GameState): Snapshot
	return { phase = state.phase, round = state.round, turnIndex = state.turnIndex }
end

-- ¿El tiempo agotado sacó a la partida de donde estaba? Si no emitió eventos y la fase, la ronda y
-- el turno siguen igual, el reloj no puede avanzar: hay que abandonar en vez de rearmar el mismo
-- plazo y quemar `seq` con lotes vacíos cada período de decisión.
function MatchState.timeoutAdvanced(state: GameState, before: Snapshot, events: { Event }): boolean
	if #events > 0 then
		return true
	end
	if state.phase ~= before.phase or state.round ~= before.round then
		return true
	end
	return state.turnIndex ~= before.turnIndex
end

-- ¿Se atiende ya una acción de un cliente? Durante una escena no (R-P39): el siguiente paso no empieza
-- hasta que el grupo la ha visto. Lo descartado no cuenta como trampa: es un clic de más.
function MatchState.acceptsAction(match: MatchState, now: number): boolean
	return now + Scenes.actionGraceSec >= match.sceneEndsAt
end

-- Registra un paso aceptado del motor: numera el lote, programa sus escenas, fija el plazo de
-- decisión y actualiza las observaciones. Devuelve nil si la partida ya está cerrada, para que
-- MatchService no difunda dos veces el final. `now` es el instante del servidor. El lote empieza
-- cuando acaba la escena en curso (R-P39). Una decisión nueva tiene su plazo entero al acabar la
-- escena; dentro de la misma, el plazo solo se alarga lo que dure esta escena (R-P40).
function MatchState.step(
	match: MatchState,
	state: GameState,
	events: { Event },
	now: number,
	endedTurn: boolean
): Step?
	if MatchState.over(match) then
		return nil
	end
	local startsAt = math.max(now, match.clock.endsAt)
	local sceneEndsAt = SceneClock.schedule(match.clock, events, now)
	local decisionKey = MatchState.decisionKey(state)
	local decisionDeadline = if decisionKey ~= match.decisionKey
		then sceneEndsAt + Scenes.decisionSeconds(state.phase)
		else match.decisionDeadline + (sceneEndsAt - startsAt)
	match.seq += 1
	match.sceneEndsAt = sceneEndsAt
	match.decisionDeadline = decisionDeadline
	match.decisionKey = decisionKey
	local observations = match.observations
	observations.sceneSec += sceneEndsAt - startsAt
	if endedTurn then
		observations.turns += 1
	end
	-- El líder de cada ronda se lee del estado ya actualizado, igual que tests/sim.luau: el evento
	-- RoundStarted dice qué ronda empieza y la clasificación, quién la lidera.
	for _, event in events do
		local round = event.round
		if event.type == "RoundStarted" and type(round) == "number" then
			observations.leaders[round] = Score.ranking(state)[1]
		end
	end
	if state.phase == "GameOver" and observations.endedAt == nil then
		observations.endedAt = now
	end
	return {
		seq = match.seq,
		startsAt = startsAt,
		events = events,
		sceneEndsAt = sceneEndsAt,
		decisionDeadline = decisionDeadline,
	}
end

-- Lote de un jugador para un paso. El `seq` es el mismo para todos; los eventos se filtran y la
-- vista se construye por jugador (View es el único sitio que decide qué se ve).
function MatchState.batch(state: GameState, step: Step, playerId: PlayerId): Batch
	return {
		seq = step.seq,
		startsAt = step.startsAt,
		decisionDeadline = step.decisionDeadline,
		events = View.filterEvents(state, playerId, step.events),
		-- Las claves de `properties` viajan como texto (ViewWire): con números se pierden entradas.
		view = ViewWire.encode(View.forPlayer(state, playerId)),
	}
end

-- Resincronización: la vista actual del jugador con el `seq` vigente, sin consumir un número
-- nuevo. Es lo que responde a ResyncRequest y lo que se envía al empezar la partida. `seq = 0`
-- significa «todavía no hay ningún lote»; el cliente no debe tratarlo como error.
function MatchState.resync(match: MatchState, state: GameState, playerId: PlayerId, now: number): Batch
	return {
		seq = match.seq,
		startsAt = now,
		decisionDeadline = match.decisionDeadline,
		events = {},
		-- Las claves de `properties` viajan como texto (ViewWire): con números se pierden entradas.
		view = ViewWire.encode(View.forPlayer(state, playerId)),
	}
end

-- ¿Se atiende una petición de resincronización? El limitador de la partida se consulta antes de
-- construir la vista (lo caro) y después se exige que el jugador siga en la mesa. Lo descartado no
-- gasta cupo y no avisa: es el mismo trato silencioso que R-P22 da a lo rechazado.
function MatchState.acceptsResync(
	match: MatchState,
	state: GameState,
	playerId: PlayerId,
	now: number
): boolean
	if not match.resyncLimiter.allow(playerId, now) then
		return false
	end
	for _, player in state.players do
		if player.id == playerId then
			return true
		end
	end
	return false
end

-- Jugador al que le vence la decisión cuando el reloj cierra la fase. En el borrador elige a
-- quien le toca (no siempre es el jugador en turno) y en la ventana de reacción contesta el
-- elegido por la carta o la renta. El resto de fases son del jugador en turno, salvo las colectivas
-- (subasta, duelo, tribunal): su reloj vence con normalidad y no es culpa de nadie en concreto, así
-- que no cuenta para que un bot tome el control. Lo usa MatchService para avisar a la presencia del
-- asiento que acumuló el tiempo.
function MatchState.decidingPlayer(state: GameState): PlayerId?
	local phase = state.phase
	if phase == "GameOver" or phase == "Auction" or phase == "Tribunal" or phase == "Duel" then
		return nil
	end
	if state.phase == "PerkDraft" then
		return Perks.currentDrafter(state)
	end
	if state.phase == "Reaction" then
		local pending = state.pending
		local reaction = if pending then pending.reaction else nil
		local eligibleId = if reaction then reaction.eligibleId else nil
		if type(eligibleId) == "string" then
			return eligibleId
		end
	end
	local player = state.players[state.turnIndex]
	if not player then
		return nil
	end
	return player.id
end

-- Abandono de la partida (R-P8): fija el final una sola vez. Quien la llama es MatchService, que
-- además para el latido y avisa al callback registrado.
function MatchState.abandon(match: MatchState, now: number)
	if match.observations.endedAt == nil then
		match.observations.endedAt = now
	end
end

-- Cambia el control por bot de un jugador. Es el único sitio que escribe `state.players[i].isBot`
-- (R-P6): el servicio de presencia decide y aquí se aplica y se registra. Devuelve false si el
-- jugador no está en la partida.
function MatchState.setBotControlled(
	match: MatchState,
	state: GameState,
	playerId: PlayerId,
	controlled: boolean
): boolean
	for _, player in state.players do
		if player.id == playerId then
			player.isBot = controlled
			match.bots[playerId] = controlled
			return true
		end
	end
	return false
end

return MatchState

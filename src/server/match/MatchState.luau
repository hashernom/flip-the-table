--!strict
-- Estado puro de una partida en el servidor: número de lote, escenas vistas, vencimiento de la
-- decisión y observaciones para la telemetría. MatchService lo envuelve, le pasa `now` y difunde
-- lo que produce; así la numeración, los plazos, las observaciones y el filtrado por jugador se
-- prueban con Lune sin tocar Roblox (R-P5, R-P7, R-P20).
local Scenes = require("../../shared/config/Scenes")
local Score = require("../../shared/rules/Score")
local Types = require("../../shared/rules/Types")
local View = require("../../shared/rules/View")
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

export type MatchState = {
	-- Último lote emitido. Empieza en 0 y crece de uno en uno con cada paso aceptado. El primer
	-- lote lleva seq 1; el resync antes de cualquier paso devuelve 0, que significa «sin lotes».
	seq: number,
	clock: SceneClock.SceneClock,
	sceneEndsAt: number,
	decisionDeadline: number,
	observations: Observations,
	-- Control por bot que pidió el servicio de presencia (R-P6). Se registra aquí y el estado del
	-- motor se toca en un solo sitio: MatchState.setBotControlled.
	bots: { [PlayerId]: boolean },
}

local MatchState = {}

-- Estado inicial de la partida. La fase inicial también tiene plazo de decisión (el borrador de
-- perks empieza en PerkDraft y no debe quedarse esperando para siempre).
function MatchState.begin(startedAt: number, phase: Phase): MatchState
	return {
		seq = 0,
		clock = SceneClock.new(),
		sceneEndsAt = startedAt,
		decisionDeadline = startedAt + Scenes.decisionSeconds(phase),
		observations = {
			startedAt = startedAt,
			endedAt = if phase == "GameOver" then startedAt else nil,
			turns = 0,
			sceneSec = 0,
			leaders = {},
		},
		bots = {},
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

-- Registra un paso aceptado del motor: numera el lote, programa sus escenas, fija el plazo de
-- decisión y actualiza las observaciones. Devuelve nil si la partida ya está cerrada, para que
-- MatchService no difunda dos veces el final. `now` es el instante del servidor.
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
	local sceneEndsAt = SceneClock.schedule(match.clock, events, now)
	local decisionDeadline = sceneEndsAt + Scenes.decisionSeconds(state.phase)
	match.seq += 1
	match.sceneEndsAt = sceneEndsAt
	match.decisionDeadline = decisionDeadline
	local observations = match.observations
	observations.sceneSec += sceneEndsAt - now
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
		startsAt = now,
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
		events = View.filterEvents(state, playerId, step.events),
		view = View.forPlayer(state, playerId),
	}
end

-- Resincronización: la vista actual del jugador con el `seq` vigente, sin consumir un número
-- nuevo. Es lo que responde a ResyncRequest y lo que se envía al empezar la partida (seq 0).
function MatchState.resync(match: MatchState, state: GameState, playerId: PlayerId, now: number): Batch
	return {
		seq = match.seq,
		startsAt = now,
		events = {},
		view = View.forPlayer(state, playerId),
	}
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

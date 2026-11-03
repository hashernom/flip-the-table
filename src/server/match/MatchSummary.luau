--!strict
-- Resumen de una partida y cálculo de los criterios de salida (Tarea 7). Es un módulo puro: no usa
-- `game`, ni `task`, ni ningún reloj, así que se prueba con Lune y la herramienta del informe puede
-- requirelo sin la plataforma de Roblox (R-P15). `MatchService` mantiene las observaciones de la
-- partida (R-P7) y `Telemetry` se las pasa aquí al terminar; el resumen nunca lee el interior de una
-- partida en curso.
--
-- El contrato es el del plan: `Summary` tiene exactamente los once campos declarados y ni un nombre
-- de jugador ni un userId. `id` es aleatorio (dos partidas iguales dan ids distintos) y no se deriva
-- de nadie: un resumen que pudiera identificar a una persona sería un defecto.
local Score = require("../../shared/rules/Score")
local Types = require("../../shared/rules/Types")

type EndMode = Types.EndMode
type GameState = Types.GameState
type PlayerId = Types.PlayerId
type SizeId = Types.SizeId

-- Observaciones que mantiene `MatchState` mientras la partida corre. Aquí se declaran solo los
-- campos que el resumen lee, para no arrastrar el servicio de partida a la herramienta; el objeto
-- real encaja tal cual (R-P7).
export type Observations = {
	turns: number,
	sceneSec: number,
	leaders: { [number]: PlayerId },
}

-- Resumen de una partida. Es exactamente la forma del plan, sin campos añadidos: el abandono no se
-- guarda, se deduce de `finished`.
--
-- `leaderAtHalfWon` es verdadero si el líder de la ronda central ganó, falso si perdió y `nil` si no
-- se pudo observar (una quiebra temprana que cierra la partida antes de la mitad, o un resumen
-- construido sin observaciones). Un cero silencioso no es una derrota: el informe solo cuenta los
-- casos observados y publica el tamaño de esa muestra.
export type Summary = {
	id: string,
	sizeId: SizeId,
	endMode: EndMode,
	players: number,
	durationSec: number,
	avgTurnSec: number,
	leaderAtHalfWon: boolean?,
	finished: boolean,
	rematch: boolean,
	cardsPlayed: number,
	sceneSec: number,
}

-- Informe de los cuatro criterios medibles de la ficha, calculado solo con partidas en modo Rondas.
-- Las tasas son fracciones de 0 a 1; el tamaño de cada muestra va al lado para que el informe diga
-- con cuántos datos cuenta, en vez de presentar un cero por falta de datos como una derrota.
--
--   · `durationSamples`: partidas terminadas de 4 a 8 jugadores (alcance de la ficha).
--   · `leaderSamples`: partidas terminadas con líder a mitad observado (`leaderAtHalfWon` no nil).
export type Report = {
	matches: number,
	ignored: number,
	finished: number,
	finishedRate: number,
	firstMatches: number,
	rematches: number,
	rematchRate: number,
	durationSamples: number,
	averageDurationSec: number,
	leaderSamples: number,
	leadersWon: number,
	leaderAtHalfRate: number,
}

local MatchSummary = {}

-- Alcance del criterio de duración de la ficha: «Las partidas de 4 a 8 jugadores en modo Rondas
-- duran de 25 a 35 minutos» (y deja 2–3 jugadores fuera de los objetivos). No es un valor de juego
-- que se ajuste jugando, sino el recorte con el que se mide; el mínimo de la partida sigue en 2.
local DURATION_MIN_PLAYERS = 4

-- 62 bits de azar en 16 dígitos hexadecimales. No se usa el reloj ni nada del servidor: el id no
-- puede identificar a una persona ni servir para correlacionar partidas entre servidores.
local function newId(): string
	return string.format("%08x%08x", math.random(1, 0x7FFFFFFF), math.random(1, 0x7FFFFFFF))
end

-- Ganador de la partida: el primer jugador `Active` de la clasificación. Es la misma regla que
-- `Turn.winnerOf` y la que usa el evento `GameEnded`; el resumen no toca el motor para averiguarlo.
local function winnerOf(state: GameState): PlayerId
	local ranking = Score.ranking(state)
	for _, playerId in ranking do
		for _, player in state.players do
			if player.id == playerId and player.status == "Active" then
				return playerId
			end
		end
	end
	return ranking[1]
end

-- Líder de la ronda central de las jugadas. La mitad se toma sobre la última ronda que empezó, no
-- sobre el número de entradas: el motor no emite `RoundStarted` de la ronda 1, así que las claves
-- empiezan en 2 y el operador `#` de Luau no es fiable para esto. Es la misma cuenta que
-- `tests/sim.luau` hace con `maxRound`.
local function middleLeader(leaders: { [number]: PlayerId }): PlayerId?
	local lastRound = 0
	for round in leaders do
		if round > lastRound then
			lastRound = round
		end
	end
	if lastRound == 0 then
		return nil
	end
	return leaders[math.ceil(lastRound / 2)]
end

-- Cartas jugadas de verdad en la partida, sumando el contador que escribe el motor en
-- `state.stats[playerId].cardsPlayed` (Cards.recordCardPlay). Un jugador sin contador cuenta cero.
local function cardsPlayedOf(state: GameState): number
	local total = 0
	for _, player in state.players do
		local stats = state.stats[player.id]
		if stats ~= nil then
			total += stats.cardsPlayed or 0
		end
	end
	return total
end

-- Resumen de una partida terminada o abandonada. Con cinco argumentos deduce del estado final lo
-- que sí es deducible (`players`, `sizeId`, `endMode`, `finished`, `rematch`, `cardsPlayed` y la
-- duración) y deja en cero `avgTurnSec` y `sceneSec`; `leaderAtHalfWon` queda nil porque no hay
-- forma de saberlo. Con el sexto argumento rellena turnos y escena y, si la ronda central está
-- anotada, también el líder (R-P7).
--
-- `finished` es verdadero solo si el motor llegó a `GameOver` y la partida no se abandonó: un
-- abandono interrumpe la partida y no cuenta como final.
function MatchSummary.fromState(
	state: GameState,
	startedAt: number,
	endedAt: number,
	rematch: boolean,
	abandoned: boolean,
	observations: Observations?
): Summary
	local durationSec = math.max(0, endedAt - startedAt)
	local avgTurnSec = 0
	local sceneSec = 0
	local leaderAtHalfWon: boolean? = nil
	if observations ~= nil then
		if observations.turns > 0 then
			avgTurnSec = durationSec / observations.turns
		end
		sceneSec = math.max(0, observations.sceneSec)
		local leader = middleLeader(observations.leaders)
		if leader ~= nil then
			leaderAtHalfWon = leader == winnerOf(state)
		end
	end
	return {
		id = newId(),
		sizeId = state.sizeId,
		endMode = state.endMode,
		players = #state.players,
		durationSec = durationSec,
		avgTurnSec = avgTurnSec,
		leaderAtHalfWon = leaderAtHalfWon,
		finished = state.phase == "GameOver" and not abandoned,
		rematch = rematch,
		cardsPlayed = cardsPlayedOf(state),
		sceneSec = sceneSec,
	}
end

-- Informe de los cuatro criterios medibles, calculado solo con partidas en modo Rondas:
--
--   · partidas terminadas: terminadas / iniciadas;
--   · segunda partida: revanchas / primeras partidas (R-P16, sin identificador de grupo);
--   · duración: media de las partidas terminadas de 4 a 8 jugadores, el alcance de la ficha;
--   · líder a mitad: partidas terminadas con líder observado en las que ganó ese líder.
--
-- Una lista vacía devuelve ceros, sin dividir por cero. Las partidas Sin Fin se cuentan en
-- `ignored` y no entran en ninguna de las cuatro cuentas. Un `leaderAtHalfWon` nil (no observado)
-- suma en partidas terminadas pero no en el denominador del líder: no se puede contar como derrota
-- lo que no se midió.
function MatchSummary.report(summaries: { Summary }): Report
	local matches = 0
	local ignored = 0
	local finished = 0
	local firstMatches = 0
	local rematches = 0
	local durationSamples = 0
	local durationTotal = 0
	local leaderSamples = 0
	local leadersWon = 0
	for _, summary in summaries do
		if summary.endMode ~= "Rounds" then
			ignored += 1
		else
			matches += 1
			if summary.rematch then
				rematches += 1
			else
				firstMatches += 1
			end
			if summary.finished then
				finished += 1
				if summary.players >= DURATION_MIN_PLAYERS then
					durationSamples += 1
					durationTotal += summary.durationSec
				end
				local leaderAtHalfWon = summary.leaderAtHalfWon
				if leaderAtHalfWon ~= nil then
					leaderSamples += 1
					if leaderAtHalfWon then
						leadersWon += 1
					end
				end
			end
		end
	end
	return {
		matches = matches,
		ignored = ignored,
		finished = finished,
		finishedRate = if matches > 0 then finished / matches else 0,
		firstMatches = firstMatches,
		rematches = rematches,
		rematchRate = if firstMatches > 0 then rematches / firstMatches else 0,
		durationSamples = durationSamples,
		averageDurationSec = if durationSamples > 0 then durationTotal / durationSamples else 0,
		leaderSamples = leaderSamples,
		leadersWon = leadersWon,
		leaderAtHalfRate = if leaderSamples > 0 then leadersWon / leaderSamples else 0,
	}
end

return MatchSummary

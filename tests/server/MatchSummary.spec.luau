--!strict
-- Pruebas del resumen de partida y del informe de criterios de salida (Tarea 7). Se ejecutan con
-- Lune y con estados reales del motor: la partida que se resume se juega con `Engine.timeout` y se
-- anota con `MatchState.step`, que es el mismo camino que usa `MatchService`. Así el resumen se
-- prueba contra observaciones de verdad (turnos, escena y líder de cada ronda) y no contra una
-- maqueta. `MatchSummary` no usa `game`, ni `task`, ni relojes: el instante llega por parámetro.
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Harness = require("../harness")
local MatchState = require("../../src/server/match/MatchState")
local MatchSummary = require("../../src/server/match/MatchSummary")
local Score = require("../../src/shared/rules/Score")
local Types = require("../../src/shared/rules/Types")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

type GameState = Types.GameState
type PlayerId = Types.PlayerId
type Observations = MatchSummary.Observations
type Report = MatchSummary.Report
type Summary = MatchSummary.Summary

-- Ids del motor con la forma real (userId en texto), para que la prueba de datos personales sea
-- honesta: el resumen no puede contener ninguno de ellos.
local PLAYER_IDS: { PlayerId } = { "P1", "P2", "P3" }

local function stateOf(players: number, seed: number, endMode: Types.EndMode?): GameState
	-- Los estados salen de `tests/fixtures`, que salta el borrador y la Zona Caliente para que la
	-- prueba no dependa del azar de esas dos fases (la simulación ya las cubre).
	local options: Fixtures.GameOptions = { players = players, seed = seed, endMode = endMode }
	return Fixtures.game(options)
end

-- Ganador con la regla del motor: el primero Active de la clasificación (Turn.winnerOf). Se calcula
-- aquí a mano, sin MatchSummary, para que la prueba no repita la implementación que comprueba.
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

-- Juega una partida entera a base de tiempo agotado y devuelve el estado final y las observaciones
-- que el servidor habría acumulado. Es el modo «idle» de tests/sim.luau: ninguna acción humana, todo
-- lo cierra el reloj, y ninguna fase se queda atascada.
local function idleMatch(players: number, seed: number): (GameState, MatchState.Observations)
	local state = stateOf(players, seed, "Rounds")
	local match = MatchState.begin(0, state.phase)
	local now = 0
	local steps = 0
	while state.phase ~= "GameOver" do
		local phaseBefore = state.phase
		local events = Engine.timeout(state)
		now += 1
		steps += 1
		if steps > 10000 then
			error("la partida de prueba no terminó", 2)
		end
		MatchState.step(match, state, events, now, phaseBefore == "AwaitEnd" or phaseBefore == "GhostTurn")
	end
	return state, match.observations
end

local function endedAtOf(observations: MatchState.Observations): number
	local endedAt = observations.endedAt
	if endedAt == nil then
		error("la partida de prueba debía terminar", 2)
	end
	return endedAt
end

-- Resumen de ejemplo para el informe, con lo que cada prueba quiera cambiar.
local nextId = 0
local function summaryOf(overrides: { [string]: any }): Summary
	nextId += 1
	local summary: Summary = {
		id = `resumen-{nextId}`,
		sizeId = "S",
		endMode = "Rounds",
		players = 4,
		durationSec = 0,
		avgTurnSec = 0,
		leaderAtHalfWon = false,
		finished = true,
		rematch = false,
		cardsPlayed = 0,
		sceneSec = 0,
	}
	for key, value in overrides do
		(summary :: any)[key] = value
	end
	return summary
end

local function keysOf(summary: Summary): { string }
	local keys: { string } = {}
	for key in summary :: { [string]: any } do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

describe("MatchSummary.fromState", function()
	it("con cinco argumentos deduce lo deducible del estado final", function()
		local state, observations = idleMatch(2, 7)
		local endedAt = endedAtOf(observations)
		local summary = MatchSummary.fromState(state, 10, 10 + endedAt, false, false)
		expect(summary.players).toBe(#state.players)
		expect(summary.sizeId).toBe(state.sizeId)
		expect(summary.endMode).toBe(state.endMode)
		expect(summary.finished).toBe(true)
		expect(summary.rematch).toBe(false)
		expect(summary.durationSec).toBe(endedAt)
		expect(summary.cardsPlayed).toBe(0)
		-- Sin observaciones no se puede adivinar: se deja en cero, nunca en un valor inventado.
		expect(summary.avgTurnSec).toBe(0)
		expect(summary.sceneSec).toBe(0)
		expect(summary.leaderAtHalfWon).toBe(false)
	end)

	it("con observaciones rellena turnos, escena y líder a mitad", function()
		local state, observations = idleMatch(3, 7)
		local endedAt = endedAtOf(observations)
		local summary =
			MatchSummary.fromState(state, observations.startedAt, endedAt, false, false, observations)
		expect(summary.durationSec).toBe(endedAt - observations.startedAt)
		expect(summary.avgTurnSec).toBe((endedAt - observations.startedAt) / observations.turns)
		expect(summary.sceneSec).toBe(observations.sceneSec)
		-- La partida de 3 jugadores y semilla 7 lidera la ronda 10 con quien acaba ganando.
		expect(observations.leaders[10]).toBe(winnerOf(state))
		expect(summary.leaderAtHalfWon).toBe(true)
	end)

	it("el líder a mitad que no gana se marca en falso", function()
		local state, observations = idleMatch(2, 7)
		local summary = MatchSummary.fromState(
			state,
			observations.startedAt,
			endedAtOf(observations),
			false,
			false,
			observations
		)
		expect(observations.leaders[10] ~= winnerOf(state)).toBe(true)
		expect(summary.leaderAtHalfWon).toBe(false)
	end)

	it("resume las observaciones de una acción real del motor", function()
		-- Un turno cerrado con Engine.apply (no con el reloj), anotado con MatchState.step: es el
		-- camino que usa MatchService cuando una persona pulsa «terminar turno».
		local state = Fixtures.game({ players = 2 })
		Fixtures.turnOf(state, state.players[2].id)
		state.phase = "AwaitEnd"
		local match = MatchState.begin(0, state.phase)
		local phaseBefore: Types.Phase = state.phase
		local actor = state.players[2].id
		local result = Engine.apply(state, actor, { type = "EndTurn" })
		if not result.ok then
			error(result.error, 2)
		end
		MatchState.step(match, state, result.events, 10, MatchState.endsTurn("EndTurn", phaseBefore, false))
		local observations = match.observations
		expect(observations.turns).toBe(1)
		expect(observations.leaders[2] ~= nil).toBe(true)
		local summary = MatchSummary.fromState(state, observations.startedAt, 10, false, false, observations)
		expect(summary.players).toBe(2)
		expect(summary.avgTurnSec).toBe(10)
		expect(summary.sceneSec).toBe(observations.sceneSec)
		expect(summary.sceneSec > 0).toBe(true)
		-- Solo se jugó la ronda 2, así que no hay ronda 1 que consultar: no se inventa un ganador.
		expect(summary.leaderAtHalfWon).toBe(false)
	end)

	it("el resumen tiene exactamente los campos del contrato", function()
		local state = Fixtures.game({ players = 2 })
		local summary = MatchSummary.fromState(state, 0, 10, false, false)
		expect(keysOf(summary)).toEqual({
			"avgTurnSec",
			"cardsPlayed",
			"durationSec",
			"endMode",
			"finished",
			"id",
			"leaderAtHalfWon",
			"players",
			"rematch",
			"sceneSec",
			"sizeId",
		})
	end)

	it("finished solo es verdadero con GameOver", function()
		local finished = stateOf(2, 7, "Rounds")
		finished.phase = "GameOver"
		expect(MatchSummary.fromState(finished, 0, 60, false, false).finished).toBe(true)

		local playing = Fixtures.game({ players = 2 })
		expect(playing.phase == "GameOver").toBe(false)
		expect(MatchSummary.fromState(playing, 0, 60, false, false).finished).toBe(false)

		-- Un abandono no es un final: aunque el estado hubiera llegado a GameOver, la partida se
		-- interrumpió y no cuenta como terminada.
		expect(MatchSummary.fromState(finished, 0, 60, false, true).finished).toBe(false)
	end)

	it("players, sizeId y endMode salen del estado", function()
		local medium = Fixtures.game({ players = 5 })
		local summary = MatchSummary.fromState(medium, 0, 1, false, false)
		expect(summary.players).toBe(5)
		expect(summary.sizeId).toBe(medium.sizeId)
		expect(summary.endMode).toBe("Rounds")

		local endless = Fixtures.game({ players = 7, endMode = "Endless" })
		local endlessSummary = MatchSummary.fromState(endless, 0, 1, false, false)
		expect(endlessSummary.players).toBe(7)
		expect(endlessSummary.endMode).toBe("Endless")
		expect(endlessSummary.sizeId).toBe(endless.sizeId)
	end)

	it("guarda la duración sin aceptar ceros ni negativos", function()
		local state = Fixtures.game({ players = 2 })
		expect(MatchSummary.fromState(state, 100, 160, false, false).durationSec).toBe(60)
		expect(MatchSummary.fromState(state, 100, 100, false, false).durationSec).toBe(0)
		expect(MatchSummary.fromState(state, 200, 100, false, false).durationSec).toBe(0)
	end)

	it("no divide por cero cuando no hubo turnos", function()
		local state = Fixtures.game({ players = 2 })
		local observations: Observations = { turns = 0, sceneSec = 0, leaders = {} }
		local summary = MatchSummary.fromState(state, 0, 100, false, false, observations)
		expect(summary.avgTurnSec).toBe(0)

		local withTurns: Observations = { turns = 4, sceneSec = 2, leaders = {} }
		expect(MatchSummary.fromState(state, 0, 100, false, false, withTurns).avgTurnSec).toBe(25)
	end)

	it("el líder a mitad se compara en la ronda impar central", function()
		local state = Fixtures.game({ players = 2 })
		local winner = winnerOf(state)
		local other: PlayerId = if state.players[1].id == winner
			then state.players[2].id
			else state.players[1].id
		-- Cinco rondas: la del medio es ceil(5 / 2) = 3.
		local wins: Observations = {
			turns = 1,
			sceneSec = 0,
			leaders = { [1] = other, [2] = other, [3] = winner, [4] = other, [5] = other },
		}
		expect(MatchSummary.fromState(state, 0, 10, false, false, wins).leaderAtHalfWon).toBe(true)
		local loses: Observations = {
			turns = 1,
			sceneSec = 0,
			leaders = { [1] = winner, [2] = winner, [3] = other, [4] = winner, [5] = winner },
		}
		expect(MatchSummary.fromState(state, 0, 10, false, false, loses).leaderAtHalfWon).toBe(false)
	end)

	it("el líder a mitad se compara en la ronda par central", function()
		local state = Fixtures.game({ players = 2 })
		local winner = winnerOf(state)
		local other: PlayerId = if state.players[1].id == winner
			then state.players[2].id
			else state.players[1].id
		-- Cuatro rondas: la del medio es ceil(4 / 2) = 2.
		local wins: Observations = {
			turns = 1,
			sceneSec = 0,
			leaders = { [1] = other, [2] = winner, [3] = other, [4] = other },
		}
		expect(MatchSummary.fromState(state, 0, 10, false, false, wins).leaderAtHalfWon).toBe(true)
		local loses: Observations = {
			turns = 1,
			sceneSec = 0,
			leaders = { [1] = winner, [2] = other, [3] = winner, [4] = winner },
		}
		expect(MatchSummary.fromState(state, 0, 10, false, false, loses).leaderAtHalfWon).toBe(false)
	end)

	it("el líder a mitad usa la última ronda empezada, no el número de rondas", function()
		local state = Fixtures.game({ players = 2 })
		local winner = winnerOf(state)
		local other: PlayerId = if state.players[1].id == winner
			then state.players[2].id
			else state.players[1].id
		-- El motor no emite RoundStarted de la ronda 1: las claves reales empiezan en 2. Con cuatro
		-- rondas jugadas, la mitad es ceil(4 / 2) = 2, y esa clave existe.
		local observations: Observations = {
			turns = 1,
			sceneSec = 0,
			leaders = { [2] = winner, [3] = other, [4] = other },
		}
		expect(MatchSummary.fromState(state, 0, 10, false, false, observations).leaderAtHalfWon).toBe(true)
	end)

	it("sin líder en la ronda central no se inventa una victoria", function()
		local state = Fixtures.game({ players = 2 })
		local observations: Observations = { turns = 0, sceneSec = 0, leaders = {} }
		expect(MatchSummary.fromState(state, 0, 10, false, false, observations).leaderAtHalfWon).toBe(false)
	end)

	it("suma las cartas jugadas por todos los jugadores", function()
		local state = Fixtures.game({ players = 3 })
		state.stats[PLAYER_IDS[1]].cardsPlayed = 3
		state.stats[PLAYER_IDS[2]].cardsPlayed = 1
		local summary = MatchSummary.fromState(state, 0, 10, false, false)
		expect(summary.cardsPlayed).toBe(4)
		-- Un contador ausente cuenta cero, no rompe el resumen.
		expect(state.stats[PLAYER_IDS[3]].cardsPlayed == nil).toBe(true)
	end)

	it("dos partidas iguales reciben ids distintos y sin datos personales", function()
		local state = Fixtures.game({ players = 2 })
		local first = MatchSummary.fromState(state, 100, 200, false, false)
		local second = MatchSummary.fromState(state, 100, 200, false, false)
		expect(first.id ~= second.id).toBe(true)
		-- Solo hexadecimal y largo fijo: ni el reloj (`os.clock`/`time`) ni los userId caben ahí.
		expect(string.match(first.id, "^%x+$")).toBe(first.id)
		expect(#first.id).toBe(16)
		expect(string.find(first.id, PLAYER_IDS[1], 1, true) == nil).toBe(true)
		expect(string.find(first.id, PLAYER_IDS[2], 1, true) == nil).toBe(true)
	end)

	it("la revancha se marca sin tocar el resto del resumen", function()
		local state = Fixtures.game({ players = 2 })
		expect(MatchSummary.fromState(state, 0, 10, true, false).rematch).toBe(true)
		expect(MatchSummary.fromState(state, 0, 10, false, false).rematch).toBe(false)
	end)

	it("un abandono también deja resumen, y no cuenta como terminado", function()
		local state = Fixtures.game({ players = 2 })
		local observations: Observations = { turns = 7, sceneSec = 12.5, leaders = { [2] = PLAYER_IDS[1] } }
		local abandoned = MatchSummary.fromState(state, 100, 160.5, false, true, observations)
		expect(abandoned.players).toBe(2)
		expect(abandoned.finished).toBe(false)
		expect(abandoned.durationSec).toBe(60.5)
		expect(abandoned.avgTurnSec).toBe(60.5 / 7)
		expect(abandoned.sceneSec).toBe(12.5)
		-- Y el informe lo ve: suma en el total de partidas y no en las terminadas.
		local report = MatchSummary.report({ abandoned })
		expect(report.matches).toBe(1)
		expect(report.finished).toBe(0)
		expect(report.finishedRate).toBe(0)
	end)
end)

describe("MatchSummary.report", function()
	it("sin resúmenes devuelve ceros y no divide por cero", function()
		local report = MatchSummary.report({})
		local expected: Report = {
			matches = 0,
			ignored = 0,
			finished = 0,
			finishedRate = 0,
			firstMatches = 0,
			rematches = 0,
			rematchRate = 0,
			durationSamples = 0,
			averageDurationSec = 0,
			leaderSamples = 0,
			leadersWon = 0,
			leaderAtHalfRate = 0,
		}
		expect(report).toEqual(expected)
	end)

	it("calcula los cuatro criterios con respuestas conocidas", function()
		local summaries = {
			summaryOf({ durationSec = 600, finished = true, leaderAtHalfWon = true }),
			summaryOf({ durationSec = 1200, finished = true }),
			summaryOf({ durationSec = 1800, finished = true, rematch = true }),
			summaryOf({ durationSec = 300, finished = false }),
		}
		local report = MatchSummary.report(summaries)
		expect(report.matches).toBe(4)
		expect(report.finished).toBe(3)
		expect(report.finishedRate).toBe(0.75)
		expect(report.firstMatches).toBe(3)
		expect(report.rematches).toBe(1)
		expect(report.rematchRate).toBe(1 / 3)
		expect(report.durationSamples).toBe(3)
		expect(report.averageDurationSec).toBe(1200)
		expect(report.leaderSamples).toBe(3)
		expect(report.leadersWon).toBe(1)
		expect(report.leaderAtHalfRate).toBe(1 / 3)
		expect(report.ignored).toBe(0)
	end)

	it("dos de cinco líderes a mitad ganaron: 0.4", function()
		local summaries = {
			summaryOf({ leaderAtHalfWon = true }),
			summaryOf({ leaderAtHalfWon = true }),
			summaryOf({}),
			summaryOf({}),
			summaryOf({}),
		}
		local report = MatchSummary.report(summaries)
		expect(report.leaderSamples).toBe(5)
		expect(report.leadersWon).toBe(2)
		expect(report.leaderAtHalfRate).toBe(0.4)
	end)

	it("ignora las partidas Sin Fin por completo", function()
		local rounds = {
			summaryOf({ durationSec = 900, finished = true, leaderAtHalfWon = true }),
			summaryOf({ durationSec = 1800, finished = false }),
			summaryOf({ durationSec = 1500, finished = true, rematch = true }),
		}
		local mixed = table.clone(rounds)
		table.insert(mixed, summaryOf({ endMode = "Endless", finished = true, leaderAtHalfWon = true }))
		table.insert(
			mixed,
			summaryOf({ endMode = "Endless", finished = true, rematch = true, durationSec = 9999 })
		)
		table.insert(mixed, summaryOf({ endMode = "Endless", finished = false, durationSec = 5000 }))
		local roundsReport = MatchSummary.report(rounds)
		local mixedReport = MatchSummary.report(mixed)
		-- Los cuatro criterios dan lo mismo; lo único que cambia es la cuenta de ignoradas.
		expect(mixedReport.matches).toBe(roundsReport.matches)
		expect(mixedReport.finished).toBe(roundsReport.finished)
		expect(mixedReport.finishedRate).toBe(roundsReport.finishedRate)
		expect(mixedReport.firstMatches).toBe(roundsReport.firstMatches)
		expect(mixedReport.rematches).toBe(roundsReport.rematches)
		expect(mixedReport.rematchRate).toBe(roundsReport.rematchRate)
		expect(mixedReport.durationSamples).toBe(roundsReport.durationSamples)
		expect(mixedReport.averageDurationSec).toBe(roundsReport.averageDurationSec)
		expect(mixedReport.leaderSamples).toBe(roundsReport.leaderSamples)
		expect(mixedReport.leadersWon).toBe(roundsReport.leadersWon)
		expect(mixedReport.leaderAtHalfRate).toBe(roundsReport.leaderAtHalfRate)
		expect(mixedReport.ignored).toBe(3)
	end)

	it("no divide por cero si todas las partidas son revanchas", function()
		local summaries = {
			summaryOf({ rematch = true }),
			summaryOf({ rematch = true }),
		}
		local report = MatchSummary.report(summaries)
		expect(report.matches).toBe(2)
		expect(report.firstMatches).toBe(0)
		expect(report.rematches).toBe(2)
		expect(report.rematchRate).toBe(0)
	end)

	it("sin partidas terminadas la duración y el líder quedan en cero", function()
		local summaries = {
			summaryOf({ finished = false, durationSec = 300 }),
			summaryOf({ finished = false, durationSec = 900 }),
		}
		local report = MatchSummary.report(summaries)
		expect(report.finished).toBe(0)
		expect(report.finishedRate).toBe(0)
		expect(report.durationSamples).toBe(0)
		expect(report.averageDurationSec).toBe(0)
		expect(report.leaderSamples).toBe(0)
		expect(report.leaderAtHalfRate).toBe(0)
	end)
end)

--!strict
-- Simulación de partidas completas: la prueba de aceptación de la fase 02. Los invariantes se
-- comprueban dentro de Sim.play, después de cada acción resuelta; aquí solo se exige que todas
-- las partidas terminen, que el resultado sea determinista y que los eventos cuadren.
local Harness = require("./harness")
local Sim = require("./sim")
local Types = require("../src/shared/rules/Types")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

-- La matriz completa: 7 tamaños × 2 modos × 1000 semillas = 14 000 partidas.
local SEED_COUNT = 1000
local IDLE_SEED_COUNT = 100
-- Tipados antes de entrar en la lista: un literal de tabla ensancha los textos a `string`.
local ROUNDS: Types.EndMode = "Rounds"
local ENDLESS: Types.EndMode = "Endless"
local MODES: { Types.EndMode } = { ROUNDS, ENDLESS }

-- Opciones con tipo explícito: un literal de tabla ensancha los textos y dejaría de encajar con
-- el contrato de Sim.play.
local function botCase(players: number, seed: number, mode: Types.EndMode): Sim.PlayOptions
	local opts: Sim.PlayOptions = { players = players, seed = seed, endMode = mode }
	return opts
end

local function idleCase(players: number, seed: number): Sim.PlayOptions
	local opts: Sim.PlayOptions = { players = players, seed = seed, idle = true, endMode = "Rounds" }
	return opts
end

-- Juega y falla nombrando el caso: si el tope de seguridad se alcanza, la partida no terminó.
local function playOrFail(opts: Sim.PlayOptions): Sim.SimResult
	local result = Sim.play(opts)
	if not result.finished then
		error(
			`la partida no terminó (jugadores={opts.players}, semilla={opts.seed}, modo={opts.endMode}, turnos={result.turns})`,
			2
		)
	end
	return result
end

describe("Sim.play: matriz completa con bots", function()
	for players = 2, 8 do
		for modeIndex = 1, #MODES do
			local mode: Types.EndMode = MODES[modeIndex]
			it(`termina las 1000 partidas de {players} jugadores en modo {mode}`, function()
				for seed = 1, SEED_COUNT do
					playOrFail(botCase(players, seed, mode))
				end
			end)
		end
	end
end)

describe("Sim.play sin decisiones", function()
	-- En `Endless` una partida sin decisiones no puede terminar en la fase 02: nadie compra, no
	-- hay renta y ningún jugador pierde efectivo (la Salida solo suma), así que la regla del
	-- único activo es inalcanzable. El modo Sin Fin se cubre en la matriz con bots; aquí se
	-- comprueba que en Rondas el tiempo agotado basta para cerrar la partida.
	for players = 2, 8 do
		it(`termina con tiempo agotado 100 partidas de {players} jugadores`, function()
			for seed = 1, IDLE_SEED_COUNT do
				playOrFail(idleCase(players, seed))
			end
		end)
	end
end)

describe("Sim.play: determinismo", function()
	it("la misma semilla produce el mismo resultado", function()
		for modeIndex = 1, #MODES do
			local mode: Types.EndMode = MODES[modeIndex]
			for _, players in { 2, 5, 8 } do
				local opts = botCase(players, 7, mode)
				expect(Sim.play(opts)).toEqual(Sim.play(opts))
			end
		end
	end)

	it("la misma semilla produce el mismo resultado sin decisiones", function()
		local opts = idleCase(4, 3)
		expect(Sim.play(opts)).toEqual(Sim.play(opts))
	end)
end)

describe("Sim.play: eventos", function()
	it("cuenta GameEnded una sola vez y al menos un RoundStarted", function()
		for modeIndex = 1, #MODES do
			local result = playOrFail(botCase(4, 1, MODES[modeIndex]))
			expect(result.events.GameEnded).toBe(1)
			expect((result.events.RoundStarted or 0) >= 1).toBe(true)
			expect(result.turns > 0).toBe(true)
			expect(type(result.leaderAtHalf)).toBe("string")
		end
	end)
end)

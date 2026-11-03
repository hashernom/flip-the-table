--!strict
-- Simulación de partidas completas: la prueba de aceptación de la fase 02, ampliada en la Tarea 10
-- para dirigir todas las fases de la fase 03 (borrador, reacciones, Mercado, Duelo, Tribunal y
-- espectros). Los invariantes se comprueban dentro de Sim.play después de cada acción resuelta;
-- aquí se exige que todas las partidas terminen, que el resultado sea determinista, que se usen
-- todas las cartas y perks y que cada fase nueva llegue a jugarse en la matriz.
local CardsConfig = require("../src/shared/config/Cards")
local Harness = require("./harness")
local PerksConfig = require("../src/shared/config/Perks")
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

-- Totales de toda la matriz. La cobertura se comprueba al final, cuando ya se jugaron las 14 000
-- partidas; así cada partida se simula una sola vez.
local usedCards: { [string]: number } = {}
local usedPerks: { [string]: number } = {}
local usedPerkUses: { [string]: number } = {}
local eventCounts: { [string]: number } = {}

local function addCounts(target: { [string]: number }, source: { [string]: number })
	for key, count in source do
		target[key] = (target[key] or 0) + count
	end
end

local function accumulate(result: Sim.SimResult)
	addCounts(usedCards, result.cardsPlayed)
	addCounts(usedPerks, result.perksDrafted)
	addCounts(usedPerkUses, result.perkUses)
	addCounts(eventCounts, result.events)
end

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

-- Nombra todos los ids sin uso para que un fallo de cobertura diga qué falta, no solo un número.
local function missing(all: { any }, counts: { [string]: number }): { string }
	local names: { string } = {}
	for _, definition in all do
		if (counts[definition.id] or 0) == 0 then
			table.insert(names, definition.id)
		end
	end
	return names
end

describe("Sim.play: resultado ampliado", function()
	it("expone cardsPlayed, perksDrafted y leaderAtHalfWon", function()
		local result = playOrFail(botCase(4, 1, ROUNDS))
		expect(type(result.cardsPlayed)).toBe("table")
		expect(type(result.perksDrafted)).toBe("table")
		expect(type(result.perkUses)).toBe("table")
		expect(type(result.leaderAtHalfWon)).toBe("boolean")
		expect(result.leaderAtHalfWon).toBe(result.winner == result.leaderAtHalf)
		-- El contador de perks viene del borrador: en toda partida se elige al menos uno.
		expect((result.events.PerkDrafted or 0) > 0).toBe(true)
	end)
end)

describe("Sim.play: tope de seguridad", function()
	it("devuelve finished = false en vez de dar la partida por terminada", function()
		-- Tope de una acción: la partida se corta en el primer borrador y el resultado debe ser
		-- explícitamente incompleto, para que la matriz no pueda pasar por accidente.
		local opts: Sim.PlayOptions = {
			players = 2,
			seed = 1,
			endMode = ROUNDS,
			maxActions = 1,
		}
		local result = Sim.play(opts)
		expect(result.finished).toBe(false)
		expect(type(result.leaderAtHalfWon)).toBe("boolean")
		expect(type(result.cardsPlayed)).toBe("table")
		expect(type(result.perkUses)).toBe("table")
	end)
end)

describe("Sim.play: matriz completa con bots", function()
	for players = 2, 8 do
		for modeIndex = 1, #MODES do
			local mode: Types.EndMode = MODES[modeIndex]
			it(`termina las 1000 partidas de {players} jugadores en modo {mode}`, function()
				for seed = 1, SEED_COUNT do
					accumulate(playOrFail(botCase(players, seed, mode)))
				end
			end)
		end
	end
end)

describe("Sim.play: cobertura de la matriz", function()
	it("usa las 20 cartas al menos una vez", function()
		local names = missing(CardsConfig.all, usedCards)
		if #names > 0 then
			error(`cartas que la simulación nunca jugó: {table.concat(names, ", ")}`, 2)
		end
		expect(#names).toBe(0)
	end)

	it("reparte los 12 perks al menos una vez", function()
		local names = missing(PerksConfig.all, usedPerks)
		if #names > 0 then
			error(`perks que la simulación nunca repartió: {table.concat(names, ", ")}`, 2)
		end
		expect(#names).toBe(0)
	end)

	it("usa los 12 perks al menos una vez (efectos reales, no solo reparto)", function()
		-- Los contadores los escribe el motor donde el efecto se aplica (Perks.recordUse). Un perk
		-- repartido pero nunca aplicado (por ejemplo, Dedos Rápidos sin RerollDie) falla aquí.
		local names = missing(PerksConfig.all, usedPerkUses)
		if #names > 0 then
			error(`perks que la simulación nunca aplicó: {table.concat(names, ", ")}`, 2)
		end
		expect(#names).toBe(0)
	end)

	it("juega todas las fases nuevas", function()
		-- Cada frase de la fase 03 deja un evento o una carta que solo puede salir jugándola.
		expect((eventCounts.PerkDrafted or 0) > 0).toBe(true)
		expect((eventCounts.CardBlocked or 0) > 0).toBe(true)
		expect((usedCards.BounceRent or 0) > 0).toBe(true)
		expect((eventCounts.MarketBought or 0) > 0).toBe(true)
		expect((eventCounts.DuelResolved or 0) > 0).toBe(true)
		expect((eventCounts.PlayerArrested or 0) > 0).toBe(true)
		expect((eventCounts.TribunalVerdict or 0) > 0).toBe(true)
		expect((eventCounts.GhostActed or 0) > 0).toBe(true)
		expect((eventCounts.GhostResurrected or 0) > 0).toBe(true)
		expect((eventCounts.PactFormed or 0) > 0).toBe(true)
	end)
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

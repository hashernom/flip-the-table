--!strict
-- Premios del final (Tarea 10): Mayor Traidor, Mejor Remontada y Víctima de la Noche. Se calculan
-- sobre state.stats, se entregan solo si hay datos (máximo mayor que 0) y los empates los resuelve
-- el orden de la clasificación del motor (Score.ranking), que es un orden total y determinista.
local Awards = require("../../src/shared/rules/Awards")
local Fixtures = require("../fixtures")
local Harness = require("../harness")
local Property = require("../../src/shared/rules/Property")
local Types = require("../../src/shared/rules/Types")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function playerOf(state: Types.GameState, index: number): Types.Player
	local player = state.players[index]
	if not player then
		error(`la partida no tiene un jugador en la posición {index}`, 2)
	end
	return player
end

local function setStat(state: Types.GameState, playerId: Types.PlayerId, key: string, value: number)
	state.stats[playerId][key] = value
end

-- Empata el efectivo de todos para que la clasificación dependa solo de lo que fije cada prueba.
local function levelCash(state: Types.GameState)
	for _, player in state.players do
		player.cash = 1000
	end
end

describe("Awards.compute", function()
	it("no entrega ningún premio cuando no hay datos", function()
		local state = Fixtures.game({ players = 4 })
		expect(Awards.compute(state)).toEqual({})
	end)

	it("entrega los tres premios a partir de sus contadores", function()
		local state = Fixtures.game({ players = 4 })
		local first = playerOf(state, 1).id
		local second = playerOf(state, 2).id
		local third = playerOf(state, 3).id
		setStat(state, first, "pactsBroken", 3)
		setStat(state, second, "comebackRounds", 2)
		setStat(state, third, "rentsPaid", 5)

		expect(Awards.compute(state)).toEqual({
			{ id = "MostTreacherous", playerId = first },
			{ id = "BestComeback", playerId = second },
			{ id = "VictimOfTheNight", playerId = third },
		})
	end)

	it("omite solo el premio cuyo máximo sigue en 0", function()
		local state = Fixtures.game({ players = 3 })
		local traitor = playerOf(state, 1).id
		setStat(state, traitor, "pactsBroken", 2)
		-- Mejor Remontada y Víctima de la Noche se quedan sin datos: no se entregan.
		expect(Awards.compute(state)).toEqual({ { id = "MostTreacherous", playerId = traitor } })
	end)

	it("un mismo jugador puede llevarse varios premios", function()
		local state = Fixtures.game({ players = 3 })
		local star = playerOf(state, 2).id
		setStat(state, star, "pactsBroken", 1)
		setStat(state, star, "rentsPaid", 4)
		setStat(state, playerOf(state, 1).id, "comebackRounds", 1)
		expect(Awards.compute(state)).toEqual({
			{ id = "MostTreacherous", playerId = star },
			{ id = "BestComeback", playerId = playerOf(state, 1).id },
			{ id = "VictimOfTheNight", playerId = star },
		})
	end)

	it("desempata con el orden de la clasificación", function()
		local state = Fixtures.game({ players = 3 })
		local leader = playerOf(state, 1)
		local second = playerOf(state, 2)
		setStat(state, leader.id, "pactsBroken", 2)
		setStat(state, second.id, "pactsBroken", 2)
		levelCash(state)
		-- El líder de la clasificación va primero en el orden de desempate.
		leader.cash = 2000
		second.cash = 1000
		expect(Awards.compute(state)[1]).toEqual({ id = "MostTreacherous", playerId = leader.id })

		-- Al invertir el patrimonio cambia el orden y, con él, el desempate.
		leader.cash = 1000
		second.cash = 2000
		expect(Awards.compute(state)[1]).toEqual({ id = "MostTreacherous", playerId = second.id })
	end)

	it("no muta las estadísticas ni la clasificación", function()
		local state = Fixtures.game({ players = 3 })
		local player = playerOf(state, 1).id
		setStat(state, player, "rentsPaid", 7)
		local before = table.clone(state.stats)
		local first = Awards.compute(state)
		local second = Awards.compute(state)
		expect(second).toEqual(first)
		expect(state.stats).toEqual(before)
	end)

	it("VictimOfTheNight sale de una renta pagada de verdad", function()
		local state = Fixtures.game({ players = 3 })
		local owner = playerOf(state, 1)
		local payer = playerOf(state, 2)
		local index = Fixtures.squareOf(state, "Property")
		Fixtures.give(state, owner.id, index)

		Property.payRent(state, payer.id, index)

		expect(Awards.compute(state)).toEqual({
			{ id = "VictimOfTheNight", playerId = payer.id },
		})
	end)
end)

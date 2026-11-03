--!strict
-- Pruebas de las reglas de la revancha: cuándo se puede empezar otra partida y quién la juega.
-- Las reglas son puras (ni game, ni reloj, ni task): el servicio les pasa los votos y los presentes,
-- aplica el resultado y es él quien cierra la espera a los Scenes.rematchSec. Cada prueba parte de
-- userIds numéricos, como manda el contrato de identidad de contracts.md.
local Harness = require("../harness")
local Lobby = require("../../src/shared/config/Lobby")
local RematchRules = require("../../src/server/match/RematchRules")
local Scenes = require("../../src/shared/config/Scenes")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

-- Ocho presentes, el tamaño máximo de una partida (Boards.forPlayerCount). Los ids son arbitrarios
-- y no se convierten a texto en ningún momento: la revancha habla de userId numérico.
local EIGHT: { number } = { 101, 202, 303, 404, 505, 606, 707, 808 }

-- Copia de los votos: se compara con `toEqual` después de cada regla. Si una regla mutara la tabla
-- recibida, la copia y el valor cambiarían juntos y la prueba lo delataría.
local function copyVotes(votes: { [number]: boolean }): { [number]: boolean }
	return table.clone(votes)
end

-- Copia densa de la lista de presentes, sin compartir la tabla.
local function copyPresent(present: { number }): { number }
	return table.clone(present)
end

-- Votos de una partida: `true` para quien aceptó y `false` para el resto de los presentes. Es el
-- caso «todos han votado», que es el que decide de inmediato; para el caso «faltan votos» cada
-- prueba arma su tabla a mano.
local function votesFor(present: { number }, accepters: { number }): { [number]: boolean }
	local votes: { [number]: boolean } = {}
	for _, userId in present do
		votes[userId] = false
	end
	for _, userId in accepters do
		votes[userId] = true
	end
	return votes
end

local function byUserId(accepted: { number }, userId: number): boolean
	return table.find(accepted, userId) ~= nil
end

describe("RematchRules.accepted", function()
	it("con ocho de ocho devuelve los ocho, en el orden de los presentes", function()
		local votes = votesFor(EIGHT, EIGHT)
		expect(RematchRules.accepted(votes, EIGHT)).toEqual(EIGHT)
	end)

	it("con dos de ocho devuelve solo esos dos", function()
		local accepters = { 202, 707 }
		local votes = votesFor(EIGHT, accepters)
		expect(RematchRules.accepted(votes, EIGHT)).toEqual(accepters)
	end)

	it("ignora el voto de quien no está presente", function()
		local votes = votesFor(EIGHT, { 202 })
		votes[999] = true
		local accepted = RematchRules.accepted(votes, EIGHT)
		expect(#accepted).toBe(1)
		expect(accepted[1]).toBe(202)
		expect(byUserId(accepted, 999)).toBe(false)
	end)

	it("quien se fue deja de contar aunque su voto siga en la tabla", function()
		local votes = votesFor(EIGHT, { 101, 202, 303 })
		expect(RematchRules.accepted(votes, { 101, 303 })).toEqual({ 101, 303 })
	end)

	it("la lista sigue el orden de los presentes, no el de la tabla de votos", function()
		local present = { 303, 101, 202 }
		local votes: { [number]: boolean } = { [303] = true, [101] = true, [202] = true }
		expect(RematchRules.accepted(votes, present)).toEqual({ 303, 101, 202 })
	end)
end)

describe("RematchRules.resolve", function()
	it("con ocho de ocho aceptando, empieza con todos", function()
		local votes = votesFor(EIGHT, EIGHT)
		expect(RematchRules.resolve(votes, EIGHT)).toBe("Start")
		expect(RematchRules.accepted(votes, EIGHT)).toEqual(EIGHT)
	end)

	it("con dos aceptando y el resto en contra, empieza con esos dos", function()
		local accepters = { 202, 707 }
		local votes = votesFor(EIGHT, accepters)
		expect(RematchRules.resolve(votes, EIGHT)).toBe("Start")
		expect(RematchRules.accepted(votes, EIGHT)).toEqual(accepters)
	end)

	it("con una sola aceptación entre ocho no empieza", function()
		local votes = votesFor(EIGHT, { 404 })
		expect(RematchRules.resolve(votes, EIGHT)).toBe("NotEnough")
		-- `accepted` sigue diciendo quién aceptó; no empezar es decisión del servicio.
		expect(RematchRules.accepted(votes, EIGHT)).toEqual({ 404 })
	end)

	it("nadie ha votado todavía: espera", function()
		expect(RematchRules.resolve({}, EIGHT)).toBe("Wait")
	end)

	it("algunos han votado y otros no: espera, y la lista solo tiene a los que aceptaron", function()
		local votes: { [number]: boolean } = { [101] = true, [202] = true, [303] = false }
		expect(RematchRules.resolve(votes, EIGHT)).toBe("Wait")
		expect(RematchRules.accepted(votes, EIGHT)).toEqual({ 101, 202 })
	end)

	it("un voto en contra con el resto sin votar tampoco decide: espera", function()
		expect(RematchRules.resolve({ [101] = false }, EIGHT)).toBe("Wait")
	end)

	it("todos los presentes votan en contra: no hay revancha", function()
		local votes = votesFor(EIGHT, {})
		expect(RematchRules.resolve(votes, EIGHT)).toBe("NotEnough")
		expect(RematchRules.accepted(votes, EIGHT)).toEqual({})
	end)

	it("un voto de quien no está presente no cuenta para empezar ni aparece en accepted", function()
		-- Solo votó alguien ajeno a la mesa: nadie de los presentes ha votado.
		local votes: { [number]: boolean } = { [999] = true }
		expect(RematchRules.resolve(votes, EIGHT)).toBe("Wait")
		expect(RematchRules.accepted(votes, EIGHT)).toEqual({})

		-- Con todos los presentes en contra, un sí ajeno no cambia el resultado.
		local allAgainst = votesFor(EIGHT, {})
		allAgainst[999] = true
		expect(RematchRules.resolve(allAgainst, EIGHT)).toBe("NotEnough")
		expect(RematchRules.accepted(allAgainst, EIGHT)).toEqual({})

		-- Con unos presentes a favor y otros sin votar, el ajeno no completa la lista.
		local partial: { [number]: boolean } = { [101] = true, [999] = true }
		expect(RematchRules.resolve(partial, EIGHT)).toBe("Wait")
		expect(RematchRules.accepted(partial, EIGHT)).toEqual({ 101 })
	end)

	it("quien se fue después de votar no bloquea el comienzo", function()
		local votes: { [number]: boolean } = { [101] = true, [202] = true, [303] = true }
		-- 202 se fue sin votar: con él en la mesa faltan votos.
		local waiting: { [number]: boolean } = { [101] = true, [303] = true }
		expect(RematchRules.resolve(waiting, { 101, 202, 303 })).toBe("Wait")
		-- Se fue: ya no está presente, así que los tres que quedan (dos) han votado.
		expect(RematchRules.resolve(waiting, { 101, 303 })).toBe("Start")
		expect(RematchRules.accepted(waiting, { 101, 303 })).toEqual({ 101, 303 })

		-- Si el que se va había aceptado, su voto tampoco se lleva la partida por delante.
		expect(RematchRules.resolve(votes, { 101, 202, 303 })).toBe("Start")
		expect(RematchRules.accepted(votes, { 101, 303 })).toEqual({ 101, 303 })
	end)

	it("con un solo presente que acepta no hay partida", function()
		expect(RematchRules.resolve({ [101] = true }, { 101 })).toBe("NotEnough")
		expect(RematchRules.accepted({ [101] = true }, { 101 })).toEqual({ 101 })
	end)

	it("con una mesa vacía no hay revancha", function()
		expect(RematchRules.resolve({}, {})).toBe("NotEnough")
		expect(RematchRules.accepted({}, {})).toEqual({})
	end)

	it("es determinista y no muta las tablas que recibe", function()
		local votes = votesFor(EIGHT, { 202, 707 })
		votes[999] = true
		local present = copyPresent(EIGHT)
		local votesBefore = copyVotes(votes)
		local presentBefore = copyPresent(present)

		local first = RematchRules.resolve(votes, present)
		local firstAccepted = RematchRules.accepted(votes, present)
		local second = RematchRules.resolve(votes, present)
		local secondAccepted = RematchRules.accepted(votes, present)

		expect(first).toBe(second)
		expect(first).toBe("Start")
		expect(firstAccepted).toEqual(secondAccepted)
		expect(firstAccepted).toEqual({ 202, 707 })
		expect(votes).toEqual(votesBefore)
		expect(present).toEqual(presentBefore)
	end)

	it("accepted devuelve una lista nueva en cada llamada", function()
		local votes = votesFor(EIGHT, { 101 })
		local first = RematchRules.accepted(votes, EIGHT)
		local second = RematchRules.accepted(votes, EIGHT)
		expect(first ~= second).toBe(true)
		expect(first).toEqual(second)
	end)
end)

describe("Configuración de la revancha", function()
	it("la ventana dura 20 segundos y el mínimo es el de cualquier partida", function()
		-- El número vive en config y el servicio lo aplica; las reglas no ven el reloj.
		expect(Scenes.rematchSec).toBe(20)
		expect(Lobby.minPlayers).toBe(2)
	end)
end)

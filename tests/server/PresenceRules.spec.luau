--!strict
-- Pruebas de las reglas de presencia: quién sigue conectado, quién controla un bot y cuántos
-- tiempos agotados lleva cada asiento. Las reglas son puras y hablan de asientos, así que se
-- prueban con Lune sin game, sin task y sin partida: el servicio de presencia solo las aplica
-- (R-P10). Cada prueba parte de asientos reales del contrato `Seat` de `contracts.md`.
local Economy = require("../../src/shared/config/Economy")
local Harness = require("../harness")
local PresenceRules = require("../../src/server/match/PresenceRules")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

type Seat = PresenceRules.Seat

-- Asiento de una partida de tres: la identidad de la conexión (userId), la clave del motor
-- (playerId = tostring(userId) para la prueba), el índice en state.players y los tres campos de
-- presencia. Ninguna prueba inventa un cuarto asiento ni reutiliza una tabla entre casos.
local function seat(userId: number, index: number): Seat
	return {
		userId = userId,
		playerId = tostring(userId),
		seat = index,
		connected = true,
		bot = false,
		timeouts = 0,
	}
end

local function threeSeats(): { Seat }
	return { seat(101, 1), seat(202, 2), seat(303, 3) }
end

-- Copia profunda de la lista recibida. Se compara con `toEqual` después de cada regla: si una
-- regla mutara un asiento, la copia y el valor cambiarían juntos y la prueba lo delataría.
local function copySeats(seats: { Seat }): { Seat }
	local copy: { Seat } = {}
	for index, value in seats do
		copy[index] = {
			userId = value.userId,
			playerId = value.playerId,
			seat = value.seat,
			connected = value.connected,
			bot = value.bot,
			timeouts = value.timeouts,
		}
	end
	return copy
end

local function byUserId(seats: { Seat }, userId: number): Seat?
	for _, value in seats do
		if value.userId == userId then
			return value
		end
	end
	return nil
end

-- Asiento conocido de cada prueba. Se busca con una función que falla claro si la regla se
-- llevó por delante la lista: un nil escondido daría un error de índice poco legible.
local function seatOf(seats: { Seat }, userId: number): Seat
	local found = byUserId(seats, userId)
	if not found then
		error(`la regla perdió el asiento de {userId}`, 2)
	end
	return found
end

describe("PresenceRules", function()
	describe("onLeave", function()
		it("marca el asiento desconectado y con bot, y no toca a los demás", function()
			local seats = threeSeats()
			seatOf(seats, 202).timeouts = 1
			local before = copySeats(seats)
			local left = PresenceRules.onLeave(seats, 202)
			expect(#left).toBe(3)
			local gone = seatOf(left, 202)
			expect(gone.connected).toBe(false)
			expect(gone.bot).toBe(true)
			expect(gone.seat).toBe(2)
			-- La racha se cierra al irse: quien vuelva no hereda los tiempos de antes.
			expect(gone.timeouts).toBe(0)
			expect(seatOf(left, 101)).toEqual(before[1])
			expect(seatOf(left, 303)).toEqual(before[3])
			expect(seats).toEqual(before)
		end)

		it("devuelve una lista nueva, no la que recibió", function()
			local seats = threeSeats()
			expect(PresenceRules.onLeave(seats, 101) ~= seats).toBe(true)
		end)

		it("no cambia nada si el userId no está en la mesa", function()
			local seats = threeSeats()
			local before = copySeats(seats)
			expect(PresenceRules.onLeave(seats, 999)).toEqual(before)
			expect(seats).toEqual(before)
		end)
	end)

	describe("onReturn", function()
		it("devuelve el control y conserva asiento y tiempos agotados", function()
			local seats = threeSeats()
			local away = seatOf(seats, 202)
			away.connected = false
			away.bot = true
			away.timeouts = 1
			local before = copySeats(seats)
			local found, restored = PresenceRules.onReturn(seats, 202)
			expect(found).toBe(true)
			local back = seatOf(restored, 202)
			expect(back.connected).toBe(true)
			expect(back.bot).toBe(false)
			expect(back.seat).toBe(2)
			expect(back.timeouts).toBe(1)
			expect(seatOf(restored, 101)).toEqual(before[1])
			expect(seatOf(restored, 303)).toEqual(before[3])
			expect(seats).toEqual(before)
		end)

		it("devuelve false si el userId nunca estuvo en la partida", function()
			local seats = threeSeats()
			local before = copySeats(seats)
			local found, restored = PresenceRules.onReturn(seats, 999)
			expect(found).toBe(false)
			expect(restored).toEqual(before)
			expect(seats).toEqual(before)
		end)

		it("quien se fue después de un tiempo agotado necesita dos más al volver", function()
			local seats = PresenceRules.onTimeout(threeSeats(), "101")
			expect(seatOf(seats, 101).timeouts).toBe(1)
			local left = PresenceRules.onLeave(seats, 101)
			expect(seatOf(left, 101).timeouts).toBe(0)
			local found, back = PresenceRules.onReturn(left, 101)
			expect(found).toBe(true)
			expect(seatOf(back, 101).timeouts).toBe(0)
			local once = PresenceRules.onTimeout(back, "101")
			expect(seatOf(once, 101).bot).toBe(false)
			local twice = PresenceRules.onTimeout(once, "101")
			expect(seatOf(twice, 101).bot).toBe(true)
		end)
	end)

	describe("onTimeout", function()
		it("un solo tiempo agotado no activa el bot", function()
			local seats = threeSeats()
			local before = copySeats(seats)
			local timedOut = PresenceRules.onTimeout(seats, "101")
			local value = seatOf(timedOut, 101)
			expect(value.timeouts).toBe(1)
			expect(value.bot).toBe(false)
			expect(seatOf(timedOut, 202)).toEqual(before[2])
			expect(seats).toEqual(before)
		end)

		it("dos tiempos agotados seguidos activan el bot", function()
			local seats = threeSeats()
			local first = PresenceRules.onTimeout(seats, "101")
			local second = PresenceRules.onTimeout(first, "101")
			local value = seatOf(second, 101)
			expect(value.timeouts).toBe(Economy.bot.timeoutsToControl)
			expect(value.bot).toBe(true)
			expect(seatOf(second, 101).connected).toBe(true)
		end)

		it("un tiempo agotado de otro asiento no activa el bot", function()
			local seats = PresenceRules.onTimeout(threeSeats(), "101")
			local other = PresenceRules.onTimeout(seats, "202")
			other = PresenceRules.onTimeout(other, "202")
			expect(seatOf(other, 101).bot).toBe(false)
			expect(seatOf(other, 101).timeouts).toBe(1)
			expect(seatOf(other, 202).bot).toBe(true)
		end)

		it("no muta la lista que recibe", function()
			local seats = threeSeats()
			local before = copySeats(seats)
			PresenceRules.onTimeout(seats, "101")
			expect(seats).toEqual(before)
		end)
	end)

	describe("onAction", function()
		it("cualquier acción pone el contador a cero y quita el bot", function()
			local seats = threeSeats()
			local value = seatOf(seats, 101)
			value.bot = true
			value.timeouts = Economy.bot.timeoutsToControl
			local before = copySeats(seats)
			local played = PresenceRules.onAction(seats, "101")
			local back = seatOf(played, 101)
			expect(back.timeouts).toBe(0)
			expect(back.bot).toBe(false)
			expect(seatOf(played, 202)).toEqual(before[2])
			expect(seats).toEqual(before)
		end)

		it("no muta la lista que recibe", function()
			local seats = threeSeats()
			local before = copySeats(seats)
			PresenceRules.onAction(seats, "202")
			expect(seats).toEqual(before)
		end)
	end)

	describe("consultas", function()
		it("isBotControlled refleja el asiento y es false para un playerId desconocido", function()
			local seats = threeSeats()
			expect(PresenceRules.isBotControlled(seats, "202")).toBe(false)
			seatOf(seats, 202).bot = true
			expect(PresenceRules.isBotControlled(seats, "202")).toBe(true)
			expect(PresenceRules.isBotControlled(seats, "999")).toBe(false)
		end)

		it("isSeated reconoce al jugador por su userId, no por su playerId", function()
			local seats = threeSeats()
			expect(PresenceRules.isSeated(seats, 202)).toBe(true)
			expect(PresenceRules.isSeated(seats, 999)).toBe(false)
		end)

		it("hasHumans distingue una mesa sin nadie conectado", function()
			local seats = threeSeats()
			expect(PresenceRules.hasHumans(seats)).toBe(true)
			local gone = seats
			for _, value in gone do
				value.connected = false
				value.bot = true
			end
			expect(PresenceRules.hasHumans(gone)).toBe(false)
			local one = threeSeats()
			seatOf(one, 101).connected = false
			seatOf(one, 303).connected = false
			expect(PresenceRules.hasHumans(one)).toBe(true)
		end)

		it("una mesa sin asientos no tiene humanos", function()
			expect(PresenceRules.hasHumans({})).toBe(false)
		end)
	end)
end)

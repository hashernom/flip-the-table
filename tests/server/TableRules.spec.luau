--!strict
-- Mesas del lobby provisional: cuenta atrás, entradas, salidas y mesa llena.
local Harness = require("../harness")
local Lobby = require("../../src/shared/config/Lobby")
local LobbyPark = require("../../src/shared/config/LobbyPark")
local TableRules = require("../../src/server/lobby/TableRules")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

describe("TableRules", function()
	it("con un solo jugador no cuenta; con dos empieza la cuenta", function()
		local t = TableRules.new("Mesa1", 4)
		expect(TableRules.sit(t, 1, 0)).toBe(true)
		expect(t.startsAt).toBe(nil)
		expect(TableRules.label(t, 0)).toBe("1/4 · Falta 1 jugador")
		TableRules.sit(t, 2, 1)
		expect(t.startsAt).toBe(1 + Lobby.tableCountdownSec)
		expect(TableRules.ready(t, 1 + Lobby.tableCountdownSec - 0.1)).toBe(false)
		expect(TableRules.ready(t, 1 + Lobby.tableCountdownSec)).toBe(true)
	end)

	it("quien llega tarde alarga un poco la cuenta y la mesa llena la acorta", function()
		local t = TableRules.new("Mesa1", 4)
		TableRules.sit(t, 1, 0)
		TableRules.sit(t, 2, 0)
		TableRules.sit(t, 3, Lobby.tableCountdownSec - 1)
		expect(t.startsAt).toBe(Lobby.tableCountdownSec - 1 + Lobby.tableJoinGraceSec)
		TableRules.sit(t, 4, Lobby.tableCountdownSec)
		expect(t.startsAt).toBe(Lobby.tableCountdownSec + Lobby.tableFullSec)
		expect(TableRules.sit(t, 5, Lobby.tableCountdownSec)).toBe(false)
	end)

	it("si se levantan y queda uno, la cuenta se para", function()
		local t = TableRules.new("Mesa1", 6)
		TableRules.sit(t, 1, 0)
		TableRules.sit(t, 2, 0)
		TableRules.leave(t, 2, 3)
		expect(t.startsAt).toBe(nil)
		expect(TableRules.ready(t, 100)).toBe(false)
		expect(TableRules.sit(t, 1, 4)).toBe(false)
	end)

	it("mientras arranca no entra nadie, y tras un fallo vuelve a esperar", function()
		local t = TableRules.new("Mesa1", 4)
		TableRules.sit(t, 1, 0)
		TableRules.sit(t, 2, 0)
		t.starting = true
		expect(TableRules.sit(t, 3, 1)).toBe(false)
		expect(TableRules.ready(t, 100)).toBe(false)
		TableRules.reset(t, 50)
		expect(t.starting).toBe(false)
		expect(t.startsAt).toBe(50 + Lobby.tableCountdownSec)
	end)
end)

describe("LobbyPark", function()
	it("hay mesas de 4, 6 y 8 puestos y ninguna pisa la fuente ni a otra", function()
		local tables = LobbyPark.tables()
		local sizes: { [number]: boolean } = {}
		for i, a in tables do
			sizes[a.seats] = true
			local ra = LobbyPark.seatRadius(a.seats) + 2
			expect(math.sqrt(a.x * a.x + a.z * a.z) - ra > LobbyPark.FOUNTAIN_RADIUS).toBe(true)
			expect(math.abs(a.x) + ra < LobbyPark.PARK_HALF and math.abs(a.z) + ra < LobbyPark.PARK_HALF).toBe(
				true
			)
			for j, b in tables do
				if i < j then
					local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
					expect(d > ra + LobbyPark.seatRadius(b.seats) + 2).toBe(true)
				end
			end
		end
		expect(sizes[4] and sizes[6] and sizes[8]).toBe(true)
	end)

	it("cada mesa tiene tantos puestos como dice, mirando a su centro", function()
		for _, t in LobbyPark.tables() do
			local seats = LobbyPark.seatsOf(t)
			expect(#seats).toBe(t.seats)
			for _, seat in seats do
				-- El frente (-Z local, girado por yaw) apunta al centro de la mesa.
				local fx, fz = -math.sin(seat.yaw), -math.cos(seat.yaw)
				local tx, tz = t.x - seat.x, t.z - seat.z
				expect(fx * tx + fz * tz > 0).toBe(true)
			end
		end
	end)

	it("los edificios quedan fuera del parque y de la calle", function()
		local inner = LobbyPark.PARK_HALF + LobbyPark.SIDEWALK + LobbyPark.STREET
		for _, b in LobbyPark.buildings() do
			expect(math.max(math.abs(b.x), math.abs(b.z)) - b.depth / 2 >= inner - 1e-6).toBe(true)
		end
	end)
end)

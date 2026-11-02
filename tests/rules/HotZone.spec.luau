--!strict
-- Zona Caliente: elección de zona con Rng, cadencia de las rondas (1, 4, 7…), evento
-- HotZoneMoved y el ×2 de renta que ya aplica Property.rentMultiplier dentro del tope ×4.
local Harness = require("../harness")
local Economy = require("../../src/shared/config/Economy")
local Fixtures = require("../fixtures")
local HotZone = require("../../src/shared/rules/HotZone")
local Property = require("../../src/shared/rules/Property")
local Rng = require("../../src/shared/rules/Rng")
local State = require("../../src/shared/rules/State")
local Turn = require("../../src/shared/rules/Turn")
local Types = require("../../src/shared/rules/Types")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

-- Exige que el evento exista: casi todas las pruebas buscan uno concreto.
local function eventOf(events: { Types.Event }, kind: string): Types.Event
	for _, event in events do
		if event.type == kind then
			return event
		end
	end
	error(`no se emitió el evento {kind}`, 2)
end

local function countOf(events: { Types.Event }, kind: string): number
	local count = 0
	for _, event in events do
		if event.type == kind then
			count += 1
		end
	end
	return count
end

local function priceOf(state: Types.GameState, index: number): number
	local price = state.board.squares[index].price
	if not price then
		error(`la casilla {index} no tiene precio`, 2)
	end
	return price
end

local function zoneIdOf(state: Types.GameState, index: number): string
	local zoneId = state.board.squares[index].zoneId
	if not zoneId then
		error(`la casilla {index} no tiene zona`, 2)
	end
	return zoneId
end

local function baseRentOf(state: Types.GameState, index: number): number
	return math.floor(priceOf(state, index) * Economy.baseRentRate)
end

-- Deja al jugador en turno como último de la ronda para que Turn.next cierre la ronda.
local function enterNextRoundFrom(state: Types.GameState, round: number)
	Fixtures.turnOf(state, state.players[#state.players].id)
	state.round = round - 1
end

describe("HotZone.isMoveRound", function()
	it("mueve la zona al empezar las rondas 1, 4, 7 y así sucesivamente", function()
		local s = Fixtures.game({ players = 4 })
		for _, round in { 1, 4, 7, 10, 13 } do
			expect(HotZone.isMoveRound(s, round)).toBe(true)
		end
		for _, round in { 2, 3, 5, 6, 8, 9, 11, 12 } do
			expect(HotZone.isMoveRound(s, round)).toBe(false)
		end
	end)

	it("respeta Economy.hotZoneInterval", function()
		local s = Fixtures.game({ players = 4 })
		for round = 1, 20 do
			expect(HotZone.isMoveRound(s, round)).toBe((round - 1) % Economy.hotZoneInterval == 0)
		end
	end)
end)

describe("HotZone.move", function()
	it("elige una zona del tablero y anuncia el cambio desde nil", function()
		local s = Fixtures.game({ players = 4 })
		expect(s.hotZoneId).toBe(nil)
		local events = HotZone.move(s)
		expect(#events).toBe(1)
		expect(events[1].type).toBe("HotZoneMoved")
		expect(events[1].from).toBe(nil)
		expect(events[1].to).toBe(s.hotZoneId)
		local chosen = s.hotZoneId
		if not chosen then
			error("HotZone.move no escribió state.hotZoneId", 2)
		end
		expect(table.find(s.board.zoneOrder, chosen) ~= nil).toBe(true)
	end)

	it("nunca repite la zona anterior", function()
		local s = Fixtures.game({ players = 4 })
		local previous = s.board.zoneOrder[1]
		s.hotZoneId = previous
		for _ = 1, #s.board.zoneOrder * 2 do
			local events = HotZone.move(s)
			local moved = eventOf(events, "HotZoneMoved")
			expect(moved.from).toBe(previous)
			expect(moved.to ~= previous).toBe(true)
			expect(moved.to).toBe(s.hotZoneId)
			previous = s.hotZoneId :: string
		end
	end)

	it("elige con Rng entre las zonas restantes, en el orden del tablero", function()
		local s = Fixtures.game({ players = 4 })
		local order = s.board.zoneOrder
		-- Con la primera zona como anterior, los candidatos empiezan en la segunda.
		s.hotZoneId = order[1]
		Rng.force(s.rng, { 1 })
		expect(eventOf(HotZone.move(s), "HotZoneMoved").to).toBe(order[2])
		-- Con la tercera como anterior, la lista salta esa zona: el tercer candidato es la cuarta.
		s.hotZoneId = order[3]
		Rng.force(s.rng, { 3 })
		expect(eventOf(HotZone.move(s), "HotZoneMoved").to).toBe(order[4])
		-- Sin zona anterior se elige sobre el orden completo.
		s.hotZoneId = nil
		Rng.force(s.rng, { 2 })
		expect(eventOf(HotZone.move(s), "HotZoneMoved").to).toBe(order[2])
	end)

	it("es determinista con la misma semilla y el mismo estado", function()
		local first = Fixtures.game({ players = 3, seed = 11 })
		local second = Fixtures.game({ players = 3, seed = 11 })
		expect(HotZone.move(first)).toEqual(HotZone.move(second))
		expect(first.hotZoneId).toBe(second.hotZoneId)
	end)
end)

describe("zona inicial de la partida", function()
	it("State.create abre la ronda 1 con una zona del tablero", function()
		local s = State.create({ playerIds = { "P1", "P2", "P3" }, seed = 1 })
		local chosen = s.hotZoneId
		if not chosen then
			error("State.create debe elegir la Zona Caliente de la ronda 1", 2)
		end
		expect(table.find(s.board.zoneOrder, chosen) ~= nil).toBe(true)
	end)

	it("el fixture de reglas la limpia para no depender de qué zona tocó", function()
		expect(Fixtures.game({ players = 3 }).hotZoneId).toBe(nil)
	end)

	it("HotZone.begin coloca la zona inicial cuando falta", function()
		local s = Fixtures.game({ players = 3 })
		expect(s.hotZoneId).toBe(nil)
		local events = HotZone.begin(s)
		expect(#events).toBe(1)
		expect(eventOf(events, "HotZoneMoved").from).toBe(nil)
		expect(s.hotZoneId ~= nil).toBe(true)
		expect(table.find(s.board.zoneOrder, s.hotZoneId :: string) ~= nil).toBe(true)
	end)

	it("es idempotente: con zona elegida no vuelve a moverla", function()
		local s = Fixtures.game({ players = 3 })
		local first = HotZone.begin(s)
		local chosen = s.hotZoneId
		expect(HotZone.begin(s)).toEqual({})
		expect(s.hotZoneId).toBe(chosen)
		expect(#first).toBe(1)
	end)
end)

describe("rentas de la Zona Caliente", function()
	it("duplica la renta de la zona a través de Property.rentFor", function()
		local s = Fixtures.game({ players = 2 })
		local idx = Fixtures.squareOf(s, "Property")
		local owner = s.players[1]
		Fixtures.give(s, owner.id, idx)
		s.hotZoneId = zoneIdOf(s, idx)
		expect(Property.rentFor(s, idx)).toBe(baseRentOf(s, idx) * Economy.hotZoneRentMultiplier)
		expect(baseRentOf(s, idx) * Economy.maxRentMultiplier >= Property.rentFor(s, idx)).toBe(true)
	end)

	it("no toca las rentas de las demás zonas", function()
		local s = Fixtures.game({ players = 2 })
		local idx = Fixtures.squareOf(s, "Property")
		local owner = s.players[1]
		Fixtures.give(s, owner.id, idx)
		s.hotZoneId = s.board.zoneOrder[2]
		expect(Property.rentFor(s, idx)).toBe(baseRentOf(s, idx))
	end)

	it("respeta el tope de × 4 al sumar Inflación y Zona Caliente", function()
		local s = Fixtures.game({ players = 2 })
		local idx = Fixtures.squareOf(s, "Property")
		local owner = s.players[1]
		Fixtures.give(s, owner.id, idx)
		s.hotZoneId = zoneIdOf(s, idx)
		table.insert(s.modifiers, { kind = "Inflation", untilRound = 99 })
		expect(Property.rentMultiplier(s, idx)).toBe(Economy.maxRentMultiplier)
		-- Una segunda Inflación no puede superar el tope: el producto 8 se queda en 4.
		table.insert(s.modifiers, { kind = "Inflation", untilRound = 99 })
		expect(Property.rentMultiplier(s, idx)).toBe(Economy.maxRentMultiplier)
		expect(Property.rentFor(s, idx)).toBe(
			math.floor(priceOf(s, idx) * Economy.baseRentRate * Economy.maxRentMultiplier)
		)
	end)
end)

describe("Turn.next y la Zona Caliente", function()
	it("mueve la zona al empezar la ronda 4", function()
		local s = Fixtures.game({ players = 2 })
		HotZone.begin(s)
		local previous = s.hotZoneId
		enterNextRoundFrom(s, 4)
		local events = Turn.next(s)
		expect(s.round).toBe(4)
		expect(events[1].type).toBe("RoundStarted")
		local moved = eventOf(events, "HotZoneMoved")
		expect(moved.from).toBe(previous)
		expect(moved.to ~= previous).toBe(true)
		expect(s.hotZoneId).toBe(moved.to)
	end)

	it("mueve la zona al empezar la ronda 7", function()
		local s = Fixtures.game({ players = 2 })
		HotZone.begin(s)
		local previous = s.hotZoneId
		enterNextRoundFrom(s, 7)
		local events = Turn.next(s)
		expect(s.round).toBe(7)
		local moved = eventOf(events, "HotZoneMoved")
		expect(moved.from).toBe(previous)
		expect(moved.to ~= previous).toBe(true)
	end)

	it("no mueve la zona en las rondas 2, 3, 5 y 6", function()
		for _, round in { 2, 3, 5, 6 } do
			local s = Fixtures.game({ players = 2 })
			HotZone.begin(s)
			local chosen = s.hotZoneId
			enterNextRoundFrom(s, round)
			local events = Turn.next(s)
			expect(s.round).toBe(round)
			expect(countOf(events, "HotZoneMoved")).toBe(0)
			expect(s.hotZoneId).toBe(chosen)
		end
	end)

	it("la ronda 1 no elige zona en un cambio de turno: la abre State.create", function()
		-- R-P40: la ronda 1 nace con zona desde State.create; el primer Turn.next no abre ronda y
		-- no emite nada (Turn.spec), así que con el fixture limpio sigue sin zona.
		local s = Fixtures.game({ players = 3 })
		Fixtures.turnOf(s, s.players[1].id)
		expect(Turn.next(s)).toEqual({})
		expect(s.hotZoneId).toBe(nil)
	end)
end)

--!strict
-- Rondas, modos de partida, Corona y final. La partida la cierra Turn; Bankruptcy solo avisa.
local Harness = require("../harness")
local Bankruptcy = require("../../src/shared/rules/Bankruptcy")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Movement = require("../../src/shared/rules/Movement")
local Property = require("../../src/shared/rules/Property")
local Score = require("../../src/shared/rules/Score")
local State = require("../../src/shared/rules/State")
local Turn = require("../../src/shared/rules/Turn")
local Types = require("../../src/shared/rules/Types")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function inTurn(state: Types.GameState): Types.Player
	return state.players[state.turnIndex]
end

-- pending es la tabla persistente que State.create siempre crea (R1).
local function pendingOf(state: Types.GameState): any
	local pending = state.pending
	if not pending then
		error("el estado no tiene pending", 2)
	end
	return pending
end

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

local function typesOf(events: { Types.Event }): { string }
	local kinds: { string } = {}
	for _, event in events do
		table.insert(kinds, event.type)
	end
	return kinds
end

local function priceOf(state: Types.GameState, index: number): number
	local price = state.board.squares[index].price
	if not price then
		error(`la casilla {index} no tiene precio`, 2)
	end
	return price
end

local function baseRentOf(state: Types.GameState, index: number): number
	return math.floor(priceOf(state, index) * Economy.baseRentRate)
end

local function zoneIdOf(state: Types.GameState, index: number): string
	local zoneId = state.board.squares[index].zoneId
	if not zoneId then
		error(`la casilla {index} no tiene zona`, 2)
	end
	return zoneId
end

local function addModifier(state: Types.GameState, modifier: Types.Modifier)
	table.insert(state.modifiers, modifier)
end

-- Exige un rechazo y devuelve el mensaje para poder comprobarlo.
local function rejected(result: Types.ApplyResult): string
	if result.ok then
		error("se esperaba un rechazo y la acción se aplicó", 3)
	end
	return result.error
end

describe("modos de partida", function()
	it("Rounds es el modo por defecto y fija el tope del tamaño", function()
		local s = Fixtures.game({ players = 8 })
		expect(s.endMode).toBe("Rounds")
		expect(s.maxRounds).toBe(Economy.rounds.L)
	end)

	it("Sin Fin no tiene tope de rondas", function()
		local s = Fixtures.game({ players = 8, endMode = "Endless" })
		expect(s.endMode).toBe("Endless")
		expect(s.maxRounds).toBe(nil)
	end)

	it("rechaza un modo desconocido con un error claro", function()
		local ok, err = pcall(function()
			State.create({ playerIds = { "P1", "P2" }, seed = 1, endMode = "SuddenDeath" :: any })
		end)
		expect(ok).toBe(false)
		expect(string.find(tostring(err), "Rounds", 1, true) ~= nil).toBe(true)
		expect(string.find(tostring(err), "Endless", 1, true) ~= nil).toBe(true)
	end)
end)

describe("Turn.isFinalRound", function()
	it("duplica la renta en las dos últimas rondas", function()
		local s = Fixtures.game({ players = 8 })
		s.round = 11
		expect(Turn.isFinalRound(s)).toBe(true)
		s.round = 10
		expect(Turn.isFinalRound(s)).toBe(false)
	end)

	it("marca también la última ronda del tamaño", function()
		local s = Fixtures.game({ players = 8 })
		s.round = Economy.rounds.L
		expect(Turn.isFinalRound(s)).toBe(true)
	end)

	it("no existe en Sin Fin", function()
		local s = Fixtures.game({ players = 8, endMode = "Endless" })
		s.round = 999
		expect(Turn.isFinalRound(s)).toBe(false)
	end)
end)

describe("Turn.isPressureRound", function()
	it("Sin Fin aplica presión desde la ronda 30", function()
		local s = Fixtures.game({ players = 3, endMode = "Endless" })
		s.round = 29
		expect(Turn.isPressureRound(s)).toBe(false)
		s.round = 30
		expect(Turn.isPressureRound(s)).toBe(true)
	end)

	it("no existe en Rounds", function()
		local s = Fixtures.game({ players = 8 })
		s.round = 30
		expect(Turn.isPressureRound(s)).toBe(false)
	end)
end)

describe("Property.rentFor en las rondas finales", function()
	it("duplica la renta en las dos últimas rondas", function()
		local s = Fixtures.game({ players = 8 })
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, s.players[1].id, idx)
		local base = baseRentOf(s, idx)
		s.round = (s.maxRounds :: number) - Economy.finalRoundsCount
		expect(Property.rentFor(s, idx)).toBe(base)
		s.round += 1
		expect(Property.rentFor(s, idx)).toBe(base * Economy.finalRoundsRentMultiplier)
		s.round += 1
		expect(Property.rentFor(s, idx)).toBe(base * Economy.finalRoundsRentMultiplier)
	end)
end)

describe("Property.rentFor en la presión de Sin Fin", function()
	it("duplica la renta desde la ronda de presión", function()
		local s = Fixtures.game({ players = 8, endMode = "Endless" })
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, s.players[1].id, idx)
		local base = baseRentOf(s, idx)
		s.round = Economy.pressureFromRound - 1
		expect(Property.rentFor(s, idx)).toBe(base)
		s.round = Economy.pressureFromRound
		expect(Property.rentFor(s, idx)).toBe(base * Economy.pressureRentMultiplier)
	end)

	it("respeta el tope de × 4 al sumar presión e Inflación", function()
		local s = Fixtures.game({ players = 8, endMode = "Endless" })
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, s.players[1].id, idx)
		s.round = Economy.pressureFromRound
		addModifier(s, { kind = "Inflation", untilRound = 99 })
		addModifier(s, { kind = "Inflation", untilRound = 99 })
		s.hotZoneId = zoneIdOf(s, idx)
		expect(Property.rentMultiplier(s, idx)).toBe(Economy.maxRentMultiplier)
		expect(Property.rentFor(s, idx)).toBe(
			math.floor(priceOf(s, idx) * Economy.baseRentRate * Economy.maxRentMultiplier)
		)
	end)
end)

describe("Turn.activeCount", function()
	it("cuenta solo a los jugadores activos", function()
		local s = Fixtures.game({ players = 4 })
		s.players[2].status = "Ghost"
		s.players[3].status = "Left"
		expect(Turn.activeCount(s)).toBe(2)
	end)
end)

describe("Turn.finishIfLastActive", function()
	it("no termina mientras queden dos activos", function()
		local s = Fixtures.game({ players = 3 })
		local events: { Types.Event } = {}
		expect(Turn.finishIfLastActive(s, events)).toBe(false)
		expect(#events).toBe(0)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("termina y proclama ganador al único activo", function()
		local s = Fixtures.game({ players = 3 })
		local survivor = s.players[2]
		s.players[1].status = "Ghost"
		s.players[3].status = "Ghost"
		-- El espectro va primero por patrimonio: aun así gana el que sigue en pie.
		s.players[1].cash = 9000
		local events: { Types.Event } = {}
		expect(Turn.finishIfLastActive(s, events)).toBe(true)
		expect(s.phase).toBe("GameOver")
		expect(typesOf(events)).toEqual({ "GameEnded" })
		expect(events[1].winnerId).toBe(survivor.id)
		expect(events[1].ranking).toEqual(Score.ranking(s))
	end)
end)

describe("final de la partida por rondas", function()
	it("termina al superar la última ronda con la clasificación y el líder como ganador", function()
		local s = Fixtures.game({ players = 8 })
		local leader = s.players[3]
		leader.cash = 5000
		Fixtures.turnOf(s, s.players[#s.players].id)
		s.round = s.maxRounds :: number
		s.phase = "AwaitEnd"
		local result = Engine.apply(s, inTurn(s).id, { type = "EndTurn" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(s.phase).toBe("GameOver")
		expect(typesOf(result.events)).toEqual({ "GameEnded" })
		expect(result.events[1].winnerId).toBe(leader.id)
		expect(result.events[1].ranking).toEqual(Score.ranking(s))
	end)

	it("no termina al entrar en la última ronda", function()
		local s = Fixtures.game({ players = 8 })
		Fixtures.turnOf(s, s.players[#s.players].id)
		s.round = (s.maxRounds :: number) - 1
		s.phase = "AwaitEnd"
		local result = Engine.apply(s, inTurn(s).id, { type = "EndTurn" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(s.round).toBe(s.maxRounds)
		expect(s.phase).toBe("AwaitRoll")
		expect(countOf(result.events, "GameEnded")).toBe(0)
		expect(eventOf(result.events, "RoundStarted").round).toBe(s.maxRounds)
	end)

	it("emite GameEnded una sola vez y rechaza las acciones posteriores", function()
		local s = Fixtures.game({ players = 8 })
		Fixtures.turnOf(s, s.players[#s.players].id)
		s.round = s.maxRounds :: number
		s.phase = "AwaitEnd"
		local actor = inTurn(s).id
		local result = Engine.apply(s, actor, { type = "EndTurn" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(countOf(result.events, "GameEnded")).toBe(1)
		expect(rejected(Engine.apply(s, actor, { type = "EndTurn" }))).toBe("La partida ha terminado")
		expect(rejected(Engine.apply(s, actor, { type = "Roll" }))).toBe("La partida ha terminado")
		expect(s.phase).toBe("GameOver")
	end)

	it("Sin Fin nunca termina por rondas", function()
		local s = Fixtures.game({ players = 3, endMode = "Endless" })
		local last = s.players[#s.players]
		Fixtures.turnOf(s, last.id)
		s.round = 500
		s.phase = "AwaitEnd"
		local result = Engine.apply(s, last.id, { type = "EndTurn" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(s.phase).toBe("AwaitRoll")
		expect(s.round).toBe(501)
		expect(countOf(result.events, "GameEnded")).toBe(0)
		expect(countOf(result.events, "FinalRoundsStarted")).toBe(0)
		expect(eventOf(result.events, "RoundStarted").round).toBe(501)
	end)
end)

describe("victoria anticipada", function()
	it("Rondas termina antes si todos los rivales están en bancarrota", function()
		local s = Fixtures.game({ players = 2 })
		local broke, winner = s.players[1], s.players[2]
		broke.cash = 0
		local events = Bankruptcy.charge(s, broke.id, 500, winner.id)
		expect(s.phase).toBe("GameOver")
		expect(typesOf(events)).toEqual({ "BankruptcyDeclared", "GameEnded" })
		expect(events[2].winnerId).toBe(winner.id)
		expect(events[2].ranking).toEqual(Score.ranking(s))
	end)

	it("Sin Fin termina con un solo jugador activo", function()
		local s = Fixtures.game({ players = 3, endMode = "Endless" })
		local survivor = s.players[1]
		expect(s.maxRounds).toBe(nil)
		expect(Turn.isFinalRound(s)).toBe(false)
		-- El primer rival cae y la partida sigue: aún quedan dos activos.
		s.players[2].cash = 0
		local first = Bankruptcy.charge(s, s.players[2].id, 5000, survivor.id)
		expect(countOf(first, "GameEnded")).toBe(0)
		expect(s.phase).toBe("AwaitRoll")
		-- El segundo deja un único activo: la partida termina en ese instante.
		s.players[3].cash = 0
		local second = Bankruptcy.charge(s, s.players[3].id, 5000, survivor.id)
		expect(typesOf(second)).toEqual({ "BankruptcyDeclared", "GameEnded" })
		expect(s.phase).toBe("GameOver")
		expect(second[2].winnerId).toBe(survivor.id)
	end)

	it("Sin Fin: el cambio de turno termina con un solo activo", function()
		local s = Fixtures.game({ players = 3, endMode = "Endless" })
		local survivor = s.players[1]
		s.players[2].status = "Ghost"
		s.players[2].cash = 0
		s.players[3].status = "Ghost"
		s.players[3].cash = 0
		s.phase = "AwaitEnd"
		local result = Engine.apply(s, survivor.id, { type = "EndTurn" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(s.phase).toBe("GameOver")
		expect(typesOf(result.events)).toEqual({ "GameEnded" })
		expect(result.events[1].winnerId).toBe(survivor.id)
	end)
end)

describe("la Corona", function()
	it("nace en el primer jugador de la clasificación", function()
		local s = Fixtures.game({ players = 4 })
		expect(pendingOf(s).crownId).toBe(s.players[1].id)
	end)

	it("pasa al líder al empezar cada ronda", function()
		local s = Fixtures.game({ players = 4 })
		local leader = s.players[3]
		leader.cash = 4000
		local previous = pendingOf(s).crownId
		Fixtures.turnOf(s, s.players[#s.players].id)
		local events = Turn.next(s)
		expect(s.round).toBe(2)
		expect(events[1]).toEqual({ type = "RoundStarted", round = 2 })
		expect(eventOf(events, "CrownMoved")).toEqual({ type = "CrownMoved", from = previous, to = leader.id })
		expect(pendingOf(s).crownId).toBe(leader.id)
	end)

	it("solo se mueve cuando cambia el portador", function()
		local s = Fixtures.game({ players = 3 })
		local leader = s.players[2]
		leader.cash = 4000
		pendingOf(s).crownId = leader.id
		Fixtures.turnOf(s, s.players[3].id)
		local events = Turn.next(s)
		expect(countOf(events, "CrownMoved")).toBe(0)
		expect(pendingOf(s).crownId).toBe(leader.id)
	end)

	it("solo la lleva un jugador activo", function()
		local s = Fixtures.game({ players = 3 })
		local ghost = s.players[1]
		ghost.cash = 9000
		ghost.status = "Ghost"
		Fixtures.turnOf(s, s.players[3].id)
		Turn.next(s)
		expect(pendingOf(s).crownId).toBe(s.players[2].id)
	end)

	it("no se mueve si no queda ningún activo", function()
		local s = Fixtures.game({ players = 2 })
		local before = pendingOf(s).crownId
		s.players[1].status = "Ghost"
		s.players[2].status = "Ghost"
		Fixtures.turnOf(s, s.players[2].id)
		local events = Turn.next(s)
		expect(countOf(events, "CrownMoved")).toBe(0)
		expect(pendingOf(s).crownId).toBe(before)
	end)
end)

describe("eventos de ronda", function()
	it("la ronda 1 empieza con la partida y no emite RoundStarted", function()
		local s = Fixtures.game({ players = 3 })
		expect(s.round).toBe(1)
		expect(Turn.next(s)).toEqual({})
	end)

	it("anuncia las rondas finales solo al entrar en ellas", function()
		local s = Fixtures.game({ players = 8 })
		Fixtures.turnOf(s, s.players[#s.players].id)
		s.round = (s.maxRounds :: number) - Economy.finalRoundsCount
		local entering = Turn.next(s)
		expect(s.round).toBe(11)
		expect(countOf(entering, "FinalRoundsStarted")).toBe(1)
		expect(eventOf(entering, "FinalRoundsStarted").round).toBe(11)
		Fixtures.turnOf(s, s.players[#s.players].id)
		local last = Turn.next(s)
		expect(s.round).toBe(12)
		expect(countOf(last, "FinalRoundsStarted")).toBe(0)
	end)
end)

describe("Salida en la presión de Sin Fin", function()
	local function pressureGame(): Types.GameState
		local s = Fixtures.game({ players = 2, endMode = "Endless" })
		s.round = Economy.pressureFromRound
		return s
	end

	it("no paga la Salida al pasar por ella", function()
		local s = pressureGame()
		local id = s.players[1].id
		Fixtures.placeOn(s, id, 31)
		local events = Movement.advance(s, id, 3)
		expect(s.players[1].position).toBe(2)
		expect(s.players[1].cash).toBe(Economy.startingCash)
		expect(countOf(events, "PassedStart")).toBe(0)
	end)

	it("no paga la Salida al caer en ella", function()
		local s = pressureGame()
		local id = s.players[1].id
		Fixtures.placeOn(s, id, #s.board.squares)
		local events = Movement.advance(s, id, 1)
		expect(s.players[1].position).toBe(1)
		expect(s.players[1].cash).toBe(Economy.startingCash)
		expect(countOf(events, "PassedStart")).toBe(0)
	end)

	it("sigue pagando justo antes de la presión", function()
		local s = Fixtures.game({ players = 2, endMode = "Endless" })
		s.round = Economy.pressureFromRound - 1
		local id = s.players[1].id
		Fixtures.placeOn(s, id, 31)
		local events = Movement.advance(s, id, 3)
		expect(s.players[1].cash).toBe(Economy.startingCash + Economy.startBonus)
		expect(countOf(events, "PassedStart")).toBe(1)
	end)

	it("tampoco paga al pasar por la Salida con un Roll", function()
		local s = pressureGame()
		local id = inTurn(s).id
		Fixtures.placeOn(s, id, 31)
		Fixtures.dice(s, 1, 2)
		local result = Engine.apply(s, id, { type = "Roll" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(s.players[s.turnIndex].cash).toBe(Economy.startingCash)
		expect(countOf(result.events, "PassedStart")).toBe(0)
	end)
end)

describe("desempates de la clasificación", function()
	it("desempata por efectivo", function()
		local s = Fixtures.game({ players = 2 })
		local first, second = s.players[1], s.players[2]
		local idx = Fixtures.squareOf(s, "Property")
		first.cash = 0
		Fixtures.give(s, first.id, idx)
		-- El mismo patrimonio (el precio de la casilla), pero second tiene más efectivo.
		second.cash = priceOf(s, idx)
		expect(Score.ranking(s)).toEqual({ second.id, first.id })
	end)

	it("desempata por orden de turno si el efectivo también coincide", function()
		local s = Fixtures.game({ players = 3 })
		expect(Score.ranking(s)).toEqual({ s.players[1].id, s.players[2].id, s.players[3].id })
	end)

	it("el final por rondas desempata igual", function()
		local s = Fixtures.game({ players = 2 })
		local first, second = s.players[1], s.players[2]
		local idx = Fixtures.squareOf(s, "Property")
		first.cash = 0
		Fixtures.give(s, first.id, idx)
		second.cash = priceOf(s, idx)
		Fixtures.turnOf(s, s.players[#s.players].id)
		s.round = s.maxRounds :: number
		s.phase = "AwaitEnd"
		local events = Turn.next(s)
		expect(eventOf(events, "GameEnded").winnerId).toBe(second.id)
	end)
end)

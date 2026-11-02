--!strict
-- Pactos: propuesta, aceptación con garantía retenida, exención de renta mientras dura,
-- caducidad, ruptura con marca de Traidor, bancarrota de un socio y la garantía reducida del
-- perk Negociador (R-P6).
local Bankruptcy = require("../../src/shared/rules/Bankruptcy")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Harness = require("../harness")
local Pact = require("../../src/shared/rules/Pact")
local Property = require("../../src/shared/rules/Property")
local Score = require("../../src/shared/rules/Score")
local Turn = require("../../src/shared/rules/Turn")
local Types = require("../../src/shared/rules/Types")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function inTurn(state: Types.GameState): Types.Player
	return state.players[state.turnIndex]
end

-- Rivales en el orden de state.players.
local function rivalsOf(state: Types.GameState, playerId: Types.PlayerId): { Types.Player }
	local rivals: { Types.Player } = {}
	for _, player in state.players do
		if player.id ~= playerId then
			table.insert(rivals, player)
		end
	end
	return rivals
end

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

-- Copia profunda: los rechazos se comprueban contra el estado entero.
local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local source = value :: any
	local copy: { [any]: any } = {}
	for key, item in source do
		copy[key] = deepCopy(item)
	end
	return copy :: any
end

-- Exige un rechazo y devuelve el mensaje para poder comprobarlo.
local function rejected(result: Types.ApplyResult): string
	if result.ok then
		error("se esperaba un rechazo y la acción se aplicó", 3)
	end
	expect(result.error ~= "").toBe(true)
	return result.error
end

-- Ofertas guardadas pendientes de respuesta.
local function offersOf(state: Types.GameState): { any }
	return pendingOf(state).pactOffers or {}
end

-- Propone un pacto por la vía del motor y devuelve el id de la oferta.
local function proposePact(
	state: Types.GameState,
	fromId: Types.PlayerId,
	toId: Types.PlayerId,
	rounds: number
): string
	local action: Types.Action = { type = "ProposePact", toId = toId, rounds = rounds }
	local result = Engine.apply(state, fromId, action)
	if not result.ok then
		error(result.error, 2)
	end
	expect(result.events).toEqual({})
	local offers = offersOf(state)
	local offer = offers[#offers]
	if not offer or offer.toId ~= toId then
		error("ProposePact no guardó la oferta", 2)
	end
	return offer.id
end

-- Propone y acepta: deja el pacto formado y devuelve su id.
local function formPact(
	state: Types.GameState,
	fromId: Types.PlayerId,
	toId: Types.PlayerId,
	rounds: number
): string
	local pactId = proposePact(state, fromId, toId, rounds)
	local action: Types.Action = { type = "RespondPact", pactId = pactId, accept = true }
	local result = Engine.apply(state, toId, action)
	if not result.ok then
		error(result.error, 2)
	end
	return pactId
end

-- Deja al jugador como último de la ronda para que Turn.next abra la siguiente.
local function enterNextRoundFrom(state: Types.GameState, round: number)
	Fixtures.turnOf(state, state.players[#state.players].id)
	state.round = round - 1
end

describe("Pact.propose", function()
	it("guarda la oferta sin mover dinero ni crear el pacto", function()
		local s = Fixtures.game({ players = 3 })
		local proposer = inTurn(s)
		local target = rivalsOf(s, proposer.id)[1]
		local cash = proposer.cash

		local pactId = proposePact(s, proposer.id, target.id, 3)
		expect(type(pactId)).toBe("string")
		expect(#offersOf(s)).toBe(1)
		local offer = offersOf(s)[1]
		expect(offer.fromId).toBe(proposer.id)
		expect(offer.toId).toBe(target.id)
		expect(offer.rounds).toBe(3)
		expect(s.pacts).toEqual({})
		expect(proposer.cash).toBe(cash)
		expect(target.cash).toBe(cash)
		expect(s.stats[proposer.id].pactsFormed).toBe(nil)
	end)

	it("rechaza proponer fuera de turno", function()
		local s = Fixtures.game({ players = 3 })
		local proposer = inTurn(s)
		local other = rivalsOf(s, proposer.id)[1]
		local before = deepCopy(s)
		local action: Types.Action =
			{ type = "ProposePact", toId = rivalsOf(s, proposer.id)[2].id, rounds = 2 }
		expect(rejected(Engine.apply(s, other.id, action))).toBe("No es tu turno")
		expect(deepCopy(s)).toEqual(before)
	end)

	it("exige una duración entera entre Economy.pact.minRounds y maxRounds", function()
		local s = Fixtures.game({ players = 3 })
		local proposer = inTurn(s)
		local target = rivalsOf(s, proposer.id)[1]
		local before = deepCopy(s)
		for _, rounds in { 0, Economy.pact.maxRounds + 1 } do
			local action: Types.Action = { type = "ProposePact", toId = target.id, rounds = rounds }
			local message = rejected(Engine.apply(s, proposer.id, action))
			expect(string.find(message, tostring(Economy.pact.minRounds), 1, true) ~= nil).toBe(true)
			expect(string.find(message, tostring(Economy.pact.maxRounds), 1, true) ~= nil).toBe(true)
		end
		local fractional: Types.Action = { type = "ProposePact", toId = target.id, rounds = 2.5 }
		expect(rejected(Engine.apply(s, proposer.id, fractional))).toBe(
			"La duración del pacto debe ser un número entero"
		)
		local textual: Types.Action = { type = "ProposePact", toId = target.id, rounds = "3" }
		expect(rejected(Engine.apply(s, proposer.id, textual))).toBe(
			"La duración del pacto debe ser un número entero"
		)
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza proponerse un pacto a sí mismo", function()
		local s = Fixtures.game({ players = 3 })
		local proposer = inTurn(s)
		local action: Types.Action = { type = "ProposePact", toId = proposer.id, rounds = 2 }
		expect(rejected(Engine.apply(s, proposer.id, action))).toBe(
			"No puedes proponerte un pacto a ti mismo"
		)
	end)

	it("rechaza un socio fantasma, ausente o que abandonó", function()
		local s = Fixtures.game({ players = 3 })
		local proposer = inTurn(s)
		local target = rivalsOf(s, proposer.id)[1]
		target.status = "Ghost"
		local ghostAction: Types.Action = { type = "ProposePact", toId = target.id, rounds = 2 }
		expect(rejected(Engine.apply(s, proposer.id, ghostAction))).toBe(
			"Solo se puede pactar con un jugador activo"
		)
		target.status = "Left"
		local leftAction: Types.Action = { type = "ProposePact", toId = target.id, rounds = 2 }
		expect(rejected(Engine.apply(s, proposer.id, leftAction))).toBe(
			"El otro jugador ha abandonado la partida"
		)
		local missingAction: Types.Action = { type = "ProposePact", toId = "P9", rounds = 2 }
		expect(rejected(Engine.apply(s, proposer.id, missingAction))).toBe(
			"El jugador P9 no está en la partida"
		)
	end)

	it("rechaza proponer siendo un fantasma", function()
		local s = Fixtures.game({ players = 3 })
		local proposer = inTurn(s)
		local target = rivalsOf(s, proposer.id)[1]
		proposer.status = "Ghost"
		local before = deepCopy(s)
		local action: Types.Action = { type = "ProposePact", toId = target.id, rounds = 2 }
		expect(rejected(Engine.apply(s, proposer.id, action))).toBe(
			"Solo los jugadores activos pueden pactar"
		)
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza proponer en una fase que no es de turno", function()
		local s = Fixtures.game({ players = 3 })
		local proposer = inTurn(s)
		local target = rivalsOf(s, proposer.id)[1]
		s.phase = "Auction"
		local action: Types.Action = { type = "ProposePact", toId = target.id, rounds = 2 }
		expect(rejected(Engine.apply(s, proposer.id, action))).toBe(
			"No se puede ProposePact en la fase Auction"
		)
	end)
end)

describe("Pact.respond", function()
	it("acepta: retiene la garantía de ambos y emite PactFormed", function()
		local s = Fixtures.game({ players = 3 })
		local proposer = inTurn(s)
		local target = rivalsOf(s, proposer.id)[1]
		local pactId = proposePact(s, proposer.id, target.id, 3)

		local action: Types.Action = { type = "RespondPact", pactId = pactId, accept = true }
		local result = Engine.apply(s, target.id, action)
		if not result.ok then
			error(result.error, 2)
		end
		local expected: { Types.Event } = { { type = "PactFormed", pactId = pactId } }
		expect(result.events).toEqual(expected)
		expect(#s.pacts).toBe(1)
		local pact = s.pacts[1]
		expect(pact.id).toBe(pactId)
		expect(pact.a).toBe(proposer.id)
		expect(pact.b).toBe(target.id)
		expect(pact.depositA).toBe(Economy.pact.deposit)
		expect(pact.depositB).toBe(Economy.pact.deposit)
		expect(pact.untilRound).toBe(s.round + 3 - 1)
		expect(proposer.cash).toBe(Economy.startingCash - Economy.pact.deposit)
		expect(target.cash).toBe(Economy.startingCash - Economy.pact.deposit)
		expect(#offersOf(s)).toBe(0)
		expect(s.stats[proposer.id].pactsFormed).toBe(1)
		expect(s.stats[target.id].pactsFormed).toBe(1)
	end)

	it("dura de 1 a Economy.pact.maxRounds rondas", function()
		for _, rounds in { Economy.pact.minRounds, Economy.pact.maxRounds } do
			local s = Fixtures.game({ players = 2 })
			local proposer = inTurn(s)
			local target = rivalsOf(s, proposer.id)[1]
			local pactId = formPact(s, proposer.id, target.id, rounds)
			expect(s.pacts[1].id).toBe(pactId)
			expect(s.pacts[1].untilRound).toBe(s.round + rounds - 1)
		end
	end)

	it("exige efectivo a quien responde", function()
		local s = Fixtures.game({ players = 2 })
		local proposer = inTurn(s)
		local target = rivalsOf(s, proposer.id)[1]
		local pactId = proposePact(s, proposer.id, target.id, 3)
		target.cash = Economy.pact.deposit - 1
		local before = deepCopy(s)
		local action: Types.Action = { type = "RespondPact", pactId = pactId, accept = true }
		expect(rejected(Engine.apply(s, target.id, action))).toBe("No tienes efectivo suficiente")
		expect(deepCopy(s)).toEqual(before)
	end)

	it("exige efectivo al proponente", function()
		local s = Fixtures.game({ players = 2 })
		local proposer = inTurn(s)
		local target = rivalsOf(s, proposer.id)[1]
		local pactId = proposePact(s, proposer.id, target.id, 3)
		proposer.cash = Economy.pact.deposit - 1
		local before = deepCopy(s)
		local action: Types.Action = { type = "RespondPact", pactId = pactId, accept = true }
		expect(rejected(Engine.apply(s, target.id, action))).toBe(
			"El otro jugador ya no tiene efectivo suficiente"
		)
		expect(deepCopy(s)).toEqual(before)
	end)

	it("admite aceptar con el efectivo justo", function()
		local s = Fixtures.game({ players = 2 })
		local proposer = inTurn(s)
		local target = rivalsOf(s, proposer.id)[1]
		local pactId = proposePact(s, proposer.id, target.id, 2)
		proposer.cash = Economy.pact.deposit
		target.cash = Economy.pact.deposit
		local action: Types.Action = { type = "RespondPact", pactId = pactId, accept = true }
		local result = Engine.apply(s, target.id, action)
		expect(result.ok).toBe(true)
		expect(proposer.cash).toBe(0)
		expect(target.cash).toBe(0)
	end)

	it("rechazar quita la oferta sin eventos ni mover dinero", function()
		local s = Fixtures.game({ players = 2 })
		local proposer = inTurn(s)
		local target = rivalsOf(s, proposer.id)[1]
		local pactId = proposePact(s, proposer.id, target.id, 3)
		local action: Types.Action = { type = "RespondPact", pactId = pactId, accept = false }
		local result = Engine.apply(s, target.id, action)
		if not result.ok then
			error(result.error, 2)
		end
		expect(result.events).toEqual({})
		expect(#offersOf(s)).toBe(0)
		expect(s.pacts).toEqual({})
		expect(proposer.cash).toBe(Economy.startingCash)
		expect(target.cash).toBe(Economy.startingCash)
	end)

	it("solo el destinatario puede responder", function()
		local s = Fixtures.game({ players = 3 })
		local proposer = inTurn(s)
		local others = rivalsOf(s, proposer.id)
		local pactId = proposePact(s, proposer.id, others[1].id, 2)
		local before = deepCopy(s)
		local action: Types.Action = { type = "RespondPact", pactId = pactId, accept = false }
		expect(rejected(Engine.apply(s, proposer.id, action))).toBe("Solo el destinatario puede responder")
		expect(rejected(Engine.apply(s, others[2].id, action))).toBe("Solo el destinatario puede responder")
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza una oferta inexistente", function()
		local s = Fixtures.game({ players = 2 })
		local target = rivalsOf(s, inTurn(s).id)[1]
		local action: Types.Action = { type = "RespondPact", pactId = "P9", accept = true }
		expect(rejected(Engine.apply(s, target.id, action))).toBe("La oferta ya no existe")
	end)

	it("rechaza aceptar si el proponente ya no puede pactar", function()
		local s = Fixtures.game({ players = 2 })
		local proposer = inTurn(s)
		local target = rivalsOf(s, proposer.id)[1]
		local pactId = proposePact(s, proposer.id, target.id, 2)
		proposer.status = "Ghost"
		local before = deepCopy(s)
		local action: Types.Action = { type = "RespondPact", pactId = pactId, accept = true }
		expect(rejected(Engine.apply(s, target.id, action))).toBe("El otro jugador ya no puede pactar")
		expect(deepCopy(s)).toEqual(before)
	end)
end)

describe("Pact.exemptsRent y Property.payRent", function()
	it("exime de renta a los dos socios en ambos sentidos", function()
		local s = Fixtures.game({ players = 3 })
		local proposer = inTurn(s)
		local partner = rivalsOf(s, proposer.id)[1]
		formPact(s, proposer.id, partner.id, 3)
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, proposer.id, idx)

		expect(Pact.exemptsRent(s, proposer.id, partner.id)).toBe(true)
		expect(Pact.exemptsRent(s, partner.id, proposer.id)).toBe(true)
		local cash = partner.cash
		expect(Property.payRent(s, partner.id, idx)).toEqual({})
		expect(partner.cash).toBe(cash)
		expect(proposer.cash).toBe(Economy.startingCash - Economy.pact.deposit)

		-- La propiedad también exime en el sentido contrario.
		local other = Fixtures.squareOf(s, "Property") + 1
		Fixtures.give(s, partner.id, other)
		cash = proposer.cash
		expect(Property.payRent(s, proposer.id, other)).toEqual({})
		expect(proposer.cash).toBe(cash)
	end)

	it("no exime a un tercero ni antes de formarse el pacto", function()
		local s = Fixtures.game({ players = 3 })
		local proposer = inTurn(s)
		local others = rivalsOf(s, proposer.id)
		local partner, third = others[1], others[2]
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, proposer.id, idx)
		local offer = proposePact(s, proposer.id, partner.id, 2)
		expect(Pact.exemptsRent(s, partner.id, proposer.id)).toBe(false)
		local action: Types.Action = { type = "RespondPact", pactId = offer, accept = true }
		expect(Engine.apply(s, partner.id, action).ok).toBe(true)
		expect(Pact.exemptsRent(s, third.id, proposer.id)).toBe(false)
		local rent = math.floor((s.board.squares[idx].price :: number) * Economy.baseRentRate)
		Property.payRent(s, third.id, idx)
		expect(third.cash).toBe(Economy.startingCash - rent)
	end)

	it("sigue eximiendo en la última ronda del pacto y deja de hacerlo después", function()
		local s = Fixtures.game({ players = 2 })
		local proposer = inTurn(s)
		local partner = rivalsOf(s, proposer.id)[1]
		formPact(s, proposer.id, partner.id, 2)
		local pact = s.pacts[1]
		s.round = pact.untilRound
		expect(Pact.exemptsRent(s, proposer.id, partner.id)).toBe(true)
		s.round = pact.untilRound + 1
		expect(Pact.exemptsRent(s, proposer.id, partner.id)).toBe(false)
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, proposer.id, idx)
		Property.payRent(s, partner.id, idx)
		expect(partner.cash < Economy.startingCash - Economy.pact.deposit).toBe(true)
	end)
end)

describe("caducidad de los pactos", function()
	it("al empezar la ronda siguiente cada socio recupera su garantía", function()
		local s = Fixtures.game({ players = 2 })
		local proposer = inTurn(s)
		local partner = rivalsOf(s, proposer.id)[1]
		local pactId = formPact(s, proposer.id, partner.id, 3)
		expect(s.pacts[1].untilRound).toBe(3)
		expect(proposer.cash).toBe(Economy.startingCash - Economy.pact.deposit)
		expect(partner.cash).toBe(Economy.startingCash - Economy.pact.deposit)

		enterNextRoundFrom(s, 4)
		local events = Turn.next(s)
		expect(s.round).toBe(4)
		local ended = eventOf(events, "PactEnded")
		expect(ended.pactId).toBe(pactId)
		expect(countOf(events, "PactEnded")).toBe(1)
		expect(s.pacts).toEqual({})
		expect(proposer.cash).toBe(Economy.startingCash)
		expect(partner.cash).toBe(Economy.startingCash)
	end)

	it("no caduca antes de su última ronda", function()
		local s = Fixtures.game({ players = 2 })
		local proposer = inTurn(s)
		local partner = rivalsOf(s, proposer.id)[1]
		formPact(s, proposer.id, partner.id, 3)
		enterNextRoundFrom(s, 3)
		local events = Turn.next(s)
		expect(s.round).toBe(3)
		expect(countOf(events, "PactEnded")).toBe(0)
		expect(#s.pacts).toBe(1)
		expect(proposer.cash).toBe(Economy.startingCash - Economy.pact.deposit)
	end)

	it("emite un PactEnded por cada pacto caducado", function()
		local s = Fixtures.game({ players = 3 })
		local proposer = inTurn(s)
		local others = rivalsOf(s, proposer.id)
		local first = formPact(s, proposer.id, others[1].id, 1)
		Fixtures.turnOf(s, proposer.id)
		local second = formPact(s, proposer.id, others[2].id, 2)
		enterNextRoundFrom(s, 2)
		local events = Turn.next(s)
		expect(countOf(events, "PactEnded")).toBe(1)
		expect(eventOf(events, "PactEnded").pactId).toBe(first)
		expect(#s.pacts).toBe(1)
		expect(s.pacts[1].id).toBe(second)
	end)
end)

describe("romper un pacto", function()
	it("el traidor pierde su garantía, el socio cobra las dos y queda marcado 3 rondas", function()
		local s = Fixtures.game({ players = 2 })
		local proposer = inTurn(s)
		local partner = rivalsOf(s, proposer.id)[1]
		local pactId = formPact(s, proposer.id, partner.id, 3)
		local action: Types.Action = { type = "BreakPact", pactId = pactId }
		local result = Engine.apply(s, proposer.id, action)
		if not result.ok then
			error(result.error, 2)
		end
		local expected: { Types.Event } = { { type = "PactBroken", pactId = pactId, playerId = proposer.id } }
		expect(result.events).toEqual(expected)
		expect(s.pacts).toEqual({})
		expect(proposer.cash).toBe(Economy.startingCash - Economy.pact.deposit)
		expect(partner.cash).toBe(Economy.startingCash + Economy.pact.deposit)
		local traitorUntilRound = proposer.traitorUntilRound
		if not traitorUntilRound then
			error("la marca de Traidor no se escribió", 2)
		end
		expect(traitorUntilRound).toBe(s.round + Economy.pact.traitorRounds - 1)
		expect(traitorUntilRound - s.round + 1).toBe(Economy.pact.traitorRounds)
		expect(partner.traitorUntilRound).toBe(nil)
		expect(s.stats[proposer.id].pactsBroken).toBe(1)
		expect(s.stats[partner.id].pactsBroken).toBe(nil)
		expect(Pact.exemptsRent(s, proposer.id, partner.id)).toBe(false)
	end)

	it("el socio también puede romperlo", function()
		local s = Fixtures.game({ players = 2 })
		local proposer = inTurn(s)
		local partner = rivalsOf(s, proposer.id)[1]
		local pactId = formPact(s, proposer.id, partner.id, 3)
		local action: Types.Action = { type = "BreakPact", pactId = pactId }
		local result = Engine.apply(s, partner.id, action)
		expect(result.ok).toBe(true)
		expect(partner.cash).toBe(Economy.startingCash - Economy.pact.deposit)
		expect(proposer.cash).toBe(Economy.startingCash + Economy.pact.deposit)
		expect(partner.traitorUntilRound).toBe(s.round + Economy.pact.traitorRounds - 1)
		expect(proposer.traitorUntilRound).toBe(nil)
	end)

	it("rechaza romper un pacto ajeno sin cambiar nada", function()
		local s = Fixtures.game({ players = 3 })
		local proposer = inTurn(s)
		local others = rivalsOf(s, proposer.id)
		local pactId = formPact(s, proposer.id, others[1].id, 2)
		local before = deepCopy(s)
		local action: Types.Action = { type = "BreakPact", pactId = pactId }
		expect(rejected(Engine.apply(s, others[2].id, action))).toBe("No participas en ese pacto")
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza un pacto inexistente", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s)
		local action: Types.Action = { type = "BreakPact", pactId = "P9" }
		expect(rejected(Engine.apply(s, actor.id, action))).toBe("El pacto no existe")
	end)

	it("no se puede romper en una fase sin turno", function()
		local s = Fixtures.game({ players = 2 })
		local proposer = inTurn(s)
		local partner = rivalsOf(s, proposer.id)[1]
		local pactId = formPact(s, proposer.id, partner.id, 2)
		s.phase = "Auction"
		local action: Types.Action = { type = "BreakPact", pactId = pactId }
		expect(rejected(Engine.apply(s, proposer.id, action))).toBe(
			"No se puede BreakPact en la fase Auction"
		)
	end)
end)

describe("bancarrota de un socio", function()
	it("termina el pacto y el superviviente recupera su garantía; la del arruinado se pierde", function()
		local s = Fixtures.game({ players = 3 })
		local fallen = inTurn(s)
		local survivor = rivalsOf(s, fallen.id)[1]
		local pactId = formPact(s, fallen.id, survivor.id, 3)
		expect(fallen.cash).toBe(Economy.startingCash - Economy.pact.deposit)
		expect(survivor.cash).toBe(Economy.startingCash - Economy.pact.deposit)
		fallen.cash = 0

		local events = Bankruptcy.charge(s, fallen.id, 500, survivor.id)
		expect(fallen.status).toBe("Ghost")
		expect(s.pacts).toEqual({})
		expect(countOf(events, "PactEnded")).toBe(1)
		expect(eventOf(events, "PactEnded").pactId).toBe(pactId)
		-- La garantía del arruinado no se acredita a nadie y el socio recupera la suya.
		expect(survivor.cash).toBe(Economy.startingCash)
		expect(fallen.cash).toBe(0)
	end)

	it("funciona con el arruinado como parte b del pacto", function()
		local s = Fixtures.game({ players = 3 })
		local survivor = inTurn(s)
		local fallen = rivalsOf(s, survivor.id)[1]
		local pactId = formPact(s, survivor.id, fallen.id, 3)
		fallen.cash = 0
		local events = Bankruptcy.charge(s, fallen.id, 500, survivor.id)
		expect(eventOf(events, "PactEnded").pactId).toBe(pactId)
		expect(s.pacts).toEqual({})
		expect(survivor.cash).toBe(Economy.startingCash)
		expect(Pact.exemptsRent(s, survivor.id, fallen.id)).toBe(false)
	end)
end)

describe("perk Negociador", function()
	it("reduce la garantía del titular cuando responde", function()
		local s = Fixtures.game({ players = 2 })
		local proposer = inTurn(s)
		local partner = rivalsOf(s, proposer.id)[1]
		table.insert(partner.perks, "Negotiator")
		local pactId = formPact(s, proposer.id, partner.id, 2)
		expect(s.pacts[1].id).toBe(pactId)
		expect(s.pacts[1].depositA).toBe(Economy.pact.deposit)
		expect(s.pacts[1].depositB).toBe(Economy.pact.negotiatorDeposit)
		expect(proposer.cash).toBe(Economy.startingCash - Economy.pact.deposit)
		expect(partner.cash).toBe(Economy.startingCash - Economy.pact.negotiatorDeposit)
	end)

	it("reduce la garantía del titular cuando propone", function()
		local s = Fixtures.game({ players = 2 })
		local proposer = inTurn(s)
		local partner = rivalsOf(s, proposer.id)[1]
		table.insert(proposer.perks, "Negotiator")
		formPact(s, proposer.id, partner.id, 2)
		expect(s.pacts[1].depositA).toBe(Economy.pact.negotiatorDeposit)
		expect(s.pacts[1].depositB).toBe(Economy.pact.deposit)
		expect(proposer.cash).toBe(Economy.startingCash - Economy.pact.negotiatorDeposit)
		expect(partner.cash).toBe(Economy.startingCash - Economy.pact.deposit)
	end)

	it("al caducar cada uno recupera exactamente lo que depositó", function()
		local s = Fixtures.game({ players = 2 })
		local proposer = inTurn(s)
		local partner = rivalsOf(s, proposer.id)[1]
		table.insert(proposer.perks, "Negotiator")
		formPact(s, proposer.id, partner.id, 2)
		enterNextRoundFrom(s, 3)
		Turn.next(s)
		expect(s.pacts).toEqual({})
		expect(proposer.cash).toBe(Economy.startingCash)
		expect(partner.cash).toBe(Economy.startingCash)
	end)
end)

describe("Engine y los pactos", function()
	it("no enumera las acciones de pacto en el espacio finito", function()
		local s = Fixtures.game({ players = 3 })
		local actor = inTurn(s).id
		for _, action in Engine.legalActions(s, actor) do
			expect(action.type ~= "ProposePact").toBe(true)
			expect(action.type ~= "RespondPact").toBe(true)
			expect(action.type ~= "BreakPact").toBe(true)
		end
	end)

	it("Pact.propose y Pact.respond funcionan también como llamadas directas", function()
		local s = Fixtures.game({ players = 2 })
		local proposer = inTurn(s)
		local partner = rivalsOf(s, proposer.id)[1]
		local result = Pact.propose(s, proposer.id, partner.id, 2)
		if not result.ok then
			error(result.error, 2)
		end
		local offers = offersOf(s)
		expect(#offers).toBe(1)
		local accepted = Pact.respond(s, partner.id, offers[1].id, true)
		if not accepted.ok then
			error(accepted.error, 2)
		end
		expect(#s.pacts).toBe(1)
		expect(countOf(accepted.events, "PactFormed")).toBe(1)
	end)
end)

describe("Puñalada sobre un pacto formado por el módulo", function()
	it("deja el estado coherente: pacto fuera, garantías devueltas y marca de Traidor", function()
		local s = Fixtures.game({ players = 2 })
		local caster = inTurn(s)
		local partner = rivalsOf(s, caster.id)[1]
		local pactId = formPact(s, caster.id, partner.id, 3)
		Fixtures.hand(s, caster.id, "Backstab")

		local action: Types.Action = { type = "PlayCard", cardId = "Backstab", pactId = pactId }
		local result = Engine.apply(s, caster.id, action)
		if not result.ok then
			error(result.error, 2)
		end
		expect(s.pacts).toEqual({})
		expect(caster.cash).toBe(Economy.startingCash)
		expect(partner.cash).toBe(Economy.startingCash)
		expect(eventOf(result.events, "PactBroken").pactId).toBe(pactId)
		expect(caster.traitorUntilRound).toBe(s.round + Economy.pact.traitorRounds - 1)
		expect(Pact.exemptsRent(s, caster.id, partner.id)).toBe(false)
		expect(s.stats[caster.id].pactsBroken).toBe(1)
	end)
end)

describe("cierre de la partida (R-P46)", function()
	it("al llegar al límite de rondas devuelve las garantías antes de la clasificación final", function()
		local s = Fixtures.game({ players = 2 })
		local proposer = s.players[1]
		local partner = s.players[2]
		table.insert(partner.perks, "Negotiator")
		local pactId = formPact(s, proposer.id, partner.id, 3)
		expect(s.pacts[1].id).toBe(pactId)
		-- Con Negociador el socio deposita 50: sin liquidar el pacto, su efectivo (1450) supera
		-- al del proponente (1400) y la clasificación final sería otra.
		expect(proposer.cash).toBe(Economy.startingCash - Economy.pact.deposit)
		expect(partner.cash).toBe(Economy.startingCash - Economy.pact.negotiatorDeposit)
		local maxRounds = s.maxRounds
		if not maxRounds then
			error("el modo Rounds debe tener tope de rondas", 2)
		end
		enterNextRoundFrom(s, maxRounds + 1)
		local events = Turn.next(s)
		expect(s.phase).toBe("GameOver")
		expect(s.pacts).toEqual({})
		expect(proposer.cash).toBe(Economy.startingCash)
		expect(partner.cash).toBe(Economy.startingCash)
		expect(eventOf(events, "PactEnded").pactId).toBe(pactId)
		-- Ya liquidadas las garantías, el desempate por orden de turno deja al proponente
		-- (players[1]) por delante del socio (players[2]).
		local ended = eventOf(events, "GameEnded")
		expect(ended.winnerId).toBe(proposer.id)
		local expected: { Types.PlayerId } = { proposer.id, partner.id }
		expect(ended.ranking).toEqual(expected)
		expect(ended.ranking).toEqual(Score.ranking(s))
		-- Las garantías se devuelven antes de anunciar el final.
		local pactAt, gameAt = 0, 0
		for index, event in events do
			if event.type == "PactEnded" then
				pactAt = index
			elseif event.type == "GameEnded" then
				gameAt = index
			end
		end
		expect(pactAt > 0 and pactAt < gameAt).toBe(true)
		-- El cierre es idempotente: una segunda llamada no vuelve a devolver nada.
		expect(Turn.next(s)).toEqual({})
		expect(proposer.cash).toBe(Economy.startingCash)
	end)

	it("si la partida termina por último activo también liquida los pactos", function()
		local s = Fixtures.game({ players = 2 })
		local proposer = s.players[1]
		local partner = s.players[2]
		formPact(s, proposer.id, partner.id, 3)
		-- Estado ilegal a propósito: el socio cae sin pasar por Bankruptcy.charge, así que su
		-- pacto sigue vivo cuando la partida se cierra por último activo.
		partner.status = "Ghost"
		local events: { Types.Event } = {}
		expect(Turn.finishIfLastActive(s, events)).toBe(true)
		expect(events[1].type).toBe("PactEnded")
		expect(events[2].type).toBe("GameEnded")
		expect(s.pacts).toEqual({})
		expect(proposer.cash).toBe(Economy.startingCash)
		expect(partner.cash).toBe(Economy.startingCash - Economy.pact.deposit)
	end)

	it("Pact.settle devuelve todas las garantías y emite un PactEnded por pacto", function()
		local s = Fixtures.game({ players = 3 })
		local proposer = inTurn(s)
		local others = rivalsOf(s, proposer.id)
		local first = formPact(s, proposer.id, others[1].id, 2)
		Fixtures.turnOf(s, proposer.id)
		local second = formPact(s, proposer.id, others[2].id, 2)
		local events = Pact.settle(s)
		expect(#events).toBe(2)
		expect(s.pacts).toEqual({})
		expect(proposer.cash).toBe(Economy.startingCash)
		expect(others[1].cash).toBe(Economy.startingCash)
		expect(others[2].cash).toBe(Economy.startingCash)
		local ids: { string } = {}
		for _, event in events do
			table.insert(ids, event.pactId)
		end
		table.sort(ids)
		local expected: { string } = { first, second }
		table.sort(expected)
		expect(ids).toEqual(expected)
	end)
end)

describe("Puñalada con un socio fuera de la partida (R-P42)", function()
	it("la garantía de un socio que abandonó se queda en el banco", function()
		local s = Fixtures.game({ players = 2 })
		local caster = inTurn(s)
		local partner = rivalsOf(s, caster.id)[1]
		local pactId = formPact(s, caster.id, partner.id, 3)
		partner.status = "Left"
		Fixtures.hand(s, caster.id, "Backstab")
		local action: Types.Action = { type = "PlayCard", cardId = "Backstab", pactId = pactId }
		local result = Engine.apply(s, caster.id, action)
		if not result.ok then
			error(result.error, 2)
		end
		expect(s.pacts).toEqual({})
		-- El lanzador activo conserva su garantía; la del socio no se acredita a nadie.
		expect(caster.cash).toBe(Economy.startingCash)
		expect(partner.cash).toBe(Economy.startingCash - Economy.pact.deposit)
		expect(eventOf(result.events, "PactBroken").playerId).toBe(caster.id)
		expect(caster.traitorUntilRound).toBe(s.round + Economy.pact.traitorRounds - 1)
	end)
end)

describe("caducidad de las ofertas (R-P44)", function()
	it("una oferta muere al terminar el turno en que se hizo", function()
		local s = Fixtures.game({ players = 3 })
		local proposer = inTurn(s)
		local target = rivalsOf(s, proposer.id)[1]
		local pactId = proposePact(s, proposer.id, target.id, 3)
		expect(#offersOf(s)).toBe(1)
		Fixtures.turnOf(s, proposer.id)
		Turn.next(s)
		expect(#offersOf(s)).toBe(0)
		expect(s.pacts).toEqual({})
		local action: Types.Action = { type = "RespondPact", pactId = pactId, accept = true }
		expect(rejected(Engine.apply(s, target.id, action))).toBe("La oferta ya no existe")
		-- La siguiente propuesta del mismo jugador recibe un id nuevo.
		Fixtures.turnOf(s, proposer.id)
		expect(proposePact(s, proposer.id, target.id, 3) ~= pactId).toBe(true)
	end)
end)

-- Primera propiedad alcanzable con dos pasos de dado desde otra casilla, igual que en
-- Reaction.spec: la renta nace de una tirada real para que la ventana se abra en el motor.
local function rentableIndex(state: Types.GameState): number
	for _, square in state.board.squares do
		if square.kind == "Property" and square.index >= 4 then
			return square.index
		end
	end
	error("el tablero no tiene una propiedad alcanzable con dos pasos", 2)
end

describe("Renta Rebotada y pactos (R-P45)", function()
	it("un socio no paga la renta desviada a su compañero de pacto", function()
		local s = Fixtures.game({ players = 3 })
		local payer = inTurn(s)
		local rivals = rivalsOf(s, payer.id)
		local owner, third = rivals[1], rivals[2]
		-- El pacto es entre el dueño y el tercero: la renta rebotada al tercero no se cobra.
		Fixtures.turnOf(s, owner.id)
		formPact(s, owner.id, third.id, 3)
		Fixtures.turnOf(s, payer.id)
		local ownerCash = owner.cash
		local thirdCash = third.cash
		Fixtures.hand(s, payer.id, "BounceRent")
		local index = rentableIndex(s)
		Fixtures.give(s, owner.id, index)
		Fixtures.placeOn(s, payer.id, index - 2)
		Fixtures.dice(s, 1, 1)
		local rolled = Engine.apply(s, payer.id, { type = "Roll" })
		if not rolled.ok then
			error(rolled.error, 2)
		end
		expect(s.phase).toBe("Reaction")
		local action: Types.Action = { type = "React", cardId = "BounceRent", targetId = third.id }
		local result = Engine.apply(s, payer.id, action)
		if not result.ok then
			error(result.error, 2)
		end
		expect(result.events).toEqual({})
		expect(s.phase).toBe("AwaitEnd")
		expect(third.cash).toBe(thirdCash)
		expect(owner.cash).toBe(ownerCash)
		expect(payer.cash).toBe(Economy.startingCash)
	end)
end)

--!strict
-- Intercambios: propuestas, respuestas, revalidación al aceptar y caducidad.
local Harness = require("../harness")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Trade = require("../../src/shared/rules/Trade")
local Types = require("../../src/shared/rules/Types")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

type TradeOffer = Trade.TradeOffer

local function inTurn(state: Types.GameState): Types.Player
	return state.players[state.turnIndex]
end

-- Otro jugador de la partida, distinto del indicado.
local function otherThan(state: Types.GameState, playerId: Types.PlayerId): Types.Player
	for _, player in state.players do
		if player.id ~= playerId then
			return player
		end
	end
	error("la partida necesita al menos dos jugadores", 2)
end

-- Exige un rechazo y devuelve el mensaje para poder comprobarlo.
local function rejected(result: Types.ApplyResult): string
	if result.ok then
		error("se esperaba un rechazo y la acción se aplicó", 3)
	end
	expect(result.error ~= "").toBe(true)
	return result.error
end

-- El contrato fija pending como tabla persistente que State.create siempre crea.
local function pendingOf(state: Types.GameState): any
	local pending = state.pending
	if not pending then
		error("el estado no tiene pending", 2)
	end
	return pending
end

local function tradesOf(state: Types.GameState): { any }
	return pendingOf(state).trades
end

describe("Trade: tope de ofertas abiertas", function()
	it("rechaza pasar del tope sin guardar nada", function()
		local s = Fixtures.game({ players = 3 })
		local from = inTurn(s)
		local to = otherThan(s, from.id)
		local offer: TradeOffer =
			{ toId = to.id, giveCash = 1, wantCash = 0, giveSquares = {}, wantSquares = {} }
		for _ = 1, Economy.maxOpenOffers do
			expect(Engine.apply(s, from.id, { type = "ProposeTrade", offer = offer }).ok).toBe(true)
		end
		expect(rejected(Engine.apply(s, from.id, { type = "ProposeTrade", offer = offer }))).toBe(
			"Tienes demasiadas ofertas abiertas"
		)
		expect(#tradesOf(s)).toBe(Economy.maxOpenOffers)
	end)
end)

-- Las primeras `count` casillas de propiedad, en orden de tablero.
local function propertySquares(state: Types.GameState, count: number): { number }
	local squares: { number } = {}
	for _, square in state.board.squares do
		if square.kind == "Property" then
			table.insert(squares, square.index)
			if #squares == count then
				return squares
			end
		end
	end
	error(`el tablero no tiene {count} propiedades`, 2)
end

-- Partida de dos jugadores con una casilla de cada uno ya repartida.
local function setup(): (Types.GameState, Types.Player, Types.Player, number, number)
	local state = Fixtures.game({ players = 2 })
	local a = inTurn(state)
	local b = otherThan(state, a.id)
	local squares = propertySquares(state, 2)
	Fixtures.give(state, a.id, squares[1])
	Fixtures.give(state, b.id, squares[2])
	return state, a, b, squares[1], squares[2]
end

-- Oferta vacía: ni dinero ni casillas.
local function offerTo(toId: Types.PlayerId): TradeOffer
	return { toId = toId, giveCash = 0, wantCash = 0, giveSquares = {}, wantSquares = {} }
end

-- Propone por la vía directa y exige que se acepte; devuelve la oferta guardada.
local function propose(state: Types.GameState, fromId: Types.PlayerId, offer: TradeOffer): any
	local result = Trade.propose(state, fromId, offer)
	if not result.ok then
		error(result.error, 2)
	end
	return tradesOf(state)[#tradesOf(state)]
end

describe("propuestas", function()
	it("registra una oferta válida con id determinista y el turno en que se hizo", function()
		local s, a, b, mine, theirs = setup()
		local round, turnIndex = s.round, s.turnIndex
		local offer = offerTo(b.id)
		offer.giveCash = 200
		offer.wantCash = 50
		offer.giveSquares = { mine }
		offer.wantSquares = { theirs }
		local result = Trade.propose(s, a.id, offer)
		expect(result).toEqual({ ok = true, events = {} })
		expect(#tradesOf(s)).toBe(1)
		expect(tradesOf(s)[1]).toEqual({
			id = "T1",
			fromId = a.id,
			toId = b.id,
			giveCash = 200,
			wantCash = 50,
			giveSquares = { mine },
			wantSquares = { theirs },
			round = round,
			turnIndex = turnIndex,
		})
		expect(pendingOf(s).tradeSeq).toBe(1)
		-- Proponer no mueve dinero, casillas ni fase.
		expect(a.cash).toBe(Economy.startingCash)
		expect(b.cash).toBe(Economy.startingCash)
		expect(s.properties[mine].ownerId).toBe(a.id)
		expect(s.properties[theirs].ownerId).toBe(b.id)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("no renumera las ofertas existentes: la siguiente es T2", function()
		local s, a, b = setup()
		local first = offerTo(b.id)
		first.giveCash = 10
		propose(s, a.id, first)
		expect(Trade.respond(s, b.id, "T1", false)).toEqual({ ok = true, events = {} })
		local second = offerTo(b.id)
		second.giveCash = 20
		expect(propose(s, a.id, second).id).toBe("T2")
		expect(pendingOf(s).tradeSeq).toBe(2)
		expect(#tradesOf(s)).toBe(1)
	end)

	it("rechaza ofrecer una casilla de otro jugador", function()
		local s, a, b, _, theirs = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 100
		offer.giveSquares = { theirs }
		expect(rejected(Trade.propose(s, a.id, offer))).toBe("No puedes ofrecer una casilla que no es tuya")
		expect(#tradesOf(s)).toBe(0)
		expect(pendingOf(s).tradeSeq).toBe(nil)
	end)

	it("rechaza pedir una casilla que el otro jugador no tiene", function()
		local s, a, b = setup()
		local free = propertySquares(s, 3)[3]
		local offer = offerTo(b.id)
		offer.wantSquares = { free }
		expect(rejected(Trade.propose(s, a.id, offer))).toBe(
			"No puedes pedir una casilla que el otro jugador no tiene"
		)
		expect(#tradesOf(s)).toBe(0)
	end)

	it("rechaza intercambiar casillas con edificios", function()
		local s, a, b, mine, theirs = setup()
		local give = offerTo(b.id)
		give.giveSquares = { mine }
		s.properties[mine].level = 1
		expect(rejected(Trade.propose(s, a.id, give))).toBe(
			"No se pueden intercambiar propiedades con edificios"
		)
		s.properties[mine].level = 0
		local want = offerTo(b.id)
		want.wantSquares = { theirs }
		s.properties[theirs].level = 2
		expect(rejected(Trade.propose(s, a.id, want))).toBe(
			"No se pueden intercambiar propiedades con edificios"
		)
		expect(#tradesOf(s)).toBe(0)
	end)

	it("rechaza una oferta que repite una casilla", function()
		local s, a, b, mine, theirs = setup()
		local give = offerTo(b.id)
		give.giveSquares = { mine, mine }
		expect(rejected(Trade.propose(s, a.id, give))).toBe("La oferta repite una casilla")
		local want = offerTo(b.id)
		want.wantSquares = { theirs, theirs }
		expect(rejected(Trade.propose(s, a.id, want))).toBe("La oferta repite una casilla")
		expect(#tradesOf(s)).toBe(0)
	end)

	it("rechaza una oferta sin nada en ninguno de los dos lados", function()
		local s, a, b = setup()
		expect(rejected(Trade.propose(s, a.id, offerTo(b.id)))).toBe("El intercambio no ofrece ni pide nada")
		expect(#tradesOf(s)).toBe(0)
	end)

	it("rechaza ofrecer más efectivo del que se tiene y admite ofrecerlo todo", function()
		local s, a, b = setup()
		a.cash = 100
		local tooMuch = offerTo(b.id)
		tooMuch.giveCash = 101
		expect(rejected(Trade.propose(s, a.id, tooMuch))).toBe("No tienes efectivo suficiente")
		local all = offerTo(b.id)
		all.giveCash = 100
		expect(Trade.propose(s, a.id, all).ok).toBe(true)
		expect(a.cash).toBe(100)
	end)

	it("rechaza importes que no son enteros no negativos", function()
		local s, a, b = setup()
		local half = offerTo(b.id)
		half.giveCash = 10.5
		expect(rejected(Trade.propose(s, a.id, half))).toBe("Los importes del intercambio no son válidos")
		local negative = offerTo(b.id)
		negative.wantCash = -10
		expect(rejected(Trade.propose(s, a.id, negative))).toBe(
			"Los importes del intercambio no son válidos"
		)
		expect(#tradesOf(s)).toBe(0)
	end)

	it("rechaza proponerse un intercambio a uno mismo", function()
		local s, a = setup()
		local offer = offerTo(a.id)
		offer.giveCash = 10
		expect(rejected(Trade.propose(s, a.id, offer))).toBe("No puedes proponerte un intercambio a ti mismo")
		expect(#tradesOf(s)).toBe(0)
	end)

	it("rechaza una oferta a un jugador que no existe", function()
		local s, a = setup()
		local offer = offerTo("P9")
		offer.giveCash = 10
		expect(rejected(Trade.propose(s, a.id, offer))).toBe("El jugador P9 no está en la partida")
		expect(#tradesOf(s)).toBe(0)
	end)

	it("rechaza una oferta a un espectro o a quien abandonó la partida", function()
		local s, a, b = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 10
		b.status = "Ghost"
		expect(rejected(Trade.propose(s, a.id, offer))).toBe(
			"Solo se puede intercambiar con un jugador activo"
		)
		b.status = "Left"
		expect(rejected(Trade.propose(s, a.id, offer))).toBe("El otro jugador ha abandonado la partida")
		expect(#tradesOf(s)).toBe(0)
	end)

	it("rechaza proponer fuera de turno", function()
		local s, _, b = setup()
		local offer = offerTo(inTurn(s).id)
		offer.giveCash = 10
		expect(rejected(Trade.propose(s, b.id, offer))).toBe("No es tu turno")
		expect(#tradesOf(s)).toBe(0)
	end)

	it("rechaza proponer fuera de las fases de turno", function()
		local s, a, b = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 10
		s.phase = "AwaitBuy"
		expect(rejected(Trade.propose(s, a.id, offer))).toBe(
			"No se puede proponer un intercambio en la fase AwaitBuy"
		)
		expect(#tradesOf(s)).toBe(0)
	end)

	it("un espectro no propone", function()
		local s, a, b = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 10
		a.status = "Ghost"
		expect(rejected(Trade.propose(s, a.id, offer))).toBe("Solo los jugadores activos pueden intercambiar")
		expect(#tradesOf(s)).toBe(0)
	end)

	it("un jugador que abandonó la partida no propone", function()
		local s, a, b = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 10
		a.status = "Left"
		expect(rejected(Trade.propose(s, a.id, offer))).toBe("El jugador ha abandonado la partida")
		expect(#tradesOf(s)).toBe(0)
	end)
end)

describe("respuestas", function()
	it("acepta la oferta: cambia el efectivo y las casillas, la elimina y emite TradeCompleted", function()
		local s, a, b, mine, theirs = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 200
		offer.wantCash = 50
		offer.giveSquares = { mine }
		offer.wantSquares = { theirs }
		propose(s, a.id, offer)
		local result = Trade.respond(s, b.id, "T1", true)
		expect(result).toEqual({
			ok = true,
			events = { { type = "TradeCompleted", fromId = a.id, toId = b.id, tradeId = "T1" } },
		})
		expect(a.cash).toBe(Economy.startingCash - 200 + 50)
		expect(b.cash).toBe(Economy.startingCash + 200 - 50)
		expect(s.properties[mine].ownerId).toBe(b.id)
		expect(s.properties[theirs].ownerId).toBe(a.id)
		expect(#tradesOf(s)).toBe(0)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("rechazar la oferta la elimina sin mover nada", function()
		local s, a, b, mine, theirs = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 200
		offer.giveSquares = { mine }
		propose(s, a.id, offer)
		expect(Trade.respond(s, b.id, "T1", false)).toEqual({ ok = true, events = {} })
		expect(a.cash).toBe(Economy.startingCash)
		expect(b.cash).toBe(Economy.startingCash)
		expect(s.properties[mine].ownerId).toBe(a.id)
		expect(s.properties[theirs].ownerId).toBe(b.id)
		expect(#tradesOf(s)).toBe(0)
	end)

	it("solo el destinatario puede responder", function()
		local s, a, b, mine = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 100
		offer.giveSquares = { mine }
		propose(s, a.id, offer)
		expect(rejected(Trade.respond(s, a.id, "T1", true))).toBe("Solo el destinatario puede responder")
		expect(rejected(Trade.respond(s, a.id, "T1", false))).toBe("Solo el destinatario puede responder")
		expect(#tradesOf(s)).toBe(1)
		expect(a.cash).toBe(Economy.startingCash)
		expect(s.properties[mine].ownerId).toBe(a.id)
	end)

	it("rechaza una oferta que ya no existe", function()
		local s, _, b = setup()
		expect(rejected(Trade.respond(s, b.id, "T9", true))).toBe("La oferta ya no existe")
		expect(rejected(Trade.respond(s, b.id, "T9", false))).toBe("La oferta ya no existe")
	end)

	it("rechaza una respuesta que no acepta ni rechaza", function()
		local s, a, b, mine = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 100
		offer.giveSquares = { mine }
		propose(s, a.id, offer)
		expect(rejected(Engine.apply(s, b.id, { type = "RespondTrade", tradeId = "T1" }))).toBe(
			"La respuesta no es válida"
		)
		expect(#tradesOf(s)).toBe(1)
	end)

	it("rechaza responder en la fase Auction", function()
		local s, a, b, mine = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 100
		offer.giveSquares = { mine }
		propose(s, a.id, offer)
		s.phase = "Auction"
		expect(rejected(Trade.respond(s, b.id, "T1", true))).toBe(
			"No se puede responder un intercambio en la fase Auction"
		)
		expect(#tradesOf(s)).toBe(1)
		expect(a.cash).toBe(Economy.startingCash)
		expect(s.properties[mine].ownerId).toBe(a.id)
	end)

	it("rechaza responder con la partida terminada", function()
		local s, a, b, mine = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 100
		offer.giveSquares = { mine }
		propose(s, a.id, offer)
		s.phase = "GameOver"
		expect(rejected(Trade.respond(s, b.id, "T1", true))).toBe(
			"No se puede responder un intercambio en la fase GameOver"
		)
		expect(#tradesOf(s)).toBe(1)
	end)

	it("un espectro no responde", function()
		local s, a, b, mine = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 100
		offer.giveSquares = { mine }
		propose(s, a.id, offer)
		b.status = "Ghost"
		expect(rejected(Trade.respond(s, b.id, "T1", true))).toBe(
			"Solo los jugadores activos pueden intercambiar"
		)
		expect(#tradesOf(s)).toBe(1)
		expect(s.properties[mine].ownerId).toBe(a.id)
	end)

	it("un jugador que abandonó la partida no responde", function()
		local s, a, b, mine = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 100
		offer.giveSquares = { mine }
		propose(s, a.id, offer)
		b.status = "Left"
		expect(rejected(Trade.respond(s, b.id, "T1", true))).toBe("El jugador ha abandonado la partida")
		expect(#tradesOf(s)).toBe(1)
	end)
end)

describe("revalidación al aceptar", function()
	it("sin efectivo suficiente del destinatario", function()
		local s, a, b, mine = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 200
		offer.wantCash = 300
		offer.giveSquares = { mine }
		propose(s, a.id, offer)
		b.cash = 299
		expect(rejected(Trade.respond(s, b.id, "T1", true))).toBe("No tienes efectivo suficiente")
		expect(#tradesOf(s)).toBe(1)
		expect(a.cash).toBe(Economy.startingCash)
		expect(b.cash).toBe(299)
		expect(s.properties[mine].ownerId).toBe(a.id)
	end)

	it("el proponente ya no tiene el efectivo ofrecido", function()
		local s, a, b, mine = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 200
		offer.wantCash = 50
		offer.giveSquares = { mine }
		propose(s, a.id, offer)
		a.cash = 199
		expect(rejected(Trade.respond(s, b.id, "T1", true))).toBe(
			"El otro jugador ya no tiene efectivo suficiente"
		)
		expect(#tradesOf(s)).toBe(1)
		expect(a.cash).toBe(199)
		expect(b.cash).toBe(Economy.startingCash)
		expect(s.properties[mine].ownerId).toBe(a.id)
	end)

	it("una casilla ofrecida ya no es del proponente", function()
		local s, a, b, mine = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 100
		offer.giveSquares = { mine }
		propose(s, a.id, offer)
		Fixtures.give(s, b.id, mine)
		expect(rejected(Trade.respond(s, b.id, "T1", true))).toBe(
			"El otro jugador ya no posee una de las casillas"
		)
		expect(#tradesOf(s)).toBe(1)
		expect(a.cash).toBe(Economy.startingCash)
		expect(s.properties[mine].ownerId).toBe(b.id)
	end)

	it("una casilla pedida ya no es del destinatario", function()
		local s, a, b, _, theirs = setup()
		local offer = offerTo(b.id)
		offer.wantSquares = { theirs }
		propose(s, a.id, offer)
		Fixtures.give(s, a.id, theirs)
		expect(rejected(Trade.respond(s, b.id, "T1", true))).toBe("Ya no posees una de las casillas")
		expect(#tradesOf(s)).toBe(1)
		expect(s.properties[theirs].ownerId).toBe(a.id)
	end)

	it("una casilla pasó a tener edificios", function()
		local s, a, b, mine = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 100
		offer.giveSquares = { mine }
		propose(s, a.id, offer)
		s.properties[mine].level = 1
		expect(rejected(Trade.respond(s, b.id, "T1", true))).toBe(
			"No se pueden intercambiar propiedades con edificios"
		)
		expect(#tradesOf(s)).toBe(1)
		expect(a.cash).toBe(Economy.startingCash)
		expect(s.properties[mine].ownerId).toBe(a.id)
	end)

	it("el proponente es ahora un espectro", function()
		local s, a, b, mine = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 100
		offer.giveSquares = { mine }
		propose(s, a.id, offer)
		a.status = "Ghost"
		expect(rejected(Trade.respond(s, b.id, "T1", true))).toBe("El otro jugador ya no puede intercambiar")
		expect(#tradesOf(s)).toBe(1)
		expect(b.cash).toBe(Economy.startingCash)
		expect(s.properties[mine].ownerId).toBe(a.id)
	end)

	it("el proponente abandonó la partida", function()
		local s, a, b, mine = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 100
		offer.giveSquares = { mine }
		propose(s, a.id, offer)
		a.status = "Left"
		expect(rejected(Trade.respond(s, b.id, "T1", true))).toBe("El otro jugador ya no puede intercambiar")
		expect(#tradesOf(s)).toBe(1)
	end)
end)

describe("caducidad", function()
	it("la oferta caduca al terminar el turno en que se hizo", function()
		local s, a, b, mine = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 100
		offer.giveSquares = { mine }
		propose(s, a.id, offer)
		s.phase = "AwaitEnd"
		local result = Engine.apply(s, a.id, { type = "EndTurn" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(#tradesOf(s)).toBe(0)
		expect(s.players[s.turnIndex].id).toBe(b.id)
	end)

	it("solo elimina las ofertas del turno que termina", function()
		local s, a, b = setup()
		-- Oferta de una ronda anterior: no la creó este turno y no debe caducar con él.
		s.round = 2
		table.insert(tradesOf(s), {
			id = "T9",
			fromId = b.id,
			toId = a.id,
			giveCash = 0,
			wantCash = 0,
			giveSquares = {},
			wantSquares = {},
			round = s.round - 1,
			turnIndex = s.turnIndex,
		})
		local offer = offerTo(b.id)
		offer.giveCash = 100
		propose(s, a.id, offer)
		expect(#tradesOf(s)).toBe(2)
		s.phase = "AwaitEnd"
		local result = Engine.apply(s, a.id, { type = "EndTurn" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(#tradesOf(s)).toBe(1)
		expect(tradesOf(s)[1].id).toBe("T9")
	end)

	it("el contador de ids no retrocede tras la caducidad", function()
		local s, a, b = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 100
		propose(s, a.id, offer)
		s.phase = "AwaitEnd"
		local endTurn = Engine.apply(s, a.id, { type = "EndTurn" })
		if not endTurn.ok then
			error(endTurn.error, 2)
		end
		local nextPlayer = inTurn(s)
		local again = offerTo(a.id)
		again.giveCash = 100
		expect(propose(s, nextPlayer.id, again).id).toBe("T2")
		expect(pendingOf(s).tradeSeq).toBe(2)
	end)
end)

describe("Trade en el motor", function()
	it("registra ProposeTrade y RespondTrade por Engine.apply y emite TradeCompleted", function()
		local s, a, b, mine = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 150
		offer.giveSquares = { mine }
		local proposed = Engine.apply(s, a.id, { type = "ProposeTrade", offer = offer })
		if not proposed.ok then
			error(proposed.error, 2)
		end
		expect(proposed.events).toEqual({})
		expect(tradesOf(s)[1].id).toBe("T1")
		local accepted = Engine.apply(s, b.id, { type = "RespondTrade", tradeId = "T1", accept = true })
		if not accepted.ok then
			error(accepted.error, 2)
		end
		expect(accepted.events).toEqual({
			{ type = "TradeCompleted", fromId = a.id, toId = b.id, tradeId = "T1" },
		})
		expect(a.cash).toBe(Economy.startingCash - 150)
		expect(b.cash).toBe(Economy.startingCash + 150)
		expect(s.properties[mine].ownerId).toBe(b.id)
		expect(#tradesOf(s)).toBe(0)
	end)

	it("rechaza ProposeTrade fuera de turno", function()
		local s, a, b = setup()
		local offer = offerTo(a.id)
		offer.giveCash = 10
		expect(rejected(Engine.apply(s, b.id, { type = "ProposeTrade", offer = offer }))).toBe(
			"No es tu turno"
		)
		expect(#tradesOf(s)).toBe(0)
	end)

	it("rechaza ProposeTrade fuera de las fases de turno", function()
		local s, a, b = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 10
		s.phase = "AwaitBuy"
		expect(rejected(Engine.apply(s, a.id, { type = "ProposeTrade", offer = offer }))).toBe(
			"No se puede ProposeTrade en la fase AwaitBuy"
		)
		expect(#tradesOf(s)).toBe(0)
	end)

	it("rechaza ProposeTrade sin oferta", function()
		local s, a = setup()
		expect(rejected(Engine.apply(s, a.id, { type = "ProposeTrade" }))).toBe("La oferta no es válida")
		expect(#tradesOf(s)).toBe(0)
	end)

	it("rechaza RespondTrade en la fase Auction", function()
		local s, a, b, mine = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 100
		offer.giveSquares = { mine }
		propose(s, a.id, offer)
		s.phase = "Auction"
		expect(rejected(Engine.apply(s, b.id, { type = "RespondTrade", tradeId = "T1", accept = true }))).toBe(
			"No se puede RespondTrade en la fase Auction"
		)
		expect(#tradesOf(s)).toBe(1)
		expect(s.properties[mine].ownerId).toBe(a.id)
	end)

	it("permite responder durante la compra (AwaitBuy)", function()
		local s, a, b, mine = setup()
		local offer = offerTo(b.id)
		offer.giveCash = 100
		offer.giveSquares = { mine }
		propose(s, a.id, offer)
		s.phase = "AwaitBuy"
		local result = Engine.apply(s, b.id, { type = "RespondTrade", tradeId = "T1", accept = true })
		if not result.ok then
			error(result.error, 2)
		end
		expect(result.events).toEqual({
			{ type = "TradeCompleted", fromId = a.id, toId = b.id, tradeId = "T1" },
		})
		expect(s.properties[mine].ownerId).toBe(b.id)
	end)

	it("rechaza RespondTrade con la partida terminada", function()
		local s, _, b = setup()
		s.phase = "GameOver"
		expect(rejected(Engine.apply(s, b.id, { type = "RespondTrade", tradeId = "T1", accept = true }))).toBe(
			"La partida ha terminado"
		)
	end)
end)

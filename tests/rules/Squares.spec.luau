--!strict
-- Casillas nuevas de la fase 03: Giro, Mercado Negro, Duelo, Portal, Cartelera de la Suerte,
-- Tribunal e Impuesto. Cubre los efectos, las fases que abren (Market, Duel y Tribunal), sus
-- acciones, el reloj, el bot y los dos perks de sistema que dependen de ellas: Afortunado
-- (Cartelera) y Abogado (Tribunal).
local Harness = require("../harness")
local Bot = require("../../src/shared/rules/Bot")
local CardsConfig = require("../../src/shared/config/Cards")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Rng = require("../../src/shared/rules/Rng")
local Squares = require("../../src/shared/rules/Squares")
local SquaresConfig = require("../../src/shared/config/Squares")
local Types = require("../../src/shared/rules/Types")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

type GameState = Types.GameState
type Player = Types.Player
type PlayerId = Types.PlayerId
type Event = Types.Event

-- pending es la tabla persistente que State.create siempre crea (R1).
local function pendingOf(state: GameState): any
	local pending = state.pending
	if not pending then
		error("el estado no tiene pending", 2)
	end
	return pending
end

local function inTurn(state: GameState): Player
	return state.players[state.turnIndex]
end

-- Primer rival activo en el orden de turnos.
local function rivalOf(state: GameState, playerId: PlayerId): Player
	for _, player in state.players do
		if player.id ~= playerId and player.status == "Active" then
			return player
		end
	end
	error(`no hay ningún rival activo de {playerId}`, 2)
end

-- Todos los rivales activos en el orden de turnos.
local function activeRivals(state: GameState, playerId: PlayerId): { Player }
	local rivals: { Player } = {}
	for _, player in state.players do
		if player.id ~= playerId and player.status == "Active" then
			table.insert(rivals, player)
		end
	end
	return rivals
end

-- Asiento del jugador en el orden de turno (1-based), para calcular lo que elige el bot.
local function seatOf(state: GameState, playerId: PlayerId): number
	for index, player in state.players do
		if player.id == playerId then
			return index
		end
	end
	error(`no existe el jugador {playerId}`, 2)
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

-- Aplica una acción legal y devuelve sus eventos.
local function applyOk(state: GameState, playerId: PlayerId, action: Types.Action): { Event }
	local result = Engine.apply(state, playerId, action)
	if not result.ok then
		error(result.error, 2)
	end
	return result.events
end

-- Primer evento del tipo pedido, para no depender de los dados y el movimiento que emite Roll.
local function firstEvent(events: { Event }, eventType: string): Event
	for _, event in events do
		if event.type == eventType then
			return event
		end
	end
	error(`no hay ningún evento {eventType}`, 2)
end

-- Las acciones legales son exactamente las que apply acepta (R8). Se prueba cada una sobre una
-- copia del estado para no alterar la partida en curso.
local function expectLegal(state: GameState, playerId: PlayerId)
	for _, action in Engine.legalActions(state, playerId) do
		local copy = deepCopy(state)
		local result = Engine.apply(copy, playerId, action)
		if not result.ok then
			error(`la acción legal {action.type} fue rechazada: {result.error}`, 2)
		end
	end
end

-- Deja al jugador dos casillas antes de `index` (con vuelta), fuerza los dados (1, 1) más los
-- valores de azar que consuma la casilla y aplica Roll. Así cada prueba golpea la casilla exacta.
local function landOn(state: GameState, playerId: PlayerId, index: number, extra: { number }?): { Event }
	local size = #state.board.squares
	Fixtures.turnOf(state, playerId)
	Fixtures.placeOn(state, playerId, (index - 3) % size + 1)
	local forced = { 1, 1 }
	if extra then
		for _, value in extra do
			table.insert(forced, value)
		end
	end
	Rng.force(state.rng, forced)
	return applyOk(state, playerId, { type = "Roll" })
end

-- Elige rival y después las dos jugadas secretas del Duelo. Devuelve los eventos de la jugada
-- que cierra la ronda (la del retador, que va en segundo lugar).
local function bothChoose(
	state: GameState,
	challengerId: PlayerId,
	rivalId: PlayerId,
	challengerChoice: string,
	rivalChoice: string
): { Event }
	applyOk(state, rivalId, { type = "DuelChoice", choice = rivalChoice })
	return applyOk(state, challengerId, { type = "DuelChoice", choice = challengerChoice })
end

describe("config/Squares", function()
	it("guarda los valores de las casillas de la arquitectura", function()
		expect(SquaresConfig.market.prices.Common).toBe(100)
		expect(SquaresConfig.market.prices.Rare).toBe(200)
		expect(SquaresConfig.market.prices.Legendary).toBe(300)
		expect(SquaresConfig.duel.winnerPrize).toBe(150)
		expect(SquaresConfig.duel.loserStepsBack).toBe(2)
		expect(SquaresConfig.duel.maxRounds).toBe(3)
		expect(SquaresConfig.portalToll).toBe(50)
		expect(SquaresConfig.billboard.bigPrize.normal).toBe(200)
		expect(SquaresConfig.billboard.bigPrize.lucky).toBe(300)
		expect(SquaresConfig.billboard.smallPrize.normal).toBe(100)
		expect(SquaresConfig.billboard.smallPrize.lucky).toBe(150)
		expect(SquaresConfig.billboard.fine).toBe(100)
		expect(SquaresConfig.tribunal.fine).toBe(150)
		expect(SquaresConfig.tribunal.payToPlayer).toBe(100)
		expect(SquaresConfig.tribunal.skipTurns).toBe(1)
		expect(SquaresConfig.tribunal.voteSeconds).toBe(25)
		expect(SquaresConfig.tax).toBe(100)
		expect(#SquaresConfig.billboard.results).toBe(5)
		expect(SquaresConfig.duelChoices).toEqual({ "Rock", "Paper", "Scissors" })
	end)
end)

describe("Giro", function()
	it("roba una carta y cierra el turno", function()
		local s = Fixtures.game({ players = 3 })
		local player = inTurn(s)
		local events = landOn(s, player.id, Fixtures.squareOf(s, "Spin"))
		expect(#player.hand).toBe(1)
		expect(events[#events].type).toBe("CardDrawn")
		expect(events[#events].playerId).toBe(player.id)
		expect(events[#events].cardId).toBe(player.hand[1])
		expect(s.stats[player.id].cardsDrawn).toBe(1)
		expect(s.phase).toBe("AwaitEnd")
	end)

	it("descarta la carta si la mano está llena", function()
		local s = Fixtures.game({ players = 3 })
		local player = inTurn(s)
		for _, cardId in { "Shield", "ExtraDie", "Reverse" } do
			Fixtures.hand(s, player.id, cardId)
		end
		local events = landOn(s, player.id, Fixtures.squareOf(s, "Spin"))
		expect(events[#events].type).toBe("CardDiscarded")
		expect(events[#events].playerId).toBe(player.id)
		expect(#player.hand).toBe(Economy.handLimit)
		expect(s.phase).toBe("AwaitEnd")
	end)
end)

describe("Mercado Negro", function()
	it("ofrece tres cartas visibles, una por rareza y a su precio", function()
		local s = Fixtures.game({ players = 3 })
		local player = inTurn(s)
		landOn(s, player.id, Fixtures.squareOf(s, "Market"), { 1, 1, 1 })
		expect(s.phase).toBe("Market")

		local market = pendingOf(s).market
		expect(market ~= nil).toBe(true)
		expect(market.playerId).toBe(player.id)
		expect(#market.cards).toBe(3)
		local rarities = {}
		for index, card in market.cards do
			local definition = CardsConfig.byId[card.cardId]
			expect(definition ~= nil).toBe(true)
			expect(card.price).toBe(SquaresConfig.market.prices[definition.rarity])
			rarities[index] = definition.rarity
		end
		expect(rarities).toEqual({ "Common", "Rare", "Legendary" })
		expectLegal(s, player.id)
	end)

	it("vende al precio de su rareza", function()
		local s = Fixtures.game({ players = 3 })
		local player = inTurn(s)
		landOn(s, player.id, Fixtures.squareOf(s, "Market"), { 1, 1, 1 })

		local legendary = pendingOf(s).market.cards[3]
		expect(legendary.cardId).toBe("Hurricane")
		local events = applyOk(s, player.id, { type = "MarketBuy", cardId = legendary.cardId })
		expect(events[1]).toEqual({
			type = "MarketBought",
			playerId = player.id,
			cardId = "Hurricane",
			price = 300,
		})
		expect(events[2]).toEqual({ type = "CardDrawn", playerId = player.id, cardId = "Hurricane" })
		expect(player.cash).toBe(Economy.startingCash - 300)
		expect(player.hand).toEqual({ "Hurricane" })
		-- La compra pasa por Deck.add: cuenta como robo y actualiza la última legendaria.
		expect(s.stats[player.id].cardsDrawn).toBe(1)
		expect(s.lastLegendaryRound).toBe(s.round)
		expect(pendingOf(s).market).toBe(nil)
		expect(s.phase).toBe("AwaitEnd")
	end)

	it("se puede pasar sin gastar nada", function()
		local s = Fixtures.game({ players = 3 })
		local player = inTurn(s)
		landOn(s, player.id, Fixtures.squareOf(s, "Market"), { 1, 1, 1 })
		local events = applyOk(s, player.id, { type = "MarketSkip" })
		expect(events).toEqual({})
		expect(player.cash).toBe(Economy.startingCash)
		expect(player.hand).toEqual({})
		expect(pendingOf(s).market).toBe(nil)
		expect(s.phase).toBe("AwaitEnd")
	end)

	it("rechaza comprar sin efectivo o sin sitio en la mano", function()
		local s = Fixtures.game({ players = 3 })
		local player = inTurn(s)
		player.cash = 99
		landOn(s, player.id, Fixtures.squareOf(s, "Market"), { 1, 1, 1 })
		expect(Engine.legalActions(s, player.id)).toEqual({ { type = "MarketSkip" } })
		local before = deepCopy(s)
		expect(rejected(Engine.apply(s, player.id, { type = "MarketBuy", cardId = "Shield" }))).toBe(
			"No tienes efectivo para comprar Shield"
		)
		expect(deepCopy(s)).toEqual(before)

		local t = Fixtures.game({ players = 3 })
		local full = inTurn(t)
		for _, cardId in { "Shield", "ExtraDie", "Reverse" } do
			Fixtures.hand(t, full.id, cardId)
		end
		landOn(t, full.id, Fixtures.squareOf(t, "Market"), { 1, 1, 1 })
		expect(Engine.legalActions(t, full.id)).toEqual({ { type = "MarketSkip" } })
		expect(rejected(Engine.apply(t, full.id, { type = "MarketBuy", cardId = "Shield" }))).toBe(
			"No tienes sitio en la mano"
		)
	end)

	it("aplica el Descuento al precio y lo consume al comprar (R-P37)", function()
		local s = Fixtures.game({ players = 3 })
		local player = inTurn(s)
		Fixtures.hand(s, player.id, "Discount")
		applyOk(s, player.id, { type = "PlayCard", cardId = "Discount" })
		expect(pendingOf(s).discounts[player.id]).toBe(true)

		landOn(s, player.id, Fixtures.squareOf(s, "Market"), { 1, 1, 1 })
		-- La común cuesta 100; con Descuento, 50. Con 75 de efectivo entra y el descuento se gasta.
		player.cash = 75
		local events = applyOk(s, player.id, { type = "MarketBuy", cardId = "Shield" })
		expect(firstEvent(events, "MarketBought").price).toBe(50)
		expect(player.cash).toBe(25)
		expect(player.hand).toEqual({ "Shield" })
		expect(pendingOf(s).discounts[player.id]).toBe(nil)
		expect(s.phase).toBe("AwaitEnd")
	end)

	it("no consume el Descuento si la compra no se completa", function()
		local s = Fixtures.game({ players = 3 })
		local player = inTurn(s)
		Fixtures.hand(s, player.id, "Discount")
		applyOk(s, player.id, { type = "PlayCard", cardId = "Discount" })
		landOn(s, player.id, Fixtures.squareOf(s, "Market"), { 1, 1, 1 })
		player.cash = 40
		expect(rejected(Engine.apply(s, player.id, { type = "MarketBuy", cardId = "Shield" }))).toBe(
			"No tienes efectivo para comprar Shield"
		)
		expect(pendingOf(s).discounts[player.id]).toBe(true)
		expect(player.hand).toEqual({})
	end)

	it("no pide ninguna decisión a los demás y el reloj pasa", function()
		local s = Fixtures.game({ players = 3 })
		local player = inTurn(s)
		local other = rivalOf(s, player.id)
		landOn(s, player.id, Fixtures.squareOf(s, "Market"), { 1, 1, 1 })
		expect(Engine.legalActions(s, other.id)).toEqual({})
		expect(rejected(Engine.apply(s, other.id, { type = "MarketBuy", cardId = "Shield" }))).toBe(
			"El Mercado Negro no es tuyo"
		)
		expect(Engine.timeout(s)).toEqual({})
		expect(s.phase).toBe("AwaitEnd")
		expect(pendingOf(s).market).toBe(nil)
		expect(player.cash).toBe(Economy.startingCash)
	end)

	it("el bot compra si le sale a cuenta y pasa si no", function()
		local s = Fixtures.game({ players = 3 })
		local player = inTurn(s)
		landOn(s, player.id, Fixtures.squareOf(s, "Market"), { 1, 1, 1 })
		expect(Bot.choose(s, player.id)).toEqual({ type = "MarketBuy", cardId = "Shield" })
		applyOk(s, player.id, { type = "MarketBuy", cardId = "Shield" })
		expect(s.phase).toBe("AwaitEnd")

		local t = Fixtures.game({ players = 3 })
		local poor = inTurn(t)
		poor.cash = 150
		landOn(t, poor.id, Fixtures.squareOf(t, "Market"), { 1, 1, 1 })
		expect(Bot.choose(t, poor.id)).toEqual({ type = "MarketSkip" })
	end)
end)

describe("Duelo", function()
	it("abre la fase y solo el retador elige un rival activo", function()
		local s = Fixtures.game({ players = 3 })
		local challenger = inTurn(s)
		local events = landOn(s, challenger.id, Fixtures.squareOf(s, "Duel"))
		expect(s.phase).toBe("Duel")
		local duel = pendingOf(s).duel
		expect(duel.challengerId).toBe(challenger.id)
		expect(duel.rivalId).toBe(nil)
		expect(duel.round).toBe(1)
		expect(duel.picks).toEqual({})
		-- Solo los dados y el movimiento: el Duelo no pide ninguna decisión al caer.
		expect(#events).toBe(2)

		local rival = rivalOf(s, challenger.id)
		expect(rejected(Engine.apply(s, rival.id, { type = "DuelChoice", rivalId = challenger.id }))).toBe(
			"Solo el retador elige a su rival"
		)
		expect(rejected(Engine.apply(s, challenger.id, { type = "DuelChoice", rivalId = challenger.id }))).toBe(
			"No puedes retarte a ti mismo"
		)
		local ghost = activeRivals(s, challenger.id)[2]
		ghost.status = "Ghost"
		expect(rejected(Engine.apply(s, challenger.id, { type = "DuelChoice", rivalId = ghost.id }))).toBe(
			`El rival {ghost.id} no es un jugador activo`
		)
		expect(Engine.apply(s, challenger.id, { type = "DuelChoice", rivalId = rival.id }).ok).toBe(true)
		expect(pendingOf(s).duel.rivalId).toBe(rival.id)
		expect(s.phase).toBe("Duel")
	end)

	it("el ganador cobra 150 del banco y el perdedor retrocede 2 sin resolver", function()
		local s = Fixtures.game({ players = 3 })
		local challenger = inTurn(s)
		local rival = rivalOf(s, challenger.id)
		landOn(s, challenger.id, Fixtures.squareOf(s, "Duel"))
		-- El perdedor queda dos casillas por delante del Impuesto: retroceder le deja encima.
		local taxIndex = Fixtures.squareOf(s, "Tax")
		Fixtures.placeOn(s, rival.id, taxIndex + 2)
		applyOk(s, challenger.id, { type = "DuelChoice", rivalId = rival.id })

		local events = bothChoose(s, challenger.id, rival.id, "Rock", "Scissors")
		expect(events[1]).toEqual({
			type = "DuelResolved",
			winnerId = challenger.id,
			loserId = rival.id,
			round = 1,
			-- R-P18: el cierre publica las dos jugadas de la ronda (copiadas del pending).
			picks = { [challenger.id] = "Rock", [rival.id] = "Scissors" },
		})
		expect(events[2].type).toBe("TokenMoved")
		expect(challenger.cash).toBe(Economy.startingCash + SquaresConfig.duel.winnerPrize)
		expect(rival.cash).toBe(Economy.startingCash)
		expect(rival.position).toBe(taxIndex)
		expect(pendingOf(s).duel).toBe(nil)
		expect(s.phase).toBe("AwaitEnd")
	end)

	it("un empate repite hasta tres rondas y después nadie gana", function()
		local s = Fixtures.game({ players = 3 })
		local challenger = inTurn(s)
		local rival = rivalOf(s, challenger.id)
		landOn(s, challenger.id, Fixtures.squareOf(s, "Duel"))
		applyOk(s, challenger.id, { type = "DuelChoice", rivalId = rival.id })
		local challengerPosition = challenger.position
		local rivalPosition = rival.position

		local first = bothChoose(s, challenger.id, rival.id, "Rock", "Rock")
		expect(first).toEqual({
			{
				type = "DuelResolved",
				round = 1,
				picks = { [challenger.id] = "Rock", [rival.id] = "Rock" },
			},
		})
		expect(pendingOf(s).duel.round).toBe(2)
		expect(pendingOf(s).duel.picks).toEqual({})
		expect(s.phase).toBe("Duel")

		local second = bothChoose(s, challenger.id, rival.id, "Paper", "Paper")
		expect(second).toEqual({
			{
				type = "DuelResolved",
				round = 2,
				picks = { [challenger.id] = "Paper", [rival.id] = "Paper" },
			},
		})
		expect(pendingOf(s).duel.round).toBe(3)
		expect(s.phase).toBe("Duel")

		local last = bothChoose(s, challenger.id, rival.id, "Scissors", "Scissors")
		expect(last).toEqual({
			{
				type = "DuelResolved",
				round = 3,
				picks = { [challenger.id] = "Scissors", [rival.id] = "Scissors" },
			},
		})
		expect(pendingOf(s).duel).toBe(nil)
		expect(s.phase).toBe("AwaitEnd")
		expect(challenger.cash).toBe(Economy.startingCash)
		expect(rival.cash).toBe(Economy.startingCash)
		expect(challenger.position).toBe(challengerPosition)
		expect(rival.position).toBe(rivalPosition)
	end)

	it("un empate publica las dos jugadas en DuelResolved (R-P18)", function()
		local s = Fixtures.game({ players = 3 })
		local challenger = inTurn(s)
		local rival = rivalOf(s, challenger.id)
		landOn(s, challenger.id, Fixtures.squareOf(s, "Duel"))
		applyOk(s, challenger.id, { type = "DuelChoice", rivalId = rival.id })

		local events = bothChoose(s, challenger.id, rival.id, "Paper", "Paper")
		expect(events).toEqual({
			{
				type = "DuelResolved",
				round = 1,
				picks = { [challenger.id] = "Paper", [rival.id] = "Paper" },
			},
		})
		-- La ronda siguiente empieza con el mapa de jugadas vacío; el evento conserva las suyas.
		expect(pendingOf(s).duel.picks).toEqual({})
	end)

	it("el reloj elige rival y jugadas al azar", function()
		local s = Fixtures.game({ players = 3 })
		local challenger = inTurn(s)
		landOn(s, challenger.id, Fixtures.squareOf(s, "Duel"))
		local rivals = activeRivals(s, challenger.id)
		Fixtures.placeOn(s, rivals[1].id, 20)
		Fixtures.placeOn(s, rivals[2].id, 25)

		-- Rival: el primero de la lista. Jugadas: piedra (1) y tijera (3), gana el retador.
		Rng.force(s.rng, { 1, 1, 3 })
		local events = Engine.timeout(s)
		expect(events[1]).toEqual({
			type = "DuelResolved",
			winnerId = challenger.id,
			loserId = rivals[1].id,
			round = 1,
			picks = { [challenger.id] = "Rock", [rivals[1].id] = "Scissors" },
		})
		expect(rivals[1].position).toBe(18)
		expect(s.phase).toBe("AwaitEnd")
		expect(pendingOf(s).duel).toBe(nil)
	end)

	it("si un participante se fue, el reloj cierra sin premio ni movimiento (R-P36)", function()
		for _, leaver in { "challenger", "rival" } do
			local s = Fixtures.game({ players = 3 })
			local challenger = inTurn(s)
			local rival = rivalOf(s, challenger.id)
			landOn(s, challenger.id, Fixtures.squareOf(s, "Duel"))
			applyOk(s, challenger.id, { type = "DuelChoice", rivalId = rival.id })
			if leaver == "challenger" then
				challenger.status = "Left"
			else
				rival.status = "Left"
			end
			local challengerCash = challenger.cash
			local rivalCash = rival.cash
			local challengerPosition = challenger.position
			local rivalPosition = rival.position

			local events = Engine.timeout(s)
			expect(events).toEqual({ { type = "DuelResolved", round = 1 } })
			expect(challenger.cash).toBe(challengerCash)
			expect(rival.cash).toBe(rivalCash)
			expect(challenger.position).toBe(challengerPosition)
			expect(rival.position).toBe(rivalPosition)
			expect(pendingOf(s).duel).toBe(nil)
			expect(s.phase).toBe("AwaitEnd")
		end
	end)

	it("legalActions y el bot solo ofrecen jugadas legales", function()
		local s = Fixtures.game({ players = 3 })
		local challenger = inTurn(s)
		landOn(s, challenger.id, Fixtures.squareOf(s, "Duel"))

		local rivalActions: { Types.Action } = {}
		for _, player in activeRivals(s, challenger.id) do
			table.insert(rivalActions, { type = "DuelChoice", rivalId = player.id })
		end
		expect(Engine.legalActions(s, challenger.id)).toEqual(rivalActions)
		local rival = rivalOf(s, challenger.id)
		expect(Engine.legalActions(s, rival.id)).toEqual({})
		expectLegal(s, challenger.id)
		expect(Bot.choose(s, challenger.id)).toEqual(rivalActions[1])

		applyOk(s, challenger.id, rivalActions[1])
		local choices: { Types.Action } = {
			{ type = "DuelChoice", choice = "Rock" },
			{ type = "DuelChoice", choice = "Paper" },
			{ type = "DuelChoice", choice = "Scissors" },
		}
		expect(Engine.legalActions(s, challenger.id)).toEqual(choices)
		expect(Engine.legalActions(s, rival.id)).toEqual(choices)
		expectLegal(s, challenger.id)
		expectLegal(s, rival.id)
		-- Fix 1: la jugada del bot varía por asiento; si todos lanzaran la primera del catálogo
		-- cada Duelo serían tres empates. Con asientos distintos eligen jugadas distintas.
		local challengerPick = Bot.choose(s, challenger.id) :: Types.Action
		local rivalPick = Bot.choose(s, rival.id) :: Types.Action
		expect(challengerPick).toEqual(choices[(seatOf(s, challenger.id) % #choices) + 1])
		expect(rivalPick).toEqual(choices[(seatOf(s, rival.id) % #choices) + 1])
		expect(challengerPick.choice ~= rivalPick.choice).toBe(true)

		applyOk(s, rival.id, rivalPick)
		expect(Engine.legalActions(s, rival.id)).toEqual({})
		expect(Engine.legalActions(s, challenger.id)).toEqual(choices)
		-- Con jugadas distintas la ronda se resuelve con ganador, no con otro empate.
		local resolved = firstEvent(applyOk(s, challenger.id, challengerPick), "DuelResolved")
		expect(resolved.winnerId ~= nil).toBe(true)
	end)
end)

describe("Portal", function()
	it("paga el peaje y salta al siguiente Portal con vuelta", function()
		local s = Fixtures.game({ players = 3 })
		local player = inTurn(s)
		local portals: { number } = {}
		for _, square in s.board.squares do
			if square.kind == "Portal" then
				table.insert(portals, square.index)
			end
		end
		expect(#portals >= 2).toBe(true)
		local from = portals[#portals]
		local events = landOn(s, player.id, from)
		expect(player.position).toBe(portals[1])
		expect(player.cash).toBe(Economy.startingCash - SquaresConfig.portalToll)
		-- La ficha se sincroniza primero con TokenMoved y después se anuncia el salto.
		expect(events[#events - 1]).toEqual({
			type = "TokenMoved",
			playerId = player.id,
			from = from,
			to = portals[1],
			path = {},
		})
		expect(events[#events]).toEqual({
			type = "PortalUsed",
			from = from,
			to = portals[1],
			toll = SquaresConfig.portalToll,
		})
		expect(s.phase).toBe("AwaitEnd")
	end)

	it("sin efectivo pero con bienes vende, paga y salta (R-P35)", function()
		local s = Fixtures.game({ players = 3 })
		local player = inTurn(s)
		player.cash = 30
		-- La propiedad más barata del tablero vale 60: el banco paga 30 por ella y cubre el peaje.
		local property = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, player.id, property)
		local portals: { number } = {}
		for _, square in s.board.squares do
			if square.kind == "Portal" then
				table.insert(portals, square.index)
			end
		end
		local from = portals[1]

		local events = landOn(s, player.id, from)
		expect(player.status).toBe("Active")
		expect(player.cash).toBe(10)
		expect(player.position).toBe(portals[2])
		expect(s.properties[property].ownerId).toBe(nil)
		expect(firstEvent(events, "PortalUsed").to).toBe(portals[2])
		expect(s.phase).toBe("AwaitEnd")
	end)

	it("sin nada con que pagar queda Ghost y no salta (R-P35)", function()
		local s = Fixtures.game({ players = 3 })
		local player = inTurn(s)
		player.cash = 30
		local portal = Fixtures.squareOf(s, "Portal")
		local events = landOn(s, player.id, portal)
		expect(player.status).toBe("Ghost")
		expect(player.cash).toBe(0)
		expect(player.position).toBe(portal)
		expect(firstEvent(events, "BankruptcyDeclared").playerId).toBe(player.id)
		local jumped = false
		for _, event in events do
			if event.type == "PortalUsed" then
				jumped = true
			end
		end
		expect(jumped).toBe(false)
		expect(s.phase).toBe("AwaitEnd")
	end)

	it("con el efectivo justo paga y salta sin quedar negativo", function()
		local s = Fixtures.game({ players = 3 })
		local player = inTurn(s)
		player.cash = SquaresConfig.portalToll
		local portal = Fixtures.squareOf(s, "Portal")
		landOn(s, player.id, portal)
		expect(player.cash).toBe(0)
		expect(player.position ~= portal).toBe(true)
	end)
end)

describe("Cartelera de la Suerte", function()
	it("la Cartelera nunca pide decisión", function()
		local s = Fixtures.game({ players = 4 })
		local id = s.players[s.turnIndex].id
		Fixtures.placeOn(s, id, Fixtures.squareOf(s, "Billboard") - 2)
		Fixtures.dice(s, 1, 1)
		local result = Engine.apply(s, id, { type = "Roll" })
		expect(result.ok).toBe(true)
		expect(s.phase).toBe("AwaitEnd")
		expect(pendingOf(s).market).toBe(nil)
		expect(pendingOf(s).duel).toBe(nil)
		expect(pendingOf(s).tribunal).toBe(nil)
	end)

	-- Índice forzado en la tabla de cinco resultados con el mismo peso.
	local CASES = {
		{ roll = 1, result = "BigPrize", amount = 200 },
		{ roll = 2, result = "SmallPrize", amount = 100 },
		{ roll = 3, result = "Fine", amount = -100 },
		{ roll = 4, result = "Card", amount = 0 },
		{ roll = 5, result = "Nothing", amount = 0 },
	}
	for _, case in CASES do
		it(`da {case.result}`, function()
			local s = Fixtures.game({ players = 3 })
			local player = inTurn(s)
			local events = landOn(s, player.id, Fixtures.squareOf(s, "Billboard"), { case.roll })
			local resultEvent = firstEvent(events, "BillboardResult")
			expect(resultEvent).toEqual({
				type = "BillboardResult",
				playerId = player.id,
				result = case.result,
				amount = case.amount,
			})
			expect(s.phase).toBe("AwaitEnd")

			if case.result == "BigPrize" then
				expect(player.cash).toBe(Economy.startingCash + SquaresConfig.billboard.bigPrize.normal)
			elseif case.result == "SmallPrize" then
				expect(player.cash).toBe(Economy.startingCash + SquaresConfig.billboard.smallPrize.normal)
			elseif case.result == "Fine" then
				expect(player.cash).toBe(Economy.startingCash - SquaresConfig.billboard.fine)
			elseif case.result == "Card" then
				expect(#player.hand).toBe(1)
				expect(firstEvent(events, "CardDrawn").cardId).toBe(player.hand[1])
				expect(player.cash).toBe(Economy.startingCash)
			else
				expect(player.cash).toBe(Economy.startingCash)
				expect(#events).toBe(3)
			end
		end)
	end

	it("una multa sin dinero pasa por la bancarrota y nunca deja efectivo negativo", function()
		local s = Fixtures.game({ players = 3 })
		local player = inTurn(s)
		player.cash = 0
		local events = landOn(s, player.id, Fixtures.squareOf(s, "Billboard"), { 3 })
		expect(firstEvent(events, "BillboardResult").amount).toBe(-SquaresConfig.billboard.fine)
		expect(firstEvent(events, "BankruptcyDeclared").playerId).toBe(player.id)
		expect(player.status).toBe("Ghost")
		expect(player.cash).toBe(0)
		expect(s.phase).toBe("AwaitEnd")
	end)

	it("Afortunado mejora los premios y no la multa", function()
		local big = Fixtures.game({ players = 3 })
		local bigPlayer = inTurn(big)
		table.insert(bigPlayer.perks, "Lucky")
		local bigEvents = landOn(big, bigPlayer.id, Fixtures.squareOf(big, "Billboard"), { 1 })
		expect(firstEvent(bigEvents, "BillboardResult").amount).toBe(300)
		expect(bigPlayer.cash).toBe(Economy.startingCash + 300)

		local small = Fixtures.game({ players = 3 })
		local smallPlayer = inTurn(small)
		table.insert(smallPlayer.perks, "Lucky")
		landOn(small, smallPlayer.id, Fixtures.squareOf(small, "Billboard"), { 2 })
		expect(smallPlayer.cash).toBe(Economy.startingCash + 150)

		local fine = Fixtures.game({ players = 3 })
		local fined = inTurn(fine)
		table.insert(fined.perks, "Lucky")
		landOn(fine, fined.id, Fixtures.squareOf(fine, "Billboard"), { 3 })
		expect(fined.cash).toBe(Economy.startingCash - SquaresConfig.billboard.fine)
	end)
end)

describe("Tribunal", function()
	it("arresta al jugador y abre el voto sin dejar votar al acusado", function()
		local s = Fixtures.game({ players = 3 })
		local accused = inTurn(s)
		local events = landOn(s, accused.id, Fixtures.squareOf(s, "Tribunal"))
		expect(events[#events]).toEqual({ type = "PlayerArrested", playerId = accused.id })
		expect(s.phase).toBe("Tribunal")
		local tribunal = pendingOf(s).tribunal
		expect(tribunal.accusedId).toBe(accused.id)
		expect(tribunal.votes).toEqual({})
		expect(tribunal.votesCount).toBe(0)
		expect(Engine.legalActions(s, accused.id)).toEqual({})
		expect(rejected(Engine.apply(s, accused.id, { type = "TribunalVote", verdict = "Fine" }))).toBe(
			"El acusado no vota"
		)
		expect(Bot.choose(s, accused.id)).toBe(nil)
		for _, rival in activeRivals(s, accused.id) do
			expectLegal(s, rival.id)
		end
	end)

	it("con un solo votante resuelve sin atascarse", function()
		local s = Fixtures.game({ players = 2 })
		local accused = inTurn(s)
		local voter = rivalOf(s, accused.id)
		landOn(s, accused.id, Fixtures.squareOf(s, "Tribunal"))

		local events = applyOk(s, voter.id, { type = "TribunalVote", verdict = "Fine" })
		expect(events).toEqual({
			{
				type = "TribunalVerdict",
				playerId = accused.id,
				verdict = "Fine",
				votes = { [voter.id] = { verdict = "Fine" } },
			},
		})
		expect(accused.cash).toBe(Economy.startingCash - SquaresConfig.tribunal.fine)
		expect(pendingOf(s).tribunal).toBe(nil)
		expect(s.phase).toBe("AwaitEnd")
	end)

	it("sin votos el reloj aplica la multa", function()
		local s = Fixtures.game({ players = 2 })
		local accused = inTurn(s)
		landOn(s, accused.id, Fixtures.squareOf(s, "Tribunal"))
		local events = Engine.timeout(s)
		expect(events[1].type).toBe("TribunalVerdict")
		expect(events[1].verdict).toBe("Fine")
		expect(events[1].votes).toEqual({})
		expect(accused.cash).toBe(Economy.startingCash - SquaresConfig.tribunal.fine)
		expect(s.phase).toBe("AwaitEnd")
	end)

	it("el reloj cuenta los votos que haya", function()
		local s = Fixtures.game({ players = 3 })
		local accused = inTurn(s)
		local voters = activeRivals(s, accused.id)
		landOn(s, accused.id, Fixtures.squareOf(s, "Tribunal"))
		applyOk(s, voters[1].id, { type = "TribunalVote", verdict = "PayToPlayer", targetId = voters[2].id })
		-- Falta un votante: el reloj resuelve con la papeleta que ya hay.
		expect(s.phase).toBe("Tribunal")
		local events = Engine.timeout(s)
		expect(events[1].verdict).toBe("PayToPlayer")
		expect(events[1].targetId).toBe(voters[2].id)
		expect(accused.cash).toBe(Economy.startingCash - SquaresConfig.tribunal.payToPlayer)
		expect(voters[2].cash).toBe(Economy.startingCash + SquaresConfig.tribunal.payToPlayer)
		expect(voters[1].cash).toBe(Economy.startingCash)
		expect(s.phase).toBe("AwaitEnd")
	end)

	it("pagar a un jugador transfiere 100 una sola vez", function()
		local s = Fixtures.game({ players = 3 })
		local accused = inTurn(s)
		local voters = activeRivals(s, accused.id)
		landOn(s, accused.id, Fixtures.squareOf(s, "Tribunal"))
		applyOk(s, voters[1].id, { type = "TribunalVote", verdict = "PayToPlayer", targetId = voters[2].id })
		local events = applyOk(
			s,
			voters[2].id,
			{ type = "TribunalVote", verdict = "PayToPlayer", targetId = voters[2].id }
		)
		expect(events[1].verdict).toBe("PayToPlayer")
		expect(events[1].targetId).toBe(voters[2].id)
		expect(accused.cash).toBe(Economy.startingCash - SquaresConfig.tribunal.payToPlayer)
		expect(voters[2].cash).toBe(Economy.startingCash + SquaresConfig.tribunal.payToPlayer)
		expect(s.phase).toBe("AwaitEnd")
	end)

	it("pagar al propio votante es legal (R-P39)", function()
		local s = Fixtures.game({ players = 2 })
		local accused = inTurn(s)
		local voter = rivalOf(s, accused.id)
		landOn(s, accused.id, Fixtures.squareOf(s, "Tribunal"))
		-- En 2 jugadores el votante es el único objetivo posible, así que apuntarse a sí mismo vale.
		local targets: { PlayerId } = {}
		for _, action in Engine.legalActions(s, voter.id) do
			if action.type == "TribunalVote" and action.verdict == "PayToPlayer" then
				table.insert(targets, action.targetId)
			end
		end
		expect(targets).toEqual({ voter.id })

		local events =
			applyOk(s, voter.id, { type = "TribunalVote", verdict = "PayToPlayer", targetId = voter.id })
		expect(events[1].targetId).toBe(voter.id)
		expect(accused.cash).toBe(Economy.startingCash - SquaresConfig.tribunal.payToPlayer)
		expect(voter.cash).toBe(Economy.startingCash + SquaresConfig.tribunal.payToPlayer)
	end)

	it("perder el turno suma skipTurns y no cobra", function()
		local s = Fixtures.game({ players = 2 })
		local accused = inTurn(s)
		local voter = rivalOf(s, accused.id)
		landOn(s, accused.id, Fixtures.squareOf(s, "Tribunal"))
		local events = applyOk(s, voter.id, { type = "TribunalVote", verdict = "SkipTurn" })
		expect(events[1].verdict).toBe("SkipTurn")
		expect(accused.skipTurns).toBe(SquaresConfig.tribunal.skipTurns)
		expect(accused.cash).toBe(Economy.startingCash)
		expect(s.phase).toBe("AwaitEnd")
	end)

	it("el empate lo decide el orden fijo", function()
		local s = Fixtures.game({ players = 3 })
		local accused = inTurn(s)
		local voters = activeRivals(s, accused.id)
		landOn(s, accused.id, Fixtures.squareOf(s, "Tribunal"))
		applyOk(s, voters[1].id, { type = "TribunalVote", verdict = "SkipTurn" })
		local events = applyOk(s, voters[2].id, { type = "TribunalVote", verdict = "Fine" })
		-- Dos votos, uno cada uno: gana Fine, la primera del orden fijo.
		expect(events[1].verdict).toBe("Fine")
		expect(accused.cash).toBe(Economy.startingCash - SquaresConfig.tribunal.fine)
		expect(accused.skipTurns).toBe(0)
	end)

	it("Abogado decide los empates en los que votó", function()
		local s = Fixtures.game({ players = 4 })
		local accused = inTurn(s)
		local voters = activeRivals(s, accused.id)
		table.insert(voters[2].perks, "Lawyer")
		landOn(s, accused.id, Fixtures.squareOf(s, "Tribunal"))
		applyOk(s, voters[1].id, { type = "TribunalVote", verdict = "Fine" })
		applyOk(s, voters[3].id, { type = "TribunalVote", verdict = "PayToPlayer", targetId = voters[1].id })
		local events = applyOk(s, voters[2].id, { type = "TribunalVote", verdict = "SkipTurn" })
		-- Triple empate: el orden fijo diría Fine, pero el Abogado votó SkipTurn.
		expect(events[1].verdict).toBe("SkipTurn")
		expect(accused.skipTurns).toBe(SquaresConfig.tribunal.skipTurns)
		expect(accused.cash).toBe(Economy.startingCash)
	end)

	it("un Soborno pendiente cancela el castigo y se consume", function()
		local s = Fixtures.game({ players = 2 })
		local accused = inTurn(s)
		local voter = rivalOf(s, accused.id)
		Fixtures.hand(s, accused.id, "Bribe")
		applyOk(s, accused.id, { type = "PlayCard", cardId = "Bribe" })
		expect(pendingOf(s).bribes[accused.id]).toBe(true)

		landOn(s, accused.id, Fixtures.squareOf(s, "Tribunal"))
		local events = applyOk(s, voter.id, { type = "TribunalVote", verdict = "Fine" })
		expect(events[1].verdict).toBe("Fine")
		expect(events[1].cancelled).toBe(true)
		expect(accused.cash).toBe(Economy.startingCash)
		expect(pendingOf(s).bribes[accused.id]).toBe(nil)
		expect(s.phase).toBe("AwaitEnd")
	end)

	it("una multa sin dinero pasa por la bancarrota y nunca deja efectivo negativo", function()
		local s = Fixtures.game({ players = 3 })
		local accused = inTurn(s)
		local voters = activeRivals(s, accused.id)
		landOn(s, accused.id, Fixtures.squareOf(s, "Tribunal"))
		accused.cash = 0
		applyOk(s, voters[1].id, { type = "TribunalVote", verdict = "Fine" })
		local events = applyOk(s, voters[2].id, { type = "TribunalVote", verdict = "Fine" })
		expect(events[1].type).toBe("TribunalVerdict")
		expect(events[2]).toEqual({ type = "BankruptcyDeclared", playerId = accused.id })
		expect(accused.status).toBe("Ghost")
		expect(accused.cash).toBe(0)
		expect(s.phase).toBe("AwaitEnd")
	end)
end)

describe("Impuesto", function()
	it("cobra 100 al banco", function()
		local s = Fixtures.game({ players = 3 })
		local player = inTurn(s)
		local events = landOn(s, player.id, Fixtures.squareOf(s, "Tax"))
		expect(player.cash).toBe(Economy.startingCash - SquaresConfig.tax)
		-- Tirada, recorrido y TaxPaid (R-P57): con efectivo no hay venta.
		expect(#events).toBe(3)
		expect(events[3]).toEqual({ type = "TaxPaid", playerId = player.id, amount = SquaresConfig.tax })
		expect(s.phase).toBe("AwaitEnd")
	end)

	it("sin dinero pasa por la bancarrota", function()
		local s = Fixtures.game({ players = 3 })
		local player = inTurn(s)
		player.cash = 0
		local events = landOn(s, player.id, Fixtures.squareOf(s, "Tax"))
		expect(player.status).toBe("Ghost")
		expect(player.cash).toBe(0)
		expect(events[4]).toEqual({ type = "BankruptcyDeclared", playerId = player.id })
		expect(s.phase).toBe("AwaitEnd")
	end)
end)

describe("Turn y skipTurns", function()
	it("un jugador con turnos perdidos no juega y el contador baja", function()
		local s = Fixtures.game({ players = 3 })
		local first = s.players[1]
		local second = s.players[2]
		second.skipTurns = 1
		Fixtures.turnOf(s, first.id)
		s.phase = "AwaitEnd"
		applyOk(s, first.id, { type = "EndTurn" })
		expect(s.turnIndex).toBe(3)
		expect(second.skipTurns).toBe(0)
		expect(s.round).toBe(1)
	end)

	it("saltar la vuelta completa avanza la ronda", function()
		local s = Fixtures.game({ players = 3 })
		local last = s.players[3]
		s.players[1].skipTurns = 1
		s.players[2].skipTurns = 1
		Fixtures.turnOf(s, last.id)
		s.phase = "AwaitEnd"
		applyOk(s, last.id, { type = "EndTurn" })
		expect(s.turnIndex).toBe(3)
		expect(s.round).toBe(2)
		expect(s.players[1].skipTurns).toBe(0)
		expect(s.players[2].skipTurns).toBe(0)
	end)

	it("el castigo del Tribunal se cumple al llegar su turno", function()
		local s = Fixtures.game({ players = 2 })
		local accused = inTurn(s)
		local voter = rivalOf(s, accused.id)
		landOn(s, accused.id, Fixtures.squareOf(s, "Tribunal"))
		applyOk(s, voter.id, { type = "TribunalVote", verdict = "SkipTurn" })
		expect(accused.skipTurns).toBe(1)
		-- El acusado cierra su turno: el castigo espera a que la vuelta le llegue.
		applyOk(s, accused.id, { type = "EndTurn" })
		expect(accused.skipTurns).toBe(1)
		-- El votante cierra el suyo (aquí no importa su tirada): el acusado pierde su turno.
		s.phase = "AwaitEnd"
		applyOk(s, voter.id, { type = "EndTurn" })
		expect(accused.skipTurns).toBe(0)
		expect(inTurn(s).id).toBe(voter.id)
		expect(s.round).toBe(2)
	end)

	it("no consume el turno perdido del único jugador que queda (R-P38)", function()
		local s = Fixtures.game({ players = 2 })
		local current = inTurn(s)
		local other = rivalOf(s, current.id)
		other.status = "Left"
		current.skipTurns = 1
		s.phase = "AwaitEnd"
		applyOk(s, current.id, { type = "EndTurn" })
		-- Solo queda él: la partida termina y la marca no se gasta sin que pierda el turno.
		expect(current.skipTurns).toBe(1)
		expect(s.players[s.turnIndex].id).toBe(current.id)
		expect(s.phase).toBe("GameOver")
	end)
end)

describe("Squares.act", function()
	it("rechaza sin levantar un error cuando la acción no es legal", function()
		local s = Fixtures.game({ players = 3 })
		local result = Squares.act(s, inTurn(s).id, { type = "MarketBuy", cardId = "Shield" })
		if result.ok then
			error("se esperaba un rechazo y la acción se aplicó", 2)
		end
		expect(result.error).toBe("El Mercado Negro no está abierto")
	end)
end)

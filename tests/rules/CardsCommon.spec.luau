--!strict
-- Cartas comunes: una prueba por carta con el estado antes y después, más permisos y objetivos.
local Harness = require("../harness")
local Bankruptcy = require("../../src/shared/rules/Bankruptcy")
local Cards = require("../../src/shared/rules/Cards")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Property = require("../../src/shared/rules/Property")
local Rng = require("../../src/shared/rules/Rng")
local Types = require("../../src/shared/rules/Types")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function inTurn(state: Types.GameState): Types.Player
	return state.players[state.turnIndex]
end

-- Rivales en el orden de state.players: el mismo que recorren los efectos de área.
local function rivalsOf(state: Types.GameState, playerId: Types.PlayerId): { Types.Player }
	local rivals: { Types.Player } = {}
	for _, player in state.players do
		if player.id ~= playerId then
			table.insert(rivals, player)
		end
	end
	return rivals
end

-- pending es la tabla persistente que State.create siempre crea (R1).
local function pendingOf(state: Types.GameState): any
	local pending = state.pending
	if not pending then
		error("el estado no tiene pending", 2)
	end
	return pending
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

-- Juega una carta por la vía real del motor. El turno lo fija la prueba.
local function playCard(
	state: Types.GameState,
	playerId: Types.PlayerId,
	cardId: string,
	targetId: Types.PlayerId?
): { Types.Event }
	local action: Types.Action = { type = "PlayCard", cardId = cardId }
	if targetId then
		action.targetId = targetId
	end
	local result = Engine.apply(state, playerId, action)
	if not result.ok then
		error(result.error, 2)
	end
	return result.events
end

local function priceOf(state: Types.GameState, index: number): number
	local price = state.board.squares[index].price
	if not price then
		error(`la casilla {index} no tiene precio`, 2)
	end
	return price
end

describe("PlayCard", function()
	it("rechaza una carta que no está en la mano sin tocar el estado", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local before = deepCopy(s)
		expect(rejected(Engine.apply(s, a.id, { type = "PlayCard", cardId = "ExtraDie" }))).toBe(
			"No tienes la carta ExtraDie en la mano"
		)
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza una carta que aún no está implementada", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		Fixtures.hand(s, a.id, "Shield")
		local before = deepCopy(s)
		expect(rejected(Engine.apply(s, a.id, { type = "PlayCard", cardId = "Shield" }))).toBe(
			"Carta no implementada: Shield"
		)
		expect(rejected(Engine.apply(s, a.id, { type = "PlayCard", cardId = "Nope" }))).toBe(
			"Carta no implementada: Nope"
		)
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza jugar fuera de turno", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s)
		local other = rivalsOf(s, actor.id)[1]
		Fixtures.hand(s, other.id, "ForcedTip")
		local before = deepCopy(s)
		expect(rejected(Engine.apply(s, other.id, { type = "PlayCard", cardId = "ForcedTip" }))).toBe(
			"No es tu turno"
		)
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza jugar en una fase que no admite la acción", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		Fixtures.hand(s, a.id, "ForcedTip")
		s.phase = "AwaitBuy"
		local before = deepCopy(s)
		expect(rejected(Engine.apply(s, a.id, { type = "PlayCard", cardId = "ForcedTip" }))).toBe(
			"No se puede PlayCard en la fase AwaitBuy"
		)
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza las cartas de tirada después de tirar", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		Fixtures.hand(s, a.id, "ExtraDie")
		Fixtures.hand(s, a.id, "Reverse")
		s.phase = "AwaitEnd"
		local before = deepCopy(s)
		expect(rejected(Engine.apply(s, a.id, { type = "PlayCard", cardId = "ExtraDie" }))).toBe(
			"No se puede jugar ExtraDie en la fase AwaitEnd"
		)
		expect(rejected(Engine.apply(s, a.id, { type = "PlayCard", cardId = "Reverse" }))).toBe(
			"No se puede jugar Reverse en la fase AwaitEnd"
		)
		expect(deepCopy(s)).toEqual(before)
	end)

	it("permite jugar en AwaitEnd sin mover la fase", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local target = rivalsOf(s, a.id)[1]
		Fixtures.hand(s, a.id, "Fine")
		s.phase = "AwaitEnd"
		local events = playCard(s, a.id, "Fine", target.id)
		expect(events[1].type).toBe("CardPlayed")
		expect(s.phase).toBe("AwaitEnd")
		expect(target.cash).toBe(Economy.startingCash - Economy.cards.fine)
	end)

	it("quita una sola copia de la carta de la mano", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local target = rivalsOf(s, a.id)[1]
		Fixtures.hand(s, a.id, "Fine")
		Fixtures.hand(s, a.id, "Fine")
		playCard(s, a.id, "Fine", target.id)
		expect(a.hand).toEqual({ "Fine" })
	end)

	it("Cards.play valida la mano antes de mutar", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local before = deepCopy(s)
		local result = Cards.play(s, a.id, "ForcedTip", {})
		if result.ok then
			error("se esperaba un rechazo y la carta se jugó", 2)
		end
		expect(result.error).toBe("No tienes la carta ForcedTip en la mano")
		local unknown = Cards.play(s, a.id, "Nope", {})
		if unknown.ok then
			error("se esperaba un rechazo y la carta se jugó", 2)
		end
		expect(unknown.error).toBe("Carta no implementada: Nope")
		expect(deepCopy(s)).toEqual(before)
	end)
end)

describe("Dado Extra", function()
	it("prepara un dado más y lo consume en la tirada", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		Fixtures.hand(s, a.id, "ExtraDie")
		local events = playCard(s, a.id, "ExtraDie")
		expect(events).toEqual({ { type = "CardPlayed", playerId = a.id, cardId = "ExtraDie" } })
		expect(a.hand).toEqual({})
		expect(a.cash).toBe(Economy.startingCash)
		expect(a.position).toBe(1)
		expect(pendingOf(s).extraDie).toBe(true)
		expect(s.stats[a.id].cardsPlayed).toBe(1)

		Rng.force(s.rng, { 1, 2, 3 })
		local rolled = Engine.apply(s, a.id, { type = "Roll" })
		if not rolled.ok then
			error(rolled.error, 2)
		end
		expect(rolled.events[1]).toEqual({ type = "DiceRolled", playerId = a.id, a = 1, b = 2, c = 3 })
		expect(a.position).toBe(1 + 1 + 2 + 3)
		expect(a.cash).toBe(Economy.startingCash)
		expect(pendingOf(s).extraDie).toBe(nil)
		expect(pendingOf(s).rolled).toEqual({ a = 1, b = 2, c = 3 })
		-- La casilla 7 está libre: la tirada resuelve el destino aunque el dado sea extra.
		expect(s.phase).toBe("AwaitBuy")
		expect(pendingOf(s).index).toBe(a.position)
	end)

	it("no deja la marca de tirada al turno siguiente si el jugador abandona", function()
		local s = Fixtures.game({ players = 3 })
		local a = inTurn(s)
		Fixtures.hand(s, a.id, "ExtraDie")
		playCard(s, a.id, "ExtraDie")
		expect(pendingOf(s).extraDie).toBe(true)
		-- Sin tirada no hay consumo: cerrar el turno del que abandonó limpia las marcas.
		a.status = "Left"
		Engine.timeout(s)
		expect(pendingOf(s).extraDie).toBe(nil)
		expect(s.players[s.turnIndex].id ~= a.id).toBe(true)
		expect(s.phase).toBe("AwaitRoll")
	end)
end)

describe("Marcha Atrás", function()
	it("retrocede la tirada y no paga la Salida", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		Fixtures.hand(s, a.id, "Reverse")
		Fixtures.placeOn(s, a.id, 2)
		local events = playCard(s, a.id, "Reverse")
		expect(events).toEqual({ { type = "CardPlayed", playerId = a.id, cardId = "Reverse" } })
		expect(a.hand).toEqual({})
		expect(a.cash).toBe(Economy.startingCash)
		expect(pendingOf(s).reverse).toBe(true)

		Rng.force(s.rng, { 1, 1 })
		local rolled = Engine.apply(s, a.id, { type = "Roll" })
		if not rolled.ok then
			error(rolled.error, 2)
		end
		expect(rolled.events[1]).toEqual({ type = "DiceRolled", playerId = a.id, a = 1, b = 1 })
		-- Desde la casilla 2, retroceder 2 pasa por la Salida: no cobra y acaba en la última casilla.
		expect(a.position).toBe(#s.board.squares)
		expect(a.cash).toBe(Economy.startingCash)
		expect(pendingOf(s).reverse).toBe(nil)
		expect(rolled.events[2]).toEqual({
			type = "TokenMoved",
			playerId = a.id,
			from = 2,
			to = #s.board.squares,
			path = { 1, #s.board.squares },
		})
		-- La última casilla es el Mercado: no abre compra.
		expect(s.phase).toBe("AwaitEnd")
	end)
end)

describe("Propina Forzada", function()
	it("cobra 50 a cada rival y el espectro paga 0", function()
		local s = Fixtures.game({ players = 4 })
		local a = inTurn(s)
		local rivals = rivalsOf(s, a.id)
		local first, second, ghost = rivals[1], rivals[2], rivals[3]
		ghost.status = "Ghost"
		local cashFirst, cashSecond, cashGhost = first.cash, second.cash, ghost.cash
		Fixtures.hand(s, a.id, "ForcedTip")
		local events = playCard(s, a.id, "ForcedTip")
		-- El espectro también recibe el intento de cobro, pero Bankruptcy.charge lo deja en no-op:
		-- no paga, no se vuelve a declarar en bancarrota y no emite un segundo evento.
		expect(events).toEqual({ { type = "CardPlayed", playerId = a.id, cardId = "ForcedTip" } })
		expect(a.cash).toBe(Economy.startingCash + 2 * Economy.cards.forcedTip)
		expect(first.cash).toBe(cashFirst - Economy.cards.forcedTip)
		expect(second.cash).toBe(cashSecond - Economy.cards.forcedTip)
		expect(ghost.cash).toBe(cashGhost)
		expect(ghost.status).toBe("Ghost")
		expect(a.hand).toEqual({})
		expect(a.position).toBe(1)
		expect(first.position).toBe(1)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("arruina al rival que no puede pagar y le entrega lo disponible", function()
		local s = Fixtures.game({ players = 3 })
		local a = inTurn(s)
		local rivals = rivalsOf(s, a.id)
		local broke, other = rivals[1], rivals[2]
		broke.cash = 10
		Fixtures.hand(s, a.id, "ForcedTip")
		local events = playCard(s, a.id, "ForcedTip")
		expect(#events).toBe(2)
		expect(events[1]).toEqual({ type = "CardPlayed", playerId = a.id, cardId = "ForcedTip" })
		expect(events[2]).toEqual({ type = "BankruptcyDeclared", playerId = broke.id, creditorId = a.id })
		expect(broke.status).toBe("Ghost")
		expect(broke.cash).toBe(0)
		-- Cobra los 10 disponibles del arruinado y los 50 del rival que sí puede pagar.
		expect(a.cash).toBe(Economy.startingCash + 10 + Economy.cards.forcedTip)
		expect(other.cash).toBe(Economy.startingCash - Economy.cards.forcedTip)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("Bankruptcy.charge no vuelve a declarar en bancarrota a un espectro", function()
		local s = Fixtures.game({ players = 3 })
		local ghost = s.players[1]
		local creditor = s.players[2]
		ghost.status = "Ghost"
		ghost.cash = 0
		expect(Bankruptcy.charge(s, ghost.id, Economy.cards.fine, creditor.id)).toEqual({})
		expect(ghost.status).toBe("Ghost")
		expect(ghost.cash).toBe(0)
		expect(creditor.cash).toBe(Economy.startingCash)
	end)
end)

describe("Descuento", function()
	it("deja la próxima compra a la mitad y consume la marca", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local index = Fixtures.squareOf(s, "Property")
		local full = priceOf(s, index)
		local half = math.floor(full * Economy.cards.discountMultiplier)
		Fixtures.hand(s, a.id, "Discount")

		expect(Property.priceFor(s, a.id, index)).toBe(full)
		local events = playCard(s, a.id, "Discount")
		expect(events).toEqual({ { type = "CardPlayed", playerId = a.id, cardId = "Discount" } })
		expect(a.hand).toEqual({})
		expect(a.cash).toBe(Economy.startingCash)
		expect(a.position).toBe(1)
		expect(pendingOf(s).discounts).toEqual({ [a.id] = true })
		expect(Property.priceFor(s, a.id, index)).toBe(half)

		a.cash = half - 1
		expect(Property.canBuy(s, a.id, index)).toBe(false)
		a.cash = half
		expect(Property.canBuy(s, a.id, index)).toBe(true)

		s.phase = "AwaitBuy"
		pendingOf(s).index = index
		local bought = Engine.apply(s, a.id, { type = "Buy" })
		if not bought.ok then
			error(bought.error, 2)
		end
		expect(bought.events).toEqual({
			{ type = "PropertyBought", playerId = a.id, index = index, price = half },
		})
		expect(a.cash).toBe(0)
		expect(s.properties[index].ownerId).toBe(a.id)
		expect(pendingOf(s).discounts).toEqual({})
	end)

	it("Property.buy sin precio cobra lo mismo que canBuy", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local index = Fixtures.squareOf(s, "Property")
		local half = math.floor(priceOf(s, index) * Economy.cards.discountMultiplier)
		Fixtures.hand(s, a.id, "Discount")
		playCard(s, a.id, "Discount")
		a.cash = half
		expect(Property.canBuy(s, a.id, index)).toBe(true)
		local events = Property.buy(s, a.id, index)
		expect(events[1].price).toBe(half)
		expect(a.cash).toBe(0)
		-- La compra directa también consume la marca del comprador.
		expect(pendingOf(s).discounts[a.id]).toBe(nil)
	end)

	it("respeta el descuento pendiente de cada jugador", function()
		local s = Fixtures.game({ players = 3 })
		local a, b, c = s.players[1], s.players[2], s.players[3]
		local first = Fixtures.squareOf(s, "Property")
		local second = first + 1
		local full = priceOf(s, first)
		local half = math.floor(full * Economy.cards.discountMultiplier)

		-- A juega su Descuento y cierra el turno sin comprar.
		Fixtures.turnOf(s, a.id)
		Fixtures.hand(s, a.id, "Discount")
		s.phase = "AwaitEnd"
		playCard(s, a.id, "Discount")
		expect(pendingOf(s).discounts).toEqual({ [a.id] = true })
		local ended = Engine.apply(s, a.id, { type = "EndTurn" })
		if not ended.ok then
			error(ended.error, 2)
		end

		-- El Descuento de B no cancela el de A; C, sin carta, paga el precio completo.
		expect(s.players[s.turnIndex].id).toBe(b.id)
		Fixtures.hand(s, b.id, "Discount")
		playCard(s, b.id, "Discount")
		expect(pendingOf(s).discounts).toEqual({ [a.id] = true, [b.id] = true })
		expect(Property.priceFor(s, c.id, first)).toBe(full)

		-- Cada compra consume la marca de su comprador y solo la suya.
		s.phase = "AwaitBuy"
		pendingOf(s).index = first
		local boughtB = Engine.apply(s, b.id, { type = "Buy" })
		if not boughtB.ok then
			error(boughtB.error, 2)
		end
		expect(boughtB.events[1].price).toBe(half)
		expect(b.cash).toBe(Economy.startingCash - half)
		expect(pendingOf(s).discounts).toEqual({ [a.id] = true })

		Fixtures.turnOf(s, a.id)
		s.phase = "AwaitBuy"
		pendingOf(s).index = second
		local boughtA = Engine.apply(s, a.id, { type = "Buy" })
		if not boughtA.ok then
			error(boughtA.error, 2)
		end
		expect(boughtA.events[1].price).toBe(
			math.floor(priceOf(s, second) * Economy.cards.discountMultiplier)
		)
		expect(pendingOf(s).discounts).toEqual({})
	end)

	it("no se aplica ni se consume en una subasta", function()
		local s = Fixtures.game({ players = 3 })
		local a = inTurn(s)
		local bidder = rivalsOf(s, a.id)[1]
		local index = Fixtures.squareOf(s, "Property")
		Fixtures.hand(s, a.id, "Discount")
		playCard(s, a.id, "Discount")
		s.phase = "AwaitBuy"
		pendingOf(s).index = index
		local declined = Engine.apply(s, a.id, { type = "DeclineBuy" })
		if not declined.ok then
			error(declined.error, 2)
		end
		local bid = Engine.apply(s, bidder.id, { type = "Bid", amount = 100 })
		if not bid.ok then
			error(bid.error, 2)
		end
		Engine.timeout(s)
		expect(s.properties[index].ownerId).toBe(bidder.id)
		expect(bidder.cash).toBe(Economy.startingCash - 100)
		-- La marca sigue reservada para la próxima compra directa del lanzador.
		expect(pendingOf(s).discounts[a.id]).toBe(true)
	end)
end)

describe("Empujón", function()
	it("mueve al rival 3 casillas sin resolver el destino", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local target = rivalsOf(s, a.id)[1]
		local destination = 1 + Economy.cards.shoveSteps
		Fixtures.hand(s, a.id, "Shove")
		Fixtures.placeOn(s, target.id, 1)
		local events = playCard(s, a.id, "Shove", target.id)
		expect(#events).toBe(2)
		expect(events[1]).toEqual({
			type = "CardPlayed",
			playerId = a.id,
			cardId = "Shove",
			targetId = target.id,
		})
		expect(events[2]).toEqual({
			type = "TokenMoved",
			playerId = target.id,
			from = 1,
			to = destination,
			path = { 2, 3, 4 },
		})
		expect(target.position).toBe(destination)
		expect(target.cash).toBe(Economy.startingCash)
		expect(a.cash).toBe(Economy.startingCash)
		expect(a.position).toBe(1)
		expect(a.hand).toEqual({})
		expect(s.phase).toBe("AwaitRoll")
		expect(pendingOf(s).index).toBe(nil)
		-- La casilla 4 está libre: si el destino se resolviera, abriría AwaitBuy.
		expect(s.properties[destination].ownerId).toBe(nil)
	end)

	it("paga la Salida si el empujón la cruza y sigue sin resolver el destino", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local target = rivalsOf(s, a.id)[1]
		-- Desde la penúltima casilla, 3 pasos cruzan la Salida y acaban en la propiedad 2.
		Fixtures.placeOn(s, target.id, #s.board.squares - 1)
		local destination = 2
		Fixtures.hand(s, a.id, "Shove")
		local events = playCard(s, a.id, "Shove", target.id)
		expect(#events).toBe(3)
		expect(events[2].type).toBe("TokenMoved")
		expect(events[3]).toEqual({
			type = "PassedStart",
			playerId = target.id,
			amount = Economy.startBonus,
		})
		expect(target.position).toBe(destination)
		expect(target.cash).toBe(Economy.startingCash + Economy.startBonus)
		-- La casilla 2 está libre: si el destino se resolviera, abriría AwaitBuy.
		expect(s.phase).toBe("AwaitRoll")
		expect(pendingOf(s).index).toBe(nil)
		expect(s.properties[destination].ownerId).toBe(nil)
	end)
end)

describe("Multa", function()
	it("cobra 100 al rival para el banco", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local target = rivalsOf(s, a.id)[1]
		Fixtures.hand(s, a.id, "Fine")
		local events = playCard(s, a.id, "Fine", target.id)
		expect(events).toEqual({
			{ type = "CardPlayed", playerId = a.id, cardId = "Fine", targetId = target.id },
		})
		expect(target.cash).toBe(Economy.startingCash - Economy.cards.fine)
		expect(a.cash).toBe(Economy.startingCash)
		expect(target.position).toBe(1)
		expect(a.position).toBe(1)
		expect(a.hand).toEqual({})
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("arruina al rival que no puede pagar", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local target = rivalsOf(s, a.id)[1]
		target.cash = 0
		Fixtures.hand(s, a.id, "Fine")
		local events = playCard(s, a.id, "Fine", target.id)
		expect(events[1].type).toBe("CardPlayed")
		expect(events[2]).toEqual({ type = "BankruptcyDeclared", playerId = target.id })
		expect(events[3].type).toBe("GameEnded")
		expect(events[3].winnerId).toBe(a.id)
		expect(target.status).toBe("Ghost")
		expect(target.cash).toBe(0)
		expect(a.cash).toBe(Economy.startingCash)
		expect(s.phase).toBe("GameOver")
	end)
end)

describe("Soborno", function()
	it("protege al lanzador del próximo castigo del Tribunal", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		Fixtures.hand(s, a.id, "Bribe")
		local events = playCard(s, a.id, "Bribe")
		expect(events).toEqual({ { type = "CardPlayed", playerId = a.id, cardId = "Bribe" } })
		expect(a.hand).toEqual({})
		expect(a.cash).toBe(Economy.startingCash)
		expect(a.position).toBe(1)
		expect(pendingOf(s).bribes).toEqual({ [a.id] = true })
		expect(s.phase).toBe("AwaitRoll")
	end)
end)

describe("Espía", function()
	it("copia la mano del rival sin publicarla en el evento", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local target = rivalsOf(s, a.id)[1]
		Fixtures.hand(s, target.id, "Reverse")
		Fixtures.hand(s, target.id, "Fine")
		Fixtures.hand(s, a.id, "Spy")
		local events = playCard(s, a.id, "Spy", target.id)
		expect(events).toEqual({
			{ type = "CardPlayed", playerId = a.id, cardId = "Spy", targetId = target.id },
		})
		-- La mano no viaja en el evento: el servidor la entrega en privado.
		expect(events[1].hand).toBe(nil)
		expect(pendingOf(s).spy).toEqual({
			viewerId = a.id,
			targetId = target.id,
			hand = { "Reverse", "Fine" },
		})
		-- Es una copia: los cambios posteriores del rival no reescriben lo que vio el lanzador.
		table.insert(target.hand, "Reverse")
		expect(pendingOf(s).spy.hand).toEqual({ "Reverse", "Fine" })
		expect(a.hand).toEqual({})
		expect(a.cash).toBe(Economy.startingCash)
		expect(a.position).toBe(1)
	end)

	it("no deja la mano espiada en el estado compartido al cerrar el turno", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		Fixtures.hand(s, a.id, "Spy")
		playCard(s, a.id, "Spy", rivalsOf(s, a.id)[1].id)
		expect(pendingOf(s).spy ~= nil).toBe(true)
		s.phase = "AwaitEnd"
		local ended = Engine.apply(s, a.id, { type = "EndTurn" })
		if not ended.ok then
			error(ended.error, 2)
		end
		expect(pendingOf(s).spy).toBe(nil)
	end)

	it("tampoco deja el Espía cuando el jugador abandona", function()
		local s = Fixtures.game({ players = 3 })
		local a = inTurn(s)
		Fixtures.hand(s, a.id, "Spy")
		playCard(s, a.id, "Spy", rivalsOf(s, a.id)[1].id)
		a.status = "Left"
		Engine.timeout(s)
		expect(pendingOf(s).spy).toBe(nil)
	end)
end)

describe("objetivo de las cartas", function()
	it("rechaza sin objetivo, a sí mismo, a un espectro o a un ausente", function()
		local s = Fixtures.game({ players = 3 })
		local a = inTurn(s)
		local ghost = rivalsOf(s, a.id)[1]
		ghost.status = "Ghost"
		Fixtures.hand(s, a.id, "Shove")
		local before = deepCopy(s)
		expect(rejected(Engine.apply(s, a.id, { type = "PlayCard", cardId = "Shove" }))).toBe(
			"La carta Shove necesita un objetivo"
		)
		expect(rejected(Engine.apply(s, a.id, { type = "PlayCard", cardId = "Shove", targetId = a.id }))).toBe(
			"El objetivo de la carta debe ser otro jugador"
		)
		expect(rejected(Engine.apply(s, a.id, { type = "PlayCard", cardId = "Shove", targetId = ghost.id }))).toBe(
			`El objetivo {ghost.id} no es un rival activo`
		)
		expect(rejected(Engine.apply(s, a.id, { type = "PlayCard", cardId = "Shove", targetId = "P9" }))).toBe(
			"El objetivo P9 no está en la partida"
		)
		expect(deepCopy(s)).toEqual(before)
	end)
end)

describe("Economy.cards", function()
	it("fija los valores de las cartas comunes de la ficha", function()
		expect(Economy.cards.forcedTip).toBe(50)
		expect(Economy.cards.fine).toBe(100)
		expect(Economy.cards.shoveSteps).toBe(3)
		expect(Economy.cards.discountMultiplier).toBe(0.5)
	end)
end)

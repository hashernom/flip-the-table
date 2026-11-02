--!strict
-- Permisos por acción, tiempo agotado y bot. Es la puerta que hace jugable el motor sin humano.
local Harness = require("../harness")
local Board = require("../../src/shared/rules/Board")
local Bot = require("../../src/shared/rules/Bot")
local Building = require("../../src/shared/rules/Building")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Types = require("../../src/shared/rules/Types")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function inTurn(state: Types.GameState): Types.Player
	return state.players[state.turnIndex]
end

local function otherThan(state: Types.GameState, playerId: Types.PlayerId): Types.Player
	for _, player in state.players do
		if player.id ~= playerId then
			return player
		end
	end
	error("la partida necesita al menos dos jugadores", 2)
end

-- pending es la tabla persistente que State.create siempre crea (R1).
local function pendingOf(state: Types.GameState): any
	local pending = state.pending
	if not pending then
		error("el estado no tiene pending", 2)
	end
	return pending
end

-- Copia profunda: los rechazos se comprueban contra el estado entero y cada acción legal se
-- reproduce sobre una copia independiente.
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

local function priceOf(state: Types.GameState, index: number): number
	local price = state.board.squares[index].price
	if not price then
		error(`la casilla {index} no tiene precio`, 2)
	end
	return price
end

local function zoneOf(state: Types.GameState, index: number): { number }
	local zone = Board.zoneOf(state, index)
	if not zone then
		error(`la casilla {index} no tiene zona`, 2)
	end
	return zone
end

local function zoneIdOf(state: Types.GameState, index: number): string
	local zoneId = state.board.squares[index].zoneId
	if not zoneId then
		error(`la casilla {index} no tiene zona`, 2)
	end
	return zoneId
end

-- Primera propiedad de otra zona: sirve para comprobar que el bot elige la construcción más
-- barata cuando tiene varias zonas completas.
local function propertyOutsideZone(state: Types.GameState, zoneId: string): number
	for _, square in state.board.squares do
		if square.kind == "Property" and square.zoneId ~= zoneId then
			return square.index
		end
	end
	error(`no hay propiedades fuera de la zona {zoneId}`, 2)
end

-- Construir exige la zona completa; el arnés no cobra las propiedades que entrega.
local function giveZone(state: Types.GameState, playerId: Types.PlayerId, index: number)
	for _, member in zoneOf(state, index) do
		Fixtures.give(state, playerId, member)
	end
end

-- Abre AwaitBuy por la vía real: desde la Salida, un 1+1 cae en la segunda propiedad, que
-- State.create deja libre.
local function setupAwaitBuy(state: Types.GameState, playerId: Types.PlayerId): number
	Fixtures.placeOn(state, playerId, 1)
	Fixtures.dice(state, 1, 1)
	local result = Engine.apply(state, playerId, { type = "Roll" })
	if not result.ok then
		error(result.error, 2)
	end
	expect(state.phase).toBe("AwaitBuy")
	return pendingOf(state).index
end

-- Abre la subasta por la vía normal del motor: AwaitBuy + DeclineBuy.
local function setupAuction(state: Types.GameState, playerId: Types.PlayerId): number
	local index = setupAwaitBuy(state, playerId)
	local result = Engine.apply(state, playerId, { type = "DeclineBuy" })
	if not result.ok then
		error(result.error, 2)
	end
	expect(state.phase).toBe("Auction")
	return index
end

-- Exige un rechazo sin cambios: compara una copia profunda del estado antes y después.
local function rejectedWithoutChange(
	state: Types.GameState,
	playerId: Types.PlayerId,
	action: Types.Action
): string
	local before = deepCopy(state)
	local result = Engine.apply(state, playerId, action)
	if result.ok then
		error("se esperaba un rechazo y la acción se aplicó", 3)
	end
	expect(deepCopy(state)).toEqual(before)
	return result.error
end

-- Comprueba que una acción del bot es legal aplicándola sobre una copia del estado.
local function expectLegal(
	state: Types.GameState,
	playerId: Types.PlayerId,
	action: Types.Action?
): Types.Action
	if not action then
		error("el bot no eligió ninguna acción", 2)
	end
	local copy = deepCopy(state)
	local result = Engine.apply(copy, playerId, action)
	if not result.ok then
		error(`el bot eligió una acción ilegal: {result.error}`, 2)
	end
	return action
end

describe("acciones ilegales", function()
	it("rechaza actuar fuera de turno sin cambiar nada", function()
		local s = Fixtures.game({ players = 4 })
		local other = s.players[s.turnIndex % 4 + 1].id
		expect(rejectedWithoutChange(s, other, { type = "Roll" })).toBe("No es tu turno")
	end)

	it("rechaza una acción en una fase equivocada sin cambiar nada", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s).id
		expect(rejectedWithoutChange(s, actor, { type = "EndTurn" })).toBe(
			"No se puede EndTurn en la fase AwaitRoll"
		)
	end)

	it("rechaza a un jugador que no está en la partida", function()
		local s = Fixtures.game({ players = 2 })
		expect(rejectedWithoutChange(s, "P9", { type = "Roll" })).toBe("El jugador P9 no está en la partida")
	end)

	it("rechaza a un jugador que ha abandonado la partida", function()
		local s = Fixtures.game({ players = 2 })
		local left = inTurn(s)
		left.status = "Left"
		expect(rejectedWithoutChange(s, left.id, { type = "Roll" })).toBe(
			"El jugador ha abandonado la partida"
		)
	end)

	it("rechaza cualquier acción con la partida terminada", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s).id
		s.phase = "GameOver"
		expect(rejectedWithoutChange(s, actor, { type = "Roll" })).toBe("La partida ha terminado")
		expect(rejectedWithoutChange(s, actor, { type = "EndTurn" })).toBe("La partida ha terminado")
	end)
end)

describe("Engine.legalActions", function()
	it("enumera Roll y una Build por casilla edificable", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		giveZone(s, actor.id, idx)
		local zone = zoneOf(s, idx)
		expect(Engine.legalActions(s, actor.id)).toEqual({
			{ type = "Roll" },
			{ type = "Build", index = zone[1] },
			{ type = "Build", index = zone[2] },
			{ type = "Build", index = zone[3] },
		})
	end)

	it("no enumera Build sin zona completa ni sin efectivo", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		local zone = zoneOf(s, idx)
		Fixtures.give(s, actor.id, zone[1])
		Fixtures.give(s, actor.id, zone[2])
		expect(Engine.legalActions(s, actor.id)).toEqual({ { type = "Roll" } })
		Fixtures.give(s, actor.id, zone[3])
		actor.cash = Building.costOf(s, actor.id, zone[1]) - 1
		expect(Engine.legalActions(s, actor.id)).toEqual({ { type = "Roll" } })
	end)

	it("un espectro en turno solo puede tirar", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s)
		giveZone(s, actor.id, Fixtures.squareOf(s, "Property"))
		actor.status = "Ghost"
		expect(Engine.legalActions(s, actor.id)).toEqual({ { type = "Roll" } })
	end)

	it("no enumera nada para quien no está en turno", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s)
		local other = otherThan(s, actor.id)
		giveZone(s, other.id, Fixtures.squareOf(s, "Property"))
		expect(Engine.legalActions(s, other.id)).toEqual({})
	end)

	it("en AwaitBuy enumera Buy y DeclineBuy cuando puede pagar", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s)
		setupAwaitBuy(s, actor.id)
		expect(Engine.legalActions(s, actor.id)).toEqual({ { type = "Buy" }, { type = "DeclineBuy" } })
	end)

	it("en AwaitBuy omite Buy cuando no le llega el efectivo", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s)
		local index = setupAwaitBuy(s, actor.id)
		actor.cash = priceOf(s, index) - 1
		expect(Engine.legalActions(s, actor.id)).toEqual({ { type = "DeclineBuy" } })
	end)

	it("en AwaitBuy no enumera nada para quien no está en turno", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s)
		local other = otherThan(s, actor.id)
		setupAwaitBuy(s, actor.id)
		expect(Engine.legalActions(s, other.id)).toEqual({})
	end)

	it("en Auction enumera una sola puja representativa por jugador activo", function()
		local s = Fixtures.game({ players = 3 })
		local roller = inTurn(s)
		setupAuction(s, roller.id)
		local expected = { { type = "Bid", amount = Economy.auctionBidStep } }
		for _, player in s.players do
			expect(Engine.legalActions(s, player.id)).toEqual(expected)
		end
	end)

	it("en Auction sube el mínimo y omite la puja del que ya va ganando", function()
		local s = Fixtures.game({ players = 3 })
		local roller = inTurn(s)
		local other = otherThan(s, roller.id)
		setupAuction(s, roller.id)
		local bid = Engine.apply(s, roller.id, { type = "Bid", amount = 50 })
		if not bid.ok then
			error(bid.error, 2)
		end
		expect(Engine.legalActions(s, roller.id)).toEqual({})
		expect(Engine.legalActions(s, other.id)).toEqual({
			{ type = "Bid", amount = 50 + Economy.auctionBidStep },
		})
		other.cash = 55
		expect(Engine.legalActions(s, other.id)).toEqual({ { type = "Bid", amount = 55 } })
		other.cash = 50
		expect(Engine.legalActions(s, other.id)).toEqual({})
	end)

	it("en Auction un espectro no puede pujar", function()
		local s = Fixtures.game({ players = 3 })
		local roller = inTurn(s)
		local ghost = otherThan(s, roller.id)
		setupAuction(s, roller.id)
		ghost.status = "Ghost"
		expect(Engine.legalActions(s, ghost.id)).toEqual({})
	end)

	it("en AwaitEnd enumera EndTurn y las Build edificables", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		giveZone(s, actor.id, idx)
		s.phase = "AwaitEnd"
		local zone = zoneOf(s, idx)
		expect(Engine.legalActions(s, actor.id)).toEqual({
			{ type = "EndTurn" },
			{ type = "Build", index = zone[1] },
			{ type = "Build", index = zone[2] },
			{ type = "Build", index = zone[3] },
		})
	end)

	it("no enumera ofertas de intercambio aunque haya alguna viva", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s)
		local other = otherThan(s, actor.id)
		table.insert(pendingOf(s).trades, {
			id = "T1",
			fromId = actor.id,
			toId = other.id,
			giveCash = 0,
			wantCash = 0,
			giveSquares = {},
			wantSquares = {},
			round = 1,
			turnIndex = 1,
		})
		expect(Engine.legalActions(s, actor.id)).toEqual({ { type = "Roll" } })
	end)

	it("no enumera nada en otras fases ni con la partida terminada", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s).id
		s.phase = "Reaction"
		expect(Engine.legalActions(s, actor)).toEqual({})
		s.phase = "GameOver"
		expect(Engine.legalActions(s, actor)).toEqual({})
	end)

	it("no enumera nada para un jugador fuera de la partida o que se fue", function()
		local s = Fixtures.game({ players = 2 })
		expect(Engine.legalActions(s, "P9")).toEqual({})
		local actor = inTurn(s)
		actor.status = "Left"
		expect(Engine.legalActions(s, actor.id)).toEqual({})
	end)
end)

describe("Engine.timeout", function()
	it("en AwaitRoll tira y abre la compra si la casilla está libre", function()
		local s = Fixtures.game({ players = 2 })
		local roller = inTurn(s)
		Fixtures.placeOn(s, roller.id, 1)
		Fixtures.dice(s, 1, 1)
		local events = Engine.timeout(s)
		expect(#events).toBe(2)
		expect(events[1]).toEqual({ type = "DiceRolled", playerId = roller.id, a = 1, b = 1 })
		expect(events[2].type).toBe("TokenMoved")
		expect(roller.position).toBe(3)
		expect(s.phase).toBe("AwaitBuy")
		expect(pendingOf(s).index).toBe(3)
		expect(s.players[s.turnIndex].id).toBe(roller.id)
	end)

	it("en AwaitRoll cierra el turno si la casilla es propia", function()
		local s = Fixtures.game({ players = 2 })
		local roller = inTurn(s)
		Fixtures.give(s, roller.id, 3)
		Fixtures.placeOn(s, roller.id, 1)
		Fixtures.dice(s, 1, 1)
		local events = Engine.timeout(s)
		expect(events[1].type).toBe("DiceRolled")
		expect(s.phase).toBe("AwaitEnd")
		expect(s.players[s.turnIndex].id).toBe(roller.id)
		expect(roller.cash).toBe(Economy.startingCash)
	end)

	it("en AwaitRoll cobra la renta de una propiedad ajena", function()
		local s = Fixtures.game({ players = 2 })
		local roller = inTurn(s)
		local owner = otherThan(s, roller.id)
		Fixtures.give(s, owner.id, 3)
		Fixtures.placeOn(s, roller.id, 1)
		Fixtures.dice(s, 1, 1)
		local events = Engine.timeout(s)
		expect(s.phase).toBe("AwaitEnd")
		expect(events[3].type).toBe("RentPaid")
		expect(roller.cash).toBe(Economy.startingCash - 6)
		expect(owner.cash).toBe(Economy.startingCash + 6)
	end)

	it("en AwaitBuy rechaza la compra y abre la subasta", function()
		local s = Fixtures.game({ players = 2 })
		local roller = inTurn(s)
		local index = setupAwaitBuy(s, roller.id)
		local events = Engine.timeout(s)
		expect(events).toEqual({ { type = "AuctionStarted", index = index } })
		expect(s.phase).toBe("Auction")
		expect(pendingOf(s).auction).toEqual({ index = index, high = 0 })
		expect(s.players[s.turnIndex].id).toBe(roller.id)
	end)

	it("en Auction cierra sin venta si no hubo pujas", function()
		local s = Fixtures.game({ players = 2 })
		local roller = inTurn(s)
		local index = setupAuction(s, roller.id)
		local events = Engine.timeout(s)
		expect(events).toEqual({ { type = "AuctionNoSale", index = index } })
		expect(s.phase).toBe("AwaitEnd")
		expect(s.properties[index].ownerId).toBe(nil)
		expect(pendingOf(s).auction).toBe(nil)
	end)

	it("en Auction cierra cobrando al ganador", function()
		local s = Fixtures.game({ players = 3 })
		local roller = inTurn(s)
		local bidder = otherThan(s, roller.id)
		local index = setupAuction(s, roller.id)
		local bid = Engine.apply(s, bidder.id, { type = "Bid", amount = 200 })
		if not bid.ok then
			error(bid.error, 2)
		end
		local events = Engine.timeout(s)
		expect(events).toEqual({
			{ type = "AuctionWon", index = index, playerId = bidder.id, amount = 200 },
		})
		expect(bidder.cash).toBe(Economy.startingCash - 200)
		expect(s.properties[index].ownerId).toBe(bidder.id)
		expect(s.phase).toBe("AwaitEnd")
		expect(pendingOf(s).auction).toBe(nil)
	end)

	it("en AwaitEnd termina el turno", function()
		local s = Fixtures.game({ players = 2 })
		local expectedNext = s.players[s.turnIndex % #s.players + 1].id
		s.phase = "AwaitEnd"
		local events = Engine.timeout(s)
		expect(events).toEqual({})
		expect(s.players[s.turnIndex].id).toBe(expectedNext)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("no hace nada en otras fases ni con la partida terminada", function()
		local s = Fixtures.game({ players = 2 })
		s.phase = "Reaction"
		local before = deepCopy(s)
		expect(Engine.timeout(s)).toEqual({})
		expect(deepCopy(s)).toEqual(before)
		s.phase = "GameOver"
		before = deepCopy(s)
		expect(Engine.timeout(s)).toEqual({})
		expect(deepCopy(s)).toEqual(before)
	end)

	it("devuelve eventos y nunca un ApplyResult", function()
		local s = Fixtures.game({ players = 2 })
		local events = Engine.timeout(s)
		expect(events[1].type).toBe("DiceRolled")
		expect((events :: any).ok).toBe(nil)
	end)
end)

describe("Bot.choose", function()
	it("tira en AwaitRoll aunque tenga casillas edificables", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s)
		giveZone(s, actor.id, Fixtures.squareOf(s, "Property"))
		expect(Bot.choose(s, actor.id)).toEqual({ type = "Roll" })
	end)

	it("compra solo si le quedan más de la reserva", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s)
		local index = setupAwaitBuy(s, actor.id)
		local price = priceOf(s, index)
		actor.cash = price + Economy.bot.buyReserve
		expect(Bot.choose(s, actor.id)).toEqual({ type = "DeclineBuy" })
		actor.cash = price + Economy.bot.buyReserve + 1
		expect(Bot.choose(s, actor.id)).toEqual({ type = "Buy" })
	end)

	it("no compra si no puede pagar", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s)
		local index = setupAwaitBuy(s, actor.id)
		actor.cash = priceOf(s, index) - 1
		expect(Bot.choose(s, actor.id)).toEqual({ type = "DeclineBuy" })
	end)

	it("construye la opción legal más barata que respeta la reserva", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s)
		local first = Fixtures.squareOf(s, "Property")
		giveZone(s, actor.id, first)
		local second = propertyOutsideZone(s, zoneIdOf(s, first))
		giveZone(s, actor.id, second)
		s.phase = "AwaitEnd"
		local cheap = Building.costOf(s, actor.id, first)
		local pricey = Building.costOf(s, actor.id, second)
		expect(cheap < pricey).toBe(true)
		actor.cash = cheap + Economy.bot.buildReserve + 1
		expect(Bot.choose(s, actor.id)).toEqual({ type = "Build", index = first })
	end)

	it("termina el turno si no puede construir respetando la reserva", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		giveZone(s, actor.id, idx)
		s.phase = "AwaitEnd"
		actor.cash = Building.costOf(s, actor.id, idx) + Economy.bot.buildReserve
		expect(Bot.choose(s, actor.id)).toEqual({ type = "EndTurn" })
	end)

	it("puja solo si la reserva de puja sigue intacta", function()
		local s = Fixtures.game({ players = 3 })
		local roller = inTurn(s)
		local bidder = otherThan(s, roller.id)
		setupAuction(s, roller.id)
		local bid = Engine.apply(s, roller.id, { type = "Bid", amount = 100 })
		if not bid.ok then
			error(bid.error, 2)
		end
		local amount = 100 + Economy.auctionBidStep
		bidder.cash = amount + Economy.bot.bidReserve
		expect(Bot.choose(s, bidder.id)).toBe(nil)
		bidder.cash = amount + Economy.bot.bidReserve + 1
		expect(Bot.choose(s, bidder.id)).toEqual({ type = "Bid", amount = amount })
	end)

	it("no puja si ya va ganando", function()
		local s = Fixtures.game({ players = 3 })
		local roller = inTurn(s)
		setupAuction(s, roller.id)
		local bid = Engine.apply(s, roller.id, { type = "Bid", amount = 100 })
		if not bid.ok then
			error(bid.error, 2)
		end
		expect(Bot.choose(s, roller.id)).toBe(nil)
	end)

	it("devuelve nil cuando no hay ninguna acción legal", function()
		local s = Fixtures.game({ players = 2 })
		expect(Bot.choose(s, "P9")).toBe(nil)
		local actor = inTurn(s)
		actor.status = "Left"
		expect(Bot.choose(s, actor.id)).toBe(nil)
		s.phase = "GameOver"
		expect(Bot.choose(s, actor.id)).toBe(nil)
	end)
end)

describe("legalActions y bot en una partida completa", function()
	it("toda acción legal se puede aplicar y el bot nunca elige una ilegal", function()
		local s = Fixtures.game({ players = 4, seed = 7, endMode = "Endless" })
		local states = 0
		local checked = 0
		local steps = 0
		local buyStates = 0
		local auctionStates = 0
		while s.phase ~= "GameOver" and states < 200 do
			states += 1
			if s.phase == "AwaitBuy" then
				buyStates += 1
			elseif s.phase == "Auction" then
				auctionStates += 1
			end
			for _, player in s.players do
				local actions = Engine.legalActions(s, player.id)
				for _, action in actions do
					local copy = deepCopy(s)
					local result = Engine.apply(copy, player.id, action)
					if not result.ok then
						error(`legalActions devolvió una acción ilegal: {result.error}`, 2)
					end
					checked += 1
				end
				local choice = Bot.choose(s, player.id)
				if choice then
					expectLegal(s, player.id, choice)
				elseif #actions > 0 then
					-- Solo la subasta puede devolver nil con una puja legal: el bot no puja.
					expect(s.phase).toBe("Auction")
				end
			end
			local actor = s.players[s.turnIndex].id
			local choice = Bot.choose(s, actor)
			local phase = s.phase
			local turnIndex = s.turnIndex
			local round = s.round
			if choice then
				local result = Engine.apply(s, actor, choice)
				if not result.ok then
					error(result.error, 2)
				end
			else
				local events = Engine.timeout(s)
				local progressed = s.phase ~= phase
					or s.turnIndex ~= turnIndex
					or s.round ~= round
					or #events > 0
				if not progressed then
					error("el bucle de simulación no avanzó", 2)
				end
			end
			steps += 1
			if steps > 1000 then
				error("el bucle de simulación no terminó", 2)
			end
		end
		expect(states).toBe(200)
		expect(checked > states).toBeTruthy()
		expect(buyStates > 0).toBe(true)
		expect(auctionStates > 0).toBe(true)
	end)
end)

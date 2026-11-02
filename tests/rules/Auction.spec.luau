--!strict
local Harness = require("../harness")
local Auction = require("../../src/shared/rules/Auction")
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

-- Primera casilla de propiedad sin dueño.
local function freeSquare(state: Types.GameState): number
	for _, square in state.board.squares do
		if square.kind == "Property" then
			local property = state.properties[square.index]
			if not property or not property.ownerId then
				return square.index
			end
		end
	end
	error("el tablero no tiene propiedades libres", 2)
end

-- Abre la subasta por la vía normal del motor: AwaitBuy + DeclineBuy.
local function declineToAuction(
	state: Types.GameState,
	playerId: Types.PlayerId,
	index: number
): { Types.Event }
	Fixtures.turnOf(state, playerId)
	state.phase = "AwaitBuy"
	pendingOf(state).index = index
	local result = Engine.apply(state, playerId, { type = "DeclineBuy" })
	if not result.ok then
		error(result.error, 2)
	end
	return result.events
end

-- Abre la subasta directamente y comprueba el estado mínimo de arranque.
local function startAuction(state: Types.GameState, index: number)
	local events = Auction.start(state, index)
	expect(events).toEqual({ { type = "AuctionStarted", index = index } })
	expect(state.phase).toBe("Auction")
end

describe("Auction.start", function()
	it("abre la subasta de una casilla libre y emite AuctionStarted", function()
		local s = Fixtures.game({ players = 2 })
		local idx = freeSquare(s)
		local events = Auction.start(s, idx)
		expect(events).toEqual({ { type = "AuctionStarted", index = idx } })
		expect(s.phase).toBe("Auction")
		expect(pendingOf(s).index).toBe(idx)
		expect(pendingOf(s).auction).toEqual({ index = idx, high = 0 })
		expect(pendingOf(s).auction.highBidder).toBe(nil)
		expect(s.properties[idx].ownerId).toBe(nil)
	end)

	it("señala una casilla que no es una propiedad", function()
		local s = Fixtures.game({ players = 2 })
		expect(function()
			Auction.start(s, Fixtures.squareOf(s, "Start"))
		end).toThrow()
	end)

	it("señala una propiedad que ya tiene dueño", function()
		local s = Fixtures.game({ players = 2 })
		local idx = freeSquare(s)
		Fixtures.give(s, inTurn(s).id, idx)
		expect(function()
			Auction.start(s, idx)
		end).toThrow()
	end)
end)

describe("Auction.bid", function()
	it("registra una puja válida sin mover dinero", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = freeSquare(s)
		startAuction(s, idx)
		local result = Auction.bid(s, a.id, 120)
		expect(result).toEqual({ ok = true, events = {} })
		expect(pendingOf(s).auction.high).toBe(120)
		expect(pendingOf(s).auction.highBidder).toBe(a.id)
		expect(a.cash).toBe(Economy.startingCash)
		expect(s.properties[idx].ownerId).toBe(nil)
	end)

	it("rechaza una puja que no supera la actual", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local other = otherThan(s, a.id)
		startAuction(s, freeSquare(s))
		Auction.bid(s, a.id, 100)
		local result = Auction.bid(s, other.id, 100)
		expect(rejected(result)).toBe("La puja debe superar la actual")
		expect(pendingOf(s).auction.high).toBe(100)
		expect(pendingOf(s).auction.highBidder).toBe(a.id)
		expect(other.cash).toBe(Economy.startingCash)
	end)

	it("rechaza una puja por encima del efectivo", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		startAuction(s, freeSquare(s))
		a.cash = 100
		local result = Auction.bid(s, a.id, 101)
		expect(rejected(result)).toBe("No tienes efectivo suficiente")
		expect(pendingOf(s).auction.high).toBe(0)
		expect(pendingOf(s).auction.highBidder).toBe(nil)
		expect(a.cash).toBe(100)
	end)

	it("acepta una puja igual al efectivo", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		startAuction(s, freeSquare(s))
		a.cash = 100
		expect(Auction.bid(s, a.id, 100)).toEqual({ ok = true, events = {} })
		expect(pendingOf(s).auction.high).toBe(100)
	end)

	it("rechaza una puja que no es un número entero", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		startAuction(s, freeSquare(s))
		expect(rejected(Auction.bid(s, a.id, 100.5))).toBe("La puja debe ser un número entero")
		expect(pendingOf(s).auction.high).toBe(0)
	end)

	it("rechaza una puja de cero o negativa", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		startAuction(s, freeSquare(s))
		expect(rejected(Auction.bid(s, a.id, 0))).toBe("La puja debe superar la actual")
		expect(rejected(Auction.bid(s, a.id, -10))).toBe("La puja debe superar la actual")
		expect(pendingOf(s).auction.high).toBe(0)
	end)

	it("rechaza pujar fuera de la fase Auction", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		expect(rejected(Auction.bid(s, a.id, 100))).toBe("No se puede pujar en la fase AwaitRoll")
	end)

	it("rechaza pujar sin subasta abierta", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		s.phase = "Auction"
		expect(rejected(Auction.bid(s, a.id, 100))).toBe("No hay ninguna subasta abierta")
	end)

	it("rechaza a un jugador que no está en la partida", function()
		local s = Fixtures.game({ players = 2 })
		startAuction(s, freeSquare(s))
		expect(rejected(Auction.bid(s, "P9", 100))).toBe("El jugador P9 no está en la partida")
	end)

	it("rechaza a un espectro", function()
		local s = Fixtures.game({ players = 2 })
		local ghost = otherThan(s, inTurn(s).id)
		startAuction(s, freeSquare(s))
		ghost.status = "Ghost"
		expect(rejected(Auction.bid(s, ghost.id, 100))).toBe("Solo los jugadores activos pueden pujar")
		expect(pendingOf(s).auction.high).toBe(0)
		expect(ghost.cash).toBe(Economy.startingCash)
	end)

	it("rechaza a un jugador que ha abandonado la partida", function()
		local s = Fixtures.game({ players = 2 })
		local left = otherThan(s, inTurn(s).id)
		startAuction(s, freeSquare(s))
		left.status = "Left"
		expect(rejected(Auction.bid(s, left.id, 100))).toBe("El jugador ha abandonado la partida")
	end)
end)

describe("Auction.close", function()
	it("con pujas cobra al ganador, le da la casilla y emite AuctionWon", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local other = otherThan(s, a.id)
		local idx = freeSquare(s)
		startAuction(s, idx)
		Auction.bid(s, a.id, 200)
		local events = Auction.close(s)
		expect(events).toEqual({
			{ type = "AuctionWon", index = idx, playerId = a.id, amount = 200 },
		})
		expect(a.cash).toBe(Economy.startingCash - 200)
		expect(other.cash).toBe(Economy.startingCash)
		expect(s.properties[idx].ownerId).toBe(a.id)
		expect(s.phase).toBe("AwaitEnd")
		expect(pendingOf(s).index).toBe(nil)
		expect(pendingOf(s).auction).toBe(nil)
	end)

	it("sin pujas deja la casilla libre y emite AuctionNoSale", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local other = otherThan(s, a.id)
		local idx = freeSquare(s)
		startAuction(s, idx)
		local events = Auction.close(s)
		expect(events).toEqual({ { type = "AuctionNoSale", index = idx } })
		expect(s.properties[idx].ownerId).toBe(nil)
		expect(s.phase).toBe("AwaitEnd")
		expect(pendingOf(s).index).toBe(nil)
		expect(pendingOf(s).auction).toBe(nil)
		expect(a.cash).toBe(Economy.startingCash)
		expect(other.cash).toBe(Economy.startingCash)
	end)

	it("gana la puja más alta", function()
		local s = Fixtures.game({ players = 3 })
		local a = inTurn(s)
		local b = otherThan(s, a.id)
		local idx = freeSquare(s)
		startAuction(s, idx)
		Auction.bid(s, a.id, 100)
		Auction.bid(s, b.id, 250)
		local events = Auction.close(s)
		expect(events).toEqual({
			{ type = "AuctionWon", index = idx, playerId = b.id, amount = 250 },
		})
		expect(b.cash).toBe(Economy.startingCash - 250)
		expect(a.cash).toBe(Economy.startingCash)
		expect(s.properties[idx].ownerId).toBe(b.id)
	end)

	it("señala cerrar sin ninguna subasta abierta", function()
		local s = Fixtures.game({ players = 2 })
		expect(function()
			Auction.close(s)
		end).toThrow()
	end)
end)

describe("Bid en el motor", function()
	it("cualquier jugador activo puede pujar aunque no sea su turno", function()
		local s = Fixtures.game({ players = 3 })
		local roller = inTurn(s)
		local bidder = otherThan(s, roller.id)
		local idx = freeSquare(s)
		declineToAuction(s, roller.id, idx)
		local result = Engine.apply(s, bidder.id, { type = "Bid", amount = 250 })
		if not result.ok then
			error(result.error, 2)
		end
		expect(result.events).toEqual({})
		expect(pendingOf(s).auction.high).toBe(250)
		expect(pendingOf(s).auction.highBidder).toBe(bidder.id)
		expect(s.phase).toBe("Auction")
		expect(s.players[s.turnIndex].id).toBe(roller.id)
	end)

	it("quien rechazó la compra puede pujar", function()
		local s = Fixtures.game({ players = 2 })
		local roller = inTurn(s)
		declineToAuction(s, roller.id, freeSquare(s))
		local result = Engine.apply(s, roller.id, { type = "Bid", amount = 90 })
		if not result.ok then
			error(result.error, 2)
		end
		expect(pendingOf(s).auction.high).toBe(90)
		expect(pendingOf(s).auction.highBidder).toBe(roller.id)
	end)

	it("un espectro no puede pujar", function()
		local s = Fixtures.game({ players = 2 })
		local roller = inTurn(s)
		local ghost = otherThan(s, roller.id)
		declineToAuction(s, roller.id, freeSquare(s))
		ghost.status = "Ghost"
		local result = Engine.apply(s, ghost.id, { type = "Bid", amount = 100 })
		expect(rejected(result)).toBe("Solo los jugadores activos pueden pujar")
		expect(pendingOf(s).auction.high).toBe(0)
		expect(pendingOf(s).auction.highBidder).toBe(nil)
		expect(ghost.cash).toBe(Economy.startingCash)
	end)

	it("rechaza pujar fuera de la subasta", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		expect(rejected(Engine.apply(s, a.id, { type = "Bid", amount = 100 }))).toBe(
			"No se puede Bid en la fase AwaitRoll"
		)
		expect(pendingOf(s).auction).toBe(nil)
	end)

	it("rechaza una puja que no es entera desde la acción", function()
		local s = Fixtures.game({ players = 2 })
		local roller = inTurn(s)
		declineToAuction(s, roller.id, freeSquare(s))
		expect(rejected(Engine.apply(s, roller.id, { type = "Bid", amount = 50.5 }))).toBe(
			"La puja debe ser un número entero"
		)
		expect(pendingOf(s).auction.high).toBe(0)
	end)

	it("rechaza pujar con la partida terminada", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		s.phase = "GameOver"
		expect(rejected(Engine.apply(s, a.id, { type = "Bid", amount = 100 }))).toBe(
			"La partida ha terminado"
		)
	end)
end)

describe("DeclineBuy", function()
	it("abre la subasta con Auction.start y emite AuctionStarted", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = freeSquare(s)
		Fixtures.turnOf(s, a.id)
		s.phase = "AwaitBuy"
		pendingOf(s).index = idx
		local result = Engine.apply(s, a.id, { type = "DeclineBuy" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(result.events).toEqual({ { type = "AuctionStarted", index = idx } })
		expect(s.phase).toBe("Auction")
		expect(pendingOf(s).index).toBe(idx)
		expect(pendingOf(s).auction).toEqual({ index = idx, high = 0 })
		expect(pendingOf(s).auction.highBidder).toBe(nil)
		expect(s.properties[idx].ownerId).toBe(nil)
	end)
end)

describe("cierre de la subasta", function()
	it("el ganador paga, recibe la propiedad y el turno sigue en AwaitEnd", function()
		local s = Fixtures.game({ players = 3 })
		local roller = inTurn(s)
		local winner = otherThan(s, roller.id)
		-- Desde la Salida, 1+1 avanza dos casillas: la segunda propiedad de la primera zona.
		local idx = Fixtures.squareOf(s, "Property") + 1
		Fixtures.placeOn(s, roller.id, 1)
		Fixtures.dice(s, 1, 1)
		local roll = Engine.apply(s, roller.id, { type = "Roll" })
		if not roll.ok then
			error(roll.error, 2)
		end
		expect(roller.position).toBe(idx)
		expect(s.phase).toBe("AwaitBuy")
		local decline = Engine.apply(s, roller.id, { type = "DeclineBuy" })
		if not decline.ok then
			error(decline.error, 2)
		end
		expect(decline.events).toEqual({ { type = "AuctionStarted", index = idx } })
		local bid = Engine.apply(s, winner.id, { type = "Bid", amount = 300 })
		if not bid.ok then
			error(bid.error, 2)
		end
		local events = Auction.close(s)
		expect(events).toEqual({
			{ type = "AuctionWon", index = idx, playerId = winner.id, amount = 300 },
		})
		expect(winner.cash).toBe(Economy.startingCash - 300)
		expect(roller.cash).toBe(Economy.startingCash)
		expect(s.properties[idx].ownerId).toBe(winner.id)
		expect(s.phase).toBe("AwaitEnd")
		expect(s.players[s.turnIndex].id).toBe(roller.id)
		expect(pendingOf(s).index).toBe(nil)
		expect(pendingOf(s).auction).toBe(nil)
		expect(Engine.apply(s, roller.id, { type = "EndTurn" }).ok).toBe(true)
	end)
end)

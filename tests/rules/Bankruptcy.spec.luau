--!strict
local Harness = require("../harness")
local Bankruptcy = require("../../src/shared/rules/Bankruptcy")
local Economy = require("../../src/shared/config/Economy")
local Fixtures = require("../fixtures")
local Property = require("../../src/shared/rules/Property")
local Score = require("../../src/shared/rules/Score")
local Types = require("../../src/shared/rules/Types")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

-- Primera casilla de propiedad con el precio indicado. Los tableros pequeños siempre tienen
-- las zonas básicas, así que 60, 130, 200, 260, 330 y 400 existen en cualquier tamaño.
local function squareOfPrice(state: Types.GameState, price: number): number
	for _, square in state.board.squares do
		if square.kind == "Property" and square.price == price then
			return square.index
		end
	end
	error(`no hay ninguna propiedad de precio {price}`, 2)
end

local function priceOf(state: Types.GameState, index: number): number
	local price = state.board.squares[index].price
	if not price then
		error(`la casilla {index} no tiene precio`, 2)
	end
	return price
end

-- Mitad del valor, redondeada hacia abajo: lo que paga el banco por un bien.
local function half(value: number): number
	return math.floor(value / 2)
end

-- Coste de un nivel de edificio, según Economy (misma fórmula que Building.costOf).
local function levelCost(state: Types.GameState, index: number): number
	return math.floor(priceOf(state, index) * Economy.buildingCostRate)
end

local function cashTotal(state: Types.GameState): number
	local total = 0
	for _, player in state.players do
		total += player.cash
	end
	return total
end

local function ownerCount(state: Types.GameState, playerId: Types.PlayerId): number
	local count = 0
	for _, property in state.properties do
		if property.ownerId == playerId then
			count += 1
		end
	end
	return count
end

describe("Bankruptcy.charge", function()
	it("no crea dinero al arruinarse", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		a.cash = 100
		Bankruptcy.charge(s, a.id, 5000, b.id)
		expect(a.status).toBe("Ghost")
		expect(a.cash).toBe(0)
		expect(b.cash).toBe(1600)
	end)

	it("vende antes de arruinarse", function()
		-- A con 50 y una propiedad de 200 debe 100: vende, paga y sigue Active con 50.
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		local idx = squareOfPrice(s, 200)
		Fixtures.give(s, a.id, idx)
		a.cash = 50
		local events = Bankruptcy.charge(s, a.id, 100, b.id)
		expect(a.status).toBe("Active")
		expect(a.cash).toBe(50)
		expect(s.properties[idx].ownerId).toBe(nil)
		expect(b.cash).toBe(Economy.startingCash + 100)
		expect(events).toEqual({})
	end)

	it("paga sin vender si el efectivo alcanza", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		local idx = squareOfPrice(s, 60)
		Fixtures.give(s, a.id, idx)
		a.cash = 500
		expect(Bankruptcy.charge(s, a.id, 100, b.id)).toEqual({})
		expect(a.status).toBe("Active")
		expect(a.cash).toBe(400)
		expect(s.properties[idx].ownerId).toBe(a.id)
		expect(b.cash).toBe(Economy.startingCash + 100)
	end)

	it("acepta pagar exactamente el efectivo disponible", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		a.cash = 100
		expect(Bankruptcy.charge(s, a.id, 100, b.id)).toEqual({})
		expect(a.status).toBe("Active")
		expect(a.cash).toBe(0)
		expect(b.cash).toBe(Economy.startingCash + 100)
	end)

	it("vende edificios antes que propiedades", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		local withBuilding = squareOfPrice(s, 200)
		local bare = squareOfPrice(s, 60)
		Fixtures.give(s, a.id, withBuilding)
		Fixtures.give(s, a.id, bare)
		s.properties[withBuilding].level = 1
		a.cash = 0
		Bankruptcy.charge(s, a.id, 10, b.id)
		-- El nivel vale 50 y ya cubre la deuda; la propiedad barata (30) no se toca.
		expect(s.properties[withBuilding].level).toBe(0)
		expect(s.properties[withBuilding].ownerId).toBe(a.id)
		expect(s.properties[bare].ownerId).toBe(a.id)
		expect(a.cash).toBe(half(levelCost(s, withBuilding)) - 10)
		expect(b.cash).toBe(Economy.startingCash + 10)
	end)

	it("vende primero el edificio más barato", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		-- Se cruzan los precios para que el edificio barato quede en el índice mayor: así la
		-- prueba distingue vender por valor de vender por orden de casilla.
		local cheap = squareOfPrice(s, 200)
		local expensive = squareOfPrice(s, 60)
		s.board.squares[cheap].price = 60
		s.board.squares[expensive].price = 200
		Fixtures.give(s, a.id, cheap)
		Fixtures.give(s, a.id, expensive)
		s.properties[cheap].level = 1
		s.properties[expensive].level = 1
		a.cash = 0
		Bankruptcy.charge(s, a.id, 10, b.id)
		-- El nivel barato vale 15 y ya cubre la deuda: el caro conserva su nivel.
		expect(s.properties[cheap].level).toBe(0)
		expect(s.properties[expensive].level).toBe(1)
		expect(s.properties[cheap].ownerId).toBe(a.id)
		expect(s.properties[expensive].ownerId).toBe(a.id)
		expect(a.cash).toBe(half(levelCost(s, cheap)) - 10)
	end)

	it("vende primero la propiedad más barata", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		-- Igual que con los edificios: el precio barato va al índice mayor.
		local cheap = squareOfPrice(s, 200)
		local expensive = squareOfPrice(s, 60)
		s.board.squares[cheap].price = 60
		s.board.squares[expensive].price = 200
		Fixtures.give(s, a.id, cheap)
		Fixtures.give(s, a.id, expensive)
		a.cash = 0
		Bankruptcy.charge(s, a.id, 10, b.id)
		-- La barata vale 30 y cubre la deuda: la cara sigue siendo del jugador.
		expect(s.properties[cheap].ownerId).toBe(nil)
		expect(s.properties[expensive].ownerId).toBe(a.id)
		expect(a.cash).toBe(half(priceOf(s, cheap)) - 10)
	end)

	it("cobra solo lo disponible y deja al jugador como espectro", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		local idx = squareOfPrice(s, 60)
		Fixtures.give(s, a.id, idx)
		s.properties[idx].level = 2
		a.cash = 100
		local events = Bankruptcy.charge(s, a.id, 5000, b.id)
		-- Dos niveles de 15 y la propiedad de 30: 60 de patrimonio más 100 de efectivo.
		expect(b.cash).toBe(Economy.startingCash + 160)
		expect(a.cash).toBe(0)
		expect(a.status).toBe("Ghost")
		expect(s.properties[idx].ownerId).toBe(nil)
		expect(s.properties[idx].level).toBe(0)
		expect(ownerCount(s, a.id)).toBe(0)
		-- R11: con dos jugadores, la bancarrota de uno cierra la partida en ese instante.
		local expected: { Types.Event } = {
			{ type = "BankruptcyDeclared", playerId = a.id, creditorId = b.id },
			{ type = "GameEnded", ranking = Score.ranking(s), winnerId = b.id },
		}
		expect(events).toEqual(expected)
	end)

	it("nunca deja efectivo negativo ni crea dinero al quebrar", function()
		local s = Fixtures.game({ players = 3 })
		local a, b = s.players[1], s.players[2]
		a.cash = 10
		local before = cashTotal(s)
		Bankruptcy.charge(s, a.id, 5000, b.id)
		expect(cashTotal(s)).toBe(before)
		expect(a.cash).toBe(0)
		for _, player in s.players do
			expect(player.cash >= 0).toBe(true)
		end
	end)

	it("sin acreedor, el banco no cobra a nadie", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		a.cash = 100
		local events = Bankruptcy.charge(s, a.id, 5000)
		expect(a.status).toBe("Ghost")
		expect(a.cash).toBe(0)
		expect(b.cash).toBe(Economy.startingCash)
		-- Sin acreedor el banco no cobra, pero la partida termina igualmente (R11).
		local expected: { Types.Event } = {
			{ type = "BankruptcyDeclared", playerId = a.id },
			{ type = "GameEnded", ranking = Score.ranking(s), winnerId = b.id },
		}
		expect(events).toEqual(expected)
	end)

	it("no cobra a un acreedor espectro", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		b.status = "Ghost"
		a.cash = 100
		expect(Bankruptcy.charge(s, a.id, 40, b.id)).toEqual({})
		expect(a.cash).toBe(60)
		expect(b.cash).toBe(Economy.startingCash)
	end)

	it("no cobra a un acreedor que ha abandonado la partida", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		b.status = "Left"
		a.cash = 100
		local events = Bankruptcy.charge(s, a.id, 5000, b.id)
		expect(a.status).toBe("Ghost")
		expect(a.cash).toBe(0)
		expect(b.cash).toBe(Economy.startingCash)
		expect(events).toEqual({
			{ type = "BankruptcyDeclared", playerId = a.id, creditorId = b.id },
		})
	end)

	it("devuelve todas las propiedades del espectro al banco", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local first = squareOfPrice(s, 60)
		local second = squareOfPrice(s, 130)
		Fixtures.give(s, a.id, first)
		Fixtures.give(s, a.id, second)
		a.cash = 0
		Bankruptcy.charge(s, a.id, 5000)
		expect(ownerCount(s, a.id)).toBe(0)
		expect(s.properties[first].ownerId).toBe(nil)
		expect(s.properties[second].ownerId).toBe(nil)
		expect(s.properties[first].level).toBe(0)
		expect(s.properties[second].level).toBe(0)
	end)
end)

describe("Property.payRent con bancarrota", function()
	it("emite RentPaid y después BankruptcyDeclared cuando no alcanza", function()
		local s = Fixtures.game({ players = 2 })
		local owner, payer = s.players[1], s.players[2]
		local idx = squareOfPrice(s, 200)
		Fixtures.give(s, owner.id, idx)
		payer.cash = 5
		local rent = Property.rentFor(s, idx)
		local events = Property.payRent(s, payer.id, idx)
		expect(payer.status).toBe("Ghost")
		expect(payer.cash).toBe(0)
		expect(owner.cash).toBe(Economy.startingCash + 5)
		-- La anotación evita que Luau unifique los dos eventos en una sola forma.
		local expected: { Types.Event } = {
			{ type = "RentPaid", index = idx, from = payer.id, to = owner.id, amount = rent },
			{ type = "BankruptcyDeclared", playerId = payer.id, creditorId = owner.id },
			{ type = "GameEnded", ranking = Score.ranking(s), winnerId = owner.id },
		}
		expect(events).toEqual(expected)
	end)

	it("vende bienes para pagar la renta", function()
		local s = Fixtures.game({ players = 2 })
		local owner, payer = s.players[1], s.players[2]
		local rented = squareOfPrice(s, 200)
		local asset = squareOfPrice(s, 60)
		Fixtures.give(s, owner.id, rented)
		Fixtures.give(s, payer.id, asset)
		payer.cash = 0
		local events = Property.payRent(s, payer.id, rented)
		-- La renta son 20; la propiedad barata vale 30 al banco y deja 10 de sobra.
		expect(payer.status).toBe("Active")
		expect(payer.cash).toBe(10)
		expect(owner.cash).toBe(Economy.startingCash + 20)
		expect(s.properties[asset].ownerId).toBe(nil)
		expect(events).toEqual({
			{ type = "RentPaid", index = rented, from = payer.id, to = owner.id, amount = 20 },
		})
	end)
end)

describe("Score.netWorth", function()
	it("suma el efectivo y el precio de las propiedades", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		local idx = squareOfPrice(s, 60)
		Fixtures.give(s, a.id, idx)
		expect(Score.netWorth(s, a.id)).toBe(Economy.startingCash + priceOf(s, idx))
		expect(Score.netWorth(s, b.id)).toBe(Economy.startingCash)
	end)

	it("incluye los edificios", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[1]
		local idx = squareOfPrice(s, 200)
		Fixtures.give(s, a.id, idx)
		s.properties[idx].level = Economy.maxBuildingLevel
		expect(Score.netWorth(s, a.id)).toBe(
			Economy.startingCash + priceOf(s, idx) + Economy.maxBuildingLevel * levelCost(s, idx)
		)
	end)

	it("no cuenta las propiedades ajenas", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1], s.players[2]
		local idx = squareOfPrice(s, 60)
		Fixtures.give(s, b.id, idx)
		expect(Score.netWorth(s, a.id)).toBe(Economy.startingCash)
		expect(Score.netWorth(s, b.id)).toBe(Economy.startingCash + priceOf(s, idx))
	end)

	it("señala un jugador que no está en la partida", function()
		local s = Fixtures.game({ players = 2 })
		expect(function()
			Score.netWorth(s, "P9")
		end).toThrow()
	end)
end)

describe("Score.ranking", function()
	it("ordena por patrimonio de mayor a menor", function()
		local s = Fixtures.game({ players = 3 })
		local first, second, third = s.players[1], s.players[2], s.players[3]
		Fixtures.give(s, first.id, squareOfPrice(s, 200))
		Fixtures.give(s, second.id, squareOfPrice(s, 60))
		-- first: 1500 + 200; second: 1500 + 60; third: 1500.
		expect(Score.ranking(s)).toEqual({ first.id, second.id, third.id })
	end)

	it("desempata por efectivo", function()
		local s = Fixtures.game({ players = 2 })
		local first, second = s.players[1], s.players[2]
		first.cash = 0
		Fixtures.give(s, first.id, squareOfPrice(s, 60)) -- patrimonio 60
		second.cash = 60 -- patrimonio 60, pero más efectivo
		expect(Score.ranking(s)).toEqual({ second.id, first.id })
	end)

	it("desempata por orden de turno cuando patrimonio y efectivo coinciden", function()
		local s = Fixtures.game({ players = 3 })
		expect(Score.ranking(s)).toEqual({ s.players[1].id, s.players[2].id, s.players[3].id })
	end)

	it("devuelve todos los jugadores, también los espectros", function()
		local s = Fixtures.game({ players = 3 })
		s.players[2].status = "Ghost"
		local ranking = Score.ranking(s)
		expect(#ranking).toBe(3)
		for _, player in s.players do
			expect(table.find(ranking, player.id) ~= nil).toBe(true)
		end
	end)
end)

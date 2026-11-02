--!strict
-- Cartas legendarias: las cinco que sacuden la mesa y la retirada del campo obsoleto
-- `hurricaneUsed`. Cada prueba fija el estado antes y después; las de área comprueban además que
-- no se resuelve ninguna casilla, que nadie queda con efectivo negativo y que la partida sigue.
local Harness = require("../harness")
local Cards = require("../../src/shared/rules/Cards")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Rng = require("../../src/shared/rules/Rng")
local Types = require("../../src/shared/rules/Types")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

type PlayArgs = Cards.PlayArgs

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
	args: PlayArgs?
): { Types.Event }
	local action: Types.Action = { type = "PlayCard", cardId = cardId }
	if args then
		action.targetId = args.targetId
		action.zoneId = args.zoneId
		action.index = args.index
		action.pactId = args.pactId
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

local function zoneIndices(state: Types.GameState, position: number): { number }
	local zoneId = state.board.zoneOrder[position]
	local indices = state.board.zones[zoneId]
	if not indices then
		error(`la zona {zoneId} no existe`, 2)
	end
	return indices
end

local function zoneIdOf(state: Types.GameState, position: number): string
	return state.board.zoneOrder[position]
end

-- Lo que el banco paga por una casilla y sus edificios: la misma cuenta que Bankruptcy (mitad
-- del precio y mitad de cada nivel). Huracán compensa con este valor.
local function saleValue(state: Types.GameState, index: number, level: number): number
	local price = priceOf(state, index)
	local levelCost = math.floor(price * Economy.buildingCostRate)
	return math.floor(price / 2) + level * math.floor(levelCost / 2)
end

-- Destinos que el efecto debe sortear con la semilla actual: un Rng espejo con la misma semilla
-- consume los mismos números, así la prueba no depende de valores concretos del generador.
local function expectedFlips(state: Types.GameState): { [Types.PlayerId]: number }
	local mirror = Rng.new(state.rng.seed)
	local flips: { [Types.PlayerId]: number } = {}
	for _, player in state.players do
		if player.status == "Active" then
			flips[player.id] = Rng.int(mirror, 1, #state.board.squares)
		end
	end
	return flips
end

describe("Huracán", function()
	it("devuelve todas las propiedades al banco y compensa la mitad a sus dueños", function()
		local s = Fixtures.game({ players = 4 })
		local a = inTurn(s)
		local rival = s.players[2]
		local ghost = s.players[3]
		local zone = zoneIndices(s, 1)
		local terrace = zone[1]
		local tower = zone[2]
		local rivalSquare = zone[3]
		local ghostSquare = zoneIndices(s, 2)[1]
		Fixtures.give(s, a.id, terrace)
		Fixtures.give(s, a.id, tower)
		Fixtures.give(s, rival.id, rivalSquare)
		Fixtures.give(s, ghost.id, ghostSquare)
		s.properties[tower].level = 2
		s.properties[rivalSquare].level = 1
		s.properties[ghostSquare].level = 1
		ghost.status = "Ghost"
		local ghostCash = ghost.cash
		local casterBefore = a.cash
		local rivalBefore = rival.cash
		Fixtures.hand(s, a.id, "Hurricane")

		local events = playCard(s, a.id, "Hurricane")

		-- La compensación usa el valor de venta al banco: mitad del precio y mitad de cada nivel.
		local casterExpected = casterBefore + saleValue(s, terrace, 0) + saleValue(s, tower, 2)
		local rivalExpected = rivalBefore + saleValue(s, rivalSquare, 1)
		expect(a.cash).toBe(casterExpected)
		expect(rival.cash).toBe(rivalExpected)
		-- Quien ya no juega no cobra: sus bienes vuelven al banco como los demás.
		expect(ghost.cash).toBe(ghostCash)
		-- R-P22: solo CardPlayed; la compensación se ve en el estado.
		expect(events).toEqual({ { type = "CardPlayed", playerId = a.id, cardId = "Hurricane" } })
		for _, index in { terrace, tower, rivalSquare, ghostSquare } do
			expect(s.properties[index].ownerId).toBe(nil)
			expect(s.properties[index].level).toBe(0)
		end
		expect(a.hand).toEqual({})
		expect(s.stats[a.id].cardsPlayed).toBe(1)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("se puede jugar en la última ronda", function()
		local s = Fixtures.game({ players = 3 })
		local a = inTurn(s)
		local maxRounds = s.maxRounds
		if not maxRounds then
			error("la partida de prueba debería tener tope de rondas", 2)
		end
		s.round = maxRounds
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a.id, idx)
		Fixtures.hand(s, a.id, "Hurricane")

		local result = Engine.apply(s, a.id, { type = "PlayCard", cardId = "Hurricane" })

		expect(result.ok).toBe(true)
		expect(s.properties[idx].ownerId).toBe(nil)
		expect(s.round).toBe(maxRounds)
		-- El final por rondas lo decide EndTurn, nunca jugar una carta.
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("se puede jugar más de una vez en la misma partida", function()
		local s = Fixtures.game({ players = 3 })
		local a = inTurn(s)
		Fixtures.hand(s, a.id, "Hurricane")
		playCard(s, a.id, "Hurricane")
		-- Sin `hurricaneUsed` no queda marca que impida el segundo uso en otra ronda.
		s.round += 1
		Fixtures.hand(s, a.id, "Hurricane")

		local events = playCard(s, a.id, "Hurricane")

		expect(events).toEqual({ { type = "CardPlayed", playerId = a.id, cardId = "Hurricane" } })
		expect(a.hand).toEqual({})
		expect(s.stats[a.id].cardsPlayed).toBe(2)
		expect(s.phase).toBe("AwaitRoll")
	end)
end)

describe("Mundo al Revés", function()
	it("mueve cada ficha activa a una casilla al azar y no resuelve ninguna casilla", function()
		local s = Fixtures.game({ players = 4, seed = 9 })
		local a = inTurn(s)
		local ghost = s.players[2]
		local left = s.players[3]
		ghost.status = "Ghost"
		left.status = "Left"
		local beforePositions: { [Types.PlayerId]: number } = {}
		local beforeCash: { [Types.PlayerId]: number } = {}
		for _, player in s.players do
			beforePositions[player.id] = player.position
			beforeCash[player.id] = player.cash
		end
		local flips = expectedFlips(s)
		-- Con esta semilla la ficha del lanzador cae en una propiedad, que se asigna a un rival:
		-- si la casilla se resolviera, pagaría renta.
		local destination = flips[a.id]
		expect(s.board.squares[destination].kind).toBe("Property")
		for _, player in s.players do
			if player.id ~= a.id and player.status == "Active" then
				Fixtures.give(s, player.id, destination)
				break
			end
		end
		Fixtures.hand(s, a.id, "WorldFlip")

		local events = playCard(s, a.id, "WorldFlip")

		local expected: { Types.Event } = { { type = "CardPlayed", playerId = a.id, cardId = "WorldFlip" } }
		for _, player in s.players do
			if player.status == "Active" then
				table.insert(expected, {
					type = "TokenMoved",
					playerId = player.id,
					from = beforePositions[player.id],
					to = flips[player.id],
					path = {},
				})
			end
		end
		expect(events).toEqual(expected)
		for _, player in s.players do
			if player.status == "Active" then
				expect(player.position).toBe(flips[player.id])
			else
				expect(player.position).toBe(beforePositions[player.id])
			end
			expect(player.cash).toBe(beforeCash[player.id])
		end
		-- Nada se resuelve: no hay compra, renta ni casilla especial; la fase sigue en la tirada.
		expect(s.phase).toBe("AwaitRoll")
		expect(a.hand).toEqual({})
	end)

	it("es determinista con la misma semilla", function()
		local first = Fixtures.game({ players = 4, seed = 21 })
		local second = Fixtures.game({ players = 4, seed = 21 })
		local a = inTurn(first)
		local b = inTurn(second)
		expect(a.id).toBe(b.id)
		Fixtures.hand(first, a.id, "WorldFlip")
		Fixtures.hand(second, b.id, "WorldFlip")

		local firstEvents = playCard(first, a.id, "WorldFlip")
		local secondEvents = playCard(second, b.id, "WorldFlip")

		expect(secondEvents).toEqual(firstEvents)
		for index, player in first.players do
			expect(second.players[index].position).toBe(player.position)
		end
	end)
end)

describe("Revolución", function()
	it("con cuatro activos cambia el más rico con el más pobre y el segundo con el segundo", function()
		local s = Fixtures.game({ players = 4 })
		local a = inTurn(s)
		-- Patrimonio distinto (sin propiedades): 400 > 300 > 200 > 100.
		s.players[1].cash = 100
		s.players[2].cash = 200
		s.players[3].cash = 300
		s.players[4].cash = 400
		Fixtures.turnOf(s, a.id)
		Fixtures.hand(s, a.id, "Revolution")

		local events = playCard(s, a.id, "Revolution")

		expect(events).toEqual({ { type = "CardPlayed", playerId = a.id, cardId = "Revolution" } })
		expect(s.players[1].cash).toBe(400)
		expect(s.players[2].cash).toBe(300)
		expect(s.players[3].cash).toBe(200)
		expect(s.players[4].cash).toBe(100)
		local total = 0
		for _, player in s.players do
			total += player.cash
		end
		expect(total).toBe(1000)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("con tres activos cambia el primero y el último y no toca al espectro", function()
		local s = Fixtures.game({ players = 4 })
		local a = inTurn(s)
		local ghost = s.players[4]
		ghost.status = "Ghost"
		ghost.cash = 999999
		s.players[1].cash = 100
		s.players[2].cash = 200
		s.players[3].cash = 300
		Fixtures.turnOf(s, a.id)
		Fixtures.hand(s, a.id, "Revolution")

		playCard(s, a.id, "Revolution")

		-- Activos: 300 > 200 > 100. Cambian el primero y el último; el espectro queda fuera.
		expect(s.players[1].cash).toBe(300)
		expect(s.players[2].cash).toBe(200)
		expect(s.players[3].cash).toBe(100)
		expect(ghost.cash).toBe(999999)
	end)

	it("con dos activos cambia el primero y el último", function()
		local s = Fixtures.game({ players = 3 })
		local a = inTurn(s)
		local ghost = s.players[3]
		ghost.status = "Ghost"
		ghost.cash = 999999
		s.players[1].cash = 100
		s.players[2].cash = 300
		Fixtures.turnOf(s, a.id)
		Fixtures.hand(s, a.id, "Revolution")

		playCard(s, a.id, "Revolution")

		-- Dos activos: 300 > 100. Se intercambian y el espectro queda fuera.
		expect(s.players[1].cash).toBe(300)
		expect(s.players[2].cash).toBe(100)
		expect(ghost.cash).toBe(999999)
	end)
end)

describe("Terremoto", function()
	it("baja un nivel de los edificios de una zona y emite BuildingChanged por cambio", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local owner = s.players[2]
		local zone = zoneIndices(s, 1)
		local other = zoneIndices(s, 2)[1]
		Fixtures.give(s, owner.id, zone[1])
		Fixtures.give(s, owner.id, zone[2])
		s.properties[zone[1]].level = 2
		s.properties[zone[2]].level = 1
		Fixtures.give(s, owner.id, other)
		s.properties[other].level = 3
		Fixtures.hand(s, a.id, "Earthquake")

		local events = playCard(s, a.id, "Earthquake", { zoneId = zoneIdOf(s, 1) })

		local expected: { Types.Event } = {
			{ type = "CardPlayed", playerId = a.id, cardId = "Earthquake" },
			{ type = "BuildingChanged", index = zone[1], from = 2, to = 1 },
			{ type = "BuildingChanged", index = zone[2], from = 1, to = 0 },
		}
		expect(events).toEqual(expected)
		expect(s.properties[zone[1]].level).toBe(1)
		expect(s.properties[zone[2]].level).toBe(0)
		-- La casilla sin edificios no cambia y la otra zona no se toca.
		expect(s.properties[zone[3]].level).toBe(0)
		expect(s.properties[other].level).toBe(3)
		expect(owner.cash).toBe(Economy.startingCash)
		expect(a.cash).toBe(Economy.startingCash)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("sin edificios en la zona solo emite CardPlayed", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		Fixtures.hand(s, a.id, "Earthquake")

		local events = playCard(s, a.id, "Earthquake", { zoneId = zoneIdOf(s, 1) })

		expect(events).toEqual({ { type = "CardPlayed", playerId = a.id, cardId = "Earthquake" } })
	end)

	it("rechaza una zona ausente o inexistente sin tocar el estado", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		Fixtures.hand(s, a.id, "Earthquake")
		local before = deepCopy(s)
		expect(rejected(Engine.apply(s, a.id, { type = "PlayCard", cardId = "Earthquake" }))).toBe(
			"La carta Earthquake necesita una zona"
		)
		expect(
			rejected(
				Engine.apply(s, a.id, { type = "PlayCard", cardId = "Earthquake", zoneId = "zona-falsa" })
			)
		).toBe("La zona zona-falsa no existe")
		expect(deepCopy(s)).toEqual(before)
	end)
end)

describe("Golpe a la Corona", function()
	it("quita el 25 % al portador de la Corona y reparte el resto entre los demás activos", function()
		local s = Fixtures.game({ players = 4 })
		local a = inTurn(s)
		local leader = s.players[3]
		local richest = s.players[2]
		-- El líder de la Corona no es el más rico: manda el portador (R-P14).
		leader.cash = 1510
		richest.cash = 3000
		pendingOf(s).crownId = leader.id
		Fixtures.turnOf(s, a.id)
		Fixtures.hand(s, a.id, "CrownStrike")
		local before = 0
		for _, player in s.players do
			before += player.cash
		end

		local events = playCard(s, a.id, "CrownStrike", { targetId = leader.id })

		-- floor(1510 × 0,25) = 377; entre los otros tres activos, floor(377 / 3) = 125 y el
		-- resto (2) se queda con el líder: 1510 − 125 × 3 = 1135.
		local amount = 377
		local share = 125
		expect(leader.cash).toBe(1510 - amount + (amount - share * 3))
		expect(leader.cash).toBe(1135)
		for _, player in s.players do
			if player.id == richest.id then
				expect(player.cash).toBe(3000 + share)
			elseif player.id ~= leader.id then
				expect(player.cash).toBe(Economy.startingCash + share)
			end
		end
		local after = 0
		for _, player in s.players do
			after += player.cash
		end
		-- Nunca se crea ni se destruye efectivo: el reparto suma exactamente lo que pierde el líder.
		expect(after).toBe(before)
		expect(events).toEqual({
			{ type = "CardPlayed", playerId = a.id, cardId = "CrownStrike", targetId = leader.id },
		})
		expect(a.hand).toEqual({})
		expect(s.stats[a.id].cardsPlayed).toBe(1)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("usa el primer activo de la clasificación si la Corona no la lleva un activo", function()
		local s = Fixtures.game({ players = 4 })
		local a = inTurn(s)
		local crown = s.players[2]
		local fallback = s.players[3]
		crown.status = "Ghost"
		crown.cash = 100
		fallback.cash = 2000
		pendingOf(s).crownId = crown.id
		Fixtures.turnOf(s, a.id)
		Fixtures.hand(s, a.id, "CrownStrike")

		-- El espectro nunca es objetivo válido.
		expect(
			rejected(
				Engine.apply(s, a.id, { type = "PlayCard", cardId = "CrownStrike", targetId = crown.id })
			)
		).toBe(`El objetivo {crown.id} no es un rival activo`)

		-- El líder pasa a ser el primer activo de la clasificación: 25 % de 2000 = 500.
		local result =
			Engine.apply(s, a.id, { type = "PlayCard", cardId = "CrownStrike", targetId = fallback.id })
		expect(result.ok).toBe(true)
		expect(fallback.cash).toBe(1500)
	end)

	it("rechaza un objetivo que no es el líder o que falta sin tocar el estado", function()
		local s = Fixtures.game({ players = 4 })
		local a = inTurn(s)
		local leader = s.players[2]
		local other = s.players[4]
		leader.cash = 2000
		pendingOf(s).crownId = leader.id
		Fixtures.hand(s, a.id, "CrownStrike")
		local before = deepCopy(s)

		expect(
			rejected(
				Engine.apply(s, a.id, { type = "PlayCard", cardId = "CrownStrike", targetId = other.id })
			)
		).toBe("El objetivo de la carta debe ser el líder")
		expect(rejected(Engine.apply(s, a.id, { type = "PlayCard", cardId = "CrownStrike" }))).toBe(
			"La carta CrownStrike necesita un objetivo"
		)
		expect(deepCopy(s)).toEqual(before)
	end)

	it("acota el cobro al efectivo disponible si el porcentaje superara el 100 %", function()
		local s = Fixtures.game({ players = 3 })
		local a = inTurn(s)
		local leader = s.players[2]
		leader.cash = 100
		pendingOf(s).crownId = leader.id
		Fixtures.hand(s, a.id, "CrownStrike")
		local configured = Economy.cards.crownStrikeRate
		Economy.cards.crownStrikeRate = 2
		local action: Types.Action = { type = "PlayCard", cardId = "CrownStrike", targetId = leader.id }
		-- pcall garantiza que el porcentaje se restaura aunque la acción falle.
		local ok, result = pcall(Engine.apply, s, a.id, action)
		Economy.cards.crownStrikeRate = configured
		if not ok then
			error(result, 2)
		end

		expect(result.ok).toBe(true)
		-- El cobro se acota a los 100 disponibles: no hay venta de bienes ni bancarrota, y el
		-- reparto (floor(100 / 2) = 50 por cabeza) deja al líder a 0 sin efectivo negativo.
		expect(leader.cash).toBe(0)
		expect(leader.status).toBe("Active")
		for _, player in s.players do
			if player.id ~= leader.id then
				expect(player.cash).toBe(Economy.startingCash + 50)
			end
		end
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("con un 25 % que redondea a 0 no cobra y el líder conserva su efectivo", function()
		local s = Fixtures.game({ players = 3 })
		local a = inTurn(s)
		local leader = s.players[2]
		leader.cash = 3
		pendingOf(s).crownId = leader.id
		Fixtures.hand(s, a.id, "CrownStrike")

		local events = playCard(s, a.id, "CrownStrike", { targetId = leader.id })

		-- floor(3 × 0,25) = 0: el cobro pasa igualmente por Bankruptcy.charge y es un no-op.
		expect(leader.cash).toBe(3)
		expect(leader.status).toBe("Active")
		expect(events).toEqual({
			{ type = "CardPlayed", playerId = a.id, cardId = "CrownStrike", targetId = leader.id },
		})
	end)
end)

describe("límites de las legendarias", function()
	it("ninguna deja efectivo negativo ni termina la partida", function()
		local cardIds = { "Hurricane", "WorldFlip", "Revolution", "Earthquake", "CrownStrike" }
		for _, cardId in cardIds do
			local s = Fixtures.game({ players = 4, seed = 5 })
			local a = inTurn(s)
			local zone = zoneIndices(s, 1)
			local leader = s.players[3]
			for _, player in s.players do
				player.cash = 0
			end
			-- Bienes para Huracán y Terremoto; el líder arranca con efectivo para que el 25 % de
			-- Golpe a la Corona sea observable.
			Fixtures.give(s, s.players[2].id, zone[1])
			s.properties[zone[1]].level = 3
			leader.cash = 12
			pendingOf(s).crownId = leader.id
			Fixtures.hand(s, a.id, cardId)
			local action: Types.Action = { type = "PlayCard", cardId = cardId }
			if cardId == "Earthquake" then
				action.zoneId = zoneIdOf(s, 1)
			elseif cardId == "CrownStrike" then
				action.targetId = leader.id
			end

			local result = Engine.apply(s, a.id, action)

			expect(result.ok).toBe(true)
			for _, player in s.players do
				expect(player.cash >= 0).toBe(true)
				expect(player.status).toBe("Active")
			end
			expect(s.phase).toBe("AwaitRoll")
			if cardId == "CrownStrike" then
				-- floor(12 × 0,25) = 3, uno por cabeza: el líder conserva 9 y cada rival cobra 1.
				expect(leader.cash).toBe(9)
				for _, player in s.players do
					if player.id ~= leader.id then
						expect(player.cash).toBe(1)
					end
				end
			end
		end
	end)

	it("retira el campo obsoleto hurricaneUsed del estado y del tipo", function()
		local s = Fixtures.game({ players = 2 })
		-- El campo ya no está en Types.GameState: un acceso tipado no compilaría. La prueba lo
		-- mira a través de `any` para fijar que tampoco existe en el estado en tiempo de ejecución.
		expect((s :: any).hurricaneUsed).toBe(nil)
	end)

	it("fija en Economy el porcentaje de Golpe a la Corona", function()
		expect(Economy.cards.crownStrikeRate).toBe(0.25)
	end)
end)

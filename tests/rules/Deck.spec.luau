--!strict
local Harness = require("../harness")
local Cards = require("../../src/shared/config/Cards")
local Deck = require("../../src/shared/rules/Deck")
local Economy = require("../../src/shared/config/Economy")
local Fixtures = require("../fixtures")
local Types = require("../../src/shared/rules/Types")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local TOLERANCE = 1e-9

-- Multiplicador del peso de legendaria según las rondas sin ninguna, en orden (0 a 7 o más).
local MULTIPLIERS = { 0.1, 0.25, 0.5, 1, 1.5, 2, 2.5, 3 }

type ExpectedCard = {
	id: string,
	name: string,
	rarity: Types.Rarity,
	target: Cards.CardTarget,
	reaction: boolean,
	leaderOnly: boolean?,
}

-- Tabla «Cartas de giro» de la ficha, en el mismo orden que el mazo.
local EXPECTED: { ExpectedCard } = {
	{ id = "Hurricane", name = "Huracán", rarity = "Legendary", target = "None", reaction = false },
	{ id = "WorldFlip", name = "Mundo al Revés", rarity = "Legendary", target = "None", reaction = false },
	{ id = "Revolution", name = "Revolución", rarity = "Legendary", target = "None", reaction = false },
	{ id = "Earthquake", name = "Terremoto", rarity = "Legendary", target = "Zone", reaction = false },
	{
		id = "CrownStrike",
		name = "Golpe a la Corona",
		rarity = "Legendary",
		target = "Player",
		reaction = false,
		leaderOnly = true,
	},
	{ id = "Inflation", name = "Inflación", rarity = "Rare", target = "None", reaction = false },
	{ id = "Strike", name = "Huelga", rarity = "Rare", target = "Zone", reaction = false },
	{ id = "BounceRent", name = "Renta Rebotada", rarity = "Rare", target = "Player", reaction = true },
	{
		id = "DeedThief",
		name = "Ladrón de Escrituras",
		rarity = "Rare",
		target = "Property",
		reaction = false,
	},
	{ id = "Backstab", name = "Puñalada", rarity = "Rare", target = "Pact", reaction = false },
	{ id = "Demolition", name = "Demolición", rarity = "Rare", target = "Property", reaction = false },
	{ id = "Shield", name = "Escudo", rarity = "Common", target = "None", reaction = true },
	{ id = "ExtraDie", name = "Dado Extra", rarity = "Common", target = "None", reaction = false },
	{ id = "Reverse", name = "Marcha Atrás", rarity = "Common", target = "None", reaction = false },
	{ id = "ForcedTip", name = "Propina Forzada", rarity = "Common", target = "None", reaction = false },
	{ id = "Discount", name = "Descuento", rarity = "Common", target = "None", reaction = false },
	{ id = "Shove", name = "Empujón", rarity = "Common", target = "Player", reaction = false },
	{ id = "Fine", name = "Multa", rarity = "Common", target = "Player", reaction = false },
	{ id = "Bribe", name = "Soborno", rarity = "Common", target = "None", reaction = false },
	{ id = "Spy", name = "Espía", rarity = "Common", target = "Player", reaction = false },
}

type PositionCase = { players: number, ranks: { number } }

-- Peso base de legendaria que corresponde a cada puesto en una partida del tamaño indicado.
-- Con todos los jugadores igualados, la clasificación sigue el orden de state.players.
local POSITIONS: { PositionCase } = {
	{ players = 2, ranks = { 2, 15 } },
	{ players = 4, ranks = { 2, 5, 15, 15 } },
	{ players = 5, ranks = { 2, 5, 5, 15, 15 } },
	{ players = 8, ranks = { 2, 5, 5, 5, 15, 15, 15, 15 } },
}

local function expectClose(actual: number, expected: number)
	if math.abs(actual - expected) > TOLERANCE then
		error(`se esperaba {expected} ± {TOLERANCE}, se obtuvo {actual}`, 2)
	end
end

local function cardOf(cardId: string): Cards.CardDef
	local card = Cards.byId[cardId]
	if not card then
		error(`el mazo devolvió la carta desconocida {cardId}`, 2)
	end
	return card
end

-- Primera carta de un robo; todas las funciones del mazo devuelven un único evento.
local function drawnCard(state: Types.GameState, playerId: Types.PlayerId, minRarity: Types.Rarity?): string
	local events = Deck.draw(state, playerId, minRarity)
	expect(#events).toBe(1)
	return events[1].cardId
end

describe("Cards", function()
	it("tiene 20 cartas: 5 legendarias, 6 raras y 9 comunes", function()
		local legendary, rare, common = 0, 0, 0
		for _, card in Cards.all do
			if card.rarity == "Legendary" then
				legendary += 1
			elseif card.rarity == "Rare" then
				rare += 1
			else
				common += 1
			end
		end
		expect(#Cards.all).toBe(20)
		expect(legendary).toBe(5)
		expect(rare).toBe(6)
		expect(common).toBe(9)
	end)

	it("respeta los ids, nombres y rarezas de la ficha", function()
		expect(#Cards.all).toBe(#EXPECTED)
		for index, expected in EXPECTED do
			local card = Cards.all[index]
			expect(card.id).toBe(expected.id)
			expect(card.name).toBe(expected.name)
			expect(card.rarity).toBe(expected.rarity)
		end
	end)

	it("define objetivo, reacción y exclusiva del líder como la ficha", function()
		for _, expected in EXPECTED do
			local card = cardOf(expected.id)
			expect(card.target).toBe(expected.target)
			expect(card.reaction).toBe(expected.reaction)
			expect(card.leaderOnly == true).toBe(expected.leaderOnly == true)
		end
	end)
end)

describe("Deck.weights", function()
	it("sube la probabilidad de legendaria con las rondas sin ninguna", function()
		local s = Fixtures.game({ players = 4 })
		local id = s.players[1].id
		s.round = 10
		s.lastLegendaryRound = 10
		local justAfter = Deck.weights(s, id).Legendary
		expect(justAfter > 0).toBeTruthy()
		s.lastLegendaryRound = 7
		local baseWeight = Deck.weights(s, id).Legendary
		expect(baseWeight).toBe(justAfter * 10)
		s.lastLegendaryRound = 3
		expect(Deck.weights(s, id).Legendary).toBe(baseWeight * 3)
		s.lastLegendaryRound = 1
		expect(Deck.weights(s, id).Legendary).toBe(baseWeight * 3)
	end)

	it("sigue la tabla de multiplicadores de la arquitectura", function()
		local s = Fixtures.game({ players = 4 })
		local id = s.players[1].id
		s.round = 30
		for rounds = 0, 8 do
			s.lastLegendaryRound = s.round - rounds
			local multiplier = MULTIPLIERS[math.min(rounds, #MULTIPLIERS - 1) + 1]
			expectClose(Deck.weights(s, id).Legendary, 2 * multiplier)
		end
	end)

	it("deja la rara intacta y completa con la común hasta 100", function()
		local s = Fixtures.game({ players = 4 })
		local id = s.players[1].id
		s.round = 12
		for rounds = 0, 8 do
			s.lastLegendaryRound = s.round - rounds
			local multiplier = MULTIPLIERS[math.min(rounds, #MULTIPLIERS - 1) + 1]
			local weights = Deck.weights(s, id)
			expectClose(weights.Rare, 23)
			expectClose(weights.Common, 100 - 23 - 2 * multiplier)
			expectClose(weights.Common + weights.Rare + weights.Legendary, 100)
		end
	end)

	it("suma 100 en todas las posiciones y multiplicadores", function()
		for players = 2, 8 do
			local s = Fixtures.game({ players = players })
			s.round = 20
			for rank = 1, players do
				for rounds = 0, 8 do
					s.lastLegendaryRound = s.round - rounds
					local weights = Deck.weights(s, s.players[rank].id)
					expectClose(weights.Common + weights.Rare + weights.Legendary, 100)
					expect(weights.Common > 0).toBeTruthy()
					expect(weights.Rare > 0).toBeTruthy()
					expect(weights.Legendary > 0).toBeTruthy()
				end
			end
		end
	end)

	it("elige el peso base según la posición en la clasificación", function()
		for _, case in POSITIONS do
			local s = Fixtures.game({ players = case.players })
			s.round = 5
			s.lastLegendaryRound = 5
			for rank, base in case.ranks do
				expectClose(Deck.weights(s, s.players[rank].id).Legendary, base * MULTIPLIERS[1])
			end
		end
	end)

	it("rechaza un jugador que no está en la partida", function()
		local s = Fixtures.game({ players = 2 })
		expect(function()
			Deck.weights(s, "P9")
		end).toThrow()
	end)
end)

describe("Deck.draw", function()
	it("roba una carta, la guarda en la mano y cuenta el robo", function()
		local s = Fixtures.game({ players = 2 })
		local player = s.players[1]
		local events = Deck.draw(s, player.id)
		expect(#events).toBe(1)
		local event = events[1]
		expect(event.type).toBe("CardDrawn")
		expect(event.playerId).toBe(player.id)
		local card = cardOf(event.cardId)
		expect(#player.hand).toBe(1)
		expect(player.hand[1]).toBe(card.id)
		expect(s.stats[player.id].cardsDrawn).toBe(1)
	end)

	it("descarta la carta cuando la mano está llena", function()
		local s = Fixtures.game({ players = 2 })
		local player = s.players[1]
		for _, cardId in { "Shield", "ExtraDie", "Reverse" } do
			Fixtures.hand(s, player.id, cardId)
		end
		expect(#player.hand).toBe(Economy.handLimit)
		local events = Deck.draw(s, player.id)
		expect(#events).toBe(1)
		expect(events[1].type).toBe("CardDiscarded")
		expect(events[1].playerId).toBe(player.id)
		cardOf(events[1].cardId)
		expect(player.hand).toEqual({ "Shield", "ExtraDie", "Reverse" })
		expect(s.stats[player.id].cardsDrawn).toBe(1)
	end)

	it("actualiza lastLegendaryRound al robar una legendaria", function()
		local s = Fixtures.game({ players = 2 })
		local id = s.players[1].id
		s.round = 8
		expect(cardOf(drawnCard(s, id, "Legendary")).rarity).toBe("Legendary")
		expect(s.lastLegendaryRound).toBe(8)
		-- Justo después de otra la probabilidad baja, pero nunca llega a cero.
		expect(Deck.weights(s, id).Legendary > 0).toBeTruthy()
		s.round = 9
		expect(cardOf(drawnCard(s, id, "Legendary")).rarity).toBe("Legendary")
		expect(s.lastLegendaryRound).toBe(9)
	end)

	it("solo marca la ronda cuando la carta robada es legendaria", function()
		local s = Fixtures.game({ players = 4, seed = 12 })
		local id = s.players[1].id
		s.round = 4
		for _ = 1, 200 do
			s.lastLegendaryRound = nil
			local card = cardOf(drawnCard(s, id))
			if card.rarity == "Legendary" then
				expect(s.lastLegendaryRound).toBe(4)
			else
				expect(s.lastLegendaryRound).toBe(nil)
			end
		end
	end)

	it("respeta la rareza mínima", function()
		local s = Fixtures.game({ players = 4 })
		local id = s.players[3].id
		local rare, legendary = 0, 0
		for _ = 1, 300 do
			local card = cardOf(drawnCard(s, id, "Rare"))
			expect(card.rarity ~= "Common").toBeTruthy()
			if card.rarity == "Legendary" then
				legendary += 1
			else
				rare += 1
			end
		end
		-- La rara mínima deja pasar también a la legendaria, así que salen las dos.
		expect(rare > 0).toBeTruthy()
		expect(legendary > 0).toBeTruthy()
		for _ = 1, 100 do
			expect(cardOf(drawnCard(s, id, "Legendary")).rarity).toBe("Legendary")
		end
	end)

	it("reparte las cartas de una rareza por igual", function()
		local s = Fixtures.game({ players = 2 })
		local id = s.players[1].id
		local seen: { [string]: boolean } = {}
		for _ = 1, 200 do
			seen[cardOf(drawnCard(s, id, "Legendary")).id] = true
		end
		local distinct = 0
		for _ in seen do
			distinct += 1
		end
		expect(distinct).toBe(5)
	end)

	it("favorece a quien va peor", function()
		local leaderState = Fixtures.game({ players = 4, seed = 7 })
		local lowerState = Fixtures.game({ players = 4, seed = 7 })
		local leaderId = leaderState.players[1].id
		local lowerId = lowerState.players[4].id
		local leaderLegendaries = 0
		local lowerLegendaries = 0
		for i = 1, 5000 do
			-- La ronda avanza para que el multiplicador recorra toda la tabla.
			leaderState.round = i
			lowerState.round = i
			if cardOf(drawnCard(leaderState, leaderId)).rarity == "Legendary" then
				leaderLegendaries += 1
			end
			if cardOf(drawnCard(lowerState, lowerId)).rarity == "Legendary" then
				lowerLegendaries += 1
			end
		end
		expect(lowerLegendaries > leaderLegendaries).toBeTruthy()
	end)

	it("rechaza una rareza mínima desconocida", function()
		local s = Fixtures.game({ players = 2 })
		expect(function()
			Deck.draw(s, s.players[1].id, "Mythic" :: any)
		end).toThrow()
	end)

	it("rechaza un jugador que no está en la partida", function()
		local s = Fixtures.game({ players = 2 })
		expect(function()
			Deck.draw(s, "P9")
		end).toThrow()
	end)
end)

describe("Economy", function()
	it("ya no guarda el cooldown de legendarias", function()
		local economy: any = Economy
		expect(economy.legendaryCooldownRounds).toBe(nil)
	end)
end)

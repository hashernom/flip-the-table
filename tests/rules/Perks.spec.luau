--!strict
-- Perks: catálogo, borrador de la fase PerkDraft y los efectos de la fase 03 que ya tienen
-- sistema. Cada momento reparte un perk por jugador en orden de turno; el reloj asigna el
-- primero de la oferta. Abogado, Afortunado, Negociador y Alma en Pena los cablean las tareas
-- que traen su sistema (R-P6): aquí solo están sus definiciones.
local Harness = require("../harness")
local Bot = require("../../src/shared/rules/Bot")
local Building = require("../../src/shared/rules/Building")
local Deck = require("../../src/shared/rules/Deck")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Movement = require("../../src/shared/rules/Movement")
local Perks = require("../../src/shared/rules/Perks")
local PerksConfig = require("../../src/shared/config/Perks")
local Property = require("../../src/shared/rules/Property")
local Rng = require("../../src/shared/rules/Rng")
local State = require("../../src/shared/rules/State")
local Types = require("../../src/shared/rules/Types")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

type GameState = Types.GameState
type Player = Types.Player
type PlayerId = Types.PlayerId

-- Tabla «Perks» de la ficha, en el mismo orden que el catálogo.
local EXPECTED: { { id: string, name: string } } = {
	{ id = "Banker", name = "Banquero" },
	{ id = "Landlord", name = "Casero" },
	{ id = "Builder", name = "Constructor" },
	{ id = "Smuggler", name = "Contrabandista" },
	{ id = "QuickFingers", name = "Dedos Rápidos" },
	{ id = "Lawyer", name = "Abogado" },
	{ id = "Negotiator", name = "Negociador" },
	{ id = "Lucky", name = "Afortunado" },
	{ id = "Hunter", name = "Cazador" },
	{ id = "Armored", name = "Blindado" },
	{ id = "Collector", name = "Coleccionista" },
	{ id = "RestlessSoul", name = "Alma en Pena" },
}

-- Rondas de la tabla «Momentos de la partida» de la arquitectura: 2.º y 3.er perk.
type MomentCase = { players: number, rounds: number, moments: { number } }

local MOMENTS: { MomentCase } = {
	{ players = 2, rounds = 20, moments = { 7, 14 } },
	{ players = 4, rounds = 20, moments = { 7, 14 } },
	{ players = 5, rounds = 15, moments = { 6, 11 } },
	{ players = 6, rounds = 15, moments = { 6, 11 } },
	{ players = 7, rounds = 12, moments = { 5, 9 } },
	{ players = 8, rounds = 12, moments = { 5, 9 } },
}

local function inTurn(state: GameState): Player
	return state.players[state.turnIndex]
end

-- pending es la tabla persistente que State.create siempre crea (R1).
local function pendingOf(state: GameState): any
	local pending = state.pending
	if not pending then
		error("el estado no tiene pending", 2)
	end
	return pending
end

-- Borrador en curso (`{ order, index, offer }`), o nil.
local function draftOf(state: GameState): any
	return pendingOf(state).draft
end

local function playerOf(state: GameState, playerId: PlayerId): Player
	for _, player in state.players do
		if player.id == playerId then
			return player
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

-- Primera propiedad cuya renta sube con el perk Casero: los precios bajos se comen el 15 % en
-- el redondeo hacia abajo y no servirían para comprobar el efecto.
local function landlordIndex(state: GameState): number
	local rate = 1 + Economy.perks.landlordRentRate
	for _, square in state.board.squares do
		if square.kind == "Property" and square.price then
			local base = math.floor(square.price * Economy.baseRentRate)
			local boosted = math.floor(square.price * Economy.baseRentRate * rate)
			if boosted > base then
				return square.index
			end
		end
	end
	error("el tablero no tiene una propiedad cuya renta suba con Casero", 2)
end

-- Todos los perks del catálogo dentro de la mano del jugador.
local function giveAllPerks(player: Player)
	local perks: { string } = {}
	for _, perk in PerksConfig.all do
		table.insert(perks, perk.id)
	end
	player.perks = perks
end

-- Elige el primer perk ofrecido hasta cerrar el borrador. Devuelve los ids en el orden en que
-- eligieron y falla si la fase no vuelve a AwaitRoll (nunca debe quedarse colgada).
local function draftAll(state: GameState): { PlayerId }
	local order: { PlayerId } = {}
	local guard = 0
	while state.phase == "PerkDraft" do
		guard += 1
		if guard > #state.players + 1 then
			error("el borrador de perks no termina", 2)
		end
		local draft = draftOf(state)
		if not draft then
			error("la fase PerkDraft no tiene pending.draft", 2)
		end
		local drafterId = draft.order[draft.index]
		local result = Engine.apply(state, drafterId, { type = "DraftPerk", perkId = draft.offer[1] })
		if not result.ok then
			error(result.error, 2)
		end
		table.insert(order, drafterId)
	end
	return order
end

-- Abre el draft del momento entrando en la ronda por la vía real: el último jugador del orden
-- cierra el turno anterior. Devuelve la ronda en la que se entra.
local function enterMoment(state: GameState, round: number): number
	local last = state.players[#state.players]
	Fixtures.turnOf(state, last.id)
	state.round = round - 1
	state.phase = "AwaitEnd"
	local result = Engine.apply(state, last.id, { type = "EndTurn" })
	if not result.ok then
		error(result.error, 2)
	end
	return state.round
end

-- Juega una carta de la mano por la vía del motor y devuelve sus eventos.
local function playCard(
	state: GameState,
	playerId: PlayerId,
	cardId: string,
	targetId: PlayerId?
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

describe("config/Perks", function()
	it("define los 12 perks de la ficha con sus ids y nombres", function()
		expect(#PerksConfig.all).toBe(12)
		expect(#EXPECTED).toBe(12)
		for index, expected in EXPECTED do
			local perk = PerksConfig.all[index]
			expect(perk.id).toBe(expected.id)
			expect(perk.name).toBe(expected.name)
			expect(#perk.description > 0).toBe(true)
		end
	end)

	it("indexa el catálogo por id sin repetir ninguno", function()
		local seen: { [string]: boolean } = {}
		for _, perk in PerksConfig.all do
			expect(seen[perk.id]).toBe(nil)
			seen[perk.id] = true
			expect(PerksConfig.byId[perk.id]).toBe(perk)
		end
		local count = 0
		for _ in seen do
			count += 1
		end
		expect(count).toBe(12)
	end)
end)

describe("Perks.has", function()
	it("reconoce solo los perks que el jugador tiene", function()
		local s = Fixtures.game({ players = 2 })
		local player = s.players[1]
		expect(Perks.has(player, "Banker")).toBe(false)
		table.insert(player.perks, "Banker")
		expect(Perks.has(player, "Banker")).toBe(true)
		expect(Perks.has(player, "Landlord")).toBe(false)
	end)
end)

describe("Perks.offer", function()
	it("ofrece 3 perks distintos que el jugador no tiene", function()
		local s = Fixtures.game({ players = 2 })
		local player = s.players[1]
		table.insert(player.perks, "Banker")
		table.insert(player.perks, "Landlord")

		local offer = Perks.offer(s, player.id)
		expect(#offer).toBe(Economy.perks.offerCount)
		local seen: { [string]: boolean } = {}
		for _, perkId in offer do
			expect(seen[perkId]).toBe(nil)
			seen[perkId] = true
			expect(Perks.has(player, perkId)).toBe(false)
			expect(PerksConfig.byId[perkId] ~= nil).toBe(true)
		end
	end)

	it("es determinista con el mismo estado", function()
		local first = Fixtures.game({ players = 3, seed = 11 })
		local second = Fixtures.game({ players = 3, seed = 11 })
		table.insert(first.players[1].perks, "Builder")
		table.insert(second.players[1].perks, "Builder")
		expect(Perks.offer(first, first.players[1].id)).toEqual(Perks.offer(second, second.players[1].id))
	end)

	it("sale del generador: semillas distintas dan ofertas distintas", function()
		local first: string? = nil
		local different = false
		for seed = 1, 8 do
			local s = Fixtures.game({ players = 3, seed = seed })
			local offer = table.concat(Perks.offer(s, s.players[1].id), ",")
			if not first then
				first = offer
			elseif offer ~= first then
				different = true
			end
		end
		expect(different).toBe(true)
	end)

	it("ofrece lo que queda cuando le faltan menos de 3", function()
		local s = Fixtures.game({ players = 2 })
		local player = s.players[1]
		for index = 1, 10 do
			table.insert(player.perks, PerksConfig.all[index].id)
		end
		local offer = Perks.offer(s, player.id)
		expect(#offer).toBe(2)
		local expected: { string } = { PerksConfig.all[11].id, PerksConfig.all[12].id }
		table.sort(offer)
		table.sort(expected)
		expect(offer).toEqual(expected)
	end)

	it("no ofrece nada al jugador que ya tiene los 12", function()
		local s = Fixtures.game({ players = 2 })
		giveAllPerks(s.players[1])
		expect(Perks.offer(s, s.players[1].id)).toEqual({})
	end)
end)

describe("momento del draft", function()
	it("abre el draft al empezar la partida y lo cierra en AwaitRoll con un perk por jugador", function()
		-- R-P31: la creación real deja la partida en el borrador, sin depender del servidor.
		local s = State.create({ playerIds = { "P1", "P2", "P3" }, seed = 9 })
		expect(s.phase).toBe("PerkDraft")

		local draft = draftOf(s)
		expect(draft ~= nil).toBe(true)
		expect(draft.index).toBe(1)
		expect(draft.order).toEqual({ s.players[1].id, s.players[2].id, s.players[3].id })
		expect(#draft.offer).toBe(Economy.perks.offerCount)
		expect(pendingOf(s).draftRound).toBe(1)

		expect(draftAll(s)).toEqual({ s.players[1].id, s.players[2].id, s.players[3].id })
		expect(s.phase).toBe("AwaitRoll")
		expect(draftOf(s)).toBe(nil)
		for _, player in s.players do
			expect(#player.perks).toBe(1)
		end

		-- Cada momento se abre una sola vez.
		expect(Perks.begin(s)).toBe(false)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("sigue la tabla de la arquitectura en los tres tamaños", function()
		for _, case in MOMENTS do
			local s = Fixtures.game({ players = case.players })
			expect(s.maxRounds).toBe(case.rounds)
			expect(Perks.momentRound(s, 1)).toBe(1)
			expect(Perks.momentRound(s, 2)).toBe(case.moments[1])
			expect(Perks.momentRound(s, 3)).toBe(case.moments[2])
		end
	end)

	it("abre el draft en las rondas de la tabla al cerrar el turno anterior", function()
		local cases: { { players: number, moments: { number } } } = {
			{ players = 4, moments = { 7, 14 } },
			{ players = 6, moments = { 6, 11 } },
			{ players = 7, moments = { 5, 9 } },
		}
		for _, case in cases do
			local s = Fixtures.game({ players = case.players })
			for moment, round in case.moments do
				expect(enterMoment(s, round)).toBe(round)
				-- R-P28: cerrar el turno que abre el momento no pisa la fase del borrador.
				expect(s.phase).toBe("PerkDraft")
				local drafted = draftAll(s)
				expect(#drafted).toBe(case.players)
				expect(s.phase).toBe("AwaitRoll")
				for _, player in s.players do
					expect(#player.perks).toBe(moment)
				end
			end
		end
	end)

	it("en Sin Fin abre en las rondas 6 y 12", function()
		local s = Fixtures.game({ players = 4, endMode = "Endless" })
		expect(s.maxRounds).toBe(nil)
		expect(Perks.momentRound(s, 2)).toBe(6)
		expect(Perks.momentRound(s, 3)).toBe(12)

		for moment, round in { 6, 12 } do
			expect(enterMoment(s, round)).toBe(round)
			expect(s.phase).toBe("PerkDraft")
			draftAll(s)
			expect(s.phase).toBe("AwaitRoll")
			for _, player in s.players do
				expect(#player.perks).toBe(moment)
			end
		end
	end)

	it("no abre draft en una ronda que no es de la tabla", function()
		local s = Fixtures.game({ players = 4 })
		expect(enterMoment(s, 3)).toBe(3)
		expect(s.phase).toBe("AwaitRoll")
		expect(draftOf(s)).toBe(nil)
		for _, player in s.players do
			expect(player.perks).toEqual({})
		end
	end)

	it("no abre draft para quien no tiene perks disponibles", function()
		local s = Fixtures.game({ players = 3 })
		for _, player in s.players do
			giveAllPerks(player)
		end
		expect(Perks.begin(s)).toBe(false)
		expect(s.phase).toBe("AwaitRoll")
		expect(draftOf(s)).toBe(nil)

		-- Quien ya tiene los 12 queda fuera del orden; el resto sigue eligiendo.
		local t = Fixtures.game({ players = 3 })
		giveAllPerks(t.players[2])
		expect(Perks.begin(t)).toBe(true)
		expect(draftOf(t).order).toEqual({ t.players[1].id, t.players[3].id })
	end)
end)

describe("Perks.draft", function()
	it("añade el perk al jugador y emite PerkDrafted", function()
		local s = Fixtures.game({ players = 3 })
		Perks.begin(s)
		local draft = draftOf(s)
		local drafterId = draft.order[draft.index]
		local perkId = draft.offer[2]

		local result = Engine.apply(s, drafterId, { type = "DraftPerk", perkId = perkId })
		if not result.ok then
			error(result.error, 2)
		end
		expect(result.events).toEqual({ { type = "PerkDrafted", playerId = drafterId, perkId = perkId } })
		expect(playerOf(s, drafterId).perks).toEqual({ perkId })
		expect(Perks.has(playerOf(s, drafterId), perkId)).toBe(true)

		-- El siguiente del orden recibe su propia oferta.
		local nextDraft = draftOf(s)
		expect(nextDraft.index).toBe(2)
		expect(nextDraft.order[nextDraft.index] ~= drafterId).toBe(true)
		expect(#nextDraft.offer).toBe(Economy.perks.offerCount)
	end)

	it("rechaza elegir fuera de tu turno sin cambiar nada", function()
		local s = Fixtures.game({ players = 3 })
		Perks.begin(s)
		local draft = draftOf(s)
		local otherId = draft.order[2]
		local before = deepCopy(s)

		expect(rejected(Engine.apply(s, otherId, { type = "DraftPerk", perkId = draft.offer[1] }))).toBe(
			"No es tu turno de elegir perk"
		)
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza un perk que no está en la oferta", function()
		local s = Fixtures.game({ players = 3 })
		Perks.begin(s)
		local draft = draftOf(s)
		local outside: string? = nil
		for _, perk in PerksConfig.all do
			if not table.find(draft.offer, perk.id) then
				outside = perk.id
				break
			end
		end
		if not outside then
			error("la oferta no dejó ningún perk fuera", 2)
		end
		local before = deepCopy(s)

		expect(rejected(Engine.apply(s, draft.order[draft.index], { type = "DraftPerk", perkId = outside }))).toBe(
			`El perk {outside} no está en la oferta`
		)
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza elegir sin borrador abierto", function()
		local s = Fixtures.game({ players = 2 })
		local actor = inTurn(s)
		expect(rejected(Perks.draft(s, actor.id, "Banker"))).toBe("El borrador de perks no está abierto")
		expect(rejected(Engine.apply(s, actor.id, { type = "DraftPerk", perkId = "Banker" }))).toBe(
			"No se puede DraftPerk en la fase AwaitRoll"
		)
		expect(actor.perks).toEqual({})
	end)

	it("cierra el borrador y vuelve a AwaitRoll tras la última elección", function()
		local s = Fixtures.game({ players = 3 })
		Perks.begin(s)
		draftAll(s)
		expect(s.phase).toBe("AwaitRoll")
		expect(draftOf(s)).toBe(nil)
		expect(pendingOf(s).draftRound).toBe(1)
		for _, player in s.players do
			expect(#player.perks).toBe(1)
		end
	end)
end)

describe("Engine en PerkDraft", function()
	it("legalActions ofrece exactamente los DraftPerk que apply acepta", function()
		local s = Fixtures.game({ players = 3 })
		Perks.begin(s)
		local draft = draftOf(s)
		local drafterId = draft.order[draft.index]
		local expected: { Types.Action } = {}
		for _, perkId in draft.offer do
			table.insert(expected, { type = "DraftPerk", perkId = perkId })
		end

		local actions = Engine.legalActions(s, drafterId)
		expect(actions).toEqual(expected)
		for _, action in actions do
			local copy = deepCopy(s)
			expect(Engine.apply(copy, drafterId, action).ok).toBe(true)
		end
		-- Solo el jugador al que le toca elige.
		expect(Engine.legalActions(s, draft.order[2])).toEqual({})
	end)

	it("el bot elige el primer perk de la oferta", function()
		local s = Fixtures.game({ players = 3 })
		Perks.begin(s)
		local draft = draftOf(s)
		local drafterId = draft.order[draft.index]
		expect(Bot.choose(s, drafterId)).toEqual({ type = "DraftPerk", perkId = draft.offer[1] })
		expect(Bot.choose(s, draft.order[2])).toBe(nil)
	end)

	it("el tiempo agotado asigna el primer perk ofrecido", function()
		local s = Fixtures.game({ players = 3 })
		Perks.begin(s)
		local draft = draftOf(s)
		local drafterId = draft.order[draft.index]
		local perkId = draft.offer[1]

		local events = Engine.timeout(s)
		expect(events).toEqual({ { type = "PerkDrafted", playerId = drafterId, perkId = perkId } })
		expect(playerOf(s, drafterId).perks).toEqual({ perkId })
		expect(s.phase).toBe("PerkDraft")
		expect(draftOf(s).index).toBe(2)

		-- El reloj cierra el resto del borrador y devuelve la fase.
		local guard = 0
		while s.phase == "PerkDraft" do
			guard += 1
			if guard > #s.players + 1 then
				error("el reloj no cierra el borrador de perks", 2)
			end
			Engine.timeout(s)
		end
		expect(s.phase).toBe("AwaitRoll")
		for _, player in s.players do
			expect(#player.perks).toBe(1)
		end
	end)
end)

describe("Banquero", function()
	it("cobra la Salida un 50 % más", function()
		local s = Fixtures.game({ players = 2 })
		local player = s.players[1]
		local bonus = math.floor(Economy.startBonus * (1 + Economy.perks.bankerStartRate))
		table.insert(player.perks, "Banker")
		Fixtures.placeOn(s, player.id, #s.board.squares)

		local events = Movement.advance(s, player.id, 1)
		expect(player.position).toBe(1)
		expect(player.cash).toBe(Economy.startingCash + bonus)
		expect(events[#events]).toEqual({ type = "PassedStart", playerId = player.id, amount = bonus })
	end)

	it("sin el perk la Salida paga lo de siempre", function()
		local s = Fixtures.game({ players = 2 })
		local player = s.players[1]
		Fixtures.placeOn(s, player.id, #s.board.squares)
		local events = Movement.advance(s, player.id, 1)
		expect(player.cash).toBe(Economy.startingCash + Economy.startBonus)
		expect(events[#events].amount).toBe(Economy.startBonus)
	end)
end)

describe("Casero", function()
	it("sube un 15 % las rentas propias", function()
		local s = Fixtures.game({ players = 2 })
		local owner = s.players[1]
		local index = landlordIndex(s)
		Fixtures.give(s, owner.id, index)
		local price = s.board.squares[index].price :: number
		local base = math.floor(price * Economy.baseRentRate)
		expect(Property.rentFor(s, index)).toBe(base)

		table.insert(owner.perks, "Landlord")
		local boosted = math.floor(price * Economy.baseRentRate * (1 + Economy.perks.landlordRentRate))
		expect(boosted > base).toBe(true)
		expect(Property.rentFor(s, index)).toBe(boosted)
	end)

	it("no toca la renta de una casilla sin dueño", function()
		local s = Fixtures.game({ players = 2 })
		local index = landlordIndex(s)
		local price = s.board.squares[index].price :: number
		table.insert(s.players[1].perks, "Landlord")
		expect(Property.rentFor(s, index)).toBe(math.floor(price * Economy.baseRentRate))
	end)
end)

describe("Constructor", function()
	it("construir cuesta un 20 % menos", function()
		local s = Fixtures.game({ players = 2 })
		local player = s.players[1]
		local index = Fixtures.squareOf(s, "Property")
		local price = s.board.squares[index].price :: number
		local base = Building.costOf(s, player.id, index)
		expect(base).toBe(math.floor(price * Economy.buildingCostRate))

		table.insert(player.perks, "Builder")
		local cheaper = Building.costOf(s, player.id, index)
		expect(cheaper < base).toBe(true)
		expect(cheaper).toBe(math.floor(base * (1 - Economy.perks.builderCostRate)))

		-- La construcción cobra el importe con descuento, no el de siempre.
		local zoneId = s.board.squares[index].zoneId :: string
		for _, member in s.board.zones[zoneId] do
			Fixtures.give(s, player.id, member)
		end
		player.cash = cheaper
		local result = Building.build(s, player.id, index)
		if not result.ok then
			error(result.error, 2)
		end
		expect(player.cash).toBe(0)
		expect(s.properties[index].level).toBe(1)
	end)
end)

describe("Contrabandista", function()
	it("sube la mano a 4 cartas", function()
		local s = Fixtures.game({ players = 2 })
		local player = s.players[1]
		table.insert(player.perks, "Smuggler")
		for _, cardId in { "Shield", "ExtraDie", "Reverse" } do
			Fixtures.hand(s, player.id, cardId)
		end

		local fourth = Deck.draw(s, player.id)
		expect(fourth[1].type).toBe("CardDrawn")
		expect(#player.hand).toBe(Economy.smugglerHandLimit)

		local fifth = Deck.draw(s, player.id)
		expect(fifth[1].type).toBe("CardDiscarded")
		expect(#player.hand).toBe(Economy.smugglerHandLimit)
	end)
end)

describe("Dedos Rápidos", function()
	it("la primera tirada no mueve y retiene los dados", function()
		local s = Fixtures.game({ players = 2 })
		local player = inTurn(s)
		table.insert(player.perks, "QuickFingers")
		Fixtures.dice(s, 3, 4)

		local result = Engine.apply(s, player.id, { type = "Roll" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(result.events).toEqual({ { type = "DiceRolled", playerId = player.id, a = 3, b = 4 } })
		expect(player.position).toBe(1)
		expect(pendingOf(s).heldRoll).toEqual({ a = 3, b = 4 })
		expect(pendingOf(s).rolled).toEqual({ a = 3, b = 4 })
		expect(s.phase).toBe("AwaitRoll")
		-- Con los dados retenidos, el motor ofrece repetir uno y volver a tirar.
		local expectedActions: { Types.Action } = {
			{ type = "Roll" },
			{ type = "RerollDie", die = "a" },
			{ type = "RerollDie", die = "b" },
		}
		expect(Engine.legalActions(s, player.id)).toEqual(expectedActions)
	end)

	it("RerollDie repite un dado una vez por ronda", function()
		local s = Fixtures.game({ players = 2 })
		local player = inTurn(s)
		table.insert(player.perks, "QuickFingers")
		Fixtures.dice(s, 3, 4)
		Engine.apply(s, player.id, { type = "Roll" })

		Rng.force(s.rng, { 6 })
		local result = Engine.apply(s, player.id, { type = "RerollDie", die = "a" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(result.events).toEqual({ { type = "DiceRolled", playerId = player.id, a = 6, b = 4 } })
		expect(pendingOf(s).heldRoll).toEqual({ a = 6, b = 4 })
		expect(pendingOf(s).rerollUsed[player.id]).toBe(1)
		-- La tirada del turno queda al día para la vista.
		expect(pendingOf(s).rolled).toEqual({ a = 6, b = 4 })
		expect(player.position).toBe(1)

		expect(rejected(Engine.apply(s, player.id, { type = "RerollDie", die = "b" }))).toBe(
			"Ya has repetido un dado esta ronda"
		)
		expect(pendingOf(s).heldRoll).toEqual({ a = 6, b = 4 })
	end)

	it("marca el reroll por jugador: dos con el perk repiten en la misma ronda", function()
		local s = Fixtures.game({ players = 2 })
		local first = inTurn(s)
		local second = s.players[s.turnIndex % #s.players + 1]
		table.insert(first.perks, "QuickFingers")
		table.insert(second.perks, "QuickFingers")

		-- Primer jugador: turno completo con su repetición.
		Fixtures.dice(s, 3, 4)
		Engine.apply(s, first.id, { type = "Roll" })
		Rng.force(s.rng, { 6 })
		local firstReroll = Engine.apply(s, first.id, { type = "RerollDie", die = "a" })
		if not firstReroll.ok then
			error(firstReroll.error, 2)
		end
		expect(pendingOf(s).rerollUsed[first.id]).toBe(1)
		Engine.apply(s, first.id, { type = "Roll" })
		local ended = Engine.apply(s, first.id, { type = "EndTurn" })
		if not ended.ok then
			error(ended.error, 2)
		end
		expect(s.round).toBe(1)

		-- Segundo jugador: la marca del primero no le quita la repetición.
		expect(inTurn(s).id).toBe(second.id)
		Fixtures.dice(s, 2, 5)
		local held = Engine.apply(s, second.id, { type = "Roll" })
		if not held.ok then
			error(held.error, 2)
		end
		expect(pendingOf(s).heldRoll).toEqual({ a = 2, b = 5 })
		Rng.force(s.rng, { 1 })
		local secondReroll = Engine.apply(s, second.id, { type = "RerollDie", die = "b" })
		if not secondReroll.ok then
			error(secondReroll.error, 2)
		end
		expect(pendingOf(s).heldRoll).toEqual({ a = 2, b = 1 })
		expect(pendingOf(s).rerollUsed[first.id]).toBe(1)
		expect(pendingOf(s).rerollUsed[second.id]).toBe(1)

		-- Y el segundo tampoco repite dos veces en la misma ronda.
		expect(rejected(Engine.apply(s, second.id, { type = "RerollDie", die = "a" }))).toBe(
			"Ya has repetido un dado esta ronda"
		)
	end)

	it("la segunda tirada mueve con los dados retenidos", function()
		local s = Fixtures.game({ players = 2 })
		local player = inTurn(s)
		table.insert(player.perks, "QuickFingers")
		Fixtures.dice(s, 3, 4)
		Engine.apply(s, player.id, { type = "Roll" })
		Rng.force(s.rng, { 6 })
		Engine.apply(s, player.id, { type = "RerollDie", die = "a" })

		local result = Engine.apply(s, player.id, { type = "Roll" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(player.position).toBe(11)
		expect(pendingOf(s).heldRoll).toBe(nil)
		expect(pendingOf(s).rolled).toEqual({ a = 6, b = 4 })
		-- Los dados ya se anunciaron al retenerlos: la tirada que mueve no los repite.
		expect(result.events[1].type).toBe("TokenMoved")
	end)

	it("vuelve a poder repetir en la ronda siguiente", function()
		local s = Fixtures.game({ players = 2 })
		local player = inTurn(s)
		table.insert(player.perks, "QuickFingers")
		Fixtures.dice(s, 3, 4)
		Engine.apply(s, player.id, { type = "Roll" })
		Rng.force(s.rng, { 6 })
		Engine.apply(s, player.id, { type = "RerollDie", die = "a" })
		Engine.apply(s, player.id, { type = "Roll" })

		-- Nueva ronda: el dado repetido vuelve a estar disponible.
		s.round = 2
		s.phase = "AwaitRoll"
		Fixtures.dice(s, 2, 2)
		local held = Engine.apply(s, player.id, { type = "Roll" })
		if not held.ok then
			error(held.error, 2)
		end
		expect(pendingOf(s).heldRoll).toEqual({ a = 2, b = 2 })

		Rng.force(s.rng, { 5 })
		local again = Engine.apply(s, player.id, { type = "RerollDie", die = "b" })
		if not again.ok then
			error(again.error, 2)
		end
		expect(pendingOf(s).heldRoll).toEqual({ a = 2, b = 5 })
		expect(pendingOf(s).rerollUsed[player.id]).toBe(2)
	end)

	it("sin el perk la tirada mueve de una vez", function()
		local s = Fixtures.game({ players = 2 })
		local player = inTurn(s)
		Fixtures.dice(s, 3, 4)
		expect(rejected(Engine.apply(s, player.id, { type = "RerollDie", die = "a" }))).toBe(
			"No hay dados retenidos que repetir"
		)
		local result = Engine.apply(s, player.id, { type = "Roll" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(player.position).toBe(8)
		expect(pendingOf(s).heldRoll).toBe(nil)
	end)

	it("el tiempo agotado mueve en un solo tick con el perk", function()
		local s = Fixtures.game({ players = 2 })
		local player = inTurn(s)
		table.insert(player.perks, "QuickFingers")
		Fixtures.dice(s, 3, 4)

		-- R-P34: el reloj no retiene los dados; la ficha se mueve en el primer tick.
		local events = Engine.timeout(s)
		expect(player.position).toBe(8)
		expect(pendingOf(s).heldRoll).toBe(nil)
		expect(pendingOf(s).rolled).toEqual({ a = 3, b = 4 })
		expect(events[1].type).toBe("DiceRolled")
		expect(events[2].type).toBe("TokenMoved")
		expect(s.phase).toBe("AwaitBuy")
	end)

	it("el tiempo agotado mueve con los dados retenidos", function()
		local s = Fixtures.game({ players = 2 })
		local player = inTurn(s)
		table.insert(player.perks, "QuickFingers")
		Fixtures.dice(s, 3, 4)
		Engine.apply(s, player.id, { type = "Roll" })
		expect(player.position).toBe(1)

		local events = Engine.timeout(s)
		expect(player.position).toBe(8)
		expect(pendingOf(s).heldRoll).toBe(nil)
		expect(pendingOf(s).rolled).toEqual({ a = 3, b = 4 })
		-- Los dados ya se anunciaron al retenerlos: la tirada del reloj solo mueve.
		expect(events[1].type).toBe("TokenMoved")
		expect(s.phase).toBe("AwaitBuy")
	end)
end)

describe("Cazador", function()
	it("multiplica por 1,5 la Multa al que lleva la Corona", function()
		local s = Fixtures.game({ players = 2 })
		local leader = s.players[1]
		local caster = s.players[2]
		Fixtures.turnOf(s, caster.id)
		table.insert(caster.perks, "Hunter")
		Fixtures.hand(s, caster.id, "Fine")

		playCard(s, caster.id, "Fine", leader.id)
		local damage = math.floor(Economy.cards.fine * Economy.perks.hunterDamageMultiplier)
		expect(damage).toBe(150)
		expect(leader.cash).toBe(Economy.startingCash - damage)
		expect(caster.cash).toBe(Economy.startingCash)
	end)

	it("no multiplica contra un rival que no lleva la Corona", function()
		local s = Fixtures.game({ players = 3 })
		local caster = s.players[1]
		local rival = s.players[2]
		expect(pendingOf(s).crownId).toBe(caster.id)
		table.insert(caster.perks, "Hunter")
		Fixtures.hand(s, caster.id, "Fine")

		playCard(s, caster.id, "Fine", rival.id)
		expect(rival.cash).toBe(Economy.startingCash - Economy.cards.fine)
	end)

	it("multiplica la Propina Forzada que paga el que lleva la Corona", function()
		local s = Fixtures.game({ players = 3 })
		local leader = s.players[1]
		local caster = s.players[2]
		local third = s.players[3]
		Fixtures.turnOf(s, caster.id)
		table.insert(caster.perks, "Hunter")
		Fixtures.hand(s, caster.id, "ForcedTip")

		playCard(s, caster.id, "ForcedTip")
		local boosted = math.floor(Economy.cards.forcedTip * Economy.perks.hunterDamageMultiplier)
		expect(leader.cash).toBe(Economy.startingCash - boosted)
		expect(third.cash).toBe(Economy.startingCash - Economy.cards.forcedTip)
		expect(caster.cash).toBe(Economy.startingCash + boosted + Economy.cards.forcedTip)
	end)

	it("multiplica el Golpe a la Corona contra el líder", function()
		local s = Fixtures.game({ players = 2 })
		local leader = s.players[1]
		local caster = s.players[2]
		Fixtures.turnOf(s, caster.id)
		table.insert(caster.perks, "Hunter")
		leader.cash = 1000
		Fixtures.hand(s, caster.id, "CrownStrike")

		playCard(s, caster.id, "CrownStrike", leader.id)
		local base = math.floor(1000 * Economy.cards.crownStrikeRate)
		local damage = math.floor(base * Economy.perks.hunterDamageMultiplier)
		expect(damage).toBe(375)
		expect(leader.cash).toBe(1000 - damage)
		expect(caster.cash).toBe(Economy.startingCash + damage)
	end)
end)

describe("Blindado", function()
	it("reduce a la mitad el primer daño por carta de la ronda", function()
		local s = Fixtures.game({ players = 2 })
		local caster = inTurn(s)
		local victim = s.players[2]
		table.insert(victim.perks, "Armored")
		local half = math.floor(Economy.cards.fine / 2)

		Fixtures.hand(s, caster.id, "Fine")
		playCard(s, caster.id, "Fine", victim.id)
		expect(victim.cash).toBe(Economy.startingCash - half)
		expect(victim.damageReducedRound).toBe(1)

		-- El segundo daño de la misma ronda llega completo.
		Fixtures.hand(s, caster.id, "Fine")
		playCard(s, caster.id, "Fine", victim.id)
		expect(victim.cash).toBe(Economy.startingCash - half - Economy.cards.fine)
	end)

	it("vuelve a proteger en la ronda siguiente", function()
		local s = Fixtures.game({ players = 2 })
		local caster = inTurn(s)
		local victim = s.players[2]
		table.insert(victim.perks, "Armored")
		local half = math.floor(Economy.cards.fine / 2)

		Fixtures.hand(s, caster.id, "Fine")
		playCard(s, caster.id, "Fine", victim.id)
		s.round = 2
		Fixtures.hand(s, caster.id, "Fine")
		playCard(s, caster.id, "Fine", victim.id)
		expect(victim.cash).toBe(Economy.startingCash - half - half)
		expect(victim.damageReducedRound).toBe(2)
	end)

	it("se aplica después de Cazador: 1,5 y luego la mitad", function()
		local s = Fixtures.game({ players = 2 })
		local leader = s.players[1]
		local caster = s.players[2]
		Fixtures.turnOf(s, caster.id)
		table.insert(caster.perks, "Hunter")
		table.insert(leader.perks, "Armored")
		Fixtures.hand(s, caster.id, "Fine")

		playCard(s, caster.id, "Fine", leader.id)
		local hit = math.floor(Economy.cards.fine * Economy.perks.hunterDamageMultiplier)
		local damage = math.floor(hit / Economy.perks.armoredDamageDivisor)
		expect(damage).toBe(75)
		expect(leader.cash).toBe(Economy.startingCash - damage)
	end)
end)

describe("Coleccionista", function()
	it("paga 100 al robar con la mano llena", function()
		local s = Fixtures.game({ players = 2 })
		local player = s.players[1]
		table.insert(player.perks, "Collector")
		for _, cardId in { "Shield", "ExtraDie", "Reverse" } do
			Fixtures.hand(s, player.id, cardId)
		end
		expect(#player.hand).toBe(Economy.handLimit)

		local events = Deck.draw(s, player.id)
		expect(events[1].type).toBe("CardDiscarded")
		expect(#player.hand).toBe(Economy.handLimit)
		expect(player.cash).toBe(Economy.startingCash + Economy.perks.collectorBonus)
		expect(s.stats[player.id].cardsDrawn).toBe(1)
	end)

	it("no paga si la mano no está llena", function()
		local s = Fixtures.game({ players = 2 })
		local player = s.players[1]
		table.insert(player.perks, "Collector")
		local events = Deck.draw(s, player.id)
		expect(events[1].type).toBe("CardDrawn")
		expect(player.cash).toBe(Economy.startingCash)
	end)
end)

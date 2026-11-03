--!strict
-- Cartas raras: una prueba por carta con el estado antes y después, las restricciones de cada
-- objetivo y la caducidad de los modificadores de renta. Renta Rebotada es una reacción y llega
-- en la Tarea 5.
local Harness = require("../harness")
local Bankruptcy = require("../../src/shared/rules/Bankruptcy")
local Cards = require("../../src/shared/rules/Cards")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Property = require("../../src/shared/rules/Property")
local Types = require("../../src/shared/rules/Types")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

type PlayArgs = Cards.PlayArgs

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

-- Renta base de una casilla libre de efectos: 10 % del precio, sin redondear dos veces.
local function baseRent(state: Types.GameState, index: number): number
	return math.floor(priceOf(state, index) * Economy.baseRentRate)
end

local function modifierExpiry(state: Types.GameState, rounds: number): number
	return state.round + rounds - 1
end

describe("Inflación", function()
	it("duplica las rentas 2 rondas y después caduca", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		-- La ronda 2 no es final ni de presión: la única variable es la Inflación.
		s.round = 2
		Fixtures.give(s, a.id, idx)
		Fixtures.hand(s, a.id, "Inflation")
		local doubled = math.floor(priceOf(s, idx) * Economy.baseRentRate * Economy.inflationRentMultiplier)

		local events = playCard(s, a.id, "Inflation")
		expect(events).toEqual({ { type = "CardPlayed", playerId = a.id, cardId = "Inflation" } })
		expect(s.modifiers).toEqual({
			{ kind = "Inflation", untilRound = modifierExpiry(s, Economy.cards.inflationRounds) },
		})
		expect(a.hand).toEqual({})
		expect(a.cash).toBe(Economy.startingCash)
		expect(a.position).toBe(1)
		expect(s.phase).toBe("AwaitRoll")
		expect(s.stats[a.id].cardsPlayed).toBe(1)
		expect(Property.rentMultiplier(s, idx)).toBe(Economy.inflationRentMultiplier)
		expect(Property.rentFor(s, idx)).toBe(doubled)

		-- Sigue activa la última ronda de su duración.
		s.round += 1
		expect(Property.rentFor(s, idx)).toBe(doubled)

		-- En la ronda de caducidad la renta vuelve a la base.
		s.round += 1
		expect(Property.rentMultiplier(s, idx)).toBe(1)
		expect(Property.rentFor(s, idx)).toBe(baseRent(s, idx))
	end)
end)

describe("Apagón", function()
	it("anula la renta de una zona 2 rondas y no toca las demás", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local zone = zoneIndices(s, 1)
		local other = zoneIndices(s, 2)[1]
		s.round = 5
		Fixtures.give(s, a.id, zone[1])
		Fixtures.give(s, a.id, other)
		Fixtures.hand(s, a.id, "Blackout")

		local events = playCard(s, a.id, "Blackout", { zoneId = zoneIdOf(s, 1) })
		expect(events).toEqual({ { type = "CardPlayed", playerId = a.id, cardId = "Blackout" } })
		expect(s.modifiers).toEqual({
			{
				kind = "Blackout",
				zoneId = zoneIdOf(s, 1),
				untilRound = modifierExpiry(s, Economy.cards.blackoutRounds),
			},
		})
		expect(a.hand).toEqual({})
		expect(a.cash).toBe(Economy.startingCash)
		expect(s.phase).toBe("AwaitRoll")
		expect(Property.rentFor(s, zone[1])).toBe(0)
		expect(Property.rentFor(s, other)).toBe(baseRent(s, other))

		-- La zona sigue apagada la última ronda de su duración.
		s.round += 1
		expect(Property.rentFor(s, zone[1])).toBe(0)
		expect(Property.rentFor(s, other)).toBe(baseRent(s, other))

		-- Al caducar, la zona vuelve a cobrar.
		s.round += 1
		expect(Property.rentFor(s, zone[1])).toBe(baseRent(s, zone[1]))
	end)

	it("rechaza una zona ausente o inexistente sin tocar el estado", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		Fixtures.hand(s, a.id, "Blackout")
		local before = deepCopy(s)
		expect(rejected(Engine.apply(s, a.id, { type = "PlayCard", cardId = "Blackout" }))).toBe(
			"La carta Blackout necesita una zona"
		)
		expect(
			rejected(Engine.apply(s, a.id, { type = "PlayCard", cardId = "Blackout", zoneId = "zona-falsa" }))
		).toBe("La zona zona-falsa no existe")
		expect(deepCopy(s)).toEqual(before)
	end)
end)

describe("Ladrón de Escrituras", function()
	it("roba una propiedad sin edificios y la escritura cambia de dueño", function()
		local s = Fixtures.game({ players = 2 })
		local thief = inTurn(s)
		local rival = rivalsOf(s, thief.id)[1]
		local idx = zoneIndices(s, 1)[3]
		Fixtures.give(s, rival.id, idx)
		Fixtures.hand(s, thief.id, "DeedThief")

		local events = playCard(s, thief.id, "DeedThief", { index = idx })
		-- La anotación evita que Luau unifique los dos eventos en una sola forma.
		local expected: { Types.Event } = {
			{ type = "CardPlayed", playerId = thief.id, cardId = "DeedThief" },
			{ type = "PropertyBought", playerId = thief.id, index = idx, price = 0 },
		}
		expect(events).toEqual(expected)
		expect(s.properties[idx].ownerId).toBe(thief.id)
		expect(s.properties[idx].level).toBe(0)
		-- El robo no mueve efectivo: la carta es lo que se gasta.
		expect(thief.cash).toBe(Economy.startingCash)
		expect(rival.cash).toBe(Economy.startingCash)
		expect(thief.hand).toEqual({})
		expect(s.stats[thief.id].cardsPlayed).toBe(1)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("rechaza una propiedad con edificios", function()
		local s = Fixtures.game({ players = 2 })
		local thief = inTurn(s)
		local rival = rivalsOf(s, thief.id)[1]
		local idx = zoneIndices(s, 1)[1]
		Fixtures.give(s, rival.id, idx)
		s.properties[idx].level = 1
		Fixtures.hand(s, thief.id, "DeedThief")
		local before = deepCopy(s)
		expect(rejected(Engine.apply(s, thief.id, { type = "PlayCard", cardId = "DeedThief", index = idx }))).toBe(
			"No se puede robar una propiedad con edificios"
		)
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza un índice que no es una propiedad o está fuera del tablero", function()
		local s = Fixtures.game({ players = 2 })
		local thief = inTurn(s)
		Fixtures.hand(s, thief.id, "DeedThief")
		local before = deepCopy(s)
		-- La Salida no es una propiedad.
		expect(rejected(Engine.apply(s, thief.id, { type = "PlayCard", cardId = "DeedThief", index = 1 }))).toBe(
			"La casilla indicada no es una propiedad"
		)
		-- Una casilla posterior a la última tampoco.
		expect(
			rejected(
				Engine.apply(
					s,
					thief.id,
					{ type = "PlayCard", cardId = "DeedThief", index = #s.board.squares + 1 }
				)
			)
		).toBe("La casilla indicada no es una propiedad")
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza un robo que completaría el grupo del ladrón", function()
		local s = Fixtures.game({ players = 2 })
		local thief = inTurn(s)
		local rival = rivalsOf(s, thief.id)[1]
		local zone = zoneIndices(s, 1)
		Fixtures.give(s, thief.id, zone[1])
		Fixtures.give(s, thief.id, zone[2])
		Fixtures.give(s, rival.id, zone[3])
		Fixtures.hand(s, thief.id, "DeedThief")
		local before = deepCopy(s)
		expect(
			rejected(Engine.apply(s, thief.id, { type = "PlayCard", cardId = "DeedThief", index = zone[3] }))
		).toBe("Robar esta propiedad completaría el grupo")
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza una casilla libre, propia, de un ausente o sin índice", function()
		local s = Fixtures.game({ players = 3 })
		local thief = inTurn(s)
		local others = rivalsOf(s, thief.id)
		local zone = zoneIndices(s, 1)
		local free, own, left = zone[1], zone[2], zone[3]
		Fixtures.give(s, thief.id, own)
		Fixtures.give(s, others[1].id, left)
		others[1].status = "Left"
		Fixtures.hand(s, thief.id, "DeedThief")
		local before = deepCopy(s)
		expect(rejected(Engine.apply(s, thief.id, { type = "PlayCard", cardId = "DeedThief" }))).toBe(
			"La carta DeedThief necesita una propiedad"
		)
		expect(rejected(Engine.apply(s, thief.id, { type = "PlayCard", cardId = "DeedThief", index = free }))).toBe(
			"La propiedad no tiene dueño"
		)
		expect(rejected(Engine.apply(s, thief.id, { type = "PlayCard", cardId = "DeedThief", index = own }))).toBe(
			"No puedes robarte una propiedad"
		)
		expect(rejected(Engine.apply(s, thief.id, { type = "PlayCard", cardId = "DeedThief", index = left }))).toBe(
			"El dueño de la propiedad no es un rival activo"
		)
		expect(deepCopy(s)).toEqual(before)
	end)

	it("R-P52: un espectro no puede jugar Ladrón de Escrituras", function()
		local s = Fixtures.game({ players = 3 })
		local ghost = inTurn(s)
		local rival = rivalsOf(s, ghost.id)[1]
		local index = zoneIndices(s, 1)[1]
		Fixtures.give(s, rival.id, index)
		Fixtures.hand(s, ghost.id, "DeedThief")
		ghost.status = "Ghost"
		local before = deepCopy(s)

		expect(Cards.reason(s, ghost.id, "DeedThief", { index = index })).toBe(
			"Solo los jugadores activos pueden jugar cartas"
		)
		expect(
			rejected(Engine.apply(s, ghost.id, { type = "PlayCard", cardId = "DeedThief", index = index }))
		).toBe("Solo los jugadores activos pueden jugar cartas")
		expect(deepCopy(s)).toEqual(before)
	end)
end)

describe("Puñalada", function()
	it("rompe un pacto propio sin coste, devuelve las garantías y marca al traidor", function()
		local s = Fixtures.game({ players = 2 })
		local caster = inTurn(s)
		local partner = rivalsOf(s, caster.id)[1]
		-- El lanzador es la parte b: así la prueba distingue depositar la garantía correcta.
		local pact: Types.Pact = {
			id = "P1",
			a = partner.id,
			b = caster.id,
			depositA = Economy.pact.negotiatorDeposit,
			depositB = Economy.pact.deposit,
			untilRound = s.round + 2,
		}
		-- Las garantías se depositaron al formar el pacto: simula el efectivo ya retenido.
		partner.cash -= pact.depositA
		caster.cash -= pact.depositB
		table.insert(s.pacts, pact)
		Fixtures.hand(s, caster.id, "Backstab")

		local events = playCard(s, caster.id, "Backstab", { pactId = "P1" })
		-- La anotación evita que Luau unifique los dos eventos en una sola forma.
		local expected: { Types.Event } = {
			{ type = "CardPlayed", playerId = caster.id, cardId = "Backstab" },
			{ type = "PactBroken", pactId = "P1", playerId = caster.id },
		}
		expect(events).toEqual(expected)
		expect(s.pacts).toEqual({})
		-- Nadie paga: cada parte recupera su garantía y el total de efectivo no cambia.
		expect(caster.cash).toBe(Economy.startingCash)
		expect(partner.cash).toBe(Economy.startingCash)
		local traitorUntilRound = caster.traitorUntilRound
		if not traitorUntilRound then
			error("la marca de Traidor no se escribió", 2)
		end
		-- La marca dura exactamente 3 rondas contando la actual: untilRound es la última activa.
		expect(traitorUntilRound - s.round + 1).toBe(3)
		expect(traitorUntilRound).toBe(s.round + Economy.pact.traitorRounds - 1)
		expect(partner.traitorUntilRound).toBe(nil)
		expect(caster.hand).toEqual({})
		expect(s.stats[caster.id].pactsBroken).toBe(1)
		expect(s.stats[partner.id].pactsBroken).toBe(nil)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("rechaza un pacto del que el lanzador no forma parte", function()
		local s = Fixtures.game({ players = 3 })
		local caster = inTurn(s)
		local others = rivalsOf(s, caster.id)
		table.insert(s.pacts, {
			id = "P1",
			a = others[1].id,
			b = others[2].id,
			depositA = Economy.pact.deposit,
			depositB = Economy.pact.deposit,
			untilRound = s.round + 2,
		})
		Fixtures.hand(s, caster.id, "Backstab")
		local before = deepCopy(s)
		expect(
			rejected(Engine.apply(s, caster.id, { type = "PlayCard", cardId = "Backstab", pactId = "P1" }))
		).toBe("No participas en ese pacto")
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza un pacto ausente o que no existe", function()
		local s = Fixtures.game({ players = 2 })
		local caster = inTurn(s)
		Fixtures.hand(s, caster.id, "Backstab")
		local before = deepCopy(s)
		expect(rejected(Engine.apply(s, caster.id, { type = "PlayCard", cardId = "Backstab" }))).toBe(
			"La carta Backstab necesita un pacto"
		)
		expect(
			rejected(Engine.apply(s, caster.id, { type = "PlayCard", cardId = "Backstab", pactId = "P9" }))
		).toBe("El pacto no existe")
		expect(deepCopy(s)).toEqual(before)
	end)
end)

describe("Demolición", function()
	it("baja un nivel de un edificio rival y emite BuildingChanged", function()
		local s = Fixtures.game({ players = 2 })
		local caster = inTurn(s)
		local rival = rivalsOf(s, caster.id)[1]
		local idx = zoneIndices(s, 1)[1]
		Fixtures.give(s, rival.id, idx)
		s.properties[idx].level = 2
		Fixtures.hand(s, caster.id, "Demolition")

		local events = playCard(s, caster.id, "Demolition", { index = idx })
		-- La anotación evita que Luau unifique los dos eventos en una sola forma.
		local expected: { Types.Event } = {
			{ type = "CardPlayed", playerId = caster.id, cardId = "Demolition" },
			{ type = "BuildingChanged", index = idx, from = 2, to = 1 },
		}
		expect(events).toEqual(expected)
		expect(s.properties[idx].level).toBe(1)
		expect(s.properties[idx].ownerId).toBe(rival.id)
		expect(rival.cash).toBe(Economy.startingCash)
		expect(caster.cash).toBe(Economy.startingCash)
		expect(caster.hand).toEqual({})
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("rechaza un edificio propio, ausente o sin nivel", function()
		local s = Fixtures.game({ players = 2 })
		local caster = inTurn(s)
		local rival = rivalsOf(s, caster.id)[1]
		local zone = zoneIndices(s, 1)
		local own, free, bare = zone[1], zone[2], zone[3]
		Fixtures.give(s, caster.id, own)
		s.properties[own].level = 1
		Fixtures.give(s, rival.id, bare)
		Fixtures.hand(s, caster.id, "Demolition")
		local before = deepCopy(s)
		expect(rejected(Engine.apply(s, caster.id, { type = "PlayCard", cardId = "Demolition" }))).toBe(
			"La carta Demolition necesita una propiedad"
		)
		expect(
			rejected(Engine.apply(s, caster.id, { type = "PlayCard", cardId = "Demolition", index = own }))
		).toBe("No puedes demoler tu propio edificio")
		expect(
			rejected(Engine.apply(s, caster.id, { type = "PlayCard", cardId = "Demolition", index = free }))
		).toBe("La propiedad no tiene dueño")
		expect(
			rejected(Engine.apply(s, caster.id, { type = "PlayCard", cardId = "Demolition", index = bare }))
		).toBe("La propiedad no tiene edificios")
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza el edificio de un jugador que abandonó", function()
		local s = Fixtures.game({ players = 3 })
		local caster = inTurn(s)
		local left = rivalsOf(s, caster.id)[1]
		local idx = zoneIndices(s, 1)[1]
		left.status = "Left"
		Fixtures.give(s, left.id, idx)
		s.properties[idx].level = 1
		Fixtures.hand(s, caster.id, "Demolition")
		local before = deepCopy(s)
		expect(
			rejected(Engine.apply(s, caster.id, { type = "PlayCard", cardId = "Demolition", index = idx }))
		).toBe("El dueño de la propiedad no es un rival activo")
		expect(deepCopy(s)).toEqual(before)
	end)
end)

describe("permisos de las cartas raras", function()
	it("rechaza una carta que no está en la mano", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local before = deepCopy(s)
		expect(rejected(Engine.apply(s, a.id, { type = "PlayCard", cardId = "Inflation" }))).toBe(
			"No tienes la carta Inflation en la mano"
		)
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza jugar fuera de AwaitRoll y AwaitEnd sin tocar el estado", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local rival = rivalsOf(s, a.id)[1]
		local idx = zoneIndices(s, 1)[1]
		Fixtures.give(s, rival.id, idx)
		s.properties[idx].level = 1
		Fixtures.hand(s, a.id, "Demolition")
		s.phase = "AwaitBuy"
		local before = deepCopy(s)
		expect(rejected(Engine.apply(s, a.id, { type = "PlayCard", cardId = "Demolition", index = idx }))).toBe(
			"No se puede PlayCard en la fase AwaitBuy"
		)
		expect(deepCopy(s)).toEqual(before)
	end)

	it("permite jugar una carta rara en AwaitEnd sin mover la fase", function()
		local s = Fixtures.game({ players = 2 })
		local a = inTurn(s)
		local idx = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, a.id, idx)
		Fixtures.hand(s, a.id, "Inflation")
		s.phase = "AwaitEnd"
		local events = playCard(s, a.id, "Inflation")
		expect(events[1]).toEqual({ type = "CardPlayed", playerId = a.id, cardId = "Inflation" })
		expect(s.phase).toBe("AwaitEnd")
		expect(Property.rentMultiplier(s, idx)).toBe(Economy.inflationRentMultiplier)
	end)
end)

describe("Bankruptcy.charge con un jugador que abandonó (R-P21)", function()
	it("no cobra ni declara en bancarrota a un pagador Left", function()
		local s = Fixtures.game({ players = 3 })
		local left = s.players[1]
		local creditor = s.players[2]
		left.status = "Left"
		left.cash = 0
		expect(Bankruptcy.charge(s, left.id, 5000, creditor.id)).toEqual({})
		expect(left.status).toBe("Left")
		expect(left.cash).toBe(0)
		expect(creditor.cash).toBe(Economy.startingCash)
	end)
end)

describe("Economy.cards de las cartas raras", function()
	it("fija las duraciones de la ficha", function()
		expect(Economy.cards.inflationRounds).toBe(2)
		expect(Economy.cards.blackoutRounds).toBe(2)
	end)
end)

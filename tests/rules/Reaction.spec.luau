--!strict
-- Ventanas de reacción de la subfase 03: Escudo cancela una carta dirigida y Renta Rebotada
-- desvía una renta a un tercero. La ventana se agota con Engine.timeout y nunca encadena otra.
-- Solo se abre cuando el jugador elegido está Active y tiene la carta: sin ella no hay espera.
local Harness = require("../harness")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Property = require("../../src/shared/rules/Property")
local Reaction = require("../../src/shared/rules/Reaction")
local Types = require("../../src/shared/rules/Types")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function inTurn(state: Types.GameState): Types.Player
	return state.players[state.turnIndex]
end

-- Rivales del jugador en el orden de state.players.
local function others(state: Types.GameState, playerId: Types.PlayerId): { Types.Player }
	local list: { Types.Player } = {}
	for _, player in state.players do
		if player.id ~= playerId then
			table.insert(list, player)
		end
	end
	return list
end

local function pendingOf(state: Types.GameState): any
	local pending = state.pending
	if not pending then
		error("el estado no tiene pending", 2)
	end
	return pending
end

local function reactionOf(state: Types.GameState): any
	return pendingOf(state).reaction
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

local function react(
	state: Types.GameState,
	playerId: Types.PlayerId,
	cardId: string,
	targetId: Types.PlayerId?
): { Types.Event }
	local action: Types.Action = { type = "React", cardId = cardId }
	if targetId then
		action.targetId = targetId
	end
	local result = Engine.apply(state, playerId, action)
	if not result.ok then
		error(result.error, 2)
	end
	return result.events
end

-- Primera propiedad alcanzable con dos pasos de dado desde otra casilla. El jugador en turno
-- cae en ella con una tirada real (1 + 1) para que la ventana de renta nazca en el motor.
local function rentableIndex(state: Types.GameState): number
	for _, square in state.board.squares do
		if square.kind == "Property" and square.index >= 4 then
			return square.index
		end
	end
	error("el tablero no tiene una propiedad alcanzable con dos pasos", 2)
end

-- Abre la ventana de renta por la vía real: da la propiedad al dueño, coloca al pagador dos
-- casillas antes, fuerza la tirada y ejecuta Roll. Devuelve la casilla y la renta cobrada.
local function rentWindow(
	state: Types.GameState,
	ownerId: Types.PlayerId,
	payerId: Types.PlayerId
): (number, number)
	local index = rentableIndex(state)
	Fixtures.give(state, ownerId, index)
	Fixtures.placeOn(state, payerId, index - 2)
	Fixtures.dice(state, 1, 1)
	local result = Engine.apply(state, payerId, { type = "Roll" })
	if not result.ok then
		error(result.error, 2)
	end
	return index, Property.rentFor(state, index)
end

describe("Escudo", function()
	it("bloquea una carta dirigida y emite CardBlocked", function()
		local s = Fixtures.game({ players = 2 })
		local caster = inTurn(s)
		local target = others(s, caster.id)[1]
		Fixtures.hand(s, caster.id, "Fine")
		Fixtures.hand(s, target.id, "Shield")

		local events = playCard(s, caster.id, "Fine", target.id)
		expect(events).toEqual({
			{ type = "CardPlayed", playerId = caster.id, cardId = "Fine", targetId = target.id },
		})
		expect(s.phase).toBe("Reaction")
		expect(reactionOf(s)).toEqual({
			trigger = { kind = "Card", cardId = "Fine", casterId = caster.id, targetId = target.id },
			-- `then` es palabra reservada: en un literal de tabla solo vale entre corchetes.
			["then"] = {
				kind = "Card",
				playerId = caster.id,
				cardId = "Fine",
				args = { targetId = target.id },
			},
			eligibleId = target.id,
			phase = "AwaitRoll",
		})
		-- La carta se gasta al jugarla aunque el escudo anule su efecto.
		expect(caster.hand).toEqual({})
		expect(s.stats[caster.id].cardsPlayed).toBe(1)
		expect(target.cash).toBe(Economy.startingCash)
		expect(caster.cash).toBe(Economy.startingCash)

		-- Solo el objetivo puede contestar; para el lanzador no hay acción legal.
		-- La anotación evita que Luau fije la forma del arreglo con el primer elemento.
		local expectedActions: { Types.Action } = {
			{ type = "React", cardId = "Shield" },
			{ type = "PassReaction" },
		}
		expect(Engine.legalActions(s, target.id)).toEqual(expectedActions)
		expect(Engine.legalActions(s, caster.id)).toEqual({})

		local blocked = react(s, target.id, "Shield")
		expect(blocked).toEqual({
			{ type = "CardBlocked", cardId = "Fine", byPlayerId = target.id },
		})
		expect(s.phase).toBe("AwaitRoll")
		expect(reactionOf(s)).toBe(nil)
		expect(target.hand).toEqual({})
		-- El efecto no ocurre: la multa no se cobra.
		expect(target.cash).toBe(Economy.startingCash)
	end)

	it("al agotarse el tiempo aplica la carta pendiente y devuelve la fase", function()
		local s = Fixtures.game({ players = 2 })
		local caster = inTurn(s)
		local target = others(s, caster.id)[1]
		Fixtures.hand(s, caster.id, "Fine")
		Fixtures.hand(s, target.id, "Shield")
		-- La fase que se restaura es la de la jugada, no siempre AwaitRoll.
		s.phase = "AwaitEnd"
		playCard(s, caster.id, "Fine", target.id)
		expect(s.phase).toBe("Reaction")

		local events = Engine.timeout(s)
		-- La Multa no emite evento propio: el efecto se ve en el efectivo.
		expect(events).toEqual({})
		expect(s.phase).toBe("AwaitEnd")
		expect(reactionOf(s)).toBe(nil)
		expect(target.cash).toBe(Economy.startingCash - Economy.cards.fine)
		expect(caster.cash).toBe(Economy.startingCash)
		-- Pasar no gasta la carta de reacción.
		expect(target.hand).toEqual({ "Shield" })
	end)

	it("sin escudo no abre ninguna ventana", function()
		local s = Fixtures.game({ players = 2 })
		local caster = inTurn(s)
		local target = others(s, caster.id)[1]
		Fixtures.hand(s, caster.id, "Fine")

		local events = playCard(s, caster.id, "Fine", target.id)
		expect(events).toEqual({
			{ type = "CardPlayed", playerId = caster.id, cardId = "Fine", targetId = target.id },
		})
		expect(s.phase).toBe("AwaitRoll")
		expect(reactionOf(s)).toBe(nil)
		expect(target.cash).toBe(Economy.startingCash - Economy.cards.fine)
	end)

	it("una carta sin objetivo de jugador no espera aunque haya escudos", function()
		local s = Fixtures.game({ players = 2 })
		local caster = inTurn(s)
		local rival = others(s, caster.id)[1]
		Fixtures.hand(s, caster.id, "Inflation")
		Fixtures.hand(s, rival.id, "Shield")

		playCard(s, caster.id, "Inflation")
		expect(s.phase).toBe("AwaitRoll")
		expect(reactionOf(s)).toBe(nil)
		expect(rival.hand).toEqual({ "Shield" })
	end)
end)

describe("Renta Rebotada", function()
	it("desvía la renta a un tercero y el pagador no paga", function()
		local s = Fixtures.game({ players = 3 })
		local payer = inTurn(s)
		local rivals = others(s, payer.id)
		local owner, third = rivals[1], rivals[2]
		Fixtures.hand(s, payer.id, "BounceRent")

		local index, amount = rentWindow(s, owner.id, payer.id)
		expect(s.phase).toBe("Reaction")
		expect(reactionOf(s)).toEqual({
			trigger = {
				kind = "Rent",
				index = index,
				payerId = payer.id,
				ownerId = owner.id,
				amount = amount,
			},
			["then"] = {
				kind = "Rent",
				index = index,
				payerId = payer.id,
				ownerId = owner.id,
				amount = amount,
			},
			eligibleId = payer.id,
			-- La renta nace resolviendo la casilla: al cerrar la ventana se vuelve a AwaitEnd.
			phase = "AwaitEnd",
		})
		-- Solo el tercero es un objetivo legal: ni el propio pagador ni el dueño.
		local expectedActions: { Types.Action } = {
			{ type = "React", cardId = "BounceRent", targetId = third.id },
			{ type = "PassReaction" },
		}
		expect(Engine.legalActions(s, payer.id)).toEqual(expectedActions)
		expect(Engine.legalActions(s, owner.id)).toEqual({})

		local events = react(s, payer.id, "BounceRent", third.id)
		expect(events).toEqual({
			{ type = "RentPaid", index = index, from = third.id, to = owner.id, amount = amount },
		})
		expect(payer.cash).toBe(Economy.startingCash)
		expect(third.cash).toBe(Economy.startingCash - amount)
		expect(owner.cash).toBe(Economy.startingCash + amount)
		expect(payer.hand).toEqual({})
		expect(s.phase).toBe("AwaitEnd")
		expect(reactionOf(s)).toBe(nil)
	end)

	it("sin Renta Rebotada la renta se cobra en el acto", function()
		local s = Fixtures.game({ players = 2 })
		local payer = inTurn(s)
		local owner = others(s, payer.id)[1]

		local index, amount = rentWindow(s, owner.id, payer.id)
		expect(reactionOf(s)).toBe(nil)
		expect(s.phase).toBe("AwaitEnd")
		expect(payer.cash).toBe(Economy.startingCash - amount)
		expect(owner.cash).toBe(Economy.startingCash + amount)
		expect(Property.rentFor(s, index)).toBe(amount)
	end)

	it("en 2 jugadores no hay ventana: cobra en el acto y la carta se queda", function()
		local s = Fixtures.game({ players = 2 })
		local payer = inTurn(s)
		local owner = others(s, payer.id)[1]
		Fixtures.hand(s, payer.id, "BounceRent")

		-- Sin un tercero legal a quien rebotar la renta, la ventana sería un pase de 5 s en cada
		-- renta para siempre. No se abre: el cobro ocurre en el acto.
		local index, amount = rentWindow(s, owner.id, payer.id)
		expect(reactionOf(s)).toBe(nil)
		expect(s.phase).toBe("AwaitEnd")
		expect(payer.cash).toBe(Economy.startingCash - amount)
		expect(owner.cash).toBe(Economy.startingCash + amount)
		expect(Property.rentFor(s, index)).toBe(amount)
		-- La carta sigue en la mano: no se gastó en una ventana que no existió.
		expect(payer.hand).toEqual({ "BounceRent" })
	end)

	it("una reacción no abre otra ventana aunque el tercero también tenga la carta", function()
		local s = Fixtures.game({ players = 3 })
		local payer = inTurn(s)
		local rivals = others(s, payer.id)
		local owner, third = rivals[1], rivals[2]
		Fixtures.hand(s, payer.id, "BounceRent")
		Fixtures.hand(s, third.id, "BounceRent")

		local index, amount = rentWindow(s, owner.id, payer.id)
		expect(reactionOf(s).eligibleId).toBe(payer.id)
		react(s, payer.id, "BounceRent", third.id)
		expect(s.phase).toBe("AwaitEnd")
		expect(reactionOf(s)).toBe(nil)
		expect(third.cash).toBe(Economy.startingCash - amount)
		-- El tercero conserva su carta: nadie abrió una segunda ventana.
		expect(third.hand).toEqual({ "BounceRent" })
		expect(Property.rentFor(s, index)).toBe(amount)
	end)
end)

describe("ventana de reacción", function()
	it("solo el jugador elegido puede responder", function()
		local s = Fixtures.game({ players = 3 })
		local caster = inTurn(s)
		local rivals = others(s, caster.id)
		local target, third = rivals[1], rivals[2]
		Fixtures.hand(s, caster.id, "Fine")
		Fixtures.hand(s, target.id, "Shield")
		playCard(s, caster.id, "Fine", target.id)
		local before = deepCopy(s)

		expect(rejected(Engine.apply(s, caster.id, { type = "PassReaction" }))).toBe(
			"Solo el jugador elegido puede responder a la reacción"
		)
		expect(rejected(Engine.apply(s, third.id, { type = "PassReaction" }))).toBe(
			"Solo el jugador elegido puede responder a la reacción"
		)
		expect(rejected(Engine.apply(s, third.id, { type = "React", cardId = "Shield" }))).toBe(
			"Solo el jugador elegido puede responder a la reacción"
		)
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza una carta que no responde al disparo de la ventana", function()
		local s = Fixtures.game({ players = 2 })
		local caster = inTurn(s)
		local target = others(s, caster.id)[1]
		Fixtures.hand(s, caster.id, "Fine")
		Fixtures.hand(s, target.id, "Shield")
		Fixtures.hand(s, target.id, "BounceRent")
		playCard(s, caster.id, "Fine", target.id)
		local before = deepCopy(s)

		expect(
			rejected(
				Engine.apply(s, target.id, { type = "React", cardId = "BounceRent", targetId = caster.id })
			)
		).toBe("La carta BounceRent no responde a esta reacción")
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza responder con una carta que ya no está en la mano", function()
		local s = Fixtures.game({ players = 3 })
		local payer = inTurn(s)
		local rivals = others(s, payer.id)
		local owner, third = rivals[1], rivals[2]
		Fixtures.hand(s, payer.id, "BounceRent")
		rentWindow(s, owner.id, payer.id)
		-- La carta desaparece de la mano: la ventana no la acepta.
		payer.hand = {}
		local before = deepCopy(s)

		expect(
			rejected(
				Engine.apply(s, payer.id, { type = "React", cardId = "BounceRent", targetId = third.id })
			)
		).toBe("No tienes la carta BounceRent en la mano")
		expect(deepCopy(s)).toEqual(before)
	end)

	it("rechaza un tercero que no es un jugador activo", function()
		local s = Fixtures.game({ players = 3 })
		local payer = inTurn(s)
		local rivals = others(s, payer.id)
		local owner, third = rivals[1], rivals[2]
		Fixtures.hand(s, payer.id, "BounceRent")
		rentWindow(s, owner.id, payer.id)
		third.status = "Ghost"
		local before = deepCopy(s)

		expect(rejected(Engine.apply(s, payer.id, { type = "React", cardId = "BounceRent" }))).toBe(
			"Renta Rebotada necesita un objetivo"
		)
		expect(
			rejected(
				Engine.apply(s, payer.id, { type = "React", cardId = "BounceRent", targetId = payer.id })
			)
		).toBe("El objetivo de Renta Rebotada no puede ser el pagador")
		expect(
			rejected(
				Engine.apply(s, payer.id, { type = "React", cardId = "BounceRent", targetId = owner.id })
			)
		).toBe("El objetivo de Renta Rebotada no puede ser el dueño")
		expect(
			rejected(
				Engine.apply(s, payer.id, { type = "React", cardId = "BounceRent", targetId = third.id })
			)
		).toBe(`El objetivo {third.id} no es un jugador activo`)
		expect(deepCopy(s)).toEqual(before)
	end)

	it("el tiempo agotado de una renta se comporta como pasar", function()
		-- Tres jugadores: la ventana de renta solo se abre si hay un tercero legal (Fix 2).
		local s = Fixtures.game({ players = 3 })
		local payer = inTurn(s)
		local owner = others(s, payer.id)[1]
		Fixtures.hand(s, payer.id, "BounceRent")

		local index, amount = rentWindow(s, owner.id, payer.id)
		expect(s.phase).toBe("Reaction")
		local events = Engine.timeout(s)
		expect(events).toEqual({
			{ type = "RentPaid", index = index, from = payer.id, to = owner.id, amount = amount },
		})
		expect(s.phase).toBe("AwaitEnd")
		expect(reactionOf(s)).toBe(nil)
		expect(payer.cash).toBe(Economy.startingCash - amount)
		expect(owner.cash).toBe(Economy.startingCash + amount)
		-- Pasar no gasta la carta de reacción.
		expect(payer.hand).toEqual({ "BounceRent" })
	end)
end)

describe("Reaction.open", function()
	it("no abre ventana si el objetivo de la carta es un fantasma", function()
		local s = Fixtures.game({ players = 2 })
		local caster = inTurn(s)
		local target = others(s, caster.id)[1]
		target.status = "Ghost"
		Fixtures.hand(s, target.id, "Shield")
		local before = deepCopy(s)

		local events = Reaction.open(
			s,
			{ kind = "Card", cardId = "Fine", casterId = caster.id, targetId = target.id },
			{ kind = "Card", playerId = caster.id, cardId = "Fine", args = { targetId = target.id } }
		)
		expect(events).toEqual({})
		expect(s.phase).toBe("AwaitRoll")
		expect(reactionOf(s)).toBe(nil)
		expect(deepCopy(s)).toEqual(before)

		-- Por la vía del motor la carta ni siquiera se puede jugar contra un fantasma.
		Fixtures.hand(s, caster.id, "Fine")
		expect(
			rejected(Engine.apply(s, caster.id, { type = "PlayCard", cardId = "Fine", targetId = target.id }))
		).toBe(`El objetivo {target.id} no es un rival activo`)
		expect(s.phase).toBe("AwaitRoll")
		expect(reactionOf(s)).toBe(nil)
	end)

	it("no abre ventana si el objetivo no tiene el escudo", function()
		local s = Fixtures.game({ players = 2 })
		local caster = inTurn(s)
		local target = others(s, caster.id)[1]
		local events = Reaction.open(
			s,
			{ kind = "Card", cardId = "Fine", casterId = caster.id, targetId = target.id },
			{ kind = "Card", playerId = caster.id, cardId = "Fine", args = { targetId = target.id } }
		)
		expect(events).toEqual({})
		expect(s.phase).toBe("AwaitRoll")
		expect(reactionOf(s)).toBe(nil)
	end)
end)

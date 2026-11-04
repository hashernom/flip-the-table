--!strict
-- Prueba de contrato de los textos del cliente. Cada escenario sale del motor y de `View` de verdad:
-- el motor decide las acciones y la vista lo que viaja, y los botones y líneas se comprueban sobre eso.
-- Con acciones inventadas, `tools/check` no vio B2, B4 ni B6: aquí no se inventa nada.
local Harness = require("../harness")
local ActionMenuRules = require("../../src/client/ui/ActionMenuRules")
local Building = require("../../src/shared/rules/Building")
local Cards = require("../../src/shared/config/Cards")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Perks = require("../../src/shared/config/Perks")
local Property = require("../../src/shared/rules/Property")
local State = require("../../src/shared/rules/State")
local Strings = require("../../src/shared/config/Strings")
local Turn = require("../../src/shared/rules/Turn")
local Types = require("../../src/shared/rules/Types")
local View = require("../../src/shared/rules/View")
local ViewText = require("../../src/client/ui/ViewText")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local NAMES: { [string]: string } = { P1 = "Ana", P2 = "Beto", P3 = "Cleo", P4 = "Dani" }

local function contains(text: string, part: string): boolean
	return string.find(text, part, 1, true) ~= nil
end

local function inTurn(state: Types.GameState): Types.Player
	return state.players[state.turnIndex]
end

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
	return state.pending
end

local function roll(state: Types.GameState, playerId: Types.PlayerId, a: number, b: number)
	Fixtures.dice(state, a, b)
	local result = Engine.apply(state, playerId, { type = "Roll" })
	if not result.ok then
		error(result.error, 2)
	end
end

-- Botones del jugador tal como los pinta el menú: con la vista y los nombres.
local function buttonsOf(state: Types.GameState, playerId: Types.PlayerId): { ActionMenuRules.Button }
	local view = View.forPlayer(state, playerId)
	return ActionMenuRules.buttonsFor(view.legalActions, { view = view, names = NAMES })
end

local function labels(buttons: { ActionMenuRules.Button }): { string }
	local out: { string } = {}
	for _, button in buttons do
		table.insert(out, button.label)
	end
	return out
end

-- Dos botones del mismo menú nunca pueden llamarse igual ni compartir id (B6).
local function expectDistinct(buttons: { ActionMenuRules.Button })
	local seenIds: { [string]: boolean } = {}
	local seenLabels: { [string]: boolean } = {}
	for _, button in buttons do
		if seenIds[button.id] then
			error(`id repetido: {button.id}`, 2)
		end
		if seenLabels[button.label] then
			error(`etiqueta repetida: {button.label}`, 2)
		end
		seenIds[button.id] = true
		seenLabels[button.label] = true
	end
end

local function findLabel(buttons: { ActionMenuRules.Button }, part: string): string?
	for _, button in buttons do
		if contains(button.label, part) then
			return button.label
		end
	end
	return nil
end

describe("ViewText: nombres y casillas", function()
	local state = Fixtures.game({ players = 4, seed = 3 })
	local view = View.forPlayer(state, "P1")

	it("el nombre sale del mapa y, sin él, del asiento; el propio lleva «tú»", function()
		expect(ViewText.playerName(view, NAMES, "P2")).toBe("Beto")
		expect(ViewText.playerName(view, NAMES, "P1")).toBe("Ana (tú)")
		-- Los asientos van en el orden barajado del motor, no en el de los ids.
		for seat, seated in view.players do
			if seated.id == "P3" then
				expect(ViewText.playerName(view, {}, "P3")).toBe(`Jugador {seat}`)
			end
		end
	end)

	it("un asiento con bot lo dice, aunque se conozca el nombre de quien se fue", function()
		for _, player in state.players do
			if player.id == "P2" then
				player.isBot = true
			end
		end
		local botView = View.forPlayer(state, "P1")
		expect(ViewText.playerName(botView, NAMES, "P2")).toBe("Beto (bot)")
		for _, player in state.players do
			player.isBot = false
		end
	end)

	it("recuerda el último nombre conocido cuando el jugador ya no está", function()
		local names: { [string]: string } = {}
		ViewText.rememberNames(names, view, function(id: string): string?
			return if id == "P2" then "Beto" else nil
		end)
		expect(names.P2).toBe("Beto")
		-- Se fue: el buscador ya no lo encuentra, y el nombre se conserva.
		ViewText.rememberNames(names, view, function(_id: string): string?
			return nil
		end)
		expect(names.P2).toBe("Beto")
	end)

	it("la casilla se nombra con el tablero de la vista y el ordinal dentro de su zona", function()
		local board = ViewText.board(view.sizeId)
		expect(ViewText.board(view.sizeId)).toBe(board)
		for index, square in board.squares do
			if square.kind == "Property" then
				local zone = board.zones[square.zoneId :: string]
				local ordinal = table.find(zone, index) :: number
				expect(ViewText.squareName(view, index)).toBe(
					Strings.property(square.zoneId :: string, ordinal)
				)
			else
				expect(ViewText.squareName(view, index)).toBe(Strings.kind(square.kind))
			end
		end
	end)
end)

describe("Menú con vistas reales: perks (B4)", function()
	local state = State.create({ playerIds = { "P1", "P2", "P3", "P4" }, seed = 5 })
	local draft = pendingOf(state).draft
	local drafter = draft.order[draft.index]

	it("cada oferta del borrador se llama como su perk y dice qué hace", function()
		local buttons = buttonsOf(state, drafter)
		expect(#buttons).toBe(Economy.perks.offerCount)
		for index, perkId in draft.offer do
			local perk = Perks.byId[perkId]
			expect(buttons[index].label).toBe(`{perk.name}: {perk.description}`)
			expect(buttons[index].action).toEqual({ type = "DraftPerk", perkId = perkId })
		end
		expectDistinct(buttons)
	end)

	it("quien no elige no tiene botones", function()
		for _, player in state.players do
			if player.id ~= drafter then
				expect(#buttonsOf(state, player.id)).toBe(0)
			end
		end
	end)
end)

describe("Menú con vistas reales: Duelo (B6)", function()
	local function duel(seed: number): (Types.GameState, Types.Player)
		local state = Fixtures.game({ players = 4, seed = seed })
		local me = inTurn(state)
		Fixtures.placeOn(state, me.id, Fixtures.squareOf(state, "Duel") - 2)
		roll(state, me.id, 1, 1)
		return state, me
	end

	it("elegir rival: un botón por rival, con su nombre", function()
		local state, me = duel(11)
		expect(state.phase).toBe("Duel")
		local buttons = buttonsOf(state, me.id)
		expect(#buttons).toBe(3)
		for _, rival in others(state, me.id) do
			expect(findLabel(buttons, `Retar a {NAMES[rival.id]}`) ~= nil).toBe(true)
		end
		expectDistinct(buttons)
	end)

	it("elegir jugada: Piedra, Papel y Tijera", function()
		local state, me = duel(11)
		local rival = others(state, me.id)[1]
		Engine.apply(state, me.id, { type = "DuelChoice", rivalId = rival.id })
		local buttons = buttonsOf(state, me.id)
		expect(labels(buttons)).toEqual({ "Piedra", "Papel", "Tijera" })
		expectDistinct(buttons)
	end)
end)

describe("Menú con vistas reales: Mercado Negro (B6)", function()
	local state = Fixtures.game({ players = 4, seed = 12 })
	local me = inTurn(state)
	Fixtures.placeOn(state, me.id, Fixtures.squareOf(state, "Market") - 2)
	roll(state, me.id, 1, 1)

	it("cada carta lleva su nombre y su precio, y se puede saltar", function()
		expect(state.phase).toBe("Market")
		local buttons = buttonsOf(state, me.id)
		local market = pendingOf(state).market
		expect(#buttons).toBe(#market.cards + 1)
		for index, card in market.cards do
			expect(buttons[index].label).toBe(`Comprar {Cards.byId[card.cardId].name} por {card.price}`)
		end
		expect(buttons[#buttons].label).toBe("No comprar nada")
		expectDistinct(buttons)
	end)

	it("con Descuento el precio mostrado es el que cobra el motor", function()
		pendingOf(state).discounts = { [me.id] = true }
		local buttons = buttonsOf(state, me.id)
		local card = pendingOf(state).market.cards[1]
		local expected = math.floor(card.price * Economy.cards.discountMultiplier)
		expect(contains(buttons[1].label, `por {expected}`)).toBe(true)
	end)
end)

describe("Menú con vistas reales: Tribunal (B6)", function()
	local state = Fixtures.game({ players = 4, seed = 13 })
	local accused = inTurn(state)
	Fixtures.placeOn(state, accused.id, Fixtures.squareOf(state, "Tribunal") - 2)
	roll(state, accused.id, 1, 1)
	local voter = others(state, accused.id)[1]

	it("cada voto dice a quién castiga y cuánto, sin botones iguales", function()
		expect(state.phase).toBe("Tribunal")
		local buttons = buttonsOf(state, voter.id)
		local accusedName = NAMES[accused.id]
		expect(findLabel(buttons, `Multa de {Economy.tribunal.fine} a {accusedName}`) ~= nil).toBe(true)
		expect(findLabel(buttons, `{accusedName} pierde un turno`) ~= nil).toBe(true)
		expect(findLabel(buttons, `{accusedName} paga {Economy.tribunal.payToPlayer} a `) ~= nil).toBe(true)
		expectDistinct(buttons)
	end)

	it("el acusado no vota: su barra queda vacía", function()
		expect(#buttonsOf(state, accused.id)).toBe(0)
	end)
end)

describe("Menú con vistas reales: cartas (B6)", function()
	it("Multa: un botón por rival, con su nombre", function()
		local state = Fixtures.game({ players = 4, seed = 14 })
		local me = inTurn(state)
		Fixtures.hand(state, me.id, "Fine")
		local buttons = buttonsOf(state, me.id)
		for _, rival in others(state, me.id) do
			expect(findLabel(buttons, `Jugar Multa contra {NAMES[rival.id]}`) ~= nil).toBe(true)
		end
		expectDistinct(buttons)
	end)

	it("Terremoto: un botón por zona, con el nombre de la zona", function()
		local state = Fixtures.game({ players = 2, seed = 15 })
		local me = inTurn(state)
		Fixtures.hand(state, me.id, "Earthquake")
		local buttons = buttonsOf(state, me.id)
		local count = 0
		for _, zoneId in state.board.zoneOrder do
			expect(findLabel(buttons, `Jugar Terremoto en {Strings.zone(zoneId).name}`) ~= nil).toBe(true)
			count += 1
		end
		expect(count > 1).toBe(true)
		expectDistinct(buttons)
	end)

	it("Ladrón de Escrituras: un botón por casilla ajena, con su nombre", function()
		local state = Fixtures.game({ players = 3, seed = 16 })
		local me = inTurn(state)
		local rival = others(state, me.id)[1]
		local zone = state.board.zones[state.board.zoneOrder[2]]
		Fixtures.give(state, rival.id, zone[1])
		Fixtures.give(state, rival.id, zone[2])
		Fixtures.hand(state, me.id, "DeedThief")
		local buttons = buttonsOf(state, me.id)
		local view = View.forPlayer(state, me.id)
		expect(
			findLabel(buttons, `Jugar Ladrón de Escrituras sobre {ViewText.squareName(view, zone[1])}`)
				~= nil
		).toBe(true)
		expect(
			findLabel(buttons, `Jugar Ladrón de Escrituras sobre {ViewText.squareName(view, zone[2])}`)
				~= nil
		).toBe(true)
		expectDistinct(buttons)
	end)

	it("una carta sin objetivo lleva solo su nombre", function()
		local state = Fixtures.game({ players = 2, seed = 17 })
		local me = inTurn(state)
		Fixtures.hand(state, me.id, "Hurricane")
		expect(findLabel(buttonsOf(state, me.id), "Jugar Huracán")).toBe("Jugar Huracán")
	end)
end)

describe("Menú con vistas reales: Renta Rebotada y Escudo (B6)", function()
	it("Renta Rebotada: un botón por tercero y «No reaccionar»", function()
		local state = Fixtures.game({ players = 4, seed = 18 })
		local payer = inTurn(state)
		local rivals = others(state, payer.id)
		local owner = rivals[1]
		Fixtures.hand(state, payer.id, "BounceRent")
		local index = 0
		for _, square in state.board.squares do
			if square.kind == "Property" then
				index = square.index
				break
			end
		end
		Fixtures.give(state, owner.id, index)
		Fixtures.placeOn(state, payer.id, index - 2 + #state.board.squares)
		roll(state, payer.id, 1, 1)
		expect(state.phase).toBe("Reaction")
		local buttons = buttonsOf(state, payer.id)
		expect(findLabel(buttons, `Renta Rebotada: que pague {NAMES[rivals[2].id]}`) ~= nil).toBe(true)
		expect(findLabel(buttons, `Renta Rebotada: que pague {NAMES[rivals[3].id]}`) ~= nil).toBe(true)
		expect(findLabel(buttons, "No reaccionar") ~= nil).toBe(true)
		expectDistinct(buttons)
	end)

	it("Escudo: se llama Escudo", function()
		local state = Fixtures.game({ players = 2, seed = 19 })
		local caster = inTurn(state)
		local target = others(state, caster.id)[1]
		Fixtures.hand(state, caster.id, "Fine")
		Fixtures.hand(state, target.id, "Shield")
		Engine.apply(state, caster.id, { type = "PlayCard", cardId = "Fine", targetId = target.id })
		expect(state.phase).toBe("Reaction")
		local buttons = buttonsOf(state, target.id)
		expect(findLabel(buttons, "Reaccionar: Escudo") ~= nil).toBe(true)
		expectDistinct(buttons)
	end)
end)

describe("Menú con vistas reales: dados, compra y construcción", function()
	it("Dedos Rápidos: con los dados retenidos, mover dice con cuáles y repetir dice cuál", function()
		local state = Fixtures.game({ players = 3, seed = 20 })
		local me = inTurn(state)
		table.insert(me.perks, "QuickFingers")
		roll(state, me.id, 3, 5)
		expect(pendingOf(state).heldRoll ~= nil).toBe(true)
		local buttons = buttonsOf(state, me.id)
		expect(findLabel(buttons, "Mover con 3 y 5") ~= nil).toBe(true)
		expect(findLabel(buttons, "Repetir el primer dado (3)") ~= nil).toBe(true)
		expect(findLabel(buttons, "Repetir el segundo dado (5)") ~= nil).toBe(true)
		expectDistinct(buttons)
	end)

	it("sin dados retenidos, tirar es tirar", function()
		local state = Fixtures.game({ players = 3, seed = 20 })
		expect(findLabel(buttonsOf(state, inTurn(state).id), "Tirar dados")).toBe("Tirar dados")
	end)

	it("comprar y no comprar dicen la casilla y el precio que cobra el motor", function()
		local state = Fixtures.game({ players = 3, seed = 21 })
		local me = inTurn(state)
		local index = 0
		for _, square in state.board.squares do
			if square.kind == "Property" then
				index = square.index
				break
			end
		end
		Fixtures.placeOn(state, me.id, index - 2 + #state.board.squares)
		roll(state, me.id, 1, 1)
		expect(state.phase).toBe("AwaitBuy")
		local view = View.forPlayer(state, me.id)
		local price = Property.priceFor(state, me.id, index)
		local name = ViewText.squareName(view, index)
		local buttons = buttonsOf(state, me.id)
		expect(labels(buttons)).toEqual({ `Comprar {name} por {price}`, `No comprar {name} (sale a subasta)` })
	end)

	it("construir dice la casilla, el nivel nuevo y el coste con los perks", function()
		local state = Fixtures.game({ players = 3, seed = 22 })
		local me = inTurn(state)
		table.insert(me.perks, "Builder")
		local zone = state.board.zones[state.board.zoneOrder[1]]
		for _, index in zone do
			Fixtures.give(state, me.id, index)
		end
		local view = View.forPlayer(state, me.id)
		local buttons = buttonsOf(state, me.id)
		for _, index in zone do
			local cost = Building.costOf(state, me.id, index)
			local expected = `Construir en {ViewText.squareName(view, index)} (nivel 1) por {cost}`
			expect(findLabel(buttons, expected) ~= nil).toBe(true)
		end
		expectDistinct(buttons)
	end)
end)

describe("Menú con vistas reales: espectro (B6)", function()
	it("sabotear y un embrujo por casilla ajena, con su nombre", function()
		local state = Fixtures.game({ players = 3, seed = 23 })
		local ghost = state.players[2]
		ghost.status = "Ghost"
		local owner = state.players[3]
		local zone = state.board.zones[state.board.zoneOrder[1]]
		Fixtures.give(state, owner.id, zone[1])
		Fixtures.turnOf(state, state.players[1].id)
		Turn.next(state)
		expect(state.phase).toBe("GhostTurn")
		local view = View.forPlayer(state, ghost.id)
		local buttons = buttonsOf(state, ghost.id)
		expect(findLabel(buttons, "Sabotear") ~= nil).toBe(true)
		expect(findLabel(buttons, `Embrujar {ViewText.squareName(view, zone[1])}`) ~= nil).toBe(true)
		expectDistinct(buttons)
	end)
end)

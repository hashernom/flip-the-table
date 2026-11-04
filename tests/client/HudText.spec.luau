--!strict
-- Textos de la barra con vistas reales del motor (B8, M14 y «Extra» de la auditoría): ronda acotada,
-- asientos con su dinero, Corona, Furia, Traidor, perks y cartas, mano propia, resultado del Espía,
-- puja más alta y quién decide. Ningún dato se inventa: todo sale de `Engine` y `View`.
local Harness = require("../harness")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Strings = require("../../src/shared/config/Strings")
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

describe("Barra: ronda", function()
	it("la ronda nunca pasa del tope: 21/20 no existe", function()
		local state = Fixtures.game({ players = 3, seed = 40 })
		local max = state.maxRounds :: number
		expect(ViewText.roundText(View.forPlayer(state, "P1"))).toBe(`Ronda 1/{max}`)
		state.round = max
		expect(ViewText.roundText(View.forPlayer(state, "P1"))).toBe(`Ronda {max}/{max}`)
		state.round = max + 1
		expect(ViewText.roundText(View.forPlayer(state, "P1"))).toBe(`Ronda {max}/{max}`)
	end)

	it("sin tope (Sin Fin) no hay «/N»", function()
		local state = Fixtures.game({ players = 3, seed = 40, endMode = "Endless" })
		state.round = 31
		expect(ViewText.roundText(View.forPlayer(state, "P1"))).toBe("Ronda 31")
	end)
end)

describe("Barra: asientos", function()
	it("dice nombre, dinero y casilla por su nombre, no el id ni «casa N»", function()
		local state = Fixtures.game({ players = 3, seed = 41 })
		local view = View.forPlayer(state, "P1")
		for index, seated in view.players do
			local line = ViewText.seatLine(view, NAMES, index)
			expect(contains(line, NAMES[seated.id])).toBe(true)
			expect(contains(line, tostring(seated.cash))).toBe(true)
			expect(contains(line, ViewText.squareName(view, seated.position))).toBe(true)
			expect(contains(line, "casa")).toBe(false)
		end
	end)

	it("enseña la flecha del turno, la Corona, la Furia, el Traidor, los perks y las cartas", function()
		local state = Fixtures.game({ players = 3, seed = 41 })
		local target = state.players[2]
		pendingOf(state).crownId = target.id
		target.fury = 3
		target.traitorUntilRound = state.round
		table.insert(target.perks, "Banker")
		table.insert(target.hand, "Fine")
		table.insert(target.hand, "Shield")
		local view = View.forPlayer(state, state.players[1].id)
		local line = ViewText.seatLine(view, NAMES, 2)
		for _, part in { "Corona", "Traidor", `Furia 3/{Economy.furyThreshold}`, "Banquero", "2 cartas" } do
			expect(contains(line, part)).toBe(true)
		end
		-- La mano ajena es un número: ningún nombre de carta se cuela.
		expect(contains(line, "Multa")).toBe(false)
		expect(contains(line, "Escudo")).toBe(false)
		local turnLine = ViewText.seatLine(view, NAMES, view.turnIndex)
		expect(string.sub(turnLine, 1, #"▶ ")).toBe("▶ ")
	end)

	it("la marca de Traidor caduca con su ronda", function()
		local state = Fixtures.game({ players = 3, seed = 41 })
		state.players[2].traitorUntilRound = 2
		state.round = 3
		local view = View.forPlayer(state, state.players[1].id)
		expect(contains(ViewText.seatLine(view, NAMES, 2), "Traidor")).toBe(false)
	end)
end)

describe("Barra: mano propia y Espía", function()
	it("tu mano y tus perks salen con nombre; la ajena no", function()
		local state = Fixtures.game({ players = 3, seed = 42 })
		local me, rival = state.players[1], state.players[2]
		table.insert(me.hand, "Hurricane")
		table.insert(me.perks, "Lucky")
		table.insert(rival.hand, "Fine")
		local lines = ViewText.ownLines(View.forPlayer(state, me.id), NAMES)
		expect(lines[1]).toBe("Tu mano: Huracán")
		expect(lines[2]).toBe("Tus perks: Afortunado")
		local rivalLines = ViewText.ownLines(View.forPlayer(state, rival.id), NAMES)
		expect(rivalLines[1]).toBe("Tu mano: Multa")
		expect(contains(table.concat(rivalLines, "\n"), "Huracán")).toBe(false)
	end)

	it("el Espía enseña la mano robada solo a quien jugó la carta", function()
		local state = Fixtures.game({ players = 3, seed = 43 })
		local me = inTurn(state)
		local rival = others(state, me.id)[1]
		table.insert(rival.hand, "Hurricane")
		table.insert(rival.hand, "Fine")
		Fixtures.hand(state, me.id, "Spy")
		local played = Engine.apply(state, me.id, { type = "PlayCard", cardId = "Spy", targetId = rival.id })
		expect(played.ok).toBe(true)
		local mine = table.concat(ViewText.ownLines(View.forPlayer(state, me.id), NAMES), "\n")
		expect(contains(mine, `Espía: {NAMES[rival.id]} tiene Huracán, Multa`)).toBe(true)
		for _, other in others(state, me.id) do
			local theirs = table.concat(ViewText.ownLines(View.forPlayer(state, other.id), NAMES), "\n")
			expect(contains(theirs, "Espía")).toBe(false)
		end
	end)
end)

describe("Barra: quién decide", function()
	it("una subasta enseña la puja más alta, quién la hizo y lo que vale la casilla", function()
		local state = Fixtures.game({ players = 3, seed = 44 })
		local index = Fixtures.squareOf(state, "Property")
		pendingOf(state).index = index
		state.phase = "AwaitBuy"
		Engine.apply(state, inTurn(state).id, { type = "DeclineBuy" })
		expect(contains(ViewText.headline(View.forPlayer(state, "P1"), NAMES), "sin pujas")).toBe(true)
		local bidder = others(state, inTurn(state).id)[1]
		expect(Engine.apply(state, bidder.id, { type = "Bid", amount = 120 }).ok).toBe(true)
		local view = View.forPlayer(state, "P1")
		local price = (state.board.squares[index] :: any).price
		local text = ViewText.headline(view, NAMES)
		expect(contains(text, `Subasta de {ViewText.squareName(view, index)} (vale {price})`)).toBe(true)
		expect(contains(text, `puja más alta 120 de {NAMES[bidder.id]}`)).toBe(true)
	end)

	it("el Tribunal, el Duelo y el turno dicen de quién es la decisión", function()
		local state = Fixtures.game({ players = 4, seed = 13 })
		local accused = inTurn(state)
		Fixtures.placeOn(state, accused.id, Fixtures.squareOf(state, "Tribunal") - 2)
		roll(state, accused.id, 1, 1)
		local other = others(state, accused.id)[1]
		expect(ViewText.headline(View.forPlayer(state, other.id), NAMES)).toBe(
			`Tribunal: castigo para {NAMES[accused.id]}`
		)
		expect(ViewText.headline(View.forPlayer(state, accused.id), NAMES)).toBe(
			"Tribunal: te juzgan los demás"
		)

		local duel = Fixtures.game({ players = 4, seed = 11 })
		local challenger = inTurn(duel)
		Fixtures.placeOn(duel, challenger.id, Fixtures.squareOf(duel, "Duel") - 2)
		roll(duel, challenger.id, 1, 1)
		expect(ViewText.headline(View.forPlayer(duel, "P1"), NAMES)).toBe(
			`Duelo: {NAMES[challenger.id]} elige rival`
		)

		local plain = Fixtures.game({ players = 3, seed = 45 })
		expect(ViewText.headline(View.forPlayer(plain, "P1"), NAMES)).toBe(
			`Turno de {NAMES[inTurn(plain).id]}`
		)
	end)

	it("los efectos activos nombran la zona o la casilla embrujada", function()
		local state = Fixtures.game({ players = 3, seed = 46 })
		local zoneId = state.board.zoneOrder[1]
		table.insert(state.modifiers, { kind = "Strike", zoneId = zoneId, untilRound = 3 })
		local owned = state.board.zones[zoneId][1]
		table.insert(state.modifiers, { kind = "Haunt", index = owned, playerId = "P2", untilRound = 1 })
		local view = View.forPlayer(state, "P1")
		expect(ViewText.modifierText(view, NAMES, view.modifiers[1])).toBe(
			`Huelga · {Strings.zone(zoneId).name} · hasta la ronda 3`
		)
		local haunt = ViewText.modifierText(view, NAMES, view.modifiers[2])
		expect(contains(haunt, "Embrujo")).toBe(true)
		expect(contains(haunt, ViewText.squareName(view, owned))).toBe(true)
		expect(contains(haunt, "de Beto")).toBe(true)
	end)
end)

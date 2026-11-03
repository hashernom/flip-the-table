--!strict
-- Pruebas de la vista por jugador: qué puede ver cada uno y qué no sale nunca del servidor. Cubre
-- las manos ajenas, los ids de las cartas robadas, las jugadas del Duelo, las papeletas del
-- Tribunal, la revelación del Espía, el generador de azar y la inmutabilidad de los eventos.
local Deck = require("../../src/shared/rules/Deck")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Harness = require("../harness")
local Types = require("../../src/shared/rules/Types")
local View = require("../../src/shared/rules/View")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

type GameState = Types.GameState
type PlayerId = Types.PlayerId
type Event = Types.Event
type PlayerView = Types.PlayerView
type ViewPlayer = Types.ViewPlayer

-- pending es la tabla persistente que State.create siempre crea (R1).
local function pendingOf(state: GameState): any
	local pending = state.pending
	if not pending then
		error("el estado no tiene pending", 2)
	end
	return pending
end

local function viewPending(view: PlayerView): any
	if not view.pending then
		error("la vista no tiene pending", 2)
	end
	return view.pending
end

local function playerView(view: PlayerView, playerId: PlayerId): ViewPlayer
	for _, player in view.players do
		if player.id == playerId then
			return player
		end
	end
	error(`la vista no tiene al jugador {playerId}`, 2)
end

-- Copia profunda: las comprobaciones de inmutabilidad se hacen contra el estado entero.
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

-- Primera ruta de una clave con ese nombre en cualquier profundidad, o nil si no aparece.
local function findKey(value: any, key: string, path: string?): string?
	if type(value) ~= "table" then
		return nil
	end
	for name, item in value do
		local here = if path then `{path}.{tostring(name)}` else tostring(name)
		if name == key then
			return here
		end
		local found = findKey(item, key, here)
		if found then
			return found
		end
	end
	return nil
end

-- ¿Aparece ese texto como clave o como valor en cualquier profundidad?
local function containsString(value: any, wanted: string): boolean
	if type(value) == "string" then
		return value == wanted
	elseif type(value) ~= "table" then
		return false
	end
	for name, item in value do
		if containsString(name, wanted) or containsString(item, wanted) then
			return true
		end
	end
	return false
end

-- ¿Aparece ese valor en cualquier profundidad? Con tablas compara identidad, no contenido.
local function containsValue(value: any, wanted: any): boolean
	if value == wanted then
		return true
	elseif type(value) ~= "table" then
		return false
	end
	for name, item in value do
		if containsValue(name, wanted) or containsValue(item, wanted) then
			return true
		end
	end
	return false
end

local function hasAction(view: PlayerView, actionType: string): boolean
	for _, action in view.legalActions do
		if action.type == actionType then
			return true
		end
	end
	return false
end

local function applyOk(state: GameState, playerId: PlayerId, action: Types.Action): { Event }
	local result = Engine.apply(state, playerId, action)
	if not result.ok then
		error(result.error, 2)
	end
	return result.events
end

local function firstEvent(events: { Event }, eventType: string): Event
	for _, event in events do
		if event.type == eventType then
			return event
		end
	end
	error(`no hay ningún evento {eventType}`, 2)
end

-- Deja al jugador dos casillas antes de `index` (con vuelta) y tira (1, 1) para pisarla.
local function landOn(state: GameState, playerId: PlayerId, index: number)
	local size = #state.board.squares
	Fixtures.turnOf(state, playerId)
	Fixtures.placeOn(state, playerId, (index - 3) % size + 1)
	Fixtures.dice(state, 1, 1)
	applyOk(state, playerId, { type = "Roll" })
end

local function openDuel(state: GameState, challengerId: PlayerId, rivalId: PlayerId)
	landOn(state, challengerId, Fixtures.squareOf(state, "Duel"))
	expect(state.phase).toBe("Duel")
	applyOk(state, challengerId, { type = "DuelChoice", rivalId = rivalId })
end

local function openTribunal(state: GameState, accusedId: PlayerId)
	landOn(state, accusedId, Fixtures.squareOf(state, "Tribunal"))
	expect(state.phase).toBe("Tribunal")
	expect(pendingOf(state).tribunal.accusedId).toBe(accusedId)
end

local function firstPropertyIndex(state: GameState): number
	for _, square in state.board.squares do
		if square.kind == "Property" then
			return square.index
		end
	end
	error("el tablero no tiene propiedades", 2)
end

describe("View.forPlayer: manos", function()
	it("muestra la mano propia completa y solo el número de las demás", function()
		local state = Fixtures.game({ players = 3 })
		Fixtures.hand(state, "P1", "Fine")
		Fixtures.hand(state, "P1", "Reverse")
		Fixtures.hand(state, "P2", "Spy")

		local view = View.forPlayer(state, "P1")
		local own = playerView(view, "P1")
		expect(own.hand).toEqual({ "Fine", "Reverse" })
		expect(own.handCount).toBe(2)
		expect(own.cash).toBe(1500)

		local other = playerView(view, "P2")
		expect(other.hand).toBe(nil)
		expect(other.handCount).toBe(1)
		local third = playerView(view, "P3")
		expect(third.hand).toBe(nil)
		expect(third.handCount).toBe(0)
	end)

	it("no deja la mano ajena en ningún nivel de la vista", function()
		local state = Fixtures.game({ players = 3 })
		Fixtures.hand(state, "P2", "Spy")
		expect(containsString(View.forPlayer(state, "P1"), "Spy")).toBe(false)

		Fixtures.hand(state, "P1", "Hurricane")
		expect(containsString(View.forPlayer(state, "P2"), "Hurricane")).toBe(false)
	end)
end)

describe("View.filterEvents: cartas robadas", function()
	it("conserva el id de CardDrawn para quien robó y lo oculta a los demás", function()
		local state = Fixtures.game({ players = 2 })
		local events = Deck.add(state, "P2", "Fine")
		expect(events[1]).toEqual({ type = "CardDrawn", playerId = "P2", cardId = "Fine" })

		expect(View.filterEvents(state, "P2", events)).toEqual({
			{ type = "CardDrawn", playerId = "P2", cardId = "Fine" },
		})
		expect(View.filterEvents(state, "P1", events)).toEqual({
			{ type = "CardDrawn", playerId = "P2" },
		})
		-- El evento original sigue intacto: filtrar no muta la entrada.
		expect(events[1].cardId).toBe("Fine")
	end)

	it("oculta también la carta descartada por mano llena", function()
		local state = Fixtures.game({ players = 2 })
		Fixtures.hand(state, "P2", "Fine")
		Fixtures.hand(state, "P2", "Reverse")
		Fixtures.hand(state, "P2", "Spy")
		local events = Deck.add(state, "P2", "Hurricane")
		expect(events[1]).toEqual({ type = "CardDiscarded", playerId = "P2", cardId = "Hurricane" })

		expect(View.filterEvents(state, "P2", events)[1]).toEqual(events[1])
		expect(View.filterEvents(state, "P1", events)[1]).toEqual({
			type = "CardDiscarded",
			playerId = "P2",
		})
	end)

	it("no oculta CardPlayed: una legendaria se anuncia con su id", function()
		local state = Fixtures.game({ players = 2 })
		Fixtures.hand(state, "P1", "Hurricane")
		Fixtures.turnOf(state, "P1")
		local events = applyOk(state, "P1", { type = "PlayCard", cardId = "Hurricane" })
		local played = firstEvent(events, "CardPlayed")
		expect(played).toEqual({ type = "CardPlayed", playerId = "P1", cardId = "Hurricane" })

		for _, playerId in { "P1", "P2" } do
			expect(firstEvent(View.filterEvents(state, playerId, events), "CardPlayed")).toEqual(played)
		end
	end)
end)

describe("View: Duelo", function()
	it("no revela la jugada ajena hasta que la ronda se resuelve", function()
		local state = Fixtures.game({ players = 3 })
		openDuel(state, "P1", "P2")
		applyOk(state, "P1", { type = "DuelChoice", choice = "Rock" })
		expect(pendingOf(state).duel.picks.P1).toBe("Rock")

		expect(viewPending(View.forPlayer(state, "P1")).duel.picks).toEqual({ P1 = "Rock" })
		expect(viewPending(View.forPlayer(state, "P2")).duel.picks).toEqual({})
		expect(viewPending(View.forPlayer(state, "P3")).duel.picks).toEqual({})

		local events = applyOk(state, "P2", { type = "DuelChoice", choice = "Paper" })
		expect(pendingOf(state).duel).toBe(nil)
		-- R-P18: el cierre publica las dos jugadas de la ronda; ya no queda nada secreto.
		local resolved = firstEvent(events, "DuelResolved")
		expect(resolved.winnerId).toBe("P2")
		expect(resolved.loserId).toBe("P1")
		expect(resolved.picks).toEqual({ P1 = "Rock", P2 = "Paper" })
		for _, playerId in { "P1", "P2", "P3" } do
			local visible = View.filterEvents(state, playerId, events)
			expect(visible).toEqual(events)
			expect(firstEvent(visible, "DuelResolved").picks).toEqual({ P1 = "Rock", P2 = "Paper" })
			expect(viewPending(View.forPlayer(state, playerId)).duel).toBe(nil)
			expect(containsString(viewPending(View.forPlayer(state, playerId)), "Rock")).toBe(false)
		end
	end)
end)

describe("View: Espía", function()
	it("revela la mano del objetivo solo a quien jugó la carta", function()
		local state = Fixtures.game({ players = 3 })
		Fixtures.hand(state, "P1", "Spy")
		Fixtures.hand(state, "P2", "Hurricane")
		Fixtures.turnOf(state, "P1")
		applyOk(state, "P1", { type = "PlayCard", cardId = "Spy", targetId = "P2" })

		local view = View.forPlayer(state, "P1")
		expect(viewPending(view).spy).toEqual({
			viewerId = "P1",
			targetId = "P2",
			hand = { "Hurricane" },
		})
		expect(viewPending(View.forPlayer(state, "P2")).spy).toBe(nil)
		local third = View.forPlayer(state, "P3")
		expect(viewPending(third).spy).toBe(nil)
		expect(containsString(third, "Hurricane")).toBe(false)

		-- La mano revelada es una copia: tocarla no cambia el estado.
		viewPending(view).spy.hand[1] = "Hacked"
		expect(pendingOf(state).spy.hand[1]).toBe("Hurricane")
	end)
end)

describe("View: Tribunal", function()
	it("oculta las papeletas ajenas hasta el veredicto", function()
		local state = Fixtures.game({ players = 3 })
		openTribunal(state, "P1")
		applyOk(state, "P2", { type = "TribunalVote", verdict = "Fine" })
		expect(pendingOf(state).tribunal.votes.P2.verdict).toBe("Fine")

		expect(viewPending(View.forPlayer(state, "P2")).tribunal.votes).toEqual({
			P2 = { verdict = "Fine" },
		})
		-- El acusado no tiene papeleta y no ve la de nadie.
		expect(viewPending(View.forPlayer(state, "P1")).tribunal.votes).toEqual({})
		expect(viewPending(View.forPlayer(state, "P1")).tribunal.votesCount).toBe(1)
		expect(viewPending(View.forPlayer(state, "P3")).tribunal.votes).toEqual({})

		local events = applyOk(state, "P3", { type = "TribunalVote", verdict = "SkipTurn" })
		expect(pendingOf(state).tribunal).toBe(nil)
		local verdict = firstEvent(events, "TribunalVerdict")
		expect(verdict.votes).toEqual({
			P2 = { verdict = "Fine" },
			P3 = { verdict = "SkipTurn" },
		})
		-- Después del veredicto las papeletas son públicas para todos.
		for _, playerId in { "P1", "P2", "P3" } do
			expect(firstEvent(View.filterEvents(state, playerId, events), "TribunalVerdict")).toEqual(verdict)
		end
	end)
end)

describe("View: azar", function()
	it("nunca incluye rng en la vista, a ninguna profundidad", function()
		local state = Fixtures.game({ players = 3 })
		openDuel(state, "P1", "P2")
		applyOk(state, "P1", { type = "DuelChoice", choice = "Rock" })

		for _, playerId in { "P1", "P2", "P3" } do
			local view = View.forPlayer(state, playerId)
			expect(findKey(view, "rng")).toBe(nil)
			expect(containsValue(view, state.rng)).toBe(false)
		end
	end)
end)

describe("View.filterEvents: contrato", function()
	it("no muta la lista ni los eventos que recibe", function()
		local state = Fixtures.game({ players = 2 })
		local input: { Event } = {
			{ type = "CardDrawn", playerId = "P2", cardId = "Fine" },
			{ type = "CardPlayed", playerId = "P1", cardId = "Hurricane" },
			{ type = "EventoFuturo", payload = { nested = { "x" } } },
		}
		local before = deepCopy(input)
		local output = View.filterEvents(state, "P1", input)
		-- La lista esperada mezcla formas: se anota como `any` para no fijar el tipo del primer
		-- elemento a los demás.
		local expected: { any } = {
			{ type = "CardDrawn", playerId = "P2" },
			{ type = "CardPlayed", playerId = "P1", cardId = "Hurricane" },
			{ type = "EventoFuturo", payload = { nested = { "x" } } },
		}
		expect(input).toEqual(before)
		expect(output).toEqual(expected)
		-- Lista y eventos nuevos: mutar la salida no toca la entrada.
		expect(output == input).toBe(false)
		expect(output[1] == input[1]).toBe(false)
		output[2].cardId = "Cambiado"
		expect(input[2].cardId).toBe("Hurricane")
	end)

	it("deja pasar sin tocar un evento desconocido", function()
		local state = Fixtures.game({ players = 2 })
		local event: Event = { type = "EventoFuturo", playerId = "P2", cardId = "Fine", data = { a = 1 } }
		expect(View.filterEvents(state, "P1", { event })[1]).toEqual(event)
	end)

	it("filtra como no dueño a un jugador que no está en la partida", function()
		local state = Fixtures.game({ players = 2 })
		local events = Deck.add(state, "P2", "Fine")
		expect(View.filterEvents(state, "Fantasma", events)).toEqual({
			{ type = "CardDrawn", playerId = "P2" },
		})
	end)
end)

describe("View.forPlayer: contrato", function()
	it("en Sin Fin manda 0 como «sin tope»", function()
		local state = Fixtures.game({ players = 2, endMode = "Endless" })
		expect(View.forPlayer(state, "P1").maxRounds).toBe(0)
	end)

	it("en Rondas manda el tope del tamaño", function()
		local state = Fixtures.game({ players = 2 })
		expect(View.forPlayer(state, "P1").maxRounds).toBe(state.maxRounds)
	end)

	it("es una función pura: no muta el estado y repite la misma vista", function()
		local state = Fixtures.game({ players = 3 })
		Fixtures.hand(state, "P1", "Fine")
		local before = deepCopy(state)
		local first = View.forPlayer(state, "P1")
		local second = View.forPlayer(state, "P1")
		expect(first).toEqual(second)
		expect(state).toEqual(before)

		-- La vista no comparte tablas con el estado: mutarla no toca la partida.
		local own = playerView(first, "P1")
		local hand = own.hand
		if not hand then
			error("la vista propia no tiene mano", 2)
		end
		hand[1] = "Hacked"
		own.cash = 0
		expect(state).toEqual(before)
	end)

	it("copia las propiedades sin compartirlas con el estado", function()
		local state = Fixtures.game({ players = 2 })
		local index = firstPropertyIndex(state)
		Fixtures.give(state, "P2", index)
		local view = View.forPlayer(state, "P1")
		expect(view.properties[index]).toEqual({ ownerId = "P2", level = 0 })
		view.properties[index].ownerId = "P1"
		expect(state.properties[index].ownerId).toBe("P2")
	end)

	it("incluye las acciones legales de ese jugador", function()
		local state = Fixtures.game({ players = 2 })
		Fixtures.turnOf(state, "P1")
		expect(hasAction(View.forPlayer(state, "P1"), "Roll")).toBe(true)
		expect(hasAction(View.forPlayer(state, "P2"), "Roll")).toBe(false)
	end)

	it("rechaza un jugador que no está en la partida", function()
		local state = Fixtures.game({ players = 2 })
		expect(function()
			View.forPlayer(state, "Fantasma")
		end).toThrow()
	end)
end)

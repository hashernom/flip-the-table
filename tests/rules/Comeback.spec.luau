--!strict
-- Remontada (Tarea 9): Furia al pagar rentas, turno corto del espectro (R-P43), cartas de
-- sabotaje, embrujos, resurrección con 3 sabotajes y el perk Alma en Pena (R-P6).
local Bankruptcy = require("../../src/shared/rules/Bankruptcy")
local Bot = require("../../src/shared/rules/Bot")
local CardsConfig = require("../../src/shared/config/Cards")
local Comeback = require("../../src/shared/rules/Comeback")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Harness = require("../harness")
local Property = require("../../src/shared/rules/Property")
local Score = require("../../src/shared/rules/Score")
local Turn = require("../../src/shared/rules/Turn")
local Types = require("../../src/shared/rules/Types")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

-- Las tres cartas de sabotaje de la ficha: las comunes Fine y Shove y la rara Demolition.
local SABOTAGE_CARDS: { [string]: boolean } = {
	["Fine"] = true,
	["Shove"] = true,
	["Demolition"] = true,
}

local function isSabotageCard(cardId: string): boolean
	return SABOTAGE_CARDS[cardId] == true
end

local function inTurn(state: Types.GameState): Types.Player
	return state.players[state.turnIndex]
end

local function playerOf(state: Types.GameState, playerId: Types.PlayerId): Types.Player
	for _, player in state.players do
		if player.id == playerId then
			return player
		end
	end
	error(`no existe el jugador {playerId}`, 2)
end

-- Líder de la mesa con el mismo criterio que la Furia: el primer Active de la clasificación.
local function leaderOf(state: Types.GameState): Types.Player
	for _, id in Score.ranking(state) do
		local player = playerOf(state, id)
		if player.status == "Active" then
			return player
		end
	end
	error("la partida no tiene ningún jugador activo", 2)
end

-- Casillas de propiedad en orden ascendente: los desempates de las pruebas no dependen del orden
-- de las claves de state.properties.
local function propertyIndices(state: Types.GameState): { number }
	local indices: { number } = {}
	for index in state.properties do
		table.insert(indices, index)
	end
	table.sort(indices)
	return indices
end

-- Deja al espectro como jugador en turno. El turno avanza desde el jugador anterior, así que el
-- estado pasa por la misma puerta que una partida real (Turn.next) y la fase es GhostTurn.
local function enterGhostTurn(state: Types.GameState, ghostId: Types.PlayerId): Types.Player
	local ghostIndex = 1
	for index, player in state.players do
		if player.id == ghostId then
			ghostIndex = index
		end
	end
	local previous = state.players[(ghostIndex - 2) % #state.players + 1]
	Fixtures.turnOf(state, previous.id)
	Turn.next(state)
	if state.players[state.turnIndex].id ~= ghostId then
		error("el turno no llegó al espectro", 2)
	end
	expect(state.phase).toBe("GhostTurn")
	return state.players[state.turnIndex]
end

-- Evento concreto dentro de una lista.
local function eventOf(events: { Types.Event }, kind: string): Types.Event
	for _, event in events do
		if event.type == kind then
			return event
		end
	end
	error(`no se emitió el evento {kind}`, 2)
end

local function countOf(events: { Types.Event }, kind: string): number
	local count = 0
	for _, event in events do
		if event.type == kind then
			count += 1
		end
	end
	return count
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

-- Da la propiedad a un jugador y prepara una mesa con un líder claro: players[1] no es
-- necesariamente el líder (el fixture baraja el orden), así que se sube el efectivo del que
-- debe ir primero.
local function tableWithLeader(state: Types.GameState): Types.Player
	local leader = state.players[1]
	leader.cash = Economy.startingCash * 6
	return leader
end

describe("Furia", function()
	it("sube 1 por renta pagada si el pagador no es el líder", function()
		local s = Fixtures.game({ players = 3 })
		local owner = s.players[2]
		local payer = s.players[3]
		local leader = tableWithLeader(s)
		expect(leaderOf(s).id).toBe(leader.id)
		local index = propertyIndices(s)[1]
		Fixtures.give(s, owner.id, index)

		Property.payRent(s, payer.id, index)
		expect(payer.fury).toBe(1)
		expect(owner.fury).toBe(0)
		expect(leader.fury).toBe(0)
	end)

	it("no cambia cuando el que paga es el líder", function()
		local s = Fixtures.game({ players = 3 })
		local owner = s.players[2]
		local leader = tableWithLeader(s)
		leader.fury = 3
		local index = propertyIndices(s)[1]
		Fixtures.give(s, owner.id, index)

		Property.payRent(s, leader.id, index)
		expect(leader.fury).toBe(3)
	end)

	it("acumula una unidad por cada renta pagada", function()
		local s = Fixtures.game({ players = 3 })
		local owner = s.players[2]
		local payer = s.players[3]
		tableWithLeader(s)
		local index = propertyIndices(s)[1]
		Fixtures.give(s, owner.id, index)

		for _ = 1, Economy.furyThreshold - 1 do
			Property.payRent(s, payer.id, index)
		end
		expect(payer.fury).toBe(Economy.furyThreshold - 1)
		expect(#payer.hand).toBe(0)
	end)

	it("al llenarse roba una carta rara o mejor, vuelve a 0 y emite FuryFilled", function()
		local s = Fixtures.game({ players = 3 })
		local owner = s.players[2]
		local payer = s.players[3]
		tableWithLeader(s)
		local index = propertyIndices(s)[1]
		Fixtures.give(s, owner.id, index)
		payer.fury = Economy.furyThreshold - 1

		local events = Property.payRent(s, payer.id, index)
		expect(payer.fury).toBe(0)
		expect(eventOf(events, "FuryFilled").playerId).toBe(payer.id)
		local drawn = eventOf(events, "CardDrawn")
		local cardId = drawn.cardId :: string
		expect(CardsConfig.byId[cardId].rarity ~= "Common").toBe(true)
		expect(table.find(payer.hand, cardId) ~= nil).toBe(true)

		-- El medidor vuelve a 0 tras el robo y empieza otra vez con la renta siguiente.
		Property.payRent(s, payer.id, index)
		expect(payer.fury).toBe(1)
	end)

	it("lee el liderazgo antes de mover el dinero (R-P50)", function()
		local s = Fixtures.game({ players = 2 })
		local payer = s.players[1]
		local owner = s.players[2]
		local index = propertyIndices(s)[1]
		local price = s.board.squares[index].price :: number
		Fixtures.give(s, owner.id, index)
		-- El pagador lidera por 10 antes del cobro; la renta (10 % del precio) le deja por debajo.
		owner.cash = 0
		payer.cash = price + 10
		expect(leaderOf(s).id).toBe(payer.id)

		Property.payRent(s, payer.id, index)
		-- Si la Furia mirara la clasificación después del cobro, subiría; se lee antes (R-P50).
		expect(payer.fury).toBe(0)
		expect(leaderOf(s).id).toBe(owner.id)
	end)

	it("no da Furia a quien queda en bancarrota con esa renta", function()
		local s = Fixtures.game({ players = 3 })
		local owner = s.players[2]
		local payer = s.players[3]
		tableWithLeader(s)
		local index = propertyIndices(s)[1]
		Fixtures.give(s, owner.id, index)
		payer.cash = 0
		payer.fury = Economy.furyThreshold - 1

		local events = Property.payRent(s, payer.id, index)
		expect(payer.status).toBe("Ghost")
		expect(payer.fury).toBe(Economy.furyThreshold - 1)
		expect(countOf(events, "FuryFilled")).toBe(0)
	end)

	it("no emite eventos después de GameEnded si la renta arruina al último rival", function()
		local s = Fixtures.game({ players = 2 })
		local owner = s.players[1]
		local payer = s.players[2]
		local index = propertyIndices(s)[1]
		Fixtures.give(s, owner.id, index)
		payer.cash = 0
		payer.fury = Economy.furyThreshold - 1

		local events = Property.payRent(s, payer.id, index)
		expect(s.phase).toBe("GameOver")
		expect(payer.status).toBe("Ghost")
		expect(countOf(events, "FuryFilled")).toBe(0)
		expect(events[#events].type).toBe("GameEnded")
	end)
end)

describe("turno de espectro (R-P43)", function()
	it("sustituye a la tirada y termina tras una acción", function()
		local s = Fixtures.game({ players = 3 })
		local ghost = s.players[2]
		local active = s.players[1]
		ghost.status = "Ghost"
		enterGhostTurn(s, ghost.id)

		-- La fase es propia: ni dados ni fin de turno normal.
		expect(rejected(Engine.apply(s, ghost.id, { type = "Roll" }))).toBe(
			"No se puede Roll en la fase GhostTurn"
		)
		expect(rejected(Engine.apply(s, ghost.id, { type = "EndTurn" }))).toBe(
			"No se puede EndTurn en la fase GhostTurn"
		)
		expect(Engine.legalActions(s, ghost.id)[1]).toEqual({ type = "GhostAct", kind = "Sabotage" })
		for _, action in Engine.legalActions(s, ghost.id) do
			expect(action.type).toBe("GhostAct")
		end

		local result = Engine.apply(s, ghost.id, { type = "GhostAct", kind = "Sabotage" })
		if not result.ok then
			error(result.error, 2)
		end
		local acted = eventOf(result.events, "GhostActed")
		expect(acted.playerId).toBe(ghost.id)
		expect(acted.kind).toBe("Sabotage")
		expect(ghost.sabotages).toBe(1)
		expect(#ghost.hand).toBe(1)
		expect(isSabotageCard(ghost.hand[1])).toBe(true)

		-- Una sola acción: el turno ya está en el siguiente jugador activo.
		expect(s.phase).toBe("AwaitRoll")
		expect(s.players[s.turnIndex].id ~= ghost.id).toBe(true)
		expect(inTurn(s).status).toBe("Active")
		expect(active.status).toBe("Active")
	end)

	it("no ofrece ni permite jugar cartas normales", function()
		local s = Fixtures.game({ players = 3 })
		local ghost = s.players[2]
		local target = s.players[1]
		ghost.status = "Ghost"
		Fixtures.hand(s, ghost.id, "Fine")
		enterGhostTurn(s, ghost.id)

		local action: Types.Action = {
			type = "PlayCard",
			cardId = "Fine",
			targetId = target.id,
		}
		expect(rejected(Engine.apply(s, ghost.id, action))).toBe("No se puede PlayCard en la fase GhostTurn")
	end)

	it("solo el espectro en turno puede actuar", function()
		local s = Fixtures.game({ players = 3 })
		local ghost = s.players[2]
		local active = s.players[1]
		ghost.status = "Ghost"
		enterGhostTurn(s, ghost.id)
		local action: Types.Action = { type = "GhostAct", kind = "Sabotage" }

		expect(rejected(Engine.apply(s, active.id, action))).toBe("No es tu turno")
		expect(Engine.legalActions(s, active.id)).toEqual({})

		-- Un jugador activo tampoco puede actuar como espectro si la fase fuera suya.
		s.phase = "GhostTurn"
		s.turnIndex = 1
		expect(rejected(Comeback.ghostAct(s, active.id, { kind = "Sabotage" }))).toBe(
			"Solo un espectro puede actuar en el turno de espectro"
		)
	end)

	it("rechaza GhostAct fuera de la fase del espectro", function()
		local s = Fixtures.game({ players = 3 })
		local ghost = s.players[2]
		ghost.status = "Ghost"
		local before = deepCopy(s)
		local action: Types.Action = { type = "GhostAct", kind = "Sabotage" }
		expect(rejected(Engine.apply(s, ghost.id, action))).toBe("No se puede GhostAct en la fase AwaitRoll")
		expect(deepCopy(s)).toEqual(before)
	end)

	it("el reloj cierra el turno sin actuar", function()
		local s = Fixtures.game({ players = 3 })
		local ghost = s.players[2]
		ghost.status = "Ghost"
		enterGhostTurn(s, ghost.id)
		local hand = table.clone(ghost.hand)

		local events = Engine.timeout(s)
		expect(s.phase).toBe("AwaitRoll")
		expect(s.players[s.turnIndex].id ~= ghost.id).toBe(true)
		expect(ghost.sabotages).toBe(0)
		expect(ghost.hand).toEqual(hand)
		expect(countOf(events, "GhostActed")).toBe(0)
		expect(countOf(events, "GhostResurrected")).toBe(0)
	end)

	it("el reloj resucita a un espectro que ya acumuló el umbral", function()
		local s = Fixtures.game({ players = 3 })
		local ghost = s.players[2]
		ghost.status = "Ghost"
		ghost.cash = 0
		ghost.position = 5
		ghost.sabotages = Economy.ghost.sabotagesToRevive
		enterGhostTurn(s, ghost.id)

		local events = Engine.timeout(s)
		expect(ghost.status).toBe("Active")
		expect(ghost.cash).toBe(Economy.ghost.reviveCash)
		expect(ghost.position).toBe(1)
		expect(ghost.sabotages).toBe(0)
		expect(countOf(events, "GhostResurrected")).toBe(1)
		-- R-P48: el reloj no actúa, solo resucita y cierra el turno.
		expect(countOf(events, "GhostActed")).toBe(0)
		expect(s.phase).toBe("AwaitRoll")
		expect(inTurn(s).status).toBe("Active")
		expect(inTurn(s).id ~= ghost.id).toBe(true)
	end)

	it("un jugador que abandonó no recibe el turno de espectro", function()
		local s = Fixtures.game({ players = 4 })
		local first = s.players[1]
		local left = s.players[2]
		local ghost = s.players[3]
		local last = s.players[4]
		left.status = "Left"
		ghost.status = "Ghost"
		Fixtures.turnOf(s, first.id)

		Turn.next(s)
		expect(s.players[s.turnIndex].id).toBe(ghost.id)
		expect(s.phase).toBe("GhostTurn")
		expect(last.status).toBe("Active")
		expect(Engine.legalActions(s, left.id)).toEqual({})
		expect(Bot.choose(s, left.id)).toBe(nil)
	end)

	it("vuelve a GhostTurn si el borrador de perks se cierra en el turno del espectro", function()
		local s = Fixtures.game({ players = 4 })
		local ghost = s.players[1]
		ghost.status = "Ghost"
		-- La ronda 7 abre el segundo borrador con 4 jugadores (floor(20 / 3) + 1). El espectro
		-- es el jugador en turno al empezar la ronda, así que el borrador se resuelve antes que
		-- su turno corto.
		Fixtures.turnOf(s, s.players[#s.players].id)
		s.round = 6
		Turn.next(s)
		expect(s.round).toBe(7)
		expect(s.phase).toBe("PerkDraft")
		expect(s.players[s.turnIndex].id).toBe(ghost.id)

		local guard = 0
		while s.phase == "PerkDraft" do
			guard += 1
			if guard > #s.players + 1 then
				error("el borrador de perks no cerró", 2)
			end
			Engine.timeout(s)
		end
		expect(s.phase).toBe("GhostTurn")
		expect(Engine.legalActions(s, ghost.id)[1]).toEqual({ type = "GhostAct", kind = "Sabotage" })
	end)
end)

describe("sabotaje", function()
	it("roba una carta entre Fine, Shove y Demolition", function()
		local s = Fixtures.game({ players = 3 })
		local ghost = s.players[2]
		ghost.status = "Ghost"
		enterGhostTurn(s, ghost.id)

		local result = Engine.apply(s, ghost.id, { type = "GhostAct", kind = "Sabotage" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(#ghost.hand).toBe(1)
		expect(isSabotageCard(ghost.hand[1])).toBe(true)
		expect(countOf(result.events, "GhostActed")).toBe(1)
		expect(eventOf(result.events, "GhostActed")).toEqual({
			type = "GhostActed",
			playerId = ghost.id,
			kind = "Sabotage",
		})
	end)

	it("cuenta el sabotaje aunque la mano esté llena", function()
		local s = Fixtures.game({ players = 3 })
		local ghost = s.players[2]
		ghost.status = "Ghost"
		-- La mano del espectro no juega cartas, pero el robo respeta el límite de la mano.
		table.insert(ghost.hand, "Fine")
		table.insert(ghost.hand, "Shove")
		table.insert(ghost.hand, "Demolition")
		enterGhostTurn(s, ghost.id)

		local result = Engine.apply(s, ghost.id, { type = "GhostAct", kind = "Sabotage" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(countOf(result.events, "CardDiscarded")).toBe(1)
		expect(#ghost.hand).toBe(3)
		-- El contador acumula sabotajes (R-P49), no solo acciones: la resurrección avanza.
		expect(ghost.sabotages).toBe(1)
	end)

	it("con tres sabotajes resucita en la misma acción con 500 en la casilla 1", function()
		local s = Fixtures.game({ players = 3 })
		local ghost = s.players[2]
		ghost.status = "Ghost"
		ghost.cash = 0
		ghost.position = 9

		for step = 1, Economy.ghost.sabotagesToRevive do
			enterGhostTurn(s, ghost.id)
			local result = Engine.apply(s, ghost.id, { type = "GhostAct", kind = "Sabotage" })
			if not result.ok then
				error(result.error, 2)
			end
			expect(eventOf(result.events, "GhostActed").kind).toBe("Sabotage")
			-- Una sola acción: el turno sigue en un jugador activo.
			expect(s.phase).toBe("AwaitRoll")
			expect(inTurn(s).status).toBe("Active")
			expect(inTurn(s).id ~= ghost.id).toBe(true)
			-- El contador se reinicia justo al resucitar, en el tercer paso.
			expect(ghost.sabotages).toBe(step % Economy.ghost.sabotagesToRevive)
			if step < Economy.ghost.sabotagesToRevive then
				-- R-P48: la resurrección no espera al turno siguiente.
				expect(ghost.status).toBe("Ghost")
				expect(countOf(result.events, "GhostResurrected")).toBe(0)
			else
				expect(ghost.status).toBe("Active")
				expect(countOf(result.events, "GhostResurrected")).toBe(1)
				expect(eventOf(result.events, "GhostResurrected")).toEqual({
					type = "GhostResurrected",
					playerId = ghost.id,
					cash = Economy.ghost.reviveCash,
				})
				-- R-P48: el sabotaje se anuncia antes que la resurrección, en la misma acción.
				local actedAt, revivedAt = 0, 0
				for index, event in result.events do
					if event.type == "GhostActed" then
						actedAt = index
					elseif event.type == "GhostResurrected" then
						revivedAt = index
					end
				end
				expect(actedAt > 0 and actedAt < revivedAt).toBe(true)
			end
		end
		expect(ghost.status).toBe("Active")
		expect(ghost.cash).toBe(Economy.ghost.reviveCash)
		expect(ghost.position).toBe(1)
		expect(ghost.sabotages).toBe(0)
		expect(#ghost.hand).toBe(Economy.ghost.sabotagesToRevive)
		expect(s.phase).toBe("AwaitRoll")
		expect(inTurn(s).status).toBe("Active")
		expect(inTurn(s).id ~= ghost.id).toBe(true)
		-- La partida sigue: hay tres activos.
		expect(s.phase ~= "GameOver").toBe(true)

		-- Las rondas de espectro quedan contadas para los premios (Task 10): la resurrección
		-- ocurre en el tercer turno de espectro.
		local stats = s.stats[ghost.id]
		expect(stats.ghostRounds).toBe(Economy.ghost.sabotagesToRevive)
		expect(stats.comebackRounds).toBe(Economy.ghost.sabotagesToRevive)
	end)
end)

describe("embrujo", function()
	it("deja la propiedad sin renta durante una ronda y la devuelve después", function()
		local s = Fixtures.game({ players = 3 })
		local owner = s.players[1]
		local ghost = s.players[2]
		local payer = s.players[3]
		ghost.status = "Ghost"
		local index = propertyIndices(s)[1]
		Fixtures.give(s, owner.id, index)
		enterGhostTurn(s, ghost.id)
		local round = s.round

		local result = Engine.apply(s, ghost.id, { type = "GhostAct", kind = "Haunt", index = index })
		if not result.ok then
			error(result.error, 2)
		end
		local acted = eventOf(result.events, "GhostActed")
		expect(acted.playerId).toBe(ghost.id)
		expect(acted.kind).toBe("Haunt")
		expect(acted.index).toBe(index)
		expect(#s.modifiers).toBe(1)
		expect(s.modifiers[1].kind).toBe("Haunt")
		expect(s.modifiers[1].index).toBe(index)
		expect(s.modifiers[1].untilRound).toBe(round)
		-- También es una sola acción: el turno termina.
		expect(s.phase).toBe("AwaitRoll")

		-- Esta ronda la casilla no cobra ni emite RentPaid.
		expect(Property.rentFor(s, index)).toBe(0)
		local cash = payer.cash
		expect(Property.payRent(s, payer.id, index)).toEqual({})
		expect(payer.cash).toBe(cash)
		expect(payer.fury).toBe(0)

		-- La ronda siguiente el embrujo ya caducó.
		s.round = round + 1
		expect(Property.rentFor(s, index) > 0).toBe(true)
		local events = Property.payRent(s, payer.id, index)
		expect(countOf(events, "RentPaid")).toBe(1)
		expect(payer.cash < cash).toBe(true)
	end)

	it("rechaza una casilla que no es propiedad, una sin dueño o la propia", function()
		local s = Fixtures.game({ players = 3 })
		local ghost = s.players[2]
		ghost.status = "Ghost"
		local indices = propertyIndices(s)
		local own, unowned = indices[1], indices[2]
		Fixtures.give(s, ghost.id, own)
		enterGhostTurn(s, ghost.id)
		local before = deepCopy(s)

		local function haunt(index: any): Types.ApplyResult
			return Comeback.ghostAct(s, ghost.id, { kind = "Haunt", index = index })
		end

		expect(rejected(haunt(Fixtures.squareOf(s, "Start")))).toBe("La casilla indicada no es una propiedad")
		expect(rejected(haunt(unowned))).toBe("La propiedad no tiene dueño")
		expect(rejected(haunt(own))).toBe("No puedes embrujar tu propia propiedad")
		expect(rejected(haunt(nil))).toBe("El embrujo necesita el índice de una propiedad")
		expect(rejected(haunt(2.5))).toBe("El embrujo necesita el índice de una propiedad")
		-- La acción llega de fuera del tipo: se comprueba el dato aunque el tipo sea una unión.
		local bogus: any = { kind = "Bogus" }
		expect(rejected(Comeback.ghostAct(s, ghost.id, bogus))).toBe("Acción de espectro desconocida: Bogus")
		expect(deepCopy(s)).toEqual(before)
	end)

	it("una renta embrujada no llena la Furia", function()
		local s = Fixtures.game({ players = 3 })
		local owner = s.players[1]
		local ghost = s.players[2]
		local payer = s.players[3]
		ghost.status = "Ghost"
		local index = propertyIndices(s)[1]
		Fixtures.give(s, owner.id, index)
		enterGhostTurn(s, ghost.id)
		local result = Engine.apply(s, ghost.id, { type = "GhostAct", kind = "Haunt", index = index })
		if not result.ok then
			error(result.error, 2)
		end
		payer.fury = Economy.furyThreshold - 1

		local events = Property.payRent(s, payer.id, index)
		expect(events).toEqual({})
		expect(payer.fury).toBe(Economy.furyThreshold - 1)
	end)
end)

describe("legalActions y Bot en GhostTurn", function()
	it("solo ofrecen acciones que apply acepta", function()
		local s = Fixtures.game({ players = 3 })
		local ghost = s.players[2]
		ghost.status = "Ghost"
		local index = propertyIndices(s)[1]
		Fixtures.give(s, s.players[1].id, index)
		enterGhostTurn(s, ghost.id)

		local actions = Engine.legalActions(s, ghost.id)
		expect(actions[1]).toEqual({ type = "GhostAct", kind = "Sabotage" })
		expect(#actions).toBe(2)
		expect(actions[2]).toEqual({ type = "GhostAct", kind = "Haunt", index = index })
		for _, action in actions do
			expect(action.type).toBe("GhostAct")
			local copy = deepCopy(s)
			expect(Engine.apply(copy, ghost.id, action).ok).toBe(true)
		end

		local choice = Bot.choose(s, ghost.id)
		if not choice then
			error("el bot debe elegir una acción de espectro", 2)
		end
		expect(choice.type).toBe("GhostAct")
		expect(choice.kind).toBe("Sabotage")
		local copy = deepCopy(s)
		expect(Engine.apply(copy, ghost.id, choice).ok).toBe(true)
	end)
end)

describe("Alma en Pena (R-P6)", function()
	it("da 2 cartas de sabotaje y suma 2 al contador cuando se arruina", function()
		local s = Fixtures.game({ players = 3 })
		local fallen = s.players[2]
		local creditor = s.players[1]
		table.insert(fallen.perks, "RestlessSoul")
		fallen.cash = 0

		local events = Bankruptcy.charge(s, fallen.id, 500, creditor.id)
		expect(fallen.status).toBe("Ghost")
		expect(#fallen.hand).toBe(2)
		for _, cardId in fallen.hand do
			expect(isSabotageCard(cardId)).toBe(true)
		end
		expect(countOf(events, "CardDrawn")).toBe(2)
		-- R-P49: las cartas del perk son sabotajes acumulados y acercan la resurrección.
		expect(fallen.sabotages).toBe(Economy.perks.restlessSoulCards)
	end)

	it("con Alma en Pena, un sabotaje más resucita", function()
		local s = Fixtures.game({ players = 3 })
		local fallen = s.players[2]
		local creditor = s.players[1]
		table.insert(fallen.perks, "RestlessSoul")
		fallen.cash = 0
		Bankruptcy.charge(s, fallen.id, 500, creditor.id)
		expect(fallen.status).toBe("Ghost")
		expect(fallen.sabotages).toBe(Economy.perks.restlessSoulCards)

		-- R-P48: la siguiente acción suma el tercer sabotaje y resucita en el acto.
		enterGhostTurn(s, fallen.id)
		local result = Engine.apply(s, fallen.id, { type = "GhostAct", kind = "Sabotage" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(fallen.status).toBe("Active")
		expect(fallen.cash).toBe(Economy.ghost.reviveCash)
		expect(fallen.position).toBe(1)
		expect(fallen.sabotages).toBe(0)
		expect(countOf(result.events, "GhostResurrected")).toBe(1)
	end)

	it("sin el perk el espectro no empieza con cartas", function()
		local s = Fixtures.game({ players = 3 })
		local fallen = s.players[2]
		local creditor = s.players[1]
		fallen.cash = 0

		local events = Bankruptcy.charge(s, fallen.id, 500, creditor.id)
		expect(fallen.status).toBe("Ghost")
		expect(fallen.hand).toEqual({})
		expect(countOf(events, "CardDrawn")).toBe(0)
		expect(fallen.sabotages).toBe(0)
	end)
end)

describe("resurrección con la partida terminada", function()
	it("no resucita ni toca el estado si la partida ya acabó", function()
		local s = Fixtures.game({ players = 3 })
		local ghost = s.players[2]
		ghost.status = "Ghost"
		ghost.sabotages = Economy.ghost.sabotagesToRevive
		s.phase = "GameOver"
		local before = deepCopy(s)

		local result = Comeback.ghostAct(s, ghost.id, { kind = "Sabotage" })
		expect(rejected(result)).toBe("La partida ha terminado")
		expect(deepCopy(s)).toEqual(before)
		expect(ghost.status).toBe("Ghost")
	end)
end)

--!strict
-- Pruebas del reloj de escenas, del mapa de duraciones y del estado puro de la partida. Todo se
-- ejecuta con Lune: ni Scenes, ni SceneClock, ni MatchState usan game, task ni ningún reloj; el
-- instante llega por parámetro (R-P5 y R-P20). La numeración de lotes, los vencimientos, las
-- observaciones y el filtrado por jugador se prueban aquí porque MatchService, que sí es de
-- Roblox, solo los envuelve.
local Cards = require("../../src/shared/config/Cards")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Harness = require("../harness")
local MatchState = require("../../src/server/match/MatchState")
local Scenes = require("../../src/shared/config/Scenes")
local SceneClock = require("../../src/server/match/SceneClock")
local Score = require("../../src/shared/rules/Score")
local Types = require("../../src/shared/rules/Types")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

-- Plazo común de decisión: sale de la configuración, no se copia aquí.
local DECISION = Economy.seconds.decision

type Event = Types.Event
type GameState = Types.GameState
type Phase = Types.Phase

-- Lista literal de «Eventos» de docs/01-arquitectura/arquitectura.md. Se escribe a mano a
-- propósito: si la arquitectura cambia, esta prueba obliga a revisar Scenes. La sección lista 33
-- tipos de evento; las cinco legendarias se anuncian con su id (CardPlayed + cardId), así que los
-- nombres con escena son 38: los 33 eventos y las 5 cartas legendarias.
local ARCHITECTURE_EVENTS: { string } = {
	"RoundStarted",
	"FinalRoundsStarted",
	"PerkDrafted",
	"DiceRolled",
	"TokenMoved",
	"PassedStart",
	"PropertyBought",
	"RentPaid",
	"AuctionStarted",
	"AuctionWon",
	"AuctionNoSale",
	"BuildingChanged",
	"TradeCompleted",
	"PlayerArrested",
	"TribunalVerdict",
	"BankruptcyDeclared",
	"GhostActed",
	"GhostResurrected",
	"CardDrawn",
	"CardDiscarded",
	"CardPlayed",
	"CardBlocked",
	"HotZoneMoved",
	"BillboardResult",
	"DuelResolved",
	"PortalUsed",
	"MarketBought",
	"PactFormed",
	"PactEnded",
	"PactBroken",
	"CrownMoved",
	"FuryFilled",
	"GameEnded",
}

local LEGENDARY_CARDS: { string } = { "Hurricane", "WorldFlip", "Revolution", "Earthquake", "CrownStrike" }

local function baseDuration(eventType: string): number
	local duration = Scenes.baseDuration(eventType)
	if duration == nil then
		error(`Scenes no da escena al evento {eventType}`, 2)
	end
	return duration
end

local function cardEvent(cardId: string): Event
	return { type = "CardPlayed", cardId = cardId }
end

local function stepOf(
	match: MatchState.MatchState,
	state: GameState,
	events: { Event },
	now: number,
	endedTurn: boolean
): MatchState.Step
	local step = MatchState.step(match, state, events, now, endedTurn)
	if not step then
		error("el paso no debía estar cerrado", 2)
	end
	return step
end

describe("Scenes", function()
	it("da escena a los 33 eventos de la arquitectura y a las 5 legendarias", function()
		expect(#ARCHITECTURE_EVENTS).toBe(33)
		expect(#LEGENDARY_CARDS).toBe(5)
		for _, eventType in ARCHITECTURE_EVENTS do
			expect(baseDuration(eventType) > 0).toBeTruthy()
		end
		for _, cardId in LEGENDARY_CARDS do
			expect(Scenes.durationFor(cardEvent(cardId), 0) > 0).toBeTruthy()
		end
	end)

	it("las escenas comunes duran entre 2 y 4 segundos", function()
		for _, eventType in ARCHITECTURE_EVENTS do
			-- Excepciones: la detención lleva la llegada, los policías y la vuelta al mapa (15 s), y el
			-- Portal cruza la ciudad con la cámara (2026-11-05, más lento a petición del responsable).
			if eventType ~= "PlayerArrested" and eventType ~= "PortalUsed" then
				local duration = baseDuration(eventType)
				expect(duration >= 2 and duration <= 4).toBeTruthy()
			end
		end
	end)

	it("la detención dura 15 segundos: llegada, policías y vuelta al mapa", function()
		expect(baseDuration("PlayerArrested")).toBe(15)
	end)

	it("cada evento dura algo, también repetido", function()
		for _, eventType in ARCHITECTURE_EVENTS do
			for _, seen in { 0, 1, 3, 10, 100 } do
				expect(Scenes.durationFor({ type = eventType }, seen) > 0).toBeTruthy()
			end
		end
	end)

	it("acorta una escena ya vista", function()
		expect(
			Scenes.durationFor({ type = "BuildingChanged" }, 3)
				< Scenes.durationFor({ type = "BuildingChanged" }, 0)
		).toBeTruthy()
	end)

	it("acorta las escenas repetidas, salvo la detención y el Portal", function()
		for _, eventType in ARCHITECTURE_EVENTS do
			if eventType ~= "PlayerArrested" and eventType ~= "PortalUsed" then
				local fresh = Scenes.durationFor({ type = eventType }, 0)
				expect(Scenes.durationFor({ type = eventType }, 1) < fresh).toBeTruthy()
				expect(Scenes.durationFor({ type = eventType }, 3) < fresh).toBeTruthy()
			end
		end
	end)

	it("la detención no se acorta al repetirse", function()
		expect(Scenes.durationFor({ type = "PlayerArrested" }, 5)).toBe(15)
	end)

	-- Medido en partida (2026-11-04): con la duración fija y el acortado, seis casillas se cruzaban en
	-- un segundo y la cámara no llegaba a acercarse a la ficha.
	describe("recorrido de una ficha", function()
		local function ride(squares: number, seen: number): number
			local path = {}
			for square = 1, squares do
				path[square] = square
			end
			return Scenes.durationFor({ type = "TokenMoved", path = path } :: any, seen)
		end

		it("no se acorta al repetirse", function()
			expect(ride(7, 0)).toBe(ride(7, 50))
		end)

		it("dura más cuantas más casillas recorre", function()
			expect(ride(9, 0) > ride(5, 0)).toBeTruthy()
		end)

		it("nunca pasa del tope ni baja del mínimo", function()
			expect(ride(40, 0)).toBe(Scenes.maxRideSec)
			expect(ride(1, 0)).toBe(Scenes.minRideSec)
		end)

		it("un salto sin ruta no es un recorrido y sigue acortándose", function()
			local jump: any = { type = "TokenMoved", path = {} }
			expect(Scenes.durationFor(jump, 3) < Scenes.durationFor(jump, 0)).toBeTruthy()
		end)
	end)

	it("en una subasta el bot da tiempo a responder", function()
		expect(Scenes.botDelayFor("Auction") > Scenes.botDelayFor("AwaitRoll")).toBeTruthy()
		expect(Scenes.botDelayFor("AwaitRoll")).toBe(Scenes.botDelaySec)
	end)

	it("ninguna legendaria supera 10 s", function()
		for _, cardId in { "Hurricane", "WorldFlip", "Revolution", "Earthquake", "CrownStrike" } do
			expect(Scenes.durationFor(cardEvent(cardId), 0) <= 10).toBeTruthy()
		end
	end)

	it("respeta la rareza de todas las cartas", function()
		for _, card in Cards.all do
			local duration = Scenes.durationFor(cardEvent(card.id), 0)
			expect(duration > 0).toBeTruthy()
			if card.rarity == "Legendary" then
				expect(duration <= 10).toBeTruthy()
			elseif card.rarity == "Rare" then
				expect(duration <= 6).toBeTruthy()
			else
				expect(duration >= 2 and duration <= 4).toBeTruthy()
			end
		end
	end)

	it("una carta desconocida también tiene escena", function()
		expect(Scenes.durationFor({ type = "CardPlayed", cardId = "NoExiste" }, 0) > 0).toBeTruthy()
		expect(Scenes.durationFor({ type = "CardPlayed" }, 0) > 0).toBeTruthy()
	end)

	it("traduce cada fase a su tiempo de decisión", function()
		local decisions: { { phase: Phase, seconds: number } } = {
			{ phase = "Auction", seconds = Economy.seconds.auction },
			{ phase = "Tribunal", seconds = Economy.seconds.tribunalVote },
			{ phase = "Reaction", seconds = Economy.seconds.reaction },
			{ phase = "GameOver", seconds = 0 },
			{ phase = "PerkDraft", seconds = Economy.seconds.decision },
			{ phase = "AwaitRoll", seconds = Economy.seconds.decision },
			{ phase = "AwaitBuy", seconds = Economy.seconds.decision },
			{ phase = "AwaitEnd", seconds = Economy.seconds.decision },
			{ phase = "Duel", seconds = Economy.seconds.decision },
			{ phase = "Market", seconds = Economy.seconds.decision },
			{ phase = "GhostTurn", seconds = Economy.seconds.decision },
		}
		for _, decision in decisions do
			expect(Scenes.decisionSeconds(decision.phase)).toBe(decision.seconds)
		end
	end)
end)

describe("SceneClock", function()
	it("encadena escenas", function()
		local clock = SceneClock.new()
		local endsAt =
			SceneClock.schedule(clock, { { type = "DiceRolled" }, { type = "TokenMoved", path = {} } }, 100)
		expect(endsAt > 100).toBeTruthy()
	end)

	it("suma las duraciones en orden desde el instante recibido", function()
		local clock = SceneClock.new()
		local events: { Event } = { { type = "DiceRolled" }, { type = "TokenMoved", path = {} } }
		local expected = 100 + Scenes.durationFor(events[1], 0) + Scenes.durationFor(events[2], 0)
		expect(SceneClock.schedule(clock, events, 100)).toBe(expected)
		expect(clock.endsAt).toBe(expected)
	end)

	it("sin eventos termina en el instante recibido", function()
		local clock = SceneClock.new()
		expect(SceneClock.schedule(clock, {}, 42)).toBe(42)
	end)

	it("acorta las repeticiones del mismo tipo de evento", function()
		local clock = SceneClock.new()
		-- Cada lote llega cuando el anterior ya acabó: se mide solo lo que dura la escena.
		local first = SceneClock.schedule(clock, { { type = "DiceRolled" } }, 0)
		local second = SceneClock.schedule(clock, { { type = "DiceRolled" } }, 100) - 100
		local third = SceneClock.schedule(clock, { { type = "DiceRolled" } }, 200) - 200
		expect(second < first).toBeTruthy()
		expect(third <= second).toBeTruthy()
	end)

	it("un lote que llega durante una escena empieza cuando esta acaba", function()
		local clock = SceneClock.new()
		-- Huracán dura 10 s y un dado recién visto, 2 s.
		expect(SceneClock.schedule(clock, { cardEvent("Hurricane") }, 100)).toBe(110)
		expect(SceneClock.schedule(clock, { { type = "DiceRolled" } }, 101)).toBe(112)
	end)

	it("un lote sin eventos no adelanta el final de la escena en curso", function()
		local clock = SceneClock.new()
		SceneClock.schedule(clock, { cardEvent("Hurricane") }, 100)
		expect(SceneClock.schedule(clock, {}, 101)).toBe(110)
		expect(clock.endsAt).toBe(110)
	end)

	it("programa cada lote desde su propio instante", function()
		local clock = SceneClock.new()
		SceneClock.schedule(clock, { { type = "DiceRolled" } }, 100)
		local endsAt = SceneClock.schedule(clock, { { type = "TokenMoved", path = {} } }, 200)
		expect(endsAt > 200).toBeTruthy()
	end)
end)

describe("MatchState", function()
	it("empieza en seq 0 y con el plazo de la fase inicial", function()
		local state = Fixtures.game({ players = 2 })
		local match = MatchState.begin(500, state.phase)
		expect(match.seq).toBe(0)
		expect(match.observations.startedAt).toBe(500)
		expect(match.observations.endedAt == nil).toBeTruthy()
		expect(match.observations.turns).toBe(0)
		expect(match.observations.sceneSec).toBe(0)
		expect(match.decisionDeadline).toBe(500 + Scenes.decisionSeconds(state.phase))
		expect(MatchState.over(match)).toBe(false)
	end)

	it("numera los lotes de uno en uno y arranca la decisión al acabar la escena", function()
		local state = Fixtures.game({ players = 2 })
		local match = MatchState.begin(100, state.phase)
		local events: { Event } = { { type = "DiceRolled" } }
		local step = stepOf(match, state, events, 110, false)
		local sceneEndsAt = 110 + Scenes.durationFor(events[1], 0)
		expect(step.seq).toBe(1)
		expect(step.startsAt).toBe(110)
		expect(step.sceneEndsAt).toBe(sceneEndsAt)
		expect(step.decisionDeadline).toBe(sceneEndsAt + Scenes.decisionSeconds(state.phase))
		expect(match.observations.sceneSec).toBe(Scenes.durationFor(events[1], 0))
	end)

	-- R-P40: el plazo solo vuelve a empezar con una decisión nueva.
	it("proponer en bucle no alarga el plazo del turno", function()
		local state = Fixtures.game({ players = 3 })
		local match = MatchState.begin(0, state.phase, MatchState.decisionKey(state))
		expect(stepOf(match, state, {}, 19, false).decisionDeadline).toBe(DECISION)
		expect(stepOf(match, state, {}, 19.5, false).decisionDeadline).toBe(DECISION)
	end)

	it("cada puja deja el cierre de la subasta donde estaba", function()
		local state = Fixtures.game({ players = 3 })
		state.phase = "Auction"
		local match = MatchState.begin(0, state.phase, MatchState.decisionKey(state))
		expect(stepOf(match, state, {}, 14, false).decisionDeadline).toBe(15)
	end)

	it("una escena dentro de la misma decisión solo suma lo que dura", function()
		local state = Fixtures.game({ players = 3 })
		local match = MatchState.begin(0, state.phase, MatchState.decisionKey(state))
		-- Un dado recién visto dura 2 s: al acabar la escena al jugador le queda lo mismo que antes.
		local step = stepOf(match, state, { { type = "DiceRolled" } }, 5, false)
		expect(step.sceneEndsAt).toBe(7)
		expect(step.decisionDeadline).toBe(DECISION + 2)
	end)

	it("una decisión nueva da el plazo completo al acabar la escena", function()
		local state = Fixtures.game({ players = 3 })
		local match = MatchState.begin(0, state.phase, MatchState.decisionKey(state))
		state.phase = "AwaitEnd"
		local step = stepOf(match, state, { { type = "DiceRolled" } }, 5, false)
		expect(step.decisionDeadline).toBe(7 + DECISION)
	end)

	it("cambiar de turno da el plazo completo aunque no haya eventos", function()
		local state = Fixtures.game({ players = 3 })
		local match = MatchState.begin(0, state.phase, MatchState.decisionKey(state))
		state.turnIndex = state.turnIndex % 3 + 1
		expect(stepOf(match, state, {}, 5, false).decisionDeadline).toBe(5 + DECISION)
	end)

	it("elegir rival en el Duelo da su plazo a la jugada", function()
		local state = Fixtures.game({ players = 3 })
		state.phase = "Duel"
		local pending = state.pending :: any
		pending.duel = { challengerId = state.players[1].id, picks = {}, round = 1 }
		local match = MatchState.begin(0, state.phase, MatchState.decisionKey(state))
		pending.duel.rivalId = state.players[2].id
		expect(stepOf(match, state, {}, 19, false).decisionDeadline).toBe(19 + DECISION)
		-- La jugada de un participante ya no reinicia nada.
		pending.duel.picks[state.players[1].id] = "Rock"
		expect(stepOf(match, state, {}, 30, false).decisionDeadline).toBe(19 + DECISION)
	end)

	it("cada elección del borrador da su plazo al siguiente", function()
		local state = Fixtures.game({ players = 3 })
		state.phase = "PerkDraft"
		local pending = state.pending :: any
		pending.draft =
			{ order = { state.players[1].id, state.players[2].id }, index = 1, offer = { "Banker" } }
		local match = MatchState.begin(0, state.phase, MatchState.decisionKey(state))
		pending.draft.index = 2
		expect(stepOf(match, state, {}, 10, false).decisionDeadline).toBe(10 + DECISION)
	end)

	-- R-P39: las escenas no se solapan.
	it("un lote durante una escena empieza al acabarla y sin eventos no la adelanta", function()
		local state = Fixtures.game({ players = 3 })
		local match = MatchState.begin(0, state.phase, MatchState.decisionKey(state))
		local huge = stepOf(match, state, { cardEvent("Hurricane") }, 100, false)
		expect(huge.startsAt).toBe(100)
		expect(huge.sceneEndsAt).toBe(110)
		local quiet = stepOf(match, state, {}, 101, false)
		expect(quiet.startsAt).toBe(110)
		expect(quiet.sceneEndsAt).toBe(110)
		expect(match.sceneEndsAt).toBe(110)
		expect(match.observations.sceneSec).toBe(10)
	end)

	it("descarta acciones de cliente hasta que acaba la escena, con margen", function()
		local state = Fixtures.game({ players = 3 })
		local match = MatchState.begin(0, state.phase, MatchState.decisionKey(state))
		stepOf(match, state, { cardEvent("Hurricane") }, 100, false)
		expect(MatchState.acceptsAction(match, 101)).toBe(false)
		expect(MatchState.acceptsAction(match, 110 - Scenes.actionGraceSec - 0.01)).toBe(false)
		expect(MatchState.acceptsAction(match, 110 - Scenes.actionGraceSec)).toBe(true)
		expect(MatchState.acceptsAction(match, 111)).toBe(true)
	end)

	it("el lote y el resync llevan el plazo vigente", function()
		local state = Fixtures.game({ players = 3 })
		local playerId = state.players[1].id
		local match = MatchState.begin(0, state.phase, MatchState.decisionKey(state))
		expect(MatchState.resync(match, state, playerId, 0).decisionDeadline).toBe(DECISION)
		state.phase = "AwaitEnd"
		local step = stepOf(match, state, { { type = "DiceRolled" } }, 5, false)
		expect(MatchState.batch(state, step, playerId).decisionDeadline).toBe(7 + DECISION)
		expect(MatchState.resync(match, state, playerId, 6).decisionDeadline).toBe(7 + DECISION)
	end)

	it("usa el plazo de la fase al cerrar la escena", function()
		local state = Fixtures.game({ players = 2 })
		state.phase = "Auction"
		local match = MatchState.begin(0, state.phase)
		local step = stepOf(match, state, { { type = "AuctionStarted" } }, 10, false)
		expect(step.decisionDeadline - step.sceneEndsAt).toBe(Economy.seconds.auction)
	end)

	it("crece de uno en uno y el resync no lo mueve", function()
		local state = Fixtures.game({ players = 2 })
		local match = MatchState.begin(0, state.phase)
		local playerId = state.players[1].id
		for turn = 1, 3 do
			local step = stepOf(match, state, { { type = "DiceRolled" } }, turn * 10, false)
			expect(step.seq).toBe(turn)
			local batch = MatchState.batch(state, step, playerId)
			expect(batch.seq).toBe(turn)
			expect(batch.startsAt).toBe(turn * 10)
			expect(batch.view.playerId).toBe(playerId)
		end
		local resync = MatchState.resync(match, state, playerId, 99)
		expect(resync.seq).toBe(3)
		expect(#resync.events).toBe(0)
		expect(resync.view.playerId).toBe(playerId)
		expect(match.seq).toBe(3)
	end)

	it("da el mismo seq a todos y filtra lo privado por jugador", function()
		local state = Fixtures.game({ players = 2 })
		local match = MatchState.begin(0, state.phase)
		local owner = state.players[1].id
		local other = state.players[2].id
		local step = stepOf(match, state, {
			{ type = "CardDrawn", playerId = owner, cardId = "Shield" },
		}, 10, false)
		local ownerBatch = MatchState.batch(state, step, owner)
		local otherBatch = MatchState.batch(state, step, other)
		expect(ownerBatch.seq).toBe(otherBatch.seq)
		expect(ownerBatch.view.playerId).toBe(owner)
		expect(otherBatch.view.playerId).toBe(other)
		expect(ownerBatch.events[1].cardId).toBe("Shield")
		expect(otherBatch.events[1].cardId == nil).toBeTruthy()
	end)

	it("acorta las escenas repetidas dentro de la partida", function()
		local state = Fixtures.game({ players = 2 })
		local match = MatchState.begin(0, state.phase)
		local first = stepOf(match, state, { { type = "DiceRolled" } }, 0, false)
		local second = stepOf(match, state, { { type = "DiceRolled" } }, 10, false)
		expect(second.sceneEndsAt - second.startsAt < first.sceneEndsAt - first.startsAt).toBeTruthy()
	end)

	it("cuenta los turnos, guarda al líder de cada ronda y acumula la escena", function()
		local state = Fixtures.game({ players = 2 })
		Fixtures.turnOf(state, state.players[2].id)
		state.phase = "AwaitEnd"
		local match = MatchState.begin(0, state.phase)
		local phaseBefore: Phase = state.phase
		local actor = state.players[2].id
		local result = Engine.apply(state, actor, { type = "EndTurn" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(state.round).toBe(2)
		stepOf(match, state, result.events, 10, MatchState.endsTurn("EndTurn", phaseBefore, false))
		expect(match.observations.turns).toBe(1)
		expect(match.observations.leaders[2]).toBe(Score.ranking(state)[1])
		expect(match.observations.sceneSec > 0).toBeTruthy()
	end)

	it("solo el reloj y las acciones que cierran turno cuentan como turno", function()
		expect(MatchState.endsTurn("EndTurn", "AwaitEnd", false)).toBe(true)
		expect(MatchState.endsTurn("GhostAct", "GhostTurn", false)).toBe(true)
		expect(MatchState.endsTurn("Roll", "AwaitRoll", false)).toBe(false)
		expect(MatchState.endsTurn(nil, "AwaitEnd", true)).toBe(true)
		expect(MatchState.endsTurn(nil, "GhostTurn", true)).toBe(true)
		expect(MatchState.endsTurn(nil, "AwaitRoll", true)).toBe(false)
		expect(MatchState.endsTurn(nil, "Auction", true)).toBe(false)
		expect(MatchState.endsTurn(nil, "AwaitEnd", false)).toBe(false)
	end)

	it("cierra las observaciones al llegar a GameOver y no admite otro paso", function()
		local state = Fixtures.game({ players = 2 })
		local match = MatchState.begin(0, state.phase)
		stepOf(match, state, { { type = "DiceRolled" } }, 5, false)
		state.phase = "GameOver"
		local final = stepOf(match, state, { { type = "GameEnded" } }, 25, false)
		expect(final.decisionDeadline).toBe(final.sceneEndsAt)
		expect(match.observations.endedAt).toBe(25)
		expect(MatchState.over(match)).toBe(true)
		expect(MatchState.step(match, state, { { type = "GameEnded" } }, 30, false) == nil).toBeTruthy()
	end)

	it("el abandono fija endedAt una sola vez", function()
		local match = MatchState.begin(0, "AwaitRoll")
		MatchState.abandon(match, 10)
		expect(match.observations.endedAt).toBe(10)
		MatchState.abandon(match, 20)
		expect(match.observations.endedAt).toBe(10)
		expect(MatchState.over(match)).toBe(true)
	end)

	it("limita el resync por partida y exige seguir en la mesa", function()
		local state = Fixtures.game({ players = 2 })
		local match = MatchState.begin(0, state.phase)
		local member = state.players[1].id
		for _ = 1, Economy.actionsPerSecond do
			expect(MatchState.acceptsResync(match, state, member, 100)).toBe(true)
		end
		-- La siguiente del mismo segundo se descarta sin construir la vista ni avisar.
		expect(MatchState.acceptsResync(match, state, member, 100)).toBe(false)
		-- Un jugador ajeno a la partida no pasa, ni siquiera con cupo libre.
		expect(MatchState.acceptsResync(match, state, "Fantasma", 200)).toBe(false)
		-- La ventana se desliza: al segundo siguiente vuelve a aceptarse.
		expect(MatchState.acceptsResync(match, state, member, 200)).toBe(true)
	end)

	it("decide si el reloj avanzó o hay que abandonar la partida", function()
		local state = Fixtures.game({ players = 2 })
		local before = MatchState.snapshot(state)
		-- Sin eventos y sin mover fase, ronda ni turno: el reloj no avanzó.
		expect(MatchState.timeoutAdvanced(state, before, {})).toBe(false)
		-- Con eventos, aunque la foto no cambie, el tic hizo algo.
		expect(MatchState.timeoutAdvanced(state, before, { { type = "DiceRolled" } })).toBe(true)
		-- Cambiar de fase, de turno o de ronda también es avanzar.
		state.phase = "AwaitEnd"
		expect(MatchState.timeoutAdvanced(state, before, {})).toBe(true)
		before = MatchState.snapshot(state)
		state.turnIndex = 2
		expect(MatchState.timeoutAdvanced(state, before, {})).toBe(true)
		before = MatchState.snapshot(state)
		state.round = 3
		expect(MatchState.timeoutAdvanced(state, before, {})).toBe(true)
	end)

	it("atribuye el vencimiento al jugador que decide en la fase", function()
		local state = Fixtures.game({ players = 3 })
		-- En las fases de turno decide el jugador en turno.
		expect(MatchState.decidingPlayer(state)).toBe(state.players[state.turnIndex].id)
		local pending = state.pending
		if not pending then
			error("el estado de la prueba no tiene pending", 2)
		end
		-- En el borrador decide a quien le toca elegir, que no es el jugador en turno.
		state.phase = "PerkDraft"
		pending.draft = {
			order = { state.players[2].id, state.players[1].id },
			index = 1,
			offer = { "Banker" },
		}
		expect(MatchState.decidingPlayer(state)).toBe(state.players[2].id)
		pending.draft = nil
		-- En la ventana de reacción contesta el elegido por la carta o la renta, no el del turno.
		state.phase = "Reaction"
		pending.reaction = { eligibleId = state.players[3].id }
		expect(MatchState.decidingPlayer(state)).toBe(state.players[3].id)
		pending.reaction = nil
		-- Sin decisión pendiente no hay a quién atribuir el vencimiento.
		state.phase = "GameOver"
		expect(MatchState.decidingPlayer(state) == nil).toBeTruthy()
	end)

	it("cambia el control de bot en un solo sitio y lo registra", function()
		local state = Fixtures.game({ players = 2 })
		local match = MatchState.begin(0, state.phase)
		local player = state.players[1]
		expect(MatchState.setBotControlled(match, state, player.id, true)).toBe(true)
		expect(player.isBot).toBe(true)
		expect(match.bots[player.id]).toBe(true)
		expect(MatchState.setBotControlled(match, state, player.id, false)).toBe(true)
		expect(player.isBot).toBe(false)
		expect(match.bots[player.id]).toBe(false)
		expect(MatchState.setBotControlled(match, state, "Fantasma", true)).toBe(false)
	end)
end)

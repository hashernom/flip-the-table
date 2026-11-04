--!nocheck
-- Sonda de la segunda pasada: reproduce cada hallazgo con el código real. No modifica el repositorio.
-- Uso: lune run auditoria/sondas/hallazgos
local ActionMenuRules = require("../../src/client/ui/ActionMenuRules")
local Bankruptcy = require("../../src/shared/rules/Bankruptcy")
local Deck = require("../../src/shared/rules/Deck")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local EventQueue = require("../../src/client/state/EventQueue")
local Fixtures = require("../../tests/fixtures")
local MatchState = require("../../src/server/match/MatchState")
local Property = require("../../src/shared/rules/Property")
local Protocol = require("../../src/shared/net/Protocol")
local Scenes = require("../../src/shared/config/Scenes")
local SceneClock = require("../../src/server/match/SceneClock")
local SceneDirector = require("../../src/client/scenes/SceneDirector")
local Squares = require("../../src/shared/rules/Squares")
local State = require("../../src/shared/rules/State")
local View = require("../../src/shared/rules/View")

local function title(text)
	print(`\n=== {text}`)
end

local function labels(legal)
	local out = {}
	for _, button in ActionMenuRules.buttonsFor(legal) do
		table.insert(out, button.label)
	end
	return table.concat(out, " | ")
end

local function playerOf(state, id)
	for _, player in state.players do
		if player.id == id then
			return player
		end
	end
end

local function apply(state, id, action)
	local result = Engine.apply(state, id, action)
	if not result.ok then
		error(`rechazada {action.type}: {result.error}`, 2)
	end
	return result.events
end

-- ---------------------------------------------------------------- Cliente
title("C1. Reloj: el servidor usa time() y el cliente GetServerTimeNow()")
do
	-- MatchService pasa time() (segundos desde que arrancó el servidor) como startsAt;
	-- main.client compara con Workspace:GetServerTimeNow() (segundos de época).
	local serverTime = 300 -- time() a los 5 min de servidor
	local clientNow = 1793750400 -- GetServerTimeNow() en noviembre de 2026
	local q = EventQueue.new()
	EventQueue.push(q, { seq = 1, startsAt = serverTime, events = { { type = "CardPlayed", cardId = "Hurricane" } } })
	local due = EventQueue.nextDue(q, clientNow)
	local behind = EventQueue.behindSec(due, clientNow)
	local waited = 0
	local director = SceneDirector.new({
		wait = function(seconds)
			waited += seconds
		end,
	})
	SceneDirector.play(director, due, behind)
	print(`behindSec = {behind}; duración real de Huracán = {Scenes.durationFor(due.events[1], 0)} s; el cliente espera {waited} s`)
end

title("C2. Revancha: la cola del cliente tras una partida con lotes")
do
	local q = EventQueue.new()
	for seq = 1, 5 do
		EventQueue.push(q, { seq = seq, startsAt = 0, events = {} })
		EventQueue.nextDue(q, 1)
	end
	EventQueue.resync(q, { round = 1 }, 0) -- lote seq = 0 de la partida nueva (main.client:344)
	print(`lastSeq tras la vista inicial de la revancha = {q.lastSeq}`)
	for seq = 1, 6 do
		print(`  lote {seq} de la revancha -> {EventQueue.push(q, { seq = seq, startsAt = 0, events = {} })}`)
	end
end

title("C3. Perks: menú y etiquetas con el borrador real")
do
	local state = State.create({ playerIds = { "A", "B", "C", "D" }, seed = 5 })
	local drafter = state.pending.draft.order[1]
	local view = View.forPlayer(state, drafter)
	print(`pending.perkOffers (lo que lee PerkMenu) = {view.pending.perkOffers}`)
	print(`pending.draft.offer (lo que manda el motor) = {table.concat(view.pending.draft.offer, ", ")}`)
	print(`botones: {labels(view.legalActions)}`)
end

title("C4. Tratos: forma de la oferta y lo que lee TradeMenu")
do
	local state = Fixtures.game({ players = 3, seed = 3 })
	local p1, p2 = state.players[1].id, state.players[2].id
	apply(state, p1, { type = "ProposeTrade", offer = { toId = p2, giveCash = 50, wantCash = 0, giveSquares = {}, wantSquares = {} } })
	local trade = View.forPlayer(state, p2).pending.trades[1]
	print(`trade.offer = {trade.offer}; trade.giveCash = {trade.giveCash}`)
	local ok, err = pcall(function()
		-- Misma primera línea de formatOffer (TradeMenu.luau:19) con trade.offer.
		local offer = trade.offer
		return offer.giveCash > 0
	end)
	print(`formatOffer(trade.offer): ok={ok} error={err}`)
end

title("C5. Subasta: control de puja con una puja alta de 200")
do
	local legal = { { type = "Bid", amount = 210 } }
	local bounds = ActionMenuRules.bidControl(legal)
	print(`control: {bounds.min} a {bounds.max}, arranca en {bounds.min}; botón: {labels(legal)}`)
end

title("C6. Etiquetas con estados reales del motor")
do
	-- Duelo
	local state = Fixtures.game({ players = 4, seed = 11 })
	local me = state.players[1].id
	Fixtures.placeOn(state, me, Fixtures.squareOf(state, "Duel") - 2)
	Fixtures.dice(state, 1, 1)
	apply(state, me, { type = "Roll" })
	print(`Duelo, elegir rival: {labels(Engine.legalActions(state, me))}`)
	apply(state, me, { type = "DuelChoice", rivalId = state.players[2].id })
	print(`Duelo, elegir jugada: {labels(Engine.legalActions(state, me))}`)
	-- Mercado
	state = Fixtures.game({ players = 4, seed = 12 })
	me = state.players[1].id
	Fixtures.placeOn(state, me, Fixtures.squareOf(state, "Market") - 2)
	Fixtures.dice(state, 1, 1)
	apply(state, me, { type = "Roll" })
	print(`Mercado: {labels(Engine.legalActions(state, me))}`)
	-- Tribunal
	state = Fixtures.game({ players = 4, seed = 13 })
	me = state.players[1].id
	Fixtures.placeOn(state, me, Fixtures.squareOf(state, "Tribunal") - 2)
	Fixtures.dice(state, 1, 1)
	apply(state, me, { type = "Roll" })
	print(`Tribunal: {labels(Engine.legalActions(state, state.players[2].id))}`)
	-- Multa y Terremoto
	state = Fixtures.game({ players = 4, seed = 14 })
	me = state.players[1].id
	Fixtures.hand(state, me, "Fine")
	print(`Multa: {labels(Engine.legalActions(state, me))}`)
	state = Fixtures.game({ players = 2, seed = 15 })
	me = state.players[1].id
	Fixtures.hand(state, me, "Earthquake")
	local count = 0
	for _, action in Engine.legalActions(state, me) do
		if action.type == "PlayCard" then
			count += 1
		end
	end
	print(`Terremoto en S: {count} botones, todos «{ActionMenuRules.labelFor({ type = "PlayCard", cardId = "Earthquake" })}»`)
end

title("C7. Peticiones del lobby tal como las manda main.client")
do
	print(`PartyJoin("ABC234"): {Protocol.validateLobby("ABC234")}`)
	print(`PartyCreate(nil): {Protocol.validateLobby(nil)}`)
	print(`PartyStart("Rounds"): {Protocol.validateLobby("Rounds")}`)
	print(`Forma que sí acepta: {Protocol.validateLobby({ type = "PartyJoin", code = "ABC234" })}`)
end

-- ---------------------------------------------------------------- Servidor
title("S1. Reloj: una acción sin eventos reinicia el plazo y pisa el final de la escena")
do
	local state = Fixtures.game({ players = 3, seed = 21 })
	local match = MatchState.begin(0, state.phase)
	local me = state.players[1].id
	local rival = state.players[2].id
	local now = 0
	for step = 1, 4 do
		now += 19
		local events = apply(state, me, { type = "ProposePact", toId = rival, rounds = 2 })
		local result = MatchState.step(match, state, events, now, false)
		print(`  t={now}: ProposePact sin tirar; plazo vence en t={result.decisionDeadline}`)
	end
	print(`  ofertas acumuladas: {#state.pending.pactOffers}; el turno sigue en {state.phase}`)

	local huge = MatchState.step(match, state, { { type = "CardPlayed", cardId = "Hurricane" } }, now, false)
	print(`  t={now}: Huracán; escena hasta t={huge.sceneEndsAt}`)
	local after = MatchState.step(match, state, {}, now + 1, false)
	print(`  t={now + 1}: acción sin eventos; sceneEndsAt pasa a t={after.sceneEndsAt}`)
end

title("S2. Subasta: cada puja reinicia los 15 s")
do
	local state = Fixtures.game({ players = 3, seed = 22 })
	local me = state.players[1].id
	local index = Fixtures.squareOf(state, "Property")
	state.pending.index = index
	state.phase = "AwaitBuy"
	apply(state, me, { type = "DeclineBuy" })
	local match = MatchState.begin(0, state.phase)
	local now, amount = 0, 0
	for step = 1, 4 do
		now += 14
		amount += 10
		local bidder = state.players[(step % 2) + 1].id
		local events = apply(state, bidder, { type = "Bid", amount = amount })
		local result = MatchState.step(match, state, events, now, false)
		print(`  t={now}: puja {amount}; cierre en t={result.decisionDeadline}`)
	end
end

title("S3. Scenes: un lote nuevo no espera a la escena anterior")
do
	local clock = SceneClock.new()
	local a = SceneClock.schedule(clock, { { type = "CardPlayed", cardId = "Hurricane" } }, 100)
	local b = SceneClock.schedule(clock, { { type = "DiceRolled" } }, 101)
	print(`  Huracán en t=100 acaba en t={a}; un lote en t=101 acaba en t={b}`)
end

-- ---------------------------------------------------------------- Información oculta
title("V1. MarketBought revela a la mesa la carta comprada")
do
	local state = Fixtures.game({ players = 3, seed = 31 })
	local me, other = state.players[1].id, state.players[2].id
	Fixtures.placeOn(state, me, Fixtures.squareOf(state, "Market") - 2)
	Fixtures.dice(state, 1, 1)
	apply(state, me, { type = "Roll" })
	local card = state.pending.market.cards[1].cardId
	local events = apply(state, me, { type = "MarketBuy", cardId = card })
	local filtered = View.filterEvents(state, other, events)
	for _, event in filtered do
		print(`  {other} recibe {event.type} cardId={event.cardId}`)
	end
end

title("V2. Ventana de reacción: lo que ve el resto de la mesa")
do
	local state = Fixtures.game({ players = 3, seed = 32 })
	local a, b, c = state.players[1].id, state.players[2].id, state.players[3].id
	Fixtures.hand(state, a, "Fine")
	Fixtures.hand(state, b, "Shield")
	apply(state, a, { type = "PlayCard", cardId = "Fine", targetId = b })
	local view = View.forPlayer(state, c)
	print(`  {c} ve phase={view.phase}, eligibleId={view.pending.reaction.eligibleId}, carta={view.pending.reaction.trigger.cardId}`)
end

-- ---------------------------------------------------------------- Reglas
title("R1. Coleccionista: un espectro acumula efectivo")
do
	local state = Fixtures.game({ players = 3, seed = 41 })
	local ghost = state.players[1]
	ghost.perks = { "Collector" }
	ghost.hand = { "Spy", "Fine", "Shove" }
	ghost.cash = 0
	Bankruptcy.charge(state, ghost.id, 1)
	state.stats[ghost.id].comebackRounds = 1 -- ya gastó su remontada
	print(`  estado={ghost.status}, efectivo={ghost.cash}`)
	state.phase = "GhostTurn"
	for _ = 1, 4 do
		state.turnIndex = 1
		state.phase = "GhostTurn"
		apply(state, ghost.id, { type = "GhostAct", kind = "Sabotage" })
		print(`  tras sabotear: estado={ghost.status}, efectivo={ghost.cash}`)
	end
end

title("R2. Embrujo: el último asiento de la ronda no protege nada")
do
	local state = Fixtures.game({ players = 3, seed = 42 })
	local a, b, ghost = state.players[1], state.players[2], state.players[3]
	ghost.status = "Ghost"
	ghost.cash = 0
	local index = Fixtures.squareOf(state, "Property")
	Fixtures.give(state, a.id, index)
	state.turnIndex = 3
	state.phase = "GhostTurn"
	local round = state.round
	apply(state, ghost.id, { type = "GhostAct", kind = "Haunt", index = index })
	print(`  embrujo en ronda {round}, turno siguiente en ronda {state.round}; multiplicador = {Property.rentMultiplier(state, index)}`)
	local _ = b
end

title("R3. Abogado acusado: empate en el Tribunal")
do
	for _, lawyerRole in { "acusado", "votante" } do
		local state = Fixtures.game({ players = 3, seed = 43 })
		local accused, v1, v2 = state.players[1], state.players[2], state.players[3]
		if lawyerRole == "acusado" then
			accused.perks = { "Lawyer" }
		else
			v2.perks = { "Lawyer" }
		end
		Fixtures.placeOn(state, accused.id, Fixtures.squareOf(state, "Tribunal") - 2)
		Fixtures.dice(state, 1, 1)
		apply(state, accused.id, { type = "Roll" })
		apply(state, v1.id, { type = "TribunalVote", verdict = "Fine" })
		local events = apply(state, v2.id, { type = "TribunalVote", verdict = "SkipTurn" })
		for _, event in events do
			if event.type == "TribunalVerdict" then
				print(`  Abogado {lawyerRole}: veredicto={event.verdict}`)
			end
		end
	end
end

title("R4. Empujón: el rival cobra la Salida")
do
	local state = Fixtures.game({ players = 3, seed = 44 })
	local me, rival = state.players[1], state.players[2]
	Fixtures.hand(state, me.id, "Shove")
	rival.position = #state.board.squares - 1
	local before = rival.cash
	apply(state, me.id, { type = "PlayCard", cardId = "Shove", targetId = rival.id })
	print(`  efectivo del rival: {before} -> {rival.cash}`)
end

title("R5. Trato o robo de una casilla sin edificios en una zona con edificios")
do
	local state = Fixtures.game({ players = 3, seed = 45 })
	local a, b = state.players[1], state.players[2]
	local zone = state.board.zones.cian
	for _, index in zone do
		Fixtures.give(state, a.id, index)
	end
	state.properties[zone[1]].level = 3
	apply(state, a.id, { type = "ProposeTrade", offer = { toId = b.id, giveCash = 0, wantCash = 0, giveSquares = { zone[2] }, wantSquares = {} } })
	apply(state, b.id, { type = "RespondTrade", tradeId = state.pending.trades[1].id, accept = true })
	print(`  casilla {zone[1]}: nivel {state.properties[zone[1]].level}, dueño {state.properties[zone[1]].ownerId == a.id and "A"}, zona completa = false, renta = {Property.rentFor(state, zone[1])}`)
end

title("R6. Casero: redondeo de la renta en coma flotante")
do
	local wrong = 0
	local examples = {}
	for _, price in { 60, 90, 100, 110, 120, 140, 150, 160, 170, 180, 210, 220, 250, 280, 290, 300, 310, 320, 340, 350, 360, 370, 400 } do
		for _, zoneMult in { 1, 2 } do
			for _, levelMult in { 1, 2, 3, 5, 8, 12 } do
				for _, dynamic in { 1, 2, 4 } do
					local floatRent = math.floor(price * Economy.baseRentRate * zoneMult * levelMult * dynamic * (1 + Economy.perks.landlordRentRate))
					-- Cuenta exacta en enteros: precio × zona × nivel × dinámico × 115 / 1000.
					local exact = (price * zoneMult * levelMult * dynamic * 115) // 1000
					if floatRent ~= exact then
						wrong += 1
						if #examples < 4 then
							table.insert(examples, `{price}x{zoneMult}x{levelMult}x{dynamic}: {floatRent} en vez de {exact}`)
						end
					end
				end
			end
		end
	end
	print(`  combinaciones con renta distinta: {wrong}; {table.concat(examples, "; ")}`)
end

title("R7. RentPaid anuncia más de lo que cobra el dueño si el pagador se arruina")
do
	local state = Fixtures.game({ players = 3, seed = 46 })
	local payer, owner = state.players[1], state.players[2]
	local index = state.board.zones.violeta[1]
	Fixtures.give(state, owner.id, index)
	payer.cash = 5
	local before = owner.cash
	local events = Property.chargeRent(state, payer.id, owner.id, index, 200)
	print(`  RentPaid.amount = {events[1].amount}; el dueño recibe {owner.cash - before}`)
end

title("R8. Furia y robo con la mano llena: la recompensa se pierde")
do
	local state = Fixtures.game({ players = 3, seed = 47 })
	local me = state.players[2]
	me.hand = { "Spy", "Fine", "Shove" }
	me.fury = Economy.furyThreshold - 1
	local owner = state.players[1]
	owner.cash = 100000
	local index = state.board.zones.cobre[1]
	Fixtures.give(state, owner.id, index)
	for _, event in Property.chargeRent(state, me.id, owner.id, index, 6) do
		print(`  {event.type} {event.cardId or ""}`)
	end
	print(`  mano final = {#me.hand} cartas`)
end

title("R9. Puja por encima del efectivo que se queda; Bot y tratos")
do
	local source = require("@lune/fs").readFile("src/shared/rules/Bot.luau")
	print(`  Bot.luau menciona RespondTrade: {string.find(source, "RespondTrade", 1, true) ~= nil}`)
end

title("R10. Dedos Rápidos: ver los dados antes de decidir la Marcha Atrás")
do
	local state = Fixtures.game({ players = 3, seed = 48 })
	local me = state.players[1]
	me.perks = { "QuickFingers" }
	Fixtures.hand(state, me.id, "Reverse")
	local start = me.position
	Fixtures.dice(state, 5, 6)
	apply(state, me.id, { type = "Roll" })
	print(`  tras tirar: fase={state.phase}, dados={state.pending.heldRoll.a}+{state.pending.heldRoll.b}, posición={me.position - start}`)
	apply(state, me.id, { type = "PlayCard", cardId = "Reverse" })
	apply(state, me.id, { type = "Roll" })
	print(`  jugó Marcha Atrás viendo los dados: posición={me.position}, de {#state.board.squares}`)
end

title("R11. Deck: mano y Squares (control de que se cargan)")
print(`  Deck.handLimit base = {Deck.handLimit({ perks = {} })}; Squares cargado = {Squares ~= nil}`)

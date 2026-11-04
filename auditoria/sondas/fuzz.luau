--!nocheck
-- Sonda hostil de la segunda pasada. Juega partidas al azar con los campos reales de cada acción y
-- comprueba después de cada paso: rechazos sin efectos, invariantes, secretos en vistas y eventos, y
-- que el reloj siempre puede avanzar. Uso: lune run auditoria/sondas/fuzz [segundos] [semilla]
local process = require("@lune/process")
local Engine = require("../../src/shared/rules/Engine")
local Bot = require("../../src/shared/rules/Bot")
local Deck = require("../../src/shared/rules/Deck")
local Protocol = require("../../src/shared/net/Protocol")
local State = require("../../src/shared/rules/State")
local View = require("../../src/shared/rules/View")
local Scenes = require("../../src/shared/config/Scenes")
local SceneClock = require("../../src/server/match/SceneClock")

local SECONDS = tonumber(process.args[1]) or 60
-- Lune no trae `Random`: se usa el Rng del propio motor, con otra instancia que la de la partida.
local RngModule = require("../../src/shared/rules/Rng")
local rngState = RngModule.new(tonumber(process.args[2]) or 12345)
local random = {
	NextInteger = function(_self, low, high)
		return RngModule.int(rngState, low, high)
	end,
	NextNumber = function(_self)
		return RngModule.int(rngState, 1, 1000000) / 1000000
	end,
}

local function deepEqual(a, b)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return a ~= a and b ~= b
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, item in value do
		out[key] = copy(item)
	end
	return out
end

local counts = {
	games = 0,
	actions = 0,
	hostile = 0,
	hostileAccepted = 0,
	validatedOk = 0,
	stateChangedOnReject = 0,
	errors = 0,
	invariants = 0,
	leaks = 0,
	stuck = 0,
	timeouts = 0,
	marketLeaks = 0,
}
local samples = {}
local function note(kind, text)
	samples[kind] = samples[kind] or {}
	if #samples[kind] < 5 then
		table.insert(samples[kind], text)
	end
end

local BAD_VALUES = { -1, 0, 1.5, 0 / 0, math.huge, -math.huge, 1e308, "", "x", true, false, {}, { 1, 2 }, { a = 1 } }

local function bad()
	return BAD_VALUES[random:NextInteger(1, #BAD_VALUES)]
end

local function hostileActions(state, playerId)
	local other = state.players[random:NextInteger(1, #state.players)].id
	local index = random:NextInteger(-2, #state.board.squares + 3)
	local cards = { "Hurricane", "Fine", "Shield", "BounceRent", "Backstab", "DeedThief", "Demolition", "Nope" }
	local card = cards[random:NextInteger(1, #cards)]
	local list = {
		{ type = "DraftPerk", perkId = bad() },
		{ type = "DraftPerk", perkId = "Banker" },
		{ type = "RerollDie", die = bad() },
		{ type = "RerollDie", die = "a" },
		{ type = "Bid", amount = bad() },
		{ type = "Bid", amount = 1e12 },
		{ type = "Bid", amount = 1 },
		{ type = "PlayCard", cardId = card, targetId = other, zoneId = bad(), index = bad(), pactId = bad() },
		{ type = "PlayCard", cardId = card, targetId = playerId },
		{ type = "PlayCard", cardId = bad() },
		{ type = "PlayCard", cardId = "Demolition", index = index },
		{ type = "PlayCard", cardId = "DeedThief", index = index },
		{ type = "PlayCard", cardId = "Earthquake", zoneId = "noexiste" },
		{ type = "PlayCard", cardId = "Backstab", pactId = "P999" },
		{ type = "React", cardId = card, targetId = other },
		{ type = "React", cardId = "BounceRent", targetId = playerId },
		{ type = "Build", index = index },
		{ type = "Build", index = bad() },
		{ type = "ProposeTrade", offer = bad() },
		{ type = "ProposeTrade", offer = { toId = other, giveCash = 1e12, wantCash = 0, giveSquares = {}, wantSquares = {} } },
		{ type = "ProposeTrade", offer = { toId = other, giveCash = -5, wantCash = 0, giveSquares = {}, wantSquares = {} } },
		{ type = "ProposeTrade", offer = { toId = other, giveCash = 0.5, wantCash = 0, giveSquares = {}, wantSquares = {} } },
		{ type = "ProposeTrade", offer = { toId = other, giveCash = 0, wantCash = 0, giveSquares = { index }, wantSquares = {} } },
		{ type = "ProposeTrade", offer = { toId = playerId, giveCash = 1, wantCash = 0, giveSquares = {}, wantSquares = {} } },
		{ type = "RespondTrade", tradeId = bad(), accept = bad() },
		{ type = "RespondTrade", tradeId = "T1", accept = true },
		{ type = "ProposePact", toId = other, rounds = bad() },
		{ type = "ProposePact", toId = bad(), rounds = 2 },
		{ type = "ProposePact", toId = other, rounds = 99 },
		{ type = "RespondPact", pactId = bad(), accept = bad() },
		{ type = "RespondPact", pactId = "P1", accept = true },
		{ type = "BreakPact", pactId = bad() },
		{ type = "BreakPact", pactId = "P999" },
		{ type = "TribunalVote", verdict = bad() },
		{ type = "TribunalVote", verdict = "PayToPlayer", targetId = bad() },
		{ type = "TribunalVote", verdict = "PayToPlayer" },
		{ type = "DuelChoice", rivalId = bad() },
		{ type = "DuelChoice", choice = bad() },
		{ type = "DuelChoice" },
		{ type = "MarketBuy", cardId = bad() },
		{ type = "MarketBuy", cardId = "Hurricane" },
		{ type = "GhostAct", kind = bad() },
		{ type = "GhostAct", kind = "Haunt", index = bad() },
		{ type = "GhostAct", kind = "Haunt", index = index },
		{ type = "Nope" },
		{},
	}
	return list
end

local function legalActionsFor(state, action, playerId)
	for _, legal in Engine.legalActions(state, playerId) do
		if deepEqual(legal, action) then
			return true
		end
	end
	return false
end

local function checkInvariants(state, context)
	local cards = 0
	for _, player in state.players do
		if type(player.cash) ~= "number" or player.cash < 0 or player.cash % 1 ~= 0 or player.cash ~= player.cash then
			counts.invariants += 1
			note("efectivo", `{context}: {player.id} cash={player.cash}`)
		end
		if player.status == "Ghost" and player.cash ~= 0 then
			counts.invariants += 1
			note("espectro con efectivo", `{context}: {player.id} cash={player.cash} perks={table.concat(player.perks, ",")}`)
		end
		if #player.hand > Deck.handLimit(player) then
			counts.invariants += 1
			note("mano", `{context}: {player.id} mano={#player.hand}`)
		end
		if player.position < 1 or player.position > #state.board.squares then
			counts.invariants += 1
			note("posición", `{context}: {player.id} pos={player.position}`)
		end
		cards += #player.hand
	end
	for index, property in state.properties do
		if property.level < 0 or property.level > 5 or property.level % 1 ~= 0 then
			counts.invariants += 1
			note("nivel", `{context}: {index} nivel={property.level}`)
		end
		if property.ownerId then
			local owner
			for _, player in state.players do
				if player.id == property.ownerId then
					owner = player
				end
			end
			if not owner or owner.status ~= "Active" then
				counts.invariants += 1
				note("dueño", `{context}: casilla {index} de {property.ownerId} estado {owner and owner.status}`)
			end
		elseif property.level ~= 0 then
			counts.invariants += 1
			note("nivel sin dueño", `{context}: {index}`)
		end
	end
	for _, pact in state.pacts do
		for _, id in { pact.a, pact.b } do
			for _, player in state.players do
				if player.id == id and player.status ~= "Active" then
					counts.invariants += 1
					note("pacto", `{context}: pacto {pact.id} con {id} {player.status}`)
				end
			end
		end
	end
	return cards
end

-- Busca el id de una carta de la mano ajena o un secreto en la vista de otro jugador.
local function checkView(state, viewerId)
	local view = View.forPlayer(state, viewerId)
	for _, seated in view.players do
		if seated.id ~= viewerId and seated.hand ~= nil then
			counts.leaks += 1
			note("mano ajena", `{viewerId} ve la mano de {seated.id}`)
		end
	end
	local pending = view.pending
	if view.rng ~= nil or (pending and pending.rng ~= nil) then
		counts.leaks += 1
		note("rng", viewerId)
	end
	if pending and pending.spy and pending.spy.viewerId ~= viewerId then
		counts.leaks += 1
		note("espía", viewerId)
	end
	if pending and pending.duel and pending.duel.picks then
		for id in pending.duel.picks do
			if id ~= viewerId then
				counts.leaks += 1
				note("duelo", `{viewerId} ve la jugada de {id}`)
			end
		end
	end
	if pending and pending.tribunal and pending.tribunal.votes then
		for id in pending.tribunal.votes do
			if id ~= viewerId then
				counts.leaks += 1
				note("tribunal", `{viewerId} ve el voto de {id}`)
			end
		end
	end
	-- La vista no puede compartir tablas con el estado.
	if view.pacts == state.pacts or view.modifiers == state.modifiers or view.stats == state.stats then
		counts.leaks += 1
		note("tabla compartida", viewerId)
	end
end

local function checkEvents(state, events)
	for _, player in state.players do
		for _, event in View.filterEvents(state, player.id, events) do
			if (event.type == "CardDrawn" or event.type == "CardDiscarded") and event.playerId ~= player.id and event.cardId ~= nil then
				counts.leaks += 1
				note("carta robada", `{player.id} ve {event.cardId}`)
			end
			if event.type == "MarketBought" and event.playerId ~= player.id and event.cardId ~= nil then
				counts.marketLeaks += 1
			end
		end
	end
end

local function step(state, phaseLabel)
	-- Acción hostil de un jugador al azar: un rechazo no puede dejar rastro.
	local attacker = state.players[random:NextInteger(1, #state.players)].id
	for _ = 1, 3 do
		local list = hostileActions(state, attacker)
		local action = list[random:NextInteger(1, #list)]
		local before = copy(state)
		counts.hostile += 1
		if Protocol.validate(action) then
			counts.validatedOk += 1
		end
		local legal = legalActionsFor(state, action, attacker)
		local ok, result = pcall(Engine.apply, state, attacker, action)
		if not ok then
			counts.errors += 1
			note("error", `{phaseLabel} {action.type}: {result}`)
			return false
		end
		if result.ok then
			counts.hostileAccepted += 1
			checkEvents(state, result.events)
			checkInvariants(state, `hostil {action.type}`)
			if state.phase == "GameOver" then
				return true
			end
			local _ = legal
		elseif not deepEqual(before, state) then
			counts.stateChangedOnReject += 1
			note("rechazo con efectos", `{phaseLabel} {action.type}: {result.error}`)
		end
	end

	-- Jugada legal al azar, o del bot, o el reloj.
	local order = {}
	for _, player in state.players do
		table.insert(order, player.id)
	end
	for index = #order, 2, -1 do
		local other = random:NextInteger(1, index)
		order[index], order[other] = order[other], order[index]
	end
	for _, playerId in order do
		local legal = Engine.legalActions(state, playerId)
		if #legal > 0 and random:NextNumber() < 0.9 then
			local action
			if random:NextNumber() < 0.5 then
				action = Bot.choose(state, playerId)
			end
			action = action or legal[random:NextInteger(1, #legal)]
			local ok, result = pcall(Engine.apply, state, playerId, action)
			if not ok then
				counts.errors += 1
				note("error", `{phaseLabel} legal {action.type}: {result}`)
				return false
			end
			if not result.ok then
				counts.invariants += 1
				note("legal rechazada", `{action.type}: {result.error}`)
			else
				counts.actions += 1
				checkEvents(state, result.events)
			end
			checkInvariants(state, action.type)
			checkView(state, playerId)
			return true
		end
	end
	local before = { phase = state.phase, round = state.round, turn = state.turnIndex }
	local ok, events = pcall(Engine.timeout, state)
	counts.timeouts += 1
	if not ok then
		counts.errors += 1
		note("error", `{phaseLabel} timeout: {events}`)
		return false
	end
	checkEvents(state, events)
	checkInvariants(state, "timeout")
	if #events == 0 and before.phase == state.phase and before.round == state.round and before.turn == state.turnIndex then
		counts.stuck += 1
		note("atascada", `fase {state.phase}`)
		return false
	end
	return true
end

local started = os.clock()
local game = 0
while os.clock() - started < SECONDS do
	game += 1
	local players = random:NextInteger(2, 8)
	local ids = {}
	for index = 1, players do
		ids[index] = `P{index}`
	end
	local state = State.create({ playerIds = ids, seed = random:NextInteger(1, 2 ^ 31 - 1), endMode = "Rounds" })
	counts.games += 1
	local guard = 0
	while state.phase ~= "GameOver" and guard < 20000 do
		guard += 1
		if not step(state, state.phase) then
			break
		end
	end
	if state.phase ~= "GameOver" and guard >= 20000 then
		counts.stuck += 1
		note("sin terminar", `{players} jugadores`)
	end
end

print("Recuentos:")
local keys = {}
for key in counts do
	table.insert(keys, key)
end
table.sort(keys)
for _, key in keys do
	print(`  {key} = {counts[key]}`)
end
print("Muestras:")
for kind, list in samples do
	print(`  [{kind}]`)
	for _, text in list do
		print(`    {text}`)
	end
end
local _ = Scenes and SceneClock

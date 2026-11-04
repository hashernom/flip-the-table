--!nocheck
-- Mide lo que no comprueban las pruebas: Sin Fin sin acciones, cuánto pesan las escenas en cada turno
-- y el líder a mitad de partida con bots. Uso: lune run auditoria/sondas/medidas [partidas]
local process = require("@lune/process")
local Bot = require("../../src/shared/rules/Bot")
local Engine = require("../../src/shared/rules/Engine")
local Scenes = require("../../src/shared/config/Scenes")
local SceneClock = require("../../src/server/match/SceneClock")
local State = require("../../src/shared/rules/State")

local GAMES = tonumber(process.args[1]) or 30

local function ids(count)
	local out = {}
	for index = 1, count do
		out[index] = `P{index}`
	end
	return out
end

print("Sin Fin, solo con tiempo agotado (tope 300 000 ticks):")
for _, players in { 2, 3, 5, 8 } do
	local finished, unfinished, maxRound = 0, 0, 0
	local rounds = {}
	for seed = 1, 3 do
		local state = State.create({ playerIds = ids(players), seed = seed, endMode = "Endless" })
		local ticks = 0
		while state.phase ~= "GameOver" and ticks < 300000 do
			ticks += 1
			Engine.timeout(state)
		end
		maxRound = math.max(maxRound, state.round)
		table.insert(rounds, state.round)
		if state.phase == "GameOver" then
			finished += 1
		else
			unfinished += 1
		end
	end
	print(`  {players} jugadores: terminaron {finished}, sin terminar {unfinished}, rondas {table.concat(rounds, ", ")}`)
end

-- Bucle de bots: mismo criterio que MatchService. Devuelve turnos, segundos de escena y líderes.
local function playBots(players, seed, mode)
	local state = State.create({ playerIds = ids(players), seed = seed, endMode = mode })
	local clock = SceneClock.new()
	local turns, sceneSec, guard = 0, 0, 0
	local auctions, tribunals = 0, 0
	while state.phase ~= "GameOver" and guard < 500000 do
		guard += 1
		local acted = false
		local events
		for _, player in state.players do
			local action = Bot.choose(state, player.id)
			if action then
				local result = Engine.apply(state, player.id, action)
				if result.ok then
					events = result.events
					acted = true
					if action.type == "EndTurn" or action.type == "GhostAct" then
						turns += 1
					end
					break
				end
			end
		end
		if not acted then
			local phase = state.phase
			events = Engine.timeout(state)
			if phase == "Auction" then
				auctions += 1
			elseif phase == "Tribunal" then
				tribunals += 1
			end
		end
		local now = 0
		sceneSec += SceneClock.schedule(clock, events, now)
	end
	return state, turns, sceneSec, auctions, tribunals, guard
end

print(`Escenas por turno con bots, {GAMES} partidas por tamaño (modo Rondas, sin tiempo de decisión):`)
for _, players in { 2, 4, 6, 8 } do
	local turnsTotal, sceneTotal, auctionTotal, rounds = 0, 0, 0, 0
	for seed = 1, GAMES do
		local state, turns, sceneSec, auctions = playBots(players, seed, "Rounds")
		turnsTotal += turns
		sceneTotal += sceneSec
		auctionTotal += auctions
		rounds += state.round
	end
	local perTurn = sceneTotal / math.max(1, turnsTotal)
	local minutes = sceneTotal / GAMES / 60
	print(
		string.format(
			"  %d jugadores: %.1f turnos por partida, %.1f s de escena por turno, %.1f min solo de escenas, %.1f subastas por partida",
			players,
			turnsTotal / GAMES,
			perTurn,
			minutes,
			auctionTotal / GAMES
		)
	)
end

print("Sin Fin con bots, duración en rondas:")
for _, players in { 2, 4, 8 } do
	local rounds, maxRound, unfinished = 0, 0, 0
	for seed = 1, GAMES do
		local state = playBots(players, seed, "Endless")
		rounds += state.round
		maxRound = math.max(maxRound, state.round)
		if state.phase ~= "GameOver" then
			unfinished += 1
		end
	end
	print(string.format("  %d jugadores: media %.0f rondas, máximo %d, sin terminar %d", players, rounds / GAMES, maxRound, unfinished))
end
local _ = Scenes

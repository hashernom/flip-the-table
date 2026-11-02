--!strict
-- Avance del turno, rondas, Corona y final de la partida. La caducidad de los intercambios
-- también vive aquí (R20).
local Economy = require("../config/Economy")
local Score = require("./Score")
local Types = require("./Types")

type GameState = Types.GameState
type Event = Types.Event
type Player = Types.Player
type PlayerId = Types.PlayerId

local Turn = {}

-- R20: una oferta caduca con el turno en que se hizo. Se ejecuta antes de mover el turno,
-- mientras round y turnIndex todavía señalan al turno que termina.
local function dropTradesOfTurn(state: GameState)
	local pending = state.pending
	if not pending or not pending.trades then
		return
	end
	for index = #pending.trades, 1, -1 do
		local trade = pending.trades[index]
		if trade.round == state.round and trade.turnIndex == state.turnIndex then
			table.remove(pending.trades, index)
		end
	end
end

-- Siguiente jugador que sigue en la partida. Si no queda ninguno, devuelve al actual.
local function nextIndex(state: GameState): number
	local count = #state.players
	local index = state.turnIndex
	for _ = 1, count do
		index = index % count + 1
		if state.players[index].status ~= "Left" then
			return index
		end
	end
	return state.turnIndex
end

local function playersById(state: GameState): { [PlayerId]: Player }
	local byId: { [PlayerId]: Player } = {}
	for _, player in state.players do
		byId[player.id] = player
	end
	return byId
end

-- Primer jugador Active de la clasificación, o nil si no queda ninguno. R25: la Corona
-- nunca la lleva un espectro ni un jugador que se fue.
local function crownTarget(state: GameState): PlayerId?
	local byId = playersById(state)
	for _, id in Score.ranking(state) do
		local player = byId[id]
		if player and player.status == "Active" then
			return id
		end
	end
	return nil
end

-- Primera ronda con renta de rondas finales, o nil si el modo no tiene rondas finales.
local function firstFinalRound(state: GameState): number?
	local maxRounds = state.maxRounds
	if state.endMode ~= "Rounds" or not maxRounds then
		return nil
	end
	return maxRounds - Economy.finalRoundsCount + 1
end

function Turn.activeCount(state: GameState): number
	local count = 0
	for _, player in state.players do
		if player.status == "Active" then
			count += 1
		end
	end
	return count
end

-- Rondas finales: solo con tope de rondas y desde la primera de las dos últimas.
function Turn.isFinalRound(state: GameState): boolean
	local first = firstFinalRound(state)
	return first ~= nil and state.round >= first
end

-- Presión de Sin Fin: desde pressureFromRound la Salida no paga y la renta se duplica.
function Turn.isPressureRound(state: GameState): boolean
	return state.endMode == "Endless" and state.round >= Economy.pressureFromRound
end

-- R11/R21: con un solo jugador Active la partida termina en ese instante y gana ese jugador,
-- aunque la clasificación coloque delante a un espectro con más patrimonio. Añade el evento
-- a `events` y devuelve true si ha cerrado la partida.
function Turn.finishIfLastActive(state: GameState, events: { Event }): boolean
	if Turn.activeCount(state) ~= 1 then
		return false
	end
	local ranking = Score.ranking(state)
	local byId = playersById(state)
	local winnerId: PlayerId? = nil
	for _, id in ranking do
		local player = byId[id]
		if player and player.status == "Active" then
			winnerId = id
			break
		end
	end
	if not winnerId then
		-- Inalcanzable: activeCount ya garantizó que hay exactamente un activo.
		error("Turn.finishIfLastActive: no se encontró el jugador activo", 2)
	end
	state.phase = "GameOver"
	table.insert(events, { type = "GameEnded", ranking = ranking, winnerId = winnerId })
	return true
end

-- La Corona se asigna al líder activo al empezar cada ronda. Solo emite evento si cambia.
local function moveCrown(state: GameState, events: { Event })
	local pending = state.pending
	if not pending then
		return
	end
	local from = pending.crownId
	local to = crownTarget(state)
	if not to or to == from then
		return
	end
	pending.crownId = to
	table.insert(events, { type = "CrownMoved", from = from, to = to })
end

function Turn.next(state: GameState): { Event }
	dropTradesOfTurn(state)
	local index = nextIndex(state)
	-- Dar la vuelta al orden abre ronda; con un solo jugador presente también cuenta.
	local startsRound = index <= state.turnIndex
	if startsRound then
		state.round += 1
	end
	state.turnIndex = index

	local events: { Event } = {}
	local maxRounds = state.maxRounds
	-- Rondas: la partida ha consumido su última ronda.
	if state.endMode == "Rounds" and maxRounds ~= nil and state.round > maxRounds then
		state.phase = "GameOver"
		local ranking = Score.ranking(state)
		table.insert(events, { type = "GameEnded", ranking = ranking, winnerId = ranking[1] })
		return events
	end
	-- R11: si en el cambio de turno queda un solo activo, la partida termina aquí.
	if Turn.finishIfLastActive(state, events) then
		return events
	end
	-- La ronda 1 empieza con la partida: solo se anuncia la ronda que abre este salto.
	if not startsRound then
		return events
	end
	table.insert(events, { type = "RoundStarted", round = state.round })
	moveCrown(state, events)
	local first = firstFinalRound(state)
	if first ~= nil and state.round == first then
		table.insert(events, { type = "FinalRoundsStarted", round = state.round })
	end
	return events
end

return Turn

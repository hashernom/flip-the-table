--!strict
-- Avance del turno, rondas, Corona y final de la partida. También viven aquí la caducidad de los
-- intercambios (R20), el movimiento de la Zona Caliente (R-P40) y la de los pactos (Tarea 8).
local Economy = require("../config/Economy")
local HotZone = require("./HotZone")
local Pact = require("./Pact")
local Perks = require("./Perks")
local Score = require("./Score")
local Types = require("./Types")

type GameState = Types.GameState
type Event = Types.Event
type Player = Types.Player
type PlayerId = Types.PlayerId

local Turn = {}

local function append(events: { Event }, more: { Event })
	for _, event in more do
		table.insert(events, event)
	end
end

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

-- Siguiente jugador que sigue en la partida. Un jugador con skipTurns > 0 pierde el turno: se
-- descuenta la marca y se sigue buscando (Tribunal: «perder 1 turno»). Solo se examinan los demás:
-- al jugador en turno no se le consume una marca por volver a sí mismo (perdería el turno sin que
-- nadie lo ganase); si no queda nadie, se le devuelve el turno sin tocar su contador.
local function nextIndex(state: GameState): number
	local count = #state.players
	local index = state.turnIndex
	for _ = 1, count - 1 do
		index = index % count + 1
		local player = state.players[index]
		if player.status ~= "Left" then
			if player.skipTurns > 0 then
				player.skipTurns -= 1
			else
				return index
			end
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

-- R27: gana siempre el primer jugador Active de la clasificación. Solo si no queda ninguno
-- (un caso que no debería llegar al final) decide el primero de la clasificación.
local function winnerOf(state: GameState, ranking: { PlayerId }): PlayerId
	local byId = playersById(state)
	for _, id in ranking do
		local player = byId[id]
		if player and player.status == "Active" then
			return id
		end
	end
	return ranking[1]
end

-- R11/R21: con un solo jugador Active la partida termina en ese instante y gana ese jugador,
-- aunque la clasificación coloque delante a un espectro con más patrimonio. Añade el evento
-- a `events` y devuelve true si la partida queda cerrada (también si ya lo estaba).
function Turn.finishIfLastActive(state: GameState, events: { Event }): boolean
	-- Idempotente: una partida terminada no vuelve a emitir GameEnded.
	if state.phase == "GameOver" then
		return true
	end
	if Turn.activeCount(state) ~= 1 then
		return false
	end
	local ranking = Score.ranking(state)
	state.phase = "GameOver"
	table.insert(events, { type = "GameEnded", ranking = ranking, winnerId = winnerOf(state, ranking) })
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
	-- Idempotente: una partida terminada no vuelve a moverse ni a cerrarse.
	if state.phase == "GameOver" then
		return {}
	end
	dropTradesOfTurn(state)
	local index = nextIndex(state)
	-- Dar la vuelta al orden abre ronda; con un solo jugador presente también cuenta.
	local startsRound = index <= state.turnIndex
	if startsRound then
		state.round += 1
	end
	state.turnIndex = index

	local events: { Event } = {}
	-- R11 manda sobre el final por rondas: si solo queda un activo, gana ese jugador.
	if Turn.finishIfLastActive(state, events) then
		return events
	end
	local maxRounds = state.maxRounds
	-- Rondas: la partida ha consumido su última ronda.
	if state.endMode == "Rounds" and maxRounds ~= nil and state.round > maxRounds then
		state.phase = "GameOver"
		local ranking = Score.ranking(state)
		table.insert(events, { type = "GameEnded", ranking = ranking, winnerId = winnerOf(state, ranking) })
		return events
	end
	-- La ronda 1 empieza con la partida: solo se anuncia la ronda que abre este salto.
	if not startsRound then
		return events
	end
	table.insert(events, { type = "RoundStarted", round = state.round })
	-- Zona Caliente: la ronda 1 la elige State.create (R-P40); al empezar las rondas de la tabla
	-- (4, 7, 10…) se mueve aquí, nunca a la misma zona que la anterior. Sin zona elegida no hay
	-- nada que mover: una partida real siempre la trae de State.create, y así el fixture de
	-- reglas (que la limpia) no altera el azar de las pruebas anteriores.
	if state.hotZoneId ~= nil and HotZone.isMoveRound(state, state.round) then
		append(events, HotZone.move(state))
	end
	-- Pactos caducados: untilRound es la última ronda activa y al entrar en la siguiente se
	-- cierran con su garantía devuelta a cada parte.
	append(events, Pact.expire(state))
	moveCrown(state, events)
	local first = firstFinalRound(state)
	if first ~= nil and state.round == first then
		table.insert(events, { type = "FinalRoundsStarted", round = state.round })
	end
	-- Marcas de una vez por ronda: el dado repetido de Dedos Rápidos se recarga al empezar ronda.
	-- Es un mapa por jugador (R-P33), así que se vacía entero.
	local pending = state.pending
	if pending then
		pending.rerollUsed = nil
	end
	-- El borrador de perks del momento abre antes de que sigan los turnos de la ronda (R-P28:
	-- Engine.endTurn no pisa la fase que deja abierta).
	Perks.begin(state)
	return events
end

return Turn

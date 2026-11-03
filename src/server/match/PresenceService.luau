--!strict
-- Servicio de presencia: mantiene el asiento de cada jugador que entra o sale de la partida y
-- decide cuándo un bot toma el control. No modifica el motor: la decisión vive en PresenceRules
-- (pura) y el cambio de `isBot` entra por el único camino de MatchService (R-P6, R-P10). Se
-- engancha al arranque de cada partida porque una revancha estrena asientos.
--
-- El bot no juega desde aquí: MatchService programa su turno al terminar la escena (R-P27) y usa
-- los ganchos `onTimeout`/`onAction` solo para mantener la racha de tiempos agotados (R-P28).
local Players = game:GetService("Players")
local MatchService = require("./MatchService")
local PresenceRules = require("./PresenceRules")

type Match = MatchService.Match
type Seat = PresenceRules.Seat

local PresenceService = {}

local started = false
-- Asientos de la partida vigente. Se reconstruyen al arrancar cada partida y a partir de ahí los
-- mantiene este servicio; el motor solo guarda `isBot`, que se aplica vía setBotControlled.
local seats: { Seat } = {}
local tracked: Match? = nil

-- Asientos iniciales de una partida. Todos los jugadores están presentes al arrancar (start los
-- recibe y avisa antes de devolver), así que el userId sale del Player y no de una conversión:
-- la identidad se toca una sola vez, en el borde (R-P9).
local function seatsFrom(match: Match): { Seat }
	local list: { Seat } = {}
	for index, statePlayer in match.state.players do
		local player = match.players[statePlayer.id]
		if player then
			list[index] = {
				userId = player.UserId,
				playerId = statePlayer.id,
				seat = index,
				connected = player.Parent ~= nil,
				bot = statePlayer.isBot,
				timeouts = 0,
			}
		end
	end
	return list
end

local function seatOf(userId: number): Seat?
	for _, value in seats do
		if value.userId == userId then
			return value
		end
	end
	return nil
end

-- Se engancha a los ganchos de la partida. Los dos comprueban que la partida siga siendo la
-- vigente: una revancha deja la anterior atrás y sus avisos ya no tocan los asientos nuevos.
local function bind(match: Match)
	tracked = match
	seats = seatsFrom(match)
	match:onTimeout(function(playerId: string)
		if tracked ~= match or match.finished then
			return
		end
		seats = PresenceRules.onTimeout(seats, playerId)
		match:setBotControlled(playerId, PresenceRules.isBotControlled(seats, playerId))
	end)
	match:onAction(function(playerId: string)
		if tracked ~= match or match.finished then
			return
		end
		seats = PresenceRules.onAction(seats, playerId)
		match:setBotControlled(playerId, false)
	end)
end

-- Salió un jugador: si tenía asiento, su bot lo reemplaza de inmediato y el turno no se pierde.
-- Si no estaba sentado (lobby, partida ajena) no se hace nada y no se avisa de ningún error.
-- Cuando ya no queda nadie conectado, la partida termina como abandonada (R-P8).
local function onPlayerRemoving(player: Player)
	local match = tracked
	if not match or match.finished then
		return
	end
	local seat = seatOf(player.UserId)
	if not seat then
		return
	end
	seats = PresenceRules.onLeave(seats, player.UserId)
	match:setBotControlled(seat.playerId, true)
	if not PresenceRules.hasHumans(seats) then
		match:abandon("no queda ningún jugador humano")
	end
end

-- Volvió un jugador: `PlayerAdded` después de un `PlayerRemoving` con el mismo UserId. Recupera
-- su asiento y su mano (el estado del motor nunca se perdió) y el control; el bot se desactiva
-- antes de reenviar la vista para que esta ya diga que no lo controla.
local function onPlayerAdded(player: Player)
	local match = tracked
	if not match or match.finished then
		return
	end
	local seat = seatOf(player.UserId)
	if not seat or seat.connected then
		return
	end
	local playerId = seat.playerId
	local found, updated = PresenceRules.onReturn(seats, player.UserId)
	if not found then
		return
	end
	seats = updated
	match:setBotControlled(playerId, false)
	match:reattach(player)
end

-- Arranca el servicio una sola vez por servidor. `MatchService.onStart` avisa también de una
-- partida que ya estuviera en curso, así que el orden con el lobby (Tarea 5) no importa.
function PresenceService.start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	MatchService.onStart(bind)
end

return PresenceService

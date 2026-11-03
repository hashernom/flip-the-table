--!strict
-- Reglas puras de presencia (R-P10): reciben la lista de asientos del contrato `Seat` y devuelven
-- listas nuevas; no tocan el motor, ni `game`, ni `task`. MatchService aplica el resultado de
-- `bot` en su único punto de escritura y PresenceService conserva la lista entre eventos.
--
-- Identidad: `onLeave`, `onReturn` e `isSeated` buscan por `userId`, la identidad de la conexión
-- que entregan `PlayerAdded`/`PlayerRemoving`. `onTimeout`, `onAction` e `isBotControlled` buscan
-- por `playerId`, porque los ganchos de MatchService ya hablan la clave del motor. `Seat` lleva
-- las dos, así que ninguna función convierte (contratos, «Identidad»).
local Economy = require("../../shared/config/Economy")

export type Seat = {
	userId: number,
	playerId: string, -- tostring(userId); es la clave del motor
	seat: number, -- índice en state.players (1..8)
	connected: boolean, -- false mientras esté desconectado
	bot: boolean, -- true si lo controla un bot
	timeouts: number, -- tiempos agotados seguidos: los cierra una acción o la salida
}

local PresenceRules = {}

-- Copia de la lista y de cada asiento. Las reglas trabajan sobre la copia: el llamador conserva
-- intacta la lista que pasó y una prueba puede compararla después de cada llamada.
local function copySeats(seats: { Seat }): { Seat }
	local copy: { Seat } = table.create(#seats)
	for index, value in seats do
		copy[index] = {
			userId = value.userId,
			playerId = value.playerId,
			seat = value.seat,
			connected = value.connected,
			bot = value.bot,
			timeouts = value.timeouts,
		}
	end
	return copy
end

local function indexOfUserId(seats: { Seat }, userId: number): number?
	for index, value in seats do
		if value.userId == userId then
			return index
		end
	end
	return nil
end

local function indexOfPlayerId(seats: { Seat }, playerId: string): number?
	for index, value in seats do
		if value.playerId == playerId then
			return index
		end
	end
	return nil
end

-- El jugador se fue: su asiento sigue en la mesa (conserva posición, propiedades y mano, que
-- viven en el motor) pero pasa a control de bot de inmediato. Es lo que mantiene la partida en
-- marcha sin esperar a nadie y sin perder el turno. La racha de tiempos agotados termina aquí:
-- mientras no está, el bot juega por él y no hay decisión suya que pueda vencer, así que quien
-- vuelva empieza de cero y no hereda el castigo de una mala conexión.
function PresenceRules.onLeave(seats: { Seat }, userId: number): { Seat }
	local copy = copySeats(seats)
	local index = indexOfUserId(copy, userId)
	if index then
		local value = copy[index]
		value.connected = false
		value.bot = true
		value.timeouts = 0
	end
	return copy
end

-- El jugador volvió: la conexión es nueva pero el userId es el mismo, así que recupera su asiento
-- y el control. `seat` y `timeouts` no se tocan: al irse la racha ya quedó cerrada y, mientras
-- está presente, solo una acción (onAction) la reinicia. Devuelve false si el userId no estaba en
-- la partida, para que el servicio no invente un asiento de lobby.
function PresenceRules.onReturn(seats: { Seat }, userId: number): (boolean, { Seat })
	local copy = copySeats(seats)
	local index = indexOfUserId(copy, userId)
	if not index then
		return false, copy
	end
	local value = copy[index]
	value.connected = true
	value.bot = false
	return true, copy
end

-- Un tiempo agotado del asiento. Al llegar al umbral (dos seguidos) el bot toma el control; un
-- tiempo suelto no basta y los de otro asiento no cuentan.
function PresenceRules.onTimeout(seats: { Seat }, playerId: string): { Seat }
	local copy = copySeats(seats)
	local index = indexOfPlayerId(copy, playerId)
	if index then
		local value = copy[index]
		value.timeouts += 1
		if value.timeouts >= Economy.bot.timeoutsToControl then
			value.bot = true
		end
	end
	return copy
end

-- Cualquier acción del jugador reinicia la racha y le devuelve el control: quien vuelve y juega
-- manda otra vez; quien vuelve y no juega vuelve a perderlo tras dos tiempos más.
function PresenceRules.onAction(seats: { Seat }, playerId: string): { Seat }
	local copy = copySeats(seats)
	local index = indexOfPlayerId(copy, playerId)
	if index then
		local value = copy[index]
		value.timeouts = 0
		value.bot = false
	end
	return copy
end

-- ¿El asiento lo controla un bot? Un playerId que no está en la mesa no lo controla nadie.
function PresenceRules.isBotControlled(seats: { Seat }, playerId: string): boolean
	local index = indexOfPlayerId(seats, playerId)
	if not index then
		return false
	end
	return seats[index].bot
end

-- ¿El userId tiene asiento? Es la pregunta que separa una salida de partida de una salida de
-- lobby (Tarea 5): sin asiento no hay nada que marcar.
function PresenceRules.isSeated(seats: { Seat }, userId: number): boolean
	return indexOfUserId(seats, userId) ~= nil
end

-- ¿Queda algún humano conectado? Cuando no queda ninguno la partida se abandona (R-P8). Un
-- asiento con bot pero conectado sigue siendo una persona que puede volver a jugar.
function PresenceRules.hasHumans(seats: { Seat }): boolean
	for _, value in seats do
		if value.connected then
			return true
		end
	end
	return false
end

return PresenceRules

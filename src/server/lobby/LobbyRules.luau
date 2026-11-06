--!strict
-- Reglas puras del lobby: fiestas (capacidad, caducidad y cambio de anfitrión), cola pública,
-- datos del teletransporte y reintentos de reserva. No usa game, task ni relojes: el instante y
-- la espera entran por parámetro, así que Lune las prueba igual que Roblox.
local Lobby = require("../../shared/config/Lobby")
local MatchSettings = require("../../shared/config/MatchSettings")
local Types = require("../../shared/rules/Types")

-- Una fiesta: código, anfitrión, miembros en orden de llegada, servidor del lobby donde vive el
-- anfitrión y vida del código. El código no es una sala permanente (R-P12 del plan): caduca y se
-- borra en cuanto el grupo sale hacia la partida.
export type Party = {
	code: string,
	hostId: number,
	members: { number },
	serverId: string,
	createdAt: number,
	expiresAt: number,
}

-- Datos que viajan al lugar de partida (R-P30): semilla, modo, código cuando es una party y
-- tamaño del grupo, que el lugar de partida usa para esperar a que lleguen todos. No llevan nada
-- privado: el jugador puede verlos.
export type MatchData = {
	seed: number,
	endMode: Types.EndMode,
	code: string?,
	size: number,
	-- Configuración de la partida privada (config/MatchSettings), ya normalizada. La cola pública no la lleva.
	settings: MatchSettings.Settings?,
}

-- Datos del salto lobby → lobby cuando la fiesta vive en otro servidor: solo el código, para que
-- el servidor del anfitrión termine de unir al jugador cuando llegue.
export type JoinData = { party: string }

local LobbyRules = {}

-- Copia con la lista de miembros nueva. Ninguna regla muta la fiesta que recibe: el servicio
-- decide qué guardar (mismo criterio que PresenceRules con los asientos).
local function copyParty(party: Party): Party
	return {
		code = party.code,
		hostId = party.hostId,
		members = table.clone(party.members),
		serverId = party.serverId,
		createdAt = party.createdAt,
		expiresAt = party.expiresAt,
	}
end

-- Fiesta recién creada: el anfitrión ya es el primer miembro y el código caduca dentro de
-- Lobby.partyLifetimeSec.
function LobbyRules.newParty(code: string, hostId: number, serverId: string, now: number): Party
	return {
		code = code,
		hostId = hostId,
		members = { hostId },
		serverId = serverId,
		createdAt = now,
		expiresAt = now + Lobby.partyLifetimeSec,
	}
end

function LobbyRules.isExpired(party: Party, now: number): boolean
	return now >= party.expiresAt
end

function LobbyRules.isMember(party: Party, userId: number): boolean
	return table.find(party.members, userId) ~= nil
end

function LobbyRules.isHost(party: Party, userId: number): boolean
	return party.hostId == userId
end

-- ¿Puede este jugador entrar en la fiesta? Devuelve el motivo en español cuando no, para que el
-- servicio lo enseñe tal cual sin teletransportar. Un miembro que repite la petición no es un
-- error: la operación es idempotente.
function LobbyRules.canJoin(party: Party?, userId: number, now: number): (boolean, string?)
	if party == nil then
		return false, "No hay ninguna party con ese código. Revisa las seis letras."
	end
	if LobbyRules.isMember(party, userId) then
		return true, nil
	end
	if LobbyRules.isExpired(party, now) then
		return false, "Ese código ha caducado. Pide uno nuevo al anfitrión."
	end
	if #party.members >= Lobby.maxPlayers then
		return false, `La party está llena: caben {Lobby.maxPlayers} jugadores como máximo.`
	end
	return true, nil
end

-- Fiesta con el jugador dentro, o nil y el motivo. El orden de `members` es el de llegada y es lo
-- que decide quién hereda el puesto de anfitrión.
function LobbyRules.join(party: Party?, userId: number, now: number): (Party?, string?)
	local allowed, reason = LobbyRules.canJoin(party, userId, now)
	if not allowed or party == nil then
		return nil, reason
	end
	if LobbyRules.isMember(party, userId) then
		return party, nil
	end
	local updated = copyParty(party)
	table.insert(updated.members, userId)
	return updated, nil
end

-- Fiesta sin el jugador. Devuelve nil cuando no queda nadie (la fiesta desaparece) y, si se va el
-- anfitrión, el siguiente en llegar hereda el puesto.
function LobbyRules.leave(party: Party, userId: number): Party?
	local remaining: { number } = {}
	for _, member in party.members do
		if member ~= userId then
			table.insert(remaining, member)
		end
	end
	if #remaining == 0 then
		return nil
	end
	local updated = copyParty(party)
	updated.members = remaining
	if LobbyRules.isHost(party, userId) then
		updated.hostId = remaining[1]
	end
	return updated
end

-- ¿Puede este jugador arrancar la partida? Solo el anfitrión, con el código vigente y al menos
-- Lobby.minPlayers dentro.
function LobbyRules.canStart(party: Party?, userId: number, now: number): (boolean, string?)
	if party == nil then
		return false, "No estás en ninguna party."
	end
	if LobbyRules.isExpired(party, now) then
		return false, "Ese código ha caducado. Crea una party nueva."
	end
	if not LobbyRules.isHost(party, userId) then
		return false, "Solo el anfitrión puede empezar la partida."
	end
	if #party.members < Lobby.minPlayers then
		return false, `Hace falta al menos {Lobby.minPlayers} jugadores para empezar.`
	end
	return true, nil
end

-- Regla de arranque de la cola pública (R-P13): de 2 a 8, empieza al llegar a queueStartAt o, como
-- muy tarde, a los queueWaitSec segundos con los que haya. Con menos de minPlayers nunca empieza y
-- con más de maxPlayers tampoco: el servicio no deja crecer la cola hasta ahí.
function LobbyRules.shouldStartQueue(count: number, waitedSec: number): boolean
	if count < Lobby.minPlayers or count > Lobby.maxPlayers then
		return false
	end
	if count >= Lobby.queueStartAt then
		return true
	end
	return waitedSec >= Lobby.queueWaitSec
end

-- Datos de una partida pública: siempre en Rondas.
function LobbyRules.queueData(seed: number, size: number): MatchData
	return { seed = seed, endMode = "Rounds", code = nil, size = size }
end

-- Datos de una party: el código para el registro del servidor de partida y el modo que eligió el
-- anfitrión.
function LobbyRules.partyData(
	seed: number,
	code: string,
	endMode: Types.EndMode,
	size: number,
	settings: any?
): MatchData
	return {
		seed = seed,
		endMode = endMode,
		code = code,
		size = size,
		settings = MatchSettings.normalize(settings),
	}
end

-- Reintenta `attempt` hasta `attempts` veces, esperando Lobby.teleportRetrySec entre intentos.
-- La espera entra por parámetro (`task.wait` en el servidor) para que la regla siga siendo pura.
-- Devuelve el último motivo cuando se agotan los intentos, para poder avisar sin inventarlo.
function LobbyRules.retry(
	attempt: () -> (boolean, string?),
	attempts: number,
	wait: (number) -> ()
): (boolean, string?)
	local total = math.max(attempts, 1)
	local reason: string? = nil
	for index = 1, total do
		local ok, message = attempt()
		if ok then
			return true, nil
		end
		reason = message
		if index < total then
			wait(Lobby.teleportRetrySec)
		end
	end
	return false, reason
end

return LobbyRules

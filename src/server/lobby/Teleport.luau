--!strict
-- Teletransporte (R-P12): interfaz propia con una implementación real sobre TeleportService y una
-- versión que rechaza con un mensaje claro donde el servicio no funciona (Studio). La reserva usa
-- TeleportOptions.ReservedServerId, que es la vía vigente: ReserveServerAsync y
-- TeleportToPrivateServer están obsoletas en la documentación oficial.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local Lobby = require("../../shared/config/Lobby")
local LobbyRules = require("./LobbyRules")

export type Teleport = {
	reserve: (players: { Player }, data: LobbyRules.MatchData) -> (boolean, string?),
	-- Salto lobby → lobby cuando la party vive en otro servidor del lobby.
	toServer: (
		player: Player,
		placeId: number,
		serverId: string,
		data: LobbyRules.JoinData
	) -> (boolean, string?),
}

-- Mensaje para el jugador. El detalle técnico va a `warn`, no a la interfaz.
local TELEPORT_ERROR = "No se pudo preparar el servidor de la partida."

local Teleport = {}

local function optionsFor(data: any): TeleportOptions
	local options = Instance.new("TeleportOptions") :: TeleportOptions
	options:SetTeleportData(data)
	return options
end

-- Fallos posteriores a la llamada: la API avisa por TeleportInitFailed cuando el teletransporte se
-- aceptó pero el jugador no llegó a salir. El evento entrega las opciones exactas del destino, así
-- que reintentar al jugador no lo manda a otro servidor. Se acota por jugador con los intentos de
-- config; al agotarse, el fallo queda en el registro en vez de dejar al jugador en silencio.
local function watchFailures()
	local failures: { [number]: number } = {}
	TeleportService.TeleportInitFailed:Connect(function(player, result, message, placeId, options)
		local count = (failures[player.UserId] or 0) + 1
		failures[player.UserId] = count
		if count > Lobby.teleportAttempts then
			warn(`Teleport: no se pudo llevar a {player.Name}: {tostring(result)} {message}`)
			return
		end
		task.wait(Lobby.teleportRetrySec)
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(placeId, { player }, options)
		end)
		if not ok then
			warn(`Teleport: el reintento de {player.Name} falló: {tostring(err)}`)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		failures[player.UserId] = nil
	end)
end

-- Implementación real. `matchPlaceId` es el lugar de partida: quien monta el servidor lo lee de
-- config y comprueba antes que esté publicado (R-P31).
function Teleport.live(matchPlaceId: number): Teleport
	watchFailures()
	return {
		reserve = function(players: { Player }, data: LobbyRules.MatchData): (boolean, string?)
			if #players == 0 then
				return false, "No hay jugadores que teletransportar."
			end
			local ok, err = pcall(function()
				local options = optionsFor(data)
				options.ReservedServerId = HttpService:GenerateGUID(false)
				TeleportService:TeleportAsync(matchPlaceId, players, options)
			end)
			if ok then
				return true, nil
			end
			warn(`Teleport: no se pudo reservar el servidor de la partida: {tostring(err)}`)
			return false, TELEPORT_ERROR
		end,
		toServer = function(
			player: Player,
			placeId: number,
			serverId: string,
			data: LobbyRules.JoinData
		): (boolean, string?)
			if serverId == "" then
				return false, "El servidor de la party ya no está disponible."
			end
			local ok, err = pcall(function()
				local options = optionsFor(data)
				options.ServerInstanceId = serverId
				TeleportService:TeleportAsync(placeId, { player }, options)
			end)
			if ok then
				return true, nil
			end
			warn(`Teleport: no se pudo llevar a {player.Name} al servidor de su party: {tostring(err)}`)
			return false, "No se pudo conectar con el servidor de la party."
		end,
	}
end

-- Implementación para lugares donde TeleportService no funciona (Studio). No finge que el grupo
-- se ha movido: contesta con el motivo, y el servicio lo enseña tal cual.
function Teleport.unavailable(reason: string): Teleport
	return {
		reserve = function(): (boolean, string?)
			return false, reason
		end,
		toServer = function(): (boolean, string?)
			return false, reason
		end,
	}
end

return Teleport

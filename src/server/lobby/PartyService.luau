--!strict
-- Servicio de party: códigos, miembros, cambio de anfitrión y arranque de la partida en un
-- servidor reservado. Todo lo que no se puede probar con Lune (MemoryStoreService y
-- TeleportService) entra por adaptadores inyectables (R-P12); las decisiones viven en LobbyRules,
-- que es puro. El lobby es otro lugar de Roblox: este módulo no requiere nada de src/server/match
-- (R-P11).
local Players = game:GetService("Players")

local Lobby = require("../../shared/config/Lobby")
local Places = require("../../shared/config/Places")
local Rng = require("../../shared/rules/Rng")
local Types = require("../../shared/rules/Types")
local LobbyRules = require("./LobbyRules")
local PartyCode = require("./PartyCode")
local PartyStore = require("./PartyStore")
local Teleport = require("./Teleport")

export type Notify = (player: Player, message: string, kind: string?) -> ()

-- Dependencias que el punto de cableado inyecta. `store` y `teleport` son los adaptadores de
-- R-P12; `now` es el reloj sincronizado del servidor (Workspace:GetServerTimeNow), porque la
-- caducidad se compara entre servidores; `serverId` es el JobId del servidor del lobby ("" en
-- Studio).
export type Adapters = {
	store: PartyStore.Store,
	teleport: Teleport.Teleport,
	notify: Notify,
	seed: () -> number,
	now: () -> number,
	serverId: string,
}

local PartyService = {}

local adapters: Adapters? = nil
-- Código de la party de cada jugador de este servidor. La lista de miembros vive en el almacén;
-- aquí solo se recuerda qué fiesta es la suya para poder salir y para saber quién arranca.
local codeByUser: { [number]: string } = {}
-- Arranques en curso por código: un doble clic del anfitrión no puede reservar dos servidores.
local starting: { [string]: boolean } = {}
-- Generador de códigos del servidor. Se siembra en configure y avanza con cada party nueva.
local rng: Rng.RngState = Rng.new(1)

local function current(): Adapters
	local config = adapters
	if config == nil then
		error("PartyService: falta configure antes de usarlo", 2)
	end
	return config :: Adapters
end

local function notify(player: Player, message: string, kind: string?)
	current().notify(player, message, kind)
end

local function notifyAll(players: { Player }, message: string, kind: string?)
	for _, player in players do
		notify(player, message, kind)
	end
end

-- Saca al jugador de una party concreta. Si era el anfitrión, avisa a quien hereda el puesto; si
-- la fiesta se queda vacía, se borra del almacén. La lista de miembros solo contiene jugadores de
-- este servidor: un ingreso desde otro servidor se completa al llegar (joinCodeOf).
local function leaveCode(userId: number, code: string)
	local config = current()
	local previousHost: number? = nil
	local updated = config.store.update(code, function(party: LobbyRules.Party?): (LobbyRules.Party?, string?)
		if party == nil then
			return nil, "La party ya no existe."
		end
		previousHost = party.hostId
		return LobbyRules.leave(party, userId)
	end)
	-- UpdateAsync devuelve nil cuando la transformación cancela: puede ser que la fiesta ya no
	-- esté o que se quedara sin miembros. En los dos casos no queda nada que guardar.
	if updated == nil then
		config.store.remove(code)
		return
	end
	if previousHost == userId and updated.hostId ~= userId then
		local nextHost = Players:GetPlayerByUserId(updated.hostId)
		if nextHost then
			notify(nextHost, `Ahora eres el anfitrión de la party {code}.`, "Info")
		end
	end
end

-- Deja la party que el jugador tuviera, si la tenía.
local function leaveParty(userId: number)
	local code: string? = codeByUser[userId]
	if code == nil then
		return
	end
	codeByUser[userId] = nil
	leaveCode(userId, code)
end

-- Código de party que trae un jugador al llegar a este servidor del lobby. Solo existe cuando el
-- jugador viene del salto lobby → lobby que hace join desde otro servidor; en un ingreso normal,
-- GetJoinData no trae TeleportData y no se hace nada.
local function joinCodeOf(player: Player): string?
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	if not ok or type(joinData) ~= "table" then
		return nil
	end
	local teleportData: any = joinData.TeleportData
	if type(teleportData) ~= "table" then
		return nil
	end
	local code = teleportData.party
	if type(code) ~= "string" then
		return nil
	end
	return code
end

local function onPlayerAdded(player: Player)
	if adapters == nil then
		return
	end
	local code = joinCodeOf(player)
	if code ~= nil then
		PartyService.join(player, code)
	end
end

local function onPlayerRemoving(player: Player)
	if adapters == nil then
		return
	end
	leaveParty(player.UserId)
end

-- Arranca el servicio una sola vez por servidor: guarda los adaptadores y conecta las salidas y
-- los ingresos que completan un salto entre servidores del lobby.
function PartyService.configure(config: Adapters)
	if adapters ~= nil then
		return
	end
	adapters = config
	rng = Rng.new(config.seed())
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- Un jugador que ya estuviera dentro cuando arranca el script (Studio) tampoco se queda fuera
	-- del salto lobby → lobby, aunque lo normal es que no haya ninguno todavía.
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

-- Crea una party y devuelve su código. Si el jugador ya estaba en una, la abandona primero. Un
-- fallo del almacén devuelve "" y un aviso: no hay código que compartir.
function PartyService.create(host: Player): string
	local config = current()
	local userId = host.UserId
	leaveParty(userId)
	local code: string? = nil
	for _ = 1, Lobby.codeAttempts do
		local candidate = PartyCode.generate(rng)
		if config.store.get(candidate) == nil then
			code = candidate
			break
		end
	end
	if code == nil then
		notify(host, "No se pudo crear la party. Inténtalo otra vez.", "Error")
		return ""
	end
	local party = LobbyRules.newParty(code, userId, config.serverId, config.now())
	if not config.store.set(code, party) then
		notify(host, "No se pudo crear la party. Inténtalo otra vez.", "Error")
		return ""
	end
	codeByUser[userId] = code
	notify(host, `Party creada. Comparte el código {code} con tu grupo.`, "PartyCode")
	return code
end

-- Une al jugador a la party del código. Mayúsculas, minúsculas y espacios no importan. Un código
-- inexistente, caducado o completo devuelve false con un mensaje claro y no teletransporta. Si la
-- fiesta vive en otro servidor del lobby, el jugador viaja al del anfitrión y el ingreso se
-- completa al llegar (onPlayerAdded).
function PartyService.join(player: Player, code: string): (boolean, string?)
	local config = current()
	local normalized = PartyCode.normalize(code)
	if normalized == nil then
		local message = "Ese código no es válido: son seis caracteres, sin 0, O, 1 ni I."
		notify(player, message, "Error")
		return false, message
	end
	local userId = player.UserId
	local previous: string? = codeByUser[userId]
	if previous == normalized then
		local currentParty = config.store.get(normalized)
		if currentParty ~= nil and not LobbyRules.isExpired(currentParty, config.now()) then
			notify(player, `Ya estás en la party {normalized}.`, "Info")
			return true, nil
		end
		-- La fiesta ya no está o caducó: se olvida y el flujo normal da el mensaje que toca.
		codeByUser[userId] = nil
		previous = nil
	end

	local found = config.store.get(normalized)
	local now = config.now()
	if found ~= nil and LobbyRules.isExpired(found, now) then
		config.store.remove(normalized)
		local message = "Ese código ha caducado. Pide uno nuevo al anfitrión."
		notify(player, message, "Error")
		return false, message
	end

	if found ~= nil and found.serverId ~= config.serverId then
		local allowed, reason = LobbyRules.canJoin(found, userId, now)
		if not allowed then
			local message = reason or "No se puede entrar en la party."
			notify(player, message, "Error")
			return false, message
		end
		local targetServer = found.serverId
		-- Un solo intento: reintentar aquí retendría el manejador del remoto y multiplicaría los
		-- teletransportes. Si falla, el jugador repite la petición y se vuelve a intentar entero.
		local ok, failure =
			config.teleport.toServer(player, game.PlaceId, targetServer, { party = normalized })
		if not ok then
			local message = "No se pudo llevar al servidor de la party. Inténtalo otra vez."
			warn(`PartyService: al llevar al servidor de la party {normalized}: {failure}`)
			notify(player, message, "Error")
			return false, message
		end
		-- El jugador sigue en su party anterior hasta que el PlayerRemoving de la salida lo saca;
		-- si el viaje falla, no ha perdido nada.
		notify(player, "Te llevamos al servidor de la party. Espera un momento.", "Info")
		return true, nil
	end

	local joined, reason = config.store.update(
		normalized,
		function(party: LobbyRules.Party?): (LobbyRules.Party?, string?)
			return LobbyRules.join(party, userId, now)
		end
	)
	if joined == nil then
		local message = reason or "No se pudo entrar en la party."
		notify(player, message, "Error")
		return false, message
	end
	-- Ya está en la nueva: solo ahora se abandona la anterior. Un código equivocado no echa al
	-- jugador de la party donde estaba.
	if previous ~= nil then
		codeByUser[userId] = nil
		leaveCode(userId, previous)
	end
	codeByUser[userId] = normalized
	notify(player, `Ya estás en la party {normalized}.`, "Info")
	return true, nil
end

-- Arranca la partida de la party. Solo el anfitrión, con el código vigente y al menos 2 miembros.
-- Con el lugar de partida sin publicar no se intenta teletransportar: se contesta que falta
-- publicarlo (R-P31). Un fallo del teletransporte se reintenta y, si persiste, el grupo sigue en
-- el lobby con un aviso.
function PartyService.start(host: Player, endMode: Types.EndMode, settings: any?): (boolean, string?)
	local config = current()
	local userId = host.UserId
	local code: string? = codeByUser[userId]
	if code == nil then
		local message = "No estás en ninguna party."
		notify(host, message, "Error")
		return false, message
	end
	if starting[code] then
		local message = "La partida ya está empezando."
		notify(host, message, "Info")
		return false, message
	end
	local party = config.store.get(code)
	if party == nil then
		codeByUser[userId] = nil
		local message = "Tu party ya no existe. Crea una nueva."
		notify(host, message, "Error")
		return false, message
	end
	local allowed, reason = LobbyRules.canStart(party, userId, config.now())
	if not allowed then
		local message = reason or "No se puede empezar la partida."
		notify(host, message, "Error")
		return false, message
	end
	if Places.matchId == Places.unpublished then
		local message = "El lugar de partida aún no está publicado."
		notify(host, message, "Error")
		return false, message
	end

	local players: { Player } = {}
	for _, memberId in party.members do
		local member = Players:GetPlayerByUserId(memberId)
		if member ~= nil and member.Parent ~= nil then
			table.insert(players, member)
		end
	end
	if #players < Lobby.minPlayers then
		local message = `Hace falta al menos {Lobby.minPlayers} jugadores para empezar.`
		notify(host, message, "Error")
		return false, message
	end

	starting[code] = true
	local data = LobbyRules.partyData(config.seed(), code, endMode, #players, settings)
	local ok, failure = LobbyRules.retry(function(): (boolean, string?)
		return config.teleport.reserve(players, data)
	end, Lobby.teleportAttempts, task.wait)
	starting[code] = nil
	if not ok then
		local message =
			"No se pudo crear el servidor de la partida. Seguís en el lobby; inténtalo otra vez."
		warn(`PartyService: al reservar el servidor de la party {code}: {failure}`)
		notifyAll(players, message, "Error")
		return false, message
	end

	-- El grupo ya viaja: el código deja de servir y no se puede volver a usar para entrar.
	config.store.remove(code)
	for _, member in party.members do
		codeByUser[member] = nil
	end
	notifyAll(players, "La partida empieza. Os llevamos al servidor reservado.", "Info")
	return true, nil
end

return PartyService

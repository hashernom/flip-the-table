--!strict
-- Almacén de fiestas (R-P12): interfaz propia con una implementación real sobre
-- MemoryStoreService y otra en memoria para Studio y pruebas. La real nunca lanza hacia arriba:
-- cada llamada va protegida y un fallo se devuelve como ausencia, para que el lobby siga
-- funcionando en local si el servicio no está disponible (por ejemplo, en un lugar sin publicar).
local Lobby = require("../../shared/config/Lobby")
local LobbyRules = require("./LobbyRules")

export type Party = LobbyRules.Party

-- Transformación atómica: recibe la fiesta actual (nil si no existe) y devuelve la nueva, o nil
-- para cancelar sin tocar lo guardado. El segundo valor es el motivo del rechazo, si lo hay.
export type Transform = (party: Party?) -> (Party?, string?)

export type Store = {
	get: (code: string) -> Party?,
	set: (code: string, party: Party) -> boolean,
	remove: (code: string) -> (),
	update: (code: string, transform: Transform) -> (Party?, string?),
}

-- Nombre global del hash map de fiestas. Todas las instancias del lobby del juego comparten uno.
local HASH_MAP_NAME = "FlipTheTableParties"

local PartyStore = {}

-- Valida y copia lo que llega del almacén. Un dato de otra versión o corrupto se descarta en vez
-- de romper el lobby, y los miembros se copian para que nadie mute lo guardado.
local function asParty(value: any): Party?
	if type(value) ~= "table" then
		return nil
	end
	local code = value.code
	local hostId = value.hostId
	local serverId = value.serverId
	local createdAt = value.createdAt
	local expiresAt = value.expiresAt
	local rawMembers = value.members
	if type(code) ~= "string" or type(serverId) ~= "string" then
		return nil
	end
	if type(hostId) ~= "number" or type(createdAt) ~= "number" or type(expiresAt) ~= "number" then
		return nil
	end
	if type(rawMembers) ~= "table" then
		return nil
	end
	local members: { number } = {}
	for index, member in rawMembers do
		if type(index) ~= "number" or index % 1 ~= 0 or index < 1 then
			return nil
		end
		if type(member) ~= "number" then
			return nil
		end
		members[index] = member
	end
	return {
		code = code,
		hostId = hostId,
		members = members,
		serverId = serverId,
		createdAt = createdAt,
		expiresAt = expiresAt,
	}
end

-- Almacén en memoria: el que usan Studio y las pruebas, y el respaldo local cuando MemoryStore
-- falla. Copia al entrar y al salir para que devolver una fiesta no permita mutar el almacén.
function PartyStore.memory(): Store
	local parties: { [string]: Party } = {}
	return {
		get = function(code: string): Party?
			return asParty(parties[code])
		end,
		set = function(code: string, party: Party): boolean
			local stored = asParty(party)
			if stored == nil then
				return false
			end
			parties[code] = stored
			return true
		end,
		remove = function(code: string)
			parties[code] = nil
		end,
		update = function(code: string, transform: Transform): (Party?, string?)
			local updated, reason = transform(asParty(parties[code]))
			if updated == nil then
				return nil, reason
			end
			local stored = asParty(updated)
			if stored == nil then
				return nil, reason
			end
			parties[code] = stored
			return asParty(stored), reason
		end,
	}
end

-- Implementación real sobre un MemoryStoreHashMap. Un hash map es lo adecuado para buscar por
-- clave (el código) sin orden. La caducidad del almacén es mayor que la del código para poder
-- distinguir «caducado» de «no existe».
local function fromService(service: MemoryStoreService): Store
	local hasMap, map = pcall(function()
		return service:GetHashMap(HASH_MAP_NAME)
	end)
	if not hasMap then
		return PartyStore.memory()
	end
	return {
		get = function(code: string): Party?
			local ok, value = pcall(function()
				return map:GetAsync(code)
			end)
			if not ok then
				return nil
			end
			return asParty(value)
		end,
		set = function(code: string, party: Party): boolean
			local saved = pcall(function()
				map:SetAsync(code, party, Lobby.storeExpirationSec)
			end)
			return saved
		end,
		remove = function(code: string)
			pcall(function()
				map:RemoveAsync(code)
			end)
		end,
		update = function(code: string, transform: Transform): (Party?, string?)
			local reason: string? = nil
			local ok, value = pcall(function()
				return map:UpdateAsync(code, function(current: any): any
					local updated, why = transform(asParty(current))
					reason = why
					return updated
				end, Lobby.storeExpirationSec)
			end)
			if not ok then
				return nil, nil
			end
			return asParty(value), reason
		end,
	}
end

-- Almacén real, o nil si el servicio ni siquiera existe en esta versión del motor.
function PartyStore.memoryStore(): Store?
	local ok, service = pcall(function(): MemoryStoreService
		return game:GetService("MemoryStoreService") :: MemoryStoreService
	end)
	if not ok then
		return nil
	end
	return fromService(service :: MemoryStoreService)
end

-- Envuelve el almacén real con un respaldo en memoria: cada escritura va a los dos y cada
-- lectura consulta primero el real. Si MemoryStore no responde, la fiesta creada en este servidor
-- sigue existiendo en local en vez de dar un error al jugador (el lobby «funciona en local»).
function PartyStore.resilient(primary: Store, fallback: Store): Store
	return {
		get = function(code: string): Party?
			local party = primary.get(code)
			if party ~= nil then
				return party
			end
			return fallback.get(code)
		end,
		set = function(code: string, party: Party): boolean
			local saved = primary.set(code, party)
			-- El respaldo en memoria siempre acepta: la fiesta local existe aunque MemoryStore
			-- esté caído, y el lobby no debe contestar un error por eso.
			local fallbackSaved = fallback.set(code, party)
			return saved or fallbackSaved
		end,
		remove = function(code: string)
			primary.remove(code)
			fallback.remove(code)
		end,
		update = function(code: string, transform: Transform): (Party?, string?)
			local updated, reason = primary.update(code, transform)
			if reason ~= nil then
				return nil, reason
			end
			if updated ~= nil then
				fallback.set(code, updated)
				return updated, nil
			end
			return fallback.update(code, transform)
		end,
	}
end

-- El almacén que usa el lobby: real con respaldo en local, o solo en memoria si el servicio no
-- está. Quien monta el servidor decide si conviene llamarlo (en Studio no hay lugar publicado).
function PartyStore.default(): Store
	local primary = PartyStore.memoryStore()
	if primary == nil then
		return PartyStore.memory()
	end
	return PartyStore.resilient(primary, PartyStore.memory())
end

return PartyStore

--!strict
-- Perfil mínimo del jugador: cuántas partidas ha terminado. La primera partida guiada lo usa para que
-- solo quien no ha terminado ninguna vea los consejos. Hoy lo arranca solo el lugar de partida; vive en
-- la carpeta del lobby porque los dos lugares comparten el almacén del universo y el lobby lo usará.
--
-- En Studio usa un almacén en memoria y no toca datos reales; fuera de Studio, un DataStore. El valor
-- se publica en el atributo `CompletedMatches` del jugador para que el cliente lo lea sin otro remoto.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

export type Profile = { completedMatches: number }

export type Store = {
	load: (userId: number) -> Profile?,
	save: (userId: number, profile: Profile) -> boolean,
}

local PlayerProfile = {}

PlayerProfile.ATTRIBUTE = "CompletedMatches"
-- Nombre del almacén; la versión va en el nombre para poder cambiar la forma sin migrar a ciegas.
PlayerProfile.STORE_NAME = "PlayerProfile_v1"
-- Lo que espera el cierre del servidor a los guardados pendientes; Roblox da 30 s en total.
PlayerProfile.CLOSE_WAIT_SEC = 20

-- Perfil válido a partir de lo que devuelva el almacén: cualquier cosa rara cuenta como cero.
function PlayerProfile.normalize(raw: any): Profile
	local count = if type(raw) == "table" then raw.completedMatches else nil
	if type(count) ~= "number" or count ~= count or count < 0 then
		count = 0
	end
	return { completedMatches = math.floor(count) }
end

function PlayerProfile.memory(): Store
	local profiles: { [number]: Profile } = {}
	return {
		load = function(userId: number): Profile?
			local stored = profiles[userId]
			return if stored ~= nil then PlayerProfile.normalize(stored) else nil
		end,
		save = function(userId: number, profile: Profile): boolean
			profiles[userId] = PlayerProfile.normalize(profile)
			return true
		end,
	}
end

function PlayerProfile.dataStore(): Store
	local store = DataStoreService:GetDataStore(PlayerProfile.STORE_NAME)
	return {
		load = function(userId: number): Profile?
			local ok, value = pcall(function()
				return store:GetAsync(tostring(userId))
			end)
			if not ok then
				warn(`PlayerProfile: no se pudo leer el perfil de {userId}: {value}`)
				return nil
			end
			return PlayerProfile.normalize(value)
		end,
		save = function(userId: number, profile: Profile): boolean
			local ok, err = pcall(function()
				store:UpdateAsync(tostring(userId), function(old: any)
					-- Nunca baja: otro servidor pudo sumar una partida entre medias.
					local previous = PlayerProfile.normalize(old)
					local next = PlayerProfile.normalize(profile)
					local count = math.max(previous.completedMatches, next.completedMatches)
					return { completedMatches = count }
				end)
			end)
			if not ok then
				warn(`PlayerProfile: no se pudo guardar el perfil de {userId}: {err}`)
			end
			return ok
		end,
	}
end

local store: Store? = nil
local cache: { [number]: Profile } = {}
local started = false
-- Guardados en curso: el cierre del servidor los espera para no perder una partida terminada.
local pending = 0

local function storeOf(): Store
	local current = store
	if current ~= nil then
		return current
	end
	local chosen = if RunService:IsStudio() then PlayerProfile.memory() else PlayerProfile.dataStore()
	store = chosen
	return chosen
end

local function publish(player: Player, profile: Profile)
	cache[player.UserId] = profile
	player:SetAttribute(PlayerProfile.ATTRIBUTE, profile.completedMatches)
end

-- Perfil conocido del jugador. Mientras no se ha cargado, cero partidas.
function PlayerProfile.get(player: Player): Profile
	local cached = cache[player.UserId]
	return if cached ~= nil then cached else { completedMatches = 0 }
end

local function load(player: Player)
	local loaded = storeOf().load(player.UserId)
	-- Si el almacén falla no se publica nada: el cliente no guía a quien no sabe si es nuevo. Si una
	-- partida terminó mientras se leía, la cuenta en memoria manda: la lectura vieja no la pisa.
	if loaded ~= nil and player.Parent ~= nil then
		local known = cache[player.UserId]
		local count = math.max(loaded.completedMatches, if known ~= nil then known.completedMatches else 0)
		publish(player, { completedMatches = count })
	end
end

-- Suma una partida terminada al jugador y la guarda.
function PlayerProfile.recordFinished(player: Player)
	local profile = { completedMatches = PlayerProfile.get(player).completedMatches + 1 }
	publish(player, profile)
	pending += 1
	task.spawn(function()
		storeOf().save(player.UserId, profile)
		pending -= 1
	end)
end

-- Sustituye el almacén. Para las pruebas y para decidir otro destino antes de `start`.
function PlayerProfile.useStore(custom: Store)
	store = custom
end

function PlayerProfile.start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(load, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		cache[player.UserId] = nil
	end)
	game:BindToClose(function()
		local deadline = os.clock() + PlayerProfile.CLOSE_WAIT_SEC
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerProfile

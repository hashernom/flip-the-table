--!strict
-- Mesas del parque: quien se sienta junto a otros en una mesa entra en partida con ellos. Escucha los
-- asientos de `LobbyWorld`, lleva la cuenta con `TableRules` y, cuando toca, teletransporta a los sentados
-- como una partida pública (configuración por defecto, modo Rondas). El cartel de cada mesa dice cuántos
-- hay y cuánto falta.
local Players = game:GetService("Players")

local Lobby = require("../../shared/config/Lobby")
local LobbyRules = require("./LobbyRules")
local LobbyWorld = require("./LobbyWorld")
local Places = require("../../shared/config/Places")
local TableRules = require("./TableRules")
local Teleport = require("./Teleport")

export type Config = {
	teleport: Teleport.Teleport,
	notify: (player: Player, message: string, kind: string?) -> (),
	seed: () -> number,
	now: () -> number,
}

local TableService = {}

local function playerOn(seat: Seat): Player?
	local humanoid = seat.Occupant
	if humanoid == nil then
		return nil
	end
	return Players:GetPlayerFromCharacter(humanoid.Parent)
end

function TableService.start(world: LobbyWorld.World, config: Config)
	type Entry = { rules: TableRules.Table, handles: LobbyWorld.TableHandles, bySeat: { [Seat]: number } }
	local entries: { Entry } = {}

	local function launch(entry: Entry)
		local rules = entry.rules
		local players: { Player } = {}
		for _, userId in rules.seated do
			local player = Players:GetPlayerByUserId(userId)
			if player ~= nil then
				table.insert(players, player)
			end
		end
		if #players < Lobby.minPlayers then
			TableRules.reset(rules, config.now())
			return
		end
		rules.starting = true
		if Places.matchId == Places.unpublished then
			for _, player in players do
				config.notify(player, "El lugar de partida aún no está publicado.", "Error")
			end
			task.wait(2)
			TableRules.reset(rules, config.now())
			return
		end
		local data = LobbyRules.queueData(config.seed(), #players)
		local ok, failure = LobbyRules.retry(function(): (boolean, string?)
			return config.teleport.reserve(players, data)
		end, Lobby.teleportAttempts, task.wait)
		if not ok then
			warn(`TableService: no se pudo llevar a la mesa {rules.id} a la partida: {failure}`)
			for _, player in players do
				config.notify(
					player,
					"No se pudo crear el servidor de la partida. Seguís en el lobby; inténtalo otra vez.",
					"Error"
				)
			end
			TableRules.reset(rules, config.now())
		end
		-- Si salió bien, los jugadores se van y sus asientos se vacían solos.
	end

	for id, handles in world.tables do
		local entry: Entry = { rules = TableRules.new(id, #handles.seats), handles = handles, bySeat = {} }
		table.insert(entries, entry)
		for _, seat in handles.seats do
			seat:GetPropertyChangedSignal("Occupant"):Connect(function()
				local now = config.now()
				local previous = entry.bySeat[seat]
				if previous ~= nil then
					entry.bySeat[seat] = nil
					TableRules.leave(entry.rules, previous, now)
				end
				local player = playerOn(seat)
				if player ~= nil and TableRules.sit(entry.rules, player.UserId, now) then
					entry.bySeat[seat] = player.UserId
				end
			end)
		end
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		for _, entry in entries do
			TableRules.leave(entry.rules, player.UserId, config.now())
		end
	end)

	task.spawn(function()
		while true do
			local now = config.now()
			for _, entry in entries do
				entry.handles.label.Text = TableRules.label(entry.rules, now)
				if TableRules.ready(entry.rules, now) then
					task.spawn(launch, entry)
				end
			end
			task.wait(Lobby.tableTickSec)
		end
	end)
end

return TableService

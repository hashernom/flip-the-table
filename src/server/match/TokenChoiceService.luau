--!strict
-- Reparto de fichas entre los asientos. No es una acción del motor: el servidor solo guarda quién
-- lleva cada ficha, impide repetirla y avisa a todos. La elección se cierra cuando alguien sale de la
-- Salida; a partir de ahí el reparto queda congelado hasta la revancha.
local Workspace = game:GetService("Workspace")

local Protocol = require("../../shared/net/Protocol")
local TokenChoice = require("../../shared/rules/TokenChoice")
local MatchService = require("./MatchService")
local Remotes = require("../Remotes")

local TokenChoiceService = {}

local assignments: TokenChoice.Assignments = {}
local assignedRemote: RemoteEvent? = nil
local limiter = Protocol.newLimiter()

local function broadcast()
	local remote = assignedRemote
	if remote == nil then
		return
	end
	remote:FireAllClients(assignments)
end

local function positionsOf(match: MatchService.Match): { number }
	local positions: { number } = {}
	for _, player in match.state.players do
		table.insert(positions, player.position)
	end
	return positions
end

-- Reparto inicial al arrancar cada partida, también en una revancha. Los bots también tienen asiento
-- y ficha: el resto del grupo los ve circular.
local function reset(match: MatchService.Match)
	local ids: { string } = {}
	for _, player in match.state.players do
		table.insert(ids, player.id)
	end
	assignments = TokenChoice.defaults(ids)
	broadcast()
end

function TokenChoiceService.start()
	assignedRemote = Remotes.remote(Protocol.REMOTES.TokenAssigned)
	local requestRemote = Remotes.remote(Protocol.REMOTES.TokenChoice)
	MatchService.onStart(reset)

	requestRemote.OnServerEvent:Connect(function(player: Player, tokenId: any)
		local match = MatchService.current()
		if match == nil then
			return
		end
		if not limiter.allow(tostring(player.UserId), Workspace:GetServerTimeNow()) then
			return
		end
		-- Sin id es una petición del reparto actual: el cliente que llega tarde no se queda sin fichas.
		if tokenId == nil then
			local remote = assignedRemote
			if remote ~= nil then
				remote:FireClient(player, assignments)
			end
			return
		end
		if match.finished then
			return
		end
		if not Protocol.validateTokenChoice(tokenId) then
			return
		end
		local playerId = tostring(player.UserId)
		if TokenChoice.locked(positionsOf(match)) then
			local remote = assignedRemote
			if remote ~= nil then
				remote:FireClient(player, assignments, "La partida ya empezó: la ficha queda como está.")
			end
			return
		end
		local ok, err = TokenChoice.choose(assignments, playerId, tokenId)
		if ok then
			broadcast()
			return
		end
		local remote = assignedRemote
		if remote ~= nil then
			remote:FireClient(player, assignments, err)
		end
	end)
end

return TokenChoiceService

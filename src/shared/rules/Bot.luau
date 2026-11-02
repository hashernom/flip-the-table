--!strict
-- Bot determinista: elige entre las acciones legales con una heurística simple. No usa azar
-- ni relojes; la simulación lo usará para jugar partidas completas sin humano.
local Building = require("./Building")
local Economy = require("../config/Economy")
local Engine = require("./Engine")
local Types = require("./Types")

type GameState = Types.GameState
type PlayerId = Types.PlayerId
type Player = Types.Player
type Action = Types.Action

local Bot = {}

local function findPlayer(state: GameState, playerId: PlayerId): Player?
	for _, player in state.players do
		if player.id == playerId then
			return player
		end
	end
	return nil
end

-- Primera acción del tipo pedido dentro de la lista legal; nil si no hay ninguna.
local function firstOf(actions: { Action }, actionType: string): Action?
	for _, action in actions do
		if action.type == actionType then
			return action
		end
	end
	return nil
end

local function pendingIndexOf(state: GameState): number?
	local pending = state.pending
	if not pending then
		return nil
	end
	return pending.index
end

local function priceOf(state: GameState, index: number): number?
	local square = state.board.squares[index]
	if not square then
		return nil
	end
	return square.price
end

-- Construcción más barata que deja al bot por encima de su reserva; nil si ninguna cumple.
local function cheapestBuild(state: GameState, player: Player, actions: { Action }): Action?
	local best: Action? = nil
	local bestCost = math.huge
	for _, action in actions do
		if action.type == "Build" then
			local cost = Building.costOf(state, player.id, action.index)
			if player.cash - cost > Economy.bot.buildReserve and cost < bestCost then
				best = action
				bestCost = cost
			end
		end
	end
	return best
end

-- Acción elegida. Devuelve nil cuando no hay ninguna legal o cuando, en una subasta, no le
-- compensa pujar: el bucle de simulación cierra con Engine.timeout. Nunca inventa una acción.
function Bot.choose(state: GameState, playerId: PlayerId): Action?
	local actions = Engine.legalActions(state, playerId)
	if #actions == 0 then
		return nil
	end
	local player = findPlayer(state, playerId)
	if not player then
		return nil
	end
	local phase = state.phase
	if phase == "AwaitRoll" then
		return firstOf(actions, "Roll")
	elseif phase == "AwaitBuy" then
		local buy = firstOf(actions, "Buy")
		if buy then
			local index = pendingIndexOf(state)
			local price = if index then priceOf(state, index) else nil
			if price and player.cash - price > Economy.bot.buyReserve then
				return buy
			end
		end
		return firstOf(actions, "DeclineBuy")
	elseif phase == "AwaitEnd" then
		local build = cheapestBuild(state, player, actions)
		if build then
			return build
		end
		return firstOf(actions, "EndTurn")
	elseif phase == "Auction" then
		local bid = firstOf(actions, "Bid")
		if not bid then
			return nil
		end
		local pending = state.pending
		local auction = if pending then pending.auction else nil
		if auction and auction.highBidder == playerId then
			return nil
		end
		if player.cash - bid.amount > Economy.bot.bidReserve then
			return bid
		end
		return nil
	elseif phase == "Reaction" then
		-- En la ventana el bot solo usa Escudo: cancelar una carta que le apunta es gratis. Renta
		-- Rebotada exigiría elegir a un tercero y la respuesta simple y legal es pasar.
		local reactAction = firstOf(actions, "React")
		if reactAction and reactAction.cardId == "Shield" then
			return reactAction
		end
		return firstOf(actions, "PassReaction")
	end
	return nil
end

return Bot

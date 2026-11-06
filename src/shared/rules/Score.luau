--!strict
-- Patrimonio y clasificación. Solo cuenta lo propio: efectivo, precios y edificios.
local Board = require("./Board")
local Economy = require("../config/Economy")
local Types = require("./Types")

type GameState = Types.GameState
type PlayerId = Types.PlayerId
type Player = Types.Player

type RankingEntry = {
	id: PlayerId,
	worth: number,
	cash: number,
	position: number,
}

local Score = {}

local function findPlayer(state: GameState, playerId: PlayerId): Player?
	for _, player in state.players do
		if player.id == playerId then
			return player
		end
	end
	return nil
end

local function playerOf(state: GameState, playerId: PlayerId): Player
	local player = findPlayer(state, playerId)
	if not player then
		error(`Score: no existe el jugador {playerId}`, 3)
	end
	return player
end

local function priceOf(state: GameState, index: number): number
	local price = Board.square(state, index).price
	if not price then
		error(`Score: la casilla {index} no es una propiedad`, 3)
	end
	return price
end

-- Coste de cada nivel de edificio, con la misma fórmula que Building.costOf. Score no puede
-- require Building: el contrato solo le permite Board, Economy y Types.
local function levelCost(price: number): number
	return math.floor(price * Economy.buildingCostRate)
end

-- Patrimonio = efectivo + Σ(precio + nivel × coste de nivel) de las casillas propias.
function Score.netWorth(state: GameState, playerId: PlayerId): number
	local player = playerOf(state, playerId)
	local total = player.cash
	for index, property in state.properties do
		if property.ownerId == playerId then
			local price = priceOf(state, index)
			total += price + property.level * levelCost(price)
			-- R-P53: una hipotecada vale el precio menos lo que ya dio la hipoteca.
			if property.mortgaged then
				total -= math.floor(price * Economy.mortgage.rate)
			end
		end
	end
	return total
end

-- Clasificación completa: patrimonio desc, efectivo desc y posición en state.players asc.
-- El último desempate hace el orden total, así que dos partidas iguales clasifican igual.
function Score.ranking(state: GameState): { PlayerId }
	local entries: { RankingEntry } = {}
	for position, player in state.players do
		table.insert(entries, {
			id = player.id,
			worth = Score.netWorth(state, player.id),
			cash = player.cash,
			position = position,
		})
	end
	table.sort(entries, function(left, right)
		if left.worth ~= right.worth then
			return left.worth > right.worth
		end
		if left.cash ~= right.cash then
			return left.cash > right.cash
		end
		return left.position < right.position
	end)
	local ranking: { PlayerId } = {}
	for index, entry in entries do
		ranking[index] = entry.id
	end
	return ranking
end

return Score

--!strict
-- Robo de cartas: rareza por posición en la clasificación y rondas sin legendaria,
-- carta uniforme dentro de la rareza y mano máxima de Economy.handLimit.
local Cards = require("../config/Cards")
local Economy = require("../config/Economy")
local Rng = require("./Rng")
local Score = require("./Score")
local Types = require("./Types")

type GameState = Types.GameState
type PlayerId = Types.PlayerId
type Rarity = Types.Rarity
type Event = Types.Event

export type RarityWeights = Cards.RarityWeights

-- Milésimas de punto porcentual: los pesos de la tabla son múltiplos de 0,05, así que
-- ninguna rareza con peso positivo se pierde por redondeo.
local WEIGHT_UNITS = 1000

local Deck = {}

local function playerOf(state: GameState, playerId: PlayerId): Types.Player
	for _, player in state.players do
		if player.id == playerId then
			return player
		end
	end
	error(`Deck: no existe el jugador {playerId}`, 3)
end

-- Puesto en la clasificación (1 = líder) y número de clasificados.
local function rankOf(state: GameState, playerId: PlayerId): (number, number)
	local ranking = Score.ranking(state)
	for rank, id in ranking do
		if id == playerId then
			return rank, #ranking
		end
	end
	error(`Deck: no existe el jugador {playerId}`, 3)
end

-- El líder es el primero; la mitad superior, los puestos 2..ceil(n/2); el resto, la inferior.
local function baseWeights(rank: number, count: number): RarityWeights
	if rank == 1 then
		return Cards.positionWeights.Leader
	elseif rank <= math.ceil(count / 2) then
		return Cards.positionWeights.UpperHalf
	end
	return Cards.positionWeights.LowerHalf
end

-- Pesos del robo en puntos porcentuales. Siempre suman 100, y la común completa el total.
function Deck.weights(state: GameState, playerId: PlayerId): RarityWeights
	local rank, count = rankOf(state, playerId)
	local base = baseWeights(rank, count)
	local rounds = state.round - (state.lastLegendaryRound or 0)
	local capped = math.clamp(rounds, 0, #Cards.legendaryRoundMultipliers - 1)
	local multiplier = Cards.legendaryRoundMultipliers[capped + 1]
	local legendary = base.Legendary * multiplier
	-- La rara no cambia y la común completa hasta 100.
	return {
		Common = 100 - base.Rare - legendary,
		Rare = base.Rare,
		Legendary = legendary,
	}
end

local function weightUnits(weight: number): number
	return math.floor(weight * WEIGHT_UNITS + 0.5)
end

local function checkMinRarity(minRarity: Rarity?)
	if minRarity == nil or minRarity == "Common" or minRarity == "Rare" or minRarity == "Legendary" then
		return
	end
	error(`Deck.draw: la rareza mínima "{minRarity}" no existe`, 3)
end

-- Elige el montón de una rareza elegible por peso, renormalizando entre las que permite
-- minRarity: nil o Common deja las tres, Rare deja rara y legendaria, y Legendary solo esa.
local function pickPool(rng: Rng.RngState, weights: RarityWeights, minRarity: Rarity?): { Cards.CardDef }
	local legendary = weightUnits(weights.Legendary)
	local rare = weightUnits(weights.Rare)
	local common = weightUnits(weights.Common)
	if minRarity == "Legendary" then
		rare, common = 0, 0
	elseif minRarity == "Rare" then
		common = 0
	end
	local total = legendary + rare + common
	if total <= 0 then
		error("Deck.draw: ninguna rareza elegible tiene peso", 3)
	end
	local roll = Rng.int(rng, 1, total)
	if roll <= legendary then
		return Cards.byRarity.Legendary
	elseif roll <= legendary + rare then
		return Cards.byRarity.Rare
	end
	return Cards.byRarity.Common
end

-- Roba una carta para la mano o la descarta si está llena. La legendaria siempre marca la
-- ronda, aunque no quepa en la mano, y todo robo cuenta en stats.cardsDrawn.
function Deck.draw(state: GameState, playerId: PlayerId, minRarity: Rarity?): { Event }
	checkMinRarity(minRarity)
	local player = playerOf(state, playerId)
	local pool = pickPool(state.rng, Deck.weights(state, playerId), minRarity)
	local card = Rng.pick(state.rng, pool)
	if card.rarity == "Legendary" then
		state.lastLegendaryRound = state.round
	end
	local stats = state.stats[playerId]
	stats.cardsDrawn = (stats.cardsDrawn or 0) + 1
	if #player.hand >= Economy.handLimit then
		return { { type = "CardDiscarded", playerId = playerId, cardId = card.id } }
	end
	table.insert(player.hand, card.id)
	return { { type = "CardDrawn", playerId = playerId, cardId = card.id } }
end

return Deck

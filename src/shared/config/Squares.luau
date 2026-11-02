--!strict
-- Valores de las casillas nuevas de la fase 03. Los que ya viven en Economy (Impuesto, Portal,
-- Duelo y Tribunal) se leen de allí para que la arquitectura tenga una sola fuente de verdad.
local Economy = require("./Economy")
local Types = require("../rules/Types")

-- Resultado de una tirada de la Cartelera de la Suerte. El orden de `results` reparte el peso
-- uniforme entre los cinco.
export type BillboardResult = "BigPrize" | "SmallPrize" | "Fine" | "Card" | "Nothing"

-- Importe de un premio de la Cartelera: normal y con el perk Afortunado.
export type BillboardPrize = { normal: number, lucky: number }

-- Elección secreta del Duelo. El orden de `duelChoices` es el que ofrece el motor.
export type DuelChoice = "Rock" | "Paper" | "Scissors"

-- Precio del Mercado Negro por rareza: la carta vale lo que vale su montón.
export type MarketPrices = { Common: number, Rare: number, Legendary: number }

export type SquaresConfig = {
	-- Una carta visible por rareza, a precio fijo.
	market: {
		rarities: { Types.Rarity },
		prices: MarketPrices,
	},
	duel: {
		winnerPrize: number,
		loserStepsBack: number,
		maxRounds: number,
	},
	duelChoices: { DuelChoice },
	portalToll: number,
	billboard: {
		results: { BillboardResult },
		bigPrize: BillboardPrize,
		smallPrize: BillboardPrize,
		fine: number,
	},
	tribunal: {
		fine: number,
		payToPlayer: number,
		skipTurns: number,
		voteSeconds: number,
	},
	tax: number,
}

-- Una carta de cada rareza: son las tres visibles del Mercado.
local MARKET_RARITIES: { Types.Rarity } = { "Common", "Rare", "Legendary" }
local MARKET_PRICES: MarketPrices = { Common = 100, Rare = 200, Legendary = 300 }

local Squares: SquaresConfig = {
	market = {
		rarities = MARKET_RARITIES,
		prices = MARKET_PRICES,
	},
	duel = {
		winnerPrize = Economy.duel.winnerPrize,
		loserStepsBack = Economy.duel.loserStepsBack,
		maxRounds = Economy.duel.maxRounds,
	},
	duelChoices = { "Rock", "Paper", "Scissors" },
	portalToll = Economy.portalToll,
	billboard = {
		-- Peso igual para los cinco resultados; nunca se pide apostar ni arriesgar nada.
		results = { "BigPrize", "SmallPrize", "Fine", "Card", "Nothing" },
		bigPrize = { normal = 200, lucky = 300 },
		smallPrize = { normal = 100, lucky = 150 },
		fine = 100,
	},
	tribunal = {
		fine = Economy.tribunal.fine,
		payToPlayer = Economy.tribunal.payToPlayer,
		skipTurns = Economy.tribunal.skipTurns,
		voteSeconds = Economy.seconds.tribunalVote,
	},
	tax = Economy.tax,
}

return Squares

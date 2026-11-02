--!strict
-- Tipos compartidos del motor. Contrato descrito en docs/01-arquitectura/arquitectura.md.
local Rng = require("./Rng")

export type RngState = Rng.RngState

export type PlayerId = string
export type SizeId = "S" | "M" | "L"
export type PlayerStatus = "Active" | "Ghost" | "Left"
export type Rarity = "Common" | "Rare" | "Legendary"

export type Phase =
	"PerkDraft"
	| "AwaitRoll"
	| "AwaitBuy"
	| "Auction"
	| "Reaction"
	| "Tribunal"
	| "Duel"
	| "Market"
	| "AwaitEnd"
	| "GhostTurn"
	| "GameOver"

export type SquareKind =
	"Start"
	| "Property"
	| "Spin"
	| "Market"
	| "Duel"
	| "Portal"
	| "Billboard"
	| "Tribunal"
	| "Tax"

export type Square = {
	index: number,
	kind: SquareKind,
	zoneId: string?,
	barrioId: string,
	price: number?,
}

export type Board = {
	sizeId: SizeId,
	squares: { Square },
	zones: { [string]: { number } },
}

export type PropertyState = {
	ownerId: PlayerId?,
	level: number,
}

export type Player = {
	id: PlayerId,
	isBot: boolean,
	status: PlayerStatus,
	cash: number,
	position: number,
	hand: { string },
	perks: { string },
	fury: number,
	sabotages: number,
	skipTurns: number,
	traitorUntilRound: number?,
	damageReducedRound: number?,
}

export type Pact = {
	id: string,
	a: PlayerId,
	b: PlayerId,
	depositA: number,
	depositB: number,
	untilRound: number,
}

export type Modifier = {
	kind: "Inflation" | "Blackout" | "Haunt" | "Discount",
	zoneId: string?,
	index: number?,
	playerId: PlayerId?,
	untilRound: number,
}

export type MatchStats = {
	[PlayerId]: { [string]: number },
}

export type GameState = {
	rng: RngState,
	sizeId: SizeId,
	board: Board,
	players: { Player },
	turnIndex: number,
	round: number,
	maxRounds: number,
	phase: Phase,
	pending: any?,
	properties: { [number]: PropertyState },
	pacts: { Pact },
	modifiers: { Modifier },
	hotZoneId: string?,
	lastLegendaryRound: number?,
	hurricaneUsed: boolean,
	stats: MatchStats,
}

export type Action = { type: string, [string]: any }
export type Event = { type: string, [string]: any }
export type ApplyResult = { ok: true, events: { Event } } | { ok: false, error: string }

-- Vista filtrada que recibe cada jugador. La subfase 04 fija sus campos en View.
export type PlayerView = {
	playerId: PlayerId,
	sizeId: SizeId,
	round: number,
	maxRounds: number,
	phase: Phase,
	turnIndex: number,
	[string]: any,
}

return {}

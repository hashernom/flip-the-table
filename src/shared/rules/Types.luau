--!strict
-- Tipos compartidos del motor. Contrato descrito en docs/01-arquitectura/arquitectura.md.
local Rng = require("./Rng")

export type RngState = Rng.RngState

export type PlayerId = string
export type SizeId = "S" | "M" | "L"
export type PlayerStatus = "Active" | "Ghost" | "Left"
export type Rarity = "Common" | "Rare" | "Legendary"
-- Rounds: la partida termina al superar el tope de rondas del tamaño. Endless: sin tope.
export type EndMode = "Rounds" | "Endless"

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
	-- Zonas en orden de ruta. Usar esta lista al elegir con Rng: un diccionario no tiene orden estable.
	zoneOrder: { string },
}

export type PropertyState = {
	ownerId: PlayerId?,
	level: number,
	-- R-P53: hipotecada. No cobra renta y su zona no admite obras. nil equivale a false.
	mortgaged: boolean?,
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
	kind: "Inflation" | "Strike" | "Haunt" | "Discount",
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
	endMode: EndMode,
	round: number,
	maxRounds: number?,
	phase: Phase,
	pending: any?,
	properties: { [number]: PropertyState },
	pacts: { Pact },
	modifiers: { Modifier },
	hotZoneId: string?,
	lastLegendaryRound: number?,
	stats: MatchStats,
	-- Usos reales de cada perk por jugador (Tarea 10): { [perkId]: número de veces que su efecto
	-- se aplicó }. Es un contador aparte de `stats` porque cada entrada es un mapa, no un número.
	perkUses: { [PlayerId]: { [string]: number } },
}

export type Action = { type: string, [string]: any }
export type Event = { type: string, [string]: any }
export type ApplyResult = { ok: true, events: { Event } } | { ok: false, error: string }

-- Jugador tal como lo ve un espectador concreto: los datos públicos de la mesa más la mano, que
-- solo viaja en la vista de su dueño. En las demás, `hand` no existe y `handCount` es lo único que
-- se sabe (View.forPlayer es el único sitio que decide).
export type ViewPlayer = {
	id: PlayerId,
	isBot: boolean,
	status: PlayerStatus,
	cash: number,
	position: number,
	perks: { string },
	fury: number,
	sabotages: number,
	skipTurns: number,
	traitorUntilRound: number?,
	damageReducedRound: number?,
	handCount: number,
	hand: { string }?,
}

-- Vista filtrada que recibe cada jugador. La produce View.forPlayer y es la única forma en que el
-- estado del servidor llega al cliente: no incluye `rng`, ni manos ajenas, ni las decisiones
-- privadas de `pending` (View las quita). El tablero no viaja: es estático y se reconstruye con
-- config/Boards a partir de `sizeId`.
export type PlayerView = {
	playerId: PlayerId,
	sizeId: SizeId,
	endMode: EndMode,
	round: number,
	-- 0 en Sin Fin: «sin tope». El contrato lo fija como número, no como nil.
	maxRounds: number,
	phase: Phase,
	turnIndex: number,
	players: { ViewPlayer },
	properties: { [number]: PropertyState },
	pacts: { Pact },
	modifiers: { Modifier },
	hotZoneId: string?,
	stats: MatchStats,
	-- Estado de paso ya filtrado: sin jugadas ajenas del Duelo, papeletas ajenas del Tribunal ni
	-- la mano del Espía cuando el jugador no jugó la carta.
	pending: any?,
	-- Acciones legales de este jugador, calculadas por Engine.legalActions.
	legalActions: { Action },
}

return {}

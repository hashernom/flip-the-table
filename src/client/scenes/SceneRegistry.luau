--!strict
-- Registro de escenas: qué escena reproduce cada evento y cada carta. Es solo datos, sin `Instance`, para
-- que la prueba de `config/Scenes` compruebe con Lune que ningún id se queda sin escena.
--
-- "Placeholder" es la escena provisional (`PlaceholderScene`). Cada tarea del plan 08 cambia aquí el
-- nombre de las escenas que termina. Las escenas que necesitan el estado del cliente (fichas, cámara) se
-- siguen registrando en el director desde `main.client`; este registro dice cuál les toca.
local Scenes = require("../../shared/config/Scenes")

local PLACEHOLDER = "Placeholder"

-- Escenas definitivas ya hechas. Todo id de `Scenes.allIds()` que no esté aquí usa la provisional.
local FINAL: { [string]: string } = {
	TokenMoved = "TokenRide",
	DiceRolled = "game/Dice",
	PortalUsed = "PortalJump",
	BillboardResult = "game/GameScenes",
	PlayerArrested = "Arrest",
	Hurricane = "legendary/Hurricane",
	WorldFlip = "legendary/WorldFlip",
	Revolution = "legendary/Revolution",
	Earthquake = "legendary/Earthquake",
	CrownStrike = "legendary/CrownStrike",
	DeedThief = "cards/DeedThief",
	Demolition = "cards/Demolition",
	Strike = "cards/Strike",
	Inflation = "cards/Inflation",
	Backstab = "cards/Backstab",
	BounceRent = "cards/BounceRent",
	Shield = "cards/CommonCards",
	CardBlocked = "cards/CommonCards",
	ExtraDie = "cards/CommonCards",
	Reverse = "cards/CommonCards",
	ForcedTip = "cards/CommonCards",
	Discount = "cards/CommonCards",
	Shove = "cards/CommonCards",
	Fine = "cards/CommonCards",
	Bribe = "cards/CommonCards",
	Spy = "cards/CommonCards",
	DuelResolved = "squares/SquareScenes",
	MarketBought = "squares/SquareScenes",
	CardDrawn = "squares/SquareScenes",
	TaxPaid = "squares/SquareScenes",
	RentPaid = "game/GameScenes",
	BuildingChanged = "game/GameScenes",
	PropertyMortgaged = "game/GameScenes",
	PropertyUnmortgaged = "game/GameScenes",
	AuctionStarted = "game/GameScenes",
	AuctionNoSale = "game/GameScenes",
	BankruptcyDeclared = "game/GameScenes",
	PactFormed = "game/GameScenes",
	PactBroken = "game/GameScenes",
	CrownMoved = "game/GameScenes",
	FuryFilled = "game/GameScenes",
	GhostActed = "game/GameScenes",
	GhostResurrected = "game/GameScenes",
	PassedStart = "game/GameScenes",
	TradeCompleted = "game/GameScenes",
	HotZoneMoved = "game/GameScenes",
	FinalRoundsStarted = "game/GameScenes",
	RoundStarted = "game/GameScenes",
	GameEnded = "game/GameScenes",
	TribunalVerdict = "game/GameScenes",
	PactEnded = "game/GameScenes",
	PerkDrafted = "game/GameScenes",
	CardDiscarded = "game/GameScenes",
	PropertyBought = "SettleNow",
	AuctionWon = "SettleNow",
}

local byId: { [string]: string } = {}
for _, id in Scenes.allIds() do
	byId[id] = FINAL[id] or PLACEHOLDER
end
-- Un id de FINAL que no existe en Scenes (un nombre mal escrito) también entra: así la prueba lo detecta.
for id, name in FINAL do
	byId[id] = name
end

local SceneRegistry = {}

SceneRegistry.PLACEHOLDER = PLACEHOLDER

-- Ids con escena registrada, ordenados.
function SceneRegistry.ids(): { string }
	local ids: { string } = {}
	for id in byId do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

-- Nombre de la escena de un id, o nil si no tiene.
function SceneRegistry.sceneFor(id: string): string?
	return byId[id]
end

return SceneRegistry

--!strict
-- Arte de las 20 cartas de giro y de los 12 perks. Los PNG salen de `art/ui/cards/` y `art/ui/perks/`,
-- que generan `build_cards.py` y `build_perks.py`, y ya están en `art/manifest.json` como `UiImage` en
-- `Draft`. Un `assetId` vacío significa «aún sin subir: la interfaz se lee solo con el texto».

export type Art = { manifestId: string, assetId: string }

local function entry(manifestId: string): Art
	return { manifestId = manifestId, assetId = "" }
end

-- En el orden de `Cards.all`.
local CARDS: { [string]: Art } = {
	Hurricane = entry("ui-card-hurricane"),
	WorldFlip = entry("ui-card-world-flip"),
	Revolution = entry("ui-card-revolution"),
	Earthquake = entry("ui-card-earthquake"),
	CrownStrike = entry("ui-card-crown-strike"),
	Inflation = entry("ui-card-inflation"),
	Strike = entry("ui-card-strike"),
	BounceRent = entry("ui-card-bounce-rent"),
	DeedThief = entry("ui-card-deed-thief"),
	Backstab = entry("ui-card-backstab"),
	Demolition = entry("ui-card-demolition"),
	Shield = entry("ui-card-shield"),
	ExtraDie = entry("ui-card-extra-die"),
	Reverse = entry("ui-card-reverse"),
	ForcedTip = entry("ui-card-forced-tip"),
	Discount = entry("ui-card-discount"),
	Shove = entry("ui-card-shove"),
	Fine = entry("ui-card-fine"),
	Bribe = entry("ui-card-bribe"),
	Spy = entry("ui-card-spy"),
}

-- En el orden de `Perks.all`.
local PERKS: { [string]: Art } = {
	Banker = entry("ui-perk-banker"),
	Landlord = entry("ui-perk-landlord"),
	Builder = entry("ui-perk-builder"),
	Smuggler = entry("ui-perk-smuggler"),
	QuickFingers = entry("ui-perk-quick-fingers"),
	Lawyer = entry("ui-perk-lawyer"),
	Negotiator = entry("ui-perk-negotiator"),
	Lucky = entry("ui-perk-lucky"),
	Hunter = entry("ui-perk-hunter"),
	Armored = entry("ui-perk-armored"),
	Collector = entry("ui-perk-collector"),
	RestlessSoul = entry("ui-perk-restless-soul"),
}

local CardArt = {}

CardArt.cards = CARDS
CardArt.perks = PERKS

-- Banda de caliza donde el juego escribe el nombre, en fracciones de la carta: el PNG mide 312 x 450
-- y la banda va de (6, 294) a (306, 416).
CardArt.band = {
	left = 6 / 312,
	top = 294 / 450,
	width = 300 / 312,
	height = 122 / 450,
}

-- Ancho partido por alto del PNG de la carta: 312 x 450.
CardArt.ASPECT = 312 / 450

function CardArt.card(id: string): Art?
	return CARDS[id]
end

function CardArt.perk(id: string): Art?
	return PERKS[id]
end

function CardArt.image(art: Art?): string
	if not art then
		return ""
	end
	return art.assetId
end

return CardArt

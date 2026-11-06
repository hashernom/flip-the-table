--!strict
-- Arte de las 20 cartas de giro y de los 12 perks. Los PNG salen de `art/ui/cards/` y `art/ui/perks/`,
-- que generan `build_cards.py` y `build_perks.py`, y ya están en `art/manifest.json` como `UiImage` en
-- `Draft`. Un `assetId` vacío significa «aún sin subir: la interfaz se lee solo con el texto».

export type Art = { manifestId: string, assetId: string }

local function entry(manifestId: string, assetId: string): Art
	return { manifestId = manifestId, assetId = assetId }
end

-- En el orden de `Cards.all`.
local CARDS: { [string]: Art } = {
	Hurricane = entry("ui-card-hurricane", "rbxassetid://73780338575237"),
	WorldFlip = entry("ui-card-world-flip", "rbxassetid://124690280946295"),
	Revolution = entry("ui-card-revolution", "rbxassetid://108167739493809"),
	Earthquake = entry("ui-card-earthquake", "rbxassetid://119717448628377"),
	CrownStrike = entry("ui-card-crown-strike", "rbxassetid://93128990375345"),
	Inflation = entry("ui-card-inflation", "rbxassetid://127519695549281"),
	Strike = entry("ui-card-strike", "rbxassetid://138782295951180"),
	BounceRent = entry("ui-card-bounce-rent", "rbxassetid://86754457987032"),
	DeedThief = entry("ui-card-deed-thief", "rbxassetid://88651299675423"),
	Backstab = entry("ui-card-backstab", "rbxassetid://139777750885354"),
	Demolition = entry("ui-card-demolition", "rbxassetid://113717002181933"),
	Shield = entry("ui-card-shield", "rbxassetid://73409136423236"),
	ExtraDie = entry("ui-card-extra-die", "rbxassetid://94023691931449"),
	Reverse = entry("ui-card-reverse", "rbxassetid://134770997642306"),
	ForcedTip = entry("ui-card-forced-tip", "rbxassetid://74726845908121"),
	Discount = entry("ui-card-discount", "rbxassetid://130225987617771"),
	Shove = entry("ui-card-shove", "rbxassetid://95806449304729"),
	Fine = entry("ui-card-fine", "rbxassetid://124007651257971"),
	Bribe = entry("ui-card-bribe", "rbxassetid://90278748996138"),
	Spy = entry("ui-card-spy", "rbxassetid://99257532450859"),
}

-- En el orden de `Perks.all`.
local PERKS: { [string]: Art } = {
	Banker = entry("ui-perk-banker", "rbxassetid://75124212267239"),
	Landlord = entry("ui-perk-landlord", "rbxassetid://106022355297473"),
	Builder = entry("ui-perk-builder", "rbxassetid://79407175260161"),
	Smuggler = entry("ui-perk-smuggler", "rbxassetid://96984499208901"),
	QuickFingers = entry("ui-perk-quick-fingers", "rbxassetid://98227439566361"),
	Lawyer = entry("ui-perk-lawyer", "rbxassetid://117589388800439"),
	Negotiator = entry("ui-perk-negotiator", "rbxassetid://71276111108341"),
	Lucky = entry("ui-perk-lucky", "rbxassetid://86183165709339"),
	Hunter = entry("ui-perk-hunter", "rbxassetid://87947090916339"),
	Armored = entry("ui-perk-armored", "rbxassetid://100524042139286"),
	Collector = entry("ui-perk-collector", "rbxassetid://128249471277338"),
	RestlessSoul = entry("ui-perk-restless-soul", "rbxassetid://78516036994888"),
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

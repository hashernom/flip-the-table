--!strict
-- Datos de las 20 cartas de giro y de las tablas del robo por rareza.
-- Los efectos viven en src/shared/rules/Cards; aquí solo hay datos.
local Types = require("../rules/Types")

export type CardTarget = "None" | "Player" | "Zone" | "Property" | "Pact"

export type CardDef = {
	id: string,
	name: string,
	rarity: Types.Rarity,
	target: CardTarget,
	reaction: boolean,
	leaderOnly: boolean?,
}

-- Peso base del robo por posición en la clasificación, en puntos porcentuales.
export type RarityWeights = { Common: number, Rare: number, Legendary: number }

-- Montones por rareza, en el orden de Cards.all.
export type CardPools = {
	Common: { CardDef },
	Rare: { CardDef },
	Legendary: { CardDef },
}

-- Orden de la tabla «Cartas de giro» de la ficha: legendarias, raras y comunes.
local ALL: { CardDef } = {
	{ id = "Hurricane", name = "Huracán", rarity = "Legendary", target = "None", reaction = false },
	{ id = "WorldFlip", name = "Mundo al Revés", rarity = "Legendary", target = "None", reaction = false },
	{ id = "Revolution", name = "Revolución", rarity = "Legendary", target = "None", reaction = false },
	{ id = "Earthquake", name = "Terremoto", rarity = "Legendary", target = "Zone", reaction = false },
	{
		id = "CrownStrike",
		name = "Golpe a la Corona",
		rarity = "Legendary",
		target = "Player",
		reaction = false,
		-- Solo apunta a quien lleva la Corona: el líder de la clasificación.
		leaderOnly = true,
	},
	{ id = "Inflation", name = "Inflación", rarity = "Rare", target = "None", reaction = false },
	{ id = "Strike", name = "Huelga", rarity = "Rare", target = "Zone", reaction = false },
	{ id = "BounceRent", name = "Renta Rebotada", rarity = "Rare", target = "Player", reaction = true },
	{
		id = "DeedThief",
		name = "Ladrón de Escrituras",
		rarity = "Rare",
		target = "Property",
		reaction = false,
	},
	{ id = "Backstab", name = "Puñalada", rarity = "Rare", target = "Pact", reaction = false },
	{ id = "Demolition", name = "Demolición", rarity = "Rare", target = "Property", reaction = false },
	{ id = "Shield", name = "Escudo", rarity = "Common", target = "None", reaction = true },
	{ id = "ExtraDie", name = "Dado Extra", rarity = "Common", target = "None", reaction = false },
	{ id = "Reverse", name = "Marcha Atrás", rarity = "Common", target = "None", reaction = false },
	{ id = "ForcedTip", name = "Propina Forzada", rarity = "Common", target = "None", reaction = false },
	{ id = "Discount", name = "Descuento", rarity = "Common", target = "None", reaction = false },
	{ id = "Shove", name = "Empujón", rarity = "Common", target = "Player", reaction = false },
	{ id = "Fine", name = "Multa", rarity = "Common", target = "Player", reaction = false },
	{ id = "Bribe", name = "Soborno", rarity = "Common", target = "None", reaction = false },
	{ id = "Spy", name = "Espía", rarity = "Common", target = "Player", reaction = false },
}

-- Tabla «Robo de cartas por posición» de la arquitectura (Líder, mitad superior y mitad inferior).
local POSITION_WEIGHTS: {
	Leader: RarityWeights,
	UpperHalf: RarityWeights,
	LowerHalf: RarityWeights,
} = {
	Leader = { Common = 75, Rare = 23, Legendary = 2 },
	UpperHalf = { Common = 70, Rare = 25, Legendary = 5 },
	LowerHalf = { Common = 55, Rare = 30, Legendary = 15 },
}

-- Multiplicador del peso de legendaria por rondas sin ninguna: índice = rondas, con tope en 7.
local LEGENDARY_ROUND_MULTIPLIERS: { number } = { 0.1, 0.25, 0.5, 1, 1.5, 2, 2.5, 3 }

local Cards = {}

Cards.all = ALL
Cards.positionWeights = POSITION_WEIGHTS
Cards.legendaryRoundMultipliers = LEGENDARY_ROUND_MULTIPLIERS

local byId: { [string]: CardDef } = {}
local byRarity: CardPools = { Common = {}, Rare = {}, Legendary = {} }
for _, card in ALL do
	if byId[card.id] then
		error(`Cards: el id {card.id} está repetido`, 2)
	end
	byId[card.id] = card
	if card.rarity == "Legendary" then
		table.insert(byRarity.Legendary, card)
	elseif card.rarity == "Rare" then
		table.insert(byRarity.Rare, card)
	else
		table.insert(byRarity.Common, card)
	end
end
Cards.byId = byId
Cards.byRarity = byRarity

return Cards

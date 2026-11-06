--!strict
-- Contrato del arte de las cartas y los perks: `CardArt` cubre exactamente las cartas de `Cards.all`
-- y los perks de `Perks.all`, con el id del manifiesto derivado del propio id del juego y todavía sin
-- asset subido. Los PNG viven en `art/ui/cards/` y `art/ui/perks/`.
local Harness = require("../harness")
local CardArt = require("../../src/shared/config/CardArt")
local Cards = require("../../src/shared/config/Cards")
local Perks = require("../../src/shared/config/Perks")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

-- `WorldFlip` -> `world-flip`, igual que el id del manifiesto. Se calcula aquí, no se copia del
-- config, para que las dos listas no se puedan desincronizar en silencio.
local function kebab(id: string): string
	local parts: { string } = {}
	local current = ""
	for index = 1, #id do
		local char = string.sub(id, index, index)
		if index > 1 and string.match(char, "%u") then
			table.insert(parts, string.lower(current))
			current = ""
		end
		current = current .. char
	end
	table.insert(parts, string.lower(current))
	return table.concat(parts, "-")
end

-- Vacío mientras el PNG no esté subido; cuando lo esté, `rbxassetid://` y solo dígitos.
local function isAssetId(value: string): boolean
	if value == "" then
		return true
	end
	return string.match(value, "^rbxassetid://%d+$") ~= nil
end

describe("CardArt", function()
	it("toda carta de Cards.all tiene entrada en CardArt.cards", function()
		for _, card in Cards.all do
			local art: CardArt.Art? = CardArt.cards[card.id]
			expect(art ~= nil).toBe(true)
		end
	end)

	it("todo perk de Perks.all tiene entrada en CardArt.perks", function()
		for _, perk in Perks.all do
			local art: CardArt.Art? = CardArt.perks[perk.id]
			expect(art ~= nil).toBe(true)
		end
	end)

	it("no hay cartas de más: las claves son exactamente los ids de Cards.all", function()
		local expected: { [string]: boolean } = {}
		for _, card in Cards.all do
			expected[card.id] = true
		end
		local seen: { [string]: boolean } = {}
		local total = 0
		for id in CardArt.cards do
			total += 1
			expect(expected[id]).toBe(true)
			seen[id] = true
		end
		expect(total).toBe(#Cards.all)
		for _, card in Cards.all do
			expect(seen[card.id]).toBe(true)
		end
	end)

	it("no hay perks de más: las claves son exactamente los ids de Perks.all", function()
		local expected: { [string]: boolean } = {}
		for _, perk in Perks.all do
			expected[perk.id] = true
		end
		local seen: { [string]: boolean } = {}
		local total = 0
		for id in CardArt.perks do
			total += 1
			expect(expected[id]).toBe(true)
			seen[id] = true
		end
		expect(total).toBe(#Perks.all)
		for _, perk in Perks.all do
			expect(seen[perk.id]).toBe(true)
		end
	end)

	it("el manifestId de cada carta es ui-card-<kebab> y el de cada perk ui-perk-<kebab>", function()
		for _, card in Cards.all do
			local art: CardArt.Art = CardArt.cards[card.id]
			expect(art.manifestId).toBe(`ui-card-{kebab(card.id)}`)
		end
		for _, perk in Perks.all do
			local art: CardArt.Art = CardArt.perks[perk.id]
			expect(art.manifestId).toBe(`ui-perk-{kebab(perk.id)}`)
		end
	end)

	it("el assetId es vacío o un rbxassetid:// seguido solo de dígitos", function()
		for id, art in CardArt.cards do
			if not isAssetId(art.assetId) then
				error(`CardArt.cards.{id}: assetId inválido «{art.assetId}»`, 2)
			end
		end
		for id, art in CardArt.perks do
			if not isAssetId(art.assetId) then
				error(`CardArt.perks.{id}: assetId inválido «{art.assetId}»`, 2)
			end
		end
	end)

	it("ningún assetId no vacío se repite entre las 32 imágenes", function()
		local seen: { [string]: string } = {}
		for id, art in CardArt.cards do
			if art.assetId ~= "" then
				expect(seen[art.assetId]).toBe(nil)
				seen[art.assetId] = `carta {id}`
			end
		end
		for id, art in CardArt.perks do
			if art.assetId ~= "" then
				expect(seen[art.assetId]).toBe(nil)
				seen[art.assetId] = `perk {id}`
			end
		end
	end)

	it("la banda del nombre cabe en la carta y ASPECT es 312/450", function()
		local band = CardArt.band
		expect(band.left >= 0).toBe(true)
		expect(band.top >= 0).toBe(true)
		expect(band.left + band.width <= 1).toBe(true)
		expect(band.top + band.height <= 1).toBe(true)
		expect(band.height > 0).toBe(true)
		expect(math.abs(CardArt.ASPECT - 312 / 450) < 1e-9).toBe(true)
	end)

	it("un id que no existe devuelve nil", function()
		expect(CardArt.card("NoExiste")).toBe(nil)
		expect(CardArt.perk("NoExiste")).toBe(nil)
	end)
end)

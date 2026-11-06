--!strict
-- Pruebas de la tabla de escenas (plan 08, Tarea 1). Toda carta y todo evento tiene duración dentro de
-- los límites de la ficha, la lista completa de ids coincide con el registro de escenas, y la variación
-- sale solo de los datos del evento, así que todo el grupo ve la misma.
local Harness = require("../harness")
local CardsConfig = require("../../src/shared/config/Cards")
local Scenes = require("../../src/shared/config/Scenes")
local SceneRegistry = require("../../src/client/scenes/SceneRegistry")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

describe("Scenes: cartas", function()
	it("toda carta tiene escena y duración", function()
		for _, card in CardsConfig.all do
			expect(Scenes.durationFor({ type = "CardPlayed", cardId = card.id }, 0) > 0).toBeTruthy()
		end
	end)

	it("respeta los límites de duración", function()
		for _, card in CardsConfig.all do
			local d = Scenes.durationFor({ type = "CardPlayed", cardId = card.id }, 0)
			if card.rarity == "Legendary" then
				expect(d <= 10).toBeTruthy()
			else
				expect(d >= 2 and d <= 4).toBeTruthy()
			end
		end
	end)
end)

describe("Scenes.allIds", function()
	it("incluye cada carta y cada evento con duración", function()
		local ids = Scenes.allIds()
		for _, card in CardsConfig.all do
			expect(table.find(ids, card.id) ~= nil).toBeTruthy()
		end
		for _, eventType in { "DiceRolled", "PlayerArrested", "GameEnded", "CardPlayed" } do
			expect(table.find(ids, eventType) ~= nil).toBeTruthy()
		end
		for _, id in ids do
			local known = Scenes.baseDuration(id) ~= nil or CardsConfig.byId[id] ~= nil
			expect(known).toBeTruthy()
		end
	end)

	it("no repite ids y va ordenada", function()
		local ids = Scenes.allIds()
		for i = 2, #ids do
			expect(ids[i - 1] < ids[i]).toBeTruthy()
		end
	end)

	it("coincide con los ids del registro de escenas", function()
		expect(SceneRegistry.ids()).toEqual(Scenes.allIds())
		for _, id in Scenes.allIds() do
			expect(SceneRegistry.sceneFor(id) ~= nil).toBeTruthy()
		end
	end)
end)

describe("Scenes.variationFor", function()
	it("da la misma variación a dos eventos iguales", function()
		local a = { type = "RentPaid", payerId = "a", ownerId = "b", amount = 40, square = 3 }
		local b = { square = 3, amount = 40, ownerId = "b", payerId = "a", type = "RentPaid" }
		expect(Scenes.variationFor(a)).toBe(Scenes.variationFor(b))
	end)

	it("se queda entre 1 y el número de variaciones de la escena", function()
		for i = 1, 40 do
			local event = { type = "RentPaid", payerId = `p{i}`, amount = i * 7 }
			local v = Scenes.variationFor(event)
			local count = Scenes.variationCount.RentPaid or 1
			expect(v >= 1 and v <= count and v == math.floor(v)).toBeTruthy()
		end
	end)

	it("una escena sin variaciones siempre da la 1", function()
		expect(Scenes.variationFor({ type = "GameEnded", winnerId = "x" })).toBe(1)
	end)

	it("cambia con los datos del evento, no con el azar", function()
		-- Una escena de prueba con 3 variaciones: 40 eventos distintos tienen que repartirse.
		Scenes.variationCount.SpecOnly = 3
		local seen: { [number]: boolean } = {}
		for i = 1, 40 do
			local v = Scenes.variationFor({ type = "SpecOnly", payerId = `p{i}` })
			expect(v >= 1 and v <= 3).toBeTruthy()
			seen[v] = true
		end
		(Scenes.variationCount :: any).SpecOnly = nil
		local distinct = 0
		for _ in seen do
			distinct += 1
		end
		expect(distinct).toBe(3)
	end)
end)

describe("Scenes: arresto", function()
	it("el arresto es la excepción aprobada de 15 s y no se acorta", function()
		expect(Scenes.durationFor({ type = "PlayerArrested" }, 0)).toBe(15)
		expect(Scenes.durationFor({ type = "PlayerArrested" }, 2)).toBe(15)
	end)
end)

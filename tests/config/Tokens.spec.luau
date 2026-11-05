--!strict
-- Pruebas del catálogo de fichas: ocho vehículos, ids y mallas únicos, búsqueda por id y ficha por
-- defecto válida. El catálogo es datos puros, así que se prueba sin Roblox.
local Harness = require("../harness")
local Tokens = require("../../src/shared/config/Tokens")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

-- Orden de la ficha, tal como lo fija el plan 07 (Tarea 5).
local EXPECTED_IDS = {
	"taxi",
	"limusina",
	"moto",
	"deportivo",
	"food-truck",
	"camion-helados",
	"grua",
	"autobus",
}

describe("Tokens.all", function()
	it("hay ocho fichas, en el orden del plan", function()
		expect(#Tokens.all).toBe(8)
		for index, id in EXPECTED_IDS do
			expect(Tokens.all[index].id).toBe(id)
		end
	end)

	it("cada ficha tiene un id y un prefijo de malla distintos", function()
		local ids: { [string]: boolean } = {}
		local assets: { [string]: boolean } = {}
		for _, token in Tokens.all do
			expect(ids[token.id]).toBe(nil)
			expect(assets[token.asset]).toBe(nil)
			expect(token.asset ~= "").toBe(true)
			ids[token.id] = true
			assets[token.asset] = true
		end
	end)

	it("los prefijos de malla son los de art/blender/tokens", function()
		local expected = { "taxi", "limo", "moto", "sport", "food", "icecream", "tow", "bus" }
		for index, asset in expected do
			expect(Tokens.all[index].asset).toBe(asset)
		end
	end)

	it("cada ficha tiene un punto de asiento con altura positiva", function()
		for _, token in Tokens.all do
			expect(token.seatOffset.y > 0).toBe(true)
			expect(token.seatOffset.z >= 0).toBe(true)
		end
	end)

	it("el taxi usa el asiento de su stats.json", function()
		local taxi = Tokens.byId("taxi") :: Tokens.Token
		expect(taxi.seatOffset.x).toBe(0)
		expect(taxi.seatOffset.y).toBe(0.8)
		expect(taxi.seatOffset.z).toBe(4.6)
	end)
end)

describe("Tokens.byId", function()
	it("devuelve la ficha de cada id", function()
		for _, token in Tokens.all do
			expect(Tokens.byId(token.id)).toBe(token)
		end
	end)

	it("devuelve nil para un id que no existe", function()
		expect(Tokens.byId("avion")).toBe(nil)
		expect(Tokens.byId("")).toBe(nil)
	end)
end)

describe("Tokens.DEFAULT_ID", function()
	it("es una ficha del catálogo, el taxi", function()
		expect(Tokens.DEFAULT_ID).toBe("taxi")
		expect(Tokens.byId(Tokens.DEFAULT_ID) ~= nil).toBe(true)
	end)
end)

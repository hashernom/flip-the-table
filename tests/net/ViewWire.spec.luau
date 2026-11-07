--!strict
-- Pruebas de cómo cruza la vista un RemoteEvent. Las propiedades se indexan por casilla con huecos, y
-- Luau guarda esa tabla mezclando tramo de array (con `nil` dentro) y hash: Roblox no la transmite
-- entera. Lo que viaja tiene que ser un diccionario puro de claves de texto, y el cliente tiene que
-- recuperar exactamente lo que el servidor tenía. Las vistas salen de State y View, no de tablas
-- inventadas: el fallo solo aparece con la forma real del tablero.
local Fixtures = require("../fixtures")
local Harness = require("../harness")
local MatchState = require("../../src/server/match/MatchState")
local View = require("../../src/shared/rules/View")
local ViewWire = require("../../src/shared/net/ViewWire")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

-- Partida con todas las propiedades repartidas entre los jugadores, en orden de casilla.
local function ownedGame(players: number)
	local state = Fixtures.game({ players = players })
	local turn = 0
	for _, property in state.properties do
		turn += 1
		property.ownerId = state.players[(turn - 1) % #state.players + 1].id
	end
	return state
end

local function count(properties: any): number
	local total = 0
	for _ in properties do
		total += 1
	end
	return total
end

describe("ViewWire.encode", function()
	it("la vista sin codificar es una tabla mixta (por eso se perdían propiedades)", function()
		local view = View.forPlayer(ownedGame(5), "P1")
		expect(view.sizeId).toBe("M")
		expect(view.properties[1]).toBe(nil)
		expect(rawlen(view.properties) > 0).toBe(true)
	end)

	for players = 2, 8 do
		it(`deja solo claves de texto y ningún tramo de array ({players} jugadores)`, function()
			local view = View.forPlayer(ownedGame(players), "P1")
			local wire = ViewWire.encode(view)
			for key in wire.properties do
				expect(type(key)).toBe("string")
			end
			expect(rawlen(wire.properties)).toBe(0)
			expect(count(wire.properties)).toBe(count(view.properties))
		end)

		it(`ida y vuelta conserva todas las propiedades y sus dueños ({players} jugadores)`, function()
			local state = ownedGame(players)
			local wire = ViewWire.normalize(ViewWire.encode(View.forPlayer(state, "P1")))
			expect(count(wire.properties)).toBe(count(state.properties))
			for index, property in state.properties do
				expect(wire.properties[index] ~= nil).toBe(true)
				expect(wire.properties[index].ownerId).toBe(property.ownerId)
				expect(wire.properties[index].level).toBe(property.level)
			end
		end)
	end

	it("no muta la vista que recibe", function()
		local view = View.forPlayer(ownedGame(5), "P1")
		local before = view.properties
		ViewWire.encode(view)
		expect(view.properties).toBe(before)
		for key in view.properties do
			expect(type(key)).toBe("number")
		end
	end)

	it("no revienta sin vista o sin propiedades", function()
		expect(ViewWire.encode(nil)).toBe(nil)
		expect(ViewWire.encode({}).properties).toBe(nil)
	end)
end)

describe("MatchState envía la vista codificada", function()
	it("resync manda las propiedades con claves de texto", function()
		local state = ownedGame(5)
		local match = MatchState.begin(0, state.phase, MatchState.decisionKey(state))
		local batch = MatchState.resync(match, state, "P1", 0)
		local properties: any = batch.view.properties
		expect(rawlen(properties)).toBe(0)
		for key in properties do
			expect(type(key)).toBe("string")
		end
		expect(count(properties)).toBe(count(state.properties))
	end)
end)

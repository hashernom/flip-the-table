--!strict
-- Pruebas de la elección de ficha sin repetir: elegir, cambiar y repartir entre jugadores y bots.
-- Es una regla pura, así que se prueba sin Roblox.
local Harness = require("../harness")
local TokenRules = require("../../src/shared/rules/TokenRules")
local Tokens = require("../../src/shared/config/Tokens")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function ids(count: number): { string }
	local out: { string } = {}
	for index = 1, count do
		table.insert(out, `P{index}`)
	end
	return out
end

-- Nombres de las fichas en el orden de `Tokens.all`, para que las pruebas no dependan de un número.
local function tokenIdAt(index: number): string
	return Tokens.all[index].id
end

-- Comprueba que ninguna ficha aparece dos veces en el reparto.
local function distinct(assigned: { [string]: string }): boolean
	local seen: { [string]: boolean } = {}
	for _, tokenId in assigned do
		if seen[tokenId] then
			return false
		end
		seen[tokenId] = true
	end
	return true
end

local function count(map: { [string]: string }): number
	local total = 0
	for _ in map do
		total += 1
	end
	return total
end

describe("TokenRules.choose", function()
	it("acepta una ficha libre y la guarda para ese jugador", function()
		local choices: { [string]: string } = {}
		local ok, reason = TokenRules.choose(choices, "P1", "moto")
		expect(ok).toBe(true)
		expect(reason).toBe(nil)
		expect(choices.P1).toBe("moto")
	end)

	it("rechaza un id que no existe y no toca las elecciones", function()
		local choices: { [string]: string } = { P1 = "moto" }
		local ok, reason = TokenRules.choose(choices, "P2", "avion")
		expect(ok).toBe(false)
		expect(type(reason)).toBe("string")
		expect(choices.P2).toBe(nil)
		expect(choices.P1).toBe("moto")
	end)

	it("rechaza una ficha que ya eligió otro jugador", function()
		local choices: { [string]: string } = { P1 = "moto" }
		local ok, reason = TokenRules.choose(choices, "P2", "moto")
		expect(ok).toBe(false)
		expect(type(reason)).toBe("string")
		expect(choices.P2).toBe(nil)
		expect(choices.P1).toBe("moto")
	end)

	it("elegir la ficha que ya tienes es válido", function()
		local choices: { [string]: string } = { P1 = "moto" }
		local ok = TokenRules.choose(choices, "P1", "moto")
		expect(ok).toBe(true)
		expect(choices.P1).toBe("moto")
	end)

	it("cambiar de ficha libera la anterior para otro jugador", function()
		local choices: { [string]: string } = {}
		expect((TokenRules.choose(choices, "P1", "taxi"))).toBe(true)
		expect((TokenRules.choose(choices, "P1", "moto"))).toBe(true)
		expect(choices.P1).toBe("moto")
		expect((TokenRules.choose(choices, "P2", "taxi"))).toBe(true)
		expect(choices.P2).toBe("taxi")
	end)

	it("no muta las elecciones cuando rechaza", function()
		local choices: { [string]: string } = { P1 = "taxi", P2 = "moto" }
		TokenRules.choose(choices, "P1", "moto")
		TokenRules.choose(choices, "P3", "nada")
		expect(choices).toEqual({ P1 = "taxi", P2 = "moto" })
	end)
end)

describe("TokenRules.assign", function()
	it("con dos jugadores sin elegir, reparte las dos primeras fichas en orden", function()
		local assigned = TokenRules.assign(ids(2), {})
		expect(assigned).toEqual({ P1 = tokenIdAt(1), P2 = tokenIdAt(2) })
	end)

	it("con ocho jugadores sin elegir, da a cada uno una ficha distinta y usa las ocho", function()
		local assigned = TokenRules.assign(ids(8), {})
		expect(count(assigned)).toBe(8)
		expect(distinct(assigned)).toBe(true)
		for index = 1, 8 do
			expect(assigned[`P{index}`]).toBe(tokenIdAt(index))
		end
	end)

	it("respeta la elección válida y da a los demás las libres en orden", function()
		local assigned = TokenRules.assign(ids(3), { P2 = "moto" })
		expect(assigned.P2).toBe("moto")
		expect(assigned.P1).toBe(tokenIdAt(1))
		expect(assigned.P3).toBe(tokenIdAt(2))
	end)

	it("con una elección repetida gana el primero de la lista", function()
		local assigned = TokenRules.assign(ids(2), { P1 = "moto", P2 = "moto" })
		expect(assigned.P1).toBe("moto")
		expect(distinct(assigned)).toBe(true)
		expect(assigned.P2 ~= "moto").toBe(true)
	end)

	it("con un id inexistente, ese jugador recibe una ficha libre", function()
		local assigned = TokenRules.assign(ids(2), { P1 = "avion" })
		expect(assigned.P1).toBe(tokenIdAt(1))
		expect(assigned.P2).toBe(tokenIdAt(2))
	end)

	it("con ocho jugadores y elecciones repetidas o inventadas, sigue siendo un reparto completo", function()
		local choices = { P1 = "moto", P2 = "moto", P3 = "avion", P4 = "moto", P5 = "taxi", P6 = "taxi" }
		local assigned = TokenRules.assign(ids(8), choices)
		expect(count(assigned)).toBe(8)
		expect(distinct(assigned)).toBe(true)
		expect(assigned.P1).toBe("moto")
		expect(assigned.P5).toBe("taxi")
	end)

	it("los bots, que no eligen, reciben las fichas que quedan libres", function()
		-- P1 y P2 son personas; P3 y P4 son bots. Solo P1 eligió.
		local assigned = TokenRules.assign(ids(4), { P1 = "autobus" })
		expect(assigned.P1).toBe("autobus")
		expect(distinct(assigned)).toBe(true)
		expect(count(assigned)).toBe(4)
		expect(assigned.P2).toBe(tokenIdAt(1))
	end)

	it("es determinista: los mismos datos dan el mismo reparto", function()
		local choices = { P2 = "grua" }
		expect(TokenRules.assign(ids(5), choices)).toEqual(TokenRules.assign(ids(5), choices))
	end)

	it("no modifica las elecciones que recibe", function()
		local choices = { P1 = "moto", P2 = "moto" }
		TokenRules.assign(ids(2), choices)
		expect(choices).toEqual({ P1 = "moto", P2 = "moto" })
	end)

	it("un choices corrupto no lanza y nunca repite una ficha", function()
		local corrupt: any = { P1 = 7, P2 = true, P3 = "taxi", P4 = "taxi", P5 = {} }
		local assigned = TokenRules.assign(ids(5), corrupt)
		expect(count(assigned)).toBe(5)
		expect(distinct(assigned)).toBe(true)
		expect(assigned.P3).toBe("taxi")
	end)
end)

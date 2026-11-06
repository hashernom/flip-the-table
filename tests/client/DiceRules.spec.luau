--!strict
-- Pruebas de las reglas puras de los dados 3D (plan 08, Tarea 6): la cara de arriba es siempre la que
-- mandó el servidor.
local DiceRules = require("../../src/client/scenes/game/DiceRules")
local Harness = require("../harness")
local Scenes = require("../../src/shared/config/Scenes")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

type V = { x: number, y: number, z: number }

-- Mismo convenio que `CFrame.Angles(rx, 0, rz)` de Roblox: R = Rx * Rz, así que a un vector se le aplica
-- primero el giro en Z y después el giro en X.
local function rotate(v: V, rx: number, rz: number): V
	local cz, sz = math.cos(rz), math.sin(rz)
	local x1, y1, z1 = v.x * cz - v.y * sz, v.x * sz + v.y * cz, v.z
	local cx, sx = math.cos(rx), math.sin(rx)
	return { x = x1, y = y1 * cx - z1 * sx, z = y1 * sx + z1 * cx }
end

describe("DiceRules.restAngles", function()
	it("cada valor de 1 a 6 queda hacia arriba", function()
		for _, face in DiceRules.FACES do
			local rx, rz = DiceRules.restAngles(face.value)
			local up = rotate(face.normal, rx, rz)
			expect(math.abs(up.y - 1) < 1e-9).toBe(true)
		end
	end)

	it("las caras opuestas suman 7", function()
		for _, a in DiceRules.FACES do
			for _, b in DiceRules.FACES do
				if a.normal.x == -b.normal.x and a.normal.y == -b.normal.y and a.normal.z == -b.normal.z then
					expect(a.value + b.value).toBe(7)
				end
			end
		end
	end)

	it("cada cara tiene tantos puntos como su valor", function()
		for value = 1, 6 do
			expect(#DiceRules.pips(value)).toBe(value)
		end
	end)
end)

describe("DiceRules.values", function()
	it("lee dos dados, o tres con el Dado Extra", function()
		expect(DiceRules.values({ a = 4, b = 3 })).toEqual({ 4, 3 })
		expect(DiceRules.values({ a = 1, b = 6, c = 2 })).toEqual({ 1, 6, 2 })
		expect(DiceRules.total({ 1, 6, 2 })).toBe(9)
	end)

	it("ignora valores fuera de un dado", function()
		expect(DiceRules.values({ a = 0, b = 7, c = 2.5 })).toEqual({})
	end)
end)

describe("DiceRules vuelo", function()
	it("el dado acaba en el suelo, quieto y en su punto", function()
		expect(DiceRules.hop(0.6, 0.6)).toBe(0)
		expect(DiceRules.hop(1, 0.6)).toBe(0)
		expect(DiceRules.spinLeft(0.6, 0.6)).toBe(0)
		expect(DiceRules.travel(0.6, 0.6)).toBe(1)
		expect(DiceRules.spinLeft(0, 0.6)).toBe(1)
	end)

	it("nunca atraviesa el suelo y bota cada vez más bajo", function()
		local peaks = { 0, 0, 0 }
		for step = 0, 600 do
			local h = DiceRules.hop(step / 1000, 0.6)
			expect(h >= 0).toBe(true)
			local s = step / 600
			local slot = if s <= 0.55 then 1 elseif s <= 0.85 then 2 else 3
			peaks[slot] = math.max(peaks[slot], h)
		end
		expect(peaks[1] > peaks[2] and peaks[2] > peaks[3]).toBe(true)
	end)

	it("la misma tirada da el mismo vuelo en todos los clientes", function()
		expect(DiceRules.jitter(12, 3)).toBe(DiceRules.jitter(12, 3))
		local j = DiceRules.jitter(5, 1)
		expect(j >= 0 and j < 1).toBe(true)
	end)
end)

describe("Escena de los dados", function()
	it("aunque se repita cada turno, dura lo bastante para verlos rodar", function()
		expect(Scenes.durationFor({ type = "DiceRolled" }, 10) >= 1.4).toBe(true)
		expect(Scenes.durationFor({ type = "DiceRolled" }, 0) <= 4).toBe(true)
	end)
end)

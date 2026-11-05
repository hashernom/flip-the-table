--!strict
local Harness = require("../harness")
local TokenMotion = require("../../src/client/world/TokenMotion")
local Tokens = require("../../src/shared/config/Tokens")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

describe("TokenMotion", function()
	it("la rueda gira lo que ha rodado, sin importar la velocidad", function()
		expect(near(TokenMotion.wheelAngle(2 * math.pi, 1), 2 * math.pi)).toBe(true)
		expect(TokenMotion.wheelAngle(0, 1)).toBe(0)
		expect(TokenMotion.wheelAngle(10, 0)).toBe(0)
	end)

	it("el reposo nunca se aleja más de su amplitud y cambia con la fase", function()
		for step = 0, 200 do
			expect(math.abs(TokenMotion.idleLift(step / 20, 0)) <= Tokens.motion.idleAmplitude + 1e-6).toBe(
				true
			)
		end
		expect(TokenMotion.idleLift(0.3, 0) ~= TokenMotion.idleLift(0.3, 1)).toBe(true)
	end)

	it("la marcha rebota sin hundirse en el suelo", function()
		for distance = 0, 100 do
			local lift = TokenMotion.rideLift(distance)
			expect(lift >= 0 and lift <= Tokens.motion.rideBounce + 1e-6).toBe(true)
		end
	end)

	it("la celebración sale y vuelve exactamente a su sitio", function()
		local startLift, startYaw = TokenMotion.celebrate(0)
		local endLift, endYaw = TokenMotion.celebrate(1)
		expect(near(startLift, 0) and near(startYaw, 0)).toBe(true)
		expect(near(endLift, 0)).toBe(true)
		expect(near(math.sin(endYaw), 0) and near(math.cos(endYaw), 1)).toBe(true)
		local midLift = TokenMotion.celebrate(0.5)
		expect(near(midLift, Tokens.motion.celebrateHeight)).toBe(true)
	end)

	it("un progreso fuera de rango no descoloca la ficha", function()
		expect(near((TokenMotion.celebrate(-1)), 0)).toBe(true)
		expect(near((TokenMotion.celebrate(2)), 0)).toBe(true)
	end)

	it("cada ficha tiene su propia fase de reposo y es estable", function()
		expect(TokenMotion.phaseOf("123")).toBe(TokenMotion.phaseOf("123"))
		expect(TokenMotion.phaseOf("123") ~= TokenMotion.phaseOf("456")).toBe(true)
	end)
end)

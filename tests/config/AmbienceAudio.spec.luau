--!strict
local Harness = require("../harness")
local AmbienceAudio = require("../../src/shared/config/AmbienceAudio")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

describe("AmbienceAudio", function()
	it("el id del ambiente tiene forma de asset de Roblox", function()
		expect(string.match(AmbienceAudio.cityDay.assetId, "^rbxassetid://%d+$") ~= nil).toBe(true)
	end)

	it("el volumen de fondo está entre 0 y 1", function()
		local volume = AmbienceAudio.cityDay.volume
		expect(volume >= 0 and volume <= 1).toBe(true)
	end)
end)

--!strict
-- Reglas del audio: cuánto baja cada sonido cuando suenan varios a la vez, para que varias escenas
-- seguidas no saturen, y cómo se combinan con los volúmenes que elige el jugador.
local Harness = require("../harness")
local AudioRules = require("../../src/client/audio/AudioRules")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

describe("AudioRules.gainFor", function()
	it("un sonido solo suena entero", function()
		expect(AudioRules.gainFor(1)).toBe(1)
	end)

	it("la ganancia baja al subir los sonidos activos y nunca supera 1", function()
		local previous = math.huge
		for count = 0, 12 do
			local gain = AudioRules.gainFor(count)
			expect(gain <= 1).toBe(true)
			expect(gain > 0).toBe(true)
			if count >= 1 then
				expect(gain < previous or count == 1).toBe(true)
			end
			previous = gain
		end
	end)

	it("la suma de varios sonidos a la vez no pasa del techo de mezcla", function()
		for count = 1, 12 do
			expect(AudioRules.gainFor(count) * count <= AudioRules.MIX_CEILING + 1e-9).toBe(true)
		end
	end)
end)

describe("AudioRules.volumeFor", function()
	it("multiplica el volumen del sonido por el del canal y la ganancia, acotado entre 0 y 1", function()
		expect(AudioRules.volumeFor(0.8, 0.5, 1)).toBe(0.4)
		expect(AudioRules.volumeFor(2, 1, 1)).toBe(1)
		expect(AudioRules.volumeFor(0.5, -1, 1)).toBe(0)
	end)

	it("con el canal a cero no suena nada", function()
		expect(AudioRules.volumeFor(1, 0, 1)).toBe(0)
	end)
end)

describe("AudioRules.musicFor", function()
	it("cada momento de la partida tiene su música", function()
		expect(AudioRules.musicFor("Lobby")).toBe("music.lobby")
		expect(AudioRules.musicFor("Normal")).toBe("music.match")
		expect(AudioRules.musicFor("FinalRounds")).toBe("music.finalRounds")
		expect(AudioRules.musicFor("Podium")).toBe("music.podium")
	end)
end)

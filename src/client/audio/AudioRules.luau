--!strict
-- Reglas puras del audio: cuánto baja cada sonido cuando suenan varios a la vez, cómo se combina con el
-- volumen de su canal y qué música toca en cada momento. `AudioDirector` solo las aplica.
local Audio = require("../../shared/config/Audio")

export type MusicState = "Lobby" | "Normal" | "FinalRounds" | "Podium"

local AudioRules = {}

AudioRules.MIX_CEILING = Audio.mixCeiling

-- Ganancia de cada sonido con `activeCount` sonando a la vez. Solo o ninguno: entero. Con más, se
-- reparte el techo de mezcla entre todos, así que la suma nunca lo pasa y la ganancia nunca sube de 1.
function AudioRules.gainFor(activeCount: number): number
	if activeCount <= 1 then
		return 1
	end
	return math.min(1, AudioRules.MIX_CEILING / activeCount)
end

-- Volumen final: el del sonido, por el de su canal y por la ganancia de la mezcla, entre 0 y 1.
function AudioRules.volumeFor(base: number, channel: number, gain: number): number
	return math.clamp(base * channel * gain, 0, 1)
end

local MUSIC: { [MusicState]: string } = {
	Lobby = "music.lobby",
	Normal = "music.match",
	FinalRounds = "music.finalRounds",
	Podium = "music.podium",
}

function AudioRules.musicFor(state: MusicState): string
	return MUSIC[state]
end

return AudioRules

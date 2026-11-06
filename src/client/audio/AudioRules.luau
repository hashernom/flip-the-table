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

-- Efecto de un evento de la mesa, o nil. Una obra suena distinto según suba o baje de nivel.
function AudioRules.soundForEvent(event: any): string?
	if type(event) ~= "table" then
		return nil
	end
	if event.type == "BuildingChanged" then
		local from = tonumber(event.from) or 0
		local to = tonumber(event.to) or 0
		if to > from then
			return Audio.buildUpSound
		elseif to < from then
			return Audio.buildDownSound
		end
		return nil
	end
	return Audio.eventSounds[event.type]
end

-- Tono de una reproducción: `roll` va de 0 a 1 (un aleatorio) y lo lleva a 1 ± `jitter`. Así un clic
-- repetido nunca suena idéntico dos veces, sin salirse de su carácter.
function AudioRules.pitchFor(jitter: number, roll: number): number
	return 1 + (math.clamp(roll, 0, 1) * 2 - 1) * math.max(jitter, 0)
end

return AudioRules

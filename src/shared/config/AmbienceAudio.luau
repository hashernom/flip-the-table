--!strict
-- Sonido de ambiente de la ciudad durante la partida (plan 06, porción vertical). Es solo dato: el
-- cliente lo convierte en un `Sound` en `src/client/world/Ambience.luau`.
--
-- Audio de terceros de la biblioteca de Roblox (Creator Store), ProSoundEffects, «City Day Ambience 1».
-- Licencia para publicar sin confirmar: queda así en `art/manifest.json` hasta que el responsable lo confirme.

export type Ambience = {
	name: string,
	assetId: string,
	volume: number,
}

local AmbienceAudio = {}

-- Volumen discreto: es ambiente de fondo, no se debe oír por encima de la partida.
AmbienceAudio.cityDay = {
	name = "City Day Ambience 1",
	assetId = "rbxassetid://9112758856",
	volume = 0.4,
} :: Ambience

return AmbienceAudio

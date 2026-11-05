--!strict
-- Sonido de ambiente de la ciudad: un `Sound` en bucle dentro de `SoundService`. Si el audio no carga,
-- la partida sigue igual: el `Sound` queda en silencio y no se lanza ningún error.
local SoundService = game:GetService("SoundService")

local AmbienceAudio = require("../../shared/config/AmbienceAudio")

local Ambience = {}

local SOUND_NAME = "CityAmbience"

-- Arranca el ambiente una sola vez: si ya existe el `Sound`, no crea otro.
function Ambience.start()
	if SoundService:FindFirstChild(SOUND_NAME) ~= nil then
		return
	end
	local config = AmbienceAudio.cityDay
	local ok: boolean, err: any = (pcall :: any)(function()
		local sound = Instance.new("Sound")
		sound.Name = SOUND_NAME
		sound.SoundId = config.assetId
		sound.Volume = config.volume
		sound.Looped = true
		sound.Parent = SoundService
		sound:Play()
	end)
	if not ok then
		warn(`Cliente: no se pudo arrancar el ambiente: {err}`)
	end
end

return Ambience

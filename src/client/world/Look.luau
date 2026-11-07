--!strict
-- Luz de Metrópolis. Los valores de partida son los de `art/lookdev/look.luau` y `art/luz.md`.
-- `LightingStyle = Realistic` no se puede poner por script: va guardado en el lugar y hay que comprobarlo
-- al publicar.
--
-- Hay dos presets: el de la partida y el del lobby. El lobby es un parque abierto a mediodía, con
-- superficies grandes y planas (césped, calzada, mesas de colores), así que el preset de la calle lo
-- deja saturado y quemado. El suyo levanta menos la luz, baja el contraste y desatura el color para que
-- el parque no compita con la interfaz.
local Lighting = game:GetService("Lighting")

local Look = {}

local function ensure(className: string, name: string): any
	local found = Lighting:FindFirstChild(name)
	if found == nil then
		found = Instance.new(className)
		found.Name = name
		found.Parent = Lighting
	end
	return found
end

export type Preset = {
	brightness: number,
	exposure: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	diffuse: number,
	density: number,
	haze: number,
	bloomIntensity: number,
	bloomThreshold: number,
	contrast: number,
	saturation: number,
	tint: Color3,
}

-- La calle de la partida: el look que ya está aprobado en `art/render`.
local MATCH: Preset = {
	brightness = 2.95,
	exposure = 0,
	ambient = Color3.fromRGB(58, 62, 74),
	outdoorAmbient = Color3.fromRGB(112, 116, 128),
	diffuse = 0.55,
	density = 0.26,
	haze = 1.5,
	bloomIntensity = 0.45,
	bloomThreshold = 1.3,
	contrast = 0.18,
	saturation = 1.02,
	tint = Color3.fromRGB(255, 246, 232),
}

-- El parque: misma hora y mismo cielo, pero luz más baja y color más apagado.
local LOBBY: Preset = {
	brightness = 2.2,
	exposure = -0.1,
	ambient = Color3.fromRGB(52, 56, 66),
	outdoorAmbient = Color3.fromRGB(100, 104, 116),
	diffuse = 0.5,
	density = 0.34,
	haze = 1.6,
	bloomIntensity = 0.22,
	bloomThreshold = 1.6,
	contrast = 0.08,
	saturation = 0.8,
	tint = Color3.fromRGB(252, 244, 232),
}

local function paint(preset: Preset)
	Lighting.ClockTime = 10.6
	Lighting.GeographicLatitude = 41.7333
	Lighting.Brightness = preset.brightness
	Lighting.Ambient = preset.ambient
	Lighting.OutdoorAmbient = preset.outdoorAmbient
	Lighting.ShadowSoftness = 0.2
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = preset.diffuse
	Lighting.EnvironmentSpecularScale = 0.85
	Lighting.ExposureCompensation = preset.exposure

	local atmosphere = ensure("Atmosphere", "Atmosphere")
	atmosphere.Density = preset.density
	atmosphere.Haze = preset.haze
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(208, 222, 242)
	atmosphere.Decay = Color3.fromRGB(198, 170, 146)
	atmosphere.Glare = 0.1

	local bloom = ensure("BloomEffect", "Bloom")
	bloom.Intensity = preset.bloomIntensity
	bloom.Threshold = preset.bloomThreshold
	bloom.Size = 22

	local correction = ensure("ColorCorrectionEffect", "ColorCorrection")
	correction.Brightness = 0.01
	correction.Contrast = preset.contrast
	correction.Saturation = preset.saturation
	correction.TintColor = preset.tint

	local sky = ensure("Sky", "Sky")
	sky.SkyboxFt = "rbxassetid://130728511009606"
	sky.SkyboxBk = "rbxassetid://80764594111224"
	sky.SkyboxLf = "rbxassetid://119522021872772"
	sky.SkyboxRt = "rbxassetid://110426578506982"
	sky.SkyboxUp = "rbxassetid://113330714001871"
	sky.SkyboxDn = "rbxassetid://91237438205488"
end

-- La calle: el cliente de la partida.
function Look.apply()
	paint(MATCH)
end

-- El parque del lobby: menos luz, menos contraste y menos saturación.
function Look.applyLobby()
	paint(LOBBY)
end

return Look

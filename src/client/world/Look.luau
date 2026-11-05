--!strict
-- Luz de Metrópolis en la partida. Los valores son los de `art/lookdev/look.luau` y `art/luz.md`.
-- `LightingStyle = Realistic` no se puede poner por script: va guardado en el lugar y hay que comprobarlo
-- al publicar.
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

function Look.apply()
	Lighting.ClockTime = 10.6
	Lighting.GeographicLatitude = 41.7333
	Lighting.Brightness = 3.135
	Lighting.Ambient = Color3.fromRGB(58, 62, 74)
	Lighting.OutdoorAmbient = Color3.fromRGB(112, 116, 128)
	Lighting.ShadowSoftness = 0.2
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.85
	Lighting.ExposureCompensation = 0

	local atmosphere = ensure("Atmosphere", "Atmosphere")
	atmosphere.Density = 0.26
	atmosphere.Haze = 1.5
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(208, 222, 242)
	atmosphere.Decay = Color3.fromRGB(198, 170, 146)
	atmosphere.Glare = 0.1

	local bloom = ensure("BloomEffect", "Bloom")
	bloom.Intensity = 0.45
	bloom.Threshold = 1.3
	bloom.Size = 22

	local correction = ensure("ColorCorrectionEffect", "ColorCorrection")
	correction.Brightness = 0.01
	correction.Contrast = 0.18
	correction.Saturation = 1.02
	correction.TintColor = Color3.fromRGB(255, 246, 232)

	local sky = ensure("Sky", "Sky")
	sky.SkyboxFt = "rbxassetid://130728511009606"
	sky.SkyboxBk = "rbxassetid://80764594111224"
	sky.SkyboxLf = "rbxassetid://119522021872772"
	sky.SkyboxRt = "rbxassetid://110426578506982"
	sky.SkyboxUp = "rbxassetid://113330714001871"
	sky.SkyboxDn = "rbxassetid://91237438205488"
end

return Look

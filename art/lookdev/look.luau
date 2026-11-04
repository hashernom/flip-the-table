--!nocheck
-- Look de Metrópolis: luz, atmósfera, post-proceso, cielo y materiales.
--
-- Este archivo es la **fuente de verdad**. Hasta ahora el look vivía solo dentro del `.rbxl` del
-- banco de pruebas, que no está en el repositorio: si ese archivo se perdía, se perdía la luz.
--
-- Cómo se usa: pegar entero en la barra de comandos de Studio (View → Command Bar) y pulsar Enter.
-- Crea o actualiza `Lighting`, sus efectos, el `Sky` y los `MaterialVariant` con los ids ya subidos.
--
-- Lo que NO puede hacer un script, y hay que tocar a mano en Explorer → Lighting → Properties:
--   * `Lighting.LightingStyle = Realistic`. Sin eso no hay sombras arrojadas y ninguna captura vale.
--   * `Lighting.EnvironmentDiffuseScale` sí se puede; `EnvironmentSpecularScale`, también.
--
-- Valores tomados del place el 2026-11-04. Si alguien los cambia allí, se actualizan aquí y se
-- vuelve a capturar: `look.json` es una foto de este archivo, no al revés.

local Look = {}

Look.lighting = {
	ClockTime = 10.6,
	GeographicLatitude = 41.7333,
	Brightness = 3.135,
	Ambient = Color3.fromRGB(58, 62, 74),
	OutdoorAmbient = Color3.fromRGB(112, 116, 128),
	ShadowSoftness = 0.2,
	GlobalShadows = true,
	EnvironmentDiffuseScale = 0.55,
	EnvironmentSpecularScale = 0.85,
	ExposureCompensation = 0,
}

Look.effects = {
	Atmosphere = {
		Density = 0.26,
		Haze = 1.5,
		Offset = 0.1,
		Color = Color3.fromRGB(208, 222, 242),
		Decay = Color3.fromRGB(198, 170, 146),
		Glare = 0.1,
	},
	Bloom = { Intensity = 0.45, Threshold = 1.3, Size = 22 },
	ColorCorrection = {
		Brightness = 0.01,
		Contrast = 0.18,
		Saturation = 1.02,
		TintColor = Color3.fromRGB(255, 246, 232),
	},
	DepthOfField = { FarIntensity = 0.14, FocusDistance = 60, InFocusRadius = 110 },
}

-- Skybox propia, subida a la cuenta del responsable. Los ids están también en `asset-ids.json`.
Look.sky = {
	SkyboxFt = "rbxassetid://130728511009606",
	SkyboxBk = "rbxassetid://80764594111224",
	SkyboxLf = "rbxassetid://119522021872772",
	SkyboxRt = "rbxassetid://110426578506982",
	SkyboxUp = "rbxassetid://113330714001871",
	SkyboxDn = "rbxassetid://91237438205488",
	StarCount = 3000,
	SunAngularSize = 2,
	MoonAngularSize = 11,
	CelestialBodiesShown = true,
}

-- `inUse` dice lo que el banco de pruebas tiene puesto de verdad. Los cuatro que no se usan quedan
-- aquí porque son los de la guía de estilo y la ciudad los va a necesitar; hoy serían material muerto.
Look.materials = {
	BrickRedCC0 = {
		BaseMaterial = Enum.Material.Brick,
		ColorMap = "rbxassetid://71677364092938",
		NormalMap = "rbxassetid://132924241608465",
		RoughnessMap = "rbxassetid://104748136545976",
		inUse = true,
	},
	BrickWarmCC0 = {
		BaseMaterial = Enum.Material.Brick,
		ColorMap = "rbxassetid://70949398469969",
		NormalMap = "rbxassetid://95950472085988",
		RoughnessMap = "rbxassetid://115976051933338",
		inUse = true,
	},
	ConcreteCC0 = {
		BaseMaterial = Enum.Material.Concrete,
		ColorMap = "rbxassetid://111200245070453",
		NormalMap = "rbxassetid://137076655980555",
		RoughnessMap = "rbxassetid://79369376727167",
		inUse = true,
	},
	AsphaltCC0 = {
		BaseMaterial = Enum.Material.Asphalt,
		ColorMap = "rbxassetid://127396582316127",
		NormalMap = "rbxassetid://89752594019417",
		RoughnessMap = "rbxassetid://137425056226224",
		inUse = true,
	},
	-- Los tres siguientes son juegos procedurales de `art/generators/pbr_assets.py`, más el ladrillo
	-- antiguo que quedó sin retirar. No los usa ninguna pieza del banco de pruebas.
	LimestoneDia = {
		BaseMaterial = Enum.Material.Limestone,
		ColorMap = "rbxassetid://114375194063151",
		NormalMap = "rbxassetid://130288238810852",
		RoughnessMap = "rbxassetid://128913742934911",
		inUse = false,
	},
	BrickDia = {
		BaseMaterial = Enum.Material.Brick,
		ColorMap = "rbxassetid://95607629939024",
		NormalMap = "rbxassetid://138499103748415",
		RoughnessMap = "rbxassetid://126002287634078",
		inUse = false,
	},
	AsphaltDia = {
		BaseMaterial = Enum.Material.Asphalt,
		ColorMap = "rbxassetid://102871027653708",
		NormalMap = "rbxassetid://84109786110489",
		RoughnessMap = "rbxassetid://131559911701324",
		inUse = false,
	},
	-- Usa un ColorMap que `asset-ids.json` da por obsoleto. Como no está puesto en ninguna pieza, no
	-- rompe nada, pero no debe usarse.
	BrickCC0 = {
		BaseMaterial = Enum.Material.Brick,
		ColorMap = "rbxassetid://117145705650698",
		NormalMap = "rbxassetid://83484755331691",
		RoughnessMap = "rbxassetid://78452583129868",
		inUse = false,
	},
}

local function ensure(className, name)
	local lighting = game:GetService("Lighting")
	local found = lighting:FindFirstChild(name)
	if found and not found:IsA(className) then
		found:Destroy()
		found = nil
	end
	if not found then
		found = Instance.new(className)
		found.Name = name
		found.Parent = lighting
	end
	return found
end

function Look.apply()
	local lighting = game:GetService("Lighting")

	for key, value in Look.lighting do
		local ok, err = pcall(function()
			(lighting :: any)[key] = value
		end)
		if not ok then
			warn(`Look: no se pudo escribir Lighting.{key}: {err}. Se toca a mano en Properties.`)
		end
	end

	local atmosphere = ensure("Atmosphere", "Atmosphere")
	for key, value in Look.effects.Atmosphere do
		(atmosphere :: any)[key] = value
	end

	local bloom = ensure("BloomEffect", "Bloom")
	for key, value in Look.effects.Bloom do
		(bloom :: any)[key] = value
	end

	local correction = ensure("ColorCorrectionEffect", "ColorCorrection")
	for key, value in Look.effects.ColorCorrection do
		(correction :: any)[key] = value
	end

	local dof = ensure("DepthOfFieldEffect", "DepthOfField")
	for key, value in Look.effects.DepthOfField do
		(dof :: any)[key] = value
	end

	local sky = ensure("Sky", "Sky")
	for key, value in Look.sky do
		(sky :: any)[key] = value
	end

	local service = game:GetService("MaterialService")
	for name, spec in Look.materials do
		local variant = service:FindFirstChild(name)
		if variant == nil or not variant:IsA("MaterialVariant") then
			if variant then
				variant:Destroy()
			end
			variant = Instance.new("MaterialVariant")
			variant.Name = name
			variant.Parent = service
		end
		local mv = variant :: MaterialVariant
		mv.BaseMaterial = spec.BaseMaterial
		mv.ColorMap = spec.ColorMap
		mv.NormalMap = spec.NormalMap
		mv.RoughnessMap = spec.RoughnessMap
	end

	print("Look aplicado. Comprueba LightingStyle = Realistic a mano.", #Look.materials .. " materiales.")
end

Look.apply()

return Look

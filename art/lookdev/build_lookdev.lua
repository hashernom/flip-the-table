-- art/lookdev/build_lookdev.lua
-- Banco de pruebas de luz de Metrópolis: una calle con materiales PBR, props y la ficha.
--
-- Uso: pegar en la barra de comandos de Studio, o ejecutar por el MCP de Studio.
--
-- Dos cosas aprendidas que están codificadas aquí:
--   1. El sol de Roblox siempre tiene componente Z positiva (Lighting:GetSunDirection()
--      da z = +0.31 a cualquier hora). Consecuencia: una calle orientada este-oeste nunca
--      recibe las sombras de sus edificios. Por eso la ciudad se construye y luego se gira
--      un cuarto de vuelta, para que la calle corra en Z y el sol barra en X.
--   2. Con el sol bajo (ClockTime 17) la fila de la manzana contraria proyecta su sombra
--      contra la fachada de enfrente. Eso es lo que da profundidad a la calle.

local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local Workspace = game:GetService("Workspace")

local previous = Workspace:FindFirstChild("LookDev")
if previous then
	previous:Destroy()
end

local root = Instance.new("Folder")
root.Name = "LookDev"

local structure = Instance.new("Folder")
structure.Name = "Structure"
structure.Parent = root

local windowFolder = Instance.new("Folder")
windowFolder.Name = "Windows"
windowFolder.Parent = root

local function piece(parent, size, position, color, material, shape)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.Parent = parent
	return part
end

local ASPHALT = Color3.fromRGB(70, 70, 76)
local SIDEWALK = Color3.fromRGB(150, 148, 142)

-- Calzada y aceras. La calle va en X antes de girarse.
piece(structure, Vector3.new(200, 0.4, 34), Vector3.new(0, -0.2, 0), ASPHALT, Enum.Material.Asphalt)
piece(structure, Vector3.new(200, 0.8, 7), Vector3.new(0, 0.4, -20.5), SIDEWALK, Enum.Material.Concrete)
piece(structure, Vector3.new(200, 0.8, 7), Vector3.new(0, 0.4, 20.5), SIDEWALK, Enum.Material.Concrete)

piece(structure, Vector3.new(1400, 1, 1400), Vector3.new(0, -0.9, 0), Color3.fromRGB(120, 120, 116), Enum.Material.Concrete)

-- Dos manzanas enfrentadas: sin la de enfrente no hay sombra que cruce la calle.
local rows = { -35, 35 }
local heights = { 15.2, 36.5, 92 }
for _, rowZ in rows do
	local x = -20
	piece(structure, Vector3.new(15, heights[1], 22), Vector3.new(x, heights[1] / 2, rowZ), Color3.new(1, 1, 1), Enum.Material.Brick)
	piece(structure, Vector3.new(15, heights[2], 22), Vector3.new(0, heights[2] / 2, rowZ), Color3.new(1, 1, 1), Enum.Material.Limestone)
	piece(structure, Vector3.new(18, heights[3] * 0.55, 22), Vector3.new(22, heights[3] * 0.275, rowZ), Color3.new(1, 1, 1), Enum.Material.Limestone)
	piece(structure, Vector3.new(14, heights[3] * 0.3, 18), Vector3.new(22, heights[3] * 0.55 + heights[3] * 0.15, rowZ), Color3.new(1, 1, 1), Enum.Material.Limestone)
	piece(structure, Vector3.new(10, heights[3] * 0.15, 14), Vector3.new(22, heights[3] * 0.85 + heights[3] * 0.075, rowZ), Color3.new(1, 1, 1), Enum.Material.Limestone)
end

-- Ventanas: el detalle que hace que una fachada no sea una caja.
local glass = Color3.fromRGB(46, 62, 78)
for _, rowZ in rows do
	local facing = -math.sign(rowZ)
	for floor = 0, 4 do
		for slot = -3, 3 do
			piece(
				windowFolder,
				Vector3.new(1.5, 2.1, 0.3),
				Vector3.new(slot * 1.9, 3.6 + floor * 7, rowZ + facing * 11.1),
				glass,
				Enum.Material.Glass
			)
		end
	end
	for floor = 0, 11 do
		for slot = -2, 2 do
			piece(
				windowFolder,
				Vector3.new(1.3, 2.3, 0.3),
				Vector3.new(22 + slot * 2.7, 3.6 + floor * 4.2, rowZ + facing * 11.1),
				glass,
				Enum.Material.Glass
			)
		end
	end
end

-- Farolas y coches: densidad a la altura de la cámara.
for i = -4, 4 do
	local x = i * 22
	for _, side in { -1, 1 } do
		local z = side * 17.5
		piece(structure, Vector3.new(0.5, 13, 0.5), Vector3.new(x, 6.5, z), Color3.fromRGB(40, 42, 46), Enum.Material.Metal)
		piece(structure, Vector3.new(1.8, 0.5, 1.8), Vector3.new(x, 13.1, z), Color3.fromRGB(250, 244, 230), Enum.Material.Metal)
	end
end

local carColors = { Color3.fromRGB(196, 40, 44), Color3.fromRGB(36, 70, 132), Color3.fromRGB(230, 196, 60) }
for index, color in ipairs(carColors) do
	local x = -50 + index * 28
	piece(structure, Vector3.new(7.2, 1.7, 3.2), Vector3.new(x, 0.95, -12), color, Enum.Material.SmoothPlastic)
	piece(structure, Vector3.new(3.6, 1.4, 2.9), Vector3.new(x - 0.4, 2.4, -12), Color3.fromRGB(26, 32, 40), Enum.Material.Glass)
end

-- La ficha: 9 studs, con su avatar de 6 encima como referencia de escala.
local token = Instance.new("Folder")
token.Name = "TaxiToken"
token.Parent = root
local base = piece(token, Vector3.new(1.2, 6, 6), Vector3.new(-44, 0.6, 0), Color3.fromRGB(214, 168, 74), Enum.Material.Metal, Enum.PartType.Cylinder)
base.CFrame = CFrame.new(-44, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90))
local stem = piece(token, Vector3.new(5.2, 4.4, 4.4), Vector3.new(-44, 3.8, 0), Color3.fromRGB(214, 168, 74), Enum.Material.Metal, Enum.PartType.Cylinder)
stem.CFrame = CFrame.new(-44, 3.8, 0) * CFrame.Angles(0, 0, math.rad(90))
piece(token, Vector3.new(4.3, 1.4, 2.5), Vector3.new(-44, 7.1, 0), Color3.fromRGB(238, 190, 44), Enum.Material.SmoothPlastic)
piece(token, Vector3.new(2.0, 1.2, 2.0), Vector3.new(-44, 8.4, 0), Color3.fromRGB(30, 40, 50), Enum.Material.Glass)
piece(token, Vector3.new(2.2, 2.6, 1.2), Vector3.new(-44, 10.3, 0), Color3.fromRGB(190, 140, 110), Enum.Material.SmoothPlastic)
piece(token, Vector3.new(1.6, 1.6, 1.6), Vector3.new(-44, 12.4, 0), Color3.fromRGB(190, 140, 110), Enum.Material.SmoothPlastic)

-- Materiales PBR. Las texturas salen de art/generators/pbr_assets.py y sus ids están
-- en art/asset-ids.json. Sin esto, las fachadas vuelven a ser el ladrillo de fábrica.
local function ensureVariant(name, baseMaterial, albedo, roughness, normal)
	local variant = MaterialService:FindFirstChild(name)
	if not variant then
		variant = Instance.new("MaterialVariant")
		variant.Name = name
		variant.BaseMaterial = baseMaterial
		variant.ColorMap = albedo
		variant.RoughnessMap = roughness
		variant.NormalMap = normal
		variant.Parent = MaterialService
	end
	return variant
end

ensureVariant(
	"BrickDia",
	Enum.Material.Brick,
	"rbxassetid://95607629939024",
	"rbxassetid://126002287634078",
	"rbxassetid://138499103748415"
)
ensureVariant(
	"LimestoneDia",
	Enum.Material.Limestone,
	"rbxassetid://114375194063151",
	"rbxassetid://128913742934911",
	"rbxassetid://130288238810852"
)
ensureVariant(
	"AsphaltDia",
	Enum.Material.Asphalt,
	"rbxassetid://102871027653708",
	"rbxassetid://131559911701324",
	"rbxassetid://84109786110489"
)

for _, part in structure:GetChildren() do
	if part.Material == Enum.Material.Brick then
		part.MaterialVariant = "BrickDia"
	elseif part.Material == Enum.Material.Limestone then
		part.MaterialVariant = "LimestoneDia"
	elseif part.Material == Enum.Material.Asphalt then
		part.MaterialVariant = "AsphaltDia"
	end
end

-- El giro: la calle pasa a correr en Z y el sol barre en X.
for _, descendant in root:GetDescendants() do
	if descendant:IsA("BasePart") then
		descendant.CFrame = CFrame.Angles(0, math.rad(90), 0) * descendant.CFrame
	end
end

root.Parent = Workspace

-- Cielo propio: sin esto todo lo demás sigue pareciendo el Roblox de fábrica.
local sky = Lighting:FindFirstChildOfClass("Sky")
if not sky then
	sky = Instance.new("Sky")
	sky.Parent = Lighting
end
sky.SkyboxUp = "rbxassetid://113330714001871"
sky.SkyboxDn = "rbxassetid://91237438205488"
sky.SkyboxLf = "rbxassetid://119522021872772"
sky.SkyboxRt = "rbxassetid://110426578506982"
sky.SkyboxFt = "rbxassetid://130728511009606"
sky.SkyboxBk = "rbxassetid://80764594111224"
sky.SunAngularSize = 2

for _, child in Lighting:GetChildren() do
	if child:IsA("PostEffect") or child:IsA("Atmosphere") then
		child:Destroy()
	end
end

Lighting.ClockTime = 17.0
Lighting.Brightness = 2.1
Lighting.Ambient = Color3.fromRGB(54, 58, 70)
Lighting.OutdoorAmbient = Color3.fromRGB(96, 100, 112)
Lighting.ExposureCompensation = -0.25
Lighting.EnvironmentDiffuseScale = 0.5
Lighting.EnvironmentSpecularScale = 0.8
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.45

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Offset = 0.12
atmosphere.Color = Color3.fromRGB(206, 220, 240)
atmosphere.Decay = Color3.fromRGB(190, 160, 136)
atmosphere.Glare = 0.1
atmosphere.Haze = 1.9
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.4
bloom.Size = 22
bloom.Threshold = 1.4
bloom.Parent = Lighting

local color = Instance.new("ColorCorrectionEffect")
color.Contrast = 0.14
color.Saturation = 1.03
color.Brightness = 0.01
color.TintColor = Color3.fromRGB(255, 246, 232)
color.Parent = Lighting

local depth = Instance.new("DepthOfFieldEffect")
depth.FarIntensity = 0.16
depth.FocusDistance = 70
depth.InFocusRadius = 120
depth.NearIntensity = 0
depth.Parent = Lighting

-- El ColorMap del MaterialVariant MULTIPLICA el color de la pieza. Por eso los edificios van en
-- blanco (Color3.new(1, 1, 1)): con un color oscuro, la textura se multiplica por cero y todo
-- sale negro. Este error costó una hora de capturas en negro.
local camera = Workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = CFrame.lookAt(Vector3.new(44, 27, 66), Vector3.new(-12, 8, -12))
camera.FieldOfView = 62

return { parts = #root:GetDescendants(), sun = tostring(Lighting:GetSunDirection()) }

-- art/lookdev/build_facade.lua
-- Fachada de referencia de Metrópolis: la pieza que fija el listón de la subfase 06.
--
-- Muro de ladrillo con textura CC0, escaparate, toldo, ventanas con marco, alféizar y parteluz,
-- junta entre plantas, cornisa, bajante y farol. 44 piezas.
--
-- Requiere que existan los MaterialVariant BrickCC0, ConcreteCC0 y AsphaltCC0 (los crea el bloque
-- de aquí abajo si faltan) y la carpeta LookDev del banco de luz.

local MaterialService = game:GetService("MaterialService")
local Workspace = game:GetService("Workspace")

local function variant(name, baseMaterial, color, normal, roughness)
	local existing = MaterialService:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local created = Instance.new("MaterialVariant")
	created.Name = name
	created.BaseMaterial = baseMaterial
	created.ColorMap = color
	created.NormalMap = normal
	created.RoughnessMap = roughness
	created.Parent = MaterialService
	return created
end

variant("BrickCC0", Enum.Material.Brick, "rbxassetid://117145705650698", "rbxassetid://83484755331691", "rbxassetid://78452583129868")
variant("ConcreteCC0", Enum.Material.Concrete, "rbxassetid://111200245070453", "rbxassetid://137076655980555", "rbxassetid://79369376727167")
variant("AsphaltCC0", Enum.Material.Asphalt, "rbxassetid://127396582316127", "rbxassetid://89752594019417", "rbxassetid://137425056226224")

local root = Workspace:FindFirstChild("LookDev")
if not root then
	error("Falta Workspace.LookDev: ejecuta antes build_lookdev.lua")
end

local previous = root:FindFirstChild("Facade")
if previous then
	previous:Destroy()
end

local facade = Instance.new("Folder")
facade.Name = "Facade"
facade.Parent = root

local origin = Vector3.new(-35, 0, 34)

local function piece(size, offset, color, material, materialVariant)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.Position = origin + offset
	part.Color = color
	part.Material = material
	if materialVariant then
		part.MaterialVariant = materialVariant
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = facade
	return part
end

local WHITE = Color3.new(1, 1, 1)
local STONE = Color3.fromRGB(232, 228, 218)
local GLASS = Color3.fromRGB(38, 52, 66)
local METAL = Color3.fromRGB(52, 54, 58)
local FABRIC = Color3.fromRGB(148, 44, 62)

-- Muro y huecos
piece(Vector3.new(2, 22, 24), Vector3.new(0, 11, 0), WHITE, Enum.Material.Brick, "BrickCC0")
piece(Vector3.new(0.4, 5.2, 15), Vector3.new(1.05, 3.2, -3), GLASS, Enum.Material.Glass)
piece(Vector3.new(0.5, 4.4, 2.8), Vector3.new(1.1, 2.2, 7.5), METAL, Enum.Material.Metal)
piece(Vector3.new(2.6, 0.35, 17), Vector3.new(2.3, 6.4, -3), FABRIC, Enum.Material.Fabric)
piece(Vector3.new(2.8, 0.55, 24.4), Vector3.new(0.4, 8.2, 0), STONE, Enum.Material.Concrete, "ConcreteCC0")
piece(Vector3.new(3.0, 0.9, 24.8), Vector3.new(0.5, 21.8, 0), STONE, Enum.Material.Concrete, "ConcreteCC0")

-- Ventanas: cristal, alféizar, dintel, jambas y parteluz
for _, height in { 11.0, 15.5, 19.0 } do
	for _, offset in { -6.0, 6.0 } do
		piece(Vector3.new(0.25, 2.4, 2.2), Vector3.new(1.02, height, offset), GLASS, Enum.Material.Glass)
		piece(Vector3.new(0.8, 0.28, 3.1), Vector3.new(1.35, height - 1.45, offset), STONE, Enum.Material.Concrete, "ConcreteCC0")
		piece(Vector3.new(0.6, 0.3, 2.9), Vector3.new(1.3, height + 1.45, offset), STONE, Enum.Material.Concrete, "ConcreteCC0")
		piece(Vector3.new(0.55, 3.0, 0.26), Vector3.new(1.3, height, offset - 1.25), STONE, Enum.Material.Concrete, "ConcreteCC0")
		piece(Vector3.new(0.55, 3.0, 0.26), Vector3.new(1.3, height, offset + 1.25), STONE, Enum.Material.Concrete, "ConcreteCC0")
		piece(Vector3.new(0.5, 2.45, 0.12), Vector3.new(1.28, height, offset), METAL, Enum.Material.Metal)
	end
end

-- Bajante y farol
piece(Vector3.new(0.35, 21, 0.35), Vector3.new(1.2, 10.5, 11.6), METAL, Enum.Material.Metal)
piece(Vector3.new(0.5, 0.7, 0.5), Vector3.new(1.4, 7.2, 5.2), METAL, Enum.Material.Metal)

return { pieces = #facade:GetChildren() }

-- art/lookdev/build_block.lua
-- Manzana completa de Metrópolis: dos hileras de edificios con tratamiento real, mobiliario de
-- calle y skyline de fondo.
--
-- Sustituye a los volúmenes grises de build_lookdev.lua. Requiere que exista Workspace.LookDev
-- (calle, aceras, coches y ficha) y crea los MaterialVariant CC0 si faltan.

local Lighting = game:GetService("Lighting")
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
end

variant("BrickRedCC0", Enum.Material.Brick, "rbxassetid://71677364092938", "rbxassetid://132924241608465", "rbxassetid://104748136545976")
variant("BrickWarmCC0", Enum.Material.Brick, "rbxassetid://70949398469969", "rbxassetid://95950472085988", "rbxassetid://115976051933338")
variant("ConcreteCC0", Enum.Material.Concrete, "rbxassetid://111200245070453", "rbxassetid://137076655980555", "rbxassetid://79369376727167")
variant("AsphaltCC0", Enum.Material.Asphalt, "rbxassetid://127396582316127", "rbxassetid://89752594019417", "rbxassetid://137425056226224")

local root = Workspace:FindFirstChild("LookDev")
if not root then
	error("Falta Workspace.LookDev: ejecuta antes build_lookdev.lua")
end

for _, name in { "Facade", "Windows", "Backdrop", "Block" } do
	local old = root:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

-- Los volúmenes sin tratar de la hilera se sustituyen por edificios.
local structure = root:FindFirstChild("Structure")
for _, part in structure:GetChildren() do
	if part:IsA("BasePart") and part.Size.Y > 8 and part.Size.X > 5 then
		part:Destroy()
	end
end

local block = Instance.new("Folder")
block.Name = "Block"
block.Parent = root

local WHITE = Color3.new(1, 1, 1)
local STONE = Color3.fromRGB(224, 220, 210)
local GLASS = Color3.fromRGB(34, 46, 58)
local METAL = Color3.fromRGB(52, 54, 58)
local FABRIC = Color3.fromRGB(148, 44, 62)

local function part(size, position, color, material, materialVariant, parent)
	local piece = Instance.new("Part")
	piece.Anchored = true
	piece.Size = size
	piece.Position = position
	piece.Color = color
	piece.Material = material
	if materialVariant then
		piece.MaterialVariant = materialVariant
	end
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent or block
	return piece
end

-- Un edificio: muro, escaparate, ventanas con alféizar y parteluz, y cornisa.
local function building(rowX, centerZ, width, height, facing, brickVariant, awning)
	local origin = Vector3.new(rowX, 0, centerZ)
	local function at(size, offset)
		return origin + Vector3.new(facing * offset.X, offset.Y, offset.Z)
	end

	part(Vector3.new(2, height, width), at(Vector3.new(0, height / 2, 0)), WHITE, Enum.Material.Brick, brickVariant)
	part(Vector3.new(3.0, 0.9, width + 0.6), at(Vector3.new(0.45, height - 0.45, 0)), STONE, Enum.Material.Concrete, "ConcreteCC0")
	part(Vector3.new(0.4, 4.6, width - 3), at(Vector3.new(1.05, 2.8, 0)), GLASS, Enum.Material.Glass)
	if awning then
		part(Vector3.new(2.4, 0.35, width - 4), at(Vector3.new(2.2, 5.8, 0)), FABRIC, Enum.Material.Fabric)
	end

	local columns = math.max(2, math.floor(width / 9))
	local floors = math.max(1, math.floor((height - 9) / 5))
	for floor = 0, floors - 1 do
		local y = 9.5 + floor * 5
		for column = 0, columns - 1 do
			local z = (column - (columns - 1) / 2) * (width / columns)
			part(Vector3.new(0.25, 2.3, 2.0), at(Vector3.new(1.02, y, z)), GLASS, Enum.Material.Glass)
			part(Vector3.new(0.8, 0.26, 2.9), at(Vector3.new(1.3, y - 1.4, z)), STONE, Enum.Material.Concrete, "ConcreteCC0")
			part(Vector3.new(0.5, 2.4, 0.12), at(Vector3.new(1.28, y, z)), METAL, Enum.Material.Metal)
		end
	end
end

local bricks = { "BrickRedCC0", "BrickWarmCC0" }
local plans = {
	{ width = 30, height = 19, awning = true },
	{ width = 26, height = 31, awning = false },
	{ width = 32, height = 22, awning = true },
	{ width = 24, height = 38, awning = false },
}

for _, row in { { x = -35, facing = 1 }, { x = 35, facing = -1 } } do
	for index, plan in ipairs(plans) do
		local z = -54 + (index - 1) * 36
		local brickVariant = bricks[(index + (row.facing > 0 and 0 or 1)) % 2 + 1]
		building(row.x, z, plan.width, plan.height, row.facing, brickVariant, plan.awning)
	end
end

-- Mobiliario: es lo que hace que la calle parezca habitada y no un decorado.
local props = Instance.new("Folder")
props.Name = "Props"
props.Parent = root

local function prop(size, position, color, material)
	return part(size, position, color, material, nil, props)
end

-- Paso de cebra en el cruce
for i = 0, 6 do
	prop(Vector3.new(34, 0.08, 2.2), Vector3.new(0, 0.06, -18 + i * 4.4), Color3.fromRGB(236, 236, 232), Enum.Material.SmoothPlastic)
end

-- Hidrante, buzón, papeleras, bancos y árboles
for _, z in { -40, 40 } do
	prop(Vector3.new(0.9, 1.4, 0.9), Vector3.new(-16.2, 1.1, z), Color3.fromRGB(178, 40, 40), Enum.Material.Metal)
	prop(Vector3.new(1.5, 1.8, 1.0), Vector3.new(-19.5, 1.3, z + 12), Color3.fromRGB(60, 90, 150), Enum.Material.Metal)
	prop(Vector3.new(1.2, 1.6, 1.2), Vector3.new(19.5, 1.2, z), Color3.fromRGB(70, 84, 70), Enum.Material.Metal)
	prop(Vector3.new(4.2, 0.35, 1.0), Vector3.new(16.5, 1.1, z + 8), Color3.fromRGB(96, 66, 42), Enum.Material.Wood)
	prop(Vector3.new(0.4, 0.9, 1.0), Vector3.new(16.5, 0.55, z + 8), Color3.fromRGB(60, 60, 64), Enum.Material.Metal)
	prop(Vector3.new(1.6, 1.2, 1.6), Vector3.new(-17.5, 0.9, z - 14), Color3.fromRGB(78, 78, 74), Enum.Material.Concrete, "ConcreteCC0")
	prop(Vector3.new(0.5, 3.2, 0.5), Vector3.new(-17.5, 3.2, z - 14), Color3.fromRGB(62, 48, 38), Enum.Material.Wood)
	prop(Vector3.new(3.4, 3.4, 3.4), Vector3.new(-17.5, 6.2, z - 14), Color3.fromRGB(58, 92, 54), Enum.Material.Grass)
end

-- Semáforo y marquesina de autobús
prop(Vector3.new(0.4, 7, 0.4), Vector3.new(-16.4, 3.5, -20), METAL, Enum.Material.Metal)
prop(Vector3.new(0.8, 2.2, 0.8), Vector3.new(-16.4, 7.4, -20), Color3.fromRGB(30, 30, 34), Enum.Material.Metal)
prop(Vector3.new(0.7, 0.7, 0.7), Vector3.new(-16.4, 8.2, -20), Color3.fromRGB(210, 60, 50), Enum.Material.Neon)
prop(Vector3.new(0.3, 3.2, 0.3), Vector3.new(17, 1.9, 26), METAL, Enum.Material.Metal)
prop(Vector3.new(0.3, 3.2, 0.3), Vector3.new(17, 1.9, 34), METAL, Enum.Material.Metal)
prop(Vector3.new(8, 0.3, 0.3), Vector3.new(17, 3.5, 30), METAL, Enum.Material.Metal)
prop(Vector3.new(7.6, 0.15, 2.2), Vector3.new(17, 4.2, 30), Color3.fromRGB(160, 186, 200), Enum.Material.Glass)

-- Skyline: siluetas variadas, más oscuras que el cielo y con cuerpos escalonados.
local skyline = Instance.new("Folder")
skyline.Name = "Backdrop"
skyline.Parent = root

local rng = Random.new(77)
for i = 1, 34 do
	local angle = (i / 34) * math.pi * 2
	local radius = 320 + rng:NextNumber() * 220
	local baseHeight = 60 + rng:NextNumber() * 90
	local width = 26 + rng:NextNumber() * 34
	local depth = 26 + rng:NextNumber() * 34
	local x = math.cos(angle) * radius
	local z = math.sin(angle) * radius
	local tone = 0.75 + rng:NextNumber() * 0.35
	local color = Color3.fromRGB(52 * tone, 58 * tone, 70 * tone)

	local tower = part(Vector3.new(width, baseHeight, depth), Vector3.new(x, baseHeight / 2, z), color, Enum.Material.Concrete, nil, skyline)
	tower.CastShadow = false

	-- Segundo cuerpo: rompe la silueta plana de una caja.
	if rng:NextNumber() > 0.35 then
		local topHeight = baseHeight * (0.3 + rng:NextNumber() * 0.4)
		local inset = width * 0.6
		local crown = part(
			Vector3.new(inset, topHeight, inset),
			Vector3.new(x, baseHeight + topHeight / 2, z),
			color:Lerp(Color3.new(0, 0, 0), 0.08),
			Enum.Material.Concrete,
			nil,
			skyline
		)
		crown.CastShadow = false
	end
end

-- Sombras marcadas. Ojo: además de esto hace falta Lighting.LightingStyle = Realistic, que solo
-- se puede poner a mano en Explorer > Lighting > Properties, sección Appearance.
Lighting.ClockTime = 9.4
Lighting.ShadowSoftness = 0.18
Lighting.ExposureCompensation = -0.1
Lighting.GlobalShadows = true

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	atmosphere.Density = 0.3
	atmosphere.Haze = 1.9
end

return { block = #block:GetChildren(), props = #props:GetChildren(), skyline = #skyline:GetChildren() }
-- art/lookdev/build_street.lua
-- Calle definitiva del banco de pruebas. Sustituye a build_block.lua y build_dressing.lua.
--
-- Cuatro correcciones sobre la versión anterior:
--   1. Manzana continua: los edificios se encadenan por anchura, sin huecos. Pared medianera.
--   2. Sol de media mañana (10,6): sombras cortas y calzada iluminada, no en penumbra.
--   3. Rótulos más grandes y con respaldo encendido, que se lean a 30 studs.
--   4. Skyline con bandas de ventanas encendidas, no losas planas.
--
-- Requiere Workspace.LookDev con calle, aceras, coches y ficha (build_lookdev.lua).

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

for _, name in { "Block", "Dressing", "Backdrop", "Facade", "Windows" } do
	local old = root:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
local structure = root:FindFirstChild("Structure")
for _, item in structure:GetChildren() do
	if item:IsA("BasePart") and item.Size.Y > 8 and item.Size.X > 5 then
		item:Destroy()
	end
end

local block = Instance.new("Folder")
block.Name = "Block"
block.Parent = root
local dressing = Instance.new("Folder")
dressing.Name = "Dressing"
dressing.Parent = root

local WHITE = Color3.new(1, 1, 1)
local STONE = Color3.fromRGB(224, 220, 210)
local GLASS = Color3.fromRGB(34, 46, 58)
local METAL = Color3.fromRGB(54, 56, 60)
local FABRIC = Color3.fromRGB(148, 44, 62)
local WARM = Color3.fromRGB(255, 214, 150)

local function piece(parent, size, position, color, material, materialVariant)
	local item = Instance.new("Part")
	item.Anchored = true
	item.Size = size
	item.Position = position
	item.Color = color
	item.Material = material
	if materialVariant then
		item.MaterialVariant = materialVariant
	end
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function sign(position, size, face, text, background, foreground)
	local panel = piece(dressing, size, position, background, Enum.Material.Neon)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(math.floor(size.Z * 45), math.floor(size.Y * 45))
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = foreground
	label.Parent = gui
	gui.Parent = panel
	return panel
end

local shops = { "CAFÉ", "HOTEL", "FARMACIA", "BAR", "BANCO", "CINE", "LIBRERÍA", "TALLER", "FLORISTA", "PANADERÍA" }
local widths = { 30, 26, 32, 24, 28 }
local heights = { 19, 31, 22, 38, 25 }
local bricks = { "BrickRedCC0", "BrickWarmCC0" }

-- Una hilera continua: el siguiente edificio empieza donde acaba el anterior.
for _, row in { { x = -35, facing = 1 }, { x = 35, facing = -1 } } do
	local cursor = -70
	local shopIndex = row.facing > 0 and 0 or 5
	for index = 1, #widths do
		local width = widths[index]
		local height = heights[index]
		local centerZ = cursor + width / 2
		local centerX = row.x
		local face = row.facing > 0 and Enum.NormalId.Right or Enum.NormalId.Left
		local shop = shops[shopIndex + index]
		local brick = bricks[(index + (row.facing > 0 and 0 or 1)) % 2 + 1]

		piece(block, Vector3.new(2, height, width), Vector3.new(centerX, height / 2, centerZ), WHITE, Enum.Material.Brick, brick)
		piece(block, Vector3.new(3.2, 0.9, width + 0.4), Vector3.new(centerX + row.facing * 0.5, height - 0.45, centerZ), STONE, Enum.Material.Concrete, "ConcreteCC0")
		piece(block, Vector3.new(0.4, 4.6, width - 3), Vector3.new(centerX + row.facing * 1.05, 2.8, centerZ), GLASS, Enum.Material.Glass)
		piece(block, Vector3.new(0.3, 3.4, width - 5), Vector3.new(centerX + row.facing * 0.2, 2.5, centerZ), Color3.fromRGB(255, 206, 140), Enum.Material.Neon)
		for mullion = -1, 1 do
			piece(block, Vector3.new(0.5, 4.6, 0.22), Vector3.new(centerX + row.facing * 1.2, 2.8, centerZ + mullion * width / 4), METAL, Enum.Material.Metal)
		end

		-- Rótulo grande con respaldo encendido: se lee a 30 studs.
		sign(
			Vector3.new(centerX + row.facing * 1.25, 7.4, centerZ),
			Vector3.new(0.2, 2.0, math.min(16, width - 6)),
			face,
			shop,
			Color3.fromRGB(34, 26, 20),
			WARM
		)

		-- Ventanas con alféizar y parteluz
		local columns = math.max(2, math.floor(width / 9))
		local floors = math.max(1, math.floor((height - 11) / 5))
		local lit = 0
		for floor = 0, floors - 1 do
			local y = 10.5 + floor * 5
			for column = 0, columns - 1 do
				local z = centerZ + (column - (columns - 1) / 2) * (width / columns)
				lit += 1
				local isLit = (lit % 3) == 0
				piece(
					block,
					Vector3.new(0.25, 2.3, 2.0),
					Vector3.new(centerX + row.facing * 1.02, y, z),
					isLit and Color3.fromRGB(255, 214, 158) or GLASS,
					isLit and Enum.Material.Neon or Enum.Material.Glass
				)
				piece(block, Vector3.new(0.8, 0.26, 2.9), Vector3.new(centerX + row.facing * 1.3, y - 1.4, z), STONE, Enum.Material.Concrete, "ConcreteCC0")
				piece(block, Vector3.new(0.5, 2.4, 0.12), Vector3.new(centerX + row.facing * 1.28, y, z), METAL, Enum.Material.Metal)
			end
		end

		-- Pretil, equipos de azotea y depósito o escape según altura
		piece(dressing, Vector3.new(1.4, 0.7, width), Vector3.new(centerX, height + 0.35, centerZ), STONE, Enum.Material.Concrete)
		piece(dressing, Vector3.new(3.2, 1.6, 3.2), Vector3.new(centerX - row.facing * 3, height + 0.8, centerZ - width * 0.2), Color3.fromRGB(120, 122, 126), Enum.Material.Metal)
		if height >= 30 then
			for floor = 0, 2 do
				local y = 11 + floor * 6
				piece(dressing, Vector3.new(1.6, 0.16, width * 0.5), Vector3.new(centerX + row.facing * 1.6, y, centerZ), METAL, Enum.Material.Metal)
				piece(dressing, Vector3.new(0.12, 1.0, width * 0.5), Vector3.new(centerX + row.facing * 2.3, y + 0.55, centerZ), METAL, Enum.Material.Metal)
			end
		else
			local tankY = height + 4.2
			piece(dressing, Vector3.new(5.4, 5.6, 5.4), Vector3.new(centerX - row.facing * 2, tankY, centerZ + 3), Color3.fromRGB(96, 74, 56), Enum.Material.Wood)
			piece(dressing, Vector3.new(6.2, 0.7, 6.2), Vector3.new(centerX - row.facing * 2, tankY + 3.1, centerZ + 3), Color3.fromRGB(70, 54, 42), Enum.Material.Wood)
		end

		cursor += width
	end
end

-- Mobiliario de calle
for i = 0, 6 do
	piece(dressing, Vector3.new(34, 0.08, 2.2), Vector3.new(0, 0.06, -18 + i * 4.4), Color3.fromRGB(236, 236, 232), Enum.Material.SmoothPlastic)
end
for _, z in { -40, 40 } do
	piece(dressing, Vector3.new(0.9, 1.4, 0.9), Vector3.new(-16.2, 1.1, z), Color3.fromRGB(178, 40, 40), Enum.Material.Metal)
	piece(dressing, Vector3.new(1.5, 1.8, 1.0), Vector3.new(-19.5, 1.3, z + 12), Color3.fromRGB(60, 90, 150), Enum.Material.Metal)
	piece(dressing, Vector3.new(1.2, 1.6, 1.2), Vector3.new(19.5, 1.2, z), Color3.fromRGB(70, 84, 70), Enum.Material.Metal)
	piece(dressing, Vector3.new(4.2, 0.35, 1.0), Vector3.new(16.5, 1.1, z + 8), Color3.fromRGB(96, 66, 42), Enum.Material.Wood)
	piece(dressing, Vector3.new(1.6, 1.2, 1.6), Vector3.new(-17.5, 0.9, z - 14), Color3.fromRGB(78, 78, 74), Enum.Material.Concrete, "ConcreteCC0")
	piece(dressing, Vector3.new(0.5, 3.2, 0.5), Vector3.new(-17.5, 3.2, z - 14), Color3.fromRGB(62, 48, 38), Enum.Material.Wood)
	piece(dressing, Vector3.new(3.4, 3.4, 3.4), Vector3.new(-17.5, 6.2, z - 14), Color3.fromRGB(58, 92, 54), Enum.Material.Grass)
end
piece(dressing, Vector3.new(0.4, 7, 0.4), Vector3.new(-16.4, 3.5, -20), METAL, Enum.Material.Metal)
piece(dressing, Vector3.new(0.7, 0.7, 0.7), Vector3.new(-16.4, 7.2, -20), Color3.fromRGB(210, 60, 50), Enum.Material.Neon)
for _, row in { { x = -35, facing = 1 }, { x = 35, facing = -1 } } do
	local face = row.facing > 0 and Enum.NormalId.Right or Enum.NormalId.Left
	sign(Vector3.new(row.x + row.facing * 1.2, 12.5, -70), Vector3.new(0.15, 1.0, 5.6), face, "CALLE 42", Color3.fromRGB(22, 84, 52), Color3.fromRGB(240, 240, 236))
end

-- Skyline: torres con bandas de ventanas encendidas y materiales variados.
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

	local tower = piece(skyline, Vector3.new(width, baseHeight, depth), Vector3.new(x, baseHeight / 2, z), color, Enum.Material.Concrete)
	tower.CastShadow = false

	if rng:NextNumber() > 0.4 then
		local crownHeight = baseHeight * (0.3 + rng:NextNumber() * 0.4)
		local crown = piece(
			skyline,
			Vector3.new(width * 0.6, crownHeight, depth * 0.6),
			Vector3.new(x, baseHeight + crownHeight / 2, z),
			color:Lerp(Color3.new(0, 0, 0), 0.08),
			Enum.Material.Concrete
		)
		crown.CastShadow = false
	end

	-- Bandas de ventanas: dos tiras verticales encendidas por torre.
	for band = 1, 2 do
		local offset = (band - 0.5) * width * 0.4 - width * 0.2
		local stripe = piece(
			skyline,
			Vector3.new(1.6, baseHeight * 0.8, 0.6),
			Vector3.new(x + offset, baseHeight * 0.42, z - depth / 2 - 0.4),
			Color3.fromRGB(255, 226, 176),
			Enum.Material.Neon
		)
		stripe.CastShadow = false
	end
end

-- Sol de media mañana: sombras cortas y calzada iluminada.
Lighting.ClockTime = 10.6
Lighting.Brightness = 2.3
Lighting.Ambient = Color3.fromRGB(58, 62, 74)
Lighting.OutdoorAmbient = Color3.fromRGB(112, 116, 128)
Lighting.ExposureCompensation = -0.05
Lighting.ShadowSoftness = 0.2
Lighting.GlobalShadows = true

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	atmosphere.Density = 0.26
	atmosphere.Haze = 1.5
end

return { block = #block:GetChildren(), dressing = #dressing:GetChildren(), skyline = #skyline:GetChildren() }
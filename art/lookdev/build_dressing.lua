-- art/lookdev/build_dressing.lua
-- Cierra la manzana: rótulos con texto, escaparates con parteluces e interior encendido, escapes de
-- incendio, depósitos de agua, pretiles, equipos de azotea, señales de calle y contenedores.
--
-- Sin personas: con fichas gigantes y nadie caminando, la ciudad se lee como una maqueta de lujo,
-- que es justo la fantasía del juego.
--
-- Requiere Workspace.LookDev con la carpeta Block ya construida (build_block.lua).

local Workspace = game:GetService("Workspace")

local root = Workspace:FindFirstChild("LookDev")
if not root then
	error("Falta Workspace.LookDev")
end
local block = root:FindFirstChild("Block")
if not block then
	error("Falta LookDev.Block: ejecuta antes build_block.lua")
end

local old = root:FindFirstChild("Dressing")
if old then
	old:Destroy()
end
local dressing = Instance.new("Folder")
dressing.Name = "Dressing"
dressing.Parent = root

local STONE = Color3.fromRGB(224, 220, 210)
local METAL = Color3.fromRGB(54, 56, 60)
local WARM = Color3.fromRGB(255, 214, 150)

local function piece(size, position, color, material, parent)
	local item = Instance.new("Part")
	item.Anchored = true
	item.Size = size
	item.Position = position
	item.Color = color
	item.Material = material
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent or dressing
	return item
end

-- Rótulo con texto, sin assets externos.
local function sign(position, size, face, text, background, foreground)
	local panel = piece(size, position, background, Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(math.floor(size.Z * 40), math.floor(size.Y * 40))
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

-- Los ocho edificios, con su orientación y su tamaño, para vestirlos.
local shops = { "CAFÉ", "HOTEL", "FARMACIA", "BAR", "BANCO", "CINE", "LIBRERÍA", "TALLER" }
local rows = { { x = -35, facing = 1 }, { x = 35, facing = -1 } }
local plans = {
	{ width = 30, height = 19, z = -54 },
	{ width = 26, height = 31, z = -18 },
	{ width = 32, height = 22, z = 18 },
	{ width = 24, height = 38, z = 54 },
}
local shopIndex = 0

for _, row in rows do
	for index, plan in ipairs(plans) do
		shopIndex += 1
		local face = row.facing > 0 and Enum.NormalId.Right or Enum.NormalId.Left
		local wallX = row.x + row.facing * 1.15
		local facadeY = 6.6

		-- Rótulo del local
		sign(
			Vector3.new(0.18, 1.5, math.min(14, plan.width - 8)),
			Vector3.new(wallX, facadeY, plan.z),
			face,
			shops[shopIndex],
			Color3.fromRGB(28, 30, 36),
			WARM
		)

		-- Interior encendido detrás del escaparate y parteluces que lo rompen
		piece(
			Vector3.new(0.3, 3.4, plan.width - 4),
			Vector3.new(row.x + row.facing * 0.2, 2.6, plan.z),
			Color3.fromRGB(255, 206, 140),
			Enum.Material.Neon
		)
		for mullion = -1, 1 do
			piece(
				Vector3.new(0.5, 4.6, 0.22),
				Vector3.new(row.x + row.facing * 1.2, 2.8, plan.z + mullion * (plan.width - 8) / 3),
				METAL,
				Enum.Material.Metal
			)
		end

		-- Pretil en la azotea y un par de equipos
		piece(Vector3.new(1.4, 0.7, plan.width), Vector3.new(row.x, plan.height + 0.35, plan.z), STONE, Enum.Material.Concrete)
		piece(Vector3.new(3.2, 1.6, 3.2), Vector3.new(row.x - row.facing * 3, plan.height + 0.8, plan.z - 5), Color3.fromRGB(120, 122, 126), Enum.Material.Metal)
		piece(Vector3.new(2.4, 1.1, 2.4), Vector3.new(row.x - row.facing * 3, plan.height + 0.55, plan.z + 6), Color3.fromRGB(110, 112, 116), Enum.Material.Metal)

		-- Escape de incendio en los edificios altos
		if plan.height >= 30 then
			for floor = 0, 2 do
				local y = 11 + floor * 6
				piece(Vector3.new(1.6, 0.16, plan.width * 0.5), Vector3.new(row.x + row.facing * 1.6, y, plan.z), METAL, Enum.Material.Metal)
				for bar = -1, 1 do
					piece(
						Vector3.new(0.1, 1.0, 0.1),
						Vector3.new(row.x + row.facing * 2.3, y + 0.5, plan.z + bar * (plan.width * 0.22)),
						METAL,
						Enum.Material.Metal
					)
				end
				piece(Vector3.new(0.12, 0.12, plan.width * 0.5), Vector3.new(row.x + row.facing * 2.3, y + 1.0, plan.z), METAL, Enum.Material.Metal)
			end
		end

		-- Depósito de agua de madera en los tejados bajos: silueta de Manhattan.
		if plan.height < 25 then
			local tankY = plan.height + 4.2
			piece(Vector3.new(5.4, 5.6, 5.4), Vector3.new(row.x - row.facing * 2, tankY, plan.z + 4), Color3.fromRGB(96, 74, 56), Enum.Material.Wood)
			piece(Vector3.new(6.2, 0.7, 6.2), Vector3.new(row.x - row.facing * 2, tankY + 3.1, plan.z + 4), Color3.fromRGB(70, 54, 42), Enum.Material.Wood)
			for legX = -1, 1, 2 do
				for legZ = -1, 1, 2 do
					piece(
						Vector3.new(0.4, 2.8, 0.4),
						Vector3.new(row.x - row.facing * 2 + legX * 2, tankY - 4.0, plan.z + 4 + legZ * 2),
						METAL,
						Enum.Material.Metal
					)
				end
			end
		end
	end
end

-- Señales de calle en la esquina
for _, row in rows do
	local face = row.facing > 0 and Enum.NormalId.Right or Enum.NormalId.Left
	sign(
		Vector3.new(0.15, 0.9, 5.2),
		Vector3.new(row.x + row.facing * 1.2, 12.5, -70),
		face,
		"CALLE 42",
		Color3.fromRGB(22, 84, 52),
		Color3.fromRGB(240, 240, 236)
	)
end

-- Contenedores y cajas junto a un local
piece(Vector3.new(2.2, 2.0, 4.4), Vector3.new(-19.5, 1.0, -30), Color3.fromRGB(56, 96, 132), Enum.Material.Metal)
piece(Vector3.new(2.2, 2.0, 4.4), Vector3.new(-19.5, 1.0, -25), Color3.fromRGB(132, 74, 48), Enum.Material.Metal)
for i = 0, 3 do
	piece(Vector3.new(1.6, 1.2, 1.6), Vector3.new(19.4, 0.6 + i * 1.2, -44), Color3.fromRGB(140, 112, 74), Enum.Material.Wood)
end

-- Ventanas encendidas: unas pocas, para que la calle no sea de mediodía perfecto.
local lit = 0
for _, part in block:GetChildren() do
	if part:IsA("BasePart") and part.Material == Enum.Material.Glass and part.Size.X < 0.4 then
		if (lit % 4) == 0 then
			part.Material = Enum.Material.Neon
			part.Color = Color3.fromRGB(255, 214, 158)
		end
		lit += 1
	end
end

return { dressing = #dressing:GetChildren(), litWindows = math.floor(lit / 4) }
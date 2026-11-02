-- art/lookdev/place_facade.lua
-- Coloca la fachada importada desde Blender en el hueco de la manzana y verifica que la escala
-- llegó bien. Se ejecuta DESPUÉS de importar facade_wall.fbx a mano en Studio.
--
-- Uso: importar con File > Import, Scale Unit = Stud, y luego ejecutar esto por el MCP o pegar en
-- la barra de comandos.
--
-- Qué comprueba:
--   - que la malla mida 20 x 25 x 3 studs (si mide 2000, la escala del importador estaba en cm)
--   - que quede a ras de calle y mirando a la calle
--   - que se haya aplicado el material CC0

local Workspace = game:GetService("Workspace")
local MaterialService = game:GetService("MaterialService")

local TARGET = CFrame.new(-35, 0, -55) * CFrame.Angles(0, math.rad(90), 0)
local EXPECTED = Vector3.new(20, 25, 3)

-- 1) Encontrar lo importado: un Model nuevo o un MeshPart suelto con "facade" en el nombre.
local imported = nil
for _, item in Workspace:GetChildren() do
	if item.Name:lower():find("facade") then
		imported = item
		break
	end
end
if not imported then
	error("No encuentro nada con 'facade' en el nombre. Importa facade_wall.fbx primero.")
end

-- 2) Agrupar si son varias piezas sueltas.
local model = imported
if not model:IsA("Model") then
	model = Instance.new("Model")
	model.Name = "FacadeImported"
	imported.Parent = model
	model.Parent = Workspace
end

-- 3) Medir antes de colocar, para no escalar a ciegas.
local size = model:GetExtentsSize()
local ratio = size.Y / EXPECTED.Y
local scaleReport = string.format("medido %.1f x %.1f x %.1f (esperado 20 x 25 x 3)", size.X, size.Y, size.Z)

if ratio > 5 or ratio < 0.2 then
	-- El importador entró en centímetros o en metros: se corrige solo.
	model:ScaleTo(model:GetScale() / ratio)
	size = model:GetExtentsSize()
	scaleReport = scaleReport .. string.format(" -> corregido a %.1f x %.1f x %.1f", size.X, size.Y, size.Z)
end

-- 4) Colocar. El pivote va a la base y a la altura de la calle.
model:PivotTo(TARGET * CFrame.new(0, size.Y / 2, 0))

-- 5) Quitar el volumen de blockout que ocupa ese hueco.
local block = Workspace:FindFirstChild("LookDev") and Workspace.LookDev:FindFirstChild("Block")
local removed = 0
if block then
	for _, part in block:GetChildren() do
		if part:IsA("BasePart") and part.Size.Y > 8 and part.Size.X > 5 then
			local position = part.Position
			if math.abs(position.X + 35) < 12 and math.abs(position.Z + 55) < 16 then
				part:Destroy()
				removed += 1
			end
		end
	end
end

-- 6) Materiales: el importador trae los suyos, pero si vienen vacíos se aplica el CC0.
local brick = MaterialService:FindFirstChild("BrickRedCC0")
local meshParts = 0
for _, item in model:GetDescendants() do
	if item:IsA("MeshPart") then
		meshParts += 1
		if brick and item.Material == Enum.Material.Plastic and item.TextureID == "" then
			item.Material = Enum.Material.Brick
			item.MaterialVariant = "BrickRedCC0"
			item.Color = Color3.new(1, 1, 1)
		end
	end
end

return {
	imported = model.Name,
	pieces = #model:GetDescendants(),
	meshParts = meshParts,
	size = scaleReport,
	blockoutRemoved = removed,
	position = tostring(model:GetPivot().Position),
}
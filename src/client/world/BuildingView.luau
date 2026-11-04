--!strict
-- Muestra en la ciudad el dueño y el nivel de cada solar. Arte gris: bloques planos con las alturas de
-- `art/escala.md`, que el plan 07 cambia por los modelos aprobados sin tocar esta interfaz. Qué cambió
-- lo decide `WorldRules` comparando vistas; las piezas de cada nivel salen de `CityLayout`.
local CityBuilder = require("./CityBuilder")
local CityLayout = require("../../shared/config/CityLayout")
local WorldRules = require("./WorldRules")

local BLOCK_COLOR = Color3.fromRGB(176, 170, 158)

local BuildingView = {}

local city: CityBuilder.CityHandles? = nil
local buildings: { [number]: Model } = {}
local levels: { [number]: number } = {}
local lastProperties: { [number]: any }? = nil

-- Empieza con una ciudad recién levantada: las piezas de la anterior se fueron con ella.
function BuildingView.bind(handles: CityBuilder.CityHandles)
	city = handles
	buildings = {}
	levels = {}
	lastProperties = nil
end

-- Pone un solar en un nivel. Las escenas la llaman también para enseñar una obra antes de la vista.
function BuildingView.setLevel(index: number, level: number)
	local handles = city
	if handles == nil or levels[index] == level then
		return
	end
	local previous: Model? = buildings[index]
	if previous ~= nil then
		previous:Destroy()
		buildings[index] = nil
	end
	levels[index] = level

	local blocks = CityLayout.buildingBlocks(level)
	if #blocks == 0 then
		return
	end
	local model = Instance.new("Model")
	model.Name = `Building{index}`
	local lot = handles.lotOf(index)
	for order, block in blocks do
		local piece = Instance.new("Part")
		piece.Name = `Block{order}`
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Material = Enum.Material.SmoothPlastic
		piece.Color = BLOCK_COLOR
		piece.Size = Vector3.new(block.width, block.height, block.depth)
		piece.CFrame = lot * CFrame.new(block.along, block.height / 2, 0)
		piece.Parent = model
	end
	model.Parent = handles.model
	buildings[index] = model
end

-- Lleva la ciudad al estado de una vista. Solo toca lo que cambió, así que se puede llamar con cada lote.
function BuildingView.sync(properties: { [number]: any }, colorOf: (ownerId: string) -> Color3?)
	local handles = city
	if handles == nil then
		return
	end
	for _, change in WorldRules.propertyChanges(lastProperties, properties) do
		handles.setOwner(change.index, if change.ownerId ~= nil then colorOf(change.ownerId) else nil)
		BuildingView.setLevel(change.index, change.level)
	end
	lastProperties = properties
end

return BuildingView

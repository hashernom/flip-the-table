--!strict
-- Muestra en la ciudad cada propiedad: su edificio fijo, su dueño, sus marcadores de mejora y los
-- añadidos de su nivel (R-P50). Arte gris: bloques planos, que el plan 07 cambia por los modelos aprobados
-- sin tocar esta interfaz. Qué cambió lo decide `WorldRules` comparando vistas; las piezas de cada nivel
-- salen de `CityLayout`.
local CityBuilder = require("./CityBuilder")
local CityLayout = require("../../shared/config/CityLayout")
local WorldRules = require("./WorldRules")

local BLOCK_COLOR = Color3.fromRGB(176, 170, 158)
local ADDON_COLOR = Color3.fromRGB(140, 134, 124)
-- Colores de la guía de estilo: caliza para las casitas y oro para lo más alto. Nunca verde y rojo (§5.1).
local MARKER_COLORS: { [string]: Color3 } = {
	House = Color3.fromRGB(210, 201, 180),
	Hotel = Color3.fromRGB(168, 174, 180),
	Tower = Color3.fromRGB(201, 162, 39),
}

local BuildingView = {}

local city: CityBuilder.CityHandles? = nil
local buildings: { [number]: Model } = {}
local levels: { [number]: number } = {}
local lastProperties: { [number]: any }? = nil

local function makePiece(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance)
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.Material = Enum.Material.SmoothPlastic
	piece.Color = color
	piece.Size = size
	piece.CFrame = cframe
	piece.Parent = parent
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

	local model = Instance.new("Model")
	model.Name = `Building{index}`
	local lot = handles.lotOf(index)
	-- El solar mira a la calle con su -Z, así que `front` crece hacia el fondo.
	for order, block in CityLayout.buildingBlocks(level) do
		makePiece(
			if order == 1 then "Base" else `Addon{order - 1}`,
			Vector3.new(block.width, block.height, block.depth),
			lot * CFrame.new(block.along, block.y + block.height / 2, block.front),
			if order == 1 then BLOCK_COLOR else ADDON_COLOR,
			model
		)
	end
	for order, marker in CityLayout.levelMarkers(level) do
		makePiece(
			`Marker{order}`,
			Vector3.new(marker.width, marker.height, marker.depth),
			lot * CFrame.new(marker.along, marker.height / 2, marker.front),
			MARKER_COLORS[marker.kind],
			model
		)
	end
	model.Parent = handles.model
	buildings[index] = model
end

-- Empieza con una ciudad recién levantada: las piezas de la anterior se fueron con ella. Cada propiedad
-- ya tiene su edificio antes de que nadie la compre.
function BuildingView.bind(handles: CityBuilder.CityHandles)
	city = handles
	buildings = {}
	levels = {}
	lastProperties = nil
	for _, slot in CityLayout.routeFor(handles.sizeId) do
		if slot.kind == "Property" then
			BuildingView.setLevel(slot.index, 0)
		end
	end
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

--!strict
-- Construye la ciudad gris provisional de un tamaño. Es arte temporal: piezas planas, colores
-- planos y rótulos, nada que se publique como versión pública. Todas las posiciones, los barrios y
-- las etiquetas salen de `CityLayout` y `Strings`, que son puros y están probados con Lune; aquí
-- solo se convierten en `Instance`.
--
-- La ciudad se levanta en el cliente: el servidor no necesita ni una pieza y así el prototipo no
-- gasta presupuesto de partes replicadas.
local CityLayout = require("../../shared/config/CityLayout")
local Strings = require("../../shared/config/Strings")
local Types = require("../../shared/rules/Types")

export type SizeId = CityLayout.SizeId

export type CityHandles = {
	model: Model,
	-- Tamaño del tablero con el que se construyó: lo usan las fichas para saber a qué ruta pertenecen.
	sizeId: SizeId,
	-- Marcador de cada casilla, por número de casilla del tablero.
	squares: { [number]: BasePart },
	-- Carpeta donde `TokenRider` deja las fichas.
	tokens: Folder,
	positionOf: (index: number) -> Vector3,
	facingOf: (index: number) -> number,
	labelOf: (index: number) -> string,
	colorOf: (index: number) -> Color3,
	-- Solar de la casilla: en el suelo, junto a la baldosa, con su frente mirando a la calle.
	lotOf: (index: number) -> CFrame,
	-- Pinta el solar con el color del dueño. La baldosa conserva el de su zona; `nil` libera el solar.
	setOwner: (index: number, color: Color3?) -> (),
	destroy: () -> (),
}

local GREY = Color3.fromRGB(120, 124, 130)
local DARK_GREY = Color3.fromRGB(52, 56, 62)
local WATER = Color3.fromRGB(38, 84, 120)
local TILE_HEIGHT = 0.4
local POST_HEIGHT = 12
local LABEL_DISTANCE = 400
local OWNER_PLATE = "OwnerPlate"

local CityBuilder = {}

-- La casilla como la ve `Strings`: número, tipo, zona y barrio. `CityLayout.Slot` ya los trae; esto
-- solo evita repetir la misma tabla cada vez que hace falta un color o un rótulo.
local function toSquare(slot: CityLayout.Slot): Types.Square
	return {
		index = slot.index,
		kind = slot.kind,
		zoneId = slot.zoneId,
		barrioId = slot.barrioId,
	}
end

local function makePart(properties: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in properties do
		(part :: any)[key] = value
	end
	return part
end

-- Rótulo que se lee desde la calle: mira siempre a la cámara y se apaga a lo lejos para no gastar.
local function makeLabel(text: string, color: Color3): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromScale(16, 4)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, POST_HEIGHT + 2, 0)
	billboard.MaxDistance = LABEL_DISTANCE
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = frame

	return billboard
end

-- Base del anillo y, para los tableros grandes, el agua de las islas exteriores. Es una sola pieza
-- grande por color: abarata el prototipo y no hace falta detalle.
local function makeGround(model: Model, sizeId: SizeId)
	local span = CityLayout.spanFor(sizeId)
	local center = CityLayout.centerFor(sizeId)
	local slab = makePart({
		Name = "Ground",
		Size = Vector3.new(span + 120, 2, span + 120),
		CFrame = CFrame.new(center.x, -TILE_HEIGHT - 1, center.z),
		Color = DARK_GREY,
		CanCollide = true,
	})
	slab.Parent = model

	if #CityLayout.bridgesFor(sizeId) > 0 then
		local water = makePart({
			Name = "Water",
			Size = Vector3.new(span + 120, 0.2, span + 120),
			CFrame = CFrame.new(center.x, -TILE_HEIGHT - 0.6, center.z),
			Color = WATER,
			Material = Enum.Material.Water,
		})
		water.Parent = model
	end
end

-- Los puentes: una pasarela por arista que cruza de una isla a otra. Ocupa solo la junta entre las
-- dos casillas (de ahí el largo de `SEAM`), para no invadir ninguna baldosa ni pelearse con ella.
local SEAM = 4
local BRIDGE_WIDTH = 20

local function makeBridges(model: Model, sizeId: SizeId)
	for order, bridge in CityLayout.bridgesFor(sizeId) do
		local midpoint = Vector3.new(
			bridge.start.x + math.sin(bridge.facing) * bridge.lengthStuds / 2,
			-TILE_HEIGHT / 2,
			bridge.start.z + math.cos(bridge.facing) * bridge.lengthStuds / 2
		)
		local plank = makePart({
			Name = `Bridge{order}`,
			Size = Vector3.new(BRIDGE_WIDTH, TILE_HEIGHT, SEAM),
			CFrame = CFrame.lookAt(
				midpoint,
				midpoint + Vector3.new(math.sin(bridge.facing), 0, math.cos(bridge.facing))
			),
			Color = GREY,
			CanCollide = true,
		})
		plank.Parent = model
	end
end

-- Una casilla: baldosa con el color de la calle, poste del tipo y rótulo con su nombre.
local function makeSquare(model: Model, slot: CityLayout.Slot): Part
	local position = Vector3.new(slot.position.x, 0, slot.position.z)
	local forward = Vector3.new(math.sin(slot.facing), 0, math.cos(slot.facing))
	local color = Color3.fromHex(Strings.colorFor(toSquare(slot)))

	local tile = makePart({
		Name = `Square{slot.index}`,
		Size = Vector3.new(
			CityLayout.SQUARE_SPACING_STUDS - 4,
			TILE_HEIGHT,
			CityLayout.SQUARE_SPACING_STUDS - 4
		),
		CFrame = CFrame.lookAt(position, position + forward),
		Color = color,
		CanCollide = true,
	})
	tile.Parent = model

	local post = makePart({
		Name = "Marker",
		Size = Vector3.new(2, POST_HEIGHT, 2),
		CFrame = CFrame.new(position + Vector3.new(0, POST_HEIGHT / 2, 0)),
		Color = color,
	})
	post.Parent = tile

	local label = makeLabel(Strings.squareLabel(toSquare(slot), slot.ordinal), color)
	label.Adornee = post
	label.Parent = post

	return tile
end

function CityBuilder.build(sizeId: SizeId, parent: Instance): CityHandles
	local existing = parent:FindFirstChild(`City_{sizeId}`)
	if existing then
		existing:Destroy()
	end

	local route = CityLayout.routeFor(sizeId)
	local model = Instance.new("Model")
	model.Name = `City_{sizeId}`

	makeGround(model, sizeId)
	makeBridges(model, sizeId)

	local squares: { [number]: BasePart } = {}
	for _, slot in route do
		squares[slot.index] = makeSquare(model, slot)
	end

	local tokens = Instance.new("Folder")
	tokens.Name = "Tokens"
	tokens.Parent = model

	model.Parent = parent

	local slots: { [number]: CityLayout.Slot } = {}
	for _, slot in route do
		slots[slot.index] = slot
	end

	local function slotAt(index: number): CityLayout.Slot
		local slot = slots[index]
		if slot == nil then
			error(`CityBuilder: la casilla {index} no existe en la ciudad {sizeId}`, 2)
		end
		return slot
	end

	local function lotOf(index: number): CFrame
		local slot = slotAt(index)
		local center = CityLayout.lotCenter(slot)
		local position = Vector3.new(center.x, 0, center.z)
		local road = Vector3.new(slot.position.x, 0, slot.position.z)
		return CFrame.lookAt(position, road)
	end

	local handles: CityHandles = {
		model = model,
		sizeId = sizeId,
		squares = squares,
		tokens = tokens,
		positionOf = function(index: number): Vector3
			local slot = slotAt(index)
			return Vector3.new(slot.position.x, 0, slot.position.z)
		end,
		facingOf = function(index: number): number
			return slotAt(index).facing
		end,
		labelOf = function(index: number): string
			local slot = slotAt(index)
			return Strings.squareLabel(toSquare(slot), slot.ordinal)
		end,
		colorOf = function(index: number): Color3
			local slot = slotAt(index)
			return Color3.fromHex(Strings.colorFor(toSquare(slot)))
		end,
		lotOf = lotOf,
		setOwner = function(index: number, color: Color3?)
			local tile: BasePart? = squares[index]
			if tile == nil then
				return
			end
			local existing = tile:FindFirstChild(OWNER_PLATE)
			if color == nil then
				if existing ~= nil then
					existing:Destroy()
				end
				return
			end
			if existing ~= nil and existing:IsA("BasePart") then
				existing.Color = color
				return
			end
			local plate = makePart({
				Name = OWNER_PLATE,
				Size = Vector3.new(CityLayout.LOT_WIDTH_STUDS, TILE_HEIGHT, CityLayout.LOT_DEPTH_STUDS),
				CFrame = lotOf(index),
				Color = color,
			})
			plate.Parent = tile
		end,
		destroy = function()
			model:Destroy()
		end,
	}

	return handles
end

return CityBuilder

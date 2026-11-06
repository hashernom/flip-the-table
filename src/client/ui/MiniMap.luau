--!strict
-- Minimapa siempre en pantalla: una chapa en la esquina con todas las casillas, su color, dueño y nivel, y
-- dónde está cada ficha. Pulsar una casilla enseña su detalle en el centro, sin mover la cámara de nadie.
-- Qué se enseña lo decide `MiniMapRules`.
local ArtAssets = require("../../shared/config/ArtAssets")
local CityLayout = require("../../shared/config/CityLayout")
local Components = require("./Components")
local MiniMapRules = require("./MiniMapRules")
local Theme = require("./Theme")
local Ui = require("../../shared/config/Ui")
local ViewText = require("./ViewText")

export type Handles = {
	setView: (view: any, names: ViewText.Names?) -> (),
}

-- Parte de su hueco que ocupa cada celda: el resto deja sitio al contorno.
local CELL_FILL = 0.84
local OWNER_STROKE = 2
local TURN_STROKE = 3
-- Las libres quedan a media luz, para que resalte lo que ya tiene dueño. Las especiales van en gris
-- con su símbolo (`Ui.miniMap`).
local FREE_FADE = 0.45
local MAP_PADDING = 10

local MiniMap = {}

local function dot(parent: Instance, size: number, color: Color3)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(size, size)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Theme.corner(frame, size)
end

function MiniMap.create(playerGui: Instance, seatColor: (seat: number) -> Color3): Handles
	local gui = Theme.screenGui(playerGui, "MiniMap", 5)

	local plate = Components.Panel(gui, "Plate", 22)
	-- Siempre arriba a la derecha (2026-11-06). En espejo los jugadores van justo debajo (`Ui.plateColumnTop`).
	plate.root.AnchorPoint = Vector2.new(1, 0)
	plate.root.Position = UDim2.new(1, -Ui.miniMapRight, 0, Ui.miniMapTop)
	plate.root.Size = UDim2.fromOffset(Ui.miniMapSize, Ui.miniMapSize)

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(MAP_PADDING, MAP_PADDING)
	holder.Size = UDim2.new(1, -MAP_PADDING * 2, 1, -MAP_PADDING * 2)
	holder.ZIndex = 5
	holder.Parent = plate.root

	local detail = Components.label(holder, "Detail", "", {
		face = Theme.font.text,
		size = 13,
		align = Enum.TextXAlignment.Center,
		wrap = true,
	})
	detail.AnchorPoint = Vector2.new(0.5, 0.5)
	detail.Position = UDim2.fromScale(0.5, 0.5)
	detail.Size = UDim2.fromScale(0.72, 0.72)

	local cells: { [number]: ImageButton } = {}
	local builtFor: string? = nil
	local selected: number? = nil
	local lastView: any = nil
	local lastNames: ViewText.Names? = nil

	local function showDetail()
		if selected == nil or lastView == nil then
			detail.Text = ""
			return
		end
		detail.Text = table.concat(MiniMapRules.detailLines(lastView, lastNames, selected), "\n")
	end

	-- Los huecos del anillo se calculan una vez por tamaño de tablero: la ciudad no cambia en la partida.
	local function build(sizeId: string)
		for _, cell in cells do
			cell:Destroy()
		end
		cells = {}
		builtFor = sizeId
		selected = nil
		local side = CityLayout.sideFor(sizeId :: any)
		for _, slot in CityLayout.routeFor(sizeId :: any) do
			local cell = Instance.new("ImageButton")
			cell.Name = `Cell{slot.index}`
			cell.AutoButtonColor = false
			cell.BorderSizePixel = 0
			cell.Size = UDim2.fromScale(CELL_FILL / side, CELL_FILL / side)
			cell.Parent = holder
			Theme.corner(cell, 3)
			local index = slot.index
			cell.Activated:Connect(function()
				selected = if selected == index then nil else index
				showDetail()
			end)
			local grid = Instance.new("UIListLayout")
			grid.FillDirection = Enum.FillDirection.Horizontal
			grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
			grid.VerticalAlignment = Enum.VerticalAlignment.Center
			grid.Wraps = true
			grid.Padding = UDim.new(0, 1)
			grid.Parent = cell
			cells[slot.index] = cell
		end
	end

	return {
		setView = function(view: any, names: ViewText.Names?)
			if view == nil or view.players == nil then
				return
			end
			lastView = view
			lastNames = names
			if builtFor ~= view.sizeId then
				build(view.sizeId)
			end
			local side = CityLayout.sideFor(view.sizeId)
			for _, info in MiniMapRules.cells(view) do
				local cell: ImageButton? = cells[info.index]
				if cell ~= nil then
					local room = 1 - 1 / side
					local inset = (1 - CELL_FILL) / 2 / side
					cell.Position = UDim2.fromScale(info.u * room + inset, info.v * room + inset)
					cell.BackgroundColor3 = Color3.fromHex(info.color)
					cell.BackgroundTransparency = if not info.isProperty
						then 0
						elseif info.ownerSeat == nil then FREE_FADE
						else 0
					-- Símbolo de la casilla especial: el mismo icono blanco que lleva pintado en la calle. Va como
					-- imagen de la propia celda, no como hijo: la celda reparte sus hijos (los puntos) en rejilla.
					local iconId = if info.isProperty then nil else ArtAssets.roadIcons[info.kind]
					cell.Image = iconId or ""
					cell.ImageColor3 = Theme.color.limestone
					cell.ScaleType = Enum.ScaleType.Fit
					for _, child in cell:GetChildren() do
						if child:IsA("Frame") or child:IsA("UIStroke") then
							child:Destroy()
						end
					end
					-- El dueño rodea la casilla con su color. El turno manda, en caliza gruesa: el amarillo es
					-- de la acción.
					if info.isTurn or info.ownerSeat ~= nil then
						local stroke = Instance.new("UIStroke")
						stroke.Thickness = if info.isTurn then TURN_STROKE else OWNER_STROKE
						stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
						stroke.Color = if info.isTurn
							then Theme.color.limestone
							else seatColor(info.ownerSeat :: number)
						stroke.Parent = cell
					end
					-- Hipotecada: un punto rojo delante de todo, que se lee aunque no se distinga el color del dueño.
					if info.mortgaged then
						dot(cell, 5, Theme.color.signal)
					end
					for _ = 1, info.level do
						dot(cell, 3, Theme.color.limestone)
					end
					for _, seat in info.tokens do
						dot(cell, 6, seatColor(seat))
					end
				end
			end
			showDetail()
		end,
	}
end

return MiniMap

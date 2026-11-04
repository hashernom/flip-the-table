--!strict
-- Minimapa siempre en pantalla: todas las casillas con su color, dueño y nivel, y dónde está cada ficha.
-- Pulsar una casilla enseña su detalle sin mover la cámara de nadie. Interfaz gris: el diseño final es del
-- plan 09. Qué se enseña lo decide `MiniMapRules`.
local CityLayout = require("../../shared/config/CityLayout")
local MiniMapRules = require("./MiniMapRules")
local Theme = require("./Theme")
local Ui = require("../../shared/config/Ui")
local ViewText = require("./ViewText")

export type Handles = {
	setView: (view: any, names: ViewText.Names?) -> (),
}

-- Parte de su hueco que ocupa cada celda: el resto deja sitio al contorno, para que no se tape con la vecina.
local CELL_FILL = 0.78
local OWNER_STROKE = 3
local TURN_STROKE = 3
local SPECIAL_FADE = 0.75
local FREE_FADE = 0.4

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

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.new(1, -Theme.PADDING, 0, Ui.miniMapTop)
	holder.Size = UDim2.fromScale(Ui.miniMapHeightFraction, Ui.miniMapHeightFraction)
	holder.SizeConstraint = Enum.SizeConstraint.RelativeYY
	holder.BackgroundColor3 = Theme.background
	holder.BackgroundTransparency = 0.45
	holder.BorderSizePixel = 0
	holder.Parent = gui
	Theme.corner(holder)

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(Ui.miniMapMaxSize, Ui.miniMapMaxSize)
	limit.Parent = holder

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.AnchorPoint = Vector2.new(0.5, 0.5)
	detail.Position = UDim2.fromScale(0.5, 0.5)
	detail.Size = UDim2.fromScale(0.68, 0.68)
	detail.BackgroundTransparency = 1
	detail.Font = Theme.font
	detail.TextColor3 = Theme.text
	detail.TextSize = 12
	detail.TextWrapped = true
	detail.Text = ""
	detail.Parent = holder

	local cells: { [number]: TextButton } = {}
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
			local cell = Instance.new("TextButton")
			cell.Name = `Cell{slot.index}`
			cell.Text = ""
			cell.AutoButtonColor = false
			cell.BorderSizePixel = 0
			cell.Size = UDim2.fromScale(CELL_FILL / side, CELL_FILL / side)
			cell.Parent = holder
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
				local cell: TextButton? = cells[info.index]
				if cell ~= nil then
					local room = 1 - 1 / side
					local inset = (1 - CELL_FILL) / 2 / side
					cell.Position = UDim2.fromScale(info.u * room + inset, info.v * room + inset)
					cell.BackgroundColor3 = Color3.fromHex(info.color)
					-- Lo importante es de quién es cada propiedad: las casillas especiales se apagan y las
					-- libres se quedan a media luz, para que resalte lo que ya tiene dueño.
					cell.BackgroundTransparency = if not info.isProperty
						then SPECIAL_FADE
						elseif info.ownerSeat == nil then FREE_FADE
						else 0
					for _, child in cell:GetChildren() do
						if child:IsA("Frame") or child:IsA("UIStroke") then
							child:Destroy()
						end
					end
					-- El dueño rodea la casilla con su color; el turno manda sobre él, en amarillo.
					if info.isTurn or info.ownerSeat ~= nil then
						local stroke = Instance.new("UIStroke")
						stroke.Thickness = if info.isTurn then TURN_STROKE else OWNER_STROKE
						stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
						stroke.Color = if info.isTurn
							then Theme.accent
							else seatColor(info.ownerSeat :: number)
						stroke.Parent = cell
					end
					for _ = 1, info.level do
						dot(cell, 3, Theme.text)
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

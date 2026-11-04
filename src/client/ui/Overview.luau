--!strict
-- Vista general en maqueta. Es la vista que la ficha promete con un botón: dueños, dinero, posiciones
-- y efectos activos de un vistazo, por encima de la ciudad. No interrumpe escenas: la abre y la cierra
-- el cliente, que es quien sabe si hay una escena en marcha.
local Strings = require("../../shared/config/Strings")
local Theme = require("./Theme")

export type Handles = {
	setView: (view: any) -> (),
	setOpen: (open: boolean) -> (),
	isOpen: () -> boolean,
	onToggle: (callback: (open: boolean) -> ()) -> (),
	close: () -> (),
	destroy: () -> (),
}

local EFFECTS: { [string]: string } = {
	Inflation = "Inflación",
	Strike = "Huelga",
	Haunt = "Embrujo",
	Discount = "Descuento",
}

local Overview = {}

function Overview.create(playerGui: Instance): Handles
	local gui = Theme.screenGui(playerGui, "Overview", 8)

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.BackgroundColor3 = Theme.background
	backdrop.BackgroundTransparency = 0.25
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Visible = false
	backdrop.Parent = gui

	local panel = Theme.panel(gui, "Sheet", "Vista general")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.AutomaticSize = Enum.AutomaticSize.None
	panel.Visible = false

	-- El contenido va en una lista con scroll: con ocho asientos, dueños, efectos y posiciones no
	-- caben en una pantalla de móvil, y la maqueta no puede quedarse sin ver lo de abajo.
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, 0, 1, -46)
	scroll.CanvasSize = UDim2.fromScale(1, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.LayoutOrder = 1
	scroll.Parent = panel

	local scrollLayout = Instance.new("UIListLayout")
	scrollLayout.FillDirection = Enum.FillDirection.Vertical
	scrollLayout.Padding = UDim.new(0, Theme.PADDING)
	scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
	scrollLayout.Parent = scroll

	local owners = Theme.panel(scroll, "Owners", "Dueños y dinero")
	owners.Size = UDim2.fromScale(1, 0)
	owners.AutomaticSize = Enum.AutomaticSize.Y

	local effects = Theme.panel(scroll, "Effects", "Efectos activos")
	effects.Size = UDim2.fromScale(1, 0)
	effects.AutomaticSize = Enum.AutomaticSize.Y

	local positions = Theme.panel(scroll, "Positions", "Posiciones")
	positions.Size = UDim2.fromScale(1, 0)
	positions.AutomaticSize = Enum.AutomaticSize.Y

	local open = false
	local listeners: { (boolean) -> () } = {}

	local function fill(container: Frame, lines: { string })
		-- Las filas de `Theme.row` son marcos, no etiquetas: hay que borrarlas por su nombre o el
		-- panel acumula una copia por cada vista que llega.
		for _, child in container:GetChildren() do
			if child:IsA("GuiObject") and child.Name ~= "Title" then
				child:Destroy()
			end
		end
		for index, line in lines do
			local key, value = Theme.row(container, index)
			key.Text = ""
			value.Text = line
			value.TextXAlignment = Enum.TextXAlignment.Left
			value.AnchorPoint = Vector2.new(0, 0)
			value.Position = UDim2.fromScale(0, 0)
			value.Size = UDim2.fromScale(1, 1)
		end
	end

	local function setOpen(value: boolean)
		open = value
		backdrop.Visible = value
		panel.Visible = value
		for _, listener in listeners do
			listener(value)
		end
	end

	backdrop.MouseButton1Click:Connect(function()
		setOpen(false)
	end)

	local handles: Handles = {
		setView = function(view: any)
			if view == nil then
				return
			end
			local ownerLines: { string } = {}
			for _, seated in view.players do
				local tag = if seated.status == "Active" then "" else ` ({seated.status})`
				table.insert(ownerLines, `{seated.id}{tag}: {seated.cash}`)
			end

			local properties = view.properties or {}
			local owned: { string } = {}
			for index, property in properties do
				if property.ownerId ~= nil then
					table.insert(owned, `Casa {index}: {property.ownerId}, nivel {property.level}`)
				end
			end
			for _, line in owned do
				table.insert(ownerLines, line)
			end
			fill(owners, ownerLines)

			local effectLines: { string } = {}
			for _, modifier in view.modifiers or {} do
				local name = EFFECTS[modifier.kind] or modifier.kind
				local zone = if modifier.zoneId ~= nil then ` · {Strings.zone(modifier.zoneId).name}` else ""
				table.insert(effectLines, `{name}{zone} · hasta la ronda {modifier.untilRound}`)
			end
			if view.hotZoneId ~= nil then
				table.insert(effectLines, `Zona Caliente: {Strings.zone(view.hotZoneId).name}`)
			end
			if #effectLines == 0 then
				table.insert(effectLines, "Ninguno")
			end
			fill(effects, effectLines)

			local positionLines: { string } = {}
			for _, seated in view.players do
				table.insert(positionLines, `{seated.id} · casilla {seated.position}`)
			end
			fill(positions, positionLines)
		end,
		isOpen = function(): boolean
			return open
		end,
		onToggle = function(listener: (boolean) -> ())
			table.insert(listeners, listener)
		end,
		setOpen = function(value: boolean)
			setOpen(value)
		end,
		close = function()
			setOpen(false)
		end,
		destroy = function()
			gui:Destroy()
		end,
	}

	-- El botón de la barra abre y cierra la maqueta. Vive aquí para que el HUD no tenga que saber de
	-- este panel.
	handles.setView(nil)
	return handles
end

return Overview

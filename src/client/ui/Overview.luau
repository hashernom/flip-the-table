--!strict
-- Vista general en maqueta. Es la vista que la ficha promete con un botón: dueños, dinero, posiciones
-- y efectos activos de un vistazo, por encima de la ciudad. No interrumpe escenas: la abre y la cierra
-- el cliente, que es quien sabe si hay una escena en marcha.
local Strings = require("../../shared/config/Strings")
local Theme = require("./Theme")
local ViewText = require("./ViewText")

export type Handles = {
	setView: (view: any, names: ViewText.Names?) -> (),
	setOpen: (open: boolean) -> (),
	isOpen: () -> boolean,
	onToggle: (callback: (open: boolean) -> ()) -> (),
	close: () -> (),
	destroy: () -> (),
}

local Overview = {}

function Overview.create(playerGui: Instance): Handles
	local gui = Theme.screenGui(playerGui, "Overview", 8)

	-- Panel lateral y sin fondo: lo importante de esta vista es la ciudad, que tiene que verse y girarse.
	local panel = Theme.panel(gui, "Sheet", "Vista general")
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 12, 0.5, 30)
	-- Tamaño propio: sin él, un Frame mide 100 × 100 y la maqueta se veía como un cuadrado (M17).
	panel.Size = UDim2.fromScale(0.26, 0.75)
	panel.AutomaticSize = Enum.AutomaticSize.None
	panel.Visible = false
	Theme.limitWidth(panel)

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
		panel.Visible = value
		for _, listener in listeners do
			listener(value)
		end
	end

	local handles: Handles = {
		setView = function(view: any, names: ViewText.Names?)
			if view == nil then
				return
			end
			local ownerLines: { string } = {}
			for _, seated in view.players do
				local tag = if seated.status == "Active" then "" else ` ({seated.status})`
				table.insert(ownerLines, `{ViewText.playerName(view, names, seated.id)}{tag}: {seated.cash}`)
			end

			-- Las propiedades con dueño, en el orden del tablero (el diccionario no tiene orden).
			local indices: { number } = {}
			for index, property in view.properties or {} do
				if property.ownerId ~= nil then
					table.insert(indices, index)
				end
			end
			table.sort(indices)
			for _, index in indices do
				local property = view.properties[index]
				table.insert(
					ownerLines,
					`{ViewText.squareName(view, index)}: {ViewText.playerName(view, names, property.ownerId)}, nivel {property.level}`
				)
			end
			fill(owners, ownerLines)

			local effectLines: { string } = {}
			for _, modifier in view.modifiers or {} do
				table.insert(effectLines, ViewText.modifierText(view, names, modifier))
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
				table.insert(
					positionLines,
					`{ViewText.playerName(view, names, seated.id)} · {ViewText.squareName(
						view,
						seated.position
					)}`
				)
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

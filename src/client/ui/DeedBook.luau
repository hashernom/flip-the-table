--!strict
-- «Tus escrituras» (R-P61): un cajón en el lateral izquierdo con todas las propiedades del jugador. Cada
-- escritura va plegada en una fila con su zona, su nombre y lo que cobra ahora; al tocarla se abre entera,
-- como la carta del tablero, con la tabla de rentas completa. Desde ahí se manda la casilla al gestor de
-- abajo (`PropertyManager`), que es el único sitio que construye, vende o hipoteca.
--
-- El cajón se pliega entero con su cabecera para dejar ver la calle, y se abre y se cierra con el gestor.
-- Todo lo que enseña sale de la vista ya resuelta: `PropertyManagerRules.info` da la fila y
-- `ActionMenuRules.deedFor` la escritura entera. Aquí solo se pinta y se pliega.
local ActionMenuRules = require("./ActionMenuRules")
local Board = require("./Board")
local Components = require("./Components")
local HudRules = require("./HudRules")
local PropertyManagerRules = require("./PropertyManagerRules")
local Strings = require("../../shared/config/Strings")
local Theme = require("./Theme")
local Ui = require("../../shared/config/Ui")

local color = Theme.color

local WIDTH = 340
local HEADER_HEIGHT = 52
local BODY_HEIGHT = 402
-- Debajo de la columna de la izquierda (el botón amarillo y la fila de Pactos y Tratos) y por encima del
-- gestor de abajo: el cajón no tapa ningún botón.
local TOP = Ui.panelTop + 74 + Ui.panelGap + 44 + 12
local BOTTOM = Ui.manage.height + Ui.manage.bottomGap + Ui.roadHeight + 16
-- Plegado: una pestaña pequeña, no una barra de lado a lado.
local COLLAPSED_WIDTH = 186
local COLLAPSED_HEIGHT = 40

export type Handles = {
	setOpen: (open: boolean) -> boolean,
	isOpen: () -> boolean,
	setData: (view: any) -> (),
	-- Resalta la escritura que el gestor está enseñando (la mueve la cámara).
	markFocused: (index: number?) -> (),
	-- La casilla elegida va al gestor de abajo.
	onManage: (callback: (index: number) -> ()) -> (),
	destroy: () -> (),
}

local DeedBook = {}

function DeedBook.create(playerGui: Instance): Handles
	local gui = Theme.screenGui(playerGui, "DeedBook", 7)
	gui.Enabled = false

	local plate = Components.Panel(gui, "Drawer", Ui.radius.plate)
	plate.root.AnchorPoint = Vector2.new(0, 0)
	plate.root.Position = UDim2.fromOffset(12, TOP)
	plate.root.Size = UDim2.fromOffset(WIDTH, 320)
	local drawer = plate.root

	local head = Instance.new("TextButton")
	head.Name = "Head"
	head.AutoButtonColor = false
	head.BackgroundColor3 = color.asphaltDeep
	head.BorderSizePixel = 0
	head.Text = ""
	head.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
	head.ZIndex = 5
	head.Parent = plate.body
	Theme.corner(head, Ui.radius.plate)

	local title = Components.label(head, "Title", Strings.upper(Strings.get("deedbook.title")), {
		face = Theme.font.roadBold,
		size = 15,
		tint = color.limestone,
	})
	title.Position = UDim2.fromOffset(16, 0)
	title.Size = UDim2.new(1, -60, 1, 0)
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.ZIndex = 6

	local mark = Board.chevron(head, color.limestone)
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.new(1, -20, 0.5, 0)
	mark.Size = UDim2.fromOffset(14, 14)
	mark.Rotation = 90
	mark.ZIndex = 6

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = color.limestone
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Position = UDim2.fromOffset(0, HEADER_HEIGHT + 8)
	scroll.Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + 8))
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ZIndex = 5
	scroll.Parent = plate.body
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, Theme.space.s)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 8)
	pad.Parent = scroll

	local open = false
	local collapsed = false
	local view: any = nil
	local expanded: number? = nil
	local focused: number? = nil
	local manageListeners: { (index: number) -> () } = {}

	local rebuild: () -> ()

	-- El cajón vive entre dos huecos: debajo de la columna de la izquierda y por encima del gestor. En
	-- pantallas bajas se aprieta en vez de salirse, y nunca baja de la mitad de lo que queda libre.
	local function fit()
		local guiHeight = gui.AbsoluteSize.Y
		if guiHeight <= 0 then
			guiHeight = Ui.referenceViewport.y
		end
		local top = math.min(TOP, guiHeight * 0.34)
		local bottom = math.min(BOTTOM, guiHeight * 0.42)
		drawer.Position = UDim2.fromOffset(12, top)
		drawer.Size = if collapsed
			then UDim2.fromOffset(COLLAPSED_WIDTH, COLLAPSED_HEIGHT)
			else UDim2.fromOffset(WIDTH, math.max(guiHeight - top - bottom, 120))
	end

	local function applyCollapsed()
		scroll.Visible = not collapsed
		head.Size = UDim2.new(1, 0, 0, if collapsed then COLLAPSED_HEIGHT else HEADER_HEIGHT)
		title.TextSize = if collapsed then 13 else 15
		-- Plegado apunta a la derecha («se abre»); abierto, a la izquierda («se cierra»).
		mark.Rotation = if collapsed then -90 else 90
		fit()
	end

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

	-- Fila plegada: la franja de la zona, el nombre y lo que rinde ahora. Toda la fila es el botón.
	local function header(parent: Instance, order: number, index: number): TextButton
		local info = PropertyManagerRules.info(view, index)
		local tint = Color3.fromHex(info.zoneColor)
		local button = Instance.new("TextButton")
		button.Name = `Deed{index}`
		button.AutoButtonColor = false
		button.BackgroundColor3 = tint
		button.BorderSizePixel = 0
		button.Text = ""
		button.Size = UDim2.new(1, 0, 0, 58)
		button.LayoutOrder = order
		button.ZIndex = 6
		button.Parent = parent
		Theme.corner(button, Ui.radius.small)
		local ink = if HudRules.inkFor(info.zoneColor) == "asphalt" then color.asphalt else color.limestone

		local zone = Components.label(button, "Zone", Strings.upper(info.zoneName), {
			face = Theme.font.road,
			size = 11,
			tint = ink,
		})
		zone.Position = UDim2.fromOffset(12, 4)
		zone.Size = UDim2.new(1, -24, 0, 16)
		zone.ZIndex = 7

		local name = Components.label(button, "Title", Strings.upper(info.name), {
			face = Theme.font.roadBold,
			size = 18,
			tint = ink,
			wrap = true,
		})
		name.Position = UDim2.fromOffset(12, 20)
		name.Size = UDim2.new(1, -24, 0, 26)
		name.ZIndex = 7

		local summary = if info.mortgaged
			then Strings.get("manage.mortgaged")
			else `{info.levelText} · {Strings.get("manage.rent", { amount = info.rent })}`
		local detail = Components.label(button, "Detail", summary, {
			face = Theme.font.textBold,
			size = 12,
			tint = ink,
		})
		detail.Position = UDim2.fromOffset(12, 42)
		detail.Size = UDim2.new(1, -24, 0, 14)
		detail.ZIndex = 7

		-- La que el gestor está enseñando lleva un filo de caliza, para no perderla entre las demás.
		if focused == index then
			local rim = Instance.new("UIStroke")
			rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			rim.Color = color.limestone
			rim.Thickness = 3
			rim.Parent = button
		end
		return button
	end

	-- Escritura abierta: la carta entera y el botón que la lleva al gestor.
	local function deedBody(parent: Instance, order: number, index: number)
		local deed = ActionMenuRules.deedFor(view, index)
		if deed == nil then
			return
		end
		local panel = Instance.new("Frame")
		panel.Name = "Body"
		panel.BackgroundColor3 = color.asphaltDeep
		panel.BorderSizePixel = 0
		panel.Size = UDim2.new(1, 0, 0, BODY_HEIGHT)
		panel.LayoutOrder = order
		panel.ZIndex = 6
		panel.Parent = parent
		Theme.corner(panel, Ui.radius.small)

		local card = Components.Deed(panel, "Card", deed)
		card.Position = UDim2.fromOffset(12, 12)
		card.Rotation = 0
		-- El alto sale de la carta: cambia con las filas de renta del tablero.
		local cardHeight = card.Size.Y.Offset
		panel.Size = UDim2.new(1, 0, 0, 12 + cardHeight + 10 + 40 + 12)

		local manage = Components.SecondaryButton(panel, "Manage", Strings.get("deedbook.manage"))
		manage.root.Position = UDim2.fromOffset(12, 12 + cardHeight + 10)
		manage.root.Size = UDim2.fromOffset(262, 40)
		manage.onActivated(function()
			for _, listener in manageListeners do
				listener(index)
			end
		end)
	end

	rebuild = function()
		local current = view
		if current == nil then
			return
		end
		for _, child in scroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local owned = PropertyManagerRules.owned(current, current.playerId)
		if #owned == 0 then
			local empty = Components.label(scroll, "Empty", Strings.get("deedbook.empty"), {
				face = Theme.font.text,
				size = 15,
				tint = color.limestone,
				wrap = true,
			})
			empty.Size = UDim2.new(1, -16, 0, 40)
			empty.ZIndex = 6
			return
		end
		for order, index in owned do
			local row = Instance.new("Frame")
			row.Name = `Row{index}`
			row.BackgroundTransparency = 1
			row.Size = UDim2.fromScale(1, 0)
			row.AutomaticSize = Enum.AutomaticSize.Y
			row.LayoutOrder = order
			row.ZIndex = 6
			row.Parent = scroll
			local stack = Instance.new("UIListLayout")
			stack.Padding = UDim.new(0, 4)
			stack.SortOrder = Enum.SortOrder.LayoutOrder
			stack.Parent = row

			local button = header(row, 1, index)
			button.Activated:Connect(function()
				expanded = if expanded == index then nil else index
				rebuild()
			end)
			if expanded == index then
				deedBody(row, 2, index)
			end
		end
	end

	local function setOpen(value: boolean): boolean
		if value then
			local current = view
			if current == nil or #PropertyManagerRules.owned(current, current.playerId) == 0 then
				return false
			end
		end
		if open == value then
			return open
		end
		open = value
		gui.Enabled = value
		if value then
			expanded = nil
			applyCollapsed()
			rebuild()
		end
		return open
	end

	head.Activated:Connect(function()
		collapsed = not collapsed
		applyCollapsed()
	end)

	return {
		setOpen = setOpen,
		isOpen = function(): boolean
			return open
		end,
		setData = function(next: any)
			view = next
			if open then
				local owned = if next ~= nil then PropertyManagerRules.owned(next, next.playerId) else {}
				if #owned == 0 then
					setOpen(false)
				else
					rebuild()
				end
			end
		end,
		markFocused = function(index: number?)
			if focused == index then
				return
			end
			focused = index
			if open then
				rebuild()
			end
		end,
		onManage = function(callback: (index: number) -> ())
			table.insert(manageListeners, callback)
		end,
		destroy = function()
			gui:Destroy()
		end,
	}
end

return DeedBook

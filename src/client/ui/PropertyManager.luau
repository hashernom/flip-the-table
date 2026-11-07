--!strict
-- «Gestionar propiedades» (R-P53). Una ficha al pie de la pantalla con la propiedad que la cámara enseña
-- en primer plano, dos flechas para pasar a la anterior o a la siguiente y los cuatro botones: construir,
-- vender un nivel, hipotecar y levantar la hipoteca. Solo se activan los que el servidor da por legales,
-- así que fuera del turno propio se mira pero no se toca.
--
-- Qué se enseña lo decide `PropertyManagerRules`; aquí solo se pinta. La cámara la mueve `main.client`
-- con `onFocus`, y las acciones salen por `onAction`.
local UserInputService = game:GetService("UserInputService")

local Board = require("./Board")
local Components = require("./Components")
local PropertyManagerRules = require("./PropertyManagerRules")
local Strings = require("../../shared/config/Strings")
local Theme = require("./Theme")
local Ui = require("../../shared/config/Ui")

local color = Theme.color
local font = Theme.font

export type Handles = {
	setOpen: (open: boolean) -> boolean,
	-- Abre el gestor directamente en una casilla del jugador (desde el libro de escrituras).
	focus: (index: number) -> boolean,
	isOpen: () -> boolean,
	-- Vista vigente y acciones de gestión legales por casilla.
	setData: (view: any, byIndex: { [number]: { any } }) -> (),
	onAction: (callback: (action: any) -> ()) -> (),
	-- Casilla enseñada (nil al cerrar): la cámara la sigue.
	onFocus: (callback: (index: number?) -> ()) -> (),
	destroy: () -> (),
}

local PropertyManager = {}

-- Botón discreto: solo un contorno fino sobre el papel y el texto en asfalto. Desactivado, casi se borra.
local function quietButton(parent: Instance, name: string, text: string, enabled: boolean): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundColor3 = color.asphalt
	button.BackgroundTransparency = 1
	button.Active = enabled
	button.Parent = parent
	Theme.corner(button, Ui.radius.pill)
	local rim = Instance.new("UIStroke")
	rim.Color = color.asphalt
	rim.Thickness = 1.5
	rim.Transparency = if enabled then 0.15 else 0.75
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Parent = button
	local label = Components.label(button, "Text", Strings.upper(text), {
		face = font.roadBold,
		size = 12,
		tint = color.asphalt,
		align = Enum.TextXAlignment.Center,
	})
	label.Size = UDim2.fromScale(1, 1)
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextTransparency = if enabled then 0 else 0.65
	if enabled then
		button.MouseEnter:Connect(function()
			button.BackgroundTransparency = 0
			label.TextColor3 = color.limestone
		end)
		button.MouseLeave:Connect(function()
			button.BackgroundTransparency = 1
			label.TextColor3 = color.asphalt
		end)
	end
	return button
end

local function arrow(parent: Instance, name: string, rotation: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundColor3 = color.asphalt
	button.Size = UDim2.fromOffset(Ui.manage.arrowWidth, Ui.manage.height)
	button.Parent = parent
	Theme.corner(button, Ui.radius.card)
	local rim = Instance.new("UIStroke")
	rim.Color = color.limestone
	rim.Thickness = 2
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Parent = button
	local mark = Board.chevron(button, color.limestone)
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.fromScale(0.5, 0.5)
	mark.Size = UDim2.fromOffset(22, 22)
	mark.Rotation = rotation
	for _, bar in mark:GetChildren() do
		if bar:IsA("Frame") then
			bar.Size = UDim2.fromOffset(14, 3)
			bar.Position = UDim2.new(0.5, (bar.Position.X.Offset :: number) * 1.6, 0.5, 0)
		end
	end
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = Theme.buttonHot
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = color.asphalt
	end)
	return button
end

function PropertyManager.create(playerGui: Instance): Handles
	local config = Ui.manage
	local gui = Instance.new("ScreenGui")
	gui.Name = "PropertyManager"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.DisplayOrder = 6
	gui.Enabled = false
	gui.Parent = playerGui

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 1)
	row.Position = UDim2.new(0.5, 0, 1, -(Ui.roadHeight + config.bottomGap))
	row.Size = UDim2.fromOffset(config.width + 2 * (config.arrowWidth + config.gap), config.height)
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, config.gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local previous = arrow(row, "Previous", 90)
	previous.LayoutOrder = 1

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.BackgroundColor3 = color.limestone
	card.Size = UDim2.fromOffset(config.width, config.height)
	card.LayoutOrder = 2
	card.Parent = row
	Theme.corner(card, Ui.radius.card)
	local cardRim = Instance.new("UIStroke")
	cardRim.Color = color.asphalt
	cardRim.Thickness = 3
	cardRim.Parent = card

	local nextButton = arrow(row, "Next", -90)
	nextButton.LayoutOrder = 3

	-- Franja de la zona: su color, su nombre y en qué propiedad de cuántas va.
	local band = Instance.new("Frame")
	band.Name = "Zone"
	band.BorderSizePixel = 0
	band.Size = UDim2.new(1, 0, 0, config.band)
	band.Parent = card
	Theme.corner(band, Ui.radius.card)
	local bandFoot = Instance.new("Frame")
	bandFoot.BorderSizePixel = 0
	bandFoot.AnchorPoint = Vector2.new(0, 1)
	bandFoot.Position = UDim2.fromScale(0, 1)
	bandFoot.Size = UDim2.fromScale(1, 0.5)
	bandFoot.Parent = band
	local zoneName =
		Components.label(band, "Name", "", { face = font.roadBold, size = 12, tint = color.asphalt })
	zoneName.Position = UDim2.fromOffset(16, 0)
	zoneName.Size = UDim2.fromScale(0.6, 1)
	zoneName.ZIndex = 2
	local counter = Components.label(band, "Count", "", {
		face = font.roadBold,
		size = 14,
		tint = color.asphalt,
		align = Enum.TextXAlignment.Right,
	})
	counter.AnchorPoint = Vector2.new(1, 0)
	counter.Position = UDim2.new(1, -16, 0, 0)
	counter.Size = UDim2.new(0.4, -16, 1, 0)
	counter.ZIndex = 2

	local name =
		Components.label(card, "Title", "", { face = font.roadBold, size = 22, tint = color.asphalt })
	name.Position = UDim2.fromOffset(14, config.band + 6)
	name.Size = UDim2.new(1, -28, 0, 28)
	name.TextScaled = true
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = Theme.textSize(22)
	fit.MinTextSize = 14
	fit.Parent = name

	local detail =
		Components.label(card, "Detail", "", { face = font.textBold, size = 13, tint = color.asphalt })
	detail.Position = UDim2.fromOffset(14, config.band + 36)
	detail.Size = UDim2.new(1, -28, 0, 18)

	local note = Components.label(card, "Note", "", { face = font.textBold, size = 12, tint = color.signal })
	note.Position = UDim2.fromOffset(14, config.band + 55)
	note.Size = UDim2.new(1, -28, 0, 16)

	local grid = Instance.new("Frame")
	grid.Name = "Buttons"
	grid.BackgroundTransparency = 1
	grid.AnchorPoint = Vector2.new(0, 1)
	grid.Position = UDim2.new(0, 12, 1, -12)
	grid.Size = UDim2.new(1, -24, 0, 2 * config.buttonHeight + 6)
	grid.Parent = card
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.5, -3, 0, config.buttonHeight)
	gridLayout.CellPadding = UDim2.fromOffset(6, 6)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local close = Components.SecondaryButton(gui, "Close", Strings.get("manage.close"), "Esc")
	close.root.AnchorPoint = Vector2.new(1, 1)
	close.root.Position =
		UDim2.new(0.5, config.width / 2, 1, -(Ui.roadHeight + config.bottomGap + config.height + 10))
	close.root.Size = UDim2.fromOffset(130, 38)

	local open = false
	local current: number? = nil
	local lastView: any = nil
	local lastByIndex: { [number]: { any } } = {}
	local actionListeners: { (action: any) -> () } = {}
	local focusListeners: { (index: number?) -> () } = {}

	local function emitFocus(index: number?)
		for _, listener in focusListeners do
			listener(index)
		end
	end

	local function paint()
		local view = lastView
		if view == nil then
			return
		end
		local list = PropertyManagerRules.owned(view, view.playerId)
		if current == nil or table.find(list, current) == nil then
			current = PropertyManagerRules.step(list, nil, 1)
		end
		local index = current
		if index == nil then
			return
		end
		local info = PropertyManagerRules.info(view, index, lastByIndex[index])
		local zoneTint = Color3.fromHex(info.zoneColor)
		band.BackgroundColor3 = zoneTint
		bandFoot.BackgroundColor3 = zoneTint
		zoneName.Text = Strings.upper(info.zoneName)
		counter.Text = Strings.get("manage.count", { at = table.find(list, index) or 1, total = #list })
		name.Text = Strings.upper(info.name)
		detail.Text = `{info.levelText} · {Strings.get("manage.rentNow", { amount = info.rentText })}`
		local anyLegal = false
		for _, button in info.buttons do
			if button.action ~= nil then
				anyLegal = true
			end
		end
		note.Text = if info.mortgaged
			then Strings.get("manage.mortgaged")
			elseif not anyLegal then Strings.get("manage.notYourTurn")
			else ""
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for order, button in info.buttons do
			local action = button.action
			local made = quietButton(grid, button.kind, button.label, action ~= nil)
			made.LayoutOrder = order
			if action ~= nil then
				made.Activated:Connect(function()
					for _, listener in actionListeners do
						listener(action)
					end
				end)
			end
		end
		previous.Visible = #list > 1
		nextButton.Visible = #list > 1
		emitFocus(index)
	end

	local function move(delta: number)
		local view = lastView
		if view == nil or not open then
			return
		end
		current = PropertyManagerRules.step(PropertyManagerRules.owned(view, view.playerId), current, delta)
		paint()
	end

	-- Devuelve si se abrió: sin propiedades no hay nada que enseñar. Con `wanted`, empieza por esa
	-- casilla si es del jugador (lo usa el libro de escrituras al mandar una al gestor).
	local function setOpen(value: boolean, wanted: number?): boolean
		if value then
			local view = lastView
			if view == nil or #PropertyManagerRules.owned(view, view.playerId) == 0 then
				return false
			end
			if
				wanted ~= nil
				and table.find(PropertyManagerRules.owned(view, view.playerId), wanted) ~= nil
			then
				current = wanted
			end
		end
		if open == value then
			return open
		end
		open = value
		gui.Enabled = value
		if value then
			paint()
		else
			emitFocus(nil)
		end
		return open
	end

	previous.Activated:Connect(function()
		move(-1)
	end)
	nextButton.Activated:Connect(function()
		move(1)
	end)
	close.onActivated(function()
		setOpen(false)
	end)

	local connection = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not open then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			setOpen(false)
		elseif processed then
			return
		elseif input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.A then
			move(-1)
		elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.D then
			move(1)
		end
	end)

	return {
		setOpen = setOpen,
		focus = function(index: number): boolean
			return setOpen(true, index)
		end,
		isOpen = function(): boolean
			return open
		end,
		setData = function(view: any, byIndex: { [number]: { any } })
			lastView = view
			lastByIndex = byIndex
			if open then
				if #PropertyManagerRules.owned(view, view.playerId) == 0 then
					setOpen(false)
				else
					paint()
				end
			end
		end,
		onAction = function(callback: (action: any) -> ())
			table.insert(actionListeners, callback)
		end,
		onFocus = function(callback: (index: number?) -> ())
			table.insert(focusListeners, callback)
		end,
		destroy = function()
			connection:Disconnect()
			gui:Destroy()
		end,
	}
end

return PropertyManager

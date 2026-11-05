--!strict
-- Panel de decisión, a la derecha, bajo el minimapa. Pinta lo que decide `ActionMenuRules`: la escritura de
-- la casilla, el único botón amarillo, la renuncia, el control de puja y la lista de opciones. No decide nada
-- por su cuenta: si un botón está aquí, es que su acción es legal. Entra por la derecha y se va por la derecha.
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ActionMenuRules = require("./ActionMenuRules")
local Components = require("./Components")
local Strings = require("../../shared/config/Strings")
local Theme = require("./Theme")
local Ui = require("../../shared/config/Ui")

export type Handles = {
	-- `extras` son botones que no vienen de `legalActions`: tratos y pactos se deciden en su propia
	-- ventana y el motor no los enumera, así que sin esto no habría forma de abrirlos.
	-- `context` lleva la vista y los nombres.
	setLegal: (
		legal: { any },
		extras: { { id: string, label: string, action: any } }?,
		context: ActionMenuRules.Context?
	) -> (),
	-- Acción elegida por el jugador. El cliente la manda al servidor tal cual.
	onAction: (callback: (action: any) -> ()) -> (),
	destroy: () -> (),
}

local ActionMenu = {}

function ActionMenu.create(playerGui: Instance): Handles
	local gui = Theme.screenGui(playerGui, "ActionMenu", 6)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundTransparency = 1
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Size = UDim2.new(0, Ui.panelWidth, 1, -Ui.panelTop - Ui.roadHeight - Ui.panelGap)
	panel.Parent = gui

	local shownAt = UDim2.new(1, -Ui.panelRight, 0, Ui.panelTop)
	local hiddenAt = UDim2.new(1, Ui.panelWidth + 20, 0, Ui.panelTop)
	panel.Position = hiddenAt

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, Ui.panelGap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local callback: ((action: any) -> ())? = nil
	local function emit(action: any)
		local target = callback
		if target ~= nil and action ~= nil then
			target(action)
		end
	end

	local currentKey = ""
	local isShown = false
	local bid: number? = nil
	local bounds: ActionMenuRules.BidControl? = nil
	local bidCaption: TextLabel? = nil
	local primaryButton: Components.Button? = nil
	local primaryAction: any = nil
	local declineAction: any = nil

	local function clear()
		for _, child in panel:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		bidCaption = nil
		primaryButton = nil
		primaryAction = nil
		declineAction = nil
	end

	local function setShown(show: boolean)
		if show == isShown then
			return
		end
		isShown = show
		Components.tween(panel, if show then Ui.motion.open else Ui.motion.close, {
			Position = if show then shownAt else hiddenAt,
		})
	end

	local function refreshBid()
		local range = bounds
		if range == nil then
			return
		end
		local current = ActionMenuRules.clampBid(bid, range)
		bid = current
		local button = primaryButton
		if button ~= nil then
			button.setText(Strings.upper(Strings.get("action.bid", { amount = current })))
		end
		local caption = bidCaption
		if caption ~= nil then
			caption.Text = Strings.get("panel.bidRange", { min = range.min, max = range.max })
		end
		primaryAction = { type = "Bid", amount = current }
	end

	local function nudge(delta: number)
		local range = bounds
		if range ~= nil then
			bid = ActionMenuRules.clampBid(ActionMenuRules.clampBid(bid, range) + delta, range)
			refreshBid()
		end
	end

	-- La escritura se reduce en pantallas bajas: botón y renuncia tienen que caber siempre.
	local function deedScale(): number
		local camera = Workspace.CurrentCamera
		local height = if camera ~= nil then camera.ViewportSize.Y else Ui.referenceViewport.y
		local room = height - Ui.panelTop - Ui.roadHeight - Ui.panelActionsHeight
		return math.clamp(room / Ui.deedHeight, Ui.deedMinScale, 1)
	end

	local function build(view: ActionMenuRules.Panel, extras: { { id: string, label: string, action: any } }?)
		clear()
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end

		local title = view.title
		if title ~= nil then
			local plate = Components.Panel(panel, "Title", Ui.radius.card)
			plate.root.Size = UDim2.new(1, -6, 0, 40)
			plate.root.LayoutOrder = nextOrder()
			local text = Components.label(plate.root, "Text", Strings.upper(title), {
				face = Theme.font.roadBold,
				size = 18,
				align = Enum.TextXAlignment.Center,
			})
			text.Size = UDim2.fromScale(1, 1)
			text.ZIndex = 5
		end

		local deed = view.deed
		if deed ~= nil then
			-- La escritura va en un hueco del tamaño que ocupa de verdad, ya ladeada dentro.
			local scale = deedScale()
			local slot = Instance.new("Frame")
			slot.Name = "DeedSlot"
			slot.BackgroundTransparency = 1
			slot.LayoutOrder = nextOrder()
			slot.Parent = panel
			local card = Components.Deed(slot, "Deed", deed)
			card.AnchorPoint = Vector2.new(0.5, 0)
			card.Position = UDim2.fromScale(0.5, 0)
			card.Rotation = -2.2
			local cardScale = Instance.new("UIScale")
			cardScale.Scale = scale
			cardScale.Parent = card
			slot.Size = UDim2.new(1, 0, 0, math.ceil(card.Size.Y.Offset * scale) + 6)
		end

		local range = view.bid
		bounds = range
		if range == nil then
			bid = nil
		else
			local row = Instance.new("Frame")
			row.Name = "BidRow"
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 44)
			row.LayoutOrder = nextOrder()
			row.Parent = panel
			local rowLayout = Instance.new("UIListLayout")
			rowLayout.FillDirection = Enum.FillDirection.Horizontal
			rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			rowLayout.Padding = UDim.new(0, 6)
			rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
			rowLayout.Parent = row
			for index, delta in { -range.jump, -range.step, range.step, range.jump } do
				local sign = if delta > 0 then "+" else "−"
				local step = Components.SecondaryButton(row, `Step{index}`, `{sign}{math.abs(delta)}`)
				step.root.Size = UDim2.fromOffset(68, 44)
				step.root.LayoutOrder = index
				step.onActivated(function()
					nudge(delta)
				end)
			end
			local caption = Components.label(panel, "BidRange", "", {
				face = Theme.font.textBold,
				size = 15,
				align = Enum.TextXAlignment.Center,
			})
			caption.Size = UDim2.new(1, 0, 0, 18)
			caption.LayoutOrder = nextOrder()
			bidCaption = caption
		end

		local primary = view.primary
		if primary ~= nil then
			primaryAction = primary.action
			local button =
				Components.PrimaryButton(panel, "Primary", Strings.upper(view.primaryText or primary.label))
			button.root.Size = UDim2.new(1, -4, 0, 74)
			button.root.Rotation = 1.2
			button.root.LayoutOrder = nextOrder()
			button.onActivated(function()
				emit(primaryAction)
			end)
			primaryButton = button
		end

		local decline = view.decline
		if decline ~= nil then
			declineAction = decline.action
			local action = decline.action
			local button = Components.SecondaryButton(panel, "Decline", Strings.get("action.decline"), "N")
			button.root.Size = UDim2.new(1, -60, 0, 44)
			button.root.Rotation = -0.8
			button.root.LayoutOrder = nextOrder()
			button.onActivated(function()
				emit(action)
			end)
		end

		if #view.options > 0 then
			-- La lista usa lo que quede de columna y hace scroll: con muchas cartas nada se sale.
			local list = Instance.new("ScrollingFrame")
			list.Name = "Options"
			list.BackgroundTransparency = 1
			list.BorderSizePixel = 0
			list.AutomaticCanvasSize = Enum.AutomaticSize.Y
			list.CanvasSize = UDim2.fromScale(0, 0)
			list.ScrollingDirection = Enum.ScrollingDirection.Y
			list.ScrollBarThickness = 5
			list.ScrollBarImageColor3 = Theme.color.limestone
			list.LayoutOrder = nextOrder()
			list.Parent = panel
			local listLayout = Instance.new("UIListLayout")
			listLayout.Padding = UDim.new(0, 6)
			listLayout.SortOrder = Enum.SortOrder.LayoutOrder
			listLayout.Parent = list
			local listPad = Instance.new("UIPadding")
			listPad.PaddingTop = UDim.new(0, 3)
			listPad.PaddingBottom = UDim.new(0, 3)
			listPad.PaddingLeft = UDim.new(0, 3)
			listPad.PaddingRight = UDim.new(0, 9)
			listPad.Parent = list
			for index, option in view.options do
				local action = option.action
				local button = Components.OptionButton(list, `Option{index}`, option.label)
				button.root.LayoutOrder = index
				if action == nil then
					button.setEnabled(false)
				else
					button.onActivated(function()
						emit(action)
					end)
				end
			end
			local function fit()
				local used = 0
				for _, child in panel:GetChildren() do
					if child:IsA("GuiObject") and child ~= list then
						used += child.AbsoluteSize.Y + Ui.panelGap
					end
				end
				local room = math.max(120, panel.AbsoluteSize.Y - used)
				list.Size = UDim2.new(1, 0, 0, math.min(listLayout.AbsoluteContentSize.Y + 6, room))
			end
			listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
			panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
			task.defer(fit)
		end

		if extras ~= nil and #extras > 0 then
			local row = Instance.new("Frame")
			row.Name = "Social"
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 44)
			row.LayoutOrder = nextOrder()
			row.Parent = panel
			local rowLayout = Instance.new("UIListLayout")
			rowLayout.FillDirection = Enum.FillDirection.Horizontal
			rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			rowLayout.Padding = UDim.new(0, 8)
			rowLayout.Parent = row
			for _, extra in extras do
				local action = extra.action
				local button = Components.SecondaryButton(row, `Extra_{extra.id}`, extra.label)
				button.root.Size = UDim2.fromOffset(140, 44)
				button.onActivated(function()
					emit(action)
				end)
			end
		end

		refreshBid()
	end

	-- Reconstruir solo si algo cambió: una vista nueva no debe hacer parpadear ni soltar la puja elegida.
	local function keyOf(view: ActionMenuRules.Panel, extras: { any }?): string
		local parts: { string } = { view.title or "", if view.deed ~= nil then view.deed.name else "" }
		if view.primary ~= nil then
			table.insert(parts, view.primary.id)
		end
		if view.decline ~= nil then
			table.insert(parts, view.decline.id)
		end
		if view.bid ~= nil then
			table.insert(parts, `bid{view.bid.step}`)
		end
		for _, option in view.options do
			table.insert(parts, option.label)
		end
		local extraList: { any } = if extras ~= nil then extras else {}
		for _, extra in extraList do
			table.insert(parts, extra.label)
		end
		return table.concat(parts, "|")
	end

	local connection = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not isShown then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space then
			emit(primaryAction)
		elseif input.KeyCode == Enum.KeyCode.N and declineAction ~= nil then
			emit(declineAction)
		end
	end)

	return {
		setLegal = function(
			legal: { any },
			extras: { { id: string, label: string, action: any } }?,
			context: ActionMenuRules.Context?
		)
			local view = ActionMenuRules.panelFor(legal, context)
			local empty = view.primary == nil
				and #view.options == 0
				and (extras == nil or #(extras :: any) == 0)
			if empty then
				setShown(false)
				currentKey = ""
				bounds = nil
				bid = nil
				return
			end
			local key = keyOf(view, extras)
			if key ~= currentKey then
				currentKey = key
				build(view, extras)
			else
				bounds = view.bid
				refreshBid()
			end
			setShown(true)
		end,
		onAction = function(target: (action: any) -> ())
			callback = target
		end,
		destroy = function()
			connection:Disconnect()
			gui:Destroy()
		end,
	}
end

return ActionMenu

--!strict
-- Panel de decisión, a la derecha, bajo el minimapa. Pinta lo que decide `ActionMenuRules`: la escritura de
-- la casilla, el único botón amarillo, la renuncia, el control de puja y la lista de opciones. No decide nada
-- por su cuenta: si un botón está aquí, es que su acción es legal. Entra por la derecha y se va por la derecha.
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ActionMenuRules = require("./ActionMenuRules")
local Board = require("./Board")
local Cards = require("../../shared/config/Cards")
local Components = require("./Components")
local Strings = require("../../shared/config/Strings")
local Theme = require("./Theme")
local Ui = require("../../shared/config/Ui")
local ViewText = require("./ViewText")

export type Handles = {
	-- `extras` son botones que no vienen de `legalActions`: tratos y pactos se deciden en su propia
	-- ventana y el motor no los enumera, así que sin esto no habría forma de abrirlos.
	-- `context` lleva la vista y los nombres.
	setLegal: (
		legal: { any },
		extras: { { id: string, label: string, action: any, key: string? } }?,
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
	-- En espejo (`Ui.hudMirror`) el panel entra por la izquierda.
	panel.AnchorPoint = if Ui.hudMirror then Vector2.new(0, 0) else Vector2.new(1, 0)
	panel.Size = UDim2.new(0, Ui.panelWidth, 1, -Ui.panelTop - Ui.roadHeight - Ui.panelGap)
	panel.Parent = gui

	local shownAt = if Ui.hudMirror
		then UDim2.fromOffset(Ui.panelRight, Ui.panelTop)
		else UDim2.new(1, -Ui.panelRight, 0, Ui.panelTop)
	local hiddenAt = if Ui.hudMirror
		then UDim2.fromOffset(-(Ui.panelWidth + 20), Ui.panelTop)
		else UDim2.new(1, Ui.panelWidth + 20, 0, Ui.panelTop)
	panel.Position = hiddenAt

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, Ui.panelGap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local callback: ((action: any) -> ())? = nil
	-- Vista y nombres del último `setLegal`: cada opción se pinta como tarjeta con su título y detalle.
	local lastContext: ActionMenuRules.Context? = nil

	-- Botones con acción, por id, con su texto original: el de una acción irreversible cambia a «¿Seguro?»
	-- hasta la segunda pulsación o hasta que vence el plazo.
	local buttonsById: { [string]: { button: Components.Button, label: string } } = {}
	local pendingConfirmId: string? = nil
	local pendingToken = 0

	local function clearPending()
		pendingToken += 1
		local id = pendingConfirmId
		pendingConfirmId = nil
		local entry = if id ~= nil then buttonsById[id] else nil
		if entry ~= nil then
			entry.button.setText(entry.label)
		end
	end

	-- Todo lo que sale del menú pasa por aquí, sea de un clic o de una tecla: la primera pulsación de una
	-- acción irreversible solo la arma; la segunda, dentro del plazo, la envía.
	local function emit(action: any)
		local target = callback
		if target == nil or action == nil then
			return
		end
		local id = ActionMenuRules.idFor(action)
		if ActionMenuRules.needsConfirm(action) and id ~= pendingConfirmId then
			clearPending()
			pendingConfirmId = id
			local token = pendingToken
			local entry = buttonsById[id]
			if entry ~= nil then
				entry.button.setText(Strings.get("action.confirm"))
			end
			task.delay(Ui.confirmSeconds, function()
				if pendingToken == token then
					clearPending()
				end
			end)
			return
		end
		clearPending()
		target(action)
	end

	local function remember(action: any, button: Components.Button, label: string)
		if action ~= nil then
			buttonsById[ActionMenuRules.idFor(action)] = { button = button, label = label }
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
	-- La lista de opciones se ajusta al tamaño del panel; el panel vive siempre, así que esta conexión
	-- se corta en cada reconstrucción o se acumularía una por cada panel con opciones.
	local fitConnection: RBXScriptConnection? = nil
	-- La bandeja de opciones plegada o abierta: se recuerda entre turnos.
	local optionsCollapsed = false

	local function clear()
		if fitConnection ~= nil then
			fitConnection:Disconnect()
			fitConnection = nil
		end
		for _, child in panel:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		bidCaption = nil
		primaryButton = nil
		primaryAction = nil
		declineAction = nil
		-- Los botones se destruyen: la confirmación pendiente se olvida con ellos.
		pendingToken += 1
		pendingConfirmId = nil
		buttonsById = {}
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

	-- La escritura se reduce en pantallas bajas: lo que va con ella tiene que caber siempre. En una
	-- subasta van además el título y la fila de puja; sin contarlos, el botón de pujar quedaba debajo
	-- del borde de la pantalla.
	local function deedScale(extra: number): number
		local camera = Workspace.CurrentCamera
		local height = if camera ~= nil then camera.ViewportSize.Y else Ui.referenceViewport.y
		local room = height - Ui.panelTop - Ui.roadHeight - Ui.panelActionsHeight - extra
		return math.clamp(room / Ui.deedHeight, Ui.deedMinScale, 1)
	end

	local function build(
		view: ActionMenuRules.Panel,
		extras: { { id: string, label: string, action: any, key: string? } }?
	)
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
			local extra = (if view.title ~= nil then Ui.panelTitleHeight else 0)
				+ (if view.bid ~= nil then Ui.bidControlsHeight else 0)
			local scale = deedScale(extra)
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
			remember(action, button, Strings.get("action.decline"))
			button.onActivated(function()
				emit(action)
			end)
		end

		if #view.options > 0 then
			-- Bandeja plegable: una cabecera con cuántas opciones hay y, debajo, las tarjetas una tras otra,
			-- sin scroll. Si no caben enteras, pasan a compactas (solo título; la descripción sale al pasar
			-- el ratón). La cabecera pliega y despliega la bandeja, y el estado se recuerda entre turnos.
			local tray = Instance.new("Frame")
			tray.Name = "Options"
			tray.BackgroundColor3 = Theme.color.asphaltDeep
			tray.BackgroundTransparency = 0.15
			tray.BorderSizePixel = 0
			tray.Size = UDim2.fromScale(1, 0)
			tray.AutomaticSize = Enum.AutomaticSize.Y
			tray.LayoutOrder = nextOrder()
			tray.Parent = panel
			local trayCorner = Instance.new("UICorner")
			trayCorner.CornerRadius = UDim.new(0, 12)
			trayCorner.Parent = tray
			local trayStroke = Instance.new("UIStroke")
			trayStroke.Color = Theme.color.limestone
			trayStroke.Transparency = 0.6
			trayStroke.Thickness = 1.5
			trayStroke.Parent = tray
			local trayLayout = Instance.new("UIListLayout")
			trayLayout.SortOrder = Enum.SortOrder.LayoutOrder
			trayLayout.Parent = tray

			local header = Instance.new("TextButton")
			header.Name = "Header"
			header.AutoButtonColor = false
			header.BackgroundTransparency = 1
			header.Text = ""
			header.Size = UDim2.new(1, 0, 0, 44)
			header.LayoutOrder = 1
			header.Parent = tray
			local headerText = Components.label(header, "Text", "", { face = Theme.font.roadBold, size = 14 })
			headerText.Position = UDim2.fromOffset(14, 0)
			headerText.Size = UDim2.new(1, -50, 1, 0)
			headerText.TextYAlignment = Enum.TextYAlignment.Center
			local mark = Board.chevron(header, Theme.color.limestone)
			mark.AnchorPoint = Vector2.new(1, 0.5)
			mark.Position = UDim2.new(1, -16, 0.5, 0)

			local list = Instance.new("Frame")
			list.Name = "List"
			list.BackgroundTransparency = 1
			list.Size = UDim2.fromScale(1, 0)
			list.AutomaticSize = Enum.AutomaticSize.Y
			list.LayoutOrder = 2
			list.Parent = tray
			local listLayout = Instance.new("UIListLayout")
			listLayout.Padding = UDim.new(0, Ui.decisionCard.gap)
			listLayout.SortOrder = Enum.SortOrder.LayoutOrder
			listLayout.Parent = list
			local listPad = Instance.new("UIPadding")
			-- Margen para que el sello de rareza, que asoma por la esquina, no se recorte.
			listPad.PaddingTop = UDim.new(0, 4)
			listPad.PaddingBottom = UDim.new(0, 12)
			listPad.PaddingLeft = UDim.new(0, 10)
			listPad.PaddingRight = UDim.new(0, 12)
			listPad.Parent = list

			local cards: { Board.DecisionCard } = {}
			local function paintHeader()
				local key = if optionsCollapsed then "option.trayShow" else "option.trayHide"
				headerText.Text = Strings.upper(Strings.get(key, { count = #view.options }))
				list.Visible = not optionsCollapsed
				mark.Rotation = if optionsCollapsed then 0 else 180
			end
			header.Activated:Connect(function()
				optionsCollapsed = not optionsCollapsed
				paintHeader()
			end)
			paintHeader()

			local context = lastContext
			for index, option in view.options do
				local action = option.action
				local data: ViewText.OptionCard = if action ~= nil
						and context ~= nil
						and context.view ~= nil
					then ViewText.optionCard(context.view, context.names, action)
					else { kind = "Other", title = option.label }
				local def = if data.cardId ~= nil then Cards.byId[data.cardId] else nil
				-- Una a cada lado, como naipes repartidos sobre la mesa.
				local tilt = if index % 2 == 0 then Ui.decisionCard.tilt else -Ui.decisionCard.tilt
				local card = Board.DecisionCard(
					list,
					`Option{index}`,
					data,
					tilt,
					if def ~= nil then def.rarity else nil
				)
				card.root.LayoutOrder = index
				table.insert(cards, card)
				card.playIn((index - 1) * Ui.decisionCard.dealStep)
				if action == nil then
					card.setEnabled(false)
				else
					remember(action, card, data.title)
					card.onActivated(function()
						emit(action)
					end)
				end
			end
			-- Compactas solo si enteras no caben en lo que queda de columna.
			local function fit()
				local used = 0
				for _, child in panel:GetChildren() do
					if child:IsA("GuiObject") and child ~= tray then
						used += child.AbsoluteSize.Y + Ui.panelGap
					end
				end
				local room = panel.AbsoluteSize.Y - used - 44
				local compact = false
				for _, card in cards do
					card.setCompact(false)
				end
				if listLayout.AbsoluteContentSize.Y + 16 > room then
					compact = true
				end
				for _, card in cards do
					card.setCompact(compact)
				end
			end
			fitConnection = panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
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
				local button = Components.SecondaryButton(row, `Extra_{extra.id}`, extra.label, extra.key)
				button.root.Size = UDim2.fromOffset(140, 44)
				remember(action, button, extra.label)
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
			extras: { { id: string, label: string, action: any, key: string? } }?,
			context: ActionMenuRules.Context?
		)
			lastContext = context
			local view = ActionMenuRules.panelFor(legal, context)
			local empty = view.primary == nil
				and #view.options == 0
				and (extras == nil or #(extras :: any) == 0)
			if empty then
				clearPending()
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

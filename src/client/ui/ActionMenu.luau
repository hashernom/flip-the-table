--!strict
-- Menú de acciones. Pinta los botones que decide `ActionMenuRules` a partir de las acciones legales
-- del servidor, más el control de puja cuando toca. No decide nada por su cuenta: si un botón está
-- aquí, es que su acción es legal.
local ActionMenuRules = require("./ActionMenuRules")
local Theme = require("./Theme")

export type Handles = {
	-- `extras` son botones que no vienen de `legalActions`: tratos y pactos se deciden en su propia
	-- ventana y el motor no los enumera, así que sin esto no habría forma de abrirlos.
	-- `context` lleva la vista y los nombres: con ellos los botones dicen sobre qué actúan y la puja
	-- conoce el efectivo del jugador.
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

	local panel = Theme.panel(gui, "Bar", nil)
	-- Abajo a la derecha: en el plano del turno la ficha y su casilla quedan abajo, hacia el centro, y un
	-- menú centrado las tapaba.
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -12, 1, -12)
	-- Ancho en fracción de la pantalla con tope: un panel de 420 px fijos se salía de un móvil estrecho.
	panel.Size = UDim2.fromScale(0.9, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Visible = false
	Theme.limitWidth(panel)

	-- Los botones van en una lista con scroll de alto máximo: con muchas cartas la barra ya no se sale
	-- de la pantalla, y la banda de puja queda siempre a la vista debajo.
	local listFrame = Theme.scrollList(panel, "List", 1)

	-- Banda de puja: solo aparece con una subasta en marcha. Los botones de paso van en una lista
	-- horizontal: sin anchos ni posiciones fijas, la banda cabe en el ancho que tenga el panel.
	local bidRow = Instance.new("Frame")
	bidRow.Name = "BidRow"
	bidRow.BackgroundTransparency = 1
	bidRow.Size = UDim2.new(1, 0, 0, math.max(Theme.MIN_TOUCH, 52))
	bidRow.LayoutOrder = 1000
	bidRow.Visible = false
	bidRow.Parent = panel

	local bidLayout = Instance.new("UIListLayout")
	bidLayout.FillDirection = Enum.FillDirection.Horizontal
	bidLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	bidLayout.Padding = UDim.new(0, 6)
	bidLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bidLayout.Parent = bidRow

	local function bidStepButton(order: number): TextButton
		local button = Theme.button(bidRow, "", order, function() end)
		button.Size = UDim2.fromOffset(math.max(Theme.MIN_TOUCH, 50), math.max(Theme.MIN_TOUCH, 48))
		button.TextSize = 16
		return button
	end
	local bigMinus = bidStepButton(1)
	local minus = bidStepButton(2)
	local plus = bidStepButton(3)
	local bigPlus = bidStepButton(4)

	local bidValue = Instance.new("TextLabel")
	bidValue.Name = "BidValue"
	bidValue.LayoutOrder = 5
	bidValue.Size = UDim2.new(1, -4 * (math.max(Theme.MIN_TOUCH, 50) + 6), 1, 0)
	bidValue.BackgroundTransparency = 1
	bidValue.FontFace = Theme.font.road
	bidValue.TextSize = 18
	bidValue.TextWrapped = true
	bidValue.TextXAlignment = Enum.TextXAlignment.Left
	bidValue.TextColor3 = Theme.accent
	bidValue.Text = ""
	bidValue.Parent = bidRow

	local buttons: { TextButton } = {}

	local callback: ((action: any) -> ())? = nil
	local bounds: ActionMenuRules.BidControl? = nil
	-- Puja elegida. Sobrevive a las vistas nuevas (acotada al rango de cada una) y se olvida al acabar
	-- la subasta: cada vista que llega no puede devolver el control al mínimo.
	local bid: number? = nil
	-- Botón de confirmar puja: no envía la acción enumerada por el motor, sino el importe elegido.
	local bidConfirm: TextButton? = nil

	local function emit(action: any)
		local target = callback
		if target then
			target(action)
		end
	end

	local function refreshBid()
		local range = bounds
		if range == nil then
			bidRow.Visible = false
			return
		end
		local current = ActionMenuRules.clampBid(bid, range)
		bid = current
		bidRow.Visible = true
		bigMinus.Text = `−{range.jump}`
		minus.Text = `−{range.step}`
		plus.Text = `+{range.step}`
		bigPlus.Text = `+{range.jump}`
		bidValue.Text = `{current}  (de {range.min} a {range.max})`
		local confirm = bidConfirm
		if confirm ~= nil then
			confirm.Text = `Pujar {current}`
		end
	end

	local function nudge(delta: number)
		local range = bounds
		if range == nil then
			return
		end
		bid = ActionMenuRules.clampBid(ActionMenuRules.clampBid(bid, range) + delta, range)
		refreshBid()
	end
	bigMinus.MouseButton1Click:Connect(function()
		nudge(-(bounds and bounds.jump or 0))
	end)
	minus.MouseButton1Click:Connect(function()
		nudge(-(bounds and bounds.step or 0))
	end)
	plus.MouseButton1Click:Connect(function()
		nudge(bounds and bounds.step or 0)
	end)
	bigPlus.MouseButton1Click:Connect(function()
		nudge(bounds and bounds.jump or 0)
	end)

	local function clear()
		for _, button in buttons do
			button:Destroy()
		end
		buttons = {}
		bidConfirm = nil
	end

	local handles: Handles = {
		setLegal = function(
			legal: { any },
			extras: { { id: string, label: string, action: any } }?,
			context: ActionMenuRules.Context?
		)
			clear()
			local cash = ActionMenuRules.ownCash(context)
			bounds = ActionMenuRules.bidControl(legal, cash)
			if bounds == nil then
				bid = nil
			end
			refreshBid()

			local list = ActionMenuRules.buttonsFor(legal, context)
			panel.Visible = #list > 0 or (extras ~= nil and #(extras :: any) > 0)
			for index, item in list do
				if item.id == "BidConfirm" then
					local button = Theme.button(listFrame, item.label, index, function()
						local range = bounds
						if range ~= nil then
							emit({ type = "Bid", amount = ActionMenuRules.clampBid(bid, range) })
						end
					end)
					button.Name = `Action_{index}_{item.id}`
					bidConfirm = button
					table.insert(buttons, button)
				else
					local action = item.action
					local button = Theme.button(listFrame, item.label, index, function()
						if action ~= nil then
							emit(action)
						end
					end)
					button.Name = `Action_{index}_{item.id}`
					table.insert(buttons, button)
				end
			end
			refreshBid()

			if extras ~= nil then
				for index, extra in extras do
					local action = extra.action
					local button = Theme.button(listFrame, extra.label, 500 + index, function()
						emit(action)
					end)
					button.Name = `Action_Extra_{extra.id}`
					table.insert(buttons, button)
				end
			end
		end,
		onAction = function(target: (action: any) -> ())
			callback = target
		end,
		destroy = function()
			gui:Destroy()
		end,
	}

	return handles
end

return ActionMenu

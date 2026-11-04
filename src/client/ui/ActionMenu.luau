--!strict
-- Menú de acciones. Pinta los botones que decide `ActionMenuRules` a partir de las acciones legales
-- del servidor, más el control de puja cuando toca. No decide nada por su cuenta: si un botón está
-- aquí, es que su acción es legal.
local ActionMenuRules = require("./ActionMenuRules")
local Theme = require("./Theme")

export type Handles = {
	setLegal: (legal: { any }) -> (),
	-- Acción elegida por el jugador. El cliente la manda al servidor tal cual.
	onAction: (callback: (action: any) -> ()) -> (),
	destroy: () -> (),
}

local ActionMenu = {}

function ActionMenu.create(playerGui: Instance): Handles
	local gui = Theme.screenGui(playerGui, "ActionMenu", 6)

	local panel = Theme.panel(gui, "Bar", nil)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -12)
	panel.Size = UDim2.fromOffset(420, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Visible = false

	-- Banda de puja: solo aparece con una subasta en marcha.
	local bidRow = Instance.new("Frame")
	bidRow.Name = "BidRow"
	bidRow.BackgroundTransparency = 1
	bidRow.Size = UDim2.new(1, 0, 0, math.max(Theme.MIN_TOUCH, 52))
	bidRow.LayoutOrder = 1000
	bidRow.Visible = false
	bidRow.Parent = panel

	local minus = Theme.button(bidRow, "−", 1, function() end)
	minus.AnchorPoint = Vector2.new(0, 0)
	minus.Position = UDim2.fromOffset(0, 2)
	minus.Size = UDim2.new(0, math.max(Theme.MIN_TOUCH, 50), 1, -4)

	local plus = Theme.button(bidRow, "+", 2, function() end)
	plus.AnchorPoint = Vector2.new(0, 0)
	plus.Position = UDim2.fromOffset(58, 2)
	plus.Size = UDim2.new(0, math.max(Theme.MIN_TOUCH, 50), 1, -4)

	local bidValue = Instance.new("TextLabel")
	bidValue.Name = "BidValue"
	bidValue.Position = UDim2.fromOffset(120, 0)
	bidValue.Size = UDim2.new(0, 100, 1, 0)
	bidValue.BackgroundTransparency = 1
	bidValue.Font = Theme.fontBold
	bidValue.TextSize = 20
	bidValue.TextXAlignment = Enum.TextXAlignment.Left
	bidValue.TextColor3 = Theme.accent
	bidValue.Text = ""
	bidValue.Parent = bidRow

	local bidCaption = Instance.new("TextLabel")
	bidCaption.Name = "BidCaption"
	bidCaption.AnchorPoint = Vector2.new(1, 0)
	bidCaption.Position = UDim2.fromScale(1, 0)
	bidCaption.Size = UDim2.new(0, 170, 1, 0)
	bidCaption.BackgroundTransparency = 1
	bidCaption.Font = Theme.font
	bidCaption.TextSize = 14
	bidCaption.TextXAlignment = Enum.TextXAlignment.Right
	bidCaption.TextColor3 = Theme.muted
	bidCaption.Text = ""
	bidCaption.Parent = bidRow

	local buttons: { TextButton } = {}

	local callback: ((action: any) -> ())? = nil
	local bounds: ActionMenuRules.BidControl? = nil
	local bid = 0
	-- Botón de confirmar puja: no envía la acción enumerada por el motor, sino el importe elegido.
	local bidConfirm: TextButton? = nil

	local function emit(action: any)
		local target = callback
		if target then
			target(action)
		end
	end

	local function refreshBid()
		if bounds == nil then
			bidRow.Visible = false
			return
		end
		bidRow.Visible = true
		bidValue.Text = `{bid}`
		bidCaption.Text = `puja entre {bounds.min} y {bounds.max}`
		local confirm = bidConfirm
		if confirm ~= nil then
			confirm.Text = `Pujar {bid}`
		end
	end

	minus.MouseButton1Click:Connect(function()
		if bounds == nil then
			return
		end
		bid = math.max(bounds.min, bid - bounds.step)
		refreshBid()
	end)

	plus.MouseButton1Click:Connect(function()
		if bounds == nil then
			return
		end
		bid = math.min(bounds.max, bid + bounds.step)
		refreshBid()
	end)

	local function clear()
		for _, button in buttons do
			button:Destroy()
		end
		buttons = {}
		bidConfirm = nil
	end

	local handles: Handles = {
		setLegal = function(legal: { any })
			clear()
			bounds = ActionMenuRules.bidControl(legal)
			if bounds ~= nil then
				bid = bounds.min
			end
			refreshBid()

			local list = ActionMenuRules.buttonsFor(legal)
			panel.Visible = #list > 0
			for index, item in list do
				if item.id == "BidConfirm" then
					local button = Theme.button(panel, item.label, index, function()
						emit({ type = "Bid", amount = bid })
					end)
					button.Name = `Action_{index}_{item.id}`
					bidConfirm = button
					table.insert(buttons, button)
				else
					local action = item.action
					local button = Theme.button(panel, item.label, index, function()
						emit(action)
					end)
					button.Name = `Action_{index}_{item.id}`
					table.insert(buttons, button)
				end
			end
			refreshBid()
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

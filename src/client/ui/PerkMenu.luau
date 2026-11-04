--!strict
-- Menú de elección de perk. El servidor ofrece tres y el jugador elige uno; llega en tres momentos de
-- la partida. Mientras está abierto, la partida espera: es una decisión, no una escena.
local Theme = require("./Theme")

export type Handles = {
	setView: (view: any) -> (),
	destroy: () -> (),
}

local PerkMenu = {}

function PerkMenu.create(playerGui: Instance, send: (action: any) -> ()): Handles
	local modal = Theme.modal(playerGui, "PerkMenu", "Elige un perk", 9)
	local body = modal.body
	body.Size = UDim2.fromScale(1, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y

	local function rebuild(view: any)
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") and child.Name ~= "Title" then
				child:Destroy()
			end
		end
		local pending = view.pending
		local offers = if pending ~= nil and pending.perkOffers ~= nil then pending.perkOffers else {}
		if #offers == 0 then
			local label = Instance.new("TextLabel")
			label.Name = "Waiting"
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 0)
			label.AutomaticSize = Enum.AutomaticSize.Y
			label.Font = Theme.font
			label.TextSize = 16
			label.TextWrapped = true
			label.TextColor3 = Theme.muted
			label.Text = "Sin perks que elegir ahora mismo."
			label.LayoutOrder = 1
			label.Parent = body
			return
		end
		for order, perkId in offers do
			Theme.button(body, tostring(perkId), order, function()
				send({ type = "DraftPerk", perkId = perkId })
				modal.setOpen(false)
			end)
		end
	end

	return {
		setView = function(view: any)
			if view == nil then
				return
			end
			rebuild(view)
			-- El draft se abre solo y se cierra solo: en cuanto la fase deja de ser la suya, la partida
			-- ya eligió y la ventana no puede quedarse tapando la mesa.
			modal.setOpen(view.phase == "PerkDraft")
		end,
		destroy = function()
			modal.gui:Destroy()
		end,
	}
end

return PerkMenu

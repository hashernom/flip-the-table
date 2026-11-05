--!strict
-- Menú para elegir ficha antes de que la partida eche a andar. Enseña las ocho, marca la propia y
-- las ocupadas, y se cierra con «Listo». La elección la arbitra el servidor: aquí solo se pinta.
local Theme = require("./Theme")
local Tokens = require("../../shared/config/Tokens")

export type Handles = {
	setVisible: (visible: boolean) -> (),
	setAssignments: (assignments: { [string]: string }, playerId: string) -> (),
	setNotice: (text: string) -> (),
	destroy: () -> (),
}

local TokenMenu = {}

function TokenMenu.create(playerGui: Instance, onChoose: (tokenId: string) -> ()): Handles
	local modal = Theme.modal(playerGui, "TokenMenu", "Elige tu ficha", 11)

	local notice = Instance.new("TextLabel")
	notice.Name = "Notice"
	notice.BackgroundTransparency = 1
	notice.Size = UDim2.fromScale(1, 0)
	notice.AutomaticSize = Enum.AutomaticSize.Y
	notice.FontFace = Theme.font.text
	notice.TextSize = 15
	notice.TextWrapped = true
	notice.TextColor3 = Theme.muted
	notice.Text = "Puedes cambiarla hasta que alguien salga de la Salida."
	notice.LayoutOrder = 0
	notice.Parent = modal.body

	local buttons: { [string]: TextButton } = {}

	local function choose(tokenId: string)
		onChoose(tokenId)
	end

	for order, token in Tokens.all() do
		buttons[token.id] = Theme.button(modal.body, token.label, order + 10, function()
			choose(token.id)
		end)
	end

	Theme.button(modal.body, "Listo", 30, function()
		modal.setOpen(false)
	end)

	return {
		setVisible = function(visible: boolean)
			modal.setOpen(visible)
		end,
		setAssignments = function(assignments: { [string]: string }, playerId: string)
			for tokenId, button in buttons do
				local owner: string? = nil
				for otherId, chosen in assignments do
					if chosen == tokenId then
						owner = otherId
						break
					end
				end
				local mine = owner == playerId
				local taken = owner ~= nil and not mine
				local label = Tokens.get(tokenId)
				local text = if label ~= nil then label.label else tokenId
				if mine then
					text ..= " · tuya"
				elseif taken then
					-- Elegirla intercambia con su dueño: el botón sigue vivo.
					text ..= " · de otro"
				end
				button.Text = text
				button.BackgroundColor3 = if mine then Theme.accent else Theme.buttonColor
				button.TextColor3 = if mine then Theme.background elseif taken then Theme.muted else Theme.text
				button.TextTransparency = 0
			end
		end,
		setNotice = function(text: string)
			notice.Text = text
		end,
		destroy = function()
			modal.gui:Destroy()
		end,
	}
end

return TokenMenu

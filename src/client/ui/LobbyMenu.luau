--!strict
-- Menú del lobby: crear una party y enseñar su código, unirse con un código y entrar a la cola
-- pública. Es la única pantalla que el jugador ve antes de que exista una partida, así que también
-- enseña los avisos del servidor.
local Theme = require("./Theme")

export type Handles = {
	setNotice: (text: string) -> (),
	setVisible: (visible: boolean) -> (),
	destroy: () -> (),
}

local LobbyMenu = {}

function LobbyMenu.create(playerGui: Instance, send: (request: any) -> ()): Handles
	local modal = Theme.modal(playerGui, "LobbyMenu", "Flip the Table", 9)
	local body = modal.body
	body.Size = UDim2.fromScale(1, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	modal.setOpen(true)

	local notice = Instance.new("TextLabel")
	notice.Name = "Notice"
	notice.BackgroundTransparency = 1
	notice.Size = UDim2.fromScale(1, 0)
	notice.AutomaticSize = Enum.AutomaticSize.Y
	notice.Font = Theme.font
	notice.TextSize = 15
	notice.TextWrapped = true
	notice.TextColor3 = Theme.muted
	notice.Text = "Crea una party o escribe un código para unirte."
	notice.LayoutOrder = 0
	notice.Parent = body

	local codeBox = Instance.new("TextBox")
	codeBox.Name = "Code"
	codeBox.BackgroundColor3 = Theme.background
	codeBox.BorderSizePixel = 0
	codeBox.Size = UDim2.fromScale(1, 0)
	codeBox.AutomaticSize = Enum.AutomaticSize.Y
	codeBox.Font = Theme.fontBold
	codeBox.TextSize = 22
	codeBox.TextColor3 = Theme.text
	codeBox.PlaceholderText = "Código de party"
	codeBox.Text = ""
	codeBox.ClearTextOnFocus = false
	codeBox.LayoutOrder = 1
	codeBox.Parent = body
	Theme.corner(codeBox, 8)

	-- El alto del cuadro de texto se fija a mano: `AutomaticSize` no crece con el texto.
	codeBox.Size = UDim2.fromOffset(0, math.max(Theme.MIN_TOUCH, 52))

	local function button(text: string, order: number, onClick: () -> ())
		Theme.button(body, text, order, onClick)
	end

	button("Crear party", 10, function()
		send({ type = "PartyCreate" })
	end)

	button("Unirme al código", 11, function()
		send({ type = "PartyJoin", code = codeBox.Text })
	end)

	button("Empezar partida", 12, function()
		send({ type = "PartyStart", endMode = "Rounds" })
	end)

	button("Partida pública", 13, function()
		send({ type = "QueueJoin" })
	end)

	return {
		setNotice = function(text: string)
			notice.Text = text
		end,
		setVisible = function(visible: boolean)
			modal.setOpen(visible)
		end,
		destroy = function()
			modal.gui:Destroy()
		end,
	}
end

return LobbyMenu

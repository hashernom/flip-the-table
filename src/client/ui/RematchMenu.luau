--!strict
-- Revancha: al acabar la partida, un botón y ya está. No es un modal: si el fondo cerrara la ventana,
-- el jugador se quedaría sin forma de votar durante los segundos que el servidor tiene abierta la
-- votación. Quien vota espera aquí y los avisos del servidor explican qué pasa después.
local Theme = require("./Theme")

export type Handles = {
	setView: (view: any) -> (),
	-- Mensaje del servidor. Es la última palabra de la votación: ya no hay nada que pulsar.
	setNotice: (text: string) -> (),
	onVote: (callback: (accept: boolean) -> ()) -> (),
	destroy: () -> (),
}

local RematchMenu = {}

function RematchMenu.create(playerGui: Instance): Handles
	local gui = Theme.screenGui(playerGui, "RematchMenu", 7)

	local panel = Theme.panel(gui, "Sheet", "¿Revancha?")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Visible = false

	Theme.limitWidth(panel)

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Size = UDim2.fromScale(1, 0)
	status.AutomaticSize = Enum.AutomaticSize.Y
	status.Font = Theme.font
	status.TextSize = 16
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = Theme.muted
	status.Text = ""
	status.LayoutOrder = 1
	status.Parent = panel

	local callback: ((accept: boolean) -> ())? = nil
	local accept: TextButton
	local decline: TextButton

	local function setButtons(visible: boolean)
		accept.Visible = visible
		decline.Visible = visible
	end

	local function vote(value: boolean, message: string)
		setButtons(false)
		status.Text = message
		local target = callback
		if target then
			target(value)
		end
	end

	accept = Theme.button(panel, "Revancha", 2, function()
		vote(true, "Esperando al resto del grupo…")
	end)
	decline = Theme.button(panel, "No, gracias", 3, function()
		vote(false, "Has dicho que no. Esperando al resto del grupo…")
	end)

	local open = false

	return {
		setView = function(view: any)
			if view == nil then
				return
			end
			local over = view.phase == "GameOver"
			-- Cada final abre la votación una sola vez; la partida nueva la deja lista para el siguiente.
			if over and not open then
				status.Text = "El grupo decide si juega otra."
				setButtons(true)
			end
			open = over
			panel.Visible = over
		end,
		setNotice = function(text: string)
			status.Text = text
			setButtons(false)
			-- También llega a quien no tiene partida (entró tarde, o no llegó el grupo): sin esto, el
			-- aviso se escribiría en un panel que nadie ve.
			panel.Visible = true
		end,
		onVote = function(target: (accept: boolean) -> ())
			callback = target
		end,
		destroy = function()
			gui:Destroy()
		end,
	}
end

return RematchMenu

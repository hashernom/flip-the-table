--!strict
-- Barra de estado del cliente: ronda, fase, temporizador de la decisión, dinero de cada asiento y los
-- dos botones que no son una acción del motor: la vista general y los emotes. Es arte gris: texto y
-- rectángulos, nada más.
--
-- El temporizador se calcula con el reloj del servidor (`remainingSeconds`), así que dos clientes
-- enseñan la misma cuenta atrás aunque uno vaya un poco por detrás.
local ActionMenuRules = require("./ActionMenuRules")
local Theme = require("./Theme")

export type Handles = {
	gui: ScreenGui,
	-- Fija la vista: ronda, fase, dinero y posiciones de todos.
	setView: (view: any) -> (),
	-- Plazo de la decisión en tiempo del servidor; nil esconde la cuenta atrás.
	setDeadline: (deadline: number?) -> (),
	-- Rótulo de la escena en curso. Vacío lo esconde.
	setBanner: (text: string) -> (),
	onOverview: (callback: () -> ()) -> (),
	onEmote: (callback: (emote: string) -> ()) -> (),
	destroy: (() -> ())?,
}

local EMOTES = { "😀", "😱", "🤑", "😡", "🤝", "🗡️" }
local PHASES: { [string]: string } = {
	PerkDraft = "Elegir perk",
	AwaitRoll = "Tirar dados",
	AwaitBuy = "Comprar",
	Auction = "Subasta",
	Reaction = "Reacción",
	Tribunal = "Tribunal",
	Duel = "Duelo",
	Market = "Mercado Negro",
	AwaitEnd = "Fin del turno",
	GhostTurn = "Turno de espectro",
	GameOver = "Fin de la partida",
}

local Hud = {}

function Hud.create(playerGui: Instance, serverNow: () -> number): Handles
	local gui = Theme.screenGui(playerGui, "Hud", 5)

	-- Fila superior: ronda, fase, cuenta atrás y los dos botones fijos.
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.BackgroundColor3 = Theme.background
	top.BackgroundTransparency = 0.1
	top.BorderSizePixel = 0
	top.Position = UDim2.fromOffset(0, 0)
	top.Size = UDim2.new(1, 0, 0, 64)
	top.Parent = gui
	Theme.corner(top, 0)

	-- Los textos van en una lista horizontal que ocupa lo que deja libre la botonera: en una pantalla
	-- estrecha se aprietan en vez de solaparse o salirse por el borde.
	local labels = Instance.new("Frame")
	labels.Name = "Labels"
	labels.BackgroundTransparency = 1
	labels.Position = UDim2.fromOffset(12, 8)
	labels.Size = UDim2.new(1, -260, 1, -16)
	labels.Parent = top

	local labelLayout = Instance.new("UIListLayout")
	labelLayout.FillDirection = Enum.FillDirection.Horizontal
	labelLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	labelLayout.Padding = UDim.new(0, 18)
	labelLayout.Parent = labels

	local function topLabel(name: string): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromOffset(0, 32)
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Font = Theme.fontBold
		label.TextSize = 20
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Theme.text
		label.Text = ""
		label.Parent = labels
		return label
	end

	local roundLabel = topLabel("Round")
	roundLabel.LayoutOrder = 1
	local phaseLabel = topLabel("Phase")
	phaseLabel.LayoutOrder = 2
	local timerLabel = topLabel("Timer")
	timerLabel.LayoutOrder = 3
	timerLabel.TextColor3 = Theme.accent

	local overviewButton = Instance.new("TextButton")
	overviewButton.Name = "OverviewButton"
	overviewButton.AnchorPoint = Vector2.new(1, 0)
	overviewButton.Position = UDim2.new(1, -12, 0, 6)
	overviewButton.Size = UDim2.fromOffset(150, math.max(Theme.MIN_TOUCH, 52))
	overviewButton.BackgroundColor3 = Theme.buttonColor
	overviewButton.BorderSizePixel = 0
	overviewButton.Font = Theme.fontBold
	overviewButton.TextSize = 16
	overviewButton.TextColor3 = Theme.text
	overviewButton.Text = "Vista general"
	overviewButton.Parent = top
	Theme.corner(overviewButton, 8)

	local emoteButton = Instance.new("TextButton")
	emoteButton.Name = "EmoteButton"
	emoteButton.AnchorPoint = Vector2.new(1, 0)
	emoteButton.Position = UDim2.new(1, -170, 0, 6)
	emoteButton.Size = UDim2.fromOffset(60, math.max(Theme.MIN_TOUCH, 52))
	emoteButton.BackgroundColor3 = Theme.buttonColor
	emoteButton.BorderSizePixel = 0
	emoteButton.Font = Theme.fontBold
	emoteButton.TextSize = 22
	emoteButton.TextColor3 = Theme.text
	emoteButton.Text = "🙂"
	emoteButton.Parent = top
	Theme.corner(emoteButton, 8)

	-- Lista de asientos: dinero y casilla de cada uno, siempre a la vista.
	local seats = Instance.new("Frame")
	seats.Name = "Seats"
	seats.AnchorPoint = Vector2.new(0, 0)
	seats.Position = UDim2.fromOffset(12, 72)
	seats.Size = UDim2.fromOffset(250, 10)
	seats.AutomaticSize = Enum.AutomaticSize.Y
	seats.BackgroundColor3 = Theme.panelColor
	seats.BackgroundTransparency = 0.1
	seats.BorderSizePixel = 0
	seats.Parent = gui
	Theme.corner(seats)
	Theme.padding(seats, 8)

	local seatLayout = Instance.new("UIListLayout")
	seatLayout.FillDirection = Enum.FillDirection.Vertical
	seatLayout.Padding = UDim.new(0, 4)
	seatLayout.SortOrder = Enum.SortOrder.LayoutOrder
	seatLayout.Parent = seats

	-- Rótulo de escena: lo que está pasando ahora mismo, para todo el grupo.
	local banner = Instance.new("TextLabel")
	banner.Name = "SceneBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 80)
	banner.Size = UDim2.fromOffset(420, 54)
	banner.BackgroundColor3 = Theme.background
	banner.BackgroundTransparency = 0.15
	banner.BorderSizePixel = 0
	banner.Font = Theme.fontBold
	banner.TextScaled = true
	banner.TextColor3 = Theme.text
	banner.Text = ""
	banner.Visible = false
	banner.Parent = gui
	Theme.corner(banner)

	-- Emotes: una fila corta que se abre y se cierra con el botón de la barra.
	local emoteBar = Instance.new("Frame")
	emoteBar.Name = "Emotes"
	emoteBar.AnchorPoint = Vector2.new(1, 0)
	emoteBar.Position = UDim2.new(1, -12, 0, 66)
	emoteBar.Size = UDim2.fromOffset(300, math.max(Theme.MIN_TOUCH, 48))
	emoteBar.BackgroundTransparency = 1
	emoteBar.Visible = false
	emoteBar.Parent = gui

	local emoteLayout = Instance.new("UIListLayout")
	emoteLayout.FillDirection = Enum.FillDirection.Horizontal
	emoteLayout.Padding = UDim.new(0, 6)
	emoteLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	emoteLayout.Parent = emoteBar

	-- Plazo de la decisión vigente. La cuenta atrás lo lee cada 0,2 s; el resto de la barra cambia con
	-- cada lote.
	local deadline: number? = nil

	local handles: Handles = {
		gui = gui,
		setView = function(view: any)
			if view == nil then
				return
			end
			local total = if view.maxRounds and view.maxRounds > 0 then `/{view.maxRounds}` else ""
			roundLabel.Text = `Ronda {view.round}{total}`
			local phase = PHASES[view.phase] or view.phase
			phaseLabel.Text = phase

			for _, child in seats:GetChildren() do
				if child:IsA("TextLabel") then
					child:Destroy()
				end
			end
			for index, seated in view.players do
				local label = Instance.new("TextLabel")
				label.Name = `Seat_{index}`
				label.BackgroundTransparency = 1
				label.Size = UDim2.new(1, 0, 0, 20)
				label.LayoutOrder = index
				label.Font = Theme.font
				label.TextSize = 15
				label.TextXAlignment = Enum.TextXAlignment.Left
				label.TextColor3 = if seated.status == "Active" then Theme.text else Theme.muted
				local turn = if index == view.turnIndex then "▶ " else ""
				label.Text = `{turn}{seated.id}  {seated.cash}  ·  casa {seated.position}`
				label.Parent = seats
			end
		end,
		setDeadline = function(value: number?)
			deadline = value
			local remaining = ActionMenuRules.remainingSeconds(value, serverNow())
			timerLabel.Text = if remaining ~= nil then `{math.ceil(remaining)} s` else ""
		end,
		setBanner = function(text: string)
			banner.Text = text
			banner.Visible = text ~= ""
		end,
		onOverview = function(callback: () -> ())
			overviewButton.MouseButton1Click:Connect(callback)
		end,
		onEmote = function(callback: (emote: string) -> ())
			emoteButton.MouseButton1Click:Connect(function()
				emoteBar.Visible = not emoteBar.Visible
			end)
			for index, emote in EMOTES do
				Theme.button(emoteBar, emote, index, function()
					emoteBar.Visible = false
					callback(emote)
				end).Size =
					UDim2.fromOffset(math.max(Theme.MIN_TOUCH, 46), math.max(Theme.MIN_TOUCH, 46))
			end
		end,
	}

	-- La cuenta atrás se refresca sola: los segundos que quedan no llegan por lote.
	task.spawn(function()
		while gui.Parent do
			if deadline ~= nil then
				local remaining = ActionMenuRules.remainingSeconds(deadline, serverNow())
				timerLabel.Text = if remaining ~= nil then `{math.ceil(remaining)} s` else ""
			end
			task.wait(0.2)
		end
	end)

	return handles
end

return Hud

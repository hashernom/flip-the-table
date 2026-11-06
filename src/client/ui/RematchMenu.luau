--!strict
-- Revancha sobre el tablón de obra: el podio a la izquierda y la votación a la derecha. No se cierra
-- tocando fuera: si el velo la cerrara, el jugador se quedaría sin forma de votar durante los segundos
-- que el servidor tiene abierta la votación. Quien vota espera aquí y los avisos del servidor explican
-- qué pasa después.
local Board = require("./Board")
local Components = require("./Components")
local HudRules = require("./HudRules")
local Lobby = require("../../shared/config/Lobby")
local Scenes = require("../../shared/config/Scenes")
local Strings = require("../../shared/config/Strings")
local Theme = require("./Theme")
local Ui = require("../../shared/config/Ui")
local ViewText = require("./ViewText")

export type Handles = {
	setView: (view: any) -> (),
	-- Podio de la partida que acaba. Sin podio se vacía, y la revancha lo vacía al empezar la siguiente.
	setResult: (podium: ViewText.Podium?) -> (),
	-- Mensaje del servidor. Es la última palabra de la votación: ya no hay nada que pulsar.
	setNotice: (text: string) -> (),
	onVote: (callback: (accept: boolean) -> ()) -> (),
	destroy: () -> (),
}

local RematchMenu = {}

function RematchMenu.create(playerGui: Instance): Handles
	local window = Board.Window(playerGui, "RematchMenu", 7, false)

	Board.Header(window.stack, 1, {
		title = Strings.get("rematch.title"),
		help = Strings.get("rematch.help"),
		steps = {
			Strings.get("rematch.step1"),
			Strings.get("rematch.step2", { seconds = Scenes.rematchSec }),
			Strings.get("rematch.step3", { min = Lobby.minPlayers }),
		},
	})

	local row = Instance.new("Frame")
	row.Name = "Middle"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 0)
	row.LayoutOrder = 2
	row.Parent = window.stack
	Board.fill(row)
	Board.list(row, Enum.FillDirection.Horizontal, Theme.space.l)

	-- Podio: con ocho jugadores y los premios hace scroll.
	local podiumPoster = Board.Poster(row, "Podium", 1, false)
	podiumPoster.root.Size = UDim2.new(0.58, -Theme.space.l // 2, 1, 0)
	local results = Instance.new("ScrollingFrame")
	results.Name = "Results"
	results.BackgroundTransparency = 1
	results.BorderSizePixel = 0
	results.Size = UDim2.fromScale(1, 0)
	results.CanvasSize = UDim2.fromScale(0, 0)
	results.AutomaticCanvasSize = Enum.AutomaticSize.Y
	results.ScrollingDirection = Enum.ScrollingDirection.Y
	results.ScrollBarThickness = 6
	results.ScrollBarImageColor3 = Theme.color.asphalt
	results.LayoutOrder = 1
	results.Parent = podiumPoster.content
	Board.fill(results)
	Board.list(results, Enum.FillDirection.Vertical, Theme.space.s)

	-- Votación.
	local votePoster = Board.Poster(row, "Vote", 2, false)
	votePoster.root.Size = UDim2.new(0.42, -Theme.space.l // 2, 1, 0)
	Board.caption(votePoster.content, "Caption", Strings.get("rematch.vote"), 1)
	local status = Board.text(votePoster.content, "Status", Strings.get("rematch.open"), 2, 20)
	local spacer = Instance.new("Frame")
	spacer.Name = "Spacer"
	spacer.BackgroundTransparency = 1
	spacer.Size = UDim2.fromScale(1, 0)
	spacer.LayoutOrder = 3
	spacer.Parent = votePoster.content
	Board.fill(spacer)
	local accept = Components.PrimaryButton(votePoster.content, "Accept", Strings.get("rematch.yes"))
	accept.root.Size = UDim2.new(1, 0, 0, 72)
	accept.root.LayoutOrder = 4
	local decline = Components.SecondaryButton(votePoster.content, "Decline", Strings.get("rematch.no"))
	decline.root.Size = UDim2.new(1, 0, 0, 44)
	decline.root.LayoutOrder = 5

	local callback: ((accept: boolean) -> ())? = nil
	local open = false

	local function setButtons(visible: boolean)
		accept.root.Visible = visible
		decline.root.Visible = visible
	end

	local function vote(value: boolean, messageKey: string)
		setButtons(false)
		status.Text = Strings.get(messageKey)
		local target = callback
		if target then
			target(value)
		end
	end

	accept.onActivated(function()
		vote(true, "rematch.waiting")
	end)
	decline.onActivated(function()
		vote(false, "rematch.declined")
	end)

	local function clearResults()
		for _, child in results:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	-- Fila de un puesto: número en disco, nombre y patrimonio. El primero va invertido y más grande.
	local function rankRow(order: number, entry: any)
		local first = entry.position == 1
		local line = Instance.new("Frame")
		line.Name = `Rank{entry.position}`
		line.BackgroundColor3 = Theme.color.asphalt
		line.BackgroundTransparency = if first then 0 else 1
		line.BorderSizePixel = 0
		line.Size = UDim2.new(1, -10, 0, if first then 56 else 40)
		line.LayoutOrder = order
		line.Parent = results
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, Ui.radius.small)
		corner.Parent = line
		local ink = if first then Theme.color.limestone else Theme.color.asphalt
		local number = Components.label(line, "Position", tostring(entry.position), {
			face = Theme.font.roadBold,
			size = if first then 30 else 22,
			tint = ink,
			align = Enum.TextXAlignment.Center,
		})
		number.Size = UDim2.new(0, 44, 1, 0)
		local name = Components.label(line, "Name", Strings.upper(entry.name), {
			face = Theme.font.roadBold,
			size = if first then 24 else 18,
			tint = ink,
		})
		name.Position = UDim2.fromOffset(52, 0)
		name.Size = UDim2.new(1, -230, 1, 0)
		name.TextYAlignment = Enum.TextYAlignment.Center
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local worth = Components.label(
			line,
			"Worth",
			Strings.get("rematch.worth", { amount = HudRules.formatMoney(entry.worth) }),
			{ face = Theme.font.text, size = 15, tint = ink, align = Enum.TextXAlignment.Right }
		)
		worth.AnchorPoint = Vector2.new(1, 0)
		worth.Position = UDim2.new(1, -12, 0, 0)
		worth.Size = UDim2.new(0, 170, 1, 0)
		worth.TextYAlignment = Enum.TextYAlignment.Center
		if first then
			local stamp = Components.Stamp(line, Strings.get("rematch.winnerStamp"), "Loss", 12)
			stamp.AnchorPoint = Vector2.new(0, 0.5)
			stamp.Position = UDim2.fromOffset(-8, 2)
		end
	end

	return {
		setView = function(view: any)
			if view == nil then
				return
			end
			local over = view.phase == "GameOver"
			-- Cada final abre la votación una sola vez; la partida nueva la deja lista para el siguiente.
			if over and not open then
				status.Text = Strings.get("rematch.open")
				setButtons(true)
			end
			open = over
			window.setOpen(over)
		end,
		setResult = function(podium: ViewText.Podium?)
			clearResults()
			if podium == nil then
				return
			end
			local order = 0
			Board.caption(results, "RankCaption", Strings.get("rematch.podium"), order)
			for _, entry in podium.ranking do
				order += 1
				rankRow(order, entry)
			end
			if #podium.awards > 0 then
				order += 1
				Board.caption(results, "AwardsCaption", Strings.get("rematch.awards"), order)
				for _, award in podium.awards do
					order += 1
					Board.text(results, `Award{order}`, `{award.label}: {award.name}`, order, 16)
				end
			end
		end,
		setNotice = function(text: string)
			status.Text = text
			setButtons(false)
			-- También llega a quien no tiene partida (entró tarde, o no llegó el grupo): sin esto, el
			-- aviso se escribiría en un tablón que nadie ve.
			window.setOpen(true)
		end,
		onVote = function(target: (accept: boolean) -> ())
			callback = target
		end,
		destroy = function()
			window.gui:Destroy()
		end,
	}
end

return RematchMenu

--!strict
-- Tablón para elegir ficha antes de que la partida eche a andar. Enseña las ocho con su modelo en 3D y
-- tres estados que se distinguen por forma y tono, no solo por un texto: libre, tuya y de otro jugador,
-- con su nombre y el color de su asiento. La elección la arbitra el servidor: aquí solo se pinta.
local Board = require("./Board")
local Components = require("./Components")
local Strings = require("../../shared/config/Strings")
local Theme = require("./Theme")
local Tokens = require("../../shared/config/Tokens")
local Ui = require("../../shared/config/Ui")

-- Nombre y color de asiento de un jugador, para la tarjeta de una ficha que ya es suya.
export type Describe = (playerId: string) -> (string, Color3)

export type Handles = {
	setVisible: (visible: boolean) -> (),
	setAssignments: (assignments: { [string]: string }, playerId: string, describe: Describe?) -> (),
	setNotice: (text: string) -> (),
	destroy: () -> (),
}

type Card = {
	root: TextButton,
	paper: Frame,
	rim: UIStroke,
	preview: ViewportFrame,
	name: TextLabel,
	status: TextLabel,
	hint: TextLabel,
	ring: Frame,
	stamp: Frame,
}

local TokenMenu = {}

local function buildCard(parent: Instance, order: number, token: Tokens.Token, onChoose: () -> ()): Card
	local color = Theme.color
	local root = Instance.new("TextButton")
	root.Name = `Token_{token.id}`
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.Text = ""
	root.LayoutOrder = order
	root.Parent = parent

	local paper = Instance.new("Frame")
	paper.Name = "Paper"
	paper.BorderSizePixel = 0
	paper.BackgroundColor3 = color.limestone
	paper.Size = UDim2.fromScale(1, 1)
	paper.Parent = root
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Ui.radius.card)
	corner.Parent = paper
	local rim = Instance.new("UIStroke")
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Color = color.asphalt
	rim.Thickness = 2
	rim.Parent = paper

	-- Todo en proporción a la tarjeta: la rejilla la encoge para que las ocho quepan en cualquier pantalla.
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.Parent = paper
	local inset = Instance.new("UIPadding")
	inset.PaddingTop = UDim.new(0, 8)
	inset.PaddingBottom = UDim.new(0, 10)
	inset.PaddingLeft = UDim.new(0, 12)
	inset.PaddingRight = UDim.new(0, 12)
	inset.Parent = body
	Board.list(body, Enum.FillDirection.Vertical, 2)

	local preview = Board.TokenPreview(body, token.id)
	preview.Size = UDim2.fromScale(1, 0)
	preview.LayoutOrder = 1
	Board.fill(preview)

	local name = Components.label(body, "Name", Strings.upper(token.label), {
		face = Theme.font.roadBold,
		size = 18,
		tint = color.asphalt,
	})
	name.Size = UDim2.new(1, 0, 0, 22)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.LayoutOrder = 2

	local statusRow = Instance.new("Frame")
	statusRow.Name = "StatusRow"
	statusRow.BackgroundTransparency = 1
	statusRow.Size = UDim2.new(1, 0, 0, 20)
	statusRow.LayoutOrder = 3
	statusRow.Parent = body
	local rowLayout = Board.list(statusRow, Enum.FillDirection.Horizontal, 8)
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	-- Disco con el color del asiento del dueño: solo en una ficha que ya es de alguien.
	local ring = Instance.new("Frame")
	ring.Name = "Owner"
	ring.BackgroundColor3 = color.asphalt
	ring.BorderSizePixel = 0
	ring.Size = UDim2.fromOffset(14, 14)
	ring.Visible = false
	ring.LayoutOrder = 1
	ring.Parent = statusRow
	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(0.5, 0)
	ringCorner.Parent = ring
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Name = "Seat"
	ringStroke.Thickness = 3
	ringStroke.Parent = ring

	local status =
		Components.label(statusRow, "Status", "", { face = Theme.font.road, size = 13, tint = color.asphalt })
	status.AutomaticSize = Enum.AutomaticSize.X
	status.Size = UDim2.fromScale(0, 1)
	status.LayoutOrder = 2

	local hint = Components.label(body, "Hint", Strings.get("token.swapHint"), {
		face = Theme.font.text,
		size = 13,
		tint = Board.muted,
		wrap = true,
	})
	hint.Size = UDim2.new(1, 0, 0, 18)
	hint.LayoutOrder = 4
	hint.Visible = false

	local stamp = Components.Stamp(paper, Strings.get("token.mine"), "Loss", 14)
	stamp.AnchorPoint = Vector2.new(1, 0)
	stamp.Position = UDim2.new(1, 8, 0, -8)
	stamp.Visible = false

	root.MouseEnter:Connect(function()
		Components.tween(paper, Ui.motion.press, { Position = UDim2.fromOffset(0, -3) })
	end)
	root.MouseLeave:Connect(function()
		Components.tween(paper, Ui.motion.press, { Position = UDim2.fromOffset(0, 0) })
	end)
	root.Activated:Connect(onChoose)

	return {
		root = root,
		paper = paper,
		rim = rim,
		preview = preview,
		name = name,
		status = status,
		hint = hint,
		ring = ring,
		stamp = stamp,
	}
end

-- Tres estados. La tuya va invertida, con borde grueso y sello; la de otro, en papel apagado, con la
-- ficha atenuada y el disco de su dueño; la libre, en papel limpio.
local function paint(card: Card, state: "Free" | "Mine" | "Taken", ownerName: string?, ownerTint: Color3?)
	local color = Theme.color
	local mine = state == "Mine"
	local taken = state == "Taken"
	card.paper.BackgroundColor3 = if mine
		then color.asphalt
		elseif taken then color.limestoneDim
		else color.limestone
	card.rim.Color = if mine then color.limestone else color.asphalt
	card.rim.Thickness = if mine then 4 else 2
	card.preview.ImageTransparency = if taken then 0.45 else 0
	local ink = if mine then color.limestone else color.asphalt
	card.name.TextColor3 = ink
	card.status.TextColor3 = ink
	card.stamp.Visible = mine
	card.ring.Visible = taken
	card.hint.Visible = taken
	if taken then
		local seat = card.ring:FindFirstChild("Seat") :: UIStroke?
		if seat ~= nil then
			seat.Color = ownerTint or color.steel
		end
		card.status.Text = Strings.upper(Strings.get("token.takenBy", { name = ownerName or "?" }))
	else
		card.status.Text = Strings.upper(Strings.get(if mine then "token.mine" else "token.free"))
	end
end

function TokenMenu.create(playerGui: Instance, onChoose: (tokenId: string) -> ()): Handles
	local window = Board.Window(playerGui, "TokenMenu", 11)
	window.setOpen(false)

	Board.Header(window.stack, 1, {
		title = Strings.get("token.title"),
		help = Strings.get("token.help"),
		steps = { Strings.get("token.step1"), Strings.get("token.step2"), Strings.get("token.step3") },
		onClose = function()
			window.setOpen(false)
		end,
	})

	local shelf = Board.Poster(window.stack, "Shelf", 2, false)
	shelf.root.Size = UDim2.fromScale(1, 0)
	Board.fill(shelf.root)
	local grid = Instance.new("UIGridLayout")
	-- Cuatro por fila y dos filas, siempre dentro del cartel: la celda es una fracción, no un tamaño fijo.
	grid.CellSize = UDim2.new(1 / Ui.tokenCard.columns, -Theme.space.l, 0.5, -Theme.space.l)
	grid.CellPadding = UDim2.fromOffset(Theme.space.l, Theme.space.l)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	shelf.layout:Destroy()
	grid.Parent = shelf.content

	local cards: { [string]: Card } = {}
	for order, token in Tokens.all() do
		cards[token.id] = buildCard(shelf.content, order, token, function()
			onChoose(token.id)
		end)
		paint(cards[token.id], "Free")
	end

	local foot = Instance.new("Frame")
	foot.Name = "Footer"
	foot.BackgroundTransparency = 1
	foot.Size = UDim2.new(1, 0, 0, Ui.board.footerHeight)
	foot.LayoutOrder = 3
	foot.Parent = window.stack
	local footLayout = Board.list(foot, Enum.FillDirection.Horizontal, Theme.space.l)
	footLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local notice = Components.label(foot, "Notice", Strings.get("token.notice"), {
		face = Theme.font.text,
		size = 17,
		tint = Theme.color.limestone,
		wrap = true,
	})
	notice.Size = UDim2.fromScale(0, 1)
	notice.TextYAlignment = Enum.TextYAlignment.Center
	notice.LayoutOrder = 1
	Board.fill(notice)
	local ready = Components.PrimaryButton(foot, "Ready", Strings.get("token.ready"))
	ready.root.Size = UDim2.fromOffset(Ui.board.sendWidth, 72)
	ready.root.LayoutOrder = 2
	ready.onActivated(function()
		window.setOpen(false)
	end)

	return {
		setVisible = function(visible: boolean)
			window.setOpen(visible)
		end,
		setAssignments = function(assignments: { [string]: string }, playerId: string, describe: Describe?)
			for tokenId, card in cards do
				local owner: string? = nil
				for otherId, chosen in assignments do
					if chosen == tokenId then
						owner = otherId
						break
					end
				end
				if owner == nil then
					paint(card, "Free")
				elseif owner == playerId then
					paint(card, "Mine")
				else
					local name, tint = nil, nil
					if describe ~= nil then
						name, tint = describe(owner)
					end
					paint(card, "Taken", name, tint)
				end
			end
		end,
		setNotice = function(text: string)
			notice.Text = text
		end,
		destroy = function()
			window.gui:Destroy()
		end,
	}
end

return TokenMenu

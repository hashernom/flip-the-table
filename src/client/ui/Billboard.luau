--!strict
-- Cartelera: la escena de `BillboardResult`. El motor tira el cartel —no hay decisión— y el cliente lo
-- enseña: un panel con las cinco salidas, una aguja que pasa por ellas y se para en la que ha salido, y
-- el importe en grande. Se abre y se cierra sola con la escena, sin pedir nada a nadie.
local Components = require("./Components")
local HudRules = require("./HudRules")
local Strings = require("../../shared/config/Strings")
local Theme = require("./Theme")
local Ui = require("../../shared/config/Ui")

local font = Theme.font
local color = Theme.color

local Billboard = {}

export type Handles = {
	play: (result: string, amount: number, playerName: string?, seconds: number) -> (),
}

-- Orden del cartel: el mismo de `Squares.billboard.results`.
local RESULTS: { string } = { "BigPrize", "SmallPrize", "Fine", "Card", "Nothing" }
local TITLE_KEY: { [string]: string } = {
	BigPrize = "billboard.bigPrize",
	SmallPrize = "billboard.smallPrize",
	Fine = "billboard.fine",
	Card = "billboard.card",
	Nothing = "billboard.nothing",
}

local CELL = 104
local CELL_HEIGHT = 92
local GAP = 8
local STRIP_TOP = 76
local STRIP_LEFT = 16
local PANEL_WIDTH = 600
local PANEL_HEIGHT = 248

local function resultText(result: string, amount: number): string
	if result == "Card" then
		return Strings.get("billboard.cardDrawn")
	elseif result == "Nothing" then
		return Strings.get("billboard.nothingHappened")
	elseif amount > 0 then
		return "+" .. HudRules.formatMoney(amount)
	elseif amount < 0 then
		return "−" .. HudRules.formatMoney(-amount)
	end
	return Strings.get("billboard.nothingHappened")
end

function Billboard.create(playerGui: Instance): Handles
	local gui = Theme.screenGui(playerGui, "Billboard", 8)

	local veil = Instance.new("Frame")
	veil.Name = "Veil"
	veil.BackgroundColor3 = color.asphaltDeep
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.Visible = false
	veil.ZIndex = 1
	veil.Parent = gui

	local panel = Components.Panel(veil, "Board", Ui.radius.plate)
	panel.root.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.root.Position = UDim2.fromScale(0.5, 0.44)
	panel.root.Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT)
	panel.root.ZIndex = 2

	local title = Components.label(panel.root, "Title", "", {
		face = font.roadBold,
		size = 30,
		align = Enum.TextXAlignment.Center,
	})
	title.ZIndex = 5
	title.Position = UDim2.fromOffset(0, 12)
	title.Size = UDim2.new(1, 0, 0, 36)

	local who = Components.label(panel.root, "Who", "", {
		face = font.road,
		size = 15,
		tint = color.limestoneDim,
		align = Enum.TextXAlignment.Center,
	})
	who.ZIndex = 5
	who.Position = UDim2.fromOffset(0, 46)
	who.Size = UDim2.new(1, 0, 0, 18)

	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.BackgroundTransparency = 1
	strip.Position = UDim2.fromOffset(STRIP_LEFT, STRIP_TOP)
	strip.Size = UDim2.fromOffset(#RESULTS * CELL + (#RESULTS - 1) * GAP, CELL_HEIGHT)
	strip.ZIndex = 4
	strip.Parent = panel.root

	for index, result in RESULTS do
		local cell = Instance.new("Frame")
		cell.Name = `Cell{index}`
		cell.BackgroundColor3 = color.asphaltDeep
		cell.BorderSizePixel = 0
		cell.Position = UDim2.fromOffset((index - 1) * (CELL + GAP), 0)
		cell.Size = UDim2.fromOffset(CELL, CELL_HEIGHT)
		cell.ZIndex = 5
		cell.Parent = strip
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0, 10)
		round.Parent = cell
		local ring = Instance.new("UIStroke")
		ring.Color = color.limestoneDim
		ring.Thickness = 2
		ring.Parent = cell

		local name = Components.label(cell, "Name", Strings.upper(Strings.get(TITLE_KEY[result] or "")), {
			face = font.roadBold,
			size = 15,
			tint = color.limestone,
			align = Enum.TextXAlignment.Center,
			wrap = true,
		})
		name.ZIndex = 6
		name.Position = UDim2.fromOffset(8, 12)
		name.Size = UDim2.new(1, -16, 1, -24)
	end

	-- La aguja: un marco que va saltando de casilla en casilla y se para en la que ha salido.
	local highlight = Instance.new("Frame")
	highlight.Name = "Highlight"
	highlight.BackgroundTransparency = 1
	highlight.Position = UDim2.fromOffset(0, 0)
	highlight.Size = UDim2.fromOffset(CELL, CELL_HEIGHT)
	highlight.ZIndex = 8
	highlight.Parent = strip
	local highlightRound = Instance.new("UICorner")
	highlightRound.CornerRadius = UDim.new(0, 10)
	highlightRound.Parent = highlight
	local highlightRing = Instance.new("UIStroke")
	highlightRing.Color = color.limestone
	highlightRing.Thickness = 4
	highlightRing.Parent = highlight

	local outcome = Components.label(panel.root, "Outcome", "", {
		face = font.roadBold,
		size = 38,
		tint = color.limestone,
		align = Enum.TextXAlignment.Center,
	})
	outcome.ZIndex = 6
	outcome.Position = UDim2.fromOffset(0, 178)
	outcome.Size = UDim2.new(1, 0, 0, 52)

	local token = 0

	local function moveTo(index: number)
		highlight.Position = UDim2.fromOffset((index - 1) * (CELL + GAP), 0)
	end

	return {
		play = function(result: string, amount: number, playerName: string?, seconds: number)
			token += 1
			local mine = token
			veil.Visible = true
			veil.BackgroundTransparency = 1
			Components.tween(veil, Ui.motion.open, { BackgroundTransparency = Ui.sheetVeil })
			title.Text = Strings.upper(Strings.get("billboard.title"))
			who.Text = if playerName ~= nil and playerName ~= ""
				then playerName
				else Strings.get("billboard.subtitle")
			outcome.Text = ""
			outcome.TextTransparency = 1
			moveTo(1)

			local landed = table.find(RESULTS, result) or 1
			local settle = math.min(1.1, seconds * 0.55)
			task.spawn(function()
				local steps = 22
				local wait = settle / (steps * 6)
				for step = 1, steps do
					if token ~= mine then
						return
					end
					moveTo(((step - 1) % #RESULTS) + 1)
					wait *= 1.16
					task.wait(wait)
				end
				if token ~= mine then
					return
				end
				moveTo(landed)
				outcome.Text = resultText(result, amount)
				outcome.TextColor3 = if amount < 0 then color.signal else color.limestone
				Components.tween(outcome, Ui.motion.open, { TextTransparency = 0 })
			end)

			task.delay(math.max(0.4, seconds - 0.15), function()
				if token ~= mine then
					return
				end
				Components.tween(veil, Ui.motion.close, { BackgroundTransparency = 1 })
				task.delay(Ui.motion.close, function()
					if token == mine then
						veil.Visible = false
					end
				end)
			end)
		end,
	}
end

return Billboard

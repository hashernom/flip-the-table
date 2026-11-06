--!strict
-- Cartelera: la escena de `BillboardResult`. El motor tira el cartel —no hay decisión— y el cliente lo
-- enseña: la pantalla se enciende, un marco recorre las cinco salidas cada vez más despacio y se para en la
-- que ha salido; las demás se apagan, la ganadora se ilumina con su color y aparece el importe. Si no sale
-- nada, la pantalla se burla con un meneo. Es un tablero de anuncios en línea, nunca una rueda.
-- Se abre y se cierra sola con la escena, sin pedir nada a nadie.
local TweenService = game:GetService("TweenService")

local BillboardRules = require("./BillboardRules")
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
-- La cifra del resultado: dónde queda y desde cuánto más abajo sube al aparecer.
local OUTCOME_TOP = 178
local OUTCOME_RISE = 14

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
	-- La pantalla se enciende creciendo un poco desde el centro.
	local power = Instance.new("UIScale")
	power.Parent = panel.root

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

	type Cell = { frame: Frame, ring: UIStroke, name: TextLabel, scale: UIScale }
	local cells: { Cell } = {}
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
		local scale = Instance.new("UIScale")
		scale.Parent = cell
		cells[index] = { frame = cell, ring = ring, name = name, scale = scale }
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
	outcome.Position = UDim2.fromOffset(0, OUTCOME_TOP)
	outcome.Size = UDim2.new(1, 0, 0, 52)

	local token = 0
	local config = Ui.billboard

	-- Curva de salida exponencial: llega con decisión y se asienta sin rebote.
	local function ease(target: Instance, seconds: number, goal: { [string]: any }): Tween
		local tween = TweenService:Create(
			target,
			TweenInfo.new(seconds, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
			goal
		)
		tween:Play()
		return tween
	end

	local function cellPosition(index: number): UDim2
		return UDim2.fromOffset((index - 1) * (CELL + GAP), 0)
	end

	-- Todas las salidas encendidas y en su sitio, como al principio de cada tirada.
	local function resetCells()
		for _, cell in cells do
			cell.frame.BackgroundColor3 = color.asphaltDeep
			cell.frame.BackgroundTransparency = 0
			cell.frame.Rotation = 0
			cell.ring.Color = color.limestoneDim
			cell.ring.Transparency = 0
			cell.name.TextColor3 = color.limestone
			cell.name.TextTransparency = 0
			cell.scale.Scale = 1
		end
		highlightRing.Color = color.limestone
		highlight.Position = cellPosition(1)
	end

	-- Color de la salida ganadora: fondo, letra y color de la cifra.
	local function toneColors(tone: string): (Color3, Color3, Color3)
		if tone == "Prize" then
			return color.taxi, color.asphalt, color.taxi
		elseif tone == "Fine" then
			return color.signal, color.limestone, color.signal
		elseif tone == "Card" then
			return color.limestone, color.navy, color.limestone
		end
		return color.asphaltDeep, color.limestoneDim, color.limestoneDim
	end

	-- La parada: las demás salidas se apagan, la ganadora se ilumina, da un golpe y aparece la cifra.
	local function land(mine: number, landed: number, result: string, amount: number)
		local tone = BillboardRules.toneFor(result)
		local fill, ink, figure = toneColors(tone)
		for index, cell in cells do
			if index ~= landed then
				ease(cell.frame, Ui.motion.open, { BackgroundTransparency = config.dimTransparency })
				ease(cell.name, Ui.motion.open, { TextTransparency = config.dimTransparency })
				ease(cell.ring, Ui.motion.open, { Transparency = config.dimTransparency })
			end
		end
		local winner = cells[landed]
		ease(winner.frame, Ui.motion.open, { BackgroundColor3 = fill })
		ease(winner.name, Ui.motion.open, { TextColor3 = ink })
		winner.ring.Color = figure
		highlightRing.Color = figure
		winner.scale.Scale = config.landPop
		ease(winner.scale, config.landPopSec * 2, { Scale = 1 })

		outcome.Text = resultText(result, amount)
		outcome.TextColor3 = figure
		outcome.Position = UDim2.fromOffset(0, OUTCOME_TOP + OUTCOME_RISE)
		ease(
			outcome,
			Ui.motion.open * 1.5,
			{ TextTransparency = 0, Position = UDim2.fromOffset(0, OUTCOME_TOP) }
		)

		-- Sin premio ni castigo, la pantalla se burla: la salida se menea de lado a lado.
		if tone == "Nothing" then
			task.spawn(function()
				for swing = 1, config.mockSwings * 2 do
					if token ~= mine then
						return
					end
					local side = if swing % 2 == 1 then 1 else -1
					ease(winner.frame, config.mockSec, { Rotation = side * config.mockDegrees })
					task.wait(config.mockSec)
				end
				if token == mine then
					ease(winner.frame, config.mockSec, { Rotation = 0 })
				end
			end)
		end
	end

	return {
		play = function(result: string, amount: number, playerName: string?, seconds: number)
			token += 1
			local mine = token
			veil.Visible = true
			veil.BackgroundTransparency = 1
			Components.tween(veil, Ui.motion.open, { BackgroundTransparency = Ui.sheetVeil })
			power.Scale = config.powerScale
			ease(power, config.powerSec, { Scale = 1 })
			title.Text = Strings.upper(Strings.get("billboard.title"))
			who.Text = if playerName ~= nil and playerName ~= ""
				then playerName
				else Strings.get("billboard.subtitle")
			outcome.Text = ""
			outcome.TextTransparency = 1
			resetCells()

			local landed = table.find(RESULTS, result) or 1
			local settle = math.min(config.maxSettleSec, seconds * config.settleShare)
			local ticks = BillboardRules.schedule(landed, #RESULTS, settle)
			task.spawn(function()
				-- Deja que la pantalla se encienda antes de que el marco eche a andar.
				task.wait(config.powerSec * 0.5)
				local started = os.clock()
				local previous = 0
				for _, tick in ticks do
					local wait = tick.at - (os.clock() - started)
					if wait > 0 then
						task.wait(wait)
					end
					if token ~= mine then
						return
					end
					-- El marco se desliza hasta la salida siguiente; cuanto más lento va, más se nota.
					local glide = math.min(config.tickSec, math.max(0.03, tick.at - previous))
					ease(highlight, glide, { Position = cellPosition(tick.index) })
					previous = tick.at
				end
				if token ~= mine then
					return
				end
				land(mine, landed, result, amount)
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

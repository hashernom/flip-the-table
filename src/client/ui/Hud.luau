--!strict
-- HUD de la partida. Pinta la mesa en la columna izquierda (`Components.PlayerChip`, una placa por asiento),
-- el letrero de ronda arriba, la mano en abanico y la calzada del plazo. Durante una escena se aparta para
-- que se vea la ciudad, y vuelve al terminar. Las decisiones viven en `ActionMenu`, a la derecha.
--
-- El plazo se calcula con el reloj del servidor, así que dos clientes ven el mismo vehículo en el mismo
-- trazo aunque uno vaya un poco por detrás.
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local ActionMenuRules = require("./ActionMenuRules")
local Cards = require("../../shared/config/Cards")
local Components = require("./Components")
local Economy = require("../../shared/config/Economy")
local HudRules = require("./HudRules")
local Protocol = require("../../shared/net/Protocol")
local Strings = require("../../shared/config/Strings")
local Theme = require("./Theme")
local Ui = require("../../shared/config/Ui")
local ViewText = require("./ViewText")

local color = Theme.color
local font = Theme.font

export type Handles = {
	gui: ScreenGui,
	setView: (view: any, names: ViewText.Names?) -> (),
	-- Plazo de la decisión en tiempo del servidor; nil esconde la calzada.
	setDeadline: (deadline: number?) -> (),
	-- Título de la escena en curso. Vacío lo esconde.
	setBanner: (text: string) -> (),
	-- Aviso breve (una acción rechazada). Se esconde solo a los `Ui.toastSeconds`.
	setToast: (text: string) -> (),
	-- Durante una escena la interfaz se aparta.
	setSceneMode: (active: boolean) -> (),
	onOverview: (callback: () -> ()) -> (),
	onEmote: (callback: (emote: string) -> ()) -> (),
	destroy: (() -> ())?,
}

local Hud = {}

-- Ronda en el círculo del letrero: «7/12», o solo el número en Sin Fin.
local function roundShort(view: any): string
	local max = view.maxRounds
	if type(max) == "number" and max > 0 then
		return `{math.min(view.round, max)}/{max}`
	end
	return tostring(view.round)
end

local RARITY_STAMP: { [string]: Components.StampKind } = {
	Common = "Common",
	Rare = "Rare",
	Legendary = "Legendary",
}

function Hud.create(playerGui: Instance, serverNow: () -> number): Handles
	local gui = Theme.screenGui(playerGui, "Hud", 5)

	-- La mesa ya dice quién hay y cómo va: la lista y la vida de Roblox sobran y ocupan ese rincón.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)

	-- La mesa: cuelga de la acera izquierda. Se aparta entera durante una escena.
	local tableFrame = Instance.new("Frame")
	tableFrame.Name = "Table"
	tableFrame.BackgroundTransparency = 1
	tableFrame.Size = UDim2.fromScale(1, 1)
	tableFrame.Parent = gui

	local chips: { [string]: Components.PlayerChip } = {}
	local lastCash: { [string]: number } = {}

	-- Letrero de ronda.
	local sign = Components.HangingSign(gui, "RoundSign", Ui.roundSignWidth)
	local roundDisc = Components.label(sign.row, "Round", "", {
		face = font.roadBold,
		size = 19,
		tint = color.asphalt,
		align = Enum.TextXAlignment.Center,
	})
	roundDisc.BackgroundTransparency = 0
	roundDisc.BackgroundColor3 = color.limestone
	roundDisc.Size = UDim2.fromOffset(62, 40)
	roundDisc.LayoutOrder = 1
	roundDisc.ZIndex = 5
	local roundCorner = Instance.new("UICorner")
	roundCorner.CornerRadius = UDim.new(0.5, 0)
	roundCorner.Parent = roundDisc

	local headline = Components.label(sign.row, "Headline", "", { face = font.road, size = 15, wrap = true })
	headline.Size = UDim2.fromOffset(Ui.roundSignWidth - 62 - 190 - 116 - 56, 40)
	headline.LayoutOrder = 2
	headline.ZIndex = 5

	local overviewButton = Components.SecondaryButton(
		sign.row,
		"OverviewButton",
		Strings.get("hud.overview"),
		Strings.get("hud.overviewKey"),
		"map"
	)
	overviewButton.root.Size = UDim2.fromOffset(190, 44)
	overviewButton.root.LayoutOrder = 3

	local emoteButton =
		Components.SecondaryButton(sign.row, "EmoteButton", Strings.get("hud.emotes"), nil, "smile")
	emoteButton.root.Size = UDim2.fromOffset(116, 44)
	emoteButton.root.LayoutOrder = 4

	for _, button in { overviewButton.root, emoteButton.root } do
		button.ZIndex = 5
		for _, child in button:GetDescendants() do
			if child:IsA("GuiObject") then
				child.ZIndex = 5
			end
		end
	end

	-- Mano en abanico: asoma de la calzada. Es solo lectura: jugar una carta va por el menú de acciones.
	local hand = Instance.new("Frame")
	hand.Name = "Hand"
	hand.BackgroundTransparency = 1
	hand.AnchorPoint = Vector2.new(0, 1)
	hand.Position = UDim2.new(0, Ui.handLeft, 1, 0)
	hand.Size = UDim2.fromOffset(Ui.handCardStep * Ui.handMaxCards, Ui.handVisibleHeight + Ui.roadHeight)
	hand.Parent = gui
	local handKey = ""

	-- Calzada del plazo.
	local timer = Components.Timer(gui, "Road")
	timer.root.ZIndex = 4
	timer.root.Visible = false

	-- Título de la escena: Luckiest Guy sobre asfalto con la barra de calzada debajo (guía §4).
	local bannerPlate = Components.Panel(gui, "SceneBanner", Ui.radius.card)
	bannerPlate.root.AnchorPoint = Vector2.new(0.5, 0)
	bannerPlate.root.Position = UDim2.new(0.5, 0, 0, Ui.bannerTop)
	bannerPlate.root.Size = UDim2.fromOffset(Ui.bannerWidth, 64)
	bannerPlate.root.Visible = false
	local bannerText = Components.label(bannerPlate.root, "Text", "", {
		face = font.shout,
		size = 32,
		align = Enum.TextXAlignment.Center,
		wrap = true,
	})
	bannerText.Size = UDim2.new(1, -24, 1, -6)
	bannerText.Position = UDim2.fromOffset(12, 0)
	bannerText.ZIndex = 5
	local bannerBar = Instance.new("Frame")
	bannerBar.Name = "RoadBar"
	bannerBar.BorderSizePixel = 0
	bannerBar.BackgroundColor3 = color.taxi
	bannerBar.AnchorPoint = Vector2.new(0.5, 1)
	bannerBar.Position = UDim2.new(0.5, 0, 1, -6)
	bannerBar.Size = UDim2.fromOffset(120, 5)
	bannerBar.ZIndex = 5
	bannerBar.Parent = bannerPlate.root

	-- Aviso breve: una acción rechazada. Es una pérdida pequeña, así que va en rojo.
	local toastPlate = Components.Panel(gui, "Toast", Ui.radius.card, color.signal)
	toastPlate.root.AnchorPoint = Vector2.new(0.5, 0)
	toastPlate.root.Position = UDim2.new(0.5, 0, 0, Ui.signTop + 66)
	toastPlate.root.Size = UDim2.fromOffset(Ui.toastWidth, 44)
	toastPlate.root.Visible = false
	local toastText = Components.label(toastPlate.root, "Text", "", {
		face = font.textBold,
		size = 16,
		align = Enum.TextXAlignment.Center,
		wrap = true,
	})
	toastText.Size = UDim2.new(1, -24, 1, 0)
	toastText.Position = UDim2.fromOffset(12, 0)
	toastText.ZIndex = 5
	local toastToken = 0
	local bannerToken = 0

	-- Emotes: una fila de discos que se despliega del letrero.
	local emoteBar = Instance.new("Frame")
	emoteBar.Name = "Emotes"
	emoteBar.BackgroundTransparency = 1
	emoteBar.AnchorPoint = Vector2.new(0.5, 0)
	emoteBar.Position = UDim2.new(0.5, 0, 0, Ui.signTop + 62)
	emoteBar.Size = UDim2.fromOffset(#Protocol.EMOTES * 56, 48)
	emoteBar.Visible = false
	emoteBar.Parent = gui
	local emoteLayout = Instance.new("UIListLayout")
	emoteLayout.FillDirection = Enum.FillDirection.Horizontal
	emoteLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	emoteLayout.Padding = UDim.new(0, 8)
	emoteLayout.Parent = emoteBar

	local deadline: number? = nil
	local deadlineTotal = 0
	local sceneActive = false

	local function refreshTimer()
		local remaining = ActionMenuRules.remainingSeconds(deadline, serverNow())
		if remaining == nil or sceneActive then
			timer.set(nil, nil)
		else
			timer.set(remaining, deadlineTotal)
		end
	end

	local overviewListeners: { () -> () } = {}
	overviewButton.onActivated(function()
		for _, listener in overviewListeners do
			listener()
		end
	end)
	local connections: { RBXScriptConnection } = {}
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if not processed and input.KeyCode == Enum.KeyCode.M then
				for _, listener in overviewListeners do
					listener()
				end
			end
		end)
	)

	local function drawHand(view: any)
		local own: any = nil
		for _, seated in view.players do
			if seated.id == view.playerId then
				own = seated
			end
		end
		local cards = if own ~= nil and own.hand ~= nil then own.hand else {}
		local key = table.concat(cards, ",")
		if key == handKey then
			return
		end
		handKey = key
		for _, child in hand:GetChildren() do
			child:Destroy()
		end
		local count = #cards
		for index, cardId in cards do
			local def = Cards.byId[cardId]
			if def ~= nil then
				local stamp: Components.StampKind = RARITY_STAMP[def.rarity] or "Common"
				local card = Components.Card(
					hand,
					`Card{index}`,
					Strings.get(`card.{cardId}.name`),
					stamp,
					Strings.get(`rarity.{def.rarity}`)
				)
				local offset = index - (count + 1) / 2
				card.Position =
					UDim2.fromOffset((index - 1) * Ui.handCardStep, math.abs(offset) * Ui.handFanDrop)
				card.Rotation = offset * Ui.handFanDegrees
			end
		end
	end

	local handles: Handles = {
		gui = gui,
		setView = function(view: any, names: ViewText.Names?)
			if view == nil then
				return
			end
			roundDisc.Text = roundShort(view)
			headline.Text = Strings.upper(ViewText.headline(view, names))

			local count = #view.players
			local turnIndex = if view.phase ~= "GameOver" then view.turnIndex else nil
			local pending = if view.pending ~= nil then view.pending else {}
			local slots = HudRules.slots(count, turnIndex)

			local rows: { Components.PlayerChipData } = {}
			local widths: { number } = {}
			for index, seated in view.players do
				local data: Components.PlayerChipData = {
					name = ViewText.seatName(view, names, seated.id),
					cash = seated.cash,
					tint = Color3.fromHex(Ui.seatColors[(index - 1) % #Ui.seatColors + 1]),
					userId = if seated.isBot == true then nil else tonumber(seated.id),
					isTurn = slots[index].isTurn,
					isGhost = seated.status == "Ghost",
					isBot = seated.isBot == true,
					hasLeft = seated.status == "Left",
					crown = pending.crownId == seated.id,
					traitor = seated.traitorUntilRound ~= nil and view.round <= seated.traitorUntilRound,
					fury = seated.fury,
					furyMax = Economy.furyThreshold,
					cards = seated.handCount,
					skipTurn = seated.skipTurns > 0,
				}
				rows[index] = data
				table.insert(widths, Components.chipContentWidth(data, count))
			end
			local width = HudRules.columnWidth(widths)

			local seen: { [string]: boolean } = {}
			for index, seated in view.players do
				seen[seated.id] = true
				local chip = chips[seated.id]
				local isNew = chip == nil
				if chip == nil then
					chip = Components.PlayerChip(tableFrame, `Seat{index}`)
					chips[seated.id] = chip
				end
				local goal = UDim2.fromOffset(Ui.plateColumnLeft, slots[index].y)
				if isNew then
					chip.root.Position = goal
				else
					Components.tween(chip.root, Ui.motion.plateShift, { Position = goal })
				end
				local previous = lastCash[seated.id]
				chip.set(rows[index], count, width, previous ~= nil)
				if previous ~= nil and previous ~= seated.cash then
					chip.floatMoney(seated.cash - previous)
				end
				lastCash[seated.id] = seated.cash
			end
			for id, chip in chips do
				if not seen[id] then
					chip.destroy()
					chips[id] = nil
					lastCash[id] = nil
				end
			end

			drawHand(view)
		end,
		setDeadline = function(value: number?)
			deadline = value
			local remaining = ActionMenuRules.remainingSeconds(value, serverNow())
			deadlineTotal = if remaining ~= nil then remaining else 0
			refreshTimer()
		end,
		setBanner = function(text: string)
			bannerText.Text = Strings.upper(text)
			local show = text ~= ""
			bannerToken += 1
			local mine = bannerToken
			if show then
				-- El título anuncia y se va: la escena sigue sola, sin nada encima.
				task.delay(Ui.bannerSeconds, function()
					if bannerToken == mine then
						bannerPlate.root.Visible = false
					end
				end)
			end
			if show and not bannerPlate.root.Visible then
				bannerPlate.root.Position = UDim2.new(0.5, 0, 0, Ui.bannerTop - 18)
				Components.tween(bannerPlate.root, Ui.motion.open, {
					Position = UDim2.new(0.5, 0, 0, Ui.bannerTop),
				})
			end
			bannerPlate.root.Visible = show
		end,
		setToast = function(text: string)
			toastToken += 1
			local mine = toastToken
			toastText.Text = text
			toastPlate.root.Visible = text ~= ""
			if text ~= "" then
				-- Un aviso nuevo reinicia la cuenta: el viejo no puede esconder al reciente.
				task.delay(Ui.toastSeconds, function()
					if toastToken == mine then
						toastPlate.root.Visible = false
					end
				end)
			end
		end,
		setSceneMode = function(active: boolean)
			sceneActive = active
			local shift = if active then -(Ui.plateColumnLeft + Ui.plateMaxWidth + Ui.arrowTipWidth) else 0
			Components.tween(tableFrame, Ui.motion.open, { Position = UDim2.fromOffset(shift, 0) })
			Components.tween(hand, Ui.motion.open, {
				Position = UDim2.new(
					0,
					Ui.handLeft,
					1,
					if active then Ui.handVisibleHeight + Ui.roadHeight else 0
				),
			})
			Components.tween(sign.root, Ui.motion.open, {
				Position = UDim2.new(0.5, 0, 0, if active then -(Ui.signTop + 70) else Ui.signTop),
			})
			emoteBar.Visible = false
			refreshTimer()
		end,
		onOverview = function(callback: () -> ())
			table.insert(overviewListeners, callback)
		end,
		onEmote = function(callback: (emote: string) -> ())
			emoteButton.onActivated(function()
				emoteBar.Visible = not emoteBar.Visible
			end)
			for index, emote in Protocol.EMOTES do
				local item = Theme.button(emoteBar, emote, index, function()
					emoteBar.Visible = false
					callback(emote)
				end)
				item.Size = UDim2.fromOffset(48, 48)
			end
		end,
		destroy = function()
			for _, connection in connections do
				connection:Disconnect()
			end
			gui:Destroy()
		end,
	}

	-- El plazo se mueve solo: los segundos que quedan no llegan por lote.
	task.spawn(function()
		while gui.Parent do
			if deadline ~= nil then
				refreshTimer()
			end
			task.wait(0.1)
		end
	end)

	return handles
end

return Hud

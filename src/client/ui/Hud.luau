--!strict
-- HUD de la partida. Pinta la mesa en la columna izquierda (`Components.PlayerChip`, una placa por asiento),
-- el letrero de ronda arriba, la mano en abanico y la calzada del plazo. Durante una escena se aparta para
-- que se vea la ciudad, y vuelve al terminar. Las decisiones viven en `ActionMenu`, a la derecha.
--
-- El plazo se calcula con el reloj del servidor, así que dos clientes ven el mismo vehículo en el mismo
-- trazo aunque uno vaya un poco por detrás.
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ActionMenuRules = require("./ActionMenuRules")
local AudioDirector = require("../audio/AudioDirector")
local Cards = require("../../shared/config/Cards")
local Board = require("./Board")
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
	-- El jugador pulsó «Propiedades».
	onManage: (callback: () -> ()) -> (),
	-- El jugador pulsó Ajustes en el letrero.
	onSettings: (callback: () -> ()) -> (),
	-- El jugador pulsó «Retomar»: un bot jugaba su asiento y quiere volver a mandar él.
	onReclaim: (callback: () -> ()) -> (),
	onEmote: (callback: (emote: string) -> ()) -> (),
	-- Jugadas de carta legales ahora, por carta, cada una con su texto («Jugar Empujón contra Ana»).
	setPlayable: (
		byCard: { [string]: { { action: any, label: string, target: string?, tint: string? } } }
	) -> (),
	-- El jugador confirmó una jugada desde la vista grande de una carta de su mano.
	onPlayCard: (callback: (action: any) -> ()) -> (),
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
	headline.Size = UDim2.fromOffset(
		Ui.roundSignWidth - 62 - 190 - Ui.manageButtonWidth - 116 - Ui.settingsButtonWidth - 72,
		40
	)
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

	-- Gestionar propiedades (R-P53): recorre las propias con la cámara.
	local manageButton = Components.SecondaryButton(
		sign.row,
		"ManageButton",
		Strings.get("manage.title"),
		Strings.get("manage.key"),
		"plate-arrow"
	)
	manageButton.root.Size = UDim2.fromOffset(Ui.manageButtonWidth, 44)
	manageButton.root.LayoutOrder = 4

	local emoteButton =
		Components.SecondaryButton(sign.row, "EmoteButton", Strings.get("hud.emotes"), nil, "smile")
	emoteButton.root.Size = UDim2.fromOffset(116, 44)
	emoteButton.root.LayoutOrder = 5

	local settingsButton = Components.SecondaryButton(
		sign.row,
		"SettingsButton",
		Strings.get("hud.settings"),
		Strings.get("hud.settingsKey")
	)
	settingsButton.root.Size = UDim2.fromOffset(Ui.settingsButtonWidth, 44)
	settingsButton.root.LayoutOrder = 6

	for _, button in { overviewButton.root, manageButton.root, emoteButton.root, settingsButton.root } do
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
	-- En espejo (`Ui.hudMirror`) la mano va a la derecha.
	local mirrored = Ui.hudMirror == true
	local handWidth = Ui.handCardStep * Ui.handMaxCards
	local function handAt(drop: number): UDim2
		return if mirrored then UDim2.new(1, -Ui.handLeft, 1, drop) else UDim2.new(0, Ui.handLeft, 1, drop)
	end
	hand.AnchorPoint = if mirrored then Vector2.new(1, 1) else Vector2.new(0, 1)
	hand.Position = handAt(0)
	hand.Size = UDim2.fromOffset(Ui.handCardStep * Ui.handMaxCards, Ui.handVisibleHeight + Ui.roadHeight)
	hand.Parent = gui
	local handKey = ""
	local lastHand: { string } = {}
	-- La primera mano que se pinta (al entrar o tras resincronizar) no cae: ya estaba ahí.
	local handPainted = false

	-- Carta en grande sobre la mano: se abre al pasar el ratón por una carta y se cierra al salir.
	local preview: CanvasGroup? = nil
	local previewToken = 0
	local hoveredCard: number? = nil
	-- Carta fijada con un clic: su vista grande se queda abierta, con los botones para jugarla dentro.
	local pinnedCard: number? = nil
	local pinnedShow: (() -> ())? = nil
	local playable: { [string]: { { action: any, label: string, target: string?, tint: string? } } } = {}
	local playListeners: { (action: any) -> () } = {}
	local function hidePreview()
		previewToken += 1
		local mine = previewToken
		local current = preview
		if current == nil then
			return
		end
		Components.tween(current, Ui.motion.close, { GroupTransparency = 1 })
		task.delay(Ui.motion.close, function()
			if previewToken == mine and current.Parent ~= nil then
				current:Destroy()
				if preview == current then
					preview = nil
				end
			end
		end)
	end
	local function unpin()
		pinnedCard = nil
		pinnedShow = nil
		hidePreview()
	end

	-- Botones de jugar dentro de la carta fijada. Un objetivo: «Confirmar». Varios: uno por objetivo.
	-- Sin jugada legal ahora, una línea que lo dice. La carta crece hacia arriba lo que ocupan.
	-- Botón compacto de un objetivo: solo su nombre, con una franja del color de su zona si la tiene. El texto
	-- se encoge para caber: nunca se sale del botón.
	local function targetButton(parent: Instance, order: number, text: string, tint: string?): TextButton
		local config = Ui.cardPreview
		local button = Instance.new("TextButton")
		button.Name = `Target{order}`
		button.AutoButtonColor = false
		button.Text = ""
		button.BackgroundColor3 = color.asphaltDeep
		button.LayoutOrder = order
		button.Parent = parent
		Theme.corner(button, 8)
		local rim = Instance.new("UIStroke")
		rim.Color = color.limestone
		rim.Transparency = 0.55
		rim.Thickness = 1.5
		rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rim.Parent = button
		local left = 10
		if tint ~= nil then
			local swatch = Instance.new("Frame")
			swatch.Name = "Zone"
			swatch.BorderSizePixel = 0
			swatch.BackgroundColor3 = Color3.fromHex(tint)
			swatch.AnchorPoint = Vector2.new(0, 0.5)
			swatch.Position = UDim2.new(0, 6, 0.5, 0)
			swatch.Size = UDim2.new(0, 6, 1, -12)
			swatch.Parent = button
			Theme.corner(swatch, 3)
			left = 18
		end
		local label = Components.label(button, "Text", text, { face = font.roadBold, size = 13 })
		label.Position = UDim2.fromOffset(left, 0)
		label.Size = UDim2.new(1, -left - 6, 1, 0)
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.TextScaled = true
		local fit = Instance.new("UITextSizeConstraint")
		fit.MaxTextSize = Theme.textSize(13)
		fit.MinTextSize = config.targetMinText
		fit.Parent = label
		button.MouseEnter:Connect(function()
			rim.Transparency = 0
		end)
		button.MouseLeave:Connect(function()
			rim.Transparency = 0.55
		end)
		return button
	end

	-- Botones de jugar dentro de la carta fijada. Un objetivo: «Confirmar». Varios: una rejilla de dos columnas
	-- con solo el nombre de cada objetivo, bajo la frase «Elige dónde». Sin jugada legal ahora, una línea que
	-- lo dice. La carta crece hacia arriba lo que ocupan.
	local function addPlayArea(face: CanvasGroup, cardId: string)
		local config = Ui.cardPreview
		local options: { { action: any, label: string, target: string?, tint: string? } } = playable[cardId]
			or {}
		local many = #options > 1
		local width = if many then config.wideWidth else config.width
		local areaHeight: number
		if many then
			local rows = math.ceil(#options / 2)
			areaHeight = config.actionPad * 2
				+ config.captionHeight
				+ rows * config.targetHeight
				+ (rows - 1) * config.actionGap
		else
			areaHeight = config.actionPad * 2 + config.actionHeight
		end
		face.Size = UDim2.fromOffset(width, config.height + areaHeight)
		local body = face:FindFirstChild("Body") :: Frame?
		if body ~= nil then
			body.Size = UDim2.new(1, 0, 1, -30 - areaHeight)
		end
		local area = Instance.new("Frame")
		area.Name = "Play"
		area.BackgroundColor3 = color.asphalt
		area.BorderSizePixel = 0
		area.AnchorPoint = Vector2.new(0, 1)
		area.Position = UDim2.fromScale(0, 1)
		area.Size = UDim2.new(1, 0, 0, areaHeight)
		area.Parent = face
		local inset = Instance.new("UIPadding")
		inset.PaddingTop = UDim.new(0, config.actionPad)
		inset.PaddingBottom = UDim.new(0, config.actionPad)
		inset.PaddingLeft = UDim.new(0, config.actionPad)
		inset.PaddingRight = UDim.new(0, config.actionPad)
		inset.Parent = area
		local function play(action: any)
			unpin()
			for _, listener in playListeners do
				listener(action)
			end
		end
		if #options == 0 then
			local note = Components.label(area, "NotNow", Strings.get("hand.notNow"), {
				face = font.textBold,
				size = 15,
				tint = color.limestoneDim,
				align = Enum.TextXAlignment.Center,
				wrap = true,
			})
			note.Size = UDim2.new(1, 0, 0, config.actionHeight)
			note.TextYAlignment = Enum.TextYAlignment.Center
			return
		end
		if not many then
			local button = Components.SecondaryButton(area, "Play1", Strings.get("hand.confirm"))
			button.root.Size = UDim2.new(1, 0, 0, config.actionHeight)
			local action = options[1].action
			button.onActivated(function()
				play(action)
			end)
			return
		end
		local caption = Components.label(area, "Choose", Strings.upper(Strings.get("hand.chooseTarget")), {
			face = font.road,
			size = 12,
			tint = color.limestoneDim,
		})
		caption.Size = UDim2.new(1, 0, 0, config.captionHeight - 4)
		local grid = Instance.new("Frame")
		grid.Name = "Targets"
		grid.BackgroundTransparency = 1
		grid.Position = UDim2.fromOffset(0, config.captionHeight)
		grid.Size = UDim2.new(1, 0, 1, -config.captionHeight)
		grid.Parent = area
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(0.5, -config.actionGap / 2, 0, config.targetHeight)
		layout.CellPadding = UDim2.fromOffset(config.actionGap, config.actionGap)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		for order, option in options do
			local action = option.action
			targetButton(grid, order, option.target or option.label, option.tint).Activated:Connect(function()
				play(action)
			end)
		end
	end

	local function showPreview(cardId: string, rarity: string, slotX: number, pinned: boolean?)
		previewToken += 1
		local current = preview
		if current ~= nil then
			current:Destroy()
		end
		local config = Ui.cardPreview
		local face = Board.CardFace(gui, cardId, rarity)
		if pinned then
			addPlayArea(face, cardId)
		end
		face.AnchorPoint = Vector2.new(0, 1)
		local lift = -(Ui.handVisibleHeight + Ui.roadHeight + config.gap)
		face.Position = if mirrored
			then UDim2.new(1, -Ui.handLeft - handWidth + slotX, 1, lift)
			else UDim2.new(0, Ui.handLeft + slotX, 1, lift)
		face.ZIndex = 20
		face.GroupTransparency = 1
		local grow = Instance.new("UIScale")
		grow.Scale = config.scaleFrom
		grow.Parent = face
		Components.tween(face, Ui.motion.open, { GroupTransparency = 0 })
		Components.tween(grow, Ui.motion.open, { Scale = 1 })
		preview = face
	end

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

	-- Letrero de «un bot juega por ti»: aparece mientras el asiento propio lo controla un bot y deja
	-- retomarlo con un botón. Sin él, recuperar el control dependía de acertar una acción antes que el bot.
	local reclaimPlate = Components.Panel(gui, "Reclaim", Ui.radius.card)
	reclaimPlate.root.AnchorPoint = Vector2.new(0.5, 0)
	reclaimPlate.root.Position = UDim2.new(0.5, 0, 0, Ui.signTop + Ui.reclaimTop)
	reclaimPlate.root.Size = UDim2.fromOffset(Ui.reclaimWidth, 96)
	reclaimPlate.root.Visible = false
	local reclaimTitle =
		Components.label(reclaimPlate.root, "Title", Strings.upper(Strings.get("hud.botPlaying")), {
			face = font.roadBold,
			size = 22,
		})
	reclaimTitle.Position = UDim2.fromOffset(20, 14)
	reclaimTitle.Size = UDim2.new(1, -250, 0, 28)
	reclaimTitle.ZIndex = 5
	local reclaimHint = Components.label(
		reclaimPlate.root,
		"Hint",
		Strings.get("hud.botHint", { count = Economy.bot.timeoutsToControl }),
		{
			face = font.text,
			size = 15,
			tint = color.limestoneDim,
			wrap = true,
		}
	)
	reclaimHint.Position = UDim2.fromOffset(20, 44)
	reclaimHint.Size = UDim2.new(1, -250, 0, 40)
	reclaimHint.ZIndex = 5
	local reclaimButton = Components.PrimaryButton(reclaimPlate.root, "Reclaim", Strings.get("hud.reclaim"))
	reclaimButton.root.AnchorPoint = Vector2.new(1, 0.5)
	reclaimButton.root.Position = UDim2.new(1, -14, 0.5, 0)
	reclaimButton.root.Size = UDim2.fromOffset(210, 70)
	reclaimButton.root.ZIndex = 5
	local reclaimListeners: { () -> () } = {}
	reclaimButton.onActivated(function()
		-- Se esconde al momento: la vista que lo confirma llega con el siguiente lote.
		reclaimPlate.root.Visible = false
		for _, listener in reclaimListeners do
			listener()
		end
	end)

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
			if input.KeyCode == Enum.KeyCode.Escape and pinnedCard ~= nil then
				unpin()
				return
			end
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
		hoveredCard = nil
		pinnedCard = nil
		pinnedShow = nil
		hidePreview()
		for _, child in hand:GetChildren() do
			child:Destroy()
		end
		-- Las cartas nuevas son las que no estaban en la mano anterior, contando repetidas.
		local before: { [string]: number } = {}
		for _, cardId in lastHand do
			before[cardId] = (before[cardId] or 0) + 1
		end
		local isFirst = not handPainted
		handPainted = true
		lastHand = table.clone(cards)
		local count = #cards
		for index, cardId in cards do
			local fresh = (before[cardId] or 0) == 0
			if not fresh then
				before[cardId] -= 1
			end
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
				local slotX = (index - 1) * Ui.handCardStep
				local place = UDim2.fromOffset(slotX, math.abs(offset) * Ui.handFanDrop)
				local angle = offset * Ui.handFanDegrees
				card.Position = place
				card.Rotation = angle
				-- Al cruzar de una carta a la de al lado, Roblox puede avisar de la entrada en la nueva antes
				-- que de la salida de la vieja: solo cierra la vista la salida de la carta que se enseña.
				-- Con una carta fijada, pasar por las demás no cambia nada: la fijada manda hasta soltarla.
				card.MouseEnter:Connect(function()
					hoveredCard = index
					if pinnedCard == nil then
						showPreview(cardId, def.rarity, slotX)
					end
				end)
				card.MouseLeave:Connect(function()
					if hoveredCard == index then
						hoveredCard = nil
						if pinnedCard == nil then
							hidePreview()
						end
					end
				end)
				-- Clic: fija la carta y abre dentro los botones para jugarla. Otro clic en ella la suelta.
				local hit = Instance.new("TextButton")
				hit.Name = "Hit"
				hit.BackgroundTransparency = 1
				hit.Text = ""
				hit.Size = UDim2.fromScale(1, 1)
				hit.ZIndex = 10
				hit.Parent = card
				hit.Activated:Connect(function()
					if pinnedCard == index then
						unpin()
						return
					end
					pinnedCard = index
					pinnedShow = function()
						showPreview(cardId, def.rarity, slotX, true)
					end
					showPreview(cardId, def.rarity, slotX, true)
				end)
				-- Una carta robada cae girada y grande desde arriba hasta su sitio en el abanico.
				if fresh and not isFirst then
					local draw = Ui.cardDraw
					local grow = Instance.new("UIScale")
					grow.Scale = draw.scale
					grow.Parent = card
					card.Position = UDim2.fromOffset(slotX + draw.shift, -draw.rise)
					card.Rotation = draw.tilt
					local info = TweenInfo.new(draw.seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
					TweenService:Create(card, info, { Position = place, Rotation = angle }):Play()
					TweenService:Create(grow, info, { Scale = 1 }):Play()
				end
			end
		end
	end

	local function playableKey(
		options: { { action: any, label: string, target: string?, tint: string? } }?
	): string
		local labels = {}
		local list: { { action: any, label: string, target: string?, tint: string? } } = options or {}
		for _, option in list do
			table.insert(labels, option.label)
		end
		return table.concat(labels, "|")
	end

	local handles: Handles = {
		gui = gui,
		setPlayable = function(byCard: {
			[string]: { { action: any, label: string, target: string?, tint: string? } },
		})
			local changed = false
			for cardId, options in byCard do
				if playableKey(playable[cardId]) ~= playableKey(options) then
					changed = true
				end
			end
			for cardId in playable do
				if byCard[cardId] == nil then
					changed = true
				end
			end
			playable = byCard
			-- La carta fijada se rehace solo si sus jugadas cambiaron (otro turno, otro objetivo).
			local show = pinnedShow
			if changed and show ~= nil then
				show()
			end
		end,
		onPlayCard = function(callback: (action: any) -> ())
			table.insert(playListeners, callback)
		end,
		setView = function(view: any, names: ViewText.Names?)
			if view == nil then
				return
			end
			roundDisc.Text = roundShort(view)
			local own = nil
			for _, seated in view.players do
				if seated.id == view.playerId then
					own = seated
				end
			end
			reclaimPlate.root.Visible = own ~= nil
				and own.isBot == true
				and own.status == "Active"
				and view.phase ~= "GameOver"
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
			-- Si en esta vista alguien cobra o paga, suena una vez de cada: el ingreso y la pérdida son
			-- eventos de la mesa y los oyen todos los clientes, porque todos ven el mismo cambio de caja.
			local gained, lost = false, false
			for index, seated in view.players do
				seen[seated.id] = true
				local chip = chips[seated.id]
				local isNew = chip == nil
				if chip == nil then
					chip = Components.PlayerChip(tableFrame, `Seat{index}`)
					chips[seated.id] = chip
				end
				-- En espejo la columna de jugadores va a la derecha y las placas se anclan por su derecha.
				chip.root.AnchorPoint = if mirrored then Vector2.new(1, 0) else Vector2.new(0, 0)
				local goal = if mirrored
					then UDim2.new(1, -Ui.plateColumnLeft, 0, slots[index].y)
					else UDim2.fromOffset(Ui.plateColumnLeft, slots[index].y)
				if isNew then
					chip.root.Position = goal
				else
					Components.tween(chip.root, Ui.motion.plateShift, { Position = goal })
				end
				local previous = lastCash[seated.id]
				chip.set(rows[index], count, width, previous ~= nil)
				if previous ~= nil and previous ~= seated.cash then
					local delta = seated.cash - previous
					chip.floatMoney(delta)
					if delta > 0 then
						gained = true
					else
						lost = true
					end
				end
				lastCash[seated.id] = seated.cash
			end
			if gained then
				AudioDirector.play("sfx.moneyGain")
			end
			if lost then
				AudioDirector.play("sfx.moneyLoss")
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
			local away = Ui.plateColumnLeft + Ui.plateMaxWidth + Ui.arrowTipWidth
			local shift = if not active then 0 elseif mirrored then away else -away
			Components.tween(tableFrame, Ui.motion.open, { Position = UDim2.fromOffset(shift, 0) })
			Components.tween(hand, Ui.motion.open, {
				Position = handAt(if active then Ui.handVisibleHeight + Ui.roadHeight else 0),
			})
			Components.tween(sign.root, Ui.motion.open, {
				Position = UDim2.new(0.5, 0, 0, if active then -(Ui.signTop + 70) else Ui.signTop),
			})
			emoteBar.Visible = false
			refreshTimer()
		end,
		onSettings = function(callback: () -> ())
			settingsButton.onActivated(callback)
		end,
		onReclaim = function(callback: () -> ())
			table.insert(reclaimListeners, callback)
		end,
		onOverview = function(callback: () -> ())
			table.insert(overviewListeners, callback)
		end,
		onManage = function(callback: () -> ())
			manageButton.onActivated(callback)
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

--!strict
-- Tablón de obra: el estándar de las ventanas de la partida (tratos, pactos, fichas y revancha). Un tablón
-- de asfalto entre dos postes de acero, con carteles de papel pegados con cinta. Cada ventana empieza por
-- un cartel de título que dice qué es, en una frase, y que despliega los pasos con «Cómo funciona».
--
-- Aquí solo están las piezas; qué va en cada cartel lo decide cada menú. Los textos llegan resueltos.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArtAssets = require("../../shared/config/ArtAssets")
local CardArt = require("../../shared/config/CardArt")
local Components = require("./Components")
local HudRules = require("./HudRules")
local SocialRules = require("./SocialRules")
local Strings = require("../../shared/config/Strings")
local Theme = require("./Theme")
local Tokens = require("../../shared/config/Tokens")
local Ui = require("../../shared/config/Ui")

local color = Theme.color
local font = Theme.font
local tween = Components.tween
local label = Components.label

-- Tinta secundaria sobre el papel: el asfalto de apoyo, que sobre caliza pasa de 4,5:1.
local PAPER_MUTED = Theme.buttonHot
-- Grosor del papel: el canto inferior del cartel, un poco más oscuro que la caliza.
local PAPER_EDGE = Color3.fromRGB(185, 175, 152)

local Board = {}

local function frame(parent: Instance, name: string, tint: Color3?): Frame
	local item = Instance.new("Frame")
	item.Name = name
	item.BorderSizePixel = 0
	item.BackgroundTransparency = if tint == nil then 1 else 0
	item.BackgroundColor3 = tint or color.asphalt
	item.Parent = parent
	return item
end

local function corner(target: GuiObject, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = target
end

local function stroke(target: GuiObject, tint: Color3, thickness: number): UIStroke
	local item = Instance.new("UIStroke")
	item.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	item.Color = tint
	item.Thickness = thickness
	item.Parent = target
	return item
end

local function pad(target: GuiObject, amount: number)
	local item = Instance.new("UIPadding")
	local value = UDim.new(0, amount)
	item.PaddingTop = value
	item.PaddingBottom = value
	item.PaddingLeft = value
	item.PaddingRight = value
	item.Parent = target
end

local function list(target: GuiObject, direction: Enum.FillDirection, gap: number): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = target
	return layout
end

-- Hace que un hijo de una lista ocupe el sitio que sobra.
function Board.fill(target: GuiObject)
	local flex = Instance.new("UIFlexItem")
	flex.FlexMode = Enum.UIFlexMode.Fill
	flex.Parent = target
end

Board.list = list
Board.muted = PAPER_MUTED

-- Tablón ----------------------------------------------------------------------------------------------

export type Window = {
	gui: ScreenGui,
	root: Frame,
	-- Pila vertical dentro del tablón: aquí van los carteles, de arriba abajo.
	stack: Frame,
	setOpen: (open: boolean) -> (),
	isOpen: () -> boolean,
	onClosed: (callback: () -> ()) -> (),
	-- Borra los carteles para volver a montarlos.
	clear: () -> (),
}

-- Con `dismissable` a false, el velo no cierra: la revancha espera el voto. `maxSize` limita el tablón
-- de una ventana con poco contenido; sin él, mide como mucho el tamaño de diseño de `Ui.board`.
function Board.Window(
	playerGui: Instance,
	name: string,
	displayOrder: number,
	dismissable: boolean?,
	maxSize: Vector2?
): Window
	local config = Ui.board
	local gui = Theme.screenGui(playerGui, name, displayOrder)

	local veil = Instance.new("TextButton")
	veil.Name = "Veil"
	veil.AutoButtonColor = false
	veil.BackgroundColor3 = color.asphaltDeep
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.Text = ""
	veil.Visible = false
	veil.Parent = gui

	local root = frame(gui, "Board")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Visible = false
	-- Un marco que no es botón deja pasar el clic al velo, y tocar el tablón lo cerraría.
	root.Active = true
	-- El tablón mide su tamaño de diseño y, si la pantalla no le da sitio, se encoge entero: encoger solo
	-- el marco dejaría sus carteles, de medidas fijas, saliéndose del papel.
	local design = maxSize or Vector2.new(config.width, config.height)
	root.Size = UDim2.fromOffset(design.X, design.Y)
	local shrink = Instance.new("UIScale")
	shrink.Parent = root
	local function fit()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local viewport = camera.ViewportSize
		local uiScale = Theme.scaleFor(viewport)
		local room = math.min(
			viewport.X / uiScale * config.fraction / design.X,
			viewport.Y / uiScale * config.fraction / design.Y
		)
		shrink.Scale = math.clamp(room, config.minScale, 1)
	end
	fit()
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	-- Los postes van detrás del tablón y asoman por arriba y por abajo.
	for _, side in { 0, 1 } do
		local post = frame(root, if side == 0 then "PostLeft" else "PostRight", color.steel)
		post.AnchorPoint = Vector2.new(side, 0)
		post.Position = UDim2.new(side, if side == 0 then 10 else -10, 0, -config.postOverhang)
		post.Size = UDim2.new(0, config.postWidth, 1, config.postOverhang * 2)
		post.ZIndex = 1
		corner(post, Ui.radius.small)
		stroke(post, color.asphalt, 3)
	end

	local plate = Components.Panel(root, "Plank", Ui.radius.small)
	plate.root.Size = UDim2.fromScale(1, 1)
	plate.root.ZIndex = 2

	local stack = frame(plate.body, "Stack")
	stack.Size = UDim2.fromScale(1, 1)
	stack.ZIndex = 4
	pad(stack, config.padding)
	list(stack, Enum.FillDirection.Vertical, config.gap)

	local open = false
	local token = 0
	local listeners: { () -> () } = {}
	local risen = UDim2.new(0.5, 0, 0.5, Ui.sheetRise)
	local centered = UDim2.fromScale(0.5, 0.5)

	local function setOpen(value: boolean)
		if value == open then
			return
		end
		open = value
		token += 1
		local mine = token
		if value then
			veil.Visible = true
			root.Visible = true
			root.Position = risen
			veil.BackgroundTransparency = 1
			tween(root, Ui.motion.open, { Position = centered })
			tween(veil, Ui.motion.open, { BackgroundTransparency = Ui.sheetVeil })
		else
			tween(root, Ui.motion.close, { Position = risen })
			tween(veil, Ui.motion.close, { BackgroundTransparency = 1 })
			task.delay(Ui.motion.close, function()
				-- Si se volvió a abrir mientras se cerraba, este cierre viejo no lo esconde.
				if token == mine and not open then
					veil.Visible = false
					root.Visible = false
				end
			end)
			for _, listener in listeners do
				listener()
			end
		end
	end

	veil.MouseButton1Click:Connect(function()
		if dismissable ~= false then
			setOpen(false)
		end
	end)

	return {
		gui = gui,
		root = root,
		stack = stack,
		setOpen = setOpen,
		isOpen = function(): boolean
			return open
		end,
		onClosed = function(callback: () -> ())
			table.insert(listeners, callback)
		end,
		clear = function()
			for _, child in stack:GetChildren() do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
		end,
	}
end

-- Cartel -----------------------------------------------------------------------------------------------

export type Poster = {
	root: Frame,
	-- Donde van los hijos, con relleno y una lista vertical.
	content: Frame,
	layout: UIListLayout,
}

-- Cartel de papel pegado con dos tiras de cinta. Con `auto`, crece con su contenido; si no, el que lo
-- crea le da el tamaño. Solo el cartel de título se tuerce: una lista con scroll no recorta bien girada.
function Board.Poster(parent: Instance, name: string, order: number, auto: boolean, tilt: number?): Poster
	local config = Ui.poster
	local root = frame(parent, name, color.limestone)
	root.LayoutOrder = order
	root.Rotation = tilt or 0
	corner(root, 3)
	if auto then
		root.Size = UDim2.fromScale(1, 0)
		root.AutomaticSize = Enum.AutomaticSize.Y
	end

	-- El canto del papel, por dentro y abajo: el grosor del cartel, sin sombra.
	local edge = frame(root, "Edge", PAPER_EDGE)
	edge.AnchorPoint = Vector2.new(0, 1)
	edge.Position = UDim2.fromScale(0, 1)
	edge.Size = UDim2.new(1, 0, 0, 4)
	corner(edge, 3)

	for _, side in { 0, 1 } do
		local tape = frame(root, "Tape", color.limestoneDim)
		tape.BackgroundTransparency = 0.15
		tape.AnchorPoint = Vector2.new(0.5, 0.5)
		tape.Position = UDim2.new(side, if side == 0 then 6 else -6, 0, 2)
		tape.Size = UDim2.fromOffset(config.tapeWidth, config.tapeHeight)
		tape.Rotation = if side == 0 then -30 else 30
		tape.ZIndex = 3
		stroke(tape, PAPER_EDGE, 1)
	end

	local content = frame(root, "Content")
	content.Size = if auto then UDim2.fromScale(1, 0) else UDim2.fromScale(1, 1)
	content.AutomaticSize = if auto then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
	pad(content, config.padding)
	local layout = list(content, Enum.FillDirection.Vertical, Theme.space.m)

	return { root = root, content = content, layout = layout }
end

-- Texto sobre el papel, que crece hacia abajo sin cortarse.
function Board.text(parent: Instance, name: string, text: string, order: number, size: number?): TextLabel
	local item =
		label(parent, name, text, { face = font.text, size = size or 17, tint = color.asphalt, wrap = true })
	item.Size = UDim2.fromScale(1, 0)
	item.AutomaticSize = Enum.AutomaticSize.Y
	item.LayoutOrder = order
	return item
end

-- Rótulo pequeño de sección, en la voz de la calle.
function Board.caption(parent: Instance, name: string, text: string, order: number): TextLabel
	local item = label(
		parent,
		name,
		Strings.upper(text),
		{ face = font.road, size = 13, tint = PAPER_MUTED, wrap = true }
	)
	item.Size = UDim2.fromScale(1, 0)
	item.AutomaticSize = Enum.AutomaticSize.Y
	item.LayoutOrder = order
	return item
end

-- Cabecera de ventana --------------------------------------------------------------------------------

export type HeaderOptions = {
	title: string,
	help: string,
	steps: { string },
	-- Sin `onClose`, la ventana no tiene botón de cerrar.
	onClose: (() -> ())?,
}

-- Galón de «Cómo funciona»: dos trazos en V, dibujados, no un glifo de fuente.
local function chevron(parent: Instance): Frame
	local holder = frame(parent, "Chevron")
	holder.Size = UDim2.fromOffset(12, 12)
	holder.LayoutOrder = 1
	for _, side in { -1, 1 } do
		local bar = frame(holder, "Bar", color.asphalt)
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.new(0.5, side * 3, 0.5, 0)
		bar.Size = UDim2.fromOffset(8, 2)
		bar.Rotation = side * -45
	end
	return holder
end

-- Cartel de título: nombre de la ventana, botón de cerrar, la frase que la explica y los pasos plegados.
function Board.Header(parent: Instance, order: number, options: HeaderOptions): Poster
	local poster = Board.Poster(parent, "Header", order, true, Ui.poster.titleTilt)

	local top = frame(poster.content, "Top")
	top.Size = UDim2.new(1, 0, 0, 48)
	top.LayoutOrder = 1
	local title = label(
		top,
		"Title",
		Strings.upper(options.title),
		{ face = font.roadBold, size = 44, tint = color.asphalt }
	)
	title.Size = UDim2.new(1, -170, 1, 0)
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextScaled = false
	title.TextWrapped = false
	title.TextTruncate = Enum.TextTruncate.None
	local onClose = options.onClose
	if onClose ~= nil then
		local close = Components.SecondaryButton(
			top,
			"Close",
			Strings.get("sheet.close"),
			Strings.get("sheet.closeKey")
		)
		close.root.AnchorPoint = Vector2.new(1, 0.5)
		close.root.Position = UDim2.fromScale(1, 0.5)
		close.root.Size = UDim2.fromOffset(150, 44)
		close.onActivated(onClose)
	else
		title.Size = UDim2.fromScale(1, 1)
	end

	local helpRow = frame(poster.content, "Help")
	helpRow.Size = UDim2.fromScale(1, 0)
	helpRow.AutomaticSize = Enum.AutomaticSize.Y
	helpRow.LayoutOrder = 2
	local rowLayout = list(helpRow, Enum.FillDirection.Horizontal, Theme.space.l)
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	local sentence = Board.text(helpRow, "Sentence", options.help, 1)
	sentence.Size = UDim2.new(1, -190, 0, 0)

	local toggle = Instance.new("TextButton")
	toggle.Name = "HowTo"
	toggle.AutoButtonColor = false
	toggle.BackgroundTransparency = 1
	toggle.Text = ""
	toggle.Size = UDim2.fromOffset(174, 32)
	toggle.LayoutOrder = 2
	toggle.Parent = helpRow
	corner(toggle, 16)
	stroke(toggle, color.asphalt, 1.5)
	local toggleRow = frame(toggle, "Row")
	toggleRow.Size = UDim2.fromScale(1, 1)
	local toggleLayout = list(toggleRow, Enum.FillDirection.Horizontal, 6)
	toggleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	toggleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	local mark = chevron(toggleRow)
	local toggleText = label(
		toggleRow,
		"Text",
		Strings.upper(Strings.get("board.howTo")),
		{ face = font.road, size = 12, tint = color.asphalt }
	)
	toggleText.AutomaticSize = Enum.AutomaticSize.X
	toggleText.Size = UDim2.fromScale(0, 1)
	toggleText.LayoutOrder = 2

	local steps = frame(poster.content, "Steps")
	steps.Size = UDim2.fromScale(1, 0)
	steps.AutomaticSize = Enum.AutomaticSize.Y
	steps.LayoutOrder = 3
	steps.Visible = false
	local stepsLayout = list(steps, Enum.FillDirection.Horizontal, Theme.space.l)
	stepsLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	local share = 1 / math.max(1, #options.steps)
	for index, text in options.steps do
		local step = frame(steps, `Step{index}`)
		step.Size = UDim2.new(share, -Theme.space.l, 0, 0)
		step.AutomaticSize = Enum.AutomaticSize.Y
		step.LayoutOrder = index
		local number = frame(step, "Number", color.asphalt)
		number.Size = UDim2.fromOffset(22, 22)
		corner(number, 11)
		local digit = label(
			number,
			"Digit",
			tostring(index),
			{ face = font.roadBold, size = 12, align = Enum.TextXAlignment.Center }
		)
		digit.Size = UDim2.fromScale(1, 1)
		local body = Board.text(step, "Text", text, 0, 15)
		body.Position = UDim2.fromOffset(30, 1)
		body.Size = UDim2.new(1, -30, 0, 0)
	end

	local expanded = false
	toggle.Activated:Connect(function()
		expanded = not expanded
		steps.Visible = expanded
		mark.Rotation = if expanded then 180 else 0
		toggleText.Text = Strings.upper(Strings.get(if expanded then "board.hideHowTo" else "board.howTo"))
	end)

	return poster
end

-- Perfil de jugador en un cartel ----------------------------------------------------------------------

export type ProfileData = { name: string, cash: number, tint: Color3, userId: number?, bot: boolean? }

function Board.Profile(parent: Instance, order: number, data: ProfileData): Frame
	local row = frame(parent, "Profile")
	row.Size = UDim2.new(1, 0, 0, 60)
	row.LayoutOrder = order
	local disc = Components.Disc(row)
	disc.setSize(48)
	disc.root.AnchorPoint = Vector2.new(0, 0.5)
	disc.root.Position = UDim2.new(0, 8, 0.5, 0)
	disc.set({ tint = data.tint, userId = data.userId, bot = data.bot })
	local name = label(
		row,
		"Name",
		Strings.upper(data.name),
		{ face = font.roadBold, size = 24, tint = color.asphalt }
	)
	name.Position = UDim2.fromOffset(74, 0)
	name.Size = UDim2.new(1, -220, 1, 0)
	name.TextYAlignment = Enum.TextYAlignment.Center
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local money = Components.MoneyLabel(row, "Money", 22)
	money.root.AnchorPoint = Vector2.new(1, 0.5)
	money.root.Position = UDim2.fromScale(1, 0.5)
	money.set(data.cash)
	return row
end

-- Pestañas sobre el papel ------------------------------------------------------------------------------

export type Tab = { id: string, label: string }

-- Fila de pestañas para elegir una opción: rival, rondas. La elegida va rellena y las demás solo con
-- contorno, así que se distingue por forma y tono, no solo por color.
function Board.Tabs(
	parent: Instance,
	order: number,
	tabs: { Tab },
	selectedId: string?,
	onPick: (id: string) -> ()
): Frame
	local row = frame(parent, "Tabs")
	row.Size = UDim2.fromScale(1, 0)
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.LayoutOrder = order
	local layout = list(row, Enum.FillDirection.Horizontal, Theme.space.s)
	layout.Wraps = true
	for position, item in tabs do
		local chosen = item.id == selectedId
		local tab = Instance.new("TextButton")
		tab.Name = `Tab{position}`
		tab.AutoButtonColor = false
		tab.AutomaticSize = Enum.AutomaticSize.X
		tab.Size = UDim2.fromOffset(0, 36)
		tab.BackgroundColor3 = color.asphalt
		tab.BackgroundTransparency = if chosen then 0 else 1
		tab.FontFace = font.road
		tab.TextSize = 14
		tab.TextColor3 = if chosen then color.limestone else color.asphalt
		tab.Text = Strings.upper(item.label)
		tab.LayoutOrder = position
		tab.Parent = row
		corner(tab, 18)
		stroke(tab, color.asphalt, 2)
		local inset = Instance.new("UIPadding")
		inset.PaddingLeft = UDim.new(0, 14)
		inset.PaddingRight = UDim.new(0, 14)
		inset.Parent = tab
		tab.MouseEnter:Connect(function()
			if not chosen then
				tween(tab, Ui.motion.press, { BackgroundTransparency = 0.85 })
			end
		end)
		tab.MouseLeave:Connect(function()
			if not chosen then
				tween(tab, Ui.motion.press, { BackgroundTransparency = 1 })
			end
		end)
		tab.Activated:Connect(function()
			if not chosen then
				onPick(item.id)
			end
		end)
	end
	return row
end

-- Escritura en miniatura ------------------------------------------------------------------------------

export type MiniDeed = {
	root: TextButton,
	setSelected: (selected: boolean) -> (),
	onActivated: (callback: () -> ()) -> (),
}

-- Una escritura pequeña que se toca para meterla o sacarla del trato. La elegida se despega del cartel,
-- engorda el borde y lleva el sello: forma y texto, no solo color.
function Board.MiniDeed(
	parent: Instance,
	name: string,
	deed: any,
	stampText: string,
	interactive: boolean
): MiniDeed
	local size = Ui.miniDeed
	local root = Instance.new("TextButton")
	root.Name = name
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.Text = ""
	root.Active = interactive
	root.Size = UDim2.fromOffset(size.width, size.height + size.lift)
	root.Parent = parent

	local card = frame(root, "Card", color.limestone)
	card.Position = UDim2.fromOffset(0, size.lift)
	card.Size = UDim2.fromOffset(size.width, size.height)
	corner(card, 10)
	local rim = stroke(card, color.asphalt, 2)

	local ink = if HudRules.inkFor(deed.zoneColor) == "asphalt" then color.asphalt else color.limestone
	local zone = frame(card, "Zone", Color3.fromHex(deed.zoneColor))
	zone.Size = UDim2.new(1, 0, 0, size.zone)
	corner(zone, 8)
	local zonePad = Instance.new("UIPadding")
	zonePad.PaddingLeft = UDim.new(0, 8)
	zonePad.PaddingRight = UDim.new(0, 8)
	zonePad.PaddingTop = UDim.new(0, 6)
	zonePad.Parent = zone
	local zoneName =
		label(zone, "ZoneName", Strings.upper(deed.zoneName), { face = font.road, size = 12, tint = ink })
	zoneName.Size = UDim2.new(1, 0, 0, 12)
	zoneName.TextTruncate = Enum.TextTruncate.AtEnd
	local title = label(
		zone,
		"Name",
		Strings.upper(deed.name),
		{ face = font.roadBold, size = 14, tint = ink, wrap = true }
	)
	title.Position = UDim2.fromOffset(0, 14)
	title.Size = UDim2.new(1, 0, 1, -16)
	title.TextYAlignment = Enum.TextYAlignment.Top

	local price = frame(card, "Price", color.asphalt)
	price.Position = UDim2.fromOffset(0, size.zone)
	price.Size = UDim2.new(1, 0, 0, size.price)
	local priceLabel =
		label(price, "Label", Strings.upper(Strings.get("deed.price")), { face = font.road, size = 12 })
	priceLabel.Position = UDim2.fromOffset(8, 0)
	priceLabel.Size = UDim2.fromScale(0.5, 1)
	local priceValue = label(price, "Value", HudRules.formatMoney(deed.price), {
		face = font.roadBold,
		size = 16,
		align = Enum.TextXAlignment.Right,
	})
	priceValue.AnchorPoint = Vector2.new(1, 0)
	priceValue.Position = UDim2.new(1, -8, 0, 0)
	priceValue.Size = UDim2.fromScale(0.5, 1)

	local rents: { any } = deed.rents or {}
	local lines: { string } = {}
	for position = 1, math.min(2, #rents) do
		table.insert(lines, `{rents[position].label}: {HudRules.formatMoney(rents[position].amount)}`)
	end
	local rentText = label(
		card,
		"Rent",
		table.concat(lines, "\n"),
		{ face = font.text, size = 12, tint = color.asphalt, wrap = true }
	)
	rentText.Position = UDim2.fromOffset(8, size.zone + size.price + 6)
	rentText.Size = UDim2.new(1, -16, 0, size.height - size.zone - size.price - 12)
	rentText.TextYAlignment = Enum.TextYAlignment.Top

	local stamp = Components.Stamp(card, stampText, "Loss")
	stamp.AnchorPoint = Vector2.new(1, 0)
	stamp.Position = UDim2.new(1, 8, 0, -8)
	stamp.ZIndex = 4
	for _, child in stamp:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = 4
		end
	end
	stamp.Visible = false

	local selected = false
	local listeners: { () -> () } = {}
	local function place()
		local lift = if selected then 0 else size.lift
		tween(card, Ui.motion.press, { Position = UDim2.fromOffset(0, lift) })
		rim.Thickness = if selected then 4 else 2
		stamp.Visible = selected
	end
	if interactive then
		root.MouseEnter:Connect(function()
			if not selected then
				tween(card, Ui.motion.press, { Position = UDim2.fromOffset(0, size.lift - 3) })
			end
		end)
		root.MouseLeave:Connect(place)
		root.Activated:Connect(function()
			for _, listener in listeners do
				listener()
			end
		end)
	end

	return {
		root = root,
		setSelected = function(value: boolean)
			selected = value
			place()
		end,
		onActivated = function(callback: () -> ())
			table.insert(listeners, callback)
		end,
	}
end

-- Rejilla de escrituras con scroll: con muchas propiedades, el cartel no crece, se desplaza.
function Board.DeedGrid(parent: Instance, order: number): ScrollingFrame
	local size = Ui.miniDeed
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Deeds"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Size = UDim2.fromScale(1, 0)
	grid.CanvasSize = UDim2.fromScale(0, 0)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = color.asphalt
	grid.LayoutOrder = order
	grid.Parent = parent
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(size.width, size.height + size.lift)
	layout.CellPadding = UDim2.fromOffset(size.gap, size.gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	-- Hueco a la derecha para el sello, que asoma por fuera de la escritura.
	local inset = Instance.new("UIPadding")
	inset.PaddingRight = UDim.new(0, 10)
	inset.PaddingTop = UDim.new(0, 4)
	inset.Parent = grid
	Board.fill(grid)
	return grid
end

-- Campo de dinero -------------------------------------------------------------------------------------

export type CashField = {
	root: Frame,
	get: () -> number,
	set: (amount: number) -> (),
	setMax: (maximum: number) -> (),
	onChanged: (callback: (amount: number) -> ()) -> (),
}

-- Importe escrito a mano, en una ventana de taxímetro. Se lee al escribir y se acota al máximo; al
-- salir del campo se reescribe con el punto de miles.
function Board.CashField(parent: Instance, order: number, editable: boolean): CashField
	local config = Ui.cashField
	local row = frame(parent, "Cash")
	row.Size = UDim2.new(1, 0, 0, config.height)
	row.LayoutOrder = order
	local layout = list(row, Enum.FillDirection.Horizontal, Theme.space.m)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center

	local caption = label(
		row,
		"Caption",
		Strings.upper(Strings.get("trade.cash")),
		{ face = font.road, size = 13, tint = PAPER_MUTED }
	)
	caption.AutomaticSize = Enum.AutomaticSize.X
	caption.Size = UDim2.fromScale(0, 1)
	caption.TextYAlignment = Enum.TextYAlignment.Center
	caption.LayoutOrder = 1

	local box = Instance.new("TextBox")
	box.Name = "Amount"
	box.BackgroundColor3 = color.asphaltDeep
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.TextEditable = editable
	box.Active = editable
	box.FontFace = font.textBold
	box.TextSize = 26
	box.TextColor3 = color.limestone
	box.PlaceholderText = "0"
	box.PlaceholderColor3 = color.steel
	box.Text = "0"
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Size = UDim2.fromOffset(config.width, config.height)
	box.LayoutOrder = 2
	box.Parent = row
	corner(box, Ui.radius.small)
	local boxPad = Instance.new("UIPadding")
	boxPad.PaddingLeft = UDim.new(0, 12)
	boxPad.PaddingRight = UDim.new(0, 12)
	boxPad.Parent = box
	local ring = stroke(box, color.limestoneDim, 2)

	local maxLabel = label(row, "Max", "", { face = font.text, size = 14, tint = PAPER_MUTED })
	maxLabel.AutomaticSize = Enum.AutomaticSize.X
	maxLabel.Size = UDim2.fromScale(0, 1)
	maxLabel.TextYAlignment = Enum.TextYAlignment.Center
	maxLabel.LayoutOrder = 3

	local amount = 0
	local maximum = math.huge
	local listeners: { (number) -> () } = {}
	local function settle(value: number, rewrite: boolean)
		local clamped = math.clamp(value, 0, maximum)
		local changed = clamped ~= amount
		amount = clamped
		if rewrite then
			box.Text = HudRules.formatMoney(amount)
		end
		if changed then
			for _, listener in listeners do
				listener(amount)
			end
		end
	end

	box:GetPropertyChangedSignal("Text"):Connect(function()
		if box:IsFocused() then
			settle(SocialRules.parseCash(box.Text, maximum), false)
		end
	end)
	box.Focused:Connect(function()
		ring.Color = color.navy
		ring.Thickness = 3
	end)
	box.FocusLost:Connect(function()
		ring.Color = color.limestoneDim
		ring.Thickness = 2
		settle(SocialRules.parseCash(box.Text, maximum), true)
	end)

	return {
		root = row,
		get = function(): number
			return amount
		end,
		set = function(value: number)
			settle(value, true)
		end,
		setMax = function(value: number)
			maximum = math.max(0, value)
			maxLabel.Text = Strings.get("trade.cashMax", { max = HudRules.formatMoney(maximum) })
			if amount > maximum then
				settle(maximum, true)
			end
		end,
		onChanged = function(callback: (number) -> ())
			table.insert(listeners, callback)
		end,
	}
end

-- Señal de doble sentido entre los dos carteles: dos flechas opuestas, dibujadas.
function Board.SwapSign(parent: Instance, order: number): Frame
	local size = Ui.board.swapSize
	local holder = frame(parent, "Swap")
	holder.Size = UDim2.new(0, size, 1, 0)
	holder.LayoutOrder = order
	local disc = frame(holder, "Disc", color.navy)
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromOffset(size, size)
	corner(disc, size // 2)
	stroke(disc, color.limestone, 5)
	-- Arriba, la flecha va a la derecha; abajo, a la izquierda. La punta es un trazo inclinado en el extremo.
	for _, side in { -1, 1 } do
		local shaft = frame(disc, "Shaft", color.limestone)
		shaft.AnchorPoint = Vector2.new(0.5, 0.5)
		shaft.Position = UDim2.new(0.5, 0, 0.5, side * 9)
		shaft.Size = UDim2.fromOffset(40, 4)
		local head = frame(disc, "Head", color.limestone)
		head.AnchorPoint = Vector2.new(0.5, 0.5)
		head.Position = UDim2.new(0.5, -side * 15, 0.5, side * 12)
		head.Size = UDim2.fromOffset(14, 4)
		head.Rotation = 37
	end
	return holder
end

-- Tarjeta de decisión ----------------------------------------------------------------------------------

export type DecisionCard = {
	root: GuiObject,
	setText: (text: string) -> (),
	setEnabled: (enabled: boolean) -> (),
	onActivated: (callback: () -> ()) -> (),
	destroy: () -> (),
	-- Entra repartida: crece, se endereza y aparece, tras `delay` segundos.
	playIn: (delay: number) -> (),
}

local RARITY_STAMP: { [string]: Components.StampKind } = {
	Common = "Common",
	Rare = "Rare",
	Legendary = "Legendary",
}

-- Una opción del panel de decisión (perk, voto, jugada, carta del mercado) como una tarjeta pequeña de
-- papel. Es efímera: entra repartida, crece un poco al pasar el ratón y se hunde al pulsarla. Un pase
-- («no reaccionar», «no comprar nada») no es tarjeta: es una píldora de contorno, para que no compita.
function Board.DecisionCard(
	parent: Instance,
	name: string,
	data: any,
	tilt: number,
	rarity: string?
): DecisionCard
	local config = Ui.decisionCard
	local pass = data.kind == "Pass"
	local root = Instance.new("TextButton")
	root.Name = name
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.Text = ""
	root.Size = UDim2.new(1, -config.inset, 0, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.Parent = parent

	local face = Instance.new("CanvasGroup")
	face.Name = "Face"
	face.BorderSizePixel = 0
	face.BackgroundColor3 = if pass then color.asphalt else color.limestone
	face.Size = UDim2.fromScale(1, 0)
	face.AutomaticSize = Enum.AutomaticSize.Y
	face.Rotation = if pass then 0 else tilt
	face.Parent = root
	corner(face, if pass then Ui.radius.pill else 10)
	local rim = stroke(face, if pass then color.limestone else color.asphalt, 2)
	local scale = Instance.new("UIScale")
	scale.Parent = face
	list(face, Enum.FillDirection.Vertical, 0)

	local title: TextLabel
	if pass then
		local inset = Instance.new("UIPadding")
		inset.PaddingTop = UDim.new(0, 11)
		inset.PaddingBottom = UDim.new(0, 11)
		inset.PaddingLeft = UDim.new(0, 14)
		inset.PaddingRight = UDim.new(0, 14)
		inset.Parent = face
		title = label(face, "Title", Strings.upper(data.title), {
			face = font.road,
			size = 14,
			align = Enum.TextXAlignment.Center,
			wrap = true,
		})
		title.Size = UDim2.fromScale(1, 0)
		title.AutomaticSize = Enum.AutomaticSize.Y
	else
		-- Franja de asfalto con el tipo: lo que la distingue de un vistazo, junto con el sello de la carta.
		local band = frame(face, "Band", color.asphalt)
		band.Size = UDim2.new(1, 0, 0, config.band)
		band.LayoutOrder = 1
		local kind = label(band, "Kind", Strings.upper(Strings.get(`option.kind.{data.kind}`)), {
			face = font.road,
			size = 12,
		})
		kind.Position = UDim2.fromOffset(10, 0)
		kind.Size = UDim2.new(1, -20, 1, 0)
		kind.TextYAlignment = Enum.TextYAlignment.Center

		-- El perk lleva su icono en la franja: es lo que lo distingue de un voto o de una jugada antes de
		-- leer nada. Va en blanco, teñido de caliza, como los iconos de `UiIcons`.
		local perkAsset = if data.kind == "Perk" and data.perkId ~= nil
			then CardArt.image(CardArt.perk(tostring(data.perkId)))
			else ""
		if perkAsset ~= "" then
			local perkIcon = Instance.new("ImageLabel")
			perkIcon.Name = "PerkIcon"
			perkIcon.BackgroundTransparency = 1
			perkIcon.BorderSizePixel = 0
			perkIcon.Image = perkAsset
			perkIcon.ImageColor3 = color.limestone
			perkIcon.ScaleType = Enum.ScaleType.Fit
			perkIcon.Size = UDim2.fromOffset(config.iconSize, config.iconSize)
			perkIcon.Position = UDim2.fromOffset(10, (config.band - config.iconSize) / 2)
			perkIcon.ZIndex = 3
			perkIcon.Parent = band
			kind.Position = UDim2.fromOffset(10 + config.iconSize + 6, 0)
			kind.Size = UDim2.new(1, -(config.iconSize + 26), 1, 0)
		end

		local body = frame(face, "Body")
		body.Size = UDim2.fromScale(1, 0)
		body.AutomaticSize = Enum.AutomaticSize.Y
		body.LayoutOrder = 2
		local inset = Instance.new("UIPadding")
		inset.PaddingTop = UDim.new(0, 8)
		inset.PaddingBottom = UDim.new(0, 10)
		inset.PaddingLeft = UDim.new(0, 10)
		inset.PaddingRight = UDim.new(0, 10)
		inset.Parent = body
		list(body, Enum.FillDirection.Vertical, 3)
		title = label(body, "Title", Strings.upper(data.title), {
			face = font.roadBold,
			size = 18,
			tint = color.asphalt,
			wrap = true,
		})
		title.Size = UDim2.fromScale(1, 0)
		title.AutomaticSize = Enum.AutomaticSize.Y
		title.LayoutOrder = 1
		if data.detail ~= nil and data.detail ~= data.title then
			local detail = Board.text(body, "Detail", data.detail, 2, 14)
			detail.TextColor3 = PAPER_MUTED
		end
		if data.note ~= nil then
			local note = label(
				body,
				"Note",
				data.note,
				{ face = font.roadBold, size = 14, tint = color.navy, wrap = true }
			)
			note.Size = UDim2.fromScale(1, 0)
			note.AutomaticSize = Enum.AutomaticSize.Y
			note.LayoutOrder = 3
		end
	end

	-- El sello va fuera de la cara: la cara recorta lo que se sale y el sello asoma por la esquina.
	if rarity ~= nil and RARITY_STAMP[rarity] ~= nil then
		local seal = Components.Stamp(root, Strings.get(`rarity.{rarity}`), RARITY_STAMP[rarity], 12)
		seal.AnchorPoint = Vector2.new(1, 0)
		seal.Position = UDim2.new(1, 4, 0, 1)
		seal.ZIndex = 3
	end
	local chosen = Components.Stamp(root, Strings.get("option.chosen"), "Loss", 14)
	chosen.AnchorPoint = Vector2.new(1, 1)
	chosen.Position = UDim2.new(1, 4, 1, 4)
	chosen.ZIndex = 3
	chosen.Visible = false

	local enabled = true
	local listeners: { () -> () } = {}
	local rest = if pass then 0 else tilt
	-- Todo se mueve con escala y giro, nunca con la posición: la tarjeta mide lo que su texto pide y una
	-- posición animada haría crecer y saltar la columna entera.
	local hovered = false
	root.MouseEnter:Connect(function()
		if enabled then
			hovered = true
			tween(face, Ui.motion.press, { Rotation = 0 })
			tween(scale, Ui.motion.press, { Scale = config.hoverScale })
			rim.Thickness = 3
		end
	end)
	root.MouseLeave:Connect(function()
		hovered = false
		tween(face, Ui.motion.press, { Rotation = rest })
		tween(scale, Ui.motion.press, { Scale = 1 })
		rim.Thickness = 2
	end)
	root.MouseButton1Down:Connect(function()
		if enabled then
			tween(scale, Ui.motion.press, { Scale = config.pressScale })
		end
	end)
	root.MouseButton1Up:Connect(function()
		tween(scale, Ui.motion.press, { Scale = if hovered then config.hoverScale else 1 })
	end)
	root.Activated:Connect(function()
		if not enabled then
			return
		end
		for _, listener in listeners do
			listener()
		end
	end)

	return {
		root = root,
		setText = function(text: string)
			title.Text = Strings.upper(text)
		end,
		setEnabled = function(value: boolean)
			enabled = value
			root.Active = value
			face.GroupTransparency = if value then 0 else 0.35
		end,
		onActivated = function(callback: () -> ())
			table.insert(listeners, function()
				-- El sello de «elegida» sale al pulsar; el panel se rehace cuando el servidor responde.
				if not pass then
					chosen.Visible = true
				end
				callback()
			end)
		end,
		destroy = function()
			root:Destroy()
		end,
		playIn = function(delay: number)
			face.GroupTransparency = 1
			face.Rotation = rest + config.dealTilt
			scale.Scale = config.dealScale
			task.delay(delay, function()
				if root.Parent == nil then
					return
				end
				tween(face, Ui.motion.open, {
					GroupTransparency = if enabled then 0 else 0.35,
					Rotation = rest,
				})
				tween(scale, Ui.motion.open, { Scale = 1 })
			end)
		end,
	}
end

-- Carta en grande ---------------------------------------------------------------------------------------

-- La carta de la mano a tamaño de lectura: nombre, rareza, lo que hace y su tipo. Se abre al pasar el
-- ratón por una carta de la mano, que asoma recortada por el pie de la pantalla. Es un `CanvasGroup`
-- para entrar y salir con un fundido entero.
function Board.CardFace(parent: Instance, cardId: string, rarity: string): CanvasGroup
	local config = Ui.cardPreview
	local face = Instance.new("CanvasGroup")
	face.Name = "CardPreview"
	face.BorderSizePixel = 0
	face.BackgroundColor3 = color.limestone
	face.Size = UDim2.fromOffset(config.width, config.height)
	face.Parent = parent
	corner(face, Ui.radius.card)
	stroke(face, color.asphalt, 4)

	-- Con arte, la carta es la ilustración: la imagen arriba a su proporción 312 x 450 y la descripción
	-- debajo. Sin arte se queda la carta de papel de siempre.
	local asset = CardArt.image(CardArt.card(cardId))
	if asset ~= "" then
		local artHeight = math.floor(config.width / CardArt.ASPECT)
		face.Size = UDim2.fromOffset(config.width, artHeight + Ui.cardArt.textHeight)
		local picture = Instance.new("ImageLabel")
		picture.Name = "Picture"
		picture.BackgroundTransparency = 1
		picture.BorderSizePixel = 0
		picture.Image = asset
		picture.ScaleType = Enum.ScaleType.Fit
		picture.Size = UDim2.fromOffset(config.width, artHeight)
		picture.Parent = face

		local body = frame(face, "Body")
		body.Position = UDim2.fromOffset(0, artHeight)
		body.Size = UDim2.new(1, 0, 1, -artHeight)
		pad(body, 12)
		list(body, Enum.FillDirection.Vertical, Theme.space.s)
		local rule = frame(body, "Rule", color.asphalt)
		rule.Size = UDim2.new(1, 0, 0, 2)
		rule.LayoutOrder = 1
		local detail = Board.text(body, "Detail", Strings.get(`card.{cardId}.description`), 2, 15)
		detail.LayoutOrder = 2
		return face
	end

	local band = frame(face, "Band", color.asphalt)
	band.Size = UDim2.new(1, 0, 0, 30)
	local kind =
		label(band, "Kind", Strings.upper(Strings.get("option.kind.Card")), { face = font.road, size = 13 })
	kind.Position = UDim2.fromOffset(14, 0)
	kind.Size = UDim2.new(1, -28, 1, 0)
	kind.TextYAlignment = Enum.TextYAlignment.Center

	local body = frame(face, "Body")
	body.Position = UDim2.fromOffset(0, 30)
	body.Size = UDim2.new(1, 0, 1, -30)
	pad(body, 16)
	list(body, Enum.FillDirection.Vertical, Theme.space.m)
	local title = label(body, "Title", Strings.upper(Strings.get(`card.{cardId}.name`)), {
		face = font.roadBold,
		size = 28,
		tint = color.asphalt,
		wrap = true,
	})
	title.Size = UDim2.fromScale(1, 0)
	title.AutomaticSize = Enum.AutomaticSize.Y
	title.LayoutOrder = 1
	local seal = Components.Stamp(body, Strings.get(`rarity.{rarity}`), RARITY_STAMP[rarity] or "Common", 14)
	seal.LayoutOrder = 2
	local rule = frame(body, "Rule", color.asphalt)
	rule.Size = UDim2.new(1, 0, 0, 2)
	rule.LayoutOrder = 3
	local detail = Board.text(body, "Detail", Strings.get(`card.{cardId}.description`), 4, 17)
	detail.LayoutOrder = 4
	return face
end

-- Ficha en tres dimensiones -----------------------------------------------------------------------------

-- La ficha de verdad, montada con sus piezas del arte cargado y vista de tres cuartos. Sin el arte
-- todavía, el visor queda vacío y la tarjeta se lee por su nombre.
function Board.TokenPreview(parent: Instance, tokenId: string): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Preview"
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 196, 186)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(-1, -2, -1)
	viewport.Parent = parent

	local folder = ReplicatedStorage:FindFirstChild(ArtAssets.FOLDER)
	local spec = Tokens.get(tokenId)
	if folder == nil or spec == nil then
		return viewport
	end
	local model = Instance.new("Model")
	for _, piece in spec.art.pieces do
		local source = folder:FindFirstChild(piece.key)
		if source ~= nil and source:IsA("BasePart") then
			local mesh = source:Clone()
			mesh.Anchored = true
			mesh.Parent = model
		end
	end
	if #model:GetChildren() == 0 then
		model:Destroy()
		return viewport
	end
	model.Parent = viewport
	local box, extents = model:GetBoundingBox()
	local radius = extents.Magnitude / 2
	local camera = Instance.new("Camera")
	camera.FieldOfView = Ui.tokenPreview.fieldOfView
	local direction = Vector3.new(1, 0.55, 1.15).Unit
	local distance = radius / math.sin(math.rad(camera.FieldOfView / 2)) * Ui.tokenPreview.margin
	camera.CFrame = CFrame.lookAt(box.Position + direction * distance, box.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

return Board

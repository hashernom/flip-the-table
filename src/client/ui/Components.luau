--!strict
-- Biblioteca de componentes de la interfaz, en la dirección Señalética: chapa esmaltada, discos de señal,
-- cifras de taxímetro, sellos, cartón y la calzada del plazo. Cada componente devuelve su marco raíz y
-- las funciones para cambiarlo; todo texto llega ya resuelto por quien lo llama, desde `Strings`.
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local CardArt = require("../../shared/config/CardArt")
local Strings = require("../../shared/config/Strings")
local HudRules = require("./HudRules")
local Theme = require("./Theme")
local Ui = require("../../shared/config/Ui")
local UiIcons = require("../../shared/config/UiIcons")

local color = Theme.color
local font = Theme.font

local Components = {}

local moneyWidth: (amount: number, size: number) -> number

-- Curva común: rápido al salir y suave al llegar. Una sola, para que todo se mueva igual.
local function tween(target: Instance, seconds: number, goal: { [string]: any }): Tween
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local animation = TweenService:Create(target, info, goal)
	animation:Play()
	return animation
end

Components.tween = tween

local function corner(target: GuiObject, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = target
end

local function round(target: GuiObject)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0.5, 0)
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

local function frame(parent: Instance, name: string, tint: Color3?): Frame
	local item = Instance.new("Frame")
	item.Name = name
	item.BorderSizePixel = 0
	item.BackgroundTransparency = if tint == nil then 1 else 0
	item.BackgroundColor3 = tint or color.asphalt
	item.Parent = parent
	return item
end

export type LabelOptions = {
	face: Font,
	size: number,
	tint: Color3?,
	align: Enum.TextXAlignment?,
	wrap: boolean?,
}

local function label(parent: Instance, name: string, text: string, options: LabelOptions): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.FontFace = options.face
	item.TextSize = Theme.textSize(options.size)
	item.TextColor3 = options.tint or color.limestone
	item.TextXAlignment = options.align or Enum.TextXAlignment.Left
	item.TextWrapped = options.wrap == true
	item.Text = text
	item.Parent = parent
	return item
end

Components.label = label

local function icon(parent: Instance, name: string, id: string, tint: Color3?): ImageLabel
	local item = Instance.new("ImageLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Image = UiIcons[id]
	item.ImageColor3 = tint or Color3.new(1, 1, 1)
	item.ScaleType = Enum.ScaleType.Fit
	item.Parent = parent
	return item
end

Components.icon = icon

-- Chapa esmaltada: labio de sombra sólida, aro de asfalto, borde de caliza y cuerpo. Es la pieza de la que
-- sale casi toda la interfaz. `radius` es la esquina troquelada.
export type Plate = { root: Frame, body: Frame, rim: UIStroke, lip: Frame }

function Components.Panel(parent: Instance, name: string, radius: number?, fill: Color3?): Plate
	local size = radius or Ui.radius.plate
	local root = frame(parent, name)

	local lip = frame(root, "Lip", color.asphaltDeep)
	lip.BackgroundTransparency = 0.45
	lip.Position = UDim2.fromOffset(-2, 3)
	lip.Size = UDim2.new(1, 4, 1, 4)
	lip.ZIndex = 1
	corner(lip, size + 2)

	local ring = frame(root, "Ring", color.asphalt)
	ring.Position = UDim2.fromOffset(-2, -2)
	ring.Size = UDim2.new(1, 4, 1, 4)
	ring.ZIndex = 2
	corner(ring, size + 2)

	local body = frame(root, "Body", fill or color.asphalt)
	body.Size = UDim2.fromScale(1, 1)
	body.ZIndex = 3
	corner(body, size)
	local rim = stroke(body, color.limestone, 3)

	return { root = root, body = body, rim = rim, lip = lip }
end

-- Taxímetro: cada cifra en su ventana de ancho fijo, para que el dinero no baile al rodar. Sube y baja
-- pasando por los valores intermedios y lanza el importe flotando cuando se le pide. El importe flotante
-- se cuelga de `overlay` (la placa entera) para quedar por delante del avatar, por el lado libre.
export type MoneyLabel = {
	root: Frame,
	set: (amount: number, animate: boolean?) -> (),
	float: (delta: number) -> (),
	setFace: (size: number, fill: Color3) -> (),
}

function Components.MoneyLabel(parent: Instance, name: string, size: number, overlay: Instance?): MoneyLabel
	local textSize = size
	local fill = color.asphaltDeep
	local root = frame(parent, name, fill)
	root.AutomaticSize = Enum.AutomaticSize.X
	root.Size = UDim2.fromOffset(0, size + 4)
	corner(root, Ui.radius.small)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = root

	local cells: { TextLabel } = {}
	local shown = 0
	local rollToken = 0

	local function draw(amount: number)
		local text = HudRules.formatMoney(amount)
		local count = utf8.len(text) or #text
		while #cells < count do
			local cell = label(root, "Digit", "", {
				face = font.textBold,
				size = textSize,
				align = Enum.TextXAlignment.Center,
			})
			cell.LayoutOrder = #cells + 1
			table.insert(cells, cell)
		end
		local index = 0
		for _, code in utf8.codes(text) do
			index += 1
			local character = utf8.char(code)
			local cell = cells[index]
			cell.Text = character
			cell.Visible = true
			local width = if character == "." then 0.28 else 0.5
			cell.Size = UDim2.fromOffset(math.ceil(textSize * width), textSize + 4)
		end
		for rest = index + 1, #cells do
			cells[rest].Visible = false
		end
	end

	local handle: MoneyLabel = nil :: any
	handle = {
		root = root,
		set = function(amount: number, animate: boolean?)
			rollToken += 1
			local mine = rollToken
			local from = shown
			shown = amount
			if animate ~= true or from == amount then
				draw(amount)
				return
			end
			local started = os.clock()
			local connection: RBXScriptConnection? = nil
			connection = RunService.Heartbeat:Connect(function()
				local alpha = (os.clock() - started) / Ui.motion.moneyRoll
				if mine ~= rollToken or alpha >= 1 then
					if mine == rollToken then
						draw(amount)
					end
					if connection ~= nil then
						connection:Disconnect()
					end
					return
				end
				local eased = 1 - (1 - alpha) ^ 3
				draw(HudRules.rollValue(from, amount, eased))
			end)
		end,
		float = function(delta: number)
			if delta == 0 then
				return
			end
			local host = overlay or (root.Parent :: Instance)
			local tag = frame(host, "MoneyFloat", if delta < 0 then color.signal else color.limestone)
			-- Fuera del taxímetro y por el lado libre de la placa: el disco del avatar ocupa el otro.
			local onLeft = Ui.hudMirror == true
			tag.AnchorPoint = if onLeft then Vector2.new(1, 0.5) else Vector2.new(0, 0.5)
			tag.Position = if onLeft then UDim2.new(0, -8, 0.5, 6) else UDim2.new(1, 8, 0.5, 6)
			tag.AutomaticSize = Enum.AutomaticSize.X
			tag.Size = UDim2.fromOffset(0, 32)
			tag.Rotation = if delta < 0 then 3 else -3
			tag.ZIndex = 60
			corner(tag, 10)
			stroke(tag, color.asphalt, 2)
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 11)
			pad.PaddingRight = UDim.new(0, 11)
			pad.Parent = tag
			local sign = if delta > 0 then "+" else ""
			local text = label(tag, "Amount", sign .. HudRules.formatMoney(delta), {
				face = font.roadBold,
				size = 22,
				tint = if delta < 0 then color.limestone else color.asphalt,
				align = Enum.TextXAlignment.Center,
			})
			text.AutomaticSize = Enum.AutomaticSize.X
			text.Size = UDim2.fromScale(0, 1)
			text.ZIndex = 61
			local rise = if onLeft then UDim2.new(0, -8, 0.5, -18) else UDim2.new(1, 8, 0.5, -18)
			tween(tag, Ui.motion.moneyFloat, { Position = rise })
			task.delay(Ui.motion.moneyFloat * 0.6, function()
				if tag.Parent ~= nil then
					tween(tag, Ui.motion.moneyFloat * 0.4, { BackgroundTransparency = 1 })
					tween(text, Ui.motion.moneyFloat * 0.4, { TextTransparency = 1 })
					-- El contorno se apaga a la vez: si no, se quedaba gris un momento tras la cifra.
					for _, child in tag:GetDescendants() do
						if child:IsA("UIStroke") then
							tween(child, Ui.motion.moneyFloat * 0.4, { Transparency = 1 })
						end
					end
				end
			end)
			task.delay(Ui.motion.moneyFloat, function()
				tag:Destroy()
			end)
		end,
		setFace = function(newSize: number, newFill: Color3)
			textSize = newSize
			fill = newFill
			root.BackgroundColor3 = fill
			root.Size = UDim2.fromOffset(0, newSize + 4)
			for _, cell in cells do
				cell.TextSize = newSize
			end
			draw(shown)
		end,
	}
	draw(0)
	return handle
end

-- Ancho del taxímetro para un importe, con las mismas medidas con las que dibuja sus ventanas.
function moneyWidth(amount: number, size: number): number
	local total = 8
	for _, code in utf8.codes(HudRules.formatMoney(amount)) do
		total += math.ceil(size * (if utf8.char(code) == "." then 0.28 else 0.5))
	end
	return total
end

-- Sello de goma: el rojo de una marca, y los tres pesos de tinta de la rareza. Va torcido: lo puso alguien.
export type StampKind = "Loss" | "Common" | "Rare" | "Legendary"

function Components.Stamp(parent: Instance, text: string, kind: StampKind, size: number?): Frame
	local fill = kind == "Loss" or kind == "Legendary"
	local root = frame(parent, "Stamp", if fill then color.signal else nil)
	root.AutomaticSize = Enum.AutomaticSize.XY
	root.Rotation = if kind == "Common" then 0 elseif kind == "Rare" then -4 else -6
	corner(root, 3)
	local tint = if fill then color.limestone elseif kind == "Rare" then color.navy else color.asphalt
	if not fill then
		stroke(root, tint, if kind == "Rare" then 2 else 1)
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 1)
	pad.PaddingBottom = UDim.new(0, 1)
	pad.Parent = root
	local caption =
		label(root, "Text", Strings.upper(text), { face = font.road, size = size or 12, tint = tint })
	caption.AutomaticSize = Enum.AutomaticSize.XY
	return root
end

-- Disco del avatar: como una señal redonda, con el color del asiento en el aro.
export type Disc = {
	root: Frame,
	set: (data: { tint: Color3, userId: number?, ghost: boolean?, crown: boolean?, bot: boolean? }) -> (),
	setSize: (size: number) -> (),
}

function Components.Disc(parent: Instance): Disc
	-- El aro exterior es hermano y va detrás: un hijo se pintaría encima de la cara.
	local root = frame(parent, "Disc")
	root.ZIndex = 6
	local outer = frame(root, "OuterRing", color.asphalt)
	outer.Position = UDim2.fromOffset(-8, -8)
	outer.Size = UDim2.new(1, 16, 1, 16)
	outer.ZIndex = 5
	round(outer)
	local plate = frame(root, "Face", color.limestone)
	plate.Size = UDim2.fromScale(1, 1)
	plate.ZIndex = 6
	round(plate)
	local aro = stroke(plate, color.limestone, 5)

	local picture = Instance.new("ImageLabel")
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.Size = UDim2.fromScale(1, 1)
	picture.ZIndex = 7
	picture.Parent = root
	round(picture)

	local crown = icon(root, "Crown", "crown")
	crown.AnchorPoint = Vector2.new(0.5, 1)
	crown.Position = UDim2.fromScale(0.52, 0.2)
	crown.Size = UDim2.fromScale(0.72, 0.56)
	crown.Rotation = -14
	crown.ZIndex = 9
	crown.Visible = false

	local antenna = frame(root, "Antenna", color.asphalt)
	antenna.AnchorPoint = Vector2.new(0.5, 1)
	antenna.Position = UDim2.fromScale(0.5, 0.02)
	antenna.Size = UDim2.fromOffset(3, 10)
	antenna.ZIndex = 4
	antenna.Visible = false
	local ball = frame(antenna, "Ball", color.works)
	ball.AnchorPoint = Vector2.new(0.5, 1)
	ball.Position = UDim2.new(0.5, 0, 0, 2)
	ball.Size = UDim2.fromOffset(9, 9)
	ball.ZIndex = 4
	round(ball)
	stroke(ball, color.asphalt, 2)

	return {
		root = root,
		set = function(data)
			aro.Color = data.tint
			plate.BackgroundColor3 = if data.ghost == true then color.steel else color.limestone
			if data.ghost == true then
				picture.Image = UiIcons.ghost
			elseif data.userId ~= nil and data.userId > 0 then
				picture.Image = `rbxthumb://type=AvatarHeadShot&id={data.userId}&w=150&h=150`
			else
				picture.Image = UiIcons.face
			end
			crown.Visible = data.crown == true
			antenna.Visible = data.bot == true
		end,
		setSize = function(size: number)
			root.Size = UDim2.fromOffset(size, size)
		end,
	}
end

-- Barra de Furia: trozos torcidos que se llenan de naranja.
local function furyBar(parent: Instance, value: number, maximum: number): Frame
	local root = frame(parent, "Fury")
	root.Size = UDim2.fromOffset(maximum * 9, 14)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 2)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = root
	for index = 1, maximum do
		local piece = frame(root, `Piece{index}`, if index <= value then color.works else color.limestone)
		piece.BackgroundTransparency = if index <= value then 0 else 0.78
		piece.Size = UDim2.fromOffset(6, 13)
		piece.Rotation = 8
		corner(piece, 2)
	end
	return root
end

-- Placa de un jugador de la mesa. La del turno se convierte en una flecha de esmalte claro que apunta a la
-- ciudad y se mece. El estado se pinta entero con `set`; el dinero rueda solo si cambió.
export type PlayerChipData = {
	name: string,
	cash: number,
	tint: Color3,
	userId: number?,
	isTurn: boolean,
	isGhost: boolean?,
	isBot: boolean?,
	hasLeft: boolean?,
	crown: boolean?,
	traitor: boolean?,
	fury: number?,
	furyMax: number?,
	cards: number?,
	skipTurn: boolean?,
}

export type PlayerChip = {
	root: Frame,
	-- `columnWidth` es el ancho común de la mesa: ver `Components.chipContentWidth`.
	set: (data: PlayerChipData, count: number, columnWidth: number, animate: boolean?) -> (),
	floatMoney: (delta: number) -> (),
	destroy: () -> (),
}

function Components.PlayerChip(parent: Instance, name: string): PlayerChip
	local root = frame(parent, name)
	local plate = Components.Panel(root, "Plate", Ui.radius.plate)
	plate.root.Size = UDim2.fromScale(1, 1)

	-- Chapa de la flecha en tres piezas de la misma imagen: extremo fijo, centro que se estira y punta entera.
	-- La punta nunca se parte: el estirado por filas de `Slice` la cortaba al redondear.
	local arrow = frame(root, "Arrow")
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.ZIndex = 3
	arrow.Visible = false
	-- En espejo (`Ui.hudMirror`) la flecha apunta a la izquierda: cada pieza lee su trozo de imagen al revés
	-- (un `ImageRectSize` negativo voltea la imagen) y la punta pasa al otro extremo.
	local mirrored = Ui.hudMirror == true
	local function arrowPiece(pieceName: string, fromX: number, toX: number): ImageLabel
		local piece = icon(arrow, pieceName, "plate-arrow")
		piece.ScaleType = Enum.ScaleType.Stretch
		if mirrored then
			piece.ImageRectOffset = Vector2.new(toX, 0)
			piece.ImageRectSize = Vector2.new(fromX - toX, Ui.arrowImageHeight)
		else
			piece.ImageRectOffset = Vector2.new(fromX, 0)
			piece.ImageRectSize = Vector2.new(toX - fromX, Ui.arrowImageHeight)
		end
		piece.ZIndex = 3
		return piece
	end
	local arrowCut = Ui.arrowCuts
	local arrowLeft = arrowPiece("Left", 0, arrowCut.left)
	local arrowMiddle = arrowPiece("Middle", arrowCut.left, arrowCut.right)
	local arrowTip = arrowPiece("Tip", arrowCut.right, Ui.arrowImageWidth)

	local content = frame(root, "Content")
	content.Size = UDim2.fromScale(1, 1)
	content.ZIndex = 5

	local nameLabel = label(content, "Name", "", { face = font.roadBold, size = 15 })
	nameLabel.ZIndex = 5
	local money = Components.MoneyLabel(content, "Money", 22, root)
	money.root.ZIndex = 5

	local marks = frame(content, "Marks")
	marks.ZIndex = 5
	local marksLayout = Instance.new("UIListLayout")
	marksLayout.FillDirection = Enum.FillDirection.Horizontal
	marksLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	marksLayout.Padding = UDim.new(0, 6)
	marksLayout.SortOrder = Enum.SortOrder.LayoutOrder
	marksLayout.Parent = marks

	local screw = frame(root, "Screw", color.limestoneDim)
	screw.AnchorPoint = Vector2.new(1, 0)
	screw.Position = UDim2.new(1, -8, 0, 7)
	screw.Size = UDim2.fromOffset(6, 6)
	screw.ZIndex = 5
	round(screw)

	local disc = Components.Disc(root)
	disc.root.AnchorPoint = Vector2.new(0.5, 0.5)

	local sway: Tween? = nil
	local lastCash: number? = nil

	local function markText(text: string, order: number, tint: Color3)
		local item =
			label(marks, `Mark{order}`, Strings.upper(text), { face = font.road, size = 12, tint = tint })
		item.AutomaticSize = Enum.AutomaticSize.X
		item.Size = UDim2.fromScale(0, 1)
		item.LayoutOrder = order
		item.ZIndex = 5
		return item
	end

	return {
		root = root,
		set = function(data: PlayerChipData, count: number, columnWidth: number, animate: boolean?)
			local tier = HudRules.tierFor(count)
			local isArrow = data.isTurn
			local height = if isArrow then tier.arrow else tier.plateHeight
			local width = if isArrow
				then columnWidth + Ui.arrowTipWidth * height / tier.arrow
				else columnWidth
			root.Size = UDim2.fromOffset(width, height)

			local ink = if isArrow then color.asphalt else color.limestone
			plate.root.Visible = not isArrow
			arrow.Visible = isArrow
			if isArrow then
				local unit = height / Ui.arrowImageHeight
				local leftWidth = math.ceil(arrowCut.left * unit)
				local tipWidth = math.ceil((Ui.arrowImageWidth - arrowCut.right) * unit)
				arrowLeft.Size = UDim2.fromOffset(leftWidth, height)
				arrowTip.Size = UDim2.fromOffset(tipWidth, height)
				arrowMiddle.Size = UDim2.new(1, -leftWidth - tipWidth + 2, 0, height)
				if mirrored then
					arrowLeft.AnchorPoint = Vector2.new(1, 0)
					arrowLeft.Position = UDim2.fromScale(1, 0)
					arrowTip.AnchorPoint = Vector2.new(0, 0)
					arrowTip.Position = UDim2.fromScale(0, 0)
					arrowMiddle.Position = UDim2.fromOffset(tipWidth - 1, 0)
				else
					arrowTip.AnchorPoint = Vector2.new(1, 0)
					arrowTip.Position = UDim2.fromScale(1, 0)
					arrowMiddle.Position = UDim2.fromOffset(leftWidth - 1, 0)
				end
			end
			plate.body.BackgroundTransparency = if data.isGhost == true or data.hasLeft == true
				then 0.3
				else 0
			plate.rim.Color = if data.isGhost == true then color.limestoneDim else color.limestone
			screw.Visible = not isArrow

			disc.setSize(tier.disc)
			disc.root.Position = if mirrored then UDim2.new(1, -4, 0.5, 0) else UDim2.new(0, 4, 0.5, 0)
			screw.AnchorPoint = if mirrored then Vector2.new(0, 0) else Vector2.new(1, 0)
			screw.Position = if mirrored then UDim2.fromOffset(8, 7) else UDim2.new(1, -8, 0, 7)
			disc.set({
				tint = data.tint,
				userId = data.userId,
				ghost = data.isGhost,
				crown = data.crown,
				bot = data.isBot,
			})

			local left = tier.disc / 2 + 12
			local nameSize = if isArrow then tier.name + 4 else tier.name
			local moneySize = if isArrow then tier.money + 2 else tier.money
			local gap = if count > Ui.plateTiers.normal.upTo then 1 else 4
			local block = nameSize + 2 + gap + moneySize + 4
			local top = math.floor((height - block) / 2)

			-- En espejo todo se ancla a la derecha, junto al disco: el texto se alinea hacia él.
			nameLabel.Position = if mirrored then UDim2.fromOffset(14, top) else UDim2.fromOffset(left, top)
			nameLabel.Size = UDim2.new(1, -left - 14, 0, nameSize + 2)
			nameLabel.TextXAlignment = if mirrored
				then Enum.TextXAlignment.Right
				else Enum.TextXAlignment.Left
			nameLabel.TextSize = nameSize
			nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
			nameLabel.TextColor3 = ink
			nameLabel.Text = Strings.upper(data.name)

			money.root.AnchorPoint = if mirrored then Vector2.new(1, 0) else Vector2.new(0, 0)
			money.root.Position = if mirrored
				then UDim2.new(1, -left, 0, top + nameSize + 2 + gap)
				else UDim2.fromOffset(left, top + nameSize + 2 + gap)
			money.setFace(moneySize, if isArrow then color.asphalt else color.asphaltDeep)
			money.set(data.cash, animate == true and lastCash ~= nil)
			lastCash = data.cash

			-- Las marcas empiezan donde acaba el taxímetro, que crece con sus cifras.
			marks.AnchorPoint = if mirrored then Vector2.new(1, 0) else Vector2.new(0, 0)
			marksLayout.HorizontalAlignment = if mirrored
				then Enum.HorizontalAlignment.Right
				else Enum.HorizontalAlignment.Left
			marks.Position = if mirrored
				then UDim2.new(1, -(left + moneyWidth(data.cash, moneySize) + 8), 0, top + nameSize + 2 + gap)
				else UDim2.fromOffset(
					left + moneyWidth(data.cash, moneySize) + 8,
					top + nameSize + 2 + gap
				)
			marks.Size = UDim2.new(1, -left - moneyWidth(data.cash, moneySize) - 14, 0, moneySize + 4)
			for _, child in marks:GetChildren() do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			local order = 0
			local function nextOrder(): number
				order += 1
				return order
			end
			if data.traitor == true then
				Components.Stamp(marks, Strings.get("mark.traitor"), "Loss").LayoutOrder = nextOrder()
			end
			if data.fury ~= nil and data.fury > 0 then
				local maximum = data.furyMax or 5
				furyBar(marks, data.fury, maximum).LayoutOrder = nextOrder()
			end
			if data.hasLeft == true then
				markText(Strings.get("mark.left"), nextOrder(), color.limestoneDim)
			end
			if data.isBot == true then
				markText(Strings.get("mark.bot"), nextOrder(), ink)
			end
			if data.skipTurn == true then
				markText(Strings.get("mark.skipTurn"), nextOrder(), ink)
			end
			if data.cards ~= nil and data.cards > 0 then
				local cardIcon = icon(marks, "CardsIcon", "cards", ink)
				cardIcon.Size = UDim2.fromOffset(16, 16)
				cardIcon.LayoutOrder = nextOrder()
				cardIcon.ZIndex = 5
				markText(tostring(data.cards), nextOrder(), ink)
			end

			-- La flecha del turno se mece; las demás, quietas.
			local current = sway
			if isArrow and current == nil then
				local swing = TweenInfo.new(
					Ui.motion.turnSwayPeriod / 2,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.InOut,
					-1,
					true
				)
				root.Rotation = -Ui.motion.turnSwayDegrees
				local started = TweenService:Create(root, swing, { Rotation = Ui.motion.turnSwayDegrees })
				started:Play()
				sway = started
			elseif not isArrow and current then
				current:Cancel()
				sway = nil
				tween(root, Ui.motion.plateShift, { Rotation = 0 })
			end
		end,
		floatMoney = function(delta: number)
			money.float(delta)
		end,
		destroy = function()
			if sway ~= nil then
				sway:Cancel()
			end
			root:Destroy()
		end,
	}
end

-- Ancho que necesita una placa para que todo quepa, sin el relleno que añade la columna. El nombre manda;
-- las marcas son formas compactas al lado del taxímetro. Con esto se calcula el ancho común de la mesa.
function Components.chipContentWidth(data: PlayerChipData, count: number): number
	local tier = HudRules.tierFor(count)
	local left = tier.disc / 2 + 12
	local nameSize = if data.isTurn then tier.name + 4 else tier.name
	local moneySize = if data.isTurn then tier.money + 2 else tier.money
	local bounds = TextService:GetTextSize(
		Strings.upper(data.name),
		nameSize,
		Enum.Font.Oswald,
		Vector2.new(math.huge, math.huge)
	)
	local marks = 0
	if data.traitor == true then
		marks += 64
	end
	if data.fury ~= nil and data.fury > 0 then
		marks += (data.furyMax or 5) * 9 + 6
	end
	if data.isBot == true then
		marks += 28
	end
	if data.hasLeft == true then
		marks += 48
	end
	if data.skipTurn == true then
		marks += 84
	end
	if data.cards ~= nil and data.cards > 0 then
		marks += 34
	end
	local lower = moneyWidth(data.cash, moneySize) + 8 + marks
	return left + math.max(bounds.X * 1.08, lower) + 22
end

-- Letrero de ronda: cuelga de dos cuerdas sobre la calle, arriba al centro.
export type HangingSign = { root: Frame, row: Frame }

function Components.HangingSign(parent: Instance, name: string, width: number): HangingSign
	local root = frame(parent, name)
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, Ui.signTop)
	root.Size = UDim2.fromOffset(width, 54)
	for _, x in { 0.14, 0.86 } do
		local cord = frame(root, "Cord", color.asphalt)
		cord.AnchorPoint = Vector2.new(0.5, 1)
		cord.Position = UDim2.fromScale(x, 0)
		-- Llega hasta el borde de la ventana: de ahí cuelga.
		cord.Size = UDim2.fromOffset(4, Ui.signTop + 4)
	end
	local plate = Components.Panel(root, "Plate", Ui.radius.pill)
	plate.root.Size = UDim2.fromScale(1, 1)
	local row = frame(root, "Row")
	row.Size = UDim2.fromScale(1, 1)
	row.ZIndex = 5
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.Parent = row
	return { root = root, row = row }
end

-- Botones. El principal es la placa amarilla con la librea del taxi, gruesa, que se hunde al pulsarla: uno
-- solo por pantalla. El secundario es una píldora de contorno, nunca amarilla.
export type Button = {
	root: GuiObject,
	setText: (text: string) -> (),
	setEnabled: (enabled: boolean) -> (),
	onActivated: (callback: () -> ()) -> (),
	destroy: () -> (),
}

local function keyCap(parent: Instance, text: string, tint: Color3, ink: Color3): Frame
	local cap = frame(parent, "Key", tint)
	cap.AutomaticSize = Enum.AutomaticSize.X
	cap.Size = UDim2.fromOffset(0, 20)
	corner(cap, 5)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = cap
	local caption = label(
		cap,
		"Text",
		text,
		{ face = font.road, size = 12, tint = ink, align = Enum.TextXAlignment.Center }
	)
	caption.AutomaticSize = Enum.AutomaticSize.X
	caption.Size = UDim2.fromScale(0, 1)
	return cap
end

function Components.PrimaryButton(parent: Instance, name: string, text: string): Button
	local root = Instance.new("TextButton")
	root.Name = name
	root.BackgroundTransparency = 1
	root.AutoButtonColor = false
	root.Text = ""
	root.Parent = parent

	local lip = frame(root, "Lip", color.taxiLip)
	lip.Position = UDim2.fromOffset(0, 8)
	lip.Size = UDim2.new(1, 0, 1, -8)
	corner(lip, Ui.radius.button)
	stroke(lip, color.asphalt, 3)

	-- Un `CanvasGroup` recorta los cuadros con la esquina y gira limpio con el botón.
	local face = Instance.new("CanvasGroup")
	face.Name = "Face"
	face.BorderSizePixel = 0
	face.BackgroundColor3 = color.taxi
	face.Size = UDim2.new(1, 0, 1, -8)
	face.Parent = root
	corner(face, Ui.radius.button)
	local outline = frame(root, "Outline")
	outline.Size = face.Size
	outline.ZIndex = 3
	corner(outline, Ui.radius.button)
	stroke(outline, color.asphalt, 3)

	local checks = frame(face, "Checks")
	checks.AnchorPoint = Vector2.new(0, 1)
	checks.Position = UDim2.fromScale(0, 1)
	checks.Size = UDim2.new(1, 0, 0, 12)
	for column = 0, 40 do
		for row = 0, 1 do
			if (column + row) % 2 == 0 then
				local check = frame(checks, "Check", color.asphalt)
				check.Position = UDim2.fromOffset(column * 6 * 2, row * 6)
				check.Size = UDim2.fromOffset(12, 6)
			end
		end
	end

	local caption = label(face, "Text", text, {
		face = font.shout,
		size = 38,
		tint = color.asphalt,
		align = Enum.TextXAlignment.Center,
	})
	caption.Position = UDim2.fromOffset(0, 3)
	caption.Size = UDim2.new(1, 0, 1, -12)

	local enabled = true
	local listeners: { () -> () } = {}
	local function press(offset: number)
		local goal = UDim2.fromOffset(0, offset)
		tween(face, Ui.motion.press, { Position = goal })
		tween(outline, Ui.motion.press, { Position = goal })
	end

	root.MouseEnter:Connect(function()
		if enabled then
			press(2)
		end
	end)
	root.MouseLeave:Connect(function()
		press(0)
	end)
	root.MouseButton1Down:Connect(function()
		if enabled then
			press(7)
		end
	end)
	root.MouseButton1Up:Connect(function()
		press(0)
	end)
	root.Activated:Connect(function()
		if enabled then
			for _, listener in listeners do
				listener()
			end
		end
	end)

	return {
		root = root,
		setText = function(value: string)
			caption.Text = value
		end,
		setEnabled = function(value: boolean)
			enabled = value
			root.Active = value
			face.GroupTransparency = if value then 0 else 0.45
			lip.BackgroundTransparency = if value then 0 else 0.6
		end,
		onActivated = function(callback: () -> ())
			table.insert(listeners, callback)
		end,
		destroy = function()
			root:Destroy()
		end,
	}
end

function Components.SecondaryButton(
	parent: Instance,
	name: string,
	text: string,
	key: string?,
	iconId: string?
): Button
	local root = Instance.new("TextButton")
	root.Name = name
	root.AutoButtonColor = false
	root.BackgroundColor3 = color.asphalt
	root.BorderSizePixel = 0
	root.Text = ""
	root.Parent = parent
	corner(root, Ui.radius.pill)
	local outline = stroke(root, color.limestone, 2)

	local row = frame(root, "Row")
	row.Size = UDim2.fromScale(1, 1)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = row

	if iconId ~= nil then
		local glyph = icon(row, "Icon", iconId, color.limestone)
		glyph.Size = UDim2.fromOffset(18, 18)
		glyph.LayoutOrder = 1
	end
	local caption = label(row, "Text", Strings.upper(text), { face = font.road, size = 14 })
	caption.AutomaticSize = Enum.AutomaticSize.X
	caption.Size = UDim2.fromScale(0, 1)
	caption.LayoutOrder = 2
	if key ~= nil then
		keyCap(row, key, color.limestone, color.asphalt).LayoutOrder = 3
	end

	local enabled = true
	local listeners: { () -> () } = {}
	root.MouseEnter:Connect(function()
		if enabled then
			tween(root, Ui.motion.press, { BackgroundColor3 = Theme.buttonHot })
		end
	end)
	root.MouseLeave:Connect(function()
		tween(root, Ui.motion.press, { BackgroundColor3 = color.asphalt })
	end)
	root.Activated:Connect(function()
		if enabled then
			for _, listener in listeners do
				listener()
			end
		end
	end)

	return {
		root = root,
		setText = function(value: string)
			caption.Text = Strings.upper(value)
		end,
		setEnabled = function(value: boolean)
			enabled = value
			root.Active = value
			outline.Color = if value then color.limestone else color.steel
			caption.TextColor3 = if value then color.limestone else color.steel
		end,
		onActivated = function(callback: () -> ())
			table.insert(listeners, callback)
		end,
		destroy = function()
			root:Destroy()
		end,
	}
end

-- Cabecera de una chapa: título en mayúsculas de carretera a la izquierda y `reserved` píxeles libres a la
-- derecha para un botón. Devuelve la fila.
function Components.titleRow(
	parent: Instance,
	title: string,
	order: number,
	height: number,
	reserved: number
): Frame
	local row = frame(parent, "TitleRow")
	row.Size = UDim2.new(1, 0, 0, height)
	row.LayoutOrder = order
	local text = label(row, "Title", Strings.upper(title), { face = font.roadBold, size = 22 })
	text.Size = UDim2.new(1, -reserved, 1, 0)
	text.TextYAlignment = Enum.TextYAlignment.Center
	text.TextTruncate = Enum.TextTruncate.AtEnd
	return row
end

-- Texto que crece hacia abajo: un párrafo entero, sin cortarse. Para lo que no cabe en un botón.
function Components.textBlock(
	parent: Instance,
	name: string,
	text: string,
	order: number,
	tint: Color3?
): TextLabel
	local item = label(parent, name, text, { face = font.text, size = 16, tint = tint, wrap = true })
	item.Size = UDim2.fromScale(1, 0)
	item.AutomaticSize = Enum.AutomaticSize.Y
	item.LayoutOrder = order
	return item
end

-- Fila horizontal de botones. Con `height` a cero crece con lo más alto que tenga dentro.
function Components.buttonRow(parent: Instance, name: string, order: number, height: number): Frame
	local row = frame(parent, name)
	if height > 0 then
		row.Size = UDim2.new(1, 0, 0, height)
	else
		row.Size = UDim2.fromScale(1, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
	end
	row.LayoutOrder = order
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	return row
end

-- Acción irreversible: la primera pulsación cambia el texto a «¿Seguro?»; la segunda, dentro del plazo,
-- ejecuta `onConfirm`. Si el plazo vence, el botón vuelve a `idleText`.
function Components.confirmPress(button: Button, idleText: string, onConfirm: () -> ())
	local armed = false
	local token = 0
	button.onActivated(function()
		token += 1
		local mine = token
		if armed then
			armed = false
			button.setText(idleText)
			onConfirm()
			return
		end
		armed = true
		button.setText(Strings.get("action.confirm"))
		task.delay(Ui.confirmSeconds, function()
			if armed and token == mine then
				armed = false
				button.setText(idleText)
			end
		end)
	end)
end

-- Hoja modal: una chapa centrada, con título, botón de cerrar y una lista con scroll. Devuelve la misma
-- forma que `Theme.modal` para que quien la usa no cambie. Sube al abrirse y baja al cerrarse.
local SHEET_PADDING = 16
local SHEET_HEADER = 48
local SHEET_GAP = 8
local SHEET_CHROME = SHEET_PADDING * 2 + SHEET_HEADER + SHEET_GAP

function Components.Sheet(playerGui: Instance, name: string, title: string, displayOrder: number): Theme.Modal
	local gui = Theme.screenGui(playerGui, name, displayOrder)

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.AutoButtonColor = false
	backdrop.BackgroundColor3 = color.asphaltDeep
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Text = ""
	backdrop.Visible = false
	backdrop.Parent = gui

	local plate = Components.Panel(gui, "Sheet", Ui.radius.plate)
	local root = plate.root
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.new(0.9, 0, 0, SHEET_CHROME)
	root.Visible = false
	-- Un marco que no es botón deja pasar el clic al velo, y tocar el fondo de la hoja la cerraría.
	root.Active = true
	Theme.limitWidth(root)

	local inner = frame(plate.body, "Inner")
	inner.Size = UDim2.fromScale(1, 1)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, SHEET_PADDING)
	pad.PaddingBottom = UDim.new(0, SHEET_PADDING)
	pad.PaddingLeft = UDim.new(0, SHEET_PADDING)
	pad.PaddingRight = UDim.new(0, SHEET_PADDING)
	pad.Parent = inner
	local stack = Instance.new("UIListLayout")
	stack.FillDirection = Enum.FillDirection.Vertical
	stack.Padding = UDim.new(0, SHEET_GAP)
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = inner

	local header = Components.titleRow(inner, title, 1, SHEET_HEADER, 158)
	local close =
		Components.SecondaryButton(header, "Close", Strings.get("sheet.close"), Strings.get("sheet.closeKey"))
	close.root.AnchorPoint = Vector2.new(1, 0.5)
	close.root.Position = UDim2.fromScale(1, 0.5)
	close.root.Size = UDim2.fromOffset(150, 44)

	local body = Theme.scrollList(inner, "Body", 2)

	-- `AutomaticSize` no sigue a una lista con scroll que crece (ver `Theme.scrollList`): el alto se fija aquí,
	-- sumando la cabecera y los huecos a lo que mide la lista.
	local function refit()
		root.Size = UDim2.new(0.9, 0, 0, SHEET_CHROME + body.Size.Y.Offset)
	end
	body:GetPropertyChangedSignal("Size"):Connect(refit)
	refit()

	local open = false
	local token = 0
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
			backdrop.Visible = true
			root.Visible = true
			root.Position = risen
			backdrop.BackgroundTransparency = 1
			tween(root, Ui.motion.open, { Position = centered })
			tween(backdrop, Ui.motion.open, { BackgroundTransparency = Ui.sheetVeil })
		else
			tween(root, Ui.motion.close, { Position = risen })
			tween(backdrop, Ui.motion.close, { BackgroundTransparency = 1 })
			task.delay(Ui.motion.close, function()
				-- Si la hoja se volvió a abrir mientras se cerraba, este cierre viejo no la esconde.
				if token == mine and not open then
					backdrop.Visible = false
					root.Visible = false
				end
			end)
		end
	end

	close.onActivated(function()
		setOpen(false)
	end)
	backdrop.MouseButton1Click:Connect(function()
		setOpen(false)
	end)

	return {
		gui = gui,
		panel = inner,
		body = body,
		backdrop = backdrop,
		setOpen = setOpen,
		isOpen = function(): boolean
			return open
		end,
	}
end

-- Opción de una lista de decisión: perks, votos, rivales, cartas. Una chapa con texto que crece hacia abajo,
-- para que una descripción larga nunca se corte.
-- `selected` invierte la chapa: caliza de fondo, texto y filete de asfalto. La marca es de forma y de tono
-- (el filete grueso y el fondo claro), nunca de color: la mano amarilla queda para el botón principal.
function Components.OptionButton(parent: Instance, name: string, text: string, selected: boolean?): Button
	local chosen = selected == true
	local ink = if chosen then color.asphalt else color.limestone
	local resting = if chosen then color.limestone else color.asphalt
	local root = Instance.new("TextButton")
	root.Name = name
	root.AutoButtonColor = false
	root.BackgroundColor3 = resting
	root.BorderSizePixel = 0
	root.FontFace = font.textBold
	root.TextSize = 16
	root.TextColor3 = ink
	root.TextWrapped = true
	root.Text = text
	root.Size = UDim2.fromScale(1, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.Parent = parent
	corner(root, Ui.radius.card)
	local outline = stroke(root, ink, if chosen then 3 else 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 11)
	pad.PaddingBottom = UDim.new(0, 11)
	pad.Parent = root

	local enabled = true
	local listeners: { () -> () } = {}
	-- La elegida no cambia al pasar el ratón: su fondo es el de la chapa invertida.
	root.MouseEnter:Connect(function()
		if enabled and not chosen then
			tween(root, Ui.motion.press, { BackgroundColor3 = Theme.buttonHot })
		end
	end)
	root.MouseLeave:Connect(function()
		tween(root, Ui.motion.press, { BackgroundColor3 = resting })
	end)
	root.Activated:Connect(function()
		if enabled then
			for _, listener in listeners do
				listener()
			end
		end
	end)
	return {
		root = root,
		setText = function(value: string)
			root.Text = value
		end,
		setEnabled = function(value: boolean)
			enabled = value
			root.Active = value
			outline.Color = if value then ink else color.steel
			root.TextColor3 = if value then ink else color.steel
		end,
		onActivated = function(callback: () -> ())
			table.insert(listeners, callback)
		end,
		destroy = function()
			root:Destroy()
		end,
	}
end

-- Escritura de propiedad: cartón con el bloque de zona a sangre, barra de precio y tabla de rentas con el
-- filete rojo que agrupa las tres casas. Va ladeada: es un objeto, no un panel.
export type DeedData = {
	zoneName: string,
	zoneColor: string,
	symbol: string?,
	name: string,
	price: number,
	rents: { { label: string, amount: number } },
	-- Código del pie, como «M-02 · 42»: tamaño del tablero, zona y casilla.
	code: string,
}

local CARD_WIDTH = 262
local DEED_ZONE_HEIGHT = 100
local DEED_PRICE_HEIGHT = 40
local DEED_ROW_HEIGHT = 23
local DEED_RULES_HEIGHT = 50
local DEED_FOOTER_HEIGHT = 22

function Components.Deed(parent: Instance, name: string, data: DeedData): Frame
	local root = frame(parent, name)
	local rulesTop = DEED_ZONE_HEIGHT + DEED_PRICE_HEIGHT + 4 + #data.rents * DEED_ROW_HEIGHT + 8
	root.Size = UDim2.fromOffset(CARD_WIDTH, rulesTop + DEED_RULES_HEIGHT + 8 + DEED_FOOTER_HEIGHT)

	local shadow = frame(root, "Lip", color.asphaltDeep)
	shadow.BackgroundTransparency = 0.5
	shadow.Position = UDim2.fromOffset(0, 7)
	shadow.Size = UDim2.fromScale(1, 1)
	corner(shadow, Ui.radius.card)

	local paper = Instance.new("CanvasGroup")
	paper.Name = "Paper"
	paper.BorderSizePixel = 0
	paper.BackgroundColor3 = color.limestone
	paper.Size = UDim2.fromScale(1, 1)
	paper.Parent = root
	corner(paper, Ui.radius.card)

	local ink = if HudRules.inkFor(data.zoneColor) == "asphalt" then color.asphalt else color.limestone
	local zone = frame(paper, "Zone", Color3.fromHex(data.zoneColor))
	zone.Size = UDim2.new(1, 0, 0, DEED_ZONE_HEIGHT)

	-- El nombre de la zona va en una pestaña de asfalto: se lee igual sobre las doce.
	local tab = frame(zone, "Tab", color.asphalt)
	tab.AutomaticSize = Enum.AutomaticSize.X
	tab.Position = UDim2.fromOffset(12, 12)
	tab.Size = UDim2.fromOffset(0, 20)
	corner(tab, 9)
	local tabPad = Instance.new("UIPadding")
	tabPad.PaddingLeft = UDim.new(0, 8)
	tabPad.PaddingRight = UDim.new(0, 8)
	tabPad.Parent = tab
	local zoneLabel = label(tab, "Name", Strings.upper(data.zoneName), { face = font.road, size = 12 })
	zoneLabel.AutomaticSize = Enum.AutomaticSize.X
	zoneLabel.Size = UDim2.fromScale(0, 1)

	local title = label(
		zone,
		"Title",
		Strings.upper(data.name),
		{ face = font.roadBold, size = 33, tint = ink, wrap = true }
	)
	title.Position = UDim2.fromOffset(12, 38)
	title.Size = UDim2.new(1, -24, 1, -48)
	title.TextYAlignment = Enum.TextYAlignment.Top
	title.LineHeight = 0.95
	-- Un nombre largo baja de tamaño hasta caber en dos líneas dentro de la franja, en vez de perder la
	-- segunda línea por debajo del borde.
	title.TextScaled = true
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = Theme.textSize(33)
	fit.MinTextSize = Ui.text.deedTitleMin
	fit.Parent = title

	if data.symbol ~= nil then
		local glyph = icon(zone, "Symbol", data.symbol, ink)
		glyph.AnchorPoint = Vector2.new(1, 0)
		glyph.Position = UDim2.new(1, -10, 0, 9)
		glyph.Size = UDim2.fromOffset(28, 28)
	end

	local bar = frame(paper, "PriceBar", color.asphalt)
	bar.Position = UDim2.fromOffset(0, DEED_ZONE_HEIGHT)
	bar.Size = UDim2.new(1, 0, 0, DEED_PRICE_HEIGHT)
	local priceCaption =
		label(bar, "Caption", Strings.upper(Strings.get("deed.price")), { face = font.road, size = 12 })
	priceCaption.Position = UDim2.fromOffset(12, 0)
	priceCaption.Size = UDim2.fromScale(0.5, 1)
	local priceValue = label(bar, "Value", HudRules.formatMoney(data.price), {
		face = font.roadBold,
		size = 30,
		align = Enum.TextXAlignment.Right,
	})
	priceValue.AnchorPoint = Vector2.new(1, 0)
	priceValue.Position = UDim2.new(1, -12, 0, 0)
	priceValue.Size = UDim2.fromScale(0.5, 1)

	for index, rent in data.rents do
		local y = DEED_ZONE_HEIGHT + DEED_PRICE_HEIGHT + 4 + (index - 1) * DEED_ROW_HEIGHT
		local isHouse = index >= 2 and index <= 4
		if isHouse then
			local fillet = frame(paper, "Fillet", color.signal)
			fillet.Position = UDim2.fromOffset(0, y + 1)
			fillet.Size = UDim2.fromOffset(3, DEED_ROW_HEIGHT - 2)
		end
		local strong = index >= 5
		local key = label(paper, `Rent{index}`, rent.label, {
			face = if strong then font.textBold else font.text,
			size = 15,
			tint = color.asphalt,
		})
		key.Position = UDim2.fromOffset(12, y)
		key.Size = UDim2.new(0.7, -12, 0, DEED_ROW_HEIGHT)
		local value = label(paper, `Amount{index}`, HudRules.formatMoney(rent.amount), {
			face = font.textBold,
			size = 15,
			tint = color.asphalt,
			align = Enum.TextXAlignment.Right,
		})
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.new(1, -12, 0, y)
		value.Size = UDim2.new(0.3, 0, 0, DEED_ROW_HEIGHT)
	end
	local rule = frame(paper, "Rule", color.asphalt)
	rule.Position = UDim2.fromOffset(12, rulesTop - 5)
	rule.Size = UDim2.new(1, -24, 0, 2)

	-- Las dos reglas que multiplican la renta: también son lo que se paga.
	local rules = frame(paper, "Rules")
	rules.Position = UDim2.fromOffset(12, rulesTop)
	rules.Size = UDim2.new(1, -24, 0, DEED_RULES_HEIGHT)
	corner(rules, Ui.radius.small)
	stroke(rules, color.asphalt, 1)
	for index, key in { "deed.fullZone", "deed.hotZone" } do
		local y = 2 + (index - 1) * 23
		local rowLabel = label(
			rules,
			`Rule{index}`,
			Strings.get(key),
			{ face = font.text, size = 14, tint = color.asphalt }
		)
		rowLabel.Position = UDim2.fromOffset(8, y)
		rowLabel.Size = UDim2.new(1, -44, 0, 23)
		local times = label(rules, `Times{index}`, Strings.get("deed.double"), {
			face = font.textBold,
			size = 15,
			tint = color.signal,
			align = Enum.TextXAlignment.Right,
		})
		times.AnchorPoint = Vector2.new(1, 0)
		times.Position = UDim2.new(1, -8, 0, y)
		times.Size = UDim2.fromOffset(30, 23)
	end

	local footer = frame(paper, "Footer", color.asphalt)
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.Size = UDim2.new(1, 0, 0, DEED_FOOTER_HEIGHT)
	local kind =
		label(footer, "Kind", Strings.upper(Strings.get("deed.footer")), { face = font.road, size = 12 })
	kind.Position = UDim2.fromOffset(12, 0)
	kind.Size = UDim2.fromScale(0.5, 1)
	local code =
		label(footer, "Code", data.code, { face = font.road, size = 12, align = Enum.TextXAlignment.Right })
	code.AnchorPoint = Vector2.new(1, 0)
	code.Position = UDim2.new(1, -12, 0, 0)
	code.Size = UDim2.fromScale(0.5, 1)

	local edge = frame(root, "Edge")
	edge.Size = UDim2.fromScale(1, 1)
	edge.ZIndex = 3
	corner(edge, Ui.radius.card)
	stroke(edge, color.asphalt, 3)

	return root
end

-- Naipe de la mano: papel caliza, nombre y sello. El abanico lo compone quien lo usa.
--
-- Con arte, la ilustración ES la carta: el PNG ya trae el marco y el sello de la rareza, y el nombre se
-- escribe sobre su banda de caliza. Sin arte se queda el naipe de papel de siempre, para que la mano se
-- lea igual mientras las imágenes no estén subidas.
function Components.Card(
	parent: Instance,
	name: string,
	title: string,
	rarity: StampKind,
	rarityText: string,
	cardId: string?
): Frame
	local asset = CardArt.image(if cardId ~= nil then CardArt.card(cardId) else nil)
	if asset ~= "" then
		local art = frame(parent, name)
		art.Size = UDim2.fromOffset(104, 150)
		local picture = Instance.new("ImageLabel")
		picture.Name = "Picture"
		picture.BackgroundTransparency = 1
		picture.BorderSizePixel = 0
		picture.Image = asset
		picture.ScaleType = Enum.ScaleType.Fit
		picture.Size = UDim2.fromScale(1, 1)
		picture.Parent = art
		local band = CardArt.band
		local nameLabel = label(art, "Name", title, {
			face = font.roadBold,
			size = Ui.cardArt.nameSize,
			tint = color.asphalt,
			wrap = true,
			align = Enum.TextXAlignment.Center,
		})
		nameLabel.Position = UDim2.fromScale(band.left, band.top)
		nameLabel.Size = UDim2.fromScale(band.width, band.height)
		nameLabel.TextYAlignment = Enum.TextYAlignment.Center
		-- Un nombre largo como «Ladrón de Escrituras» no cabe a 15 px en 100 de ancho: se encoge solo
		-- hasta el mínimo legible, en vez de salirse de la banda.
		nameLabel.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MinTextSize = Ui.cardArt.nameMinSize
		limit.MaxTextSize = Ui.cardArt.nameSize
		limit.Parent = nameLabel
		return art
	end

	local root = frame(parent, name, color.limestone)
	root.Size = UDim2.fromOffset(104, 150)
	corner(root, Ui.radius.card - 3)
	stroke(root, color.asphalt, 3)
	local titleLabel = label(root, "Title", Strings.upper(title), {
		face = font.road,
		size = 13,
		tint = color.asphalt,
		wrap = true,
	})
	titleLabel.Position = UDim2.fromOffset(8, 7)
	titleLabel.Size = UDim2.new(1, -16, 0, 30)
	titleLabel.TextYAlignment = Enum.TextYAlignment.Top
	local seal = Components.Stamp(root, rarityText, rarity, 12)
	seal.Position = UDim2.fromOffset(8, 40)
	return root
end

-- Calzada del plazo: cruza el pie de la pantalla. El vehículo del turno se come los trazos naranjas hasta
-- llegar al cono; en los últimos segundos, los trazos y la cifra avisan.
export type Timer = {
	root: Frame,
	set: (remaining: number?, total: number?) -> (),
	destroy: () -> (),
}

function Components.Timer(parent: Instance, name: string): Timer
	local root = frame(parent, name, color.asphalt)
	root.AnchorPoint = Vector2.new(0, 1)
	root.Position = UDim2.fromScale(0, 1)
	root.Size = UDim2.new(1, 0, 0, Ui.roadHeight)

	local curb = frame(root, "Curb", color.limestone)
	curb.Size = UDim2.new(1, 0, 0, 4)

	local lane = frame(root, "Lane")
	lane.Position = UDim2.fromOffset(20, 0)
	lane.Size = UDim2.new(1, -100, 1, 0)

	local dashes: { Frame } = {}
	local period = Ui.dashLength + Ui.dashGap

	local vehicle = icon(root, "Vehicle", "taxi-side")
	vehicle.AnchorPoint = Vector2.new(0.5, 1)
	vehicle.Size = UDim2.fromOffset(66, 36)
	vehicle.ZIndex = 3

	local cone = icon(root, "Cone", "cone")
	cone.AnchorPoint = Vector2.new(1, 1)
	cone.Position = UDim2.new(1, -66, 1, -6)
	cone.Size = UDim2.fromOffset(38, 44)
	cone.ZIndex = 3

	local seconds = label(root, "Seconds", "", {
		face = font.roadBold,
		size = 22,
		align = Enum.TextXAlignment.Right,
	})
	seconds.AnchorPoint = Vector2.new(1, 0)
	seconds.Position = UDim2.new(1, -14, 0, 4)
	seconds.Size = UDim2.fromOffset(52, 30)

	local function layoutDashes(): number
		local width = lane.AbsoluteSize.X
		local needed = math.max(1, math.floor(width / period))
		while #dashes < needed do
			local dash = frame(lane, "Dash", color.works)
			dash.AnchorPoint = Vector2.new(0, 0.5)
			dash.Position = UDim2.new(0, #dashes * period, 0.5, 2)
			dash.Size = UDim2.fromOffset(Ui.dashLength, 7)
			round(dash)
			table.insert(dashes, dash)
		end
		return needed
	end

	return {
		root = root,
		set = function(remaining: number?, total: number?)
			root.Visible = remaining ~= nil and total ~= nil
			if remaining == nil or total == nil then
				return
			end
			local state = HudRules.deadline(remaining, total)
			local count = layoutDashes()
			local eaten = state.progress * count
			for index, dash in dashes do
				if index <= eaten then
					-- Pintura ya gastada: se hunde en el asfalto, sin velo.
					dash.BackgroundColor3 = color.asphaltDeep
					dash.BackgroundTransparency = 0
				else
					dash.BackgroundColor3 = if state.warn then color.signal else color.works
					dash.BackgroundTransparency = 0
				end
			end
			vehicle.Position = UDim2.new(0, 20 + state.progress * lane.AbsoluteSize.X, 1, -6)
			seconds.Text = Strings.get("hud.seconds", { seconds = state.seconds })
			seconds.TextColor3 = if state.warn then color.works else color.limestone
		end,
		destroy = function()
			root:Destroy()
		end,
	}
end

return Components

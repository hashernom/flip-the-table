--!strict
-- Maqueta de lujo de la vista general. El plinto (madera, latón y cristal ahumado) se construye una vez
-- y se reutiliza; encima va una copia en miniatura de la ciudad, que es `city.model` clonado y escalado,
-- no una ciudad dibujada a mano. Sobre cada propiedad con dueño, una tarjeta; sobre cada casilla
-- ocupada, el marcador de su asiento.
--
-- La escala, la colocación del plinto y lo que dice cada tarjeta salen de `ModelCityRules`, que es puro
-- y se prueba con Lune. Aquí solo se convierten en `Instance`. La cámara y el botón son de `Overview` y
-- `main.client`: esta maqueta solo aparece y desaparece, y `hide` la aparca sin dejar instancias sueltas.
local Workspace = game:GetService("Workspace")

local CityBuilder = require("./CityBuilder")
local CityLayout = require("../../shared/config/CityLayout")
local ModelCityRules = require("./ModelCityRules")
local ViewText = require("../ui/ViewText")

type CityHandles = CityBuilder.CityHandles
type Names = ViewText.Names
type Plinth = ModelCityRules.Plinth
type CardData = ModelCityRules.Card
type Marker = ModelCityRules.Marker

local ROOT_NAME = "ModelCity"
local PLINTH_NAME = "Plinth"
local MINIATURE_NAME = "Miniature"
local CARDS_NAME = "Cards"
local MARKERS_NAME = "Markers"

-- Paleta de la maqueta. La madera y el latón son de exposición; el cristal ahumado deja ver la ciudad
-- desde abajo sin teñirla del todo.
local WOOD_DARK = Color3.fromRGB(54, 34, 22)
local WOOD = Color3.fromRGB(92, 60, 38)
local BRASS = Color3.fromRGB(198, 162, 86)
local BRASS_DARK = Color3.fromRGB(138, 108, 52)
local GLASS_COLOR = Color3.fromRGB(34, 38, 44)
local CREAM = Color3.fromRGB(244, 234, 212)
local MUTED_CREAM = Color3.fromRGB(214, 198, 164)

-- Medidas del plinto, en studs del mundo. La altura total la fija `ModelCityRules`; aquí solo se
-- reparte entre la base, el cuerpo y la tapa.
local BASE_HEIGHT = 4
local BODY_INSET = 4
local DECK_INSET = 2
local DECK_HEIGHT = 2
local DECK_FRAME = 7
local GLASS_THICKNESS = 0.4
local BAND_HEIGHT = 0.8
local LIP_HEIGHT = 0.5
local LIP_WIDTH = 1
local PLAQUE_LENGTH = 90
local PLAQUE_HEIGHT = 8
local PLAQUE_BACK = 0.8
local PLAQUE_GLASS = 0.5
-- Cuánto entra el cristal de la placa por cada lado: en ese canto de latón van los remaches.
local PLAQUE_INSET = 5
local PLAQUE_EDGE = 2
local RIVET_LENGTH = 0.6
local RIVET_DIAMETER = 1.1
local PIXELS_PER_STUD = 16

-- Tarjeta sobre cada propiedad. Va en píxeles, no en studs: tiene que leerse igual con la maqueta
-- grande o pequeña en pantalla, que es para lo que sirve la vista general.
local CARD_SIZE = UDim2.fromOffset(96, 34)
local CARD_LIFT = 3
local CARD_BG = Color3.fromRGB(18, 20, 24)
local CARD_TEXT = Color3.fromRGB(240, 232, 214)
local CARD_DETAIL = Color3.fromRGB(232, 202, 132)

-- Marcador de asiento: una peana de latón y una bola del color de la ficha, del tamaño de una ficha
-- escalada para que las ocho quepan en su casilla sin pisarse.
local MARKER_BASE_RATIO = 2
local MARKER_BALL_RATIO = 0.85

-- Altura a la que se mira la maqueta desde la cámara, sobre la cara del plinto.
local FOCUS_LIFT = 14

type CardHandle = {
	anchor: Part,
	name: TextLabel,
	detail: TextLabel,
	stripe: Frame,
}

local root: Model? = nil
local miniature: Model? = nil
local plinth: Plinth? = nil
local builtSize: ModelCityRules.SizeId? = nil
-- Ciudad exacta de la que se copió la miniatura, y resumen con el que se decidió volver a copiarla.
local builtFrom: Model? = nil
local builtKey: string? = nil
local cards: { [number]: CardHandle } = {}
local lastCards: { [number]: CardData }? = nil
local markersKey: string? = nil
local plaqueEffects: { TextLabel } = {}
local open = false
local lastView: any = nil
local lastNames: Names? = nil

local ModelCity = {}

local function makePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = true
	piece.Material = material
	piece.Color = color
	piece.Size = size
	piece.CFrame = cframe
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

local function makeLabel(name: string, font: Enum.Font, color: Color3, maxSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = ""
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize
	limit.Parent = label
	return label
end

-- Centro del plinto en su cara superior. Todo lo que se apoya en él se mide desde aquí.
local function deckCenter(geometry: Plinth): Vector3
	return Vector3.new(geometry.center.x, geometry.deckY, geometry.center.z)
end

-- Una placa de latón con su cristal ahumado, el nombre de la ciudad y, debajo, sus efectos. Devuelve la
-- etiqueta de los efectos: el nombre no cambia y se escribe una sola vez.
local function buildPlaque(
	geometry: Plinth,
	normal: Vector3,
	bodyHalf: number,
	bodyCenterY: number,
	parent: Instance
): TextLabel
	local tangent = Vector3.new(-normal.Z, 0, normal.X)
	local origin = Vector3.new(geometry.center.x, bodyCenterY, geometry.center.z)
	local function face(depth: number): CFrame
		local position = origin + normal * (bodyHalf + depth)
		return CFrame.lookAt(position, position + normal)
	end

	local back = makePart(
		"PlaqueBack",
		Vector3.new(PLAQUE_LENGTH, PLAQUE_HEIGHT, PLAQUE_BACK),
		face(PLAQUE_BACK / 2),
		BRASS_DARK,
		Enum.Material.Metal,
		parent
	)
	back.Reflectance = 0.12

	local glass = makePart(
		"PlaqueGlass",
		Vector3.new(PLAQUE_LENGTH - 2 * PLAQUE_INSET, PLAQUE_HEIGHT - 2 * PLAQUE_EDGE, PLAQUE_GLASS),
		face(PLAQUE_BACK + PLAQUE_GLASS / 2),
		GLASS_COLOR,
		Enum.Material.Glass,
		parent
	)
	glass.Transparency = 0.2
	glass.Reflectance = 0.1
	glass.CastShadow = false

	-- Remaches en el canto de latón que deja el cristal al entrar.
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local along = corner[1] * (PLAQUE_LENGTH / 2 - 2.5)
		local up = corner[2] * (PLAQUE_HEIGHT / 2 - 1.25)
		local position = origin
			+ normal * (bodyHalf + PLAQUE_BACK + RIVET_LENGTH / 2)
			+ tangent * along
			+ Vector3.new(0, up, 0)
		local rivet = makePart(
			"Rivet",
			Vector3.new(RIVET_LENGTH, RIVET_DIAMETER, RIVET_DIAMETER),
			CFrame.fromMatrix(position, normal, Vector3.yAxis),
			BRASS,
			Enum.Material.Metal,
			parent
		)
		rivet.Shape = Enum.PartType.Cylinder
	end

	local surface = Instance.new("SurfaceGui")
	surface.Name = "Label"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surface.CanvasSize = Vector2.new(PLAQUE_LENGTH - 2 * PLAQUE_INSET, PLAQUE_HEIGHT - 2 * PLAQUE_EDGE)
		* PIXELS_PER_STUD
	surface.LightInfluence = 0.2
	surface.Parent = glass

	local title = makeLabel("Name", Enum.Font.GothamBold, CREAM, 34)
	title.Size = UDim2.fromScale(0.9, 0.56)
	title.Position = UDim2.fromScale(0.05, 0.04)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextStrokeColor3 = Color3.fromRGB(20, 12, 4)
	title.TextStrokeTransparency = 0.5
	title.Text = ModelCityRules.CITY_NAME
	title.Parent = surface

	local effect = makeLabel("Effect", Enum.Font.GothamMedium, MUTED_CREAM, 20)
	effect.Size = UDim2.fromScale(0.9, 0.3)
	effect.Position = UDim2.fromScale(0.05, 0.62)
	effect.TextXAlignment = Enum.TextXAlignment.Center
	effect.Parent = surface

	return effect
end

-- El plinto: base de madera, canto de latón, tapa con marco y cristal, y cuatro placas iguales para que
-- el nombre se lea desde cualquier lado al girar la vista general. Devuelve las etiquetas de efectos.
local function buildPlinth(geometry: Plinth, parent: Instance): { TextLabel }
	local center = deckCenter(geometry)
	local bodyHeight = geometry.height - BASE_HEIGHT - DECK_HEIGHT
	local bodyWidth = geometry.width - 2 * BODY_INSET
	local bodyDepth = geometry.depth - 2 * BODY_INSET
	local bodyHalf = bodyWidth / 2
	local bodyCenterY = geometry.baseY + BASE_HEIGHT + bodyHeight / 2

	makePart(
		"Base",
		Vector3.new(geometry.width, BASE_HEIGHT, geometry.depth),
		CFrame.new(geometry.center.x, geometry.baseY + BASE_HEIGHT / 2, geometry.center.z),
		WOOD_DARK,
		Enum.Material.WoodPlanks,
		parent
	)
	makePart(
		"Body",
		Vector3.new(bodyWidth, bodyHeight, bodyDepth),
		CFrame.new(geometry.center.x, bodyCenterY, geometry.center.z),
		WOOD,
		Enum.Material.Wood,
		parent
	)
	local band = makePart(
		"BrassBand",
		Vector3.new(geometry.width - 2, BAND_HEIGHT, geometry.depth - 2),
		CFrame.new(geometry.center.x, geometry.baseY + BASE_HEIGHT, geometry.center.z),
		BRASS,
		Enum.Material.Metal,
		parent
	)
	band.Reflectance = 0.18

	-- Una luz cálida dentro del plinto: ilumina el cristal y la ciudad desde abajo, como una vitrina.
	local glow = Instance.new("PointLight")
	glow.Name = "PlinthGlow"
	glow.Color = BRASS
	glow.Brightness = 0.7
	glow.Range = 30
	glow.Shadows = false
	glow.Parent = band

	-- Tapa: cuatro listones de madera con un cristal ahumado en el hueco.
	local deckOuter = geometry.width - 2 * DECK_INSET
	local deckCenterY = geometry.deckY - DECK_HEIGHT / 2
	local barOffset = deckOuter / 2 - DECK_FRAME / 2
	local opening = deckOuter - 2 * DECK_FRAME
	for _, spot in
		{
			{
				name = "DeckFront",
				offset = Vector3.new(0, 0, barOffset),
				size = Vector3.new(deckOuter, DECK_HEIGHT, DECK_FRAME),
			},
			{
				name = "DeckBack",
				offset = Vector3.new(0, 0, -barOffset),
				size = Vector3.new(deckOuter, DECK_HEIGHT, DECK_FRAME),
			},
			{
				name = "DeckLeft",
				offset = Vector3.new(-barOffset, 0, 0),
				size = Vector3.new(DECK_FRAME, DECK_HEIGHT, opening),
			},
			{
				name = "DeckRight",
				offset = Vector3.new(barOffset, 0, 0),
				size = Vector3.new(DECK_FRAME, DECK_HEIGHT, opening),
			},
		}
	do
		makePart(
			spot.name,
			spot.size,
			CFrame.new(center.X, deckCenterY, center.Z) + spot.offset,
			WOOD,
			Enum.Material.Wood,
			parent
		)
	end

	local glass = makePart(
		"GlassTop",
		Vector3.new(opening, GLASS_THICKNESS, opening),
		CFrame.new(center.X, geometry.deckY - GLASS_THICKNESS / 2, center.Z),
		GLASS_COLOR,
		Enum.Material.Glass,
		parent
	)
	glass.Transparency = 0.35
	glass.Reflectance = 0.12
	glass.CastShadow = false

	-- Borde de latón del cristal: la miniatura queda dentro de una bandeja.
	local lipOffset = opening / 2 + LIP_WIDTH / 2
	local lipY = geometry.deckY + LIP_HEIGHT / 2
	for _, spot in
		{
			{
				name = "LipFront",
				offset = Vector3.new(0, 0, lipOffset),
				size = Vector3.new(opening + 2 * LIP_WIDTH, LIP_HEIGHT, LIP_WIDTH),
			},
			{
				name = "LipBack",
				offset = Vector3.new(0, 0, -lipOffset),
				size = Vector3.new(opening + 2 * LIP_WIDTH, LIP_HEIGHT, LIP_WIDTH),
			},
			{
				name = "LipLeft",
				offset = Vector3.new(-lipOffset, 0, 0),
				size = Vector3.new(LIP_WIDTH, LIP_HEIGHT, opening),
			},
			{
				name = "LipRight",
				offset = Vector3.new(lipOffset, 0, 0),
				size = Vector3.new(LIP_WIDTH, LIP_HEIGHT, opening),
			},
		}
	do
		local lip = makePart(
			spot.name,
			spot.size,
			CFrame.new(center.X, lipY, center.Z) + spot.offset,
			BRASS,
			Enum.Material.Metal,
			parent
		)
		lip.Reflectance = 0.2
	end

	local effects: { TextLabel } = {}
	for _, normal in { Vector3.zAxis, -Vector3.zAxis, Vector3.xAxis, -Vector3.xAxis } do
		table.insert(effects, buildPlaque(geometry, normal, bodyHalf, bodyCenterY, parent))
	end
	return effects
end

local function findFolder(name: string): Folder?
	local current = root
	if current == nil then
		return nil
	end
	local folder = current:FindFirstChild(name)
	if folder ~= nil and folder:IsA("Folder") then
		return folder
	end
	return nil
end

-- Color de un asiento: el de la franja de su ficha si ya existe, para no repetir la paleta de
-- `main.client`; si no, el de respaldo de `ModelCityRules`.
local function tokenColor(city: CityHandles, id: string): Color3?
	local token = city.tokens:FindFirstChild(`Token_{id}`)
	if token == nil then
		return nil
	end
	local stripe = token:FindFirstChild("Stripe")
	if stripe ~= nil and stripe:IsA("BasePart") then
		return stripe.Color
	end
	return nil
end

local function cardColor(city: CityHandles, card: CardData): Color3
	return tokenColor(city, card.ownerId) or Color3.fromHex(card.color)
end

local function markerColor(city: CityHandles, marker: Marker): Color3
	return tokenColor(city, marker.id) or Color3.fromHex(marker.color)
end

-- Sitio de la tarjeta: encima del edificio de la propiedad en la miniatura. Si el edificio aún no tiene
-- piezas, se usa la altura de un solar con su edificio gris.
local function cardPosition(city: CityHandles, index: number, geometry: Plinth): Vector3
	local current = miniature
	if current ~= nil then
		local building = current:FindFirstChild(`Building{index}`)
		if building ~= nil and building:IsA("Model") then
			local hasParts = false
			for _, descendant in building:GetDescendants() do
				if descendant:IsA("BasePart") then
					hasParts = true
					break
				end
			end
			if hasParts then
				local boxCFrame, boxSize = building:GetBoundingBox()
				return Vector3.new(boxCFrame.X, boxCFrame.Y + boxSize.Y / 2 + CARD_LIFT, boxCFrame.Z)
			end
		end
	end
	local lot = city.lotOf(index)
	local point = ModelCityRules.modelPoint(geometry, lot.Position.X, 30, lot.Position.Z)
	return Vector3.new(point.x, point.y + CARD_LIFT, point.z)
end

local function updateCard(handle: CardHandle, card: CardData, color: Color3)
	handle.name.Text = card.name
	handle.detail.Text = card.detail
	handle.stripe.BackgroundColor3 = color
end

local function buildCard(card: CardData, color: Color3, position: Vector3, parent: Instance): CardHandle
	local anchor = Instance.new("Part")
	anchor.Name = `CardAnchor{card.index}`
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = parent

	local gui = Instance.new("BillboardGui")
	gui.Name = `Card{card.index}`
	gui.Adornee = anchor
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 4096
	gui.Size = CARD_SIZE
	gui.Parent = anchor

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = CARD_BG
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = BRASS
	stroke.Thickness = 2
	stroke.Transparency = 0.15
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = panel

	local stripe = Instance.new("Frame")
	stripe.Name = "Seat"
	stripe.Size = UDim2.fromScale(0.04, 1)
	stripe.BackgroundColor3 = color
	stripe.BorderSizePixel = 0
	stripe.Parent = panel
	local stripeCorner = Instance.new("UICorner")
	stripeCorner.CornerRadius = UDim.new(0, 8)
	stripeCorner.Parent = stripe

	local name = makeLabel("Owner", Enum.Font.GothamBold, CARD_TEXT, 24)
	name.Size = UDim2.fromScale(0.85, 0.46)
	name.Position = UDim2.fromScale(0.08, 0.08)
	name.Parent = panel

	local detail = makeLabel("Detail", Enum.Font.GothamMedium, CARD_DETAIL, 18)
	detail.Size = UDim2.fromScale(0.85, 0.34)
	detail.Position = UDim2.fromScale(0.08, 0.55)
	detail.Parent = panel

	local handle: CardHandle = {
		anchor = anchor,
		name = name,
		detail = detail,
		stripe = stripe,
	}
	updateCard(handle, card, color)
	return handle
end

-- Destruye las tarjetas y olvida el estado anterior: sus anclajes cuelgan de la miniatura y dejan de
-- valer en cuanto se vuelve a copiar la ciudad.
local function clearCards()
	for index, handle in cards do
		handle.anchor:Destroy()
		cards[index] = nil
	end
	cards = {}
	lastCards = nil
end

local function ensureCards(city: CityHandles, view: any, names: Names?, geometry: Plinth)
	local folder = findFolder(CARDS_NAME)
	if folder == nil then
		return
	end
	local current = ModelCityRules.cards(view, names)
	local changes = ModelCityRules.cardDiff(lastCards, current)
	for _, index in changes.removed do
		local handle = cards[index]
		if handle ~= nil then
			handle.anchor:Destroy()
			cards[index] = nil
		end
	end
	for _, card in changes.changed do
		local handle = cards[card.index]
		if handle ~= nil then
			updateCard(handle, card, cardColor(city, card))
		end
	end
	for _, card in changes.added do
		cards[card.index] =
			buildCard(card, cardColor(city, card), cardPosition(city, card.index, geometry), folder)
	end
	lastCards = current
end

local function buildMarker(
	city: CityHandles,
	marker: Marker,
	slot: CityLayout.Slot,
	geometry: Plinth,
	parent: Instance
)
	local forward = Vector3.new(math.sin(slot.facing), 0, math.cos(slot.facing))
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local x = slot.position.x + right.X * marker.side + forward.X * marker.along
	local z = slot.position.z + right.Z * marker.side + forward.Z * marker.along
	local point = ModelCityRules.modelPoint(geometry, x, 0, z)
	local color = markerColor(city, marker)
	local diameter = CityLayout.TOKEN_BASE_STUDS * geometry.scale
	local baseHeight = math.max(0.5, MARKER_BASE_RATIO * geometry.scale)
	local ballSize = diameter * MARKER_BALL_RATIO

	local model = Instance.new("Model")
	model.Name = `Marker_{marker.id}`
	local base = makePart(
		"Base",
		Vector3.new(baseHeight, diameter, diameter),
		CFrame.new(point.x, point.y + baseHeight / 2, point.z) * CFrame.Angles(0, 0, math.pi / 2),
		BRASS_DARK,
		Enum.Material.Metal,
		model
	)
	base.Reflectance = 0.15
	base.Shape = Enum.PartType.Cylinder
	local ball = makePart(
		"Ball",
		Vector3.new(ballSize, ballSize, ballSize),
		CFrame.new(point.x, point.y + baseHeight + ballSize / 2 - 0.15, point.z),
		color,
		Enum.Material.SmoothPlastic,
		model
	)
	ball.Shape = Enum.PartType.Ball
	model.Parent = parent
end

local function ensureMarkers(city: CityHandles, view: any, geometry: Plinth)
	local folder = findFolder(MARKERS_NAME)
	if folder == nil then
		return
	end
	local markers = ModelCityRules.markers(view)
	local keyParts: { string } = {}
	for _, marker in markers do
		table.insert(keyParts, `{marker.id}:{marker.seat}:{marker.square}`)
	end
	table.sort(keyParts)
	local key = table.concat(keyParts, ",")
	if key == markersKey then
		return
	end
	for _, child in folder:GetChildren() do
		child:Destroy()
	end
	local route = CityLayout.routeFor(city.sizeId)
	for _, marker in markers do
		local slot = route[marker.square]
		if slot ~= nil then
			buildMarker(city, marker, slot, geometry, folder)
		end
	end
	markersKey = key
end

-- Resumen de lo que se ve en la ciudad. La miniatura se vuelve a copiar solo si cambió: dueños,
-- niveles, Zona Caliente o el número de piezas (arte que acaba de cargar).
local function cityKey(city: CityHandles, view: any): string
	local props: { string } = {}
	for index, property in view.properties or {} do
		table.insert(props, `{index}:{property.ownerId or ""}:{property.level}`)
	end
	table.sort(props)
	return `{#city.model:GetDescendants()}|{table.concat(props, ",")}|{tostring(view.hotZoneId)}`
end

-- Copia la ciudad, la escala y la apoya en el cristal. Se quitan las fichas reales y las etiquetas de
-- pantalla del clon: la maqueta pone las suyas, y un `BillboardGui` clonado se vería gigante.
local function ensureMiniature(city: CityHandles, view: any, geometry: Plinth)
	local key = cityKey(city, view)
	if miniature ~= nil and builtKey == key and builtFrom == city.model then
		return
	end
	if miniature ~= nil then
		miniature:Destroy()
		miniature = nil
	end
	clearCards()

	local clone = city.model:Clone()
	clone.Name = MINIATURE_NAME
	local tokens = clone:FindFirstChild("Tokens")
	if tokens ~= nil then
		tokens:Destroy()
	end
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BillboardGui") or descendant:IsA("Highlight") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end

	clone:ScaleTo(geometry.scale)
	-- Se apoya por la caja real, no por el pivote: así el fondo de la losa queda sobre el cristal y la
	-- ciudad centrada en el plinto, sea cual sea el pivote que traiga el modelo.
	local boxCFrame, boxSize = clone:GetBoundingBox()
	local deck = deckCenter(geometry)
	local delta = Vector3.new(
		deck.X - boxCFrame.Position.X,
		geometry.deckY - (boxCFrame.Position.Y - boxSize.Y / 2),
		deck.Z - boxCFrame.Position.Z
	)
	clone:PivotTo(clone:GetPivot() + delta)
	local current = root
	if current == nil then
		clone:Destroy()
		return
	end
	clone.Parent = current
	miniature = clone
	builtKey = key
	builtFrom = city.model
end

local function updatePlaques(view: any)
	local effect = ModelCityRules.plaque(view).effect
	for _, label in plaqueEffects do
		label.Text = effect or ""
	end
end

local function buildRoot(geometry: Plinth): Model
	local model = Instance.new("Model")
	model.Name = ROOT_NAME
	local board = Instance.new("Model")
	board.Name = PLINTH_NAME
	board.Parent = model
	plaqueEffects = buildPlinth(geometry, board)
	for _, name in { CARDS_NAME, MARKERS_NAME } do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = model
	end
	return model
end

local function showNow(city: CityHandles, view: any, names: Names?)
	local sizeId: ModelCityRules.SizeId = city.sizeId
	local geometry = ModelCityRules.plinthFor(sizeId)
	if root == nil or builtSize ~= sizeId then
		ModelCity.destroy()
		root = buildRoot(geometry)
		builtSize = sizeId
	end
	plinth = geometry
	ensureMiniature(city, view, geometry)
	ensureCards(city, view, names, geometry)
	ensureMarkers(city, view, geometry)
	updatePlaques(view)
	local current = root
	if current ~= nil then
		current.Parent = Workspace
	end
	open = true
	lastView = view
	lastNames = names
end

-- Monta o actualiza la maqueta y la enseña. Es idempotente: si la vista no cambió, no hace nada.
function ModelCity.show(city: CityBuilder.CityHandles, view: any, names: ViewText.Names?)
	if city == nil or view == nil then
		return
	end
	if open and root ~= nil and root.Parent ~= nil and lastView == view and lastNames == names then
		return
	end
	local ok: boolean, err: any = pcall(showNow, city, view, names)
	if not ok then
		warn(`ModelCity: no se pudo montar la maqueta: {err}`)
	end
end

-- La aparca sin destruirla: la siguiente apertura reaprovecha plinto, miniatura y tarjetas. No deja
-- instancias sueltas porque todo cuelga de un único `Model` raíz.
function ModelCity.hide()
	local current = root
	if current ~= nil then
		current.Parent = nil
	end
	open = false
	lastView = nil
	lastNames = nil
end

function ModelCity.isOpen(): boolean
	return open and root ~= nil and root.Parent ~= nil
end

-- Libera la maqueta. `hide` basta para cerrarla; esto es para cuando la ciudad desaparece (revancha o
-- cambio de tamaño) y no se va a volver a abrir la misma.
function ModelCity.destroy()
	local current = root
	if current ~= nil then
		current:Destroy()
	end
	root = nil
	miniature = nil
	plinth = nil
	builtSize = nil
	builtFrom = nil
	builtKey = nil
	cards = {}
	lastCards = nil
	markersKey = nil
	plaqueEffects = {}
	open = false
	lastView = nil
	lastNames = nil
end

-- Punto al que debe mirar la cámara de la vista general, y radio que tiene que abarcar. No son parte de
-- la interfaz mínima: están para que el cableado de la cámara no tenga que repetir las medidas.
function ModelCity.focus(): Vector3?
	local geometry = plinth
	if geometry == nil then
		return nil
	end
	return Vector3.new(geometry.center.x, geometry.deckY + FOCUS_LIFT, geometry.center.z)
end

function ModelCity.radius(): number?
	local geometry = plinth
	if geometry == nil then
		return nil
	end
	return geometry.width / 2
end

return ModelCity

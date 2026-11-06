--!strict
-- Muestra en la ciudad cada propiedad: su edificio fijo, su dueño, sus marcadores de mejora y los
-- añadidos de su nivel (R-P50). Arte gris: bloques planos, que el plan 07 cambia por los modelos aprobados
-- sin tocar esta interfaz. Qué cambió lo decide `WorldRules` comparando vistas; las piezas de cada nivel
-- salen de `CityLayout`.
local CityBuilder = require("./CityBuilder")
local CityLayout = require("../../shared/config/CityLayout")
local WorldRules = require("./WorldRules")
local ArtAssets = require("../../shared/config/ArtAssets")
local Strings = require("../../shared/config/Strings")
local Ui = require("../../shared/config/Ui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BLOCK_COLOR = Color3.fromRGB(176, 170, 158)
local ADDON_COLOR = Color3.fromRGB(140, 134, 124)
-- Bloque del mojón mientras no llega su malla: caliza.
local MARKER_COLOR = Color3.fromRGB(210, 201, 180)
-- Zona Caliente: contorno cálido que pulsa sobre los edificios de la zona activa. No depende del
-- color del dueño ni de la zona, así que se distingue también en blanco y negro.
local HOT_ZONE_GLOW = "HotZoneGlow"
local HOT_ZONE_FILL = Color3.fromRGB(255, 168, 48)
local HOT_ZONE_OUTLINE = Color3.fromRGB(255, 214, 120)
-- Mejora: contorno blanco cálido, más claro que el de la Zona Caliente, con un velo leve que se apaga.
local UPGRADE_GLOW = "UpgradeGlow"
local UPGRADE_FILL = Color3.fromRGB(255, 236, 170)
local UPGRADE_OUTLINE = Color3.fromRGB(255, 250, 225)

-- Atributos de cada pieza: qué es (Base, Addon o Marker) y su nivel. Las escenas se llevan añadidos y
-- marcadores sin tocar el cuerpo del edificio (art/vision-visual.md).
local ROLE = "Role"
local TIER = "Tier"

local BuildingView = {}

BuildingView.ROLE = ROLE
BuildingView.TIER = TIER

local city: CityBuilder.CityHandles? = nil
local buildings: { [number]: Model } = {}
local levels: { [number]: number } = {}
local lastProperties: { [number]: any }? = nil
local owners: { [number]: { name: string, color: Color3 }? } = {}
-- Solares que tienen piezas reales pero se dibujaron en gris porque sus mallas aún no habían llegado.
local pending: { [number]: boolean } = {}
local tagsVisible = false
local hotZoneId: string? = nil

local function makePiece(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.Material = Enum.Material.SmoothPlastic
	piece.Color = color
	piece.Size = size
	piece.CFrame = cframe
	piece.Parent = parent
	return piece
end

-- Comprueba que la malla ya está en la carpeta de la que copia `placeMesh`.
local function meshReady(key: string): boolean
	local folder = ReplicatedStorage:FindFirstChild(ArtAssets.FOLDER)
	local source = if folder ~= nil then folder:FindFirstChild(key) else nil
	return source ~= nil and source:IsA("BasePart")
end

-- Copia una malla real colocada respecto a `origin`. Sin cargar todavía, devuelve nil.
local function placeMesh(piece: ArtAssets.Piece, origin: CFrame, parent: Instance): BasePart?
	local folder = ReplicatedStorage:FindFirstChild(ArtAssets.FOLDER)
	local source = if folder ~= nil then folder:FindFirstChild(piece.key) else nil
	if source == nil or not source:IsA("BasePart") then
		return nil
	end
	local mesh = source:Clone()
	-- La pieza llega con el origen en el centro de la base, así que su posición ya es relativa a él.
	mesh.CFrame = origin * source.CFrame
	mesh.Parent = parent
	return mesh
end

-- Crea o actualiza la etiqueta de dueño y nivel sobre el edificio.
local function refreshTag(index: number)
	local model: Model? = buildings[index]
	if model == nil then
		return
	end
	local owner = owners[index]
	local text = WorldRules.ownerTag(if owner ~= nil then owner.name else nil, levels[index] or 0)
	local tag = model:FindFirstChild("OwnerTag") :: BillboardGui?
	if text == nil or owner == nil then
		if tag ~= nil then
			tag:Destroy()
		end
		return
	end
	if tag == nil then
		local made = Instance.new("BillboardGui")
		made.Name = "OwnerTag"
		made.Adornee = model:FindFirstChild("Base") :: BasePart
		made.AlwaysOnTop = true
		made.Size = UDim2.fromOffset(84, 15)
		made.ExtentsOffsetWorldSpace = Vector3.new(0, 1, 0)
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.BorderSizePixel = 0
		label.Parent = made
		made.Parent = model
		tag = made
	end
	local shown = tag :: BillboardGui
	shown.Enabled = tagsVisible
	local label = shown:FindFirstChild("Text") :: TextLabel
	label.Text = text
	label.BackgroundColor3 = owner.color
end

-- Zona de una propiedad según el tablero con el que se construyó la ciudad.
local function zoneOf(index: number): string?
	local handles = city
	if handles == nil then
		return nil
	end
	local slot = CityLayout.routeFor(handles.sizeId)[index]
	return if slot ~= nil then slot.zoneId else nil
end

-- La cifra de cada casilla cambia también sin cambio de dueño (Zona Caliente, Inflación, zona completa):
-- se repinta con cada vista y al mover la Zona Caliente. `setPrice` solo toca los textos que cambiaron.
local function repaintPrices()
	local handles = city
	if handles == nil or lastProperties == nil then
		return
	end
	for index, property in lastProperties do
		local hot = hotZoneId ~= nil and zoneOf(index) == hotZoneId
		handles.setPrice(index, WorldRules.priceCell(property, hot))
	end
end

-- Contorno cálido que pulsa en los edificios de la Zona Caliente. Sin relleno: la arquitectura se ve
-- tal cual y el pulso lo distingue de una selección estática.
local function ensureGlow(index: number)
	local model: Model? = buildings[index]
	if model == nil then
		return
	end
	local existing: Instance? = model:FindFirstChild(HOT_ZONE_GLOW)
	local wanted = hotZoneId ~= nil and zoneOf(index) == hotZoneId
	if wanted and existing == nil then
		local glow = Instance.new("Highlight")
		glow.Name = HOT_ZONE_GLOW
		glow.Adornee = model
		glow.FillColor = HOT_ZONE_FILL
		glow.FillTransparency = 1
		glow.OutlineColor = HOT_ZONE_OUTLINE
		glow.OutlineTransparency = 0.15
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Parent = model
		local tween = TweenService:Create(
			glow,
			TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ OutlineTransparency = 0.6 }
		)
		tween:Play()
	elseif not wanted and existing then
		existing:Destroy()
	end
end

-- Destello del contorno cuando un edificio sube de nivel. Mientras dura, apaga el contorno de la Zona
-- Caliente del mismo edificio (dos `Highlight` sobre un modelo se pisan) y lo devuelve al terminar. Si el
-- edificio se rehace a mitad, el destello se va con el modelo viejo.
local function flashUpgrade(model: Model)
	local config = Ui.upgradeGlow
	local hot = model:FindFirstChild(HOT_ZONE_GLOW) :: Highlight?
	if hot ~= nil then
		hot.Enabled = false
	end
	local glow = Instance.new("Highlight")
	glow.Name = UPGRADE_GLOW
	glow.Adornee = model
	glow.FillColor = UPGRADE_FILL
	glow.FillTransparency = 0.7
	glow.OutlineColor = UPGRADE_OUTLINE
	glow.OutlineTransparency = 0
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = model
	local pulse = TweenService:Create(
		glow,
		TweenInfo.new(
			config.pulseSec,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			math.max(config.pulses * 2 - 1, 0),
			true
		),
		{ OutlineTransparency = 0.55, FillTransparency = 0.95 }
	)
	pulse.Completed:Connect(function()
		if glow.Parent == nil then
			return
		end
		local fade = TweenService:Create(
			glow,
			TweenInfo.new(config.fadeSec, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ OutlineTransparency = 1, FillTransparency = 1 }
		)
		fade.Completed:Connect(function()
			glow:Destroy()
			local current = model:FindFirstChild(HOT_ZONE_GLOW) :: Highlight?
			if current ~= nil then
				current.Enabled = true
			end
		end)
		fade:Play()
	end)
	pulse:Play()
end

-- Enciende o apaga el contorno de la Zona Caliente. Se puede llamar en cada lote: si la zona no
-- cambió, no hace nada.
function BuildingView.setHotZone(zoneId: string?)
	if hotZoneId == zoneId then
		return
	end
	hotZoneId = zoneId
	for index in buildings do
		ensureGlow(index)
	end
	repaintPrices()
end

-- Pone un solar en un nivel. Las escenas la llaman también para enseñar una obra antes de la vista.
function BuildingView.setLevel(index: number, level: number)
	local handles = city
	if handles == nil or levels[index] == level then
		return
	end
	-- Nivel anterior conocido: nil al levantar la ciudad o al rehacer el arte, que no son mejoras.
	local before = levels[index]
	local previous: Model? = buildings[index]
	if previous ~= nil then
		previous:Destroy()
		buildings[index] = nil
	end
	levels[index] = level

	local model = Instance.new("Model")
	model.Name = `Building{index}`
	local lot = handles.lotOf(index)
	-- El solar mira a la calle con su -Z, así que `front` crece hacia el fondo.
	-- El modelo real si ya está cargado; si no, el bloque gris, que se cambia en `refreshArt`.
	local real = ArtAssets.piecesFor(handles.labelOf(index), level)
	local placedReal = real ~= nil
	if real ~= nil then
		local origin = lot * CFrame.new(0, 0, ArtAssets.FRONT_OFFSET)
		local roles = BuildingView.rolesFor(handles.labelOf(index), level)
		for order, piece in real do
			local mesh = placeMesh(piece, origin, model)
			if mesh == nil then
				placedReal = false
			else
				if order == 1 then
					mesh.Name = "Base"
				end
				local role = roles[order]
				mesh:SetAttribute(ROLE, role.role)
				mesh:SetAttribute(TIER, role.tier)
			end
		end
	end
	if not placedReal then
		model:ClearAllChildren()
		for order, block in CityLayout.buildingBlocks(level) do
			local piece = makePiece(
				if order == 1 then "Base" else `Addon{order - 1}`,
				Vector3.new(block.width, block.height, block.depth),
				lot * CFrame.new(block.along, block.y + block.height / 2, block.front),
				if order == 1 then BLOCK_COLOR else ADDON_COLOR,
				model
			)
			piece:SetAttribute(ROLE, if order == 1 then "Base" else "Addon")
			piece:SetAttribute(TIER, order - 1)
		end
	end
	-- Pendiente solo si había piezas reales que no pudieron colocarse: el modelo real se pone al llegar.
	if real ~= nil and not placedReal then
		pending[index] = true
	else
		pending[index] = nil
	end
	for order, marker in CityLayout.levelMarkers(level) do
		local origin = lot * CFrame.new(marker.along, 0, marker.front)
		local stone = placeMesh(ArtAssets.mojon.stone, origin, model)
		local ring = placeMesh(ArtAssets.mojon.ring, origin, model)
		for _, mesh in { stone, ring } do
			if mesh ~= nil then
				mesh:SetAttribute(ROLE, "Marker")
				mesh:SetAttribute(TIER, order)
			end
		end
		if ring ~= nil then
			local slot = CityLayout.routeFor(handles.sizeId)[index]
			if slot ~= nil and slot.zoneId ~= nil then
				ring.Color = Color3.fromHex(Strings.zone(slot.zoneId).color)
			end
		end
		if stone == nil then
			local block = makePiece(
				`Marker{order}`,
				Vector3.new(marker.width, marker.height, marker.depth),
				lot * CFrame.new(marker.along, marker.height / 2, marker.front),
				MARKER_COLOR,
				model
			)
			block:SetAttribute(ROLE, "Marker")
			block:SetAttribute(TIER, order)
		end
	end
	model.Parent = handles.model
	buildings[index] = model
	refreshTag(index)
	ensureGlow(index)
	if before ~= nil and level > before then
		flashUpgrade(model)
	end
end

-- Destello del edificio de una casilla, el mismo de una mejora. Lo usan las escenas que cambian algo del
-- edificio sin subir de nivel (un robo, un cambio de dueño).
function BuildingView.flash(index: number)
	local model: Model? = buildings[index]
	if model ~= nil then
		flashUpgrade(model)
	end
end

-- Papel de cada pieza real de un edificio, en el orden de `ArtAssets.piecesFor`: el cuerpo (tier 0) y
-- los añadidos de cada nivel (tier = nivel). Las escenas lo leen con el atributo `Role` para llevarse
-- los añadidos y marcadores sin tocar el cuerpo.
function BuildingView.rolesFor(name: string, level: number): { { role: string, tier: number } }
	local roles: { { role: string, tier: number } } = {}
	local property = ArtAssets.properties[name]
	if property == nil then
		return roles
	end
	for _ in property.base do
		table.insert(roles, { role = "Base", tier = 0 })
	end
	for order = 1, math.min(level, #property.addons) do
		for _ in property.addons[order] do
			table.insert(roles, { role = "Addon", tier = order })
		end
	end
	return roles
end

-- Modelo del edificio de una casilla, o nil si no hay ciudad o no es propiedad.
function BuildingView.modelOf(index: number): Model?
	return buildings[index]
end

-- Nivel que la ciudad muestra ahora en esa casilla (puede ir por detrás de la vista durante una escena).
function BuildingView.levelOf(index: number): number
	return levels[index] or 0
end

-- Vuelve a levantar lo que está en la ciudad cuando terminan de cargar los modelos reales.
function BuildingView.refreshArt()
	for index, level in table.clone(levels) do
		levels[index] = nil
		BuildingView.setLevel(index, level)
	end
end

-- Cambia el gris por el modelo real en los solares pendientes cuyas mallas ya están todas cargadas. Los demás
-- se quedan como están: no se borra nada hasta comprobar que la copia completa va a salir bien.
function BuildingView.refreshPending()
	local handles = city
	if handles == nil then
		return
	end
	for index in table.clone(pending) do
		local level = levels[index]
		if level == nil then
			continue
		end
		local real = ArtAssets.piecesFor(handles.labelOf(index), level)
		local complete = real ~= nil
		if real ~= nil then
			for _, piece in real do
				if not meshReady(piece.key) then
					complete = false
					break
				end
			end
		end
		if complete then
			levels[index] = nil
			BuildingView.setLevel(index, level)
		end
	end
end

-- Enseña u oculta las etiquetas: solo se ven en la vista general.
function BuildingView.setTagsVisible(visible: boolean)
	if tagsVisible == visible then
		return
	end
	tagsVisible = visible
	for index in buildings do
		refreshTag(index)
	end
end

-- Empieza con una ciudad recién levantada: las piezas de la anterior se fueron con ella. Cada propiedad
-- ya tiene su edificio antes de que nadie la compre.
function BuildingView.bind(handles: CityBuilder.CityHandles)
	city = handles
	buildings = {}
	levels = {}
	owners = {}
	pending = {}
	lastProperties = nil
	hotZoneId = nil
	for _, slot in CityLayout.routeFor(handles.sizeId) do
		if slot.kind == "Property" then
			BuildingView.setLevel(slot.index, 0)
		end
	end
end

-- Lleva la ciudad al estado de una vista. Solo toca lo que cambió, así que se puede llamar con cada lote.
function BuildingView.sync(
	properties: { [number]: any },
	colorOf: (ownerId: string) -> Color3?,
	nameOf: (ownerId: string) -> string
)
	local handles = city
	if handles == nil then
		return
	end
	for _, change in WorldRules.propertyChanges(lastProperties, properties) do
		local color = if change.ownerId ~= nil then colorOf(change.ownerId) else nil
		handles.setOwner(change.index, color, change.mortgaged)
		owners[change.index] = if change.ownerId ~= nil and color ~= nil
			then { name = nameOf(change.ownerId), color = color }
			else nil
		BuildingView.setLevel(change.index, change.level)
		refreshTag(change.index)
	end
	lastProperties = properties
	repaintPrices()
end

return BuildingView

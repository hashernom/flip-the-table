--!strict
-- Construye la ciudad gris provisional de un tamaño: calle de asfalto, aceras, casillas pintadas y
-- rótulos (art/vision-visual.md). Es arte temporal: piezas planas y colores planos, nada que se publique
-- como versión pública. Todas las posiciones, los barrios y
-- las etiquetas salen de `CityLayout` y `Strings`, que son puros y están probados con Lune; aquí
-- solo se convierten en `Instance`.
--
-- La ciudad se levanta en el cliente: el servidor no necesita ni una pieza y así el prototipo no
-- gasta presupuesto de partes replicadas.
local WorldRules = require("./WorldRules")
local ArtAssets = require("../../shared/config/ArtAssets")
local CityInterior = require("../../shared/config/CityInterior")
local CityLayout = require("../../shared/config/CityLayout")
local Economy = require("../../shared/config/Economy")
local Strings = require("../../shared/config/Strings")
local Ui = require("../../shared/config/Ui")
local HudRules = require("../ui/HudRules")
local UiIcons = require("../../shared/config/UiIcons")
local Types = require("../../shared/rules/Types")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

export type SizeId = CityLayout.SizeId

export type CityHandles = {
	model: Model,
	-- Tamaño del tablero con el que se construyó: lo usan las fichas para saber a qué ruta pertenecen.
	sizeId: SizeId,
	-- Pintura de cada casilla, por número de casilla del tablero.
	squares: { [number]: BasePart },
	-- Carpeta donde `TokenRider` deja las fichas.
	tokens: Folder,
	positionOf: (index: number) -> Vector3,
	facingOf: (index: number) -> number,
	labelOf: (index: number) -> string,
	colorOf: (index: number) -> Color3,
	-- Solar de la casilla: en el suelo, junto a la baldosa, con su frente mirando a la calle.
	lotOf: (index: number) -> CFrame,
	-- Solar fuera del anillo aunque los solares vayan dentro: el de la cárcel.
	outsideLotOf: (index: number) -> CFrame,
	-- Pinta el solar con el color del dueño. La baldosa conserva el de su zona; `nil` libera el solar.
	-- `mortgaged` apaga la placa y planta el cartel de hipotecada (R-P53).
	setOwner: (index: number, color: Color3?, mortgaged: boolean?) -> (),
	-- Repinta la cifra de una casilla de propiedad (`WorldRules.priceCell`); nil la borra. Solo toca lo
	-- que cambió.
	setPrice: (index: number, cell: WorldRules.PriceCell?) -> (),
	-- Enciende la tira de la Zona Caliente en las casillas de una zona; `nil` la apaga.
	setHotZone: (zoneId: string?) -> (),
	-- Marca gruesa de la Zona Caliente para la vista general: desde lo alto la raya y los contornos no se ven.
	setHotZoneOverview: (visible: boolean) -> (),
	-- Vuelve a colocar el fondo de los barrios: las mallas llegan después de construir la ciudad.
	refreshBackdrops: () -> (),
	destroy: () -> (),
}

local DARK_GREY = Color3.fromRGB(52, 56, 62)
local ASPHALT = Color3.fromRGB(74, 78, 84)
local PAVEMENT = Color3.fromRGB(128, 123, 112)
local PAINT_HEIGHT = 0.05
local WATER = Color3.fromRGB(38, 84, 120)
local TILE_HEIGHT = 0.4
-- Suelo libre fuera del anillo (2026-11-06): 60 studs por lado, para los barrios. Lo comparten suelo y agua.
-- Margen del suelo alrededor del anillo: caben los fondos de barrio (a 72 de la calle) y las arboledas.
local GROUND_MARGIN = 190
-- Suelo de la ciudad: césped, no asfalto gris. Lo construido va encima.
local GROUND_GRASS = Color3.fromRGB(94, 138, 74)
local INTERIOR_FOLDER = "Interior"
local NAME_DEPTH = 6
-- Rótulo de una casilla enmarcada: centrado en la mitad libre de la calle, sin tocar el marco.
local FRAMED_NAME_SIDE = 7.5
local FRAMED_NAME_MARGIN = 3
local ROAD_PAINT_TRANSPARENCY = 0.08
-- Cuánto se apaga el color de la pintura: 0 es el color puro, que brilla; 1, el de la baldosa antigua.
local ROAD_PAINT_DIM = 0.5
local NAME_PIXELS_PER_STUD = 16
local NAME_TEXT_SIZE = 70
local NAME_PAINT = Color3.fromRGB(222, 216, 200)
-- Cifra de una propiedad: en el carril libre, más allá del nombre. Una sola, con su etiqueta encima.
local PRICE_PAINT = "PricePaint"
local PRICE_DEPTH = 5
local PRICE_GAP = 0.5
local PRICE_CAPTION_SHARE = 0.3
local PRICE_CAPTION_SIZE = 22
local PRICE_VALUE_SIZE = 56
local OWNER_PLATE = "OwnerPlate"
-- Solar comprado: la placa del dueño no es un bloque liso. Lleva un canto claro y un halo que se apaga en
-- unos studs alrededor, dibujado con anillos translúcidos (sin imágenes), y una luz que tiñe la base del
-- edificio. La placa toma el color del dueño algo apagado; el canto y el halo lo llevan puro.
local OWNER_HALO = "OwnerHalo"
local OWNER_HALO_STUDS = 3
local OWNER_HALO_RINGS = 12
local OWNER_HALO_RING_TRANSPARENCY = 0.95
local OWNER_HALO_BRIGHTNESS = 1.1
local OWNER_PLATE_DIM = 0.22
local OWNER_EDGE_STUDS = 0.45
local OWNER_GUI_PIXELS_PER_STUD = 20
local OWNER_LIGHT_RANGE = 6
local OWNER_LIGHT_BRIGHTNESS = 0.35
-- Hipotecada: la placa pierde el halo y la luz, se apaga hacia el gris y lleva un cartel rojo en la acera
-- del solar. Se distingue en blanco y negro por el cartel, no solo por el color.
local MORTGAGE_DIM = 0.65
local MORTGAGE_RED = Color3.fromRGB(196, 48, 43)
local MORTGAGE_SIGN_SIZE = Vector3.new(9, 3.6, 0.3)
local MORTGAGE_POST_HEIGHT = 3
-- Icono de una casilla especial: va sobre la pintura, un poco hacia la calle para no pisar el nombre.
local ICON_SIZE = 14
local ICON_OFFSET = -3
local ICON_TRANSPARENCY = 0.05
-- Zona Caliente: tira de neón en el borde de la acera de cada casilla de la zona activa. Va sobre la
-- pintura, no sobre el edificio, y pulsa para no confundirse con una línea pintada más.
local HOT_ZONE_NAME = "HotZone"
local HOT_ZONE_COLOR = Color3.fromRGB(255, 168, 48)
local HOT_ZONE_WIDTH = 1.2
local HOT_ZONE_LENGTH = 28
local HOT_ZONE_EDGE = CityLayout.PAINT_ACROSS_STUDS / 2 - 0.9
local HOT_ZONE_HEIGHT = 0.08
local HOT_ZONE_Y = PAINT_HEIGHT + 0.02
-- Vista general: relleno naranja translúcido sobre cada casilla de la zona y un rótulo flotante en medio.
local HOT_ZONE_FILL_TRANSPARENCY = 0.68
local HOT_ZONE_TAG_SIZE = UDim2.fromOffset(150, 28)
local HOT_ZONE_TAG_LIFT = 14

local CityBuilder = {}

-- La casilla como la ve `Strings`: número, tipo, zona y barrio. `CityLayout.Slot` ya los trae; esto
-- solo evita repetir la misma tabla cada vez que hace falta un color o un rótulo.
local function toSquare(slot: CityLayout.Slot): Types.Square
	return {
		index = slot.index,
		kind = slot.kind,
		zoneId = slot.zoneId,
		barrioId = slot.barrioId,
	}
end

local function makePart(properties: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in properties do
		(part :: any)[key] = value
	end
	return part
end

local function ownerSurface(parent: BasePart, name: string, light: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = OWNER_GUI_PIXELS_PER_STUD
	gui.LightInfluence = 0
	gui.Brightness = light
	gui.Parent = parent
	return gui
end

-- Cartel de hipotecada: un tablón rojo sobre un poste, en la esquina del solar que da a la calle y mirando a
-- ella. Lleva el texto y una banda diagonal, para leerse también sin color.
local function makeMortgageSign(lot: CFrame, plate: Part)
	local width, depth = CityLayout.LOT_WIDTH_STUDS, CityLayout.LOT_DEPTH_STUDS
	-- El solar mira a la calle con su -Z: el frente queda en z = -depth / 2.
	local foot = lot * CFrame.new(width / 2 - MORTGAGE_SIGN_SIZE.X / 2 - 1, 0, -depth / 2 + 1.5)
	local post = makePart({
		Name = "MortgagePost",
		Size = Vector3.new(0.4, MORTGAGE_POST_HEIGHT, 0.4),
		CFrame = foot * CFrame.new(0, MORTGAGE_POST_HEIGHT / 2, 0),
		Color = Color3.fromRGB(60, 62, 66),
	})
	post.Parent = plate
	local board = makePart({
		Name = "MortgageSign",
		Size = MORTGAGE_SIGN_SIZE,
		CFrame = foot * CFrame.new(0, MORTGAGE_POST_HEIGHT + MORTGAGE_SIGN_SIZE.Y / 2, 0),
		Color = MORTGAGE_RED,
	})
	board.Parent = plate
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.3
		gui.Parent = board
		local stripe = Instance.new("Frame")
		stripe.BorderSizePixel = 0
		stripe.BackgroundColor3 = Color3.fromRGB(245, 236, 214)
		stripe.AnchorPoint = Vector2.new(0.5, 0.5)
		stripe.Position = UDim2.fromScale(0.5, 0.5)
		stripe.Size = UDim2.new(1.4, 0, 0, 10)
		stripe.Rotation = -14
		stripe.BackgroundTransparency = 0.35
		stripe.Parent = gui
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(255, 248, 232)
		text.TextStrokeTransparency = 0.4
		text.Text = Strings.upper(Strings.get("city.mortgaged"))
		text.ZIndex = 2
		text.Parent = gui
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0.06, 0)
		pad.PaddingRight = UDim.new(0.06, 0)
		pad.PaddingTop = UDim.new(0.12, 0)
		pad.PaddingBottom = UDim.new(0.12, 0)
		pad.Parent = text
	end
end

-- Placa del dueño de un solar, con su canto y su halo. Se rehace entera al cambiar de dueño o de hipoteca.
local function makeOwnerPlate(lot: CFrame, color: Color3, mortgaged: boolean?): Part
	local width, depth = CityLayout.LOT_WIDTH_STUDS, CityLayout.LOT_DEPTH_STUDS
	local plate = makePart({
		Name = OWNER_PLATE,
		Size = Vector3.new(width, TILE_HEIGHT, depth),
		CFrame = lot,
		Color = color:Lerp(DARK_GREY, if mortgaged then MORTGAGE_DIM else OWNER_PLATE_DIM),
	})
	if mortgaged then
		-- Sin halo ni luz: apagada. Un canto rojo y el cartel dicen por qué.
		local edgeGui = ownerSurface(plate, "Edge", 1)
		local edge = Instance.new("Frame")
		edge.Name = "Edge"
		edge.BackgroundTransparency = 1
		edge.Size = UDim2.fromScale(1, 1)
		edge.Parent = edgeGui
		local stroke = Instance.new("UIStroke")
		stroke.Color = MORTGAGE_RED
		stroke.Thickness = OWNER_EDGE_STUDS * OWNER_GUI_PIXELS_PER_STUD
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = edge
		makeMortgageSign(lot, plate)
		return plate
	end

	-- Canto: un marco claro por dentro del borde de la placa.
	local edgeGui = ownerSurface(plate, "Edge", 1.2)
	local edge = Instance.new("Frame")
	edge.Name = "Edge"
	edge.BackgroundTransparency = 1
	edge.Size = UDim2.fromScale(1, 1)
	edge.Parent = edgeGui
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = OWNER_EDGE_STUDS * OWNER_GUI_PIXELS_PER_STUD
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = edge
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, OWNER_GUI_PIXELS_PER_STUD // 2)
	corner.Parent = edge

	-- Halo: una lámina invisible algo mayor que la placa, justo bajo su cara de arriba (la placa tapa el
	-- centro y el halo solo asoma alrededor), con anillos que se apilan.
	-- Cada anillo es más pequeño que el anterior, así que el color se acumula hacia la placa y se apaga
	-- hacia fuera; las esquinas redondas evitan el corte en cruz.
	local reach = OWNER_HALO_STUDS * 2
	local halo = makePart({
		Name = OWNER_HALO,
		Size = Vector3.new(width + reach, 0.05, depth + reach),
		CFrame = lot * CFrame.new(0, TILE_HEIGHT / 2 - 0.03, 0),
		Transparency = 1,
	})
	halo.Parent = plate
	local haloGui = ownerSurface(halo, "Glow", OWNER_HALO_BRIGHTNESS)
	local step = OWNER_HALO_STUDS * OWNER_GUI_PIXELS_PER_STUD / OWNER_HALO_RINGS
	for ring = 0, OWNER_HALO_RINGS - 1 do
		local inset = math.floor(ring * step)
		local band = Instance.new("Frame")
		band.Name = `Ring{ring}`
		band.AnchorPoint = Vector2.new(0.5, 0.5)
		band.Position = UDim2.fromScale(0.5, 0.5)
		band.Size = UDim2.new(1, -2 * inset, 1, -2 * inset)
		band.BackgroundColor3 = color
		band.BackgroundTransparency = OWNER_HALO_RING_TRANSPARENCY
		band.BorderSizePixel = 0
		band.Parent = haloGui
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0, math.floor(OWNER_HALO_STUDS * OWNER_GUI_PIXELS_PER_STUD - inset))
		round.Parent = band
	end

	-- Luz hacia arriba: tiñe la base del edificio con el color del dueño.
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Top
	light.Color = color
	light.Range = OWNER_LIGHT_RANGE
	light.Brightness = OWNER_LIGHT_BRIGHTNESS
	light.Angle = 120
	light.Shadows = false
	light.Parent = plate
	return plate
end

-- Rótulo que se lee desde la calle: mira siempre a la cámara y se apaga a lo lejos para no gastar.
-- Base del anillo y, para los tableros grandes, el agua de las islas exteriores. Es una sola pieza
-- grande por color: abarata el prototipo y no hace falta detalle.
local function makeGround(model: Model, sizeId: SizeId)
	local span = CityLayout.spanFor(sizeId)
	local center = CityLayout.centerFor(sizeId)
	local slab = makePart({
		Name = "Ground",
		Size = Vector3.new(span + 2 * GROUND_MARGIN, 2, span + 2 * GROUND_MARGIN),
		CFrame = CFrame.new(center.x, -TILE_HEIGHT - 1, center.z),
		Color = GROUND_GRASS,
		Material = Enum.Material.Grass,
		CanCollide = true,
	})
	slab.Parent = model

	if #CityLayout.bridgesFor(sizeId) > 0 then
		local water = makePart({
			Name = "Water",
			Size = Vector3.new(span + 2 * GROUND_MARGIN, 0.2, span + 2 * GROUND_MARGIN),
			CFrame = CFrame.new(center.x, -TILE_HEIGHT - 0.6, center.z),
			Color = WATER,
			Material = Enum.Material.Water,
		})
		water.Parent = model
	end
end

-- Los puentes: una pasarela por arista que cruza de una isla a otra. Ocupa solo la junta entre las
-- dos casillas (de ahí el largo de `SEAM`), para no invadir ninguna baldosa ni pelearse con ella.
local SEAM = 4
local BRIDGE_WIDTH = 20

local function makeBridges(model: Model, sizeId: SizeId)
	for order, bridge in CityLayout.bridgesFor(sizeId) do
		local midpoint = Vector3.new(
			bridge.start.x + math.sin(bridge.facing) * bridge.lengthStuds / 2,
			-TILE_HEIGHT / 2,
			bridge.start.z + math.cos(bridge.facing) * bridge.lengthStuds / 2
		)
		local plank = makePart({
			Name = `Bridge{order}`,
			Size = Vector3.new(BRIDGE_WIDTH, TILE_HEIGHT, SEAM),
			CFrame = CFrame.lookAt(
				midpoint,
				midpoint + Vector3.new(math.sin(bridge.facing), 0, math.cos(bridge.facing))
			),
			Color = ASPHALT,
			CanCollide = true,
		})
		plank.Parent = model
	end
end

-- El fondo de cada barrio: piezas de bajo detalle detrás de los solares, para que la ciudad no acabe en
-- una pared. No tienen colisión ni se pueden consultar: son silueta y nadie las pisa (art/PIPELINE.md).
local BACKDROP_FOLDER = "Backdrop"

local function makeBackdrops(model: Model, sizeId: SizeId)
	local previous = model:FindFirstChild(BACKDROP_FOLDER)
	if previous ~= nil then
		previous:Destroy()
	end
	local art = ReplicatedStorage:FindFirstChild(ArtAssets.FOLDER)
	if art == nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = BACKDROP_FOLDER
	for _, barrioId in CityLayout.barriosFor(sizeId) do
		for _, item in CityLayout.backdropsFor(sizeId, barrioId) do
			local pieces = ArtAssets.street[item.kind]
			if pieces == nil then
				continue
			end
			local position = Vector3.new(item.x, item.y, item.z)
			local origin = CFrame.lookAt(position, position + Vector3.new(item.lookX, 0, item.lookZ))
			for _, piece in pieces do
				local source = art:FindFirstChild(piece.key)
				if source ~= nil and source:IsA("BasePart") then
					local mesh = source:Clone()
					mesh.Name = piece.key
					mesh.CFrame = origin * source.CFrame
					mesh.Anchored = true
					mesh.CanCollide = false
					mesh.CanQuery = false
					mesh.CanTouch = false
					mesh.Parent = folder
				end
			end
		end
	end
	folder.Parent = model
end

-- Ciudad procedural: el interior del anillo y el borde exterior (`CityInterior`). Cada pieza es un `Part`
-- anclado y sin colisión; las finas no dan sombra.
local MATERIALS: { [string]: Enum.Material } = {
	SmoothPlastic = Enum.Material.SmoothPlastic,
	Concrete = Enum.Material.Concrete,
	Grass = Enum.Material.Grass,
	Glass = Enum.Material.Glass,
	Brick = Enum.Material.Brick,
	Wood = Enum.Material.Wood,
	Slate = Enum.Material.Slate,
	Ground = Enum.Material.Ground,
	Metal = Enum.Material.Metal,
	-- El agua de un `Part` se pinta como cristal: refleja el cielo, que es lo que la hace leerse como agua.
	Water = Enum.Material.Glass,
	Asphalt = Enum.Material.Asphalt,
	Pavement = Enum.Material.Pavement,
	Fabric = Enum.Material.Fabric,
}
local WATER_TRANSPARENCY = 0.15

local function makeInteriorPart(item: CityInterior.Item, parent: Instance)
	local part: BasePart
	local rotation = CFrame.Angles(0, item.yaw, 0)
	if item.shape == "Wedge" then
		part = Instance.new("WedgePart")
		part.Size = Vector3.new(item.sx, item.sy, item.sz)
	elseif item.shape == "Disk" then
		local cylinder = Instance.new("Part")
		cylinder.Shape = Enum.PartType.Cylinder
		-- El cilindro de Roblox tiene el eje en X: se tumba para que quede de pie, como un disco.
		cylinder.Size = Vector3.new(item.sy, item.sx, item.sx)
		rotation *= CFrame.Angles(0, 0, math.pi / 2)
		part = cylinder
	elseif item.shape == "Ball" then
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(item.sx, item.sy, item.sz)
		part = ball
	else
		part = Instance.new("Part")
		part.Size = Vector3.new(item.sx, item.sy, item.sz)
	end
	part.Name = item.name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CastShadow = item.flat ~= true
	part.Color = Color3.fromHex(item.color)
	part.Material = MATERIALS[item.material] or Enum.Material.SmoothPlastic
	part.Transparency = item.transparency or (if item.material == "Water" then WATER_TRANSPARENCY else 0)
	part.CFrame = CFrame.new(item.x, item.y, item.z) * rotation
	part.Parent = parent
end

local function makeInterior(model: Model, sizeId: SizeId)
	local folder = Instance.new("Folder")
	folder.Name = INTERIOR_FOLDER
	for _, item in CityInterior.itemsFor(sizeId) do
		makeInteriorPart(item, folder)
	end
	for _, item in CityInterior.exteriorFor(sizeId) do
		makeInteriorPart(item, folder)
	end
	folder.Parent = model
end

-- La calle: un tramo de asfalto por lado del anillo, con su acera a cada lado. Va por piezas largas, no
-- por casilla: así el asfalto se lee continuo, que es lo que hace que parezca una calle y no un tablero.
local function makeStreet(model: Model, sizeId: SizeId)
	local span = CityLayout.spanFor(sizeId)
	local street = CityLayout.STREET_WIDTH_STUDS
	local walk = CityLayout.SIDEWALK_STUDS
	local walkOffset = street / 2 + walk / 2
	-- Cada lado: su eje y hacia dónde queda el exterior del anillo.
	local sides = {
		{ center = Vector3.new(span / 2, 0, 0), along = Vector3.xAxis, out = -Vector3.zAxis },
		{ center = Vector3.new(span, 0, span / 2), along = Vector3.zAxis, out = Vector3.xAxis },
		{ center = Vector3.new(span / 2, 0, span), along = Vector3.xAxis, out = Vector3.zAxis },
		{ center = Vector3.new(0, 0, span / 2), along = Vector3.zAxis, out = -Vector3.xAxis },
	}
	local function strip(
		name: string,
		center: Vector3,
		along: Vector3,
		length: number,
		width: number,
		color: Color3
	)
		local size = if along == Vector3.xAxis
			then Vector3.new(length, TILE_HEIGHT, width)
			else Vector3.new(width, TILE_HEIGHT, length)
		local part = makePart({ Name = name, Size = size, Color = color, CanCollide = true })
		part.Material = if color == ASPHALT then Enum.Material.Asphalt else Enum.Material.Concrete
		part.CFrame = CFrame.new(center)
		part.Parent = model
	end
	for order, side in sides do
		local road = side.center + Vector3.new(0, -TILE_HEIGHT / 2, 0)
		strip(`Street{order}`, road, side.along, span + street, street, ASPHALT)
		local curb = Vector3.new(0, TILE_HEIGHT / 2, 0)
		strip(
			`WalkOut{order}`,
			side.center + side.out * walkOffset + curb,
			side.along,
			span + street + walk * 2,
			walk,
			PAVEMENT
		)
		strip(
			`WalkIn{order}`,
			side.center - side.out * walkOffset + curb,
			side.along,
			span - street - walk * 2,
			walk,
			PAVEMENT
		)
	end
end

-- Una casilla: pintura del color de su calle sobre el asfalto, y en la acera el poste con su nombre.
local function makeSquare(model: Model, slot: CityLayout.Slot, corner: boolean): Part
	local center = CityLayout.slotCenter(slot)
	local position = Vector3.new(center.x, PAINT_HEIGHT / 2, center.z)
	local forward = Vector3.new(math.sin(slot.facing), 0, math.cos(slot.facing))
	-- Lado del edificio de esta casilla: dentro las propiedades, fuera las especiales (`CityLayout.lotSideOf`).
	local slotSide = CityLayout.lotSideOf(slot)
	local color = Color3.fromHex(Strings.colorFor(toSquare(slot)))

	local tile = makePart({
		Name = `Square{slot.index}`,
		Size = Vector3.new(CityLayout.SLOT_DEPTH_STUDS, PAINT_HEIGHT, CityLayout.SLOT_LENGTH_STUDS),
		CFrame = CFrame.lookAt(position, position + forward),
		Color = Color3.new(WorldRules.paintColor(color.R, color.G, color.B)),
		Material = Enum.Material.Concrete,
	})
	tile.Parent = model

	-- Casilla enmarcada: pintura desgastada sobre el asfalto, teñida con el color de la zona. Va de lado a lado de la
	-- calle, centrada en ella; en una esquina ocupa el cuadrado del cruce.
	do
		tile.Transparency = 1
		local across = CityLayout.PAINT_ACROSS_STUDS
		local middle = Vector3.new(slot.position.x, PAINT_HEIGHT / 2, slot.position.z)
		local frame = makePart({
			Name = "RoadPaint",
			Size = Vector3.new(across, PAINT_HEIGHT, if corner then across else CityLayout.PAINT_ALONG_STUDS),
			-- Girada: el borde izquierdo de la textura, el de la isla, queda del lado del edificio.
			CFrame = CFrame.lookAt(middle, middle - forward * slotSide),
			Transparency = 1,
		})
		frame.Parent = tile
		local paint = Instance.new("Decal")
		paint.Face = Enum.NormalId.Top
		local textures = if slot.kind == "Property" then ArtAssets.roadPaintIsland else ArtAssets.roadPaint
		paint.Texture = textures[(slot.index - 1) % #textures + 1]
		-- Algo apagada y transparente: el asfalto se transparenta y la línea no brilla.
		local r, g, b = WorldRules.roadPaintColor(color.R, color.G, color.B)
		paint.Color3 = Color3.new(r, g, b):Lerp(Color3.new(WorldRules.paintColor(r, g, b)), ROAD_PAINT_DIM)
		paint.Transparency = ROAD_PAINT_TRANSPARENCY
		paint.Parent = frame
	end

	-- Señalética del tipo de casilla: el icono blanco de `art/textures/casillas/iconos`, teñido como la
	-- pintura del nombre. Va en su propia pieza para no tocar el desgaste de la pintura de la zona.
	-- Hacia el interior del anillo. Con `LOT_SIDE` todo lo pintado se mide hacia la mitad libre de la calle,
	-- la contraria a los edificios.
	local inward = Vector3.new(-forward.Z, 0, forward.X)
	local towardFree = inward * slotSide
	local iconId = ArtAssets.roadIcons[slot.kind]
	if iconId ~= nil then
		local middle = Vector3.new(slot.position.x, PAINT_HEIGHT / 2 + 0.01, slot.position.z)
			+ towardFree * ICON_OFFSET
		local icon = makePart({
			Name = "RoadIcon",
			Size = Vector3.new(ICON_SIZE, PAINT_HEIGHT, ICON_SIZE),
			CFrame = CFrame.lookAt(middle, middle + forward),
			Transparency = 1,
		})
		icon.Parent = tile
		local decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Top
		decal.Texture = iconId
		decal.Color3 = NAME_PAINT
		decal.Transparency = ICON_TRANSPARENCY
		decal.Parent = icon
	end

	-- El nombre va pintado en el carril libre, junto a la casilla: la ficha nunca lo tapa. Mira hacia el
	-- interior del anillo, que es desde donde mira la cámara.
	local namePosition = Vector3.new(slot.position.x, PAINT_HEIGHT / 2, slot.position.z)
		+ towardFree * FRAMED_NAME_SIDE
	-- Dentro del marco, el rótulo deja margen para no tocar el contorno.
	local nameLength = CityLayout.PAINT_ALONG_STUDS - 2 * FRAMED_NAME_MARGIN
	local plate = makePart({
		Name = "NamePaint",
		Size = Vector3.new(NAME_DEPTH, PAINT_HEIGHT, nameLength),
		-- Se lee desde la mitad libre, que es desde donde mira la cámara.
		CFrame = CFrame.lookAt(namePosition, namePosition + forward * CityLayout.LOT_SIDE),
		Transparency = 1,
	})
	plate.Parent = tile
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Top
	surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surface.CanvasSize = Vector2.new(nameLength, NAME_DEPTH) * NAME_PIXELS_PER_STUD
	surface.LightInfluence = 1
	surface.Parent = plate
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	-- Se encoge y parte en dos líneas si no cabe: un nombre largo no puede pisar el de al lado.
	text.TextScaled = true
	text.TextWrapped = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = NAME_TEXT_SIZE
	limit.Parent = text
	text.TextColor3 = NAME_PAINT
	text.Text = Strings.squareLabel(toSquare(slot), slot.ordinal)
	text.Parent = surface

	-- Las propiedades llevan pintada junto al nombre la cifra que importa ahora (`WorldRules.priceCell`).
	-- Llega vacía y `setPrice` la rellena con la vista.
	if slot.kind == "Property" then
		local pricePosition = Vector3.new(slot.position.x, PAINT_HEIGHT / 2, slot.position.z)
			+ towardFree * (FRAMED_NAME_SIDE + NAME_DEPTH / 2 + PRICE_GAP + PRICE_DEPTH / 2)
		local strip = makePart({
			Name = PRICE_PAINT,
			Size = Vector3.new(PRICE_DEPTH, PAINT_HEIGHT, nameLength),
			CFrame = CFrame.lookAt(pricePosition, pricePosition + forward * CityLayout.LOT_SIDE),
			Transparency = 1,
		})
		strip.Parent = tile
		local prices = Instance.new("SurfaceGui")
		prices.Name = "Prices"
		prices.Face = Enum.NormalId.Top
		prices.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		prices.CanvasSize = Vector2.new(nameLength, PRICE_DEPTH) * NAME_PIXELS_PER_STUD
		prices.LightInfluence = 1
		prices.Parent = strip
		local caption = Instance.new("TextLabel")
		caption.Name = "Caption"
		caption.BackgroundTransparency = 1
		caption.Size = UDim2.fromScale(1, PRICE_CAPTION_SHARE)
		caption.Font = Enum.Font.GothamBold
		caption.TextSize = PRICE_CAPTION_SIZE
		caption.TextColor3 = NAME_PAINT
		caption.Text = ""
		caption.Parent = prices
		local value = Instance.new("TextLabel")
		value.Name = "Value"
		value.BackgroundTransparency = 1
		value.Position = UDim2.fromScale(0, PRICE_CAPTION_SHARE)
		value.Size = UDim2.fromScale(1, 1 - PRICE_CAPTION_SHARE)
		value.Font = Enum.Font.GothamBlack
		value.TextScaled = true
		value.Text = ""
		value.Parent = prices
		local valueLimit = Instance.new("UITextSizeConstraint")
		valueLimit.MaxTextSize = PRICE_VALUE_SIZE
		valueLimit.Parent = value
	end

	return tile
end

function CityBuilder.build(sizeId: SizeId, parent: Instance): CityHandles
	local existing = parent:FindFirstChild(`City_{sizeId}`)
	if existing then
		existing:Destroy()
	end

	local route = CityLayout.routeFor(sizeId)
	local model = Instance.new("Model")
	model.Name = `City_{sizeId}`

	makeGround(model, sizeId)
	makeStreet(model, sizeId)
	makeBridges(model, sizeId)
	makeBackdrops(model, sizeId)
	makeInterior(model, sizeId)

	local squares: { [number]: BasePart } = {}
	for order, slot in route do
		-- Una esquina es donde la calle cambia de sentido: la casilla anterior venía por otra dirección.
		local previous = route[(order - 2) % #route + 1]
		squares[slot.index] = makeSquare(model, slot, math.abs(previous.facing - slot.facing) > 0.01)
	end

	local tokens = Instance.new("Folder")
	tokens.Name = "Tokens"
	tokens.Parent = model

	local hotZone = Instance.new("Folder")
	hotZone.Name = HOT_ZONE_NAME
	hotZone.Parent = model
	local hotZoneId: string? = nil

	local overviewMarks = false
	local function setHotZone(zoneId: string?)
		if hotZoneId == zoneId then
			return
		end
		hotZoneId = zoneId
		for _, strip in hotZone:GetChildren() do
			strip:Destroy()
		end
		if zoneId == nil then
			return
		end
		for _, slot in route do
			if slot.zoneId ~= zoneId then
				continue
			end
			local forward = Vector3.new(math.sin(slot.facing), 0, math.cos(slot.facing))
			local inward = Vector3.new(-forward.Z, 0, forward.X)
			local middle = Vector3.new(slot.position.x, HOT_ZONE_Y, slot.position.z)
				- inward * CityLayout.LOT_SIDE * HOT_ZONE_EDGE
			local strip = makePart({
				Name = `HotZone{slot.index}`,
				Size = Vector3.new(HOT_ZONE_WIDTH, HOT_ZONE_HEIGHT, HOT_ZONE_LENGTH),
				CFrame = CFrame.lookAt(middle, middle + forward),
				Color = HOT_ZONE_COLOR,
				Material = Enum.Material.Neon,
				Transparency = 0.3,
			})
			strip.Parent = hotZone
			-- Relleno de la vista general: tapa la casilla entera y solo se ve con la vista general abierta.
			local fill = makePart({
				Name = `HotZoneFill{slot.index}`,
				Size = Vector3.new(
					CityLayout.PAINT_ACROSS_STUDS,
					HOT_ZONE_HEIGHT,
					CityLayout.PAINT_ALONG_STUDS
				),
				CFrame = CFrame.lookAt(
					Vector3.new(slot.position.x, HOT_ZONE_Y + 0.01, slot.position.z),
					Vector3.new(slot.position.x, HOT_ZONE_Y + 0.01, slot.position.z) + forward
				),
				Color = HOT_ZONE_COLOR,
				Material = Enum.Material.Neon,
				Transparency = if overviewMarks then HOT_ZONE_FILL_TRANSPARENCY else 1,
			})
			fill:SetAttribute("OverviewFill", true)
			fill.Parent = hotZone
			-- El pulso lento lo separa de una raya pintada y se lee en blanco y negro.
			local tween = TweenService:Create(
				strip,
				TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Transparency = 0.65 }
			)
			tween:Play()
		end
		-- Rótulo en la casilla central de la zona, con el icono de llama: dice qué es y qué hace.
		local members: { CityLayout.Slot } = {}
		for _, slot in route do
			if slot.zoneId == zoneId then
				table.insert(members, slot)
			end
		end
		local middle = members[math.max(1, math.ceil(#members / 2))]
		if middle ~= nil then
			local anchor = makePart({
				Name = "HotZoneTagAnchor",
				Size = Vector3.new(1, 1, 1),
				CFrame = CFrame.new(middle.position.x, HOT_ZONE_TAG_LIFT, middle.position.z),
				Transparency = 1,
			})
			anchor.Parent = hotZone
			local tag = Instance.new("BillboardGui")
			tag.Name = "HotZoneTag"
			tag.Size = HOT_ZONE_TAG_SIZE
			tag.AlwaysOnTop = true
			tag.Enabled = overviewMarks
			tag.Parent = anchor
			local plate = Instance.new("Frame")
			plate.Size = UDim2.fromScale(1, 1)
			plate.BackgroundColor3 = HOT_ZONE_COLOR
			plate.BorderSizePixel = 0
			plate.Parent = tag
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = plate
			local flame = Instance.new("ImageLabel")
			flame.BackgroundTransparency = 1
			flame.Image = UiIcons.flame
			flame.ImageColor3 = Color3.fromRGB(40, 30, 20)
			flame.Position = UDim2.fromOffset(8, 4)
			flame.Size = UDim2.fromOffset(20, 20)
			flame.Parent = plate
			local text = Instance.new("TextLabel")
			text.BackgroundTransparency = 1
			text.Position = UDim2.fromOffset(32, 2)
			text.Size = UDim2.new(1, -40, 1, -4)
			text.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
			text.TextScaled = true
			text.TextColor3 = Color3.fromRGB(40, 30, 20)
			text.Text = Strings.upper(Strings.get("hotZone.tag", { mult = Economy.hotZoneRentMultiplier }))
			text.Parent = plate
		end
	end

	local function setHotZoneOverview(visible: boolean)
		if overviewMarks == visible then
			return
		end
		overviewMarks = visible
		for _, piece in hotZone:GetDescendants() do
			if piece:IsA("BasePart") and piece:GetAttribute("OverviewFill") then
				piece.Transparency = if visible then HOT_ZONE_FILL_TRANSPARENCY else 1
			elseif piece:IsA("BillboardGui") then
				piece.Enabled = visible
			end
		end
	end

	model.Parent = parent

	local slots: { [number]: CityLayout.Slot } = {}
	for _, slot in route do
		slots[slot.index] = slot
	end

	local function slotAt(index: number): CityLayout.Slot
		local slot = slots[index]
		if slot == nil then
			error(`CityBuilder: la casilla {index} no existe en la ciudad {sizeId}`, 2)
		end
		return slot
	end

	local function lotOf(index: number): CFrame
		local slot = slotAt(index)
		local center = CityLayout.lotCenter(slot)
		local position = Vector3.new(center.x, 0, center.z)
		local road = Vector3.new(slot.position.x, 0, slot.position.z)
		return CFrame.lookAt(position, road)
	end

	local function outsideLotOf(index: number): CFrame
		local slot = slotAt(index)
		local center = CityLayout.outsideLotCenter(slot)
		local position = Vector3.new(center.x, 0, center.z)
		local road = Vector3.new(slot.position.x, 0, slot.position.z)
		return CFrame.lookAt(position, road)
	end

	local handles: CityHandles = {
		model = model,
		sizeId = sizeId,
		squares = squares,
		tokens = tokens,
		positionOf = function(index: number): Vector3
			local slot = slotAt(index)
			return Vector3.new(slot.position.x, 0, slot.position.z)
		end,
		facingOf = function(index: number): number
			return slotAt(index).facing
		end,
		labelOf = function(index: number): string
			local slot = slotAt(index)
			return Strings.squareLabel(toSquare(slot), slot.ordinal)
		end,
		colorOf = function(index: number): Color3
			local slot = slotAt(index)
			return Color3.fromHex(Strings.colorFor(toSquare(slot)))
		end,
		lotOf = lotOf,
		outsideLotOf = outsideLotOf,
		setHotZone = setHotZone,
		setHotZoneOverview = setHotZoneOverview,
		refreshBackdrops = function()
			makeBackdrops(model, sizeId)
		end,
		setPrice = function(index: number, cell: WorldRules.PriceCell?)
			local tile: BasePart? = squares[index]
			local strip = if tile ~= nil then tile:FindFirstChild(PRICE_PAINT) else nil
			local prices = if strip ~= nil then strip:FindFirstChild("Prices") else nil
			if prices == nil then
				return
			end
			local caption = prices:FindFirstChild("Caption") :: TextLabel
			local value = prices:FindFirstChild("Value") :: TextLabel
			local captionText = if cell ~= nil then Strings.upper(Strings.get(cell.caption)) else ""
			local valueText = if cell ~= nil then HudRules.formatMoney(cell.amount) else ""
			if caption.Text ~= captionText then
				caption.Text = captionText
			end
			if value.Text ~= valueText then
				value.Text = valueText
			end
			if cell ~= nil then
				value.TextColor3 = Color3.fromHex(Ui.squarePrices.tones[cell.tone])
			end
		end,
		setOwner = function(index: number, color: Color3?, mortgaged: boolean?)
			local tile: BasePart? = squares[index]
			if tile == nil then
				return
			end
			local current = tile:FindFirstChild(OWNER_PLATE)
			if color == nil then
				if current ~= nil then
					current:Destroy()
				end
				return
			end
			if current ~= nil then
				current:Destroy()
			end
			makeOwnerPlate(lotOf(index), color, mortgaged).Parent = tile
		end,
		destroy = function()
			model:Destroy()
		end,
	}

	return handles
end

return CityBuilder

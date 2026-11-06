--!strict
-- Construye el lobby provisional en el servidor (todos lo ven igual y los asientos son de verdad): el parque
-- con su fuente, caminos, árboles y farolas, las mesas de juego con sus bancos, la calle alrededor y los
-- edificios. La disposición sale de `config/LobbyPark`.
--
-- Recicla mallas ya subidas (árboles, farolas, bancos y fachadas de barrio) con `InsertService`; lo que no
-- cargue se queda en su versión procedural, así que el lobby se levanta siempre.
local InsertService = game:GetService("InsertService")
local Workspace = game:GetService("Workspace")

local ArtAssets = require("../../shared/config/ArtAssets")
local LobbyPark = require("../../shared/config/LobbyPark")
local Ui = require("../../shared/config/Ui")

export type TableHandles = { seats: { Seat }, label: TextLabel, center: Vector3 }
export type World = { tables: { [string]: TableHandles }, spawn: SpawnLocation }

local LobbyWorld = {}

local GRASS = Color3.fromRGB(96, 140, 74)
local LAWN = Color3.fromRGB(108, 156, 82)
local PATH = Color3.fromRGB(205, 196, 176)
local CURB = Color3.fromRGB(180, 172, 156)
local ASPHALT = Color3.fromHex(Ui.palette.asphalt)
local LINE = Color3.fromHex(Ui.palette.limestone)
local WOOD = Color3.fromRGB(122, 84, 51)
local IRON = Color3.fromRGB(35, 40, 43)
local WATER = Color3.fromRGB(72, 160, 214)
local STONE = Color3.fromRGB(210, 201, 180)
local GLASS = Color3.fromRGB(70, 96, 120)

-- Colores de las mesas: la tapa es un tablero con el color de cada mesa en el borde.
local TABLE_COLORS = { "#F5C518", "#C4382B", "#1B3A6B", "#5A9E5A", "#E07A3C", "#9B5DE5" }

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	cframe: CFrame,
	material: Enum.Material?
): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.Size = size
	piece.Color = color
	piece.CFrame = cframe
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

local function cylinder(
	parent: Instance,
	name: string,
	height: number,
	diameter: number,
	color: Color3,
	at: Vector3,
	material: Enum.Material?
): Part
	local piece = part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		color,
		CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)),
		material
	)
	piece.Shape = Enum.PartType.Cylinder
	return piece
end

-- Mallas recicladas: se cargan una vez y se clonan. nil si no cargó.
local loaded: { [string]: BasePart? } = {}

local function loadPiece(piece: ArtAssets.Piece)
	if loaded[piece.key] ~= nil then
		return
	end
	local id = tonumber(string.match(piece.assetId, "%d+"))
	local ok, model: any = pcall(function()
		return InsertService:LoadAsset(id :: number)
	end)
	local mesh = if ok then model:FindFirstChildWhichIsA("BasePart", true) else nil
	if mesh == nil then
		warn(`LobbyWorld: no se pudo cargar {piece.key}`)
		return
	end
	mesh.Anchored = true
	mesh.Color = Color3.fromRGB(piece.color[1], piece.color[2], piece.color[3])
	mesh.Material = (Enum.Material :: any)[piece.material]
	mesh.Parent = nil
	loaded[piece.key] = mesh
end

-- Pone las mallas de un grupo de `ArtAssets.street` con el origen en el centro de su base. Devuelve false si
-- falta alguna (entonces se deja la versión procedural).
local function placeArt(parent: Instance, group: string, origin: CFrame, collide: boolean): boolean
	local pieces = ArtAssets.street[group]
	if pieces == nil then
		return false
	end
	for _, piece in pieces do
		if loaded[piece.key] == nil then
			return false
		end
	end
	for _, piece in pieces do
		local source = loaded[piece.key] :: BasePart
		local mesh = source:Clone()
		mesh.CFrame = origin * source.CFrame
		mesh.CanCollide = collide
		mesh.Parent = parent
	end
	return true
end

local function proceduralTree(parent: Instance, at: Vector3)
	cylinder(parent, "Trunk", 7, 1.4, WOOD, at + Vector3.new(0, 3.5, 0), Enum.Material.Wood)
	local crown = part(
		parent,
		"Crown",
		Vector3.new(9, 8, 9),
		Color3.fromRGB(75, 107, 58),
		CFrame.new(at + Vector3.new(0, 10, 0)),
		Enum.Material.Grass
	)
	crown.Shape = Enum.PartType.Ball
end

local function proceduralLamp(parent: Instance, at: Vector3)
	cylinder(parent, "Post", 12, 0.6, IRON, at + Vector3.new(0, 6, 0), Enum.Material.Metal)
	local bulb = part(
		parent,
		"Bulb",
		Vector3.new(1.6, 1.6, 1.6),
		Color3.fromRGB(255, 236, 190),
		CFrame.new(at + Vector3.new(0, 12.4, 0)),
		Enum.Material.Neon
	)
	bulb.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 0.6
	light.Color = Color3.fromRGB(255, 226, 170)
	light.Parent = bulb
end

-- Fuente del centro: pilón de piedra, agua, columna y dos tazas con chorros.
local function buildFountain(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Fountain"
	folder.Parent = parent
	local r = LobbyPark.FOUNTAIN_RADIUS
	cylinder(folder, "Plaza", 0.3, r * 2 + 16, PATH, Vector3.new(0, 0.15, 0), Enum.Material.Pavement)
	cylinder(folder, "Basin", 2.4, r * 2, STONE, Vector3.new(0, 1.2, 0), Enum.Material.Limestone)
	local water =
		cylinder(folder, "Water", 0.4, r * 2 - 2, WATER, Vector3.new(0, 2.2, 0), Enum.Material.Glass)
	water.Transparency = 0.25
	water.CanCollide = false
	cylinder(folder, "Column", 7, 2.4, STONE, Vector3.new(0, 5, 0), Enum.Material.Limestone)
	cylinder(folder, "Bowl", 1, 9, STONE, Vector3.new(0, 7.2, 0), Enum.Material.Limestone)
	cylinder(folder, "TopColumn", 3, 1.4, STONE, Vector3.new(0, 9, 0), Enum.Material.Limestone)
	cylinder(folder, "TopBowl", 0.8, 4.5, STONE, Vector3.new(0, 10.6, 0), Enum.Material.Limestone)
	local spout =
		part(folder, "Spout", Vector3.new(1, 1, 1), WATER, CFrame.new(0, 11.2, 0), Enum.Material.Glass)
	spout.Transparency = 1
	spout.CanCollide = false
	local spray = Instance.new("ParticleEmitter")
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 230, 250))
	spray.LightEmission = 0.3
	spray.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.15) })
	spray.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	spray.Lifetime = NumberRange.new(1.1, 1.5)
	spray.Rate = 70
	spray.Speed = NumberRange.new(9, 12)
	spray.SpreadAngle = Vector2.new(18, 18)
	spray.Acceleration = Vector3.new(0, -22, 0)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Parent = spout
end

-- Una mesa de juego: tapa de tablero con su color, patas, cartel y un banco por puesto.
local function buildTable(parent: Instance, data: LobbyPark.Table, order: number): TableHandles
	local folder = Instance.new("Model")
	folder.Name = data.id
	folder.Parent = parent
	local center = Vector3.new(data.x, 0, data.z)
	local accent = Color3.fromHex(TABLE_COLORS[(order - 1) % #TABLE_COLORS + 1])
	local radius = LobbyPark.seatRadius(data.seats)
	cylinder(
		folder,
		"Rug",
		0.2,
		radius * 2 + 7,
		PATH,
		center + Vector3.new(0, 0.1, 0),
		Enum.Material.Pavement
	)
	cylinder(folder, "Leg", 3, 1.6, IRON, center + Vector3.new(0, 1.5, 0), Enum.Material.Metal)
	local top = radius * 2 - 4.5
	cylinder(folder, "Top", 0.6, top, accent, center + Vector3.new(0, 3.3, 0), Enum.Material.Wood)
	cylinder(
		folder,
		"Board",
		0.2,
		top - 1.6,
		Color3.fromHex(Ui.palette.limestone),
		center + Vector3.new(0, 3.65, 0)
	)
	-- Un pequeño tablero: casillas de colores alrededor del borde.
	for i = 1, 12 do
		local angle = (i - 1) / 12 * math.pi * 2
		local at = center
			+ Vector3.new(math.cos(angle) * (top / 2 - 1.6), 3.78, math.sin(angle) * (top / 2 - 1.6))
		part(
			folder,
			"Square",
			Vector3.new(1.2, 0.08, 1.2),
			Color3.fromHex(TABLE_COLORS[(i - 1) % #TABLE_COLORS + 1]),
			CFrame.new(at) * CFrame.Angles(0, -angle, 0)
		)
	end
	local seats: { Seat } = {}
	for i, spot in LobbyPark.seatsOf(data) do
		local frame = CFrame.new(spot.x, 0, spot.z) * CFrame.Angles(0, spot.yaw, 0)
		local seat = Instance.new("Seat")
		seat.Name = `Puesto{i}`
		seat.Anchored = true
		seat.Size = Vector3.new(2.6, 0.6, 2.4)
		seat.Color = Color3.fromRGB(122, 84, 51)
		seat.Material = Enum.Material.Wood
		seat.CFrame = frame * CFrame.new(0, 1.9, 0)
		seat.TopSurface = Enum.SurfaceType.Smooth
		seat.Parent = folder
		-- Respaldo y patas, del color de la mesa: se ve de lejos a qué mesa pertenece.
		part(folder, "Back", Vector3.new(2.6, 2.4, 0.3), accent, frame * CFrame.new(0, 3.2, 1.2))
		part(
			folder,
			"Legs",
			Vector3.new(2.2, 1.6, 2),
			IRON,
			frame * CFrame.new(0, 0.8, 0),
			Enum.Material.Metal
		)
		table.insert(seats, seat)
	end
	-- Cartel de la mesa: nombre, puestos y cuenta atrás. Lo actualiza `TableService`.
	local post =
		part(folder, "SignAnchor", Vector3.new(1, 1, 1), IRON, CFrame.new(center + Vector3.new(0, 11, 0)))
	post.Transparency = 1
	post.CanCollide = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 74)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Parent = post
	local plate = Instance.new("Frame")
	plate.Size = UDim2.fromScale(1, 1)
	plate.BackgroundColor3 = Color3.fromHex(Ui.palette.asphalt)
	plate.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = plate
	local rim = Instance.new("UIStroke")
	rim.Color = accent
	rim.Thickness = 3
	rim.Parent = plate
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -12, 0.5, 0)
	title.Position = UDim2.fromOffset(6, 2)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = accent
	title.Text = `MESA {order} · {data.seats} JUGADORES`
	title.Parent = plate
	local label = Instance.new("TextLabel")
	label.Name = "Status"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -12, 0.45, 0)
	label.Position = UDim2.new(0, 6, 0.5, 0)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromHex(Ui.palette.limestone)
	label.Text = ""
	label.Parent = plate
	return { seats = seats, label = label, center = center }
end

-- Edificio procedural: bloque con plantas de ventanas, cornisa y un bajo con escaparate.
local function proceduralBuilding(parent: Instance, data: LobbyPark.Building)
	local frame = CFrame.new(data.x, 0, data.z) * CFrame.Angles(0, data.yaw, 0)
	local color = Color3.fromHex(data.color)
	part(
		parent,
		"Body",
		Vector3.new(data.width, data.height, data.depth),
		color,
		frame * CFrame.new(0, data.height / 2, 0),
		Enum.Material.Concrete
	)
	part(
		parent,
		"Cornice",
		Vector3.new(data.width + 1, 1.2, data.depth + 1),
		CURB,
		frame * CFrame.new(0, data.height + 0.6, 0),
		Enum.Material.Limestone
	)
	-- Ventanas en la fachada que mira al parque (-Z local).
	local floors = math.floor((data.height - 8) / 7)
	for floor = 1, floors do
		local y = 8 + (floor - 0.5) * 7
		local columns = math.max(2, math.floor(data.width / 7))
		for c = 1, columns do
			local x = -data.width / 2 + (c - 0.5) * data.width / columns
			part(
				parent,
				"Window",
				Vector3.new(3.2, 4, 0.3),
				GLASS,
				frame * CFrame.new(x, y, -data.depth / 2 - 0.1),
				Enum.Material.Glass
			)
		end
	end
	-- Escaparate del bajo, con toldo del color de la casa.
	part(
		parent,
		"Shopfront",
		Vector3.new(data.width - 6, 5, 0.3),
		GLASS,
		frame * CFrame.new(0, 3, -data.depth / 2 - 0.1),
		Enum.Material.Glass
	)
	part(
		parent,
		"Awning",
		Vector3.new(data.width - 4, 0.4, 3),
		color:Lerp(Color3.new(0, 0, 0), 0.35),
		frame * CFrame.new(0, 6, -data.depth / 2 - 1.5) * CFrame.Angles(math.rad(-12), 0, 0)
	)
end

function LobbyWorld.build(): World
	local root = Instance.new("Folder")
	root.Name = "LobbyPark"
	root.Parent = Workspace

	-- Mallas recicladas, en paralelo: se piden antes de construir y se usan al final si llegaron.
	local wanted: { ArtAssets.Piece } = {}
	for _, group in { "Tree", "Lamp", "Bench" } do
		local pieces: { ArtAssets.Piece } = ArtAssets.street[group] or {}
		for _, piece in pieces do
			table.insert(wanted, piece)
		end
	end
	for _, building in LobbyPark.buildings() do
		if building.art ~= nil then
			local pieces: { ArtAssets.Piece } = ArtAssets.street[building.art :: string] or {}
			for _, piece in pieces do
				table.insert(wanted, piece)
			end
		end
	end
	local pending = #wanted
	for _, piece in wanted do
		task.spawn(function()
			loadPiece(piece)
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < 12 do
		waited += task.wait(0.1)
	end

	local half = LobbyPark.PARK_HALF
	local outer = half + LobbyPark.SIDEWALK + LobbyPark.STREET
	-- Suelo, césped del parque, acera, calle y la acera de los edificios.
	part(
		root,
		"Ground",
		Vector3.new(outer * 2 + 200, 1, outer * 2 + 200),
		GRASS,
		CFrame.new(0, -0.5, 0),
		Enum.Material.Grass
	)
	local street = outer * 2
	part(
		root,
		"Street",
		Vector3.new(street, 0.2, street),
		ASPHALT,
		CFrame.new(0, 0.1, 0),
		Enum.Material.Asphalt
	)
	local walk = (half + LobbyPark.SIDEWALK) * 2
	part(root, "Sidewalk", Vector3.new(walk, 0.4, walk), PATH, CFrame.new(0, 0.2, 0), Enum.Material.Pavement)
	part(
		root,
		"Lawn",
		Vector3.new(half * 2, 0.5, half * 2),
		LAWN,
		CFrame.new(0, 0.25, 0),
		Enum.Material.Grass
	)
	-- Raya discontinua en el centro de la calle.
	local mid = half + LobbyPark.SIDEWALK + LobbyPark.STREET / 2
	for side = 0, 3 do
		local yaw = side * math.pi / 2
		for i = -8, 8 do
			local frame = CFrame.Angles(0, yaw, 0) * CFrame.new(i * 12, 0.22, mid)
			part(root, "Dash", Vector3.new(6, 0.05, 0.6), LINE, frame)
		end
	end
	-- Caminos en cruz y anillo alrededor de la fuente.
	part(root, "PathNS", Vector3.new(8, 0.56, half * 2), PATH, CFrame.new(0, 0.28, 0), Enum.Material.Pavement)
	part(root, "PathEW", Vector3.new(half * 2, 0.56, 8), PATH, CFrame.new(0, 0.28, 0), Enum.Material.Pavement)
	buildFountain(root)

	local world: World = { tables = {}, spawn = nil :: any }
	for order, data in LobbyPark.tables() do
		world.tables[data.id] = buildTable(root, data, order)
	end

	-- Árboles y farolas, reciclados si cargaron.
	for _, tree in LobbyPark.trees() do
		local at = Vector3.new(tree.x, 0.5, tree.z)
		if not placeArt(root, "Tree", CFrame.new(at), true) then
			proceduralTree(root, at)
		end
	end
	for _, spot in
		{
			{ 18, 18 },
			{ -18, 18 },
			{ 18, -18 },
			{ -18, -18 },
			{ 0, half - 2 },
			{ 0, -(half - 2) },
			{ half - 2, 0 },
			{ -(half - 2), 0 },
		}
	do
		local at = Vector3.new(spot[1], 0.5, spot[2])
		if not placeArt(root, "Lamp", CFrame.new(at), true) then
			proceduralLamp(root, at)
		end
	end
	-- Bancos de paseo junto a los caminos (decoración: los de las mesas son los que cuentan).
	for _, spot in { { 7, 30, -math.pi / 2 }, { -7, -30, math.pi / 2 }, { 30, -7, 0 }, { -30, 7, math.pi } } do
		placeArt(root, "Bench", CFrame.new(spot[1], 0.5, spot[2]) * CFrame.Angles(0, spot[3], 0), true)
	end

	-- Edificios alrededor: fachada reciclada donde la hay; si no, el procedural.
	for _, building in LobbyPark.buildings() do
		local frame = CFrame.new(building.x, 0, building.z) * CFrame.Angles(0, building.yaw, 0)
		if building.art == nil or not placeArt(root, building.art, frame, true) then
			proceduralBuilding(root, building)
		end
	end

	-- Aparición en el camino sur, mirando a la fuente.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 0.6, 8)
	spawn.CFrame = CFrame.new(0, 0.6, half - 14)
	spawn.Color = PATH
	spawn.Material = Enum.Material.Pavement
	spawn.Transparency = 0
	spawn.Parent = root
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal ~= nil then
		decal:Destroy()
	end
	world.spawn = spawn
	return world
end

return LobbyWorld

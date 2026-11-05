--!strict
-- Ficha provisional del jugador y recorrido por la ruta. Arte gris: una caja con un asiento, sin
-- detalle, que solo sirve para comprobar que el avatar sube y que la ficha recorre la calle en el
-- tiempo previsto.
--
-- La ficha guarda su tamaño en un atributo, así que `ride` y `place` resuelven sus posiciones con
-- `CityLayout` sin que nadie les pase la ciudad: la geometría tiene una sola fuente. El cuerpo es la
-- parte principal y las demás van soldadas a él, así que mover el cuerpo mueve la ficha entera.
local Players = game:GetService("Players")

local CameraRules = require("../camera/CameraRules")
local CityLayout = require("../../shared/config/CityLayout")

type SizeId = CityLayout.SizeId

local BODY_SIZE = Vector3.new(6, 5, 6)
local SEAT_THICKNESS = 0.3
-- El asiento gris es solo el anclaje del avatar: su centro va 0,55 por encima de la placa real para
-- que un avatar de 6 studs apoye los pies en ella (`mount` lo baja 0,15 de su altura).
local SEAT_LIFT = 0.55
local BODY_COLOR = Color3.fromRGB(96, 100, 106)
local SEAT_COLOR = Color3.fromRGB(58, 62, 68)
local ArtAssets = require("../../shared/config/ArtAssets")
local Tokens = require("../../shared/config/Tokens")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WELD_NAME = "TokenWeld"
local RIDE_STEP = 1 / 30

local TokenRider = {}

-- Altura del asiento sobre la base de la ficha, que es donde se apoyan los pies del avatar.
function TokenRider.seatHeight(): number
	return BODY_SIZE.Y + SEAT_THICKNESS
end

-- CFrame del cuerpo de la ficha en una casilla: apoyado en el suelo y girado hacia la siguiente, para
-- que el avatar mire por donde va la partida. `offset` la aparta del centro si comparte casilla.
local function cframeAt(slot: CityLayout.Slot, offset: CityLayout.TokenOffset?): CFrame
	local forward = Vector3.new(math.sin(slot.facing), 0, math.cos(slot.facing))
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local side = if offset ~= nil then offset.side else 0
	local along = if offset ~= nil then offset.along else 0
	local base = Vector3.new(slot.position.x, 0, slot.position.z) + right * side + forward * along
	local bodyCenter = base + Vector3.new(0, BODY_SIZE.Y / 2, 0)
	return CFrame.lookAt(bodyCenter, bodyCenter + forward)
end

local function part(name: string, size: Vector3, color: Color3, parent: Instance, anchored: boolean): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.Color = color
	piece.Material = Enum.Material.SmoothPlastic
	-- Solo el cuerpo va anclado. Las demás piezas quedan sueltas y soldadas a él: una `WeldConstraint`
	-- entre dos piezas ancladas no mueve ninguna, y la ficha se quedaría quieta en el recorrido.
	piece.Anchored = anchored
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

local function weldTo(list: { BasePart }, body: BasePart)
	for _, piece in list do
		local weld = Instance.new("WeldConstraint")
		weld.Name = WELD_NAME
		weld.Part0 = body
		weld.Part1 = piece
		weld.Parent = piece
	end
end

-- Crea la ficha de un asiento. `ownerId` es el id del jugador en el motor (el userId en texto),
-- que también vale para un bot: una ficha no necesita un `Player` para existir. `color` es el color
-- del jugador: tiñe la placa del asiento, que es lo que la identifica. `tokenId` elige el vehículo
-- del catálogo `Tokens`; sin uno válido cae al taxi para no dejar a nadie sin ficha.
function TokenRider.create(
	ownerId: string,
	sizeId: SizeId,
	color: Color3,
	parent: Instance,
	tokenId: string
): Model
	local spec = Tokens.get(tokenId) or Tokens.get("taxi")
	if spec == nil then
		error("TokenRider: no hay fichas en el catálogo", 2)
	end
	local model = Instance.new("Model")
	model.Name = `Token_{ownerId}`
	model:SetAttribute("TokenId", spec.id)

	local body = part("Body", BODY_SIZE, BODY_COLOR, model, true)
	model.PrimaryPart = body

	local stripe = part("Stripe", Vector3.new(BODY_SIZE.X + 0.2, 1.2, BODY_SIZE.Z + 0.2), color, model, false)
	stripe.CFrame = body.CFrame

	local seat = part("Seat", Vector3.new(1, SEAT_THICKNESS, 1), SEAT_COLOR, model, false)
	local seatAt = spec.art.seat
	seat.CFrame = body.CFrame * CFrame.new(seatAt[1], seatAt[2] + SEAT_LIFT - BODY_SIZE.Y / 2, seatAt[3])

	weldTo({ stripe, seat }, body)

	model:SetAttribute("SizeId", sizeId)
	model:SetAttribute("Index", 1)
	model.Parent = parent
	TokenRider.dress(model)
	return model
end

-- Ficha oculta durante una escena (la detención la aparta mientras el detenido va en la patrulla). Cada
-- pieza guarda su transparencia de antes, así que mostrarla devuelve la ficha tal como estaba: el cuerpo y
-- la franja del taxi ya son invisibles y siguen así. Se guarda en un atributo de la pieza: en una tabla débil
-- las Instance se pierden aunque sigan vivas, y la ficha no volvía a verse.
local HIDDEN_ATTRIBUTE = "Hidden"
local SAVED_TRANSPARENCY = "SavedTransparency"

-- Oculta la ficha entera. Se puede repetir: las piezas que aparezcan después (el taxi) también se ocultan.
function TokenRider.hide(token: Model)
	token:SetAttribute(HIDDEN_ATTRIBUTE, true)
	for _, piece in token:GetDescendants() do
		if piece:IsA("BasePart") then
			if piece:GetAttribute(SAVED_TRANSPARENCY) == nil then
				piece:SetAttribute(SAVED_TRANSPARENCY, piece.Transparency)
			end
			piece.Transparency = 1
		end
	end
end

-- Devuelve la ficha a su transparencia de antes. Sin ocultar, no hace nada.
function TokenRider.show(token: Model)
	token:SetAttribute(HIDDEN_ATTRIBUTE, nil)
	for _, piece in token:GetDescendants() do
		if piece:IsA("BasePart") then
			local original = piece:GetAttribute(SAVED_TRANSPARENCY)
			if type(original) == "number" then
				piece.Transparency = original
				piece:SetAttribute(SAVED_TRANSPARENCY, nil)
			end
		end
	end
end

function TokenRider.isHidden(token: Model): boolean
	return token:GetAttribute(HIDDEN_ATTRIBUTE) == true
end

-- Viste la ficha con su vehículo real si ya está cargado. Sin él sigue siendo la gris; se puede repetir.
local DRESSED_NAME = "DressedArt"

function TokenRider.dress(token: Model)
	local folder = ReplicatedStorage:FindFirstChild(ArtAssets.FOLDER)
	local body = token.PrimaryPart
	if folder == nil or body == nil or token:FindFirstChild(DRESSED_NAME) ~= nil then
		return
	end
	local tokenId = token:GetAttribute("TokenId")
	local spec = if type(tokenId) == "string" then Tokens.get(tokenId) else nil
	if spec == nil then
		return
	end
	local origin = body.CFrame * CFrame.new(0, -BODY_SIZE.Y / 2, 0)
	local dressed = Instance.new("Folder")
	dressed.Name = DRESSED_NAME
	local pieces: { BasePart } = {}
	local plate: BasePart? = nil
	for _, piece in spec.art.pieces do
		local source = folder:FindFirstChild(piece.key)
		if source == nil or not source:IsA("BasePart") then
			dressed:Destroy()
			return
		end
		local mesh = source:Clone()
		mesh.CFrame = origin * source.CFrame
		mesh.Anchored = false
		mesh.Parent = dressed
		table.insert(pieces, mesh)
		if piece.key == spec.art.plate then
			plate = mesh
		end
	end
	weldTo(pieces, body)
	dressed.Parent = token
	-- El cuerpo y la franja siguen moviendo la ficha, pero ya no se ven.
	body.Transparency = 1
	local stripe = token:FindFirstChild("Stripe")
	local playerColor = BODY_COLOR
	if stripe ~= nil and stripe:IsA("BasePart") then
		playerColor = stripe.Color
		stripe.Transparency = 1
	end
	-- La placa del techo se tiñe con el color del jugador: es su marca en la ciudad.
	if plate ~= nil then
		plate.Color = playerColor
		plate.Material = Enum.Material.SmoothPlastic
	end
	-- El asiento gris era solo el anclaje del avatar; la placa real ocupa su sitio.
	local seat = token:FindFirstChild("Seat")
	if seat ~= nil and seat:IsA("BasePart") then
		seat.Transparency = 1
		seat:SetAttribute(SAVED_TRANSPARENCY, 1)
	end
	-- Si la ficha estaba oculta, el vehículo recién puesto también se oculta. El cuerpo y la franja ya son
	-- invisibles, así que se guardan con transparencia 1: `show` no debe devolverlos visibles.
	if TokenRider.isHidden(token) then
		body:SetAttribute(SAVED_TRANSPARENCY, 1)
		if stripe ~= nil and stripe:IsA("BasePart") then
			stripe:SetAttribute(SAVED_TRANSPARENCY, 1)
		end
		TokenRider.hide(token)
	end
end

local function bodyOf(token: Model): BasePart
	local primary = token.PrimaryPart
	if primary == nil or not primary:IsA("BasePart") then
		local body = token:FindFirstChild("Body")
		if body == nil or not body:IsA("BasePart") then
			error("TokenRider: la ficha no tiene cuerpo", 2)
		end
		token.PrimaryPart = body
		primary = body
	end
	return primary :: BasePart
end

local function seatOf(token: Model): BasePart
	local seat = token:FindFirstChild("Seat")
	if seat == nil or not seat:IsA("BasePart") then
		error("TokenRider: la ficha no tiene asiento", 2)
	end
	return seat :: BasePart
end

local function routeOf(token: Model): { CityLayout.Slot }
	local sizeId = token:GetAttribute("SizeId")
	if type(sizeId) ~= "string" then
		error("TokenRider: la ficha no dice a qué tamaño de ciudad pertenece", 2)
	end
	return CityLayout.routeFor(sizeId :: SizeId)
end

-- La casilla se acota a la ruta en vez de reventar: una ficha con un número de otra ciudad no puede
-- llevarse por delante el bucle del cliente, que es lo que deja la partida sin imagen.
local function slotAt(token: Model, index: number): CityLayout.Slot
	local route = routeOf(token)
	local clamped = math.clamp(index, 1, #route)
	return route[clamped] :: CityLayout.Slot
end

local function remember(token: Model, index: number, offset: CityLayout.TokenOffset?)
	token:SetAttribute("Index", index)
	token:SetAttribute("Side", if offset ~= nil then offset.side else 0)
	token:SetAttribute("Along", if offset ~= nil then offset.along else 0)
end

-- Coloca la ficha en una casilla sin animación. Se usa al entrar en la partida y al resincronizar.
function TokenRider.place(token: Model, index: number, offset: CityLayout.TokenOffset?)
	bodyOf(token).CFrame = cframeAt(slotAt(token, index), offset)
	remember(token, index, offset)
end

-- ¿La ficha ya está en esa casilla y en ese sitio de la casilla?
function TokenRider.isAt(token: Model, index: number, offset: CityLayout.TokenOffset): boolean
	return token:GetAttribute("Index") == index
		and token:GetAttribute("Side") == offset.side
		and token:GetAttribute("Along") == offset.along
end

-- Pone el avatar en `idle` o `walk` con las animaciones de su propio `Animate`. Ese script se apaga porque, soldado
-- y en estado Physics, se queda para siempre en la pose de caída. Sin animaciones, el avatar queda en su pose de
-- reposo, que también vale. Nunca lanza: un avatar raro no puede parar una escena.
function TokenRider.setAvatarMotion(player: Player, motion: "idle" | "walk")
	pcall(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if character == nil or animator == nil then
			return
		end
		local animate = character:FindFirstChild("Animate")
		if animate ~= nil and animate:IsA("BaseScript") then
			animate.Enabled = false
		end
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0.1)
		end
		local folder = animate and animate:FindFirstChild(motion)
		local animation = folder and folder:FindFirstChildWhichIsA("Animation")
		if animation ~= nil then
			local track = animator:LoadAnimation(animation)
			track.Looped = true
			track:Play(0.1)
		end
	end)
end

-- Sube el avatar a la ficha: lo deja de pie sobre el asiento y soldado a él, sin poder caminar ni
-- saltar. Mirar alrededor sigue funcionando porque es cosa de la cámara, no del personaje.
function TokenRider.mount(player: Player, token: Model)
	local character = player.Character
	if character == nil then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return false
	end

	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	-- Que el motor no intente levantarlo ni moverlo: aquí el avatar no tiene piernas propias.
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	local existing = root:FindFirstChild(WELD_NAME)
	if existing then
		existing:Destroy()
	end

	local seat = seatOf(token)
	-- Altura de los ojos del avatar: con un avatar mínimo o máximo la cámara acaba por encima del
	-- asiento, nunca dentro de la ficha ni por debajo del suelo.
	local height = humanoid.HipHeight + root.Size.Y
	local offset = CameraRules.seatOffset(height)
	root.CFrame = seat.CFrame * CFrame.new(0, offset - root.Size.Y / 2, 0)

	local weld = Instance.new("WeldConstraint")
	weld.Name = WELD_NAME
	weld.Part0 = root
	weld.Part1 = seat
	weld.Parent = root
	TokenRider.setAvatarMotion(player, "idle")
	token:SetAttribute("Rider", player.UserId)
	return true
end

-- Pone el avatar de pie sobre `anchor`, una pieza anclada en el suelo, y lo suelda a ella: quien mueva la
-- pieza mueve al jugador. Es el sitio de la detención antes de subirlo a la patrulla. False si el avatar no
-- está listo, y entonces el llamador usa otro relleno.
function TokenRider.standOn(player: Player, anchor: BasePart): boolean
	local character = player.Character
	if character == nil then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		return false
	end
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	local existing = root:FindFirstChild(WELD_NAME)
	if existing then
		existing:Destroy()
	end
	-- La cadera del avatar queda a la altura que tendría de pie sobre el suelo, con los pies en `anchor`.
	root.CFrame = anchor.CFrame * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Name = WELD_NAME
	weld.Part0 = root
	weld.Part1 = anchor
	weld.Parent = root
	TokenRider.setAvatarMotion(player, "idle")
	return true
end

-- Oculta o muestra el avatar solo para este cliente (LocalTransparencyModifier): el resto del grupo sigue
-- viendo el suyo, como debe.
function TokenRider.setAvatarHidden(player: Player, hidden: boolean)
	local character = player.Character
	if character == nil then
		return
	end
	for _, piece in character:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

-- ¿El avatar del jugador está soldado a esta ficha? Una ciudad reconstruida deja soldaduras a fichas
-- que ya no existen, así que no basta con que haya una.
function TokenRider.isMounted(player: Player, token: Model): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local weld = root and root:FindFirstChild(WELD_NAME)
	return weld ~= nil and weld:IsA("WeldConstraint") and weld.Part1 == token:FindFirstChild("Seat")
end

-- Suelta la soldadura del avatar. La velocidad sigue a cero: la partida no permite andar por la
-- ciudad, y volver a moverse es cosa de `CameraDirector` cuando la escena lo permita.
function TokenRider.dismount(token: Model)
	local rider = token:GetAttribute("Rider")
	if rider == nil then
		return
	end
	for _, player in Players:GetPlayers() do
		if player.UserId == rider and player.Character then
			local root = player.Character:FindFirstChild("HumanoidRootPart")
			local weld = root and root:FindFirstChild(WELD_NAME)
			if weld then
				weld:Destroy()
			end
		end
	end
	token:SetAttribute("Rider", nil)
end

-- Lleva la ficha por la ruta en, como máximo, `Scenes.maxRideSec` segundos. `path` son números de
-- casilla en orden. `arrival` es su sitio en la última casilla, para que no pise a quien ya esté allí.
-- Devuelve la duración real usada, para que quien la llame sepa cuánto esperar.
function TokenRider.ride(
	token: Model,
	path: { number },
	durationSec: number,
	arrival: CityLayout.TokenOffset?
): number
	local body = bodyOf(token)
	local seconds = CameraRules.rideSeconds(durationSec)
	if #path == 0 then
		return 0
	end

	local targets: { number } = {}
	local route = routeOf(token)
	for _, index in path do
		if route[index] ~= nil then
			table.insert(targets, index)
		end
	end
	if #targets == 0 then
		return 0
	end

	local step = seconds / #targets
	for order, index in targets do
		local offset = if order == #targets then arrival else nil
		local from = body.CFrame
		local to = cframeAt(route[index] :: CityLayout.Slot, offset)
		local elapsed = 0
		while elapsed < step do
			elapsed += task.wait(RIDE_STEP)
			local alpha = math.min(1, elapsed / step)
			-- Suavizado para que el arranque y la frenada no den tirones.
			local eased = alpha * alpha * (3 - 2 * alpha)
			body.CFrame = from:Lerp(to, eased)
		end
		body.CFrame = to
		remember(token, index, offset)
	end
	return seconds
end

-- Burbuja efímera sobre la ficha: es como se ven los emotes del grupo. Se destruye sola; dos seguidos
-- reemplazan la anterior en vez de apilarse.
local BUBBLE_NAME = "EmoteBubble"

function TokenRider.bubble(token: Model, text: string, seconds: number?)
	local existing = token:FindFirstChild(BUBBLE_NAME)
	if existing then
		existing:Destroy()
	end
	local anchor = token:FindFirstChild("Seat") or token.PrimaryPart
	if anchor == nil then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = BUBBLE_NAME
	billboard.Size = UDim2.fromScale(8, 8)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard

	task.delay(seconds or 2.5, function()
		if billboard.Parent then
			billboard:Destroy()
		end
	end)
end

return TokenRider

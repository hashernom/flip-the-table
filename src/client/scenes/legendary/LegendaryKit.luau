--!strict
-- Piezas comunes de las cinco escenas legendarias: el bucle por fotograma, el cielo de tormenta, las piezas
-- sueltas, los billetes y el plano de toda la ciudad. Cada escena lo usa como `Arrest` usa sus funciones
-- locales: aquí no hay reglas, solo `Instance` y cámara.
local Lighting = game:GetService("Lighting")

local CameraDirector = require("../../camera/CameraDirector")
local CameraShots = require("../../../shared/config/CameraShots")
local CityBuilder = require("../../world/CityBuilder")
local CityLayout = require("../../../shared/config/CityLayout")
local LegendaryRules = require("./LegendaryRules")
local SceneDirector = require("../SceneDirector")
local Strings = require("../../../shared/config/Strings")
local Theme = require("../../ui/Theme")

type Context = SceneDirector.Context

export type Options = {
	director: CameraDirector.Director,
	city: () -> CityBuilder.CityHandles?,
	token: (id: string) -> Model?,
	log: (message: string) -> (),
}

-- Lo que la escena tiene en marcha: su carpeta de piezas y si la cortaron.
export type Run = {
	props: Folder,
	cancelled: boolean,
	finished: boolean,
}

export type Sky = { set: (alpha: number) -> (), restore: () -> () }

local LegendaryKit = {}

-- Pieza anclada que no choca, no se toca ni se consulta: atrezo de escena.
function LegendaryKit.part(parent: Instance, name: string, size: Vector3, color: Color3, cframe: CFrame): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.CastShadow = false
	piece.Material = Enum.Material.SmoothPlastic
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Size = size
	piece.Color = color
	piece.CFrame = cframe
	piece.Parent = parent
	return piece
end

-- Carpeta de piezas de una escena, dentro de la ciudad: se borra entera al acabar.
function LegendaryKit.begin(handles: CityBuilder.CityHandles, name: string): Run
	local props = Instance.new("Folder")
	props.Name = name
	props.Parent = handles.model
	return { props = props, cancelled = false, finished = false }
end

-- Bucle por fotograma de una escena: llama a `step(t, dt)` hasta la duración o hasta que la corten, y
-- descuenta el tiempo del director con `ctx.spent`. Un fallo se registra y corta la escena; `finish` va
-- siempre al final, con fallo o sin él.
function LegendaryKit.play(
	ctx: Context,
	run: Run,
	label: string,
	log: (message: string) -> (),
	step: (t: number, dt: number) -> (),
	finish: () -> ()
)
	local duration = ctx.duration
	local ok, err = pcall(function()
		local t = 0
		step(0, 0)
		while t < duration and not run.cancelled do
			local dt = task.wait()
			if run.cancelled then
				break
			end
			t += dt
			ctx.spent(dt)
			step(math.min(t, duration), dt)
		end
	end)
	if not ok then
		log(`{label}: la escena falló: {tostring(err)}`)
	end
	finish()
end

-- Borra las piezas de una escena. Nunca lanza.
function LegendaryKit.clear(run: Run)
	pcall(function()
		run.props:Destroy()
	end)
end

-- Cielo de tormenta: `set(alpha)` lleva la luz de la de antes (0) a la de tormenta (1), y `restore` deja
-- exactamente lo que había.
function LegendaryKit.sky(stormBrightness: number, ambient: string, fogEnd: number, fogColor: string): Sky
	local saved = {
		brightness = Lighting.Brightness,
		outdoor = Lighting.OutdoorAmbient,
		ambient = Lighting.Ambient,
		fogEnd = Lighting.FogEnd,
		fogColor = Lighting.FogColor,
	}
	local stormAmbient = Color3.fromHex(ambient)
	local stormFog = Color3.fromHex(fogColor)
	return {
		set = function(alpha: number)
			local a = math.clamp(alpha, 0, 1)
			Lighting.Brightness = saved.brightness
				+ (saved.brightness * stormBrightness - saved.brightness) * a
			Lighting.OutdoorAmbient = saved.outdoor:Lerp(stormAmbient, a)
			Lighting.Ambient = saved.ambient:Lerp(stormAmbient, a * 0.6)
			Lighting.FogEnd = saved.fogEnd + (math.min(saved.fogEnd, fogEnd) - saved.fogEnd) * a
			Lighting.FogColor = saved.fogColor:Lerp(stormFog, a)
		end,
		restore = function()
			Lighting.Brightness = saved.brightness
			Lighting.OutdoorAmbient = saved.outdoor
			Lighting.Ambient = saved.ambient
			Lighting.FogEnd = saved.fogEnd
			Lighting.FogColor = saved.fogColor
		end,
	}
end

-- Puntos de las casillas de la ciudad, en el orden de la ruta, y su centro y lado.
function LegendaryKit.routePoints(sizeId: CityLayout.SizeId): ({ LegendaryRules.Point }, { [number]: number })
	local points: { LegendaryRules.Point } = {}
	local orderOf: { [number]: number } = {}
	for order, slot in CityLayout.routeFor(sizeId) do
		table.insert(points, { x = slot.position.x, z = slot.position.z })
		orderOf[slot.index] = order
	end
	return points, orderOf
end

-- Plano de toda la ciudad: a `facing` del centro, a la distancia que pide su tamaño. `snap` lo pone de golpe.
function LegendaryKit.wide(
	director: CameraDirector.Director,
	sizeId: CityLayout.SizeId,
	facing: number,
	snap: boolean?
)
	local points = LegendaryKit.routePoints(sizeId)
	local center, span = LegendaryRules.center(points)
	local wide = CameraShots.legendWide
	director.setSceneFocus(Vector3.new(center.x, 0, center.z), {
		back = span * wide.backPerSpan,
		inward = 0,
		up = span * wide.upPerSpan,
		ahead = 0,
		focusUp = wide.focusUp,
		fixedSide = true,
	}, facing, snap)
end

-- Cartel que flota en `position`, siempre de cara a la cámara: placa de color con texto en mayúsculas y
-- borde de caliza, como los sellos de la interfaz. `tilt` lo tuerce. Devuelve la placa, para animarla.
function LegendaryKit.sign(
	parent: Instance,
	position: Vector3,
	text: string,
	width: number,
	height: number,
	color: string,
	tilt: number?
): Frame
	local anchor =
		LegendaryKit.part(parent, "SignAnchor", Vector3.new(1, 1, 1), Color3.new(), CFrame.new(position))
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(width, height)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local plate = Instance.new("Frame")
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.Size = UDim2.fromScale(1, 1)
	plate.BackgroundColor3 = Color3.fromHex(color)
	plate.BorderSizePixel = 0
	plate.Rotation = tilt or 0
	plate.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = plate
	local rim = Instance.new("UIStroke")
	rim.Color = Theme.color.limestone
	rim.Thickness = 3
	rim.Parent = plate
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Theme.font.roadBold
	label.TextScaled = true
	label.TextColor3 = Theme.color.limestone
	label.Text = Strings.upper(text)
	label.Parent = plate
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = label
	return plate
end

-- Mueve un cartel de `sign`: su ancla está dos niveles por encima de la placa.
function LegendaryKit.moveSign(plate: Frame, position: Vector3)
	local gui = plate.Parent
	local anchor = if gui ~= nil then gui.Parent else nil
	if anchor ~= nil and anchor:IsA("BasePart") then
		anchor.CFrame = CFrame.new(position)
	end
end

-- Base de una ficha en el mundo (el suelo bajo su cuerpo).
function LegendaryKit.tokenBase(token: Model): Vector3?
	local body = token.PrimaryPart or token:FindFirstChild("Body")
	if body == nil or not body:IsA("BasePart") then
		return nil
	end
	return Vector3.new(body.Position.X, body.Position.Y - body.Size.Y / 2, body.Position.Z)
end

-- Billete: papel verde con una banda oscura. Devuelve las dos piezas; `placeBill` las mueve juntas.
function LegendaryKit.bill(parent: Instance, color: string, band: string, at: CFrame): { Part }
	local paper = LegendaryKit.part(parent, "Bill", Vector3.new(2.2, 0.08, 1.1), Color3.fromHex(color), at)
	local stripe =
		LegendaryKit.part(parent, "BillBand", Vector3.new(0.5, 0.1, 1.12), Color3.fromHex(band), at)
	return { paper, stripe }
end

function LegendaryKit.placeBill(bill: { Part }, at: CFrame)
	for _, piece in bill do
		piece.CFrame = at
	end
end

-- Piezas de un edificio por su papel (`BuildingView.ROLE`): "Addon" o "Marker". Las del nivel más alto
-- primero, para llevarse antes el último añadido.
function LegendaryKit.piecesWithRole(
	model: Model,
	role: string,
	roleAttribute: string,
	tierAttribute: string
): { BasePart }
	local found: { BasePart } = {}
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") and piece:GetAttribute(roleAttribute) == role then
			table.insert(found, piece)
		end
	end
	table.sort(found, function(a, b)
		local ta = (a:GetAttribute(tierAttribute) :: number?) or 0
		local tb = (b:GetAttribute(tierAttribute) :: number?) or 0
		return ta > tb
	end)
	return found
end

return LegendaryKit

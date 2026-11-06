--!strict
-- Escena del Ladrón de Escrituras (carta rara, plan 08 Tarea 4). La cámara viaja a la propiedad robada; a
-- mitad de escena el solar cambia al color del ladrón con un destello y sobre el edificio cae un sello rojo
-- «Robada por …». Así todo el grupo ve qué propiedad cambió de manos y quién se la llevó.
--
-- Solo muestra: el cambio de dueño ya lo decidió el servidor y llega en `ctx.view`. Si falta la ciudad o la
-- casilla, la escena espera su tiempo y el director pone el mundo como la vista al acabar.
local TweenService = game:GetService("TweenService")

local BuildingView = require("../../world/BuildingView")
local CameraShots = require("../../../shared/config/CameraShots")
local CameraDirector = require("../../camera/CameraDirector")
local CityBuilder = require("../../world/CityBuilder")
local Scenes = require("../../../shared/config/Scenes")
local SceneDirector = require("../SceneDirector")
local Strings = require("../../../shared/config/Strings")
local Theme = require("../../ui/Theme")
local Types = require("../../../shared/rules/Types")

type Context = SceneDirector.Context

export type Options = {
	director: CameraDirector.Director,
	city: () -> CityBuilder.CityHandles?,
	-- Nombre que se enseña de un jugador.
	nameOf: (view: any, id: string) -> string,
}

local DeedThief = {}

-- Sello que cae sobre el edificio: un cartel rojo con el nombre del ladrón, siempre de cara a la cámara.
local function makeStamp(lot: CFrame, text: string): BillboardGui
	local config = Scenes.deedThief
	local anchor = Instance.new("Part")
	anchor.Name = "DeedThiefStamp"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(lot.Position + Vector3.new(0, config.stampLift, 0))
	anchor.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(config.stampWidth, config.stampHeight)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor

	local plate = Instance.new("Frame")
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.Size = UDim2.fromScale(1, 1)
	plate.BackgroundColor3 = Theme.color.signal
	plate.BorderSizePixel = 0
	plate.Rotation = config.stampTilt
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
	label.Text = text
	label.Parent = plate
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = label

	-- Cae como un sello: grande y transparente, y se asienta de golpe.
	local scale = Instance.new("UIScale")
	scale.Scale = config.stampFrom
	scale.Parent = plate
	plate.BackgroundTransparency = 1
	label.TextTransparency = 1
	local info = TweenInfo.new(config.stampSec, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	TweenService:Create(scale, info, { Scale = 1 }):Play()
	TweenService:Create(plate, info, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(label, info, { TextTransparency = 0 }):Play()
	return gui
end

function DeedThief.new(options: Options): SceneDirector.Scene
	local function run(ctx: Context, event: Types.Event)
		local index = event.index
		local handles = options.city()
		if type(index) ~= "number" or handles == nil then
			ctx.wait(ctx.duration)
			return
		end
		local config = Scenes.deedThief
		local lot = handles.lotOf(index)
		-- El solar mira a la calle con su -Z: la cámara se pone en la calle, de frente a la fachada.
		local look = lot.LookVector
		options.director.setSceneFocus(lot.Position, CameraShots.deed, math.atan2(-look.X, -look.Z))

		local stamp: BillboardGui? = nil
		local ok, err = pcall(function()
			ctx.wait(ctx.duration * config.swapAt)
			-- El cambio de dueño: el solar toma el color del ladrón y el edificio destella.
			ctx.world.reconcile(ctx.view)
			BuildingView.flash(index)
			local thief = if type(event.playerId) == "string"
				then options.nameOf(ctx.view, event.playerId)
				else ""
			stamp = makeStamp(lot, Strings.upper(Strings.get("scene.deedThief.stamp", { name = thief })))
			ctx.wait(ctx.duration * (1 - config.swapAt))
		end)
		if stamp ~= nil then
			local anchor = stamp.Parent
			if anchor ~= nil then
				anchor:Destroy()
			end
		end
		options.director.setSceneFocus(nil)
		if not ok then
			error(err, 0)
		end
	end

	return { run = run }
end

return DeedThief

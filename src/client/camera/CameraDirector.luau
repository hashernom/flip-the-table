--!strict
-- Director de cámara. Decide el plano con `CameraRules` y lo aplica cada fotograma. Es el único sitio
-- del cliente que toca `Camera`: ni las escenas ni los menús mueven la cámara por su cuenta.
--
-- Regla que se ve aquí y no en `CameraRules`: una escena nunca se interrumpe, así que la petición de
-- vista general se recuerda y se abre al terminar.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraRules = require("./CameraRules")
local CameraShots = require("../../shared/config/CameraShots")
local CityLayout = require("../../shared/config/CityLayout")

type Mode = CameraRules.Mode
type SizeId = CityLayout.SizeId

export type Director = {
	update: (ctx: { riding: boolean?, sceneRunning: boolean? }, dt: number) -> Mode,
	requestOverview: (on: boolean) -> (),
	rotateOverview: (pixels: number) -> (),
	mode: () -> Mode,
	follow: (token: Model?) -> (),
	-- Foco de una escena. Con `shot` la cámara toma ese plano desde `position`, mirando hacia
	-- `facing`; sin él, la cámara se aleja con el plano por defecto. Sin posición se limpia el foco. Con
	-- `snap` la cámara va directa al plano, sin suavizado: para cortes y para seguir algo muy rápido.
	setSceneFocus: (position: Vector3?, shot: CameraShots.Shot?, facing: number?, snap: boolean?) -> (),
	-- Foco de la vista general: centro y mitad del ancho de lo que se enseña. Sin centro vuelve a la
	-- ciudad entera; lo usa la maqueta para que la cámara la encuadre a ella y no al tablero.
	setOverviewFocus: (position: Vector3?, radius: number?) -> (),
	setSize: (sizeId: SizeId) -> (),
	destroy: () -> (),
}

local CameraDirector = {}

function CameraDirector.new(player: Player, sizeId: SizeId): Director
	local camera = Workspace.CurrentCamera
	if camera == nil then
		camera = Instance.new("Camera")
		camera.Parent = Workspace
		Workspace.CurrentCamera = camera
	end

	local center = CityLayout.centerFor(sizeId)
	local cityCenter = Vector3.new(center.x, 0, center.z)
	local citySpan = CityLayout.spanFor(sizeId)

	-- El tamaño real de la partida llega en la primera vista: la ciudad se vuelve a construir y la
	-- cámara tiene que mirar al centro nuevo.
	local function setSize(nextSize: SizeId)
		local nextCenter = CityLayout.centerFor(nextSize)
		cityCenter = Vector3.new(nextCenter.x, 0, nextCenter.z)
		citySpan = CityLayout.spanFor(nextSize)
	end

	local mode: Mode = "Turn"
	local overviewWanted = false
	local followToken: Model? = nil
	local sceneFocus: Vector3? = nil
	local sceneShot: CameraShots.Shot? = nil
	local sceneFacing = 0
	local sceneSnap = false
	local spin = 0
	local overviewFocus: Vector3? = nil
	local overviewRadius: number? = nil
	player.CameraMode = Enum.CameraMode.Classic

	local function bodyOf(token: Model?): BasePart?
		if token == nil then
			return nil
		end
		local body = token.PrimaryPart or token:FindFirstChild("Body")
		return if body ~= nil and body:IsA("BasePart") then body else nil
	end

	local function apply(target: CFrame, dt: number)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = camera.CFrame:Lerp(target, CameraRules.followAlpha(CameraShots.followRate, dt))
	end

	-- Plano sobre la ficha que se sigue. Sin ficha, una vista de la ciudad: nunca se queda en blanco.
	local function shotTarget(shot: CameraShots.Shot): CFrame
		local body = bodyOf(followToken)
		if body == nil then
			return CFrame.lookAt(cityCenter + Vector3.new(0, 120, 120), cityCenter)
		end
		local look = body.CFrame.LookVector
		local base = body.Position
		local eye, focus = CameraRules.pose(
			shot,
			{ x = base.X, y = base.Y - body.Size.Y / 2, z = base.Z },
			math.atan2(look.X, look.Z)
		)
		return CFrame.lookAt(Vector3.new(eye.x, eye.y, eye.z), Vector3.new(focus.x, focus.y, focus.z))
	end

	local function overviewTarget(): CFrame
		local center = overviewFocus or cityCenter
		local span = if overviewRadius ~= nil then overviewRadius * 2 else citySpan
		local eye, focus = CameraRules.overviewPose({ x = center.X, y = center.Y, z = center.Z }, span, spin)
		return CFrame.lookAt(Vector3.new(eye.x, eye.y, eye.z), Vector3.new(focus.x, focus.y, focus.z))
	end

	-- Hasta que cada escena tenga su cámara (plan 08), se ve desde el plano del turno.
	local function sceneTarget(): CFrame
		local focus = sceneFocus
		if focus == nil then
			return shotTarget(CameraShots.turn)
		end
		local shot = sceneShot
		if shot ~= nil then
			local eye, look = CameraRules.pose(shot, { x = focus.X, y = focus.Y, z = focus.Z }, sceneFacing)
			return CFrame.lookAt(Vector3.new(eye.x, eye.y, eye.z), Vector3.new(look.x, look.y, look.z))
		end
		return CFrame.lookAt(focus + Vector3.new(0, 40, 70), focus)
	end

	local director: Director = {
		update = function(ctx, dt)
			mode = CameraRules.modeFor({
				riding = ctx.riding,
				sceneRunning = ctx.sceneRunning,
				overviewRequested = overviewWanted,
			})
			if mode == "Scene" and sceneSnap and sceneFocus ~= nil then
				camera.CameraType = Enum.CameraType.Scriptable
				camera.CFrame = sceneTarget()
			elseif mode == "Scene" then
				apply(sceneTarget(), dt)
			elseif mode == "Overview" then
				apply(overviewTarget(), dt)
			elseif mode == "Ride" then
				apply(shotTarget(CameraShots.ride), dt)
			else
				apply(shotTarget(CameraShots.turn), dt)
			end
			return mode
		end,
		requestOverview = function(on: boolean)
			-- Si la escena está en marcha, la petición se queda guardada: `update` la abrirá en cuanto
			-- la escena termine, que es lo que pide la ficha.
			overviewWanted = on
		end,
		rotateOverview = function(pixels: number)
			spin = CameraRules.overviewYaw(spin, pixels)
		end,
		setOverviewFocus = function(position: Vector3?, radius: number?)
			overviewFocus = position
			overviewRadius = radius
		end,
		mode = function(): Mode
			return mode
		end,
		follow = function(token: Model?)
			followToken = token
		end,
		setSize = setSize,
		setSceneFocus = function(
			position: Vector3?,
			shot: CameraShots.Shot?,
			facing: number?,
			snap: boolean?
		)
			sceneFocus = position
			sceneShot = if position ~= nil then shot else nil
			sceneFacing = facing or 0
			sceneSnap = snap == true and position ~= nil
		end,
		destroy = function()
			camera.CameraType = Enum.CameraType.Custom
			followToken = nil
		end,
	}

	return director
end

-- Arranca el bucle de cámara. Devuelve una función para pararlo.
function CameraDirector.start(
	director: Director,
	ctxProvider: () -> { riding: boolean?, sceneRunning: boolean? }
): () -> ()
	local connection = RunService.RenderStepped:Connect(function(dt: number)
		director.update(ctxProvider(), dt)
	end)
	return function()
		connection:Disconnect()
		director.destroy()
	end
end

return CameraDirector

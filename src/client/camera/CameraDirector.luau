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
	update: (ctx: { riding: boolean?, sceneRunning: boolean? }) -> Mode,
	requestOverview: (on: boolean) -> (),
	mode: () -> Mode,
	follow: (token: Model?) -> (),
	setSceneFocus: (position: Vector3?) -> (),
	setSize: (sizeId: SizeId) -> (),
	destroy: () -> (),
}

-- Alturas de cámara sobre la ciudad. Son de arte provisional: la vista general tiene que verse como una
-- maqueta. Los planos del turno y del recorrido están en `config/CameraShots`.
local OVERVIEW_HEIGHT = 620
local OVERVIEW_BACK = 320
local OVERVIEW_TURN = 0.06

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

	-- El tamaño real de la partida llega en la primera vista: la ciudad se vuelve a construir y la
	-- cámara tiene que mirar al centro nuevo.
	local function setSize(nextSize: SizeId)
		local nextCenter = CityLayout.centerFor(nextSize)
		cityCenter = Vector3.new(nextCenter.x, 0, nextCenter.z)
	end

	local mode: Mode = "Turn"
	local overviewWanted = false
	local followToken: Model? = nil
	local sceneFocus: Vector3? = nil
	local spin = 0
	player.CameraMode = Enum.CameraMode.Classic

	local function bodyOf(token: Model?): BasePart?
		if token == nil then
			return nil
		end
		local body = token.PrimaryPart or token:FindFirstChild("Body")
		return if body ~= nil and body:IsA("BasePart") then body else nil
	end

	local function apply(target: CFrame)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = camera.CFrame:Lerp(target, CameraShots.lerpAlpha)
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
		local angle = spin
		local offset =
			Vector3.new(math.sin(angle) * OVERVIEW_BACK, OVERVIEW_HEIGHT, math.cos(angle) * OVERVIEW_BACK)
		return CFrame.lookAt(cityCenter + offset, cityCenter)
	end

	-- Hasta que cada escena tenga su cámara (plan 08), se ve desde el plano del turno.
	local function sceneTarget(): CFrame
		local focus = sceneFocus
		if focus == nil then
			return shotTarget(CameraShots.turn)
		end
		return CFrame.lookAt(focus + Vector3.new(0, 40, 70), focus)
	end

	local director: Director = {
		update = function(ctx)
			mode = CameraRules.modeFor({
				riding = ctx.riding,
				sceneRunning = ctx.sceneRunning,
				overviewRequested = overviewWanted,
			})
			if mode == "Scene" then
				apply(sceneTarget())
			elseif mode == "Overview" then
				spin += OVERVIEW_TURN * (1 / 60)
				apply(overviewTarget())
			elseif mode == "Ride" then
				apply(shotTarget(CameraShots.ride))
			else
				apply(shotTarget(CameraShots.turn))
			end
			return mode
		end,
		requestOverview = function(on: boolean)
			-- Si la escena está en marcha, la petición se queda guardada: `update` la abrirá en cuanto
			-- la escena termine, que es lo que pide la ficha.
			overviewWanted = on
		end,
		mode = function(): Mode
			return mode
		end,
		follow = function(token: Model?)
			followToken = token
		end,
		setSize = setSize,
		setSceneFocus = function(position: Vector3?)
			sceneFocus = position
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
	local connection = RunService.RenderStepped:Connect(function()
		director.update(ctxProvider())
	end)
	return function()
		connection:Disconnect()
		director.destroy()
	end
end

return CameraDirector

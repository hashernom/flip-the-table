--!strict
-- Director de cámara. Decide el modo con `CameraRules` y lo aplica cada fotograma. Es el único sitio
-- del cliente que toca `Camera`: ni las escenas ni los menús mueven la cámara por su cuenta.
--
-- Reglas que se ven aquí y no en `CameraRules`: una escena nunca se interrumpe, así que la petición
-- de vista general se recuerda y se abre al terminar; y la cámara no atraviesa el suelo ni la ficha,
-- porque siempre se coloca por encima del asiento con la altura de los ojos del avatar.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraRules = require("./CameraRules")
local CityLayout = require("../../shared/config/CityLayout")
local TokenRider = require("../world/TokenRider")

type Mode = CameraRules.Mode
type SizeId = CityLayout.SizeId

export type Director = {
	update: (ctx: { isActive: boolean?, sceneRunning: boolean? }) -> Mode,
	requestOverview: (on: boolean) -> (),
	mode: () -> Mode,
	follow: (token: Model?) -> (),
	setSceneFocus: (position: Vector3?) -> (),
	destroy: () -> (),
}

-- Alturas de cámara sobre la ficha y sobre la ciudad. Son de arte provisional: la vista general tiene
-- que verse como una maqueta y la persecución como alguien mirando desde detrás de la ficha.
local FOLLOW_BACK = 26
local FOLLOW_UP = 18
local OVERVIEW_HEIGHT = 620
local OVERVIEW_BACK = 320
local OVERVIEW_TURN = 0.06
local LERP_ALPHA = 0.12

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

	local mode: Mode = "FollowActive"
	local overviewWanted = false
	local followToken: Model? = nil
	local sceneFocus: Vector3? = nil
	local spin = 0
	local firstPerson = false

	local function currentCharacter(): Model?
		return player.Character
	end

	local function seatOf(token: Model?): (Vector3?, CFrame?)
		if token == nil then
			return nil, nil
		end
		local seat = token:FindFirstChild("Seat")
		if seat and seat:IsA("BasePart") then
			return seat.Position, seat.CFrame
		end
		local body = token.PrimaryPart or token:FindFirstChild("Body")
		if body and body:IsA("BasePart") then
			return body.Position, body.CFrame
		end
		return nil, nil
	end

	local function applyFirstPerson()
		local personaje = currentCharacter()
		local humanoid = personaje and personaje:FindFirstChildOfClass("Humanoid")
		if humanoid == nil then
			mode = "FollowActive"
			return
		end
		-- Primera persona de Roblox: la cámara sigue al humanoid y el jugador solo puede mirar, porque
		-- el cuerpo está soldado a la ficha y sin velocidad.
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		firstPerson = true
	end

	local function applyScriptable(target: CFrame)
		if firstPerson then
			-- Salir de primera persona exige devolver el control al jugador un instante: si solo se
			-- cambia el tipo, la cámara se queda pegada al avatar hasta el siguiente fotograma.
			player.CameraMode = Enum.CameraMode.Classic
			camera.CameraType = Enum.CameraType.Custom
			firstPerson = false
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = camera.CFrame:Lerp(target, LERP_ALPHA)
	end

	local function followTarget(): CFrame
		local position, seat = seatOf(followToken)
		if position == nil or seat == nil then
			return CFrame.new(cityCenter + Vector3.new(0, 120, 120)) * CFrame.Angles(0, math.rad(-45), 0)
		end
		local behind = (seat :: CFrame).LookVector * -FOLLOW_BACK
		local focus = position + Vector3.new(0, TokenRider.seatHeight() * 0.6, 0)
		return CFrame.lookAt(focus + behind + Vector3.new(0, FOLLOW_UP, 0), focus)
	end

	local function overviewTarget(): CFrame
		local angle = spin
		local offset =
			Vector3.new(math.sin(angle) * OVERVIEW_BACK, OVERVIEW_HEIGHT, math.cos(angle) * OVERVIEW_BACK)
		return CFrame.lookAt(cityCenter + offset, cityCenter)
	end

	local function sceneTarget(): CFrame
		local focus = sceneFocus or cityCenter
		local anchor = seatOf(followToken)
		local from = if anchor ~= nil then anchor + Vector3.new(0, 26, 0) else focus + Vector3.new(0, 40, 70)
		return CFrame.lookAt(from, focus)
	end

	local director: Director = {
		update = function(ctx)
			mode = CameraRules.modeFor({
				isActive = ctx.isActive,
				sceneRunning = ctx.sceneRunning,
				overviewRequested = overviewWanted,
			})
			if mode == "FirstPerson" then
				applyFirstPerson()
			elseif mode == "Scene" then
				applyScriptable(sceneTarget())
			elseif mode == "Overview" then
				spin += OVERVIEW_TURN * (1 / 60)
				applyScriptable(overviewTarget())
			else
				applyScriptable(followTarget())
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
		setSceneFocus = function(position: Vector3?)
			sceneFocus = position
		end,
		destroy = function()
			player.CameraMode = Enum.CameraMode.Classic
			camera.CameraType = Enum.CameraType.Custom
			followToken = nil
		end,
	}

	return director
end

-- Arranca el bucle de cámara. Devuelve una función para pararlo.
function CameraDirector.start(
	director: Director,
	ctxProvider: () -> { isActive: boolean?, sceneRunning: boolean? }
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

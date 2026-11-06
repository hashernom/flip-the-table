--!strict
-- Escena del Portal: la ficha se enciende de cian, se disuelve con un anillo en el suelo, la cámara viaja
-- al otro Portal y la ficha reaparece allí con otro anillo y el mismo brillo, que se apaga. Un aviso sobre
-- la ficha dice adónde salta. Antes la ficha se quedaba quieta y saltaba de golpe al acabar el lote.
--
-- Los tiempos son fracciones de la duración de la escena (`Scenes.portal`), así que la escena se adapta
-- si llega tarde. Nunca lanza: si falta la ficha o el avatar, la escena sigue con lo que haya.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Scenes = require("../../shared/config/Scenes")
local TokenRider = require("../world/TokenRider")

local PortalJump = {}

export type Options = {
	token: Model,
	playerId: string,
	-- Coloca la ficha en el Portal de llegada (sin animación).
	placeAtDestination: () -> (),
	-- La cámara sigue a la ficha: al moverla, viaja con ella.
	follow: (token: Model) -> (),
	-- Texto del aviso sobre la ficha («Portal → Plaza del Jazz»).
	callout: string,
	duration: number,
	wait: (seconds: number) -> (),
}

local GLOW_NAME = "PortalGlow"
local SPARKS_NAME = "PortalSparks"

local function tween(target: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local created = TweenService:Create(target, info, goal)
	created:Play()
	return created
end

-- Piezas de la ficha y, si va montado, del avatar del jugador: las dos se disuelven juntas.
local function piecesOf(token: Model, playerId: string): { BasePart }
	local list: { BasePart } = {}
	for _, piece in token:GetDescendants() do
		if piece:IsA("BasePart") then
			table.insert(list, piece)
		end
	end
	local userId = tonumber(playerId)
	local rider = if userId ~= nil then Players:GetPlayerByUserId(userId) else nil
	local character = if rider ~= nil then rider.Character else nil
	if character ~= nil and TokenRider.isMounted(rider :: Player, token) then
		for _, piece in character:GetDescendants() do
			if piece:IsA("BasePart") then
				table.insert(list, piece)
			end
		end
	end
	return list
end

-- Disuelve o hace aparecer con `LocalTransparencyModifier`, que no pisa la transparencia guardada de
-- `TokenRider.hide` ni la de las piezas que ya eran invisibles.
local function fade(pieces: { BasePart }, to: number, seconds: number)
	for _, piece in pieces do
		if piece.Parent ~= nil then
			tween(piece, seconds, { LocalTransparencyModifier = to })
		end
	end
end

local function bodyOf(token: Model): BasePart?
	local body = token:FindFirstChild("Body") or token.PrimaryPart
	return if body ~= nil and body:IsA("BasePart") then body else nil
end

-- Anillo de luz que se abre en el suelo y se apaga.
local function ring(at: Vector3, color: Color3)
	local config = Scenes.portal
	local disc = Instance.new("Part")
	disc.Name = "PortalRing"
	disc.Shape = Enum.PartType.Cylinder
	disc.Anchored = true
	disc.CanCollide = false
	disc.CanQuery = false
	disc.CanTouch = false
	disc.Material = Enum.Material.Neon
	disc.Color = color
	disc.Transparency = 0.15
	disc.Size = Vector3.new(0.1, 2, 2)
	-- Un cilindro crece a lo largo de X: girado, queda plano sobre la calle.
	disc.CFrame = CFrame.new(at.X, 0.12, at.Z) * CFrame.Angles(0, 0, math.rad(90))
	disc.Parent = Workspace
	local seconds = config.ringSec
	tween(disc, seconds, {
		Size = Vector3.new(0.1, config.ringStuds, config.ringStuds),
		Transparency = 1,
	}, Enum.EasingStyle.Quad)
	task.delay(seconds + 0.1, function()
		disc:Destroy()
	end)
end

local function addGlow(token: Model, color: Color3): (Highlight, ParticleEmitter?)
	local glow = Instance.new("Highlight")
	glow.Name = GLOW_NAME
	glow.Adornee = token
	glow.FillColor = color
	glow.OutlineColor = Color3.new(1, 1, 1):Lerp(color, 0.3)
	glow.FillTransparency = 1
	glow.OutlineTransparency = 1
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	glow.Parent = token
	local body = bodyOf(token)
	local sparks: ParticleEmitter? = nil
	if body ~= nil then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = SPARKS_NAME
		emitter.Color = ColorSequence.new(color)
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new(0.1, 1)
		emitter.Lifetime = NumberRange.new(0.5, 0.9)
		emitter.Speed = NumberRange.new(3, 6)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, 6, 0)
		emitter.Rate = 0
		emitter.Parent = body
		sparks = emitter
	end
	return glow, sparks
end

function PortalJump.run(options: Options)
	local config = Scenes.portal
	local token = options.token
	local total = options.duration
	local color = Color3.fromHex(config.color)
	local elapsed = 0
	local function waitUntil(fraction: number)
		local target = total * fraction
		if target > elapsed then
			options.wait(target - elapsed)
			elapsed = target
		end
	end

	options.follow(token)
	local glow, sparks = addGlow(token, color)
	TokenRider.bubble(token, options.callout, total * config.vanishAt)

	-- 1. Se enciende: brillo y chispas.
	local glowIn = total * config.vanishAt
	tween(glow, glowIn, { FillTransparency = 0.25, OutlineTransparency = 0 })
	if sparks ~= nil then
		sparks.Rate = config.sparkRate
	end
	waitUntil(config.vanishAt)

	-- 2. Se disuelve sobre un anillo de luz.
	local pieces = piecesOf(token, options.playerId)
	local body = bodyOf(token)
	if body ~= nil then
		ring(body.Position, color)
	end
	if sparks ~= nil then
		sparks:Emit(config.sparkBurst)
	end
	local fadeSec = total * (config.goneAt - config.vanishAt)
	fade(pieces, 1, fadeSec)
	waitUntil(config.goneAt)

	-- 3. Viaja: la ficha pasa al otro Portal y la cámara la sigue por la ciudad.
	if sparks ~= nil then
		sparks.Rate = 0
	end
	options.placeAtDestination()
	options.follow(token)
	waitUntil(config.appearAt)

	-- 4. Reaparece sobre otro anillo, todavía encendida, con el aviso.
	body = bodyOf(token)
	if body ~= nil then
		ring(body.Position, color)
	end
	if sparks ~= nil then
		sparks:Emit(config.sparkBurst)
	end
	pieces = piecesOf(token, options.playerId)
	fade(pieces, 0, total * (config.shownAt - config.appearAt))
	TokenRider.bubble(token, options.callout, total * (1 - config.appearAt))
	waitUntil(config.shownAt)

	-- 5. El brillo se apaga.
	tween(glow, total * (1 - config.shownAt), { FillTransparency = 1, OutlineTransparency = 1 })
	waitUntil(1)
	glow:Destroy()
	if sparks ~= nil then
		sparks:Destroy()
	end
	for _, piece in pieces do
		if piece.Parent ~= nil then
			piece.LocalTransparencyModifier = 0
		end
	end
end

return PortalJump

--!strict
-- Escena del Golpe a la Corona (CardPlayed CrownStrike, con `targetId` = el líder). Un foco cae sobre el
-- líder, su corona se tambalea, se cae a la calle con un bote, y el dinero sale volando de su ficha hacia
-- cada rival.
--
-- Lo que pierde cada uno ya está en la vista; la escena enseña a quién va el dinero, no cuánto.
local CameraShots = require("../../../shared/config/CameraShots")
local LegendaryKit = require("./LegendaryKit")
local LegendaryRules = require("./LegendaryRules")
local LegendaryStaging = require("../../../shared/config/LegendaryStaging")
local SceneDirector = require("../SceneDirector")
local Types = require("../../../shared/rules/Types")

type Context = SceneDirector.Context
type Run = LegendaryKit.Run

local STAGING = LegendaryStaging.crownStrike

type Piece = { part: Part, offset: CFrame }
type Bill = {
	parts: { Part },
	from: LegendaryRules.Point3,
	to: LegendaryRules.Point3,
	delay: number,
	height: number,
	seed: number,
}

export type CrownStrike = { scene: SceneDirector.Scene, cancelAll: () -> () }

local CrownStrike = {}

local function toPoint(v: Vector3): LegendaryRules.Point3
	return { x = v.X, y = v.Y, z = v.Z }
end

-- Corona de oro: aro, cinco puntas con bola y una joya roja al frente. Las piezas van relativas a su centro.
local function makeCrown(run: Run): { Piece }
	local size = STAGING.crownSize
	local gold = Color3.fromHex(STAGING.crownColor)
	local pieces: { Piece } = {}
	local band =
		LegendaryKit.part(run.props, "CrownBand", Vector3.new(size * 0.35, size, size), gold, CFrame.new())
	band.Shape = Enum.PartType.Cylinder
	band.Material = Enum.Material.Metal
	table.insert(pieces, { part = band, offset = CFrame.Angles(0, 0, math.pi / 2) })
	for order = 1, 5 do
		local angle = (order - 1) / 5 * 2 * math.pi
		local at = Vector3.new(math.sin(angle) * size * 0.42, size * 0.35, math.cos(angle) * size * 0.42)
		local spike = LegendaryKit.part(
			run.props,
			"CrownSpike",
			Vector3.new(size * 0.18, size * 0.5, size * 0.18),
			gold,
			CFrame.new()
		)
		spike.Material = Enum.Material.Metal
		table.insert(pieces, { part = spike, offset = CFrame.new(at) * CFrame.Angles(0, angle, 0) })
		local ball =
			LegendaryKit.part(run.props, "CrownBall", Vector3.new(1, 1, 1) * size * 0.16, gold, CFrame.new())
		ball.Shape = Enum.PartType.Ball
		ball.Material = Enum.Material.Metal
		table.insert(pieces, { part = ball, offset = CFrame.new(at + Vector3.new(0, size * 0.3, 0)) })
	end
	local jewel = LegendaryKit.part(
		run.props,
		"CrownJewel",
		Vector3.new(1, 1, 0.4) * size * 0.2,
		Color3.fromHex(STAGING.jewelColor),
		CFrame.new()
	)
	jewel.Material = Enum.Material.Neon
	table.insert(pieces, { part = jewel, offset = CFrame.new(0, 0, size * 0.52) })
	return pieces
end

local function placeCrown(pieces: { Piece }, at: CFrame)
	for _, piece in pieces do
		piece.part.CFrame = at * piece.offset
	end
end

function CrownStrike.new(options: LegendaryKit.Options): CrownStrike
	local active: { [Run]: () -> () } = {}

	local function cancelAll()
		for run, stop in table.clone(active) do
			run.cancelled = true
			stop()
		end
	end

	local function run(ctx: Context, event: Types.Event)
		cancelAll()
		local handles = options.city()
		local leaderId = event.targetId
		local leader = if type(leaderId) == "string" then options.token(leaderId) else nil
		local base = if leader ~= nil then LegendaryKit.tokenBase(leader) else nil
		if handles == nil or leader == nil or base == nil or type(leaderId) ~= "string" then
			ctx.wait(ctx.duration)
			return
		end
		local current = LegendaryKit.begin(handles, "CrownStrike")
		local windows = LegendaryRules.windows(STAGING, ctx.duration)
		local crown = makeCrown(current)
		local top = base + Vector3.new(0, STAGING.crownLift, 0)
		local index = leader:GetAttribute("Index")
		local facing = if type(index) == "number" then handles.facingOf(index) else 0
		local forward = Vector3.new(math.sin(facing), 0, math.cos(facing))
		local landing = base + forward * 6 + Vector3.new(0, STAGING.crownSize * 0.2, 0)

		-- Foco: un haz de luz cálida que baja del cielo sobre el líder.
		local beam = LegendaryKit.part(
			current.props,
			"Spotlight",
			Vector3.new(60, 12, 12),
			Color3.fromHex(STAGING.spotlightColor),
			CFrame.new(base + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		)
		beam.Shape = Enum.PartType.Cylinder
		beam.Material = Enum.Material.Neon
		beam.Transparency = 1
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromHex(STAGING.spotlightColor)
		glow.Range = 30
		glow.Brightness = 0
		glow.Parent = beam

		-- Billetes hacia cada rival, uno tras otro.
		local bills: { Bill } = {}
		local view = ctx.view
		local players = if type(view) == "table" and type(view.players) == "table" then view.players else {}
		for rivalOrder, rivalId in LegendaryRules.crownRivals(leaderId, players) do
			local rival = options.token(rivalId)
			local target = if rival ~= nil then LegendaryKit.tokenBase(rival) else nil
			if target == nil then
				continue
			end
			local distance = (target - base).Magnitude
			for order = 1, STAGING.billsPerRival do
				local seed = ((rivalOrder * 0.618 + order * 0.271) % 1)
				local parts =
					LegendaryKit.bill(current.props, STAGING.billColor, STAGING.billBand, CFrame.new(base))
				for _, piece in parts do
					piece.Transparency = 1
				end
				table.insert(bills, {
					parts = parts,
					from = toPoint(base + Vector3.new(0, 4, 0)),
					to = toPoint(target + Vector3.new((seed - 0.5) * 3, 3, (order % 2 - 0.5) * 3)),
					delay = (order - 1) / STAGING.billsPerRival * 0.45 + (rivalOrder - 1) * 0.05,
					height = STAGING.billArc + distance * 0.25,
					seed = seed,
				})
			end
		end

		local function finish()
			if current.finished then
				return
			end
			current.finished = true
			active[current] = nil
			pcall(function()
				options.director.setSceneFocus(nil)
			end)
			LegendaryKit.clear(current)
		end
		active[current] = finish

		local function step(t: number, _dt: number)
			local light = LegendaryRules.ease(LegendaryRules.progress(windows.spotlight, t))
			local fading = 1 - LegendaryRules.progress(windows.settle, t)
			beam.Transparency = 1 - 0.7 * light * fading
			glow.Brightness = 3 * light * fading

			-- Corona: aparece sobre el líder, se tambalea, cae a la calle con un bote y se queda allí.
			local wobble = LegendaryRules.progress(windows.wobble, t)
			local fall = LegendaryRules.progress(windows.fall, t)
			local spin = t * 0.8
			if fall <= 0 then
				local tilt = math.sin(t * STAGING.wobbleHz * 2 * math.pi) * STAGING.wobbleRadians * wobble
				placeCrown(crown, CFrame.new(top) * CFrame.Angles(tilt, spin, tilt * 0.6))
			else
				local eased = LegendaryRules.ease(fall)
				local at = top:Lerp(landing, eased)
				local bounce = if fall > 0.75 then math.sin((fall - 0.75) / 0.25 * math.pi) * 1.5 else 0
				placeCrown(
					crown,
					CFrame.new(at + Vector3.new(0, bounce, 0))
						* CFrame.Angles(eased * math.pi * 0.55, spin, eased * 0.4)
				)
			end

			-- El dinero vuela de la ficha del líder a cada rival.
			local rain = LegendaryRules.progress(windows.rain, t)
			for _, bill in bills do
				local p = math.clamp((rain - bill.delay) / 0.55, 0, 1)
				local visible = p > 0 and p < 1
				for _, piece in bill.parts do
					piece.Transparency = if visible then 0 else 1
				end
				if visible then
					local at = LegendaryRules.arc(bill.from, bill.to, p, bill.height)
					local flutter = t * 7 + bill.seed * 10
					LegendaryKit.placeBill(
						bill.parts,
						CFrame.new(at.x, at.y, at.z)
							* CFrame.Angles(math.sin(flutter) * 0.8, flutter, math.cos(flutter) * 0.5)
					)
				end
			end

			if rain > 0 and rain < 1 and #bills > 0 then
				LegendaryKit.wide(options.director, handles.sizeId, facing)
			else
				options.director.setSceneFocus(base, CameraShots.crown, facing)
			end
		end

		LegendaryKit.play(ctx, current, "CrownStrike", options.log, step, finish)
	end

	return { scene = { run = run }, cancelAll = cancelAll }
end

return CrownStrike

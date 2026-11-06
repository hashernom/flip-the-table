--!strict
-- Escena de la Puñalada (CardPlayed Backstab, con `targetId` = el socio traicionado). Una cuerda dorada une
-- las fichas de los dos socios, se tensa, brilla y se parte; las dos mitades caen y sobre el traidor cae el
-- sello rojo «Traidor». Apto para todo público: la traición se ve como un pacto roto, sin armas.
--
-- El pacto ya está roto en la vista (y el PactBroken que sigue lo anuncia); la escena solo lo enseña.
local CameraShots = require("../../../shared/config/CameraShots")
local CardSceneRules = require("./CardSceneRules")
local CardStaging = require("../../../shared/config/CardStaging")
local LegendaryKit = require("../legendary/LegendaryKit")
local LegendaryRules = require("../legendary/LegendaryRules")
local SceneDirector = require("../SceneDirector")
local Strings = require("../../../shared/config/Strings")
local Types = require("../../../shared/rules/Types")

type Context = SceneDirector.Context
type Run = LegendaryKit.Run

local STAGING = CardStaging.backstab
local SEGMENTS = 14
-- Más lejos que esto, los dos socios no caben en un plano de calle y se abre a toda la ciudad.
local CLOSE_STUDS = 70

export type Backstab = { scene: SceneDirector.Scene, cancelAll: () -> () }

local Backstab = {}

local function toPoint(v: Vector3): LegendaryRules.Point3
	return { x = v.X, y = v.Y, z = v.Z }
end

local function toVector(p: LegendaryRules.Point3): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

function Backstab.new(options: LegendaryKit.Options): Backstab
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
		local traitorId, partnerId = event.playerId, event.targetId
		local traitor = if type(traitorId) == "string" then options.token(traitorId) else nil
		local partner = if type(partnerId) == "string" then options.token(partnerId) else nil
		local from = if traitor ~= nil then LegendaryKit.tokenBase(traitor) else nil
		local to = if partner ~= nil then LegendaryKit.tokenBase(partner) else nil
		if handles == nil or from == nil or to == nil then
			ctx.wait(ctx.duration)
			return
		end
		local current = LegendaryKit.begin(handles, "Backstab")
		local windows = LegendaryRules.windows(STAGING, ctx.duration)
		local a = toPoint(from + Vector3.new(0, STAGING.ropeHeight, 0))
		local b = toPoint(to + Vector3.new(0, STAGING.ropeHeight, 0))
		local ropeColor = Color3.fromHex(STAGING.ropeColor)
		local snapColor = Color3.fromHex(STAGING.snapColor)
		local segments: { Part } = {}
		for order = 1, SEGMENTS do
			local segment = LegendaryKit.part(
				current.props,
				`Rope{order}`,
				Vector3.new(STAGING.ropeThickness, STAGING.ropeThickness, 1),
				ropeColor,
				CFrame.new(from)
			)
			segment.Material = Enum.Material.Fabric
			segment.Transparency = 1
			table.insert(segments, segment)
		end
		local stamp = LegendaryKit.sign(
			current.props,
			from + Vector3.new(0, STAGING.stampLift, 0),
			Strings.get("scene.backstab.stamp"),
			STAGING.stampWidth,
			STAGING.stampHeight,
			"#C4382B",
			STAGING.stampTilt
		)
		local stampScale = Instance.new("UIScale")
		stampScale.Scale = 0
		stampScale.Parent = stamp
		local middle = from:Lerp(to, 0.5)
		local distance = (to - from).Magnitude
		local heading = math.atan2(to.X - from.X, to.Z - from.Z) + math.pi / 2

		-- Coloca el segmento `order` entre dos puntos de la cuerda.
		local function place(segment: Part, p: Vector3, q: Vector3)
			local length = math.max(0.05, (q - p).Magnitude)
			segment.Size = Vector3.new(STAGING.ropeThickness, STAGING.ropeThickness, length)
			segment.CFrame = CFrame.lookAt(p:Lerp(q, 0.5), q)
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
			local bind = LegendaryRules.ease(LegendaryRules.progress(windows.bind, t))
			local strain = LegendaryRules.progress(windows.strain, t)
			local snap = LegendaryRules.progress(windows.snap, t)
			-- Cuelga al tenderse, se tensa (sin comba, vibrando) y al partirse cada mitad cae.
			local sag = STAGING.sagStuds * (1 - LegendaryRules.ease(strain))
			local quiver = if strain > 0 and snap <= 0 then math.sin(t * 60) * 0.15 * strain else 0
			local color = ropeColor:Lerp(snapColor, strain)
			for order, segment in ipairs(segments) do
				local t0 = (order - 1) / SEGMENTS
				local t1 = order / SEGMENTS
				-- Al tenderse, la cuerda crece desde el traidor hasta el socio.
				if t1 > bind + 1e-6 then
					segment.Transparency = 1
					continue
				end
				local p = toVector(CardSceneRules.rope(a, b, t0, sag))
				local q = toVector(CardSceneRules.rope(a, b, t1, sag))
				if snap > 0 then
					-- Partida por la mitad: cada mitad cuelga de su ficha y cae hacia el suelo.
					local drop = LegendaryRules.ease(snap)
					local fromEnd = if t0 < 0.5 then t0 * 2 else (1 - t1) * 2
					local fall = Vector3.new(0, -STAGING.ropeHeight * drop * (1 - fromEnd * 0.2) * fromEnd, 0)
					p += fall
					q += fall
					segment.Transparency = math.max(0, drop - 0.6) / 0.4
				else
					segment.Transparency = 0
					p += Vector3.new(0, quiver, 0)
					q += Vector3.new(0, -quiver, 0)
				end
				segment.Color = color
				place(segment, p, q)
			end
			-- Sello sobre el traidor: cae grande y se asienta.
			local stampIn = LegendaryRules.progress(windows.stamp, t)
			stampScale.Scale = if stampIn <= 0 then 0 else 1 + (1 - LegendaryRules.ease(stampIn)) * 0.6

			if distance > CLOSE_STUDS then
				LegendaryKit.wide(options.director, handles.sizeId, heading)
			else
				options.director.setSceneFocus(middle, CameraShots.revolution, heading)
			end
		end

		LegendaryKit.play(ctx, current, "Backstab", options.log, step, finish)
	end

	return { scene = { run = run }, cancelAll = cancelAll }
end

return Backstab

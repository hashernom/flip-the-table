--!strict
-- Escena de la Revolución (CardPlayed Revolution). Una multitud con pancartas toma la calle frente al jugador
-- que era más rico, llega un blindado, carga los sacos y los lanza por encima de la ciudad hasta el que era
-- más pobre; la multitud lo celebra. Con 4 jugadores o más pasa en dos sitios a la vez, una pareja por
-- blindado.
--
-- Quién da y quién recibe sale de la vista ya resuelta (`LegendaryRules.revolutionPairs`): la escena no
-- calcula el cambio, solo lo enseña.
local Actors = require("../Actors")
local CameraShots = require("../../../shared/config/CameraShots")
local CityLayout = require("../../../shared/config/CityLayout")
local LegendaryKit = require("./LegendaryKit")
local LegendaryRules = require("./LegendaryRules")
local LegendaryStaging = require("../../../shared/config/LegendaryStaging")
local Robloxian = require("../../world/Robloxian")
local SceneDirector = require("../SceneDirector")
local Types = require("../../../shared/rules/Types")

type Context = SceneDirector.Context
type Run = LegendaryKit.Run

local STAGING = LegendaryStaging.revolution

type Marcher = { model: Model, from: Vector3, to: Vector3, facing: Vector3, banner: Part?, seed: number }
type Sack = {
	part: Part,
	from: LegendaryRules.Point3,
	to: LegendaryRules.Point3,
	delay: number,
	height: number,
}
type Stage = {
	giver: Vector3,
	taker: Vector3,
	forward: Vector3,
	free: Vector3,
	truck: Model?,
	truckFrom: CFrame,
	truckTo: CFrame,
	marchers: { Marcher },
	sacks: { Sack },
}

export type Revolution = { scene: SceneDirector.Scene, cancelAll: () -> () }

local Revolution = {}

local function toPoint(v: Vector3): LegendaryRules.Point3
	return { x = v.X, y = v.Y, z = v.Z }
end

-- Monta una pareja: multitud detrás del que da, un blindado que llega hasta él y los sacos que irán al otro.
local function stage(run: Run, handles: any, giver: Model, taker: Model, pairIndex: number): Stage?
	local giverBase = LegendaryKit.tokenBase(giver)
	local takerBase = LegendaryKit.tokenBase(taker)
	local index = giver:GetAttribute("Index")
	if giverBase == nil or takerBase == nil or type(index) ~= "number" then
		return nil
	end
	local facing = handles.facingOf(index)
	local forward = Vector3.new(math.sin(facing), 0, math.cos(facing))
	-- Hacia la mitad libre de la calle, la contraria a los edificios.
	local free = Vector3.new(-forward.Z, 0, forward.X) * -CityLayout.LOT_SIDE
	local result: Stage = {
		giver = giverBase,
		taker = takerBase,
		forward = forward,
		free = free,
		truck = nil,
		truckFrom = CFrame.lookAt(
			giverBase - forward * STAGING.truckStartStuds + free * 6,
			giverBase + free * 6
		),
		truckTo = CFrame.lookAt(
			giverBase - forward * STAGING.truckStopStuds + free * 6,
			giverBase + forward + free * 6
		),
		marchers = {},
		sacks = {},
	}
	local bannerColor = Color3.fromHex(STAGING.bannerColor)
	for order = 1, STAGING.crowdPerPair do
		local row = math.floor((order - 1) / 3)
		local column = (order - 1) % 3 - 1
		local lateral = free * (column * STAGING.crowdSpacing + 2)
		local from = giverBase + forward * (STAGING.crowdStartStuds + row * STAGING.crowdSpacing) + lateral
		local to = giverBase + forward * (STAGING.crowdStopStuds + row * STAGING.crowdSpacing) + lateral
		local model = Actors.spawn("Crowd", CFrame.lookAt(from, from - forward))
		if model ~= nil then
			local banner: Part? = nil
			if order % 2 == 1 then
				banner = LegendaryKit.part(
					run.props,
					"Banner",
					Vector3.new(3.2, 1.6, 0.2),
					bannerColor,
					CFrame.new(from)
				)
			end
			table.insert(result.marchers, {
				model = model,
				from = from,
				to = to,
				facing = -forward,
				banner = banner,
				seed = (order * 0.3819 + pairIndex * 0.21) % 1,
			})
		end
	end
	result.truck = Actors.spawn("ArmoredTruck", result.truckFrom)
	local sackColor = Color3.fromHex(STAGING.sackColor)
	local distance = (takerBase - giverBase).Magnitude
	for order = 1, STAGING.sacksPerPair do
		local start = result.truckTo.Position + Vector3.new(0, 4, 0)
		local part =
			LegendaryKit.part(run.props, "Sack", Vector3.new(1.8, 2, 1.8), sackColor, CFrame.new(start))
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.Fabric
		part.Transparency = 1
		local landing = takerBase + Vector3.new((order - 2.5) * 1.6, 1, (order % 2) * 1.6)
		table.insert(result.sacks, {
			part = part,
			from = toPoint(start),
			to = toPoint(landing),
			delay = (order - 1) * 0.12,
			height = STAGING.sackArc + distance * 0.3,
		})
	end
	return result
end

function Revolution.new(options: LegendaryKit.Options): Revolution
	local active: { [Run]: () -> () } = {}

	local function cancelAll()
		for run, stop in table.clone(active) do
			run.cancelled = true
			stop()
		end
	end

	local function run(ctx: Context, _event: Types.Event)
		cancelAll()
		local handles = options.city()
		local view = ctx.view
		if handles == nil or type(view) ~= "table" or type(view.players) ~= "table" then
			ctx.wait(ctx.duration)
			return
		end
		local current = LegendaryKit.begin(handles, "Revolution")
		local windows = LegendaryRules.windows(STAGING, ctx.duration)
		local stages: { Stage } = {}
		for pairIndex, pair in LegendaryRules.revolutionPairs(view.players) do
			local giver = options.token(pair.giver)
			local taker = options.token(pair.taker)
			if giver ~= nil and taker ~= nil then
				local made = stage(current, handles, giver, taker, pairIndex)
				if made ~= nil then
					table.insert(stages, made)
				end
			end
		end
		if #stages == 0 then
			LegendaryKit.clear(current)
			ctx.wait(ctx.duration)
			return
		end

		local function finish()
			if current.finished then
				return
			end
			current.finished = true
			active[current] = nil
			for _, item in stages do
				for _, marcher in item.marchers do
					pcall(Actors.despawn, marcher.model)
				end
				if item.truck ~= nil then
					pcall(Actors.despawn, item.truck)
				end
			end
			pcall(function()
				options.director.setSceneFocus(nil)
			end)
			LegendaryKit.clear(current)
		end
		active[current] = finish

		local function step(t: number, _dt: number)
			local march = LegendaryRules.progress(windows.march, t)
			local trucks = LegendaryRules.ease(LegendaryRules.progress(windows.trucks, t))
			local swap = LegendaryRules.progress(windows.swap, t)
			local cheer = LegendaryRules.progress(windows.cheer, t)
			for _, item in stages do
				for _, marcher in item.marchers do
					local walked = LegendaryRules.ease(march)
					local at = marcher.from:Lerp(marcher.to, walked)
					local walking = march > 0 and march < 1
					local hop = 0
					if cheer > 0 then
						hop = math.abs(math.sin((t * 6 + marcher.seed * 3) * math.pi)) * 1.2
					end
					local swing = if walking then math.sin(t * 9 + marcher.seed * 6) * 0.6 else 0
					local raise = if cheer > 0 or march >= 1 then 1 else 0.6
					local root = CFrame.lookAt(at, at + marcher.facing)
						* CFrame.new(0, Robloxian.TORSO_HEIGHT + hop, 0)
					Actors.pose(marcher.model, root, swing, raise)
					if marcher.banner ~= nil then
						marcher.banner.CFrame = root
							* CFrame.new(0, 3.6 + math.sin(t * 4 + marcher.seed) * 0.2, -0.8)
					end
				end
				if item.truck ~= nil then
					item.truck:PivotTo(item.truckFrom:Lerp(item.truckTo, trucks))
				end
				for _, sack in item.sacks do
					local p = math.clamp((swap - sack.delay) / (1 - 0.4), 0, 1)
					if p <= 0 or p >= 1 then
						sack.part.Transparency = 1
						continue
					end
					local at = LegendaryRules.arc(sack.from, sack.to, LegendaryRules.ease(p), sack.height)
					sack.part.Transparency = 0
					sack.part.CFrame = CFrame.new(at.x, at.y, at.z) * CFrame.Angles(p * 5, p * 3, 0)
				end
			end

			-- Cámara: la multitud y el blindado a pie de calle; los sacos volando por encima de la ciudad; y la
			-- celebración de vuelta en la calle.
			local first = stages[1]
			local heading = math.atan2(first.forward.X, first.forward.Z)
			if swap > 0 and swap < 1 then
				LegendaryKit.wide(options.director, handles.sizeId, heading)
			else
				options.director.setSceneFocus(
					first.giver + first.forward * 8,
					CameraShots.revolution,
					heading
				)
			end
		end

		LegendaryKit.play(ctx, current, "Revolution", options.log, step, finish)
	end

	return { scene = { run = run }, cancelAll = cancelAll }
end

return Revolution

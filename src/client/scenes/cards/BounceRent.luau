--!strict
-- Escena de la Renta Rebotada (CardPlayed BounceRent, reacción, con `targetId` = el tercero e `index` = la
-- casilla). Una moneda de renta sale de la propiedad hacia quien debía pagarla, rebota en un muelle sobre
-- su ficha y vuela hasta el tercero, que es quien la paga (el RentPaid que sigue).
local CardSceneRules = require("./CardSceneRules")
local CardStaging = require("../../../shared/config/CardStaging")
local CameraShots = require("../../../shared/config/CameraShots")
local LegendaryKit = require("../legendary/LegendaryKit")
local LegendaryRules = require("../legendary/LegendaryRules")
local SceneDirector = require("../SceneDirector")
local Types = require("../../../shared/rules/Types")

type Context = SceneDirector.Context
type Run = LegendaryKit.Run

local STAGING = CardStaging.bounceRent
local CLOSE_STUDS = 70

export type BounceRent = { scene: SceneDirector.Scene, cancelAll: () -> () }

local BounceRent = {}

local function toPoint(v: Vector3): LegendaryRules.Point3
	return { x = v.X, y = v.Y, z = v.Z }
end

function BounceRent.new(options: LegendaryKit.Options): BounceRent
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
		local payer = if type(event.playerId) == "string" then options.token(event.playerId) else nil
		local third = if type(event.targetId) == "string" then options.token(event.targetId) else nil
		local index = event.index
		local via = if payer ~= nil then LegendaryKit.tokenBase(payer) else nil
		local to = if third ~= nil then LegendaryKit.tokenBase(third) else nil
		if handles == nil or via == nil or to == nil or type(index) ~= "number" then
			ctx.wait(ctx.duration)
			return
		end
		local current = LegendaryKit.begin(handles, "BounceRent")
		local windows = LegendaryRules.windows(STAGING, ctx.duration)
		local from = handles.lotOf(index).Position + Vector3.new(0, 6, 0)
		local bounceAt = via + Vector3.new(0, 6 + STAGING.springStuds, 0)
		local landing = to + Vector3.new(0, 4, 0)

		local coin = LegendaryKit.part(
			current.props,
			"RentCoin",
			Vector3.new(0.5, STAGING.coinSize, STAGING.coinSize),
			Color3.fromHex(STAGING.coinColor),
			CFrame.new(from)
		)
		coin.Shape = Enum.PartType.Cylinder
		coin.Material = Enum.Material.Metal
		local spring = LegendaryKit.part(
			current.props,
			"Spring",
			Vector3.new(STAGING.springStuds, 2.4, 2.4),
			Color3.fromHex(STAGING.springColor),
			CFrame.new(via + Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		)
		spring.Shape = Enum.PartType.Cylinder
		spring.Material = Enum.Material.Metal
		spring.Transparency = 1
		local glow = Instance.new("PointLight")
		glow.Color = coin.Color
		glow.Range = 10
		glow.Brightness = 2
		glow.Parent = coin

		local spanning = math.max((via - from).Magnitude, (to - via).Magnitude)
		local middle = from:Lerp(to, 0.5)
		local heading = math.atan2(to.X - from.X, to.Z - from.Z) + math.pi / 2

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
			local launch = LegendaryRules.progress(windows.launch, t)
			local bounce = LegendaryRules.progress(windows.bounce, t)
			local land = LegendaryRules.progress(windows.land, t)
			-- El muelle aparece sobre quien rebota y se aplasta al recibir la moneda.
			spring.Transparency = if launch > 0.4 then 0 else 1
			local squash = if bounce > 0 then 1 - 0.5 * math.sin(bounce * math.pi) else 1
			spring.Size = Vector3.new(STAGING.springStuds * squash, 2.4, 2.4)
			spring.CFrame = CFrame.new(via + Vector3.new(0, 6 + STAGING.springStuds * squash / 2, 0))
				* CFrame.Angles(0, 0, math.pi / 2)

			local at: LegendaryRules.Point3
			if land > 0 then
				at = CardSceneRules.bounce(
					toPoint(from),
					toPoint(bounceAt),
					toPoint(landing),
					1,
					LegendaryRules.ease(land),
					STAGING
				)
			else
				at = CardSceneRules.bounce(
					toPoint(from),
					toPoint(bounceAt),
					toPoint(landing),
					LegendaryRules.ease(launch),
					0,
					STAGING
				)
			end
			coin.CFrame = CFrame.new(at.x, at.y, at.z) * CFrame.Angles(0, t * 9, 0)
			coin.Transparency = if t >= windows.settle.from
				then LegendaryRules.progress(windows.settle, t)
				else 0

			if spanning > CLOSE_STUDS then
				LegendaryKit.wide(options.director, handles.sizeId, heading)
			else
				options.director.setSceneFocus(middle, CameraShots.revolution, heading)
			end
		end

		LegendaryKit.play(ctx, current, "BounceRent", options.log, step, finish)
	end

	return { scene = { run = run }, cancelAll = cancelAll }
end

return BounceRent

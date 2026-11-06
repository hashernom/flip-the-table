--!strict
-- Escena de la Inflación (CardPlayed Inflation). La cámara abre a toda la ciudad, sobre cada propiedad sube
-- un «×2» naranja, las cifras pintadas en las casillas saltan a su renta nueva y los billetes brincan por
-- todas las calles.
--
-- La renta doble ya está en la vista: a mitad de escena se concilia el mundo con ella, y así las cifras de
-- las casillas cambian delante del grupo.
local CardSceneRules = require("./CardSceneRules")
local CardStaging = require("../../../shared/config/CardStaging")
local CityLayout = require("../../../shared/config/CityLayout")
local Economy = require("../../../shared/config/Economy")
local LegendaryKit = require("../legendary/LegendaryKit")
local LegendaryRules = require("../legendary/LegendaryRules")
local SceneDirector = require("../SceneDirector")
local Strings = require("../../../shared/config/Strings")
local Types = require("../../../shared/rules/Types")

type Context = SceneDirector.Context
type Run = LegendaryKit.Run

local STAGING = CardStaging.inflation

type Badge = { plate: Frame, scale: UIScale, base: Vector3, delay: number }
type Bill = { parts: { Part }, base: Vector3, seed: number, delay: number }

export type Inflation = { scene: SceneDirector.Scene, cancelAll: () -> () }

local Inflation = {}

function Inflation.new(options: LegendaryKit.Options): Inflation
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
		if handles == nil then
			ctx.wait(ctx.duration)
			return
		end
		local current = LegendaryKit.begin(handles, "Inflation")
		local windows = LegendaryRules.windows(STAGING, ctx.duration)
		local badges: { Badge } = {}
		local bills: { Bill } = {}
		local text = Strings.get("scene.inflation.badge", { mult = Economy.inflationRentMultiplier })
		local properties: { CityLayout.Slot } = {}
		for _, slot in CityLayout.routeFor(handles.sizeId) do
			if slot.kind == "Property" then
				table.insert(properties, slot)
			end
		end
		for order, slot in properties do
			local lot = handles.lotOf(slot.index)
			local base = lot.Position + Vector3.new(0, STAGING.badgeLift, 0)
			local delay = (order - 1) / math.max(1, #properties) * 0.5
			local plate = LegendaryKit.sign(
				current.props,
				base,
				text,
				STAGING.badgeWidth,
				STAGING.badgeHeight,
				STAGING.badgeColor,
				-6
			)
			local scale = Instance.new("UIScale")
			scale.Scale = 0
			scale.Parent = plate
			table.insert(badges, { plate = plate, scale = scale, base = base, delay = delay })
			local street = handles.positionOf(slot.index)
			for salt = 1, STAGING.billsPerProperty do
				local parts =
					LegendaryKit.bill(current.props, STAGING.billColor, STAGING.billBand, CFrame.new(street))
				for _, piece in parts do
					piece.Transparency = 1
				end
				table.insert(bills, {
					parts = parts,
					base = street + Vector3.new(0, 1, 0),
					seed = ((order * 0.618 + salt * 0.31) % 1),
					delay = delay * 0.6 + salt * 0.08,
				})
			end
		end
		local swapped = false

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
			-- Los «×2» suben y crecen, una propiedad tras otra.
			local rise = LegendaryRules.progress(windows.rise, t)
			for _, badge in badges do
				local p = LegendaryRules.ease(math.clamp((rise - badge.delay) / 0.5, 0, 1))
				badge.scale.Scale = p
				LegendaryKit.moveSign(badge.plate, badge.base + Vector3.new(0, STAGING.badgeRise * p, 0))
			end
			-- Las cifras de las casillas pasan a su valor nuevo, todas a la vez.
			if not swapped and t >= windows.swap.from then
				swapped = true
				pcall(ctx.world.reconcile, ctx.view)
			end
			-- Los billetes brincan desde cada casilla.
			local rain = LegendaryRules.progress(windows.rain, t)
			for _, bill in bills do
				local p = math.clamp((rain - bill.delay) / 0.5, 0, 1)
				local visible = p > 0 and p < 1
				for _, piece in bill.parts do
					piece.Transparency = if visible then 0 else 1
				end
				if visible then
					local offset = CardSceneRules.burst(bill.seed, p, STAGING)
					local flutter = t * 8 + bill.seed * 9
					LegendaryKit.placeBill(
						bill.parts,
						CFrame.new(bill.base + Vector3.new(offset.x, offset.y, offset.z))
							* CFrame.Angles(math.sin(flutter) * 0.7, flutter, 0)
					)
				end
			end
			LegendaryKit.wide(options.director, handles.sizeId, math.pi * 0.25)
		end

		LegendaryKit.play(ctx, current, "Inflation", options.log, step, finish)
	end

	return { scene = { run = run }, cancelAll = cancelAll }
end

return Inflation

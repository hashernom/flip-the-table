--!strict
-- Escena de la Huelga (CardPlayed Strike, con `zoneId`). La cámara va a la zona; en cada edificio baja una
-- persiana metálica, cuelga un cartel «Cerrado por huelga» y la pintura de sus casillas se apaga. Así se ve
-- qué zona deja de cobrar renta.
--
-- La regla ya la aplicó el motor (un modificador de 2 rondas); la escena solo la enseña, y al acabar quita
-- sus persianas y carteles y devuelve la pintura.
local BuildingView = require("../../world/BuildingView")
local CameraShots = require("../../../shared/config/CameraShots")
local CardStaging = require("../../../shared/config/CardStaging")
local CityLayout = require("../../../shared/config/CityLayout")
local LegendaryKit = require("../legendary/LegendaryKit")
local LegendaryRules = require("../legendary/LegendaryRules")
local SceneDirector = require("../SceneDirector")
local Strings = require("../../../shared/config/Strings")
local Types = require("../../../shared/rules/Types")

type Context = SceneDirector.Context
type Run = LegendaryKit.Run

local STAGING = CardStaging.strike

type Shutter = { panel: Part, slats: { Part }, top: CFrame, width: number, delay: number }
type Sign = { plate: Frame, scale: UIScale, delay: number }
type Dimmed = { decal: Decal, transparency: number }

export type Strike = { scene: SceneDirector.Scene, cancelAll: () -> () }

local Strike = {}

-- Persiana frente a la fachada de un edificio: arranca enrollada arriba y baja hasta el suelo.
local function makeShutter(run: Run, model: Model, lot: CFrame, delay: number): Shutter
	local boxCFrame, size = model:GetBoundingBox()
	-- El solar mira a la calle con su LookVector: la persiana va justo delante de la fachada.
	local look = lot.LookVector
	local depth = math.abs(look:Dot(boxCFrame.LookVector)) * size.Z
		+ math.abs(look:Dot(boxCFrame.RightVector)) * size.X
	local front = Vector3.new(boxCFrame.Position.X, 0, boxCFrame.Position.Z)
		+ look * (depth / 2 + STAGING.shutterDepthStuds)
	local width = math.min(CityLayout.LOT_WIDTH_STUDS * 0.8, math.max(size.X, size.Z) * 0.8)
	local top = CFrame.lookAt(
		front + Vector3.new(0, STAGING.shutterHeight, 0),
		front + Vector3.new(0, STAGING.shutterHeight, 0) + look
	)
	local panel = LegendaryKit.part(
		run.props,
		"Shutter",
		Vector3.new(width, 0.05, 0.3),
		Color3.fromHex(STAGING.shutterColor),
		top
	)
	panel.Material = Enum.Material.CorrodedMetal
	local slats: { Part } = {}
	for order = 1, STAGING.slats do
		local slat = LegendaryKit.part(
			run.props,
			"Slat",
			Vector3.new(width, 0.2, 0.34),
			Color3.fromHex(STAGING.slatColor),
			top
		)
		slat.Transparency = 1
		table.insert(slats, slat)
		slat:SetAttribute("Order", order)
	end
	return { panel = panel, slats = slats, top = top, width = width, delay = delay }
end

function Strike.new(options: LegendaryKit.Options): Strike
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
		local zoneId = event.zoneId
		if handles == nil or type(zoneId) ~= "string" then
			ctx.wait(ctx.duration)
			return
		end
		local slots: { CityLayout.Slot } = {}
		for _, slot in CityLayout.routeFor(handles.sizeId) do
			if slot.zoneId == zoneId then
				table.insert(slots, slot)
			end
		end
		if #slots == 0 then
			ctx.wait(ctx.duration)
			return
		end
		local current = LegendaryKit.begin(handles, "Strike")
		local windows = LegendaryRules.windows(STAGING, ctx.duration)
		local shutters: { Shutter } = {}
		local signs: { Sign } = {}
		local dimmed: { Dimmed } = {}
		local sumX, sumZ = 0, 0
		for order, slot in slots do
			sumX += slot.position.x
			sumZ += slot.position.z
			local delay = (order - 1) / math.max(1, #slots) * 0.35
			local model = BuildingView.modelOf(slot.index)
			if model ~= nil then
				local lot = handles.lotOf(slot.index)
				table.insert(shutters, makeShutter(current, model, lot, delay))
				local _, size = model:GetBoundingBox()
				local plate = LegendaryKit.sign(
					current.props,
					lot.Position + Vector3.new(0, size.Y + 4, 0),
					Strings.get("scene.strike.sign"),
					170,
					46,
					STAGING.signColor,
					-4
				)
				local scale = Instance.new("UIScale")
				scale.Scale = 0
				scale.Parent = plate
				table.insert(signs, { plate = plate, scale = scale, delay = delay })
			end
			local tile: BasePart? = handles.squares[slot.index]
			if tile ~= nil then
				for _, decal in tile:GetDescendants() do
					if decal:IsA("Decal") then
						table.insert(dimmed, { decal = decal, transparency = decal.Transparency })
					end
				end
			end
		end
		local focus = Vector3.new(sumX / #slots, 0, sumZ / #slots)
		local middle = slots[math.max(1, math.ceil(#slots / 2))]

		local function finish()
			if current.finished then
				return
			end
			current.finished = true
			active[current] = nil
			for _, item in dimmed do
				pcall(function()
					item.decal.Transparency = item.transparency
				end)
			end
			pcall(function()
				options.director.setSceneFocus(nil)
			end)
			LegendaryKit.clear(current)
		end
		active[current] = finish

		local function step(t: number, _dt: number)
			-- Persianas: bajan una tras otra, y cada lama aparece cuando la persiana pasa por ella.
			local down = LegendaryRules.progress(windows.shutters, t)
			for _, shutter in shutters do
				local p = LegendaryRules.ease(math.clamp((down - shutter.delay) / (1 - 0.35), 0, 1))
				local height = math.max(0.05, STAGING.shutterHeight * p)
				shutter.panel.Size = Vector3.new(shutter.width, height, 0.3)
				shutter.panel.CFrame = shutter.top * CFrame.new(0, -height / 2, 0)
				for _, slat in shutter.slats do
					local order = slat:GetAttribute("Order") :: number
					local at = STAGING.shutterHeight * order / (STAGING.slats + 1)
					slat.Transparency = if height >= at then 0 else 1
					slat.CFrame = shutter.top * CFrame.new(0, -at, 0)
				end
			end
			-- Carteles: aparecen con un pequeño rebote.
			local hang = LegendaryRules.progress(windows.signs, t)
			for _, sign in signs do
				local p = math.clamp((hang - sign.delay) / (1 - 0.35), 0, 1)
				sign.scale.Scale = if p <= 0 then 0 else 1 + math.sin(p * math.pi) * 0.25 * (1 - p)
			end
			-- La zona se apaga mientras bajan las persianas.
			local dim = STAGING.dimTransparency * LegendaryRules.ease(down)
			for _, item in dimmed do
				item.decal.Transparency = item.transparency + (1 - item.transparency) * dim
			end
			options.director.setSceneFocus(focus, CameraShots.quake, middle.facing)
		end

		LegendaryKit.play(ctx, current, "Strike", options.log, step, finish)
	end

	return { scene = { run = run }, cancelAll = cancelAll }
end

return Strike

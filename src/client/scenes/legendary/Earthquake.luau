--!strict
-- Escena del Terremoto (CardPlayed Earthquake, con `zoneId`). La calle de la zona se agrieta, los edificios
-- de la zona tiemblan y cada uno con mejoras pierde su último marcador y su último añadido, que caen hacia la
-- calle entre polvo. Las grietas y el polvo duran lo que la escena.
--
-- El motor ya bajó un nivel cada edificio de la zona (los BuildingChanged que siguen). Al acabar, cada
-- edificio vuelve a su sitio y la conciliación con la vista lo rehace en su nivel nuevo.
local BuildingView = require("../../world/BuildingView")
local CameraShots = require("../../../shared/config/CameraShots")
local CityLayout = require("../../../shared/config/CityLayout")
local LegendaryKit = require("./LegendaryKit")
local LegendaryRules = require("./LegendaryRules")
local LegendaryStaging = require("../../../shared/config/LegendaryStaging")
local SceneDirector = require("../SceneDirector")
local Types = require("../../../shared/rules/Types")

type Context = SceneDirector.Context
type Run = LegendaryKit.Run

local STAGING = LegendaryStaging.earthquake

type Shaken = { model: Model, pivot: CFrame, seed: number }
type Falling = {
	part: BasePart,
	origin: CFrame,
	transparency: number,
	toward: Vector3,
	seed: number,
}
type Crack = { part: Part, full: Vector3, order: number }

export type Earthquake = { scene: SceneDirector.Scene, cancelAll: () -> () }

local Earthquake = {}

local function seedOf(index: number, salt: number): number
	return ((index * 0.754877666 + salt * 0.569840291) % 1)
end

-- Grietas de una casilla: segmentos oscuros en abanico sobre el asfalto, que crecen desde el centro.
local function cracksFor(run: Run, slot: CityLayout.Slot, from: number): { Crack }
	local cracks: { Crack } = {}
	local color = Color3.fromHex(STAGING.crackColor)
	local center = CityLayout.slotCenter(slot)
	for order = 1, STAGING.cracksPerSquare do
		local seed = seedOf(slot.index, order)
		local angle = slot.facing + (seed - 0.5) * math.pi * 1.6 + order
		local length = STAGING.crackLength * (0.6 + seed * 0.8)
		local offset = Vector3.new(math.sin(angle), 0, math.cos(angle)) * (length / 2)
		local at = Vector3.new(center.x, 0.08 + order * 0.004, center.z) + offset * (0.4 + seed)
		local part = LegendaryKit.part(
			run.props,
			`Crack{slot.index}_{order}`,
			Vector3.new(STAGING.crackWidth * (0.6 + seed * 0.6), 0.06, 0.01),
			color,
			CFrame.lookAt(at, at + Vector3.new(math.sin(angle), 0, math.cos(angle)))
		)
		part.Material = Enum.Material.Slate
		table.insert(cracks, {
			part = part,
			full = Vector3.new(part.Size.X, part.Size.Y, length),
			order = order + from,
		})
	end
	return cracks
end

function Earthquake.new(options: LegendaryKit.Options): Earthquake
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

		local current = LegendaryKit.begin(handles, "Earthquake")
		local windows = LegendaryRules.windows(STAGING, ctx.duration)
		local shaken: { Shaken } = {}
		local falling: { Falling } = {}
		local cracks: { Crack } = {}
		local dusts: { Smoke } = {}
		local sumX, sumZ = 0, 0
		for order, slot in slots do
			sumX += slot.position.x
			sumZ += slot.position.z
			for _, crack in cracksFor(current, slot, (order - 1) * STAGING.cracksPerSquare) do
				table.insert(cracks, crack)
			end
			local model = BuildingView.modelOf(slot.index)
			if model == nil then
				continue
			end
			table.insert(shaken, { model = model, pivot = model:GetPivot(), seed = seedOf(slot.index, 0) })
			-- Con mejoras, cae el último marcador y el último añadido: lo que el motor le quita.
			if BuildingView.levelOf(slot.index) > 0 then
				local lot = handles.lotOf(slot.index)
				local toward = -lot.LookVector * STAGING.fallTowardStreet
				local markers =
					LegendaryKit.piecesWithRole(model, "Marker", BuildingView.ROLE, BuildingView.TIER)
				local addons =
					LegendaryKit.piecesWithRole(model, "Addon", BuildingView.ROLE, BuildingView.TIER)
				local lastMarker = if #markers > 0 then markers[1]:GetAttribute(BuildingView.TIER) else nil
				local lastAddon = if #addons > 0 then addons[1]:GetAttribute(BuildingView.TIER) else nil
				for salt, piece in markers do
					if piece:GetAttribute(BuildingView.TIER) == lastMarker then
						table.insert(falling, {
							part = piece,
							origin = piece.CFrame,
							transparency = piece.Transparency,
							toward = toward,
							seed = seedOf(slot.index, salt),
						})
					end
				end
				for salt, piece in addons do
					if piece:GetAttribute(BuildingView.TIER) == lastAddon then
						table.insert(falling, {
							part = piece,
							origin = piece.CFrame,
							transparency = piece.Transparency,
							toward = toward,
							seed = seedOf(slot.index, salt + 10),
						})
					end
				end
				local anchor =
					LegendaryKit.part(current.props, "Dust", Vector3.new(1, 1, 1), Color3.new(), lot)
				anchor.Transparency = 1
				local dust = Instance.new("Smoke")
				dust.Color = Color3.fromHex(STAGING.dustColor)
				dust.Opacity = 0.45
				dust.Size = 14
				dust.RiseVelocity = 5
				dust.Enabled = false
				dust.Parent = anchor
				table.insert(dusts, dust)
			end
		end
		local middle = slots[math.max(1, math.ceil(#slots / 2))]
		local focus = Vector3.new(sumX / #slots, 0, sumZ / #slots)

		local function finish()
			if current.finished then
				return
			end
			current.finished = true
			active[current] = nil
			for _, item in shaken do
				pcall(function()
					item.model:PivotTo(item.pivot)
				end)
			end
			-- Lo caído se queda fuera al acabar entera: la conciliación rehace esos edificios un nivel más
			-- abajo. Si cortan la escena, cada pieza vuelve a su sitio.
			if current.cancelled then
				for _, item in falling do
					pcall(function()
						item.part.CFrame = item.origin
						item.part.Transparency = item.transparency
					end)
				end
			end
			pcall(function()
				options.director.setSceneFocus(nil)
			end)
			LegendaryKit.clear(current)
		end
		active[current] = finish

		local totalCracks = #cracks
		local function step(t: number, _dt: number)
			-- Temblor: arranca suave, es máximo mientras tiembla y caen las piezas, y se calma al final.
			local strength = 0
			if t < windows.shake.from then
				strength = 0.35 * LegendaryRules.progress(windows.rumble, t)
					+ 0.4 * LegendaryRules.progress(windows.crack, t)
			elseif t < windows.settle.from then
				strength = 1
			else
				strength = 1 - LegendaryRules.ease(LegendaryRules.progress(windows.settle, t))
			end
			for _, item in shaken do
				-- Movido sobre la pose guardada después de mover las piezas que caen: estas van por su cuenta.
				local offset =
					LegendaryRules.shake(t, item.seed, STAGING.shakeStuds * strength, STAGING.shakeHz)
				item.model:PivotTo(item.pivot * CFrame.new(offset.x, 0, offset.z))
			end

			-- Grietas: se abren de una en una durante su paso y se quedan.
			local opened = LegendaryRules.progress(windows.crack, t) * totalCracks
			for _, crack in cracks do
				local grow = math.clamp(opened - crack.order + 1, 0, 1)
				crack.part.Size = Vector3.new(crack.full.X, crack.full.Y, math.max(0.01, crack.full.Z * grow))
			end

			-- Caída: las piezas se separan, caen girando hacia la calle y se hunden en el polvo.
			local fall = LegendaryRules.progress(windows.fall, t)
			for _, item in falling do
				if fall <= 0 then
					continue
				end
				local p = LegendaryRules.ease(math.clamp(fall * 1.3 - item.seed * 0.3, 0, 1))
				local drop = item.origin.Position.Y * p
				local slide = item.toward * p
				local turn = p * STAGING.fallTurns * 2 * math.pi * (0.5 + item.seed)
				item.part.CFrame = CFrame.new(item.origin.Position + slide - Vector3.new(0, drop, 0))
					* (item.origin - item.origin.Position)
					* CFrame.Angles(turn, 0, turn * 0.4)
				item.part.Transparency = item.transparency
					+ (1 - item.transparency) * math.max(0, p - 0.8) / 0.2
			end
			for _, dust in dusts do
				dust.Enabled = t >= windows.fall.from and t < windows.settle.to - 0.5
			end

			options.director.setSceneFocus(focus, CameraShots.quake, middle.facing)
		end

		LegendaryKit.play(ctx, current, "Earthquake", options.log, step, finish)
	end

	return { scene = { run = run }, cancelAll = cancelAll }
end

return Earthquake

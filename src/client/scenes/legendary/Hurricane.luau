--!strict
-- Escena del Huracán (CardPlayed Hurricane). El cielo se oscurece, un embudo de viento entra por la calle y
-- da la vuelta entera a la ciudad. A su paso se lleva los marcadores y los añadidos de cada edificio, y apaga
-- la placa del dueño; el cuerpo del edificio queda en pie (art/vision-visual.md). Si no hay nada construido,
-- levanta carteles y coches de la calle para que la escena siga teniendo sentido. Después sale de la ciudad
-- y vuelve la luz.
--
-- El motor ya devolvió las propiedades al banco: la vista lo dice y el director pone la ciudad como ella al
-- acabar. Aquí solo se mueven piezas; `finish` las devuelve a su sitio antes de esa conciliación.
local BuildingView = require("../../world/BuildingView")
local CameraShots = require("../../../shared/config/CameraShots")
local LegendaryKit = require("./LegendaryKit")
local LegendaryRules = require("./LegendaryRules")
local LegendaryStaging = require("../../../shared/config/LegendaryStaging")
local SceneDirector = require("../SceneDirector")
local Types = require("../../../shared/rules/Types")

type Context = SceneDirector.Context
type Run = LegendaryKit.Run

local STAGING = LegendaryStaging.hurricane

-- Un resto que el viento arranca: su pieza, dónde estaba y cuándo empieza a volar.
type Debris = {
	part: BasePart,
	origin: CFrame,
	transparency: number,
	seed: number,
	startsAt: number,
	-- Atrezo de la escena (carteles y coches): se borra con la carpeta, no se devuelve.
	prop: boolean,
}

-- Placa de dueño que se apaga al paso del embudo.
type Plate = { parts: { BasePart }, saved: { number }, fadesAt: number }

export type Hurricane = { scene: SceneDirector.Scene, cancelAll: () -> () }

local Hurricane = {}

local function seedOf(order: number, salt: number): number
	return ((order * 0.618033988749895 + salt * 0.137) % 1)
end

-- Embudo: anillos semitransparentes apilados que se abren hacia arriba, con polvo en la base.
local function makeFunnel(run: Run): { rings: { Part }, dust: Smoke }
	local rings: { Part } = {}
	local color = Color3.fromHex(STAGING.funnelColor)
	for index = 1, STAGING.funnelRings do
		local share = (index - 1) / math.max(1, STAGING.funnelRings - 1)
		local radius = STAGING.funnelBaseRadius
			+ (STAGING.funnelTopRadius - STAGING.funnelBaseRadius) * share ^ 1.4
		local ring = LegendaryKit.part(
			run.props,
			`FunnelRing{index}`,
			Vector3.new(STAGING.funnelHeight / STAGING.funnelRings * 1.2, radius * 2, radius * 2),
			color,
			CFrame.new()
		)
		ring.Shape = Enum.PartType.Cylinder
		ring.Transparency = STAGING.funnelTransparency + share * 0.25
		ring.Material = Enum.Material.Fabric
		table.insert(rings, ring)
	end
	local dust = Instance.new("Smoke")
	dust.Color = Color3.fromHex(STAGING.debrisColor)
	dust.Opacity = 0.5
	dust.Size = 18
	dust.RiseVelocity = 12
	dust.Parent = rings[1]
	return { rings = rings, dust = dust }
end

-- Coloca el embudo con la base en `base`, girando sobre sí mismo y meciéndose.
local function placeFunnel(rings: { Part }, base: Vector3, t: number)
	local step = STAGING.funnelHeight / #rings
	for index, ring in rings do
		local height = (index - 0.5) * step
		local sway = math.sin(t * 1.7 + index * 0.45) * (index / #rings) * 6
		local spin = t * STAGING.funnelTurnsPerSec * 2 * math.pi + index * 0.3
		ring.CFrame = CFrame.new(base + Vector3.new(sway, height, sway * 0.6))
			* CFrame.Angles(0, spin, 0)
			* CFrame.Angles(0, 0, math.pi / 2)
	end
end

-- Lo que el viento puede llevarse: añadidos y marcadores de cada edificio, en el orden en que pasa el
-- embudo, y las placas de dueño.
local function collect(
	handles: any,
	loop: LegendaryRules.Loop,
	orderOf: { [number]: number },
	sweep: LegendaryRules.Window
): ({ Debris }, { Plate })
	local debris: { Debris } = {}
	local plates: { Plate } = {}
	local span = sweep.to - sweep.from
	for index, order in orderOf do
		local passAt = sweep.from + loop.passAt[order] * span
		local model = BuildingView.modelOf(index)
		if model ~= nil then
			local salt = 0
			for _, role in { "Addon", "Marker" } do
				for _, piece in LegendaryKit.piecesWithRole(model, role, BuildingView.ROLE, BuildingView.TIER) do
					salt += 1
					table.insert(debris, {
						part = piece,
						origin = piece.CFrame,
						transparency = piece.Transparency,
						seed = seedOf(order, salt),
						startsAt = passAt - STAGING.pullAhead * span + salt * 0.04,
						prop = false,
					})
				end
			end
		end
		local tile = handles.squares[index]
		local plate = if tile ~= nil then tile:FindFirstChild("OwnerPlate") else nil
		if plate ~= nil then
			local parts: { BasePart } = {}
			local saved: { number } = {}
			for _, piece in plate:GetDescendants() do
				if piece:IsA("BasePart") then
					table.insert(parts, piece)
					table.insert(saved, piece.Transparency)
				end
			end
			if plate:IsA("BasePart") then
				table.insert(parts, plate)
				table.insert(saved, plate.Transparency)
			end
			table.insert(plates, { parts = parts, saved = saved, fadesAt = passAt })
		end
	end
	return debris, plates
end

-- Sin nada construido, el viento levanta carteles y coches repartidos por la calle.
local function streetProps(run: Run, loop: LegendaryRules.Loop, sweep: LegendaryRules.Window): { Debris }
	local props: { Debris } = {}
	local span = sweep.to - sweep.from
	for order = 1, STAGING.propsWhenEmpty do
		local fraction = (order - 0.5) / STAGING.propsWhenEmpty
		local pose = LegendaryRules.along(loop, fraction)
		-- Al borde de la calle, del lado de fuera.
		local sideX, sideZ = pose.headingZ, -pose.headingX
		local at = Vector3.new(pose.x + sideX * 15, 0, pose.z + sideZ * 15)
		local facing = CFrame.lookAt(at, at + Vector3.new(pose.headingX, 0, pose.headingZ))
		local pieces: { Part } = {}
		if order % 2 == 0 then
			table.insert(
				pieces,
				LegendaryKit.part(
					run.props,
					"Car",
					Vector3.new(4, 1.6, 8),
					Color3.fromHSV(fraction, 0.55, 0.8),
					facing * CFrame.new(0, 1.1, 0)
				)
			)
			table.insert(
				pieces,
				LegendaryKit.part(
					run.props,
					"CarCab",
					Vector3.new(3.4, 1.2, 4),
					Color3.fromRGB(46, 74, 99),
					facing * CFrame.new(0, 2.5, 0.4)
				)
			)
		else
			table.insert(
				pieces,
				LegendaryKit.part(
					run.props,
					"SignPost",
					Vector3.new(0.4, 5, 0.4),
					Color3.fromRGB(60, 62, 66),
					facing * CFrame.new(0, 2.5, 0)
				)
			)
			table.insert(
				pieces,
				LegendaryKit.part(
					run.props,
					"SignBoard",
					Vector3.new(4.5, 2.4, 0.3),
					Color3.fromRGB(237, 229, 211),
					facing * CFrame.new(0, 5.6, 0)
				)
			)
		end
		for salt, piece in pieces do
			table.insert(props, {
				part = piece :: BasePart,
				origin = piece.CFrame,
				transparency = piece.Transparency,
				seed = seedOf(order, salt),
				startsAt = sweep.from + fraction * span - STAGING.pullAhead * span,
				prop = true,
			})
		end
	end
	return props
end

local function flyDebris(debris: { Debris }, t: number)
	for _, item in debris do
		local flight = (t - item.startsAt) / STAGING.debrisSeconds
		if flight <= 0 then
			continue
		end
		if flight >= 1 then
			item.part.Transparency = 1
			continue
		end
		local offset = LegendaryRules.debris(item.seed, LegendaryRules.ease(flight), STAGING)
		local tumble = flight * 6 * (item.seed + 0.5)
		item.part.CFrame = CFrame.new(item.origin.Position + Vector3.new(offset.x, offset.y, offset.z))
			* (item.origin - item.origin.Position)
			* CFrame.Angles(tumble, tumble * 0.7, tumble * 0.3)
		item.part.Transparency = item.transparency + (1 - item.transparency) * math.max(0, flight - 0.7) / 0.3
	end
end

function Hurricane.new(options: LegendaryKit.Options): Hurricane
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
		local points, orderOf = LegendaryKit.routePoints(handles.sizeId)
		if #points == 0 then
			ctx.wait(ctx.duration)
			return
		end
		local loop = LegendaryRules.loop(points)
		local center = LegendaryRules.center(points)
		local windows = LegendaryRules.windows(STAGING, ctx.duration)
		local current = LegendaryKit.begin(handles, "Hurricane")
		local sky = LegendaryKit.sky(
			STAGING.stormBrightness,
			STAGING.stormAmbient,
			STAGING.stormFogEnd,
			STAGING.stormFogColor
		)
		local debris, plates = collect(handles, loop, orderOf, windows.sweep)
		if #debris == 0 then
			debris = streetProps(current, loop, windows.sweep)
		end
		local funnel = makeFunnel(current)
		local start = LegendaryRules.along(loop, 0)
		local entry = Vector3.new(
			start.x - start.headingX * STAGING.approachStuds,
			0,
			start.z - start.headingZ * STAGING.approachStuds
		)
		local outX, outZ = start.x - center.x, start.z - center.z
		local outLength = math.max(1e-3, math.sqrt(outX * outX + outZ * outZ))
		local exit = Vector3.new(
			start.x + outX / outLength * STAGING.approachStuds,
			0,
			start.z + outZ / outLength * STAGING.approachStuds
		)
		local focusedWide = false

		local function finish()
			if current.finished then
				return
			end
			current.finished = true
			active[current] = nil
			pcall(sky.restore)
			-- Al acabar entera, lo arrancado sigue fuera: el motor ya bajó esos edificios a nivel 0 y la
			-- conciliación con la vista los rehace. Solo si cortan la escena vuelve cada pieza a su sitio.
			for _, item in debris do
				if not item.prop and current.cancelled then
					pcall(function()
						item.part.CFrame = item.origin
						item.part.Transparency = item.transparency
					end)
				end
			end
			for _, plate in plates do
				if not current.cancelled then
					continue
				end
				for order, piece in plate.parts do
					pcall(function()
						piece.Transparency = plate.saved[order]
					end)
				end
			end
			pcall(function()
				options.director.setSceneFocus(nil)
			end)
			LegendaryKit.clear(current)
		end
		active[current] = finish

		local function step(t: number, _dt: number)
			-- Cielo: se oscurece al principio y se aclara al final.
			if t < windows.clear.from then
				sky.set(LegendaryRules.ease(LegendaryRules.progress(windows.darken, t)))
			else
				sky.set(1 - LegendaryRules.ease(LegendaryRules.progress(windows.clear, t)))
			end

			-- Embudo: entra, da la vuelta y sale.
			local base: Vector3
			local heading = 0
			if t < windows.sweep.from then
				local p = LegendaryRules.ease(LegendaryRules.progress(windows.arrive, t))
				base = entry:Lerp(Vector3.new(start.x, 0, start.z), p)
				heading = math.atan2(start.headingX, start.headingZ)
			elseif t < windows.leave.from then
				local pose = LegendaryRules.along(loop, LegendaryRules.progress(windows.sweep, t))
				base = Vector3.new(pose.x, 0, pose.z)
				heading = math.atan2(pose.headingX, pose.headingZ)
			else
				local p = LegendaryRules.ease(LegendaryRules.progress(windows.leave, t))
				base = Vector3.new(start.x, 0, start.z):Lerp(exit, p)
				heading = math.atan2(outX, outZ)
			end
			placeFunnel(funnel.rings, base, t)
			funnel.dust.Enabled = t < windows.clear.from

			flyDebris(debris, t)
			for _, plate in plates do
				if t >= plate.fadesAt then
					local fade = math.clamp((t - plate.fadesAt) / STAGING.debrisSeconds, 0, 1)
					for order, piece in plate.parts do
						piece.Transparency = plate.saved[order] + (1 - plate.saved[order]) * fade
					end
				end
			end

			-- Cámara: toda la ciudad mientras se oscurece; el embudo de cerca en el barrido; y la ciudad otra vez.
			if t >= windows.sweep.from and t < windows.leave.from then
				focusedWide = false
				options.director.setSceneFocus(base, CameraShots.hurricane, heading)
			elseif not focusedWide then
				focusedWide = true
				LegendaryKit.wide(options.director, handles.sizeId, heading)
			end
		end

		LegendaryKit.play(ctx, current, "Hurricane", options.log, step, finish)
	end

	return { scene = { run = run }, cancelAll = cancelAll }
end

return Hurricane

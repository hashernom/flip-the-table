--!strict
-- Escena de la Demolición (CardPlayed Demolition, con `index`). Una grúa con bola llega por la calle hasta
-- el edificio rival, la bola toma impulso y golpea; el edificio tiembla y su último marcador y su último
-- añadido caen a la calle entre polvo. Queda claro qué edificio se tocó y que bajó un nivel.
--
-- El motor ya bajó el nivel (el BuildingChanged que sigue). Al acabar, la conciliación rehace el edificio.
local Actors = require("../Actors")
local BuildingView = require("../../world/BuildingView")
local CameraShots = require("../../../shared/config/CameraShots")
local CardSceneRules = require("./CardSceneRules")
local CardStaging = require("../../../shared/config/CardStaging")
local LegendaryKit = require("../legendary/LegendaryKit")
local LegendaryRules = require("../legendary/LegendaryRules")
local SceneDirector = require("../SceneDirector")
local Types = require("../../../shared/rules/Types")

type Context = SceneDirector.Context
type Run = LegendaryKit.Run

local STAGING = CardStaging.demolition

type Falling = { part: BasePart, origin: CFrame, transparency: number, toward: Vector3, seed: number }
type Swinging = { part: BasePart, origin: CFrame }

export type Demolition = { scene: SceneDirector.Scene, cancelAll: () -> () }

local Demolition = {}

function Demolition.new(options: LegendaryKit.Options): Demolition
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
		local index = event.index
		local model = if type(index) == "number" then BuildingView.modelOf(index) else nil
		if handles == nil or type(index) ~= "number" or model == nil then
			ctx.wait(ctx.duration)
			return
		end
		local current = LegendaryKit.begin(handles, "Demolition")
		local windows = LegendaryRules.windows(STAGING, ctx.duration)
		local lot = handles.lotOf(index)
		-- El solar mira a la calle con su LookVector (su -Z).
		local toStreet = lot.LookVector
		local side = lot.RightVector
		local parked = lot.Position + toStreet * STAGING.craneStreetStuds + side * STAGING.craneSideStuds
		local craneTo = CFrame.lookAt(parked, parked + side)
		local craneFrom = craneTo + side * -STAGING.craneApproachStuds
		local crane = Actors.spawn("WreckingBall", craneFrom)

		-- La bola y su cadena se balancean alrededor de lo alto de la cadena.
		local swinging: { Swinging } = {}
		local pivotLocal: CFrame? = nil
		if crane ~= nil then
			for _, piece in crane:GetDescendants() do
				if
					piece:IsA("BasePart")
					and (piece.Name == "wrecking_ball" or piece.Name == "wrecking_chain")
				then
					-- Medidas respecto a la grúa donde aparece, para moverlas con ella.
					table.insert(swinging, { part = piece, origin = craneFrom:ToObjectSpace(piece.CFrame) })
					if piece.Name == "wrecking_chain" then
						local top = piece.CFrame * CFrame.new(0, piece.Size.Y / 2, 0)
						pivotLocal = craneFrom:ToObjectSpace(CFrame.new(top.Position))
					end
				end
			end
		end

		-- Lo que cae: el último marcador y el último añadido.
		local falling: { Falling } = {}
		local markers = LegendaryKit.piecesWithRole(model, "Marker", BuildingView.ROLE, BuildingView.TIER)
		local addons = LegendaryKit.piecesWithRole(model, "Addon", BuildingView.ROLE, BuildingView.TIER)
		for _, group in { markers, addons } do
			local last = if #group > 0 then group[1]:GetAttribute(BuildingView.TIER) else nil
			for salt, piece in group do
				if piece:GetAttribute(BuildingView.TIER) == last then
					table.insert(falling, {
						part = piece,
						origin = piece.CFrame,
						transparency = piece.Transparency,
						toward = toStreet * STAGING.fallTowardStreet,
						seed = (salt * 0.618) % 1,
					})
				end
			end
		end
		local pivot = model:GetPivot()
		local dustAnchor = LegendaryKit.part(current.props, "Dust", Vector3.new(1, 1, 1), Color3.new(), lot)
		dustAnchor.Transparency = 1
		local dust = Instance.new("Smoke")
		dust.Color = Color3.fromHex(STAGING.dustColor)
		dust.Opacity = 0.5
		dust.Size = 12
		dust.RiseVelocity = 5
		dust.Enabled = false
		dust.Parent = dustAnchor

		local function finish()
			if current.finished then
				return
			end
			current.finished = true
			active[current] = nil
			pcall(function()
				model:PivotTo(pivot)
			end)
			if current.cancelled then
				for _, item in falling do
					pcall(function()
						item.part.CFrame = item.origin
						item.part.Transparency = item.transparency
					end)
				end
			end
			if crane ~= nil then
				pcall(Actors.despawn, crane)
			end
			pcall(function()
				options.director.setSceneFocus(nil)
			end)
			LegendaryKit.clear(current)
		end
		active[current] = finish

		local look = lot.LookVector
		local facing = math.atan2(-look.X, -look.Z)
		local function step(t: number, _dt: number)
			-- La grúa llega y para frente al edificio.
			local arrive = LegendaryRules.ease(LegendaryRules.progress(windows.arrive, t))
			local base = craneFrom:Lerp(craneTo, arrive)
			if crane ~= nil then
				crane:PivotTo(base)
			end
			-- La bola: impulso hacia atrás y golpe hacia la fachada.
			local angle = CardSceneRules.swing(
				LegendaryRules.progress(windows.windup, t),
				LegendaryRules.progress(windows.strike, t),
				STAGING
			)
			if pivotLocal ~= nil then
				-- Gira en el mundo alrededor de lo alto de la cadena, con el eje a lo largo de la calle. Con ese
				-- eje, un ángulo positivo llevaría la bola hacia la calle: se niega para que golpee la fachada.
				local hinge = (base * pivotLocal).Position
				local turn = CFrame.new(hinge) * CFrame.fromAxisAngle(side, -angle) * CFrame.new(-hinge)
				for _, item in swinging do
					item.part.CFrame = turn * (base * item.origin)
				end
			end

			-- Tras el golpe: el edificio tiembla, caen las piezas y sale polvo.
			local hit = t >= windows.fall.from
			local after = LegendaryRules.progress(windows.fall, t)
			local strength = if hit then 1 - LegendaryRules.ease(after) else 0
			local offset = LegendaryRules.shake(t, 0.37, STAGING.shakeStuds * strength, STAGING.shakeHz)
			model:PivotTo(pivot * CFrame.new(offset.x, 0, offset.z))
			for _, item in falling do
				if not hit then
					continue
				end
				local p = LegendaryRules.ease(math.clamp(after * 1.3 - item.seed * 0.3, 0, 1))
				local turn = p * math.pi * (0.4 + item.seed)
				item.part.CFrame = CFrame.new(
					item.origin.Position + item.toward * p - Vector3.new(0, item.origin.Position.Y * p, 0)
				) * (item.origin - item.origin.Position) * CFrame.Angles(turn, 0, turn * 0.5)
				item.part.Transparency = item.transparency
					+ (1 - item.transparency) * math.max(0, p - 0.8) / 0.2
			end
			dust.Enabled = hit and after < 0.9

			options.director.setSceneFocus(lot.Position, CameraShots.deed, facing)
		end

		LegendaryKit.play(ctx, current, "Demolition", options.log, step, finish)
	end

	return { scene = { run = run }, cancelAll = cancelAll }
end

return Demolition

--!strict
-- Escena de los dados (DiceRolled, plan 08 Tarea 6). Dos dados 3D (tres con el Dado Extra) salen de la ficha
-- de quien tira, ruedan, botan y se paran enseñando arriba los valores exactos que mandó el servidor. Al
-- pararse brillan con el color del asiento y sobre ellos aparece la suma.
--
-- Solo muestra: el valor ya lo decidió el servidor y llega en el evento. `DiceRules.restAngles` deja cada
-- dado con su cara arriba; el resto del vuelo (giros, botes, desvío lateral) sale de los datos del evento, así
-- que todo el grupo ve la misma tirada. Dos variaciones: lanzados desde la ficha o caídos del cielo.
local CameraDirector = require("../../camera/CameraDirector")
local CityBuilder = require("../../world/CityBuilder")
local DiceRules = require("./DiceRules")
local LegendaryKit = require("../legendary/LegendaryKit")
local SceneDirector = require("../SceneDirector")
local Strings = require("../../../shared/config/Strings")
local Theme = require("../../ui/Theme")
local Types = require("../../../shared/rules/Types")
local Ui = require("../../../shared/config/Ui")

type Context = SceneDirector.Context
type Run = LegendaryKit.Run

export type Options = {
	director: CameraDirector.Director,
	city: () -> CityBuilder.CityHandles?,
	token: (id: string) -> Model?,
	colorOf: (id: string) -> Color3,
	log: (message: string) -> (),
}

export type Dice = { scene: SceneDirector.Scene, cancelAll: () -> () }

local STAGING = Ui.dice

type Die = {
	model: Model,
	from: Vector3,
	to: Vector3,
	yaw: number,
	rx: number,
	rz: number,
	axis: Vector3,
	turns: number,
	glow: Highlight,
	landed: boolean,
}

local Dice = {}

-- Un dado: cubo de caliza con los puntos en azul marino y el 1 en rojo, como un dado de mesa.
function Dice.makeDie(parent: Instance, index: number): Model
	local model = Instance.new("Model")
	model.Name = `Die{index}`
	local size = STAGING.size
	local body = LegendaryKit.part(model, "Body", Vector3.one * size, Theme.color.limestone, CFrame.new())
	body.Material = Enum.Material.SmoothPlastic
	model.PrimaryPart = body
	-- Cantos: una caja apenas menor y más oscura asoma en las aristas y les da volumen.
	local edge =
		LegendaryKit.part(model, "Edge", Vector3.one * (size * 1.002), Theme.color.limestoneDim, CFrame.new())
	edge.Transparency = 0.82
	local half = size / 2
	local spacing = size * 0.27
	local pip = size * 0.19
	for _, face in DiceRules.FACES do
		local n = Vector3.new(face.normal.x, face.normal.y, face.normal.z)
		local u = if math.abs(n.Y) > 0.5
			then Vector3.xAxis
			elseif math.abs(n.X) > 0.5 then Vector3.zAxis
			else Vector3.xAxis
		local v = n:Cross(u)
		local color = if face.value == 1 then Theme.color.signal else Theme.color.navy
		local dot = if face.value == 1 then pip * 1.5 else pip
		for _, at in DiceRules.pips(face.value) do
			local center = n * (half + 0.01) + u * (at[1] * spacing) + v * (at[2] * spacing)
			local piece = LegendaryKit.part(
				model,
				"Pip",
				Vector3.new(0.08, dot, dot),
				color,
				CFrame.fromMatrix(center, n, u)
			)
			piece.Shape = Enum.PartType.Cylinder
		end
	end
	model.Parent = parent
	return model
end

-- Base de la ficha y hacia dónde mira, plana. Sin ficha, la casilla de salida de la ciudad.
local function anchorOf(token: Model?, handles: CityBuilder.CityHandles): (Vector3, Vector3)
	if token ~= nil then
		local base = LegendaryKit.tokenBase(token)
		local body = token.PrimaryPart
		if base ~= nil and body ~= nil then
			local look = body.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			return base, if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
		end
	end
	local start = handles.positionOf(0)
	local yaw = handles.facingOf(0)
	return start, Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

function Dice.new(options: Options): Dice
	local active: { [Run]: () -> () } = {}

	local function cancelAll()
		for run, stop in table.clone(active) do
			run.cancelled = true
			stop()
		end
	end

	local function run(ctx: Context, event: Types.Event)
		cancelAll()
		ctx.show("")
		local handles = options.city()
		local values = DiceRules.values(event :: any)
		if handles == nil or #values == 0 then
			ctx.wait(ctx.duration)
			return
		end
		local id = event.playerId
		local token = if type(id) == "string" then options.token(id) else nil
		if token ~= nil then
			options.director.follow(token)
		end
		local current = LegendaryKit.begin(handles, "Dice")
		local base, forward = anchorOf(token, handles)
		local right = forward:Cross(Vector3.yAxis)
		local seat = if type(id) == "string" then options.colorOf(id) else Theme.color.taxi
		local fromSky = ctx.variation == 2
		local seed = DiceRules.total(values) * 7 + #values + (if type(id) == "string" then #id else 0)
		local dice: { Die } = {}
		for i, value in values do
			local spread = (i - (#values + 1) / 2) * STAGING.gap
			local wobble = (DiceRules.jitter(seed, i) - 0.5) * STAGING.gap * 0.35
			local reach = STAGING.reach + (DiceRules.jitter(seed, i + 10) - 0.5) * 2
			local to = base
				+ forward * reach
				+ right * (spread + wobble)
				+ Vector3.new(0, STAGING.size / 2, 0)
			local from = if fromSky
				then to + Vector3.new(0, STAGING.skyHeight, 0) - forward * 2
				else base + Vector3.new(0, STAGING.throwHeight, 0) + right * spread * 0.3
			local rx, rz = DiceRules.restAngles(value)
			local axis = Vector3.new(
				DiceRules.jitter(seed, i + 20) - 0.5,
				DiceRules.jitter(seed, i + 30) - 0.5,
				DiceRules.jitter(seed, i + 40) - 0.5
			)
			local model = Dice.makeDie(current.props, i)
			local glow = Instance.new("Highlight")
			glow.FillColor = seat
			glow.OutlineColor = seat
			glow.FillTransparency = 1
			glow.OutlineTransparency = 1
			glow.DepthMode = Enum.HighlightDepthMode.Occluded
			glow.Parent = model
			table.insert(dice, {
				model = model,
				from = from,
				to = to,
				yaw = DiceRules.jitter(seed, i + 50) * math.pi * 2,
				rx = rx,
				rz = rz,
				axis = if axis.Magnitude > 1e-3 then axis.Unit else Vector3.xAxis,
				turns = STAGING.turns + i * 0.5,
				glow = glow,
				landed = false,
			})
		end
		-- La suma aparece sobre los dados cuando se paran.
		local middle = Vector3.zero
		for _, die in dice do
			middle += die.to
		end
		middle /= #dice
		local text = if #values == 1
			then tostring(values[1])
			else Strings.get(
				"scene.dice.total",
				{ dice = table.concat(values :: { any }, " + "), total = DiceRules.total(values) }
			)
		local signBase = middle + Vector3.new(0, STAGING.signLift, 0)
		local sign =
			LegendaryKit.sign(current.props, signBase, text, STAGING.signWidth, STAGING.signHeight, "#1B3A6B")
		local signScale = Instance.new("UIScale")
		signScale.Scale = 0
		signScale.Parent = sign

		local function finish()
			if current.finished then
				return
			end
			current.finished = true
			active[current] = nil
			LegendaryKit.clear(current)
		end
		active[current] = finish

		local duration = math.max(ctx.duration, 0.01)
		local function step(t: number, _dt: number)
			local p = t / duration
			for i, die in dice do
				-- Cada dado sale un poco después del anterior, como al soltarlos de la mano.
				local lag = (i - 1) * STAGING.stagger
				local q = math.clamp((p - lag) / (1 - lag), 0, 1)
				local rest = STAGING.restAt
				local along = DiceRules.travel(q, rest)
				local height = DiceRules.hop(q, rest)
				local flat = die.from:Lerp(die.to, along)
				local drop = if fromSky then (1 - along) * (die.from.Y - die.to.Y) else 0
				local y = die.to.Y + height * STAGING.bounceHeight + drop
				if not fromSky then
					y += (1 - along) * (die.from.Y - die.to.Y)
				end
				local position = Vector3.new(flat.X, y, flat.Z)
				local spin = DiceRules.spinLeft(q, rest) * die.turns * math.pi * 2
				die.model:PivotTo(
					CFrame.new(position)
						* CFrame.Angles(0, die.yaw, 0)
						* CFrame.fromAxisAngle(die.axis, spin)
						* CFrame.Angles(die.rx, 0, die.rz)
				)
				-- Al pararse, el dado brilla con el color de quien tira y se apaga poco a poco.
				if q >= rest then
					local glowP = math.clamp((q - rest) / (1 - rest), 0, 1)
					die.glow.OutlineTransparency = 0.1 + 0.9 * glowP
					die.glow.FillTransparency = 0.55 + 0.45 * glowP
					die.landed = true
				end
			end
			-- La suma salta con un pequeño rebote cuando el último dado se para.
			local lastRest = (#dice - 1) * STAGING.stagger
				+ STAGING.restAt * (1 - (#dice - 1) * STAGING.stagger)
			local s = math.clamp((p - lastRest) / 0.12, 0, 1)
			local pop = if s < 1 then s * (1 + 0.35 * math.sin(s * math.pi)) else 1
			signScale.Scale = pop
			LegendaryKit.moveSign(sign, signBase + Vector3.new(0, s * 1.5, 0))
		end

		LegendaryKit.play(ctx, current, "Dice", options.log, step, finish)
	end

	return { scene = { run = run }, cancelAll = cancelAll }
end

return Dice

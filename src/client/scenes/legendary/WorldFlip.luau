--!strict
-- Escena de Mundo al Revés (CardPlayed WorldFlip). La ciudad retumba, todas las fichas suben al cielo, la
-- cámara da la vuelta entera al tablero mientras ellas giran en el aire, y cada una cae, con un bote, en la
-- casilla nueva que le dio el motor.
--
-- Los destinos salen de la vista del lote, que ya trae a cada jugador en su casilla. Los TokenMoved sin ruta
-- que siguen no mueven nada más: la ficha ya está donde dicen.
local LegendaryKit = require("./LegendaryKit")
local LegendaryRules = require("./LegendaryRules")
local LegendaryStaging = require("../../../shared/config/LegendaryStaging")
local SceneDirector = require("../SceneDirector")
local TokenRider = require("../../world/TokenRider")
local Types = require("../../../shared/rules/Types")
local WorldRules = require("../../world/WorldRules")

type Context = SceneDirector.Context
type Run = LegendaryKit.Run

local STAGING = LegendaryStaging.worldFlip

type Flyer = {
	token: Model,
	body: BasePart,
	start: CFrame,
	destination: Vector3,
	to: number,
	offset: any,
	seed: number,
}

export type WorldFlip = { scene: SceneDirector.Scene, cancelAll: () -> () }

local WorldFlip = {}

function WorldFlip.new(options: LegendaryKit.Options): WorldFlip
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

		local current = LegendaryKit.begin(handles, "WorldFlip")
		local windows = LegendaryRules.windows(STAGING, ctx.duration)
		local offsets = WorldRules.tokenOffsets(view.players)
		local flyers: { Flyer } = {}
		for order, seated in view.players do
			local token = options.token(seated.id)
			if token == nil or seated.status ~= "Active" or TokenRider.isHidden(token) then
				continue
			end
			local body, rest = TokenRider.takeOver(token)
			local destination = handles.positionOf(seated.position)
			table.insert(flyers, {
				token = token,
				body = body,
				start = rest,
				destination = Vector3.new(destination.X, rest.Position.Y, destination.Z),
				to = seated.position,
				offset = offsets[seated.id],
				seed = (order * 0.618033988749895) % 1,
			})
		end
		local startFacing = math.pi * 0.25

		local function finish()
			if current.finished then
				return
			end
			current.finished = true
			active[current] = nil
			for _, flyer in flyers do
				pcall(function()
					-- Entera, cada ficha queda en su casilla nueva; cortada, vuelve a donde estaba.
					if current.cancelled then
						TokenRider.restore(flyer.token)
					else
						TokenRider.place(flyer.token, flyer.to, flyer.offset)
					end
				end)
			end
			pcall(function()
				options.director.setSceneFocus(nil)
			end)
			LegendaryKit.clear(current)
		end
		active[current] = finish

		local function step(t: number, _dt: number)
			local lift = LegendaryRules.ease(LegendaryRules.progress(windows.lift, t))
			local spin = LegendaryRules.progress(windows.spin, t)
			local drop = LegendaryRules.progress(windows.drop, t)
			for _, flyer in flyers do
				local base = flyer.start.Position
				local height = 0
				local across = 0
				if t < windows.lift.from then
					-- Retumbo: la ficha tiembla en su sitio.
					local shake = LegendaryRules.shake(t, flyer.seed, STAGING.rumbleStuds, STAGING.rumbleHz)
					flyer.body.CFrame = flyer.start * CFrame.new(shake.x, 0, shake.z)
					continue
				elseif t < windows.drop.from then
					height = STAGING.liftStuds * lift
					-- Arriba se desplaza hacia su destino, mientras la cámara gira.
					across = LegendaryRules.ease(spin) * 0.85
				else
					local fall = LegendaryRules.ease(drop)
					height = STAGING.liftStuds * (1 - fall)
					-- Bote al tocar el suelo.
					if drop > 0.8 then
						height += math.sin((drop - 0.8) / 0.2 * math.pi) * STAGING.bounceStuds
					end
					across = 0.85 + 0.15 * fall
				end
				local position = base:Lerp(flyer.destination, across) + Vector3.new(0, height, 0)
				local turns = STAGING.tokenTurns * 2 * math.pi * (LegendaryRules.ease(spin) + lift * 0.25)
				flyer.body.CFrame = CFrame.new(position)
					* (flyer.start - flyer.start.Position)
					* CFrame.Angles(math.sin(turns) * 0.6, turns, math.cos(turns * 0.5) * 0.4)
			end

			-- La cámara da la vuelta entera a la ciudad mientras las fichas están arriba.
			local orbit = startFacing + STAGING.cameraTurns * 2 * math.pi * LegendaryRules.ease(spin)
			LegendaryKit.wide(options.director, handles.sizeId, orbit, t >= windows.lift.from)
		end

		LegendaryKit.play(ctx, current, "WorldFlip", options.log, step, finish)
	end

	return { scene = { run = run }, cancelAll = cancelAll }
end

return WorldFlip

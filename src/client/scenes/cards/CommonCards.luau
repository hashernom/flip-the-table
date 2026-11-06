--!strict
-- Escenas de las nueve cartas comunes (plan 08, Tarea 4) y de la reacción del Escudo (CardBlocked). Cada una
-- dura de 2 a 4 s y deja claro quién actuó y a quién afectó: la cámara va a la ficha que importa, un cartel
-- con el nombre de la carta y de los jugadores flota encima y un objeto propio de la carta hace la acción.
--
-- Solo muestran: el efecto ya lo aplicó el servidor. Todas usan el mismo esqueleto (`LegendaryKit.play`, una
-- carpeta de piezas que se borra al acabar) y cada carta aporta su `build`, que monta las piezas y devuelve
-- el paso por fotograma.
local Actors = require("../Actors")
local CameraDirector = require("../../camera/CameraDirector")
local CardSceneRules = require("./CardSceneRules")
local Cards = require("../../../shared/config/Cards")
local CardStaging = require("../../../shared/config/CardStaging")
local CityBuilder = require("../../world/CityBuilder")
local Dice = require("../game/Dice")
local Economy = require("../../../shared/config/Economy")
local LegendaryKit = require("../legendary/LegendaryKit")
local LegendaryRules = require("../legendary/LegendaryRules")
local Robloxian = require("../../world/Robloxian")
local SceneDirector = require("../SceneDirector")
local Strings = require("../../../shared/config/Strings")
local Theme = require("../../ui/Theme")
local Types = require("../../../shared/rules/Types")

type Context = SceneDirector.Context
type Run = LegendaryKit.Run

local STAGING = CardStaging.common

export type Options = {
	director: CameraDirector.Director,
	city: () -> CityBuilder.CityHandles?,
	token: (id: string) -> Model?,
	nameOf: (id: string) -> string,
	-- Ids de los rivales de un jugador que siguen en la partida, para la Propina Forzada.
	rivalsOf: (id: string) -> { string },
	log: (message: string) -> (),
}

export type CommonCards = {
	scenes: { [string]: SceneDirector.Scene },
	cancelAll: () -> (),
}

-- Lo que una carta necesita para montarse.
type Env = {
	run: Run,
	handles: CityBuilder.CityHandles,
	actorId: string?,
	targetId: string?,
	actorBase: Vector3?,
	targetBase: Vector3?,
	actorToken: Model?,
	targetToken: Model?,
	options: Options,
	event: Types.Event,
}

-- Paso por fotograma: `p` va de 0 a 1 a lo largo de la escena.
type Step = (p: number, t: number) -> ()
type Build = (env: Env) -> (Step, (() -> ())?)

local function v3(p: LegendaryRules.Point3): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

local function p3(v: Vector3): LegendaryRules.Point3
	return { x = v.X, y = v.Y, z = v.Z }
end

-- Fase `p` dentro de [from, to], de 0 a 1.
local function phase(p: number, from: number, to: number): number
	return math.clamp((p - from) / (to - from), 0, 1)
end

-- Salto de entrada: crece con un pequeño rebote.
local function pop(s: number): number
	if s <= 0 then
		return 0
	elseif s >= 1 then
		return 1
	end
	return s * (1 + 0.4 * math.sin(s * math.pi))
end

-- Hacia dónde mira la ficha, plano.
local function forwardOf(token: Model?): Vector3
	local body = if token ~= nil then token.PrimaryPart else nil
	if body == nil then
		return Vector3.zAxis
	end
	local look = body.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
end

-- Cartel con el nombre de la carta y de los jugadores, que aparece con un salto sobre `base`.
local function header(env: Env, base: Vector3, text: string, color: string): (p: number) -> ()
	local at = base + Vector3.new(0, STAGING.headerLift, 0)
	local plate =
		LegendaryKit.sign(env.run.props, at, text, STAGING.headerWidth, STAGING.headerHeight, color, -4)
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = plate
	return function(p: number)
		local s = phase(p, 0.05, 0.2)
		local out = phase(p, 0.9, 1)
		scale.Scale = pop(s) * (1 - out)
		LegendaryKit.moveSign(plate, at + Vector3.new(0, s * 1.5, 0))
	end
end

local function names(env: Env, key: string, extra: { [string]: any }?): string
	local params: { [string]: any } = if extra ~= nil then table.clone(extra) else {}
	params.actor = if env.actorId ~= nil then env.options.nameOf(env.actorId) else ""
	params.target = if env.targetId ~= nil then env.options.nameOf(env.targetId) else ""
	return Strings.get(key, params)
end

-- Moneda dorada (cilindro plano).
local function coin(parent: Instance): Part
	local piece = LegendaryKit.part(
		parent,
		"Coin",
		Vector3.new(0.35, STAGING.coinSize, STAGING.coinSize),
		Color3.fromHex(STAGING.coinColor),
		CFrame.new()
	)
	piece.Shape = Enum.PartType.Cylinder
	piece.Material = Enum.Material.Metal
	return piece
end

-- Escudo: una burbuja azul envuelve la ficha del que se defiende; la carta del rival llega volando, choca
-- contra la burbuja y sale despedida dando vueltas.
local function shield(env: Env): Step
	local base = env.actorBase :: Vector3
	local center = base + Vector3.new(0, 3.5, 0)
	local bubble = LegendaryKit.part(
		env.run.props,
		"Shield",
		Vector3.one,
		Color3.fromHex(STAGING.shieldColor),
		CFrame.new(center)
	)
	bubble.Shape = Enum.PartType.Ball
	bubble.Material = Enum.Material.ForceField
	local blocked = env.event.cardId
	local def = if type(blocked) == "string" then Cards.byId[blocked] else nil
	local cardName = if def ~= nil then def.name else ""
	local head = header(env, base, names(env, "scene.common.shield", { card = cardName }), "#1B3A6B")
	local card = LegendaryKit.part(
		env.run.props,
		"BlockedCard",
		Vector3.new(2.4, 3.4, 0.2),
		Theme.color.signal,
		CFrame.new()
	)
	local forward = forwardOf(env.actorToken)
	local from = center + forward * 26 + Vector3.new(0, 8, 0)
	local hit = center + forward * (STAGING.shieldSize / 2)
	local away = hit + forward * 18 + Vector3.new(6, 14, 0)
	return function(p: number, t: number)
		head(p)
		local grow = pop(phase(p, 0, 0.2))
		local pulse = 1 + 0.04 * math.sin(t * 10)
		local impact = phase(p, 0.45, 0.55)
		local ring = if impact > 0 and impact < 1 then 1 + 0.15 * math.sin(impact * math.pi) else 1
		local fade = phase(p, 0.85, 1)
		bubble.Size = Vector3.one * (STAGING.shieldSize * grow * pulse * ring)
		bubble.Transparency = fade
		-- La carta del rival: llega, choca y rebota lejos dando vueltas.
		local inbound = phase(p, 0.2, 0.5)
		local bounce = phase(p, 0.5, 0.85)
		card.Transparency = if inbound <= 0 or bounce >= 1 then 1 else 0
		if bounce <= 0 then
			card.CFrame = CFrame.lookAt(from:Lerp(hit, inbound * inbound), hit)
				* CFrame.Angles(0, 0, inbound * 3)
		else
			local at = v3(LegendaryRules.arc(p3(hit), p3(away), bounce, 6))
			card.CFrame = CFrame.new(at) * CFrame.Angles(bounce * 9, bounce * 5, 0)
		end
	end
end

-- Dado Extra: un tercer dado cae del cielo sobre la ficha, bota y se queda brillando.
local function extraDie(env: Env): Step
	local base = env.actorBase :: Vector3
	local die = Dice.makeDie(env.run.props, 3)
	local head = header(env, base, names(env, "scene.common.extraDie"), "#E07A3C")
	local rest = base + forwardOf(env.actorToken) * 7 + Vector3.new(0, 1.7, 0)
	local sky = rest + Vector3.new(0, 30, 0)
	local glow = Instance.new("Highlight")
	glow.FillColor = Theme.color.taxi
	glow.OutlineColor = Theme.color.taxi
	glow.FillTransparency = 1
	glow.OutlineTransparency = 1
	glow.Parent = die
	return function(p: number, t: number)
		head(p)
		local fall = phase(p, 0.1, 0.45)
		local bounce = phase(p, 0.45, 0.65)
		local y = if bounce <= 0
			then sky.Y + (rest.Y - sky.Y) * fall * fall
			else rest.Y + 4 * bounce * (1 - bounce) * 3
		local spin = (1 - phase(p, 0.1, 0.65)) * 8
		die:PivotTo(
			CFrame.new(rest.X, y, rest.Z) * CFrame.Angles(spin, spin * 0.7, 0) * CFrame.Angles(0, t * 0.3, 0)
		)
		if p > 0.65 then
			local g = phase(p, 0.65, 1)
			glow.OutlineTransparency = g
			glow.FillTransparency = 0.5 + 0.5 * g
		end
	end
end

-- Marcha Atrás: una flecha de tráfico gigante aparece sobre la ficha y da media vuelta.
local function reverse(env: Env): Step
	local base = env.actorBase :: Vector3
	local head = header(env, base, names(env, "scene.common.reverse"), "#C4382B")
	local color = Color3.fromHex(STAGING.arrowColor)
	local pieces: { { part: Part, offset: CFrame } } = {}
	local function add(size: Vector3, offset: CFrame)
		local piece = LegendaryKit.part(env.run.props, "Arrow", size, color, CFrame.new())
		piece.Material = Enum.Material.Neon
		table.insert(pieces, { part = piece, offset = offset })
	end
	-- Flecha en U: dos brazos, el codo y la punta.
	add(Vector3.new(1, 6, 0.6), CFrame.new(-2, 0, 0))
	add(Vector3.new(1, 4, 0.6), CFrame.new(2, 1, 0))
	add(Vector3.new(5, 1, 0.6), CFrame.new(0, 3, 0))
	add(Vector3.new(2.4, 2.4, 0.6), CFrame.new(-2, -3.2, 0) * CFrame.Angles(0, 0, math.rad(45)))
	local forward = forwardOf(env.actorToken)
	local center = base + Vector3.new(0, 11, 0)
	return function(p: number)
		head(p)
		local s = pop(phase(p, 0.1, 0.3)) * (1 - phase(p, 0.88, 1))
		local turn = LegendaryRules.ease(phase(p, 0.35, 0.7)) * math.pi
		local frame = CFrame.lookAt(center, center + forward) * CFrame.Angles(0, turn, 0)
		for _, item in pieces do
			local o = item.offset
			item.part.CFrame = frame * CFrame.new(o.Position * s) * o.Rotation
			item.part.Transparency = if s <= 0.01 then 1 else 0
		end
	end
end

-- Propina Forzada: de cada rival sale una moneda que cruza en arco hasta la ficha de quien juega.
local function forcedTip(env: Env): Step
	local base = env.actorBase :: Vector3
	local head = header(
		env,
		base,
		names(env, "scene.common.forcedTip") .. "  +" .. tostring(Economy.cards.forcedTip),
		"#F5C518"
	)
	type Flight = { part: Part, from: Vector3, delay: number }
	local flights: { Flight } = {}
	local rivals: { string } = if env.actorId ~= nil then env.options.rivalsOf(env.actorId) else {}
	for order, id in rivals do
		local token = env.options.token(id)
		local from = if token ~= nil then LegendaryKit.tokenBase(token) else nil
		if from ~= nil then
			for k = 0, 1 do
				table.insert(flights, {
					part = coin(env.run.props),
					from = from + Vector3.new(0, 6, 0),
					delay = (order - 1) * 0.04 + k * 0.07,
				})
			end
		end
	end
	local to = base + Vector3.new(0, 5, 0)
	return function(p: number, t: number)
		head(p)
		for _, flight in flights do
			local q = phase(p, 0.15 + flight.delay, 0.75 + flight.delay)
			flight.part.Transparency = if q <= 0 or q >= 1 then 1 else 0
			local at = v3(LegendaryRules.arc(p3(flight.from), p3(to), LegendaryRules.ease(q), 16))
			flight.part.CFrame = CFrame.new(at) * CFrame.Angles(0, t * 12, 0)
		end
	end
end

-- Descuento: una etiqueta de precio con «-50 %» baja colgada de un hilo y se balancea sobre la ficha.
local function discount(env: Env): Step
	local base = env.actorBase :: Vector3
	local head = header(env, base, names(env, "scene.common.discount"), "#1B3A6B")
	local percent = math.floor((1 - Economy.cards.discountMultiplier) * 100 + 0.5)
	local hook = base + Vector3.new(0, 20, 0)
	local tag =
		LegendaryKit.part(env.run.props, "Tag", Vector3.new(5, 3, 0.3), Theme.color.taxi, CFrame.new(hook))
	local cord = LegendaryKit.part(
		env.run.props,
		"String",
		Vector3.new(0.12, 1, 0.12),
		Theme.color.asphalt,
		CFrame.new(hook)
	)
	local label = LegendaryKit.sign(env.run.props, hook, `-{percent}%`, 110, 60, "#F5C518", 0)
	return function(p: number, t: number)
		head(p)
		local drop = LegendaryRules.ease(phase(p, 0.1, 0.4))
		local length = 9 * drop
		local swing = math.sin(t * 5) * 0.5 * (1 - phase(p, 0.4, 1)) + math.sin(t * 5) * 0.08
		local end_ = hook + Vector3.new(math.sin(swing) * length, -math.cos(swing) * length, 0)
		tag.CFrame = CFrame.new(end_) * CFrame.Angles(0, 0, swing)
		cord.Size = Vector3.new(0.12, math.max(0.1, length), 0.12)
		cord.CFrame = CFrame.new((hook + end_) / 2) * CFrame.Angles(0, 0, swing)
		local visible = drop > 0 and p < 0.95
		tag.Transparency = if visible then 0 else 1
		cord.Transparency = if visible then 0 else 1
		LegendaryKit.moveSign(label, end_ + Vector3.new(0, 0, 0.5))
		label.Visible = visible
	end
end

-- Empujón: un guante de boxeo gigante sale por detrás de la ficha rival y le da un empujón; la ficha
-- se sacude hacia delante y vuelve a su sitio (el avance de verdad lo enseña su recorrido, después).
local function shove(env: Env): (Step, () -> ())
	local base = env.targetBase :: Vector3
	local token = env.targetToken
	local head = header(env, base, names(env, "scene.common.shove"), "#C4382B")
	local forward = forwardOf(token)
	local glove = LegendaryKit.part(env.run.props, "Glove", Vector3.one * 4, Theme.color.signal, CFrame.new())
	glove.Shape = Enum.PartType.Ball
	local cuff =
		LegendaryKit.part(env.run.props, "Cuff", Vector3.new(2.5, 3, 3), Theme.color.limestone, CFrame.new())
	cuff.Shape = Enum.PartType.Cylinder
	local start = if token ~= nil then token:GetPivot() else nil
	local function restore()
		if token ~= nil and start ~= nil and token.Parent ~= nil then
			token:PivotTo(start)
		end
	end
	local at = base + Vector3.new(0, 3, 0)
	return function(p: number)
		head(p)
		local windup = LegendaryRules.ease(phase(p, 0.1, 0.4))
		local punch = phase(p, 0.4, 0.5)
		local back = phase(p, 0.55, 0.9)
		local distance = 16 - 6 * windup * (1 - punch) - 10 * punch + 12 * back
		local pos = at - forward * (3 + distance)
		glove.CFrame = CFrame.lookAt(pos, at)
		cuff.CFrame = CFrame.lookAt(pos - forward * 2.6, at) * CFrame.Angles(0, math.rad(90), 0)
		local visible = p > 0.08 and p < 0.92
		glove.Transparency = if visible then 0 else 1
		cuff.Transparency = if visible then 0 else 1
		-- La ficha rival recibe el golpe: un salto hacia delante que se amortigua.
		if token ~= nil and start ~= nil then
			local hit = phase(p, 0.48, 0.8)
			local jolt = if hit > 0 and hit < 1 then math.sin(hit * math.pi) * (1 - hit) * 5 else 0
			token:PivotTo(start + forward * jolt + Vector3.new(0, jolt * 0.3, 0))
		end
	end,
		restore
end

-- Multa: un policía se acerca a la ficha rival y le entrega el parte; el parte sale volando hacia la ficha.
local function fine(env: Env): (Step, () -> ())
	local base = env.targetBase :: Vector3
	local forward = forwardOf(env.targetToken)
	local side = forward:Cross(Vector3.yAxis)
	local head =
		header(env, base, names(env, "scene.common.fine") .. "  -" .. tostring(Economy.cards.fine), "#C4382B")
	local from = base + side * 16 + forward * 4
	local stop = base + side * 5 + forward * 1
	local facing = (base - stop) * Vector3.new(1, 0, 1)
	local police = Actors.spawn("Police", CFrame.lookAt(from, from + facing))
	local ticket = LegendaryKit.part(
		env.run.props,
		"Ticket",
		Vector3.new(1.6, 2.2, 0.1),
		Theme.color.limestone,
		CFrame.new(from)
	)
	local band = LegendaryKit.part(
		env.run.props,
		"TicketBand",
		Vector3.new(1.62, 0.5, 0.12),
		Theme.color.signal,
		CFrame.new(from)
	)
	local function release()
		if police ~= nil then
			pcall(Actors.despawn, police)
		end
	end
	return function(p: number, t: number)
		head(p)
		local walk = LegendaryRules.ease(phase(p, 0, 0.4))
		local at = from:Lerp(stop, walk)
		local walking = walk > 0 and walk < 1
		local hand = phase(p, 0.45, 0.6)
		if police ~= nil then
			local root = CFrame.lookAt(at, at + facing) * CFrame.new(0, Robloxian.TORSO_HEIGHT, 0)
			Actors.pose(police, root, if walking then math.sin(t * 10) * 0.6 else 0, 0.3 + 0.7 * hand)
		end
		-- El parte: en la mano del policía, se adelanta al entregarlo y vuela hasta la ficha.
		local fly = phase(p, 0.6, 0.85)
		local holding = at + Vector3.new(0, Robloxian.TORSO_HEIGHT + 1, 0) + facing.Unit * (1 + 1.5 * hand)
		local target = base + Vector3.new(0, 5.5, 0)
		local pos = v3(LegendaryRules.arc(p3(holding), p3(target), fly, 3))
		local frame = CFrame.lookAt(pos, pos + facing) * CFrame.Angles(0, 0, fly * 6)
		ticket.CFrame = frame
		band.CFrame = frame * CFrame.new(0, 0.7, 0)
		local visible = p > 0.3 and fly < 1
		ticket.Transparency = if visible then 0 else 1
		band.Transparency = if visible then 0 else 1
	end,
		release
end

-- Soborno: un maletín se abre sobre la ficha y de él salen billetes; el cartel dice que se libra del
-- Tribunal.
local function bribe(env: Env): Step
	local base = env.actorBase :: Vector3
	local head = header(env, base, names(env, "scene.common.bribe"), "#1B3A6B")
	local center = base + Vector3.new(0, 9, 0)
	local brown = Color3.fromHex(STAGING.caseColor)
	local case = LegendaryKit.part(env.run.props, "Case", Vector3.new(5, 3, 1.6), brown, CFrame.new(center))
	local lid = LegendaryKit.part(env.run.props, "Lid", Vector3.new(5, 0.4, 1.6), brown, CFrame.new(center))
	local handle = LegendaryKit.part(
		env.run.props,
		"Handle",
		Vector3.new(1.6, 0.5, 0.4),
		Theme.color.asphalt,
		CFrame.new(center)
	)
	type Bill = { parts: { Part }, seed: number }
	local bills: { Bill } = {}
	for i = 1, STAGING.bribeBills do
		local parts = LegendaryKit.bill(env.run.props, "#8DB86B", "#4E7A3A", CFrame.new(center))
		for _, piece in parts do
			piece.Transparency = 1
		end
		table.insert(bills, { parts = parts, seed = (i * 0.618) % 1 })
	end
	local forward = forwardOf(env.actorToken)
	return function(p: number, t: number)
		head(p)
		local s = pop(phase(p, 0.05, 0.25)) * (1 - phase(p, 0.9, 1))
		local frame = CFrame.lookAt(center, center + forward) * CFrame.Angles(0, 0, math.sin(t * 3) * 0.08)
		local open = LegendaryRules.ease(phase(p, 0.3, 0.45)) * math.rad(110)
		case.Size = Vector3.new(5, 3, 1.6) * math.max(s, 0.01)
		case.CFrame = frame
		lid.CFrame = frame
			* CFrame.new(0, 1.5 * s, -0.8 * s)
			* CFrame.Angles(-open, 0, 0)
			* CFrame.new(0, 0.2, 0.8 * s)
		handle.CFrame = frame * CFrame.new(0, 1.75 * s, 0)
		local visible = s > 0.01
		case.Transparency = if visible then 0 else 1
		lid.Transparency = if visible then 0 else 1
		handle.Transparency = if visible then 0 else 1
		local burst = phase(p, 0.45, 0.95)
		for _, bill in bills do
			local offset = CardSceneRules.burst(bill.seed, burst, CardStaging.inflation)
			local shown = burst > 0 and burst < 1
			for _, piece in bill.parts do
				piece.Transparency = if shown then 0 else 1
			end
			if shown then
				local flutter = t * 8 + bill.seed * 9
				LegendaryKit.placeBill(
					bill.parts,
					CFrame.new(center + Vector3.new(offset.x * 0.6, offset.y * 0.8, offset.z * 0.6))
						* CFrame.Angles(math.sin(flutter) * 0.7, flutter, 0)
				)
			end
		end
	end
end

-- Espía: un foco cae del cielo sobre la ficha rival y unos prismáticos gigantes la miran.
local function spy(env: Env): Step
	local base = env.targetBase :: Vector3
	local head = header(env, base, names(env, "scene.common.spy"), "#1B3A6B")
	local beam = LegendaryKit.part(
		env.run.props,
		"Beam",
		Vector3.new(60, 1, 1),
		Color3.fromHex(STAGING.beamColor),
		CFrame.new()
	)
	beam.Shape = Enum.PartType.Cylinder
	beam.Material = Enum.Material.Neon
	local forward = forwardOf(env.targetToken)
	local lensA =
		LegendaryKit.part(env.run.props, "Lens", Vector3.new(3, 1.8, 1.8), Theme.color.asphalt, CFrame.new())
	local lensB =
		LegendaryKit.part(env.run.props, "Lens", Vector3.new(3, 1.8, 1.8), Theme.color.asphalt, CFrame.new())
	local bridge = LegendaryKit.part(
		env.run.props,
		"Bridge",
		Vector3.new(0.8, 0.8, 1.4),
		Theme.color.steel,
		CFrame.new()
	)
	lensA.Shape = Enum.PartType.Cylinder
	lensB.Shape = Enum.PartType.Cylinder
	return function(p: number, t: number)
		head(p)
		local light = phase(p, 0.05, 0.25) * (1 - phase(p, 0.85, 1))
		local width = 9 * light
		beam.Size = Vector3.new(60, math.max(0.1, width), math.max(0.1, width))
		beam.CFrame = CFrame.new(base + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90))
		beam.Transparency = 1 - 0.55 * light
		-- Los prismáticos llegan, enfocan (se acercan un poco) y se van.
		local come = LegendaryRules.ease(phase(p, 0.2, 0.45))
		local leave = phase(p, 0.8, 1)
		local eye = base
			+ Vector3.new(0, 7, 0)
			+ forward * (24 - 12 * come + 20 * leave)
			+ Vector3.new(0, math.sin(t * 4) * 0.4, 0)
		local frame = CFrame.lookAt(eye, base + Vector3.new(0, 4, 0))
		lensA.CFrame = frame * CFrame.new(-1.1, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
		lensB.CFrame = frame * CFrame.new(1.1, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
		bridge.CFrame = frame
		local visible = come > 0 and leave < 1
		for _, piece in { lensA, lensB, bridge } do
			piece.Transparency = if visible then 0 else 1
		end
	end
end

-- Qué carta usa cada escena y a qué ficha mira la cámara: "actor" o "target".
local BUILDS: { [string]: { build: Build, focus: string } } = {
	Shield = { build = shield :: any, focus = "actor" },
	ExtraDie = { build = extraDie :: any, focus = "actor" },
	Reverse = { build = reverse :: any, focus = "actor" },
	ForcedTip = { build = forcedTip :: any, focus = "actor" },
	Discount = { build = discount :: any, focus = "actor" },
	Shove = { build = shove :: any, focus = "target" },
	Fine = { build = fine :: any, focus = "target" },
	Bribe = { build = bribe :: any, focus = "actor" },
	Spy = { build = spy :: any, focus = "target" },
}

local CommonCards = {}

CommonCards.CARD_IDS =
	{ "Shield", "ExtraDie", "Reverse", "ForcedTip", "Discount", "Shove", "Fine", "Bribe", "Spy" }

function CommonCards.new(options: Options): CommonCards
	local active: { [Run]: () -> () } = {}

	local function cancelAll()
		for run, stop in table.clone(active) do
			run.cancelled = true
			stop()
		end
	end

	local function sceneFor(cardId: string): SceneDirector.Scene
		local spec = BUILDS[cardId]
		local function run(ctx: Context, event: Types.Event)
			cancelAll()
			ctx.show("")
			local handles = options.city()
			-- El Escudo llega como CardBlocked: quien se defiende es `byPlayerId`.
			local actorId = if event.type == "CardBlocked" then event.byPlayerId else event.playerId
			local targetId = event.targetId
			local actorToken = if type(actorId) == "string" then options.token(actorId) else nil
			local targetToken = if type(targetId) == "string" then options.token(targetId) else nil
			local env: Env = {
				run = nil :: any,
				handles = handles :: any,
				actorId = if type(actorId) == "string" then actorId else nil,
				targetId = if type(targetId) == "string" then targetId else nil,
				actorToken = actorToken,
				targetToken = targetToken,
				actorBase = if actorToken ~= nil then LegendaryKit.tokenBase(actorToken) else nil,
				targetBase = if targetToken ~= nil then LegendaryKit.tokenBase(targetToken) else nil,
				options = options,
				event = event,
			}
			local focusToken = if spec.focus == "target" then targetToken else actorToken
			local focusBase = if spec.focus == "target" then env.targetBase else env.actorBase
			-- Sin ciudad o sin la ficha que importa, la escena espera su tiempo: el director pone el mundo al día.
			if handles == nil or focusToken == nil or focusBase == nil then
				ctx.wait(ctx.duration)
				return
			end
			options.director.follow(focusToken)
			local current = LegendaryKit.begin(handles, `Card{cardId}`)
			env.run = current
			local built: Step? = nil
			local cleanup: (() -> ())? = nil
			local ok, err = pcall(function()
				built, cleanup = spec.build(env)
			end)
			local function finish()
				if current.finished then
					return
				end
				current.finished = true
				active[current] = nil
				if cleanup ~= nil then
					pcall(cleanup)
				end
				LegendaryKit.clear(current)
			end
			active[current] = finish
			if not ok or built == nil then
				options.log(`{cardId}: no se pudo montar la escena: {tostring(err)}`)
				finish()
				ctx.wait(ctx.duration)
				return
			end
			local step = built :: Step
			local duration = math.max(ctx.duration, 0.01)
			LegendaryKit.play(ctx, current, cardId, options.log, function(t: number)
				step(t / duration, t)
			end, finish)
		end
		return { run = run }
	end

	local scenes: { [string]: SceneDirector.Scene } = {}
	for _, cardId in CommonCards.CARD_IDS do
		scenes[cardId] = sceneFor(cardId)
	end
	-- La reacción del Escudo es su propio evento.
	scenes.CardBlocked = scenes.Shield
	return { scenes = scenes, cancelAll = cancelAll }
end

return CommonCards

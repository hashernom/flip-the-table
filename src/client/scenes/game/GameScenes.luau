--!strict
-- Escenas de la partida (plan 08, Tarea 6): renta, construcción, hipoteca, subasta, bancarrota, pactos y
-- traición, Zona Caliente, corona, furia, espectros, paso por la Salida, intercambio, inicio de la partida,
-- Última Ronda y podio. Los dados tienen su módulo (`Dice`).
--
-- Usan el esqueleto de las cartas comunes (`CommonCards.runner`). Solo muestran: el servidor ya cobró,
-- construyó o movió la corona; cuando la escena cambia algo del mundo a la vista (un nivel, un dueño, la
-- Zona Caliente), concilia con la vista del lote a mitad de escena, y el director lo vuelve a hacer al final.
local Actors = require("../Actors")
local BuildingView = require("../../world/BuildingView")
local CameraShots = require("../../../shared/config/CameraShots")
local CardSceneRules = require("../cards/CardSceneRules")
local CardStaging = require("../../../shared/config/CardStaging")
local CityLayout = require("../../../shared/config/CityLayout")
local CommonCards = require("../cards/CommonCards")
local Economy = require("../../../shared/config/Economy")
local LegendaryKit = require("../legendary/LegendaryKit")
local Perks = require("../../../shared/config/Perks")
local LegendaryRules = require("../legendary/LegendaryRules")
local SceneDirector = require("../SceneDirector")
local Strings = require("../../../shared/config/Strings")
local Theme = require("../../ui/Theme")
local Types = require("../../../shared/rules/Types")

type Env = CommonCards.Env
type Step = CommonCards.Step

local kit = CommonCards.kit
local phase, pop = kit.phase, kit.pop
local STAGING = CardStaging.game

export type Options = CommonCards.Options & {
	-- Socios de un pacto que ya no está en la vista (vencido): el cliente recuerda los últimos pactos.
	pactOf: (pactId: string) -> (string?, string?),
	-- Enseña el panel de la Cartelera durante `seconds`.
	showBillboard: (event: any, seconds: number) -> (),
	-- Concilia el mundo con la vista ya (nivel, dueño, Zona Caliente) a mitad de escena.
	reconcile: (view: any) -> (),
	-- Color del asiento de un jugador.
	colorOf: (id: string) -> Color3,
}

export type GameScenes = {
	scenes: { [string]: SceneDirector.Scene },
	cancelAll: () -> (),
}

local GameScenes = {}

local function opts(env: Env): Options
	return env.options :: any
end

-- Cartel suelto sobre un punto, que salta al entrar y se va al final.
local function floating(
	env: Env,
	at: Vector3,
	text: string,
	color: string,
	from: number,
	width: number?
): (p: number) -> ()
	local plate = LegendaryKit.sign(env.run.props, at, text, width or 170, 56, color, -4)
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = plate
	return function(p: number)
		local s = phase(p, from, from + 0.15)
		scale.Scale = pop(s) * (1 - phase(p, 0.9, 1))
		LegendaryKit.moveSign(plate, at + Vector3.new(0, s * 2, 0))
	end
end

-- Mira a un solar desde la calle, como el Ladrón de Escrituras.
local function focusLot(env: Env, index: number): CFrame
	local lot = env.handles.lotOf(index)
	local look = lot.LookVector
	env.options.director.setSceneFocus(lot.Position, CameraShots.deed, math.atan2(-look.X, -look.Z))
	return lot
end

-- Concilia una sola vez cuando `p` pasa de `at`.
local function reconcileAt(env: Env, at: number): (p: number) -> ()
	local done = false
	return function(p: number)
		if not done and p >= at then
			done = true
			pcall(opts(env).reconcile, env.view)
		end
	end
end

-- Lluvia de monedas de `from` a `to`, en arco y una tras otra.
local function coinStream(
	env: Env,
	from: Vector3,
	to: Vector3,
	count: number,
	from_: number,
	to_: number
): (p: number, t: number) -> ()
	type Flight = { part: Part, delay: number }
	local flights: { Flight } = {}
	for i = 1, count do
		table.insert(flights, { part = kit.coin(env.run.props), delay = (i - 1) * 0.04 })
	end
	return function(p: number, t: number)
		for _, flight in flights do
			local q = phase(p, from_ + flight.delay, to_ + flight.delay)
			flight.part.Transparency = if q <= 0 or q >= 1 then 1 else 0
			local at = kit.v3(LegendaryRules.arc(kit.p3(from), kit.p3(to), LegendaryRules.ease(q), 10))
			flight.part.CFrame = CFrame.new(at) * CFrame.Angles(0, t * 12, 0)
		end
	end
end

-- Renta: quien paga suelta monedas que vuelan al edificio del dueño; «-X» sobre quien paga y «+X» sobre el
-- edificio. La variación 2 cambia las monedas por un billete gigante que cruza la calle revoloteando.
local function rent(env: Env): Step
	local base = env.actorBase :: Vector3
	local amount = if type(env.event.amount) == "number" then env.event.amount else 0
	local index = env.event.index
	local lotAt = if type(index) == "number" then env.handles.lotOf(index).Position else base
	local target = lotAt + Vector3.new(0, 8, 0)
	local head = kit.header(env, base, kit.names(env, "scene.rent.header", { amount = amount }), "#C4382B")
	local minus = floating(env, base + Vector3.new(0, 9, 0), `-{amount}`, "#C4382B", 0.2, 120)
	local plus = floating(env, target + Vector3.new(0, 6, 0), `+{amount}`, "#F5C518", 0.65, 120)
	local fly: (p: number, t: number) -> ()
	if env.variation == 2 then
		local bill = LegendaryKit.bill(env.run.props, "#8DB86B", "#4E7A3A", CFrame.new(base))
		for _, piece in bill do
			piece.Size *= Vector3.new(3, 1, 3)
		end
		fly = function(p: number, t: number)
			local q = phase(p, 0.2, 0.75)
			local at = kit.v3(LegendaryRules.arc(kit.p3(base + Vector3.new(0, 5, 0)), kit.p3(target), q, 12))
			for _, piece in bill do
				piece.Transparency = if q > 0 and q < 1 then 0 else 1
			end
			LegendaryKit.placeBill(
				bill,
				CFrame.new(at) * CFrame.Angles(math.sin(t * 9) * 0.6, t * 3, math.cos(t * 7) * 0.3)
			)
		end
	else
		fly = coinStream(env, base + Vector3.new(0, 5, 0), target, STAGING.rentCoins, 0.2, 0.7)
	end
	return function(p: number, t: number)
		head(p)
		minus(p)
		plus(p)
		fly(p, t)
	end
end

-- Construir: un gancho de grúa baja del cielo con el añadido del nivel, lo deja en el edificio y este
-- destella con su nivel nuevo. Bajar de nivel (venta, Demolición) lo sube y se lo lleva.
local function build(env: Env): Step
	local index = env.event.index :: number
	local from = if type(env.event.from) == "number" then env.event.from else 0
	local to = if type(env.event.to) == "number" then env.event.to else 0
	local up = to > from
	local lot = env.handles.lotOf(index)
	-- El añadido se posa en lo alto del edificio, sea cual sea su altura.
	local model = BuildingView.modelOf(index)
	local roof = STAGING.buildSeat
	if model ~= nil then
		local ok, box, size = pcall(function()
			return model:GetBoundingBox()
		end)
		if ok then
			roof = (box :: CFrame).Position.Y + (size :: Vector3).Y / 2 - lot.Position.Y
		end
	end
	local top = lot.Position + Vector3.new(0, roof + STAGING.buildTop, 0)
	local seat = lot.Position + Vector3.new(0, roof + 2, 0)
	local cable = LegendaryKit.part(
		env.run.props,
		"Cable",
		Vector3.new(0.25, 1, 0.25),
		Theme.color.asphalt,
		CFrame.new(top)
	)
	local hook =
		LegendaryKit.part(env.run.props, "Hook", Vector3.new(1.4, 1, 1.4), Theme.color.works, CFrame.new(top))
	local crate =
		LegendaryKit.part(env.run.props, "Addon", Vector3.new(6, 4, 6), Theme.color.taxi, CFrame.new(top))
	local stripe = LegendaryKit.part(
		env.run.props,
		"AddonStripe",
		Vector3.new(6.1, 0.8, 6.1),
		Theme.color.asphalt,
		CFrame.new(top)
	)
	local label = floating(
		env,
		lot.Position + Vector3.new(0, roof + 10, 0),
		Strings.get(if up then "scene.build.up" else "scene.build.down", { level = to }),
		if up then "#E07A3C" else "#A8AEB4",
		0.55
	)
	local swap = reconcileAt(env, 0.55)
	local flashed = false
	return function(p: number, t: number)
		swap(p)
		if not flashed and p >= 0.55 then
			flashed = true
			BuildingView.flash(index)
		end
		-- Sube: baja cargado (0 a 0,5), suelta y sube vacío. Baja: llega vacío, engancha y se lo lleva.
		local descend = LegendaryRules.ease(phase(p, 0.05, 0.5))
		local ascend = phase(p, 0.6, 0.95)
		local depth = descend * (1 - ascend * ascend)
		local hookAt = top:Lerp(seat + Vector3.new(0, 3, 0), depth)
			+ Vector3.new(math.sin(t * 2) * 0.3 * (1 - depth), 0, 0)
		local length = (top - hookAt).Magnitude
		cable.Size = Vector3.new(0.25, math.max(0.1, length), 0.25)
		cable.CFrame = CFrame.new((top + hookAt) / 2)
		hook.CFrame = CFrame.new(hookAt)
		cable.Transparency = 0
		hook.Transparency = 0
		local carrying = if up then p < 0.55 else p >= 0.55
		local crateAt = if carrying then hookAt - Vector3.new(0, 2.5, 0) else seat
		-- Variación 2: sin grúa. El añadido cae del cielo y bota en el tejado (o sale volando si baja de nivel).
		if env.variation == 2 then
			cable.Transparency = 1
			hook.Transparency = 1
			if up then
				local fall = phase(p, 0.05, 0.45)
				local hop = phase(p, 0.45, 0.6)
				local y = seat.Y + 30 * (1 - fall * fall) + 4 * hop * (1 - hop) * 3
				crateAt = Vector3.new(seat.X, y, seat.Z)
				carrying = p < 0.6
			else
				local away = phase(p, 0.55, 0.95)
				crateAt = seat + Vector3.new(0, away * away * 40, 0)
				carrying = p >= 0.55
			end
		end
		local crateVisible = carrying and p > 0.05 and p < 0.95
		local spin = if env.variation == 2 and carrying then CFrame.Angles(0, t * 4, 0) else CFrame.new()
		crate.CFrame = CFrame.new(crateAt) * spin
		stripe.CFrame = CFrame.new(crateAt) * spin
		crate.Transparency = if crateVisible then 0 else 1
		stripe.Transparency = if crateVisible then 0 else 1
		label(p)
	end
end

-- Hipoteca y deshipoteca: un sello cae sobre el edificio con «Hipotecada» o «Libre».
local function mortgage(env: Env): Step
	local index = env.event.index :: number
	local lot = env.handles.lotOf(index)
	local mortgaged = env.event.type == "PropertyMortgaged"
	local amount = if type(env.event.amount) == "number" then env.event.amount else 0
	local text =
		Strings.get(if mortgaged then "scene.mortgage.on" else "scene.mortgage.off", { amount = amount })
	local stamp = floating(
		env,
		lot.Position + Vector3.new(0, 20, 0),
		text,
		if mortgaged then "#A8AEB4" else "#5A9E5A",
		0.1,
		230
	)
	local swap = reconcileAt(env, 0.3)
	return function(p: number)
		swap(p)
		stamp(p)
	end
end

-- Subasta: un mazo gigante golpea delante del solar; «Subasta» al empezar y «Sin venta» si nadie pujó.
local function auction(env: Env): Step
	local index = env.event.index :: number
	local lot = focusLot(env, index)
	local started = env.event.type == "AuctionStarted"
	-- El solar mira a la calle con su -Z (su LookVector): el mazo golpea en la acera, delante de la fachada.
	local street = lot.Position + lot.LookVector * STAGING.gavelStreet
	local wood = Color3.fromHex(STAGING.gavelWood)
	local head = LegendaryKit.part(env.run.props, "GavelHead", Vector3.new(7, 3.2, 3.2), wood, CFrame.new())
	head.Shape = Enum.PartType.Cylinder
	local shaft = LegendaryKit.part(env.run.props, "GavelShaft", Vector3.new(0.9, 9, 0.9), wood, CFrame.new())
	local block = LegendaryKit.part(
		env.run.props,
		"GavelBlock",
		Vector3.new(6, 1.2, 6),
		wood,
		CFrame.new(street + Vector3.new(0, 0.6, 0))
	)
	local sign = floating(
		env,
		street + Vector3.new(0, 16, 0),
		Strings.get(if started then "scene.auction.start" else "scene.auction.noSale"),
		if started then "#F5C518" else "#A8AEB4",
		0.35,
		210
	)
	local pivot = street + Vector3.new(4, 8, 0)
	return function(p: number)
		-- Dos golpes: el segundo, más fuerte.
		local swing = 0
		local s1 = phase(p, 0.1, 0.3)
		local s2 = phase(p, 0.35, 0.55)
		if s2 > 0 then
			swing = math.sin(s2 * math.pi) * 1.4
		else
			swing = math.sin(s1 * math.pi) * 0.9
		end
		local angle = -swing
		local frame = CFrame.new(pivot) * CFrame.Angles(0, 0, angle) * CFrame.new(-4.5, 0, 0)
		shaft.CFrame = frame * CFrame.Angles(0, 0, math.rad(90))
		head.CFrame = frame * CFrame.new(-4.5, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
		local visible = p > 0.05 and p < 0.92
		for _, piece in { head, shaft, block } do
			piece.Transparency = if visible then 0 else 1
		end
		sign(p)
	end
end

-- Bancarrota: llega una grúa, se lleva la ficha por los aires y el cartel lo anuncia. La ficha vuelve a su
-- sitio al acabar; la vista la deja como espectro.
local function bankruptcy(env: Env): (Step, () -> ())
	local base = env.actorBase :: Vector3
	local token = env.actorToken
	local head = kit.header(env, base, kit.names(env, "scene.bankruptcy.header"), "#C4382B")
	local forward = kit.forwardOf(token)
	local truckFrom = base - forward * 40
	local truckAt = base - forward * 9
	local truck = Actors.spawn("TowTruck", CFrame.lookAt(truckFrom, truckFrom + forward))
	local start = if token ~= nil then token:GetPivot() else nil
	local hookTop = base + Vector3.new(0, 14, 0)
	local cable = LegendaryKit.part(
		env.run.props,
		"TowCable",
		Vector3.new(0.3, 1, 0.3),
		Theme.color.asphalt,
		CFrame.new(hookTop)
	)
	local function restore()
		if truck ~= nil then
			pcall(Actors.despawn, truck)
		end
		if token ~= nil and start ~= nil and token.Parent ~= nil then
			token:PivotTo(start)
		end
	end
	return function(p: number, t: number)
		head(p)
		local arrive = LegendaryRules.ease(phase(p, 0, 0.3))
		local lift = LegendaryRules.ease(phase(p, 0.35, 0.6))
		local leave = phase(p, 0.65, 1)
		local truckPos = truckFrom:Lerp(truckAt, arrive) + forward * (leave * leave * 40)
		if truck ~= nil then
			truck:PivotTo(CFrame.lookAt(truckPos, truckPos + forward))
		end
		if token ~= nil and start ~= nil then
			local sway = math.sin(t * 6) * 0.15 * lift
			local carry = forward * (leave * leave * 40)
			token:PivotTo(start * CFrame.new(0, lift * 6, 0) * CFrame.Angles(sway, 0, 0) + carry)
		end
		local hookAt = base + Vector3.new(0, 5 + lift * 6, 0) + forward * (leave * leave * 40)
		local topAt = hookTop + forward * (leave * leave * 40)
		cable.Size = Vector3.new(0.3, math.max(0.1, (topAt - hookAt).Magnitude), 0.3)
		cable.CFrame = CFrame.new((topAt + hookAt) / 2)
		cable.Transparency = if lift > 0 and p < 0.95 then 0 else 1
	end,
		restore
end

-- Quiénes firman un pacto: sus dos socios, de la vista.
local function pactIds(event: Types.Event, view: any): (string?, string?)
	local pacts = if view ~= nil then view.pacts else nil
	if type(pacts) == "table" then
		for _, pact in pacts do
			if pact.id == event.pactId then
				return pact.a, pact.b
			end
		end
	end
	return event.playerId, nil
end

-- Pacto: una cuerda dorada une a los dos socios y el cartel «Pacto» aparece entre ellos.
local function pactFormed(env: Env): Step
	local a = env.actorBase :: Vector3
	local b = env.targetBase or a
	local mid = (a + b) / 2
	local across = (b - a) * Vector3.new(1, 0, 1)
	local side = if across.Magnitude > 1e-3 then across.Unit:Cross(Vector3.yAxis) else Vector3.zAxis
	env.options.director.setSceneFocus(mid, CameraShots.duel, math.atan2(-side.X, -side.Z))
	local rope = CardStaging.backstab
	local segments: { Part } = {}
	for i = 1, STAGING.pactSegments do
		segments[i] = LegendaryKit.part(
			env.run.props,
			"Rope",
			Vector3.new(rope.ropeThickness, rope.ropeThickness, 1),
			Color3.fromHex(rope.ropeColor),
			CFrame.new()
		)
		segments[i].Material = Enum.Material.Neon
	end
	local head =
		floating(env, mid + Vector3.new(0, 14, 0), kit.names(env, "scene.pact.formed"), "#1B3A6B", 0.4, 260)
	local from = a + Vector3.new(0, rope.ropeHeight, 0)
	local to = b + Vector3.new(0, rope.ropeHeight, 0)
	return function(p: number)
		head(p)
		local reach = LegendaryRules.ease(phase(p, 0.1, 0.45))
		local fade = phase(p, 0.85, 1)
		local count = #segments
		for i, piece in segments do
			local t0 = (i - 1) / count * reach
			local t1 = i / count * reach
			local p0 = kit.v3(CardSceneRules.rope(kit.p3(from), kit.p3(to), t0, rope.sagStuds))
			local p1 = kit.v3(CardSceneRules.rope(kit.p3(from), kit.p3(to), t1, rope.sagStuds))
			local length = (p1 - p0).Magnitude
			piece.Size = Vector3.new(rope.ropeThickness, rope.ropeThickness, math.max(0.05, length))
			if length > 1e-3 then
				piece.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
			end
			piece.Transparency = if reach > 0 then fade else 1
		end
	end
end

-- Traición (PactBroken): un foco cae sobre el traidor y un cartel gigante lo señala. La marca de traidor que
-- dura sus 3 rondas la lleva `world/TokenMarks`.
local function traitor(env: Env): Step
	local base = env.actorBase :: Vector3
	local beam = LegendaryKit.part(
		env.run.props,
		"Spotlight",
		Vector3.new(60, 1, 1),
		Color3.fromHex(STAGING.spotColor),
		CFrame.new()
	)
	beam.Shape = Enum.PartType.Cylinder
	beam.Material = Enum.Material.Neon
	local sign = floating(
		env,
		base + Vector3.new(0, 18, 0),
		kit.names(env, "scene.traitor.sign"),
		"#C4382B",
		0.25,
		300
	)
	local arrow = floating(env, base + Vector3.new(0, 11, 0), "▼", "#C4382B", 0.35, 60)
	return function(p: number, t: number)
		local light = phase(p, 0.05, 0.25) * (1 - phase(p, 0.88, 1))
		local width = 10 * light + math.sin(t * 6) * 0.4 * light
		beam.Size = Vector3.new(60, math.max(0.1, width), math.max(0.1, width))
		beam.CFrame = CFrame.new(base + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90))
		beam.Transparency = 1 - 0.55 * light
		sign(p)
		arrow(p)
	end
end

-- Corona: la corona vuela de la ficha del líder anterior a la del nuevo y cae sobre ella.
local function crown(env: Env): Step
	local to = env.targetBase :: Vector3
	local from = env.actorBase or (to + Vector3.new(0, 40, 0))
	local pieces = GameScenes.makeCrown(env.run.props)
	local sign =
		floating(env, to + Vector3.new(0, 17, 0), kit.names(env, "scene.crown.header"), "#F5C518", 0.6, 260)
	return function(p: number, t: number)
		local q = LegendaryRules.ease(phase(p, 0.1, 0.65))
		local at = kit.v3(
			LegendaryRules.arc(
				kit.p3(from + Vector3.new(0, 12, 0)),
				kit.p3(to + Vector3.new(0, 12, 0)),
				q,
				14
			)
		)
		local frame = CFrame.new(at) * CFrame.Angles(0, t * 4, 0)
		for _, item in pieces do
			item.part.CFrame = frame * item.offset
			item.part.Transparency = if p > 0.05 and p < 0.95 then 0 else 1
		end
		sign(p)
	end
end

-- Corona dorada: aro con cinco picos. Devuelve las piezas y su posición relativa al centro.
function GameScenes.makeCrown(parent: Instance): { { part: Part, offset: CFrame } }
	local gold = Theme.color.taxi
	local list: { { part: Part, offset: CFrame } } = {}
	local ring = LegendaryKit.part(parent, "CrownRing", Vector3.new(1, 3.6, 3.6), gold, CFrame.new())
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Metal
	table.insert(list, { part = ring, offset = CFrame.Angles(0, 0, math.rad(90)) })
	for i = 1, 5 do
		local angle = (i - 1) / 5 * math.pi * 2
		local spike = LegendaryKit.part(parent, "CrownSpike", Vector3.new(0.7, 1.4, 0.7), gold, CFrame.new())
		spike.Material = Enum.Material.Metal
		table.insert(list, {
			part = spike,
			offset = CFrame.new(math.cos(angle) * 1.5, 1, math.sin(angle) * 1.5)
				* CFrame.Angles(0, -angle, math.rad(10)),
		})
	end
	local gem =
		LegendaryKit.part(parent, "CrownGem", Vector3.new(0.6, 0.6, 0.6), Theme.color.signal, CFrame.new())
	gem.Material = Enum.Material.Neon
	table.insert(list, { part = gem, offset = CFrame.new(1.85, 0.1, 0) })
	return list
end

-- Aura: anillos de luz que crecen alrededor de la ficha, de un color, con un cartel.
local function aura(env: Env, color: string, text: string, rings: number): Step
	local base = env.actorBase :: Vector3
	local list: { Part } = {}
	for i = 1, rings do
		local piece = LegendaryKit.part(
			env.run.props,
			"Aura",
			Vector3.new(0.4, 1, 1),
			Color3.fromHex(color),
			CFrame.new(base)
		)
		piece.Shape = Enum.PartType.Cylinder
		piece.Material = Enum.Material.Neon
		list[i] = piece
	end
	local sign = floating(env, base + Vector3.new(0, 15, 0), text, color, 0.15, 260)
	return function(p: number)
		for i, piece in ipairs(list) do
			local q = (phase(p, 0.05, 0.85) * 1.6 - (i - 1) * 0.25) % 1
			local size = 4 + q * 22
			piece.Size = Vector3.new(0.4, size, size)
			piece.CFrame = CFrame.new(base + Vector3.new(0, 0.3 + i * 0.05, 0))
				* CFrame.Angles(0, 0, math.rad(90))
			piece.Transparency = if p > 0.05 and p < 0.9 then 0.2 + 0.8 * q else 1
		end
		sign(p)
	end
end

-- Espectro: una voluta translúcida sale de la ficha del espectro y vuela al edificio que embruja (o da
-- vueltas, si sabotea); al revivir, un rayo de luz cae sobre la ficha.
local function ghost(env: Env): Step
	local base = env.actorBase :: Vector3
	local event = env.event
	local wisp = LegendaryKit.part(
		env.run.props,
		"Wisp",
		Vector3.one * 3.2,
		Color3.fromHex(STAGING.ghostColor),
		CFrame.new(base)
	)
	wisp.Shape = Enum.PartType.Ball
	wisp.Material = Enum.Material.Neon
	local haunt = event.kind == "Haunt" and type(event.index) == "number"
	local target = if haunt
		then env.handles.lotOf(event.index :: number).Position + Vector3.new(0, 10, 0)
		else base + Vector3.new(0, 10, 0)
	local text = kit.names(env, if haunt then "scene.ghost.haunt" else "scene.ghost.sabotage")
	local sign = floating(env, target + Vector3.new(0, 8, 0), text, "#6B5B95", 0.3, 260)
	return function(p: number, t: number)
		local q = LegendaryRules.ease(phase(p, 0.1, 0.6))
		local at = kit.v3(LegendaryRules.arc(kit.p3(base + Vector3.new(0, 5, 0)), kit.p3(target), q, 8))
		if not haunt then
			at += Vector3.new(math.cos(t * 5) * 5 * q, 0, math.sin(t * 5) * 5 * q)
		end
		wisp.CFrame = CFrame.new(at + Vector3.new(0, math.sin(t * 7) * 0.6, 0))
		wisp.Transparency = if p > 0.05 and p < 0.92 then 0.35 + 0.2 * math.sin(t * 9) else 1
		sign(p)
	end
end

local function resurrect(env: Env): Step
	local base = env.actorBase :: Vector3
	local cash = if type(env.event.cash) == "number" then env.event.cash else 0
	local beam =
		LegendaryKit.part(env.run.props, "Ray", Vector3.new(80, 1, 1), Theme.color.limestone, CFrame.new())
	beam.Shape = Enum.PartType.Cylinder
	beam.Material = Enum.Material.Neon
	local glow = aura(env, "#F5C518", kit.names(env, "scene.ghost.revive", { cash = cash }), 3)
	return function(p: number, t: number)
		local light = phase(p, 0, 0.3) * (1 - phase(p, 0.8, 1))
		local width = 12 * light + math.sin(t * 8) * light
		beam.Size = Vector3.new(80, math.max(0.1, width), math.max(0.1, width))
		beam.CFrame = CFrame.new(base + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90))
		beam.Transparency = 1 - 0.6 * light
		glow(p, t)
	end
end

-- Salida: los billetes saltan alrededor de la ficha con «+X».
local function passedStart(env: Env): Step
	local base = env.actorBase :: Vector3
	local amount = if type(env.event.amount) == "number" then env.event.amount else 0
	local sign = floating(
		env,
		base + Vector3.new(0, 12, 0),
		Strings.get("scene.start.bonus", { amount = amount }),
		"#5A9E5A",
		0.1,
		150
	)
	type Bill = { parts: { Part }, seed: number }
	local bills: { Bill } = {}
	for i = 1, STAGING.startBills do
		table.insert(bills, {
			parts = LegendaryKit.bill(env.run.props, "#8DB86B", "#4E7A3A", CFrame.new(base)),
			seed = (i * 0.618) % 1,
		})
	end
	return function(p: number, t: number)
		sign(p)
		local burst = phase(p, 0.1, 0.85)
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
					CFrame.new(base + Vector3.new(offset.x, offset.y + 2, offset.z))
						* CFrame.Angles(math.sin(flutter) * 0.7, flutter, 0)
				)
			end
		end
	end
end

-- Intercambio: dos maletines cruzan en arco entre las fichas de los dos jugadores.
local function trade(env: Env): Step
	local a = env.actorBase :: Vector3
	local b = env.targetBase or a
	local mid = (a + b) / 2
	local across = (b - a) * Vector3.new(1, 0, 1)
	local side = if across.Magnitude > 1e-3 then across.Unit:Cross(Vector3.yAxis) else Vector3.zAxis
	env.options.director.setSceneFocus(mid, CameraShots.duel, math.atan2(-side.X, -side.Z))
	local brown = Color3.fromHex(CardStaging.common.caseColor)
	local caseA = LegendaryKit.part(env.run.props, "CaseA", Vector3.new(4, 2.6, 1.4), brown, CFrame.new(a))
	local caseB =
		LegendaryKit.part(env.run.props, "CaseB", Vector3.new(4, 2.6, 1.4), Theme.color.navy, CFrame.new(b))
	local sign =
		floating(env, mid + Vector3.new(0, 14, 0), kit.names(env, "scene.trade.header"), "#1B3A6B", 0.1, 280)
	return function(p: number, t: number)
		sign(p)
		local q = LegendaryRules.ease(phase(p, 0.2, 0.75))
		local up = Vector3.new(0, 6, 0)
		caseA.CFrame = CFrame.new(kit.v3(LegendaryRules.arc(kit.p3(a + up), kit.p3(b + up), q, 9)))
			* CFrame.Angles(0, t * 3, 0)
		caseB.CFrame = CFrame.new(kit.v3(LegendaryRules.arc(kit.p3(b + up), kit.p3(a + up), q, 5)))
			* CFrame.Angles(0, -t * 3, 0)
		local visible = p > 0.1 and p < 0.92
		caseA.Transparency = if visible then 0 else 1
		caseB.Transparency = if visible then 0 else 1
	end
end

-- Propiedades de una zona en la ciudad.
local function zoneSlots(handles: any, zoneId: any): { CityLayout.Slot }
	local list: { CityLayout.Slot } = {}
	if type(zoneId) ~= "string" then
		return list
	end
	for _, slot in CityLayout.routeFor(handles.sizeId) do
		if slot.kind == "Property" and slot.zoneId == zoneId then
			table.insert(list, slot)
		end
	end
	return list
end

-- Zona Caliente: la cámara se acerca a la zona nueva, desde su calle, y en cada propiedad sube una columna de
-- calor naranja, suave; a mitad de escena la ciudad se pinta con la zona nueva. Desde arriba, con toda la
-- ciudad, los edificios tapaban la zona.
local function hotZone(env: Env): Step
	local columns: { { part: Part, at: Vector3, delay: number } } = {}
	local slots = zoneSlots(env.handles, env.event.to)
	for order, slot in slots do
		local at = env.handles.lotOf(slot.index).Position
		local piece = LegendaryKit.part(
			env.run.props,
			"Heat",
			Vector3.new(1, 10, 10),
			Color3.fromHex(STAGING.heatColor),
			CFrame.new(at)
		)
		piece.Shape = Enum.PartType.Cylinder
		piece.Material = Enum.Material.Neon
		table.insert(columns, { part = piece, at = at, delay = (order - 1) * 0.06 })
	end
	local zoneName = if type(env.event.to) == "string" then Strings.zone(env.event.to).name else ""
	-- Centro de la zona y hacia dónde mira desde su calle (el solar del medio).
	local center = Vector3.zero
	for _, column in columns do
		center += column.at
	end
	center = if #columns > 0 then center / #columns else Vector3.zero
	if #slots > 0 then
		local middle = env.handles.lotOf(slots[math.ceil(#slots / 2)].index)
		local look = middle.LookVector
		env.options.director.setSceneFocus(center, CameraShots.hotZone, math.atan2(-look.X, -look.Z))
	else
		LegendaryKit.wide(env.options.director, env.handles.sizeId, math.pi * 0.25)
	end
	local sign = floating(
		env,
		center + Vector3.new(0, 40, 0),
		Strings.get("scene.hotZone.header", { zone = zoneName }),
		"#E07A3C",
		0.3,
		320
	)
	local swap = reconcileAt(env, 0.45)
	return function(p: number, t: number)
		swap(p)
		sign(p)
		for _, column in columns do
			local q = phase(p, 0.2 + column.delay, 0.55 + column.delay) * (1 - phase(p, 0.85, 1))
			local height = STAGING.heatHeight * q
			column.part.Size =
				Vector3.new(math.max(0.1, height), 9 + math.sin(t * 6) * 0.6, 9 + math.sin(t * 6) * 0.6)
			column.part.CFrame = CFrame.new(column.at + Vector3.new(0, height / 2, 0))
				* CFrame.Angles(0, 0, math.rad(90))
			column.part.Transparency = if q > 0 then STAGING.heatTransparency else 1
		end
	end
end

-- Última Ronda: el cielo se oscurece, la cámara abre a la ciudad y un cartel gigante lo avisa.
local function finalRounds(env: Env): (Step, () -> ())
	LegendaryKit.wide(env.options.director, env.handles.sizeId, math.pi * 0.75)
	local sky = LegendaryKit.sky(1.2, "#3A2A40", 900, "#2A2030")
	local points = LegendaryKit.routePoints(env.handles.sizeId)
	local center = LegendaryRules.center(points)
	local sign = floating(
		env,
		Vector3.new(center.x, 45, center.z),
		Strings.get("scene.finalRounds.header"),
		"#C4382B",
		0.15,
		380
	)
	return function(p: number)
		sky.set(phase(p, 0, 0.4))
		sign(p)
	end, function()
		-- El aviso se queda en el ambiente: se mantiene el cielo oscuro hasta el final de la escena, y luego vuelve.
		sky.restore()
	end
end

-- Inicio de la partida (RoundStarted de la ronda 1): la cámara gira sobre la ciudad entera con su nombre de
-- barrios. Las rondas siguientes solo enseñan su número.
local function roundStarted(env: Env): Step
	local round = if type(env.event.round) == "number" then env.event.round else 1
	local points = LegendaryKit.routePoints(env.handles.sizeId)
	local center = LegendaryRules.center(points)
	local text = if round == 1
		then Strings.get("scene.round.first")
		else Strings.get("scene.round.next", { round = round })
	local sign = floating(env, Vector3.new(center.x, 40, center.z), text, "#1B3A6B", 0.1, 300)
	local first = round == 1
	return function(p: number)
		if first then
			LegendaryKit.wide(env.options.director, env.handles.sizeId, math.pi * (0.25 + p * 0.5), p == 0)
		end
		sign(p)
	end
end

-- Podio: tres escalones en la plaza con una copia de la ficha de cada uno de los tres primeros encima. Con
-- un único superviviente solo sube él. La pantalla final (clasificación, premios y revancha) va después.
local function podium(env: Env): Step
	-- Arriba quien ganó (con un único superviviente, solo él); después el resto por la clasificación.
	local order: { string } = {}
	local winnerId = env.event.winnerId
	if type(winnerId) == "string" then
		table.insert(order, winnerId)
	end
	if type(env.event.ranking) == "table" then
		for _, id in env.event.ranking do
			if type(id) == "string" and id ~= winnerId then
				table.insert(order, id)
			end
		end
	end
	local points = LegendaryKit.routePoints(env.handles.sizeId)
	local center = LegendaryRules.center(points)
	local origin = Vector3.new(center.x, 0, center.z)
	env.options.director.setSceneFocus(origin + Vector3.new(0, 6, 0), CameraShots.podium, math.pi)
	local heights = STAGING.podiumHeights
	local spots = { 0, -1, 1 }
	type Step3 = {
		block: Part,
		copy: Model?,
		at: Vector3,
		height: number,
		delay: number,
		label: (p: number) -> (),
	}
	local steps: { Step3 } = {}
	for place = 1, math.min(3, #order) do
		local id = order[place]
		local height = heights[place]
		local at = origin + Vector3.new(spots[place] * STAGING.podiumGap, 0, 0)
		local color = if type(id) == "string" then opts(env).colorOf(id) else Theme.color.steel
		local block = LegendaryKit.part(
			env.run.props,
			"Podium",
			Vector3.new(STAGING.podiumGap - 1, 0.1, 9),
			color,
			CFrame.new(at)
		)
		local copy: Model? = nil
		local token = if type(id) == "string" then env.options.token(id) else nil
		if token ~= nil then
			local ok, result = pcall(function()
				return token:Clone()
			end)
			local cloned: Model? = if ok then result else nil
			if cloned ~= nil then
				for _, piece in cloned:GetDescendants() do
					if piece:IsA("BasePart") then
						piece.Anchored = true
					elseif piece:IsA("Script") or piece:IsA("LocalScript") then
						piece:Destroy()
					end
				end
				cloned.Parent = env.run.props
				copy = cloned
			end
		end
		local label = floating(
			env,
			at + Vector3.new(0, height + 12, 0),
			tostring(place),
			"#F5C518",
			0.4 + place * 0.08,
			70
		)
		table.insert(
			steps,
			{ block = block, copy = copy, at = at, height = height, delay = (3 - place) * 0.1, label = label }
		)
	end
	local winnerName = if #order > 0 then env.options.nameOf(order[1]) else ""
	local sign = floating(
		env,
		origin + Vector3.new(0, 30, 0),
		Strings.get("scene.podium.winner", { name = winnerName }),
		"#F5C518",
		0.6,
		320
	)
	return function(p: number)
		for _, s in steps do
			local q = LegendaryRules.ease(phase(p, 0.05 + s.delay, 0.4 + s.delay))
			local h = math.max(0.1, s.height * q)
			s.block.Size = Vector3.new(STAGING.podiumGap - 1, h, 9)
			s.block.CFrame = CFrame.new(s.at + Vector3.new(0, h / 2, 0))
			s.label(p)
			if s.copy ~= nil then
				local drop = phase(p, 0.4 + s.delay, 0.6 + s.delay)
				local y = h + 3 + (1 - drop) * 20
				s.copy:PivotTo(CFrame.new(s.at + Vector3.new(0, y, 0)) * CFrame.Angles(0, math.pi, 0))
			end
		end
		sign(p)
	end
end

-- Tribunal: un mazo de juez golpea junto al acusado y cae el veredicto. Con Soborno, el cartel dice que se
-- libra.
local function tribunal(env: Env): Step
	local base = env.actorBase :: Vector3
	local event = env.event
	local key = if event.cancelled == true
		then "scene.tribunal.bribed"
		elseif event.verdict == "Fine" then "scene.tribunal.fine"
		elseif event.verdict == "PayToPlayer" then "scene.tribunal.pay"
		else "scene.tribunal.skip"
	local head = kit.header(env, base, kit.names(env, "scene.tribunal.header"), "#1B3A6B")
	local verdict = floating(
		env,
		base + Vector3.new(0, 10, 0),
		kit.names(env, key, { fine = Economy.tribunal.fine, pay = Economy.tribunal.payToPlayer }),
		if event.cancelled == true then "#5A9E5A" else "#C4382B",
		0.5,
		280
	)
	local forward = kit.forwardOf(env.actorToken)
	local side = forward:Cross(Vector3.yAxis)
	local wood = Color3.fromHex(STAGING.gavelWood)
	local hammer =
		LegendaryKit.part(env.run.props, "JudgeGavel", Vector3.new(5, 2.4, 2.4), wood, CFrame.new())
	hammer.Shape = Enum.PartType.Cylinder
	local shaft = LegendaryKit.part(env.run.props, "JudgeShaft", Vector3.new(0.7, 6, 0.7), wood, CFrame.new())
	local pivot = base + side * 7 + Vector3.new(0, 8, 0)
	return function(p: number)
		head(p)
		verdict(p)
		local strike = math.sin(phase(p, 0.25, 0.5) * math.pi) * 1.3
		local frame = CFrame.lookAt(pivot, pivot + forward)
			* CFrame.Angles(0, 0, strike)
			* CFrame.new(-3.5, 0, 0)
		shaft.CFrame = frame * CFrame.Angles(0, 0, math.rad(90))
		hammer.CFrame = frame * CFrame.new(-3, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
		local visible = p > 0.1 and p < 0.92
		hammer.Transparency = if visible then 0 else 1
		shaft.Transparency = if visible then 0 else 1
	end
end

-- Pacto vencido: la cuerda dorada entre los dos socios se afloja y se desvanece, sin traición.
local function pactEnded(env: Env): Step
	local a = env.actorBase :: Vector3
	local b = env.targetBase or a
	local mid = (a + b) / 2
	local rope = CardStaging.backstab
	local segments: { Part } = {}
	for i = 1, STAGING.pactSegments do
		segments[i] = LegendaryKit.part(
			env.run.props,
			"Rope",
			Vector3.new(rope.ropeThickness, rope.ropeThickness, 1),
			Color3.fromHex(rope.ropeColor),
			CFrame.new()
		)
	end
	local sign =
		floating(env, mid + Vector3.new(0, 14, 0), kit.names(env, "scene.pact.ended"), "#A8AEB4", 0.2, 260)
	local from = a + Vector3.new(0, rope.ropeHeight, 0)
	local to = b + Vector3.new(0, rope.ropeHeight, 0)
	return function(p: number)
		sign(p)
		-- La cuerda se afloja (más comba) y sus tramos se apagan desde el centro.
		local loose = phase(p, 0.2, 0.8)
		local sag = rope.sagStuds * (1 + loose * 1.5)
		for i, piece in segments do
			local t0, t1 = (i - 1) / #segments, i / #segments
			local p0 = kit.v3(CardSceneRules.rope(kit.p3(from), kit.p3(to), t0, sag))
			local p1 = kit.v3(CardSceneRules.rope(kit.p3(from), kit.p3(to), t1, sag))
			local length = (p1 - p0).Magnitude
			piece.Size = Vector3.new(rope.ropeThickness, rope.ropeThickness, math.max(0.05, length))
			if length > 1e-3 then
				piece.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
			end
			local fromCenter = math.abs((i - 0.5) / #segments - 0.5) * 2
			piece.Transparency = if p < 0.05 then 1 else math.clamp((loose - fromCenter * 0.6) * 1.6, 0, 1)
		end
	end
end

-- Perk elegido: una medalla dorada sube girando sobre la ficha con el nombre del perk.
local function perk(env: Env): Step
	local base = env.actorBase :: Vector3
	local def = if type(env.event.perkId) == "string" then Perks.byId[env.event.perkId] else nil
	local name = if def ~= nil then def.name else ""
	local medal =
		LegendaryKit.part(env.run.props, "Medal", Vector3.new(0.5, 4, 4), Theme.color.taxi, CFrame.new())
	medal.Shape = Enum.PartType.Cylinder
	medal.Material = Enum.Material.Metal
	local core = LegendaryKit.part(
		env.run.props,
		"MedalCore",
		Vector3.new(0.6, 2.4, 2.4),
		Theme.color.navy,
		CFrame.new()
	)
	core.Shape = Enum.PartType.Cylinder
	local sign = floating(
		env,
		base + Vector3.new(0, 15, 0),
		kit.names(env, "scene.perk.header", { perk = name }),
		"#F5C518",
		0.35,
		280
	)
	return function(p: number, t: number)
		sign(p)
		local rise = LegendaryRules.ease(phase(p, 0.05, 0.4))
		local at = base + Vector3.new(0, 4 + rise * 6, 0)
		local frame = CFrame.new(at)
			* CFrame.Angles(0, t * 3 + (1 - rise) * 8, 0)
			* CFrame.Angles(0, math.rad(90), 0)
		medal.CFrame = frame
		core.CFrame = frame
		local visible = p > 0.05 and p < 0.92
		medal.Transparency = if visible then 0 else 1
		core.Transparency = if visible then 0 else 1
	end
end

-- Descarte: con la mano llena, la carta sale volando de la ficha dando vueltas y cae a una papelera.
local function discard(env: Env): Step
	local base = env.actorBase :: Vector3
	local forward = kit.forwardOf(env.actorToken)
	local side = forward:Cross(Vector3.yAxis)
	local binAt = base + side * 8 + forward * 3
	local bin = LegendaryKit.part(
		env.run.props,
		"Bin",
		Vector3.new(4, 4.5, 4),
		Theme.color.steel,
		CFrame.new(binAt + Vector3.new(0, 2.25, 0))
	)
	local card = LegendaryKit.part(
		env.run.props,
		"Discard",
		Vector3.new(2.4, 3.4, 0.2),
		Theme.color.navy,
		CFrame.new()
	)
	local sign = floating(
		env,
		base + Vector3.new(0, 13, 0),
		kit.names(env, "scene.discard.header"),
		"#A8AEB4",
		0.1,
		260
	)
	return function(p: number, t: number)
		sign(p)
		local s = pop(phase(p, 0, 0.15)) * (1 - phase(p, 0.9, 1))
		bin.Transparency = if s > 0.01 then 0 else 1
		bin.Size = Vector3.new(4, 4.5, 4) * math.max(0.01, s)
		local q = phase(p, 0.2, 0.7)
		local at = kit.v3(
			LegendaryRules.arc(
				kit.p3(base + Vector3.new(0, 6, 0)),
				kit.p3(binAt + Vector3.new(0, 3, 0)),
				q,
				7
			)
		)
		card.CFrame = CFrame.new(at) * CFrame.Angles(q * 9, t * 6, q * 4)
		card.Transparency = if q > 0 and q < 1 then 0 else 1
	end
end

-- Cartelera: primero el panel de la pantalla gigante (`ui/Billboard`); cuando se para, el resultado pasa en
-- la ciudad. Premio: llueven billetes sobre la ficha. Multa: llega un policía con el parte. Carta: la escena
-- del robo viene después. Nada: el panel ya se burla.
local function billboard(env: Env): (Step, (() -> ())?)
	local panelShare = STAGING.billboardPanelShare
	pcall(opts(env).showBillboard, env.event, env.duration * panelShare)
	local result = env.event.result
	local sub: Step? = nil
	local cleanup: (() -> ())? = nil
	if result == "Fine" then
		local fineEnv = table.clone(env)
		fineEnv.targetId = env.actorId
		fineEnv.targetToken = env.actorToken
		fineEnv.targetBase = env.actorBase
		local built, release = CommonCards.builds.Fine.build(fineEnv)
		sub, cleanup = built, release
	elseif result == "Prize" then
		local base = env.actorBase :: Vector3
		local amount = if type(env.event.amount) == "number" then env.event.amount else 0
		local plus = floating(env, base + Vector3.new(0, 12, 0), `+{amount}`, "#5A9E5A", 0.1, 140)
		type Bill = { parts: { Part }, seed: number }
		local bills: { Bill } = {}
		for i = 1, STAGING.prizeBills do
			table.insert(bills, {
				parts = LegendaryKit.bill(env.run.props, "#8DB86B", "#4E7A3A", CFrame.new(base)),
				seed = (i * 0.618) % 1,
			})
		end
		sub = function(p: number, t: number)
			plus(p)
			for _, bill in bills do
				local q = phase(p, bill.seed * 0.4, bill.seed * 0.4 + 0.55)
				local angle = bill.seed * math.pi * 2
				local radius = 2 + bill.seed * 7
				local at = base
					+ Vector3.new(math.cos(angle) * radius, 28 * (1 - q) + 0.5, math.sin(angle) * radius)
				for _, piece in bill.parts do
					piece.Transparency = if q > 0 and q < 1 then 0 else 1
				end
				LegendaryKit.placeBill(
					bill.parts,
					CFrame.new(at) * CFrame.Angles(math.sin(t * 7 + bill.seed * 9) * 0.8, t * 2, 0)
				)
			end
		end
	end
	return function(p: number, t: number)
		local step = sub
		if step ~= nil and p >= panelShare then
			step(phase(p, panelShare, 1), t)
		end
	end,
		cleanup
end

function GameScenes.new(options: Options): GameScenes
	local runner = CommonCards.runner(options)
	local function payer(event: Types.Event): (string?, string?)
		return event.from, event.to
	end
	local function self(event: Types.Event): (string?, string?)
		return event.playerId, nil
	end
	local function crownIds(event: Types.Event): (string?, string?)
		return event.from, event.to
	end
	local function tradeIds(event: Types.Event): (string?, string?)
		return event.fromId, event.toId
	end
	local scenes: { [string]: SceneDirector.Scene } = {
		RentPaid = runner.scene("Rent", { build = rent :: any, focus = "actor", ids = payer :: any }),
		BuildingChanged = runner.scene("Build", { build = build :: any, focus = "none" }),
		PropertyMortgaged = runner.scene("Mortgage", { build = mortgage :: any, focus = "none" }),
		PropertyUnmortgaged = runner.scene("Unmortgage", { build = mortgage :: any, focus = "none" }),
		AuctionStarted = runner.scene("Auction", { build = auction :: any, focus = "none" }),
		AuctionNoSale = runner.scene("AuctionNoSale", { build = auction :: any, focus = "none" }),
		BankruptcyDeclared = runner.scene(
			"Bankruptcy",
			{ build = bankruptcy :: any, focus = "actor", ids = self :: any }
		),
		PactFormed = runner.scene(
			"Pact",
			{ build = pactFormed :: any, focus = "actor", ids = pactIds :: any }
		),
		PactBroken = runner.scene("Traitor", { build = traitor :: any, focus = "actor", ids = self :: any }),
		CrownMoved = runner.scene("Crown", { build = crown :: any, focus = "target", ids = crownIds :: any }),
		FuryFilled = runner.scene("Fury", {
			build = function(env: Env): Step
				return aura(env, "#C4382B", kit.names(env, "scene.fury.header"), 4)
			end :: any,
			focus = "actor",
			ids = self :: any,
		}),
		GhostActed = runner.scene("Ghost", { build = ghost :: any, focus = "actor", ids = self :: any }),
		GhostResurrected = runner.scene(
			"Resurrect",
			{ build = resurrect :: any, focus = "actor", ids = self :: any }
		),
		PassedStart = runner.scene(
			"Start",
			{ build = passedStart :: any, focus = "actor", ids = self :: any }
		),
		TradeCompleted = runner.scene(
			"Trade",
			{ build = trade :: any, focus = "actor", ids = tradeIds :: any }
		),
		HotZoneMoved = runner.scene("HotZone", { build = hotZone :: any, focus = "none" }),
		FinalRoundsStarted = runner.scene("FinalRounds", { build = finalRounds :: any, focus = "none" }),
		RoundStarted = runner.scene("Round", { build = roundStarted :: any, focus = "none" }),
		GameEnded = runner.scene("Podium", { build = podium :: any, focus = "none" }),
		TribunalVerdict = runner.scene(
			"Tribunal",
			{ build = tribunal :: any, focus = "actor", ids = self :: any }
		),
		PactEnded = runner.scene("PactEnded", {
			build = pactEnded :: any,
			focus = "actor",
			ids = function(event: Types.Event): (string?, string?)
				if type(event.pactId) ~= "string" then
					return nil, nil
				end
				return options.pactOf(event.pactId)
			end :: any,
		}),
		PerkDrafted = runner.scene("Perk", { build = perk :: any, focus = "actor", ids = self :: any }),
		CardDiscarded = runner.scene(
			"Discard",
			{ build = discard :: any, focus = "actor", ids = self :: any }
		),
		BillboardResult = runner.scene(
			"Billboard",
			{ build = billboard :: any, focus = "actor", ids = self :: any }
		),
	}
	return { scenes = scenes, cancelAll = runner.cancelAll }
end

return GameScenes

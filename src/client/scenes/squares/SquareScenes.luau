--!strict
-- Escenas de casillas (plan 08, Tarea 5): Duelo, Mercado Negro, Giro (robo de carta) e Impuesto. La
-- Cartelera vive en `ui/Billboard` y el Portal en `scenes/PortalJump`, que ya eran escenas propias.
--
-- Usan el esqueleto de las cartas comunes (`CommonCards.runner`): cámara a la ficha que importa, carpeta de
-- piezas que se borra al acabar y un paso por fotograma. Solo muestran: el servidor ya decidió el duelo, el
-- cobro y la carta. Una carta robada o comprada solo se nombra a su dueño, como en la vista (R-P44).
local CameraShots = require("../../../shared/config/CameraShots")
local CardStaging = require("../../../shared/config/CardStaging")
local Cards = require("../../../shared/config/Cards")
local CommonCards = require("../cards/CommonCards")
local Economy = require("../../../shared/config/Economy")
local LegendaryKit = require("../legendary/LegendaryKit")
local LegendaryRules = require("../legendary/LegendaryRules")
local SceneDirector = require("../SceneDirector")
local Strings = require("../../../shared/config/Strings")
local Theme = require("../../ui/Theme")
local Types = require("../../../shared/rules/Types")

type Env = CommonCards.Env
type Step = CommonCards.Step

local kit = CommonCards.kit
local phase, pop = kit.phase, kit.pop
local STAGING = CardStaging.squares

export type Options = CommonCards.Options & {
	-- Sigue a la ficha de un jugador: el Duelo acaba mirando al perdedor, que es quien se mueve.
	follow: (id: string) -> (),
}

export type SquareScenes = {
	scenes: { [string]: SceneDirector.Scene },
	cancelAll: () -> (),
}

local SquareScenes = {}

-- Nombre de una carta, si el evento la trae (solo la ve su dueño); si no, «?».
local function cardLabel(cardId: any): string
	local def = if type(cardId) == "string" then Cards.byId[cardId] else nil
	return if def ~= nil then def.name else "?"
end

-- Carta física: placa azul marino con borde de caliza y su nombre flotando encima.
type CardProp = { card: Part, rim: Part, label: Frame }

local function makeCard(env: Env, text: string): CardProp
	return {
		card = LegendaryKit.part(
			env.run.props,
			"Card",
			Vector3.new(3, 4.2, 0.25),
			Theme.color.navy,
			CFrame.new()
		),
		rim = LegendaryKit.part(
			env.run.props,
			"CardRim",
			Vector3.new(3.3, 4.5, 0.2),
			Theme.color.limestone,
			CFrame.new()
		),
		label = LegendaryKit.sign(env.run.props, Vector3.zero, text, 150, 46, "#1B3A6B", 0),
	}
end

local function placeCard(prop: CardProp, frame: CFrame, visible: boolean)
	prop.card.CFrame = frame
	prop.rim.CFrame = frame * CFrame.new(0, 0, 0.05)
	prop.card.Transparency = if visible then 0 else 1
	prop.rim.Transparency = if visible then 0 else 1
	LegendaryKit.moveSign(prop.label, frame.Position + Vector3.new(0, 3.6, 0))
	prop.label.Visible = visible
end

-- Duelo: los dos rivales frente a frente, un «VS» entre ellos y sus elecciones se revelan a la vez. El
-- ganador se ilumina con su premio; el perdedor se apaga. Al final la cámara pasa al perdedor.
local function duel(env: Env): Step
	local event = env.event
	local a = env.actorBase
	local b = env.targetBase
	local picks = if type(event.picks) == "table" then event.picks else {}
	local winner = if type(event.winnerId) == "string" then event.winnerId else nil
	local loser = if type(event.loserId) == "string" then event.loserId else nil
	local mid = if a ~= nil and b ~= nil then (a + b) / 2 else (a or b or Vector3.zero)
	if a ~= nil and b ~= nil then
		local across = (b - a) * Vector3.new(1, 0, 1)
		local side = if across.Magnitude > 1e-3 then across.Unit:Cross(Vector3.yAxis) else Vector3.zAxis
		env.options.director.setSceneFocus(mid, CameraShots.duel, math.atan2(-side.X, -side.Z))
	end
	local vsAt = mid + Vector3.new(0, STAGING.duelSignLift + 4, 0)
	local vs = LegendaryKit.sign(env.run.props, vsAt, Strings.get("scene.duel.vs"), 120, 70, "#C4382B", -6)
	local vsScale = Instance.new("UIScale")
	vsScale.Parent = vs
	type Side = { id: string?, base: Vector3?, plate: Frame?, scale: UIScale? }
	local sides: { Side } = {
		{ id = env.actorId, base = a },
		{ id = env.targetId, base = b },
	}
	for _, side in sides do
		if side.base ~= nil and side.id ~= nil then
			local pick = picks[side.id]
			local text = if type(pick) == "string" then Strings.duelChoice(pick) else "…"
			local plate = LegendaryKit.sign(
				env.run.props,
				side.base + Vector3.new(0, STAGING.duelSignLift, 0),
				text,
				170,
				64,
				"#1B3A6B",
				0
			)
			local scale = Instance.new("UIScale")
			scale.Scale = 0
			scale.Parent = plate
			side.plate = plate
			side.scale = scale
		end
	end
	local result = if winner ~= nil
		then Strings.get("scene.duel.prize", { amount = Economy.duel.winnerPrize })
		else Strings.get("scene.duel.tie")
	local resultAt = (if winner ~= nil and winner == env.actorId then a elseif winner ~= nil then b else mid)
		or mid
	local resultSign = LegendaryKit.sign(
		env.run.props,
		resultAt + Vector3.new(0, STAGING.duelSignLift + 6, 0),
		result,
		160,
		56,
		if winner ~= nil then "#F5C518" else "#A8AEB4",
		-4
	)
	local resultScale = Instance.new("UIScale")
	resultScale.Scale = 0
	resultScale.Parent = resultSign
	local clash = LegendaryKit.part(
		env.run.props,
		"Clash",
		Vector3.one,
		Theme.color.taxi,
		CFrame.new(mid + Vector3.new(0, 4, 0))
	)
	clash.Shape = Enum.PartType.Ball
	clash.Material = Enum.Material.Neon
	local followed = false
	return function(p: number, t: number)
		vsScale.Scale = pop(phase(p, 0, 0.15)) * (1 - phase(p, 0.3, 0.38))
		-- Las dos elecciones se revelan a la vez, como al dar la vuelta a dos cartas.
		local reveal = phase(p, 0.3, 0.42)
		local settle = phase(p, 0.5, 0.62)
		for _, side in sides do
			if side.plate ~= nil and side.scale ~= nil and side.base ~= nil then
				local won = winner ~= nil and side.id == winner
				local lost = loser ~= nil and side.id == loser
				local grow = if won then 1 + 0.25 * settle else 1
				side.scale.Scale = pop(reveal) * grow
				if settle > 0 then
					side.plate.BackgroundColor3 = if won
						then Theme.color.taxi
						elseif lost then Theme.color.steel
						else side.plate.BackgroundColor3
				end
				local droop = if lost then settle * 2.5 else 0
				local shake = if lost and settle > 0 and settle < 1 then math.sin(t * 40) * 0.4 else 0
				LegendaryKit.moveSign(
					side.plate,
					side.base + Vector3.new(shake, STAGING.duelSignLift - droop, 0)
				)
			end
		end
		local burst = phase(p, 0.42, 0.55)
		clash.Size = Vector3.one * math.max(0.05, 10 * math.sin(burst * math.pi))
		clash.Transparency = if burst > 0 and burst < 1 then 0.2 + 0.8 * burst else 1
		resultScale.Scale = pop(phase(p, 0.55, 0.7))
		-- El perdedor retrocede en la escena siguiente: la cámara ya va con él.
		if not followed and p >= STAGING.duelFollowAt then
			followed = true
			env.options.director.setSceneFocus(nil)
			if loser ~= nil then
				(env.options :: any).follow(loser)
			end
		end
	end
end

-- Mercado Negro: un baúl oscuro se abre junto a la ficha con un brillo morado y sale una carta girando.
local function market(env: Env): Step
	local base = env.actorBase :: Vector3
	local head = kit.header(env, base, kit.names(env, "scene.market.header"), "#4B2A6B")
	local forward = kit.forwardOf(env.actorToken)
	local side = forward:Cross(Vector3.yAxis)
	local at = base + side * 7 + forward * 2
	local dark = Color3.fromHex(STAGING.marketCrate)
	local crate = LegendaryKit.part(
		env.run.props,
		"Crate",
		Vector3.new(5, 3, 3.4),
		dark,
		CFrame.new(at + Vector3.new(0, 1.5, 0))
	)
	local lid = LegendaryKit.part(
		env.run.props,
		"Lid",
		Vector3.new(5.2, 0.5, 3.6),
		dark,
		CFrame.new(at + Vector3.new(0, 3.25, 0))
	)
	local glow = LegendaryKit.part(
		env.run.props,
		"Glow",
		Vector3.new(4.6, 0.3, 3),
		Color3.fromHex(STAGING.marketGlow),
		CFrame.new(at + Vector3.new(0, 3, 0))
	)
	glow.Material = Enum.Material.Neon
	local card = makeCard(env, cardLabel(env.event.cardId))
	return function(p: number, t: number)
		head(p)
		local s = pop(phase(p, 0, 0.18)) * (1 - phase(p, 0.9, 1))
		local visible = s > 0.01
		crate.Transparency = if visible then 0 else 1
		local open = LegendaryRules.ease(phase(p, 0.2, 0.35))
		lid.CFrame = CFrame.new(at + Vector3.new(0, 3.25 + open * 1.5, 0) - side * open * 4)
			* CFrame.Angles(0, 0, open * 1.2)
		lid.Transparency = if visible then 0 else 1
		glow.Transparency = if open > 0 and visible then 0.2 + 0.2 * math.sin(t * 8) else 1
		local rise = LegendaryRules.ease(phase(p, 0.35, 0.65))
		local frame = CFrame.new(at + Vector3.new(0, 3 + rise * 6, 0))
			* CFrame.Angles(0, t * 4 * (1 - rise) + rise * math.pi * 2, 0)
		placeCard(card, frame, rise > 0 and visible)
	end
end

-- Giro: una carta cae del cielo dando vueltas y se planta delante de la ficha que la roba.
local function spin(env: Env): Step
	local base = env.actorBase :: Vector3
	local head = kit.header(env, base, kit.names(env, "scene.spin.header"), "#E07A3C")
	local forward = kit.forwardOf(env.actorToken)
	local rest = base + forward * 6 + Vector3.new(0, 4, 0)
	local card = makeCard(env, cardLabel(env.event.cardId))
	return function(p: number, t: number)
		head(p)
		local fall = phase(p, 0.05, 0.5)
		local y = rest.Y + 30 * (1 - LegendaryRules.ease(fall))
		local turn = (1 - fall) * 10 + math.sin(t * 2) * 0.15
		local frame = CFrame.lookAt(Vector3.new(rest.X, y, rest.Z), Vector3.new(rest.X, y, rest.Z) - forward)
			* CFrame.Angles(0, turn, 0)
		placeCard(card, frame, fall > 0 and p < 0.92)
	end
end

-- Impuesto: un sello de goma gigante cae sobre la ficha, deja la marca roja en el suelo y salen monedas
-- hacia arriba, camino del banco.
local function tax(env: Env): Step
	local base = env.actorBase :: Vector3
	local amount = if type(env.event.amount) == "number" then env.event.amount else 0
	local head = kit.header(env, base, kit.names(env, "scene.tax.header", { amount = amount }), "#C4382B")
	local handle = LegendaryKit.part(
		env.run.props,
		"StampHandle",
		Vector3.new(2, 5, 2),
		Color3.fromHex(STAGING.stampWood),
		CFrame.new()
	)
	handle.Shape = Enum.PartType.Cylinder
	local block = LegendaryKit.part(
		env.run.props,
		"StampBlock",
		Vector3.new(9, 2, 9),
		Theme.color.asphalt,
		CFrame.new()
	)
	local ink = LegendaryKit.part(
		env.run.props,
		"StampInk",
		Vector3.new(9, 0.1, 9),
		Theme.color.signal,
		CFrame.new(base + Vector3.new(0, 0.06, 0))
	)
	ink.Transparency = 1
	type Coin = { part: Part, seed: number }
	local coins: { Coin } = {}
	for i = 1, STAGING.taxCoins do
		table.insert(coins, { part = kit.coin(env.run.props), seed = (i * 0.618) % 1 })
	end
	return function(p: number, t: number)
		head(p)
		-- Baja despacio, golpea y vuelve a subir.
		local down = phase(p, 0.1, 0.4)
		local up = phase(p, 0.55, 0.8)
		local height = 9 + 24 * (1 - down * down) + 30 * up * up
		local squash = if down >= 1 and up <= 0 then 0.85 else 1
		local at = base + Vector3.new(0, height, 0)
		block.Size = Vector3.new(9, 2 * squash, 9)
		block.CFrame = CFrame.new(at)
		handle.CFrame = CFrame.new(at + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local shown = p > 0.08 and up < 1
		block.Transparency = if shown then 0 else 1
		handle.Transparency = if shown then 0 else 1
		local mark = phase(p, 0.4, 0.45) * (1 - phase(p, 0.85, 1))
		ink.Transparency = 1 - 0.75 * mark
		local fly = phase(p, 0.45, 0.95)
		for _, item in coins do
			local angle = item.seed * math.pi * 2
			local radius = 3 + 4 * fly
			local y = 2 + fly * 26 + math.sin(fly * math.pi) * 3
			item.part.Transparency = if fly > 0 and fly < 1 then 0 else 1
			item.part.CFrame = CFrame.new(
				base + Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
			) * CFrame.Angles(0, t * 10 + item.seed * 6, 0)
		end
	end
end

-- Quiénes salen en un duelo: ganador y perdedor, o los dos que eligieron si fue empate.
local function duelIds(event: Types.Event): (string?, string?)
	if type(event.winnerId) == "string" and type(event.loserId) == "string" then
		return event.winnerId, event.loserId
	end
	local ids: { string } = {}
	if type(event.picks) == "table" then
		for id in event.picks do
			if type(id) == "string" then
				table.insert(ids, id)
			end
		end
	end
	table.sort(ids)
	return ids[1], ids[2]
end

function SquareScenes.new(options: Options): SquareScenes
	local runner = CommonCards.runner(options)
	local scenes: { [string]: SceneDirector.Scene } = {
		DuelResolved = runner.scene("Duel", { build = duel :: any, focus = "actor", ids = duelIds }),
		MarketBought = runner.scene("Market", { build = market :: any, focus = "actor" }),
		CardDrawn = runner.scene("Spin", { build = spin :: any, focus = "actor" }),
		TaxPaid = runner.scene("Tax", { build = tax :: any, focus = "actor" }),
	}
	return { scenes = scenes, cancelAll = runner.cancelAll }
end

return SquareScenes

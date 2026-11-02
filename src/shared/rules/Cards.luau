--!strict
-- Efectos de las cartas de giro. Las definiciones (nombre, rareza, objetivo) viven en
-- config/Cards; aquí solo hay comportamiento. Una carta sin efecto en esta tabla se rechaza con
-- «Carta no implementada»: cada tarea añade las suyas (comunes T2, raras T3, legendarias T4,
-- reacciones T5).

local Bankruptcy = require("./Bankruptcy")
local CardsConfig = require("../config/Cards")
local Economy = require("../config/Economy")
local Movement = require("./Movement")
local Types = require("./Types")

type GameState = Types.GameState
type Player = Types.Player
type PlayerId = Types.PlayerId
type Event = Types.Event
type Phase = Types.Phase
type ApplyResult = Types.ApplyResult

-- Argumentos de PlayCard que consumen los efectos. Los que usan zonas, propiedades o pactos los
-- validarán las cartas de las tareas 3 y 4.
export type PlayArgs = {
	targetId: PlayerId?,
	zoneId: string?,
	index: number?,
	pactId: string?,
}

type Effect = (GameState, Player, Player?, { Event }) -> ()

type EffectDef = {
	-- Fases en las que la carta tiene sentido. PlayCard solo llega desde AwaitRoll y AwaitEnd.
	phases: { Phase },
	apply: Effect,
}

local Cards = {}

-- Las cartas de tirada solo valen antes de tirar: después ya no queda tirada en este turno.
local ROLL_PHASES: { Phase } = { "AwaitRoll" }
local TURN_PHASES: { Phase } = { "AwaitRoll", "AwaitEnd" }

local function findPlayer(state: GameState, playerId: PlayerId): Player?
	for _, player in state.players do
		if player.id == playerId then
			return player
		end
	end
	return nil
end

local function playerOf(state: GameState, playerId: PlayerId): Player
	local player = findPlayer(state, playerId)
	if not player then
		error(`Cards: no existe el jugador {playerId}`, 3)
	end
	return player
end

-- pending es la tabla persistente que State.create siempre crea (R1).
local function pendingOf(state: GameState): any
	local pending = state.pending
	if not pending then
		error("Cards: el estado no tiene pending", 3)
	end
	return pending
end

local function append(events: { Event }, more: { Event })
	for _, event in more do
		table.insert(events, event)
	end
end

-- La carta ya validó que trae objetivo; un nil aquí sería un fallo de programación.
local function targetOf(target: Player?): Player
	if not target then
		error("Cards: la carta necesita un objetivo validado", 3)
	end
	return target
end

-- Motivo por el que el objetivo de una carta de jugador no vale, o nil. El objetivo nunca puede
-- ser el lanzador, un espectro, quien abandonó ni alguien fuera de la partida.
local function targetReason(
	state: GameState,
	playerId: PlayerId,
	cardId: string,
	targetId: PlayerId?
): string?
	if targetId == nil then
		return `La carta {cardId} necesita un objetivo`
	end
	if targetId == playerId then
		return "El objetivo de la carta debe ser otro jugador"
	end
	local target = findPlayer(state, targetId)
	if not target then
		return `El objetivo {targetId} no está en la partida`
	end
	if target.status ~= "Active" then
		return `El objetivo {targetId} no es un rival activo`
	end
	return nil
end

-- Dado Extra: la próxima tirada del turno usa un dado más. Engine.roll consume la marca.
local function extraDie(state: GameState, _player: Player, _target: Player?, _events: { Event })
	pendingOf(state).extraDie = true
end

-- Marcha Atrás: la tirada del turno mueve hacia atrás. Engine.roll consume la marca.
local function reverse(state: GameState, _player: Player, _target: Player?, _events: { Event })
	pendingOf(state).reverse = true
end

-- Propina Forzada: cada rival activo paga 50 al lanzador. R-P3: todo cobro pasa por
-- Bankruptcy.charge para que nadie quede con efectivo negativo; un espectro no paga.
local function forcedTip(state: GameState, player: Player, _target: Player?, events: { Event })
	for _, rival in state.players do
		if rival.id ~= player.id and rival.status == "Active" then
			append(events, Bankruptcy.charge(state, rival.id, Economy.cards.forcedTip, player.id))
		end
	end
end

-- Descuento: la próxima compra directa del lanzador cuesta la mitad. La marca se consume en
-- Engine.buy y no afecta a las subastas.
local function discount(state: GameState, player: Player, _target: Player?, _events: { Event })
	pendingOf(state).discountId = player.id
end

-- Empujón: avanza al rival sin resolver la casilla de destino (ni compra, ni renta, ni efecto).
local function shove(state: GameState, _player: Player, target: Player?, events: { Event })
	append(events, Movement.advance(state, targetOf(target).id, Economy.cards.shoveSteps))
end

-- Multa: el rival paga 100 al banco. Sin acreedor, Bankruptcy.charge no acredita a nadie.
local function fine(state: GameState, _player: Player, target: Player?, events: { Event })
	append(events, Bankruptcy.charge(state, targetOf(target).id, Economy.cards.fine))
end

-- Soborno: apunta al lanzador como protegido. La Tarea 7 consume (y borra) su entrada del mapa
-- al cancelar el castigo del Tribunal; un mapa permite varios sobornos vivos a la vez.
local function bribe(state: GameState, player: Player, _target: Player?, _events: { Event })
	local pending = pendingOf(state)
	local bribes = pending.bribes
	if not bribes then
		bribes = {}
		pending.bribes = bribes
	end
	bribes[player.id] = true
end

-- Espía: guarda una copia de la mano rival para que el servidor la entregue en privado. La mano
-- no puede viajar en CardPlayed: el evento se difunde a toda la mesa.
local function spy(state: GameState, player: Player, target: Player?, _events: { Event })
	local rival = targetOf(target)
	pendingOf(state).spy = {
		viewerId = player.id,
		targetId = rival.id,
		hand = table.clone(rival.hand),
	}
end

-- Efectos implementados por id. Añadir una carta aquí la vuelve jugable; las que falten se
-- rechazan con «Carta no implementada».
local EFFECTS: { [string]: EffectDef } = {
	ExtraDie = { phases = ROLL_PHASES, apply = extraDie },
	Reverse = { phases = ROLL_PHASES, apply = reverse },
	ForcedTip = { phases = TURN_PHASES, apply = forcedTip },
	Discount = { phases = TURN_PHASES, apply = discount },
	Shove = { phases = TURN_PHASES, apply = shove },
	Fine = { phases = TURN_PHASES, apply = fine },
	Bribe = { phases = TURN_PHASES, apply = bribe },
	Spy = { phases = TURN_PHASES, apply = spy },
}

-- Un efecto sin definición en el catálogo sería una carta que nadie puede robar: falla al cargar.
for cardId in EFFECTS do
	if not CardsConfig.byId[cardId] then
		error(`Cards: el efecto {cardId} no existe en el catálogo de cartas`, 2)
	end
end

-- Motivo por el que el jugador no puede jugar la carta, o nil. No modifica el estado. Es la
-- única regla, compartida por Cards.play y por la comprobación previa de Engine.
function Cards.reason(state: GameState, playerId: PlayerId, cardId: string, args: PlayArgs): string?
	if type(cardId) ~= "string" then
		return "PlayCard necesita el id de la carta"
	end
	local effect = EFFECTS[cardId]
	if not effect then
		return `Carta no implementada: {cardId}`
	end
	local player = findPlayer(state, playerId)
	if not player then
		return `El jugador {playerId} no está en la partida`
	end
	if player.status == "Left" then
		return "El jugador ha abandonado la partida"
	end
	if not table.find(player.hand, cardId) then
		return `No tienes la carta {cardId} en la mano`
	end
	if not table.find(effect.phases, state.phase) then
		return `No se puede jugar {cardId} en la fase {state.phase}`
	end
	local definition = CardsConfig.byId[cardId]
	if definition.target == "Player" then
		return targetReason(state, playerId, cardId, args.targetId)
	end
	return nil
end

-- Juega una carta de la mano: valida, emite CardPlayed y después los eventos del efecto.
-- Devuelve ok = false sin tocar el estado cuando la jugada no es legal.
function Cards.play(state: GameState, playerId: PlayerId, cardId: string, args: PlayArgs): ApplyResult
	local reason = Cards.reason(state, playerId, cardId, args)
	if reason then
		return { ok = false, error = reason }
	end
	local player = playerOf(state, playerId)
	local definition = CardsConfig.byId[cardId]
	local target: Player? = nil
	if definition.target == "Player" then
		target = findPlayer(state, args.targetId :: PlayerId)
	end

	local events: { Event } = { { type = "CardPlayed", playerId = playerId, cardId = cardId } }
	if target then
		events[1].targetId = target.id
	end

	-- La carta se gasta aunque su efecto cierre la partida (por ejemplo, una Multa que arruina
	-- al último rival) y cuenta para el premio de cartas jugadas.
	local handIndex = table.find(player.hand, cardId)
	if not handIndex then
		error(`Cards.play: no se encontró {cardId} en la mano de {playerId}`, 2)
	end
	table.remove(player.hand, handIndex)
	local stats = state.stats[playerId]
	stats.cardsPlayed = (stats.cardsPlayed or 0) + 1

	EFFECTS[cardId].apply(state, player, target, events)
	return { ok = true, events = events }
end

return Cards

--!strict
-- Ventanas de reacción: la interrupción de 5 s en la que un jugador al que apuntan (Escudo) o al
-- que le cobran una renta (Renta Rebotada) puede cancelar la carta o desviar la renta a un
-- tercero.
--
-- Contrato con los llamadores (Cards y Property):
--   * Reaction.open(state, trigger, then) solo abre la ventana cuando el jugador elegido está
--     Active y lleva la carta de reacción. Si la abre, deja state.phase = "Reaction" y
--     pending.reaction = { trigger, then, eligibleId, phase }; si no la abre, no toca nada. En los
--     dos casos devuelve {}.
--   * El llamador detecta la ventana con state.phase == "Reaction": si la fase no cambió, aplica
--     el efecto en el acto; si cambió, lo deja en suspenso y lo continúa la ventana.
--   * `then` es la continuación que Engine reanuda al pasar o al agotarse el tiempo. Es palabra
--     reservada de Lua, así que en el código se escribe y se lee entre corchetes: reaction["then"].
--   * Una reacción nunca abre otra ventana: la continuación se aplica con Cards.resume o
--     Property.chargeRent, que no llaman a Reaction.open.
--
-- Este módulo no require Cards ni Property (crearía un ciclo): aquí se decide y se cierra la
-- ventana; Engine reanuda la continuación porque ya require los dos.

local Types = require("./Types")

type GameState = Types.GameState
type Player = Types.Player
type PlayerId = Types.PlayerId
type Phase = Types.Phase
type Action = Types.Action
type Event = Types.Event
type ApplyResult = Types.ApplyResult

export type CardTrigger = {
	kind: "Card",
	cardId: string,
	casterId: PlayerId,
	targetId: PlayerId,
}

export type RentTrigger = {
	kind: "Rent",
	index: number,
	payerId: PlayerId,
	ownerId: PlayerId,
	amount: number,
}

export type ReactionTrigger = CardTrigger | RentTrigger

-- La continuación que la ventana dejó en suspenso. `args` es Cards.PlayArgs; se deja como any
-- para no require Cards desde aquí (ciclo).
export type CardContinuation = {
	kind: "Card",
	playerId: PlayerId,
	cardId: string,
	args: any,
}

export type RentContinuation = {
	kind: "Rent",
	index: number,
	payerId: PlayerId,
	ownerId: PlayerId,
	amount: number,
}

export type PendingAction = CardContinuation | RentContinuation

-- Forma de pending.reaction mientras dura la ventana.
export type PendingReaction = {
	trigger: ReactionTrigger,
	["then"]: PendingAction,
	eligibleId: PlayerId,
	phase: Phase,
}

local Reaction = {}

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
		error(`Reaction: no existe el jugador {playerId}`, 3)
	end
	return player
end

-- pending es la tabla persistente que State.create siempre crea (R1).
local function pendingOf(state: GameState): any
	local pending = state.pending
	if not pending then
		error("Reaction: el estado no tiene pending", 3)
	end
	return pending
end

-- Motivo por el que el tercero elegido no vale para Renta Rebotada, o nil. Nunca puede ser el
-- pagador, el dueño ni alguien que ya no siga jugando.
local function bounceReason(state: GameState, payerId: PlayerId, trigger: RentTrigger, targetId: any): string?
	if targetId == nil then
		return "Renta Rebotada necesita un objetivo"
	end
	if targetId == payerId then
		return "El objetivo de Renta Rebotada no puede ser el pagador"
	end
	if targetId == trigger.ownerId then
		return "El objetivo de Renta Rebotada no puede ser el dueño"
	end
	local target = findPlayer(state, targetId)
	if not target then
		return `El objetivo {targetId} no está en la partida`
	end
	if target.status ~= "Active" then
		return `El objetivo {targetId} no es un jugador activo`
	end
	return nil
end

-- Abre la ventana si el jugador elegido puede responder; si no, no toca el estado. Devuelve
-- siempre {}: el llamador detecta la ventana con state.phase == "Reaction" (ver cabecera).
function Reaction.open(state: GameState, trigger: ReactionTrigger, continuation: PendingAction): { Event }
	local pending = pendingOf(state)
	-- Una ventana abierta no admite otra: la partida no encadena interrupciones.
	if pending.reaction ~= nil then
		return {}
	end
	local eligibleId: PlayerId
	local reactionCardId: string
	if trigger.kind == "Card" then
		eligibleId = trigger.targetId
		reactionCardId = "Shield"
	else
		eligibleId = trigger.payerId
		reactionCardId = "BounceRent"
	end
	local eligible = findPlayer(state, eligibleId)
	if not eligible or eligible.status ~= "Active" then
		return {}
	end
	if not table.find(eligible.hand, reactionCardId) then
		return {}
	end
	pending.reaction = {
		trigger = trigger,
		["then"] = continuation,
		eligibleId = eligibleId,
		phase = state.phase,
	}
	state.phase = "Reaction"
	return {}
end

-- Cierra la ventana sin decisión del jugador (tiempo agotado o pase). Devuelve la continuación
-- para que Engine la reanude, o nil si no había ninguna abierta. No valida: es la salida de
-- emergencia del reloj y debe resolver siempre, aunque el elegido ya no pueda actuar.
function Reaction.close(state: GameState): PendingAction?
	local pending = state.pending
	if not pending then
		return nil
	end
	local reaction = pending.reaction
	if not reaction then
		return nil
	end
	pending.reaction = nil
	-- Si la partida terminó mientras la ventana estaba abierta, GameOver manda sobre la fase.
	if state.phase == "Reaction" then
		state.phase = reaction.phase
	end
	return reaction["then"]
end

-- Motivo por el que el jugador no puede contestar a la ventana, o nil. No modifica el estado y
-- es la única regla, compartida por Reaction.respond y por la comprobación previa de Engine.
function Reaction.reason(state: GameState, playerId: PlayerId, action: Action): string?
	if state.phase ~= "Reaction" then
		return `No se puede {action.type} en la fase {state.phase}`
	end
	local pending = state.pending
	local reaction = if pending then pending.reaction else nil
	if not reaction then
		return "No hay ninguna reacción pendiente"
	end
	if action.type ~= "React" and action.type ~= "PassReaction" then
		return `Acción desconocida: {action.type}`
	end
	if playerId ~= reaction.eligibleId then
		return "Solo el jugador elegido puede responder a la reacción"
	end
	local player = findPlayer(state, playerId)
	if not player then
		return `El jugador {playerId} no está en la partida`
	end
	if player.status ~= "Active" then
		return "Solo los jugadores activos pueden responder a la reacción"
	end
	if action.type == "PassReaction" then
		return nil
	end
	local trigger: ReactionTrigger = reaction.trigger
	-- La carta que responde la decide el disparo: Escudo contra una carta, Renta Rebotada contra
	-- una renta. Con otra carta no hay respuesta posible.
	local requiredCardId = if trigger.kind == "Card" then "Shield" else "BounceRent"
	if action.cardId ~= requiredCardId then
		return `La carta {action.cardId} no responde a esta reacción`
	end
	if not table.find(player.hand, action.cardId) then
		return `No tienes la carta {action.cardId} en la mano`
	end
	if trigger.kind ~= "Rent" then
		return nil
	end
	return bounceReason(state, playerId, trigger, action.targetId)
end

-- Resuelve la decisión del jugador elegido sin tocar la continuación: gasta la carta de reacción,
-- emite CardBlocked cuando toca y cierra la ventana restaurando la fase. Engine se encarga de
-- reanudar `then` (pase) o de cobrar la renta al tercero (Renta Rebotada). Devuelve ok = false
-- sin mutar cuando la respuesta no es legal.
function Reaction.respond(state: GameState, playerId: PlayerId, action: Action): ApplyResult
	local reason = Reaction.reason(state, playerId, action)
	if reason then
		return { ok = false, error = reason }
	end
	local player = playerOf(state, playerId)
	local events: { Event } = {}
	if action.type == "React" then
		local handIndex = table.find(player.hand, action.cardId)
		if not handIndex then
			error(`Reaction.respond: no se encontró {action.cardId} en la mano de {playerId}`, 2)
		end
		table.remove(player.hand, handIndex)
		local reaction = pendingOf(state).reaction
		if reaction and action.cardId == "Shield" and reaction.trigger.kind == "Card" then
			table.insert(events, {
				type = "CardBlocked",
				cardId = reaction.trigger.cardId,
				byPlayerId = playerId,
			})
		end
	end
	Reaction.close(state)
	return { ok = true, events = events }
end

return Reaction

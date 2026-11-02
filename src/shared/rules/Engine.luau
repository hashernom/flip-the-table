--!strict
-- Punto de entrada del motor: valida la acción, la aplica y devuelve los eventos.
local Auction = require("./Auction")
local Board = require("./Board")
local Building = require("./Building")
local Cards = require("./Cards")
local Economy = require("../config/Economy")
local Movement = require("./Movement")
local Pact = require("./Pact")
local Perks = require("./Perks")
local Property = require("./Property")
local Reaction = require("./Reaction")
local Rng = require("./Rng")
local Squares = require("./Squares")
local SquaresConfig = require("../config/Squares")
local Trade = require("./Trade")
local Turn = require("./Turn")
local Types = require("./Types")

type GameState = Types.GameState
type PlayerId = Types.PlayerId
type Action = Types.Action
type Event = Types.Event
type Phase = Types.Phase

type Handler = (GameState, PlayerId, Action) -> { Event }
type ApplyHandler = (GameState, PlayerId, Action) -> Types.ApplyResult

-- Una acción y su contrato: fases válidas, quién puede usarla y qué la ejecuta. `handler` aplica
-- y devuelve eventos; `apply` devuelve el ApplyResult tal cual y lo usa Squares para poder
-- rechazar sin levantar un error. Cada regla declara una de las dos formas.
type ActionRule = {
	phases: { Phase },
	turnOnly: boolean,
	-- Comprobación extra antes de mutar (efectivo, pending...). nil = sin motivo de rechazo.
	check: ((GameState, PlayerId, Action) -> string?)?,
	handler: Handler?,
	apply: ApplyHandler?,
}

local Engine = {}

local function playerOf(state: GameState, playerId: PlayerId): Types.Player?
	for _, player in state.players do
		if player.id == playerId then
			return player
		end
	end
	return nil
end

local function append(events: { Event }, more: { Event })
	for _, event in more do
		table.insert(events, event)
	end
end

-- Puja representativa de una subasta: una sola, con el incremento de Economy. Nil si el
-- jugador ya va ganando o no puede superar la puja actual.
local function representativeBid(state: GameState, playerId: PlayerId): Action?
	local pending = state.pending
	if not pending then
		return nil
	end
	local auction = pending.auction
	if not auction then
		return nil
	end
	if auction.highBidder == playerId then
		return nil
	end
	local player = playerOf(state, playerId)
	if not player or player.cash <= auction.high then
		return nil
	end
	return {
		type = "Bid",
		amount = math.min(auction.high + Economy.auctionBidStep, player.cash),
	}
end

-- Resuelve la casilla pisada. Una propiedad libre abre la compra; la ajena cobra renta; las
-- casillas de la fase 03 (Giro, Mercado Negro, Duelo, Portal, Cartelera, Tribunal e Impuesto)
-- las resuelve Squares, que puede abrir su propia fase (Market, Duel o Tribunal).
local function resolveLanding(state: GameState, playerId: PlayerId): (Phase, { Event })
	local player = playerOf(state, playerId)
	if not player then
		error(`Engine.resolveLanding: no existe el jugador {playerId}`, 2)
	end
	local square = Board.square(state, player.position)
	if square.kind ~= "Property" then
		local before = state.phase
		local events = Squares.resolve(state, playerId, square.index)
		-- Si la casilla abrió una fase o la partida terminó (una multa arruinó al último rival),
		-- manda la fase nueva; si no, el turno sigue hasta AwaitEnd.
		if state.phase ~= before then
			return state.phase, events
		end
		return "AwaitEnd", events
	end
	local property = state.properties[square.index]
	if not property or not property.ownerId then
		local pending = state.pending
		if not pending then
			error("Engine.resolveLanding: el estado no tiene pending", 2)
		end
		pending.index = square.index
		return "AwaitBuy", {}
	end
	if property.ownerId == playerId then
		return "AwaitEnd", {}
	end
	return "AwaitEnd", Property.payRent(state, playerId, square.index)
end

-- Resuelve una tirada de dos dados ya conocidos: consume las marcas del turno (Marcha Atrás y
-- Dado Extra), mueve la ficha y resuelve la casilla. `announced` indica que los dos dados ya se
-- anunciaron en un DiceRolled anterior (tirada retenida por Dedos Rápidos): entonces no se
-- repiten y el dado extra, si lo hay, se anuncia aquí.
local function moveRoll(
	state: GameState,
	playerId: PlayerId,
	a: number,
	b: number,
	announced: boolean
): { Event }
	local pending = state.pending
	if not pending then
		error("Engine.moveRoll: el estado no tiene pending", 2)
	end
	local extraDie = pending.extraDie == true
	local backwards = pending.reverse == true
	pending.extraDie = nil
	pending.reverse = nil

	local total = a + b
	-- El dado extra solo aparece en el evento cuando se usa: las tiradas antiguas no cambian.
	local dice: Event? = nil
	local rolled: { [string]: number } = { a = a, b = b }
	if extraDie then
		local c = Rng.int(state.rng, 1, 6)
		total += c
		rolled.c = c
		dice = { type = "DiceRolled", playerId = playerId, a = a, b = b, c = c }
	elseif not announced then
		dice = { type = "DiceRolled", playerId = playerId, a = a, b = b }
	end
	pending.rolled = rolled

	local events: { Event } = {}
	if dice then
		table.insert(events, dice)
	end
	append(events, Movement.advance(state, playerId, if backwards then -total else total))
	-- Anotación explícita: Luau ensancha la unión de literales al inferir la local.
	local phase: Phase, landingEvents: { Event } = resolveLanding(state, playerId)
	append(events, landingEvents)
	-- La casilla puede cerrar la partida (la renta arruina al último rival y Turn fija
	-- GameOver): la fase resuelta no sobrescribe un final ya decidido. Una ventana de reacción
	-- abierta por la renta tampoco: se queda en Reaction y, al cerrarse, vuelve a la fase de la
	-- casilla (AwaitEnd), no a AwaitRoll; si no, el jugador podría tirar dos veces.
	if state.phase == "Reaction" then
		local reaction = pending.reaction
		if reaction then
			reaction.phase = phase
		end
	elseif state.phase ~= "GameOver" then
		state.phase = phase
	end
	return events
end

-- ¿El jugador ya repitió un dado esta ronda? R-P33: la marca es por jugador (como los descuentos),
-- porque dos jugadores pueden tener Dedos Rápidos a la vez. Turn.next la limpia al empezar ronda.
local function rerollUsedThisRound(state: GameState, playerId: PlayerId): boolean
	local pending = state.pending
	local used = pending and pending.rerollUsed
	return used ~= nil and used[playerId] == state.round
end

-- Roll: dos dados (o tres con Dado Extra), movimiento de la ficha y resolución de la casilla.
-- Marcha Atrás invierte el sentido de la tirada. Las dos marcas se consumen al mover.
-- R-P29: con Dedos Rápidos y sin usar el repetidor esa ronda, la primera tirada no mueve: deja
-- los dados retenidos en pending.heldRoll y la fase sigue en AwaitRoll. RerollDie repite uno y
-- la siguiente tirada mueve con los dados retenidos.
local function roll(state: GameState, playerId: PlayerId, _action: Action): { Event }
	local pending = state.pending
	if not pending then
		error("Engine.roll: el estado no tiene pending", 2)
	end
	local player = playerOf(state, playerId)
	if not player then
		error(`Engine.roll: no existe el jugador {playerId}`, 2)
	end

	local held = pending.heldRoll
	if held then
		pending.heldRoll = nil
		return moveRoll(state, playerId, held.a, held.b, true)
	end

	local a = Rng.int(state.rng, 1, 6)
	local b = Rng.int(state.rng, 1, 6)
	if Perks.has(player, "QuickFingers") and not rerollUsedThisRound(state, playerId) then
		pending.heldRoll = { a = a, b = b }
		pending.rolled = { a = a, b = b }
		return { { type = "DiceRolled", playerId = playerId, a = a, b = b } }
	end
	return moveRoll(state, playerId, a, b, false)
end

-- Tirada del reloj (R-P34): resuelve el turno de una vez, sin retener dados. Con dados retenidos
-- mueve con ellos y los consume; sin ellos tira y mueve en el acto. Dedos Rápidos no puede dejar
-- el turno a medias cuando el jugador no actúa.
local function rollForced(state: GameState, playerId: PlayerId): { Event }
	local pending = state.pending
	if not pending then
		error("Engine.rollForced: el estado no tiene pending", 2)
	end
	local held = pending.heldRoll
	if held then
		pending.heldRoll = nil
		return moveRoll(state, playerId, held.a, held.b, true)
	end
	return moveRoll(state, playerId, Rng.int(state.rng, 1, 6), Rng.int(state.rng, 1, 6), false)
end

-- EndTurn: pasa el turno y deja al siguiente jugador listo para tirar. Turn.next puede cerrar
-- la partida (última ronda o un solo activo): entonces la fase GameOver no se sobrescribe (R13).
local function endTurn(state: GameState, _playerId: PlayerId, _action: Action): { Event }
	local events = Turn.next(state)
	local pending = state.pending
	if pending then
		-- La vista del turno siguiente no debe enseñar los dados del jugador anterior ni las
		-- cartas de tirada sin gastar: solo valen para la tirada de este turno. El Espía tampoco
		-- sobrevive: la mano robada se entrega en privado y no se queda en el estado compartido.
		pending.rolled = nil
		pending.heldRoll = nil
		pending.extraDie = nil
		pending.reverse = nil
		pending.spy = nil
	end
	-- R-P28: la ronda que empieza puede abrir el borrador de perks (Turn.next); esa fase no se
	-- pisa al cerrar el turno.
	if state.phase ~= "GameOver" and state.phase ~= "PerkDraft" then
		state.phase = "AwaitRoll"
	end
	return events
end

-- Motivo por el que Buy no puede aplicarse, o nil. Property.canBuy es la única regla.
local function buyCheck(state: GameState, playerId: PlayerId, _action: Action): string?
	local pending = state.pending
	if not pending or not pending.index then
		return "No hay ninguna propiedad a la venta"
	end
	if not Property.canBuy(state, playerId, pending.index) then
		return "No puedes comprar esta propiedad"
	end
	return nil
end

-- Buy: compra la propiedad pendiente. Property.buy aplica el Descuento del comprador y consume
-- su marca en la misma operación. Todo lo rechazable se comprueba antes de mutar.
local function buy(state: GameState, playerId: PlayerId, _action: Action): { Event }
	local pending = state.pending
	if not pending or not pending.index then
		error("Engine.buy: la fase AwaitBuy no tiene pending.index", 2)
	end
	local events = Property.buy(state, playerId, pending.index)
	pending.index = nil
	state.phase = "AwaitEnd"
	return events
end

-- DeclineBuy solo necesita que haya una casilla pendiente que subastar.
local function declineBuyCheck(state: GameState, _playerId: PlayerId, _action: Action): string?
	local pending = state.pending
	if not pending or not pending.index then
		return "No hay ninguna propiedad que subastar"
	end
	return nil
end

-- DeclineBuy: abre la subasta conservando la casilla. Auction.start fija la fase, pending y
-- emite AuctionStarted; el cierre lo decide Auction.close (la Tarea 9 lo llamará desde timeout).
local function declineBuy(state: GameState, _playerId: PlayerId, _action: Action): { Event }
	local pending = state.pending
	if not pending or not pending.index then
		error("Engine.declineBuy: la fase AwaitBuy no tiene pending.index", 2)
	end
	return Auction.start(state, pending.index)
end

-- Motivo por el que una puja no es legal, o nil. La regla vive en Auction y se comparte con
-- Auction.bid para validar siempre antes de mutar.
local function bidCheck(state: GameState, playerId: PlayerId, action: Action): string?
	return Auction.bidReason(state, playerId, action.amount)
end

-- Bid: registra la puja y deja la fase en Auction. Cualquier jugador activo puede pujar,
-- también el que no está en turno y el que rechazó la compra. Un rechazo aquí sería un fallo
-- de programación: bidCheck ya lo habría devuelto.
local function bid(state: GameState, playerId: PlayerId, action: Action): { Event }
	local result = Auction.bid(state, playerId, action.amount)
	if not result.ok then
		error(result.error, 2)
	end
	return result.events
end

-- Motivo por el que Build no puede aplicarse, o nil. Building.buildReason es la única regla.
local function buildCheck(state: GameState, playerId: PlayerId, action: Action): string?
	return Building.buildReason(state, playerId, action.index)
end

-- Build: sube un nivel de edificio sin cambiar la fase. Building.build vuelve a validar sin
-- mutar; un rechazo aquí sería un fallo de programación porque buildCheck ya lo habría dado.
local function build(state: GameState, playerId: PlayerId, action: Action): { Event }
	local result = Building.build(state, playerId, action.index)
	if not result.ok then
		error(result.error, 2)
	end
	return result.events
end

-- Argumentos de PlayCard que entiende Cards; el resto de la acción (type, cardId) no le sirve.
local function cardArgs(action: Action): Cards.PlayArgs
	return {
		targetId = action.targetId,
		zoneId = action.zoneId,
		index = action.index,
		pactId = action.pactId,
	}
end

-- Motivo por el que PlayCard no puede aplicarse, o nil. Cards.reason es la única regla de mano,
-- fase de la carta y objetivo.
local function playCardCheck(state: GameState, playerId: PlayerId, action: Action): string?
	return Cards.reason(state, playerId, action.cardId, cardArgs(action))
end

-- PlayCard: aplica el efecto de la carta sin cambiar la fase. Cards.play vuelve a validar sin
-- mutar; un rechazo aquí sería un fallo de programación porque playCardCheck ya lo habría dado.
local function playCard(state: GameState, playerId: PlayerId, action: Action): { Event }
	local result = Cards.play(state, playerId, action.cardId, cardArgs(action))
	if not result.ok then
		error(result.error, 2)
	end
	return result.events
end

-- Motivo por el que una propuesta de intercambio no es válida, o nil. Trade.proposeReason es la
-- única regla.
local function proposeTradeCheck(state: GameState, playerId: PlayerId, action: Action): string?
	return Trade.proposeReason(state, playerId, action.offer)
end

-- ProposeTrade: guarda la oferta en pending.trades sin mover dinero ni casillas. Trade.propose
-- vuelve a validar sin mutar; un rechazo aquí sería un fallo de programación porque
-- proposeTradeCheck ya lo habría dado.
local function proposeTrade(state: GameState, playerId: PlayerId, action: Action): { Event }
	local result = Trade.propose(state, playerId, action.offer)
	if not result.ok then
		error(result.error, 2)
	end
	return result.events
end

-- Motivo por el que una respuesta a un intercambio no es válida, o nil. Trade.respondReason es la
-- única regla, incluida la revalidación completa que exige aceptar.
local function respondTradeCheck(state: GameState, playerId: PlayerId, action: Action): string?
	return Trade.respondReason(state, playerId, action.tradeId, action.accept)
end

-- RespondTrade: a diferencia de las demás acciones, la usa el destinatario de la oferta y no el
-- jugador en turno (turnOnly = false).
local function respondTrade(state: GameState, playerId: PlayerId, action: Action): { Event }
	local result = Trade.respond(state, playerId, action.tradeId, action.accept)
	if not result.ok then
		error(result.error, 2)
	end
	return result.events
end

-- Motivo por el que ProposePact no puede aplicarse, o nil. Pact.proposeReason es la única regla
-- de socio, turno y duración.
local function proposePactCheck(state: GameState, playerId: PlayerId, action: Action): string?
	return Pact.proposeReason(state, playerId, action.toId, action.rounds)
end

-- ProposePact: guarda la oferta en pending.pactOffers sin mover dinero ni crear el pacto.
-- Pact.propose vuelve a validar sin mutar; un rechazo aquí sería un fallo de programación
-- porque proposePactCheck ya lo habría dado.
local function proposePact(state: GameState, playerId: PlayerId, action: Action): { Event }
	local result = Pact.propose(state, playerId, action.toId, action.rounds)
	if not result.ok then
		error(result.error, 2)
	end
	return result.events
end

-- Motivo por el que RespondPact no puede aplicarse, o nil. Pact.respondReason es la única regla,
-- incluida la revalidación de efectivo y de que el proponente siga activo.
local function respondPactCheck(state: GameState, playerId: PlayerId, action: Action): string?
	return Pact.respondReason(state, playerId, action.pactId, action.accept)
end

-- RespondPact: la usa el destinatario de la oferta, no el jugador en turno (turnOnly = false).
local function respondPact(state: GameState, playerId: PlayerId, action: Action): { Event }
	local result = Pact.respond(state, playerId, action.pactId, action.accept)
	if not result.ok then
		error(result.error, 2)
	end
	return result.events
end

-- Motivo por el que BreakPact no puede aplicarse, o nil. Pact.breakReason es la única regla:
-- solo un socio activo y solo sobre un pacto existente.
local function breakPactCheck(state: GameState, playerId: PlayerId, action: Action): string?
	return Pact.breakReason(state, playerId, action.pactId)
end

-- BreakPact: cualquier socio puede romperlo sin estar en turno, como responder un intercambio.
local function breakPact(state: GameState, playerId: PlayerId, action: Action): { Event }
	local result = Pact.breakPact(state, playerId, action.pactId)
	if not result.ok then
		error(result.error, 2)
	end
	return result.events
end

-- Ventana de reacción abierta, o nil. La abre Reaction.open desde Cards o Property.
local function pendingReaction(state: GameState): any
	local pending = state.pending
	if not pending then
		return nil
	end
	return pending.reaction
end

-- Reanuda la acción que la ventana dejó en suspenso. La forma de la continuación la decide
-- Reaction: una carta (Cards.resume, sin revalidar ni tocar la mano) o una renta
-- (Property.chargeRent, sin abrir otra ventana). Engine es quien puede require los dos módulos
-- sin cerrar un ciclo.
local function resumePending(state: GameState, continuation: Reaction.PendingAction?): { Event }
	if not continuation then
		return {}
	end
	if continuation.kind == "Card" then
		return Cards.resume(state, continuation.playerId, continuation.cardId, continuation.args)
	end
	return Property.chargeRent(
		state,
		continuation.payerId,
		continuation.ownerId,
		continuation.index,
		continuation.amount
	)
end

-- Motivo por el que React/PassReaction no puede aplicarse, o nil. Reaction.reason es la única
-- regla de la ventana: quién puede contestar, con qué carta y con qué objetivo.
local function reactCheck(state: GameState, playerId: PlayerId, action: Action): string?
	return Reaction.reason(state, playerId, action)
end

-- React/PassReaction: Reaction.respond aplica la decisión (gasta la carta, emite CardBlocked,
-- cierra la ventana y restaura la fase) y el motor reanuda la continuación. Escudo no reanuda
-- nada; Renta Rebotada la paga el tercero elegido y el pagador original no paga.
local function react(state: GameState, playerId: PlayerId, action: Action): { Event }
	local reaction = pendingReaction(state)
	if not reaction then
		error("Engine.react: la fase Reaction no tiene pending.reaction", 2)
	end
	local result = Reaction.respond(state, playerId, action)
	if not result.ok then
		error(result.error, 2)
	end
	local events: { Event } = result.events
	if action.type == "PassReaction" then
		append(events, resumePending(state, reaction["then"]))
	elseif action.cardId == "BounceRent" then
		append(
			events,
			Property.chargeRent(
				state,
				action.targetId,
				reaction.trigger.ownerId,
				reaction.trigger.index,
				reaction.trigger.amount
			)
		)
	end
	return events
end

-- Motivo por el que DraftPerk no puede aplicarse, o nil. Perks.draftReason es la única regla:
-- solo elige el jugador al que le toca y solo un perk de su oferta.
local function draftPerkCheck(state: GameState, playerId: PlayerId, action: Action): string?
	return Perks.draftReason(state, playerId, action.perkId)
end

-- DraftPerk: añade el perk elegido y pasa el turno al siguiente jugador del orden. La última
-- elección cierra el borrador (Perks.draft deja la fase en AwaitRoll).
local function draftPerk(state: GameState, playerId: PlayerId, action: Action): { Event }
	local result = Perks.draft(state, playerId, action.perkId)
	if not result.ok then
		error(result.error, 2)
	end
	return result.events
end

-- Motivo por el que RerollDie no puede aplicarse, o nil. R-P29: solo con Dedos Rápidos, con
-- dados retenidos y una vez por ronda (R-P33: la marca es de este jugador).
local function rerollDieCheck(state: GameState, playerId: PlayerId, action: Action): string?
	local pending = state.pending
	if not pending or not pending.heldRoll then
		return "No hay dados retenidos que repetir"
	end
	local player = playerOf(state, playerId)
	if not player or not Perks.has(player, "QuickFingers") then
		return "No tienes el perk Dedos Rápidos"
	end
	local die = action.die
	if die ~= "a" and die ~= "b" then
		return "RerollDie necesita el dado a o b"
	end
	if rerollUsedThisRound(state, playerId) then
		return "Ya has repetido un dado esta ronda"
	end
	return nil
end

-- RerollDie: repite un dado retenido y deja la tirada del turno y la marca al día. La marca vive
-- en pending.rerollUsed[playerId] y Turn.next la limpia al empezar la ronda siguiente.
local function rerollDie(state: GameState, playerId: PlayerId, action: Action): { Event }
	local pending = state.pending
	if not pending or not pending.heldRoll then
		error("Engine.rerollDie: la fase AwaitRoll no tiene dados retenidos", 2)
	end
	local held = pending.heldRoll
	local die: string = action.die
	held[die] = Rng.int(state.rng, 1, 6)
	local used = pending.rerollUsed
	if not used then
		used = {}
		pending.rerollUsed = used
	end
	used[playerId] = state.round
	pending.rolled = { a = held.a, b = held.b }
	return { { type = "DiceRolled", playerId = playerId, a = held.a, b = held.b } }
end

-- Motivo por el que una acción de las fases nuevas no vale, o nil. Squares.reason es la única
-- regla de MarketBuy, MarketSkip, DuelChoice y TribunalVote.
local function squaresCheck(state: GameState, playerId: PlayerId, action: Action): string?
	return Squares.reason(state, playerId, action)
end

-- Única fuente de verdad de fases y permisos: la Tarea 9 derivará legalActions de aquí.
-- Las tareas siguientes añaden sus acciones a esta misma tabla.
local rules: { [string]: ActionRule } = {
	-- El borrador de perks no exige estar en turno: elige a quien le toca en el orden del draft.
	DraftPerk = { phases = { "PerkDraft" }, turnOnly = false, check = draftPerkCheck, handler = draftPerk },
	Roll = { phases = { "AwaitRoll" }, turnOnly = true, handler = roll },
	RerollDie = { phases = { "AwaitRoll" }, turnOnly = true, check = rerollDieCheck, handler = rerollDie },
	Buy = { phases = { "AwaitBuy" }, turnOnly = true, check = buyCheck, handler = buy },
	DeclineBuy = { phases = { "AwaitBuy" }, turnOnly = true, check = declineBuyCheck, handler = declineBuy },
	Bid = { phases = { "Auction" }, turnOnly = false, check = bidCheck, handler = bid },
	Build = { phases = { "AwaitRoll", "AwaitEnd" }, turnOnly = true, check = buildCheck, handler = build },
	PlayCard = {
		phases = { "AwaitRoll", "AwaitEnd" },
		turnOnly = true,
		check = playCardCheck,
		handler = playCard,
	},
	-- La ventana la abre Reaction.open; solo el jugador elegido contesta y puede hacerlo sin
	-- estar en turno. Una reacción nunca abre otra ventana.
	React = { phases = { "Reaction" }, turnOnly = false, check = reactCheck, handler = react },
	PassReaction = {
		phases = { "Reaction" },
		turnOnly = false,
		check = reactCheck,
		handler = react,
	},
	-- Fases de las casillas nuevas (Tarea 7). Ninguna exige estar en turno: el Duelo pregunta a
	-- dos jugadores, el Tribunal a todos los activos y el Mercado solo al que cayó en él;
	-- Squares.reason decide quién puede actuar en cada una. Se aplican con `apply` porque
	-- Squares.act devuelve ApplyResult y un rechazo debe volver al llamador sin levantar un error.
	MarketBuy = { phases = { "Market" }, turnOnly = false, check = squaresCheck, apply = Squares.act },
	MarketSkip = { phases = { "Market" }, turnOnly = false, check = squaresCheck, apply = Squares.act },
	DuelChoice = { phases = { "Duel" }, turnOnly = false, check = squaresCheck, apply = Squares.act },
	TribunalVote = { phases = { "Tribunal" }, turnOnly = false, check = squaresCheck, apply = Squares.act },
	ProposeTrade = {
		phases = { "AwaitRoll", "AwaitEnd" },
		turnOnly = true,
		check = proposeTradeCheck,
		handler = proposeTrade,
	},
	-- Responder no exige estar en turno y sí estar en una fase de turno: nunca en Auction (R18).
	RespondTrade = {
		phases = { "AwaitRoll", "AwaitBuy", "AwaitEnd" },
		turnOnly = false,
		check = respondTradeCheck,
		handler = respondTrade,
	},
	-- Pactos (Tarea 8): proponer exige estar en turno; responder y romper no, pero solo en fases
	-- de turno (R18). Su espacio no es finito (socio y duración), así que no se enumeran en
	-- legalActions y se validan en apply.
	ProposePact = {
		phases = { "AwaitRoll", "AwaitEnd" },
		turnOnly = true,
		check = proposePactCheck,
		handler = proposePact,
	},
	RespondPact = {
		phases = { "AwaitRoll", "AwaitBuy", "AwaitEnd" },
		turnOnly = false,
		check = respondPactCheck,
		handler = respondPact,
	},
	BreakPact = {
		phases = { "AwaitRoll", "AwaitBuy", "AwaitEnd" },
		turnOnly = false,
		check = breakPactCheck,
		handler = breakPact,
	},
	EndTurn = { phases = { "AwaitEnd" }, turnOnly = true, handler = endTurn },
}

-- Motivo del rechazo, o nil si la acción es legal. No modifica el estado.
local function validate(state: GameState, playerId: PlayerId, action: Action): string?
	local rule = rules[action.type]
	if not rule then
		return `Acción desconocida: {action.type}`
	end
	if state.phase == "GameOver" then
		return "La partida ha terminado"
	end
	local player = playerOf(state, playerId)
	if not player then
		return `El jugador {playerId} no está en la partida`
	end
	if player.status == "Left" then
		return "El jugador ha abandonado la partida"
	end
	if not table.find(rule.phases, state.phase) then
		return `No se puede {action.type} en la fase {state.phase}`
	end
	if rule.turnOnly and playerId ~= state.players[state.turnIndex].id then
		return "No es tu turno"
	end
	if rule.check then
		local reason = rule.check(state, playerId, action)
		if reason then
			return reason
		end
	end
	return nil
end

-- Enumera el espacio finito de acciones legales de un jugador: Roll, Buy/DeclineBuy, una puja
-- representativa, Build por casilla edificable, las de las fases nuevas (Mercado, Duelo y
-- Tribunal) y EndTurn. Los intercambios no se enumeran (su espacio es infinito) y se validan en
-- apply. Los pactos tampoco: elegir socio y duración no es un espacio finito, así que
-- ProposePact/RespondPact/BreakPact se validan en apply y el bot los cableará en la Tarea 10.
-- Los candidatos pasan por validate, la única tabla de permisos: nunca se devuelve una acción
-- que apply rechazaría (R8).
function Engine.legalActions(state: GameState, playerId: PlayerId): { Action }
	local phase = state.phase
	local candidates: { Action } = {}
	if phase == "AwaitRoll" or phase == "AwaitEnd" then
		table.insert(candidates, { type = if phase == "AwaitRoll" then "Roll" else "EndTurn" })
		-- R-P29: con dados retenidos, repetir cada dado es una acción más de la fase.
		local pending = state.pending
		if phase == "AwaitRoll" and pending and pending.heldRoll then
			table.insert(candidates, { type = "RerollDie", die = "a" })
			table.insert(candidates, { type = "RerollDie", die = "b" })
		end
		for _, square in state.board.squares do
			if square.kind == "Property" then
				table.insert(candidates, { type = "Build", index = square.index })
			end
		end
	elseif phase == "AwaitBuy" then
		table.insert(candidates, { type = "Buy" })
		table.insert(candidates, { type = "DeclineBuy" })
	elseif phase == "PerkDraft" then
		-- Las ofertas del borrador en curso; validate descarta las de quien no está en turno de
		-- elegir, así que la lista coincide exactamente con lo que apply acepta.
		local draft = Perks.pendingDraft(state)
		if draft then
			for _, perkId in draft.offer do
				table.insert(candidates, { type = "DraftPerk", perkId = perkId })
			end
		end
	elseif phase == "Auction" then
		local bidAction = representativeBid(state, playerId)
		if bidAction then
			table.insert(candidates, bidAction)
		end
	elseif phase == "Reaction" then
		-- Pasar siempre es legal; las cartas de reacción solo si el jugador es el elegido y las
		-- lleva. Renta Rebotada necesita un tercero: se enumeran los rivales y Reaction.reason
		-- descarta al dueño, a los espectros y a quien se fue al validar cada candidato.
		local reaction = pendingReaction(state)
		if reaction then
			if reaction.trigger.kind == "Card" then
				table.insert(candidates, { type = "React", cardId = "Shield" })
			else
				for _, player in state.players do
					if player.id ~= reaction.eligibleId then
						table.insert(candidates, {
							type = "React",
							cardId = "BounceRent",
							targetId = player.id,
						})
					end
				end
			end
			table.insert(candidates, { type = "PassReaction" })
		end
	elseif phase == "Market" then
		-- Solo el que cayó en el Mercado compra o pasa; validate descarta además las cartas que
		-- no puede pagar o que no caben en la mano.
		local pending = state.pending
		local market = if pending then pending.market else nil
		if market and market.playerId == playerId then
			for _, card in market.cards do
				table.insert(candidates, { type = "MarketBuy", cardId = card.cardId })
			end
			table.insert(candidates, { type = "MarketSkip" })
		end
	elseif phase == "Duel" then
		-- Primero el retador elige rival; después cada participante elige una vez por ronda.
		local pending = state.pending
		local duel = if pending then pending.duel else nil
		if duel then
			if duel.rivalId == nil then
				if duel.challengerId == playerId then
					for _, player in state.players do
						if player.id ~= duel.challengerId and player.status == "Active" then
							table.insert(candidates, { type = "DuelChoice", rivalId = player.id })
						end
					end
				end
			elseif playerId == duel.challengerId or playerId == duel.rivalId then
				if duel.picks[playerId] == nil then
					for _, choice in SquaresConfig.duelChoices do
						table.insert(candidates, { type = "DuelChoice", choice = choice })
					end
				end
			end
		end
	elseif phase == "Tribunal" then
		-- Un voto por votante activo: multa, pagar a un jugador activo o perder el turno.
		local pending = state.pending
		local tribunal = if pending then pending.tribunal else nil
		local player = playerOf(state, playerId)
		if tribunal and player and player.status == "Active" and playerId ~= tribunal.accusedId then
			if tribunal.votes[playerId] == nil then
				table.insert(candidates, { type = "TribunalVote", verdict = "Fine" })
				for _, target in state.players do
					if target.status == "Active" and target.id ~= tribunal.accusedId then
						table.insert(candidates, {
							type = "TribunalVote",
							verdict = "PayToPlayer",
							targetId = target.id,
						})
					end
				end
				table.insert(candidates, { type = "TribunalVote", verdict = "SkipTurn" })
			end
		end
	end

	local actions: { Action } = {}
	for _, action in candidates do
		if not validate(state, playerId, action) then
			table.insert(actions, action)
		end
	end
	return actions
end

function Engine.apply(state: GameState, playerId: PlayerId, action: Action): Types.ApplyResult
	local reason = validate(state, playerId, action)
	if reason then
		return { ok = false, error = reason }
	end
	local rule = rules[action.type]
	if not rule then
		-- Inalcanzable tras validate; se mantiene por si las dos tablas se separan.
		return { ok = false, error = `Acción desconocida: {action.type}` }
	end
	-- Las reglas con `apply` ya devuelven ApplyResult (Squares): un rechazo surgido al aplicar se
	-- propaga tal cual, sin levantar un error y sin tocar el estado.
	local apply = rule.apply
	if apply then
		return apply(state, playerId, action)
	end
	local handler = rule.handler
	if not handler then
		-- Inalcanzable: cada regla declara handler o apply.
		return { ok = false, error = `La acción {action.type} no tiene manejador` }
	end
	return { ok = true, events = handler(state, playerId, action) }
end

-- Ejecuta una acción de tiempo agotado y devuelve solo sus eventos. En un estado válido la
-- acción siempre es legal; si no lo fuera, apply no toca nada y aquí no hay eventos.
local function perform(state: GameState, playerId: PlayerId, action: Action): { Event }
	local result = Engine.apply(state, playerId, action)
	if not result.ok then
		return {}
	end
	return result.events
end

-- Cierra el turno sin que el jugador actúe: pasa al siguiente, descarta la compra pendiente y
-- deja la fase lista para tirar. Es la salida cuando quien está en turno ya no puede actuar
-- (abandonó) o cuando el defecto de la fase no se puede aplicar. Sin ella, esos timeouts serían
-- no-ops, el resto quedaría rechazado con «No es tu turno» y la partida se congelaría.
local function abandonTurn(state: GameState): { Event }
	local pending = state.pending
	if pending then
		pending.index = nil
		pending.rolled = nil
		pending.heldRoll = nil
		pending.extraDie = nil
		pending.reverse = nil
		pending.spy = nil
	end
	local events = Turn.next(state)
	if state.phase ~= "GameOver" and state.phase ~= "PerkDraft" then
		state.phase = "AwaitRoll"
	end
	return events
end

-- Tiempo agotado: resuelve la fase en curso. Devuelve eventos, nunca un ApplyResult. En las
-- fases sin resolución automática (incluido GameOver) devuelve {} sin tocar el estado.
function Engine.timeout(state: GameState): { Event }
	local phase = state.phase
	if phase == "Auction" then
		return Auction.close(state)
	elseif phase == "Reaction" then
		-- El reloj se comporta como un pase del jugador elegido: cierra la ventana y continúa la
		-- acción que quedó en suspenso. Sin ventana abierta no hace nada.
		return resumePending(state, Reaction.close(state))
	elseif phase == "PerkDraft" then
		-- El reloj asigna el primer perk ofrecido al jugador al que le toca elegir.
		return Perks.timeout(state)
	elseif phase == "Market" then
		-- El reloj del Mercado es un pase: se cierra sin comprar.
		return Squares.marketTimeout(state)
	elseif phase == "Duel" then
		-- El reloj completa el rival y las jugadas que falten con azar y resuelve la ronda.
		return Squares.duelTimeout(state)
	elseif phase == "Tribunal" then
		-- El reloj resuelve con las papeletas que haya; sin ninguna, multa.
		return Squares.tribunalTimeout(state)
	elseif phase ~= "AwaitRoll" and phase ~= "AwaitBuy" and phase ~= "AwaitEnd" then
		return {}
	end
	local player = state.players[state.turnIndex]
	if not player then
		return {}
	end
	-- Un jugador que abandonó no puede ejecutar el defecto de la fase: se cierra su turno.
	if player.status == "Left" then
		return abandonTurn(state)
	end
	-- R-P34: en AwaitRoll el reloj resuelve el turno de una sola vez, también con Dedos Rápidos:
	-- mueve con los dados retenidos si los hay y, si no, tira y mueve sin retener. Pasar por Roll
	-- dejaría la ficha quieta un tick más.
	if phase == "AwaitRoll" then
		return rollForced(state, player.id)
	end
	local action: Action = { type = "DeclineBuy" }
	if phase == "AwaitEnd" then
		action = { type = "EndTurn" }
	end
	local events = perform(state, player.id, action)
	-- La compra siempre emite eventos; si no hay ninguno, apply rechazó el defecto (por ejemplo,
	-- AwaitBuy sin casilla pendiente) y se cierra el turno para no congelar la partida. En AwaitEnd
	-- el turno ya avanzó aunque no haya eventos que anunciar.
	if #events > 0 or phase == "AwaitEnd" then
		return events
	end
	return abandonTurn(state)
end

return Engine

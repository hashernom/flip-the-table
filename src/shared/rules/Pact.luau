--!strict
-- Pactos: un trato con duración entre dos jugadores que exime de renta a ambos. Cada parte
-- deposita una garantía que recupera al terminar; romperlo la entrega al socio y marca al
-- traidor durante Economy.pact.traitorRounds rondas (R-P1/R-P33). La carta Puñalada rompe el
-- mismo registro sin coste, así que las dos vías dejan el estado con la misma forma.
local Economy = require("../config/Economy")
local Perks = require("./Perks")
local Types = require("./Types")

type GameState = Types.GameState
type Player = Types.Player
type PlayerId = Types.PlayerId
type PactRecord = Types.Pact
type Event = Types.Event
type ApplyResult = Types.ApplyResult
type Phase = Types.Phase

-- La oferta guardada en pending.pactOffers: todavía no hay dinero retenido ni pacto formado.
type PactOffer = {
	id: string,
	fromId: PlayerId,
	toId: PlayerId,
	rounds: number,
	-- Turno en que se hizo: la oferta caduca al terminarlo (R-P44), como los intercambios (R20).
	round: number,
	turnIndex: number,
}

-- Fases en las que se puede proponer, responder y romper. Son fases de turno: nada se mueve
-- durante una subasta (R18) y con la partida terminada no se responde nada.
local PROPOSE_PHASES: { Phase } = { "AwaitRoll", "AwaitEnd" }
local RESPOND_PHASES: { Phase } = { "AwaitRoll", "AwaitBuy", "AwaitEnd" }
local BREAK_PHASES: { Phase } = { "AwaitRoll", "AwaitBuy", "AwaitEnd" }

-- Perk Negociador (R-P6): su titular deposita la garantía reducida. Se consulta el id del
-- catálogo sin require de Perks: el contrato de dependencias de Pact es Types y config/Economy.
local NEGOTIATOR_PERK = "Negotiator"

local Pact = {}

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
		error(`Pact: no existe el jugador {playerId}`, 3)
	end
	return player
end

-- pending es la tabla persistente que State.create siempre crea (R1).
local function pendingOf(state: GameState): any
	local pending = state.pending
	if not pending then
		error("Pact: el estado no tiene pending", 3)
	end
	return pending
end

local function findPactIndex(state: GameState, pactId: string): number?
	for index, pact in state.pacts do
		if pact.id == pactId then
			return index
		end
	end
	return nil
end

local function findOfferIndex(offers: { any }, offerId: string): number?
	for index, offer in offers do
		if offer.id == offerId then
			return index
		end
	end
	return nil
end

-- Garantía que deposita un jugador. El Negociador paga la reducida.
local function depositOf(player: Player): number
	if table.find(player.perks, NEGOTIATOR_PERK) ~= nil then
		return Economy.pact.negotiatorDeposit
	end
	return Economy.pact.deposit
end

-- Devuelve una garantía a un jugador activo: quien no está Active (Ghost o Left) no recibe
-- dinero, el banco se queda con él. Es la única regla de devolución de garantías, compartida por
-- los pactos y por la Puñalada (Cards, R-P42).
function Pact.creditIfActive(state: GameState, playerId: PlayerId, amount: number)
	if amount == 0 then
		return
	end
	local player = findPlayer(state, playerId)
	if player and player.status == "Active" then
		player.cash += amount
	end
end

-- Cierra el pacto en la posición `index`: cada parte recupera su propia garantía y se anota el
-- evento. Lo comparten la caducidad por rondas y la liquidación del final de la partida (R-P46).
local function closeAndRefund(state: GameState, index: number, events: { Event })
	local pact = state.pacts[index]
	table.remove(state.pacts, index)
	Pact.creditIfActive(state, pact.a, pact.depositA)
	Pact.creditIfActive(state, pact.b, pact.depositB)
	table.insert(events, { type = "PactEnded", pactId = pact.id })
end

-- Motivo por el que una propuesta no es válida, o nil. No modifica el estado. Es la única
-- regla, compartida por Pact.propose y por la comprobación previa de Engine.
function Pact.proposeReason(state: GameState, fromId: PlayerId, toId: any, rounds: any): string?
	if not table.find(PROPOSE_PHASES, state.phase) then
		return `No se puede proponer un pacto en la fase {state.phase}`
	end
	local proposer = findPlayer(state, fromId)
	if not proposer then
		return `El jugador {fromId} no está en la partida`
	end
	if proposer.status == "Left" then
		return "El jugador ha abandonado la partida"
	end
	if proposer.status ~= "Active" then
		return "Solo los jugadores activos pueden pactar"
	end
	if state.players[state.turnIndex].id ~= fromId then
		return "No es tu turno"
	end
	-- R-P41: cada oferta viaja en la vista de toda la mesa, así que su número tiene tope.
	local open = 0
	for _, offer: PactOffer in pendingOf(state).pactOffers or {} do
		if offer.fromId == fromId then
			open += 1
		end
	end
	if open >= Economy.maxOpenOffers then
		return "Tienes demasiadas ofertas abiertas"
	end
	if type(toId) ~= "string" then
		return "La oferta no es válida"
	end
	if toId == fromId then
		return "No puedes proponerte un pacto a ti mismo"
	end
	local partner = findPlayer(state, toId)
	if not partner then
		return `El jugador {toId} no está en la partida`
	end
	if partner.status == "Left" then
		return "El otro jugador ha abandonado la partida"
	end
	if partner.status ~= "Active" then
		return "Solo se puede pactar con un jugador activo"
	end
	if type(rounds) ~= "number" or rounds % 1 ~= 0 then
		return "La duración del pacto debe ser un número entero"
	end
	if rounds < Economy.pact.minRounds or rounds > Economy.pact.maxRounds then
		return `La duración del pacto debe estar entre {Economy.pact.minRounds} y {Economy.pact.maxRounds} rondas`
	end
	return nil
end

-- Registra la oferta con un id determinista (P1, P2…). Proponer no mueve dinero ni forma el
-- pacto: las garantías se retienen al aceptar.
function Pact.propose(state: GameState, fromId: PlayerId, toId: string, rounds: number): ApplyResult
	local reason = Pact.proposeReason(state, fromId, toId, rounds)
	if reason then
		return { ok = false, error = reason }
	end
	local pending = pendingOf(state)
	local offers = pending.pactOffers
	if not offers then
		offers = {}
		pending.pactOffers = offers
	end
	local seq = (pending.pactSeq or 0) + 1
	pending.pactSeq = seq
	local offer: PactOffer = {
		id = `P{seq}`,
		fromId = fromId,
		toId = toId,
		rounds = rounds,
		round = state.round,
		turnIndex = state.turnIndex,
	}
	table.insert(offers, offer)
	return { ok = true, events = {} }
end

-- R-P44: una oferta caduca con el turno en que se hizo, igual que los intercambios (R20). La
-- llama Turn.next antes de mover el turno, mientras round y turnIndex señalan al que termina.
function Pact.dropOffersOfTurn(state: GameState)
	local pending = state.pending
	local offers = pending and pending.pactOffers
	if not offers then
		return
	end
	for index = #offers, 1, -1 do
		local offer: PactOffer = offers[index]
		if offer.round == state.round and offer.turnIndex == state.turnIndex then
			table.remove(offers, index)
		end
	end
end

-- Motivo por el que una respuesta no es válida, o nil. Con accept = true revalida que el
-- proponente siga activo y que ambos tengan efectivo antes de retener nada.
function Pact.respondReason(state: GameState, playerId: PlayerId, pactId: any, accept: any): string?
	if not table.find(RESPOND_PHASES, state.phase) then
		return `No se puede responder un pacto en la fase {state.phase}`
	end
	local player = findPlayer(state, playerId)
	if not player then
		return `El jugador {playerId} no está en la partida`
	end
	if player.status == "Left" then
		return "El jugador ha abandonado la partida"
	end
	if player.status ~= "Active" then
		return "Solo los jugadores activos pueden pactar"
	end
	if type(pactId) ~= "string" then
		return "La oferta no es válida"
	end
	if type(accept) ~= "boolean" then
		return "La respuesta no es válida"
	end
	local pending = pendingOf(state)
	local offers = pending.pactOffers
	if not offers then
		return "La oferta ya no existe"
	end
	local index = findOfferIndex(offers, pactId)
	if not index then
		return "La oferta ya no existe"
	end
	local offer: PactOffer = offers[index]
	if offer.toId ~= playerId then
		return "Solo el destinatario puede responder"
	end
	if not accept then
		return nil
	end
	local proposer = findPlayer(state, offer.fromId)
	if not proposer then
		return `El jugador {offer.fromId} no está en la partida`
	end
	if proposer.status ~= "Active" then
		return "El otro jugador ya no puede pactar"
	end
	if proposer.cash < depositOf(proposer) then
		return "El otro jugador ya no tiene efectivo suficiente"
	end
	if player.cash < depositOf(player) then
		return "No tienes efectivo suficiente"
	end
	return nil
end

-- Responde a una oferta. Rechazarla solo la elimina; aceptarla retiene las dos garantías, crea
-- el pacto y emite PactFormed. Las garantías no se acreditan a nadie: quedan en depósito.
function Pact.respond(state: GameState, playerId: PlayerId, pactId: string, accept: boolean): ApplyResult
	local reason = Pact.respondReason(state, playerId, pactId, accept)
	if reason then
		return { ok = false, error = reason }
	end
	local pending = pendingOf(state)
	local offers = pending.pactOffers
	if not offers then
		error("Pact.respond: la oferta validada ya no existe", 2)
	end
	local index = findOfferIndex(offers, pactId)
	if not index then
		error(`Pact.respond: la oferta {pactId} desapareció durante la validación`, 2)
	end
	local offer: PactOffer = offers[index]
	table.remove(offers, index)
	if not accept then
		return { ok = true, events = {} }
	end
	local proposer = playerOf(state, offer.fromId)
	local partner = playerOf(state, offer.toId)
	local depositA = depositOf(proposer)
	local depositB = depositOf(partner)
	-- Negociador: la garantía reducida se aplica de verdad al formar el pacto.
	if Perks.has(proposer, NEGOTIATOR_PERK) then
		Perks.recordUse(state, proposer.id, NEGOTIATOR_PERK)
	end
	if Perks.has(partner, NEGOTIATOR_PERK) then
		Perks.recordUse(state, partner.id, NEGOTIATOR_PERK)
	end
	proposer.cash -= depositA
	partner.cash -= depositB
	local pact: PactRecord = {
		id = offer.id,
		a = proposer.id,
		b = partner.id,
		depositA = depositA,
		depositB = depositB,
		-- untilRound es la última ronda activa, como en los modificadores: un pacto de 3 rondas
		-- formado en la ronda R vive R, R+1 y R+2.
		untilRound = state.round + offer.rounds - 1,
	}
	table.insert(state.pacts, pact)
	local proposerStats = state.stats[proposer.id]
	proposerStats.pactsFormed = (proposerStats.pactsFormed or 0) + 1
	local partnerStats = state.stats[partner.id]
	partnerStats.pactsFormed = (partnerStats.pactsFormed or 0) + 1
	return { ok = true, events = { { type = "PactFormed", pactId = offer.id } } }
end

-- Motivo por el que una ruptura no es válida, o nil. Solo un socio activo puede romperlo.
function Pact.breakReason(state: GameState, playerId: PlayerId, pactId: any): string?
	if not table.find(BREAK_PHASES, state.phase) then
		return `No se puede romper un pacto en la fase {state.phase}`
	end
	local player = findPlayer(state, playerId)
	if not player then
		return `El jugador {playerId} no está en la partida`
	end
	if player.status == "Left" then
		return "El jugador ha abandonado la partida"
	end
	if player.status ~= "Active" then
		return "Solo los jugadores activos pueden romper un pacto"
	end
	if type(pactId) ~= "string" then
		return "El pacto no existe"
	end
	local index = findPactIndex(state, pactId)
	if not index then
		return "El pacto no existe"
	end
	local pact = state.pacts[index]
	if pact.a ~= playerId and pact.b ~= playerId then
		return "No participas en ese pacto"
	end
	return nil
end

-- Rompe un pacto: el traidor pierde su garantía, el socio cobra las dos y el traidor queda
-- marcado con la misma convención que los modificadores: untilRound es su última ronda activa.
function Pact.breakPact(state: GameState, playerId: PlayerId, pactId: string): ApplyResult
	local reason = Pact.breakReason(state, playerId, pactId)
	if reason then
		return { ok = false, error = reason }
	end
	local index = findPactIndex(state, pactId)
	if not index then
		error(`Pact.breakPact: el pacto {pactId} desapareció durante la validación`, 2)
	end
	local pact = state.pacts[index]
	local breaker = playerOf(state, playerId)
	local partnerId = if pact.a == playerId then pact.b else pact.a
	local breakerDeposit = if pact.a == playerId then pact.depositA else pact.depositB
	local partnerDeposit = if pact.a == playerId then pact.depositB else pact.depositA
	table.remove(state.pacts, index)
	-- El socio cobra lo suyo y lo que pierde el traidor. Si ya no está activo, el banco se queda
	-- con las dos garantías, como en cualquier cobro a un jugador fuera del circuito de dinero.
	Pact.creditIfActive(state, partnerId, partnerDeposit + breakerDeposit)
	breaker.traitorUntilRound = state.round + Economy.pact.traitorRounds - 1
	local stats = state.stats[playerId]
	stats.pactsBroken = (stats.pactsBroken or 0) + 1
	return { ok = true, events = { { type = "PactBroken", pactId = pact.id, playerId = playerId } } }
end

-- ¿Un pacto vivo exime de renta entre estos dos jugadores? Un pacto dura mientras
-- state.round <= untilRound: en la ronda untilRound+1 ya no exime.
function Pact.exemptsRent(state: GameState, payerId: PlayerId, ownerId: PlayerId): boolean
	if payerId == ownerId then
		return false
	end
	for _, pact in state.pacts do
		if pact.untilRound >= state.round then
			if (pact.a == payerId and pact.b == ownerId) or (pact.a == ownerId and pact.b == payerId) then
				return true
			end
		end
	end
	return false
end

-- Cierra los pactos cuya última ronda ya pasó: cada parte recupera su propia garantía. La llama
-- Turn.next al empezar una ronda; sin ella un pacto duraría para siempre.
function Pact.expire(state: GameState): { Event }
	local events: { Event } = {}
	for index = #state.pacts, 1, -1 do
		if state.pacts[index].untilRound < state.round then
			closeAndRefund(state, index, events)
		end
	end
	return events
end

-- R-P46: al cerrar la partida no puede quedar ninguna garantía en depósito. La llama Turn antes
-- de calcular la clasificación final, para que el patrimonio cuente el efectivo devuelto.
function Pact.settle(state: GameState): { Event }
	local events: { Event } = {}
	for index = #state.pacts, 1, -1 do
		closeAndRefund(state, index, events)
	end
	return events
end

-- R-P10: un socio que cae en bancarrota cierra sus pactos. El superviviente recupera su
-- garantía; la del arruinado se queda en el banco. La llama Bankruptcy.charge antes de comprobar
-- el final de la partida, para que la clasificación cuente el depósito devuelto.
function Pact.onBankruptcy(state: GameState, playerId: PlayerId): { Event }
	local events: { Event } = {}
	for index = #state.pacts, 1, -1 do
		local pact = state.pacts[index]
		if pact.a == playerId or pact.b == playerId then
			table.remove(state.pacts, index)
			local survivorId = if pact.a == playerId then pact.b else pact.a
			local survivorDeposit = if pact.a == playerId then pact.depositB else pact.depositA
			Pact.creditIfActive(state, survivorId, survivorDeposit)
			table.insert(events, { type = "PactEnded", pactId = pact.id })
		end
	end
	return events
end

return Pact

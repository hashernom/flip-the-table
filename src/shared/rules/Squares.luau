--!strict
-- Casillas nuevas de la fase 03: Giro, Mercado Negro, Duelo, Portal, Cartelera de la Suerte,
-- Tribunal e Impuesto. Squares.resolve aplica el efecto de la casilla y abre la fase que pida
-- decisión (Market, Duel o Tribunal); las acciones de esas fases se validan y se aplican aquí.
-- Ninguna mecánica pide apostar: el Mercado cobra un precio fijo, el Duelo no arriesga dinero y
-- la Cartelera no pregunta nada.

local Bankruptcy = require("./Bankruptcy")
local Board = require("./Board")
local CardsConfig = require("../config/Cards")
local Deck = require("./Deck")
local Movement = require("./Movement")
local Perks = require("./Perks")
local Rng = require("./Rng")
local SquaresConfig = require("../config/Squares")
local Types = require("./Types")

type GameState = Types.GameState
type Player = Types.Player
type PlayerId = Types.PlayerId
type Event = Types.Event
type Action = Types.Action
type ApplyResult = Types.ApplyResult

-- Carta a la venta en el Mercado Negro: el precio lo fija su rareza.
export type MarketCard = { cardId: string, price: number }

-- Estado de paso de las tres fases, con la forma de los contratos de la fase 03.
export type PendingMarket = { playerId: PlayerId, cards: { MarketCard } }

export type PendingDuel = {
	challengerId: PlayerId,
	rivalId: PlayerId?,
	-- Jugada secreta de cada participante en la ronda en curso.
	picks: { [PlayerId]: string },
	round: number,
}

-- Papeleta del Tribunal. `targetId` solo tiene sentido con PayToPlayer.
export type TribunalVote = { verdict: string, targetId: PlayerId? }

export type PendingTribunal = {
	accusedId: PlayerId,
	-- Papeletas por votante; el acusado nunca tiene entrada.
	votes: { [PlayerId]: TribunalVote },
	votesCount: number,
}

-- Orden fijo de desempate del Tribunal: gana el primero de la lista. Es una regla, no un valor
-- ajustable.
local VERDICT_ORDER = { "Fine", "PayToPlayer", "SkipTurn" }

local DUEL_CHOICES = SquaresConfig.duelChoices

local Squares = {}

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
		error(`Squares: no existe el jugador {playerId}`, 3)
	end
	return player
end

-- pending es la tabla persistente que State.create siempre crea (R1).
local function pendingOf(state: GameState): any
	local pending = state.pending
	if not pending then
		error("Squares: el estado no tiene pending", 3)
	end
	return pending
end

local function append(events: { Event }, more: { Event })
	for _, event in more do
		table.insert(events, event)
	end
end

local function activeRivals(state: GameState, playerId: PlayerId): { Player }
	local rivals: { Player } = {}
	for _, player in state.players do
		if player.id ~= playerId and player.status == "Active" then
			table.insert(rivals, player)
		end
	end
	return rivals
end

-- ---------------------------------------------------------------- Mercado Negro

-- Oferta visible: una carta de cada rareza configurada, elegida con Rng dentro de su montón.
local function marketOffer(state: GameState): { MarketCard }
	local cards: { MarketCard } = {}
	for _, rarity in SquaresConfig.market.rarities do
		local card = Rng.pick(state.rng, CardsConfig.byRarity[rarity])
		table.insert(cards, { cardId = card.id, price = SquaresConfig.market.prices[rarity] })
	end
	return cards
end

local function openMarket(state: GameState, playerId: PlayerId): { Event }
	pendingOf(state).market = { playerId = playerId, cards = marketOffer(state) }
	state.phase = "Market"
	return {}
end

local function offerOf(market: PendingMarket, cardId: string): MarketCard?
	for _, card in market.cards do
		if card.cardId == cardId then
			return card
		end
	end
	return nil
end

-- Motivo por el que el jugador no puede comprar esa carta, o nil. La oferta, el efectivo y el
-- sitio en la mano se comprueban antes de cobrar nada.
function Squares.marketBuyReason(state: GameState, playerId: PlayerId, cardId: any): string?
	local market: PendingMarket? = pendingOf(state).market
	if not market then
		return "El Mercado Negro no está abierto"
	end
	if market.playerId ~= playerId then
		return "El Mercado Negro no es tuyo"
	end
	if type(cardId) ~= "string" then
		return "MarketBuy necesita el id de la carta"
	end
	local player = findPlayer(state, playerId)
	if not player then
		return `El jugador {playerId} no está en la partida`
	end
	local offer = offerOf(market, cardId)
	if not offer then
		return `La carta {cardId} no está en el Mercado Negro`
	end
	if player.cash < offer.price then
		return `No tienes efectivo para comprar {cardId}`
	end
	if #player.hand >= Deck.handLimit(player) then
		return "No tienes sitio en la mano"
	end
	return nil
end

-- Motivo por el que el dueño del Mercado no puede pasar, o nil.
function Squares.marketSkipReason(state: GameState, playerId: PlayerId): string?
	local market: PendingMarket? = pendingOf(state).market
	if not market then
		return "El Mercado Negro no está abierto"
	end
	if market.playerId ~= playerId then
		return "El Mercado Negro no es tuyo"
	end
	return nil
end

-- Compra: cobra el precio al banco, entrega la carta y emite MarketBought más el robo. El
-- efectivo y el hueco ya están validados, así que el cobro no puede vender bienes ni arruinar.
local function marketBuy(state: GameState, playerId: PlayerId, cardId: string): ApplyResult
	local reason = Squares.marketBuyReason(state, playerId, cardId)
	if reason then
		return { ok = false, error = reason }
	end
	local market = pendingOf(state).market :: PendingMarket
	local offer = offerOf(market, cardId)
	if not offer then
		error("Squares.marketBuy: la oferta validada ya no existe", 2)
	end
	local player = playerOf(state, playerId)
	local events = Bankruptcy.charge(state, playerId, offer.price, nil)
	table.insert(player.hand, cardId)
	table.insert(events, 1, {
		type = "MarketBought",
		playerId = playerId,
		cardId = cardId,
		price = offer.price,
	})
	table.insert(events, { type = "CardDrawn", playerId = playerId, cardId = cardId })
	pendingOf(state).market = nil
	state.phase = "AwaitEnd"
	return { ok = true, events = events }
end

local function marketSkip(state: GameState, playerId: PlayerId): ApplyResult
	local reason = Squares.marketSkipReason(state, playerId)
	if reason then
		return { ok = false, error = reason }
	end
	pendingOf(state).market = nil
	state.phase = "AwaitEnd"
	return { ok = true, events = {} }
end

-- Tiempo agotado del Mercado: se cierra como si el jugador hubiera pasado. Cierra la fase
-- aunque falte pending.market: el reloj nunca debe dejar la partida esperando.
function Squares.marketTimeout(state: GameState): { Event }
	pendingOf(state).market = nil
	if state.phase == "Market" then
		state.phase = "AwaitEnd"
	end
	return {}
end

-- ---------------------------------------------------------------------- Duelo

-- Abre el Duelo; si no queda ningún rival activo no hay a quién retar y no se abre la fase.
local function openDuel(state: GameState, playerId: PlayerId): { Event }
	if #activeRivals(state, playerId) == 0 then
		return {}
	end
	pendingOf(state).duel = { challengerId = playerId, picks = {}, round = 1 }
	state.phase = "Duel"
	return {}
end

-- Motivo por el que una elección de Duelo no vale, o nil. El primer DuelChoice elige rival y
-- solo lo puede enviar el retador; a partir de ahí cada participante elige una vez por ronda.
function Squares.duelChoiceReason(state: GameState, playerId: PlayerId, action: Action): string?
	local duel: PendingDuel? = pendingOf(state).duel
	if not duel then
		return "El Duelo no está abierto"
	end
	local player = findPlayer(state, playerId)
	if not player then
		return `El jugador {playerId} no está en la partida`
	end
	if player.status ~= "Active" then
		return "Solo los jugadores activos juegan el Duelo"
	end
	if duel.rivalId == nil then
		if playerId ~= duel.challengerId then
			return "Solo el retador elige a su rival"
		end
		if type(action.rivalId) ~= "string" then
			return "DuelChoice necesita el rival"
		end
		local rival = findPlayer(state, action.rivalId)
		if not rival then
			return `El rival {action.rivalId} no está en la partida`
		end
		if rival.id == playerId then
			return "No puedes retarte a ti mismo"
		end
		if rival.status ~= "Active" then
			return `El rival {rival.id} no es un jugador activo`
		end
		return nil
	end
	if playerId ~= duel.challengerId and playerId ~= duel.rivalId then
		return "No participas en este Duelo"
	end
	if duel.picks[playerId] ~= nil then
		return "Ya has elegido en esta ronda"
	end
	if type(action.choice) ~= "string" or not table.find(DUEL_CHOICES, action.choice) then
		return "DuelChoice necesita Rock, Paper o Scissors"
	end
	return nil
end

-- ¿La jugada `left` gana a `right`? Piedra a tijera, tijera a papel y papel a piedra.
local function beats(left: string, right: string): boolean
	return (left == "Rock" and right == "Scissors")
		or (left == "Paper" and right == "Rock")
		or (left == "Scissors" and right == "Paper")
end

-- Cierra la ronda cuando ya hay dos jugadas. Un empate repite con jugadas nuevas hasta el tope
-- de rondas; después no gana nadie. El premio lo paga el banco y el perdedor retrocede sin que
-- se resuelva la casilla de destino: no hay apuesta ni cobro al perdedor.
local function resolveDuelRound(state: GameState): { Event }
	local duel = pendingOf(state).duel :: PendingDuel
	local rivalId = duel.rivalId
	if not rivalId then
		error("Squares: el Duelo no tiene rival al resolver la ronda", 2)
	end
	local challengerPick = duel.picks[duel.challengerId]
	local rivalPick = duel.picks[rivalId]
	if not challengerPick or not rivalPick then
		error("Squares: el Duelo no tiene las dos jugadas", 2)
	end
	local events: { Event } = {}
	if challengerPick == rivalPick then
		-- Empate: se anuncia la ronda con los dos bandos a nil. Si quedan rondas, el Duelo sigue
		-- con jugadas nuevas; si era la última, se cierra sin premio ni retroceso.
		table.insert(events, { type = "DuelResolved", round = duel.round })
		if duel.round >= SquaresConfig.duel.maxRounds then
			pendingOf(state).duel = nil
			if state.phase ~= "GameOver" then
				state.phase = "AwaitEnd"
			end
		else
			duel.round += 1
			duel.picks = {}
		end
		return events
	end

	local winnerId: PlayerId
	local loserId: PlayerId
	if beats(challengerPick, rivalPick) then
		winnerId, loserId = duel.challengerId, rivalId
	else
		winnerId, loserId = rivalId, duel.challengerId
	end
	playerOf(state, winnerId).cash += SquaresConfig.duel.winnerPrize
	table.insert(
		events,
		{ type = "DuelResolved", winnerId = winnerId, loserId = loserId, round = duel.round }
	)
	append(events, Movement.advance(state, loserId, -SquaresConfig.duel.loserStepsBack))
	pendingOf(state).duel = nil
	if state.phase ~= "GameOver" then
		state.phase = "AwaitEnd"
	end
	return events
end

local function duelChoice(state: GameState, playerId: PlayerId, action: Action): ApplyResult
	local reason = Squares.duelChoiceReason(state, playerId, action)
	if reason then
		return { ok = false, error = reason }
	end
	local duel = pendingOf(state).duel :: PendingDuel
	if duel.rivalId == nil then
		-- Primer paso: el retador elige rival. Todavía no hay jugada que guardar.
		duel.rivalId = action.rivalId
		return { ok = true, events = {} }
	end
	duel.picks[playerId] = action.choice
	local rivalId = duel.rivalId
	if not rivalId or duel.picks[duel.challengerId] == nil or duel.picks[rivalId] == nil then
		return { ok = true, events = {} }
	end
	return { ok = true, events = resolveDuelRound(state) }
end

-- Tiempo agotado del Duelo: el rival que falte y las jugadas que falten se eligen con Rng. Se
-- resuelve una ronda; si empata, la siguiente ronda espera a su propio reloj.
function Squares.duelTimeout(state: GameState): { Event }
	local duel: PendingDuel? = pendingOf(state).duel
	if not duel then
		-- Sin estado de Duelo no hay nada que resolver, pero la fase no se queda colgada.
		if state.phase == "Duel" then
			state.phase = "AwaitEnd"
		end
		return {}
	end
	if duel.rivalId == nil then
		local rivals = activeRivals(state, duel.challengerId)
		if #rivals == 0 then
			pendingOf(state).duel = nil
			if state.phase == "Duel" then
				state.phase = "AwaitEnd"
			end
			return {}
		end
		duel.rivalId = Rng.pick(state.rng, rivals).id
	end
	local rivalId = duel.rivalId
	if not rivalId then
		error("Squares.duelTimeout: el Duelo no tiene rival", 2)
	end
	local rival = findPlayer(state, rivalId)
	if not rival or rival.status ~= "Active" then
		-- El rival se fue a mitad del Duelo: se cierra sin premio.
		pendingOf(state).duel = nil
		if state.phase == "Duel" then
			state.phase = "AwaitEnd"
		end
		return { { type = "DuelResolved", round = duel.round } }
	end
	if duel.picks[duel.challengerId] == nil then
		duel.picks[duel.challengerId] = Rng.pick(state.rng, DUEL_CHOICES)
	end
	if duel.picks[rivalId] == nil then
		duel.picks[rivalId] = Rng.pick(state.rng, DUEL_CHOICES)
	end
	return resolveDuelRound(state)
end

-- -------------------------------------------------------------------- Tribunal

-- Votantes con derecho a voto: todos los activos menos el acusado.
local function tribunalVoters(state: GameState, accusedId: PlayerId): { Player }
	local voters: { Player } = {}
	for _, player in state.players do
		if player.status == "Active" and player.id ~= accusedId then
			table.insert(voters, player)
		end
	end
	return voters
end

-- ¿Ya votó todo el que puede votar? Un votante que se fue no bloquea el cierre.
local function allVoted(state: GameState, tribunal: PendingTribunal): boolean
	for _, player in state.players do
		if player.status == "Active" and player.id ~= tribunal.accusedId then
			if tribunal.votes[player.id] == nil then
				return false
			end
		end
	end
	return true
end

local function tally(tribunal: PendingTribunal): { [string]: number }
	local counts: { [string]: number } = { Fine = 0, PayToPlayer = 0, SkipTurn = 0 }
	for _, vote in tribunal.votes do
		if counts[vote.verdict] ~= nil then
			counts[vote.verdict] += 1
		end
	end
	return counts
end

-- Primera papeleta del veredicto, en orden de turno: fija el objetivo cuando varias pagan al
-- mismo jugador.
local function firstVoteFor(state: GameState, tribunal: PendingTribunal, verdict: string): TribunalVote?
	for _, player in state.players do
		local vote = tribunal.votes[player.id]
		if vote and vote.verdict == verdict then
			return vote
		end
	end
	return nil
end

-- Papeleta de un Abogado que haya votado por uno de los veredictos empatados, o nil. El perk
-- gana los empates en los que participa su propio voto (ficha: «los empates te favorecen»).
local function lawyerVoteFor(state: GameState, tribunal: PendingTribunal, tied: { string }): TribunalVote?
	for _, player in state.players do
		local vote = tribunal.votes[player.id]
		if vote and table.find(tied, vote.verdict) and Perks.has(player, "Lawyer") then
			return vote
		end
	end
	return nil
end

-- Veredicto ganador y la papeleta que lo representa. Sin votos manda la multa. En un empate
-- decide el Abogado si votó por uno de los empatados y, si no, el orden fijo.
local function chooseVerdict(state: GameState, tribunal: PendingTribunal): (string, TribunalVote?)
	local counts = tally(tribunal)
	local best = 0
	for _, verdict in VERDICT_ORDER do
		if counts[verdict] > best then
			best = counts[verdict]
		end
	end
	local tied: { string } = {}
	for _, verdict in VERDICT_ORDER do
		if counts[verdict] == best then
			table.insert(tied, verdict)
		end
	end
	if #tied > 1 then
		local lawyer = lawyerVoteFor(state, tribunal, tied)
		if lawyer then
			return lawyer.verdict, lawyer
		end
	end
	local verdict = tied[1]
	return verdict, firstVoteFor(state, tribunal, verdict)
end

-- Cierra el Tribunal y aplica el castigo. Un Soborno pendiente del acusado cancela la pena y se
-- consume en la misma operación. Los cobros pasan por Bankruptcy.charge (R-P3).
local function resolveTribunal(state: GameState): { Event }
	local tribunal: PendingTribunal? = pendingOf(state).tribunal
	if not tribunal then
		return {}
	end
	local accusedId = tribunal.accusedId
	local verdict, vote = chooseVerdict(state, tribunal)
	local targetId = if vote then vote.targetId else nil
	local events: { Event } = {}
	local bribes = pendingOf(state).bribes
	local cancelled = bribes ~= nil and bribes[accusedId] == true
	if cancelled then
		bribes[accusedId] = nil
	elseif verdict == "Fine" then
		append(events, Bankruptcy.charge(state, accusedId, SquaresConfig.tribunal.fine, nil))
	elseif verdict == "PayToPlayer" then
		append(events, Bankruptcy.charge(state, accusedId, SquaresConfig.tribunal.payToPlayer, targetId))
	else
		playerOf(state, accusedId).skipTurns += SquaresConfig.tribunal.skipTurns
	end
	pendingOf(state).tribunal = nil
	table.insert(events, 1, {
		type = "TribunalVerdict",
		playerId = accusedId,
		verdict = verdict,
		targetId = targetId,
		votes = tribunal.votes,
		cancelled = cancelled or nil,
	})
	if state.phase ~= "GameOver" then
		state.phase = "AwaitEnd"
	end
	return events
end

-- Abre el Tribunal con el arresto. Si no hay votantes (situación defensiva: la partida habría
-- terminado antes), resuelve en el acto para no dejar la fase colgada.
local function openTribunal(state: GameState, playerId: PlayerId): { Event }
	pendingOf(state).tribunal = { accusedId = playerId, votes = {}, votesCount = 0 }
	state.phase = "Tribunal"
	local events: { Event } = { { type = "PlayerArrested", playerId = playerId } }
	if #tribunalVoters(state, playerId) == 0 then
		append(events, resolveTribunal(state))
	end
	return events
end

-- Motivo por el que un voto no vale, o nil. El acusado no vota, cada votante vota una vez y
-- pagar a alguien exige un objetivo activo distinto del acusado.
function Squares.tribunalVoteReason(state: GameState, playerId: PlayerId, action: Action): string?
	local tribunal: PendingTribunal? = pendingOf(state).tribunal
	if not tribunal then
		return "El Tribunal no está abierto"
	end
	if playerId == tribunal.accusedId then
		return "El acusado no vota"
	end
	local player = findPlayer(state, playerId)
	if not player then
		return `El jugador {playerId} no está en la partida`
	end
	if player.status ~= "Active" then
		return "Solo los jugadores activos votan en el Tribunal"
	end
	if tribunal.votes[playerId] ~= nil then
		return "Ya has votado en el Tribunal"
	end
	local verdict = action.verdict
	if verdict ~= "Fine" and verdict ~= "PayToPlayer" and verdict ~= "SkipTurn" then
		return `El veredicto {verdict} no existe`
	end
	if verdict ~= "PayToPlayer" then
		return nil
	end
	if type(action.targetId) ~= "string" then
		return "Pagar a un jugador necesita un objetivo"
	end
	if action.targetId == tribunal.accusedId then
		return "El acusado no puede pagarse a sí mismo"
	end
	local target = findPlayer(state, action.targetId)
	if not target then
		return `El objetivo {action.targetId} no está en la partida`
	end
	if target.status ~= "Active" then
		return `El objetivo {action.targetId} no es un jugador activo`
	end
	return nil
end

local function tribunalVote(state: GameState, playerId: PlayerId, action: Action): ApplyResult
	local reason = Squares.tribunalVoteReason(state, playerId, action)
	if reason then
		return { ok = false, error = reason }
	end
	local tribunal = pendingOf(state).tribunal :: PendingTribunal
	local vote: TribunalVote = { verdict = action.verdict }
	if action.verdict == "PayToPlayer" then
		vote.targetId = action.targetId
	end
	tribunal.votes[playerId] = vote
	tribunal.votesCount += 1
	local events: { Event } = {}
	if allVoted(state, tribunal) then
		append(events, resolveTribunal(state))
	end
	return { ok = true, events = events }
end

-- Tiempo agotado del Tribunal: se resuelve con las papeletas que haya; sin ninguna, multa. Si
-- faltara el estado de paso, la fase se cierra igual para no bloquear el reloj.
function Squares.tribunalTimeout(state: GameState): { Event }
	local events = resolveTribunal(state)
	if #events == 0 and state.phase == "Tribunal" then
		state.phase = "AwaitEnd"
	end
	return events
end

-- ----------------------------------------------------------------------- Portal

-- Siguiente Portal en el sentido de avance, con vuelta y sin contar el actual.
local function nextPortalIndex(state: GameState, from: number): number?
	local size = #state.board.squares
	for step = 1, size - 1 do
		local index = (from - 1 + step) % size + 1
		if state.board.squares[index].kind == "Portal" then
			return index
		end
	end
	return nil
end

-- Peaje y salto. Sin un Portal al que ir o sin efectivo no se cobra nada y la ficha se queda:
-- el peaje solo se paga cuando el salto ocurre (P4: nada de deudas por un salto).
local function usePortal(state: GameState, playerId: PlayerId, index: number): { Event }
	local player = playerOf(state, playerId)
	local to = nextPortalIndex(state, index)
	local toll = SquaresConfig.portalToll
	if not to or player.cash < toll then
		return {}
	end
	local events = Bankruptcy.charge(state, playerId, toll, nil)
	player.position = to
	table.insert(events, { type = "PortalUsed", from = index, to = to, toll = toll })
	return events
end

-- --------------------------------------------------------------------- Cartelera

local function prizeAmount(player: Player, prize: SquaresConfig.BillboardPrize): number
	if Perks.has(player, "Lucky") then
		return prize.lucky
	end
	return prize.normal
end

-- Una tirada con el mismo peso para los cinco resultados. Nunca se pide decisión: el premio se
-- ingresa, la multa pasa por Bankruptcy.charge, la carta se roba y «nada» no toca el estado.
-- `amount` va con signo (la ficha enseña +200 y −100).
local function billboard(state: GameState, playerId: PlayerId): { Event }
	local player = playerOf(state, playerId)
	local results = SquaresConfig.billboard.results
	local result: SquaresConfig.BillboardResult = results[Rng.int(state.rng, 1, #results)]
	local amount = 0
	local events: { Event } = {}
	if result == "BigPrize" then
		amount = prizeAmount(player, SquaresConfig.billboard.bigPrize)
		player.cash += amount
	elseif result == "SmallPrize" then
		amount = prizeAmount(player, SquaresConfig.billboard.smallPrize)
		player.cash += amount
	elseif result == "Fine" then
		amount = -SquaresConfig.billboard.fine
		append(events, Bankruptcy.charge(state, playerId, SquaresConfig.billboard.fine, nil))
	elseif result == "Card" then
		append(events, Deck.draw(state, playerId))
	end
	table.insert(events, 1, {
		type = "BillboardResult",
		playerId = playerId,
		result = result,
		amount = amount,
	})
	return events
end

-- --------------------------------------------------------------------- Giro y Tax

local function spin(state: GameState, playerId: PlayerId): { Event }
	return Deck.draw(state, playerId)
end

local function tax(state: GameState, playerId: PlayerId): { Event }
	return Bankruptcy.charge(state, playerId, SquaresConfig.tax, nil)
end

-- ---------------------------------------------------------------------- Casillas

-- Resuelve la casilla pisada. Devuelve solo eventos: cuando abre una fase (Market, Duel o
-- Tribunal) la deja escrita en state.phase; Engine la lee antes de cerrar el turno.
function Squares.resolve(state: GameState, playerId: PlayerId, index: number): { Event }
	local square = Board.square(state, index)
	if square.kind == "Property" then
		error(`Squares.resolve: la casilla {index} es una propiedad y la resuelve Property`, 2)
	end
	if square.kind == "Spin" then
		return spin(state, playerId)
	elseif square.kind == "Market" then
		return openMarket(state, playerId)
	elseif square.kind == "Duel" then
		return openDuel(state, playerId)
	elseif square.kind == "Portal" then
		return usePortal(state, playerId, index)
	elseif square.kind == "Billboard" then
		return billboard(state, playerId)
	elseif square.kind == "Tribunal" then
		return openTribunal(state, playerId)
	elseif square.kind == "Tax" then
		return tax(state, playerId)
	end
	-- Salida: pisarla no añade nada a lo que ya pagó el movimiento.
	return {}
end

-- ------------------------------------------------------------------- Acciones

-- Motivo por el que una acción de las fases nuevas no vale, o nil. No modifica el estado y es la
-- única regla de MarketBuy, MarketSkip, DuelChoice y TribunalVote.
function Squares.reason(state: GameState, playerId: PlayerId, action: Action): string?
	if action.type == "MarketBuy" then
		return Squares.marketBuyReason(state, playerId, action.cardId)
	elseif action.type == "MarketSkip" then
		return Squares.marketSkipReason(state, playerId)
	elseif action.type == "DuelChoice" then
		return Squares.duelChoiceReason(state, playerId, action)
	elseif action.type == "TribunalVote" then
		return Squares.tribunalVoteReason(state, playerId, action)
	end
	return `Acción desconocida: {action.type}`
end

-- Aplica la acción ya validada. Un rechazo aquí sería un fallo de programación: Engine la
-- habría filtrado con Squares.reason.
function Squares.act(state: GameState, playerId: PlayerId, action: Action): ApplyResult
	local reason = Squares.reason(state, playerId, action)
	if reason then
		return { ok = false, error = reason }
	end
	if action.type == "MarketBuy" then
		return marketBuy(state, playerId, action.cardId)
	elseif action.type == "MarketSkip" then
		return marketSkip(state, playerId)
	elseif action.type == "DuelChoice" then
		return duelChoice(state, playerId, action)
	elseif action.type == "TribunalVote" then
		return tribunalVote(state, playerId, action)
	end
	error(`Squares.act: la acción {action.type} no es de casillas`, 2)
end

return Squares

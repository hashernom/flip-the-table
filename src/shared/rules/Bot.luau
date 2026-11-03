--!strict
-- Bot determinista: elige entre las acciones legales con una heurística simple. No usa azar ni
-- relojes; la simulación lo usa para jugar partidas completas sin humano. Desde la Tarea 10 usa
-- todos los sistemas: juega cualquier carta que tenga y sea legal, propone y acepta pactos cuando
-- puede cubrir la garantía, se queda con el primer perk del borrador y contesta Mercado, Duelo,
-- Tribunal, reacciones y turnos de espectro.
local Building = require("./Building")
local Economy = require("../config/Economy")
local Engine = require("./Engine")
local Types = require("./Types")

type GameState = Types.GameState
type PlayerId = Types.PlayerId
type Player = Types.Player
type Action = Types.Action

-- Forma de la oferta de pacto guardada en pending.pactOffers (Pact no la exporta).
type PactOffer = {
	id: string,
	fromId: PlayerId,
	toId: PlayerId,
	rounds: number,
}

-- Perk Negociador: el titular deposita la garantía reducida (mismo id que en el catálogo).
local NEGOTIATOR_PERK = "Negotiator"

-- Carta que rompe un pacto. El bot propone un pacto cuando la lleva en la mano: así la Puñalada
-- tiene un objetivo y la mano no se llena de cartas que nunca se pueden jugar.
local BACKSTAB_CARD = "Backstab"

local Bot = {}

local function findPlayer(state: GameState, playerId: PlayerId): Player?
	for _, player in state.players do
		if player.id == playerId then
			return player
		end
	end
	return nil
end

-- Posición del jugador en el orden de turno, para decisiones deterministas que varían por asiento.
local function playerIndex(state: GameState, playerId: PlayerId): number
	for index, player in state.players do
		if player.id == playerId then
			return index
		end
	end
	return 1
end

-- Primera acción del tipo pedido dentro de la lista legal; nil si no hay ninguna.
local function firstOf(actions: { Action }, actionType: string): Action?
	for _, action in actions do
		if action.type == actionType then
			return action
		end
	end
	return nil
end

-- Primera PlayCard cuyo id esté en la lista. En AwaitRoll solo se juegan las cartas que modifican
-- la tirada: el resto espera a AwaitEnd, donde el bot juega toda la mano legal de una vez.
local function firstCardOf(actions: { Action }, cardIds: { string }): Action?
	for _, action in actions do
		if action.type == "PlayCard" and table.find(cardIds, action.cardId) then
			return action
		end
	end
	return nil
end

local function pendingIndexOf(state: GameState): number?
	local pending = state.pending
	if not pending then
		return nil
	end
	return pending.index
end

-- Mercado Negro en curso, o nil.
local function pendingMarket(state: GameState): any
	local pending = state.pending
	if not pending then
		return nil
	end
	return pending.market
end

-- Precio de una carta del Mercado en curso, o nil si no está en la oferta.
local function marketPriceOf(state: GameState, cardId: string): number?
	local market = pendingMarket(state)
	if not market then
		return nil
	end
	for _, card in market.cards do
		if card.cardId == cardId then
			return card.price
		end
	end
	return nil
end

local function priceOf(state: GameState, index: number): number?
	local square = state.board.squares[index]
	if not square then
		return nil
	end
	return square.price
end

-- Construcción más barata que deja al bot por encima de su reserva; nil si ninguna cumple.
local function cheapestBuild(state: GameState, player: Player, actions: { Action }): Action?
	local best: Action? = nil
	local bestCost = math.huge
	for _, action in actions do
		if action.type == "Build" then
			local cost = Building.costOf(state, player.id, action.index)
			if player.cash - cost > Economy.bot.buildReserve and cost < bestCost then
				best = action
				bestCost = cost
			end
		end
	end
	return best
end

-- Garantía que depositaría el jugador. El Negociador paga la reducida; el id se consulta sin
-- require Perks, igual que hace Pact con sus perks.
local function depositOf(player: Player): number
	if table.find(player.perks, NEGOTIATOR_PERK) ~= nil then
		return Economy.pact.negotiatorDeposit
	end
	return Economy.pact.deposit
end

-- ¿La oferta se puede responder en esta fase? Son las mismas de Pact.respondReason; la ventana
-- de reacción, el Mercado, el Duelo y el Tribunal no admiten pactos.
local function canRespondPact(phase: Types.Phase): boolean
	return phase == "AwaitRoll" or phase == "AwaitBuy" or phase == "AwaitEnd"
end

-- Primera oferta de pacto dirigida al jugador, o nil.
local function offerTo(state: GameState, playerId: PlayerId): PactOffer?
	local pending = state.pending
	local offers = pending and pending.pactOffers
	if not offers then
		return nil
	end
	for _, offer: PactOffer in offers do
		if offer.toId == playerId then
			return offer
		end
	end
	return nil
end

-- ¿El jugador ya tiene una oferta de pacto pendiente como proponente? Evita proponer en bucle.
local function hasOfferFrom(state: GameState, playerId: PlayerId): boolean
	local pending = state.pending
	local offers = pending and pending.pactOffers
	if not offers then
		return false
	end
	for _, offer: PactOffer in offers do
		if offer.fromId == playerId then
			return true
		end
	end
	return false
end

-- Respuesta a una oferta de pacto: acepta si las dos partes pueden cubrir su garantía y rechaza
-- en caso contrario. Rechazar no cuesta nada y libera la oferta antes de que caduque.
local function pactResponse(state: GameState, player: Player): Action?
	if not canRespondPact(state.phase) then
		return nil
	end
	local offer = offerTo(state, player.id)
	if not offer then
		return nil
	end
	local proposer = findPlayer(state, offer.fromId)
	local affordable = proposer ~= nil
		and proposer.status == "Active"
		and player.cash >= depositOf(player)
		and proposer.cash >= depositOf(proposer)
	return { type = "RespondPact", pactId = offer.id, accept = affordable }
end

-- Primer pacto vivo en el que participa el jugador, o nil.
local function pactOf(state: GameState, playerId: PlayerId): Types.Pact?
	for _, pact in state.pacts do
		if pact.a == playerId or pact.b == playerId then
			return pact
		end
	end
	return nil
end

-- Propuesta de pacto: solo si lleva Puñalada en la mano (así el pacto tiene una salida y la carta
-- no se queda atascada), no tiene un pacto vivo ni una oferta pendiente, y hay un rival activo
-- que pueda cubrir su garantía. La duración es la máxima del catálogo: el pacto caduca solo.
local function pactProposal(state: GameState, player: Player): Action?
	if table.find(player.hand, BACKSTAB_CARD) == nil then
		return nil
	end
	if state.phase ~= "AwaitRoll" and state.phase ~= "AwaitEnd" then
		return nil
	end
	if state.players[state.turnIndex].id ~= player.id then
		return nil
	end
	if player.status ~= "Active" then
		return nil
	end
	if pactOf(state, player.id) ~= nil then
		return nil
	end
	if hasOfferFrom(state, player.id) then
		return nil
	end
	if player.cash < depositOf(player) + Economy.bot.bidReserve then
		return nil
	end
	for _, candidate in state.players do
		if candidate.id ~= player.id and candidate.status == "Active" then
			if candidate.cash >= depositOf(candidate) + Economy.bot.bidReserve then
				return {
					type = "ProposePact",
					toId = candidate.id,
					rounds = Economy.pact.maxRounds,
				}
			end
		end
	end
	return nil
end

-- Cartas que solo tienen sentido antes de tirar: modifican la tirada del turno.
local ROLL_CARDS: { string } = { "ExtraDie", "Reverse" }

-- Propiedades del jugador y si tiene alguna en la zona de la casilla. La cartera objetivo es una
-- zona completa: al llegar al tope solo se compra donde ya se tiene presencia, para no repartir el
-- capital en parcelas sueltas que nunca completan un grupo. No es un tope duro: las subastas
-- pueden añadir más propiedades.
local function ownedCount(state: GameState, playerId: PlayerId): number
	local count = 0
	for _, property in state.properties do
		if property.ownerId == playerId then
			count += 1
		end
	end
	return count
end

local function ownsInZone(state: GameState, playerId: PlayerId, index: number): boolean
	local zoneId = state.board.squares[index].zoneId
	if not zoneId then
		return false
	end
	local indices = state.board.zones[zoneId]
	if not indices then
		return false
	end
	for _, other in indices do
		local property = state.properties[other]
		if property and property.ownerId == playerId then
			return true
		end
	end
	return false
end

-- Acción elegida. Devuelve nil cuando no hay ninguna legal o cuando, en una subasta, no le
-- compensa pujar: el bucle de simulación cierra con Engine.timeout. Nunca inventa una acción.
function Bot.choose(state: GameState, playerId: PlayerId): Action?
	local player = findPlayer(state, playerId)
	if not player then
		return nil
	end

	-- Los pactos no están en legalActions (su espacio no es finito): el bot los decide aquí y el
	-- motor los valida en apply como cualquier acción.
	local response = pactResponse(state, player)
	if response then
		return response
	end
	local proposal = pactProposal(state, player)
	if proposal then
		return proposal
	end

	local actions = Engine.legalActions(state, playerId)
	if #actions == 0 then
		return nil
	end
	local phase = state.phase
	if phase == "PerkDraft" then
		-- El primer perk ofrecido: la lista legal ya viene en el orden de la oferta y solo trae
		-- las acciones del jugador al que le toca elegir.
		return firstOf(actions, "DraftPerk")
	elseif phase == "GhostTurn" then
		-- Turno corto del espectro (R-P43): el sabotaje es la primera acción legal, la más simple
		-- y la que acumula para resucitar.
		return firstOf(actions, "GhostAct")
	elseif phase == "AwaitRoll" then
		-- Dedos Rápidos: si hay dados retenidos, repite uno antes de mover. Así el perk se usa de
		-- verdad en la simulación (y queda su contador).
		local reroll = firstOf(actions, "RerollDie")
		if reroll then
			return reroll
		end
		-- Las cartas de tirada se juegan antes de tirar; las demás esperan a AwaitEnd.
		local rollCard = firstCardOf(actions, ROLL_CARDS)
		if rollCard then
			return rollCard
		end
		return firstOf(actions, "Roll")
	elseif phase == "AwaitBuy" then
		local buy = firstOf(actions, "Buy")
		if buy then
			local index = pendingIndexOf(state)
			local price = if index then priceOf(state, index) else nil
			if price and index and player.cash - price > Economy.bot.buyReserve then
				-- Cartera máxima: una zona completa. Al llegar al tope solo se compra en una zona
				-- donde ya se tiene presencia; el resto se subasta.
				local zoneId = state.board.squares[index].zoneId
				local zoneSize = if zoneId then #state.board.zones[zoneId] else 0
				local full = ownedCount(state, player.id) >= zoneSize
				if not full or ownsInZone(state, player.id, index) then
					return buy
				end
			end
		end
		return firstOf(actions, "DeclineBuy")
	elseif phase == "AwaitEnd" then
		-- Toda carta legal se juega al cerrar el turno: la mano queda libre para el siguiente
		-- robo y no se llena de cartas sin salida.
		local card = firstOf(actions, "PlayCard")
		if card then
			return card
		end
		local build = cheapestBuild(state, player, actions)
		if build then
			return build
		end
		return firstOf(actions, "EndTurn")
	elseif phase == "Auction" then
		local bid = firstOf(actions, "Bid")
		if not bid then
			return nil
		end
		local pending = state.pending
		local auction = if pending then pending.auction else nil
		if auction and auction.highBidder == playerId then
			return nil
		end
		if player.cash - bid.amount > Economy.bot.bidReserve then
			return bid
		end
		return nil
	elseif phase == "Reaction" then
		-- Con carta de reacción en la mano se usa siempre: Escudo contra una carta y Renta
		-- Rebotada contra una renta (el primer tercero legal lo elige el motor). Sin carta, pasa.
		local react = firstOf(actions, "React")
		if react then
			return react
		end
		return firstOf(actions, "PassReaction")
	elseif phase == "Market" then
		-- Compra la primera carta de la oferta si le deja por encima de su reserva; si no, pasa.
		local buy = firstOf(actions, "MarketBuy")
		if buy then
			local price = marketPriceOf(state, buy.cardId)
			if price and player.cash - price > Economy.bot.buyReserve then
				return buy
			end
		end
		return firstOf(actions, "MarketSkip")
	elseif phase == "Duel" then
		-- Primero el retador elige rival; después cada participante elige piedra (la primera
		-- jugada del catálogo). La simulación pregunta a los dos participantes.
		return firstOf(actions, "DuelChoice")
	elseif phase == "Tribunal" then
		-- Vota distinto según el asiento para que haya empates reales: los impares multan y los
		-- pares quitan el turno. Es lo que permite que Abogado rompa un empate a su favor.
		local fine: Action? = nil
		local skip: Action? = nil
		for _, action in actions do
			if action.type == "TribunalVote" then
				if action.verdict == "Fine" then
					fine = action
				elseif action.verdict == "SkipTurn" then
					skip = action
				end
			end
		end
		if playerIndex(state, playerId) % 2 == 0 and skip then
			return skip
		end
		return fine or firstOf(actions, "TribunalVote")
	end
	return nil
end

return Bot

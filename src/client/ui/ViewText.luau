--!strict
-- Textos de la interfaz, en español y puros. Convierten lo que el motor y `View` mandan (ids, índices
-- de casilla, `userId` en texto) en frases que un jugador entiende: nombres de personas, de casillas,
-- de cartas y de perks. No crean ni tocan `Instance`, así que se prueban con Lune contra vistas
-- salidas de `Engine` y `View`, y los menús solo pintan lo que sale de aquí.
--
-- Las fórmulas no se repiten: precios y costes salen de `Property.priceFor`, `Building.costOf` y
-- `Squares.marketPriceFor`, que aceptan una vista porque solo leen tablero, jugadores y `pending`.
local Boards = require("../../shared/config/Boards")
local Building = require("../../shared/rules/Building")
local Cards = require("../../shared/config/Cards")
local Economy = require("../../shared/config/Economy")
local Perks = require("../../shared/config/Perks")
local Property = require("../../shared/rules/Property")
local Score = require("../../shared/rules/Score")
local Squares = require("../../shared/rules/Squares")
local Strings = require("../../shared/config/Strings")
local Types = require("../../shared/rules/Types")

type Action = Types.Action
type Board = Types.Board
type PlayerId = Types.PlayerId

-- Nombre visible de cada asiento, por `PlayerId`. Lo rellena `main.client` con los `Player` de Roblox.
export type Names = { [PlayerId]: string }

local ViewText = {}

-- El tablero es estático y se reconstruye con `Boards.get`, que lo arma entero cada vez: se guarda por
-- tamaño para no rehacerlo con cada texto.
local boards: { [string]: Board } = {}

function ViewText.board(sizeId: string): Board
	local cached = boards[sizeId]
	if cached == nil then
		cached = Boards.get(sizeId :: Types.SizeId)
		boards[sizeId] = cached
	end
	return cached
end

-- Guarda el nombre de quien está sentado. `lookup` resuelve un `PlayerId` a su nombre actual, o nil si
-- esa persona ya no está: el último nombre conocido se conserva, porque un bot puede ocupar el asiento
-- de quien se fue y la mesa sigue hablando de él por su nombre.
function ViewText.rememberNames(names: Names, view: any, lookup: (PlayerId) -> string?)
	if view == nil then
		return
	end
	for _, seated in view.players do
		local found = lookup(seated.id)
		if found ~= nil and found ~= "" then
			names[seated.id] = found
		end
	end
end

-- Nombre de un jugador: el conocido o «Jugador N» con su asiento; con bot lo dice, y el propio lleva
-- «tú» para que «Multa de 150 a Ana (tú)» no deje dudas.
function ViewText.playerName(view: any, names: Names?, id: PlayerId): string
	local seatIndex: number? = nil
	local isBot = false
	for index, seated in view.players do
		if seated.id == id then
			seatIndex = index
			isBot = seated.isBot == true
			break
		end
	end
	local name = if names ~= nil then names[id] else nil
	if name == nil then
		name = if seatIndex ~= nil then `Jugador {seatIndex}` else "Alguien"
	end
	local text: string = name :: string
	if isBot then
		text = `{text} (bot)`
	end
	if id == view.playerId then
		text = `{text} (tú)`
	end
	return text
end

-- Nombre para la placa de la mesa: el bot se ve por su antena y su marca, así que solo se añade «(tú)».
function ViewText.seatName(view: any, names: Names?, id: PlayerId): string
	local known = if names ~= nil then names[id] else nil
	local text: string = known or ""
	if text == "" then
		for index, seated in view.players do
			if seated.id == id then
				text = `Jugador {index}`
			end
		end
	end
	if text == "" then
		text = "Alguien"
	end
	return if id == view.playerId then `{text} (tú)` else text
end

-- Nombre de una casilla: el de la propiedad (por su ordinal dentro de la zona) o el de su tipo.
function ViewText.squareName(view: any, index: number): string
	local board = ViewText.board(view.sizeId)
	local square = board.squares[index]
	if square == nil then
		return `casilla {index}`
	end
	local ordinal: number? = nil
	if square.kind == "Property" and square.zoneId ~= nil then
		local zone = board.zones[square.zoneId]
		ordinal = if zone ~= nil then table.find(zone, index) else nil
	end
	return Strings.squareLabel(square, ordinal)
end

function ViewText.cardName(cardId: string): string
	local card = Cards.byId[cardId]
	return if card ~= nil then card.name else cardId
end

function ViewText.perkName(perkId: string): string
	local perk = Perks.byId[perkId]
	return if perk ~= nil then perk.name else perkId
end

-- Lo mínimo de un estado para las fórmulas del motor: tablero, jugadores y `pending` de la vista.
local function stateLike(view: any): any
	return { board = ViewText.board(view.sizeId), players = view.players, pending = view.pending }
end

local function pendingOf(view: any): any
	return if view.pending ~= nil then view.pending else {}
end

-- Etiqueta de un botón con el objeto de la acción dicho por su nombre: quien lo lee sabe qué compra,
-- a quién retará o dónde construye. Una acción que no se conoce se muestra con su tipo, como siempre.
-- Solo el objetivo de una jugada de carta («Callejón del Cobre», «Ana»), y el color de su zona si lo tiene.
-- Sirve para los botones de una carta con varios objetivos: el nombre de la carta ya está en la carta.
-- nil si la jugada no tiene objetivo.
function ViewText.cardTarget(view: any, names: Names?, action: Action): (string?, string?)
	if action.zoneId ~= nil then
		local zone = Strings.zone(tostring(action.zoneId))
		return zone.name, zone.color
	elseif action.targetId ~= nil then
		return ViewText.playerName(view, names, tostring(action.targetId)), nil
	elseif type(action.index) == "number" then
		return ViewText.squareName(view, action.index), nil
	elseif action.pactId ~= nil then
		for _, pact in view.pacts or {} do
			if pact.id == action.pactId then
				local a = ViewText.playerName(view, names, tostring(pact.a))
				local b = ViewText.playerName(view, names, tostring(pact.b))
				return `{a} y {b}`, nil
			end
		end
	end
	return nil, nil
end

function ViewText.actionLabel(view: any, names: Names?, action: Action): string
	local actionType = action.type
	local pending = pendingOf(view)
	local me = view.playerId
	local function player(id: any): string
		return ViewText.playerName(view, names, tostring(id))
	end
	local function square(index: any): string
		return if type(index) == "number" then ViewText.squareName(view, index) else "una casilla"
	end

	if actionType == "DraftPerk" then
		local perk = Perks.byId[action.perkId]
		if perk == nil then
			return tostring(action.perkId)
		end
		return `{perk.name}: {perk.description}`
	elseif actionType == "Roll" then
		local held = pending.heldRoll
		if held ~= nil then
			return `Mover con {held.a} y {held.b}`
		end
		return "Tirar dados"
	elseif actionType == "RerollDie" then
		local held = pending.heldRoll
		local which = if action.die == "a" then "primer" else "segundo"
		local value = if held ~= nil then held[action.die] else nil
		return if value ~= nil then `Repetir el {which} dado ({value})` else `Repetir el {which} dado`
	elseif actionType == "Buy" then
		local index = pending.index
		if type(index) ~= "number" then
			return "Comprar"
		end
		return `Comprar {square(index)} por {Property.priceFor(stateLike(view), me, index)}`
	elseif actionType == "DeclineBuy" then
		local index = pending.index
		if type(index) ~= "number" then
			return "No comprar"
		end
		return `No comprar {square(index)} (sale a subasta)`
	elseif actionType == "Build" then
		local index = action.index
		if type(index) ~= "number" then
			return "Construir"
		end
		local property = if view.properties ~= nil then view.properties[index] else nil
		local level = if property ~= nil then property.level + 1 else 1
		local cost = Building.costOf(stateLike(view), me, index)
		return `Construir en {square(index)} (nivel {level}) por {cost}`
	elseif actionType == "SellBuilding" or actionType == "Mortgage" or actionType == "Unmortgage" then
		local index = action.index
		if type(index) ~= "number" then
			return actionType
		end
		local state = stateLike(view)
		if actionType == "SellBuilding" then
			return `Vender un nivel de {square(index)} por {Building.sellRefund(state, index)}`
		elseif actionType == "Mortgage" then
			return `Hipotecar {square(index)} por {Building.mortgageValue(state, index)}`
		end
		return `Levantar la hipoteca de {square(index)} por {Building.unmortgageCost(state, index)}`
	elseif actionType == "PlayCard" then
		local card = Cards.byId[action.cardId]
		local name = ViewText.cardName(tostring(action.cardId))
		if card == nil then
			return `Jugar {name}`
		end
		if card.target == "Player" and action.targetId ~= nil then
			return `Jugar {name} contra {player(action.targetId)}`
		elseif card.target == "Zone" and action.zoneId ~= nil then
			return `Jugar {name} en {Strings.zone(action.zoneId).name}`
		elseif card.target == "Property" and action.index ~= nil then
			return `Jugar {name} sobre {square(action.index)}`
		elseif card.target == "Pact" and action.pactId ~= nil then
			for _, pact in view.pacts or {} do
				if pact.id == action.pactId then
					return `Jugar {name} sobre el pacto de {player(pact.a)} y {player(pact.b)}`
				end
			end
			return `Jugar {name} sobre un pacto`
		end
		return `Jugar {name}`
	elseif actionType == "React" then
		if action.cardId == "BounceRent" and action.targetId ~= nil then
			return `Renta Rebotada: que pague {player(action.targetId)}`
		end
		return `Reaccionar: {ViewText.cardName(tostring(action.cardId))}`
	elseif actionType == "PassReaction" then
		return "No reaccionar"
	elseif actionType == "MarketBuy" then
		local name = ViewText.cardName(tostring(action.cardId))
		local price = Squares.marketPriceFor(stateLike(view), me, tostring(action.cardId))
		return if price ~= nil then `Comprar {name} por {price}` else `Comprar {name}`
	elseif actionType == "MarketSkip" then
		return "No comprar nada"
	elseif actionType == "DuelChoice" then
		if action.rivalId ~= nil then
			return `Retar a {player(action.rivalId)}`
		end
		return Strings.duelChoice(tostring(action.choice))
	elseif actionType == "TribunalVote" then
		local tribunal = pending.tribunal
		local accused = if tribunal ~= nil then player(tribunal.accusedId) else "el acusado"
		if action.verdict == "Fine" then
			return `Multa de {Economy.tribunal.fine} a {accused}`
		elseif action.verdict == "SkipTurn" then
			return `{accused} pierde un turno`
		elseif action.verdict == "PayToPlayer" and action.targetId ~= nil then
			return `{accused} paga {Economy.tribunal.payToPlayer} a {player(action.targetId)}`
		end
		return "Votar castigo"
	elseif actionType == "GhostAct" then
		if action.kind == "Haunt" and type(action.index) == "number" then
			return `Embrujar {square(action.index)}`
		end
		return "Sabotear: robar una carta"
	elseif actionType == "EndTurn" then
		return "Terminar turno"
	end
	return actionType
end

export type OptionKind = "Perk" | "Card" | "Vote" | "Duel" | "Ghost" | "Pass" | "Other"

-- Una opción del panel de decisión dicha como tarjeta: título corto, detalle y una nota (precio u
-- objetivo). `kind` decide su cara; `cardId`, si es una carta, para su rareza.
export type OptionCard = {
	kind: OptionKind,
	title: string,
	detail: string?,
	note: string?,
	cardId: string?,
	-- Perk elegido, cuando la opción es una carta de perk: la tarjeta enseña su icono.
	perkId: string?,
}

function ViewText.optionCard(view: any, names: Names?, action: Action): OptionCard
	local actionType = action.type
	local label = ViewText.actionLabel(view, names, action)
	if actionType == "DraftPerk" then
		local perk = Perks.byId[action.perkId]
		if perk ~= nil then
			return {
				kind = "Perk",
				title = perk.name,
				detail = perk.description,
				perkId = tostring(action.perkId),
			}
		end
	elseif actionType == "PlayCard" or actionType == "React" or actionType == "MarketBuy" then
		local cardId = tostring(action.cardId)
		local card = Cards.byId[cardId]
		if card ~= nil then
			local note: string? = nil
			if actionType == "MarketBuy" then
				local price = Squares.marketPriceFor(stateLike(view), view.playerId, cardId)
				note = if price ~= nil then Strings.get("option.price", { price = price }) else nil
			elseif label ~= `Jugar {card.name}` and label ~= `Reaccionar: {card.name}` then
				-- Con objetivo, la etiqueta dice contra quién o dónde: va de nota.
				note = label
			end
			return {
				kind = "Card",
				title = card.name,
				detail = Strings.get(`card.{cardId}.description`),
				note = note,
				cardId = cardId,
			}
		end
	elseif actionType == "PassReaction" or actionType == "MarketSkip" then
		return { kind = "Pass", title = label }
	elseif actionType == "TribunalVote" then
		local title = label
		if action.verdict == "Fine" then
			title = Strings.get("option.fine", { amount = Economy.tribunal.fine })
		elseif action.verdict == "SkipTurn" then
			title = Strings.get("option.skipTurn")
		elseif action.verdict == "PayToPlayer" and action.targetId ~= nil then
			title = Strings.get("option.payTo", {
				amount = Economy.tribunal.payToPlayer,
				name = ViewText.playerName(view, names, tostring(action.targetId)),
			})
		end
		return { kind = "Vote", title = title, detail = label }
	elseif actionType == "DuelChoice" then
		if action.rivalId ~= nil then
			return {
				kind = "Duel",
				title = ViewText.playerName(view, names, tostring(action.rivalId)),
				detail = label,
			}
		end
		return { kind = "Duel", title = Strings.duelChoice(tostring(action.choice)) }
	elseif actionType == "GhostAct" then
		local haunt = action.kind == "Haunt"
		return {
			kind = "Ghost",
			title = Strings.get(if haunt then "option.haunt" else "option.sabotage"),
			detail = label,
		}
	end
	return { kind = "Other", title = label }
end

-- Efectos de la mesa que dura unas rondas, con su nombre en español.
local EFFECTS: { [string]: string } = {
	Inflation = "Inflación",
	Strike = "Huelga",
	Haunt = "Embrujo",
	Discount = "Descuento",
}

-- Línea de un efecto activo: qué es, dónde (zona o casilla), de quién y hasta cuándo.
function ViewText.modifierText(view: any, names: Names?, modifier: any): string
	local parts: { string } = { EFFECTS[modifier.kind] or tostring(modifier.kind) }
	if modifier.zoneId ~= nil then
		table.insert(parts, Strings.zone(modifier.zoneId).name)
	end
	if type(modifier.index) == "number" then
		table.insert(parts, ViewText.squareName(view, modifier.index))
	end
	if modifier.playerId ~= nil then
		table.insert(parts, `de {ViewText.playerName(view, names, modifier.playerId)}`)
	end
	table.insert(parts, `hasta la ronda {modifier.untilRound}`)
	return table.concat(parts, " · ")
end

-- Ronda en la barra. La ronda del motor sube al acabar la última («21/20») y eso no es una ronda que
-- se juegue: se acota al tope. Sin tope (Sin Fin) no hay «/N».
function ViewText.roundText(view: any): string
	local max = view.maxRounds
	if type(max) == "number" and max > 0 then
		return `Ronda {math.min(view.round, max)}/{max}`
	end
	return `Ronda {view.round}`
end

-- ¿Lleva la marca de Traidor? Dura hasta la ronda que fija el motor, incluida.
local function isTraitor(view: any, seated: any): boolean
	return seated.traitorUntilRound ~= nil and view.round <= seated.traitorUntilRound
end

-- Línea de un asiento para la barra: quién, cuánto dinero y dónde, y debajo lo que lo distingue
-- (Corona, Traidor, Furia, perks y cartas). Lo que el servidor manda como público se enseña a todos;
-- la mano ajena es solo un número.
function ViewText.seatLine(view: any, names: Names?, index: number): string
	local seated = view.players[index]
	local pending = pendingOf(view)
	local turn = if index == view.turnIndex and view.phase ~= "GameOver" then "▶ " else ""
	local main =
		`{turn}{ViewText.playerName(view, names, seated.id)} · {seated.cash} · {ViewText.squareName(
			view,
			seated.position
		)}`
	local tags: { string } = {}
	if seated.status == "Ghost" then
		table.insert(tags, "Espectro")
	elseif seated.status == "Left" then
		table.insert(tags, "Se fue")
	end
	if pending.crownId == seated.id then
		table.insert(tags, "Corona")
	end
	if isTraitor(view, seated) then
		table.insert(tags, "Traidor")
	end
	if seated.fury > 0 then
		table.insert(tags, `Furia {seated.fury}/{Economy.furyThreshold}`)
	end
	if seated.status == "Ghost" and seated.sabotages > 0 then
		table.insert(tags, `{seated.sabotages}/{Economy.ghost.sabotagesToRevive} sabotajes`)
	end
	if seated.skipTurns > 0 then
		table.insert(tags, "pierde turno")
	end
	if seated.handCount > 0 then
		table.insert(tags, if seated.handCount == 1 then "1 carta" else `{seated.handCount} cartas`)
	end
	for _, perkId in seated.perks do
		table.insert(tags, ViewText.perkName(perkId))
	end
	if #tags == 0 then
		return main
	end
	return `{main}\n{table.concat(tags, " · ")}`
end

-- Mano y perks del propio jugador, con el nombre de cada carta, y el resultado del Espía si lo
-- jugó. Cada línea es una frase; sin nada que decir no hay línea.
function ViewText.ownLines(view: any, names: Names?): { string }
	local lines: { string } = {}
	local own: any = nil
	for _, seated in view.players do
		if seated.id == view.playerId then
			own = seated
		end
	end
	if own == nil then
		return lines
	end
	local hand: { string } = {}
	for _, cardId in own.hand or {} do
		table.insert(hand, ViewText.cardName(cardId))
	end
	table.insert(lines, if #hand > 0 then `Tu mano: {table.concat(hand, ", ")}` else "Tu mano: vacía")
	if #own.perks > 0 then
		local perks: { string } = {}
		for _, perkId in own.perks do
			table.insert(perks, ViewText.perkName(perkId))
		end
		table.insert(lines, `Tus perks: {table.concat(perks, ", ")}`)
	end
	local spy = pendingOf(view).spy
	if spy ~= nil and spy.viewerId == view.playerId then
		local spied: { string } = {}
		for _, cardId in spy.hand or {} do
			table.insert(spied, ViewText.cardName(cardId))
		end
		local target = ViewText.playerName(view, names, spy.targetId)
		table.insert(
			lines,
			if #spied > 0
				then `Espía: {target} tiene {table.concat(spied, ", ")}`
				else `Espía: {target} no tiene cartas`
		)
	end
	return lines
end

-- Qué está pasando ahora en la mesa, para quien mira y para quien espera: de quién es la decisión y,
-- en una subasta, la puja más alta y lo que vale la casilla.
function ViewText.headline(view: any, names: Names?): string
	local pending = pendingOf(view)
	local function name(id: any): string
		return ViewText.playerName(view, names, tostring(id))
	end
	local phase = view.phase
	local turn = view.players[view.turnIndex]
	local turnName = if turn ~= nil then name(turn.id) else "Alguien"
	if phase == "PerkDraft" then
		local draft = pending.draft
		local drafter = if draft ~= nil then draft.order[draft.index] else nil
		return if drafter ~= nil then `Elige perk: {name(drafter)}` else "Elección de perks"
	elseif phase == "Auction" then
		local auction = pending.auction
		if auction == nil then
			return "Subasta"
		end
		local square = ViewText.board(view.sizeId).squares[auction.index]
		local worth = if square ~= nil and square.price ~= nil then ` (vale {square.price})` else ""
		local head = `Subasta de {ViewText.squareName(view, auction.index)}{worth}`
		if auction.highBidder ~= nil then
			return `{head}: puja más alta {auction.high} de {name(auction.highBidder)}`
		end
		return `{head}: sin pujas`
	elseif phase == "Reaction" then
		local reaction = pending.reaction
		return if reaction ~= nil then `{name(reaction.eligibleId)} puede reaccionar` else "Reacción"
	elseif phase == "Tribunal" then
		local tribunal = pending.tribunal
		if tribunal == nil then
			return "Tribunal"
		end
		if tribunal.accusedId == view.playerId then
			return "Tribunal: te juzgan los demás"
		end
		return `Tribunal: castigo para {name(tribunal.accusedId)}`
	elseif phase == "Duel" then
		local duel = pending.duel
		if duel == nil then
			return "Duelo"
		end
		if duel.rivalId == nil then
			return `Duelo: {name(duel.challengerId)} elige rival`
		end
		return `Duelo: {name(duel.challengerId)} contra {name(duel.rivalId)}`
	elseif phase == "Market" then
		local market = pending.market
		return if market ~= nil then `Mercado Negro: {name(market.playerId)}` else "Mercado Negro"
	elseif phase == "GameOver" then
		return "Fin de la partida"
	end
	return `Turno de {turnName}`
end

-- Podio del final con el evento `GameEnded`: el ganador, la clasificación en el orden del motor
-- (patrimonio, luego efectivo) y los premios con su nombre. Sin evento, no hay podio. `view` sirve para
-- resolver nombres: es la vista de la mesa al acabar, con todos sus asientos.
export type Podium = {
	winnerId: string?,
	ranking: { { id: string, position: number, name: string, worth: number } },
	awards: { { label: string, name: string } },
}

-- Podio con estructura, para que el tablón de la revancha pinte cada parte a su manera. Mismos datos
-- que `podiumLines`: ganador, clasificación con el patrimonio del motor y premios.
function ViewText.podium(event: any, view: any, names: Names?): Podium
	local podium: Podium = { winnerId = nil, ranking = {}, awards = {} }
	if event == nil or view == nil then
		return podium
	end
	podium.winnerId = event.winnerId
	local final =
		{ board = ViewText.board(view.sizeId), players = view.players, properties = view.properties }
	for position, id in event.ranking or {} do
		table.insert(podium.ranking, {
			id = id,
			position = position,
			name = ViewText.playerName(view, names, id),
			worth = Score.netWorth(final :: any, id),
		})
	end
	for _, award in event.awards or {} do
		table.insert(podium.awards, {
			label = Strings.award(award.id),
			name = ViewText.playerName(view, names, award.playerId),
		})
	end
	return podium
end

function ViewText.podiumLines(event: any, view: any, names: Names?): { string }
	local lines: { string } = {}
	if event == nil then
		return lines
	end
	if event.winnerId ~= nil then
		table.insert(lines, `Ganador: {ViewText.playerName(view, names, event.winnerId)}`)
	end
	-- `ranking` es la lista de ids en orden. El patrimonio se calcula con la misma fórmula del motor
	-- sobre la vista final, que ya lleva dinero, casillas y niveles de todos.
	local final =
		{ board = ViewText.board(view.sizeId), players = view.players, properties = view.properties }
	for position, id in event.ranking or {} do
		local name = ViewText.playerName(view, names, id)
		table.insert(lines, `{position}. {name} · patrimonio {Score.netWorth(final :: any, id)}`)
	end
	for _, award in event.awards or {} do
		table.insert(lines, `{Strings.award(award.id)}: {ViewText.playerName(view, names, award.playerId)}`)
	end
	return lines
end

return ViewText

--!strict
-- Punto de entrada del motor: valida la acción, la aplica y devuelve los eventos.
local Auction = require("./Auction")
local Board = require("./Board")
local Building = require("./Building")
local Cards = require("./Cards")
local Economy = require("../config/Economy")
local Movement = require("./Movement")
local Property = require("./Property")
local Rng = require("./Rng")
local Trade = require("./Trade")
local Turn = require("./Turn")
local Types = require("./Types")

type GameState = Types.GameState
type PlayerId = Types.PlayerId
type Action = Types.Action
type Event = Types.Event
type Phase = Types.Phase

type Handler = (GameState, PlayerId, Action) -> { Event }

-- Una acción y su contrato: fases válidas, quién puede usarla y qué la ejecuta.
type ActionRule = {
	phases: { Phase },
	turnOnly: boolean,
	-- Comprobación extra antes de mutar (efectivo, pending...). nil = sin motivo de rechazo.
	check: ((GameState, PlayerId, Action) -> string?)?,
	handler: Handler,
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

-- Resuelve la casilla pisada. Una propiedad libre abre la compra; la ajena cobra renta; la
-- propia y las demás casillas cierran el turno (los efectos de las especiales llegan en la 03).
local function resolveLanding(state: GameState, playerId: PlayerId): (Phase, { Event })
	local player = playerOf(state, playerId)
	if not player then
		error(`Engine.resolveLanding: no existe el jugador {playerId}`, 2)
	end
	local square = Board.square(state, player.position)
	if square.kind ~= "Property" then
		return "AwaitEnd", {}
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

-- Roll: dos dados (o tres con Dado Extra), movimiento de la ficha y resolución de la casilla.
-- Marcha Atrás invierte el sentido de la tirada. Las dos marcas se consumen aquí.
local function roll(state: GameState, playerId: PlayerId, _action: Action): { Event }
	local pending = state.pending
	if not pending then
		error("Engine.roll: el estado no tiene pending", 2)
	end
	local extraDie = pending.extraDie == true
	local backwards = pending.reverse == true
	pending.extraDie = nil
	pending.reverse = nil

	local a = Rng.int(state.rng, 1, 6)
	local b = Rng.int(state.rng, 1, 6)
	local total = a + b
	-- El dado extra solo aparece en el evento cuando se usa: las tiradas antiguas no cambian.
	local dice: Event = { type = "DiceRolled", playerId = playerId, a = a, b = b }
	local rolled: { [string]: number } = { a = a, b = b }
	if extraDie then
		local c = Rng.int(state.rng, 1, 6)
		total += c
		dice.c = c
		rolled.c = c
	end
	pending.rolled = rolled

	local events: { Event } = { dice }
	append(events, Movement.advance(state, playerId, if backwards then -total else total))
	-- Anotación explícita: Luau ensancha la unión de literales al inferir la local.
	local phase: Phase, landingEvents: { Event } = resolveLanding(state, playerId)
	append(events, landingEvents)
	-- La casilla puede cerrar la partida (la renta arruina al último rival y Turn fija
	-- GameOver): la fase resuelta no sobrescribe un final ya decidido.
	if state.phase ~= "GameOver" then
		state.phase = phase
	end
	return events
end

-- EndTurn: pasa el turno y deja al siguiente jugador listo para tirar. Turn.next puede cerrar
-- la partida (última ronda o un solo activo): entonces la fase GameOver no se sobrescribe (R13).
local function endTurn(state: GameState, _playerId: PlayerId, _action: Action): { Event }
	local events = Turn.next(state)
	local pending = state.pending
	if pending then
		-- La vista del turno siguiente no debe enseñar los dados del jugador anterior ni las
		-- cartas de tirada sin gastar: solo valen para la tirada de este turno.
		pending.rolled = nil
		pending.extraDie = nil
		pending.reverse = nil
	end
	if state.phase ~= "GameOver" then
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

-- Buy: cobra la propiedad pendiente al precio de Property.priceFor (que aplica Descuento) y
-- consume la marca si era del comprador. Todo lo rechazable se comprueba antes de mutar.
local function buy(state: GameState, playerId: PlayerId, _action: Action): { Event }
	local pending = state.pending
	if not pending or not pending.index then
		error("Engine.buy: la fase AwaitBuy no tiene pending.index", 2)
	end
	local price = Property.priceFor(state, playerId, pending.index)
	local events = Property.buy(state, playerId, pending.index, price)
	-- La subasta no pasa por aquí: nunca aplica ni consume el Descuento.
	if pending.discountId == playerId then
		pending.discountId = nil
	end
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

-- Única fuente de verdad de fases y permisos: la Tarea 9 derivará legalActions de aquí.
-- Las tareas siguientes añaden sus acciones a esta misma tabla.
local rules: { [string]: ActionRule } = {
	Roll = { phases = { "AwaitRoll" }, turnOnly = true, handler = roll },
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
-- representativa, Build por casilla edificable y EndTurn. Los intercambios no se enumeran (su
-- espacio es infinito) y se validan en apply. Los candidatos pasan por validate, la única tabla
-- de permisos: nunca se devuelve una acción que apply rechazaría (R8).
function Engine.legalActions(state: GameState, playerId: PlayerId): { Action }
	local phase = state.phase
	local candidates: { Action } = {}
	if phase == "AwaitRoll" or phase == "AwaitEnd" then
		table.insert(candidates, { type = if phase == "AwaitRoll" then "Roll" else "EndTurn" })
		for _, square in state.board.squares do
			if square.kind == "Property" then
				table.insert(candidates, { type = "Build", index = square.index })
			end
		end
	elseif phase == "AwaitBuy" then
		table.insert(candidates, { type = "Buy" })
		table.insert(candidates, { type = "DeclineBuy" })
	elseif phase == "Auction" then
		local bidAction = representativeBid(state, playerId)
		if bidAction then
			table.insert(candidates, bidAction)
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
	return { ok = true, events = rule.handler(state, playerId, action) }
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
		pending.extraDie = nil
		pending.reverse = nil
	end
	local events = Turn.next(state)
	if state.phase ~= "GameOver" then
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
	local action: Action = { type = "Roll" }
	if phase == "AwaitBuy" then
		action = { type = "DeclineBuy" }
	elseif phase == "AwaitEnd" then
		action = { type = "EndTurn" }
	end
	local events = perform(state, player.id, action)
	-- La tirada y la compra siempre emiten eventos; si no hay ninguno, apply rechazó el defecto
	-- (por ejemplo, AwaitBuy sin casilla pendiente) y se cierra el turno para no congelar la
	-- partida. En AwaitEnd el turno ya avanzó aunque no haya eventos que anunciar.
	if #events > 0 or phase == "AwaitEnd" then
		return events
	end
	return abandonTurn(state)
end

return Engine

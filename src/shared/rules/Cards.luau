--!strict
-- Efectos de las cartas de giro. Las definiciones (nombre, rareza, objetivo) viven en
-- config/Cards; aquí solo hay comportamiento. Una carta sin efecto en esta tabla se rechaza con
-- «Carta no implementada»: cada tarea añade las suyas (comunes T2, raras T3, legendarias T4,
-- reacciones T5).

local Bankruptcy = require("./Bankruptcy")
local Building = require("./Building")
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

-- Argumentos de PlayCard que consumen los efectos (zona, casilla o pacto). Cada carta valida los
-- suyos en Cards.reason antes de mutar el estado.
export type PlayArgs = {
	targetId: PlayerId?,
	zoneId: string?,
	index: number?,
	pactId: string?,
}

-- El quinto argumento son los argumentos de PlayCard (zona, casilla o pacto). Las cartas que no
-- los usan declaran menos parámetros y Luau las sigue aceptando.
type Effect = (GameState, Player, Player?, { Event }, PlayArgs) -> ()

type EffectDef = {
	-- Fases en las que la carta tiene sentido. PlayCard solo llega desde AwaitRoll y AwaitEnd.
	phases: { Phase },
	-- Motivo por el que los argumentos de la carta no valen, o nil. Se comprueba en Cards.reason
	-- antes de aplicar y nunca muta el estado.
	reason: ((GameState, PlayerId, PlayArgs) -> string?)?,
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

-- Marca al jugador en el conjunto `field` de pending (lo crea si hace falta). Descuentos y
-- sobornos son conjuntos por jugador: dos jugadores pueden tener el suyo vivo a la vez y nadie
-- cancela la marca de otro.
local function markPending(state: GameState, field: string, playerId: PlayerId)
	local pending = pendingOf(state)
	local marks = pending[field]
	if not marks then
		marks = {}
		pending[field] = marks
	end
	marks[playerId] = true
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

-- Índice del pacto con ese id, o nil. Los pactos viven en el estado desde la Tarea 8, que
-- completa su ciclo de vida; Puñalada opera sobre el mismo arreglo.
local function findPactIndex(state: GameState, pactId: string): number?
	for index, pact in state.pacts do
		if pact.id == pactId then
			return index
		end
	end
	return nil
end

-- Motivo por el que la casilla de una carta de propiedad no vale, o nil. Solo comprueba que sea
-- una propiedad con dueño: cada carta añade sus propias restricciones.
local function propertyTargetReason(state: GameState, index: number?, cardId: string): string?
	if type(index) ~= "number" or index % 1 ~= 0 then
		return `La carta {cardId} necesita una propiedad`
	end
	local square = state.board.squares[index]
	if not square or square.kind ~= "Property" then
		return "La casilla indicada no es una propiedad"
	end
	local property = state.properties[index]
	if not property or not property.ownerId then
		return "La propiedad no tiene dueño"
	end
	return nil
end

-- ¿El jugador sería dueño de toda la zona si robara esta casilla? El robo no puede completar un
-- grupo: la carta nunca entrega la zona entera.
local function completesZone(state: GameState, playerId: PlayerId, index: number): boolean
	local square = state.board.squares[index]
	if not square or not square.zoneId then
		return false
	end
	local indices = state.board.zones[square.zoneId]
	if not indices then
		return false
	end
	for _, other in indices do
		if other ~= index then
			local property = state.properties[other]
			if not property or property.ownerId ~= playerId then
				return false
			end
		end
	end
	return true
end

-- Apagón: la zona debe existir en el tablero.
local function blackoutReason(state: GameState, _playerId: PlayerId, args: PlayArgs): string?
	if type(args.zoneId) ~= "string" then
		return "La carta Blackout necesita una zona"
	end
	if not state.board.zones[args.zoneId] then
		return `La zona {args.zoneId} no existe`
	end
	return nil
end

-- Ladrón de Escrituras: propiedad ajena, sin edificios y que no complete el grupo del ladrón.
local function deedThiefReason(state: GameState, playerId: PlayerId, args: PlayArgs): string?
	local reason = propertyTargetReason(state, args.index, "DeedThief")
	if reason then
		return reason
	end
	local index = args.index :: number
	local property = state.properties[index]
	if property.ownerId == playerId then
		return "No puedes robarte una propiedad"
	end
	local owner = findPlayer(state, property.ownerId :: PlayerId)
	if not owner or owner.status ~= "Active" then
		return "El dueño de la propiedad no es un rival activo"
	end
	if property.level > 0 then
		return "No se puede robar una propiedad con edificios"
	end
	if completesZone(state, playerId, index) then
		return "Robar esta propiedad completaría el grupo"
	end
	return nil
end

-- Demolición: edificio de otro jugador activo y con al menos un nivel.
local function demolitionReason(state: GameState, playerId: PlayerId, args: PlayArgs): string?
	local reason = propertyTargetReason(state, args.index, "Demolition")
	if reason then
		return reason
	end
	local index = args.index :: number
	local property = state.properties[index]
	if property.ownerId == playerId then
		return "No puedes demoler tu propio edificio"
	end
	local owner = findPlayer(state, property.ownerId :: PlayerId)
	if not owner or owner.status ~= "Active" then
		return "El dueño de la propiedad no es un rival activo"
	end
	if property.level <= 0 then
		return "La propiedad no tiene edificios"
	end
	return nil
end

-- Puñalada: el lanzador debe participar en el pacto que rompe (R-P1).
local function backstabReason(state: GameState, playerId: PlayerId, args: PlayArgs): string?
	if type(args.pactId) ~= "string" then
		return "La carta Backstab necesita un pacto"
	end
	local index = findPactIndex(state, args.pactId)
	if not index then
		return "El pacto no existe"
	end
	local pact = state.pacts[index]
	if pact.a ~= playerId and pact.b ~= playerId then
		return "No participas en ese pacto"
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

-- Propina Forzada: cada rival paga 50 al lanzador. R-P3: todo cobro pasa por
-- Bankruptcy.charge para que nadie quede con efectivo negativo. R-P20/R-P21: también se intenta
-- con espectros y con quien abandonó; Bankruptcy.charge lo deja en no-op porque ya no tienen
-- dinero que dar.
local function forcedTip(state: GameState, player: Player, _target: Player?, events: { Event })
	for _, rival in state.players do
		if rival.id ~= player.id then
			append(events, Bankruptcy.charge(state, rival.id, Economy.cards.forcedTip, player.id))
		end
	end
end

-- Descuento: la próxima compra directa del lanzador cuesta la mitad. Property.buy consume la
-- marca de ese jugador y las subastas no la tocan.
local function discount(state: GameState, player: Player, _target: Player?, _events: { Event })
	markPending(state, "discounts", player.id)
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
	markPending(state, "bribes", player.id)
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

-- Inflación: todas las rentas ×2 durante Economy.cards.inflationRounds rondas. untilRound es la
-- última ronda activa; Property.rentMultiplier ignora los modificadores ya caducados.
local function inflation(
	state: GameState,
	_player: Player,
	_target: Player?,
	_events: { Event },
	_args: PlayArgs
)
	table.insert(state.modifiers, {
		kind = "Inflation",
		untilRound = state.round + Economy.cards.inflationRounds - 1,
	})
end

-- Apagón: una zona no cobra renta durante Economy.cards.blackoutRounds rondas.
local function blackout(
	state: GameState,
	_player: Player,
	_target: Player?,
	_events: { Event },
	args: PlayArgs
)
	table.insert(state.modifiers, {
		kind = "Blackout",
		zoneId = args.zoneId :: string,
		untilRound = state.round + Economy.cards.blackoutRounds - 1,
	})
end

-- Ladrón de Escrituras: el dueño rival pierde la propiedad y el lanzador la gana sin pagar. Se
-- emite PropertyBought, el evento de propiedad que ya usa el motor; el precio es 0 porque la
-- carta es lo que se gasta.
local function deedThief(
	state: GameState,
	player: Player,
	_target: Player?,
	events: { Event },
	args: PlayArgs
)
	local index = args.index :: number
	local property = state.properties[index]
	if not property then
		error(`Cards.deedThief: la casilla {index} no es una propiedad`, 2)
	end
	property.ownerId = player.id
	table.insert(events, { type = "PropertyBought", playerId = player.id, index = index, price = 0 })
end

-- Puñalada: rompe un pacto propio sin coste (R-P1). Cada parte recupera su garantía —el lanzador
-- no la pierde como en una ruptura normal— y el lanzador queda marcado como Traidor.
local function backstab(state: GameState, player: Player, _target: Player?, events: { Event }, args: PlayArgs)
	local index = findPactIndex(state, args.pactId :: string)
	if not index then
		error("Cards.backstab: el pacto validado ya no existe", 2)
	end
	local pact = state.pacts[index]
	local ownDeposit = if pact.a == player.id then pact.depositA else pact.depositB
	local partnerDeposit = if pact.a == player.id then pact.depositB else pact.depositA
	local partnerId = if pact.a == player.id then pact.b else pact.a
	table.remove(state.pacts, index)
	player.cash += ownDeposit
	playerOf(state, partnerId).cash += partnerDeposit
	-- Misma convención que los modificadores: untilRound es la última ronda activa, así que una
	-- marca de 3 rondas creada en R llega hasta R+2 y cubre R, R+1 y R+2.
	player.traitorUntilRound = state.round + Economy.pact.traitorRounds - 1
	local stats = state.stats[player.id]
	stats.pactsBroken = (stats.pactsBroken or 0) + 1
	table.insert(events, { type = "PactBroken", pactId = pact.id, playerId = player.id })
end

-- Demolición: baja un nivel de un edificio rival. Building.lower emite BuildingChanged y no
-- devuelve dinero.
local function demolition(
	state: GameState,
	_player: Player,
	_target: Player?,
	events: { Event },
	args: PlayArgs
)
	append(events, Building.lower(state, args.index :: number))
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
	Inflation = { phases = TURN_PHASES, apply = inflation },
	Blackout = { phases = TURN_PHASES, reason = blackoutReason, apply = blackout },
	DeedThief = { phases = TURN_PHASES, reason = deedThiefReason, apply = deedThief },
	Backstab = { phases = TURN_PHASES, reason = backstabReason, apply = backstab },
	Demolition = { phases = TURN_PHASES, reason = demolitionReason, apply = demolition },
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
		local targetMessage = targetReason(state, playerId, cardId, args.targetId)
		if targetMessage then
			return targetMessage
		end
	end
	if effect.reason then
		local argumentMessage = effect.reason(state, playerId, args)
		if argumentMessage then
			return argumentMessage
		end
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

	EFFECTS[cardId].apply(state, player, target, events, args)
	return { ok = true, events = events }
end

return Cards

--!strict
-- Duraciones de las escenas de cada evento y tiempo de decisión de cada fase. Es el único sitio
-- donde viven el mapa evento → segundos (R-P23) y el mapa fase → segundos (R-P20): ni SceneClock
-- ni MatchService tienen números propios.
local Cards = require("./Cards")
local Economy = require("./Economy")
local Types = require("../rules/Types")

type Event = Types.Event
type Phase = Types.Phase

local Scenes = {}

-- Los 33 eventos de la arquitectura («Eventos»). Las escenas comunes duran entre 2 y 4 segundos;
-- CardPlayed usa además la rareza de la carta jugada, que se decide más abajo. PlayerArrested dura 15 s:
-- la llegada de las patrullas, los policías, la vuelta entera al mapa y la entrada en la cárcel. La partida
-- sigue al acabar. Es la única escena que pasa del tope de 10 s: excepción decidida por el responsable el
-- 2026-11-06 (plan 08).
local BASE_DURATION: { [string]: number } = {
	RoundStarted = 2.5,
	FinalRoundsStarted = 3,
	PerkDrafted = 2,
	DiceRolled = 2,
	TokenMoved = 2,
	PassedStart = 2,
	-- La compra y la subasta ganada se ven al instante (la escena aplica el resultado al empezar): una
	-- espera larga aquí era tiempo muerto en cada turno (responsable, 2026-11-06).
	PropertyBought = 1.2,
	RentPaid = 2.5,
	AuctionStarted = 3,
	AuctionWon = 1.8,
	AuctionNoSale = 2.5,
	BuildingChanged = 2,
	PropertyMortgaged = 2,
	PropertyUnmortgaged = 2,
	TradeCompleted = 2.5,
	PlayerArrested = 15,
	TribunalVerdict = 4,
	BankruptcyDeclared = 4,
	GhostActed = 2.5,
	GhostResurrected = 4,
	CardDrawn = 2.8,
	CardDiscarded = 2,
	CardPlayed = 3,
	CardBlocked = 2.5,
	HotZoneMoved = 3,
	BillboardResult = 4,
	DuelResolved = 4,
	PortalUsed = 4.8,
	MarketBought = 2.5,
	TaxPaid = 2.5,
	PactFormed = 3,
	PactEnded = 2.5,
	PactBroken = 3,
	CrownMoved = 3,
	FuryFilled = 3,
	GameEnded = 4,
}

-- Repetir el mismo tipo de evento en una partida acorta la escena: la segunda dura la mitad y las
-- siguientes se acercan al mínimo sin llegar nunca a cero.
local REPEAT_FACTOR = 0.5
local MIN_DURATION = 0.5
-- Duración de un evento que no está en la tabla. durationFor nunca devuelve 0, pero la prueba de
-- cobertura exige que baseDuration lo conozca: un evento nuevo sin escena rompe la puerta.
local UNKNOWN_DURATION = 2
-- Suelo propio de las escenas que se repiten en cada turno y que, más cortas, no se entienden: los dados
-- tienen que verse rodar y pararse en su cara.
local MIN_BY_EVENT: { [string]: number } = {
	DiceRolled = 1.4,
	-- El robo: la carta sale del mazo y su dueño la ve en grande antes de que vuele a la mano.
	CardDrawn = 2,
}

-- Cartas por rareza: comunes y raras de 2 a 4 s, legendarias hasta 10 s (ficha, «Las escenas no
-- pueden frenar la partida»).
local CARD_DURATION: { [string]: number } = {
	Common = 2.5,
	Rare = 4,
	Legendary = 8,
}

-- Escena propia de cada legendaria: las cinco se anuncian con su id, así que cada una tiene su
-- momento. La Revolución es la única que pasa de 10 s: la multitud y el blindado llegan de lejos y con
-- menos tiempo no se veía llegar ninguno de los dos.
local LEGENDARY_DURATION: { [string]: number } = {
	Hurricane = 10,
	WorldFlip = 9,
	Revolution = 13,
	Earthquake = 7,
	CrownStrike = 6,
}

-- Duración base de un evento, o nil si no tiene escena. La prueba de cobertura usa el nil para
-- detectar eventos nuevos sin escena; durationFor prefiere no romper la partida y usa un respaldo.
function Scenes.baseDuration(eventType: string): number?
	return BASE_DURATION[eventType]
end

-- Segundos de la carta jugada según su rareza. Una carta desconocida (o un CardPlayed sin cardId)
-- dura lo que la escena base del evento.
local function cardDuration(cardId: any): number
	if type(cardId) ~= "string" then
		return BASE_DURATION.CardPlayed
	end
	local legendary = LEGENDARY_DURATION[cardId]
	if legendary then
		return legendary
	end
	local card = Cards.byId[cardId]
	if not card then
		return BASE_DURATION.CardPlayed
	end
	-- Una rareza desconocida (dato roto o futura) no debe romper el latido: cae en la base de
	-- CardPlayed, igual que una carta desconocida.
	return CARD_DURATION[card.rarity] or BASE_DURATION.CardPlayed
end

-- Tope de un recorrido de ficha en la ciudad: sea cual sea la distancia, un turno no puede quedarse
-- esperando a que la ficha cruce el mapa. Lo aplica `CameraRules.rideSeconds`.
Scenes.maxRideSec = 4
-- Un recorrido dura según las casillas que cruza, con un mínimo para que dé tiempo a verlo. Con dos
-- dados son unos 2,8 s de media. Se ajusta a ojo y cuenta para el objetivo de 15 a 20 s por turno.
Scenes.rideSecPerSquare = 0.4
Scenes.minRideSec = 1.2

-- Duración en segundos de la escena de un evento. `seenCount` es cuántas veces se ha visto ese
-- tipo de evento en la partida: a partir de la segunda, la escena se acorta. El recorrido de una ficha
-- no: se repite en cada turno y es lo que el grupo mira, así que depende solo de la distancia. Un
-- TokenMoved sin ruta es un salto, no un recorrido, y se trata como cualquier otra escena.
function Scenes.durationFor(event: Event, seenCount: number): number
	if event.type == "TokenMoved" and type(event.path) == "table" and #event.path > 0 then
		return math.clamp(#event.path * Scenes.rideSecPerSquare, Scenes.minRideSec, Scenes.maxRideSec)
	end
	local base = if event.type == "CardPlayed"
		then cardDuration(event.cardId)
		else BASE_DURATION[event.type] or UNKNOWN_DURATION
	-- La detención tampoco se acorta: es un momento grande de la partida y se ve entera cada vez. El
	-- Portal tampoco: la ficha cruza la ciudad y, más rápido, el salto no se entiende.
	if event.type == "PlayerArrested" or event.type == "PortalUsed" then
		return base
	end
	local seen = if seenCount > 0 then math.floor(seenCount) else 0
	return math.max(MIN_BY_EVENT[event.type] or MIN_DURATION, base * REPEAT_FACTOR ^ seen)
end

-- Una escena que empieza tarde arranca en su punto; si le queda menos que esto, se omite: no da tiempo a
-- entenderla y solo retrasaría al cliente que va atrasado.
Scenes.skipBelowSec = 0.5

-- Todos los ids que pueden tener escena, ordenados: cada evento con duración y cada carta. La prueba de
-- `config/Scenes` exige que `client/scenes/SceneRegistry` tenga exactamente estos.
function Scenes.allIds(): { string }
	local ids: { string } = {}
	for eventType in BASE_DURATION do
		table.insert(ids, eventType)
	end
	for _, card in Cards.all do
		if BASE_DURATION[card.id] == nil then
			table.insert(ids, card.id)
		end
	end
	table.sort(ids)
	return ids
end

-- Cuántas variaciones tiene la escena de cada id. Lo que no está aquí tiene una sola. Las escenas
-- frecuentes ganan variaciones en la Tarea 7.
Scenes.variationCount = {
	-- Dados: lanzados desde la ficha o caídos del cielo.
	DiceRolled = 2,
	-- Renta: monedas o un billete gigante. Construir: con grúa o caído del cielo. Compra: dos carteles.
	RentPaid = 2,
	BuildingChanged = 2,
	PropertyBought = 2,
} :: { [string]: number }

-- Huella de un valor del evento: solo cuentan los datos simples, para que dos clientes con el mismo
-- evento lleguen al mismo número sin depender del orden de las tablas.
local function fingerprint(event: Event): string
	local keys: { string } = {}
	for key, value in event :: any do
		local kind = type(value)
		if type(key) == "string" and (kind == "string" or kind == "number" or kind == "boolean") then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	local parts: { string } = {}
	for _, key in keys do
		table.insert(parts, `{key}={tostring((event :: any)[key])}`)
	end
	return table.concat(parts, ";")
end

-- Variación de la escena de un evento, de 1 al número de variaciones de su id. Sale solo de los datos
-- del evento, sin azar ni reloj: así todo el grupo ve la misma.
function Scenes.variationFor(event: Event): number
	local id = if event.type == "CardPlayed" and type(event.cardId) == "string"
		then event.cardId
		else event.type
	local count = Scenes.variationCount[id] or 1
	if count <= 1 then
		return 1
	end
	local hash = 5381
	local text = fingerprint(event)
	for i = 1, #text do
		hash = (hash * 33 + string.byte(text, i)) % 2147483647
	end
	return hash % count + 1
end

-- Escena del Portal (`client/scenes/PortalJump`). Las fases son fracciones de la duración: se enciende
-- hasta `vanishAt`, se disuelve hasta `goneAt`, la cámara viaja hasta `appearAt`, reaparece hasta
-- `shownAt` y el brillo se apaga hasta el final. Color del Portal, anillo de luz y chispas.
Scenes.portal = {
	color = "#06B6D4",
	vanishAt = 0.22,
	goneAt = 0.36,
	appearAt = 0.62,
	shownAt = 0.76,
	ringStuds = 16,
	ringSec = 0.9,
	sparkRate = 40,
	sparkBurst = 30,
}

-- Escena del Ladrón de Escrituras: en qué parte de la escena cambia el dueño, y el sello que cae sobre el
-- edificio (altura sobre el solar, tamaño en píxeles, giro y caída).
Scenes.deedThief = {
	swapAt = 0.35,
	stampLift = 26,
	stampWidth = 260,
	stampHeight = 64,
	stampTilt = -6,
	stampFrom = 1.8,
	stampSec = 0.28,
}

-- Tiempo de decisión de una fase (R-P20). GameOver no tiene temporizador y el resto de fases usa
-- el valor común de Economy. Excepto subasta, Tribunal y reacción, que tienen el suyo.
function Scenes.decisionSeconds(phase: Phase): number
	if phase == "Auction" then
		return Economy.seconds.auction
	elseif phase == "Tribunal" then
		return Economy.seconds.tribunalVote
	elseif phase == "Reaction" then
		return Economy.seconds.reaction
	elseif phase == "GameOver" then
		return 0
	end
	return Economy.seconds.decision
end

-- Cada cuánto mira el latido del servidor si venció el plazo de decisión. Es el único número de
-- MatchService y vive aquí, con el resto de tiempos.
Scenes.heartbeatSec = 0.25

-- Cada cuánto mira el perfil de los jugadores si la partida ya terminó, para sumarles una partida.
Scenes.profilePollSec = 1

-- Espera tras la última escena antes de que el bot juegue el turno de un asiento sin humano
-- (R-P27). No se espera al plazo de decisión: un ausente no puede convertir cada turno en el plazo entero.
Scenes.botDelaySec = 0.6
-- En una subasta espera más: a 0,6 s por puja, el precio corría sin dar tiempo a una persona.
Scenes.botAuctionDelaySec = 1.5

function Scenes.botDelayFor(phase: Phase): number
	return if phase == "Auction" then Scenes.botAuctionDelaySec else Scenes.botDelaySec
end

-- Espera máxima, al arrancar el lugar de partida, a que llegue el grupo que viene por
-- teletransporte (R-P30). El servidor reservado empieza a contar cuando aparece el primer jugador
-- y arranca antes si ya están todos los que anuncia el dato de entrada.
Scenes.joinSec = 3

-- Espera máxima a un grupo que anunció su tamaño. Cada jugador tarda lo que tarde en cargar, y quien
-- llegara después del arranque se quedaría sin asiento.
Scenes.joinTimeoutSec = 30

-- Margen con el que el servidor acepta una acción antes de que acabe la escena (R-P39): cubre el
-- desfase entre el reloj del cliente y el suyo, sin dejar que un cliente corte la escena del grupo.
Scenes.actionGraceSec = 0.25

-- Ventana de la revancha: segundos que el grupo tiene para decidir si juega otra partida en el
-- mismo servidor cuando la anterior termina. La cuenta atrás empieza al acabar la escena final y la
-- cierra el servicio, no la regla (contracts.md, «Revancha»).
Scenes.rematchSec = 20

return Scenes

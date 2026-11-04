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
-- CardPlayed usa además la rareza de la carta jugada, que se decide más abajo.
local BASE_DURATION: { [string]: number } = {
	RoundStarted = 2.5,
	FinalRoundsStarted = 3,
	PerkDrafted = 2,
	DiceRolled = 2,
	TokenMoved = 2,
	PassedStart = 2,
	PropertyBought = 2.5,
	RentPaid = 2.5,
	AuctionStarted = 3,
	AuctionWon = 3,
	AuctionNoSale = 2.5,
	BuildingChanged = 2,
	TradeCompleted = 2.5,
	PlayerArrested = 3,
	TribunalVerdict = 4,
	BankruptcyDeclared = 4,
	GhostActed = 2.5,
	GhostResurrected = 4,
	CardDrawn = 2,
	CardDiscarded = 2,
	CardPlayed = 3,
	CardBlocked = 2.5,
	HotZoneMoved = 3,
	BillboardResult = 3,
	DuelResolved = 4,
	PortalUsed = 3,
	MarketBought = 2.5,
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

-- Cartas por rareza: comunes 2–4 s, raras hasta 6 s y legendarias hasta 10 s.
local CARD_DURATION: { [string]: number } = {
	Common = 2.5,
	Rare = 4.5,
	Legendary = 8,
}

-- Escena propia de cada legendaria: las cinco se anuncian con su id, así que cada una tiene su
-- momento. Ninguna pasa de 10 s.
local LEGENDARY_DURATION: { [string]: number } = {
	Hurricane = 10,
	WorldFlip = 9,
	Revolution = 8,
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

-- Duración en segundos de la escena de un evento. `seenCount` es cuántas veces se ha visto ese
-- tipo de evento en la partida: a partir de la segunda, la escena se acorta.
function Scenes.durationFor(event: Event, seenCount: number): number
	local base = if event.type == "CardPlayed"
		then cardDuration(event.cardId)
		else BASE_DURATION[event.type] or UNKNOWN_DURATION
	local seen = if seenCount > 0 then math.floor(seenCount) else 0
	return math.max(MIN_DURATION, base * REPEAT_FACTOR ^ seen)
end

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

-- Espera tras la última escena antes de que el bot juegue el turno de un asiento sin humano
-- (R-P27). No se espera al plazo de decisión: un ausente no puede convertir cada turno en 20 s.
Scenes.botDelaySec = 0.6

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

-- Tope de un recorrido de ficha en la ciudad: sea cual sea la distancia, un turno no puede quedarse
-- esperando a que la ficha cruce el mapa. Lo aplica `CameraRules.rideSeconds`.
Scenes.maxRideSec = 4

-- Ventana de la revancha: segundos que el grupo tiene para decidir si juega otra partida en el
-- mismo servidor cuando la anterior termina. La cuenta atrás empieza al acabar la escena final y la
-- cierra el servicio, no la regla (contracts.md, «Revancha»).
Scenes.rematchSec = 20

return Scenes

--!strict
-- Protocolo compartido por servidor y cliente: nombres de los remotos, forma de las acciones y
-- límite de frecuencia. Es lógica pura: no usa game, Instance, task ni ningún reloj; el instante
-- se pasa por parámetro para poder probarlo con Lune.
local Economy = require("../config/Economy")

export type Action = { type: string, [string]: any }
export type Limiter = {
	allow: (playerId: string, now: number) -> boolean,
}

local Protocol = {}

-- Los remotos de la subfase 04. El gateway del lugar de partida crea Action, Batch y Resync, y el
-- servicio de revancha crea Rematch; el del lobby crea los cuatro de party y cola. Notice nace en
-- los dos lugares: el lobby lo usa para sus avisos y la revancha para los suyos. El cliente del plan
-- 05 los busca por el mismo nombre. Los tres del contrato original no se tocan.
Protocol.REMOTES = {
	Action = "ActionRequest",
	Batch = "EventBatch",
	Resync = "ResyncRequest",
	-- Revancha (R-P14): el cliente manda si acepta jugar otra en el mismo servidor.
	Rematch = "RematchVoteRequest",
	-- Lobby (R-P29): peticiones del cliente y aviso del servidor.
	PartyCreate = "PartyCreateRequest",
	PartyJoin = "PartyJoinRequest",
	PartyStart = "PartyStartRequest",
	QueueJoin = "QueueJoinRequest",
	-- Modo solo: un jugador contra bots, con su propio modo y configuración.
	SoloStart = "SoloStartRequest",
	Notice = "LobbyNotice",
	-- Emotes del cliente (plan 05): no son una acción del motor, así que no pasan por la puerta de
	-- acciones. El servidor los reenvía a todo el grupo y el cliente los enseña sobre la ficha.
	Emote = "EmoteRequest",
	-- Elección de ficha (plan 07): tampoco es una acción del motor. El servidor solo arbitra que no se
	-- repita y avisa a todos del reparto.
	TokenChoice = "TokenChoiceRequest",
	TokenAssigned = "TokenAssigned",
	-- Retomar el asiento cuando lo juega un bot (plan 09): no lleva datos, el servidor sabe quién pide.
	Reclaim = "ReclaimSeatRequest",
}

-- Clases de aviso que viajan por `Notice` (R-P48). El cliente enruta por `kind`: un rechazo de acción es
-- un aviso breve de la barra y el resto se enseña en el panel de revancha. Los valores se escriben igual
-- en servidor y cliente, así que no hay cadenas sueltas.
Protocol.NOTICE_KINDS = {
	Info = "Info",
	Error = "Error",
	PartyCode = "PartyCode",
	ActionRejected = "ActionRejected",
}

-- Los emotes son pocos y fijos: un botón, un emote. La lista vive aquí para que cliente y servidor
-- acepten exactamente los mismos.
Protocol.EMOTES = { "😀", "😱", "🤑", "😡", "🤝", "🗡️" }

-- La ventana del limitador es un segundo por definición; el número de acciones vive en config.
local WINDOW_SECONDS = 1

-- Tipos de campo aceptados por la lista blanca de cada acción.
type FieldCheck = (value: any) -> boolean
type ActionSpec = {
	required: { string },
	fields: { [string]: FieldCheck },
}

local function isIdentifier(value: any): boolean
	return type(value) == "string" and #value > 0
end

local function isBoolean(value: any): boolean
	return type(value) == "boolean"
end

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value % 1 == 0 and value >= 1
end

-- Un importe de intercambio puede ser 0: una oferta puede dar solo dinero, solo casillas o
-- ambas cosas, y el motor exige que los dos importes existan.
local function isNonNegativeInteger(value: any): boolean
	return type(value) == "number" and value % 1 == 0 and value >= 0
end

local function oneOf(allowed: { string }): FieldCheck
	return function(value: any): boolean
		return type(value) == "string" and table.find(allowed, value) ~= nil
	end
end

-- Lista densa de índices de casilla: 1..n, todos enteros positivos. Sin # para no depender de
-- metatablas de un paquete de red.
local function isIndexList(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	local count = 0
	local highest = 0
	for key, index in value do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
			return false
		end
		if not isPositiveInteger(index) then
			return false
		end
		count += 1
		if key > highest then
			highest = key
		end
	end
	return count == highest
end

local DUEL_CHOICES = { "Rock", "Paper", "Scissors" }
local GHOST_KINDS = { "Sabotage", "Haunt" }
local DIE_NAMES = { "a", "b" }
local VERDICTS = { "Fine", "PayToPlayer", "SkipTurn" }

-- Oferta de intercambio: exactamente los cinco campos de Trade.TradeOffer, sin nada más.
local TRADE_OFFER_SPEC: ActionSpec = {
	required = { "toId", "giveCash", "wantCash", "giveSquares", "wantSquares" },
	fields = {
		toId = isIdentifier,
		giveCash = isNonNegativeInteger,
		wantCash = isNonNegativeInteger,
		giveSquares = isIndexList,
		wantSquares = isIndexList,
	},
}

local function matchesSpec(value: any, spec: ActionSpec): boolean
	if type(value) ~= "table" then
		return false
	end
	for key in value do
		if spec.fields[key] == nil then
			return false
		end
	end
	for _, key in spec.required do
		if value[key] == nil then
			return false
		end
	end
	for key, check in spec.fields do
		local field = value[key]
		if field ~= nil and not check(field) then
			return false
		end
	end
	return true
end

local function isTradeOffer(value: any): boolean
	return matchesSpec(value, TRADE_OFFER_SPEC)
end

-- Una entrada por acción de la arquitectura. `fields` es la lista blanca: una clave que no esté
-- aquí se rechaza, también `playerId` (el servidor usa el Player del remoto, nunca el del paquete).
local ACTION_SPECS: { [string]: ActionSpec } = {
	DraftPerk = {
		required = { "perkId" },
		fields = { perkId = isIdentifier },
	},
	Roll = { required = {}, fields = {} },
	RerollDie = {
		required = { "die" },
		fields = { die = oneOf(DIE_NAMES) },
	},
	Buy = { required = {}, fields = {} },
	DeclineBuy = { required = {}, fields = {} },
	Bid = {
		required = { "amount" },
		fields = { amount = isPositiveInteger },
	},
	PlayCard = {
		required = { "cardId" },
		fields = {
			cardId = isIdentifier,
			targetId = isIdentifier,
			zoneId = isIdentifier,
			index = isPositiveInteger,
			pactId = isIdentifier,
		},
	},
	React = {
		required = { "cardId" },
		fields = { cardId = isIdentifier, targetId = isIdentifier },
	},
	PassReaction = { required = {}, fields = {} },
	Build = {
		required = { "index" },
		fields = { index = isPositiveInteger },
	},
	SellBuilding = {
		required = { "index" },
		fields = { index = isPositiveInteger },
	},
	Mortgage = {
		required = { "index" },
		fields = { index = isPositiveInteger },
	},
	Unmortgage = {
		required = { "index" },
		fields = { index = isPositiveInteger },
	},
	ProposeTrade = {
		required = { "offer" },
		fields = { offer = isTradeOffer },
	},
	RespondTrade = {
		required = { "tradeId", "accept" },
		fields = { tradeId = isIdentifier, accept = isBoolean },
	},
	ProposePact = {
		required = { "toId", "rounds" },
		fields = { toId = isIdentifier, rounds = isPositiveInteger },
	},
	RespondPact = {
		required = { "pactId", "accept" },
		fields = { pactId = isIdentifier, accept = isBoolean },
	},
	BreakPact = {
		required = { "pactId" },
		fields = { pactId = isIdentifier },
	},
	TribunalVote = {
		required = { "verdict" },
		fields = { verdict = oneOf(VERDICTS), targetId = isIdentifier },
	},
	DuelChoice = {
		required = {},
		fields = { rivalId = isIdentifier, choice = oneOf(DUEL_CHOICES) },
	},
	MarketBuy = {
		required = { "cardId" },
		fields = { cardId = isIdentifier },
	},
	MarketSkip = { required = {}, fields = {} },
	GhostAct = {
		required = { "kind" },
		fields = { kind = oneOf(GHOST_KINDS), index = isPositiveInteger },
	},
	EndTurn = { required = {}, fields = {} },
}

-- Un código de party puede llegar con espacios (" ab3k9z "); la forma solo acota el tamaño para
-- que un paquete enorme no recorra tablas. La validez real la decide PartyCode.normalize en el
-- lobby, que es quien conoce el alfabeto.
local MAX_PARTY_CODE_LENGTH = 16

local function isPartyCode(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= MAX_PARTY_CODE_LENGTH
end

local END_MODES = { "Rounds", "Endless" }

-- Modo solo: el jugador más sus bots. Ocho asientos como mucho, así que de 1 a 7 bots.
Protocol.MAX_BOTS = 7

local function isBotCount(value: any): boolean
	return type(value) == "number" and value % 1 == 0 and value >= 1 and value <= Protocol.MAX_BOTS
end

-- Configuración de la partida privada: aquí solo la forma (pocas claves de texto con valores simples). Qué
-- valores valen lo decide `MatchSettings.normalize` en el servidor.
local MAX_SETTINGS_KEYS = 16

local function isSettings(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	local count = 0
	for key, item in value do
		count += 1
		if count > MAX_SETTINGS_KEYS or type(key) ~= "string" or #key > 32 then
			return false
		end
		local kind = type(item)
		if kind ~= "number" and kind ~= "boolean" and kind ~= "string" then
			return false
		end
		if kind == "string" and #item > 32 then
			return false
		end
	end
	return true
end

-- Peticiones del lobby (R-P29). Viven en Protocol, igual que las acciones de la partida, para que
-- el nombre y la forma tengan una sola fuente de verdad. El lobby no las valida con
-- Protocol.validate: un tipo de partida no debe colarse por el remoto del lobby ni al revés.
local LOBBY_SPECS: { [string]: ActionSpec } = {
	PartyCreate = { required = {}, fields = {} },
	PartyJoin = { required = { "code" }, fields = { code = isPartyCode } },
	PartyStart = { required = { "endMode" }, fields = { endMode = oneOf(END_MODES), settings = isSettings } },
	QueueJoin = { required = {}, fields = {} },
	SoloStart = {
		required = { "bots", "endMode" },
		fields = { bots = isBotCount, endMode = oneOf(END_MODES), settings = isSettings },
	},
}

-- Reglas de forma que cruzan dos campos: no son legalidad de fase, solo aseguran que la acción
-- lleva la información que su tipo necesita.
local function extraShapeReason(action: any): string?
	if action.type == "DuelChoice" then
		local hasRival = action.rivalId ~= nil
		local hasChoice = action.choice ~= nil
		if hasRival == hasChoice then
			return "DuelChoice necesita el rival o la jugada, pero no las dos cosas"
		end
	elseif action.type == "GhostAct" then
		if action.kind == "Haunt" and action.index == nil then
			return "GhostAct Haunt necesita una casilla"
		end
		if action.kind == "Sabotage" and action.index ~= nil then
			return "GhostAct Sabotage no lleva casilla"
		end
	elseif action.type == "TribunalVote" then
		if action.verdict == "PayToPlayer" and action.targetId == nil then
			return "TribunalVote PayToPlayer necesita un objetivo"
		end
		if action.verdict ~= "PayToPlayer" and action.targetId ~= nil then
			return "TribunalVote solo lleva objetivo con PayToPlayer"
		end
	end
	return nil
end

-- Valida la forma contra una tabla de especificaciones. `checkExtra` activa las reglas que cruzan
-- dos campos, que solo existen para las acciones de la partida.
local function validateWithSpecs(
	action: any,
	specs: { [string]: ActionSpec },
	checkExtra: boolean
): (boolean, string?)
	if type(action) ~= "table" then
		return false, "La acción no es una tabla"
	end
	local actionType = action.type
	if type(actionType) ~= "string" then
		return false, "La acción no tiene un tipo válido"
	end
	local spec = specs[actionType]
	if not spec then
		return false, `Acción desconocida: {actionType}`
	end
	for key in action do
		if key ~= "type" and spec.fields[key] == nil then
			return false, `Campo desconocido: {tostring(key)}`
		end
	end
	for _, key in spec.required do
		if action[key] == nil then
			return false, `Falta el campo {key}`
		end
	end
	for key, check in spec.fields do
		local value = action[key]
		if value ~= nil and not check(value) then
			return false, `El campo {key} no es válido`
		end
	end
	local extra = if checkExtra then extraShapeReason(action) else nil
	if extra then
		return false, extra
	end
	return true, nil
end

local function validateShape(action: any): (boolean, string?)
	return validateWithSpecs(action, ACTION_SPECS, true)
end

-- ¿La acción tiene la forma del contrato? Devuelve el motivo cuando no. No decide legalidad: la
-- fase, el turno y el efectivo siguen siendo de Engine.apply, para no duplicar reglas.
function Protocol.validate(action: any): (boolean, string?)
	return validateShape(action)
end

-- ¿La petición del lobby tiene la forma del contrato? Mismos mensajes que la puerta de partida.
function Protocol.validateLobby(action: any): (boolean, string?)
	return validateWithSpecs(action, LOBBY_SPECS, false)
end

-- ¿El paquete del remoto de revancha es un voto booleano? El paquete es el booleano a secas: la
-- identidad del votante sale del Player del remoto, nunca de un campo del paquete (contracts.md,
-- «Identidad»). Que el votante siga en la partida terminada lo decide RematchService.
function Protocol.validateRematch(vote: any): (boolean, string?)
	if type(vote) ~= "boolean" then
		return false, "El voto de revancha tiene que ser verdadero o falso"
	end
	return true, nil
end

-- ¿El paquete del remoto de emotes es uno de los emotes de la lista? Mismo criterio de forma que las
-- acciones: lo que no está en la lista no se reenvía a nadie.
function Protocol.validateEmote(emote: any): boolean
	if type(emote) ~= "string" then
		return false
	end
	return table.find(Protocol.EMOTES, emote) ~= nil
end

-- Id de ficha: minúsculas y guiones, como los del catálogo `Tokens` (food-truck, camion-helados).
-- El servidor comprueba además que exista; aquí solo se descarta basura.
function Protocol.validateTokenChoice(tokenId: any): boolean
	if type(tokenId) ~= "string" then
		return false
	end
	if #tokenId < 1 or #tokenId > 24 then
		return false
	end
	return string.match(tokenId, "^[a-z%-]+$") ~= nil
end

-- Limitador deslizante: guarda los instantes de las acciones aceptadas y descarta la que haría
-- pasar del ritmo permitido en los últimos WINDOW_SECONDS. Las descartadas no gastan cupo y la
-- ventana guarda como mucho ese ritmo de instantes por jugador. Sin `requestsPerSecond` usa el de
-- la partida (Economy.actionsPerSecond); el lobby pasa el suyo porque cada petición suya cuesta
-- mucho más que una acción.
function Protocol.newLimiter(requestsPerSecond: number?): Limiter
	local limit = requestsPerSecond or Economy.actionsPerSecond
	local accepted: { [string]: { number } } = {}
	return {
		allow = function(playerId: string, now: number): boolean
			local kept: { number } = {}
			local previous = accepted[playerId]
			if previous then
				for _, stamp in previous do
					if now - stamp < WINDOW_SECONDS then
						table.insert(kept, stamp)
					end
				end
			end
			if #kept >= limit then
				accepted[playerId] = kept
				return false
			end
			table.insert(kept, now)
			accepted[playerId] = kept
			return true
		end,
	}
end

return Protocol

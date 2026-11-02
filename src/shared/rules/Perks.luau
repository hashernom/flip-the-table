--!strict
-- Borrador de perks (fase PerkDraft): el reparto de la tabla «Momentos de la partida» y la
-- oferta de cada jugador. Los efectos viven en el módulo que ya tiene su sistema; aquí solo hay
-- reparto. El draft se abre al empezar la partida (State.create, R-P31) y al entrar en las rondas
-- de la tabla (Turn.next).
local Economy = require("../config/Economy")
local PerksConfig = require("../config/Perks")
local Rng = require("./Rng")
local Types = require("./Types")

type GameState = Types.GameState
type Player = Types.Player
type PlayerId = Types.PlayerId
type Event = Types.Event
type ApplyResult = Types.ApplyResult

-- Estado de paso del borrador: a quién le toca elegir y su oferta. `order` está en orden de
-- turno desde el jugador en turno y recortado a quien tiene perks disponibles.
export type Draft = {
	order: { PlayerId },
	index: number,
	offer: { string },
}

local Perks = {}

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
		error(`Perks: no existe el jugador {playerId}`, 3)
	end
	return player
end

-- pending es la tabla persistente que State.create siempre crea (R1).
local function pendingOf(state: GameState): any
	local pending = state.pending
	if not pending then
		error("Perks: el estado no tiene pending", 2)
	end
	return pending
end

local function append(events: { Event }, more: { Event })
	for _, event in more do
		table.insert(events, event)
	end
end

-- ¿El jugador tiene el perk? `player.perks` guarda ids del catálogo.
function Perks.has(player: Player, perkId: string): boolean
	return table.find(player.perks, perkId) ~= nil
end

-- Ronda del momento de draft: 1 al empezar la partida, 2 y 3 en la tabla de la arquitectura
-- (floor(N / 3) + 1 y floor(2N / 3) + 1 con tope de rondas; 6 y 12 en Sin Fin). nil si el
-- momento no existe para el modo.
function Perks.momentRound(state: GameState, moment: number): number?
	if moment < 1 or moment > 1 + #Economy.perks.endlessRounds then
		return nil
	end
	if moment == 1 then
		return 1
	end
	if state.endMode == "Endless" then
		return Economy.perks.endlessRounds[moment - 1]
	end
	local maxRounds = state.maxRounds
	if not maxRounds then
		return nil
	end
	return math.floor(maxRounds * (moment - 1) / Economy.perks.momentDivisor) + 1
end

-- Momento al que pertenece una ronda, o nil si esa ronda no abre ningún draft.
local function momentOfRound(state: GameState, round: number): number?
	for moment = 1, 1 + #Economy.perks.endlessRounds do
		if Perks.momentRound(state, moment) == round then
			return moment
		end
	end
	return nil
end

-- Jugadores que entran al borrador, en orden de turno desde el jugador en turno. Solo los
-- activos: un espectro no elige perks. Quien ya tiene el catálogo entero no tiene oferta.
local function draftOrder(state: GameState): { PlayerId }
	local order: { PlayerId } = {}
	local count = #state.players
	for step = 0, count - 1 do
		local player = state.players[(state.turnIndex - 1 + step) % count + 1]
		if player.status == "Active" and #player.perks < #PerksConfig.all then
			table.insert(order, player.id)
		end
	end
	return order
end

-- Oferta de un jugador: hasta Economy.perks.offerCount perks distintos del catálogo que aún no
-- tiene, elegidos con Rng. Si le quedan menos, se ofrecen todos; si no le queda ninguno, la
-- oferta está vacía y el borrador lo salta.
function Perks.offer(state: GameState, playerId: PlayerId): { string }
	local player = playerOf(state, playerId)
	local available: { string } = {}
	for _, perk in PerksConfig.all do
		if not Perks.has(player, perk.id) then
			table.insert(available, perk.id)
		end
	end
	local count = math.min(Economy.perks.offerCount, #available)
	local offer: { string } = {}
	if count == 0 then
		return offer
	end
	local shuffled = Rng.shuffle(state.rng, available)
	for index = 1, count do
		offer[index] = shuffled[index]
	end
	return offer
end

-- Borrador en curso, o nil.
function Perks.pendingDraft(state: GameState): Draft?
	local draft = pendingOf(state).draft
	if draft == nil then
		return nil
	end
	return draft :: Draft
end

-- Jugador al que le toca elegir, o nil si no hay borrador.
function Perks.currentDrafter(state: GameState): PlayerId?
	local draft = Perks.pendingDraft(state)
	if not draft then
		return nil
	end
	return draft.order[draft.index]
end

-- Cierra el borrador: el turno sigue en la fase de siempre.
local function closeDraft(state: GameState)
	pendingOf(state).draft = nil
	state.phase = "AwaitRoll"
end

-- Pasa al siguiente jugador del orden que pueda elegir y le prepara la oferta. Si no queda
-- ninguno, cierra el borrador. Devuelve true mientras siga abierto.
local function advanceDraft(state: GameState, draft: Draft): boolean
	while true do
		draft.index += 1
		local nextId = draft.order[draft.index]
		if not nextId then
			break
		end
		local nextPlayer = findPlayer(state, nextId)
		if nextPlayer and nextPlayer.status == "Active" then
			local offer = Perks.offer(state, nextId)
			if #offer > 0 then
				draft.offer = offer
				return true
			end
		end
	end
	closeDraft(state)
	return false
end

-- Abre el borrador del momento en curso, si toca. Lo llaman State.create al crear la partida
-- (ronda 1, R-P31) y Turn.next al entrar en una ronda de la tabla. No abre dos veces la misma
-- ronda ni pisa un borrador ya abierto; devuelve true si lo abrió.
function Perks.begin(state: GameState): boolean
	if state.phase == "GameOver" then
		return false
	end
	local pending = pendingOf(state)
	if pending.draft ~= nil or pending.draftRound == state.round then
		return false
	end
	if not momentOfRound(state, state.round) then
		return false
	end
	-- La marca se pone también cuando no hay nadie a quien ofrecer: el momento ya se resolvió.
	pending.draftRound = state.round
	local order = draftOrder(state)
	if #order == 0 then
		return false
	end
	pending.draft = { order = order, index = 1, offer = Perks.offer(state, order[1]) }
	state.phase = "PerkDraft"
	return true
end

-- Motivo por el que una elección no vale, o nil. No modifica el estado. Es la única regla,
-- compartida por Perks.draft y por la comprobación previa de Engine: solo elige el jugador al
-- que le toca y solo un perk de su oferta.
function Perks.draftReason(state: GameState, playerId: PlayerId, perkId: any): string?
	local draft = Perks.pendingDraft(state)
	if not draft then
		return "El borrador de perks no está abierto"
	end
	if type(perkId) ~= "string" then
		return "DraftPerk necesita el id del perk"
	end
	local player = findPlayer(state, playerId)
	if not player then
		return `El jugador {playerId} no está en la partida`
	end
	if player.status ~= "Active" then
		return "Solo los jugadores activos eligen perk"
	end
	if draft.order[draft.index] ~= playerId then
		return "No es tu turno de elegir perk"
	end
	if not table.find(draft.offer, perkId) then
		return `El perk {perkId} no está en la oferta`
	end
	return nil
end

-- Elige un perk de la oferta: lo añade al jugador, emite PerkDrafted y pasa el turno al
-- siguiente. La última elección cierra el borrador y devuelve la fase a AwaitRoll. Un rechazo
-- no toca nada.
function Perks.draft(state: GameState, playerId: PlayerId, perkId: string): ApplyResult
	local reason = Perks.draftReason(state, playerId, perkId)
	if reason then
		return { ok = false, error = reason }
	end
	local draft = Perks.pendingDraft(state)
	if not draft then
		error("Perks.draft: el borrador validado ya no existe", 2)
	end
	local player = playerOf(state, playerId)
	table.insert(player.perks, perkId)
	advanceDraft(state, draft)
	return { ok = true, events = { { type = "PerkDrafted", playerId = playerId, perkId = perkId } } }
end

-- Tiempo agotado: asigna el primer perk ofrecido al jugador al que le toca elegir, igual que una
-- elección suya. Si el jugador ya no puede elegir (abandonó a mitad), lo salta para que el reloj
-- nunca deje el borrador colgado. Devuelve los eventos de las elecciones aplicadas.
function Perks.timeout(state: GameState): { Event }
	local draft = Perks.pendingDraft(state)
	if not draft then
		return {}
	end
	local events: { Event } = {}
	while true do
		local drafterId = draft.order[draft.index]
		if not drafterId then
			closeDraft(state)
			return events
		end
		local perkId = draft.offer[1]
		if perkId then
			local result = Perks.draft(state, drafterId, perkId)
			if result.ok then
				append(events, result.events)
				return events
			end
		end
		if not advanceDraft(state, draft) then
			return events
		end
	end
end

return Perks

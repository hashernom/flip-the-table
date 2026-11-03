--!strict
-- Simulación determinista de una partida completa. Vive fuera de `src/shared/rules`: usa el bot
-- y el tiempo agotado como lo haría el servidor y comprueba los invariantes después de cada
-- acción resuelta. No usa relojes ni azar propio: todo sale de la semilla del estado.
--
-- Desde la Tarea 10 dirige todas las fases de la fase 03: el borrador lo eligen los jugadores (no
-- el reloj), las ofertas de pacto las responden sus destinatarios, y Reacción, Mercado, Duelo y
-- Tribunal preguntan a quien puede decidir en cada una (no solo al jugador en turno).
local Bot = require("../src/shared/rules/Bot")
local Economy = require("../src/shared/config/Economy")
local Engine = require("../src/shared/rules/Engine")
local Score = require("../src/shared/rules/Score")
local State = require("../src/shared/rules/State")
local Types = require("../src/shared/rules/Types")

type GameState = Types.GameState
type PlayerId = Types.PlayerId
type Player = Types.Player
type Event = Types.Event
type Action = Types.Action
type EndMode = Types.EndMode

export type PlayOptions = {
	players: number,
	seed: number,
	idle: boolean?,
	endMode: EndMode?,
}

export type SimResult = {
	finished: boolean,
	turns: number,
	leaderAtHalf: PlayerId,
	-- ¿El jugador que lideraba a mitad de partida ganó al final?
	leaderAtHalfWon: boolean,
	winner: PlayerId,
	events: { [string]: number },
	-- Usos por id de carta. Cuenta PlayCard y también las reacciones (Escudo y Renta Rebotada).
	cardsPlayed: { [string]: number },
	-- Perks repartidos por id. Sale de los eventos PerkDrafted, también los del reloj.
	perksDrafted: { [string]: number },
}

-- Tope de seguridad: solo detecta una partida que no termina. Las partidas Sin Fin legítimas
-- llegan a decenas de miles de acciones (rondas con rentas pequeñas), así que queda muy por
-- encima. Nunca es una forma de terminar la partida: al alcanzarlo se devuelve finished = false.
local MAX_ACTIONS = 1000000

local Sim = {}

-- Los jugadores nunca se añaden ni se quitan de la partida: el mapa se construye una vez y sus
-- valores se leen siempre actualizados porque son las mismas tablas que muta el motor.
local function playersById(state: GameState): { [PlayerId]: Player }
	local byId: { [PlayerId]: Player } = {}
	for _, player in state.players do
		byId[player.id] = player
	end
	return byId
end

-- Jugador por id, o nil. A diferencia de playersById no exige que exista: las ofertas y las
-- fases pueden apuntar a un jugador que ya no está en la partida.
local function playerOf(state: GameState, playerId: PlayerId): Player?
	for _, player in state.players do
		if player.id == playerId then
			return player
		end
	end
	return nil
end

-- Invariantes que deben cumplirse tras cualquier acción resuelta: nadie en negativo, ningún
-- espectro con propiedades y todos los niveles dentro del máximo de Economy.
local function checkState(state: GameState, byId: { [PlayerId]: Player }, context: string, detail: string)
	for _, player in state.players do
		if player.cash < 0 then
			error(
				`Simulación inválida ({context}; {detail}): el jugador {player.id} tiene efectivo negativo ({player.cash})`,
				2
			)
		end
	end
	for index, property in state.properties do
		local level = property.level
		if level < 0 or level > Economy.maxBuildingLevel or level % 1 ~= 0 then
			error(
				`Simulación inválida ({context}; {detail}): la casilla {index} tiene el nivel {level} fuera de 0..{Economy.maxBuildingLevel}`,
				2
			)
		end
		local ownerId = property.ownerId
		if ownerId ~= nil then
			local owner: Player? = byId[ownerId]
			if owner ~= nil and owner.status == "Ghost" then
				error(
					`Simulación inválida ({context}; {detail}): la casilla {index} pertenece al espectro {ownerId}`,
					2
				)
			end
		end
	end
end

-- En cada límite de turno, además, toda casilla con dueño debe tenerlo presente y activo.
local function checkTurnBoundary(
	state: GameState,
	byId: { [PlayerId]: Player },
	context: string,
	detail: string
)
	for index, property in state.properties do
		local ownerId = property.ownerId
		if ownerId ~= nil then
			local owner: Player? = byId[ownerId]
			if owner == nil then
				error(
					`Simulación inválida ({context}; {detail}): la casilla {index} pertenece a un jugador que no existe ({ownerId})`,
					2
				)
			elseif owner.status ~= "Active" then
				error(
					`Simulación inválida ({context}; {detail}): la casilla {index} pertenece a {ownerId}, que no está activo ({owner.status})`,
					2
				)
			end
		end
	end
end

-- Juega una partida completa de principio a fin y devuelve su resumen. Un invariante roto lanza
-- un error con jugadores, semilla y modo: la prueba falla y el caso se puede reproducir.
function Sim.play(opts: PlayOptions): SimResult
	local mode: EndMode = opts.endMode or "Rounds"
	local playerIds: { PlayerId } = {}
	for index = 1, opts.players do
		playerIds[index] = `P{index}`
	end
	local state = State.create({ playerIds = playerIds, seed = opts.seed, endMode = mode })
	local byId = playersById(state)

	local context = `jugadores={table.concat(playerIds, ",")}, semilla={opts.seed}, modo={mode}`
	local counts: { [string]: number } = {}
	local cardsPlayed: { [string]: number } = {}
	local perksDrafted: { [string]: number } = {}
	-- Líder al empezar cada ronda: la clasificación completa, igual que la Corona.
	local leaders: { [number]: PlayerId } = {}
	local maxRound = 1
	local turns = 0
	local actions = 0
	local winner: PlayerId? = nil

	-- Punto medio de las rondas jugadas: la última ronda que llegó a empezar. Si la partida
	-- murió en la ronda 1, no hay ronda que consultar y decide la clasificación final.
	local function leaderAtHalf(): PlayerId
		return leaders[math.ceil(maxRound / 2)] or Score.ranking(state)[1]
	end

	local function finalWinner(): PlayerId
		return winner or Score.ranking(state)[1]
	end

	local function unfinished(): SimResult
		local half = leaderAtHalf()
		local final = finalWinner()
		return {
			finished = false,
			turns = turns,
			leaderAtHalf = half,
			leaderAtHalfWon = final == half,
			winner = final,
			events = counts,
			cardsPlayed = cardsPlayed,
			perksDrafted = perksDrafted,
		}
	end

	local function record(events: { Event })
		for _, event in events do
			counts[event.type] = (counts[event.type] or 0) + 1
			if event.type == "RoundStarted" then
				local round: number = event.round
				maxRound = math.max(maxRound, round)
				leaders[round] = Score.ranking(state)[1]
			elseif event.type == "GameEnded" then
				winner = event.winnerId
			elseif event.type == "PerkDrafted" then
				local perkId: string = event.perkId
				perksDrafted[perkId] = (perksDrafted[perkId] or 0) + 1
			end
		end
	end

	-- Cuenta el uso de una carta. PlayCard gasta una carta de la mano y React gasta la carta de
	-- reacción; las dos son usos reales para el informe de cobertura.
	local function recordCardUse(action: Action)
		if action.type ~= "PlayCard" and action.type ~= "React" then
			return
		end
		local cardId = action.cardId
		if type(cardId) ~= "string" then
			return
		end
		cardsPlayed[cardId] = (cardsPlayed[cardId] or 0) + 1
	end

	-- Resuelve una acción o un tiempo agotado: cuenta, anota eventos y comprueba invariantes.
	local function resolved(events: { Event }, detail: string, endedTurn: boolean, action: Action?)
		actions += 1
		if action then
			recordCardUse(action)
		end
		record(events)
		checkState(state, byId, context, detail)
		if endedTurn then
			turns += 1
			checkTurnBoundary(state, byId, context, detail)
		end
	end

	-- Jugador al que le toca decidir según la fase. La mayoría de las fases son del jugador en
	-- turno, pero el borrador rota, la reacción interrumpe a otro, el Mercado es de quien cayó en
	-- él, el Duelo pregunta a sus dos participantes y el Tribunal a todos los votantes.
	local function actorForPhase(): PlayerId?
		local phase = state.phase
		local pending = state.pending
		if phase == "Reaction" then
			local reaction = pending and pending.reaction
			return if reaction then reaction.eligibleId else nil
		elseif phase == "Market" then
			local market = pending and pending.market
			return if market then market.playerId else nil
		elseif phase == "Duel" then
			local duel = pending and pending.duel
			if not duel then
				return nil
			end
			if duel.rivalId == nil then
				return duel.challengerId
			end
			for _, player in state.players do
				local participates = player.id == duel.challengerId or player.id == duel.rivalId
				if participates and player.status == "Active" and duel.picks[player.id] == nil then
					return player.id
				end
			end
			return nil
		elseif phase == "Tribunal" then
			local tribunal = pending and pending.tribunal
			if not tribunal then
				return nil
			end
			for _, player in state.players do
				local canVote = player.status == "Active"
					and player.id ~= tribunal.accusedId
					and tribunal.votes[player.id] == nil
				if canVote then
					return player.id
				end
			end
			return nil
		elseif phase == "PerkDraft" then
			local draft = pending and pending.draft
			return if draft then draft.order[draft.index] else nil
		end
		local current = state.players[state.turnIndex]
		return if current then current.id else nil
	end

	-- Respuesta a las ofertas de pacto vivas. El destinatario puede responder sin estar en turno
	-- (Pact lo permite), así que la simulación se las pregunta antes de la acción del turno. Solo
	-- hay ofertas durante las fases de turno y caducan al terminar el turno (R-P44).
	local function respondPactOffers(): (boolean, { Event })
		local phase = state.phase
		if phase ~= "AwaitRoll" and phase ~= "AwaitBuy" and phase ~= "AwaitEnd" then
			return false, {}
		end
		local pending = state.pending
		local offers = pending and pending.pactOffers
		if not offers then
			return false, {}
		end
		for _, offer in offers do
			local recipient = playerOf(state, offer.toId)
			if recipient and recipient.status == "Active" then
				local action = Bot.choose(state, recipient.id)
				if action ~= nil and action.type == "RespondPact" then
					local result = Engine.apply(state, recipient.id, action)
					if not result.ok then
						error(
							`Simulación inválida ({context}): el motor rechazó la respuesta de pacto de {recipient.id} que el bot dio por legal: {result.error}`,
							2
						)
					end
					return true, result.events
				end
			end
		end
		return false, {}
	end

	while state.phase ~= "GameOver" do
		if actions >= MAX_ACTIONS then
			return unfinished()
		end
		local phase = state.phase
		if opts.idle then
			-- Sin decisiones: todo lo resuelve el tiempo agotado, también el cierre de subasta.
			local events = Engine.timeout(state)
			resolved(events, `tiempo agotado en {phase}`, phase == "AwaitEnd" or phase == "GhostTurn")
		elseif phase == "Auction" then
			-- La subasta se juega aparte del turno: cada pasada pregunta a todos los activos y
			-- una pasada entera sin pujas la cierra el tiempo agotado.
			local open = true
			while open do
				if actions >= MAX_ACTIONS then
					return unfinished()
				end
				local anyBid = false
				for _, player in state.players do
					if player.status == "Active" then
						local action = Bot.choose(state, player.id)
						if action ~= nil and action.type == "Bid" then
							local result = Engine.apply(state, player.id, action)
							if not result.ok then
								error(
									`Simulación inválida ({context}): el motor rechazó la puja de {player.id} que el bot dio por legal: {result.error}`,
									2
								)
							end
							anyBid = true
							resolved(result.events, `puja de {player.id} en subasta`, false, action)
						end
					end
				end
				if not anyBid then
					local events = Engine.timeout(state)
					resolved(events, "cierre de subasta", false)
					open = false
				end
			end
		else
			local responded, pactEvents = respondPactOffers()
			if responded then
				resolved(pactEvents, "respuesta de pacto", false)
			else
				local actor = actorForPhase()
				if actor == nil then
					local events = Engine.timeout(state)
					resolved(events, `tiempo agotado en {phase}`, phase == "AwaitEnd" or phase == "GhostTurn")
				else
					local action = Bot.choose(state, actor)
					if action ~= nil then
						local result = Engine.apply(state, actor, action)
						if not result.ok then
							error(
								`Simulación inválida ({context}): el motor rechazó la acción {action.type} de {actor} que el bot dio por legal: {result.error}`,
								2
							)
						end
						-- GhostAct cierra el turno igual que EndTurn (R-P43): cuenta como límite.
						local endedTurn = action.type == "EndTurn" or action.type == "GhostAct"
						resolved(result.events, `{action.type} de {actor}`, endedTurn, action)
					else
						local events = Engine.timeout(state)
						resolved(
							events,
							`tiempo agotado en {phase}`,
							phase == "AwaitEnd" or phase == "GhostTurn"
						)
					end
				end
			end
		end
	end

	if winner == nil then
		error(`Simulación inválida ({context}): la partida terminó en GameOver sin emitir GameEnded`, 2)
	end
	local half = leaderAtHalf()
	local final = finalWinner()
	return {
		finished = true,
		turns = turns,
		leaderAtHalf = half,
		leaderAtHalfWon = final == half,
		winner = final,
		events = counts,
		cardsPlayed = cardsPlayed,
		perksDrafted = perksDrafted,
	}
end

return Sim

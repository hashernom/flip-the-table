--!strict
-- Simulación determinista de una partida completa. Vive fuera de `src/shared/rules`: usa el bot
-- y el tiempo agotado como lo haría el servidor y comprueba los invariantes después de cada
-- acción resuelta. No usa relojes ni azar propio: todo sale de la semilla del estado.
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
	winner: PlayerId,
	events: { [string]: number },
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

	local function unfinished(): SimResult
		return {
			finished = false,
			turns = turns,
			leaderAtHalf = leaderAtHalf(),
			winner = winner or Score.ranking(state)[1],
			events = counts,
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
			end
		end
	end

	-- Resuelve una acción o un tiempo agotado: cuenta, anota eventos y comprueba invariantes.
	local function resolved(events: { Event }, detail: string, endedTurn: boolean)
		actions += 1
		record(events)
		checkState(state, byId, context, detail)
		if endedTurn then
			turns += 1
			checkTurnBoundary(state, byId, context, detail)
		end
	end

	while state.phase ~= "GameOver" do
		if actions >= MAX_ACTIONS then
			return unfinished()
		end
		local phase = state.phase
		if opts.idle then
			-- Sin decisiones: todo lo resuelve el tiempo agotado, también el cierre de subasta.
			local events = Engine.timeout(state)
			resolved(events, `tiempo agotado en {phase}`, phase == "AwaitEnd")
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
							resolved(result.events, `puja de {player.id} en subasta`, false)
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
			local actor = state.players[state.turnIndex].id
			local action = Bot.choose(state, actor)
			if action ~= nil then
				local result = Engine.apply(state, actor, action)
				if not result.ok then
					error(
						`Simulación inválida ({context}): el motor rechazó la acción {action.type} de {actor} que el bot dio por legal: {result.error}`,
						2
					)
				end
				resolved(result.events, `{action.type} de {actor}`, action.type == "EndTurn")
			else
				local events = Engine.timeout(state)
				resolved(events, `tiempo agotado en {phase}`, phase == "AwaitEnd")
			end
		end
	end

	if winner == nil then
		error(`Simulación inválida ({context}): la partida terminó en GameOver sin emitir GameEnded`, 2)
	end
	return {
		finished = true,
		turns = turns,
		leaderAtHalf = leaderAtHalf(),
		winner = winner or Score.ranking(state)[1],
		events = counts,
	}
end

return Sim

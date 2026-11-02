--!strict
-- Crea el estado inicial de una partida. El orden de turnos se decide con la semilla.
local Boards = require("../config/Boards")
local Economy = require("../config/Economy")
local Rng = require("./Rng")
local Score = require("./Score")
local Types = require("./Types")

export type CreateOptions = {
	playerIds: { Types.PlayerId },
	seed: number,
	endMode: Types.EndMode?,
}

local State = {}

-- Rounds por defecto. Cualquier otro texto llegaría de fuera (config o red) y debe fallar claro.
local function endModeOf(endMode: Types.EndMode?): Types.EndMode
	if endMode == nil or endMode == "Rounds" then
		return "Rounds"
	elseif endMode == "Endless" then
		return "Endless"
	end
	error(`State.create: el modo de partida "{endMode}" no existe; usa "Rounds" o "Endless"`, 3)
end

local function newPlayer(id: Types.PlayerId): Types.Player
	return {
		id = id,
		isBot = false,
		status = "Active",
		cash = Economy.startingCash,
		position = 1,
		hand = {},
		perks = {},
		fury = 0,
		sabotages = 0,
		skipTurns = 0,
	}
end

-- Toda propiedad nace libre y sin edificios.
local function newProperties(board: Types.Board): { [number]: Types.PropertyState }
	local properties: { [number]: Types.PropertyState } = {}
	for _, square in board.squares do
		if square.kind == "Property" then
			properties[square.index] = { level = 0 }
		end
	end
	return properties
end

-- Un id repetido rompería las estadísticas y la búsqueda de jugadores sin avisar.
local function checkUniqueIds(playerIds: { Types.PlayerId })
	local seen: { [Types.PlayerId]: boolean } = {}
	for _, id in playerIds do
		if seen[id] then
			error(`State.create: el jugador {id} está repetido`, 3)
		end
		seen[id] = true
	end
end

function State.create(opts: CreateOptions): Types.GameState
	-- Boards.forPlayerCount rechaza menos de 2 o más de 8 jugadores.
	-- La anotación evita que Luau ensanche la unión de literales al inferir la local.
	local sizeId: Types.SizeId = Boards.forPlayerCount(#opts.playerIds)
	checkUniqueIds(opts.playerIds)
	local endMode: Types.EndMode = endModeOf(opts.endMode)

	local board = Boards.get(sizeId)
	local rng = Rng.new(opts.seed)
	-- El orden barajado es el orden de turnos: state.players lo conserva.
	local order = Rng.shuffle(rng, opts.playerIds)

	local players: { Types.Player } = {}
	local stats: Types.MatchStats = {}
	for index, id in order do
		players[index] = newPlayer(id)
		stats[id] = {}
	end

	local state: Types.GameState = {
		rng = rng,
		sizeId = sizeId,
		board = board,
		players = players,
		turnIndex = 1,
		endMode = endMode,
		round = 1,
		-- En Sin Fin no hay tope: la partida solo acaba con un único jugador activo.
		maxRounds = if endMode == "Rounds" then Economy.rounds[sizeId] else nil,
		phase = "AwaitRoll",
		-- Tabla persistente: las fases escriben sus claves, nunca la reemplazan.
		pending = { trades = {} },
		properties = newProperties(board),
		pacts = {},
		modifiers = {},
		hotZoneId = nil,
		lastLegendaryRound = nil,
		stats = stats,
	}
	-- R4/R25: la ronda 1 ya necesita portador de la Corona. En la creación todos están
	-- Active, así que el primero de la clasificación es el primer activo.
	local pending = state.pending
	if not pending then
		error("State.create: el estado no tiene pending", 2)
	end
	pending.crownId = Score.ranking(state)[1]
	return state
end

return State

--!strict
-- Crea el estado inicial de una partida. El orden de turnos se decide con la semilla.
local Boards = require("../config/Boards")
local Economy = require("../config/Economy")
local Rng = require("./Rng")
local Types = require("./Types")

export type CreateOptions = {
	playerIds: { Types.PlayerId },
	seed: number,
}

local State = {}

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

	return {
		rng = rng,
		sizeId = sizeId,
		board = board,
		players = players,
		turnIndex = 1,
		round = 1,
		maxRounds = Economy.rounds[sizeId],
		phase = "AwaitRoll",
		-- Tabla persistente: las fases escriben sus claves, nunca la reemplazan.
		pending = { trades = {} },
		properties = newProperties(board),
		pacts = {},
		modifiers = {},
		hotZoneId = nil,
		lastLegendaryRound = nil,
		hurricaneUsed = false,
		stats = stats,
	}
end

return State

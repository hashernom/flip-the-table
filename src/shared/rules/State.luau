--!strict
-- Crea el estado inicial de una partida. El orden de turnos se decide con la semilla.
local Boards = require("../config/Boards")
local Economy = require("../config/Economy")
local HotZone = require("./HotZone")
local MatchSettings = require("../config/MatchSettings")
local Perks = require("./Perks")
local Rng = require("./Rng")
local Score = require("./Score")
local Types = require("./Types")

export type CreateOptions = {
	playerIds: { Types.PlayerId },
	seed: number,
	endMode: Types.EndMode?,
	-- Configuración de la partida privada; se normaliza, así que un dato roto vuelve a la de por defecto.
	settings: any?,
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

local function newPlayer(id: Types.PlayerId, startingCash: number): Types.Player
	return {
		id = id,
		isBot = false,
		status = "Active",
		cash = startingCash,
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
	local settings = MatchSettings.normalize(opts.settings)

	local board = Boards.get(sizeId)
	local rng = Rng.new(opts.seed)
	-- El orden barajado es el orden de turnos: state.players lo conserva.
	local order = Rng.shuffle(rng, opts.playerIds)

	local players: { Types.Player } = {}
	local stats: Types.MatchStats = {}
	local perkUses: { [Types.PlayerId]: { [string]: number } } = {}
	for index, id in order do
		players[index] = newPlayer(id, settings.startingCash)
		stats[id] = {}
		perkUses[id] = {}
	end

	local state: Types.GameState = {
		rng = rng,
		sizeId = sizeId,
		board = board,
		players = players,
		turnIndex = 1,
		endMode = endMode,
		settings = settings,
		round = 1,
		-- En Sin Fin no hay tope: la partida solo acaba con un único jugador activo.
		maxRounds = if endMode == "Rounds"
			then MatchSettings.maxRounds(Economy.rounds[sizeId], settings)
			else nil,
		phase = "PerkDraft",
		-- Tabla persistente: las fases escriben sus claves, nunca la reemplazan. Las listas de
		-- ofertas de intercambio y de pacto nacen vacías; sus secuencias de id se crean al primer
		-- uso.
		pending = { trades = {}, pactOffers = {} },
		properties = newProperties(board),
		pacts = {},
		modifiers = {},
		hotZoneId = nil,
		lastLegendaryRound = nil,
		stats = stats,
		perkUses = perkUses,
	}
	-- R4/R25: la ronda 1 ya necesita portador de la Corona. En la creación todos están
	-- Active, así que el primero de la clasificación es el primer activo.
	local pending = state.pending
	if not pending then
		error("State.create: el estado no tiene pending", 2)
	end
	pending.crownId = Score.ranking(state)[1]
	-- R-P31: la partida empieza en el borrador de perks. Nadie tiene habilidades todavía y el
	-- primer draft queda abierto en orden de turno con su oferta. No es opcional: sin borrador, la
	-- fase PerkDraft se quedaría sin contenido y nadie podría actuar.
	-- Sin perks (configuración de la partida), se empieza a tirar directamente.
	if not settings.perks then
		state.phase = "AwaitRoll"
	elseif not Perks.begin(state) then
		error("State.create: la partida debe empezar con el borrador de perks", 2)
	end
	-- R-P40: la ronda 1 abre con Zona Caliente, igual que el borrador. State.create devuelve
	-- solo el estado y el arranque de la partida no emite eventos de ronda, así que el
	-- HotZoneMoved de esta primera elección no viaja en ningún arreglo: la zona queda en el
	-- estado y el cliente la lee de ahí.
	-- Sin Zona Caliente no hay zona elegida, y Turn no la mueve nunca (no hay nada que mover).
	if settings.hotZone then
		HotZone.begin(state)
	end
	return state
end

return State

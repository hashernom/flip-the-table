--!strict
-- Utilidades de las pruebas. Colocan el estado en la situación que cada prueba necesita.
local Board = require("../src/shared/rules/Board")
local Rng = require("../src/shared/rules/Rng")
local State = require("../src/shared/rules/State")
local Types = require("../src/shared/rules/Types")

export type GameOptions = {
	players: number,
	seed: number?,
}

local Fixtures = {}

local function playerOf(state: Types.GameState, playerId: Types.PlayerId): Types.Player
	for _, player in state.players do
		if player.id == playerId then
			return player
		end
	end
	error(`Fixtures: no existe el jugador {playerId}`, 3)
end

function Fixtures.game(opts: GameOptions): Types.GameState
	local playerIds: { Types.PlayerId } = {}
	for index = 1, opts.players do
		playerIds[index] = `P{index}`
	end
	return State.create({ playerIds = playerIds, seed = opts.seed or opts.players })
end

-- Fija la próxima tirada sin tocar el resto del generador.
function Fixtures.dice(state: Types.GameState, a: number, b: number)
	Rng.force(state.rng, { a, b })
end

-- Mueve la ficha sin pasar por la Salida ni cobrar nada.
function Fixtures.placeOn(state: Types.GameState, playerId: Types.PlayerId, index: number)
	local player = playerOf(state, playerId)
	player.position = Board.square(state, index).index
end

-- Da una propiedad sin cobrarla ni entregar efectivo.
function Fixtures.give(state: Types.GameState, playerId: Types.PlayerId, index: number)
	playerOf(state, playerId)
	Board.square(state, index)
	local property = state.properties[index]
	if not property then
		error(`Fixtures.give: la casilla {index} no es una propiedad`, 2)
	end
	property.ownerId = playerId
end

function Fixtures.squareOf(state: Types.GameState, kind: Types.SquareKind): number
	for _, square in state.board.squares do
		if square.kind == kind then
			return square.index
		end
	end
	error(`Fixtures.squareOf: el tablero no tiene ninguna casilla {kind}`, 2)
end

function Fixtures.hand(state: Types.GameState, playerId: Types.PlayerId, cardId: string)
	table.insert(playerOf(state, playerId).hand, cardId)
end

function Fixtures.turnOf(state: Types.GameState, playerId: Types.PlayerId)
	for index, player in state.players do
		if player.id == playerId then
			state.turnIndex = index
			return
		end
	end
	error(`Fixtures.turnOf: no existe el jugador {playerId}`, 2)
end

return Fixtures

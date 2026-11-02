--!strict
-- Zona Caliente: una zona del tablero cuyas rentas se duplican y que cambia cada
-- Economy.hotZoneInterval rondas, al empezar las rondas 1, 4, 7… La ronda 1 la elige State.create
-- al crear la partida (R-P40, igual que abre el borrador de perks); Turn.next mueve la zona al
-- empezar las rondas siguientes de la tabla (4, 7, 10…).
local Economy = require("../config/Economy")
local Rng = require("./Rng")
local Types = require("./Types")

type GameState = Types.GameState
type Event = Types.Event

local HotZone = {}

-- Rondas de la tabla de la ficha (1, 4, 7…): la primera de cada tramo de hotZoneInterval.
function HotZone.isMoveRound(_state: GameState, round: number): boolean
	return (round - 1) % Economy.hotZoneInterval == 0
end

-- Elige la zona con Rng entre state.board.zoneOrder, nunca la anterior, y anuncia el cambio.
-- `from` es nil en la primera elección de la partida.
function HotZone.move(state: GameState): { Event }
	local from = state.hotZoneId
	local candidates: { string } = {}
	for _, zoneId in state.board.zoneOrder do
		if zoneId ~= from then
			table.insert(candidates, zoneId)
		end
	end
	-- El catálogo no tiene tableros de una sola zona (el más pequeño tiene 6). Si llegara uno,
	-- repetir la zona es preferible a romper la partida.
	local pool = if #candidates > 0 then candidates else state.board.zoneOrder
	if #pool == 0 then
		return {}
	end
	local to = Rng.pick(state.rng, pool)
	state.hotZoneId = to
	return { { type = "HotZoneMoved", from = from, to = to } }
end

-- Zona inicial de la partida. La llama State.create al abrir la ronda 1 (R-P40) y es
-- idempotente: con una zona ya elegida no hace nada, así el arranque puede llamarla siempre.
function HotZone.begin(state: GameState): { Event }
	if state.hotZoneId ~= nil then
		return {}
	end
	return HotZone.move(state)
end

return HotZone

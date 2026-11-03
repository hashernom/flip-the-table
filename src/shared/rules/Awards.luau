--!strict
-- Premios del final (Tarea 10): títulos del podio calculados con los contadores de la partida.
-- Cada premio se entrega al jugador con el contador más alto; si ese máximo es 0 no hay datos y
-- el premio no se entrega. Los empates los resuelve el orden de Score.ranking: patrimonio
-- descendente, efectivo descendente y posición inicial ascendente, un orden total y determinista.
--
-- Los contadores son los que ya acumulaban las tareas anteriores:
--   * MostTreacherous (Mayor Traidor)  → stats.pactsBroken (pactos rotos).
--   * BestComeback (Mejor Remontada)   → stats.comebackRounds (rondas como espectro antes de
--     resucitar; Comeback las guarda al resucitar).
--   * VictimOfTheNight (Víctima de la Noche) → stats.rentsPaid (rentas pagadas).
-- No se filtra por estado: el premio es un recuento de lo que pasó en la partida y un espectro o
-- un jugador que se fue sigue teniendo su historial en state.stats.
local Score = require("./Score")
local Types = require("./Types")

type GameState = Types.GameState
type PlayerId = Types.PlayerId

export type Award = {
	id: string,
	playerId: PlayerId,
}

type AwardDef = {
	id: string,
	stat: string,
}

-- Orden de entrega del podio, el de la ficha: traidor, remontada y víctima.
local AWARDS: { AwardDef } = {
	{ id = "MostTreacherous", stat = "pactsBroken" },
	{ id = "BestComeback", stat = "comebackRounds" },
	{ id = "VictimOfTheNight", stat = "rentsPaid" },
}

local Awards = {}

-- Devuelve un premio por cada contador con datos, en el orden de AWARDS. La lista puede estar
-- vacía (partida sin traiciones, remontadas ni rentas) y un mismo jugador puede llevarse varios.
function Awards.compute(state: GameState): { Award }
	local ranking = Score.ranking(state)
	local awards: { Award } = {}
	for _, definition in AWARDS do
		local winnerId: PlayerId? = nil
		local best = 0
		-- El recorrido es el de la clasificación: ante un empate gana el que aparece antes. Solo
		-- un valor estrictamente mayor reemplaza al ganador actual.
		for _, playerId in ranking do
			local stats = state.stats[playerId]
			local value = if stats then stats[definition.stat] or 0 else 0
			if value > best then
				best = value
				winnerId = playerId
			end
		end
		if winnerId then
			table.insert(awards, { id = definition.id, playerId = winnerId })
		end
	end
	return awards
end

return Awards

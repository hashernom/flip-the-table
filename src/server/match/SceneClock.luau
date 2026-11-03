--!strict
-- Reloj de escenas: encadena las duraciones que da Scenes y recuerda cuántas veces se ha visto
-- cada tipo de evento en la partida. Es puro (R-P5): recibe `now` y no usa game, task ni ningún
-- reloj, por eso se prueba con Lune desde tests/server. El servidor es el único que llama a
-- time() y le pasa el instante.
local Scenes = require("../../shared/config/Scenes")
local Types = require("../../shared/rules/Types")

type Event = Types.Event

export type SceneClock = {
	-- Cuándo termina la última escena programada, en la base de tiempo del servidor.
	endsAt: number,
	-- Veces que se ha programado cada tipo de evento en esta partida. Es lo que acorta las
	-- escenas repetidas.
	seen: { [string]: number },
}

local SceneClock = {}

function SceneClock.new(): SceneClock
	return { endsAt = 0, seen = {} }
end

-- Programa las escenas de un lote a partir de `now`, una detrás de otra, y devuelve cuándo termina
-- la última. Sin eventos devuelve `now` (el lote no tiene escena que esperar). La decisión se fija
-- después, con este valor: nunca antes de que la escena acabe (R-P20).
function SceneClock.schedule(clock: SceneClock, events: { Event }, now: number): number
	local cursor = now
	for _, event in events do
		local seenCount = clock.seen[event.type] or 0
		cursor += Scenes.durationFor(event, seenCount)
		clock.seen[event.type] = seenCount + 1
	end
	clock.endsAt = cursor
	return cursor
end

return SceneClock

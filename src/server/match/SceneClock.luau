--!strict
-- Reloj de escenas: encadena las duraciones que da Scenes y recuerda cuántas veces se ha visto
-- cada tipo de evento en la partida. Es puro (R-P5): recibe `now` y no usa game, task ni ningún
-- reloj, por eso se prueba con Lune desde tests/server. MatchService le pasa el instante, siempre
-- en el reloj de Workspace:GetServerTimeNow() (R-P38).
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

-- Programa las escenas de un lote, una detrás de otra, y devuelve cuándo termina la última. Empiezan
-- en `now` o, si hay una escena en curso, cuando esta acabe: las escenas no se solapan (R-P39). Sin
-- eventos no añade nada, y tampoco adelanta el final de la escena en curso. La decisión se fija
-- después, con este valor: nunca antes de que la escena acabe (R-P20).
function SceneClock.schedule(clock: SceneClock, events: { Event }, now: number): number
	local cursor = math.max(now, clock.endsAt)
	for _, event in events do
		-- La repetición se cuenta por escena, no por tipo de evento: jugar otra carta distinta no acorta
		-- la siguiente, y el cliente cuenta con la misma clave.
		local sceneId = Scenes.sceneIdFor(event)
		local seenCount = clock.seen[sceneId] or 0
		cursor += Scenes.durationFor(event, seenCount)
		clock.seen[sceneId] = seenCount + 1
	end
	clock.endsAt = cursor
	return cursor
end

return SceneClock

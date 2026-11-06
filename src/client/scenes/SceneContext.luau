--!strict
-- Contexto que recibe cada escena. Es el contrato del plan 08: una escena solo muestra lo que el
-- servidor ya decidió, así que todo lo que necesita le llega aquí, y el mundo, la cámara y el audio
-- entran inyectados para que el director se pruebe con Lune.
local Types = require("../../shared/rules/Types")

type Event = Types.Event

-- Pone la ciudad como dice la vista: fichas, edificios y marcas. El director la llama al acabar cada
-- lote, aunque una escena falle o se omita.
export type WorldApi = { reconcile: (view: any) -> () }
export type CameraApi = { follow: (target: any) -> () }
export type AudioApi = { play: (id: string) -> () }

export type SceneContext = {
	event: Event,
	-- Vista del lote: el estado ya resuelto que la escena muestra.
	view: any,
	startedAt: number,
	duration: number,
	-- La escena ya se vio en esta partida y dura menos.
	shortened: boolean,
	-- Variación de la escena, igual para todo el grupo (`Scenes.variationFor`).
	variation: number,
	world: WorldApi,
	camera: CameraApi,
	audio: AudioApi,
	show: (text: string) -> (),
	wait: (seconds: number) -> (),
	-- Tiempo que la escena ya consumió fuera de `wait` (un recorrido que corre por su cuenta). El
	-- director lo descuenta para no esperar dos veces el mismo hueco.
	spent: (seconds: number) -> (),
}

local SceneContext = {}

SceneContext.noWorld = table.freeze({ reconcile = function(_view: any) end }) :: WorldApi
SceneContext.noCamera = table.freeze({ follow = function(_target: any) end }) :: CameraApi
SceneContext.noAudio = table.freeze({ play = function(_id: string) end }) :: AudioApi

function SceneContext.new(fields: SceneContext): SceneContext
	return fields
end

return SceneContext

--!strict
-- Director de escenas del cliente. Recibe un lote, resuelve la escena de cada evento y la reproduce
-- en orden, con la duración real de `Scenes`. Es el único módulo que sabe cuánto dura algo.
--
-- Dos decisiones que sostienen los criterios de la tarea:
--
-- - **El reloj entra inyectado.** Así el director se prueba entero con Lune, sin abrir Studio.
-- - **Un error no se lleva la cola por delante.** Cada escena va dentro de `pcall`; si falla se
--   registra y se sigue. La escena fallida ocupa su tiempo igual, para que el cliente no se adelante
--   al reloj del servidor, que es lo que mantiene a dos clientes a menos de 250 ms.
local Scenes = require("../../shared/config/Scenes")
local Types = require("../../shared/rules/Types")
local PlaceholderScene = require("./PlaceholderScene")

type Event = Types.Event
type Batch = { seq: number, startsAt: number?, events: { Event }?, view: any? }

export type Context = PlaceholderScene.Context & {
	-- Tiempo que la escena ya consumió fuera de `wait` (un recorrido que corre por su cuenta). El
	-- director lo descuenta para no esperar dos veces el mismo hueco.
	spent: (seconds: number) -> (),
}
export type Scene = { run: (ctx: Context, event: Event) -> () }

export type Options = {
	-- El reloj entra inyectado: el director no conoce `task`, así que se prueba entero con Lune y en
	-- Roblox espera de verdad. Quien lo crea decide qué significa esperar.
	wait: (seconds: number) -> (),
	show: ((text: string) -> ())?,
	log: ((message: string) -> ())?,
	-- Aviso al empezar cada evento, en su orden: el sonido de la interfaz suena con su escena.
	onEvent: ((event: Event) -> ())?,
}

export type Director = {
	wait: (seconds: number) -> (),
	show: (text: string) -> (),
	log: (message: string) -> (),
	onEvent: (event: Event) -> (),
	scenes: { [string]: Scene },
	-- Cuántas veces se ha visto cada tipo de evento en esta partida: acorta las escenas repetidas.
	seen: { [string]: number },
	-- Hay un título en pantalla, puesto por una escena de este director.
	titled: boolean,
}

local SceneDirector = {}

-- Suelo de la escena de un cliente atrasado: suficiente para que el grupo vea que algo pasa, sin
-- repetir entera una escena que el resto ya vio.
SceneDirector.MIN_LATE_SEC = 0.2

function SceneDirector.new(options: Options): Director
	local show = options.show or function(_text: string) end
	local director: Director = nil :: any
	director = {
		wait = options.wait,
		show = function(text: string)
			director.titled = text ~= ""
			show(text)
		end,
		log = options.log or function(_message: string) end,
		onEvent = options.onEvent or function(_event: Event) end,
		scenes = {},
		seen = {},
		titled = false,
	}
	return director
end

-- Una partida nueva vuelve a ver sus escenas enteras: el servidor estrena su reloj con cada partida y
-- los dos cuentan las mismas repeticiones.
function SceneDirector.reset(director: Director)
	director.seen = {}
end

-- Qué escena le toca a un evento. Una carta jugada se anuncia con su id, que es lo que le da escena
-- propia a cada legendaria; todo lo demás usa el tipo del evento.
function SceneDirector.sceneIdFor(event: Event): string
	if event.type == "CardPlayed" and type(event.cardId) == "string" then
		return event.cardId
	end
	return event.type
end

-- Registra la escena definitiva de un evento o de una carta. Las escenas provisionales de la subfase
-- 05 no registran nada: el nombre lo pone `PlaceholderScene` por defecto.
function SceneDirector.register(director: Director, eventOrCardId: string, scene: Scene)
	director.scenes[eventOrCardId] = scene
end

-- Reproduce un lote entero y devuelve cuántas escenas se reprodujeron. `ctx.wait` de la escena y la
-- espera del director comparten un contador, así que una escena que espera lo suyo no se espera dos
-- veces y una que falla a la primera sigue ocupando su hueco.
-- `behindSec` es cuánto lleva vencido el lote: un cliente que se quedó atrás descuenta ese tiempo en
-- vez de repetir escenas que el resto ya vio.
function SceneDirector.play(director: Director, batch: Batch, behindSec: number?): number
	local late = math.max(0, behindSec or 0)
	local events: { Event } = batch.events or {}
	local played = 0
	for _, event in events do
		local id = SceneDirector.sceneIdFor(event)
		local scene: Scene? = director.scenes[id]
		if scene == nil then
			scene = director.scenes[event.type]
		end

		local seen = director.seen[event.type] or 0
		director.seen[event.type] = seen + 1
		director.onEvent(event)
		local duration = math.max(SceneDirector.MIN_LATE_SEC, Scenes.durationFor(event, seen) - late)

		local elapsed = 0
		local function wait(seconds: number)
			if seconds <= 0 then
				return
			end
			elapsed += seconds
			director.wait(seconds)
		end

		local ctx: Context = {
			duration = duration,
			show = director.show,
			wait = wait,
			spent = function(seconds: number)
				if seconds > 0 then
					elapsed = math.min(duration, elapsed + seconds)
				end
			end,
		}

		-- Una escena definitiva se ve sola: no se queda encima el título del evento anterior.
		if scene ~= nil and director.titled then
			director.titled = false
			director.show("")
		end
		local target: Scene = scene or PlaceholderScene
		local ok, err = (pcall :: any)(target.run, ctx, event)
		if not ok then
			director.log(`SceneDirector: la escena {id} falló: {tostring(err)}`)
		end

		-- Lo que la escena no consumió se espera aquí: el lote tiene que ocupar lo que dice el reloj
		-- del servidor, aunque la escena se haya quedado corta o haya reventado.
		local remaining = duration - elapsed
		if remaining > 0 then
			elapsed = duration
			director.wait(remaining)
		end

		played += 1
	end
	return played
end

return SceneDirector

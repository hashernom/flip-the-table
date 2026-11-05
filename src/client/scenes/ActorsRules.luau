--!strict
-- Reglas del pool de actores de escena (plan 07, tarea 6). Son puras: no tocan `Instance` ni ningún
-- servicio, solo cuentan cuántos actores de cada tipo están en la escena, cuántos esperan libres y cuál
-- es su tope. Así se prueban con Lune sin abrir Studio, y `Actors` se limita a crear, mover y guardar
-- los modelos.
--
-- Un tipo nunca tiene más de `max` modelos vivos: los `active` están en la escena y los `free` esperan
-- en el pool para volver a usarse. Por eso una escena no puede pedir más de los que luego sabrá
-- liberar, que es la condición de la tarea.
local ActorsRules = {}

export type Kind =
	"Police"
	| "PatrolCar"
	| "Crowd"
	| "Worker"
	| "Crane"
	| "TowTruck"
	| "ArmoredTruck"
	| "WreckingBall"

-- Cuenta de un tipo. `active` son los que están en escena, `free` los que esperan en el pool y `max` el
-- tope de modelos vivos a la vez.
export type State = {
	active: number,
	free: number,
	max: number,
}

export type Pools = { [Kind]: State }

-- Qué hacer al ocupar un hueco (`take`) o al liberarlo (`drop`).
export type Slot = "reuse" | "create"
export type Release = "recycle" | "destroy"

-- Los tipos de la tarea, en el orden de la interfaz de `Actors`.
ActorsRules.KINDS = {
	"Police",
	"PatrolCar",
	"Crowd",
	"Worker",
	"Crane",
	"TowTruck",
	"ArmoredTruck",
	"WreckingBall",
} :: { Kind }

-- Topes por defecto, en modelos vivos a la vez. Se pueden cambiar al crear el pool con `new`.
ActorsRules.DEFAULTS = {
	Police = 4,
	PatrolCar = 2,
	Crowd = 12,
	Worker = 4,
	Crane = 2,
	TowTruck = 2,
	ArmoredTruck = 2,
	WreckingBall = 1,
} :: { [Kind]: number }

-- Convierte un texto en un tipo conocido. `nil` si no está en la lista: un `spawn` con una errata no
-- crea nada en vez de romper la escena.
function ActorsRules.kindOf(value: string): Kind?
	-- Se lee por índice y con el tipo anotado: la iteración genérica y la comparación con `string`
	-- ensanchan los literales del array.
	for index = 1, #ActorsRules.KINDS do
		local kind: Kind = ActorsRules.KINDS[index]
		if kind == value then
			return kind
		end
	end
	return nil
end

-- Tope de un tipo: el que pida `limits` o el de por defecto, saneado a un entero no negativo.
local function limitFor(kind: Kind, limits: { [string]: number }?): number
	local value = ActorsRules.DEFAULTS[kind]
	if limits ~= nil and limits[kind] ~= nil then
		value = limits[kind]
	end
	return math.max(0, math.floor(value))
end

-- Cuentas nuevas, todas a cero. `limits` es opcional y solo cambia los tipos que nombre.
function ActorsRules.new(limits: { [string]: number }?): Pools
	local pools: Pools = {}
	for index = 1, #ActorsRules.KINDS do
		local kind: Kind = ActorsRules.KINDS[index]
		pools[kind] = { active = 0, free = 0, max = limitFor(kind, limits) }
	end
	return pools
end

-- Ocupa un hueco: recicla uno de los libres o pide crear uno nuevo. `nil` si el tipo ya está al tope.
function ActorsRules.take(state: State): Slot?
	if state.free > 0 then
		state.free -= 1
		state.active += 1
		return "reuse"
	end
	if state.active < state.max then
		state.active += 1
		return "create"
	end
	return nil
end

-- Deshace un `take` que no llegó a crear ni a reciclar nada (faltaba el arte). No llena el pool, porque
-- no hay modelo que guardar.
function ActorsRules.cancel(state: State)
	if state.active > 0 then
		state.active -= 1
	end
end

-- Libera un actor. Vuelve al pool mientras quepa; si el tope bajó y el pool ya está lleno, hay que
-- destruirlo. `nil` si no había nada activo que liberar.
function ActorsRules.drop(state: State): Release?
	if state.active <= 0 then
		return nil
	end
	state.active -= 1
	if state.free < state.max then
		state.free += 1
		return "recycle"
	end
	return "destroy"
end

-- Vacía las cuentas de un tipo al acabar la escena y conserva su tope.
function ActorsRules.clear(state: State)
	state.active = 0
	state.free = 0
end

function ActorsRules.clearAll(pools: Pools)
	for index = 1, #ActorsRules.KINDS do
		local kind: Kind = ActorsRules.KINDS[index]
		ActorsRules.clear(pools[kind])
	end
end

-- Suma de activos y de libres de todos los tipos, para comprobar de un vistazo que no queda nada vivo.
function ActorsRules.totals(pools: Pools): (number, number)
	local active, free = 0, 0
	for index = 1, #ActorsRules.KINDS do
		local kind: Kind = ActorsRules.KINDS[index]
		local state = pools[kind]
		active += state.active
		free += state.free
	end
	return active, free
end

return ActorsRules

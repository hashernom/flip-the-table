--!strict
-- Almacén de estado del cliente. Guarda la última vista conocida y el número del último lote
-- aplicado. Es lógica pura: no usa game, Instance, task ni ningún reloj; el orden y la hora los
-- decide `EventQueue` y el reloj lo pasa quien lo tiene (el director de escenas).
local Types = require("../../shared/rules/Types")

type PlayerView = Types.PlayerView
type Event = Types.Event

-- Lote entrante. El contrato de la arquitectura lo fija como `{ seq, startsAt, events, view }`; el
-- cliente acepta además un lote sin carga útil, porque un paquete recortado no debe romper el
-- latido: lo que falta se ignora y la vista anterior se conserva.
export type Batch = {
	seq: number,
	startsAt: number?,
	events: { Event }?,
	view: PlayerView?,
}

export type Store = {
	view: PlayerView?,
	seq: number,
	events: number,
}

local StateStore = {}

function StateStore.new(): Store
	return { view = nil, seq = 0, events = 0 }
end

-- Aplica un lote: si trae vista, la guarda; si trae eventos, los cuenta; y avanza el número de
-- lote. Un lote más viejo que el ya aplicado se descarta entero (llega tarde y contaría eventos dos
-- veces). Un lote sin vista no borra la anterior: el servidor solo manda vista cuando cambia.
function StateStore.apply(store: Store, batch: Batch)
	local seq = batch.seq
	if type(seq) ~= "number" or seq < store.seq then
		return
	end
	local events = batch.events
	if events ~= nil then
		store.events += #events
	end
	if batch.view ~= nil then
		store.view = batch.view
	end
	store.seq = seq
end

-- Fija la instantánea que llega en una resincronización. Es la única forma de aplicar estado sin
-- reproducir escenas, y por eso no cuenta eventos: lo que el cliente se perdió no se inventa.
function StateStore.reset(store: Store, view: PlayerView?, seq: number)
	store.view = view
	store.seq = seq
end

function StateStore.view(store: Store): PlayerView?
	return store.view
end

function StateStore.seq(store: Store): number
	return store.seq
end

function StateStore.eventCount(store: Store): number
	return store.events
end

return StateStore

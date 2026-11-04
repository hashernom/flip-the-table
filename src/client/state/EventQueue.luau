--!strict
-- Cola de eventos del cliente. Recibe los lotes numerados del servidor, los mantiene en orden de
-- `seq` y entrega a la escena que toca cuando le llega su hora. Un duplicado se ignora y un hueco
-- pide resincronizar: el cliente se queda con la última vista buena en vez de inventarse lo que
-- falta. Es lógica pura: ni game, ni Instance, ni task; la hora entra por parámetro.
local StateStore = require("./StateStore")

export type Batch = StateStore.Batch
export type Queue = {
	state: StateStore.Store,
	-- Mayor `seq` contiguo que la cola aceptó (0 es la vista inicial, que también viaja por aquí).
	lastSeq: number,
	-- Lotes aceptados que aún esperan su hora, siempre en orden de `seq`.
	pending: { Batch },
	-- Primer `seq` que falta cuando hay un hueco; nil cuando la cola está al día.
	gap: number?,
}

local EventQueue = {}

function EventQueue.new(): Queue
	return { state = StateStore.new(), lastSeq = 0, pending = {}, gap = nil }
end

-- ¿El lote trae un número de secuencia utilizable? Un paquete sin `seq` entero y positivo no sirve
-- para ordenar nada, así que se trata como hueco y se pide resincronizar.
local function isValidSeq(seq: any): boolean
	return type(seq) == "number" and seq % 1 == 0 and seq >= 1
end

-- Inserta el lote en su sitio. Los aceptados llegan casi siempre en orden; la inserción ordenada
-- mantiene la garantía aunque un paquete se cuele por el camino.
local function insert(q: Queue, batch: Batch)
	local pending = q.pending
	local index = #pending + 1
	for position, queued in pending do
		if queued.seq > batch.seq then
			index = position
			break
		end
	end
	table.insert(pending, index, batch)
end

-- Clasifica un lote entrante. Devuelve:
--   "Queued"    el lote entra en la cola;
--   "Duplicate" ya lo teníamos (o ya se reprodujo): se ignora;
--   "Gap"       falta un lote anterior: el cliente debe mandar `ResyncRequest`.
function EventQueue.push(q: Queue, batch: Batch): "Queued" | "Gap" | "Duplicate"
	local seq = batch.seq
	if not isValidSeq(seq) then
		return "Gap"
	end
	if seq <= q.lastSeq then
		return "Duplicate"
	end
	if q.gap ~= nil then
		-- Mientras falta un lote no se acepta nada más: encadenar los siguientes dejaría la
		-- partida contada a medias. La resincronización trae la vista completa.
		return "Gap"
	end
	if seq > q.lastSeq + 1 then
		q.gap = q.lastSeq + 1
		return "Gap"
	end
	insert(q, batch)
	q.lastSeq = seq
	return "Queued"
end

-- Entrega el siguiente lote cuya hora ya llegó, o nil si no hay ninguno listo. Nunca adelanta un
-- lote: si el primero no ha empezado, espera, aunque el siguiente ya esté vencido.
function EventQueue.nextDue(q: Queue, now: number): Batch?
	if q.gap ~= nil then
		return nil
	end
	local head = q.pending[1]
	if head == nil then
		return nil
	end
	local startsAt = head.startsAt or 0
	if now < startsAt then
		return nil
	end
	table.remove(q.pending, 1)
	return head
end

-- Cuántos segundos lleva vencido un lote. El director de escenas lo usa para acortar la escena de
-- un cliente que llega tarde en vez de repetirla entera; nunca devuelve negativo.
function EventQueue.behindSec(batch: Batch, now: number): number
	local startsAt = batch.startsAt or 0
	return math.max(0, now - startsAt)
end

-- Resincronizar: sustituye la vista y salta hasta el `seq` que anuncia el servidor. Los lotes
-- anteriores se descartan porque sus escenas ya terminaron: su estado entra por la vista y no se
-- reproducen. `seq = 0` significa «todavía no hay lotes»: si la cola ya llevaba alguno, es una partida
-- nueva en el mismo servidor (la revancha) y la numeración vuelve a empezar.
function EventQueue.resync(q: Queue, view: any, seq: number)
	if seq == 0 then
		q.lastSeq = 0
		q.pending = {}
	end
	local target = if isValidSeq(seq) then seq else q.lastSeq
	StateStore.reset(q.state, view, target)
	if target > q.lastSeq then
		q.lastSeq = target
	end
	local kept: { Batch } = {}
	for _, queued in q.pending do
		if queued.seq > target then
			table.insert(kept, queued)
		end
	end
	q.pending = kept
	q.gap = nil
end

return EventQueue

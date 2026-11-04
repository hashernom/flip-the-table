--!strict
-- Pruebas de la cola de eventos y del almacén de estado del cliente. Son lógica pura: ni `game`, ni
-- `task`, ni reloj propio; el instante entra por parámetro, igual que en `Protocol.newLimiter`.
-- Cubren los tres criterios de la tarea: orden por `seq`, duplicado ignorado con hueco que pide
-- resincronización, y lote cuya escena ya terminó aplicado sin reproducirse.
local Harness = require("../harness")
local EventQueue = require("../../src/client/state/EventQueue")
local StateStore = require("../../src/client/state/StateStore")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

-- Vista mínima: lo que se comprueba es que viaja y se guarda tal cual, no su contenido. El tipo del
-- contrato es PlayerView; para la prueba basta una tabla identificable.
local function view(tag: string): any
	return { round = 1, tag = tag }
end

local function batch(seq: number, startsAt: number?): EventQueue.Batch
	return { seq = seq, startsAt = startsAt }
end

local function tagOf(q: EventQueue.Queue): string?
	local stored = StateStore.view(q.state)
	if stored == nil then
		return nil
	end
	return (stored :: any).tag
end

describe("EventQueue.push", function()
	it("el primer lote entra", function()
		local q = EventQueue.new()
		expect(EventQueue.push(q, { seq = 1 })).toBe("Queued")
	end)

	it("detecta un hueco", function()
		local q = EventQueue.new()
		expect(EventQueue.push(q, { seq = 1 })).toBe("Queued")
		expect(EventQueue.push(q, { seq = 3 })).toBe("Gap")
	end)

	it("ignora un duplicado", function()
		local q = EventQueue.new()
		EventQueue.push(q, { seq = 1 })
		expect(EventQueue.push(q, { seq = 1 })).toBe("Duplicate")
	end)

	it("ignora un duplicado aunque el lote llegue con otro contenido", function()
		local q = EventQueue.new()
		EventQueue.push(q, { seq = 1, startsAt = 10 })
		expect(EventQueue.push(q, { seq = 1, startsAt = 99 })).toBe("Duplicate")
	end)

	it("ignora lo que ya se reprodujo, no solo lo que sigue en la cola", function()
		local q = EventQueue.new()
		EventQueue.push(q, batch(1, 0))
		EventQueue.nextDue(q, 0)
		expect(EventQueue.push(q, { seq = 1 })).toBe("Duplicate")
	end)

	it("acepta la secuencia completa en orden", function()
		local q = EventQueue.new()
		expect(EventQueue.push(q, { seq = 1 })).toBe("Queued")
		expect(EventQueue.push(q, { seq = 2 })).toBe("Queued")
		expect(EventQueue.push(q, { seq = 3 })).toBe("Queued")
	end)

	it("un hueco sigue siendo hueco hasta que se resincroniza", function()
		local q = EventQueue.new()
		EventQueue.push(q, { seq = 1 })
		expect(EventQueue.push(q, { seq = 4 })).toBe("Gap")
		expect(EventQueue.push(q, { seq = 5 })).toBe("Gap")
		EventQueue.resync(q, view("resync"), 4)
		expect(EventQueue.push(q, { seq = 4 })).toBe("Duplicate")
		expect(EventQueue.push(q, { seq = 5 })).toBe("Queued")
	end)

	it("rechaza un lote sin número de secuencia válido", function()
		local q = EventQueue.new()
		expect(EventQueue.push(q, { seq = 0 })).toBe("Gap")
		expect(EventQueue.push(q, { seq = 1.5 })).toBe("Gap")
		expect(EventQueue.push(q, { startsAt = 0 } :: any)).toBe("Gap")
	end)
end)

describe("EventQueue.nextDue", function()
	it("no entrega un lote que aún no empieza", function()
		local q = EventQueue.new()
		EventQueue.push(q, batch(1, 10))
		expect(EventQueue.nextDue(q, 9.99)).toBe(nil)
		expect((EventQueue.nextDue(q, 10) :: any).seq).toBe(1)
	end)

	it("un lote sin hora de inicio está listo de inmediato", function()
		local q = EventQueue.new()
		EventQueue.push(q, { seq = 1 })
		expect((EventQueue.nextDue(q, 0) :: any).seq).toBe(1)
	end)

	it("entrega siempre en orden de seq, aunque el segundo ya esté vencido", function()
		local q = EventQueue.new()
		EventQueue.push(q, batch(1, 0))
		EventQueue.push(q, batch(2, 0))
		expect((EventQueue.nextDue(q, 100) :: any).seq).toBe(1)
		expect((EventQueue.nextDue(q, 100) :: any).seq).toBe(2)
		expect(EventQueue.nextDue(q, 100)).toBe(nil)
	end)

	it("no entrega el segundo mientras el primero no haya vencido", function()
		local q = EventQueue.new()
		EventQueue.push(q, batch(1, 10))
		EventQueue.push(q, batch(2, 1))
		expect(EventQueue.nextDue(q, 5)).toBe(nil)
		expect((EventQueue.nextDue(q, 10) :: any).seq).toBe(1)
		expect((EventQueue.nextDue(q, 10) :: any).seq).toBe(2)
	end)

	it("con un hueco pendiente no entrega nada", function()
		local q = EventQueue.new()
		EventQueue.push(q, { seq = 1 })
		EventQueue.push(q, { seq = 3 })
		EventQueue.nextDue(q, 0)
		expect(EventQueue.nextDue(q, 1000)).toBe(nil)
	end)
end)

describe("EventQueue.resync", function()
	it("aplica el estado de la resincronización sin reproducir escenas", function()
		local q = EventQueue.new()
		EventQueue.push(q, batch(1, 0))
		EventQueue.resync(q, view("reciente"), 7)
		expect(tagOf(q)).toBe("reciente")
		-- El lote 1 ya no se reproduce: su escena terminó hace tiempo.
		expect(EventQueue.nextDue(q, 1000)).toBe(nil)
	end)

	it("descarta los lotes pendientes que el servidor ya dio por vistos", function()
		local q = EventQueue.new()
		EventQueue.push(q, batch(1, 0))
		EventQueue.push(q, batch(2, 0))
		EventQueue.resync(q, view("reciente"), 2)
		expect(EventQueue.nextDue(q, 1000)).toBe(nil)
		EventQueue.push(q, batch(3, 0))
		expect((EventQueue.nextDue(q, 1000) :: any).seq).toBe(3)
	end)

	it("quita el hueco pendiente", function()
		local q = EventQueue.new()
		EventQueue.push(q, { seq = 1 })
		EventQueue.push(q, { seq = 3 })
		EventQueue.resync(q, view("reciente"), 3)
		expect(EventQueue.push(q, { seq = 3 })).toBe("Duplicate")
		expect(EventQueue.push(q, { seq = 4 })).toBe("Queued")
	end)

	it("un lote posterior sigue reproduciéndose con normalidad", function()
		local q = EventQueue.new()
		EventQueue.resync(q, view("reciente"), 0)
		EventQueue.push(q, batch(1, 50))
		expect((EventQueue.nextDue(q, 50) :: any).seq).toBe(1)
		expect(tagOf(q)).toBe("reciente")
	end)
end)

describe("StateStore", function()
	it("empieza sin vista", function()
		local store = StateStore.new()
		expect(StateStore.view(store)).toBe(nil)
	end)

	it("guarda la vista del último lote aplicado", function()
		local store = StateStore.new()
		StateStore.apply(store, { seq = 1, view = view("uno") })
		expect((StateStore.view(store) :: any).tag).toBe("uno")
		StateStore.apply(store, { seq = 2, view = view("dos") })
		expect((StateStore.view(store) :: any).tag).toBe("dos")
	end)

	it("no pierde la vista cuando un lote no trae ninguna", function()
		local store = StateStore.new()
		StateStore.apply(store, { seq = 1, view = view("uno") })
		StateStore.apply(store, { seq = 2 })
		expect((StateStore.view(store) :: any).tag).toBe("uno")
	end)

	it("recuerda el lote aplicado y avanza con cada evento", function()
		local store = StateStore.new()
		expect(StateStore.seq(store)).toBe(0)
		StateStore.apply(store, { seq = 4, events = { { type = "DiceRolled" }, { type = "TokenMoved" } } })
		expect(StateStore.seq(store)).toBe(4)
		expect(StateStore.eventCount(store)).toBe(2)
	end)

	it("guarda la vista de una resincronización", function()
		local store = StateStore.new()
		StateStore.reset(store, view("reciente"), 9)
		expect((StateStore.view(store) :: any).tag).toBe("reciente")
		expect(StateStore.seq(store)).toBe(9)
	end)
end)

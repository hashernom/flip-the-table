--!strict
-- Pruebas del director de escenas. El director es puro salvo por el reloj, que entra inyectado, así
-- que se puede probar con Lune: aquí `wait` apunta lo que se le pide esperar en vez de esperarlo.
-- Cubren los tres criterios de la tarea: todo evento sin escena final muestra su nombre durante su
-- duración real, la escena de una carta se elige por su id y un error no detiene la cola.
local Harness = require("../harness")
local Scenes = require("../../src/shared/config/Scenes")
local SceneDirector = require("../../src/client/scenes/SceneDirector")
local PlaceholderScene = require("../../src/client/scenes/PlaceholderScene")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

type Director = SceneDirector.Director

-- Director de prueba: apunta esperas, rótulos y avisos en lugar de hablarlos.
type Recorder = {
	director: Director,
	waits: { number },
	labels: { string },
	messages: { string },
	reconciled: { any },
}

local function recorder(): Recorder
	local record: Recorder = {
		waits = {},
		labels = {},
		messages = {},
		reconciled = {},
		director = nil :: any,
	}
	record.director = SceneDirector.new({
		wait = function(seconds: number)
			table.insert(record.waits, seconds)
		end,
		show = function(text: string)
			table.insert(record.labels, text)
		end,
		log = function(message: string)
			table.insert(record.messages, message)
		end,
		world = {
			reconcile = function(view: any)
				table.insert(record.reconciled, view)
			end,
		},
		now = function()
			return 42
		end,
	})
	return record
end

local function batch(events: { any }): any
	return { seq = 1, startsAt = 0, events = events }
end

describe("SceneDirector.play", function()
	it("una escena final limpia el título que dejó el evento anterior", function()
		local record = recorder()
		SceneDirector.register(record.director, "PlayerArrested", { run = function() end })
		SceneDirector.play(record.director, batch({ { type = "DiceRolled" }, { type = "PlayerArrested" } }))
		expect(record.labels).toEqual({ "DiceRolled", "" })
	end)

	it("un evento sin escena final muestra su nombre durante su duración real", function()
		local record = recorder()
		SceneDirector.play(record.director, batch({ { type = "DiceRolled" } }))
		expect(record.labels).toEqual({ "DiceRolled" })
		expect(record.waits).toEqual({ Scenes.durationFor({ type = "DiceRolled" }, 0) })
	end)

	it("reproduce todos los eventos del lote en orden", function()
		local record = recorder()
		SceneDirector.play(
			record.director,
			batch({ { type = "DiceRolled" }, { type = "TokenMoved" }, { type = "RentPaid" } })
		)
		expect(record.labels).toEqual({ "DiceRolled", "TokenMoved", "RentPaid" })
		expect(#record.waits).toBe(3)
	end)

	it("repetir un evento acorta su escena, como manda Scenes.durationFor", function()
		local record = recorder()
		SceneDirector.play(record.director, batch({ { type = "DiceRolled" }, { type = "DiceRolled" } }))
		expect(record.waits[1]).toBe(Scenes.durationFor({ type = "DiceRolled" }, 0))
		expect(record.waits[2]).toBe(Scenes.durationFor({ type = "DiceRolled" }, 1))
		expect(record.waits[2] < record.waits[1]).toBe(true)
	end)

	it("un lote vacío no muestra nada ni espera", function()
		local record = recorder()
		expect(SceneDirector.play(record.director, batch({}))).toBe(0)
		expect(#record.labels).toBe(0)
		expect(#record.waits).toBe(0)
	end)
end)

describe("SceneDirector: escenas finales", function()
	it("una escena registrada para el evento sustituye al nombre", function()
		local record = recorder()
		SceneDirector.register(record.director, "DiceRolled", {
			run = function(ctx, _event)
				ctx.show("dados girando")
				ctx.wait(ctx.duration)
			end,
		})
		SceneDirector.play(record.director, batch({ { type = "DiceRolled" } }))
		expect(record.labels).toEqual({ "dados girando" })
		expect(record.waits).toEqual({ Scenes.durationFor({ type = "DiceRolled" }, 0) })
	end)

	it("una carta usa su propia escena y su propia duración", function()
		local record = recorder()
		local seen: string? = nil
		SceneDirector.register(record.director, "Hurricane", {
			run = function(_ctx, event)
				seen = event.cardId
			end,
		})
		local event = { type = "CardPlayed", cardId = "Hurricane" }
		SceneDirector.play(record.director, batch({ event }))
		expect(seen).toBe("Hurricane")
		-- La legendaria dura lo que dice Scenes para esa carta, no la base de CardPlayed.
		expect(record.waits[1]).toBe(Scenes.durationFor(event, 0))
		expect(record.waits[1]).toBe(10)
	end)

	it("una carta sin escena registrada cae en la del evento CardPlayed", function()
		local record = recorder()
		SceneDirector.play(record.director, batch({ { type = "CardPlayed", cardId = "Hurricane" } }))
		-- Se anuncia con el nombre de la carta, pero se reproduce con la escena provisional del evento.
		expect(record.labels).toEqual({ "Hurricane" })
		expect(record.waits[1]).toBe(10)
	end)
end)

describe("SceneDirector.reset", function()
	it("una partida nueva vuelve a ver sus escenas enteras", function()
		local record = recorder()
		-- Los dados tienen su propio suelo (1,4 s): la segunda tirada no baja de ahí.
		local dice = { seq = 1, events = { { type = "DiceRolled" } } }
		SceneDirector.play(record.director, dice)
		SceneDirector.play(record.director, dice)
		expect(record.waits).toEqual({ 2, 1.4 })
		SceneDirector.reset(record.director)
		SceneDirector.play(record.director, dice)
		expect(record.waits).toEqual({ 2, 1.4, 2 })
	end)
end)

describe("SceneDirector: errores", function()
	it("un error dentro de una escena no detiene la cola", function()
		local record = recorder()
		SceneDirector.register(record.director, "DiceRolled", {
			run = function()
				error("escena rota a propósito")
			end,
		})
		SceneDirector.play(record.director, batch({ { type = "DiceRolled" }, { type = "TokenMoved" } }))
		expect(#record.messages).toBe(1)
		expect(string.find(record.messages[1], "escena rota a propósito", 1, true) ~= nil).toBe(true)
		expect(record.labels).toEqual({ "TokenMoved" })
	end)

	it("la escena rota igualmente ocupa su tiempo, para no desviarse del reloj del servidor", function()
		local record = recorder()
		SceneDirector.register(record.director, "DiceRolled", {
			run = function()
				error("escena rota a propósito")
			end,
		})
		SceneDirector.play(record.director, batch({ { type = "DiceRolled" } }))
		expect(record.waits).toEqual({ Scenes.durationFor({ type = "DiceRolled" }, 0) })
	end)

	it("una escena que ya gastó su tiempo sin esperar solo deja esperar el resto", function()
		local record = recorder()
		SceneDirector.register(record.director, "TokenMoved", {
			run = function(ctx)
				-- Como un recorrido de ficha: consume tiempo real sin pasar por `ctx.wait`.
				ctx.spent(ctx.duration / 2)
			end,
		})
		SceneDirector.play(record.director, batch({ { type = "TokenMoved" } }))
		expect(record.waits).toEqual({ Scenes.durationFor({ type = "TokenMoved" }, 0) / 2 })
	end)

	it("una escena que ya esperó lo suyo no se espera dos veces", function()
		local record = recorder()
		SceneDirector.register(record.director, "DiceRolled", {
			run = function(ctx)
				ctx.wait(ctx.duration)
			end,
		})
		SceneDirector.play(record.director, batch({ { type = "DiceRolled" } }))
		-- Una sola espera: la de la escena, no la del director encima.
		expect(#record.waits).toBe(1)
	end)
end)

describe("SceneDirector: identificadores", function()
	it("el id de escena de una carta jugada es el de la carta", function()
		expect(SceneDirector.sceneIdFor({ type = "CardPlayed", cardId = "Hurricane" })).toBe("Hurricane")
	end)

	it("el id de escena de un evento normal es su tipo", function()
		expect(SceneDirector.sceneIdFor({ type = "RentPaid" })).toBe("RentPaid")
	end)

	it("una carta jugada sin id cae en el tipo del evento", function()
		expect(SceneDirector.sceneIdFor({ type = "CardPlayed" })).toBe("CardPlayed")
	end)
end)

describe("PlaceholderScene", function()
	it("una carta se anuncia con el nombre de la carta, no con el del evento", function()
		-- Sin escena final, el grupo tiene que leer qué carta le acaba de caer: «WorldFlip» y no
		-- «CardPlayed».
		expect(PlaceholderScene.labelFor({ type = "CardPlayed", cardId = "WorldFlip" })).toBe("WorldFlip")
	end)

	it("un evento normal se anuncia con su tipo", function()
		expect(PlaceholderScene.labelFor({ type = "RentPaid" })).toBe("RentPaid")
	end)

	it("una carta sin id se queda con el tipo del evento", function()
		expect(PlaceholderScene.labelFor({ type = "CardPlayed" })).toBe("CardPlayed")
	end)
end)

describe("SceneDirector: cliente atrasado", function()
	it("un lote que llega tarde acorta su escena en vez de repetirla entera", function()
		local record = recorder()
		local full = Scenes.durationFor({ type = "DiceRolled" }, 0)
		SceneDirector.play(record.director, batch({ { type = "DiceRolled" } }), 1.5)
		expect(record.waits[1]).toBe(full - 1.5)
	end)

	it("una escena a la que le quedan menos de 500 ms se omite", function()
		local record = recorder()
		local ran = false
		SceneDirector.register(record.director, "DiceRolled", {
			run = function()
				ran = true
			end,
		})
		local full = Scenes.durationFor({ type = "DiceRolled" }, 0)
		SceneDirector.play(record.director, batch({ { type = "DiceRolled" } }), full - 0.4)
		expect(ran).toBe(false)
		expect(#record.waits).toBe(0)
	end)

	it("un lote muy atrasado no reproduce nada, pero deja el mundo como la vista", function()
		local record = recorder()
		local view = { round = 7 }
		SceneDirector.play(
			record.director,
			{ seq = 3, events = { { type = "DiceRolled" } }, view = view },
			99
		)
		expect(#record.waits).toBe(0)
		expect(#record.labels).toBe(0)
		expect(record.reconciled).toEqual({ view })
	end)

	it("con medio segundo o más empieza en su punto, con lo que le queda", function()
		local record = recorder()
		local full = Scenes.durationFor({ type = "DiceRolled" }, 0)
		SceneDirector.play(record.director, batch({ { type = "DiceRolled" } }), full - Scenes.skipBelowSec)
		expect(record.waits).toEqual({ Scenes.skipBelowSec })
	end)

	it("el atraso se descuenta una vez: las escenas siguientes del lote van a su hora", function()
		local record = recorder()
		local dice = Scenes.durationFor({ type = "DiceRolled" }, 0)
		local rent = Scenes.durationFor({ type = "RentPaid" }, 0)
		-- Llega tarde lo justo para perderse los dados y medio segundo del alquiler.
		SceneDirector.play(
			record.director,
			batch({ { type = "DiceRolled" }, { type = "RentPaid" } }),
			dice + 0.5
		)
		expect(record.waits).toEqual({ rent - 0.5 })
	end)

	it("sin atraso la escena dura lo que toca", function()
		local record = recorder()
		local full = Scenes.durationFor({ type = "DiceRolled" }, 0)
		SceneDirector.play(record.director, batch({ { type = "DiceRolled" } }), 0)
		expect(record.waits[1]).toBe(full)
	end)
end)

describe("Scenes: Portal", function()
	it("el salto del Portal dura más que antes y no se acorta al repetirse", function()
		local first = Scenes.durationFor({ type = "PortalUsed" }, 0)
		expect(first >= 4).toBe(true)
		expect(Scenes.durationFor({ type = "PortalUsed" }, 3)).toBe(first)
	end)

	it("las fases del salto van en orden dentro de la escena", function()
		local p = Scenes.portal
		expect(0 < p.vanishAt and p.vanishAt < p.goneAt and p.goneAt < p.appearAt).toBe(true)
		expect(p.appearAt < p.shownAt and p.shownAt < 1).toBe(true)
	end)
end)

describe("SceneDirector: conciliación con la vista", function()
	it("al acabar el lote, el mundo se pone como la vista", function()
		local record = recorder()
		local view = { round = 1 }
		SceneDirector.play(record.director, { seq = 1, events = { { type = "DiceRolled" } }, view = view })
		expect(record.reconciled).toEqual({ view })
	end)

	it("aunque la escena falle, el mundo acaba como la vista", function()
		local record = recorder()
		SceneDirector.register(record.director, "BuildingChanged", {
			run = function()
				error("grúa rota a propósito")
			end,
		})
		local view = { buildings = { [5] = 2 } }
		SceneDirector.play(
			record.director,
			{ seq = 1, events = { { type = "BuildingChanged" } }, view = view }
		)
		expect(record.reconciled).toEqual({ view })
	end)

	it("dos escenas seguidas sobre el mismo edificio terminan en el nivel de la vista", function()
		-- La escena de cada evento deja el edificio a su manera; la última palabra es de la vista.
		local record = recorder()
		local level = 0
		SceneDirector.register(record.director, "BuildingChanged", {
			run = function(_ctx, event)
				level = event.level
			end,
		})
		record.director.world = {
			reconcile = function(view: any)
				level = view.level
			end,
		}
		local view = { level = 2 }
		SceneDirector.play(record.director, {
			seq = 1,
			events = {
				{ type = "BuildingChanged", square = 5, level = 3 },
				{ type = "BuildingChanged", square = 5, level = 1 },
			},
			view = view,
		})
		expect(level).toBe(2)
	end)

	it("un fallo al conciliar se registra y no rompe el director", function()
		local record = recorder()
		record.director.world = {
			reconcile = function()
				error("mundo roto a propósito")
			end,
		}
		SceneDirector.play(record.director, { seq = 1, events = { { type = "DiceRolled" } }, view = {} })
		expect(#record.messages).toBe(1)
	end)

	it("un lote sin vista no concilia", function()
		local record = recorder()
		SceneDirector.play(record.director, batch({ { type = "DiceRolled" } }))
		expect(#record.reconciled).toBe(0)
	end)
end)

describe("SceneDirector: contexto de la escena", function()
	it("la escena recibe evento, vista, inicio, variación y si está acortada", function()
		local record = recorder()
		local contexts: { any } = {}
		SceneDirector.register(record.director, "RentPaid", {
			run = function(ctx)
				table.insert(contexts, ctx)
			end,
		})
		local view = { round = 2 }
		local event = { type = "RentPaid", payerId = "a", amount = 40 }
		SceneDirector.play(record.director, { seq = 1, events = { event, event }, view = view })
		local first, second = contexts[1], contexts[2]
		expect(first.event).toBe(event)
		expect(first.view).toBe(view)
		expect(first.startedAt).toBe(42)
		expect(first.variation).toBe(Scenes.variationFor(event))
		expect(first.shortened).toBe(false)
		expect(second.shortened).toBe(true)
		expect(first.world ~= nil and first.camera ~= nil and first.audio ~= nil).toBe(true)
	end)

	it("sin APIs inyectadas la escena recibe unas que no hacen nada", function()
		local director = SceneDirector.new({ wait = function() end })
		local got: any = nil
		SceneDirector.register(director, "DiceRolled", {
			run = function(ctx)
				got = ctx
				ctx.camera.follow(nil)
				ctx.audio.play("x")
				ctx.world.reconcile({})
			end,
		})
		SceneDirector.play(director, batch({ { type = "DiceRolled" } }))
		expect(got ~= nil).toBe(true)
	end)
end)

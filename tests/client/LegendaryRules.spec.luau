--!strict
-- Pruebas de las reglas puras de las cinco legendarias (plan 08, Tarea 3): tiempos, recorrido del embudo,
-- vuelo de los restos, temblor, arcos, y quién da y quién recibe en la Revolución y el Golpe a la Corona.
local Harness = require("../harness")
local LegendaryRules = require("../../src/client/scenes/legendary/LegendaryRules")
local LegendaryStaging = require("../../src/shared/config/LegendaryStaging")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function near(a: number, b: number, tolerance: number?): boolean
	return math.abs(a - b) <= (tolerance or 1e-6)
end

local SQUARE = { { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 10, z = 10 }, { x = 0, z = 10 } }

describe("LegendaryRules.windows", function()
	it("las fracciones de cada legendaria suman 1", function()
		for _, name in { "hurricane", "worldFlip", "revolution", "earthquake", "crownStrike" } do
			local staging = (LegendaryStaging :: any)[name]
			local total = 0
			for _, step in staging.steps do
				total += staging.fractions[step]
			end
			expect(near(total, 1, 1e-9)).toBe(true)
		end
	end)

	it("reparte la duración en ventanas seguidas que acaban en la duración", function()
		local staging = LegendaryStaging.hurricane
		local windows = LegendaryRules.windows(staging, 10)
		local at = 0
		for _, step in staging.steps do
			expect(near(windows[step].from, at)).toBe(true)
			expect(windows[step].to >= windows[step].from).toBe(true)
			at = windows[step].to
		end
		expect(at).toBe(10)
	end)

	it("una duración negativa deja todas las ventanas en cero", function()
		local windows = LegendaryRules.windows(LegendaryStaging.earthquake, -3)
		expect(windows.settle.to).toBe(0)
	end)
end)

describe("LegendaryRules.progress y ease", function()
	it("progress va de 0 a 1 dentro de su ventana", function()
		local window = { from = 2, to = 4 }
		expect(LegendaryRules.progress(window, 1)).toBe(0)
		expect(LegendaryRules.progress(window, 3)).toBe(0.5)
		expect(LegendaryRules.progress(window, 9)).toBe(1)
	end)

	it("una ventana vacía salta de 0 a 1", function()
		local window = { from = 2, to = 2 }
		expect(LegendaryRules.progress(window, 1)).toBe(0)
		expect(LegendaryRules.progress(window, 2)).toBe(1)
	end)

	it("ease empieza y acaba suave y no se sale de 0 a 1", function()
		expect(LegendaryRules.ease(0)).toBe(0)
		expect(LegendaryRules.ease(1)).toBe(1)
		expect(LegendaryRules.ease(0.5)).toBe(0.5)
		expect(LegendaryRules.ease(-2)).toBe(0)
		expect(LegendaryRules.ease(5)).toBe(1)
	end)
end)

describe("LegendaryRules.loop", function()
	it("recorre el anillo por longitud y vuelve al principio", function()
		local loop = LegendaryRules.loop(SQUARE)
		expect(loop.length).toBe(40)
		local start = LegendaryRules.along(loop, 0)
		expect(near(start.x, 0) and near(start.z, 0)).toBe(true)
		local half = LegendaryRules.along(loop, 0.5)
		expect(near(half.x, 10) and near(half.z, 10)).toBe(true)
		local quarter = LegendaryRules.along(loop, 0.125)
		expect(near(quarter.x, 5) and near(quarter.z, 0)).toBe(true)
		local done = LegendaryRules.along(loop, 1)
		expect(near(done.x, 0) and near(done.z, 0)).toBe(true)
	end)

	it("el rumbo apunta por donde sigue la calle", function()
		local loop = LegendaryRules.loop(SQUARE)
		local first = LegendaryRules.along(loop, 0.1)
		expect(near(first.headingX, 1) and near(first.headingZ, 0)).toBe(true)
		local second = LegendaryRules.along(loop, 0.3)
		expect(near(second.headingX, 0) and near(second.headingZ, 1)).toBe(true)
	end)

	it("cada punto sabe en qué fracción del recorrido pasa el embudo", function()
		local loop = LegendaryRules.loop(SQUARE)
		expect(loop.passAt).toEqual({ 0, 0.25, 0.5, 0.75 })
	end)

	it("un anillo de un solo punto no rompe", function()
		local loop = LegendaryRules.loop({ { x = 3, z = 4 } })
		local here = LegendaryRules.along(loop, 0.7)
		expect(near(here.x, 3) and near(here.z, 4)).toBe(true)
	end)
end)

describe("LegendaryRules.debris", function()
	it("empieza en el sitio y sube en espiral", function()
		local start = LegendaryRules.debris(0.3, 0, LegendaryStaging.hurricane)
		expect(near(start.x, 0) and near(start.y, 0) and near(start.z, 0)).toBe(true)
		local later = LegendaryRules.debris(0.3, 1, LegendaryStaging.hurricane)
		expect(near(later.y, LegendaryStaging.hurricane.debrisRise)).toBe(true)
		local radius = math.sqrt(later.x * later.x + later.z * later.z)
		expect(near(radius, LegendaryStaging.hurricane.debrisSpread, 1e-6)).toBe(true)
	end)

	it("dos piezas con semilla distinta salen hacia sitios distintos", function()
		local a = LegendaryRules.debris(0.1, 0.8, LegendaryStaging.hurricane)
		local b = LegendaryRules.debris(0.6, 0.8, LegendaryStaging.hurricane)
		expect(near(a.x, b.x) and near(a.z, b.z)).toBe(false)
	end)

	it("la misma semilla da siempre el mismo vuelo", function()
		local a = LegendaryRules.debris(0.42, 0.5, LegendaryStaging.hurricane)
		local b = LegendaryRules.debris(0.42, 0.5, LegendaryStaging.hurricane)
		expect(a).toEqual(b)
	end)
end)

describe("LegendaryRules.shake", function()
	it("no se aleja más que la amplitud y vale cero sin amplitud", function()
		for step = 0, 50 do
			local offset = LegendaryRules.shake(step * 0.037, 0.5, 0.9, 12)
			expect(math.abs(offset.x) <= 0.9 + 1e-9 and math.abs(offset.z) <= 0.9 + 1e-9).toBe(true)
		end
		local still = LegendaryRules.shake(1.3, 0.5, 0, 12)
		expect(still.x == 0 and still.z == 0).toBe(true)
	end)

	it("es el mismo para la misma semilla y el mismo instante", function()
		expect(LegendaryRules.shake(0.7, 0.2, 1, 10)).toEqual(LegendaryRules.shake(0.7, 0.2, 1, 10))
	end)
end)

describe("LegendaryRules.arc", function()
	it("sale del origen, llega al destino y sube en medio", function()
		local from = { x = 0, y = 2, z = 0 }
		local to = { x = 10, y = 2, z = 0 }
		local start = LegendaryRules.arc(from, to, 0, 8)
		local finish = LegendaryRules.arc(from, to, 1, 8)
		local middle = LegendaryRules.arc(from, to, 0.5, 8)
		expect(start).toEqual(from)
		expect(finish).toEqual(to)
		expect(near(middle.x, 5) and near(middle.y, 10)).toBe(true)
	end)
end)

describe("LegendaryRules.revolutionPairs", function()
	local function player(id: string, cash: number, status: string?): any
		return { id = id, cash = cash, status = status or "Active" }
	end

	it("con 2 o 3 jugadores, el dinero va del más rico de antes al más pobre de antes", function()
		-- Tras el cambio, el que era rico es ahora el más pobre: él da y el que ahora es más rico recibe.
		local pairs = LegendaryRules.revolutionPairs({ player("A", 300), player("B", 900), player("C", 500) })
		expect(pairs).toEqual({ { giver = "A", taker = "B" } })
	end)

	it("con 4 o más jugadores hay dos parejas", function()
		local pairs = LegendaryRules.revolutionPairs({
			player("A", 100),
			player("B", 1200),
			player("C", 600),
			player("D", 200),
			player("E", 900),
		})
		expect(pairs).toEqual({ { giver = "A", taker = "B" }, { giver = "D", taker = "E" } })
	end)

	it("solo cuentan los activos, y con menos de 2 no hay parejas", function()
		local pairs = LegendaryRules.revolutionPairs({ player("A", 100), player("B", 900, "Bankrupt") })
		expect(#pairs).toBe(0)
	end)
end)

describe("LegendaryRules.crownRivals", function()
	it("los rivales son los activos que no son el líder", function()
		local rivals = LegendaryRules.crownRivals(
			"B",
			{
				{ id = "A", status = "Active" },
				{ id = "B", status = "Active" },
				{ id = "C", status = "Bankrupt" },
				{ id = "D", status = "Active" },
			} :: any
		)
		expect(rivals).toEqual({ "A", "D" })
	end)
end)

describe("LegendaryRules.center", function()
	it("da el centro y el lado de la ciudad", function()
		local center, span = LegendaryRules.center(SQUARE)
		expect(near(center.x, 5) and near(center.z, 5)).toBe(true)
		expect(span).toBe(10)
	end)

	it("sin puntos, el centro es el origen", function()
		local center, span = LegendaryRules.center({})
		expect(center.x == 0 and center.z == 0 and span == 0).toBe(true)
	end)
end)

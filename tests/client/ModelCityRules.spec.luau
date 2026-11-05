--!strict
-- Pruebas de las reglas de la maqueta de la vista general: la escala y el plinto de los tres tableros,
-- las tarjetas que entran y salen entre dos vistas y los marcadores de cada asiento. Las vistas salen de
-- `View`, no de tablas inventadas, para que un cambio de contrato las rompa.
local Harness = require("../harness")
local CityLayout = require("../../src/shared/config/CityLayout")
local Fixtures = require("../fixtures")
local ModelCityRules = require("../../src/client/world/ModelCityRules")
local View = require("../../src/shared/rules/View")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local SIZES: { string } = { "S", "M", "L" }

-- Los alias de `SizeId` no se unifican al pasar por una lista, igual que en `CityLayout.spec`: estas
-- envolturas con `string` dejan las pruebas escritas sobre los tres nombres sin pelearse con el tipo.
local function plinthFor(size: string): ModelCityRules.Plinth
	return ModelCityRules.plinthFor(size :: any)
end

local function groundSpan(size: string): number
	return ModelCityRules.groundSpan(size :: any)
end

local function spanFor(size: string): number
	return CityLayout.spanFor(size :: any)
end

local function centerFor(size: string): CityLayout.Vector3Like
	return CityLayout.centerFor(size :: any)
end

local function firstProperty(state: any): number
	for _, square in state.board.squares do
		if square.kind == "Property" then
			return square.index
		end
	end
	error("el tablero no tiene propiedades")
end

local function viewOf(state: any): any
	return View.forPlayer(state, "P1")
end

-- El asiento es el orden de la vista, que `State` baraja al crear la partida: no se puede suponer que
-- P2 sea el asiento 2.
local function seatOf(view: any, id: string): number
	for seat, seated in view.players do
		if seated.id == id then
			return seat
		end
	end
	error(`el jugador {id} no está sentado`)
end

describe("ModelCityRules: escala y plinto", function()
	it("la miniatura ocupa el mismo ancho en los tres tableros", function()
		for _, size in SIZES do
			local plinth = plinthFor(size)
			local shown = groundSpan(size) * plinth.scale
			expect(math.abs(shown - ModelCityRules.MODEL_SPAN_STUDS) < 1e-9).toBe(true)
			expect(plinth.scale < 1).toBe(true)
		end
	end)

	it("cada tablero se escala a lo suyo: más grande, menos escala", function()
		local small = ModelCityRules.plinthFor("S")
		local medium = ModelCityRules.plinthFor("M")
		local large = ModelCityRules.plinthFor("L")
		expect(small.scale > medium.scale).toBe(true)
		expect(medium.scale > large.scale).toBe(true)
		expect(medium.modelSpan).toBe(small.modelSpan)
		expect(large.modelSpan).toBe(small.modelSpan)
	end)

	it("el plinto cabe en la plaza interior y se apoya en el suelo", function()
		for _, size in SIZES do
			local plinth = plinthFor(size)
			local inner = spanFor(size) - 2 * (CityLayout.STREET_WIDTH_STUDS / 2 + CityLayout.SIDEWALK_STUDS)
			expect(plinth.width <= inner).toBe(true)
			expect(plinth.depth).toBe(plinth.width)
			expect(plinth.baseY).toBe(ModelCityRules.GROUND_TOP_STUDS)
			expect(plinth.height).toBe(ModelCityRules.PLINTH_HEIGHT_STUDS)
			expect(math.abs(plinth.deckY - (plinth.baseY + plinth.height)) < 1e-9).toBe(true)
		end
	end)

	it("la ciudad cae centrada y su calle queda sobre la cara del plinto", function()
		for _, size in SIZES do
			local plinth = plinthFor(size)
			local center = centerFor(size)
			expect(plinth.center.x).toBe(center.x)
			expect(plinth.center.z).toBe(center.z)

			local below =
				ModelCityRules.modelPoint(plinth, center.x, -ModelCityRules.GROUND_DEPTH_STUDS, center.z)
			expect(math.abs(below.x - plinth.center.x) < 1e-9).toBe(true)
			expect(math.abs(below.y - plinth.deckY) < 1e-9).toBe(true)
			expect(math.abs(below.z - plinth.center.z) < 1e-9).toBe(true)

			local street = ModelCityRules.modelPoint(plinth, center.x, 0, center.z)
			expect(math.abs(street.y - plinth.surfaceY) < 1e-9).toBe(true)
		end
	end)

	it("la placa dice el nombre de la ciudad", function()
		local plaque = ModelCityRules.plaque(viewOf(Fixtures.game({ players = 4 })))
		expect(plaque.title).toBe("Metrópolis")
		expect(plaque.effect).toBe(nil)
	end)
end)

describe("ModelCityRules.cards", function()
	it("una propiedad sin dueño no tiene tarjeta", function()
		local view = viewOf(Fixtures.game({ players = 4 }))
		local cards = ModelCityRules.cards(view, nil)
		local count = 0
		for _ in cards do
			count += 1
		end
		expect(count).toBe(0)
	end)

	it("una propiedad con dueño dice quién es, cuánto dinero tiene y su nivel", function()
		local state = Fixtures.game({ players = 4 })
		local index = firstProperty(state)
		Fixtures.give(state, "P2", index)
		state.properties[index].level = 3
		local view = viewOf(state)
		local seat = seatOf(view, "P2")
		local card = ModelCityRules.cards(view, { P2 = "Ana" })[index]
		expect(card.ownerId).toBe("P2")
		expect(card.name).toBe("Ana")
		expect(card.seat).toBe(seat)
		expect(card.cash).toBe(view.players[seat].cash)
		expect(card.level).toBe(3)
		expect(card.detail).toBe(`{view.players[seat].cash} · 3 casas`)
		expect(card.color).toBe(ModelCityRules.seatColor(seat))
	end)

	it("sin nombres conocidos, la tarjeta sigue nombrando al dueño por su asiento", function()
		local state = Fixtures.game({ players = 4 })
		local index = firstProperty(state)
		Fixtures.give(state, "P3", index)
		local view = viewOf(state)
		local card = ModelCityRules.cards(view, nil)[index]
		expect(card.name).toBe(`Jugador {seatOf(view, "P3")}`)
	end)

	it("un dueño que ya no está sentado conserva su tarjeta, sin asiento", function()
		local state = Fixtures.game({ players = 4 })
		local index = firstProperty(state)
		Fixtures.give(state, "P2", index)
		for seat, seated in state.players do
			if seated.id == "P2" then
				table.remove(state.players, seat)
				break
			end
		end
		local card = ModelCityRules.cards(viewOf(state), { P2 = "Ana" })[index]
		expect(card.name).toBe("Ana")
		expect(card.seat).toBe(nil)
		expect(card.cash).toBe(0)
		expect(card.color).toBe(ModelCityRules.colorForOwner("P2"))
	end)

	it("un dueño sin asiento recibe un color estable de la paleta", function()
		local color = ModelCityRules.colorForOwner("P2")
		expect(color).toBe(ModelCityRules.colorForOwner("P2"))
		expect(table.find(ModelCityRules.SEAT_COLORS, color) ~= nil).toBe(true)
	end)

	it("solo enseña las propiedades que siguen teniendo dueño", function()
		local state = Fixtures.game({ players = 4 })
		local first = firstProperty(state)
		Fixtures.give(state, "P2", first)
		state.properties[first].ownerId = nil
		local cards = ModelCityRules.cards(viewOf(state), nil)
		expect(cards[first]).toBe(nil)
	end)
end)

describe("ModelCityRules.cardDiff", function()
	local function states(): (any, number)
		local state = Fixtures.game({ players = 4 })
		local index = firstProperty(state)
		return state, index
	end

	it("crea la tarjeta cuando una propiedad se compra", function()
		local state, index = states()
		local before = ModelCityRules.cards(viewOf(state), nil)
		Fixtures.give(state, "P2", index)
		local after = ModelCityRules.cards(viewOf(state), nil)
		local changes = ModelCityRules.cardDiff(before, after)
		expect(#changes.added).toBe(1)
		expect(changes.added[1].index).toBe(index)
		expect(#changes.changed).toBe(0)
		expect(#changes.removed).toBe(0)
	end)

	it("actualiza la tarjeta cuando cambia el dinero o el nivel", function()
		local state, index = states()
		Fixtures.give(state, "P2", index)
		local before = ModelCityRules.cards(viewOf(state), nil)
		local seat = seatOf(viewOf(state), "P2")
		state.players[seat].cash += 250
		state.properties[index].level = 2
		local after = ModelCityRules.cards(viewOf(state), nil)
		local changes = ModelCityRules.cardDiff(before, after)
		expect(#changes.added).toBe(0)
		expect(#changes.changed).toBe(1)
		expect(changes.changed[1].cash).toBe(after[index].cash)
		expect(changes.changed[1].level).toBe(2)
	end)

	it("retira la tarjeta cuando la propiedad se queda sin dueño", function()
		local state, index = states()
		Fixtures.give(state, "P2", index)
		local before = ModelCityRules.cards(viewOf(state), nil)
		state.properties[index].ownerId = nil
		local after = ModelCityRules.cards(viewOf(state), nil)
		local changes = ModelCityRules.cardDiff(before, after)
		expect(#changes.added).toBe(0)
		expect(#changes.changed).toBe(0)
		expect(changes.removed).toEqual({ index })
	end)

	it("con la misma vista no toca nada", function()
		local state, index = states()
		Fixtures.give(state, "P2", index)
		local cards = ModelCityRules.cards(viewOf(state), nil)
		local changes = ModelCityRules.cardDiff(cards, cards)
		expect(#changes.added + #changes.changed + #changes.removed).toBe(0)
	end)
end)

describe("ModelCityRules.markers", function()
	it("hay un marcador por asiento, en su casilla y con el color de su asiento", function()
		local state = Fixtures.game({ players = 8 })
		local view = viewOf(state)
		local markers = ModelCityRules.markers(view)
		expect(#markers).toBe(8)
		for seat, marker in markers do
			expect(marker.seat).toBe(seat)
			expect(marker.id).toBe(view.players[seat].id)
			expect(marker.square).toBe(view.players[seat].position)
			expect(marker.color).toBe(ModelCityRules.seatColor(seat))
		end
	end)

	it("dos fichas en la misma casilla no se pisan", function()
		local state = Fixtures.game({ players = 4 })
		Fixtures.placeOn(state, "P1", 5)
		Fixtures.placeOn(state, "P2", 5)
		local shared: { ModelCityRules.Marker } = {}
		for _, marker in ModelCityRules.markers(viewOf(state)) do
			if marker.square == 5 then
				table.insert(shared, marker)
			end
		end
		expect(#shared).toBe(2)
		expect(shared[1].side ~= shared[2].side or shared[1].along ~= shared[2].along).toBe(true)
	end)

	it("el color del asiento se repite cada ocho asientos", function()
		expect(ModelCityRules.seatColor(9)).toBe(ModelCityRules.seatColor(1))
		expect(ModelCityRules.seatColor(0)).toBe(ModelCityRules.seatColor(8))
	end)
end)

describe("ModelCityRules.effectLine", function()
	it("sin efectos no hay línea", function()
		local view = viewOf(Fixtures.game({ players = 4 }))
		expect(ModelCityRules.effectLine(view)).toBe(nil)
	end)

	it("nombra la Zona Caliente activa", function()
		local state = Fixtures.game({ players = 4 })
		state.hotZoneId = "cobre"
		expect(ModelCityRules.effectLine(viewOf(state))).toBe("Zona Caliente: Callejón del Cobre")
	end)

	it("cuenta los efectos de mesa que no se nombran", function()
		local state = Fixtures.game({ players = 4 })
		state.modifiers = { { kind = "Inflation", untilRound = 4 } }
		expect(ModelCityRules.effectLine(viewOf(state))).toBe("1 efecto activo")
		table.insert(state.modifiers, { kind = "Strike", zoneId = "cobre", untilRound = 6 })
		expect(ModelCityRules.effectLine(viewOf(state))).toBe("2 efectos activos")
	end)

	it("una zona que no existe no rompe la placa", function()
		local state = Fixtures.game({ players = 4 })
		state.hotZoneId = "inventada"
		expect(ModelCityRules.effectLine(viewOf(state))).toBe(nil)
	end)
end)

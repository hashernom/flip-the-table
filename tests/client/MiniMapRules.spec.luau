--!strict
-- Pruebas del minimapa, con vistas salidas de `State` y `View`, no de tablas inventadas. El minimapa es lo
-- que responde a la pregunta central del juego: quién tiene qué y dónde está cada uno.
local Harness = require("../harness")
local Boards = require("../../src/shared/config/Boards")
local Economy = require("../../src/shared/config/Economy")
local Fixtures = require("../fixtures")
local MiniMapRules = require("../../src/client/ui/MiniMapRules")
local Property = require("../../src/shared/rules/Property")
local View = require("../../src/shared/rules/View")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function firstProperty(state: any): number
	for _, square in state.board.squares do
		if square.kind == "Property" then
			return square.index
		end
	end
	error("el tablero no tiene propiedades")
end

local function cellAt(cells: { any }, index: number): any
	for _, cell in cells do
		if cell.index == index then
			return cell
		end
	end
	error(`no hay celda {index}`)
end

describe("MiniMapRules.cells", function()
	it("hay una celda por casilla, en sitios distintos, en los tres tableros", function()
		for players, size in { [4] = "S", [6] = "M", [8] = "L" } do
			local view = View.forPlayer(Fixtures.game({ players = players }), "P1")
			local board = Boards.get(size :: any)
			expect(view.sizeId).toBe(size)
			local cells = MiniMapRules.cells(view)
			expect(#cells).toBe(#board.squares)
			local seen: { [string]: boolean } = {}
			for _, cell in cells do
				expect(cell.u >= 0 and cell.u <= 1).toBe(true)
				expect(cell.v >= 0 and cell.v <= 1).toBe(true)
				local key = `{cell.u},{cell.v}`
				expect(seen[key]).toBe(nil)
				seen[key] = true
			end
		end
	end)

	it("sin dueño ni nivel, y con el color de su zona", function()
		local state = Fixtures.game({ players = 4 })
		local index = firstProperty(state)
		local cell = cellAt(MiniMapRules.cells(View.forPlayer(state, "P1")), index)
		expect(cell.ownerSeat).toBe(nil)
		expect(cell.level).toBe(0)
		expect(type(cell.color)).toBe("string")
		expect(cell.isProperty).toBe(true)
	end)

	it("enseña el asiento del dueño y el nivel", function()
		local state = Fixtures.game({ players = 4 })
		local index = firstProperty(state)
		Fixtures.give(state, "P2", index)
		state.properties[index].level = Economy.maxBuildingLevel
		local view = View.forPlayer(state, "P1")
		local cell = cellAt(MiniMapRules.cells(view), index)
		expect(view.players[cell.ownerSeat].id).toBe("P2")
		expect(cell.level).toBe(Economy.maxBuildingLevel)
	end)

	it("pone cada ficha en su casilla y marca a quien le toca", function()
		local state = Fixtures.game({ players = 4 })
		Fixtures.placeOn(state, "P3", 9)
		Fixtures.turnOf(state, "P3")
		local view = View.forPlayer(state, "P1")
		local cells = MiniMapRules.cells(view)
		local cell = cellAt(cells, 9)
		expect(#cell.tokens).toBe(1)
		expect(view.players[cell.tokens[1]].id).toBe("P3")
		expect(cell.isTurn).toBe(true)
		expect(cellAt(cells, 1).isTurn).toBe(false)
		expect(#cellAt(cells, 1).tokens).toBe(3)
	end)

	it("todos los clientes ven lo mismo: no depende de quién mira", function()
		local state = Fixtures.game({ players = 4 })
		expect(MiniMapRules.cells(View.forPlayer(state, "P1"))).toEqual(
			MiniMapRules.cells(View.forPlayer(state, "P2"))
		)
	end)
end)

describe("MiniMapRules.detailLines", function()
	it("una propiedad libre dice su nombre y su precio", function()
		local state = Fixtures.game({ players = 4 })
		local index = firstProperty(state)
		local lines = MiniMapRules.detailLines(View.forPlayer(state, "P1"), nil, index)
		local text = table.concat(lines, "\n")
		expect(string.find(text, "Sin dueño", 1, true) ~= nil).toBe(true)
		expect(string.find(text, "Precio", 1, true) ~= nil).toBe(true)
	end)

	it("una propiedad con dueño dice la renta que cobra el motor", function()
		local state = Fixtures.game({ players = 4 })
		local index = firstProperty(state)
		Fixtures.give(state, "P2", index)
		state.properties[index].level = 2
		local expected = Property.rentFor(state, index)
		local text = table.concat(MiniMapRules.detailLines(View.forPlayer(state, "P1"), nil, index), "\n")
		expect(string.find(text, `Renta: {expected}`, 1, true) ~= nil).toBe(true)
		expect(string.find(text, "2 casas", 1, true) ~= nil).toBe(true)
	end)

	it("una casilla especial no enseña precio", function()
		local state = Fixtures.game({ players = 4 })
		local text = table.concat(MiniMapRules.detailLines(View.forPlayer(state, "P1"), nil, 1), "\n")
		expect(string.find(text, "Precio", 1, true) == nil).toBe(true)
	end)

	it("una casilla que no existe no revienta", function()
		local state = Fixtures.game({ players = 4 })
		expect(#MiniMapRules.detailLines(View.forPlayer(state, "P1"), nil, 999)).toBe(0)
	end)
end)

describe("MiniMapRules: casillas especiales", function()
	it("una casilla especial va en gris y lleva su tipo para pintar su símbolo", function()
		local Ui = require("../../src/shared/config/Ui")
		local view = View.forPlayer(Fixtures.game({ players = 4 }), "P1")
		local found = false
		for _, cell in MiniMapRules.cells(view) do
			expect(type(cell.kind)).toBe("string")
			if not cell.isProperty then
				found = true
				expect(cell.color).toBe(Ui.miniMap.specialColor)
			end
		end
		expect(found).toBe(true)
	end)
end)

describe("MiniMapRules: hipotecas", function()
	it("una propiedad hipotecada lo dice en su celda", function()
		local state = Fixtures.game({ players = 4 })
		local index = firstProperty(state)
		Fixtures.give(state, "P1", index)
		state.properties[index].mortgaged = true
		local cell = cellAt(MiniMapRules.cells(View.forPlayer(state, "P1")), index)
		expect(cell.mortgaged).toBe(true)
	end)
end)

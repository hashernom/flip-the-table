--!strict
-- Pruebas de las reglas puras de la ciudad en el cliente: qué propiedades cambiaron entre dos vistas,
-- dónde cae cada ficha de una misma casilla y qué piezas forman cada nivel de edificio. Las vistas
-- salen de `Engine` y `View`, no de tablas inventadas, para que un cambio de contrato las rompa.
local Harness = require("../harness")
local CityLayout = require("../../src/shared/config/CityLayout")
local Economy = require("../../src/shared/config/Economy")
local Fixtures = require("../fixtures")
local View = require("../../src/shared/rules/View")
local ViewWire = require("../../src/client/state/ViewWire")
local WorldRules = require("../../src/client/world/WorldRules")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function realView(): any
	return View.forPlayer(Fixtures.game({ players = 4 }), "P1")
end

describe("ViewWire.normalize", function()
	it("devuelve claves de número a las propiedades que un remoto pasó a texto", function()
		local view = { properties = { ["2"] = { level = 1, ownerId = "1" }, ["4"] = { level = 0 } } }
		ViewWire.normalize(view)
		expect(view.properties[2].level).toBe(1)
		expect(view.properties[4].level).toBe(0)
		expect((view.properties :: any)["2"]).toBe(nil)
	end)

	it("deja igual una vista real, que ya llega con números", function()
		local view = realView()
		local count = 0
		for _ in view.properties do
			count += 1
		end
		ViewWire.normalize(view)
		local after = 0
		for index in view.properties do
			expect(type(index)).toBe("number")
			after += 1
		end
		expect(after).toBe(count)
	end)

	it("no revienta sin vista o sin propiedades", function()
		expect(ViewWire.normalize(nil)).toBe(nil)
		expect(ViewWire.normalize({}).properties).toBe(nil)
	end)
end)

describe("WorldRules.propertyChanges", function()
	it("la primera vista solo informa de lo que tiene dueño o nivel", function()
		local changes = WorldRules.propertyChanges(nil, realView().properties)
		expect(#changes).toBe(0)
	end)

	it("detecta dueño y nivel nuevos, en orden de casilla", function()
		local before = { [2] = { level = 0 }, [4] = { level = 0 } }
		local after = { [2] = { level = 2, ownerId = "1" }, [4] = { level = 0, ownerId = "2" } }
		expect(WorldRules.propertyChanges(before, after)).toEqual({
			{ index = 2, ownerId = "1", level = 2 },
			{ index = 4, ownerId = "2", level = 0 },
		})
	end)

	it("detecta una venta sin evento, como la de una bancarrota (M11)", function()
		local before = { [2] = { level = 3, ownerId = "1" } }
		local after = { [2] = { level = 0 } }
		expect(WorldRules.propertyChanges(before, after)).toEqual({ { index = 2, level = 0 } })
	end)

	it("una partida nueva limpia lo que ya no está en la vista", function()
		local before = { [2] = { level = 3, ownerId = "1" } }
		expect(WorldRules.propertyChanges(before, {})).toEqual({ { index = 2, level = 0 } })
	end)

	it("sin cambios no devuelve nada", function()
		local same = { [2] = { level = 1, ownerId = "1" } }
		expect(#WorldRules.propertyChanges(same, { [2] = { level = 1, ownerId = "1" } })).toBe(0)
	end)
end)

describe("WorldRules.seatOf", function()
	it("el asiento es el orden en la vista, no la casilla", function()
		local view = realView()
		for seat, seated in view.players do
			expect(WorldRules.seatOf(view.players, seated.id)).toBe(seat)
		end
		expect(WorldRules.seatOf(view.players, "nadie")).toBe(nil)
	end)
end)

describe("WorldRules.tokenOffsets", function()
	it("sola en su casilla, la ficha va al centro", function()
		local offsets = WorldRules.tokenOffsets({ { id = "a", position = 3 }, { id = "b", position = 9 } })
		expect(offsets.a).toEqual({ side = 0, along = 0 })
		expect(offsets.b).toEqual({ side = 0, along = 0 })
	end)

	it("todas las de una vista inicial quedan en sitios distintos", function()
		local offsets = WorldRules.tokenOffsets(realView().players)
		local seen: { [string]: boolean } = {}
		for _, offset in offsets do
			local key = `{offset.side},{offset.along}`
			expect(seen[key]).toBe(nil)
			seen[key] = true
		end
	end)

	it("depende del asiento, así que todos los clientes ven lo mismo", function()
		local players = { { id = "a", position = 1 }, { id = "b", position = 1 }, { id = "c", position = 2 } }
		expect(WorldRules.tokenOffsets(players)).toEqual(WorldRules.tokenOffsets(players))
		expect(WorldRules.tokenOffsets(players).c).toEqual({ side = 0, along = 0 })
	end)
end)

describe("CityLayout.tokenOffset", function()
	it("ocho fichas caben en la casilla sin pisarse", function()
		local half = (CityLayout.SQUARE_SPACING_STUDS - 4) / 2
		local seen: { [string]: boolean } = {}
		for order = 1, 8 do
			local offset = CityLayout.tokenOffset(order, 8)
			expect(math.abs(offset.side) <= half).toBe(true)
			expect(math.abs(offset.along) <= half).toBe(true)
			local key = `{offset.side},{offset.along}`
			expect(seen[key]).toBe(nil)
			seen[key] = true
		end
	end)

	it("el grupo queda centrado en la casilla", function()
		for count = 1, 8 do
			local side, along = 0, 0
			for order = 1, count do
				local offset = CityLayout.tokenOffset(order, count)
				side += offset.side
				along += offset.along
			end
			-- Un carril incompleto no suma cero, pero nunca se aleja más de medio carril del centro.
			expect(math.abs(side / count) <= CityLayout.TOKEN_LANE_STUDS / 2).toBe(true)
			expect(math.abs(along / count) <= CityLayout.TOKEN_ROW_STUDS / 2).toBe(true)
		end
	end)
end)

describe("CityLayout.buildingBlocks", function()
	it("un solar sin nivel no tiene piezas", function()
		expect(#CityLayout.buildingBlocks(0)).toBe(0)
	end)

	it("una, dos y tres casas, hotel y rascacielos, como la escalera de la ficha", function()
		expect(#CityLayout.buildingBlocks(1)).toBe(1)
		expect(#CityLayout.buildingBlocks(2)).toBe(2)
		expect(#CityLayout.buildingBlocks(3)).toBe(3)
		expect(#CityLayout.buildingBlocks(4)).toBe(1)
		expect(#CityLayout.buildingBlocks(5)).toBe(1)
	end)

	it("hay una forma por cada nivel del motor, y ninguna de más", function()
		for level = 1, Economy.maxBuildingLevel do
			expect(#CityLayout.buildingBlocks(level) > 0).toBe(true)
		end
		expect(#CityLayout.buildingBlocks(Economy.maxBuildingLevel + 1)).toBe(0)
	end)

	it("cada paso se ve más alto o más ocupado que el anterior", function()
		local function height(level: number): number
			local top = 0
			for _, block in CityLayout.buildingBlocks(level) do
				top = math.max(top, block.height)
			end
			return top
		end
		expect(height(4) > height(3)).toBe(true)
		expect(height(5) > height(4)).toBe(true)
	end)

	it("usa las alturas de art/escala.md", function()
		expect(CityLayout.buildingBlocks(1)[1].height).toBe(15.2)
		expect(CityLayout.buildingBlocks(4)[1].height).toBe(36.5)
		expect(CityLayout.buildingBlocks(5)[1].height).toBe(92)
	end)

	it("todas las piezas caben en su solar y no se pisan entre ellas", function()
		for level = 1, Economy.maxBuildingLevel do
			local blocks = CityLayout.buildingBlocks(level)
			for order, block in blocks do
				expect(math.abs(block.along) + block.width / 2 <= CityLayout.LOT_WIDTH_STUDS / 2).toBe(true)
				expect(block.depth <= CityLayout.LOT_DEPTH_STUDS).toBe(true)
				local other = blocks[order + 1]
				if other ~= nil then
					expect(other.along - block.along >= (block.width + other.width) / 2).toBe(true)
				end
			end
		end
	end)
end)

describe("CityLayout.lotCenter", function()
	it("cae por fuera del anillo y fuera de la baldosa", function()
		local center = CityLayout.centerFor("S")
		for _, slot in CityLayout.routeFor("S") do
			local lot = CityLayout.lotCenter(slot)
			local fromCenter = math.max(math.abs(lot.x - center.x), math.abs(lot.z - center.z))
			local slotFromCenter =
				math.max(math.abs(slot.position.x - center.x), math.abs(slot.position.z - center.z))
			expect(fromCenter > slotFromCenter).toBe(true)
		end
	end)
end)

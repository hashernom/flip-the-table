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
		expect(offsets.a).toEqual({ side = CityLayout.SLOT_SIDE_STUDS, along = 0 })
		expect(offsets.b).toEqual({ side = CityLayout.SLOT_SIDE_STUDS, along = 0 })
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
		expect(WorldRules.tokenOffsets(players).c).toEqual({ side = CityLayout.SLOT_SIDE_STUDS, along = 0 })
	end)
end)

describe("CityLayout.tokenOffset", function()
	it("ocho fichas caben en su casilla pintada sin pisarse", function()
		local token = CityLayout.TOKEN_BASE_STUDS / 2
		local seen: { [string]: boolean } = {}
		for order = 1, 8 do
			local offset = CityLayout.tokenOffset(order, 8)
			expect(math.abs(offset.along) + token <= CityLayout.SLOT_LENGTH_STUDS / 2).toBe(true)
			expect(
				math.abs(offset.side - CityLayout.SLOT_SIDE_STUDS) + token <= CityLayout.SLOT_DEPTH_STUDS / 2
			).toBe(true)
			local key = `{offset.side},{offset.along}`
			expect(seen[key]).toBe(nil)
			seen[key] = true
		end
		expect(CityLayout.TOKEN_LANE_STUDS >= CityLayout.TOKEN_BASE_STUDS).toBe(true)
		expect(CityLayout.TOKEN_ROW_STUDS >= CityLayout.TOKEN_BASE_STUDS).toBe(true)
	end)

	it("el grupo queda centrado en la casilla", function()
		for count = 1, 8 do
			local side, along = 0, 0
			for order = 1, count do
				local offset = CityLayout.tokenOffset(order, count)
				side += offset.side - CityLayout.SLOT_SIDE_STUDS
				along += offset.along
			end
			-- Un carril incompleto no suma cero, pero nunca se aleja más de medio carril del centro.
			expect(math.abs(side / count) <= CityLayout.TOKEN_ROW_STUDS / 2).toBe(true)
			expect(math.abs(along / count) <= CityLayout.TOKEN_LANE_STUDS / 2).toBe(true)
		end
	end)
end)

describe("La calle y sus casillas pintadas", function()
	it("cada casilla deja asfalto a la vista hasta la siguiente", function()
		local gap = CityLayout.SQUARE_SPACING_STUDS - CityLayout.SLOT_LENGTH_STUDS
		expect(gap >= 8).toBe(true)
	end)

	it("no ocupa toda la calzada: la otra mitad queda libre", function()
		expect(CityLayout.SLOT_DEPTH_STUDS <= CityLayout.STREET_WIDTH_STUDS / 2).toBe(true)
		local edge = math.abs(CityLayout.SLOT_SIDE_STUDS) + CityLayout.SLOT_DEPTH_STUDS / 2
		expect(edge <= CityLayout.STREET_WIDTH_STUDS / 2).toBe(true)
	end)

	it("los edificios vecinos no se tocan", function()
		local base = CityLayout.buildingBlocks(0)[1]
		expect(CityLayout.SQUARE_SPACING_STUDS - base.width >= 8).toBe(true)
	end)

	it("la casilla cae del lado de su edificio, y el solar empieza tras la acera", function()
		for _, slot in CityLayout.routeFor("S") do
			local paint = CityLayout.slotCenter(slot)
			local lot = CityLayout.lotCenter(slot)
			local toPaint = math.sqrt((paint.x - slot.position.x) ^ 2 + (paint.z - slot.position.z) ^ 2)
			local toLot = math.sqrt((lot.x - slot.position.x) ^ 2 + (lot.z - slot.position.z) ^ 2)
			local paintToLot = math.sqrt((lot.x - paint.x) ^ 2 + (lot.z - paint.z) ^ 2)
			expect(math.abs(toPaint - math.abs(CityLayout.SLOT_SIDE_STUDS)) < 0.01).toBe(true)
			expect(math.abs(toLot - paintToLot - toPaint) < 0.01).toBe(true)
			expect(
				math.abs(
					toLot
						- CityLayout.LOT_DEPTH_STUDS / 2
						- CityLayout.STREET_WIDTH_STUDS / 2
						- CityLayout.SIDEWALK_STUDS
				) < 0.01
			).toBe(true)
		end
	end)
end)

describe("CityLayout.buildingBlocks", function()
	local function top(level: number): number
		local height = 0
		for _, block in CityLayout.buildingBlocks(level) do
			height = math.max(height, block.y + block.height)
		end
		return height
	end

	it("el edificio existe sin mejoras y se conserva en todos los niveles (R-P50)", function()
		local base = CityLayout.buildingBlocks(0)[1]
		expect(base ~= nil).toBe(true)
		for level = 1, Economy.maxBuildingLevel do
			expect(CityLayout.buildingBlocks(level)[1]).toEqual(base)
		end
	end)

	it("cada nivel añade algo y ninguno quita lo anterior", function()
		for level = 1, Economy.maxBuildingLevel do
			expect(#CityLayout.buildingBlocks(level) > #CityLayout.buildingBlocks(level - 1)).toBe(true)
		end
	end)

	it("sube un poco, no se convierte en otro edificio", function()
		for level = 1, Economy.maxBuildingLevel do
			expect(top(level) >= top(level - 1)).toBe(true)
		end
		expect(top(Economy.maxBuildingLevel) > top(0)).toBe(true)
		expect(top(Economy.maxBuildingLevel) <= top(0) * 1.5).toBe(true)
	end)

	it("todas las piezas caben en su solar", function()
		for level = 0, Economy.maxBuildingLevel do
			for _, block in CityLayout.buildingBlocks(level) do
				expect(math.abs(block.along) + block.width / 2 <= CityLayout.LOT_WIDTH_STUDS / 2).toBe(true)
				expect(math.abs(block.front) + block.depth / 2 <= CityLayout.LOT_DEPTH_STUDS / 2).toBe(true)
			end
		end
	end)
end)

describe("CityLayout.levelMarkers", function()
	it("solo el nivel máximo lleva marcador: un mojón", function()
		for level = 0, Economy.maxBuildingLevel - 1 do
			expect(#CityLayout.levelMarkers(level)).toBe(0)
		end
		local top = CityLayout.levelMarkers(Economy.maxBuildingLevel)
		expect(#top).toBe(1)
		expect(top[1].kind).toBe("Mojon")
		expect(top[1].height < 6).toBe(true)
		expect(#CityLayout.levelMarkers(Economy.maxBuildingLevel + 1)).toBe(0)
	end)

	it("van delante del edificio, dentro del solar y sin pisarse", function()
		local base = CityLayout.buildingBlocks(0)[1]
		for level = 1, Economy.maxBuildingLevel do
			local markers = CityLayout.levelMarkers(level)
			for order, marker in markers do
				expect(math.abs(marker.along) + marker.width / 2 <= CityLayout.LOT_WIDTH_STUDS / 2).toBe(true)
				expect(marker.front + marker.depth / 2 <= base.front - base.depth / 2).toBe(true)
				expect(math.abs(marker.front) + marker.depth / 2 <= CityLayout.LOT_DEPTH_STUDS / 2).toBe(true)
				local other = markers[order + 1]
				if other ~= nil then
					expect(other.along - marker.along >= (marker.width + other.width) / 2).toBe(true)
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

Harness.describe("CityLayout: marco pintado de la casilla", function()
	Harness.it("cruza el asfalto sin salirse, y caben las ocho fichas a lo largo", function()
		Harness.expect(CityLayout.PAINT_ACROSS_STUDS <= CityLayout.STREET_WIDTH_STUDS).toBe(true)
		Harness.expect(CityLayout.PAINT_ALONG_STUDS <= CityLayout.SQUARE_SPACING_STUDS).toBe(true)
		for order = 1, 8 do
			local offset = CityLayout.tokenOffset(order, 8)
			Harness.expect(math.abs(offset.along) + 3 <= CityLayout.PAINT_ALONG_STUDS / 2).toBe(true)
		end
	end)
end)

Harness.describe("WorldRules.roadPaintColor", function()
	Harness.it("no toca un color que ya se ve sobre el asfalto", function()
		local r, g, b = WorldRules.roadPaintColor(0.98, 0.8, 0.08)
		Harness.expect(r).toBe(0.98)
		Harness.expect(g).toBe(0.8)
		Harness.expect(b).toBe(0.08)
	end)

	Harness.it("aclara lo que se perdería en la calle hasta el mínimo de luz", function()
		local r, g, b = WorldRules.roadPaintColor(0.39, 0.45, 0.55)
		Harness.expect(math.abs(0.2126 * r + 0.7152 * g + 0.0722 * b - 0.5) < 1e-6).toBe(true)
		Harness.expect(b > r).toBe(true)
	end)
end)

Harness.describe("WorldRules.paintColor", function()
	Harness.it("rebaja un color puro a pintura vial sin perder su tono", function()
		local r, g, b = WorldRules.paintColor(0.86, 0.15, 0.15)
		Harness.expect(r < 0.7).toBe(true)
		Harness.expect(g > 0.15 and b > 0.15).toBe(true)
		Harness.expect(r > g).toBe(true)
	end)
	Harness.it("dos zonas distintas siguen siendo distintas", function()
		local r1 = WorldRules.paintColor(0.86, 0.15, 0.15)
		local r2 = WorldRules.paintColor(0.02, 0.71, 0.83)
		Harness.expect(math.abs(r1 - r2) > 0.2).toBe(true)
	end)
end)

Harness.describe("WorldRules.ownerTag", function()
	Harness.it("sin dueño no hay etiqueta", function()
		Harness.expect(WorldRules.ownerTag(nil, 0)).toBe(nil)
	end)
	Harness.it("dice el dueño y, si hay mejoras, el nivel", function()
		Harness.expect(WorldRules.ownerTag("Ana", 0)).toBe("Ana")
		Harness.expect(WorldRules.ownerTag("Ana", 3)).toBe("Ana · Nivel 3")
	end)
end)

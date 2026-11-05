--!strict
-- Reglas puras del HUD: tamaño de las placas de la mesa, formato del dinero, plazo, tinta sobre color y
-- escala. Lo demás es dibujo y se comprueba en Studio.
local Harness = require("../harness")
local HudRules = require("../../src/client/ui/HudRules")
local Strings = require("../../src/shared/config/Strings")
local Boards = require("../../src/shared/config/Boards")
local Ui = require("../../src/shared/config/Ui")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

describe("HudRules.slots: la mesa en la columna izquierda", function()
	it("las placas se reducen al subir de 3 a 4 y de 5 a 6 jugadores", function()
		expect(HudRules.tierFor(1).plateHeight).toBe(HudRules.tierFor(3).plateHeight)
		expect(HudRules.tierFor(3).plateHeight > HudRules.tierFor(4).plateHeight).toBe(true)
		expect(HudRules.tierFor(4).plateHeight).toBe(HudRules.tierFor(5).plateHeight)
		expect(HudRules.tierFor(5).plateHeight > HudRules.tierFor(6).plateHeight).toBe(true)
		expect(HudRules.tierFor(6).plateHeight).toBe(HudRules.tierFor(8).plateHeight)
	end)

	it("hay un sitio por jugador, en orden y sin solaparse", function()
		for count = 1, 8 do
			local slots = HudRules.slots(count, 1)
			expect(#slots).toBe(count)
			for index = 2, count do
				local previous = slots[index - 1]
				expect(slots[index].y >= previous.y + previous.height).toBe(true)
			end
		end
	end)

	it("solo la placa del turno es flecha, y es más alta que las demás", function()
		local slots = HudRules.slots(5, 2)
		expect(slots[2].isTurn).toBe(true)
		expect(slots[1].isTurn).toBe(false)
		expect(slots[2].height > slots[1].height).toBe(true)
	end)

	it("sin turno, como al acabar la partida, no hay flecha", function()
		for _, slot in HudRules.slots(4, nil) do
			expect(slot.isTurn).toBe(false)
		end
	end)

	it("ocho jugadores caben por encima de la mano y la calzada a la altura de referencia", function()
		local slots = HudRules.slots(8, 8)
		local last = slots[8]
		expect(last.y + last.height <= Ui.referenceViewport.y - Ui.roadHeight - Ui.handClearance).toBe(true)
	end)
end)

describe("HudRules.columnWidth", function()
	it("se ajusta al contenido más largo de la mesa", function()
		expect(HudRules.columnWidth({ 150, 190, 180 })).toBe(190)
	end)

	it("no baja del mínimo ni deja que un nombre largo se coma la ciudad", function()
		expect(HudRules.columnWidth({ 90 })).toBe(Ui.plateMinWidth)
		expect(HudRules.columnWidth({ 900 })).toBe(Ui.plateMaxWidth)
	end)
end)

describe("HudRules.formatMoney", function()
	it("separa los miles con punto, como pide la guía", function()
		expect(HudRules.formatMoney(0)).toBe("0")
		expect(HudRules.formatMoney(860)).toBe("860")
		expect(HudRules.formatMoney(1240)).toBe("1.240")
		expect(HudRules.formatMoney(1000000)).toBe("1.000.000")
	end)

	it("una deuda lleva el signo", function()
		expect(HudRules.formatMoney(-150)).toBe("−150")
	end)
end)

describe("HudRules.rollValue: el taxímetro", function()
	it("empieza en el valor viejo y acaba exactamente en el nuevo", function()
		expect(HudRules.rollValue(100, 340, 0)).toBe(100)
		expect(HudRules.rollValue(100, 340, 1)).toBe(340)
		expect(HudRules.rollValue(340, 100, 1)).toBe(100)
	end)

	it("pasa por enteros y nunca se sale del tramo", function()
		for step = 0, 20 do
			local value = HudRules.rollValue(1000, 860, step / 20)
			expect(value == math.floor(value)).toBe(true)
			expect(value >= 860 and value <= 1000).toBe(true)
		end
	end)
end)

describe("HudRules.deadline: la calzada del plazo", function()
	it("el vehículo sale del principio y llega al cono al agotarse", function()
		expect(HudRules.deadline(20, 20).progress).toBe(0)
		expect(HudRules.deadline(0, 20).progress).toBe(1)
		expect(HudRules.deadline(5, 20).progress).toBe(0.75)
	end)

	it("avisa solo en los últimos segundos", function()
		expect(HudRules.deadline(Ui.deadlineWarnSeconds + 1, 20).warn).toBe(false)
		expect(HudRules.deadline(Ui.deadlineWarnSeconds, 20).warn).toBe(true)
	end)

	it("no se sale del tramo con relojes desfasados", function()
		expect(HudRules.deadline(25, 20).progress).toBe(0)
		expect(HudRules.deadline(-3, 20).progress).toBe(1)
		expect(HudRules.deadline(-3, 20).seconds).toBe(0)
	end)
end)

describe("HudRules.inkFor: lo que se escribe sobre el color de una zona", function()
	it("el nombre grande se lee en las doce zonas, con al menos 3:1", function()
		for _, zoneId in Boards.get("L").zoneOrder do
			local color = Strings.zone(zoneId).color
			local ink = HudRules.inkFor(color)
			expect(HudRules.contrast(color, (Ui.palette :: any)[ink]) >= 3).toBe(true)
		end
	end)

	it("usa caliza sobre el carmesí y asfalto sobre el limón", function()
		expect(HudRules.inkFor("#DC2626")).toBe("limestone")
		expect(HudRules.inkFor("#FACC15")).toBe("asphalt")
	end)
end)

describe("HudRules.scaleFor", function()
	it("la referencia mide 1, y una pantalla mayor escala hacia arriba", function()
		expect(HudRules.scaleFor(Ui.referenceViewport.x, Ui.referenceViewport.y)).toBe(1)
		expect(HudRules.scaleFor(2880, 1800)).toBe(Ui.maxUiScale)
	end)

	it("nunca encoge: ninguna etiqueta baja de 12 píxeles", function()
		expect(HudRules.scaleFor(1280, 720)).toBe(1)
	end)
end)

describe("Paleta de la interfaz", function()
	it("es la de la guía de estilo y el verde fieltro no está", function()
		expect(Ui.palette.asphalt).toBe("#23272C")
		expect(Ui.palette.limestone).toBe("#EDE5D3")
		expect(Ui.palette.taxi).toBe("#F5C518")
		expect(Ui.palette.signal).toBe("#C4382B")
		expect(Ui.palette.works).toBe("#E07A3C")
		for _, hex in Ui.palette :: any do
			expect(hex ~= "#1F5B45").toBe(true)
		end
	end)
end)

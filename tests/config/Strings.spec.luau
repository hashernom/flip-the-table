--!strict
-- Pruebas de los textos y colores de la ciudad. Es el contenido que hace reconocible cada casilla
-- desde la calle: nombre de la zona, color de la zona, nombre de cada propiedad y etiqueta de las
-- casillas especiales. La fuente de verdad es docs/02-mvp/contenido-tablero.md.
local Harness = require("../harness")
local Boards = require("../../src/shared/config/Boards")
local Cards = require("../../src/shared/config/Cards")
local Perks = require("../../src/shared/config/Perks")
local Types = require("../../src/shared/rules/Types")
local Strings = require("../../src/shared/config/Strings")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local SIZES = { "S", "M", "L" } :: { Types.SizeId }

describe("Strings.get", function()
	it("una clave desconocida es un error, no un texto vacío", function()
		expect(function()
			Strings.get("no.existe")
		end).toThrow()
	end)

	it("sustituye los argumentos con nombre", function()
		expect(Strings.get("hud.round", { current = 7, max = 12 })).toBe("Ronda 7/12")
	end)

	it("un argumento que falta es un error: no se enseña una llave al jugador", function()
		expect(function()
			Strings.get("hud.round", { current = 7 })
		end).toThrow()
	end)

	it("toda carta tiene nombre y descripción", function()
		expect(#Cards.all).toBe(20)
		for _, card in Cards.all do
			expect(Strings.get(`card.{card.id}.name`)).toBe(card.name)
			expect(#Strings.get(`card.{card.id}.description`) > 0).toBe(true)
		end
	end)

	it("todo perk tiene nombre y descripción", function()
		expect(#Perks.all).toBe(12)
		for _, perk in Perks.all do
			expect(Strings.get(`perk.{perk.id}.name`)).toBe(perk.name)
			expect(Strings.get(`perk.{perk.id}.description`)).toBe(perk.description)
		end
	end)
end)

describe("Strings.eventTitle", function()
	it("todo evento del motor tiene título en español, y el recorrido no lleva", function()
		local events = {
			"RoundStarted",
			"FinalRoundsStarted",
			"PerkDrafted",
			"DiceRolled",
			"PassedStart",
			"PropertyBought",
			"RentPaid",
			"AuctionStarted",
			"AuctionWon",
			"AuctionNoSale",
			"BuildingChanged",
			"PropertyMortgaged",
			"PropertyUnmortgaged",
			"TradeCompleted",
			"PlayerArrested",
			"TribunalVerdict",
			"BankruptcyDeclared",
			"GhostActed",
			"GhostResurrected",
			"CardDrawn",
			"CardDiscarded",
			"CardPlayed",
			"CardBlocked",
			"HotZoneMoved",
			"BillboardResult",
			"DuelResolved",
			"PortalUsed",
			"MarketBought",
			"PactFormed",
			"PactEnded",
			"PactBroken",
			"CrownMoved",
			"FuryFilled",
			"GameEnded",
		}
		for _, id in events do
			local title = Strings.eventTitle(id)
			expect(#title > 0).toBe(true)
			expect(title ~= id).toBe(true)
		end
		expect(Strings.eventTitle("TokenMoved")).toBe("")
	end)

	it("una carta se anuncia por su nombre y un id desconocido no se enseña", function()
		expect(Strings.eventTitle("Hurricane")).toBe("Huracán")
		expect(Strings.eventTitle("NoExiste")).toBe("")
	end)
end)

describe("Strings.upper", function()
	it("pasa a mayúsculas las vocales con tilde y la eñe", function()
		expect(Strings.upper("María José")).toBe("MARÍA JOSÉ")
		expect(Strings.upper("Año común")).toBe("AÑO COMÚN")
		expect(Strings.upper("Distrito Carmesí")).toBe("DISTRITO CARMESÍ")
	end)
end)

describe("Strings: zonas", function()
	it("cada zona de la arquitectura tiene nombre, color y barrio", function()
		for _, zoneId in Boards.get("L").zoneOrder do
			local zone = Strings.zone(zoneId)
			expect(#zone.name > 0).toBe(true)
			expect(#zone.color == 7).toBe(true)
			expect(string.sub(zone.color, 1, 1)).toBe("#")
			expect(#zone.barrio > 0).toBe(true)
		end
	end)

	it("hay doce zonas y todas están en la ruta del tablero grande", function()
		if #Boards.get("L").zoneOrder ~= 12 then
			error("el tablero grande debería tener 12 zonas")
		end
		for _, zoneId in Boards.get("L").zoneOrder do
			expect(Strings.zone(zoneId).name ~= zoneId).toBe(true)
		end
	end)

	it("una zona desconocida es un error, no un nombre inventado", function()
		expect(function()
			Strings.zone("inexistente")
		end).toThrow()
	end)

	it("todos los colores son distintos entre sí", function()
		local seen: { [string]: boolean } = {}
		for _, zoneId in Boards.get("L").zoneOrder do
			local color = Strings.zone(zoneId).color
			expect(seen[color] == nil).toBe(true)
			seen[color] = true
		end
	end)
end)

describe("Strings: propiedades", function()
	it("cada zona tiene un nombre por propiedad", function()
		for _, zoneId in Boards.get("L").zoneOrder do
			local zone = Strings.zone(zoneId)
			for ordinal = 1, zone.properties do
				local name = Strings.property(zoneId, ordinal)
				expect(#name > 0).toBe(true)
			end
		end
	end)

	it("no hay dos propiedades con el mismo nombre", function()
		local seen: { [string]: boolean } = {}
		for _, zoneId in Boards.get("L").zoneOrder do
			for ordinal = 1, Strings.zone(zoneId).properties do
				local name = Strings.property(zoneId, ordinal)
				expect(seen[name] == nil).toBe(true)
				seen[name] = true
			end
		end
	end)

	it("hay 34 propiedades en el tablero grande", function()
		local total = 0
		for _, zoneId in Boards.get("L").zoneOrder do
			total += Strings.zone(zoneId).properties
		end
		expect(total).toBe(34)
	end)

	it("Cobre y Violeta tienen dos propiedades; el resto, tres", function()
		expect(Strings.zone("cobre").properties).toBe(2)
		expect(Strings.zone("violeta").properties).toBe(2)
		expect(Strings.zone("cian").properties).toBe(3)
		expect(Strings.zone("ocre").properties).toBe(3)
	end)

	it("Muelle Violeta son las dos Versalles", function()
		expect(Strings.property("violeta", 1)).toBe("Versalles 1")
		expect(Strings.property("violeta", 2)).toBe("Versalles 2")
	end)

	it("una propiedad fuera de la zona es un error", function()
		expect(function()
			Strings.property("cobre", 3)
		end).toThrow()
	end)
end)

describe("Strings: etiquetas de casilla", function()
	it("cada tipo de casilla tiene su etiqueta", function()
		local kinds: { Types.SquareKind } = {
			"Start",
			"Property",
			"Spin",
			"Market",
			"Duel",
			"Portal",
			"Billboard",
			"Tribunal",
			"Tax",
		}
		for _, kind in kinds do
			if (kind :: string) ~= "Property" then
				expect(#Strings.kind(kind :: any) > 0).toBe(true)
			end
		end
	end)

	it("la Salida se llama Salida y el Impuesto, Impuesto", function()
		expect(Strings.kind("Start")).toBe("Salida")
		expect(Strings.kind("Tax")).toBe("Impuesto")
	end)

	it("la etiqueta de una casilla de propiedad es el nombre de la propiedad", function()
		for _, sizeId in SIZES do
			local board = Boards.get(sizeId :: any)
			for index, square in board.squares do
				local label = Strings.squareLabel(square, index :: any)
				expect(#label > 0).toBe(true)
				if square.kind == "Property" then
					expect(label ~= Strings.kind(square.kind)).toBe(true)
				end
			end
		end
	end)

	it("el número de propiedad dentro de su zona elige el nombre", function()
		local board = Boards.get("S")
		local ordinals: { [number]: number } = {}
		for _, indices in board.zones do
			for ordinal, index in indices do
				ordinals[index] = ordinal
			end
		end
		for index, square in board.squares do
			if square.kind == "Property" then
				local expected = Strings.property(square.zoneId :: string, ordinals[index])
				expect(Strings.squareLabel(square, ordinals[index])).toBe(expected)
			end
		end
	end)
end)

--!strict
-- Podio del final (M12 de la auditoría) con un `GameEnded` real: el que emite el motor al acabar la
-- última ronda, tal como llega al cliente tras `View.filterEvents`.
local Harness = require("../harness")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Score = require("../../src/shared/rules/Score")
local Strings = require("../../src/shared/config/Strings")
local Types = require("../../src/shared/rules/Types")
local View = require("../../src/shared/rules/View")
local ViewText = require("../../src/client/ui/ViewText")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local NAMES: { [string]: string } = { P1 = "Ana", P2 = "Beto", P3 = "Cleo" }

-- Lleva la partida a su final por el camino de verdad: el último jugador de la última ronda termina su
-- turno. Devuelve el evento tal como lo recibe `viewerId`.
local function finished(state: Types.GameState, viewerId: Types.PlayerId): (any, any)
	state.round = state.maxRounds :: number
	local last = state.players[#state.players]
	Fixtures.turnOf(state, last.id)
	state.phase = "AwaitEnd"
	local result = Engine.apply(state, last.id, { type = "EndTurn" })
	if not result.ok then
		error(result.error, 2)
	end
	for _, event in View.filterEvents(state, viewerId, result.events) do
		if event.type == "GameEnded" then
			return event, View.forPlayer(state, viewerId)
		end
	end
	error("la partida no emitió GameEnded", 2)
end

local function contains(text: string, part: string): boolean
	return string.find(text, part, 1, true) ~= nil
end

describe("ViewText.podiumLines", function()
	it("nombra al ganador y ordena a todos por la clasificación del motor", function()
		local state = Fixtures.game({ players = 3, seed = 50 })
		state.players[1].cash = 3000
		local event, view = finished(state, "P1")
		local lines = ViewText.podiumLines(event, view, NAMES)
		expect(lines[1]).toBe(
			`Ganador: {NAMES[event.winnerId]}{if event.winnerId == "P1" then " (tú)" else ""}`
		)
		expect(#event.ranking).toBe(3)
		for position, id in event.ranking do
			local line = lines[1 + position]
			expect(contains(line, `{position}. {NAMES[id]}`)).toBe(true)
			-- El patrimonio mostrado es el del motor sobre el estado final.
			expect(contains(line, `patrimonio {Score.netWorth(state, id)}`)).toBe(true)
		end
		expect(event.ranking[1]).toBe("P1")
	end)

	it("los premios salen con su nombre en español y el de su ganador", function()
		local state = Fixtures.game({ players = 3, seed = 50 })
		state.stats.P2.pactsBroken = 2
		state.stats.P3.rentsPaid = 4
		local event, view = finished(state, "P1")
		expect(#event.awards).toBe(2)
		local text = table.concat(ViewText.podiumLines(event, view, NAMES), "\n")
		expect(contains(text, `{Strings.award("MostTreacherous")}: Beto`)).toBe(true)
		expect(contains(text, `{Strings.award("VictimOfTheNight")}: Cleo`)).toBe(true)
		expect(Strings.award("MostTreacherous")).toBe("Mayor Traidor")
		expect(Strings.award("BestComeback")).toBe("Mejor Remontada")
		expect(Strings.award("VictimOfTheNight")).toBe("Víctima de la Noche")
	end)

	it("sin premios con datos no hay líneas de premios", function()
		local state = Fixtures.game({ players = 3, seed = 51 })
		local event, view = finished(state, "P1")
		expect(#event.awards).toBe(0)
		expect(#ViewText.podiumLines(event, view, NAMES)).toBe(1 + #event.ranking)
	end)

	it("un premio que el cliente aún no conoce se muestra con su id, no rompe", function()
		local view = View.forPlayer(Fixtures.game({ players = 3, seed = 52 }), "P1")
		local event = {
			type = "GameEnded",
			ranking = {},
			winnerId = "P2",
			awards = { { id = "NuevoPremio", playerId = "P2" } },
		}
		local lines = ViewText.podiumLines(event, view, NAMES)
		expect(lines[#lines]).toBe("NuevoPremio: Beto")
	end)

	it("sin evento no hay podio", function()
		local view = View.forPlayer(Fixtures.game({ players = 3, seed = 52 }), "P1")
		expect(ViewText.podiumLines(nil, view, NAMES)).toEqual({})
	end)
end)

describe("ViewText.podium", function()
	it("da ganador, puestos con patrimonio y premios por separado", function()
		local state = Fixtures.game({ players = 3, seed = 50 })
		state.players[1].cash = 3000
		local event, view = finished(state, "P1")
		local podium = ViewText.podium(event, view, NAMES)
		expect(podium.winnerId).toBe(event.winnerId)
		expect(#podium.ranking).toBe(3)
		for position, id in event.ranking do
			local row = podium.ranking[position]
			expect(row.id).toBe(id)
			expect(row.position).toBe(position)
			expect(row.worth).toBe(Score.netWorth(state, id))
			expect(contains(row.name, NAMES[id])).toBe(true)
		end
		expect(#podium.awards).toBe(#(event.awards or {}))
	end)

	it("sin evento no hay podio", function()
		local podium = ViewText.podium(nil, nil, NAMES)
		expect(podium.winnerId).toBe(nil)
		expect(#podium.ranking).toBe(0)
	end)
end)

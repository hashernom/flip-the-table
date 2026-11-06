--!nocheck
-- Cobertura de Scenes (R-P23): recorre src/shared/rules buscando literales `type = "..."` y exige
-- escena para cada evento. Si el motor añade un evento sin duración, esta prueba rompe la puerta.
-- Usa @lune/fs, así que va sin comprobación de tipos como las demás pruebas de herramientas; el
-- nombre conserva el filtro `lune run tests/run SceneClock` de la tarea.
local fs = require("@lune/fs")

local Harness = require("../harness")
local Scenes = require("../../src/shared/config/Scenes")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local RULES_DIR = "src/shared/rules"

-- Las 24 acciones de la arquitectura no son eventos y no llevan escena. Se excluyen del barrido
-- porque también se escriben como literales `type = "..."` en las tablas del motor.
local ACTIONS: { [string]: boolean } = {
	DraftPerk = true,
	Roll = true,
	RerollDie = true,
	Buy = true,
	DeclineBuy = true,
	Bid = true,
	PlayCard = true,
	React = true,
	PassReaction = true,
	Build = true,
	SellBuilding = true,
	Mortgage = true,
	Unmortgage = true,
	ProposeTrade = true,
	RespondTrade = true,
	ProposePact = true,
	RespondPact = true,
	BreakPact = true,
	TribunalVote = true,
	DuelChoice = true,
	MarketBuy = true,
	MarketSkip = true,
	GhostAct = true,
	EndTurn = true,
}

-- Todos los literales `type = "Nombre"` de los módulos del motor, sin acciones y sin repetir.
local function eventTypes(): { string }
	local found: { [string]: boolean } = {}
	local events: { string } = {}
	for _, name in fs.readDir(RULES_DIR) do
		local path = `{RULES_DIR}/{name}`
		if not fs.isDir(path) and string.sub(name, -5) == ".luau" then
			local source = fs.readFile(path)
			for eventType in string.gmatch(source, 'type%s*=%s*"([A-Z][A-Za-z]+)"') do
				if not ACTIONS[eventType] and not found[eventType] then
					found[eventType] = true
					table.insert(events, eventType)
				end
			end
		end
	end
	table.sort(events)
	return events
end

describe("Scenes: cobertura de eventos", function()
	it("encuentra los eventos del motor", function()
		local events = eventTypes()
		-- El motor emite 33 tipos de evento; el mínimo solo demuestra que el barrido encontró el
		-- catálogo y no un conjunto vacío por un patrón roto.
		expect(#events >= 30).toBeTruthy()
		expect(table.find(events, "GameEnded") ~= nil).toBeTruthy()
		expect(table.find(events, "CardPlayed") ~= nil).toBeTruthy()
	end)

	it("todo evento del motor tiene escena y duración positiva", function()
		for _, eventType in eventTypes() do
			local duration = Scenes.baseDuration(eventType)
			if duration == nil then
				error(`Scenes no da escena al evento {eventType}`, 2)
			end
			expect(duration > 0).toBeTruthy()
		end
	end)
end)

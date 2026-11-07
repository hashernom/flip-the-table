--!strict
-- Gestionar propiedades (R-P53): qué propiedades recorre el menú, cómo se navega y qué botones enseña.
local Harness = require("../harness")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local HudRules = require("../../src/client/ui/HudRules")
local Property = require("../../src/shared/rules/Property")
local PropertyManagerRules = require("../../src/client/ui/PropertyManagerRules")
local ActionMenuRules = require("../../src/client/ui/ActionMenuRules")
local View = require("../../src/shared/rules/View")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function properties(state: any): { number }
	local out = {}
	for _, square in state.board.squares do
		if square.kind == "Property" then
			table.insert(out, square.index)
		end
	end
	return out
end

describe("PropertyManagerRules", function()
	it("recorre solo las propiedades propias, en orden de ruta", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[s.turnIndex]
		local list = properties(s)
		Fixtures.give(s, a.id, list[3])
		Fixtures.give(s, a.id, list[1])
		local view = View.forPlayer(s, a.id)
		expect(PropertyManagerRules.owned(view, a.id)).toEqual({ list[1], list[3] })
	end)

	it("las flechas dan la vuelta en los dos sentidos", function()
		expect(PropertyManagerRules.step({ 4, 9, 12 }, 12, 1)).toBe(4)
		expect(PropertyManagerRules.step({ 4, 9, 12 }, 4, -1)).toBe(12)
		expect(PropertyManagerRules.step({ 4, 9, 12 }, 9, 1)).toBe(12)
		expect(PropertyManagerRules.step({}, nil, 1)).toBe(nil)
	end)

	it("enseña los cuatro botones y solo activa los legales", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[s.turnIndex]
		local idx = properties(s)[1]
		Fixtures.give(s, a.id, idx)
		local view = View.forPlayer(s, a.id)
		local _, byIndex = ActionMenuRules.splitManageActions(Engine.legalActions(s, a.id))
		local info = PropertyManagerRules.info(view, idx, byIndex[idx])
		local kinds, enabled = {}, {}
		for _, button in info.buttons do
			table.insert(kinds, button.kind)
			enabled[button.kind] = button.action ~= nil
		end
		expect(kinds).toEqual({ "Build", "SellBuilding", "Mortgage", "Unmortgage" })
		expect(enabled.Mortgage).toBe(true)
		expect(enabled.Unmortgage).toBe(false)
		expect(enabled.SellBuilding).toBe(false)
		expect(info.mortgaged).toBe(false)
		expect(info.rent > 0).toBe(true)
	end)

	it("una hipotecada dice que no cobra renta", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[s.turnIndex]
		local idx = properties(s)[1]
		Fixtures.give(s, a.id, idx)
		s.properties[idx].mortgaged = true
		local info = PropertyManagerRules.info(View.forPlayer(s, a.id), idx, nil)
		expect(info.mortgaged).toBe(true)
		expect(info.rent).toBe(0)
	end)

	it("enseña la renta que se cobra ahora, no la de la tabla impresa", function()
		local s = Fixtures.game({ players = 2 })
		local a = s.players[s.turnIndex]
		local idx = properties(s)[1]
		local square = s.board.squares[idx]
		local zoneId = square.zoneId :: string
		for _, member in s.board.zones[zoneId] do
			Fixtures.give(s, a.id, member)
		end
		local info = PropertyManagerRules.info(View.forPlayer(s, a.id), idx, nil)
		-- Con la zona completa la vista ya trae el ×2; la tabla impresa sigue en la renta sin grupo.
		local printed = Property.rentTable(square.price :: number)[1] or 0
		expect(info.rent).toBe(Property.rentFor(s, idx))
		expect(info.rent > printed).toBe(true)
		expect(info.rentText).toBe(HudRules.formatMoney(info.rent))
	end)
end)

--!strict
-- Pruebas de las reglas del menú de acciones. Son puras: convierten las acciones legales que manda el
-- servidor en botones y deciden cuándo hace falta el control de puja. Cubren los criterios de la
-- Tarea 5 que se pueden comprobar sin Studio: un botón solo existe si su acción es legal, y la puja
-- aparece con su control y con sus límites.
local Harness = require("../harness")
local ActionMenuRules = require("../../src/client/ui/ActionMenuRules")
local Economy = require("../../src/shared/config/Economy")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function ids(legal: { any }): { string }
	local out: { string } = {}
	for _, button in ActionMenuRules.buttonsFor(legal) do
		table.insert(out, button.id)
	end
	return out
end

describe("ActionMenuRules.buttonsFor", function()
	it("sin acciones legales no hay ningún botón", function()
		expect(ActionMenuRules.buttonsFor({})).toEqual({})
	end)

	it("sin compra legal no hay botón de compra", function()
		local legal = { { type = "Roll" }, { type = "EndTurn" } }
		local buttonIds = ids(legal)
		expect(table.find(buttonIds, "Buy")).toBe(nil)
		expect(table.find(buttonIds, "Roll") ~= nil).toBe(true)
	end)

	it("con compra legal aparece el botón de compra", function()
		local buttonIds = ids({ { type = "Buy" } })
		expect(buttonIds).toEqual({ "Buy" })
	end)

	it("cada acción legal tiene exactamente un botón, en el orden que llega", function()
		local legal = { { type = "Roll" }, { type = "Buy" }, { type = "DeclineBuy" }, { type = "EndTurn" } }
		expect(ids(legal)).toEqual({ "Roll", "Buy", "DeclineBuy", "EndTurn" })
	end)

	it("cada botón lleva la acción que enviará al servidor", function()
		local legal = { { type = "Build", index = 7 } }
		local buttons = ActionMenuRules.buttonsFor(legal)
		expect(#buttons).toBe(1)
		expect(buttons[1].action.index).toBe(7)
		expect(buttons[1].action.type).toBe("Build")
	end)

	it("varias acciones del mismo tipo dan un botón por cada una", function()
		local legal = { { type = "Build", index = 3 }, { type = "Build", index = 9 } }
		local buttons = ActionMenuRules.buttonsFor(legal)
		expect(#buttons).toBe(2)
		expect(buttons[1].id ~= buttons[2].id).toBe(true)
		expect(buttons[1].label ~= buttons[2].label).toBe(true)
	end)

	it("una acción que las reglas no conocen sigue teniendo su botón", function()
		-- Esconder una acción legal dejaría al jugador sin salida: se muestra con su tipo por nombre.
		local buttonIds = ids({ { type = "AccionFutura" } })
		expect(buttonIds).toEqual({ "AccionFutura" })
	end)

	it("todas las acciones de la arquitectura tienen etiqueta en español", function()
		local actions = {
			"DraftPerk",
			"Roll",
			"RerollDie",
			"Buy",
			"DeclineBuy",
			"PlayCard",
			"React",
			"PassReaction",
			"Build",
			"RespondTrade",
			"ProposePact",
			"RespondPact",
			"BreakPact",
			"TribunalVote",
			"DuelChoice",
			"MarketBuy",
			"MarketSkip",
			"GhostAct",
			"EndTurn",
		}
		for _, actionType in actions do
			local label = ActionMenuRules.labelFor({ type = actionType } :: any)
			expect(label ~= actionType).toBe(true)
			expect(#label > 0).toBe(true)
		end
	end)

	it("el botón de una carta lleva el nombre de la carta", function()
		local label = ActionMenuRules.labelFor({ type = "PlayCard", cardId = "Hurricane" } :: any)
		expect(string.find(label, "Hurricane", 1, true) ~= nil).toBe(true)
	end)
end)

describe("ActionMenuRules: puja", function()
	it("con una puja legal hay control de puja", function()
		local control = ActionMenuRules.bidControl({ { type = "Bid", amount = 240 } })
		expect(control ~= nil).toBe(true)
		local bounds = control :: any
		expect(bounds.max).toBe(240)
		expect(bounds.min).toBe(Economy.auctionBidStep)
		expect(bounds.step).toBe(Economy.auctionBidStep)
	end)

	it("sin puja legal no hay control de puja", function()
		expect(ActionMenuRules.bidControl({ { type = "Roll" } })).toBe(nil)
		expect(ActionMenuRules.bidControl({})).toBe(nil)
	end)

	it("la puja legal nunca deja un rango vacío", function()
		-- Si el servidor enumera una puja por debajo del paso, el control sigue teniendo un valor.
		local bounds = ActionMenuRules.bidControl({ { type = "Bid", amount = 3 } }) :: any
		expect(bounds.min).toBe(1)
		expect(bounds.max >= bounds.min).toBe(true)
	end)

	it("el control de puja no aparece como botón suelto", function()
		local buttonIds = ids({ { type = "Bid", amount = 200 } })
		expect(table.find(buttonIds, "Bid")).toBe(nil)
		expect(table.find(buttonIds, "BidConfirm") ~= nil).toBe(true)
	end)
end)

describe("ActionMenuRules: temporizador", function()
	it("la cuenta atrás de una decisión se calcula con el reloj del servidor", function()
		expect(ActionMenuRules.remainingSeconds(110, 100)).toBe(10)
		expect(ActionMenuRules.remainingSeconds(100, 110)).toBe(0)
	end)

	it("sin plazo conocido no se inventa una cuenta atrás", function()
		expect(ActionMenuRules.remainingSeconds(nil, 100)).toBe(nil)
	end)
end)

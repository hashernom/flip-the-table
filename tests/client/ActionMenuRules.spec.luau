--!strict
-- Pruebas de las reglas del menú de acciones. Son puras: convierten las acciones legales que manda el
-- servidor en botones y deciden cuándo hace falta el control de puja. Cubren los criterios de la
-- Tarea 5 que se pueden comprobar sin Studio: un botón solo existe si su acción es legal, y la puja
-- aparece con su control y con sus límites.
local Harness = require("../harness")
local ActionMenuRules = require("../../src/client/ui/ActionMenuRules")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Property = require("../../src/shared/rules/Property")
local Types = require("../../src/shared/rules/Types")
local View = require("../../src/shared/rules/View")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function ids(legal: { any }): { string }
	local out: { string } = {}
	for _, button in ActionMenuRules.buttonsFor(legal) do
		table.insert(out, button.id)
	end
	return out
end

describe("Property.rentTable", function()
	it("imprime la renta sin mejoras y la de cada nivel", function()
		expect(Property.rentTable(260)).toEqual({ 30, 105, 260, 625, 1250, 1665 })
	end)
end)

describe("ActionMenuRules.panelFor", function()
	it("sin acciones no hay nada que enseñar", function()
		local panel = ActionMenuRules.panelFor({})
		expect(panel.primary).toBe(nil)
		expect(#panel.options).toBe(0)
	end)

	it("comprar es el botón principal y renunciar va aparte", function()
		local panel = ActionMenuRules.panelFor({ { type = "Buy" }, { type = "DeclineBuy" } })
		expect((panel.primary :: any).id).toBe("Buy")
		expect(panel.primaryText).toBe("Comprar")
		expect((panel.decline :: any).id).toBe("DeclineBuy")
		expect(#panel.options).toBe(0)
	end)

	it("hay un solo botón principal y ninguna acción legal se pierde", function()
		local legal = {
			{ type = "EndTurn" },
			{ type = "Roll" },
			{ type = "PlayCard", cardId = "Fine" },
			{ type = "Build", index = 2 },
		}
		local panel = ActionMenuRules.panelFor(legal)
		expect((panel.primary :: any).id).toBe("Roll")
		expect(#panel.options).toBe(3)
	end)

	it("sin acción principal, todas son opciones", function()
		local panel = ActionMenuRules.panelFor({
			{ type = "DraftPerk", perkId = "Banker" },
			{ type = "DraftPerk", perkId = "Lawyer" },
		})
		expect(panel.primary).toBe(nil)
		expect(#panel.options).toBe(2)
	end)

	it("la puja propone el mínimo y conserva su control", function()
		local panel = ActionMenuRules.panelFor({ { type = "Bid", amount = 120 } })
		expect(panel.primaryText).toBe("Pujar 120")
		expect((panel.bid :: any).min).toBe(120)
	end)
end)

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
		local action: any = buttons[1].action
		expect(action.index).toBe(7)
		expect(action.type).toBe("Build")
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

describe("ActionMenuRules.offerText", function()
	-- La oferta sale del motor y de la vista reales: el fallo original era leer un campo que no existe.
	local function offerFromEngine(offer: { [string]: any }): any
		local state = Fixtures.game({ players = 3, seed = 3 })
		local from, to = state.players[1].id, state.players[2].id
		for _, index in offer.giveSquares do
			Fixtures.give(state, from, index)
		end
		for _, index in offer.wantSquares do
			Fixtures.give(state, to, index)
		end
		offer.toId = to
		local result = Engine.apply(state, from, { type = "ProposeTrade", offer = offer })
		if not result.ok then
			error(result.error, 2)
		end
		return (View.forPlayer(state, to).pending :: any).trades[1]
	end

	it("describe dinero por nada", function()
		local trade = offerFromEngine({ giveCash = 50, wantCash = 0, giveSquares = {}, wantSquares = {} })
		expect(ActionMenuRules.offerText(trade)).toBe("50 por nada")
	end)

	it("describe casillas y dinero en los dos lados", function()
		local trade =
			offerFromEngine({ giveCash = 100, wantCash = 200, giveSquares = { 2, 3 }, wantSquares = { 6 } })
		expect(ActionMenuRules.offerText(trade)).toBe("100 + casillas 2, 3 por 200 + casilla 6")
	end)

	it("con un nombrador de casillas, las casillas salen por su nombre", function()
		local trade =
			offerFromEngine({ giveCash = 0, wantCash = 75, giveSquares = { 2, 3 }, wantSquares = {} })
		local text = ActionMenuRules.offerText(trade, function(index: number): string
			return `C{index}`
		end)
		expect(text).toBe("C2, C3 por 75")
	end)

	it("describe casillas sin dinero, sin signos de más", function()
		local trade = offerFromEngine({ giveCash = 0, wantCash = 75, giveSquares = { 2 }, wantSquares = {} })
		expect(ActionMenuRules.offerText(trade)).toBe("casilla 2 por 75")
	end)
end)

describe("ActionMenuRules: puja", function()
	-- El límite inferior es la puja que enumera el motor y el superior, el efectivo del jugador: así
	-- una puja de 210 contra una alta de 200 no obliga a 20 pulsaciones. B5 de la auditoría.
	it("con una puja legal hay control de puja", function()
		local control = ActionMenuRules.bidControl({ { type = "Bid", amount = 240 } }, 900)
		expect(control ~= nil).toBe(true)
		local bounds = control :: any
		expect(bounds.min).toBe(240)
		expect(bounds.max).toBe(900)
		expect(bounds.step).toBe(Economy.auctionBidStep)
		expect(bounds.jump).toBe(Economy.auctionBidJump)
	end)

	it("sin puja legal no hay control de puja", function()
		expect(ActionMenuRules.bidControl({ { type = "Roll" } }, 500)).toBe(nil)
		expect(ActionMenuRules.bidControl({}, 500)).toBe(nil)
	end)

	it("la puja legal nunca deja un rango vacío", function()
		-- Si el servidor enumera una puja y el efectivo no la alcanza (vista incoherente), el rango
		-- sigue teniendo un valor: el mínimo.
		local bounds = ActionMenuRules.bidControl({ { type = "Bid", amount = 3 } }, 2) :: any
		expect(bounds.min).toBe(3)
		expect(bounds.max >= bounds.min).toBe(true)
		local noCash = ActionMenuRules.bidControl({ { type = "Bid", amount = 3 } }) :: any
		expect(noCash.max >= noCash.min).toBe(true)
	end)

	it("el control de puja no aparece como botón suelto", function()
		local buttonIds = ids({ { type = "Bid", amount = 200 } })
		expect(table.find(buttonIds, "Bid")).toBe(nil)
		expect(table.find(buttonIds, "BidConfirm") ~= nil).toBe(true)
	end)

	it("conserva lo elegido entre vistas y lo acota al rango nuevo", function()
		local control = { min = 210, max = 900, step = 10, jump = 50 }
		expect(ActionMenuRules.clampBid(nil, control)).toBe(210)
		expect(ActionMenuRules.clampBid(400, control)).toBe(400)
		-- La puja alta subió por encima de lo elegido: se sube al mínimo nuevo.
		expect(ActionMenuRules.clampBid(300, { min = 350, max = 900, step = 10, jump = 50 })).toBe(350)
		-- El efectivo bajó por debajo de lo elegido: se baja al máximo.
		expect(ActionMenuRules.clampBid(800, { min = 210, max = 600, step = 10, jump = 50 })).toBe(600)
	end)

	it("con una subasta real, cualquier puja entre el mínimo y el efectivo la acepta el motor", function()
		-- Subasta abierta con una puja alta de 200 del segundo jugador.
		local function auction(): Types.GameState
			local state = Fixtures.game({ players = 3, seed = 7 })
			local pending: any = state.pending
			pending.index = Fixtures.squareOf(state, "Property")
			state.phase = "AwaitBuy"
			Engine.apply(state, state.players[state.turnIndex].id, { type = "DeclineBuy" })
			Engine.apply(state, state.players[2].id, { type = "Bid", amount = 200 })
			return state
		end

		it("quien va ganando la subasta conserva el panel y lo ve dicho", function()
			local state = auction()
			local leader = state.players[2]
			local view = View.forPlayer(state, leader.id)
			local buttons = ActionMenuRules.buttonsFor(view.legalActions, { view = view })
			expect(#buttons).toBe(1)
			expect(buttons[1].id).toBe("BidLeading")
			expect(buttons[1].label).toBe("Vas ganando con 200")
			expect(buttons[1].action).toBe(nil)
		end)

		local state = auction()
		local rival = state.players[3]
		local view = View.forPlayer(state, rival.id)
		local bounds = ActionMenuRules.bidControl(view.legalActions, rival.cash) :: any
		expect(bounds.min).toBe(210)
		expect(bounds.max).toBe(rival.cash)
		for _, amount in { bounds.min, bounds.min + bounds.jump, bounds.max } do
			local copy = auction()
			expect(Engine.apply(copy, rival.id, { type = "Bid", amount = amount }).ok).toBe(true)
		end
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

describe("ActionMenuRules.needsConfirm", function()
	-- Solo las acciones sin vuelta atrás piden una segunda pulsación; el resto se manda al primer toque.
	it("romper un pacto pide confirmación", function()
		expect(ActionMenuRules.needsConfirm({ type = "BreakPact", pactId = "p1" } :: any)).toBe(true)
	end)

	it("no comprar pide confirmación", function()
		expect(ActionMenuRules.needsConfirm({ type = "DeclineBuy" } :: any)).toBe(true)
	end)

	it("responder un trato pide confirmación, aceptando o rechazando", function()
		expect(ActionMenuRules.needsConfirm({ type = "RespondTrade", accept = true } :: any)).toBe(true)
		expect(ActionMenuRules.needsConfirm({ type = "RespondTrade", accept = false } :: any)).toBe(true)
	end)

	it("rechazar un pacto pide confirmación, aceptarlo no", function()
		expect(ActionMenuRules.needsConfirm({ type = "RespondPact", pactId = "p1", accept = false } :: any)).toBe(
			true
		)
		expect(ActionMenuRules.needsConfirm({ type = "RespondPact", pactId = "p1", accept = true } :: any)).toBe(
			false
		)
	end)

	it("comprar, tirar y terminar el turno se mandan al primer toque", function()
		expect(ActionMenuRules.needsConfirm({ type = "Buy" } :: any)).toBe(false)
		expect(ActionMenuRules.needsConfirm({ type = "Roll" } :: any)).toBe(false)
		expect(ActionMenuRules.needsConfirm({ type = "EndTurn" } :: any)).toBe(false)
	end)

	it("proponer un pacto no pide confirmación", function()
		expect(ActionMenuRules.needsConfirm({ type = "ProposePact", toId = "p2" } :: any)).toBe(false)
	end)
end)

describe("ActionMenuRules.splitHandActions", function()
	it("las jugadas de carta van a la mano, agrupadas por carta, y el resto se queda en el panel", function()
		local legal = {
			{ type = "EndTurn" },
			{ type = "PlayCard", cardId = "push", targetId = "p2" },
			{ type = "PlayCard", cardId = "push", targetId = "p3" },
			{ type = "PlayCard", cardId = "discount" },
			{ type = "React", cardId = "shield" },
		}
		local rest, byCard = ActionMenuRules.splitHandActions(legal)
		expect(#rest).toBe(2)
		expect(rest[1].type).toBe("EndTurn")
		expect(rest[2].type).toBe("React")
		expect(#byCard.push).toBe(2)
		expect(#byCard.discount).toBe(1)
		expect(byCard.shield).toBe(nil)
	end)

	it("sin jugadas de carta, el panel recibe todo y la mano nada", function()
		local rest, byCard = ActionMenuRules.splitHandActions({ { type = "EndTurn" } })
		expect(#rest).toBe(1)
		expect((next(byCard))).toBe(nil)
	end)
end)

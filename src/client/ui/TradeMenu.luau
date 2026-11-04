--!strict
-- Menú de tratos. Propone un intercambio (dinero y casillas de cada lado) y responde a los que llegan.
-- Todo se hace con botones: la ficha prohíbe depender del chat o de la voz. Qué se puede ofrecer lo
-- decide `SocialRules`, que lee la vista; aquí solo se pinta.
local ActionMenuRules = require("./ActionMenuRules")
local SocialRules = require("./SocialRules")
local Theme = require("./Theme")
local Ui = require("../../shared/config/Ui")
local ViewText = require("./ViewText")

export type Handles = {
	setView: (view: any, names: ViewText.Names?) -> (),
	-- Abre o cierra la ventana. El menú de acciones la abre cuando su botón pide un trato o un pacto:
	-- esas acciones necesitan más datos de los que cabe en un botón.
	setOpen: (open: boolean) -> (),
	destroy: () -> (),
}

local TradeMenu = {}

-- Añade o quita una casilla de la lista elegida.
local function toggle(list: { number }, index: number): { number }
	local out: { number } = {}
	local found = false
	for _, item in list do
		if item == index then
			found = true
		else
			table.insert(out, item)
		end
	end
	if not found then
		table.insert(out, index)
	end
	return out
end

function TradeMenu.create(playerGui: Instance, send: (action: any) -> ()): Handles
	local modal = Theme.modal(playerGui, "TradeMenu", "Tratos", 9)
	local body = modal.body

	local selection: SocialRules.Selection = {
		targetId = nil,
		giveCash = 0,
		wantCash = 0,
		giveSquares = {},
		wantSquares = {},
	}
	local lastView: any = nil
	local lastNames: ViewText.Names? = nil

	local function rebuild()
		local view = lastView
		if view == nil then
			return
		end
		local names = lastNames
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local order = 0
		local function header(text: string)
			order += 1
			Theme.header(body, text, order)
		end
		local function button(text: string, onClick: () -> ())
			order += 1
			Theme.button(body, text, order, onClick)
		end
		local function squareName(index: number): string
			return ViewText.squareName(view, index)
		end

		if SocialRules.canPropose(view) then
			header("Elige a quién proponer")
			local rivals = SocialRules.rivals(view)
			-- El rival elegido que ya no está activo se olvida.
			if selection.targetId ~= nil and table.find(rivals, selection.targetId) == nil then
				selection.targetId = nil
			end
			for _, rivalId in rivals do
				local mark = if selection.targetId == rivalId then "✓ " else ""
				button(`{mark}{ViewText.playerName(view, names, rivalId)}`, function()
					if selection.targetId ~= rivalId then
						selection.wantSquares = {}
					end
					selection.targetId = rivalId
					rebuild()
				end)
			end

			local target = selection.targetId
			if target ~= nil then
				header(`Entregas {selection.giveCash} · pides {selection.wantCash}`)
				button("Entregar menos dinero", function()
					selection.giveCash = SocialRules.nextStep(Ui.tradeCashSteps, selection.giveCash, -1)
					rebuild()
				end)
				button("Entregar más dinero", function()
					selection.giveCash = SocialRules.nextStep(Ui.tradeCashSteps, selection.giveCash, 1)
					rebuild()
				end)
				button("Pedir menos dinero", function()
					selection.wantCash = SocialRules.nextStep(Ui.tradeCashSteps, selection.wantCash, -1)
					rebuild()
				end)
				button("Pedir más dinero", function()
					selection.wantCash = SocialRules.nextStep(Ui.tradeCashSteps, selection.wantCash, 1)
					rebuild()
				end)

				local mine = SocialRules.tradeableSquares(view, view.playerId)
				if #mine > 0 then
					header("Tus casillas sin edificios: toca para entregar")
					for _, index in mine do
						local mark = if table.find(selection.giveSquares, index) ~= nil then "✓ " else ""
						button(`{mark}{squareName(index)}`, function()
							selection.giveSquares = toggle(selection.giveSquares, index)
							rebuild()
						end)
					end
				end
				local theirs = SocialRules.tradeableSquares(view, target)
				if #theirs > 0 then
					header(
						`Casillas de {ViewText.playerName(view, names, target)} sin edificios: toca para pedir`
					)
					for _, index in theirs do
						local mark = if table.find(selection.wantSquares, index) ~= nil then "✓ " else ""
						button(`{mark}{squareName(index)}`, function()
							selection.wantSquares = toggle(selection.wantSquares, index)
							rebuild()
						end)
					end
				end

				local action = SocialRules.proposal(view, selection)
				if action ~= nil then
					local offer = action.offer
					header(`Propones: {ActionMenuRules.offerText(offer, squareName)}`)
					button("Enviar propuesta", function()
						send(action)
						selection = {
							targetId = nil,
							giveCash = 0,
							wantCash = 0,
							giveSquares = {},
							wantSquares = {},
						}
						modal.setOpen(false)
					end)
				else
					header("Elige dinero o casillas para proponer")
				end
			end
		else
			header("Solo puedes proponer un trato en tu turno, antes de tirar o al final")
		end

		local announced = false
		for _, trade in SocialRules.incomingTrades(view) do
			if not announced then
				header("Te han propuesto")
				announced = true
			end
			local from = ViewText.playerName(view, names, trade.fromId)
			button(`Aceptar de {from}: {ActionMenuRules.offerText(trade, squareName)}`, function()
				send({ type = "RespondTrade", tradeId = trade.id, accept = true })
			end)
			button(`Rechazar a {from}`, function()
				send({ type = "RespondTrade", tradeId = trade.id, accept = false })
			end)
		end
	end

	return {
		setView = function(view: any, names: ViewText.Names?)
			if view == nil then
				return
			end
			lastView = view
			lastNames = names
			-- Sin fase de turno (subasta, duelo, final) no hay nada que tratar: la ventana se cierra.
			if not SocialRules.available(view) then
				modal.setOpen(false)
			end
			rebuild()
		end,
		setOpen = function(open: boolean)
			modal.setOpen(open)
		end,
		destroy = function()
			modal.gui:Destroy()
		end,
	}
end

return TradeMenu

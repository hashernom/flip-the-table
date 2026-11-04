--!strict
-- Menú de tratos. Propone un intercambio (dinero por dinero, sobre casillas, o las dos cosas) y
-- responde a los que llegan. Todo se hace con botones: la ficha prohíbe depender del chat o de la voz.
local Theme = require("./Theme")

export type Handles = {
	setView: (view: any) -> (),
	-- Abre o cierra la ventana. El menú de acciones la abre cuando su botón pide un trato o un pacto:
	-- esas acciones necesitan más datos de los que cabe en un botón.
	setOpen: (open: boolean) -> (),
	destroy: () -> (),
}

local CASH_STEPS = { 0, 50, 100, 200 }

local TradeMenu = {}

local function formatOffer(offer: any): string
	local give = if offer.giveCash > 0 then `{offer.giveCash}` else ""
	local squares = if offer.giveSquares and #offer.giveSquares > 0
		then `casas {table.concat(offer.giveSquares, ",")}`
		else ""
	local want = if offer.wantCash > 0 then `{offer.wantCash}` else ""
	local wantSquares = if offer.wantSquares and #offer.wantSquares > 0
		then `casas {table.concat(offer.wantSquares, ",")}`
		else ""
	local left = if #give > 0 or #squares > 0 then table.concat({ give, squares }, " + ") else "nada"
	local right = if #want > 0 or #wantSquares > 0 then table.concat({ want, wantSquares }, " + ") else "nada"
	return `{left} por {right}`
end

function TradeMenu.create(playerGui: Instance, send: (action: any) -> ()): Handles
	local modal = Theme.modal(playerGui, "TradeMenu", "Tratos", 9)
	local body = modal.body
	body.Size = UDim2.fromScale(1, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y

	local state = {
		targetId = nil :: string?,
		give = 0,
		want = 0,
		giveIndex = 1,
		wantIndex = 1,
	}

	local function rebuild(view: any)
		for _, child in body:GetChildren() do
			if child:IsA("GuiObject") and child.Name ~= "Title" then
				child:Destroy()
			end
		end
		local order = 0

		local function header(text: string)
			order += 1
			local label = Instance.new("TextLabel")
			label.Name = `Header_{order}`
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 0)
			label.AutomaticSize = Enum.AutomaticSize.Y
			label.Font = Theme.fontBold
			label.TextSize = 16
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextColor3 = Theme.muted
			label.Text = text
			label.LayoutOrder = order
			label.Parent = body
		end

		local function button(text: string, onClick: () -> ())
			order += 1
			Theme.button(body, text, order, onClick)
		end

		header("Elige a quién proponer")
		for _, seated in view.players do
			if seated.id ~= view.playerId then
				local selected = if state.targetId == seated.id then "✓ " else ""
				button(`{selected}{seated.id}`, function()
					state.targetId = seated.id
					rebuild(view)
				end)
			end
		end

		header(`Entregas {state.give} · pides {state.want}`)
		button("Entregar menos", function()
			state.giveIndex = math.max(1, state.giveIndex - 1)
			state.give = CASH_STEPS[state.giveIndex]
			rebuild(view)
		end)
		button("Entregar más", function()
			state.giveIndex = math.min(#CASH_STEPS, state.giveIndex + 1)
			state.give = CASH_STEPS[state.giveIndex]
			rebuild(view)
		end)
		button("Pedir menos", function()
			state.wantIndex = math.max(1, state.wantIndex - 1)
			state.want = CASH_STEPS[state.wantIndex]
			rebuild(view)
		end)
		button("Pedir más", function()
			state.wantIndex = math.min(#CASH_STEPS, state.wantIndex + 1)
			state.want = CASH_STEPS[state.wantIndex]
			rebuild(view)
		end)
		button("Enviar propuesta", function()
			local target = state.targetId
			if target == nil then
				return
			end
			send({
				type = "ProposeTrade",
				offer = {
					toId = target,
					giveCash = state.give,
					wantCash = state.want,
					giveSquares = {},
					wantSquares = {},
				},
			})
			modal.setOpen(false)
		end)

		local pending = view.pending
		local trades = if pending ~= nil and pending.trades ~= nil then pending.trades else {}
		if #trades > 0 then
			header("Te han propuesto")
			for _, trade in trades do
				if trade.toId == view.playerId then
					button(`Aceptar: {formatOffer(trade.offer)}`, function()
						send({ type = "RespondTrade", tradeId = trade.id, accept = true })
						rebuild(view)
					end)
					button("Rechazar", function()
						send({ type = "RespondTrade", tradeId = trade.id, accept = false })
						rebuild(view)
					end)
				end
			end
		end
	end

	return {
		setView = function(view: any)
			if view == nil then
				return
			end
			rebuild(view)
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

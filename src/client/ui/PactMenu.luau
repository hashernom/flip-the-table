--!strict
-- Menú de pactos. Propone un acuerdo con duración, acepta o rechaza los que llegan y permite romper
-- el propio, que es la mitad divertida de la traición: perder la garantía y llevar la marca de Traidor
-- a la vista de todos.
local Theme = require("./Theme")

export type Handles = {
	setView: (view: any) -> (),
	destroy: () -> (),
}

local ROUND_OPTIONS = { 1, 2, 3, 5 }
local MAX_ROUNDS = 5

local PactMenu = {}

local function panelBody(modal: Theme.Modal): Frame
	local body = Theme.panel(modal.panel, "Body", nil)
	body.Size = UDim2.fromScale(1, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	return body
end

function PactMenu.create(playerGui: Instance, send: (action: any) -> ()): Handles
	local modal = Theme.modal(playerGui, "PactMenu", "Pactos", 9)
	local body = panelBody(modal)
	local state = { targetId = nil :: string?, rounds = ROUND_OPTIONS[1] }

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

		header(`Con quién y cuántas rondas (máximo {MAX_ROUNDS})`)
		for _, seated in view.players do
			if seated.id ~= view.playerId then
				local selected = if state.targetId == seated.id then "✓ " else ""
				button(`{selected}{seated.id}`, function()
					state.targetId = seated.id
					rebuild(view)
				end)
			end
		end
		for _, rounds in ROUND_OPTIONS do
			local selected = if state.rounds == rounds then "✓ " else ""
			button(`{selected}{rounds} rondas`, function()
				state.rounds = rounds
				rebuild(view)
			end)
		end
		button("Proponer pacto", function()
			local target = state.targetId
			if target == nil then
				return
			end
			send({ type = "ProposePact", toId = target, rounds = state.rounds })
			modal.setOpen(false)
		end)

		local pending = view.pending
		local offers = if pending ~= nil and pending.pactOffers ~= nil then pending.pactOffers else {}
		if #offers > 0 then
			header("Te han propuesto")
			for _, offer in offers do
				if offer.toId == view.playerId then
					button(`Aceptar pacto de {offer.fromId} ({offer.rounds} rondas)`, function()
						send({ type = "RespondPact", pactId = offer.id, accept = true })
						rebuild(view)
					end)
					button(`Rechazar pacto de {offer.fromId}`, function()
						send({ type = "RespondPact", pactId = offer.id, accept = false })
						rebuild(view)
					end)
				end
			end
		end

		local own: { any } = {}
		for _, pact in view.pacts or {} do
			if pact.a == view.playerId or pact.b == view.playerId then
				table.insert(own, pact)
			end
		end
		if #own > 0 then
			header("Tus pactos")
			for _, pact in own do
				button(`Romper pacto con {if pact.a == view.playerId then pact.b else pact.a}`, function()
					send({ type = "BreakPact", pactId = pact.id })
					rebuild(view)
				end)
			end
		end
	end

	return {
		setView = function(view: any)
			if view ~= nil then
				rebuild(view)
			end
		end,
		destroy = function()
			modal.gui:Destroy()
		end,
	}
end

return PactMenu

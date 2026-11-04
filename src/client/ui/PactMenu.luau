--!strict
-- Menú de pactos. Propone un acuerdo con duración, acepta o rechaza los que llegan y permite romper
-- el propio, que es la mitad divertida de la traición: perder la garantía y llevar la marca de Traidor
-- a la vista de todos. Quién puede qué lo decide `SocialRules`.
local Economy = require("../../shared/config/Economy")
local SocialRules = require("./SocialRules")
local Theme = require("./Theme")
local ViewText = require("./ViewText")

export type Handles = {
	setView: (view: any, names: ViewText.Names?) -> (),
	-- Abre o cierra la ventana. El menú de acciones la abre cuando su botón pide un trato o un pacto:
	-- esas acciones necesitan más datos de los que cabe en un botón.
	setOpen: (open: boolean) -> (),
	destroy: () -> (),
}

local PactMenu = {}

function PactMenu.create(playerGui: Instance, send: (action: any) -> ()): Handles
	local modal = Theme.modal(playerGui, "PactMenu", "Pactos", 9)
	local body = modal.body
	local options = SocialRules.pactRounds()
	local state = { targetId = nil :: string?, rounds = options[1] }
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

		if SocialRules.canPropose(view) then
			header(`Con quién y cuántas rondas (máximo {Economy.pact.maxRounds})`)
			local rivals = SocialRules.rivals(view)
			if state.targetId ~= nil and table.find(rivals, state.targetId) == nil then
				state.targetId = nil
			end
			for _, rivalId in rivals do
				local mark = if state.targetId == rivalId then "✓ " else ""
				button(`{mark}{ViewText.playerName(view, names, rivalId)}`, function()
					state.targetId = rivalId
					rebuild()
				end)
			end
			for _, rounds in options do
				local mark = if state.rounds == rounds then "✓ " else ""
				button(`{mark}{rounds} rondas`, function()
					state.rounds = rounds
					rebuild()
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
		else
			header("Solo puedes proponer un pacto en tu turno, antes de tirar o al final")
		end

		local announced = false
		for _, offer in SocialRules.incomingPacts(view) do
			if not announced then
				header("Te han propuesto")
				announced = true
			end
			local from = ViewText.playerName(view, names, offer.fromId)
			button(`Aceptar pacto de {from} ({offer.rounds} rondas)`, function()
				send({ type = "RespondPact", pactId = offer.id, accept = true })
			end)
			button(`Rechazar pacto de {from}`, function()
				send({ type = "RespondPact", pactId = offer.id, accept = false })
			end)
		end

		local own = SocialRules.ownPacts(view)
		if #own > 0 then
			header("Tus pactos")
			for _, pact in own do
				local partner = ViewText.playerName(view, names, pact.partnerId)
				button(`Romper pacto con {partner} (hasta la ronda {pact.untilRound})`, function()
					send({ type = "BreakPact", pactId = pact.id })
				end)
			end
		end
	end

	return {
		setView = function(view: any, names: ViewText.Names?)
			if view == nil then
				return
			end
			lastView = view
			lastNames = names
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

return PactMenu

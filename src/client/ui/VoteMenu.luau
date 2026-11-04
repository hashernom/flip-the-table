--!strict
-- Menú de votación del Tribunal. El jugador arrestado espera y el resto vota el castigo: multa, perder
-- un turno o pagarle a alguien. Sin chat, todo con botones.
local Theme = require("./Theme")

export type Handles = {
	setView: (view: any) -> (),
	destroy: () -> (),
}

local VERDICTS = {
	{ id = "Fine", label = "Multa" },
	{ id = "SkipTurn", label = "Perder un turno" },
	{ id = "PayToPlayer", label = "Pagar a alguien" },
}

local VoteMenu = {}

function VoteMenu.create(playerGui: Instance, send: (action: any) -> ()): Handles
	local modal = Theme.modal(playerGui, "VoteMenu", "Tribunal", 9)
	local body = Theme.panel(modal.panel, "Body", nil)
	body.Size = UDim2.fromScale(1, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y

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

		local pending = view.pending
		local tribunal = if pending ~= nil then pending.tribunal else nil
		local accused = if tribunal ~= nil then tribunal.accusedId else "alguien"
		header(`Castigo para {accused}`)

		for _, verdict in VERDICTS do
			if verdict.id == "PayToPlayer" then
				header("Si elige pagar a alguien, elige a quién")
				for _, seated in view.players do
					if seated.id ~= view.playerId and seated.id ~= accused then
						button(`Pagar a {seated.id}`, function()
							send({ type = "TribunalVote", verdict = "PayToPlayer", targetId = seated.id })
							modal.setOpen(false)
						end)
					end
				end
			else
				button(verdict.label, function()
					send({ type = "TribunalVote", verdict = verdict.id })
					modal.setOpen(false)
				end)
			end
		end
	end

	return {
		setView = function(view: any)
			if view ~= nil and view.phase == "Tribunal" then
				modal.setOpen(true)
				rebuild(view)
			end
		end,
		destroy = function()
			modal.gui:Destroy()
		end,
	}
end

return VoteMenu

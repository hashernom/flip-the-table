--!strict
-- Menú de pactos sobre el tablón de obra. A la izquierda se propone: socio, duración y el contrato en
-- una frase. A la derecha, lo que ya está en marcha: propuestas recibidas y pactos propios, que se
-- pueden romper con una segunda confirmación. Romper es la mitad divertida de la traición: se pierde la
-- garantía y se lleva la marca de Traidor a la vista de todos. Quién puede qué lo decide `SocialRules`.
local Board = require("./Board")
local Components = require("./Components")
local Economy = require("../../shared/config/Economy")
local SocialRules = require("./SocialRules")
local Strings = require("../../shared/config/Strings")
local Theme = require("./Theme")
local Ui = require("../../shared/config/Ui")
local ViewText = require("./ViewText")

export type Handles = {
	setView: (view: any, names: ViewText.Names?) -> (),
	-- Abre o cierra la ventana. El menú de acciones la abre cuando su botón pide un pacto.
	setOpen: (open: boolean) -> (),
	isOpen: () -> boolean,
	destroy: () -> (),
}

local PactMenu = {}

-- «1 ronda» o «N rondas», según la cuenta.
local function roundsText(rounds: number): string
	if rounds == 1 then
		return Strings.get("pact.oneRound")
	end
	return Strings.get("pact.rounds", { count = rounds })
end

function PactMenu.create(playerGui: Instance, send: (action: any) -> ()): Handles
	local window =
		Board.Window(playerGui, "PactMenu", 9, true, Vector2.new(Ui.pactBoard.width, Ui.pactBoard.height))
	local options = SocialRules.pactRounds()
	local state = { targetId = nil :: string?, rounds = options[1] }
	local lastView: any = nil
	local lastNames: ViewText.Names? = nil
	local builtKey = ""

	local rebuild: () -> ()

	local function close()
		window.setOpen(false)
	end

	-- Fila de un elemento de la lista de la derecha: su frase y sus botones debajo.
	local function entry(parent: Instance, order: number, text: string, warning: string?): Frame
		local box = Instance.new("Frame")
		box.Name = `Entry{order}`
		box.BackgroundTransparency = 1
		box.Size = UDim2.fromScale(1, 0)
		box.AutomaticSize = Enum.AutomaticSize.Y
		box.LayoutOrder = order
		box.Parent = parent
		Board.list(box, Enum.FillDirection.Vertical, Theme.space.s)
		Board.text(box, "Line", text, 1)
		if warning ~= nil then
			Board.text(box, "Warning", warning, 2, 14).TextColor3 = Board.muted
		end
		local buttons = Instance.new("Frame")
		buttons.Name = "Buttons"
		buttons.BackgroundTransparency = 1
		buttons.Size = UDim2.new(1, 0, 0, 44)
		buttons.LayoutOrder = 3
		buttons.Parent = box
		Board.list(buttons, Enum.FillDirection.Horizontal, Theme.space.s)
		return buttons
	end

	local function build(view: any, names: ViewText.Names?)
		local deposit = Economy.pact.deposit
		Board.Header(window.stack, 1, {
			title = Strings.get("pact.title"),
			help = Strings.get("pact.help"),
			steps = {
				Strings.get("pact.step1"),
				Strings.get("pact.step2", { deposit = deposit }),
				Strings.get("pact.step3", { rounds = Economy.pact.traitorRounds }),
			},
			onClose = close,
		})

		local row = Instance.new("Frame")
		row.Name = "Middle"
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, 0)
		row.LayoutOrder = 2
		row.Parent = window.stack
		Board.fill(row)
		Board.list(row, Enum.FillDirection.Horizontal, Theme.space.l)

		-- Proponer.
		local propose = Board.Poster(row, "Propose", 1, false)
		propose.root.Size = UDim2.new(0.5, -Theme.space.l // 2, 1, 0)
		Board.caption(propose.content, "Title", Strings.get("pact.proposeTitle"), 1)
		local rivals = SocialRules.rivals(view)
		if state.targetId ~= nil and table.find(rivals, state.targetId) == nil then
			state.targetId = nil
		end
		local canPropose = SocialRules.canPropose(view)
		local contract = ""
		if #rivals == 0 then
			Board.text(propose.content, "Empty", Strings.get("pact.noRivals"), 2)
		else
			Board.caption(propose.content, "PartnerCaption", Strings.get("pact.partner"), 2)
			local partners: { Board.Tab } = {}
			for _, rivalId in rivals do
				table.insert(partners, {
					id = rivalId,
					label = ViewText.playerName(view, names, rivalId),
					-- El punto lleva el color del asiento: se reconoce al rival sin leer el nombre.
					tint = ViewText.seatTint(view, rivalId),
				})
			end
			Board.Tabs(propose.content, 3, partners, state.targetId, function(id: string)
				state.targetId = id
				builtKey = ""
				rebuild()
			end)
			Board.caption(propose.content, "LengthCaption", Strings.get("pact.length"), 4)
			local lengths: { Board.Tab } = {}
			for _, rounds in options do
				table.insert(lengths, { id = tostring(rounds), label = roundsText(rounds) })
			end
			Board.Tabs(propose.content, 5, lengths, tostring(state.rounds), function(id: string)
				state.rounds = tonumber(id) or options[1]
				builtKey = ""
				rebuild()
			end)
			local target = state.targetId
			if not canPropose then
				contract = Strings.get("pact.onlyOnTurn")
			elseif target == nil then
				contract = Strings.get("pact.pickPartner")
			else
				contract = Strings.get("pact.contract", {
					name = ViewText.playerName(view, names, target),
					rounds = roundsText(state.rounds),
					deposit = deposit,
				})
			end
		end

		-- Lo que ya está en marcha.
		local running = Board.Poster(row, "Running", 2, false)
		running.root.Size = UDim2.new(0.5, -Theme.space.l // 2, 1, 0)
		Board.caption(running.content, "Title", Strings.get("pact.listTitle"), 1)
		local entries = Instance.new("ScrollingFrame")
		entries.Name = "Entries"
		entries.BackgroundTransparency = 1
		entries.BorderSizePixel = 0
		entries.Size = UDim2.fromScale(1, 0)
		entries.CanvasSize = UDim2.fromScale(0, 0)
		entries.AutomaticCanvasSize = Enum.AutomaticSize.Y
		entries.ScrollingDirection = Enum.ScrollingDirection.Y
		entries.ScrollBarThickness = 6
		entries.ScrollBarImageColor3 = Theme.color.asphalt
		entries.LayoutOrder = 2
		entries.Parent = running.content
		Board.fill(entries)
		Board.list(entries, Enum.FillDirection.Vertical, Theme.space.l)

		local order = 0
		for _, offer in SocialRules.incomingPacts(view) do
			order += 1
			local from = ViewText.playerName(view, names, offer.fromId)
			local buttons = entry(
				entries,
				order,
				Strings.get("pact.offerLine", { name = from, rounds = roundsText(offer.rounds) })
			)
			local id = offer.id
			-- Aceptar un pacto se envía al primer toque; rechazarlo pide confirmación.
			local accept = Components.SecondaryButton(buttons, "Accept", Strings.get("pact.accept"))
			accept.root.Size = UDim2.fromOffset(150, 44)
			accept.root.LayoutOrder = 1
			accept.onActivated(function()
				send({ type = "RespondPact", pactId = id, accept = true })
			end)
			local reject = Components.SecondaryButton(buttons, "Reject", Strings.get("pact.reject"))
			reject.root.Size = UDim2.fromOffset(170, 44)
			reject.root.LayoutOrder = 2
			Components.confirmPress(reject, Strings.get("pact.reject"), function()
				send({ type = "RespondPact", pactId = id, accept = false })
			end)
		end
		for _, pact in SocialRules.ownPacts(view) do
			order += 1
			local partner = ViewText.playerName(view, names, pact.partnerId)
			local buttons = entry(
				entries,
				order,
				Strings.get("pact.activeLine", { name = partner, round = pact.untilRound }),
				Strings.get("pact.breakWarning", { name = partner })
			)
			local id = pact.id
			local breakButton = Components.SecondaryButton(buttons, "Break", Strings.get("pact.break"))
			breakButton.root.Size = UDim2.fromOffset(200, 44)
			Components.confirmPress(breakButton, Strings.get("pact.break"), function()
				send({ type = "BreakPact", pactId = id })
			end)
		end
		if order == 0 then
			Board.text(entries, "Empty", Strings.get("pact.empty"), 1)
		end

		-- Pie: el contrato en una frase y el verbo.
		local foot = Instance.new("Frame")
		foot.Name = "Footer"
		foot.BackgroundTransparency = 1
		foot.Size = UDim2.new(1, 0, 0, Ui.board.footerHeight)
		foot.LayoutOrder = 3
		foot.Parent = window.stack
		local footLayout = Board.list(foot, Enum.FillDirection.Horizontal, Theme.space.l)
		footLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		local summary = Components.label(foot, "Contract", contract, {
			face = Theme.font.roadBold,
			size = 19,
			tint = Theme.color.limestone,
			wrap = true,
		})
		summary.Size = UDim2.fromScale(0, 1)
		summary.TextYAlignment = Enum.TextYAlignment.Center
		summary.LayoutOrder = 1
		Board.fill(summary)
		local sendButton = Components.PrimaryButton(foot, "Send", Strings.get("pact.send"))
		sendButton.root.Size = UDim2.fromOffset(Ui.board.sendWidth, 72)
		sendButton.root.LayoutOrder = 2
		sendButton.setEnabled(canPropose and state.targetId ~= nil)
		sendButton.onActivated(function()
			local chosen = state.targetId
			if not canPropose or chosen == nil then
				return
			end
			send({ type = "ProposePact", toId = chosen, rounds = state.rounds })
			close()
		end)
	end

	local function keyOf(view: any): string
		local parts: { string } = {
			tostring(SocialRules.canPropose(view)),
			tostring(state.targetId),
			tostring(state.rounds),
		}
		for _, rivalId in SocialRules.rivals(view) do
			table.insert(parts, `r{rivalId}`)
		end
		for _, offer in SocialRules.incomingPacts(view) do
			table.insert(parts, `o{offer.id}`)
		end
		for _, pact in SocialRules.ownPacts(view) do
			table.insert(parts, `p{pact.id}:{pact.untilRound}`)
		end
		return table.concat(parts, "|")
	end

	rebuild = function()
		local view = lastView
		if view == nil then
			return
		end
		local key = keyOf(view)
		if key == builtKey then
			return
		end
		builtKey = key
		window.clear()
		build(view, lastNames)
	end

	return {
		setView = function(view: any, names: ViewText.Names?)
			if view == nil then
				return
			end
			lastView = view
			lastNames = names
			if not SocialRules.available(view) then
				window.setOpen(false)
			end
			rebuild()
		end,
		setOpen = function(open: boolean)
			if open then
				builtKey = ""
				rebuild()
			end
			window.setOpen(open)
		end,
		isOpen = window.isOpen,
		destroy = function()
			window.gui:Destroy()
		end,
	}
end

return PactMenu

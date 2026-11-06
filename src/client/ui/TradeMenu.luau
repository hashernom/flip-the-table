--!strict
-- Menú de tratos sobre el tablón de obra. Dos modos: proponer (tus escrituras y tu dinero a un lado, las
-- del rival al otro) y responder a una propuesta recibida, que se abre sola cuando llega. Todo se hace
-- con botones y un campo de dinero: la ficha prohíbe depender del chat o de la voz. Qué se puede
-- ofrecer lo decide `SocialRules`; aquí solo se pinta.
local UserInputService = game:GetService("UserInputService")

local ActionMenuRules = require("./ActionMenuRules")
local Board = require("./Board")
local Components = require("./Components")
local HudRules = require("./HudRules")
local SocialRules = require("./SocialRules")
local Strings = require("../../shared/config/Strings")
local Theme = require("./Theme")
local Ui = require("../../shared/config/Ui")
local ViewText = require("./ViewText")

export type Handles = {
	setView: (view: any, names: ViewText.Names?) -> (),
	-- Abre o cierra la ventana. Con propuestas recibidas abre en ellas; si no, en proponer.
	setOpen: (open: boolean) -> (),
	isOpen: () -> boolean,
	destroy: () -> (),
}

type Mode = "Propose" | "Incoming"

local TradeMenu = {}

-- Añade o quita una casilla de la lista elegida.
local function toggle(items: { number }, index: number): { number }
	local out: { number } = {}
	local found = false
	for _, item in items do
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

local function emptySelection(): SocialRules.Selection
	return { targetId = nil, giveCash = 0, wantCash = 0, giveSquares = {}, wantSquares = {} }
end

local function seatOf(view: any, id: string): (any, number)
	for index, seated in view.players do
		if seated.id == id then
			return seated, index
		end
	end
	return nil, 0
end

local function profileFor(view: any, names: ViewText.Names?, id: string, own: boolean): Board.ProfileData
	local seated, index = seatOf(view, id)
	local name = ViewText.playerName(view, names, id)
	return {
		name = if own then Strings.get("trade.you", { name = name }) else name,
		cash = if seated ~= nil then seated.cash else 0,
		tint = Color3.fromHex(Ui.seatColors[(math.max(index, 1) - 1) % #Ui.seatColors + 1]),
		userId = if seated ~= nil and seated.isBot ~= true then tonumber(seated.id) else nil,
		bot = seated ~= nil and seated.isBot == true,
	}
end

-- Lo que cruza de un lado, en una línea: casillas por su nombre y el dinero al final.
local function sideText(view: any, squares: { number }, cash: number): string
	local parts: { string } = {}
	for _, index in squares do
		table.insert(parts, ViewText.squareName(view, index))
	end
	local items = table.concat(parts, ", ")
	if cash > 0 and items ~= "" then
		return Strings.get("trade.plusCash", { items = items, cash = HudRules.formatMoney(cash) })
	elseif cash > 0 then
		return HudRules.formatMoney(cash)
	elseif items ~= "" then
		return items
	end
	return Strings.get("trade.nothing")
end

function TradeMenu.create(playerGui: Instance, send: (action: any) -> ()): Handles
	local window = Board.Window(playerGui, "TradeMenu", 9)
	local board = Ui.board

	local selection = emptySelection()
	local mode: Mode = "Propose"
	local incomingIndex = 1
	local lastView: any = nil
	local lastNames: ViewText.Names? = nil
	local builtKey = ""
	local seenTrades: { [string]: boolean } = {}

	local rebuild: () -> ()

	-- ¿Hay un campo de este tablón con el foco? Entonces una vista nueva espera a que se suelte.
	local function writing(): boolean
		local focused = UserInputService:GetFocusedTextBox()
		return focused ~= nil and focused:IsDescendantOf(window.gui)
	end

	local function close()
		window.setOpen(false)
	end

	-- Fila del pie: el resumen a la izquierda, que ocupa lo que sobra, y los botones a la derecha.
	local function footer(order: number): Frame
		local row = Instance.new("Frame")
		row.Name = "Footer"
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, board.footerHeight)
		row.LayoutOrder = order
		row.Parent = window.stack
		local layout = Board.list(row, Enum.FillDirection.Horizontal, Theme.space.l)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		return row
	end

	local function summaryBlock(parent: Instance, captionKey: string, order: number): TextLabel
		local block = Instance.new("Frame")
		block.Name = `Summary{order}`
		block.BackgroundTransparency = 1
		block.Size = UDim2.fromScale(0, 1)
		block.LayoutOrder = order
		block.Parent = parent
		Board.fill(block)
		local caption = Components.label(block, "Caption", Strings.upper(Strings.get(captionKey)), {
			face = Theme.font.road,
			size = 12,
			tint = Theme.color.limestoneDim,
		})
		caption.Size = UDim2.new(1, 0, 0, 16)
		local value = Components.label(block, "Value", "", {
			face = Theme.font.roadBold,
			size = 19,
			tint = Theme.color.limestone,
			wrap = true,
		})
		value.Position = UDim2.fromOffset(0, 18)
		value.Size = UDim2.new(1, 0, 1, -18)
		value.TextYAlignment = Enum.TextYAlignment.Top
		return value
	end

	-- Las dos columnas de carteles con la señal de doble sentido en medio.
	local function middle(order: number): Frame
		local row = Instance.new("Frame")
		row.Name = "Middle"
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, 0)
		row.LayoutOrder = order
		row.Parent = window.stack
		Board.fill(row)
		Board.list(row, Enum.FillDirection.Horizontal, Theme.space.l)
		return row
	end

	local function sidePoster(parent: Instance, name: string, order: number): Board.Poster
		local poster = Board.Poster(parent, name, order, false)
		poster.root.Size = UDim2.new(0.5, -(board.swapSize // 2 + Theme.space.l), 1, 0)
		return poster
	end

	local function deeds(
		view: any,
		grid: ScrollingFrame,
		squares: { number },
		chosen: { number },
		stamp: string,
		interactive: boolean,
		onToggle: ((index: number, deed: Board.MiniDeed) -> ())?
	)
		for order, index in squares do
			local data = ActionMenuRules.deedFor(view, index)
			if data ~= nil then
				local deed = Board.MiniDeed(grid, `Deed{index}`, data, stamp, interactive)
				deed.root.LayoutOrder = order
				deed.setSelected(table.find(chosen, index) ~= nil)
				if onToggle ~= nil then
					deed.onActivated(function()
						onToggle(index, deed)
					end)
				end
			end
		end
	end

	-- Proponer ---------------------------------------------------------------------------------------

	local function buildPropose(view: any, names: ViewText.Names?)
		local rivals = SocialRules.rivals(view)
		if selection.targetId ~= nil and table.find(rivals, selection.targetId) == nil then
			selection = emptySelection()
		end
		if selection.targetId == nil then
			selection.targetId = rivals[1]
		end
		local target = selection.targetId
		local canPropose = SocialRules.canPropose(view)

		Board.Header(window.stack, 1, {
			title = Strings.get("trade.title"),
			help = Strings.get("trade.help"),
			steps = { Strings.get("trade.step1"), Strings.get("trade.step2"), Strings.get("trade.step3") },
			onClose = close,
		})

		local row = middle(2)
		local mine = sidePoster(row, "Mine", 1)
		Board.Profile(mine.content, 1, profileFor(view, names, view.playerId, true))
		Board.caption(mine.content, "Hint", Strings.get("trade.giveHint"), 2)
		local myGrid = Board.DeedGrid(mine.content, 3)
		local myCash = Board.CashField(mine.content, 4, canPropose)

		Board.SwapSign(row, 2)

		local theirs = sidePoster(row, "Theirs", 3)
		local theirGrid: ScrollingFrame? = nil
		local theirCash: Board.CashField? = nil
		if target ~= nil then
			if #rivals > 1 then
				local items: { Board.Tab } = {}
				for _, rivalId in rivals do
					table.insert(items, { id = rivalId, label = ViewText.playerName(view, names, rivalId) })
				end
				Board.Tabs(theirs.content, 0, items, target, function(rivalId: string)
					selection.targetId = rivalId
					selection.wantSquares = {}
					selection.wantCash = 0
					rebuild()
				end)
			end
			Board.Profile(theirs.content, 1, profileFor(view, names, target, false))
			Board.caption(
				theirs.content,
				"Hint",
				Strings.get("trade.wantHint", { name = ViewText.playerName(view, names, target) }),
				2
			)
			theirGrid = Board.DeedGrid(theirs.content, 3)
			theirCash = Board.CashField(theirs.content, 4, canPropose)
		else
			Board.text(theirs.content, "Empty", Strings.get("trade.pickCashOrSquares"), 1)
		end

		local foot = footer(3)
		local giveValue = summaryBlock(foot, "trade.summaryGive", 1)
		local getValue = summaryBlock(foot, "trade.summaryGet", 2)
		local sendButton = Components.PrimaryButton(foot, "Send", Strings.get("trade.send"))
		sendButton.root.Size = UDim2.fromOffset(board.sendWidth, 72)
		sendButton.root.LayoutOrder = 3

		local function refresh()
			local action = if canPropose then SocialRules.proposal(view, selection) else nil
			sendButton.setEnabled(action ~= nil)
			if not canPropose then
				giveValue.Text = Strings.get("trade.onlyOnTurn")
				getValue.Text = ""
				return
			end
			giveValue.Text = sideText(view, selection.giveSquares, selection.giveCash)
			getValue.Text = sideText(view, selection.wantSquares, selection.wantCash)
		end

		local myOwn = SocialRules.tradeableSquares(view, view.playerId)
		if #myOwn == 0 then
			Board.text(myGrid, "Empty", Strings.get("trade.noDeeds"), 0, 15).Size = UDim2.fromOffset(300, 0)
		end
		deeds(
			view,
			myGrid,
			myOwn,
			selection.giveSquares,
			Strings.get("trade.stampGive"),
			canPropose,
			function(index, deed)
				selection.giveSquares = toggle(selection.giveSquares, index)
				deed.setSelected(table.find(selection.giveSquares, index) ~= nil)
				refresh()
			end
		)
		local me = seatOf(view, view.playerId)
		myCash.setMax(if me ~= nil then me.cash else 0)
		myCash.set(selection.giveCash)
		-- Si el saldo bajó, el campo acota el importe: la selección se queda con lo que de verdad se envía.
		selection.giveCash = myCash.get()
		myCash.onChanged(function(amount: number)
			selection.giveCash = amount
			refresh()
		end)

		local grid = theirGrid
		local cashField = theirCash
		if target ~= nil and grid ~= nil and cashField ~= nil then
			local theirOwn = SocialRules.tradeableSquares(view, target)
			if #theirOwn == 0 then
				Board.text(grid, "Empty", Strings.get("trade.noDeeds"), 0, 15).Size = UDim2.fromOffset(300, 0)
			end
			deeds(
				view,
				grid,
				theirOwn,
				selection.wantSquares,
				Strings.get("trade.stampWant"),
				canPropose,
				function(index, deed)
					selection.wantSquares = toggle(selection.wantSquares, index)
					deed.setSelected(table.find(selection.wantSquares, index) ~= nil)
					refresh()
				end
			)
			local rival = seatOf(view, target)
			cashField.setMax(if rival ~= nil then rival.cash else 0)
			cashField.set(selection.wantCash)
			selection.wantCash = cashField.get()
			cashField.onChanged(function(amount: number)
				selection.wantCash = amount
				refresh()
			end)
		end

		sendButton.onActivated(function()
			local action = if canPropose then SocialRules.proposal(view, selection) else nil
			if action == nil then
				return
			end
			send(action)
			selection = emptySelection()
			builtKey = ""
			close()
		end)
		refresh()
	end

	-- Responder --------------------------------------------------------------------------------------

	local function buildIncoming(view: any, names: ViewText.Names?, trades: { any })
		incomingIndex = math.clamp(incomingIndex, 1, #trades)
		local trade = trades[incomingIndex]
		local from = ViewText.playerName(view, names, trade.fromId)

		Board.Header(window.stack, 1, {
			title = Strings.get("trade.incomingTitle", { name = from }),
			help = Strings.get("trade.incomingHelp", { name = from }),
			steps = {
				Strings.get("trade.incomingStep1"),
				Strings.get("trade.incomingStep2"),
				Strings.get("trade.incomingStep3"),
			},
			onClose = close,
		})

		local row = middle(2)
		local giver = sidePoster(row, "Giver", 1)
		Board.Profile(giver.content, 1, profileFor(view, names, trade.fromId, false))
		Board.caption(giver.content, "Hint", Strings.get("trade.theyGive"), 2)
		local giveGrid = Board.DeedGrid(giver.content, 3)
		local giveSquares: { number } = trade.giveSquares or {}
		if #giveSquares == 0 then
			Board.text(giveGrid, "Empty", Strings.get("trade.nothing"), 0, 15).Size = UDim2.fromOffset(200, 0)
		end
		deeds(view, giveGrid, giveSquares, giveSquares, Strings.get("trade.summaryGet"), false, nil)
		local giveCash = Board.CashField(giver.content, 4, false)
		giveCash.set(trade.giveCash or 0)

		Board.SwapSign(row, 2)

		local you = sidePoster(row, "You", 3)
		Board.Profile(you.content, 1, profileFor(view, names, view.playerId, true))
		Board.caption(you.content, "Hint", Strings.get("trade.theyWant"), 2)
		local wantGrid = Board.DeedGrid(you.content, 3)
		local wantSquares: { number } = trade.wantSquares or {}
		if #wantSquares == 0 then
			Board.text(wantGrid, "Empty", Strings.get("trade.nothing"), 0, 15).Size = UDim2.fromOffset(200, 0)
		end
		deeds(view, wantGrid, wantSquares, wantSquares, Strings.get("trade.stampGive"), false, nil)
		local wantCash = Board.CashField(you.content, 4, false)
		wantCash.set(trade.wantCash or 0)

		local foot = footer(3)
		local countLabel = summaryBlock(foot, "trade.title", 1)
		countLabel.Text = Strings.get("trade.offerCount", { current = incomingIndex, total = #trades })
		if #trades > 1 then
			local nextButton = Components.SecondaryButton(foot, "Next", Strings.get("trade.next"))
			nextButton.root.Size = UDim2.fromOffset(150, 44)
			nextButton.root.LayoutOrder = 2
			nextButton.onActivated(function()
				incomingIndex = incomingIndex % #trades + 1
				builtKey = ""
				rebuild()
			end)
		end
		local id = trade.id
		local reject = Components.SecondaryButton(foot, "Reject", Strings.get("trade.reject"))
		reject.root.Size = UDim2.fromOffset(190, 44)
		reject.root.LayoutOrder = 3
		Components.confirmPress(reject, Strings.get("trade.reject"), function()
			send({ type = "RespondTrade", tradeId = id, accept = false })
		end)
		local accept = Components.PrimaryButton(foot, "Accept", Strings.get("trade.accept"))
		accept.root.Size = UDim2.fromOffset(board.sendWidth, 72)
		accept.root.LayoutOrder = 4
		Components.confirmPress(accept, Strings.get("trade.accept"), function()
			send({ type = "RespondTrade", tradeId = id, accept = true })
		end)
	end

	-- Clave de lo que se ve: si no cambia, una vista nueva no rehace el tablón ni quita el foco del campo.
	local function keyOf(view: any, trades: { any }): string
		local parts: { string } =
			{ mode, tostring(SocialRules.canPropose(view)), tostring(selection.targetId) }
		-- Solo el dinero que acota los campos: el propio y el del rival elegido. Un cobro entre otros
		-- dos jugadores no rehace el tablón mientras se escribe.
		for _, seated in view.players do
			if seated.id == view.playerId or seated.id == selection.targetId then
				table.insert(parts, `{seated.id}:{seated.cash}`)
			end
			table.insert(parts, `{seated.id}:{seated.status}`)
		end
		for _, index in SocialRules.tradeableSquares(view, view.playerId) do
			table.insert(parts, `m{index}`)
		end
		if selection.targetId ~= nil then
			for _, index in SocialRules.tradeableSquares(view, selection.targetId) do
				table.insert(parts, `t{index}`)
			end
		end
		for _, trade in trades do
			table.insert(parts, `x{trade.id}`)
		end
		table.insert(parts, tostring(incomingIndex))
		return table.concat(parts, "|")
	end

	rebuild = function()
		local view = lastView
		if view == nil then
			return
		end
		local trades = SocialRules.incomingTrades(view)
		if mode == "Incoming" and #trades == 0 then
			-- Ya no queda nada que responder: la ventana se cierra y la próxima vez abre en proponer.
			mode = "Propose"
			builtKey = ""
			window.setOpen(false)
		end
		local key = keyOf(view, trades)
		if key == builtKey then
			return
		end
		builtKey = key
		window.clear()
		if mode == "Incoming" then
			buildIncoming(view, lastNames, trades)
		else
			buildPropose(view, lastNames)
		end
	end

	local function apply(view: any, names: ViewText.Names?)
		if view == nil then
			return
		end
		lastView = view
		lastNames = names
		-- Sin fase de turno (subasta, duelo, final) no hay nada que tratar: la ventana se cierra.
		if not SocialRules.available(view) then
			window.setOpen(false)
		end
		-- Una propuesta nueva abre el tablón en ella: es una decisión que espera respuesta.
		-- Solo cuenta como vista cuando se puede responder: la que llega en una subasta o un duelo se
		-- abre al volver a una fase de turno.
		local trades = SocialRules.incomingTrades(view)
		local arrived = false
		local available = SocialRules.available(view)
		local typing = writing()
		for position, trade in trades do
			if available and not typing and not seenTrades[trade.id] then
				seenTrades[trade.id] = true
				incomingIndex = position
				arrived = true
			end
		end
		if typing then
			-- Mientras se escribe en un campo no se rehace nada: el foco se perdería a media cifra.
			return
		end
		if arrived then
			mode = "Incoming"
			builtKey = ""
			rebuild()
			window.setOpen(true)
			return
		end
		rebuild()
	end

	-- Al soltar un campo de este tablón, se aplica la vista que esperaba.
	UserInputService.TextBoxFocusReleased:Connect(function(box: TextBox)
		if box:IsDescendantOf(window.gui) then
			task.defer(function()
				if not writing() then
					apply(lastView, lastNames)
				end
			end)
		end
	end)

	return {
		setView = apply,
		setOpen = function(open: boolean)
			if open then
				local view = lastView
				local trades = if view ~= nil then SocialRules.incomingTrades(view) else {}
				mode = if #trades > 0 then "Incoming" else "Propose"
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

return TradeMenu

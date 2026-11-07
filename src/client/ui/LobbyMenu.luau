--!strict
-- Lobby sobre el tablón de obra: crear una party y enseñar su código, unirse con un código y entrar en
-- la cola pública. El anfitrión elige Rondas o Sin Fin, con la frase de cómo termina cada uno, ajusta la
-- configuración de la partida (`config/MatchSettings`: dinero inicial, subastas, perks…) y empieza.
-- Es la única pantalla antes de que exista una partida, así que también enseña los avisos del servidor:
-- un error sale en rojo, con sello. El estado (sin party, anfitrión, invitado, en cola) sale de lo que
-- el jugador pidió y del aviso con que responde el servidor.
local Board = require("./Board")
local Components = require("./Components")
local Lobby = require("../../shared/config/Lobby")
local MatchSettings = require("../../shared/config/MatchSettings")
local NoticeRules = require("./NoticeRules")
local Protocol = require("../../shared/net/Protocol")
local Strings = require("../../shared/config/Strings")
local Theme = require("./Theme")
local Ui = require("../../shared/config/Ui")

export type Handles = {
	setNotice: (text: string, kind: string?) -> (),
	setVisible: (visible: boolean) -> (),
	isVisible: () -> boolean,
	onClosed: (callback: () -> ()) -> (),
	destroy: () -> (),
}

type State = "Idle" | "Host" | "Guest" | "Queue"
type Request = "Create" | "Join" | "Queue" | "Start" | "Solo"

local LobbyMenu = {}

function LobbyMenu.create(playerGui: Instance, send: (request: any) -> (), closeLabel: string?): Handles
	local window = Board.Window(playerGui, "LobbyMenu", 9, false)
	local state: State = "Idle"
	local lastRequest: Request? = nil
	local code: string? = nil
	local endMode: "Rounds" | "Endless" = "Rounds"
	-- Configuración que elige el anfitrión; se conserva mientras siga en el lobby.
	local settings = MatchSettings.defaults()
	-- Modo solo contra bots: su propia mesa, con sus bots y su dinero.
	local soloBots = 3
	local soloMode: "Rounds" | "Endless" = "Rounds"
	local soloSettings = MatchSettings.defaults()
	local noticeText = Strings.get("lobby.idleNotice")
	local noticeIsError = false

	local rebuild: () -> ()

	local function request(kind: Request, payload: any)
		lastRequest = kind
		send(payload)
	end

	local function column(parent: Instance, name: string, order: number, share: number): Board.Poster
		local poster = Board.Poster(parent, name, order, false)
		poster.root.Size = UDim2.new(share, -Theme.space.l, 1, 0)
		return poster
	end

	local function title(poster: Board.Poster, key: string, order: number)
		local heading = Board.caption(poster.content, "Title", Strings.get(key), order)
		heading.FontFace = Theme.font.roadBold
		heading.TextSize = 22
		heading.TextColor3 = Theme.color.asphalt
	end

	local function spacer(poster: Board.Poster, order: number)
		local gap = Instance.new("Frame")
		gap.Name = "Spacer"
		gap.BackgroundTransparency = 1
		gap.Size = UDim2.fromScale(1, 0)
		gap.LayoutOrder = order
		gap.Parent = poster.content
		Board.fill(gap)
	end

	local function codePlate(parent: Instance, order: number, value: string)
		local plate = Instance.new("Frame")
		plate.Name = "Code"
		plate.BackgroundColor3 = Theme.color.navy
		plate.BorderSizePixel = 0
		plate.Size = UDim2.new(1, 0, 0, Ui.lobby.codeHeight)
		plate.LayoutOrder = order
		plate.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, Ui.radius.small)
		corner.Parent = plate
		local text = Components.label(plate, "Text", value, {
			face = Theme.font.roadBold,
			size = Ui.lobby.codeSize,
			align = Enum.TextXAlignment.Center,
		})
		text.Size = UDim2.fromScale(1, 1)
		-- El código entra con un golpe de tamaño: es lo primero que hay que leer en voz alta al grupo.
		local grow = Instance.new("UIScale")
		grow.Scale = 1.25
		grow.Parent = plate
		Components.tween(grow, Ui.motion.open, { Scale = 1 })
	end

	-- Rótulo corto dentro de una fila horizontal: los `Board.caption` ocupan todo el ancho.
	local function inline(
		parent: Instance,
		name: string,
		text: string,
		order: number,
		width: number
	): TextLabel
		local item = Components.label(parent, name, Strings.upper(text), {
			face = Theme.font.road,
			size = 13,
			tint = Board.muted,
		})
		item.Size = UDim2.fromOffset(width, 26)
		item.TextYAlignment = Enum.TextYAlignment.Center
		item.LayoutOrder = order
		return item
	end

	-- Dinero escrito a mano: solo dígitos mientras se teclea y, al salir del campo, el valor se
	-- recorta al rango válido. El número vive en la configuración; el texto solo lo enseña.
	local function cashInput(
		parent: Instance,
		order: number,
		initial: number,
		onChange: (number) -> ()
	): TextBox
		local box = Instance.new("TextBox")
		box.Name = "Cash"
		box.BackgroundColor3 = Theme.color.asphaltDeep
		box.BorderSizePixel = 0
		box.ClearTextOnFocus = false
		box.FontFace = Theme.font.roadBold
		box.TextSize = 24
		box.TextColor3 = Theme.color.limestone
		box.PlaceholderText = tostring(MatchSettings.DEFAULTS.startingCash)
		box.PlaceholderColor3 = Theme.color.steel
		box.Text = tostring(initial)
		box.Size = UDim2.fromOffset(150, 40)
		box.LayoutOrder = order
		box.Parent = parent
		local shape = Instance.new("UICorner")
		shape.CornerRadius = UDim.new(0, Ui.radius.small)
		shape.Parent = box
		local ring = Instance.new("UIStroke")
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ring.Color = Theme.color.limestoneDim
		ring.Thickness = 2
		ring.Parent = box
		box.Focused:Connect(function()
			ring.Color = Theme.color.navy
			ring.Thickness = 3
		end)
		box.FocusLost:Connect(function()
			ring.Color = Theme.color.limestoneDim
			ring.Thickness = 2
			local typed = tonumber(box.Text) or MatchSettings.DEFAULTS.startingCash
			local value = MatchSettings.clampCash(typed) or MatchSettings.DEFAULTS.startingCash
			box.Text = tostring(value)
			onChange(value)
		end)
		box:GetPropertyChangedSignal("Text"):Connect(function()
			local digits = string.gsub(box.Text, "%D", "")
			if digits ~= box.Text then
				box.Text = digits
			end
			local value = tonumber(digits)
			if value ~= nil then
				onChange(MatchSettings.clampCash(value) or MatchSettings.DEFAULTS.startingCash)
			end
		end)
		return box
	end

	-- Modo solo: un jugador y sus bots, en su propio servidor. No hace falta nadie más ni código.
	local function buildSolo(order: number)
		local poster = Board.Poster(window.stack, "Solo", order, false)
		poster.root.Size = UDim2.new(1, 0, 0, 124)
		local heading = Board.caption(poster.content, "Title", Strings.get("lobby.solo.title"), 1)
		heading.FontFace = Theme.font.roadBold
		heading.TextSize = 20
		heading.TextColor3 = Theme.color.asphalt

		local line = Instance.new("Frame")
		line.Name = "Controls"
		line.BackgroundTransparency = 1
		line.Size = UDim2.new(1, 0, 0, 56)
		line.LayoutOrder = 2
		line.Parent = poster.content
		local layout = Board.list(line, Enum.FillDirection.Horizontal, Theme.space.m)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center

		inline(line, "BotsLabel", Strings.get("lobby.solo.bots"), 1, 52)
		local minus = Components.SecondaryButton(line, "BotsMinus", "-")
		minus.root.Size = UDim2.fromOffset(40, 40)
		minus.root.LayoutOrder = 2
		minus.onActivated(function()
			if soloBots > 1 then
				soloBots -= 1
				rebuild()
			end
		end)
		local count = Components.label(line, "BotsCount", tostring(soloBots), {
			face = Theme.font.roadBold,
			size = 22,
			tint = Theme.color.asphalt,
			align = Enum.TextXAlignment.Center,
		})
		count.Size = UDim2.fromOffset(30, 40)
		count.TextYAlignment = Enum.TextYAlignment.Center
		count.LayoutOrder = 3
		local plus = Components.SecondaryButton(line, "BotsPlus", "+")
		plus.root.Size = UDim2.fromOffset(40, 40)
		plus.root.LayoutOrder = 4
		plus.onActivated(function()
			if soloBots < Protocol.MAX_BOTS then
				soloBots += 1
				rebuild()
			end
		end)

		inline(line, "CashLabel", Strings.get("lobby.solo.money"), 5, 110)
		cashInput(line, 6, soloSettings.startingCash, function(value: number)
			soloSettings.startingCash = value
		end)

		local mode = Components.SecondaryButton(line, "SoloMode", Strings.get(`lobby.mode.{soloMode}`))
		mode.root.Size = UDim2.fromOffset(140, 40)
		mode.root.LayoutOrder = 7
		mode.onActivated(function()
			soloMode = if soloMode == "Rounds" then "Endless" else "Rounds"
			rebuild()
		end)

		local start = Components.PrimaryButton(line, "SoloStart", Strings.get("lobby.solo.start"))
		start.root.Size = UDim2.fromOffset(250, 56)
		start.root.LayoutOrder = 8
		start.onActivated(function()
			request("Solo", {
				type = "SoloStart",
				bots = soloBots,
				endMode = soloMode,
				settings = table.clone(soloSettings),
			})
		end)
	end

	local function buildIdle(row: Frame)
		local create = column(row, "Create", 1, 1 / 3)
		title(create, "lobby.create", 1)
		Board.text(create.content, "Help", Strings.get("lobby.createHelp"), 2, 16)
		spacer(create, 3)
		local createButton =
			Components.PrimaryButton(create.content, "Create", Strings.get("lobby.createButton"))
		createButton.root.Size = UDim2.new(1, 0, 0, 72)
		createButton.root.LayoutOrder = 4
		createButton.onActivated(function()
			request("Create", { type = "PartyCreate" })
		end)

		local join = column(row, "Join", 2, 1 / 3)
		title(join, "lobby.join", 1)
		Board.text(join.content, "Help", Strings.get("lobby.joinHelp", { length = Lobby.codeLength }), 2, 16)
		local box = Instance.new("TextBox")
		box.Name = "CodeBox"
		box.BackgroundColor3 = Theme.color.asphaltDeep
		box.BorderSizePixel = 0
		box.ClearTextOnFocus = false
		box.FontFace = Theme.font.roadBold
		box.TextSize = 30
		box.TextColor3 = Theme.color.limestone
		box.PlaceholderText = Strings.get("lobby.joinPlaceholder")
		box.PlaceholderColor3 = Theme.color.steel
		box.Text = ""
		box.Size = UDim2.new(1, 0, 0, 56)
		box.LayoutOrder = 3
		box.Parent = join.content
		local boxCorner = Instance.new("UICorner")
		boxCorner.CornerRadius = UDim.new(0, Ui.radius.small)
		boxCorner.Parent = box
		local ring = Instance.new("UIStroke")
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ring.Color = Theme.color.limestoneDim
		ring.Thickness = 2
		ring.Parent = box
		box.Focused:Connect(function()
			ring.Color = Theme.color.navy
			ring.Thickness = 3
		end)
		box.FocusLost:Connect(function()
			ring.Color = Theme.color.limestoneDim
			ring.Thickness = 2
		end)
		-- El código se escribe en mayúsculas aunque se teclee en minúsculas.
		box:GetPropertyChangedSignal("Text"):Connect(function()
			local upper = string.upper(box.Text)
			if upper ~= box.Text then
				box.Text = upper
			end
		end)
		spacer(join, 4)
		local joinButton = Components.SecondaryButton(join.content, "Join", Strings.get("lobby.joinButton"))
		joinButton.root.Size = UDim2.new(1, 0, 0, 44)
		joinButton.root.LayoutOrder = 5
		joinButton.onActivated(function()
			request("Join", { type = "PartyJoin", code = box.Text })
		end)

		local public = column(row, "Public", 3, 1 / 3)
		title(public, "lobby.public", 1)
		Board.text(public.content, "Help", Strings.get("lobby.publicHelp"), 2, 16)
		spacer(public, 3)
		local publicButton =
			Components.SecondaryButton(public.content, "Public", Strings.get("lobby.publicButton"))
		publicButton.root.Size = UDim2.new(1, 0, 0, 44)
		publicButton.root.LayoutOrder = 4
		publicButton.onActivated(function()
			request("Queue", { type = "QueueJoin" })
		end)
	end

	-- Opciones de la partida: cada una con su nombre, sus valores en pestañas y una línea de ayuda. Las que
	-- solo valen en Rondas se esconden en Sin Fin.
	local function buildSettings(row: Frame)
		local poster = column(row, "Settings", 3, 0.4)
		title(poster, "lobby.settings", 1)
		-- Con el dinero escrito a mano la lista ya no cabe en pantallas bajas: se desplaza dentro del
		-- cartel en vez de salirse por abajo.
		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "Options"
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 6
		scroll.ScrollBarImageColor3 = Theme.color.asphalt
		scroll.ScrollingDirection = Enum.ScrollingDirection.Y
		scroll.Size = UDim2.fromScale(1, 0)
		scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.LayoutOrder = 2
		scroll.Parent = poster.content
		Board.fill(scroll)
		local options = Instance.new("UIListLayout")
		options.FillDirection = Enum.FillDirection.Vertical
		options.Padding = UDim.new(0, Theme.space.m)
		options.SortOrder = Enum.SortOrder.LayoutOrder
		options.Parent = scroll
		local order = 1
		for _, option in MatchSettings.OPTIONS do
			if option.roundsOnly == true and endMode ~= "Rounds" then
				continue
			end
			local caption = Board.caption(scroll, `{option.id}Label`, option.label, order)
			caption.FontFace = Theme.font.roadBold
			caption.TextSize = 16
			caption.TextColor3 = Theme.color.asphalt
			order += 1
			local tabs: { Board.Tab } = {}
			local current = (settings :: any)[option.id]
			local selected: string
			if option.kind == "toggle" then
				tabs = {
					{ id = "on", label = Strings.get("lobby.settings.on") },
					{ id = "off", label = Strings.get("lobby.settings.off") },
				}
				selected = if current == true then "on" else "off"
			else
				for _, choice in MatchSettings.choicesOf(option) do
					table.insert(tabs, { id = tostring(choice.value), label = choice.label })
				end
				selected = tostring(current)
			end
			Board.Tabs(scroll, order, tabs, selected, function(id: string)
				if option.kind == "toggle" then
					(settings :: any)[option.id] = id == "on"
				else
					for _, choice in MatchSettings.choicesOf(option) do
						if tostring(choice.value) == id then
							(settings :: any)[option.id] = choice.value
						end
					end
				end
				rebuild()
			end)
			order += 1
			-- El dinero inicial además se escribe a mano: las pestañas son atajos, no una lista cerrada.
			if option.id == "startingCash" then
				local box = cashInput(scroll, order, settings.startingCash, function(value: number)
					settings.startingCash = value
				end)
				box.Size = UDim2.new(1, -8, 0, 40)
				order += 1
			end
			local help = Board.text(scroll, `{option.id}Help`, option.help, order, 13)
			help.TextColor3 = Theme.color.asphalt
			order += 1
		end
		local reset = Components.SecondaryButton(scroll, "Reset", Strings.get("lobby.settings.reset"))
		reset.root.Size = UDim2.new(1, -8, 0, 36)
		reset.root.LayoutOrder = order
		reset.root.Visible = not MatchSettings.isDefault(settings)
		reset.onActivated(function()
			settings = MatchSettings.defaults()
			rebuild()
		end)
	end

	local function buildHost(row: Frame)
		local party = column(row, "Party", 1, 0.25)
		title(party, "lobby.yourParty", 1)
		codePlate(party.content, 2, code or "")
		Board.text(party.content, "Share", Strings.get("lobby.shareCode"), 3, 16)

		local mode = column(row, "Mode", 2, 0.35)
		title(mode, "lobby.mode", 1)
		local tabs: { Board.Tab } = {
			{ id = "Rounds", label = Strings.get("lobby.mode.Rounds") },
			{ id = "Endless", label = Strings.get("lobby.mode.Endless") },
		}
		Board.Tabs(mode.content, 2, tabs, endMode, function(id: string)
			endMode = if id == "Endless" then "Endless" else "Rounds"
			rebuild()
		end)
		Board.text(mode.content, "ModeHelp", Strings.get(`lobby.modeHelp.{endMode}`), 3, 17)
		spacer(mode, 4)
		local start = Components.PrimaryButton(mode.content, "Start", Strings.get("lobby.start"))
		start.root.Size = UDim2.new(1, 0, 0, 72)
		start.root.LayoutOrder = 5
		start.onActivated(function()
			request("Start", { type = "PartyStart", endMode = endMode, settings = table.clone(settings) })
		end)
		buildSettings(row)
	end

	local function buildWaiting(row: Frame, key: string)
		local poster = column(row, "Waiting", 1, 1)
		if code ~= nil then
			title(poster, "lobby.yourParty", 1)
			codePlate(poster.content, 2, code)
		end
		Board.text(poster.content, "Wait", Strings.get(key), 3, 20)
		spacer(poster, 4)
		local back = Components.SecondaryButton(poster.content, "Back", Strings.get("lobby.leaveView"))
		back.root.Size = UDim2.fromOffset(200, 44)
		back.root.LayoutOrder = 5
		back.onActivated(function()
			state = "Idle"
			rebuild()
		end)
	end

	rebuild = function()
		window.clear()
		Board.Header(window.stack, 1, {
			title = Strings.get("lobby.title"),
			help = Strings.get("lobby.help"),
			steps = { Strings.get("lobby.step1"), Strings.get("lobby.step2"), Strings.get("lobby.step3") },
		})
		local row = Instance.new("Frame")
		row.Name = "Middle"
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, 0)
		row.LayoutOrder = 2
		row.Parent = window.stack
		Board.fill(row)
		Board.list(row, Enum.FillDirection.Horizontal, Theme.space.l)
		if state == "Host" then
			buildHost(row)
		elseif state == "Guest" then
			buildWaiting(row, "lobby.guestWait")
		elseif state == "Queue" then
			buildWaiting(row, "lobby.queueWait")
		else
			buildIdle(row)
			buildSolo(3)
		end

		-- Pie: el último aviso del servidor. Un error lleva sello rojo, no solo color.
		local foot = Instance.new("Frame")
		foot.Name = "Footer"
		foot.BackgroundTransparency = 1
		foot.Size = UDim2.new(1, 0, 0, Ui.lobby.noticeHeight)
		foot.LayoutOrder = if state == "Idle" then 4 else 3
		foot.Parent = window.stack
		local layout = Board.list(foot, Enum.FillDirection.Horizontal, Theme.space.m)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		-- Salida siempre a la vista: el tablón no se cierra tocando fuera, así que lleva su propio botón.
		local back = Components.SecondaryButton(foot, "Close", closeLabel or Strings.get("lobby.leaveView"))
		back.root.Size = UDim2.fromOffset(190, 36)
		back.root.LayoutOrder = 0
		back.onActivated(function()
			window.setOpen(false)
		end)
		if noticeIsError then
			local stamp = Components.Stamp(foot, Strings.get("lobby.error"), "Loss", 14)
			stamp.LayoutOrder = 1
		end
		local notice = Components.label(foot, "Notice", noticeText, {
			face = Theme.font.text,
			size = 17,
			tint = Theme.color.limestone,
			wrap = true,
		})
		notice.Size = UDim2.fromScale(0, 1)
		notice.TextYAlignment = Enum.TextYAlignment.Center
		notice.LayoutOrder = 2
		Board.fill(notice)
	end

	rebuild()
	window.setOpen(true)

	return {
		setNotice = function(text: string, kind: string?)
			noticeText = text
			noticeIsError = kind == Protocol.NOTICE_KINDS.Error
			local found = NoticeRules.partyCode(text)
			local inherited = kind == Protocol.NOTICE_KINDS.Info
				and string.find(text, "anfitrión", 1, true) ~= nil
			if found ~= nil and (kind == Protocol.NOTICE_KINDS.PartyCode or inherited) then
				-- Party creada, o heredada al irse el anfitrión.
				code = found
				state = "Host"
			elseif kind == Protocol.NOTICE_KINDS.Info and lastRequest == "Join" and found ~= nil then
				code = found
				state = "Guest"
			elseif kind == Protocol.NOTICE_KINDS.Info and lastRequest == "Queue" then
				state = "Queue"
			end
			rebuild()
		end,
		setVisible = function(visible: boolean)
			window.setOpen(visible)
		end,
		isVisible = window.isOpen,
		onClosed = window.onClosed,
		destroy = function()
			window.gui:Destroy()
		end,
	}
end

return LobbyMenu

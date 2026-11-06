--!strict
-- Lobby sobre el tablón de obra: crear una party y enseñar su código, unirse con un código y entrar en
-- la cola pública. El anfitrión elige Rondas o Sin Fin, con la frase de cómo termina cada uno, y empieza.
-- Es la única pantalla antes de que exista una partida, así que también enseña los avisos del servidor:
-- un error sale en rojo, con sello. El estado (sin party, anfitrión, invitado, en cola) sale de lo que
-- el jugador pidió y del aviso con que responde el servidor.
local Board = require("./Board")
local Components = require("./Components")
local Lobby = require("../../shared/config/Lobby")
local NoticeRules = require("./NoticeRules")
local Protocol = require("../../shared/net/Protocol")
local Strings = require("../../shared/config/Strings")
local Theme = require("./Theme")
local Ui = require("../../shared/config/Ui")

export type Handles = {
	setNotice: (text: string, kind: string?) -> (),
	setVisible: (visible: boolean) -> (),
	isVisible: () -> boolean,
	destroy: () -> (),
}

type State = "Idle" | "Host" | "Guest" | "Queue"
type Request = "Create" | "Join" | "Queue" | "Start"

local LobbyMenu = {}

function LobbyMenu.create(playerGui: Instance, send: (request: any) -> ()): Handles
	local window = Board.Window(playerGui, "LobbyMenu", 9, false)
	local state: State = "Idle"
	local lastRequest: Request? = nil
	local code: string? = nil
	local endMode: "Rounds" | "Endless" = "Rounds"
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

	local function buildHost(row: Frame)
		local party = column(row, "Party", 1, 0.45)
		title(party, "lobby.yourParty", 1)
		codePlate(party.content, 2, code or "")
		Board.text(party.content, "Share", Strings.get("lobby.shareCode"), 3, 16)

		local mode = column(row, "Mode", 2, 0.55)
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
			request("Start", { type = "PartyStart", endMode = endMode })
		end)
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
		end

		-- Pie: el último aviso del servidor. Un error lleva sello rojo, no solo color.
		local foot = Instance.new("Frame")
		foot.Name = "Footer"
		foot.BackgroundTransparency = 1
		foot.Size = UDim2.new(1, 0, 0, Ui.lobby.noticeHeight)
		foot.LayoutOrder = 3
		foot.Parent = window.stack
		local layout = Board.list(foot, Enum.FillDirection.Horizontal, Theme.space.m)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
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
		destroy = function()
			window.gui:Destroy()
		end,
	}
end

return LobbyMenu

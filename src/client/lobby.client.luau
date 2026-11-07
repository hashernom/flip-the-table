--!strict
-- Cliente del lobby provisional (solo en el lugar del lobby: `lobby.project.json` lo monta en vez de
-- `main.client`, y `default.project.json` lo ignora). El jugador camina por el parque y se sienta en una mesa
-- para jugar con quien esté a su lado; el botón «Jugar con amigos» abre el tablón de party y cola de siempre.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- R-P17: `shared` se monta junto al código del cliente, como hermano de `Client`, y Roblox copia
-- `StarterPlayerScripts` a `PlayerScripts` por partes. Este LocalScript empieza a correr antes de que
-- `shared` exista, así que hay que esperarla antes del primer `require` relativo o el lobby se queda
-- sin interfaz (error «could not resolve child component "shared"»).
local SHARED_WAIT_SEC = 10
local REMOTE_WAIT_SEC = 15

local player = Players.LocalPlayer
local playerScripts = script.Parent.Parent
local playerGui = player:WaitForChild("PlayerGui")

playerScripts:WaitForChild("shared", SHARED_WAIT_SEC)

local Components = require("./ui/Components")
local LobbyMenu = require("./ui/LobbyMenu")
local Look = require("./world/Look")
local Protocol = require("../shared/net/Protocol")
local Strings = require("../shared/config/Strings")
local Theme = require("./ui/Theme")
local Ui = require("../shared/config/Ui")

Look.applyLobby()

local remotes = ReplicatedStorage:WaitForChild("FlipTheTableRemotes", REMOTE_WAIT_SEC)

local function send(request: any)
	if remotes == nil or type(request) ~= "table" then
		return
	end
	local field: string? = nil
	for key, _ in Protocol.REMOTES :: any do
		if key == request.type then
			field = key
		end
	end
	local name = if field ~= nil then (Protocol.REMOTES :: any)[field] else nil
	local remote = if type(name) == "string" then remotes:FindFirstChild(name) else nil
	if remote ~= nil and remote:IsA("RemoteEvent") then
		remote:FireServer(request)
	end
end

local menu = LobbyMenu.create(playerGui, send, Strings.get("lobby.backToPark"))
menu.setVisible(false)

-- Interfaz propia del parque: un cartel arriba con lo que hay que hacer y el botón del tablón.
local gui = Theme.screenGui(playerGui, "LobbyPark", 4)

local hint = Components.Panel(gui, "Hint", Ui.radius.card)
hint.root.AnchorPoint = Vector2.new(0.5, 0)
hint.root.Position = UDim2.new(0.5, 0, 0, Ui.signTop)
hint.root.Size = UDim2.fromOffset(560, 54)
local hintText = Components.label(hint.body, "Text", Strings.get("lobbyPark.hint"), {
	face = Theme.font.road,
	size = 18,
	align = Enum.TextXAlignment.Center,
	wrap = true,
})
hintText.ZIndex = 5
hintText.Size = UDim2.new(1, -24, 1, 0)
hintText.Position = UDim2.fromOffset(12, 0)

-- Botones de abajo: crear o unirse a una party (abre el tablón) y partida rápida (la cola pública).
-- Van en una barra propia para que el par quede siempre centrado, aunque uno sea más ancho que el otro.
local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -24)
bar.BackgroundTransparency = 1
bar.Size = UDim2.fromOffset(0, 64)
bar.AutomaticSize = Enum.AutomaticSize.X
bar.Parent = gui
local barLayout = Instance.new("UIListLayout")
barLayout.FillDirection = Enum.FillDirection.Horizontal
barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
barLayout.Padding = UDim.new(0, 16)
barLayout.Parent = bar

local friends = Components.PrimaryButton(bar, "Friends", Strings.get("lobbyPark.friends"))
friends.root.Size = UDim2.fromOffset(480, 64)
local quick = Components.SecondaryButton(bar, "Quick", Strings.get("lobbyPark.quick"))
quick.root.Size = UDim2.fromOffset(240, 52)
quick.onActivated(function()
	send({ type = "QueueJoin" })
end)

local function setMenu(open: boolean)
	menu.setVisible(open)
	bar.Visible = not open
	hint.root.Visible = not open
end

-- El tablón trae su propio botón «Volver al parque»: al cerrarse, el parque recupera sus botones.
menu.onClosed(function()
	setMenu(false)
end)

friends.onActivated(function()
	setMenu(true)
end)
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and menu.isVisible() then
		setMenu(false)
	elseif input.KeyCode == Enum.KeyCode.P then
		setMenu(not menu.isVisible())
	end
end)

-- Avisos del servidor: los de party y cola van al tablón (y lo abren); los de las mesas, al cartel de arriba.
if remotes ~= nil then
	local noticeRemote = remotes:WaitForChild(Protocol.REMOTES.Notice, REMOTE_WAIT_SEC)
	if noticeRemote ~= nil and noticeRemote:IsA("RemoteEvent") then
		noticeRemote.OnClientEvent:Connect(function(notice: any)
			if type(notice) ~= "table" or type(notice.message) ~= "string" then
				return
			end
			if menu.isVisible() then
				menu.setNotice(notice.message, notice.kind)
			else
				hintText.Text = notice.message
				task.delay(6, function()
					if hintText.Text == notice.message then
						hintText.Text = Strings.get("lobbyPark.hint")
					end
				end)
			end
		end)
	end
end

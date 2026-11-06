--!strict
-- Cliente del lobby provisional (solo en el lugar del lobby: `lobby.project.json` lo monta en vez de
-- `main.client`, y `default.project.json` lo ignora). El jugador camina por el parque y se sienta en una mesa
-- para jugar con quien esté a su lado; el botón «Jugar con amigos» abre el tablón de party y cola de siempre.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Components = require("./ui/Components")
local LobbyMenu = require("./ui/LobbyMenu")
local Look = require("./world/Look")
local Protocol = require("../shared/net/Protocol")
local Strings = require("../shared/config/Strings")
local Theme = require("./ui/Theme")
local Ui = require("../shared/config/Ui")

local REMOTE_WAIT_SEC = 15

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

Look.apply()

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

local menu = LobbyMenu.create(playerGui, send)
menu.setVisible(false)

-- Interfaz propia del parque: un cartel arriba con lo que hay que hacer y el botón del tablón.
local gui = Theme.screenGui(playerGui, "LobbyPark", 4)

local hint = Components.Panel(gui, "Hint", Ui.radius.card)
hint.root.AnchorPoint = Vector2.new(0.5, 0)
hint.root.Position = UDim2.new(0.5, 0, 0, Ui.signTop)
hint.root.Size = UDim2.fromOffset(560, 54)
local hintText = Components.label(hint.root, "Text", Strings.get("lobbyPark.hint"), {
	face = Theme.font.road,
	size = 18,
	align = Enum.TextXAlignment.Center,
	wrap = true,
})
hintText.Size = UDim2.new(1, -24, 1, 0)
hintText.Position = UDim2.fromOffset(12, 0)

local friends = Components.PrimaryButton(gui, "Friends", Strings.get("lobbyPark.friends"))
friends.root.AnchorPoint = Vector2.new(0.5, 1)
friends.root.Position = UDim2.new(0.5, 0, 1, -24)
friends.root.Size = UDim2.fromOffset(300, 64)

local function setMenu(open: boolean)
	menu.setVisible(open)
	friends.root.Visible = not open
	hint.root.Visible = not open
end

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

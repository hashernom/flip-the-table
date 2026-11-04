--!strict
-- Único punto de cableado del cliente. Monta la ciudad, la cola de eventos, el estado, las fichas, la
-- cámara y el director de escenas, y los conecta con los remotos del servidor. Ningún otro archivo
-- del cliente crea instancias por su cuenta.
--
-- Arranca en un `task.spawn` a propósito: un `LocalScript` empieza a correr en cuanto se copia a
-- `PlayerScripts`, antes de que estén todos sus hermanos, y `shared` es hermano suyo (R-P17). Los
-- `require` van dentro de `boot`, después de esperar esa carpeta, o la primera partida de cada
-- servidor se quedaría sin cliente.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Color de la franja de cada asiento. Es lo único que distingue una ficha de otra en el arte gris.
local SEAT_COLORS = {
	Color3.fromRGB(230, 90, 90),
	Color3.fromRGB(90, 160, 230),
	Color3.fromRGB(110, 200, 120),
	Color3.fromRGB(230, 190, 80),
	Color3.fromRGB(180, 120, 230),
	Color3.fromRGB(90, 200, 200),
	Color3.fromRGB(230, 140, 60),
	Color3.fromRGB(200, 200, 210),
}

-- Mientras no llegue la primera vista, el cliente monta el tablero pequeño. El tamaño real viaja en
-- `view.sizeId` y se aplica al recibirlo.
local DEFAULT_SIZE: "S" | "M" | "L" = "S"
local SHARED_WAIT_SEC = 10
local REMOTE_WAIT_SEC = 20
-- Cada cuánto mira la cola si ya venció el siguiente lote. Mismo orden que el latido del servidor.
local TICK_SEC = 0.05

local player = Players.LocalPlayer
local playerScripts = script.Parent.Parent
local playerId = tostring(player.UserId)

local function seatColor(index: number): Color3
	return SEAT_COLORS[(index - 1) % #SEAT_COLORS + 1]
end

-- Rótulo gris de la escena en curso. Es el arte temporal que la subfase 09 sustituye por la interfaz
-- final; aquí solo tiene que dejar claro qué está pasando.
local function createBanner(): TextLabel
	local gui = Instance.new("ScreenGui")
	gui.Name = "SceneBanner"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 24)
	label.Size = UDim2.new(0, 420, 0, 54)
	label.BackgroundColor3 = Color3.fromRGB(32, 34, 38)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(240, 240, 240)
	label.Text = ""
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = label

	return label
end

local function boot()
	-- R-P17: `shared` se monta junto al código del cliente para que la misma cadena relativa resuelva
	-- en el disco, en Lune y en el DataModel. Hay que esperarla antes de pedir nada.
	playerScripts:WaitForChild("shared", SHARED_WAIT_SEC)

	local CameraDirector = require("./camera/CameraDirector")
	local CityBuilder = require("./world/CityBuilder")
	local TokenRider = require("./world/TokenRider")
	local EventQueue = require("./state/EventQueue")
	local StateStore = require("./state/StateStore")
	local SceneDirector = require("./scenes/SceneDirector")
	local Protocol = require("../shared/net/Protocol")

	local banner = createBanner()
	local city = CityBuilder.build(DEFAULT_SIZE, Workspace)
	local director = CameraDirector.new(player, DEFAULT_SIZE)
	local scenes = SceneDirector.new({
		show = function(text: string)
			banner.Text = text
		end,
	})

	local queue = EventQueue.new()
	local tokens: { [string]: Model } = {}
	local myToken: Model? = nil
	local sceneRunning = false

	-- Una ficha por asiento del servidor, también para los bots: el resto del grupo tiene que ver a
	-- todo el mundo sobre su casilla, no solo a quien tiene cliente.
	local function ensureToken(id: string, index: number): Model
		local existing = tokens[id]
		if existing then
			return existing
		end
		local token = TokenRider.create(id, DEFAULT_SIZE, seatColor(index), city.tokens)
		TokenRider.place(token, index)
		tokens[id] = token
		if id == playerId then
			myToken = token
			director.follow(token)
		end
		return token
	end

	-- Las fichas siguen al servidor: la posición de la vista es la que manda, no una cuenta local.
	local function syncTokens(view: any)
		if view == nil or view.players == nil then
			return
		end
		for _, seated in view.players do
			local token = ensureToken(seated.id, seated.position)
			if token:GetAttribute("Index") ~= seated.position then
				TokenRider.place(token, seated.position)
			end
		end
	end

	-- El recorrido de una ficha es una escena: el grupo entero ve cómo se mueve. `ride` corre por su
	-- cuenta y devuelve lo que tardó, que el director descuenta del hueco de la escena.
	SceneDirector.register(scenes, "TokenMoved", {
		run = function(ctx, event)
			local id = event.playerId
			local path = event.path
			local token = if type(id) == "string" then tokens[id] else nil
			if token == nil or type(path) ~= "table" or #path == 0 then
				ctx.wait(ctx.duration)
				return
			end
			local used = TokenRider.ride(token, path, ctx.duration)
			ctx.spent(used)
		end,
	})

	local function context()
		local view = StateStore.view(queue.state)
		local active = false
		if view ~= nil then
			local turn = view.players[view.turnIndex]
			active = turn ~= nil and turn.id == playerId
		end
		return { isActive = active, sceneRunning = sceneRunning }
	end

	CameraDirector.start(director, context)

	local remotes = ReplicatedStorage:WaitForChild("FlipTheTableRemotes", REMOTE_WAIT_SEC)
	if remotes == nil then
		warn("Cliente: el servidor no creó los remotos; la ciudad se queda sin partida")
		return
	end
	local eventBatch = remotes:WaitForChild(Protocol.REMOTES.Batch, REMOTE_WAIT_SEC) :: RemoteEvent
	local resync = remotes:WaitForChild(Protocol.REMOTES.Resync, REMOTE_WAIT_SEC) :: RemoteEvent

	-- Lotes del servidor. El primero de todos llega con `seq = 0`: es la vista inicial, no un lote
	-- nuevo (R-P25), y se aplica sin reproducir nada.
	eventBatch.OnClientEvent:Connect(function(batch: any)
		if type(batch) ~= "table" or type(batch.seq) ~= "number" then
			return
		end
		if batch.seq == 0 then
			EventQueue.resync(queue, batch.view, 0)
			syncTokens(batch.view)
			return
		end
		if EventQueue.push(queue, batch) == "Gap" then
			resync:FireServer()
		end
	end)

	-- Respuesta a una petición de resincronización: vista completa y salto de `seq`.
	resync.OnClientEvent:Connect(function(batch: any)
		if type(batch) ~= "table" or type(batch.seq) ~= "number" then
			return
		end
		EventQueue.resync(queue, batch.view, batch.seq)
		syncTokens(batch.view)
	end)

	-- Bucle del cliente: entrega los lotes cuando les toca, aplica su estado y reproduce sus escenas.
	task.spawn(function()
		while true do
			local due = EventQueue.nextDue(queue, Workspace:GetServerTimeNow())
			if due ~= nil then
				StateStore.apply(queue.state, due)
				syncTokens(due.view)
				sceneRunning = true
				SceneDirector.play(scenes, due)
				sceneRunning = false
				banner.Text = ""
			else
				task.wait(TICK_SEC)
			end
		end
	end)

	-- El avatar local monta en su ficha en cuanto la vista dice dónde está.
	task.spawn(function()
		local character = player.Character or player.CharacterAdded:Wait()
		character:WaitForChild("Humanoid", 10)
		character:WaitForChild("HumanoidRootPart", 10)
		local deadline = os.clock() + REMOTE_WAIT_SEC
		while myToken == nil and os.clock() < deadline do
			local view = StateStore.view(queue.state)
			if view ~= nil then
				syncTokens(view)
			end
			task.wait(TICK_SEC)
		end
		local token = myToken
		if token ~= nil then
			TokenRider.mount(player, token)
		end
	end)
end

task.spawn(boot)

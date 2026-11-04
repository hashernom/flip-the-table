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
	local ActionMenu = require("./ui/ActionMenu")
	local Hud = require("./ui/Hud")
	local LobbyMenu = require("./ui/LobbyMenu")
	local Overview = require("./ui/Overview")
	local PactMenu = require("./ui/PactMenu")
	local PerkMenu = require("./ui/PerkMenu")
	local TradeMenu = require("./ui/TradeMenu")
	local VoteMenu = require("./ui/VoteMenu")
	local Scenes = require("../shared/config/Scenes")

	local playerGui = player:WaitForChild("PlayerGui")
	local city = CityBuilder.build(DEFAULT_SIZE, Workspace)
	local director = CameraDirector.new(player, DEFAULT_SIZE)

	local hud = Hud.create(playerGui, function()
		return Workspace:GetServerTimeNow()
	end)
	local actionMenu = ActionMenu.create(playerGui)
	local overview = Overview.create(playerGui)
	local tradeMenu = TradeMenu.create(playerGui, function() end)
	local pactMenu = PactMenu.create(playerGui, function() end)
	local voteMenu = VoteMenu.create(playerGui, function() end)
	local perkMenu = PerkMenu.create(playerGui, function() end)
	local lobbyMenu = LobbyMenu.create(playerGui, function() end)

	local scenes = SceneDirector.new({
		show = function(text: string)
			hud.setBanner(text)
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

	-- Aplica una vista a la vez a la barra, los asientos y los menús. Es el único sitio que lo hace:
	-- así la interfaz nunca enseña dos verdades distintas.
	local function applyView(view: any)
		if view == nil then
			return
		end
		hud.setView(view)
		-- La primera vista con partida en marcha cierra el lobby: ya hay mesa.
		lobbyMenu.setVisible(false)
		actionMenu.setLegal(view.legalActions or {})
		overview.setView(view)
		tradeMenu.setView(view)
		pactMenu.setView(view)
		voteMenu.setView(view)
		perkMenu.setView(view)
		if view.phase == "GameOver" then
			lobbyMenu.setVisible(false)
		end
	end

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
			applyView(batch.view)
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

	-- Remotos de acción y de emote. El de acción es el mismo que valida el servidor: aquí solo se
	-- manda la intención, nunca un resultado.
	-- Un remoto que falte no puede llevarse el cliente por delante: sin él se pierde esa función, no la
	-- partida. El servidor los crea al arrancar, así que en una partida real están.
	local actionRemote = remotes:WaitForChild(Protocol.REMOTES.Action, REMOTE_WAIT_SEC)
	local emoteRemote = remotes:WaitForChild(Protocol.REMOTES.Emote, REMOTE_WAIT_SEC)

	if actionRemote and actionRemote:IsA("RemoteEvent") then
		local actionEvent = actionRemote :: RemoteEvent
		actionMenu.onAction(function(action: any)
			actionEvent:FireServer(action)
		end)
	else
		warn("Cliente: falta el remoto de acciones; los menús no podrán jugar")
	end

	-- La vista general se pide con el botón de la barra. Mientras hay una escena, la petición se queda
	-- guardada: la escena no se interrumpe y la maqueta se abre al terminar.
	local overviewWanted = false
	hud.onOverview(function()
		overviewWanted = not overviewWanted
		overview.setOpen(overviewWanted)
		director.requestOverview(overviewWanted)
	end)

	if emoteRemote and emoteRemote:IsA("RemoteEvent") then
		local emoteEvent = emoteRemote :: RemoteEvent
		hud.onEmote(function(emote: string)
			emoteEvent:FireServer(emote)
		end)
		-- Los emotes llegan de todo el grupo: burbuja sobre la ficha de quien lo lanza.
		emoteEvent.OnClientEvent:Connect(function(fromId: any, emote: any)
			if type(fromId) ~= "string" or type(emote) ~= "string" then
				return
			end
			local token: Model? = tokens[fromId]
			if token ~= nil then
				TokenRider.bubble(token, emote)
			end
		end)
	else
		warn("Cliente: falta el remoto de emotes; se juega sin emotes")
	end

	-- Bucle del cliente: entrega los lotes cuando les toca, aplica su estado y reproduce sus escenas.
	task.spawn(function()
		while true do
			local due = EventQueue.nextDue(queue, Workspace:GetServerTimeNow())
			if due ~= nil then
				StateStore.apply(queue.state, due)
				syncTokens(due.view)
				applyView(due.view)
				sceneRunning = true
				SceneDirector.play(scenes, due)
				sceneRunning = false
				hud.setBanner("")
				-- La decisión no empieza hasta que termina la escena: el plazo se cuenta desde aquí,
				-- igual que hace el reloj del servidor.
				local view = StateStore.view(queue.state)
				if view ~= nil and view.phase ~= "GameOver" then
					hud.setDeadline(Workspace:GetServerTimeNow() + Scenes.decisionSeconds(view.phase))
				else
					hud.setDeadline(nil)
				end
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

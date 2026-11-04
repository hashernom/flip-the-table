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

-- Tablero con el que se arranca antes de que llegue la primera vista. El tamaño real lo manda el
-- servidor en `view.sizeId` y la ciudad se reconstruye al recibirlo.
local START_SIZE: "S" | "M" | "L" = "S"
local SHARED_WAIT_SEC = 10
local REMOTE_WAIT_SEC = 20
-- Cada cuánto mira la cola si ya venció el siguiente lote. Mismo orden que el latido del servidor.
local TICK_SEC = 0.05

-- Botones que no vienen de `legalActions`: un trato o un pacto se deciden en su ventana, y el motor no
-- los enumera como acción legal porque necesitan más datos que un clic.
local SOCIAL_BUTTONS = {
	{ id = "Trade", label = "Tratos", action = { type = "__OpenTrade" } },
	{ id = "Pact", label = "Pactos", action = { type = "__OpenPact" } },
}

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
	local BuildingView = require("./world/BuildingView")
	local CityBuilder = require("./world/CityBuilder")
	local TokenRider = require("./world/TokenRider")
	local WorldRules = require("./world/WorldRules")
	local EventQueue = require("./state/EventQueue")
	local StateStore = require("./state/StateStore")
	local ViewWire = require("./state/ViewWire")
	local SceneDirector = require("./scenes/SceneDirector")
	local Protocol = require("../shared/net/Protocol")
	local ActionMenu = require("./ui/ActionMenu")
	local Hud = require("./ui/Hud")
	local LobbyMenu = require("./ui/LobbyMenu")
	local Overview = require("./ui/Overview")
	local PactMenu = require("./ui/PactMenu")
	local PerkMenu = require("./ui/PerkMenu")
	local RematchMenu = require("./ui/RematchMenu")
	local TradeMenu = require("./ui/TradeMenu")
	local VoteMenu = require("./ui/VoteMenu")

	local playerGui = player:WaitForChild("PlayerGui")

	-- Los remotos se resuelven más abajo, pero los menús se crean antes: estas funciones se reasignan
	-- en cuanto los remotos existen y las clausuras ven el valor nuevo.
	local sendAction: (action: any) -> () = function() end
	local sendLobby: (request: any) -> () = function() end

	local hud = Hud.create(playerGui, function()
		return Workspace:GetServerTimeNow()
	end)
	local actionMenu = ActionMenu.create(playerGui)
	local overview = Overview.create(playerGui)
	local tradeMenu = TradeMenu.create(playerGui, function(action: any)
		sendAction(action)
	end)
	local pactMenu = PactMenu.create(playerGui, function(action: any)
		sendAction(action)
	end)
	local voteMenu = VoteMenu.create(playerGui, function(action: any)
		sendAction(action)
	end)
	local perkMenu = PerkMenu.create(playerGui, function(action: any)
		sendAction(action)
	end)
	local lobbyMenu = LobbyMenu.create(playerGui, function(request: any)
		sendLobby(request)
	end)
	local rematchMenu = RematchMenu.create(playerGui)

	local scenes = SceneDirector.new({
		wait = function(seconds: number)
			task.wait(seconds)
		end,
		show = function(text: string)
			hud.setBanner(text)
		end,
		log = function(message: string)
			warn(message)
		end,
	})

	local queue = EventQueue.new()
	local director = CameraDirector.new(player, START_SIZE)
	local tokens: { [string]: Model } = {}
	local myToken: Model? = nil
	local sceneRunning = false
	local city: CityBuilder.CityHandles? = nil
	local size: string? = nil

	-- La ciudad se construye con el tamaño que anuncia el servidor. Si la partida es de 5 a 8
	-- jugadores el tablero es de 48 o 56 casillas, y una ciudad de 40 no sirve: se tira la vieja y se
	-- levanta la nueva con sus fichas.
	local function ensureCity(sizeId: string)
		if size == sizeId and city ~= nil then
			return
		end
		local previous = city
		city = nil
		tokens = {}
		myToken = nil
		if previous ~= nil then
			previous.destroy()
		end
		local handles = CityBuilder.build(sizeId :: CityBuilder.SizeId, Workspace)
		city = handles
		size = sizeId
		BuildingView.bind(handles)
		director.setSize(sizeId :: CityBuilder.SizeId)
	end

	-- Una ficha por asiento del servidor, también para los bots: el resto del grupo tiene que ver a todo
	-- el mundo sobre su casilla, no solo a quien tiene cliente.
	local function ensureToken(id: string, seat: number, index: number): Model?
		local existing = tokens[id]
		if existing then
			return existing
		end
		local handles = city
		if handles == nil then
			return nil
		end
		local token = TokenRider.create(id, handles.sizeId, seatColor(seat), handles.tokens)
		TokenRider.place(token, index)
		tokens[id] = token
		if id == playerId then
			myToken = token
		end
		return token
	end

	-- Las fichas siguen al servidor: la posición de la vista es la que manda. Se llama con la vista
	-- inicial y al terminar las escenas de un lote, nunca antes: llamarla antes haría que la ficha
	-- saltara al destino y luego volviera a recorrer la calle.
	local function syncTokens(view: any)
		if view == nil or view.players == nil then
			return
		end
		ensureCity(view.sizeId)
		-- En una revancha sigue solo quien aceptó: la ficha de quien se fue no se queda en la calle.
		local seatedIds: { [string]: boolean } = {}
		for _, seated in view.players do
			seatedIds[seated.id] = true
		end
		for id, token in tokens do
			if not seatedIds[id] then
				token:Destroy()
				tokens[id] = nil
			end
		end
		local offsets = WorldRules.tokenOffsets(view.players)
		for seat, seated in view.players do
			local token = ensureToken(seated.id, seat, seated.position)
			if token ~= nil and not TokenRider.isAt(token, seated.position, offsets[seated.id]) then
				TokenRider.place(token, seated.position, offsets[seated.id])
			end
			-- Las fichas son locales de cada cliente, así que la soldadura de un avatar no se replica: cada
			-- cliente sube también a los demás a su copia de la ficha, o los vería flotando en la salida.
			-- Si su personaje aún no ha llegado, se reintenta con el siguiente lote.
			local userId = tonumber(seated.id)
			local other = if userId ~= nil then Players:GetPlayerByUserId(userId) else nil
			if
				token ~= nil
				and other ~= nil
				and other ~= player
				and not TokenRider.isMounted(other, token)
			then
				TokenRider.mount(other, token)
			end
		end
		BuildingView.sync(view.properties or {}, function(ownerId: string): Color3?
			local seat = WorldRules.seatOf(view.players, ownerId)
			return if seat ~= nil then seatColor(seat) else nil
		end)
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
			-- La vista del lote ya lleva el resultado, así que se sabe a qué sitio de la casilla llega.
			local view = StateStore.view(queue.state)
			local arrival = if view ~= nil then WorldRules.tokenOffsets(view.players)[id] else nil
			local used = TokenRider.ride(token, path, ctx.duration, arrival)
			ctx.spent(used)
		end,
	})

	-- La cámara sigue a la ficha del turno, sea de quien sea: es lo que hace que el resto del grupo vea
	-- la jugada del activo, como pide la tabla «Qué ve cada jugador».
	local function followActive(view: any)
		if view == nil then
			return
		end
		local turn = view.players[view.turnIndex]
		local target = if turn ~= nil then tokens[turn.id] else nil
		director.follow(target or myToken)
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

	-- La maqueta se abre y se cierra con el modo de cámara, no con el botón: si el jugador la pide justo
	-- cuando empieza una escena, la petición queda guardada y se abre al terminar. Una escena no se
	-- interrumpe nunca.
	local overviewWanted = false
	hud.onOverview(function()
		overviewWanted = not overviewWanted
		director.requestOverview(overviewWanted)
	end)
	-- Cerrar con el fondo también cancela la petición: si no, la cámara seguiría orbitando con la
	-- maqueta cerrada y harían falta dos pulsaciones para volver.
	overview.onToggle(function(open: boolean)
		if not open and overviewWanted then
			overviewWanted = false
			director.requestOverview(false)
		end
	end)

	task.spawn(function()
		while true do
			overview.setOpen(overviewWanted and director.mode() == "Overview")
			task.wait(0.1)
		end
	end)

	local remotes = ReplicatedStorage:WaitForChild("FlipTheTableRemotes", REMOTE_WAIT_SEC)
	if remotes == nil then
		warn("Cliente: el servidor no creó los remotos; la ciudad se queda sin partida")
		return
	end

	-- Un remoto que falte no puede llevarse el cliente por delante: sin él se pierde esa función, no la
	-- partida. El servidor los crea al arrancar, así que en una partida real están.
	local actionRemote = remotes:WaitForChild(Protocol.REMOTES.Action, REMOTE_WAIT_SEC)
	local emoteRemote = remotes:WaitForChild(Protocol.REMOTES.Emote, REMOTE_WAIT_SEC)
	local eventBatch = remotes:WaitForChild(Protocol.REMOTES.Batch, REMOTE_WAIT_SEC) :: RemoteEvent
	local resync = remotes:WaitForChild(Protocol.REMOTES.Resync, REMOTE_WAIT_SEC) :: RemoteEvent

	if actionRemote and actionRemote:IsA("RemoteEvent") then
		local actionEvent = actionRemote :: RemoteEvent
		sendAction = function(action: any)
			actionEvent:FireServer(action)
		end
	else
		warn("Cliente: falta el remoto de acciones; los menús no podrán jugar")
	end

	-- Peticiones del lobby. En el lugar de partida no hay servicio que las escuche; el lugar del lobby
	-- tendrá el suyo en la subfase 09.
	local function connectLobby(field: string, remote: Instance)
		if not remote:IsA("RemoteEvent") then
			return
		end
		local lobbyRemote = remote :: RemoteEvent
		local previous = sendLobby
		sendLobby = function(request: any)
			if request.type ~= field then
				previous(request)
				return
			end
			-- El servidor valida el paquete entero con Protocol.validateLobby: tipo y campos.
			lobbyRemote:FireServer(request)
		end
	end

	for _, field in { "PartyCreate", "PartyJoin", "PartyStart", "QueueJoin" } do
		local name = (Protocol.REMOTES :: any)[field]
		local remote = if type(name) == "string" then remotes:FindFirstChild(name) else nil
		if remote ~= nil then
			connectLobby(field, remote :: Instance)
		end
	end

	-- Los botones sociales abren su ventana; el resto se manda al servidor tal cual.
	actionMenu.onAction(function(action: any)
		if action.type == "__OpenTrade" then
			tradeMenu.setOpen(true)
			return
		elseif action.type == "__OpenPact" then
			pactMenu.setOpen(true)
			return
		end
		sendAction(action)
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

	-- Aplica una vista a la barra, los asientos y los menús. Es el único sitio que lo hace: así la
	-- interfaz nunca enseña dos verdades distintas.
	-- Cada pieza va protegida: un menú con un fallo pierde su función, no se lleva por delante el bucle
	-- del cliente, que dejaría al jugador sin partida hasta que vuelva a entrar.
	local function applyView(view: any)
		if view == nil then
			return
		end
		local steps: { [string]: () -> () } = {
			Hud = function()
				hud.setView(view)
			end,
			LobbyMenu = function()
				lobbyMenu.setVisible(false)
			end,
			ActionMenu = function()
				actionMenu.setLegal(view.legalActions or {}, SOCIAL_BUTTONS)
			end,
			Overview = function()
				overview.setView(view)
			end,
			TradeMenu = function()
				tradeMenu.setView(view)
			end,
			PactMenu = function()
				pactMenu.setView(view)
			end,
			VoteMenu = function()
				voteMenu.setView(view)
			end,
			PerkMenu = function()
				perkMenu.setView(view)
			end,
			RematchMenu = function()
				rematchMenu.setView(view)
			end,
		}
		for name, step in steps do
			local ok: boolean, err: any = (pcall :: any)(step)
			if not ok then
				warn(`Cliente: {name} falló al aplicar la vista: {err}`)
			end
		end
	end

	-- Declarada aquí porque una partida nueva la necesita; se asigna más abajo.
	local mountLocal: () -> () = function() end

	-- Durante una escena no se decide nada (R-P39): el servidor descartaría el clic. Los menús vuelven
	-- con la vista del lote, al terminar la escena.
	local function hideMenus()
		actionMenu.setLegal({}, nil)
		voteMenu.close()
		perkMenu.close()
		hud.setDeadline(nil)
	end

	-- Lotes del servidor. El primero de todos llega con `seq = 0`: es la vista inicial, no un lote nuevo
	-- (R-P25), y se aplica sin reproducir nada.
	eventBatch.OnClientEvent:Connect(function(batch: any)
		if type(batch) ~= "table" or type(batch.seq) ~= "number" then
			return
		end
		ViewWire.normalize(batch.view)
		-- En una revancha, este lote es también la señal de partida nueva: la cola, las escenas vistas y
		-- las fichas vuelven a empezar, y si el tablero cambió de tamaño la ficha propia es otra.
		if batch.seq == 0 then
			EventQueue.resync(queue, batch.view, 0)
			SceneDirector.reset(scenes)
			syncTokens(batch.view)
			applyView(batch.view)
			followActive(batch.view)
			hud.setDeadline(batch.decisionDeadline)
			task.spawn(mountLocal)
			return
		end
		if EventQueue.push(queue, batch) == "Gap" then
			resync:FireServer()
		end
	end)

	-- Respuesta a una petición de resincronización: vista completa y salto de `seq`. La interfaz se
	-- actualiza aquí también, que es justo el camino del cliente que se quedó atrás.
	resync.OnClientEvent:Connect(function(batch: any)
		if type(batch) ~= "table" or type(batch.seq) ~= "number" then
			return
		end
		ViewWire.normalize(batch.view)
		EventQueue.resync(queue, batch.view, batch.seq)
		syncTokens(batch.view)
		applyView(batch.view)
		followActive(batch.view)
		hud.setDeadline(batch.decisionDeadline)
	end)

	-- La votación de revancha y los avisos del servidor. Sin estos remotos se juega igual.
	local rematchRemote = remotes:WaitForChild(Protocol.REMOTES.Rematch, REMOTE_WAIT_SEC)
	if rematchRemote and rematchRemote:IsA("RemoteEvent") then
		local rematchEvent = rematchRemote :: RemoteEvent
		rematchMenu.onVote(function(accept: boolean)
			rematchEvent:FireServer(accept)
		end)
	else
		warn("Cliente: falta el remoto de revancha; no se podrá votar")
	end
	local noticeRemote = remotes:WaitForChild(Protocol.REMOTES.Notice, REMOTE_WAIT_SEC)
	if noticeRemote and noticeRemote:IsA("RemoteEvent") then
		(noticeRemote :: RemoteEvent).OnClientEvent:Connect(function(notice: any)
			if type(notice) == "table" and type(notice.message) == "string" then
				rematchMenu.setNotice(notice.message)
				lobbyMenu.setVisible(false)
			end
		end)
	end

	-- Reproduce un lote ya vencido. Va aparte para que el bucle lo proteja entero: un fallo aquí no
	-- puede dejar al cliente sin partida.
	local function playBatch(due: any, now: number)
		StateStore.apply(queue.state, due)
		local events = due.events
		if events ~= nil and #events > 0 then
			hideMenus()
		end
		sceneRunning = true
		-- Un lote que llegó tarde acorta sus escenas: el cliente se pone al día en vez de repetir
		-- lo que el grupo ya vio.
		SceneDirector.play(scenes, due, EventQueue.behindSec(due, now))
		sceneRunning = false
		hud.setBanner("")
		-- La vista lleva ya el resultado: se enseña al terminar la escena, no antes.
		applyView(due.view)
		local view = StateStore.view(queue.state)
		syncTokens(view)
		followActive(view)
		if view ~= nil and view.phase ~= "GameOver" then
			hud.setDeadline(due.decisionDeadline)
		else
			hud.setDeadline(nil)
		end
	end

	-- Bucle del cliente: entrega los lotes cuando les toca, aplica su estado y reproduce sus escenas.
	task.spawn(function()
		while true do
			local now = Workspace:GetServerTimeNow()
			local due = EventQueue.nextDue(queue, now)
			if due ~= nil then
				local ok: boolean, err: any = (pcall :: any)(playBatch, due, now)
				if not ok then
					sceneRunning = false
					warn(`Cliente: falló el lote {due.seq}: {err}`)
				end
			else
				task.wait(TICK_SEC)
			end
		end
	end)

	-- El avatar local monta en su ficha en cuanto hay una, y vuelve a montar si reaparece.
	mountLocal = function()
		local token = myToken
		if token == nil then
			return
		end
		local character = player.Character or player.CharacterAdded:Wait()
		if character:WaitForChild("Humanoid", 10) == nil then
			return
		end
		if character:WaitForChild("HumanoidRootPart", 10) == nil then
			return
		end
		TokenRider.mount(player, token)
	end

	task.spawn(function()
		local deadline = os.clock() + REMOTE_WAIT_SEC
		while myToken == nil and os.clock() < deadline do
			local view = StateStore.view(queue.state)
			if view ~= nil then
				syncTokens(view)
			end
			task.wait(TICK_SEC)
		end
		mountLocal()
	end)

	-- Roblox crea un personaje nuevo al reaparecer: hay que volver a soldarlo a la ficha o el jugador
	-- se queda de pie en el punto de aparición, en primera persona y sin ficha.
	player.CharacterAdded:Connect(function()
		task.spawn(mountLocal)
	end)
end

task.spawn(boot)

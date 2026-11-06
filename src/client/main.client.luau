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

-- Color de cada asiento. Se rellena en `boot`, cuando ya se puede leer `config/Ui`.
local SEAT_COLORS: { Color3 } = {}

-- Tablero con el que se arranca antes de que llegue la primera vista. El tamaño real lo manda el
-- servidor en `view.sizeId` y la ciudad se reconstruye al recibirlo.
local START_SIZE: "S" | "M" | "L" = "S"
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

	for _, hex in require("../shared/config/Ui").seatColors do
		table.insert(SEAT_COLORS, Color3.fromHex(hex))
	end

	local CameraDirector = require("./camera/CameraDirector")
	local CameraRules = require("./camera/CameraRules")
	local ArtAssets = require("../shared/config/ArtAssets")
	local StreetDressing = require("./world/StreetDressing")
	local BuildingView = require("./world/BuildingView")
	local Look = require("./world/Look")
	local Ambience = require("./world/Ambience")
	local CityBuilder = require("./world/CityBuilder")
	local TokenRider = require("./world/TokenRider")
	local JailView = require("./world/JailView")
	local SquareView = require("./world/SquareView")
	local Tokens = require("../shared/config/Tokens")
	local Arrest = require("./scenes/Arrest")
	local WorldRules = require("./world/WorldRules")
	local EventQueue = require("./state/EventQueue")
	local StateStore = require("./state/StateStore")
	local ResyncGate = require("./state/ResyncGate")
	local ViewWire = require("./state/ViewWire")
	local SceneDirector = require("./scenes/SceneDirector")
	local Protocol = require("../shared/net/Protocol")
	local ActionMenu = require("./ui/ActionMenu")
	local Billboard = require("./ui/Billboard")
	local Hud = require("./ui/Hud")
	local LobbyMenu = require("./ui/LobbyMenu")
	local TokenMenu = require("./ui/TokenMenu")
	local MiniMap = require("./ui/MiniMap")
	local AudioDirector = require("./audio/AudioDirector")
	local GuidedMatch = require("./ui/GuidedMatch")
	local Overview = require("./ui/Overview")
	local ModelCity = require("./world/ModelCity")
	local PortalJump = require("./scenes/PortalJump")
	local PropertyManager = require("./ui/PropertyManager")
	local PactMenu = require("./ui/PactMenu")
	local RematchMenu = require("./ui/RematchMenu")
	local SettingsMenu = require("./ui/SettingsMenu")
	local TradeMenu = require("./ui/TradeMenu")
	local NoticeRules = require("./ui/NoticeRules")
	local ActionMenuRules = require("./ui/ActionMenuRules")
	local SocialRules = require("./ui/SocialRules")
	local ViewText = require("./ui/ViewText")
	local Strings = require("../shared/config/Strings")

	local playerGui = player:WaitForChild("PlayerGui")

	-- Los remotos se resuelven más abajo, pero los menús se crean antes: estas funciones se reasignan
	-- en cuanto los remotos existen y las clausuras ven el valor nuevo.
	local sendAction: (action: any) -> () = function() end
	local sendLobby: (request: any) -> () = function() end
	local chooseToken: (tokenId: string) -> () = function() end
	local tokenChoices: { [string]: string } = {}

	local hud = Hud.create(playerGui, function()
		return Workspace:GetServerTimeNow()
	end)
	local actionMenu = ActionMenu.create(playerGui)
	local miniMap = MiniMap.create(playerGui, seatColor)
	local overview = Overview.create(playerGui)
	local guided = GuidedMatch.create(playerGui)
	-- Ajustes: los volúmenes de los dos canales, que aplica el director de audio.
	local settings = SettingsMenu.create(playerGui)
	settings.setVolumes(AudioDirector.volumes())
	settings.onChanged(function(musicLevel: number, effectsLevel: number)
		AudioDirector.setVolumes(musicLevel, effectsLevel)
	end)
	hud.onSettings(function()
		settings.setOpen(not settings.isOpen())
	end)
	-- Gestionar propiedades (R-P53): la cámara enseña de cerca la propiedad elegida.
	local manager = PropertyManager.create(playerGui)
	-- Cartelera: la tirada del cartel cuando alguien cae en su casilla.
	local billboard = Billboard.create(playerGui)
	-- Sin partida todavía suena la música del lobby.
	AudioDirector.setMusicState("Lobby")
	-- Clic y roce de todos los botones, también de los menús que se crean más abajo.
	AudioDirector.bindUi(playerGui)
	local tradeMenu = TradeMenu.create(playerGui, function(action: any)
		sendAction(action)
	end)
	local pactMenu = PactMenu.create(playerGui, function(action: any)
		sendAction(action)
	end)
	local lobbyMenu = LobbyMenu.create(playerGui, function(request: any)
		sendLobby(request)
	end)
	local tokenMenu = TokenMenu.create(playerGui, function(tokenId: string)
		chooseToken(tokenId)
	end)
	local rematchMenu = RematchMenu.create(playerGui)

	local scenes = SceneDirector.new({
		wait = function(seconds: number)
			task.wait(seconds)
		end,
		show = function(text: string)
			hud.setBanner(Strings.eventTitle(text))
		end,
		-- El sonido de cada evento suena cuando empieza su escena, no todo el lote de golpe.
		onEvent = function(event: any)
			AudioDirector.playEvent(event)
		end,
		log = function(message: string)
			warn(message)
		end,
	})

	-- Nombre de cada asiento. Los `playerId` son el `userId` en texto: se resuelven aquí, que es el único
	-- sitio que conoce a los `Player`, y se guarda el último nombre conocido porque un bot puede ocupar
	-- el asiento de quien se fue.
	local names: ViewText.Names = {}
	local Ui = require("../shared/config/Ui")
	local Economy = require("../shared/config/Economy")

	local function lookupName(id: string): string?
		local userId = tonumber(id)
		local found = if userId ~= nil then Players:GetPlayerByUserId(userId) else nil
		return if found ~= nil then found.DisplayName else nil
	end

	local queue = EventQueue.new()

	-- Nombre y color de asiento de un jugador, para la tarjeta de una ficha que ya es suya.
	local function describeSeat(id: string): (string, Color3)
		local view = StateStore.view(queue.state)
		local index = 1
		if view ~= nil then
			for position, seated in view.players do
				if seated.id == id then
					index = position
				end
			end
		end
		local name = if view ~= nil then ViewText.playerName(view, names, id) else id
		return name, Color3.fromHex(Ui.seatColors[(index - 1) % #Ui.seatColors + 1])
	end
	local director = CameraDirector.new(player, START_SIZE)
	local tokens: { [string]: Model } = {}
	local myToken: Model? = nil
	local tokenRefreshPending = false
	-- Declarada aquí porque el reparto de fichas la necesita; se asigna más abajo.
	local mountLocal: () -> () = function() end
	local sceneRunning = false
	local riding = false
	-- Lote de solo obras e hipotecas con el gestor abierto: no cierra menús ni toma la cámara.
	local quietScene = false
	local MANAGE_EVENTS: { [string]: boolean } = {
		BuildingChanged = true,
		PropertyMortgaged = true,
		PropertyUnmortgaged = true,
	}
	-- Salto sin ruta pendiente de su escena (Portal): quién salta y adónde.
	local pendingJump: { playerId: string, to: any }? = nil
	local city: CityBuilder.CityHandles? = nil
	local size: string? = nil

	-- La escena de la detención aparta la ficha del detenido mientras dura. El color del asiento viste al
	-- relleno de un bot detenido.
	local arrest = Arrest.new({
		director = director,
		city = function()
			return city
		end,
		token = function(id: string): Model?
			return tokens[id]
		end,
		colorOf = function(id: string): Color3
			local view = StateStore.view(queue.state)
			local seat = if view ~= nil then WorldRules.seatOf(view.players, id) else nil
			return seatColor(seat or 1)
		end,
		log = function(message: string)
			warn(message)
		end,
	})

	-- La ciudad se construye con el tamaño que anuncia el servidor. Si la partida es de 5 a 8
	-- jugadores el tablero es de 48 o 56 casillas, y una ciudad de 40 no sirve: se tira la vieja y se
	-- levanta la nueva con sus fichas.
	local function ensureCity(sizeId: string)
		if size == sizeId and city ~= nil then
			return
		end
		-- Una ciudad nueva deja sin sitio a las patrullas y a las fichas: cualquier detención en curso acaba aquí.
		arrest.cancelAll()
		local previous = city
		city = nil
		tokens = {}
		myToken = nil
		ModelCity.destroy()
		director.setOverviewFocus(nil, nil)
		if previous ~= nil then
			previous.destroy()
		end
		local handles = CityBuilder.build(sizeId :: CityBuilder.SizeId, Workspace)
		city = handles
		size = sizeId
		BuildingView.bind(handles)
		StreetDressing.build(handles)
		JailView.build(handles)
		SquareView.build(handles)
		StreetDressing.startTraffic(handles)
		director.setSize(sizeId :: CityBuilder.SizeId)
	end

	local function tokenIdOf(id: string, seat: number): string
		return tokenChoices[id] or Tokens.forSeat(seat)
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
		local token =
			TokenRider.create(id, handles.sizeId, seatColor(seat), handles.tokens, tokenIdOf(id, seat))
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
			-- Un detenido se queda donde la escena lo deja hasta que acaba: no se le recoloca ni se le remonta.
			if arrest.holds(seated.id) then
				continue
			end
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
		end, function(ownerId: string): string
			return ViewText.playerName(view, names, ownerId)
		end)
	end

	-- El servidor cambió el reparto de fichas: se tira la que ya no toca y se vuelve a montar. La
	-- posición la repone `syncTokens` con la vista vigente; el avatar propio se vuelve a soldar.
	local function refreshTokens(view: any)
		if view == nil or view.players == nil then
			return
		end
		-- A mitad de escena la ficha que va por la calle no se toca: se guarda para el lote siguiente.
		if sceneRunning or riding then
			tokenRefreshPending = true
			return
		end
		local changed = false
		for seat, seated in view.players do
			local token: Model? = tokens[seated.id]
			if token ~= nil and token:GetAttribute("TokenId") ~= tokenIdOf(seated.id, seat) then
				token:Destroy()
				tokens[seated.id] = nil
				changed = true
			end
		end
		if changed then
			syncTokens(view)
			-- Un detenido no vuelve a montar hasta que acabe su escena.
			if not arrest.holds(playerId) then
				task.spawn(mountLocal)
			end
		end
	end

	-- Lo que las escenas pueden tocar. Al acabar cada lote el director pone el mundo como la vista, aunque
	-- una escena falle o se omita; `syncTokens` deja en paz al detenido hasta que acabe su escena.
	scenes.world = {
		reconcile = function(view: any)
			syncTokens(view)
		end,
	}
	scenes.camera = {
		follow = function(target: any)
			director.follow(target)
		end,
	}
	scenes.audio = {
		play = function(id: string)
			AudioDirector.play(id)
		end,
	}
	scenes.now = function()
		return Workspace:GetServerTimeNow()
	end

	-- El recorrido de una ficha es una escena: el grupo entero ve cómo se mueve. `ride` corre por su
	-- cuenta y devuelve lo que tardó, que el director descuenta del hueco de la escena.
	SceneDirector.register(scenes, "TokenMoved", {
		run = function(ctx, event)
			-- La partida ya echó a andar: la ficha queda como esté hasta la revancha.
			tokenMenu.setVisible(false)
			local id = event.playerId
			-- Si el detenido vuelve a moverse, su detención termina ya: su ficha no puede estar en dos sitios.
			if type(id) == "string" then
				arrest.cancelFor(id)
			end
			local path = event.path
			local token = if type(id) == "string" then tokens[id] else nil
			-- Un salto sin ruta se guarda: si lo sigue un PortalUsed, su escena lo enseña entero. Si no,
			-- la ficha se recoloca al acabar el lote, como antes.
			if type(path) == "table" and #path == 0 and type(id) == "string" then
				pendingJump = { playerId = id, to = event.to }
				ctx.spent(ctx.duration)
				return
			end
			if token == nil or type(path) ~= "table" or #path == 0 then
				ctx.wait(ctx.duration)
				return
			end
			-- La vista del lote ya lleva el resultado, así que se sabe a qué sitio de la casilla llega.
			local view = StateStore.view(queue.state)
			local arrival = if view ~= nil then WorldRules.tokenOffsets(view.players)[id] else nil
			-- Todo el grupo sigue a esa ficha de cerca mientras recorre la calle (R-P51). Si retrocede, la
			-- cámara se pone delante para ver la ficha y no la calle que deja.
			local backward = type(event.from) == "number" and CameraRules.isBackward(event.from, path)
			director.follow(token, backward)
			riding = true
			local used = TokenRider.ride(token, path, ctx.duration, arrival)
			riding = false
			ctx.spent(used)
		end,
	})

	-- Portal: la ficha se enciende, se disuelve, la cámara cruza la ciudad y reaparece en el otro Portal.
	SceneDirector.register(scenes, "PortalUsed", {
		run = function(ctx, event)
			ctx.show("PortalUsed")
			local jump = pendingJump
			pendingJump = nil
			local token = if jump ~= nil then tokens[jump.playerId] else nil
			if jump == nil or token == nil or jump.to ~= event.to then
				ctx.wait(ctx.duration)
				return
			end
			local id = jump.playerId
			local view = StateStore.view(queue.state)
			local arrival = if view ~= nil then WorldRules.tokenOffsets(view.players)[id] else nil
			local destination = if view ~= nil then ViewText.squareName(view, event.to) else ""
			riding = true
			local ok: boolean, err: any = (pcall :: any)(PortalJump.run, {
				token = token,
				playerId = id,
				placeAtDestination = function()
					TokenRider.place(token, event.to, arrival)
				end,
				follow = function(target: Model)
					director.follow(target)
				end,
				callout = Strings.get("portal.callout", { square = destination }),
				duration = ctx.duration,
				wait = ctx.wait,
			})
			riding = false
			if not ok then
				warn(`Cliente: la escena del Portal falló: {err}`)
			end
		end,
	})

	-- Cartelera: el motor tira el cartel y el cliente lo enseña. No hay decisión que esperar: el panel
	-- pasa por las cinco salidas y deja el resultado hasta que acaba la escena.
	SceneDirector.register(scenes, "BillboardResult", {
		run = function(ctx, event)
			ctx.show("")
			local view = StateStore.view(queue.state)
			local playerName = if view ~= nil then ViewText.playerName(view, nil, event.playerId) else nil
			billboard.play(event.result :: string, event.amount :: number, playerName, ctx.duration)
			ctx.wait(ctx.duration)
		end,
	})

	-- Duelo: hasta que llegue su escena final (plan 08, Tarea 5), la cámara pasa ya al perdedor, que es
	-- quien se mueve después; sin perdedor (empate o duelo anulado) se queda donde estaba.
	SceneDirector.register(scenes, "DuelResolved", {
		run = function(ctx, event)
			ctx.show("DuelResolved")
			local loser = if type(event.loserId) == "string" then tokens[event.loserId] else nil
			if loser ~= nil then
				director.follow(loser)
			end
			ctx.wait(ctx.duration)
		end,
	})

	-- Detención: el detenido se baja de su ficha, llegan dos patrullas y los policías lo meten en una. Dan la vuelta
	-- al mapa y entran en la cárcel; al acabar la escena reaparece la ficha y sigue la partida.
	SceneDirector.register(scenes, "PlayerArrested", arrest.scene)

	-- Compra y subasta ganada: el resultado se ve al instante (halo del dueño y dinero de la barra), sin
	-- esperar a que acabe el lote. La escena es corta: un tiempo muerto aquí se nota en cada turno.
	local function settleNow(ctx: SceneDirector.Context, title: string)
		ctx.show(title)
		ctx.world.reconcile(ctx.view)
		if ctx.view ~= nil then
			hud.setView(ctx.view, names)
		end
		ctx.wait(ctx.duration)
	end
	SceneDirector.register(scenes, "PropertyBought", {
		run = function(ctx)
			settleNow(ctx, "PropertyBought")
		end,
	})
	SceneDirector.register(scenes, "AuctionWon", {
		run = function(ctx)
			settleNow(ctx, "AuctionWon")
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
		return { riding = riding, sceneRunning = sceneRunning and not quietScene }
	end

	CameraDirector.start(director, context)

	-- La maqueta se abre y se cierra con el modo de cámara, no con el botón: si el jugador la pide justo
	-- cuando empieza una escena, la petición queda guardada y se abre al terminar. Una escena no se
	-- interrumpe nunca.
	Look.apply()
	Ambience.start()
	task.spawn(function()
		local art = ReplicatedStorage:WaitForChild(ArtAssets.FOLDER, REMOTE_WAIT_SEC)
		if art == nil then
			return
		end
		-- Mientras llegan las mallas, los solares que esperan su edificio real se cambian en cuanto están listos.
		while not art:GetAttribute(ArtAssets.READY_ATTRIBUTE) do
			BuildingView.refreshPending()
			task.wait(ArtAssets.REFRESH_SEC)
		end
		BuildingView.refreshArt()
		if city ~= nil then
			StreetDressing.build(city)
			-- El fondo de cada barrio también espera a sus mallas: se vuelve a colocar ahora.
			city.refreshBackdrops()
			JailView.build(city)
			SquareView.build(city)
			StreetDressing.startTraffic(city)
		end
		for _, token in tokens do
			TokenRider.dress(token)
		end
	end)

	local function toggleManager()
		if manager.isOpen() then
			manager.setOpen(false)
		elseif not manager.setOpen(true) then
			hud.setToast(Strings.get("manage.none"))
		end
	end
	hud.onManage(toggleManager)
	game:GetService("UserInputService").InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.G then
			toggleManager()
		end
	end)
	manager.onFocus(function(index: number?)
		local handles = city
		director.setManageFocus(if index ~= nil and handles ~= nil then handles.lotOf(index) else nil)
	end)
	manager.onAction(function(action: any)
		sendAction(action)
	end)

	local overviewWanted = false
	hud.onOverview(function()
		overviewWanted = not overviewWanted
		director.requestOverview(overviewWanted)
	end)
	task.spawn(function()
		while true do
			local open = overviewWanted and director.mode() == "Overview"
			overview.setOpen(open)
			-- La vista general es la ciudad real desde lo alto, con las etiquetas de dueño encima. La maqueta
			-- en miniatura ya no se enseña (decisión del responsable, 2026-11-05): se veía como una copia
			-- dentro de la ciudad. `ModelCity` sigue en el código por si se recupera.
			BuildingView.setTagsVisible(open)
			local handles = city
			if handles ~= nil then
				handles.setHotZoneOverview(open)
			end
			task.wait(0.1)
		end
	end)

	-- Arrastrar sobre la ciudad gira la vista general. Lo que cae sobre un botón no cuenta.
	local UserInputService = game:GetService("UserInputService")
	local dragging = false
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local kind = input.UserInputType
		if
			not processed and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch)
		then
			dragging = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if
			dragging
			and director.mode() == "Overview"
			and (kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch)
		then
			director.rotateOverview(input.Delta.X)
		end
	end)

	-- Atajos de teclado: T y P abren los menús sociales si el jugador puede usarlos ahora; Escape cierra lo
	-- que esté abierto. Una caja de texto con foco se queda con sus teclas.
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or UserInputService:GetFocusedTextBox() ~= nil then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.K then
			settings.setOpen(not settings.isOpen())
		elseif key == Enum.KeyCode.Escape then
			tradeMenu.setOpen(false)
			pactMenu.setOpen(false)
			settings.setOpen(false)
			if overviewWanted then
				overviewWanted = false
				director.requestOverview(false)
			end
		elseif key == Enum.KeyCode.T or key == Enum.KeyCode.P then
			local view = StateStore.view(queue.state)
			if sceneRunning or view == nil or not SocialRules.available(view) then
				return
			end
			if key == Enum.KeyCode.T then
				tradeMenu.setOpen(true)
			else
				pactMenu.setOpen(true)
			end
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
	local reclaimRemote = remotes:WaitForChild(Protocol.REMOTES.Reclaim, REMOTE_WAIT_SEC)
	local eventBatch = remotes:WaitForChild(Protocol.REMOTES.Batch, REMOTE_WAIT_SEC) :: RemoteEvent
	local resync = remotes:WaitForChild(Protocol.REMOTES.Resync, REMOTE_WAIT_SEC) :: RemoteEvent
	local tokenRequest = remotes:WaitForChild(Protocol.REMOTES.TokenChoice, REMOTE_WAIT_SEC)
	local tokenAssigned = remotes:WaitForChild(Protocol.REMOTES.TokenAssigned, REMOTE_WAIT_SEC)

	if actionRemote and actionRemote:IsA("RemoteEvent") then
		local actionEvent = actionRemote :: RemoteEvent
		sendAction = function(action: any)
			actionEvent:FireServer(action)
		end
	else
		warn("Cliente: falta el remoto de acciones; los menús no podrán jugar")
	end

	if tokenRequest and tokenRequest:IsA("RemoteEvent") then
		local requestEvent = tokenRequest :: RemoteEvent
		chooseToken = function(tokenId: string)
			requestEvent:FireServer(tokenId)
		end
	else
		warn("Cliente: falta el remoto de elección de ficha; se queda el reparto por asiento")
	end

	if tokenAssigned and tokenAssigned:IsA("RemoteEvent") then
		(tokenAssigned :: RemoteEvent).OnClientEvent:Connect(function(assignments: any, message: any)
			if type(assignments) ~= "table" then
				return
			end
			local clean: { [string]: string } = {}
			for id, tokenId in assignments do
				if type(id) == "string" and type(tokenId) == "string" then
					clean[id] = tokenId
				end
			end
			tokenChoices = clean
			tokenMenu.setAssignments(tokenChoices, playerId, describeSeat)
			if type(message) == "string" and message ~= "" then
				tokenMenu.setNotice(message)
			end
			local view = StateStore.view(queue.state)
			if view ~= nil then
				refreshTokens(view)
			end
		end)
	end

	-- Pide el reparto actual después de conectar el aviso: si se pidiera antes, la respuesta podría
	-- llegar cuando nadie escucha.
	if tokenRequest and tokenRequest:IsA("RemoteEvent") then
		(tokenRequest :: RemoteEvent):FireServer(nil)
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
	-- Jugar una carta desde la mano: el botón de confirmar dentro de su vista grande ya es la confirmación.
	hud.onPlayCard(function(action: any)
		sendAction(action)
	end)
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

	-- Retomar el asiento cuando lo juega un bot: el servidor sabe quién pide y decide si vale.
	hud.onReclaim(function()
		if reclaimRemote ~= nil and reclaimRemote:IsA("RemoteEvent") then
			(reclaimRemote :: RemoteEvent):FireServer()
		end
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
		ViewText.rememberNames(names, view, lookupName)
		local steps: { [string]: () -> () } = {
			Hud = function()
				hud.setView(view, names)
			end,
			LobbyMenu = function()
				lobbyMenu.setVisible(false)
			end,
			ActionMenu = function()
				-- Con un bot al mando del asiento propio, el panel se aparta: el botón amarillo es Retomar.
				for _, seated in view.players do
					if seated.id == view.playerId and seated.isBot == true then
						actionMenu.setLegal({}, nil)
						hud.setPlayable({})
						return
					end
				end
				-- Las cartas se juegan desde la mano; el panel de la derecha no las repite.
				local afterManage, byIndex = ActionMenuRules.splitManageActions(view.legalActions or {})
				manager.setData(view, byIndex)
				local rest, byCard = ActionMenuRules.splitHandActions(afterManage)
				local playable: { [string]: { { action: any, label: string, target: string?, tint: string? } } } =
					{}
				for cardId, actions in byCard do
					local options = {}
					for _, action in actions do
						local target, tint = ViewText.cardTarget(view, names, action)
						table.insert(options, {
							action = action,
							label = ViewText.actionLabel(view, names, action),
							target = target,
							tint = tint,
						})
					end
					playable[cardId] = options
				end
				hud.setPlayable(playable)
				-- Tratos y Pactos no son acciones del motor: se añaden según la vista (con el número de
				-- ofertas por responder) y desaparecen al acabar la partida.
				actionMenu.setLegal(rest, SocialRules.buttonsFor(view), { view = view, names = names })
			end,
			HotZone = function()
				local handles = city
				if handles ~= nil then
					handles.setHotZone(view.hotZoneId)
				end
				BuildingView.setHotZone(view.hotZoneId)
			end,
			Overview = function()
				overview.setView(view, names)
			end,
			-- La música sale de la vista, así que también acierta al entrar a media partida o al resincronizar.
			Music = function()
				local finalFrom = if type(view.maxRounds) == "number"
					then view.maxRounds - Economy.finalRoundsCount + 1
					else math.huge
				if view.phase == "GameOver" then
					AudioDirector.setMusicState("Podium")
				elseif view.round >= finalFrom then
					AudioDirector.setMusicState("FinalRounds")
				else
					AudioDirector.setMusicState("Normal")
				end
			end,
			MiniMap = function()
				miniMap.setView(view, names)
			end,
			TradeMenu = function()
				tradeMenu.setView(view, names)
			end,
			PactMenu = function()
				pactMenu.setView(view, names)
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

	-- Durante una escena no se decide nada (R-P39): el servidor descartaría el clic. Los menús vuelven
	-- con la vista del lote, al terminar la escena.
	local function hideMenus()
		actionMenu.setLegal({}, nil)
		hud.setPlayable({})
		hud.setDeadline(nil)
		-- Ninguna hoja tapa una escena: tratos, pactos y la vista general se cierran al empezar.
		tradeMenu.setOpen(false)
		pactMenu.setOpen(false)
		manager.setOpen(false)
		if overviewWanted then
			overviewWanted = false
			director.requestOverview(false)
		end
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
			arrest.cancelAll()
			EventQueue.resync(queue, batch.view, 0)
			rematchMenu.setResult(nil)
			SceneDirector.reset(scenes)
			syncTokens(batch.view)
			applyView(batch.view)
			local firstDecision = batch.view.legalActions ~= nil and #batch.view.legalActions > 0
			guided.observe({}, if firstDecision then batch.view.phase else nil)
			followActive(batch.view)
			hud.setDeadline(batch.decisionDeadline)
			-- La partida acaba de empezar: cada jugador elige su ficha. Se cierra al primer movimiento.
			if batch.view.phase ~= "GameOver" then
				tokenMenu.setVisible(true)
			end
			task.spawn(mountLocal)
			return
		end
		if EventQueue.push(queue, batch) == "Gap" then
			resync:FireServer()
		end
	end)

	-- Pone la interfaz, las fichas y la cámara al día con la vista de un resync.
	local function applyResync(batch: any)
		-- Una vista nueva manda sobre las escenas en curso: las detenciones acaban y las fichas vuelven.
		arrest.cancelAll()
		syncTokens(batch.view)
		applyView(batch.view)
		followActive(batch.view)
		hud.setDeadline(batch.decisionDeadline)
	end

	-- Respuesta de resync que llegó mientras corría una escena. Los menús no vuelven a aparecer a mitad
	-- de una escena (R-P39): el estado se pone al día en la cola, pero la interfaz espera a que acabe.
	local resyncGate = ResyncGate.new()

	-- Respuesta a una petición de resincronización: vista completa y salto de `seq`. La interfaz se
	-- actualiza aquí también, que es justo el camino del cliente que se quedó atrás.
	resync.OnClientEvent:Connect(function(batch: any)
		if type(batch) ~= "table" or type(batch.seq) ~= "number" then
			return
		end
		ViewWire.normalize(batch.view)
		EventQueue.resync(queue, batch.view, batch.seq)
		if resyncGate.offer(batch, sceneRunning) == "Apply" then
			applyResync(batch)
		end
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
			-- R-P48: se enruta por `kind`. El rechazo de una acción es un aviso breve de la barra; los
			-- avisos de revancha y de lobby siguen yendo al panel de revancha.
			local route = NoticeRules.route(notice)
			if route == "Toast" then
				hud.setToast(notice.message)
				AudioDirector.play("ui.deny")
			elseif route == "Panel" then
				-- Antes de que haya partida, el aviso es del lobby y se queda en su tablón.
				if lobbyMenu.isVisible() and StateStore.view(queue.state) == nil then
					lobbyMenu.setNotice(notice.message, notice.kind)
				else
					rematchMenu.setNotice(notice.message)
					lobbyMenu.setVisible(false)
				end
			end
		end)
	end

	-- Reproduce un lote ya vencido. Va aparte para que el bucle lo proteja entero: un fallo aquí no
	-- puede dejar al cliente sin partida.
	local function playBatch(due: any, now: number)
		StateStore.apply(queue.state, due)
		local events = due.events
		-- Con «Propiedades» abierto, un lote que solo trae obras e hipotecas no cierra el gestor ni mueve la
		-- cámara: el jugador sigue gestionando de corrido y los demás ven el mismo primer plano.
		local manageOnly = manager.isOpen() and events ~= nil and #events > 0
		for _, event in events or {} do
			if not MANAGE_EVENTS[event.type] then
				manageOnly = false
			end
		end
		quietScene = manageOnly
		local hasScene = events ~= nil and #events > 0 and not manageOnly
		if hasScene then
			hideMenus()
			hud.setSceneMode(true)
			guided.setSceneMode(true)
		end
		sceneRunning = true
		-- Un lote que llegó tarde acorta sus escenas: el cliente se pone al día en vez de repetir
		-- lo que el grupo ya vio.
		-- La interfaz acusa cada evento con su sonido y la música sigue el momento de la partida.
		for _, event in events or {} do
			if event.type == "FinalRoundsStarted" then
				AudioDirector.setMusicState("FinalRounds")
			elseif event.type == "GameEnded" then
				AudioDirector.setMusicState("Podium")
			end
		end
		SceneDirector.play(scenes, due, EventQueue.behindSec(due, now))
		sceneRunning = false
		quietScene = false
		riding = false
		-- Una elección que llegó a mitad de escena se aplica ahora, con las fichas ya paradas.
		if tokenRefreshPending then
			tokenRefreshPending = false
			local pendingView = StateStore.view(queue.state)
			if pendingView ~= nil then
				refreshTokens(pendingView)
			end
		end
		hud.setBanner("")
		if hasScene then
			hud.setSceneMode(false)
			guided.setSceneMode(false)
		end
		-- La vista lleva ya el resultado: se enseña al terminar la escena, no antes.
		applyView(due.view)
		-- Primera partida guiada: lo que acaba de pasar y la decisión que le llega al jugador, si le toca.
		local decided = due.view ~= nil and due.view.legalActions ~= nil and #due.view.legalActions > 0
		guided.observe(events or {}, if decided then due.view.phase else nil)
		-- El final de la partida trae el podio y los premios (R-P45): se enseñan en el panel de revancha.
		for _, event in events or {} do
			if event.type == "GameEnded" then
				arrest.cancelAll()
				rematchMenu.setResult(ViewText.podium(event, due.view, names))
				-- Celebración: cada ficha que se ve da un salto al acabar la partida.
				for _, token in tokens do
					if not TokenRider.isHidden(token) then
						TokenRider.celebrate(token, 2)
					end
				end
			end
		end
		-- El director ya concilió con la vista del lote; esto cubre el lote sin vista y lo que cambió
		-- después, como el detenido que se libera al acabar la partida. Si no hay nada nuevo, no mueve nada.
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
					riding = false
					warn(`Cliente: falló el lote {due.seq}: {err}`)
				end
				-- Un resync que llegó durante la escena manda sobre la vista de ese lote: es más reciente.
				local late = resyncGate.take()
				if late ~= nil then
					local applied: boolean, lateErr: any = (pcall :: any)(applyResync, late)
					if not applied then
						warn(`Cliente: falló el resync aplazado: {lateErr}`)
					end
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

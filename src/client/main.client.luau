--!strict
-- Único punto de cableado del cliente. Monta la ciudad, la ficha del jugador local y la cámara, y
-- deja el resto de módulos colgando de aquí: ningún otro archivo del cliente crea instancias por su
-- cuenta. Es `LocalScript` porque todo lo que hace es vista.
--
-- Arranca en un `task.spawn` a propósito: un `LocalScript` empieza a correr en cuanto se copia a
-- `PlayerScripts`, antes de que estén todos sus hermanos, y `shared` es hermano suyo (R-P17). Los
-- `require` van dentro de `boot`, después de esperar esa carpeta, o la primera partida de cada
-- servidor se quedaría sin interfaz.
local Players = game:GetService("Players")
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

-- Mientras no llegue la vista del servidor, arranca en el tablero pequeño: el tamaño real viaja en el
-- primer lote (`view.sizeId`) y se aplica al recibirlo.
local DEFAULT_SIZE: "S" | "M" | "L" = "S"
local SHARED_WAIT_SEC = 10

local player = Players.LocalPlayer
local playerScripts = script.Parent.Parent

local function seatColor(index: number): Color3
	return SEAT_COLORS[(index - 1) % #SEAT_COLORS + 1]
end

local function seatIndex(): number
	local position = 1
	for index, other in Players:GetPlayers() do
		if other == player then
			position = index
			break
		end
	end
	return position
end

local function boot()
	-- R-P17: `shared` se monta junto al código del cliente para que la misma cadena relativa resuelva
	-- en el disco, en Lune y en el DataModel. Hay que esperarla antes de pedir nada.
	playerScripts:WaitForChild("shared", SHARED_WAIT_SEC)

	local CameraDirector = require("./camera/CameraDirector")
	local CityBuilder = require("./world/CityBuilder")
	local TokenRider = require("./world/TokenRider")

	local city = CityBuilder.build(DEFAULT_SIZE, Workspace)
	local token = TokenRider.create(player, DEFAULT_SIZE, seatColor(seatIndex()), city.tokens)
	TokenRider.place(token, 1)

	local director = CameraDirector.new(player, DEFAULT_SIZE)
	director.follow(token)

	local function mountWhenReady()
		local character = player.Character or player.CharacterAdded:Wait()
		if character:WaitForChild("Humanoid", 10) == nil then
			return
		end
		if character:WaitForChild("HumanoidRootPart", 10) == nil then
			return
		end
		TokenRider.mount(player, token)
	end

	task.spawn(mountWhenReady)
	player.CharacterAdded:Connect(function()
		task.spawn(mountWhenReady)
	end)

	-- Contexto de cámara. La vista general y las escenas llegarán a `overviewRequested` y
	-- `sceneRunning` desde la interfaz y el director de escenas; por ahora el jugador local manda en
	-- su propio turno, que es lo que se comprueba en esta tarea.
	CameraDirector.start(director, function()
		return { isActive = true, sceneRunning = false }
	end)
end

task.spawn(boot)

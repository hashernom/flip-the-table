--!strict
-- Puerta de entrada de las acciones que envía el cliente. No confía en ningún id del paquete:
-- usa el Player que entrega el RemoteEvent, descarta lo que no pase Protocol.validate y limita la
-- frecuencia por jugador. El resto de la seguridad vive en el motor (Engine.apply).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Protocol = require("../../shared/net/Protocol")
local Types = require("../../shared/rules/Types")

type Action = Types.Action
type OnAction = (player: Player, action: Action) -> ()

local RemoteGateway = {}

-- Los tres RemoteEvent viven en ReplicatedStorage/FlipTheTableRemotes. El gateway los crea si no
-- existen; el cliente del plan 05 los busca en esa misma carpeta y solo escucha Batch y Resync.
local FOLDER_NAME = "FlipTheTableRemotes"

local function remotesFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		if existing:IsA("Folder") then
			return existing :: Folder
		end
		error(`RemoteGateway: {FOLDER_NAME} existe en ReplicatedStorage y no es una carpeta`, 2)
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

local function remoteFor(name: string): RemoteEvent
	local parent = remotesFolder()
	local existing = parent:FindFirstChild(name)
	if existing then
		if existing:IsA("RemoteEvent") then
			return existing :: RemoteEvent
		end
		error(`RemoteGateway: {FOLDER_NAME}.{name} existe y no es un RemoteEvent`, 2)
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

-- Reloj del servidor para el limitador: no depende del reloj del cliente ni del de la máquina
-- donde corre Studio. El protocolo recibe el instante por parámetro para seguir siendo puro.
local function now(): number
	return Workspace:GetServerTimeNow()
end

-- RemoteEvent del protocolo, creándolo si hace falta. Es la puerta que usan RemoteGateway.start
-- (Action) y MatchService (Batch y Resync) para que el nombre viva solo en Protocol.REMOTES.
function RemoteGateway.remote(name: string): RemoteEvent
	return remoteFor(name)
end

function RemoteGateway.start(onAction: OnAction)
	local limiter = Protocol.newLimiter()
	local actionRemote = remoteFor(Protocol.REMOTES.Action)
	-- Batch lo escribe el servidor y Resync lo conectará el servicio de partida (Tarea 3); aquí
	-- solo se crean para que el cliente los encuentre desde el primer arranque.
	remoteFor(Protocol.REMOTES.Batch)
	remoteFor(Protocol.REMOTES.Resync)

	actionRemote.OnServerEvent:Connect(function(player: Player, packet: any)
		-- El limitador va antes de validar: así un cliente que inunda con paquetes malformados
		-- tampoco puede hacernos recorrer tablas enormes. Es por jugador, no por conexión.
		-- R-P9: la identidad sale del Player del remoto, nunca de un id del paquete, y el motor
		-- usa el userId en texto.
		if not limiter.allow(tostring(player.UserId), now()) then
			return
		end
		-- pcall por si un paquete raro hiciera fallar la validación: nunca debe salir un error del
		-- manejador. Lo que no valide se descarta en silencio, como pide el contrato del plan.
		local ok: boolean, accepted: any = pcall(function(): boolean
			return (Protocol.validate(packet))
		end)
		if not ok or accepted ~= true then
			return
		end
		local called: boolean, err: any = pcall(onAction, player, packet)
		if not called then
			warn(`RemoteGateway: onAction falló para {player.UserId}: {err}`)
		end
	end)
end

return RemoteGateway

--!strict
-- Puerta de entrada de las acciones que envía el cliente. No confía en ningún id del paquete:
-- usa el Player que entrega el RemoteEvent, descarta lo que no pase Protocol.validate y limita la
-- frecuencia por jugador. El resto de la seguridad vive en el motor (Engine.apply).
local Workspace = game:GetService("Workspace")

local Protocol = require("../../shared/net/Protocol")
local Remotes = require("../Remotes")
local Types = require("../../shared/rules/Types")

type Action = Types.Action
type OnAction = (player: Player, action: Action) -> ()

local RemoteGateway = {}

-- Reloj del servidor para el limitador: no depende del reloj del cliente ni del de la máquina
-- donde corre Studio. El protocolo recibe el instante por parámetro para seguir siendo puro.
local function now(): number
	return Workspace:GetServerTimeNow()
end

-- RemoteEvent del protocolo, creándolo si hace falta. Es la puerta que usan RemoteGateway.start
-- (Action) y MatchService (Batch y Resync) para que el nombre viva solo en Protocol.REMOTES.
function RemoteGateway.remote(name: string): RemoteEvent
	return Remotes.remote(name)
end

function RemoteGateway.start(onAction: OnAction)
	local limiter = Protocol.newLimiter()
	local actionRemote = Remotes.remote(Protocol.REMOTES.Action)
	-- Batch lo escribe el servidor y Resync lo conectará el servicio de partida; aquí solo se
	-- crean para que el cliente los encuentre desde el primer arranque.
	Remotes.remote(Protocol.REMOTES.Batch)
	Remotes.remote(Protocol.REMOTES.Resync)

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

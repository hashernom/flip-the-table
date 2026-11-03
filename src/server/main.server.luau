--!strict
-- Único punto de cableado del servidor: conecta la puerta de acciones con el servicio de partida
-- y arranca la presencia. Es un Script y no un ModuleScript porque debe ejecutarse una sola vez al
-- arrancar el servidor; un ModuleScript solo correría cuando alguien lo requiriera, y aquí no hay
-- nadie que lo haga.
local MatchService = require("./match/MatchService")
local PresenceService = require("./match/PresenceService")
local RemoteGateway = require("./match/RemoteGateway")

-- La pasarela valida, limita y filtra; el servicio aplica la acción al motor. Se conecta una sola
-- vez por servidor: la revancha reutiliza esta conexión y solo cambia la partida vigente.
RemoteGateway.start(function(player, action)
	MatchService.submit(player, action)
end)

-- La presencia registra PlayerAdded/PlayerRemoving y se engancha al arranque de cada partida;
-- aquí no se crea ninguna, eso es del lobby (Tarea 5). Sin esta llamada, quien se va no deja un
-- bot y quien vuelve no recupera su asiento.
PresenceService.start()

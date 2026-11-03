--!strict
-- Único punto de cableado del servidor: conecta la puerta de acciones con el servicio de partida.
-- Es un Script y no un ModuleScript porque debe ejecutarse una sola vez al arrancar el servidor;
-- un ModuleScript solo correría cuando alguien lo requiriera, y aquí no hay nadie que lo haga.
local RemoteGateway = require("./match/RemoteGateway")
local MatchService = require("./match/MatchService")

-- La pasarela valida, limita y filtra; el servicio aplica la acción al motor. Se conecta una sola
-- vez por servidor: la revancha reutiliza esta conexión y solo cambia la partida vigente.
RemoteGateway.start(function(player, action)
	MatchService.submit(player, action)
end)

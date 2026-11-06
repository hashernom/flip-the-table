--!strict
-- Identificadores de los dos lugares de Roblox. 0 = todavía sin publicar; lo rellena el
-- responsable al publicar (R-P31). Nunca se inventan números.
--
-- `unpublished` es el centinela que comparan PartyService y PublicQueue: con 0 no se intenta
-- teletransportar y se contesta con un mensaje claro, porque el lugar destino todavía no existe.
-- Task 6 reutiliza `lobbyId` para el camino de vuelta de quien no juega la revancha.
return {
	unpublished = 0,
	lobbyId = 94932221063421,
	matchId = 133924106108598,
}

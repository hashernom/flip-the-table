--!strict
-- Valores ajustables del lobby: códigos de party, teletransporte y cola pública. Ningún número de
-- estas reglas vive en la lógica (contracts.md, «Números ajustables»).
return {
	-- Longitud del código de party. El alfabeto (sin 0, O, 1 ni I) es parte del contrato y vive en
	-- PartyCode; aquí solo se ajusta cuántos caracteres tiene.
	codeLength = 6,
	-- Intentos de generar un código libre antes de rendirse. Con 32^6 combinaciones, un choque es
	-- improbable, pero el bucle no puede ser infinito.
	codeAttempts = 8,
	-- Jugadores que caben en una partida, privada o pública. Coinciden con el motor
	-- (Boards.forPlayerCount admite de 2 a 8).
	minPlayers = 2,
	maxPlayers = 8,
	-- Vida de un código de party desde que se crea, en segundos. Pasado ese tiempo el código
	-- caduca: no es una sala permanente. Al teletransportar el grupo se borra antes.
	partyLifetimeSec = 300,
	-- Intentos de reservar y teletransportar al grupo, y espera entre intentos en segundos.
	teleportAttempts = 3,
	teleportRetrySec = 1,
	-- Caducidad de los datos de party en MemoryStore, en segundos. Algo mayor que la vida del
	-- código para que una fiesta caducada se reconozca como caducada y no como inexistente.
	storeExpirationSec = 900,
	-- Cola pública: empieza en cuanto hay queueStartAt jugadores y, como muy tarde, a los
	-- queueWaitSec segundos con los que haya (mínimo minPlayers).
	queueStartAt = 4,
	queueWaitSec = 60,
	-- Cada cuánto revisa la cola si ya toca empezar, en segundos.
	queueTickSec = 1,
}

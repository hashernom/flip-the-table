--!strict
-- Reglas puras de la revancha: con los votos de quienes siguen sentados, deciden si se puede
-- empezar otra partida y quién la juega. No usan game, ni task, ni ningún reloj: el servicio de
-- revancha es quien abre la ventana de Scenes.rematchSec y le pasa los votos y los presentes
-- (contracts.md, «Revancha»). Los votos son por userId numérico; ningún PlayerId de texto entra
-- aquí (contracts.md, «Identidad»).
local Lobby = require("../../shared/config/Lobby")

export type Decision = "Start" | "Wait" | "NotEnough"

local RematchRules = {}

-- Presentes únicos y en el orden recibido. Una lista con un id repetido no puede contar como dos
-- votos: `present` describe asientos, no papeletas.
local function uniquePresent(present: { number }): { number }
	local seen: { [number]: boolean } = {}
	local unique: { number } = {}
	for _, userId in present do
		if not seen[userId] then
			seen[userId] = true
			table.insert(unique, userId)
		end
	end
	return unique
end

-- userIds de los presentes que aceptaron, en el orden de `present`. Un voto de quien no está
-- presente se ignora: no cuenta para empezar ni aparece aquí, aunque siga en la tabla de votos.
function RematchRules.accepted(votes: { [number]: boolean }, present: { number }): { number }
	local accepters: { number } = {}
	for _, userId in uniquePresent(present) do
		if votes[userId] == true then
			table.insert(accepters, userId)
		end
	end
	return accepters
end

-- Qué toca hacer: "Start" si todos los presentes han votado y hay al menos Lobby.minPlayers
-- aceptaciones; "NotEnough" si todos han votado y no llega el mínimo; "Wait" mientras falte alguien
-- por votar. El paso del tiempo no está aquí: a los Scenes.rematchSec el servicio cierra la espera
-- con quien haya aceptado.
function RematchRules.resolve(votes: { [number]: boolean }, present: { number }): Decision
	local acceptedCount = 0
	local pending = false
	for _, userId in uniquePresent(present) do
		local vote = votes[userId]
		if vote == nil then
			pending = true
		elseif vote == true then
			acceptedCount += 1
		end
	end
	if pending then
		return "Wait"
	end
	if acceptedCount >= Lobby.minPlayers then
		return "Start"
	end
	return "NotEnough"
end

return RematchRules

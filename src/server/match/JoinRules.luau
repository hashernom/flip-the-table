--!strict
-- Regla pura del arranque en el lugar de partida: esperar, empezar o cancelar. El grupo que viene del
-- lobby anuncia su tamaño y se le espera hasta Scenes.joinTimeoutSec; sin datos de entrada (probar en
-- Studio) se da la espera corta desde que hay jugadores suficientes.
local Lobby = require("../../shared/config/Lobby")
local Scenes = require("../../shared/config/Scenes")

export type Decision = "Wait" | "Start" | "Abort"

export type Situation = {
	present: number,
	-- Tamaño que anunció el lobby, o nil sin datos de entrada.
	expected: number?,
	-- Segundos desde que llegó el primer jugador.
	sinceFirst: number,
	-- Segundos desde que hay jugadores suficientes, o nil si aún no los hay.
	sinceMinimum: number?,
}

local JoinRules = {}

function JoinRules.decide(situation: Situation): Decision
	local enough = situation.present >= Lobby.minPlayers
	local expected = situation.expected
	if expected == nil then
		local since = situation.sinceMinimum
		return if enough and since ~= nil and since >= Scenes.joinSec then "Start" else "Wait"
	end
	if enough and situation.present >= expected then
		return "Start"
	end
	if situation.sinceFirst < Scenes.joinTimeoutSec then
		return "Wait"
	end
	return if enough then "Start" else "Abort"
end

return JoinRules

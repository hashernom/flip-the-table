--!strict
-- Movimiento de las fichas: curvas puras, sin Roblox, de cuánto giran las ruedas y cuánto se eleva el
-- vehículo. `TokenRider` las aplica; los valores están en `Tokens.motion`.
local Tokens = require("../../shared/config/Tokens")

local TAU = 2 * math.pi
-- Base del reparto de fases: separa bien ids parecidos.
local PHASE_HASH = 31
local PHASE_STEPS = 1000

local TokenMotion = {}

-- Ángulo de una rueda de ese radio que ha rodado `distance` studs, sin deslizar.
function TokenMotion.wheelAngle(distance: number, radius: number): number
	if radius <= 0 then
		return 0
	end
	return distance / radius
end

-- Fase de reposo de una ficha, estable por id: ocho fichas juntas no respiran a la vez.
function TokenMotion.phaseOf(id: string): number
	local hash = 0
	for index = 1, #id do
		hash = (hash * PHASE_HASH + string.byte(id, index)) % PHASE_STEPS
	end
	return hash / PHASE_STEPS * TAU
end

-- Elevación en reposo, en el instante `seconds`.
function TokenMotion.idleLift(seconds: number, phase: number): number
	local motion = Tokens.motion
	return motion.idleAmplitude * math.sin(seconds / motion.idlePeriodSec * TAU + phase)
end

-- Elevación en marcha tras recorrer `distance`: siempre hacia arriba, nunca se hunde en el asfalto.
function TokenMotion.rideLift(distance: number): number
	local motion = Tokens.motion
	return motion.rideBounce * math.abs(math.sin(distance / motion.rideBounceStuds * math.pi))
end

-- Celebración con `progress` de 0 a 1: elevación y giro. Empieza y acaba en el sitio y orientación
-- originales; fuera de ese rango no mueve nada.
function TokenMotion.celebrate(progress: number): (number, number)
	local motion = Tokens.motion
	if progress < 0 or progress > 1 then
		return 0, 0
	end
	local lift = motion.celebrateHeight * math.sin(progress * math.pi)
	return lift, progress * motion.celebrateSpins * TAU
end

return TokenMotion

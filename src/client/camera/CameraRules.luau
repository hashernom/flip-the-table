--!strict
-- Reglas de cámara. Son puras: deciden qué plano toca y dónde va la cámara, sin tocar la cámara, el
-- avatar ni `RunService`. `CameraDirector` las aplica y `TokenRider` las obedece.
--
-- Todo el grupo ve el mismo plano, como en un juego de tablero compartido (R-P51), con una prioridad
-- estricta: una escena manda sobre todo lo demás, y el recorrido de una ficha es una escena con su propio
-- plano cerrado. Después va la vista general, que cada jugador pide con un botón, y si no, el plano del
-- turno, que sigue a la ficha activa.
local CameraShots = require("../../shared/config/CameraShots")
local CityLayout = require("../../shared/config/CityLayout")
local Scenes = require("../../shared/config/Scenes")

export type Mode = "Turn" | "Ride" | "Scene" | "Overview"
export type Context = {
	riding: boolean?,
	sceneRunning: boolean?,
	overviewRequested: boolean?,
}

-- Recorrido más corto que se acepta: por debajo, la ficha parece teletransportarse.
local MIN_RIDE_SEC = 0.4

-- Parte de la altura del avatar que queda por encima del asiento al montarlo en la ficha.
local EYE_HEIGHT_RATIO = 0.85
local MIN_SEAT_OFFSET = 1

local CameraRules = {}

CameraRules.MIN_RIDE_SEC = MIN_RIDE_SEC
CameraRules.EYE_HEIGHT_RATIO = EYE_HEIGHT_RATIO
CameraRules.MIN_SEAT_OFFSET = MIN_SEAT_OFFSET

-- Plano que toca. Un contexto incompleto cuenta como «nada en marcha»: es lo que ocurre antes de que
-- llegue el primer lote, y la cámara nunca debe quedarse en blanco.
function CameraRules.modeFor(ctx: Context): Mode
	if ctx.sceneRunning == true then
		return if ctx.riding == true then "Ride" else "Scene"
	end
	if ctx.overviewRequested == true then
		return "Overview"
	end
	return "Turn"
end

-- Dónde va la cámara y a qué mira, para una ficha en `position` que avanza según `facing`. La ruta gira
-- siempre a la derecha, así que el interior del anillo queda a la derecha de la marcha.
function CameraRules.pose(
	shot: CameraShots.Shot,
	position: CityLayout.Vector3Like,
	facing: number
): (CityLayout.Vector3Like, CityLayout.Vector3Like)
	local forwardX, forwardZ = math.sin(facing), math.cos(facing)
	local rightX, rightZ = -forwardZ, forwardX
	local eye = {
		x = position.x - forwardX * shot.back + rightX * shot.inward,
		y = position.y + shot.up,
		z = position.z - forwardZ * shot.back + rightZ * shot.inward,
	}
	local focus = {
		x = position.x + forwardX * shot.ahead,
		y = position.y + shot.focusUp,
		z = position.z + forwardZ * shot.ahead,
	}
	return eye, focus
end

-- Duración de un recorrido, acotada por el tope de `Scenes`. Sea cual sea la distancia, la ficha
-- nunca tarda más: el turno se mide en segundos, no en studs.
function CameraRules.rideSeconds(requested: number): number
	if requested ~= requested then
		return MIN_RIDE_SEC
	end
	return math.clamp(requested, MIN_RIDE_SEC, Scenes.maxRideSec)
end

-- Separación entre el asiento de la ficha y el avatar montado, según su altura. Con alturas absurdas
-- (un modelo roto) se queda en el mínimo, que sigue estando por encima de la ficha.
function CameraRules.seatOffset(avatarHeight: number): number
	if avatarHeight ~= avatarHeight or avatarHeight < 0 then
		return MIN_SEAT_OFFSET
	end
	return math.max(MIN_SEAT_OFFSET, avatarHeight * EYE_HEIGHT_RATIO)
end

return CameraRules

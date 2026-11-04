--!strict
-- Reglas de cámara. Son puras: deciden qué modo toca y cuánto dura un recorrido, sin tocar la
-- cámara, el avatar ni `RunService`. `CameraDirector` las aplica y `TokenRider` las obedece.
--
-- El modo sigue la tabla «Qué ve cada jugador» de la ficha, con una prioridad estricta: una escena
-- manda sobre todo lo demás, porque el grupo entero tiene que ver lo mismo; después, la vista
-- general, que el jugador pide con un botón y puede usar también el activo; si no, el activo va en
-- primera persona sobre su ficha y el resto sigue a la ficha activa.
local Scenes = require("../../shared/config/Scenes")

export type Mode = "FirstPerson" | "FollowActive" | "Scene" | "Overview"
export type Context = {
	isActive: boolean?,
	sceneRunning: boolean?,
	overviewRequested: boolean?,
}

-- Recorrido más corto que se acepta: por debajo, la ficha parece teletransportarse.
local MIN_RIDE_SEC = 0.4

-- Parte de la altura del avatar a la que se pone la cámara: la de los ojos, para que un avatar muy
-- bajo no deje la cámara dentro de la ficha y uno muy alto no la deje dentro de su cabeza.
local EYE_HEIGHT_RATIO = 0.85
local MIN_SEAT_OFFSET = 1

local CameraRules = {}

CameraRules.MIN_RIDE_SEC = MIN_RIDE_SEC
CameraRules.EYE_HEIGHT_RATIO = EYE_HEIGHT_RATIO
CameraRules.MIN_SEAT_OFFSET = MIN_SEAT_OFFSET

-- Modo de cámara que toca. Un contexto incompleto cuenta como «nada activo»: es lo que ocurre
-- antes de que llegue el primer lote, y la cámara nunca debe quedarse en blanco.
function CameraRules.modeFor(ctx: Context): Mode
	if ctx.sceneRunning == true then
		return "Scene"
	end
	if ctx.overviewRequested == true then
		return "Overview"
	end
	if ctx.isActive == true then
		return "FirstPerson"
	end
	return "FollowActive"
end

-- Duración de un recorrido, acotada por el tope de `Scenes`. Sea cual sea la distancia, la ficha
-- nunca tarda más: el turno se mide en segundos, no en studs.
function CameraRules.rideSeconds(requested: number): number
	if requested ~= requested then
		return MIN_RIDE_SEC
	end
	return math.clamp(requested, MIN_RIDE_SEC, Scenes.maxRideSec)
end

-- Separación entre el asiento de la ficha y la cámara, según la altura del avatar. Con alturas
-- absurdas (un modelo roto) se queda en el mínimo, que sigue estando por encima de la ficha.
function CameraRules.seatOffset(avatarHeight: number): number
	if avatarHeight ~= avatarHeight or avatarHeight < 0 then
		return MIN_SEAT_OFFSET
	end
	return math.max(MIN_SEAT_OFFSET, avatarHeight * EYE_HEIGHT_RATIO)
end

return CameraRules

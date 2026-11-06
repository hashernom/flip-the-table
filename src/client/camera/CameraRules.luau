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
local Ui = require("../../shared/config/Ui")

export type Mode = "Turn" | "Ride" | "Scene" | "Overview" | "Manage"
export type Context = {
	riding: boolean?,
	sceneRunning: boolean?,
	overviewRequested: boolean?,
	-- «Gestionar propiedades» abierto: primer plano de la propiedad elegida (R-P53).
	managing: boolean?,
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
	if ctx.managing == true then
		return "Manage"
	end
	if ctx.overviewRequested == true then
		return "Overview"
	end
	return "Turn"
end

-- Primer plano de una propiedad: la cámara se pone del lado de la calle, delante de la fachada y algo
-- por encima, y mira al solar. `toRoad` es la dirección del solar hacia su calle (no hace falta normalizada).
function CameraRules.managePose(
	lot: CityLayout.Vector3Like,
	toRoad: CityLayout.Vector3Like
): (CityLayout.Vector3Like, CityLayout.Vector3Like)
	local shot = CameraShots.manage
	local length = math.sqrt(toRoad.x * toRoad.x + toRoad.z * toRoad.z)
	local dx, dz = 0, 1
	if length > 1e-6 then
		dx, dz = toRoad.x / length, toRoad.z / length
	end
	local eye = { x = lot.x + dx * shot.distance, y = lot.y + shot.up, z = lot.z + dz * shot.distance }
	local toward = shot.toward or 0
	local focus = { x = lot.x + dx * toward, y = lot.y + shot.focusUp, z = lot.z + dz * toward }
	return eye, focus
end

-- Dónde va la cámara y a qué mira, para una ficha en `position` que avanza según `facing`. La ruta gira
-- siempre a la derecha, así que el interior del anillo queda a la derecha de la marcha.
function CameraRules.pose(
	shot: CameraShots.Shot,
	position: CityLayout.Vector3Like,
	facing: number
): (CityLayout.Vector3Like, CityLayout.Vector3Like)
	local forwardX, forwardZ = math.sin(facing), math.cos(facing)
	-- `inward` se mide hacia la mitad libre de la calle, la contraria a los edificios (`LOT_SIDE`).
	local side = if shot.fixedSide then 1 else CityLayout.LOT_SIDE
	local rightX, rightZ = -forwardZ * side, forwardX * side
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

-- Dónde va la cámara de la vista general: crece con la ciudad, para que quepa en cualquier tamaño.
function CameraRules.overviewPose(
	center: CityLayout.Vector3Like,
	span: number,
	yaw: number
): (CityLayout.Vector3Like, CityLayout.Vector3Like)
	local back = span * CameraShots.overview.backPerSpan
	-- Se aparta para que el tablero quede fuera del panel lateral, que en espejo (`Ui.hudMirror`) está a la
	-- izquierda.
	local shift = span * CameraShots.overview.panelShiftPerSpan * (if Ui.hudMirror then -1 else 1)
	local sine, cosine = math.sin(yaw), math.cos(yaw)
	local focusX, focusZ = center.x - cosine * shift, center.z + sine * shift
	local focus = { x = focusX, y = center.y, z = focusZ }
	local eye = {
		x = focusX + sine * back,
		y = center.y + span * CameraShots.overview.heightPerSpan,
		z = focusZ + cosine * back,
	}
	return eye, focus
end

-- Giro de la vista general tras arrastrar `pixels`. Un valor roto no la mueve.
function CameraRules.overviewYaw(yaw: number, pixels: number): number
	if pixels ~= pixels then
		return yaw
	end
	return yaw - pixels * CameraShots.overview.radiansPerPixel
end

-- Cuánto se acerca la cámara a su plano en un fotograma de `dt` segundos. Es exponencial para que el
-- movimiento sea el mismo a 30 que a 144 FPS. Un tiempo roto no la mueve.
function CameraRules.followAlpha(rate: number, dt: number): number
	if dt ~= dt or dt <= 0 then
		return 0
	end
	return 1 - math.exp(-rate * dt)
end

-- ¿El recorrido va marcha atrás? Hacia delante, el primer paso es la casilla siguiente o la Salida al dar
-- la vuelta; cualquier otro primer paso es un retroceso (el perdedor de un Duelo). La cámara se pone
-- entonces delante de la ficha, mirando hacia donde va, para que se vea a quién retrocede.
function CameraRules.isBackward(from: number, path: { number }): boolean
	local first = path[1]
	if first == nil then
		return false
	end
	return first ~= from + 1 and first ~= 1
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

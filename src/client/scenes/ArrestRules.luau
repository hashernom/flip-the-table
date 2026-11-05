--!strict
-- Reglas de la escena de detención (PlayerArrested). Son puras: tiempos, puntos y rutas como tablas, sin
-- Instance ni Vector3, para probarlas con Lune. `Arrest` las aplica sobre las mallas. Los valores ajustables
-- viven en `shared/config/ArrestStaging`; aquí se reexponen con sus mismos nombres.
--
-- Todo se mide en coordenadas locales de la esquina Tribunal (V): `along` avanza por la calle que sigue a
-- la esquina (F) y `side` va hacia el interior del anillo (R). Así la misma geometría vale en S, M y L y
-- en cualquier giro del anillo. La cárcel queda a `side` negativo, al otro lado de la acera.
local ArrestStaging = require("../../shared/config/ArrestStaging")
local CityLayout = require("../../shared/config/CityLayout")

export type Vec = CityLayout.Vector3Like
export type Local = { along: number, side: number }
export type Frame = { corner: Vec, facing: number }
export type Window = { from: number, to: number }

local ArrestRules = {}

-- Pasos del tiempo bloqueante, en orden. Sus fracciones suman 1: la escena las reparte sobre
-- `ctx.duration`, así que una repetición (duración a la mitad) sigue viéndose coherente.
ArrestRules.STEPS = { "detach", "sirens", "closeUp", "board", "depart", "lap", "gate" }
ArrestRules.FRACTIONS = ArrestStaging.FRACTIONS

-- Dónde está el detenido: su casilla. Es el mismo punto que `CityLayout.slotCenter`.
ArrestRules.DETAINED = { along = 0, side = CityLayout.SLOT_SIDE_STUDS }

-- Fachada de la cárcel: en la acera exterior, a la distancia de la calle que marca la configuración.
-- Va desde la calle hasta el solar, la acera y el fondo del edificio, que queda centrado en el solar.
local JAIL_GATE_SIDE = -(
	CityLayout.STREET_WIDTH_STUDS / 2
	+ CityLayout.SIDEWALK_STUDS
	+ CityLayout.LOT_DEPTH_STUDS / 2
	+ ArrestStaging.JAIL_FRONT_OFFSET
	- ArrestStaging.JAIL_DEPTH / 2
)
ArrestRules.JAIL_GATE_SIDE = JAIL_GATE_SIDE
-- Dentro de la cárcel: la patrulla entera queda tras la fachada, así que su centro va siete studs más al fondo.
ArrestRules.JAIL_INSIDE_SIDE = JAIL_GATE_SIDE - 7

ArrestRules.CARS = ArrestStaging.CARS
ArrestRules.OFFICERS = ArrestStaging.OFFICERS
ArrestRules.DEPART_STUDS = ArrestStaging.DEPART_STUDS
ArrestRules.DOOR = ArrestStaging.DOOR
ArrestRules.BOARD_ARRIVED = ArrestStaging.BOARD_ARRIVED
ArrestRules.BOARD_HELD = ArrestStaging.BOARD_HELD
ArrestRules.FLASH_HZ = ArrestStaging.FLASH_HZ
ArrestRules.TURN_RADIANS_PER_SEC = ArrestStaging.TURN_RADIANS_PER_SEC

local ESCORT_STOP = ArrestStaging.ESCORT_STOP
local CONVOY_START_SIDE = ArrestStaging.GATE_START_SIDE + ArrestStaging.CONVOY_GAP

-- Studs de la entrada final de cada patrulla: lo que le queda cuando acaba la vuelta. A sigue recta hasta dentro
-- de la cárcel. B viene un trecho por detrás, por la misma calle, y se aparta a su sitio junto a la casilla.
ArrestRules.GATE_STUDS = {
	A = ArrestStaging.GATE_START_SIDE - ArrestRules.JAIL_INSIDE_SIDE,
	B = CONVOY_START_SIDE - ArrestStaging.ESCORT_TURN_SIDE + math.sqrt(
		ESCORT_STOP.along ^ 2 + (ArrestStaging.ESCORT_TURN_SIDE - ESCORT_STOP.side) ^ 2
	),
}

-- Coordenada local de un punto del mundo: lo contrario de `toWorld`.
local function toLocal(frame: Frame, point: Vec): Local
	local forwardX, forwardZ = math.sin(frame.facing), math.cos(frame.facing)
	local rightX, rightZ = -forwardZ, forwardX
	local dx, dz = point.x - frame.corner.x, point.z - frame.corner.z
	return { along = dx * forwardX + dz * forwardZ, side = dx * rightX + dz * rightZ }
end

-- Recorridos de las dos patrullas: desde su aparcamiento, por todas las casillas del anillo, hasta volver a la
-- esquina por la calle de llegada. A entra en la cárcel; B se aparta junto a la casilla. Vale para cualquier
-- tamaño de tablero, porque el anillo se lee de la ruta.
function ArrestRules.routes(route: { CityLayout.Slot }, slot: CityLayout.Slot): { [string]: { Local } }
	local frame = ArrestRules.frameOf(slot)
	local start = 1
	for index, candidate in route do
		if candidate == slot then
			start = index
		end
	end
	local ring: { Local } = {}
	for step = 1, #route - 1 do
		local nextSlot = route[(start + step - 1) % #route + 1]
		table.insert(ring, toLocal(frame, nextSlot.position))
	end

	local carA: { Local } = { ArrestRules.CARS.A.spot }
	-- B sale por detrás de A, por la misma línea, para no cruzarse con ella.
	local carB: { Local } = { ArrestRules.CARS.B.spot, ArrestRules.CARS.A.spot }
	for _, point in ring do
		table.insert(carA, point)
		table.insert(carB, point)
	end
	table.insert(carA, { along = 0, side = ArrestRules.JAIL_INSIDE_SIDE })
	table.insert(carB, { along = 0, side = ArrestStaging.ESCORT_TURN_SIDE })
	table.insert(carB, ESCORT_STOP)
	return { A = carA, B = carB }
end

-- Lo recorrido por una patrulla en el instante `time`, con la longitud de su ruta y de su entrada. Primero arranca
-- despacio, luego se lanza por el anillo y, ya en la calle de llegada, frena hasta su sitio.
function ArrestRules.travelDistance(
	windows: { [string]: Window },
	time: number,
	length: number,
	gateStuds: number
): number
	local lapStuds = length - gateStuds - ArrestStaging.DEPART_STUDS
	if time < windows.lap.from then
		return ArrestStaging.DEPART_STUDS * ArrestRules.ease(ArrestRules.progress(windows.depart, time))
	elseif time < windows.gate.from then
		local lap = ArrestRules.progress(windows.lap, time)
		return ArrestStaging.DEPART_STUDS + lapStuds * lap ^ ArrestStaging.LAP_CURVE
	end
	local gate = ArrestRules.progress(windows.gate, time)
	return length - gateStuds + gateStuds * (1 - (1 - gate) ^ 2)
end

-- Llegada de una patrulla: dónde está, hacia dónde apunta y cuánto cabecea con `progress` entre 0 y 1 del paso
-- `sirens`. Entra lanzada y clava los frenos, y al final derrapa hasta quedar cruzada. Devuelve también si derrapa.
function ArrestRules.arrivalPose(key: string, progress: number): (Local, Local, number, boolean)
	local car = ArrestRules.CARS[key]
	local span = car.window.to - car.window.from
	local own = if span > 0 then math.clamp((progress - car.window.from) / span, 0, 1) else 1
	local travelled = 1 - (1 - own) ^ 3
	local point = ArrestRules.lerp(car.arrival, car.spot, travelled)
	local skid = math.clamp((own - ArrestStaging.SKID_FROM) / (1 - ArrestStaging.SKID_FROM), 0, 1)
	local eased = ArrestRules.ease(skid)
	local along = car.parked.along * eased
	local side = -1 + (car.parked.side + 1) * eased
	local size = math.sqrt(along * along + side * side)
	local heading = { along = along / size, side = side / size }
	local pitch = ArrestStaging.BRAKE_PITCH * math.sin(skid * math.pi)
	return point, heading, pitch, skid > 0 and skid < 1
end

-- Ventanas de cada paso, en segundos desde el inicio de la escena. Consecutivas; la última acaba en
-- `duration` exacto para que la escena nunca pase de su tiempo.
function ArrestRules.windows(duration: number): { [string]: Window }
	local total = math.max(0, duration)
	local windows: { [string]: Window } = {}
	local at = 0
	for index, name in ArrestRules.STEPS do
		local from = at
		if index == #ArrestRules.STEPS then
			at = total
		else
			at += ArrestRules.FRACTIONS[name] * total
		end
		windows[name] = { from = from, to = at }
	end
	return windows
end

-- Avance de un paso entre 0 y 1 en el instante `time`. Un paso de duración nula ya está acabado.
function ArrestRules.progress(window: Window, time: number): number
	if time ~= time then
		return 0
	end
	local span = window.to - window.from
	if span <= 0 then
		return if time >= window.to then 1 else 0
	end
	return math.clamp((time - window.from) / span, 0, 1)
end

-- Suavizado para que las patrullas frenen y los policías arranquen sin tirones.
function ArrestRules.ease(t: number): number
	local clamped = math.clamp(t, 0, 1)
	return clamped * clamped * (3 - 2 * clamped)
end

function ArrestRules.lerp(a: Local, b: Local, t: number): Local
	return {
		along = a.along + (b.along - a.along) * t,
		side = a.side + (b.side - a.side) * t,
	}
end

-- Gira el vector unitario `current` hacia `target` como mucho `maxRadians`, por el camino corto. Devuelve un
-- vector unitario. Si alguno de los dos es casi nulo no hay rumbo que girar, y devuelve `target`.
local NULL_LENGTH = 1e-6
local TAU = 2 * math.pi

function ArrestRules.turnToward(current: Local, target: Local, maxRadians: number): Local
	local currentLength = math.sqrt(current.along * current.along + current.side * current.side)
	local targetLength = math.sqrt(target.along * target.along + target.side * target.side)
	if currentLength < NULL_LENGTH or targetLength < NULL_LENGTH then
		return target
	end
	local from = math.atan2(current.side, current.along)
	local to = math.atan2(target.side, target.along)
	-- Diferencia llevada a [-pi, pi): el camino corto, nunca la vuelta entera.
	local difference = (to - from + math.pi) % TAU - math.pi
	local limit = math.max(0, maxRadians)
	local step = math.clamp(difference, -limit, limit)
	local angle = from + step
	return { along = math.cos(angle), side = math.sin(angle) }
end

-- Punto del mundo (suelo) de una coordenada local, con la esquina y el giro de la casilla Tribunal.
function ArrestRules.toWorld(frame: Frame, point: Local): Vec
	local forwardX, forwardZ = math.sin(frame.facing), math.cos(frame.facing)
	local rightX, rightZ = -forwardZ, forwardX
	return {
		x = frame.corner.x + forwardX * point.along + rightX * point.side,
		y = 0,
		z = frame.corner.z + forwardZ * point.along + rightZ * point.side,
	}
end

-- Dirección del mundo de un vector local (sin la posición de la esquina).
function ArrestRules.directionOf(frame: Frame, direction: Local): Vec
	return ArrestRules.toWorld({ corner = { x = 0, y = 0, z = 0 }, facing = frame.facing }, direction)
end

-- Marco de una casilla: su esquina y el giro de la calle que sigue.
function ArrestRules.frameOf(slot: CityLayout.Slot): Frame
	return { corner = slot.position, facing = slot.facing }
end

-- Casilla Tribunal de una ruta, o nil si el tablero no la tiene.
function ArrestRules.tribunalSlot(route: { CityLayout.Slot }): CityLayout.Slot?
	for _, slot in route do
		if slot.kind == "Tribunal" then
			return slot
		end
	end
	return nil
end

-- Longitud de un recorrido: suma de sus tramos.
function ArrestRules.routeLength(route: { Local }): number
	local total = 0
	for index = 1, #route - 1 do
		local a, b = route[index], route[index + 1]
		total += math.sqrt((b.along - a.along) ^ 2 + (b.side - a.side) ^ 2)
	end
	return total
end

-- Punto de un recorrido a `distance` studs del inicio, con su dirección de marcha. Pasado el final se queda
-- en el último punto y devuelve `true` como tercer valor. Un recorrido de menos de dos puntos no se mueve.
function ArrestRules.pointOn(route: { Local }, distance: number): (Local, Local, boolean)
	if #route == 0 then
		return { along = 0, side = 0 }, { along = 0, side = 0 }, true
	end
	if #route == 1 then
		return route[1], { along = 0, side = 0 }, true
	end
	local remaining = math.max(0, distance)
	for index = 1, #route - 1 do
		local a, b = route[index], route[index + 1]
		local dAlong, dSide = b.along - a.along, b.side - a.side
		local length = math.sqrt(dAlong * dAlong + dSide * dSide)
		if length > 0 and remaining <= length then
			local t = remaining / length
			return { along = a.along + dAlong * t, side = a.side + dSide * t },
				{ along = dAlong / length, side = dSide / length },
				false
		end
		remaining -= length
	end
	local last, before = route[#route], route[#route - 1]
	local dAlong, dSide = last.along - before.along, last.side - before.side
	local length = math.sqrt(dAlong * dAlong + dSide * dSide)
	local heading = if length > 0
		then { along = dAlong / length, side = dSide / length }
		else { along = 0, side = 0 }
	return last, heading, true
end

-- Punto de la cárcel donde entra la patrulla A: la puerta, en la fachada, alineada con la columna along 0.
function ArrestRules.gate(): Local
	return { along = 0, side = JAIL_GATE_SIDE }
end

return ArrestRules

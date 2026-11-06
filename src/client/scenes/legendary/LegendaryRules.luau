--!strict
-- Reglas puras de las cinco escenas legendarias (plan 08, Tarea 3). Tiempos, recorridos y trayectorias como
-- tablas, sin `Instance` ni `Vector3`, para probarlas con Lune. Cada escena las aplica sobre sus piezas; los
-- valores ajustables viven en `shared/config/LegendaryStaging`.
--
-- Nada aquí decide reglas: quién da y quién recibe se lee de la vista que ya resolvió el servidor.
local LegendaryStaging = require("../../../shared/config/LegendaryStaging")

export type Window = { from: number, to: number }
export type Point = { x: number, z: number }
export type Point3 = { x: number, y: number, z: number }
export type Loop = {
	points: { Point },
	-- Longitud acumulada al llegar a cada punto; el último tramo cierra el anillo.
	cumulative: { number },
	length: number,
	-- Fracción del recorrido en la que se pasa por cada punto.
	passAt: { number },
}
export type Pose = { x: number, z: number, headingX: number, headingZ: number }
export type Pair = { giver: string, taker: string }

local TAU = 2 * math.pi

local LegendaryRules = {}

-- Reparte `duration` entre los pasos de una escena según sus fracciones. El último paso acaba justo en la
-- duración, así que una escena acortada sigue cerrando a su hora.
function LegendaryRules.windows(staging: LegendaryStaging.Staging, duration: number): { [string]: Window }
	local total = math.max(0, duration)
	local windows: { [string]: Window } = {}
	local at = 0
	for index, step in staging.steps do
		local from = at
		if index == #staging.steps then
			at = total
		else
			at += (staging.fractions[step] or 0) * total
		end
		windows[step] = { from = from, to = at }
	end
	return windows
end

-- Avance de 0 a 1 dentro de una ventana.
function LegendaryRules.progress(window: Window, time: number): number
	if time ~= time then
		return 0
	end
	local span = window.to - window.from
	if span <= 0 then
		return if time >= window.to then 1 else 0
	end
	return math.clamp((time - window.from) / span, 0, 1)
end

-- Suavizado de entrada y salida.
function LegendaryRules.ease(t: number): number
	local clamped = math.clamp(t, 0, 1)
	return clamped * clamped * (3 - 2 * clamped)
end

-- Anillo cerrado por los puntos dados, medido por longitud: el embudo avanza a velocidad constante aunque
-- las casillas de esquina estén más separadas.
function LegendaryRules.loop(points: { Point }): Loop
	local cumulative: { number } = {}
	local length = 0
	for index, point in points do
		cumulative[index] = length
		local nextPoint = points[index % #points + 1]
		length += math.sqrt((nextPoint.x - point.x) ^ 2 + (nextPoint.z - point.z) ^ 2)
	end
	local passAt: { number } = {}
	for index in points do
		passAt[index] = if length > 0 then cumulative[index] / length else 0
	end
	return { points = points, cumulative = cumulative, length = length, passAt = passAt }
end

-- Punto y rumbo a la fracción `fraction` del anillo (0 y 1 son la salida).
function LegendaryRules.along(loop: Loop, fraction: number): Pose
	local points = loop.points
	if #points == 0 then
		return { x = 0, z = 0, headingX = 0, headingZ = 1 }
	end
	if #points == 1 or loop.length <= 0 then
		return { x = points[1].x, z = points[1].z, headingX = 0, headingZ = 1 }
	end
	local distance = (fraction % 1) * loop.length
	if fraction >= 1 then
		distance = 0
	end
	local segment = #points
	for index = 1, #points do
		local stop = if index < #points then loop.cumulative[index + 1] else loop.length
		if distance < stop then
			segment = index
			break
		end
	end
	local from = points[segment]
	local to = points[segment % #points + 1]
	local dx, dz = to.x - from.x, to.z - from.z
	local span = math.sqrt(dx * dx + dz * dz)
	local t = if span > 0 then (distance - loop.cumulative[segment]) / span else 0
	local headingX, headingZ = 0, 1
	if span > 0 then
		headingX, headingZ = dx / span, dz / span
	end
	return { x = from.x + dx * t, z = from.z + dz * t, headingX = headingX, headingZ = headingZ }
end

-- Vuelo de un resto arrancado por el huracán, relativo a donde estaba: sube y se abre en espiral. `seed`
-- (0 a 1) elige hacia dónde sale; `t` (0 a 1) es el avance del vuelo.
function LegendaryRules.debris(seed: number, t: number, staging: typeof(LegendaryStaging.hurricane)): Point3
	local clamped = math.clamp(t, 0, 1)
	local angle = seed * TAU + clamped * staging.debrisTurns * TAU
	local radius = staging.debrisSpread * clamped
	return {
		x = math.cos(angle) * radius,
		y = staging.debrisRise * clamped,
		z = math.sin(angle) * radius,
	}
end

-- Temblor horizontal en el instante `t`: dos senos desfasados por la semilla, nunca más que `amplitude`.
function LegendaryRules.shake(t: number, seed: number, amplitude: number, hz: number): Point
	if amplitude == 0 then
		return { x = 0, z = 0 }
	end
	local phase = seed * TAU
	return {
		x = math.sin(t * hz * TAU + phase) * amplitude,
		z = math.sin(t * hz * 1.37 * TAU + phase * 2) * amplitude,
	}
end

-- Parábola de `from` a `to` que sube `height` por encima de la recta en la mitad.
function LegendaryRules.arc(from: Point3, to: Point3, p: number, height: number): Point3
	local t = math.clamp(p, 0, 1)
	if t == 0 then
		return { x = from.x, y = from.y, z = from.z }
	elseif t == 1 then
		return { x = to.x, y = to.y, z = to.z }
	end
	return {
		x = from.x + (to.x - from.x) * t,
		y = from.y + (to.y - from.y) * t + height * 4 * t * (1 - t),
		z = from.z + (to.z - from.z) * t,
	}
end

-- Activos ordenados por efectivo, de más a menos; a igualdad, por id, para que todos vean lo mismo.
local function ranking(players: { any }): { any }
	local active: { any } = {}
	for _, player in players do
		if player.status == "Active" then
			table.insert(active, player)
		end
	end
	table.sort(active, function(a, b)
		if a.cash ~= b.cash then
			return a.cash > b.cash
		end
		return tostring(a.id) < tostring(b.id)
	end)
	return active
end

-- Quién dio y quién recibió en la Revolución, leído de la vista ya resuelta: el motor cambió el efectivo
-- del más rico con el del más pobre (y del segundo con el penúltimo con 4 o más). Después del cambio, el
-- que era rico es el más pobre: él da, y el que ahora encabeza recibe.
function LegendaryRules.revolutionPairs(players: { any }): { Pair }
	local active = ranking(players)
	local count = #active
	local pairs: { Pair } = {}
	if count < 2 then
		return pairs
	end
	table.insert(pairs, { giver = active[count].id, taker = active[1].id })
	if count >= 4 then
		table.insert(pairs, { giver = active[count - 1].id, taker = active[2].id })
	end
	return pairs
end

-- Rivales que reciben su parte en el Golpe a la Corona: los activos que no son el líder, en el orden de
-- los asientos.
function LegendaryRules.crownRivals(leaderId: string, players: { any }): { string }
	local rivals: { string } = {}
	for _, player in players do
		if player.status == "Active" and player.id ~= leaderId then
			table.insert(rivals, player.id)
		end
	end
	return rivals
end

-- Centro de la ciudad y lado mayor del recuadro que ocupan sus casillas.
function LegendaryRules.center(points: { Point }): (Point, number)
	if #points == 0 then
		return { x = 0, z = 0 }, 0
	end
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, point in points do
		minX, maxX = math.min(minX, point.x), math.max(maxX, point.x)
		minZ, maxZ = math.min(minZ, point.z), math.max(maxZ, point.z)
	end
	return { x = (minX + maxX) / 2, z = (minZ + maxZ) / 2 }, math.max(maxX - minX, maxZ - minZ)
end

return LegendaryRules

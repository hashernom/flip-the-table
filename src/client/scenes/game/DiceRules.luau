--!strict
-- Reglas puras de la escena de los dados (plan 08, Tarea 6). Sin `Instance` ni `CFrame`: ángulos y números,
-- para probarlas con Lune. La escena (`scenes/game/Dice`) las convierte en piezas.
--
-- Un dado es un cubo con los puntos de un dado de verdad: caras opuestas suman 7. En sus ejes locales:
-- +Y = 1, -Y = 6, +X = 3, -X = 4, +Z = 2, -Z = 5. Para que el dado acabe enseñando arriba el valor que
-- mandó el servidor, se gira con `restAngles(valor)` y después solo se le da la vuelta alrededor de la
-- vertical, que no cambia la cara de arriba.
local DiceRules = {}

export type Face = { value: number, normal: { x: number, y: number, z: number } }

-- Las seis caras con su normal local.
DiceRules.FACES = {
	{ value = 1, normal = { x = 0, y = 1, z = 0 } },
	{ value = 6, normal = { x = 0, y = -1, z = 0 } },
	{ value = 3, normal = { x = 1, y = 0, z = 0 } },
	{ value = 4, normal = { x = -1, y = 0, z = 0 } },
	{ value = 2, normal = { x = 0, y = 0, z = 1 } },
	{ value = 5, normal = { x = 0, y = 0, z = -1 } },
} :: { Face }

-- Posición de los puntos de cada valor en su cara, de -1 a 1 en los dos ejes de la cara.
local PIPS: { [number]: { { number } } } = {
	[1] = { { 0, 0 } },
	[2] = { { -1, -1 }, { 1, 1 } },
	[3] = { { -1, -1 }, { 0, 0 }, { 1, 1 } },
	[4] = { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } },
	[5] = { { -1, -1 }, { 1, -1 }, { 0, 0 }, { -1, 1 }, { 1, 1 } },
	[6] = { { -1, -1 }, { 1, -1 }, { -1, 0 }, { 1, 0 }, { -1, 1 }, { 1, 1 } },
}

function DiceRules.pips(value: number): { { number } }
	return PIPS[value] or {}
end

-- Giro (en radianes, alrededor de X y de Z) que deja la cara `value` hacia arriba. Un valor fuera de 1 a 6
-- deja el 1 arriba: la escena nunca falla por un dato raro.
function DiceRules.restAngles(value: number): (number, number)
	local half = math.pi / 2
	if value == 6 then
		return math.pi, 0
	elseif value == 3 then
		return 0, half
	elseif value == 4 then
		return 0, -half
	elseif value == 2 then
		return -half, 0
	elseif value == 5 then
		return half, 0
	end
	return 0, 0
end

-- Valores del evento en orden: dos dados, o tres con el Dado Extra. Ignora lo que no sea un entero de 1 a 6.
function DiceRules.values(event: { [string]: any }): { number }
	local list: { number } = {}
	for _, key in { "a", "b", "c" } do
		local value = event[key]
		if type(value) == "number" and value >= 1 and value <= 6 and value == math.floor(value) then
			table.insert(list, value)
		end
	end
	return list
end

-- Si es una tirada doble: los dos primeros dados iguales.
function DiceRules.isDouble(values: { number }): boolean
	return #values >= 2 and values[1] == values[2]
end

function DiceRules.total(values: { number }): number
	local sum = 0
	for _, value in values do
		sum += value
	end
	return sum
end

-- Altura (en múltiplos de `height`) del dado en el momento `p` (0 a 1) de su caída: un lanzamiento alto y
-- dos botes cada vez más bajos, y quieto desde `rest`. Nunca baja de 0.
function DiceRules.hop(p: number, rest: number): number
	local t = math.clamp(p, 0, 1)
	if t >= rest then
		return 0
	end
	local s = t / rest
	-- Tres arcos: el lanzamiento (55 %) y dos botes (30 % y 15 %), de altura 1, 0,3 y 0,1.
	local spans = { { 0, 0.55, 1 }, { 0.55, 0.85, 0.3 }, { 0.85, 1, 0.1 } }
	for _, span in spans do
		if s <= span[2] then
			local u = (s - span[1]) / (span[2] - span[1])
			return 4 * u * (1 - u) * span[3]
		end
	end
	return 0
end

-- Cuánto del giro de rodar queda en `p`: 1 al lanzar, 0 desde `rest`. Frena al final (curva cúbica), así
-- el dado no da un tirón al quedarse en su cara.
function DiceRules.spinLeft(p: number, rest: number): number
	local t = math.clamp(p / rest, 0, 1)
	local left = 1 - t
	return left * left * left
end

-- Avance horizontal (0 a 1) del lanzamiento hasta su punto de reposo, frenando al final.
function DiceRules.travel(p: number, rest: number): number
	local t = math.clamp(p / rest, 0, 1)
	return 1 - (1 - t) * (1 - t)
end

-- Número entre 0 y 1 que sale solo de los datos (sin azar): así todo el grupo ve el mismo vuelo.
function DiceRules.jitter(seed: number, salt: number): number
	local x = math.sin(seed * 12.9898 + salt * 78.233) * 43758.5453
	return x - math.floor(x)
end

return DiceRules

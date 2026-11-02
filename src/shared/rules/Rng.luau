--!strict
-- Azar determinista y serializable. No usa Random ni math.random para que una
-- misma semilla dé el mismo resultado en Lune y en Roblox.

export type RngState = { seed: number, forced: { number }? }

local MODULUS = 2 ^ 31
local MULTIPLIER = 1103515245
local INCREMENT = 12345
local LOW_BITS = 65536

local Rng = {}

-- Multiplica por partes: el producto directo superaría los 53 bits de precisión de un número.
local function advance(rng: RngState): number
	local high = math.floor(rng.seed / LOW_BITS)
	local low = rng.seed % LOW_BITS
	local highPart = (high * MULTIPLIER) % MODULUS
	rng.seed = (highPart * LOW_BITS + low * MULTIPLIER + INCREMENT) % MODULUS
	return rng.seed
end

function Rng.new(seed: number): RngState
	if seed ~= seed or seed == math.huge or seed == -math.huge then
		error("Rng.new: la semilla debe ser un número finito", 2)
	end
	return { seed = math.floor(seed) % MODULUS }
end

function Rng.force(rng: RngState, values: { number })
	rng.forced = table.clone(values)
end

function Rng.int(rng: RngState, min: number, max: number): number
	if min > max then
		error(`Rng.int: rango no válido [{min}, {max}]`, 2)
	end
	local forced = rng.forced
	if forced then
		local value = table.remove(forced, 1) :: number
		if #forced == 0 then
			rng.forced = nil
		end
		return value
	end
	return min + math.floor(advance(rng) / MODULUS * (max - min + 1))
end

function Rng.pick<T>(rng: RngState, list: { T }): T
	if #list == 0 then
		error("Rng.pick: la lista está vacía", 2)
	end
	return list[Rng.int(rng, 1, #list)]
end

function Rng.shuffle<T>(rng: RngState, list: { T }): { T }
	local result = table.clone(list)
	for i = #result, 2, -1 do
		local j = Rng.int(rng, 1, i)
		result[i], result[j] = result[j], result[i]
	end
	return result
end

return Rng

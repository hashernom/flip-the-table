--!strict
-- Pruebas del pool de actores de escena. `ActorsRules` es puro: no crea `Instance` ni toca servicios, solo
-- cuenta activos, libres y topes. Cubren pedir de más, liberar, reutilizar y limpiar, que es lo que necesita
-- `Actors` para no llenar la ciudad de mallas.
local Harness = require("../harness")
local ActorsRules = require("../../src/client/scenes/ActorsRules")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

-- `Pools` y `DEFAULTS` indexan por el union `Kind`; un literal suelto se ensancha a `string`, así que las
-- pruebas entran siempre por un parámetro ya anotado.
local function poolOf(pools: ActorsRules.Pools, kind: ActorsRules.Kind): ActorsRules.State
	return pools[kind]
end

local function defaultLimit(kind: ActorsRules.Kind): number
	return ActorsRules.DEFAULTS[kind]
end

describe("ActorsRules: tipos y topes", function()
	it("los ocho tipos de la tarea tienen tope y están en la lista", function()
		local expected: { ActorsRules.Kind } = {
			"Police",
			"PatrolCar",
			"Crowd",
			"Worker",
			"Crane",
			"TowTruck",
			"ArmoredTruck",
			"WreckingBall",
		}
		expect(#ActorsRules.KINDS).toBe(#expected)
		-- Por índice y con el tipo anotado: la iteración genérica ensancha los literales a `string`.
		for index = 1, #expected do
			local kind: ActorsRules.Kind = expected[index]
			expect(ActorsRules.kindOf(kind)).toBe(kind)
			expect(ActorsRules.DEFAULTS[kind] >= 1).toBe(true)
		end
	end)

	it("un texto que no es un tipo no vale", function()
		expect(ActorsRules.kindOf("Ghost")).toBe(nil)
		expect(ActorsRules.kindOf("police")).toBe(nil)
	end)

	it("new copia los topes por defecto con la cuenta a cero", function()
		local pools = ActorsRules.new()
		for index = 1, #ActorsRules.KINDS do
			local kind: ActorsRules.Kind = ActorsRules.KINDS[index]
			local state = pools[kind]
			expect(state.active).toBe(0)
			expect(state.free).toBe(0)
			expect(state.max).toBe(ActorsRules.DEFAULTS[kind])
		end
	end)

	it("new acepta topes propios y sanea negativos y decimales", function()
		local pools = ActorsRules.new({ Police = 2, Crowd = -3, Crane = 1.9, TowTruck = 0 })
		expect(poolOf(pools, "Police").max).toBe(2)
		expect(poolOf(pools, "Crowd").max).toBe(0)
		expect(poolOf(pools, "Crane").max).toBe(1)
		expect(poolOf(pools, "TowTruck").max).toBe(0)
		expect(poolOf(pools, "Worker").max).toBe(defaultLimit("Worker"))
	end)

	it("cada pool lleva su cuenta: dos llamadas a new no se pisan", function()
		local first = ActorsRules.new()
		local second = ActorsRules.new()
		ActorsRules.take(poolOf(first, "Police"))
		expect(poolOf(first, "Police").active).toBe(1)
		expect(poolOf(second, "Police").active).toBe(0)
	end)
end)

describe("ActorsRules: pedir de más", function()
	it("al llegar al tope, take devuelve nil y no mueve la cuenta", function()
		local state = { active = 0, free = 0, max = 2 }
		expect(ActorsRules.take(state)).toBe("create")
		expect(ActorsRules.take(state)).toBe("create")
		expect(ActorsRules.take(state)).toBe(nil)
		expect(state.active).toBe(2)
		expect(state.free).toBe(0)
		expect(ActorsRules.take(state)).toBe(nil)
	end)

	it("un tipo con tope cero no da ningún actor", function()
		local state = { active = 0, free = 0, max = 0 }
		expect(ActorsRules.take(state)).toBe(nil)
		expect(state.active).toBe(0)
	end)
end)

describe("ActorsRules: liberar", function()
	it("drop devuelve el actor al pool y baja el activo", function()
		local state = { active = 0, free = 0, max = 2 }
		ActorsRules.take(state)
		expect(ActorsRules.drop(state)).toBe("recycle")
		expect(state.active).toBe(0)
		expect(state.free).toBe(1)
	end)

	it("liberar sin nada activo no hace nada ni deja la cuenta en negativo", function()
		local state = { active = 0, free = 0, max = 2 }
		expect(ActorsRules.drop(state)).toBe(nil)
		expect(ActorsRules.drop(state)).toBe(nil)
		expect(state.active).toBe(0)
		expect(state.free).toBe(0)
	end)
end)

describe("ActorsRules: reutilizar", function()
	it("tras liberar, take recicla del pool en vez de crear", function()
		local state = { active = 0, free = 0, max = 1 }
		expect(ActorsRules.take(state)).toBe("create")
		ActorsRules.drop(state)
		expect(ActorsRules.take(state)).toBe("reuse")
		expect(state.active).toBe(1)
		expect(state.free).toBe(0)
	end)

	it("reciclar no crea de más ni sube el tope", function()
		local state = { active = 0, free = 0, max = 3 }
		local creates, reuses = 0, 0
		for _ = 1, 100 do
			local slot = ActorsRules.take(state)
			if slot == "create" then
				creates += 1
			elseif slot == "reuse" then
				reuses += 1
			end
			ActorsRules.drop(state)
		end
		expect(creates).toBe(1)
		expect(reuses).toBe(99)
		expect(state.active).toBe(0)
		expect(state.free).toBe(1)
	end)
end)

describe("ActorsRules: limpiar", function()
	it("clear vacía el tipo y conserva su tope", function()
		local state = { active = 0, free = 0, max = 4 }
		ActorsRules.take(state)
		ActorsRules.take(state)
		ActorsRules.drop(state)
		ActorsRules.clear(state)
		expect(state.active).toBe(0)
		expect(state.free).toBe(0)
		expect(state.max).toBe(4)
		expect(ActorsRules.take(state)).toBe("create")
	end)

	it("clearAll limpia todos los tipos y conserva los topes", function()
		local pools = ActorsRules.new({ Police = 2, Crowd = 3 })
		ActorsRules.take(poolOf(pools, "Police"))
		ActorsRules.take(poolOf(pools, "Police"))
		ActorsRules.take(poolOf(pools, "Crowd"))
		ActorsRules.drop(poolOf(pools, "Crowd"))
		ActorsRules.clearAll(pools)
		local active, free = ActorsRules.totals(pools)
		expect(active).toBe(0)
		expect(free).toBe(0)
		expect(poolOf(pools, "Police").max).toBe(2)
		expect(poolOf(pools, "Crowd").max).toBe(3)
	end)
end)

describe("ActorsRules: huecos que no llegan a usarse", function()
	it("cancel deshace un take que no llegó a crear mallas", function()
		local state = { active = 0, free = 0, max = 1 }
		expect(ActorsRules.take(state)).toBe("create")
		ActorsRules.cancel(state)
		expect(state.active).toBe(0)
		expect(state.free).toBe(0)
		expect(ActorsRules.take(state)).toBe("create")
	end)

	it("cancel sin activos no deja la cuenta en negativo", function()
		local state = { active = 0, free = 0, max = 1 }
		ActorsRules.cancel(state)
		expect(state.active).toBe(0)
	end)

	it("si el tope baja, los actores sobrantes se destruyen en vez de llenar el pool", function()
		local pools = ActorsRules.new({ Police = 2 })
		local state = poolOf(pools, "Police")
		ActorsRules.take(state)
		ActorsRules.take(state)
		state.max = 1
		expect(ActorsRules.drop(state)).toBe("recycle")
		expect(ActorsRules.drop(state)).toBe("destroy")
		expect(state.active).toBe(0)
		expect(state.free).toBe(1)
	end)
end)

describe("ActorsRules: totales", function()
	it("totals suma activos y libres de todos los tipos", function()
		local pools = ActorsRules.new()
		ActorsRules.take(poolOf(pools, "Police"))
		ActorsRules.take(poolOf(pools, "Crowd"))
		ActorsRules.drop(poolOf(pools, "Crowd"))
		local active, free = ActorsRules.totals(pools)
		expect(active).toBe(1)
		expect(free).toBe(1)
	end)
end)

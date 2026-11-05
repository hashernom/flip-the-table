--!strict
local Harness = require("../harness")
local ActorPool = require("../../src/client/scenes/ActorPool")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function counter(): (() -> { id: number }, () -> number)
	local built = 0
	return function()
		built += 1
		return { id = built }
	end, function()
		return built
	end
end

describe("ActorPool", function()
	it("crear y liberar 100 veces construye un solo objeto", function()
		local build, built = counter()
		local pool = ActorPool.new(5, build)
		for _ = 1, 100 do
			pool.release((pool.acquire()))
		end
		expect(built()).toBe(1)
		expect(pool.activeCount()).toBe(0)
	end)

	it("nunca construye más que su límite: pasado el tope, reutiliza el más antiguo", function()
		local build, built = counter()
		local pool = ActorPool.new(3, build)
		local first = pool.acquire()
		pool.acquire()
		pool.acquire()
		local fourth = pool.acquire()
		expect(built()).toBe(3)
		expect(fourth).toBe(first)
		expect(pool.activeCount()).toBe(3)
	end)

	it("liberar dos veces, o algo ajeno, no duplica el objeto", function()
		local build = counter()
		local pool = ActorPool.new(3, build)
		local item = pool.acquire()
		pool.release(item)
		pool.release(item)
		pool.release({ id = 99 })
		local a = pool.acquire()
		local b = pool.acquire()
		expect(a).toBe(item)
		expect(a ~= b).toBe(true)
	end)

	it("avisa al reutilizar uno activo para que se pueda recolocar", function()
		local build = counter()
		local pool = ActorPool.new(1, build)
		local _, stolenFirst = pool.acquire()
		local _, stolenSecond = pool.acquire()
		expect(stolenFirst).toBe(false)
		expect(stolenSecond).toBe(true)
	end)

	it("un límite no válido cuenta como uno", function()
		local build, built = counter()
		local pool = ActorPool.new(0, build)
		pool.acquire()
		pool.acquire()
		expect(built()).toBe(1)
	end)
end)

--!strict
-- Reserva de actores de escena: una escena nunca crea más de los que se pueden liberar. Es una regla pura,
-- sin Roblox: quien construye el objeto y lo enseña es `Actors`.
export type Pool<T> = {
	-- Un actor libre o, si ya están todos en escena, el más antiguo. El segundo valor dice si estaba en uso.
	acquire: () -> (T, boolean),
	release: (item: T) -> (),
	activeCount: () -> number,
}

local ActorPool = {}

function ActorPool.new<T>(limit: number, build: () -> T): Pool<T>
	local capacity = math.max(limit, 1)
	local free: { T } = {}
	-- En orden de salida: el primero es el más antiguo.
	local active: { T } = {}
	local built = 0

	return {
		acquire = function(): (T, boolean)
			local item = table.remove(free)
			if item ~= nil then
				table.insert(active, item)
				return item, false
			end
			if built < capacity then
				built += 1
				local made = build()
				table.insert(active, made)
				return made, false
			end
			local oldest = table.remove(active, 1) :: T
			table.insert(active, oldest)
			return oldest, true
		end,
		release = function(item: T)
			local index = table.find(active, item)
			if index ~= nil then
				table.remove(active, index)
				table.insert(free, item)
			end
		end,
		activeCount = function(): number
			return #active
		end,
	}
end

return ActorPool

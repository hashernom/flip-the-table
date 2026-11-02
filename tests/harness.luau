--!strict
-- Arnés mínimo de pruebas para ejecutar con Lune, sin Roblox.

export type Failure = { name: string, message: string }

local Harness = {}

local stack: { string } = {}
local passed = 0
local failures: { Failure } = {}

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for key, value in a do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function show(value: any): string
	if type(value) ~= "table" then
		return tostring(value)
	end
	local parts = {}
	for key, item in value do
		table.insert(parts, `{key} = {show(item)}`)
	end
	table.sort(parts)
	return `\{ {table.concat(parts, ", ")} \}`
end

function Harness.describe(name: string, fn: () -> ())
	table.insert(stack, name)
	fn()
	table.remove(stack)
end

function Harness.it(name: string, fn: () -> ())
	table.insert(stack, name)
	local fullName = table.concat(stack, " > ")
	table.remove(stack)
	local ok: boolean, err: any = (pcall :: any)(fn)
	if ok then
		passed += 1
	else
		table.insert(failures, { name = fullName, message = tostring(err) })
	end
end

function Harness.expect(value: any)
	local matchers = {}

	function matchers.toBe(other: any)
		if value ~= other then
			error(`se esperaba {show(other)}, se obtuvo {show(value)}`, 2)
		end
	end

	function matchers.toEqual(other: any)
		if not deepEqual(value, other) then
			error(`se esperaba {show(other)}, se obtuvo {show(value)}`, 2)
		end
	end

	function matchers.toBeTruthy()
		if not value then
			error(`se esperaba un valor verdadero, se obtuvo {show(value)}`, 2)
		end
	end

	function matchers.toThrow()
		local ok = pcall(value)
		if ok then
			error("se esperaba un error y no se lanzó ninguno", 2)
		end
	end

	return matchers
end

function Harness.results(): (number, { Failure })
	return passed, failures
end

return Harness

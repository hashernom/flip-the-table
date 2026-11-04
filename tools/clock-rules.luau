--!nocheck
-- R-P38: la partida mide el tiempo con Workspace:GetServerTimeNow(). `time()` cuenta desde que arrancó
-- cada proceso, así que un instante suyo no significa nada en el cliente. El servidor y el cliente solo
-- se encuentran en Roblox, donde Lune no llega: esta regla es lo que lo vigila en `tools/check`.
local fs = require("@lune/fs")

local clockRules = {}

local function stripCommentsAndStrings(source: string): string
	local result = string.gsub(source, "%-%-%[%[.-%]%]", "")
	result = string.gsub(result, "%-%-[^\n]*", "")
	result = string.gsub(result, '"[^"\n]*"', '""')
	return (string.gsub(result, "'[^'\n]*'", "''"))
end

-- ¿El código llama a la función global time()? `obj.time()` y `uptime()` no cuentan.
function clockRules.usesUptime(source: string): boolean
	local clean = stripCommentsAndStrings(source)
	local start = 1
	while true do
		local first, last = string.find(clean, "time%s*%(", start)
		if not first then
			return false
		end
		local before = if first > 1 then string.sub(clean, first - 1, first - 1) else ""
		if not string.find(before, "[%w_%.:]") then
			return true
		end
		start = last + 1
	end
end

-- Archivos .luau de la carpeta, también en subcarpetas, que usan time().
function clockRules.offenders(dir: string): { string }
	local found = {}
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			for _, nested in clockRules.offenders(path) do
				table.insert(found, nested)
			end
		elseif string.sub(name, -5) == ".luau" and clockRules.usesUptime(fs.readFile(path)) then
			table.insert(found, path)
		end
	end
	return found
end

return clockRules

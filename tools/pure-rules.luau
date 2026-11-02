--!nocheck
-- Devuelve los archivos que usan APIs de Roblox o fuentes de azar y tiempo no deterministas.
-- El motor debe seguir siendo puro y reproducible.
local fs = require("@lune/fs")

local FORBIDDEN = {
	"%f[%w_]game%f[^%w_]",
	"%f[%w_]workspace%f[^%w_]",
	"%f[%w_]script%f[^%w_]",
	"%f[%w_]Instance%f[^%w_]",
	"%f[%w_]task%f[^%w_]",
	"%f[%w_]Random%f[^%w_]",
	"%f[%w_]tick%f[^%w_]",
	"%f[%w_]wait%f[^%w_]",
	"%f[%w_]math%.random%f[^%w_]",
	"%f[%w_]os%.time%f[^%w_]",
	"%f[%w_]os%.clock%f[^%w_]",
}

local function stripCommentsAndStrings(source: string): string
	local result = string.gsub(source, "%-%-%[%[.-%]%]", "")
	result = string.gsub(result, "%-%-[^\n]*", "")
	result = string.gsub(result, '"[^"\n]*"', '""')
	return (string.gsub(result, "'[^'\n]*'", "''"))
end

local function pureRules(paths: { string }): { string }
	local offenders = {}
	for _, path in paths do
		local source = stripCommentsAndStrings(fs.readFile(path))
		for _, pattern in FORBIDDEN do
			if string.find(source, pattern) then
				table.insert(offenders, path)
				break
			end
		end
	end
	return offenders
end

return pureRules

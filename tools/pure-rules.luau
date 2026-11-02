--!nocheck
-- Devuelve los archivos que usan APIs de Roblox. El motor debe seguir siendo puro.
local fs = require("@lune/fs")

local FORBIDDEN = {
	"%f[%w_]game[%.:]",
	"%f[%w_]workspace%f[^%w_]",
	"%f[%w_]Instance%.",
	"%f[%w_]task%.",
	"%f[%w_]Random%.",
}

local function stripComments(source: string): string
	local withoutBlocks = string.gsub(source, "%-%-%[%[.-%]%]", "")
	return (string.gsub(withoutBlocks, "%-%-[^\n]*", ""))
end

local function pureRules(paths: { string }): { string }
	local offenders = {}
	for _, path in paths do
		local source = stripComments(fs.readFile(path))
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

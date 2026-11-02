--!nocheck
-- Ejecuta tests/**/*.spec.luau. Uso: lune run tests/run [filtro]
local fs = require("@lune/fs")
local process = require("@lune/process")

local Harness = require("./harness")

local ROOT = "tests"

local function collect(dir: string, relative: string, out: { string })
	local names = fs.readDir(dir)
	table.sort(names)
	for _, name in names do
		local path = `{dir}/{name}`
		local rel = if relative == "" then name else `{relative}/{name}`
		if fs.isDir(path) then
			collect(path, rel, out)
		elseif string.sub(name, -10) == ".spec.luau" then
			table.insert(out, string.sub(rel, 1, -6))
		end
	end
end

local filter = process.args[1]
local specs = {}
collect(ROOT, "", specs)

local loaded = 0
local loadErrors = {}
for _, spec in specs do
	if not filter or string.find(spec, filter, 1, true) then
		loaded += 1
		local ok, err = pcall(require, `./{spec}`)
		if not ok then
			table.insert(loadErrors, `{spec}: {err}`)
		end
	end
end

local passed, failures = Harness.results()

for _, failure in failures do
	print(`FAIL {failure.name}\n     {failure.message}`)
end
for _, message in loadErrors do
	print(`ERROR {message}`)
end
print(`{loaded} archivos, {passed} pasaron, {#failures} fallaron, {#loadErrors} errores de carga`)

if loaded == 0 then
	print("No hay pruebas que coincidan con el filtro")
	process.exit(1)
end
process.exit(if #failures > 0 or #loadErrors > 0 then 1 else 0)

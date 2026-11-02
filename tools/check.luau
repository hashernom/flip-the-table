--!nocheck
-- Comprobación global. Uso: lune run tools/check
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local pureRules = require("./pure-rules")

local RULES_DIR = "src/shared/rules"
local MANIFEST_PATH = "art/manifest.json"
local CODE_DIRS = { "src", "tests", "tools" }
-- src/server y src/client quedan fuera: la plataforma estándar es lo que garantiza que el
-- código compartido no use globales de Roblox. El plan 04 añade un segundo pase para ellos.
local PURE_DIRS = { "src/shared", "tests", "tools" }

local failed = {}

local function run(label: string, program: string, args: { string })
	local result = process.exec(program, args)
	if result.ok then
		print(`OK    {label}`)
	else
		print(`FALLA {label}\n{result.stdout}{result.stderr}`)
		table.insert(failed, label)
	end
end

local function luauFiles(dir: string, out: { string }): { string }
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			luauFiles(path, out)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, path)
		end
	end
	return out
end

run("Formato (StyLua)", "stylua", { "--check", table.unpack(CODE_DIRS) })
run("Lint (Selene)", "selene", CODE_DIRS)
run("Tipos (luau-lsp)", "luau-lsp", { "analyze", "--platform=standard", table.unpack(PURE_DIRS) })
run("Pruebas", "lune", { "run", "tests/run" })

local offenders = pureRules(luauFiles(RULES_DIR, {}))
if #offenders == 0 then
	print("OK    Motor puro")
else
	print(`FALLA Motor puro: usan APIs de Roblox:\n  {table.concat(offenders, "\n  ")}`)
	table.insert(failed, "Motor puro")
end

-- Manifiesto de assets: nada fuera de presupuesto y nada aprobado sin revisión en el juego.
local manifestOk, manifestErr = pcall(function()
	local Manifest = require("./manifest")
	local manifest = serde.decode("json", fs.readFile(MANIFEST_PATH))
	local problems = Manifest.validate(manifest)
	if #problems > 0 then
		error(`{table.concat(problems, "\n  ")}`, 0)
	end
end)
if manifestOk then
	print("OK    Manifiesto")
else
	print(`FALLA Manifiesto ({MANIFEST_PATH}):\n  {manifestErr}`)
	table.insert(failed, "Manifiesto")
end

if #failed > 0 then
	print(`\n{#failed} comprobaciones fallaron: {table.concat(failed, ", ")}`)
	process.exit(1)
end
print("\nTodo correcto")
process.exit(0)

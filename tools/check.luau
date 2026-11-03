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
-- Pase de Roblox: el servidor y el cliente sí usan globals del motor. Las definiciones están
-- fijadas en el repositorio (types/README.md) y el mapa lo genera Rojo.
local ROBLOX_DIRS = { "src/server", "src/client" }
local ROBLOX_DEFINITIONS = "types/globalTypes.d.lua"
local SOURCEMAP_PATH = "sourcemap.json"

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

-- ¿La carpeta tiene algún .luau, directo o en subcarpetas? luau-lsp sale con 1 si una ruta no
-- aporta ficheros, y src/client solo tiene .gitkeep hasta el plan 05.
local function hasLuauFiles(dir: string): boolean
	local ok, names = pcall(fs.readDir, dir)
	if not ok then
		return false
	end
	for _, name in names do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			if hasLuauFiles(path) then
				return true
			end
		elseif string.sub(name, -5) == ".luau" then
			return true
		end
	end
	return false
end

run("Formato (StyLua)", "stylua", { "--check", table.unpack(CODE_DIRS) })
run("Lint (Selene)", "selene", CODE_DIRS)
run("Tipos (luau-lsp)", "luau-lsp", { "analyze", "--platform=standard", table.unpack(PURE_DIRS) })
-- Paso 0 del plan 04: el servidor y el cliente usan globals de Roblox, así que se analizan aparte
-- con las definiciones del repositorio. El pase estándar de arriba no cambia. El sourcemap se
-- genera para el editor, pero no se pasa a luau-lsp: con --sourcemap, luau-lsp 1.70.1 resuelve los
-- require relativos contra el DataModel y `../../shared` no puede cruzar de ServerScriptService a
-- ReplicatedStorage (types/README.md lo explica). Sin él los resuelve por ruta de archivo, igual
-- que Lune, y las definiciones de Roblox siguen cargadas.
run("Mapa de Rojo", "rojo", { "sourcemap", "default.project.json", "--output", SOURCEMAP_PATH })
local robloxDirs = {}
for _, dir in ROBLOX_DIRS do
	if hasLuauFiles(dir) then
		table.insert(robloxDirs, dir)
	end
end
if #robloxDirs > 0 then
	run("Tipos de Roblox (luau-lsp)", "luau-lsp", {
		"analyze",
		"--platform=roblox",
		`--definitions={ROBLOX_DEFINITIONS}`,
		table.unpack(robloxDirs),
	})
else
	print("OK    Tipos de Roblox (luau-lsp): sin código de servidor ni cliente")
end
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

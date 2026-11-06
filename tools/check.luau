--!nocheck
-- Comprobación global. Uso: lune run tools/check
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local clockRules = require("./clock-rules")
local pureRules = require("./pure-rules")

local RULES_DIR = "src/shared/rules"
local MATCH_DIR = "src/server/match"
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
-- Segundo proyecto (R-P11): el lugar del lobby tiene su propia profundidad de árbol. Sin un
-- sourcemap propio, un `require` relativo mal montado se resuelve contra el mapa del lugar de
-- partida y el pase de tipos no ve el fallo; `rojo build` tampoco lo ve, porque solo empaqueta.
local LOBBY_SOURCEMAP_PATH = "sourcemap-lobby.json"
local LOBBY_PROJECT = "lobby.project.json"
local LOBBY_DIR = "src/server/lobby"

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
-- con las definiciones del repositorio y el sourcemap de Rojo. default.project.json monta
-- src/shared como `shared` (minúsculas) bajo ServerScriptService y StarterPlayerScripts, además de
-- ReplicatedStorage.Shared: así la misma ruta `../../shared/...` resuelve igual en disco, en Lune y
-- en el DataModel (R-P17). El pase estándar de arriba no cambia.
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
		`--sourcemap={SOURCEMAP_PATH}`,
		table.unpack(robloxDirs),
	})
else
	print("OK    Tipos de Roblox (luau-lsp): sin código de servidor ni cliente")
end
-- Pase del lobby contra SU proyecto: es donde se comprueba que `../../shared/...` resuelve con la
-- profundidad del DataModel del lobby y no con la del lugar de partida.
run("Mapa de Rojo (lobby)", "rojo", { "sourcemap", LOBBY_PROJECT, "--output", LOBBY_SOURCEMAP_PATH })
if hasLuauFiles(LOBBY_DIR) then
	run("Tipos de Roblox del lobby (luau-lsp)", "luau-lsp", {
		"analyze",
		"--platform=roblox",
		`--definitions={ROBLOX_DEFINITIONS}`,
		`--sourcemap={LOBBY_SOURCEMAP_PATH}`,
		LOBBY_DIR,
		-- El cliente del lobby solo existe en ese lugar: se comprueba con su mapa.
		"src/client/lobby.client.luau",
	})
else
	print("OK    Tipos de Roblox del lobby (luau-lsp): sin código de lobby")
end
run("Pruebas", "lune", { "run", "tests/run" })

local offenders = pureRules(luauFiles(RULES_DIR, {}))
if #offenders == 0 then
	print("OK    Motor puro")
else
	print(`FALLA Motor puro: usan APIs de Roblox:\n  {table.concat(offenders, "\n  ")}`)
	table.insert(failed, "Motor puro")
end

-- R-P38: el reloj de la partida es uno solo; `time()` no se compara entre el servidor y el cliente.
local clockOffenders = clockRules.offenders(MATCH_DIR)
if #clockOffenders == 0 then
	print("OK    Reloj de la partida")
else
	print(`FALLA Reloj de la partida: usan time():\n  {table.concat(clockOffenders, "\n  ")}`)
	table.insert(failed, "Reloj de la partida")
end

-- Manifiesto de assets: nada fuera de presupuesto y nada aprobado sin revisión en el juego.
local manifestOk, manifestErr = pcall(function()
	local Manifest = require("./manifest")
	local manifest = serde.decode("json", fs.readFile(MANIFEST_PATH))
	local problems = Manifest.validate(manifest)
	for _, path in luauFiles("src", {}) do
		for _, problem in Manifest.sourceProblems(manifest, path, fs.readFile(path)) do
			table.insert(problems, problem)
		end
	end
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

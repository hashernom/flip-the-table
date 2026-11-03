--!nocheck
-- Informe de los criterios de salida de la ficha. Uso: lune run tools/criteria-report [ruta.json]
--
-- Lee el JSON exportado por la telemetría del servidor (la última línea de la salida del servidor,
-- que es un arreglo JSON desnudo, sin prefijo) y calcula, solo con partidas en modo Rondas, los
-- cuatro criterios medibles: partidas terminadas, segunda partida, duración y líder a mitad de
-- partida. La duración se mide solo con partidas de 4 a 8 jugadores (alcance de la ficha) y el
-- líder solo con las que tienen líder conocido; cada línea dice el tamaño de su muestra. El cálculo
-- vive en `MatchSummary.report`, que es puro y se prueba con Lune (R-P15); esta herramienta solo lee
-- e imprime.
--
-- Sin argumento lee `telemetry/summaries.json`. No inventa datos: si el archivo no está, lo dice y
-- sale con 1.
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local MatchSummary = require("../src/server/match/MatchSummary")

local DEFAULT_PATH = "telemetry/summaries.json"
local path = process.args[1] or DEFAULT_PATH

if not fs.isFile(path) then
	print(`No hay resúmenes exportados en {path}.`)
	print(
		"Cada partida deja una etiqueta y, debajo, el arreglo JSON desnudo; guarda esa última línea como JSON."
	)
	process.exit(1)
end

local ok, decoded = pcall(function()
	return serde.decode("json", fs.readFile(path))
end)
if not ok or type(decoded) ~= "table" then
	print(`El archivo {path} no es un arreglo JSON de resúmenes.`)
	process.exit(1)
end

-- Un resumen con la forma equivocada daría un informe engañoso: se rechaza en vez de sumarlo. Se
-- exige además que el JSON sea un arreglo (claves 1..n), porque un objeto suelto se recorrería como
-- si sus valores fueran partidas.
local entries = 0
for key in decoded do
	if type(key) ~= "number" then
		print(`El archivo {path} no es un arreglo JSON de resúmenes.`)
		process.exit(1)
	end
	entries += 1
end
if entries ~= #decoded then
	print(`El archivo {path} no es un arreglo JSON de resúmenes.`)
	process.exit(1)
end
for index, summary in decoded do
	if type(summary) ~= "table" then
		print(`El resumen {index} de {path} no es una tabla.`)
		process.exit(1)
	end
end

local reportOk, report = pcall(MatchSummary.report, decoded)
if not reportOk then
	print(`No se pudo calcular el informe de {path}: {report}`)
	process.exit(1)
end

local function percentage(part, whole)
	if whole == 0 then
		return "sin datos"
	end
	return string.format("%.1f %%", part / whole * 100)
end

local function plural(count, singular, many)
	if count == 1 then
		return `1 {singular}`
	end
	return `{count} {many}`
end

print("Informe de criterios de salida — Flip the Table")
print(
	string.format(
		"Resúmenes exportados: %d (%d en modo Rondas, %d en Sin Fin ignoradas).",
		#decoded,
		report.matches,
		report.ignored
	)
)
print("")
print(
	string.format(
		"Partidas terminadas: %s (%d de %d).",
		percentage(report.finished, report.matches),
		report.finished,
		report.matches
	)
)
print(
	string.format(
		"Segunda partida:     %s (%s entre %s).",
		percentage(report.rematches, report.firstMatches),
		plural(report.rematches, "revancha", "revanchas"),
		plural(report.firstMatches, "primera partida", "primeras partidas")
	)
)
if report.durationSamples == 0 then
	print("Duración media:      sin datos (ninguna partida terminada de 4 a 8 jugadores).")
else
	print(
		string.format(
			"Duración media:      %.1f min (%.0f s) en %s de 4 a 8 jugadores.",
			report.averageDurationSec / 60,
			report.averageDurationSec,
			plural(report.durationSamples, "partida terminada", "partidas terminadas")
		)
	)
end
if report.leaderSamples == 0 then
	print("Líder a mitad:       sin datos (ninguna partida terminada con líder conocido).")
else
	print(
		string.format(
			"Líder a mitad:       %s (%d de %d partidas con líder conocido).",
			percentage(report.leadersWon, report.leaderSamples),
			report.leadersWon,
			report.leaderSamples
		)
	)
end

process.exit(0)

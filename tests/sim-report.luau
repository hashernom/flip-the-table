--!strict
-- Informe de la simulación (Tarea 10). Uso: lune run tests/sim-report
--
-- Juega una muestra de la matriz (no las 14 000 partidas) y resume, por tamaño de tablero, la
-- tasa de victoria del líder a mitad de partida, los turnos medios y el uso de cada carta y cada
-- perk. Es el documento que lee el responsable y también una puerta: si una carta o un perk quedan
-- sin usar, el comando falla con la lista de los que faltan.
local Boards = require("../src/shared/config/Boards")
local CardsConfig = require("../src/shared/config/Cards")
local PerksConfig = require("../src/shared/config/Perks")
local Sim = require("./sim")
local Types = require("../src/shared/rules/Types")

-- Muestra del informe. La matriz completa (14 000 partidas) la cubre tests/sim.spec; aquí se
-- busca un informe legible en menos de un minuto. Cada tamaño juega sus recuentos de jugadores y
-- los dos modos con las mismas semillas.
local SEED_COUNT = 50

local PLAYER_COUNTS: { number } = { 2, 3, 4, 5, 6, 7, 8 }
-- Tipados antes de entrar en la lista: un literal de tabla ensancha los textos a `string`.
local SIZE_S: Types.SizeId = "S"
local SIZE_M: Types.SizeId = "M"
local SIZE_L: Types.SizeId = "L"
local SIZE_ORDER: { Types.SizeId } = { SIZE_S, SIZE_M, SIZE_L }
local ROUNDS: Types.EndMode = "Rounds"
local ENDLESS: Types.EndMode = "Endless"
local MODES: { Types.EndMode } = { ROUNDS, ENDLESS }
local SIZE_LABEL: { [Types.SizeId]: string } = {
	S = "S (2 a 4 jugadores)",
	M = "M (5 y 6 jugadores)",
	L = "L (7 y 8 jugadores)",
}

type ModeSummary = {
	matches: number,
	leaderWon: number,
	turns: number,
	unfinished: number,
}

type SizeSummary = {
	cards: { [string]: number },
	perks: { [string]: number },
	modes: { [Types.EndMode]: ModeSummary },
	matches: number,
	unfinished: number,
}

local function newModeSummary(): ModeSummary
	return { matches = 0, leaderWon = 0, turns = 0, unfinished = 0 }
end

local function newSizeSummary(): SizeSummary
	return {
		cards = {},
		perks = {},
		modes = { Rounds = newModeSummary(), Endless = newModeSummary() },
		matches = 0,
		unfinished = 0,
	}
end

local function addCounts(target: { [string]: number }, source: { [string]: number })
	for key, count in source do
		target[key] = (target[key] or 0) + count
	end
end

local summaries: { [Types.SizeId]: SizeSummary } = {}
for sizeIndex = 1, #SIZE_ORDER do
	local sizeId: Types.SizeId = SIZE_ORDER[sizeIndex]
	summaries[sizeId] = newSizeSummary()
end

-- Reparte los recuentos de jugadores por tamaño con la misma regla que el motor.
local playersBySize: { [Types.SizeId]: { number } } = { S = {}, M = {}, L = {} }
for _, players in PLAYER_COUNTS do
	local sizeId: Types.SizeId = Boards.forPlayerCount(players)
	table.insert(playersBySize[sizeId], players)
end

local totalMatches = 0
local allCards: { [string]: number } = {}
local allPerks: { [string]: number } = {}
for sizeIndex = 1, #SIZE_ORDER do
	local sizeId: Types.SizeId = SIZE_ORDER[sizeIndex]
	local summary = summaries[sizeId]
	for _, players in playersBySize[sizeId] do
		for modeIndex = 1, #MODES do
			local mode: Types.EndMode = MODES[modeIndex]
			local modeSummary = summary.modes[mode]
			for seed = 1, SEED_COUNT do
				local opts: Sim.PlayOptions = { players = players, seed = seed, endMode = mode }
				local result = Sim.play(opts)
				totalMatches += 1
				summary.matches += 1
				modeSummary.matches += 1
				if result.finished then
					modeSummary.turns += result.turns
					if result.leaderAtHalfWon then
						modeSummary.leaderWon += 1
					end
				else
					modeSummary.unfinished += 1
					summary.unfinished += 1
				end
				addCounts(summary.cards, result.cardsPlayed)
				addCounts(allCards, result.cardsPlayed)
				-- La columna de perks mide efectos aplicados de verdad, no repartos del borrador.
				addCounts(summary.perks, result.perkUses)
				addCounts(allPerks, result.perkUses)
			end
		end
	end
end

local function percentage(part: number, whole: number): string
	if whole == 0 then
		return "0.0"
	end
	return string.format("%.1f", part / whole * 100)
end

local function average(total: number, count: number): string
	if count == 0 then
		return "0.0"
	end
	return string.format("%.1f", total / count)
end

print("Informe de la simulación — Flip the Table, plan 03 (premios y dinámicas)")
print(
	string.format(
		"Muestra: %d semillas × %d tamaños × %d recuentos de jugadores × 2 modos = %d partidas (la matriz completa tiene %d).",
		SEED_COUNT,
		#SIZE_ORDER,
		#PLAYER_COUNTS,
		totalMatches,
		#PLAYER_COUNTS * 2 * 1000
	)
)

local zeroCards: { string } = {}
local zeroPerks: { string } = {}
for _, card in CardsConfig.all do
	if (allCards[card.id] or 0) == 0 then
		table.insert(zeroCards, card.id)
	end
end
for _, perk in PerksConfig.all do
	if (allPerks[perk.id] or 0) == 0 then
		table.insert(zeroPerks, perk.id)
	end
end

for sizeIndex = 1, #SIZE_ORDER do
	local sizeId: Types.SizeId = SIZE_ORDER[sizeIndex]
	local summary = summaries[sizeId]
	print("")
	print(string.format("Tamaño %s — %d partidas", SIZE_LABEL[sizeId], summary.matches))
	for modeIndex = 1, #MODES do
		local mode: Types.EndMode = MODES[modeIndex]
		local modeSummary = summary.modes[mode]
		local finished = modeSummary.matches - modeSummary.unfinished
		print(
			string.format(
				"  %-8s %4d partidas · líder a mitad ganó %5s %% · turnos medios %7s",
				mode,
				modeSummary.matches,
				percentage(modeSummary.leaderWon, finished),
				average(modeSummary.turns, finished)
			)
		)
	end
	if summary.unfinished > 0 then
		print(string.format("  AVISO: %d partidas no terminaron (tope de seguridad).", summary.unfinished))
	end

	print("  Cartas (usos en todas las partidas del tamaño):")
	for _, card in CardsConfig.all do
		local count = summary.cards[card.id] or 0
		print(string.format("    %-22s %-24s %6d", card.id, card.name, count))
	end
	print("  Perks (usos reales de cada efecto):")
	for _, perk in PerksConfig.all do
		local count = summary.perks[perk.id] or 0
		print(string.format("    %-22s %-24s %6d", perk.id, perk.name, count))
	end
end

print("")
if #zeroCards == 0 and #zeroPerks == 0 then
	print("Cobertura: las 20 cartas y los 12 perks se usaron al menos una vez en la muestra.")
else
	if #zeroCards > 0 then
		print(`Cartas sin usar en la muestra: {table.concat(zeroCards, ", ")}`)
	end
	if #zeroPerks > 0 then
		print(`Perks sin aplicar en la muestra: {table.concat(zeroPerks, ", ")}`)
	end
end

-- La cobertura es una puerta, no solo una columna del informe: una carta o un perk sin usar es
-- una regresión y el comando que nombra el plan debe fallar. Sin ceros, el comando sale con 0.
local uncovered: { string } = {}
for _, cardId in zeroCards do
	table.insert(uncovered, `carta {cardId}`)
end
for _, perkId in zeroPerks do
	table.insert(uncovered, `perk {perkId}`)
end
if #uncovered > 0 then
	error(`Cobertura incompleta en la muestra: {table.concat(uncovered, ", ")}`, 2)
end

-- Un tope de seguridad alcanzado invalida el informe: la matriz tampoco pasaría. Falla con un
-- mensaje que dice cuántas partidas no terminaron.
local unfinished = 0
for sizeIndex = 1, #SIZE_ORDER do
	local sizeId: Types.SizeId = SIZE_ORDER[sizeIndex]
	unfinished += summaries[sizeId].unfinished
end
if unfinished > 0 then
	error(`El informe encontró {unfinished} partidas sin terminar; revisa la simulación.`, 2)
end

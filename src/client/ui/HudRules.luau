--!strict
-- Reglas puras del HUD. No crean ni tocan `Instance`, así que se prueban con Lune: cuánto mide cada placa
-- de la mesa, cómo se escribe el dinero, por dónde va el plazo y qué tinta se lee sobre un color.
local Ui = require("../../shared/config/Ui")

export type Tier = {
	upTo: number,
	plateHeight: number,
	step: number,
	disc: number,
	name: number,
	money: number,
	arrow: number,
}

export type Slot = { y: number, height: number, isTurn: boolean }

export type Deadline = { progress: number, seconds: number, warn: boolean }

local HudRules = {}

-- Tamaño de las placas según cuántos jugadores haya en la mesa.
function HudRules.tierFor(count: number): Tier
	local tiers = Ui.plateTiers
	if count <= tiers.large.upTo then
		return tiers.large
	elseif count <= tiers.normal.upTo then
		return tiers.normal
	end
	return tiers.compact
end

-- Sitio de cada placa en la columna, de arriba abajo. La del turno es una flecha más alta. Sin turno,
-- como al acabar la partida, ninguna lo es.
function HudRules.slots(count: number, turnIndex: number?): { Slot }
	local tier = HudRules.tierFor(count)
	local arrowGap = tier.step - tier.plateHeight
	local slots: { Slot } = {}
	local y = Ui.plateColumnTop
	for index = 1, count do
		local isTurn = index == turnIndex
		local height = if isTurn then tier.arrow else tier.plateHeight
		table.insert(slots, { y = y, height = height, isTurn = isTurn })
		y += height + arrowGap
	end
	return slots
end

-- Ancho común de las placas: el del contenido más largo, acotado. Todas iguales, para que la columna se
-- lea como una sola pieza y un nombre muy largo no se coma la ciudad.
function HudRules.columnWidth(contentWidths: { number }): number
	local widest = Ui.plateMinWidth
	for _, width in contentWidths do
		widest = math.max(widest, math.ceil(width))
	end
	return math.min(widest, Ui.plateMaxWidth)
end

-- Dinero con punto de miles, como pide la guía. El signo es el de resta, no un guion.
function HudRules.formatMoney(amount: number): string
	local digits = tostring(math.abs(math.floor(amount)))
	local grouped = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1.")))
	if string.sub(grouped, 1, 1) == "." then
		grouped = string.sub(grouped, 2)
	end
	return if amount < 0 then `−{grouped}` else grouped
end

-- Valor que enseña el taxímetro en un punto de su recorrido, de 0 a 1. Siempre un entero, y siempre
-- termina exactamente en el valor nuevo.
function HudRules.rollValue(from: number, to: number, alpha: number): number
	if alpha >= 1 then
		return to
	elseif alpha <= 0 then
		return from
	end
	local value = from + (to - from) * alpha
	return if to >= from then math.floor(value) else math.ceil(value)
end

-- Estado de la calzada del plazo: cuánto ha recorrido el vehículo, los segundos que se enseñan y si
-- toca avisar. Los relojes de dos máquinas pueden diferir, así que se acota.
function HudRules.deadline(remaining: number, total: number): Deadline
	local seconds = math.max(0, math.ceil(remaining))
	local progress = if total > 0 then math.clamp(1 - remaining / total, 0, 1) else 1
	return { progress = progress, seconds = seconds, warn = seconds <= Ui.deadlineWarnSeconds }
end

local function channel(value: number): number
	local unit = value / 255
	return if unit <= 0.03928 then unit / 12.92 else ((unit + 0.055) / 1.055) ^ 2.4
end

local function luminance(hex: string): number
	local r = tonumber(string.sub(hex, 2, 3), 16) :: number
	local g = tonumber(string.sub(hex, 4, 5), 16) :: number
	local b = tonumber(string.sub(hex, 6, 7), 16) :: number
	return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
end

-- Contraste WCAG entre dos colores `#RRGGBB`.
function HudRules.contrast(a: string, b: string): number
	local la, lb = luminance(a), luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

-- Tinta de la paleta que mejor se lee sobre un color, como el bloque de zona de una escritura.
function HudRules.inkFor(background: string): "limestone" | "asphalt"
	local onLight = HudRules.contrast(background, Ui.palette.limestone)
	local onDark = HudRules.contrast(background, Ui.palette.asphalt)
	return if onLight >= onDark then "limestone" else "asphalt"
end

-- Escala de toda la interfaz. Crece con la pantalla, pero nunca encoge por debajo de lo diseñado.
function HudRules.scaleFor(width: number, height: number): number
	local reference = Ui.referenceViewport
	local fit = math.min(width / reference.x, height / reference.y)
	return math.clamp(fit, 1, Ui.maxUiScale)
end

return HudRules

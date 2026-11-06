--!strict
-- Reglas puras de la animación de la Cartelera: por qué salidas pasa el marco y en qué instante. El marco da
-- unas vueltas por las cinco salidas, cada vez más despacio, y se para justo en la que ha salido. El motor ya
-- decidió el resultado: esto solo reparte el suspense en el tiempo. Sin Instance, para probarlo con Lune.
local Ui = require("../../shared/config/Ui")

export type Tick = { index: number, at: number }

local BillboardRules = {}

-- Pasos del marco hasta pararse en `landed`, de `count` salidas, en `settleSec` segundos. El avance sigue una
-- curva de salida (rápido al principio, lento al final), así que los huecos entre pasos crecen siempre. El
-- último paso es la salida ganadora y llega exactamente en `settleSec`.
function BillboardRules.schedule(landed: number, count: number, settleSec: number): { Tick }
	local config = Ui.billboard
	local total = config.laps * count + landed
	local ticks: { Tick } = {}
	for step = 1, total do
		local progress = step / total
		-- Inversa de 1 - (1 - t)^power: el instante en el que la curva llega a este paso.
		local at = settleSec * (1 - (1 - progress) ^ (1 / config.easePower))
		table.insert(ticks, { index = (step - 1) % count + 1, at = at })
	end
	return ticks
end

-- Tono de la salida al pararse. Un premio brilla en amarillo, la multa en rojo, la carta en papel y la nada
-- se queda apagada (y la pantalla se burla con un meneo).
function BillboardRules.toneFor(result: string): string
	if result == "BigPrize" or result == "SmallPrize" then
		return "Prize"
	elseif result == "Fine" then
		return "Fine"
	elseif result == "Card" then
		return "Card"
	end
	return "Nothing"
end

return BillboardRules

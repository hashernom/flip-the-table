--!strict
-- Configuración de una partida privada: lo que el anfitrión elige al crearla en el lobby. Es el único sitio
-- con las opciones, sus valores posibles y sus valores por defecto. La interfaz del lobby pinta esta tabla,
-- el servidor del lobby y el de la partida la validan con `normalize`, y el motor la lee del estado.
--
-- Ninguna opción permite apostar ni pagar por ventaja: solo cambian el ritmo y las reglas de la mesa para
-- todo el grupo por igual. Las partidas públicas usan siempre los valores por defecto.
local Economy = require("./Economy")

export type Settings = {
	startingCash: number,
	startBonus: number,
	-- Duración del modo Rondas: "Short", "Normal" o "Long". En Sin Fin no cuenta.
	length: string,
	auctions: boolean,
	perks: boolean,
	hotZone: boolean,
}

export type Choice = { value: any, label: string }

export type Option = {
	id: string,
	label: string,
	help: string,
	-- "toggle" (sí / no) o "choice" (uno de `choices`).
	kind: string,
	choices: { Choice }?,
	-- Solo en el modo Rondas.
	roundsOnly: boolean?,
}

local MatchSettings = {}

MatchSettings.DEFAULTS = {
	startingCash = Economy.startingCash,
	startBonus = Economy.startBonus,
	length = "Normal",
	auctions = true,
	perks = true,
	hotZone = true,
} :: Settings

-- Multiplicador de las rondas de `Economy.rounds` según la duración elegida.
MatchSettings.LENGTH_FACTOR = { Short = 0.6, Normal = 1, Long = 1.5 } :: { [string]: number }

-- Orden en que aparecen en el lobby.
MatchSettings.OPTIONS = {
	{
		id = "startingCash",
		label = "Dinero inicial",
		help = "Con cuánto empieza cada jugador.",
		kind = "choice",
		choices = {
			{ value = 1000, label = "1000" },
			{ value = 1500, label = "1500" },
			{ value = 2000, label = "2000" },
			{ value = 2500, label = "2500" },
		},
	},
	{
		id = "startBonus",
		label = "Paso por la Salida",
		help = "Lo que se cobra al pasar por la Salida.",
		kind = "choice",
		choices = {
			{ value = 100, label = "100" },
			{ value = 200, label = "200" },
			{ value = 300, label = "300" },
		},
	},
	{
		id = "length",
		label = "Duración",
		help = "Cuántas rondas dura la partida en el modo Rondas.",
		kind = "choice",
		roundsOnly = true,
		choices = {
			{ value = "Short", label = "Corta" },
			{ value = "Normal", label = "Normal" },
			{ value = "Long", label = "Larga" },
		},
	},
	{
		id = "auctions",
		label = "Subastas",
		help = "Si nadie compra una propiedad, se subasta. Sin subastas, se queda libre.",
		kind = "toggle",
	},
	{
		id = "perks",
		label = "Perks",
		help = "Elegir perks en los momentos de la partida.",
		kind = "toggle",
	},
	{
		id = "hotZone",
		label = "Zona Caliente",
		help = "Una zona cobra más renta y cambia cada pocas rondas.",
		kind = "toggle",
	},
} :: { Option }

local byId: { [string]: Option } = {}
for _, option in MatchSettings.OPTIONS do
	byId[option.id] = option
end
MatchSettings.byId = byId

-- Configuración de una partida en curso. Un estado sin configuración (pruebas, partidas antiguas) usa la
-- de por defecto.
function MatchSettings.of(state: any): Settings
	local settings = if type(state) == "table" then state.settings else nil
	return if settings ~= nil then settings else MatchSettings.DEFAULTS
end

-- Valores posibles de una opción de elección (vacío en un sí / no).
function MatchSettings.choicesOf(option: Option): { Choice }
	return option.choices or {}
end

-- Una copia nueva con los valores por defecto.
function MatchSettings.defaults(): Settings
	return table.clone(MatchSettings.DEFAULTS)
end

-- Configuración válida a partir de lo que llegue de fuera (cliente, teleport o un dato viejo): cada valor
-- desconocido o de otro tipo vuelve al de por defecto. Nunca falla.
function MatchSettings.normalize(raw: any): Settings
	local settings = MatchSettings.defaults()
	if type(raw) ~= "table" then
		return settings
	end
	for _, option in MatchSettings.OPTIONS do
		local value = raw[option.id]
		if option.kind == "toggle" then
			if type(value) == "boolean" then
				(settings :: any)[option.id] = value
			end
		else
			for _, choice in MatchSettings.choicesOf(option) do
				if choice.value == value then
					(settings :: any)[option.id] = value
					break
				end
			end
		end
	end
	return settings
end

-- Rondas del modo Rondas con la duración elegida (nunca menos de 4, para que haya Última Ronda).
function MatchSettings.maxRounds(base: number, settings: Settings): number
	local factor = MatchSettings.LENGTH_FACTOR[settings.length] or 1
	return math.max(4, math.floor(base * factor + 0.5))
end

-- Si una configuración es la de por defecto (para no enseñar nada en una partida normal).
function MatchSettings.isDefault(settings: Settings): boolean
	for key, value in MatchSettings.DEFAULTS :: any do
		if (settings :: any)[key] ~= value then
			return false
		end
	end
	return true
end

return MatchSettings

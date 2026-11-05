--!strict
-- Nombres y colores de la ciudad. Es el contenido que hace reconocible cada casilla desde la
-- calle: nombre y color de la zona, nombre de cada propiedad y etiqueta de cada casilla especial.
-- La fuente de verdad es docs/02-mvp/contenido-tablero.md; aquí solo se copia para que el cliente
-- no dependa de un documento. Los colores son cadenas `#RRGGBB` porque `Color3` es de Roblox y esta
-- carpeta se analiza con la plataforma estándar; el cliente los convierte al construir.
local Types = require("../rules/Types")

type SquareKind = Types.SquareKind

export type Zone = {
	name: string,
	barrio: string,
	color: string,
	properties: number,
	-- Nombres de las propiedades en el orden de su zona. El ordinal de la casilla elige uno.
	names: { string },
}

local ZONES: { [string]: Zone } = {
	cobre = {
		name = "Callejón del Cobre",
		barrio = "Centro",
		color = "#C97B3A",
		properties = 2,
		names = { "Barbería Morro", "Callejón del Hojalatero" },
	},
	cian = {
		name = "Pasaje Cian",
		barrio = "Centro",
		color = "#22D3EE",
		properties = 3,
		names = { "Pasaje Burbuja", "Calle del Cable", "Caldas" },
	},
	magenta = {
		name = "Bulevar Magenta",
		barrio = "Centro",
		color = "#E85D9E",
		properties = 3,
		names = { "Centro Páez", "Neo Mundo", "Plaza del Neón" },
	},
	naranja = {
		name = "Feria Naranja",
		barrio = "Centro",
		color = "#F59E0B",
		properties = 3,
		names = { "Mercado de la Séptima", "llaneradas.com", "Calle del Azafrán" },
	},
	carmesi = {
		name = "Distrito Carmesí",
		barrio = "Centro",
		color = "#DC2626",
		properties = 3,
		names = { "Plaza del Jazz", "Cine Lux", "Bodega La Reserva" },
	},
	limon = {
		name = "Paseo Limón",
		barrio = "Centro",
		color = "#FACC15",
		properties = 3,
		names = { "Vereda La Mata", "Villa Margarita", "Panadería La Espiga" },
	},
	esmeralda = {
		name = "Dársena Esmeralda",
		barrio = "Puerto",
		color = "#10B981",
		properties = 3,
		names = { "Muelle de los Pescadores", "Astillero Neptuno", "Acuario La Sirena" },
	},
	violeta = {
		name = "Muelle Violeta",
		barrio = "Puerto",
		color = "#8B5CF6",
		properties = 2,
		names = { "Versalles 1", "Versalles 2" },
	},
	anil = {
		name = "Mirador Añil",
		barrio = "ZonaAlta",
		color = "#4F46E5",
		properties = 3,
		names = { "Observatorio Cerro Azul", "D.T", "Torres de Aragón" },
	},
	blanca = {
		name = "Cumbre Blanca",
		barrio = "ZonaAlta",
		color = "#E7E5E4",
		properties = 3,
		names = { "Tajamar", "Cacique", "Monviso" },
	},
	grafito = {
		name = "Distrito Grafito",
		barrio = "Industrial",
		color = "#64748B",
		properties = 3,
		names = { "Fundición Vulcano", "Chatarrería El Imán", "Estación de Metrolínea" },
	},
	ocre = {
		name = "Sector Ocre",
		barrio = "Industrial",
		color = "#A16207",
		properties = 3,
		names = { "Almacén El Ladrillo", "Curtiembre Los Nogales", "Fábrica de Ladrillos La Hormiga" },
	},
}

-- Etiqueta corta de cada tipo de casilla. Es lo que se lee en el rótulo de la calle y en la vista
-- general; el nombre largo de la casilla de propiedad sale de su zona.
local KINDS: { [SquareKind]: string } = {
	Start = "Salida",
	Property = "Propiedad",
	Spin = "Giro",
	Market = "Mercado Negro",
	Duel = "Duelo",
	Portal = "Portal",
	Billboard = "Cartelera",
	Tribunal = "Tribunal",
	Tax = "Impuesto",
}

-- Color de cada casilla especial, también en `#RRGGBB`. Las propiedades usan el color de su zona.
local KIND_COLORS: { [SquareKind]: string } = {
	Start = "#16A34A",
	Property = "#9CA3AF",
	Spin = "#0EA5E9",
	Market = "#7C3AED",
	Duel = "#EF4444",
	Portal = "#06B6D4",
	Billboard = "#EAB308",
	Tribunal = "#1D4ED8",
	Tax = "#B91C1C",
}

-- Premios del final y jugadas del Duelo, en español. Los ids son los del motor (Awards y Squares).
local AWARDS: { [string]: string } = {
	MostTreacherous = "Mayor Traidor",
	BestComeback = "Mejor Remontada",
	VictimOfTheNight = "Víctima de la Noche",
}

local DUEL_CHOICES: { [string]: string } = {
	Rock = "Piedra",
	Paper = "Papel",
	Scissors = "Tijera",
}

local TOKENS: { [string]: string } = {
	taxi = "Taxi",
	limusina = "Limusina",
	moto = "Moto",
	deportivo = "Deportivo",
	["food-truck"] = "Food truck",
	["camion-helados"] = "Camión de helados",
	grua = "Grúa",
	autobus = "Autobús",
}

local Strings = {}

-- Nombre del barrio, que es la agrupación de zonas que la ciudad muestra en la calle.
Strings.BARRIOS = {
	Centro = "Centro",
	Puerto = "Puerto",
	ZonaAlta = "Zona Alta",
	Industrial = "Industrial",
}

function Strings.zone(zoneId: string): Zone
	local zone = ZONES[zoneId]
	if zone == nil then
		error(`Strings: la zona {zoneId} no tiene nombre ni color`, 2)
	end
	return zone
end

-- Nombre de la enésima propiedad de una zona. El ordinal lo da el propio tablero: la primera
-- propiedad de la zona es la 1.
function Strings.property(zoneId: string, ordinal: number): string
	local zone = Strings.zone(zoneId)
	local name = zone.names[ordinal]
	if name == nil then
		error(`Strings: la zona {zoneId} no tiene una propiedad {ordinal}`, 2)
	end
	return name
end

-- Nombre de una ficha. Un id desconocido se devuelve tal cual: debe verse feo, no romper el aviso.
function Strings.token(tokenId: string): string
	return TOKENS[tokenId] or tokenId
end

function Strings.kind(kind: SquareKind): string
	local label = KINDS[kind]
	if label == nil then
		error(`Strings: el tipo de casilla {tostring(kind)} no tiene etiqueta`, 2)
	end
	return label
end

-- Color `#RRGGBB` de una casilla: el de su zona si es propiedad y el de su tipo si no.
function Strings.colorFor(square: Types.Square): string
	if square.kind == "Property" and square.zoneId ~= nil then
		return Strings.zone(square.zoneId :: string).color
	end
	local color = KIND_COLORS[square.kind]
	if color == nil then
		error(`Strings: el tipo de casilla {tostring(square.kind)} no tiene color`, 2)
	end
	return color
end

-- Rótulo de una casilla. `ordinal` es su número de propiedad dentro de la zona, que `CityLayout`
-- calcula; para las casillas especiales no hace falta.
function Strings.squareLabel(square: Types.Square, ordinal: number?): string
	if square.kind == "Property" then
		local zoneId = square.zoneId
		if zoneId == nil then
			return Strings.kind("Property")
		end
		local zone = Strings.zone(zoneId)
		local position = ordinal or 1
		-- El ordinal llega dado por quien recorre el tablero; si no, se usa el primero de la zona,
		-- que siempre existe y evita romper la etiqueta de la calle.
		if zone.names[position] == nil then
			position = 1
		end
		return zone.names[position]
	end
	return Strings.kind(square.kind)
end

-- Nombre de un premio del podio. Un id desconocido se devuelve tal cual: un premio nuevo sin nombre
-- debe verse feo, no romper la pantalla final.
function Strings.award(awardId: string): string
	return AWARDS[awardId] or awardId
end

-- Nombre de una jugada del Duelo (Piedra, Papel o Tijera).
function Strings.duelChoice(choiceId: string): string
	return DUEL_CHOICES[choiceId] or choiceId
end

-- Nombre del barrio para la interfaz. Un barrio desconocido devuelve su identificador: se prefiere
-- un rótulo feo a un error en mitad de una partida.
function Strings.barrio(barrioId: string): string
	return Strings.BARRIOS[barrioId] or barrioId
end

-- Nombre de un nivel de construcción, como lo dice `contenido-tablero.md`.
local BUILDING_LEVELS = { "Sin mejoras", "1 casa", "2 casas", "3 casas", "Hotel", "Rascacielos" }

function Strings.buildingLevel(level: number): string
	return BUILDING_LEVELS[level + 1] or `Nivel {level}`
end

return Strings

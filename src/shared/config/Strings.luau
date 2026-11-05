--!strict
-- Nombres y colores de la ciudad. Es el contenido que hace reconocible cada casilla desde la
-- calle: nombre y color de la zona, nombre de cada propiedad y etiqueta de cada casilla especial.
-- La fuente de verdad es docs/02-mvp/contenido-tablero.md; aquí solo se copia para que el cliente
-- no dependa de un documento. Los colores son cadenas `#RRGGBB` porque `Color3` es de Roblox y esta
-- carpeta se analiza con la plataforma estándar; el cliente los convierte al construir.
local Cards = require("./Cards")
local Perks = require("./Perks")
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

-- Efecto de cada carta, como lo dice la ficha. El nombre vive en `Cards`, junto a sus reglas.
local CARD_DESCRIPTIONS: { [string]: string } = {
	Hurricane = "Todas las propiedades vuelven al banco. Sus dueños cobran la mitad de su valor.",
	WorldFlip = "La ciudad gira en el aire y todas las fichas caen en casillas al azar.",
	Revolution = "Los dos jugadores más ricos intercambian efectivo con los dos más pobres.",
	Earthquake = "Todos los edificios de una zona bajan un nivel.",
	CrownStrike = "El líder pierde 25 % de su efectivo, repartido entre los demás.",
	Inflation = "Todas las rentas se duplican durante 2 rondas.",
	Strike = "Una zona no cobra renta durante 2 rondas.",
	BounceRent = "Reacción: la próxima renta que te cobren la paga otro jugador que elijas.",
	DeedThief = "Robas una propiedad sin edificios que no complete un grupo.",
	Backstab = "Rompes un pacto tuyo sin coste y te quedas con la garantía.",
	Demolition = "Un edificio rival baja un nivel.",
	Shield = "Reacción: anula la próxima carta que te apunte.",
	ExtraDie = "Tiras un dado adicional este turno.",
	Reverse = "Retrocedes lo que sacaste en vez de avanzar.",
	ForcedTip = "Cada rival te paga 50.",
	Discount = "Tu próxima compra cuesta la mitad.",
	Shove = "Mueves a un rival 3 casillas.",
	Fine = "Un rival paga 100 al banco.",
	Bribe = "Te libras de un castigo del Tribunal.",
	Spy = "Ves la mano de un rival.",
}

-- Textos de la interfaz. `{nombre}` se sustituye con los argumentos de `Strings.get`. Las claves de
-- cartas y perks se añaden abajo, desde sus catálogos.
local TEXTS: { [string]: string } = {
	["hud.round"] = "Ronda {current}/{max}",
	["hud.roundEndless"] = "Ronda {current}",
	["hud.yourTurn"] = "Tu turno",
	["hud.overview"] = "Vista general",
	["hud.overviewKey"] = "M",
	["hud.emotes"] = "Emotes",
	["hud.seconds"] = "{seconds} s",
	["deed.price"] = "Precio",
	["deed.footer"] = "Escritura",
	["deed.fullZone"] = "Zona completa del dueño",
	["deed.hotZone"] = "Casilla en Zona Caliente",
	["deed.double"] = "×2",
	["action.buy"] = "Comprar",
	["action.roll"] = "Tirar",
	["action.move"] = "Mover",
	["action.endTurn"] = "Terminar",
	["action.bid"] = "Pujar {amount}",
	["panel.PerkDraft"] = "Elige un perk",
	["panel.Auction"] = "Subasta",
	["panel.Reaction"] = "¿Reaccionas?",
	["panel.Tribunal"] = "Vota el castigo",
	["panel.Duel"] = "Duelo",
	["panel.Market"] = "Mercado Negro",
	["panel.GhostTurn"] = "Turno de espectro",
	["panel.bidRange"] = "De {min} a {max}",
	["action.decline"] = "No comprar · Subasta",
	["rarity.Common"] = "Común",
	["rarity.Rare"] = "Rara",
	["rarity.Legendary"] = "Legendaria",
	["mark.crown"] = "Corona",
	["mark.traitor"] = "Traidor",
	["mark.fury"] = "Furia {current}/{max}",
	["mark.ghost"] = "Espectro",
	["mark.left"] = "Se fue",
	["mark.bot"] = "Bot",
	["mark.you"] = "Tú",
	["mark.cards"] = "{count} cartas",
	["mark.oneCard"] = "1 carta",
	["mark.skipTurn"] = "Pierde turno",
}

for _, card in Cards.all do
	local description = CARD_DESCRIPTIONS[card.id]
	if description == nil then
		error(`Strings: la carta {card.id} no tiene descripción`)
	end
	TEXTS[`card.{card.id}.name`] = card.name
	TEXTS[`card.{card.id}.description`] = description
end

for _, perk in Perks.all do
	TEXTS[`perk.{perk.id}.name`] = perk.name
	TEXTS[`perk.{perk.id}.description`] = perk.description
end

local Strings = {}

-- Texto de la interfaz. Una clave o un argumento que falte es un error: durante el desarrollo se ve
-- enseguida, y ningún jugador llega a leer una clave o una llave sin sustituir.
function Strings.get(key: string, args: { [string]: any }?): string
	local text = TEXTS[key]
	if text == nil then
		error(`Strings: la clave {key} no existe`, 2)
	end
	return (
		string.gsub(text, "{(%w+)}", function(name: string): string
			local value = if args ~= nil then args[name] else nil
			if value == nil then
				error(`Strings: la clave {key} necesita el argumento {name}`, 2)
			end
			return tostring(value)
		end)
	)
end

-- Título que anuncia un evento en pantalla. Corto: va en la voz grande. `TokenMoved` no lleva: el
-- recorrido se ve solo.
local EVENT_TITLES: { [string]: string } = {
	RoundStarted = "Nueva ronda",
	FinalRoundsStarted = "Última ronda",
	PerkDrafted = "Perk elegido",
	DiceRolled = "¡Dados!",
	TokenMoved = "",
	PassedStart = "Salida",
	PropertyBought = "¡Comprada!",
	RentPaid = "Renta",
	AuctionStarted = "Subasta",
	AuctionWon = "Subasta ganada",
	AuctionNoSale = "Sin ventas",
	BuildingChanged = "Obras",
	TradeCompleted = "Trato cerrado",
	PlayerArrested = "¡Arrestado!",
	TribunalVerdict = "Veredicto",
	BankruptcyDeclared = "Bancarrota",
	GhostActed = "Espectro",
	GhostResurrected = "¡Resucita!",
	CardDrawn = "Carta robada",
	CardDiscarded = "Descarte",
	CardPlayed = "Carta jugada",
	CardBlocked = "¡Bloqueada!",
	HotZoneMoved = "Zona Caliente",
	BillboardResult = "Cartelera",
	DuelResolved = "Duelo",
	PortalUsed = "Portal",
	MarketBought = "Mercado Negro",
	PactFormed = "Pacto firmado",
	PactEnded = "Pacto terminado",
	PactBroken = "¡Traición!",
	CrownMoved = "Nueva Corona",
	FuryFilled = "¡Furia!",
	GameEnded = "Fin de la partida",
}

-- Mayúsculas del español. `string.upper` solo entiende ASCII y dejaría «MARíA JOSé».
local UPPER = {
	["á"] = "Á",
	["é"] = "É",
	["í"] = "Í",
	["ó"] = "Ó",
	["ú"] = "Ú",
	["ü"] = "Ü",
	["ñ"] = "Ñ",
}

function Strings.upper(text: string): string
	local out = string.upper(text)
	for lower: string, upper: string in pairs(UPPER) do
		out = (string.gsub(out, lower, upper))
	end
	return out
end

-- Título de un evento o de una carta jugada. Un id que no se conoce no enseña nada: nunca un nombre interno.
function Strings.eventTitle(id: string): string
	local title = EVENT_TITLES[id]
	if title ~= nil then
		return title
	end
	return TEXTS[`card.{id}.name`] or ""
end

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

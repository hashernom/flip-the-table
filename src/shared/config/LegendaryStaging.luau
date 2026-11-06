--!strict
-- Puesta en escena de las cinco cartas legendarias (plan 08, Tarea 3). Tiempos como fracciones de la escena,
-- que suman 1, y medidas en studs. Se ajustan a ojo, por eso viven aquí y no en la lógica de cada escena.
-- Las reglas puras están en `client/scenes/legendary/LegendaryRules`.

export type Staging = { steps: { string }, fractions: { [string]: number } }

local LegendaryStaging = {}

-- Huracán: el cielo se oscurece, el embudo entra por la calle y da la vuelta a la ciudad llevándose
-- marcadores, añadidos y placas de dueño; el cuerpo de los edificios queda en pie. Sin nada que llevarse,
-- levanta carteles y coches. Después se va y el cielo vuelve.
LegendaryStaging.hurricane = {
	steps = { "darken", "arrive", "sweep", "leave", "clear" },
	fractions = { darken = 0.12, arrive = 0.1, sweep = 0.56, leave = 0.12, clear = 0.1 },
	-- Embudo: alto, radio en la base y en la boca, anillos que lo forman y vueltas por segundo.
	funnelHeight = 80,
	funnelBaseRadius = 5,
	funnelTopRadius = 26,
	funnelRings = 14,
	funnelTurnsPerSec = 1.6,
	-- Por dónde entra y sale: tantos studs fuera de la ciudad, en el eje de la primera casilla.
	approachStuds = 140,
	-- Cuánto antes de que pase el embudo empieza a volar una pieza, en fracción del barrido.
	pullAhead = 0.02,
	-- Vuelo de los restos: segundos de vuelo, altura, radio de la espiral y vueltas.
	debrisSeconds = 1.6,
	debrisRise = 70,
	debrisSpread = 34,
	debrisTurns = 1.5,
	-- Carteles y coches que levanta si no hay nada construido: cuántos y qué tamaño.
	propsWhenEmpty = 10,
	-- Cielo: brillo y ambiente de tormenta. Se vuelve a lo que había al acabar.
	stormBrightness = 0.6,
	stormAmbient = "#3B414A",
	stormFogEnd = 520,
	stormFogColor = "#59606B",
	funnelColor = "#8A9099",
	funnelTransparency = 0.35,
	debrisColor = "#6E747C",
}

-- Mundo al Revés: la ciudad tiembla, todas las fichas suben, la cámara da la vuelta entera al tablero
-- mientras giran en el aire y caen cada una en su nueva casilla.
LegendaryStaging.worldFlip = {
	steps = { "rumble", "lift", "spin", "drop", "settle" },
	fractions = { rumble = 0.1, lift = 0.18, spin = 0.38, drop = 0.24, settle = 0.1 },
	liftStuds = 55,
	-- Vueltas de cada ficha sobre sí misma mientras está arriba, y de la cámara alrededor de la ciudad.
	tokenTurns = 2,
	cameraTurns = 1,
	-- Bote al caer: altura y duración relativa.
	bounceStuds = 3,
	rumbleStuds = 0.35,
	rumbleHz = 14,
}

-- Revolución: una multitud toma la calle frente a los más ricos, llegan blindados y el dinero cambia de
-- manos en sacos; la multitud celebra.
LegendaryStaging.revolution = {
	steps = { "gather", "march", "trucks", "swap", "cheer" },
	fractions = { gather = 0.14, march = 0.22, trucks = 0.26, swap = 0.24, cheer = 0.14 },
	-- Multitud: personas por pareja, separación y de dónde salen (studs por detrás en la calle).
	crowdPerPair = 6,
	crowdSpacing = 3.2,
	crowdStartStuds = 40,
	crowdStopStuds = 10,
	-- Blindados: desde dónde llegan y altura del arco de los sacos.
	truckStartStuds = 70,
	truckStopStuds = 12,
	sackArc = 16,
	sacksPerPair = 4,
	sackColor = "#C9B27C",
	bannerColor = "#C4382B",
}

-- Terremoto: la calle de la zona se agrieta, los edificios tiemblan y cada uno pierde su último marcador y
-- su último añadido, que caen al suelo; el polvo y las grietas duran lo que la escena.
LegendaryStaging.earthquake = {
	steps = { "rumble", "crack", "shake", "fall", "settle" },
	fractions = { rumble = 0.12, crack = 0.18, shake = 0.3, fall = 0.25, settle = 0.15 },
	shakeStuds = 0.9,
	shakeHz = 12,
	-- Grietas: segmentos por casilla, ancho y largo de cada uno.
	cracksPerSquare = 5,
	crackWidth = 1.1,
	crackLength = 7,
	crackColor = "#16191C",
	-- Caída de las piezas: hacia dónde se desplazan al caer (studs hacia la calle) y giro.
	fallTowardStreet = 6,
	fallTurns = 0.4,
	dustColor = "#B8AE98",
}

-- Golpe a la Corona: un foco sobre el líder, la corona se tambalea y cae, y el dinero sale volando de su
-- ficha hacia cada rival.
LegendaryStaging.crownStrike = {
	steps = { "spotlight", "wobble", "fall", "rain", "settle" },
	fractions = { spotlight = 0.15, wobble = 0.15, fall = 0.2, rain = 0.38, settle = 0.12 },
	crownLift = 13,
	crownSize = 5,
	wobbleRadians = 0.35,
	wobbleHz = 5,
	-- Billetes por rival y altura del arco.
	billsPerRival = 6,
	billArc = 22,
	crownColor = "#F2C14E",
	jewelColor = "#C4382B",
	billColor = "#8DB86B",
	billBand = "#4E7A3A",
	spotlightColor = "#FFF2C4",
}

return LegendaryStaging

--!strict
-- Puesta en escena de las cartas raras (plan 08, Tarea 4). Como `LegendaryStaging`: tiempos como fracciones
-- de la escena, que suman 1, y medidas en studs y colores. Las raras duran de 2 a 4 s (config/Scenes), así
-- que cada una tiene pocos pasos y muy claros: quién actúa, a quién afecta y qué cambia.

local CardStaging = {}

-- Demolición: llega la grúa con la bola frente al edificio rival, la bola toma impulso, golpea, el edificio
-- tiembla y su último marcador y su último añadido caen a la calle.
CardStaging.demolition = {
	steps = { "arrive", "windup", "strike", "fall", "settle" },
	fractions = { arrive = 0.2, windup = 0.2, strike = 0.1, fall = 0.35, settle = 0.15 },
	-- Dónde para la grúa: studs desde la fachada hacia la calle y de lado.
	craneStreetStuds = 14,
	craneSideStuds = 6,
	craneApproachStuds = 30,
	-- Balanceo de la bola: atrás antes del golpe y un rebote pequeño después (radianes).
	windupRadians = 0.9,
	strikeRadians = 0.35,
	shakeStuds = 0.7,
	shakeHz = 14,
	fallTowardStreet = 5,
	dustColor = "#B8AE98",
}

-- Huelga: en cada edificio de la zona baja una persiana metálica, cuelga un cartel y la calle se apaga.
CardStaging.strike = {
	steps = { "focus", "shutters", "signs", "hold" },
	fractions = { focus = 0.15, shutters = 0.35, signs = 0.2, hold = 0.3 },
	shutterHeight = 9,
	shutterDepthStuds = 0.6,
	shutterColor = "#8E949A",
	slatColor = "#6E747A",
	slats = 6,
	signColor = "#C4382B",
	-- Cuánto se apaga la zona: oscurece la pintura de sus casillas mientras dura la escena.
	dimTransparency = 0.45,
}

-- Inflación: en cada propiedad sale un «×2» que sube y los billetes saltan por toda la ciudad. A mitad de
-- escena las cifras pintadas pasan a su valor nuevo.
CardStaging.inflation = {
	steps = { "focus", "rise", "swap", "rain" },
	fractions = { focus = 0.15, rise = 0.3, swap = 0.15, rain = 0.4 },
	badgeLift = 14,
	badgeRise = 10,
	badgeWidth = 86,
	badgeHeight = 46,
	-- Billetes: cuántos por propiedad y altura de su salto.
	billsPerProperty = 2,
	billJump = 18,
	billSpread = 12,
	billColor = "#8DB86B",
	billBand = "#4E7A3A",
	badgeColor = "#E07A3C",
}

-- Puñalada: una cuerda une al traidor con su socio, se tensa, brilla y se parte; las dos mitades caen y
-- sobre el traidor cae el sello rojo de traidor.
CardStaging.backstab = {
	steps = { "bind", "strain", "snap", "stamp" },
	fractions = { bind = 0.25, strain = 0.25, snap = 0.2, stamp = 0.3 },
	ropeHeight = 7,
	ropeThickness = 0.6,
	ropeColor = "#C9B27C",
	snapColor = "#FFF2C4",
	sagStuds = 5,
	stampLift = 14,
	stampWidth = 200,
	stampHeight = 60,
	stampTilt = -6,
}

-- Renta Rebotada: la renta sale de la propiedad hacia quien debía pagarla, rebota en él con un muelle y
-- acaba en el tercero que la paga.
CardStaging.bounceRent = {
	steps = { "launch", "bounce", "land", "settle" },
	fractions = { launch = 0.35, bounce = 0.15, land = 0.35, settle = 0.15 },
	coinSize = 3,
	coinColor = "#F2C14E",
	launchArc = 14,
	landArc = 20,
	springColor = "#1B3A6B",
	springStuds = 3,
}

-- Las nueve comunes (scenes/cards/CommonCards): cartel con quién juega y contra quién, y el objeto de cada
-- carta. Sus tiempos van dentro de cada escena, como fracciones de sus 2,5 s.
CardStaging.common = {
	headerLift = 16,
	headerWidth = 300,
	headerHeight = 58,
	coinSize = 2.2,
	coinColor = "#F2C14E",
	shieldSize = 15,
	shieldColor = "#5AB8E8",
	arrowColor = "#E07A3C",
	caseColor = "#6B4A2E",
	bribeBills = 8,
	beamColor = "#FFF2C4",
}

-- Escenas de casillas (scenes/squares/SquareScenes): carteles del Duelo, cuándo pasa la cámara al perdedor,
-- el baúl del Mercado Negro y el sello del Impuesto.
CardStaging.squares = {
	duelSignLift = 13,
	duelFollowAt = 0.85,
	marketCrate = "#1E1A24",
	marketGlow = "#9B5DE5",
	stampWood = "#8A5A33",
	taxCoins = 8,
}

return CardStaging

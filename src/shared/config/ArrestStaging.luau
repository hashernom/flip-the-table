--!strict
-- Valores de la escena de detención (PlayerArrested): reparto del tiempo, sitios de aparcamiento y de los
-- policías, frenazo de la llegada, vuelta al mapa y tamaño de la cárcel. Todo en studs y segundos. Es tabla
-- pura, sin Instance ni Color3: `ArrestRules` la reexpone y las pruebas con Lune la leen igual que el juego.
-- Las rutas no están aquí: `ArrestRules` las construye con el anillo de cada tamaño de tablero.
local ArrestStaging = {}

-- Fracciones del tiempo, en orden: bajarse, llegada de las patrullas, pausa, subirlo al coche, arrancar,
-- vuelta al mapa y entrada en la cárcel. Suman 1. Con los 15 s de `Scenes`, la vuelta dura 3,9 s.
ArrestStaging.FRACTIONS = {
	detach = 0.06,
	sirens = 0.22,
	closeUp = 0.06,
	board = 0.28,
	depart = 0.05,
	lap = 0.26,
	gate = 0.07,
}

-- Las dos patrullas llegan por la calle de dentro y frenan cruzadas, con el morro hacia el detenido. `A` lleva al
-- detenido y sale delante. `B` sale detrás y acaba junto a la casilla. `window` es qué parte de la llegada ocupa
-- cada una: A entra primero y B le pisa los talones.
ArrestStaging.CARS = {
	A = {
		spot = { along = 11, side = -3 },
		arrival = { along = 11, side = 180 },
		parked = { along = -0.5, side = -0.866 },
		window = { from = 0, to = 0.75 },
	},
	B = {
		spot = { along = -11, side = -3 },
		arrival = { along = -11, side = 180 },
		parked = { along = 0.5, side = -0.866 },
		window = { from = 0.25, to = 1 },
	},
}

-- Parte final de la llegada en la que el coche derrapa, y cuánto cabecea al frenar (radianes).
ArrestStaging.SKID_FROM = 0.65
ArrestStaging.BRAKE_PITCH = 0.1

-- Los dos policías salen por las puertas de la patrulla A, van hasta el detenido y lo llevan a la puerta.
ArrestStaging.OFFICERS = {
	{ start = { along = 11, side = 1 }, flank = { along = 3, side = 1 }, door = { along = 7, side = 0 } },
	{
		start = { along = 11, side = -7 },
		flank = { along = 3, side = -7 },
		door = { along = 7, side = -6 },
	},
}
-- Puerta de la patrulla A, por donde entra el detenido.
ArrestStaging.DOOR = { along = 7, side = -3 }
-- Partes de `board`: los policías llegan hasta aquí, y hasta aquí lo sujetan antes de llevárselo.
ArrestStaging.BOARD_ARRIVED = 0.35
ArrestStaging.BOARD_HELD = 0.55

-- Lo que avanzan las patrullas al salir, antes de lanzarse a por la vuelta.
ArrestStaging.DEPART_STUDS = 14
-- Curva de la vuelta: mayor que 1, arranca despacio y acaba lanzada.
ArrestStaging.LAP_CURVE = 1.6
-- La vuelta acaba con A en la calle de llegada, a este `side`; lo que queda es la entrada, con otra cámara.
ArrestStaging.GATE_START_SIDE = 70
-- B llega este trecho por detrás y se aparta a este sitio, junto a la casilla.
ArrestStaging.CONVOY_GAP = 22
ArrestStaging.ESCORT_TURN_SIDE = 34
ArrestStaging.ESCORT_STOP = { along = -10, side = 6 }

-- Parpadeo de las sirenas por segundo y giro máximo del rumbo mostrado, en radianes por segundo.
ArrestStaging.FLASH_HZ = 5
ArrestStaging.TURN_RADIANS_PER_SEC = 14

-- Escala de la gorra de los policías respecto a la pieza del arte.
ArrestStaging.CAP_SCALE = 0.6

-- La fachada de la cárcel queda a esta distancia de la acera exterior, y el edificio tiene este fondo.
ArrestStaging.JAIL_FRONT_OFFSET = 2
ArrestStaging.JAIL_DEPTH = 16

return ArrestStaging

--!strict
-- Valores iniciales de la economía y los tiempos. Se ajustan en pruebas.

return {
	startingCash = 1500,
	startBonus = 200,
	-- Acciones por segundo y jugador que acepta `Protocol.newLimiter` en el servidor. Lo que
	-- sobra se descarta sin tocar el motor.
	actionsPerSecond = 10,
	minPropertyPrice = 60,
	maxPropertyPrice = 400,
	priceStep = 10,
	baseRentRate = 0.1,
	completeZoneRentMultiplier = 2,
	-- Multiplicador de renta de los niveles 1 a 5: una, dos y tres casas, hotel y rascacielos.
	buildingRentMultiplier = { 2, 3, 5, 8, 12 },
	buildingCostRate = 0.5,
	maxRentMultiplier = 4,
	maxBuildingLevel = 5,
	-- Puja representativa que enumera Engine.legalActions: min(alta + paso, efectivo).
	auctionBidStep = 10,
	-- Reservas del bot: efectivo que debe quedarle tras pagar para decidir actuar.
	bot = {
		buyReserve = 200,
		buildReserve = 200,
		bidReserve = 100,
		-- Tiempos agotados seguidos que hacen falta para que el bot tome el control (R-P6).
		timeoutsToControl = 2,
	},
	rounds = { S = 20, M = 15, L = 12 },
	finalRoundsCount = 2,
	-- Multiplicadores de los efectos dinámicos de renta. Se aplican al producto y el total
	-- queda acotado por maxRentMultiplier.
	finalRoundsRentMultiplier = 2,
	pressureRentMultiplier = 2,
	inflationRentMultiplier = 2,
	hotZoneRentMultiplier = 2,
	-- Sin Fin: desde esta ronda la Salida no paga y la renta se duplica.
	pressureFromRound = 30,
	hotZoneInterval = 3,
	seconds = {
		decision = 20,
		auction = 15,
		tribunalVote = 10,
		reaction = 5,
	},
	tax = 100,
	portalToll = 50,
	-- Efectos de las cartas de la ficha y descuento de la siguiente compra.
	cards = {
		forcedTip = 50,
		fine = 100,
		shoveSteps = 3,
		discountMultiplier = 0.5,
		-- Duración en rondas de las cartas raras; el modificador caduca después.
		inflationRounds = 2,
		blackoutRounds = 2,
		-- Porcentaje del efectivo del líder que reparte Golpe a la Corona, redondeado hacia abajo.
		crownStrikeRate = 0.25,
	},
	tribunal = {
		fine = 150,
		payToPlayer = 100,
		skipTurns = 1,
	},
	duel = {
		winnerPrize = 150,
		loserStepsBack = 2,
		maxRounds = 3,
	},
	pact = {
		deposit = 100,
		negotiatorDeposit = 50,
		minRounds = 1,
		maxRounds = 5,
		traitorRounds = 3,
	},
	furyThreshold = 5,
	ghost = {
		sabotagesToRevive = 3,
		reviveCash = 500,
	},
	handLimit = 3,
	smugglerHandLimit = 4,
	-- Perks de la fase 03: draft y efectos. Cada sistema lee su número de aquí.
	perks = {
		offerCount = 3,
		-- Momentos del draft: con tope de rondas, floor(maxRounds × (momento − 1) / divisor) + 1
		-- (momento 2 y 3); en Sin Fin, las rondas fijas de endlessRounds.
		momentDivisor = 3,
		endlessRounds = { 6, 12 },
		-- Banquero: porcentaje extra sobre el bono de la Salida.
		bankerStartRate = 0.5,
		-- Casero: porcentaje extra sobre las rentas propias.
		landlordRentRate = 0.15,
		-- Constructor: descuento sobre el coste de subir un nivel.
		builderCostRate = 0.2,
		-- Coleccionista: pago al robar con la mano llena.
		collectorBonus = 100,
		-- Cazador: multiplicador del daño en efectivo de las cartas contra quien lleva la Corona.
		hunterDamageMultiplier = 1.5,
		-- Blindado: divisor del primer daño por carta de cada ronda.
		armoredDamageDivisor = 2,
		-- Alma en Pena: cartas de sabotaje con las que empieza el espectro al arruinarse (R-P6).
		restlessSoulCards = 2,
	},
}

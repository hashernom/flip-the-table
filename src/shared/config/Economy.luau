--!strict
-- Valores iniciales de la economía y los tiempos. Se ajustan en pruebas.

return {
	startingCash = 1500,
	startBonus = 200,
	minPropertyPrice = 60,
	maxPropertyPrice = 400,
	priceStep = 10,
	baseRentRate = 0.1,
	completeZoneRentMultiplier = 2,
	buildingRentMultiplier = { 3, 6, 10 },
	buildingCostRate = 0.5,
	maxRentMultiplier = 4,
	maxBuildingLevel = 3,
	-- Puja representativa que enumera Engine.legalActions: min(alta + paso, efectivo).
	auctionBidStep = 10,
	-- Reservas del bot: efectivo que debe quedarle tras pagar para decidir actuar.
	bot = {
		buyReserve = 200,
		buildReserve = 200,
		bidReserve = 100,
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
}

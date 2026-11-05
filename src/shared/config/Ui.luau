--!strict
-- Valores de la interfaz del cliente que se ajustan a ojo. Viven aquí y no en cada menú para que
-- tocarlos no obligue a leer la lógica. Los de reglas (rondas máximas de un pacto, saltos de puja) se
-- leen de Economy.

return {
	-- Importes que recorren los botones «más» y «menos» de un trato, en efectivo.
	tradeCashSteps = { 0, 50, 100, 200, 500 },
	-- Duraciones que ofrece el menú de pactos. El motor acepta de Economy.pact.minRounds a
	-- Economy.pact.maxRounds: el menú solo enseña las que caben.
	pactRoundOptions = { 1, 2, 3, 5 },
	-- Segundos que se queda en pantalla el aviso de una acción rechazada.
	toastSeconds = 3,
	-- Fracción de la altura de la pantalla que puede ocupar un panel con lista antes de hacer scroll.
	maxPanelHeightFraction = 0.6,
	-- Ancho máximo, en píxeles, de los paneles y los modales; en pantallas estrechas mandan los 90 %.
	maxPanelWidth = 460,
	-- Minimapa: lado y distancia a los bordes de la ventana.
	miniMapSize = 192,
	miniMapTop = 12,
	miniMapRight = 12,

	-- Paleta de art/guia-de-estilo.md §2.1, en `#RRGGBB` porque `Color3` es de Roblox. Las variantes
	-- son la misma chapa en sombra: el labio del botón, el fondo del taxímetro y el tornillo.
	palette = {
		asphalt = "#23272C",
		asphaltDeep = "#14171A",
		limestone = "#EDE5D3",
		limestoneDim = "#CFC5AE",
		taxi = "#F5C518",
		taxiLip = "#B8920F",
		signal = "#C4382B",
		works = "#E07A3C",
		steel = "#A8AEB4",
		navy = "#1B3A6B",
	},

	-- Tamaño de pantalla para el que se diseña. Por encima se escala hacia arriba, hasta `maxUiScale`;
	-- por debajo nunca se encoge, porque ninguna etiqueta puede bajar de 12 píxeles.
	referenceViewport = { x = 1440, y = 900 },
	maxUiScale = 1.6,

	-- Radios de la chapa. La placa es troquelada: nada de esquinas vivas.
	radius = { plate = 16, pill = 27, card = 14, button = 18, small = 6 },

	-- Mesa en la columna izquierda: de 1 a 8 placas, cuyo tamaño depende de cuántos jugadores haya.
	-- Ancho común de la columna: el justo para el contenido más largo de la mesa, entre estos dos topes.
	plateMinWidth = 176,
	plateMaxWidth = 240,
	-- Lo que la punta de la flecha del turno sobresale de la placa.
	arrowTipWidth = 46,
	plateColumnLeft = 44,
	plateColumnTop = 70,
	plateTiers = {
		large = { upTo = 3, plateHeight = 70, step = 80, disc = 58, name = 15, money = 20, arrow = 84 },
		normal = { upTo = 5, plateHeight = 66, step = 75, disc = 56, name = 14, money = 19, arrow = 80 },
		compact = { upTo = 8, plateHeight = 60, step = 67, disc = 52, name = 14, money = 18, arrow = 74 },
	},

	-- Chapa de la flecha del turno: alto de la imagen y tramo que se estira a lo ancho.
	arrowImageHeight = 312,
	arrowSliceCenter = { left = 110, top = 120, right = 700, bottom = 190 },

	-- Color del aro de cada asiento, en `#RRGGBB`.
	seatColors = { "#E85D9E", "#22D3EE", "#F59E0B", "#8B5CF6", "#CFC5AE", "#10B981", "#4F46E5", "#C97B3A" },

	-- Letrero de ronda, título de escena y aviso.
	roundSignWidth = 560,
	-- El letrero cuelga del borde superior de la ventana.
	signTop = 12,
	bannerTop = 22,
	-- Lo que dura en pantalla el título de un evento, aunque su escena siga.
	bannerSeconds = 1.6,
	bannerWidth = 420,
	toastWidth = 460,

	-- Mano en abanico, sobre la calzada.
	handLeft = 352,
	handCardStep = 82,
	handMaxCards = 4,
	handVisibleHeight = 92,
	handFanDegrees = 11,
	handFanDrop = 10,

	-- Calzada del plazo, al pie de la pantalla, y hueco que deja la mano sobre ella.
	roadHeight = 36,
	handClearance = 100,
	deadlineWarnSeconds = 5,
	dashLength = 28,
	dashGap = 16,

	-- Movimiento de la interfaz, en segundos. Breve siempre: nada retrasa la partida.
	motion = {
		press = 0.08,
		open = 0.22,
		close = 0.15,
		moneyRoll = 0.6,
		moneyFloat = 1.8,
		turnSwayPeriod = 3.2,
		turnSwayDegrees = 1,
		plateShift = 0.25,
	},
}

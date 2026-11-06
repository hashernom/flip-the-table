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
	-- Segundos que espera un botón de acción irreversible la segunda pulsación; pasados, vuelve a su texto.
	confirmSeconds = 3,
	-- Fracción de la altura de la pantalla que puede ocupar un panel con lista antes de hacer scroll.
	maxPanelHeightFraction = 0.6,
	-- Ancho máximo, en píxeles, de los paneles y los modales; en pantallas estrechas mandan los 90 %.
	maxPanelWidth = 460,
	-- Hojas modales: cuánto sube la hoja al abrirse, y la opacidad del velo que cubre la ciudad.
	sheetRise = 16,
	sheetVeil = 0.35,
	-- Tablón de obra: la ventana de tratos, pactos, fichas y revancha. Ocupa esta fracción de la pantalla
	-- hasta el tamaño de diseño; los postes de acero sobresalen por arriba y por abajo.
	board = {
		width = 1200,
		height = 820,
		fraction = 0.94,
		-- Lo más que se encoge el tablón en una pantalla baja; por debajo, la letra dejaría de leerse.
		minScale = 0.75,
		padding = 24,
		gap = 16,
		postWidth = 26,
		postOverhang = 16,
		footerHeight = 76,
		swapSize = 88,
		sendWidth = 250,
	},
	-- Pactos caben en un tablón más pequeño: socio, duración y una lista corta.
	pactBoard = { width = 900, height = 620 },
	-- Ajustes: tablón pequeño y barras de volumen.
	settingsBoard = { width = 760, height = 640 },
	slider = {
		rowHeight = 48,
		captionWidth = 130,
		valueWidth = 80,
		trackHeight = 12,
		knob = 26,
		keyWidth = 72,
	},
	-- Lobby: placa del código de party y alto del pie con el aviso del servidor.
	lobby = { codeHeight = 84, codeSize = 56, noticeHeight = 56 },
	-- Cartel pegado al tablón: relleno, giro del cartel de título y medida de la cinta.
	poster = { padding = 18, titleTilt = -0.4, tapeWidth = 64, tapeHeight = 20 },
	-- Escritura en miniatura dentro de un cartel; la elegida se despega `lift` píxeles.
	miniDeed = { width = 112, height = 146, lift = 10, zone = 58, price = 26, gap = 12 },
	-- Tarjeta de ficha en el tablón de elegir ficha, y cámara del visor que enseña la ficha en 3D.
	tokenCard = { columns = 4 },
	tokenPreview = { fieldOfView = 30, margin = 1.08 },
	-- Tarjeta de decisión del panel: franja del tipo, cuánto crece al pasar el ratón, cómo entra repartida
	-- (desde `dealScale`, girada `dealTilt` más, una tras otra cada `dealStep` s) y cuánto se hunde al pulsarla.
	decisionCard = {
		inset = 6,
		band = 22,
		hoverScale = 1.03,
		dealScale = 0.88,
		dealTilt = 4,
		dealStep = 0.05,
		tilt = 1.2,
		pressScale = 0.96,
		gap = 10,
	},
	-- Consejo de la primera partida: ancho, hueco sobre la mano y la calzada, giro, cuánto sube al entrar
	-- y segundos en pantalla antes de irse solo.
	guide = { width = 420, bottom = 150, tilt = -0.8, rise = 24, seconds = 7 },
	-- Campo de dinero escrito a mano.
	cashField = { width = 150, height = 48 },
	-- Hueco que deja el cartel de la vista general sobre la calzada del plazo.
	overviewBottom = 24,
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

	-- Chapa de la flecha del turno: medidas de la imagen y dónde se corta en tres piezas.
	arrowImageWidth = 960,
	arrowImageHeight = 312,
	arrowCuts = { left = 110, right = 700 },

	-- Panel de decisión, a la derecha, bajo el minimapa.
	panelTop = 216,
	panelRight = 12,
	panelWidth = 296,
	panelGap = 8,
	-- Altura de lo que acompaña a la escritura: botón, secundario y huecos. Con pantallas bajas, la
	-- escritura se reduce hasta `deedMinScale` para que todo quepa.
	panelActionsHeight = 150,
	deedHeight = 354,
	deedMinScale = 0.45,
	-- Lo que añaden al panel el título de una fase (subasta, duelo) y la fila de puja con su rango.
	panelTitleHeight = 48,
	bidControlsHeight = 72,

	-- Color del aro de cada asiento, en `#RRGGBB`.
	seatColors = { "#E85D9E", "#22D3EE", "#F59E0B", "#8B5CF6", "#CFC5AE", "#10B981", "#4F46E5", "#C97B3A" },

	-- Letrero de «un bot juega por ti», bajo el aviso breve.
	reclaimTop = 120,
	reclaimWidth = 560,
	-- Letrero de ronda, título de escena y aviso.
	roundSignWidth = 690,
	settingsButtonWidth = 128,
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

	-- Carta de la mano vista en grande al pasar el ratón, y cómo llega una carta robada: cae desde
	-- `drawRise` píxeles por encima de la mano, girada `drawTilt` grados y `drawScale` veces más grande.
	cardPreview = { width = 250, height = 350, gap = 14, scaleFrom = 0.85 },
	cardDraw = { seconds = 0.55, rise = 380, shift = 220, tilt = -16, scale = 1.8 },
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

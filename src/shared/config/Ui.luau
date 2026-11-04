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
}

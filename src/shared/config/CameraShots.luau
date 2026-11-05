--!strict
-- Planos de la cámara de turno, medidos desde la ficha (R-P51). `back` es hacia atrás en la marcha,
-- `inward` hacia el interior del anillo, desde donde se ven las fachadas de frente, `up` la altura, y
-- `ahead` y `focusUp` dicen a qué punto mira. Se ajustan a ojo, por eso viven aquí.
export type Shot = { back: number, inward: number, up: number, ahead: number, focusUp: number }

return {
	-- Antes de tirar y al decidir: alejado, para ver la propiedad y las casillas que vienen.
	turn = { back = 26, inward = 34, up = 50, ahead = 42, focusUp = 6 } :: Shot,
	-- Durante el recorrido: cerca de la ficha y del avatar.
	ride = { back = 16, inward = 7, up = 13, ahead = 10, focusUp = 8 } :: Shot,
	-- Vista general: altura y retroceso como fracción del lado de la ciudad, y giro por píxel arrastrado.
	overview = { heightPerSpan = 1.35, backPerSpan = 0.1, panelShiftPerSpan = 0.14, radiansPerPixel = 0.006 },
	-- Con qué rapidez se acerca al plano, por segundo: cuanto mayor, más brusco. No depende de los FPS.
	followRate = 5,
}

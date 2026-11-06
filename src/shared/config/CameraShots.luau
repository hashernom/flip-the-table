--!strict
-- Planos de la cámara de turno, medidos desde la ficha (R-P51). `back` es hacia atrás en la marcha,
-- `inward` hacia el interior del anillo, desde donde se ven las fachadas de frente, `up` la altura, y
-- `ahead` y `focusUp` dicen a qué punto mira. Se ajustan a ojo, por eso viven aquí.
-- `fixedSide`: el plano no sigue a `CityLayout.LOT_SIDE` (los de la detención, montada con la cárcel fuera).
export type Shot = {
	back: number,
	inward: number,
	up: number,
	ahead: number,
	focusUp: number,
	fixedSide: boolean?,
}

return {
	-- Antes de tirar y al decidir: alejado, para ver la propiedad y las casillas que vienen.
	turn = { back = 26, inward = 34, up = 50, ahead = 42, focusUp = 6 } :: Shot,
	-- Gestionar propiedades: delante de la fachada, desde la calle, a `distance` del solar y `up` de alto.
	manage = { distance = 44, up = 24, focusUp = 8 },
	-- Durante el recorrido: cerca de la ficha y del avatar.
	ride = { back = 16, inward = 7, up = 13, ahead = 10, focusUp = 8 } :: Shot,
	-- Primer plano del detenido (PlayerArrested): desde el interior de la calle, para que ninguna patrulla
	-- quede entre la cámara y el avatar.
	arrest = { back = 4, inward = 20, up = 8, ahead = 0, focusUp = 3, fixedSide = true } :: Shot,
	-- Seguimiento de la patrulla en su vuelta al mapa: detrás y cerca, mirando hacia donde va.
	arrestChase = { back = 20, inward = 0, up = 8, ahead = 16, focusUp = 2, fixedSide = true } :: Shot,
	-- Vista general: altura y retroceso como fracción del lado de la ciudad, y giro por píxel arrastrado.
	-- Más cerca del tablero (2026-11-06): el anillo llena la vista y el exterior queda libre para los barrios.
	-- Más cerca aún (2026-11-06, segunda vez): de frente cabe entera; en diagonal asoman las esquinas.
	overview = { heightPerSpan = 0.85, backPerSpan = 0.08, panelShiftPerSpan = 0.08, radiansPerPixel = 0.006 },
	-- Con qué rapidez se acerca al plano, por segundo: cuanto mayor, más brusco. No depende de los FPS.
	followRate = 5,
}

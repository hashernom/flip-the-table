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
	-- Mira `toward` studs por delante del solar, hacia la calle: así la isla con las casas queda en el centro
	-- de la pantalla, por encima del panel, y el edificio detrás.
	manage = { distance = 52, up = 44, focusUp = 2, toward = 13 },
	-- Durante el recorrido: cerca de la ficha y del avatar.
	ride = { back = 16, inward = 7, up = 13, ahead = 10, focusUp = 8 } :: Shot,
	-- Primer plano del detenido (PlayerArrested): desde el interior de la calle, para que ninguna patrulla
	-- quede entre la cámara y el avatar.
	arrest = { back = 4, inward = 20, up = 8, ahead = 0, focusUp = 3, fixedSide = true } :: Shot,
	-- Seguimiento de la patrulla en su vuelta al mapa: detrás y cerca, mirando hacia donde va.
	arrestChase = { back = 20, inward = 0, up = 8, ahead = 16, focusUp = 2, fixedSide = true } :: Shot,
	-- Legendarias (plan 08, Tarea 3). Huracán: desde fuera de la calle y en alto, siguiendo al embudo.
	hurricane = { back = 75, inward = 40, up = 58, ahead = 0, focusUp = 22, fixedSide = true } :: Shot,
	-- Terremoto: la zona entera, desde el centro del anillo, a media altura para ver temblar las fachadas.
	quake = { back = 52, inward = 44, up = 36, ahead = 0, focusUp = 8 } :: Shot,
	-- Revolución: a pie de calle, de lado, para ver la multitud y los blindados.
	revolution = { back = 34, inward = 36, up = 22, ahead = 6, focusUp = 4 } :: Shot,
	-- Golpe a la Corona: cerca del líder y algo por debajo de la corona, que cae hacia la cámara.
	crown = { back = 20, inward = 16, up = 12, ahead = 0, focusUp = 9 } :: Shot,
	-- Plano de toda la ciudad para Huracán y Mundo al Revés: retroceso y altura como fracción del lado de la
	-- ciudad, para que quepa en cualquier tamaño.
	legendWide = { backPerSpan = 0.62, upPerSpan = 0.62, focusUp = 10 },
	-- Ladrón de Escrituras: desde la calle, de frente a la fachada de la propiedad robada.
	deed = { back = 44, inward = 0, up = 24, ahead = 0, focusUp = 10, fixedSide = true } :: Shot,
	-- Duelo: de lado, con los dos rivales en el cuadro y el «VS» entre ellos.
	duel = { back = 42, inward = 0, up = 18, ahead = 0, focusUp = 7, fixedSide = true } :: Shot,
	-- Zona Caliente: primer plano de la zona nueva, desde su calle y algo alto, para ver sus edificios juntos.
	hotZone = { back = 70, inward = 0, up = 46, ahead = 0, focusUp = 6, fixedSide = true } :: Shot,
	-- Podio: de frente a los tres escalones, un poco por encima.
	podium = { back = 46, inward = 0, up = 20, ahead = 0, focusUp = 8, fixedSide = true } :: Shot,
	-- Vista general: altura y retroceso como fracción del lado de la ciudad, y giro por píxel arrastrado.
	-- Más cerca del tablero (2026-11-06): el anillo llena la vista y el exterior queda libre para los barrios.
	-- Encuadra el tablero, no la ciudad (2026-11-06): el anillo con su calle llena la pantalla de frente.
	overview = { heightPerSpan = 0.8, backPerSpan = 0.03, panelShiftPerSpan = 0.08, radiansPerPixel = 0.006 },
	-- Con qué rapidez se acerca al plano, por segundo: cuanto mayor, más brusco. No depende de los FPS.
	followRate = 5,
}

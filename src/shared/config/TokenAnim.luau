--!strict
-- Amplitudes y tiempos de la animación procedural de las fichas. Los tres gestos —reposo, marcha y
-- celebración— se hacen moviendo el cuerpo desde `TokenRider`, sin animaciones subidas, así que estos
-- números son lo único que se toca para ajustarlos. Van aquí, con el resto de valores ajustables del
-- juego, y no dentro del módulo que los usa.
export type Idle = {
	step: number, -- segundos entre fotogramas de la animación
	period: number, -- segundos de un vaivén completo
	lift: number, -- studs de subida y bajada del cuerpo
	pitch: number, -- radianes de cabeceo
}

export type Ride = {
	step: number,
	bob: number, -- studs de bote
	pitch: number, -- radianes de cabeceo
	bobPeriod: number, -- segundos de un bote completo
	fadeSec: number, -- segundos que tarda el bote en aparecer al arrancar y en apagarse al frenar
}

export type Celebrate = {
	step: number,
	seconds: number, -- duración por defecto
	minSeconds: number,
	maxSeconds: number,
	lift: number, -- studs que sube la ficha en el salto
}

return {
	-- Reposo: tan leve y lento que no se nota en la cámara.
	idle = { step = 1 / 30, period = 3.2, lift = 0.05, pitch = math.rad(0.5) } :: Idle,
	-- Marcha: bote y cabeceo encima del avance de la ficha, apagados en los extremos del recorrido.
	ride = { step = 1 / 30, bob = 0.08, pitch = math.rad(1), bobPeriod = 0.5, fadeSec = 0.35 } :: Ride,
	-- Celebración: un salto corto y un giro completo sobre sí misma.
	celebrate = { step = 1 / 30, seconds = 1.1, minSeconds = 0.3, maxSeconds = 3, lift = 2.2 } :: Celebrate,
}

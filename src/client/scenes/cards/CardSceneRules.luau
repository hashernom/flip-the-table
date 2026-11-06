--!strict
-- Reglas puras de las escenas de cartas raras (plan 08, Tarea 4): el balanceo de la bola de demolición, la
-- cuerda del pacto, el rebote de la renta y el salto de los billetes. Tablas en vez de `Vector3`, para
-- probarlas con Lune. Los tiempos se reparten con `LegendaryRules.windows`.
-- Solo se usa en los tipos (`typeof`), que selene no cuenta.
-- selene: allow(unused_variable)
local CardStaging = require("../../../shared/config/CardStaging")
local LegendaryRules = require("../legendary/LegendaryRules")

type Point3 = LegendaryRules.Point3

local CardSceneRules = {}

-- Ángulo de la bola respecto a la vertical: positivo hacia el edificio. `windup` (0 a 1) la lleva hacia
-- atrás y `strike` (0 a 1) la lanza hasta pasar un poco la vertical al golpear.
function CardSceneRules.swing(windup: number, strike: number, staging: typeof(CardStaging.demolition)): number
	local back = -staging.windupRadians * LegendaryRules.ease(windup)
	if strike <= 0 then
		return back
	end
	local p = math.clamp(strike, 0, 1)
	-- Cae como un péndulo: acelera hacia el edificio, sin suavizar el final, porque golpea.
	return back + (staging.strikeRadians - back) * (p * p)
end

-- Punto `t` (0 a 1) de una cuerda de `a` a `b` que cuelga `sag` en medio.
function CardSceneRules.rope(a: Point3, b: Point3, t: number, sag: number): Point3
	local p = math.clamp(t, 0, 1)
	if p == 0 then
		return { x = a.x, y = a.y, z = a.z }
	elseif p == 1 then
		return { x = b.x, y = b.y, z = b.z }
	end
	return {
		x = a.x + (b.x - a.x) * p,
		y = a.y + (b.y - a.y) * p - sag * 4 * p * (1 - p),
		z = a.z + (b.z - a.z) * p,
	}
end

-- Moneda de la Renta Rebotada: `launch` (0 a 1) la lleva de la propiedad a quien debía pagar, y `land`
-- (0 a 1) del rebote al tercero, con un arco más alto.
function CardSceneRules.bounce(
	from: Point3,
	via: Point3,
	to: Point3,
	launch: number,
	land: number,
	staging: typeof(CardStaging.bounceRent)
): Point3
	if land <= 0 then
		return LegendaryRules.arc(from, via, launch, staging.launchArc)
	end
	return LegendaryRules.arc(via, to, land, staging.landArc)
end

-- Salto de un billete de la Inflación, relativo a su propiedad: sale hacia `seed` (0 a 1 de vuelta),
-- sube `billJump` a mitad y cae a `billSpread` del sitio.
function CardSceneRules.burst(seed: number, t: number, staging: typeof(CardStaging.inflation)): Point3
	local p = math.clamp(t, 0, 1)
	local angle = seed * 2 * math.pi
	local radius = staging.billSpread * p
	return {
		x = math.cos(angle) * radius,
		y = staging.billJump * 4 * p * (1 - p),
		z = math.sin(angle) * radius,
	}
end

return CardSceneRules

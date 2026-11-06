--!strict
-- Identidad de los barrios de Metrópolis (plan 07, Tarea 1). Es puro: ni `Instance` ni `Vector3`,
-- solo números y textos, para poder probarlo con Lune.
--
-- Un barrio no se define por sus zonas, sino por su calle: la acera que pisa, el mobiliario que la
-- amuebla y la silueta que tiene detrás. Eso es lo que hace que Centro, Puerto, Zona Alta e
-- Industrial se distingan de un vistazo aunque el color no se distinga (art/guia-de-estilo.md §7).
--
-- Los `kind` son ids de `ArtAssets.street`: el mismo texto identifica la pieza en el manifiesto y en
-- el código. Un barrio sin sus mallas subidas se queda sin amueblar, pero la ciudad se construye.

export type Rule = {
	-- Id del asset en `ArtAssets.street`.
	kind: string,
	-- "slot": en el centro de la casilla. "joint": en la junta con la siguiente.
	at: "slot" | "joint",
	-- Studs a lo largo de la calle desde el punto de arriba, en el sentido de la marcha.
	along: number,
	-- Studs desde el eje de la calzada. Positivo, hacia los edificios; negativo, hacia el interior.
	out: number,
	-- Altura de la base de la pieza.
	y: number,
	-- Uno de cada `every`; `skip` desplaza el ciclo para que no todo caiga en la misma casilla.
	every: number?,
	skip: number?,
	-- Solo en la primera o la última casilla del barrio.
	from: "first" | "last"?,
	-- Solo si la casilla y la siguiente siguen en la misma recta (no en una esquina).
	straight: boolean?,
	-- Fuera de la última casilla, donde el paso de cebra cierra el barrio.
	exceptLast: boolean?,
}

export type Barrio = {
	id: string,
	label: string,
	-- Acera propia: la chapa de pavimento y bordillo que se pone en cada casilla.
	walk: string,
	-- Fondos de ciudad, de 80 de ancho. Se alternan para que la silueta no se repita.
	backdrops: { string },
	-- Cruzado de la calle en las dos puntas del barrio: es la frontera entre barrios.
	crosswalk: string,
	rules: { Rule },
}

local Barrios = {}

-- La acera del juego mide 0,4 sobre el asfalto (`CityLayout`), y todo lo que se apoya en ella empieza ahí.
Barrios.SIDEWALK_TOP = 0.4

-- Centro va primero porque es el barrio de referencia de la familia: su calle es la plantilla.
-- Los otros tres entran con su propio lote de arte, uno detrás de otro.
local LIST: { Barrio } = {
	{
		id = "Centro",
		label = "Centro",
		walk = "centro-walk",
		backdrops = { "centro-backdrop-a", "centro-backdrop-b" },
		crosswalk = "Crosswalk",
		rules = {
			-- La acera, en todas las casillas.
			{ kind = "centro-walk", at = "slot", along = 0, out = 20.5, y = Barrios.SIDEWALK_TOP },
			-- Farola de forja contra el bordillo, y banco arrimado a la fachada.
			{ kind = "centro-lamp", at = "slot", along = -13, out = 18.0, y = Barrios.SIDEWALK_TOP },
			{ kind = "centro-bench", at = "slot", along = 9, out = 22.6, y = Barrios.SIDEWALK_TOP },
			-- Un quiosco de prensa cada cuatro casillas, entre el banco y la esquina.
			{
				kind = "centro-kiosk",
				at = "slot",
				along = 15.5,
				out = 21.0,
				y = Barrios.SIDEWALK_TOP,
				every = 4,
				skip = 2,
			},
			-- Boca de riego cada tres casillas, junto al bordillo.
			{
				kind = "centro-hydrant",
				at = "slot",
				along = 4.0,
				out = 18.1,
				y = Barrios.SIDEWALK_TOP,
				every = 3,
				skip = 1,
			},
			-- Plátanos en las juntas, en las dos aceras: la copa tapa la fachada justo lo suficiente. La
			-- última junta la ocupa el paso de cebra que cierra el barrio.
			{
				kind = "centro-tree",
				at = "joint",
				along = 0,
				out = 19.5,
				y = Barrios.SIDEWALK_TOP,
				straight = true,
				exceptLast = true,
			},
			{
				kind = "centro-tree",
				at = "joint",
				along = 0,
				out = -20.5,
				y = Barrios.SIDEWALK_TOP,
				straight = true,
				exceptLast = true,
			},
		},
	},
}

local BY_ID: { [string]: Barrio } = {}
for _, barrio in LIST do
	BY_ID[barrio.id] = barrio
end

Barrios.all = LIST

-- Los barrios con calle propia, en el orden en que los recorre la ruta.
Barrios.ids = table.freeze((function(): { string }
	local ids: { string } = {}
	for _, barrio in LIST do
		table.insert(ids, barrio.id)
	end
	return ids
end)())

function Barrios.get(id: string): Barrio
	local barrio = BY_ID[id]
	if barrio == nil then
		error(`Barrios: no hay barrio "{id}"`, 2)
	end
	return barrio
end

function Barrios.has(id: string): boolean
	return BY_ID[id] ~= nil
end

return Barrios

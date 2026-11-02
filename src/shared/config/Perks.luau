--!strict
-- Datos de los 12 perks del MVP. Los efectos viven en el módulo que ya tiene su sistema:
-- Movement (Banquero), Property (Casero), Building (Constructor), Deck (Contrabandista y
-- Coleccionista), Cards (Cazador y Blindado) y Engine (Dedos Rápidos). Abogado, Afortunado,
-- Negociador y Alma en Pena los cablean las tareas que traen su sistema (R-P6).

export type PerkDef = {
	id: string,
	-- Nombre en español para la interfaz.
	name: string,
	description: string,
}

-- Orden de la tabla «Perks» de la ficha.
local ALL: { PerkDef } = {
	{
		id = "Banker",
		name = "Banquero",
		description = "Cobras 50 % más al pasar por la Salida",
	},
	{
		id = "Landlord",
		name = "Casero",
		description = "Tus rentas suben 15 %",
	},
	{
		id = "Builder",
		name = "Constructor",
		description = "Construir te cuesta 20 % menos",
	},
	{
		id = "Smuggler",
		name = "Contrabandista",
		description = "Tu mano sube a 4 cartas",
	},
	{
		id = "QuickFingers",
		name = "Dedos Rápidos",
		description = "Puedes repetir un dado una vez por ronda",
	},
	{
		id = "Lawyer",
		name = "Abogado",
		description = "Los empates en el Tribunal te favorecen",
	},
	{
		id = "Negotiator",
		name = "Negociador",
		description = "Tus pactos piden menos garantía",
	},
	{
		id = "Lucky",
		name = "Afortunado",
		description = "Mejores premios en la Cartelera",
	},
	{
		id = "Hunter",
		name = "Cazador",
		description = "Tus cartas contra el líder hacen 50 % más de daño",
	},
	{
		id = "Armored",
		name = "Blindado",
		description = "El primer daño por carta de cada ronda se reduce a la mitad",
	},
	{
		id = "Collector",
		name = "Coleccionista",
		description = "Cobras 100 cada vez que robas una carta y tienes la mano llena",
	},
	{
		id = "RestlessSoul",
		name = "Alma en Pena",
		description = "Si te arruinas, empiezas como espectro con 2 cartas",
	},
}

local Perks = {}

Perks.all = ALL

local byId: { [string]: PerkDef } = {}
for _, perk in ALL do
	if byId[perk.id] then
		error(`Perks: el id {perk.id} está repetido`, 2)
	end
	byId[perk.id] = perk
end
Perks.byId = byId

return Perks

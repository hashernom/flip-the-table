--!strict
-- Escena provisional: muestra el nombre del evento mientras dura. Es el arte gris de las escenas: no
-- hay animación, ni personajes, ni cámara propia, solo un rótulo que confirma que la cola avanza y
-- que todo el grupo ve lo mismo en el mismo orden.
--
-- Es puro: no toca `Instance` ni espera por su cuenta. Recibe el reloj y el rótulo en el contexto, así
-- que la misma escena corre igual en Roblox y en Lune.
local Types = require("../../shared/rules/Types")

export type Context = {
	duration: number,
	show: (text: string) -> (),
	wait: (seconds: number) -> (),
}

local PlaceholderScene = {}

-- Rótulo de un evento. Una carta se anuncia con su propio id, que es lo que le da nombre a cada
-- legendaria; sin id, se queda con el tipo del evento, que es el nombre con el que aparece en la
-- arquitectura.
function PlaceholderScene.labelFor(event: Types.Event): string
	if event.type == "CardPlayed" and type(event.cardId) == "string" then
		return event.cardId
	end
	return event.type
end

function PlaceholderScene.run(ctx: Context, event: Types.Event)
	ctx.show(PlaceholderScene.labelFor(event))
	ctx.wait(ctx.duration)
end

return PlaceholderScene

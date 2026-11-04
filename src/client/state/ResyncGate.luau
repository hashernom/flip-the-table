--!strict
-- Compuerta de las respuestas de resync. Una vista completa que llega mientras corre una escena no se
-- pinta en el acto: los menús volverían a aparecer a mitad de ella (R-P39). Se guarda hasta que la
-- escena acaba y, si llegan varias, vale la última. Es pura: no sabe de menús ni de escenas, solo de
-- si hay una en marcha.
export type Gate = {
	-- «Apply» si hay que aplicar la vista ya; «Defer» si se guarda para cuando acabe la escena.
	offer: (batch: any, sceneRunning: boolean) -> "Apply" | "Defer",
	-- La respuesta aplazada, una sola vez, o nil si no hay ninguna.
	take: () -> any?,
}

local ResyncGate = {}

function ResyncGate.new(): Gate
	local held: any? = nil
	return {
		offer = function(batch: any, sceneRunning: boolean): "Apply" | "Defer"
			if sceneRunning then
				held = batch
				return "Defer"
			end
			return "Apply"
		end,
		take = function(): any?
			local batch = held
			held = nil
			return batch
		end,
	}
end

return ResyncGate

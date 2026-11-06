--!strict
-- Registro de escenas: qué escena reproduce cada evento y cada carta. Es solo datos, sin `Instance`, para
-- que la prueba de `config/Scenes` compruebe con Lune que ningún id se queda sin escena.
--
-- "Placeholder" es la escena provisional (`PlaceholderScene`). Cada tarea del plan 08 cambia aquí el
-- nombre de las escenas que termina. Las escenas que necesitan el estado del cliente (fichas, cámara) se
-- siguen registrando en el director desde `main.client`; este registro dice cuál les toca.
local Scenes = require("../../shared/config/Scenes")

local PLACEHOLDER = "Placeholder"

-- Escenas definitivas ya hechas. Todo id de `Scenes.allIds()` que no esté aquí usa la provisional.
local FINAL: { [string]: string } = {
	TokenMoved = "TokenRide",
	PortalUsed = "PortalJump",
	BillboardResult = "Billboard",
	PlayerArrested = "Arrest",
	DeedThief = "cards/DeedThief",
	PropertyBought = "SettleNow",
	AuctionWon = "SettleNow",
}

local byId: { [string]: string } = {}
for _, id in Scenes.allIds() do
	byId[id] = FINAL[id] or PLACEHOLDER
end
-- Un id de FINAL que no existe en Scenes (un nombre mal escrito) también entra: así la prueba lo detecta.
for id, name in FINAL do
	byId[id] = name
end

local SceneRegistry = {}

SceneRegistry.PLACEHOLDER = PLACEHOLDER

-- Ids con escena registrada, ordenados.
function SceneRegistry.ids(): { string }
	local ids: { string } = {}
	for id in byId do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

-- Nombre de la escena de un id, o nil si no tiene.
function SceneRegistry.sceneFor(id: string): string?
	return byId[id]
end

return SceneRegistry

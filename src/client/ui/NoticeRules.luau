--!strict
-- Enrutado de los avisos del servidor (`LobbyNotice`, R-P48). Es puro: decide dónde se enseña cada
-- aviso y `main.client` solo lo ejecuta. El panel de revancha sigue recibiendo los avisos de la revancha
-- y del lobby; el rechazo de una acción es un aviso breve de la barra.
local Protocol = require("../../shared/net/Protocol")

export type Route = "Toast" | "Panel"

local NoticeRules = {}

-- Destino de un aviso, o nil si no es un aviso válido (no es una tabla o no trae mensaje).
function NoticeRules.route(notice: any): Route?
	if type(notice) ~= "table" or type(notice.message) ~= "string" then
		return nil
	end
	if notice.kind == Protocol.NOTICE_KINDS.ActionRejected then
		return "Toast"
	end
	return "Panel"
end

return NoticeRules

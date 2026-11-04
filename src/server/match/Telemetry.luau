--!strict
-- Telemetría de partidas (Tarea 7): al terminar una partida —o al abandonarla— deja un resumen para
-- medir los criterios de salida de la ficha. El resumen se construye con `MatchSummary`, que es puro,
-- y se publica de dos formas:
--
--   · una línea de etiqueta y, debajo, el JSON desnudo con la lista de resúmenes: la última línea es
--     el archivo que lee `tools/criteria-report`, sin quitarle ningún prefijo (Roblox no deja
--     escribir ficheros desde el servidor);
--   · un evento `MatchSummary` de `AnalyticsService`, atribuido a un jugador presente, con la
--     duración como valor y el tamaño y el modo como campos de desglose.
--
-- Nunca frena la partida: todo va protegido con `pcall`, el envío no espera y un fallo solo se avisa
-- una vez. Si `AnalyticsService` no está disponible (por ejemplo en Studio), el resumen local sigue
-- existiendo y solo se pierde el evento remoto.
--
-- Se engancha a `MatchService` sin espiarlo: `onStart` avisa de cada partida nueva, `onAbandon` del
-- abandono y `current()`/`finished` del final normal, que es lo único que el servicio publica. La
-- partida terminada se sondea con el latido de `Scenes`, igual que hace `RematchService`, y se
-- cierra también al irse un jugador para no perderla si el servidor se apaga (R-P7, R-P8, R-P28).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local MatchService = require("./MatchService")
local MatchSummary = require("./MatchSummary")
local Scenes = require("../../shared/config/Scenes")

type Match = MatchService.Match
type Summary = MatchSummary.Summary

-- Nombre del evento personalizado. No lleva datos personales: el `player` es la atribución que pide
-- la API de Roblox, no un campo del resumen.
local EVENT_NAME = "MatchSummary"

local Telemetry = {}

local started = false
-- Partidas arrancadas en este servidor, en orden. La segunda y siguientes son revanchas: en un
-- servidor solo se sustituye una partida terminada por otra, y eso solo lo hace `RematchService`
-- (R-P21). No hace falta un identificador de grupo (R-P16).
local starts = 0
-- Número de partida de cada objeto `Match`. Claves débiles: el resumen de una partida no debe
-- retener su estado cuando ya no hay ninguna referencia. El `:: any` es solo para que el tipo de la
-- tabla débil sea el del mapa y no el de la metatabla.
local ordinals: { [Match]: number } = setmetatable({}, { __mode = "k" }) :: any
-- Partidas cuyo resumen ya se cerró, para que el abandono y el vigilante no lo hagan dos veces.
local recorded: { [Match]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- Resúmenes de este servidor, en orden. Es la copia que un comando de Studio o el plan 10 puede leer;
-- la exportación que consume la herramienta son las líneas JSON de la salida.
local summaries: { Summary } = {}
-- Servicio de analítica, resuelto una sola vez, y aviso único de degradación.
local analyticsService: AnalyticsService? = nil
local analyticsResolved = false
local warned = false

local function degrade(reason: string)
	if warned then
		return
	end
	warned = true
	warn(`Telemetry: {reason}. La partida sigue y el resumen local se conserva.`)
end

local function analytics(): AnalyticsService?
	if analyticsResolved then
		return analyticsService
	end
	analyticsResolved = true
	local ok: boolean, service: any = pcall(function()
		return game:GetService("AnalyticsService")
	end)
	if ok and service ~= nil then
		analyticsService = service :: AnalyticsService
	end
	return analyticsService
end

-- Primer jugador de la partida que sigue conectado. `AnalyticsService:LogCustomEvent` exige un
-- `Player` al que atribuir el evento; la identidad no viaja en el resumen ni se guarda.
local function firstPresent(match: Match): Player?
	for _, statePlayer in match.state.players do
		local player: Player? = match.players[statePlayer.id]
		if player ~= nil and player.Parent ~= nil then
			return player
		end
	end
	return nil
end

-- Envía el resumen a AnalyticsService sin esperar y sin dejar que un fallo salga de aquí. El evento
-- no lleva nombres ni ids: solo la duración y tres campos de desglose (la API documentada admite
-- como mucho esos tres campos con nombre propio).
local function send(summary: Summary, player: Player?)
	if player == nil then
		return
	end
	local service = analytics()
	if service == nil then
		degrade("AnalyticsService no está disponible")
		return
	end
	local ok: boolean, err: any = pcall(function()
		service:LogCustomEvent(player, EVENT_NAME, summary.durationSec, {
			CustomField01 = summary.sizeId,
			CustomField02 = summary.endMode,
			CustomField03 = if summary.finished then "Finished" else "Unfinished",
		})
	end)
	if not ok then
		degrade(`AnalyticsService:LogCustomEvent falló: {err}`)
	end
end

-- Deja los resúmenes donde la herramienta pueda leerlos: la etiqueta va en su propia línea y debajo
-- va el JSON desnudo de la lista completa. La última línea de la salida es un arreglo JSON válido y
-- se guarda tal cual como `telemetry/summaries.json`, sin editar nada. `HttpService` no necesita HTTP
-- habilitado para codificar, y si fallara, los resúmenes en memoria siguen ahí.
local function publish(summary: Summary)
	table.insert(summaries, summary)
	local ok: boolean, encoded: any = pcall(function()
		return HttpService:JSONEncode(summaries)
	end)
	if ok then
		print("Telemetry: resúmenes de este servidor (la línea siguiente es el JSON):")
		print(encoded)
	else
		degrade(`no se pudo codificar el resumen: {encoded}`)
	end
end

-- Cierra el resumen de una partida. Es idempotente: lo llaman el aviso de abandono y el vigilante,
-- y solo el primero que llegue lo publica. `observations.endedAt` lo fija `MatchState` al terminar o
-- al abandonar; si faltara, se usa el reloj del servidor.
local function record(match: Match)
	if recorded[match] then
		return
	end
	recorded[match] = true
	local observations = match.matchState.observations
	local endedAt = observations.endedAt or MatchService.now()
	local ordinal = ordinals[match]
	local summary = MatchSummary.fromState(
		match.state,
		observations.startedAt,
		endedAt,
		ordinal ~= nil and ordinal > 1,
		match.abandoned,
		observations
	)
	publish(summary)
	send(summary, firstPresent(match))
end

-- Un fallo al cerrar el resumen no puede tumbar el abandono ni el latido de la partida.
local function recordSafely(match: Match)
	local ok: boolean, err: any = pcall(record, match)
	if not ok then
		warn(`Telemetry: no se pudo cerrar el resumen de la partida: {err}`)
	end
end

-- Vigila la partida vigente: un final normal no avisa por ningún gancho, así que se sondea con el
-- mismo latido que usa el servidor. Un final por abandono lo cierra antes su propio aviso.
local function watch()
	while true do
		task.wait(Scenes.heartbeatSec)
		local match = MatchService.current()
		if match ~= nil and match.finished then
			recordSafely(match)
		end
	end
end

-- Arranca el servicio una sola vez por servidor. Debe llamarse antes de que empiece la primera
-- partida: si se enganchara después, la partida ya en curso se contaría como la primera y una
-- revancha en curso se marcaría mal.
function Telemetry.start()
	if started then
		return
	end
	started = true
	MatchService.onStart(function(match: Match)
		starts += 1
		ordinals[match] = starts
		-- El abandono cierra el resumen en el acto: cuando se van todos los jugadores el servidor
		-- puede apagarse antes del siguiente latido y el resumen no puede perderse.
		match:onAbandon(function()
			recordSafely(match)
		end)
	end)
	-- Si la partida ya terminó y se va el último jugador, el servidor puede cerrarse antes del
	-- siguiente latido: el resumen se cierra aquí. Es idempotente con el vigilante y con el aviso de
	-- abandono.
	Players.PlayerRemoving:Connect(function()
		local match = MatchService.current()
		if match ~= nil and match.finished then
			recordSafely(match)
		end
	end)
	task.spawn(watch)
end

-- Resúmenes de este servidor, en orden de cierre. Es una copia: quien la recorra no toca la lista.
function Telemetry.summaries(): { Summary }
	return table.clone(summaries)
end

return Telemetry

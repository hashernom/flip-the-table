--!strict
-- Reglas de las mesas del lobby (puras, sin `Instance`): quién está sentado, cuándo empieza la cuenta atrás y
-- qué dice el cartel. Una mesa arranca partida con quienes estén sentados al acabar la cuenta: con 2 o más
-- empieza a contar, cada nuevo jugador da unos segundos más y, llena, arranca enseguida.
local Lobby = require("../../shared/config/Lobby")

export type Table = {
	id: string,
	seats: number,
	-- userIds sentados, en el orden en que se sentaron.
	seated: { number },
	-- Momento (en segundos) en que arranca la partida, o nil si no cuenta.
	startsAt: number?,
	-- Ya se está teletransportando: nadie más entra ni sale de la cuenta.
	starting: boolean,
}

local TableRules = {}

function TableRules.new(id: string, seats: number): Table
	return { id = id, seats = seats, seated = {}, startsAt = nil, starting = false }
end

-- Recalcula la cuenta atrás tras un cambio. `joined` dice si alguien acaba de sentarse.
local function retime(tableData: Table, now: number, joined: boolean)
	local count = #tableData.seated
	if count < Lobby.minPlayers then
		tableData.startsAt = nil
		return
	end
	local current = tableData.startsAt
	local startsAt: number
	if current == nil then
		startsAt = now + Lobby.tableCountdownSec
	else
		startsAt = current
	end
	if current ~= nil and joined then
		-- Quien llega a última hora no se queda sin ver la cuenta.
		startsAt = math.max(startsAt, now + Lobby.tableJoinGraceSec)
	end
	if count >= tableData.seats then
		startsAt = math.min(startsAt, now + Lobby.tableFullSec)
	end
	tableData.startsAt = startsAt
end

-- Alguien se sienta. Devuelve false si ya estaba, si la mesa está llena o si ya arranca.
function TableRules.sit(tableData: Table, userId: number, now: number): boolean
	if tableData.starting or #tableData.seated >= tableData.seats or table.find(tableData.seated, userId) then
		return false
	end
	table.insert(tableData.seated, userId)
	retime(tableData, now, true)
	return true
end

-- Alguien se levanta (o se va del juego). No hace nada si no estaba.
function TableRules.leave(tableData: Table, userId: number, now: number)
	local index = table.find(tableData.seated, userId)
	if index == nil then
		return
	end
	table.remove(tableData.seated, index)
	retime(tableData, now, false)
end

-- ¿Toca arrancar ya?
function TableRules.ready(tableData: Table, now: number): boolean
	local startsAt = tableData.startsAt
	return not tableData.starting
		and startsAt ~= nil
		and now >= startsAt
		and #tableData.seated >= Lobby.minPlayers
end

-- Segundos que faltan, redondeados hacia arriba, o nil si no cuenta.
function TableRules.secondsLeft(tableData: Table, now: number): number?
	local startsAt = tableData.startsAt
	if startsAt == nil then
		return nil
	end
	return math.max(0, math.ceil(startsAt - now))
end

-- Texto del cartel de la mesa.
function TableRules.label(tableData: Table, now: number): string
	local count = #tableData.seated
	local head = `{count}/{tableData.seats}`
	if tableData.starting then
		return `{head} · ¡Vamos a la partida!`
	end
	local left = TableRules.secondsLeft(tableData, now)
	if left ~= nil then
		return `{head} · Empieza en {left} s`
	end
	if count == 1 then
		return `{head} · Falta 1 jugador`
	end
	return `{head} · Siéntate para jugar`
end

-- Tras un teletransporte fallido, la mesa vuelve a esperar con quien siga sentado.
function TableRules.reset(tableData: Table, now: number)
	tableData.starting = false
	tableData.startsAt = nil
	retime(tableData, now, false)
end

return TableRules

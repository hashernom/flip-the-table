--!strict
-- Reglas de los menús sociales (tratos y pactos). Son puras y leen la vista del jugador: cuándo se
-- enseñan los botones, a quién se puede proponer, qué casillas se pueden poner en un trato y cuántas
-- ofertas esperan respuesta. Los menús solo pintan lo que aquí se decide.
--
-- Reflejan las reglas del motor (`Trade.proposeReason`, `Pact.proposeReason`): proponer exige estar
-- en turno, en AwaitRoll o AwaitEnd, y el rival tiene que estar activo; responder y romper valen en
-- cualquier fase de turno. El servidor sigue validando: esto solo evita ofrecer lo que se rechazaría.
local Economy = require("../../shared/config/Economy")
local Types = require("../../shared/rules/Types")
local Ui = require("../../shared/config/Ui")

type Action = Types.Action
type PlayerId = Types.PlayerId

export type SocialButton = { id: string, label: string, action: Action }

-- Lo elegido en el menú de tratos: rival, dinero y casillas de cada lado.
export type Selection = {
	targetId: PlayerId?,
	giveCash: number,
	wantCash: number,
	giveSquares: { number },
	wantSquares: { number },
}

local TURN_PHASES = { "AwaitRoll", "AwaitBuy", "AwaitEnd" }
local PROPOSE_PHASES = { "AwaitRoll", "AwaitEnd" }

local SocialRules = {}

local function me(view: any): any?
	for _, seated in view.players do
		if seated.id == view.playerId then
			return seated
		end
	end
	return nil
end

-- ¿Pueden abrirse los menús sociales? Solo un jugador activo y en una fase de turno: en una subasta,
-- un duelo o al acabar la partida no hay nada que tratar.
function SocialRules.available(view: any): boolean
	local own = me(view)
	return own ~= nil and own.status == "Active" and table.find(TURN_PHASES, view.phase) ~= nil
end

-- ¿Puede proponer ahora? Solo en su turno, antes de tirar o al final.
function SocialRules.canPropose(view: any): boolean
	local own = me(view)
	if own == nil or own.status ~= "Active" or table.find(PROPOSE_PHASES, view.phase) == nil then
		return false
	end
	local turn = view.players[view.turnIndex]
	return turn ~= nil and turn.id == view.playerId
end

function SocialRules.incomingTrades(view: any): { any }
	local list: { any } = {}
	local pending = view.pending
	for _, trade in if pending ~= nil and pending.trades ~= nil then pending.trades else {} do
		if trade.toId == view.playerId then
			table.insert(list, trade)
		end
	end
	return list
end

function SocialRules.incomingPacts(view: any): { any }
	local list: { any } = {}
	local pending = view.pending
	for _, offer in if pending ~= nil and pending.pactOffers ~= nil then pending.pactOffers else {} do
		if offer.toId == view.playerId then
			table.insert(list, offer)
		end
	end
	return list
end

-- Botones que abren Tratos y Pactos, con el número de ofertas que esperan respuesta. No son
-- acciones del motor: `main.client` las intercepta (`__OpenTrade`, `__OpenPact`).
function SocialRules.buttonsFor(view: any): { SocialButton }
	if not SocialRules.available(view) then
		return {}
	end
	local function label(base: string, count: number): string
		return if count > 0 then `{base} ({count})` else base
	end
	return {
		{
			id = "Trade",
			label = label("Tratos", #SocialRules.incomingTrades(view)),
			action = { type = "__OpenTrade" },
		},
		{
			id = "Pact",
			label = label("Pactos", #SocialRules.incomingPacts(view)),
			action = { type = "__OpenPact" },
		},
	}
end

-- Rivales a quienes se puede proponer: los activos que no son uno mismo.
function SocialRules.rivals(view: any): { PlayerId }
	local list: { PlayerId } = {}
	for _, seated in view.players do
		if seated.id ~= view.playerId and seated.status == "Active" then
			table.insert(list, seated.id)
		end
	end
	return list
end

-- Casillas de un jugador que pueden entrar en un trato: las suyas y sin edificios, en orden. El
-- motor rechaza intercambiar una propiedad con edificios.
function SocialRules.tradeableSquares(view: any, ownerId: PlayerId): { number }
	local list: { number } = {}
	for index, property in view.properties do
		if property.ownerId == ownerId and property.level == 0 then
			table.insert(list, index)
		end
	end
	table.sort(list)
	return list
end

-- Los elementos de `chosen` que siguen siendo válidos, sin repetir y en orden.
local function keepValid(chosen: { number }, valid: { number }): { number }
	local allowed: { [number]: boolean } = {}
	for _, index in valid do
		allowed[index] = true
	end
	local seen: { [number]: boolean } = {}
	local out: { number } = {}
	for _, index in chosen do
		if allowed[index] and not seen[index] then
			seen[index] = true
			table.insert(out, index)
		end
	end
	table.sort(out)
	return out
end

-- Propuesta de trato lista para mandar, o nil si falta rival o no ofrece ni pide nada. Depura lo
-- elegido contra la vista de ahora: la selección puede venir de una vista anterior y una casilla
-- pudo cambiar de dueño o ganar un edificio.
function SocialRules.proposal(view: any, selection: Selection): Action?
	local targetId = selection.targetId
	if targetId == nil or table.find(SocialRules.rivals(view), targetId) == nil then
		return nil
	end
	local own = me(view)
	local cash = if own ~= nil then own.cash else 0
	local giveCash = math.max(0, math.min(math.floor(selection.giveCash), cash))
	local wantCash = math.max(0, math.floor(selection.wantCash))
	local giveSquares = keepValid(selection.giveSquares, SocialRules.tradeableSquares(view, view.playerId))
	local wantSquares = keepValid(selection.wantSquares, SocialRules.tradeableSquares(view, targetId))
	if giveCash + wantCash == 0 and #giveSquares == 0 and #wantSquares == 0 then
		return nil
	end
	return {
		type = "ProposeTrade",
		offer = {
			toId = targetId,
			giveCash = giveCash,
			wantCash = wantCash,
			giveSquares = giveSquares,
			wantSquares = wantSquares,
		},
	}
end

-- Siguiente importe de una lista ordenada en la dirección pedida (+1 o -1); en el extremo se queda.
function SocialRules.nextStep(steps: { number }, current: number, direction: number): number
	if direction >= 0 then
		for _, step in steps do
			if step > current then
				return step
			end
		end
		return steps[#steps]
	end
	for index = #steps, 1, -1 do
		if steps[index] < current then
			return steps[index]
		end
	end
	return steps[1]
end

-- Duraciones de pacto que se ofrecen: las de la configuración que el motor acepta.
function SocialRules.pactRounds(): { number }
	local list: { number } = {}
	for _, rounds in Ui.pactRoundOptions do
		if rounds >= Economy.pact.minRounds and rounds <= Economy.pact.maxRounds then
			table.insert(list, rounds)
		end
	end
	return list
end

-- Pactos en los que participa el jugador, con el otro socio.
function SocialRules.ownPacts(view: any): { { id: string, partnerId: PlayerId, untilRound: number } }
	local list: { { id: string, partnerId: PlayerId, untilRound: number } } = {}
	for _, pact in view.pacts or {} do
		if pact.a == view.playerId or pact.b == view.playerId then
			table.insert(list, {
				id = pact.id,
				partnerId = if pact.a == view.playerId then pact.b else pact.a,
				untilRound = pact.untilRound,
			})
		end
	end
	return list
end

return SocialRules

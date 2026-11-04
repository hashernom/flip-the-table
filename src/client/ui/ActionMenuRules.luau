--!strict
-- Reglas del menú de acciones. Convierten las acciones legales que manda el servidor en botones y
-- deciden cuándo hace falta el control de puja. Son puras: no crean ni tocan `Instance`, así que se
-- prueban con Lune y la interfaz solo pinta lo que aquí se decide.
--
-- Principio: un botón existe si y solo si su acción es legal. Esconder una acción que el servidor
-- acepta dejaría al jugador sin salida, así que una acción desconocida también se muestra, con su
-- tipo por nombre.
local Economy = require("../../shared/config/Economy")
local Types = require("../../shared/rules/Types")

type Action = Types.Action

export type Button = {
	-- Identificador único dentro del menú: el tipo, más el índice o la carta cuando hay varias.
	id: string,
	label: string,
	action: Action,
}

export type BidControl = {
	min: number,
	max: number,
	step: number,
	-- Salto grande, para no pulsar «+» veinte veces con solo 15 s de subasta.
	jump: number,
}

-- Lo que el menú sabe de la mesa además de las acciones legales: la vista del jugador y los nombres
-- que `main.client` resolvió. Sin contexto los botones se quedan con su etiqueta genérica.
export type Context = {
	view: any?,
	names: { [string]: string }?,
}

-- Etiqueta de cada acción, en el idioma del juego. Las que llevan objeto se completan más abajo.
local LABELS: { [string]: string } = {
	DraftPerk = "Elegir perk",
	Roll = "Tirar dados",
	RerollDie = "Repetir dado",
	Buy = "Comprar",
	DeclineBuy = "No comprar",
	PlayCard = "Jugar carta",
	React = "Reaccionar",
	PassReaction = "Pasar",
	Build = "Construir",
	ProposeTrade = "Proponer trato",
	RespondTrade = "Responder trato",
	ProposePact = "Proponer pacto",
	RespondPact = "Responder pacto",
	BreakPact = "Romper pacto",
	TribunalVote = "Votar castigo",
	DuelChoice = "Elegir jugada",
	MarketBuy = "Comprar del mercado",
	MarketSkip = "Pasar del mercado",
	GhostAct = "Actuar como espectro",
	EndTurn = "Terminar turno",
}

local ActionMenuRules = {}

-- Nombre visible de un botón. Las acciones con objeto lo llevan en la etiqueta, porque en el menú
-- aparecen varias a la vez y «Construir» a secas no dice en qué casilla.
function ActionMenuRules.labelFor(action: Action): string
	local actionType = action.type
	local base = LABELS[actionType]
	if base == nil then
		return actionType
	end
	if actionType == "Build" or actionType == "MarketBuy" then
		local index = action.index
		if type(index) == "number" then
			return `{base} {index}`
		end
	elseif actionType == "PlayCard" or actionType == "React" then
		if type(action.cardId) == "string" then
			return `{base}: {action.cardId}`
		end
	elseif actionType == "GhostAct" then
		if action.kind == "Haunt" and type(action.index) == "number" then
			return `Embrujar {action.index}`
		end
		return "Sabotear"
	end
	return base
end

-- Identificador único del botón. Dos acciones del mismo tipo sobre casillas distintas tienen que
-- poder convivir en el mismo menú.
local function idFor(action: Action): string
	local actionType = action.type
	if actionType == "Build" or actionType == "MarketBuy" then
		return `{actionType}:{tostring(action.index)}`
	elseif actionType == "PlayCard" or actionType == "React" then
		return `{actionType}:{tostring(action.cardId)}`
	elseif actionType == "GhostAct" then
		return `{actionType}:{tostring(action.kind)}:{tostring(action.index)}`
	end
	return actionType
end

-- Efectivo del propio jugador en la vista, o nil si no se conoce.
function ActionMenuRules.ownCash(context: Context?): number?
	local view = if context ~= nil then context.view else nil
	if view == nil then
		return nil
	end
	for _, seated in view.players do
		if seated.id == view.playerId then
			return seated.cash
		end
	end
	return nil
end

-- Botones del menú, en el orden en que el motor enumera sus acciones. Una puja no es un botón: tiene
-- su propio control, así que se cambia por el botón de confirmar.
function ActionMenuRules.buttonsFor(legal: { Action }, context: Context?): { Button }
	local buttons: { Button } = {}
	for _, action in legal do
		if action.type == "Bid" then
			local bounds = ActionMenuRules.bidControl(legal, ActionMenuRules.ownCash(context))
			if bounds ~= nil then
				table.insert(buttons, {
					id = "BidConfirm",
					label = `Pujar {bounds.min}`,
					action = { type = "Bid", amount = bounds.min },
				})
			end
		else
			table.insert(buttons, {
				id = idFor(action),
				label = ActionMenuRules.labelFor(action),
				action = action,
			})
		end
	end
	return buttons
end

-- Límites del control de puja, o nil si no hay ninguna puja legal. El mínimo es la puja que el motor
-- enumera (`min(alta + paso, efectivo)`) y el máximo, el efectivo del jugador: el motor acepta
-- cualquier entero entre las dos. Sin efectivo conocido, el rango se reduce a esa puja.
function ActionMenuRules.bidControl(legal: { Action }, cash: number?): BidControl?
	for _, action in legal do
		if action.type == "Bid" then
			local enumerated = action.amount
			local step = Economy.auctionBidStep
			local min = if type(enumerated) == "number" and enumerated > 0 then enumerated else step
			local max = if cash ~= nil then math.max(min, cash) else min
			return { min = min, max = max, step = step, jump = Economy.auctionBidJump }
		end
	end
	return nil
end

-- Puja elegida tras una vista nueva: se conserva lo que el jugador había elegido, acotado al rango de
-- ahora (la puja alta puede haber subido o su efectivo haber bajado). Sin elección previa, el mínimo.
function ActionMenuRules.clampBid(previous: number?, control: BidControl): number
	if previous == nil then
		return control.min
	end
	return math.max(control.min, math.min(control.max, previous))
end

-- Un lado de un trato: dinero, casillas, las dos cosas o «nada».
local function offerSide(cash: number, squares: { number }): string
	local parts: { string } = {}
	if cash > 0 then
		table.insert(parts, tostring(cash))
	end
	if #squares > 0 then
		local noun = if #squares == 1 then "casilla" else "casillas"
		table.insert(parts, `{noun} {table.concat(squares, ", ")}`)
	end
	return if #parts > 0 then table.concat(parts, " + ") else "nada"
end

-- Texto de un trato guardado en `pending.trades`, desde el punto de vista de quien lo propone.
function ActionMenuRules.offerText(trade: any): string
	return `{offerSide(trade.giveCash, trade.giveSquares)} por {offerSide(trade.wantCash, trade.wantSquares)}`
end

-- Segundos que quedan de una decisión. Sin plazo conocido no hay cuenta atrás: el menú esconde el
-- temporizador en vez de inventarse uno.
function ActionMenuRules.remainingSeconds(deadline: number?, now: number): number?
	if deadline == nil then
		return nil
	end
	return math.max(0, deadline - now)
end

return ActionMenuRules

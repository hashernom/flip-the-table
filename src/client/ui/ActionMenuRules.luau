--!strict
-- Reglas del menú de acciones. Convierten las acciones legales que manda el servidor en botones y
-- deciden cuándo hace falta el control de puja. Son puras: no crean ni tocan `Instance`, así que se
-- prueban con Lune y la interfaz solo pinta lo que aquí se decide.
--
-- Principio: un botón existe si y solo si su acción es legal. Esconder una acción que el servidor
-- acepta dejaría al jugador sin salida, así que una acción desconocida también se muestra, con su
-- tipo por nombre.
local Economy = require("../../shared/config/Economy")
local HudRules = require("./HudRules")
local Types = require("../../shared/rules/Types")
local Property = require("../../shared/rules/Property")
local Strings = require("../../shared/config/Strings")
local UiIcons = require("../../shared/config/UiIcons")
local ViewText = require("./ViewText")

type Action = Types.Action

export type Button = {
	-- Identificador único dentro del menú: el tipo, más el índice o la carta cuando hay varias.
	id: string,
	label: string,
	-- Sin acción, el botón es solo un aviso.
	action: Action?,
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
	SellBuilding = "Vender edificio",
	Mortgage = "Hipotecar",
	Unmortgage = "Levantar hipoteca",
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

-- Acciones que pueden ser el botón amarillo, de más a menos importante. Solo hay uno por pantalla.
local PRIMARY_RANK: { [string]: number } = { Buy = 1, Bid = 2, Roll = 3, EndTurn = 4 }

-- Fases que encabezan el panel con un título.
local PANEL_TITLES: { [string]: boolean } = {
	PerkDraft = true,
	Auction = true,
	Reaction = true,
	Tribunal = true,
	Duel = true,
	Market = true,
	GhostTurn = true,
}

local ActionMenuRules = {}

-- Nombre visible de un botón. Con la vista (`context`) las acciones con objeto lo llevan en la
-- etiqueta, por su nombre: en el menú aparecen varias a la vez y «Construir» a secas no dice dónde.
-- Sin ella se cae a una etiqueta genérica, que es lo que ven las pruebas de forma.
function ActionMenuRules.labelFor(action: Action, context: Context?): string
	if context ~= nil and context.view ~= nil then
		return ViewText.actionLabel(context.view, context.names, action)
	end
	local actionType = action.type
	local base = LABELS[actionType]
	if base == nil then
		return actionType
	end
	if actionType == "Build" then
		local index = action.index
		if type(index) == "number" then
			return `{base} {index}`
		end
	elseif actionType == "MarketBuy" or actionType == "PlayCard" or actionType == "React" then
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

-- Identificador único del botón: el tipo y todos los campos de la acción, en orden. Dos acciones del
-- mismo tipo que difieren en cualquier campo (rival, jugada, objetivo, carta) tienen ids distintos.
function ActionMenuRules.idFor(action: Action): string
	local keys: { string } = {}
	for key in action do
		if key ~= "type" then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	local parts: { string } = { action.type }
	for _, key in keys do
		table.insert(parts, `{key}={tostring(action[key])}`)
	end
	return table.concat(parts, ":")
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
				id = ActionMenuRules.idFor(action),
				label = ActionMenuRules.labelFor(action, context),
				action = action,
			})
		end
	end
	-- Quien va ganando no tiene jugada legal. Sin este aviso, el panel desaparecería y volvería con cada
	-- puja del rival. No lleva acción: no se puede pulsar.
	local view = if context ~= nil then context.view else nil
	local auction = if view ~= nil and view.pending ~= nil then view.pending.auction else nil
	if view ~= nil and view.phase == "Auction" and auction ~= nil and auction.highBidder == view.playerId then
		table.insert(buttons, { id = "BidLeading", label = `Vas ganando con {auction.high}` })
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

-- Un lado de un trato: dinero, casillas, las dos cosas o «nada». Con `squareName` las casillas se
-- nombran («Caldas»); sin él se enseña su número, como en las pruebas de forma.
local function offerSide(cash: number, squares: { number }, squareName: ((number) -> string)?): string
	local parts: { string } = {}
	if cash > 0 then
		table.insert(parts, tostring(cash))
	end
	if #squares > 0 then
		if squareName ~= nil then
			local named: { string } = {}
			for _, index in squares do
				table.insert(named, squareName(index))
			end
			table.insert(parts, table.concat(named, ", "))
		else
			local noun = if #squares == 1 then "casilla" else "casillas"
			table.insert(parts, `{noun} {table.concat(squares, ", ")}`)
		end
	end
	return if #parts > 0 then table.concat(parts, " + ") else "nada"
end

-- Texto de un trato guardado en `pending.trades`, desde el punto de vista de quien lo propone.
function ActionMenuRules.offerText(trade: any, squareName: ((number) -> string)?): string
	local give = offerSide(trade.giveCash, trade.giveSquares, squareName)
	return `{give} por {offerSide(trade.wantCash, trade.wantSquares, squareName)}`
end

-- Datos de la escritura de una casilla. Las cifras salen del motor; la carta solo las pinta.
function ActionMenuRules.deedFor(view: any, index: number): any?
	local board = ViewText.board(view.sizeId)
	local square = board.squares[index]
	if square == nil or square.kind ~= "Property" or square.zoneId == nil or square.price == nil then
		return nil
	end
	local zone = Strings.zone(square.zoneId)
	local rents = {}
	for position, amount in Property.rentTable(square.price) do
		table.insert(rents, { label = Strings.buildingLevel(position - 1), amount = amount })
	end
	local zoneNumber = table.find(board.zoneOrder, square.zoneId) or 0
	local symbol = `zone-{square.zoneId}`
	return {
		zoneName = zone.name,
		zoneColor = zone.color,
		symbol = if UiIcons[symbol] ~= nil then symbol else nil,
		name = ViewText.squareName(view, index),
		price = Property.priceFor(
			{ board = board, players = view.players, pending = view.pending } :: any,
			view.playerId,
			index
		),
		rents = rents,
		code = `{view.sizeId}-{string.format("%02d", zoneNumber)} · {index}`,
	}
end

export type Panel = {
	title: string?,
	deed: any?,
	-- El único botón amarillo de la pantalla, y su texto corto.
	primary: Button?,
	primaryText: string?,
	-- Renuncia a comprar: la segunda salida, con tecla propia.
	decline: Button?,
	options: { Button },
	bid: BidControl?,
}

-- Qué enseña el panel de decisión. Todo botón legal aparece en algún sitio: lo que no es la acción
-- principal ni la renuncia se queda en la lista de opciones.
function ActionMenuRules.panelFor(legal: { Action }, context: Context?): Panel
	local view: any = if context ~= nil then context.view else nil
	local pending: any = if view ~= nil and view.pending ~= nil then view.pending else {}
	local panel: Panel = { options = {} }
	local buttons = ActionMenuRules.buttonsFor(legal, context)
	if #buttons == 0 then
		return panel
	end
	panel.bid = ActionMenuRules.bidControl(legal, ActionMenuRules.ownCash(context))
	if view ~= nil then
		if view.phase == "AwaitBuy" and type(pending.index) == "number" then
			panel.deed = ActionMenuRules.deedFor(view, pending.index)
		elseif view.phase == "Auction" and pending.auction ~= nil then
			panel.deed = ActionMenuRules.deedFor(view, pending.auction.index)
		end
		if PANEL_TITLES[view.phase] then
			panel.title = Strings.get(`panel.{view.phase}`)
		end
	end
	local chosen: { [string]: Button } = {}
	for _, button in buttons do
		local kind = if button.action ~= nil then button.action.type else button.id
		if PRIMARY_RANK[kind] ~= nil then
			local current = panel.primary
			local currentKind = if current ~= nil and current.action ~= nil then current.action.type else ""
			if current == nil or PRIMARY_RANK[kind] < (PRIMARY_RANK[currentKind] or math.huge) then
				panel.primary = button
			end
		elseif kind == "DeclineBuy" then
			panel.decline = button
			chosen[button.id] = button
		end
	end
	local primary = panel.primary
	if primary ~= nil then
		chosen[primary.id] = primary
		local kind = if primary.action ~= nil then primary.action.type else primary.id
		if kind == "Buy" then
			panel.primaryText = Strings.get("action.buy")
		elseif kind == "Roll" then
			panel.primaryText = Strings.get(if pending.heldRoll ~= nil then "action.move" else "action.roll")
		elseif kind == "EndTurn" then
			panel.primaryText = Strings.get("action.endTurn")
		elseif kind == "Bid" then
			panel.primaryText =
				Strings.get("action.bid", { amount = HudRules.formatMoney((primary.action :: any).amount) })
		end
	end
	for _, button in buttons do
		if chosen[button.id] == nil then
			table.insert(panel.options, button)
		end
	end
	return panel
end

-- Acciones que no tienen vuelta atrás: necesitan una segunda pulsación. Romper un pacto, renunciar a
-- comprar, responder un trato y rechazar un pacto son irreversibles; aceptar un pacto no lo es.
-- Separa las jugadas de carta del resto: las cartas se juegan desde la mano (clic en la carta y confirmar
-- dentro de su vista grande), no desde el panel. Devuelve lo que queda para el panel y las jugadas de
-- cada carta, una por objetivo posible. Las reacciones se quedan en el panel: son una decisión con plazo.
-- R-P53: las acciones de gestión (construir, vender, hipotecar y levantar la hipoteca) no van en el
-- panel: van en «Gestionar propiedades», agrupadas por casilla. Devuelve lo que queda para el panel.
local MANAGE: { [string]: boolean } =
	{ Build = true, SellBuilding = true, Mortgage = true, Unmortgage = true }

function ActionMenuRules.splitManageActions(legal: { Action }): ({ Action }, { [number]: { Action } })
	local rest: { Action } = {}
	local byIndex: { [number]: { Action } } = {}
	for _, action in legal do
		if MANAGE[action.type] and type(action.index) == "number" then
			local list = byIndex[action.index]
			if list == nil then
				list = {}
				byIndex[action.index] = list
			end
			table.insert(list, action)
		else
			table.insert(rest, action)
		end
	end
	return rest, byIndex
end

function ActionMenuRules.splitHandActions(legal: { Action }): ({ Action }, { [string]: { Action } })
	local rest: { Action } = {}
	local byCard: { [string]: { Action } } = {}
	for _, action in legal do
		if action.type == "PlayCard" and type(action.cardId) == "string" then
			local list = byCard[action.cardId]
			if list == nil then
				list = {}
				byCard[action.cardId] = list
			end
			table.insert(list, action)
		else
			table.insert(rest, action)
		end
	end
	return rest, byCard
end

function ActionMenuRules.needsConfirm(action: Action): boolean
	local actionType = action.type
	if actionType == "BreakPact" or actionType == "DeclineBuy" or actionType == "RespondTrade" then
		return true
	end
	if actionType == "RespondPact" then
		return action.accept == false
	end
	return false
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

--!strict
-- Textos de la interfaz, en español y puros. Convierten lo que el motor y `View` mandan (ids, índices
-- de casilla, `userId` en texto) en frases que un jugador entiende: nombres de personas, de casillas,
-- de cartas y de perks. No crean ni tocan `Instance`, así que se prueban con Lune contra vistas
-- salidas de `Engine` y `View`, y los menús solo pintan lo que sale de aquí.
--
-- Las fórmulas no se repiten: precios y costes salen de `Property.priceFor`, `Building.costOf` y
-- `Squares.marketPriceFor`, que aceptan una vista porque solo leen tablero, jugadores y `pending`.
local Boards = require("../../shared/config/Boards")
local Building = require("../../shared/rules/Building")
local Cards = require("../../shared/config/Cards")
local Economy = require("../../shared/config/Economy")
local Perks = require("../../shared/config/Perks")
local Property = require("../../shared/rules/Property")
local Squares = require("../../shared/rules/Squares")
local Strings = require("../../shared/config/Strings")
local Types = require("../../shared/rules/Types")

type Action = Types.Action
type Board = Types.Board
type PlayerId = Types.PlayerId

-- Nombre visible de cada asiento, por `PlayerId`. Lo rellena `main.client` con los `Player` de Roblox.
export type Names = { [PlayerId]: string }

local ViewText = {}

-- El tablero es estático y se reconstruye con `Boards.get`, que lo arma entero cada vez: se guarda por
-- tamaño para no rehacerlo con cada texto.
local boards: { [string]: Board } = {}

function ViewText.board(sizeId: string): Board
	local cached = boards[sizeId]
	if cached == nil then
		cached = Boards.get(sizeId :: Types.SizeId)
		boards[sizeId] = cached
	end
	return cached
end

-- Guarda el nombre de quien está sentado. `lookup` resuelve un `PlayerId` a su nombre actual, o nil si
-- esa persona ya no está: el último nombre conocido se conserva, porque un bot puede ocupar el asiento
-- de quien se fue y la mesa sigue hablando de él por su nombre.
function ViewText.rememberNames(names: Names, view: any, lookup: (PlayerId) -> string?)
	if view == nil then
		return
	end
	for _, seated in view.players do
		local found = lookup(seated.id)
		if found ~= nil and found ~= "" then
			names[seated.id] = found
		end
	end
end

-- Nombre de un jugador: el conocido o «Jugador N» con su asiento; con bot lo dice, y el propio lleva
-- «tú» para que «Multa de 150 a Ana (tú)» no deje dudas.
function ViewText.playerName(view: any, names: Names?, id: PlayerId): string
	local seatIndex: number? = nil
	local isBot = false
	for index, seated in view.players do
		if seated.id == id then
			seatIndex = index
			isBot = seated.isBot == true
			break
		end
	end
	local name = if names ~= nil then names[id] else nil
	if name == nil then
		name = if seatIndex ~= nil then `Jugador {seatIndex}` else "Alguien"
	end
	local text: string = name :: string
	if isBot then
		text = `{text} (bot)`
	end
	if id == view.playerId then
		text = `{text} (tú)`
	end
	return text
end

-- Nombre de una casilla: el de la propiedad (por su ordinal dentro de la zona) o el de su tipo.
function ViewText.squareName(view: any, index: number): string
	local board = ViewText.board(view.sizeId)
	local square = board.squares[index]
	if square == nil then
		return `casilla {index}`
	end
	local ordinal: number? = nil
	if square.kind == "Property" and square.zoneId ~= nil then
		local zone = board.zones[square.zoneId]
		ordinal = if zone ~= nil then table.find(zone, index) else nil
	end
	return Strings.squareLabel(square, ordinal)
end

function ViewText.cardName(cardId: string): string
	local card = Cards.byId[cardId]
	return if card ~= nil then card.name else cardId
end

function ViewText.perkName(perkId: string): string
	local perk = Perks.byId[perkId]
	return if perk ~= nil then perk.name else perkId
end

-- Lo mínimo de un estado para las fórmulas del motor: tablero, jugadores y `pending` de la vista.
local function stateLike(view: any): any
	return { board = ViewText.board(view.sizeId), players = view.players, pending = view.pending }
end

local function pendingOf(view: any): any
	return if view.pending ~= nil then view.pending else {}
end

-- Etiqueta de un botón con el objeto de la acción dicho por su nombre: quien lo lee sabe qué compra,
-- a quién retará o dónde construye. Una acción que no se conoce se muestra con su tipo, como siempre.
function ViewText.actionLabel(view: any, names: Names?, action: Action): string
	local actionType = action.type
	local pending = pendingOf(view)
	local me = view.playerId
	local function player(id: any): string
		return ViewText.playerName(view, names, tostring(id))
	end
	local function square(index: any): string
		return if type(index) == "number" then ViewText.squareName(view, index) else "una casilla"
	end

	if actionType == "DraftPerk" then
		local perk = Perks.byId[action.perkId]
		if perk == nil then
			return tostring(action.perkId)
		end
		return `{perk.name}: {perk.description}`
	elseif actionType == "Roll" then
		local held = pending.heldRoll
		if held ~= nil then
			return `Mover con {held.a} y {held.b}`
		end
		return "Tirar dados"
	elseif actionType == "RerollDie" then
		local held = pending.heldRoll
		local which = if action.die == "a" then "primer" else "segundo"
		local value = if held ~= nil then held[action.die] else nil
		return if value ~= nil then `Repetir el {which} dado ({value})` else `Repetir el {which} dado`
	elseif actionType == "Buy" then
		local index = pending.index
		if type(index) ~= "number" then
			return "Comprar"
		end
		return `Comprar {square(index)} por {Property.priceFor(stateLike(view), me, index)}`
	elseif actionType == "DeclineBuy" then
		local index = pending.index
		if type(index) ~= "number" then
			return "No comprar"
		end
		return `No comprar {square(index)} (sale a subasta)`
	elseif actionType == "Build" then
		local index = action.index
		if type(index) ~= "number" then
			return "Construir"
		end
		local property = if view.properties ~= nil then view.properties[index] else nil
		local level = if property ~= nil then property.level + 1 else 1
		local cost = Building.costOf(stateLike(view), me, index)
		return `Construir en {square(index)} (nivel {level}) por {cost}`
	elseif actionType == "PlayCard" then
		local card = Cards.byId[action.cardId]
		local name = ViewText.cardName(tostring(action.cardId))
		if card == nil then
			return `Jugar {name}`
		end
		if card.target == "Player" and action.targetId ~= nil then
			return `Jugar {name} contra {player(action.targetId)}`
		elseif card.target == "Zone" and action.zoneId ~= nil then
			return `Jugar {name} en {Strings.zone(action.zoneId).name}`
		elseif card.target == "Property" and action.index ~= nil then
			return `Jugar {name} sobre {square(action.index)}`
		elseif card.target == "Pact" and action.pactId ~= nil then
			for _, pact in view.pacts or {} do
				if pact.id == action.pactId then
					return `Jugar {name} sobre el pacto de {player(pact.a)} y {player(pact.b)}`
				end
			end
			return `Jugar {name} sobre un pacto`
		end
		return `Jugar {name}`
	elseif actionType == "React" then
		if action.cardId == "BounceRent" and action.targetId ~= nil then
			return `Renta Rebotada: que pague {player(action.targetId)}`
		end
		return `Reaccionar: {ViewText.cardName(tostring(action.cardId))}`
	elseif actionType == "PassReaction" then
		return "No reaccionar"
	elseif actionType == "MarketBuy" then
		local name = ViewText.cardName(tostring(action.cardId))
		local price = Squares.marketPriceFor(stateLike(view), me, tostring(action.cardId))
		return if price ~= nil then `Comprar {name} por {price}` else `Comprar {name}`
	elseif actionType == "MarketSkip" then
		return "No comprar nada"
	elseif actionType == "DuelChoice" then
		if action.rivalId ~= nil then
			return `Retar a {player(action.rivalId)}`
		end
		return Strings.duelChoice(tostring(action.choice))
	elseif actionType == "TribunalVote" then
		local tribunal = pending.tribunal
		local accused = if tribunal ~= nil then player(tribunal.accusedId) else "el acusado"
		if action.verdict == "Fine" then
			return `Multa de {Economy.tribunal.fine} a {accused}`
		elseif action.verdict == "SkipTurn" then
			return `{accused} pierde un turno`
		elseif action.verdict == "PayToPlayer" and action.targetId ~= nil then
			return `{accused} paga {Economy.tribunal.payToPlayer} a {player(action.targetId)}`
		end
		return "Votar castigo"
	elseif actionType == "GhostAct" then
		if action.kind == "Haunt" and type(action.index) == "number" then
			return `Embrujar {square(action.index)}`
		end
		return "Sabotear: robar una carta"
	elseif actionType == "EndTurn" then
		return "Terminar turno"
	end
	return actionType
end

return ViewText

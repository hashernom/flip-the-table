--!strict
-- Bancarrota sin eliminación: cobra una deuda, vende bienes al banco si hace falta y, cuando
-- nada alcanza, convierte al jugador en espectro sin dejar efectivo negativo ni crear dinero.
local Board = require("./Board")
local Economy = require("../config/Economy")
local Types = require("./Types")

type GameState = Types.GameState
type PlayerId = Types.PlayerId
type Player = Types.Player
type Event = Types.Event

-- El banco compra a la mitad. Es una regla fija del contrato, no un valor ajustable.
local BANK_SALE_DIVISOR = 2

-- Un bien vendible: la casilla y lo que el banco paga por él.
type Asset = { index: number, value: number }

local Bankruptcy = {}

local function findPlayer(state: GameState, playerId: PlayerId): Player?
	for _, player in state.players do
		if player.id == playerId then
			return player
		end
	end
	return nil
end

local function playerOf(state: GameState, playerId: PlayerId): Player
	local player = findPlayer(state, playerId)
	if not player then
		error(`Bankruptcy: no existe el jugador {playerId}`, 3)
	end
	return player
end

local function half(value: number): number
	return math.floor(value / BANK_SALE_DIVISOR)
end

local function priceOf(state: GameState, index: number): number
	local price = Board.square(state, index).price
	if not price then
		error(`Bankruptcy: la casilla {index} no es una propiedad`, 3)
	end
	return price
end

-- Coste de un nivel de edificio, con la misma fórmula que Building.costOf. Bankruptcy no puede
-- require Building: el contrato solo le permite Board, Economy y Types.
local function levelCost(state: GameState, index: number): number
	return math.floor(priceOf(state, index) * Economy.buildingCostRate)
end

-- Paga al acreedor solo si sigue activo: nil, Ghost y Left son el banco y no reciben nada.
local function credit(state: GameState, creditorId: PlayerId?, amount: number)
	if not creditorId then
		return
	end
	local creditor = playerOf(state, creditorId)
	if creditor.status ~= "Active" then
		return
	end
	creditor.cash += amount
end

-- Propiedades del jugador en orden ascendente: el desempate entre bienes del mismo valor no
-- depende del orden de las claves de la tabla.
local function ownedSquares(state: GameState, playerId: PlayerId): { number }
	local indices: { number } = {}
	for index, property in state.properties do
		if property.ownerId == playerId then
			table.insert(indices, index)
		end
	end
	table.sort(indices)
	return indices
end

-- Niveles de edificio vendibles, de menor a mayor valor y por casilla si empatan.
local function buildingsOf(state: GameState, playerId: PlayerId): { Asset }
	local assets: { Asset } = {}
	for _, index in ownedSquares(state, playerId) do
		local level = state.properties[index].level
		local value = half(levelCost(state, index))
		for _ = 1, level do
			table.insert(assets, { index = index, value = value })
		end
	end
	table.sort(assets, function(left, right)
		if left.value ~= right.value then
			return left.value < right.value
		end
		return left.index < right.index
	end)
	return assets
end

-- Propiedades vendibles, de menor a mayor valor y por casilla si empatan. El índice no sirve
-- como criterio: dos tableros pueden ordenar precios de otra forma.
local function propertiesOf(state: GameState, playerId: PlayerId): { Asset }
	local assets: { Asset } = {}
	for _, index in ownedSquares(state, playerId) do
		table.insert(assets, { index = index, value = half(priceOf(state, index)) })
	end
	table.sort(assets, function(left, right)
		if left.value ~= right.value then
			return left.value < right.value
		end
		return left.index < right.index
	end)
	return assets
end

-- Vende un nivel al banco: la casilla sigue siendo del jugador hasta que quiebra.
local function sellBuilding(state: GameState, payer: Player, asset: Asset)
	state.properties[asset.index].level -= 1
	payer.cash += asset.value
end

-- Vende la propiedad al banco: vuelve libre y sin edificios.
local function sellProperty(state: GameState, payer: Player, asset: Asset)
	local property = state.properties[asset.index]
	property.level = 0
	property.ownerId = nil
	payer.cash += asset.value
end

-- Devuelve al banco lo que aún quede en manos del jugador quebrado. Con la deuda cubierta no
-- se llega aquí, pero la limpieza es explícita para cumplir el contrato.
local function returnProperties(state: GameState, playerId: PlayerId)
	for _, index in ownedSquares(state, playerId) do
		local property = state.properties[index]
		property.ownerId = nil
		property.level = 0
	end
end

-- Cobra `amount` al jugador. Con efectivo suficiente paga directo; si no, vende bienes al banco
-- de menor a mayor valor; si ni así alcanza, queda con 0, pasa a Ghost y devuelve sus
-- propiedades. Devuelve solo el evento de bancarrota: las ventas no tienen evento propio.
function Bankruptcy.charge(
	state: GameState,
	payerId: PlayerId,
	amount: number,
	creditorId: PlayerId?
): { Event }
	if amount < 0 then
		error(`Bankruptcy.charge: el importe {amount} no puede ser negativo`, 2)
	end
	local payer = playerOf(state, payerId)

	-- 1. Con efectivo suficiente no hay venta ni bancarrota.
	if payer.cash >= amount then
		payer.cash -= amount
		credit(state, creditorId, amount)
		return {}
	end

	-- 2. Vende primero edificios y después propiedades, siempre de menor a mayor valor.
	for _, asset in buildingsOf(state, payerId) do
		if payer.cash >= amount then
			break
		end
		sellBuilding(state, payer, asset)
	end
	for _, asset in propertiesOf(state, payerId) do
		if payer.cash >= amount then
			break
		end
		sellProperty(state, payer, asset)
	end

	if payer.cash >= amount then
		payer.cash -= amount
		credit(state, creditorId, amount)
		return {}
	end

	-- 3. Ni vendiéndolo todo alcanza: paga lo disponible, pasa a espectro y devuelve los bienes.
	local available = payer.cash
	payer.cash = 0
	payer.status = "Ghost"
	-- Nadie se paga a sí mismo; con un acreedor distinto, cobra solo lo que existe.
	if creditorId ~= payerId then
		credit(state, creditorId, available)
	end
	returnProperties(state, payerId)
	-- SEAM Tarea 8: aquí comprobará Turn.finishIfLastActive(state) si queda un solo jugador
	-- Active y emitirá GameEnded. La comprobación se centraliza en Turn, no en este módulo.
	return { { type = "BankruptcyDeclared", playerId = payerId, creditorId = creditorId } }
end

return Bankruptcy

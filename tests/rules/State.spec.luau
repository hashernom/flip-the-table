--!strict
local Harness = require("../harness")
local Board = require("../../src/shared/rules/Board")
local Fixtures = require("../fixtures")
local Rng = require("../../src/shared/rules/Rng")
local State = require("../../src/shared/rules/State")
local Types = require("../../src/shared/rules/Types")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function ids(count: number): { string }
	local playerIds = {}
	for index = 1, count do
		playerIds[index] = `P{index}`
	end
	return playerIds
end

local function orderOf(state: Types.GameState): { string }
	local order = {}
	for index, player in state.players do
		order[index] = player.id
	end
	return order
end

local function sameOrder(a: { string }, b: { string }): boolean
	if #a ~= #b then
		return false
	end
	for index = 1, #a do
		if a[index] ~= b[index] then
			return false
		end
	end
	return true
end

local function zoneOfFirstProperty(state: Types.GameState): string
	local index = Fixtures.squareOf(state, "Property")
	local zoneId = state.board.squares[index].zoneId
	if not zoneId then
		error(`la casilla {index} debería tener zona`, 2)
	end
	return zoneId
end

describe("State.create", function()
	it("asigna tablero y rondas según jugadores", function()
		local s = Fixtures.game({ players = 8 })
		expect(s.sizeId).toBe("L")
		expect(#s.board.squares).toBe(48)
		expect(s.maxRounds).toBe(12)
	end)

	it("rechaza 9 jugadores", function()
		expect(function()
			Fixtures.game({ players = 9 })
		end).toThrow()
	end)

	it("empieza con 1500 en la casilla 1", function()
		local p = Fixtures.game({ players = 4 }).players[1]
		expect(p.cash).toBe(1500)
		expect(p.position).toBe(1)
	end)

	it("admite de 2 a 8 jugadores", function()
		for players = 2, 8 do
			local s = State.create({ playerIds = ids(players), seed = players })
			expect(#s.players).toBe(players)
		end
	end)

	it("rechaza uno y nueve jugadores", function()
		expect(function()
			State.create({ playerIds = ids(1), seed = 1 })
		end).toThrow()
		expect(function()
			State.create({ playerIds = ids(9), seed = 1 })
		end).toThrow()
	end)

	it("rechaza ids repetidos", function()
		expect(function()
			State.create({ playerIds = { "P1", "P1" }, seed = 1 })
		end).toThrow()
	end)

	it("asigna las rondas del tamaño", function()
		expect(Fixtures.game({ players = 2 }).maxRounds).toBe(20)
		expect(Fixtures.game({ players = 4 }).maxRounds).toBe(20)
		expect(Fixtures.game({ players = 5 }).sizeId).toBe("M")
		expect(Fixtures.game({ players = 5 }).maxRounds).toBe(15)
		expect(Fixtures.game({ players = 6 }).maxRounds).toBe(15)
		expect(Fixtures.game({ players = 7 }).maxRounds).toBe(12)
		expect(Fixtures.game({ players = 8 }).maxRounds).toBe(12)
	end)

	it("abre la partida en la primera ronda y esperando tirada", function()
		local s = Fixtures.game({ players = 3 })
		expect(s.round).toBe(1)
		expect(s.turnIndex).toBe(1)
		expect(s.phase).toBe("AwaitRoll")
		expect(#s.players).toBe(3)
		expect(s.pacts).toEqual({})
		expect(s.modifiers).toEqual({})
		expect(s.hotZoneId).toBe(nil)
		expect(s.lastLegendaryRound).toBe(nil)
		expect(s.pending.trades).toEqual({})
	end)

	it("deja a todos activos, sin bienes y con sus estadísticas", function()
		local s = Fixtures.game({ players = 6 })
		for _, p in s.players do
			expect(p.status).toBe("Active")
			expect(p.cash).toBe(1500)
			expect(p.position).toBe(1)
			expect(p.hand).toEqual({})
			expect(p.perks).toEqual({})
			expect(p.fury).toBe(0)
			expect(p.sabotages).toBe(0)
			expect(p.skipTurns).toBe(0)
			expect(p.isBot).toBe(false)
			expect(s.stats[p.id]).toEqual({})
		end
	end)

	it("deja toda propiedad en el banco con nivel 0", function()
		local s = Fixtures.game({ players = 5 })
		local properties = 0
		for _, square in s.board.squares do
			if square.kind == "Property" then
				properties += 1
				expect(s.properties[square.index]).toEqual({ level = 0 })
			end
		end
		expect(properties).toBe(24)
	end)

	it("baraja el orden de turnos con la semilla", function()
		local playerIds = ids(6)
		local rng = Rng.new(11)
		local expected = Rng.shuffle(rng, playerIds)
		local s = State.create({ playerIds = playerIds, seed = 11 })
		expect(orderOf(s)).toEqual(expected)
		expect(s.rng.seed).toBe(rng.seed)
		expect(playerIds).toEqual(ids(6))
	end)

	it("repite el orden con la misma semilla y lo cambia con otra", function()
		local function order(seed: number): { string }
			return orderOf(State.create({ playerIds = ids(5), seed = seed }))
		end
		expect(order(3)).toEqual(order(3))
		local differs = false
		for seed = 1, 20 do
			local shuffled = order(seed)
			local sorted = table.clone(shuffled)
			table.sort(sorted)
			expect(sorted).toEqual(ids(5))
			if not sameOrder(shuffled, ids(5)) then
				differs = true
			end
		end
		expect(differs).toBe(true)
	end)
end)

describe("Board", function()
	it("devuelve la casilla indicada", function()
		local s = Fixtures.game({ players = 2 })
		expect(Board.square(s, 1).kind).toBe("Start")
		expect(Board.square(s, #s.board.squares).index).toBe(#s.board.squares)
		expect(function()
			Board.square(s, 0)
		end).toThrow()
		expect(function()
			Board.square(s, #s.board.squares + 1)
		end).toThrow()
	end)

	it("da la zona de una propiedad y nada en las demás casillas", function()
		local s = Fixtures.game({ players = 2 })
		local index = Fixtures.squareOf(s, "Property")
		expect(Board.zoneOf(s, index)).toEqual(s.board.zones[zoneOfFirstProperty(s)])
		expect(Board.zoneOf(s, 1)).toBe(nil)
	end)

	it("devuelve una copia de la zona para que nadie mute el tablero", function()
		local s = Fixtures.game({ players = 2 })
		local zone = Board.zoneOf(s, Fixtures.squareOf(s, "Property"))
		if not zone then
			error("la primera propiedad debería tener zona", 2)
		end
		table.remove(zone, 1)
		expect(#s.board.zones[zoneOfFirstProperty(s)]).toBe(3)
	end)

	it("reconoce una zona solo cuando está completa", function()
		local s = Fixtures.game({ players = 2 })
		local a, b = s.players[1].id, s.players[2].id
		local zoneId = zoneOfFirstProperty(s)
		local zone = Board.zoneOf(s, Fixtures.squareOf(s, "Property"))
		if not zone then
			error("la primera propiedad debería tener zona", 2)
		end
		expect(Board.ownsZone(s, a, zoneId)).toBe(false)
		Fixtures.give(s, a, zone[1])
		Fixtures.give(s, a, zone[2])
		expect(Board.ownsZone(s, a, zoneId)).toBe(false)
		Fixtures.give(s, a, zone[3])
		expect(Board.ownsZone(s, a, zoneId)).toBe(true)
		expect(Board.ownsZone(s, b, zoneId)).toBe(false)
		expect(Board.ownsZone(s, a, "no-existe")).toBe(false)
	end)
end)

describe("Fixtures", function()
	it("usa los ids P1..Pn y la semilla por defecto", function()
		local a = Fixtures.game({ players = 4 })
		local b = Fixtures.game({ players = 4, seed = 4 })
		expect(orderOf(a)).toEqual(orderOf(b))
		local collected = orderOf(a)
		table.sort(collected)
		expect(collected).toEqual(ids(4))
	end)

	it("fuerza los dados", function()
		local s = Fixtures.game({ players = 3 })
		Fixtures.dice(s, 2, 5)
		expect(Rng.int(s.rng, 1, 6)).toBe(2)
		expect(Rng.int(s.rng, 1, 6)).toBe(5)
		expect(s.rng.forced).toBe(nil)
	end)

	it("coloca la ficha y da propiedades sin cobrar", function()
		local s = Fixtures.game({ players = 2 })
		local id = s.players[1].id
		Fixtures.placeOn(s, id, 17)
		expect(s.players[1].position).toBe(17)
		local index = Fixtures.squareOf(s, "Property")
		Fixtures.give(s, id, index)
		expect(s.properties[index].ownerId).toBe(id)
		expect(s.players[1].cash).toBe(1500)
	end)

	it("busca la primera casilla de un tipo", function()
		local s = Fixtures.game({ players = 2 })
		expect(Fixtures.squareOf(s, "Start")).toBe(1)
		expect(Fixtures.squareOf(s, "Property")).toBe(2)
		expect(s.board.squares[Fixtures.squareOf(s, "Duel")].kind).toBe("Duel")
	end)

	it("añade cartas a la mano de un jugador", function()
		local s = Fixtures.game({ players = 3 })
		local id = s.players[2].id
		Fixtures.hand(s, id, "card-1")
		Fixtures.hand(s, id, "card-2")
		expect(s.players[2].hand).toEqual({ "card-1", "card-2" })
		expect(s.players[1].hand).toEqual({})
	end)

	it("pone el turno en el jugador indicado", function()
		local s = Fixtures.game({ players = 3 })
		local id = s.players[2].id
		Fixtures.turnOf(s, id)
		expect(s.turnIndex).toBe(2)
		expect(s.players[s.turnIndex].id).toBe(id)
	end)
end)

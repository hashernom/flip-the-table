--!strict
local Harness = require("../harness")
local Economy = require("../../src/shared/config/Economy")
local Engine = require("../../src/shared/rules/Engine")
local Fixtures = require("../fixtures")
local Movement = require("../../src/shared/rules/Movement")
local Turn = require("../../src/shared/rules/Turn")
local Types = require("../../src/shared/rules/Types")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local function inTurn(state: Types.GameState): Types.Player
	return state.players[state.turnIndex]
end

-- Exige un rechazo y devuelve el mensaje para poder comprobarlo.
local function rejected(result: Types.ApplyResult): string
	if result.ok then
		error("se esperaba un rechazo y la acción se aplicó", 3)
	end
	expect(result.error ~= "").toBe(true)
	return result.error
end

describe("Roll", function()
	it("avanza lo que marcan los dados", function()
		local s = Fixtures.game({ players = 4 })
		local id = s.players[s.turnIndex].id
		Fixtures.dice(s, 3, 4)
		expect(Engine.apply(s, id, { type = "Roll" }).ok).toBe(true)
		expect(s.players[s.turnIndex].position).toBe(8)
	end)

	it("paga 200 al pasar por la Salida", function()
		local s = Fixtures.game({ players = 4 })
		local id = s.players[s.turnIndex].id
		Fixtures.placeOn(s, id, 31)
		Fixtures.dice(s, 1, 2)
		Engine.apply(s, id, { type = "Roll" })
		expect(s.players[s.turnIndex].cash).toBe(1700)
	end)

	it("registra la tirada y deja el turno en AwaitEnd", function()
		local s = Fixtures.game({ players = 4 })
		local id = inTurn(s).id
		-- 3+4 desde la Salida cae en la propiedad 8; en propia, la Tarea 3 cierra en AwaitEnd.
		Fixtures.give(s, id, 8)
		Fixtures.dice(s, 3, 4)
		local result = Engine.apply(s, id, { type = "Roll" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(s.pending.rolled).toEqual({ a = 3, b = 4 })
		expect(s.phase).toBe("AwaitEnd")
		expect(result.events[1]).toEqual({ type = "DiceRolled", playerId = id, a = 3, b = 4 })
		expect(result.events[2].type).toBe("TokenMoved")
	end)

	it("emite el movimiento antes de pagar la Salida", function()
		local s = Fixtures.game({ players = 4 })
		local id = inTurn(s).id
		Fixtures.placeOn(s, id, 31)
		Fixtures.dice(s, 1, 2)
		local result = Engine.apply(s, id, { type = "Roll" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(#result.events).toBe(3)
		expect(result.events[1].type).toBe("DiceRolled")
		expect(result.events[2].type).toBe("TokenMoved")
		expect(result.events[3]).toEqual({ type = "PassedStart", playerId = id, amount = Economy.startBonus })
	end)

	it("rechaza tirar fuera de AwaitRoll", function()
		local s = Fixtures.game({ players = 4 })
		local id = inTurn(s).id
		Fixtures.placeOn(s, id, 9)
		Fixtures.dice(s, 3, 4)
		s.phase = "AwaitEnd"
		expect(rejected(Engine.apply(s, id, { type = "Roll" }))).toBe("No se puede Roll en la fase AwaitEnd")
		expect(s.phase).toBe("AwaitEnd")
		expect(inTurn(s).position).toBe(9)
		expect(inTurn(s).cash).toBe(Economy.startingCash)
		expect(s.rng.forced).toEqual({ 3, 4 })
		expect(s.pending.rolled).toBe(nil)
	end)

	it("rechaza tirar fuera de turno", function()
		local s = Fixtures.game({ players = 4 })
		local other = s.players[s.turnIndex % #s.players + 1].id
		Fixtures.dice(s, 3, 4)
		expect(rejected(Engine.apply(s, other, { type = "Roll" }))).toBe("No es tu turno")
		expect(s.phase).toBe("AwaitRoll")
		expect(inTurn(s).position).toBe(1)
		expect(s.rng.forced).toEqual({ 3, 4 })
		expect(s.pending.rolled).toBe(nil)
	end)

	it("rechaza cualquier acción con la partida terminada", function()
		local s = Fixtures.game({ players = 4 })
		local id = inTurn(s).id
		s.phase = "GameOver"
		expect(rejected(Engine.apply(s, id, { type = "Roll" }))).toBe("La partida ha terminado")
		expect(rejected(Engine.apply(s, id, { type = "EndTurn" }))).toBe("La partida ha terminado")
		expect(s.phase).toBe("GameOver")
		expect(inTurn(s).position).toBe(1)
	end)

	it("rechaza a un jugador que se fue", function()
		local s = Fixtures.game({ players = 4 })
		local id = inTurn(s).id
		inTurn(s).status = "Left"
		expect(rejected(Engine.apply(s, id, { type = "Roll" }))).toBe("El jugador ha abandonado la partida")
		expect(s.phase).toBe("AwaitRoll")
		expect(inTurn(s).position).toBe(1)
	end)

	it("rechaza acciones desconocidas", function()
		local s = Fixtures.game({ players = 4 })
		local id = inTurn(s).id
		expect(rejected(Engine.apply(s, id, { type = "Dance" }))).toBe("Acción desconocida: Dance")
		expect(s.phase).toBe("AwaitRoll")
		expect(inTurn(s).position).toBe(1)
	end)

	it("rechaza a un jugador que no está en la partida", function()
		local s = Fixtures.game({ players = 4 })
		expect(rejected(Engine.apply(s, "P9", { type = "Roll" }))).toBe(
			"El jugador P9 no está en la partida"
		)
		expect(s.phase).toBe("AwaitRoll")
	end)
end)

describe("Movement.advance", function()
	it("da la vuelta al tablero", function()
		local s = Fixtures.game({ players = 2 })
		local id = s.players[1].id
		local size = #s.board.squares
		Fixtures.placeOn(s, id, size)
		local events = Movement.advance(s, id, 3)
		expect(s.players[1].position).toBe(3)
		expect(events[1].from).toBe(size)
		expect(events[1].to).toBe(3)
		expect(events[1].path).toEqual({ 1, 2, 3 })
	end)

	it("describe la ruta que recorre", function()
		local s = Fixtures.game({ players = 2 })
		local id = s.players[1].id
		Fixtures.placeOn(s, id, 31)
		local events = Movement.advance(s, id, 3)
		expect(events[1]).toEqual({
			type = "TokenMoved",
			playerId = id,
			from = 31,
			to = 2,
			path = { 32, 1, 2 },
		})
		expect(s.players[1].position).toBe(2)
	end)

	it("paga al pasar por la Salida", function()
		local s = Fixtures.game({ players = 2 })
		local id = s.players[1].id
		Fixtures.placeOn(s, id, 31)
		local events = Movement.advance(s, id, 3)
		expect(s.players[1].cash).toBe(Economy.startingCash + Economy.startBonus)
		expect(events[2]).toEqual({ type = "PassedStart", playerId = id, amount = Economy.startBonus })
	end)

	it("paga al caer en la Salida", function()
		local s = Fixtures.game({ players = 2 })
		local id = s.players[1].id
		Fixtures.placeOn(s, id, 30)
		Movement.advance(s, id, 3)
		expect(s.players[1].position).toBe(1)
		expect(s.players[1].cash).toBe(Economy.startingCash + Economy.startBonus)
	end)

	it("no paga al retroceder sobre la Salida", function()
		local s = Fixtures.game({ players = 2 })
		local id = s.players[1].id
		Fixtures.placeOn(s, id, 2)
		local events = Movement.advance(s, id, -2)
		expect(s.players[1].position).toBe(#s.board.squares)
		expect(s.players[1].cash).toBe(Economy.startingCash)
		expect(#events).toBe(1)
		expect(events[1].type).toBe("TokenMoved")
	end)

	it("retrocede con pasos negativos", function()
		local s = Fixtures.game({ players = 2 })
		local id = s.players[1].id
		Fixtures.placeOn(s, id, 10)
		local events = Movement.advance(s, id, -3)
		expect(s.players[1].position).toBe(7)
		expect(events[1].from).toBe(10)
		expect(events[1].to).toBe(7)
		expect(events[1].path).toEqual({ 9, 8, 7 })
	end)

	it("no paga la Salida por salir de ella", function()
		local s = Fixtures.game({ players = 2 })
		local id = s.players[1].id
		local events = Movement.advance(s, id, 5)
		expect(s.players[1].position).toBe(6)
		expect(s.players[1].cash).toBe(Economy.startingCash)
		expect(#events).toBe(1)
	end)

	it("no hace nada si los pasos son cero", function()
		local s = Fixtures.game({ players = 2 })
		local id = s.players[1].id
		expect(Movement.advance(s, id, 0)).toEqual({})
		expect(s.players[1].position).toBe(1)
		expect(s.players[1].cash).toBe(Economy.startingCash)
	end)
end)

describe("Turn.next", function()
	it("pasa al siguiente jugador sin cambiar la ronda", function()
		local s = Fixtures.game({ players = 3 })
		expect(Turn.next(s)).toEqual({})
		expect(s.turnIndex).toBe(2)
		expect(s.round).toBe(1)
	end)

	it("sube la ronda al dar la vuelta al orden", function()
		local s = Fixtures.game({ players = 3 })
		Fixtures.turnOf(s, s.players[3].id)
		Turn.next(s)
		expect(s.turnIndex).toBe(1)
		expect(s.round).toBe(2)
	end)

	it("salta a los jugadores que se fueron", function()
		local s = Fixtures.game({ players = 4 })
		s.players[2].status = "Left"
		Turn.next(s)
		expect(s.turnIndex).toBe(3)
		expect(s.round).toBe(1)
	end)

	it("sigue contando rondas con un solo jugador presente", function()
		local s = Fixtures.game({ players = 2 })
		s.players[2].status = "Left"
		Turn.next(s)
		expect(s.turnIndex).toBe(1)
		expect(s.round).toBe(2)
	end)
end)

describe("EndTurn", function()
	it("pasa el turno al siguiente y vuelve a AwaitRoll", function()
		local s = Fixtures.game({ players = 3 })
		local id = inTurn(s).id
		s.phase = "AwaitEnd"
		local result = Engine.apply(s, id, { type = "EndTurn" })
		if not result.ok then
			error(result.error, 2)
		end
		expect(#result.events).toBe(0)
		expect(s.turnIndex).toBe(2)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("cierra el turno después de moverse", function()
		local s = Fixtures.game({ players = 2 })
		local id = inTurn(s).id
		-- 1+3 desde la Salida cae en el Spin: una casilla especial también cierra en AwaitEnd.
		Fixtures.dice(s, 1, 3)
		expect(Engine.apply(s, id, { type = "Roll" }).ok).toBe(true)
		expect(s.phase).toBe("AwaitEnd")
		expect(Engine.apply(s, id, { type = "EndTurn" }).ok).toBe(true)
		expect(s.phase).toBe("AwaitRoll")
		expect(s.turnIndex).toBe(2)
	end)

	it("sube la ronda al cerrar el orden", function()
		local s = Fixtures.game({ players = 3 })
		Fixtures.turnOf(s, s.players[3].id)
		local id = inTurn(s).id
		s.phase = "AwaitEnd"
		expect(Engine.apply(s, id, { type = "EndTurn" }).ok).toBe(true)
		expect(s.turnIndex).toBe(1)
		expect(s.round).toBe(2)
	end)

	it("salta a los jugadores que se fueron", function()
		local s = Fixtures.game({ players = 3 })
		s.players[2].status = "Left"
		local id = inTurn(s).id
		s.phase = "AwaitEnd"
		expect(Engine.apply(s, id, { type = "EndTurn" }).ok).toBe(true)
		expect(s.turnIndex).toBe(3)
		expect(s.round).toBe(1)
	end)

	it("rechaza terminar antes de tirar", function()
		local s = Fixtures.game({ players = 3 })
		local id = inTurn(s).id
		expect(rejected(Engine.apply(s, id, { type = "EndTurn" }))).toBe(
			"No se puede EndTurn en la fase AwaitRoll"
		)
		expect(s.turnIndex).toBe(1)
		expect(s.phase).toBe("AwaitRoll")
	end)

	it("rechaza terminar fuera de turno", function()
		local s = Fixtures.game({ players = 3 })
		local other = s.players[s.turnIndex + 1].id
		s.phase = "AwaitEnd"
		expect(rejected(Engine.apply(s, other, { type = "EndTurn" }))).toBe("No es tu turno")
		expect(s.turnIndex).toBe(1)
		expect(s.phase).toBe("AwaitEnd")
	end)
end)

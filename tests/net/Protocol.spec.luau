--!strict
-- Pruebas del protocolo de red: forma de las acciones, lista blanca de campos y límite de
-- frecuencia. Todo es lógica pura, sin Roblox, así que se ejecuta con Lune.
local Economy = require("../../src/shared/config/Economy")
local Protocol = require("../../src/shared/net/Protocol")
local Sim = require("../sim")
local Harness = require("../harness")

local describe = Harness.describe
local it = Harness.it
local expect = Harness.expect

-- Diez acciones por segundo: el número vive en config y este es su valor acordado.
local ACTIONS_PER_SECOND = 10

describe("Protocol.REMOTES", function()
	it("tiene los remotos del contrato: los tres de la partida y los del lobby (R-P29)", function()
		expect(Protocol.REMOTES).toEqual({
			Action = "ActionRequest",
			Batch = "EventBatch",
			Resync = "ResyncRequest",
			PartyCreate = "PartyCreateRequest",
			PartyJoin = "PartyJoinRequest",
			PartyStart = "PartyStartRequest",
			QueueJoin = "QueueJoinRequest",
			Notice = "LobbyNotice",
		})
	end)
end)

describe("Protocol.validate: rechaza entrada no válida", function()
	-- El bloque del plan, tal cual: cada valor debe rechazarse sin lanzar. Se anota como `any`
	-- porque una tabla heterogénea ensancharía el tipo de sus elementos.
	local PLAN_CASES: { any } = {
		{},
		1,
		"Roll",
		{ type = "Nope" },
		{ type = "Bid", amount = -5 },
		{ type = "Bid", amount = 1.5 },
	}
	for _, bad in PLAN_CASES do
		it("rechaza entrada no válida", function()
			expect((Protocol.validate(bad))).toBe(false)
		end)
	end

	it("acepta una puja válida", function()
		expect((Protocol.validate({ type = "Bid", amount = 100 }))).toBe(true)
	end)

	it("rechaza nil sin lanzar error", function()
		local ok: boolean, accepted: any = pcall(function(): boolean
			return (Protocol.validate(nil))
		end)
		expect(ok).toBe(true)
		expect(accepted).toBe(false)
	end)

	local BAD_VALUES: { any } = {
		true,
		{},
		{ type = 1 },
		{ type = true },
		{ type = "Nope" },
		{ type = "Bid" },
		{ type = "Bid", amount = -1 },
		{ type = "Bid", amount = 0 },
		{ type = "Bid", amount = 1.5 },
		{ type = "Bid", amount = "100" },
		{ type = "Bid", amount = math.huge },
		{ type = "Roll", playerId = "P1" },
		{ type = "Bid", amount = 100, amout = 100 },
		{ type = "Build", index = 1.5 },
		{ type = "Build", index = 0 },
		{ type = "Build", index = "4" },
		{ type = "PlayCard" },
		{ type = "PlayCard", cardId = 7 },
		{ type = "PlayCard", cardId = "Fine", targetId = 7 },
		{ type = "PlayCard", cardId = "Blackout", zoneId = 7 },
		{ type = "PlayCard", cardId = "Demolition", index = 0 },
		{ type = "PlayCard", cardId = "Backstab", pactId = 7 },
		{ type = "PlayCard", cardId = "Fine", targetId = "P2", playerId = "P1" },
		{ type = "React", cardId = "Shield", accept = true },
		{ type = "RerollDie", die = "c" },
		{ type = "RespondTrade", tradeId = "T1", accept = "sí" },
		{ type = "RespondPact", pactId = "P1", accept = 1 },
		{ type = "ProposePact", toId = "P2", rounds = 2.5 },
		{ type = "ProposePact", toId = "P2", rounds = 0 },
		{ type = "ProposePact", toId = 7, rounds = 2 },
		{ type = "TribunalVote", verdict = "Maybe" },
		{ type = "DuelChoice", choice = "Lizard" },
		{ type = "DuelChoice", rivalId = 7 },
		{ type = "GhostAct", kind = "Dance" },
		{ type = "ProposeTrade", offer = "nope" },
		{
			type = "ProposeTrade",
			offer = {
				toId = "P2",
				giveCash = 0,
				wantCash = 0,
				giveSquares = {},
				wantSquares = {},
				playerId = "P1",
			},
		},
		{
			type = "ProposeTrade",
			offer = { toId = "P2", giveCash = -1, wantCash = 0, giveSquares = {}, wantSquares = {} },
		},
		{
			type = "ProposeTrade",
			offer = { toId = "P2", giveCash = 0, wantCash = 0, giveSquares = { "5" }, wantSquares = {} },
		},
		{
			type = "ProposeTrade",
			offer = { toId = "P2", giveCash = 0, wantCash = 0, giveSquares = {} },
		},
	}

	it("rechaza tipos de campo incorrectos, importes no enteros y campos desconocidos", function()
		for _, bad in BAD_VALUES do
			local ok: boolean, accepted: any = pcall(function(): boolean
				return (Protocol.validate(bad))
			end)
			expect(ok).toBe(true)
			expect(accepted).toBe(false)
		end
	end)

	it("rechaza un campo desconocido en cualquier acción válida", function()
		local actions: { any } = {
			{ type = "DraftPerk", perkId = "Banker" },
			{ type = "Roll" },
			{ type = "RerollDie", die = "a" },
			{ type = "Buy" },
			{ type = "DeclineBuy" },
			{ type = "Bid", amount = 100 },
			{ type = "PlayCard", cardId = "Fine", targetId = "P2" },
			{ type = "React", cardId = "Shield" },
			{ type = "PassReaction" },
			{ type = "Build", index = 4 },
			{
				type = "ProposeTrade",
				offer = { toId = "P2", giveCash = 0, wantCash = 100, giveSquares = { 4 }, wantSquares = {} },
			},
			{ type = "RespondTrade", tradeId = "T1", accept = true },
			{ type = "ProposePact", toId = "P2", rounds = 3 },
			{ type = "RespondPact", pactId = "P1", accept = false },
			{ type = "BreakPact", pactId = "P1" },
			{ type = "TribunalVote", verdict = "Fine" },
			{ type = "DuelChoice", rivalId = "P2" },
			{ type = "DuelChoice", choice = "Rock" },
			{ type = "MarketBuy", cardId = "Shield" },
			{ type = "MarketSkip" },
			{ type = "GhostAct", kind = "Sabotage" },
			{ type = "GhostAct", kind = "Haunt", index = 4 },
			{ type = "EndTurn" },
		}
		for _, action in actions do
			expect((Protocol.validate(action))).toBe(true)
			local withPlayer = table.clone(action)
			withPlayer.playerId = "P1"
			expect((Protocol.validate(withPlayer))).toBe(false)
		end
	end)

	it("comprueba la forma, no la legalidad en la fase", function()
		-- Sin estado no hay fase: el motor decidirá si la puja se puede pagar o no.
		expect((Protocol.validate({ type = "Bid", amount = 1000000 }))).toBe(true)
		expect((Protocol.validate({ type = "Build", index = 9999 }))).toBe(true)
	end)
end)

describe("Protocol.validateLobby", function()
	local VALID: { any } = {
		{ type = "PartyCreate" },
		{ type = "PartyJoin", code = "AB3K9Z" },
		{ type = "PartyJoin", code = " ab3k9z " },
		{ type = "PartyStart", endMode = "Rounds" },
		{ type = "PartyStart", endMode = "Endless" },
		{ type = "QueueJoin" },
	}

	it("acepta las peticiones del lobby con su forma", function()
		for _, packet in VALID do
			expect((Protocol.validateLobby(packet))).toBe(true)
		end
	end)

	local INVALID: { any } = {
		1,
		"PartyJoin",
		{},
		{ type = "Nope" },
		{ type = "Roll" },
		{ type = "PartyJoin" },
		{ type = "PartyJoin", code = 7 },
		{ type = "PartyJoin", code = "" },
		{ type = "PartyJoin", code = string.rep("A", 17) },
		{ type = "PartyJoin", code = "AB3K9Z", playerId = "1" },
		{ type = "PartyCreate", playerId = "1" },
		{ type = "PartyStart" },
		{ type = "PartyStart", endMode = "Duel" },
		{ type = "PartyStart", endMode = true },
		{ type = "QueueJoin", playerId = "1" },
	}

	it("rechaza tipos, campos y valores que no son del lobby", function()
		expect((Protocol.validateLobby(nil))).toBe(false)
		for _, packet in INVALID do
			local ok: boolean, accepted: any = pcall(function(): boolean
				return (Protocol.validateLobby(packet))
			end)
			expect(ok).toBe(true)
			expect(accepted).toBe(false)
		end
	end)

	it("no mezcla las dos puertas: una acción de partida no entra por el lobby", function()
		expect((Protocol.validateLobby({ type = "Roll" }))).toBe(false)
		expect((Protocol.validate({ type = "PartyJoin", code = "AB3K9Z" }))).toBe(false)
	end)
end)

describe("Protocol.newLimiter", function()
	it("el límite configurado es de 10 acciones por segundo", function()
		expect(Economy.actionsPerSecond).toBe(ACTIONS_PER_SECOND)
	end)

	it("permite diez acciones en el mismo instante y descarta la undécima", function()
		local limiter = Protocol.newLimiter()
		local now = 1000
		for _ = 1, ACTIONS_PER_SECOND do
			expect(limiter.allow("P1", now)).toBe(true)
		end
		expect(limiter.allow("P1", now)).toBe(false)
		expect(limiter.allow("P1", now + 0.99)).toBe(false)
	end)

	it("cuenta por jugador", function()
		local limiter = Protocol.newLimiter()
		for _ = 1, ACTIONS_PER_SECOND do
			expect(limiter.allow("P1", 1000)).toBe(true)
		end
		expect(limiter.allow("P1", 1000)).toBe(false)
		expect(limiter.allow("P2", 1000)).toBe(true)
	end)

	it("acepta un ritmo propio: el lobby usa el suyo, más bajo que el de la partida", function()
		local lobbyRate = 2
		local limiter = Protocol.newLimiter(lobbyRate)
		expect(limiter.allow("P1", 1000)).toBe(true)
		expect(limiter.allow("P1", 1000)).toBe(true)
		expect(limiter.allow("P1", 1000)).toBe(false)
		expect(limiter.allow("P2", 1000)).toBe(true)
		expect(limiter.allow("P1", 1001)).toBe(true)
	end)

	it("vuelve a permitir al cumplirse un segundo", function()
		local limiter = Protocol.newLimiter()
		for _ = 1, ACTIONS_PER_SECOND do
			expect(limiter.allow("P1", 1000)).toBe(true)
		end
		expect(limiter.allow("P1", 1000.999)).toBe(false)
		for _ = 1, ACTIONS_PER_SECOND do
			expect(limiter.allow("P1", 1001)).toBe(true)
		end
		expect(limiter.allow("P1", 1001)).toBe(false)
	end)

	it("las llamadas descartadas no gastan cupo", function()
		local limiter = Protocol.newLimiter()
		for _ = 1, ACTIONS_PER_SECOND do
			expect(limiter.allow("P1", 1000)).toBe(true)
		end
		for _ = 1, 50 do
			expect(limiter.allow("P1", 1000.5)).toBe(false)
		end
		expect(limiter.allow("P1", 1001)).toBe(true)
	end)
end)

describe("Protocol.validate: acciones reales de una partida", function()
	-- La prueba de aceptación de la lista blanca: todo lo que el motor aplica en una partida
	-- completa del bot tiene que pasar la puerta del protocolo. Si una acción nueva se añade al
	-- motor y aquí se rechaza, el test falla y delata la deriva entre las dos tablas.
	local CASES: { { players: number, seed: number } } = {
		{ players = 2, seed = 7 },
		{ players = 4, seed = 1 },
		{ players = 8, seed = 3 },
	}

	for _, case in CASES do
		it(
			`acepta todas las acciones de una partida de {case.players} jugadores (semilla {case.seed})`,
			function()
				local rejected: { string } = {}
				local total = 0
				local seen: { [string]: boolean } = {}
				Sim.play({
					players = case.players,
					seed = case.seed,
					onAction = function(action)
						total += 1
						seen[action.type] = true
						local ok, reason = Protocol.validate(action)
						if not ok then
							table.insert(rejected, `{action.type}: {reason}`)
						end
					end,
				})
				if #rejected > 0 then
					error(
						`Protocol rechazó {#rejected} de {total} acciones que el motor aceptó: {table.concat(
							rejected,
							"; "
						)}`,
						2
					)
				end
				expect(total > 0).toBe(true)
				-- Que la prueba no pase por vacío: una partida del bot usa varias acciones distintas.
				local kinds = 0
				for _ in seen do
					kinds += 1
				end
				expect(kinds >= 5).toBe(true)
			end
		)
	end
end)

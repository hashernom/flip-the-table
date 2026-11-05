--!strict
-- Pruebas de los códigos de party y de las reglas puras del lobby: alfabeto, normalización,
-- capacidad, caducidad, cambio de anfitrión, reintentos de teletransporte y arranque de la cola
-- pública. Todo es lógica pura, sin Roblox, así que se ejecuta con Lune.
local Harness = require("../harness")
local Lobby = require("../../src/shared/config/Lobby")
local LobbyRules = require("../../src/server/lobby/LobbyRules")
local PartyCode = require("../../src/server/lobby/PartyCode")
local Rng = require("../../src/shared/rules/Rng")

local describe = Harness.describe
local it = Harness.it
local expect = Harness.expect

-- Alfabeto del contrato (contracts.md, «Códigos de party»): sin 0, O, 1 ni I.
local ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
local FORBIDDEN = { "0", "O", "1", "I" }

-- Semillas del barrido: bastantes para que un código fijo o un alfabeto incompleto se delaten.
local SEEDS = 500

-- Instante de referencia de las pruebas de fiesta. La caducidad se mide contra este valor.
local NOW = 1000

local function codeFor(seed: number): string
	return PartyCode.generate(Rng.new(seed))
end

local function contains(text: string, needle: string): boolean
	return string.find(text, needle, 1, true) ~= nil
end

-- Fiesta de prueba con la forma del contrato: código, anfitrión, miembros en orden de llegada,
-- servidor del anfitrión y vida de config. `expiresAt` se puede mover para probar la caducidad.
local function party(members: { number }, hostId: number?): LobbyRules.Party
	return {
		code = "AB3K9Z",
		hostId = hostId or members[1],
		members = members,
		serverId = "servidor-1",
		createdAt = NOW,
		expiresAt = NOW + Lobby.partyLifetimeSec,
	}
end

describe("PartyCode.generate", function()
	it("siempre mide los caracteres de config y usa solo el alfabeto permitido", function()
		for seed = 1, SEEDS do
			local code = codeFor(seed)
			expect(#code).toBe(Lobby.codeLength)
			for index = 1, #code do
				local character = string.sub(code, index, index)
				expect(string.find(ALPHABET, character, 1, true) ~= nil).toBe(true)
			end
		end
	end)

	it("nunca contiene 0, O, 1 ni I", function()
		for seed = 1, SEEDS do
			local code = codeFor(seed)
			for _, forbidden in FORBIDDEN do
				expect(contains(code, forbidden)).toBe(false)
			end
		end
	end)

	it("la misma semilla da siempre el mismo código", function()
		for seed = 1, 20 do
			expect(codeFor(seed)).toBe(codeFor(seed))
		end
	end)

	it("dos semillas distintas dan códigos distintos al menos una vez", function()
		local seen: { [string]: boolean } = {}
		local distinct = 0
		for seed = 1, 64 do
			local code = codeFor(seed)
			if not seen[code] then
				seen[code] = true
				distinct += 1
			end
		end
		expect(distinct > 1).toBe(true)
	end)

	it("consume el generador: dos llamadas seguidas del mismo rng no son siempre iguales", function()
		local rng = Rng.new(1)
		local changes = 0
		local previous: string? = nil
		for _ = 1, 20 do
			local code = PartyCode.generate(rng)
			if previous and code ~= previous then
				changes += 1
			end
			previous = code
		end
		expect(changes > 0).toBe(true)
	end)
end)

describe("PartyCode.normalize", function()
	it("recorta espacios y pasa a mayúsculas", function()
		expect(PartyCode.normalize(" ab3k9z ")).toBe("AB3K9Z")
		expect(PartyCode.normalize("ab3k9z")).toBe("AB3K9Z")
		expect(PartyCode.normalize("  AB3K9Z  ")).toBe("AB3K9Z")
		expect(PartyCode.normalize("\tab3k9z\n")).toBe("AB3K9Z")
	end)

	it("rechaza el texto vacío o de longitud distinta", function()
		expect(PartyCode.normalize("")).toBe(nil)
		expect(PartyCode.normalize("   ")).toBe(nil)
		expect(PartyCode.normalize("AB3K9")).toBe(nil)
		expect(PartyCode.normalize("AB3K9ZZ")).toBe(nil)
	end)

	it("rechaza símbolos, acentos y las letras o números prohibidos", function()
		expect(PartyCode.normalize("AB-C9Z")).toBe(nil)
		expect(PartyCode.normalize("AB3K9!")).toBe(nil)
		expect(PartyCode.normalize("AB3K0Z")).toBe(nil)
		expect(PartyCode.normalize("AB3KOZ")).toBe(nil)
		expect(PartyCode.normalize("AB3K1Z")).toBe(nil)
		expect(PartyCode.normalize("AB3KIZ")).toBe(nil)
	end)
end)

describe("LobbyRules.shouldStartQueue", function()
	it("los valores acordados viven en config y no en la lógica", function()
		expect(Lobby.minPlayers).toBe(2)
		expect(Lobby.maxPlayers).toBe(8)
		expect(Lobby.codeLength).toBe(6)
		expect(Lobby.partyLifetimeSec).toBe(300)
		expect(Lobby.teleportAttempts).toBe(3)
		expect(Lobby.requestsPerSecond).toBe(2)
		expect(Lobby.queueStartAt).toBe(4)
		expect(Lobby.queueWaitSec).toBe(60)
	end)

	it("empieza en cuanto hay 4 o más y nunca con 9", function()
		expect(LobbyRules.shouldStartQueue(4, 0)).toBe(true)
		expect(LobbyRules.shouldStartQueue(8, 0)).toBe(true)
		expect(LobbyRules.shouldStartQueue(9, 0)).toBe(false)
		expect(LobbyRules.shouldStartQueue(9, Lobby.queueWaitSec)).toBe(false)
	end)

	it("con 2 o 3 espera a los 60 s", function()
		expect(LobbyRules.shouldStartQueue(2, 10)).toBe(false)
		expect(LobbyRules.shouldStartQueue(3, Lobby.queueWaitSec - 1)).toBe(false)
		expect(LobbyRules.shouldStartQueue(2, Lobby.queueWaitSec)).toBe(true)
		expect(LobbyRules.shouldStartQueue(3, Lobby.queueWaitSec)).toBe(true)
	end)

	it("con menos de 2 no empieza nunca", function()
		expect(LobbyRules.shouldStartQueue(0, Lobby.queueWaitSec)).toBe(false)
		expect(LobbyRules.shouldStartQueue(1, Lobby.queueWaitSec * 10)).toBe(false)
	end)
end)

describe("LobbyRules party", function()
	it("nace con el anfitrión dentro y una caducidad de config", function()
		local created = LobbyRules.newParty("AB3K9Z", 101, "servidor-1", NOW)
		expect(created.code).toBe("AB3K9Z")
		expect(created.hostId).toBe(101)
		expect(created.members).toEqual({ 101 })
		expect(created.serverId).toBe("servidor-1")
		expect(created.createdAt).toBe(NOW)
		expect(created.expiresAt).toBe(NOW + Lobby.partyLifetimeSec)
	end)

	it("une hasta el máximo sin duplicar y rechaza al siguiente", function()
		local current = LobbyRules.newParty("AB3K9Z", 101, "servidor-1", NOW)
		for userId = 102, Lobby.maxPlayers + 100 do
			if #current.members >= Lobby.maxPlayers then
				break
			end
			local joined, reason = LobbyRules.join(current, userId, NOW)
			expect(reason).toBe(nil)
			expect(joined ~= nil).toBe(true)
			current = joined :: LobbyRules.Party
		end
		expect(#current.members).toBe(Lobby.maxPlayers)
		expect((LobbyRules.join(current, 102, NOW))).toEqual(current)
		local full, reason = LobbyRules.join(current, Lobby.maxPlayers + 200, NOW)
		expect(full).toBe(nil)
		expect(contains(reason :: string, "llena")).toBe(true)
	end)

	it("rechaza un código inexistente o caducado con un mensaje claro", function()
		local missing, missingReason = LobbyRules.join(nil, 101, NOW)
		expect(missing).toBe(nil)
		expect(contains(missingReason :: string, "No hay")).toBe(true)

		local expired = party({ 101, 102 })
		expired.expiresAt = NOW
		local joined, reason = LobbyRules.join(expired, 103, NOW)
		expect(joined).toBe(nil)
		expect(contains(reason :: string, "caducado")).toBe(true)
	end)

	it("no muta la fiesta que recibe", function()
		local original = party({ 101 })
		local before = table.clone(original)
		before.members = table.clone(original.members)
		local joined = LobbyRules.join(original, 102, NOW)
		expect(joined ~= nil).toBe(true)
		expect(#original.members).toBe(1)
		expect(original).toEqual(before)
	end)

	it("al salir el anfitrión toma su lugar el siguiente", function()
		local current = party({ 101, 102, 103 })
		expect(LobbyRules.leave(current, 101)).toEqual(party({ 102, 103 }, 102))
		expect(LobbyRules.leave(current, 103)).toEqual(party({ 101, 102 }, 101))
		expect(LobbyRules.leave(party({ 101 }), 101)).toBe(nil)
	end)

	it("solo el anfitrión empieza y hacen falta al menos 2", function()
		local current = party({ 101, 102 })
		local notHost, hostReason = LobbyRules.canStart(current, 102, NOW)
		expect(notHost).toBe(false)
		expect(contains(hostReason :: string, "anfitrión")).toBe(true)

		local alone, fewReason = LobbyRules.canStart(party({ 101 }), 101, NOW)
		expect(alone).toBe(false)
		expect(contains(fewReason :: string, "2")).toBe(true)

		expect((LobbyRules.canStart(current, 101, NOW))).toBe(true)
	end)

	it("un código caducado no puede empezar", function()
		local current = party({ 101, 102 })
		current.expiresAt = NOW
		local ok, reason = LobbyRules.canStart(current, 101, NOW)
		expect(ok).toBe(false)
		expect(contains(reason :: string, "caducado")).toBe(true)
	end)
end)

describe("LobbyRules.retry", function()
	it("reintenta hasta el límite y devuelve el último motivo", function()
		local calls = 0
		local waits: { number } = {}
		local ok, reason = LobbyRules.retry(
			function(): (boolean, string?)
				calls += 1
				return false, `intento {calls}`
			end,
			Lobby.teleportAttempts,
			function(seconds: number)
				table.insert(waits, seconds)
			end
		)
		expect(ok).toBe(false)
		expect(calls).toBe(Lobby.teleportAttempts)
		expect(reason).toBe(`intento {Lobby.teleportAttempts}`)
		expect(#waits).toBe(Lobby.teleportAttempts - 1)
		for _, seconds in waits do
			expect(seconds).toBe(Lobby.teleportRetrySec)
		end
	end)

	it("se detiene en cuanto un intento funciona", function()
		local calls = 0
		local waits = 0
		local ok, reason = LobbyRules.retry(
			function(): (boolean, string?)
				calls += 1
				return calls >= 2, nil
			end,
			Lobby.teleportAttempts,
			function()
				waits += 1
			end
		)
		expect(ok).toBe(true)
		expect(reason).toBe(nil)
		expect(calls).toBe(2)
		expect(waits).toBe(1)
	end)
end)

describe("LobbyRules datos de teletransporte", function()
	it("la cola pública siempre usa Rondas", function()
		local data = LobbyRules.queueData(42, 5)
		expect(data.seed).toBe(42)
		expect(data.size).toBe(5)
		expect(data.endMode).toBe("Rounds")
		expect(data.code).toBe(nil)
	end)

	it("la party viaja con su código y el modo que elige el anfitrión", function()
		local data = LobbyRules.partyData(42, "AB3K9Z", "Endless", 3)
		expect(data.seed).toBe(42)
		expect(data.code).toBe("AB3K9Z")
		expect(data.endMode).toBe("Endless")
		expect(data.size).toBe(3)
	end)
end)

describe("LobbyRules: elección de ficha", function()
	local function party()
		local base = LobbyRules.newParty("AB3K9Z", 1, "", 0)
		return (LobbyRules.join(base, 2, 0)) :: LobbyRules.Party
	end

	it("guarda la elección sin mutar la party que recibe", function()
		local original = party()
		local updated = LobbyRules.chooseToken(original, 1, "moto") :: LobbyRules.Party
		expect((updated.tokens :: any)["1"]).toBe("moto")
		expect(original.tokens).toBe(nil)
	end)

	it("rechaza una ficha ajena, una inexistente y a quien no es miembro", function()
		local updated = LobbyRules.chooseToken(party(), 1, "moto") :: LobbyRules.Party
		local taken, takenReason = LobbyRules.chooseToken(updated, 2, "moto")
		expect(taken).toBe(nil)
		expect(type(takenReason)).toBe("string")
		expect((LobbyRules.chooseToken(updated, 2, "caballo"))).toBe(nil)
		expect((LobbyRules.chooseToken(updated, 9, "taxi"))).toBe(nil)
		expect((LobbyRules.chooseToken(nil, 1, "taxi"))).toBe(nil)
	end)

	it("quien se va libera su ficha", function()
		local updated = LobbyRules.chooseToken(party(), 1, "moto") :: LobbyRules.Party
		local left = LobbyRules.leave(updated, 1) :: LobbyRules.Party
		expect(left.tokens ~= nil and (left.tokens :: any)["1"]).toBe(nil)
		expect(LobbyRules.chooseToken(left, 2, "moto") ~= nil).toBe(true)
	end)

	it("los datos de la partida llevan las elecciones", function()
		local data = LobbyRules.partyData(42, "AB3K9Z", "Endless", 3, { ["1"] = "moto" })
		expect((data.tokens :: any)["1"]).toBe("moto")
	end)
end)

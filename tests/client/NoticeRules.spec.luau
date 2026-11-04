--!strict
-- Enrutado de los avisos del servidor (R-P48). Antes todo aviso iba al panel de revancha: un rechazo de
-- acción lo habría abierto en mitad de la partida. Los `kind` salen de `Protocol.NOTICE_KINDS`, el mismo
-- contrato que usa el servidor.
local Harness = require("../harness")
local NoticeRules = require("../../src/client/ui/NoticeRules")
local Protocol = require("../../src/shared/net/Protocol")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

describe("NoticeRules.route", function()
	it("un rechazo de acción es un aviso breve, no el panel de revancha", function()
		local notice = { kind = Protocol.NOTICE_KINDS.ActionRejected, message = "No es tu turno" }
		expect(NoticeRules.route(notice)).toBe("Toast")
	end)

	it("los avisos de revancha y de lobby siguen yendo al panel", function()
		for _, kind in { "Info", "Error", "PartyCode" } do
			expect(Protocol.NOTICE_KINDS[kind]).toBe(kind)
			expect(NoticeRules.route({ kind = kind, message = "Hola" })).toBe("Panel")
		end
	end)

	it("un aviso sin kind conocido va al panel, como hasta ahora", function()
		expect(NoticeRules.route({ message = "Hola" })).toBe("Panel")
		expect(NoticeRules.route({ kind = "Nuevo", message = "Hola" })).toBe("Panel")
	end)

	it("lo que no es un aviso con mensaje se ignora", function()
		expect(NoticeRules.route(nil)).toBe(nil)
		expect(NoticeRules.route("texto")).toBe(nil)
		expect(NoticeRules.route({ kind = "Info" })).toBe(nil)
		expect(NoticeRules.route({ kind = "Info", message = 3 })).toBe(nil)
	end)
end)

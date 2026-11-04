--!strict
-- Una respuesta de resync que llega durante una escena no puede devolver los menús a mitad de ella
-- (R-P39, «Extra» de la auditoría): se aplaza hasta que acaba, y manda la más reciente.
local Harness = require("../harness")
local ResyncGate = require("../../src/client/state/ResyncGate")

local describe, it, expect = Harness.describe, Harness.it, Harness.expect

describe("ResyncGate", function()
	it("sin escena en curso, la vista se aplica en el acto", function()
		local gate = ResyncGate.new()
		expect(gate.offer({ seq = 4 }, false)).toBe("Apply")
		expect(gate.take()).toBe(nil)
	end)

	it("con una escena en curso se aplaza y sale al terminar", function()
		local gate = ResyncGate.new()
		local batch = { seq = 4 }
		expect(gate.offer(batch, true)).toBe("Defer")
		expect(gate.take()).toBe(batch)
		-- Se entrega una sola vez.
		expect(gate.take()).toBe(nil)
	end)

	it("si llegan dos durante la misma escena, vale la última", function()
		local gate = ResyncGate.new()
		gate.offer({ seq = 4 }, true)
		local newer = { seq = 5 }
		gate.offer(newer, true)
		expect(gate.take()).toBe(newer)
	end)
end)

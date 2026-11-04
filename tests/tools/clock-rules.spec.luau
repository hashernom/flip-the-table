--!nocheck
-- R-P38: `time()` cuenta desde que arrancó cada proceso y no se compara entre máquinas. Con él en el
-- servidor, cada escena del cliente duraba 0,2 s y ninguna prueba de Lune podía verlo.
local Harness = require("../harness")
local clockRules = require("../../tools/clock-rules")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

describe("clockRules.usesUptime", function()
	it("señala una llamada a time()", function()
		expect(clockRules.usesUptime("local now = time()\nreturn now\n")).toBe(true)
		expect(clockRules.usesUptime("record(match, time ())\n")).toBe(true)
	end)

	it("acepta el reloj del servidor", function()
		expect(clockRules.usesUptime("return Workspace:GetServerTimeNow()\n")).toBe(false)
	end)

	it("no confunde otros nombres ni comentarios", function()
		expect(clockRules.usesUptime("local x = uptime()\nlocal y = obj.time()\nlocal z = o:time()\n")).toBe(
			false
		)
		expect(clockRules.usesUptime("-- antes se usaba time() aquí\nreturn 1\n")).toBe(false)
		expect(clockRules.usesUptime('local s = "time()"\nreturn s\n')).toBe(false)
	end)
end)

describe("clockRules.offenders", function()
	it("el código de la partida no usa time()", function()
		expect(clockRules.offenders("src/server/match")).toEqual({})
	end)
end)

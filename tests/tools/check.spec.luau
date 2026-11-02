--!nocheck
local fs = require("@lune/fs")

local Harness = require("../harness")
local pureRules = require("../../tools/pure-rules")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local SAMPLE = "build/pure-rules-sample.luau"
local FORBIDDEN_SAMPLES = {
	"game.Players",
	'game:GetService("Players")',
	'Instance.new("Part")',
	"task.wait()",
	"Random.new()",
}

local function withSample(source: string, fn: () -> ())
	if not fs.isDir("build") then
		fs.writeDir("build")
	end
	fs.writeFile(SAMPLE, source)
	local ok, err = pcall(fn)
	fs.removeFile(SAMPLE)
	if not ok then
		error(err, 0)
	end
end

describe("pureRules", function()
	it("señala un archivo que usa workspace", function()
		withSample("local g = workspace.Gravity\nreturn g\n", function()
			expect(pureRules({ SAMPLE })).toEqual({ SAMPLE })
		end)
	end)

	for _, forbidden in FORBIDDEN_SAMPLES do
		it(`señala {forbidden}`, function()
			withSample(`local x = {forbidden}\nreturn x\n`, function()
				expect(pureRules({ SAMPLE })).toEqual({ SAMPLE })
			end)
		end)
	end

	it("ignora las menciones en comentarios", function()
		withSample("-- no usa workspace ni task.wait\nreturn 1\n", function()
			expect(pureRules({ SAMPLE })).toEqual({})
		end)
	end)

	it("no confunde nombres parecidos", function()
		withSample(
			"local endgame = {}\nendgame.x = 1\nlocal multitask = {}\nmultitask.y = 2\nreturn endgame\n",
			function()
				expect(pureRules({ SAMPLE })).toEqual({})
			end
		)
	end)

	it("acepta el módulo Rng", function()
		expect(pureRules({ "src/shared/rules/Rng.luau" })).toEqual({})
	end)
end)

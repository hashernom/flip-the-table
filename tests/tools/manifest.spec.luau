--!nocheck
-- El manifiesto es la única puerta por la que un asset puede entrar al juego: nadie lo aprueba
-- sin capturas tomadas en el juego y ningún asset puede colarse por encima de su presupuesto.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Harness = require("../harness")
local Manifest = require("../../tools/manifest")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local MANIFEST_PATH = "art/manifest.json"

-- Entrada válida por defecto: cada prueba cambia solo lo que examina.
local function entry(overrides: { [string]: any }): { [string]: any }
	local base = {
		id = "taxi",
		category = "Token",
		source = "art/blender/taxi.blend",
		triangles = 7000,
		lods = { 2000 },
		textures = 3,
		status = "Draft",
		screenshots = {},
	}
	for key, value in overrides do
		base[key] = value
	end
	return base
end

local function validate(...: { [string]: any }): { string }
	local assets = { ... }
	return Manifest.validate({ assets = assets })
end

describe("Manifest.validate", function()
	it("rechaza aprobar sin capturas", function()
		local problems = validate(entry({ status = "Approved", approvedBy = "Ana", screenshots = {} }))
		expect(#problems).toBe(1)
	end)

	it("rechaza superar el presupuesto", function()
		local problems = validate(entry({ triangles = 9000 }))
		expect(#problems).toBe(1)
	end)

	it("rechaza aprobar sin approvedBy", function()
		local problems = validate(entry({ status = "Approved", screenshots = { "captura-1.png" } }))
		expect(#problems).toBe(1)
	end)

	it("acepta un borrador dentro de presupuesto", function()
		expect(validate(entry({}))).toEqual({})
	end)

	it("acepta un asset en el juego con capturas, todavía sin aprobar", function()
		expect(validate(entry({ status = "InGame", screenshots = { "captura-1.png" } }))).toEqual({})
	end)

	it("exige versión de menor detalle donde es obligatoria", function()
		local problems = validate(entry({ lods = {} }))
		expect(#problems).toBe(1)
		expect(string.find(problems[1], "menor detalle", 1, true)).toBeTruthy()
	end)

	it("no exige versión de menor detalle en el fondo de ciudad", function()
		expect(validate(entry({ category = "CityBackdrop", triangles = 3000, lods = {} }))).toEqual({})
	end)

	it("rechaza una versión de menor detalle mayor que el modelo", function()
		local problems = validate(entry({ lods = { 9000 } }))
		expect(#problems).toBe(1)
	end)

	it("rechaza una categoría desconocida", function()
		local problems = validate(entry({ category = "Vehiculo" }))
		expect(#problems).toBe(1)
		expect(string.find(problems[1], "categoría", 1, true)).toBeTruthy()
	end)

	it("rechaza dos veces el mismo id", function()
		local problems = validate(entry({}), entry({ triangles = 1000 }))
		expect(#problems).toBe(1)
		expect(string.find(problems[1], "repetido", 1, true)).toBeTruthy()
	end)

	it("rechaza un estado desconocido", function()
		local problems = validate(entry({ status = "Listo" }))
		expect(#problems).toBe(1)
	end)

	it("rechaza un asset sin id y no se queda esperando", function()
		local problems = validate({ category = "Token", triangles = 1000, lods = { 100 }, status = "Draft" })
		expect(#problems).toBe(1)
	end)

	it("nombra el asset en el problema", function()
		local problems = validate(entry({ id = "rascacielos", triangles = 12000 }))
		expect(string.find(problems[1], "rascacielos", 1, true)).toBeTruthy()
	end)

	it("no cuenta las capturas vacías como capturas", function()
		local problems =
			validate(entry({ status = "Approved", approvedBy = "Ana", screenshots = { "", "" } }))
		expect(#problems).toBe(1)
	end)
end)

describe("Manifest.unknownRefs", function()
	local manifest = { assets = { entry({ id = "taxi" }), entry({ id = "casa" }) } }

	it("señala un id que no está en el manifiesto", function()
		local missing = Manifest.unknownRefs(manifest, { "taxi", "rascacielos" })
		expect(missing).toEqual({ "rascacielos" })
	end)

	it("acepta los ids que sí están", function()
		expect(Manifest.unknownRefs(manifest, { "casa", "taxi" })).toEqual({})
	end)
end)

describe("Manifest: ids de asset en el código", function()
	local manifest = { assets = { entry({ id = "taxi", assetId = "rbxassetid://111" }) } }

	it("encuentra los ids en un archivo y los repetidos cuentan una vez", function()
		local source =
			'a.Image = "rbxassetid://111"\nb.Image = "rbxassetid://222"\nc.Image = "rbxassetid://111"\n'
		expect(Manifest.assetRefs(source)).toEqual({ "rbxassetid://111", "rbxassetid://222" })
	end)

	it("señala un id que ningún asset registra", function()
		expect(Manifest.unknownAssets(manifest, { "rbxassetid://111", "rbxassetid://222" })).toEqual({
			"rbxassetid://222",
		})
	end)

	it("nombra el archivo y el id sin registrar", function()
		local problems = Manifest.sourceProblems(
			manifest,
			"src/x.luau",
			'a = "rbxassetid://222"\nb = "rbxassetid://111"\n'
		)
		expect(problems).toEqual({ "src/x.luau: rbxassetid://222 no está en el manifiesto" })
	end)
end)

describe("Manifest.validate con datos rotos", function()
	it("nombra el asset sin triángulos en vez de reventar", function()
		local problems = validate(entry({ triangles = "muchos" }))
		expect(#problems).toBe(1)
		expect(string.find(problems[1], "taxi", 1, true)).toBeTruthy()
	end)
end)

describe("Manifest.BUDGETS", function()
	it("reproduce los presupuestos de la subfase 06", function()
		expect(Manifest.BUDGETS.Token.triangles).toBe(8000)
		expect(Manifest.BUDGETS.Building.triangles).toBe(10000)
		expect(Manifest.BUDGETS.SceneCharacter.triangles).toBe(5000)
		expect(Manifest.BUDGETS.RepeatedProp.triangles).toBe(2000)
		expect(Manifest.BUDGETS.CityBackdrop.triangles).toBe(3000)
	end)
end)

describe("art/manifest.json", function()
	local manifest = serde.decode("json", fs.readFile(MANIFEST_PATH))

	it("existe y está limpio", function()
		expect(Manifest.validate(manifest)).toEqual({})
	end)

	it("registra cada asset como borrador, nunca aprobado", function()
		local approved = {}
		for _, asset in manifest.assets do
			if asset.status == "Approved" then
				table.insert(approved, asset.id)
			end
		end
		expect(approved).toEqual({})
	end)

	it("no tiene ids repetidos", function()
		local seen = {}
		local repeated = {}
		for _, asset in manifest.assets do
			if seen[asset.id] then
				table.insert(repeated, asset.id)
			end
			seen[asset.id] = true
		end
		expect(repeated).toEqual({})
	end)

	it("no referencia ids que el manifiesto no tenga", function()
		local ids = {}
		for _, asset in manifest.assets do
			table.insert(ids, asset.id)
		end
		expect(Manifest.unknownRefs(manifest, ids)).toEqual({})
	end)
end)

--!strict
-- Manifiesto de assets: presupuestos técnicos y la regla de que nada se aprueba sin revisión
-- en el juego. Es puro: recibe la tabla ya decodificada y devuelve los problemas.
--
-- Uso desde tools/check y desde tests. El detalle de la tubería está en art/PIPELINE.md.

export type Category = "Building" | "Token" | "SceneCharacter" | "RepeatedProp" | "CityBackdrop"
export type Status = "Draft" | "InGame" | "Approved"

export type Budget = { triangles: number, lodRequired: boolean, label: string }

export type Asset = {
	id: string,
	category: string,
	source: string?,
	triangles: number,
	lods: { number }?,
	textures: number?,
	assetId: string?,
	assetIds: { string }?,
	status: string,
	approvedBy: string?,
	screenshots: { string }?,
	generatedWith: string?,
}

export type Manifest = { assets: { Asset } }

-- Presupuestos de la subfase 06. El límite de Roblox es de 20 000 triángulos por malla; estos
-- son menores a propósito, para que la ciudad entera quepa en un móvil.
local BUDGETS: { [string]: Budget } = {
	Building = { triangles = 10000, lodRequired = true, label = "Edificio de la ruta" },
	Token = { triangles = 8000, lodRequired = true, label = "Ficha" },
	SceneCharacter = { triangles = 5000, lodRequired = true, label = "Personaje de escena" },
	RepeatedProp = { triangles = 2000, lodRequired = true, label = "Objeto repetido" },
	CityBackdrop = { triangles = 3000, lodRequired = false, label = "Fondo de ciudad" },
}

local STATUSES: { [string]: boolean } = {
	Draft = true,
	InGame = true,
	Approved = true,
}

local Manifest = {}

Manifest.BUDGETS = BUDGETS

local function hasText(value: string?): boolean
	return value ~= nil and #value > 0
end

-- Cuenta solo las capturas con nombre: una lista de textos vacíos no es una revisión.
local function countScreenshots(screenshots: { string }?): number
	if screenshots == nil then
		return 0
	end
	local count = 0
	for _, name in screenshots do
		if hasText(name) then
			count += 1
		end
	end
	return count
end

local function checkAsset(asset: Asset, id: string, problems: { string })
	local budget = BUDGETS[asset.category]
	if budget == nil then
		local categories = {}
		for name in BUDGETS do
			table.insert(categories, name)
		end
		table.sort(categories)
		table.insert(
			problems,
			`{id}: categoría desconocida "{asset.category}" (válidas: {table.concat(categories, ", ")})`
		)
		return
	end

	if type(asset.triangles) ~= "number" then
		table.insert(problems, `{id}: los triángulos tienen que ser un número`)
		return
	end

	if asset.triangles > budget.triangles then
		table.insert(
			problems,
			`{id}: {asset.triangles} triángulos supera el presupuesto de {budget.triangles} ({budget.label})`
		)
	end

	-- Sin anotación, el tipo queda como unión {number} | {} y Luau no sabe recorrerlo.
	local lods: { number } = asset.lods or {}
	if budget.lodRequired and #lods == 0 then
		table.insert(problems, `{id}: necesita versión de menor detalle ({budget.label})`)
	end
	for _, triangles in lods do
		if triangles >= asset.triangles then
			table.insert(
				problems,
				`{id}: la versión de menor detalle ({triangles}) no es menor que el modelo ({asset.triangles})`
			)
		end
	end

	if not STATUSES[asset.status] then
		table.insert(
			problems,
			`{id}: estado desconocido "{asset.status}" (válidos: Draft, InGame, Approved)`
		)
		return
	end

	if asset.status == "Approved" then
		if not hasText(asset.approvedBy) then
			table.insert(problems, `{id}: está aprobado sin approvedBy`)
		end
		if countScreenshots(asset.screenshots) == 0 then
			table.insert(problems, `{id}: está aprobado sin capturas en el juego`)
		end
	end
end

-- Devuelve todos los problemas del manifiesto, cada uno nombrando el asset. Vacío es válido.
function Manifest.validate(manifest: Manifest): { string }
	local problems: { string } = {}
	local seen: { [string]: boolean } = {}

	for _, asset in manifest.assets do
		if not hasText(asset.id) then
			table.insert(problems, "hay un asset sin id")
			continue
		end

		local id = asset.id
		if seen[id] then
			table.insert(problems, `{id}: id repetido en el manifiesto`)
			continue
		end
		seen[id] = true

		checkAsset(asset, id, problems)
	end

	return problems
end

-- Ids de src/ que no existen en el manifiesto: nadie referencia un asset que no está registrado.
function Manifest.unknownRefs(manifest: Manifest, refs: { string }): { string }
	local known: { [string]: boolean } = {}
	for _, asset in manifest.assets do
		known[asset.id] = true
	end

	local missing = {}
	for _, ref in refs do
		if not known[ref] then
			table.insert(missing, ref)
		end
	end
	return missing
end

-- Ids de asset de Roblox que aparecen en un texto, sin repetir y en orden de aparición.
function Manifest.assetRefs(source: string): { string }
	local refs: { string } = {}
	for ref in string.gmatch(source, "rbxassetid://%d+") do
		if not table.find(refs, ref) then
			table.insert(refs, ref)
		end
	end
	return refs
end

-- Ids de asset que ninguna entrada del manifiesto registra en su `assetId`.
function Manifest.unknownAssets(manifest: Manifest, refs: { string }): { string }
	local known: { [string]: boolean } = {}
	for _, asset in manifest.assets do
		if asset.assetId ~= nil then
			known[asset.assetId] = true
		end
		-- Un asset puede ser varias mallas: el manifiesto lo trata como uno y registra todos sus ids.
		local extra: { string } = asset.assetIds or {}
		for _, id in extra do
			known[id] = true
		end
	end
	local missing: { string } = {}
	for _, ref in refs do
		if not known[ref] then
			table.insert(missing, ref)
		end
	end
	return missing
end

-- Problemas de un archivo de código: cada id de asset sin registrar, con el archivo donde está.
function Manifest.sourceProblems(manifest: Manifest, path: string, source: string): { string }
	local problems: { string } = {}
	for _, ref in Manifest.unknownAssets(manifest, Manifest.assetRefs(source)) do
		table.insert(problems, `{path}: {ref} no está en el manifiesto`)
	end
	return problems
end

return Manifest

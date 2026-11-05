--!strict
-- Actores de escena (plan 07, tarea 6): policías, patrullas, multitud, obreros, grúa y los vehículos que
-- piden las escenas del plan 08. `spawn` devuelve un `Model?`: un modelo anclado y sin colisión con su
-- origen en `at`, o nil si el tipo está al tope o falta su arte (y avisa por `warn`).
--
-- Las personas salen de `Robloxian`, con el uniforme de policía o de obrero y la multitud vestida con la
-- paleta de abajo; los vehículos y la grúa, de las mallas de `ReplicatedStorage.ArtAssets` que describe
-- `ArtAssets.actors`, y la patrulla, de `ArtAssets.patrol`. No hay mallas nuevas.
--
-- El recuento lo lleva `ActorsRules`, que es puro: aquí solo se guardan los modelos libres de cada tipo y
-- se reciclan. `despawn` devuelve el modelo al pool o lo destruye si no cabe, y `clear` lo borra todo al
-- acabar la escena. `clear` es global a propósito: `SceneDirector` reproduce una escena cada vez, así que
-- dos escenas no comparten actores; si algún día se solapan, hará falta una carpeta por escena.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ActorsRules = require("./ActorsRules")
local ArtAssets = require("../../shared/config/ArtAssets")
local Robloxian = require("../world/Robloxian")

export type Kind = ActorsRules.Kind
type Person = Robloxian.Robloxian
type Piece = ArtAssets.Piece

-- Un actor vivo: su modelo y, según el tipo, las piezas del vehículo con su sitio en el arte o la
-- persona de `Robloxian`, que se recoloca entera con `pose`.
type Record = {
	kind: Kind,
	model: Model,
	parts: { BasePart },
	offsets: { CFrame },
	person: Person?,
	pooled: boolean,
}

local CONTAINER_NAME = "SceneActors"
local ACTOR_ATTRIBUTE = "ActorKind"

-- Uniformes. Los del policía son los mismos colores que usa `Arrest`: es el mismo personaje en toda la
-- ciudad. El obrero lleva pantalón de trabajo, camisa naranja y el casco de `ArtAssets.actors.workerHelmet`.
local POLICE_PANTS = Color3.fromRGB(27, 42, 74)
local POLICE_SHIRT = Color3.fromRGB(58, 86, 140)
local WORKER_PANTS = Color3.fromRGB(90, 58, 36)
local WORKER_SHIRT = Color3.fromRGB(245, 158, 11)
-- Multitud: cada uno con su ropa. Sin amarillo, que ya es del taxi y del casco del obrero.
local CROWD = {
	{ Color3.fromRGB(52, 70, 94), Color3.fromRGB(196, 56, 43) },
	{ Color3.fromRGB(88, 76, 96), Color3.fromRGB(237, 229, 211) },
	{ Color3.fromRGB(60, 62, 66), Color3.fromRGB(31, 95, 168) },
	{ Color3.fromRGB(68, 84, 72), Color3.fromRGB(139, 92, 246) },
	{ Color3.fromRGB(110, 44, 44), Color3.fromRGB(210, 201, 180) },
	{ Color3.fromRGB(150, 152, 150), Color3.fromRGB(16, 185, 129) },
}

-- Mallas de cada vehículo: la patrulla tiene grupo propio y el resto sale de `ArtAssets.actors`.
local VEHICLES: { [string]: { Piece } } = {
	PatrolCar = ArtAssets.patrol,
	Crane = ArtAssets.actors.Crane,
	TowTruck = ArtAssets.actors.TowTruck,
	ArmoredTruck = ArtAssets.actors.ArmoredTruck,
	WreckingBall = ArtAssets.actors.WreckingBall,
}

local pools = ActorsRules.new()
-- Modelos libres por tipo: el pool de verdad. `pools` lleva la cuenta y estas listas guardan las mallas.
local free: { [Kind]: { Model } } = {}
-- Se lee por índice y con el tipo anotado: la iteración genérica ensancha los literales del array.
for index = 1, #ActorsRules.KINDS do
	local kind: Kind = ActorsRules.KINDS[index]
	free[kind] = {}
end
-- Los modelos vivos, para encontrar su tipo al liberarlos. Claves débiles: si una escena borra un modelo
-- por su cuenta, su ficha no se queda pegada.
local records: { [Model]: Record } = setmetatable({}, { __mode = "k" }) :: any
local sceneFolder: Folder? = nil
-- Rota la ropa de la multitud para que dos personas seguidas no salgan vestidas igual.
local crowdIndex = 0

local function artFolder(): Instance?
	return ReplicatedStorage:FindFirstChild(ArtAssets.FOLDER)
end

local function sourceOf(art: Instance, key: string): BasePart?
	local source = art:FindFirstChild(key)
	if source ~= nil and source:IsA("BasePart") then
		return source
	end
	return nil
end

-- Copia las piezas de un grupo de arte con el origen en `at`. Falso si falta alguna: mejor un actor menos
-- que medio coche suelto.
local function clonePieces(
	model: Model,
	art: Instance,
	group: { Piece },
	parts: { BasePart },
	offsets: { CFrame }
): boolean
	for _, piece in group do
		local source = sourceOf(art, piece.key)
		if source == nil then
			warn(`Actors: falta la pieza {piece.key} de {model.Name}`)
			return false
		end
		local mesh = source:Clone() :: BasePart
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanTouch = false
		mesh.CanQuery = false
		mesh.Parent = model
		table.insert(parts, mesh)
		table.insert(offsets, source.CFrame)
	end
	return true
end

-- Piezas de la gorra o del casco que ya estén cargadas. Si falta alguna, la persona va sin ella: el
-- uniforme sigue siendo su seña.
local function capSources(art: Instance?, group: { Piece }): { BasePart }
	local sources: { BasePart } = {}
	if art == nil then
		return sources
	end
	for _, piece in group do
		local source = sourceOf(art, piece.key)
		if source ~= nil then
			table.insert(sources, source)
		end
	end
	return sources
end

-- Persona con el uniforme de su papel. La multitud no lleva gorra y cambia de ropa en cada aparición.
local function buildPerson(model: Model, kind: Kind, art: Instance?): Person?
	if kind == "Police" then
		return Robloxian.create(model, {
			body = POLICE_PANTS,
			shirt = POLICE_SHIRT,
			cap = capSources(art, ArtAssets.officerCap),
			police = true,
		})
	end
	if kind == "Worker" then
		return Robloxian.create(model, {
			body = WORKER_PANTS,
			shirt = WORKER_SHIRT,
			cap = capSources(art, ArtAssets.actors.workerHelmet),
		})
	end
	if kind ~= "Crowd" then
		return nil
	end
	crowdIndex += 1
	local look = CROWD[(crowdIndex - 1) % #CROWD + 1]
	return Robloxian.create(model, { body = look[1], shirt = look[2] })
end

-- Crea el modelo de un tipo. Su sitio lo pone `place`. `nil` si falta el arte de un vehículo.
local function build(kind: Kind): Record?
	local art = artFolder()
	local group: { Piece }? = VEHICLES[kind]
	local model = Instance.new("Model")
	model.Name = kind
	model:SetAttribute(ACTOR_ATTRIBUTE, kind)
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	local person: Person? = nil
	if group ~= nil then
		if art == nil or not clonePieces(model, art, group, parts, offsets) then
			model:Destroy()
			return nil
		end
	else
		-- La gorra y el casco se resuelven al crear la persona. Sin el arte cargado, la persona se
		-- quedaría sin ellos para siempre al reciclarse, así que no se crea hasta que el arte está listo.
		if
			(kind == "Police" or kind == "Worker")
			and (art == nil or art:GetAttribute(ArtAssets.READY_ATTRIBUTE) ~= true)
		then
			model:Destroy()
			return nil
		end
		person = buildPerson(model, kind, art)
		if person == nil then
			model:Destroy()
			return nil
		end
	end
	return { kind = kind, model = model, parts = parts, offsets = offsets, person = person, pooled = false }
end

-- Pone el modelo en `at`. Los vehículos recolocan cada malla con su sitio del arte; las personas se posan
-- enteras con `pose`, con los pies en el suelo.
local function place(record: Record, at: CFrame)
	local person = record.person
	if person ~= nil then
		person.pose(at * CFrame.new(0, Robloxian.TORSO_HEIGHT, 0), 0)
	else
		for index, part in record.parts do
			part.CFrame = at * record.offsets[index]
		end
	end
	record.model.WorldPivot = at
end

-- Carpeta de todos los actores. Se crea al primer `spawn` y agrupa los modelos de las escenas.
local function actorsFolder(): Folder
	local current = sceneFolder
	if current ~= nil and current.Parent ~= nil then
		return current
	end
	local found = Workspace:FindFirstChild(CONTAINER_NAME)
	if found ~= nil and found:IsA("Folder") then
		sceneFolder = found
		return found
	end
	local created = Instance.new("Folder")
	created.Name = CONTAINER_NAME
	created.Parent = Workspace
	sceneFolder = created
	return created
end

-- Saca un modelo del pool y lo vuelve a poner en `at`. `nil` si la cuenta y la lista no cuadran.
local function reuse(kind: Kind, at: CFrame): Model?
	local model = table.remove(free[kind])
	if model == nil then
		return nil
	end
	local record = records[model]
	if record == nil then
		-- La lista tenía un modelo que ya no es un actor: se descarta para que no vuelva a salir.
		model:Destroy()
		return nil
	end
	record.pooled = false
	place(record, at)
	record.model.Parent = actorsFolder()
	return model
end

-- Un actor desapareció por fuera (la escena lo destruyó sin `despawn`): se olvida y se descuenta.
local function forget(model: Model)
	local record = records[model]
	if record == nil then
		return
	end
	records[model] = nil
	if record.pooled then
		local list = free[record.kind]
		local index = table.find(list, model)
		if index ~= nil then
			table.remove(list, index)
		end
	else
		ActorsRules.abandon(pools[record.kind])
	end
end

local Actors = {}

-- Crea (o recicla) un actor del tipo pedido con su origen en `at`. `nil` si el tipo no existe, si el pool
-- está al tope o si falta su arte.
function Actors.spawn(kind: Kind, at: CFrame): Model?
	local known: Kind? = ActorsRules.kindOf(kind)
	if known == nil then
		warn(`Actors: tipo desconocido "{kind}"`)
		return nil
	end
	local state = pools[known]
	local slot = ActorsRules.take(state)
	if slot == nil then
		warn(`Actors: {known} ya tiene {state.max} actores vivos`)
		return nil
	end
	if slot == "reuse" then
		local model = reuse(known, at)
		if model ~= nil then
			return model
		end
		-- La lista no tenía el modelo que la cuenta prometía: la lista manda y se resincroniza.
		state.free = #free[known]
		ActorsRules.cancel(state, "create")
		warn(`Actors: el pool de {known} no tenía el modelo que decía la cuenta`)
		return nil
	end
	local record = build(known)
	if record == nil then
		ActorsRules.cancel(state, "create")
		warn(`Actors: no se pudo construir {known} (falta arte o aún no está listo)`)
		return nil
	end
	place(record, at)
	records[record.model] = record
	record.model.Destroying:Connect(function()
		forget(record.model)
	end)
	record.model.Parent = actorsFolder()
	return record.model
end

-- Devuelve el actor al pool. Si el pool ya no tiene hueco (el tope bajó o la cuenta no cuadra), lo
-- destruye. Llamarlo dos veces sobre el mismo modelo no hace nada la segunda.
function Actors.despawn(model: Model)
	local record = records[model]
	if record == nil or record.pooled then
		return
	end
	local release = ActorsRules.drop(pools[record.kind])
	if release == "recycle" then
		record.pooled = true
		record.model.Parent = nil
		table.insert(free[record.kind], record.model)
		return
	end
	records[model] = nil
	record.model:Destroy()
end

-- Borra todos los actores, vacía el pool y las cuentas. Cada escena lo llama al terminar; `SceneDirector`
-- las reproduce de una en una, así que no hay dos escenas compartiendo esta carpeta.
function Actors.clear()
	local models: { Model } = {}
	for model in records do
		table.insert(models, model)
	end
	-- Se vacía antes de destruir para que los avisos de `Destroying` no toquen cuentas ya limpiadas.
	table.clear(records)
	for _, model in models do
		model:Destroy()
	end
	for _, list in free do
		table.clear(list)
	end
	ActorsRules.clearAll(pools)
	crowdIndex = 0
	if sceneFolder ~= nil then
		if sceneFolder.Parent ~= nil then
			sceneFolder:Destroy()
		end
		sceneFolder = nil
	end
end

-- Anima a una persona: `root` es la cadera, `swing` balancea brazos y piernas y `reach` (0 a 1) adelanta
-- los brazos. Devuelve false si el modelo no es una persona o ya no existe.
function Actors.pose(model: Model, root: CFrame, swing: number, reach: number?): boolean
	local record = records[model]
	if record == nil or record.person == nil then
		return false
	end
	record.person.pose(root, swing, reach)
	return true
end

return Actors

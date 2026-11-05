--!strict
-- Personajes y vehículos de escena. Cada tipo tiene su reserva (`ActorPool`), con el tope de
-- `Scenes.actors.limits`: crear y destruir se reduce a enseñar y guardar, y una escena no puede dejar
-- la memoria creciendo. Las personas son `Robloxian` con otro uniforme; los vehículos, mallas de
-- `ArtAssets.actors`, salvo la patrulla, que ya existe.
--
-- Un tipo cuyas mallas aún no se han registrado o cargado devuelve un modelo vacío y avisa una vez: la
-- partida no depende del arte. Se rellena solo en cuanto llegan.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActorPool = require("./ActorPool")
local ArtAssets = require("../../shared/config/ArtAssets")
local Robloxian = require("../world/Robloxian")
local Scenes = require("../../shared/config/Scenes")

export type Kind =
	"Police"
	| "PatrolCar"
	| "Crowd"
	| "Worker"
	| "Crane"
	| "TowTruck"
	| "ArmoredTruck"
	| "WreckingBall"

type Style = { body: Color3, shirt: Color3?, police: boolean?, capKey: "officerCap" | "workerHelmet" | nil }

local Actors = {}

local holding: Folder? = nil
local pools: { [string]: ActorPool.Pool<Model> } = {}
-- De qué tipo es cada modelo y, si es una persona, su esqueleto. Se guardan para siempre: el tope de
-- cada reserva acota cuántos modelos llegan a existir.
local kindOf: { [Model]: string } = {}
local people: { [Model]: Robloxian.Robloxian } = {}
local warned: { [string]: boolean } = {}
local crowdTurn = 0

local function colorOf(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function art(): Instance?
	return ReplicatedStorage:FindFirstChild(ArtAssets.FOLDER)
end

local function holder(): Folder
	local folder = holding
	if folder == nil then
		local made = Instance.new("Folder")
		made.Name = "ActorsPool"
		-- Fuera del Workspace no se dibuja nada: es donde esperan los actores libres.
		made.Parent = ReplicatedStorage
		holding = made
		return made
	end
	return folder
end

local function piecesOf(kind: string): { ArtAssets.Piece }?
	if kind == "PatrolCar" then
		return ArtAssets.patrol
	end
	return ArtAssets.actors[kind]
end

-- Copia las mallas del vehículo con su sitio respecto al origen. El pivote queda en ese origen, así
-- que `PivotTo` lo coloca sin soldaduras. Si alguna falta, el modelo se queda vacío hasta otro intento.
local function fillVehicle(model: Model, kind: string): boolean
	if #model:GetChildren() > 0 then
		return true
	end
	local folder = art()
	local pieces = piecesOf(kind)
	if folder == nil or pieces == nil or #pieces == 0 then
		return false
	end
	for _, piece in pieces do
		if folder:FindFirstChild(piece.key) == nil then
			return false
		end
	end
	for _, piece in pieces do
		local source = folder:FindFirstChild(piece.key) :: BasePart
		local mesh = source:Clone()
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanTouch = false
		mesh.CanQuery = false
		mesh.Parent = model
	end
	model.WorldPivot = CFrame.new()
	return true
end

local function styleOf(kind: string): Style
	local style = Scenes.actors
	if kind == "Police" then
		return {
			body = colorOf(style.policeUniform),
			shirt = colorOf(style.policeShirt),
			police = true,
			capKey = "officerCap",
		}
	elseif kind == "Worker" then
		return { body = colorOf(style.workerUniform), capKey = "workerHelmet" }
	end
	crowdTurn = crowdTurn % #style.crowdColors + 1
	return { body = colorOf(style.crowdColors[crowdTurn]) }
end

local function isPerson(kind: string): boolean
	return kind == "Police" or kind == "Crowd" or kind == "Worker"
end

local function buildPerson(kind: string): Model
	local style = styleOf(kind)
	local caps: { BasePart } = {}
	local folder = art()
	local capPieces: { ArtAssets.Piece } = if style.capKey == "officerCap"
		then ArtAssets.officerCap
		elseif style.capKey == "workerHelmet" then ArtAssets.workerHelmet
		else {}
	if folder ~= nil then
		for _, piece in capPieces do
			local source = folder:FindFirstChild(piece.key)
			if source ~= nil and source:IsA("BasePart") then
				table.insert(caps, source)
			end
		end
	end
	local person = Robloxian.create(holder(), {
		body = style.body,
		shirt = style.shirt,
		cap = caps,
		police = style.police,
	})
	people[person.model] = person
	return person.model
end

local function poolOf(kind: string): ActorPool.Pool<Model>
	local pool = pools[kind]
	if pool ~= nil then
		return pool
	end
	local limit = Scenes.actors.limits[kind]
	if limit == nil then
		error(`Actors: el tipo {kind} no existe`, 3)
	end
	local made = ActorPool.new(limit, function(): Model
		local model: Model
		if isPerson(kind) then
			model = buildPerson(kind)
		else
			model = Instance.new("Model")
			model.Name = kind
		end
		kindOf[model] = kind
		return model
	end)
	pools[kind] = made
	return made
end

-- Saca un actor a escena en `at`, con los pies en ese punto.
function Actors.spawn(kind: Kind, at: CFrame): Model
	local model = poolOf(kind).acquire()
	local person = people[model]
	if person ~= nil then
		person.pose(at * CFrame.new(0, Robloxian.TORSO_HEIGHT, 0), 0)
	elseif fillVehicle(model, kind) then
		model:PivotTo(at)
	elseif not warned[kind] then
		warned[kind] = true
		warn(`Actors: {kind} aún no tiene mallas; se queda vacío hasta que lleguen.`)
	end
	model.Parent = workspace
	return model
end

-- Guarda el actor para la siguiente escena. Devolver uno que no salió de aquí no hace nada.
function Actors.despawn(model: Model)
	local kind = kindOf[model]
	if kind == nil then
		return
	end
	poolOf(kind).release(model)
	model.Parent = holder()
end

-- Esqueleto de una persona, para animarla en su escena. Nil si es un vehículo.
function Actors.personOf(model: Model): Robloxian.Robloxian?
	return people[model]
end

-- Actores de ese tipo que hay ahora en escena.
function Actors.activeCount(kind: Kind): number
	return poolOf(kind).activeCount()
end

return Actors

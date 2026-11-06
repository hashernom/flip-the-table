--!strict
-- Amuebla las zonas ya ambientadas con las mallas de `ArtAssets`. Dónde va cada pieza lo decide
-- `CityLayout`, que es puro; aquí solo se copian. Sin mallas cargadas no pone nada, y se vuelve a llamar
-- cuando llegan: construir dos veces deja el mismo resultado.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ArtAssets = require("../../shared/config/ArtAssets")
local CityBuilder = require("./CityBuilder")
local CityLayout = require("../../shared/config/CityLayout")

local FOLDER = "StreetDressing"
local TRAFFIC_FOLDER = "Traffic"
local CAR_SPEED = 24

local trafficConnection: RBXScriptConnection? = nil

local BACKDROP_FOLDER = "Backdrop"

-- Fachadas de la ciudad de fondo: material y color de cada tono de `CityLayout.BACKDROP.tones`. Ladrillo,
-- caliza, hormigón y cristal, como el resto de la ciudad (art/vision-visual.md); nada de neón.
local TONES: { { material: Enum.Material, color: Color3 } } = {
	{ material = Enum.Material.Brick, color = Color3.fromRGB(150, 84, 62) },
	{ material = Enum.Material.Limestone, color = Color3.fromRGB(206, 196, 174) },
	{ material = Enum.Material.Concrete, color = Color3.fromRGB(142, 140, 134) },
	{ material = Enum.Material.Brick, color = Color3.fromRGB(118, 70, 56) },
	{ material = Enum.Material.Sandstone, color = Color3.fromRGB(190, 170, 136) },
	{ material = Enum.Material.Slate, color = Color3.fromRGB(96, 102, 108) },
}
local WINDOW_COLOR = Color3.fromRGB(56, 78, 98)
local LEDGE_COLOR = Color3.fromRGB(70, 72, 76)
local GRASS_COLOR = Color3.fromRGB(86, 120, 64)
local WINDOW_STEP = 5
local WINDOW_HEIGHT = 2.2

local StreetDressing = {}

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local made = Instance.new("Part")
	made.Name = name
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = true
	made.Size = size
	made.CFrame = cframe
	made.Color = color
	made.Material = material
	made.TopSurface = Enum.SurfaceType.Smooth
	made.BottomSurface = Enum.SurfaceType.Smooth
	return made
end

-- Un bloque de la ciudad de fondo: cuerpo, cornisa y bandas de ventanas en la fachada que da a la calle.
local function block(item: CityLayout.Backdrop, parent: Instance)
	local w, d, h = item.w or 20, item.d or 20, item.h or 20
	local tone = TONES[item.tone or 1] or TONES[1]
	local base = Vector3.new(item.x, 0, item.z)
	local origin = CFrame.lookAt(base, base + Vector3.new(item.lookX, 0, item.lookZ))
	local model = Instance.new("Model")
	model.Name = "Block"
	part("Body", Vector3.new(w, h, d), origin * CFrame.new(0, h / 2, 0), tone.color, tone.material).Parent =
		model
	part(
		"Ledge",
		Vector3.new(w + 1, 0.8, d + 1),
		origin * CFrame.new(0, h + 0.4, 0),
		LEDGE_COLOR,
		Enum.Material.Concrete
	).Parent =
		model
	-- La fachada mira a la calle: -Z del origen. Una banda de cristal por planta, sin la planta baja.
	local floor = WINDOW_STEP
	while floor + WINDOW_HEIGHT < h - 1 do
		part(
			"Windows",
			Vector3.new(w - 3, WINDOW_HEIGHT, 0.3),
			origin * CFrame.new(0, floor + WINDOW_HEIGHT / 2, -d / 2 - 0.1),
			WINDOW_COLOR,
			Enum.Material.Glass
		).Parent =
			model
		floor += WINDOW_STEP
	end
	model.Parent = parent
end

-- Decorado de fuera del anillo (`CityLayout.backdropFor`). Los bloques y el césped no necesitan arte; los
-- árboles, farolas y bancos, sí: sin `art` se quedan para la siguiente llamada.
function StreetDressing.buildBackdrop(city: CityBuilder.CityHandles, art: Instance?)
	local previous = city.model:FindFirstChild(BACKDROP_FOLDER)
	if previous ~= nil then
		previous:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = BACKDROP_FOLDER
	for _, item in CityLayout.backdropFor(city.sizeId) do
		if item.kind == "Block" then
			block(item, folder)
		elseif item.kind == "Grass" then
			local base = Vector3.new(item.x, 0, item.z)
			local origin = CFrame.lookAt(base, base + Vector3.new(item.lookX, 0, item.lookZ))
			part(
				"Grass",
				Vector3.new(item.w or 20, 0.3, item.d or 20),
				origin * CFrame.new(0, 0.15, 0),
				GRASS_COLOR,
				Enum.Material.Grass
			).Parent =
				folder
		elseif art ~= nil and ArtAssets.street[item.kind] ~= nil then
			local y = if item.kind == "Lamp" or item.kind == "Tree" then 0.4 else 0.3
			local position = Vector3.new(item.x, y, item.z)
			local origin = CFrame.lookAt(position, position + Vector3.new(item.lookX, 0, item.lookZ))
			for _, piece in ArtAssets.street[item.kind] do
				local source = art:FindFirstChild(piece.key)
				if source ~= nil and source:IsA("BasePart") then
					local mesh = source:Clone()
					mesh.CFrame = origin * source.CFrame
					mesh.Parent = folder
				end
			end
		end
	end
	folder.Parent = city.model
end

function StreetDressing.build(city: CityBuilder.CityHandles)
	local previous = city.model:FindFirstChild(FOLDER)
	if previous ~= nil then
		previous:Destroy()
	end
	local art = ReplicatedStorage:FindFirstChild(ArtAssets.FOLDER)
	StreetDressing.buildBackdrop(city, art)
	if art == nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	for _, zone in ArtAssets.dressedZones do
		for _, item in CityLayout.dressingFor(city.sizeId, zone) do
			local position = Vector3.new(item.x, item.y, item.z)
			local origin = CFrame.lookAt(position, position + Vector3.new(item.lookX, 0, item.lookZ))
			for _, piece in ArtAssets.street[item.kind] do
				local source = art:FindFirstChild(piece.key)
				if source ~= nil and source:IsA("BasePart") then
					local mesh = source:Clone()
					mesh.CFrame = origin * source.CFrame
					mesh.Parent = folder
				end
			end
		end
	end
	folder.Parent = city.model
end

-- Pone los coches a circular. Es decorado de este cliente: no toca la partida y cada jugador puede ver los
-- coches en un sitio distinto.
function StreetDressing.startTraffic(city: CityBuilder.CityHandles)
	if trafficConnection ~= nil then
		trafficConnection:Disconnect()
		trafficConnection = nil
	end
	local previous = city.model:FindFirstChild(TRAFFIC_FOLDER)
	if previous ~= nil then
		previous:Destroy()
	end
	local art = ReplicatedStorage:FindFirstChild(ArtAssets.FOLDER)
	if art == nil then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = TRAFFIC_FOLDER
	local length = CityLayout.trafficLength(city.sizeId)
	local cars: { { parts: { BasePart }, offsets: { CFrame }, start: number } } = {}
	for order, color in ArtAssets.carColors do
		local car = { parts = {}, offsets = {}, start = length * (order - 1) / #ArtAssets.carColors }
		for _, piece in ArtAssets.street.Car do
			local source = art:FindFirstChild(piece.key)
			if source ~= nil and source:IsA("BasePart") then
				local mesh = source:Clone()
				if piece.key == ArtAssets.CAR_BODY then
					mesh.Color = Color3.fromRGB(color[1], color[2], color[3])
				end
				mesh.Parent = folder
				table.insert(car.parts, mesh)
				table.insert(car.offsets, source.CFrame)
			end
		end
		table.insert(cars, car)
	end
	folder.Parent = city.model

	local sizeId: CityLayout.SizeId = city.sizeId
	local allParts: { BasePart } = {}
	for _, car in cars do
		table.move(car.parts, 1, #car.parts, #allParts + 1, allParts)
	end
	local travelled = 0
	trafficConnection = RunService.Heartbeat:Connect(function(dt: number)
		travelled += dt * CAR_SPEED
		local frames: { CFrame } = {}
		for _, car in cars do
			local x, z, forwardX, forwardZ = CityLayout.trafficPose(sizeId, travelled + car.start)
			local position = Vector3.new(x, 0, z)
			local origin = CFrame.lookAt(position, position + Vector3.new(forwardX, 0, forwardZ))
			for _, offset in car.offsets do
				table.insert(frames, origin * offset)
			end
		end
		Workspace:BulkMoveTo(allParts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

return StreetDressing

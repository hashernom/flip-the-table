--!strict
-- Amuebla cada barrio con las mallas de `ArtAssets`. Qué se pone lo decide `Barrios`, y dónde, `CityLayout`,
-- que es puro; aquí solo se copian. Sin mallas cargadas no pone nada, y se vuelve a llamar cuando llegan:
-- construir dos veces deja el mismo resultado.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ArtAssets = require("../../shared/config/ArtAssets")
local Barrios = require("../../shared/config/Barrios")
local CityBuilder = require("./CityBuilder")
local CityLayout = require("../../shared/config/CityLayout")

local FOLDER = "StreetDressing"
local TRAFFIC_FOLDER = "Traffic"
local CAR_SPEED = 24

local trafficConnection: RBXScriptConnection? = nil

local StreetDressing = {}

function StreetDressing.build(city: CityBuilder.CityHandles)
	local previous = city.model:FindFirstChild(FOLDER)
	if previous ~= nil then
		previous:Destroy()
	end
	local art = ReplicatedStorage:FindFirstChild(ArtAssets.FOLDER)
	if art == nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	for _, barrioId in CityLayout.barriosFor(city.sizeId) do
		-- Un barrio que aún no tiene sus mallas se queda sin amueblar, pero la ciudad se construye.
		if not Barrios.has(barrioId) then
			continue
		end
		for _, item in CityLayout.dressingFor(city.sizeId, barrioId) do
			local pieces = ArtAssets.street[item.kind]
			if pieces == nil then
				warn(`StreetDressing: {barrioId} pide "{item.kind}" y no está en ArtAssets`)
				continue
			end
			local position = Vector3.new(item.x, item.y, item.z)
			local origin = CFrame.lookAt(position, position + Vector3.new(item.lookX, 0, item.lookZ))
			for _, piece in pieces do
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

--!strict
-- Amuebla las zonas ya ambientadas con las mallas de `ArtAssets`. Dónde va cada pieza lo decide
-- `CityLayout`, que es puro; aquí solo se copian. Sin mallas cargadas no pone nada, y se vuelve a llamar
-- cuando llegan: construir dos veces deja el mismo resultado.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtAssets = require("../../shared/config/ArtAssets")
local CityBuilder = require("./CityBuilder")
local CityLayout = require("../../shared/config/CityLayout")

local FOLDER = "StreetDressing"

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

return StreetDressing

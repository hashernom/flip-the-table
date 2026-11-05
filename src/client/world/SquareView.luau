--!strict
-- Coloca el lugar de cada casilla especial en su solar, con el mismo origen que las propiedades y
-- la cárcel: centro de la base a ras de suelo y el retranqueo de `ArtAssets.FRONT_OFFSET`.
--
-- Un tipo de casilla se repite en varias casillas del tablero, así que cada solar recibe su copia del
-- mismo modelo. Si a un tipo le falta una sola malla, no se coloca nada de ese tipo: un lugar a medias
-- se ve peor que el solar vacío, y `main` vuelve a llamar cuando terminen de cargar los modelos.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtAssets = require("../../shared/config/ArtAssets")
local CityBuilder = require("./CityBuilder")
local CityLayout = require("../../shared/config/CityLayout")

local FOLDER = "Squares"

local SquareView = {}

local function ready(art: Instance, pieces: { ArtAssets.Piece }): boolean
	for _, piece in pieces do
		local source = art:FindFirstChild(piece.key)
		if source == nil or not source:IsA("BasePart") then
			return false
		end
	end
	return true
end

function SquareView.build(city: CityBuilder.CityHandles)
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
	for _, slot in CityLayout.routeFor(city.sizeId) do
		local pieces = ArtAssets.squares[slot.kind]
		if pieces == nil or not ready(art, pieces) then
			continue
		end
		local model = Instance.new("Model")
		model.Name = `Square_{slot.kind}_{slot.index}`
		local origin = city.lotOf(slot.index) * CFrame.new(0, 0, ArtAssets.FRONT_OFFSET)
		for _, piece in pieces do
			local source = art:FindFirstChild(piece.key)
			if source ~= nil and source:IsA("BasePart") then
				local mesh = source:Clone()
				mesh.Name = piece.key
				mesh.CFrame = origin * source.CFrame
				mesh.Parent = model
			end
		end
		model.Parent = folder
	end
	folder.Parent = city.model
end

return SquareView

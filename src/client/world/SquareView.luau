--!strict
-- Lugares de las casillas especiales: el edificio o el decorado de cada tipo, en el solar de cada casilla de
-- ese tipo. Es solo decorado, como `JailView`: sin mallas registradas o cargadas no levanta nada, y se vuelve
-- a llamar cuando llegan. Se puede repetir: sustituye lo que hubiera.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtAssets = require("../../shared/config/ArtAssets")
local CityBuilder = require("./CityBuilder")
local CityLayout = require("../../shared/config/CityLayout")

local FOLDER = "SpecialSquares"

local SquareView = {}

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
		if pieces ~= nil then
			-- El solar mira a la calle con su -Z; el edificio se retrasa hacia el fondo, igual que las propiedades.
			local origin = city.lotOf(slot.index) * CFrame.new(0, 0, ArtAssets.FRONT_OFFSET)
			local place = Instance.new("Model")
			place.Name = `{slot.kind}{slot.index}`
			for _, piece in pieces do
				local source = art:FindFirstChild(piece.key)
				if source ~= nil and source:IsA("BasePart") then
					local mesh = source:Clone()
					mesh.CFrame = origin * source.CFrame
					mesh.Parent = place
				end
			end
			place.Parent = folder
		end
	end
	folder.Parent = city.model
end

return SquareView

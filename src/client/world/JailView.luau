--!strict
-- Cárcel: el edificio que está en el solar de la casilla Tribunal (la de la esquina donde se detiene a
-- alguien). Es solo decorado: no es una casilla ni una propiedad, así que `BuildingView` no la toca y no
-- le pone bloque gris. Sin mallas reales no se levanta nada, y se vuelve a llamar cuando llegan, como
-- `StreetDressing.build`. La posición sale de `CityBuilder` (`lotOf`) y de `ArtAssets.FRONT_OFFSET`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArrestRules = require("../scenes/ArrestRules")
local ArtAssets = require("../../shared/config/ArtAssets")
local CityBuilder = require("./CityBuilder")
local CityLayout = require("../../shared/config/CityLayout")

local FOLDER = "Jail"

local JailView = {}

function JailView.build(city: CityBuilder.CityHandles)
	local previous = city.model:FindFirstChild(FOLDER)
	if previous ~= nil then
		previous:Destroy()
	end
	local art = ReplicatedStorage:FindFirstChild(ArtAssets.FOLDER)
	if art == nil then
		return
	end
	local slot = ArrestRules.tribunalSlot(CityLayout.routeFor(city.sizeId))
	if slot == nil then
		return
	end

	-- El solar mira a la calle con su -Z; el edificio se retrasa hacia el fondo, igual que las propiedades.
	-- La cárcel siempre queda fuera del anillo: la escena de la detención está montada así.
	local origin = city.outsideLotOf(slot.index) * CFrame.new(0, 0, ArtAssets.FRONT_OFFSET)
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	for _, piece in ArtAssets.jail do
		local source = art:FindFirstChild(piece.key)
		if source ~= nil and source:IsA("BasePart") then
			local mesh = source:Clone()
			mesh.CFrame = origin * source.CFrame
			mesh.Parent = folder
		end
	end
	folder.Parent = city.model
end

return JailView

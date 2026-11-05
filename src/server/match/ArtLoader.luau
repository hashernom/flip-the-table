--!strict
-- Carga las mallas reales y las deja donde los clientes puedan copiarlas: `InsertService` solo funciona en
-- el servidor. Si una falla, se avisa y esa pieza no aparece; la partida no depende del arte.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtAssets = require("../../shared/config/ArtAssets")

local ArtLoader = {}

local function loadPiece(folder: Folder, piece: ArtAssets.Piece)
	local id = tonumber(string.match(piece.assetId, "%d+"))
	local ok, loaded: any = pcall(function()
		return InsertService:LoadAsset(id :: number)
	end)
	local mesh = if ok then loaded:FindFirstChildWhichIsA("BasePart", true) else nil
	if mesh == nil then
		warn(`ArtLoader: no se pudo cargar {piece.key}: {if ok then "sin malla" else loaded}`)
	else
		mesh.Name = piece.key
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanTouch = false
		mesh.CanQuery = false
		mesh.Color = Color3.fromRGB(piece.color[1], piece.color[2], piece.color[3])
		mesh.Material = (Enum.Material :: any)[piece.material]
		mesh.Reflectance = piece.reflectance or 0
		mesh.Parent = folder
	end
end

function ArtLoader.start()
	local folder = Instance.new("Folder")
	folder.Name = ArtAssets.FOLDER
	folder.Parent = ReplicatedStorage
	task.spawn(function()
		local order = ArtAssets.loadOrder()
		-- Los hilos comparten el índice: Luau no cambia de hilo entre leer y sumar, así que no se repite pieza.
		local nextIndex = 0
		local workers = math.min(ArtAssets.LOAD_WORKERS, #order)
		local finished = 0
		for _ = 1, workers do
			task.spawn(function()
				while true do
					nextIndex += 1
					local piece = order[nextIndex]
					if piece == nil then
						break
					end
					loadPiece(folder, piece)
				end
				finished += 1
			end)
		end
		-- El atributo se activa una sola vez, cuando han terminado todos los hilos, falle o no alguna malla.
		while finished < workers do
			task.wait()
		end
		folder:SetAttribute(ArtAssets.READY_ATTRIBUTE, true)
	end)
end

return ArtLoader

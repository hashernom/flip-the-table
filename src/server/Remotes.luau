--!strict
-- Fábrica de RemoteEvent compartida por los dos lugares de la subfase 04. No vive en src/shared
-- porque usa `game` e `Instance` y el pase estándar de src/shared prohíbe las APIs de Roblox; para
-- que la misma ruta resuelva en los dos proyectos, se monta en ServerScriptService.Server.Remotes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Los remotos viven en ReplicatedStorage/FlipTheTableRemotes. El cliente del plan 05 los busca en
-- esa misma carpeta.
local FOLDER_NAME = "FlipTheTableRemotes"

local Remotes = {}

local function folder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		if existing:IsA("Folder") then
			return existing :: Folder
		end
		error(`Remotes: {FOLDER_NAME} existe en ReplicatedStorage y no es una carpeta`, 2)
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = ReplicatedStorage
	return created
end

-- RemoteEvent del protocolo, creándolo si hace falta. El nombre vive en Protocol.REMOTES; aquí
-- solo se garantiza que exista y que sea del tipo correcto.
function Remotes.remote(name: string): RemoteEvent
	local parent = folder()
	local existing = parent:FindFirstChild(name)
	if existing then
		if existing:IsA("RemoteEvent") then
			return existing :: RemoteEvent
		end
		error(`Remotes: {FOLDER_NAME}.{name} existe y no es un RemoteEvent`, 2)
	end
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = parent
	return event
end

return Remotes

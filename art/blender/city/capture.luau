--!nocheck
-- Captura de la ciudad por barrios en Studio, en modo edición.
--
-- Sirve para lo que el plan pide al cerrar cada lote: ver el barrio construido por el código de
-- verdad (`CityBuilder` + `StreetDressing`), no una maqueta aparte. Carga solo las mallas de los
-- barrios que pide, levanta la ciudad del tamaño pedido y devuelve la cámara ya encuadrada.
--
-- Uso con el MCP de Studio (execute_luau, datamodel Edit), pegando esto tal cual, o cambiando
-- `PEDIDO` al principio:
--
--   local PEDIDO = { sizeId = "L", barrios = { "Centro", "Puerto", "ZonaAlta", "Industrial" }, mirar = "Centro" }
--
-- Devuelve `{ posicion = Vector3, objetivo = Vector3, piezas = n }`: se lo pasa a `screen_capture`
-- como `camera_position` y `look_at_position`. Nada de esto se guarda en el lugar.

local PEDIDO = {
	sizeId = "L",
	barrios = { "Centro" },
	mirar = "Centro",
	-- Altura de la cámara y distancia al eje de la calle, hacia el interior del anillo.
	altura = 26,
	retroceso = 70,
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local StarterPlayer = game:GetService("StarterPlayer")

local config = ReplicatedStorage:FindFirstChild("Shared"):FindFirstChild("config")
local ArtAssets = require(config.ArtAssets)
local Barrios = require(config.Barrios)
local CityLayout = require(config.CityLayout)
local client = StarterPlayer:FindFirstChild("StarterPlayerScripts"):FindFirstChild("Client")
local CityBuilder = require(client.world.CityBuilder)
local StreetDressing = require(client.world.StreetDressing)

-- 1. Las mallas de los barrios pedidos, como las deja `ArtLoader` en el servidor.
local folder = ReplicatedStorage:FindFirstChild(ArtAssets.FOLDER)
if folder then
	folder:Destroy()
end
folder = Instance.new("Folder")
folder.Name = ArtAssets.FOLDER

local cargadas = 0
for _, barrioId in PEDIDO.barrios do
	if not Barrios.has(barrioId) then
		continue
	end
	local barrio = Barrios.get(barrioId)
	local kinds = { barrio.walk, barrio.crosswalk }
	table.move(barrio.backdrops, 1, #barrio.backdrops, #kinds + 1, kinds)
	for _, rule in barrio.rules do
		table.insert(kinds, rule.kind)
	end

	local vistos = {}
	for _, kind in kinds do
		if vistos[kind] then
			continue
		end
		vistos[kind] = true
		for _, piece in ArtAssets.street[kind] or {} do
			local model = InsertService:LoadAsset(tonumber(string.match(piece.assetId, "%d+")))
			local mesh = model:FindFirstChildWhichIsA("BasePart", true)
			if mesh then
				mesh.Name = piece.key
				mesh.Anchored = true
				mesh.CanCollide = false
				mesh.Color = Color3.fromRGB(piece.color[1], piece.color[2], piece.color[3])
				mesh.Material = (Enum.Material :: any)[piece.material]
				mesh.Reflectance = piece.reflectance or 0
				mesh.Parent = folder
				cargadas += 1
			end
			model:Destroy()
		end
	end
end
folder:SetAttribute(ArtAssets.READY_ATTRIBUTE, true)
folder.Parent = ReplicatedStorage

-- 2. La ciudad del tamaño pedido, con su mobiliario y su fondo.
local anterior = workspace:FindFirstChild(`City_{PEDIDO.sizeId}`)
if anterior then
	anterior:Destroy()
end
local handles = CityBuilder.build(PEDIDO.sizeId, workspace)
StreetDressing.build(handles)
handles.refreshBackdrops()

-- 3. Encuadre: desde dentro del anillo, mirando la fachada del barrio pedido.
local route = CityLayout.routeFor(PEDIDO.sizeId)
local slots = {}
for _, slot in route do
	if slot.barrioId == PEDIDO.mirar then
		table.insert(slots, slot)
	end
end
if #slots == 0 then
	return { error = `el barrio {PEDIDO.mirar} no entra en {PEDIDO.sizeId}`, piezas = cargadas }
end
local centro = slots[math.ceil(#slots / 2)]
local outX, outZ = math.cos(centro.facing), -math.sin(centro.facing)
local base = Vector3.new(centro.position.x, 0, centro.position.z)
local posicion = base - Vector3.new(outX, 0, outZ) * PEDIDO.retroceso + Vector3.new(0, PEDIDO.altura, 0)
local objetivo = base + Vector3.new(outX, 0, outZ) * 30 + Vector3.new(0, 8, 0)
workspace.CurrentCamera.CFrame = CFrame.lookAt(posicion, objetivo)

return {
	posicion = posicion,
	objetivo = objetivo,
	piezas = cargadas,
	casillas = #slots,
}

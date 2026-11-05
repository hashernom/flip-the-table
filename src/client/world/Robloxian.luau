--!strict
-- Robloxiano clásico, para la escena de la detención: los policías y el relleno de un bot detenido. Se construye
-- con partes en código: torso 2x2x1, brazos y piernas 1x2x1 y cabeza 2x1x1 con SpecialMesh de tipo Head. Todo va
-- anclado, sin colisiones ni consultas, y el personaje se mueve entero con `pose`, que coloca cada parte con su
-- CFrame. Con `police` lleva camisa, corbata, placa, cinturón, radio, gafas de sol y botas. Nunca lleva armas.
local ArrestStaging = require("../../shared/config/ArrestStaging")

export type Robloxian = {
	-- Pone el personaje con la cadera en `root` (el centro del torso). `swing` balancea brazos y piernas al andar y
	-- `reach` (0 a 1) adelanta los brazos, para sujetar al detenido.
	pose: (root: CFrame, swing: number, reach: number?) -> (),
	destroy: () -> (),
}

export type Options = {
	body: Color3,
	cap: { BasePart }?,
	-- Uniforme de policía: `body` son los pantalones y `shirt` la camisa y las mangas.
	police: boolean?,
	shirt: Color3?,
}

-- Tono de piel neutro: no define a nadie; el uniforme es lo que se lee.
local SKIN = Color3.fromRGB(234, 184, 146)
local DARK = Color3.fromRGB(26, 28, 32)
local GOLD = Color3.fromRGB(201, 162, 39)
-- Cara clásica, incluida en el propio cliente de Roblox.
local FACE_TEXTURE = "rbxasset://textures/face.png"
-- Centro del torso sobre el suelo: las piernas miden 2 y el torso 2, así que los pies quedan en y = 0.
local TORSO_HEIGHT = 3
-- Tamaño de la gorra respecto a la pieza del arte.
local CAP_SCALE = ArrestStaging.CAP_SCALE
-- Brazos hacia delante con `reach` en 1 (radianes).
local REACH_RADIANS = math.rad(75)

local Robloxian = {}

Robloxian.TORSO_HEIGHT = TORSO_HEIGHT

local function piece(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = parent
	return part
end

-- Detalles del uniforme: cada uno cuelga de una parte del cuerpo, con su tamaño, color y sitio en ella. El frente
-- del personaje es -Z.
local function policeDetails(
	shirtColor: Color3
): { { limb: string, size: Vector3, color: Color3, at: Vector3 } }
	local collar = shirtColor:Lerp(Color3.new(1, 1, 1), 0.35)
	return {
		{
			limb = "Torso",
			size = Vector3.new(0.9, 0.22, 0.06),
			color = collar,
			at = Vector3.new(0, 0.88, -0.5),
		},
		{
			limb = "Torso",
			size = Vector3.new(0.24, 1.15, 0.06),
			color = DARK,
			at = Vector3.new(0, 0.2, -0.52),
		},
		{
			limb = "Torso",
			size = Vector3.new(0.36, 0.42, 0.06),
			color = GOLD,
			at = Vector3.new(-0.55, 0.42, -0.52),
		},
		{
			limb = "Torso",
			size = Vector3.new(0.3, 0.46, 0.14),
			color = DARK,
			at = Vector3.new(0.58, 0.42, -0.55),
		},
		{ limb = "Torso", size = Vector3.new(2.06, 0.26, 1.06), color = DARK, at = Vector3.new(0, -0.86, 0) },
		{
			limb = "Torso",
			size = Vector3.new(0.34, 0.2, 0.06),
			color = GOLD,
			at = Vector3.new(0, -0.86, -0.55),
		},
		{
			limb = "Torso",
			size = Vector3.new(0.4, 0.3, 0.16),
			color = DARK,
			at = Vector3.new(0.75, -0.86, -0.56),
		},
		{ limb = "Head", size = Vector3.new(1, 0.2, 0.08), color = DARK, at = Vector3.new(0, 0.1, -0.62) },
		{
			limb = "LeftArm",
			size = Vector3.new(1.04, 0.14, 1.04),
			color = GOLD,
			at = Vector3.new(0, 0.96, 0),
		},
		{
			limb = "RightArm",
			size = Vector3.new(1.04, 0.14, 1.04),
			color = GOLD,
			at = Vector3.new(0, 0.96, 0),
		},
		{
			limb = "LeftArm",
			size = Vector3.new(1.02, 0.34, 1.02),
			color = SKIN,
			at = Vector3.new(0, -0.84, 0),
		},
		{
			limb = "RightArm",
			size = Vector3.new(1.02, 0.34, 1.02),
			color = SKIN,
			at = Vector3.new(0, -0.84, 0),
		},
		{
			limb = "LeftLeg",
			size = Vector3.new(1.04, 0.4, 1.2),
			color = DARK,
			at = Vector3.new(0, -0.82, -0.08),
		},
		{
			limb = "RightLeg",
			size = Vector3.new(1.04, 0.4, 1.2),
			color = DARK,
			at = Vector3.new(0, -0.82, -0.08),
		},
	}
end

-- `body` es el color del uniforme. `cap` son las piezas de la gorra, que se copian y se colocan sobre la cabeza en
-- cada `pose`. Sin `cap` el personaje va sin gorra.
function Robloxian.create(parent: Instance, options: Options): Robloxian
	local model = Instance.new("Model")
	model.Name = "Robloxian"
	local upper = options.shirt or options.body

	local torso = piece("Torso", Vector3.new(2, 2, 1), upper, model)
	local head = piece("Head", Vector3.new(2, 1, 1), SKIN, model)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Texture = FACE_TEXTURE
	face.Face = Enum.NormalId.Front
	face.Parent = head
	local leftArm = piece("LeftArm", Vector3.new(1, 2, 1), upper, model)
	local rightArm = piece("RightArm", Vector3.new(1, 2, 1), upper, model)
	local leftLeg = piece("LeftLeg", Vector3.new(1, 2, 1), options.body, model)
	local rightLeg = piece("RightLeg", Vector3.new(1, 2, 1), options.body, model)
	local limbs: { [string]: BasePart } = {
		Torso = torso,
		Head = head,
		LeftArm = leftArm,
		RightArm = rightArm,
		LeftLeg = leftLeg,
		RightLeg = rightLeg,
	}

	local details: { { part: BasePart, limb: BasePart, offset: CFrame } } = {}
	if options.police then
		for _, detail in policeDetails(upper) do
			table.insert(details, {
				part = piece("Detail", detail.size, detail.color, model) :: BasePart,
				limb = limbs[detail.limb],
				offset = CFrame.new(detail.at),
			})
		end
	end

	local caps: { { part: BasePart, offset: CFrame } } = {}
	local sources: { BasePart } = options.cap or {}
	for _, source in sources do
		local copy = source:Clone()
		copy.Size = source.Size * CAP_SCALE
		copy.Anchored = true
		copy.CanCollide = false
		copy.CanTouch = false
		copy.CanQuery = false
		copy.Parent = model
		-- La posición de la pieza se escala con la gorra; su giro se conserva tal cual.
		table.insert(caps, {
			part = copy,
			offset = CFrame.new(source.CFrame.Position * CAP_SCALE) * source.CFrame.Rotation,
		})
	end

	model.Parent = parent

	local function pose(root: CFrame, swing: number, reach: number?)
		local forward = (reach or 0) * REACH_RADIANS
		torso.CFrame = root
		head.CFrame = root * CFrame.new(0, 1.5, 0)
		-- Cada extremidad gira sobre su articulación (el hombro o la cadera) y su centro queda un bloque por
		-- debajo de ella.
		leftArm.CFrame = root
			* CFrame.new(-1.5, 1, 0)
			* CFrame.Angles(swing + forward, 0, 0)
			* CFrame.new(0, -1, 0)
		rightArm.CFrame = root
			* CFrame.new(1.5, 1, 0)
			* CFrame.Angles(forward - swing, 0, 0)
			* CFrame.new(0, -1, 0)
		leftLeg.CFrame = root * CFrame.new(-0.5, -1, 0) * CFrame.Angles(-swing, 0, 0) * CFrame.new(0, -1, 0)
		rightLeg.CFrame = root * CFrame.new(0.5, -1, 0) * CFrame.Angles(swing, 0, 0) * CFrame.new(0, -1, 0)
		for _, detail in details do
			detail.part.CFrame = detail.limb.CFrame * detail.offset
		end
		-- La gorra va sobre la coronilla, con la base de su malla en la parte alta de la cabeza.
		local crown = root * CFrame.new(0, 2, 0)
		for _, cap in caps do
			cap.part.CFrame = crown * cap.offset
		end
	end

	return {
		pose = pose,
		destroy = function()
			model:Destroy()
		end,
	}
end

return Robloxian

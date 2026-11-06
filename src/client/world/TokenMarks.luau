--!strict
-- Marcas fijas sobre las fichas (plan 08, Tarea 6): la corona del líder, que se ve durante toda la partida, y
-- el cartel de traidor, que dura las rondas de su marca (`traitorUntilRound`). Siguen a la vista: se ponen y
-- se quitan cada vez que el mundo se concilia, así que nunca se quedan en una ficha que ya no toca.
--
-- Las piezas van soldadas al cuerpo de la ficha, como su atrezo: se mueven con ella por la calle.
local GameScenes = require("../scenes/game/GameScenes")
local Strings = require("../../shared/config/Strings")
local Theme = require("../ui/Theme")

local CROWN_NAME = "LeaderCrown"
local TRAITOR_NAME = "TraitorMark"
-- Altura sobre el centro de la ficha: por encima de la cabeza del avatar que va montado.
local CROWN_LIFT = 13
local TRAITOR_LIFT = 17

local TokenMarks = {}

local function weld(piece: BasePart, body: BasePart)
	piece.Anchored = false
	piece.Massless = true
	piece.CanCollide = false
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = body
	joint.Part1 = piece
	joint.Parent = piece
end

local function addCrown(token: Model, body: BasePart)
	local folder = Instance.new("Folder")
	folder.Name = CROWN_NAME
	folder.Parent = token
	local center = CFrame.new(body.Position + Vector3.new(0, CROWN_LIFT, 0))
		* CFrame.Angles(0, 0, math.rad(8))
	for _, item in GameScenes.makeCrown(folder) do
		item.part.CFrame = center * item.offset
		weld(item.part, body)
	end
end

local function addTraitor(token: Model, body: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = TRAITOR_NAME
	gui.Adornee = body
	gui.Size = UDim2.fromOffset(150, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, TRAITOR_LIFT, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	local plate = Instance.new("TextLabel")
	plate.Size = UDim2.fromScale(1, 1)
	plate.BackgroundColor3 = Theme.color.signal
	plate.TextColor3 = Theme.color.limestone
	plate.FontFace = Theme.font.roadBold
	plate.TextScaled = true
	plate.Text = Strings.upper(Strings.get("scene.backstab.stamp"))
	plate.Rotation = -4
	plate.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = plate
	local rim = Instance.new("UIStroke")
	rim.Color = Theme.color.limestone
	rim.Thickness = 2
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Parent = plate
	gui.Parent = token
end

-- Pone o quita las marcas de cada ficha según la vista: corona a quien la lleva y cartel a quien sigue
-- marcado de traidor esta ronda.
function TokenMarks.sync(view: any, tokens: { [string]: Model })
	if view == nil or type(view.players) ~= "table" then
		return
	end
	local pending = view.pending
	local crownId = if type(pending) == "table" then pending.crownId else nil
	local round = if type(view.round) == "number" then view.round else 0
	local traitors: { [string]: boolean } = {}
	for _, seated in view.players do
		local untilRound = seated.traitorUntilRound
		if type(untilRound) == "number" and untilRound >= round then
			traitors[seated.id] = true
		end
	end
	for id, token in tokens do
		local body = token.PrimaryPart
		if body == nil then
			continue
		end
		local hasCrown = token:FindFirstChild(CROWN_NAME) ~= nil
		local wantsCrown = crownId == id and view.phase ~= "GameOver"
		if wantsCrown and not hasCrown then
			addCrown(token, body)
		elseif not wantsCrown and hasCrown then
			(token:FindFirstChild(CROWN_NAME) :: Instance):Destroy()
		end
		local hasMark = token:FindFirstChild(TRAITOR_NAME) ~= nil
		if traitors[id] and not hasMark then
			addTraitor(token, body)
		elseif not traitors[id] and hasMark then
			(token:FindFirstChild(TRAITOR_NAME) :: Instance):Destroy()
		end
	end
end

return TokenMarks

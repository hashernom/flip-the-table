--!strict
-- Primera partida guiada. Un cartel pequeño con un consejo de una frase que entra, se queda unos
-- segundos y se va solo: nunca detiene la partida ni obliga a cerrarlo, aunque se puede tocar para
-- quitarlo antes. Solo lo ve quien no ha terminado ninguna partida (`GuidedMatchRules.shouldGuide`), y
-- cada concepto se explica una vez. Qué consejo toca lo deciden las reglas; aquí solo se enseña.
local Players = game:GetService("Players")

local Board = require("./Board")
local Components = require("./Components")
local GuidedMatchRules = require("./GuidedMatchRules")
local Strings = require("../../shared/config/Strings")
local Theme = require("./Theme")
local Ui = require("../../shared/config/Ui")

export type Handles = {
	-- Eventos de un lote ya reproducido y la fase en que le toca decidir al jugador, si le toca.
	observe: (events: { any }, decisionPhase: string?) -> (),
	-- Durante una escena el cartel se aparta; vuelve al acabar si le queda tiempo.
	setSceneMode: (active: boolean) -> (),
	destroy: () -> (),
}

local GuidedMatch = {}

-- Atributo que el servidor pone en el jugador con sus partidas terminadas (`PlayerProfile`).
GuidedMatch.ATTRIBUTE = "CompletedMatches"

function GuidedMatch.create(playerGui: Instance): Handles
	local config = Ui.guide
	local gui = Theme.screenGui(playerGui, "GuidedMatch", 6)

	local button = Instance.new("TextButton")
	button.Name = "Tip"
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.Text = ""
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -config.bottom)
	button.Size = UDim2.fromOffset(config.width, 0)
	button.AutomaticSize = Enum.AutomaticSize.Y
	button.Visible = false
	button.Parent = gui

	local poster = Board.Poster(button, "Paper", 0, true, config.tilt)
	local title = Board.caption(poster.content, "Title", Strings.get("guide.title"), 1)
	title.TextColor3 = Theme.color.navy
	local text = Board.text(poster.content, "Text", "", 2, 17)

	local seen: { [string]: boolean } = {}
	local queue: { string } = {}
	local showing = false
	local sceneActive = false
	local token = 0
	local current: string? = nil

	local function guided(): boolean
		local player = Players.LocalPlayer
		local value = if player ~= nil then player:GetAttribute(GuidedMatch.ATTRIBUTE) else nil
		return GuidedMatchRules.shouldGuide(if type(value) == "number" then value else nil)
	end

	local showNext: () -> ()

	-- Sitio del cartel: se mueve el botón entero, no el papel, para que su tamaño automático no salte.
	local rest = UDim2.new(0.5, 0, 1, -config.bottom)
	local lowered = UDim2.new(0.5, 0, 1, -config.bottom + config.rise)
	local closing = false

	local function hide(mine: number)
		if token ~= mine or closing or not showing then
			return
		end
		closing = true
		token += 1
		local closed = token
		Components.tween(button, Ui.motion.close, { Position = lowered })
		task.delay(Ui.motion.close, function()
			if token ~= closed then
				return
			end
			closing = false
			button.Visible = false
			showing = false
			current = nil
			showNext()
		end)
	end

	showNext = function()
		if showing or closing or sceneActive or #queue == 0 then
			return
		end
		local tip = table.remove(queue, 1) :: string
		current = tip
		showing = true
		token += 1
		local mine = token
		text.Text = Strings.get(`guide.{tip}`)
		button.Position = lowered
		button.Visible = true
		Components.tween(button, Ui.motion.open, { Position = rest })
		task.delay(config.seconds, function()
			hide(mine)
		end)
	end

	-- Tocarlo lo quita antes de tiempo, pero no hace falta: se va solo.
	button.Activated:Connect(function()
		hide(token)
	end)

	local function offer(event: any)
		local tip = GuidedMatchRules.tipFor(event, seen)
		if tip ~= nil then
			seen[tip] = true
			table.insert(queue, tip)
		end
	end

	-- La última decisión vista: si el perfil llega después que la primera vista, su consejo no se pierde.
	local pendingPhase: string? = nil
	local player = Players.LocalPlayer
	if player ~= nil then
		player:GetAttributeChangedSignal(GuidedMatch.ATTRIBUTE):Connect(function()
			local phase = pendingPhase
			if phase ~= nil and guided() then
				pendingPhase = nil
				offer(GuidedMatchRules.decisionEvent(phase))
				showNext()
			end
		end)
	end

	return {
		observe = function(events: { any }, decisionPhase: string?)
			if not guided() then
				pendingPhase = decisionPhase
				return
			end
			pendingPhase = nil
			for _, event in events do
				if type(event) == "table" and type(event.type) == "string" then
					offer(event)
				end
			end
			if decisionPhase ~= nil then
				offer(GuidedMatchRules.decisionEvent(decisionPhase))
			end
			showNext()
		end,
		setSceneMode = function(active: boolean)
			sceneActive = active
			if active and showing and not closing then
				-- La escena manda: el consejo se aparta y vuelve entero al acabar.
				local tip = current
				if tip ~= nil then
					table.insert(queue, 1, tip)
				end
				hide(token)
			elseif not active then
				showNext()
			end
		end,
		destroy = function()
			gui:Destroy()
		end,
	}
end

return GuidedMatch

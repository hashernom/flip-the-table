--!strict
-- Ajustes: volumen de la música y de los efectos por separado, y los atajos de teclado a la vista. Es
-- un tablón pequeño del mismo estándar que el resto de ventanas. Los volúmenes valen al momento y duran
-- mientras se juega; quien los aplica es `AudioDirector`.
local UserInputService = game:GetService("UserInputService")

local Board = require("./Board")
local Components = require("./Components")
local Strings = require("../../shared/config/Strings")
local Theme = require("./Theme")
local Ui = require("../../shared/config/Ui")

export type Handles = {
	setOpen: (open: boolean) -> (),
	isOpen: () -> boolean,
	-- Volúmenes de partida, de 0 a 1.
	setVolumes: (music: number, effects: number) -> (),
	onChanged: (callback: (music: number, effects: number) -> ()) -> (),
	destroy: () -> (),
}

local SettingsMenu = {}

-- Teclas que se listan, en el orden en que se usan.
local KEYS: { string } = { "Space", "N", "M", "T", "P", "K", "Esc" }

type Slider = { set: (value: number) -> (), get: () -> number, connections: { RBXScriptConnection } }

-- Barra de volumen sobre el papel: pista de asfalto, tramo lleno en marino y un tirador redondo. Se
-- arrastra o se toca en cualquier punto; la cifra al lado dice el porcentaje.
local function slider(
	parent: Instance,
	order: number,
	captionKey: string,
	onMove: (value: number) -> ()
): Slider
	local config = Ui.slider
	local color = Theme.color
	local row = Instance.new("Frame")
	row.Name = `Slider{order}`
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, config.rowHeight)
	row.LayoutOrder = order
	row.Parent = parent

	local caption = Components.label(row, "Caption", Strings.upper(Strings.get(captionKey)), {
		face = Theme.font.roadBold,
		size = 18,
		tint = color.asphalt,
	})
	caption.Size = UDim2.new(0, config.captionWidth, 1, 0)
	caption.TextYAlignment = Enum.TextYAlignment.Center

	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.AutoButtonColor = false
	track.Text = ""
	track.BackgroundColor3 = color.asphalt
	track.BorderSizePixel = 0
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, config.captionWidth, 0.5, 0)
	track.Size = UDim2.new(1, -(config.captionWidth + config.valueWidth), 0, config.trackHeight)
	track.Parent = row
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0.5, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = color.navy
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fill

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.BackgroundColor3 = color.limestone
	knob.BorderSizePixel = 0
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0, 0.5)
	knob.Size = UDim2.fromOffset(config.knob, config.knob)
	knob.Parent = track
	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(0.5, 0)
	knobCorner.Parent = knob
	local knobRim = Instance.new("UIStroke")
	knobRim.Color = color.asphalt
	knobRim.Thickness = 4
	knobRim.Parent = knob

	local valueLabel = Components.label(row, "Value", "", {
		face = Theme.font.textBold,
		size = 18,
		tint = color.asphalt,
		align = Enum.TextXAlignment.Right,
	})
	valueLabel.AnchorPoint = Vector2.new(1, 0)
	valueLabel.Position = UDim2.fromScale(1, 0)
	valueLabel.Size = UDim2.new(0, config.valueWidth - 12, 1, 0)
	valueLabel.TextYAlignment = Enum.TextYAlignment.Center

	local value = 0
	local function paint()
		fill.Size = UDim2.fromScale(value, 1)
		knob.Position = UDim2.fromScale(value, 0.5)
		valueLabel.Text = Strings.get("settings.percent", { value = math.floor(value * 100 + 0.5) })
	end
	local function fromPointer(x: number)
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		value = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
		paint()
		onMove(value)
	end

	local dragging = false
	track.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			dragging = true
			Components.tween(
				knob,
				Ui.motion.press,
				{ Size = UDim2.fromOffset(config.knob + 6, config.knob + 6) }
			)
			fromPointer(input.Position.X)
		end
	end)
	local connections: { RBXScriptConnection } = {}
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if
				dragging and (kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch)
			then
				fromPointer(input.Position.X)
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if dragging and (kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch) then
				dragging = false
				Components.tween(knob, Ui.motion.press, { Size = UDim2.fromOffset(config.knob, config.knob) })
			end
		end)
	)

	return {
		connections = connections,
		set = function(next: number)
			value = math.clamp(next, 0, 1)
			paint()
		end,
		get = function(): number
			return value
		end,
	}
end

function SettingsMenu.create(playerGui: Instance): Handles
	local size = Ui.settingsBoard
	local window = Board.Window(playerGui, "SettingsMenu", 12, true, Vector2.new(size.width, size.height))
	Board.Header(window.stack, 1, {
		title = Strings.get("settings.title"),
		help = Strings.get("settings.help"),
		steps = {
			Strings.get("settings.step1"),
			Strings.get("settings.step2"),
			Strings.get("settings.step3"),
		},
		onClose = function()
			window.setOpen(false)
		end,
	})

	local listeners: { (number, number) -> () } = {}
	local poster = Board.Poster(window.stack, "Sound", 2, true)
	local musicSlider: Slider
	local effectsSlider: Slider
	local function changed()
		for _, listener in listeners do
			listener(musicSlider.get(), effectsSlider.get())
		end
	end
	musicSlider = slider(poster.content, 1, "settings.music", changed)
	effectsSlider = slider(poster.content, 2, "settings.effects", changed)

	local keys = Board.Poster(window.stack, "Keys", 3, false)
	keys.root.Size = UDim2.fromScale(1, 0)
	Board.fill(keys.root)
	Board.caption(keys.content, "Caption", Strings.get("settings.keys"), 1)
	for index, key in KEYS do
		local row = Instance.new("Frame")
		row.Name = `Key{key}`
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 24)
		row.LayoutOrder = index + 1
		row.Parent = keys.content
		local layout = Board.list(row, Enum.FillDirection.Horizontal, Theme.space.m)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		local keyName = if key == "Space" then Strings.get("settings.keyName.Space") else key
		local cap = Components.label(row, "Cap", keyName, {
			face = Theme.font.road,
			size = 13,
			align = Enum.TextXAlignment.Center,
		})
		cap.BackgroundTransparency = 0
		cap.BackgroundColor3 = Theme.color.asphalt
		cap.Size = UDim2.fromOffset(Ui.slider.keyWidth, 22)
		local capCorner = Instance.new("UICorner")
		capCorner.CornerRadius = UDim.new(0, 5)
		capCorner.Parent = cap
		local what = Components.label(row, "What", Strings.get(`settings.key.{key}`), {
			face = Theme.font.text,
			size = 15,
			tint = Theme.color.asphalt,
		})
		what.Size = UDim2.new(1, -(Ui.slider.keyWidth + Theme.space.m), 1, 0)
		what.LayoutOrder = 2
	end

	return {
		setOpen = window.setOpen,
		isOpen = window.isOpen,
		setVolumes = function(music: number, effects: number)
			musicSlider.set(music)
			effectsSlider.set(effects)
		end,
		onChanged = function(callback: (number, number) -> ())
			table.insert(listeners, callback)
		end,
		destroy = function()
			for _, item in { musicSlider, effectsSlider } do
				for _, connection in item.connections do
					connection:Disconnect()
				end
			end
			window.gui:Destroy()
		end,
	}
end

return SettingsMenu

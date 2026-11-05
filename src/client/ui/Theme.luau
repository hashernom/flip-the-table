--!strict
-- Piezas comunes de la interfaz gris. Todo el arte es temporal: colores planos, sin imágenes, sin
-- iconos. Existe para que los menús no repitan la misma veintena de líneas y para que las medidas
-- táctiles y la zona segura se decidan en un solo sitio.
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Ui = require("../../shared/config/Ui")

local Theme = {}

Theme.background = Color3.fromRGB(28, 30, 34)
Theme.panelColor = Color3.fromRGB(44, 47, 53)
Theme.buttonColor = Color3.fromRGB(64, 68, 76)
Theme.buttonHot = Color3.fromRGB(92, 98, 108)
Theme.accent = Color3.fromRGB(240, 190, 70)
Theme.danger = Color3.fromRGB(200, 80, 74)
Theme.text = Color3.fromRGB(238, 238, 240)
Theme.muted = Color3.fromRGB(168, 172, 180)

Theme.font = Enum.Font.GothamMedium
Theme.fontBold = Enum.Font.GothamBold

-- Medidas táctiles: el dedo no perdona un botón de 20 píxeles. El mínimo es el de la ficha.
Theme.MIN_TOUCH = 44
Theme.PADDING = 8
Theme.RADIUS = 10

-- Inserto de la zona segura: en un móvil con muesca, la interfaz se aparta de los bordes.
function Theme.inset(): Vector2
	return GuiService:GetGuiInset()
end

-- Pantalla completa que respeta la zona segura del dispositivo.
function Theme.screenGui(playerGui: Instance, name: string, displayOrder: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder
	-- CoreUISafeInsets suma la muesca del móvil y la barra superior de Roblox: sin eso, la barra de
	-- estado queda debajo de los botones del menú del motor.
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = playerGui
	return gui
end

function Theme.corner(instance: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.RADIUS)
	corner.Parent = instance
end

function Theme.padding(instance: GuiObject, amount: number?)
	local padding = Instance.new("UIPadding")
	local value = UDim.new(0, amount or Theme.PADDING)
	padding.PaddingTop = value
	padding.PaddingBottom = value
	padding.PaddingLeft = value
	padding.PaddingRight = value
	padding.Parent = instance
end

-- Panel con un título opcional. Devuelve el marco donde van los hijos.
function Theme.panel(parent: Instance, name: string, title: string?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Theme.panelColor
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Theme.corner(frame)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, Theme.PADDING)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	Theme.padding(frame)

	if title ~= nil then
		local label = Instance.new("TextLabel")
		label.Name = "Title"
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, 26)
		label.Font = Theme.fontBold
		label.TextSize = 20
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Theme.text
		label.Text = title
		label.LayoutOrder = 0
		label.Parent = frame
	end

	return frame
end

-- Ancho de un panel: la fracción que se le dé del ancho de la pantalla, con un tope en píxeles. En un
-- móvil estrecho manda la fracción; en una pantalla grande, el tope. Sin esto, un panel de ancho fijo
-- se sale de la pantalla (I13).
function Theme.limitWidth(instance: GuiObject)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(Ui.maxPanelWidth, math.huge)
	limit.Parent = instance
end

-- Alto máximo, en píxeles, de una lista dentro de un panel: una fracción de la altura de la pantalla.
function Theme.maxListHeight(): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera ~= nil then camera.ViewportSize.Y else 600
	return math.floor(viewport * Ui.maxPanelHeightFraction)
end

-- Lista vertical con scroll. Crece con su contenido hasta `Theme.maxListHeight()` y a partir de ahí
-- hace scroll: sin ese tope, el scroll de un modal nunca actuaba porque la lista crecía con sus filas y
-- se salía de la pantalla (I13). El tope sigue al tamaño de la pantalla.
--
-- El alto se fija a mano, sin `AutomaticSize`. Comprobado en Studio (2026-11-04): un panel con
-- `AutomaticSize` no recalcula al crecer un `ScrollingFrame` que también lo usa. La lista medía 160 y el
-- panel seguía en 16, así que los botones no se veían hasta que algo redimensionaba la ventana.
function Theme.scrollList(parent: Instance, name: string, order: number): ScrollingFrame
	local list = Instance.new("ScrollingFrame")
	list.Name = name
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.fromScale(1, 0)
	list.CanvasSize = UDim2.fromScale(0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollingDirection = Enum.ScrollingDirection.Y
	list.ScrollBarThickness = 6
	list.LayoutOrder = order
	list.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, Theme.PADDING)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local function fit()
		list.Size = UDim2.new(1, 0, 0, math.min(layout.AbsoluteContentSize.Y, Theme.maxListHeight()))
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	return list
end

-- Rótulo de sección dentro de un panel o de la lista de un modal.
function Theme.header(parent: Instance, text: string, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = `Header_{order}`
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Font = Theme.fontBold
	label.TextSize = 16
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Theme.muted
	label.Text = text
	label.LayoutOrder = order
	label.Parent = parent
	return label
end

-- Botón grande, con etiqueta y acción. El alto nunca baja del mínimo táctil.
function Theme.button(parent: Instance, text: string, order: number, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = `Action_{order}`
	button.AutoButtonColor = false
	button.BackgroundColor3 = Theme.buttonColor
	button.BorderSizePixel = 0
	button.Size = UDim2.new(1, 0, 0, math.max(Theme.MIN_TOUCH, 48))
	button.Font = Theme.fontBold
	button.TextSize = 18
	button.TextColor3 = Theme.text
	button.Text = text
	-- Un texto largo, como la descripción de un perk, crece hacia abajo en vez de cortarse por los lados.
	button.TextWrapped = true
	button.AutomaticSize = Enum.AutomaticSize.Y
	button.LayoutOrder = order
	button.Parent = parent
	Theme.corner(button, 8)
	Theme.padding(button, 8)

	button.MouseButton1Click:Connect(function()
		button.BackgroundColor3 = Theme.buttonHot
		onClick()
		task.delay(0.15, function()
			if button.Parent then
				button.BackgroundColor3 = Theme.buttonColor
			end
		end)
	end)

	return button
end

-- Fila de texto dentro de un panel: etiqueta a la izquierda y valor a la derecha.
function Theme.row(parent: Instance, order: number): (TextLabel, TextLabel)
	local row = Instance.new("Frame")
	row.Name = `Row_{order}`
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 24)
	row.LayoutOrder = order
	row.Parent = parent

	local key = Instance.new("TextLabel")
	key.BackgroundTransparency = 1
	key.Size = UDim2.fromScale(0.6, 1)
	key.Font = Theme.font
	key.TextSize = 16
	key.TextXAlignment = Enum.TextXAlignment.Left
	key.TextColor3 = Theme.muted
	key.Parent = row

	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.fromScale(1, 0)
	value.Size = UDim2.fromScale(0.4, 1)
	value.Font = Theme.fontBold
	value.TextSize = 16
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.TextColor3 = Theme.text
	value.Parent = row

	return key, value
end

-- Ventana modal con título, fondo y un panel vertical donde colgar filas. La usan la vista general y
-- los menús sociales, que comparten la misma forma.
export type Modal = {
	gui: ScreenGui,
	panel: Frame,
	-- Lista con scroll donde van las filas de la ventana. Con siete rivales, un menú social tiene más
	-- botones de los que caben en un móvil: sin scroll, «Proponer» queda fuera de la pantalla.
	body: ScrollingFrame,
	backdrop: TextButton,
	setOpen: (open: boolean) -> (),
	isOpen: () -> boolean,
}

function Theme.modal(playerGui: Instance, name: string, title: string, displayOrder: number): Modal
	local gui = Theme.screenGui(playerGui, name, displayOrder)

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.BackgroundColor3 = Theme.background
	backdrop.BackgroundTransparency = 0.25
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Visible = false
	backdrop.Parent = gui

	local panel = Theme.panel(gui, "Sheet", title)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.Visible = false
	Theme.limitWidth(panel)

	local body = Theme.scrollList(panel, "Body", 1)

	local modal: Modal = nil :: any
	modal = {
		gui = gui,
		panel = panel,
		body = body,
		backdrop = backdrop,
		setOpen = function(open: boolean)
			backdrop.Visible = open
			panel.Visible = open
		end,
		isOpen = function(): boolean
			return panel.Visible
		end,
	}

	backdrop.MouseButton1Click:Connect(function()
		modal.setOpen(false)
	end)

	return modal
end

return Theme

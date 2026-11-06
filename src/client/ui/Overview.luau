--!strict
-- Vista general en maqueta. Es la vista que la ficha promete con un botón: dinero, efectos y posiciones
-- de un vistazo, por encima de la ciudad. Va en un cartel estrecho en la columna derecha, bajo el
-- minimapa, para no tapar la maqueta ni la columna de jugadores. Las propiedades no se repiten aquí:
-- cada una lleva su tarjeta sobre la maqueta. No interrumpe escenas: la abre y la cierra el cliente,
-- que es quien sabe si hay una escena en marcha.
local Board = require("./Board")
local Components = require("./Components")
local HudRules = require("./HudRules")
local Strings = require("../../shared/config/Strings")
local Theme = require("./Theme")
local Ui = require("../../shared/config/Ui")
local ViewText = require("./ViewText")

export type Handles = {
	setView: (view: any, names: ViewText.Names?) -> (),
	setOpen: (open: boolean) -> (),
	isOpen: () -> boolean,
	onToggle: (callback: (open: boolean) -> ()) -> (),
	close: () -> (),
	destroy: () -> (),
}

local Overview = {}

-- Marca de estado de un asiento. Un activo no lleva ninguna. Un bot ya lo dice `ViewText.playerName`.
local STATUS_KEYS: { [string]: string } = { Ghost = "mark.ghost", Left = "mark.left" }

function Overview.create(playerGui: Instance): Handles
	local gui = Theme.screenGui(playerGui, "Overview", 8)

	-- Botón que despliega el cartel de datos. Está plegado al abrir la vista: lo primero es la maqueta.
	local toggle = Components.SecondaryButton(gui, "DataToggle", Strings.get("overview.showData"))
	-- En espejo (`Ui.hudMirror`) va abajo a la izquierda: arriba está el panel de acciones con su botón amarillo,
	-- que no se puede tapar.
	local bottomOffset = Ui.roadHeight + Ui.overviewBottom
	toggle.root.AnchorPoint = if Ui.hudMirror then Vector2.new(0, 1) else Vector2.new(1, 0)
	toggle.root.Position = if Ui.hudMirror
		then UDim2.new(0, Ui.panelRight, 1, -bottomOffset)
		else UDim2.new(1, -Ui.panelRight, 0, Ui.panelTop)
	toggle.root.Size = UDim2.fromOffset(Ui.panelWidth, 44)
	toggle.root.Visible = false

	local posterTop = Ui.panelTop + 44 + Theme.space.s
	local poster = Board.Poster(gui, "Sheet", 0, false)
	-- En espejo el cartel crece hacia arriba desde su botón, y ocupa como mucho la mitad de la pantalla.
	poster.root.AnchorPoint = if Ui.hudMirror then Vector2.new(0, 1) else Vector2.new(1, 0)
	poster.root.Position = if Ui.hudMirror
		then UDim2.new(0, Ui.panelRight, 1, -(bottomOffset + 44 + Theme.space.s))
		else UDim2.new(1, -Ui.panelRight, 0, posterTop)
	poster.root.Size = if Ui.hudMirror
		then UDim2.new(0, Ui.panelWidth, Ui.overviewPosterFraction, 0)
		else UDim2.new(0, Ui.panelWidth, 1, -(posterTop + Ui.roadHeight + Ui.overviewBottom))
	poster.root.Visible = false

	local title = Board.caption(poster.content, "Title", Strings.get("overview.title"), 1)
	title.FontFace = Theme.font.roadBold
	title.TextSize = 22
	title.TextColor3 = Theme.color.asphalt
	Board.text(poster.content, "Help", Strings.get("overview.help"), 2, 14).TextColor3 = Board.muted

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 0)
	scroll.CanvasSize = UDim2.fromScale(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = Theme.color.asphalt
	scroll.LayoutOrder = 3
	scroll.Parent = poster.content
	Board.fill(scroll)
	Board.list(scroll, Enum.FillDirection.Vertical, Theme.space.s)

	local open = false
	local expanded = false
	local listeners: { (boolean) -> () } = {}

	local function refresh()
		toggle.root.Visible = open
		poster.root.Visible = open and expanded
		toggle.setText(Strings.get(if expanded then "overview.hideData" else "overview.showData"))
	end

	toggle.onActivated(function()
		expanded = not expanded
		refresh()
	end)

	local function setOpen(value: boolean)
		open = value
		-- Cada vez que se abre la vista, los datos empiezan plegados.
		if value then
			expanded = false
		end
		refresh()
		for _, listener in listeners do
			listener(value)
		end
	end

	local handles: Handles = {
		setView = function(view: any, names: ViewText.Names?)
			if view == nil then
				return
			end
			for _, child in scroll:GetChildren() do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			local order = 0
			local function caption(key: string)
				order += 1
				Board.caption(scroll, `Caption{order}`, Strings.get(key), order)
			end
			local function line(text: string)
				order += 1
				Board.text(scroll, `Line{order}`, text, order, 15).Size = UDim2.new(1, -8, 0, 0)
			end

			caption("overview.owners")
			for _, seated in view.players do
				local name = ViewText.playerName(view, names, seated.id)
				local cash = HudRules.formatMoney(seated.cash)
				local statusKey = STATUS_KEYS[seated.status]
				if statusKey ~= nil then
					line(
						Strings.get(
							"overview.ownerLineStatus",
							{ name = name, status = Strings.get(statusKey), cash = cash }
						)
					)
				else
					line(Strings.get("overview.ownerLine", { name = name, cash = cash }))
				end
			end

			caption("overview.effects")
			local effects = 0
			for _, modifier in view.modifiers or {} do
				effects += 1
				line(ViewText.modifierText(view, names, modifier))
			end
			if view.hotZoneId ~= nil then
				effects += 1
				line(Strings.get("overview.hotZone", { zone = Strings.zone(view.hotZoneId).name }))
			end
			if effects == 0 then
				line(Strings.get("overview.none"))
			end

			caption("overview.positions")
			for _, seated in view.players do
				line(Strings.get("overview.position", {
					name = ViewText.playerName(view, names, seated.id),
					square = ViewText.squareName(view, seated.position),
				}))
			end
		end,
		isOpen = function(): boolean
			return open
		end,
		onToggle = function(listener: (boolean) -> ())
			table.insert(listeners, listener)
		end,
		setOpen = function(value: boolean)
			setOpen(value)
		end,
		close = function()
			setOpen(false)
		end,
		destroy = function()
			gui:Destroy()
		end,
	}

	return handles
end

return Overview

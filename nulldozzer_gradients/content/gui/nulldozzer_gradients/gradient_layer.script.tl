-- Gradient data layer: a button in the mod button area opens a window whose tool greys out the map,
-- draws every track piece colored by its steepest gradient, and shows the gradient of hovered track in a tooltip.

local app_util = ug_require "::/scripts/app_util.tl" as AppUtil
local react = ug_require "::/gui/main/react.lua" as React
local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local color_util = ug_require "::/gui/main/color_util.tl" as ColorUtil
local game_react_globals = ug_require "::/gui/main/game_react_globals.tl" as GameReactGlobals
local layer_react_util = ug_require "::/gui/layers/layer_react_util.tl" as LayerReactUtil
local main_mod_button_area = ug_require "::/gui/main/main_mod_button_area.tl" as MainModButtonArea
local tool_react_util = ug_require "::/gui/main/tool_react_util.tl" as ToolReactUtil
local view_manager_util = ug_require "::/gui/entity_window/view_manager_util.tl" as ViewManagerUtil

local LOG_PREFIX <const> = "[nulldozzer_gradients] "
local WINDOW_ID <const> = "nullDozzerGradientsWindow"
local ICON <const> = "::/gui/construction/build_control/symbol_slope_2_20.tga"

-- Distance in metres between the points where the gradient is measured along a track piece.
local SAMPLE_SPACING <const> = 10.0

local layerColors = api.gui.genericRep.get(api.gui.genericRep.find("::/gui/layers/layer_colors.gres")).data as LayerColors

local record Band
	-- Upper limit of the band, as a fraction (0.01 = 1%).
	maxGradient : number
	color : {number}
	label : string
end

local BANDS : {Band} = {
	{ maxGradient = 0.01, color = { 0.20, 0.75, 0.25, 1.0 }, label = "Green: under 1%" },
	{ maxGradient = 0.02, color = { 0.65, 0.85, 0.20, 1.0 }, label = "Light green: 1-2%" },
	{ maxGradient = 0.03, color = { 1.00, 0.85, 0.10, 1.0 }, label = "Yellow: 2-3%" },
	{ maxGradient = 0.04, color = { 1.00, 0.50, 0.10, 1.0 }, label = "Orange: 3-4%" },
	{ maxGradient = math.huge, color = { 0.90, 0.15, 0.15, 1.0 }, label = "Red: 4% and steeper" },
}

local function bandFor(gradient : number) : Band
	for _, band in ipairs(BANDS) do
		if gradient < band.maxGradient then
			return band
		end
	end
	return BANDS[#BANDS]
end

local function toVec4(color : {number}) : Vec4f
	return api.type.Vec4f.new(color[1], color[2], color[3], color[4])
end

local function maxGradientOf(geometry : EdgeGeometry) : number
	local steps = math.max(1, math.ceil(geometry.length / SAMPLE_SPACING))
	local maxGradient = 0.0
	local prev = api.engine.util.transport.calcPosition(geometry, 0.0)
	for i = 1, steps do
		local pos = api.engine.util.transport.calcPosition(geometry, i / steps)
		local dx = pos.x - prev.x
		local dy = pos.y - prev.y
		local horizontal = math.sqrt(dx * dx + dy * dy)
		if horizontal > 0.01 then
			maxGradient = math.max(maxGradient, math.abs(pos.z - prev.z) / horizontal)
		end
		prev = pos
	end
	return maxGradient
end

-- Everything collected for one opening of the layer. The engine objects (network, geometry, strip) are kept
-- referenced for as long as the layer is open: the game crashed (assert in transport::CalcPosition) when it
-- used a strip after we had dropped our references, presumably because the geometry had been freed.
local record LayerData
	-- Steepest gradient per track piece entity, as a fraction, regardless of direction.
	gradients : {Engine.Entity : number}
	pieceCount : integer
	networks : {Engine.Component.TransportNetwork}
	geometries : {EdgeGeometry}
	strips : {Builtin.Type.EdgeRenderable.Edge}
end

local function collectLayerData() : LayerData
	local data : LayerData = { gradients = {}, pieceCount = 0, networks = {}, geometries = {}, strips = {} }
	local entities = api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(0, 0), 1e10, api.type.ComponentType.BASE_EDGE)
	for _, entity in ipairs(entities) do
		local baseEdge = api.engine.getComponent(entity, api.type.ComponentType.BASE_EDGE) as Engine.Component.BaseEdge
		if baseEdge and baseEdge.roadType == api.type["enum"].RoadType.TRACK then
			local network = api.engine.getComponent(entity, api.type.ComponentType.TRANSPORT_NETWORK) as Engine.Component.TransportNetwork
			if network and network.edges and #network.edges > 0 then
				local geometry = network.edges[1].geometry
				local gradient = maxGradientOf(geometry)

				local color = toVec4(bandFor(gradient).color)
				local strip = builtin.type.EdgeRenderable.Edge.new(geometry)
				strip.colors = { color, color }
				strip.width = 3.0
				strip.offsetZ = 0.5
				strip.stepSize = 2.0

				data.gradients[entity] = gradient
				data.pieceCount = data.pieceCount + 1
				data.networks[#data.networks + 1] = network
				data.geometries[#data.geometries + 1] = geometry
				data.strips[#data.strips + 1] = strip
			end
		end
	end
	log.message(LOG_PREFIX .. "found " .. data.pieceCount .. " track pieces")
	return data
end

-- Greys out the map the same way the game's own data layers do.
local function makeLayerConfig() : LayerConfig
	local colorPassFn = api.type.LayerConfig.ColorPassFn.new()
	colorPassFn.fallbackColor = layer_react_util.createDefaultFallbackColor(layerColors.Infrastructure.Fallback.Surface, layerColors.Infrastructure.Fallback.Details)
	local layerConfig = api.type.LayerConfig.new()
	layerConfig.colorPassFn = colorPassFn
	return layerConfig
end

-- Hovering track reports a "parallel strip" entity, not the track piece itself. A strip covers ranges of one or
-- more track pieces (the game's own tooltip in game_tooltips.tl maps it the same way). Returns the steepest
-- gradient among the pieces the hovered entity covers, or nil.
local function gradientForHovered(entity : Engine.Entity, gradients : {Engine.Entity : number}) : number
	if gradients[entity] ~= nil then
		return gradients[entity]
	end
	local strip = api.engine.getComponent(entity, api.type.ComponentType.BASE_PARALLEL_STRIP) as Engine.Component.BaseParallelStrip
	if strip == nil then
		return nil
	end
	local maxGradient : number = nil
	for _, rangeGroup in ipairs(strip.rangeGroups) do
		for _, range in ipairs(rangeGroup) do
			local gradient = gradients[range.edge]
			if gradient ~= nil and (maxGradient == nil or gradient > maxGradient) then
				maxGradient = gradient
			end
		end
	end
	return maxGradient
end

local function isTrackPiece(entity : Engine.Entity) : boolean
	local baseEdge = api.engine.getComponent(entity, api.type.ComponentType.BASE_EDGE) as Engine.Component.BaseEdge
	return baseEdge ~= nil and baseEdge.roadType == api.type["enum"].RoadType.TRACK
end

-- Adapted from Urban Games' selector_react_util.makeDefaultSelector (base game, gui/main/selector_react_util.tl).
-- The default selector filters out every road and track piece (BaseEdge), so plain track can't be hovered.
-- This version lets track pieces through for hovering, but ignores clicks on them so clicking other things
-- still works as in the game's own data layers.
local function makeGradientSelector(hoveredRef : ReactRefT<Engine.Entity>) : TreeNodeId
	local refRC = game_react_globals.getDefaultRendererComponent()
	local selectionGres = api.gui.genericRep.get(api.gui.genericRep.find("::/gui/main/selection_colors.gres")).data as SelectionGuiConfig
	local transparency = api.gui.genericRep.get(api.gui.genericRep.find("::/gui/main/transparency.gres")).data as GResTransparency
	local colors = selectionGres.inverted

	return builtin.Selector{
		onHover = function(entity : Engine.Entity, _indices : {integer}, _apiDetails : Gui.SelectionDetails)
			hoveredRef:set(entity)
		end,
		onSelect = function(entity : Engine.Entity, _indices : {integer}, apiDetails : Gui.SelectionDetails) : boolean
			if entity >= 0 and isTrackPiece(entity) then
				return false
			end
			if entity >= 0 then
				react.fireEvent(refRC, "selectEntity", { entity = entity, stack = true })
				api.gui.fireGuiScriptEvent("mainView", "select", entity)
				if apiDetails and apiDetails.data and apiDetails.data.kind == api.gui.SelectionDetails.Type.World then
					local world = apiDetails.data as Gui.SelectionDetails.World
					api.gui.fireGuiScriptEvent("mainView", "select-world", {
						pos = { world.pos.x, world.pos.y, world.pos.z },
						water = world.water,
					})
				end
				return true
			elseif apiDetails ~= nil and apiDetails.data ~= nil and apiDetails.data.kind == api.gui.SelectionDetails.Type.Marker then
				local marker = apiDetails.data as Gui.SelectionDetails.Marker
				react.fireEvent(refRC, "selectMarker", marker.marker)
				api.gui.fireGuiScriptEvent("mainView", "selectMarker", marker.marker)
				if marker.entity and marker.fireSelectEntity then
					react.fireEvent(refRC, "selectEntity", { entity = marker.entity, stack = true })
				end
			end
			return false
		end,
		onSelectNothing = function() : boolean
			react.fireEvent(refRC, "selectNothing", { stack = true })
			return false
		end,
		stopOnMenuBack = false,
		filter = function(entity : Engine.Entity) : boolean
			if entity == nil then
				return false
			end
			local baseNode = api.engine.getComponent(entity, api.type.ComponentType.BASE_NODE) as Engine.Component.BaseNode
			if baseNode then
				if not view_manager_util.baseNodeCanToggleDoubleSlipSwitch(entity)
					and not view_manager_util.baseNodeCanConfigTrafficLight(entity) then
					return false
				end
			end
			if api.engine.getComponent(entity, api.type.ComponentType.BASE_EDGE) ~= nil then
				return isTrackPiece(entity)
			end
			return true
		end,
		selectionColor = color_util.toVec4(colors.selectionColor),
		selectionOutlineColor = color_util.withTransparency(colors.selectionOutlineColor, transparency.Low),
		selectionOutlineColor1 = color_util.toVec4(colors.selectionOutlineColor),
		circleBorderColor = color_util.withTransparency(colors.selectionCircleColor, transparency.Low),
		crosshairColor = color_util.toVec4(colors.crosshairColor),
	}
end

local record TooltipParam
	hoveredRef : ReactRefT<Engine.Entity>
	gradients : {Engine.Entity : number}
end

-- Tooltip next to the mouse with the gradient of the hovered track, styled like the game's own tooltips.
local GradientTooltip = react.RegisterRecipe("NullDozzerGradientsTooltip", function(param : TooltipParam) : TreeNodeId
	react.setMouseTransparent(true)

	local gradientState : ReactStateT<number> = react.useState(nil)
	react.onStep(function()
		local entity = param.hoveredRef:get()
		local gradient : number = nil
		if entity ~= nil and entity >= 0 then
			gradient = gradientForHovered(entity, param.gradients)
		end
		gradientState:transform(function() : number
			return gradient
		end)
	end)

	local gradient = gradientState:old()
	if gradient == nil then
		return builtin.BoxLayout{}
	end
	return builtin.BoxLayout{
		children = {
			builtin.TextView{
				meta = {
					class = "default-tooltip-configuration, font-scale-tooltip",
					mouseTransparent = true,
				},
				text = "Gradient: " .. api.util.toStringPercentPrecision(gradient, 1),
			},
		},
	}
end)

local GradientLayerContent = react.RegisterRecipe("NullDozzerGradientsContent", function(payload : ToolReactUtil.ToolWindowParamPayload<ToolReactUtil.IToolParam>) : TreeNodeId
	local dataRef : ReactRefT<LayerData> = react.useRef()
	if dataRef:get() == nil then
		dataRef:set(collectLayerData())
	end
	local data = dataRef:get()

	local hoveredRef : ReactRefT<Engine.Entity> = react.useRef(-1)

	payload.setActionFn(function() : TreeNodeId
		return builtin.ActionDescriptor{
			tool = "nulldozzer_gradients",
			-- Same as the game's data layers: no selection circle or crosshair when using the mouse.
			terrainCirclePolicy = app_util.getMouseOrGamepad("Never", "FocusSelection"),
			crosshair = app_util.getMouseOrGamepad(false, true),
			children = {
				builtin.LayerConfig{ config = makeLayerConfig() },
				builtin.EdgeRenderable{ edges = data.strips, ignoreDepth = true },
				makeGradientSelector(hoveredRef),
				builtin.ActionTooltip{
					recipe = GradientTooltip,
					param = { hoveredRef = hoveredRef, gradients = data.gradients },
				},
			},
		}
	end)

	local lines : {TreeNodeId} = {
		builtin.TextView{ text = "Track pieces: " .. data.pieceCount },
	}
	for _, band in ipairs(BANDS) do
		lines[#lines + 1] = builtin.TextView{ text = band.label }
	end

	return builtin.BoxLayout{
		children = {
			layer_react_util.LayerLegendWrapper{
				content = builtin.BoxLayout{
					orientation = builtin.type.Orientation.Vertical,
					children = lines,
				},
			},
		},
	}
end)

local GradientLayerWindow = react.RegisterWrapperRecipe("NullDozzerGradientsWindow", builtin.Window, function(params : ToolReactUtil.IToolWindowParam<ToolReactUtil.IToolParam>) : TreeNodeId
	return builtin.Window{
		title = "Gradient Data Layer",
		closable = true,
		onClose = params.onClose,
		content = GradientLayerContent(params.payload),
		id = WINDOW_ID,
	}
end)

local GradientLayerTool = tool_react_util.registerToolWithWindow("NullDozzerGradients", WINDOW_ID, GradientLayerWindow)

local function makeGameCtx() : GameContext
	return {
		windowContainer = game_react_globals.getDefaultWindowContainer(),
		toolStack = game_react_globals.getDefaultToolStack(),
	} as GameContext
end

local GradientLayerButton = react.RegisterPluginRecipe(main_mod_button_area.MainModButtonAreaExtension, "NullDozzerGradientsButton", function() : TreeNodeId
	-- Plugin recipes must return a layout, so the button is wrapped in a BoxLayout.
	return builtin.BoxLayout{
		children = {
			builtin.ToolButton{
				meta = {
					id = "nulldozzer_gradients.button",
					tooltip = "Gradient Data Layer",
				},
				toolDefinition = GradientLayerTool,
				toolStack = game_react_globals.getDefaultToolStack(),
				content = builtin.ImageView{
					path = ICON,
					scaling = builtin.type.ImageViewScaling.AutoFit,
				},
				showFn = function()
					game_react_globals.getDefaultToolStackApi().push(GradientLayerTool, nil, { gameCtx = makeGameCtx() })
				end,
				hideFn = function()
					game_react_globals.getDefaultToolStackApi().pop(GradientLayerTool, nil)
				end,
			},
		},
	}
end)

return {
	GradientLayerButton = GradientLayerButton,
}

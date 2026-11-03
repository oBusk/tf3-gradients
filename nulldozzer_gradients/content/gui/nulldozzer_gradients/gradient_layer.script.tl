local app_util = ug_require "::/scripts/app_util.tl" as AppUtil
local react = ug_require "::/gui/main/react.lua" as React
local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local game_react_globals = ug_require "::/gui/main/game_react_globals.tl" as GameReactGlobals
local layer_react_util = ug_require "::/gui/layers/layer_react_util.tl" as LayerReactUtil
local main_mod_button_area = ug_require "::/gui/main/main_mod_button_area.tl" as MainModButtonArea
local selector_react_util = ug_require "::/gui/main/selector_react_util.tl" as SelectorReactUtil
local tool_react_util = ug_require "::/gui/main/tool_react_util.tl" as ToolReactUtil

local gradient_scale = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/gradient_scale.tl" as NullDozzerGradientScale
local gradient_tooltip = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/gradient_tooltip.tl" as NullDozzerGradientTooltip
local network_scan = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/network_scan.tl" as NullDozzerNetworkScan
local point_grid = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/point_grid.tl" as NullDozzerPointGrid

local type Piece = NullDozzerNetworkScan.Piece
local type Strip = Builtin.Type.EdgeRenderable.Edge

local TOOL_NAME <const> = "NullDozzerGradients"
local ACTION_TOOL <const> = "nulldozzer_gradients"
local WINDOW_ID <const> = "nullDozzerGradientsWindow"
local BUTTON_ID <const> = "nulldozzer_gradients.button"
local BUTTON_ICON <const> = "::/gui/construction/build_control/symbol_slope_2_20.tga"

local STRIP_OPACITY <const> = 0.6
local STRIP_OFFSET_Z <const> = 0.3
local STRIP_STEP <const> = 2.0
local STRIP_WIDTH : {NullDozzerNetworkScan.Kind : number} = {
	track = 1.8,
	road = 2.5,
}

local GRID_CELL_SIZE <const> = 20.0
local LEGEND_LEVELS_PER_STEP <const> = 4

local layerColors = api.gui.genericRep.get(api.gui.genericRep.find("::/gui/layers/layer_colors.gres")).data as LayerColors

local record LayerState
	piecesByEntity : {Engine.Entity : Piece}
	grid : NullDozzerPointGrid.Grid
	strips : {Strip}
end

local function makeStrip(lane : EdgeGeometry, piece : Piece) : Strip
	local color = gradient_scale.colorFor(gradient_scale.forKind(piece.kind), piece.profile.maxGradient, STRIP_OPACITY)
	local strip = builtin.type.EdgeRenderable.Edge.new(lane)
	strip.colors = { color, color }
	strip.width = STRIP_WIDTH[piece.kind]
	strip.offsetZ = STRIP_OFFSET_Z
	strip.stepSize = STRIP_STEP
	return strip
end

local function addToGrid(grid : NullDozzerPointGrid.Grid, piece : Piece)
	for _, sample in ipairs(piece.profile.samples) do
		point_grid.add(grid, { x = sample.x, y = sample.y, gradient = sample.gradient, piece = piece.entity })
	end
end

local function buildLayerState() : LayerState
	local state : LayerState = { piecesByEntity = {}, grid = point_grid.new(GRID_CELL_SIZE), strips = {} }
	for _, piece in ipairs(network_scan.scanAll()) do
		state.piecesByEntity[piece.entity] = piece
		addToGrid(state.grid, piece)
		for _, lane in ipairs(piece.lanes) do
			state.strips[#state.strips + 1] = makeStrip(lane, piece)
		end
	end
	return state
end

local function makeGreyMapConfig() : LayerConfig
	local colorPassFn = api.type.LayerConfig.ColorPassFn.new()
	colorPassFn.fallbackColor = layer_react_util.createDefaultFallbackColor(layerColors.Infrastructure.Fallback.Surface, layerColors.Infrastructure.Fallback.Details)
	local layerConfig = api.type.LayerConfig.new()
	layerConfig.colorPassFn = colorPassFn
	return layerConfig
end

local function ColorBar(scale : NullDozzerGradientScale.Scale) : TreeNodeId
	local colors : {Vec4f} = {}
	for _, gradient in ipairs(scale.legendGradients) do
		colors[#colors + 1] = gradient_scale.colorFor(scale, gradient, 1.0)
	end
	return builtin.GradientLegend{
		colors = layer_react_util.makeGradientColorsOfN({ colors = colors, numberOfLevels = LEGEND_LEVELS_PER_STEP * (#colors - 1) }),
		horizontal = true,
		discrete = true,
		internalLabels = false,
	}
end

local LegendLabels = react.RegisterRecipe("NullDozzerGradientLegendLabels", function(scale : NullDozzerGradientScale.Scale) : TreeNodeId
	local children : {TreeNodeId} = {}
	for i, gradient in ipairs(scale.legendGradients) do
		if i > 1 then
			children[#children + 1] = builtin.Component{ meta = { class = "nulldozzer-legend-spacer" } }
		end
		children[#children + 1] = builtin.TextView{ meta = { class = "font-scale-annotation" }, text = api.util.toStringPercentPrecision(gradient, 1) }
	end
	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Horizontal,
		children = children,
	}
end)

local function Legend(kind : NullDozzerNetworkScan.Kind) : TreeNodeId
	local scale = gradient_scale.forKind(kind)
	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Vertical,
		children = { ColorBar(scale), LegendLabels(scale) },
	}
end

local function Subtitle(text : string) : TreeNodeId
	return builtin.TextView{ meta = { class = "font-scale-title-4, layer-subtitle" }, text = text }
end

local function LayerAction(state : LayerState, hoveredRef : ReactRefT<Engine.Entity>) : TreeNodeId
	return builtin.ActionDescriptor{
		tool = ACTION_TOOL,
		terrainCirclePolicy = app_util.getMouseOrGamepad("Never", "FocusSelection"),
		crosshair = app_util.getMouseOrGamepad(false, true),
		children = {
			builtin.LayerConfig{ config = makeGreyMapConfig() },
			builtin.EdgeRenderable{ edges = state.strips, ignoreDepth = true },
			selector_react_util.makeDefaultSelector(game_react_globals.getDefaultRendererComponent(), hoveredRef, true, nil, true),
			builtin.ActionTooltip{
				recipe = gradient_tooltip.Tooltip,
				param = { hoveredRef = hoveredRef, grid = state.grid, pieces = state.piecesByEntity },
			},
		},
	}
end

local LayerContent = react.RegisterRecipe("NullDozzerGradientsContent", function(payload : ToolReactUtil.ToolWindowParamPayload<ToolReactUtil.IToolParam>) : TreeNodeId
	local stateRef : ReactRefT<LayerState> = react.useRef()
	if stateRef:get() == nil then
		stateRef:set(buildLayerState())
	end
	local hoveredRef : ReactRefT<Engine.Entity> = react.useRef(-1)

	payload.setActionFn(function() : TreeNodeId
		return LayerAction(stateRef:get(), hoveredRef)
	end)

	return builtin.BoxLayout{
		children = {
			layer_react_util.LayerLegendWrapper{
				content = builtin.BoxLayout{
					orientation = builtin.type.Orientation.Vertical,
					children = {
						Subtitle("Track gradient"),
						Legend("track"),
						Subtitle("Road gradient"),
						Legend("road"),
						builtin.TextView{ text = "Hold Shift over a bridge or tunnel to list its segments." },
					},
				},
			},
		},
	}
end)

local LayerWindow = react.RegisterWrapperRecipe("NullDozzerGradientsWindow", builtin.Window, function(params : ToolReactUtil.IToolWindowParam<ToolReactUtil.IToolParam>) : TreeNodeId
	return builtin.Window{
		title = "Gradient Data Layer",
		closable = true,
		onClose = params.onClose,
		content = LayerContent(params.payload),
		id = WINDOW_ID,
	}
end)

local LayerTool = tool_react_util.registerToolWithWindow(TOOL_NAME, WINDOW_ID, LayerWindow)

local function defaultGameContext() : GameContext
	return {
		windowContainer = game_react_globals.getDefaultWindowContainer(),
		toolStack = game_react_globals.getDefaultToolStack(),
	} as GameContext
end

local LayerButton = react.RegisterPluginRecipe(main_mod_button_area.MainModButtonAreaExtension, "NullDozzerGradientsButton", function() : TreeNodeId
	return builtin.BoxLayout{
		children = {
			builtin.ToolButton{
				meta = { id = BUTTON_ID, tooltip = "Gradient Data Layer" },
				toolDefinition = LayerTool,
				toolStack = game_react_globals.getDefaultToolStack(),
				content = builtin.ImageView{ path = BUTTON_ICON, scaling = builtin.type.ImageViewScaling.AutoFit },
				showFn = function()
					game_react_globals.getDefaultToolStackApi().push(LayerTool, nil, { gameCtx = defaultGameContext() })
				end,
				hideFn = function()
					game_react_globals.getDefaultToolStackApi().pop(LayerTool, nil)
				end,
			},
		},
	}
end)

return {
	GradientLayerButton = LayerButton,
}

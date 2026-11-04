local app_util = ug_require "::/scripts/app_util.tl" as AppUtil
local react = ug_require "::/gui/main/react.lua" as React
local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local engine_react_util = ug_require "::/gui/main/engine_react_util.tl" as EngineReactUtil
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
	-- One colour per piece from its average gradient.
	segmentStrips : {Strip}
	-- One colour per 4 m stretch, shown while the detail modifier is held.
	detailStrips : {Strip}
end

-- One colour per 4 m sample, in order along the piece. Unverified: assumes the
-- engine spreads the colour list evenly along the strip (the base game only
-- ever passes two). A single sample is doubled so the list has a start and end.
local function distanceSquared(position : Vec3f, sample : NullDozzerEdgeProfile.Sample) : number
	local dx = position.x - sample.x
	local dy = position.y - sample.y
	return dx * dx + dy * dy
end

-- Samples are measured along the piece's first lane; a road lane running the other
-- way starts at the last sample, so its colours must be reversed.
local function runsBackwards(lane : EdgeGeometry, samples : {NullDozzerEdgeProfile.Sample}) : boolean
	local start = api.engine.util.transport.calcPosition(lane, 0.0)
	return distanceSquared(start, samples[#samples]) < distanceSquared(start, samples[1])
end

local function detailColors(lane : EdgeGeometry, piece : Piece) : {Vec4f}
	local scale = gradient_scale.forKind(piece.kind)
	local samples = piece.profile.samples
	local backwards = runsBackwards(lane, samples)
	local colors : {Vec4f} = {}
	for i = 1, #samples do
		local sample = backwards and samples[#samples + 1 - i] or samples[i]
		colors[i] = gradient_scale.colorFor(scale, sample.gradient, STRIP_OPACITY)
	end
	if #colors == 1 then
		colors[2] = colors[1]
	end
	return colors
end

local function segmentColors(piece : Piece) : {Vec4f}
	local color = gradient_scale.colorFor(gradient_scale.forKind(piece.kind), piece.profile.averageGradient, STRIP_OPACITY)
	return { color, color }
end

local function makeStrip(lane : EdgeGeometry, piece : Piece, colors : {Vec4f}) : Strip
	local strip = builtin.type.EdgeRenderable.Edge.new(lane)
	strip.colors = colors
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
	local state : LayerState = { piecesByEntity = {}, grid = point_grid.new(GRID_CELL_SIZE), segmentStrips = {}, detailStrips = {} }
	for _, piece in ipairs(network_scan.scanAll()) do
		state.piecesByEntity[piece.entity] = piece
		addToGrid(state.grid, piece)
		for _, lane in ipairs(piece.lanes) do
			state.segmentStrips[#state.segmentStrips + 1] = makeStrip(lane, piece, segmentColors(piece))
			state.detailStrips[#state.detailStrips + 1] = makeStrip(lane, piece, detailColors(lane, piece))
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

local function LayerAction(state : LayerState, hoveredRef : ReactRefT<Engine.Entity>, detail : boolean) : TreeNodeId
	return builtin.ActionDescriptor{
		tool = ACTION_TOOL,
		terrainCirclePolicy = app_util.getMouseOrGamepad("Never", "FocusSelection"),
		crosshair = app_util.getMouseOrGamepad(false, true),
		children = {
			builtin.LayerConfig{ config = makeGreyMapConfig() },
			-- Only one EdgeRenderable is allowed per ActionDescriptor, so swap the list.
			builtin.EdgeRenderable{ edges = detail and state.detailStrips or state.segmentStrips, ignoreDepth = true },
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
	local detailState = engine_react_util.useStepState(gradient_tooltip.isDetailHeld)
	local detail = detailState:old() == true

	payload.setActionFn(function() : TreeNodeId
		return LayerAction(stateRef:get(), hoveredRef, detail)
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
						builtin.TextView{ text = "Colours show each segment's average.\nHold Shift to see the gradient every 4 m." },
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

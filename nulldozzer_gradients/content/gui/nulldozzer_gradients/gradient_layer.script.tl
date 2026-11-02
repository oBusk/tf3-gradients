-- Prototype of the gradient data layer: a button in the mod button area opens a window
-- whose tool greys out the map and draws every track piece colored by its steepest gradient.

local react = ug_require "::/gui/main/react.lua" as React
local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local game_react_globals = ug_require "::/gui/main/game_react_globals.tl" as GameReactGlobals
local layer_react_util = ug_require "::/gui/layers/layer_react_util.tl" as LayerReactUtil
local main_mod_button_area = ug_require "::/gui/main/main_mod_button_area.tl" as MainModButtonArea
local tool_react_util = ug_require "::/gui/main/tool_react_util.tl" as ToolReactUtil

local LOG_PREFIX <const> = "[nulldozzer_gradients] "
local WINDOW_ID <const> = "nulldozzer_gradients.window"
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

local record TrackPiece
	geometry : EdgeGeometry
	-- Steepest gradient anywhere on the piece, as a fraction, regardless of direction.
	maxGradient : number
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

local function collectTrackPieces() : {TrackPiece}
	local pieces : {TrackPiece} = {}
	local entities = api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(0, 0), 1e10, api.type.ComponentType.BASE_EDGE)
	for _, entity in ipairs(entities) do
		local baseEdge = api.engine.getComponent(entity, api.type.ComponentType.BASE_EDGE) as Engine.Component.BaseEdge
		if baseEdge and baseEdge.roadType == api.type["enum"].RoadType.TRACK then
			local network = api.engine.getComponent(entity, api.type.ComponentType.TRANSPORT_NETWORK) as Engine.Component.TransportNetwork
			if network and network.edges and #network.edges > 0 then
				local geometry = network.edges[1].geometry
				local piece : TrackPiece = { geometry = geometry, maxGradient = maxGradientOf(geometry) }
				pieces[#pieces + 1] = piece
				log.message(LOG_PREFIX .. "piece " .. tostring(entity) .. ": max " .. math.floor(piece.maxGradient * 1000 + 0.5) / 10 .. " pct over " .. math.floor(geometry.length) .. " m")
			end
		end
	end
	log.message(LOG_PREFIX .. "found " .. #pieces .. " track pieces")
	return pieces
end

local function makeRenderableEdges(pieces : {TrackPiece}) : {Builtin.Type.EdgeRenderable.Edge}
	local result : {Builtin.Type.EdgeRenderable.Edge} = {}
	for _, piece in ipairs(pieces) do
		local color = toVec4(bandFor(piece.maxGradient).color)
		local edge = builtin.type.EdgeRenderable.Edge.new(piece.geometry)
		edge.colors = { color, color }
		edge.width = 3.0
		edge.offsetZ = 0.5
		edge.stepSize = 2.0
		result[#result + 1] = edge
	end
	return result
end

-- Greys out the map the same way the game's own data layers do.
local function makeLayerConfig() : LayerConfig
	local colorPassFn = api.type.LayerConfig.ColorPassFn.new()
	colorPassFn.fallbackColor = layer_react_util.createDefaultFallbackColor(layerColors.Infrastructure.Fallback.Surface, layerColors.Infrastructure.Fallback.Details)
	local layerConfig = api.type.LayerConfig.new()
	layerConfig.colorPassFn = colorPassFn
	return layerConfig
end

local GradientLayerContent = react.RegisterRecipe("NullDozzerGradientsContent", function(payload : ToolReactUtil.ToolWindowParamPayload<ToolReactUtil.IToolParam>) : TreeNodeId
	local piecesRef : ReactRefT<{TrackPiece}> = react.useRef()
	if piecesRef:get() == nil then
		piecesRef:set(collectTrackPieces())
	end
	local pieces = piecesRef:get()

	payload.setActionFn(function() : TreeNodeId
		return builtin.ActionDescriptor{
			tool = "nulldozzer_gradients",
			children = {
				builtin.LayerConfig{ config = makeLayerConfig() },
				builtin.EdgeRenderable{ edges = makeRenderableEdges(pieces), ignoreDepth = true },
			},
		}
	end)

	local lines : {TreeNodeId} = {
		builtin.TextView{ text = "Track pieces: " .. #pieces },
	}
	for _, band in ipairs(BANDS) do
		lines[#lines + 1] = builtin.TextView{ text = band.label }
	end

	return builtin.BoxLayout{
		orientation = builtin.type.Orientation.Vertical,
		children = lines,
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

log.message(LOG_PREFIX .. "data layer script loaded")

return {
	GradientLayerButton = GradientLayerButton,
}

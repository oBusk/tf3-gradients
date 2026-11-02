local react = ug_require "::/gui/main/react.lua" as React
local builtin = ug_require "::/gui/main/builtin.lua" as Builtin
local point_grid = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/point_grid.tl" as NullDozzerPointGrid

local gradient_tooltip : NullDozzerGradientTooltip = {}

local type Piece = NullDozzerNetworkScan.Piece

local MAX_DISTANCE_TO_NETWORK <const> = 6.0
local LIST_SEGMENTS_ACTION <const> = "IA_PRECISION_MODE"

local STRUCTURE_NAMES : {NullDozzerNetworkScan.Structure : string} = {
	bridge = "Bridge",
	tunnel = "Tunnel",
	ground = "Structure",
}

local function percent(gradient : number) : string
	return api.util.toStringPercentPrecision(gradient, 1)
end

local function isListSegmentsHeld() : boolean
	local ok, held = pcall(api.gui.inputAction.modifierOnlyActionIsActive, LIST_SEGMENTS_ACTION)
	return ok and held == true
end

local function piecesOfStructure(structureEntity : Engine.Entity, pieces : {Engine.Entity : Piece}) : {Piece}
	local strip = api.engine.getComponent(structureEntity, api.type.ComponentType.BASE_PARALLEL_STRIP) as Engine.Component.BaseParallelStrip
	if strip == nil then
		return nil
	end
	local result : {Piece} = {}
	local seen : {Engine.Entity : boolean} = {}
	for _, rangeGroup in ipairs(strip.rangeGroups) do
		for _, range in ipairs(rangeGroup) do
			local piece = pieces[range.edge]
			if piece and not seen[piece.entity] then
				seen[piece.entity] = true
				result[#result + 1] = piece
			end
		end
	end
	if #result == 0 then
		return nil
	end
	return result
end

local function describeStructure(structurePieces : {Piece}, listSegments : boolean) : string
	local steepest = 0.0
	for _, piece in ipairs(structurePieces) do
		steepest = math.max(steepest, piece.profile.maxGradient)
	end
	local lines = { STRUCTURE_NAMES[structurePieces[1].structure] .. " max: " .. percent(steepest) }
	if listSegments then
		for i, piece in ipairs(structurePieces) do
			lines[#lines + 1] = "Segment " .. i .. ": " .. percent(piece.profile.maxGradient)
		end
	end
	return table.concat(lines, "\n")
end

local function describePoint(point : NullDozzerPointGrid.Point, pieces : {Engine.Entity : Piece}) : string
	return "Gradient: " .. percent(point.gradient) .. "\nSegment max: " .. percent(pieces[point.piece].profile.maxGradient)
end

local function describeHoveredStructure(param : NullDozzerGradientTooltip.Param) : string
	local hovered = param.hoveredRef:get()
	if hovered == nil or hovered < 0 then
		return nil
	end
	local structurePieces = piecesOfStructure(hovered, param.pieces)
	return structurePieces and describeStructure(structurePieces, isListSegmentsHeld())
end

local function describePointUnderMouse(param : NullDozzerGradientTooltip.Param) : string
	if not api.gui.mouse.hasTerrainPosition() then
		return nil
	end
	local ground = api.gui.mouse.getTerrainPosition()
	local point = point_grid.nearest(param.grid, ground.x, ground.y, MAX_DISTANCE_TO_NETWORK)
	return point and describePoint(point, param.pieces)
end

local function tooltipText(param : NullDozzerGradientTooltip.Param) : string
	return describeHoveredStructure(param) or describePointUnderMouse(param)
end

local function TooltipBox(text : string) : TreeNodeId
	return builtin.BoxLayout{
		children = {
			builtin.TextView{
				meta = {
					class = "default-tooltip-configuration, font-scale-tooltip",
					mouseTransparent = true,
				},
				text = text,
			},
		},
	}
end

gradient_tooltip.Tooltip = react.RegisterRecipe("NullDozzerGradientsTooltip", function(param : NullDozzerGradientTooltip.Param) : TreeNodeId
	react.setMouseTransparent(true)

	local textState : ReactStateT<string> = react.useState(nil)
	react.onStep(function()
		local text = tooltipText(param)
		textState:transform(function() : string
			return text
		end)
	end)

	local text = textState:old()
	if text == nil then
		return builtin.BoxLayout{}
	end
	return TooltipBox(text)
end)

return gradient_tooltip

local edge_profile = ug_require "nulldozzer_gradients::/gui/nulldozzer_gradients/edge_profile.tl" as NullDozzerEdgeProfile

local network_scan : NullDozzerNetworkScan = {}

local WHOLE_MAP_CENTER <const> = { 0.0, 0.0 }
local WHOLE_MAP_RADIUS <const> = 1e10

local ROAD_LANE_MODES : {TransportMode} = {
	api.type["enum"].TransportMode.CAR,
	api.type["enum"].TransportMode.BUS,
	api.type["enum"].TransportMode.TRUCK,
	api.type["enum"].TransportMode.TRAM,
	api.type["enum"].TransportMode.ELECTRIC_TRAM,
}

local function allBaseEdges() : {Engine.Entity}
	local center = api.type.Vec2f.new(WHOLE_MAP_CENTER[1], WHOLE_MAP_CENTER[2])
	return api.engine.util.octree.findEntitiesInCircle(center, WHOLE_MAP_RADIUS, api.type.ComponentType.BASE_EDGE)
end

local function kindOf(baseEdge : Engine.Component.BaseEdge) : NullDozzerNetworkScan.Kind
	if baseEdge.roadType == api.type["enum"].RoadType.TRACK then
		return "track"
	end
	if baseEdge.roadType == api.type["enum"].RoadType.STREET then
		return "road"
	end
	return nil
end

local function structureOf(baseEdge : Engine.Component.BaseEdge) : NullDozzerNetworkScan.Structure
	if baseEdge.type == api.type["enum"].BaseEdgeType.BRIDGE then
		return "bridge"
	end
	if baseEdge.type == api.type["enum"].BaseEdgeType.TUNNEL then
		return "tunnel"
	end
	return "ground"
end

local function carriesRoadTraffic(edge : Edge) : boolean
	for _, mode in ipairs(ROAD_LANE_MODES) do
		if edge.transportModes[mode] then
			return true
		end
	end
	return false
end

local function lanesOf(network : Engine.Component.TransportNetwork, kind : NullDozzerNetworkScan.Kind) : {EdgeGeometry}
	if kind == "track" then
		return { network.edges[1].geometry }
	end
	local lanes : {EdgeGeometry} = {}
	for _, edge in ipairs(network.edges) do
		if carriesRoadTraffic(edge) then
			lanes[#lanes + 1] = edge.geometry
		end
	end
	if #lanes == 0 then
		lanes[1] = network.edges[1].geometry
	end
	return lanes
end

local function scanPiece(entity : Engine.Entity) : NullDozzerNetworkScan.Piece
	local baseEdge = api.engine.getComponent(entity, api.type.ComponentType.BASE_EDGE) as Engine.Component.BaseEdge
	local kind = baseEdge and kindOf(baseEdge)
	if kind == nil then
		return nil
	end
	local network = api.engine.getComponent(entity, api.type.ComponentType.TRANSPORT_NETWORK) as Engine.Component.TransportNetwork
	if network == nil or network.edges == nil or #network.edges == 0 then
		return nil
	end
	local lanes = lanesOf(network, kind)
	return {
		entity = entity,
		kind = kind,
		structure = structureOf(baseEdge),
		profile = edge_profile.measure(lanes[1]),
		network = network,
		lanes = lanes,
	}
end

function network_scan.scanAll() : {NullDozzerNetworkScan.Piece}
	local pieces : {NullDozzerNetworkScan.Piece} = {}
	for _, entity in ipairs(allBaseEdges()) do
		local piece = scanPiece(entity)
		if piece then
			pieces[#pieces + 1] = piece
		end
	end
	return pieces
end

return network_scan

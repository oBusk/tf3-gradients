global record NullDozzerNetworkScan
	enum Kind
		"track"
		"road"
	end

	enum Structure
		"ground"
		"bridge"
		"tunnel"
	end

	record Piece
		entity : Engine.Entity
		kind : Kind
		structure : Structure
		profile : NullDozzerEdgeProfile.Profile
		-- The engine frees geometry that nothing references, so the network stays referenced with its lanes.
		network : Engine.Component.TransportNetwork
		lanes : {EdgeGeometry}
	end

	scanAll : function() : {Piece}
end

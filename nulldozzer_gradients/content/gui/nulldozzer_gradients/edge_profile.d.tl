global record NullDozzerEdgeProfile
	record Sample
		x : number
		y : number
		gradient : number
	end

	record Profile
		maxGradient : number
		samples : {Sample}
	end

	measure : function(geometry : EdgeGeometry) : Profile
end

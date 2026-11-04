global record NullDozzerEdgeProfile
	record Sample
		x : number
		y : number
		gradient : number
	end

	record Profile
		--- Height change between the ends over the horizontal length along the piece.
		averageGradient : number
		--- Steepest 4 m stretch.
		maxGradient : number
		--- Length along the piece, ignoring height.
		horizontalLength : number
		samples : {Sample}
	end

	measure : function(geometry : EdgeGeometry) : Profile
end

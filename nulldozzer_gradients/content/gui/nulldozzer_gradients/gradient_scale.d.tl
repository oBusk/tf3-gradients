global record NullDozzerGradientScale
	record Stop
		gradient : number
		color : {number}
	end

	record Scale
		--- Steepest gradient the player may build for this kind; drawn black.
		maxGradient : number
		stops : {Stop}
		legendGradients : {number}
	end

	forKind : function(kind : NullDozzerNetworkScan.Kind) : Scale
	colorFor : function(scale : Scale, gradient : number, opacity : number) : Vec4f
end

global record NullDozzerGradientScale
	record Stop
		gradient : number
		color : {number}
	end

	record Scale
		stops : {Stop}
		legendGradients : {number}
	end

	forKind : function(kind : NullDozzerNetworkScan.Kind) : Scale
	colorFor : function(scale : Scale, gradient : number, opacity : number) : Vec4f
end

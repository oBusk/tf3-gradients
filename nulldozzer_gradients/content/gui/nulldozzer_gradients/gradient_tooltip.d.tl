global record NullDozzerGradientTooltip
	record Param
		hoveredRef : ReactRefT<Engine.Entity>
		grid : NullDozzerPointGrid.Grid
		pieces : {Engine.Entity : NullDozzerNetworkScan.Piece}
	end

	Tooltip : Recipe<Param>
end

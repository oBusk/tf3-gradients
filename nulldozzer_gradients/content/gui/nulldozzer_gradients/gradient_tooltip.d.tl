global record NullDozzerGradientTooltip
	record Param
		hoveredRef : ReactRefT<Engine.Entity>
		grid : NullDozzerPointGrid.Grid
		pieces : {Engine.Entity : NullDozzerNetworkScan.Piece}
	end

	Tooltip : Recipe<Param>
	--- True while the detail modifier (Shift by default) is held.
	isDetailHeld : function() : boolean
end

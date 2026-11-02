global record NullDozzerPointGrid
	record Point
		x : number
		y : number
		gradient : number
		piece : Engine.Entity
	end

	record Grid
		cellSize : number
		cells : {string : {Point}}
	end

	new : function(cellSize : number) : Grid
	add : function(grid : Grid, point : Point)
	nearest : function(grid : Grid, x : number, y : number, maxDistance : number) : Point
end

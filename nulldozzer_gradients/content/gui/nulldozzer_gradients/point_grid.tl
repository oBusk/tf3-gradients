local point_grid : NullDozzerPointGrid = {}

local function cellIndex(grid : NullDozzerPointGrid.Grid, coordinate : number) : integer
	return math.floor(coordinate / grid.cellSize)
end

local function cellKey(cx : integer, cy : integer) : string
	return tostring(cx) .. ":" .. tostring(cy)
end

function point_grid.new(cellSize : number) : NullDozzerPointGrid.Grid
	return { cellSize = cellSize, cells = {} }
end

function point_grid.add(grid : NullDozzerPointGrid.Grid, point : NullDozzerPointGrid.Point)
	local key = cellKey(cellIndex(grid, point.x), cellIndex(grid, point.y))
	local cell = grid.cells[key]
	if cell == nil then
		cell = {}
		grid.cells[key] = cell
	end
	cell[#cell + 1] = point
end

function point_grid.nearest(grid : NullDozzerPointGrid.Grid, x : number, y : number, maxDistance : number) : NullDozzerPointGrid.Point
	local reach = math.ceil(maxDistance / grid.cellSize)
	local cx = cellIndex(grid, x)
	local cy = cellIndex(grid, y)
	local best : NullDozzerPointGrid.Point = nil
	local bestDistanceSquared = maxDistance * maxDistance
	for ix = cx - reach, cx + reach do
		for iy = cy - reach, cy + reach do
			for _, point in ipairs(grid.cells[cellKey(ix, iy)] or {}) do
				local dx = point.x - x
				local dy = point.y - y
				local distanceSquared = dx * dx + dy * dy
				if distanceSquared < bestDistanceSquared then
					best = point
					bestDistanceSquared = distanceSquared
				end
			end
		end
	end
	return best
end

return point_grid

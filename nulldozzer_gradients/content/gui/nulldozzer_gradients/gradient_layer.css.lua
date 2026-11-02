local ssu = require "::/gui/main/stylesheetutil.lua"

function data()
	local result = {}
	local a = ssu.makeAdder(result)

	-- Same place and width as the game's own data layer window.
	a("Window#nullDozzerGradientsWindow", {
		margin = { 30, 0, 0, 80 },
		size = { 420, -1 },
		gravity = { 0, 0 },
	})

	a("R::NullDozzerGradientLegendLabels", {
		gravity = { -1, 0 },
	})

	a("R::NullDozzerGradientLegendLabels !nulldozzer-legend-spacer", {
		gravity = { -1, 0 },
	})

	return result
end

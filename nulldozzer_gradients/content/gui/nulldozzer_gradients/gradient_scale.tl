local gradient_scale : NullDozzerGradientScale = {}

local type Scale = NullDozzerGradientScale.Scale

local GREEN <const> = { 0.20, 0.75, 0.25 }
local YELLOW <const> = { 1.00, 0.85, 0.10 }
local RED <const> = { 0.90, 0.15, 0.10 }
local BLACK <const> = { 0.05, 0.05, 0.05 }

local SCALES : {NullDozzerNetworkScan.Kind : Scale} = {
	track = {
		stops = {
			{ gradient = 0.00, color = GREEN },
			{ gradient = 0.02, color = YELLOW },
			{ gradient = 0.04, color = RED },
			{ gradient = 0.09, color = BLACK },
		},
		legendGradients = { 0.00, 0.03, 0.06, 0.09 },
	},
	road = {
		stops = {
			{ gradient = 0.00, color = GREEN },
			{ gradient = 0.05, color = YELLOW },
			{ gradient = 0.10, color = RED },
			{ gradient = 0.20, color = BLACK },
		},
		legendGradients = { 0.00, 0.05, 0.10, 0.15, 0.20 },
	},
}

local function mix(a : number, b : number, t : number) : number
	return a + (b - a) * t
end

local function mixColors(a : {number}, b : {number}, t : number) : {number}
	return { mix(a[1], b[1], t), mix(a[2], b[2], t), mix(a[3], b[3], t) }
end

local function rgbAt(scale : Scale, gradient : number) : {number}
	local stops = scale.stops
	if gradient <= stops[1].gradient then
		return stops[1].color
	end
	for i = 2, #stops do
		local lower = stops[i - 1]
		local upper = stops[i]
		if gradient <= upper.gradient then
			local t = (gradient - lower.gradient) / (upper.gradient - lower.gradient)
			return mixColors(lower.color, upper.color, t)
		end
	end
	return stops[#stops].color
end

function gradient_scale.forKind(kind : NullDozzerNetworkScan.Kind) : Scale
	return SCALES[kind]
end

function gradient_scale.colorFor(scale : Scale, gradient : number, opacity : number) : Vec4f
	local rgb = rgbAt(scale, gradient)
	return api.type.Vec4f.new(rgb[1], rgb[2], rgb[3], opacity)
end

return gradient_scale

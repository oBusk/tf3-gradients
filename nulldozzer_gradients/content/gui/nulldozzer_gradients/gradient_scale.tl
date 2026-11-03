local gradient_scale : NullDozzerGradientScale = {}

local type Scale = NullDozzerGradientScale.Scale
local type Kind = NullDozzerNetworkScan.Kind

local GREEN <const> = { 0.20, 0.75, 0.25 }
local YELLOW <const> = { 1.00, 0.85, 0.10 }
local RED <const> = { 0.90, 0.15, 0.10 }
local BLACK <const> = { 0.05, 0.05, 0.05 }

-- Each colour sits at a fraction of the steepest gradient the player may build,
-- so black always means "at the limit", whatever the limit is.
local STOPS : {{number, {number}}} = {
	{ 0.0, GREEN },
	{ 1.0 / 3.0, YELLOW },
	{ 2.0 / 3.0, RED },
	{ 1.0, BLACK },
}

-- Used only if no buildable template of that kind reports a limit.
-- Vanilla values: tracks set 8.5% (base/content/infrastructure/track.zip); roads
-- set nothing and get the engine default, which the game reports as 20%.
local FALLBACK_MAX : {Kind : number} = {
	track = 0.085,
	road = 0.20,
}

local ROAD_TYPES : {Kind : RoadType} = {
	track = api.type["enum"].RoadType.TRACK,
	road = api.type["enum"].RoadType.STREET,
}

local scales : {Kind : Scale} = {}

-- The base game marks templates the player can never build (depot and industry
-- tracks, 12.5% limit) with availability.yearFrom = 100000.
local NEVER_AVAILABLE_YEAR <const> = 100000

local function isPlayerBuildable(template : StreetTemplate) : boolean
	local availability = template.availability
	return availability == nil or availability.yearFrom < NEVER_AVAILABLE_YEAR
end

-- Steepest maxSlopeBuild among templates the player can build. Mods that change
-- the limit, e.g. Realistic Track Gradients, edit these templates, so the scale
-- follows them.
local function buildLimit(kind : Kind) : number
	local rep = api.res.streetTemplateRep
	local steepest = 0.0
	local steepestName = ""
	for id, name in pairs(rep.getAll()) do
		local template = rep.get(id)
		if template.roadType == ROAD_TYPES[kind] and isPlayerBuildable(template)
			and template.maxSlopeBuild ~= nil and template.maxSlopeBuild > steepest then
			steepest = template.maxSlopeBuild
			steepestName = name
		end
	end
	if steepest <= 0.0 then
		log.message("[nulldozzer_gradients] no " .. kind .. " build limit found, using fallback")
		return FALLBACK_MAX[kind]
	end
	log.message("[nulldozzer_gradients] " .. kind .. " build limit: " .. api.util.toStringPercentPrecision(steepest, 1) .. " (" .. steepestName .. ")")
	return steepest
end

local function makeScale(kind : Kind) : Scale
	local maxGradient = buildLimit(kind)
	local scale : Scale = { maxGradient = maxGradient, stops = {}, legendGradients = {} }
	for _, stop in ipairs(STOPS) do
		local gradient = stop[1] * maxGradient
		scale.stops[#scale.stops + 1] = { gradient = gradient, color = stop[2] }
		scale.legendGradients[#scale.legendGradients + 1] = gradient
	end
	return scale
end

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

function gradient_scale.forKind(kind : Kind) : Scale
	if scales[kind] == nil then
		scales[kind] = makeScale(kind)
	end
	return scales[kind]
end

function gradient_scale.colorFor(scale : Scale, gradient : number, opacity : number) : Vec4f
	local rgb = rgbAt(scale, gradient)
	return api.type.Vec4f.new(rgb[1], rgb[2], rgb[3], opacity)
end

return gradient_scale

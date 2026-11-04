local edge_profile : NullDozzerEdgeProfile = {}

local SAMPLE_SPACING <const> = 4.0
local MIN_HORIZONTAL_DISTANCE <const> = 0.01

local function positionAt(geometry : EdgeGeometry, t : number) : Vec3f
	return api.engine.util.transport.calcPosition(geometry, t)
end

local function horizontalDistance(a : Vec3f, b : Vec3f) : number
	local dx = b.x - a.x
	local dy = b.y - a.y
	return math.sqrt(dx * dx + dy * dy)
end

local function gradientOver(rise : number, run : number) : number
	if run < MIN_HORIZONTAL_DISTANCE then
		return 0.0
	end
	return math.abs(rise) / run
end

local function sampleBetween(a : Vec3f, b : Vec3f) : NullDozzerEdgeProfile.Sample
	return {
		x = (a.x + b.x) / 2,
		y = (a.y + b.y) / 2,
		gradient = gradientOver(b.z - a.z, horizontalDistance(a, b)),
	}
end

function edge_profile.measure(geometry : EdgeGeometry) : NullDozzerEdgeProfile.Profile
	local steps = math.max(1, math.ceil(geometry.length / SAMPLE_SPACING))
	local profile : NullDozzerEdgeProfile.Profile = { averageGradient = 0.0, maxGradient = 0.0, horizontalLength = 0.0, samples = {} }
	local first = positionAt(geometry, 0.0)
	local previous = first
	local run = 0.0
	for step = 1, steps do
		local current = positionAt(geometry, step / steps)
		local sample = sampleBetween(previous, current)
		profile.samples[#profile.samples + 1] = sample
		profile.maxGradient = math.max(profile.maxGradient, sample.gradient)
		run = run + horizontalDistance(previous, current)
		previous = current
	end
	-- Height change over the horizontal length along the track, like the build tool.
	profile.averageGradient = gradientOver(previous.z - first.z, run)
	profile.horizontalLength = run
	return profile
end

return edge_profile

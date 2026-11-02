local edge_profile : NullDozzerEdgeProfile = {}

local SAMPLE_SPACING <const> = 4.0
local MIN_HORIZONTAL_DISTANCE <const> = 0.01

local function positionAt(geometry : EdgeGeometry, t : number) : Vec3f
	return api.engine.util.transport.calcPosition(geometry, t)
end

local function gradientBetween(a : Vec3f, b : Vec3f) : number
	local dx = b.x - a.x
	local dy = b.y - a.y
	local horizontal = math.sqrt(dx * dx + dy * dy)
	if horizontal < MIN_HORIZONTAL_DISTANCE then
		return 0.0
	end
	return math.abs(b.z - a.z) / horizontal
end

local function sampleBetween(a : Vec3f, b : Vec3f) : NullDozzerEdgeProfile.Sample
	return {
		x = (a.x + b.x) / 2,
		y = (a.y + b.y) / 2,
		gradient = gradientBetween(a, b),
	}
end

function edge_profile.measure(geometry : EdgeGeometry) : NullDozzerEdgeProfile.Profile
	local steps = math.max(1, math.ceil(geometry.length / SAMPLE_SPACING))
	local profile : NullDozzerEdgeProfile.Profile = { maxGradient = 0.0, samples = {} }
	local previous = positionAt(geometry, 0.0)
	for step = 1, steps do
		local current = positionAt(geometry, step / steps)
		local sample = sampleBetween(previous, current)
		profile.samples[#profile.samples + 1] = sample
		profile.maxGradient = math.max(profile.maxGradient, sample.gradient)
		previous = current
	end
	return profile
end

return edge_profile

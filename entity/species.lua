local mathx = require "lib.math"
local data = require "lib.data"

local species = {}

-- Five trout taxa from data/trout, one file per fish. beat is
-- tail Hz. slither 0 tail only, 1 full body. Brown sits mid
-- way, part swim part slither.
species.list = data.list("trout")

species.by_id = {}
for i = 1, #species.list do
	species.by_id[species.list[i].id] = species.list[i]
end

-- Wrap an index into the species list.
function species.at(i)
	return species.list[((i - 1) % #species.list) + 1]
end

local clamp = mathx.clamp
local mix3 = mathx.mix3
local BELLY_CREAM = { 0.82, 0.80, 0.66 }

-- Weight each taxon for this water. Form: w = 0.15 + bed
-- * (0.35 + 0.65 * (flow + size) / 2). Bed sets the base,
-- flow and size pull toward taxa built for that beat.
function species.weights(char)
	local base = char.flow_speed or 1
	local u_flow = clamp((base - 0.45) / 1.1, 0, 1)
	local span = 216 - 78
	local u_size = clamp(((char.water_half or 120) - 78) / math.max(span, 1), 0, 1)
	local bed_id = char.bed_type and char.bed_type.id or "gravel"
	local out = {}
	for i = 1, #species.list do
		local spec = species.list[i]
		local bed_w = (spec.bed_fit and spec.bed_fit[bed_id]) or 0.5
		local flow_w = 1 - math.min(1, math.abs(u_flow - spec.current_tolerance) * 1.6)
		local size_w = 1 - math.min(1, math.abs(u_size - (spec.size_ideal or 0.5)) * 1.2)
		out[i] = 0.15 + bed_w * (0.35 + 0.65 * (0.5 * flow_w + 0.5 * size_w))
	end
	return out
end

-- Weighted pick from weights with a 0..1 roll.
function species.pick(weights, roll)
	local total = 0
	for i = 1, #weights do total = total + weights[i] end
	local x = roll * total
	for i = 1, #weights do
		x = x - weights[i]
		if x <= 0 then return species.list[i] end
	end
	return species.list[#species.list]
end

-- Copy a taxon tuned for this water. Stress form:
-- s = |u_flow - tol| * 1.5, clamped 0..1. Clear fast water
-- makes fish wary and less surface prone. Never mutates the list.
function species.instantiate(spec, char, clarity)
	local base = char.flow_speed or 1
	local u_flow = clamp((base - 0.45) / 1.1, 0, 1)
	local stress = clamp(math.abs(u_flow - spec.current_tolerance) * 1.5, 0, 1)
	local clear = (clarity or 0.5) - 0.5
	local out = {}
	for k, v in pairs(spec) do out[k] = v end
	out.feed = { spec.feed[1], spec.feed[2], spec.feed[3], spec.feed[4] }
	out.length_cm = { spec.length_cm[1], spec.length_cm[2] }
	out.manners = spec.manners
	out.skittish = clamp(spec.skittish + clear * 0.4 + stress * 0.15, 0, 1)
	out.cruise = spec.cruise * (1 + 0.5 * stress)
	out.surface_period = spec.surface_period * (1 + 0.8 * stress)
	out.aggression = clamp(spec.aggression * (1 - 0.3 * stress), 0, 1)
	out.rise_depth = clamp(spec.rise_depth * (1 - 0.2 * stress), 0.2, 0.9)
	-- Belly tint baked once. The draw loop used to mix this
	-- per fish per frame.
	out.belly = mix3(out.color, BELLY_CREAM, 0.7)
	return out
end

return species

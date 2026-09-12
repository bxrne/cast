local mathx = require "lib.math"

local species = {}

-- Five trout taxa. beat is tail Hz. slither 0 tail only, 1 full body.
-- Brown sits mid way, part swim part slither.
species.list = {
	{ id = "brown", binomial = "Salmo trutta", common = "brown trout", length_cm = { 24, 68 }, color = { 0.52, 0.44, 0.22 }, stripe = { 0.78, 0.40, 0.14 }, cover_need = 0.9, current_tolerance = 0.25, edge_bias = 0.7, depth_pref = 0.55, depth_need = 0.7, rise_depth = 0.48, cruise = 0.055, surface_period = 7.5, aggression = 0.85, skittish = 0.55, feed_period = 22, feed = { 0.22, 0.48, 0.12, 0.18 }, manners = { "sip", "rise", "head_and_tail" }, beat = 3.2, slither = 0.65, tail_amp = 0.55 },
	{ id = "rainbow", binomial = "Oncorhynchus mykiss", common = "rainbow trout", length_cm = { 22, 62 }, color = { 0.30, 0.48, 0.34 }, stripe = { 0.85, 0.34, 0.42 }, cover_need = 0.45, current_tolerance = 0.8, edge_bias = 0.25, depth_pref = 0.48, depth_need = 0.45, rise_depth = 0.72, cruise = 0.07, surface_period = 5.2, aggression = 0.7, skittish = 0.4, feed_period = 16, feed = { 0.12, 0.32, 0.18, 0.38 }, manners = { "rise", "splash", "sip" }, beat = 5.0, slither = 0.15, tail_amp = 1.0 },
	{ id = "brook", binomial = "Salvelinus fontinalis", common = "brook trout", length_cm = { 16, 38 }, color = { 0.30, 0.34, 0.18 }, stripe = { 0.85, 0.30, 0.18 }, cover_need = 0.85, current_tolerance = 0.2, edge_bias = 0.9, depth_pref = 0.22, depth_need = 0.8, rise_depth = 0.55, cruise = 0.05, surface_period = 6.4, aggression = 0.35, skittish = 0.8, feed_period = 18, feed = { 0.2, 0.4, 0.15, 0.25 }, manners = { "sip", "rise" }, beat = 4.2, slither = 0.3, tail_amp = 0.8 },
	{ id = "cutthroat", binomial = "Oncorhynchus clarkii", common = "cutthroat trout", length_cm = { 20, 52 }, color = { 0.48, 0.44, 0.22 }, stripe = { 0.88, 0.42, 0.22 }, cover_need = 0.6, current_tolerance = 0.45, edge_bias = 0.55, depth_pref = 0.35, depth_need = 0.6, rise_depth = 0.62, cruise = 0.06, surface_period = 8.0, aggression = 0.3, skittish = 0.75, feed_period = 20, feed = { 0.18, 0.38, 0.16, 0.28 }, manners = { "sip", "head_and_tail", "rise" }, beat = 3.8, slither = 0.35, tail_amp = 0.85 },
	{ id = "bull", binomial = "Salvelinus confluentus", common = "bull trout", length_cm = { 32, 86 }, color = { 0.38, 0.42, 0.36 }, stripe = { 0.40, 0.44, 0.40 }, cover_need = 0.75, current_tolerance = 0.35, edge_bias = 0.15, depth_pref = 0.82, depth_need = 0.9, rise_depth = 0.38, cruise = 0.048, surface_period = 16.0, aggression = 0.9, skittish = 0.25, feed_period = 28, feed = { 0.4, 0.45, 0.08, 0.07 }, manners = { "porpoise", "rise" }, beat = 2.6, slither = 0.5, tail_amp = 0.7 },
}

species.by_id = {}
for i = 1, #species.list do
	species.by_id[species.list[i].id] = species.list[i]
end

-- Wrap an index into the species list.
function species.at(i)
	return species.list[((i - 1) % #species.list) + 1]
end

-- Bed fit per taxon. Rows follow list order. Keys are bed ids.
local BED_FIT = {
	brown = { chalk = 1.0, gravel = 0.95, silt = 0.5, peat = 0.3, bedrock = 0.45 },
	rainbow = { chalk = 0.7, gravel = 1.0, silt = 0.4, peat = 0.3, bedrock = 0.8 },
	brook = { chalk = 0.4, gravel = 0.6, silt = 0.55, peat = 0.95, bedrock = 0.35 },
	cutthroat = { chalk = 0.6, gravel = 0.9, silt = 0.5, peat = 0.5, bedrock = 0.5 },
	bull = { chalk = 0.35, gravel = 0.55, silt = 0.4, peat = 0.6, bedrock = 1.0 },
}

-- Ideal size per taxon, 0 creek to 1 broad river.
local SIZE_IDEAL = { brown = 0.6, rainbow = 0.5, brook = 0.2, cutthroat = 0.4, bull = 0.8 }

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
		local bed_w = (BED_FIT[spec.id] and BED_FIT[spec.id][bed_id]) or 0.5
		local flow_w = 1 - math.min(1, math.abs(u_flow - spec.current_tolerance) * 1.6)
		local size_w = 1 - math.min(1, math.abs(u_size - (SIZE_IDEAL[spec.id] or 0.5)) * 1.2)
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

local mathx = require "lib.math"

local habitat = {}
local clamp = mathx.clamp

local GRID_T, GRID_A = 40, 11
local ACROSS_LO, ACROSS_HI = 0.22, 0.78
local MIN_DT, MIN_DA = 0.055, 0.16

-- Keep a station inside the wet channel, off the gravel lip.
function habitat.channel_across(across)
	return clamp(across, ACROSS_LO, ACROSS_HI)
end

-- Piecewise tent used by PHABSIM suitability curves.
local function tent(x, lo, peak, hi)
	if x <= lo or x >= hi or peak <= lo or hi <= peak then
		return 0
	end
	if x < peak then
		return (x - lo) / (peak - lo)
	end
	return (hi - x) / (hi - peak)
end

-- Velocity SI. Peak shifts with how much current the species will sit in.
local function si_velocity(sample, spec, base)
	local v = sample.speed / math.max(base, 0.2)
	local peak = 0.20 + 0.38 * spec.current_tolerance
	return 0.06 + 0.94 * tent(v, 0.02, peak, peak + 0.5 + 0.25 * (1 - spec.current_tolerance))
end

-- Depth SI. Peaks at the species' preferred column depth.
local function si_depth(sample, spec)
	local peak = spec.depth_pref
	return 0.08 + 0.92 * tent(sample.depth_n, 0.04, peak, math.min(1, peak + 0.55))
end

-- Cover SI from seams, inside of bends, and bank shade.
local function si_cover(sample, spec)
	local edge = math.min(sample.across, 1 - sample.across)
	local seam = sample.seam / (sample.speed + 0.25)
	local inside = 0
	if sample.kappa > 0.02 and sample.across < 0.48 then
		inside = 1
	elseif sample.kappa < -0.02 and sample.across > 0.52 then
		inside = 1
	end
	return clamp(0.15 + 0.45 * seam + 0.3 * inside + spec.edge_bias * (0.32 - edge), 0.04, 1)
end

-- Hughes–Dill style net energy: drift in the next lane minus hold cost.
function habitat.energy(sample, river, spec)
	local base = river.flow.base_speed
	local v_hold, v_drift = sample.speed, sample.speed
	for d = -2, 2 do
		if d ~= 0 then
			local s = river:sample(sample.t, habitat.channel_across(sample.across + d * 0.07))
			if s.speed > v_drift then
				v_drift = s.speed
			end
		end
	end
	local capture = math.exp(-1.35 * v_hold / math.max(v_drift, 0.12))
	local intake = (v_drift / math.max(base, 0.2)) * capture
	local cost = 0.32 * (v_hold / math.max(base, 0.2)) ^ 3
	return intake - cost
end

-- Combined habitat score: geometric-mean HSI times normalised energy.
function habitat.score(sample, spec, river)
	local base = river.flow.base_speed
	local hsi = (si_velocity(sample, spec, base) * si_depth(sample, spec) * si_cover(sample, spec)) ^ (1 / 3)
	local nei = habitat.energy(sample, river, spec)
	return hsi * (0.4 + 0.6 * clamp(0.5 + nei, 0, 1.4))
end

-- Sample the channel on a regular (t, across) grid.
function habitat.grid(river)
	local cells = {}
	for i = 1, GRID_T do
		local t = 0.07 + (i - 0.5) / GRID_T * 0.86
		for j = 1, GRID_A do
			local across = ACROSS_LO + (j - 1) / (GRID_A - 1) * (ACROSS_HI - ACROSS_LO)
			cells[#cells + 1] = river:sample(t, across)
		end
	end
	return cells
end

-- True when two lies are far enough apart along the beat.
local function separated(a, b)
	return math.abs(a.t - b.t) > MIN_DT or math.abs(a.across - b.across) > MIN_DA
end

-- Best cell for spec, skipping taken lies. Optional extra(sample) bonus.
function habitat.best(cells, spec, river, taken, extra)
	local best, pick = -1e9, cells[1]
	for i = 1, #cells do
		local sample = cells[i]
		local ok = true
		for j = 1, #taken do
			if not separated(sample, taken[j]) then
				ok = false
				break
			end
		end
		if ok then
			local score = habitat.score(sample, spec, river)
			if extra then
				score = score + extra(sample)
			end
			if score > best then
				best, pick = score, sample
			end
		end
	end
	return pick, best
end

-- Place each species on a distinct lie. Fish appear where they will hold.
function habitat.place(river, specs)
	local cells, taken, spots = habitat.grid(river), {}, {}
	for i = 1, #specs do
		local pick = habitat.best(cells, specs[i], river, taken)
		taken[#taken + 1] = pick
		spots[i] = pick
	end
	return spots
end

return habitat

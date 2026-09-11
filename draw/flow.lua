local mathx = require "lib.math"

local flow = {}
local lerp, clamp, norm, tangent = mathx.lerp, mathx.clamp, mathx.norm, mathx.tangent
local DEPTH_REF = 12

-- Water column depth at a station. Shallow on the shelves, deep in the thalweg.
function flow.depth(st, across)
	local edge = math.min(across, 1 - across)
	local shelf = clamp(edge / 0.15, 0, 1)
	local trough = 1 - math.min(1, (across - st.thalweg) ^ 2 * 5.2)
	return st.bed_scale * (3 + (7 + 26 * st.pool) * trough * shelf)
end

-- Speed at a channel station: faster on the outside of a bend and in shallows.
local function speed_across(base, st, across, width_scale)
	local bend = 1 + clamp(st.kappa * 5, -0.6, 0.6) * (across - 0.5) * 2
	local mid = 1 - (across - 0.5) * (across - 0.5) * 1.35
	local depth = flow.depth(st, across)
	local skinny = (DEPTH_REF / math.max(depth, 3)) ^ 0.42
	return base * width_scale * clamp(bend, 0.32, 1.85) * (0.52 + 0.48 * mid) * skinny
end

-- Build a sampleable flow field from centerline stations and a bed type.
function flow.build(pts, base_speed, bed)
	bed = bed or { depth_scale = 1, pool_contrast = 0.5 }
	local n, mean_hw = #pts, 0
	for i = 1, n do
		mean_hw = mean_hw + pts[i].hw
	end
	mean_hw = mean_hw / n
	local stations = {}
	for i = 1, n do
		local p = pts[i]
		local tx, ty = tangent(pts, i)
		local t0x, t0y = tangent(pts, math.max(1, i - 1))
		local t1x, t1y = tangent(pts, math.min(n, i + 1))
		local kappa = t0x * t1y - t0y * t1x
		local wave = 0.5 + 0.5 * math.sin(p.t * 5.2 * math.pi)
		stations[i] = {
			t = p.t, x = p.x, y = p.y, hw = p.hw,
			tx = tx, ty = ty, px = -ty, py = tx,
			kappa = kappa,
			width_scale = mean_hw / math.max(p.hw, 8),
			thalweg = 0.5 + clamp(kappa * 3, -0.16, 0.16),
			pool = 0.5 + (wave - 0.5) * bed.pool_contrast,
			bed_scale = bed.depth_scale,
		}
	end
	return { stations = stations, base_speed = base_speed, bed = bed }
end

-- Neighbour stations and blend factor for t in [0, 1].
local function pair(field, t)
	local s, n = field.stations, #field.stations
	t = clamp(t, 0, 1)
	local f = t * (n - 1) + 1
	local i = math.floor(f)
	if i < 1 then
		return s[1], s[1], 0
	end
	if i >= n then
		return s[n], s[n], 0
	end
	return s[i], s[i + 1], f - i
end

-- Blend two stations for depth lookups.
local function blend_station(a, b, u)
	return {
		kappa = lerp(a.kappa, b.kappa, u),
		width_scale = lerp(a.width_scale, b.width_scale, u),
		thalweg = lerp(a.thalweg, b.thalweg, u),
		pool = lerp(a.pool, b.pool, u),
		bed_scale = lerp(a.bed_scale, b.bed_scale, u),
		hw = lerp(a.hw, b.hw, u),
	}
end

-- Speed at a station using the field's base current.
function flow.speed(field, st, across)
	return speed_across(field.base_speed, st, across, st.width_scale)
end

-- World pose, speed, depth, pressure, and seam strength at (t, across).
function flow.sample(field, t, across)
	across = clamp(across, 0, 1)
	local a, b, u = pair(field, t)
	local st = blend_station(a, b, u)
	local tx, ty = norm(lerp(a.tx, b.tx, u), lerp(a.ty, b.ty, u))
	local px, py = -ty, tx
	local depth = flow.depth(st, across)
	local speed = speed_across(field.base_speed, st, across, st.width_scale)
	local s_in = speed_across(field.base_speed, st, clamp(across - 0.08, 0, 1), st.width_scale)
	local s_out = speed_across(field.base_speed, st, clamp(across + 0.08, 0, 1), st.width_scale)
	return {
		x = lerp(a.x, b.x, u) + px * st.hw * (across * 2 - 1),
		y = lerp(a.y, b.y, u) + py * st.hw * (across * 2 - 1),
		tx = tx, ty = ty, px = px, py = py,
		t = t, across = across, hw = st.hw, kappa = st.kappa,
		speed = speed, depth = depth, depth_n = clamp(depth / 36, 0, 1),
		pressure = 1 / (0.18 + speed),
		seam = math.abs(s_out - s_in),
		pool = st.pool,
	}
end

-- How good a hold is: slack water next to a seam.
function flow.lie_score(sample)
	return sample.seam * sample.pressure
end

return flow

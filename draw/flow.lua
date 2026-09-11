local mathx = require "lib.math"

local flow = {}
local lerp, clamp, norm, tangent = mathx.lerp, mathx.clamp, mathx.norm, mathx.tangent
local DEPTH_REF = 12
local CLUSTERS = 13 -- eddy cluster count along the beat

-- Water column depth at a station. Cross-section from riffle-pool
-- geometry: the shelf ramps from the shore to the trough, the pool
-- deepens the thalweg, and bed_scale sets the overall depth.
-- Reference form: piecewise cross-section control.
function flow.depth(st, across)
	local edge = math.min(across, 1 - across)
	local shelf = clamp(edge / 0.15, 0, 1)
	local trough = 1 - math.min(1, (across - st.thalweg) ^ 2 * 5.2)
	return st.bed_scale * (3 + (7 + 26 * st.pool) * trough * shelf)
end

-- Base channel speed. Terms, in order:
--  bend  - superelevation puts the outside of a curve faster (kappa);
--  mid   - the thalweg line runs faster than the margins (parabola);
--  skin  - shallow riffles run faster than deep pools (V ~ D^-0.42);
--  drag  - the boundary layer slows water near the shoreline;
--  widen - continuity: a widening reach decelerates, a narrowing one
--          accelerates and drags off the bank geometry.
local function speed_across(base, st, across, width_scale)
	local bend = 1 + clamp(st.kappa * 5, -0.6, 0.6) * (across - 0.5) * 2
	local mid = 1 - (across - 0.5) * (across - 0.5) * 1.35
	local depth = flow.depth(st, across)
	local skin = (DEPTH_REF / math.max(depth, 3)) ^ 0.42
	local edge = math.min(across, 1 - across)
	local drag = 1 - 0.40 * clamp((0.14 - edge) / 0.14, 0, 1)
	local widen = 1 - clamp(st.dhw * 2.2, -0.15, 0.30)
	return base * width_scale * clamp(bend, 0.32, 1.85) * (0.52 + 0.48 * mid) * skin * drag * widen
end

-- Seeded eddy clusters: a fraction of the beat is turbulent. Each
-- cluster has its own strength, drift rate, and phase so the pattern
-- is unique per river seed.
local function build_clusters(seed, n)
	local out = {}
	for i = 1, n do
		local key = mathx.hash01(seed, i, 71)
		out[i] = {
			strength = key < 0.55 and (0.4 + key * 0.4) or 0,
			rate = 0.7 + key * 1.5,
			phase = key * 8.0,
		}
	end
	return out
end

-- Sitting eddy: returns (swirl magnitude 0..1, heading rotation in
-- radians). It pulses inside its cluster cell, drifts with time, and
-- intensifies near the banks and at sharp bends (drag off geometry).
local function turbulence(field, t, across, kappa, time)
	if not field.turbulent then
		return 0, 0
	end
	local u = t * CLUSTERS
	local cell = math.floor(u) % CLUSTERS + 1
	local c = field.turbulent[cell]
	if c.strength <= 0 then
		return 0, 0
	end
	local pulse = math.sin((u - math.floor(u)) * math.pi)
	local sway = math.sin(time * c.rate + c.phase + u * 6.283)
	local near_bank = 0.45 + 1.15 * math.min(across, 1 - across)
	local sharp = 0.6 + math.min(1, math.abs(kappa) * 14)
	local amt = c.strength * field.turb_scale * pulse * sway * near_bank * sharp
	return math.abs(amt), amt * 0.32
end

-- Build a sampleable flow field from centerline stations and a bed.
-- Seed drives the eddy cluster placement; obstacles add their wakes
-- and shade to the field.
function flow.build(pts, base_speed, bed, seed, obstacles)
	bed = bed or { depth_scale = 1, pool_contrast = 0.5 }
	local n, mean_hw, step = #pts, 0, (1 / math.max(1, #pts - 1))
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
		local kappa = t0x * t1y - t0y * t1x -- signed bend curvature
		local wave = 0.5 + 0.5 * math.sin(p.t * 5.2 * math.pi)
		local prev_hw = pts[math.max(1, i - 1)].hw
		local next_hw = pts[math.min(n, i + 1)].hw
		stations[i] = {
			t = p.t, x = p.x, y = p.y, hw = p.hw,
			tx = tx, ty = ty, px = -ty, py = tx,
			kappa = kappa,
			dhw = (next_hw - prev_hw) / (2 * step), -- width gradient along t
			width_scale = mean_hw / math.max(p.hw, 8),
			thalweg = 0.5 + clamp(kappa * 3, -0.16, 0.16),
			pool = 0.5 + (wave - 0.5) * bed.pool_contrast,
			bed_scale = bed.depth_scale,
		}
	end
	local field = { stations = stations, base_speed = base_speed, base = base_speed, turb_scale = 1, bed = bed }
	field.turbulent = seed and build_clusters(seed, CLUSTERS) or nil
	field.obstacles = obstacles or nil
	return field
end

-- Wake and shade from the obstacle field. A rock slows the lanes
-- downstream of it (the slack trout lie) and casts cover around it.
local function obstacles_at(list, t, across)
	local wake, shade = 0, 0
	for i = 1, #list do
		local o = list[i]
		local dt = (t - o.t) / o.wt
		local da = (across - o.across) / o.dw
		if dt > -0.06 and dt < 1.05 and math.abs(da) < 1.25 then
			local lat = 1 - math.min(1, math.abs(da))
			local down = 1 - math.max(0, dt)
			wake = wake + lat * down
		end
		local d = math.sqrt(dt * dt + da * da * 0.35)
		if d < 2.0 then
			shade = shade + (1 - d / 2.0) * o.shade
		end
	end
	return clamp(wake, 0, 1.4), clamp(shade, 0, 1)
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
		dhw = lerp(a.dhw, b.dhw, u),
	}
end

-- Speed at a station using the field's base current. Geometry only.
function flow.speed(field, st, across)
	return speed_across(field.base_speed, st, across, st.width_scale)
end

-- Full field sample. With a time argument the heading and speed pick
-- up the eddy field; without it the sample is pure geometry, which
-- habitat scoring and the player pose rely on.
function flow.sample(field, t, across, time)
	across = clamp(across, 0, 1)
	local a, b, u = pair(field, t)
	local st = blend_station(a, b, u)
	local tx, ty = norm(lerp(a.tx, b.tx, u), lerp(a.ty, b.ty, u))
	local px, py = -ty, tx
	local depth = flow.depth(st, across)
	local speed = speed_across(field.base_speed, st, across, st.width_scale)
	local s_in = speed_across(field.base_speed, st, clamp(across - 0.08, 0, 1), st.width_scale)
	local s_out = speed_across(field.base_speed, st, clamp(across + 0.08, 0, 1), st.width_scale)
	local eddy, spin = 0, 0
	local wake, shade = 0, 0
	if field.obstacles then
		wake, shade = obstacles_at(field.obstacles, t, across)
		speed = speed * (1 - 0.5 * wake)
	end
	if time then
		eddy, spin = turbulence(field, t, across, st.kappa, time)
		eddy = eddy + wake * 0.3
		spin = spin + wake * 0.28 * math.sin(time * 3.1 + t * 13.0)
		speed = speed * (1 + eddy * 0.12)
	end
	if spin ~= 0 then -- rotate heading into the swirl, keep the pose fixed
		local c, s = math.cos(spin), math.sin(spin)
		tx, ty = tx * c - ty * s, tx * s + ty * c
	end
	return {
		x = lerp(a.x, b.x, u) + px * st.hw * (across * 2 - 1),
		y = lerp(a.y, b.y, u) + py * st.hw * (across * 2 - 1),
		tx = tx, ty = ty, px = px, py = py,
		t = t, across = across, hw = st.hw, kappa = st.kappa,
		speed = speed, depth = depth, depth_n = clamp(depth / 36, 0, 1),
		pressure = 1 / (0.18 + speed), -- Bernoulli-like: slow water reads as high pressure
		seam = math.abs(s_out - s_in), -- shear between neighbouring lanes
		pool = st.pool,
		eddy = eddy,
		shade = shade,
	}
end

-- How good a hold is: slack water next to a seam. Fish use shear
-- zones as energy refugia, so pressure and seam combine.
function flow.lie_score(sample)
	return sample.seam * sample.pressure
end

return flow
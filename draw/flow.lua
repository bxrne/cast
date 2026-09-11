local mathx = require "lib.math"

local flow = {}
local lerp, clamp, norm, tangent = mathx.lerp, mathx.clamp, mathx.norm, mathx.tangent
local DEPTH_REF = 12
local CLUSTERS = 13 -- eddy cluster count along the beat

-- Water column depth. Form: D = S * (3 + (7 + 26 * pool)
-- * trough * shelf). Shelf ramps from the shore, trough peaks
-- at the thalweg, pool scales the contrast, S the bed.
function flow.depth(st, across)
	local edge = math.min(across, 1 - across)
	local shelf = clamp(edge / 0.15, 0, 1)
	local trough = 1 - math.min(1, (across - st.thalweg) ^ 2 * 5.2)
	return st.bed_scale * (3 + (7 + 26 * st.pool) * trough * shelf)
end

-- Base channel speed. Form: V = Vb * Ws * bend * mid * skin
-- * drag * widen. Skin follows V ~ D^-0.42, so shallow riffles
-- run faster than deep pools. Terms, in order:
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

-- Flat scalar form. Same math, no station table. depth_hint
-- skips one depth eval for the neighbour lane lookups.
local function speed_across_st(base, kappa, width_scale, thalweg, pool, bed_scale, hw, dhw, across, depth_hint)
	local k = kappa * 5
	if k < -0.6 then k = -0.6 elseif k > 0.6 then k = 0.6 end
	local bend = 1 + k * (across - 0.5) * 2
	if bend < 0.32 then bend = 0.32 elseif bend > 1.85 then bend = 1.85 end
	local d = across - 0.5
	local mid = 1 - d * d * 1.35
	local depth = depth_hint
	if not depth then
		local edge0 = across < 0.5 and across or 1 - across
		local shelf0 = edge0 / 0.15
		if shelf0 > 1 then shelf0 = 1 end
		local dtw = across - thalweg
		local trough0 = 1 - dtw * dtw * 5.2
		if trough0 < 0 then trough0 = 0 elseif trough0 > 1 then trough0 = 1 end
		depth = bed_scale * (3 + (7 + 26 * pool) * trough0 * shelf0)
	end
	local skin = (DEPTH_REF / (depth < 3 and 3 or depth)) ^ 0.42
	local edge = across < 0.5 and across or 1 - across
	local drag = 1 - 0.40 * (edge > 0.14 and 0 or (0.14 - edge) / 0.14)
	local w = dhw * 2.2
	if w < -0.15 then w = -0.15 elseif w > 0.30 then w = 0.30 end
	return base * width_scale * bend * (0.52 + 0.48 * mid) * skin * drag * (1 - w)
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

-- Full field sample into out. No alloc. Hot path for fish,
-- flow map bakes, and debug arrows. Returns out.
function flow.sample_into(field, t, across, time, out)
	across = clamp(across, 0, 1)
	local a, b, u = pair(field, t)
	local iu = 1 - u
	local kappa = a.kappa * iu + b.kappa * u
	local width_scale = a.width_scale * iu + b.width_scale * u
	local thalweg = a.thalweg * iu + b.thalweg * u
	local pool = a.pool * iu + b.pool * u
	local bed_scale = a.bed_scale * iu + b.bed_scale * u
	local hw = a.hw * iu + b.hw * u
	local dhw = a.dhw * iu + b.dhw * u
	local tx, ty = norm(a.tx * iu + b.tx * u, a.ty * iu + b.ty * u)
	local px, py = -ty, tx
	local edge = across < 0.5 and across or 1 - across
	local shelf = edge / 0.15
	if shelf > 1 then shelf = 1 end
	local dtw = across - thalweg
	local trough = 1 - dtw * dtw * 5.2
	if trough < 0 then trough = 0 elseif trough > 1 then trough = 1 end
	local depth = bed_scale * (3 + (7 + 26 * pool) * trough * shelf)
	local speed = speed_across_st(field.base_speed, kappa, width_scale, thalweg, pool, bed_scale, hw, dhw, across, depth)
	local s_in = speed_across_st(field.base_speed, kappa, width_scale, thalweg, pool, bed_scale, hw, dhw, across - 0.08 < 0 and 0 or across - 0.08, nil)
	local s_out = speed_across_st(field.base_speed, kappa, width_scale, thalweg, pool, bed_scale, hw, dhw, across + 0.08 > 1 and 1 or across + 0.08, nil)
	local eddy, spin, wake, shade = 0, 0, 0, 0
	if field.obstacles then
		wake, shade = obstacles_at(field.obstacles, t, across)
		speed = speed * (1 - 0.5 * wake)
	end
	if time then
		eddy, spin = turbulence(field, t, across, kappa, time)
		eddy = eddy + wake * 0.3
		spin = spin + wake * 0.28 * math.sin(time * 3.1 + t * 13.0)
		speed = speed * (1 + eddy * 0.12)
	end
	if spin ~= 0 then
		local c, s = math.cos(spin), math.sin(spin)
		local ntx = tx * c - ty * s
		ty = tx * s + ty * c
		tx = ntx
	end
	out = out or {}
	out.x = (a.x * iu + b.x * u) + px * hw * (across * 2 - 1)
	out.y = (a.y * iu + b.y * u) + py * hw * (across * 2 - 1)
	out.tx = tx
	out.ty = ty
	out.px = px
	out.py = py
	out.t = t
	out.across = across
	out.hw = hw
	out.kappa = kappa
	out.speed = speed
	out.depth = depth
	out.depth_n = depth / 36 < 0 and 0 or (depth / 36 > 1 and 1 or depth / 36)
	out.pressure = 1 / (0.18 + speed)
	out.seam = s_out > s_in and s_out - s_in or s_in - s_out
	out.pool = pool
	out.eddy = eddy
	out.shade = shade
	out.occ = out.occ or 0
	return out
end

-- Full field sample. With a time argument the heading and speed pick
-- up the eddy field; without it the sample is pure geometry, which
-- habitat scoring and the player pose rely on.
function flow.sample(field, t, across, time)
	return flow.sample_into(field, t, across, time, nil)
end

-- How good a hold is: slack water next to a seam. Form:
-- L = seam * P with P = 1 / (0.18 + V) and seam the shear
-- |Vout - Vin| between neighbouring lanes.
function flow.lie_score(sample)
	return sample.seam * sample.pressure
end

return flow
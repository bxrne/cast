local mathx = require "lib.math"

local flow = {}
local lerp, clamp, norm, tangent = mathx.lerp, mathx.clamp, mathx.norm, mathx.tangent

-- Speed at a channel station: faster on the outside of a bend and in the middle.
local function speed_across(base, kappa, across, width_scale)
	local bend = 1 + clamp(kappa * 5, -0.6, 0.6) * (across - 0.5) * 2
	local mid = 1 - (across - 0.5) * (across - 0.5) * 1.35
	return base * width_scale * clamp(bend, 0.32, 1.85) * (0.52 + 0.48 * mid)
end

-- Build a sampleable flow field from centerline stations.
function flow.build(pts, base_speed)
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
		stations[i] = {
			t = p.t, x = p.x, y = p.y, hw = p.hw,
			tx = tx, ty = ty, px = -ty, py = tx,
			kappa = t0x * t1y - t0y * t1x,
			width_scale = mean_hw / math.max(p.hw, 8),
		}
	end
	return { stations = stations, base_speed = base_speed }
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

-- Speed at a station using the field's base current.
function flow.speed(field, kappa, across, width_scale)
	return speed_across(field.base_speed, kappa, across, width_scale)
end

-- World pose, speed, pressure, and seam strength at (t, across).
function flow.sample(field, t, across)
	across = clamp(across, 0, 1)
	local a, b, u = pair(field, t)
	local hw = lerp(a.hw, b.hw, u)
	local tx, ty = norm(lerp(a.tx, b.tx, u), lerp(a.ty, b.ty, u))
	local px, py = -ty, tx
	local kappa = lerp(a.kappa, b.kappa, u)
	local width_scale = lerp(a.width_scale, b.width_scale, u)
	local speed = speed_across(field.base_speed, kappa, across, width_scale)
	local s_in = speed_across(field.base_speed, kappa, clamp(across - 0.08, 0, 1), width_scale)
	local s_out = speed_across(field.base_speed, kappa, clamp(across + 0.08, 0, 1), width_scale)
	return {
		x = lerp(a.x, b.x, u) + px * hw * (across * 2 - 1),
		y = lerp(a.y, b.y, u) + py * hw * (across * 2 - 1),
		tx = tx, ty = ty, px = px, py = py,
		t = t, across = across, hw = hw, kappa = kappa, speed = speed,
		pressure = 1 / (0.18 + speed),
		seam = math.abs(s_out - s_in),
	}
end

-- How good a hold is: slack water next to a seam.
function flow.lie_score(sample)
	return sample.seam * sample.pressure
end

return flow

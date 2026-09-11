local flow = {}

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function clamp(x, lo, hi)
	if x < lo then
		return lo
	end
	if x > hi then
		return hi
	end
	return x
end

local function norm(x, y)
	local len = math.sqrt(x * x + y * y)
	if len < 1e-6 then
		return 1, 0, 0
	end
	return x / len, y / len, len
end

local function tangent(pts, i)
	local prev = pts[math.max(1, i - 1)]
	local nxt = pts[math.min(#pts, i + 1)]
	local x, y = norm(nxt.x - prev.x, nxt.y - prev.y)
	return x, y
end

local function speed_across(base, kappa, across, width_scale)
	local bend = 1 + clamp(kappa * 5, -0.6, 0.6) * (across - 0.5) * 2
	local mid = 1 - (across - 0.5) * (across - 0.5) * 1.35
	return base * width_scale * clamp(bend, 0.32, 1.85) * (0.52 + 0.48 * mid)
end

function flow.build(pts, base_speed)
	local n = #pts
	local mean_hw = 0
	for i = 1, n do
		mean_hw = mean_hw + pts[i].hw
	end
	mean_hw = mean_hw / n

	local stations = {}
	for i = 1, n do
		local tx, ty = tangent(pts, i)
		local t0x, t0y = tangent(pts, math.max(1, i - 1))
		local t1x, t1y = tangent(pts, math.min(n, i + 1))
		local kappa = t0x * t1y - t0y * t1x
		local hw = pts[i].hw
		stations[i] = {
			t = pts[i].t,
			x = pts[i].x,
			y = pts[i].y,
			hw = hw,
			tx = tx,
			ty = ty,
			px = -ty,
			py = tx,
			kappa = kappa,
			width_scale = mean_hw / math.max(hw, 8),
		}
	end

	return {
		stations = stations,
		base_speed = base_speed,
	}
end

local function pair(field, t)
	local stations = field.stations
	local n = #stations
	t = clamp(t, 0, 1)
	local f = t * (n - 1) + 1
	local i = math.floor(f)
	if i < 1 then
		return stations[1], stations[1], 0
	end
	if i >= n then
		return stations[n], stations[n], 0
	end
	return stations[i], stations[i + 1], f - i
end

function flow.speed(field, kappa, across, width_scale)
	return speed_across(field.base_speed, kappa, across, width_scale)
end

function flow.sample(field, t, across)
	across = clamp(across, 0, 1)
	local a, b, u = pair(field, t)
	local x = lerp(a.x, b.x, u)
	local y = lerp(a.y, b.y, u)
	local hw = lerp(a.hw, b.hw, u)
	local tx, ty = norm(lerp(a.tx, b.tx, u), lerp(a.ty, b.ty, u))
	local px, py = -ty, tx
	local kappa = lerp(a.kappa, b.kappa, u)
	local width_scale = lerp(a.width_scale, b.width_scale, u)
	local dist = hw * (across * 2 - 1)
	local speed = speed_across(field.base_speed, kappa, across, width_scale)
	local s_in = speed_across(field.base_speed, kappa, clamp(across - 0.08, 0, 1), width_scale)
	local s_out = speed_across(field.base_speed, kappa, clamp(across + 0.08, 0, 1), width_scale)
	local seam = math.abs(s_out - s_in)
	return {
		x = x + px * dist,
		y = y + py * dist,
		tx = tx,
		ty = ty,
		px = px,
		py = py,
		t = t,
		across = across,
		speed = speed,
		pressure = 1 / (0.18 + speed),
		seam = seam,
		kappa = kappa,
		hw = hw,
	}
end

function flow.lie_score(sample)
	return sample.seam * sample.pressure
end

return flow

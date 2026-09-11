local mathx = {}

mathx.TAU = math.pi * 2

local sin, floor, sqrt, max, min = math.sin, math.floor, math.sqrt, math.max, math.min

-- Interpolate from a to b by t in [0, 1].
function mathx.lerp(a, b, t)
	return a + (b - a) * t
end

-- Clamp x into [lo, hi]. Uses ifs so lo = 0 is safe.
function mathx.clamp(x, lo, hi)
	if x < lo then
		return lo
	end
	if x > hi then
		return hi
	end
	return x
end

-- Lerp two rgb triples.
function mathx.mix3(a, b, t)
	return { mathx.lerp(a[1], b[1], t), mathx.lerp(a[2], b[2], t), mathx.lerp(a[3], b[3], t) }
end

-- Fractional part of x.
function mathx.fract(x)
	return x - floor(x)
end

-- Deterministic 0..1 hash of up to three numbers.
function mathx.hash01(a, b, c)
	return mathx.fract(sin(a * 127.1 + (b or 0) * 311.7 + (c or 0) * 74.7) * 43758.5453)
end

-- Tile-friendly 2D hash.
function mathx.hash2(ix, iy, s)
	return mathx.fract(sin(ix * 127.1 + iy * 311.7 + s * 19.19) * 43758.5453)
end

-- Unit vector and length. Degenerate input becomes (1, 0).
function mathx.norm(x, y)
	local len = sqrt(x * x + y * y)
	if len < 1e-6 then
		return 1, 0, 0
	end
	return x / len, y / len, len
end

-- Unit tangent at station i of a polyline.
function mathx.tangent(pts, i)
	local a = pts[max(1, i - 1)]
	local b = pts[min(#pts, i + 1)]
	return mathx.norm(b.x - a.x, b.y - a.y)
end

-- Seamless value noise on a square period.
function mathx.tile_noise(x, y, period, s)
	local ix, iy = floor(x), floor(y)
	local fx, fy = x - ix, y - iy
	fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
	local x0, y0 = ix % period, iy % period
	local x1, y1 = (ix + 1) % period, (iy + 1) % period
	local h = mathx.hash2
	return mathx.lerp(mathx.lerp(h(x0, y0, s), h(x1, y0, s), fx), mathx.lerp(h(x0, y1, s), h(x1, y1, s), fx), fy)
end

return mathx

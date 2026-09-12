local mathx = require "lib.math"
local palette = require "draw.palette"

local obstacle = {}
local clamp, mix3, mix3r, TAU = mathx.clamp, mathx.mix3, mathx.mix3r, mathx.TAU
local LICHEN_PALE = { 0.62, 0.64, 0.50 }
local LICHEN_RUST = { 0.72, 0.50, 0.30 }

-- Moss affinity per bed. Peat beats stay green, bare bedrock
-- grows almost none.
local MOSS_BY_BED = { chalk = 0.30, peat = 0.70, gravel = 0.35, silt = 0.50, bedrock = 0.12 }

-- Lichen affinity per bed. Pale crusts favour chalk and bare rock.
local LICHEN_BY_BED = { chalk = 0.60, peat = 0.15, gravel = 0.30, silt = 0.15, bedrock = 0.45 }

-- Scatter n rocks across a t band and an across band.
-- Bank-attached rocks sit on the gravel lip; the rest hold mid-flow.
local function scatter(rng, list, n, t_lo, t_hi, a_lo, a_hi, r)
	for i = 1, n do
		list[#list + 1] = {
			t = t_lo + rng:random() * (t_hi - t_lo),
			across = a_lo + rng:random() * (a_hi - a_lo),
			r = r * (0.7 + rng:random() * 0.7),
			rot = rng:random() * math.pi,
			bank = a_lo < 0.2,
		}
	end
end

-- Jittered ring polygon in local space. Radius wobbles per
-- vertex so no clean ellipse rim survives.
local function ring(rng, r, n, squash, ox, oy, scale, xscale)
	local pts = {}
	for i = 1, n do
		local a = (i - 1) / n * TAU
		local rr = r * (0.78 + 0.4 * rng:random()) * (scale or 1)
		pts[#pts + 1] = (ox or 0) + math.cos(a) * rr * (xscale or 1)
		pts[#pts + 1] = (oy or 0) + math.sin(a) * rr * (squash or 0.72)
	end
	return pts
end

-- Seeded obstacle field for a river. Bed type sets how rocky the
-- beat is; river width scales the rock size. Silhouettes bake
-- here, so draw spends no tables per frame.
function obstacle.generate(seed, char)
	local spec = char.bed_type.obs or { rocks = 8, rock_r = 16 }
	local rng = love.math.newRandomGenerator(seed + 47)
	local k = char.water_half / 78
	local list = {}
	local bank = math.floor(spec.rocks * 0.35)
	scatter(rng, list, bank, 0.08, 0.92, 0.04, 0.14, spec.rock_r * 0.9 * k)
	scatter(rng, list, bank, 0.08, 0.92, 0.86, 0.96, spec.rock_r * 0.9 * k)
	scatter(rng, list, spec.rocks - 2 * bank, 0.08, 0.92, 0.24, 0.76, spec.rock_r * k)
	for i = 1, #list do
		local o = list[i]
		-- Wake length along t and half-width in across units, plus the
		-- shade a big rock casts for fish lying beneath it.
		o.wt = 0.05 + 0.10 * o.r / math.max(char.water_half, 10)
		o.dw = 0.06 + (o.r / math.max(char.water_half, 10)) * 1.4
		o.shade = o.bank and 0.5 or 0.35
		-- Dressing from the surrounds. Bed sets moss and lichen,
		-- bank stones and lush beats grow greener. Seeded per rock.
		local bed_id = char.bed_type and char.bed_type.id or "gravel"
		local lush = char.lush or 0.5
		o.moss = clamp((MOSS_BY_BED[bed_id] or 0.3) + (o.bank and 0.25 or 0) + lush * 0.3 - 0.15, 0, 1)
		o.lichen = clamp((LICHEN_BY_BED[bed_id] or 0.3) + (o.bank and 0.1 or 0) - lush * 0.15, 0, 1)
		o.tone = rng:random()
		o.ex = 0.75 + rng:random() * 0.5
		o.ey = 0.55 + rng:random() * 0.4
		-- Baked silhouette set. Base ring, shaded low lobe, lit top
		-- lobe, and a wet underlay. All share the jittered family
		-- so edges never show a clean curve.
		o.poly = ring(rng, o.r, 10, 0.72 * o.ey, 0, 0, 1, o.ex)
		o.poly_lo = ring(rng, o.r, 9, 0.66 * o.ey, o.r * 0.10, o.r * 0.12, 0.8, o.ex)
		o.poly_hi = ring(rng, o.r, 8, 0.60 * o.ey, -o.r * 0.12, -o.r * 0.14, 0.55, o.ex)
		o.poly_wet = ring(rng, o.r, 10, 0.72 * o.ey, 0, o.r * 0.05, 1.03, o.ex * 1.01)
		-- Moss flecks as small polys on the top half.
		o.moss_poly = {}
		local nm = 2 + math.floor(o.moss * 4)
		for m = 1, nm do
			local h = rng:random()
			o.moss_poly[m] = ring(rng, o.r * (0.10 + h * 0.14), 6, 0.6,
				(h - 0.5) * o.r * o.ex, -(0.05 + rng:random() * 0.35) * o.r * o.ey, 1, 1)
		end
		-- Grit pits and pale flecks, kept well inside the rim.
		o.grit = {}
		for g = 1, 5 do
			local h = rng:random()
			o.grit[g] = {
				dx = (h - 0.5) * o.r * 0.9 * o.ex,
				dy = (rng:random() - 0.5) * o.r * 0.6 * o.ey,
				rr = o.r * (0.03 + h * 0.05),
				light = h <= 0.45,
			}
		end
		-- Lichen crust dots, pale and rust.
		o.lich = {}
		local nl = 2 + math.floor(o.lichen * 3)
		for l = 1, nl do
			local h = rng:random()
			o.lich[l] = {
				dx = (h - 0.5) * o.r * 0.9 * o.ex,
				dy = (rng:random() - 0.6) * o.r * 0.6 * o.ey,
				rr = o.r * (0.05 + h * 0.07),
				rust = h > 0.6,
			}
		end
	end
	return list
end

-- One rock as stacked jittered polygons tinted by the local
-- gravel. Shade lobe sits low right, light lobe high left, moss
-- breaks across the top, lichen crusts the dry stone. Form:
-- cover = bed affinity plus bank and lush terms, emergent only.
local function draw_rock(o, s, char, emergent)
	local deep = char.water_deep
	if not emergent then
		local r, g, b = mix3r(mix3r(palette.STONE, char.gravel, 0.5), deep, 0.55)
		love.graphics.setColor(r, g, b, 0.85)
		love.graphics.polygon("fill", o.poly)
		return
	end
	local sr, sg, sb = mix3r(palette.STONE, char.gravel, 0.35 + o.tone * 0.35)
	love.graphics.setColor(deep[1], deep[2], deep[3], 0.35)
	love.graphics.polygon("fill", o.poly_wet)
	love.graphics.setColor(sr, sg, sb, 1)
	love.graphics.polygon("fill", o.poly)
	love.graphics.setColor(deep[1], deep[2], deep[3], 0.30)
	love.graphics.polygon("fill", o.poly_lo)
	love.graphics.setColor(1, 1, 1, 0.10)
	love.graphics.polygon("fill", o.poly_hi)
	for i = 1, #o.grit do
		local g = o.grit[i]
		if g.light then
			love.graphics.setColor(1, 1, 1, 0.12)
		else
			love.graphics.setColor(deep[1], deep[2], deep[3], 0.35)
		end
		love.graphics.ellipse("fill", g.dx, g.dy, g.rr, g.rr * 0.7)
	end
	local moss_a = o.moss * 0.7
	if moss_a > 0.05 then
		local mr, mg, mb = mix3r(palette.MOSS, char.bank, 0.35)
		love.graphics.setColor(mr, mg, mb, moss_a)
		for i = 1, #o.moss_poly do
			love.graphics.polygon("fill", o.moss_poly[i])
		end
	end
	if o.lichen > 0.2 then
		for i = 1, #o.lich do
			local l = o.lich[i]
			local c = l.rust and LICHEN_RUST or LICHEN_PALE
			love.graphics.setColor(c[1], c[2], c[3], 0.35 + o.lichen * 0.45)
			love.graphics.ellipse("fill", l.dx, l.dy, l.rr, l.rr * 0.7)
		end
	end
end

-- Draw an obstacle. Emergent pieces (poking above the water) are dry
-- and opaque; submerged ones are tinted toward the deep water.
function obstacle.draw(list, river)
	if not list then
		return
	end
	local char = river.char
	for i = 1, #list do
		local o = list[i]
		local s = river:sample(o.t, o.across)
		local emergent = s.depth < o.r * 0.85
		love.graphics.push()
		love.graphics.translate(s.x, s.y)
		love.graphics.rotate(o.rot)
		draw_rock(o, s, char, emergent)
		love.graphics.pop()
	end
end

return obstacle
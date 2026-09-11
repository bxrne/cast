local mathx = require "lib.math"
local palette = require "draw.palette"

local obstacle = {}
local clamp, mix3 = mathx.clamp, mathx.mix3

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

-- Seeded obstacle field for a river. Bed type sets how rocky the beat
-- is; river width scales the rock size.
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
	end
	return list
end

-- One rock as a cluster of wet-grey lobes, dry when emergent.
local function draw_rock(o, s, char, emergent)
	local base = mix3(palette.STONE, char.gravel, emergent and 0.4 or 0.7)
	love.graphics.setColor(base[1], base[2], base[3], emergent and 1 or 0.85)
	local lobe = 0.72
	for i = 1, 3 do
		local a = o.rot + i * 2.1
		local dx, dy = math.cos(a), math.sin(a)
		love.graphics.ellipse("fill", dx * o.r * 0.18, dy * o.r * 0.18, o.r * lobe, o.r * 0.6 * lobe)
		lobe = lobe * 0.72
	end
	if emergent then
		love.graphics.setColor(1, 1, 1, 0.08)
		love.graphics.ellipse("fill", -o.r * 0.12, -o.r * 0.22, o.r * 0.4, o.r * 0.2)
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
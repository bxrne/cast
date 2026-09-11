local mathx = require "lib.math"

local foam = {}
foam.__index = foam
local clamp = mathx.clamp

local CAP = 150
local EMIT_RATE = 12 -- flecks per second per unit of foam source
local DRIFT = 0.045 -- slowest drift on calm water, t units per second
local DRIFT_SPAN = 0.15 -- extra drift on brisk flows
local STEPS = 24 -- trace subdivisions along the wake
local SEGS = 8 -- trace segments, each with its own fade

-- Qualify an emergent rock as a foam source: current strength trips the
-- wake, and the rock face is big enough to tear the surface film.
local function qualify(river, o)
	local s = river:sample(o.t, o.across)
	if s.depth >= o.r * 0.85 then
		return nil
	end
	local base = river.flow and river.flow.base_speed or 1
	local rel = clamp(s.speed / math.max(base, 0.01), 0, 1)
	local q = clamp((rel - 0.30) / 0.55, 0, 1) * clamp(o.r / 16, 0.3, 1.6)
	if q <= 0.05 then
		return nil
	end
	return q
end

-- Rocks that foam right now.
local function sources(river)
	local list, out = river.obstacles, {}
	if not list then
		return out
	end
	for i = 1, #list do
		local o = list[i]
		local q = qualify(river, o)
		if q then
			out[#out + 1] = { o = o, q = q }
		end
	end
	return out
end

-- Streamwise foam trace behind a source rock. Each point follows the
-- live flow heading (eddies included), so the band is a real streamline
-- of the wake: it curves with the water, widens as the wake spreads,
-- and dissolves downstream. Drawn under the rocks.
local function draw_trace(river, o, q)
	local span = o.wt * 3.4
	local hw = river.char.water_half
	local top, bottom = {}, {}
	for i = 0, STEPS do
		local u = i / STEPS
		local s = river:sample_live(o.t + u * span, o.across)
		local width = o.dw * (0.42 + 1.05 * u * (1.0 - 0.42 * u))
		local px, py = -s.ty, s.tx
		local wx, wy = px * width * hw * 2, py * width * hw * 2
		top[i + 1] = { s.x + wx, s.y + wy }
		bottom[i + 1] = { s.x - wx, s.y - wy }
	end
	local per = STEPS / SEGS
	local flick = 0.78 + 0.22 * math.sin(river.time * 2.1 + o.t * 91.0)
	for k = 1, SEGS do
		local a0, a1 = (k - 1) * per, k * per
		local fade = (1 - k / SEGS) ^ 1.5
		local pts = {}
		for i = a0, a1 do
			pts[#pts + 1] = top[i + 1][1]
			pts[#pts + 1] = top[i + 1][2]
		end
		for i = a1, a0, -1 do
			pts[#pts + 1] = bottom[i + 1][1]
			pts[#pts + 1] = bottom[i + 1][2]
		end
		love.graphics.setColor(0.86, 0.90, 0.88, clamp(fade * flick * q * 0.16, 0, 0.55))
		love.graphics.polygon("fill", pts)
	end
end

-- True when a fleck sits on an emergent rock, where the film is broken.
local function over_rock(river, p)
	local list = river.obstacles
	if not list then
		return false
	end
	local rt_scale = river.len_inv * 1.3
	local ra_scale = 1 / math.max(river.char.water_half, 10)
	for i = 1, #list do
		local o = list[i]
		if o.r * 0.85 > river:sample(o.t, o.across).depth then
			local dt = (p.t - o.t) * rt_scale / o.r
			local da = (p.across - o.across) * ra_scale / o.r
			if dt * dt + da * da * 8 < 1 then
				return true
			end
		end
	end
	return false
end

function foam.new()
	return setmetatable({ parts = {}, emit = 0 }, foam)
end

function foam:reset()
	self.parts = {}
end

local function spawn(parts, srcs)
	local total = 0
	for i = 1, #srcs do
		total = total + srcs[i].q
	end
	local roll = love.math.random() * total
	local o
	for i = 1, #srcs do
		roll = roll - srcs[i].q
		if roll <= 0 then
			o = srcs[i].o
			break
		end
	end
	if not o then
		return
	end
	parts[#parts + 1] = {
		t = o.t + (love.math.random() - 0.5) * 0.015,
		across = o.across + (love.math.random() - 0.5) * 0.04,
		x = 0, y = 0,
		r = 1.4 + love.math.random() * 2.0,
		age = 0,
		life = 2.4 + love.math.random() * 2.6,
		seed = love.math.random() * 100,
	}
end

-- Advect flecks with the live current, then emit new ones. Flecks that
-- meet a rock face are broken up, so none ride over the stone.
function foam:update(dt, river)
	local parts = self.parts
	for i = #parts, 1, -1 do
		local p = parts[i]
		local s = river:sample_live(p.t, p.across)
		local rel = clamp(s.speed / math.max(river.flow.base_speed, 0.01), 0, 1)
		p.t = p.t + (DRIFT + rel * DRIFT_SPAN) * dt
		p.across = p.across + math.sin(river.time * (1.1 + p.seed) + p.seed * 9.0) * dt * 0.012
		p.x, p.y = s.x, s.y
		p.age = p.age + dt
		if p.age >= p.life or over_rock(river, p) then
			parts[i] = parts[#parts]
			parts[#parts] = nil
		end
	end
	local srcs = sources(river)
	self.emit = self.emit + dt
	if #parts < CAP then
		local budget = self.emit * EMIT_RATE
		while budget >= 1 and #parts < CAP do
			budget = budget - 1
			spawn(parts, srcs)
		end
		self.emit = budget
	end
end

-- Foam density near a world point, 0..1. Fish use it to stay out of
-- white water when sipping the film.
function foam:density(x, y)
	local n = 0
	for i = 1, #self.parts do
		local p = self.parts[i]
		local dx, dy = p.x - x, p.y - y
		if dx * dx + dy * dy < 26 * 26 then
			n = n + 1
		end
	end
	return math.min(1, n * 0.34)
end

-- Muted traces behind the sources, then a few drifting flecks brighten
-- the wake edges. Everything sits under the rocks.
function foam:draw(river)
	local srcs = sources(river)
	for i = 1, #srcs do
		draw_trace(river, srcs[i].o, math.min(1, srcs[i].q))
	end
	for i = 1, #self.parts do
		local p = self.parts[i]
		local u = p.age / p.life
		local r = p.r * (0.7 + 0.8 * u - 0.4 * u * u)
		local a = (1 - u) * 0.26 * math.min(1, u * 6)
		love.graphics.setColor(0.93, 0.95, 0.93, a)
		love.graphics.ellipse("fill", p.x, p.y, r, r * 0.62)
	end
end

return foam
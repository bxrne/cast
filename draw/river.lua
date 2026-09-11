local flow = require "draw.flow"
local palette = require "draw.palette"
local obstacle = require "draw.obstacle"
local foam = require "draw.foam"
local mathx = require "lib.math"
local gfx = require "lib.gfx"

local river = {}
river.__index = river

local SAMPLES, STREAKS, TILE, BANK_TILE = 96, 3, 256, 128
local ALONG, WET_LIP, WATER_INSET = 8, 8, 2.5
local lerp, clamp, mix3, hash2 = mathx.lerp, mathx.clamp, mathx.mix3, mathx.hash2
local tile_noise, tangent, TAU = mathx.tile_noise, mathx.tangent, mathx.TAU
local vert, strip = gfx.vert, gfx.strip

-- Repeating dirt/grass grain for the floodplain.
local function grain_tile(seed)
	return gfx.image(TILE, function(x, y)
		local n = 0.14 * tile_noise(x / 32, y / 32, 8, seed)
		    + 0.34 * tile_noise(x / 8, y / 8, 32, seed + 3)
		    + 0.30 * tile_noise(x / 4, y / 4, 64, seed + 7)
		    + 0.22 * tile_noise(x / 2, y / 2, 128, seed + 13)
		n = n + (hash2(x, y, seed + 11) - 0.5) * 0.14
		if hash2(x, y, seed + 23) > 0.982 then
			n = n * 0.70
		end
		return clamp(0.70 + 0.30 * n, 0.58, 1)
	end)
end

-- Streaky pebble grain for bank strips.
local function bank_tile(seed)
	return gfx.image(BANK_TILE, function(x, y)
		local n = 0.50 * tile_noise(x / 8, y / 16, 16, seed) + 0.30 * tile_noise(x / 16, y / 8, 8, seed + 5)
		n = n + (hash2(x, y, seed + 11) - 0.5) * 0.16
		if hash2(x, y, seed + 29) > 0.96 then
			n = n * 0.55
		elseif hash2(x, y, seed + 31) > 0.93 then
			n = n * 0.78
		end
		return clamp(0.55 + 0.45 * n, 0.40, 1)
	end)
end

-- Scatter n ellipses with a color factory.
local function scatter(rng, n, w, h, rx, ry, color, alpha)
	for _ = 1, n do
		gfx.ellipse(
			rng:random() * w, rng:random() * h,
			rx[1] + rng:random() * rx[2], ry[1] + rng:random() * ry[2],
			rng:random() * TAU, color(rng), alpha[1] + rng:random() * alpha[2]
		)
	end
end

-- Bake floodplain grain plus clutter into a canvas.
local function ground_canvas(seed, width, height, char)
	local grain = grain_tile(seed)
	local quad = love.graphics.newQuad(0, 0, width, height, TILE, TILE)
	local canvas = love.graphics.newCanvas(width, height)
	local rng = love.math.newRandomGenerator(seed + 91)
	canvas:renderTo(function()
		love.graphics.setColor(char.ground)
		love.graphics.draw(grain, quad, 0, 0)
		scatter(rng, 28, width, height, { 18, 34 }, { 10, 22 }, function(r)
			return mix3(char.ground, mix3(palette.PEAT_SOIL, palette.GRASS, r:random()),
				0.35 + r:random() * 0.4)
		end, { 0.18, 0.12 })
		scatter(rng, 140, width, height, { 3, 11 }, { 2, 7 }, function(r)
			return mix3(char.ground, mix3(palette.MOSS, palette.STONE, r:random()), 0.25 + r:random() * 0.5)
		end, { 0.22, 0.20 })
		scatter(rng, 55, width, height, { 1.2, 3.2 }, { 0.9, 2.2 }, function()
			return palette.STONE
		end, { 0.28, 0.25 })
		love.graphics.setColor(1, 1, 1, 1)
	end)
	grain:release()
	return canvas
end

-- Pick a size band so creeks stay rare.
local function river_size(rng)
	local roll = rng:random()
	if roll < 0.28 then
		return 0.28 + rng:random() * 0.18
	end
	if roll < 0.78 then
		return 0.48 + rng:random() * 0.28
	end
	return 0.78 + rng:random() * 0.22
end

-- Seeded channel proportions, bed type, and colours.
local function character(seed, width, height)
	local rng = love.math.newRandomGenerator(seed)
	local size, lush, energy = river_size(rng), rng:random(), rng:random()
	local bed = palette.bed_at(rng:random())
	local span = math.min(width, height)
	local char = palette.make(bed, lush)
	char.bed_type = bed
	char.water_half = lerp(78, span * 0.30, size)
	char.bank_extra = lerp(34, 96, 0.45 * size + 0.55 * lush)
	char.meander = lerp(span * 0.035, span * 0.12, energy) * (1.0 - 0.45 * size)
	char.flow_speed = lerp(0.45, 1.55, energy)
	char.p1, char.p2, char.p3 = rng:random() * TAU, rng:random() * TAU, rng:random() * TAU
	return char
end

-- Bottom-left to top-right centerline with meander.
local function centerline(char, width, height)
	local x0, y0, x1, y1 = -20, height + 8, width + 20, -8
	local dx, dy = mathx.norm(x1 - x0, y1 - y0)
	local px, py, pts = -dy, dx, {}
	for i = 0, SAMPLES do
		local t = i / SAMPLES
		local wobble = math.sin(t * 2.15 * math.pi + char.p1) * char.meander
		    + math.sin(t * 5.05 * math.pi + char.p2) * char.meander * 0.32
		    + math.sin(t * 9.4 * math.pi + char.p3) * char.meander * 0.10
		pts[#pts + 1] = {
			t = t,
			x = lerp(x0, x1, t) + px * wobble,
			y = lerp(y0, y1, t) + py * wobble,
			hw = char.water_half * (1 + 0.10 * math.sin(t * 4.6 * math.pi + char.p2)),
		}
	end
	return pts
end

-- Irregular bank width along the river.
local function ragged(t, base, pa, pb)
	local n = 0.70 + 0.22 * math.sin(t * 13 * math.pi + pa) + 0.14 * math.sin(t * 29 * math.pi + pb) +
	    0.08 * math.sin(t * 47 * math.pi + pa * 0.7)
	return math.max(18, base * n)
end

-- Water vertex tinted by depth. Alpha carries normalised depth for the shader.
local function water_vert(p, px, py, across, char, field)
	local st = field.stations[p.i]
	local depth = flow.depth(st, across)
	local depth_n = clamp(depth / 36, 0, 1)
	local spd = flow.speed(field, st, across)
	local color = mix3(char.water_mid, char.water_deep, depth_n)
	local hw = p.hw - WATER_INSET
	local v = vert(p.x + px * hw * (across * 2 - 1), p.y + py * hw * (across * 2 - 1), p.t * ALONG, across, color,
		depth_n)
	v.speed = spd
	return v
end

-- Bank, wet lip, and water rails at every station.
local function rails(pts, char, field)
	local bank_lo, bank_li, bank_ri, bank_ro = {}, {}, {}, {}
	local wet_li, wet_lo, wet_ri, wet_ro = {}, {}, {}, {}
	local water_l, water_r = {}, {}
	for i = 1, #pts do
		local p = pts[i]
		p.i = i
		local tx, ty = tangent(pts, i)
		local px, py = -ty, tx
		local lip = WET_LIP * (0.85 + 0.25 * math.sin(p.t * 11 * math.pi + char.p2))
		local wet_in, wet_out = p.hw - WATER_INSET, p.hw + lip
		local left = p.hw + ragged(p.t, char.bank_extra, char.p1, char.p3)
		local right = p.hw + ragged(p.t, char.bank_extra, char.p2, char.p1)
		local shade = 0.82 + 0.18 * math.sin(p.t * 19 * math.pi + char.p3)
		local inner, outer = mix3(char.gravel, char.wet, 0.35 + 0.25 * shade),
		    mix3(char.bank, char.gravel, 0.15 * (1 - shade))
		local uv = p.t * 10
		bank_li[i] = vert(p.x - px * wet_out, p.y - py * wet_out, uv, 0, inner)
		bank_lo[i] = vert(p.x - px * left, p.y - py * left, uv, 1, outer)
		bank_ri[i] = vert(p.x + px * wet_out, p.y + py * wet_out, uv, 0, inner)
		bank_ro[i] = vert(p.x + px * right, p.y + py * right, uv, 1, outer)
		wet_li[i] = vert(p.x - px * wet_in, p.y - py * wet_in, uv, 0, char.wet)
		wet_lo[i] = vert(p.x - px * wet_out, p.y - py * wet_out, uv, 1, inner)
		wet_ri[i] = vert(p.x + px * wet_in, p.y + py * wet_in, uv, 0, char.wet)
		wet_ro[i] = vert(p.x + px * wet_out, p.y + py * wet_out, uv, 1, inner)
		water_l[i] = water_vert(p, px, py, 0, char, field)
		water_r[i] = water_vert(p, px, py, 1, char, field)
	end
	return {
		bank_lo = bank_lo,
		bank_li = bank_li,
		bank_ri = bank_ri,
		bank_ro = bank_ro,
		wet_li = wet_li,
		wet_lo = wet_lo,
		wet_ri = wet_ri,
		wet_ro = wet_ro,
		water_l = water_l,
		water_r = water_r,
	}
end

-- Short current streaks that stay inside the water strip.
local function draw_streaks(channel, time, speed)
	local left, right = channel.water_l, channel.water_r
	love.graphics.setLineWidth(1)
	for s = 1, STREAKS do
		local across, phase, pts = s / (STREAKS + 1), (time * speed * 0.10 + s * 0.23) % 1, {}
		love.graphics.setColor(0.72, 0.78, 0.72, 0.06 + (s % 2) * 0.03)
		for i = 1, #left do
			local along = (left[i].u / ALONG + phase * (0.7 + 0.3 * ((left[i].speed or speed) / math.max(speed, 0.1)))) %
			    1
			if along < 0.18 then
				pts[#pts + 1] = lerp(left[i].x, right[i].x, across)
				pts[#pts + 1] = lerp(left[i].y, right[i].y, across)
			else
				gfx.line(pts)
				pts = {}
			end
		end
		gfx.line(pts)
	end
end

-- Create a river scene for this window.
function river.new(opts)
	opts = opts or {}
	local self = setmetatable({
		seed = opts.seed or 1,
		width = opts.width or love.graphics.getWidth(),
		height = opts.height or love.graphics.getHeight(),
		time = 0,
		show_flow = false,
		shader = gfx.shader("draw/water.glsl"),
		foam = foam.new(),
	}, river)
	self:rebuild()
	return self
end

-- Rebuild meshes from the current seed and size.
function river:rebuild()
	gfx.release_all(self.bank_l, self.bank_r, self.wet_l, self.wet_r, self.water, self.ground, self.bank_tex)
	local char = character(self.seed, self.width, self.height)
	local pts = centerline(char, self.width, self.height)
	self.obstacles = obstacle.generate(self.seed, char)
	local field = flow.build(pts, char.flow_speed, char.bed_type, self.seed, self.obstacles)
	local channel = rails(pts, char, field)
	self.char, self.flow, self.channel = char, field, channel
	local x0, y0, x1, y1 = pts[1].x, pts[1].y, pts[#pts].x, pts[#pts].y
	self.len_inv = 1 / math.max(1, math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2))
	self.foam:reset()
	self.ground = ground_canvas(self.seed, self.width, self.height, char)
	self.bank_tex = bank_tile(self.seed)
	self.bank_l = strip(channel.bank_lo, channel.bank_li)
	self.bank_r = strip(channel.bank_ri, channel.bank_ro)
	self.wet_l = strip(channel.wet_lo, channel.wet_li)
	self.wet_r = strip(channel.wet_ri, channel.wet_ro)
	self.water = strip(channel.water_l, channel.water_r)
	self.bank_l:setTexture(self.bank_tex)
	self.bank_r:setTexture(self.bank_tex)
	self.wet_l:setTexture(self.bank_tex)
	self.wet_r:setTexture(self.bank_tex)
end

-- Replace the seed and rebuild.
function river:reseed(seed)
	self.seed = seed
	self:rebuild()
end

-- Fit the river to a new window size.
function river:resize(width, height)
	self.width, self.height = width, height
	self:rebuild()
end

-- Advance water animation and drift the foam.
function river:update(dt)
	self.time = self.time + dt
	self.foam:update(dt, self)
end

-- Sample flow at parametric (t, across). Geometry only, used by
-- habitat scoring and the shore pose.
function river:sample(t, across)
	return flow.sample(self.flow, t, across)
end

-- Animated sample for entities: heading and speed pick up the eddies.
function river:sample_live(t, across)
	return flow.sample(self.flow, t, across, self.time)
end

-- Lie quality at a flow sample.
function river:lie_score(sample)
	return flow.lie_score(sample)
end

-- Draw velocity arrows for the debug overlay. Lives on top of the
-- eddy field and adds a light noise wobble so the indicators move.
function river:draw_flow()
	local n_t, n_a = 22, 7
	love.graphics.setLineWidth(1.5)
	for i = 1, n_t do
		local t = (i - 0.5) / n_t
		for j = 1, n_a do
			local across = (j - 0.5) / n_a
			local s = flow.sample(self.flow, t, across, self.time)
			local nse = 0.10 * math.sin(self.time * 2.6 + t * 41 + across * 29)
			    + 0.07 * math.sin(self.time * 4.1 + t * 83 + across * 57)
			local k = s.speed / self.flow.base_speed
			love.graphics.setColor(0.2 + k * 0.6, 0.55, 0.85 - k * 0.4, 0.75)
			local tip = 10 + (s.speed + nse * 4) * 14
			local c, sn = math.cos(nse), math.sin(nse)
			local ex, ey = s.tx * c - s.ty * sn, s.tx * sn + s.ty * c
			love.graphics.line(s.x, s.y, s.x + ex * tip, s.y + ey * tip)
		end
	end
end

-- Draw ground, banks, water, and optional flow overlay.
function river:draw()
	local char = self.char
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(self.ground)
	love.graphics.draw(self.bank_l)
	love.graphics.draw(self.bank_r)
	self.shader:send("time", self.time)
	self.shader:send("speed", char.flow_speed)
	self.shader:send("bed_color", char.bed)
	self.shader:send("spot_color", char.spot)
	love.graphics.setShader(self.shader)
	love.graphics.draw(self.water)
	love.graphics.setShader()
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(self.wet_l)
	love.graphics.draw(self.wet_r)
	-- Foam first so rocks always sit on top of the film.
	self.foam:draw(self)
	obstacle.draw(self.obstacles, self)
	draw_streaks(self.channel, self.time, char.flow_speed)
	if self.show_flow then
		self:draw_flow()
	end
end

return river

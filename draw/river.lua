local river = {}
river.__index = river

local SAMPLES = 96
local STREAKS = 3
local TILE = 256
local BANK_TILE = 128
local ALONG = 8
local WET_LIP = 8
local CLUTTER_SMALL = 140
local CLUTTER_MED = 28
local CLUTTER_STONE = 55
local TAU = math.pi * 2

local STONE = { 0.36, 0.34, 0.28 }
local MOSS = { 0.27, 0.36, 0.16 }
local PEAT_SOIL = { 0.18, 0.16, 0.10 }
local GRASS = { 0.24, 0.30, 0.14 }
local WET_CLEAR = { 0.16, 0.15, 0.12 }
local WET_PEAT = { 0.12, 0.14, 0.10 }
local GRAVEL_CLEAR = { 0.32, 0.30, 0.24 }
local GRAVEL_PEAT = { 0.22, 0.20, 0.16 }
local WATER_DEEP_CLEAR = { 0.10, 0.20, 0.18 }
local WATER_DEEP_PEAT = { 0.06, 0.10, 0.08 }
local WATER_MID_CLEAR = { 0.18, 0.32, 0.26 }
local WATER_MID_PEAT = { 0.12, 0.18, 0.14 }
local FOAM_CLEAR = { 0.58, 0.62, 0.56 }
local FOAM_PEAT = { 0.48, 0.46, 0.38 }

local WATER = [[
extern number time;
extern number speed;
extern vec3 foam;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
	float along = uv.x;
	float across = uv.y;
	vec2 flow = vec2(along * 7.0 - time * speed, across * 11.0);
	float n1 = noise(flow);
	float n2 = noise(flow * 2.3 + vec2(1.7, time * 0.08));
	vec3 c = color.rgb * (0.90 + 0.10 * n1);
	c += pow(clamp(n2, 0.0, 1.0), 9.0) * 0.14;
	float edge = smoothstep(0.0, 0.11, across) * smoothstep(0.0, 0.11, 1.0 - across);
	c = mix(foam, c, edge);
	return vec4(c, 1.0);
}
]]

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function mix3(a, b, t)
	return { lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t) }
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
		return 1, 0
	end
	return x / len, y / len
end

local function release(obj)
	if obj then
		obj:release()
	end
end

local function fract(x)
	return x - math.floor(x)
end

local function hash(ix, iy, s)
	return fract(math.sin(ix * 127.1 + iy * 311.7 + s * 19.19) * 43758.5453)
end

local function tile_noise(x, y, period, s)
	local ix = math.floor(x)
	local iy = math.floor(y)
	local fx = x - ix
	local fy = y - iy
	fx = fx * fx * (3 - 2 * fx)
	fy = fy * fy * (3 - 2 * fy)
	local x0, y0 = ix % period, iy % period
	local x1, y1 = (ix + 1) % period, (iy + 1) % period
	return lerp(
		lerp(hash(x0, y0, s), hash(x1, y0, s), fx),
		lerp(hash(x0, y1, s), hash(x1, y1, s), fx),
		fy
	)
end

local function make_image(size, fn)
	local data = love.image.newImageData(size, size)
	for y = 0, size - 1 do
		for x = 0, size - 1 do
			local n = fn(x, y)
			data:setPixel(x, y, n, n, n, 1)
		end
	end
	local img = love.graphics.newImage(data)
	img:setWrap("repeat", "repeat")
	img:setFilter("linear", "linear")
	return img
end

local function grain_tile(seed)
	return make_image(TILE, function(x, y)
		local n = 0.14 * tile_noise(x / 32, y / 32, 8, seed)
			+ 0.34 * tile_noise(x / 8, y / 8, 32, seed + 3)
			+ 0.30 * tile_noise(x / 4, y / 4, 64, seed + 7)
			+ 0.22 * tile_noise(x / 2, y / 2, 128, seed + 13)
		n = n + (hash(x, y, seed + 11) - 0.5) * 0.14
		if hash(x, y, seed + 23) > 0.982 then
			n = n * 0.70
		end
		return clamp(0.70 + 0.30 * n, 0.58, 1)
	end)
end

local function bank_tile(seed)
	return make_image(BANK_TILE, function(x, y)
		local along = tile_noise(x / 8, y / 16, 16, seed)
		local across = tile_noise(x / 16, y / 8, 8, seed + 5)
		local n = 0.50 * along + 0.30 * across
		n = n + (hash(x, y, seed + 11) - 0.5) * 0.16
		if hash(x, y, seed + 29) > 0.96 then
			n = n * 0.55
		elseif hash(x, y, seed + 31) > 0.93 then
			n = n * 0.78
		end
		return clamp(0.55 + 0.45 * n, 0.40, 1)
	end)
end

local function ellipse(x, y, rx, ry, rot, rgb, alpha)
	love.graphics.setColor(rgb[1], rgb[2], rgb[3], alpha)
	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.rotate(rot)
	love.graphics.ellipse("fill", 0, 0, rx, ry)
	love.graphics.pop()
end

local function ground_canvas(seed, width, height, char)
	local grain = grain_tile(seed)
	local quad = love.graphics.newQuad(0, 0, width, height, TILE, TILE)
	local canvas = love.graphics.newCanvas(width, height)
	local rng = love.math.newRandomGenerator(seed + 91)
	canvas:renderTo(function()
		love.graphics.setColor(char.ground)
		love.graphics.draw(grain, quad, 0, 0)
		for _ = 1, CLUTTER_MED do
			local shade = mix3(char.ground, mix3(PEAT_SOIL, GRASS, rng:random()), 0.35 + rng:random() * 0.4)
			ellipse(
				rng:random() * width,
				rng:random() * height,
				18 + rng:random() * 34,
				10 + rng:random() * 22,
				rng:random() * TAU,
				shade,
				0.18 + rng:random() * 0.12
			)
		end
		for _ = 1, CLUTTER_SMALL do
			local shade = mix3(char.ground, mix3(MOSS, STONE, rng:random()), 0.25 + rng:random() * 0.5)
			ellipse(
				rng:random() * width,
				rng:random() * height,
				3 + rng:random() * 11,
				2 + rng:random() * 7,
				rng:random() * TAU,
				shade,
				0.22 + rng:random() * 0.20
			)
		end
		for _ = 1, CLUTTER_STONE do
			ellipse(
				rng:random() * width,
				rng:random() * height,
				1.2 + rng:random() * 3.2,
				0.9 + rng:random() * 2.2,
				rng:random() * TAU,
				STONE,
				0.28 + rng:random() * 0.25
			)
		end
		love.graphics.setColor(1, 1, 1, 1)
	end)
	grain:release()
	return canvas
end

local function vert(x, y, u, v, rgb)
	return { x = x, y = y, u = u, v = v, r = rgb[1], g = rgb[2], b = rgb[3] }
end

local function strip(left, right)
	local verts = {}
	for i = 1, #left do
		local l, r = left[i], right[i]
		verts[#verts + 1] = { l.x, l.y, l.u, l.v, l.r, l.g, l.b, 1 }
		verts[#verts + 1] = { r.x, r.y, r.u, r.v, r.r, r.g, r.b, 1 }
	end
	return love.graphics.newMesh(verts, "strip", "static")
end

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

local function palette(peat, lush)
	return {
		ground = mix3(mix3(STONE, GRASS, lush), PEAT_SOIL, peat * 0.55),
		bank = mix3(mix3(STONE, MOSS, lush), mix3(PEAT_SOIL, MOSS, 0.35), peat * 0.45),
		wet = mix3(WET_CLEAR, WET_PEAT, peat),
		gravel = mix3(GRAVEL_CLEAR, GRAVEL_PEAT, peat),
		water_deep = mix3(WATER_DEEP_CLEAR, WATER_DEEP_PEAT, peat),
		water_mid = mix3(WATER_MID_CLEAR, WATER_MID_PEAT, peat),
		foam = mix3(FOAM_CLEAR, FOAM_PEAT, peat),
	}
end

local function character(seed, width, height)
	local rng = love.math.newRandomGenerator(seed)
	local size = river_size(rng)
	local peat = rng:random()
	local lush = rng:random()
	local energy = rng:random()
	local span = math.min(width, height)
	local colors = palette(peat, lush)
	return {
		water_half = lerp(78, span * 0.30, size),
		bank_extra = lerp(34, 96, 0.45 * size + 0.55 * lush),
		meander = lerp(span * 0.035, span * 0.12, energy) * (1.0 - 0.45 * size),
		flow_speed = lerp(0.45, 1.55, energy),
		p1 = rng:random() * TAU,
		p2 = rng:random() * TAU,
		p3 = rng:random() * TAU,
		ground = colors.ground,
		bank = colors.bank,
		wet = colors.wet,
		gravel = colors.gravel,
		water_deep = colors.water_deep,
		water_mid = colors.water_mid,
		foam = colors.foam,
	}
end

local function centerline(char, width, height)
	local x0, y0 = -20, height + 8
	local x1, y1 = width + 20, -8
	local dx, dy = norm(x1 - x0, y1 - y0)
	local px, py = -dy, dx
	local pts = {}
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

local function tangent(pts, i)
	local prev = pts[math.max(1, i - 1)]
	local nxt = pts[math.min(#pts, i + 1)]
	return norm(nxt.x - prev.x, nxt.y - prev.y)
end

local function ragged(t, base, pa, pb)
	local n = 0.70
		+ 0.22 * math.sin(t * 13.0 * math.pi + pa)
		+ 0.14 * math.sin(t * 29.0 * math.pi + pb)
		+ 0.08 * math.sin(t * 47.0 * math.pi + pa * 0.7)
	return math.max(18, base * n)
end

local function water_vert(p, px, py, across, char)
	local thalweg = 0.5 + 0.08 * math.sin(p.t * 4.1 + char.p1)
	local depth = 1 - math.min(1, (across - thalweg) ^ 2 * 5.2)
	local color = mix3(char.water_mid, char.water_deep, depth)
	local dist = p.hw * (across * 2 - 1)
	return vert(p.x + px * dist, p.y + py * dist, p.t * ALONG, across, color)
end

local function bank_vert(x, y, t, across, rgb)
	return vert(x, y, t * 10, across, rgb)
end

local function rails(pts, char)
	local bank_lo, bank_li = {}, {}
	local bank_ri, bank_ro = {}, {}
	local wet_l, wet_r = {}, {}
	local water_l, water_r = {}, {}

	for i = 1, #pts do
		local p = pts[i]
		local tx, ty = tangent(pts, i)
		local px, py = -ty, tx
		local wet = p.hw + WET_LIP * (0.85 + 0.25 * math.sin(p.t * 11 * math.pi + char.p2))
		local left = p.hw + ragged(p.t, char.bank_extra, char.p1, char.p3)
		local right = p.hw + ragged(p.t, char.bank_extra, char.p2, char.p1)
		local along = p.t * ALONG
		local shade = 0.82 + 0.18 * math.sin(p.t * 19 * math.pi + char.p3)
		local inner = mix3(char.gravel, char.wet, 0.35 + 0.25 * shade)
		local outer = mix3(char.bank, char.gravel, 0.15 * (1 - shade))

		bank_li[i] = bank_vert(p.x - px * wet, p.y - py * wet, p.t, 0, inner)
		bank_lo[i] = bank_vert(p.x - px * left, p.y - py * left, p.t, 1, outer)
		bank_ri[i] = bank_vert(p.x + px * wet, p.y + py * wet, p.t, 0, inner)
		bank_ro[i] = bank_vert(p.x + px * right, p.y + py * right, p.t, 1, outer)
		wet_l[i] = vert(p.x - px * wet, p.y - py * wet, along, 0, char.wet)
		wet_r[i] = vert(p.x + px * wet, p.y + py * wet, along, 1, char.wet)
		water_l[i] = water_vert(p, px, py, 0, char)
		water_r[i] = water_vert(p, px, py, 1, char)
	end

	return {
		bank_lo = bank_lo,
		bank_li = bank_li,
		bank_ri = bank_ri,
		bank_ro = bank_ro,
		wet_l = wet_l,
		wet_r = wet_r,
		water_l = water_l,
		water_r = water_r,
	}
end

local function flush_line(pts)
	if #pts >= 4 then
		love.graphics.line(pts)
	end
end

local function draw_streaks(channel, time, speed)
	local left, right = channel.water_l, channel.water_r
	local n = #left
	love.graphics.setLineWidth(1.1)
	for s = 1, STREAKS do
		local across = s / (STREAKS + 1)
		local phase = (time * speed * 0.12 + s * 0.2) % 1
		love.graphics.setColor(0.72, 0.78, 0.72, 0.10 + (s % 2) * 0.04)
		local pts = {}
		for i = 1, n do
			local along = (left[i].u / ALONG + phase) % 1
			if along < 0.48 then
				pts[#pts + 1] = lerp(left[i].x, right[i].x, across)
				pts[#pts + 1] = lerp(left[i].y, right[i].y, across)
			else
				flush_line(pts)
				pts = {}
			end
		end
		flush_line(pts)
	end
end

function river.new(opts)
	opts = opts or {}
	local self = setmetatable({
		seed = opts.seed or 1,
		width = opts.width or love.graphics.getWidth(),
		height = opts.height or love.graphics.getHeight(),
		time = 0,
		shader = love.graphics.newShader(WATER),
	}, river)
	self:rebuild()
	return self
end

function river:rebuild()
	release(self.bank_l)
	release(self.bank_r)
	release(self.wet)
	release(self.water)
	release(self.ground)
	release(self.bank_tex)

	local char = character(self.seed, self.width, self.height)
	local channel = rails(centerline(char, self.width, self.height), char)
	local bank_tex = bank_tile(self.seed)

	self.char = char
	self.channel = channel
	self.ground = ground_canvas(self.seed, self.width, self.height, char)
	self.bank_tex = bank_tex
	self.bank_l = strip(channel.bank_lo, channel.bank_li)
	self.bank_r = strip(channel.bank_ri, channel.bank_ro)
	self.wet = strip(channel.wet_l, channel.wet_r)
	self.water = strip(channel.water_l, channel.water_r)
	self.bank_l:setTexture(bank_tex)
	self.bank_r:setTexture(bank_tex)
end

function river:reseed(seed)
	self.seed = seed
	self:rebuild()
end

function river:resize(width, height)
	self.width = width
	self.height = height
	self:rebuild()
end

function river:update(dt)
	self.time = self.time + dt
end

function river:draw()
	local char = self.char
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(self.ground)
	love.graphics.draw(self.bank_l)
	love.graphics.draw(self.bank_r)
	love.graphics.draw(self.wet)

	self.shader:send("time", self.time)
	self.shader:send("speed", char.flow_speed)
	self.shader:send("foam", char.foam)
	love.graphics.setShader(self.shader)
	love.graphics.draw(self.water)
	love.graphics.setShader()

	draw_streaks(self.channel, self.time, char.flow_speed)
end

return river

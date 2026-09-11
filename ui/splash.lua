local splash = {}
splash.__index = splash

local STEP_GAP = 0.7 -- seconds per load step

-- Twelve working trout patterns. kind sets the body plan and
-- how the fly sits: dry rides high, wet and nymph hang low.
local FLIES = {
	{ name = "adams", kind = "dry", s = 1.0, body = { 0.42, 0.40, 0.36 }, wing = { 0.82, 0.82, 0.78 } },
	{ name = "blue winged olive", kind = "dry", s = 0.85, body = { 0.45, 0.46, 0.24 }, wing = { 0.70, 0.74, 0.72 } },
	{ name = "elk hair caddis", kind = "dry", s = 0.95, body = { 0.55, 0.40, 0.22 }, wing = { 0.72, 0.58, 0.36 } },
	{ name = "royal wulff", kind = "dry", s = 1.05, body = { 0.62, 0.20, 0.14 }, wing = { 0.88, 0.86, 0.76 } },
	{ name = "griffiths gnat", kind = "dry", s = 0.6, body = { 0.25, 0.25, 0.26 }, wing = { 0.75, 0.78, 0.80 } },
	{ name = "stimulator", kind = "dry", s = 1.2, body = { 0.66, 0.42, 0.16 }, wing = { 0.78, 0.64, 0.42 } },
	{ name = "partridge and orange", kind = "wet", s = 0.9, body = { 0.68, 0.42, 0.18 }, wing = { 0.45, 0.38, 0.28 } },
	{ name = "leadwing coachman", kind = "wet", s = 0.95, body = { 0.60, 0.48, 0.20 }, wing = { 0.35, 0.36, 0.38 } },
	{ name = "pheasant tail", kind = "nymph", s = 0.9, body = { 0.48, 0.36, 0.20 }, wing = { 0.30, 0.24, 0.14 } },
	{ name = "hares ear", kind = "nymph", s = 1.0, body = { 0.55, 0.48, 0.32 }, wing = { 0.35, 0.30, 0.20 } },
	{ name = "copper john", kind = "nymph", s = 0.85, body = { 0.62, 0.32, 0.14 }, wing = { 0.80, 0.70, 0.40 } },
	{ name = "woolly bugger", kind = "streamer", s = 1.5, body = { 0.30, 0.32, 0.22 }, wing = { 0.55, 0.58, 0.40 } },
}

-- Dry fly. Upright divided wings, hackle collar, ribbed body.
local function dry_fly(f, s)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.55, 0.48, 0.34, 1)
	love.graphics.line(-22 * s, -4 * s, -13 * s, 0)
	love.graphics.line(-23 * s, 0, -13 * s, 0)
	love.graphics.line(-22 * s, 4 * s, -13 * s, 0)
	love.graphics.setColor(0.15, 0.14, 0.12, 1)
	love.graphics.line(-13 * s, -5 * s, 12 * s, -5 * s)
	love.graphics.circle("line", 14 * s, -6 * s, 2 * s, 8)
	love.graphics.setColor(f.body[1], f.body[2], f.body[3], 1)
	love.graphics.ellipse("fill", -4 * s, -5 * s, 9 * s, 4.6 * s, 0, 10)
	love.graphics.ellipse("fill", 4 * s, -5 * s, 6.5 * s, 4.0 * s, 0, 10)
	love.graphics.setColor(0.88, 0.85, 0.72, 1)
	for i = -2, 2 do
		love.graphics.line(9 * s + i * 2.4 * s, -4 * s, 9 * s + i * 3.4 * s, -14 * s - (i == 0 and 2 or 0))
	end
	love.graphics.setColor(f.wing[1], f.wing[2], f.wing[3], 0.92)
	love.graphics.ellipse("fill", 5 * s, -20 * s, 4.6 * s, 10 * s, -0.25, 10)
	love.graphics.ellipse("fill", 12 * s, -20 * s, 4.6 * s, 10 * s, 0.25, 10)
	love.graphics.setLineWidth(1)
end

-- Nymph. Slim ribbed abdomen, bead head, breathing tail.
local function nymph_fly(f, s)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.60, 0.52, 0.36, 1)
	love.graphics.line(-20 * s, -3 * s, -13 * s, 0)
	love.graphics.line(-20 * s, 3 * s, -13 * s, 0)
	love.graphics.setColor(f.body[1], f.body[2], f.body[3], 1)
	love.graphics.ellipse("fill", -5 * s, 0, 11 * s, 4.2 * s, 0, 12)
	love.graphics.setColor(f.wing[1], f.wing[2], f.wing[3], 1)
	love.graphics.line(-11 * s, -4 * s, -11 * s, 4 * s)
	love.graphics.line(-5 * s, -4.2 * s, -5 * s, 4.2 * s)
	love.graphics.line(1 * s, -4 * s, 1 * s, 4 * s)
	love.graphics.setColor(0.80, 0.62, 0.25, 1)
	love.graphics.circle("fill", 8 * s, 0, 4.4 * s, 12)
	love.graphics.setColor(1, 1, 1, 0.25)
	love.graphics.circle("fill", 6.6 * s, -1.4 * s, 1.4 * s, 8)
	love.graphics.setLineWidth(1)
end

-- Wet fly. Wings swept back along the body, soft hackle beard.
local function wet_fly(f, s)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(f.wing[1], f.wing[2], f.wing[3], 0.95)
	love.graphics.ellipse("fill", -2 * s, -2 * s, 13 * s, 4.4 * s, -0.35, 12)
	love.graphics.ellipse("fill", -2 * s, 2 * s, 13 * s, 4.4 * s, 0.35, 12)
	love.graphics.setColor(f.body[1], f.body[2], f.body[3], 1)
	love.graphics.ellipse("fill", 0, 0, 12 * s, 4.2 * s, 0, 12)
	love.graphics.setColor(0.88, 0.85, 0.72, 1)
	for i = -1, 1 do
		love.graphics.line(8 * s, -2 * s + i * 2 * s, 3 * s, -8 * s + i * 2 * s)
	end
	love.graphics.setColor(0.15, 0.14, 0.12, 1)
	love.graphics.line(-12 * s, 0, 13 * s, 0)
	love.graphics.setLineWidth(1)
end

-- Streamer. Long baitfish body, tail fin, gill flash, eye.
local function streamer_fly(f, s)
	love.graphics.setColor(f.body[1], f.body[2], f.body[3], 1)
	love.graphics.polygon("fill", -30 * s, 0, -22 * s, -8 * s, -22 * s, 8 * s)
	love.graphics.ellipse("fill", -4 * s, 0, 20 * s, 6.5 * s, 0, 14)
	love.graphics.setColor(f.wing[1], f.wing[2], f.wing[3], 0.9)
	love.graphics.ellipse("fill", -4 * s, -1 * s, 16 * s, 3.4 * s, 0, 12)
	love.graphics.setColor(0.75, 0.30, 0.22, 1)
	love.graphics.ellipse("fill", 8 * s, 0, 4 * s, 5 * s, 0, 10)
	love.graphics.setColor(0.10, 0.10, 0.10, 1)
	love.graphics.circle("fill", 12 * s, -1.5 * s, 1.8 * s, 8)
end

local PLANS = { dry = dry_fly, wet = wet_fly, nymph = nymph_fly, streamer = streamer_fly }

-- Scatter the wall. Dense jittered grid, seeded, with the
-- middle kept clear for the reel. Each pattern repeats.
local function lay_wall(w, h)
	local rng = love.math.newRandomGenerator(77)
	local spots, tries = {}, 0
	local cx, cy = w * 0.5, h * 0.56
	while #spots < #FLIES * 4 and tries < 1200 do
		tries = tries + 1
		local col = math.floor(rng:random() * 9)
		local row = math.floor(rng:random() * 7)
		local x = (col + 0.5) / 9 * w + (rng:random() - 0.5) * w * 0.07
		local y = (row + 0.5) / 7 * h + (rng:random() - 0.5) * h * 0.08
		local ex, ey = (x - cx) / (w * 0.24), (y - cy) / (h * 0.32)
		if ex * ex + ey * ey > 1 then
			local taken = false
			for i = 1, #spots do
				local dx, dy = spots[i].x - x, spots[i].y - y
				if dx * dx + dy * dy < (w * 0.055) ^ 2 then
					taken = true
					break
				end
			end
			if not taken then
				spots[#spots + 1] = { x = x, y = y, rot = rng:random() * 6.283 }
			end
		end
	end
	return spots
end

function splash.new()
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	return setmetatable({
		t = 0, step_t = 0, progress = 0, shown = 0,
		spin = 0, pulse = 0,
		wall = lay_wall(w, h),
		small = love.graphics.newFont(18),
	}, splash)
end

-- Advance clock, step timer, and reel spin. Shown progress eases
-- toward true progress, fast early then settling, so the count
-- reads logarithmic instead of steppy.
function splash:update(dt, w)
	self.t = self.t + dt
	self.step_t = self.step_t + dt
	self.pulse = math.max(0, self.pulse - dt * 1.2)
	self.spin = self.spin + dt * (2 + 10 * self.pulse)
	self.shown = self.shown + (self.progress - self.shown) * math.min(1, 1.6 * dt)
end

-- True when the next build step is due.
function splash:step_due()
	if self.step_t >= STEP_GAP then
		self.step_t = 0
		return true
	end
	return false
end

-- Kick the reel. The loader calls this per finished step.
function splash:mark_step()
	self.pulse = 1
end

-- Spinning fly reel. Cage ring, wound spool, handle arm at the
-- spin angle. Full rim ring only, no pie.
local function reel(self, x, y, r)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.55, 0.60, 0.58, 1)
	love.graphics.circle("line", x, y, r, 40)
	love.graphics.setColor(0.16, 0.20, 0.22, 1)
	love.graphics.circle("fill", x, y, r - 4, 36)
	love.graphics.setColor(0.75, 0.62, 0.30, 1)
	love.graphics.circle("line", x, y, r - 4, 36)
	love.graphics.setColor(0.42, 0.36, 0.24, 1)
	for i = 1, 3 do
		love.graphics.circle("line", x, y, 12 + i * 7, 28)
	end
	love.graphics.setColor(0.75, 0.62, 0.30, 1)
	love.graphics.circle("fill", x, y, 7, 16)
	local a = self.spin
	local hx, hy = x + math.cos(a) * (r - 12), y + math.sin(a) * (r - 12)
	love.graphics.setColor(0.80, 0.78, 0.70, 1)
	love.graphics.line(x, y, hx, hy)
	love.graphics.circle("fill", hx, hy, 5, 12)
	love.graphics.circle("fill", x - math.cos(a) * 10, y - math.sin(a) * 10, 3, 10)
	love.graphics.setColor(0.30, 0.52, 0.58, 0.45)
	love.graphics.circle("line", x, y, r + 7, 40)
	love.graphics.setLineWidth(1)
end

function splash:draw(w, h)
	love.graphics.setColor(0.05, 0.10, 0.14, 1)
	love.graphics.rectangle("fill", 0, 0, w, h)
	-- The wall. One pattern per spot, natural rotations.
	for i = 1, #self.wall do
		local f = FLIES[((i - 1) % #FLIES) + 1]
		local p = self.wall[i]
		love.graphics.push()
		love.graphics.translate(p.x, p.y)
		love.graphics.rotate(p.rot)
		PLANS[f.kind](f, f.s)
		love.graphics.pop()
	end
	-- Reel in the clear middle, percent underneath.
	local rx, ry, rr = w * 0.5, h * 0.56, 58
	reel(self, rx, ry, rr)
	love.graphics.setFont(self.small)
	love.graphics.setColor(0.70, 0.72, 0.64, 1)
	love.graphics.printf(math.floor(self.shown * 100) .. "%", 0, ry + rr + 18, w, "center")
end

return splash

-- Fly line on a mouse-pinned rod. A verlet rope: the tip
-- follows the cursor, the fly trails behind. Space lifts and
-- casts in two beats: back first, then forward once the line
-- straightens. Early second beats land short. The fly lays
-- out where the physics puts it. On water it drifts with the
-- current, paler and lower. Scroll mends and pays slack.
-- A hooked fish pins the fly end until it is caught or lost.
local mathx = require "lib.math"
local tackle = require "draw.flies"

local line = {}
local clamp, hash01 = mathx.clamp, mathx.hash01

local SEG_N = 14
local REST_CAST, REST_COIL = 18, 6
local REST_MAX = REST_CAST + 14
local READY_LO, READY_HI = 0.7, 1.8
local GRAV, DAMP_AIR, DAMP_WATER = 900, 0.995, 0.92

function line.spawn()
	local pts = {}
	for i = 1, SEG_N do
		pts[i] = { x = 0, y = 0, px = 0, py = 0, water = false }
	end
	return {
		kind = "line", pts = pts, state = "coiled",
		rest = REST_COIL, back_t = 0, quality = 1,
		hook = nil, mend_cd = 0, dimple_t = 0,
		rodvx = 0, rodvy = 0, fly = nil,
	}
end

-- Screen point to water data. Nearest flow station sets t,
-- the normal projection sets across, then a full sample
-- fills speed, heading, depth, and the surface pose.
local LS = {}
local function locate(river, x, y)
	local sts = river.flow and river.flow.stations
	if not sts then
		return nil
	end
	local bi, bd = 1, 1e18
	for i = 1, #sts do
		local dx, dy = x - sts[i].x, y - sts[i].y
		local d = dx * dx + dy * dy
		if d < bd then
			bd, bi = d, i
		end
	end
	local st = sts[bi]
	local rx, ry = x - st.x, y - st.y
	local across = clamp(0.5 + (rx * st.px + ry * st.py) / (2 * math.max(st.hw, 8)), 0, 1)
	return river:sample_into(st.t, across, river.time, LS)
end

-- Fly pose for the fish. Position only; the sim reads it a
-- frame late, which is fine at these speeds.
function line.lure(self)
	local f = self.pts[SEG_N]
	return { x = f.x, y = f.y, t = f.t or 0.5, across = f.across or 0.5, wet = f.water, active = self.state == "laid" }
end

-- Back to the rod after a catch or a loss. Short and slack.
function line.reset(self)
	self.state = "coiled"
	self.rest = REST_COIL
	self.hook = nil
end

-- Shove every waterborne point upstream. One mend per beat.
function line.mend(self, river)
	if self.state ~= "laid" or self.mend_cd > 0 then
		return false
	end
	self.mend_cd = 0.4
	for i = 2, SEG_N do
		local p = self.pts[i]
		if p.water and p.dx then
			p.x, p.px = p.x - p.dx * 42, p.px - p.dx * 42
			p.y, p.py = p.y - p.dy * 42, p.py - p.dy * 42
		end
	end
	local f = self.pts[SEG_N]
	if river.splash then
		river.splash:ring(f.x, f.y, 10, 0.7)
	end
	return true
end

-- Pay out slack. Loose line drifts wider. Slack during a
-- fight risks throwing the hook.
function line.slack(self)
	if self.state ~= "laid" and self.state ~= "fight" then
		return false
	end
	self.rest = math.min(REST_MAX, self.rest + 2)
	if self.state == "fight" and self.hook then
		self.throw_n = (self.throw_n or 0) + 1
		if hash01(self.hook.id, self.throw_n, 77) < 0.25 then
			local hooked = self.hook
			hooked.hooked, self.hook = false, nil
			hooked.spook_t = math.max(hooked.spook_t or 0, 2)
			self.state = "laid"
			return "thrown"
		end
	end
	return true
end

-- Spacebar: lift a laid line, start the backcast, or shoot
-- the forward cast. Timing the second beat is the skill.
-- Early beats tail and land short.
function line.press(self, mx, my)
	if self.state == "coiled" then
		self.state = "back"
		self.back_t = 0
		self.rest = REST_CAST
		for i = 2, SEG_N do
			local p = self.pts[i]
			p.px, p.py = p.px, p.py - 260 * (i / SEG_N)
		end
		return "back"
	end
	if self.state == "back" then
		local q = 0.6
		if self.back_t >= READY_LO and self.back_t <= READY_HI then
			q = 1
		elseif self.back_t > READY_HI then
			q = math.max(0.4, 1 - (self.back_t - READY_HI) * 0.4)
		end
		self.quality = q
		local ax, ay = self.rodvx, self.rodvy - 320
		local len = math.sqrt(ax * ax + ay * ay)
		if len < 60 then
			ax, ay = 160, -520
			len = math.sqrt(ax * ax + ay * ay)
		end
		local sp = (560 + math.min(760, len * 0.6)) * q
		for i = 2, SEG_N do
			local p = self.pts[i]
			p.px, p.py = p.x - ax / len * sp * 0.016, p.y - ay / len * sp * 0.016
		end
		self.state = "forward"
		self.fly_t = 0
		return "forward"
	end
	if self.state == "laid" then
		self.state = "coiled"
		self.rest = REST_COIL
		return "lift"
	end
	return nil
end

-- One verlet step. Tip pinned to the rod, fly pinned to a
-- hooked fish. Water points snap to the film and drift.
local function step(self, river, mx, my, dt)
	local pts = self.pts
	pts[1].x, pts[1].y, pts[1].px, pts[1].py = mx, my, mx, my
	for i = 2, SEG_N do
		local p = pts[i]
		local vx, vy = (p.x - p.px) * DAMP_AIR, (p.y - p.py) * DAMP_AIR
		p.px, p.py = p.x, p.y
		p.x, p.y = p.x + vx, p.y + vy + GRAV * dt * dt
		p.water = false
	end
	if self.state == "fight" and self.hook then
		local f = pts[SEG_N]
		f.x, f.y, f.px, f.py = self.hook.x, self.hook.y, self.hook.x, self.hook.y
	end
	for i = 2, SEG_N do
		local p = pts[i]
		local s = locate(river, p.x, p.y)
		if s and p.y >= s.y - 2 then
			p.y, p.py = s.y, s.y
			p.x = p.x + s.tx * s.speed * dt * 6
			p.px = p.px * 0.5 + p.x * 0.5
			p.water = true
			p.dx, p.dy, p.t, p.across = s.tx, s.ty, s.t, s.across
		end
	end
	for _ = 1, 3 do
		for i = 1, SEG_N - 1 do
			local a, b = pts[i], pts[i + 1]
			local dx, dy = b.x - a.x, b.y - a.y
			local d = math.sqrt(dx * dx + dy * dy)
			if d > 1e-5 then
				local diff = (d - self.rest) / d
				if i == 1 then
					b.x, b.y = b.x - dx * diff, b.y - dy * diff
				elseif i + 1 == SEG_N and self.state == "fight" then
					a.x, a.y = a.x + dx * diff, a.y + dy * diff
				else
					local h = diff * 0.5
					a.x, a.y = a.x + dx * h, a.y + dy * h
					b.x, b.y = b.x - dx * h, b.y - dy * h
				end
			end
		end
		pts[1].x, pts[1].y = mx, my
	end
end

function line.update(self, river, mx, my, dt)
	self.mend_cd = math.max(0, self.mend_cd - dt)
	local pvx, pvy = mx - (self.rx or mx), my - (self.ry or my)
	self.rx, self.ry = mx, my
	self.rodvx, self.rodvy = pvx / math.max(dt, 1e-4), pvy / math.max(dt, 1e-4)
	if self.state == "back" then
		self.back_t = self.back_t + dt
	end
	if self.state == "forward" then
		self.fly_t = (self.fly_t or 0) + dt
	end
	step(self, river, mx, my, dt)
	local f = self.pts[SEG_N]
	if self.state == "forward" then
		local vx, vy = f.x - f.px, f.y - f.py
		if f.water and vx * vx + vy * vy < 60 then
			self.state = "laid"
			self.rest = REST_CAST
		elseif (self.fly_t or 0) > 4 then
			self.state = f.water and "laid" or "coiled"
			self.rest = self.state == "laid" and REST_CAST or REST_COIL
		end
	end
	if self.state == "laid" then
		self.dimple_t = self.dimple_t - dt
		if self.dimple_t <= 0 and f.water then
			self.dimple_t = 1.2
			if river.splash then
				river.splash:dimple(f.x, f.y, 2)
			end
		end
	end
end

local AERIAL = { 0.80, 0.70, 0.42 }
local LAID = { 0.55, 0.50, 0.38 }
local TAUT = { 0.90, 0.55, 0.30 }

-- Rod stub off the cursor, then the line. Laid line runs
-- paler and thinner. Taut fight line runs hot.
function line.draw(self, mx, my)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.30, 0.22, 0.14, 1)
	love.graphics.line(mx, my, mx + 30, my + 40)
	love.graphics.setColor(0.55, 0.55, 0.58, 1)
	love.graphics.circle("line", mx + 18, my + 24, 5, 10)
	love.graphics.setLineWidth(1)
	if self.state == "coiled" then
		love.graphics.setColor(AERIAL[1], AERIAL[2], AERIAL[3], 0.9)
		love.graphics.circle("line", mx + 6, my - 8, 7, 12)
		love.graphics.circle("line", mx + 12, my - 2, 5, 10)
		return
	end
	local c = self.state == "fight" and TAUT or (self.state == "laid" and LAID or AERIAL)
	love.graphics.setColor(c[1], c[2], c[3], self.state == "laid" and 0.75 or 1)
	love.graphics.setLineWidth(self.state == "laid" and 1 or 2)
	local pts = {}
	for i = 1, SEG_N do
		pts[#pts + 1] = self.pts[i].x
		pts[#pts + 1] = self.pts[i].y
	end
	love.graphics.line(pts)
	love.graphics.setLineWidth(1)
	local f = self.pts[SEG_N]
	if self.fly then
		for i = 1, #tackle.list do
			if tackle.list[i].name == self.fly then
				love.graphics.push()
				love.graphics.translate(f.x, f.y)
				tackle.draw(tackle.list[i], 0.45)
				love.graphics.pop()
				break
			end
		end
	else
		love.graphics.setColor(0.12, 0.11, 0.10, 1)
		love.graphics.circle("fill", f.x, f.y, 2.5, 8)
		love.graphics.line(f.x - 3, f.y - 1, f.x - 1, f.y)
		love.graphics.line(f.x + 3, f.y - 1, f.x + 1, f.y)
	end
end

return line

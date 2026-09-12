local tackle = require "draw.flies"

local splash = {}
splash.__index = splash

local STEP_GAP = 0.7 -- seconds per load step


-- Scatter the wall. Dense jittered grid, seeded, with the
-- middle kept clear for the reel. Each pattern repeats.
local function lay_wall(w, h)
	local rng = love.math.newRandomGenerator(77)
	local spots, tries = {}, 0
	local cx, cy = w * 0.5, h * 0.56
	while #spots < #tackle.list * 4 and tries < 1200 do
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
	local fonts = require("ui.fonts").get()
	return setmetatable({
		t = 0, step_t = 0, progress = 0, shown = 0,
		spin = 0, pulse = 0,
		wall = lay_wall(w, h),
		title = fonts.title, sub = fonts.subtitle, small = fonts.small,
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
		local f = tackle.list[((i - 1) % #tackle.list) + 1]
		local p = self.wall[i]
		love.graphics.push()
		love.graphics.translate(p.x, p.y)
		love.graphics.rotate(p.rot)
		tackle.draw(f, f.s)
		love.graphics.pop()
	end
	-- Title over the wall, reel in the clear middle, subtitle
	-- tucked under the count. Tight cluster, no dead air.
	love.graphics.setFont(self.title)
	love.graphics.setColor(0.04, 0.07, 0.10, 1)
	love.graphics.printf("Cast", 2, h * 0.24 + 3, w, "center")
	love.graphics.setColor(0.90, 0.88, 0.74, 1)
	love.graphics.printf("Cast", 0, h * 0.24, w, "center")
	local rx, ry, rr = w * 0.5, h * 0.52, 58
	reel(self, rx, ry, rr)
	love.graphics.setFont(self.small)
	love.graphics.setColor(0.70, 0.72, 0.64, 1)
	love.graphics.printf(math.floor(self.shown * 100) .. "%", 0, ry + rr + 14, w, "center")
	love.graphics.setFont(self.sub)
	love.graphics.setColor(0.55, 0.62, 0.60, 1)
	love.graphics.printf("a fly fishing game", 0, ry + rr + 68, w, "center")
end

return splash

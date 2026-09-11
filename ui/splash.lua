local splash = {}
splash.__index = splash

local STEP_GAP = 0.7 -- seconds per load step

-- Serif title face with a safe fallback.
local function serif(size)
	for _, path in ipairs({
		"/System/Library/Fonts/Supplemental/Georgia.ttf",
		"/Library/Fonts/Georgia.ttf",
	}) do
		local f = io.open(path, "r")
		if f then
			f:close()
			local ok, font = pcall(love.graphics.newFont, path, size)
			if ok and font then
				return font
			end
		end
	end
	return love.graphics.newFont(size)
end

function splash.new()
	return setmetatable({
		t = 0, step_t = 0, progress = 0,
		spin = 0, pulse = 0,
		title = serif(84), sub = love.graphics.newFont(18),
	}, splash)
end

-- Advance clock, step timer, and reel spin.
function splash:update(dt, w)
	self.t = self.t + dt
	self.step_t = self.step_t + dt
	self.pulse = math.max(0, self.pulse - dt * 1.2)
	self.spin = self.spin + dt * (2 + 10 * self.pulse)
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
-- spin angle, progress arc around the rim.
local function reel(self, x, y, r)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.55, 0.60, 0.58, 1)
	love.graphics.circle("line", x, y, r, 40)
	love.graphics.setColor(0.16, 0.20, 0.22, 1)
	love.graphics.circle("fill", x, y, r - 4, 36)
	love.graphics.setColor(0.75, 0.62, 0.30, 1)
	love.graphics.circle("line", x, y, r - 4, 36)
	-- Wound line coils.
	love.graphics.setColor(0.42, 0.36, 0.24, 1)
	for i = 1, 3 do
		love.graphics.circle("line", x, y, 12 + i * 7, 28)
	end
	-- Arbor.
	love.graphics.setColor(0.75, 0.62, 0.30, 1)
	love.graphics.circle("fill", x, y, 7, 16)
	-- Handle arm and knob. Spins with load activity.
	local a = self.spin
	local hx, hy = x + math.cos(a) * (r - 12), y + math.sin(a) * (r - 12)
	love.graphics.setColor(0.80, 0.78, 0.70, 1)
	love.graphics.line(x, y, hx, hy)
	love.graphics.circle("fill", hx, hy, 5, 12)
	love.graphics.circle("fill", x - math.cos(a) * 10, y - math.sin(a) * 10, 3, 10)
	-- Progress arc on the rim.
	love.graphics.setColor(0.30, 0.52, 0.58, 0.45)
	love.graphics.circle("line", x, y, r + 7, 40)
	love.graphics.setColor(0.55, 0.85, 0.88, 1)
	love.graphics.arc("line", x, y, r + 7, -math.pi / 2, -math.pi / 2 + self.progress * math.pi * 2, 40)
	love.graphics.setLineWidth(1)
end

-- A tied dry fly. Hook with up eye, ribbed abdomen, dubbed
-- thorax, hackle collar, upright divided wings, tail fibers.
local function fly(x, y)
	love.graphics.setLineWidth(2)
	-- Tail fibers.
	love.graphics.setColor(0.55, 0.48, 0.34, 1)
	love.graphics.line(x - 22, y - 4, x - 13, y)
	love.graphics.line(x - 23, y, x - 13, y)
	love.graphics.line(x - 22, y + 4, x - 13, y)
	-- Hook bend and shank with up eye.
	love.graphics.setColor(0.15, 0.14, 0.12, 1)
	love.graphics.arc("line", x - 13, y, 5, -1.2, 1.2, 8)
	love.graphics.line(x - 13, y - 5, x + 12, y - 5)
	love.graphics.circle("line", x + 14, y - 6, 2, 8)
	-- Ribbed abdomen, tapering to the tail.
	love.graphics.setColor(0.45, 0.36, 0.20, 1)
	love.graphics.ellipse("fill", x - 4, y - 5, 9, 4.6, 0, 10)
	love.graphics.ellipse("fill", x + 4, y - 5, 6.5, 4.0, 0, 10)
	love.graphics.setColor(0.28, 0.22, 0.12, 1)
	love.graphics.line(x - 10, y - 8, x - 10, y - 2)
	love.graphics.line(x - 4, y - 9, x - 4, y - 1)
	love.graphics.line(x + 2, y - 9, x + 2, y - 1)
	-- Dubbed thorax.
	love.graphics.setColor(0.52, 0.42, 0.24, 1)
	love.graphics.ellipse("fill", x + 9, y - 5, 5.5, 5, 0, 10)
	-- Hackle collar strokes.
	love.graphics.setColor(0.88, 0.85, 0.72, 1)
	for i = -2, 2 do
		love.graphics.line(x + 9 + i * 2.4, y - 4, x + 9 + i * 3.4, y - 14 - (i == 0 and 2 or 0))
		love.graphics.line(x + 9 + i * 2.4, y - 4, x + 9 + i * 3.0, y + 3)
	end
	-- Upright divided wings.
	love.graphics.setColor(0.85, 0.86, 0.80, 0.9)
	love.graphics.ellipse("fill", x + 5, y - 20, 4.6, 10, -0.25, 10)
	love.graphics.ellipse("fill", x + 12, y - 20, 4.6, 10, 0.25, 10)
	love.graphics.setLineWidth(1)
end

function splash:draw(w, h)
	love.graphics.setColor(0.05, 0.10, 0.14, 1)
	love.graphics.rectangle("fill", 0, 0, w, h)
	-- Faint drift lanes behind the title.
	love.graphics.setColor(0.10, 0.20, 0.26, 0.5)
	love.graphics.setLineWidth(1)
	for i = 1, 5 do
		local y = h * 0.10 + i * 20 + math.sin(self.t * 0.8 + i) * 4
		love.graphics.line(0, y, w, y)
	end
	love.graphics.setFont(self.title)
	love.graphics.setColor(0.90, 0.88, 0.74, 1)
	love.graphics.printf("Cast", 0, h * 0.16, w, "center")
	love.graphics.setFont(self.sub)
	love.graphics.setColor(0.55, 0.62, 0.60, 1)
	love.graphics.printf("a fly fishing game", 0, h * 0.16 + 96, w, "center")
	-- Reel, line paying out to the fly as chunks land.
	local rx, ry, rr = w * 0.30, h * 0.56, 58
	reel(self, rx, ry, rr)
	local fx = rx + rr + 30 + self.progress * w * 0.34
	local sag = math.sin(self.t * 3) * 2
	love.graphics.setColor(0.70, 0.72, 0.64, 0.8)
	love.graphics.line(rx + rr, ry, fx, ry + sag)
	fly(fx, ry + sag)
	love.graphics.setFont(self.sub)
	love.graphics.setColor(0.70, 0.72, 0.64, 1)
	love.graphics.printf(math.floor(self.progress * 100) .. "%", 0, ry + rr + 18, w, "center")
end

return splash

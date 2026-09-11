local mathx = require "lib.math"

local player = {}
player.__index = player

local WALK_T, WALK_OFF = 0.14, 55
local OFF_MIN, OFF_MAX = 18, 130

-- Outward normal from the water onto land for this bank.
local function land_sign(side)
	if side < 0 then
		return -1
	end
	return 1
end

-- World pose on land at station t, offset pixels from the water.
local function pose(river, t, side, offset)
	local s = river:sample(t, side < 0 and 0 or 1)
	local k = land_sign(side) * offset
	return s.x + s.px * k, s.y + s.py * k
end

-- Bank whose land sits lower on the screen.
local function lower_bank(river, t)
	local _, yl = pose(river, t, -1, 40)
	local _, yr = pose(river, t, 1, 40)
	if yr >= yl then
		return 1
	end
	return -1
end

-- Station t on the lower bank that sits in the bottom of the window.
local function spawn_t(river, side)
	local h, best_t, best = river.height, 0.12, -1e9
	for i = 1, 24 do
		local t = 0.06 + (i - 1) / 23 * 0.34
		local x, y = pose(river, t, side, 40)
		if x > 28 and x < river.width - 28 and y > h * 0.55 and y < h - 20 then
			local score = y - math.abs(x - river.width * 0.35) * 0.15
			if score > best then
				best, best_t = score, t
			end
		end
	end
	return best_t
end

-- Place the player on the lower bank, in the bottom of the screen.
function player.spawn(river, seed)
	local t_guess = 0.14
	local side = lower_bank(river, t_guess)
	local t = spawn_t(river, side)
	local offset = 42
	local x, y = pose(river, t, side, offset)
	return setmetatable({
		kind = "player",
		t = t,
		side = side,
		offset = offset,
		x = x,
		y = y,
	}, player)
end

-- Left/right walk the bank. Up/down move toward or away from the water.
function player:update(dt, river, locked)
	if locked then
		return
	end
	local dt_t, dt_off = 0, 0
	if love.keyboard.isDown("left") then
		dt_t = dt_t - WALK_T * dt
	end
	if love.keyboard.isDown("right") then
		dt_t = dt_t + WALK_T * dt
	end
	if love.keyboard.isDown("up") then
		dt_off = dt_off - WALK_OFF * dt
	end
	if love.keyboard.isDown("down") then
		dt_off = dt_off + WALK_OFF * dt
	end
	self.t = mathx.clamp(self.t + dt_t, 0.05, 0.92)
	self.offset = mathx.clamp(self.offset + dt_off, OFF_MIN, OFF_MAX)
	self.side = lower_bank(river, self.t)
	self.x, self.y = pose(river, self.t, self.side, self.offset)
end

-- Top-down angler, drawn on top of the ground.
function player:draw()
	love.graphics.push()
	love.graphics.translate(self.x, self.y)
	love.graphics.setColor(0.12, 0.11, 0.08, 0.35)
	love.graphics.ellipse("fill", 1, 3, 8, 4)
	love.graphics.setColor(0.22, 0.20, 0.14)
	love.graphics.ellipse("fill", 0, 1, 8, 5)
	love.graphics.setColor(0.48, 0.40, 0.24)
	love.graphics.ellipse("fill", 0, -4, 5.5, 4)
	love.graphics.pop()
end

return player

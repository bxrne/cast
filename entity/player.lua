local mathx = require "lib.math"

local player = {}
player.__index = player

local BANK_OFFSET, WALK = 36, 0.12

-- World position on a bank at station t.
local function sample_bank(river, t, side)
	local s = river:sample(t, side < 0 and 0 or 1)
	local sign = side < 0 and -1 or 1
	return s.x + s.px * sign * BANK_OFFSET, s.y + s.py * sign * BANK_OFFSET
end

-- Place the player on a bank from the world seed.
function player.spawn(river, seed)
	local t, side = 0.38, seed % 2 == 0 and 1 or -1
	local x, y = sample_bank(river, t, side)
	return setmetatable({ kind = "player", t = t, side = side, x = x, y = y }, player)
end

-- Walk along the river with WASD. A/D pick a bank.
function player:update(dt, river)
	local dt_t = 0
	if love.keyboard.isDown("w") then
		dt_t = dt_t - WALK * dt
	end
	if love.keyboard.isDown("s") then
		dt_t = dt_t + WALK * dt
	end
	if love.keyboard.isDown("a") then
		self.side = -1
	end
	if love.keyboard.isDown("d") then
		self.side = 1
	end
	self.t = mathx.clamp(self.t + dt_t, 0.04, 0.96)
	self.x, self.y = sample_bank(river, self.t, self.side)
end

-- Top-down waders and torso.
function player:draw()
	love.graphics.push()
	love.graphics.translate(self.x, self.y)
	love.graphics.setColor(0.18, 0.16, 0.12)
	love.graphics.ellipse("fill", 0, 0, 7, 4)
	love.graphics.setColor(0.45, 0.38, 0.22)
	love.graphics.ellipse("fill", 0, -3, 4.5, 3.2)
	love.graphics.pop()
end

return player

local player = {}
player.__index = player

local BANK_OFFSET = 36
local WALK = 0.12

local function sample_bank(river, t, side)
	local across
	if side < 0 then
		across = 0
	else
		across = 1
	end
	local s = river:sample(t, across)
	local sign = 1
	if side < 0 then
		sign = -1
	end
	return s.x + s.px * sign * BANK_OFFSET, s.y + s.py * sign * BANK_OFFSET, s
end

function player.spawn(river, seed)
	local t = 0.38
	local side = -1
	if seed % 2 == 0 then
		side = 1
	end
	local x, y = sample_bank(river, t, side)
	return setmetatable({
		kind = "player",
		t = t,
		side = side,
		x = x,
		y = y,
	}, player)
end

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
	self.t = math.max(0.04, math.min(0.96, self.t + dt_t))
	self.x, self.y = sample_bank(river, self.t, self.side)
end

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

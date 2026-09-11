---@diagnostic disable: undefined-global

local draw = require "draw"

local river
local captured = false

function love.load()
	river = draw.river.new({ seed = 1 })
end

function love.update(dt)
	river:update(dt)
end

function love.draw()
	river:draw()
	love.graphics.setColor(0.86, 0.84, 0.72)
	love.graphics.print("seed " .. river.seed .. "  (R reseed)", 12, 10)
	if not captured then
		captured = true
		love.graphics.captureScreenshot("river-preview.png")
	end
end

function love.keypressed(key)
	if key == "r" then
		river:reseed(river.seed + 1)
	elseif key == "escape" then
		love.event.quit()
	end
end

function love.resize(w, h)
	river:resize(w, h)
end

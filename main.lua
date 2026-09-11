---@diagnostic disable: undefined-global


function love.load() -- Runs once when the game starts
	message = "Hello, LÖVE!"
	x = 300
	y = 200
end

function love.update(dt)
	-- Runs every frame; dt is delta time
	if love.keyboard.isDown("right") then
		x = x + 200 * dt
	end
	if love.keyboard.isDown("left") then
		x = x - 200 * dt
	end
end

function love.draw()
	-- Runs every frame to draw graphics
	love.graphics.print(message, x, y)
end

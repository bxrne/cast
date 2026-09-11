---@diagnostic disable: undefined-global

local draw = require "draw"
local debug_ui = require "ui.debug"

local world
local dbg

local function reseed(seed)
	seed = math.max(1, math.floor(seed))
	world.seed = seed
	world.river:reseed(seed)
end

function love.load()
	world = {
		seed = 1,
		paused = false,
		time_scale = 1,
	}
	world.river = draw.river.new({ seed = world.seed })
	dbg = debug_ui.new({
		controls = {
			{
				id = "seed",
				label = "seed",
				kind = "int",
				min = 1,
				max = 999999,
				get = function()
					return world.seed
				end,
				set = reseed,
			},
			{
				id = "pause",
				label = "pause",
				kind = "bool",
				get = function()
					return world.paused
				end,
				set = function(v)
					world.paused = v
				end,
			},
			{
				id = "time_scale",
				label = "time scale",
				kind = "float",
				min = 0,
				max = 3,
				step = 0.1,
				get = function()
					return world.time_scale
				end,
				set = function(v)
					world.time_scale = v
				end,
			},
		},
	})
end

function love.update(dt)
	if world.paused then
		return
	end
	world.river:update(dt * world.time_scale)
end

function love.draw()
	world.river:draw()
	dbg:draw()
end

function love.keypressed(key)
	if dbg:keypressed(key) then
		return
	end
	if key == "r" then
		reseed(world.seed + 1)
	elseif key == "escape" then
		love.event.quit()
	end
end

function love.resize(w, h)
	world.river:resize(w, h)
end

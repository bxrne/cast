---@diagnostic disable: undefined-global

local draw = require "draw"
local debug_ui = require "ui.debug"
local fish = require "entity.fish"
local player = require "entity.player"

local world
local dbg

local function spawn_entities()
	world.player = player.spawn(world.river, world.seed)
	world.fish = fish.spawn(world.river, world.seed, world.fish_count)
end

local function reseed(seed)
	seed = math.max(1, math.floor(seed))
	world.seed = seed
	world.river:reseed(seed)
	spawn_entities()
end

function love.load()
	world = {
		seed = 1,
		paused = false,
		time_scale = 1,
		fish_count = 10,
		show_lies = false,
	}
	world.river = draw.river.new({ seed = world.seed })
	spawn_entities()
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
			{
				id = "show_flow",
				label = "show flow",
				kind = "bool",
				get = function()
					return world.river.show_flow
				end,
				set = function(v)
					world.river.show_flow = v
				end,
			},
			{
				id = "show_lies",
				label = "show lies",
				kind = "bool",
				get = function()
					return world.show_lies
				end,
				set = function(v)
					world.show_lies = v
				end,
			},
			{
				id = "fish_count",
				label = "fish",
				kind = "int",
				min = 0,
				max = 24,
				get = function()
					return world.fish_count
				end,
				set = function(v)
					world.fish_count = math.floor(v)
					world.fish = fish.spawn(world.river, world.seed, world.fish_count)
				end,
			},
		},
	})
end

function love.update(dt)
	if world.paused then
		return
	end
	dt = dt * world.time_scale
	world.river:update(dt)
	fish.update(world.fish, dt, world.river)
	world.player:update(dt, world.river)
end

function love.draw()
	world.river:draw()
	if world.show_lies then
		fish.draw_lies(world.river)
	end
	fish.draw(world.fish)
	world.player:draw()
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
	spawn_entities()
end

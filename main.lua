---@diagnostic disable: undefined-global

local draw = require "draw"
local debug_ui = require "ui.debug"
local fish = require "entity.fish"
local player = require "entity.player"
local rand = require "lib.rand"

local world, dbg

-- Spawn player and fish for the current seed.
local function spawn_entities()
	world.player = player.spawn(world.river, world.seed)
	world.fish = fish.spawn(world.river, world.seed, world.fish_count)
end

-- Apply a new seed to the river and entities.
local function reseed(seed)
	world.seed = math.max(1, math.floor(seed))
	world.river:reseed(world.seed)
	spawn_entities()
end

-- Build a debug control table.
local function ctrl(id, kind, get, set, extra)
	extra = extra or {}
	extra.id, extra.label, extra.kind, extra.get, extra.set = id, extra.label or id:gsub("_", " "), kind, get, set
	return extra
end

-- Load world, river, entities, and the debug panel.
function love.load()
	world = { seed = 1, paused = false, time_scale = 1, fish_count = 10, show_lies = false }
	world.river = draw.river.new({ seed = world.seed })
	spawn_entities()
	dbg = debug_ui.new({
		controls = {
			ctrl("seed", "seed", function() return world.seed end, reseed, { min = 1, max = 999999 }),
			ctrl("pause", "bool", function() return world.paused end, function(v) world.paused = v end),
			ctrl("time_scale", "float", function() return world.time_scale end, function(v) world.time_scale = v end, { min = 0, max = 8, step = 0.25 }),
			ctrl("show_flow", "bool", function() return world.river.show_flow end, function(v) world.river.show_flow = v end),
			ctrl("show_lies", "bool", function() return world.show_lies end, function(v) world.show_lies = v end),
			ctrl("fish_count", "int", function() return world.fish_count end, function(v)
				world.fish_count = math.floor(v)
				world.fish = fish.spawn(world.river, world.seed, world.fish_count)
			end, { min = 0, max = 24, label = "fish" }),
			ctrl("bed", "label", function()
				return world.river.char.bed_type.id
			end, function() end),
		},
	})
end

-- Step the sim unless paused.
function love.update(dt)
	if world.paused then
		return
	end
	dt = dt * world.time_scale
	world.river:update(dt)
	fish.update(world.fish, dt, world.river)
	world.player:update(dt, world.river)
end

-- Draw world then debug overlay.
function love.draw()
	world.river:draw()
	if world.show_lies then
		fish.draw_lies(world.river)
	end
	fish.draw(world.fish)
	world.player:draw()
	dbg:draw()
end

-- Debug keys first, then R rolls a seed.
function love.keypressed(key)
	if dbg:keypressed(key) then
		return
	end
	if key == "r" then
		reseed(rand.other(world.seed, 1, 999999))
	elseif key == "escape" then
		love.event.quit()
	end
end

-- Rebuild the river and entities after a resize.
function love.resize(w, h)
	world.river:resize(w, h)
	spawn_entities()
end

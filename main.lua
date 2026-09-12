---@diagnostic disable: undefined-global

local draw = require "draw"
local debug_ui = require "ui.debug"
local flybox_ui = require "ui.flybox"
local fish = require "entity.fish"
local load_screen = require "ui.splash"
local sfx = require "sfx"

local world, dbg, boot, flybox

-- Spawn the seeded school for the current river.
local function spawn_entities()
	world.fish = fish.spawn(world.river, world.seed)
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

-- Build the debug panel for the current world. Flat list.
-- Seed and fps always visible. All knobs reachable.
local function build_panel()
	world.sound = world.sound or 0.64
	dbg = debug_ui.new({
		controls = {
			ctrl("seed", "seed", function() return world.seed end, reseed,
				{ min = 1, max = 24, bed = function() return world.river.char.bed_type.id end }),
			ctrl("fps", "label", function()
				return string.format("%d fps", love.timer.getFPS())
			end, function() end),
			ctrl("pause", "bool", function() return world.paused end, function(v) world.paused = v end),
			ctrl("time_scale", "float", function() return world.time_scale end, function(v) world.time_scale = v end, { min = 0, max = 8, step = 0.25 }),
			ctrl("sound", "float",
				function() return world.sound end,
				function(v) world.sound = v sfx.level(v) end,
				{ min = 0, max = 1, step = 0.05 }),
			ctrl("fish tags", "bool", function() return world.show_fish end, function(v) world.show_fish = v end),
			ctrl("current", "float",
				function() return world.river.flow.base_speed / world.river.flow.base end,
				function(v) world.river.flow.base_speed = world.river.flow.base * v world.river:touch_flow() end,
				{ min = 0.25, max = 3, step = 0.05 }),
			ctrl("turbulence", "float",
				function() return world.river.flow.turb_scale end,
				function(v) world.river.flow.turb_scale = v world.river:touch_flow() end,
				{ min = 0, max = 1, step = 0.05 }),
			ctrl("bed exposure", "float",
				function() return world.river.bed_exposure end,
				function(v) world.river.bed_exposure = v end,
				{ min = 0.4, max = 2.8, step = 0.2 }),
			ctrl("water sheen", "float",
				function() return world.river.water_sheen end,
				function(v) world.river.water_sheen = v end,
				{ min = 0, max = 1, step = 0.05 }),
			ctrl("show flow", "bool", function() return world.river.show_flow end, function(v) world.river.show_flow = v end),
		},
	})
	sfx.level(world.sound)
end

-- Load the splash first. Heavy build runs as staged steps so
-- the reel and the wall stay live.
function love.load()
	boot = { screen = load_screen.new(), done = 0, total = 6, water = nil }
end

-- One build step per beat of the step timer.
local function boot_step()
	local n = boot.done + 1
	if n == 1 then
		local code = love.filesystem.read("draw/water.glsl")
		assert(code, "draw/water.glsl")
		boot.water = love.graphics.newShader(code)
	elseif n == 2 then
		fish.preload()
	elseif n == 3 then
		world = { seed = love.math.random(1, 24), paused = false, time_scale = 1, show_fish = false }
		world.river = draw.river.new({ seed = world.seed, shader = boot.water })
	elseif n == 4 then
		spawn_entities()
	elseif n == 5 then
		build_panel()
		flybox = flybox_ui.new()
	elseif n == 6 then
		sfx.build()
	end
	boot.done = n
	boot.screen.progress = n / boot.total
	boot.screen:mark_step()
end

function love.update(dt)
	if boot then
		local w = love.graphics.getWidth()
		boot.screen:update(dt, w)
		if boot.screen:step_due() and boot.done < boot.total then
			boot_step()
		end
		if boot.done >= boot.total then
			world.time = 0
			boot = nil
		end
		return
	end
	if world.paused then
		return
	end
	if dt > 0.05 then dt = 0.05 end
	dt = dt * world.time_scale
	world.river:update(dt)
	fish.update(world.fish, dt, world.river, nil)
	-- Water bed follows the beat. Flow norm plus turbulence
	-- steer the three voices.
	local u = math.max(0, math.min(1, (world.river.flow.base_speed - 0.45) / 1.1))
	sfx.water(dt, u, world.river.flow.turb_scale or 0)
end

-- Draw splash while booting, world after.
function love.draw()
	if boot then
		boot.screen:draw(love.graphics.getWidth(), love.graphics.getHeight())
		return
	end
	world.river:draw()
	fish.draw(world.fish, world.river)
	if world.show_fish then
		fish.draw_indicators(world.fish)
	end
	flybox:draw()
	dbg:draw()
end

-- Debug panel keys first; seeds change only from the panel.
function love.keypressed(key)
	if boot then
		if key == "escape" then
			love.event.quit()
		end
		return
	end
	if dbg:keypressed(key) then
		return
	end
	-- Esc closes the drawer. Nothing quits the game by key.
	if key == "escape" then
		flybox.open = false
		return
	end
	if key == "f12" then
		-- Save to the write dir as current.png; format comes first here.
		love.graphics.captureScreenshot(function(img)
			img:encode("png", "current.png")
		end)
	end
end

-- Rebuild the river and entities after a resize.
function love.resize(w, h)
	if boot then
		return
	end
	world.river:resize(w, h)
	spawn_entities()
end

-- Route clicks to the fly box first.
function love.mousepressed(x, y, button)
	if boot or button ~= 1 then
		return
	end
	flybox:mousepressed(x, y)
end

-- Wheel scrolls the fly box list while it is open.
function love.wheelmoved(dx, dy)
	if boot then
		return
	end
	flybox:wheelmoved(dx, dy)
end

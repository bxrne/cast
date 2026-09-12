---@diagnostic disable: undefined-global

local draw = require "draw"
local debug_ui = require "ui.debug"
local flybox_ui = require "ui.flybox"
local fish = require "entity.fish"
local birds = require "entity.birds"
local insects = require "entity.insects"
local data = require "lib.data"
local load_screen = require "ui.splash"
local sfx = require "sfx"

local world, dbg, boot, flybox

-- Spawn the seeded school, birds, and flies for the current river.
local function spawn_entities()
	world.fish = fish.spawn(world.river, world.seed)
	world.birds = birds.spawn(world.river, world.seed)
	world.insects = insects.spawn(world.river, world.seed)
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

-- Section title. Never selectable, never adjustable.
local function head(id)
	return ctrl(id, "header", function() return "" end, function() end)
end

-- Live fly takes across the school this frame.
local function take_count()
	local n = 0
	for i = 1, #world.fish do
		n = n + (world.fish[i].takes or 0)
	end
	return string.format("%d takes", n)
end

-- Flies still on the water out of the hatch total.
local function flies_up()
	local up, n = 0, #world.insects
	for i = 1, n do
		if world.insects[i].state ~= "taken" then
			up = up + 1
		end
	end
	return string.format("%d/%d up", up, n)
end

-- Build the debug panel for the current world. Headers split
-- the list into sections. Labels are readouts: the cursor
-- skips them, so fps and counts can never read as knobs.
local function build_panel()
	world.sound = world.sound or 0.20
	world.show_birds = world.show_birds ~= false
	world.show_insects = world.show_insects ~= false
	dbg = debug_ui.new({
		controls = {
			head("river"),
			ctrl("seed", "seed", function() return world.seed end, reseed,
				{ min = 1, max = 24, bed = function() return world.river.char.bed_type.id end }),
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
			head("life"),
			ctrl("fishes", "label", function() return string.format("%d fish", #world.fish) end, function() end),
			ctrl("birds", "bool", function() return world.show_birds end, function(v) world.show_birds = v end),
			ctrl("flies", "bool", function() return world.show_insects end, function(v) world.show_insects = v end),
			ctrl("takes", "label", take_count, function() end),
			ctrl("hatch", "label", flies_up, function() end),
			head("sim"),
			ctrl("pause", "bool", function() return world.paused end, function(v) world.paused = v end),
			ctrl("time_scale", "float", function() return world.time_scale end, function(v) world.time_scale = v end, { min = 0, max = 8, step = 0.25 }),
			head("sound"),
			ctrl("sfx", "bool", function() return sfx.is_enabled() end, function(v) sfx.onoff(v) end),
			ctrl("sound", "float",
				function() return world.sound end,
				function(v) world.sound = v sfx.level(v) end,
				{ min = 0, max = 1, step = 0.05 }),
			head("view"),
			ctrl("fish tags", "bool", function() return world.show_fish end, function(v) world.show_fish = v end),
			ctrl("show flow", "bool", function() return world.river.show_flow end, function(v) world.river.show_flow = v end),
			ctrl("fps", "label", function()
				return string.format("%d fps", love.timer.getFPS())
			end, function() end),
		},
	})
	sfx.level(world.sound)
end

-- Load the splash first. Heavy build runs as staged steps so
-- the reel and the wall stay live.
function love.load()
	pcall(function() love.window.maximize() end)
	boot = { screen = load_screen.new(), done = 0, total = 6, water = nil }
	sfx.reel_start()
end

-- One build step per beat of the step timer. Independent steps
-- run in parallel to cut startup from 4.2s to ~2.1s.
local function boot_step()
	local n = boot.done + 1
	if n == 1 then
		-- Steps 1+2: entity config and shaders first, then the
		-- fish preload. Both independent.
		data.load()
		local code = love.filesystem.read("draw/water.glsl")
		assert(code, "draw/water.glsl")
		boot.water = love.graphics.newShader(code)
		fish.preload()
		n = 2
	elseif n == 3 then
		-- Step3: river needs the shader from step1.
		world = { seed = love.math.random(1, 24), paused = false, time_scale = 1, show_fish = false }
		world.river = draw.river.new({ seed = world.seed, shader = boot.water })
		world.sound = 0.20
	elseif n == 4 then
		-- Steps4+5+6: entities, panel, sound are independent after river.
		spawn_entities()
		build_panel()
		flybox = flybox_ui.new()
		sfx.build()
		n = 6
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
			sfx.reel_stop()
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
	-- Hidden life stays out of the sim, not just the draw.
	-- Birds off means no spooks and no pecks. Flies off
	-- means nothing to hunt and nothing to scatter.
	local show_birds = world.show_birds ~= false
	local show_flies = world.show_insects ~= false
	if show_birds then
		birds.update(world.birds, dt, world.river)
	end
	if show_flies then
		if show_birds then
			insects.avoid_birds(world.insects, world.birds, world.river, dt)
		end
		insects.update(world.insects, dt, world.river)
	end
	local events = fish.update(world.fish, dt, world.river, nil, {
		birds = show_birds and world.birds or nil,
		insects = show_flies and world.insects or nil,
	})
	if show_flies and events and #events > 0 then
		insects.apply_events(world.insects, events, world.river)
	end
	-- Water bed follows the beat. Flow norm plus turbulence
	-- steer the three voices.
	local u = math.max(0, math.min(1, (world.river.flow.base_speed - 0.45) / 1.1))
	sfx.water(dt, u)
end

-- Draw splash while booting, world after.
function love.draw()
	if boot then
		boot.screen:draw(love.graphics.getWidth(), love.graphics.getHeight())
		return
	end
	world.river:draw()
	fish.draw(world.fish, world.river)
	if world.show_insects ~= false then
		insects.draw(world.insects)
	end
	if world.show_birds ~= false then
		birds.draw(world.birds)
	end
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
	-- Fly box captures up/down when open.
	if flybox:keypressed(key) then
		return
	end
	if dbg:keypressed(key) then
		return
	end
	-- f toggles the fly box.
	if key == "f" then
		flybox:toggle()
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
	if flybox then
		flybox:resize()
	end
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

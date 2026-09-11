---@diagnostic disable: undefined-global

local draw = require "draw"
local debug_ui = require "ui.debug"
local fish = require "entity.fish"

local world, dbg

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

-- Load world, river, entities, and the debug panel.
function love.load()
	world = { seed = 1, paused = false, time_scale = 1, show_fish = true }
	world.river = draw.river.new({ seed = world.seed })
	spawn_entities()
	dbg = debug_ui.new({
		controls = {
			ctrl("seed", "seed", function() return world.seed end, reseed, { min = 1, max = 999999 }),
			ctrl("pause", "bool", function() return world.paused end, function(v) world.paused = v end),
			ctrl("time_scale", "float", function() return world.time_scale end, function(v) world.time_scale = v end, { min = 0, max = 8, step = 0.25 }),
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
			ctrl("show_flow", "bool", function() return world.river.show_flow end, function(v) world.river.show_flow = v end),
			ctrl("show_fish", "bool", function() return world.show_fish end, function(v) world.show_fish = v end, { label = "fish tags" }),
			ctrl("bed", "label", function()
				return world.river.char.bed_type.id
			end, function() end),
		},
	})
end

-- Step the sim unless paused. Clamp dt so a hitch never
-- throws fish across the beat.
function love.update(dt)
	if world.paused then
		return
	end
	if dt > 0.05 then dt = 0.05 end
	dt = dt * world.time_scale
	world.river:update(dt)
	fish.update(world.fish, dt, world.river, nil)
end

-- Draw world then debug overlay.
function love.draw()
	world.river:draw()
	fish.draw(world.fish, world.river)
	if world.show_fish then
		fish.draw_indicators(world.fish)
	end
	dbg:draw()
end

-- Debug panel keys first; seeds change only from the panel.
function love.keypressed(key)
	if dbg:keypressed(key) then
		return
	end
	if key == "escape" then
		love.event.quit()
	elseif key == "f12" then
		-- Save to the write dir as current.png; format comes first here.
		love.graphics.captureScreenshot(function(img)
			img:encode("png", "current.png")
		end)
	end
end

-- Rebuild the river and entities after a resize.
function love.resize(w, h)
	world.river:resize(w, h)
	spawn_entities()
end

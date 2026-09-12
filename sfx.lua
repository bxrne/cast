-- Water sound from a bundled MP3. Volume follows flow speed.
-- The debug panel owns on/off and master level.
local sfx = {}

local src = nil
local enabled = true

-- Load and start the river loop. Safe no-op headless.
function sfx.build()
	local good = pcall(function()
		src = love.audio.newSource("assets/sfx/dragon-studio-soothing-river-flow-372456.mp3", "streaming")
		src:setLooping(true)
		src:setVolume(0.5)
		src:play()
	end)
	if not good then
		src = nil
	end
end

-- Called every frame. u = normalised flow speed 0..1.
-- Volume scales with flow: quiet on a creek, fuller on a rapid.
function sfx.water(dt, u)
	if not src or not enabled then
		return
	end
	local k = math.min(1, 8 * dt)
	local master = sfx._master or 0.64
	local target = master * (0.25 + u * 0.55)
	local cur = src:getVolume()
	src:setVolume(cur + (target - cur) * k)
end

-- Master level, 0..1.
function sfx.level(v)
	sfx._master = math.max(0, math.min(1, v or 0.64))
	if not src or not enabled then
		return
	end
	src:setVolume(sfx._master * 0.55)
end

-- On/off toggle from the debug panel.
function sfx.onoff(v)
	enabled = v
	if not src then
		return
	end
	if not enabled then
		src:setVolume(0)
	elseif src:getVolume() == 0 then
		sfx.level(sfx._master or 0.64)
	end
end

function sfx.is_enabled()
	return enabled
end

return sfx

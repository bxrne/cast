-- Water sound from a bundled MP3. Volume is flat, set by slider.
-- The debug panel owns on/off and master level.
local sfx = {}

local src = nil
local reel_src = nil
local enabled = true
local last_error = nil

-- Load and start the river loop. Safe no-op headless.
function sfx.build()
	src = nil
	last_error = nil
	if not love.audio then
		last_error = "audio unavailable"
		print("[sfx] " .. last_error)
		return
	end
	local ok, err = pcall(function()
		local source = love.audio.newSource("assets/sfx/babbling-brook.mp3", "stream")
		if not source then
			error("source creation returned nil")
		end
		source:setLooping(true)
		source:setVolume(sfx._master or 0.20)
		local started = source:play()
		if started == false then
			error("source refused playback")
		end
		src = source
	end)
	if not ok then
		last_error = tostring(err)
		src = nil
		print("[sfx] " .. last_error)
	end
end

-- Splash reel loop from the bundled MP3. Plays while the
-- loading reel spins. Stops when the splash goes away.
function sfx.reel_start()
	if reel_src and reel_src:isPlaying() then
		return
	end
	if not love.audio then
		return
	end
	local ok, err = pcall(function()
		if not reel_src then
			local reel = love.audio.newSource("assets/sfx/reel-constant.mp3", "stream")
			if not reel then
				error("reel source creation returned nil")
			end
			reel:setLooping(true)
			reel_src = reel
		end
		if enabled then
			reel_src:setVolume(sfx._master or 0.20)
		else
			reel_src:setVolume(0)
		end
		local started = reel_src:play()
		if started == false then
			error("reel source refused playback")
		end
	end)
	if not ok then
		last_error = tostring(err)
		print("[sfx] " .. last_error)
	end
end

-- Stop the splash reel loop. Safe no-op when idle.
function sfx.reel_stop()
	if not reel_src then
		return
	end
	pcall(function()
		reel_src:stop()
	end)
	reel_src = nil
end

-- Volume is flat, controlled only by the debug slider.
-- This function is kept for the beat hook but no longer touches volume.
function sfx.water(dt, u)
	-- Intentionally empty: flow speed must not affect volume.
end

-- Master level, 0..1.
function sfx.level(v)
	sfx._master = math.max(0, math.min(1, v or 0.20))
	if reel_src and enabled then
		reel_src:setVolume(sfx._master)
	end
	if not src or not enabled then
		return
	end
	src:setVolume(sfx._master)
	if not src:isPlaying() then
		local started = src:play()
		if started == false then
			last_error = "source refused playback"
			print("[sfx] " .. last_error)
		else
			last_error = nil
		end
	end
end

-- On/off toggle from the debug panel.
function sfx.onoff(v)
	enabled = v
	if reel_src then
		if enabled then
			sfx.level(sfx._master or 0.20)
			if not reel_src:isPlaying() then
				reel_src:play()
			end
		else
			reel_src:setVolume(0)
			reel_src:pause()
		end
	end
	if not src then
		return
	end
	if enabled then
		sfx.level(sfx._master or 0.20)
	else
		src:setVolume(0)
		src:pause()
	end
end

function sfx.is_enabled()
	return enabled
end

function sfx.status()
	if last_error then
		return "error: " .. last_error
	end
	if not enabled then
		return "off"
	end
	if not src then
		return "not loaded"
	end
	return string.format("%s %.0f%%", src:isPlaying() and "playing" or "paused", src:getVolume() * 100)
end

return sfx

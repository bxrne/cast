-- Procedural water sound. Three seamless looped voices
-- crossfade by flow params. No audio files; loops never
-- click and the repo stays light.
local sfx = {}

local RATE, LEN = 22050, 44100 -- 2 s mono loops
local ok = false
local trickle, riffle, pool

local function fade_ends(data, n)
	for i = 0, n - 1 do
		local k = i / n
		local a = data:getSample(i)
		local b = data:getSample(LEN - n + i)
		data:setSample(i, a * k + b * (1 - k))
	end
end

local function normalize(data, peak)
	local m = 0
	for i = 0, LEN - 1 do
		local a = math.abs(data:getSample(i))
		if a > m then m = a end
	end
	if m > 0 then
		local k = peak / m
		for i = 0, LEN - 1 do
			data:setSample(i, data:getSample(i) * k)
		end
	end
end

-- Trickle voice. Band-limited bed with resonant droplet pings
-- and amplitude modulation for a rhythmic trickle character.
local function build_trickle()
	local d = love.sound.newSoundData(LEN, RATE, 16, 1)
	-- Tighter low-pass base: more brown than white noise.
	local lp1, lp2 = 0, 0
	for i = 0, LEN - 1 do
		local w = love.math.random() * 2 - 1
		lp1 = lp1 + 0.06 * (w - lp1)
		lp2 = lp2 + 0.10 * (lp1 - lp2)
		-- Amplitude modulation: slow rise-fall cycle.
		local am = 0.55 + 0.45 * math.sin(i / RATE * 2.2 * 6.283 + lp2 * 3)
		d:setSample(i, lp2 * 0.7 * am)
	end
	-- Resonant droplet pings: short decays, ring frequencies.
	for p = 1, 14 do
		local at = love.math.random(0, LEN - 3600)
		local f = 1800 + love.math.random() * 2400
		local decay = 120 + love.math.random() * 320
		local amp = 0.18 + love.math.random() * 0.22
		for i = 0, 3600 - 1 do
			local k = math.exp(-i / decay)
			local v = d:getSample(at + i) + math.sin(i / RATE * f * 6.283) * k * amp
			d:setSample(at + i, v)
		end
	end
	-- A few very short high-pitched drip transients.
	for p = 1, 5 do
		local at = love.math.random(0, LEN - 400)
		local f = 3200 + love.math.random() * 1800
		for i = 0, 399 do
			local k = math.exp(-i / 40)
			local v = d:getSample(at + i) + (love.math.random() * 2 - 1) * k * 0.12
			d:setSample(at + i, v + math.sin(i / RATE * f * 6.283) * k * 0.15)
		end
	end
	normalize(d, 0.35)
	fade_ends(d, 4000)
	return d
end

-- Riffle voice. Mid band chop over smoothed noise.
local function build_riffle()
	local d = love.sound.newSoundData(LEN, RATE, 16, 1)
	local lp, v = 0, 0
	for i = 0, LEN - 1 do
		local w = love.math.random() * 2 - 1
		lp = lp + 0.12 * (w - lp)
		v = v + 0.5 * (w * 0.4 + lp - v)
		d:setSample(i, v * (0.75 + 0.25 * math.sin(i / RATE * 3.1)))
	end
	normalize(d, 0.45)
	fade_ends(d, 4000)
	return d
end

-- Pool voice. Deep smoothed wash.
local function build_pool()
	local d = love.sound.newSoundData(LEN, RATE, 16, 1)
	local brown, lp = 0, 0
	for i = 0, LEN - 1 do
		local w = love.math.random() * 2 - 1
		brown = (brown + 0.02 * w) / 1.02
		lp = lp + 0.08 * (brown * 3.2 - lp)
		d:setSample(i, lp)
	end
	normalize(d, 0.4)
	fade_ends(d, 4000)
	return d
end

-- Build buffers and start the water bed. Safe no-op headless.
function sfx.build()
	local good = pcall(function()
		trickle = love.audio.newSource(build_trickle(), "static")
		riffle = love.audio.newSource(build_riffle(), "static")
		pool = love.audio.newSource(build_pool(), "static")
		for _, s in ipairs({ trickle, riffle, pool }) do
			s:setLooping(true)
			s:setVolume(0)
			s:play()
		end
	end)
	ok = good
end

-- Mix the bed from normalised flow and turbulence. Trickle owns
-- creeks, riffle owns brisk beats, pool always breathes.
function sfx.water(dt, u, turb)
	if not ok then
		return
	end
	local k = math.min(1, 4 * dt)
	local gt = math.max(0, 1.3 - u * 1.8) * 0.65
	local gr = math.max(0, 1 - math.abs(u - 0.65) * 2.2) * (0.35 + turb * 0.4)
	local gp = 0.30 + u * 0.15
	trickle:setVolume(trickle:getVolume() + (gt - trickle:getVolume()) * k)
	riffle:setVolume(riffle:getVolume() + (gr - riffle:getVolume()) * k)
	pool:setVolume(pool:getVolume() + (gp - pool:getVolume()) * k)
end

-- Master level, 0..1. The panel owns this. Default bed runs
-- at sixty-four percent (twenty under the old full).
function sfx.level(v)
	pcall(love.audio.setVolume, math.max(0, math.min(1, v or 0.64)))
end

return sfx

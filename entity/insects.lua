-- Live flies over the film. Small noise-driven clusters, never
-- a grid. Each fly wanders its cluster on its own phase while
-- the cluster itself drifts on tile noise. States: swarm flies
-- above the film, skitter touches it, startled bursts away,
-- taken is gone until it respawns. Fish read x, y, and state.
-- Fish never write here; they return take events and the main
-- loop applies them through apply_events.
local mathx = require "lib.math"

local insects = {}
local clamp, hash01, lerp, TAU = mathx.clamp, mathx.hash01, mathx.lerp, mathx.TAU
local noise = mathx.tile_noise

-- Two or three clusters of four to six flies.
function insects.spawn(river, seed)
	local ncl = 2 + math.floor(hash01(seed, 301, 302) * 2)
	local out = {}
	local id = 0
	for c = 1, ncl do
		local home_t = 0.15 + hash01(seed, c, 303) * 0.7
		local home_a = 0.30 + hash01(seed, c, 304) * 0.40
		local n = 4 + math.floor(hash01(seed, c, 305) * 3)
		for k = 1, n do
			id = id + 1
			local h1, h2, h3 = hash01(seed, id, 306), hash01(seed, id, 307), hash01(seed, id, 308)
			out[#out + 1] = {
				kind = "fly", id = id, seed = seed, cluster = c,
				home_t = home_t, home_across = home_a,
				t = home_t, across = home_a, x = 0, y = 0, hoff = 6 + h1 * 8,
				phase = h2 * TAU, radius = 0.008 + h3 * 0.016,
				speed = 0.6 + h1 * 1.2, state = "swarm",
				timer = 2 + h2 * 4, clock = h3 * 10,
				bx = 0, by = 0,
			}
		end
	end
	insects._clock = 0
	return out
end

-- Cluster anchor wanders on noise so the group drifts but
-- never marches in formation.
local function anchor(f, clock)
	local p = f.cluster * 7.3
	local ct = f.home_t + 0.015 * math.sin(clock * 0.11 + p)
	    + (noise(clock * 0.05, p, 8, f.seed) - 0.5) * 0.03
	local ca = f.home_across + 0.020 * math.sin(clock * 0.09 + p * 1.7)
	    + (noise(p, clock * 0.05, 8, f.seed + 5) - 0.5) * 0.04
	return ct, ca
end

-- Tick motion, mode flips, and respawns. Needs the river to
-- turn parametric drift into screen pose.
function insects.update(list, dt, river)
	insects._clock = (insects._clock or 0) + dt
	local clock = insects._clock
	for i = 1, #list do
		local f = list[i]
		f.clock = f.clock + dt
		if f.state == "taken" then
			f.timer = f.timer - dt
			if f.timer <= 0 then
				f.state = "swarm"
				f.timer = 2 + hash01(f.seed, f.id, math.floor(clock) + 309) * 4
				f.home_t = clamp(f.home_t + (hash01(f.seed, f.id, clock) - 0.5) * 0.1, 0.1, 0.9)
				f.bx, f.by = 0, 0
			end
		elseif f.state == "startled" then
			f.timer = f.timer - dt
			f.bx, f.by = f.bx * (1 - 2.4 * dt), f.by * (1 - 2.4 * dt)
			if f.timer <= 0 then
				f.state = "swarm"
				f.timer = 2 + hash01(f.seed, f.id, math.floor(clock) + 310) * 4
			end
		else
			f.timer = f.timer - dt
			if f.timer <= 0 then
				if f.state == "swarm" then
					f.state = "skitter"
					f.timer = 1.5 + hash01(f.seed, f.id, math.floor(clock) + 311) * 3
				else
					f.state = "swarm"
					f.timer = 2 + hash01(f.seed, f.id, math.floor(clock) + 312) * 4
				end
			end
			f.bx, f.by = 0, 0
		end
		if f.state ~= "taken" then
			local ct, ca = anchor(f, clock)
			local a = f.clock * f.speed + f.phase
			local rad = f.radius * (0.7 + 0.3 * math.sin(f.clock * 0.7 + f.phase * 2))
			local jx = (noise(f.clock * 0.6, f.id * 3.1, 16, f.seed) - 0.5) * 0.008
			local jy = (noise(f.id * 3.1, f.clock * 0.6, 16, f.seed + 9) - 0.5) * 0.010
			f.t = clamp(ct + math.cos(a) * rad + jx, 0.05, 0.95)
			f.across = clamp(ca + math.sin(a) * rad * 1.4 + jy, 0.15, 0.85)
			local s = river:sample(f.t, f.across)
			f.x, f.y = s.x + f.bx, s.y + f.by
			if f.state == "skitter" and river.splash then
				if hash01(f.id, math.floor(f.clock * 2), 7) < 0.05 then
					river.splash:dimple(f.x, f.y, 2)
				end
			end
		end
	end
end

-- Scatter flies around a rise point. Burst offsets decay in update.
function insects.startle_at(list, x, y, r)
	for i = 1, #list do
		local f = list[i]
		if f.state == "swarm" or f.state == "skitter" then
			local dx, dy = f.x - x, f.y - y
			local d = math.sqrt(dx * dx + dy * dy)
			if d < r then
				local nx, ny = 1, 0
				if d > 0.5 then
					nx, ny = dx / d, dy / d
				else
					local a = hash01(f.seed, f.id, math.floor((insects._clock or 0) * 3) + 313) * TAU
					nx, ny = math.cos(a), math.sin(a)
				end
				local push = (1 - d / r) * 26 + 8
				f.bx, f.by = nx * push, ny * push
				f.state = "startled"
				f.timer = 0.9 + hash01(f.seed, f.id, 314) * 0.7
			end
		end
	end
end

-- Answer birds. Flying birds scatter the flies under their
-- shadow, harder when low. Perched birds peck the nearest
-- catchable fly inside 48 px on a seeded timer. Reads birds,
-- writes only flies.
function insects.avoid_birds(list, birds, river, dt)
	if not birds then
		return
	end
	for bi = 1, #birds do
		local b = birds[bi]
		if b.state == "flying" or b.state == "takeoff" then
			local span = (b.type and b.type.alt or 60) + 40
			local r = 90 * (1 - (b.alt or 0) / span) + 30
			if r >= 25 then
				insects.startle_at(list, b.x, b.y, r)
			end
		elseif b.state == "perched" then
			b.peck_t = (b.peck_t or 5) - dt
			if b.peck_t <= 0 then
				local best, bd = nil, 48
				for i = 1, #list do
					local f = list[i]
					if (f.state == "swarm" or f.state == "skitter") and f.x then
						local dx, dy = f.x - b.x, f.y - b.y
						local d = math.sqrt(dx * dx + dy * dy)
						if d < bd then
							bd, best = d, f
						end
					end
				end
				if best then
					best.state = "taken"
					best.timer = 6 + hash01(best.seed, best.id, math.floor(insects._clock or 0) + 316) * 5
					if river.splash then
						river.splash:dimple(best.x, best.y, 2.5)
					end
					insects.startle_at(list, best.x, best.y, 30)
					b.peck_t = 4 + hash01(b.seed, b.id, b.trips + 513) * 5
				else
					b.peck_t = 2
				end
			end
		end
	end
end

-- Apply fish take events from the frame. Each event is
-- { x, y, kind } with kind gulp, jump, or miss. A gulp
-- eats the nearest catchable fly. Jump and miss only scatter.
function insects.apply_events(list, events, river)
	for e = 1, #events do
		local ev = events[e]
		if ev.kind == "gulp" then
			local best, bd = nil, 16
			for i = 1, #list do
				local f = list[i]
				if f.state == "swarm" or f.state == "skitter" then
					local dx, dy = f.x - ev.x, f.y - ev.y
					local d = math.sqrt(dx * dx + dy * dy)
					if d < bd then
						bd, best = d, f
					end
				end
			end
			if best then
				best.state = "taken"
				best.timer = 6 + hash01(best.seed, best.id, math.floor(insects._clock or 0) + 315) * 5
			end
			if river.splash then
				river.splash:ring(ev.x, ev.y, 7, 0.6)
			end
			insects.startle_at(list, ev.x, ev.y, 46)
		else
			if river.splash then
				river.splash:ring(ev.x, ev.y, ev.kind == "jump" and 13 or 9, 0.7)
			end
			insects.startle_at(list, ev.x, ev.y, ev.kind == "jump" and 70 or 50)
		end
	end
end

-- Two-pixel body, two flicker wings. Skitter sits on the
-- film, swarm rides above it with a faint shadow.
function insects.draw(list)
	for i = 1, #list do
		local f = list[i]
		if f.state ~= "taken" then
			local y = f.state == "swarm" and (f.y - f.hoff) or f.y
			if f.state == "swarm" then
				love.graphics.setColor(0.05, 0.08, 0.10, 0.22)
				love.graphics.ellipse("fill", f.x, f.y, 3, 1.4, 8)
			end
			local flick = math.sin(f.clock * 40 + f.phase) > 0
			love.graphics.setColor(0.85, 0.87, 0.82, flick and 0.9 or 0.45)
			love.graphics.line(f.x - 3, y - 1, f.x - 1, y)
			love.graphics.line(f.x + 3, y - 1, f.x + 1, y)
			love.graphics.setColor(0.12, 0.11, 0.10, 0.95)
			love.graphics.line(f.x - 2, y, f.x + 2, y)
		end
	end
end

return insects

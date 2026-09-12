-- Bank birds. Seeded visitors that cross the beat, perch on
-- emergent rocks, and lift again. Type follows the water: bed,
-- flow, and size set the mix. Fish scurry when one flies low
-- or drops onto a rock. Drawn simple: perched body and head,
-- flying body with two flap triangles, plus a water shadow.
local mathx = require "lib.math"

local birds = {}
local clamp, hash01, lerp, TAU = mathx.clamp, mathx.hash01, mathx.lerp, mathx.TAU

-- Four visitors. spook_r is the screen radius that scurries
-- fish. flow_pref 0 still water, 1 fast water. chest is a
-- bright bib that reads against grey rock. bob is the idle
-- dip amplitude so perched birds move.
birds.TYPES = {
	{ id = "heron", size = 22, body = { 0.52, 0.57, 0.62 }, wing = { 0.35, 0.40, 0.46 }, chest = { 0.84, 0.84, 0.80 }, beak = { 0.85, 0.70, 0.30 }, bob = 0.6, spook_r = 170, cruise = 130, alt = 90, beds = { silt = 1.0, peat = 0.9, gravel = 0.5, chalk = 0.5, bedrock = 0.3 }, flow_pref = 0.2, size_pref = 0.7 },
	{ id = "dipper", size = 11, body = { 0.28, 0.24, 0.20 }, wing = { 0.34, 0.30, 0.25 }, chest = { 0.93, 0.91, 0.85 }, beak = { 0.70, 0.65, 0.55 }, bob = 2.2, spook_r = 95, cruise = 170, alt = 55, beds = { bedrock = 1.0, gravel = 0.9, chalk = 0.5, silt = 0.3, peat = 0.3 }, flow_pref = 0.8, size_pref = 0.35 },
	{ id = "wagtail", size = 12, body = { 0.62, 0.62, 0.56 }, wing = { 0.30, 0.30, 0.26 }, chest = { 0.90, 0.86, 0.62 }, beak = { 0.20, 0.18, 0.16 }, bob = 1.2, spook_r = 105, cruise = 160, alt = 65, beds = { gravel = 1.0, chalk = 0.9, silt = 0.5, peat = 0.4, bedrock = 0.5 }, flow_pref = 0.5, size_pref = 0.45 },
	{ id = "kingfisher", size = 12, body = { 0.16, 0.50, 0.66 }, wing = { 0.12, 0.35, 0.48 }, chest = { 0.87, 0.47, 0.20 }, beak = { 0.15, 0.14, 0.12 }, bob = 0.8, spook_r = 120, cruise = 220, alt = 50, beds = { peat = 0.9, silt = 0.8, gravel = 0.6, chalk = 0.5, bedrock = 0.3 }, flow_pref = 0.35, size_pref = 0.4 },
}

-- Weight one type for this water. Form mirrors species
-- weights: bed sets the base, flow and size pull the mix.
local function weight(tp, char, flow_u, size_u)
	local bed_id = char.bed_type and char.bed_type.id or "gravel"
	local bed_w = (tp.beds and tp.beds[bed_id]) or 0.4
	local flow_w = 1 - math.min(1, math.abs(flow_u - tp.flow_pref) * 1.6)
	local size_w = 1 - math.min(1, math.abs(size_u - tp.size_pref) * 1.2)
	return 0.15 + bed_w * (0.35 + 0.65 * (0.5 * flow_w + 0.5 * size_w))
end

local function pick_type(char, flow_u, size_u, roll)
	local total = 0
	local ws = {}
	for i = 1, #birds.TYPES do
		ws[i] = weight(birds.TYPES[i], char, flow_u, size_u)
		total = total + ws[i]
	end
	local x = roll * total
	for i = 1, #birds.TYPES do
		x = x - ws[i]
		if x <= 0 then
			return birds.TYPES[i]
		end
	end
	return birds.TYPES[#birds.TYPES]
end

-- Perch length for one stay, 12 to 24 s from a seeded hash.
-- Long stays keep flights a rare event.
local function perch_dur(seed, id, n)
	return 12 + hash01(seed, id, n) * 12
end

-- Emergent rock candidates. Falls back to the largest rock,
-- then to a bank point when the beat has no stones.
local function perch_rocks(river)
	local list = river.obstacles or {}
	local cands = {}
	for i = 1, #list do
		local o = list[i]
		local s = river:sample(o.t, o.across)
		if s.depth < o.r * 0.85 then
			cands[#cands + 1] = i
		end
	end
	if #cands == 0 and #list > 0 then
		local big, bi = -1, 1
		for i = 1, #list do
			if list[i].r > big then
				big, bi = list[i].r, i
			end
		end
		cands[1] = bi
	end
	return cands
end

-- Spawn the seeded visitors. Most beats stay empty, some
-- get one bird, rich beats two. Each bird starts perched.
function birds.spawn(river, seed)
	-- Seed rides in the high spread slot so neighbouring
	-- seeds in the 1 to 24 band still vary the count.
	local u = hash01(77, 502, seed)
	local count = 1
	if u < 0.45 then
		count = 0
	elseif u < 0.93 then
		count = 1
	else
		count = 2
	end
	local char = river.char or {}
	local base = river.flow and river.flow.base_speed or 1
	local flow_u = clamp(((base - 0.45) / 1.1), 0, 1)
	local size_u = clamp((((char.water_half or 120) - 78) / 138), 0, 1)
	local cands = perch_rocks(river)
	local out = {}
	for i = 1, count do
		local tp = pick_type(char, flow_u, size_u, hash01(seed, i, 501))
		local rock = 0
		local t, across = 0.5, 0.5
		if #cands > 0 then
			rock = cands[math.floor(hash01(seed, i, 503) * #cands) + 1]
			local o = river.obstacles[rock]
			t, across = o.t, o.across
		else
			t = 0.2 + hash01(seed, i, 504) * 0.6
			across = hash01(seed, i, 505) < 0.5 and 0.10 or 0.90
		end
		local s = river:sample(t, across)
		out[#out + 1] = {
			kind = "bird", id = i, seed = seed, type = tp,
			state = "perched", timer = perch_dur(seed, i, 1),
			trips = 0, rock = rock, t = t, across = across,
			from_t = t, from_a = across, to_t = t, to_a = across,
			fx = s.x, fy = s.y, x = s.x, y = s.y,
			tx = s.x, ty = s.y, alt = 0, prog = 0, dur = 1,
			flap = hash01(seed, i, 506) * TAU,
			grace = 0, clock = hash01(seed, i, 507) * 10,
		}
	end
	return out
end

-- Choose a new perch rock unlike the current one.
local function next_rock(self, river, cands)
	if #cands == 0 then
		self.to_t = 0.2 + hash01(self.seed, self.id, self.trips + 508) * 0.6
		self.to_a = hash01(self.seed, self.id, self.trips + 509) < 0.5 and 0.10 or 0.90
		return 0
	end
	if #cands == 1 then
		return cands[1]
	end
	local at = 1
	for i = 1, #cands do
		if cands[i] == self.rock then
			at = i
			break
		end
	end
	local step = 1 + math.floor(hash01(self.seed, self.id, self.trips + 510) * (#cands - 1))
	return cands[((at - 1 + step) % #cands) + 1]
end

-- True while this bird threatens fish: flying, lifting off,
-- or just touched down. Perched birds are scenery.
function birds.threatening(b)
	return b.state == "flying" or b.state == "takeoff" or b.grace > 0
end

-- Tick clocks, hops, and flights. Landing rings the film.
function birds.update(list, dt, river)
	local cands = perch_rocks(river)
	for bi = 1, #list do
		local b = list[bi]
		b.clock = b.clock + dt
		b.grace = math.max(0, b.grace - dt)
		if b.state == "perched" then
			b.flap = b.flap + dt * 2
			b.timer = b.timer - dt
			local s = river:sample(b.t, b.across)
			b.x, b.y = s.x, s.y - (river.obstacles and b.rock > 0 and 6 or 0)
			b.alt = 0
			if b.timer <= 0 then
				b.trips = b.trips + 1
				local rock = next_rock(b, river, cands)
				b.rock = rock
				if rock > 0 then
					local o = river.obstacles[rock]
					b.to_t, b.to_a = o.t, o.across
				end
				local s2 = river:sample(b.to_t, b.to_a)
				b.tx, b.ty = s2.x, s2.y
				b.state = "takeoff"
				b.prog = 0
				b.dur = 0.45
				b.fx, b.fy = b.x, b.y
			end
		elseif b.state == "takeoff" then
			b.flap = b.flap + dt * 26
			b.prog = b.prog + dt / b.dur
			local u = clamp(b.prog, 0, 1)
			b.alt = b.type.alt * 0.45 * u
			b.x = lerp(b.fx, b.fx + (b.tx - b.fx) * 0.08, u)
			b.y = lerp(b.fy, b.fy + (b.ty - b.fy) * 0.08, u)
			if b.prog >= 1 then
				b.state = "flying"
				b.prog = 0
				local dx, dy = b.tx - b.x, b.ty - b.y
				b.dur = math.max(1.2, math.sqrt(dx * dx + dy * dy) / b.type.cruise)
				b.fx, b.fy = b.x, b.y
			end
		elseif b.state == "flying" then
			b.flap = b.flap + dt * 14
			b.prog = b.prog + dt / b.dur
			local u = clamp(b.prog, 0, 1)
			local wob = math.sin(u * math.pi) * 14 * math.sin(b.clock * 3.1 + b.id * 2.2)
			local dx, dy = b.tx - b.fx, b.ty - b.fy
			local len = math.max(1, math.sqrt(dx * dx + dy * dy))
			local nx, ny = -dy / len, dx / len
			b.x = lerp(b.fx, b.tx, u) + nx * wob
			b.y = lerp(b.fy, b.ty, u) + ny * wob
			b.alt = b.type.alt * math.sin(u * math.pi) + 8
			b.t = lerp(b.from_t, b.to_t, u)
			b.across = lerp(b.from_a, b.to_a, u)
			if b.prog >= 1 then
				b.state = "perched"
				b.t, b.across = b.to_t, b.to_a
				b.from_t, b.from_a = b.to_t, b.to_a
				b.timer = perch_dur(b.seed, b.id, b.trips + 511)
				b.grace = 1.6
				b.alt = 0
				if river.splash then
					river.splash:ring(b.tx, b.ty, 14, 0.8)
				end
			end
		end
	end
end

-- Soft shadow on the film. Shrinks and fades with height.
local function shadow(b)
	if b.alt <= 1 then
		return
	end
	local k = clamp(1 - b.alt / (b.type.alt + 40), 0.15, 0.7)
	love.graphics.setColor(0.05, 0.08, 0.10, 0.30 * k)
	love.graphics.ellipse("fill", b.x, b.y + 4, b.type.size * 0.7 * k + 4, 4, 0, 10)
end

-- Perched body: legs, outlined chest with a bright bib, head,
-- beak, tail. The dark outline and pale bib lift the bird off
-- grey rock. Idle bob keeps it alive while it sits.
local function draw_perched(b)
	local s = b.type.size / 12
	local bob = math.sin(b.clock * 6 + b.id * 2.4) * (b.type.bob or 1)
	local x, y = b.x, b.y + bob * 0.5
	love.graphics.setColor(0.16, 0.14, 0.12, 1)
	love.graphics.line(x - 3 * s, b.y, x - 3 * s, y - 8 * s)
	love.graphics.line(x + 3 * s, b.y, x + 3 * s, y - 8 * s)
	love.graphics.setColor(0.08, 0.07, 0.06, 1)
	love.graphics.ellipse("fill", x, y - 12 * s, 8.2 * s, 10.2 * s, 0.15, 12)
	love.graphics.circle("fill", x + 3 * s, y - 22 * s, 5.7 * s, 10)
	love.graphics.setColor(b.type.body[1], b.type.body[2], b.type.body[3], 1)
	love.graphics.ellipse("fill", x, y - 12 * s, 7 * s, 9 * s, 0.15, 12)
	love.graphics.circle("fill", x + 3 * s, y - 22 * s, 4.5 * s, 10)
	local chest = b.type.chest or { 0.9, 0.89, 0.84 }
	love.graphics.setColor(chest[1], chest[2], chest[3], 1)
	love.graphics.ellipse("fill", x + 1 * s, y - 11 * s, 3.8 * s, 5.5 * s, 0.15, 10)
	love.graphics.setColor(b.type.beak[1], b.type.beak[2], b.type.beak[3], 1)
	love.graphics.line(x + 6 * s, y - 22 * s, x + 12 * s, y - 20 * s)
	love.graphics.setColor(b.type.wing[1], b.type.wing[2], b.type.wing[3], 1)
	love.graphics.line(x - 6 * s, y - 8 * s, x - 12 * s, y - 2 * s)
end

-- Flying body with two flap triangles along the heading.
local function draw_flying(b)
	local x, y = b.x, b.y - b.alt
	local dx, dy = b.tx - b.fx, b.ty - b.fy
	local len = math.sqrt(dx * dx + dy * dy)
	local ang = len > 1 and math.atan2(dy, dx) or 0
	local s = b.type.size / 12
	local beat = math.sin(b.flap) * (6 + 4 * s)
	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.rotate(ang)
	love.graphics.setColor(b.type.wing[1], b.type.wing[2], b.type.wing[3], 1)
	love.graphics.polygon("fill", 0, 0, -4 * s, -10 * s - beat, -12 * s, -2 * s)
	love.graphics.polygon("fill", 0, 0, -4 * s, 10 * s + beat, -12 * s, 2 * s)
	love.graphics.setColor(b.type.body[1], b.type.body[2], b.type.body[3], 1)
	love.graphics.ellipse("fill", 0, 0, 8 * s, 3.2 * s, 0, 10)
	love.graphics.circle("fill", 7 * s, 0, 2.6 * s, 8)
	love.graphics.pop()
end

-- Shadows first, then bodies over the water.
function birds.draw(list)
	for i = 1, #list do
		shadow(list[i])
	end
	for i = 1, #list do
		local b = list[i]
		if b.state == "flying" or b.state == "takeoff" then
			draw_flying(b)
		else
			draw_perched(b)
		end
	end
end

return birds

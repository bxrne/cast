-- Bank birds. Seeded visitors that cross the beat, perch on
-- emergent rocks, and lift again. Type follows the water: bed,
-- flow, and size set the mix. Fish scurry when one flies low
-- or drops onto a rock. Drawn simple: perched body and head,
-- flying body with two flap triangles, plus a water shadow.
local mathx = require "lib.math"
local data = require "lib.data"

local birds = {}
local clamp, hash01, lerp, TAU = mathx.clamp, mathx.hash01, mathx.lerp, mathx.TAU

-- Two visitors from data/birds, one file per bird. Both big
-- waders, so the roster reads against any bed without
-- relying on the seed.
birds.TYPES = data.list("birds")

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

-- Emergent rock survey, cached per river build. Rocks never
-- move, so sampling them every frame is pure waste. Keyed
-- weak like the habitat grid so dead rivers drop out.
local survey_cache = setmetatable({}, { __mode = "k" })
local function survey(river)
	local hit = survey_cache[river]
	if hit and hit.id == river.cache_id then
		return hit.cands, hit.xy
	end
	local list = river.obstacles or {}
	local cands, xy = {}, {}
	for i = 1, #list do
		local o = list[i]
		local s = river:sample(o.t, o.across)
		xy[i] = { x = s.x, y = s.y }
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
	survey_cache[river] = { id = river.cache_id, cands = cands, xy = xy }
	return cands, xy
end

-- Emergent rock candidates. Falls back to the largest rock.
-- Bank points cover beats with no stones at all.
local function perch_rocks(river)
	local cands = survey(river)
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
			peck_t = 3 + hash01(seed, i, 512) * 5,
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
-- Perched poses read the cached survey. No sampling here.
function birds.update(list, dt, river)
	local cands, xy = survey(river)
	for bi = 1, #list do
		local b = list[bi]
		b.clock = b.clock + dt
		b.grace = math.max(0, b.grace - dt)
		if b.state == "perched" then
			b.flap = b.flap + dt * 2
			b.timer = b.timer - dt
			local p = xy[b.rock]
			if p then
				b.x, b.y = p.x, p.y - 6
			else
				local s = river:sample(b.t, b.across)
				b.x, b.y = s.x, s.y
			end
			b.alt = 0
			if b.timer <= 0 then
				b.trips = b.trips + 1
				b.from_t, b.from_a = b.t, b.across
				local rock = next_rock(b, river, cands)
				b.rock = rock
				if rock > 0 then
					local o = river.obstacles[rock]
					b.to_t, b.to_a = o.t, o.across
					b.tx, b.ty = xy[rock].x, xy[rock].y
				else
					local s2 = river:sample(b.to_t, b.to_a)
					b.tx, b.ty = s2.x, s2.y
				end
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
	love.graphics.ellipse("fill", b.x, b.y + 4, b.type.size * 0.7 * k + 4, 4, 10)
end

local OUTLINE = { 0.08, 0.07, 0.06 }

-- Perched wader: stilt legs with feet, level body, kinked
-- neck, dagger beak, tail wedge. Dark outline plus pale bib
-- lift it off grey rock. Idle bob keeps it alive. Herons
-- wear a black crest spike, egrets two nuchal plumes.
local function draw_perched(b)
	local s = b.type.size / 12
	local neck = b.type.neck or 1
	local bob = math.sin(b.clock * 6 + b.id * 2.4) * (b.type.bob or 1)
	local x, yb = b.x, b.y + bob * 0.5
	local leg, by = 13 * s, yb - 13 * s - 5 * s
	love.graphics.setColor(0.12, 0.11, 0.10, 1)
	love.graphics.line(x - 3 * s, yb, x - 3 * s, yb - leg)
	love.graphics.line(x + 3 * s, yb, x + 3 * s, yb - leg)
	love.graphics.line(x - 3 * s, yb, x - 6 * s, yb)
	love.graphics.line(x + 3 * s, yb, x + 6 * s, yb)
	love.graphics.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 1)
	love.graphics.ellipse("fill", x, by, 11 * s, 7 * s, 12)
	love.graphics.setColor(b.type.body[1], b.type.body[2], b.type.body[3], 1)
	love.graphics.ellipse("fill", x, by, 10 * s, 6 * s, 12)
	love.graphics.polygon("fill", x - 9 * s, by - 1 * s, x - 15 * s, by - 4 * s, x - 9 * s, by - 5 * s)
	local chest = b.type.chest or { 0.9, 0.89, 0.84 }
	love.graphics.setColor(chest[1], chest[2], chest[3], 1)
	love.graphics.ellipse("fill", x + 3 * s, by + 1 * s, 4.5 * s, 4 * s, 10)
	local kx, ky = x + 11 * s, by - 12 * s * neck
	local hx, hy = x + 9 * s, by - 21 * s * neck
	love.graphics.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 1)
	love.graphics.setLineWidth(4 * s)
	love.graphics.line(x + 7 * s, by - 2 * s, kx, ky, hx, hy)
	love.graphics.setLineWidth(1)
	love.graphics.setColor(b.type.body[1], b.type.body[2], b.type.body[3], 1)
	love.graphics.line(x + 7 * s, by - 2 * s, kx, ky, hx, hy)
	love.graphics.circle("fill", hx, hy, 3.6 * s, 10)
	love.graphics.setColor(b.type.beak[1], b.type.beak[2], b.type.beak[3], 1)
	love.graphics.polygon("fill", hx + 2 * s, hy - 1 * s, hx + 11 * s, hy + 0.5 * s, hx + 2 * s, hy + 2 * s)
	if b.type.id == "heron" then
		love.graphics.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 1)
		love.graphics.line(hx - 2 * s, hy - 2 * s, hx - 9 * s, hy - 5 * s)
	else
		love.graphics.setColor(chest[1], chest[2], chest[3], 1)
		love.graphics.line(hx - 2 * s, hy - 2 * s, hx - 8 * s, hy - 4 * s)
		love.graphics.line(hx - 2 * s, hy - 1 * s, hx - 8 * s, hy - 2 * s)
	end
end

-- Flying wader: folded head, broad fingered wings, tail fan,
-- legs trailing past the tail. Wings beat around the glide.
local function draw_flying(b)
	local x, y = b.x, b.y - b.alt
	local dx, dy = b.tx - b.fx, b.ty - b.fy
	local len = math.sqrt(dx * dx + dy * dy)
	local ang = len > 1 and math.atan2(dy, dx) or 0
	local s = b.type.size / 12
	local beat = math.sin(b.flap) * (5 + 3 * s)
	love.graphics.push()
	love.graphics.translate(x, y)
	love.graphics.rotate(ang)
	love.graphics.setColor(0.12, 0.11, 0.10, 1)
	love.graphics.line(-6 * s, -1.5 * s, -16 * s, -1.5 * s)
	love.graphics.line(-6 * s, 1.5 * s, -16 * s, 1.5 * s)
	love.graphics.line(-16 * s, -1.5 * s, -18 * s, -1.5 * s)
	love.graphics.line(-16 * s, 1.5 * s, -18 * s, 1.5 * s)
	love.graphics.setColor(b.type.wing[1], b.type.wing[2], b.type.wing[3], 1)
	love.graphics.polygon("fill", -7 * s, 0, -13 * s, -4 * s, -13 * s, 4 * s)
	love.graphics.setColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], 1)
	love.graphics.ellipse("fill", 0, 0, 10 * s, 4 * s, 12)
	love.graphics.setColor(b.type.body[1], b.type.body[2], b.type.body[3], 1)
	love.graphics.ellipse("fill", 0, 0, 9 * s, 3.2 * s, 10)
	love.graphics.circle("fill", 6 * s, -1 * s, 2.8 * s, 8)
	love.graphics.setColor(b.type.beak[1], b.type.beak[2], b.type.beak[3], 1)
	love.graphics.polygon("fill", 8 * s, -1.6 * s, 12 * s, -0.6 * s, 8 * s, 0.4 * s)
	love.graphics.setColor(b.type.body[1], b.type.body[2], b.type.body[3], 1)
	love.graphics.polygon("fill", 0, -1 * s, -5 * s, -13 * s - beat, -11 * s, -4 * s)
	love.graphics.polygon("fill", 0, 1 * s, -5 * s, 13 * s + beat, -11 * s, 4 * s)
	love.graphics.setColor(b.type.wing[1], b.type.wing[2], b.type.wing[3], 1)
	love.graphics.line(-5 * s, -13 * s - beat, -11 * s, -4 * s)
	love.graphics.line(-5 * s, 13 * s + beat, -11 * s, 4 * s)
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

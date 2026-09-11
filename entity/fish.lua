local bt = require "entity.bt"
local species = require "entity.species"
local mind = require "entity.mind"
local habitat = require "entity.habitat"
local mathx = require "lib.math"

local fish = {}
local clamp, hash01, lerp, mix3 = mathx.clamp, mathx.hash01, mathx.lerp, mathx.mix3
local MANNERS = {
	sip = { duration = 0.55, height = 2.2, ring = 6, drops = 0 },
	rise = { duration = 1.05, height = 5.5, ring = 12, drops = 3 },
	head_and_tail = { duration = 1.35, height = 4.2, ring = 10, drops = 2 },
	splash = { duration = 0.7, height = 6.5, ring = 16, drops = 7 },
	porpoise = { duration = 1.7, height = 7.5, ring = 14, drops = 5 },
}

-- Reused scratch for pose lookups. No alloc in the hot loop.
local SCRATCH = {}
local ORDER = {}

-- Choose a habitat lie from the cached river grid.
local function pick_lie(self, river, extra)
	local cells = river.cells or habitat.grid(river)
	local taken = { { t = self.t, across = self.across } }
	local pick = habitat.best(cells, self.species, river, extra and {} or taken, extra)
	self.target_t = pick.t
	self.target_across = habitat.channel_across(pick.across)
end

-- Pick a surface manner from the species list using a seeded hash.
local function pick_manner(self)
	local manners = self.species.manners
	return manners[math.floor(hash01(self.id, self.rises + 1, self.seed) * #manners) + 1]
end

-- True when a film-feeding fish should break the surface.
local function due_to_rise(self)
	if self.surface then
		return true
	end
	if self.phase ~= "film" or self.column < 0.72 then
		return false
	end
	if not self.at_lie or self.hold_time < self.period then
		return false
	end
	local depth_n = self.sample and self.sample.depth_n or 1
	return depth_n <= self.species.rise_depth
end

-- Step toward the current target. Returns true on arrival.
local function move_toward(self, river, dt, pace)
	local dt_t, dt_a = self.target_t - self.t, self.target_across - self.across
	local dist = math.sqrt(dt_t * dt_t + dt_a * dt_a * 0.15)
	if dist < 0.012 then
		self.t, self.across, self.at_lie, self.target_t = self.target_t, self.target_across, true, nil
		return true
	end
	local k = math.min(1, (pace or self.cruise) * dt / dist)
	self.t = clamp(self.t + dt_t * k, 0.05, 0.95)
	self.across = habitat.channel_across(self.across + dt_a * k)
	self.at_lie, self.hold_time = false, 0
	river:sample_into(self.t, self.across, nil, SCRATCH)
	self.hx, self.hy = SCRATCH.tx, SCRATCH.ty
	return false
end

-- Emit breach spray. Count scales with the manner.
local function breach_fx(river, self, spec)
	if not river.splash then return end
	river.splash:ring(self.x, self.y, spec.ring, 0.7)
	for i = 1, spec.drops do
		local a = hash01(self.id, self.rises, i) * 6.283
		local sp = 40 + hash01(i, self.id, 7) * 90
		river.splash:drop(self.x, self.y - 2, math.cos(a) * sp, -50 - hash01(i, 3, 9) * 90, 0.4, 1.6)
	end
end

-- Bolt deep and away from the player while spooked.
local function act_flee(ctx)
	local self = ctx.fish
	if mind.spooked(self, ctx.player, ctx.river) then
		self.spook_t = math.max(self.spook_t, 1.1 + self.species.skittish)
	end
	if self.spook_t <= 0 then
		return bt.FAILURE
	end
	self.activity = "burst"
	self.spook_t = self.spook_t - ctx.dt
	if not self.target_t then
		local player = ctx.player
		pick_lie(self, ctx.river, function(sample)
			local away = player and math.abs(sample.t - player.t) or 0
			return sample.depth_n * 1.4 + away * 0.8
		end)
	end
	move_toward(self, ctx.river, ctx.dt, self.cruise * 1.7)
	return bt.RUNNING
end

-- Push a weaker fish off its lie.
local function act_bully(ctx)
	local self = ctx.fish
	if self.species.aggression < 0.45 or self.spook_t > 0 then
		return bt.FAILURE
	end
	local other = mind.rival(self, ctx.list)
	if not other then
		self.chase_t = 0
		return bt.FAILURE
	end
	self.chase_t = (self.chase_t or 0) + ctx.dt
	if self.chase_t > 2.4 then
		self.chase_t = 0
		return bt.SUCCESS
	end
	self.activity = "chase"
	self.target_t, self.target_across = other.t, habitat.channel_across(other.across)
	move_toward(self, ctx.river, ctx.dt, self.cruise * 1.35)
	local dx, dy = self.x - other.x, self.y - other.y
	if dx * dx + dy * dy < 22 * 22 then
		other.spook_t = math.max(other.spook_t, 1.3)
		other.at_lie, other.target_t = false, nil
	end
	return bt.RUNNING
end

-- Rise if due, then play the surface clip.
local function act_rise(ctx)
	local self = ctx.fish
	if not self.surface then
		if not due_to_rise(self) then
			return bt.FAILURE
		end
		local name = pick_manner(self)
		local spec = MANNERS[name]
		self.surface = { t = 0, duration = spec.duration, height = spec.height, ring = spec.ring, name = name }
		self.activity = "rise"
		breach_fx(ctx.river, self, spec)
	end
	self.surface.t = self.surface.t + ctx.dt
	if self.surface.t >= self.surface.duration then
		if ctx.river.splash then
			ctx.river.splash:ring(self.x, self.y, self.surface.ring * 0.7, 0.6)
		end
		self.surface, self.hold_time, self.rises = nil, 0, self.rises + 1
		return bt.SUCCESS
	end
	return bt.RUNNING
end

-- Swim to a lie when not already holding.
local function act_seek(ctx)
	local self = ctx.fish
	if self.at_lie then
		return bt.FAILURE
	end
	self.activity = "cruise"
	if not self.target_t then
		pick_lie(self, ctx.river)
	end
	return move_toward(self, ctx.river, ctx.dt) and bt.SUCCESS or bt.RUNNING
end

-- Hold, nymph-drift, or rest according to feed phase.
local function act_feed(ctx)
	local self = ctx.fish
	ctx.river:sample_into(self.t, self.across, ctx.river.time, SCRATCH)
	self.at_lie = true
	self.hold_time = self.hold_time + ctx.dt
	self.hx, self.hy = -SCRATCH.tx, -SCRATCH.ty
	self.across = habitat.channel_across(self.home_across or self.across)
	if self.phase == "rest" then
		self.activity = "rest"
	elseif self.phase == "nymph" then
		self.activity = "drift"
	else
		self.activity = "hold"
	end
	if self.phase == "nymph" then
		self.t = clamp(self.t + SCRATCH.speed * ctx.dt * 0.032, 0.05, 0.95)
		if math.abs(self.t - (self.home_t or self.t)) > 0.05 then
			self.target_t, self.target_across, self.at_lie = self.home_t, self.home_across, false
		end
	end
	return bt.SUCCESS
end

-- Flee, else bully, else rise, else seek, else feed.
local function tree()
	return bt.selector({
		bt.action(act_flee),
		bt.action(act_bully),
		bt.action(act_rise),
		bt.action(act_seek),
		bt.action(act_feed),
	})
end

-- Copy world pose from the flow field, with live eddy headings.
local function sync_pose(self, river, live)
	if live then
		river:sample_into(self.t, self.across, river.time, SCRATCH)
	else
		river:sample_into(self.t, self.across, nil, SCRATCH)
	end
	self.x, self.y = SCRATCH.x, SCRATCH.y
	if not self.sample then self.sample = {} end
	self.sample.depth_n = SCRATCH.depth_n
	self.sample.speed = SCRATCH.speed
	if not self.hx then
		self.hx, self.hy = -SCRATCH.tx, -SCRATCH.ty
	end
end

-- Spawn a seeded school on ranked habitat lies, already holding.
-- Taxa follow the water. Bed, flow, and size set the mix. Each
-- fish gets a tuned copy, so behaviour fits the beat.
function fish.spawn(river, seed, count)
	count = count or (6 + math.floor(hash01(seed, 4, 8) * 11))
	count = mathx.clamp(math.floor(count), 0, 24)
	local weights = species.weights(river.char)
	local clar = mind.clarity(river)
	local specs = {}
	for i = 1, count do
		local base = species.pick(weights, hash01(seed, i, 3))
		specs[i] = species.instantiate(base, river.char, clar)
	end
	local spots = habitat.place(river, specs)
	local list = {}
	for i = 1, count do
		local spec, spot = specs[i], spots[i]
		local u = hash01(seed, i, 9)
		local length = spec.length_cm[1] + u * (spec.length_cm[2] - spec.length_cm[1])
		local across = habitat.channel_across(spot.across)
		local self = {
			kind = "fish", id = i, seed = seed, species = spec, length = length,
			t = spot.t, across = across,
			home_t = spot.t, home_across = across, column = 0.2,
			at_lie = true, rises = 0, spook_t = 0, chase_t = 0, clock = 0,
			phase_off = hash01(seed, i, 41) * spec.feed_period,
			hold_time = hash01(seed, i, 29) * spec.surface_period * 0.4,
			cruise = spec.cruise * (0.75 + 0.4 * (length / spec.length_cm[2])),
			period = spec.surface_period * (0.7 + 0.5 * (length - spec.length_cm[1]) / (spec.length_cm[2] - spec.length_cm[1])),
			dimple_t = 2 + hash01(seed, i, 55) * 6,
			activity = "hold",
			tree = bt.clone(tree()),
		}
		self.phase = mind.phase(self)
		self.column = mind.column_target(self, self.phase)
		sync_pose(self, river, false)
		self.x, self.y = SCRATCH.x, SCRATCH.y
		list[i] = self
	end
	return list
end

-- Rare faint dimple from a holding fish near the film. No
-- wake while swimming. One touch, at most two.
local function dimple(self, river, dt)
	if self.surface or not self.at_lie then return end
	if self.column < 0.7 then return end
	if self.activity ~= "hold" and self.activity ~= "drift" then return end
	self.dimple_t = (self.dimple_t or 5) - dt
	if self.dimple_t > 0 then return end
	self.dimple_t = 4 + hash01(self.id, math.floor(self.clock), 77) * 5
	if river.splash then
		river.splash:dimple(self.x, self.y - 1, 3 + hash01(self.id, self.rises + 1, 5) * 2)
		if hash01(self.id, self.rises, 11) < 0.3 then
			river.splash:dimple(self.x + 5, self.y + 2, 2.5)
		end
	end
end

-- Tick every fish tree, then move each one through the water column.
function fish.update(list, dt, river, player)
	for i = 1, #list do
		local self = list[i]
		self.clock = self.clock + dt
		self.phase = mind.phase(self)
		bt.tick(self.tree, { fish = self, river = river, dt = dt, player = player, list = list })
		mind.approach_column(self, mind.column_target(self, self.phase), dt)
		dimple(self, river, dt)
		local ot, oa = self.t, self.across
		self.t, self.across = river:push_out(self.t, self.across)
		sync_pose(self, river, true)
		if ot == self.t and oa == self.across then
			-- pose already fresh, no second lookup
		end
		if self.at_lie then
			self.home_t, self.home_across = self.t, self.across
		end
	end
end

-- One body segment. Lateral offset bends the spine. Head stays
-- planted when effort is low. Only the tail works.
local function segment(self, s, len, phase, slither, tail_amp, steady)
	local along = (s - 0.5) * len
	local wave = math.sin(phase - s * 5.2)
	local env = slither * (0.4 + 0.6 * s) + tail_amp * s * s
	local damp = steady * (0.2 + 0.8 * s) + (1 - steady)
	local lat = wave * env * damp * len * 0.10
	local w = len * (0.16 * (1 - math.abs(s - 0.42) * 1.5) + 0.03)
	if w < 1 then w = 1 end
	return along, lat, w
end

-- Swim effort by activity. Freq scales beat, amp scales tail.
-- Holds barely move. Head stays still, tail ticks over.
-- Bursts go full tail driven.
local ACT = {
	rest = { freq = 0.25, amp = 0.10, slide = 0.4, steady = 1.0 },
	drift = { freq = 0.4, amp = 0.16, slide = 0.5, steady = 1.0 },
	hold = { freq = 0.45, amp = 0.18, slide = 0.5, steady = 1.0 },
	cruise = { freq = 1.25, amp = 0.95, slide = 0.6, steady = 0.0 },
	chase = { freq = 1.7, amp = 1.25, slide = 0.35, steady = 0.0 },
	burst = { freq = 2.0, amp = 1.4, slide = 0.3, steady = 0.0 },
	rise = { freq = 1.8, amp = 1.3, slide = 0.4, steady = 0.0 },
}

-- Draw deep fish first. Visibility follows water clarity, column
-- height, and the feed phase; only a rising fish shows on the film.
function fish.draw(list, river)
	local clar = river and mind.clarity(river) or 0.5
	local deep = river and river.char.water_deep or { 0.10, 0.20, 0.30 }
	for i = 1, #list do ORDER[i] = list[i] end
	for i = #list + 1, #ORDER do ORDER[i] = nil end
	table.sort(ORDER, function(a, b) return a.column < b.column end)
	for i = 1, #list do
		local self = ORDER[i]
		local col = self.column
		local len = self.length * 0.42 * lerp(0.58, 1.12, col)
		local lift, vis = 0, math.max(0.04, col ^ 1.4 * (0.2 + 0.8 * clar))
		local ang = math.atan2(self.hy, self.hx)
		local beat = self.species.beat or 4
		local act = ACT[self.activity] or ACT.hold
		local phase = self.clock * beat * act.freq * 6.283 + self.id * 1.7
		local slither = (self.species.slither or 0.3) * act.slide
		local tail_amp = (self.species.tail_amp or 0.8) * act.amp + 0.1
		if self.surface and col > 0.7 then
			local u = self.surface.t / self.surface.duration
			local arch = math.sin(u * math.pi)
			lift = -self.surface.height * arch
			vis = 0.95
			tail_amp = tail_amp * (1 + arch * 1.2)
		end
		local sink = (1 - col) * 0.62
		local body = mix3(self.species.color, deep, sink)
		local stripe = mix3(self.species.stripe, deep, sink)
		local ca, sa = math.cos(ang), math.sin(ang)
		-- Hold surge. The whole fish breathes a touch along its
		-- heading instead of shivering in place.
		local surge = 0
		if act.steady > 0 then
			surge = math.sin(phase * 0.5) * len * 0.03 * act.steady
		end
		love.graphics.setColor(body[1], body[2], body[3], vis)
		for s = 1, 5 do
			local u = s / 6
			local along, lat, w = segment(self, u, len, phase, slither, tail_amp, act.steady)
			local wx = self.x + ca * (along + surge) - sa * lat
			local wy = self.y + lift + sa * (along + surge) + ca * lat
			love.graphics.ellipse("fill", wx, wy, len * 0.11, w * 0.5, ang, 8)
		end
		love.graphics.setColor(stripe[1], stripe[2], stripe[3], vis)
		local tu = 0.82
		local along, lat = segment(self, tu, len, phase, slither, tail_amp * 1.2, act.steady)
		local tx = self.x + ca * (along + surge) - sa * lat
		local ty = self.y + lift + sa * (along + surge) + ca * lat
		local flick = math.sin(phase - tu * 5.2) * tail_amp * len * 0.06
		love.graphics.push()
		love.graphics.translate(tx, ty)
		love.graphics.rotate(ang + flick * 0.12)
		love.graphics.polygon("fill", 0, 0, -len * 0.16, len * 0.07 + flick * 0.3, -len * 0.16, -len * 0.07 + flick * 0.3)
		love.graphics.pop()
	end
end

-- Feed-phase tint used in the tag underline.
local PHASE_TINT = {
	rest = { 0.62, 0.66, 0.56 },
	nymph = { 0.42, 0.64, 0.74 },
	emerge = { 0.56, 0.76, 0.62 },
	film = { 0.94, 0.80, 0.50 },
}

-- Column-depth meter: a thin bar with a marker at the fish height.
local function depth_meter(x, y, column)
	love.graphics.setColor(0.86, 0.92, 0.86, 0.30)
	love.graphics.setLineWidth(1)
	love.graphics.line(x, y - 1, x, y + 13)
	love.graphics.setColor(0.86, 0.92, 0.86, 0.85)
	local my = y + 12 - 12 * column
	love.graphics.circle("fill", x, my, 2.2, 8)
end

-- Tags for each trout: species dot, phase tint, and column height.
-- Label text caches at 5 Hz to avoid per frame format churn.
function fish.draw_indicators(list)
	love.graphics.push("all")
	for i = 1, #list do
		local self = list[i]
		if not self._tag_t or self.clock - self._tag_t > 0.2 then
			self._tag = string.format("%-7s %s %3.0f%%", self.species.id, self.phase, self.column * 100)
			self._tag_t = self.clock
		end
		local label = self._tag
		local tw = love.graphics.getFont():getWidth(label)
		local w, h = tw + 30, 16
		local x, y = math.floor(self.x + 9), math.floor(self.y - 12)
		love.graphics.setColor(0.06, 0.07, 0.05, 0.72)
		love.graphics.rectangle("fill", x, y, w, h, 4, 4)
		love.graphics.setColor(1, 1, 1, 0.12)
		love.graphics.rectangle("line", x, y, w, h, 4, 4)
		local c = self.species.color
		love.graphics.setColor(c[1], c[2], c[3], 0.95)
		love.graphics.circle("fill", x + 9, y + 8, 3.4, 8)
		local tint = PHASE_TINT[self.phase] or { 0.8, 0.8, 0.7 }
		love.graphics.setColor(tint[1], tint[2], tint[3], 0.9)
		love.graphics.rectangle("fill", x + 15, y + h - 2, w - 30, 2, 1, 1)
		love.graphics.setColor(0.90, 0.88, 0.72, 0.97)
		love.graphics.print(label, x + 17, y + 2)
		depth_meter(x + w - 4, y + 2, self.column)
	end
	love.graphics.pop()
end

return fish

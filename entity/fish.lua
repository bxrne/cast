local bt = require "entity.bt"
local species = require "entity.species"
local mind = require "entity.mind"
local habitat = require "entity.habitat"
local mathx = require "lib.math"

local fish = {}
local clamp, hash01, lerp, mix3 = mathx.clamp, mathx.hash01, mathx.lerp, mathx.mix3
local MANNERS = {
	sip = { duration = 0.55, height = 2.2, ring = 6 },
	rise = { duration = 1.05, height = 5.5, ring = 12 },
	head_and_tail = { duration = 1.35, height = 4.2, ring = 10 },
	splash = { duration = 0.7, height = 6.5, ring = 16 },
	porpoise = { duration = 1.7, height = 7.5, ring = 14 },
}

-- Choose a habitat lie. Optional extra(sample) bonus for flee, etc.
local function pick_lie(self, river, extra)
	local cells = habitat.grid(river)
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
	local sample = river:sample(self.t, self.across)
	self.hx, self.hy = sample.tx, sample.ty
	return false
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
		local spec = MANNERS[pick_manner(self)]
		self.surface = { t = 0, duration = spec.duration, height = spec.height, ring = spec.ring }
	end
	self.surface.t = self.surface.t + ctx.dt
	if self.surface.t >= self.surface.duration then
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
	if not self.target_t then
		pick_lie(self, ctx.river)
	end
	return move_toward(self, ctx.river, ctx.dt) and bt.SUCCESS or bt.RUNNING
end

-- Hold, nymph-drift, or rest according to feed phase.
local function act_feed(ctx)
	local self, sample = ctx.fish, ctx.river:sample_live(ctx.fish.t, ctx.fish.across)
	self.at_lie = true
	self.hold_time = self.hold_time + ctx.dt
	self.hx, self.hy = -sample.tx, -sample.ty
	self.across = habitat.channel_across(self.home_across or self.across)
	if self.phase == "nymph" then
		self.t = clamp(self.t + sample.speed * ctx.dt * 0.032, 0.05, 0.95)
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
local function sync_pose(self, river)
	local sample = river:sample_live(self.t, self.across)
	self.x, self.y, self.sample = sample.x, sample.y, sample
	if not self.hx then
		self.hx, self.hy = -sample.tx, -sample.ty
	end
end

-- Spawn a seeded school on ranked habitat lies, already holding.
function fish.spawn(river, seed, count)
	count = count or (6 + math.floor(hash01(seed, 4, 8) * 11))
	count = mathx.clamp(math.floor(count), 0, 24)
	local specs = {}
	for i = 1, count do
		specs[i] = species.at(math.floor(hash01(seed, i, 3) * #species.list) + 1)
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
			tree = bt.clone(tree()),
		}
		self.phase = mind.phase(self)
		self.column = mind.column_target(self, self.phase)
		sync_pose(self, river)
		list[i] = self
	end
	return list
end

-- Tick every fish tree, then move each one through the water column.
function fish.update(list, dt, river, player)
	for i = 1, #list do
		local self = list[i]
		self.clock = self.clock + dt
		self.phase = mind.phase(self)
		bt.tick(self.tree, { fish = self, river = river, dt = dt, player = player, list = list })
		mind.approach_column(self, mind.column_target(self, self.phase), dt)
		sync_pose(self, river)
		if self.at_lie then
			self.home_t, self.home_across = self.t, self.across
		end
	end
end

-- Draw deep fish first. Size and opacity follow column height.
function fish.draw(list)
	local order = {}
	for i = 1, #list do
		order[i] = list[i]
	end
	table.sort(order, function(a, b)
		return a.column < b.column
	end)
	for i = 1, #order do
		local self = order[i]
		local col = self.column
		local len = self.length * 0.42 * lerp(0.58, 1.12, col)
		local lift, alpha = 0, lerp(0.32, 1, col)
		if self.surface and col > 0.7 then
			local u = self.surface.t / self.surface.duration
			local arch = math.sin(u * math.pi)
			lift = -self.surface.height * arch
			love.graphics.setColor(0.78, 0.84, 0.80, 0.22 * arch)
			love.graphics.ellipse("line", self.x, self.y, self.surface.ring * (0.4 + 0.6 * u), self.surface.ring * 0.35 * (0.4 + 0.6 * u))
		end
		local body = mix3(self.species.color, { 0.08, 0.12, 0.16 }, 1 - col)
		local stripe = mix3(self.species.stripe, { 0.12, 0.14, 0.16 }, 1 - col)
		love.graphics.push()
		love.graphics.translate(self.x, self.y + lift)
		love.graphics.rotate(math.atan2(self.hy, self.hx))
		love.graphics.setColor(body[1], body[2], body[3], alpha)
		love.graphics.ellipse("fill", 0, 0, len * 0.5, len * 0.16)
		love.graphics.setColor(stripe[1], stripe[2], stripe[3], alpha)
		love.graphics.ellipse("fill", -len * 0.02, 0, len * 0.28, len * 0.07)
		love.graphics.pop()
	end
end

-- Labels for each trout: species, feed phase, and column.
function fish.draw_indicators(list)
	for i = 1, #list do
		local self = list[i]
		local label = string.format("%s  %s  %.0f%%", self.species.id, self.phase, self.column * 100)
		love.graphics.setColor(0.10, 0.12, 0.08, 0.7)
		love.graphics.rectangle("fill", self.x + 8, self.y - 12, 6 * #label + 4, 14, 2, 2)
		love.graphics.setColor(0.90, 0.86, 0.68)
		love.graphics.print(label, self.x + 10, self.y - 12)
	end
end

return fish

local bt = require "entity.bt"
local species = require "entity.species"

local fish = {}

local MAX_SEARCH_T = 24
local MAX_SEARCH_A = 7
local MANNERS = {
	sip = { duration = 0.55, height = 2.2, ring = 6 },
	rise = { duration = 1.05, height = 5.5, ring = 12 },
	head_and_tail = { duration = 1.35, height = 4.2, ring = 10 },
	splash = { duration = 0.7, height = 6.5, ring = 16 },
	porpoise = { duration = 1.7, height = 7.5, ring = 14 },
}

local function fract(x)
	return x - math.floor(x)
end

local function hash01(a, b, c)
	return fract(math.sin(a * 127.1 + (b or 0) * 311.7 + (c or 0) * 74.7) * 43758.5453)
end

local function clamp(x, lo, hi)
	if x < lo then
		return lo
	end
	if x > hi then
		return hi
	end
	return x
end

local function lie_value(sample, spec, river)
	local score = river:lie_score(sample)
	score = score + spec.cover_need * sample.pressure * 0.35
	score = score - (1 - spec.current_tolerance) * sample.speed * 0.4
	local edge = math.min(sample.across, 1 - sample.across)
	score = score + spec.edge_bias * (0.35 - edge) * 0.8
	return score
end

local function pick_lie(self, river)
	local best, bt_t, ba = -1e9, self.t, self.across
	for i = 1, MAX_SEARCH_T do
		local t = clamp(self.t + (i / MAX_SEARCH_T - 0.5) * 0.4, 0.06, 0.94)
		for j = 1, MAX_SEARCH_A do
			local across = 0.14 + (j - 1) / (MAX_SEARCH_A - 1) * 0.72
			local sample = river:sample(t, across)
			local score = lie_value(sample, self.species, river)
			if score > best then
				best = score
				bt_t = t
				ba = across
			end
		end
	end
	self.target_t = bt_t
	self.target_across = ba
end

local function pick_manner(self)
	local manners = self.species.manners
	local u = hash01(self.id, self.rises + 1, self.seed)
	local i = math.floor(u * #manners) + 1
	return manners[i]
end

local function due_to_rise(self)
	if not self.at_lie then
		return false
	end
	if self.surface then
		return true
	end
	return self.hold_time >= self.period
end

local function start_rise(self)
	local name = pick_manner(self)
	local spec = MANNERS[name]
	self.surface = {
		name = name,
		t = 0,
		duration = spec.duration,
		height = spec.height,
		ring = spec.ring,
	}
end

local function move_toward(self, river, dt)
	local dt_t = self.target_t - self.t
	local dt_a = self.target_across - self.across
	local dist = math.sqrt(dt_t * dt_t + dt_a * dt_a * 0.15)
	if dist < 0.012 then
		self.t = self.target_t
		self.across = self.target_across
		self.at_lie = true
		self.target_t = nil
		return true
	end
	local step = self.cruise * dt
	local k = step / dist
	if k > 1 then
		k = 1
	end
	self.t = clamp(self.t + dt_t * k, 0.05, 0.95)
	self.across = clamp(self.across + dt_a * k, 0.12, 0.88)
	self.at_lie = false
	self.hold_time = 0
	local sample = river:sample(self.t, self.across)
	self.hx, self.hy = sample.tx, sample.ty
	return false
end

local function tree()
	return bt.selector({
		bt.action(function(ctx)
			local self = ctx.fish
			if not self.surface then
				if not due_to_rise(self) then
					return bt.FAILURE
				end
				start_rise(self)
			end
			self.surface.t = self.surface.t + ctx.dt
			if self.surface.t >= self.surface.duration then
				self.surface = nil
				self.hold_time = 0
				self.rises = self.rises + 1
				return bt.SUCCESS
			end
			return bt.RUNNING
		end),
		bt.action(function(ctx)
			local self = ctx.fish
			if self.at_lie then
				return bt.FAILURE
			end
			if not self.target_t then
				pick_lie(self, ctx.river)
			end
			if move_toward(self, ctx.river, ctx.dt) then
				return bt.SUCCESS
			end
			return bt.RUNNING
		end),
		bt.action(function(ctx)
			local self = ctx.fish
			self.at_lie = true
			self.hold_time = self.hold_time + ctx.dt
			local sample = ctx.river:sample(self.t, self.across)
			self.hx, self.hy = -sample.tx, -sample.ty
			return bt.SUCCESS
		end),
	})
end

local function sync_pose(self, river)
	local sample = river:sample(self.t, self.across)
	self.x = sample.x
	self.y = sample.y
	if not self.hx then
		self.hx, self.hy = -sample.tx, -sample.ty
	end
	self.sample = sample
end

function fish.spawn(river, seed, count)
	count = math.max(0, math.min(24, math.floor(count or 10)))
	local list = {}
	for i = 1, count do
		local spec = species.at(math.floor(hash01(seed, i, 3) * #species.list) + 1)
		local u = hash01(seed, i, 9)
		local length = spec.length_cm[1] + u * (spec.length_cm[2] - spec.length_cm[1])
		local t = 0.08 + hash01(seed, i, 17) * 0.84
		local across = 0.2 + hash01(seed, i, 21) * 0.6
		local self = {
			kind = "fish",
			id = i,
			seed = seed,
			species = spec,
			length = length,
			t = t,
			across = across,
			at_lie = false,
			hold_time = hash01(seed, i, 29) * spec.surface_period * 0.4,
			rises = 0,
			cruise = spec.cruise * (0.75 + 0.4 * (length / spec.length_cm[2])),
			period = spec.surface_period * (0.7 + 0.5 * (length - spec.length_cm[1]) / (spec.length_cm[2] - spec.length_cm[1])),
			tree = bt.clone(tree()),
		}
		sync_pose(self, river)
		pick_lie(self, river)
		list[i] = self
	end
	return list
end

function fish.update(list, dt, river)
	for i = 1, #list do
		local self = list[i]
		bt.tick(self.tree, { fish = self, river = river, dt = dt })
		sync_pose(self, river)
	end
end

function fish.draw(list)
	for i = 1, #list do
		local self = list[i]
		local len = self.length * 0.42
		local lift = 0
		if self.surface then
			local u = self.surface.t / self.surface.duration
			local arch = math.sin(u * math.pi)
			lift = -self.surface.height * arch
			love.graphics.setColor(0.78, 0.84, 0.80, 0.22 * arch)
			love.graphics.ellipse("line", self.x, self.y, self.surface.ring * (0.4 + 0.6 * u), self.surface.ring * 0.35 * (0.4 + 0.6 * u))
		end
		local ang = math.atan2(self.hy, self.hx)
		love.graphics.push()
		love.graphics.translate(self.x, self.y + lift)
		love.graphics.rotate(ang)
		love.graphics.setColor(self.species.color)
		love.graphics.ellipse("fill", 0, 0, len * 0.5, len * 0.16)
		love.graphics.setColor(self.species.stripe)
		love.graphics.ellipse("fill", -len * 0.02, 0, len * 0.28, len * 0.07)
		love.graphics.pop()
	end
end

function fish.draw_lies(river)
	love.graphics.setPointSize(4)
	for i = 1, 18 do
		local t = (i - 0.5) / 18
		for j = 1, 6 do
			local across = j / 7
			local sample = river:sample(t, across)
			local score = river:lie_score(sample)
			local a = math.min(0.7, score * 0.25)
			love.graphics.setColor(0.95, 0.75, 0.2, a)
			love.graphics.points(sample.x, sample.y)
		end
	end
end

return fish

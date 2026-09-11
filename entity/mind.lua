local mathx = require "lib.math"

local mind = {}
local clamp = mathx.clamp

local PHASES = { "rest", "nymph", "emerge", "film" }
local COLUMN = { rest = 0.12, nymph = 0.22, emerge = 0.58, film = 0.9 }
local CLEAR = { chalk = 1, bedrock = 0.75, gravel = 0.55, silt = 0.35, peat = 0.2 }

-- Current feed phase from the species cycle and a seeded offset.
function mind.phase(fish)
	if fish.spook_t > 0 then
		return "rest"
	end
	local spec = fish.species
	local u = ((fish.clock + fish.phase_off) % spec.feed_period) / spec.feed_period
	local acc = 0
	for i = 1, #PHASES do
		acc = acc + spec.feed[i]
		if u < acc then
			return PHASES[i]
		end
	end
	return "film"
end

-- Desired water-column height. 0 is the bed, 1 is the film.
function mind.column_target(fish, phase)
	if fish.spook_t > 0 then
		return 0.06
	end
	local col = COLUMN[phase] or 0.2
	if phase == "nymph" then
		col = col + fish.species.depth_pref * 0.08
	end
	return clamp(col, 0.05, 0.96)
end

-- Bed clarity: chalk spook more, peat less.
function mind.clarity(river)
	local id = river.char and river.char.bed_type and river.char.bed_type.id
	return CLEAR[id] or 0.5
end

-- True when the player is close enough to spook this fish.
function mind.spooked(fish, player, river)
	if not player then
		return false
	end
	local dx, dy = fish.x - player.x, fish.y - player.y
	local dist = math.sqrt(dx * dx + dy * dy)
	local radius = (70 + 110 * fish.species.skittish) * mind.clarity(river)
	if fish.column > 0.7 then
		radius = radius * 1.25
	end
	return dist < radius
end

-- Nearest rival this fish will try to push off a lie.
function mind.rival(fish, list)
	local best, found = 1e9, nil
	local reach = 28 + fish.length * 0.55 * fish.species.aggression
	for i = 1, #list do
		local other = list[i]
		if other.id ~= fish.id then
			local dx, dy = fish.x - other.x, fish.y - other.y
			local dist = math.sqrt(dx * dx + dy * dy)
			local rank = fish.species.aggression * fish.length
			local theirs = other.species.aggression * other.length
			if dist < reach and rank > theirs and dist < best then
				best, found = dist, other
			end
		end
	end
	return found
end

-- Move column toward a target at a species rate.
function mind.approach_column(fish, target, dt)
	local rate = 0.45 + fish.species.cruise * 4
	if fish.spook_t > 0 then
		rate = rate * 2.2
	end
	local d = target - fish.column
	local step = rate * dt
	if d > step then
		fish.column = fish.column + step
	elseif d < -step then
		fish.column = fish.column - step
	else
		fish.column = target
	end
end

return mind

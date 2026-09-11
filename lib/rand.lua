local rand = {}

-- Integer in [lo, hi] that is not cur.
function rand.other(cur, lo, hi)
	local v = love.math.random(lo, hi)
	if v == cur then
		return lo + (cur - lo + 1) % (hi - lo + 1)
	end
	return v
end

return rand

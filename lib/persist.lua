-- Persistent state saved to the LÖVE write directory.
-- Tiny JSON-free format: key=value lines, one per field.
local persist = {}

local PATH = "settings.cfg"

function persist.save(t)
	local lines = {}
	for k, v in pairs(t) do
		lines[#lines + 1] = tostring(k) .. "=" .. tostring(v)
	end
	love.filesystem.write(table.concat(lines, "\n"))
end

function persist.load()
	local data = love.filesystem.read(PATH)
	if not data then
		return {}
	end
	local t = {}
	for line in data:gmatch("[^\n]+") do
		local k, v = line:match("^([^=]+)=(.*)$")
		if k then
			-- Try numeric.
			local n = tonumber(v)
			t[k] = n or v
		end
	end
	return t
end

return persist

-- Entity config store. Inline tables became JSON under data/,
-- one folder per entity, one file per type. Loaded once during
-- the splash through data.load. Modules read through list and
-- group, which lazy-load on first touch so headless use keeps
-- working. Reads go through love.filesystem in game, plain io
-- outside it.
local json = require "lib.json"

local data = {}

local ROOT = "data"
local FILES = {
	trout = { dir = "trout", ids = { "brown", "rainbow", "brook", "cutthroat", "bull" } },
	birds = { dir = "birds", ids = { "heron", "egret" } },
	beds = { dir = "beds", ids = { "chalk", "peat", "gravel", "silt", "bedrock" } },
	rises = { dir = "rises", ids = { "sip", "rise", "head_and_tail", "splash", "porpoise" } },
	lures = { dir = "lures", ids = {
		"adams", "blue_winged_olive", "elk_hair_caddis", "royal_wulff",
		"griffiths_gnat", "stimulator", "partridge_and_orange",
		"leadwing_coachman", "pheasant_tail", "hares_ear",
		"copper_john", "woolly_bugger",
	} },
}

local groups, lists = {}, {}

local function read_file(path)
	if love and love.filesystem then
		return love.filesystem.read(path)
	end
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local s = f:read("*a")
	f:close()
	return s
end

local function load_group(key)
	local spec = FILES[key]
	assert(spec, "data: unknown group " .. tostring(key))
	local out = {}
	for _, id in ipairs(spec.ids) do
		local path = ROOT .. "/" .. spec.dir .. "/" .. id .. ".json"
		local raw = read_file(path)
		assert(raw, "data: missing " .. path)
		out[id] = json.decode(raw)
	end
	return out
end

local function ensure(key)
	if not groups[key] then
		groups[key] = load_group(key)
	end
	return groups[key]
end

-- Load every group now. The splash calls this first so later
-- steps never touch the disk.
function data.load()
	for key in pairs(FILES) do
		ensure(key)
	end
end

-- Types keyed by id.
function data.group(key)
	return ensure(key)
end

-- Types in manifest order. Trout, beds, and lures rely on it.
function data.list(key)
	if not lists[key] then
		local group = ensure(key)
		local arr = {}
		for _, id in ipairs(FILES[key].ids) do
			arr[#arr + 1] = group[id]
		end
		lists[key] = arr
	end
	return lists[key]
end

return data

-- Shared trout fly catalog. Twelve working patterns drawn from
-- standard tying recipes. kind sets the body plan: dry rides
-- high, wet swings, nymph drifts deep, streamer strips.
local flies = {}

flies.list = {
	{ name = "adams", kind = "dry", s = 1.0,
		rig = "dry, hooks 12 to 18", water = "riffles and current seams", tip = "First pick for an unknown hatch. Dead drift only." },
	{ name = "blue winged olive", kind = "dry", s = 0.85,
		rig = "dry, hooks 16 to 20", water = "slow tailouts", tip = "Cloudy afternoons. Go a size smaller than you think." },
	{ name = "elk hair caddis", kind = "dry", s = 0.95,
		rig = "dry, hooks 12 to 16", water = "fast pocket water", tip = "Skate it an inch at the end of the drift." },
	{ name = "royal wulff", kind = "dry", s = 1.05,
		rig = "dry, hooks 10 to 14", water = "rough runs", tip = "High floater for broken water. Easy to track." },
	{ name = "griffiths gnat", kind = "dry", s = 0.6,
		rig = "dry, hooks 18 to 22", water = "flat glassy pools", tip = "Midge clusters. Long light tippet, no drag." },
	{ name = "stimulator", kind = "dry", s = 1.2,
		rig = "dry, hooks 8 to 12", water = "summer riffles", tip = "Stonefly big meal. Browns move far for it." },
	{ name = "partridge and orange", kind = "wet", s = 0.9,
		rig = "wet, hooks 12 to 16", water = "seams, swung down", tip = "Swing across and let it lift at the hang." },
	{ name = "leadwing coachman", kind = "wet", s = 0.95,
		rig = "wet, hooks 10 to 14", water = "runs, swung or stripped", tip = "Old reliable when nothing shows on top." },
	{ name = "pheasant tail", kind = "nymph", s = 0.9,
		rig = "nymph, hooks 14 to 20", water = "deep slots, dead drifted", tip = "Matches most mayfly nymphs. Fish it deep." },
	{ name = "hares ear", kind = "nymph", s = 1.0,
		rig = "nymph, hooks 12 to 16", water = "pools and eddies", tip = "Scruffy wins. Trail it behind a heavier fly." },
	{ name = "copper john", kind = "nymph", s = 0.85,
		rig = "nymph, hooks 10 to 18", water = "fast deep slots", tip = "Heavy dropper that punches through current." },
	{ name = "woolly bugger", kind = "streamer", s = 1.5,
		rig = "streamer, hooks 6 to 10", water = "undercut banks and pools", tip = "Strip, pause, hang on. Moves the big browns." },
}

local DARK = { 0.15, 0.14, 0.12 }
local CREAM = { 0.88, 0.85, 0.72 }

-- Hook shank with up eye and bend, facing right.
local function hook(s, gape)
	love.graphics.setColor(DARK[1], DARK[2], DARK[3], 1)
	love.graphics.setLineWidth(2)
	love.graphics.line(-13 * s, 0, 12 * s, 0)
	love.graphics.circle("line", 14 * s, -1 * s, 2 * s, 8)
	love.graphics.arc("line", -13 * s, 0, (gape or 5) * s, -1.4, 1.4, 8)
	love.graphics.setLineWidth(1)
end

-- Adams. Grey dubbed body, mixed brown and grizzly tail, barred
-- grizzly tip wings, mixed wound hackle.
local function adams(s)
	hook(s)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.45, 0.30, 0.18, 1)
	love.graphics.line(-22 * s, -4 * s, -13 * s, 0)
	love.graphics.setColor(0.55, 0.55, 0.53, 1)
	love.graphics.line(-22 * s, 0, -13 * s, 0)
	love.graphics.line(-22 * s, 4 * s, -13 * s, 0)
	love.graphics.setColor(0.50, 0.50, 0.48, 1)
	love.graphics.ellipse("fill", -3 * s, 0, 11 * s, 4.6 * s, 0, 10)
	love.graphics.setColor(0.62, 0.62, 0.60, 1)
	love.graphics.ellipse("fill", 5 * s, -14 * s, 4.4 * s, 10 * s, -0.22, 10)
	love.graphics.ellipse("fill", 11 * s, -14 * s, 4.4 * s, 10 * s, 0.22, 10)
	love.graphics.setColor(0.25, 0.25, 0.25, 1)
	love.graphics.line(5 * s, -22 * s, 5 * s, -8 * s)
	love.graphics.line(11 * s, -22 * s, 11 * s, -8 * s)
	for i = -2, 2 do
		if i % 2 == 0 then
			love.graphics.setColor(0.45, 0.30, 0.18, 1)
		else
			love.graphics.setColor(0.60, 0.60, 0.58, 1)
		end
		love.graphics.line(8 * s + i * 2.4 * s, 1 * s, 8 * s + i * 3.4 * s, -11 * s)
	end
	love.graphics.setLineWidth(1)
end

-- Blue winged olive. Olive body, dun wings and hackle, sparse.
local function bwo(s)
	hook(s)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.50, 0.48, 0.30, 1)
	love.graphics.line(-20 * s, 0, -13 * s, 0)
	love.graphics.setColor(0.45, 0.46, 0.24, 1)
	love.graphics.ellipse("fill", -3 * s, 0, 10 * s, 4.0 * s, 0, 10)
	love.graphics.setColor(0.55, 0.58, 0.60, 1)
	love.graphics.ellipse("fill", 5 * s, -12 * s, 4.0 * s, 9 * s, -0.22, 10)
	love.graphics.ellipse("fill", 11 * s, -12 * s, 4.0 * s, 9 * s, 0.22, 10)
	love.graphics.setColor(0.60, 0.62, 0.62, 1)
	for i = -1, 1 do
		love.graphics.line(8 * s + i * 3 * s, 1 * s, 8 * s + i * 4 * s, -9 * s)
	end
	love.graphics.setLineWidth(1)
end

-- Elk hair caddis. Tan dubbed body, palmered hackle, elk tent wing.
local function elk(s)
	hook(s)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.55, 0.40, 0.22, 1)
	love.graphics.ellipse("fill", -2 * s, 0, 12 * s, 4.6 * s, 0, 12)
	love.graphics.setColor(0.50, 0.36, 0.20, 1)
	for i = -3, 3 do
		love.graphics.line(-2 * s + i * 3 * s, 4 * s, -2 * s + i * 3.6 * s, -5 * s)
	end
	love.graphics.setColor(0.72, 0.58, 0.36, 1)
	love.graphics.polygon("fill", -14 * s, -4 * s, 10 * s, -10 * s, 12 * s, -4 * s, -12 * s, -1 * s)
	love.graphics.setColor(0.60, 0.46, 0.28, 1)
	love.graphics.line(-14 * s, -4 * s, 10 * s, -10 * s)
	love.graphics.setLineWidth(1)
end

-- Royal wulff. Peacock ends, red floss middle, white wings.
local function wulff(s)
	hook(s)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.45, 0.30, 0.18, 1)
	love.graphics.line(-22 * s, 0, -13 * s, 0)
	love.graphics.setColor(0.20, 0.22, 0.18, 1)
	love.graphics.ellipse("fill", -7 * s, 0, 7 * s, 4.6 * s, 0, 10)
	love.graphics.setColor(0.62, 0.20, 0.14, 1)
	love.graphics.ellipse("fill", 1 * s, 0, 5 * s, 4.8 * s, 0, 10)
	love.graphics.setColor(0.20, 0.22, 0.18, 1)
	love.graphics.ellipse("fill", 8 * s, 0, 5 * s, 4.6 * s, 0, 10)
	love.graphics.setColor(0.88, 0.86, 0.76, 1)
	love.graphics.ellipse("fill", 5 * s, -14 * s, 4.4 * s, 10 * s, -0.22, 10)
	love.graphics.ellipse("fill", 11 * s, -14 * s, 4.4 * s, 10 * s, 0.22, 10)
	love.graphics.setColor(0.45, 0.30, 0.18, 1)
	for i = -2, 2 do
		love.graphics.line(8 * s + i * 2.4 * s, 1 * s, 8 * s + i * 3.4 * s, -11 * s)
	end
	love.graphics.setLineWidth(1)
end

-- Griffiths gnat. Tiny dark peacock ball in dense grizzly hackle.
local function gnat(s)
	hook(s, 4)
	love.graphics.setColor(0.22, 0.24, 0.20, 1)
	love.graphics.ellipse("fill", 0, 0, 9 * s, 6 * s, 0, 12)
	love.graphics.setColor(0.60, 0.60, 0.58, 1)
	love.graphics.setLineWidth(2)
	for i = -3, 3 do
		love.graphics.line(i * 3 * s, 5 * s, i * 4 * s, -6 * s)
		love.graphics.line(i * 3 * s, -5 * s, i * 4 * s, 6 * s)
	end
	love.graphics.setLineWidth(1)
end

-- Stimulator. Long orange body, elk wing, bushy collar, tail.
local function stimulator(s)
	hook(s, 6)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.60, 0.44, 0.20, 1)
	love.graphics.line(-24 * s, -3 * s, -13 * s, 0)
	love.graphics.line(-24 * s, 3 * s, -13 * s, 0)
	love.graphics.setColor(0.66, 0.42, 0.16, 1)
	love.graphics.ellipse("fill", -3 * s, 0, 13 * s, 5 * s, 0, 12)
	love.graphics.setColor(0.72, 0.58, 0.36, 1)
	love.graphics.polygon("fill", -10 * s, -4 * s, 8 * s, -12 * s, 12 * s, -5 * s, -8 * s, -1 * s)
	love.graphics.setColor(0.55, 0.36, 0.16, 1)
	for i = -2, 2 do
		love.graphics.line(6 * s + i * 2.6 * s, 4 * s, 6 * s + i * 3.4 * s, -7 * s)
	end
	love.graphics.setLineWidth(1)
end

-- Partridge and orange. Slim orange silk body, soft hackle swept back.
local function partridge(s)
	hook(s)
	love.graphics.setColor(0.68, 0.42, 0.18, 1)
	love.graphics.setLineWidth(3)
	love.graphics.line(-12 * s, 0, 11 * s, 0)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.45, 0.36, 0.26, 1)
	for i = -1, 1 do
		love.graphics.line(9 * s, -3 * s + i * 3 * s, -2 * s, -10 * s + i * 3 * s)
		love.graphics.line(9 * s, 3 * s + i * 3 * s, -2 * s, 10 * s + i * 3 * s)
	end
	love.graphics.setColor(0.55, 0.44, 0.30, 1)
	love.graphics.line(9 * s, -4 * s, -4 * s, -11 * s)
	love.graphics.line(9 * s, 4 * s, -4 * s, 11 * s)
	love.graphics.setLineWidth(1)
end

-- Leadwing coachman. Peacock body, dark slate wings swept back.
local function coachman(s)
	hook(s)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.45, 0.42, 0.30, 1)
	love.graphics.line(-20 * s, 0, -13 * s, 0)
	love.graphics.setColor(0.22, 0.24, 0.20, 1)
	love.graphics.ellipse("fill", -2 * s, 0, 12 * s, 4.6 * s, 0, 12)
	love.graphics.setColor(0.35, 0.36, 0.38, 0.95)
	love.graphics.ellipse("fill", -1 * s, -3 * s, 13 * s, 4.6 * s, -0.30, 12)
	love.graphics.ellipse("fill", -1 * s, 3 * s, 13 * s, 4.6 * s, 0.30, 12)
	love.graphics.setColor(0.45, 0.30, 0.18, 1)
	for i = -1, 1 do
		love.graphics.line(8 * s + i * 2.6 * s, 1 * s, 8 * s + i * 3.4 * s, -8 * s)
	end
	love.graphics.setLineWidth(1)
end

-- Pheasant tail. Barred brown abdomen with copper rib, dark
-- wingcase, split legs, gold bead head.
local function pheasant(s)
	hook(s)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.40, 0.30, 0.18, 1)
	love.graphics.line(-20 * s, -3 * s, -14 * s, 0)
	love.graphics.line(-20 * s, 3 * s, -14 * s, 0)
	love.graphics.setColor(0.48, 0.36, 0.20, 1)
	love.graphics.ellipse("fill", -4 * s, 0, 11 * s, 4.0 * s, 0, 12)
	love.graphics.setColor(0.72, 0.44, 0.20, 1)
	for i = -2, 2 do
		love.graphics.line(-4 * s + i * 4 * s, -4 * s, -4 * s + i * 4 * s, 4 * s)
	end
	love.graphics.setColor(0.30, 0.24, 0.14, 1)
	love.graphics.polygon("fill", -2 * s, -4 * s, 8 * s, -4.6 * s, 8 * s, 4.6 * s, -2 * s, 4 * s)
	love.graphics.line(8 * s, -4 * s, 12 * s, -8 * s)
	love.graphics.line(8 * s, 4 * s, 12 * s, 8 * s)
	love.graphics.setColor(0.80, 0.62, 0.25, 1)
	love.graphics.circle("fill", 11 * s, 0, 4.2 * s, 12)
	love.graphics.setLineWidth(1)
end

-- Hares ear. Shaggy tan body, gold rib, mottled wingcase, hare tail.
local function hares(s)
	hook(s)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.55, 0.48, 0.32, 1)
	love.graphics.line(-19 * s, -3 * s, -13 * s, 0)
	love.graphics.line(-19 * s, 3 * s, -13 * s, 0)
	love.graphics.setColor(0.55, 0.48, 0.32, 1)
	love.graphics.ellipse("fill", -2 * s, 0, 12 * s, 5 * s, 0, 12)
	love.graphics.setColor(0.65, 0.58, 0.40, 1)
	for i = -3, 3 do
		love.graphics.line(-2 * s + i * 3 * s, 4 * s, -2 * s + i * 3.8 * s, -5 * s)
	end
	love.graphics.setColor(0.72, 0.55, 0.25, 1)
	love.graphics.line(-10 * s, -4 * s, -10 * s, 4 * s)
	love.graphics.line(-4 * s, -5 * s, -4 * s, 5 * s)
	love.graphics.line(2 * s, -5 * s, 2 * s, 5 * s)
	love.graphics.setColor(0.38, 0.30, 0.18, 1)
	love.graphics.polygon("fill", 0, -4.6 * s, 9 * s, -5 * s, 9 * s, 5 * s, 0, 4.6 * s)
	love.graphics.setLineWidth(1)
end

-- Copper john. Gold bead, copper wire abdomen, biot tail, peacock
-- thorax, dark wingcase with pearl flash, legs.
local function copper(s)
	hook(s)
	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.45, 0.36, 0.24, 1)
	love.graphics.line(-19 * s, -4 * s, -13 * s, -1 * s)
	love.graphics.line(-19 * s, 4 * s, -13 * s, 1 * s)
	love.graphics.setColor(0.62, 0.32, 0.14, 1)
	love.graphics.ellipse("fill", -4 * s, 0, 10 * s, 4.4 * s, 0, 12)
	love.graphics.setColor(0.35, 0.16, 0.08, 1)
	for i = -2, 2 do
		love.graphics.line(-4 * s + i * 3.6 * s, -4.2 * s, -4 * s + i * 3.6 * s, 4.2 * s)
	end
	love.graphics.setColor(0.22, 0.26, 0.20, 1)
	love.graphics.ellipse("fill", 5 * s, 0, 5 * s, 4.8 * s, 0, 10)
	love.graphics.setColor(0.30, 0.26, 0.20, 1)
	love.graphics.polygon("fill", 1 * s, -4.4 * s, 9 * s, -5 * s, 9 * s, 5 * s, 1 * s, 4.4 * s)
	love.graphics.setColor(0.85, 0.88, 0.90, 1)
	love.graphics.line(2 * s, -4.6 * s, 8 * s, -5 * s)
	love.graphics.setColor(0.45, 0.36, 0.26, 1)
	love.graphics.line(9 * s, -4 * s, 12 * s, -7 * s)
	love.graphics.line(9 * s, 4 * s, 12 * s, 7 * s)
	love.graphics.setColor(0.80, 0.62, 0.25, 1)
	love.graphics.circle("fill", 11 * s, 0, 4.4 * s, 12)
	love.graphics.setLineWidth(1)
end

-- Woolly bugger. Flowing marabou tail, chenille body, palmered
-- hackle, brass cone head, eye.
local function bugger(s)
	love.graphics.setColor(0.28, 0.30, 0.20, 1)
	love.graphics.polygon("fill", -32 * s, -2 * s, -20 * s, -9 * s, -20 * s, 9 * s, -32 * s, 2 * s)
	love.graphics.setColor(0.30, 0.32, 0.22, 1)
	love.graphics.ellipse("fill", -4 * s, 0, 20 * s, 6.5 * s, 0, 14)
	love.graphics.setColor(0.38, 0.40, 0.26, 1)
	love.graphics.setLineWidth(2)
	for i = -3, 3 do
		love.graphics.line(-4 * s + i * 4.4 * s, 6 * s, -4 * s + i * 5.2 * s, -6 * s)
	end
	love.graphics.setLineWidth(1)
	love.graphics.setColor(0.72, 0.55, 0.28, 1)
	love.graphics.polygon("fill", 12 * s, -6 * s, 17 * s, -4 * s, 17 * s, 4 * s, 12 * s, 6 * s)
	love.graphics.setColor(0.10, 0.10, 0.10, 1)
	love.graphics.circle("fill", 14.5 * s, -1.5 * s, 1.6 * s, 8)
end

local DRAW = {
	adams = adams,
	["blue winged olive"] = bwo,
	["elk hair caddis"] = elk,
	["royal wulff"] = wulff,
	["griffiths gnat"] = gnat,
	stimulator = stimulator,
	["partridge and orange"] = partridge,
	["leadwing coachman"] = coachman,
	["pheasant tail"] = pheasant,
	["hares ear"] = hares,
	["copper john"] = copper,
	["woolly bugger"] = bugger,
}

-- Draw pattern f at scale s in local space.
function flies.draw(f, s)
	DRAW[f.name](s or f.s)
end

return flies

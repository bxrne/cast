local mix3 = require("lib.math").mix3

local STONE, MOSS = { 0.36, 0.34, 0.28 }, { 0.27, 0.36, 0.16 }
local PEAT_SOIL, GRASS = { 0.18, 0.16, 0.10 }, { 0.24, 0.30, 0.14 }

-- Bed types. Water stays bluish; spots and stain come from the bed.
local BEDS = {
	{
		id = "chalk",
		water = { 0.18, 0.36, 0.44 },
		water_deep = { 0.06, 0.20, 0.30 },
		bed = { 0.50, 0.48, 0.38 },
		spot = { 0.38, 0.36, 0.26 },
		depth_scale = 0.82,
		pool_contrast = 0.32,
		expose = 0.6,
		obs = { rocks = 8, rock_r = 16 },
	},
	{
		id = "peat",
		water = { 0.18, 0.34, 0.40 },
		water_deep = { 0.06, 0.16, 0.24 },
		bed = { 0.16, 0.12, 0.08 },
		spot = { 0.28, 0.20, 0.12 },
		depth_scale = 1.18,
		pool_contrast = 0.72,
		obs = { rocks = 6, rock_r = 20 },
	},
	{
		id = "gravel",
		water = { 0.22, 0.42, 0.52 },
		water_deep = { 0.08, 0.24, 0.38 },
		bed = { 0.44, 0.38, 0.26 },
		spot = { 0.58, 0.50, 0.32 },
		depth_scale = 1.0,
		pool_contrast = 0.55,
		obs = { rocks = 12, rock_r = 17 },
	},
	{
		id = "silt",
		water = { 0.24, 0.42, 0.46 },
		water_deep = { 0.10, 0.24, 0.32 },
		bed = { 0.40, 0.36, 0.26 },
		spot = { 0.30, 0.36, 0.20 },
		depth_scale = 0.88,
		pool_contrast = 0.22,
		obs = { rocks = 5, rock_r = 15 },
	},
	{
		id = "bedrock",
		water = { 0.16, 0.36, 0.50 },
		water_deep = { 0.05, 0.18, 0.34 },
		bed = { 0.30, 0.32, 0.34 },
		spot = { 0.18, 0.20, 0.24 },
		depth_scale = 1.22,
		pool_contrast = 0.8,
		obs = { rocks = 16, rock_r = 22 },
	},
}

local palette = {
	STONE = STONE,
	MOSS = MOSS,
	PEAT_SOIL = PEAT_SOIL,
	GRASS = GRASS,
	BEDS = BEDS,
}

-- Pick a bed type from a 0..1 roll.
function palette.bed_at(u)
	return BEDS[math.min(#BEDS, math.floor(u * #BEDS) + 1)]
end

-- Mix land and water colours from a bed type and bank lushness.
function palette.make(bed, lush)
	local stain = bed.id == "peat" and 0.55 or (bed.id == "silt" and 0.35 or 0.12)
	return {
		ground = mix3(mix3(STONE, GRASS, lush), mix3(PEAT_SOIL, bed.bed, 0.35), stain),
		bank = mix3(mix3(STONE, MOSS, lush), mix3(bed.bed, MOSS, 0.4), stain * 0.6),
		wet = mix3({ 0.22, 0.20, 0.16 }, bed.bed, 0.45),
		gravel = mix3({ 0.34, 0.32, 0.24 }, bed.bed, 0.5),
		water_mid = bed.water,
		water_deep = bed.water_deep,
		bed = bed.bed,
		spot = bed.spot,
		expose = bed.expose or 1,
	}
end

return palette

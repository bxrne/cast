local mix3 = require("lib.math").mix3

local STONE, MOSS = { 0.36, 0.34, 0.28 }, { 0.27, 0.36, 0.16 }
local PEAT_SOIL, GRASS = { 0.18, 0.16, 0.10 }, { 0.24, 0.30, 0.14 }

-- Bed types from data/beds, one file per bed. Water stays
-- bluish; spots and stain come from the bed.
local BEDS = require("lib.data").list("beds")

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

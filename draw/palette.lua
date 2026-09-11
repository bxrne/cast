local mix3 = require("lib.math").mix3

local STONE, MOSS = { 0.36, 0.34, 0.28 }, { 0.27, 0.36, 0.16 }
local PEAT_SOIL, GRASS = { 0.18, 0.16, 0.10 }, { 0.24, 0.30, 0.14 }

local palette = {
	STONE = STONE,
	MOSS = MOSS,
	PEAT_SOIL = PEAT_SOIL,
	GRASS = GRASS,
}

-- Mix a river palette from peat stain and bank lushness.
function palette.make(peat, lush)
	return {
		ground = mix3(mix3(STONE, GRASS, lush), PEAT_SOIL, peat * 0.55),
		bank = mix3(mix3(STONE, MOSS, lush), mix3(PEAT_SOIL, MOSS, 0.35), peat * 0.45),
		wet = mix3({ 0.16, 0.15, 0.12 }, { 0.12, 0.14, 0.10 }, peat),
		gravel = mix3({ 0.32, 0.30, 0.24 }, { 0.22, 0.20, 0.16 }, peat),
		water_deep = mix3({ 0.10, 0.20, 0.18 }, { 0.06, 0.10, 0.08 }, peat),
		water_mid = mix3({ 0.18, 0.32, 0.26 }, { 0.12, 0.18, 0.14 }, peat),
		foam = mix3({ 0.58, 0.62, 0.56 }, { 0.48, 0.46, 0.38 }, peat),
	}
end

return palette

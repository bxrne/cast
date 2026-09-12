-- Repo typefaces, loaded from assets during the splash.
-- IM Fell carries titles, Spectral carries body, JetBrains Mono
-- carries the debug panel and fish tags.
local fonts = {}

local cache = nil

local function face(path, size)
	local ok, font = pcall(love.graphics.newFont, path, size)
	if ok and font then
		return font
	end
	return love.graphics.newFont(size)
end

-- Load and cache the set. Runs once from the boot steps.
function fonts.get()
	if cache then
		return cache
	end
	cache = {
		title = face("assets/fonts/IMFellEnglish-Regular.ttf", 88),
		subtitle = face("assets/fonts/IMFellEnglish-Italic.ttf", 24),
		head = face("assets/fonts/IMFellEnglish-Regular.ttf", 20),
		body = face("assets/fonts/Spectral-Regular.ttf", 15),
		small = love.graphics.newFont(18),
		mono = face("assets/fonts/JetBrainsMono-Regular.ttf", 13),
	}
	return cache
end

return fonts

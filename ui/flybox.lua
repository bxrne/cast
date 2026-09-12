local tackle = require "draw.flies"
local theme = require "ui.debug"

local flybox = {}
flybox.__index = flybox

local BTN = { x = 16, y = 16, w = 148, h = 42 }
local ROW_H = 54
local LIST_W = 246
local GUTTER = 28
local PAD = 22
local LIST_TOP = 70
local LIST_BOTTOM = 18
local PREVIEW_PAD = 20

local ACCENT = { 0.72, 0.82, 0.55 }
local LIGHT_GRAY = { 0.68, 0.70, 0.64 }

function flybox.new()
	local fonts = require("ui.fonts").get()
	return setmetatable({
		open = false, selected = 1, scroll = 0,
		font = fonts.mono, mono = fonts.mono,
		head = fonts.head, body = fonts.body,
	}, flybox)
end

function flybox:toggle()
	self.open = not self.open
end

-- True when x, y lands in the button.
local function on_button(x, y)
	return x >= BTN.x and x <= BTN.x + BTN.w and y >= BTN.y and y <= BTN.y + BTN.h
end

-- The open tray is always half the viewport and centered on both axes.
local function drawer()
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	local dw, dh = w * 0.5, h * 0.5
	return { x = (w - dw) / 2, y = (h - dh) / 2, w = dw, h = dh }
end

local function list_width(d)
	return math.max(150, math.min(LIST_W, d.w * 0.38))
end

-- Max scroll for the pattern list in this drawer.
local function max_scroll(d)
	return math.max(0, LIST_TOP + #tackle.list * ROW_H + LIST_BOTTOM - d.h)
end

-- Keep the selected row visible after keyboard navigation.
local function clamp_scroll(self)
	local d = drawer()
	local top = d.y + LIST_TOP
	local bot = d.y + d.h - LIST_BOTTOM
	local ry = top - self.scroll + (self.selected - 1) * ROW_H
	if ry < top then
		self.scroll = self.scroll - (top - ry)
	elseif ry + ROW_H > bot then
		self.scroll = self.scroll + (ry + ROW_H - bot)
	end
	self.scroll = math.max(0, math.min(max_scroll(d), self.scroll))
end

function flybox:mousepressed(x, y)
	if on_button(x, y) then
		self.open = not self.open
		return true
	end
	if not self.open then
		return false
	end
	local d = drawer()
	local list_w = list_width(d)
	if x < d.x or x > d.x + d.w or y < d.y or y > d.y + d.h then
		self.open = false
		return false
	end
	-- Row pick in the list column.
	if x <= d.x + list_w + 8 then
		local ly = d.y + LIST_TOP - self.scroll
		local i = math.floor((y - ly) / ROW_H) + 1
		if i >= 1 and i <= #tackle.list then
			self.selected = i
			clamp_scroll(self)
		end
		return true
	end
	return true
end

-- Up/down navigates the list, scroll follows.
function flybox:keypressed(key)
	if not self.open then
		return false
	end
	local n = #tackle.list
	if n == 0 then
		return false
	end
	if key == "up" then
		self.selected = ((self.selected - 2) % n) + 1
		clamp_scroll(self)
		return true
	end
	if key == "down" then
		self.selected = (self.selected % n) + 1
		clamp_scroll(self)
		return true
	end
	return false
end

-- Wheel scrolls the pattern list.
function flybox:wheelmoved(dx, dy)
	if not self.open then
		return false
	end
	self.scroll = math.max(0, math.min(max_scroll(drawer()), self.scroll - dy * 24))
	return true
end

-- Re-clamp after the viewport changes.
function flybox:resize()
	if self.open then
		clamp_scroll(self)
	end
end

local function button(self)
	love.graphics.setFont(self.body)
	love.graphics.setColor(0, 0, 0, 0.28)
	love.graphics.rectangle("fill", BTN.x + 2, BTN.y + 3, BTN.w, BTN.h, 5, 5)
	love.graphics.setColor(theme.BG, 0.96)
	love.graphics.rectangle("fill", BTN.x, BTN.y, BTN.w, BTN.h, 5, 5)
	love.graphics.setColor(theme.EDGE, 1)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", BTN.x, BTN.y, BTN.w, BTN.h, 5, 5)
	love.graphics.setColor(theme.TEXT, 1)
	love.graphics.printf("FLY BOX", BTN.x, BTN.y + 12, BTN.w, "center")
end

local function list_col(self, d)
	local list = tackle.list
	local list_w = list_width(d)
	local has_index = d.w >= 560
	local index_w = has_index and 34 or 0
	local text_w = list_w - PAD * 2 - index_w

	love.graphics.setFont(self.body)
	love.graphics.setColor(ACCENT, 1)
	love.graphics.print("PATTERNS", d.x + PAD, d.y + PAD + 2)
	love.graphics.setColor(theme.EDGE, 0.45)
	love.graphics.setLineWidth(1)
	love.graphics.line(d.x + PAD, d.y + PAD + 24, d.x + list_w - PAD, d.y + PAD + 24)

	-- Clip rows to the list column. The rows use whitespace, not separators.
	love.graphics.setScissor(d.x + PAD - 8, d.y + LIST_TOP - 8, list_w + 16, d.h - LIST_TOP - LIST_BOTTOM + 16)
	local ly = d.y + LIST_TOP - self.scroll
	for i = 1, #list do
		local ry = ly + (i - 1) * ROW_H
		local selected = i == self.selected
		if selected then
			love.graphics.setColor(theme.HI, 0.30)
			love.graphics.rectangle("fill", d.x + PAD - 8, ry + 2, list_w - PAD, ROW_H - 6, 3, 3)
		end
		love.graphics.setFont(self.body)
		love.graphics.setColor(selected and ACCENT or theme.TEXT, 1)
		love.graphics.printf(list[i].name, d.x + PAD, ry + 7, text_w, "left")

		love.graphics.setFont(self.mono)
		love.graphics.setColor(selected and ACCENT or theme.DIM, 1)
		love.graphics.printf(string.upper(list[i].kind), d.x + PAD, ry + 31, text_w, "left")
		if has_index then
			love.graphics.setColor(selected and ACCENT or theme.DIM, 1)
			love.graphics.printf(string.format("%02d", i), d.x + list_w - PAD - index_w, ry + 7, index_w, "right")
		end
	end
	love.graphics.setScissor()
end

local META_LABEL_W = 72
local META_GAP = 8

-- Draw one label/value pair. Returns the y for the next row.
-- The mono label sits 2px lower so its baseline matches the body value.
local function draw_metadata(label, value, x, y, w, self)
	local vw = w - META_LABEL_W
	love.graphics.setFont(self.body)
	local _, wrapped = self.body:getWrap(value, vw)
	local line_px = self.body:getHeight() * self.body:getLineHeight()
	local h = math.max(line_px, #wrapped * line_px)
	love.graphics.setFont(self.mono)
	love.graphics.setColor(theme.EDGE, 1)
	love.graphics.print(label, x, y + 2)
	love.graphics.setFont(self.body)
	love.graphics.setColor(theme.TEXT, 1)
	love.graphics.printf(value, x + META_LABEL_W, y, vw, "left")
	return y + h + META_GAP
end

local function detail_col(self, d)
	local f = tackle.list[self.selected]
	local list_w = list_width(d)
	local x = d.x + list_w + GUTTER
	local col_w = d.x + d.w - x - PAD
	local top = d.y + PAD

	love.graphics.setFont(self.body)
	love.graphics.setColor(ACCENT, 1)
	love.graphics.print("SPECIMEN", x, top)
	love.graphics.setFont(self.mono)
	love.graphics.setColor(theme.DIM, 1)
	love.graphics.printf("/  " .. string.upper(f.kind), x + 104, top + 2, col_w - 184, "left")
	love.graphics.setColor(theme.DIM, 1)
	love.graphics.printf(string.format("%02d / %02d", self.selected, #tackle.list), x + col_w - 72, top + 2, 72, "right")
	love.graphics.setColor(theme.EDGE, 0.45)
	love.graphics.setLineWidth(1)
	love.graphics.line(x, top + 24, x + col_w, top + 24)

	local preview_y = d.y + LIST_TOP - 4
	local preview_h = math.max(130, math.min(math.floor(d.h * 0.43), d.h - 220))
	local preview_bottom = preview_y + preview_h
	love.graphics.setColor(theme.HI, 0.18)
	love.graphics.rectangle("fill", x, preview_y, col_w, preview_h, 3, 3)
	love.graphics.setColor(theme.EDGE, 0.65)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", x, preview_y, col_w, preview_h, 3, 3)

	-- A quiet light-gray measuring plate keeps the fly artwork legible.
	local cx = x + col_w / 2
	local cy = preview_y + preview_h / 2
	love.graphics.setColor(LIGHT_GRAY, 0.24)
	love.graphics.line(x + PREVIEW_PAD, cy, x + col_w - PREVIEW_PAD, cy)
	love.graphics.line(cx, preview_y + PREVIEW_PAD, cx, preview_bottom - PREVIEW_PAD)

	local art_w = f.kind == "streamer" and 66 or 48
	local art_h = f.kind == "dry" and 38 or 28
	local scale = math.min((col_w - PREVIEW_PAD * 2) / art_w, (preview_h - PREVIEW_PAD * 2) / art_h)
	scale = math.max(0.55, math.min(scale, 4))
	love.graphics.push()
	love.graphics.translate(cx, cy)
	tackle.draw(f, scale)
	love.graphics.pop()

	local copy_y = preview_bottom + PAD - 2
	love.graphics.setFont(self.head)
	love.graphics.setColor(theme.TEXT, 1)
	love.graphics.printf(f.name, x, copy_y, col_w, "left")
	local _, name_wrapped = self.head:getWrap(f.name, col_w)
	local name_h = #name_wrapped * self.head:getHeight() * self.head:getLineHeight()

	local meta_y = copy_y + name_h + 8
	meta_y = draw_metadata("RIG", f.rig, x, meta_y, col_w, self)
	meta_y = draw_metadata("WATER", f.water, x, meta_y, col_w, self)
	draw_metadata("TIP", f.tip, x, meta_y, col_w, self)
end

function flybox:draw()
	button(self)
	if not self.open then
		return
	end
	local d = drawer()
	local list_w = list_width(d)
	love.graphics.push("all")
	love.graphics.setColor(0, 0, 0, 0.30)
	love.graphics.rectangle("fill", d.x + 7, d.y + 9, d.w, d.h, 6, 6)
	love.graphics.setColor(theme.BG, 0.97)
	love.graphics.rectangle("fill", d.x, d.y, d.w, d.h, 6, 6)
	love.graphics.setColor(theme.EDGE, 1)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", d.x, d.y, d.w, d.h, 6, 6)
	love.graphics.setColor(theme.EDGE, 0.45)
	love.graphics.line(d.x + list_w + GUTTER / 2, d.y + PAD, d.x + list_w + GUTTER / 2, d.y + d.h - PAD)
	list_col(self, d)
	detail_col(self, d)
	love.graphics.pop()
end

return flybox

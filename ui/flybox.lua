local tackle = require "draw.flies"
local dbg_theme = require "ui.debug"

local flybox = {}
flybox.__index = flybox

local BTN = { x = 16, y = 16, w = 132, h = 38 }
local ROW_H = 36
local LIST_W = 200

function flybox.new()
	local fonts = require("ui.fonts").get()
	return setmetatable({
		open = false, selected = 1, scroll = 0,
		font = fonts.mono, head = fonts.head, body = fonts.body,
	}, flybox)
end

function flybox:toggle()
	self.open = not self.open
end

-- True when x, y lands in the button.
local function on_button(x, y)
	return x >= BTN.x and x <= BTN.x + BTN.w and y >= BTN.y and y <= BTN.y + BTN.h
end

-- Drawer geometry. Centered, 50 percent of screen.
local function drawer()
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	local dw, dh = w * 0.5, h * 0.5
	return { x = (w - dw) / 2, y = (h - dh) / 2, w = dw, h = dh }
end

-- Max scroll for the pattern list in this drawer.
local function max_scroll(d)
	return math.max(0, 40 + #tackle.list * ROW_H + 8 - d.h)
end

-- Keep the selected row visible after keyboard navigation.
local function clamp_scroll(self)
	local d = drawer()
	local top = d.y + 40
	local bot = d.y + d.h - 8
	local ly = top - self.scroll
	local ry = ly + (self.selected - 1) * ROW_H
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
	if x < d.x or x > d.x + d.w or y < d.y or y > d.y + d.h then
		self.open = false
		return false
	end
	-- Row pick in the list column.
	local ly = d.y + 40 - self.scroll
	if x <= d.x + LIST_W + 8 then
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

local function button(self)
	love.graphics.setColor(dbg_theme.BG[1], dbg_theme.BG[2], dbg_theme.BG[3], 0.95)
	love.graphics.rectangle("fill", BTN.x, BTN.y, BTN.w, BTN.h, 5, 5)
	love.graphics.setColor(dbg_theme.EDGE[1], dbg_theme.EDGE[2], dbg_theme.EDGE[3], 1)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", BTN.x, BTN.y, BTN.w, BTN.h, 5, 5)
	love.graphics.setLineWidth(1)
	love.graphics.setFont(self.font)
	love.graphics.setColor(dbg_theme.TEXT[1], dbg_theme.TEXT[2], dbg_theme.TEXT[3], 1)
	love.graphics.printf("Fly Box", BTN.x, BTN.y + 10, BTN.w, "center")
end

local function list_col(self, d)
	local list = tackle.list
	love.graphics.setFont(self.font)
	love.graphics.setColor(dbg_theme.TEXT[1], dbg_theme.TEXT[2], dbg_theme.TEXT[3], 1)
	love.graphics.print("Flies", d.x + 14, d.y + 10)
	-- Clip rows to the drawer.
	love.graphics.setScissor(d.x, d.y + 34, LIST_W + 8, d.h - 42)
	local ly = d.y + 40 - self.scroll
	for i = 1, #list do
		local ry = ly + (i - 1) * ROW_H
		if i == self.selected then
			love.graphics.setColor(dbg_theme.HI[1], dbg_theme.HI[2], dbg_theme.HI[3], 0.95)
			love.graphics.rectangle("fill", d.x + 6, ry, LIST_W - 12, ROW_H - 2, 3, 3)
		end
		love.graphics.setFont(self.body)
		love.graphics.setColor(dbg_theme.TEXT[1], dbg_theme.TEXT[2], dbg_theme.TEXT[3], 1)
		love.graphics.print(list[i].name, d.x + 14, ry + 3)
		love.graphics.setColor(dbg_theme.DIM[1], dbg_theme.DIM[2], dbg_theme.DIM[3], 1)
		love.graphics.print(list[i].kind, d.x + 14, ry + 18)
	end
	love.graphics.setScissor()
end

-- Detail column: large framed fly preview with text below.
local function detail_col(self, d)
	local f = tackle.list[self.selected]
	local x = d.x + LIST_W + 16
	local col_w = d.x + d.w - x - 12
	-- Divider line.
	love.graphics.setColor(dbg_theme.EDGE[1], dbg_theme.EDGE[2], dbg_theme.EDGE[3], 0.6)
	love.graphics.line(x - 8, d.y + 10, x - 8, d.y + d.h - 10)
	-- Framed preview box in the upper portion.
	local box_h = d.h * 0.50
	local box_cx = x + col_w / 2
	local box_cy = d.y + 28 + box_h / 2
	local box_w = col_w - 16
	love.graphics.setColor(dbg_theme.BG[1], dbg_theme.BG[2], dbg_theme.BG[3], 0.5)
	love.graphics.rectangle("fill", box_cx - box_w / 2, box_cy - box_h / 2, box_w, box_h, 3, 3)
	love.graphics.setColor(dbg_theme.EDGE[1], dbg_theme.EDGE[2], dbg_theme.EDGE[3], 0.45)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", box_cx - box_w / 2, box_cy - box_h / 2, box_w, box_h, 3, 3)
	-- Fly drawing scaled to fill the box.
	local base_s = f.kind == "streamer" and 1.2 or (f.kind == "dry" and 1.6 or 2.2)
	local scale = base_s * math.min(box_w / 100, box_h / 80)
	love.graphics.push()
	love.graphics.translate(box_cx, box_cy)
	tackle.draw(f, scale)
	love.graphics.pop()
	-- Text below the box, spacing from d.h.
	local text_top = box_cy + box_h / 2 + 12
	local line_h = math.max(16, d.h * 0.055)
	love.graphics.setFont(self.head)
	love.graphics.setColor(dbg_theme.TEXT[1], dbg_theme.TEXT[2], dbg_theme.TEXT[3], 1)
	love.graphics.printf(f.name, x, text_top, col_w, "left")
	love.graphics.setFont(self.body)
	love.graphics.setColor(dbg_theme.EDGE[1], dbg_theme.EDGE[2], dbg_theme.EDGE[3], 1)
	love.graphics.printf(f.rig, x, text_top + line_h, col_w, "left")
	love.graphics.setColor(dbg_theme.DIM[1], dbg_theme.DIM[2], dbg_theme.DIM[3], 1)
	love.graphics.printf(f.water, x, text_top + line_h * 2, col_w, "left")
	love.graphics.setColor(dbg_theme.TEXT[1], dbg_theme.TEXT[2], dbg_theme.TEXT[3], 1)
	love.graphics.printf(f.tip, x, text_top + line_h * 3, col_w, "left")
end

function flybox:draw()
	button(self)
	if not self.open then
		return
	end
	local d = drawer()
	love.graphics.setColor(dbg_theme.BG[1], dbg_theme.BG[2], dbg_theme.BG[3], 0.97)
	love.graphics.rectangle("fill", d.x, d.y, d.w, d.h, 6, 6)
	love.graphics.setColor(dbg_theme.EDGE[1], dbg_theme.EDGE[2], dbg_theme.EDGE[3], 1)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", d.x, d.y, d.w, d.h, 6, 6)
	love.graphics.setLineWidth(1)
	list_col(self, d)
	detail_col(self, d)
end

return flybox

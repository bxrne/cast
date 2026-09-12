local tackle = require "draw.flies"
local dbg_theme = require "ui.debug"

local flybox = {}
flybox.__index = flybox

local BTN = { x = 16, y = 16, w = 132, h = 38 }
local ROW_H = 44
local LIST_W = 240

function flybox.new()
	local fonts = require("ui.fonts").get()
	return setmetatable({
		open = false, selected = 1, scroll = 0,
		font = fonts.mono, head = fonts.head, body = fonts.body,
	}, flybox)
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
	-- Row pick in the scrollable list column.
	local ly = d.y + 40 - self.scroll
	if x <= d.x + LIST_W + 8 then
		local i = math.floor((y - ly) / ROW_H) + 1
		if i >= 1 and i <= #tackle.list then
			self.selected = i
			local top, bot = d.y + 40, d.y + d.h - 8
			local ry = ly + (i - 1) * ROW_H
			if ry < top then
				self.scroll = self.scroll - (top - ry)
			elseif ry + ROW_H > bot then
				self.scroll = self.scroll + (ry + ROW_H - bot)
			end
			self.scroll = math.max(0, math.min(max_scroll(d), self.scroll))
		end
		return true
	end
	return true
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
			love.graphics.rectangle("fill", d.x + 6, ry, LIST_W - 12, ROW_H - 4, 3, 3)
		end
		love.graphics.push()
		love.graphics.translate(d.x + 36, ry + (ROW_H - 4) / 2)
		tackle.draw(list[i], list[i].s * 0.50)
		love.graphics.pop()
		love.graphics.setFont(self.body)
		love.graphics.setColor(dbg_theme.TEXT[1], dbg_theme.TEXT[2], dbg_theme.TEXT[3], 1)
		love.graphics.print(list[i].name, d.x + 64, ry + 4)
		love.graphics.setColor(dbg_theme.DIM[1], dbg_theme.DIM[2], dbg_theme.DIM[3], 1)
		love.graphics.print(list[i].kind, d.x + 64, ry + 22)
	end
	love.graphics.setScissor()
end

local function detail_col(self, d)
	local f = tackle.list[self.selected]
	local x = d.x + LIST_W + 20
	love.graphics.setColor(dbg_theme.EDGE[1], dbg_theme.EDGE[2], dbg_theme.EDGE[3], 0.6)
	love.graphics.line(x - 10, d.y + 10, x - 10, d.y + d.h - 10)
	local scale = f.kind == "streamer" and 1.0 or (f.kind == "dry" and 1.3 or 1.8)
	love.graphics.push()
	love.graphics.translate(x + (d.x + d.w - x) / 2, d.y + 120)
	tackle.draw(f, scale)
	love.graphics.pop()
	love.graphics.setFont(self.head)
	love.graphics.setColor(dbg_theme.TEXT[1], dbg_theme.TEXT[2], dbg_theme.TEXT[3], 1)
	love.graphics.printf(f.name, x, d.y + 190, d.x + d.w - x - 16, "left")
	love.graphics.setFont(self.body)
	love.graphics.setColor(dbg_theme.EDGE[1], dbg_theme.EDGE[2], dbg_theme.EDGE[3], 1)
	love.graphics.printf(f.kind .. "  |  " .. f.rig, x, d.y + 214, d.x + d.w - x - 16, "left")
	love.graphics.setColor(dbg_theme.TEXT[1], dbg_theme.TEXT[2], dbg_theme.TEXT[3], 1)
	love.graphics.printf("Water: " .. f.water, x, d.y + 236, d.x + d.w - x - 16, "left")
	love.graphics.setColor(dbg_theme.DIM[1], dbg_theme.DIM[2], dbg_theme.DIM[3], 1)
	love.graphics.printf(f.tip, x, d.y + 260, d.x + d.w - x - 16, "left")
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

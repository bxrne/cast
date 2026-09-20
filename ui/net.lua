-- Creel panel beside the fly box. The NET button shows the
-- landed count. Opening it lists every caught fish: species
-- and length. Esc or a second click closes it.
local theme = require "ui.debug"

local net = {}
net.__index = net

local BTN = { x = 172, y = 16, w = 110, h = 42 }
local PAD = 22
local ROW_H = 26

function net.new()
	local fonts = require("ui.fonts").get()
	return setmetatable({ open = false, mono = fonts.mono, body = fonts.body }, net)
end

-- True when x, y lands in the button.
local function on_button(x, y)
	return x >= BTN.x and x <= BTN.x + BTN.w and y >= BTN.y and y <= BTN.y + BTN.h
end

function net:mousepressed(x, y, list)
	if on_button(x, y) then
		self.open = not self.open
		return true
	end
	if not self.open then
		return false
	end
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	local rows = math.max(1, #list)
	local dw, dh = 300, PAD * 2 + 30 + rows * ROW_H + PAD
	local dx, dy = (w - dw) / 2, (h - dh) / 2
	if x < dx or x > dx + dw or y < dy or y > dy + dh then
		self.open = false
		return false
	end
	return true
end

local function button(self, list)
	love.graphics.setFont(self.body)
	love.graphics.setColor(0, 0, 0, 0.28)
	love.graphics.rectangle("fill", BTN.x + 2, BTN.y + 3, BTN.w, BTN.h, 5, 5)
	love.graphics.setColor(theme.BG, 0.96)
	love.graphics.rectangle("fill", BTN.x, BTN.y, BTN.w, BTN.h, 5, 5)
	love.graphics.setColor(theme.EDGE, 1)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", BTN.x, BTN.y, BTN.w, BTN.h, 5, 5)
	love.graphics.setColor(theme.TEXT, 1)
	love.graphics.printf("NET", BTN.x, BTN.y + 12, BTN.w - 34, "center")
	love.graphics.setFont(self.mono)
	love.graphics.setColor(0.72, 0.82, 0.55, 1)
	love.graphics.printf(string.format("%02d", #list), BTN.x + BTN.w - 34, BTN.y + 13, 24, "right")
end

function net:draw(list)
	button(self, list)
	if not self.open then
		return
	end
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	local rows = math.max(1, #list)
	local dw, dh = 300, PAD * 2 + 30 + rows * ROW_H + PAD
	local dx, dy = (w - dw) / 2, (h - dh) / 2
	love.graphics.push("all")
	love.graphics.setColor(0, 0, 0, 0.30)
	love.graphics.rectangle("fill", dx + 7, dy + 9, dw, dh, 6, 6)
	love.graphics.setColor(theme.BG, 0.97)
	love.graphics.rectangle("fill", dx, dy, dw, dh, 6, 6)
	love.graphics.setColor(theme.EDGE, 1)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", dx, dy, dw, dh, 6, 6)
	love.graphics.setFont(self.body)
	love.graphics.setColor(0.72, 0.82, 0.55, 1)
	love.graphics.print("NET", dx + PAD, dy + PAD)
	love.graphics.setFont(self.mono)
	love.graphics.setColor(theme.DIM, 1)
	love.graphics.printf(string.format("%02d LANDED", #list), dx + dw - PAD - 110, dy + PAD + 2, 110, "right")
	local y = dy + PAD + 30
	if #list == 0 then
		love.graphics.setFont(self.body)
		love.graphics.setColor(theme.DIM, 1)
		love.graphics.print("Empty creel. Go catch one.", dx + PAD, y)
	else
		for i = 1, #list do
			love.graphics.setFont(self.body)
			love.graphics.setColor(theme.TEXT, 1)
			love.graphics.printf(list[i].common, dx + PAD, y + (i - 1) * ROW_H, 170, "left")
			love.graphics.setFont(self.mono)
			love.graphics.setColor(theme.DIM, 1)
			love.graphics.printf(string.format("%dcm", list[i].length), dx + dw - PAD - 70, y + (i - 1) * ROW_H + 2, 70, "right")
		end
	end
	love.graphics.pop()
end

return net

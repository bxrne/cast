local debug = {}
debug.__index = debug

local PANEL_W = 280
local ROW_H = 22
local PAD = 12

local function format_value(ctrl)
	local v = ctrl.get()
	if ctrl.kind == "bool" then
		if v then
			return "on"
		end
		return "off"
	end
	if ctrl.kind == "float" then
		return string.format("%.2f", v)
	end
	return tostring(v)
end

local function nudge(ctrl, dir)
	local v = ctrl.get()
	if ctrl.kind == "bool" then
		ctrl.set(not v)
		return
	end
	local step = ctrl.step or 1
	if ctrl.kind == "float" then
		v = v + dir * step
	else
		v = v + dir * step
	end
	if ctrl.min then
		v = math.max(ctrl.min, v)
	end
	if ctrl.max then
		v = math.min(ctrl.max, v)
	end
	ctrl.set(v)
end

function debug.new(opts)
	opts = opts or {}
	return setmetatable({
		open = opts.open or false,
		selected = 1,
		controls = opts.controls or {},
	}, debug)
end

function debug:add(ctrl)
	self.controls[#self.controls + 1] = ctrl
end

function debug:toggle()
	self.open = not self.open
end

function debug:keypressed(key)
	if key == "f1" or key == "`" then
		self:toggle()
		return true
	end
	if not self.open then
		return false
	end
	local n = #self.controls
	if n == 0 then
		return false
	end
	if key == "up" then
		self.selected = ((self.selected - 2) % n) + 1
		return true
	end
	if key == "down" then
		self.selected = (self.selected % n) + 1
		return true
	end
	if key == "left" then
		nudge(self.controls[self.selected], -1)
		return true
	end
	if key == "right" then
		nudge(self.controls[self.selected], 1)
		return true
	end
	return false
end

function debug:draw()
	if not self.open then
		return
	end
	local controls = self.controls
	local rows = #controls + 3
	local h = PAD * 2 + rows * ROW_H
	local x, y = 16, 16

	love.graphics.push("all")
	love.graphics.origin()
	love.graphics.setLineWidth(1)
	love.graphics.setColor(0.10, 0.11, 0.08, 0.88)
	love.graphics.rectangle("fill", x, y, PANEL_W, h, 3, 3)
	love.graphics.setColor(0.42, 0.46, 0.32, 0.9)
	love.graphics.rectangle("line", x, y, PANEL_W, h, 3, 3)

	love.graphics.setColor(0.82, 0.80, 0.68)
	love.graphics.print("debug", x + PAD, y + 8)
	love.graphics.setColor(0.55, 0.54, 0.42)
	love.graphics.print("F1", x + PANEL_W - PAD - 18, y + 8)

	for i = 1, #controls do
		local cy = y + PAD + (i + 0.4) * ROW_H
		if i == self.selected then
			love.graphics.setColor(0.28, 0.32, 0.18, 0.95)
			love.graphics.rectangle("fill", x + 6, cy - 3, PANEL_W - 12, ROW_H - 2, 2, 2)
		end
		local ctrl = controls[i]
		love.graphics.setColor(0.78, 0.76, 0.62)
		love.graphics.print(ctrl.label, x + PAD, cy)
		love.graphics.printf(format_value(ctrl), x + PAD, cy, PANEL_W - PAD * 2, "right")
	end

	local fy = y + h - PAD - ROW_H
	love.graphics.setColor(0.50, 0.49, 0.38)
	love.graphics.print("arrows adjust   R seed   WASD walk", x + PAD, fy)
	love.graphics.pop()
end

return debug

local rand = require "lib.rand"

local debug = {}
debug.__index = debug

local PANEL_W, ROW_H, PAD = 280, 22, 12

-- Format a control value for the panel.
local function format_value(ctrl)
	local v = ctrl.get()
	if ctrl.kind == "bool" then
		return v and "on" or "off"
	end
	if ctrl.kind == "float" then
		return string.format("%.2f", v)
	end
	return tostring(v)
end

-- Apply left/right to one control.
local function nudge(ctrl, dir)
	if ctrl.kind == "bool" then
		ctrl.set(not ctrl.get())
		return
	end
	if ctrl.kind == "label" then
		return
	end
	if ctrl.kind == "seed" then
		ctrl.set(rand.other(ctrl.get(), ctrl.min or 1, ctrl.max or 999999))
		return
	end
	local v = ctrl.get() + dir * (ctrl.step or 1)
	if ctrl.min then
		v = math.max(ctrl.min, v)
	end
	if ctrl.max then
		v = math.min(ctrl.max, v)
	end
	ctrl.set(v)
end

-- Create a closed panel with optional controls.
function debug.new(opts)
	opts = opts or {}
	return setmetatable({ open = opts.open or false, selected = 1, controls = opts.controls or {} }, debug)
end

-- Append a control.
function debug:add(ctrl)
	self.controls[#self.controls + 1] = ctrl
end

-- Open or close the panel.
function debug:toggle()
	self.open = not self.open
end

-- Handle a key. Returns true if consumed.
function debug:keypressed(key)
	if key == "f1" or key == "`" then
		self:toggle()
		return true
	end
	if not self.open or #self.controls == 0 then
		return false
	end
	local n = #self.controls
	local keys = {
		up = function()
			self.selected = ((self.selected - 2) % n) + 1
		end,
		down = function()
			self.selected = (self.selected % n) + 1
		end,
		left = function()
			nudge(self.controls[self.selected], -1)
		end,
		right = function()
			nudge(self.controls[self.selected], 1)
		end,
	}
	if not keys[key] then
		return false
	end
	keys[key]()
	return true
end

-- Draw the overlay when open.
function debug:draw()
	if not self.open then
		return
	end
	local controls, h, x, y = self.controls, PAD * 2 + (#self.controls + 3) * ROW_H, 16, 16
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
		love.graphics.setColor(0.78, 0.76, 0.62)
		love.graphics.print(controls[i].label, x + PAD, cy)
		love.graphics.printf(format_value(controls[i]), x + PAD, cy, PANEL_W - PAD * 2, "right")
	end
	love.graphics.setColor(0.50, 0.49, 0.38)
	love.graphics.print("arrows adjust   R roll seed", x + PAD, y + h - PAD - ROW_H)
	love.graphics.pop()
end

return debug

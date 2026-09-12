local rand = require "lib.rand"

local debug = {}
debug.__index = debug

local PANEL_W, ROW_H, HEAD_H, PAD = 280, 22, 26, 12
local FOOTER_GAP, FOOTER_H = 14, 20
local SEL = { 0.95, 0.88, 0.60 }

-- UI theme, shared with flybox and fish tags.
debug.BG = { 0.10, 0.11, 0.08 }
debug.EDGE = { 0.42, 0.46, 0.32 }
debug.TEXT = { 0.78, 0.76, 0.62 }
debug.DIM = { 0.55, 0.54, 0.42 }
debug.HI = { 0.28, 0.32, 0.18 }

-- True when the row takes left/right input. Headers and
-- labels are readouts. The cursor never stops on them, so
-- fps and friends read as info, not knobs.
local function adjustable(c)
	return c.kind == "bool" or c.kind == "float" or c.kind == "seed"
end

-- Format a control value for the panel.
local function format_value(ctrl)
	local v = ctrl.get()
	if v == nil then
		return "?"
	end
	if ctrl.kind == "bool" then
		return v and "on" or "off"
	end
	if ctrl.kind == "float" then
		return string.format("%.2f", v)
	end
	if ctrl.kind == "seed" then
		if ctrl.bed then
			local ok, bed = pcall(ctrl.bed)
			if ok and bed then
				return string.format("%d (%s)", v, bed)
			end
		end
		return tostring(v)
	end
	return tostring(v)
end

-- Apply left/right to one control. Readouts ignore it.
local function nudge(ctrl, dir)
	if not adjustable(ctrl) then
		return
	end
	if ctrl.kind == "bool" then
		ctrl.set(not ctrl.get())
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
	if not (v == v) or v == math.huge or v == -math.huge then
		return
	end
	ctrl.set(v)
end

-- Create a closed panel with optional controls and a mono font.
-- The cursor starts on the first adjustable row.
function debug.new(opts)
	opts = opts or {}
	local fonts = require("ui.fonts").get()
	local self = setmetatable({
		open = false,
		selected = 1,
		controls = opts.controls or {},
		font = fonts.mono,
	}, debug)
	for i = 1, #self.controls do
		if adjustable(self.controls[i]) then
			self.selected = i
			break
		end
	end
	return self
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
	-- Step over headers and readouts. At most one full wrap.
	-- With no adjustable row the cursor stays put.
	local function move(dir)
		local n = #self.controls
		for _ = 1, n do
			self.selected = ((self.selected - 1 + dir) % n) + 1
			if adjustable(self.controls[self.selected]) then
				return
			end
		end
	end
	local keys = {
		up = function() move(-1) end,
		down = function() move(1) end,
		left = function() nudge(self.controls[self.selected], -1) end,
		right = function() nudge(self.controls[self.selected], 1) end,
	}
	if not keys[key] then
		return false
	end
	keys[key]()
	return true
end

-- Draw the overlay when open, top right. Section headers
-- split knobs from readouts. The selected knob gets a soft
-- box plus bright text. Readouts stay dim and value only.
function debug:draw()
	if not self.open then
		return
	end
	local controls = self.controls
	local w, h = love.graphics.getWidth(), love.graphics.getHeight()
	local rows_h = 0
	for i = 1, #controls do
		rows_h = rows_h + (controls[i].kind == "header" and HEAD_H or ROW_H)
	end
	local x, y = w - PANEL_W - 16, 16
	local panel_h = PAD * 2 + ROW_H + rows_h + FOOTER_GAP + FOOTER_H
	love.graphics.push("all")
	love.graphics.setFont(self.font)
	love.graphics.origin()
	love.graphics.setLineWidth(1)
	love.graphics.setColor(debug.BG[1], debug.BG[2], debug.BG[3], 0.92)
	love.graphics.rectangle("fill", x, y, PANEL_W, panel_h, 3, 3)
	love.graphics.setColor(debug.EDGE[1], debug.EDGE[2], debug.EDGE[3], 0.9)
	love.graphics.rectangle("line", x, y, PANEL_W, panel_h, 3, 3)
	love.graphics.setColor(debug.TEXT[1], debug.TEXT[2], debug.TEXT[3])
	love.graphics.print("debug", x + PAD, y + 8)
	love.graphics.setColor(debug.DIM[1], debug.DIM[2], debug.DIM[3])
	love.graphics.print("F1", x + PANEL_W - PAD - 18, y + 8)
	local cy = y + PAD + ROW_H
	for i = 1, #controls do
		local c = controls[i]
		if c.kind == "header" then
			love.graphics.setColor(debug.DIM[1], debug.DIM[2], debug.DIM[3], 1)
			love.graphics.print(string.upper(c.label or c.id or "?"), x + PAD, cy + 9)
			love.graphics.setColor(debug.EDGE[1], debug.EDGE[2], debug.EDGE[3], 0.45)
			love.graphics.line(x + PAD, cy + HEAD_H - 3, x + PANEL_W - PAD, cy + HEAD_H - 3)
			cy = cy + HEAD_H
		else
			local sel = i == self.selected
			if sel then
				love.graphics.setColor(debug.HI[1], debug.HI[2], debug.HI[3], 0.85)
				love.graphics.rectangle("fill", x + 6, cy + 1, PANEL_W - 12, ROW_H - 2, 3, 3)
				love.graphics.setColor(SEL[1], SEL[2], SEL[3])
			elseif adjustable(c) then
				love.graphics.setColor(debug.TEXT[1], debug.TEXT[2], debug.TEXT[3])
			else
				love.graphics.setColor(debug.DIM[1], debug.DIM[2], debug.DIM[3])
			end
			love.graphics.print(c.label or c.id or "?", x + PAD, cy)
			love.graphics.printf(format_value(c), x + PAD, cy, PANEL_W - PAD * 2, "right")
			cy = cy + ROW_H
		end
	end
	local footer_y = y + panel_h - PAD - FOOTER_H
	love.graphics.setColor(debug.EDGE[1], debug.EDGE[2], debug.EDGE[3], 0.45)
	love.graphics.line(x + PAD, footer_y - FOOTER_GAP / 2, x + PANEL_W - PAD, footer_y - FOOTER_GAP / 2)
	love.graphics.setColor(debug.DIM[1], debug.DIM[2], debug.DIM[3])
	love.graphics.print("up/down pick  left/right adjust  F1 close", x + PAD, footer_y + 4)
	love.graphics.pop()
end

return debug
